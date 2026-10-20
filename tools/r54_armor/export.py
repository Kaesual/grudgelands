#!/usr/bin/env python3
"""Export the frozen armor catalog for the render/check tool.

Writes
  data/catalog.json   boxes (slot, bone, rest box, rotation, mirror, texels,
                      sheet size, face rectangles), bones, slots with their
                      inner skin regions, the body boxes, and the per line/tier
                      selections in the texture-format §7 shape;
  data/palettes.json  the reference palette and the 18 tier palettes
                      (placeholder colours expanded from catalog.py);
  data/skins/<race>_{hair,bald}.png   the composed race skins (from the game
                      repo, read only) so rendering needs no repo access.

Hand edits survive a re-export: the `palette`, `variant`, `inner` and `icon`
fields of an existing data/catalog.json are kept (only `on` is refreshed from
tiers_example.json), and an existing data/palettes.json is kept unless --force.
"""
import argparse
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True   # never write __pycache__ into the tool folder
TOOL = Path(__file__).resolve().parent
PROTO = TOOL
sys.path.insert(0, str(TOOL))
# catalog.py and skins.py live next to this file
import armorlib as L  # noqa: E402
import catalog as P  # noqa: E402  (catalog.py)
import skins  # noqa: E402  (skins.py; reads the game repo textures, read only)

SLOT_OF = {
    "helm": "head", "visor": "head",
    "chest": "chest", "belt": "chest", "sleeve": "chest", "bracer": "chest", "pauldron": "chest",
    "reinforce": "chest", "flare": "chest", "spike": "chest",
    "panel_f": "legs", "panel_b": "legs", "tasset": "legs", "thigh": "legs", "knee": "legs",
    "boot": "feet", "toe": "feet",
}
LABEL_EN = {
    "helm": "helm shell", "visor": "visor", "chest": "chest shell", "belt": "belt",
    "panel_f": "front panel", "panel_b": "back panel", "tasset": "tasset", "sleeve": "sleeve shell",
    "bracer": "bracer", "pauldron": "shoulder core", "reinforce": "shoulder reinforcement",
    "flare": "shoulder flare", "spike": "shoulder spike", "thigh": "thigh", "knee": "knee cop",
    "boot": "boot shell", "toe": "toe cap",
}
# Inner regions on the 64x32 skin, (x0, y0, x1, y1) exclusive ends (spec §3)
INNER_REGIONS = {
    "chest": [[16, 16, 40, 32], [40, 16, 56, 32]],
    "legs": [[0, 20, 16, 28]],
    "feet": [[0, 28, 16, 32]],
    "head": [],
}
# Body boxes of character.b3d with their skin UV origin and texel dims (w, h, d)
BODY = [
    {"id": "head", "bone": "head", "box": [-4, 24, -4, 4, 32, 4], "uv": [0, 0], "dims": [8, 8, 8], "mirror": False},
    {"id": "hat", "bone": "head", "box": [-4.5, 23.5, -4.5, 4.5, 32.5, 4.5], "uv": [32, 0], "dims": [8, 8, 8], "mirror": False},
    {"id": "torso", "bone": "body", "box": [-4, 12, -2, 4, 24, 2], "uv": [16, 16], "dims": [8, 12, 4], "mirror": False},
    {"id": "arm", "bone": "arm_r", "box": [-8, 12, -2, -4, 24, 2], "uv": [40, 16], "dims": [4, 12, 4], "mirror": True},
    {"id": "leg", "bone": "leg_r", "box": [-4, 0, -2, 0, 12, 2], "uv": [0, 16], "dims": [4, 12, 4], "mirror": True},
]


def expand_palette(p):
    """prototype light/mid/dark/trim(/glow) -> the 13 reference names (placeholders)."""
    lt, md, dk, tr = (L.hex_rgb(p[k]) for k in ("light", "mid", "dark", "trim"))

    def mix(a, b, t):
        return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

    def sc(a, f):
        return tuple(max(0, min(255, round(v * f))) for v in a)

    linen = L.hex_rgb(P.CLOTH)
    acc_l, acc_d = L.hex_rgb(P.LEATHER[0]), L.hex_rgb(P.LEATHER[1])
    c = {
        "M_HI": mix(lt, (255, 255, 255), 0.35), "M_LIGHT": lt, "M_MID": md, "M_DARK": dk,
        "M_DEEP": sc(dk, 0.7), "OUTLINE": sc(dk, 0.4),
        "ACC_LIGHT": acc_l, "ACC_DARK": acc_d,
        "A_LIGHT": linen, "A_DARK": sc(linen, 0.78),
        "B_LIGHT": tr, "B_DARK": sc(tr, 0.72),
        "GLOW": L.hex_rgb(p["glow"]) if "glow" in p else lt,
    }
    return {k: L.rgb_hex(v) for k, v in c.items()}


