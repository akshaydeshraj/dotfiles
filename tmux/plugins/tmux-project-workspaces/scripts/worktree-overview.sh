#!/usr/bin/env bash
# Full-screen dashboard of every worktree/session with state.
# Bound to Cmd+Shift+K (M-K) and prefix+Tab.

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DEFAULT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-project-workspaces"
DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces"
NOTIFY="${PROJECT_WORKSPACES_NOTIFY_DIR:-${NOTIFY:-$DEFAULT_CACHE_DIR/notify}}"
WORKTREE_ROOT="${PROJECT_WORKSPACES_WORKTREE_ROOT:-${WORKTREE_ROOT:-$HOME/worktrees}}"
PROJECTS_FILE="${PROJECT_WORKSPACES_PROJECTS_FILE:-${PROJECTS_FILE:-$DEFAULT_STATE_DIR/projects.txt}}"
SELF="$0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CURRENT=$(tmux display-message -p '#S' 2>/dev/null || true)

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

list_known_repos() {
  {
    list_projects
    tmux list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null | awk -F'|' '$1 ~ /\// {print $2}' | while read -r p; do
      [ -n "$p" ] || continue
      canonical_repo_from_path "$p" 2>/dev/null || true
    done
  } | awk 'NF && !seen[$0]++'
}

list_known_worktrees() {
  while read -r repo; do
    git -C "$repo" worktree list --porcelain 2>/dev/null | awk -v repo="$repo" '
      /^worktree /{wt=$2}
      /^branch /{
        branch=$2
        sub("refs/heads/","",branch)
        name=repo
        sub(".*/","",name)
        kind=(wt == repo ? "primary" : "worktree")
        print name "/" branch "\t" wt "\t" kind "\t" repo
      }
    '
  done < <(list_known_repos)
}

list_session_only_rows() {
  tmux list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null | awk -F'|' '$1 ~ /\// {print $1 "\t" $2 "\tsession-only\t-"}'
}

render() {
  # Union of known git worktrees + slash-named tmux sessions that may no longer
  # have a matching worktree on disk.
  {
    list_known_worktrees
    list_session_only_rows
  } | awk -F'\t' '!seen[$1]++' | sort -f | while IFS=$'\t' read -r s wt kind _repo_root; do
    local repo live cur agent dirty ab age pr note

    repo="${s%%/*}"
    [ -n "$wt" ] || wt="-"

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

    pr=$("$SCRIPT_DIR/pr-state.sh" "$s" 2>/dev/null)
    note=""
    [ "$kind" = "primary" ] && note=" primary"
    [ "$kind" = "session-only" ] && note=" session-only"

    printf '%s\t%s\t\033[1m%-40s\033[0m  \033[36m%-10s\033[0m  \033[90m%-14s\033[0m  %s %s %s %s\n' \
      "$s" "$wt" "$s" "$ab" "$age" "$live" "$cur" "$agent" "$dirty${note:+$note}${pr:+  $pr}"
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
  --bind "ctrl-d:execute($SCRIPT_DIR/worktree-remove.sh {1})+reload($SELF --render)" \
  --bind "ctrl-k:execute-silent(tmux kill-session -t {1} 2>/dev/null)+reload($SELF --render)" \
  --bind "ctrl-p:execute-silent(cd {2} 2>/dev/null && gh pr view --web)" \
  --bind "ctrl-s:execute(cd {2} 2>/dev/null && git fetch origin main && git rebase origin/main)" \
  --color=bg+:#0050A4,fg+:#ffffff,hl:#ffc600,hl+:#ffc600,pointer:#ffc600,prompt:#0088ff)

[ -z "$sel" ] && exit 0
target=$(printf '%s\n' "$sel" | awk -F'\t' '{print $1}')
tmux has-session -t "$target" 2>/dev/null && tmux switch-client -t "$target"
