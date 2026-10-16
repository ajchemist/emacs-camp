{
  description = "emacs-camp: Emacs builds, installation and runtime configuration";

  # nix-basecamp is the system baseline: nixpkgs (which fixes the Emacs source
  # and recipe) and the mkHome/mkDarwin builders the fixtures, CI and sandbox
  # use. It has no Emacs of its own; the modules here do not depend on it.
  inputs.basecamp.url = "github:ajchemist/nix-basecamp";
  # CI only: the agents and ACP adapters agent-shell drives in the agents job.
  # The modules do not depend on it.
  inputs.agent-camp = {
    url = "github:ajchemist/agent-camp";
    inputs.basecamp.follows = "basecamp";
  };

  outputs = { self, basecamp, ... }:
    let
      nixpkgs = basecamp.inputs.nixpkgs;
      lib = nixpkgs.lib;
      build = import ./lib/emacs.nix { inherit lib; };
      systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
      # Fixtures turn every extra on: only default-on extras compile, so this
      # is what keeps all of them compiling in CI.
      allExtras = map (lib.removeSuffix ".el")
        (builtins.filter (lib.hasSuffix ".el") (builtins.attrNames (builtins.readDir ./extras)));
      # basecamp's builders with emacs-camp on: the install where it happens
      # (nix-darwin on macOS, Home Manager on Linux) and the runtime in the home.
      home = args: basecamp.lib.mkHome (args // {
        modules = [ self.homeModules.default { emacs-camp.enable = lib.mkDefault true; } ] ++ args.modules or [ ];
      });
      darwin = args: basecamp.lib.mkDarwin (args // {
        modules = [ self.darwinModules.default {
          emacs-camp.enable = lib.mkDefault true;
          home-manager.sharedModules = [ self.homeModules.default ];
        } ] ++ args.modules or [ ];
      });
      withAllExtras = { emacs-camp.extras = allExtras; };
      # The image's home (Dockerfile): the module as deployed, lightened for a
      # sandbox. Emacs without native compilation (no gcc/libgccjit), no extras.
      sandbox = system: home {
        user = "user"; inherit system;
        modules = [ ({ lib, pkgs, config, ... }: {
          emacs-camp = { gui = false; nativeComp = false; };
          # Only what the demo runs: Emacs and a git without its perl/python
          # tools (basecamp's full git and jq, home-manager's CLI are dropped).
          # The image starts from scratch, so the shell and its tools come from here.
          home.packages = lib.mkForce (with pkgs; [
            config.emacs-camp.package gitMinimal bashInteractive coreutils less cacert
            config.i18n.glibcLocales # home-path/lib/locale: LOCALE_ARCHIVE in the Dockerfile
          ]);
          # No systemd in a container; a bare name keeps systemd (~120 MB) out of the closure.
          systemd.user.systemctlPath = "systemctl";
          # Two locales instead of every glibc locale (~220 MB).
          i18n.glibcLocales = pkgs.glibcLocales.override {
            allLocales = false;
            locales = [ "en_US.UTF-8/UTF-8" "ko_KR.UTF-8/UTF-8" ];
          };
        }) ];
      };
    in {
      # The Emacs for code evaluated outside a module (a downstream plan, the
      # Dockerfile's cached layer). Same values as the modules' read-only options.
      lib = {
        emacsMajor = build.major;
        emacsPackage = { system, gui ? false, nativeComp ? true, patches ? [ ] }:
          build.package { pkgs = nixpkgs.legacyPackages.${system}; inherit gui nativeComp patches; };
        emacsWarm = { system }: build.warm nixpkgs.legacyPackages.${system};
      };

      homeModules = {
        default = ./module.nix;
        emacs-camp = ./module.nix;
        emacs = ./install.nix;
      };
      darwinModules = { default = ./darwin; emacs = ./darwin; };

      darwinConfigurations.fixture = darwin {
        user = "fixture";
        modules = [ { home-manager.sharedModules = [ withAllExtras ]; } ];
      };
      homeConfigurations = {
        fixture = home { user = "fixture"; modules = [ withAllExtras ]; };
        sandbox-x86_64-linux = sandbox "x86_64-linux";
        sandbox-aarch64-linux = sandbox "aarch64-linux";
      };

      # The Emacs builds, for CI jobs that run Emacs without deploying (one
      # source of Emacs for every job) and for `nix build`.
      packages = lib.genAttrs systems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = self.packages.${system}.emacs;
          emacs = build.package { inherit pkgs; gui = pkgs.stdenv.hostPlatform.isDarwin; };
          emacs-gui = build.package { inherit pkgs; gui = true; };
          emacs-nox = build.package { inherit pkgs; };
          emacs-gui-no-native = build.package { inherit pkgs; gui = true; nativeComp = false; };
          emacs-nox-no-native = build.package { inherit pkgs; nativeComp = false; };
          eln-warm = build.warm pkgs;
        });

      # Per platform: a home with every extra, whose build byte-compiles lisp/
      # with the installed Emacs and fails on warnings; the install options;
      # the app takeover and warmer scripts.
      checks = lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          cfg = if pkgs.stdenv.hostPlatform.isDarwin
            then (darwin { user = "fixture"; inherit system;
                           modules = [ { home-manager.sharedModules = [ withAllExtras ]; } ]; }).config.home-manager.users.fixture
            else (home { user = "fixture"; inherit system; modules = [ withAllExtras ]; }).config;
        in {
          home = cfg.home.activationPackage;
          installation = import ./ci/installation.nix { inherit home darwin lib pkgs system; };
          helpers = pkgs.runCommand "emacs-helper-tests" {
            nativeBuildInputs = [ pkgs.python3 pkgs.bash pkgs.coreutils ];
            ECAMP_WARM = "${build.warm pkgs}/bin/eln-warm-store";
          } ''
            cp -r ${./ci} ci
            cp -r ${./lib} lib
            python3 ci/test-emacs.py
            touch $out
          '';
        });
    };
}
