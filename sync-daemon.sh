#!/usr/bin/env bash
set -euo pipefail

# ── PATH setup for launchd's minimal environment ──
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

log "=== Sync started ==="

# ── Phase 1: Regenerate package lists (fast, no AI needed) ──
brew bundle dump --force --file="$DOTFILES/Brewfile" --describe >> "$LOG" 2>&1 || log "brew bundle dump failed"

npm list -g --depth=0 --json 2>>"$LOG" | \
  jq -r '.dependencies | to_entries[] | "\(.key)@\(.value.version)"' \
  > "$DOTFILES/npm-global-packages.txt" || log "npm list failed"

pipx list --json 2>>"$LOG" | \
  jq -r '.venvs | to_entries[] | "\(.key)==\(.value.metadata.main_package.package_version)"' \
  > "$DOTFILES/pipx-packages.txt" || log "pipx list failed"

# ── Phase 2: Pull remote changes ──
cd "$DOTFILES"
git stash --quiet >> "$LOG" 2>&1 || true
git pull --rebase origin master >> "$LOG" 2>&1 || {
  log "Rebase failed — aborting rebase and restoring stash"
  git rebase --abort >> "$LOG" 2>&1 || true
  git stash pop --quiet >> "$LOG" 2>&1 || true
  exit 0
}
if ! git stash pop --quiet >> "$LOG" 2>&1; then
  log "Stash pop conflict — resetting to HEAD"
  git reset --hard HEAD >> "$LOG" 2>&1
fi

# ── Phase 3: Claude diff check — compare live configs vs repo ──
CLAUDE_BIN=$(command -v claude 2>/dev/null || echo "")
if [[ -z "$CLAUDE_BIN" ]]; then
  log "claude CLI not found — skipping diff check, falling back to package-only sync"
  ALLOWLIST=(Brewfile npm-global-packages.txt pipx-packages.txt)
  git add "${ALLOWLIST[@]}" 2>/dev/null || true
  if ! git diff --cached --quiet; then
    CHANGED=$(git diff --cached --name-only | tr '\n' ', ' | sed 's/,$//')
    git commit -m "auto-sync: $CHANGED"
    git push origin master >> "$LOG" 2>&1 && log "Pushed: $CHANGED" || log "Push failed"
  else
    log "No changes"
  fi
  log "=== Sync complete (fallback) ==="
  exit 0
fi

log "Running Claude diff check..."

cat <<'PROMPT' | "$CLAUDE_BIN" -p \
  --dangerously-skip-permissions \
  --permission-mode bypassPermissions \
  --model sonnet \
  --max-budget-usd 0.50 \
  --no-session-persistence \
  --allowedTools "Bash Read Write Edit Glob Grep" \
  >> "$LOG" 2>&1
You are running as an automated dotfiles sync job. The repo is in the current working directory.

PHASE 1 (already done for you): Brewfile, npm-global-packages.txt, and pipx-packages.txt have been regenerated. git pull --rebase has been done.

PHASE 2 (your job): Check for diffs between live config files and the repo. Compare:

STOW PACKAGES:
- ~/.zshrc and ~/.zprofile vs zsh/
- ~/.tmux.conf and ~/.config/tmux/ vs tmux/
- ~/.config/ghostty/config vs ghostty/
- ~/.config/zed/settings.json vs zed/
- ~/.config/btop/btop.conf and ~/.config/btop/themes/ vs btop/
- ~/.yabairc and ~/.skhdrc and ~/.config/sketchybar/ and ~/.config/borders/ vs wm/
- ~/.config/oh-my-posh/ vs prompt/
- ~/.config/mise/config.toml vs mise/
- ~/.config/gh/config.yml vs gh/
- ~/.config/atuin/themes/ vs atuin/

ALSO CHECK:
- Any changes to Brewfile, npm-global-packages.txt, pipx-packages.txt (regenerated above)
- install.sh, macos-defaults.sh, sync-daemon.sh

RULES:
- For .zshrc: NEVER commit hardcoded IPs or BW_SESSION tokens. Keep secrets externalized via $HOME/.env variables (${HETZNER_IP}, ${NAS_IP}, etc.). If the live file has hardcoded secrets, replace them with env vars before copying.
- Copy the live version into the repo for any diffs found
- Stage all changes, commit with a descriptive message, push to origin master
- If no diffs found, just output 'All configs in sync' and exit

Be concise. Do the work silently — only output a summary at the end.
PROMPT

log "=== Sync complete ==="
