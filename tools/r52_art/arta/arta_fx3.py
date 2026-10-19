#!/usr/bin/env python3
"""Round 52 ARTA pass 3: eight original talent-tree pixel overlay families.

Run with python3 -I; Pillow is the only dependency. Source weapon pixels
enter previews only. All motion paths are open, with a fade before restart.
One clock per family, including both variants and every bow draw stage.
This generator writes only staged art, never game files or earlier drops.
"""

import argparse
import hashlib
import io
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
GEAR = REPO / "mods/ITEMS/grug_gear/textures"
ABILITY = REPO / "mods/PLAYER/grug_abilities/textures"
ALPHA = (0, 96, 176, 255)
MATERIALS = ("wood", "stone", "bronze", "iron", "steel", "silversteel",
             "embersteel", "abyssal_steel")
CLASSES = {
    "mage": (("ember", "rime"), ("staff", "wand", "dagger")),
    "warrior": (("bulwark", "ruin"), ("sword", "dagger", "greataxe")),
    "priest": (("mercy", "reckoning"), ("staff", "wand", "dagger")),
    "scout": (("quarry", "veil"), ("bow", "sword", "dagger")),
}
# Integer milliseconds also encode exactly in GIF's centisecond clock.
TIMING = {"ember": (8, 120), "rime": (12, 260), "bulwark": (12, 180),
          "ruin": (10, 160), "mercy": (12, 280), "reckoning": (12, 160),
          "quarry": (12, 260), "veil": (12, 280)}
TITLES = {
    "ember": ("Candle tongue", "Split cinder"),
    "rime": ("Growing frost fern", "Held crystal"),
    "bulwark": ("Measured edge", "Rivet glint"),
    "ruin": ("Hot cutting edge", "Tempered fracture"),
    "mercy": ("Quiet blessing", "Sheltered light"),
    "reckoning": ("White verdict", "Golden seal"),
    "quarry": ("Passing breeze", "Single leaf"),
    "veil": ("Fine smoke", "Silver in shadow"),
}
MOTIONS = {
    "ember": "A short flame grows upwards and subsides; one spark rises and fades.",
    "rime": "A fixed ice crystal forms, holds its glint, then fades with cold mist.",
    "bulwark": "A silver-blue glint travels once along a cutting edge, then rests.",
    "ruin": "A fixed red-hot edge beats twice like a heart; one ember lifts away.",
    "mercy": "Warm gold-white light breathes slowly; a single soft mote rises.",
    "reckoning": "A hard gold-white flash and crimson point punctuate a long still pause.",
    "quarry": "A short teal breeze or a single green leaf drifts away, then rests.",
    "veil": "A narrow violet-black wisp rises and thins beside a fixed silver edge.",
}


def composition(edge, mark, plume, spark, aux=(), arrow=()):
    """Authored source-pixel placement; paths never wrap or reverse direction.

    edge/aux: cutting edge or bow limbs; mark: a fixed crystalline/light motif;
    plume/spark: separate ascending paths; arrow: only the forward arrowhead.
    A dagger uses a point and a small shoulder, not a reduced sword rail.
    """
    return dict(edge=edge, mark=mark, plume=plume, spark=spark, aux=aux, arrow=arrow)


