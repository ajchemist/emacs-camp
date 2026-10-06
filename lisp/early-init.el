;;; early-init.el --- emacs-camp: before the first frame  -*- lexical-binding: t -*-

;; Set frame decorations this early so the first frame is drawn without them.
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
;; On macOS the menu bar lives outside the frame and is free, so keep it;
;; on X11 and tty remove the one drawn inside the frame.
(unless (eq system-type 'darwin)
  (push '(menu-bar-lines . 0) default-frame-alist))
(setq inhibit-startup-screen t)

;; Disable GC during init, then use a reasonable limit for the session. The
;; stock 800KB threshold makes an init with many packages collect dozens of
;; times; with this it collects once.
(setq gc-cons-threshold most-positive-fixnum)
(add-hook 'emacs-startup-hook (lambda () (setq gc-cons-threshold (* 100 1024 1024))))

;; Before init.el runs, package.el activates each installed package by loading
;; its *-autoloads.el. Quickstart merges all of those into a single precompiled
;; file that package.el regenerates on install/delete/upgrade. Only works if
;; set in early-init.
(defvar package-quickstart)
(setq package-quickstart t)
