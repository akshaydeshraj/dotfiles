(setq doom-theme 'doom-cobalt2)

(setq display-line-numbers-type t)

(add-to-list 'default-frame-alist '(fullscreen . maximized))
(doom/set-frame-opacity 90 t)
(set-face-attribute 'default nil :height 140)

(defun my/ensure-treemacs-visible ()
  "Open treemacs unless it is already visible."
  (when (display-graphic-p)
    (require 'treemacs)
    (unless (eq (treemacs-current-visibility) 'visible)
      (save-selected-window (treemacs)))))

(add-hook 'doom-first-file-hook #'my/ensure-treemacs-visible)
(add-hook 'doom-after-reload-hook #'my/ensure-treemacs-visible)

(after! treemacs
  (treemacs-project-follow-mode +1))

(setq org-directory "~/org/")
