"""Prefix root-absolute asset references in a built site so it can be served
from a sub-path such as https://<user>.github.io/<repo>/.

Only references to entries that actually exist at the top level of the build
output are rewritten, so external URLs and API routes are left alone.
Usage: python3 rebase-paths.py <dist-dir> </repo/>
"""
import os
import re
import sys

root, base = sys.argv[1], sys.argv[2]
if not base.endswith("/"):
    base += "/"
names = [n for n in os.listdir(root) if n not in ("index.html", ".nojekyll")]
if not names:
    sys.exit(0)
alt = "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))
# A quote, backtick or "(" followed by "/<top-level entry>" and then a boundary.
ref = re.compile(r"""(?<=["'`(])/(?=(?:%s)(?:[/?#"'`)]|$))""" % alt)
root_only = re.compile(r"""(?<=["'`])/(?=["'`])""")
TEXT = (".html", ".js", ".mjs", ".css", ".json", ".webmanifest", ".svg", ".txt")

changed = 0
for dirpath, _, files in os.walk(root):
    for f in files:
        if not f.endswith(TEXT):
            continue
        p = os.path.join(dirpath, f)
        with open(p, encoding="utf-8", errors="surrogateescape") as fh:
            s = fh.read()
        t = ref.sub(base, s)
        if f in ("sw.js", "service-worker.js"):
            t = root_only.sub(base, t)
        if t != s:
            with open(p, "w", encoding="utf-8", errors="surrogateescape") as fh:
                fh.write(t)
            changed += 1
print(f"rebase-paths: prefixed references in {changed} file(s) with {base}")
