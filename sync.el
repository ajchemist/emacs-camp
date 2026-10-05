;;; sync.el --- emacs-camp: deploy-time package sync  -*- lexical-binding: t -*-

;; Run in the background by the Home Manager module after each switch
;; (`emacs --batch -l sync.el'): load init.el exactly as a start would, so
;; every use-package :ensure block installs what is missing; native-compile
;; elpa/ and wait for it; refresh package-quickstart. The module then runs the
;; macOS warmer over eln-cache/. Installed packages are never upgraded here
;; (M-x package-upgrade-all). Nothing missing means no network.

(require 'package)
(package-initialize)
(defvar ecamp-sync-t0 (float-time))
(defun ecamp-sync-phase (what)
  (message "emacs-camp sync: %s %.1fs" what (- (float-time) ecamp-sync-t0))
  (setq ecamp-sync-t0 (float-time)))
;; Sources, not the .elc: use-package runs :ensure at byte-compile time and
;; leaves it out of the compiled code, so init.elc (and user/*.elc) never
;; install anything. Loading the .el expands the macros now, :ensure included.
(defvar ecamp-load-source t)
(load (locate-user-emacs-file "init.el") nil t t)
(ecamp-sync-phase "install")

(require 'comp-run nil t)
(when (and (fboundp 'native-comp-available-p) (native-comp-available-p))
  ;; Every core, not the default half: this runs in the background, and on
  ;; a 3-core machine half means a single compile job.
  (setq native-comp-async-jobs-number (num-processors))
  (native-compile-async package-user-dir 'recursively)
  (while (or comp-files-queue
             (> (if (fboundp 'comp--async-runnings) (comp--async-runnings) (comp-async-runnings)) 0))
    (sleep-for 1)))

(ecamp-sync-phase "native-compile")
(package-quickstart-refresh)
(message "emacs-camp sync: done (%d packages)" (length package-alist))
