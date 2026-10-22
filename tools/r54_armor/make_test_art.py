#!/usr/bin/env python3
"""Write a synthetic art set in the reference palette, for demonstrating and
testing render.py and check.py (never shipped).

  python3 make_test_art.py [--out test_art] [--broken test_art_broken]

Box sheets: shaded faces (top light with a dark back-edge row, sides mid with
light top and deep bottom rows), zone A as a two-row stripe and zone B as three
pixels on the front face. Orientation markers in OUTLINE: letter glyphs F
(front), R (right face, the character's right), L (left face), B (back) on
faces big enough, otherwise a corner flag (an L of three pixels) in the face's
top-left texel corner. Seen from outside, the glyph must read correctly on the
right-hand (or only) copy and mirrored on the mirrored left copy.

Polygon parts (Round 56, the hood): every face's whole rect painted (bleed
included), shaded by its facing (up light, sides mid, down and back dark), a
zone A stripe and zone B pixels on the larger faces, and a corner flag in
OUTLINE at each rect's top-left texel.

The clean set also writes tiers.json (the example selection plus a pauldron on
metal T1, since every box may be used on every tier; the hood on every cloth
and leather tier, and leather T6 on its own helm variant b, the veil, whose
chin strip stays closed). Every face is opaque except an eye band in the
helm's face window and, on the chin-strip tiers (cloth, leather T1-T5; Round
56 ruling 17), the helm front face's bottom row.

The broken set is a copy of the clean set with deliberate errors (wrong sheet
size, off-palette colour, partial alpha, paint outside the faces and outside
the slot region, an icon of the wrong size, a missing file, an unknown file
name, a slot whose zones were removed, an unknown box in tiers.json,
transparent texels in the sleeve and the chest faces, a hole in the helm front
outside its face window; Round 56: an open chin strip on the veil helm of
leather T6, a hole in a hood face's bleed, hood paint outside its faces, and a
tier that wears the hood without the helm).
"""
import argparse
import json
import shutil
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image  # noqa: E402

import armorlib as L  # noqa: E402

C = {n: L.hex_rgb(h) + (255,) for _, n, h, _ in L.REFERENCE}
GLYPH = {  # 3x5, rows top-down
    "F": ["###", "#..", "##.", "#..", "#.."],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
}
FACE_LETTER = {"front": "F", "right": "R", "left": "L", "back": "B"}
# per box: (zone A first row, zone B row) on the front face; default (H // 2, H // 2 - 2)
ZONE_ROWS = {"boot": (3, 2), "thigh": (1, 0), "knee": (1, 0), "toe": (1, 0), "belt": (1, 0),
             "panel_f": (3, 1), "panel_b": (3, 1)}


def mark(px, fx, fy, fw, fh, letter):
    if fw >= 7 and fh >= 7:
        for r, row in enumerate(GLYPH[letter]):
            for c, ch in enumerate(row):
                if ch == "#":
                    px[fx + 1 + c, fy + 1 + r] = C["OUTLINE"]
    else:
        px[fx, fy] = C["OUTLINE"]
        if fw > 1:
            px[fx + 1, fy] = C["OUTLINE"]
        if fh > 1:
            px[fx, fy + 1] = C["OUTLINE"]


