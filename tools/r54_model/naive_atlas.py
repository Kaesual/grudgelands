#!/usr/bin/env python3
"""A stand-in armor texture for model screenshots (Round 54 lane MODEL).

Not the bake (lane BAKE's tools/r54_armor/bake.py makes the game's files):
this pastes, for one line and tier of an art directory, every worn box sheet
`<line>/<box>_<variant>.png` into its rectangle of tools/r54_armor/data/
atlas.json and the inner paint onto the race skin, both with the tier's
palette, the same way tools/r54_armor/render.py composes them for its
contact sheets. The capture probe (capture.sh) shows the result on the real
models, so a screenshot can be held against

    python3 tools/r54_armor/render.py --art tools/r54_armor/test_art \
        --line metal --tiers T6 --detail --out OUT

    python3 tools/r54_model/naive_atlas.py --art tools/r54_armor/test_art \
        --line metal --tier T6 --out DIR [--race human] [--name PREFIX] \
        [--palette steel]

writes DIR/<PREFIX>_atlas.png (128x64) and DIR/<PREFIX>_skin.png (64x32);
PREFIX defaults to r54model_<line>_<tier>. Python 3 + Pillow (the armor
tool's own helpers, tools/r54_armor/armorlib.py).
"""
import argparse
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools/r54_armor"))
import armorlib as L  # noqa: E402
from PIL import Image  # noqa: E402


def compose(art, line, tier_id, race, palette=None):
    cat = L.load_catalog()
    atlas = json.loads((L.DATA / "atlas.json").read_text())
    pals, _, errors = L.load_palettes(art)
    tiers, notes, more = L.load_tiers(cat, pals, art)
    for message in errors + more:
        print("naive_atlas:", message)
    tier = tiers[line][tier_id]
    mapping = L.palette_map(pals, palette or tier["palette"])
    width, height = atlas["size"]
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for box in cat["boxes"]:
        if box["id"] not in tier["on"]:
            continue
        path = L.box_file(art, line, box["id"], L.tier_variant(tier, box["id"]))
        x, y, w, h = atlas["boxes"][box["id"]]["rect"]
        if path.exists():
            im = L.apply_palette(L.load_rgba(path), mapping)
        else:
            print("naive_atlas: missing", path)
            im = L.checker((w, h))
        if im.size != (w, h):
            raise SystemExit("naive_atlas: %s is %dx%d, its atlas rectangle %dx%d" % (path, *im.size, w, h))
        sheet.paste(im, (x, y))
    helm = any(b in tier["on"] for b in ("helm", "visor"))
    skin = L.load_rgba(L.DATA / "skins" / ("%s_%s.png" % (race, "bald" if helm else "hair")))
    for slot in L.INNER_SLOTS:
        variant = (tier.get("inner") or {}).get(slot)
        path = L.inner_file(art, line, slot, variant) if variant else None
        if path and path.exists():
            skin.alpha_composite(L.apply_palette(L.load_rgba(path), mapping))
    return sheet, skin


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--art", required=True)
    ap.add_argument("--line", required=True, choices=L.LINES)
    ap.add_argument("--tier", required=True, choices=L.TIER_IDS)
    ap.add_argument("--race", default="human")
    ap.add_argument("--out", required=True)
    ap.add_argument("--name")
    ap.add_argument("--palette", help="another tier palette (e.g. steel: the orientation letters read better)")
    a = ap.parse_args()
    sheet, skin = compose(a.art, a.line, a.tier, a.race, a.palette)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    name = a.name or "r54model_%s_%s" % (a.line, a.tier)
    sheet.save(out / (name + "_atlas.png"))
    skin.save(out / (name + "_skin.png"))
    print("naive_atlas: wrote %s_atlas.png and %s_skin.png in %s" % (name, name, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
