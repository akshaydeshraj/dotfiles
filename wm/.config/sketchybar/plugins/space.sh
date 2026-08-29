#!/bin/bash
# Sketchybar space indicator — Tokyo Night Storm
# Palette source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh

WORKSPACE="$1"
FOCUSED_WORKSPACE="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

if [ "$WORKSPACE" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" \
    background.drawing=on \
    background.color=0xffe0af68 \
    icon.highlight=on
else
  sketchybar --set "$NAME" \
    background.drawing=off \
    icon.highlight=off
fi
