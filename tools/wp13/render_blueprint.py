#!/usr/bin/env python3
"""Render a settlement blueprint with the real node textures.

Unlike tools/wp13/preview.py (symbolic colours, schematic overview) this draws
a dimetric 2:1 isometric picture using the actual 16px mod art, so a reviewer
can judge whether a building *looks* right.

    python3 tools/wp13/render_blueprint.py \
        mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua \
        -o /tmp/hearthpine.png

Input is either a blueprint .lua (dumped through tools/wp13/dump_blueprint.lua
with luajit / tools/bin/lua51) or a TSV with `x<TAB>y<TAB>z<TAB>name<TAB>param2`
per line. Node tiles come from tools/wp13/node_tiles.json, which
tools/wp13/extract_tiles.py generates by scanning the mod sources.

Only Python 3 + Pillow are required.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import time
from collections import Counter

try:
    from PIL import Image, ImageChops, ImageColor, ImageDraw
except ImportError:  # pragma: no cover
    sys.stderr.write("Pillow is required: pip install --user pillow\n")
    raise

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_TILES = os.path.join(HERE, "node_tiles.json")

# Visible faces for the camera that sits over the +x / +y / +z corner.
SHADE_TOP = 1.0
SHADE_X = 0.80
SHADE_Z = 0.62

VIEW_TURNS = {"ne": 0, "nw": 1, "sw": 2, "se": 3}

# Luanti tile order: +Y, -Y, +X, -X, +Z, -Z
FACE_TOP, FACE_BOTTOM, FACE_XP, FACE_XN, FACE_ZP, FACE_ZN = range(6)


# ---------------------------------------------------------------------------
# cell input
# ---------------------------------------------------------------------------

def load_cells(path, lua_bin=None):
    """Return a list of (x, y, z, name, param2)."""
    if path.endswith(".lua"):
        return load_cells_from_lua(path, lua_bin)
    with open(path, "r", encoding="utf-8") as fh:
        return parse_tsv(fh)


def _lua_interpreters(explicit):
    if explicit:
        return [explicit]
    cands = ["luajit", os.path.join(REPO, "tools", "bin", "lua51"),
             "lua5.1", "lua"]
    return [c for c in cands if os.sep not in c or os.path.exists(c)]


def load_cells_from_lua(path, lua_bin=None):
    dumper = os.path.join(HERE, "dump_blueprint.lua")
    if not os.path.exists(dumper):
        raise SystemExit("missing %s" % dumper)
    last = None
    for exe in _lua_interpreters(lua_bin):
        try:
            proc = subprocess.run([exe, dumper, path], capture_output=True,
                                  cwd=REPO)
        except (OSError, FileNotFoundError) as exc:
            last = str(exc)
            continue
        if proc.returncode != 0:
            raise SystemExit("dump_blueprint.lua failed:\n%s"
                             % proc.stderr.decode("utf-8", "replace"))
        return parse_tsv(proc.stdout.decode("utf-8", "replace").splitlines())
    raise SystemExit("no Lua 5.1 interpreter found (tried luajit, "
                     "tools/bin/lua51, lua5.1, lua): %s" % last)


def parse_tsv(lines):
    cells = []
    for line in lines:
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        try:
            x, y, z = int(parts[0]), int(parts[1]), int(parts[2])
        except ValueError:
            continue
        name = parts[3].strip()
        try:
            p2 = int(parts[4]) if len(parts) > 4 and parts[4] else 0
        except ValueError:
            p2 = 0
        cells.append((x, y, z, name, p2))
    return cells


# ---------------------------------------------------------------------------
# texture resolution
# ---------------------------------------------------------------------------

class TextureBank:
    def __init__(self, tiles_json, extra_roots=()):
        with open(tiles_json, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        self.nodes = data.get("nodes", {})
        self.index = dict(data.get("textures", {}))
        self.fallback_colors = data.get("fallback_colors", {})
        self.extra_roots = list(extra_roots)
        self._scanned = False
        self._cache = {}
        self.warnings = Counter()

    # -- file lookup ----------------------------------------------------
    def _rescan(self):
        if self._scanned:
            return
        self._scanned = True
        roots = [os.path.join(REPO, "mods")] + \
            [os.path.abspath(r) for r in self.extra_roots]
        for root in roots:
            if not os.path.isdir(root):
                continue
            for dirpath, dirnames, filenames in os.walk(root):
                dirnames[:] = [d for d in dirnames if d != ".git"]
                if os.path.basename(dirpath) != "textures":
                    continue
                for fn in filenames:
                    known = self.index.get(fn)
                    if known and os.path.exists(os.path.join(REPO, known)):
                        continue  # the mapped file is really there
                    self.index[fn] = os.path.relpath(
                        os.path.join(dirpath, fn), REPO)

    def find_file(self, basename):
        rel = self.index.get(basename)
        if rel:
            full = os.path.join(REPO, rel)
            if os.path.exists(full):
                return full
        self._rescan()
        rel = self.index.get(basename)
        if rel:
            full = os.path.join(REPO, rel)
            if os.path.exists(full):
                return full
        return None

    # -- modifier-aware texture spec ------------------------------------
    def texture(self, spec):
        """Resolve a Luanti texture spec to an RGBA image, or None."""
        if not spec:
            return None
        if spec in self._cache:
            return self._cache[spec]
        img = None
        try:
            img = self._build(spec)
        except Exception:
            img = None
        if img is None:
            base = spec.split("^")[0].strip().lstrip("(").rstrip(")")
            if base and base != spec and not base.startswith("["):
                img = self._load_file(base)
                if img is not None:
                    self.warnings["modifier-fallback: %s" % spec] += 1
        if img is None:
            self.warnings["texture-missing: %s" % spec] += 1
        self._cache[spec] = img
        return img

    def _load_file(self, basename):
        basename = basename.strip()
        if not basename:
            return None
        path = self.find_file(basename)
        if not path:
            return None
        try:
            return Image.open(path).convert("RGBA")
        except OSError:
            return None

    def _build(self, spec):
        parts = split_modifiers(spec.strip())
        if not parts:
            return None
        base = parts[0]
        if base.startswith("("):
            img = self._build(base[1:-1])
        elif base.startswith("["):
            return None  # [combine / [fill / ... : generated, unsupported
        else:
            img = self._load_file(base)
        if img is None:
            return None
        img = img.copy()
        for part in parts[1:]:
            if part.startswith("("):
                over = self._build(part[1:-1])
                img = overlay(img, over) if over is not None else img
            elif part.startswith("["):
                img = apply_modifier(img, part, self.warnings)
            else:
                over = self._load_file(part)
                if over is None:
                    self.warnings["overlay-missing: %s" % part] += 1
                else:
                    img = overlay(img, over)
            if img is None:
                return None
        return img


def split_modifiers(spec):
    """Split a texture spec on top-level '^', keeping (...) groups intact."""
    out, depth, cur = [], 0, []
    for ch in spec:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "^" and depth == 0:
            out.append("".join(cur).strip())
            cur = []
            continue
        cur.append(ch)
    out.append("".join(cur).strip())
    return [p for p in out if p]


def overlay(base, over):
    if over.size != base.size:
        over = over.resize(base.size, Image.NEAREST)
    out = base.copy()
    out.alpha_composite(over)
    return out


def parse_color(text):
    text = text.strip()
    try:
        rgba = ImageColor.getrgb(text)
    except ValueError:
        return None
    if len(rgba) == 3:
        return rgba + (255,)
    return rgba


def apply_modifier(img, mod, warnings):
    body = mod[1:]
    name = body.split(":", 1)[0]
    arg = body.split(":", 1)[1] if ":" in body else ""
    if name.startswith("transform"):
        return apply_transform(img, name[len("transform"):])
    if name == "colorize":
        bits = arg.split(":")
        color = parse_color(bits[0]) if bits else None
        if color is None:
            warnings["colorize-unparsed: %s" % mod] += 1
            return img
        ratio = 128
        if len(bits) > 1 and bits[1] and bits[1] != "alpha":
            try:
                ratio = int(bits[1])
            except ValueError:
                ratio = 128
        elif len(bits) > 1 and bits[1] == "alpha":
            ratio = color[3]
        f = max(0.0, min(1.0, ratio / 255.0))
        px = img.load()
        w, h = img.size
        for yy in range(h):
            for xx in range(w):
                r, g, b, a = px[xx, yy]
                px[xx, yy] = (int(r + (color[0] - r) * f),
                              int(g + (color[1] - g) * f),
                              int(b + (color[2] - b) * f), a)
        return img
    if name == "multiply":
        color = parse_color(arg)
        if color is None:
            return img
        px = img.load()
        w, h = img.size
        for yy in range(h):
            for xx in range(w):
                r, g, b, a = px[xx, yy]
                px[xx, yy] = (r * color[0] // 255, g * color[1] // 255,
                              b * color[2] // 255, a)
        return img
    if name == "opacity":
        try:
            val = int(arg)
        except ValueError:
            return img
        alpha = img.getchannel("A").point(lambda v: v * val // 255)
        img.putalpha(alpha)
        return img
    if name in ("noalpha", "makealpha", "mask", "brighten", "resize",
                "verticalframe", "sheet", "png"):
        if name == "brighten":
            return img.point(lambda v: min(255, int(v * 1.3)))
        if name == "verticalframe":
            bits = arg.split(":")
            if len(bits) == 2:
                try:
                    count, index = int(bits[0]), int(bits[1])
                    w, h = img.size
                    fh = h // max(1, count)
                    return img.crop((0, index * fh, w, (index + 1) * fh))
                except ValueError:
                    pass
        if name == "noalpha":
            out = Image.new("RGBA", img.size, (0, 0, 0, 255))
            out.paste(img.convert("RGB"), (0, 0))
            return out
        warnings["modifier-ignored: %s" % mod] += 1
        return img
    warnings["modifier-unknown: %s" % mod] += 1
    return img


def apply_transform(img, code):
    code = code.upper()
    i = 0
    while i < len(code):
        c = code[i]
        if c == "R":
            j = i + 1
            num = ""
            while j < len(code) and code[j].isdigit():
                num += code[j]
                j += 1
            deg = int(num) if num else 0
            if deg == 90:
                img = img.transpose(Image.ROTATE_270)
            elif deg == 180:
                img = img.transpose(Image.ROTATE_180)
            elif deg == 270:
                img = img.transpose(Image.ROTATE_90)
            i = j
            continue
        if c == "F":
            nxt = code[i + 1] if i + 1 < len(code) else ""
            if nxt == "X":
                img = img.transpose(Image.FLIP_LEFT_RIGHT)
                i += 2
                continue
            if nxt == "Y":
                img = img.transpose(Image.FLIP_TOP_BOTTOM)
                i += 2
                continue
        i += 1
    return img


def flat_color_for(name):
    """Deterministic pastel-ish colour for names with no usable texture."""
    h = 0
    for ch in name:
        h = (h * 131 + ord(ch)) & 0xFFFFFFFF
    hue = (h % 360) / 360.0
    r, g, b = hsv_to_rgb(hue, 0.42, 0.78)
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def hsv_to_rgb(h, s, v):
    i = int(h * 6)
    f = h * 6 - i
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    return [(v, t, p), (q, v, p), (p, v, t),
            (p, q, v), (t, p, v), (v, p, q)][i % 6]


# ---------------------------------------------------------------------------
# node shapes
# ---------------------------------------------------------------------------

def rot_box(box, turns):
    """Rotate a unit-cube box `turns` quarter turns about the Y axis."""
    turns %= 4
    if turns == 0:
        return box
    x0, y0, z0, x1, y1, z1 = box
    pts = [(x0, z0), (x1, z0), (x0, z1), (x1, z1)]
    for _ in range(turns):
        # facedir +1: local +Z maps to world +X, local +X maps to world -Z
        pts = [(w - 0.5 + 0.5, -(u - 0.5) + 0.5) for (u, w) in pts]
    xs = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    return (min(xs), y0, min(zs), max(xs), y1, max(zs))


def flip_y(box):
    x0, y0, z0, x1, y1, z1 = box
    return (x0, 1.0 - y1, z0, x1, 1.0 - y0, z1)


CUBE = (0.0, 0.0, 0.0, 1.0, 1.0, 1.0)

WALLMOUNT_DIR = {2: (1, 0, 0), 3: (-1, 0, 0), 4: (0, 0, 1), 5: (0, 0, -1),
                 0: (0, 1, 0), 1: (0, -1, 0)}


def node_boxes(shape, param2, conn):
    """Return [(box, face_uv_mode)] for one node; face_uv_mode 'crop'|'full'."""
    fd = param2 & 3
    upside = 20 <= (param2 & 31) <= 23

    if shape in ("cube", "glass", "liquid", "unknown"):
        return [(CUBE, "crop")]

    if shape == "slab":
        box = (0, 0.5, 0, 1, 1, 1) if upside else (0, 0, 0, 1, 0.5, 1)
        return [(box, "crop")]

    if shape == "stair":
        low = (0, 0, 0, 1, 0.5, 1)
        step = rot_box((0, 0.5, 0.5, 1, 1, 1), fd)
        if upside:
            low = flip_y(low)
            step = flip_y(step)
        boxes = [low, step]
        return [(b, "crop") for b in boxes]

    if shape == "torch":
        return [((0.44, 0.0, 0.44, 0.56, 0.62, 0.56), "full")]

    if shape in ("torch_wall", "torch_ceiling"):
        dx, dy, dz = WALLMOUNT_DIR.get(param2 & 7, (0, -1, 0))
        if dy:  # ceiling torch
            return [((0.44, 0.34, 0.44, 0.56, 0.96, 0.56), "full")]
        # hug the wall the torch is attached to, leaning out and up
        cx, cz = 0.5 + dx * 0.36, 0.5 + dz * 0.36
        return [((cx - 0.06, 0.22, cz - 0.06, cx + 0.06, 0.86, cz + 0.06),
                 "full")]

    if shape in ("plant", "billboard"):
        e = 0.035
        return [((0.5 - e, 0, 0.02, 0.5 + e, 0.92, 0.98), "full"),
                ((0.02, 0, 0.5 - e, 0.98, 0.92, 0.5 + e), "full")]

    if shape in ("fence", "fence_rail", "wall"):
        thick = 0.25 if shape == "wall" else 0.125
        a, b = 0.5 - thick, 0.5 + thick
        boxes = [((a, 0, a, b, 1, b), "crop")]
        rail_y = [(0.30, 0.44), (0.62, 0.76)] if shape != "wall" \
            else [(0.0, 0.88)]
        rt = 0.075 if shape != "wall" else 0.1875
        for axis, sign, bit in (("x", 1, 1), ("x", -1, 2),
                                ("z", 1, 4), ("z", -1, 8)):
            if not conn & bit:
                continue
            for (y0, y1) in rail_y:
                if axis == "x":
                    if sign > 0:
                        boxes.append(((b, y0, 0.5 - rt, 1.0, y1, 0.5 + rt),
                                      "crop"))
                    else:
                        boxes.append(((0.0, y0, 0.5 - rt, a, y1, 0.5 + rt),
                                      "crop"))
                else:
                    if sign > 0:
                        boxes.append(((0.5 - rt, y0, b, 0.5 + rt, y1, 1.0),
                                      "crop"))
                    else:
                        boxes.append(((0.5 - rt, y0, 0.0, 0.5 + rt, y1, a),
                                      "crop"))
        return boxes

    if shape == "pane":
        # flat pane: a thin plate; facedir picks the axis it spans
        plate = rot_box((0.0, 0.0, 0.46, 1.0, 1.0, 0.54), fd)
        if conn and not (conn & 3) and (conn & 12):
            plate = (0.46, 0.0, 0.0, 0.54, 1.0, 1.0)
        elif conn and (conn & 3) and not (conn & 12):
            plate = (0.0, 0.0, 0.46, 1.0, 1.0, 0.54)
        return [(plate, "full")]

    if shape in ("door", "trapdoor", "trapdoor_open"):
        if shape == "trapdoor":
            return [((0.0, 0.0, 0.0, 1.0, 0.1875, 1.0), "full")]
        return [(rot_box((0.0, 0.0, 0.0, 1.0, 1.0, 0.1875), fd), "full")]

    if shape == "bed":
        return [(rot_box((0.0, 0.0, 0.0, 1.0, 0.44, 1.0), fd), "crop")]

    if shape == "nodebox":
        return [((0.08, 0.0, 0.08, 0.92, 0.9, 0.92), "crop")]

    if shape == "air":
        return []

    return [(CUBE, "crop")]


# Shapes drawn as a camera-facing sprite instead of boxes: at 16px art a
# 2/16-node-thick box samples almost nothing but transparent pixels, so the
# node disappears. A billboard keeps them visible and recognisable.
BILLBOARD_SHAPES = {"plant", "torch", "torch_wall", "torch_ceiling",
                    "billboard"}

GLASS_BACKING = (188, 222, 235, 70)

CONNECTING_SHAPES = {"fence", "fence_rail", "wall", "pane"}


# ---------------------------------------------------------------------------
# sprite building
# ---------------------------------------------------------------------------

class SpriteFactory:
    def __init__(self, bank, scale, view_turns):
        self.bank = bank
        self.s = scale
        self.view_turns = view_turns
        self.cache = {}
        self.flat_warned = set()

    def project(self, x, y, z):
        s = self.s
        return ((x - z) * s, (x + z) * (s * 0.5) - y * s)

    def tiles_for(self, name):
        entry = self.bank.nodes.get(name) or {}
        tiles = list(entry.get("tiles") or [])
        drawtype = (entry.get("drawtype") or "")
        if drawtype.startswith("glasslike_framed") and tiles:
            tiles = [tiles[0]]
        if not tiles:
            # last-ditch guess: mod "foo:bar" usually ships "foo_bar.png"
            if ":" in name:
                mod, base = name.split(":", 1)
                guess = "%s_%s.png" % (mod, base)
                if self.bank.find_file(guess):
                    tiles = [guess]
        while len(tiles) < 6 and tiles:
            tiles.append(tiles[-1])
        return tiles

    def face_image(self, _name, face, tiles):
        if not tiles:
            return None
        spec = tiles[min(face, len(tiles) - 1)]
        return self.bank.texture(spec)

    def get(self, name, param2, conn, shape, alpha):
        key = (name, param2, conn)
        spr = self.cache.get(key)
        if spr is None:
            spr = self._build(name, param2, conn, shape, alpha)
            self.cache[key] = spr
        return spr

    def _build(self, name, param2, conn, shape, alpha):
        s = self.s
        size = 2 * s
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        origin = (s, s)  # screen position of the cell's (0,0,0) corner
        tiles = self.tiles_for(name)
        flat = None
        if not tiles or all(self.bank.texture(t) is None for t in tiles):
            colors = self.bank.fallback_colors or {}
            hexcol = colors.get(name)
            flat = parse_color(hexcol) if hexcol else flat_color_for(name)
            if name not in self.flat_warned:
                self.flat_warned.add(name)

        if shape in BILLBOARD_SHAPES:
            self._draw_billboard(img, origin, shape, param2, tiles, flat)
        else:
            backing = GLASS_BACKING if shape == "glass" else None
            if backing:
                alpha = 1.0
            boxes = node_boxes(shape, param2, conn)
            boxes.sort(key=lambda bm: sum(bm[0][i] + bm[0][i + 3]
                                          for i in range(3)))
            for box, uvmode in boxes:
                self._draw_box(img, origin, box, uvmode, tiles, flat, alpha,
                               backing)
        if not img.getbbox():
            return None
        return img

    def _draw_billboard(self, img, origin, shape, param2, tiles, flat):
        """Camera-facing sprite standing on the node's base."""
        s = self.s
        cx, cz, lift = 0.5, 0.5, 0.0
        if shape == "torch_wall":
            dx, _dy, dz = WALLMOUNT_DIR.get(param2 & 7, (0, 0, 0))
            cx, cz = 0.5 + dx * 0.34, 0.5 + dz * 0.34
            lift = 0.22
        elif shape == "torch_ceiling":
            lift = 0.38
        sx, sy = self.project(cx, lift, cz)
        sx += origin[0]
        sy += origin[1]
        tex = None if flat else self.bank.texture(tiles[0]) if tiles else None
        w = max(2, int(round(s * 1.30)))
        h = max(2, int(round(s * 1.65)))
        if tex is None:
            col = flat or (170, 170, 170, 255)
            sprite = Image.new("RGBA", (w, h), col)
        else:
            sprite = tex.resize((w, h), Image.NEAREST)
            sprite = shade_image(sprite, 0.94, 1.0)
        px, py = int(round(sx - w / 2.0)), int(round(sy - h))
        img.paste(sprite, (px, py), sprite)

    def _draw_box(self, img, origin, box, uvmode, tiles, flat, alpha,
                  backing=None):
        x0, y0, z0, x1, y1, z1 = box
        ox, oy = origin

        def P(x, y, z):
            sx, sy = self.project(x, y, z)
            return (sx + ox, sy + oy)

        faces = (
            # (tile index, p0, pu, pv, uv rect (u0,v0,u1,v1), shade)
            (FACE_TOP, P(x0, y1, z0), P(x1, y1, z0), P(x0, y1, z1),
             (x0, z0, x1, z1), SHADE_TOP),
            (FACE_XP, P(x1, y1, z1), P(x1, y1, z0), P(x1, y0, z1),
             (1 - z1, 1 - y1, 1 - z0, 1 - y0), SHADE_X),
            (FACE_ZP, P(x0, y1, z1), P(x1, y1, z1), P(x0, y0, z1),
             (x0, 1 - y1, x1, 1 - y0), SHADE_Z),
        )
        for face, p0, pu_pt, pv_pt, uv, shade in faces:
            pu = (pu_pt[0] - p0[0], pu_pt[1] - p0[1])
            pv = (pv_pt[0] - p0[0], pv_pt[1] - p0[1])
            if abs(pu[0] * pv[1] - pu[1] * pv[0]) < 1e-6:
                continue
            if backing:
                paste_quad(img, Image.new("RGBA", (2, 2), backing), p0, pu,
                           pv, (0, 0, 1, 1), shade, 1.0)
            tex = None if flat else self.face_image(None, face, tiles)
            if tex is None:
                col = flat or (170, 170, 170, 255)
                tex = Image.new("RGBA", (4, 4), col)
                uv = (0, 0, 1, 1)
            elif uvmode == "full":
                uv = (0, 0, 1, 1)
            paste_quad(img, tex, p0, pu, pv, uv, shade, alpha)


