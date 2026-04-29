#!/usr/bin/env bash
# Unified Cmd+K: tree view of CURATED projects + their worktrees.
#
# Behaviour:
# - Only projects listed in PROJECTS_FILE render (curated, not auto-discovered).
# - Typing an unknown name that matches a zoxide-known repo -> adds it, re-renders.
# - Typing "<repo>/<branch>" -> creates a worktree (auto-tracks the repo).
# - Typing ":<name>" -> always opens/switches a plain tmux session with that name.
# - Pressing Esc with text in the prompt -> closes cleanly (no ghost session).
#
# Keys inside fzf:
#   enter  go            ^a add project (pick from zoxide)
#   ^n     new worktree  ^x untrack project (keep worktree on disk)
#   ^d     delete worktree+session+branch
#   ^k     kill session only
#   ^p     open PR for row    ^r refresh

set -euo pipefail

# ── Tokyo Night Storm palette ─────────────────────────────────────
# Source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh
PALETTE_SH="$HOME/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh"
# shellcheck source=/dev/null
[ -f "$PALETTE_SH" ] && source "$PALETTE_SH"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-project-workspaces"
DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces"
NOTIFY="${PROJECT_WORKSPACES_NOTIFY_DIR:-${NOTIFY:-$DEFAULT_CACHE_DIR/notify}}"
WORKTREE_ROOT="${PROJECT_WORKSPACES_WORKTREE_ROOT:-${WORKTREE_ROOT:-$HOME/worktrees}}"
PROJECTS_FILE="${PROJECT_WORKSPACES_PROJECTS_FILE:-${PROJECTS_FILE:-$DEFAULT_STATE_DIR/projects.txt}}"
CORE_BIN="${PROJECT_WORKSPACES_CORE_BIN:-$PLUGIN_DIR/target/release/tmux-project-workspaces}"
SELF="$0"
LOG_FILE="${TMPDIR:-/tmp}/tree-switcher.log"

# Outer tmux client that invoked us (popup dispatches don't reach it unless -t targets it).
current_client() {
  tmux display-message -p '#{client_tty}' 2>/dev/null || true
}

OUTER_CLIENT="${OUTER_CLIENT:-$(current_client)}"
[ -n "$OUTER_CLIENT" ] || OUTER_CLIENT="$(tmux list-clients -F '#{client_tty}' 2>/dev/null | head -1)"
export OUTER_CLIENT

mkdir -p "$(dirname "$PROJECTS_FILE")"
touch "$PROJECTS_FILE"
mkdir -p "$NOTIFY"

CURRENT=$(tmux display-message -p '#S' 2>/dev/null || true)

open_plain_session() {
  local query="$1" session

  if core_available; then
    if session=$("$CORE_BIN" open-plain-session "$query" "$OUTER_CLIENT" 2>/dev/null); then
      tmux display-message "opened session $session"
      return 0
    fi
  fi

  tmux display-message "failed to open plain session"
}

# ------- project list helpers ------------------------------------------------

# Emit absolute paths of curated projects that still resolve to a git repo.
list_projects() {
  awk 'NF && $1 !~ /^#/' "$PROJECTS_FILE" | while read -r p; do
    [ -d "$p/.git" ] || [ -f "$p/.git" ] || continue
    printf '%s\n' "$p"
  done
}

