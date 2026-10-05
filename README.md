# emacs-camp

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
  Option = Super, then `custom.el`, `user/*.el`, `local.el`.

Without Nix, copying `lisp/*.el` into `~/.config/emacs/` works; packages then
install on the first start instead of at deploy.

### Packages

The `use-package` blocks are the package list.

| Keyword | Meaning |
|---|---|
| `:ensure` (default on) | install if missing; does not load |
| none / `:hook` `:bind` `:mode` `:commands` | load on first use (default deferred) |
| `:demand t` | load at startup; use only for what the first frame needs |
| `:init` | runs at startup; keep it to `setq` and key bindings |
| `:config` | runs when the package loads (`with-eval-after-load`) |

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
| native-compile those files | host, `emacsCampNativeCompile` | warning; Emacs JITs instead |
| install missing packages, compile `elpa/`, refresh quickstart, warm `.eln` | host, background (`emacsCampPackageSync`) | log in `~/.cache/emacs-camp/sync.log` |

`.eln` files cannot come from the store: their name is keyed by the path
Emacs loads the source from, which is `~/.config/emacs/...`. The switch does
not wait for the package sync; an Emacs started meanwhile skips `:ensure`
(`~/.cache/emacs-camp/sync.pid` is alive), so two processes never install at
once. A pre-existing `~/.emacs` or `~/.emacs.d` would shadow
`~/.config/emacs` and is moved to `*.before-emacs-camp` once.

### What lands where

| Path in `~/.config/emacs/` | Owner |
|---|---|
| `early-init.el(c)`, `init.el(c)`, `user/*.el(c)`, `eln-warm` (macOS) | module (store links) |
| `eln-cache/` | module for the files above, package.el for packages |
| `elpa/`, `package-quickstart.el` | package.el |
| `custom.el` | Custom |
| `local.el` | you, per host; loaded last |

Profiling: `EMACS_USE_PACKAGE_STATS=1 emacs`, then `M-x use-package-report`.

## Checks

`nix flake check` builds a home per platform with basecamp's Emacs and this
module, which byte-compiles `lisp/` against it.
