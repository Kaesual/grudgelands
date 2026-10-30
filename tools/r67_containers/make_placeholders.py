#!/usr/bin/env python3
"""Round 67 lane CONTAINERS: the placeholder textures of the container tiers.

The Steel-Reinforced and Abyssal chests, locked chests, bookshelves and
vessels shelves (default/containers.lua) use their own textures under their
final names; until the art lane's pick replaces the files, each is the wooden
original tinted (a steel grey and a dark violet over its luminance). The
wooden tier keeps the vendored files. Derived from minetest_game media
(CC BY-SA 3.0, mods/BASE/default/license.txt), so the placeholders are
CC BY-SA 3.0 too.

    python3 tools/r67_containers/make_placeholders.py [--check]

--check exits 1 when a written file differs from what the script makes (or
when the art lane's file replaced a placeholder: then this script is retired
for that file and --check is no longer a gate).
"""

import io
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DEFAULT = ROOT / "mods/BASE/default/textures"
VESSELS = ROOT / "mods/BASE/vessels/textures"

# tier suffix -> RGB tint multiplied over the luminance (0..255 each), and a
# lift so dark wood does not turn black.
TINTS = {
    "steel": ((178, 186, 196), 40),
    "abyssal": ((120, 80, 170), 18),
}

# (source, target pattern with {tier}): the chest's five faces, the shelves'
# fronts and their shared side and top (the vendored shelves use the plank).
FILES = [
    (DEFAULT / "default_chest_top.png", DEFAULT / "default_chest_{tier}_top.png"),
    (DEFAULT / "default_chest_side.png", DEFAULT / "default_chest_{tier}_side.png"),
    (DEFAULT / "default_chest_front.png", DEFAULT / "default_chest_{tier}_front.png"),
    (DEFAULT / "default_chest_lock.png", DEFAULT / "default_chest_{tier}_lock.png"),
    (DEFAULT / "default_chest_inside.png", DEFAULT / "default_chest_{tier}_inside.png"),
    (DEFAULT / "default_bookshelf.png", DEFAULT / "default_bookshelf_{tier}.png"),
    (DEFAULT / "default_wood.png", DEFAULT / "default_shelf_{tier}_side.png"),
    (VESSELS / "vessels_shelf.png", VESSELS / "vessels_shelf_{tier}.png"),
]


def tinted(source, tint, lift):
    image = Image.open(source).convert("RGBA")
    out = Image.new("RGBA", image.size)
    src, dst = image.load(), out.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = src[x, y]
            lum = (299 * r + 587 * g + 114 * b) // 1000
            lum = lift + lum * (255 - lift) // 255
            dst[x, y] = tuple(lum * c // 255 for c in tint) + (a,)
    return out


def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    for tier, (tint, lift) in TINTS.items():
        for source, pattern in FILES:
            target = Path(str(pattern).format(tier=tier))
            data = png_bytes(tinted(source, tint, lift))
            if check:
                if not target.exists() or target.read_bytes() != data:
                    stale.append(target.relative_to(ROOT))
            else:
                target.write_bytes(data)
    if check and stale:
        for path in stale:
            print(f"stale: {path}")
        return 1
    print(f"{len(TINTS) * len(FILES)} placeholder textures " + ("match" if check else "written"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