def shade_image(tex, shade, alpha):
    if shade >= 0.999 and alpha >= 0.999:
        return tex
    r, g, b, a = tex.split()
    lut = [min(255, int(i * shade)) for i in range(256)]
    r, g, b = r.point(lut), g.point(lut), b.point(lut)
    if alpha < 0.999:
        a = a.point([int(i * alpha) for i in range(256)])
    return Image.merge("RGBA", (r, g, b, a))


def paste_quad(dst, tex, p0, pu, pv, uv, shade, alpha):
    """Draw `tex` (sub-rect uv) into the parallelogram p0 + s*pu + t*pv."""
    tw, th = tex.size
    u0, v0, u1, v1 = uv
    cx0, cy0 = int(round(u0 * tw)), int(round(v0 * th))
    cx1, cy1 = max(cx0 + 1, int(round(u1 * tw))), \
        max(cy0 + 1, int(round(v1 * th)))
    sub = tex.crop((cx0, cy0, min(cx1, tw), min(cy1, th)))
    sub = shade_image(sub, shade, alpha)
    sw, sh = sub.size
    if sw < 1 or sh < 1:
        return

    corners = [p0,
               (p0[0] + pu[0], p0[1] + pu[1]),
               (p0[0] + pu[0] + pv[0], p0[1] + pu[1] + pv[1]),
               (p0[0] + pv[0], p0[1] + pv[1])]
    xs = [c[0] for c in corners]
    ys = [c[1] for c in corners]
    ox, oy = int(math.floor(min(xs))), int(math.floor(min(ys)))
    w = int(math.ceil(max(xs))) - ox
    h = int(math.ceil(max(ys))) - oy
    if w <= 0 or h <= 0:
        return

    det = pu[0] * pv[1] - pu[1] * pv[0]
    if abs(det) < 1e-9:
        return
    i00, i01 = pv[1] / det, -pv[0] / det
    i10, i11 = -pu[1] / det, pu[0] / det
    dx, dy = ox - p0[0] + 0.5, oy - p0[1] + 0.5
    a = sw * i00
    b = sw * i01
    c = sw * (i00 * dx + i01 * dy)
    d = sh * i10
    e = sh * i11
    f = sh * (i10 * dx + i11 * dy)
    warped = sub.transform((w, h), Image.AFFINE, (a, b, c, d, e, f),
                           resample=Image.NEAREST)

    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon([(cx - ox, cy - oy) for cx, cy in corners],
                                 fill=255)
    mask = ImageChops.multiply(mask, warped.getchannel("A"))
    dst.paste(warped, (ox, oy), mask)


