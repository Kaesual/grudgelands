#!/usr/bin/env python3
"""Enchant-colour masks for every weapon and armour texture (Round 31 lane B,
docs/planning/round31-plan.md section 2.2).

For each source texture the script derives two non-overlapping pixel groups
from the texture's own colour clusters and writes ONE mask file next to it:

    <source stem>_ench.png   width W, height 2*H, greyscale + alpha
        top frame    group A (accents)  -> the prefix stat's colour
        bottom frame group B (fittings) -> the suffix stat's colour

A mask pixel is opaque exactly where its group is; its grey value is the
source pixel's shading inside the group, rescaled to 0.6..1.0, so
`[multiply:<stat colour>` keeps the item's light and dark steps. The engine
picks a frame with `[verticalframe:2:0` / `[verticalframe:2:1` (no comma in
the modifier, so the string is safe inside formspec elements too); the full
modifier is `grug_gear.enchant_image` in mods/ITEMS/grug_gear/enchant_colors.lua.

How the groups are found (no hand-painted pixels):
  1. Only fully opaque source pixels take part (alpha 255): a coloured pixel
     can never fall outside the texture or change its silhouette.
  2. Distinct colours are clustered into MATERIALS by their OKLab (a, b)
     chroma (lightness ignored, so one ramp of a material stays together;
     greys collapse into one neutral material). The biggest is the main
     material, every other one a secondary material.
  3. An OUTLINE colour (the texture's darkest colour, mostly on the
     silhouette edge) never takes part.
  4. Group B (fittings) is the largest secondary material that is big enough
     (a hilt, a handle, a strap, a trim); without one, the darkest
     non-outline tones of the main material.
  5. Group A (accents) is the brightest tones of the main material (edge
     highlights, sheen) that are not in B.
  Both groups take whole colours, brightest (A) or darkest (B) first, until
  they reach TARGET of the opaque pixels, and stop before CAP.
  When a texture fails (a group too small, or too much of the texture), the
  OVERRIDES table names the source colours of its groups instead.

Every result is checked: A and B inside the opaque pixels, A and B disjoint,
both at least the minimum size (MIN_PIXELS and MIN_SHARE of the opaque
pixels), neither above MAX_SHARE.

    python3 tools/r31_b/gen_enchant_masks.py            # write the masks
    python3 tools/r31_b/gen_enchant_masks.py --check    # fixture: rebuild in
        memory, compare every pixel with the shipped file, check the groups
    python3 tools/r31_b/gen_enchant_masks.py --report   # per-texture table

Masks inherit the licence of their source texture (they carry its shapes and
shading); see the LICENSE-media.md rows of grug_gear and grug_visuals.
"""
import argparse
import io
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GEAR = ROOT / "mods/ITEMS/grug_gear/textures"
VISUALS = ROOT / "mods/PLAYER/grug_visuals/textures"

# The six material keys per line, as grug_gear.MATERIALS lists them.
METALS = ["bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"]
CLOTH = ["patch", "woven", "heavy", "silkweave", "silk", "stormweave"]
LEATHER = ["light", "cured", "heavy", "scaled", "sleek", "nightscale"]
LINES = {"metal": METALS, "cloth": CLOTH, "leather": LEATHER}
SLOTS = ["head", "chest", "legs", "feet"]


def sources():
    """(directory, stem, kind) for every texture an enchantable item shows.

    Mirrors grug_gear/init.lua: weapon sprites per family and metal, the four
    bow files (BOW_IMAGE), the six shields, the one spellbook, the 72 armour
    icons; and grug_visuals' 72 worn overlays (compose.lua OVERLAY).
    """
    out = []
    for family in ["sword", "dagger", "greataxe", "staff", "wand"]:
        for metal in METALS:
            out.append((GEAR, "grug_gear_item_%s_%s" % (family, metal), "item"))
    for bow in ["lebethron", "birch", "mallorn", "alder"]:
        out.append((GEAR, "grug_gear_bow_" + bow, "item"))
    for metal in METALS:
        out.append((GEAR, "grug_gear_shield_" + metal, "item"))
    out.append((GEAR, "grug_gear_spellbook", "item"))
    for line, grades in LINES.items():
        for slot in SLOTS:
            for grade in grades:
                out.append((GEAR, "grug_gear_item_%s_%s_%s" % (slot, line, grade), "item"))
    for line, grades in LINES.items():
        for slot in SLOTS:
            for grade in grades:
                out.append((VISUALS, "grug_visuals_%s_%s_%s" % (line, slot, grade), "worn"))
    return out


# A group grows (whole colours) until it covers TARGET of the opaque pixels
# and never past CAP. Worn overlays take less: on the body all four pieces
# show at once and at a larger size.
TARGET = {"item": 0.14, "worn": 0.10}
CAP = {"item": 0.25, "worn": 0.18}
MIN_PIXELS = {"item": 5, "worn": 8}
MIN_SHARE = 0.05   # each group at least this share of the opaque pixels
MAX_SHARE = 0.30   # each group at most this share (checked)
MATERIAL_SPLIT = 0.045  # OKLab chroma distance that separates two materials
OUTLINE_DARK = 48  # a darkest colour below this brightness is outline anyway
TONE_FLOOR = 0.6   # darkest pixel of a group multiplies the colour by 0.6

