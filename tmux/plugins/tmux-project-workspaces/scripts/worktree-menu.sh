#!/usr/bin/env bash
# prefix+w menu. Acts on the current tmux session's worktree.

set -euo pipefail

# ── Tokyo Night Storm palette ─────────────────────────────────────
# Source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh
PALETTE_SH="$HOME/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh"
# shellcheck source=/dev/null
[ -f "$PALETTE_SH" ] && source "$PALETTE_SH"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION=$(tmux display-message -p '#S')
WT_PATH=$(tmux display-message -p '#{pane_current_path}')

ACTION=$(printf '%s\n' \
  " new worktree…" \
  "󰆴 remove this worktree" \
  " sync from main (fetch + rebase)" \
  " open PR (push + gh pr create)" \
  " view PR in browser" \
  " mark agent waiting / done" \
  " prune orphans" \
  "󰜺 kill this session only" \
  | fzf --reverse --prompt='  worktree  ' \
        --color="$(tn_fzf_colors)")

case "$ACTION" in
  *"new worktree"*)
    exec "$SCRIPT_DIR/tree-switcher.sh"
    ;;
  *"remove this worktree"*)
    "$SCRIPT_DIR/worktree-remove.sh" "$SESSION"
    ;;
  *"sync from main"*)
    tmux split-window -v -c "$WT_PATH" \
      "git fetch origin main && git rebase origin/main; echo; read -rp 'press enter to close...' _"
    ;;
  *"open PR"*)
    tmux split-window -v -c "$WT_PATH" \
      "git push -u origin HEAD && gh pr create --fill | tee /tmp/pr-url-$$; url=\$(tail -1 /tmp/pr-url-$$); tmux set-environment -t '$SESSION' PR_URL \"\$url\"; rm -f /tmp/pr-url-$$; read -rp 'press enter to close...' _"
    ;;
  *"view PR"*)
    ( cd "$WT_PATH" && gh pr view --web ) 2>/dev/null
    ;;
  *"mark agent"*)
    exec "$SCRIPT_DIR/agent-menu.sh"
    ;;
  *"prune orphans"*)
    tmux display-popup -E -w 80% -h 70% -b rounded -S "fg=${TN_YELLOW}" -T " Orphans " \
      "$SCRIPT_DIR/prune-orphans.sh --interactive"
    ;;
  *"kill this session"*)
    tmux kill-session -t "$SESSION"
    ;;
esac
