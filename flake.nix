{
  description = "emacs-camp: an Emacs runtime on top of nix-basecamp (use-package, deferred loading, deploy-time compile)";

  inputs.basecamp.url = "github:ajchemist/nix-basecamp";
  # CI only: the agents and ACP adapters agent-shell drives in the agents job.
  # The module does not depend on it.
  inputs.agent-camp = {
    url = "github:ajchemist/agent-camp";
    inputs.basecamp.follows = "basecamp";
  };

  outputs = { self, basecamp, ... }:
  let
    linuxHome = basecamp.lib.mkHome {
      user = "fixture"; emacs = "nox"; modules = [ self.homeModules.default { emacs-camp.korean.enable = true; emacs-camp.extras = [ "10-prog" ]; } ];
    };
    darwin = basecamp.lib.mkDarwin {
      user = "fixture"; emacs = "gui";
      modules = [{ home-manager.sharedModules = [ self.homeModules.default { emacs-camp.korean.enable = true; emacs-camp.extras = [ "10-prog" ]; } ]; }];
    };
    darwinHome = darwin.config.home-manager.users.fixture;
    # The image's home (Dockerfile): the module as deployed, lightened for a
    # sandbox. Emacs without native compilation (no gcc/libgccjit), no extras.
    sandbox = system: basecamp.lib.mkHome {
      user = "user"; inherit system; emacs = "nox";
      modules = [ self.homeModules.default ({ lib, pkgs, config, ... }: {
        basecamp.emacs.nativeComp = false;
        # Only what the demo runs: Emacs and a git without its perl/python
        # tools (basecamp's full git and jq, home-manager's CLI are dropped).
        home.packages = lib.mkForce [ config.basecamp.emacs.package pkgs.gitMinimal ];
        # Two locales instead of every glibc locale (~220 MB).
        i18n.glibcLocales = pkgs.glibcLocales.override {
          allLocales = false;
          locales = [ "en_US.UTF-8/UTF-8" "ko_KR.UTF-8/UTF-8" ];
        };
      }) ];
    };
  in {
    homeConfigurations = {
      sandbox-x86_64-linux = sandbox "x86_64-linux";
      sandbox-aarch64-linux = sandbox "aarch64-linux";
    };

    homeModules.default = ./module.nix;
    homeModules.emacs-camp = ./module.nix;

    # Per platform, a home using basecamp's Emacs plus this module; the build
    # byte-compiles lisp/ with that Emacs and fails on warnings.
    checks = {
      x86_64-linux.home = linuxHome.activationPackage;
      aarch64-darwin.home = darwinHome.home.activationPackage;
    };

    # basecamp's Emacs as those homes get it, for CI jobs that run Emacs
    # without deploying (one source of Emacs for every job).
    packages = {
      x86_64-linux.emacs = linuxHome.config.basecamp.emacs.package;
      aarch64-darwin.emacs = darwinHome.basecamp.emacs.package;
    };
  };
}
