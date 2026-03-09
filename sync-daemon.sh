#!/usr/bin/env bash
set -euo pipefail

# Ensure brew/npm/pipx/jq/git resolve under launchd's minimal PATH
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
LOG="$HOME/.local/log/dotfiles-sync.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# Only sync allowlisted files
ALLOWLIST=(
  Brewfile
  npm-global-packages.txt
  pipx-packages.txt
  zsh/ git/ tmux/ ghostty/ wm/ prompt/ zed/ mise/ btop/ gh/ claude/ atuin/
)

# Regenerate Brewfile (taps + leaves + casks + mas)
brew bundle dump --force --file="$DOTFILES/Brewfile" --describe >> "$LOG" 2>&1 || log "brew bundle dump failed"

# Regenerate npm global packages
npm list -g --depth=0 --json 2>>"$LOG" | \
  jq -r '.dependencies | to_entries[] | "\(.key)@\(.value.version)"' \
  > "$DOTFILES/npm-global-packages.txt" || log "npm list failed"

# Regenerate pipx packages
pipx list --json 2>>"$LOG" | \
  jq -r '.venvs | to_entries[] | "\(.key)==\(.value.metadata.main_package.package_version)"' \
  > "$DOTFILES/pipx-packages.txt" || log "pipx list failed"

# Pull remote changes first — stash local changes to avoid dirty-tree rejection
cd "$DOTFILES"
git stash --quiet >> "$LOG" 2>&1 || true
git pull --rebase origin master >> "$LOG" 2>&1 || {
  log "Rebase failed — aborting rebase and restoring stash"
  git rebase --abort >> "$LOG" 2>&1 || true
  git stash pop --quiet >> "$LOG" 2>&1 || true
  exit 0
}
if ! git stash pop --quiet >> "$LOG" 2>&1; then
  log "Stash pop conflict — resetting to HEAD (regenerated files will be recreated)"
  git reset --hard HEAD >> "$LOG" 2>&1
fi

# Stage only allowlisted paths
git add "${ALLOWLIST[@]}"

if ! git diff --cached --quiet; then
  CHANGED=$(git diff --cached --name-only | tr '\n' ', ' | sed 's/,$//')
  git commit -m "auto-sync: $CHANGED"
  git push origin master >> "$LOG" 2>&1 && log "Pushed: $CHANGED" || log "Push failed"
else
  log "No changes"
fi