# Each pair is independently composed for variants 1 and 2. No scaling,
# rotation, modulo-indexed edge motion or copied weapon pixels is involved.
COMPOSITIONS = {
    "sword": (
        composition([(10, 5), (11, 4), (12, 3), (13, 2)],
                    [(12, 3), (11, 3), (12, 2), (13, 3)],
                    [(11, 4), (11, 3), (11, 2), (11, 1)],
                    [(12, 2), (11, 1), (10, 0)]),
        composition([(11, 3), (12, 2), (13, 1)],
                    [(13, 2), (12, 2), (13, 1)],
                    [(14, 3), (14, 2), (14, 1), (14, 0)],
                    [(11, 3), (10, 2), (9, 1)])),
    "dagger": (
        composition([(8, 6), (9, 5)],
                    [(9, 5), (8, 5), (9, 4), (10, 5)],
                    [(9, 5), (9, 4), (9, 3), (9, 2)],
                    [(8, 4), (8, 3), (8, 2)]),
        composition([(7, 6), (8, 5), (8, 4)],
                    [(8, 5), (7, 5), (8, 4), (9, 5)],
                    [(7, 5), (7, 4), (7, 3), (7, 2)],
                    [(10, 5), (10, 4), (10, 3)])),
    "greataxe": (
        composition([(4, 5), (4, 4), (4, 3), (5, 2)],
                    [(4, 3), (4, 2), (5, 3)],
                    [(4, 3), (4, 2), (4, 1), (4, 0)],
                    [(14, 10), (14, 9), (14, 8)],
                    aux=[(12, 12), (13, 12), (14, 11)]),
        composition([(4, 4), (5, 3), (6, 2)],
                    [(5, 3), (4, 3), (5, 2)],
                    [(5, 2), (5, 1), (5, 0)],
                    [(13, 11), (13, 10), (13, 9)],
                    aux=[(12, 11), (13, 11), (14, 10)])),
    "staff": (
        composition([(11, 2), (12, 1), (13, 0)],
                    [(12, 1), (11, 1), (12, 0), (13, 1), (12, 2)],
                    [(11, 2), (10, 1), (10, 0)],
                    [(14, 2), (14, 1), (14, 0)]),
        composition([(12, 2), (13, 1), (14, 1)],
                    [(13, 1), (13, 0), (12, 1), (14, 1)],
                    [(14, 2), (14, 1), (14, 0)],
                    [(11, 2), (11, 1), (11, 0)])),
    "wand": (
        composition([(12, 3), (13, 2)],
                    [(13, 2), (12, 2), (13, 1), (14, 2)],
                    [(13, 2), (13, 1), (13, 0)],
                    [(11, 3), (11, 2), (11, 1)]),
        composition([(13, 3), (14, 3)],
                    [(14, 3), (14, 2), (13, 3)],
                    [(14, 3), (14, 2), (14, 1), (14, 0)],
                    [(12, 2), (12, 1), (12, 0)])),
    "bow": (
        composition([(8, 2), (9, 1), (10, 1)], [(9, 1)],
                    [(9, 2), (9, 1), (9, 0)],
                    [(8, 2), (7, 1), (6, 0)],
                    aux=[(1, 11), (1, 10), (1, 9)]),
        composition([(1, 12), (1, 11), (1, 10)], [(1, 11)],
                    [(0, 12), (0, 11), (0, 10), (0, 9)],
                    [(1, 11), (1, 10), (1, 9)],
                    aux=[(9, 1), (10, 1)])),
    "bow_draw0": (
        composition([(7, 2), (8, 1), (9, 1)], [(8, 1)],
                    [(8, 2), (8, 1), (8, 0)],
                    [(8, 2), (7, 1), (6, 0)],
                    aux=[(1, 11), (1, 10), (1, 9)], arrow=[(2, 1), (1, 0)]),
        composition([(2, 11), (2, 10), (1, 9)], [(2, 10)],
                    [(0, 11), (0, 10), (0, 9), (0, 8)],
                    [(1, 10), (1, 9), (1, 8)],
                    aux=[(9, 1), (10, 2)], arrow=[(3, 2), (2, 1)])),
    "bow_draw1": (
        composition([(7, 3), (7, 2), (8, 1)], [(8, 1)],
                    [(8, 2), (8, 1), (8, 0)],
                    [(8, 2), (7, 1), (6, 0)],
                    aux=[(2, 11), (2, 10), (1, 9)], arrow=[(2, 1), (1, 0)]),
        composition([(2, 12), (2, 11), (2, 10)], [(2, 11)],
                    [(0, 11), (0, 10), (0, 9), (0, 8)],
                    [(1, 10), (1, 9), (1, 8)],
                    aux=[(8, 1), (9, 1)], arrow=[(3, 2), (2, 1)])),
    "bow_draw2": (
        composition([(7, 3), (7, 2), (8, 1)], [(8, 1)],
                    [(8, 2), (8, 1), (8, 0)],
                    [(8, 2), (7, 1), (6, 0)],
                    aux=[(3, 12), (3, 11), (2, 10)], arrow=[(4, 3), (3, 2)]),
        composition([(3, 12), (3, 11), (2, 10)], [(3, 11)],
                    [(1, 11), (1, 10), (1, 9), (1, 8)],
                    [(2, 10), (1, 9), (0, 8)],
                    aux=[(8, 1), (9, 1)], arrow=[(5, 4), (4, 3)])),
}


