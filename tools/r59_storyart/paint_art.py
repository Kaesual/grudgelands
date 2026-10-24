#!/usr/bin/env python3
"""Paint Round 59's four picked quest objects; Python 3 + Pillow, no downloads.

GPT-6 Astra, 2026-10-24. AI-assisted original pixel art, CC0-1.0.
Run from any directory: python3 tools/r59_storyart/paint_art.py [--check]
Writes the four 32x32 RGBA textures into mods/PLAYER/grug_quests/textures/;
--check writes nothing and verifies that the shipped files are byte-for-byte
what the generator paints (and 32x32 RGBA with alpha 0 or 255 only).
The sprites are drawn by drop01.py (the story art drop 01's picks) and
drop01b.py (drop 01b's rope snare), copies of the drops' own generators
trimmed to the user's picks; the drops' review sheets stay outside the repo.
"""

import argparse
import io
import sys
from pathlib import Path

sys.dont_write_bytecode = True

import drop01  # noqa: E402
import drop01b  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
QUESTS = ROOT / "mods/PLAYER/grug_quests/textures"
# kind -> painter; the sizes the user picked live in data/use_objects.json.
PAINTERS = {
    "dispatch_record": drop01.dispatch_record,   # drop 01 P1, size 1.1
    "witness_record": drop01.witness_record,     # drop 01 P2, size 1.2
    "held_supplies": drop01.held_supplies,       # drop 01 P1, size 1.3
    "snare_bundle": drop01b.snare_bundle,        # drop 01b, size 1.2
}


def encode(im):
    """The PNG bytes the drops wrote (Image.save with Pillow's defaults)."""
    out = io.BytesIO()
    im.save(out, format="PNG")
    return out.getvalue()


def validate(kind, im):
    assert im.size == (32, 32) and im.mode == "RGBA", (kind, "format")
    alpha = {value for _, value in im.getchannel("A").getcolors(256)}
    assert alpha == {0, 255}, (kind, "alpha must be 0 or 255 only", sorted(alpha))
    assert im.getbbox()[3] == 32, (kind, "ground contact at row 31")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="verify the shipped PNGs without writing")
    args = parser.parse_args()
    failures = []
    for kind, paint in PAINTERS.items():
        im = paint()
        validate(kind, im)
        data = encode(im)
        path = QUESTS / f"grug_quests_obj_{kind}.png"
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
    print(f"OK: {len(PAINTERS)} textures {verb} (32x32 RGBA, alpha 0/255)")


if __name__ == "__main__":
    main()
