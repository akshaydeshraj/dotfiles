#!/bin/bash
DISK=$(df -h /System/Volumes/Data | awk 'NR==2 {gsub(/%/,""); print $5"%"}')
sketchybar --set "$NAME" label="$DISK"
