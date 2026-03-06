#!/bin/bash

if tailscale status >/dev/null 2>&1; then
  sketchybar --set "$NAME" icon="󰒒" icon.color=0xffa6e3a1 label="up"
else
  sketchybar --set "$NAME" icon="󰒎" icon.color=0xfff38ba8 label="down"
fi
