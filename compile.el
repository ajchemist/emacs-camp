;;; compile.el --- emacs-camp: load before any batch compile of its files  -*- lexical-binding: t -*-

;; emacs --batch -l compile.el -f batch-byte-compile FILE...  (or batch-native-compile)
;; :ensure is off while compiling: otherwise packages download in the middle
;; of it (offline in the Nix sandbox), and the output requires all of them
;; at startup. sync.el is what installs packages.
(require 'use-package)
(setq use-package-ensure-function 'ignore)
