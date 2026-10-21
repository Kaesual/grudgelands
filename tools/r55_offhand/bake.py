#!/usr/bin/env python3
"""Bake painted offhand art into the game's offhand textures (Round 55 lane BAKE).

Reads an art directory in the contract's layout (docs/technical/offhand-format.md
section 6: shield and book sheets and icons in the reference palette, tiers.json,
optional palettes.json), the armor's palettes (tools/r54_armor/data/palettes.json),
params.json and data/atlas.json, and writes the files of section 7 for every
bracket grade (grug_gear.MATERIALS' metal keys, offhand.grades()):

  grug_offhand_shield_<grade>.png     atlas layer, the atlas size (64 x 64): the
                                      tier's shield sheet palette-swapped into
                                      the sheet of its size step (shield_<step>
                                      of data/atlas.json, params' tier_step);
                                      the other copies and the book transparent
  grug_offhand_book_<grade>.png       atlas layer: the tier's six book box
                                      sheets in their rectangles
  ..._ench.png next to each           enchant mask, grey + alpha, two frames
                                      stacked: frame 0 zone A (A_LIGHT/A_DARK),
                                      frame 1 zone B (B_LIGHT/B_DARK); light
                                      255, dark 153 (as the armor's)
  grug_gear_shield_<grade>.png        shield icon, 16 x 16, and its 16 x 32 mask
  grug_gear_spellbook_<grade>.png     spellbook icon likewise (icons only with
                                      --icons-out)

Only the face rectangles of data/atlas.json are copied (a face the contract
leaves out has no rectangle). The art is validated first; any violation fails
the bake with every problem found and writes nothing:
  - tiers.json: both items, tiers T1..T6, each with a known palette, its
    variant(s) (a book map names known boxes) and, for an icon bake, its icon;
  - file names (shield/<variant>.png, book/<box>_<variant>.png,
    icons/shield|book_<variant>.png; tiers.json, palettes.json and the optional
    cloak_<id>.png and wings_<id>.png at the top) and the files the tiers need;
  - sizes (the atlas sheets, icons 16 x 16; a cloak 32 x 32 and its wings
    16 x 32, size only, not baked), the reference palette only, alpha 0 or 255;
  - opaque: every shield texel the outline contains or crosses (front and
    back, offhand.shield_texels) and every texel of a book face;
  - zones: per item and tier at least 6 zone A and 3 zone B texels on the
    faces it turns outwards (the shield's front texels; the book's cover_f
    front, cover_b back, pages_f back and pages_b front).
Warnings (exit code unchanged): an art file no tier uses, paint outside a
book sheet's faces (dropped).

  python3 bake.py                           bake the picked art (tools/r55_art/art)
                                            into grug_visuals/textures
  python3 bake.py --art DIR [--out DIR]     another art directory or output
  python3 bake.py --icons-out DIR           also write the 12 icons + masks
  python3 bake.py --check [--art ...] [...] rebuild in memory; exit 1 on a
                                            missing, extra (grug_offhand_*) or
                                            different file
  python3 bake.py --sheet OUT.png           contact sheet of the bake
"""
import argparse
import io
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw  # noqa: E402

import offhand as O  # noqa: E402

sys.path.insert(0, str(O.ROOT / "tools/r54_armor"))
import armorlib as L  # noqa: E402

GAME_OUT = O.ROOT / "mods/PLAYER/grug_visuals/textures"
ART = O.ROOT / "tools/r55_art/art"        # the finish step's picked art
PREFIX = "grug_offhand_"
ITEMS = ("shield", "book")
TIER_IDS = L.TIER_IDS
ZONE_MIN = {"A": 6, "B": 3}
# reference name -> (mask frame, grey)
ZONE_GREY = {"A_LIGHT": (0, 255), "A_DARK": (0, 153), "B_LIGHT": (1, 255), "B_DARK": (1, 153)}
ZONE_OF = {"A_LIGHT": "A", "A_DARK": "A", "B_LIGHT": "B", "B_DARK": "B"}
# The book faces counted for the zone minimum: the covers' outsides and the
# readable pages (format doc sections 3.2 and 6).
BOOK_SEEN = (("cover_f", "front"), ("cover_b", "back"), ("pages_f", "back"), ("pages_b", "front"))
ID = re.compile(r"^[a-z0-9]+$")
TOP_FILES = ("tiers.json", "palettes.json")
# Optional cloak textures at the top (format doc section 6): size-checked, not baked.
CLOAK_SIZE = (32, 32)
TOP_TEXTURES = {"cloak": (CLOAK_SIZE, "a cloak texture"), "wings": (O.WINGS_SIZE, "a wing texture")}
TOP_TEXTURE = re.compile(r"^(cloak|wings)_[a-z0-9]+\.png$")


