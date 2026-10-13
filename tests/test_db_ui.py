import importlib.machinery
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import urlunsplit

loader = importlib.machinery.SourceFileLoader("db_ui", str(Path(__file__).resolve().parents[1] / "bin/workbench-db-ui"))
spec = importlib.util.spec_from_loader(loader.name, loader)
ui = importlib.util.module_from_spec(spec)
loader.exec_module(ui)


def dsn(user="reader", password="test%40secret", database="billing", query="sslmode=require"):
    return urlunsplit(("postgresql", f"{user}:{password}@db.example.invalid:5432", "/" + database, query, ""))


class DatabaseUiTests(unittest.TestCase):
    def test_readonly_and_password_decoding(self):
        env = ui.connection_env(dsn(), "billing", "reader")
        self.assertEqual(env["PGPASSWORD"], "test@secret")
        self.assertEqual(env["PGTARGETSESSIONATTRS"], "read-only")
        self.assertIn("default_transaction_read_only=on", env["PGOPTIONS"])

    def test_reject_wrong_database_or_identity(self):
        for database, user in [("other", "reader"), ("billing", "admin")]:
            with self.assertRaises(ui.ConfigError):
                ui.connection_env(dsn(), database, user)

    def test_reject_placeholders_and_cleartext(self):
        for value in [dsn(password="pwd"), dsn(query="sslmode=disable"), dsn() + " "]:
            with self.assertRaises(ui.ConfigError):
                ui.connection_env(value)

    def test_connection_settings_cannot_inherit_write_access(self):
        with patch.dict(os.environ, {"PGSERVICE": "admin", "PGOPTIONS": "-c default_transaction_read_only=off"}):
            env = ui.connection_env(dsn(query="sslmode=prefer&options=-c%20default_transaction_read_only%3Doff"))
        self.assertNotIn("PGSERVICE", env)
        self.assertEqual(env["PGSSLMODE"], "require")
        self.assertTrue(env["PGOPTIONS"].endswith("default_transaction_read_only=on"))

    def test_write_is_explicit_and_requires_writable_session(self):
        env = ui.connection_env(dsn(user="writer"), write=True)
        self.assertEqual(env["PGTARGETSESSIONATTRS"], "read-write")
        self.assertEqual(env["PGOPTIONS"], "-c default_transaction_read_only=off")

    def test_libpq_option_names(self):
        env = ui.connection_env(dsn(query="sslmode=require&connect_timeout=5&application_name=ui"))
        self.assertEqual(env["PGCONNECT_TIMEOUT"], "5")
        self.assertEqual(env["PGAPPNAME"], "ui")

    def test_store_is_not_executed_and_requires_private_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "credentials"
            p.write_text("DB_DSN='$(touch should-not-exist)'\n")
            p.chmod(0o600)
            self.assertEqual(ui.read_store(p)["DB_DSN"], "$(touch should-not-exist)")
            p.chmod(0o644)
            with self.assertRaises(ui.ConfigError):
                ui.read_store(p)

    def test_invalid_ui_overrides_are_rejected_before_loading_credentials(self):
        for args in [["prod", "billing", "--user", "admin"], ["dev", "--profile", "writer"]]:
            with self.assertRaises(ui.ConfigError):
                ui.main(args)

    def test_target_selection(self):
        with patch.object(ui, "resolve_target", side_effect=ui.ConfigError("stop")) as resolve:
            with self.assertRaises(ui.ConfigError):
                ui.main(["prod", "billing"])
        self.assertEqual(resolve.call_args.args[1], "billing_prod")

    def test_write_store_is_separate_from_readonly(self):
        with patch.object(ui, "read_store", return_value={"DATABASE_WRITE_DEV_DSN": dsn(user="writer")}) as read:
            with patch.object(ui, "run_client", return_value=0):
                ui.main(["write", "dev"])
        self.assertEqual(read.call_args.args[0].name, "db-write.env")

    def test_write_environment_selects_its_own_dsn_and_tunnel(self):
        values = {"DATABASE_WRITE_DEV_DSN": dsn(user="dev_writer", database="dev_db"),
                  "DATABASE_WRITE_PROD_DSN": dsn(user="prod_writer", database="prod_db")}
        for environment in ("dev", "prod"):
            with patch.object(ui, "read_store", return_value=values):
                with patch.object(ui, "run_client", return_value=0) as run:
                    ui.main(["write", environment, "--theme", "nord"])
            child_env, tunnel, options = run.call_args.args
            self.assertEqual(child_env["PGDATABASE"], environment + "_db")
            self.assertEqual(child_env["PGUSER"], environment + "_writer")
            self.assertEqual(child_env["PGTARGETSESSIONATTRS"], "read-write")
            self.assertEqual(tunnel, environment)
            self.assertEqual(options, ["--theme", "nord"])

    def test_write_requires_an_explicit_valid_environment(self):
        for args in (["write"], ["write", "staging"], ["write", "--theme", "nord"]):
            with patch.object(ui, "read_store") as read:
                with self.assertRaises(ui.ConfigError):
                    ui.main(args)
                read.assert_not_called()

    def test_missing_prod_does_not_fall_back_to_dev_or_legacy(self):
        values = {"DATABASE_WRITE_DEV_DSN": dsn(user="writer"),
                  "DATABASE_WRITE_ENV": "prod", "DATABASE_WRITE_DSN": dsn(user="old_writer")}
        with patch.object(ui, "read_store", return_value=values):
            with patch.object(ui, "run_client") as run:
                with self.assertRaises(ui.ConfigError):
                    ui.main(["write", "prod"])
                run.assert_not_called()

    def test_no_dsn_or_password_in_client_arguments_and_cleanup_after_failure(self):
        env = ui.connection_env(dsn())
        with patch.dict(os.environ, {"WORKBENCH_WG_HELPER": "/fake/wg", "KEEP_WG": "0"}):
            with patch.object(ui.subprocess, "check_output", return_value="none\n"):
                with patch.object(ui.subprocess, "run") as run:
                    with patch.object(ui.subprocess, "call", return_value=7) as call:
                        self.assertEqual(ui.run_client(env, "prod", []), 7)
        self.assertNotIn(env["PGPASSWORD"], " ".join(call.call_args.args[0]))
        self.assertNotIn(dsn(), " ".join(call.call_args.args[0]))
        self.assertEqual(run.call_args.args[0], ["/fake/wg", "down", "prod"])

    def test_existing_tunnel_is_preserved(self):
        with patch.dict(os.environ, {"WORKBENCH_WG_HELPER": "/fake/wg", "KEEP_WG": "0"}):
            with patch.object(ui.subprocess, "check_output", return_value="dev\n"):
                with patch.object(ui.subprocess, "run") as run:
                    with patch.object(ui.subprocess, "call", return_value=0):
                        ui.run_client(ui.connection_env(dsn()), "dev", [])
        self.assertEqual(run.call_count, 1)


if __name__ == "__main__":
    unittest.main()
