export PATH="/opt/homebrew/bin:$PATH"

session=$(tmux list-sessions -F '#S' 2>/dev/null | fzf --reverse --border=none --no-info \
  --print-query \
  --header='  Pick or create a session' \
  --color=bg+:#0050A4,fg+:#ffffff,hl:#ffc600,hl+:#ffc600,pointer:#ffc600,prompt:#0088ff \
  | tail -1)

if [ -n "$session" ]; then
  if tmux has-session -t "$session" 2>/dev/null; then
    tmux switch-client -t "$session"
  else
    tmux new-session -d -s "$session" && tmux switch-client -t "$session"
  fi
fi
