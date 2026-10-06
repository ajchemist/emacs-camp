;;; smoke.el --- start the deployed config the way Emacs does and check it  -*- lexical-binding: t -*-

;; emacs --batch --init-directory DIR -l ci/smoke.el
;; DIR contains early-init/init (.el and .elc, as deployed by the module) plus
;; the packages from the sync. Replays startup (early-init, package activation
;; via quickstart, init), checks the runtime contract and reports timings.

(defvar smoke-failures 0)
(defun smoke (name ok &optional detail)
  (message "%s %s%s" (if ok "ok  " "FAIL") name (if detail (format " (%s)" detail) ""))
  (unless ok (setq smoke-failures (1+ smoke-failures))))

(defvar smoke-init-seconds)
(defvar smoke-init-features)
(defvar smoke-init-gcs)
(let ((t0 (float-time)) (f0 features))
  (load (locate-user-emacs-file "early-init") nil t)
  (package-activate-all)
  (load (locate-user-emacs-file "init") nil t)
  (setq smoke-init-seconds (- (float-time) t0)
        smoke-init-features (length (seq-difference features f0))
        smoke-init-gcs gcs-done)
  (message "init (batch emulation): %.3fs" smoke-init-seconds))

;; Child mode (ECAMP_LOAD_ONE=PKG): after the same init, time the first
;; `require' of one package and print one line for the parent's report. A
;; fresh process per package, so what an earlier package dragged in never
;; makes a later one look cheap.
(let ((one (getenv "ECAMP_LOAD_ONE")))
  (when (and one (not (string-empty-p one)))
    (let ((pkg (intern one)) (f0 features) (t0 (float-time)))
      (if (featurep pkg)
          (princ (format "LOADONE %s init 0 0\n" pkg))
        (condition-case e
            (progn (require pkg)
                   (princ (format "LOADONE %s ok %.3f %d\n" pkg (- (float-time) t0)
                                  (length (seq-difference features f0)))))
          (error (princ (format "LOADONE %s error 0 0 %S\n" pkg e))))))
    (kill-emacs 0)))

;; Keep init light: a time limit (ECAMP_INIT_BUDGET seconds, 1.5 by default,
;; generous for cold CI machines) and, more precisely, a list of heavy
;; libraries that must not load before they are used.
(let ((budget (string-to-number (or (getenv "ECAMP_INIT_BUDGET") "1.5"))))
  (smoke "init within budget" (< smoke-init-seconds budget)
         (format "%.3fs < %.1fs" smoke-init-seconds budget)))
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
;; The completion UI waits for the first command (ecamp-completion-ui).
(smoke "completion UI not loaded at init"
       (not (seq-some #'featurep '(vertico marginalia corfu cape orderless))))
(smoke "completion UI armed on pre-command-hook" (memq 'ecamp-completion-ui (default-value 'pre-command-hook)))
(run-hooks 'pre-command-hook)           ; what the first keystroke does
(smoke "first command turns the completion UI on"
       (and (bound-and-true-p vertico-mode) (bound-and-true-p savehist-mode)
            (bound-and-true-p marginalia-mode) (bound-and-true-p global-corfu-mode)))
(smoke "completion UI hook removes itself" (not (memq 'ecamp-completion-ui (default-value 'pre-command-hook))))
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

;; Lazy loading: every trigger the config promises pulls in its package, and
;; nothing earlier does, just as a user's first key press would.
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
      ;; corfu stays off in batch, so pretend to be interactive when enabling it.
      (let ((noninteractive nil)) (corfu--on))
      (smoke "corfu active in the file buffer" (bound-and-true-p corfu-mode))
      (smoke "cape capfs in place" (memq 'cape-dabbrev (default-value 'completion-at-point-functions)))
      (kill-buffer))))

(let ((t1 (float-time)))
  (require 'agent-shell)
  (message "first agent-shell load: %.3fs" (- (float-time) t1)))

;; Report: init, then each use-package package loaded on its own after init.
;; Printed to the log; also the job summary under GitHub Actions.
(defun smoke-packages ()
  "The packages init.el declares, in order."
  (with-temp-buffer
    (insert-file-contents (locate-user-emacs-file "init.el"))
    (let (pkgs)
      (while (re-search-forward "^(use-package \\([^ \n)]+\\)" nil t)
        (push (intern (match-string 1)) pkgs))
      (nreverse pkgs))))

(defun smoke-load-one (pkg)
  "Load PKG after init in a fresh Emacs; return (STATUS SECONDS FEATURES ERROR)."
  (with-temp-buffer
    (let ((process-environment (cons (format "ECAMP_LOAD_ONE=%s" pkg) process-environment)))
      (call-process (expand-file-name invocation-name invocation-directory) nil t nil
                    "--batch" "--init-directory" user-emacs-directory "-l" smoke-file))
    (goto-char (point-min))
    (if (re-search-forward "^LOADONE [^ ]+ \\([a-z]+\\) \\([0-9.]+\\) \\([0-9]+\\) ?\\(.*\\)$" nil t)
        (list (match-string 1) (string-to-number (match-string 2))
              (string-to-number (match-string 3)) (match-string 4))
      (list "error" 0 0 (string-trim (buffer-string))))))

(defvar smoke-file (or load-file-name buffer-file-name))
(let* ((budget (string-to-number (or (getenv "ECAMP_LOAD_BUDGET") "2.0")))
       (label (or (getenv "ECAMP_SMOKE_LABEL") (format "%s" system-type)))
       (rows nil))
  (dolist (pkg (smoke-packages))
    (if (not (or (featurep pkg) (locate-library (symbol-name pkg))))
        (push (format "| `%s` | not installed here (`:if`) | | | |" pkg) rows)
      (pcase-let ((`(,status ,secs ,feats ,err) (smoke-load-one pkg)))
        (pcase status
          ("init" (push (format "| `%s` | already loaded by init | | | ok |" pkg) rows))
          ;; Loading must work; the time is a measurement. Shared runners are
          ;; noisy (macOS has doubled magit's time between runs), so over the
          ;; budget is a warning annotation, not a failure.
          ("ok" (smoke (format "%s loads after init" pkg) t
                       (format "%.3fs, %d features" secs feats))
                (when (and (>= secs budget) (getenv "GITHUB_ACTIONS"))
                  (message "::warning::%s first load %.3fs exceeds %.1fs (%s)" pkg secs budget label))
                (push (format "| `%s` | on first use | %.3f | %d | %s |" pkg secs feats
                              (if (< secs budget) "ok" (format "**slow** (> %.1fs)" budget)))
                      rows))
          (_ (smoke (format "%s loads after init" pkg) nil err)
             (push (format "| `%s` | on first use | | | **error** `%s` |" pkg err) rows))))))
  (let ((report
         (concat
          (format "### smoke: %s (Emacs %s)\n\n" label emacs-version)
          "| init (batch emulation) | features loaded | GCs | budget |\n|---|---|---|---|\n"
          (format "| %.3fs | %d | %d | %.1fs |\n\n" smoke-init-seconds smoke-init-features
                  smoke-init-gcs (string-to-number (or (getenv "ECAMP_INIT_BUDGET") "1.5")))
          (format "Each package below is required in a fresh Emacs after init (budget %.1fs).\n\n" budget)
          "| package | loads | first load (s) | features pulled in | |\n|---|---|---:|---:|---|\n"
          (mapconcat #'identity (nreverse rows) "\n") "\n\n"
          (format "%d check(s) failed.\n\n" smoke-failures)))
        (summary (getenv "GITHUB_STEP_SUMMARY")))
    (message "\n%s" report)
    (when (and summary (not (string-empty-p summary)))
      (write-region report nil summary 'append 'silent))))

(kill-emacs (if (zerop smoke-failures) 0 1))
