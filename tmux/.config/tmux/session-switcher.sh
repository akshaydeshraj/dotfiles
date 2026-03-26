#!/bin/bash
export PATH="/opt/homebrew/bin:$PATH"

CURRENT=$(tmux display-message -p '#S')

# Annotate sesh output with ● (current) and 🤖 (claude waiting)
annotate() {
  sesh list -i ${1:--it} | while IFS= read -r line; do
    name=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^. //')
    markers=""
    [ "$name" = "$CURRENT" ] && markers="  ●"
    [ -f "/tmp/claude-notify/${name}" ] && markers="${markers}  🤖"
    printf '%s%s\n' "$line" "$markers"
  done
}

# Reload mode: fzf calls this script back for refreshing the list
if [ "$1" = "--reload" ]; then
  annotate "$2"
  exit 0
fi

session=$(annotate -it | fzf --reverse --no-sort --ansi \
  --border=none --no-info \
  --prompt '  ' \
  --header '  ^a all / ^t tmux / ^x zoxide / ^d kill' \
  --bind 'tab:down,btab:up' \
  --bind "ctrl-a:change-prompt(  )+reload($0 --reload)" \
  --bind "ctrl-t:change-prompt(  )+reload($0 --reload -it)" \
  --bind "ctrl-x:change-prompt(  )+reload($0 --reload -iz)" \
  --bind "ctrl-d:execute(tmux kill-session -t {2..})+reload($0 --reload -it)" \
  --color=bg+:#0050A4,fg+:#ffffff,hl:#ffc600,hl+:#ffc600,pointer:#ffc600,prompt:#0088ff \
)

# Strip markers before connecting
session=$(echo "$session" | sed 's/  [●🤖].*$//')
if [ -n "$session" ]; then
  rm -f "/tmp/claude-notify/${session}"
  sesh connect "$session"
fi