class BakeError(Exception):
    pass


def coords(lst, n=4):
    s = ", ".join("(%d,%d)" % p for p in lst[:n])
    return s + (" ... (+%d)" % (len(lst) - n) if len(lst) > n else "")


# --- art files --------------------------------------------------------------------------
def shield_file(art, v):
    return Path(art) / "shield" / ("%s.png" % v)


def book_file(art, box, v):
    return Path(art) / "book" / ("%s_%s.png" % (box, v))


def icon_art(art, item, v):
    return Path(art) / "icons" / ("%s_%s.png" % (item, v))


def read_grid(path, size, errors):
    """({(x, y): reference name} of a reference-palette PNG's opaque pixels,
    the set of painted pixels off the palette or with partial alpha, whether
    the file was read at its size). A file not read is already an error; one
    read but blank is not, its rules still apply."""
    if not path.exists():
        errors.append("missing %s" % path)
        return {}, set(), False
    try:
        im = Image.open(path).convert("RGBA")
    except Exception as e:  # noqa: BLE001
        errors.append("%s: cannot read (%s)" % (path, e))
        return {}, set(), False
    if im.size != tuple(size):
        errors.append("%s: size %dx%d, expected %dx%d" % (path, im.width, im.height, size[0], size[1]))
        return {}, set(), False
    px = im.load()
    grid, off, partial = {}, [], []
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if a != 255:
                partial.append((x, y))
            name = L.REF_RGB.get((r, g, b))
            if name is None:
                off.append((x, y))
            if a == 255 and name:
                grid[(x, y)] = name
    if off:
        errors.append("%s: %d pixel(s) off the reference palette at %s" % (path, len(off), coords(off)))
    if partial:
        errors.append("%s: %d pixel(s) with partial alpha (only 0 or 255) at %s" % (path, len(partial), coords(partial)))
    return grid, set(off) | set(partial), True


def unknown_files(art, errors):
    """Every file of the art directory must be one of the contract's names.
    -> the set of unknown paths."""
    art = Path(art)
    unknown = set()
    for p in sorted(art.rglob("*")):
        if p.is_dir():
            continue
        rel = p.relative_to(art)
        parts, name = rel.parts, p.name
        if len(parts) == 1:
            m = TOP_TEXTURE.match(name)
            ok = name in TOP_FILES or m
            if m:
                want, what = TOP_TEXTURES[m.group(1)]
                try:
                    with Image.open(p) as im:
                        size = im.size
                except Exception as e:  # noqa: BLE001
                    errors.append("%s: cannot read (%s)" % (p, e))
                else:
                    if size != want:
                        errors.append("%s: size %dx%d, expected %dx%d (%s, not baked)" % ((p,) + size + want + (what,)))
        elif len(parts) == 2 and parts[0] == "shield":
            ok = name.endswith(".png") and ID.match(name[:-4])
        elif len(parts) == 2 and parts[0] == "book":
            box, _, v = name[:-4].rpartition("_") if name.endswith(".png") else ("", "", "")
            ok = box in O.BOOK_BOXES and ID.match(v)
        elif len(parts) == 2 and parts[0] == "icons":
            item, _, v = name[:-4].partition("_") if name.endswith(".png") else ("", "", "")
            ok = item in ITEMS and ID.match(v)
        else:
            ok = False
        if not ok:
            unknown.add(p)
            errors.append("%s: unknown file name (expected shield/<variant>.png, book/<box>_<variant>.png "
                          "with box %s, icons/shield_<variant>.png or icons/book_<variant>.png; at the top "
                          "tiers.json, palettes.json, cloak_<id>.png, wings_<id>.png)" % (p, ", ".join(O.BOOK_BOXES)))
    return unknown


