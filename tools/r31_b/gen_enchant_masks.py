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
  4. Group B (fittings) comes from the biggest secondary material that can
     supply it (a grip wrap, a guard, a buckle, a trim line); without one,
     from the darkest non-outline tones of the main material.
  5. Group A (accents) comes from the brightest tones of the main material
     (edge highlights), never from B's pixels.
  A group is a small ACCENT, not a scatter and not a repaint (design round 2,
  the user's ruling 7 of round31-plan.md section 6: a narrow stripe is
  enough): tones are added one at a time, but only 8-connected runs of at
  least two pixels count, and a run with inner pixels keeps only its rim, so
  a group is made of thin stripes. The biggest stripes are taken first and
  the group stops at TARGET of the opaque pixels; a stripe longer than what
  is left is cut to a connected piece grown from its first pixel in tone
  order. Lone pixels are never coloured.
  When a texture fails (a group too small), the OVERRIDES table names the
  source colours a group may draw from instead; the same run rule applies.

Every result is checked: A and B inside the opaque pixels, A and B disjoint,
both at least the minimum size (MIN_PIXELS and MIN_SHARE of the opaque
pixels), neither above its cap.

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


# A group grows until it covers TARGET of the opaque pixels and never passes
# CAP. Worn overlays take less: on the body all four pieces show at once and
# at a larger size. `scale` (the preview's smaller variant) multiplies both.
TARGET = {"item": 0.07, "worn": 0.04}
CAP = {"item": 0.10, "worn": 0.06}
MIN_PIXELS = {"item": 4, "worn": 6}
MIN_SHARE = {"item": 0.03, "worn": 0.015}
MATERIAL_SPLIT = 0.045  # OKLab chroma distance that separates two materials
OUTLINE_DARK = 48  # a darkest colour below this brightness is outline anyway
TONE_FLOOR = 0.6   # darkest pixel of a group multiplies the colour by 0.6

# Textures where the automatic choice fails, with the source colours (hex, as
# in the PNG) each group may draw from. Found with --report.
OVERRIDES = {
}

NEIGHBOURS = ((-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1))


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


def runs(pixels):
    """8-connected runs of a pixel set, as sorted lists, biggest first."""
    left, out = set(pixels), []
    for start in sorted(pixels, key=lambda p: (p[1], p[0])):
        if start not in left:
            continue
        left.discard(start)
        run, todo = [start], [start]
        while todo:
            x, y = todo.pop()
            for dx, dy in NEIGHBOURS:
                q = (x + dx, y + dy)
                if q in left:
                    left.discard(q)
                    run.append(q)
                    todo.append(q)
        out.append(sorted(run, key=lambda p: (p[1], p[0])))
    out.sort(key=lambda r: (-len(r), r[0][1], r[0][0]))
    return out


