#!/usr/bin/env python3
"""The offhand contract (Round 55, docs/technical/offhand-format.md).

One module the model generator (MODEL), the bake (BAKE) and the preview
page's export (PAGE) agree on:
  * params.json: loading and validating it (section 2 of the format doc);
  * the rotation convention: `euler(rot, order)`;
  * the shield outline and the book's boxes in their own frames (section 3);
  * the offhand atlas: every sheet's rectangle, written to data/atlas.json
    (section 4);
  * the baked file names (section 7).

  python3 offhand.py            validate params.json, write data/atlas.json
  python3 offhand.py --check    exit 1 if params.json is invalid or
                                data/atlas.json is stale
  python3 offhand.py --png OUT  draw the atlas layout at 8x with labels

Pure Python 3 (PIL only for --png).
"""
import argparse
import json
import math
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
TOOL = Path(__file__).resolve().parent
ROOT = TOOL.parents[1]
PARAMS = TOOL / "params.json"
ATLAS = TOOL / "data/atlas.json"
MATERIALS_LUA = ROOT / "mods/ITEMS/grug_gear/init.lua"

FORMAT = 1
ATLAS_W = 64             # the offhand atlas is 64 wide; its height is the smallest
ATLAS_MIN_H = 32         # power of two (at least 32) that holds every sheet
CARD_RESERVE = 16        # a free 16 x 16 rectangle for a later off-hand weapon card
WINGS_SIZE = (16, 32)    # the wing texture (section 6)
ICON_SIZE = (16, 16)
BONES = ("Offhand_Shield", "Offhand_Book")
BACK_CARDS = {"body": "Body", "cloak": "Cloak"}   # card -> bone (format doc §3.3)
BACK_SIZE = (32, 16)     # the back texture: the cloak card left, the body card right
# Every clip the generator keys (player_api's ranges and the Round 40 pose
# clips, gen_cloak_model.py BASE_RANGES and PICKS); the NPC model has only the
# first six.
CLIPS = ("stand", "sit", "lay", "walk", "mine", "walk_mine",
         "cast1", "cast1_walk", "cast2", "cast2_walk", "swing", "swing_walk",
         "bow", "bow_walk", "block", "block_walk", "charge", "charge_walk",
         "flinch", "flinch_walk")
ORDERS = ("XYZ", "XZY", "YXZ", "YZX", "ZXY", "ZYX")
FACES = ("top", "bottom", "right", "front", "left", "back")
# The book's boxes in the closed frame (section 3.2): faces each one leaves out.
BOOK_BOXES = ("cover_f", "cover_b", "pages_f", "pages_b", "spine", "ribbon")
BOOK_SKIP = {"pages_f": ("front",), "pages_b": ("back",), "ribbon": ("top",)}


class ContractError(Exception):
    pass


# --- grades -----------------------------------------------------------------------
def grades():
    """The metal grade keys of brackets 1..6 (grug_gear.MATERIALS): the shields'
    and spellbooks' item names and the baked file names use them."""
    text = MATERIALS_LUA.read_text()
    block = re.search(r"\ngrug_gear\.MATERIALS = \{\n(.*?)\n\}\n", text, re.S)
    if not block:
        raise ContractError("grug_gear.MATERIALS not found in %s" % MATERIALS_LUA)
    keys = re.findall(r"\bmetal = \{key = \"([a-z0-9_]+)\"", block.group(1))
    if len(keys) != 6:
        raise ContractError("grug_gear.MATERIALS: expected 6 metal grades, read %s" % keys)
    return keys


# --- the baked file names (section 7) -----------------------------------------------
def layer_file(item, grade):
    """The offhand atlas layer of a shield or spellbook (grug_visuals/textures)."""
    return "grug_offhand_%s_%s.png" % (item, grade)


def icon_file(item, grade):
    """The item icon (grug_gear/textures); the shields keep today's names."""
    return ("grug_gear_shield_%s.png" if item == "shield" else "grug_gear_spellbook_%s.png") % grade


def mask_file(name):
    return name[:-len(".png")] + "_ench.png"