def load_tiers(art, pals, errors, icons):
    """{item: {tier: {palette, variant {sheet: id}, icon}}} from <art>/tiers.json;
    every item and tier must be there (no fallback is baked)."""
    path = Path(art) / "tiers.json"
    try:
        raw = json.loads(path.read_text())
    except Exception as e:  # noqa: BLE001
        raise BakeError("cannot read %s (%s)" % (path, e)) from e
    if not isinstance(raw, dict):
        raise BakeError("%s: expected an object {item: {tier: entry}}" % path)
    for key in raw:
        if key not in ITEMS and not key.startswith("_"):
            errors.append("%s: unknown item '%s' (items: %s)" % (path, key, ", ".join(ITEMS)))
    out = {}
    for item in ITEMS:
        given = raw.get(item)
        if not isinstance(given, dict):
            errors.append("%s: no '%s'" % (path, item))
            given = {}
        for key in given:
            if key not in TIER_IDS and not key.startswith("_"):
                errors.append("%s: %s: unknown tier '%s' (tiers: %s)" % (path, item, key, ", ".join(TIER_IDS)))
        out[item] = {}
        for tid in TIER_IDS:
            where = "%s: %s %s" % (path, item, tid)
            T = given.get(tid)
            if not isinstance(T, dict):
                errors.append("%s: no entry" % where)
                continue
            for key in T:
                if key not in ("palette", "variant", "icon") and not key.startswith("_"):
                    errors.append("%s: unknown key '%s' (palette, variant, icon)" % (where, key))
            pal = T.get("palette")
            if pal is None:
                errors.append("%s: no 'palette'" % where)
            elif pal not in pals["palettes"]:
                errors.append("%s: unknown palette '%s' (palettes: %s)" % (where, pal, ", ".join(pals["palettes"])))
            sheets = ("shield",) if item == "shield" else O.BOOK_BOXES
            v = T.get("variant", "a")
            if isinstance(v, str):
                variant = {s: v for s in sheets}
            elif isinstance(v, dict) and item == "book":
                for box in v:
                    if box not in O.BOOK_BOXES:
                        errors.append("%s: 'variant' names unknown box '%s' (boxes: %s)"
                                      % (where, box, ", ".join(O.BOOK_BOXES)))
                variant = {s: v.get(s, "a") for s in sheets}
            else:
                errors.append("%s: 'variant' must be an id%s" % (where, " or a map box -> id" if item == "book" else ""))
                variant = {s: "a" for s in sheets}
            for s, vid in variant.items():
                if not (isinstance(vid, str) and ID.match(vid)):
                    errors.append("%s: variant %r of %s is not an id (a, b, ...)" % (where, vid, s))
            icon = T.get("icon")
            if icon is not None and not (isinstance(icon, str) and ID.match(icon)):
                errors.append("%s: icon %r is not an id (a, b, ...)" % (where, icon))
                icon = None
            if icon is None and icons:
                errors.append("%s: names no 'icon' (an icon bake needs every tier's icon)" % where)
            out[item][tid] = {"palette": pal, "variant": variant, "icon": icon}
    return out


# --- the rules (format doc section 6) ----------------------------------------------------
def shield_cells(params, faces):
    """{face: set of sheet texels} the outline contains or crosses
    (offhand.shield_texels): the face, the rim and the slanted edges sample
    them, so they must be opaque (format doc sections 4 and 6)."""
    shape = params["shield"]["shape"]
    out = {}
    for face, (fx, fy, fw, fh) in faces.items():
        out[face] = {(fx + c, fy + r) for c, r in O.shield_texels(shape, face)}
    return out


def rect_cells(x, y, w, h):
    return {(x + i, y + j) for j in range(h) for i in range(w)}


