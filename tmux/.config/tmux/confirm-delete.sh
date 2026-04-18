#!/bin/bash
# Schedule a confirm-before prompt for worktree removal on the given tmux client.
# Called via `tmux run-shell -b` so it runs on the tmux server, detached from any
# popup that may be closing around the caller.
#
# Usage: confirm-delete.sh <session> <client-tty>

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SESSION="$1"
CLIENT="$2"
[ -z "$SESSION" ] && exit 1

REMOVE="$HOME/.config/tmux/worktree-remove.sh"

ACTION="run-shell \"$REMOVE --no-confirm '$SESSION' >/dev/null 2>&1\""
if [ -n "$CLIENT" ]; then
  tmux confirm-before -t "$CLIENT" -p "remove $SESSION? (y/n)" "$ACTION"
else
  tmux confirm-before -p "remove $SESSION? (y/n)" "$ACTION"
fi
