import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from urllib.parse import urlunsplit

ROOT = Path(__file__).resolve().parents[1]


class HelpersTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.directory = Path(self.scratch.name)
        self.tools = self.directory / "tools"
        self.tools.mkdir()
        self.env = {k: v for k, v in os.environ.items()
                    if k not in ("AWS_PROFILE", "SSH_CONNECTION", "SSH_TTY", "TMUX",
                                 "DISPLAY", "WAYLAND_DISPLAY", "WORKBENCH_LOCATION")}
        self.env["PATH"] = str(self.tools) + os.pathsep + os.environ["PATH"]

    def fake(self, name, body):
        path = self.tools / name
        path.write_text("#!/bin/sh\n" + body + "\n")
        path.chmod(0o700)
        return path

    def run_helper(self, name, *args):
        return subprocess.run(["bash", str(ROOT / "bin" / name), *args],
                              env=self.env, capture_output=True, text=True, timeout=5)

    def test_aws_desktop_profile_and_remote_device_code(self):
        self.fake("aws", "printf '%s\\n' \"$@\"")
        self.fake("uname", "echo Darwin")
        result = self.run_helper("awslogin", "example-reader")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.splitlines(), ["sso", "login", "--profile", "example-reader"])
        self.env["SSH_CONNECTION"] = "synthetic"
        self.env["AWS_PROFILE"] = "example-default"
        result = self.run_helper("awslogin")
        self.assertEqual(result.stdout.splitlines(),
                         ["sso", "login", "--profile", "example-default", "--use-device-code", "--no-browser"])

    def test_aws_headless_and_display_linux(self):
        self.fake("aws", "printf '%s\\n' \"$@\"")
        self.fake("uname", "echo Linux")
        self.assertIn("--use-device-code", self.run_helper("awslogin", "reader").stdout)
        self.env["DISPLAY"] = ":1"
        self.assertNotIn("--use-device-code", self.run_helper("awslogin", "reader").stdout)

    def test_aws_missing_profile_and_extra_args_do_not_login(self):
        self.fake("aws", "echo unexpected-login")
        for args in ((), ("reader", "other")):
            result = self.run_helper("awslogin", *args)
            self.assertEqual(result.returncode, 2)
            self.assertNotIn("unexpected-login", result.stdout)

    def test_installer_dry_runs_do_not_invoke_mutations(self):
        marker = self.directory / "mutation"
        self.env["TEST_MUTATION_MARKER"] = str(marker)
        for name in ("mkdir", "mv", "ln", "curl", "sudo", "git", "uv"):
            self.fake(name, 'touch "$TEST_MUTATION_MARKER"; exit 99')
        self.fake("harlequin", "exit 0")
        self.fake("uname", 'if [ "$1" = -m ]; then echo x86_64; else echo Linux; fi')
        for name in ("install.sh", "install-runtimes-linux.sh"):
            result = subprocess.run(["bash", str(ROOT / name), "--dry-run"],
                                    env=self.env, capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0)
            self.assertFalse(marker.exists())

    def phone_stub(self, clients):
        self.env.update(TMUX="synthetic", TMUX_PANE="%1", PHONE_CLIENTS=clients)
        self.fake("tmux", '''case "$1" in
has-session) exit 0 ;;
display-message) echo '$1' ;;
list-clients) printf '%s\\n' "$PHONE_CLIENTS" ;;
*) printf '%s\\n' "$@" ;;
esac''')

    def test_phone_exact_target_and_single_client(self):
        self.phone_stub("client-one")
        result = self.run_helper("workbench-phone-session", "my task")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.splitlines(), ["switch-client", "-c", "client-one", "-t", "=my task"])

    def test_phone_shared_clients_stay_in_place(self):
        self.phone_stub("client-one\nclient-two")
        result = self.run_helper("workbench-phone-session", "my task")
        self.assertEqual(result.returncode, 0)
        self.assertIn('Session "my task" is ready', result.stdout)
        self.assertNotIn("switch-client", result.stdout)

    def test_phone_invalid_names_cannot_be_tmux_options(self):
        self.phone_stub("client-one")
        for name in ("-bad", "project:window", "x" * 129, "", "$(command)"):
            result = self.run_helper("workbench-phone-session", name)
            self.assertEqual(result.returncode, 2)
            self.assertNotIn("switch-client", result.stdout)

    def test_vpn_resolves_conflict_when_selected_is_already_active(self):
        config = self.directory / "databases.conf"
        config.write_text("WORKBENCH_WG_DEV_INTERFACE=wg-example-dev\nWORKBENCH_WG_PROD_INTERFACE=wg-example-prod\n")
        self.env["WORKBENCH_DATABASE_CONFIG"] = str(config)
        self.fake("systemctl", "exit 0")
        self.fake("sudo", "printf '%s\\n' \"$@\"")
        result = self.run_helper("workbench-wg", "up", "dev")
        self.assertEqual(result.returncode, 0)
        self.assertIn("stop\nwg-quick@wg-example-prod.service", result.stdout)
        self.assertNotIn("start", result.stdout)

    def mcp_config(self, expected_name="billing", key="DATABASE_DSN"):
        config = self.directory / "databases.conf"
        config.write_text(f'''workbench_database() {{
WORKBENCH_DATABASE_DSN_VAR={key}
WORKBENCH_DATABASE_NAME={expected_name}
WORKBENCH_DATABASE_READONLY_USER=reader
}}
''')
        store = self.directory / "store"
        value = urlunsplit(("postgresql", "reader:synthetic@db.example.invalid", "/billing", "sslmode=require", ""))
        store.write_text(f"{key}='{value}'\n")
        store.chmod(0o600)
        self.env.update(WORKBENCH_DATABASE_CONFIG=str(config), WORKBENCH_DATABASE_SECRETS=str(store),
                        WORKBENCH_NPX=str(self.fake("npx", "echo synthetic-dbhub")),
                        TMPDIR=str(self.directory), PYTHONOPTIMIZE="1")
        return value

    def test_mcp_supports_database_target_ids_and_no_credential_output(self):
        value = self.mcp_config()
        result = self.run_helper("workbench-db-mcp", "billing_dev")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("synthetic-dbhub", result.stdout)
        self.assertNotIn(value, result.stdout + result.stderr)
        self.assertFalse(list(self.directory.glob("workbench-db.*")))

    def test_mcp_rejects_wrong_identity_even_when_python_is_optimized(self):
        value = self.mcp_config(expected_name="other")
        result = self.run_helper("workbench-db-mcp", "billing_dev")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("synthetic-dbhub", result.stdout)
        self.assertNotIn(value, result.stdout + result.stderr)

    def test_mcp_rejects_write_mapping(self):
        self.mcp_config(key="DATABASE_WRITE_DSN")
        result = self.run_helper("workbench-db-mcp", "billing_dev")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("write DSNs cannot", result.stderr)


if __name__ == "__main__":
    unittest.main()