def stripes(pixels):
    """The runs of a pixel set, each thinned to a stripe: a run that has
    inner pixels (all four side neighbours in the run) keeps only its rim,
    so a flat patch becomes the thin line along its edge."""
    out = []
    for run in runs(pixels):
        inside = set(run)
        rim = [p for p in run if any((p[0] + dx, p[1] + dy) not in inside
                                     for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        out.extend(runs(rim) if len(rim) < len(run) else [run])
    out.sort(key=lambda r: (-len(r), r[0][1], r[0][0]))
    return out


def grow(tones, by_tone, rank, goal, exclude):
    """A calm group from `tones` (ordered): see the module docstring.

    `by_tone` maps a colour to its pixels, `rank` a pixel to its place in the
    tone order (for cutting an oversized run from its brightest end)."""
    candidates, pieces = set(), []
    for tone in tones:
        candidates |= set(by_tone[tone]) - exclude
        pieces = [r for r in stripes(candidates) if len(r) >= 2]
        if sum(len(r) for r in pieces) >= goal:
            break
    picked = set()
    for run in pieces:
        if len(picked) >= goal:
            break
        # A run is at least two pixels, so the last one may pass the goal by one.
        room = max(2, int(math.ceil(goal - len(picked))))
        if len(run) <= room:
            picked.update(run)
        else:
            # Too big for what is left: a connected piece of it, grown from
            # its first pixel in tone order.
            picked |= piece(run, room, rank)
    return picked


def piece(run, size, rank):
    run = set(run)
    start = min(run, key=lambda p: (rank[p], p[1], p[0]))
    picked, todo = {start}, [start]
    while todo and len(picked) < size:
        x, y = todo.pop(0)
        for dx, dy in NEIGHBOURS:
            q = (x + dx, y + dy)
            if q in run and q not in picked and len(picked) < size:
                picked.add(q)
                todo.append(q)
    return picked


def split(directory, stem, kind, scale=1.0):
    """The two groups as sets of (x, y), and how they were found."""
    _, w, h, px = load(directory, stem)
    opaque = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] == 255]
    by_tone = {}
    for x, y in opaque:
        by_tone.setdefault(px[x, y][:3], []).append((x, y))
    colors = {c: len(p) for c, p in by_tone.items()}
    n = len(opaque)
    minimum = max(MIN_PIXELS[kind], MIN_SHARE[kind] * n)
    goal = max(minimum, TARGET[kind] * scale * n)
    cap = max(goal + 1, CAP[kind] * scale * n)

    def brightest(group):
        return sorted(group, key=lambda c: (-brightness(c), c))

    def darkest(group):
        return sorted(group, key=lambda c: (brightness(c), c))

    def ranks(tones):
        order = {}
        for index, tone in enumerate(tones):
            for p in by_tone[tone]:
                order[p] = index
        return order

    def pick(tones, exclude=frozenset()):
        return grow(tones, by_tone, ranks(tones), goal, exclude)

    override = OVERRIDES.get(stem)
    if override:
        def listed(names):
            return [c for c in (tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for v in names)
                    if c in by_tone]
        b_set = pick(brightest(listed(override["b"])))
        a_set = pick(brightest(listed(override["a"])), b_set)
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
        edge = sum(1 for x, y in by_tone[deepest] if on_edge(x, y))
        outline = {deepest} if (edge >= 0.6 * colors[deepest] or
                               brightness(deepest) < OUTLINE_DARK) else set()
        mats = [sorted(m) for m in
                materials({c: k for c, k in colors.items() if c not in outline})]
        main = mats[0]
        everything = [c for m in mats for c in m]
        # B: the first secondary material that supplies a group, else the
        # main material's dark tones, else any dark tones (the best try wins).
        attempts = [(brightest(m), "material") for m in mats[1:]]
        attempts += [(darkest(main), "tones"), (darkest(everything), "other")]
        b_set, method = set(), "none"
        for tones, how in attempts:
            found = pick(tones)
            if len(found) > len(b_set):
                b_set, method = found, how
            if len(b_set) >= minimum:
                break
        # A: the main material's bright tones; else any bright tones.
        a_set = set()
        for tones in (brightest(main), brightest(everything)):
            found = pick(tones, b_set)
            if len(found) > len(a_set):
                a_set = found
            if len(a_set) >= minimum:
                break
    return {"a": a_set, "b": b_set, "opaque": set(opaque), "method": method,
            "weak": bool(override and override.get("weak")), "minimum": minimum,
            "cap": cap}


def problems(result, kind):
    """Inside, disjoint, at least the minimum, at most the cap; the size rule
    only as far as the override marks the source as too small for it."""
    minimum = 1 if result["weak"] else result["minimum"]
    out = []
    for name in ("a", "b"):
        group = result[name]
        if not group <= result["opaque"]:
            out.append("group %s outside the opaque pixels" % name.upper())
        if len(group) < minimum:
            out.append("group %s has %d px (< %.0f)" % (name.upper(), len(group), minimum))
        if len(group) > result["cap"]:
            out.append("group %s has %d px (> cap %.0f)" % (name.upper(), len(group),
                                                            result["cap"]))
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
