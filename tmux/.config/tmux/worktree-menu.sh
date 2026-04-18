#!/bin/bash
# prefix+w menu. Acts on the current tmux session's worktree.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SESSION=$(tmux display-message -p '#S')
WT_PATH=$(tmux display-message -p '#{pane_current_path}')

ACTION=$(printf '%s\n' \
  " new worktree…" \
  "󰆴 remove this worktree" \
  " sync from main (fetch + rebase)" \
  " open PR (push + gh pr create)" \
  " view PR in browser" \
  " prune orphans" \
  "󰜺 kill this session only" \
  | fzf --reverse --prompt='  worktree  ' \
        --color=bg+:#0050A4,fg+:#ffffff,hl:#ffc600,hl+:#ffc600,pointer:#ffc600,prompt:#0088ff)

case "$ACTION" in
  *"new worktree"*)
    exec "$HOME/.config/tmux/tree-switcher.sh"
    ;;
  *"remove this worktree"*)
    "$HOME/.config/tmux/worktree-remove.sh" "$SESSION"
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
  *"prune orphans"*)
    tmux display-popup -E -w 80% -h 70% -b rounded -S "fg=#ffc600" -T " Orphans " \
      "$HOME/.config/tmux/prune-orphans.sh --interactive"
    ;;
  *"kill this session"*)
    tmux kill-session -t "$SESSION"
    ;;
esac
