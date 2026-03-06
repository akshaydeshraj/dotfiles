#!/bin/bash

SSID="$(ipconfig getsummary en0 2>/dev/null | command grep '  SSID : ' | command sed 's/.*SSID : //')"

if [ -z "$SSID" ]; then
  sketchybar --set "$NAME" icon="󰖪" icon.color=0xfff38ba8 label="offline"
else
  sketchybar --set "$NAME" icon="󰖩" icon.color=0xfff9e2af label="$SSID"
fi
