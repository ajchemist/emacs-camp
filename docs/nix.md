# Build, install and configure Emacs

This flake builds and installs Emacs and deploys its runtime. The supported
Nix systems are `aarch64-darwin`, `x86_64-linux` and `aarch64-linux`. Windows
runs the Lisp runtime on a separately installed GNU Emacs; there is no Windows
Nix module.

## Build without installing

```sh
nix build github:ajchemist/emacs-camp#emacs
./result/bin/emacs --version
```

`packages.<system>.emacs` (also `default`) is the GUI build on macOS and nox
on Linux. The other outputs are `emacs-gui`, `emacs-nox`,
`emacs-gui-no-native`, `emacs-nox-no-native` and `eln-warm`. For code
evaluated outside a module, `lib.emacsPackage { system; gui ? false;
nativeComp ? true; patches ? []; }` is the same builder, `lib.emacsMajor` the
pinned major and `lib.emacsWarm { system; }` the warmer.

`lib/emacs.nix` selects the major (31). nixpkgs, which fixes the Emacs source
revision, recipe and upstream patches, comes from
[nix-basecamp](https://github.com/ajchemist/nix-basecamp). A downstream that
sets `inputs.basecamp.follows = "basecamp"` gets its own lock's nixpkgs.

## A downstream flake

basecamp's builders make the system or home; emacs-camp adds its modules.

```nix
{
  inputs = {
    basecamp.url = "github:ajchemist/nix-basecamp";
    emacs-camp = {
      url = "github:ajchemist/emacs-camp";
      inputs.basecamp.follows = "basecamp";
    };
  };
  outputs = { basecamp, emacs-camp, ... }: {
    # Linux: Home Manager installs Emacs and deploys the runtime.
    homeConfigurations.example = basecamp.lib.mkHome {
      user = "example";
      modules = [ emacs-camp.homeModules.default {
        emacs-camp = {
          enable = true;
          gui = false;
          extras = [ "00-korean" "10-prog" ];
          # userFiles = [ ./emacs/fonts.el ];
        };
      } ];
    };
    # macOS: nix-darwin installs Emacs; Home Manager deploys the runtime.
    darwinConfigurations.example = basecamp.lib.mkDarwin {
      user = "example";
      modules = [ emacs-camp.darwinModules.default {
        emacs-camp = { enable = true; gui = true; };
        home-manager.users.example.imports = [ emacs-camp.homeModules.default ];
      } ];
    };
  };
}
```

The modules also work in a Home Manager or nix-darwin configuration that does
not use basecamp. Imported directly, every module defaults to
`emacs-camp.enable = false`.

## Where each option is set

- **Home Manager only** (Linux, or macOS without nix-darwin): import
  `homeModules.default` and set `emacs-camp.enable = true`. It installs Emacs
  in the home profile and deploys the runtime. `homeModules.emacs` installs
  Emacs without the runtime.
- **nix-darwin**: add `darwinModules.default` to the system modules and set
  `enable`, `gui`, `nativeComp` and `patches` there. Add `homeModules.default`
  to the user's Home Manager imports (or `home-manager.sharedModules`); there
  the build options mirror the system's, read-only. The runtime options
  `extras` and `userFiles` stay in Home Manager.

nix-darwin installs the system package and copies Emacs.app into
`/Applications/Nix Apps`. A GUI setup uninstalls Homebrew's Emacs casks
(`emacs`, `emacs-app`, `emacs-mac`) and moves any other `Emacs.app` in
`/Applications` or `~/Applications` to `Emacs.app.before-emacs-camp`. It never
deletes one and never overwrites an earlier backup. `warmNativeLisp` warms the
built-in native Lisp in the background as the primary user, once per Emacs
store path. With Home Manager alone on macOS, Emacs goes into the home
profile and neither the takeover nor the built-in warm-up runs.

| Option | Default | Purpose |
|---|---|---|
| `enable` | `false` | Install Emacs and, with `homeModules.default`, deploy the runtime |
| `gui` | macOS `true`, Linux `false` | GUI build instead of `-nox` |
| `nativeComp` | `true` | `false` drops gcc and libgccjit (~430 MB) |
| `patches` | `[]` | Source patches applied before compilation ([rules](source-patches.md)) |
| `major`, `package`, `warmProgram` | read-only | The pinned major, the Emacs, the warmer |
| `extras` | `[]` | Default-on runtime extras |
| `userFiles` | `[]` | Your Lisp files, compiled and loaded in name order |
| `warmNativeLisp` | `true` | nix-darwin only: warm the built-in `.eln` |

The home module byte-compiles, native-compiles and syncs packages with
`package`, the same Emacs it installs; there is no separate compiler Emacs.
`warmProgram` provides `bin/eln-warm DIR...` and
`bin/eln-warm-store start|status EMACS`.

## Development

`path:.` includes untracked files:

```sh
nix flake check path:. --all-systems --no-build
nix build path:.#checks.aarch64-darwin.home path:.#checks.aarch64-darwin.installation path:.#checks.aarch64-darwin.helpers
nix build path:.#darwinConfigurations.fixture.system
# On a Linux builder:
nix build path:.#checks.x86_64-linux.home path:.#checks.x86_64-linux.helpers
```

To try an unpublished basecamp, add
`--override-input basecamp path:../nix-basecamp`.
