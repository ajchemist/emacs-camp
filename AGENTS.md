## Agent skills

Skills live once, in `.agents/skills/`, which every agent that honours it
reads; `.claude/skills` is a symlink to it for Claude Code. They are pinned
in `skills-lock.json` and not committed: restore them with
`bunx skills experimental_install`, update with `bunx skills update -p`.

The engineering skills ([mattpocock/skills](https://github.com/mattpocock/skills))
and [ponytail](https://github.com/DietrichGebert/ponytail) are Claude Code
plugins enabled for this project in `.claude/settings.json`.

### Issue tracker

Issues are tracked in GitHub Issues for ajchemist/emacs-camp (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one root `GLOSSARY.md` plus `docs/adr/`, created lazily. See `docs/agents/domain.md`.
