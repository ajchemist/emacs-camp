;;; init.el --- emacs-camp  -*- lexical-binding: t -*-

;; Load order: this file -> custom.el -> user/*.el -> local.el.
;; ~/.config/emacs is a real directory; elpa/, eln-cache/, custom.el and
;; local.el are written there by Emacs or by hand, never by emacs-camp.

;;; Packages

;; Windows builds of Emacs fail the TLS 1.3 handshake with elpa.gnu.org and
;; elpa.nongnu.org ("Failed to download `gnu' archive"), and compat lives there.
(defvar gnutls-algorithm-priority)
(when (eq system-type 'windows-nt)
  (setq gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3"))

;; package.el + MELPA, deliberately not Nix: the packages worth following move
;; daily and a Nix snapshot of MELPA trails by weeks.
(require 'package)
(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")
        ("melpa-stable" . "https://stable.melpa.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("gnu" . "https://elpa.gnu.org/packages/"))
      package-archive-priorities
      '(("melpa" . 4) ("melpa-stable" . 3) ("nongnu" . 2) ("gnu" . 1))
      ;; native-compile at install time, not on first load
      package-native-compile t)

;; The use-package blocks are the package list. :ensure (on for all) installs
;; a missing package when its block is read but never loads it: loading waits
;; for a :hook/:bind/:mode/:commands trigger (always-defer). Only blocks that
;; must load at startup say `:demand t'. :ensure acts only where this file
;; is loaded as source: byte-compiled, use-package drops it from the .elc.
;; So under the Home Manager module (which links a compiled init) installing
;; is sync.el's job, at deploy in the background; without it (plain copy, no
;; .elc) it happens at start. A source start during a sync skips :ensure so
;; two processes never write elpa/ at once.
;; eval-and-compile: these must hold while the byte-compiler expands the
;; use-package forms below, not only when the .elc runs; otherwise the .elc
;; is expanded with the defaults and `require's every package at startup.
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
        ;; EMACS_USE_PACKAGE_STATS=1, then M-x use-package-report. Baked in at
        ;; compile time like the rest, so it needs init.el loaded as source.
        use-package-compute-statistics (getenv "EMACS_USE_PACKAGE_STATS")))

;; macOS vets each .eln on its first dlopen (~0.3s, serialised). Whatever
;; package.el compiles into eln-cache/ is vetted by the warmer the Home
;; Manager module links as ./eln-warm: at startup, and after each compile batch.
(defvar native-comp-eln-load-path)        ; absent without native-comp
(defun ecamp-eln-warm ()
  (let ((warm (expand-file-name (locate-user-emacs-file "eln-warm"))))
    (when (file-executable-p warm)
      (start-process "eln-warm" nil warm
                     (expand-file-name (car native-comp-eln-load-path))))))
(when (eq system-type 'darwin)
  (add-hook 'emacs-startup-hook #'ecamp-eln-warm)
  (add-hook 'native-comp-async-all-done-hook #'ecamp-eln-warm))

;;; Custom writes here, never into init.el.

(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror 'nomessage)

;;; UI

(column-number-mode 1)
(when (fboundp 'fringe-mode)               ; absent without a window system
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

;; Emacs.app started from the Dock or Finder gets launchd's PATH, not the
;; login shell's, so CLIs installed by bun, fnm, Homebrew... are missing.
;; Only then (no TERM: not started from a terminal) ask the shell once.
(use-package exec-path-from-shell
  :if (and (memq window-system '(mac ns)) (not (getenv "TERM")))
  :demand t
  :functions exec-path-from-shell-initialize
  :config (exec-path-from-shell-initialize))

;;; Completion

;; Minibuffer: vertico shows the candidates of the built-in completing-read,
;; orderless matches space-separated pieces in any order, marginalia
;; annotates them, consult adds the search/jump commands, embark acts on the
;; candidate at point. In buffers: corfu pops up completion-at-point, cape
;; adds more capfs to it.

(use-package vertico
  :demand t
  :functions vertico-mode
  :config (vertico-mode 1))

(use-package savehist                   ; vertico sorts by this history
  :ensure nil
  :demand t
  :config (savehist-mode 1))

(use-package orderless
  :demand t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :demand t
  :functions marginalia-mode
  :config (marginalia-mode 1))

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
  :demand t
  :functions global-corfu-mode
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  :config (global-corfu-mode 1))

(use-package cape
  :demand t
  :functions cape-dabbrev cape-file
  :config
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file))

;;; Git

(use-package magit
  :bind ("C-x g" . magit-status))

(use-package forge                       ; with magit, not before
  :after magit
  :demand t)

;; Per buffer, not global-diff-hl-mode: that would load vc, diff-mode and
;; log-edit at startup. diff-hl loads with the first file buffer.
(use-package diff-hl
  :hook ((prog-mode text-mode conf-mode) . diff-hl-mode)
  :hook (dired-mode . diff-hl-dired-mode)
  :hook (magit-post-refresh . diff-hl-magit-post-refresh))

;;; Agents

;; agent-shell: ACP agents (Claude Code, Codex, Gemini, ...) in a comint
;; buffer. Loads on the first M-x agent-shell / agent-shell-*-start-*.
;; Each agent needs its ACP adapter on PATH: claude-agent-acp, codex-acp, ...
;; (see agent-shell's README).
(use-package agent-shell)

;;; Keys

;; NS-only variables: declared so the file compiles on every OS.
(defvar ns-command-modifier)
(defvar ns-alternate-modifier)
(when (eq system-type 'darwin)
  (setq ns-command-modifier 'meta        ; Cmd is Meta
        ns-alternate-modifier 'super))   ; Option is Super
(global-set-key [C-wheel-up] #'text-scale-decrease)
(global-set-key [C-wheel-down] #'text-scale-increase)

;;; User layer and free zone

;; user/*.el: files a downstream supplies (Home Manager option
;; emacs-camp.userFiles), loaded in name order. local.el: unmanaged, per
;; host, loaded last so it can override anything.
(defvar ecamp-load-source nil
  "Non-nil: load user/*.el as source (sync.el sets it so their :ensure runs).")
(let ((dir (locate-user-emacs-file "user")))
  (when (file-directory-p dir)
    (dolist (f (directory-files dir t "\\.el\\'"))
      (load (if ecamp-load-source f (file-name-sans-extension f))
            nil 'nomessage ecamp-load-source))))
(load (locate-user-emacs-file "local") 'noerror 'nomessage)
