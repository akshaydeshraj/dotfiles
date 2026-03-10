#!/bin/bash
USED=$(vm_stat | awk '/Pages active/{a=$3}/Pages wired/{w=$4}END{gsub(/\./,"",a);gsub(/\./,"",w);print (a+w)*16384}')
TOTAL=$(sysctl -n hw.memsize)
MEM=$((USED * 100 / TOTAL))
sketchybar --set "$NAME" label="${MEM}%"
