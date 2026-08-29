#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
STOW_PACKAGES=(zsh git tmux ghostty wm prompt zed cursor mise btop gh claude atuin arc doom bat nvim)
FAILURES=()

echo "=== Dotfiles Bootstrap ==="
echo ""

# ── Step 1: Check for .env ──
if [[ ! -f "$HOME/.env" ]]; then
  echo "ERROR: ~/.env not found."
  echo ""
  echo "  cp $DOTFILES_DIR/.env.example ~/.env"
  echo "  # Then edit ~/.env with your real values"
  echo ""
  exit 1
fi
chmod 600 "$HOME/.env"
source "$HOME/.env"

# ── Step 2: Xcode CLI Tools ──
if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Press Enter after installation completes."
  read -r
fi

# ── Step 3: Homebrew ──
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ── Step 4: Brew packages ──
echo "Installing brew packages..."
brew bundle --file="$DOTFILES_DIR/Brewfile" --no-lock

# Remove the window manager and hotkey daemon that AeroSpace replaces.
for legacy_wm in yabai skhd; do
  brew services stop "$legacy_wm" 2>/dev/null || true
  if brew list --formula "$legacy_wm" &>/dev/null; then
    brew uninstall "$legacy_wm"
  fi
done

# Remove links created by older versions of the wm stow package.
for legacy_config in .yabairc .skhdrc; do
  legacy_path="$HOME/$legacy_config"
  if [[ -L "$legacy_path" && "$(readlink "$legacy_path")" == *"/dotfiles/wm/$legacy_config" ]]; then
    rm -f "$legacy_path"
  fi
done

# ── Step 5: Stow dotfiles ──
echo "Stowing dotfiles..."
if ! command -v stow &>/dev/null; then
  brew install stow
fi

mkdir -p "$BACKUP_DIR"
for pkg in "${STOW_PACKAGES[@]}"; do
  # Dry-run to detect conflicts
  conflicts=$(stow --no-folding --dir="$DOTFILES_DIR" --target="$HOME" --simulate "$pkg" 2>&1 || true)
  if echo "$conflicts" | grep -q "CONFLICT"; then
    echo "  Backing up conflicts for $pkg..."
    echo "$conflicts" | grep "CONFLICT" | while read -r line; do
      file=$(echo "$line" | sed 's/.*CONFLICT: //' | sed 's/ .*//')
      if [[ -f "$HOME/$file" ]]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        mv "$HOME/$file" "$BACKUP_DIR/$file"
      fi
    done
  fi
  echo "  Stowing $pkg..."
  stow --no-folding --dir="$DOTFILES_DIR" --target="$HOME" "$pkg"
done

# ── Step 5a: Link Zen browser chrome ──
# Zen profile paths embed a random ID and contain spaces, so we don't stow.
# The helper script discovers profiles via profiles.ini and symlinks chrome/.
if [[ -d "$HOME/Library/Application Support/zen" ]]; then
  echo "Linking Zen browser chrome (Tokyo Night Storm)..."
  bash "$DOTFILES_DIR/zen/link-profile.sh" || FAILURES+=("zen link-profile")
fi

# ── Step 5b: Build bat theme cache ──
# bat reads tmThemes from ~/.config/bat/themes/ but only after `cache --build`.
# Stowing puts the symlink there; this step registers it so BAT_THEME works.
if command -v bat &>/dev/null; then
  echo "Building bat theme cache..."
  bat cache --build >/dev/null 2>&1 || FAILURES+=("bat cache --build")
fi

# ── Step 5c: Git hooks ──
echo "Configuring git hooks..."
git -C "$DOTFILES_DIR" config core.hooksPath "$DOTFILES_DIR/hooks"

