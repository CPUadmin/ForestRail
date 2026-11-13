"""Tests of tools/devenv.py: python -m unittest tools/test_devenv.py"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import devenv  # noqa: E402


class DevenvTest(unittest.TestCase):
    def test_missing_settings_message(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(SystemExit) as caught:
                devenv.godot_path(Path(folder) / "local_settings.json")
            text = str(caught.exception)
            self.assertIn("local_settings.json", text)
            self.assertIn("godot", text)

    def test_missing_exe_message(self):
        with tempfile.TemporaryDirectory() as folder:
            settings = Path(folder) / "local_settings.json"
            settings.write_text('{"godot": "C:/nowhere/Godot.exe"}', encoding="utf-8")
            with self.assertRaises(SystemExit) as caught:
                devenv.godot_path(settings)
            self.assertIn("C:/nowhere/Godot.exe", str(caught.exception))

    def test_list_suites_has_known(self):
        suites = devenv.list_suites()
        self.assertIn("check_model", suites)
        self.assertIn("drive_campaign", suites)
        self.assertNotIn("check_save_p8", suites)
        self.assertNotIn("check_soak_p8", suites)
        self.assertNotIn("check_perf", suites)
        self.assertFalse([s for s in suites if s.startswith("probe_")])

    def test_unknown_suites(self):
        self.assertEqual(devenv.unknown_suites(["check_model", "check_hud"]), ["check_hud"])


if __name__ == "__main__":
    unittest.main()
