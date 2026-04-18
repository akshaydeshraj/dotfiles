#!/bin/bash
# Unified Cmd+K: tree view of CURATED projects + their worktrees.
#
# Behaviour:
# - Only projects listed in PROJECTS_FILE render (curated, not auto-discovered).
# - Typing an unknown name that matches a zoxide-known repo → adds it, re-renders.
# - Typing "<repo>/<branch>" → creates a worktree (auto-tracks the repo).
# - Pressing Esc with text in the prompt → closes cleanly (no ghost session).
#
# Keys inside fzf:
#   enter  go            ^a add project (pick from zoxide)
#   ^n     new worktree  ^x untrack project (keep worktree on disk)
#   ^d     delete worktree+session+branch
#   ^k     kill session only
#   ^p     open PR for row    ^r refresh

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

NOTIFY="$HOME/.cache/claude-notify"
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/worktrees}"
PROJECTS_FILE="${PROJECTS_FILE:-$HOME/.config/tmux/projects.txt}"
SELF="$0"

# Outer tmux client that invoked us (popup dispatches don't reach it unless -t targets it).
OUTER_CLIENT="${OUTER_CLIENT:-$(tmux list-clients -F '#{client_tty}' 2>/dev/null | head -1)}"
export OUTER_CLIENT

mkdir -p "$(dirname "$PROJECTS_FILE")"
touch "$PROJECTS_FILE"

