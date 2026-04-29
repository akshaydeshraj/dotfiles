#!/usr/bin/env bash

set -euo pipefail

# ── Tokyo Night Storm palette ─────────────────────────────────────
# Source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh
PALETTE_SH="$HOME/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh"
# shellcheck source=/dev/null
[ -f "$PALETTE_SH" ] && source "$PALETTE_SH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_SCRIPT="$SCRIPT_DIR/agent-state.sh"
SESSION="$(tmux display-message -p '#S')"
PANE_CMD="$(tmux display-message -p '#{pane_current_command}' | tr '[:upper:]' '[:lower:]')"

detect_tool() {
  local shown tool
  shown="$("$STATE_SCRIPT" show "$SESSION" 2>/dev/null || true)"
  tool="$(printf '%s\n' "$shown" | sed -n 's/^tool=//p' | head -1)"
  if [ -n "$tool" ]; then
    printf '%s\n' "$tool"
    return 0
  fi
  case "$PANE_CMD" in
    *codex*) printf 'codex\n' ;;
    *claude*) printf 'claude\n' ;;
    *) printf 'agent\n' ;;
  esac
}

TOOL="$(detect_tool)"

ACTION=$(printf '%s\n' \
  " mark $TOOL waiting" \
  " mark $TOOL done" \
  " clear agent state" \
  | fzf --reverse --prompt='  agent  ' \
        --color="$(tn_fzf_colors)")

case "$ACTION" in
  *"waiting"*)
    "$STATE_SCRIPT" set wait "$TOOL" "$SESSION"
    tmux display-message "$TOOL waiting: $SESSION"
    ;;
  *"done"*)
    "$STATE_SCRIPT" set "done" "$TOOL" "$SESSION"
    tmux display-message "$TOOL done: $SESSION"
    ;;
  *"clear"*)
    "$STATE_SCRIPT" clear "$SESSION"
    tmux display-message "cleared agent state: $SESSION"
    ;;
esac