def box_sheet(b, line):
    W, H, D = b["texels"]
    SW, SH = b["sheet"]
    im = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    px = im.load()
    base = {"metal": "M_MID", "leather": "M_MID", "cloth": "M_LIGHT"}[line]
    for face, (fx, fy, fw, fh) in b["faces"].items():
        for y in range(fh):
            for x in range(fw):
                if face == "top":
                    c = "M_DEEP" if y == 0 else "M_HI"          # row 0 = back edge
                elif face == "bottom":
                    c = "M_DARK"
                else:
                    c = base
                    if y == 0:
                        c = "M_LIGHT" if base == "M_MID" else "M_HI"
                    elif y == fh - 1 and fh > 2:
                        c = "M_DEEP"
                    elif face != "front" and (x == 0 or x == fw - 1) and fw > 2:
                        c = "M_DARK"
                    elif line == "leather" and face in ("front", "back") and (x + y) % 5 == 0:
                        c = "ACC_DARK"                          # diagonal strap
                    elif line == "metal" and b["id"] == "chest" and face == "front" and y == fh // 2 + 2:
                        c = "GLOW"                              # ember seam on palettes with glow
                px[fx + x, fy + y] = C[c]
        if face == "front":
            ra, rb = ZONE_ROWS.get(b["id"], (fh // 2, max(0, fh // 2 - 2)))
            for y in (ra, ra + 1):
                if 0 <= y < fh:
                    for x in range(fw):
                        px[fx + x, fy + y] = C["A_LIGHT" if y == ra else "A_DARK"]
            if 0 <= rb < fh:
                x0 = max(0, fw - 3)                     # right part of the face, clear of the glyph
                for x in range(x0, fw):
                    px[fx + x, fy + rb] = C["B_LIGHT" if x != x0 + 1 else "B_DARK"]
        if face in FACE_LETTER:
            mark(px, fx, fy, fw, fh, FACE_LETTER[face])
    return im


def inner_sheet(cat, slot, line):
    im = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    px = im.load()
    fill = {"chest": "A_DARK" if line == "cloth" else "ACC_LIGHT", "legs": "ACC_DARK", "feet": "M_DARK"}[slot]
    for x0, y0, x1, y1 in cat["slots"][slot]["inner_regions"]:
        for y in range(y0, y1):
            for x in range(x0, x1):
                c = fill
                if slot == "chest" and y in (26, 27):
                    c = "A_LIGHT"                                # zone A band
                if slot == "chest" and y == 24 and x % 3 == 0:
                    c = "B_LIGHT"                                # zone B buttons
                if slot == "legs" and y == 20:
                    c = "A_LIGHT"
                if slot == "legs" and y == 21 and x % 2 == 0:
                    c = "B_DARK"
                if slot == "feet" and y == 28:
                    c = "B_LIGHT"
                if slot == "feet" and y == 29:
                    c = "A_DARK"
                px[x, y] = C[c]
    # corner flags on the front faces (top-left = the character's right / the arm's outer side)
    if slot == "chest":
        for (x, y) in ((20, 20), (21, 20), (20, 21), (44, 20), (45, 20), (44, 21)):
            px[x, y] = C["OUTLINE"]
    if slot == "legs":
        for (x, y) in ((4, 22), (5, 22), (4, 23)):
            px[x, y] = C["OUTLINE"]
    return im


ICONS = {  # 16x16 silhouettes: '#' material, 'a' zone A, 'b' zone B, 'h' highlight, 'd' dark
    "head": ["................", "......####......", "....##hhhh##....", "...#hhh##hhh#...", "..#hhh####hhh#..",
             "..#hhh####hhh#..", "..#hh######hh#..", "..#bb######bb#..", "..##########d#..", "..#dooooooooo#..",
             "..##aaaaaaaa##..", "..##aaaaaaaa##..", "..###......###..", "..###......###..", "...##......##...",
             "................"],
    "chest": ["................", ".###........###.", "#hhh##....##hhh#", "#hhh###aa###hhh#", "#hh####aa####hh#",
              ".##h###aa###h##.", "..#h###aa###h#..", "..#h###bb###h#..", "..#h###aa###h#..", "..#h###aa###h#..",
              "..#dddddddddd#..", "..#bdddddddddb#.", "..#d########d#..", "..#dd######dd#..", "...##########...",
              "................"],
    "legs": ["................", "..############..", "..#bbbbbbbbbb#..", "..#hh######hh#..", "..#h###..###h#..",
             "..#h##a..a##h#..", "..#h##a..a##h#..", "..#h##a..a##h#..", "..#h##a..a##h#..", "..#d##....##d#..",
             "..#d##....##d#..", "..#d##....##d#..", "..#dd#....#dd#..", "..####....####..", "................",
             "................"],
    "feet": ["................", "................", "..####....####..", "..#hh#....#hh#..", "..#h##....#h##..",
             "..#aa#....#aa#..", "..#h##....#h##..", "..#h##....#h##..", "..#h###...#h###.", "..#h####..#h####",
             "..#bdddd#.#bdddd", "..#dddddd##ddddd", "..########.#####", "................", "................",
             "................"],
}
ICON_C = {"#": "OUTLINE", "h": "M_LIGHT", "d": "M_DARK", "a": "A_LIGHT", "b": "B_LIGHT", "o": "M_DEEP"}


def icon(slot, line):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(ICONS[slot]):
        for x, ch in enumerate(row):
            if ch == "#":
                # interior '#' = material mid; '#' on the silhouette edge = outline
                n = [ICONS[slot][yy][xx] if 0 <= yy < 16 and 0 <= xx < 16 else "."
                     for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1))]
                px[x, y] = C["OUTLINE" if "." in n else ("ACC_DARK" if line == "leather" else "M_MID")]
            elif ch in ICON_C:
                px[x, y] = C[ICON_C[ch]]
    return im


