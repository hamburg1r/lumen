import os
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import chrome


class ConfigTests(unittest.TestCase):
    def test_defaults_and_overrides(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp) / "lumen"
            directory.mkdir()
            (directory / "theme.toml").write_text('[theme]\naccent = "#123456"\nradius = 26\nbackground_opacity = 0.5\n')
            (directory / "shell.toml").write_text('[modules]\nnetwork = false\n')
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp}):
                actual = chrome.config()
            self.assertEqual(actual["theme"]["accent"], "#123456")
            self.assertEqual(actual["theme"]["radius"], 26)
            self.assertEqual(actual["theme"]["background_opacity"], 0.5)
            self.assertEqual(actual["theme"]["surface"], chrome.DEFAULT_THEME["surface"])
            self.assertFalse(actual["modules"]["network"])
            self.assertTrue(actual["modules"]["workspaces"])

    def test_invalid_types_and_missing_files_keep_defaults(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp) / "lumen"
            directory.mkdir()
            (directory / "theme.toml").write_text('[theme]\nradius = "large"\nbackground_opacity = 2.0\n')
            (directory / "shell.toml").write_text('[modules]\nnetwork = 1\n')
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp}):
                actual = chrome.config()
            self.assertEqual(actual["theme"]["radius"], chrome.DEFAULT_THEME["radius"])
            self.assertEqual(actual["theme"]["background_opacity"], chrome.DEFAULT_THEME["background_opacity"])
            self.assertTrue(actual["modules"]["network"])

    def test_input_watcher_emits_only_changes(self):
        output = io.StringIO()
        states = iter([{"caps": False, "brightness": 30},
                       {"caps": False, "brightness": 30},
                       {"caps": True, "brightness": 30}])
        def stop_after_third(_):
            if len(output.getvalue().splitlines()) == 2:
                raise StopIteration

        with patch.object(chrome, "input_state", side_effect=lambda: next(states)), \
             patch("time.sleep", side_effect=stop_after_third), \
             patch("sys.stdout", output), \
             self.assertRaises(StopIteration):
            chrome.watch_input()
        self.assertEqual([json.loads(line) for line in output.getvalue().splitlines()],
                         [{"caps": False, "brightness": 30},
                          {"caps": True, "brightness": 30}])

    def test_daemon_history_and_dismiss(self):
        with patch.object(chrome, "bus_value", return_value='[{"id":1,"summary":"Hi"}]'):
            self.assertEqual(chrome.history()[0]["summary"], "Hi")
        with patch.object(chrome, "bus_value", return_value=None):
            self.assertEqual(chrome.history(), [])
        with patch.object(chrome, "bus_value", return_value=True) as call:
            self.assertTrue(chrome.dismiss(42))
            self.assertEqual(call.call_args.args[-2:], ("u", "42"))

    def test_input_caps_comes_from_daemon(self):
        with patch.object(chrome, "bus_value", return_value=True) as call:
            self.assertTrue(chrome.input_state()["caps"])
            self.assertEqual(call.call_args.args,
                             ("/org/lumen/Input", "org.lumen.Input", "GetCapsLock"))


if __name__ == "__main__":
    unittest.main()
