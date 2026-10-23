#!/usr/bin/env python3
"""Round 57 lane FIX56: the head pieces from below and from the front at a low
angle, before and after the chin strip's underside (ruling 24).

  python3 tools/r57_fix56/chin_shots.py BEFORE_ART AFTER_ART OUT

BEFORE_ART and AFTER_ART are art directories in the contract's format (e.g. a
copy of tools/r54_art/art before the change, and tools/r54_art/art). Renders
with the offline soft renderer of tools/r54_armor/render.py (the real model:
catalog boxes, the hood's polygon part, the human skin), the camera aimed at
the head. Writes OUT/<line>_<tier>.png per head piece: rows before / after,
columns from below (front), from below (three-quarter) and from the front at a
low angle; cloth and leather T1 and T6 and metal T3.
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
TOOL = Path(__file__).resolve().parent.parent / "r54_armor"
sys.path.insert(0, str(TOOL))
from PIL import Image, ImageDraw  # noqa: E402

import armorlib as L  # noqa: E402
import render  # noqa: E402
import softrender  # noqa: E402

HEAD = (0.0, 25.0, 0.0)
_camera = softrender.camera
softrender.camera = lambda dirv, dist, w, h, target=HEAD, fov=30.0: _camera(dirv, dist, w, h, target, fov)
VIEWS = [("from below (front)", (0.0, -1.0, 0.7)), ("from below (3/4)", (0.6, -1.0, 0.7)),
         ("front, low angle", (0.0, -0.3, 1.0))]
PIECES = [("cloth", "T1"), ("cloth", "T6"), ("leather", "T1"), ("leather", "T6"), ("metal", "T3")]
CW, CH, DIST = 300, 300, 24


def shots(art, line, tid):
    cat = L.load_catalog()
    pals, _, perr = L.load_palettes(art, None)
    tiers, _, terr = L.load_tiers(cat, pals, art)
    if perr or terr:
        sys.exit(f"{art}: {perr + terr}")
    cat = dict(cat, tiers=tiers)
    cells = [{"tier": 0, "x": i * CW, "y": 0, "w": CW, "h": CH, "dir": d, "walk": False}
             for i, (_, d) in enumerate(VIEWS)]
    img, _, missing = render.render_cells(cat, pals, art, line, [tid], "human", cells, CW * len(VIEWS), CH,
                                          DIST, None, "")
    if missing[tid]:
        sys.exit(f"{art} {line} {tid}: missing {missing[tid]}")
    return img


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    before, after, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    for line, tid in PIECES:
        top, label_w = 22, 70
        sheet = Image.new("RGB", (label_w + CW * len(VIEWS), top + 2 * CH), (236, 234, 229))
        d = ImageDraw.Draw(sheet)
        for i, (name, _) in enumerate(VIEWS):
            d.text((label_w + i * CW + 6, 4), f"{line} {tid}: {name}", fill=(20, 20, 20), font=render.font(13))
        for row, (name, art) in enumerate((("before", before), ("after", after))):
            sheet.paste(shots(art, line, tid), (label_w, top + row * CH))
            d.text((6, top + row * CH + CH // 2), name, fill=(20, 20, 20), font=render.font(14))
        path = out / f"{line}_{tid}.png"
        sheet.save(path)
        print(path)


if __name__ == "__main__":
    main()
