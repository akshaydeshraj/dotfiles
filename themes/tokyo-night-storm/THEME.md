# Tokyo Night Storm — macOS Setup

Replicates the [Tokyo Night Storm](https://github.com/folke/tokyonight.nvim) palette across the entire dev/desktop stack. Replaces the previous Cobalt2 setup (archived under `themes/cobalt2/`).

## Color Palette

| Role | Hex | 0xARGB |
|------|-----|--------|
| Background | `#24283b` | `0xff24283b` |
| Foreground | `#c0caf5` | `0xffc0caf5` |
| Accent (yellow / gold) | `#e0af68` | `0xffe0af68` |
| Selection BG | `#2e3c64` | `0xff2e3c64` |
| Border / dim | `#414868` | `0xff414868` |
| Red | `#f7768e` | `0xfff7768e` |
| Green | `#9ece6a` | `0xff9ece6a` |
| Yellow | `#e0af68` | `0xffe0af68` |
| Blue | `#7aa2f7` | `0xff7aa2f7` |
| Magenta | `#bb9af7` | `0xffbb9af7` |
| Cyan | `#7dcfff` | `0xff7dcfff` |
| Orange | `#ff9e64` | `0xffff9e64` |

Source-of-truth: `palette.sh` in this directory.

## What's Themed

| Component | Config File | Notes |
|-----------|-------------|-------|
| Ghostty | `~/.config/ghostty/config` | Inline 16-color palette, opacity 85%. See `ghostty-palette` snippet here for raw values. |
| tmux | `~/.tmux.conf` | Status bar, pane borders, popup borders |
| tmux project workspaces | `tmux/plugins/tmux-project-workspaces/scripts/*.sh` + `tmux-project-workspaces.tmux` | fzf color strings via sourced palette.sh |
| Starship prompt | `~/.config/starship.toml` | Native `[palettes.tokyo_night_storm]` directive |
| Doom Emacs | `~/.config/doom/config.el` | Built-in `doom-tokyo-night` theme (no custom file) |
| btop | `~/.config/btop/themes/tokyo-night-storm.theme` | Activated via `color_theme` in `btop.conf` |
| Atuin | `~/.config/atuin/themes/tokyo-night-storm.toml` | **Activation requires** `[theme] name = "tokyo-night-storm"` in `~/.config/atuin/config.toml` (config.toml is not tracked in dotfiles — has session token) |
| Sketchybar | `~/.config/sketchybar/sketchybarrc` + `plugins/space.sh` + `plugins/wifi.sh` + `plugins/tailscale.sh` | All bar colors, space indicators, status icons |
| JankyBorders | `~/.config/borders/bordersrc` | Yellow active, gray-blue inactive |
| Yabai | `~/.yabairc` | `insert_feedback_color` set to TN yellow |
| Zed | `~/.config/zed/settings.json` | "Tokyo Night Storm" theme (built-in) |
| fzf | `FZF_DEFAULT_OPTS` in `~/.zshrc` | Sourced from `palette.sh` via `tn_fzf_colors` helper |
| zsh-autosuggestions | `~/.zshrc` | `$TN_DIM` (gray-blue) |
| zsh-syntax-highlighting | `~/.zshrc` | Green commands, yellow strings, red errors, cyan paths |
| eza | `EZA_COLORS` in `~/.zshrc` | ANSI codes — colors map to TN via terminal palette |
| bat | `bat/.config/bat/themes/tokyo-night-storm.tmTheme` + `BAT_THEME=tokyo-night-storm` in `~/.zshrc` | Hand-rolled tmTheme matching this palette. After edits run `bat cache --build`. |
| Obsidian | (user-installed) | Community "Tokyo Night" theme — install from settings |

## Reference-Based Design

`palette.sh` is the single source of truth:

- **Shell-side** sources it (zshrc, tmux plugin scripts) and uses `$TN_*` vars.
- **Starship** uses TOML's native `[palettes.tokyo_night_storm]` directive — same colors, named cleanly.
- **App-side** configs (Doom, Atuin, ghostty, tmux conf, btop, sketchybar, borders, yabai, zed) hardcode hex values with a comment at the top of each file linking back to `palette.sh`. None of these tools support importing external palettes.

To tweak the theme: edit `palette.sh` first, then propagate hex changes to app-side files.

## Activation Notes

### Atuin

The atuin theme **does not auto-activate**. Add to `~/.config/atuin/config.toml`:

```toml
[theme]
name = "tokyo-night-storm"
```

(This file is not tracked in dotfiles because it contains the sync session token.)

### Doom Emacs

After pulling, run:
```bash
~/.config/emacs/bin/doom sync
```
Then restart Emacs. The `doom-tokyo-night` theme ships with `doom-themes` (already a dependency).

### Starship

Replaces oh-my-posh. After zshrc reload, the new prompt should appear immediately.

### bat

The TN Storm tmTheme is stowed from this repo into `~/.config/bat/themes/`. After install or any edit to the tmTheme, rebuild bat's theme cache:

```bash
bat cache --build
```

### Obsidian

User-managed. Install the community "Tokyo Night" theme:
- Settings → Appearance → Themes → Manage → search "Tokyo Night" → install → enable.

## Reverting to Cobalt2

All Cobalt2 standalone files are preserved in `themes/cobalt2/`. To revert:
1. `cp themes/cobalt2/doom-cobalt2-theme.el doom/.config/doom/themes/`
2. Set `doom-theme` back to `'doom-cobalt2` in `doom/config.el`
3. `cp themes/cobalt2/cobalt2.toml atuin/.config/atuin/themes/`
4. `cp themes/cobalt2/cobalt2.omp.json prompt/.config/oh-my-posh/`
5. `cp themes/cobalt2/cobalt2.theme btop/.config/btop/themes/`
6. Manually revert inline hex changes in: zshrc, .tmux.conf, ghostty config, sketchybarrc, bordersrc, yabairc, btop.conf, zed settings, tmux plugin scripts.

(Inline reverts are tedious — git revert on the retheme commit is cleaner.)

## Files in this directory

- `palette.sh` — shell exports (source-of-truth)
- `ghostty-palette` — raw Ghostty palette dump (reference)
- `THEME.md` — this file
