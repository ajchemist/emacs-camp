;;; 00-korean.el --- emacs-camp: Korean input and text  -*- lexical-binding: t -*-

;; Loaded when "00-korean" is in `ecamp-extras' (emacs-camp.extras
;; sets that default), before user/*.el, so a downstream file can override
;; anything here.

;; The Korean language environment gives C-\ the 2-beolsik hangul input
;; method, but it also prefers EUC-KR; put UTF-8 back on top so new files,
;; processes and the terminal stay UTF-8. Old EUC-KR/CP949 files are still
;; detected on read.
(set-language-environment "Korean")
(prefer-coding-system 'utf-8)
(setq default-input-method "korean-hangul")

;; macOS stores hangul file names decomposed (NFD); without this dired and
;; find-file show split jamo.  utf-8-hfs (built-in ucs-normalize) reads them
;; back as NFC and writes NFD.  Emacs usually picks it already; pin it so a
;; language-environment change can't undo it.
(when (eq system-type 'darwin)
  (set-file-name-coding-system 'utf-8-hfs)
  ;; Shell output (ls in shell-mode, M-!) prints those names too.
  (add-to-list 'process-coding-system-alist
               '("\\(?:\\`\\|/\\)\\(?:ba\\|z\\)?sh\\'" . (utf-8-hfs . utf-8-unix))))

;; The hangul and hanja keys of a Korean keyboard (Linux/X), plus S-SPC as on
;; Windows, toggle the input method; F9 converts the hangul before point to
;; hanja.
(autoload 'hangul-to-hanja-conversion "hangul" nil t)
(keymap-global-set "<Hangul>" #'toggle-input-method)
(keymap-global-set "S-SPC" #'toggle-input-method)
(keymap-global-set "<Hangul_Hanja>" #'hangul-to-hanja-conversion)
(keymap-global-set "<f9>" #'hangul-to-hanja-conversion)

;;; 00-korean.el ends here
