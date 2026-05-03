#!/bin/bash
export PATH="/opt/homebrew/bin:$PATH"

CURRENT=$(tmux display-message -p '#S')

# Build session list with indicators:
#   ● = current session
#   🤖 = Claude waiting for input
session=$(tmux list-sessions -F '#S' 2>/dev/null | while read -r s; do
  marker=""
  [ "$s" = "$CURRENT" ] && marker="  ●"
  [ -f "/tmp/claude-notify/${s}" ] && marker="${marker}  🤖"
  echo "${s}${marker}"
done | \
  fzf --reverse --border=none --no-info \
  --print-query \
  --header='  Pick or create a session' \
  --color=bg+:#2e3c64,fg+:#c0caf5,hl:#e0af68,hl+:#e0af68,pointer:#e0af68,prompt:#7aa2f7 \
  | tail -1 | sed 's/  [●🤖].*$//')

if [ -n "$session" ]; then
  # Clear notification marker when switching to the session
  rm -f "/tmp/claude-notify/${session}"

  if tmux has-session -t "$session" 2>/dev/null; then
    tmux switch-client -t "$session"
  else
    tmux new-session -d -s "$session" && tmux switch-client -t "$session"
  fi
fi
