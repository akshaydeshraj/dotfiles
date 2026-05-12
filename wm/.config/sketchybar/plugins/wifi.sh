#!/bin/bash
# Sketchybar wifi — Tokyo Night Storm (offline=red, online=yellow)
# Palette source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh

SSID="$(ipconfig getsummary en0 2>/dev/null | command grep '  SSID : ' | command sed 's/.*SSID : //')"

if [ -z "$SSID" ]; then
  sketchybar --set "$NAME" icon="󰖪" icon.color=0xfff7768e label="offline"
else
  sketchybar --set "$NAME" icon="󰖩" icon.color=0xffe0af68 label="$SSID"
fi
