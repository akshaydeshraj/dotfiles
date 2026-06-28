#!/bin/bash
# Notify when Claude Code needs attention
# Called from: Notification hook

# Get tmux session this Claude is running in
SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "unknown")

# Get the currently visible tmux session (what the user is looking at)
ACTIVE_SESSION=$(tmux list-clients -F '#{client_session}' 2>/dev/null | head -1)

# Skip if user is in Ghostty AND looking at this session
FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null | tr '[:upper:]' '[:lower:]')

if [ "$FRONT_APP" = "ghostty" ] && [ "$SESSION" = "$ACTIVE_SESSION" ]; then
  exit 0
fi

# Mark this session as needing attention
mkdir -p /tmp/claude-notify
touch "/tmp/claude-notify/${SESSION}"

osascript - "$SESSION" <<'APPLESCRIPT'
on run argv
  set s to item 1 of argv
  display notification ("Waiting for your input in session: " & s) with title ("Claude Code - " & s) sound name "Funk"
end run
APPLESCRIPT
