{
  description = "emacs-camp: an Emacs runtime on top of nix-basecamp (use-package, deferred loading, deploy-time compile)";

  inputs.basecamp.url = "github:ajchemist/nix-basecamp";

  outputs = { self, basecamp, ... }: {
    homeModules.default = ./module.nix;
    homeModules.emacs-camp = ./module.nix;

    # A home on each platform with basecamp's Emacs and this module; building
    # it byte-compiles lisp/ against that Emacs (warnings are errors).
    checks = {
      x86_64-linux.home = (basecamp.lib.mkHome {
        user = "fixture"; emacs = "nox"; modules = [ self.homeModules.default ];
      }).activationPackage;
      aarch64-darwin.home = (basecamp.lib.mkDarwin {
        user = "fixture"; emacs = "gui";
        modules = [{ home-manager.sharedModules = [ self.homeModules.default ]; }];
      }).config.home-manager.users.fixture.home.activationPackage;
    };
  };
}
