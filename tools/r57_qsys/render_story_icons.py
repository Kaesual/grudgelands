#!/usr/bin/env python3
"""Round 57 lane QSYS: the story quest markers of the map window and the
minimap (ruling 13), a simple variant of the Round 27 quest icons
(tools/r27_minimap/render_icons.py, whose badge and glyphs it reuses).

* grug_map_quest_story_{available,locked,ready,active}.png -- 16x16 pixel
  art: the same "!" (available, locked) or "?" (ready, active) on the round
  dark badge, the glyph in the story violet (bright when the quest can be
  taken or handed in, muted otherwise, as the gold and grey of the plain
  icons) and the badge's rim in violet, so a story giver reads apart from a
  side quest's at 16 px while its status stays visible on its own.

The 3D marker over a giver uses the same two violets as fills
(grug_quests/npc.lua MARKERS) and needs no file.

Original, deterministic, no imported assets (CC0-1.0 like the other
grug_map marker icons, mods/PLAYER/grug_map/LICENSE-media.md).

Usage: python3 tools/r57_qsys/render_story_icons.py [--check]
"""
import importlib.util
import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "mods/PLAYER/grug_map/textures"

_spec = importlib.util.spec_from_file_location("r27_icons", ROOT / "tools/r27_minimap/render_icons.py")
R27 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(R27)

VIOLET, VIOLET_LIGHT = (180, 107, 255, 255), (222, 190, 255, 255)
MUTED, MUTED_LIGHT = (169, 155, 196, 255), (214, 206, 228, 255)
RIM = (120, 64, 196, 255)


def story(glyph, fill, light):
    """The plain icon's grid, its badge rim ("o") in the story violet."""
    palette = {"o": RIM, "b": (43, 33, 24, 235), "k": R27.OUTLINE, "g": fill, "G": light}
    grid = []
    for base_row, glyph_row in zip(R27.BADGE, glyph):
        grid.append("".join(g if g != "." else b for b, g in zip(base_row, glyph_row)))
    return R27.pixel_icon(grid, palette)


def icons():
    return {
        "grug_map_quest_story_available.png": story(R27.EXCLAIM, VIOLET, VIOLET_LIGHT),
        "grug_map_quest_story_locked.png": story(R27.EXCLAIM, MUTED, MUTED_LIGHT),
        "grug_map_quest_story_ready.png": story(R27.QUESTION, VIOLET, VIOLET_LIGHT),
        "grug_map_quest_story_active.png": story(R27.QUESTION, MUTED, MUTED_LIGHT),
    }


def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def main(argv):
    raise SystemExit("Retired runtime exporter; use tools/r64_map/ship.py --check")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
