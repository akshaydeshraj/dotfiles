# Cobalt2 Theme — macOS Setup

Replicates the [omarchy-cobalt2-theme](https://github.com/hoblin/omarchy-cobalt2-theme) across macOS tools.

## Color Palette

| Role | Hex |
|------|-----|
| Background | `#122738` |
| Alt Background | `#193549` |
| Foreground | `#ffffff` |
| Accent / Cursor | `#ffc600` |
| Selection BG | `#0050A4` |
| Border (inactive) | `#0d3a58` |
| Red | `#ff628c` |
| Green | `#3ad900` |
| Yellow | `#ffc600` |
| Blue | `#0088ff` |
| Magenta | `#fb94ff` |
| Cyan | `#80fcff` |
| Orange | `#ff9d00` |
| Bright Black | `#0050A4` |

## What's Themed

| Component | Config File | Notes |
|-----------|-------------|-------|
| Ghostty | `~/.config/ghostty/config` | Inline 16-color palette, gold cursor, 85% opacity |
| tmux | `~/.tmux.conf` | Gold active border, blue status bar, Cobalt2 window styles |
| Oh-My-Posh | `~/.config/oh-my-posh/cobalt2.omp.json` | Prompt segments remapped from Solarized |
| btop | `~/.config/btop/themes/cobalt2.theme` | Dropped from upstream repo verbatim |
| Sketchybar | `~/.config/sketchybar/sketchybarrc` | Remapped from Catppuccin Mocha |
| Yabai | `~/.yabairc` | `insert_feedback_color` set to gold |
| JankyBorders | `~/.config/borders/bordersrc` | Gold active border, dark blue inactive |
| fzf | `FZF_DEFAULT_OPTS` in `~/.zshrc` | Full Cobalt2 color scheme |
| zsh-autosuggestions | `ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE` in `~/.zshrc` | Dim blue (`#0050A4`) |
| zsh-syntax-highlighting | `ZSH_HIGHLIGHT_STYLES` in `~/.zshrc` | Green commands, gold strings, pink errors, cyan paths |
| delta (git diff) | `~/.gitconfig` `[delta]` section | Gold filenames, pink/green line numbers, TwoDark syntax |
| eza | `EZA_COLORS` in `~/.zshrc` | Blue dirs, green executables, gold sizes |
| Atuin | `~/.config/atuin/themes/cobalt2.toml` | Custom theme with named colors |
| pgcli | `~/.config/pgcli/config` `[colors]` section | Cobalt2 completion menus and toolbars |
| Zed | `~/.config/zed/settings.json` | Dark mode, "Cobalt2" theme (install from extensions) |
| Obsidian | Vault `.obsidian/snippets/cobalt2.css` | CSS snippet from upstream repo, enable in Settings > Appearance |
| bat | `BAT_THEME` in `~/.zshrc` | TwoDark (closest available built-in) |
| macOS | System Preferences | Dark mode, Yellow accent color |
| Wallpaper | `~/Pictures/cobalt2/` | 3 wallpapers from upstream repo |

## Backups

All original configs backed up to `~/.config-backups/pre-cobalt2/` before changes.

## Reverting

```bash
# Restore all original configs
cp ~/.config-backups/pre-cobalt2/ghostty-config ~/.config/ghostty/config
cp ~/.config-backups/pre-cobalt2/tmux.conf ~/.tmux.conf
cp ~/.config-backups/pre-cobalt2/solarized-dark.omp.json ~/.config/oh-my-posh/
cp ~/.config-backups/pre-cobalt2/sketchybarrc ~/.config/sketchybar/
cp ~/.config-backups/pre-cobalt2/.yabairc ~/

# Remove added files
rm ~/.config/btop/themes/cobalt2.theme
rm ~/.config/oh-my-posh/cobalt2.omp.json
rm ~/.config/borders/bordersrc
rm ~/.config/atuin/themes/cobalt2.toml

# Revert zshrc prompt line to solarized-dark.omp.json
# Revert BAT_THEME to "Dracula"
# Remove FZF_DEFAULT_OPTS, EZA_COLORS, ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE, ZSH_HIGHLIGHT_STYLES

# Restart services
brew services restart sketchybar
brew services stop felixkratz/formulae/borders

# macOS accent color: System Settings > Appearance > Accent color
```

## Not Applicable on macOS

These components from the Omarchy theme are Linux/Wayland only and cannot be ported:

- Hyprland (window manager)
- Hyprlock (screen locker)
- Waybar (status bar — Sketchybar is the macOS equivalent)
- Mako (notifications)
- Walker (app launcher)
- SwayOSD (on-screen display)
- Chromium theme
- Yaru-yellow icon theme
