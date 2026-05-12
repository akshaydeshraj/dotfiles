#!/bin/bash
# Sketchybar space indicator — Tokyo Night Storm
# Palette source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh

if [ "$SELECTED" = "true" ]; then
  sketchybar --set "$NAME" \
    background.drawing=on \
    background.color=0xffe0af68 \
    icon.highlight=on
else
  sketchybar --set "$NAME" \
    background.drawing=off \
    icon.highlight=off
fi
