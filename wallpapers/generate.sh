#!/usr/bin/env bash
# Reproducible Tokyo Night Storm wallpaper generation.
# Palette source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh
#
# Usage: ./generate.sh [output-dir]
# Output: 3 4K (3840x2160) PNGs derived from the TN palette.
#
# Edit the palette in palette.sh, re-run this script — wallpapers regenerate.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$DOTFILES_DIR/themes/tokyo-night-storm/palette.sh"

OUT="${1:-$DOTFILES_DIR/wallpapers}"
mkdir -p "$OUT"

command -v magick >/dev/null || { echo "ImageMagick (magick) not installed"; exit 1; }

# 1. Vertical gradient with a soft central blue glow
magick -size 3840x2160 \
  gradient:"$TN_BG_DARK"-"$TN_BG" \
  -fill "$TN_BLUE" -stroke none -draw 'circle 1920,1080 1920,980' \
  -blur 0x80 \
  "$OUT/01_tokyo-night-storm-glow.png"

# 2. Diagonal gradient bg → border
magick -size 3840x2160 \
  -define gradient:angle=135 gradient:"$TN_BG"-"$TN_BORDER" \
  "$OUT/02_tokyo-night-storm-diagonal.png"

# 3. Three soft glowing orbs (blue / magenta / yellow) on bg
magick -size 3840x2160 xc:"$TN_BG" \
  -fill "$TN_BLUE"    -draw 'circle 800,600 800,300' \
  -fill "$TN_MAGENTA" -draw 'circle 2400,1500 2400,1200' \
  -fill "$TN_YELLOW"  -draw 'circle 3000,400 3000,250' \
  -blur 0x80 \
  "$OUT/03_tokyo-night-storm-orbs.png"

echo "Generated:"
ls -la "$OUT"/*.png
