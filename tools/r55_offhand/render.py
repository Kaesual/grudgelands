#!/usr/bin/env python3
"""Render offhand art on the game's player model (Round 55 lane VIEWER).

The painter's look tool: pure Python 3 + Pillow + numpy (no browser, no
engine, no network). It reads the model the game ships
(mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d) with the model
generator's own parser and rig (tools/r33_c3/gen_cloak_model.py), so every
pose clip and frame is the game's, and rasterises it with Round 54's software
renderer (tools/r54_armor/softrender.py: same camera, lights, nearest texels,
alpha test, 2x supersampling).

  python3 render.py --art DIR --out DIR [--item shield|book|cloak|all]
                    [--tiers T1,T3] [--race human,orc] [--detail]
                    [--armor metal:T3] [--cloak ID] [--back PNG]

Textures, in the model's slot order (skin, cloak, armor, weapon, offhand,
back, wings): the race's default look (Round 54's skins), no armor unless
--armor LINE:TIER (the shipped armor layers of that tier, the helmet drops the
hair), no weapon card (the game shows the held weapon on a separate entity),
the tier's offhand layer built with bake.py's own functions (palette applied
as the bake applies it), the back card only with --back (on the cloak card
when a cloak is worn, else on the body card) and a cloak with its wings
from <art>/cloak_<id>.png and <art>/wings_<id>.png.

Output (all PNG, in --out):
  shield_<race>.png, book_<race>.png   contact sheet: rows = tiers T1-T6,
      columns = front, back, the shield side (the character's left), front
      3/4 left, back 3/4 left in Stand, then the item's pose (Block for the
      shield, Cast 1 for the book) from the front and front 3/4 left; right
      of the views the tier's icon at 32 and 16 px (16 px again on a dark
      slot)
  <item>_<tier>_<race>.png (--detail)  one tier large: the item alone in its
      own frame (front and back flat lit, so every texel shows its exact
      colour; two lit 3/4 views), then eight views on the character close
      up, and the icon at 64/32/16 px
  cloak_<race>.png                     one row per cloak_<id>/wings_<id> of
      the art directory: back, the left side and back 3/4 left in Stand and
      mid-walk, and the back with a weapon on the cloak card

Missing or unreadable art renders as a magenta/black checker and is listed in
the row label (and printed). The sheet header says whether bake.py accepts the
art directory (its problems are printed): the render shows what it can even
when the bake would fail. Deterministic: no clock, no randomness.
"""
import argparse
import importlib.util
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
TOOL = Path(__file__).resolve().parent
ROOT = TOOL.parents[1]
sys.path.insert(0, str(TOOL))
sys.path.append(str(ROOT / "tools/r33_c3"))
sys.path.append(str(ROOT / "tools/r54_armor"))

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

import offhand as O  # noqa: E402  (the contract)
import bake as B  # noqa: E402  (tools/r55_offhand/bake.py: read_grid, layer_image, load_tiers, ...)
import gen_cloak_model as G  # noqa: E402  (the b3d parser and rig)
import armorlib as L  # noqa: E402
import softrender as SR  # noqa: E402  (Round 54's rasteriser)
import skins  # noqa: E402  (Round 54: STATURE)
from make_test_art import CLOTH_PALETTES, METAL_PALETTES  # noqa: E402

MODEL = G.TARGET
SLOTS = ("skin", "cloak", "armor", "weapon", "offhand", "back", "wings")
FLIP = np.array([-1.0, 1.0, 1.0])       # model (left-handed) <-> catalog frame (x = the character's left)
BG = (201, 205, 211)
DARK = (48, 46, 52)
MAGENTA = (200, 0, 160)
CHECK = ((255, 0, 255, 255), (40, 0, 40, 255))   # armorlib.checker's colours
PLAIN_CLOAK = ROOT / "mods/PLAYER/grug_achievements/textures/grug_achievements_cloak_plain_grey.png"
DEFAULT_BACK = ROOT / "mods/ITEMS/grug_gear/textures/grug_gear_bow_wood.png"
ARMOR_TEX = ROOT / "mods/PLAYER/grug_visuals/textures"
CLOAK_SIZE = (32, 32)

# camera directions (from the target), catalog frame: x = the character's left, z = the face
VIEWS = {
    "front": ((0, 0.1, 1), "front"),
    "back": ((0, 0.1, -1), "back"),
    "left": ((1, 0.1, 0), "left side (shield side)"),
    "right": ((-1, 0.1, 0), "right side"),
    "front3q_l": ((42, 13, 80), "front 3/4 left"),
    "back3q_l": ((42, 13, -80), "back 3/4 left"),
}
POSE = {"shield": ("block", "Block"), "book": ("cast1", "Cast 1")}
FULL = {"target": (0.0, 17.5, 0.0), "dist": 82.0}       # Round 54's full-body camera


def font(size):
    return ImageFont.load_default(size=size)


