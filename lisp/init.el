;;; init.el --- emacs-camp  -*- lexical-binding: t -*-

;; Files load in this order: this one, custom.el, the chosen extras/*.el,
;; user/*.el, local.el.
;; ~/.config/emacs is an ordinary directory. Emacs or the user writes elpa/,
;; eln-cache/, custom.el and local.el into it; emacs-camp never does.

;;; Packages

;; Packages come from package.el and MELPA on purpose, not from Nix: the ones
;; worth tracking change every day, and Nix's MELPA snapshot lags by weeks.
(require 'package)
(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")
        ("melpa-stable" . "https://stable.melpa.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("gnu" . "https://elpa.gnu.org/packages/"))
      package-archive-priorities
      '(("melpa" . 4) ("melpa-stable" . 3) ("nongnu" . 2) ("gnu" . 1))
      ;; compile to native code when installing instead of on first load
      package-native-compile t)

;; The package list is the set of use-package blocks below. With :ensure
;; (enabled everywhere), reading a block installs its package if absent, but
;; nothing is loaded until a :hook/:bind/:mode/:commands trigger fires
;; (always-defer). Blocks needed at startup are marked `:demand t'.
;; :ensure only matters when this file is read as source, since use-package
;; strips it from the .elc. Under the Home Manager module, which links a
;; compiled init, sync.el installs packages in the background at deploy;
;; with a plain copy and no .elc, installs happen at startup. A source start
;; that overlaps a running sync skips :ensure, so elpa/ never has two writers.
;; eval-and-compile: the byte-compiler has to see these settings when it
;; expands the use-package forms, not just the .elc at run time. Otherwise the
;; .elc gets the default expansion and `require's all packages at startup.
(eval-and-compile
  (require 'use-package)
  (defun ecamp-sync-running-p ()
    "Non-nil while the deploy-time package sync is running."
    (let ((pid (ignore-errors
                 (with-temp-buffer
                   (insert-file-contents
                    (expand-file-name "emacs-camp/sync.pid"
                                      (or (getenv "XDG_CACHE_HOME") "~/.cache")))
                   (string-to-number (buffer-string))))))
      (and pid (> pid 0) (process-attributes pid) t)))
  (setq use-package-always-ensure (not (and (not noninteractive) (ecamp-sync-running-p)))
        use-package-always-defer t
        ;; Set EMACS_USE_PACKAGE_STATS=1 and run M-x use-package-report. Fixed at
        ;; compile time like everything here, so load init.el from source.
        use-package-compute-statistics (getenv "EMACS_USE_PACKAGE_STATS")))

;; macOS checks every .eln the first time it is dlopen'ed (~0.3s each, one
;; at a time). The Home Manager module links a warmer as ./eln-warm; it runs
;; over what package.el puts in eln-cache/, at startup and after each batch.
(defvar native-comp-eln-load-path)        ; only defined with native-comp
(defun ecamp-eln-warm ()
  (let ((warm (expand-file-name (locate-user-emacs-file "eln-warm"))))
    (when (file-executable-p warm)
      (start-process "eln-warm" nil warm
                     (expand-file-name (car native-comp-eln-load-path))))))
(when (eq system-type 'darwin)
  (add-hook 'emacs-startup-hook #'ecamp-eln-warm)
  (add-hook 'native-comp-async-all-done-hook #'ecamp-eln-warm))

;;; Custom saves to its own file, not init.el.

(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror 'nomessage)

;;; UI

(column-number-mode 1)
(when (fboundp 'fringe-mode)               ; missing on builds without a GUI
  (fringe-mode '(12 . 12)))
(setq visible-bell nil
      ring-bell-function (lambda ()
                           (invert-face 'mode-line)
                           (run-with-timer 0.125 nil #'invert-face 'mode-line)))

(use-package catppuccin-theme
  :demand t
  :custom (catppuccin-flavor 'latte)
  :config (load-theme 'catppuccin t))

;;; Environment

;; Launched from the Dock or Finder, Emacs.app inherits launchd's PATH rather
;; than the login shell's, so tools from bun, fnm, Homebrew and the like are
;; not found. In that case only (TERM unset, so no terminal) query the shell.
(use-package exec-path-from-shell
  :if (and (memq window-system '(mac ns)) (not (getenv "TERM")))
  :demand t
  :functions exec-path-from-shell-initialize
  :config (exec-path-from-shell-initialize))

;;; Completion

;; In the minibuffer, vertico lists what the built-in completing-read offers,
;; orderless lets space-separated terms match in any order, marginalia adds
;; annotations, consult supplies search and jump commands, and embark runs
;; actions on the current candidate. Inside buffers, corfu shows a popup for
;; completion-at-point and cape contributes extra capfs.

(use-package vertico
  :functions vertico-mode)

(use-package savehist                   ; history that vertico sorts by
  :ensure nil)

;; Nothing at startup reads from the minibuffer or completes in a buffer, so
;; the completion UI loads on the first command instead: pre-command-hook runs
;; before M-x and friends call completing-read (minibuffer-setup-hook would be
;; too late for vertico), and before the first keystroke that could complete.
;; corfu stays global (eshell, comint, ... included), only enabled later.
;; If startup code ever does use the minibuffer (desktop restore, a prompt in
;; user/*.el or local.el), give these packages `:demand t' and `:config' that
;; enables their modes, and drop this hook. Otherwise that prompt gets the
;; default UI, and savehist loads the history file over the history it has
;; just recorded.
(defun ecamp-completion-ui ()
  "Enable savehist, vertico, marginalia and corfu once, before the first command."
  (remove-hook 'pre-command-hook #'ecamp-completion-ui)
  (savehist-mode 1)
  (vertico-mode 1)
  (marginalia-mode 1)
  (global-corfu-mode 1))
(add-hook 'pre-command-hook #'ecamp-completion-ui)

(use-package orderless                  ; its autoloads register the style
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :functions marginalia-mode)

(use-package consult
  :bind (([remap switch-to-buffer] . consult-buffer)
         ([remap switch-to-buffer-other-window] . consult-buffer-other-window)
         ([remap project-switch-to-buffer] . consult-project-buffer)
         ([remap yank-pop] . consult-yank-pop)
         ([remap goto-line] . consult-goto-line)
         ([remap imenu] . consult-imenu)
         ("M-s l" . consult-line)
         ("M-s r" . consult-ripgrep)
         ("M-s f" . consult-find)
         :map isearch-mode-map
         ("M-s l" . consult-line))
  :custom
  (xref-show-xrefs-function #'consult-xref)
  (xref-show-definitions-function #'consult-xref))

(use-package embark
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)
         ("C-h B" . embark-bindings))
  :custom (prefix-help-command #'embark-prefix-help-command))

(use-package embark-consult
  :hook (embark-collect-mode . consult-preview-at-point-mode))

(use-package corfu
  :functions global-corfu-mode
  :custom
  (corfu-auto t)
  (corfu-cycle t))

(use-package cape                       ; capfs are autoloaded
  :functions cape-dabbrev cape-file
  :init
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file))

;; dirvish takes over dired the first time dired loads, not at startup: the
;; first C-x d or C-x C-j pulls in dired, then dirvish, then runs as dirvish.
;; Plain dired keys still work; ? opens a transient of everything else.
(use-package dirvish
  :functions dirvish-override-dired-mode
  :defines dirvish-mode-map
  :init (with-eval-after-load 'dired (dirvish-override-dired-mode 1))
  :bind (:map dirvish-mode-map
         ("?" . dirvish-dispatch)
         ("TAB" . dirvish-subtree-toggle)
         ("s" . dirvish-quicksort)
         ("l" . dirvish-ls-switches-menu)
         ("y" . dirvish-yank-menu)
         ("M-f" . dirvish-history-go-forward)
         ("M-b" . dirvish-history-go-backward))
  :custom
  (dirvish-attributes '(vc-state subtree-state collapse file-time file-size)))

;;; Lisp

;; Structural editing for lisp buffers: parens stay balanced, C-) / C-} slurp
;; and barf. RET is left as newline-and-indent (paredit 26 takes it over,
;; which breaks RET in ielm and M-:); C-j is paredit's newline.
(use-package paredit
  :defines paredit-mode-map
  :hook ((emacs-lisp-mode lisp-mode lisp-interaction-mode scheme-mode
          clojure-mode ielm-mode eval-expression-minibuffer-setup) . paredit-mode)
  :bind (:map paredit-mode-map
         ("RET" . nil)
         ("C-j" . paredit-newline)))

;; Elisp eval results (C-x C-e, C-M-x) show inline at point, as CIDER does.
;; eros-mode is global; the first elisp buffer turns it on.
(use-package eros
  :hook (emacs-lisp-mode . eros-mode))

;; Installed only; extras/10-prog.el turns it on (a taste, not a default).
(use-package rainbow-delimiters)

;;; Git

(use-package magit
  :bind ("C-x g" . magit-status))

(use-package forge                       ; loads alongside magit, never earlier
  :after magit
  :demand t)

;; Enabled per buffer instead of global-diff-hl-mode, which would pull in vc,
;; diff-mode and log-edit at startup. diff-hl arrives with the first file.
(use-package diff-hl
  :hook ((prog-mode text-mode conf-mode) . diff-hl-mode)
  :hook (dired-mode . diff-hl-dired-mode)
  :hook (magit-post-refresh . diff-hl-magit-post-refresh))

;;; Agents

;; agent-shell runs ACP agents (Claude Code, Codex, Gemini, ...) inside a
;; comint buffer and loads on the first M-x agent-shell or
;; agent-shell-*-start-*. Every agent requires its ACP adapter on PATH, e.g.
;; claude-agent-acp or codex-acp; agent-camp installs them (<agent>-acp).
(use-package agent-shell)

;;; Keys

;; These exist only on NS builds; declare them so other OSes compile cleanly.
(defvar ns-command-modifier)
(defvar ns-alternate-modifier)
(when (eq system-type 'darwin)
  (setq ns-command-modifier 'meta        ; Cmd is Meta
        ns-alternate-modifier 'super))   ; Option is Super

;;; User layer and free zone

;; user/*.el come from a downstream through the Home Manager option
;; emacs-camp.userFiles and load sorted by name. local.el is per host and
;; unmanaged; it loads last so it can override everything.
(defvar ecamp-load-source nil
  "Non-nil: load user/*.el as source (sync.el sets it so their :ensure runs).")

;; extras/*.el are always deployed but load only when named in `ecamp-extras'.
;; Its default comes from extras-default.el (the Home Manager module writes it
;; from emacs-camp.korean.enable and the like); M-x customize-variable
;; ecamp-extras overrides that default in custom.el. Rules: docs/adr/0001-extras.md, 0002.
(load (locate-user-emacs-file "extras-default") 'noerror 'nomessage)
;; macOS /bin/ls has no --dired or GNU sort options (dirvish quicksort); the
;; module writes nix coreutils' ls into extras-default.el. Elsewhere ls is GNU.
(defvar ecamp-gnu-ls nil "GNU ls the deploy provides, or nil to keep the default.")
(when ecamp-gnu-ls
  (setq insert-directory-program ecamp-gnu-ls))
(defvar ecamp-extras-default nil
  "Extras the deploy turned on; the default of `ecamp-extras'.")
(defcustom ecamp-extras ecamp-extras-default
  "Names of extras/*.el to load at startup, e.g. (\"00-korean\")."
  :type '(repeat string)
  :group 'initialization)
(dolist (name ecamp-extras)
  (let ((f (locate-user-emacs-file (concat "extras/" name))))
    (load (if ecamp-load-source (concat f ".el") f) 'noerror 'nomessage ecamp-load-source)))
(let ((dir (locate-user-emacs-file "user")))
  (when (file-directory-p dir)
    (dolist (f (directory-files dir t "\\.el\\'"))
      (load (if ecamp-load-source f (file-name-sans-extension f))
            nil 'nomessage ecamp-load-source))))
(load (locate-user-emacs-file "local") 'noerror 'nomessage)
