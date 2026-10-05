;;; sync.el --- emacs-camp: deploy-time package sync  -*- lexical-binding: t -*-

;; Run in the background by the Home Manager module after each switch
;; (`emacs --batch -l sync.el'): load init.el exactly as a start would, so
;; every use-package :ensure block installs what is missing; native-compile
;; elpa/ and wait for it; refresh package-quickstart. The module then runs the
;; macOS warmer over eln-cache/. Installed packages are never upgraded here
;; (M-x package-upgrade-all). Nothing missing means no network.

(require 'package)
(package-initialize)
(load (locate-user-emacs-file "init") nil t)

(require 'comp-run nil t)
(when (and (fboundp 'native-comp-available-p) (native-comp-available-p))
  (native-compile-async package-user-dir 'recursively)
  (while (or comp-files-queue (> (comp--async-runnings) 0))
    (sleep-for 1)))

(package-quickstart-refresh)
(message "emacs-camp sync: done (%d packages)" (length package-alist))
