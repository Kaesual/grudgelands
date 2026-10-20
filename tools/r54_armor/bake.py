#!/usr/bin/env python3
"""Bake painted armor art into the game's armor textures (Round 54 lane BAKE).

Reads an art directory in the contract's format (docs/technical/armor-format.md
section 6: box sheets, inner paint and icons in the reference palette,
tiers.json, optional palettes.json), data/palettes.json and data/atlas.json,
and writes the files of section 7 for every line, grade and slot:

  grug_armor_<line>_<grade>_<slot>.png        atlas layer, 128 x 64: the slot's
                                              worn boxes, each sheet palette-
                                              swapped into its atlas rectangle
                                              (face rectangles only; a mirrored
                                              box has one sheet, so one copy)
  grug_armor_<line>_<grade>_<slot>_skin.png   skin layer, 64 x 32 (chest, legs,
                                              feet): the tier's inner paint,
                                              clipped to the slot's regions
  ..._ench.png next to each                   enchant mask, grey + alpha, two
                                              frames stacked: frame 0 zone A
                                              (A_LIGHT/A_DARK), frame 1 zone B
                                              (B_LIGHT/B_DARK); light 255, dark
                                              153 (the 0.6 tone floor of
                                              tools/r31_b/gen_enchant_masks.py)
  grug_gear_item_<slot>_<line>_<grade>.png    item icon, 16 x 16, and its
                                              16 x 32 mask (only with --icons-out)

Every file exists for every grade, transparent where the tier paints nothing.
Tier T<n> of a line is the n-th grade of grug_gear.MATERIALS (read from
mods/ITEMS/grug_gear/init.lua). Alpha is hard (0 or 255); the zones come from
the reference-palette pixels, so a palette that gives zone A the same colour as
the metal still yields the right mask.

  python3 bake.py                               bake the picked art (tools/r54_art/
                                                art) into grug_visuals
  python3 bake.py --art DIR [--out DIR]         another art directory or output
  python3 bake.py --icons-out DIR               also write the 72 icons + masks
  python3 bake.py --check [--art ...] [...]     rebuild in memory; exit 1 on a
                                                missing, extra (grug_armor_*) or
                                                different file
  python3 bake.py --sheet OUT.png               contact sheet of the bake
"""
import argparse
import io
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw  # noqa: E402

import armorlib as L  # noqa: E402

TOOL = L.TOOL
ROOT = TOOL.parents[1]
GAME_OUT = ROOT / "mods/PLAYER/grug_visuals/textures"
MATERIALS_LUA = ROOT / "mods/ITEMS/grug_gear/init.lua"
ART = ROOT / "tools/r54_art/art"         # the picked art (Round 54 lane INTEG)
PREFIX = "grug_armor_"
SKIN_SIZE = (64, 32)
ICON_SIZE = (16, 16)
# reference name -> (mask frame, grey)
ZONE_GREY = {"A_LIGHT": (0, 255), "A_DARK": (0, 153), "B_LIGHT": (1, 255), "B_DARK": (1, 153)}


class BakeError(Exception):
    pass


def grades():
    """{line: [grade key of T1 .. T6]} from grug_gear.MATERIALS."""
    text = MATERIALS_LUA.read_text()
    block = re.search(r"\ngrug_gear\.MATERIALS = \{\n(.*?)\n\}\n", text, re.S)
    if not block:
        raise BakeError(f"grug_gear.MATERIALS not found in {MATERIALS_LUA}")
    out = {ln: [] for ln in L.LINES}
    for ln, key in re.findall(r"\b(metal|cloth|leather) = \{key = \"([a-z0-9_]+)\"", block.group(1)):
        out[ln].append(key)
    if any(len(v) != len(L.TIER_IDS) for v in out.values()):
        raise BakeError(f"grug_gear.MATERIALS: expected {len(L.TIER_IDS)} grades per line, read {out}")
    return out


def read_grid(path, size, errors):
    """{(x, y): reference name} of a reference-palette PNG's opaque pixels."""
    if not path.exists():
        errors.append(f"missing {path}")
        return {}
    im = Image.open(path).convert("RGBA")
    if im.size != tuple(size):
        errors.append(f"{path}: size {im.size[0]}x{im.size[1]}, expected {size[0]}x{size[1]}")
        return {}
    px = im.load()
    grid, bad = {}, []
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            name = L.REF_RGB.get((r, g, b))
            if a != 255 or name is None:
                bad.append((x, y))
                continue
            grid[(x, y)] = name
    if bad:
        errors.append(f"{path}: {len(bad)} pixel(s) with partial alpha or off the reference palette, "
                      f"first at {bad[:4]} (run check.py)")
    return grid


def layer_image(grid, size, colors):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    px = im.load()
    for (x, y), name in grid.items():
        px[x, y] = L.hex_rgb(colors[name]) + (255,)
    return im


