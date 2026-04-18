#!/bin/bash
# Send the same prompt to every agent pane across all sessions.
# Convention: "agent pane" = pane #0 of window "work".
# Bound to prefix+A. Opens a tmux command-prompt, then resends via --send.

if [ "${1:-}" = "--send" ]; then
  msg="$2"
  [ -z "$msg" ] && exit 0
  tmux list-sessions -F '#{session_name}' 2>/dev/null | while read -r s; do
    tmux list-windows -t "$s" -F '#{window_name} #{window_index}' 2>/dev/null \
      | awk '$1=="work"{print $2}' | while read -r win; do
        tmux send-keys -t "$s:$win.0" "$msg" Enter 2>/dev/null || true
    done
  done
  exit 0
fi

tmux command-prompt -p 'broadcast to all agents:' \
  "run-shell \"$0 --send '%1'\""
