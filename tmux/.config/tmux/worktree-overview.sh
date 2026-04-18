#!/bin/bash
# Full-screen dashboard of every worktree/session with state.
# Bound to Cmd+Shift+K (M-K) and prefix+Tab.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

NOTIFY="$HOME/.cache/claude-notify"
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/worktrees}"
SELF="$0"

CURRENT=$(tmux display-message -p '#S' 2>/dev/null || true)

render() {
  # Union of (tmux sessions whose name is repo/branch) + (dirs under worktrees/).
  {
    tmux list-sessions -F '#{session_name}' 2>/dev/null | awk '/\//'
    if [ -d "$WORKTREE_ROOT" ]; then
      find "$WORKTREE_ROOT" -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
        | sed "s|$WORKTREE_ROOT/||"
    fi
  } | awk '!seen[$0]++' | sort -f | while read -r s; do
    repo="${s%%/*}"; branch="${s#*/}"
    wt="$WORKTREE_ROOT/$repo/$branch"

    live=" "; tmux has-session -t "$s" 2>/dev/null || live="·"
    cur=" ";  [ "$s" = "$CURRENT" ] && cur="●"
    agent=" ";[ -f "$NOTIFY/$s" ] && agent="🤖"
    dirty=" "
    if [ -d "$wt" ]; then
      [ -n "$(git -C "$wt" status --porcelain 2>/dev/null | head -1)" ] && dirty="◆"
    fi

    if [ -d "$wt" ]; then
      ab=$(git -C "$wt" rev-list --left-right --count origin/main...HEAD 2>/dev/null \
        | awk '{printf "+%s/-%s", $2, $1}')
      [ -z "$ab" ] && ab="-"
      age=$(git -C "$wt" log -1 --format='%cr' 2>/dev/null)
      [ -z "$age" ] && age="-"
    else
      ab="missing-dir"; age="-"
    fi

    pr=$("$HOME/.config/tmux/pr-state.sh" "$s" 2>/dev/null)

    printf '%s\t%s\t\033[1m%-40s\033[0m  \033[36m%-10s\033[0m  \033[90m%-14s\033[0m  %s %s %s %s\n' \
      "$s" "$wt" "$s" "$ab" "$age" "$live" "$cur" "$agent" "$dirty${pr:+  $pr}"
  done
}

case "${1:-}" in
  --render) render; exit 0 ;;
esac

sel=$(render | fzf --ansi --reverse --no-sort \
  --delimiter=$'\t' --with-nth=3 \
  --prompt='  dashboard  ' \
  --header='enter: switch  ^d: delete  ^k: kill-session  ^p: open PR  ^s: sync from main  ^r: refresh' \
  --bind "ctrl-r:reload($SELF --render)" \
  --bind "ctrl-d:execute($HOME/.config/tmux/worktree-remove.sh {1})+reload($SELF --render)" \
  --bind "ctrl-k:execute-silent(tmux kill-session -t {1} 2>/dev/null)+reload($SELF --render)" \
  --bind "ctrl-p:execute-silent(cd {2} 2>/dev/null && gh pr view --web)" \
  --bind "ctrl-s:execute(cd {2} 2>/dev/null && git fetch origin main && git rebase origin/main)" \
  --color=bg+:#0050A4,fg+:#ffffff,hl:#ffc600,hl+:#ffc600,pointer:#ffc600,prompt:#0088ff)

[ -z "$sel" ] && exit 0
target=$(printf '%s\n' "$sel" | awk -F'\t' '{print $1}')
tmux has-session -t "$target" 2>/dev/null && tmux switch-client -t "$target"