# Add a repo path to the curated list (idempotent).
add_project() {
  local repo="$1"
  [ -z "$repo" ] && return 0
  [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || return 0
  grep -Fxq "$repo" "$PROJECTS_FILE" 2>/dev/null && return 0
  printf '%s\n' "$repo" >> "$PROJECTS_FILE"
}

# Remove a repo path from the curated list; disk is untouched.
remove_project() {
  local repo="$1"
  [ -z "$repo" ] && return 0
  local tmp
  tmp=$(mktemp)
  grep -Fxv "$repo" "$PROJECTS_FILE" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$PROJECTS_FILE"
}

# Resolve a short name (e.g. "helyx") to an absolute repo path.
# Prefers a repo already in PROJECTS_FILE, otherwise falls back to zoxide.
# Always emits at most one line.
resolve_repo_by_name_shell() {
  local name="$1" d
  {
    list_projects | while read -r d; do
      [ "$(basename "$d")" = "$name" ] && printf '%s\n' "$d"
    done
    zoxide query -l 2>/dev/null | while read -r d; do
      [ "$(basename "$d")" = "$name" ] && { [ -d "$d/.git" ] || [ -f "$d/.git" ]; } \
        && printf '%s\n' "$d"
    done
  } | awk '!seen[$0]++' | head -1
}

# Zoxide-known git repos NOT already in the curated list.
untracked_candidates_shell() {
  local tracked
  tracked=$(list_projects | sort -u)
  zoxide query -l 2>/dev/null | while read -r d; do
    { [ -d "$d/.git" ] || [ -f "$d/.git" ]; } || continue
    printf '%s\n' "$d"
  done | awk '!seen[$0]++' | while read -r d; do
    if ! printf '%s\n' "$tracked" | grep -Fxq "$d"; then
      printf '%s\n' "$d"
    fi
  done | sort -f
}

# Given any path inside a git worktree/clone, return the canonical main-clone path.
canonical_repo_from_path() {
  local p="$1" common
  common=$(git -C "$p" rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$common" in
    /*) ;;
    *)  common=$(cd "$p" && cd "$common" && pwd) ;;
  esac
  case "$common" in
    */.git) printf '%s\n' "${common%/.git}" ;;
    *)      printf '%s\n' "$common" ;;
  esac
}

list_plain_sessions() {
  tmux list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null | awk -F'|' '$1 !~ /\// {print $1 "\t" $2}'
}

header_for_row() {
  local key="$1" kind="$2"

  case "$key" in
    REPO:*)
      printf '^a add repo  enter switch primary  ^n new worktree  ^x untrack  ^r reload'
      ;;
    SECTION:projects)
      printf '^a add repo  ^n new worktree  ^r reload'
      ;;
    SECTION:plain)
      printf 'enter switch  ^k kill  ^r reload'
      ;;
    SESSION:*)
      printf 'enter switch  ^k kill  ^r reload'
      ;;
    HINT:*)
      printf '^a add repo  ^r reload'
      ;;
    *)
      if [ "$kind" = "primary" ]; then
        printf 'enter switch  ^p PR  ^k protected  ^r reload'
      else
        printf 'enter switch  ^d delete  ^k remove-if-disposable  ^p PR  ^r reload'
      fi
      ;;
  esac
}