# ---------------------------------------------------------------------------
# model preparation
# ---------------------------------------------------------------------------

def rotate_param2(p2, paramtype2, turns):
    turns %= 4
    if turns == 0:
        return p2
    if paramtype2 == "wallmounted":
        wm = {2: 5, 5: 3, 3: 4, 4: 2}
        d = p2 & 7
        for _ in range(turns):
            d = wm.get(d, d)
        return (p2 & ~7) | d
    # facedir / colorfacedir: rotate the horizontal quarter only
    axis = p2 & ~3
    return axis | ((p2 + turns) & 3)


# ---------------------------------------------------------------------------
# main render
# ---------------------------------------------------------------------------

def build_model(cells, bank, args):
    """Filter, rotate and classify cells. Returns (cells, meta-by-name)."""
    turns = VIEW_TURNS[args.view]
    meta = {}

    def info(name):
        m = meta.get(name)
        if m is None:
            entry = bank.nodes.get(name) or {}
            shape = entry.get("shape") or ("air" if name == "air" else
                                           "unknown")
            if name == "air":
                shape = "air"
            alpha = 1.0
            if shape == "glass":
                alpha = 0.55
            elif shape == "liquid":
                alpha = 0.75
            opaque = shape in ("cube",) and alpha >= 0.999
            m = (shape, alpha, opaque, entry.get("paramtype2") or "")
            meta[name] = m
        return m

    kept = []
    for (x, y, z, name, p2) in cells:
        if name == "air" or name == "ignore":
            continue
        shape, alpha, opaque, pt2 = info(name)
        if shape == "air":
            continue
        if args.ymax is not None and y > args.ymax:
            continue
        if args.ymin is not None and y < args.ymin:
            continue
        if args.region:
            rx0, rz0, rx1, rz1 = args.region
            if not (rx0 <= x <= rx1 and rz0 <= z <= rz1):
                continue
        nx, nz = x, z
        for _ in range(turns):
            nx, nz = nz, -nx
        kept.append((nx, y, nz, name, rotate_param2(p2, pt2, turns)))
    return kept, meta


