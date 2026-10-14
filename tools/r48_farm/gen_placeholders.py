#!/usr/bin/env python3
"""Round 48 lane FARM: placeholder PNGs under the plant art plan's target names.

The plant art plan (docs/planning/plant-art-plan.md §6 and §7) fixes the file
names the final art replaces; lane FARM wires them in the game with these
placeholders, renders of today's images: the texture-modifier composites the
items show today baked into files (the engine's [colorize:<colour>:<ratio>,
imagesource.cpp apply_colorize), Pumpkin stages tinted for Melon and Cave Cap
stages tinted for Mushroom. The art lane's final step overwrites the PNGs and
their ledger rows; from then on this script is obsolete and --check reports
the replaced files.

  python3 -I tools/r48_farm/gen_placeholders.py           write the PNGs
  python3 -I tools/r48_farm/gen_placeholders.py --check   exit 1 when one differs

Standard library only; the PNG decoder is tools/r44_mb/gen_baked_art.py's.
"""
import argparse
import importlib.util
import os
import struct
import sys
import zlib

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT = "mods/BASE/default/textures/"
FARM = "mods/ITEMS/grug_farming/textures/"
GATHER = "mods/ITEMS/grug_gathering/textures/"

# target: (source, colorize colour or None, ratio, frame height or None)
MELON = "#61a94e"      # today's Melon item tint (gathering catalog)
MUSHROOM = "#9b7653"   # today's Mushroom item tint
TARGETS = {}
for stage in range(1, 5):
    TARGETS[FARM + "grug_farming_melon_%d.png" % stage] = (
        FARM + "grug_farming_pumpkin_%d.png" % stage, MELON, 95, None)
    TARGETS[FARM + "grug_farming_mushroom_%d.png" % stage] = (
        FARM + "grug_farming_cave_cap_%d.png" % stage, MUSHROOM, 80, None)
TARGETS.update({
    FARM + "grug_farming_melon_seeds.png": (FARM + "grug_farming_seed_melon.png", None, 0, None),
    FARM + "grug_farming_mushroom_spores.png": (
        FARM + "grug_farming_seed_beetroot.png", "#c8b49a", 90, None),
    FARM + "grug_farming_seed_cassava.png": (
        FARM + "grug_farming_seed_potato.png", "#d8b27a", 32, None),
    FARM + "grug_farming_salt_pan.png": (FARM + "grug_farming_salt_crust_4.png", None, 0, 16),
    GATHER + "grug_gathering_melon.png": (DEFAULT + "default_apple.png", MELON, 95, None),
    GATHER + "grug_gathering_mushroom.png": (
        DEFAULT + "default_pine_bush_sapling.png", MUSHROOM, 150, None),
})
# Sunleaf, Gravemoss and Wild Cocoa: the item icon and the source's world
# sprite, both today's composite until the art pick splits them.
for key, source, colour, ratio in (
        ("sunleaf", "default_grass_3.png", "#e5d34a", 105),
        ("gravemoss", "default_fern_1.png", "#526c45", 100),
        ("wild_cocoa", "default_pine_bush_sapling.png", "#70452d", 175)):
    for suffix in ("", "_plant"):
        TARGETS[GATHER + "grug_gathering_%s%s.png" % (key, suffix)] = (
            DEFAULT + source, colour, ratio, None)


def load_decoder():
    path = os.path.join(REPO, "tools", "r44_mb", "gen_baked_art.py")
    spec = importlib.util.spec_from_file_location("gen_baked_art", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.decode_png


def colorize(rows, colour, ratio):
    """The engine's interpolating [colorize: every pixel with alpha > 0 moves
    `ratio`/255 of the way to the colour (alpha included, colour alpha 255)."""
    cr, cg, cb = (int(colour[i:i + 2], 16) for i in (1, 3, 5))
    d = ratio / 255.0
    inv = 1.0 - d

    def mix(a, b):
        return int(round(a * inv + b * d))

    out = []
    for row in rows:
        out.append([(mix(r, cr), mix(g, cg), mix(b, cb), mix(a, 255)) if a > 0 else (r, g, b, a)
                    for (r, g, b, a) in row])
    return out


def encode(width, height, rows):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)

    raw = bytearray()
    for row in rows:
        raw.append(0)
        for pixel in row:
            raw.extend(pixel)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def render(decode, source, colour, ratio, frame):
    with open(os.path.join(REPO, source), "rb") as handle:
        width, height, rows = decode(handle.read())
    if frame:
        rows, height = rows[:frame], frame
    if colour:
        rows = colorize(rows, colour, ratio)
    return encode(width, height, rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    decode = load_decoder()
    stale = []
    for target in sorted(TARGETS):
        data = render(decode, *TARGETS[target])
        path = os.path.join(REPO, target)
        if args.check:
            current = open(path, "rb").read() if os.path.exists(path) else None
            if current != data:
                stale.append(target)
        else:
            with open(path, "wb") as handle:
                handle.write(data)
    if args.check:
        for target in stale:
            print("differs from its placeholder: " + target)
        print("%d placeholders, %d differ" % (len(TARGETS), len(stale)))
        return 1 if stale else 0
    print("wrote %d placeholders" % len(TARGETS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
