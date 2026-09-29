#!/usr/bin/env python3
"""qmllint-ci.py — run Qt6 qmllint over every .qml file and gate on hard errors.

Without a qmldir for the singletons (deferred), qmllint is noisy: singleton,
unqualified-access and missing-property warnings are false positives today. So
this fails only on FATAL ids (syntax errors) and prints a per-id count of
everything else, so the gate can be tightened as the noise is removed.
"""
import collections
import json
import os
import pathlib
import subprocess
import sys
import tempfile

FATAL = {"syntax"}
ROOT = pathlib.Path(__file__).resolve().parent.parent
QMLLINT = os.environ.get("QMLLINT", "/usr/lib/qt6/bin/qmllint")


def main():
    files = sorted(str(p.relative_to(ROOT)) for p in ROOT.rglob("*.qml")
                   if not any(part.startswith(".") for part in p.relative_to(ROOT).parts))
    with tempfile.NamedTemporaryFile(suffix=".json") as out:
        subprocess.run([QMLLINT, "--json", out.name, *files], cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        report = json.load(open(out.name))
    counts = collections.Counter()
    fatal = []
    for f in report.get("files", []):
        for w in f.get("warnings", []):
            wid = w.get("id") or w.get("type", "?")
            counts[wid] += 1
            if wid in FATAL:
                fatal.append(f"{f['filename']}:{w.get('line', '?')}:{w.get('column', '?')}: {w['message']}")
    print(f"qmllint: {len(files)} files")
    for wid, n in counts.most_common():
        print(f"  {n:5d}  {wid}{'  (FATAL)' if wid in FATAL else ''}")
    for line in fatal:
        print(f"::error::{line}")
    return 1 if fatal else 0


if __name__ == "__main__":
    sys.exit(main())
