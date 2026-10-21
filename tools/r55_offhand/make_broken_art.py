#!/usr/bin/env python3
"""Write test_art_broken/: a copy of the offhand test art with deliberate
errors, one per rule of bake.py's validation (Round 55 lane BAKE). Never
shipped; test_bake.py checks that the bake refuses it with these messages.

  python3 make_broken_art.py            rewrite test_art_broken/ from test_art/
  python3 make_broken_art.py --check    exit 1 if test_art_broken/ is stale

The errors (expected() lists the message each one must produce; every
position and count is derived from params.json, which the user keeps tuning):
   1 shield/b.png (shield T6) has the wrong size
   2 shield/a.png: an off-palette colour and a partial alpha on the front
   3 shield/a.png: a transparent texel inside the outline on the back, and one
     on the front that the outline only crosses (the rim samples it; when the
     shape has such a texel)
   4 shield/c.png (shield T5): no zone texels, below the zone minimum
   5 book/cover_b_a.png: a hole in the back cover's outside
   6 book/cover_f_n.png, cover_b_n.png (book T4): covers without zones, so the
     book falls below the zone minimum
   7 icons/book_a.png: an icon of the wrong size
   8 book/ribbon_a.png is missing
   9 book/clasp_a.png: an unknown file name
  10 tiers.json: shield T2 an unknown palette, shield T3 no palette, book T3
     missing, an unknown tier T7, book T1 a variant for an unknown box
  11 wings_big.png, cloak_small.png: a wing and a cloak texture of the wrong
     size
  12 blank sheets at the right size: shield/e.png (shield T4: holes on both
     faces and no zones), book/spine_e.png and pages_f_e.png (book T5: holes)
And one warning: paint outside the spine sheet's faces (dropped).
"""
import argparse
import importlib.util
import json
import shutil
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image  # noqa: E402

import offhand as O  # noqa: E402

sys.path.insert(0, str(O.ROOT / "tools/r54_armor"))
import armorlib as L  # noqa: E402

# this folder's make_test_art (tools/r54_armor, on the path for armorlib, has one of the same name)
_spec = importlib.util.spec_from_file_location("r55_make_test_art", O.TOOL / "make_test_art.py")
MT = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MT)

CLEAN = O.TOOL / "test_art"
BROKEN = O.TOOL / "test_art_broken"
C = {n: L.hex_rgb(h) + (255,) for _, n, h, _ in L.REFERENCE}
ZONES = L.ZONE_A | L.ZONE_B


