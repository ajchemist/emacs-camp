# emacs-camp

[![Try it on Killercoda](https://img.shields.io/badge/Try_it-Killercoda-1e90ff?logo=gnuemacs&logoColor=white)](https://killercoda.com/emacs-camp/scenario/emacs-camp)
[![CI](https://github.com/ajchemist/emacs-camp/actions/workflows/ci.yml/badge.svg)](https://github.com/ajchemist/emacs-camp/actions/workflows/ci.yml)
[![Demo image](https://github.com/ajchemist/emacs-camp/actions/workflows/demo-image.yml/badge.svg)](https://github.com/ajchemist/emacs-camp/actions/workflows/demo-image.yml)

English · [한국어](README.ko.md)

emacs-camp is an Emacs runtime with a small init and a full set of packages.
Each package is handled by `use-package`: it gets installed when absent, stays
unloaded until something actually calls it, and is configured at the moment it
loads. Emacs itself comes from
[nix-basecamp](https://github.com/ajchemist/nix-basecamp); this repository only
cares about what runs on top of it.

**Try it in a browser:** [Killercoda playground](https://killercoda.com/emacs-camp/scenario/emacs-camp)
opens a terminal with emacs-camp already installed (Emacs 31, terminal build);
type `emacs`. It needs a free Killercoda account, and a session lasts an hour.
The image is `ghcr.io/ajchemist/emacs-camp-demo` (`demo/Dockerfile`, rebuilt
weekly), so `docker run --rm -it ghcr.io/ajchemist/emacs-camp-demo` works
locally too.

```
nix-basecamp   Emacs binary, GUI/nox, Emacs.app, store .eln warm-up
emacs-camp     lisp/ runtime + a Home Manager module that deploys it
your flake     your own files through emacs-camp.userFiles
```

## The runtime (`lisp/`, no Nix needed)

- **early-init.el**: drops the tool bar and scroll bar (on macOS the system
  menu bar stays), skips the startup screen, turns GC off for init and sets
  100MB afterwards, enables `package-quickstart`.
- **init.el**: package.el with MELPA (priority melpa > melpa-stable > nongnu >
  gnu, native-compiled when installed), `use-package-always-ensure t` and
  `use-package-always-defer t`, the catppuccin latte theme, Cmd as Meta and
  Option as Super on macOS, exec-path-from-shell (only for an Emacs.app not
  launched from a terminal), completion (vertico, orderless, marginalia,
  consult, embark + embark-consult; corfu + cape inside buffers), git (magit +
  forge, diff-hl in each file buffer), agent-shell, and finally `custom.el`,
  `user/*.el`, `local.el`.

You can skip Nix entirely and copy `lisp/*.el` into `~/.config/emacs/`. In that
case packages get installed on the first launch rather than at deploy time.

### Packages

The package list is simply the set of `use-package` blocks.

| Keyword | Meaning |
|---|---|
| `:ensure` (default on) | install if missing; does not load. It only takes effect when the file is loaded from source; byte-compilation makes use-package drop it, so under the module the deploy-time sync (which loads the sources) does the installing |
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
```

The module depends on nothing from basecamp beyond its contract
(`basecamp.emacs.package`, `.warmProgram`). Every switch does the following:

| Step | Where | On failure |
|---|---|---|
| byte-compile `lisp/` and `userFiles` | store build (warnings are errors) | switch stops before activating |
| link `.el` + `.elc` into `~/.config/emacs/` | Home Manager | n/a |
| native-compile those files (+ warm, macOS) | host, `emacsCampNativeCompile` | warning; Emacs JITs instead |
| install missing packages, compile `elpa/`, refresh quickstart, warm `.eln` (macOS) | host, background; first switch waits (`emacsCampPackageSync`) | log in `~/.cache/emacs-camp/sync.log` |

The store can't provide `.eln` files, because each file's name is derived from
the path Emacs reads the source from, and that path is `~/.config/emacs/...`.
A switch returns without waiting for the package sync, except the first one
(no `elpa/` yet), which waits so Emacs starts complete. If you start Emacs in
the meantime it skips `:ensure` while `~/.cache/emacs-camp/sync.pid` points at
a live process, so installs never run in two processes at once. Native
compilation at switch time also has `:ensure` turned off, as in the store
byte-compile; otherwise packages would get installed halfway through the
compile, and the resulting `.eln` would load all of them at startup. The sync
native-compiles `elpa/` using all cores (by default Emacs uses half, which on
a 3-core machine is a single job), and logs the seconds spent in each phase
(`install`, `native-compile`, `warmed`). It then deletes the `eln-cache/`
subdirectories of other Emacs builds (one accumulates per build; only the
running build's is ever read, and a returning older build just re-JITs).
Since an existing `~/.emacs` or `~/.emacs.d` takes precedence over
`~/.config/emacs`, every switch that finds one renames it to
`*.before-emacs-camp`; an earlier backup becomes `*.before-emacs-camp.~N~`, and
a symlink is moved as a link with its target left alone.

### macOS only: `.eln` warm-up

The first time a process `dlopen`s a Mach-O file, macOS checks it. That takes
roughly 0.3-0.4 s per file, one file at a time, and the result is cached per
file afterwards. A native-compiled Lisp file (`.eln`) is a Mach-O dylib, so
without a warm-up every feature would hang once on its first use on macOS.
nix-basecamp absorbs that cost for Emacs's ~3000 built-in `.eln`; emacs-camp
absorbs it for the ones it builds:

- `.eln` for the init and user files, as soon as the switch compiles them;
- package `.eln`, when the background sync finishes, plus from Emacs itself at
  startup and after every async compile batch (`ecamp-eln-warm`).

Linux and Windows don't do this check, so they get no warming and no
`eln-warm` link. GitHub's macOS runners skip the check too (the "macOS .eln
vetting cost" CI step measures 0.000 s for both opens), whereas a regular
Apple Silicon Mac spends about 0.4 s on the first open of a new `.eln`.

### What lands where

This is the host after a switch (macOS; on Linux there is no `eln-warm` link
and no `Applications/`):

```
~/.config/emacs/                     user-emacs-directory (a real directory)
├── early-init.el  -> /nix/store/…-emacs-camp-config/early-init.el
├── early-init.elc -> /nix/store/…-emacs-camp-config/early-init.elc
├── init.el        -> /nix/store/…-emacs-camp-config/init.el
├── init.elc       -> /nix/store/…-emacs-camp-config/init.elc
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
| `early-init.el(c)`, `init.el(c)`, `user/*.el(c)`, `eln-warm` (macOS) | module (store links) |
| `eln-cache/` | module for the files above, package.el for packages; the sync prunes other builds' subdirectories |
| `elpa/`, `package-quickstart.el` | package.el |
| `custom.el` | Custom |
| `local.el` | you, per host; loaded last |

To profile, run `EMACS_USE_PACKAGE_STATS=1 emacs -q -l ~/.config/emacs/init.el`
and then `M-x use-package-report`. The setting gets baked in when init.el is
compiled, which is why the source has to be loaded.

The use-package policy (`always-ensure`, `always-defer`) is wrapped in
`eval-and-compile`. use-package expands its forms at compile time, so with a
bare `setq` the `.elc` would be expanded with the defaults and would load all
packages at startup.

## Checks

For each platform, `nix flake check` builds a home from basecamp's Emacs plus
this module, and that build byte-compiles `lisp/` with that Emacs.

CI (`.github/workflows/ci.yml`) has a lint job, a module-free runtime job
(`lisp/` copied in) on ubuntu, macOS and Windows, and a real deploy on ubuntu
and macOS. Every job uses basecamp's Emacs (this flake's
`packages.<system>.emacs`); Windows, where Nix does not run, installs GNU's
build of the same version, which lint reads from the flake. It runs only when
code changes (`lisp/`, `ci/`, `sync.el`, `module.nix`, the flake, the
workflow), plus the weekly schedule. `ci/smoke.el` boots the config the same
way Emacs does and verifies that:

- init stays light: it finishes within `ECAMP_INIT_BUDGET` seconds (1.5 by
  default; the measurement is written to the job summary), and magit, forge,
  transient, consult, embark, diff-hl, vc, org and agent-shell are all still
  unloaded after startup. Neither is the completion UI (vertico, savehist,
  marginalia, orderless, corfu, cape): `ecamp-completion-ui` turns it on
  from `pre-command-hook` at the first command, then removes itself;
- packages load when first used: `C-x g` brings in magit (and forge after
  it), `M-s l` brings in consult, `C-.` brings in embark (with
  embark-consult), and opening a file inside a git repository enables
  diff-hl, corfu and the cape capfs.
- every `use-package` package loads after init without error, each timed in
  its own fresh Emacs so nothing loaded earlier makes it look cheap. Taking
  longer than `ECAMP_LOAD_BUDGET` seconds (2.0 by default) adds a warning
  annotation rather than failing, since shared runners are noisy. The job summary gets a
  table per job: init time, features and GCs at startup, then each package
  with when it loads, its first-load time and how many features it pulls in.

The runtime job caches `elpa/` keyed on OS, package list and ISO week. The
weekly scheduled run starts from an empty cache so MELPA drift is still
caught. On Windows runners, the `gpg` found on PATH is the MSYS build shipped
with Git for Windows, and it reports `bad-signature` for every GNU/NonGNU ELPA
archive (`compat` lives there), so CI disables signature checking on that
platform. On a Windows desktop, install a native gpg (Gpg4win) instead.

The agents job deploys emacs-camp next to
[agent-camp](https://github.com/ajchemist/agent-camp) on ubuntu and macOS, with
claude, codex, pi and goose and their ACP adapters (`claude-agent-acp`,
`codex-acp`, `pi-acp`, `goose acp`). Then `ci/acp-handshake.el` has agent-shell
start each one with its own config and waits for the ACP initialize exchange.
No account is needed, because initialize comes before authentication. The
emacs-camp module does not depend on agent-camp; the flake input is only for
CI. To get the adapters on your own machine, import agent-camp's module
(answer yes to `<agent>-acp`), or install them however you like.
