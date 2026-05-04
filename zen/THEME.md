# Zen Browser — Tokyo Night Storm

Palette source-of-truth: [`themes/tokyo-night-storm/palette.sh`](../themes/tokyo-night-storm/palette.sh).

## Layout

```
zen/
├── chrome/
│   ├── userChrome.css     # browser frame (sidebar, tabs, urlbar, menus)
│   └── userContent.css    # about:newtab / about:home / about:blank
├── link-profile.sh        # symlinks chrome/ into every Zen profile
└── THEME.md               # this file
```

The chrome dir is **not stowed** and we **copy**, not symlink:

- Zen profile paths look like `~/Library/Application Support/zen/Profiles/d7qo0bal.Default (release)/` — the random ID changes on reinstall, so `link-profile.sh` discovers profiles via `profiles.ini`.
- Zen runs in macOS seatbelt sandbox (`-sbStartup` in process args). The sandbox **does not follow symlinks** outside the profile container, so symlinked `userChrome.css` silently fails to load. We copy instead.
- The auto-sync daemon (`sync-daemon.sh`, runs every 10 min) re-runs the helper, so edits to `zen/chrome/*.css` in the dotfiles propagate automatically. You can also run it on-demand.

`install.sh` runs the helper automatically; you can also run it ad-hoc:

```bash
bash zen/link-profile.sh
```

The script also writes
`user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);`
to each profile's `user.js`, which is required for `userChrome.css` to load.

After the first link, **restart Zen** for the CSS to take effect.

## Per-workspace accents

Workspace UUIDs are hardwired into `userChrome.css`:

| Workspace | UUID | Accent |
|-----------|------|--------|
| Work | `{84c43e1f-a011-43ff-b812-9902759e4d37}` | TN magenta `#bb9af7` |
| Personal | `{54313d76-7b8c-4a60-9172-8859ac2524ee}` | TN blue `#7aa2f7` |

Switching workspaces re-tints the URL focus ring and the active-tab line.
No Zen UI step required — the CSS reads `zen-workspace-id` / `zen-workspace-active`
attributes that Zen sets on the document root.

### If you delete or recreate a workspace

Zen issues a fresh UUID. Capture the new ones from `zen-sessions.jsonlz4`
(LZ4-compressed; needs Python `lz4`) and update the two `:root[zen-workspace-active="..."]`
selectors at the bottom of `chrome/userChrome.css`:

```bash
python3 -c '
import lz4.block, struct, json, sys
p = "$HOME/Library/Application Support/zen/Profiles/<your-profile>/zen-sessions.jsonlz4"
with open(p, "rb") as f: d = f.read()
n = struct.unpack("<I", d[8:12])[0]
obj = json.loads(lz4.block.decompress(d[12:], uncompressed_size=n))
for s in obj["spaces"]:
    print(s["name"], s["uuid"])
'
```

(`pip3 install --user --break-system-packages lz4` if not installed.)

## Verifying

After restarting Zen:

- Sidebar / urlbar / tabs all on `#24283b` (TN bg).
- URL bar focus ring: TN magenta in Work, TN blue in Personal.
- New tab page (about:newtab) on TN bg with TN fg text.
- Tab close-button hover: TN red.

If chrome doesn't load:

- Confirm `toolkit.legacyUserProfileCustomizations.stylesheets = true` in
  `about:config`.
- Confirm symlinks resolve:
  `ls -la "$HOME/Library/Application Support/zen/Profiles/<profile>/chrome/"`.
- Re-run `bash zen/link-profile.sh`.
