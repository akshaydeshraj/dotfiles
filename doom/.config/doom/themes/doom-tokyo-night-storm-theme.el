;;; doom-tokyo-night-storm-theme.el --- Tokyo Night Storm -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; A Doom-themes port of folke/tokyonight.nvim (Storm variant).
;; Palette source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh
;;
;; Mirrors the structure of the archived doom-cobalt2-theme.el so face
;; customizations carry over identically — only the color slots change.

(require 'doom-themes)

(defgroup doom-tokyo-night-storm-theme nil
  "Options for the `doom-tokyo-night-storm' theme."
  :group 'doom-themes)

(defcustom doom-tokyo-night-storm-brighter-modeline nil
  "If non-nil, more vivid colors will be used to style the mode-line."
  :group 'doom-tokyo-night-storm-theme
  :type 'boolean)

(defcustom doom-tokyo-night-storm-brighter-comments nil
  "If non-nil, comments will be brighter."
  :group 'doom-tokyo-night-storm-theme
  :type 'boolean)

(defcustom doom-tokyo-night-storm-padded-modeline doom-themes-padded-modeline
  "If non-nil, adds extra padding to the mode-line."
  :group 'doom-tokyo-night-storm-theme
  :type '(choice integer boolean))

(def-doom-theme doom-tokyo-night-storm
  "Tokyo Night Storm — calmed-down navy with cool pastel accents."

  ;; name        default     256       16
  ((bg         '("#24283b" nil       nil))
   (bg-alt     '("#1f2335" nil       nil))
   (base0      '("#15161e" "black"   "black"))
   (base1      '("#1a1b26" "#1c1c1c" "brightblack"))
   (base2      '("#292e42" "#262626" "brightblack"))
   (base3      '("#3b4261" "#3a3a3a" "brightblack"))
   (base4      '("#414868" "#444444" "brightblack"))
   (base5      '("#565f89" "#585858" "brightblack"))
   (base6      '("#737aa2" "#626262" "brightblack"))
   (base7      '("#a9b1d6" "#9e9e9e" "brightblack"))
   (base8      '("#c0caf5" "#dfdfdf" "white"))
   (fg         '("#c0caf5" "#ffffff" "white"))
   (fg-alt     '("#a9b1d6" "#bcbcbc" "brightwhite"))

   (grey       base4)
   (red        '("#f7768e" "#ff5f87" "red"))
   (orange     '("#ff9e64" "#ff8700" "brightred"))
   (green      '("#9ece6a" "#5fd700" "green"))
   (teal       '("#73daca" "#5fffaf" "brightcyan"))
   (yellow     '("#e0af68" "#ffd700" "yellow"))
   (blue       '("#7aa2f7" "#0087ff" "brightblue"))
   (dark-blue  '("#3d59a1" "#005faf" "blue"))
   (magenta    '("#bb9af7" "#ff87ff" "magenta"))
   (violet     '("#9d7cd8" "#af87d7" "brightmagenta"))
   (cyan       '("#7dcfff" "#5fffff" "brightcyan"))
   (dark-cyan  '("#2ac3de" "#5faf87" "cyan"))

   ;; face categories — Tokyo Night-canonical assignments
   (highlight       blue)
   (vertical-bar    base4)
   (selection       '("#2e3c64" "#5f5f87" "blue"))
   (builtin         cyan)
   (comments        (if doom-tokyo-night-storm-brighter-comments base6 base5))
   (doc-comments    (doom-lighten (if doom-tokyo-night-storm-brighter-comments base6 base5) 0.25))
   (constants       orange)
   (functions       blue)
   (keywords        magenta)
   (methods         blue)
   (operators       cyan)
   (type            dark-cyan)
   (strings         green)
   (variables       fg)
   (numbers         orange)
   (region          selection)
   (error           red)
   (warning         yellow)
   (success         green)
   (vc-modified     yellow)
   (vc-added        green)
   (vc-deleted      red)

   ;; custom categories
   (-modeline-bright doom-tokyo-night-storm-brighter-modeline)
   (-modeline-pad
    (when doom-tokyo-night-storm-padded-modeline
      (if (integerp doom-tokyo-night-storm-padded-modeline) doom-tokyo-night-storm-padded-modeline 4)))

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
   (cursor :background fg)
   (fringe :background bg :foreground base4)
   ((tooltip &override) :background bg-alt :foreground fg)
   (mode-line
    :background modeline-bg :foreground modeline-fg
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg)))
   (mode-line-inactive
    :background modeline-bg-inactive :foreground modeline-fg-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-inactive)))
   (mode-line-emphasis :foreground (if -modeline-bright base8 blue))

   ;;;; doom-modeline
   (doom-modeline-bar :background blue)
   (doom-modeline-buffer-modified :foreground yellow)
   (doom-modeline-buffer-major-mode :foreground blue :weight 'bold)
   (doom-modeline-buffer-path :foreground cyan)
   (doom-modeline-buffer-file :foreground fg :weight 'bold)
   (doom-modeline-project-dir :foreground yellow :weight 'bold)
   (doom-modeline-info :foreground green)
   (doom-modeline-warning :foreground yellow)
   (doom-modeline-urgent :foreground red)

   ;;;; ivy / vertico / corfu / consult
   (vertico-current :background selection :foreground fg :extend t)
   (corfu-current :background selection :foreground fg)
   ((orderless-match-face-0 &override) :foreground yellow :weight 'bold)
   ((orderless-match-face-1 &override) :foreground magenta :weight 'bold)
   ((orderless-match-face-2 &override) :foreground green :weight 'bold)
   ((orderless-match-face-3 &override) :foreground cyan :weight 'bold)

   ;;;; magit
   (magit-section-heading :foreground blue :weight 'bold)
   (magit-branch-current :foreground yellow :weight 'bold :box t)
   (magit-branch-local :foreground blue)
   (magit-branch-remote :foreground green)
   (magit-tag :foreground orange)
   (magit-hash :foreground base6)
   (magit-diff-hunk-heading :background base2 :foreground fg-alt)
   (magit-diff-hunk-heading-highlight :background base3 :foreground fg)

   ;;;; org
   ((outline-1 &override) :foreground blue :weight 'bold)
   ((outline-2 &override) :foreground magenta)
   ((outline-3 &override) :foreground cyan)
   ((outline-4 &override) :foreground yellow)
   ((outline-5 &override) :foreground green)
   (org-block :background bg-alt :extend t)
   (org-block-begin-line :foreground base5 :background bg-alt :slant 'italic)
   (org-block-end-line :foreground base5 :background bg-alt :slant 'italic)
   (org-todo :foreground yellow :weight 'bold)
   (org-done :foreground green :weight 'bold)
   (org-headline-done :foreground base5 :strike-through t)
   (org-link :foreground cyan :underline t)
   (org-code :foreground green :background bg-alt)
   (org-verbatim :foreground green :background bg-alt)
   (org-quote :foreground fg-alt :slant 'italic)
   (org-table :foreground fg-alt :background bg-alt)

   ;;;; treemacs
   (treemacs-root-face :foreground blue :weight 'bold :height 1.1)
   (treemacs-directory-face :foreground blue)
   (treemacs-file-face :foreground fg)
   (treemacs-git-modified-face :foreground yellow)
   (treemacs-git-added-face :foreground green)
   (treemacs-git-untracked-face :foreground magenta)

   ;;;; vc-gutter / diff-hl
   ((diff-hl-change &override) :foreground yellow :background yellow)
   ((diff-hl-insert &override) :foreground green :background green)
   ((diff-hl-delete &override) :foreground red :background red)

   ;;;; flycheck / flymake
   (flycheck-error :underline `(:style wave :color ,red))
   (flycheck-warning :underline `(:style wave :color ,yellow))
   (flycheck-info :underline `(:style wave :color ,green))

   ;;;; rainbow-delimiters
   (rainbow-delimiters-depth-1-face :foreground blue)
   (rainbow-delimiters-depth-2-face :foreground magenta)
   (rainbow-delimiters-depth-3-face :foreground cyan)
   (rainbow-delimiters-depth-4-face :foreground yellow)
   (rainbow-delimiters-depth-5-face :foreground green)
   (rainbow-delimiters-depth-6-face :foreground orange)
   (rainbow-delimiters-unmatched-face :foreground red :weight 'bold)

   ;;;; misc
   (hl-line :background bg-alt :extend t)
   (highlight-quoted-symbol :foreground orange)
   (font-lock-comment-delimiter-face :foreground comments :slant 'italic)
   (font-lock-comment-face :foreground comments :slant 'italic)))

;;; doom-tokyo-night-storm-theme.el ends here