def mask_image(grid, size):
    w, h = size
    im = Image.new("LA", (w, 2 * h), (0, 0))
    px = im.load()
    for (x, y), name in grid.items():
        zone = ZONE_GREY.get(name)
        if zone:
            px[x, y + zone[0] * h] = (zone[1], 255)
    return im


def load_selection(cat, art, errors):
    """(palettes, tiers) for the bake; tiers.json must name every line and tier
    (the render tools' fallback to the example selection is not baked)."""
    pals, _, perr = L.load_palettes(art)
    errors.extend(perr)
    path = Path(art) / "tiers.json"
    try:
        raw = json.loads(path.read_text())
    except Exception as e:  # noqa: BLE001
        raise BakeError(f"cannot read {path} ({e})") from e
    for ln in L.LINES:
        for tid in L.TIER_IDS:
            if not isinstance((raw.get(ln) or {}).get(tid), dict):
                errors.append(f"{path}: no entry for {ln} {tid}")
    tiers, _, terr = L.load_tiers(cat, pals, art)
    errors.extend(terr)
    return pals, tiers


def bake(art, icons=False):
    """-> ({file name: game image}, {file name: icon image}). Raises BakeError
    with every problem found."""
    art = Path(art)
    cat = L.load_catalog()
    atlas = json.loads((L.DATA / "atlas.json").read_text())
    asize = tuple(atlas["size"])
    errors = []
    pals, tiers = load_selection(cat, art, errors)
    grade_keys = grades()
    by_slot = {s: [b for b in cat["boxes"] if b["slot"] == s] for s in L.SLOTS}
    regions = {s: L.skin_region_mask(cat, s) for s in L.INNER_SLOTS}
    cache = {}

    def grid(path, size):
        if path not in cache:
            cache[path] = read_grid(path, size, errors)
        return cache[path]

    files, icon_files = {}, {}
    for ln in L.LINES:
        for tid, grade in zip(L.TIER_IDS, grade_keys[ln]):
            tier = tiers[ln][tid]
            colors = pals["palettes"][tier["palette"]]["colors"]
            for slot in L.SLOTS:
                stem = f"{PREFIX}{ln}_{grade}_{slot}"
                layer = {}
                for b in by_slot[slot]:
                    if b["id"] not in tier["on"]:
                        continue
                    sheet = grid(L.box_file(art, ln, b["id"], L.tier_variant(tier, b["id"])), b["sheet"])
                    ox, oy = atlas["boxes"][b["id"]]["rect"][:2]
                    for fx, fy, fw, fh in b["faces"].values():
                        for y in range(fy, fy + fh):
                            for x in range(fx, fx + fw):
                                name = sheet.get((x, y))
                                if name:
                                    layer[(ox + x, oy + y)] = name
                files[stem + ".png"] = layer_image(layer, asize, colors)
                files[stem + "_ench.png"] = mask_image(layer, asize)
                if slot in regions:
                    v = (tier.get("inner") or {}).get(slot)
                    inner = grid(L.inner_file(art, ln, slot, v), SKIN_SIZE) if v else {}
                    skin = {p: n for p, n in inner.items() if p in regions[slot]}
                    files[stem + "_skin.png"] = layer_image(skin, SKIN_SIZE, colors)
                    files[stem + "_skin_ench.png"] = mask_image(skin, SKIN_SIZE)
                if icons:
                    v = (tier.get("icon") or {}).get(slot)
                    if not v:
                        errors.append(f"tiers.json: {ln} {tid} names no icon for {slot}")
                        continue
                    icon = grid(L.icon_file(art, ln, slot, v), ICON_SIZE)
                    istem = f"grug_gear_item_{slot}_{ln}_{grade}"
                    icon_files[istem + ".png"] = layer_image(icon, ICON_SIZE, colors)
                    icon_files[istem + "_ench.png"] = mask_image(icon, ICON_SIZE)
    if errors:
        raise BakeError("\n".join(errors))
    return files, icon_files


def png_bytes(im):
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def same(path, im):
    """True when the PNG at path decodes to exactly this image (mode, size, pixels)."""
    if not path.exists():
        return False
    with Image.open(path) as old:
        return old.mode == im.mode and old.size == im.size and old.tobytes() == im.tobytes()


def compare(files, out, own_prefix):
    """Problems of an output directory against the bake: missing, different,
    and (own_prefix) extra grug_armor_* files."""
    problems = []
    for name, im in sorted(files.items()):
        path = out / name
        if not path.exists():
            problems.append(f"missing {path}")
        elif not same(path, im):
            problems.append(f"differs {path}")
    if own_prefix:
        for path in sorted(out.glob(PREFIX + "*.png")):
            if path.name not in files:
                problems.append(f"extra {path} (the bake does not write it)")
    return problems


def write(files, out, own_prefix):
    """Write changed files; remove grug_armor_* files the bake no longer writes.
    -> (written, removed, total bytes)."""
    out.mkdir(parents=True, exist_ok=True)
    written = removed = total = 0
    for name, im in sorted(files.items()):
        path = out / name
        if not same(path, im):
            path.write_bytes(png_bytes(im))
            written += 1
        total += path.stat().st_size
    if own_prefix:
        for path in sorted(out.glob(PREFIX + "*.png")):
            if path.name not in files:
                path.unlink()
                removed += 1
    return written, removed, total


