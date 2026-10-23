"""Shared helpers for the armor render/check tool: reference palette, catalog
access, sheet layout, box geometry (rest pose, mirrored copies, z rotations)
and art file lookup. The data lives in data/ (written by export.py)."""
import json
import math
from pathlib import Path

from PIL import Image

TOOL = Path(__file__).resolve().parent
DATA = TOOL / "data"
LINES = ["metal", "leather", "cloth"]
SLOTS = ["head", "chest", "legs", "feet"]
INNER_SLOTS = ["chest", "legs", "feet"]          # head has no inner paint (spec §3)

# Reference palette (spec §4): index, name, hex, meaning
REFERENCE = [
    (1, "M_HI", "#F0F0F0", "material highlight"),
    (2, "M_LIGHT", "#C8C8C8", "material light"),
    (3, "M_MID", "#A0A0A0", "material base"),
    (4, "M_DARK", "#787878", "material shade"),
    (5, "M_DEEP", "#505050", "material deep shade, seams"),
    (6, "OUTLINE", "#282828", "gaps, slits, darkest line"),
    (7, "ACC_LIGHT", "#A07850", "accent material (straps, under-leather, rope) light"),
    (8, "ACC_DARK", "#6E5034", "accent material dark"),
    (9, "A_LIGHT", "#E07070", "zone A (prefix): cloth, tabard, lining, stole - light"),
    (10, "A_DARK", "#B04848", "zone A dark"),
    (11, "B_LIGHT", "#70A0E0", "zone B (suffix): fittings, buckles, rivets, hem, gem - light"),
    (12, "B_DARK", "#4870B0", "zone B dark"),
    (13, "GLOW", "#FFC040", "glow (ember seams); M_LIGHT on palettes without glow"),
]
REF_NAMES = [r[1] for r in REFERENCE]


def hex_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def rgb_hex(c):
    return "#%02X%02X%02X" % tuple(c[:3])


REF_RGB = {hex_rgb(h): name for _, name, h, _ in REFERENCE}     # rgb -> name
ZONE_A = {hex_rgb("#E07070"), hex_rgb("#B04848")}
ZONE_B = {hex_rgb("#70A0E0"), hex_rgb("#4870B0")}


def load_catalog():
    return json.loads((DATA / "catalog.json").read_text())


def pieces(cat):
    """Every catalog box, then every polygon part (spec §1a): the things a tier wears, in catalog order. A part
    entry carries the box keys the sheet tools read (id, slot, bone, sheet, `faces` = name -> rect, mirror False)
    plus `kind` "poly", `vertices` and `polys` (its faces with vertex indices, uv and normal)."""
    return list(cat["boxes"]) + list(cat.get("parts", []))


def load_palettes(art=None, path=None):
    """-> (palettes, notes, errors). The base is data/palettes.json; palettes
    from `path` (or, without one, <art>/palettes.json when it exists) are laid
    over it by name, so a painter can propose tier palettes in an art drop.
    Every palette must give all 13 reference names as #RRGGBB."""
    pals = json.loads((DATA / "palettes.json").read_text())
    notes, errors = [], []
    src = Path(path) if path else (Path(art) / "palettes.json" if art else None)
    if src is not None and (path or src.exists()):
        try:
            extra = json.loads(src.read_text())
        except Exception as e:  # noqa: BLE001
            errors.append(f"palettes: cannot read {src} ({e}); using data/palettes.json")
            extra = {}
        given = extra.get("palettes", {}) if isinstance(extra, dict) else {}
        if not isinstance(given, dict):
            errors.append(f"palettes: {src}: 'palettes' must be an object name -> palette")
            given = {}
        for name, p in given.items():
            if name.startswith("_"):
                continue
            cols = p.get("colors") if isinstance(p, dict) else None
            if not isinstance(cols, dict):
                errors.append(f"palettes: {src}: '{name}' has no 'colors' object")
                continue
            bad = [n for n in REF_NAMES if not _is_hex(cols.get(n))]
            unknown = [n for n in cols if n not in REF_NAMES]
            if bad or unknown:
                errors.append(f"palettes: {src}: '{name}': " + "; ".join(
                    ([f"missing or not #RRGGBB: {', '.join(bad)}"] if bad else []) +
                    ([f"unknown names: {', '.join(unknown)}"] if unknown else [])))
                continue
            base = pals["palettes"].get(name, {})
            pals["palettes"][name] = {"name": p.get("name", base.get("name", name)),
                                      "line": p.get("line", base.get("line")), "tier": p.get("tier", base.get("tier")),
                                      "colors": {n: cols[n].upper() for n in REF_NAMES}}
        notes.append(f"palettes: data/palettes.json with {len(given)} from {src} laid over it")
    return pals, notes, errors