def cull(cells, meta):
    """Drop cells whose three visible faces all touch an opaque neighbour."""
    opaque = set()
    for (x, y, z, name, _p2) in cells:
        if meta[name][2]:
            opaque.add((x, y, z))
    out = []
    for cell in cells:
        x, y, z = cell[0], cell[1], cell[2]
        if (x + 1, y, z) in opaque and (x, y + 1, z) in opaque and \
                (x, y, z + 1) in opaque:
            continue
        out.append(cell)
    return out


def connection_mask(cells, meta):
    """Neighbour bitmask (+x,-x,+z,-z) for fence/wall/pane style nodes."""
    solid = set()
    for (x, y, z, name, _p2) in cells:
        shape = meta[name][0]
        if shape not in ("air", "plant", "torch", "torch_wall",
                         "torch_ceiling"):
            solid.add((x, y, z))
    masks = {}
    for (x, y, z, name, _p2) in cells:
        if meta[name][0] not in CONNECTING_SHAPES:
            continue
        m = 0
        if (x + 1, y, z) in solid:
            m |= 1
        if (x - 1, y, z) in solid:
            m |= 2
        if (x, y, z + 1) in solid:
            m |= 4
        if (x, y, z - 1) in solid:
            m |= 8
        masks[(x, y, z)] = m
    return masks


