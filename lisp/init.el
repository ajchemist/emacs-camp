;;; init.el --- emacs-camp  -*- lexical-binding: t -*-

;; Load order: this file -> custom.el -> user/*.el -> local.el.
;; ~/.config/emacs is a real directory; elpa/, eln-cache/, custom.el and
;; local.el are written there by Emacs or by hand, never by emacs-camp.

;;; Packages

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
;; must load at startup say `:demand t'. Under the Home Manager module the
;; installing happens at deploy, in the background (sync.el); a start
;; meanwhile skips :ensure so two processes never write elpa/ at once.
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
      ;; EMACS_USE_PACKAGE_STATS=1 emacs, then M-x use-package-report.
      use-package-compute-statistics (getenv "EMACS_USE_PACKAGE_STATS"))

;; macOS vets each .eln on its first dlopen (~0.3s, serialised). Whatever
;; package.el compiles into eln-cache/ is vetted by the warmer the Home
;; Manager module links as ./eln-warm: at startup, and after each compile batch.
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
(fringe-mode '(12 . 12))
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

;;; Agents

;; agent-shell: ACP agents (Claude Code, Codex, Gemini, ...) in a comint
;; buffer. Loads on the first M-x agent-shell / agent-shell-*-start-*.
;; Each agent needs its ACP adapter on PATH: claude-agent-acp, codex-acp, ...
;; (see agent-shell's README).
(use-package agent-shell)

;;; Keys

(when (eq system-type 'darwin)
  (setq ns-command-modifier 'meta        ; Cmd is Meta
        ns-alternate-modifier 'super))   ; Option is Super
(global-set-key [C-wheel-up] #'text-scale-decrease)
(global-set-key [C-wheel-down] #'text-scale-increase)

;;; User layer and free zone

;; user/*.el: files a downstream supplies (Home Manager option
;; emacs-camp.userFiles), loaded in name order. local.el: unmanaged, per
;; host, loaded last so it can override anything.
(let ((dir (locate-user-emacs-file "user")))
  (when (file-directory-p dir)
    (dolist (f (directory-files dir t "\\.el\\'"))
      (load (file-name-sans-extension f) nil 'nomessage))))
(load (locate-user-emacs-file "local") 'noerror 'nomessage)
