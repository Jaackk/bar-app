import importlib.util
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("monitor", Path(__file__).with_name("check-menu-updates.py"))
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


class MonitorTests(unittest.TestCase):
    def test_discovers_new_url_and_nested_label(self):
        rows = monitor.menu_links('<a href="/menus/new.pdf"><span>Drinks Menu</span></a><a href="/food.pdf">Lunch</a>')
        self.assertEqual(rows, [{"label": "Drinks Menu", "url": "https://www.rockwater.uk/menus/new.pdf"}])

    def test_same_url_change_is_detected(self):
        before = {"menus": [{"url": "x", "sha256": "old"}]}
        after = {"menus": [{"url": "x", "sha256": "new"}]}
        self.assertEqual(len(monitor.differences(before, after)["changed"]), 1)

    def test_removed_and_added_links_need_review(self):
        delta = monitor.differences({"menus": [{"url": "old", "sha256": "a"}]}, {"menus": [{"url": "new", "sha256": "a"}]})
        self.assertEqual(len(delta["added"]), 1)
        self.assertEqual(len(delta["removed"]), 1)

    def test_unchanged_and_missing_main_link(self):
        state = {"menus": [{"url": "x", "sha256": "same"}]}
        self.assertFalse(any(monitor.differences(state, state).values()))
        with self.assertRaises(ValueError):
            monitor.menu_links('<a href="/pub.pdf">The Pub Menu</a>')

    def test_failure_never_accepts_or_overwrites_baseline(self):
        with TemporaryDirectory() as temp:
            target = Path(temp)
            baseline = target / "reviewed-baseline.json"
            baseline.write_text('{"menus": []}', encoding="utf-8")
            with patch.object(monitor, "fetch", side_effect=OSError("offline")), patch("builtins.print"):
                self.assertEqual(monitor.check(target, accept=True), 2)
            self.assertEqual(baseline.read_text(encoding="utf-8"), '{"menus": []}')

    def test_rejects_foreign_and_insecure_urls(self):
        self.assertFalse(monitor.official("https://rockwater.uk.evil.test/a.pdf"))
        self.assertFalse(monitor.official("http://rockwater.uk/a.pdf"))
        self.assertFalse(monitor.official("https://user@rockwater.uk/a.pdf"))
        with self.assertRaises(ValueError):
            monitor.menu_links('<a href="https://other.test/x.pdf">Drinks Menu</a>')


if __name__ == "__main__":
    unittest.main()
