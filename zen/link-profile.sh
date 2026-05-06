#!/usr/bin/env bash
# Sync Tokyo Night Storm chrome files into every Zen browser profile.
#
# Why a script instead of stow:
#   Zen profile dirs have generated IDs ("d7qo0bal.Default (release)") and
#   live under "~/Library/Application Support/zen/" (with a space).
#
# Why copies (not symlinks):
#   Zen runs in macOS seatbelt sandbox (-sbStartup). Symlinks pointing
#   outside the profile container are NOT followed, so userChrome.css
#   doesn't load. Copies sidestep the sandbox entirely.
#
# Idempotent: cmp-checks each file and only copies on change.
# Re-run after editing the source CSS, or let sync-daemon.sh do it.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ZEN_DIR="$HOME/Library/Application Support/zen"
CHROME_SRC="$DOTFILES_DIR/zen/chrome"

if [[ ! -d "$ZEN_DIR" ]]; then
  echo "Zen browser data dir not found at: $ZEN_DIR"
  echo "Skipping (install Zen first, run it once to create a profile, then re-run)."
  exit 0
fi

if [[ ! -f "$ZEN_DIR/profiles.ini" ]]; then
  echo "No profiles.ini in $ZEN_DIR — nothing to link."
  exit 0
fi

mapfile -t PROFILE_PATHS < <(awk -F= '/^Path=/ {print $2}' "$ZEN_DIR/profiles.ini")

if [[ ${#PROFILE_PATHS[@]} -eq 0 ]]; then
  echo "No profiles found in profiles.ini."
  exit 0
fi

sync_one() {
  local target="$1"   # absolute path of file to create / replace
  local source="$2"   # absolute path inside dotfiles
  # If the target is a stale symlink from previous installs, remove it.
  if [[ -L "$target" ]]; then
    rm -f "$target"
  fi
  # Skip if identical.
  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    return 0
  fi
  if [[ -e "$target" && ! -L "$target" ]] && ! cmp -s "$source" "$target"; then
    local backup="${target}.pre-tn-storm.$(date +%s)"
    cp "$target" "$backup"
    echo "    backed up existing $(basename "$target") → $(basename "$backup")"
  fi
  cp "$source" "$target"
  return 1
}

CHANGED=0
for rel in "${PROFILE_PATHS[@]}"; do
  profile_dir="$ZEN_DIR/$rel"
  if [[ ! -d "$profile_dir" ]]; then
    echo "  Skipping missing profile: $rel"
    continue
  fi
  mkdir -p "$profile_dir/chrome"
  before=$CHANGED
  sync_one "$profile_dir/chrome/userChrome.css"  "$CHROME_SRC/userChrome.css"  || CHANGED=$((CHANGED + 1))
  sync_one "$profile_dir/chrome/userContent.css" "$CHROME_SRC/userContent.css" || CHANGED=$((CHANGED + 1))
  if (( CHANGED > before )); then
    echo "  Synced chrome -> $rel"
  fi

  # Ensure prefs needed for userChrome.css + Browser Console.
  # - legacyUserProfileCustomizations: required on older Zen, harmless on new
  # - devtools.chrome.enabled: lets Cmd+Shift+J open Browser Console
  # - devtools.debugger.remote-enabled: lets you inspect chrome:// in devtools
  user_js="$profile_dir/user.js"
  for flag in \
    'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' \
    'user_pref("devtools.chrome.enabled", true);' \
    'user_pref("devtools.debugger.remote-enabled", true);' ; do
    if [[ ! -f "$user_js" ]] || ! grep -Fq "$flag" "$user_js"; then
      printf '%s\n' "$flag" >> "$user_js"
    fi
  done
done

if (( CHANGED == 0 )); then
  echo "Zen chrome already in sync."
else
  echo "Done. Restart Zen (⌘Q + relaunch) to pick up the theme."
fi