# Textures where the automatic split fails, with the source colours of each
# group (hex, as in the PNG). Found with --report.
OVERRIDES = {}
# The six greataxes share one map: the dark outline and haft colour covers
# half the sprite and the head body another third, so no whole colour fits
# a group. A = the head's highlight, B = the haft fittings and the head's rim.
for _metal, _light, _rim in [("bronze", "ffad70", "5b2d18"), ("iron", "d7dad8", "383b3e"),
                             ("steel", "eef3f2", "34383d"), ("silversteel", "f3fbff", "48535c"),
                             ("embersteel", "ffd06a", "4a1713"),
                             ("abyssal_steel", "d5c2f1", "302447")]:
    OVERRIDES["grug_gear_item_greataxe_" + _metal] = {
        "a": [_light], "b": ["986335", "c18a4d", _rim]}
OVERRIDES.update({
    # Its main gold tones are 32 % and 40 %: A = the highlight, B = the rim.
    "grug_gear_shield_embersteel": {"a": ["e8d4aa"], "b": ["ab7d19"]},
    # The Woven Hood icon is a 16-pixel band (the source art is that thin),
    # too small for the size rule: the two light cord tones (A) and the two
    # light cloth tones (B); reported to the user as a weak icon.
    "grug_gear_item_head_cloth_woven": {
        "a": ["a3a1a1", "c5c5c5"], "b": ["2d4b27", "2b4f28"], "weak": True},
    # Light leather is one ramp whose middle tones are each a third of the
    # piece: A = the three light tones, B = the darkest seam tone.
    "grug_gear_item_legs_leather_light": {
        "a": ["9a947f", "a6a48f", "b6b7a4"], "b": ["605244"]},
    "grug_gear_item_feet_leather_light": {
        "a": ["9a947f", "a6a48f", "b6b7a4"], "b": ["605244"]},
    # Flat grey shoes on a black sole (the outline colour): A = the lightest
    # grey, B = the sole.
    "grug_visuals_cloth_feet_silkweave": {"a": ["8d8d8d", "8d8e8d"], "b": ["000000"]},
})


def srgb_to_linear(v):
    v = v / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def oklab(rgb):
    r, g, b = (srgb_to_linear(c) for c in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(x) ** (1 / 3), x) for x in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def brightness(rgb):
    # The engine's SColor::getBrightness.
    return 0.3 * rgb[0] + 0.59 * rgb[1] + 0.11 * rgb[2]


def hexcolor(rgb):
    return "%02x%02x%02x" % rgb


def load(directory, stem):
    image = Image.open(directory / (stem + ".png")).convert("RGBA")
    w, h = image.size
    px = image.load()
    return image, w, h, px


def materials(colors):
    """Complete-linkage clustering of the distinct colours on OKLab (a, b).

    `colors` maps rgb -> pixel count. Returns a list of sets of rgb, the
    biggest material first (ties broken by the colours themselves).
    """
    feats = {c: oklab(c)[1:] for c in colors}
    clusters = [{c} for c in sorted(colors)]

    def dist(p, q):
        return max(math.hypot(feats[a][0] - feats[b][0], feats[a][1] - feats[b][1])
                   for a in p for b in q)
    while len(clusters) > 1:
        best = None
        for i in range(len(clusters)):
            for j in range(i + 1, len(clusters)):
                d = dist(clusters[i], clusters[j])
                if best is None or d < best[0]:
                    best = (d, i, j)
        if best[0] > MATERIAL_SPLIT:
            break
        _, i, j = best
        clusters[i] = clusters[i] | clusters[j]
        del clusters[j]
    clusters.sort(key=lambda c: (-sum(colors[x] for x in c), sorted(c)))
    return clusters


def take(tones, colors, goal, cap):
    """Whole colours from `tones` (already ordered) until `goal` pixels; a
    colour that would carry the group past `cap` is skipped."""
    picked, count = [], 0
    for c in tones:
        if count >= goal:
            break
        if count + colors[c] > cap:
            continue
        picked.append(c)
        count += colors[c]
    return picked