# --- rotations ----------------------------------------------------------------------
def axis_matrix(axis, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    if axis == "X":
        return ((1, 0, 0), (0, c, -s), (0, s, c))
    if axis == "Y":
        return ((c, 0, s), (0, 1, 0), (-s, 0, c))
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


def mat_mul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def euler(rot, order):
    """The rotation matrix (rows) of `rot` = [x, y, z] degrees in `order`:
    R = R_A(rot_A) * R_B(rot_B) * R_C(rot_C) for order "ABC", each R_axis the
    standard right-handed matrix acting on column vectors (three.js's Euler with
    the same order string). The angles are always listed x, y, z."""
    m = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    for axis in order:
        m = mat_mul(m, axis_matrix(axis, rot["XYZ".index(axis)]))
    return m


def place(placement, p, scale=1.0):
    """An item point (its own frame, skin pixels) at rest in the catalog frame."""
    r = euler(placement["rot"], placement["order"])
    q = [scale * c for c in p]
    return tuple(placement["pos"][i] + sum(r[i][k] * q[k] for k in range(3)) for i in range(3))


# --- the shapes (section 3) -----------------------------------------------------------
def shield_outline(shape):
    """The shield's outline (x, y) in its own frame, clockwise from the top left
    seen from the front, and its levels (T top, S shoulder, M waist, B point)."""
    W, H = shape["width"] / 2, shape["height"]
    T = H * shape["top"]
    B = T - H
    S = T - H * shape["shoulder"]
    M = (S + B) / 2
    k = shape["taper"]
    pts = [(-W, T), (0, T), (W, T), (W, S), (W * k, M), (0, B), (-W * k, M), (-W, S)]
    return pts, {"T": T, "S": S, "M": M, "B": B, "W": W}


def _clip_area(poly, x0, y0, x1, y1):
    """Area of a polygon clipped to the rectangle (Sutherland-Hodgman)."""
    def clip(pts, inside, cut):
        out = []
        for a, b in zip(pts, pts[1:] + pts[:1]):
            if inside(b):
                if not inside(a):
                    out.append(cut(a, b))
                out.append(b)
            elif inside(a):
                out.append(cut(a, b))
        return out

    def at_x(c):
        return lambda a, b: (c, a[1] + (b[1] - a[1]) * (c - a[0]) / (b[0] - a[0]))

    def at_y(c):
        return lambda a, b: (a[0] + (b[0] - a[0]) * (c - a[1]) / (b[1] - a[1]), c)
    pts = list(poly)
    for inside, cut in ((lambda p: p[0] >= x0, at_x(x0)), (lambda p: p[0] <= x1, at_x(x1)),
                        (lambda p: p[1] >= y0, at_y(y0)), (lambda p: p[1] <= y1, at_y(y1))):
        if not pts:
            return 0.0
        pts = clip(pts, inside, cut)
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))) / 2 if pts else 0.0


def shield_texels(shape, side):
    """{(column, row)} of a shield face's texels the outline contains or crosses
    with positive area (format doc §6: they must be opaque; the rest is never
    sampled). `side` is "front" (column 0 at -x) or "back" (column 0 at +x)."""
    poly, lv = shield_outline(shape)
    W, H = texels(shape["width"]), texels(shape["height"])
    sx, sy = 2 * lv["W"] / W, shape["height"] / H
    out = set()
    for cy in range(H):
        y1 = lv["T"] - cy * sy
        for cx in range(W):
            x0 = -lv["W"] + cx * sx if side == "front" else lv["W"] - (cx + 1) * sx
            if _clip_area(poly, x0, y1 - sy, x0 + sx, y1) > 1e-9:
                out.add((cx, cy))
    return out


def shield_front_z(shape, x):
    """z of the front face at x (the ridge runs down x = 0); the back face is
    `thick` lower. The frame's origin lies in the plane of the back rim."""
    W = shape["width"] / 2
    return shape["thick"] + shape["ridge"] * (1 - abs(x) / W)


