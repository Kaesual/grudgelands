#!/usr/bin/env python3
"""Round 52 ARTA pass 2: original weapon-specific pixel animation.

Run with python3 -I. Pillow is the only dependency. No game files are written.
All effect coordinates are authored here; source pixels enter previews only.
Existing differing outputs are never overwritten, including drop-01.
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
FRAMES, FRAME_MS, LOOP_S = 8, 120, 0.96
ALPHA = (0, 96, 176, 255)
PULSE = (96, 176, 176, 255, 176, 176, 96, 96)
TRAVEL = (0, 1, 2, 3, 4, 3, 2, 1)
# Start each family/variant on a quiet transition shared by all its weapons.
# This only rotates the closed cycle; it adds no hold or duplicate end frame.
PHASE_ORIGIN = {"rage": (5, 0), "wild": (3, 7), "shadow": (3, 3),
                "fire": (0, 0), "frost": (5, 6), "holy": (0, 0)}
MATERIALS = ("wood", "stone", "bronze", "iron", "steel", "silversteel",
             "embersteel", "abyssal_steel")
CLASSES = {
    "warrior": (("rage",), ("sword", "dagger", "greataxe")),
    "scout": (("wild", "shadow"), ("bow", "sword", "dagger")),
    "mage": (("fire", "frost"), ("staff", "wand", "dagger")),
    "priest": (("holy",), ("staff", "wand", "dagger")),
}
TITLES = {
    "rage": ("Ember edge", "Heartbeat embers"),
    "wild": ("Wind and leaf", "Turning leaves"),
    "shadow": ("Smoke ribbon", "Silver curls"),
    "fire": ("Flame tongues", "Banked sparks"),
    "frost": ("Creeping rime", "Crystal motes"),
    "holy": ("Quiet radiance", "Orbiting motes"),
}


def stroke(edge, air):
    """An authored edge and an eight-step closed mote route, in source pixels."""
    assert len(air) == FRAMES
    return dict(edge=edge, air=air)


# These are distinct authored placements, not a transformed universal overlay.
# Axe strokes follow BOTH cutting edges; bow strokes avoid the centre wrap.
PLACEMENT = {
    "sword": [stroke(
        [(8, 7), (9, 6), (10, 5), (11, 4), (12, 3), (13, 2)],
        [(10, 2), (11, 1), (12, 0), (13, 0), (14, 1), (14, 2), (13, 3), (12, 3)])],
    "dagger": [stroke(
        [(6, 7), (7, 6), (8, 5), (9, 5)],
        [(7, 4), (8, 3), (9, 3), (10, 4), (10, 5), (9, 6), (8, 6), (7, 5)])],
    "greataxe": [stroke(
        [(6, 7), (5, 6), (4, 5), (4, 4), (4, 3), (5, 2)],
        [(3, 3), (3, 2), (4, 1), (5, 1), (6, 2), (5, 3), (4, 4), (3, 4)]), stroke(
        [(10, 10), (11, 11), (12, 12), (13, 12), (14, 11), (14, 10)],
        [(11, 11), (12, 11), (13, 11), (14, 11), (15, 12), (14, 13), (13, 13), (12, 12)])],
    "staff": [stroke(
        [(11, 2), (11, 1), (12, 0), (13, 0), (14, 1)],
        [(10, 1), (11, 0), (12, 0), (13, 1), (14, 2), (13, 3), (12, 3), (11, 2)])],
    "wand": [stroke(
        [(11, 3), (12, 3), (13, 2), (14, 3)],
        [(11, 2), (12, 1), (13, 1), (14, 2), (14, 3), (13, 4), (12, 4), (11, 3)])],
    "bow": [stroke(
        [(7, 2), (8, 2), (9, 1), (10, 1), (11, 1), (12, 1)],
        [(7, 1), (8, 0), (9, 0), (10, 0), (11, 0), (10, 1), (9, 1), (8, 1)]), stroke(
        [(1, 9), (1, 10), (1, 11), (1, 12), (1, 13)],
        [(0, 10), (0, 11), (0, 12), (0, 13), (1, 13), (1, 12), (1, 11), (1, 10)])],
    "bow_draw0": [stroke(
        [(7, 2), (8, 1), (9, 1), (10, 2), (11, 2), (12, 1)],
        [(8, 0), (9, 0), (10, 1), (11, 1), (12, 0), (11, 0), (10, 0), (9, 1)]), stroke(
        [(2, 8), (1, 9), (2, 10), (2, 11), (1, 12)],
        [(0, 8), (0, 9), (0, 10), (0, 11), (1, 11), (1, 10), (1, 9), (1, 8)]), stroke(
        [(3, 2), (2, 1), (1, 0), (0, 0)],
        [(0, 0), (1, 0), (2, 0), (3, 1), (3, 2), (2, 2), (1, 2), (0, 1)])],
    "bow_draw1": [stroke(
        [(7, 3), (7, 2), (8, 1), (9, 1), (10, 2), (11, 2)],
        [(8, 0), (9, 0), (10, 0), (11, 1), (12, 1), (11, 0), (10, 1), (9, 1)]), stroke(
        [(2, 8), (1, 9), (2, 10), (2, 11), (2, 12)],
        [(0, 8), (0, 9), (0, 10), (0, 11), (1, 11), (1, 10), (1, 9), (1, 8)]), stroke(
        [(3, 2), (2, 1), (1, 1), (1, 0)],
        [(0, 0), (1, 0), (2, 0), (3, 1), (3, 2), (2, 2), (1, 2), (0, 1)])],
    "bow_draw2": [stroke(
        [(7, 3), (7, 2), (8, 1), (9, 1), (10, 2), (11, 2)],
        [(8, 0), (9, 0), (10, 0), (11, 1), (12, 2), (11, 2), (10, 1), (9, 1)]), stroke(
        [(2, 8), (1, 9), (2, 10), (3, 11), (3, 12)],
        [(0, 9), (0, 10), (1, 11), (2, 12), (2, 11), (1, 10), (1, 9), (1, 8)]), stroke(
        [(5, 4), (4, 3), (3, 3), (3, 2)],
        [(2, 1), (3, 1), (4, 1), (4, 2), (4, 3), (3, 3), (2, 3), (2, 2)])],
}
# Flame paths rise from each actual head. The staff touches the top image
# border already, so its tongues also lick up its left flank.
FLAMES = {
    "dagger": [[(7, 6), (7, 5), (6, 4)], [(9, 5), (9, 4), (10, 3)]],
    "staff": [[(11, 2), (10, 1), (10, 0)], [(13, 2), (14, 1), (14, 0)]],
    "wand": [[(12, 3), (12, 2), (11, 1)], [(14, 3), (14, 2), (14, 1)]],
}


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


def frame(family, shape, variant, phase):
    phase = (phase + PHASE_ORIGIN[family][variant - 1]) % FRAMES
    im = Image.new("RGBA", (16, 16))

    def px(point, color, alpha=176):
        assert alpha in ALPHA
        assert 0 <= point[0] < 16 and 0 <= point[1] < 16, point
        # No antialiasing; the overlay alpha palette remains exact.
        im.putpixel(point, (*color, alpha))

    for k, placement in enumerate(PLACEMENT[shape]):
        edge, air = placement["edge"], placement["air"]
        p = (phase + 3 * k) % FRAMES
        head = TRAVEL[p] * (len(edge) - 1) // 4
        # Bow/axe branches are smaller so the complete effect stays sparse.
        count = 3 if len(PLACEMENT[shape]) > 1 else 4
        if family == "rage":
            for i, point in enumerate(edge):
                if variant == 1 or abs(i - head) <= 1:
                    px(point, (181, 22, 53), 96 if variant == 1 else PULSE[p])
            px(edge[head], (242, 56, 76), PULSE[(p + 2) % 8])
            px(air[p], (255, 91, 95), 176)
            if variant == 2:
                px(air[(p - 1) % 8], (171, 24, 49), 96)
        elif family == "wild":
            for i in range(count if variant == 1 else 2):
                px(edge[(head + i) % len(edge)], (62, 195, 172), 96 if i else 176)
            px(air[p], (156, 204, 77), 176)
            px(air[(p - 1) % 8], (55, 130, 76), 96)
            if variant == 2:
                px(air[(p + 4) % 8], (111, 180, 67), 176)
        elif family == "shadow":
            for i in range(count if variant == 1 else 2):
                px(edge[(head + i) % len(edge)], (39, 24, 55), 176)
            px(air[p], (104, 65, 139), 96 if variant == 1 else 176)
            px(air[(p - 1) % 8], (61, 36, 83), 96)
            if variant == 2:
                px(air[(p + 1) % 8], (38, 24, 51), 96)
            px(edge[(head + 1) % len(edge)], (191, 185, 211), 96)
        elif family == "frost":
            for i, point in enumerate(edge):
                px(point, (111, 192, 231), 96)
                if (i + p) % (3 if variant == 1 else 4) == 0:
                    px(point, (215, 246, 255), PULSE[(p + i) % 8])
            px(air[p], (197, 237, 255), 176)
            if variant == 2:
                px(air[(p + 1) % 8], (119, 192, 229), 96)
                px(air[(p + 4) % 8], (219, 248, 255), 176)
        elif family == "holy":
            for point in edge:
                px(point, (235, 179, 67), 96)
            px(edge[head], (255, 241, 189), PULSE[p])
            for offset in ((0, 4) if variant == 1 else (0, 3, 6)):
                px(air[(p + offset) % 8], (255, 239, 189) if offset == 0 else
                   (241, 194, 91), 176 if offset == 0 else 96)
        elif family == "fire":
            for i, jet in enumerate(FLAMES[shape]):
                q = (p + i * 3) % 8
                px(jet[0], (219, 57, 26), 176)
                px(jet[1], (255, 123, 32), 176 if variant == 1 else 96)
                if variant == 1 and q in (1, 2, 3, 4, 5):
                    px(jet[2], (255, 195, 73), 96 if q in (1, 5) else 176)
            px(air[p], (255, 170, 45), 176)
            if variant == 2:
                px(air[(p + 3) % 8], (255, 207, 94), 176)
                px(edge[head], (246, 84, 23), PULSE[p])
        else:
            raise ValueError(family)
    return im


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
    stats = ("str", "crit_percent") if shape in ("sword", "greataxe") else ("int", "max_mana_percent")
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
        return [(name, load(path)) for name, path in zip(("Alder", "Wood"), paths)], paths
    if shape.startswith("bow_draw"):
        path = ABILITY / f"grug_abilities_{shape.replace('draw', 'draw_')}.png"
        return [(shape.replace("_", " "), load(path))], [path]
    paths = [GEAR / f"grug_gear_item_{shape}_{m}.png" for m in MATERIALS]
    paths = [p for p in paths if p.exists()]
    samples = [(p.stem.split(shape + "_")[1].replace("_", " "), load(p)) for p in paths]
    iron = GEAR / f"grug_gear_item_{shape}_iron.png"
    mask = GEAR / f"grug_gear_item_{shape}_iron_ench.png"
    samples.append(("iron enchanted", enchanted(load(iron), load(mask), shape)))
    return samples, [*paths, mask]


def composite(effect, weapon, scale=8):
    bg = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = (38, 43, 52, 255) if (x // 4 + y // 4) % 2 else (45, 50, 60, 255)
            bg.putpixel((x, y), c)
    bg = Image.alpha_composite(bg, weapon)
    return Image.alpha_composite(bg, effect).convert("RGB").resize(
        (16 * scale, 16 * scale), Image.Resampling.NEAREST)


def animated_preview(key, frames, samples, title):
    result = []
    width = max(400, 20 + len(samples) * 148)
    for effect in frames:
        im = Image.new("RGB", (width, 202), (21, 25, 33))
        d = ImageDraw.Draw(im)
        d.text((12, 8), key, fill=(240, 238, 229))
        d.text((12, 24), f"{title} | 8 frames / 0.96 s / 8x", fill=(180, 190, 202))
        for i, (name, weapon) in enumerate(samples):
            x = 12 + i * 148
            d.text((x, 48), name, fill=(211, 217, 226))
            im.paste(composite(effect, weapon), (x, 66))
        result.append(im)
    # One palette for the entire loop avoids palette flicker between frames.
    atlas = Image.new("RGB", (width, 202 * FRAMES))
    for i, im in enumerate(result):
        atlas.paste(im, (0, 202 * i))
    palette = atlas.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return [im.quantize(palette=palette, dither=Image.Dither.NONE) for im in result]


def preview_sheet(all_frames, all_samples):
    # Three permitted weapon columns per class. Bow's four stages occupy
    # four subcells INSIDE its family row; variants remain side by side.
    cell_w, sub_h, header_h = 570, 182, 52
    height = 66 + sum(header_h + len(families) * sub_h * (4 if "bow" in ws else 1)
                      for families, ws in CLASSES.values())
    sheet = Image.new("RGB", (1740, height), (20, 24, 32))
    d = ImageDraw.Draw(sheet)
    d.text((16, 12), "ARTA / DROP 02 - class and weapon overlays", fill=(243, 236, 221))
    d.text((16, 30), "Frame 1 at 8x | v1 left / v2 right | 8 frames, 0.96 s in every strip | GIFs show every material + enchanted iron", fill=(182, 195, 211))
    y = 66
    for cls, (families, ws) in CLASSES.items():
        d.rectangle((10, y, 1728, y + 28), fill=(43, 51, 66))
        d.text((20, y + 8), cls.title(), fill=(247, 238, 216))
        for col, weapon in enumerate(ws):
            d.text((18 + col * cell_w, y + 35), weapon.upper(), fill=(190, 200, 215))
        y += header_h
        family_h = sub_h * (4 if "bow" in ws else 1)
        for family in families:
            for col, weapon in enumerate(ws):
                shapes = ["bow", "bow_draw0", "bow_draw1", "bow_draw2"] if weapon == "bow" else [weapon]
                for stage, shape in enumerate(shapes):
                    for variant in (1, 2):
                        x, yy = 18 + col * cell_w + (variant - 1) * 280, y + stage * sub_h
                        key = asset_key(cls, family, shape, variant)
                        d.text((x, yy + 4), key, fill=(233, 232, 226))
                        samples = all_samples[shape]
                        if weapon != "bow":
                            samples = [next(s for s in samples if s[0] == "iron")]
                        for n, (label, base) in enumerate(samples):
                            xx = x + n * 136
                            d.text((xx, yy + 22), label, fill=(167, 185, 200))
                            sheet.paste(composite(all_frames[key][0], base), (xx, yy + 39))
            y += family_h
            d.line((12, y - 3, 1728, y - 3), fill=(52, 59, 72))
    return sheet


def asset_key(cls, family, shape, variant):
    return f"fx.{cls}.{family}.{shape.replace('_draw', '.draw')}.v{variant}"


def delta(a, b):
    # Premultiplied colour AND alpha measure visible motion even for dark smoke.
    ap = [a.getpixel((x, y)) for y in range(16) for x in range(16)]
    bp = [b.getpixel((x, y)) for y in range(16) for x in range(16)]
    return sum(sum(abs(pa[c] * pa[3] - pb[c] * pb[3]) for c in range(3))
               + 255 * abs(pa[3] - pb[3]) for pa, pb in zip(ap, bp))


def check_asset(entry, out, frames, shape, samples):
    with Image.open(out / entry["path"]) as strip:
        assert strip.size == (16, 128) and strip.mode == "RGBA"
        levels = sorted(set(strip.getchannel("A").tobytes()))
        assert set(levels) <= set(ALPHA)
        assert all(strip.getpixel((x, y))[3] or strip.getpixel((x, y)) == (0, 0, 0, 0)
                   for y in range(128) for x in range(16))
    forbidden = GRIPS[shape] | STRINGS.get(shape, set())
    counts = []
    for effect in frames:
        pixels = {(x, y) for y in range(16) for x in range(16) if effect.getpixel((x, y))[3]}
        assert not pixels & forbidden, (entry["key"], sorted(pixels & forbidden))
        assert 1 <= len(pixels) <= 20, (entry["key"], len(pixels))
        counts.append(len(pixels))
    assert frame(entry["family"], shape, entry["variant"], 8).tobytes() == frames[0].tobytes()
    steps = [delta(frames[i], frames[(i + 1) % 8]) for i in range(8)]
    assert steps[-1] <= max(steps[:-1]), (entry["key"], steps)
    with Image.open(out / entry["gif"]["path"]) as gif:
        assert gif.info["loop"] == 0 and gif.n_frames == FRAMES
        durations = []
        for i in range(gif.n_frames):
            gif.seek(i)
            durations.append(gif.info["duration"])
        assert durations == [FRAME_MS] * FRAMES
    return dict(key=entry["key"], alpha_levels=levels, pixels_per_frame=counts,
                grip_or_string_pixels=0, cyclic_deltas=steps, loop_seam_pass=True,
                gif_frames=8, gif_frame_ms=durations, preview_weapons=len(samples))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=HERE / "drop-02")
    args = parser.parse_args()
    out = args.out.resolve()
    if out == HERE / "drop-01" or HERE / "drop-01" in out.parents:
        raise SystemExit("drop-01 is immutable")
    entries, checks, all_frames = [], [], {}
    all_samples, refs = {}, {}
    for shape in PLACEMENT:
        all_samples[shape], paths = weapons(shape)
        refs[shape] = [source_record(p) for p in paths]
    for cls, (families, ws) in CLASSES.items():
        for family in families:
            for weapon in ws:
                shapes = ["bow", "bow_draw0", "bow_draw1", "bow_draw2"] if weapon == "bow" else [weapon]
                for shape in shapes:
                    for variant in (1, 2):
                        key = asset_key(cls, family, shape, variant)
                        frames = [frame(family, shape, variant, i) for i in range(FRAMES)]
                        all_frames[key] = frames
                        strip = Image.new("RGBA", (16, 128))
                        for i, effect in enumerate(frames):
                            strip.paste(effect, (0, i * 16))
                        path = Path("fx") / cls / f"{family}_{shape}_v{variant}.png"
                        data = encoded(strip, optimize=True)
                        write_new(out / path, data)
                        gif = animated_preview(key, frames, all_samples[shape], TITLES[family][variant - 1])
                        gif_data = encoded(gif[0], "GIF", save_all=True, append_images=gif[1:],
                                           duration=FRAME_MS, loop=0, disposal=2, optimize=False)
                        write_new((out / path).with_suffix(".gif"), gif_data)
                        license_id = "CC0-1.0" if weapon in ("wand", "greataxe") else "CC-BY-SA-4.0"
                        entry = dict(key=key, **{"class": cls}, family=family, weapon=weapon,
                                     stage=(shape.removeprefix("bow_") if shape != "bow" else "idle")
                                     if weapon == "bow" else None,
                                     variant=variant, path=path.as_posix(), sha256=sha(data),
                                     frames=FRAMES, loop_s=LOOP_S, frame_ms=FRAME_MS,
                                     size=[16, 128], mode="RGBA", license="CC0-1.0",
                                     title=TITLES[family][variant - 1], bytes=len(data),
                                     gif=dict(path=path.with_suffix(".gif").as_posix(),
                                              sha256=sha(gif_data), bytes=len(gif_data),
                                              scale=8, frames=8, loop_s=LOOP_S,
                                              license=license_id, sources=refs[shape],
                                              enchant_stats=(["str", "crit_percent"]
                                                  if weapon in ("sword", "greataxe") else
                                                  ["int", "max_mana_percent"])
                                              if weapon != "bow" else None))
                        entries.append(entry)
                        checks.append(check_asset(entry, out, frames, shape, all_samples[shape]))
    assert len(entries) == 48 and len({e["key"] for e in entries}) == 48
    preview = encoded(preview_sheet(all_frames, all_samples), optimize=True)
    write_new(out / "preview.png", preview)
    manifest = dict(schema=2, lane="ARTA", drop="02", date="2026-10-19",
                    classification="compatible", author="GPT-6 Astra (Grudgelands)",
                    paths_relative_to="manifest directory; source paths relative to repository",
                    animation=dict(type="vertical_frames", frames=8, frame_size=[16, 16],
                                   frame_ms=120, loop_s=0.96, alpha_levels=list(ALPHA)),
                    preview=dict(path="preview.png", sha256=sha(preview), license="CC-BY-SA-4.0"),
                    assets=entries)
    # The generator is code, not a weapon image.
    manifest["generator"] = dict(path=Path(__file__).relative_to(REPO).as_posix(),
                                 sha256=sha(Path(__file__).read_bytes()), license="GPL-3.0-or-later")
    enchant_path = GEAR.parent / "enchant_colors.lua"
    manifest["preview_enchant_input"] = dict(path=enchant_path.relative_to(REPO).as_posix(),
                                             sha256=sha(enchant_path.read_bytes()))
    write_new(out / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())
    write_new(out / "checks.json", (json.dumps(dict(
        scope="Media only; no fixtures, Lua or engine runs", assets=checks,
        class_counts={cls: sum(e["class"] == cls for e in entries) for cls in CLASSES}), indent=2) + "\n").encode())
    print("48 strips + 48 GIFs + preview.png; 8 frames / 0.96 s; checks PASS")


if __name__ == "__main__":
    main()
