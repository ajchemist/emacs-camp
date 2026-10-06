;;; sync.el --- emacs-camp: deploy-time package sync  -*- lexical-binding: t -*-

;; The Home Manager module starts this in the background after every switch
;; (`emacs --batch -l sync.el'). It loads init.el the same way a normal start
;; does, so each use-package :ensure block installs anything absent; then it
;; native-compiles elpa/, waits for that to finish, and regenerates
;; package-quickstart. Afterwards the module runs the macOS warmer on
;; eln-cache/. Upgrades never happen here (use M-x package-upgrade-all), and
;; if nothing is missing the network is not touched.

(require 'package)
(package-initialize)
(defvar ecamp-sync-t0 (float-time))
(defun ecamp-sync-phase (what)
  (message "emacs-camp sync: %s %.1fs" what (- (float-time) ecamp-sync-t0))
  (setq ecamp-sync-t0 (float-time)))
;; Load the .el files, not the .elc: use-package handles :ensure during
;; byte-compilation and omits it from the output, so init.elc and user/*.elc
;; can't install. Reading the source expands the macros here, :ensure and all.
(defvar ecamp-load-source t)
(load (locate-user-emacs-file "init.el") nil t t)
(ecamp-sync-phase "install")

(require 'comp-run nil t)
(when (and (fboundp 'native-comp-available-p) (native-comp-available-p))
  ;; Use all cores instead of the default half. Nobody waits on this, and
  ;; half of a 3-core machine is just one compile job.
  (setq native-comp-async-jobs-number (num-processors))
  (native-compile-async package-user-dir 'recursively)
  (while (or comp-files-queue
             (> (if (fboundp 'comp--async-runnings) (comp--async-runnings) (comp-async-runnings)) 0))
    (sleep-for 1)))

(ecamp-sync-phase "native-compile")
(package-quickstart-refresh)
(message "emacs-camp sync: done (%d packages)" (length package-alist))