def build_boxes():
    out = []
    for b in P.boxes():
        x0, y0, z0, x1, y1, z1 = b["box"]
        w, h, d = x1 - x0, y1 - y0, z1 - z0
        W, H, D = L.texels(w), L.texels(h), L.texels(d)
        rot = None
        if b["rot"]:
            axis, deg, o = b["rot"]
            rot = [axis, deg, list(o)]
        out.append({
            "id": b["id"], "label": b["label"], "label_en": LABEL_EN[b["id"]], "area": b["area"],
            "slot": SLOT_OF[b["id"]], "bone": b["bone"], "box": list(b["box"]), "size": [w, h, d],
            "rot": rot, "mirror": b["mirror"], "texels": [W, H, D],
            "sheet": list(L.sheet_size(W, H, D)),
            "faces": {k: list(v) for k, v in L.sheet_faces(W, H, D).items()},
        })
    return out


def build_tiers(old):
    src = json.loads((PROTO / "tiers_example.json").read_text())
    tiers = {}
    for line in L.LINES:
        tiers[line] = {}
        for T in P.LINES[line]["tiers"]:
            tid = T["tier"]
            prev = ((old or {}).get(line) or {}).get(tid) or {}
            tiers[line][tid] = {
                "palette": prev.get("palette", T["pal"]),
                "on": list(src[line][tid]),
                "variant": prev.get("variant", {}),
                "inner": prev.get("inner", {"chest": "a", "legs": "a", "feet": "a"}),
                "icon": prev.get("icon", {"head": "a", "chest": "a", "legs": "a", "feet": "a"}),
            }
    return tiers


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--force", action="store_true", help="overwrite palettes.json and the tier fields")
    ap.add_argument("--check", action="store_true",
                    help="write nothing; exit 1 if data/catalog.json or data/skins/ differ from a fresh export")
    a = ap.parse_args()
    L.DATA.mkdir(exist_ok=True)
    cat_path = L.DATA / "catalog.json"
    old = None
    if cat_path.exists() and not a.force:
        old = json.loads(cat_path.read_text()).get("tiers")
    boxes = build_boxes()
    slots = {s: {"boxes": [b["id"] for b in boxes if b["slot"] == s], "inner_regions": INNER_REGIONS[s]}
             for s in L.SLOTS}
    cat = {
        "_doc": "Generated by export.py from catalog.py and tiers_example.json; spec: docs/technical/armor-format.md. "
                "Units: skin pixels, rest pose, y up from the soles, +z forward, the character's right is -x. "
                "box = [x0,y0,z0,x1,y1,z1]; rot = [axis, degrees, origin] applied about origin; mirror = a left "
                "copy mirrored in x shares the sheet. faces: [x, y, w, h] on the sheet. Tier fields palette/variant/"
                "inner/icon are kept on re-export (hand edits allowed).",
        "bones": {k: list(v) for k, v in P.BONES.items()},
        "boxes": boxes,
        "slots": slots,
        "body": BODY,
        "reference": [{"index": i, "name": n, "hex": h, "meaning": m} for i, n, h, m in L.REFERENCE],
        "tiers": build_tiers(old),
        "stature": dict(skins.STATURE),
    }
    if a.check:
        bad = []
        if not cat_path.exists() or json.loads(cat_path.read_text()) != json.loads(json.dumps(cat)):
            bad.append(str(cat_path))
        for race in skins.LOOKS:
            for hair, tag in ((True, "hair"), (False, "bald")):
                p = L.DATA / "skins" / f"{race}_{tag}.png"
                if not p.exists() or L.load_rgba(p).tobytes() != skins.compose(race, hair).tobytes():
                    bad.append(str(p))
        for p in bad:
            print("STALE", p)
        print("export check:", "FAIL (run python3 export.py)" if bad else "ok")
        return 1 if bad else 0
    cat_path.write_text(json.dumps(cat, indent=1, ensure_ascii=False))
    print("wrote", cat_path, len(boxes), "boxes,", sum(2 if b["mirror"] else 1 for b in boxes), "with mirrored copies")

    pal_path = L.DATA / "palettes.json"
    if a.force or not pal_path.exists():
        line_of = {T["pal"]: (ln, T["tier"]) for ln in L.LINES for T in P.LINES[ln]["tiers"]}
        pals = {
            "_doc": "Tier palettes: reference colour name -> tier colour. Placeholder values expanded from "
                    "catalog.py PALETTES; the coordinator tunes them. GLOW = M_LIGHT where a palette has no glow.",
            "reference": {n: h for _, n, h, _ in L.REFERENCE},
            "palettes": {},
        }
        for key, (ln, tid) in line_of.items():
            p = P.PALETTES[key]
            pals["palettes"][key] = {"name": p["name"], "line": ln, "tier": tid, "colors": expand_palette(p)}
        pal_path.write_text(json.dumps(pals, indent=1, ensure_ascii=False))
        print("wrote", pal_path, len(pals["palettes"]), "palettes")
    else:
        print("kept", pal_path, "(use --force to regenerate)")

    sk = L.DATA / "skins"
    sk.mkdir(exist_ok=True)
    for race in skins.LOOKS:
        skins.compose(race, True).save(sk / f"{race}_hair.png")
        skins.compose(race, False).save(sk / f"{race}_bald.png")
    print("wrote", sk, len(skins.LOOKS), "races")


if __name__ == "__main__":
    sys.exit(main())
