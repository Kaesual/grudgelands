#!/usr/bin/env python3
"""Round 34 lane F2 art: original 16x16 pixel art drawn from the character
grids below; no imported image assets. Deterministic CC0 art like the other
grug_map marker icons (tools/r26_map/render_steward_icon.py).

* grug_map_crownbinder.png -- the Crownbinder's map marker: a gold crown over
  a dark anvil;
* grug_map_decor_merchant.png -- the Decor Merchant's map marker: a hanging
  lantern;
* grug_money_bag_of_coins.png -- the Bag of Coins item: a tied leather purse
  with gold coins at its foot.

Usage: python3 tools/r34_f2/render_icons.py [--check]
  --check  exit 1 when a shipped PNG differs from the grids.
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUTLINE = (25, 21, 15, 255)

CROWNBINDER = [
    "................",
    "..o....o....o...",
    ".oGo..oGo..oGo..",
    ".oggooogggooggo.",
    ".oggggggggggggo.",
    ".ogrggGgggrgggo.",
    ".oggggggggggggo.",
    "..oooooooooooo..",
    "................",
    ".ooooooooooooo..",
    "oAaaaaaaaaaaaao.",
    ".oooaaaaaaaooo..",
    "....oaaaaao.....",
    "...oaaaaaaao....",
    "..ooooooooooo...",
    "................",
]
CROWNBINDER_PALETTE = {
    "o": OUTLINE,
    "g": (232, 184, 58, 255),    # crown gold
    "G": (255, 228, 124, 255),   # gold highlight
    "r": (190, 40, 52, 255),     # ruby
    "a": (92, 96, 104, 255),     # anvil iron
    "A": (150, 156, 166, 255),   # anvil highlight
}

DECOR_MERCHANT = [
    ".......oo.......",
    "......o..o......",
    ".......oo.......",
    ".....oooooo.....",
    "....obbbbbbo....",
    "...oooooooooo...",
    "...obyyyyyybo...",
    "...obyYYYYybo...",
    "...obyYwwYybo...",
    "...obyYwwYybo...",
    "...obyYYYYybo...",
    "...obyyyyyybo...",
    "...oooooooooo...",
    "....obbbbbbo....",
    ".....oooooo.....",
    "................",
]
DECOR_MERCHANT_PALETTE = {
    "o": OUTLINE,
    "b": (112, 72, 38, 255),     # dark wood frame
    "y": (236, 160, 54, 255),    # warm glass
    "Y": (255, 206, 96, 255),    # bright glass
    "w": (255, 246, 214, 255),   # flame core
}

BAG_OF_COINS = [
    "................",
    ".......oo.......",
    "......oLLo......",
    ".......oo.......",
    "......orro......",
    ".....obbbbo.....",
    "....obbBbbbo....",
    "...obbBbbbbbo...",
    "..obbBbbbbbbbo..",
    "..obbbbbbbbbbo..",
    "..obbbbbbbbdbo..",
    "..obbbbbbbdbbo..",
    "...obbbbbbbbo...",
    "..ogGooooooogGo.",
    ".ogGgo...ogGgGo.",
    "..ooo.....ooooo.",
]
BAG_OF_COINS_PALETTE = {
    "o": OUTLINE,
    "b": (138, 92, 50, 255),     # leather
    "B": (176, 124, 72, 255),    # leather highlight
    "d": (104, 66, 34, 255),     # seam
    "r": (196, 160, 88, 255),    # drawstring
    "L": (214, 182, 106, 255),   # string loop
    "g": (232, 184, 58, 255),    # coin gold
    "G": (255, 228, 124, 255),   # coin highlight
}

ICONS = [
    ("mods/PLAYER/grug_map/textures/grug_map_crownbinder.png", CROWNBINDER,
     CROWNBINDER_PALETTE),
    ("mods/PLAYER/grug_map/textures/grug_map_decor_merchant.png", DECOR_MERCHANT,
     DECOR_MERCHANT_PALETTE),
    ("mods/PLAYER/grug_money/textures/grug_money_bag_of_coins.png", BAG_OF_COINS,
     BAG_OF_COINS_PALETTE),
]


def render(grid, palette):
    assert len(grid) == 16 and all(len(row) == 16 for row in grid), grid
    image = Image.new("RGBA", (16, 16))
    px = image.load()
    for y, row in enumerate(grid):
        for x, cell in enumerate(row):
            px[x, y] = (0, 0, 0, 0) if cell == "." else palette[cell]
    return image


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    for path, grid, palette in ICONS:
        out = ROOT / path
        image = render(grid, palette)
        if check:
            if not out.exists() or \
                    Image.open(out).convert("RGBA").tobytes() != image.tobytes():
                stale.append(path)
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        image.save(out, optimize=True)
        print(path)
    if check:
        print("R34 F2 ICONS " + ("STALE: " + ", ".join(stale) if stale else "CURRENT"))
        sys.exit(1 if stale else 0)


if __name__ == "__main__":
    main()
