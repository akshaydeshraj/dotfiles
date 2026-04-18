#!/bin/bash
# tmux-resurrect pre-save hook: snapshot the list of active worktrees
# so even if tmux resurrect loses a session, we can restore the worktree map.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/worktrees}"
OUT="$HOME/.tmux/resurrect/worktrees.txt"
mkdir -p "$(dirname "$OUT")"

{
  echo "# snapshot $(date -Iseconds)"
  zoxide query -l 2>/dev/null | while read -r d; do
    if [ -d "$d/.git" ] || [ -f "$d/.git" ]; then
      git -C "$d" worktree list --porcelain 2>/dev/null | awk -v r="$d" '
        /^worktree /{wt=$2}
        /^branch /{sub("refs/heads/","",$2); print r"\t"wt"\t"$2}
      '
    fi
  done
} > "$OUT"