# --- the model --------------------------------------------------------------------
class Model:
    """The shipped player model: rest vertices, UVs, one triangle list per
    texture slot, bone weights, and skinned positions per engine frame, all
    in the catalog frame (skin pixels)."""

    def __init__(self, path=MODEL):
        data = Path(path).read_bytes()
        root = G.parse(data, 0, len(data))
        self.rig = G.Rig(root)
        mesh = G.kid(G.find_node(root, "Player"), "MESH")
        vrts = G.kid(mesh, "VRTS")
        n = (len(vrts.raw) - 12) // 32
        raw = np.frombuffer(vrts.raw, "<f4", n * 8, 12).reshape(n, 8).astype(float)
        self.rest_model, self.uv = raw[:, :3], raw[:, 6:8]
        self.rest = self.rest_model * FLIP / G.PX
        self.tris = [np.frombuffer(c.raw, "<i4", offset=4).reshape(-1, 3).astype(int)
                     for c in mesh.kids if c.tag == "TRIS"]
        if len(self.tris) != len(SLOTS):
            raise SystemExit("render: %s has %d mesh buffers, expected %d (%s)"
                             % (path, len(self.tris), len(SLOTS), ", ".join(SLOTS)))
        self.weights = {}
        for name, chunk in self.rig.chunk.items():
            for k in chunk.kids:
                if k.tag == "BONE":
                    w = np.frombuffer(k.raw, dtype=[("v", "<i4"), ("w", "<f4")])
                    w = w[w["w"] > 0]
                    if len(w):
                        self.weights[name] = (w["v"].astype(int), w["w"].astype(float))
        layout, _ = G.pose_layout()
        self.clips = dict(G.BASE_RANGES)
        self.clips.update({c["name"]: (c["first"], c["last"]) for c in layout})
        self.cache = {}

    def bone_matrix(self, bone, frame):
        """4 x 4: a model-space rest point to model space at an engine frame."""
        return np.array(self.rig.skin(bone, frame + 1)).reshape(4, 4).T

    def positions(self, frame):
        if frame not in self.cache:
            out = np.zeros_like(self.rest_model)
            for bone, (ids, ws) in self.weights.items():
                m = self.bone_matrix(bone, frame)
                out[ids] += ws[:, None] * (self.rest_model[ids] @ m[:3, :3].T + m[:3, 3])
            self.cache[frame] = out * FLIP / G.PX
        return self.cache[frame]

    def carry(self, bone, frame, p):
        """A catalog rest point riding `bone` at an engine frame (catalog frame)."""
        m = self.bone_matrix(bone, frame)
        q = np.asarray(p, float) * FLIP * G.PX
        return (m[:3, :3] @ q + m[:3, 3]) * FLIP / G.PX

    def frame(self, pose):
        """The engine frame shown for a pose: Stand its first frame, Walk the
        frame of the widest leg swing, any other clip its middle frame."""
        if pose == "stand":
            return self.clips["stand"][0]
        a, b = self.clips[pose]
        if pose == "walk":
            legs = self.rig.keys["Leg_Right"]
            return max(range(a, b + 1), key=lambda f: (abs(G.leg_swing(legs, f)), -f))
        return a + (b - a) // 2

    def sheet_tris(self, slot, rects, size):
        """Indices (into the slot's triangle list) whose UV centre lies in one of
        the texel rectangles [x, y, w, h] of a texture of `size`."""
        t = self.tris[SLOTS.index(slot)]
        c = self.uv[t].mean(axis=1) * np.array(size, float)
        hit = np.zeros(len(t), bool)
        for x, y, w, h in rects:
            hit |= (c[:, 0] >= x) & (c[:, 0] < x + w) & (c[:, 1] >= y) & (c[:, 1] < y + h)
        return np.nonzero(hit)[0]


# --- rendering ----------------------------------------------------------------------
def tex_array(img):
    """(RGBA array, summed-area table of the alpha-test mask)."""
    a = np.asarray(img.convert("RGBA"))
    sat = np.zeros((a.shape[0] + 1, a.shape[1] + 1), np.int64)
    sat[1:, 1:] = (a[..., 3] >= 128).cumsum(0).cumsum(1)
    return a, sat


def triangles(model, frame, textures, select=None, positions=None, stature=1.0):
    """[(3 x 3 points, 3 x 2 texel uv, texture array)] of every slot with a
    texture, skipping triangles whose UV box holds no opaque texel. `select`
    = {slot: triangle indices} limits a slot; `positions` replaces the
    skinned vertex positions (e.g. an item in its own frame)."""
    P = (model.positions(frame) if positions is None else positions) * stature
    out = []
    for i, slot in enumerate(SLOTS):
        img = textures.get(slot)
        if img is None or (select is not None and slot not in select):
            continue
        tex, sat = tex_array(img)
        th, tw = tex.shape[:2]
        tris = model.tris[i] if select is None else model.tris[i][select[slot]]
        for tri in tris:
            uv = model.uv[tri] * (tw, th)
            x0, y0 = np.clip(np.floor(uv.min(0)).astype(int), 0, (tw - 1, th - 1))
            x1, y1 = np.clip(np.floor(uv.max(0)).astype(int), 0, (tw - 1, th - 1)) + 1
            if sat[y1, x1] - sat[y0, x1] - sat[y1, x0] + sat[y0, x0] == 0:
                continue
            out.append((P[tri], uv, tex))
    return out


