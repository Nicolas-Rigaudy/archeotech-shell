"""Tests for scripts/storage-scan.py (item_181). Run: python3 -m unittest discover tests/py

Every test runs on a temp $HOME with its own XDG dirs and only the source files
it writes (--no-user-sources, no shipped list unless asked), so nothing on the
real machine is scanned beyond `du`/`statvfs` of the temp folders."""
import contextlib
import importlib.util
import io
import json
import os
import pathlib
import subprocess
import tempfile
import unittest
from unittest import mock

_p = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "storage-scan.py"
_spec = importlib.util.spec_from_file_location("storage_scan", _p)
ss = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ss)

MB = 1024 * 1024


def blob(path, size):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        f.write(os.urandom(size))           # real blocks, so du agrees with the size


class TempHome(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = os.path.realpath(self.tmp.name)
        env = {"HOME": self.home, "XDG_CACHE_HOME": "", "XDG_DATA_HOME": "",
               "XDG_CONFIG_HOME": "", "XDG_STATE_HOME": "", "UV_CACHE_DIR": ""}
        self.env = mock.patch.dict(os.environ, env)
        self.env.start()
        for k in [k for k in os.environ if k.startswith("XDG_") and k.endswith("_DIR")]:
            del os.environ[k]
        ss.setup_env()

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def h(self, rel):
        return os.path.join(self.home, rel)

    def sources(self, items, name="extra.json"):
        f = self.h(name)
        with open(f, "w") as fh:
            json.dump({"sources": items}, fh)
        return f

    def scan(self, *args, shipped=False):
        argv = ["--no-user-sources", "--timeout", "20"] + list(args)
        out = io.StringIO()
        target = ss.SHIPPED if shipped else self.h("none.json")
        with mock.patch.object(ss, "SHIPPED", target), contextlib.redirect_stdout(out):
            code = ss.main(argv)
        return code, json.loads(out.getvalue())


class SourceFormat(TempHome):
    def test_check_source(self):
        ok = {"id": "x", "label": "X", "path": "~/x", "tier": "safe", "action": "remove"}
        self.assertIsNone(ss.check_source(ok))
        self.assertIn("tier", ss.check_source(dict(ok, tier="maybe")))
        self.assertIn("action", ss.check_source(dict(ok, action="shred")))
        self.assertIn("needs a command", ss.check_source(dict(ok, action="command")))
        self.assertIn("no path", ss.check_source({k: v for k, v in ok.items() if k != "path"}))
        self.assertIn("no label", ss.check_source(dict(ok, label="")))
        self.assertIn("children", ss.check_source(dict(ok, action="open", children={})))
        self.assertIn("object", ss.check_source(dict(ok, children=True)))
        self.assertIsNone(ss.check_source({"id": "x", "disabled": True}), "a disabling stub needs only the id")
        self.assertIsNone(ss.check_source({"id": "c", "label": "C", "tier": "review", "action": "command",
                                           "command": "true"}), "a command source needs no path")

    def test_merge_override_disable_and_errors(self):
        a = self.sources([{"id": "one", "label": "One", "path": "~/a", "tier": "safe", "action": "remove"},
                          {"id": "two", "label": "Two", "path": "~/b", "tier": "safe", "action": "remove"}], "a.json")
        b = self.sources([{"id": "one", "label": "Mine", "path": "~/c", "tier": "review", "action": "trash"},
                          {"id": "two", "disabled": True},
                          {"id": "bad", "label": "Bad", "tier": "nope", "action": "remove", "path": "~/d"}], "b.json")
        broken = self.h("broken.json")
        pathlib.Path(broken).write_text("{not json")
        errors = []
        got = ss.load_sources([a, b, broken, self.h("missing.json")], errors)
        self.assertEqual([s["id"] for s in got], ["one"])
        self.assertEqual(got[0]["label"], "Mine", "a later file replaces the same id")
        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(any("bad: tier" in e for e in errors))
        self.assertTrue(any("broken.json" in e for e in errors))

    def test_candidates_expand_glob_and_unset_vars(self):
        for d in (".cdx/profiles/.a.remove.1", ".cdx/profiles/.b.remove.2", ".cdx/profiles/keep"):
            os.makedirs(self.h(d))
        s = {"path": "~/.cdx/profiles/.*.remove.*", "glob": True}
        self.assertEqual([os.path.basename(p) for p in ss.candidates(s)], [".a.remove.1", ".b.remove.2"])
        os.makedirs(self.h(".cache/uv"))
        self.assertEqual(ss.candidates({"paths": ["$UV_CACHE_DIR", "$XDG_CACHE_HOME/uv"]}), [self.h(".cache/uv")],
                         "an empty XDG_CACHE_HOME means ~/.cache; an unset variable drops the path")
        self.assertEqual(ss.candidates({"path": "~/nothing"}), [])

    def test_commands_are_quoted(self):
        p = self.h("odd name; rm -rf ~")
        self.assertEqual(ss.commands_for({"action": "remove"}, [p]), ["rm -rf -- '%s'" % p])
        self.assertEqual(ss.commands_for({"action": "trash"}, [p]), ["gio trash -- '%s'" % p])
        self.assertEqual(ss.commands_for({"action": "command", "command": "uv cache clean --cache-dir {path}"},
                                         ["/a", "/b c"]),
                         ["uv cache clean --cache-dir /a", "uv cache clean --cache-dir '/b c'"])
        self.assertEqual(ss.commands_for({"action": "command", "command": "gio trash --empty"}, ["/x"]),
                         ["gio trash --empty"])
        self.assertEqual(ss.commands_for({"action": "open"}, ["/x"]), [])

    def test_shipped_sources_are_valid(self):
        errors = []
        got = ss.load_sources([str(_p.parent / "storage-sources.json")], errors)
        self.assertEqual(errors, [])
        ids = {s["id"] for s in got}
        for need in ("pacman", "paru", "yay", "journal", "trash", "uv", "pip", "npm", "flatpak",
                     "docker", "snapper", "app-caches", "downloads"):
            self.assertIn(need, ids)
        for s in got:
            if s["action"] in ("remove", "trash"):
                self.assertFalse(s.get("root"), "%s: root sources run a command, never rm" % s["id"])


class Guard(TempHome):
    def test_personal_and_system_paths_are_refused(self):
        for p in ("/", "/usr", "/var/cache", self.home, os.path.dirname(self.home), self.h("Documents"),
                  self.h("Documents/old"), self.h("Downloads"), self.h(".config"), self.h(".ssh"),
                  self.h(".cache"), self.h(".local/share")):
            self.assertIsNotNone(ss.personal_reason(p), p)
        for p in (self.h(".ssh/id_rsa"), self.h(".gnupg/private-keys-v1.d"), self.h(".config/zen"),
                  self.h(".local/bin/tool"), "/home/someone-else/cache", "/root/.cache"):
            self.assertIsNotNone(ss.personal_reason(p), "%s: inside a kept folder" % p)
        for p in (self.h(".cache/zen"), self.h(".npm/_cacache"), self.h(".local/share/Trash"), "/var/cache/pacman/pkg"):
            self.assertIsNone(ss.personal_reason(p), p)

    def test_children_base_must_be_a_cache_area(self):
        blob(self.h("Projects/code/a"), 2 * MB)
        blob(self.h("dev/a"), 2 * MB)
        blob(self.h(".local/share/app/x/a"), 2 * MB)
        f = self.sources([
            {"id": "h", "label": "Home", "path": "~", "tier": "safe", "action": "remove", "children": {}},
            {"id": "data", "label": "Data", "path": "$XDG_DATA_HOME", "tier": "review", "action": "trash",
             "children": {}},
            {"id": "app", "label": "App", "path": "$XDG_DATA_HOME/app", "tier": "review", "action": "trash",
             "children": {}}])
        _, d = self.scan("--sources", f)
        self.assertEqual([e["source"] for e in d["entries"]], ["app"])
        self.assertEqual(sorted(r["id"] for r in d["rejected"]), ["data", "h"])
        self.assertNotIn("safe", [c.get("tier") for c in d["tree"]["children"] if c["name"] in ("Projects", "dev")],
                         "a refused base colours nothing")

    def test_a_command_given_the_path_is_guarded(self):
        f = self.sources([{"id": "c", "label": "C", "path": "~", "tier": "safe", "action": "command",
                           "command": "tool clean --dir {path}"}])
        _, d = self.scan("--sources", f)
        self.assertEqual(d["entries"], [])
        self.assertEqual([r["id"] for r in d["rejected"]], ["c"])

    def test_detail_command_quotes_the_path(self):
        os.makedirs(self.h("junk/a;touch pwned"))
        f = self.sources([{"id": "g", "label": "{name}", "path": "~/junk/*", "glob": True, "tier": "review",
                           "action": "trash", "detail_command": "echo {name}"}])
        _, d = self.scan("--sources", f)
        self.assertEqual(d["entries"][0]["detail"], "a;touch pwned")
        self.assertFalse(os.path.exists("pwned") or os.path.exists(self.h("pwned")))

    def test_user_dirs_file_adds_folders(self):
        cfg = self.h(".config")
        os.makedirs(cfg)
        pathlib.Path(cfg, "user-dirs.dirs").write_text('XDG_PROJECTS_DIR="$HOME/Projects"\nXDG_MUSIC_DIR="$HOME"\n')
        self.assertIn("personal folder", ss.personal_reason(self.h("Projects/x")))
        self.assertIsNone(ss.personal_reason(self.h("Music")), "a user dir set to $HOME is not a folder of its own")

    def test_a_personal_source_is_rejected_not_offered(self):
        blob(self.h("Documents/thesis.pdf"), MB)
        blob(self.h(".cache/app/x"), MB)
        f = self.sources([
            {"id": "evil", "label": "Docs", "path": "$XDG_DOCUMENTS_DIR", "tier": "safe", "action": "remove"},
            {"id": "evil2", "label": "Home", "path": "~", "tier": "safe", "action": "trash"},
            {"id": "ok", "label": "App", "path": "~/.cache/app", "tier": "safe", "action": "remove"},
            {"id": "dl", "label": "Downloads", "path": "$XDG_DOCUMENTS_DIR", "tier": "review", "action": "open"}])
        _, d = self.scan("--sources", f)
        self.assertEqual(sorted(e["source"] for e in d["entries"]), ["dl", "ok"])
        self.assertEqual(sorted(r["id"] for r in d["rejected"]), ["evil", "evil2"])
        for e in d["entries"]:
            for c in e["commands"]:
                self.assertNotIn("Documents", c)


class Entries(TempHome):
    def test_user_source_appears_with_size_cost_and_flags(self):
        blob(self.h(".cdx/shared-cache/uv/a"), 2 * MB)
        blob(self.h(".cdx/profiles/.old.remove.abc/x"), 3 * MB)
        blob(self.h(".cdx/profiles/.new.remove.def/x"), MB)
        blob(self.h(".pkgs/p"), MB)
        f = self.sources([
            {"id": "cdx", "label": "Old cdx profile {name}", "path": "~/.cdx/profiles/.*.remove.*", "glob": True,
             "tier": "review", "action": "trash", "cost": "Left over from {mtime}"},
            {"id": "uv-cdx", "label": "uv cache (cdx)", "path": "~/.cdx/shared-cache/uv", "tier": "safe",
             "action": "remove", "cost": "Downloads again"},
            {"id": "pac", "label": "pkgs", "path": self.h(".pkgs"), "tier": "safe", "action": "command",
             "command": "paccache -rk2", "root": True, "upto": True, "size": "none"}])
        _, d = self.scan("--sources", f)
        by = {e["id"]: e for e in d["entries"]}
        self.assertEqual(set(by), {"cdx:.old.remove.abc", "cdx:.new.remove.def", "uv-cdx", "pac"})
        old = by["cdx:.old.remove.abc"]
        self.assertEqual(old["label"], "Old cdx profile .old.remove.abc")
        self.assertGreaterEqual(old["bytes"], 3 * MB)
        self.assertRegex(old["cost"], r"Left over from \d{4}-\d\d-\d\d")
        self.assertFalse(old["checked"], "review rows start unticked")
        self.assertTrue(old["user"])
        self.assertTrue(by["uv-cdx"]["checked"], "safe rows with a size start ticked")
        self.assertTrue(by["pac"]["root"] and by["pac"]["upto"])
        self.assertIsNone(by["pac"]["bytes"])
        self.assertFalse(by["pac"]["checked"], "a row without a size is never pre-ticked")
        tiers = [e["tier"] for e in d["entries"]]
        self.assertEqual(tiers, sorted(tiers, key=ss.TIERS.index), "safe rows first")

    def test_children_group_skips_paths_other_sources_own(self):
        blob(self.h(".cache/big/a"), 3 * MB)
        blob(self.h(".cache/small/a"), MB // 4)
        blob(self.h(".cache/paru/clone/pkg"), 2 * MB)
        blob(self.h(".cache/paru/other"), 2 * MB)
        blob(self.h(".cache/skip/a"), 3 * MB)
        f = self.sources([
            {"id": "caches", "label": "App caches", "path": "$XDG_CACHE_HOME", "tier": "safe", "action": "remove",
             "children": {"min_bytes": MB, "exclude": ["$XDG_CACHE_HOME/skip"]}},
            {"id": "paru", "label": "paru", "path": "$XDG_CACHE_HOME/paru/clone", "tier": "safe", "action": "remove"}])
        _, d = self.scan("--sources", f)
        by = {e["id"]: e for e in d["entries"]}
        self.assertEqual(by["caches"]["paths"], [self.h(".cache/big")],
                         "paru holds another source's folder, small is under min_bytes, skip is excluded")
        self.assertEqual(by["caches"]["detail"], "big")
        self.assertIn("paru", by)

    def test_a_nested_path_is_counted_once(self):
        blob(self.h(".cache/tool/sub/a"), 2 * MB)
        f = self.sources([
            {"id": "outer", "label": "O", "path": "~/.cache/tool", "tier": "safe", "action": "remove"},
            {"id": "inner", "label": "I", "path": "~/.cache/tool/sub", "tier": "safe", "action": "remove"}])
        _, d = self.scan("--sources", f)
        self.assertEqual([e["id"] for e in d["entries"]], ["outer"])

    def test_requires_hides_missing_tools(self):
        f = self.sources([{"id": "fp", "label": "Flatpak", "requires": "no-such-tool-xyz", "size": "none",
                           "tier": "safe", "action": "command", "command": "true"}])
        _, d = self.scan("--sources", f)
        self.assertEqual(d["entries"], [])


class Tree(TempHome):
    def setUp(self):
        super().setUp()
        blob(self.h("Projects/a/big.bin"), 4 * MB)
        blob(self.h("Projects/b/mid.bin"), 2 * MB)
        blob(self.h("Documents/doc.pdf"), MB)
        blob(self.h(".cache/zen/c"), 3 * MB)
        blob(self.h("loose.iso"), 2 * MB)
        for i in range(30):
            blob(self.h("many/d%02d/f" % i), 8192 * (i + 1))

    def test_sizes_add_up_and_tiers_colour_the_tree(self):
        f = self.sources([{"id": "caches", "label": "App caches", "path": "$XDG_CACHE_HOME", "tier": "safe",
                           "action": "remove", "children": {"min_bytes": 1}}])
        _, d = self.scan("--sources", f)
        t = d["tree"]
        self.assertTrue(t["complete"])
        self.assertEqual(t["path"], self.home)
        self.assertEqual(sum(c["bytes"] for c in t["children"]), t["bytes"], "children cover the folder exactly")
        names = [c["name"] for c in t["children"]]
        self.assertEqual(names[0], "Projects", "largest first")
        self.assertIn("loose.iso", names, "the top folder names its own files")
        by = {c["name"]: c for c in t["children"]}
        self.assertEqual(by["loose.iso"]["kind"], "file")
        self.assertEqual(by["Documents"]["tier"], "personal")
        zen = next(c for c in by[".cache"]["children"] if c["name"] == "zen")
        self.assertEqual(zen["tier"], "safe")
        many = by["many"]["children"]
        more = [c for c in many if c["kind"] == "more"]
        self.assertEqual(len(more), 1, "past the kept children the rest is one box")
        self.assertEqual(more[0]["name"], "%d more folders" % (30 - ss.KEEP[1]))
        self.assertEqual(sum(c["bytes"] for c in many), by["many"]["bytes"])

    def test_scoped_tree_has_no_entries(self):
        code, d = self.scan("--tree", self.h("Projects"), "--depth", "2")
        self.assertEqual(code, 0)
        self.assertNotIn("entries", d)
        self.assertEqual([c["name"] for c in d["tree"]["children"]], ["a", "b"])
        a = d["tree"]["children"][0]
        self.assertGreaterEqual(a["bytes"], 4 * MB)
        self.assertNotIn("children", a, "below the top folder only subfolders get boxes")
        code, d = self.scan("--tree", self.h("nope"))
        self.assertEqual(code, 1)
        self.assertIn("no such folder", d["error"])

    def test_depth_limits_nesting(self):
        _, d = self.scan("--depth", "1")
        self.assertTrue(all("children" not in c for c in d["tree"]["children"]))


class Partial(TempHome):
    def test_timeout_keeps_what_du_printed(self):
        real = subprocess.run

        def slow(cmd, **kw):
            if cmd[:2] == ["du", "-xb"] and "--max-depth=3" in cmd:
                raise subprocess.TimeoutExpired(cmd, 1, output=b"100\t%s/x/y\n300\t%s/x\n" % (
                    self.home.encode(), self.home.encode()))
            return real(cmd, **kw)

        with mock.patch.object(ss.subprocess, "run", side_effect=slow):
            _, d = self.scan()
        self.assertTrue(d["partial"])
        self.assertFalse(d["tree"]["complete"])
        self.assertEqual(d["tree"]["bytes"], 300, "a missing parent line is the sum of what was printed")

    def test_root_mode_is_free_space_only(self):
        _, d = self.scan("--root")
        self.assertEqual(set(d), {"version", "generated", "root"})
        r = d["root"]
        self.assertGreater(r["size"], 0)
        self.assertEqual(r["free_pct"] + r["used_pct"], 100)

    def test_bad_mount_reports_an_error(self):
        code, d = self.scan("--root", "--mount", self.h("no-such-mount"))
        self.assertEqual(code, 1)
        self.assertIn("cannot read free space", d["error"])


if __name__ == "__main__":
    unittest.main()