def render(cells, bank, args):
    cells, meta = build_model(cells, bank, args)
    if not cells:
        raise SystemExit("nothing to draw (all cells filtered out?)")
    total = len(cells)
    cells = cull(cells, meta)
    conn = connection_mask(cells, meta)

    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    zs = [c[2] for c in cells]
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)
    minz, maxz = min(zs), max(zs)

    scale = args.scale
    while scale > 1:
        w = int((maxx - minx + maxz - minz + 2) * scale) + 4
        h = int(((maxx - minx + maxz - minz + 2) * scale) / 2
                + (maxy - miny + 2) * scale) + 4
        if w <= args.max_pixels and h <= args.max_pixels:
            break
        scale -= 1
    if scale != args.scale:
        sys.stderr.write("scale reduced %d -> %d to stay under %dpx\n"
                         % (args.scale, scale, args.max_pixels))

    factory = SpriteFactory(bank, scale, VIEW_TURNS[args.view])
    corners = [factory.project(x, y, z)
               for x in (minx, maxx + 1) for y in (miny, maxy + 1)
               for z in (minz, maxz + 1)]
    pad = scale
    ox = -min(c[0] for c in corners) + pad
    oy = -min(c[1] for c in corners) + pad
    width = int(max(c[0] for c in corners) + ox + pad)
    height = int(max(c[1] for c in corners) + oy + pad)

    bg = parse_color(args.background) or (24, 26, 30, 255)
    img = Image.new("RGBA", (width, height), bg)

    cells.sort(key=lambda c: (c[0] + c[1] + c[2], c[1]))
    drawn = 0
    for (x, y, z, name, p2) in cells:
        shape, alpha, _opaque, _pt2 = meta[name]
        cmask = conn.get((x, y, z), 0) if shape in CONNECTING_SHAPES else 0
        spr = factory.get(name, p2, cmask, shape, alpha)
        if spr is None:
            continue
        sx, sy = factory.project(x, y, z)
        img.paste(spr, (int(sx + ox) - scale, int(sy + oy) - scale), spr)
        drawn += 1

    if args.light:
        img = apply_night(img, cells, meta, factory, bank, ox, oy, scale)

    return img, {"total": total, "after_cull": len(cells), "drawn": drawn,
                 "scale": scale, "size": (width, height),
                 "sprites": len(factory.cache),
                 "flat": sorted(factory.flat_warned)}


