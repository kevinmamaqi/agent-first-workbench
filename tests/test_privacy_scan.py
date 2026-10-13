import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCANNER = Path(__file__).resolve().parents[1] / "scripts/check-private-files.sh"


class PrivacyScanTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.directory = Path(self.scratch.name)
        self.tree = self.directory / "tree"
        self.tree.mkdir()
        self.env = dict(os.environ)
        self.env.pop("PRIVATE_DENYLIST", None)

    def scan(self):
        return subprocess.run(["bash", str(SCANNER), str(self.tree)], env=self.env,
                              capture_output=True, text=True, timeout=5)

    def test_token_is_detected_without_printing_its_value(self):
        token = "gh" + "p_" + "synthetic_do_not_print"
        (self.tree / "example.txt").write_text(token)
        result = self.scan()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("example.txt", result.stdout)
        self.assertNotIn(token, result.stdout + result.stderr)

    def test_ignored_empty_credential_file_is_rejected(self):
        (self.tree / ".gitignore").write_text(".env\n")
        (self.tree / ".env").write_text("")
        result = self.scan()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(".env", result.stdout)

    def test_denylist_is_external_and_never_printed(self):
        term = "synthetic-private-identifier"
        (self.tree / "example.txt").write_text(term)
        denylist = self.directory / "denylist"
        denylist.write_text(term + "\n")
        self.env["PRIVATE_DENYLIST"] = str(denylist)
        result = self.scan()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(term, result.stdout + result.stderr)

    def test_external_symlink_is_rejected_without_reading_target(self):
        target = self.directory / "outside"
        target.write_text("outside content")
        (self.tree / "link").symlink_to(target)
        result = self.scan()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("external symlink", result.stderr)

    def test_internal_relative_symlink_is_allowed(self):
        (self.tree / "example.md").write_text("public example\n")
        (self.tree / "link").symlink_to("example.md")
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_failed_scanner_cannot_pass(self):
        tools = self.directory / "tools"
        tools.mkdir()
        rg = tools / "rg"
        rg.write_text("#!/bin/sh\nexit 2\n")
        rg.chmod(0o700)
        self.env["PATH"] = str(tools) + os.pathsep + os.environ["PATH"]
        result = self.scan()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("scan could not complete", result.stderr)


if __name__ == "__main__":
    unittest.main()
