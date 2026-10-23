#!/usr/bin/env python3
"""Round 57 lane FIX56: the chin strip's underside (ruling 24) in the armor check.

  python3 tools/r57_fix56/test_chin.py

Checks, with tools/r54_armor (armorlib, check.py) and the shipped art in
tools/r54_art/art:
  - armorlib.chin_under is the helm bottom face's three front rows (the rows
    that start in front of the neck), full width: 30 texels;
  - the hood's polygon part reaches below the helm's top only behind the
    head (z <= -4.75), so it shows nothing under the chin;
  - check.py passes the shipped art with no violation;
  - on the shipped sheets, the open chin (the strip and its underside) is
    transparent on every chin-strip tier's helm (cloth T1-T6, leather T1-T5)
    and opaque on leather T6 and every metal helm;
  - on copies of the art, check.py refuses the underside opened on the leather
    T6 helm and on a metal helm, and a texel opened behind the underside (the
    fourth row, under the neck) on a cloth helm.
Prints "R57 FIX56 CHIN PASS checks=<n>" or the failures; exit 1 on failure.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
TOOL = REPO / "tools" / "r54_armor"
ART = REPO / "tools" / "r54_art" / "art"
sys.path.insert(0, str(TOOL))
from PIL import Image  # noqa: E402

import armorlib as L  # noqa: E402

checks, failures = 0, []


def check(ok, label):
    global checks
    checks += 1
    if not ok:
        failures.append(label)


def run_check(art):
    run = subprocess.run([sys.executable, str(TOOL / "check.py"), "--art", str(art), "--quiet-overlaps"],
                         cwd=TOOL, capture_output=True, text=True)
    return run.returncode, run.stdout + run.stderr


def main():
    cat = L.load_catalog()
    helm = next(b for b in cat["boxes"] if b["id"] == "helm")
    fx, fy, fw, fh = helm["faces"]["bottom"]
    under = L.chin_under(helm)
    check(under == {(fx + c, fy + r) for r in range(3) for c in range(fw)},
          f"chin_under is the bottom face's three front rows (got {sorted(under)})")
    check(L.chin_texels(helm) == under | L.chin_row(helm), "chin_texels is the strip and its underside")
    check(not L.chin_under(next(b for b in cat["boxes"] if b["id"] == "visor")), "only the helm has an underside")
    # the hood (polygon part): below the helm's top it lies wholly behind the head, so none of its faces reaches
    # under the chin
    hood = next(b for b in L.pieces(cat) if b["id"] == "hood")
    low = [v for v in hood["vertices"] if v[1] < helm["box"][4] - 1e-6]
    check(low and all(v[2] <= -L.FACE_RECT[2] - 0.75 + 1e-6 for v in low),
          f"the hood shows nothing under the chin (vertices below the helm's top: {low})")

    code, out = run_check(ART)
    check(code == 0 and "no violations" in out, "check.py passes the shipped art:\n" + out[-600:])

    pals, _, _ = L.load_palettes(ART, None)
    tiers, _, errors = L.load_tiers(cat, pals, ART)
    check(not errors, f"shipped tiers load ({errors})")
    sheets = {}
    for line in L.LINES:
        for tid, T in tiers[line].items():
            if "helm" in T["on"]:
                sheets.setdefault((line, L.tier_variant(T, "helm")), []).append(tid)
    for (line, var), tids in sorted(sheets.items()):
        im = Image.open(L.box_file(ART, line, "helm", var)).convert("RGBA")
        alphas = [im.getpixel(xy)[3] for xy in sorted(L.chin_texels(helm))]
        if L.chin_open(line, tids):
            check(all(a == 0 for a in alphas), f"{line} helm_{var} ({tids}): the open chin is transparent")
        else:
            check(all(a == 255 for a in alphas), f"{line} helm_{var} ({tids}): the chin stays opaque")
    check(L.chin_open("leather", ["T6"]) is False and L.chin_open("metal", ["T1"]) is False,
          "leather T6 and metal keep the chin closed")

    def variant(line, tid):
        return L.tier_variant(tiers[line][tid], "helm")

    cases = [("leather", "T6", sorted(under), True, "the underside on the leather T6 helm"),
             ("metal", "T3", sorted(under), True, "the underside on a metal helm"),
             ("cloth", "T1", [(fx + 4, fy + 3)], True, "a texel behind the underside on a cloth helm"),
             ("cloth", "T1", sorted(under), False, "the underside on a cloth helm (as shipped)")]
    for line, tid, texels, refused, label in cases:
        with tempfile.TemporaryDirectory(prefix="r57_fix56_chin.") as tmp:
            art = Path(tmp) / "art"
            shutil.copytree(ART, art)
            path = L.box_file(art, line, "helm", variant(line, tid))
            im = Image.open(path).convert("RGBA")
            for xy in texels:
                im.putpixel(xy, (0, 0, 0, 0))
            im.save(path)
            code, out = run_check(art)
            rel = f"{line}/helm_{variant(line, tid)}.png"
            hit = code == 1 and f"{rel}: " in out and "transparent texel" in out
            if refused:
                check(hit, f"check.py refuses {label} ({rel}):\n" + out[-600:])
            else:
                check(code == 0, f"check.py allows {label} ({rel}):\n" + out[-600:])

    for f in failures:
        print("FAIL", f)
    print(f"R57 FIX56 CHIN {'FAIL' if failures else 'PASS'} checks={checks}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
