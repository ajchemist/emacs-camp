#!/usr/bin/env bash
# Deploy emacs-camp for real onto the CI runner, the way a downstream does:
# nix-basecamp's builder + this module, for the runner's own user.
#   Linux: basecamp.lib.mkHome (emacs = nox) -> activate Home Manager.
#   macOS: basecamp.lib.mkDarwin (emacs = gui) -> activate nix-darwin (sudo).
# Then waits for the background package sync and prints where things landed.
set -euo pipefail
user="$(id -un)"
flake="$(pwd)"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
t0=$SECONDS

case "$(uname -s)" in
  Linux)
    out="$(nix build --impure --no-link --print-out-paths --expr "
      let f = builtins.getFlake \"path:$flake\"; in
      (f.inputs.basecamp.lib.mkHome {
        user = \"$user\"; homeDirectory = \"$HOME\"; emacs = \"nox\";
        modules = [ f.homeModules.default ];
      }).activationPackage")"
    "$out/activate"
    emacs="$HOME/.nix-profile/bin/emacs"
    ;;
  Darwin)
    top="$(nix build --impure --no-link --print-out-paths --expr "
      let f = builtins.getFlake \"path:$flake\"; in
      (f.inputs.basecamp.lib.mkDarwin {
        user = \"$user\"; emacs = \"gui\";
        modules = [ { home-manager.sharedModules = [ f.homeModules.default ]; } ];
      }).system")"
    for f in /etc/bashrc /etc/zshrc /etc/zshenv; do
      if [ -f "$f" ] && [ ! -L "$f" ]; then sudo mv "$f" "$f.before-nix-darwin"; fi
    done
    sudo -H nix-env --profile /nix/var/nix/profiles/system --set "$top"
    sudo -H "$top/activate"
    emacs=/run/current-system/sw/bin/emacs
    ;;
esac
deployed=$((SECONDS - t0))

cache="${XDG_CACHE_HOME:-$HOME/.cache}/emacs-camp"
for _ in $(seq 1 200); do
  [ -f "$cache/sync.log" ] && ! kill -0 "$(cat "$cache/sync.pid" 2>/dev/null)" 2>/dev/null && break
  sleep 3
done
synced=$((SECONDS - t0))
cat "$cache/sync.log"
grep -q '^emacs-camp sync: done' "$cache/sync.log"
if [ "$(uname -s)" = Darwin ]; then grep -q '^emacs-camp sync: warmed' "$cache/sync.log"; fi

echo "EMACS=$emacs" >> "${GITHUB_ENV:-/dev/null}"
{
  echo "### deploy ($(uname -s))"
  echo "| step | seconds |"; echo "|---|---|"
  echo "| build + activate | $deployed |"
  echo "| + background package sync done | $synced |"
  echo
  echo '```'; (cd "$HOME/.config/emacs" && find . -maxdepth 2 ! -path './elpa/*/*' ! -path './eln-cache/*/*' | sort); echo '```'
} >> "$summary"
