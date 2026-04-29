#!/usr/bin/env bash
set -euo pipefail

echo "Configuring macOS defaults..."

# ===== Dock =====
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.3
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false          # Don't rearrange Spaces (critical for yabai)
defaults write com.apple.dock minimize-to-application -bool true

# ===== Mission Control =====
defaults write com.apple.dock expose-animation-duration -float 0.1

# ===== Finder =====
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"  # Search current folder
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# ===== Input =====
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false   # Key repeat instead of accents
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# ===== Screenshots =====
mkdir -p "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# ===== Appearance (Tokyo Night Storm) =====
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"          # Dark mode
# AppleAccentColor enum: -1=Multicolor 0=Graphite 1=Red 2=Orange 3=Yellow
# 4=Green 5=Blue 6=Purple 7=Pink. Blue matches TN Storm's primary accent #7aa2f7.
defaults write NSGlobalDomain AppleAccentColor -int 5
defaults write NSGlobalDomain AppleHighlightColor -string "0.698039 0.843137 1.000000 Blue"
# Wallpaper — Tokyo Night Storm. Palette-derived, reproducible via wallpapers/generate.sh.
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
WALLPAPER="$DOTFILES_DIR/wallpapers/01_tokyo-night-storm-glow.png"
if [[ -f "$WALLPAPER" ]]; then
  osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER\"" 2>/dev/null || true
fi

# ===== Window Management =====
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g NSWindowShouldDragOnGesture YES

# ===== Trackpad =====
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool true

# ===== Restart affected apps =====
for app in "Dock" "Finder" "SystemUIServer"; do
  killall "$app" &>/dev/null || true
done

echo "macOS defaults applied. Some changes require logout/restart."
