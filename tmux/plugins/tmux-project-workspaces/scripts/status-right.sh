#!/usr/bin/env bash

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-project-workspaces"
DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces"
NOTIFY_DIR="${PROJECT_WORKSPACES_NOTIFY_DIR:-${NOTIFY:-$DEFAULT_CACHE_DIR/notify}}"
AGENT_STATE_DIR="${PROJECT_WORKSPACES_AGENT_STATE_DIR:-${AGENT_STATE_DIR:-$DEFAULT_CACHE_DIR/agent-state}}"
PROJECTS_FILE="${PROJECT_WORKSPACES_PROJECTS_FILE:-${PROJECTS_FILE:-$DEFAULT_STATE_DIR/projects.txt}}"
SESSION="${1:-}"

active_notify_count() {
  local count

  [ -d "$NOTIFY_DIR" ] || {
    printf '0'
    return 0
  }

  count="$(find "$NOTIFY_DIR" -maxdepth 1 -type f ! -name '.count' 2>/dev/null | wc -l | tr -d ' ')"
  if [ -n "$count" ] && [ "$count" -gt 0 ] 2>/dev/null; then
    printf '%s' "$count"
    return 0
  fi

  printf '0'
}

pr_tag() {
  local raw="$1"
  case "$raw" in
    PASS)   return 1 ;;
    FAIL)   printf 'pr:fail' ;;
    "⋯")    printf 'pr:wait' ;;
    merged) printf 'merged' ;;
    closed) printf 'closed' ;;
    *)      return 1 ;;
  esac
}

agent_state_file() {
  local session="$1"
  printf '%s/%s.state\n' "$AGENT_STATE_DIR" "$(printf '%s' "$session" | tr '/:' '__')"
}

agent_status_tag() {
  local session="$1" file status tool label updated now
  file="$(agent_state_file "$session")"
  [ -f "$file" ] || return 1

  status="$(sed -n 's/^status=//p' "$file" | head -1)"
  tool="$(sed -n 's/^tool=//p' "$file" | head -1)"
  updated="$(sed -n 's/^updated_at=//p' "$file" | head -1)"
  [ -n "$status" ] || return 1

  if [ "$status" = "run" ] && [ -n "$updated" ]; then
    now="$(date +%s)"
    if [ $((now - updated)) -gt 90 ] 2>/dev/null; then
      status="off"
    fi
  fi

  case "$tool" in
    claude|codex) label="$tool" ;;
    "") label="agent" ;;
    *) label="$tool" ;;
  esac

  case "$status" in
    run) return 1 ;;
    wait) printf '%s:wait' "$label" ;;
    done) printf '%s:done' "$label" ;;
    off) printf '%s:off' "$label" ;;
    *) return 1 ;;
  esac
}

worktree_path_for_session() {
  local session="$1"
  local repo branch root wt env_path

  [[ "$session" == */* ]] || return 1

  env_path="$(tmux show-environment -t "=$session" WORKTREE_PATH 2>/dev/null | sed -n 's/^WORKTREE_PATH=//p')"
  if [ -n "$env_path" ] && [ -d "$env_path" ]; then
    printf '%s\n' "$env_path"
    return 0
  fi

  repo="${session%%/*}"
  branch="${session#*/}"
  root="${PROJECT_WORKSPACES_WORKTREE_ROOT:-${WORKTREE_ROOT:-$HOME/worktrees}}"
  wt="$root/$repo/$branch"
  if [ -d "$wt" ]; then
    printf '%s\n' "$wt"
    return 0
  fi

  if [ -f "$PROJECTS_FILE" ]; then
    while IFS= read -r candidate; do
      [ -n "$candidate" ] || continue
      [ -d "$candidate" ] || continue
      [ "$(basename "$candidate")" = "$repo" ] || continue

      wt="$(git -C "$candidate" worktree list --porcelain 2>/dev/null | awk -v want="$branch" '
        /^worktree /{wt=$2}
        /^branch refs\/heads\//{
          b=$0
          sub(/^branch refs\/heads\//, "", b)
          if (b == want) { print wt; exit }
        }')"
      if [ -n "$wt" ] && [ -d "$wt" ]; then
        printf '%s\n' "$wt"
        return 0
      fi
    done < "$PROJECTS_FILE"
  fi

  return 1
}

parts=()
count="$(active_notify_count)"
if [ "$count" -gt 0 ] 2>/dev/null; then
  parts+=("●$count")
fi

if [ -n "$SESSION" ]; then
  if tag="$(agent_status_tag "$SESSION" 2>/dev/null)"; then
    parts+=("$tag")
  fi
fi

if wt="$(worktree_path_for_session "$SESSION" 2>/dev/null)"; then
  if pr_raw="$("$SCRIPT_DIR/pr-state.sh" "$SESSION" 2>/dev/null | xargs)" && [ -n "$pr_raw" ]; then
    if tag="$(pr_tag "$pr_raw" 2>/dev/null)"; then
      parts+=("$tag")
    fi
  fi

  if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null | head -1)" ]; then
    parts+=("dirty")
  fi
fi

if [ "${#parts[@]}" -gt 0 ]; then
  printf '%s ' "${parts[*]}"
fi
