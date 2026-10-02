#!/usr/bin/env python3
"""Round 28 Lane W1: two world views of one seed side by side.

Reads <out>/<left>_seed_<s>.png and <right>_seed_<s>.png (render.py) and the
two dumps' edge classes, and writes <out>/compare_seed_<s>.png: the two maps
(without their side panels) next to each other under a strip with the
border length per class for both.

Usage: pair.py --out DIR --seed SEED --left NAME DUMP_DIR LABEL --right NAME DUMP_DIR LABEL
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

from render import CLASS_RGB, INK, INK2, LEFT, PX, TOP, BOTTOM, font

CLASSES = ("fit", "step", "jump", "forced", "none")
NAMES = {"fit": "fit (gap <= 1)", "step": "step (2-5)", "jump": "jump (> 5)",
         "forced": "forced (bands)", "none": "no recipe"}
STRIP = 110


def totals(dump, seed):
    doc = json.load(open(Path(dump) / ("world_%s.json" % seed)))
    out = {c: 0 for c in CLASSES}
    for e in doc["edges"]:
        out[e[11]] += doc["cell"]
    return out, doc["frame"]["cols"] * PX


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", required=True)
    ap.add_argument("--left", nargs=3, required=True, metavar=("NAME", "DUMP", "LABEL"))
    ap.add_argument("--right", nargs=3, required=True, metavar=("NAME", "DUMP", "LABEL"))
    args = ap.parse_args()
    out = Path(args.out)
    parts = []
    for name, dump, label in (args.left, args.right):
        t, w = totals(dump, args.seed)
        img = Image.open(out / ("%s_seed_%s.png" % (name, args.seed)))
        maps = img.crop((LEFT, TOP, LEFT + w, img.height - BOTTOM))
        parts.append((name, t, maps, label))
    gap = 24
    W = LEFT * 2 + sum(p[2].width for p in parts) + gap
    H = STRIP + max(p[2].height for p in parts) + BOTTOM
    canvas = Image.new("RGB", (W, H), (252, 252, 251))
    d = ImageDraw.Draw(canvas)
    f_title, f_text, f_bold = font(26, True), font(16), font(16, True)
    x = LEFT
    for name, t, maps, label in parts:
        canvas.paste(maps, (x, STRIP))
        d.text((x, 12), "seed %s - %s" % (args.seed, label), font=f_title, fill=INK)
        cx = x
        for c in CLASSES:
            d.rectangle([cx, 58, cx + 26, 66], fill=CLASS_RGB[c], outline=INK)
            txt = "%s %d" % (NAMES[c], t[c])
            d.text((cx + 32, 52), txt, font=f_bold if c == "jump" else f_text, fill=INK)
            cx += 44 + d.textbbox((0, 0), txt, font=f_bold)[2]
        d.text((x, 80), "border length in nodes; full legend and lists in %s_seed_%s.png/.md" % (
            name, args.seed), font=f_text, fill=INK2)
        x += maps.width + gap
    canvas.save(out / ("compare_seed_%s.png" % args.seed), optimize=True)


if __name__ == "__main__":
    main()
