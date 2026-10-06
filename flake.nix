{
  description = "emacs-camp: an Emacs runtime on top of nix-basecamp (use-package, deferred loading, deploy-time compile)";

  inputs.basecamp.url = "github:ajchemist/nix-basecamp";

  outputs = { self, basecamp, ... }:
  let
    linuxHome = basecamp.lib.mkHome {
      user = "fixture"; emacs = "nox"; modules = [ self.homeModules.default ];
    };
    darwin = basecamp.lib.mkDarwin {
      user = "fixture"; emacs = "gui";
      modules = [{ home-manager.sharedModules = [ self.homeModules.default ]; }];
    };
    darwinHome = darwin.config.home-manager.users.fixture;
  in {
    homeModules.default = ./module.nix;
    homeModules.emacs-camp = ./module.nix;

    # A home on each platform with basecamp's Emacs and this module; building
    # it byte-compiles lisp/ against that Emacs (warnings are errors).
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