def local_faces(sheet):
    """A sheet's face rectangles on its own origin (atlas faces minus the rect)."""
    ox, oy = sheet["rect"][:2]
    return {f: (x - ox, y - oy, w, h) for f, (x, y, w, h) in sheet["faces"].items()}


def check_opaque(path, painted, cells, what, errors):
    holes = sorted((p for p in cells if p not in painted), key=lambda q: (q[1], q[0]))
    if holes:
        errors.append("%s: %d transparent texel(s) %s at %s (sheet pixels; the offhand is opaque)"
                      % (path, len(holes), what, coords(holes)))


def zone_count(grid, cells):
    n = {"A": 0, "B": 0}
    for p in cells:
        z = ZONE_OF.get(grid.get(p))
        if z:
            n[z] += 1
    return n


def check_zones(where, n, errors):
    short = ["%d zone %s (at least %d)" % (n[z], z, ZONE_MIN[z]) for z in ("A", "B") if n[z] < ZONE_MIN[z]]
    if short:
        errors.append("%s: %s" % (where, ", ".join(short)))


# --- the bake --------------------------------------------------------------------------
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


def load_contract():
    """(params, atlas); the committed atlas must be the one params.json packs."""
    try:
        params = O.load()
        atlas = json.loads(O.ATLAS.read_text())
        if atlas != json.loads(json.dumps(O.pack(params))):
            raise BakeError("%s is stale against params.json; run python3 tools/r55_offhand/offhand.py" % O.ATLAS)
        grades = O.grades()
    except O.ContractError as e:
        raise BakeError(str(e)) from e
    return params, atlas, grades


def bake(art, icons=False, warnings=None):
    """-> ({file name: game image}, {file name: icon image}). Raises BakeError
    with every problem found; appends warnings to `warnings` (a list)."""
    art = Path(art)
    if not art.is_dir():
        raise BakeError("no art directory %s (the finish step's picked art; pass --art DIR, e.g. "
                        "tools/r55_offhand/test_art)" % art)
    warnings = [] if warnings is None else warnings
    params, atlas, grade_keys = load_contract()
    sheets = atlas["sheets"]
    asize = tuple(atlas["size"])
    errors = []
    pals, _, perr = L.load_palettes(art)
    errors.extend(perr)
    tiers = load_tiers(art, pals, errors, icons)
    unknown = unknown_files(art, errors)

    s0 = sheets["shield_0"]
    shield_faces = local_faces(s0)
    inside = shield_cells(params, shield_faces)
    cache, read = {}, set()                # read: the paths read at their size

    def sheet_grid(sheet_id, path):
        """A validated sheet grid (rules checked once per file)."""
        if path in cache:
            return cache[path]
        sh = sheets[sheet_id]
        faces = local_faces(sh)
        grid, bad, ok = read_grid(path, sh["rect"][2:], errors)
        painted = set(grid) | bad          # bad pixels are reported once, not again as holes
        if ok:
            read.add(path)
            if sheet_id.startswith("shield"):
                for face, cells in inside.items():
                    check_opaque(path, painted, cells, "the outline contains or crosses (%s face)" % face, errors)
            else:
                face_set = set().union(*(rect_cells(*r) for r in faces.values()))
                check_opaque(path, painted, face_set, "in a face", errors)
                outside = sorted((p for p in painted if p not in face_set), key=lambda q: (q[1], q[0]))
                if outside:
                    warnings.append("%s: %d pixel(s) outside the faces at %s (dropped)"
                                    % (path, len(outside), coords(outside)))
        cache[path] = grid
        return grid

    def icon_grid(path):
        if path not in cache:
            cache[path] = read_grid(path, O.ICON_SIZE, errors)[0]
        return cache[path]

    files, icon_files = {}, {}
    for item in ITEMS:
        for n, (tid, grade) in enumerate(zip(TIER_IDS, grade_keys), start=1):
            tier = tiers[item].get(tid)
            if tier is None or tier["palette"] not in pals["palettes"]:
                continue                       # already an error
            colors = pals["palettes"][tier["palette"]]["colors"]
            layer = {}
            if item == "shield":
                step = O.tier_step(params, n)
                path = shield_file(art, tier["variant"]["shield"])
                grid = sheet_grid("shield_0", path)
                pieces = [("shield_%d" % step, grid)]
                zones = zone_count(grid, inside["front"])
                seen = [path]
                where = "%s (shield %s, size step %d)" % (path, tid, step)
            else:
                paths = {box: book_file(art, box, tier["variant"][box]) for box in O.BOOK_BOXES}
                pieces = [(box, sheet_grid(box, paths[box])) for box in O.BOOK_BOXES]
                zones = {"A": 0, "B": 0}
                for box, face in BOOK_SEEN:
                    fx, fy, fw, fh = local_faces(sheets[box])[face]
                    for z, c in zone_count(dict(pieces)[box], rect_cells(fx, fy, fw, fh)).items():
                        zones[z] += c
                seen = [paths[box] for box, _ in BOOK_SEEN]
                where = "book %s (outer covers and readable pages)" % tid
            if all(p in read for p in seen):     # a file not read is already an error
                check_zones(where, zones, errors)
            for sheet_id, grid in pieces:
                ox, oy = sheets[sheet_id]["rect"][:2]
                for fx, fy, fw, fh in local_faces(sheets[sheet_id]).values():
                    for y in range(fy, fy + fh):
                        for x in range(fx, fx + fw):
                            name = grid.get((x, y))
                            if name:
                                layer[(ox + x, oy + y)] = name
            name = O.layer_file(item, grade)
            files[name] = layer_image(layer, asize, colors)
            files[O.mask_file(name)] = mask_image(layer, asize)
            if tier["icon"]:                    # a named icon is validated in every bake
                grid = icon_grid(icon_art(art, item, tier["icon"]))
                if icons:
                    name = O.icon_file(item, grade)
                    icon_files[name] = layer_image(grid, O.ICON_SIZE, colors)
                    icon_files[O.mask_file(name)] = mask_image(grid, O.ICON_SIZE)
    for d in ("shield", "book", "icons"):
        for p in sorted((art / d).glob("*.png")):
            if p not in cache and p not in unknown:
                warnings.append("%s: no tier in tiers.json uses it" % p)
    if errors:
        raise BakeError("\n".join(errors))
    return files, icon_files