describe_row_shell() {
  local key="$1" path="$2" repo="$3" kind="$4"

  case "$key" in
    REPO:*)
      printf 'Projects\nenter: switch primary  ^n: new worktree  ^x: untrack\nrepo: %s\n' "$repo"
      ;;
    SECTION:projects)
      printf 'Projects\n^a: add repo  ^n: new worktree\n'
      ;;
    SECTION:plain)
      printf 'Sessions\nenter: switch\n'
      ;;
    SESSION:*)
      printf 'Sessions\nenter: switch\npath: %s\n' "${path:-$HOME}"
      ;;
    HINT:*)
      printf 'Hints\n^a: add repo\n'
      ;;
    */*)
      if [ "$kind" = "primary" ]; then
        printf 'Projects\nenter: switch  ^p: PR\nprimary checkout: delete disabled\npath: %s\n' "$path"
      else
        printf 'Projects\nenter: switch  ^d: delete  ^p: PR\npath: %s\n' "$path"
      fi
      ;;
    *)
      printf 'Picker\nenter: switch\n'
      ;;
  esac
}

# ------- rendering -----------------------------------------------------------

render_shell() {
  local projects plain_sessions
  projects=$(list_projects)
  plain_sessions=$(list_plain_sessions)

  if [ -z "$projects" ] && [ -z "$plain_sessions" ]; then
    printf '\tHINT:\t(no projects yet - type a repo name + enter to add, or ^a to pick)\t\t\t\t\n'
    return 0
  fi

  if [ -n "$projects" ]; then
    printf 'projects\tSECTION:projects\t\033[1;33mProjects\033[0m\t\t\t\tsection\n'
    printf '%s\n' "$projects" | awk '!seen[$0]++' | sort -f | while read -r repo; do
      local name rows
      name=$(basename "$repo")

      rows=$(git -C "$repo" worktree list --porcelain 2>/dev/null | awk -v repo="$repo" '
        /^worktree /{wt=$2}
        /^branch /{
          branch=$2
          sub("refs/heads/","",branch)
          kind=(wt == repo ? "primary" : "worktree")
          print wt "\t" branch "\t" kind
        }
      ')

      if [ -z "$rows" ]; then
        printf '%s\t%s\t▸ %s\t\t%s\t%s\trepo\n' \
          "$name" "REPO:$name" "$name" "$repo" "$repo"
        continue
      fi

      printf '%s\t%s\t\033[1;33m▾ %s\033[0m\t\t%s\t%s\trepo\n' \
        "$name" "REPO:$name" "$name" "$repo" "$repo"

      printf '%s\n' "$rows" | while IFS=$'\t' read -r wt_path branch kind; do
        local session search m live age tags
        [ -z "$wt_path" ] && continue

        session="$name/$branch"
        search="$name $branch"
        m=""
        [ "$session" = "$CURRENT" ] && m="$m ●"
        [ -f "$NOTIFY/$session" ] && m="$m 🤖"
        [ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null | head -1)" ] && m="$m ◆"
        live="[stopped]"
        tmux has-session -t "=$session" 2>/dev/null && live="[live]"
        age=$(git -C "$wt_path" log -1 --format='%cr' 2>/dev/null)
        tags=""
        [ "$kind" = "primary" ] && tags="$tags [primary]"
        [[ "$m" == *"◆"* ]] && tags="$tags [dirty]"
        [[ "$m" == *"🤖"* ]] && tags="$tags [agent]"
        [[ "$m" == *"●"* ]] && tags="$tags ●"

        printf '%s\t%s\t    \033[36m%-36s\033[0m\t%s%s %s\t%s\t%s\t%s\n' \
          "$search" "$session" "$branch" "$live" "$tags" "$age" "$wt_path" "$repo" "$kind"
      done
    done
  fi

  if [ -n "$plain_sessions" ]; then
    printf 'sessions\tSECTION:plain\t\033[1;36mSessions\033[0m\t\t\t\tsection\n'
    printf '%s\n' "$plain_sessions" | awk -F'\t' '!seen[$1]++' | sort -f | while IFS=$'\t' read -r session path; do
      local marker live note
      [ -n "$session" ] || continue
      marker=""
      [ "$session" = "$CURRENT" ] && marker=" ●"
      live="[live]"
      note=" [session]"
      printf '%s\tSESSION:%s\t    \033[36m%-36s\033[0m\t%s%s%s\t%s\t\tplain\n' \
        "$session" "$session" "$session" "$live" "$marker" "$note" "${path:-$HOME}"
    done
  fi
}

core_available() {
  [ -x "$CORE_BIN" ]
}

kill_policy() {
  local key="$1"

  if core_available; then
    "$CORE_BIN" kill-policy "$key"
    return $?
  fi

  if [[ "$key" == SESSION:* ]]; then
    session="${key#SESSION:}"
    if tmux has-session -t "=$session" 2>/dev/null; then
      printf 'kill\t%s\n' "$session"
      return 0
    fi
    printf 'blocked\tsession not running: %s\n' "$session"
    return 2
  fi

  if tmux has-session -t "=$key" 2>/dev/null; then
    printf 'kill\t%s\n' "$key"
    return 0
  fi
  printf 'blocked\tsession not running: %s\n' "$key"
  return 2
}

resolve_repo_by_name() {
  local name="$1"

  if core_available; then
    "$CORE_BIN" resolve-repo "$name"
    return 0
  fi

  resolve_repo_by_name_shell "$name"
}

untracked_candidates() {
  if core_available; then
    "$CORE_BIN" untracked-candidates
    return 0
  fi

  untracked_candidates_shell
}

describe_row() {
  if core_available; then
    "$CORE_BIN" describe-row "$1" "$2" "$3" "$4"
  else
    describe_row_shell "$1" "$2" "$3" "$4"
  fi
}

render() {
  if core_available; then
    "$CORE_BIN" render
  else
    render_shell
  fi
}

# Sub-picker: show every zoxide repo not yet tracked; selected -> add + re-render.
add_picker() {
  local cands pick
  cands=$(untracked_candidates)
  [ -z "$cands" ] && { tmux display-message "no untracked git repos found via zoxide"; return 0; }
  pick=$(printf '%s\n' "$cands" | fzf \
    --reverse --prompt='add ❯ ' \
    --header='pick a repo to track (Esc to cancel)' \
    --color="$(tn_fzf_colors)") || return 0
  [ -n "$pick" ] && add_project "$pick"
}

pick_project_for_new_worktree() {
  local pick
  pick=$(list_projects | while read -r repo; do
    [ -n "$repo" ] || continue
    printf '%s\t%s\n' "$(basename "$repo")" "$repo"
  done | fzf \
    --reverse --delimiter=$'\t' --with-nth=1,2 \
    --prompt='new worktree ❯ ' \
    --header='pick a project (Esc to cancel)' \
    --color="$(tn_fzf_colors)") || return 0
  printf '%s\n' "$pick" | awk -F'\t' '{print $2}'
}

# ------- session / worktree lifecycle ----------------------------------------

create_worktree_core() {
  local repo="$1" branch="$2"
  core_available || return 1
  "$CORE_BIN" create-worktree "$repo" "$branch"
}

create_session() {
  local repo="$1" wt_path="$2" branch="$3"

  core_available || return 1
  "$CORE_BIN" open-worktree-session "$repo" "$wt_path" "$branch" "$OUTER_CLIENT"
}

ensure_and_attach() {
  local repo="$1" branch="$2"
  local name wt session err meta

  if core_available; then
    if ! meta=$(create_worktree_core "$repo" "$branch" 2>&1); then
      tmux display-message "${meta%%$'\n'*}"
      return 1
    fi
    repo=$(printf '%s\n' "$meta" | awk -F'\t' '{print $1}')
    wt=$(printf '%s\n' "$meta" | awk -F'\t' '{print $2}')
    name=$(printf '%s\n' "$meta" | awk -F'\t' '{print $3}')
    branch=$(printf '%s\n' "$meta" | awk -F'\t' '{print $4}')
  else
    name=$(basename "$repo")
    wt="$WORKTREE_ROOT/$name/$branch"
    mkdir -p "$(dirname "$wt")"

    if ! git -C "$repo" worktree list --porcelain | awk '/^worktree /{print $2}' | grep -qx "$wt"; then
      if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
        err=$(git -C "$repo" worktree add "$wt" "$branch" 2>&1) || {
          tmux display-message "${err%%$'\n'*}"
          return 1
        }
      elif git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        err=$(git -C "$repo" worktree add --track -b "$branch" "$wt" "origin/$branch" 2>&1) || {
          tmux display-message "${err%%$'\n'*}"
          return 1
        }
      else
        err=$(git -C "$repo" worktree add -b "$branch" "$wt" 2>&1) || {
          tmux display-message "${err%%$'\n'*}"
          return 1
        }
      fi
    fi

    add_project "$repo"
  fi

  session="$name/$branch"
  create_session "$repo" "$wt" "$branch" >/dev/null 2>&1 || {
    tmux display-message "failed to open session: $session"
    return 1
  }
  rm -f "$NOTIFY/$session"
  tmux display-message "ready: $session"
}

prompt_branch_and_create() {
  local repo="$1"
  local name
  name=$(basename "$repo")
  add_project "$repo"

  tmux set-environment -g TREE_SWITCHER_CREATE_REPO "$repo"
  tmux set-environment -g TREE_SWITCHER_CREATE_NAME "$name"

  # Dispatch to the outer client so the prompt survives the popup closing.
  if [ -n "$OUTER_CLIENT" ]; then
    tmux command-prompt -t "$OUTER_CLIENT" -p "new branch in $name:" \
      "run-shell \"$SELF --create '#{TREE_SWITCHER_CREATE_REPO}' '%1'\""
  else
    tmux command-prompt -p "new branch in $name:" \
      "run-shell \"$SELF --create '#{TREE_SWITCHER_CREATE_REPO}' '%1'\""
  fi
}

# ------- subcommand dispatch -------------------------------------------------

case "${1:-}" in
  --render)
    render
    exit 0
    ;;
  --describe-row)
    describe_row "$2" "$3" "$4" "$5"
    exit 0
    ;;
  --create)
    repo="$2"; branch="$3"
    [ -z "$branch" ] && exit 0
    resolved=$(canonical_repo_from_path "$repo" 2>/dev/null)
    [ -n "$resolved" ] && repo="$resolved"
    ensure_and_attach "$repo" "$branch"
    exit 0
    ;;
  --prompt-create)
    repo="$2"
    client="${3:-}"
    [ -n "$repo" ] || exit 0
    [ -n "$client" ] && OUTER_CLIENT="$client"
    prompt_branch_and_create "$repo"
    exit 0
    ;;
  --kill-session)
    key="$2"
    case "$key" in
      ACTION:*|REPO:*|HINT:*|SECTION:*|'') exit 0 ;;
    esac
    decision=$(kill_policy "$key" 2>&1)
    rc=$?
    action=$(printf '%s\n' "$decision" | awk -F'\t' '{print $1}')
    message=$(printf '%s\n' "$decision" | awk -F'\t' '{print $2}')
    if [ "$action" = "kill" ] && [ -n "$message" ]; then
      tmux kill-session -t "=$message" 2>/dev/null || true
    elif [ "$action" = "remove" ] && [ -n "$message" ]; then
      "$SCRIPT_DIR/worktree-remove.sh" --no-confirm "$message" >/dev/null 2>&1 || true
    elif [ -n "$message" ]; then
      tmux display-message "$message"
    elif [ $rc -ne 0 ]; then
      tmux display-message "${decision%%$'\n'*}"
    fi
    exit 0
    ;;
  --open-pr)
    key="$2"
    case "$key" in
      ACTION:*|REPO:*|HINT:*|SECTION:*|SESSION:*|'') exit 0 ;;
      *)
        name="${key%%/*}"
        branch="${key#*/}"
        wt="$WORKTREE_ROOT/$name/$branch"
        ( cd "$wt" 2>/dev/null && gh pr view --web 2>/dev/null ) || true
        ;;
    esac
    exit 0
    ;;
  --untrack)
    key="$2"
    case "$key" in
      REPO:*) repo_name="${key#REPO:}" ;;
      ACTION:*|HINT:*|SECTION:*|SESSION:*|'') exit 0 ;;
      *)      repo_name="${key%%/*}" ;;
    esac
    repo=$(resolve_repo_by_name "$repo_name")
    if [ -n "$repo" ]; then
      if core_available; then
        "$CORE_BIN" untrack-project "$repo" >/dev/null
      else
        remove_project "$repo"
      fi
    fi
    exit 0
    ;;
  --add-picker)
    add_picker
    exit 0
    ;;
  --request-delete)
    key="$2"
    kind="$3"
    case "$key" in
      ACTION:*|HINT:*|REPO:*|SECTION:*|SESSION:*|'') exit 0 ;;
    esac
    if [ "$kind" = "primary" ]; then
      tmux display-message "refusing to remove primary checkout: $key"
      exit 0
    fi
    tmux run-shell -b "$SCRIPT_DIR/confirm-delete.sh '$key' '$OUTER_CLIENT'"
    exit 0
    ;;
    --request-new)
    repo="$2"
    if [ -z "$repo" ]; then
      repo=$(pick_project_for_new_worktree)
    fi
    [ -n "$repo" ] && tmux run-shell -b "$SELF --prompt-create '$repo' '$OUTER_CLIENT'"
    exit 0
    ;;
  --header)
    header_for_row "$2" "$3"
    exit 0
    ;;
