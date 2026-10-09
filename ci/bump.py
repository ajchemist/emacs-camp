#!/usr/bin/env python3
"""Move `ecamp-elpa-snapshot` in lisp/init.el to the elpa-mirror's HEAD (docs/adr/0004).

Usage: bump.py   (run from the repository root; prints "<sha7> (<date>)", or nothing if already current)
Before rewriting, checks that raw.githubusercontent.com serves melpa/archive-contents at that commit,
since that is the first URL every host fetches.
"""
import json, os, re, urllib.request

MIRROR = "d12frosted/elpa-mirror"
INIT = "lisp/init.el"
PIN = re.compile(r'\(defconst ecamp-elpa-snapshot "([0-9a-f]{40})"\)')

def fetch(url, method="GET"):
    req = urllib.request.Request(url, method=method, headers={"User-Agent": "emacs-camp"})
    if "api.github.com" in url and os.environ.get("GITHUB_TOKEN"):
        req.add_header("Authorization", "Bearer " + os.environ["GITHUB_TOKEN"])
    with urllib.request.urlopen(req, timeout=60) as r:  # raises on 4xx/5xx
        return r.read()

def main():
    src = open(INIT).read()
    current = PIN.search(src).group(1)
    head = json.loads(fetch(f"https://api.github.com/repos/{MIRROR}/commits/HEAD"))
    sha, date = head["sha"], head["commit"]["committer"]["date"][:10]
    if sha == current:
        return
    fetch(f"https://raw.githubusercontent.com/{MIRROR}/{sha}/melpa/archive-contents", "HEAD")
    src, n = PIN.subn(f'(defconst ecamp-elpa-snapshot "{sha}")', src)
    assert n == 1, f"{INIT}: expected one ecamp-elpa-snapshot defconst, found {n}"
    open(INIT, "w").write(src)
    print(f"{sha[:7]} ({date})")

if __name__ == "__main__":
    main()
