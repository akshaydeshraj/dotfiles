(setq doom-theme 'doom-cobalt2)

(setq display-line-numbers-type t)

(add-to-list 'default-frame-alist '(fullscreen . maximized))
(doom/set-frame-opacity 90 t)
(set-face-attribute 'default nil :height 140)

(after! treemacs
  (treemacs-project-follow-mode +1))

(add-hook 'treemacs-mode-hook
          (lambda () (setq-local line-spacing 5)))

(setq org-directory "~/org/")

(defun my/add-straight-package-to-load-path (package)
  "Add PACKAGE's straight build directory to `load-path' when present."
  (let* ((straight-dir (or (bound-and-true-p straight-base-dir)
                           (expand-file-name "straight/" doom-local-dir)))
         (build-dir (expand-file-name
                     (format "build-%d.%d/%s"
                             emacs-major-version
                             emacs-minor-version
                             package)
                     straight-dir)))
    (when (file-directory-p build-dir)
      (add-to-list 'load-path build-dir))))

(dolist (package '("shell-maker" "acp" "agent-shell"))
  (my/add-straight-package-to-load-path package))

(setq after-load-alist
      (seq-remove
       (lambda (entry)
         (member (car-safe entry) '(agent-shell "agent-shell")))
       after-load-alist))

(after! agent-shell
  (require 'acp)
  (require 'agent-shell-anthropic)
  (require 'agent-shell-openai)

  (setq agent-shell-session-strategy 'prompt
        agent-shell-context-sources nil
        agent-shell-show-usage-at-turn-end t
        agent-shell-show-context-usage-indicator 'detailed
        agent-shell-show-welcome-message nil)

  ;; Let agent subprocesses see the same PATH/HOME/auth context as Emacs.
  (setq agent-shell-anthropic-claude-environment
        (agent-shell-make-environment-variables :inherit-env t)
        agent-shell-openai-codex-environment
        (agent-shell-make-environment-variables :inherit-env t))

  ;; Reuse the CLI login flows instead of duplicating API key config in Emacs.
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t)
        agent-shell-openai-authentication
        (agent-shell-openai-make-authentication :login t))

  (set-popup-rule! "^\\*agent-shell"
    :side 'right
    :size 0.45
    :ttl nil
    :select t))