esac

# ------- main picker ---------------------------------------------------------

set +e
result=$("$SELF" --render | fzf \
  --ansi --reverse --no-sort --print-query \
  --delimiter=$'\t' --with-nth=3,4 --nth=1 \
  --prompt='  ' \
  --header=$'^a add repo  enter switch  ^n new worktree  ^r reload' \
  --expect=enter \
  --bind "ctrl-r:reload($SELF --render)" \
  --bind "focus:transform-header:$SELF --header {2} {7}" \
  --bind "ctrl-a:execute($SELF --add-picker)+reload($SELF --render)" \
  --bind "ctrl-x:execute-silent($SELF --untrack {2})+reload($SELF --render)" \
  --bind "ctrl-d:execute-silent($SELF --request-delete {2} {7})+abort" \
  --bind "ctrl-k:execute-silent($SELF --kill-session {2})+reload($SELF --render)" \
  --bind "ctrl-p:execute-silent($SELF --open-pr {2})+abort" \
  --bind "ctrl-n:execute-silent($SELF --request-new {6})+abort" \
  --color="$(tn_fzf_colors)")
fzf_exit=$?
set -e

# Esc / Ctrl-C from fzf = no-op. Do not create phantom sessions.
[ "$fzf_exit" = 130 ] && exit 0

