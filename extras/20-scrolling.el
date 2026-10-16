;;; 20-scrolling.el --- emacs-camp: pixel-precise wheel and trackpad scrolling  -*- lexical-binding: t -*-

;; Loaded when "20-scrolling" is in `ecamp-extras'. Enable after init so
;; user files can choose scroll margins and wheel settings first. Reuses
;; pixel-scroll-precision-mode; no separate activation of that mode is needed.
;; Keyboard movement margins remain controlled by the built-in scroll-* options.
;; M-x ultra-scroll-check diagnoses pixel input support on the current device.

(use-package ultra-scroll
  :hook (after-init . ultra-scroll-mode))

;;; 20-scrolling.el ends here
