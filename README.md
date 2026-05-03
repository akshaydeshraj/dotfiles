# dotfiles

macOS dev setup: zsh + yabai + skhd + sketchybar + Ghostty + tmux + Zed

Clone, add secrets, run one script. Uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management.

## Quick Start

```bash
git clone https://github.com/akshaydeshraj/dotfiles ~/Code/personal/dotfiles
cd ~/Code/personal/dotfiles

# Create your secrets file
cp .env.example ~/.env
vim ~/.env  # Fill in real values

# Bootstrap everything
chmod +x install.sh
./install.sh
```

## What's Included

| Package | Configs | Description |
|---------|---------|-------------|
| `zsh` | `.zshrc`, `.zprofile` | Shell config with lazy-loading, modern CLI aliases |
| `git` | `.config/git/ignore` | Global gitignore (git config set by install.sh) |
| `tmux` | `.tmux.conf`, `.config/tmux/` | Terminal multiplexer, fzf session switcher, yazi/lazygit popups |
| `ghostty` | `.config/ghostty/config` | Terminal emulator |
| `wm` | `.yabairc`, `.skhdrc`, `.config/sketchybar/` | Tiling WM + hotkeys + status bar |
| `prompt` | `.config/starship.toml` | Starship prompt (Tokyo Night Storm) |
| `zed` | `.config/zed/settings.json` | Editor (vim mode, Tokyo Night Storm) |
| `mise` | `.config/mise/config.toml` | Runtime manager (Node LTS, Ruby 3) |
| `btop` | `.config/btop/btop.conf` | System monitor |
| `gh` | `.config/gh/config.yml` | GitHub CLI |
| `claude` | `.claude/CLAUDE.md`, `.claude/RTK.md` | Claude Code instructions |
| `doom` | `.config/doom/` | Doom Emacs config (Tokyo Night Storm) |
| `atuin` | `.config/atuin/themes/` | Atuin shell history theme |
| `bat` | `.config/bat/themes/` | bat syntax theme (Tokyo Night Storm tmTheme) |

## Theme

Active theme: **Tokyo Night Storm**. Source-of-truth: [`themes/tokyo-night-storm/palette.sh`](themes/tokyo-night-storm/palette.sh). Full mapping in [`themes/tokyo-night-storm/THEME.md`](themes/tokyo-night-storm/THEME.md). Previous theme (Cobalt2) is archived under [`themes/cobalt2/`](themes/cobalt2/).

## Secrets

All secrets live in `~/.env` (never committed). See `.env.example` for required variables:

- `BW_SESSION` - Bitwarden CLI session token
- `HETZNER_IP` / `NAS_IP` - Remote host IPs for SSH aliases
- `GIT_USER_NAME` / `GIT_USER_EMAIL` - Git identity

## What install.sh Does

1. Validates `~/.env` exists
2. Installs Xcode CLI tools + Homebrew
3. Installs all packages from `Brewfile` (91 formulae, 18 casks)
4. Backs up conflicting dotfiles, then stows all packages
5. Configures git from env vars
6. Applies macOS defaults (Dock, Finder, keyboard, screenshots)
7. Installs mise runtimes (Node, Ruby)
8. Installs global npm + pipx packages (pinned versions)
9. Starts yabai, skhd, sketchybar services
10. Prompts for `gh auth login`

## Manual Steps After Install

- **SIP**: Partially disable for yabai scripting addition
- **Accessibility**: Grant permissions to yabai and skhd (System Settings > Privacy)
- **Spaces**: Create 6 Spaces in Mission Control (browser, terminal, editor, chat, pkm, passwords)
- **Logout**: Some macOS defaults require logout/restart

## Auto-Sync Daemon

A launchd agent runs every 10 minutes to:
- Regenerate `Brewfile`, `npm-global-packages.txt`, `pipx-packages.txt` from system state
- Detect config file changes (via stow symlinks)
- Auto-commit and push to GitHub

```bash
# Check status
launchctl list | grep dotfiles

# View logs
tail -f ~/.local/log/dotfiles-sync.log

# Manually trigger a sync
./sync-daemon.sh

# Stop the daemon
launchctl bootout gui/$(id -u)/com.dotfiles.autosync

# Restart the daemon
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dotfiles.autosync.plist
```

## Updating

```bash
cd ~/Code/personal/dotfiles
git pull
# Re-stow changed packages:
stow --restow --no-folding -t ~ <package>
```

## Adding a New Config

```bash
mkdir newapp
# Mirror the target path inside it:
mkdir -p newapp/.config/newapp
cp ~/.config/newapp/config newapp/.config/newapp/config
# Add to STOW_PACKAGES in install.sh, then:
stow --no-folding -t ~ newapp
```

## tmux Keybinds

- `Alt+K`: fzf session switcher (popup), shows `●` for current session and `🤖` when Claude is waiting
- `Alt+J`: switch to last session
- `Alt+B`: Claude fork overlay (`claude --continue --fork-session`)
- `prefix + e`: toggle yazi file explorer
- `prefix + g`: lazygit popup

A previous Rust-based worktree/workspaces plugin lived at `tmux/plugins/tmux-project-workspaces/`. It was removed in favour of a minimal config; the snapshot is preserved on the `worktree-experiment` git tag.

## Key Design Decisions

- **Stow `--no-folding`**: Creates individual symlinks inside `~/.config/` rather than replacing the directory
- **`wm/` bundles yabai+skhd+sketchybar**: They're tightly coupled (skhd calls yabai, sketchybar reads yabai spaces)
- **Git config not in repo**: Contains email, set by `install.sh` from env vars
- **SSH config excluded**: Contains infrastructure details, managed manually
- **Package versions pinned**: npm and pipx packages have version locks for reproducibility