def book_boxes(shape, ribbon):
    """{box: (x0, y0, z0, x1, y1, z1)} of the book in its CLOSED frame (section
    3.2): the spine along y at x = 0, the front half at z > 0, the back half at
    z < 0, page tops at +y. The halves then open about the y axis (book_turn);
    the spine is not turned: it is the plate behind the open halves that joins
    the covers' spine edges (at x = -(p + c) sin(open / 2), z = +-(p + c)
    cos(open / 2)), at least spine_min thick each way."""
    w, h, p, c, i = shape["width"], shape["height"], shape["pages"] / 2, shape["cover"], shape["inset"]
    sp = max(c, shape["spine_min"])
    a = math.radians(shape["open"] / 2)
    back, half = (p + c) * math.sin(a), max((p + c) * math.cos(a), sp / 2)
    return {
        "cover_f": (0, -h / 2, p, w, h / 2, p + c),
        "cover_b": (0, -h / 2, -p - c, w, h / 2, -p),
        "pages_f": (0, -h / 2 + i, 0, w - i, h / 2 - i, p),
        "pages_b": (0, -h / 2 + i, -p, w - i, h / 2 - i, 0),
        "spine": (-back - sp, -h / 2, -half, -back, h / 2, half),
        "ribbon": (ribbon["x0"], -h / 2 - ribbon["below"], -ribbon["half_depth"],
                   ribbon["x1"], -h / 2 + ribbon["into"], ribbon["half_depth"]),
    }


def book_turn(shape, box):
    """Degrees about the y axis that opens a box's half (euler order Y): the
    front half -open/2, the back half +open/2, spine and ribbon 0."""
    if box.endswith("_f"):
        return -shape["open"] / 2
    if box.endswith("_b"):
        return shape["open"] / 2
    return 0.0


CLOAK_HALF_W = 2.05 / 0.525   # the cloak's half-width in skin pixels (gen_cloak_model.HALF_W)


def wing_hinge_x(wings):
    """|x| of the wings' hinge line (format doc §3.4): the cloak's side, inset by
    thick / 2 * sin(angle) + 0.05 px so the turned wing starts inside the cloak."""
    e = wings["thick"] / 2 * math.sin(math.radians(abs(wings["angle"]))) + 0.05
    return CLOAK_HALF_W - e


# --- sheets and the atlas (section 4) -------------------------------------------------
def texels(size):
    return max(1, int(math.floor(size + 0.5)))


def box_sheet(box):
    """(sheet w, h, faces) of a box: the classic unwrap of armor-format.md §4."""
    x0, y0, z0, x1, y1, z1 = box
    W, H, D = texels(x1 - x0), texels(y1 - y0), texels(z1 - z0)
    faces = {"top": (D, 0, W, D), "bottom": (D + W, 0, W, D), "right": (0, D, D, H),
             "front": (D, D, W, H), "left": (D + W, D, D, H), "back": (2 * D + W, D, W, H)}
    return 2 * D + 2 * W, D + H, faces


def sheets(params):
    """{sheet id: (w, h, {face: (x, y, w, h)})} on their own origin."""
    out = {}
    s = params["shield"]["shape"]
    W, H = texels(s["width"]), texels(s["height"])
    for step in range(len(params["shield"]["sizes"])):
        out["shield_%d" % step] = (2 * W, H, {"front": (0, 0, W, H), "back": (W, 0, W, H)})
    for box_id, box in book_boxes(params["book"]["shape"], params["book"]["ribbon"]).items():
        w, h, faces = box_sheet(box)
        for f in BOOK_SKIP.get(box_id, ()):
            faces.pop(f)
        out[box_id] = (w, h, faces)
    out["card"] = (CARD_RESERVE, CARD_RESERVE, {"front": (0, 0, CARD_RESERVE, CARD_RESERVE)})
    return out


def pack(params):
    """Shelves left to right, sheets sorted by height, then width (descending),
    then id; no gutter (as the armor atlas)."""
    sh = sheets(params)
    order = sorted(sh, key=lambda k: (-sh[k][1], -sh[k][0], k))
    x = y = shelf = 0
    rects = {}
    for k in order:
        w, h, faces = sh[k]
        if w > ATLAS_W:
            raise ContractError("sheet %s is %d wide, the atlas %d" % (k, w, ATLAS_W))
        if x + w > ATLAS_W:
            x, y, shelf = 0, y + shelf, 0
        rects[k] = {"rect": [x, y, w, h],
                    "faces": {f: [x + fx, y + fy, fw, fh] for f, (fx, fy, fw, fh) in faces.items()}}
        x += w
        shelf = max(shelf, h)
    used = y + shelf
    height = ATLAS_MIN_H
    while height < used:
        height *= 2
    return {"_doc": "Generated by tools/r55_offhand/offhand.py from params.json; "
                    "docs/technical/offhand-format.md section 4. Rects [x, y, w, h] in texels, origin top left.",
            "size": [ATLAS_W, height], "used_rows": used,
            "sheets": {k: rects[k] for k in sorted(rects)}}


