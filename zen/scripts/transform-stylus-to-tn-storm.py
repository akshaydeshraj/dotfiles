#!/usr/bin/env python3
"""
Transform a Catppuccin Stylus userstyle export into a Tokyo Night Storm port.

Reads a Stylus JSON export (an array whose first element is `{settings: ...}`
followed by N userstyle entries authored by Catppuccin). Emits a new export
with each style's LESS source rewritten to use the Tokyo Night Storm palette
in place of Catppuccin's.

Mechanism: replaces the single line

    @import "https://userstyles.catppuccin.com/lib/lib.less";

with an inlined Tokyo Night Storm port of that library — same `@catppuccin`
+ `@catppuccin-filters` maps, same `#lib.palette()` / `#lib.defaults()` /
`#lib.rgbify()` / `#lib.hslify()` / `#lib.css-variables()` mixin shapes —
so every `#catppuccin(@flavor)` callsite, every `@catppuccin[X][Y]` map
lookup, and every `var(--ctp-NAME)` reference resolves transparently.

Since TN Storm has no light/dark variants, all four flavor maps point to
the same palette. SVG recoloring filters (`@*-filter`) are stubbed to
`none`; the affected icons render in their source color.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# Mapping from Catppuccin's 26 color slots to Tokyo Night Storm.
#
# Source: github.com/folke/tokyonight.nvim, lua/tokyonight/colors/storm.lua
# (31 named colors). The ANSI-16 subset exported by themes/tokyo-night-storm/
# palette.sh is a strict subset of that, so this mapping uses upstream
# directly to keep the surface/overlay/subtext ladder monotonic and the
# accents canonical.
#
# Catppuccin → TN Storm (canonical name in trailing comment):
TN_PALETTE: dict[str, str] = {
    # Surface ladder (12 monotonic dark→light)
    "crust":    "#1b1e2d",  # bg_dark1
    "mantle":   "#1f2335",  # bg_dark
    "base":     "#24283b",  # bg
    "surface0": "#292e42",  # bg_highlight
    "surface1": "#3b4261",  # fg_gutter
    "surface2": "#394b70",  # blue7
    "overlay0": "#414868",  # terminal_black
    "overlay1": "#545c7e",  # dark3
    "overlay2": "#565f89",  # comment
    "subtext0": "#737aa2",  # dark5
    "subtext1": "#a9b1d6",  # fg_dark
    "text":     "#c0caf5",  # fg

    # Accents (catppuccin's 14 — all canonical TN names; the pink-family
    # slots fold into TN's blue family so the port reads as cool/blue
    # instead of pink/pastel.)
    "rosewater": "#b4f9f8",  # blue6  (palest blue → softest accent)
    "flamingo":  "#0db9d7",  # blue2  (vivid cyan)
    "pink":      "#2ac3de",  # blue1  (saturated cyan-blue replaces pink pop)
    "mauve":     "#bb9af7",  # magenta
    "red":       "#f7768e",  # red
    "maroon":    "#db4b4b",  # red1
    "peach":     "#ff9e64",  # orange
    "yellow":    "#e0af68",  # yellow
    "green":     "#9ece6a",  # green
    "teal":      "#73daca",  # green1 (matches catppuccin's pastel teal)
    "sky":       "#89ddff",  # blue5
    "sapphire":  "#7dcfff",  # cyan
    "blue":      "#7aa2f7",  # blue
    "lavender":  "#9d7cd8",  # purple (semantic: lavender ≈ light purple)
}

_FLAVOR_MAP_BODY = " ".join(f"@{n}: {h};" for n, h in TN_PALETTE.items())
_FILTER_MAP_BODY = " ".join(f"@{n}: none;" for n in TN_PALETTE)


def _palette_assigns(suffix: str = "") -> str:
    """Per-flavor lookups, indented for the `.palette()` mixin body."""
    map_name = "@catppuccin-filters" if suffix else "@catppuccin"
    out_suffix = "-filter" if suffix else ""
    lines = [
        f"    @{name}{out_suffix}: {map_name}[@@flavor][@{name}];"
        for name in TN_PALETTE
    ]
    lines.append(
        f"    @accent{out_suffix}: {map_name}[@@flavor][@@accentColor];"
    )
    return "\n".join(lines)


def _css_var_assigns() -> str:
    return "\n".join(f"    --ctp-{name}: @{name};" for name in TN_PALETTE)


# Inline replacement for the original `@import` URL. Mirrors the upstream
# library's public interface so all existing call sites work unchanged.
TN_STORM_LIB = f"""\
// Tokyo Night Storm port of userstyles.catppuccin.com/lib/lib.less.
// All four flavors resolve to the same TN Storm palette; light/dark
// distinctions in the original are collapsed to dark only.
@catppuccin: {{
  @latte:     {{ {_FLAVOR_MAP_BODY} }};
  @frappe:    {{ {_FLAVOR_MAP_BODY} }};
  @macchiato: {{ {_FLAVOR_MAP_BODY} }};
  @mocha:     {{ {_FLAVOR_MAP_BODY} }};
}};

