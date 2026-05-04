#!/usr/bin/env python3
"""Rewrite Zen workspace gradient themes to TN colors + zero opacity.

WHY: Zen renders each workspace's stored gradient theme as a translucent
overlay across the whole window chrome. That overlay paints OVER our
userChrome.css colors, so the TN palette is invisible inside a workspace
(it shows correctly in incognito, which has no workspace).

WHAT: This script reads `<profile>/zen-sessions.jsonlz4` (mozLz40-wrapped
LZ4 block), sets the primary gradient color of each known workspace to a
Tokyo Night accent (Work=magenta, Personal=blue), and forces opacity=0 so
the overlay is invisible. Zen still surfaces `--zen-primary-color` per
workspace from the primary gradient stop, which our userChrome.css uses to
tint the URL focus ring and active tab line.

REQUIREMENTS: Zen must be FULLY QUIT (⌘Q) before running. Zen overwrites
zen-sessions.jsonlz4 on shutdown and during tab activity.

  pip3 install --user --break-system-packages lz4
  python3 zen/clear-workspace-themes.py

Backups (.bak) are left next to each rewritten file.
"""

from __future__ import annotations

import json
import shutil
import struct
import subprocess
import sys
from configparser import RawConfigParser
from pathlib import Path

import lz4.block

ZEN_DIR = Path.home() / "Library" / "Application Support" / "zen"

WORKSPACE_ACCENTS = {
    "{84c43e1f-a011-43ff-b812-9902759e4d37}": (187, 154, 247),  # Work    — TN magenta #bb9af7
    "{54313d76-7b8c-4a60-9172-8859ac2524ee}": (122, 162, 247),  # Personal — TN blue    #7aa2f7
}

MOZ_MAGIC = b"mozLz40\0"


def is_zen_running() -> bool:
    try:
        result = subprocess.run(
            ["pgrep", "-fl", "/Applications/Zen.app"],
            capture_output=True, text=True, check=False,
        )
        return any("/Applications/Zen.app" in line for line in result.stdout.splitlines())
    except FileNotFoundError:
        return False


def read_mozlz4(path: Path) -> dict:
    raw = path.read_bytes()
    if raw[:8] != MOZ_MAGIC:
        raise ValueError(f"{path} is not a mozLz4 file")
    uncomp_size = struct.unpack("<I", raw[8:12])[0]
    decompressed = lz4.block.decompress(raw[12:], uncompressed_size=uncomp_size)
    return json.loads(decompressed.decode("utf-8"))


def write_mozlz4(path: Path, obj: dict) -> None:
    payload = json.dumps(obj, separators=(",", ":")).encode("utf-8")
    # store_size=False: mozLz4 carries the uncompressed size in its own
    # 4-byte header; if we leave the lz4 default we'd write the size twice
    # and the resulting file fails to decode.
    compressed = lz4.block.compress(payload, mode="default", store_size=False)
    path.write_bytes(MOZ_MAGIC + struct.pack("<I", len(payload)) + compressed)


def discover_profiles() -> list[Path]:
    ini = ZEN_DIR / "profiles.ini"
    if not ini.exists():
        return []
    cp = RawConfigParser()
    cp.read(ini)
    paths: list[Path] = []
    for section in cp.sections():
        if not section.startswith("Profile"):
            continue
        rel = cp.get(section, "Path", fallback=None)
        if rel:
            paths.append(ZEN_DIR / rel)
    return paths


def patch_workspaces(obj: dict) -> int:
    """Mutate `obj` in place. Return number of workspaces modified."""
    spaces = obj.get("spaces") or []
    changed = 0
    for space in spaces:
        uuid = space.get("uuid")
        if uuid not in WORKSPACE_ACCENTS:
            continue
        primary_rgb = list(WORKSPACE_ACCENTS[uuid])
        theme = space.get("theme") or {}
        if theme.get("type") != "gradient":
            # Skip non-gradient themes (e.g. user already cleared it)
            continue
        for color in theme.get("gradientColors") or []:
            if color.get("isPrimary"):
                color["c"] = primary_rgb
        # Kill the visual overlay; keep the primary color so Zen still
        # populates --zen-primary-color from it.
        theme["opacity"] = 0
        space["theme"] = theme
        changed += 1
    return changed


def main() -> int:
    if is_zen_running():
        print("ERROR: Zen is running. Fully quit (⌘Q) before running this script.")
        return 1

    profiles = discover_profiles()
    if not profiles:
        print(f"No Zen profiles discovered under {ZEN_DIR}")
        return 0

    total = 0
    for profile in profiles:
        sessions = profile / "zen-sessions.jsonlz4"
        if not sessions.exists():
            print(f"  Skipping {profile.name}: no zen-sessions.jsonlz4")
            continue
        try:
            obj = read_mozlz4(sessions)
        except Exception as exc:
            print(f"  Skipping {profile.name}: failed to decode ({exc})")
            continue
        changed = patch_workspaces(obj)
        if changed == 0:
            print(f"  No workspaces matched in {profile.name} (already cleared?)")
            continue

        backup = sessions.with_suffix(sessions.suffix + ".bak")
        if not backup.exists():
            shutil.copy2(sessions, backup)
        write_mozlz4(sessions, obj)
        print(f"  Rewrote {changed} workspace theme(s) in {profile.name}")
        total += changed

    if total == 0:
        print("Nothing to do.")
    else:
        print(f"Done — {total} workspace theme(s) rewritten across {len(profiles)} profile(s).")
        print("Launch Zen to see TN bg + per-workspace accent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
