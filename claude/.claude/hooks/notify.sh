#!/bin/bash
# Claude Code hook: update tmux-visible attention + agent state.
# Called from: Notification, Stop, SessionStart hooks.

set -euo pipefail

NOTIFY_DIR="$HOME/.cache/tmux-project-workspaces/notify"
LEGACY_NOTIFY_DIR="$HOME/.cache/claude-notify"
STATE_SCRIPT="$HOME/Code/personal/dotfiles/tmux/plugins/tmux-project-workspaces/scripts/agent-state.sh"
mkdir -p "$NOTIFY_DIR"
mkdir -p "$LEGACY_NOTIFY_DIR"

INPUT="$(cat)"
EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""' 2>/dev/null || true)"
MESSAGE="$(printf '%s' "$INPUT" | jq -r '.message // .notification // ""' 2>/dev/null || true)"
SESSION="${TMUX_SESSION:-$(tmux display-message -p '#S' 2>/dev/null || echo "unknown")}"
SAFE_SESSION="$(printf '%s' "$SESSION" | tr '/:' '__')"
ACTIVE_SESSION="$(tmux list-clients -F '#{client_session}' 2>/dev/null | head -1)"
FRONT_APP="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null | tr '[:upper:]' '[:lower:]')"

update_count() {
  :
}

case "$EVENT" in
  SessionStart)
    [ -x "$STATE_SCRIPT" ] && "$STATE_SCRIPT" touch claude "$SESSION" >/dev/null 2>&1 || true
    tmux refresh-client -S 2>/dev/null || true
    exit 0
    ;;
  Stop)
    [ -x "$STATE_SCRIPT" ] && "$STATE_SCRIPT" set "done" claude "$SESSION" >/dev/null 2>&1 || true
    tmux refresh-client -S 2>/dev/null || true
    exit 0
    ;;
  Notification)
    ;;
  *)
    exit 0
    ;;
esac

# Notification events are the documented signal for "waiting for input" and permission requests.
touch "$NOTIFY_DIR/$SAFE_SESSION"
touch "$LEGACY_NOTIFY_DIR/$SAFE_SESSION"
update_count
[ -x "$STATE_SCRIPT" ] && "$STATE_SCRIPT" set wait claude "$SESSION" >/dev/null 2>&1 || true
tmux refresh-client -S 2>/dev/null || true

# If the user is already staring at this session in Ghostty, skip the OS nudge.
if [ "$FRONT_APP" = "ghostty" ] && [ "$SESSION" = "$ACTIVE_SESSION" ]; then
  exit 0
fi

TEXT="Claude needs attention in session: ${SESSION}"
if printf '%s' "$MESSAGE" | grep -qi 'waiting for your input'; then
  TEXT="Claude is waiting for your input in session: ${SESSION}"
elif printf '%s' "$MESSAGE" | grep -qi 'permission'; then
  TEXT="Claude needs permission in session: ${SESSION}"
fi

osascript -e "display notification \"$TEXT\" with title \"Claude Code — ${SESSION}\" sound name \"Funk\"" 2>/dev/null || true
