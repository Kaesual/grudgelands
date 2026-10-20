#!/usr/bin/env python3
"""Test of bake.py on a tiny synthetic art set (Round 54 lane BAKE).

  python3 tools/r54_armor/test_bake.py      exit 1 on a failure

Proves: every reference colour lands at its atlas texel in the tier's colour;
a mirrored box is pasted once; paint outside the faces and boxes the tier does
not wear stay transparent; zone pixels appear in the right mask frame with the
light/dark grey; the skin layer is clipped to the slot's regions; every grade
gets every file; the icons; --check finds missing, extra and changed files;
broken art (a missing sheet, an off-palette colour) fails the bake.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image  # noqa: E402

TOOL = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL))
import armorlib as L  # noqa: E402
import bake as B  # noqa: E402

FAILS = []


def ok(cond, what):
    if not cond:
        FAILS.append(what)


CAT = L.load_catalog()
BOX = {b["id"]: b for b in CAT["boxes"]}
ATLAS = json.loads((L.DATA / "atlas.json").read_text())
REF = {name: L.hex_rgb(h) for _, name, h, _ in L.REFERENCE}
# a test palette with 13 distinct colours (and differing from the reference)
PAL = {name: "#%02X%02X%02X" % (10 + 15 * i, 200 - 13 * i, (37 * i) % 256)
       for i, name in enumerate(L.REF_NAMES)}
GRADES = B.grades()


def sheet(bid, paint):
    """A box sheet with `paint` {(x, y): reference name}."""
    w, h = BOX[bid]["sheet"]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for (x, y), n in paint.items():
        im.putpixel((x, y), REF[n] + (255,))
    return im


def make_art(root):
    """Every line and tier wears helm, chest and sleeve (mirrored) except metal
    T2 (nothing); pauldron has a sheet that no tier wears."""
    for ln in L.LINES:
        d = root / ln
        (d / "inner").mkdir(parents=True)
        (d / "icons").mkdir()
        fx, fy = BOX["chest"]["faces"]["front"][:2]
        paint = {(fx + i, fy): n for i, n in enumerate(L.REF_NAMES)}       # one pixel per colour
        paint[(0, 0)] = "M_MID"                                            # outside every face
        sheet("chest", paint).save(d / "chest_a.png")
        sx, sy = BOX["sleeve"]["faces"]["front"][:2]
        sheet("sleeve", {(sx, sy): "B_DARK", (sx + 1, sy): "M_DARK"}).save(d / "sleeve_a.png")
        hx, hy = BOX["helm"]["faces"]["top"][:2]
        sheet("helm", {(hx, hy): "A_DARK"}).save(d / "helm_a.png")
        px, py = BOX["pauldron"]["faces"]["front"][:2]
        sheet("pauldron", {(px, py): "M_HI"}).save(d / "pauldron_a.png")
        full = Image.new("RGBA", (64, 32), REF["A_LIGHT"] + (255,))        # paints the whole skin
        for slot in L.INNER_SLOTS:
            full.save(d / "inner" / f"{slot}_a.png")
        for slot in L.SLOTS:
            ic = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
            ic.putpixel((3, 4), REF["B_LIGHT"] + (255,))
            ic.putpixel((5, 6), REF["OUTLINE"] + (255,))
            ic.save(d / "icons" / f"{slot}_a.png")
    tier = {"palette": "test", "on": ["helm", "chest", "sleeve"],
            "inner": {s: "a" for s in L.INNER_SLOTS}, "icon": {s: "a" for s in L.SLOTS}}
    tiers = {ln: {t: dict(tier) for t in L.TIER_IDS} for ln in L.LINES}
    tiers["metal"]["T2"] = dict(tier, on=[], inner={})
    (root / "tiers.json").write_text(json.dumps(tiers))
    (root / "palettes.json").write_text(json.dumps({"palettes": {"test": {"colors": PAL}}}))


def opaque(im):
    return {(x, y) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[-1]}


def run(*args):
    return subprocess.run([sys.executable, str(TOOL / "bake.py"), *map(str, args)],
                          capture_output=True, text=True)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        art = tmp / "art"
        make_art(art)
        files, icons = B.bake(art, icons=True)
        g1 = GRADES["metal"][0]

        # file set: 72 atlas + 54 skin layers, each with its mask; 72 icons + masks
        ok(len(files) == 2 * (72 + 54), f"game file count {len(files)}")
        ok(len(icons) == 2 * 72, f"icon file count {len(icons)}")
        for ln in L.LINES:
            for g in GRADES[ln]:
                for s in L.SLOTS:
                    stem = f"grug_armor_{ln}_{g}_{s}"
                    ok(files.get(stem + ".png") and files[stem + ".png"].size == (128, 64)
                       and files[stem + ".png"].mode == "RGBA", f"{stem}.png")
                    ok(files.get(stem + "_ench.png") and files[stem + "_ench.png"].size == (128, 128)
                       and files[stem + "_ench.png"].mode == "LA", f"{stem}_ench.png")
                    if s != "head":
                        ok(files.get(stem + "_skin.png") and files[stem + "_skin.png"].size == (64, 32),
                           f"{stem}_skin.png")
                        ok(files.get(stem + "_skin_ench.png") and
                           files[stem + "_skin_ench.png"].size == (64, 64), f"{stem}_skin_ench.png")
                    else:
                        ok(stem + "_skin.png" not in files, "head has no skin layer")

        chest = files[f"grug_armor_metal_{g1}_chest.png"]
        mask = files[f"grug_armor_metal_{g1}_chest_ench.png"]
        ax, ay = ATLAS["boxes"]["chest"]["faces"]["front"][:2]
        # every reference colour at its texel, in the tier palette's colour
        for i, n in enumerate(L.REF_NAMES):
            ok(chest.getpixel((ax + i, ay)) == L.hex_rgb(PAL[n]) + (255,), f"colour {n} at its atlas texel")
        # zones in the right frame, light 255 / dark 153; other colours unmasked
        for i, n in enumerate(L.REF_NAMES):
            top, bottom = mask.getpixel((ax + i, ay)), mask.getpixel((ax + i, ay + 64))
            want = B.ZONE_GREY.get(n)
            if want is None:
                ok(top[1] == 0 and bottom[1] == 0, f"{n} not in a mask frame")
            else:
                hit, miss = (top, bottom) if want[0] == 0 else (bottom, top)
                ok(hit == (want[1], 255) and miss[1] == 0, f"{n} in mask frame {want[0]} grey {want[1]}")
        # paint outside the faces is dropped
        rx, ry = ATLAS["boxes"]["chest"]["rect"][:2]
        ok(chest.getpixel((rx, ry))[3] == 0, "paint outside the faces stays transparent")
        # mirrored sleeve: pasted once, at its one rectangle; nothing else in the layer
        sx, sy = ATLAS["boxes"]["sleeve"]["faces"]["front"][:2]
        want = {(ax + i, ay) for i in range(13)} | {(sx, sy), (sx + 1, sy)}
        ok(opaque(chest) == want, f"chest layer opaque exactly at the painted texels ({len(opaque(chest))})")
        ok(mask.getpixel((sx, sy + 64)) == (153, 255), "sleeve B_DARK in frame 1")
        # a box the tier does not wear stays transparent (pauldron has a sheet)
        px, py, pw, ph = ATLAS["boxes"]["pauldron"]["rect"]
        ok(not any(px <= x < px + pw and py <= y < py + ph for x, y in opaque(chest)), "unworn pauldron transparent")
        # head layer: the helm top pixel; legs and feet layers empty
        hx, hy = ATLAS["boxes"]["helm"]["faces"]["top"][:2]
        head = files[f"grug_armor_metal_{g1}_head.png"]
        ok(opaque(head) == {(hx, hy)}, "head layer holds only the helm pixel")
        ok(files[f"grug_armor_metal_{g1}_head_ench.png"].getpixel((hx, hy)) == (153, 255), "helm A_DARK frame 0")
        for s in ("legs", "feet"):
            ok(not opaque(files[f"grug_armor_metal_{g1}_{s}.png"]), f"{s} layer empty")
        # a tier that wears nothing: every file present and transparent
        g2 = GRADES["metal"][1]
        for name, im in files.items():
            if name.startswith(f"grug_armor_metal_{g2}_"):
                ok(not opaque(im), f"{name} transparent (tier wears nothing)")
        # skin layers clipped to the slot regions, A_LIGHT mask at 255
        for s in L.INNER_SLOTS:
            sk = files[f"grug_armor_metal_{g1}_{s}_skin.png"]
            ok(opaque(sk) == L.skin_region_mask(CAT, s), f"{s} skin layer clipped to its regions")
            sm = files[f"grug_armor_metal_{g1}_{s}_skin_ench.png"]
            ok(opaque(sm) == L.skin_region_mask(CAT, s), f"{s} skin mask = zone A over the region")
        # icon and its mask
        ic = icons[f"grug_gear_item_head_metal_{g1}.png"]
        icm = icons[f"grug_gear_item_head_metal_{g1}_ench.png"]
        ok(ic.size == (16, 16) and ic.getpixel((3, 4)) == L.hex_rgb(PAL["B_LIGHT"]) + (255,), "icon colour")
        ok(icm.size == (16, 32) and icm.getpixel((3, 20)) == (255, 255) and icm.getpixel((3, 4))[1] == 0
           and icm.getpixel((5, 22))[1] == 0, "icon mask frame 1")
        # deterministic
        again, _ = B.bake(art)
        ok(all(B.png_bytes(again[n]) == B.png_bytes(im) for n, im in files.items()), "bake is deterministic")

        # the command line: write, check, then a missing, a changed and an extra file
        out, iout = tmp / "out", tmp / "icons"
        r = run("--art", art, "--out", out, "--icons-out", iout)
        ok(r.returncode == 0 and len(list(out.iterdir())) == 252 and len(list(iout.iterdir())) == 144,
           "write: " + r.stdout + r.stderr)
        r = run("--art", art, "--out", out, "--icons-out", iout, "--check")
        ok(r.returncode == 0, "check after write: " + r.stdout)
        victim = out / f"grug_armor_cloth_{GRADES['cloth'][2]}_legs.png"
        victim.unlink()
        Image.new("RGBA", (128, 64), (1, 2, 3, 255)).save(out / f"grug_armor_metal_{g1}_feet.png")
        (out / "grug_armor_old_thing.png").write_bytes(B.png_bytes(Image.new("RGBA", (1, 1))))
        Image.new("RGBA", (16, 16)).save(iout / f"grug_gear_item_feet_cloth_{GRADES['cloth'][0]}.png")
        (iout / "grug_gear_item_sword_bronze.png").write_bytes(b"")        # not the bake's: never an extra
        r = run("--art", art, "--out", out, "--icons-out", iout, "--check")
        ok(r.returncode == 1 and "missing" in r.stdout and "differs" in r.stdout and "extra" in r.stdout
           and sum(ln.startswith("FAIL ") for ln in r.stdout.splitlines()) == 4, "check finds missing, changed, extra: " + r.stdout)
        r = run("--art", art, "--out", out, "--icons-out", iout)
        ok(r.returncode == 0 and "1 removed" in r.stdout and not (out / "grug_armor_old_thing.png").exists(),
           "write removes the stale grug_armor file: " + r.stdout)
        ok(run("--art", art, "--out", out, "--icons-out", iout, "--check").returncode == 0, "check after rewrite")

        # broken art fails the bake with the reason
        (art / "metal" / "sleeve_a.png").unlink()
        bad = sheet("chest", {})
        bad.putpixel(tuple(BOX["chest"]["faces"]["front"][:2]), (1, 2, 3, 255))
        bad.save(art / "leather" / "chest_a.png")
        r = run("--art", art, "--out", tmp / "out2")
        ok(r.returncode == 1 and "missing" in r.stdout and "off the reference palette" in r.stdout
           and not (tmp / "out2").exists(), "broken art fails: " + r.stdout)

    for f in FAILS:
        print("FAIL", f)
    print("r54 bake test:", "FAIL %d" % len(FAILS) if FAILS else "PASS")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
