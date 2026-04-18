#!/bin/bash
# Clear notification marker when Claude resumes work or session ends.
# Called from: UserPromptSubmit, SessionEnd hooks.

NOTIFY_DIR="$HOME/.cache/claude-notify"
SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "unknown")

rm -f "$NOTIFY_DIR/$SESSION"

count=$(find "$NOTIFY_DIR" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
  printf '🤖 %s ' "$count" > "$NOTIFY_DIR/.count"
else
  : > "$NOTIFY_DIR/.count"
fi

tmux refresh-client -S 2>/dev/null || true