line1=$(printf '%s\n' "$result" | sed -n '1p')
line2=$(printf '%s\n' "$result" | sed -n '2p')
line3=$(printf '%s\n' "$result" | sed -n '3p')

query="$line1"
if [ "$line2" = "enter" ]; then
  keypress="$line2"
  row="$line3"
else
  keypress=""
  row="$line2"
fi

key=$(printf   '%s\n' "$row" | awk -F'\t' '{print $2}')
path=$(printf  '%s\n' "$row" | awk -F'\t' '{print $5}')
repo=$(printf  '%s\n' "$row" | awk -F'\t' '{print $6}')
kind=$(printf  '%s\n' "$row" | awk -F'\t' '{print $7}')
printf '[%s] expect keypress=%q query=%q key=%q path=%q repo=%q kind=%q\n' \
  "$(date '+%H:%M:%S')" "$keypress" "$query" "$key" "$path" "$repo" "$kind" >> "$LOG_FILE"

[ "$keypress" = "enter" ] || exit 0

if [[ "$query" == :* ]]; then
  plain_name="${query#:}"
  [ -z "$plain_name" ] && exit 0
  open_plain_session "$plain_name"
  exit 0
fi

# No row selected - interpret the typed query.
if [ -z "$row" ]; then
  [ -z "$query" ] && exit 0

  if [[ "$query" == */* ]]; then
    # "repo/branch" - create worktree if repo resolves.
    repo_name="${query%%/*}"
    branch="${query#*/}"
    [ -z "$branch" ] && exit 0
    repo=$(resolve_repo_by_name "$repo_name")
    if [ -n "$repo" ]; then
      ensure_and_attach "$repo" "$branch"
    else
      open_plain_session "$query"
    fi
    exit 0
  fi

  # Single word - try to track it as a project and re-render.
  repo=$(resolve_repo_by_name "$query")
  if [ -n "$repo" ]; then
    add_project "$repo"
    tmux display-message "tracked: $(basename "$repo")"
    exec "$SELF"
  fi

  open_plain_session "$query"
  exit 0
fi

# Row was selected by enter.
case "$key" in
  HINT:*)
    exec "$SELF"
    ;;
  ACTION:new-worktree)
    tmux run-shell -b "$SELF --request-new ''"
    ;;
  SECTION:*)
    exec "$SELF"
    ;;
  REPO:*)
    if [ -n "$repo" ]; then
      primary_branch=$(git -C "$repo" worktree list --porcelain 2>/dev/null | awk -v want="$repo" '
        /^worktree /{wt=$2}
        /^branch refs\/heads\//{
          branch=$0
          sub(/^branch refs\/heads\//, "", branch)
          if (wt == want) { print branch; exit }
        }')
      if [ -n "$primary_branch" ] && core_available; then
        "$CORE_BIN" open-worktree-session "$repo" "$repo" "$primary_branch" "$OUTER_CLIENT" >/dev/null 2>&1 || true
      fi
    fi
    ;;
  SESSION:*)
    if core_available; then
      "$CORE_BIN" open-plain-session "${key#SESSION:}" "$OUTER_CLIENT" >/dev/null 2>&1 || true
    fi
    ;;
  */*)
    session="$key"
    rm -f "$NOTIFY/$session"
    branch="${session#*/}"
    if [ -n "$repo" ] && core_available; then
      "$CORE_BIN" open-worktree-session "$repo" "$path" "$branch" "$OUTER_CLIENT" >/dev/null 2>&1 || true
    fi
    ;;
esac
