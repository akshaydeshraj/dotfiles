#!/bin/bash
# Sketchybar tailscale — Tokyo Night Storm (up=green, down=red)
# Palette source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh

if tailscale status >/dev/null 2>&1; then
  sketchybar --set "$NAME" icon="󰒒" icon.color=0xff9ece6a label="up"
else
  sketchybar --set "$NAME" icon="󰒎" icon.color=0xfff7768e label="down"
fi