def render_view(tris, dirv, w, h, target, dist, fov=30.0, flat=False, bg=BG, raw=False):
    """One view (w x h) of a triangle list: back faces culled, flat-shaded
    with Round 54's lights (or unlit with `flat`: every texel its own colour).
    `raw`: the supersampled RGB array instead, not filtered down."""
    W, H = w * SR.SS, h * SR.SS
    cam = SR.camera(dirv, dist, W, H, target, fov)
    color = np.empty((H, W, 3), float)
    color[:] = bg
    zbuf = np.full((H, W), np.inf)
    for pts, uv, tex in tris:
        # the model's winding is clockwise seen from outside in this frame
        n = -np.cross(pts[1] - pts[0], pts[2] - pts[0])
        ln = np.linalg.norm(n)
        if ln < 1e-12:
            continue
        n /= ln
        if n @ (cam["pos"] - pts.mean(axis=0)) <= 0:
            continue
        proj = [SR.project(cam, p) for p in pts]
        if min(p[2] for p in proj) < 1.0:
            continue
        S = np.array([[p[0], p[1]] for p in proj])
        Z = np.array([p[2] for p in proj])
        light = np.ones(3) if flat else SR.shade(cam, n)
        SR.raster_tri(color, zbuf, S, Z, uv, (0, 0, tex.shape[1], tex.shape[0]), tex, light)
    rgb = np.clip(color + 0.5, 0, 255).astype(np.uint8)
    if raw:
        return rgb
    img = Image.fromarray(rgb, "RGB")
    return img.reduce(SR.SS) if SR.SS > 1 else img


def screen_point(p, dirv, w, h, target, dist, fov=30.0):
    """Where a catalog point lands in a view rendered by render_view (pixels)."""
    cam = SR.camera(dirv, dist, w * SR.SS, h * SR.SS, target, fov)
    x, y, _ = SR.project(cam, np.asarray(p, float))
    return x / SR.SS, y / SR.SS


# --- textures -----------------------------------------------------------------------
def checker_cells(img, cells):
    px = img.load()
    for x, y in cells:
        px[x, y] = CHECK[(x + y) % 2]