@catppuccin-filters: {{
  @latte:     {{ {_FILTER_MAP_BODY} }};
  @frappe:    {{ {_FILTER_MAP_BODY} }};
  @macchiato: {{ {_FILTER_MAP_BODY} }};
  @mocha:     {{ {_FILTER_MAP_BODY} }};
}};

#lib {{
  .palette() {{
{_palette_assigns()}

{_palette_assigns("filter")}
  }}

  .defaults() {{
    color-scheme: dark;

    ::selection {{
      background-color: fade(@accent, 30%);
    }}

    input,
    textarea {{
      &::placeholder {{
        color: @subtext0 !important;
      }}
    }}
  }}

  .rgbify(@color) {{
    @rgb: red(@color), green(@color), blue(@color);
  }}

  .hslify(@color) {{
    @raw: e(
      %("%s, %s%, %s%", hue(@color), saturation(@color), lightness(@color))
    );
  }}

  .css-variables() {{
{_css_var_assigns()}
    --ctp-accent: @accent;
  }}
}}
"""

CATPPUCCIN_IMPORT_RE = re.compile(
    r'^\s*@import\s+"https://userstyles\.catppuccin\.com/lib/lib\.less";\s*$',
    re.MULTILINE,
)


def transform_source(src: str) -> str:
    src = CATPPUCCIN_IMPORT_RE.sub(TN_STORM_LIB, src, count=1)

    # Metadata renames in the userstyle header.
    src = re.sub(r'^(@name\s+.+?)\s+Catppuccin\s*$',
                 r'\1 Tokyo Night Storm', src, flags=re.MULTILINE)
    src = re.sub(r'^@author\s+Catppuccin\s*$',
                 '@author Tokyo Night Storm port (akshay@skit.ai)', src,
                 flags=re.MULTILINE)
    src = re.sub(r'^@description\s+Soothing pastel theme for (.+)$',
                 r'@description Tokyo Night Storm theme for \1', src,
                 flags=re.MULTILINE)
    # Drop @updateURL — local port, no upstream to track.
    src = re.sub(r'^@updateURL\s+.+\n?', '', src, flags=re.MULTILINE)

    # Switch the default accentColor from mauve to blue. Catppuccin styles
    # mark `mauve:Mauve*` as default; the `*` is what Stylus reads. In TN
    # Storm that lands on magenta (#bb9af7), which leaks pink-purple into
    # every highlight/selection/focus surface across all 134 styles.
    # Move the asterisk to `blue:Blue` so highlights default to TN blue.
    src = src.replace('"mauve:Mauve*"', '"mauve:Mauve"')
    src = src.replace('"blue:Blue"', '"blue:Blue*"')

    return src


def transform_usercss_data(data: dict) -> dict:
    if isinstance(data.get("name"), str):
        data["name"] = data["name"].replace(" Catppuccin", " Tokyo Night Storm")
    if data.get("author") == "Catppuccin":
        data["author"] = "Tokyo Night Storm port (akshay@skit.ai)"
    if isinstance(data.get("description"), str):
        data["description"] = data["description"].replace(
            "Soothing pastel theme", "Tokyo Night Storm theme"
        )
    data.pop("updateURL", None)
    # Mirror the source-code accentColor default flip (mauve → blue) so
    # Stylus's import path picks up the new default without re-parsing.
    accent = data.get("vars", {}).get("accentColor")
    if isinstance(accent, dict) and accent.get("default") == "mauve":
        accent["default"] = "blue"
    return data


def transform_entry(entry: dict) -> dict:
    new = dict(entry)
    if isinstance(new.get("sourceCode"), str):
        new["sourceCode"] = transform_source(new["sourceCode"])
    if isinstance(new.get("name"), str):
        new["name"] = new["name"].replace(" Catppuccin", " Tokyo Night Storm")
    if new.get("author") == "Catppuccin":
        new["author"] = "Tokyo Night Storm port (akshay@skit.ai)"
    if isinstance(new.get("description"), str):
        new["description"] = new["description"].replace(
            "Soothing pastel theme", "Tokyo Night Storm theme"
        )
    if "usercssData" in new:
        new["usercssData"] = transform_usercss_data(dict(new["usercssData"]))
    # Force Stylus to recompute digest on import (source content changed).
    new.pop("originalDigest", None)
    new.pop("updateUrl", None)
    return new


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: transform-stylus-to-tn-storm.py INPUT.json OUTPUT.json",
              file=sys.stderr)
        return 2
    in_path, out_path = Path(argv[1]), Path(argv[2])
    payload = json.loads(in_path.read_text())
    if not isinstance(payload, list):
        print("error: expected top-level JSON array", file=sys.stderr)
        return 1

    out: list = []
    transformed = 0
    for entry in payload:
        if isinstance(entry, dict) and "settings" in entry and "sourceCode" not in entry:
            out.append(entry)
            continue
        if isinstance(entry, dict) and "sourceCode" in entry:
            out.append(transform_entry(entry))
            transformed += 1
        else:
            out.append(entry)

    out_path.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
    print(f"transformed {transformed} styles → {out_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