# ── Step 6: Git config ──
echo "Configuring git..."
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global init.defaultBranch master
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global delta.syntax-theme TwoDark
git config --global delta.minus-style "syntax #3a1528"
git config --global delta.minus-emph-style "syntax #6b2038"
git config --global delta.plus-style "syntax #1a3a1a"
git config --global delta.plus-emph-style "syntax #2a5a2a"
# Tokyo Night Storm — palette source-of-truth: themes/tokyo-night-storm/palette.sh
git config --global delta.line-numbers-minus-style "#f7768e"
git config --global delta.line-numbers-plus-style "#9ece6a"
git config --global delta.line-numbers-zero-style "#414868"
git config --global delta.hunk-header-style "file line-number syntax"
git config --global delta.hunk-header-decoration-style "blue box"
git config --global delta.file-style "#e0af68 bold"
git config --global delta.file-decoration-style "#e0af68 ul"
git config --global merge.conflictstyle diff3
git config --global credential.https://github.com.helper ""
git config --global credential.https://github.com.helper "!/opt/homebrew/bin/gh auth git-credential"
git config --global credential.https://gist.github.com.helper ""
git config --global credential.https://gist.github.com.helper "!/opt/homebrew/bin/gh auth git-credential"

# ── Step 7: macOS defaults ──
echo "Applying macOS defaults..."
bash "$DOTFILES_DIR/macos-defaults.sh"

# ── Step 8: Directories ──
mkdir -p "$HOME/.zsh/cache"
mkdir -p "$HOME/Desktop/Screenshots"

# ── Step 9: mise runtimes ──
if command -v mise &>/dev/null; then
  echo "Installing mise runtimes..."
  mise install --yes || true
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  echo "Installing mise runtimes..."
  "$HOME/.local/bin/mise" install --yes || true
else
  echo "Installing mise..."
  curl https://mise.run | sh
  "$HOME/.local/bin/mise" install --yes || true
fi

# ── Step 10: Global npm packages ──
echo "Installing global npm packages..."
while IFS= read -r pkg; do
  [[ -z "$pkg" || "$pkg" == \#* ]] && continue
  echo "  npm install -g $pkg"
  npm install -g "$pkg" || FAILURES+=("npm: $pkg")
done < "$DOTFILES_DIR/npm-global-packages.txt"

# ── Step 11: pipx packages ──
echo "Installing pipx packages..."
while IFS= read -r pkg; do
  [[ -z "$pkg" || "$pkg" == \#* ]] && continue
  echo "  pipx install $pkg"
  pipx install "$pkg" || FAILURES+=("pipx: $pkg")
done < "$DOTFILES_DIR/pipx-packages.txt"

# ── Step 12: Services ──
echo "Starting services..."
open -a AeroSpace 2>/dev/null || true
brew services start sketchybar 2>/dev/null || true
brew services start borders 2>/dev/null || true

# ── Step 13: Auto-sync daemon ──
echo "Setting up dotfiles auto-sync daemon..."
mkdir -p "$HOME/.local/log"
PLIST_SRC="$DOTFILES_DIR/launchd/com.dotfiles.autosync.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.dotfiles.autosync.plist"
mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s|__DOTFILES_DIR__|$DOTFILES_DIR|g" -e "s|__HOME__|$HOME|g" \
  "$PLIST_SRC" > "$PLIST_DST"
launchctl bootout "gui/$(id -u)/com.dotfiles.autosync" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
echo "  Auto-sync daemon started (runs every 4 hours)"
# Clean up legacy diff-check daemon if present
launchctl bootout "gui/$(id -u)/com.dotfiles.diffcheck" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.dotfiles.diffcheck.plist"

# ── Step 14: GitHub auth ──
if ! gh auth status &>/dev/null 2>&1; then
  echo ""
  echo "Authenticate with GitHub:"
  gh auth login
fi

# ── Summary ──
echo ""
echo "=== Bootstrap complete! ==="

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "The following packages failed to install:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
fi

if [[ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
  echo ""
  echo "Backed up conflicting files to: $BACKUP_DIR"
fi

echo ""
echo "Manual steps remaining:"
echo "  1. Re-enable SIP if you disabled it for the previous window manager"
echo "  2. Grant Accessibility permission to AeroSpace"
echo "  3. Keep one native macOS Space per display"
echo "  4. Log out and back in for macOS defaults to take full effect"
