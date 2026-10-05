;;; agent-shell-e2e.el --- drive agent-shell end to end in batch  -*- lexical-binding: t -*-

;; emacs --batch --init-directory DIR -l ci/agent-shell-e2e.el
;; ECAMP_E2E_AGENT=mock (default): ci/mock-acp-agent.py, no network, no keys.
;; ECAMP_E2E_AGENT=claude: the real Claude Code ACP adapter (claude-agent-acp
;; on PATH, ANTHROPIC_API_KEY in the environment).
;; Starts a session over a real subprocess, sends a prompt, waits for the
;; expected text in the shell buffer. Exit 0 on success, 1 otherwise.

(require 'package)
(package-initialize)
(require 'agent-shell)

(defvar e2e-dir (file-name-directory (or load-file-name buffer-file-name)))
(defvar e2e-agent (or (getenv "ECAMP_E2E_AGENT") "mock"))
(defvar e2e-timeout (if (equal e2e-agent "mock") 30 180))
;; Session transcripts land under default-directory; keep them out of the checkout.
(setq default-directory (file-name-as-directory (make-temp-file "ecamp-e2e" t)))

(defun e2e-wait (pred what)
  (let ((deadline (+ (float-time) e2e-timeout)))
    (while (and (not (funcall pred)) (< (float-time) deadline))
      (accept-process-output nil 0.2))
    (unless (funcall pred) (error "timeout waiting for %s" what))))

(defun e2e-config ()
  (pcase e2e-agent
    ("mock"
     (agent-shell-make-agent-config
      :identifier 'mock :mode-line-name "Mock" :buffer-name "Mock"
      :shell-prompt "Mock> " :shell-prompt-regexp "Mock> "
      :client-maker (lambda (buffer)
                      (agent-shell--make-acp-client
                       :command (or (executable-find "python3") (executable-find "python"))
                       :command-params (list (expand-file-name "mock-acp-agent.py" e2e-dir))
                       :context-buffer buffer))))
    ("claude"
     (setq agent-shell-anthropic-authentication
           (agent-shell-anthropic-make-authentication :api-key (getenv "ANTHROPIC_API_KEY")))
     (agent-shell-anthropic-make-claude-code-config))
    (_ (error "unknown ECAMP_E2E_AGENT %s" e2e-agent))))

(let* ((prompt (if (equal e2e-agent "mock") "hello from ci"
                 "Reply with exactly the word PONG and nothing else."))
       (expect (if (equal e2e-agent "mock") "PONG: hello from ci" "PONG"))
       (t0 (float-time))
       (buffer (agent-shell-start :config (e2e-config))))
  (condition-case err
      (let (ready)
        (with-current-buffer buffer
          (e2e-wait (lambda () (map-nested-elt agent-shell--state '(:session :id))) "session"))
        (setq ready (float-time))
        (message "e2e[%s]: session ready %.2fs" e2e-agent (- ready t0))
        (agent-shell-insert :text prompt :submit t :no-focus t :shell-buffer buffer)
        (with-current-buffer buffer
          (e2e-wait (lambda ()
                      (save-excursion
                        (goto-char (point-min))
                        ;; the reply, not the echoed prompt
                        (and (search-forward prompt nil t) (search-forward expect nil t))))
                    "reply"))
        (message "e2e[%s]: reply %.2fs after prompt, %.2fs total"
                 e2e-agent (- (float-time) ready) (- (float-time) t0))
        (kill-emacs 0))
    (error
     (message "e2e[%s]: FAILED: %S\n--- buffer ---\n%s" e2e-agent err
              (with-current-buffer buffer (buffer-substring-no-properties (point-min) (point-max))))
     (kill-emacs 1))))
