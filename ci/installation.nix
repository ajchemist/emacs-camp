{ home, darwin, lib, pkgs, system }:
let
  build = import ../lib/emacs.nix { inherit lib; };
  homeWith = settings: (home {
    user = "fixture"; inherit system;
    modules = [ { emacs-camp = settings; } ];
  }).config;
  off = homeWith { enable = false; };
  gui = homeWith { gui = true; };
  nox = homeWith { gui = false; };
  lean = homeWith { gui = false; nativeComp = false; };
  patched = homeWith { patches = [ ./source-patch-fixture.patch ]; };
  isEmacs = p: (p.pname or "") == "emacs";
  darwinWith = settings: (darwin {
    user = "fixture"; inherit system;
    modules = [ { emacs-camp = settings; } ];
  }).config;
  installed = darwinWith { gui = true; };
  mirrored = installed.home-manager.users.fixture;
in
assert !off.emacs-camp.enable && !(lib.any isEmacs off.home.packages);
assert gui.emacs-camp.package == build.package { inherit pkgs; gui = true; };
assert nox.emacs-camp.package == build.package { inherit pkgs; };
assert lean.emacs-camp.package == build.package { inherit pkgs; nativeComp = false; };
assert lib.elem ./source-patch-fixture.patch patched.emacs-camp.package.patches;
assert lib.versions.major gui.emacs-camp.package.version == build.major;
assert lib.hasInfix (builtins.unsafeDiscardStringContext "${nox.emacs-camp.package}/bin/emacs") nox.home.activation.emacsCampNativeCompile.data;
assert !(pkgs.stdenv.hostPlatform.isDarwin) || (
  mirrored.emacs-camp.package == installed.emacs-camp.package
  && !(lib.any isEmacs mirrored.home.packages)
  && lib.any isEmacs installed.environment.systemPackages
  && lib.hasInfix "emacs-app-takeover" installed.system.activationScripts.postActivation.text
  && lib.hasInfix "eln-warm-store start" installed.system.activationScripts.postActivation.text
  && !(darwinWith { enable = false; }).home-manager.users.fixture.emacs-camp.enable
);
pkgs.runCommand "emacs-installation-checks" { } "touch $out"