# --- output ---------------------------------------------------------------------------
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
    and (own_prefix) extra grug_offhand_* files."""
    problems = []
    for name, im in sorted(files.items()):
        path = out / name
        if not path.exists():
            problems.append("missing %s" % path)
        elif not same(path, im):
            problems.append("differs %s" % path)
    if own_prefix:
        for path in sorted(out.glob(PREFIX + "*.png")):
            if path.name not in files:
                problems.append("extra %s (the bake does not write it)" % path)
    return problems


def write(files, out, own_prefix):
    """Write changed files; remove grug_offhand_* files the bake no longer
    writes. -> (written, removed, total bytes)."""
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


def tinted(img, mask):
    """The image with zone A texels red and zone B texels blue."""
    out = img.copy()
    h = img.height
    for frame, tint in ((0, (255, 40, 40)), (1, (40, 120, 255))):
        fm = mask.crop((0, frame * h, img.width, (frame + 1) * h))
        out.paste(Image.new("RGBA", img.size, tint + (255,)), (0, 0), fm.getchannel("A"))
    return out


def contact_sheet(files, icon_files, art, path):
    """Per tier: the shield in its size step's sheet (front | back) and with its
    zones tinted (A red, B blue), the book's sheets likewise, the icons."""
    params, atlas, grade_keys = load_contract()
    sheets = atlas["sheets"]
    SS, BS, IS = 8, 5, 4
    sw, sh = sheets["shield_0"]["rect"][2:]
    book = [sheets[b]["rect"] for b in O.BOOK_BOXES]
    bx0, by0 = min(r[0] for r in book), min(r[1] for r in book)
    bx1, by1 = max(r[0] + r[2] for r in book), max(r[1] + r[3] for r in book)
    cols = [110, sw * SS, sw * SS, (bx1 - bx0) * BS, (bx1 - bx0) * BS, 4 * (16 * IS + 6)]
    gap = 8
    rowh = max(sh * SS, (by1 - by0) * BS, 16 * IS) + 16
    sheet = Image.new("RGBA", (sum(cols) + gap * len(cols), 40 + rowh * len(TIER_IDS)), (58, 58, 64, 255))
    d = ImageDraw.Draw(sheet)
    d.text((4, 4), "offhand bake of %s" % art, fill=(230, 230, 230))
    x = 0
    for c, t in zip(cols, ["", "shield (front | back)", "zones A red / B blue", "book sheets", "zones",
                           "icons: shield, book (+ zones)"]):
        d.text((x + 4, 22), t, fill=(230, 230, 230))
        x += c + gap

    def put(img, x, y, scale):
        big = img.resize((img.width * scale, img.height * scale), Image.Resampling.NEAREST)
        sheet.alpha_composite(big, (x, y))
        d.rectangle([x - 1, y - 1, x + big.width, y + big.height], outline=(90, 90, 98))
        return big.width

    for i, (tid, g) in enumerate(zip(TIER_IDS, grade_keys)):
        y = 40 + i * rowh
        step = O.tier_step(params, i + 1)
        d.text((4, y + 4), "%s %s\nshield_%d" % (tid, g, step), fill=(230, 230, 230))
        x = cols[0] + gap
        rx, ry = sheets["shield_%d" % step]["rect"][:2]
        lay, msk = files[O.layer_file("shield", g)], files[O.mask_file(O.layer_file("shield", g))]
        for img in (lay, tinted(lay, msk)):
            put(img.crop((rx, ry, rx + sw, ry + sh)), x, y, SS)
            x += sw * SS + gap
        lay, msk = files[O.layer_file("book", g)], files[O.mask_file(O.layer_file("book", g))]
        for img in (lay, tinted(lay, msk)):
            put(img.crop((bx0, by0, bx1, by1)), x, y, BS)
            x += (bx1 - bx0) * BS + gap
        for item in ITEMS:
            n = O.icon_file(item, g)
            if n in icon_files:
                ic = icon_files[n]
                x += put(ic, x, y, IS) + 6
                x += put(tinted(ic, icon_files[O.mask_file(n)]), x, y, IS) + 6
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--art", default=str(ART), help="art directory (default: tools/r55_art/art)")
    ap.add_argument("--out", default=str(GAME_OUT), help="atlas layers (default: grug_visuals/textures)")
    ap.add_argument("--icons-out", help="also bake the 12 item icons and their masks into this directory")
    ap.add_argument("--check", action="store_true", help="compare instead of writing; exit 1 on a difference")
    ap.add_argument("--sheet", help="write a contact sheet PNG")
    a = ap.parse_args()
    warnings = []
    try:
        files, icon_files = bake(a.art, icons=bool(a.icons_out), warnings=warnings)
    except BakeError as e:
        print("BAKE FAIL\n" + str(e))
        return 1
    finally:
        for w in warnings:
            print("WARNING", w)
    out = Path(a.out)
    targets = [(files, out, True)] + ([(icon_files, Path(a.icons_out), False)] if a.icons_out else [])
    if a.check:
        problems = [p for f, o, own in targets for p in compare(f, o, own)]
        for p in problems:
            print("FAIL", p)
        n = sum(len(f) for f, _, _ in targets)
        print("r55 offhand bake check: %s (%d files, art %s)" % ("FAIL" if problems else "ok", n, a.art))
        rc = 1 if problems else 0
    else:
        for f, o, own in targets:
            written, removed, total = write(f, o, own)
            print("r55 offhand bake: %d files in %s (%d written, %d removed, %d bytes)"
                  % (len(f), o, written, removed, total))
        rc = 0
    if a.sheet:
        contact_sheet(files, icon_files, a.art, a.sheet)
        print("wrote", a.sheet)
    return rc


if __name__ == "__main__":
    sys.exit(main())
