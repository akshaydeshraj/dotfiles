#!/bin/bash
# Detect drift between on-disk worktrees and tmux sessions.
# --interactive: show findings in an fzf list with delete/attach actions.
# (default):     stdout a summary (used by tmux start hook).

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/worktrees}"

orphan_worktrees() {
  [ -d "$WORKTREE_ROOT" ] || return
  find "$WORKTREE_ROOT" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | while read -r d; do
    rel="${d#$WORKTREE_ROOT/}"
    session="$rel"
    tmux has-session -t "$session" 2>/dev/null || echo "WT\t$session\t$d"
  done
}

orphan_sessions() {
  tmux list-sessions -F '#{session_name}' 2>/dev/null | awk '/\//' | while read -r s; do
    d="$WORKTREE_ROOT/$s"
    [ -d "$d" ] || echo "SESSION\t$s\t-"
  done
}

if [ "${1:-}" = "--interactive" ]; then
  sel=$({ orphan_worktrees; orphan_sessions; } | \
    fzf --reverse --ansi --delimiter=$'\t' --with-nth=1,2 \
        --prompt='  orphans  ' \
        --header='enter: adopt (attach/session)  ^d: delete  ^q: quit' \
        --bind 'ctrl-q:abort' \
        --color=bg+:#0050A4,fg+:#ffffff,hl:#ffc600,hl+:#ffc600,pointer:#ffc600,prompt:#0088ff \
        --expect=ctrl-d)
  [ -z "$sel" ] && exit 0
  keypress=$(printf '%s\n' "$sel" | sed -n '1p')
  row=$(printf   '%s\n' "$sel" | sed -n '2p')
  kind=$(printf  '%s\n' "$row" | awk -F'\t' '{print $1}')
  name=$(printf  '%s\n' "$row" | awk -F'\t' '{print $2}')
  path=$(printf  '%s\n' "$row" | awk -F'\t' '{print $3}')

  if [ "$keypress" = "ctrl-d" ]; then
    case "$kind" in
      WT)      rm -rf "$path"; tmux display-message "deleted dir $path" ;;
      SESSION) tmux kill-session -t "$name" && tmux display-message "killed $name" ;;
    esac
  else
    case "$kind" in
      WT)      exec "$HOME/.config/tmux/tree-switcher.sh" ;;
      SESSION) tmux switch-client -t "$name" ;;
    esac
  fi
  exit 0
fi

# Non-interactive: just list.
wt_orphans=$(orphan_worktrees | wc -l | tr -d ' ')
sess_orphans=$(orphan_sessions | wc -l | tr -d ' ')
if [ "$wt_orphans" -gt 0 ] || [ "$sess_orphans" -gt 0 ]; then
  printf 'worktree orphans: %s\nsession orphans: %s\n' "$wt_orphans" "$sess_orphans"
  orphan_worktrees
  orphan_sessions
fi
