# Tokyo Night Storm — single source of truth palette
# Source: https://github.com/folke/tokyonight.nvim (Storm variant)
# Derived from ~/Downloads/tokyo-night-storm (Ghostty palette dump)
#
# Sourced by:
#   - zsh/.zshrc                (FZF, autosuggest, syntax highlight)
#   - tmux plugin scripts       (fzf colors, popup borders)
#
# App-side configs that hardcode these hex values (cannot import shell vars):
#   - doom/.config/doom/config.el      (uses built-in doom-tokyo-night theme)
#   - atuin/.config/atuin/themes/tokyo-night-storm.toml
#   - prompt/.config/starship.toml      (via starship's [palettes] directive)
#   - ghostty/.config/ghostty/config
#   - tmux/.tmux.conf
#   - btop/.config/btop/themes/tokyo-night-storm.theme
#   - wm/.config/sketchybar/sketchybarrc + plugins
#   - wm/.config/borders/bordersrc
#   - wm/.yabairc
#   - zed/.config/zed/settings.json (theme name only)
#   - nvim/.config/nvim/init.lua (colorscheme name only — folke/tokyonight.nvim)
#
# When tweaking colors, edit this file first, then propagate.

# ── Hex (#RRGGBB form, for shell tools) ─────────────────────────
export TN_BG="#24283b"
export TN_BG_DARK="#1f2335"
export TN_BG_HIGHLIGHT="#292e42"
export TN_FG="#c0caf5"
export TN_FG_DARK="#a9b1d6"
export TN_SELECTION_BG="#2e3c64"
export TN_BORDER="#414868"            # also br-black
export TN_COMMENT="#565f89"

export TN_BLACK="#1d202f"
export TN_RED="#f7768e"
export TN_GREEN="#9ece6a"
export TN_YELLOW="#e0af68"
export TN_BLUE="#7aa2f7"
export TN_MAGENTA="#bb9af7"
export TN_CYAN="#7dcfff"
export TN_WHITE="#a9b1d6"
export TN_BR_BLACK="#414868"

export TN_ORANGE="#ff9e64"            # extra accent (TN canonical)

# Semantic accents (mirrors the cobalt2 role names this replaces)
export TN_ACCENT="$TN_YELLOW"         # was cobalt2 gold
export TN_ACCENT_ALT="$TN_BLUE"       # secondary accent
export TN_CURSOR="$TN_FG"
export TN_DIM="$TN_BR_BLACK"          # was cobalt2 dim blue (autosuggest, comments)

# ── 0xAARRGGBB form (sketchybar / borders) ──────────────────────
export TN_BG_ARGB="0xff24283b"
export TN_FG_ARGB="0xffc0caf5"
export TN_SELECTION_BG_ARGB="0xff2e3c64"
export TN_BORDER_ARGB="0xff414868"

export TN_BLACK_ARGB="0xff1d202f"
export TN_RED_ARGB="0xfff7768e"
export TN_GREEN_ARGB="0xff9ece6a"
export TN_YELLOW_ARGB="0xffe0af68"
export TN_BLUE_ARGB="0xff7aa2f7"
export TN_MAGENTA_ARGB="0xffbb9af7"
export TN_CYAN_ARGB="0xff7dcfff"
export TN_WHITE_ARGB="0xffa9b1d6"
export TN_BR_BLACK_ARGB="0xff414868"
export TN_ORANGE_ARGB="0xffff9e64"

export TN_ACCENT_ARGB="$TN_YELLOW_ARGB"
export TN_ACCENT_ALT_ARGB="$TN_BLUE_ARGB"

# ── Helper: emit fzf --color string from current palette ────────
# Usage:  --color="$(tn_fzf_colors)"
tn_fzf_colors() {
  cat <<EOF
bg+:${TN_SELECTION_BG},bg:${TN_BG},fg:${TN_FG},fg+:${TN_FG},hl:${TN_YELLOW},hl+:${TN_YELLOW},info:${TN_CYAN},marker:${TN_GREEN},prompt:${TN_BLUE},spinner:${TN_MAGENTA},pointer:${TN_RED},header:${TN_BLUE},border:${TN_BORDER},separator:${TN_BORDER},scrollbar:${TN_BORDER},label:${TN_CYAN},query:${TN_FG}
EOF
}

# ── Helper: convert #RRGGBB → "R;G;B" (truecolor ANSI fragment) ─
_tn_rgb() {
  local h="${1#\#}"
  printf '%d;%d;%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# ── Helper: emit EZA_COLORS string for eza ──────────────────────
# Usage:  export EZA_COLORS="$(tn_eza_colors)"
# Uses 24-bit truecolor (38;2;R;G;B) so colors are theme-canonical
# rather than dependent on the terminal's 8/16-color palette mapping.
tn_eza_colors() {
  local fg="38;2;$(_tn_rgb "$TN_FG")"
  local fg_dark="38;2;$(_tn_rgb "$TN_FG_DARK")"
  local blue="38;2;$(_tn_rgb "$TN_BLUE")"
  local green="38;2;$(_tn_rgb "$TN_GREEN")"
  local yellow="38;2;$(_tn_rgb "$TN_YELLOW")"
  local red="38;2;$(_tn_rgb "$TN_RED")"
  local magenta="38;2;$(_tn_rgb "$TN_MAGENTA")"
  local cyan="38;2;$(_tn_rgb "$TN_CYAN")"
  local orange="38;2;$(_tn_rgb "$TN_ORANGE")"
  local dim="38;2;$(_tn_rgb "$TN_BORDER")"

  # File classes
  local out="di=${blue};1"     # directory (blue bold)
  out="${out}:ex=${green};1"   # executable (green bold)
  out="${out}:fi=${fg}"        # regular file
  out="${out}:ln=${magenta}"   # symlink
  out="${out}:or=${red};1"     # orphan symlink

  # Permissions
  out="${out}:ur=${yellow}"    # user read
  out="${out}:uw=${red}"       # user write
  out="${out}:ux=${green};1"   # user execute (bold)
  out="${out}:ue=${green};1"   # user execute on file
  out="${out}:gr=${cyan}"      # group read
  out="${out}:gw=${magenta}"   # group write
  out="${out}:gx=${magenta}"   # group execute
  out="${out}:tr=${cyan}"      # other read
  out="${out}:tw=${cyan}"      # other write
  out="${out}:tx=${cyan}"      # other execute
  out="${out}:xa=${orange}"    # extended attribute marker
  out="${out}:xx=${dim}"       # punctuation / no-perm dash

  # Ownership
  out="${out}:uu=${magenta}"   # your username
  out="${out}:un=${fg_dark}"   # other usernames
  out="${out}:gu=${cyan}"      # your group
  out="${out}:gn=${dim}"       # other groups

  # Sizes / dates
  out="${out}:sn=${yellow}"    # size number
  out="${out}:sb=${orange}"    # size base (B/K/M/G)
  out="${out}:nb=${fg}"        # bytes
  out="${out}:nk=${yellow}"    # KiB
  out="${out}:nm=${orange}"    # MiB
  out="${out}:ng=${red}"       # GiB
  out="${out}:nt=${red};1"     # TiB
  out="${out}:da=${cyan}"      # date

  # Git status
  out="${out}:ga=${green}"     # added
  out="${out}:gm=${yellow}"    # modified
  out="${out}:gd=${red}"       # deleted
  out="${out}:gv=${magenta}"   # renamed
  out="${out}:gt=${cyan}"      # type-changed
  out="${out}:gi=${dim}"       # ignored
  out="${out}:gc=${orange};1"  # conflicted (bold)

  printf '%s' "$out"
}
