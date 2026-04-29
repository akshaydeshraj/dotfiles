#!/usr/bin/env bash
# Detect drift between on-disk worktrees and tmux sessions.
# --interactive: show findings in an fzf list with delete/attach actions.
# (default):     stdout a summary (used by tmux start hook).

set -euo pipefail

# ── Tokyo Night Storm palette ─────────────────────────────────────
# Source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh
PALETTE_SH="$HOME/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh"
# shellcheck source=/dev/null
[ -f "$PALETTE_SH" ] && source "$PALETTE_SH"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
DEFAULT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-project-workspaces"
WORKTREE_ROOT="${PROJECT_WORKSPACES_WORKTREE_ROOT:-${WORKTREE_ROOT:-$HOME/worktrees}}"
PROJECTS_FILE="${PROJECT_WORKSPACES_PROJECTS_FILE:-${PROJECTS_FILE:-$DEFAULT_STATE_DIR/projects.txt}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

orphan_worktrees() {
  while read -r repo; do
    git -C "$repo" worktree list --porcelain 2>/dev/null | awk -v repo="$repo" '
      /^worktree /{wt=$2}
      /^branch /{
        branch=$2
        sub("refs/heads/","",branch)
        if (wt != repo) {
          name=repo
          sub(".*/","",name)
          print name "/" branch "\t" wt
        }
      }
    ' | while IFS=$'\t' read -r session path; do
      tmux has-session -t "$session" 2>/dev/null || printf 'WT\t%s\t%s\n' "$session" "$path"
    done
  done < <(list_known_repos)
}

orphan_sessions() {
  tmux list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null | awk -F'|' '$1 ~ /\// {print $1 "\t" $2}' | while IFS=$'\t' read -r s d; do
    if [ -z "$d" ] || [ ! -d "$d" ]; then
      printf 'SESSION\t%s\t%s\n' "$s" "${d:--}"
      continue
    fi

    repo=$(canonical_repo_from_path "$d" 2>/dev/null || true)
    if [ -z "$repo" ]; then
      printf 'SESSION\t%s\t%s\n' "$s" "$d"
      continue
    fi

    git -C "$repo" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | grep -Fxq "$d" \
      || printf 'SESSION\t%s\t%s\n' "$s" "$d"
  done
}

if [ "${1:-}" = "--interactive" ]; then
  sel=$({ orphan_worktrees; orphan_sessions; } | \
    fzf --reverse --ansi --delimiter=$'\t' --with-nth=1,2 \
        --prompt='  orphans  ' \
        --header='enter: adopt (attach/session)  ^d: delete  ^q: quit' \
        --bind 'ctrl-q:abort' \
        --color="$(tn_fzf_colors)" \
        --expect=ctrl-d)
  [ -z "$sel" ] && exit 0
  keypress=$(printf '%s\n' "$sel" | sed -n '1p')
  row=$(printf   '%s\n' "$sel" | sed -n '2p')
  kind=$(printf  '%s\n' "$row" | awk -F'\t' '{print $1}')
  name=$(printf  '%s\n' "$row" | awk -F'\t' '{print $2}')
  path=$(printf  '%s\n' "$row" | awk -F'\t' '{print $3}')

  if [ "$keypress" = "ctrl-d" ]; then
    case "$kind" in
      WT)      "$SCRIPT_DIR/worktree-remove.sh" --no-confirm "$name" ;;
      SESSION) tmux kill-session -t "$name" && tmux display-message "killed $name" ;;
    esac
  else
    case "$kind" in
      WT)      exec "$SCRIPT_DIR/tree-switcher.sh" ;;
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
