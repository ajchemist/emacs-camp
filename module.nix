# emacs-camp Home Manager module: deploys lisp/ on top of nix-basecamp's Emacs.
# Consumes basecamp's contract only (basecamp.emacs.package, .warmProgram);
# a downstream sets basecamp.emacs.enable/gui where the install happens.
{ lib, config, pkgs, ... }:

let
  cfg = config.emacs-camp;
  emacs = config.basecamp.emacs.package;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  elnWarm = "${config.basecamp.emacs.warmProgram}/bin/eln-warm";
  userNames = map baseNameOf cfg.userFiles;

  # Byte-compiled with the Emacs that will load it, so a broken init fails the
  # switch rather than the next start. use-package would run :ensure while
  # compiling; the sandbox has no network and installing is sync.el's job.
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

  # Every linked source: early-init, init, user/*.
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

    # Links only; ~/.config/emacs itself stays a real, writable directory.
    xdg.configFile = lib.listToAttrs (map (f: lib.nameValuePair "emacs/${f}" { source = "${compiled}/${f}"; })
      (lib.concatMap (n: [ "${n}.el" "${n}.elc" ]) linked))
      // lib.optionalAttrs isDarwin { "emacs/eln-warm".source = elnWarm; };

    # An .eln is keyed by the path Emacs loads the source from
    # (~/.config/emacs/...), never a store path, so it is made here, once per
    # content change, and vetted at once on macOS (init's load before any
    # startup hook could warm them).
    home.activation.emacsCampNativeCompile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      for f in ${lib.escapeShellArgs linked}; do
        src="$HOME/.config/emacs/$f.el"
        eln="$(${emacs}/bin/emacs --batch --eval "(when (native-comp-available-p) (princ (comp-el-to-eln-filename \"$src\")))" 2>/dev/null || true)"
        if [ -n "$eln" ] && [ ! -f "$eln" ]; then
          run ${emacs}/bin/emacs --batch -f batch-native-compile "$src" \
            || echo "emacs-camp: native-compile of $src failed; Emacs will JIT it instead" >&2
          ${lib.optionalString isDarwin ''[ -f "$eln" ] && run ${elnWarm} "$(dirname "$eln")"''}
        fi
      done
    '';

    # Packages, in the background on every switch: sync.el installs what the
    # :ensure blocks miss, compiles elpa/, refreshes quickstart; then the
    # macOS warmer. One at a time; init.el skips :ensure while sync.pid lives.
    home.activation.emacsCampPackageSync = lib.hm.dag.entryAfter [ "emacsCampNativeCompile" ] ''
      d="''${XDG_CACHE_HOME:-$HOME/.cache}/emacs-camp"
      if ! kill -0 "$(cat "$d/sync.pid" 2>/dev/null)" 2>/dev/null; then
        run mkdir -p "$d"
        run nohup sh -c 'echo $$ >"$0/sync.pid"; { "$1" --batch -l "$2" && ''${3:+"$3" "$4"}; } >"$0/sync.log" 2>&1; rm -f "$0/sync.pid"' \
          "$d" ${emacs}/bin/emacs ${./sync.el} \
          "${lib.optionalString isDarwin elnWarm}" "$HOME/.config/emacs/eln-cache" \
          >/dev/null 2>&1 </dev/null &
      fi
    '';

    # ~/.emacs and ~/.emacs.d win over ~/.config/emacs: moved aside once,
    # never deleted.
    home.activation.emacsCampLegacy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for p in "$HOME/.emacs" "$HOME/.emacs.d"; do
        if [ -e "$p" ] && [ ! -L "$p" ] && [ ! -e "$p.before-emacs-camp" ]; then
          run mv -v "$p" "$p.before-emacs-camp"
        fi
      done
    '';
  };
}
