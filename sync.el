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
;; The archive index is fetched once, and installing everything takes
;; minutes. If MELPA rebuilds a package meanwhile, the old tarball is gone
;; (404) and :ensure only warns. Still missing afterwards: refetch, retry once.
(setq use-package-ensure-function
      (lambda (name args state &rest r)
        (apply #'use-package-ensure-elpa name args state r)
        (dolist (e args)
          (let ((p (if (eq e t) (use-package-as-symbol name) e)))
            (when (consp p) (setq p (car p)))
            (when (and p (not (package-installed-p p)))
              (package-refresh-contents)
              (apply #'use-package-ensure-elpa name args state r))))))
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

;; eln-cache/ keeps one <version>-<hash>/ per Emacs build that ever ran with
;; this directory; only the running build's is read. Drop the others (the
;; cost of being wrong is a re-JIT if an older build comes back).
(when (bound-and-true-p comp-native-version-dir)
  (let ((cache (expand-file-name "eln-cache" user-emacs-directory)))
    (when (file-directory-p cache)
      (dolist (d (directory-files cache t "\\`[0-9]"))
        (when (and (file-directory-p d)
                   (not (equal (file-name-nondirectory d) comp-native-version-dir)))
          (delete-directory d t)
          (message "emacs-camp sync: pruned eln-cache/%s" (file-name-nondirectory d)))))))
(package-quickstart-refresh)
(message "emacs-camp sync: done (%d packages)" (length package-alist))