CURRENT=$(tmux display-message -p '#S' 2>/dev/null || true)

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
resolve_repo_by_name() {
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
untracked_candidates() {
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

# ------- rendering -----------------------------------------------------------

render() {
  local projects
  projects=$(list_projects)

  if [ -z "$projects" ]; then
    printf 'HINT:\t\033[90m(no projects yet — type a repo name + enter to add, or ^a to pick)\033[0m\t\t\n'
    return 0
  fi

  printf '%s\n' "$projects" | awk '!seen[$0]++' | sort -f | while read -r repo; do
    name=$(basename "$repo")

    rows=$(git -C "$repo" worktree list --porcelain 2>/dev/null | awk '
      /^worktree /{wt=$2}
      /^branch /{sub("refs/heads/","",$2); print wt"\t"$2}
    ')

    if [ -z "$rows" ]; then
      printf '%s\t\033[90m▸ %s\033[0m\t\t%s\n' "REPO:$name" "$name" "$repo"
      continue
    fi

    printf '%s\t\033[1;33m▾ %s\033[0m\t\t%s\n' "REPO:$name" "$name" "$repo"

    echo "$rows" | while IFS=$'\t' read -r wt_path branch; do
      [ -z "$wt_path" ] && continue
      session="$name/$branch"
      m=""
      [ "$session" = "$CURRENT" ] && m="$m ●"
      [ -f "$NOTIFY/$session" ] && m="$m 🤖"
      [ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null | head -1)" ] && m="$m ◆"
      live="·"
      tmux has-session -t "$session" 2>/dev/null && live=" "
      age=$(git -C "$wt_path" log -1 --format='%cr' 2>/dev/null)
      printf '%s\t    \033[36m%-36s\033[0m\t\033[90m%s %s %s\033[0m\t%s\n' \
        "$session" "$session" "$live" "$m" "$age" "$wt_path"
    done

    printf 'NEW:%s\t    \033[32m+ new worktree in %s\033[0m\t\t%s\n' "$name" "$name" "$repo"
  done
}

# Sub-picker: show every zoxide repo not yet tracked; selected → add + re-render.
add_picker() {
  local cands pick
  cands=$(untracked_candidates)
  [ -z "$cands" ] && { tmux display-message "no untracked git repos found via zoxide"; return 0; }
  pick=$(printf '%s\n' "$cands" | fzf \
    --reverse --prompt='add ❯ ' \
    --header='pick a repo to track (Esc to cancel)' \
    --color=bg+:#0050A4,fg+:#ffffff,hl:#ffc600,hl+:#ffc600,pointer:#ffc600,prompt:#0088ff) || return 0
  [ -n "$pick" ] && add_project "$pick"
}

# ------- session / worktree lifecycle ----------------------------------------

create_session() {
  local session="$1" wt_path="$2" branch="$3" repo="$4"

  if [ -x "$repo/.worktree-init.sh" ]; then
    ( cd "$wt_path" && \
      TMUX_SESSION="$session" WORKTREE_PATH="$wt_path" BRANCH="$branch" REPO_ROOT="$repo" \
      "$repo/.worktree-init.sh" ) || true
  fi

  tmux new-session -ds "$session" -c "$wt_path" -n work
  tmux new-window -t "$session:" -n git -c "$wt_path" lazygit
  tmux new-window -t "$session:" -n free -c "$wt_path"
  tmux select-window -t "$session:work"
}

ensure_and_attach() {
  local repo="$1" branch="$2"
  local name wt
  name=$(basename "$repo")
  wt="$WORKTREE_ROOT/$name/$branch"
  mkdir -p "$(dirname "$wt")"
  if ! git -C "$repo" worktree list --porcelain | awk '/^worktree /{print $2}' | grep -qx "$wt"; then
    git -C "$repo" worktree add -b "$branch" "$wt" 2>/dev/null \
      || git -C "$repo" worktree add "$wt" "$branch" 2>/dev/null \
      || git -C "$repo" worktree add "$wt"
  fi
  add_project "$repo"
  local session="$name/$branch"
  if ! tmux has-session -t "$session" 2>/dev/null; then
    create_session "$session" "$wt" "$branch" "$repo"
  fi
  rm -f "$NOTIFY/$session"
  tmux switch-client -t "$session"
}

prompt_branch_and_create() {
  local repo="$1"
  local name
  name=$(basename "$repo")
  add_project "$repo"
  # Dispatch to the outer client so the prompt survives the popup closing.
  tmux command-prompt -t "$OUTER_CLIENT" -p "new branch in $name:" \
    "run-shell \"$SELF --create '$repo' '%1'\" ; switch-client -c '$OUTER_CLIENT' -t \"$name/%1\""
}

# ------- subcommand dispatch -------------------------------------------------

case "${1:-}" in
  --render)
    render
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
  --delete)
    key="$2"
    case "$key" in
      REPO:*|NEW:*|HINT:*|'') exit 0 ;;
      */*)
        # Stash the pending delete and let fzf close first. Main loop picks it up.
        printf '%s\n' "$key" > "$HOME/.cache/tree-switcher-pending-delete"
        ;;
    esac
    exit 0
    ;;
  --kill-session)
    key="$2"
    case "$key" in
      REPO:*|NEW:*|HINT:*|'') exit 0 ;;
      *) tmux kill-session -t "$key" 2>/dev/null || true ;;
    esac
    exit 0
    ;;
  --open-pr)
    key="$2"
    case "$key" in
      REPO:*|NEW:*|HINT:*|'') exit 0 ;;
      *)
        name="${key%%/*}"
        branch="${key#*/}"
        wt="$WORKTREE_ROOT/$name/$branch"
        ( cd "$wt" 2>/dev/null && gh pr view --web 2>/dev/null ) || true
        ;;
    esac
    exit 0
    ;;
  --new-here)
    key="$2"
    case "$key" in
      REPO:*|NEW:*) repo_name="${key#*:}" ;;
      HINT:*|'')    exit 0 ;;
      *)            repo_name="${key%%/*}" ;;
    esac
    repo=$(resolve_repo_by_name "$repo_name")
    [ -n "$repo" ] && prompt_branch_and_create "$repo"
    exit 0
    ;;
  --untrack)
    key="$2"
    case "$key" in
      REPO:*) repo_name="${key#REPO:}" ;;
      NEW:*)  repo_name="${key#NEW:}" ;;
      HINT:*|'') exit 0 ;;
      *)      repo_name="${key%%/*}" ;;
    esac
    repo=$(resolve_repo_by_name "$repo_name")
    [ -n "$repo" ] && remove_project "$repo"
    exit 0
    ;;
  --add-picker)
    add_picker
    exit 0
    ;;
esac

# ------- main picker ---------------------------------------------------------