# --- params.json (section 2) -----------------------------------------------------------
def _vec(v, n=3):
    return isinstance(v, list) and len(v) == n and all(isinstance(c, (int, float)) for c in v)


def _num(v, lo=None, hi=None):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and \
        (lo is None or v >= lo) and (hi is None or v <= hi)


def _placement(where, pl, bones, errors):
    if not isinstance(pl, dict):
        errors.append("%s: not an object" % where)
        return
    if bones is not None and pl.get("bone") not in bones:
        errors.append("%s.bone: %r, expected one of %s" % (where, pl.get("bone"), ", ".join(bones)))
    for key in ("pos", "rot"):
        if not _vec(pl.get(key)):
            errors.append("%s.%s: expected three numbers" % (where, key))
    if pl.get("order") not in ORDERS:
        errors.append("%s.order: %r, expected one of %s" % (where, pl.get("order"), ", ".join(ORDERS)))


def _shape(where, shape, spec, errors):
    for key, lo, hi in spec:
        if not _num(shape.get(key), lo, hi):
            errors.append("%s.%s: %r, expected a number in [%s, %s]" % (where, key, shape.get(key), lo, hi))
    extra = set(shape) - {k for k, _, _ in spec}
    if extra:
        errors.append("%s: unknown key(s) %s" % (where, ", ".join(sorted(extra))))


def _clip(where, entry, errors):
    if not isinstance(entry, dict):
        errors.append("%s: not an object" % where)
        return
    if entry.get("order") not in ORDERS:
        errors.append("%s.order: %r, expected one of %s" % (where, entry.get("order"), ", ".join(ORDERS)))
    if not _num(entry.get("steady", 0), 0, 1):
        errors.append("%s.steady: %r, expected a number in [0, 1]" % (where, entry.get("steady")))
    if "keys" in entry:
        if "rot" in entry or "pos" in entry:
            errors.append("%s: either rot/pos or keys, not both" % where)
        keys = entry["keys"]
        if not isinstance(keys, list) or not keys:
            errors.append("%s.keys: expected a non-empty list" % where)
            return
        frames = []
        for i, k in enumerate(keys):
            if not isinstance(k, dict) or not isinstance(k.get("frame"), int) or k["frame"] < 0:
                errors.append("%s.keys[%d].frame: expected an integer >= 0" % (where, i))
                continue
            frames.append(k["frame"])
            if not _vec(k.get("rot", [0, 0, 0])) or not _vec(k.get("pos", [0, 0, 0])):
                errors.append("%s.keys[%d]: rot and pos are three numbers" % (where, i))
        if frames != sorted(set(frames)):
            errors.append("%s.keys: frames must rise strictly" % where)
    else:
        if not _vec(entry.get("rot", [0, 0, 0])) or not _vec(entry.get("pos", [0, 0, 0])):
            errors.append("%s: rot and pos are three numbers" % where)
    extra = set(entry) - {"rot", "pos", "order", "steady", "keys"}
    if extra:
        errors.append("%s: unknown key(s) %s" % (where, ", ".join(sorted(extra))))