def contact_sheet(files, icon_files, path):
    """Per line and grade: the four atlas layers over each other, the same with
    the enchant zones tinted (A red, B blue), the skin layers likewise, icons."""
    grade_keys = grades()
    S, SK, IC = 2, 3, 3
    aw, ah = files[next(n for n in files if n.endswith("_head.png"))].size
    cols = [150, aw * S, aw * S, 64 * SK, 64 * SK, 4 * (16 * IC + 4)]
    gap, rowh = 6, max(ah * S, 32 * SK, 16 * IC * 2 + 4) + 6
    width = sum(cols) + gap * len(cols)
    rows = [(ln, g) for ln in L.LINES for g in grade_keys[ln]]
    sheet = Image.new("RGBA", (width, 24 + rowh * len(rows)), (58, 58, 64, 255))
    d = ImageDraw.Draw(sheet)
    heads = ["", "atlas (4 slots)", "zones A red / B blue", "skin layers", "zones", "icons (+ zones)"]
    x = 0
    for c, t in zip(cols, heads):
        d.text((x + 4, 6), t, fill=(230, 230, 230))
        x += c + gap

    def tinted(img, mask):
        out = img.copy()
        h = img.height
        for frame, tint in ((0, (255, 40, 40)), (1, (40, 120, 255))):
            fm = mask.crop((0, frame * h, img.width, (frame + 1) * h))
            col = Image.new("RGBA", img.size, tint + (255,))
            out.paste(col, (0, 0), fm.getchannel("A"))
        return out

    def stack(names):
        base = None
        for n in names:
            im = files[n]
            base = im.copy() if base is None else Image.alpha_composite(base, im)
        return base

    for i, (ln, g) in enumerate(rows):
        y = 24 + i * rowh
        d.text((4, y + 4), f"{ln}\n{g}", fill=(230, 230, 230))
        x = cols[0] + gap
        stem = f"{PREFIX}{ln}_{g}_"
        at = stack([stem + s + ".png" for s in L.SLOTS])
        am = stack([stem + s + "_ench.png" for s in L.SLOTS])
        sk = stack([stem + s + "_skin.png" for s in L.INNER_SLOTS])
        sm = stack([stem + s + "_skin_ench.png" for s in L.INNER_SLOTS])
        for img, scale in ((at, S), (tinted(at, am), S), (sk, SK), (tinted(sk, sm), SK)):
            big = img.resize((img.width * scale, img.height * scale), Image.Resampling.NEAREST)
            sheet.alpha_composite(big, (x, y))
            d.rectangle([x - 1, y - 1, x + big.width, y + big.height], outline=(90, 90, 98))
            x += big.width + gap
        for slot in L.SLOTS:
            n = f"grug_gear_item_{slot}_{ln}_{g}"
            if n + ".png" not in icon_files:
                continue
            ic = icon_files[n + ".png"]
            for k, img in enumerate((ic, tinted(ic, icon_files[n + "_ench.png"]))):
                big = img.resize((16 * IC, 16 * IC), Image.Resampling.NEAREST)
                sheet.alpha_composite(big, (x, y + k * (16 * IC + 4)))
            x += 16 * IC + 4
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--art", default=str(ART), help="art directory (default: tools/r54_art/art)")
    ap.add_argument("--out", default=str(GAME_OUT), help="atlas and skin layers (default: grug_visuals/textures)")
    ap.add_argument("--icons-out", help="also bake the 72 item icons and their masks into this directory")
    ap.add_argument("--check", action="store_true", help="compare instead of writing; exit 1 on a difference")
    ap.add_argument("--sheet", help="write a contact sheet PNG")
    a = ap.parse_args()
    try:
        files, icon_files = bake(a.art, icons=bool(a.icons_out))
    except BakeError as e:
        print("BAKE FAIL\n" + str(e))
        return 1
    out = Path(a.out)
    targets = [(files, out, True)] + ([(icon_files, Path(a.icons_out), False)] if a.icons_out else [])
    if a.check:
        problems = [p for f, o, own in targets for p in compare(f, o, own)]
        for p in problems:
            print("FAIL", p)
        n = sum(len(f) for f, _, _ in targets)
        print(f"r54 bake check: {'FAIL' if problems else 'ok'} ({n} files, art {a.art})")
        rc = 1 if problems else 0
    else:
        for f, o, own in targets:
            written, removed, total = write(f, o, own)
            print(f"r54 bake: {len(f)} files in {o} ({written} written, {removed} removed, {total} bytes)")
        rc = 0
    if a.sheet:
        contact_sheet(files, icon_files, a.sheet)
        print("wrote", a.sheet)
    return rc


if __name__ == "__main__":
    sys.exit(main())
