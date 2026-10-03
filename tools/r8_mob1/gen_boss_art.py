#!/usr/bin/env python3
"""Generate the Round-8 Fallen Crown icon: original 16x16 pixel art, a
deterministic CC0 asset. (The royal skins it once made are drawn from the
character look layers since Round 31: tools/wp13/gen_character_visuals.py.)
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "mods/ENTITIES/grug_mobs/textures"


def fallen_crown():
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = image.load()
    gold = (226, 174, 46, 255)
    light = (255, 222, 104, 255)
    dark = (126, 82, 22, 255)
    ruby = (184, 40, 48, 255)
    for x in range(3, 13):
        for y in range(8, 13):
            px[x, y] = gold
    for x in range(4, 12):
        px[x, 12] = dark
    for x, top in ((3, 4), (6, 2), (9, 3), (12, 4)):
        for y in range(top, 9):
            px[x, y] = gold
        if x + 1 < 13:
            px[x + 1, top + 2] = light
    for x in range(4, 12):
        px[x, 8] = light
    px[6, 10] = ruby
    px[9, 10] = ruby
    return image


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "grug_mobs_item_fallen_crown.png"
    fallen_crown().save(path, optimize=True)
    print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
