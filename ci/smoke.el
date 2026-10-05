;;; smoke.el --- start the deployed config the way Emacs does and check it  -*- lexical-binding: t -*-

;; emacs --batch --init-directory DIR -l ci/smoke.el
;; DIR holds early-init/init (.el + .elc as the module deploys them) and the
;; packages the sync installed. Emulates startup: early-init, package
;; activation (quickstart), init. Asserts the runtime contract; prints timings.

(defvar smoke-failures 0)
(defun smoke (name ok &optional detail)
  (message "%s %s%s" (if ok "ok  " "FAIL") name (if detail (format " (%s)" detail) ""))
  (unless ok (setq smoke-failures (1+ smoke-failures))))

(let ((t0 (float-time)))
  (load (locate-user-emacs-file "early-init") nil t)
  (package-activate-all)
  (load (locate-user-emacs-file "init") nil t)
  (message "init (batch emulation): %.3fs" (- (float-time) t0)))

(smoke "init loaded from .elc"
       (string-suffix-p "init.elc" (or (car (seq-find (lambda (e) (string-match-p "/init\\.elc?\\'" (or (car e) "")))
                                                      load-history))
                                       "")))
(smoke "use-package always-defer" (eq use-package-always-defer t))
(smoke "package-quickstart on" (bound-and-true-p package-quickstart))
(smoke "custom-file in user dir" (equal custom-file (locate-user-emacs-file "custom.el")))
(smoke "catppuccin latte enabled" (and (memq 'catppuccin custom-enabled-themes)
                                       (eq (bound-and-true-p catppuccin-flavor) 'latte)))
(dolist (p '(vertico orderless marginalia consult embark embark-consult corfu cape
             magit forge diff-hl))
  (smoke (format "%s installed" p) (package-installed-p p)))
(smoke "vertico/marginalia/corfu modes on"
       (and (bound-and-true-p vertico-mode) (bound-and-true-p marginalia-mode)
            (bound-and-true-p global-corfu-mode)))
(smoke "orderless completion style" (memq 'orderless completion-styles))
(smoke "magit deferred (not loaded at init)" (not (featurep 'magit)))
(smoke "agent-shell installed" (package-installed-p 'agent-shell))
(smoke "agent-shell deferred (not loaded at init)" (not (featurep 'agent-shell)))
(smoke "agent-shell command is an autoload" (autoloadp (symbol-function 'agent-shell)))
(smoke "agent-shell deps not loaded at init"
       (not (seq-some #'featurep '(acp shell-maker))))
(when (and (fboundp 'native-comp-available-p) (native-comp-available-p))
  (let ((eln (comp-el-to-eln-filename (locate-user-emacs-file "init.el"))))
    (smoke "init.el native-compiled" (file-exists-p eln) (file-name-nondirectory eln))))
(when (eq system-type 'darwin)
  (smoke "macOS keys" (and (eq ns-command-modifier 'meta) (eq ns-alternate-modifier 'super))))

(let ((t1 (float-time)))
  (require 'agent-shell)
  (message "first agent-shell load: %.3fs" (- (float-time) t1)))

(kill-emacs (if (zerop smoke-failures) 0 1))