set +e
result=$("$SELF" --render | fzf \
  --ansi --reverse --no-sort --print-query \
  --delimiter=$'\t' --with-nth=2,3 --nth=1,2 \
  --prompt='  ' \
  --header='enter: go  ^a add repo  ^x untrack  ^n new worktree  ^d delete  ^k kill  ^p PR  ^r reload' \
  --bind "ctrl-r:reload($SELF --render)" \
  --bind "ctrl-a:execute($SELF --add-picker)+reload($SELF --render)" \
  --bind "ctrl-x:execute-silent($SELF --untrack {1})+reload($SELF --render)" \
  --bind "ctrl-d:execute($SELF --delete {1})+abort" \
  --bind "ctrl-k:execute-silent($SELF --kill-session {1})+reload($SELF --render)" \
  --bind "ctrl-p:execute-silent($SELF --open-pr {1})" \
  --bind "ctrl-n:execute($SELF --new-here {1})+abort" \
  --color=bg+:#0050A4,fg+:#ffffff,hl:#ffc600,hl+:#ffc600,pointer:#ffc600,prompt:#0088ff)
fzf_exit=$?
set -e

# Pending delete written by ^d binding — schedule confirm-before on the tmux server
# so it survives this popup closing. run-shell -b returns immediately.
PENDING="$HOME/.cache/tree-switcher-pending-delete"
if [ -s "$PENDING" ]; then
  pending=$(head -1 "$PENDING")
  rm -f "$PENDING"
  if [ -n "$pending" ]; then
    tmux run-shell -b "$HOME/.config/tmux/confirm-delete.sh '$pending' '$OUTER_CLIENT'"
  fi
fi

# Esc / Ctrl-C from fzf = no-op. Do not create phantom sessions.
[ "$fzf_exit" = 130 ] && exit 0

query=$(printf '%s\n' "$result" | sed -n '1p')
row=$(printf   '%s\n' "$result" | sed -n '2p')
key=$(printf   '%s\n' "$row" | awk -F'\t' '{print $1}')
path=$(printf  '%s\n' "$row" | awk -F'\t' '{print $4}')

# No row selected — interpret the typed query.
if [ -z "$row" ]; then
  [ -z "$query" ] && exit 0

  if [[ "$query" == */* ]]; then
    # "repo/branch" — create worktree if repo resolves.
    repo_name="${query%%/*}"
    branch="${query#*/}"
    [ -z "$branch" ] && exit 0
    repo=$(resolve_repo_by_name "$repo_name")
    [ -z "$repo" ] && { tmux display-message "unknown repo: $repo_name  (type the name alone first to track it)"; exit 0; }
    ensure_and_attach "$repo" "$branch"
    exit 0
  fi

  # Single word — try to track it as a project and re-render.
  repo=$(resolve_repo_by_name "$query")
  if [ -n "$repo" ]; then
    add_project "$repo"
    tmux display-message "tracked: $(basename "$repo")"
    exec "$SELF"
  fi

  tmux display-message "no git repo named '$query' in zoxide — cd into it once to register, or ^a to pick"
  exit 0
fi

# Row was selected by enter.
case "$key" in
  HINT:*)
    exec "$SELF"
    ;;
  REPO:*)
    repo_name="${key#REPO:}"
    repo=$(resolve_repo_by_name "$repo_name")
    [ -n "$repo" ] && prompt_branch_and_create "$repo"
    ;;
  NEW:*)
    repo_name="${key#NEW:}"
    repo=$(resolve_repo_by_name "$repo_name")
    [ -n "$repo" ] && prompt_branch_and_create "$repo"
    ;;
  */*)
    session="$key"
    rm -f "$NOTIFY/$session"
    if tmux has-session -t "$session" 2>/dev/null; then
      tmux switch-client -t "$session"
    else
      repo_name="${session%%/*}"
      branch="${session#*/}"
      repo=$(resolve_repo_by_name "$repo_name")
      if [ -n "$repo" ]; then
        create_session "$session" "$path" "$branch" "$repo"
      else
        tmux new-session -dAs "$session" -c "$path"
      fi
      tmux switch-client -t "$session"
    fi
    ;;
esac
