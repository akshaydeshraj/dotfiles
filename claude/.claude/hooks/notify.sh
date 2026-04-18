#!/bin/bash
# Notify when Claude Code needs attention.
# Called from: Notification, Stop hooks.

NOTIFY_DIR="$HOME/.cache/claude-notify"
mkdir -p "$NOTIFY_DIR"

SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "unknown")
ACTIVE_SESSION=$(tmux list-clients -F '#{client_session}' 2>/dev/null | head -1)

FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null | tr '[:upper:]' '[:lower:]')

# If the user is already staring at this session in Ghostty, skip the nudge.
if [ "$FRONT_APP" = "ghostty" ] && [ "$SESSION" = "$ACTIVE_SESSION" ]; then
  exit 0
fi

touch "$NOTIFY_DIR/$SESSION"

# Maintain aggregate count for statusline.
count=$(find "$NOTIFY_DIR" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
  printf '🤖 %s ' "$count" > "$NOTIFY_DIR/.count"
else
  : > "$NOTIFY_DIR/.count"
fi

# Refresh tmux statusline so the user sees it immediately.
tmux refresh-client -S 2>/dev/null || true

osascript -e "display notification \"Waiting for your input in session: ${SESSION}\" with title \"Claude Code — ${SESSION}\" sound name \"Funk\"" 2>/dev/null || true
