#!/bin/bash
# Toggle yazi in a temporary window

YAZI_WIN=$(tmux list-windows -F '#{window_name} #{window_id}' | awk '/yazi/{print $2}')

if [ -n "$YAZI_WIN" ]; then
  tmux kill-window -t "$YAZI_WIN"
else
  PANE_PATH=$(tmux display-message -p '#{pane_current_path}')
  tmux new-window -n yazi -c "$PANE_PATH" "yazi"
fi
