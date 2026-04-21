#!/usr/bin/env bash
# Schedule a confirm-before prompt for worktree removal on the given tmux client.
# Called via `tmux run-shell -b` so it runs on the tmux server, detached from any
# popup that may be closing around the caller.
#
# Usage: confirm-delete.sh <session> <client-tty>

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION="${1:-}"
CLIENT="${2:-}"
[ -z "$SESSION" ] && exit 1

REMOVE="$SCRIPT_DIR/worktree-remove.sh"
if [ -z "$CLIENT" ]; then
  CLIENT="$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)"
fi
if [ -z "$CLIENT" ]; then
  CLIENT="$(tmux list-clients -F '#{client_tty}' 2>/dev/null | head -1)"
fi

printf -v ACTION 'run-shell "%s --no-confirm %q >/dev/null 2>&1"' "$REMOVE" "$SESSION"
if [ -n "$CLIENT" ]; then
  tmux confirm-before -t "$CLIENT" -p "remove $SESSION? (y/n)" "$ACTION"
else
  tmux confirm-before -p "remove $SESSION? (y/n)" "$ACTION"
fi
