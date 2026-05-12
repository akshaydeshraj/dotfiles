#!/bin/bash
# Sketchybar battery — Tokyo Night Storm (charging/high=green, mid=yellow,
# low=orange, critical=red, drained-text=fg). Levels >80, >60, >40, >20.
# Palette source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh

PERCENTAGE="$(pmset -g batt | command grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | command grep 'AC Power')"

if [ -n "$CHARGING" ]; then
  ICON="󰂄"
  COLOR="0xff9ece6a"
elif [ "$PERCENTAGE" -gt 80 ]; then
  ICON="󰁹"
  COLOR="0xff9ece6a"
elif [ "$PERCENTAGE" -gt 60 ]; then
  ICON="󰂁"
  COLOR="0xffc0caf5"
elif [ "$PERCENTAGE" -gt 40 ]; then
  ICON="󰁿"
  COLOR="0xffe0af68"
elif [ "$PERCENTAGE" -gt 20 ]; then
  ICON="󰁽"
  COLOR="0xffff9e64"
else
  ICON="󰂃"
  COLOR="0xfff7768e"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="${PERCENTAGE}%"
