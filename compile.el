;;; compile.el --- emacs-camp: load before any batch compile of its files  -*- lexical-binding: t -*-

;; emacs --batch -l compile.el -f batch-byte-compile FILE...  (or batch-native-compile)
;; :ensure is off while compiling: otherwise packages download in the middle
;; of it (offline in the Nix sandbox), and the output requires all of them
;; at startup. sync.el is what installs packages.
;; Installed packages (elpa/) are activated so use-package can load them at
;; compile time and expand their macros; without that each block prints
;; "Cannot load X". A no-op in the sandbox and before the first sync.
(require 'package)
(package-activate-all)
(require 'use-package)
(setq use-package-ensure-function 'ignore)