def split(directory, stem, kind):
    """The two groups as sets of (x, y), and how they were found."""
    _, w, h, px = load(directory, stem)
    opaque = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] == 255]
    colors = {}
    for x, y in opaque:
        c = px[x, y][:3]
        colors[c] = colors.get(c, 0) + 1
    n = len(opaque)
    override = OVERRIDES.get(stem)
    if override:
        a_set = {tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for v in override["a"]}
        b_set = {tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for v in override["b"]}
        method = "override"
    else:
        # The outline colour: the darkest one, if most of its pixels touch the
        # silhouette (a transparent 4-neighbour or the image border).
        def on_edge(x, y):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] < 255:
                    return True
            return False
        deepest = min(colors, key=lambda c: (brightness(c), c))
        edge = sum(1 for x, y in opaque if px[x, y][:3] == deepest and on_edge(x, y))
        outline = {deepest} if (edge >= 0.6 * colors[deepest] or
                               brightness(deepest) < OUTLINE_DARK) else set()
        mats = [sorted(m) for m in
                materials({c: k for c, k in colors.items() if c not in outline})]
        goal = TARGET[kind] * n
        minimum = max(MIN_PIXELS[kind], MIN_SHARE * n)
        main = mats[0]
        others = [c for m in mats[1:] for c in m]

        def brightest(group):
            return sorted(group, key=lambda c: (-brightness(c), c))

        def darkest(group):
            return sorted(group, key=lambda c: (brightness(c), c))

        def enough(picked):
            return sum(colors[c] for c in picked) >= minimum

        def choose(cap):
            # B: the largest big-enough secondary material (all of it up to
            # the cap, brightest tones first); else the main material's dark
            # tones; else the dark tones of whatever else there is.
            b_set, method = [], "tones"
            for m in mats[1:]:
                if sum(colors[c] for c in m) >= minimum:
                    b_set, method = take(brightest(m), colors, n, cap), "material"
                    break
            if not enough(b_set):
                b_set, method = take(darkest(main), colors, goal, cap), "tones"
            if not enough(b_set):
                b_set, method = take(darkest(others), colors, goal, cap), "other"
            # A: the main material's bright tones; else any other bright tones.
            a_set = take([c for c in brightest(main) if c not in b_set], colors, goal, cap)
            if not enough(a_set):
                a_set = take([c for c in brightest(main + others) if c not in b_set],
                             colors, goal, cap)
            return a_set, b_set, method
        # A worn overlay whose tones are too coarse for its smaller cap gets
        # the item cap.
        a_set, b_set, method = choose(CAP[kind] * n)
        if not (enough(a_set) and enough(b_set)) and kind != "item":
            a_set, b_set, method = choose(CAP["item"] * n)
        a_set, b_set = set(a_set), set(b_set)
    group_a = {(x, y) for x, y in opaque if px[x, y][:3] in a_set}
    group_b = {(x, y) for x, y in opaque if px[x, y][:3] in b_set}
    return {"a": group_a, "b": group_b, "opaque": set(opaque), "method": method,
            "weak": bool(override and override.get("weak"))}


def problems(result, kind):
    """Inside, disjoint, non-empty; the size rule unless the override marks
    the source as too small for it."""
    n = len(result["opaque"])
    minimum = 1 if result["weak"] else max(MIN_PIXELS[kind], MIN_SHARE * n)
    out = []
    for name in ("a", "b"):
        group = result[name]
        if not group <= result["opaque"]:
            out.append("group %s outside the opaque pixels" % name.upper())
        if len(group) < minimum:
            out.append("group %s has %d px (< %.0f)" % (name.upper(), len(group), minimum))
        if not result["weak"] and len(group) > MAX_SHARE * n:
            out.append("group %s covers %d of %d px" % (name.upper(), len(group), n))
    if result["a"] & result["b"]:
        out.append("groups overlap")
    return out


def render(directory, stem, result):
    """The mask image: W x 2H, mode LA."""
    _, w, h, px = load(directory, stem)
    mask = Image.new("LA", (w, 2 * h), (0, 0))
    out = mask.load()
    for frame, name in enumerate(("a", "b")):
        group = sorted(result[name])
        if not group:
            continue
        values = [brightness(px[x, y][:3]) for x, y in group]
        low, high = min(values), max(values)
        for (x, y), value in zip(group, values):
            t = 1.0 if high == low else (value - low) / (high - low)
            grey = int(round(255 * (TONE_FLOOR + (1 - TONE_FLOOR) * t)))
            out[x, y + frame * h] = (grey, 255)
    return mask


def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--report", action="store_true")
    args = parser.parse_args()
    failures, total_bytes, rows = [], 0, []
    for directory, stem, kind in sources():
        result = split(directory, stem, kind)
        issues = problems(result, kind)
        mask = render(directory, stem, result)
        target = directory / (stem + "_ench.png")
        n = len(result["opaque"])
        rows.append("%-46s %-8s n=%4d A=%4d B=%4d %s" % (
            stem, result["method"], n, len(result["a"]), len(result["b"]),
            "; ".join(issues)))
        if issues:
            failures.append("%s: %s" % (stem, "; ".join(issues)))
        if args.check:
            if not target.exists():
                failures.append("%s: mask file missing" % target.name)
                continue
            shipped = Image.open(target)
            if shipped.mode != "LA" or shipped.size != mask.size or \
                    shipped.tobytes() != mask.tobytes():
                failures.append("%s: shipped mask differs from the generator" % target.name)
            total_bytes += target.stat().st_size
        elif not args.report:
            data = png_bytes(mask)
            if not target.exists() or target.read_bytes() != data:
                target.write_bytes(data)
            total_bytes += len(data)
    if args.report:
        print("\n".join(rows))
    count = len(rows)
    for line in failures:
        print("FAIL " + line)
    if failures:
        print("R31 B MASKS FAIL %d of %d" % (len(failures), count))
        return 1
    print("R31 B MASKS PASS files=%d bytes=%d" % (count, total_bytes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
