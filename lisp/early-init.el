;;; early-init.el --- emacs-camp: before the first frame  -*- lexical-binding: t -*-

;; Frame chrome is decided here so the first frame never shows it.
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
;; macOS keeps its system menu bar (outside the frame, costs nothing);
;; X11 and tty drop the in-frame one.
(unless (eq system-type 'darwin)
  (push '(menu-bar-lines . 0) default-frame-alist))
(setq inhibit-startup-screen t)

;; No GC while init runs, then a sane ceiling for the session. Emacs still
;; starts interactive sessions at the 800KB threshold: a package-heavy init
;; collects dozens of times; this makes it once.
(setq gc-cons-threshold most-positive-fixnum)
(add-hook 'emacs-startup-hook (lambda () (setq gc-cons-threshold (* 100 1024 1024))))

;; package.el activates every installed package (each *-autoloads.el) before
;; init.el; quickstart concatenates them into one precompiled file, which
;; package.el itself refreshes on install/delete/upgrade. Must be set here.
(defvar package-quickstart)
(setq package-quickstart t)
