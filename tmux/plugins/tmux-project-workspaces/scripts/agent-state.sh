#!/usr/bin/env bash

set -euo pipefail

DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces"
STATE_DIR="${PROJECT_WORKSPACES_AGENT_STATE_DIR:-${AGENT_STATE_DIR:-$DEFAULT_CACHE_DIR/agent-state}}"
mkdir -p "$STATE_DIR"

usage() {
  cat <<'EOF'
usage:
  agent-state.sh set <status> <tool> [session]
  agent-state.sh touch <tool> [session]
  agent-state.sh clear [session]
  agent-state.sh show [session]

status:
  run | wait | done | off

tool:
  claude | codex | other freeform label
EOF
}

current_session() {
  tmux display-message -p '#S' 2>/dev/null || true
}

session_name() {
  local session="${1:-}"
  if [ -n "$session" ]; then
    printf '%s\n' "$session"
    return 0
  fi
  if [ -n "${TMUX_SESSION:-}" ]; then
    printf '%s\n' "$TMUX_SESSION"
    return 0
  fi
  current_session
}

safe_name() {
  printf '%s' "$1" | tr '/:' '__'
}

state_file() {
  printf '%s/%s.state\n' "$STATE_DIR" "$(safe_name "$1")"
}

now_epoch() {
  date +%s
}

set_state() {
  local status="$1"
  local tool="$2"
  local session="$3"
  local file

  case "$status" in
    run|wait|done|off) ;;
    *)
      echo "invalid status: $status" >&2
      exit 2
      ;;
  esac

  [ -n "$tool" ] || tool="unknown"
  [ -n "$session" ] || exit 0

  file="$(state_file "$session")"
  cat > "$file" <<EOF
status=$status
tool=$tool
updated_at=$(now_epoch)
session=$session
EOF
}

touch_state() {
  local tool="$1"
  local session="$2"
  set_state run "$tool" "$session"
}

show_state() {
  local session="$1"
  local file
  [ -n "$session" ] || exit 0
  file="$(state_file "$session")"
  [ -f "$file" ] || exit 0
  cat "$file"
}

clear_state() {
  local session="$1"
  local file
  [ -n "$session" ] || exit 0
  file="$(state_file "$session")"
  rm -f "$file"
}

cmd="${1:-}"
case "$cmd" in
  set)
    shift
    set_state "${1:-}" "${2:-}" "$(session_name "${3:-}")"
    ;;
  touch)
    shift
    touch_state "${1:-}" "$(session_name "${2:-}")"
    ;;
  clear)
    shift
    clear_state "$(session_name "${1:-}")"
    ;;
  show)
    shift
    show_state "$(session_name "${1:-}")"
    ;;
  *)
    usage
    exit 1
    ;;
esac
