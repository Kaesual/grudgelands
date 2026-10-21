#!/usr/bin/env python3
"""Stand-in offhand textures for model screenshots (Round 55 lane MODEL).

Not the bake (lane BAKE's tools/r55_offhand/bake.py makes the game's files):
this pastes the sheets of an art directory in the contract's layout
(docs/technical/offhand-format.md §6; default tools/r55_offhand/test_art)
into their rectangles of tools/r55_offhand/data/atlas.json, as they are,
and copies the wing texture, so capture.sh can show them on the real models:

    python3 tools/r55_model/stand_in.py --out DIR [--art ART] [--variant a]

writes DIR/r55model_shield<step>.png (the shield sheet in the region of size
step 0, 1 and 2), DIR/r55model_book.png (every book sheet), each 64x64 with
the rest transparent, and DIR/r55model_wings.png (the art's wings test
texture). Python 3 + Pillow. Never into mods/: the test art never ships.
"""
import argparse
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools/r55_offhand"))
import offhand as oh  # noqa: E402
from PIL import Image  # noqa: E402


def paste(atlas, sheets):
    """A transparent atlas with {sheet id: image} in their rectangles."""
    im = Image.new("RGBA", tuple(atlas["size"]), (0, 0, 0, 0))
    for sheet, art in sheets.items():
        x, y, w, h = atlas["sheets"][sheet]["rect"]
        if art.size != (w, h):
            raise SystemExit("stand_in: %s is %dx%d, its rectangle %dx%d" % (sheet, *art.size, w, h))
        im.paste(art, (x, y))
    return im


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--art", default=str(REPO / "tools/r55_offhand/test_art"))
    ap.add_argument("--variant", default="a")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    art, out = Path(a.art), Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    atlas = json.loads(oh.ATLAS.read_text())
    shield = Image.open(art / "shield" / ("%s.png" % a.variant)).convert("RGBA")
    for step in range(3):
        paste(atlas, {"shield_%d" % step: shield}).save(out / ("r55model_shield%d.png" % step))
    book = {box: Image.open(art / "book" / ("%s_%s.png" % (box, a.variant))).convert("RGBA")
            for box in oh.BOOK_BOXES}
    paste(atlas, book).save(out / "r55model_book.png")
    wings = sorted(art.glob("wings_*.png"))
    if wings:
        Image.open(wings[0]).convert("RGBA").save(out / "r55model_wings.png")
    print("stand_in: wrote r55model_shield0-2.png, r55model_book.png%s in %s" % (
        ", r55model_wings.png" if wings else "", out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
