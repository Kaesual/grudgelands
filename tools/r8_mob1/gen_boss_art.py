#!/usr/bin/env python3
"""Generate the Round-8 royal skins and Fallen Crown icon.

The six base skins are original CC0 Grudgelands art.  This generator adds a
race-coloured tabard and a gold crown on the same classic 64x32 UV layout;
the Crown item is original pixel art.  Outputs are deterministic CC0 assets.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "mods/PLAYER/grug_visuals/textures"
OUT = ROOT / "mods/ENTITIES/grug_mobs/textures"

RACES = {
    "dwarf": ((78, 116, 164, 255), (210, 226, 244, 255)),
    "human": ((48, 88, 170, 255), (226, 236, 255, 255)),
    "elf": ((70, 132, 104, 255), (224, 242, 214, 255)),
    "undead": ((92, 64, 122, 255), (216, 196, 234, 255)),
    "orc": ((154, 48, 42, 255), (248, 202, 96, 255)),
    "troll": ((34, 118, 142, 255), (204, 238, 236, 255)),
}


def royal_skin(race, colours):
    image = Image.open(BASE / ("grug_visuals_skin_%s.png" % race)).convert("RGBA")
    px = image.load()
    cloth, trim = colours
    dark = tuple(max(0, channel * 3 // 4) for channel in cloth[:3]) + (255,)
    gold = (232, 184, 58, 255)
    gold_dark = (150, 104, 28, 255)
    gem = (116, 220, 238, 255)

    # Torso tabard: front/back centre panels, belt and race-coloured trim.
    for x0 in (22, 34):
        for y in range(20, 32):
            for x in range(x0, x0 + 4):
                px[x, y] = cloth if y < 29 else dark
    for x in range(20, 40):
        px[x, 27] = trim
    px[23, 23] = gold
    px[24, 24] = gold
    px[25, 23] = gold

    # Crown on the hat layer: a full circlet plus four raised points.  Every
    # head face gets pixels, so it reads from front, back and either side.
    for x0 in (32, 40, 48, 56):
        for x in range(x0, x0 + 8):
            px[x, 11] = gold_dark
            px[x, 12] = gold
        for dx in (0, 3, 7):
            px[x0 + dx, 9] = gold
            px[x0 + dx, 10] = gold
    for x in range(40, 48):
        for y in range(5, 8):
            px[x, y] = gold if (x + y) % 2 == 0 else gold_dark
    px[43, 11] = gem
    px[44, 11] = gem
    return image


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
    for race in sorted(RACES):
        path = OUT / ("grug_mobs_royal_%s.png" % race)
        royal_skin(race, RACES[race]).save(path, optimize=True)
        print(path.relative_to(ROOT))
    path = OUT / "grug_mobs_item_fallen_crown.png"
    fallen_crown().save(path, optimize=True)
    print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