def _is_hex(v):
    return isinstance(v, str) and len(v) == 7 and v[0] == "#" and all(c in "0123456789abcdefABCDEF" for c in v[1:])


def texels(size):
    """Texel count for a box edge of `size` skin pixels (spec §2)."""
    return max(1, int(math.floor(size + 0.5)))


def sheet_faces(W, H, D):
    """Face rectangles (x, y, w, h) on a box sheet, classic skin unwrap (spec §2)."""
    return {
        "top": (D, 0, W, D), "bottom": (D + W, 0, W, D),
        "right": (0, D, D, H), "front": (D, D, W, H),
        "left": (D + W, D, D, H), "back": (2 * D + W, D, W, H),
    }


def sheet_size(W, H, D):
    return (2 * D + 2 * W, D + H)


# ---------- geometry (rest pose, model space in skin pixels) ----------
FACE_NORMAL = {"front": (0, 0, 1), "back": (0, 0, -1), "right": (-1, 0, 0), "left": (1, 0, 0),
               "top": (0, 1, 0), "bottom": (0, -1, 0)}


def face_point(box, face, u, v):
    """Local (unrotated, right-copy) point on a face at face coords u,v in 0..1
    (u = sheet column direction, v = sheet row direction, row 0 at the top)."""
    x0, y0, z0, x1, y1, z1 = box
    w, h, d = x1 - x0, y1 - y0, z1 - z0
    if face == "front":
        return (x0 + u * w, y1 - v * h, z1)
    if face == "back":
        return (x1 - u * w, y1 - v * h, z0)
    if face == "right":
        return (x0, y1 - v * h, z0 + u * d)
    if face == "left":
        return (x1, y1 - v * h, z1 - u * d)
    if face == "top":
        return (x0 + u * w, y1, z0 + v * d)
    if face == "bottom":
        return (x0 + u * w, y0, z1 - v * d)
    raise ValueError(face)


def face_uv(box, face, p):
    """Inverse of face_point: (u, v) in 0..1 of a local point on a face."""
    x0, y0, z0, x1, y1, z1 = box
    w, h, d = x1 - x0, y1 - y0, z1 - z0
    x, y, z = p
    return {
        "front": ((x - x0) / w, (y1 - y) / h), "back": ((x1 - x) / w, (y1 - y) / h),
        "right": ((z - z0) / d, (y1 - y) / h), "left": ((z1 - z) / d, (y1 - y) / h),
        "top": ((x - x0) / w, (z - z0) / d), "bottom": ((x - x0) / w, (z1 - z) / d),
    }[face]


def faces_at(box, p, eps=1e-6):
    """Faces whose plane contains the local point p (p on the box surface)."""
    x0, y0, z0, x1, y1, z1 = box
    planes = {"right": (0, x0), "left": (0, x1), "bottom": (1, y0), "top": (1, y1), "back": (2, z0), "front": (2, z1)}
    return [f for f, (k, c) in planes.items() if abs(p[k] - c) < eps]


def _rot(p, axis, deg, o, inverse=False):
    a = math.radians(-deg if inverse else deg)
    c, s = math.cos(a), math.sin(a)
    x, y, z = p[0] - o[0], p[1] - o[1], p[2] - o[2]
    if axis == "z":
        x, y = x * c - y * s, x * s + y * c
    elif axis == "x":
        y, z = y * c - z * s, y * s + z * c
    elif axis == "y":
        x, z = x * c + z * s, -x * s + z * c
    return (x + o[0], y + o[1], z + o[2])