def positions(params):
    """Where the errors go, derived from params.json (it is retuned, so nothing
    is pinned): sheet-local texels and counts."""
    shape = params["shield"]["shape"]
    sheets = O.sheets(params)
    w, h = sheets["shield_0"][:2]
    W = w // 2
    poly, lv = O.shield_outline(shape)
    art = Image.open(CLEAN / "shield" / "a.png").convert("RGBA")
    plain = {p for p in ((x, y) for y in range(h) for x in range(w)) if art.getpixel(p)[:3] not in ZONES}
    front, back = O.shield_texels(shape, "front"), {(W + c, r) for c, r in O.shield_texels(shape, "back")}

    def interior(cells):
        """Painted non-zone texels whose four neighbours are in the set, in reading order."""
        return sorted((p for p in cells & plain if all((p[0] + dx, p[1] + dy) in cells
                                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))),
                      key=lambda q: (q[1], q[0]))

    def centre_inside(c, r):
        return MT.inside(poly, -lv["W"] + 2 * lv["W"] * (c + 0.5) / W, lv["T"] - (r + 0.5) / h * shape["height"])
    inner_f, inner_b = interior(front), interior(back)
    crossed = sorted((p for p in front & plain if not centre_inside(*p)), key=lambda q: (q[1], q[0]))
    bw, bh, bfaces = sheets["cover_b"]
    fx, fy, fw, fh = bfaces["back"]

    def cells(box):
        return sum(fw_ * fh_ for _, _, fw_, fh_ in sheets[box][2].values())
    return {"size": (w, h), "off": inner_f[len(inner_f) // 2], "partial": inner_f[len(inner_f) // 2 + 1],
            "hole_back": inner_b[len(inner_b) // 2], "crossed": crossed[0] if crossed else None,
            "cover_hole": (fx + fw // 2, fy + fh // 2), "n_front": len(front), "n_back": len(back),
            "n_spine": cells("spine"), "n_pages_f": cells("pages_f")}


def expected(params=None):
    """[(error number, a fragment of the message bake.py must print for it)]."""
    params = params or O.load()
    q = positions(params)
    w, h = q["size"]
    out = [
        (1, "shield/b.png: size %dx%d, expected %dx%d" % (w + 1, h, w, h)),
        (2, "shield/a.png: 1 pixel(s) off the reference palette at (%d,%d)" % q["off"]),
        (2, "shield/a.png: 1 pixel(s) with partial alpha (only 0 or 255) at (%d,%d)" % q["partial"]),
        (3, "shield/a.png: 1 transparent texel(s) the outline contains or crosses (back face) at (%d,%d)"
         % q["hole_back"]),
        (4, "shield/c.png (shield T5, size step %d): 0 zone A (at least 6), 0 zone B (at least 3)"
         % O.tier_step(params, 5)),
        (5, "book/cover_b_a.png: 1 transparent texel(s) in a face at (%d,%d)" % q["cover_hole"]),
        (6, "book T4 (outer covers and readable pages): 0 zone A (at least 6), 0 zone B (at least 3)"),
        (7, "icons/book_a.png: size 32x32, expected 16x16"),
        (8, "missing "),
        (8, "book/ribbon_a.png"),
        (9, "book/clasp_a.png: unknown file name"),
        (10, "shield T2: unknown palette 'tin'"),
        (10, "shield T3: no 'palette'"),
        (10, "book T3: no entry"),
        (10, "shield: unknown tier 'T7'"),
        (10, "book T1: 'variant' names unknown box 'clasp'"),
        (11, "wings_big.png: size 32x32, expected 16x32"),
        (11, "cloak_small.png: size 16x32, expected 32x32"),
        (12, "shield/e.png: %d transparent texel(s) the outline contains or crosses (front face)" % q["n_front"]),
        (12, "shield/e.png: %d transparent texel(s) the outline contains or crosses (back face)" % q["n_back"]),
        (12, "shield/e.png (shield T4, size step %d): 0 zone A (at least 6), 0 zone B (at least 3)"
         % O.tier_step(params, 4)),
        (12, "book/spine_e.png: %d transparent texel(s) in a face" % q["n_spine"]),
        (12, "book/pages_f_e.png: %d transparent texel(s) in a face" % q["n_pages_f"]),
    ]
    if q["crossed"]:
        out.append((3, "shield/a.png: 1 transparent texel(s) the outline contains or crosses (front face) at (%d,%d)"
                    % q["crossed"]))
    return out


WARNING = "book/spine_a.png: 1 pixel(s) outside the faces at (0,0) (dropped)"


def edit(path, fn):
    im = Image.open(path).convert("RGBA")
    fn(im, im.load())
    im.save(path)


def no_zones(im, px):
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] and px[x, y][:3] in ZONES:
                px[x, y] = C["ACC_DARK"]


def write(out):
    out = Path(out)
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(CLEAN, out)
    sh, bk = out / "shield", out / "book"
    q = positions(O.load())
    # 1 wrong sheet size
    im = Image.open(sh / "a.png")
    im.crop((0, 0, im.width + 1, im.height)).save(sh / "b.png")
    # 4 a shield variant without zones (before 2 and 3 touch a.png)
    shutil.copy(sh / "a.png", sh / "c.png")
    edit(sh / "c.png", no_zones)

    # 2, 3 off-palette, partial alpha on the front; a hole inside the outline on the back, and one on the
    # front's slanted edge, in a texel the outline only crosses (its centre lies outside)
    def shield_a(im, px):
        px[q["off"]] = (0x12, 0x34, 0x56, 255)
        px[q["partial"]] = C["M_MID"][:3] + (128,)
        px[q["hole_back"]] = (0, 0, 0, 0)
        if q["crossed"]:
            px[q["crossed"]] = (0, 0, 0, 0)
    edit(sh / "a.png", shield_a)

    # 6 covers without zones for book T4 (before 5 touches cover_b_a.png)
    for box in ("cover_f", "cover_b"):
        shutil.copy(bk / ("%s_a.png" % box), bk / ("%s_n.png" % box))
        edit(bk / ("%s_n.png" % box), no_zones)

    # 5 a hole in the middle of the back cover's outside
    def cover_b(im, px):
        px[q["cover_hole"]] = (0, 0, 0, 0)
    edit(bk / "cover_b_a.png", cover_b)
    # 7 an icon of the wrong size
    Image.open(out / "icons/book_a.png").resize((32, 32), Image.Resampling.NEAREST).save(out / "icons/book_a.png")
    # 12 blank sheets of the right size (read fine, nothing painted)
    for name, like in (("shield/e.png", "shield/a.png"), ("book/spine_e.png", "book/spine_a.png"),
                       ("book/pages_f_e.png", "book/pages_f_a.png")):
        Image.new("RGBA", Image.open(out / like).size, (0, 0, 0, 0)).save(out / name)
    # 11 a wing texture of the wrong size
    Image.open(out / "wings_test.png").resize((32, 32), Image.Resampling.NEAREST).save(out / "wings_big.png")
    Image.new("RGBA", (16, 32), (0, 0, 0, 0)).save(out / "cloak_small.png")
    # 8 a missing file, 9 an unknown file name
    (bk / "ribbon_a.png").unlink()
    shutil.copy(bk / "spine_a.png", bk / "clasp_a.png")

    # the warning: paint outside the spine sheet's faces (its top-left corner)
    def spine(im, px):
        px[0, 0] = C["M_MID"]
    edit(bk / "spine_a.png", spine)
    # 10 tiers.json
    t = json.loads((out / "tiers.json").read_text())
    t["shield"]["T2"]["palette"] = "tin"
    del t["shield"]["T3"]["palette"]
    t["shield"]["T5"]["variant"] = "c"
    t["shield"]["T6"]["variant"] = "b"
    t["shield"]["T4"]["variant"] = "e"
    t["book"]["T5"]["variant"] = {"spine": "e", "pages_f": "e"}
    t["shield"]["T7"] = dict(t["shield"]["T6"])
    del t["book"]["T3"]
    t["book"]["T1"]["variant"] = {"clasp": "a"}
    t["book"]["T4"]["variant"] = {"cover_f": "n", "cover_b": "n"}
    (out / "tiers.json").write_text(json.dumps(t, indent=1) + "\n")


def same_tree(a, b):
    """[differences] between two art directories (file sets, pixels, text)."""
    fa = {p.relative_to(a) for p in Path(a).rglob("*") if p.is_file()}
    fb = {p.relative_to(b) for p in Path(b).rglob("*") if p.is_file()}
    out = ["only in %s: %s" % (a, p) for p in sorted(fa - fb)] + ["only in %s: %s" % (b, p) for p in sorted(fb - fa)]
    for rel in sorted(fa & fb):
        pa, pb = Path(a) / rel, Path(b) / rel
        if rel.suffix == ".png":
            with Image.open(pa) as x, Image.open(pb) as y:
                if x.mode != y.mode or x.size != y.size or x.tobytes() != y.tobytes():
                    out.append("differs: %s" % rel)
        elif pa.read_bytes() != pb.read_bytes():
            out.append("differs: %s" % rel)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        with tempfile.TemporaryDirectory() as tmp:
            fresh = Path(tmp) / "broken"
            write(fresh)
            problems = same_tree(fresh, BROKEN)
        for p in problems:
            print("FAIL", p)
        print("make_broken_art check: %s" % ("FAIL (run python3 tools/r55_offhand/make_broken_art.py)"
                                              if problems else "ok"))
        return 1 if problems else 0
    write(BROKEN)
    print("make_broken_art: wrote %s (%d deliberate errors)" % (BROKEN, len({n for n, _ in expected()})))
    return 0


if __name__ == "__main__":
    sys.exit(main())
