#!/usr/bin/env python3
"""Generate deterministic crownless royal-guard skins from project CC0 art."""

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


def guard_skin(race, colours):
    image = Image.open(BASE / ("grug_visuals_skin_%s.png" % race)).convert("RGBA")
    pixels = image.load()
    cloth, trim = colours
    dark = tuple(max(0, channel * 3 // 4) for channel in cloth[:3]) + (255,)
    gold = (232, 184, 58, 255)

    for x0 in (22, 34):
        for y in range(20, 32):
            for x in range(x0, x0 + 4):
                pixels[x, y] = cloth if y < 29 else dark
    for x in range(20, 40):
        pixels[x, 27] = trim
    pixels[23, 23] = gold
    pixels[24, 24] = gold
    pixels[25, 23] = gold
    return image


def main():
    for race in sorted(RACES):
        path = OUT / ("grug_mobs_royal_guard_%s.png" % race)
        guard_skin(race, RACES[race]).save(path, optimize=True)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