class Instance:
    """One placed copy of a catalog box (the right/only copy, or the mirrored left copy)."""

    def __init__(self, b, mirrored):
        self.b = b
        self.id = b["id"]
        self.mirrored = mirrored
        self.side = ("L" if mirrored else ("R" if b["mirror"] else ""))
        self.box = b["box"]
        self.rot = b["rot"]

    @property
    def name(self):
        return self.id + ("." + self.side if self.side else "")

    def to_world(self, p):
        if self.rot:
            p = _rot(p, self.rot[0], self.rot[1], self.rot[2])
        if self.mirrored:
            p = (-p[0], p[1], p[2])
        return p

    def dir_to_world(self, n):
        if self.rot:
            n = _rot(n, self.rot[0], self.rot[1], (0, 0, 0))
        if self.mirrored:
            n = (-n[0], n[1], n[2])
        return n

    def to_local(self, p):
        if self.mirrored:
            p = (-p[0], p[1], p[2])
        if self.rot:
            p = _rot(p, self.rot[0], self.rot[1], self.rot[2], inverse=True)
        return p

    def contains_segment(self, p, n, length, eps=1e-6):
        """Does the world segment p .. p + length*n touch this box's volume (closed)?"""
        a = self.to_local(p)
        q = self.to_local((p[0] + n[0] * length, p[1] + n[1] * length, p[2] + n[2] * length))
        t0, t1 = 0.0, 1.0
        for i in range(3):
            lo, hi = self.box[i] - eps, self.box[i + 3] + eps
            da = q[i] - a[i]
            if abs(da) < 1e-12:
                if a[i] < lo or a[i] > hi:
                    return False
                continue
            ta, tb = (lo - a[i]) / da, (hi - a[i]) / da
            if ta > tb:
                ta, tb = tb, ta
            t0, t1 = max(t0, ta), min(t1, tb)
            if t0 > t1:
                return False
        return True

    def world_aabb(self):
        x0, y0, z0, x1, y1, z1 = self.box
        pts = [self.to_world((x, y, z)) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
        return [min(p[i] for p in pts) for i in range(3)] + [max(p[i] for p in pts) for i in range(3)]


def instances(boxes):
    out = []
    for b in boxes:
        out.append(Instance(b, False))
        if b["mirror"]:
            out.append(Instance(b, True))
    return out


# ---------- opacity (the user, 2026-10-20: armor is opaque; only the helm's face stays open) ----------
FACE_RECT = (-4.0, 24.0, 4.0, 32.0)   # the head's front face (x0, y0, x1, y1), skin pixels


def open_window(b):
    """Sheet pixels that may be transparent: the texels of the helm's front face lying wholly in front of the
    head's front face (the face opening; the head is directly behind, so it leaves no hole). Empty for every
    other box."""
    if b["id"] != "helm":
        return set()
    fx, fy, fw, fh = b["faces"]["front"]
    x0, y0, _, x1, y1, _ = b["box"]
    hx0, hy0, hx1, hy1 = FACE_RECT
    out = set()
    for r in range(fh):
        for c in range(fw):
            tx0, tx1 = x0 + c * (x1 - x0) / fw, x0 + (c + 1) * (x1 - x0) / fw
            ty1, ty0 = y1 - r * (y1 - y0) / fh, y1 - (r + 1) * (y1 - y0) / fh
            if tx0 >= hx0 - 1e-9 and tx1 <= hx1 + 1e-9 and ty0 >= hy0 - 1e-9 and ty1 <= hy1 + 1e-9:
                out.add((fx + c, fy + r))
    return out


# ---------- the chin strip (Round 56 ruling 17; its underside Round 57 ruling 24) ----------
# The helm front face's bottom row may stay transparent on every cloth head piece and on the leather ones without
# a veil (T1-T5); leather T6 and metal stay opaque there (the user, 2026-10-22).
CHIN_TIERS = {"cloth": ("T1", "T2", "T3", "T4", "T5", "T6"), "leather": ("T1", "T2", "T3", "T4", "T5")}


def chin_row(b):
    """Sheet pixels of the helm front face's bottom row; empty for every other box."""
    if b["id"] != "helm":
        return set()
    fx, fy, fw, fh = b["faces"]["front"]
    return {(fx + c, fy + fh - 1) for c in range(fw)}


# Round 57 ruling 24: the strip continues under the chin. The helm's bottom face (its top row is the front edge)
# opens in every row that starts in front of the neck (the body's front face), full width like the strip; the head's
# underside is directly above it. The rows behind lie under the neck and stay opaque.
NECK_FRONT_Z = 2.0   # the body's front face (z), skin pixels


def chin_under(b):
    """Sheet pixels of the helm bottom face's rows under the chin (Round 57 ruling 24); empty for every other
    box."""
    if b["id"] != "helm":
        return set()
    fx, fy, fw, fh = b["faces"]["bottom"]
    z1 = b["box"][5]
    depth = (z1 - b["box"][2]) / fh
    return {(fx + c, fy + r) for r in range(fh) if z1 - r * depth > NECK_FRONT_Z + 1e-9 for c in range(fw)}


def chin_texels(b):
    """Every sheet pixel of the open chin: the strip on the front face and its continuation under the chin."""
    return chin_row(b) | chin_under(b)


def chin_open(line, tids):
    """May a helm sheet worn by these tiers of `line` leave its chin strip open? Yes when every tier wearing it is
    a chin-strip tier (a sheet no tier wears: when the line has chin-strip tiers)."""
    allowed = CHIN_TIERS.get(line, ())
    return bool(allowed) and all(t in allowed for t in tids)


# ---------- art files ----------
def box_file(art, line, box_id, variant):
    return Path(art) / line / f"{box_id}_{variant}.png"


def inner_file(art, line, slot, variant):
    return Path(art) / line / "inner" / f"{slot}_{variant}.png"


def icon_file(art, line, slot, variant):
    return Path(art) / line / "icons" / f"{slot}_{variant}.png"


def tier_variant(tier, box_id):
    return (tier.get("variant") or {}).get(box_id, "a")


def expected_files(cat, art, line, tier):
    """[(kind, key, variant, path)] for one tier: box sheets of the worn boxes,
    inner paint and icons."""
    out = []
    for bid in tier["on"]:
        v = tier_variant(tier, bid)
        out.append(("box", bid, v, box_file(art, line, bid, v)))
    for slot, v in (tier.get("inner") or {}).items():
        if v:
            out.append(("inner", slot, v, inner_file(art, line, slot, v)))
    for slot, v in (tier.get("icon") or {}).items():
        if v:
            out.append(("icon", slot, v, icon_file(art, line, slot, v)))
    return out


def load_rgba(path):
    return Image.open(path).convert("RGBA")


def checker(size, cell=1, a=(255, 0, 255, 255), b=(40, 0, 40, 255)):
    """Magenta checker that marks missing art."""
    im = Image.new("RGBA", size)
    px = im.load()
    for y in range(size[1]):
        for x in range(size[0]):
            px[x, y] = a if ((x // cell) + (y // cell)) % 2 == 0 else b
    return im


def palette_map(palettes, name):
    """reference rgb -> palette rgb for one tier palette."""
    pal = palettes["palettes"][name]["colors"]
    return {hex_rgb(h): hex_rgb(pal[n]) for _, n, h, _ in REFERENCE}


def apply_palette(img, mapping):
    """Swap reference colours for palette colours by exact match; other
    colours stay (check.py reports them). Alpha is hardened at 128."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            c = mapping.get((r, g, b), (r, g, b))
            px[x, y] = (c[0], c[1], c[2], 255)
    return out


def skin_region_mask(cat, slot):
    """set of (x, y) on the 64x32 skin a slot may paint."""
    s = set()
    for x0, y0, x1, y1 in cat["slots"][slot]["inner_regions"]:
        for y in range(y0, y1):
            for x in range(x0, x1):
                s.add((x, y))
    return s


# ---------- tier selection (spec §7: <art>/tiers.json, written by the painter) ----------
TIER_IDS = ["T1", "T2", "T3", "T4", "T5", "T6"]


def load_tiers(cat, pals, art):
    """-> (tiers {line: {tier: {palette, on, variant, inner, icon}}}, notes, errors).

    Reads <art>/tiers.json; a missing file, line or tier falls back to the example
    selection in data/catalog.json (tiers_example.json) and says so in `notes`."""
    example = cat["tiers"]
    path = Path(art) / "tiers.json"
    notes, errors = [], []
    if not path.exists():
        notes.append(f"no {path}: using the EXAMPLE selection from data/catalog.json (tiers_example.json) for every tier")
        return {ln: {t: dict(v) for t, v in example[ln].items()} for ln in LINES}, notes, errors
    try:
        raw = json.loads(path.read_text())
    except Exception as e:  # noqa: BLE001
        errors.append(f"tiers.json: cannot read ({e}); using the example selection")
        return {ln: {t: dict(v) for t, v in example[ln].items()} for ln in LINES}, notes, errors
    box_ids = {b["id"] for b in pieces(cat)}       # boxes and polygon parts
    out = {}
    for key in raw:
        if key not in LINES and not key.startswith("_"):
            errors.append(f"tiers.json: unknown line '{key}' (lines: {', '.join(LINES)})")
    for ln in LINES:
        out[ln] = {}
        given = raw.get(ln)
        if not isinstance(given, dict):
            notes.append(f"tiers.json has no '{ln}': using the EXAMPLE selection for {ln}")
            out[ln] = {t: dict(v) for t, v in example[ln].items()}
            continue
        for key in given:
            if key not in TIER_IDS and not key.startswith("_"):
                errors.append(f"tiers.json: {ln}: unknown tier '{key}' (tiers: {', '.join(TIER_IDS)})")
        for tid in TIER_IDS:
            T = given.get(tid)
            ex = example[ln][tid]
            if not isinstance(T, dict):
                notes.append(f"tiers.json has no {ln} {tid}: using the EXAMPLE selection for it")
                out[ln][tid] = dict(ex)
                continue
            where = f"tiers.json: {ln} {tid}"
            on = T.get("on")
            if not isinstance(on, list):
                errors.append(f"{where}: 'on' must be a list of box ids")
                on = []
            for bid in on:
                if bid not in box_ids:
                    errors.append(f"{where}: unknown box '{bid}' in 'on' (boxes: {', '.join(sorted(box_ids))})")
            on = [b["id"] for b in pieces(cat) if b["id"] in on]           # catalog order, known ids only
            for part in cat.get("parts", []):
                if part["id"] in on and part["shell"] not in on:
                    errors.append(f"{where}: names '{part['id']}' without '{part['shell']}' (the {part['id']} has no "
                                  f"faces inside the {part['shell']} shell, so alone it would be hollow; spec §1a)")
            pal = T.get("palette")
            if pal is None:
                errors.append(f"{where}: no 'palette'")
                pal = ex["palette"]
            elif pal not in pals["palettes"]:
                errors.append(f"{where}: unknown palette '{pal}' (palettes.json: {', '.join(pals['palettes'])})")
                pal = ex["palette"]
            variant = T.get("variant") or {}
            for bid in variant:
                if bid not in box_ids:
                    errors.append(f"{where}: 'variant' names unknown box '{bid}'")
            inner = T.get("inner") or {}         # a tier entry without 'inner' has none (no example fallback)
            for slot in inner:
                if slot not in INNER_SLOTS:
                    errors.append(f"{where}: 'inner' slot '{slot}' unknown (inner slots: {', '.join(INNER_SLOTS)})")
            icon = T.get("icon") or {}         # a tier entry without 'icon' has none (no example fallback)
            for slot in icon:
                if slot not in SLOTS:
                    errors.append(f"{where}: 'icon' slot '{slot}' unknown (slots: {', '.join(SLOTS)})")
            out[ln][tid] = {"palette": pal, "on": on, "variant": {k: v for k, v in variant.items() if k in box_ids},
                            "inner": {k: v for k, v in inner.items() if k in INNER_SLOTS},
                            "icon": {k: v for k, v in icon.items() if k in SLOTS}}
    notes.insert(0, f"tier selection from {path}")
    return out, notes, errors
