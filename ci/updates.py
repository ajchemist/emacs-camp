#!/usr/bin/env python3
"""Weekly update briefing: the pinned elpa-mirror commit against the mirror's HEAD.

Usage: updates.py [--tickets]   (run from the repository root)
Prints a Markdown summary. --tickets keeps the one update ticket, found by the labels
`update` + `update:elpa-mirror` (agent-camp's docs/adr/0001, our docs/adr/0004).
The mirror commits every few hours, so the pin counts as behind only once it is
STALE_DAYS older than HEAD; that keeps the ticket to one rewrite a week at most.
"""
import json, os, re, subprocess, sys, urllib.request
from datetime import datetime, timezone

MIRROR = "d12frosted/elpa-mirror"
STALE_DAYS = 7

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "emacs-camp"})
    if os.environ.get("GITHUB_TOKEN"):
        req.add_header("Authorization", "Bearer " + os.environ["GITHUB_TOKEN"])
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

def commit(ref):
    d = get(f"https://api.github.com/repos/{MIRROR}/commits/{ref}")
    return d["sha"], datetime.fromisoformat(d["commit"]["committer"]["date"].replace("Z", "+00:00"))

def pinned():
    return re.search(r'\(defconst ecamp-elpa-snapshot "([0-9a-f]{40})"\)', open("lisp/init.el").read()).group(1)

def link(sha):
    return f"[`{sha[:7]}`](https://github.com/{MIRROR}/commit/{sha})"

def main():
    pin, pin_date = commit(pinned())
    head, head_date = commit("HEAD")
    days = (head_date - pin_date).days
    print(f"## elpa-mirror update briefing — {datetime.now(timezone.utc):%Y-%m-%d}\n")
    print("| | Commit | Date |\n|---|---|---|")
    print(f"| Pinned (`ecamp-elpa-snapshot`) | {link(pin)} | {pin_date:%Y-%m-%d} |")
    print(f"| Mirror HEAD | {link(head)} | {head_date:%Y-%m-%d} |")
    print(f"\nThe pin is {days} days behind; it needs a bump at {STALE_DAYS} or more.")
    if "--tickets" in sys.argv:
        sync_ticket(pin, pin_date, head, head_date, days >= STALE_DAYS)

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout

def sync_ticket(pin, pin_date, head, head_date, stale):
    """One open update ticket: open it, rewrite it as the mirror moves, close it once the pin is fresh."""
    found = json.loads(run("gh", "issue", "list", "--state", "open", "--label", "update",
                           "--label", "update:elpa-mirror", "--json", "number,title,labels"))
    issue = found[0] if found else None
    if not stale:
        if issue:
            run("gh", "issue", "close", str(issue["number"]), "--comment",
                f"The pin {pin[:7]} ({pin_date:%Y-%m-%d}) is within {STALE_DAYS} days of the mirror's HEAD. Closing.")
        return
    title = f"Bump elpa-mirror {pin[:7]} → {head[:7]} ({head_date:%Y-%m-%d})"
    body = (f"The mirror's HEAD is {link(head)} ({head_date:%Y-%m-%d}); `ecamp-elpa-snapshot` in "
            f"`lisp/init.el` pins {link(pin)} ({pin_date:%Y-%m-%d}).\n\n"
            "Label this `approved` and automation opens the bump PR (`bump.yml`), which moves the pin to "
            "the mirror's HEAD at that time. Kept up to date by the weekly update briefing (docs/adr/0004).")
    if not issue:
        print(run("gh", "issue", "create", "--title", title, "--body", body, "--label", "update",
                  "--label", "update:elpa-mirror", "--label", "needs-triage"), file=sys.stderr)
        return
    if issue["title"] == title:
        return
    n = str(issue["number"])
    run("gh", "issue", "edit", n, "--title", title, "--body", body)
    run("gh", "issue", "comment", n, "--body", f"The mirror moved to {head[:7]} ({head_date:%Y-%m-%d}).")
    if any(l["name"] == "approved" for l in issue["labels"]):
        run("gh", "workflow", "run", "bump.yml")

if __name__ == "__main__":
    main()
