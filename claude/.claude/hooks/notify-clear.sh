#!/bin/bash
# Clear Claude notification marker when Claude resumes work or the session ends.
# Called from: UserPromptSubmit, SessionEnd hooks.

set -euo pipefail

NOTIFY_DIR="$HOME/.cache/tmux-project-workspaces/notify"
LEGACY_NOTIFY_DIR="$HOME/.cache/claude-notify"
STATE_SCRIPT="$HOME/Code/personal/dotfiles/tmux/plugins/tmux-project-workspaces/scripts/agent-state.sh"
INPUT="$(cat)"
EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""' 2>/dev/null || true)"
SESSION="${TMUX_SESSION:-$(tmux display-message -p '#S' 2>/dev/null || echo "unknown")}"
SAFE_SESSION="$(printf '%s' "$SESSION" | tr '/:' '__')"

rm -f "$NOTIFY_DIR/$SAFE_SESSION"
rm -f "$LEGACY_NOTIFY_DIR/$SAFE_SESSION"

case "$EVENT" in
  UserPromptSubmit)
    [ -x "$STATE_SCRIPT" ] && "$STATE_SCRIPT" touch claude "$SESSION" >/dev/null 2>&1 || true
    ;;
  SessionEnd)
    [ -x "$STATE_SCRIPT" ] && "$STATE_SCRIPT" clear "$SESSION" >/dev/null 2>&1 || true
    ;;
esac

tmux refresh-client -S 2>/dev/null || true
