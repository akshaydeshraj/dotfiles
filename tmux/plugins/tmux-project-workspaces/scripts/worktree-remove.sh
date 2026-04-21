#!/usr/bin/env bash
# Remove a worktree + its tmux session + its branch.
# Usage: worktree-remove.sh [--no-confirm] <session>   (e.g. "devspec/feat-login")
#
# Without --no-confirm, dispatches an async tmux confirm-before prompt to the
# outer client (so it survives popup closure), then re-invokes with --no-confirm.

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_BIN="${PROJECT_WORKSPACES_CORE_BIN:-$PLUGIN_DIR/target/release/tmux-project-workspaces}"
LOG=/tmp/wt-remove.log
echo "[$(date '+%H:%M:%S')] invoked: argv=[$*] pwd=$PWD tmux=${TMUX:-unset} outer=${OUTER_CLIENT:-unset}" >> "$LOG"

DEFAULT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-project-workspaces"
DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces"
PROJECTS_FILE="${PROJECT_WORKSPACES_PROJECTS_FILE:-${PROJECTS_FILE:-$DEFAULT_STATE_DIR/projects.txt}}"
NOTIFY="${PROJECT_WORKSPACES_NOTIFY_DIR:-${NOTIFY:-$DEFAULT_CACHE_DIR/notify}}"

current_client() {
  tmux display-message -p '#{client_tty}' 2>/dev/null || true
}

list_projects() {
  awk 'NF && $1 !~ /^#/' "$PROJECTS_FILE" 2>/dev/null | while read -r p; do
    [ -d "$p/.git" ] || [ -f "$p/.git" ] || continue
    printf '%s\n' "$p"
  done
}

canonical_repo_from_path() {
  local p="$1" common

  common=$(git -C "$p" rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$common" in
    /*) ;;
    *) common=$(cd "$p" && cd "$common" && pwd) ;;
  esac
  case "$common" in
    */.git) printf '%s\n' "${common%/.git}" ;;
    *) printf '%s\n' "$common" ;;
  esac
}

find_target() {
  local session="$1" repo_name branch session_path repo wt kind

  if [ -x "$CORE_BIN" ]; then
    "$CORE_BIN" find-delete-target "$session"
    return 0
  fi

  repo_name="${session%%/*}"
  branch="${session#*/}"

  if tmux has-session -t "$session" 2>/dev/null; then
    session_path=$(tmux display-message -p -t "$session" '#{session_path}' 2>/dev/null)
    if [ -n "$session_path" ] && [ -d "$session_path" ]; then
      repo=$(canonical_repo_from_path "$session_path" 2>/dev/null || true)
      if [ -n "$repo" ]; then
        kind="worktree"
        [ "$session_path" = "$repo" ] && kind="primary"
        printf '%s\t%s\t%s\n' "$repo" "$session_path" "$kind"
        return 0
      fi
    fi
  fi

  while read -r repo; do
    [ "$(basename "$repo")" = "$repo_name" ] || continue
    wt=$(git -C "$repo" worktree list --porcelain 2>/dev/null | awk -v want="$branch" '
      /^worktree /{wt=$2}
      /^branch /{
        b=$2
        sub("refs/heads/","",b)
        if (b == want) {
          print wt
          exit
        }
      }
    ')
    [ -n "$wt" ] || continue

    kind="worktree"
    [ "$wt" = "$repo" ] && kind="primary"
    printf '%s\t%s\t%s\n' "$repo" "$wt" "$kind"
    return 0
  done < <(list_projects)

  return 1
}

remove_worktree_core() {
  local session="$1"
  [ -x "$CORE_BIN" ] || return 1
  "$CORE_BIN" remove-worktree "$session"
}

NO_CONFIRM=false
if [ "${1:-}" = "--no-confirm" ]; then
  NO_CONFIRM=true
  shift
fi

SESSION="${1:-}"
[ -z "$SESSION" ] && { echo "usage: $0 [--no-confirm] <session>"; exit 1; }
[[ "$SESSION" != */* ]] && { echo "bad session name: $SESSION"; exit 1; }

if ! $NO_CONFIRM; then
  CLIENT="${OUTER_CLIENT:-$(current_client)}"
  [ -n "$CLIENT" ] || CLIENT="$(tmux list-clients -F '#{client_tty}' 2>/dev/null | head -1)"
  SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  printf -v ACTION 'run-shell "%s --no-confirm %q"' "$SELF" "$SESSION"
  echo "[$(date '+%H:%M:%S')] dispatching confirm: client=$CLIENT self=$SELF action=$ACTION" >> "$LOG"
  # confirm-before is async; action runs only on 'y'.
  if [ -n "$CLIENT" ]; then
    tmux confirm-before -t "$CLIENT" -p "remove $SESSION? (y/n)" "$ACTION"
  else
    tmux confirm-before -p "remove $SESSION? (y/n)" "$ACTION"
  fi
  rc=$?
  echo "[$(date '+%H:%M:%S')] confirm-before dispatch rc=$rc" >> "$LOG"
  exit 0
fi

# --- actual removal ---
BRANCH="${SESSION#*/}"
target=$(find_target "$SESSION")
REPO=$(printf '%s\n' "$target" | awk -F'\t' '{print $1}')
WT_PATH=$(printf '%s\n' "$target" | awk -F'\t' '{print $2}')
WT_KIND=$(printf '%s\n' "$target" | awk -F'\t' '{print $3}')

if [ -z "$WT_PATH" ]; then
  tmux display-message "unable to resolve worktree for $SESSION"
  exit 1
fi

if [ "$WT_KIND" = "primary" ]; then
  tmux display-message "refusing to remove primary checkout: $SESSION"
  exit 1
fi

tmux kill-session -t "$SESSION" 2>/dev/null || true

if [ -x "$CORE_BIN" ]; then
  meta=$(remove_worktree_core "$SESSION" 2>&1) || {
    echo "[$(date '+%H:%M:%S')] core remove failed: $meta" >> "$LOG"
    tmux display-message "${meta%%$'\n'*}"
    exit 1
  }
  REPO=$(printf '%s\n' "$meta" | awk -F'\t' '{print $1}')
  WT_PATH=$(printf '%s\n' "$meta" | awk -F'\t' '{print $2}')
else
  if [ -n "$REPO" ]; then
    err=$(git -C "$REPO" worktree remove --force "$WT_PATH" 2>&1) || {
      echo "[$(date '+%H:%M:%S')] worktree remove failed: $err" >> "$LOG"
    }
  fi

  [ -d "$WT_PATH" ] && rm -rf "$WT_PATH"

  # User already confirmed removing the whole worktree; force-delete the branch too.
  if [ -n "$REPO" ]; then
    err=$(git -C "$REPO" branch -d "$BRANCH" 2>&1) \
      || err=$(git -C "$REPO" branch -D "$BRANCH" 2>&1) \
      || {
        echo "[$(date '+%H:%M:%S')] branch delete failed: $err" >> "$LOG"
      }
  fi
fi

mkdir -p "$NOTIFY"
rm -f "$NOTIFY/$SESSION"
count=$(find "$NOTIFY" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
  printf '🤖 %s ' "$count" > "$NOTIFY/.count"
else
  : > "$NOTIFY/.count"
fi
tmux refresh-client -S 2>/dev/null || true
tmux display-message "removed $SESSION"
