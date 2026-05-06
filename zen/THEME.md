# Zen Browser - Tokyo Night Storm

Palette source-of-truth: [`themes/tokyo-night-storm/palette.sh`](../themes/tokyo-night-storm/palette.sh).

## Current State

This is a verified `userChrome.css` loading baseline, not the final theme.
It applies a small Tokyo Night Storm surface set and a thin blue URL border.

The baseline is intentionally narrow:

- `chrome/userChrome.css` loads in both Zen profiles.
- Core toolbar/sidebar surfaces use TN Storm background `#24283b`.
- URL bar uses `#1f2335` with a `1px` TN blue border.
- `chrome/userContent.css` themes about pages.
- No Zen Mods path is used.
- No workspace session rewriting is used.

## Sync

Manual sync:

```bash
bash zen/link-profile.sh
```

The autosync daemon only syncs Zen when `DOTFILES_SYNC_ZEN=1` is set.

## Next Steps

Build the final theme incrementally from this checkpoint. Test one visible
surface at a time before committing more rules.
