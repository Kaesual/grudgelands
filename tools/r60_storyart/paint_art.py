#!/usr/bin/env python3
"""Paint Round 60's picked quest objects and quest item icons; Python 3 + Pillow, no downloads.

GPT-6 Astra, 2026-10-24. AI-assisted original pixel art, CC0-1.0.
Run from any directory: python3 tools/r60_storyart/paint_art.py [--check]
Writes the four 32x32 RGBA quest-object textures into
mods/PLAYER/grug_quests/textures/ and the three 16x16 RGBA quest item icons
into mods/ENTITIES/grug_mobs/textures/; --check writes nothing and verifies
that the shipped files are byte-for-byte what the generator paints (RGBA
at their size, alpha 0 or 255 only, the objects standing on row 31).
The sprites are drawn by drop02.py (the story art drop 02's P2 picks) and
drop02b.py (drop 02b's P2 Captain's Orders), copies of the drops' own
generators trimmed to the user's picks; the drops' review sheets stay
outside the repo.
"""

import argparse
import io
import sys
from pathlib import Path

sys.dont_write_bytecode = True

import drop02  # noqa: E402
import drop02b  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
QUESTS = ROOT / "mods/PLAYER/grug_quests/textures"
MOBS = ROOT / "mods/ENTITIES/grug_mobs/textures"

# Each drop wrote its PNGs with its own Pillow save options.
DEFAULT_SAVE = {}                                    # drop 02: Image.save defaults
DROP02B_SAVE = {"optimize": False, "compress_level": 9}

# shipped file -> (painter, side, ground contact, save options); the sizes
# the user picked for the objects live in grug_quests/data/use_objects.json.
ART = {
    QUESTS / "grug_quests_obj_signal_lantern.png": (drop02.lantern_hood, 32, True, DEFAULT_SAVE),       # 1.2
    QUESTS / "grug_quests_obj_sighting_frame.png": (drop02.sighting_tripod, 32, True, DEFAULT_SAVE),    # 1.4
    QUESTS / "grug_quests_obj_reading_knots.png": (drop02.knots_raked, 32, True, DEFAULT_SAVE),         # 1.3
    QUESTS / "grug_quests_obj_claim_notice.png": (drop02.notice_wings, 32, True, DEFAULT_SAVE),         # 1.3
    MOBS / "grug_mobs_dispatch_folio.png": (drop02.folio_front, 16, False, DEFAULT_SAVE),
    MOBS / "grug_mobs_accord_captains_orders.png": (lambda: drop02b.roll("accord"), 16, False, DROP02B_SAVE),
    MOBS / "grug_mobs_throng_captains_orders.png": (lambda: drop02b.roll("throng"), 16, False, DROP02B_SAVE),
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
    print(f"OK: {len(ART)} textures {verb} (4 objects 32x32, 3 icons 16x16; RGBA, alpha 0/255)")


if __name__ == "__main__":
    main()
