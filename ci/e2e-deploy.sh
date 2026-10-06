#!/usr/bin/env bash
# Actually install emacs-camp on the CI runner the same way a downstream would,
# using nix-basecamp's builder plus this module for the runner's user.
#   Linux: basecamp.lib.mkHome (emacs = nox) -> activate Home Manager.
#   macOS: basecamp.lib.mkDarwin (emacs = gui) -> activate nix-darwin (sudo).
# ECAMP_WITH_AGENTS=1 adds agent-camp with its CI set (claude, codex, pi,
# goose and their ACP adapters) and exports AGENT_CAMP_PATH.
# After that, wait for the background package sync and list the result.
set -euo pipefail
user="$(id -un)"
flake="$(pwd)"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
t0=$SECONDS
mods="f.homeModules.default"
if [ "${ECAMP_WITH_AGENTS:-}" = 1 ]; then
  mods="$mods f.inputs.agent-camp.homeModules.default f.inputs.agent-camp.lib.ciSettings"
fi

case "$(uname -s)" in
  Linux)
    out="$(nix build --impure --no-link --print-out-paths --expr "
      let f = builtins.getFlake \"path:$flake\"; in
      (f.inputs.basecamp.lib.mkHome {
        user = \"$user\"; homeDirectory = \"$HOME\"; emacs = \"nox\";
        modules = [ $mods ];
      }).activationPackage")"
    "$out/activate"
    emacs="$HOME/.nix-profile/bin/emacs"
    ;;
  Darwin)
    top="$(nix build --impure --no-link --print-out-paths --expr "
      let f = builtins.getFlake \"path:$flake\"; in
      (f.inputs.basecamp.lib.mkDarwin {
        user = \"$user\"; emacs = \"gui\";
        modules = [ { home-manager.sharedModules = [ $mods ]; } ];
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
if [ "${ECAMP_WITH_AGENTS:-}" = 1 ]; then
  echo "AGENT_CAMP_PATH=$HOME/.bun/bin:$HOME/.local/share/fnm/aliases/default/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$user/bin:$PATH" >> "${GITHUB_ENV:-/dev/null}"
fi
{
  echo "### deploy ($(uname -s))"
  echo "| step | seconds |"; echo "|---|---|"
  echo "| build + activate | $deployed |"
  echo "| + background package sync done | $synced |"
  echo
  echo '```'; (cd "$HOME/.config/emacs" && find . -maxdepth 2 ! -path './elpa/*/*' ! -path './eln-cache/*/*' | sort); echo '```'
} >> "$summary"
