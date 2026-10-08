;;; sync.el --- emacs-camp: deploy-time package sync  -*- lexical-binding: t -*-

;; The Home Manager module starts this in the background after every switch
;; (`emacs --batch -l sync.el'). It loads init.el the same way a normal start
;; does, so each use-package :ensure block installs anything absent. Then it
;; makes every package those blocks name, and their dependencies in elpa/,
;; match the pinned snapshot (`ecamp-elpa-snapshot', docs/adr/0004): a
;; different installed version is reinstalled, upgrade or downgrade alike.
;; Packages nobody names are left alone. Last it native-compiles elpa/, waits
;; for that, and regenerates package-quickstart; the module then runs the
;; macOS warmer on eln-cache/. If the snapshot is unchanged and nothing is
;; off, the network is not touched.

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

(defvar ecamp-elpa-snapshot)
(defvar ecamp-elpa-mirrors)
(defvar ecamp-sync-wanted nil "Packages the :ensure blocks named.")
(defvar ecamp-sync-started nil)
(defvar ecamp-sync-mirrors nil "Mirror URLs not tried yet in this sync.")
(defvar ecamp-sync-stamp (expand-file-name "archives/ecamp-snapshot" package-user-dir)
  "The snapshot the archive indexes were last fetched for.")

;; package.el caches each index under the archive's name, not its URL, so a
;; new snapshot needs an explicit refetch. melpa points at the next mirror
;; that serves the index; that mirror then also serves the tarballs.
(defun ecamp-sync-index ()
  "Point melpa at the next mirror serving the snapshot; refetch all indexes."
  (let ((index (expand-file-name "archives/melpa/archive-contents" package-user-dir)))
    (while (progn
             (unless ecamp-sync-mirrors
               (error "emacs-camp sync: no mirror serves snapshot %s" ecamp-elpa-snapshot))
             (setf (alist-get "melpa" package-archives nil nil #'equal)
                   (format (pop ecamp-sync-mirrors) ecamp-elpa-snapshot))
             (message "emacs-camp sync: index from %s" (cdr (assoc "melpa" package-archives)))
             (ignore-errors (delete-file index))
             (package-refresh-contents)
             (not (file-exists-p index))))
    (with-temp-file ecamp-sync-stamp (insert ecamp-elpa-snapshot))))

;; Runs on the first :ensure, by which point init.el has set the snapshot.
(defun ecamp-sync-start ()
  (setq ecamp-sync-mirrors ecamp-elpa-mirrors)
  (if (and (file-exists-p (expand-file-name "archives/melpa/archive-contents" package-user-dir))
           (equal (ignore-errors (with-temp-buffer
                                   (insert-file-contents ecamp-sync-stamp)
                                   (buffer-string)))
                  ecamp-elpa-snapshot))
      (progn (pop ecamp-sync-mirrors)   ; current; init.el's URL serves it
             (package-read-all-archive-contents))
    (ecamp-sync-index)))

(setq use-package-ensure-function
      (lambda (name args state &rest r)
        (unless ecamp-sync-started
          (setq ecamp-sync-started t)
          (ecamp-sync-start))
        (dolist (e args)
          (let ((p (if (eq e t) (use-package-as-symbol name) e)))
            (when (consp p) (setq p (car p)))
            (when p (push p ecamp-sync-wanted))))
        (apply #'use-package-ensure-elpa name args state r)))
(load (locate-user-emacs-file "init.el") nil t t)
(ecamp-sync-phase "install")

;; Read elpa/ and the cached indexes afresh: a start with package-quickstart
;; fills neither, and package-delete keeps the deleted version in
;; package-alist while another version of the package is installed (Emacs 31).
(defun ecamp-sync-read ()
  (setq package-alist nil)
  (package-load-all-descriptors)
  (package-read-all-archive-contents))

(defun ecamp-sync-names ()
  "The wanted packages, plus their dependencies that live in elpa/."
  (let ((todo ecamp-sync-wanted) names)
    (while todo
      (let ((n (pop todo)))
        (unless (memq n names)
          (push n names)
          (dolist (r (when-let* ((d (cadr (assq n package-archive-contents))))
                       (package-desc-reqs d)))
            (when (assq (car r) package-alist) (push (car r) todo))))))
    names))

(defun ecamp-sync-off-p (name)
  "Non-nil if NAME is wanted but missing, or not at the snapshot's version."
  (let ((have (cadr (assq name package-alist)))
        (want (cadr (assq name package-archive-contents))))
    (if have
        (and want (not (package-vc-p have))
             (not (equal (package-desc-version have) (package-desc-version want))))
      (and (memq name ecamp-sync-wanted) (not (package-installed-p name))))))

;; `package-upgrade' installs the archive's version whenever it differs from
;; the installed one, so it downgrades too, and deletes the old one.
(defun ecamp-sync-converge ()
  "Install or reinstall every package that is off; return those still off."
  (ecamp-sync-read)
  (dolist (name (ecamp-sync-names))
    (when (ecamp-sync-off-p name)
      (with-demoted-errors "emacs-camp sync: %S"
        (if (assq name package-alist) (package-upgrade name) (package-install name)))))
  (ecamp-sync-read)
  (seq-filter #'ecamp-sync-off-p (ecamp-sync-names)))

;; A mirror can serve the index and still fail a tarball: then the next
;; mirror, once.
(when (and (ecamp-sync-converge) ecamp-sync-mirrors)
  (ecamp-sync-index)
  (ecamp-sync-converge))
(let ((off (seq-filter #'ecamp-sync-off-p (ecamp-sync-names))))
  (when off
    (ignore-errors (delete-file ecamp-sync-stamp)) ; the next sync refetches the index
    (message "emacs-camp sync: not at snapshot %s: %s" ecamp-elpa-snapshot off)))
(ecamp-sync-phase "converge")

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
