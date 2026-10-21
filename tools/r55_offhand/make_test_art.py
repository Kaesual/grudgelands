#!/usr/bin/env python3
"""Write the offhand test art (docs/technical/offhand-format.md section 6):
flat regions in the reference palette with zones A and B marked and
orientation glyphs, for BAKE's tests and the round's shots. Never shipped:
it is baked only into a test-only mod.

  python3 make_test_art.py [--out test_art]

Shield sheet: the front face M_MID inside the outline with the ridge column
M_LIGHT, every texel the outline contains or crosses painted, the border texels
(which the rim samples) M_DARK, a zone A band
across the shoulder, zone B texels round the boss, glyph F at the top left;
the back face ACC_DARK (wood) with an ACC_LIGHT strap and glyph B. Texels
wholly outside the outline stay transparent. Book: covers A_DARK outside with zone B
corners, ACC_DARK elsewhere; pages M_HI with M_DARK lines on the readable
face; spine ACC_DARK with a B_DARK band; ribbon A_LIGHT. Glyphs F (front
cover), B (back cover) and R (the reader's right page) where a face is
big enough. Plus the 16 x 16 icons, a wings test texture and tiers.json.
"""
import argparse
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image  # noqa: E402

import offhand as O  # noqa: E402

sys.path.insert(0, str(O.ROOT / "tools/r54_armor"))
import armorlib as L  # noqa: E402

C = {n: L.hex_rgb(h) + (255,) for _, n, h, _ in L.REFERENCE}
GLYPH = {"F": ["###", "#..", "##.", "#..", "#.."], "B": ["##.", "#.#", "##.", "#.#", "##."],
         "R": ["##.", "#.#", "##.", "#.#", "#.#"]}
METAL_PALETTES = ("bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel")
CLOTH_PALETTES = ("patch", "woven", "heavy_cloth", "silkweave", "silk", "stormweave")


def glyph(px, fx, fy, fw, fh, letter):
    if fw >= 5 and fh >= 7:
        for r, row in enumerate(GLYPH[letter]):
            for c, ch in enumerate(row):
                if ch == "#":
                    px[fx + 1 + c, fy + 1 + r] = C["OUTLINE"]
    else:
        px[fx, fy] = C["OUTLINE"]


def inside(poly, x, y):
    hit = False
    for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            hit = not hit
    return hit


