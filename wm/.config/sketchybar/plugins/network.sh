#!/bin/bash
IFACE=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
[ -z "$IFACE" ] && IFACE="en0"

STATS_FILE="/tmp/sketchybar-net-${IFACE}"

RX_NOW=$(netstat -ibn | awk -v iface="$IFACE" '$1==iface && $3 ~ /\./{print $7; exit}')
TX_NOW=$(netstat -ibn | awk -v iface="$IFACE" '$1==iface && $3 ~ /\./{print $10; exit}')
NOW=$(date +%s)

if [ -f "$STATS_FILE" ]; then
  read -r RX_PREV TX_PREV PREV_TIME < "$STATS_FILE"
  ELAPSED=$((NOW - PREV_TIME))
  [ "$ELAPSED" -lt 1 ] && ELAPSED=1

  DL=$(( (RX_NOW - RX_PREV) / ELAPSED ))
  UL=$(( (TX_NOW - TX_PREV) / ELAPSED ))

  fmt() {
    local bytes=$1
    if [ "$bytes" -ge 1048576 ]; then
      printf "%.1fM/s" "$(echo "$bytes / 1048576" | bc -l)"
    elif [ "$bytes" -ge 1024 ]; then
      printf "%.0fK/s" "$(echo "$bytes / 1024" | bc -l)"
    else
      printf "0K/s"
    fi
  }

  sketchybar --set net_down label="$(fmt $DL)" \
             --set net_up label="$(fmt $UL)"
else
  sketchybar --set net_down label="--" \
             --set net_up label="--"
fi

echo "$RX_NOW $TX_NOW $NOW" > "$STATS_FILE"