def part_sheet(p):
    """A polygon part's placeholder sheet: each face's whole rect (bleed included), shaded by its facing."""
    im = Image.new("RGBA", tuple(p["sheet"]), (0, 0, 0, 0))
    px = im.load()
    for f in p["polys"]:
        fx, fy, fw, fh = f["rect"]
        ny, nz = f["normal"][1], f["normal"][2]
        base = "M_LIGHT" if ny > 0.5 else "M_DARK" if ny < -0.5 or nz < -0.9 else "M_MID"
        for y in range(fh):
            for x in range(fw):
                c = base
                if fw >= 6 and fh >= 6 and y in (fh // 2, fh // 2 + 1):
                    c = "A_LIGHT" if y == fh // 2 else "A_DARK"         # zone A stripe
                elif fw >= 6 and fh >= 6 and y == fh // 2 - 2 and x >= fw - 3:
                    c = "B_LIGHT"                                         # zone B pixels
                elif fh > 2 and y == 0:
                    c = "M_HI"
                px[fx + x, fy + y] = C[c]
        px[fx, fy] = C["OUTLINE"]                                         # corner flag: the rect's top-left
        if fw > 1:
            px[fx + 1, fy] = C["OUTLINE"]
        if fh > 1:
            px[fx, fy + 1] = C["OUTLINE"]
    return im


def shape(im, b, chin=False):
    """The helm's face window: an eye band (rows 3-5 of the window) left open; with `chin`, the chin strip (the
    front face's bottom row, Round 56 ruling 17) too."""
    win = L.open_window(b)
    if win:
        px = im.load()
        ys = sorted({y for _, y in win})
        for x, y in win:
            if y in ys[2:5] and px[x, y][:3] not in (L.ZONE_A | L.ZONE_B):
                px[x, y] = (0, 0, 0, 0)
        for x, y in (L.chin_row(b) if chin else ()):
            px[x, y] = (0, 0, 0, 0)
    return im


def test_tiers(cat):
    """The example selection in the spec §7 shape, plus free choices: a plain shoulder piece on metal T1, the hood
    on every cloth and leather tier (Round 56), leather T6 on the helm variant b (the veil: chin strip closed)."""
    t = {"_doc": "test selection (make_test_art.py): the example from tiers_example.json; metal T1 adds the pauldron, "
                 "cloth and leather add the hood, leather T6 wears helm variant b"}
    for line in L.LINES:
        t[line] = {tid: {"palette": T["palette"], "on": list(T["on"]), "variant": dict(T["variant"]),
                         "inner": dict(T["inner"]), "icon": dict(T["icon"])} for tid, T in cat["tiers"][line].items()}
    t["metal"]["T1"]["on"].append("pauldron")
    for line in ("cloth", "leather"):
        for T in t[line].values():
            T["on"].append("hood")
    t["leather"]["T6"]["variant"]["helm"] = "b"
    return t


def write_clean(cat, out):
    out = Path(out)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    tiers = test_tiers(cat)
    (out / "tiers.json").write_text(json.dumps(tiers, indent=1))
    n = 0
    for line in L.LINES:
        need_box, need_inner, need_icon = set(), set(), set()
        for tier in tiers[line].values():
            for kind, key, v, _ in L.expected_files(cat, out, line, tier):
                {"box": need_box, "inner": need_inner, "icon": need_icon}[kind].add((key, v))
        byid = {b["id"]: b for b in L.pieces(cat)}
        for bid, v in sorted(need_box):
            p = L.box_file(out, line, bid, v)
            p.parent.mkdir(parents=True, exist_ok=True)
            b = byid[bid]
            if b.get("kind") == "poly":
                part_sheet(b).save(p)
            else:
                users = [tid for tid, T in tiers[line].items() if bid in T["on"] and L.tier_variant(T, bid) == v]
                shape(box_sheet(b, line), b, chin=L.chin_open(line, users)).save(p)
            n += 1
        for slot, v in sorted(need_inner):
            p = L.inner_file(out, line, slot, v)
            p.parent.mkdir(parents=True, exist_ok=True)
            inner_sheet(cat, slot, line).save(p)
            n += 1
        for slot, v in sorted(need_icon):
            p = L.icon_file(out, line, slot, v)
            p.parent.mkdir(parents=True, exist_ok=True)
            icon(slot, line).save(p)
            n += 1
    print("wrote", n, "files to", out)


def write_broken(clean, out):
    out = Path(out)
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(clean, out)
    m = out / "metal"
    # 1 wrong sheet size
    im = Image.open(m / "helm_a.png")
    im.crop((0, 0, im.width + 1, im.height)).save(m / "helm_a.png")
    # 2 off-palette colour and partial alpha on the chest front face
    im = Image.open(m / "chest_a.png").convert("RGBA")
    im.putpixel((7, 8), (0x12, 0x34, 0x56, 255))
    im.putpixel((8, 8), (0xA0, 0xA0, 0xA0, 128))
    im.save(m / "chest_a.png")
    # 3 paint outside the face rectangles (the empty corner left of the top face)
    im = Image.open(m / "belt_a.png").convert("RGBA")
    im.putpixel((0, 0), L.hex_rgb("#A0A0A0") + (255,))
    im.save(m / "belt_a.png")
    # 4 inner legs paints into the feet rows (outside its region) and loses its zones
    im = Image.open(m / "inner" / "legs_a.png").convert("RGBA")
    px = im.load()
    for x in range(16):
        for y in range(32):
            if px[x, y][3] and px[x, y][:3] in (L.ZONE_A | L.ZONE_B):
                px[x, y] = C["ACC_DARK"]
    px[5, 30] = C["ACC_DARK"]
    im.save(m / "inner" / "legs_a.png")
    # 5 thigh without zones -> metal T1/T2 legs fall below the zone minimum
    im = Image.open(m / "thigh_a.png").convert("RGBA")
    px = im.load()
    for x in range(im.width):
        for y in range(im.height):
            if px[x, y][3] and px[x, y][:3] in (L.ZONE_A | L.ZONE_B):
                px[x, y] = C["M_MID"]
    im.save(m / "thigh_a.png")
    # 6 icon of the wrong size
    Image.open(m / "icons" / "head_a.png").resize((32, 32), Image.Resampling.NEAREST).save(m / "icons" / "head_a.png")
    # 7 missing file
    (m / "boot_a.png").unlink()
    # 8 unknown file name
    shutil.copy(m / "visor_a.png", m / "helmet_a.png")
    # 9 tiers.json names a box that is not in the catalog
    t = json.loads((out / "tiers.json").read_text())
    t["metal"]["T6"]["on"].append("crest")
    (out / "tiers.json").write_text(json.dumps(t, indent=1))
    # 10-12 transparency: a corner cut on the sleeve front, a notch and a hole in the chest back, a hole in the
    # helm front outside its face window
    sl = next(b for b in L.load_catalog()["boxes"] if b["id"] == "sleeve")
    im = Image.open(m / "sleeve_a.png").convert("RGBA")
    fx, fy, fw, fh = sl["faces"]["front"]
    im.putpixel((fx + fw - 1, fy), (0, 0, 0, 0))
    im.save(m / "sleeve_a.png")
    ch = next(b for b in L.load_catalog()["boxes"] if b["id"] == "chest")
    im = Image.open(m / "chest_a.png").convert("RGBA")
    fx, fy, fw, fh = ch["faces"]["back"]
    for x in range(4):
        im.putpixel((fx + x, fy + 10), (0, 0, 0, 0))
    for x in range(3, 6):
        for y in range(4, 7):
            im.putpixel((fx + x, fy + y), (0, 0, 0, 0))
    im.save(m / "chest_a.png")
    # (helm_a.png already has the wrong size, so the helm hole goes into the leather helm)
    hl = next(b for b in L.load_catalog()["boxes"] if b["id"] == "helm")
    lp = out / "leather" / "helm_a.png"
    im = Image.open(lp).convert("RGBA")
    fx, fy, fw, fh = hl["faces"]["front"]
    im.putpixel((fx, fy + fh - 2), (0, 0, 0, 0))          # column 0: outside the window, above the chin strip
    im.save(lp)
    # Round 56: 13 the chin strip open on the veil helm (leather T6 wears variant b; ruling 17 keeps it closed)
    lp = out / "leather" / "helm_b.png"
    im = Image.open(lp).convert("RGBA")
    for xy in L.chin_row(hl):
        im.putpixel(xy, (0, 0, 0, 0))
    im.save(lp)
    # 14-15 the hood: a hole in the bleed of T.top (the rect's top-left corner lies outside the polygon) and paint
    # outside every face rect
    hood = next(p for p in L.load_catalog()["parts"] if p["id"] == "hood")
    hp = out / "cloth" / "hood_a.png"
    im = Image.open(hp).convert("RGBA")
    fx, fy, fw, fh = hood["faces"]["T.top"]
    im.putpixel((fx, fy + 2), (0, 0, 0, 0))               # left of the slanted edge: bleed, not polygon
    cells = {(x, y) for fx, fy, fw, fh in hood["faces"].values() for x in range(fx, fx + fw) for y in range(fy, fy + fh)}
    free = next((x, y) for y in range(im.height) for x in range(im.width) if (x, y) not in cells)
    im.putpixel(free, C["M_MID"])
    im.save(hp)
    # 16 a tier that wears the hood without the helm (cloth T2)
    t = json.loads((out / "tiers.json").read_text())
    t["cloth"]["T2"]["on"].remove("helm")
    (out / "tiers.json").write_text(json.dumps(t, indent=1))
    print("wrote broken set to", out, "(16 deliberate errors in metal/, leather/, cloth/ and tiers.json)")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(L.TOOL / "test_art"))
    ap.add_argument("--broken", default=str(L.TOOL / "test_art_broken"))
    a = ap.parse_args()
    cat = L.load_catalog()
    write_clean(cat, a.out)
    write_broken(a.out, a.broken)


if __name__ == "__main__":
    main()
