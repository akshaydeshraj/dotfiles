#!/usr/bin/env bash
set -euo pipefail

# Ensure brew and tools resolve under launchd's minimal PATH
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
LOG="$HOME/.local/log/dotfiles-diff-check.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

log "Starting diff check..."

/opt/homebrew/bin/claude -p \
  --dangerously-skip-permissions \
  --permission-mode bypassPermissions \
  --model sonnet \
  --max-budget-usd 0.50 \
  --no-session-persistence \
  --allowedTools "Bash Read Write Edit Glob Grep" \
  "You are running as an automated dotfiles sync job in $DOTFILES.

Check for diffs between live config files and the dotfiles repo. Compare these live files against their repo counterparts:

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

ROOT FILES:
- Compare live Brewfile, npm-global-packages.txt, pipx-packages.txt

RULES:
- For .zshrc: NEVER commit hardcoded IPs or BW_SESSION tokens. Keep secrets externalized via \\\$HOME/.env variables (\\\${HETZNER_IP}, \\\${NAS_IP}, etc.)
- Copy the live version into the repo for any diffs found
- Stage changes, commit with a descriptive message, push to origin master
- If no diffs found, just output 'All configs in sync' and exit

Be concise. Do the work silently — only output a summary at the end." \
  >> "$LOG" 2>&1

log "Diff check complete."