def load_png(path, size):
    """(RGBA image, problem or None): a missing or wrong-sized file is a checker."""
    path = Path(path)
    if not path.exists():
        return L.checker(size, cell=max(1, size[0] // 8)), "missing"
    try:
        im = Image.open(path).convert("RGBA")
    except Exception as e:  # noqa: BLE001
        return L.checker(size, cell=max(1, size[0] // 8)), "unreadable (%s)" % e
    if im.size != tuple(size):
        return L.checker(size, cell=max(1, size[0] // 8)), "size %dx%d, expected %dx%d" % (im.size + tuple(size))
    return im, None


class Art:
    """An art directory with its contract: params, atlas, grades, palettes,
    the tier selection and bake.py's verdict."""

    def __init__(self, art):
        self.art = Path(art)
        if not self.art.is_dir():
            raise SystemExit("render: no art directory %s" % art)
        try:
            self.params, self.atlas, self.grades = B.load_contract()
        except B.BakeError as e:
            raise SystemExit("render: %s" % e)
        self.sheets = self.atlas["sheets"]
        self.size = tuple(self.atlas["size"])
        self.pals, pnotes, perrors = L.load_palettes(self.art)
        self.notes = pnotes + perrors
        if (self.art / "tiers.json").exists():
            errors = []
            try:
                self.tiers = B.load_tiers(self.art, self.pals, errors, False)
            except B.BakeError as e:
                raise SystemExit("render: %s" % e)
            self.notes += errors
            self.tier_source = "art/tiers.json"
        else:
            self.tiers = {item: {tid: {"palette": pals[n], "variant": {s: "a" for s in sheets}, "icon": "a"}
                                 for n, tid in enumerate(L.TIER_IDS)}
                          for item, pals, sheets in (("shield", METAL_PALETTES, ("shield",)),
                                                     ("book", CLOTH_PALETTES, O.BOOK_BOXES))}
            self.tier_source = "DEFAULT selection (no art/tiers.json: variant a, the test art's palettes)"
        for item, sheets in (("shield", ("shield",)), ("book", O.BOOK_BOXES)):
            for tid in L.TIER_IDS:          # a tier tiers.json leaves out: a checker, listed
                self.tiers.setdefault(item, {}).setdefault(tid, {
                    "palette": None, "variant": {s: "a" for s in sheets}, "icon": None, "absent": True})
        warnings = []
        try:
            B.bake(self.art, icons=True, warnings=warnings)
            self.bake_problems = []
        except B.BakeError as e:
            self.bake_problems = str(e).splitlines()
        self.bake_warnings = warnings

    def rel(self, path):
        try:
            return str(Path(path).relative_to(self.art))
        except ValueError:
            return str(path)

    def colors(self, palette):
        if palette in self.pals["palettes"]:
            return self.pals["palettes"][palette]["colors"]
        return {name: hx for _, name, hx, _ in L.REFERENCE}     # unknown palette: the reference colours

    def layer(self, item, tid):
        """(offhand atlas layer, icon, [missing or broken files]) of a tier,
        built as bake.py builds it; a missing file, a wrong size and
        off-palette or partial-alpha texels show the checker."""
        tier = self.tiers[item][tid]
        n = L.TIER_IDS.index(tid) + 1
        if tier.get("absent"):
            ids = ["shield_%d" % O.tier_step(self.params, n)] if item == "shield" else O.BOOK_BOXES
            img = Image.new("RGBA", self.size, (0, 0, 0, 0))
            checker_cells(img, {(x, y) for s in ids for fx, fy, fw, fh in self.sheets[s]["faces"].values()
                                for y in range(fy, fy + fh) for x in range(fx, fx + fw)})
            return img, L.checker(O.ICON_SIZE, cell=4), ["no tiers.json entry"]
        colors = self.colors(tier["palette"])
        missing = [] if tier["palette"] in self.pals["palettes"] else ["palette %s unknown" % tier["palette"]]
        if item == "shield":
            pieces = [("shield_%d" % O.tier_step(self.params, n), "shield_0",
                       B.shield_file(self.art, tier["variant"]["shield"]))]
        else:
            pieces = [(box, box, B.book_file(self.art, box, tier["variant"][box])) for box in O.BOOK_BOXES]
        grid, bad = {}, set()
        for sheet_id, read_id, path in pieces:
            errors = []
            cells, off, ok = B.read_grid(path, self.sheets[read_id]["rect"][2:], errors)
            if not ok:
                missing.append(self.rel(path) + ("" if path.exists() else " (missing)"))
            elif off:
                missing.append("%s (%d off-palette texels)" % (self.rel(path), len(off)))
            ox, oy = self.sheets[sheet_id]["rect"][:2]
            for fx, fy, fw, fh in B.local_faces(self.sheets[read_id]).values():
                for y in range(fy, fy + fh):
                    for x in range(fx, fx + fw):
                        if not ok or (x, y) in off:
                            bad.add((ox + x, oy + y))
                        elif (x, y) in cells:
                            grid[(ox + x, oy + y)] = cells[(x, y)]
        img = B.layer_image(grid, self.size, colors)
        checker_cells(img, bad)
        icon = L.checker(O.ICON_SIZE, cell=4)
        if tier["icon"] is None:
            missing.append("no icon named")
        else:
            path = B.icon_art(self.art, item, tier["icon"])
            errors = []
            cells, off, ok = B.read_grid(path, O.ICON_SIZE, errors)
            if ok:            # an icon_palette (format doc section 6) colours the icon only
                icon = B.layer_image(cells, O.ICON_SIZE, self.colors(tier.get("icon_palette") or tier["palette"]))
                checker_cells(icon, off)
                if off:
                    missing.append("%s (%d off-palette texels)" % (self.rel(path), len(off)))
            else:
                missing.append(self.rel(path) + ("" if path.exists() else " (missing)"))
        return img, icon, missing

    def label(self, item, tid):
        tier = self.tiers[item][tid]
        variants = sorted(set(tier["variant"].values()))
        v = variants[0] if len(variants) == 1 else ", ".join("%s %s" % kv for kv in sorted(tier["variant"].items()))
        lines = (["(no tiers.json entry)"] if tier.get("absent") else
                 ["palette %s" % tier["palette"], "variant %s, icon %s%s" % (
                     v, tier["icon"], " (%s)" % tier["icon_palette"] if tier.get("icon_palette") else "")])
        if item == "shield":
            n = L.TIER_IDS.index(tid) + 1
            step = O.tier_step(self.params, n)
            lines.append("size step %d (x%g)" % (step, self.params["shield"]["sizes"][step]))
        return lines

    def cloak_ids(self):
        ids = {p.stem.split("_", 1)[1] for pat in ("cloak_*.png", "wings_*.png") for p in self.art.glob(pat)}
        return sorted(ids)

    def cloak(self, cid):
        """(cloak image, wings image or None, [notes]) of a cloak id; a wing
        texture without its cloak is shown on the game's plain grey cloak."""
        notes = []
        path = self.art / ("cloak_%s.png" % cid)
        if path.exists():
            cloak, problem = load_png(path, CLOAK_SIZE)
            if problem:
                notes.append("cloak_%s.png %s" % (cid, problem))
        else:
            cloak = Image.open(PLAIN_CLOAK).convert("RGBA")
            notes.append("no cloak_%s.png: the plain grey cloak" % cid)
        wings = None
        path = self.art / ("wings_%s.png" % cid)
        if path.exists():
            wings, problem = load_png(path, O.WINGS_SIZE)
            if problem:
                notes.append("wings_%s.png %s" % (cid, problem))
        return cloak, wings, notes


def back_texture(img, on_cloak):
    """The 32 x 16 back texture (format doc §5): the image, turned 180 degrees
    as the game turns it (grip up), in the left half (the cloak card) when a
    cloak is worn, else in the right half (the body card)."""
    out = Image.new("RGBA", O.BACK_SIZE, (0, 0, 0, 0))
    im = img.convert("RGBA")
    if im.size != (16, 16):
        im = im.resize((16, 16), Image.Resampling.NEAREST)
    out.paste(im.rotate(180), (0 if on_cloak else 16, 0))
    return out


def r54_grades():
    spec = importlib.util.spec_from_file_location("r54_bake", ROOT / "tools/r54_armor/bake.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.grades()


def armor_textures(spec, race):
    """(skin, armor atlas) of a worn armor set "LINE:TIER" from the shipped
    layers (grug_visuals/textures, Round 54's bake of the picked art)."""
    line, _, tid = spec.partition(":")
    if line not in L.LINES or tid not in L.TIER_IDS:
        raise SystemExit("render: --armor %s, expected LINE:TIER with LINE in %s and TIER T1..T6"
                         % (spec, ", ".join(L.LINES)))
    grade = r54_grades()[line][L.TIER_IDS.index(tid)]
    atlas = None
    skin_layers = []
    for slot in L.SLOTS:
        stem = ARMOR_TEX / ("grug_armor_%s_%s_%s" % (line, grade, slot))
        im = Image.open(str(stem) + ".png").convert("RGBA")
        atlas = im if atlas is None else Image.alpha_composite(atlas, im)
        if slot == "head":
            helmet = im.getchannel("A").getbbox() is not None
        else:
            skin_layers.append(Image.open(str(stem) + "_skin.png").convert("RGBA"))
    skin = skin_image(race, helmet)
    for layer in skin_layers:
        skin.alpha_composite(layer)
    return skin, atlas


def skin_image(race, bald=False):
    return L.load_rgba(L.DATA / "skins" / ("%s_%s.png" % (race, "bald" if bald else "hair")))


# --- sheets -----------------------------------------------------------------------------
def icon_block(icon, w=110):
    """The icon at 32 px and at 16 px on the background and on a dark slot."""
    im = Image.new("RGB", (w, 40), BG)
    big = icon.resize((32, 32), Image.Resampling.NEAREST)
    im.paste(big, (0, 0), big)
    im.paste(icon, (40, 0), icon)
    dark = Image.new("RGB", (16, 16), DARK)
    dark.paste(icon, (0, 0), icon)
    im.paste(dark, (40, 18))
    return im


def wrap(text, n):
    out, cur = [], ""
    for word in text.split(" "):
        if cur and len(cur) + 1 + len(word) > n:
            out.append(cur)
            cur = word
        else:
            cur = (cur + " " + word) if cur else word
    return out + ([cur] if cur else [])


def bake_line(art):
    if art.bake_problems:
        return "bake.py: %d PROBLEM(S), see the console" % len(art.bake_problems)
    return "bake.py: accepts this art"


def report(art):
    for n in art.notes:
        print("note:", n)
    for p in art.bake_problems:
        print("BAKE PROBLEM:", p)
    for w in art.bake_warnings:
        print("bake warning:", w)


class Look:
    """The fixed textures of a render: race, skin, armor, cloak, back card."""

    def __init__(self, art, race, armor=None, cloak=None, back=None):
        self.race, self.stature = race, skins.STATURE[race]
        self.armor_spec, self.cloak_spec = armor, cloak
        self.notes = []
        if armor:
            self.skin, self.armor = armor_textures(armor, race)
        else:
            self.skin, self.armor = skin_image(race), None
        self.cloak = self.wings = None
        if cloak:
            if Path(cloak).is_file():
                self.cloak, problem = load_png(cloak, CLOAK_SIZE)
                self.notes += [problem] if problem else []
            else:
                self.cloak, self.wings, notes = art.cloak(cloak)
                self.notes += notes
        self.back = None
        if back:
            img, problem = load_png(back, (16, 16))
            self.notes += ["--back %s" % problem] if problem else []
            self.back = back_texture(img, self.cloak is not None)

    def textures(self, offhand=None):
        return {"skin": self.skin, "cloak": self.cloak, "armor": self.armor, "offhand": offhand,
                "back": self.back, "wings": self.wings}

    def describe(self):
        parts = ["race %s" % self.race]
        parts.append("armor %s" % (self.armor_spec or "none"))
        if self.cloak is not None:
            parts.append("cloak %s" % self.cloak_spec)
        if self.back is not None:
            parts.append("back card")
        return ", ".join(parts)


def item_columns(item):
    pose, name = POSE[item]
    return [(v, "stand", VIEWS[v][1]) for v in ("front", "back", "left", "front3q_l", "back3q_l")] + \
        [(v, pose, "%s, %s" % (name, VIEWS[v][1])) for v in ("front", "front3q_l")]


def contact_sheet(model, art, look, item, tids, out):
    cw, ch = 220, 300
    cols = item_columns(item)
    lab_w, head_h, col_h, ic_w = 170, 34, 20, 130
    W, H = cw * len(cols), ch * len(tids)
    sheet = Image.new("RGB", (lab_w + W + ic_w, head_h + col_h + H), (236, 234, 229))
    d = ImageDraw.Draw(sheet)
    frames = {pose: model.frame(pose) for _, pose, _ in cols}
    d.text((8, 8), "%s - %s - art %s - tiers: %s - %s - frames %s" % (
        item, look.describe(), art.art.resolve(), art.tier_source, bake_line(art),
        ", ".join("%s %d" % kv for kv in frames.items())), fill=(20, 20, 20), font=font(14))
    for c, (_, _, label) in enumerate(cols):
        d.text((lab_w + c * cw + 6, head_h + 3), label, fill=(60, 60, 60), font=font(12))
    d.text((lab_w + W + 8, head_h + 3), "icon 32 / 16 px", fill=(60, 60, 60), font=font(12))
    missing = {}
    for r, tid in enumerate(tids):
        layer, icon, miss = art.layer(item, tid)
        missing[tid] = miss
        textures = look.textures(layer)
        y0 = head_h + col_h + r * ch
        scenes = {}
        for c, (view, pose, _) in enumerate(cols):
            if pose not in scenes:
                scenes[pose] = triangles(model, frames[pose], textures, stature=look.stature)
            cell = render_view(scenes[pose], VIEWS[view][0], cw, ch, FULL["target"], FULL["dist"])
            sheet.paste(cell, (lab_w + c * cw, y0))
        d.line([(0, y0), (sheet.width, y0)], fill=(150, 150, 150))
        d.text((8, y0 + 6), tid, fill=(20, 20, 20), font=font(18))
        yy = y0 + 32
        d.text((8, yy), "grade %s" % art.grades[L.TIER_IDS.index(tid)], fill=(50, 50, 50), font=font(12))
        yy += 15
        for ln in art.label(item, tid):
            d.text((8, yy), ln, fill=(50, 50, 50), font=font(12))
            yy += 15
        if miss:
            yy += 4
            d.text((8, yy), "MISSING / BROKEN (%d):" % len(miss), fill=MAGENTA, font=font(12))
            yy += 15
            for ln in [w for m in miss for w in wrap(m, 24)][:10]:
                d.text((8, yy), ln, fill=MAGENTA, font=font(11))
                yy += 13
        sheet.paste(icon_block(icon), (lab_w + W + 10, y0 + 8))
    p = Path(out) / ("%s_%s.png" % (item, look.race))
    sheet.save(p)
    return p, missing


def item_positions(model, art, item, tid):
    """(triangle selection, rest positions in the item's own frame): the
    shield copy of the tier's size step or the book, from the shipped model."""
    if item == "shield":
        step = O.tier_step(art.params, L.TIER_IDS.index(tid) + 1)
        ids, scale = ["shield_%d" % step], art.params["shield"]["sizes"][step]
    else:
        ids, scale = list(O.BOOK_BOXES), 1.0
    rects = [art.sheets[s]["rect"] for s in ids]
    sel = model.sheet_tris("offhand", rects, art.size)
    place = art.params[item]["place"]
    R = np.array(O.euler(place["rot"], place["order"]))
    local = (model.rest - np.array(place["pos"], float)) @ R / scale     # R^T (p - pos) / scale, per row
    return {"offhand": sel}, local


def item_centre(model, sel, frame, stature=1.0):
    pts = model.positions(frame)[model.tris[SLOTS.index("offhand")][sel["offhand"]].ravel()] * stature
    return (pts.min(axis=0) + pts.max(axis=0)) / 2


# 26 directions round the item (the poles nudged off the vertical, which the camera's up needs)
ROUND = [(i, j, k) if (i, k) != (0, 0) else (0.15, j, 0.1)
         for i in (-1, 0, 1) for j in (-1, 0, 1) for k in (-1, 0, 1) if (i, j, k) != (0, 0, 0)]


def seen_texels(model, sel, frames, size, w=300, dist=30.0):
    """{(x, y)} of the offhand atlas texels that show in at least one view:
    the selected offhand triangles (e.g. item_positions' selection) on the
    human body (opaque, no armor or cloak), from the 26 ROUND directions at
    each engine frame, close up. A texel never seen is hidden by the item
    itself, the hand or the body in these poses (the templates hatch it)."""
    W, H = size
    ids = np.zeros((H, W, 4), np.uint8)
    ids[..., 0], ids[..., 1] = np.meshgrid(np.arange(W), np.arange(H))
    ids[..., 2], ids[..., 3] = 7, 255
    body = np.asarray(skin_image("human")).copy()
    body[..., :3] = (0, 0, 255)
    textures = {"skin": Image.fromarray(body, "RGBA"), "offhand": Image.fromarray(ids, "RGBA")}
    select = {"skin": np.arange(len(model.tris[0])), "offhand": sel["offhand"]}
    seen = set()
    for f in frames:
        tris = triangles(model, f, textures, select=select)
        target = item_centre(model, sel, f)
        for d in ROUND:
            rgb = render_view(tris, d, w, w, target, dist, flat=True, bg=(0, 0, 255), raw=True)
            hit = rgb[..., 2] == 7
            seen.update(zip(rgb[hit, 0].tolist(), rgb[hit, 1].tolist()))
    return seen


# the item alone: (label, direction in the item's frame, flat)
ALONE = {
    "shield": [("front (flat, as painted)", (0, 0, 1), True), ("back (flat, seen from behind)", (0, 0, -1), True),
               ("front 3/4, lit", (0.55, 0.3, 1), False), ("back 3/4, lit", (-0.55, 0.3, -1), False)],
    "book": [("reader's view (flat)", (1, 0, 0), True), ("covers and spine (flat)", (-1, 0, 0), True),
             ("reader's view 3/4, lit", (1, 0.6, 0.7), False), ("spine side 3/4, lit", (-1, 0.5, 0.7), False)],
}


def near_ortho(local_pts, dirv):
    """(target, dist, fov) of a practically orthographic camera framing points."""
    lo, hi = local_pts.min(axis=0), local_pts.max(axis=0)
    extent = float(np.linalg.norm(hi - lo))
    dist = 2000.0
    return (lo + hi) / 2, dist, math.degrees(2 * math.atan(extent * 0.56 / dist))


def detail_sheet(model, art, look, item, tid, out):
    aw, ah = 420, 420
    cw, ch = 420, 440
    pose, pname = POSE[item]
    views = [(v, "stand", VIEWS[v][1]) for v in ("front", "back", "left", "front3q_l", "back3q_l")] + \
        [("front", pose, "%s, front" % pname), ("front3q_l", pose, "%s, front 3/4 left" % pname),
         ("front3q_l", "walk", "mid-walk, front 3/4 left")]
    ncol = 4
    W = max(aw * len(ALONE[item]), cw * ncol)
    head_h, lab_h, foot_h = 40, 22, 110
    rows = math.ceil(len(views) / ncol)
    sheet = Image.new("RGB", (W, head_h + lab_h + ah + rows * (lab_h + ch) + foot_h), (236, 234, 229))
    d = ImageDraw.Draw(sheet)
    layer, icon, missing = art.layer(item, tid)
    d.text((8, 8), "%s %s (%s) - %s - %s - %s" % (item, tid, art.grades[L.TIER_IDS.index(tid)],
                                                 " / ".join(art.label(item, tid)), look.describe(), bake_line(art)),
           fill=(20, 20, 20), font=font(14))
    textures = look.textures(layer)
    sel, local = item_positions(model, art, item, tid)
    alone = triangles(model, 0, {"offhand": layer}, select=sel, positions=local)
    pts = local[model.tris[SLOTS.index("offhand")][sel["offhand"]].ravel()]
    y = head_h
    for i, (label, dirv, flat) in enumerate(ALONE[item]):
        d.text((i * aw + 6, y + 4), "alone: " + label, fill=(40, 40, 40), font=font(13))
        target, dist, fov = near_ortho(pts, dirv)
        sheet.paste(render_view(alone, dirv, aw, ah, target, dist, fov, flat=flat), (i * aw, y + lab_h))
    y += lab_h + ah
    frames = {}
    for i, (view, p, label) in enumerate(views):
        frames.setdefault(p, model.frame(p))
        tris = triangles(model, frames[p], textures, stature=look.stature)
        x0, y0 = (i % ncol) * cw, y + (i // ncol) * (lab_h + ch)
        d.text((x0 + 6, y0 + 4), "%s (frame %d)" % (label, frames[p]), fill=(40, 40, 40), font=font(13))
        target = item_centre(model, sel, frames[p], look.stature)
        sheet.paste(render_view(tris, VIEWS[view][0], cw, ch, target, 36.0), (x0, y0 + lab_h))
    y += rows * (lab_h + ch) + 8
    x = 8
    for s in (64, 32, 16):
        big = icon.resize((s, s), Image.Resampling.NEAREST)
        bgim = Image.new("RGB", (s, s), BG)
        bgim.paste(big, (0, 0), big)
        sheet.paste(bgim, (x, y))
        x += s + 8
    dark = Image.new("RGB", (16, 16), DARK)
    dark.paste(icon, (0, 0), icon)
    sheet.paste(dark, (x, y))
    x += 40
    if missing:
        d.text((x, y), "MISSING / BROKEN: " + "; ".join(missing), fill=MAGENTA, font=font(13))
    p = Path(out) / ("%s_%s_%s.png" % (item, tid, look.race))
    sheet.save(p)
    return p, missing


def cloak_sheet(model, art, look, ids, out, back_img):
    cw, ch = 220, 300
    cols = [(v, p, "%s, %s" % (VIEWS[v][1].replace(" (shield side)", ""), "Stand" if p == "stand" else "mid-walk"))
            for p in ("stand", "walk") for v in ("back", "left", "back3q_l")]
    cols.append(("back3q_l", "stand", "back 3/4 left, cloak card"))
    frames = {p: model.frame(p) for p in ("stand", "walk")}
    lab_w, head_h, col_h = 170, 34, 20
    W, H = cw * len(cols), ch * len(ids)
    sheet = Image.new("RGB", (lab_w + W, head_h + col_h + H), (236, 234, 229))
    d = ImageDraw.Draw(sheet)
    d.text((8, 8), "cloaks - race %s - art %s - frames Stand %d, mid-walk %d - card: %s" % (
        look.race, art.art.resolve(), frames["stand"], frames["walk"], Path(back_img).name),
        fill=(20, 20, 20), font=font(14))
    for c, (_, _, label) in enumerate(cols):
        d.text((lab_w + c * cw + 6, head_h + 3), label, fill=(60, 60, 60), font=font(12))
    card, _ = load_png(back_img, (16, 16))
    notes_all = {}
    for r, cid in enumerate(ids):
        cloak, wings, notes = art.cloak(cid)
        notes_all[cid] = notes
        base = {"skin": look.skin, "armor": look.armor, "cloak": cloak, "wings": wings}
        y0 = head_h + col_h + r * ch
        for c, (view, pose, label) in enumerate(cols):
            tex = dict(base, back=back_texture(card, True)) if "card" in label else base
            tris = triangles(model, frames[pose], tex, stature=look.stature)
            sheet.paste(render_view(tris, VIEWS[view][0], cw, ch, FULL["target"], FULL["dist"]),
                        (lab_w + c * cw, y0))
        d.line([(0, y0), (sheet.width, y0)], fill=(150, 150, 150))
        d.text((8, y0 + 6), cid, fill=(20, 20, 20), font=font(18))
        yy = y0 + 32
        d.text((8, yy), "wings: %s" % ("yes" if wings is not None else "none"), fill=(50, 50, 50), font=font(12))
        yy += 19
        for n in notes:
            bad = "expected" in n or "unreadable" in n or "missing" in n
            for ln in wrap(n, 24):
                d.text((8, yy), ln, fill=MAGENTA if bad else (90, 90, 90), font=font(11))
                yy += 13
    p = Path(out) / ("cloak_%s.png" % look.race)
    sheet.save(p)
    return p, notes_all


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--art", required=True, help="art directory (offhand-format.md section 6)")
    ap.add_argument("--out", required=True, help="output directory")
    ap.add_argument("--item", default="all", choices=["shield", "book", "cloak", "all"])
    ap.add_argument("--tiers", default="", help="comma list, e.g. T1,T3 (default all six)")
    ap.add_argument("--race", default="human", help="comma list: %s" % ", ".join(skins.STATURE))
    ap.add_argument("--detail", action="store_true", help="one large sheet per tier instead of the contact sheet")
    ap.add_argument("--armor", help="wear the shipped armor of LINE:TIER, e.g. metal:T3 (default: none)")
    ap.add_argument("--cloak", help="wear a cloak on the item sheets: an id of the art directory "
                                    "(cloak_<id>.png, wings_<id>.png) or a 32x32 PNG")
    ap.add_argument("--back", help="a 16x16 item image on the back card of the item sheets (the cloak "
                                   "card with --cloak, else the body card); the cloak sheet's card column "
                                   "uses it too (default there: the wooden bow)")
    a = ap.parse_args()
    art = Art(a.art)
    report(art)
    tids = [t.strip() for t in a.tiers.split(",") if t.strip()] or list(L.TIER_IDS)
    for t in tids:
        if t not in L.TIER_IDS:
            sys.exit("render: unknown tier %s (T1..T6)" % t)
    races = [r.strip() for r in a.race.split(",") if r.strip()]
    for r in races:
        if r not in skins.STATURE:
            sys.exit("render: unknown race %s; known: %s" % (r, ", ".join(skins.STATURE)))
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    model = Model()
    items = ["shield", "book", "cloak"] if a.item == "all" else [a.item]
    for race in races:
        look = Look(art, race, a.armor, a.cloak, a.back)
        for n in look.notes:
            print("note:", n)
        for item in items:
            if item == "cloak":
                ids = art.cloak_ids()
                if not ids:
                    print("no cloak_<id>.png or wings_<id>.png in %s: no cloak sheet" % art.art)
                    continue
                if a.detail:
                    continue
                p, notes = cloak_sheet(model, art, look, ids, out, a.back or DEFAULT_BACK)
                print(p, "(%d cloak(s))" % len(ids))
                for cid, ns in notes.items():
                    for n in ns:
                        print("  %s: %s" % (cid, n))
            elif a.detail:
                for tid in tids:
                    p, miss = detail_sheet(model, art, look, item, tid, out)
                    print(p, "(missing/broken: %d)" % len(miss))
            else:
                p, miss = contact_sheet(model, art, look, item, tids, out)
                print(p, "(missing/broken: %d)" % sum(len(v) for v in miss.values()))
                for tid, v in miss.items():
                    if v:
                        print("  %s: %s" % (tid, "; ".join(v)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
