# emacs-camp

[![CI](https://github.com/ajchemist/emacs-camp/actions/workflows/ci.yml/badge.svg)](https://github.com/ajchemist/emacs-camp/actions/workflows/ci.yml)
[![Image](https://github.com/ajchemist/emacs-camp/actions/workflows/image.yml/badge.svg)](https://github.com/ajchemist/emacs-camp/actions/workflows/image.yml)

English · [한국어](README.ko.md)

emacs-camp is an Emacs runtime with a small init and a full set of packages.
`use-package` handles each package. It installs the package when it is
missing, leaves it unloaded until something calls it, and configures it when
it loads. Emacs itself comes from
[nix-basecamp](https://github.com/ajchemist/nix-basecamp), and this repository
covers only what runs on top of it.

## Playgrounds

Try it in a browser, no install. Each one runs on the visitor's own account
and its free quota; this repository only provides the buttons and their
definitions.

| | Opens | Needs |
|---|---|---|
| [![Killercoda](https://img.shields.io/badge/Try_it-Killercoda-1e90ff?logo=gnuemacs&logoColor=white)](https://killercoda.com/emacs-camp/scenario/emacs-camp) | a terminal; type `emacs` | free Killercoda login (1-hour sessions) |
| [![Codespaces](https://img.shields.io/badge/Open_in-Codespaces-24292f?logo=github&logoColor=white)](https://codespaces.new/ajchemist/emacs-camp?quickstart=1) | VS Code in the browser; its terminal is Emacs (bash from the `+` menu) | GitHub account (free Codespaces hours) |
| [![iximiuz Labs](https://img.shields.io/badge/Start_on-iximiuz_Labs-6c47ff?logo=docker&logoColor=white)](https://labs.iximiuz.com/playgrounds/emacs-camp-7b268ff0) | a Docker VM; its terminal is Emacs, `C-x C-c` leaves a shell, `emacs-camp` starts it again | free iximiuz login (daily playground time) |
| `docker run -it --rm ghcr.io/ajchemist/emacs-camp` | Emacs, locally or anywhere with Docker | Docker |

Play with Docker would have been another, but it shut down on 2026-03-01.

Where each one is defined:

- Killercoda: the scenario lives on the `killercoda` branch, which holds
  nothing else, and Killercoda syncs that branch. Main can't be the source:
  its `.claude/skills` symlink points at the uncommitted `.agents/skills`,
  and that dangling link stalls Killercoda's sync.
- Codespaces: `.devcontainer/devcontainer.json`, on the `:debian` image
  (`scratch` has no shell for a dev container).
- iximiuz Labs: `playgrounds/iximiuz/manifest.yaml`. After editing it, run
  `labctl playground update emacs-camp-7b268ff0 -f playgrounds/iximiuz/manifest.yaml`.
- All of them run the image from [Demo image](#demo-image).

```
nix-basecamp   Emacs binary, GUI/nox, Emacs.app, store .eln warm-up
emacs-camp     lisp/ runtime + a Home Manager module that deploys it
your flake     your own files through emacs-camp.userFiles
```

## The runtime (`lisp/`, no Nix needed)

- **early-init.el** drops the tool bar and scroll bar (on macOS the system
  menu bar stays), skips the startup screen, turns GC off for init and sets
  100MB afterwards, and enables `package-quickstart`.
- **init.el** sets up package.el with MELPA (priority melpa > melpa-stable >
  nongnu > gnu, native-compiled when installed), `use-package-always-ensure t`
  and `use-package-always-defer t`. It then configures:
  - the catppuccin latte theme;
  - Cmd as Meta and Option as Super on macOS, and exec-path-from-shell for an
    Emacs.app that was not launched from a terminal;
  - completion with vertico, savehist, orderless, marginalia, consult, embark
    and embark-consult, plus corfu and cape inside buffers;
  - dirvish, which replaces dired the first time dired loads;
  - paredit in Lisp buffers, eros for inline elisp eval results;
  - git with magit, forge, and diff-hl in each file buffer;
  - agent-shell.

  Finally it loads `custom.el`, the extras named in `ecamp-extras`,
  `user/*.el` and `local.el`, in that order.

You can skip Nix and copy `lisp/*.el` into `~/.config/emacs/`. Packages then
install on the first launch instead of at deploy time. To compile the files
you put in `user/` yourself, run `bin/emacs-camp-compile-user`. It byte- and
native-compiles them in place and skips the symlinks that the module manages.

### Packages

The package list is the set of `use-package` blocks.

| Keyword | Meaning |
|---|---|
| `:ensure` (default on) | Installs the package if it is missing, without loading it. It works only when Emacs loads the file from source, because use-package drops it during byte-compilation. Under the module, the package sync loads the sources and does the installing. |
| none / `:hook` `:bind` `:mode` `:commands` | load on first use (deferred by default) |
| `:demand t` | load at startup; reserve it for what the first frame needs |
| `:init` | runs at startup; limit it to `setq` and key bindings |
| `:config` | runs when the package loads (`with-eval-after-load`) |

If a block's `:config` calls a function from its package, add `:functions
name` (or `:commands`). The store build compiles init.el with no packages
present, and it treats "not known to be defined" as an error.

To upgrade, run `M-x package-upgrade-all`. Deleting a block does not uninstall
its package; use `M-x package-delete` for that.

## The Home Manager module

```nix
inputs.emacs-camp = {
  url = "github:ajchemist/emacs-camp";
  inputs.basecamp.follows = "basecamp";
};
# in a home built with basecamp.lib.mkDarwin / mkHome, basecamp.emacs.enable = true:
imports = [ emacs-camp.homeModules.default ];
emacs-camp.userFiles = [ ./emacs/fonts.el ];
emacs-camp.korean.enable = true;  # hangul input on C-\, UTF-8 over EUC-KR, hangul/hanja keys
emacs-camp.extras = [ "10-prog" ];  # rainbow parens, eval flash, auto-closed brackets, off-screen paren context
```

Every `extras/*.el` is deployed to `~/.config/emacs/extras/`, but none loads
unless named in `ecamp-extras`. `emacs-camp.extras` and options like `korean.enable` only set its
default (written to `extras-default.el`). Turn extras on or off later with
`M-x customize-variable RET ecamp-extras`, which saves to `custom.el`.
Only default-on extras are byte- and native-compiled at deploy; the others
ship as `.el` and are native-compiled on first load once turned on.
An extra may bring its own packages with `use-package`; only enabled extras
install them (docs/adr/0002-extras-opt-in-cost.md).

The module depends on nothing from basecamp beyond its contract
(`basecamp.emacs.package`, `.warmProgram`). Every switch does the following:

| Step | Where | On failure |
|---|---|---|
| byte-compile `lisp/` and `userFiles` | store build (warnings are errors) | switch stops before activating |
| link `.el` + `.elc` into `~/.config/emacs/` | Home Manager | n/a |
| native-compile those files (+ warm, macOS) | host, `emacsCampNativeCompile` | warning; Emacs JITs instead |
| install missing packages, compile `elpa/`, refresh quickstart, warm `.eln` (macOS) | host, background; first switch waits (`emacsCampPackageSync`) | log in `~/.cache/emacs-camp/sync.log` |

The store can't provide `.eln` files. Each file's name comes from the path
Emacs reads the source from, and that path is `~/.config/emacs/...`.

A switch returns without waiting for the package sync. The exception is the
first switch, when `elpa/` does not exist yet. It waits, so the first Emacs
start has every package.

If you start Emacs while a package sync runs, Emacs skips `:ensure` as long as
`~/.cache/emacs-camp/sync.pid` points at a live process. Only one process
installs packages at a time.

Native compilation at switch time turns `:ensure` off, as the store
byte-compile does (both load `compile.el` first). Without that, packages would
install halfway through the compile, and the resulting `.eln` would load all
of them at startup.

The package sync native-compiles `elpa/` on all cores. Emacs uses half by
default, which is a single job on a 3-core machine. The sync logs the seconds
spent in each phase (`install`, `native-compile`, `warmed`). It then deletes
the `eln-cache/` subdirectories of other Emacs builds. Each build adds one, and
Emacs reads only the running build's. If an older build comes back, it
re-JITs.

An existing `~/.emacs` or `~/.emacs.d` takes precedence over `~/.config/emacs`.
Every switch that finds one renames it to `*.before-emacs-camp`. An earlier
backup becomes `*.before-emacs-camp.~N~`, and the switch moves a symlink as a
link and leaves its target alone.

### `.eln` warm-up on macOS

The first time a process `dlopen`s a Mach-O file, macOS checks it. That takes
0.3 to 0.4 s per file, one file at a time, and macOS caches the result per
file. A native-compiled Lisp file (`.eln`) is a Mach-O dylib, so without a
warm-up every feature would hang once on its first use on macOS. nix-basecamp
runs that check ahead of time for Emacs's ~3000 built-in `.eln`, and
emacs-camp does it for the ones it builds:

- `.eln` for the init and user files, as soon as the switch compiles them;
- package `.eln`, when the package sync finishes, plus from Emacs itself at
  startup and after every async compile batch (`ecamp-eln-warm`).

Linux and Windows don't do this check, so they get no warming and no
`eln-warm` link. GitHub's macOS runners skip the check too (the "macOS .eln
vetting cost" CI step measures 0.000 s for both opens). A regular Apple
Silicon Mac spends about 0.4 s on the first open of a new `.eln`.

### What lands where

This is the host after a switch (macOS; on Linux there is no `eln-warm` link
and no `Applications/`):

```
~/.config/emacs/                     user-emacs-directory (a real directory)
├── early-init.el  -> /nix/store/…-emacs-camp-config/early-init.el
├── early-init.elc -> /nix/store/…-emacs-camp-config/early-init.elc
├── init.el        -> /nix/store/…-emacs-camp-config/init.el
├── init.elc       -> /nix/store/…-emacs-camp-config/init.elc
├── extras-default.el(c) -> /nix/store/…   default of ecamp-extras
├── extras/
│   └── 00-korean.el(c) -> /nix/store/…    every extra, loaded only if chosen
├── user/
│   ├── fonts.el   -> /nix/store/…   one pair per emacs-camp.userFiles entry
│   └── fonts.elc  -> /nix/store/…
├── eln-warm       -> /nix/store/…-eln-warm/bin/eln-warm   (macOS)
├── eln-cache/31.1-<hash>/
│   ├── init-<path>-<content>.eln          compiled at switch
│   └── agent-shell-<path>-<content>.eln   compiled by the package sync
├── elpa/
│   ├── agent-shell-<version>/ …           installed by the package sync
│   └── archives/                          MELPA/ELPA indexes
├── package-quickstart.el(c)               every package's autoloads, one file
├── custom.el                              written by Custom
└── local.el                               yours, optional, loaded last

~/.cache/emacs-camp/
├── sync.log                         latest package sync, seconds per phase
└── sync.pid                         present only during a sync

~/.emacs.before-emacs-camp(.~N~), ~/.emacs.d.before-emacs-camp(.~N~)   moved aside whenever they appear

/nix/store/…-emacs-31.1/             the Emacs (nix-basecamp), built-in .eln included
```

| Path in `~/.config/emacs/` | Owner |
|---|---|
| `early-init.el(c)`, `init.el(c)`, `extras-default.el(c)`, `extras/*.el(c)`, `user/*.el(c)`, `eln-warm` (macOS) | module (store links) |
| `eln-cache/` | module for the files above, package.el for packages; the package sync prunes other builds' subdirectories |
| `elpa/`, `package-quickstart.el` | package.el |
| `custom.el` | Custom |
| `local.el` | you, per host; loaded last |

To profile, run `EMACS_USE_PACKAGE_STATS=1 emacs -q -l ~/.config/emacs/init.el`
and then `M-x use-package-report`. The compiler fixes this setting when it
compiles init.el, so you have to load the source.

The use-package policy (`always-ensure`, `always-defer`) is wrapped in
`eval-and-compile`. use-package expands its forms at compile time. With a
bare `setq`, the compiler would expand the `.elc` with the defaults, and it
would load all packages at startup.

## Demo image

`Dockerfile` builds `ghcr.io/ajchemist/emacs-camp`:

- One deploy path: a Nix stage builds the flake's
  `homeConfigurations.sandbox-<arch>-linux` (basecamp's Emacs plus this module)
  and runs its Home Manager activation, so the links, `extras-default.el`,
  compile and package sync are the module's own. Only the home and its
  `/nix/store` closure ship, without Nix, as two tags: `:latest` on
  `scratch`, nothing else (about 170 MB compressed), and `:debian` on Debian
  slim, for apt and a `/bin/sh` (about 200 MB).
- The sandbox is lightened by options, not by a second recipe:
  `basecamp.emacs.nativeComp = false` drops gcc and libgccjit, a bare
  `systemctl` keeps systemd out, git is `gitMinimal`, and no extra is
  on (`M-x customize-variable RET ecamp-extras` turns one on).
- GitHub Actions (`.github/workflows/image.yml`) builds both tags from main for
  amd64 and arm64, each on a native runner, and joins them per tag.
  It runs on every push that touches `lisp/`, `extras/`, `sync.el`,
  `compile.el`, `module.nix`, `flake.*` or `Dockerfile`, and nightly at 18:00 UTC to pick up MELPA
  updates. A newer build cancels a running one.

## Checks

For each platform, `nix flake check` builds a home from basecamp's Emacs plus
this module, and that build byte-compiles `lisp/` with that Emacs.

CI (`.github/workflows/ci.yml`) has three kinds of jobs:

- a lint job;
- a module-free runtime job on ubuntu, macOS and Windows, which copies `lisp/`
  in;
- a real deploy on ubuntu and macOS.

Every job uses basecamp's Emacs (this flake's `packages.<system>.emacs`).
Windows, where Nix does not run, installs GNU's build of the same version, and
the lint job reads that version from the flake. CI runs only when code changes
(`lisp/`, `ci/`, `sync.el`, `module.nix`, the flake, the workflow), plus a
weekly schedule. `ci/smoke.el` boots the config the same way Emacs does and
verifies that:

- init stays light. It finishes within `ECAMP_INIT_BUDGET` seconds (1.5 by
  default; the job summary records the measurement), and magit, forge,
  transient, consult, embark, diff-hl, vc, org and agent-shell are all still
  unloaded after startup. So is the completion UI (vertico, savehist,
  marginalia, orderless, corfu, cape). `ecamp-completion-ui` turns it on from
  `pre-command-hook` at the first command, then removes itself.
- packages load when first used. `C-x g` loads magit (and forge after it),
  `M-s l` loads consult, `C-.` loads embark (with embark-consult), and opening
  a file inside a git repository enables diff-hl, corfu and the cape capfs.
- every `use-package` package loads after init without error. Each one is
  timed in its own fresh Emacs, so nothing loaded earlier lowers its measured
  time. Taking longer than `ECAMP_LOAD_BUDGET` seconds (2.0 by default) adds a
  warning annotation instead of failing, because shared runners are noisy. The
  job summary gets a table per job with init time, features and GCs at
  startup, then each package with when it loads, its first-load time and how
  many features it pulls in.

The runtime job caches `elpa/` keyed on OS, package list and ISO week. The
weekly scheduled run starts from an empty cache, so it still catches MELPA
drift.

On Windows runners, the `gpg` on PATH is the MSYS build that ships with Git
for Windows. It reports `bad-signature` for every GNU/NonGNU ELPA archive, and
`compat` comes from there, so CI disables signature checking on that platform.
On a Windows desktop, install a native gpg (Gpg4win) instead.

The agents job deploys emacs-camp next to
[agent-camp](https://github.com/ajchemist/agent-camp) on ubuntu and macOS, with
claude, codex, pi and goose and their ACP adapters (`claude-agent-acp`,
`codex-acp`, `pi-acp`, `goose acp`). Then `ci/acp-handshake.el` has agent-shell
start each one with its own config and waits for the ACP initialize exchange.
No account is needed, because initialize comes before authentication. The
emacs-camp module does not depend on agent-camp; the flake input is only for
CI. To get the adapters on your own machine, import agent-camp's module
(answer yes to `<agent>-acp`), or install them however you like.

## License

GPL-3.0-or-later, like Emacs and the packages it builds on. See `LICENSE`.
