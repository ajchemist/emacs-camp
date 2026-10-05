# emacs-camp

English · [한국어](README.ko.md)

An Emacs runtime that keeps init light without giving up on packages:
`use-package` installs what is missing, loads nothing until it is used, and
configures each package when it loads. Built on
[nix-basecamp](https://github.com/ajchemist/nix-basecamp), which installs
Emacs itself; emacs-camp is only about what runs inside it.

```
nix-basecamp   Emacs binary, GUI/nox, Emacs.app, store .eln warm-up
emacs-camp     lisp/ runtime + a Home Manager module that deploys it
your flake     your own files through emacs-camp.userFiles
```

## The runtime (`lisp/`, no Nix needed)

- **early-init.el**: no tool bar or scroll bar (macOS keeps its system menu
  bar), no startup screen, GC off during init and 100MB after,
  `package-quickstart`.
- **init.el**: package.el + MELPA (melpa > melpa-stable > nongnu > gnu,
  native-compiled at install), `use-package-always-ensure t` +
  `use-package-always-defer t`, catppuccin latte, macOS Cmd = Meta and
  Option = Super, exec-path-from-shell (Emacs.app started outside a
  terminal only), agent-shell, then `custom.el`, `user/*.el`, `local.el`.

Without Nix, copying `lisp/*.el` into `~/.config/emacs/` works; packages then
install on the first start instead of at deploy.

### Packages

The `use-package` blocks are the package list.

| Keyword | Meaning |
|---|---|
| `:ensure` (default on) | install if missing; does not load. Runs only when the file is loaded as source: byte-compiled, use-package drops it, so with the module installing is the deploy-time sync's job (it loads the sources) |
| none / `:hook` `:bind` `:mode` `:commands` | load on first use (default deferred) |
| `:demand t` | load at startup; use only for what the first frame needs |
| `:init` | runs at startup; keep it to `setq` and key bindings |
| `:config` | runs when the package loads (`with-eval-after-load`) |

A block whose `:config` calls a package function needs `:functions name`
(or `:commands`): the store build compiles init.el without the packages
installed and treats "not known to be defined" as an error.

Upgrading is `M-x package-upgrade-all`; removing a block leaves the package
installed (`M-x package-delete`).

## The Home Manager module

```nix
inputs.emacs-camp = {
  url = "github:ajchemist/emacs-camp";
  inputs.basecamp.follows = "basecamp";
};
# in a home built with basecamp.lib.mkDarwin / mkHome, basecamp.emacs.enable = true:
imports = [ emacs-camp.homeModules.default ];
emacs-camp.userFiles = [ ./emacs/fonts.el ];
```

It reads only basecamp's contract (`basecamp.emacs.package`,
`.warmProgram`) and on each switch:

| Step | Where | On failure |
|---|---|---|
| byte-compile `lisp/` and `userFiles` | store build (warnings are errors) | switch stops before activating |
| link `.el` + `.elc` into `~/.config/emacs/` | Home Manager | n/a |
| native-compile those files (+ warm, macOS) | host, `emacsCampNativeCompile` | warning; Emacs JITs instead |
| install missing packages, compile `elpa/`, refresh quickstart, warm `.eln` (macOS) | host, background (`emacsCampPackageSync`) | log in `~/.cache/emacs-camp/sync.log` |

`.eln` files cannot come from the store: their name is keyed by the path
Emacs loads the source from, which is `~/.config/emacs/...`. The switch does
not wait for the package sync; an Emacs started meanwhile skips `:ensure`
(`~/.cache/emacs-camp/sync.pid` is alive), so two processes never install at
once. A pre-existing `~/.emacs` or `~/.emacs.d` would shadow
`~/.config/emacs` and is moved to `*.before-emacs-camp` once.

### macOS only: `.eln` warm-up

macOS vets every Mach-O file the first time a process `dlopen`s it (about
0.3-0.4 s per file, serialised, then cached per file). Native-compiled Lisp
(`.eln`) files are Mach-O dylibs, so on macOS the first use of each feature
would stall once. nix-basecamp pays this for Emacs's ~3000 built-in `.eln`;
emacs-camp pays it for the ones it produces:

- the init and user files' `.eln`, right after they are compiled at switch;
- package `.eln`, at the end of the background sync, and from Emacs itself at
  startup and after each async compile batch (`ecamp-eln-warm`).

Linux and Windows have no such check: nothing is warmed there and no
`eln-warm` link is created. GitHub's macOS runners do not perform the check
either (CI's "macOS .eln vetting cost" step sees 0.000 s on both opens); on an
ordinary Apple Silicon Mac the first open of a fresh `.eln` costs ~0.4 s.

### What lands where

After a switch the host looks like this (macOS; Linux has no `eln-warm`
link and no `Applications/`):

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
├── package-quickstart.el(c)               all package autoloads in one file
├── custom.el                              Custom's writes
└── local.el                               yours, optional, loaded last

~/.cache/emacs-camp/
├── sync.log                         last package sync ("done", "warmed")
└── sync.pid                         only while a sync runs

~/.emacs.before-emacs-camp, ~/.emacs.d.before-emacs-camp   moved aside once, if they existed

/nix/store/…-emacs-31.1/             the Emacs (nix-basecamp), built-in .eln included
```

| Path in `~/.config/emacs/` | Owner |
|---|---|
| `early-init.el(c)`, `init.el(c)`, `user/*.el(c)`, `eln-warm` (macOS) | module (store links) |
| `eln-cache/` | module for the files above, package.el for packages |
| `elpa/`, `package-quickstart.el` | package.el |
| `custom.el` | Custom |
| `local.el` | you, per host; loaded last |

Profiling: `EMACS_USE_PACKAGE_STATS=1 emacs -q -l ~/.config/emacs/init.el`, then
`M-x use-package-report` (the setting is fixed when init.el is compiled, so it
needs the source loaded).

The use-package policy (`always-ensure`, `always-defer`) sits in
`eval-and-compile`: use-package expands at compile time, so a plain `setq`
would leave the `.elc` expanded with the defaults and loading every package at
startup.

## Checks

`nix flake check` builds a home per platform with basecamp's Emacs and this
module, which byte-compiles `lisp/` against it.
