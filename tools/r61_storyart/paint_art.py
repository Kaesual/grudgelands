#!/usr/bin/env python3
"""Paint Round 61's picked quest object and quest item icon; Python 3 + Pillow, no downloads.

GPT-6 Astra, 2026-10-25. AI-assisted original pixel art, CC0-1.0.
Run from any directory: python3 tools/r61_storyart/paint_art.py [--check]
Writes the 32x32 RGBA quest-object texture storm_vessel into
mods/PLAYER/grug_quests/textures/ and the 16x16 RGBA Runner's Packet icon
into mods/ENTITIES/grug_mobs/textures/; --check writes nothing and verifies
that the shipped files are byte-for-byte what the generator paints (RGBA
at their size, alpha 0 or 255 only, the object standing on row 31).
The sprites are drawn by drop03.py (the story art drop 03's P1 picks), a
copy of the drop's own generator trimmed to the user's picks; the drop's
review sheets stay outside the repo.
"""

import argparse
import io
import sys
from pathlib import Path

sys.dont_write_bytecode = True

import drop03  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
QUESTS = ROOT / "mods/PLAYER/grug_quests/textures"
MOBS = ROOT / "mods/ENTITIES/grug_mobs/textures"

# The drop wrote its PNGs with Pillow's default save options.
DEFAULT_SAVE = {}

# shipped file -> (painter, side, ground contact, save options); the size
# the user picked for the object lives in grug_quests/data/use_objects.json.
ART = {
    QUESTS / "grug_quests_obj_storm_vessel.png": (drop03.clay_crock, 32, True, DEFAULT_SAVE),     # 1.2
    MOBS / "grug_mobs_runners_packet.png": (drop03.flat_envelope, 16, False, DEFAULT_SAVE),
}


def encode(im, options):
    """The PNG bytes the drop wrote."""
    out = io.BytesIO()
    im.save(out, format="PNG", **options)
    return out.getvalue()


def validate(name, im, side, grounded):
    assert im.size == (side, side) and im.mode == "RGBA", (name, "format")
    alpha = {value for _, value in im.getchannel("A").getcolors(256)}
    assert alpha == {0, 255}, (name, "alpha must be 0 or 255 only", sorted(alpha))
    if grounded:
        assert im.getbbox()[3] == side, (name, "ground contact at the bottom row")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="verify the shipped PNGs without writing")
    args = parser.parse_args()
    failures = []
    for path, (paint, side, grounded, options) in ART.items():
        im = paint()
        validate(path.name, im, side, grounded)
        data = encode(im, options)
        if args.check:
            if not path.is_file():
                failures.append(f"missing: {path.relative_to(ROOT)}")
            elif path.read_bytes() != data:
                failures.append(f"differs: {path.relative_to(ROOT)}")
        else:
            path.write_bytes(data)
    if failures:
        print("\n".join(failures))
        sys.exit(1)
    verb = "match" if args.check else "written"
    print(f"OK: {len(ART)} textures {verb} (1 object 32x32, 1 icon 16x16; RGBA, alpha 0/255)")


if __name__ == "__main__":
    main()