def frame(family, shape, variant, phase):
    count, _ = TIMING[family]
    p = phase % count
    g = COMPOSITIONS[shape][variant - 1]
    edge, mark, plume, spark = (g[k] for k in ("edge", "mark", "plume", "spark"))
    im = Image.new("RGBA", (16, 16))

    def px(point, color, alpha=176):
        assert alpha in ALPHA and 0 <= point[0] < 16 and 0 <= point[1] < 16
        if alpha:
            im.putpixel(point, (*color, alpha))

    def stroke(points, color, alpha=176):
        for point in points:
            px(point, color, alpha)

    def rise(path, start, end, color, alpha=176, tail=None):
        # Fade at both ends; the particle vanishes before its position resets.
        if start <= p <= end:
            i = min(len(path) - 1, (p - start) * len(path) // (end - start + 1))
            if tail is not None and i:
                px(path[i - 1], tail, 96)
            px(path[i], color, 96 if p in (start, end) else alpha)

    if family == "ember":
        # One licking tongue versus two low cinders; neither circles the head.
        px(plume[0], (213, 57, 23), 176)
        if variant == 1:
            height = (1, 2, 3, 3, 2, 2, 1, 1)[p]
            for i in range(1, min(height, len(plume))):
                px(plume[i], (255, 132, 28) if i == 1 else (255, 204, 87), 176)
            px(edge[-1], (239, 90, 25), 96)
            rise(spark, 1, 6, (255, 190, 62))
        else:
            px(spark[0], (228, 82, 26), 176)
            if p in (1, 2, 3):
                px(plume[1], (255, 156, 40), 176)
            if p in (3, 4, 5):
                px(spark[1], (255, 171, 50), 176)
            if p in (2, 3, 4, 5):
                px(plume[-1], (255, 215, 100), 96 if p in (2, 5) else 176)
    elif family == "rime":
        # Crystals grow IN PLACE and hold; no travelling white dots or echoes.
        growth = (1, 1, 2, 3, 5, 5, 5, 5, 3, 2, 1, 1)[p]
        a = (96, 96, 176, 176, 176, 255, 255, 176, 176, 96, 96, 96)[p]
        stroke(mark[:growth], (128, 198, 230), 96 if a == 96 else 176)
        px(mark[0], (225, 248, 255), a)
        if variant == 2 and 3 <= p <= 8:
            px(edge[-1], (194, 229, 251), 176)
        rise(spark, 5, 9, (111, 159, 198), 96)
    elif family == "bulwark":
        # One pass from heel to tip, then a long quiet steel point.
        px(edge[-1], (125, 157, 180), 96)
        if 1 <= p <= 5:
            i = min(len(edge) - 1, (p - 1) * len(edge) // 5)
            if i and variant == 1:
                px(edge[i - 1], (105, 148, 175), 96)
            px(edge[i], (213, 232, 244), 176 if p in (1, 5) else 255)
            if variant == 2 and p in (2, 3):
                px(mark[0], (242, 247, 249), 255)
            if g["aux"]:
                # Both axe bits receive a local straight glint simultaneously.
                j = min(len(g["aux"]) - 1, (p - 1) * len(g["aux"]) // 5)
                px(g["aux"][j], (173, 203, 223), 176)
    elif family == "ruin":
        a = (96, 176, 255, 96, 176, 176, 96, 96, 96, 96)[p]
        rail = edge if variant == 1 else (edge[0], edge[-1])
        stroke(rail, (193, 33, 41), a)
        if g["aux"]:
            stroke(g["aux"][::2], (167, 25, 34), a)
        if p in (1, 2, 4, 5):
            px(mark[0], (255, 94, 57) if p in (1, 2) else (234, 56, 43), a)
        rise(spark, 2, 6, (239, 74, 43), 176)
    elif family == "mercy":
        a = (96, 96, 96, 176, 176, 176, 176, 176, 176, 96, 96, 96)[p]
        stroke(mark[:3] if variant == 1 else edge[:2], (230, 181, 95), 96)
        px(mark[0], (255, 237, 187), a)
        if 4 <= p <= 7:
            px(mark[1], (255, 247, 218), 176)
        rise(spark if variant == 1 else plume, 2, 9, (253, 230, 170), 176)
    elif family == "reckoning":
        # A rigid mark, one hard beat, then still. Crimson stays at one point.
        px(mark[0], (185, 148, 62), 96)
        if p == 2:
            stroke(mark[:3] if variant == 1 else mark, (255, 250, 223), 255)
            px(edge[-1], (255, 211, 83), 255)
            px(spark[0], (193, 32, 63), 255)
        elif p == 3:
            stroke(mark[:2], (237, 188, 70), 176)
            if variant == 2:
                px(spark[0], (193, 32, 63), 176)
        elif p == 4:
            px(mark[0], (237, 188, 70), 176)
    elif family == "quarry":
        px(edge[0], (56, 141, 112), 96)
        if variant == 1:
            # A short breeze travels ONCE along the limb or cutting edge.
            if 1 <= p <= 7:
                i = min(len(edge) - 1, (p - 1) * len(edge) // 7)
                px(edge[i], (79, 192, 171), 96 if p in (1, 7) else 176)
                if i:
                    px(edge[i - 1], (48, 132, 123), 96)
            rise(spark, 4, 9, (141, 185, 76), 176)
        else:
            # One two-pixel leaf keeps its orientation while it drifts away.
            if 1 <= p <= 9:
                i = min(len(spark) - 1, (p - 1) * len(spark) // 9)
                x, y = spark[i]
                a = 96 if p in (1, 9) else 176
                px((x, y), (144, 192, 82), a)
                px((x + 1, y), (56, 122, 79), 96)
        if g["aux"]:
            px(g["aux"][-1], (67, 152, 130), 176 if 3 <= p <= 6 else 96)
        if g["arrow"]:
            px(g["arrow"][-1], (128, 187, 119), 176 if 3 <= p <= 6 else 96)
    elif family == "veil":
        px(edge[-1], (181, 180, 204), 96)
        px(plume[0], (38, 27, 53), 96)
        rise(plume, 1, 9, (124, 83, 163) if variant == 1 else (96, 62, 131),
             176, tail=(35, 25, 47))
        if variant == 2 and 4 <= p <= 6:
            px(edge[-1], (215, 214, 231), 176)
        if g["aux"]:
            px(g["aux"][-1], (132, 131, 155), 96)
        if g["arrow"]:
            px(g["arrow"][-1], (190, 185, 214), 176 if 4 <= p <= 6 else 96)
    else:
        raise ValueError(family)
    return im


# Shared source inspection and compositing conventions retained from pass 2.
def rectangle(x0, y0, x1, y1):
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


# Independent exclusion maps traced from the inspected source sprites.
# They are validation regions, never clipping masks that hide misplaced art.
GRIPS = {
    "sword": rectangle(0, 8, 7, 15),
    "dagger": rectangle(0, 8, 7, 15),
    "greataxe": {(x, y) for y in range(8, 16) for x in range(11)
                 if abs(x + y - 16) <= 2},
    "staff": rectangle(0, 4, 11, 15),
    "wand": rectangle(0, 7, 10, 15),
    "bow": rectangle(3, 3, 7, 7),
    "bow_draw0": rectangle(3, 4, 6, 7),
    "bow_draw1": rectangle(3, 4, 6, 7),
    "bow_draw2": rectangle(3, 5, 6, 7),
}
STRINGS = {
    "bow": {(16 - y, y) for y in range(3, 14)},
    "bow_draw0": {(14, 2), (13, 3), (13, 4), (12, 5), (11, 6), (11, 7),
                  (10, 8), (9, 9), (8, 10), (6, 11), (7, 11), (5, 12),
                  (3, 13), (4, 13), (2, 14)},
    "bow_draw1": {(14, 3), (13, 4), (13, 5), (12, 6), (12, 7), (11, 8),
                  (9, 10), (8, 11), (6, 12), (7, 12), (4, 13), (5, 13), (3, 14)},
    "bow_draw2": {(14, 4), (14, 5), (14, 6), (13, 7), (13, 8), (13, 9),
                  (12, 10), (10, 12), (11, 12), (12, 12), (7, 13), (8, 13),
                  (9, 13), (4, 14), (5, 14), (6, 14)},
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(im, fmt="PNG", **kwargs):
    buf = io.BytesIO()
    im.save(buf, format=fmt, **kwargs)
    return buf.getvalue()


def write_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data:
            raise SystemExit(f"Refusing to replace {path}; use a fresh --out directory")
    else:
        path.write_bytes(data)


def source_license(path):
    if "bow_draw" in path.name:
        return "CC-BY-SA-4.0"
    if "_wand_" in path.name or "_greataxe_" in path.name:
        return "CC0-1.0"
    return "CC-BY-SA-3.0"


def source_record(path):
    with Image.open(path) as im:
        size = list(im.size)
    return dict(path=path.relative_to(REPO).as_posix(), sha256=sha(path.read_bytes()),
                size=size, license=source_license(path))


def load(path):
    with Image.open(path) as im:
        return im.convert("RGBA")


def enchanted(base, mask, shape):
    """Two static affix groups, not animation frames; both tint the iron item.

    Read the shipped affix colours and opacity. Preview only valid affixes:
    Strength/Crit for sword/axe, Intelligence/Mana for dagger/staff/wand.
    Use the game's integer multiply + alpha blend on the opaque source pixels.
    """
    code = (GEAR.parent / "enchant_colors.lua").read_text()
    opacity = int(re.search(r"ENCHANT_OPACITY = (\d+)", code)[1])
    out = base.copy()
    stats = enchant_stats(shape)
    for group, stat in enumerate(stats):
        color = re.search(r'\b' + stat + r' = "#([0-9a-f]{6})"', code)[1]
        rgb = tuple(int(color[i:i + 2], 16) for i in (0, 2, 4))
        for y in range(16):
            for x in range(16):
                source = mask.getpixel((x, y + group * 16))
                if source[3]:
                    old = out.getpixel((x, y))
                    assert old[3] == 255
                    tint = [source[c] * rgb[c] // 255 for c in range(3)]
                    a = source[3] * opacity // 255
                    out.putpixel((x, y), tuple((old[c] * (255 - a) + tint[c] * a)
                                              // 255 for c in range(3)) + (255,))
    return out


def weapons(shape):
    """Return labelled previews plus exact input paths, in material order."""
    if shape == "bow":
        paths = [GEAR / f"grug_gear_bow_{name}.png" for name in ("alder", "wood")]
        samples = [(name, load(path)) for name, path in zip(("Alder", "Wood"), paths)]
        mask = GEAR / "grug_gear_bow_alder_ench.png"
        samples.append(("alder enchanted", enchanted(load(paths[0]), load(mask), shape)))
        return samples, [*paths, mask]
    if shape.startswith("bow_draw"):
        path = ABILITY / f"grug_abilities_{shape.replace('draw', 'draw_')}.png"
        # scout.lua strips affix masks on draw: the enchanted bow has the
        # same stage sprite. Show that explicitly rather than inventing a mask.
        return [(shape.replace("_", " "), load(path)),
                ("enchanted (same)", load(path))], [path]
    paths = [GEAR / f"grug_gear_item_{shape}_{m}.png" for m in MATERIALS]
    paths = [p for p in paths if p.exists()]
    samples = [(p.stem.split(shape + "_")[1].replace("_", " "), load(p)) for p in paths]
    iron = GEAR / f"grug_gear_item_{shape}_iron.png"
    mask = GEAR / f"grug_gear_item_{shape}_iron_ench.png"
    samples.append(("iron enchanted", enchanted(load(iron), load(mask), shape)))
    return samples, [*paths, mask]


def enchant_stats(shape):
    if shape.startswith("bow"):
        return ["dex", "crit_percent"]
    if shape in ("sword", "greataxe"):
        return ["str", "crit_percent"]
    return ["int", "max_mana_percent"]


def composite(effect, weapon, scale=8):
    bg = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = (38, 43, 52, 255) if (x // 4 + y // 4) % 2 else (45, 50, 60, 255)
            bg.putpixel((x, y), c)
    bg = Image.alpha_composite(bg, weapon)
    return Image.alpha_composite(bg, effect).convert("RGB").resize(
        (16 * scale, 16 * scale), Image.Resampling.NEAREST)


def clock_label(family):
    count, ms = TIMING[family]
    return f"{count} x {ms / 1000:g} s = {count * ms / 1000:g} s"


def animated_preview(key, family, variant, frames, samples):
    result = []
    width, height = max(456, 20 + len(samples) * 148), 224
    for i, effect in enumerate(frames):
        im = Image.new("RGB", (width, height), (21, 25, 33))
        d = ImageDraw.Draw(im)
        d.text((12, 8), key, fill=(240, 238, 229))
        d.text((12, 25), f"{TITLES[family][variant - 1]} | {clock_label(family)} | 8x",
               fill=(180, 190, 202))
        for j, (name, weapon) in enumerate(samples):
            x = 12 + j * 148
            d.text((x, 49), name, fill=(211, 217, 226))
            im.paste(composite(effect, weapon), (x, 67))
        # The small counter keeps identical hold frames individually encoded
        # in GIF, while showing that the effect really is intentionally still.
        d.text((12, 204), f"FRAME {i + 1:02}/{len(frames)} | real speed | loop",
               fill=(139, 155, 176))
        result.append(im)
    # A shared palette avoids palette changes during quiet frames.
    atlas = Image.new("RGB", (width, height * len(frames)))
    for i, im in enumerate(result):
        atlas.paste(im, (0, height * i))
    palette = atlas.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return [im.quantize(palette=palette, dither=Image.Dither.NONE) for im in result]


def asset_key(cls, family, shape, variant):
    return f"fx.{cls}.{family}.{shape.replace('_draw', '.draw')}.v{variant}"


def shapes_for(weapon):
    return ("bow", "bow_draw0", "bow_draw1", "bow_draw2") if weapon == "bow" else (weapon,)


def preview_sheet(all_frames, all_samples):
    cell_w, sub_h, header_h, family_header = 590, 183, 52, 32
    width = 1800
    height = 80 + sum(header_h + len(families) *
                     (family_header + sub_h * (4 if "bow" in ws else 1))
                     for families, ws in CLASSES.values())
    sheet = Image.new("RGB", (width, height), (20, 24, 32))
    d = ImageDraw.Draw(sheet)
    d.text((18, 12), "ARTA / DROP 03 - ONE FAMILY PER TALENT TREE", fill=(243, 236, 221))
    d.text((18, 32), "Frame 1 at exactly 8x | v1 left / v2 right | GIFs play the full cycle at real speed",
           fill=(182, 195, 211))
    d.text((18, 49), "Quiet first frames are intentional. All materials and enchant samples are in the GIFs.",
           fill=(145, 164, 186))
    y = 80
    for cls, (families, ws) in CLASSES.items():
        d.rectangle((10, y, width - 12, y + 28), fill=(43, 51, 66))
        d.text((20, y + 8), cls.upper(), fill=(247, 238, 216))
        for col, weapon in enumerate(ws):
            d.text((18 + col * cell_w, y + 35), weapon.upper(), fill=(190, 200, 215))
        y += header_h
        for family in families:
            d.text((18, y + 7), f"{family.upper()} | {clock_label(family)} | {MOTIONS[family]}",
                   fill=(224, 215, 190))
            y += family_header
            for col, weapon in enumerate(ws):
                for stage, shape in enumerate(shapes_for(weapon)):
                    for variant in (1, 2):
                        x, yy = 18 + col * cell_w + (variant - 1) * 290, y + stage * sub_h
                        key = asset_key(cls, family, shape, variant)
                        d.text((x, yy + 3), key, fill=(233, 232, 226))
                        samples = all_samples[shape]
                        if weapon != "bow":
                            samples = [next(s for s in samples if s[0] == "iron")]
                        else:
                            samples = samples[:2] if shape == "bow" else samples[:1]
                        for n, (label, base) in enumerate(samples):
                            xx = x + n * 136
                            d.text((xx, yy + 20), label, fill=(167, 185, 200))
                            sheet.paste(composite(all_frames[key][0], base), (xx, yy + 37))
            y += sub_h * (4 if "bow" in ws else 1)
            d.line((12, y - 4, width - 12, y - 4), fill=(52, 59, 72))
    return sheet


def delta(a, b):
    # Premultiplied RGB plus alpha records visible motion, including dark smoke.
    return sum(sum(abs(pa[c] * pa[3] - pb[c] * pb[3]) for c in range(3))
               + 255 * abs(pa[3] - pb[3]) for pa, pb in zip(pixels(a), pixels(b)))


def pixels(im):
    return (im.getpixel((x, y)) for y in range(im.height) for x in range(im.width))


def check_asset(entry, out, frames, shape, gif_frames):
    count, ms = TIMING[entry["family"]]
    with Image.open(out / entry["path"]) as strip:
        assert strip.size == (16, 16 * count) and strip.mode == "RGBA"
        levels = sorted(set(strip.getchannel("A").tobytes()))
        assert set(levels) <= set(ALPHA)
        assert all(p[3] or p == (0, 0, 0, 0) for p in pixels(strip))
        assert sha((out / entry["path"]).read_bytes()) == entry["sha256"]
        for i, effect in enumerate(frames):
            assert strip.crop((0, 16 * i, 16, 16 * (i + 1))).tobytes() == effect.tobytes()
    forbidden = GRIPS[shape] | STRINGS.get(shape, set())
    counts = []
    for effect in frames:
        occupied = {(x, y) for y in range(16) for x in range(16) if effect.getpixel((x, y))[3]}
        assert not occupied & forbidden, (entry["key"], sorted(occupied & forbidden))
        assert len(occupied) <= 12, (entry["key"], len(occupied))
        counts.append(len(occupied))
    assert frame(entry["family"], shape, entry["variant"], count).tobytes() == frames[0].tobytes()
    # The seam is a real authored hold, not merely smaller than another jump.
    assert frames[-1].tobytes() == frames[0].tobytes(), entry["key"]
    assert len({f.tobytes() for f in frames}) >= 3, entry["key"]
    steps = [delta(frames[i], frames[(i + 1) % count]) for i in range(count)]
    with Image.open(out / entry["gif"]["path"]) as gif:
        assert gif.info["loop"] == 0 and gif.n_frames == count
        durations = []
        for i in range(count):
            gif.seek(i)
            durations.append(gif.info["duration"])
            assert gif.convert("RGB").tobytes() == gif_frames[i].convert("RGB").tobytes()
        assert durations == [ms] * count
    assert sha((out / entry["gif"]["path"]).read_bytes()) == entry["gif"]["sha256"]
    return dict(key=entry["key"], size=entry["size"], alpha_levels=levels,
                pixels_per_frame=counts, grip_or_string_pixels=0,
                cyclic_deltas=steps, seam_delta=steps[-1], exact_seam_hold=True,
                identical_adjacent_frames=sum(s == 0 for s in steps[:-1]),
                gif_frames=count, gif_frame_ms=durations, gif_roundtrip_pass=True,
                preview_weapons=entry["gif"]["samples"])


def validate_paths():
    # All particle routes have monotone x/y coordinates and never close.
    # Fixed marks and cutting edges are not particle routes.
    for shape, variants in COMPOSITIONS.items():
        for g in variants:
            for name in ("plume", "spark"):
                path = g[name]
                assert path[0] != path[-1], (shape, name)
                assert all(path[i][1] > path[i + 1][1] for i in range(len(path) - 1))
                dx = [b[0] - a[0] for a, b in zip(path, path[1:])]
                assert all(d >= 0 for d in dx) or all(d <= 0 for d in dx)


def media_rows(entries, preview):
    lines = ["| File (relative to drop-03) | Author | Source / modifications | Licence |",
             "|---|---|---|---|"]
    for e in entries:
        lines.append(f"| `{e['path']}` | GPT-6 Astra (Grudgelands) | FX3: {e['title']} | CC0-1.0 |")
        lines.append(f"| `{e['gif']['path']}` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | {e['gif']['license']} |")
    lines.append(f"| `{preview['path']}` | GPT-6 Astra; weapon authors | Labelled FX3 contact sheet; source credits below | CC-BY-SA-4.0 |")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=HERE / "drop-03")
    args = parser.parse_args()
    out = args.out.resolve()
    # The output may not contain, or be contained by, game/earlier-drop paths.
    for protected in (REPO / "mods", HERE / "drop-01", HERE / "drop-02"):
        if out == protected or protected in out.parents or out in protected.parents:
            raise SystemExit(f"Protected output location: {protected}")
    validate_paths()
    entries, checks, all_frames = [], [], {}
    all_samples, refs = {}, {}
    for shape in COMPOSITIONS:
        all_samples[shape], paths = weapons(shape)
        refs[shape] = [source_record(p) for p in paths]
    for cls, (families, ws) in CLASSES.items():
        for family in families:
            count, ms = TIMING[family]
            for weapon in ws:
                for shape in shapes_for(weapon):
                    for variant in (1, 2):
                        key = asset_key(cls, family, shape, variant)
                        frames = [frame(family, shape, variant, i) for i in range(count)]
                        all_frames[key] = frames
                        strip = Image.new("RGBA", (16, 16 * count))
                        for i, effect in enumerate(frames):
                            strip.paste(effect, (0, i * 16))
                        path = Path("fx") / cls / f"{family}_{shape}_v{variant}.png"
                        data = encoded(strip, optimize=True)
                        write_new(out / path, data)
                        gif = animated_preview(key, family, variant, frames, all_samples[shape])
                        gif_data = encoded(gif[0], "GIF", save_all=True, append_images=gif[1:],
                                           duration=ms, loop=0, disposal=2, optimize=False)
                        write_new((out / path).with_suffix(".gif"), gif_data)
                        license_id = refs[shape][0]["license"]
                        entry = dict(key=key, **{"class": cls}, family=family, weapon=weapon,
                                     stage=(shape.removeprefix("bow_") if shape != "bow" else "idle")
                                     if weapon == "bow" else None,
                                     variant=variant, path=path.as_posix(), sha256=sha(data),
                                     frames=count, frame_s=ms / 1000, frame_ms=ms,
                                     loop_s=count * ms / 1000, size=[16, 16 * count],
                                     mode="RGBA", license="CC0-1.0",
                                     title=TITLES[family][variant - 1], bytes=len(data),
                                     gif=dict(path=path.with_suffix(".gif").as_posix(),
                                              sha256=sha(gif_data), bytes=len(gif_data),
                                              scale=8, frames=count, frame_s=ms / 1000,
                                              loop_s=count * ms / 1000,
                                              license=license_id, sources=refs[shape],
                                              samples=[name for name, _ in all_samples[shape]],
                                              enchant_stats=enchant_stats(shape),
                                              enchant_rendering=("Unchanged draw sprite: runtime removes affix masks"
                                                  if shape.startswith("bow_draw") else "Two static affix masks at shipped opacity")))
                        entries.append(entry)
                        checks.append(check_asset(entry, out, frames, shape, gif))
    # 8 families x 3 weapons x 2 variants, plus 2 bow families x 3 draw
    # stages x 2 variants. The brief's 52 omitted Scout swords and daggers.
    assert len(entries) == 60 and len({e["key"] for e in entries}) == 60
    assert len({e["sha256"] for e in entries}) == 60
    for family, (count, ms) in TIMING.items():
        assert {(e["frames"], e["frame_ms"]) for e in entries if e["family"] == family} == {(count, ms)}
    preview = encoded(preview_sheet(all_frames, all_samples), optimize=True)
    write_new(out / "preview.png", preview)
    manifest = dict(schema=3, lane="ARTA", drop="03", date="2026-10-19",
                    classification="compatible", author="GPT-6 Astra (Grudgelands)",
                    paths_relative_to="manifest directory; source paths relative to repository",
                    count_note="60 strips cover all 24 family/weapon combinations and three extra bow draw stages per bow family, in two variants.",
                    animation=dict(type="vertical_frames", frame_size=[16, 16],
                                   alpha_levels=list(ALPHA), timing_scope="family, shared by both variants and all weapons/stages",
                                   families={f: dict(frames=n, frame_s=ms / 1000, loop_s=n * ms / 1000,
                                                     motion=MOTIONS[f]) for f, (n, ms) in TIMING.items()}),
                    preview=dict(path="preview.png", sha256=sha(preview), license="CC-BY-SA-4.0"),
                    generator=dict(path=Path(__file__).relative_to(REPO).as_posix(),
                                   sha256=sha(Path(__file__).read_bytes()), license="GPL-3.0-or-later"),
                    preview_code_inputs=[dict(path=p.relative_to(REPO).as_posix(), sha256=sha(p.read_bytes()))
                                         for p in (GEAR.parent / "enchant_colors.lua", ABILITY.parent / "scout.lua")],
                    assets=entries)
    write_new(out / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())
    write_new(out / "checks.json", (json.dumps(dict(
        scope="Media only; no fixtures, Lua execution or engine runs", assets=checks,
        monotone_particle_paths=True, family_timing_pass=True,
        class_counts={cls: sum(e["class"] == cls for e in entries) for cls in CLASSES}), indent=2) + "\n").encode())
    print(f"{len(entries)} strips + {len(entries)} GIFs + preview.png; eight family clocks; media checks PASS")


if __name__ == "__main__":
    main()
