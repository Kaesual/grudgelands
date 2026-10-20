#!/usr/bin/env python3
"""The Character page's empty-slot ghosts from the picked armor art (Round 54
lane INTEG).

grug_inventory/pages.lua draws an empty armor slot with
grug_gear_item_<slot>_metal.png darkened (^[multiply:#666666). Each of the
four is a copy of the baked metal T3 (steel) icon of its slot, the middle of
the metal ladder.

  python3 tools/r54_art/ghosts.py           write the four ghosts
  python3 tools/r54_art/ghosts.py --check   exit 1 when one differs (mode,
                                            size and pixels) from its icon
"""
import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image

GEAR = Path(__file__).resolve().parents[2] / "mods/ITEMS/grug_gear/textures"
SLOTS = ("head", "chest", "legs", "feet")
GRADE = "steel"


def pairs():
    for slot in SLOTS:
        yield GEAR / f"grug_gear_item_{slot}_metal_{GRADE}.png", GEAR / f"grug_gear_item_{slot}_metal.png"


def same(a, b):
    if not b.exists():
        return False
    ia, ib = Image.open(a), Image.open(b)
    return ia.mode == ib.mode and ia.size == ib.size and ia.tobytes() == ib.tobytes()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    bad = [dst for src, dst in pairs() if not same(src, dst)]
    if a.check:
        for dst in bad:
            print("FAIL", dst, "differs from its icon")
        print(f"r54 ghosts check: {'FAIL' if bad else 'ok'} ({len(SLOTS)} files)")
        return 1 if bad else 0
    for src, dst in pairs():
        if dst in bad:
            shutil.copyfile(src, dst)
    print(f"r54 ghosts: {len(bad)} of {len(SLOTS)} written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
