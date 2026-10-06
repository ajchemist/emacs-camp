#!/usr/bin/env bash
# macOS only: time the first-dlopen check that the warm-up is there to avoid.
# A new .eln is opened twice; the check costs only on the first open.
set -euo pipefail
emacs="${EMACS:-emacs}"
d="$(mktemp -d)"
printf ';;; -*- lexical-binding: t -*-\n(defun vet-probe () %s)\n' "$RANDOM$RANDOM" > "$d/vet-probe.el"
"$emacs" --batch --eval "(native-compile \"$d/vet-probe.el\" \"$d/vet-probe.eln\")" >/dev/null 2>&1
t() { /usr/bin/python3 - "$1" <<'PY'
import ctypes, sys, time
t = time.perf_counter(); ctypes.CDLL(sys.argv[1]); print(f"{time.perf_counter() - t:.3f}")
PY
}
first="$(t "$d/vet-probe.eln")"; second="$(t "$d/vet-probe.eln")"
echo "first dlopen ${first}s, second ${second}s"
{ echo "### macOS .eln vetting"; echo "| first dlopen | second dlopen |"; echo "|---|---|"; echo "| ${first}s | ${second}s |"; } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
