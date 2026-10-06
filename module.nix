# Home Manager module for emacs-camp: puts lisp/ on top of nix-basecamp's Emacs.
# It relies on nothing but basecamp's contract (basecamp.emacs.package,
# .warmProgram); the downstream sets basecamp.emacs.enable/gui where it installs.
{ lib, config, pkgs, ... }:

let
  cfg = config.emacs-camp;
  emacs = config.basecamp.emacs.package;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  elnWarm = "${config.basecamp.emacs.warmProgram}/bin/eln-warm";
  userNames = map baseNameOf cfg.userFiles;

  # Compiled by the same Emacs that loads it, so a broken init breaks the switch
  # instead of the next launch. :ensure is disabled while compiling: the
  # sandbox is offline, and sync.el is what installs packages.
  compiled = pkgs.runCommand "emacs-camp-config" { nativeBuildInputs = [ emacs ]; } ''
    mkdir user
    cp ${./lisp}/*.el .
    ${lib.concatMapStringsSep "\n" (f: "cp ${f} user/${baseNameOf f}") cfg.userFiles}
    emacs --batch \
      --eval '(progn (require (quote use-package)) (setq use-package-ensure-function (quote ignore) byte-compile-error-on-warn t))' \
      -f batch-byte-compile ./*.el ${lib.optionalString (cfg.userFiles != [ ]) "user/*.el"}
    mkdir -p $out/user; cp ./*.el ./*.elc $out/
    ${lib.optionalString (cfg.userFiles != [ ]) "cp user/*.el user/*.elc $out/user/"}
  '';

  # All sources that get linked: early-init, init, user/*.
  linked = [ "early-init" "init" ] ++ map (n: "user/${lib.removeSuffix ".el" n}") userNames;
in
{
  options.emacs-camp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.basecamp.emacs.enable;
      description = "Deploy emacs-camp into ~/.config/emacs (defaults to basecamp.emacs.enable).";
    };
    userFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Downstream .el files, linked as ~/.config/emacs/user/<name> and loaded in name order after the core, before local.el.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = config.basecamp.emacs.enable;
      message = "emacs-camp needs nix-basecamp's Emacs: set basecamp.emacs.enable where the install happens.";
    }];

    # Only individual links; ~/.config/emacs remains a normal writable directory.
    xdg.configFile = lib.listToAttrs (map (f: lib.nameValuePair "emacs/${f}" { source = "${compiled}/${f}"; })
      (lib.concatMap (n: [ "${n}.el" "${n}.elc" ]) linked))
      // lib.optionalAttrs isDarwin { "emacs/eln-warm".source = elnWarm; };

    # An .eln's name depends on the path the source is loaded from
    # (~/.config/emacs/...), not a store path, so build it here whenever the
    # content changes and warm it immediately on macOS (init loads before a
    # startup hook would get the chance).
    home.activation.emacsCampNativeCompile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      for f in ${lib.escapeShellArgs linked}; do
        src="$HOME/.config/emacs/$f.el"
        eln="$(${emacs}/bin/emacs --batch --eval "(when (native-comp-available-p) (princ (comp-el-to-eln-filename \"$src\")))" 2>/dev/null || true)"
        if [ -n "$eln" ] && [ ! -f "$eln" ]; then
          # Reuse the byte-compile prelude; otherwise :ensure fires, packages
          # download in the middle of compiling, and the resulting .eln
          # requires all of them at startup.
          run ${emacs}/bin/emacs --batch \
            --eval '(progn (require (quote use-package)) (setq use-package-ensure-function (quote ignore)))' \
            -f batch-native-compile "$src" \
            || echo "emacs-camp: native-compile of $src failed; Emacs will JIT it instead" >&2
          ${lib.optionalString isDarwin ''[ -f "$eln" ] && run ${elnWarm} "$(dirname "$eln")"''}
        fi
      done
    '';

    # Each switch kicks off package work in the background: sync.el installs
    # whatever :ensure blocks lack, compiles elpa/ and refreshes quickstart,
    # followed by the macOS warmer. Never two at once; while sync.pid is alive
    # init.el leaves :ensure alone.
    home.activation.emacsCampPackageSync = lib.hm.dag.entryAfter [ "emacsCampNativeCompile" ] ''
      d="''${XDG_CACHE_HOME:-$HOME/.cache}/emacs-camp"
      if ! kill -0 "$(cat "$d/sync.pid" 2>/dev/null)" 2>/dev/null; then
        run mkdir -p "$d"
        run nohup sh -c 'echo $$ >"$0/sync.pid"; { "$1" --batch -l "$2" && if [ -n "$3" ]; then t=$(date +%s); "$3" "$4" && echo "emacs-camp sync: warmed $4 $(( $(date +%s) - t ))s"; fi; } >"$0/sync.log" 2>&1; rm -f "$0/sync.pid"' \
          "$d" ${emacs}/bin/emacs ${./sync.el} \
          "${lib.optionalString isDarwin elnWarm}" "$HOME/.config/emacs/eln-cache" \
          >/dev/null 2>&1 </dev/null &
      fi
    '';

    # ~/.emacs and ~/.emacs.d take priority over ~/.config/emacs, so rename
    # them once; they are never removed.
    # Every time one shows up (a tool may recreate ~/.emacs.d), not only the
    # first: an earlier backup is kept as *.before-emacs-camp.~N~ (GNU mv
    # --backup=numbered), and a symlink is moved as a link, its target untouched.
    home.activation.emacsCampLegacy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for p in "$HOME/.emacs" "$HOME/.emacs.d"; do
        if [ -e "$p" ] || [ -L "$p" ]; then
          run ${pkgs.coreutils}/bin/mv -vT --backup=numbered "$p" "$p.before-emacs-camp"
        fi
      done
    '';
  };
}