def validate(p):
    """A list of problems (empty = valid)."""
    errors = []
    if not isinstance(p, dict) or p.get("format") != FORMAT:
        return ["format: expected %d" % FORMAT]
    sh, bk = p.get("shield", {}), p.get("book", {})
    _shape("shield.shape", sh.get("shape", {}), (
        ("width", 2, 20), ("height", 2, 24), ("top", 0.1, 0.9), ("shoulder", 0.05, 0.95),
        ("taper", 0, 1), ("ridge", 0, 4), ("thick", 0.1, 3)), errors)
    if sh.get("boss") is not None:
        _shape("shield.boss", sh["boss"], (("radius", 0.1, 4), ("height", 0, 3), ("lift", -1, 1)), errors)
    sizes = sh.get("sizes")
    if not (isinstance(sizes, list) and len(sizes) == 3 and all(_num(v, 0.3, 1.5) for v in sizes)):
        errors.append("shield.sizes: expected three numbers in [0.3, 1.5]")
    steps = sh.get("tier_step", {})
    if sorted(steps) != [str(t) for t in range(1, 7)] or any(v not in (0, 1, 2) for v in steps.values()):
        errors.append("shield.tier_step: expected brackets \"1\"..\"6\" -> 0, 1 or 2")
    _placement("shield.place", sh.get("place"), BONES, errors)
    _shape("book.shape", bk.get("shape", {}), (
        ("width", 1, 12), ("height", 1, 14), ("pages", 0.25, 6), ("cover", 0.1, 2), ("open", 0, 180),
        ("inset", 0, 2), ("spine_min", 0, 2)), errors)
    _shape("book.ribbon", bk.get("ribbon") or {}, (("x0", -1, 8), ("x1", -1, 8), ("below", 0, 8), ("into", 0, 4),
                                                   ("half_depth", 0.05, 2)), errors)
    _placement("book.place", bk.get("place"), BONES, errors)
    back = p.get("back", {})
    for card in BACK_CARDS:
        _placement("back.%s" % card, back.get(card), None, errors)
        if isinstance(back.get(card), dict) and set(back[card]) - {"pos", "rot", "order"}:
            errors.append("back.%s: unknown key(s) %s" % (card, ", ".join(sorted(set(back[card]) - {"pos", "rot", "order"}))))
    if not _num(back.get("size"), 2, 32):
        errors.append("back.size: expected a number in [2, 32]")
    if set(back) - {"size", "body", "cloak"}:
        errors.append("back: unknown key(s) %s" % ", ".join(sorted(set(back) - {"size", "body", "cloak"})))
    _shape("wings", p.get("wings", {}), (("width", 0.5, 8), ("angle", -10, 90), ("drop", 0, 12),
                                         ("thick", 0.05, 0.65)), errors)
    bones = p.get("bones", {})
    if sorted(bones) != sorted(BONES):
        errors.append("bones: expected exactly %s" % ", ".join(BONES))
    for name, bone in bones.items():
        if not isinstance(bone, dict) or not _vec(bone.get("pivot")):
            errors.append("bones.%s.pivot: expected three numbers" % name)
            continue
        clips = bone.get("clips", {})
        for clip, entry in clips.items():
            if clip not in CLIPS:
                errors.append("bones.%s.clips.%s: unknown clip (known: %s)" % (name, clip, ", ".join(CLIPS)))
                continue
            _clip("bones.%s.clips.%s" % (name, clip), entry, errors)
    for key in set(p) - {"_doc", "format", "shield", "book", "back", "wings", "bones"}:
        errors.append("%s: unknown key" % key)
    return errors


def load(path=PARAMS):
    p = json.loads(Path(path).read_text())
    errors = validate(p)
    if errors:
        raise ContractError("%s:\n  %s" % (path, "\n  ".join(errors)))
    return p


def tier_step(params, bracket):
    return params["shield"]["tier_step"][str(bracket)]


# --- CLI ------------------------------------------------------------------------------
def draw(atlas, path):
    from PIL import Image, ImageDraw
    k = 8
    w, h = atlas["size"]
    im = Image.new("RGB", (w * k, h * k), (40, 40, 44))
    d = ImageDraw.Draw(im)
    for name, s in atlas["sheets"].items():
        for face, (fx, fy, fw, fh) in s["faces"].items():
            d.rectangle([fx * k, fy * k, (fx + fw) * k - 1, (fy + fh) * k - 1], fill=(90, 110, 140), outline=(20, 20, 20))
        x, y, rw, rh = s["rect"]
        d.rectangle([x * k, y * k, (x + rw) * k - 1, (y + rh) * k - 1], outline=(240, 200, 90))
        d.text((x * k + 3, y * k + 2), name, fill=(255, 255, 255))
    im.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--png")
    ap.add_argument("--params", default=str(PARAMS))
    args = ap.parse_args()
    try:
        params = load(args.params)
        grades()
        atlas = pack(params)
    except ContractError as e:
        print("offhand: %s" % e, file=sys.stderr)
        return 1
    text = json.dumps(atlas, indent=1, sort_keys=True) + "\n"
    if args.check:
        if not ATLAS.exists() or ATLAS.read_text() != text:
            print("offhand: data/atlas.json is stale; run python3 tools/r55_offhand/offhand.py", file=sys.stderr)
            return 1
        print("offhand: params.json valid, atlas %dx%d current" % tuple(atlas["size"]))
        return 0
    ATLAS.write_text(text)
    print("offhand: wrote %s (%dx%d, %d rows used)" % (ATLAS.relative_to(ROOT), *atlas["size"], atlas["used_rows"]))
    if args.png:
        draw(atlas, args.png)
    return 0


if __name__ == "__main__":
    sys.exit(main())