LIGHT_SOURCE_HINTS = ("torch", "lantern", "lamp", "furnace_active", "fire:",
                      "meselamp", "campfire", "candle", "brazier")


def is_light_source(name, shape):
    if shape in ("torch", "torch_wall", "torch_ceiling"):
        return True
    low = name.lower()
    return any(h in low for h in LIGHT_SOURCE_HINTS)


def apply_night(img, cells, meta, factory, bank, ox, oy, scale):
    rgb = img.convert("RGB")
    night_lut = [int((i / 255.0) ** 1.15 * 255 * 0.30) for i in range(256)]
    r, g, b = rgb.split()
    r = r.point(night_lut)
    g = g.point(night_lut)
    b = b.point([int(v * 1.25) if v * 1.25 < 255 else 255 for v in night_lut])
    night = Image.merge("RGB", (r, g, b))

    radius = max(3 * scale, 24)
    size = radius * 2 + 1
    glow = Image.new("L", (size, size), 0)
    gpx = glow.load()
    for yy in range(size):
        for xx in range(size):
            dx = (xx - radius) / float(radius)
            dy = (yy - radius) / float(radius) * 2.0  # dimetric squash
            d = math.sqrt(dx * dx + dy * dy)
            if d >= 1.0:
                continue
            gpx[xx, yy] = int(255 * (1.0 - d) ** 2.2)

    acc = Image.new("L", img.size, 0)
    lights = 0
    for (x, y, z, name, _p2) in cells:
        shape = meta[name][0]
        if not is_light_source(name, shape):
            continue
        sx, sy = factory.project(x, y, z)
        px, py = int(sx + ox) - radius, int(sy + oy) - radius - scale // 2
        box = (px, py, px + size, py + size)
        region = acc.crop(box)
        acc.paste(ImageChops.add(region, glow), box)
        lights += 1

    tint = Image.merge("RGB", (
        acc.point(lambda v: min(255, int(v * 0.95))),
        acc.point(lambda v: int(v * 0.62)),
        acc.point(lambda v: int(v * 0.26))))
    out = ImageChops.add(night, tint)
    sys.stderr.write("night mode: %d light sources\n" % lights)
    return out.convert("RGBA")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", help="blueprint .lua or cell TSV")
    ap.add_argument("-o", "--out", default="blueprint.png")
    ap.add_argument("--view", choices=sorted(VIEW_TURNS), default="ne",
                    help="camera corner; rotates the model in 90 deg steps "
                         "(default ne = over the +x/+z corner)")
    ap.add_argument("--ymax", type=int, default=None,
                    help="drop cells above this local y (interior cutaway)")
    ap.add_argument("--ymin", type=int, default=None,
                    help="drop cells below this local y")
    ap.add_argument("--region", nargs=4, type=int, metavar=("X1", "Z1",
                                                            "X2", "Z2"),
                    default=None, help="crop to local x/z rectangle")
    ap.add_argument("--scale", type=int, default=16,
                    help="pixels per node (default 16)")
    ap.add_argument("--max-pixels", type=int, default=4000,
                    help="auto-reduce scale to stay under this (default 4000)")
    ap.add_argument("--light", action="store_true",
                    help="night mode: darken, then glow around light sources")
    ap.add_argument("--background", default="#181a1e")
    ap.add_argument("--tiles", default=DEFAULT_TILES,
                    help="node tile map (default tools/wp13/node_tiles.json)")
    ap.add_argument("--texture-root", action="append", default=[],
                    help="extra directory tree to search for textures")
    ap.add_argument("--lua", default=None, help="Lua 5.1 interpreter to use")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    if args.region:
        x1, z1, x2, z2 = args.region
        args.region = (min(x1, x2), min(z1, z2), max(x1, x2), max(z1, z2))

    t0 = time.time()
    if not os.path.exists(args.tiles):
        raise SystemExit("missing %s - run tools/wp13/extract_tiles.py first"
                         % args.tiles)
    bank = TextureBank(args.tiles, args.texture_root)
    cells = load_cells(args.input, args.lua)
    t_load = time.time()
    img, stats = render(cells, bank, args)
    t_draw = time.time()
    img.convert("RGB").save(args.out)
    t_end = time.time()

    if not args.quiet:
        sys.stderr.write(
            "%s: %dx%d px, scale %d, %d cells -> %d after culling, "
            "%d sprites\n" % (args.out, stats["size"][0], stats["size"][1],
                              stats["scale"], stats["total"],
                              stats["after_cull"], stats["sprites"]))
        sys.stderr.write("timing: load %.1fs, draw %.1fs, save %.1fs, "
                         "total %.1fs\n" % (t_load - t0, t_draw - t_load,
                                            t_end - t_draw, t_end - t0))
        if stats["flat"]:
            sys.stderr.write("UNRESOLVED (drawn as flat colour): %s\n"
                             % ", ".join(stats["flat"]))
        if bank.warnings:
            sys.stderr.write("texture warnings:\n")
            for msg, count in bank.warnings.most_common(20):
                sys.stderr.write("  %s (x%d)\n" % (msg, count))
    return 0


if __name__ == "__main__":
    sys.exit(main())
