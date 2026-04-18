#!/bin/bash
# Remove a worktree + its tmux session + its branch.
# Usage: worktree-remove.sh [--no-confirm] <session>   (e.g. "devspec/feat-login")
#
# Without --no-confirm, dispatches an async tmux confirm-before prompt to the
# outer client (so it survives popup closure), then re-invokes with --no-confirm.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

LOG=/tmp/wt-remove.log
echo "[$(date '+%H:%M:%S')] invoked: argv=[$*] pwd=$PWD tmux=${TMUX:-unset} outer=${OUTER_CLIENT:-unset}" >> "$LOG"

NO_CONFIRM=false
if [ "$1" = "--no-confirm" ]; then
  NO_CONFIRM=true
  shift
fi

SESSION="${1:-}"
[ -z "$SESSION" ] && { echo "usage: $0 [--no-confirm] <session>"; exit 1; }
[[ "$SESSION" != */* ]] && { echo "bad session name: $SESSION"; exit 1; }

if ! $NO_CONFIRM; then
  CLIENT="${OUTER_CLIENT:-$(tmux list-clients -F '#{client_tty}' 2>/dev/null | head -1)}"
  SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  ACTION="run-shell \"$SELF --no-confirm $SESSION\""
  echo "[$(date '+%H:%M:%S')] dispatching confirm: client=$CLIENT self=$SELF action=$ACTION" >> "$LOG"
  # confirm-before is async; action runs only on 'y'.
  tmux confirm-before ${CLIENT:+-t "$CLIENT"} -p "remove $SESSION? (y/n)" "$ACTION"
  rc=$?
  echo "[$(date '+%H:%M:%S')] confirm-before dispatch rc=$rc" >> "$LOG"
  exit 0
fi

# --- actual removal ---
REPO_NAME="${SESSION%%/*}"
BRANCH="${SESSION#*/}"
WT_PATH="${WORKTREE_ROOT:-$HOME/worktrees}/$REPO_NAME/$BRANCH"

REPO=$(zoxide query -l 2>/dev/null | while read -r d; do
  if [ "$(basename "$d")" = "$REPO_NAME" ] && { [ -d "$d/.git" ] || [ -f "$d/.git" ]; }; then
    echo "$d"; break
  fi
done)

tmux kill-session -t "$SESSION" 2>/dev/null || true

if [ -n "$REPO" ]; then
  git -C "$REPO" worktree remove --force "$WT_PATH" 2>/dev/null \
    || git -C "$REPO" worktree remove --force "$BRANCH" 2>/dev/null \
    || true
fi

[ -d "$WT_PATH" ] && rm -rf "$WT_PATH"

# User already confirmed removing the whole worktree; force-delete the branch too.
if [ -n "$REPO" ]; then
  git -C "$REPO" branch -d "$BRANCH" 2>/dev/null \
    || git -C "$REPO" branch -D "$BRANCH" 2>/dev/null \
    || true
fi

NOTIFY="$HOME/.cache/claude-notify"
rm -f "$NOTIFY/$SESSION"
count=$(find "$NOTIFY" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
  printf '🤖 %s ' "$count" > "$NOTIFY/.count"
else
  : > "$NOTIFY/.count"
fi
tmux refresh-client -S 2>/dev/null || true
tmux display-message "removed $SESSION"
