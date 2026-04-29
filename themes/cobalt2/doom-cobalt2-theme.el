;;; doom-cobalt2-theme.el --- Cobalt2 -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; A Doom-themes port of Wes Bos's Cobalt2.
;; Palette mirrors ~/Code/personal/dotfiles/COBALT2.md.

(require 'doom-themes)

(defgroup doom-cobalt2-theme nil
  "Options for the `doom-cobalt2' theme."
  :group 'doom-themes)

(defcustom doom-cobalt2-brighter-modeline nil
  "If non-nil, more vivid colors will be used to style the mode-line."
  :group 'doom-cobalt2-theme
  :type 'boolean)

(defcustom doom-cobalt2-brighter-comments nil
  "If non-nil, comments will be brighter."
  :group 'doom-cobalt2-theme
  :type 'boolean)

(defcustom doom-cobalt2-padded-modeline doom-themes-padded-modeline
  "If non-nil, adds extra padding to the mode-line."
  :group 'doom-cobalt2-theme
  :type '(choice integer boolean))

(def-doom-theme doom-cobalt2
  "A Cobalt2 theme — deep navy with gold accents."

  ;; name        default     256       16
  ((bg         '("#122738" nil       nil))
   (bg-alt     '("#0d1f2d" nil       nil))
   (base0      '("#091621" "black"   "black"))
   (base1      '("#122738" "#1c1c1c" "brightblack"))
   (base2      '("#193549" "#262626" "brightblack"))
   (base3      '("#1f405c" "#3a3a3a" "brightblack"))
   (base4      '("#0d3a58" "#444444" "brightblack"))
   (base5      '("#3e6b8a" "#585858" "brightblack"))
   (base6      '("#5a8aab" "#626262" "brightblack"))
   (base7      '("#9ec1d8" "#9e9e9e" "brightblack"))
   (base8      '("#dfedf6" "#dfdfdf" "white"))
   (fg         '("#ffffff" "#ffffff" "white"))
   (fg-alt     '("#9ec1d8" "#bcbcbc" "brightwhite"))

   (grey       base4)
   (red        '("#ff628c" "#ff5f87" "red"))
   (orange     '("#ff9d00" "#ff8700" "brightred"))
   (green      '("#3ad900" "#5fd700" "green"))
   (teal       '("#80fcff" "#5fffff" "brightcyan"))
   (yellow     '("#ffc600" "#ffd700" "yellow"))
   (blue       '("#0088ff" "#0087ff" "brightblue"))
   (dark-blue  '("#0050a4" "#005faf" "blue"))
   (magenta    '("#fb94ff" "#ff87ff" "magenta"))
   (violet     '("#c792ea" "#af87d7" "brightmagenta"))
   (cyan       '("#80fcff" "#5fffff" "brightcyan"))
   (dark-cyan  '("#5fb3b3" "#5faf87" "cyan"))

   ;; face categories
   (highlight       yellow)
   (vertical-bar    base4)
   (selection       dark-blue)
   (builtin         yellow)
   (comments        (if doom-cobalt2-brighter-comments base6 base5))
   (doc-comments    (doom-lighten (if doom-cobalt2-brighter-comments base6 base5) 0.25))
   (constants       orange)
   (functions       yellow)
   (keywords        orange)
   (methods         yellow)
   (operators       cyan)
   (type            magenta)
   (strings         green)
   (variables       fg)
   (numbers         orange)
   (region          dark-blue)
   (error           red)
   (warning         yellow)
   (success         green)
   (vc-modified     orange)
   (vc-added        green)
   (vc-deleted      red)

   ;; custom categories
   (-modeline-bright doom-cobalt2-brighter-modeline)
   (-modeline-pad
    (when doom-cobalt2-padded-modeline
      (if (integerp doom-cobalt2-padded-modeline) doom-cobalt2-padded-modeline 4)))

   (modeline-fg              fg)
   (modeline-fg-alt          base5)
   (modeline-bg
    (if -modeline-bright (doom-darken base2 0.15) base2))
   (modeline-bg-alt
    (if -modeline-bright (doom-darken base2 0.1) (doom-darken base1 0.05)))
   (modeline-bg-inactive     base1)
   (modeline-bg-inactive-alt (doom-darken base1 0.1)))

  ;;;; Base theme face overrides
  (((line-number &override) :foreground (doom-lighten base4 0.15))
   ((line-number-current-line &override) :foreground yellow :weight 'bold)
   (cursor :background yellow)
   (fringe :background bg :foreground base4)
   ((tooltip &override) :background bg-alt :foreground fg)
   (mode-line
    :background modeline-bg :foreground modeline-fg
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg)))
   (mode-line-inactive
    :background modeline-bg-inactive :foreground modeline-fg-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-inactive)))
   (mode-line-emphasis :foreground (if -modeline-bright base8 yellow))

   ;;;; doom-modeline
   (doom-modeline-bar :background yellow)
   (doom-modeline-buffer-modified :foreground orange)
   (doom-modeline-buffer-major-mode :foreground yellow :weight 'bold)
   (doom-modeline-buffer-path :foreground blue)
   (doom-modeline-buffer-file :foreground fg :weight 'bold)
   (doom-modeline-project-dir :foreground yellow :weight 'bold)
   (doom-modeline-info :foreground green)
   (doom-modeline-warning :foreground orange)
   (doom-modeline-urgent :foreground red)

   ;;;; ivy / vertico / corfu / consult
   (vertico-current :background dark-blue :foreground fg :extend t)
   (corfu-current :background dark-blue :foreground fg)
   ((orderless-match-face-0 &override) :foreground yellow :weight 'bold)
   ((orderless-match-face-1 &override) :foreground magenta :weight 'bold)
   ((orderless-match-face-2 &override) :foreground green :weight 'bold)
   ((orderless-match-face-3 &override) :foreground cyan :weight 'bold)

   ;;;; magit
   (magit-section-heading :foreground yellow :weight 'bold)
   (magit-branch-current :foreground yellow :weight 'bold :box t)
   (magit-branch-local :foreground blue)
   (magit-branch-remote :foreground green)
   (magit-tag :foreground orange)
   (magit-hash :foreground base6)
   (magit-diff-hunk-heading :background base2 :foreground fg-alt)
   (magit-diff-hunk-heading-highlight :background base3 :foreground fg)

   ;;;; org
   ((outline-1 &override) :foreground yellow :weight 'bold)
   ((outline-2 &override) :foreground orange)
   ((outline-3 &override) :foreground blue)
   ((outline-4 &override) :foreground magenta)
   ((outline-5 &override) :foreground cyan)
   (org-block :background bg-alt :extend t)
   (org-block-begin-line :foreground base5 :background bg-alt :slant 'italic)
   (org-block-end-line :foreground base5 :background bg-alt :slant 'italic)
   (org-todo :foreground yellow :weight 'bold)
   (org-done :foreground green :weight 'bold)
   (org-headline-done :foreground base5 :strike-through t)
   (org-link :foreground blue :underline t)
   (org-code :foreground orange :background bg-alt)
   (org-verbatim :foreground green :background bg-alt)
   (org-quote :foreground fg-alt :slant 'italic)
   (org-table :foreground fg-alt :background bg-alt)

   ;;;; treemacs
   (treemacs-root-face :foreground yellow :weight 'bold :height 1.1)
   (treemacs-directory-face :foreground blue)
   (treemacs-file-face :foreground fg)
   (treemacs-git-modified-face :foreground orange)
   (treemacs-git-added-face :foreground green)
   (treemacs-git-untracked-face :foreground magenta)

   ;;;; vc-gutter / diff-hl
   ((diff-hl-change &override) :foreground orange :background orange)
   ((diff-hl-insert &override) :foreground green :background green)
   ((diff-hl-delete &override) :foreground red :background red)

   ;;;; flycheck / flymake
   (flycheck-error :underline `(:style wave :color ,red))
   (flycheck-warning :underline `(:style wave :color ,orange))
   (flycheck-info :underline `(:style wave :color ,green))

   ;;;; rainbow-delimiters
   (rainbow-delimiters-depth-1-face :foreground yellow)
   (rainbow-delimiters-depth-2-face :foreground orange)
   (rainbow-delimiters-depth-3-face :foreground magenta)
   (rainbow-delimiters-depth-4-face :foreground blue)
   (rainbow-delimiters-depth-5-face :foreground cyan)
   (rainbow-delimiters-depth-6-face :foreground green)
   (rainbow-delimiters-unmatched-face :foreground red :weight 'bold)

   ;;;; misc
   (hl-line :background bg-alt :extend t)
   (highlight-quoted-symbol :foreground orange)
   (font-lock-comment-delimiter-face :foreground comments :slant 'italic)
   (font-lock-comment-face :foreground comments :slant 'italic)))

;;; doom-cobalt2-theme.el ends here
