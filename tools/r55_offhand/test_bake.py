#!/usr/bin/env python3
"""Test of bake.py on the offhand test art (Round 55 lane BAKE).

  python3 tools/r55_offhand/test_bake.py      exit 1 on a failure

Bakes test_art/ into a temp dir and proves: the file set and formats; each
tier's shield lands in the sheet of its size step (params' tier_step) and the
other copies, the book and the card stay transparent; each book box lands in
its rectangle, only its faces, with a left-out face transparent; glyph and
zone texels at their atlas positions in the tier palette's colour; the masks'
zones (frame 0 A, frame 1 B, light 255, dark 153); palettes.json laid over by
name; a book variant map; the icons and their masks; determinism; --check
finding a missing, a changed and an extra file (and write removing the
extra); the broken set failing with the expected messages and writing
nothing; a hole in a texel the outline only crosses; blank sheets; a missing art
directory; make_broken_art.py --check.
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image  # noqa: E402

TOOL = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL))
import bake as B  # noqa: E402
import make_broken_art as MB  # noqa: E402
import offhand as O  # noqa: E402

L = B.L
FAILS = []


def ok(cond, what):
    if not cond:
        FAILS.append(what)


ART = TOOL / "test_art"
PARAMS = O.load()
ATLAS = json.loads(O.ATLAS.read_text())
SHEETS = ATLAS["sheets"]
SIZE = tuple(ATLAS["size"])
GRADES = O.grades()
TIERS = json.loads((ART / "tiers.json").read_text())
PALS = L.load_palettes()[0]["palettes"]
REF = {L.hex_rgb(h): n for _, n, h, _ in L.REFERENCE}
GREY = {"A_LIGHT": (0, 255), "A_DARK": (0, 153), "B_LIGHT": (1, 255), "B_DARK": (1, 153)}


def art_names(path):
    """{(x, y): reference name} of an art PNG."""
    im = Image.open(path).convert("RGBA")
    return {(x, y): REF[im.getpixel((x, y))[:3]] for y in range(im.height) for x in range(im.width)
            if im.getpixel((x, y))[3]}


def opaque(im, rect=None):
    x0, y0, w, h = rect or (0, 0, im.width, im.height)
    return {(x, y) for y in range(y0, y0 + h) for x in range(x0, x0 + w) if im.getpixel((x, y))[-1]}


def rgba(palette, name):
    return L.hex_rgb(PALS[palette]["colors"][name]) + (255,)


def expected(item, tier, art=ART):
    """{atlas texel: reference name}: the art's face texels moved into the
    atlas (an independent re-derivation from atlas.json's face rectangles)."""
    out = {}
    if item == "shield":
        parts = [("shield_%d" % O.tier_step(PARAMS, int(tier[1:])), art / "shield" / "a.png")]
    else:
        v = TIERS["book"][tier]["variant"]
        parts = [(b, art / "book" / ("%s_%s.png" % (b, v if isinstance(v, str) else v.get(b, "a"))))
                 for b in O.BOOK_BOXES]
    for sheet, path in parts:
        names = art_names(path)
        rx, ry = SHEETS[sheet]["rect"][:2]
        for fx, fy, fw, fh in SHEETS[sheet]["faces"].values():
            for y in range(fy, fy + fh):
                for x in range(fx, fx + fw):
                    n = names.get((x - rx, y - ry))
                    if n:
                        out[(x, y)] = n
    return out


def check_layer(files, item, tier, grade, palette, art=ART, label=""):
    lay = files[O.layer_file(item, grade)]
    mask = files[O.mask_file(O.layer_file(item, grade))]
    ok(lay.size == SIZE and lay.mode == "RGBA", "%s layer format %s %s" % (item, lay.size, lay.mode))
    ok(mask.size == (SIZE[0], 2 * SIZE[1]) and mask.mode == "LA", "%s mask format" % item)
    want = expected(item, tier, art)
    ok(opaque(lay) == set(want), "%s %s%s: opaque exactly at the face texels (%d vs %d)"
       % (item, tier, label, len(opaque(lay)), len(want)))
    bad_col = [p for p, n in want.items() if lay.getpixel(p) != rgba(palette, n)]
    ok(not bad_col, "%s %s%s: colours from palette %s, first wrong at %s" % (item, tier, label, palette, bad_col[:3]))
    bad_mask = []
    for y in range(SIZE[1]):
        for x in range(SIZE[0]):
            g = GREY.get(want.get((x, y)))
            top, bottom = mask.getpixel((x, y)), mask.getpixel((x, y + SIZE[1]))
            if g is None:
                good = top[1] == 0 and bottom[1] == 0
            else:
                hit, miss = (top, bottom) if g[0] == 0 else (bottom, top)
                good = hit == (g[1], 255) and miss[1] == 0
            if not good:
                bad_mask.append((x, y))
    ok(not bad_mask, "%s %s%s: mask zones, first wrong at %s" % (item, tier, label, bad_mask[:3]))
    return lay, mask


def run(*args):
    return subprocess.run([sys.executable, str(TOOL / "bake.py"), *map(str, args)], capture_output=True, text=True)


def main():
    files, icons = B.bake(ART, icons=True)
    names = {O.layer_file(i, g) for i in ("shield", "book") for g in GRADES}
    ok(set(files) == names | {O.mask_file(n) for n in names}, "game file set: %s" % sorted(files))
    inames = {O.icon_file(i, g) for i in ("shield", "book") for g in GRADES}
    ok(set(icons) == inames | {O.mask_file(n) for n in inames}, "icon file set: %s" % sorted(icons))

    # --- shields: in the sheet of the tier's size step only ---------------------------------
    steps = set()
    for n, g in enumerate(GRADES, start=1):
        tier = "T%d" % n
        step = O.tier_step(PARAMS, n)
        steps.add(step)
        pal = TIERS["shield"][tier]["palette"]
        lay, mask = check_layer(files, "shield", tier, g, pal)
        rect = SHEETS["shield_%d" % step]["rect"]
        ok(opaque(lay) <= opaque(lay, rect), "shield %s: everything inside shield_%d" % (tier, step))
        for other in range(3):
            if other != step:
                ok(not opaque(lay, SHEETS["shield_%d" % other]["rect"]), "shield %s: shield_%d transparent" % (tier, other))
        for b in O.BOOK_BOXES + ("card",):
            ok(not opaque(lay, SHEETS[b]["rect"]), "shield %s: %s transparent" % (tier, b))
        # samples: the top-left border texel, the F glyph on the front, the B glyph on the back
        fx, fy = SHEETS["shield_%d" % step]["faces"]["front"][:2]
        bx, by = SHEETS["shield_%d" % step]["faces"]["back"][:2]
        for (x, y), n_ in (((fx, fy), "M_DARK"), ((fx + 2, fy + 1), "OUTLINE"), ((fx + 4, fy + 1), "OUTLINE"),
                           ((fx + 2, fy + 5), "OUTLINE"), ((bx + 2, by + 1), "OUTLINE"), ((bx + 4, by + 2), "OUTLINE"),
                           ((bx, by), "M_DEEP")):
            ok(lay.getpixel((x, y)) == rgba(pal, n_), "shield %s sample %s at (%d,%d)" % (tier, n_, x, y))
        ok(lay.getpixel((fx, fy + 12)) == (0, 0, 0, 0), "shield %s: outside the outline stays transparent" % tier)
        # zone samples: the shoulder band (zone A) and the boss texels (zone B) in their frames
        ok(mask.getpixel((fx + 1, fy + 5)) == (255, 255), "shield %s: A_LIGHT in frame 0 at 255" % tier)
        ok(mask.getpixel((fx + 1, fy + 6)) == (153, 255), "shield %s: A_DARK in frame 0 at 153" % tier)
        ok(mask.getpixel((fx + 3, fy + 5 + SIZE[1])) == (255, 255), "shield %s: B_LIGHT in frame 1 at 255" % tier)
        ok(mask.getpixel((fx + 4, fy + 4 + SIZE[1])) == (153, 255), "shield %s: B_DARK in frame 1 at 153" % tier)
    ok(steps == {0, 1, 2}, "the test tiers use all three size steps: %s" % steps)

    # --- books: every box in its rectangle, only its faces ----------------------------------
    for n, g in enumerate(GRADES, start=1):
        tier = "T%d" % n
        pal = TIERS["book"][tier]["palette"]
        lay, mask = check_layer(files, "book", tier, g, pal)
        for b in O.BOOK_BOXES:
            faces = SHEETS[b]["faces"]
            cells = {(x, y) for fx, fy, fw, fh in faces.values() for y in range(fy, fy + fh) for x in range(fx, fx + fw)}
            ok(opaque(lay, SHEETS[b]["rect"]) == cells, "book %s: %s opaque on its faces only" % (tier, b))
        for s in ("shield_0", "shield_1", "shield_2", "card"):
            ok(not opaque(lay, SHEETS[s]["rect"]), "book %s: %s transparent" % (tier, s))
        # a left-out face has no texels: pages_f's right face would sit at the sheet's (0, D)
        px, py = SHEETS["pages_f"]["rect"][:2]
        ok(lay.getpixel((px, py + 1)) == (0, 0, 0, 0), "book %s: pages_f's left-out right face transparent" % tier)
        cf, cb = SHEETS["cover_f"]["faces"]["front"], SHEETS["cover_b"]["faces"]["back"]
        pb, sp, rb = SHEETS["pages_b"]["faces"]["front"], SHEETS["spine"]["faces"]["front"], SHEETS["ribbon"]["faces"]["front"]
        for (x, y), n_ in (((cf[0], cf[1]), "B_LIGHT"), ((cf[0] + 1, cf[1] + 1), "OUTLINE"),
                           ((cf[0] + 3, cf[1] + 1), "OUTLINE"), ((cb[0] + 1, cb[1] + 1), "OUTLINE"),
                           ((cb[0] + 3, cb[1] + 2), "OUTLINE"), ((cb[0] + 1, cb[1] + 2), "OUTLINE"),
                           ((cf[0] + 3, cf[1] + 4), "A_DARK"), ((pb[0], pb[1]), "OUTLINE"),
                           ((pb[0] + 1, pb[1] + 1), "M_DARK"), ((sp[0], sp[1] + sp[3] // 2), "B_DARK"),
                           ((rb[0], rb[1]), "A_LIGHT")):
            ok(lay.getpixel((x, y)) == rgba(pal, n_), "book %s sample %s at (%d,%d)" % (tier, n_, x, y))
        ok(mask.getpixel((cf[0], cf[1] + SIZE[1])) == (255, 255), "book %s: cover corner B_LIGHT frame 1" % tier)
        ok(mask.getpixel((cf[0] + 3, cf[1] + 4)) == (153, 255), "book %s: cover A_DARK frame 0" % tier)

    # --- icons ---------------------------------------------------------------------------
    for item, art_name in (("shield", "shield_a.png"), ("book", "book_a.png")):
        names = art_names(ART / "icons" / art_name)
        for n, g in enumerate(GRADES, start=1):
            pal = TIERS[item]["T%d" % n]["palette"]
            ic, im = icons[O.icon_file(item, g)], icons[O.mask_file(O.icon_file(item, g))]
            ok(ic.size == (16, 16) and ic.mode == "RGBA" and im.size == (16, 32) and im.mode == "LA",
               "%s icon formats" % item)
            ok(opaque(ic) == set(names) and all(ic.getpixel(p) == rgba(pal, nm) for p, nm in names.items()),
               "%s icon T%d: the art in its palette" % (item, n))
            bad = [p for p, nm in names.items() if nm in GREY and
                   im.getpixel((p[0], p[1] + 16 * GREY[nm][0])) != (GREY[nm][1], 255)]
            ok(not bad and len(opaque(im)) == sum(nm in GREY for nm in names.values()),
               "%s icon T%d mask: %s" % (item, n, bad[:3]))

    # --- determinism ---------------------------------------------------------------------
    again, _ = B.bake(ART)
    ok(all(B.png_bytes(again[n]) == B.png_bytes(im) for n, im in files.items()), "the bake is deterministic")

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        # --- palettes.json laid over by name, a book variant map ---------------------------
        art2 = tmp / "art2"
        shutil.copytree(ART, art2)
        test_pal = {nm: "#%02X%02X%02X" % (10 + 15 * i, 200 - 13 * i, (37 * i) % 256)
                    for i, nm in enumerate(L.REF_NAMES)}
        (art2 / "palettes.json").write_text(json.dumps({"palettes": {"bronze": {"colors": test_pal}}}))
        cover = Image.open(art2 / "book" / "cover_f_a.png").convert("RGBA")
        fx, fy, fw, fh = SHEETS["cover_f"]["faces"]["back"]
        rx, ry = SHEETS["cover_f"]["rect"][:2]
        for y in range(fh):
            for x in range(fw):
                cover.putpixel((fx - rx + x, fy - ry + y), L.hex_rgb("#E07070") + (255,))
        cover.putpixel((0, 0), L.hex_rgb("#E07070") + (255,))           # outside every face: dropped
        cover.save(art2 / "book" / "cover_f_b.png")
        t = json.loads((art2 / "tiers.json").read_text())
        t["book"]["T2"]["variant"] = {"cover_f": "b"}
        (art2 / "tiers.json").write_text(json.dumps(t))
        warn = []
        f2, _ = B.bake(art2, warnings=warn)
        ok(f2[O.layer_file("book", GRADES[1])].getpixel((rx, ry)) == (0, 0, 0, 0)
           and any("cover_f_b.png: 1 pixel(s) outside the faces at (0,0) (dropped)" in w for w in warn),
           "paint outside the faces is dropped with a warning: %s" % warn)
        lay = f2[O.layer_file("shield", GRADES[0])]
        fx0, fy0 = SHEETS["shield_%d" % O.tier_step(PARAMS, 1)]["faces"]["front"][:2]
        ok(lay.getpixel((fx0, fy0)) == L.hex_rgb(test_pal["M_DARK"]) + (255,), "palettes.json overrides bronze")
        ok(f2[O.layer_file("shield", GRADES[1])].tobytes() == files[O.layer_file("shield", GRADES[1])].tobytes(),
           "other palettes unchanged")
        # a hole in a texel the outline only crosses (its centre outside) is a violation: the rim samples it
        shape = PARAMS["shield"]["shape"]
        poly, lv = O.shield_outline(shape)
        fw, fh = SHEETS["shield_0"]["faces"]["front"][2:]

        def centre_inside(c, r):
            x, y = -lv["W"] + 2 * lv["W"] * (c + 0.5) / fw, lv["T"] - (r + 0.5) / fh * shape["height"]
            hit = False
            for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
                if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
                    hit = not hit
            return hit
        crossed = sorted(t for t in O.shield_texels(shape, "front") if not centre_inside(*t))
        ok(crossed, "the outline crosses some front texels without containing their centre")
        sh = Image.open(art2 / "shield" / "a.png").convert("RGBA")
        cut = crossed[0]
        sh.putpixel(cut, (0, 0, 0, 0))
        sh.save(art2 / "shield" / "a.png")
        try:
            B.bake(art2)
            ok(False, "a hole in a crossed edge texel fails the bake")
        except B.BakeError as e:
            ok("1 transparent texel(s) the outline contains or crosses (front face) at (%d,%d)" % cut in str(e),
               "the crossed edge hole is named: %s" % e)
        shutil.copy(ART / "shield" / "a.png", art2 / "shield" / "a.png")
        # a blank sheet of the right size is not "already reported": its rules apply (review finding)
        for rel, what in (("shield/a.png", "the outline contains or crosses (front face)"),
                          ("book/spine_a.png", "in a face"), ("book/pages_f_a.png", "in a face")):
            keep = (art2 / rel).read_bytes()
            Image.new("RGBA", Image.open(art2 / rel).size, (0, 0, 0, 0)).save(art2 / rel)
            try:
                B.bake(art2)
                ok(False, "a blank %s fails the bake" % rel)
            except B.BakeError as e:
                ok("%s: " % rel in str(e) and what in str(e)
                   and (rel != "shield/a.png" or "0 zone A (at least 6)" in str(e)),
                   "a blank %s is named with its holes (and the shield's zones): %s" % (rel, e))
            (art2 / rel).write_bytes(keep)
        bl = f2[O.layer_file("book", GRADES[1])]
        ok(bl.getpixel((fx + 1, fy + 1)) == rgba(TIERS["book"]["T2"]["palette"], "A_LIGHT"), "book T2 cover_f from variant b")
        ok(f2[O.mask_file(O.layer_file("book", GRADES[1]))].getpixel((fx + 1, fy + 1)) == (255, 255),
           "book T2 variant b's zone in the mask")
        cbx, cby = SHEETS["cover_b"]["faces"]["back"][:2]
        ok(bl.getpixel((cbx + 1, cby + 1)) == files[O.layer_file("book", GRADES[1])].getpixel((cbx + 1, cby + 1)),
           "book T2 cover_b still variant a")

        # --- the command line: write, check, a missing, a changed and an extra file ---------
        out, iout = tmp / "out", tmp / "icons"
        r = run("--art", ART, "--out", out, "--icons-out", iout)
        ok(r.returncode == 0 and len(list(out.iterdir())) == 24 and len(list(iout.iterdir())) == 24,
           "write: " + r.stdout + r.stderr)
        r = run("--art", ART, "--out", out, "--icons-out", iout, "--check")
        ok(r.returncode == 0 and "check: ok (48 files" in r.stdout, "check after write: " + r.stdout)
        (out / O.layer_file("book", GRADES[2])).unlink()
        Image.new("RGBA", SIZE, (1, 2, 3, 255)).save(out / O.layer_file("shield", GRADES[0]))
        (out / "grug_offhand_old_thing.png").write_bytes(B.png_bytes(Image.new("RGBA", (1, 1))))
        Image.new("RGBA", (16, 16)).save(iout / O.icon_file("book", GRADES[3]))
        (iout / "grug_gear_item_sword_bronze.png").write_bytes(b"")        # not the bake's: never an extra
        (out / "grug_armor_metal_bronze_head.png").write_bytes(b"")         # nor another bake's
        r = run("--art", ART, "--out", out, "--icons-out", iout, "--check")
        fails = [ln for ln in r.stdout.splitlines() if ln.startswith("FAIL ")]
        ok(r.returncode == 1 and len(fails) == 4 and any("missing" in f for f in fails)
           and sum("differs" in f for f in fails) == 2 and any("extra" in f and "old_thing" in f for f in fails),
           "check finds missing, changed (layer and icon), extra: " + r.stdout)
        r = run("--art", ART, "--out", out, "--icons-out", iout)
        ok(r.returncode == 0 and "1 removed" in r.stdout and not (out / "grug_offhand_old_thing.png").exists()
           and (out / "grug_armor_metal_bronze_head.png").exists(), "write removes only the stale grug_offhand file")
        ok(run("--art", ART, "--out", out, "--icons-out", iout, "--check").returncode == 0, "check after rewrite")
        r = run("--art", ART, "--out", out, "--sheet", tmp / "sheet.png")
        ok(r.returncode == 0 and Image.open(tmp / "sheet.png").width > 600, "contact sheet: " + r.stdout)

        # --- broken art fails with every expected message and writes nothing ----------------
        r = run("--art", TOOL / "test_art_broken", "--out", tmp / "out2", "--icons-out", tmp / "icons2")
        ok(r.returncode == 1 and r.stdout.startswith("BAKE FAIL") and not (tmp / "out2").exists()
           and not (tmp / "icons2").exists(), "broken art fails and writes nothing")
        for n, frag in MB.ERRORS:
            ok(frag in r.stdout, "broken error %d: %r not in the output" % (n, frag))
        ok(MB.WARNING in r.stdout, "broken: the warning %r" % MB.WARNING)
        violations = [ln for ln in r.stdout.splitlines()[1:] if not ln.startswith("WARNING")]
        ok(len(violations) == len(MB.ERRORS) - 1, "broken: %d violations, expected %d (no double reports):\n%s"
           % (len(violations), len(MB.ERRORS) - 1, "\n".join(violations)))
        # an icon bake needs every tier's icon
        t = json.loads((art2 / "tiers.json").read_text())
        del t["shield"]["T4"]["icon"]
        (art2 / "tiers.json").write_text(json.dumps(t))
        B.bake(art2)
        try:
            B.bake(art2, icons=True)
            ok(False, "an icon bake of a tier without 'icon' fails")
        except B.BakeError as e:
            ok("shield T4: names no 'icon'" in str(e), "icon bake names the tier: %s" % e)
        # the default art directory is absent until the finish step: a clear error
        r = run("--art", tmp / "r55_art_absent", "--out", tmp / "out3")
        ok(r.returncode == 1 and "no art directory" in r.stdout and not (tmp / "out3").exists(),
           "absent art: " + r.stdout)

    r = subprocess.run([sys.executable, str(TOOL / "make_broken_art.py"), "--check"], capture_output=True, text=True)
    ok(r.returncode == 0, "make_broken_art.py --check: " + r.stdout)

    for f in FAILS:
        print("FAIL", f)
    print("r55 offhand bake test:", "FAIL %d" % len(FAILS) if FAILS else "PASS")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
