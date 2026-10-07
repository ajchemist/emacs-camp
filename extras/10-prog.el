;;; 10-prog.el --- emacs-camp: parens and eval feedback in code buffers  -*- lexical-binding: t -*-

;; Loaded when "10-prog" is in `ecamp-extras'. Every prog-mode buffer plus
;; ielm (a comint buffer, not prog-mode):
;; - rainbow-delimiters colors nesting (init.el installs it, this turns it on);
;; - C-x C-e flashes the sexp it evaluated and C-M-x the defun, on the
;;   built-in pulse.el, as eval-sexp-fu did (10 x 0.03s ~ its 0.29s flash).
;; Matching parens need nothing here: show-paren-mode is on by default.

;; ielm input is fontified in a hidden emacs-lisp-mode buffer (ielm-fontify-input-enable),
;; so the mode goes there; on ielm-mode itself it colors nothing.
(use-package rainbow-delimiters
  :hook ((prog-mode ielm-indirect-setup) . rainbow-delimiters-mode))

(setopt pulse-iterations 10 pulse-delay 0.03)

(defun ecamp-eval-flash-last-sexp (&rest _)
  (pulse-momentary-highlight-region
   (save-excursion (backward-sexp) (point)) (point)))

(defun ecamp-eval-flash-defun (&rest _)
  (when-let* ((b (bounds-of-thing-at-point 'defun)))
    (pulse-momentary-highlight-region (car b) (cdr b))))

(advice-add 'eval-last-sexp :before #'ecamp-eval-flash-last-sexp)
(advice-add 'eval-defun :before #'ecamp-eval-flash-defun)

;;; 10-prog.el ends here