def shield_sheet(params):
    shape = params["shield"]["shape"]
    poly, lv = O.shield_outline(shape)
    W, H = O.texels(shape["width"]), O.texels(shape["height"])
    im = Image.new("RGBA", (2 * W, H), (0, 0, 0, 0))
    px = im.load()
    boss = params["shield"].get("boss")
    by = (lv["T"] + lv["B"]) / 2 + (lv["T"] - (lv["T"] + lv["B"]) / 2) * (boss["lift"] if boss else 0)
    for side, x_off in (("front", 0), ("back", W)):
        painted = O.shield_texels(shape, side)
        cells = {}
        for cy in range(H):
            for cx in range(W):
                u = (cx + 0.5) / W
                x = (-lv["W"] + 2 * lv["W"] * u) if side == "front" else (lv["W"] - 2 * lv["W"] * u)
                y = lv["T"] - (cy + 0.5) / H * shape["height"]
                cells[(cx, cy)] = ((cx, cy) in painted, x, y)
        for (cx, cy), (inn, x, y) in cells.items():
            if not inn:
                continue
            border = any(not cells.get((cx + dx, cy + dy), (False,))[0]
                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if side == "front":
                c = "M_DARK" if border else ("M_LIGHT" if abs(x) < lv["W"] / W else "M_MID")
                if not border and abs(y - lv["S"]) < shape["height"] / H:
                    c = "A_LIGHT" if y >= lv["S"] else "A_DARK"
                if boss and not border and abs(abs(x) - boss["radius"]) < 0.6 and abs(y - by) < 0.6:
                    c = "B_LIGHT"
                if boss and not border and abs(x) < 0.6 and abs(abs(y - by) - boss["radius"]) < 0.6:
                    c = "B_DARK"
            else:
                c = "M_DEEP" if border else ("ACC_LIGHT" if abs(y) < 1 else "ACC_DARK")
            px[x_off + cx, cy] = C[c]
        glyph(px, x_off + 1, 0, W - 1, H, "F" if side == "front" else "B")
    return im


def book_sheet(box_id, sheet):
    w, h, faces = sheet
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for face, (fx, fy, fw, fh) in faces.items():
        outer = (box_id, face) in (("cover_f", "front"), ("cover_b", "back"))
        readable = (box_id, face) in (("pages_f", "back"), ("pages_b", "front"))
        for y in range(fh):
            for x in range(fw):
                if box_id.startswith("cover"):
                    c = "A_DARK" if outer else "ACC_DARK"
                    if outer and (x, y) in ((0, 0), (fw - 1, 0), (0, fh - 1), (fw - 1, fh - 1)):
                        c = "B_LIGHT"
                elif box_id.startswith("pages"):
                    c = ("M_DARK" if y % 2 == 1 and 0 < x < fw - 1 else "M_HI") if readable else "M_LIGHT"
                elif box_id == "spine":
                    c = "B_DARK" if y == fh // 2 else "ACC_DARK"
                else:
                    c = "A_LIGHT"
                px[fx + x, fy + y] = C[c]
        if outer:
            glyph(px, fx, fy, fw, fh, "F" if box_id == "cover_f" else "B")
        if readable and box_id == "pages_b":
            glyph(px, fx, fy, fw, fh, "R")
    return im


ICON_SHIELD = ["................", "..############..", "..#mmmmhmmmmm#..", "..#maaaaaaaam#..", "..#maaaaaaaam#..",
               "..#mmmmhmmmmm#..", "..#mmmbbbmmmm#..", "..#mmmbbbmmmm#..", "..#mmmmhmmmmm#..", "...#mmmhmmmm#...",
               "...#mmmhmmmm#...", "....#mmhmmm#....", ".....#mhmm#.....", "......#hm#......", ".......##.......",
               "................"]
ICON_BOOK = ["................", "................", "..############..", "..#aaaaaaaaaa#..", "..#ab######ba#..",
             "..#a#hhhhhh#a#..", "..#a#hdddhh#a#..", "..#a#hhhhhh#a#..", "..#a#hdddhh#a#..", "..#a#hhhhhh#a#..",
             "..#ab######ba#..", "..#aaaaaaaaaa#..", "..############..", "................", "................",
             "................"]
ICON_COL = {"#": "OUTLINE", "m": "M_MID", "h": "M_HI", "d": "M_DARK", "a": "A_DARK", "b": "B_LIGHT"}


def icon(rows):
    im = Image.new("RGBA", O.ICON_SIZE, (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = C[ICON_COL[ch]]
    return im


def wings():
    """Outer face (columns 0-7, seen from behind, the left wing; hinge at
    column 7) and lining (columns 8-15, seen from the front; hinge at column
    8): the triangle below the diagonal from the hinge's top to the outer
    bottom corner."""
    w, h = O.WINGS_SIZE
    half = w // 2
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(h):
        reach = (y + 1) * half / h          # texels out from the hinge on this row
        for k in range(half):
            if k < reach:
                outer = "A_DARK" if y < h - 2 else "B_LIGHT"
                px[half - 1 - k, y] = C["OUTLINE" if k + 1 >= reach else outer]
                px[half + k, y] = C["A_LIGHT"]
    return im


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(O.TOOL / "test_art"))
    args = ap.parse_args()
    params = O.load()
    out = Path(args.out)
    (out / "shield").mkdir(parents=True, exist_ok=True)
    (out / "book").mkdir(exist_ok=True)
    (out / "icons").mkdir(exist_ok=True)
    shield_sheet(params).save(out / "shield/a.png")
    for box_id, sheet in O.sheets(params).items():
        if box_id in O.BOOK_BOXES:
            book_sheet(box_id, sheet).save(out / ("book/%s_a.png" % box_id))
    icon(ICON_SHIELD).save(out / "icons/shield_a.png")
    icon(ICON_BOOK).save(out / "icons/book_a.png")
    wings().save(out / "wings_test.png")
    tiers = {"shield": {"T%d" % t: {"palette": METAL_PALETTES[t - 1], "variant": "a", "icon": "a"} for t in range(1, 7)},
             "book": {"T%d" % t: {"palette": CLOTH_PALETTES[t - 1], "variant": "a", "icon": "a"} for t in range(1, 7)}}
    (out / "tiers.json").write_text(json.dumps(tiers, indent=1) + "\n")
    print("make_test_art: wrote %s" % out)


if __name__ == "__main__":
    main()
