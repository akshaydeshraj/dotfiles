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

# ===== Appearance (Cobalt2) =====
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"          # Dark mode
defaults write NSGlobalDomain AppleAccentColor -int 3                     # Yellow accent
defaults write NSGlobalDomain AppleHighlightColor -string "0.847059 0.847059 0.862745 Yellow"
# Wallpaper — Cobalt2 (set first wallpaper from the collection)
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
WALLPAPER="$DOTFILES_DIR/wallpapers/02_a_car_driving_on_a_road_at_night.png"
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
