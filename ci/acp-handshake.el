;;; acp-handshake.el --- agent-shell starts each real ACP agent  -*- lexical-binding: t -*-

;; emacs --batch --init-directory DIR -l ci/acp-handshake.el AGENT...
;; AGENT is claude, codex, pi or goose. For each, agent-shell's own config
;; starts the adapter it would start for a user (claude-agent-acp, codex-acp,
;; pi-acp, `goose acp`) and the run waits for the ACP initialize exchange to
;; complete. No account is needed: initialize comes before authentication.
;; Exits 0 when every agent initialized, else 1.

(require 'package)
(package-initialize)
(require 'agent-shell)

(setq default-directory (file-name-as-directory (make-temp-file "ecamp-acp" t)))

(defun acp-hs-config (agent)
  (pcase agent
    ("claude" (agent-shell-anthropic-make-claude-code-config))
    ("codex" (agent-shell-openai-make-codex-config))
    ("pi" (agent-shell-pi-make-agent-config))
    ("goose" (agent-shell-goose-make-agent-config))
    (_ (error "unknown agent %s" agent))))

(defun acp-hs-run (agent)
  (let* ((t0 (float-time))
         (deadline (+ t0 120))
         (buffer (agent-shell-start :config (acp-hs-config agent)))
         (ok (lambda () (with-current-buffer buffer (map-elt agent-shell--state :initialized)))))
    (while (and (not (funcall ok)) (buffer-live-p buffer) (< (float-time) deadline))
      (accept-process-output nil 0.2))
    (if (funcall ok)
        (progn (message "acp[%s]: initialized in %.2fs" agent (- (float-time) t0)) t)
      (message "acp[%s]: FAILED to initialize\n--- buffer ---\n%s" agent
               (with-current-buffer buffer (buffer-substring-no-properties (point-min) (point-max))))
      nil)))

(let ((failed (seq-remove #'acp-hs-run command-line-args-left)))
  (setq command-line-args-left nil)
  (kill-emacs (if failed 1 0)))
