#!/bin/bash

if [ "$SELECTED" = "true" ]; then
  sketchybar --set "$NAME" \
    background.drawing=on \
    background.color=0xff89b4fa \
    icon.highlight=on
else
  sketchybar --set "$NAME" \
    background.drawing=off \
    icon.highlight=off
fi
