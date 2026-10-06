;;; 00-korean.el --- emacs-camp: Korean input and text  -*- lexical-binding: t -*-

;; Loaded as user/00-korean.el when emacs-camp.korean.enable is set: first of
;; the user files, so a downstream file can override anything here.

;; The Korean language environment gives C-\ the 2-beolsik hangul input
;; method, but it also prefers EUC-KR; put UTF-8 back on top so new files,
;; processes and the terminal stay UTF-8. Old EUC-KR/CP949 files are still
;; detected on read.
(set-language-environment "Korean")
(prefer-coding-system 'utf-8)
(setq default-input-method "korean-hangul")

;; The hangul and hanja keys of a Korean keyboard (Linux/X), plus S-SPC as on
;; Windows, toggle the input method; F9 converts the hangul before point to
;; hanja.
(autoload 'hangul-to-hanja-conversion "hangul" nil t)
(keymap-global-set "<Hangul>" #'toggle-input-method)
(keymap-global-set "S-SPC" #'toggle-input-method)
(keymap-global-set "<Hangul_Hanja>" #'hangul-to-hanja-conversion)
(keymap-global-set "<f9>" #'hangul-to-hanja-conversion)

;; GUI frames: a hangul font for hangul, whatever the default font is.
(defun ecamp-korean-font (&optional _frame)
  "Use the first installed hangul font for the hangul script."
  (when (display-graphic-p)
    (when-let* ((family (seq-find (lambda (f) (find-font (font-spec :family f)))
                                  '("Apple SD Gothic Neo" "D2Coding"
                                    "Noto Sans CJK KR" "NanumGothicCoding"
                                    "Malgun Gothic"))))
      (set-fontset-font t 'hangul (font-spec :family family)))))
(ecamp-korean-font)
(add-hook 'after-make-frame-functions #'ecamp-korean-font)

;;; 00-korean.el ends here
