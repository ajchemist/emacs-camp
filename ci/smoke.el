;;; smoke.el --- start the deployed config the way Emacs does and check it  -*- lexical-binding: t -*-

;; emacs --batch --init-directory DIR -l ci/smoke.el
;; DIR holds early-init/init (.el + .elc as the module deploys them) and the
;; packages the sync installed. Emulates startup: early-init, package
;; activation (quickstart), init. Asserts the runtime contract; prints timings.

(defvar smoke-failures 0)
(defun smoke (name ok &optional detail)
  (message "%s %s%s" (if ok "ok  " "FAIL") name (if detail (format " (%s)" detail) ""))
  (unless ok (setq smoke-failures (1+ smoke-failures))))

(defvar smoke-init-seconds)
(let ((t0 (float-time)))
  (load (locate-user-emacs-file "early-init") nil t)
  (package-activate-all)
  (load (locate-user-emacs-file "init") nil t)
  (setq smoke-init-seconds (- (float-time) t0))
  (message "init (batch emulation): %.3fs" smoke-init-seconds))

;; Init stays light: a time budget (ECAMP_INIT_BUDGET seconds, default 1.5,
;; loose enough for cold CI runners) and, sharper, the heavy libraries that
;; must wait for their first use.
(let ((budget (string-to-number (or (getenv "ECAMP_INIT_BUDGET") "1.5"))))
  (smoke "init within budget" (< smoke-init-seconds budget)
         (format "%.3fs < %.1fs" smoke-init-seconds budget)))
(let ((summary (getenv "GITHUB_STEP_SUMMARY")))
  (when (and summary (not (string-empty-p summary)))
    (write-region (format "| %s init (batch emulation) | %.3fs |\n" system-type smoke-init-seconds)
                  nil summary 'append 'silent)))
(let ((loaded (seq-filter #'featurep
                          '(magit forge transient consult embark embark-consult
                            diff-hl vc vc-git diff-mode log-edit
                            agent-shell acp shell-maker org))))
  (smoke "no heavy library loaded at init" (null loaded) (and loaded (format "%S" loaded))))

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

;; On-the-fly loading: each trigger the config advertises loads its package
;; (and only then), the way a user's first keystroke would.
(defun smoke-load-via-key (keys)
  "Autoload the command KEYS is bound to; return the command."
  (let ((cmd (key-binding (kbd keys))))
    (when (autoloadp (symbol-function cmd))
      (autoload-do-load (symbol-function cmd) cmd))
    cmd))

(smoke "C-x g autoloads magit" (and (eq (smoke-load-via-key "C-x g") 'magit-status)
                                    (featurep 'magit)))
(smoke "forge follows magit (:after)" (featurep 'forge))
(smoke "consult still unloaded before its key" (not (featurep 'consult)))
(smoke "M-s l autoloads consult" (and (eq (smoke-load-via-key "M-s l") 'consult-line)
                                      (featurep 'consult)))
(smoke "C-. autoloads embark" (and (eq (smoke-load-via-key "C-.") 'embark-act)
                                   (featurep 'embark)))
(smoke "embark-consult joins once both are loaded" (featurep 'embark-consult))
(let* ((repo (make-temp-file "smoke-repo" t))
       (file (expand-file-name "a.el" repo))
       (default-directory repo))
  (when (executable-find "git")
    (call-process "git" nil nil nil "init" "-q")
    (with-temp-file file (insert ";; a\n"))
    (call-process "git" nil nil nil "add" ".")
    (call-process "git" nil nil nil "-c" "user.name=s" "-c" "user.email=s@s" "commit" "-qm" "a")
    (with-current-buffer (find-file-noselect file)
      (smoke "visiting a file turns on diff-hl" (bound-and-true-p diff-hl-mode))
      ;; corfu itself skips batch sessions; ask as an interactive buffer would.
      (let ((noninteractive nil)) (corfu--on))
      (smoke "corfu active in the file buffer" (bound-and-true-p corfu-mode))
      (smoke "cape capfs in place" (memq 'cape-dabbrev (default-value 'completion-at-point-functions)))
      (kill-buffer))))

(let ((t1 (float-time)))
  (require 'agent-shell)
  (message "first agent-shell load: %.3fs" (- (float-time) t1)))

(kill-emacs (if (zerop smoke-failures) 0 1))
