#!/usr/bin/env python3
"""Paint the hood in three views and project them onto its faces (Round 56 HOODPAINT).

The hood's sheet (docs/technical/armor-format.md §1a) holds its faces as separate rectangles, each in its own
orientation, so a border or a pattern does not run across the head by itself. This tool lets a painter paint
what one sees instead: the hood from the side, from behind and from above, at one pixel per skin pixel, and
projects those views onto the faces' texels.

  python3 views.py templates OUT_DIR       side.png, back.png, top.png (paint these) and *_8x.png (guides)
  python3 views.py project SIDE BACK TOP -o hood_<variant>.png      the 64x12 sheet, palette checked
  python3 views.py preview SHEET [--views SIDE BACK TOP] [-o preview.png]   the sheet rendered from the views
  python3 views.py demo OUT_DIR            an example view set, its sheet and its preview (test art only)
  python3 views.py --selftest              seams, uniform views, refusals, round trip, check.py

The views (one pixel = one skin pixel, a margin of one pixel round the hood):
  side  seen from the character's right (-x): columns from the back (left) to the front (right), rows top down;
        it paints both sides (the part is symmetric about x = 0; the left faces sample it mirrored);
  back  seen from behind (-z): columns from the character's left (left) to the character's right, rows top down;
  top   seen from above (+y): columns from the character's right (left) to left, rows from the back (top) to
        the front (bottom), as the top faces lie on the sheet.
A view pixel covers one skin pixel of the catalog frame (pixel borders on whole skin pixels); a point exactly
on a pixel border belongs to the pixel right of or below it.

Projection: every texel of every face rectangle (bleed included) takes its centre's 3D point through the face's
affine uv -> 3D map (from the schema's vertices and uv), and samples the view the face's outward normal points
at: the dominant axis (largest |component|) chooses; x -> side, z with n_z < 0 -> back, y with n_y > 0 -> top
(a face facing the front or down has no view and is refused). Ties go in the order x, z, y. The texel takes
the colour of the view pixel its point projects into (nearest pixel).

The geometry comes from the schema file (default tools/r56_hood/hood.json, --part FILE) and the catalog data of
tools/r54_armor (the shell box that closes the part, the head); nothing about the hood's shape is fixed here.
Python 3 and Pillow; test art only, nothing here ships.
"""
import argparse
import math
import random
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ARMOR = HERE.parent / "r54_armor"
sys.path.insert(0, str(ARMOR))
from PIL import Image, ImageChops, ImageDraw, ImageFilter  # noqa: E402

import armorlib as L  # noqa: E402
import polypart as PP  # noqa: E402
import templates as TP  # noqa: E402  (font, compose_wrapped, inside, the face tints)

PART = HERE / "hood.json"
EPS = 1e-9
S = 8                                       # the guides' and the preview's scale (--scale)
# name, image right, image down, toward the viewer (unit axes), what it shows, the edge labels left/right/top/bottom
VIEWS = [
    ("side", (0, 0, 1), (0, -1, 0), (-1, 0, 0), "seen from the character's right (-x); paints both sides",
     ("BACK", "FRONT", "UP", "DOWN")),
    ("back", (-1, 0, 0), (0, -1, 0), (0, 0, -1), "seen from behind (-z)", ("LEFT", "RIGHT", "UP", "DOWN")),
    ("top", (1, 0, 0), (0, 0, 1), (0, 1, 0), "seen from above (+y)", ("RIGHT", "LEFT", "BACK", "FRONT")),
]
VIEW_NAMES = [v[0] for v in VIEWS]
TINTS = [(250, 226, 160), (170, 205, 245), (245, 185, 185), (180, 235, 180), (215, 190, 240),
         (205, 190, 150), (160, 225, 220), (240, 205, 170)]     # as templates/parts/<part>.png, by face index
HELM_GREY, HEAD_GREY = (184, 184, 184), (136, 136, 136)        # not reference colours
EDGE, OTHER_EDGE, SILHOUETTE, HOLE = (200, 0, 120), (110, 110, 110), (25, 25, 25), (255, 0, 255)
REF = {name: L.hex_rgb(h) for _, name, h, _ in L.REFERENCE}


# ---------- vectors ----------
def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def add(a, b, k=1.0):
    return (a[0] + k * b[0], a[1] + k * b[1], a[2] + k * b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


# ---------- geometry ----------
class Face:
    """One planar face: `pts` (3D), `uv` (sheet texels), `rect`, outward unit normal `n`, its `view`, the affine
    map uv -> 3D (`O + u U + v V`) and back, and `kind` 'hood' or 'shell'."""

    def __init__(self, name, index, pts, uv, rect, n, kind="hood"):
        self.name, self.index, self.pts, self.uv, self.rect, self.n, self.kind = name, index, pts, uv, rect, n, kind
        self.view = None
        self.mirror = None
        if uv is not None:
            self._fit()

    def _fit(self):
        p, uv = self.pts, self.uv
        best = None
        for i in range(1, len(p)):
            for j in range(i + 1, len(p)):
                du1, dv1 = uv[i][0] - uv[0][0], uv[i][1] - uv[0][1]
                du2, dv2 = uv[j][0] - uv[0][0], uv[j][1] - uv[0][1]
                det = du1 * dv2 - du2 * dv1
                if best is None or abs(det) > abs(best[0]):
                    best = (det, i, j, du1, dv1, du2, dv2)
        det, i, j, du1, dv1, du2, dv2 = best
        if abs(det) < 1e-9:
            raise SystemExit(f"{self.name}: its uv polygon has no area")
        d1, d2 = sub(p[i], p[0]), sub(p[j], p[0])
        self.U = tuple((dv2 * d1[k] - dv1 * d2[k]) / det for k in range(3))
        self.V = tuple((-du2 * d1[k] + du1 * d2[k]) / det for k in range(3))
        self.O = tuple(p[0][k] - uv[0][0] * self.U[k] - uv[0][1] * self.V[k] for k in range(3))
        off = max(math.dist(self.point(u, v), q) for (u, v), q in zip(uv, p))
        if off > 0.01:
            raise SystemExit(f"{self.name}: its uv map is not affine ({off:.4f} px off at a vertex); the tool "
                             "needs one affine map per face")
        a, b, c = dot(self.U, self.U), dot(self.U, self.V), dot(self.V, self.V)
        g = a * c - b * b
        self.inv = ((c / g, -b / g), (-b / g, a / g))

    def point(self, u, v):
        return tuple(self.O[k] + u * self.U[k] + v * self.V[k] for k in range(3))

    def uv_of(self, p):
        d = sub(p, self.O)
        x, y = dot(d, self.U), dot(d, self.V)
        return (self.inv[0][0] * x + self.inv[0][1] * y, self.inv[1][0] * x + self.inv[1][1] * y)

    def texels(self):
        x0, y0, w, h = self.rect
        return [(x, y) for y in range(y0, y0 + h) for x in range(x0, x0 + w)]


def choose_view(n):
    """The view a face with outward normal n samples: the dominant axis, ties in the order x, z, y."""
    k = max((0, 2, 1), key=lambda a: (round(abs(n[a]), 9), -(0, 2, 1).index(a)))
    if k == 0:
        return "side"
    if k == 2:
        return "back" if n[2] < 0 else None
    return "top" if n[1] > 0 else None


def box_faces(box, kind):
    """The six faces of a box [x0, y0, z0, x1, y1, z1] (corner cycles, outward normals), for the renders."""
    x0, y0, z0, x1, y1, z1 = box
    c = {(i, j, k): (x1 if i else x0, y1 if j else y0, z1 if k else z0) for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    quads = [  # four corners (x, y, z: 0 low, 1 high), the outward normal
        ((0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0), (-1, 0, 0)),
        ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1), (1, 0, 0)),
        ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1), (0, -1, 0)),
        ((0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0), (0, 1, 0)),
        ((0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0), (0, 0, -1)),
        ((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)),
    ]
    return [Face(f"{kind}{i}", -1, [c[q] for q in quad[:4]], None, None, quad[4], kind) for i, quad in enumerate(quads)]


class Frame:
    """A view's pixel grid: point p -> continuous pixel coords (dot(p - o, R), dot(p - o, D)); `cols` x `rows`."""

    def __init__(self, name, R, D, E, o, cols, rows, title="", labels=("", "", "", "")):
        self.name, self.R, self.D, self.E, self.o = name, R, D, E, o
        self.cols, self.rows, self.title, self.labels = cols, rows, title, labels

    def cont(self, p):
        d = sub(p, self.o)
        return dot(d, self.R), dot(d, self.D)

    def pixel(self, p):
        c, r = self.cont(p)
        return int(math.floor(c + EPS)), int(math.floor(r + EPS))

    def base(self, c, r):
        """The world point of the continuous pixel coords (c, r) on the plane through o."""
        return add(add(self.o, self.R, c), self.D, r)


class Hood:
    def __init__(self, part_path=PART):
        cat = L.load_catalog()
        part = PP.load(part_path)
        self.part = part
        self.id = part["id"]
        shell_id = next((p["shell"] for p in cat.get("parts", []) if p["id"] == part["id"]), "helm")
        boxes = {b["id"]: b["box"] for b in cat["boxes"]}
        self.shell_id, self.shell = shell_id, boxes[shell_id]
        self.head = next(b["box"] for b in cat["body"] if b["id"] == "head")
        errs = PP.validate(part, self.shell)
        if errs:
            raise SystemExit(f"{part_path}: not a valid polygon part:\n  " + "\n  ".join(errs))
        self.sheet = tuple(part["sheet"])
        self.faces = []
        for i, f in enumerate(part["faces"]):
            pts = PP.points(part, f)
            face = Face(f["name"], i, pts, [tuple(q) for q in f["uv"]], tuple(f["rect"]), PP.newell(pts))
            face.view = choose_view(face.n)
            if face.view is None:
                raise SystemExit(f"{face.name}: faces {'the front' if face.n[2] > 0 else 'down'} "
                                 f"(normal {tuple(round(c, 3) for c in face.n)}); there is no view for it")
            self.faces.append(face)
        self.shell_faces = box_faces(self.shell, "shell")
        # mirror partners (a different face whose points are this face's mirrored in x)
        key = {frozenset((round(-p[0], 3), round(p[1], 3), round(p[2], 3)) for p in f.pts): f for f in self.faces}
        for f in self.faces:
            m = key.get(frozenset((round(p[0], 3), round(p[1], 3), round(p[2], 3)) for p in f.pts))
            f.mirror = m if m is not None and m is not f else None
        self.samples = {}           # (face name, sheet x, sheet y) -> (point, inside the polygon)
        for f in self.faces:
            for x, y in f.texels():
                self.samples[(f.name, x, y)] = (f.point(x + 0.5, y + 0.5), TP.inside(f.uv, (x + 0.5, y + 0.5)))
        self.frames = {}
        V = self.part["vertices"]
        for name, R, D, E, title, labels in VIEWS:
            pts = [tuple(p) for p in V]
            spts = [p for (fn, _, _), (p, _) in self.samples.items() if self.face(fn).view == name]
            o, size = [0.0, 0.0, 0.0], []
            for ax in (R, D):
                k = next(i for i in range(3) if ax[i])
                s = ax[k]
                lo = min([math.floor(s * p[k] + EPS) for p in pts + spts])
                hi = max([math.ceil(s * p[k] - EPS) - 1 for p in pts] + [math.floor(s * p[k] + EPS) for p in spts])
                lo, hi = lo - 1, hi + 1                         # the margin
                o[k] = s * lo
                size.append(hi - lo + 1)
            self.frames[name] = Frame(name, R, D, E, tuple(o), size[0], size[1], title, labels)

    def face(self, name):
        return next(f for f in self.faces if f.name == name)

    def sample_map(self):
        """(face name, sheet x, sheet y) -> (view, col, row) of every texel of every face rect."""
        out = {}
        for (fn, x, y), (p, _) in self.samples.items():
            v = self.face(fn).view
            out[(fn, x, y)] = (v,) + self.frames[v].pixel(p)
        return out


# ---------- projection ----------
def load_views(paths, hood):
    ims = {}
    for name, path in zip(VIEW_NAMES, paths):
        im = Image.open(path).convert("RGBA")
        fr = hood.frames[name]
        if im.size != (fr.cols, fr.rows):
            raise SystemExit(f"{path}: the {name} view is {im.width}x{im.height}, expected {fr.cols}x{fr.rows} "
                             f"(start from `views.py templates`)")
        ims[name] = im
    return ims


def project(hood, ims, strict=True):
    """-> (sheet RGBA, problems). `strict`: every sample must be opaque and a reference colour."""
    sheet = Image.new("RGBA", hood.sheet, (0, 0, 0, 0))
    px = sheet.load()
    vp = {k: im.load() for k, im in ims.items()}
    problems = []
    for (fn, x, y), (v, c, r) in hood.sample_map().items():
        f = hood.face(fn)
        fr = hood.frames[v]
        where = f"{fn} texel ({x - f.rect[0]},{y - f.rect[1]}) (sheet {x},{y}) samples {v} view pixel ({c},{r})"
        if not (0 <= c < fr.cols and 0 <= r < fr.rows):
            problems.append(f"{where}: outside the view")
            continue
        col = vp[v][c, r]
        if strict and col[3] != 255:
            problems.append(f"{where}: {'transparent' if col[3] == 0 else f'partial alpha {col[3]}'}")
        elif strict and col[:3] not in L.REF_RGB:
            problems.append(f"{where}: colour {L.rgb_hex(col)} is not in the reference palette")
        px[x, y] = col if strict else col[:3] + (255,)
    return sheet, problems


# ---------- an orthographic rasteriser (flat colours) ----------
def raster(hood, frame, scale, sheet=None, shade=False):
    """Render the part and its shell box from `frame` at `scale` px per view pixel (pixel centres): -> (owner,
    colour) rows; owner is the hood Face, a shell face or None; colour from the sheet's texel (HOLE where it is
    transparent), the shell grey, or None."""
    W, H = frame.cols * scale, frame.rows * scale
    depth = [[-math.inf] * W for _ in range(H)]
    owner = [[None] * W for _ in range(H)]
    colour = [[None] * W for _ in range(H)]
    spx = sheet.load() if sheet is not None else None
    for f in hood.faces + hood.shell_faces:
        ne = dot(f.n, frame.E)
        if ne <= 1e-9:
            continue
        scr = [tuple(v * scale for v in frame.cont(p)) for p in f.pts]
        x0, x1 = max(0, int(math.floor(min(q[0] for q in scr)))), min(W - 1, int(math.ceil(max(q[0] for q in scr))))
        y0, y1 = max(0, int(math.floor(min(q[1] for q in scr)))), min(H - 1, int(math.ceil(max(q[1] for q in scr))))
        d = dot(f.n, f.pts[0])
        light = 1.0
        if shade:
            light = 0.62 + 0.38 * max(0.0, dot(f.n, (-0.35, 0.8, -0.48)))
        for py in range(y0, y1 + 1):
            for px_ in range(x0, x1 + 1):
                c = (px_ + 0.5, py + 0.5)
                if not TP.inside(scr, c):
                    continue
                b = frame.base(c[0] / scale, c[1] / scale)
                t = (d - dot(f.n, b)) / ne
                if t <= depth[py][px_]:
                    continue
                depth[py][px_] = t
                owner[py][px_] = f
                if f.kind == "shell":
                    col = HELM_GREY
                elif spx is None:
                    col = TINTS[f.index % len(TINTS)]
                else:
                    u, v = f.uv_of(add(b, frame.E, t))
                    rx, ry, rw, rh = f.rect
                    tx = min(max(int(math.floor(u)), rx), rx + rw - 1)
                    ty = min(max(int(math.floor(v)), ry), ry + rh - 1)
                    tc = spx[tx, ty]
                    col = tc[:3] if tc[3] >= 128 else HOLE
                colour[py][px_] = tuple(min(255, int(ch * light + 0.5)) for ch in col)
    return owner, colour


def oblique_frame(hood, E, up=(0.0, 1.0, 0.0), margin=1.0):
    """An orthographic frame looking along -E (a three-quarter view), fitted round the part and its shell."""
    n = math.sqrt(dot(E, E))
    E = tuple(c / n for c in E)
    R = (up[1] * E[2] - up[2] * E[1], up[2] * E[0] - up[0] * E[2], up[0] * E[1] - up[1] * E[0])
    n = math.sqrt(dot(R, R))
    R = tuple(c / n for c in R)
    U = (E[1] * R[2] - E[2] * R[1], E[2] * R[0] - E[0] * R[2], E[0] * R[1] - E[1] * R[0])
    D = tuple(-c for c in U)
    pts = [tuple(p) for p in hood.part["vertices"]] + [q for f in hood.shell_faces for q in f.pts]
    xs, ys = [dot(p, R) for p in pts], [dot(p, D) for p in pts]
    o0, o1 = min(xs) - margin, min(ys) - margin
    o = add(add((0.0, 0.0, 0.0), R, o0), D, o1)
    return Frame("3/4", R, D, E, o, int(math.ceil(max(xs) - o0 + margin)), int(math.ceil(max(ys) - o1 + margin)))


# ---------- drawing helpers ----------
def checker(x, y):
    return (238, 238, 238) if ((x // 4) + (y // 4)) % 2 else (226, 226, 226)


def to_image(colour, W, H):
    im = Image.new("RGB", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            px[x, y] = colour[y][x] or checker(x, y)
    return im


def scaled(im, frame):
    """A 1x view (RGBA) at S x with transparent pixels on a checker."""
    out = Image.new("RGB", (frame.cols * S, frame.rows * S))
    px, src = out.load(), im.load()
    for y in range(out.height):
        for x in range(out.width):
            c = src[x // S, y // S]
            px[x, y] = c[:3] if c[3] >= 128 else checker(x, y)
    return out


def draw_lines(hood, frame, im):
    """Face edges (magenta: faces painted in this view; grey: other faces seen from here), the part's silhouette,
    the shell box's and the head's outlines, at S x."""
    d = ImageDraw.Draw(im)
    mask = Image.new("L", im.size, 0)
    md = ImageDraw.Draw(mask)
    for f in hood.faces:
        scr = [tuple(v * S for v in frame.cont(p)) for p in f.pts]
        md.polygon(scr, fill=255)
    for box, col in ((hood.head, HEAD_GREY), (hood.shell, (95, 95, 95))):
        corners = [(box[i], box[j], box[k]) for i in (0, 3) for j in (1, 4) for k in (2, 5)]
        xs = [frame.cont(c)[0] * S for c in corners]
        ys = [frame.cont(c)[1] * S for c in corners]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        dash = 4 if col == HEAD_GREY else 0
        for a, b in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
            if not dash:
                d.line([a, b], fill=col, width=1)
                continue
            n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1])) // dash)
            for i in range(0, n, 2):
                t0, t1 = i / max(n, 1), min(1.0, (i + 1) / max(n, 1))
                d.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                        (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], fill=col, width=1)
    for f in sorted(hood.faces, key=lambda f: f.view == frame.name):
        if dot(f.n, frame.E) <= 1e-9:
            continue
        scr = [tuple(v * S for v in frame.cont(p)) for p in f.pts]
        mine = f.view == frame.name
        d.line(scr + scr[:1], fill=EDGE if mine else OTHER_EDGE, width=2 if mine else 1)
    im.paste(SILHOUETTE, mask=ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(5))))


def framed(im, labels, font_size=11):
    """The image with a band round it carrying the edge labels (left, right, top, bottom)."""
    f = TP.font(font_size)
    side = 46
    out = Image.new("RGB", (im.width + 2 * side, im.height + 36), (250, 249, 246))
    out.paste(im, (side, 18))
    d = ImageDraw.Draw(out)
    left, right, top, bottom = labels
    d.text((side - 4 - d.textlength(left, font=f), 18 + im.height / 2 - 6), left, fill=(30, 30, 30), font=f)
    d.text((side + im.width + 4, 18 + im.height / 2 - 6), right, fill=(30, 30, 30), font=f)
    d.text((side + im.width / 2 - d.textlength(top, font=f) / 2, 3), top, fill=(30, 30, 30), font=f)
    d.text((side + im.width / 2 - d.textlength(bottom, font=f) / 2, 18 + im.height + 3), bottom, fill=(30, 30, 30),
           font=f)
    return out


def hstack(ims, gap=16, bg=(250, 249, 246)):
    out = Image.new("RGB", (sum(i.width for i in ims) + gap * (len(ims) - 1), max(i.height for i in ims)), bg)
    x = 0
    for i in ims:
        out.paste(i, (x, 0))
        x += i.width + gap
    return out


def vstack(ims, gap=10, bg=(250, 249, 246)):
    out = Image.new("RGB", (max(i.width for i in ims), sum(i.height for i in ims) + gap * (len(ims) - 1)), bg)
    y = 0
    for i in ims:
        out.paste(i, (0, y))
        y += i.height + gap
    return out


def caption(im, text, font_size=12):
    f = TP.font(font_size)
    out = Image.new("RGB", (max(im.width, int(ImageDraw.Draw(im).textlength(text, font=f)) + 4), im.height + 18),
                    (250, 249, 246))
    ImageDraw.Draw(out).text((2, 2), text, fill=(20, 20, 20), font=f)
    out.paste(im, (0, 18))
    return out


# ---------- templates ----------
def fill_area(hood, name):
    """{(col, row): (face, inside)} of the pixels the faces painted in this view sample; `inside` when a texel
    centre inside a polygon samples it (otherwise only bleed does). The first face (schema order) names a pixel."""
    area = {}
    for (fn, x, y), (v, c, r) in hood.sample_map().items():
        if v != name:
            continue
        f, inside = hood.face(fn), hood.samples[(fn, x, y)][1]
        old = area.get((c, r))
        if old is None or (inside and not old[1]) or (inside == old[1] and f.index < old[0].index):
            area[(c, r)] = (f, inside)
    return area


def template(hood, name):
    """The 1x view to paint into: the fill area tinted per face (darker: only bleed samples it), the shell box and
    the head in grey for orientation (never sampled), the rest transparent. No tint is a reference colour, so a
    pixel left unpainted is refused by `project`."""
    fr = hood.frames[name]
    im = Image.new("RGBA", (fr.cols, fr.rows), (0, 0, 0, 0))
    px = im.load()
    for box, col in ((hood.shell, HELM_GREY), (hood.head, HEAD_GREY)):
        corners = [(box[i], box[j], box[k]) for i in (0, 3) for j in (1, 4) for k in (2, 5)]
        cs = [fr.cont(c) for c in corners]
        c0, c1 = math.floor(min(c[0] for c in cs) + EPS), math.ceil(max(c[0] for c in cs) - EPS)
        r0, r1 = math.floor(min(c[1] for c in cs) + EPS), math.ceil(max(c[1] for c in cs) - EPS)
        for r in range(max(0, r0), min(fr.rows, r1)):
            for c in range(max(0, c0), min(fr.cols, c1)):
                px[c, r] = col + (255,)
    for (c, r), (f, inside) in fill_area(hood, name).items():
        t = TINTS[f.index % len(TINTS)]
        px[c, r] = (t if inside else tuple(int(v * 0.78) for v in t)) + (255,)
    return im


def guide(hood, name, one):
    """The guide of a view (S x): the 1x template, a pixel grid, hatching where a face seen from here is painted in
    another view, face edges, the silhouette, the shell and head outlines, face labels, edge labels, legend."""
    fr = hood.frames[name]
    im = scaled(one, fr)
    d = ImageDraw.Draw(im)
    area = fill_area(hood, name)
    owner, _ = raster(hood, fr, 1)
    other = {}
    for r in range(fr.rows):
        for c in range(fr.cols):
            f = owner[r][c]
            if f is not None and f.kind == "hood" and f.view != name and (c, r) not in area:
                other.setdefault(f.view, set()).add(f.name)
                for k in range(0, S, 3):
                    d.line([(c * S + k, r * S), (c * S, r * S + k)], fill=(120, 120, 120))
                    d.line([(c * S + S - 1, r * S + k), (c * S + k, r * S + S - 1)], fill=(120, 120, 120))
    for x in range(fr.cols + 1):
        d.line([(x * S, 0), (x * S, fr.rows * S)], fill=(205, 205, 205))
    for y in range(fr.rows + 1):
        d.line([(0, y * S), (fr.cols * S, y * S)], fill=(205, 205, 205))
    draw_lines(hood, fr, im)
    f10 = TP.font(10)
    for f in hood.faces:                    # a face's name inside it where it fits (the key below names all)
        if f.view != name or (f.mirror is not None and f.mirror.index < f.index):
            continue
        cs = [fr.cont(p) for p in f.pts]
        cx, cy = sum(c[0] for c in cs) / len(cs) * S, sum(c[1] for c in cs) / len(cs) * S
        w = d.textlength(f.name, font=f10)
        box = (max(c[0] for c in cs) - min(c[0] for c in cs)) * S, (max(c[1] for c in cs) - min(c[1] for c in cs)) * S
        if w + 6 <= box[0] and box[1] >= 16:
            d.rectangle([cx - w / 2 - 1, cy - 6, cx + w / 2 + 1, cy + 5], fill=(255, 255, 255))
            d.text((cx - w / 2, cy - 6), f.name, fill=(20, 20, 20), font=f10)
    body = framed(im, fr.labels)
    mine = [f.name for f in hood.faces if f.view == name]
    body = vstack([body, swatch_key(hood, [f for f in hood.faces if f.view == name], name == "side")], gap=4)
    lines = [f"{name} view, {fr.cols}x{fr.rows} px, one pixel per skin pixel; {fr.title}; paint `{name}.png` "
             f"(this guide is {name}_{S}x.png). Edge labels: the character's directions.",
             f"faces painted here: {', '.join(mine)}" + (" (the left faces sample this view mirrored: one side "
                                                          "view paints both sides)" if name == "side" else ""),
             "TINTED pixels are sampled: paint every one with reference colours (templates/palette.png), opaque; "
             "each tint is one face (key below the view; as on templates/parts/" + hood.id + ".png), the DARKER "
             "tint = only bleed texels sample it (paint it like its neighbours). `project` refuses a pixel left "
             "tinted or transparent.",
             "GREY: the " + hood.shell_id + " shell (light) and the head (dark, dashed outline) for orientation; "
             "never sampled, like every pixel outside the tint. Magenta lines: the edges of the faces painted here; "
             "thin grey lines: faces seen from here but painted in another view; black: the hood's silhouette."]
    if other:
        lines.append("HATCHED: seen from here but painted in another view: " + "; ".join(
            f"{', '.join(sorted(v))} in the {k} view" for k, v in sorted(other.items())))
    return TP.compose_wrapped(f"{hood.id} - {name} view (paint guide)", lines, body)


def swatch_key(hood, faces, mirrored):
    """A row of each face's tint (and its darker bleed-only tint) with its name."""
    f11 = TP.font(11)
    items = [f for f in faces if not (mirrored and f.mirror is not None and f.mirror.index < f.index)]
    im = Image.new("RGB", (max(200, 150 * len(items) + 50), 18), (250, 249, 246))
    d = ImageDraw.Draw(im)
    x = 46
    for f in items:
        t = TINTS[f.index % len(TINTS)]
        d.rectangle([x, 3, x + 11, 14], fill=t, outline=(90, 90, 90))
        d.rectangle([x + 13, 3, x + 24, 14], fill=tuple(int(v * 0.78) for v in t), outline=(90, 90, 90))
        label = f.name + (f" + {f.mirror.name}" if mirrored and f.mirror is not None else "")
        d.text((x + 29, 3), label, fill=(20, 20, 20), font=f11)
        x += 150
    return im


def cmd_templates(hood, out):
    out.mkdir(parents=True, exist_ok=True)
    for name in VIEW_NAMES:
        one = template(hood, name)
        one.save(out / f"{name}.png")
        guide(hood, name, one).save(out / f"{name}_{S}x.png")
        print(f"{out / name}.png ({one.width}x{one.height}) and {name}_{S}x.png")


# ---------- preview ----------
def compare(hood, name, sheet, view):
    """The 1x round trip of a view: the projected sheet rendered from the view at its pixel centres against the
    painted view, on the pixels where a face painted in this view is in front. -> (compared, differing pixels)."""
    fr = hood.frames[name]
    owner, colour = raster(hood, fr, 1, sheet)
    vp = view.load()
    n, bad = 0, []
    for r in range(fr.rows):
        for c in range(fr.cols):
            f = owner[r][c]
            if f is None or f.kind != "hood" or f.view != name:
                continue
            n += 1
            if colour[r][c] != vp[c, r][:3]:
                bad.append((c, r))
    return n, bad


def preview(hood, sheet, views=None):
    rows = []
    for name in VIEW_NAMES:
        fr = hood.frames[name]
        _, colour = raster(hood, fr, S, sheet)
        res = to_image(colour, fr.cols * S, fr.rows * S)
        draw_lines(hood, fr, res)
        panels = []
        if views is not None:
            n, bad = compare(hood, name, sheet, views[name])
            pv = scaled(views[name], fr)
            draw_lines(hood, fr, pv)
            d = ImageDraw.Draw(res)
            for c, r in bad:
                d.rectangle([c * S, r * S, c * S + S - 1, r * S + S - 1], outline=(0, 200, 220), width=1)
            panels.append(caption(framed(pv, fr.labels), f"{name}: painted"))
            panels.append(caption(framed(res, fr.labels), f"{name}: the sheet rendered ({len(bad)} of {n} px differ)"))
        else:
            panels.append(caption(framed(res, fr.labels), f"{name}: the sheet rendered"))
        rows.append(hstack(panels))
    obl = []
    for label, E in (("back right, above", (-1.0, 0.8, -1.2)), ("back left, above", (1.0, 0.8, -1.2)),
                     ("front right, above", (-1.0, 0.9, 1.0))):
        fr = oblique_frame(hood, E)
        _, colour = raster(hood, fr, S, sheet, shade=True)
        obl.append(caption(to_image(colour, fr.cols * S, fr.rows * S), label))
    rows.append(hstack(obl))
    big = sheet.resize((sheet.width * S, sheet.height * S), Image.NEAREST)
    bg = Image.new("RGB", big.size)
    bp = bg.load()
    for y in range(bg.height):
        for x in range(bg.width):
            bp[x, y] = checker(x, y)
    bg.paste(big, mask=big.split()[3])
    d = ImageDraw.Draw(bg)
    for f in hood.faces:
        x, y, w, h = f.rect
        d.rectangle([x * S, y * S, (x + w) * S - 1, (y + h) * S - 1], outline=(40, 40, 40))
    rows.append(caption(bg, f"the sheet ({S}x)"))
    lines = ["Orthographic, flat colours (the three-quarter views lightly shaded), reference palette; the "
             f"{hood.shell_id} shell grey; magenta: a transparent texel. Lines as on the view guides."]
    if views is not None:
        lines.append("Cyan frames: pixels where the rendered sheet differs from the painted view (nearest sampling "
                     "between the view grid and the face texels; a few are expected, a pattern of them is not).")
    return TP.compose_wrapped(f"{hood.id} - preview", lines, vstack(rows))


# ---------- the example and the tests ----------
def paint_views(hood, rule):
    """A view set painted on every pixel by rule(view name, world point of the pixel centre, col, row) -> rgb."""
    out = {}
    for name in VIEW_NAMES:
        fr = hood.frames[name]
        im = Image.new("RGBA", (fr.cols, fr.rows))
        px = im.load()
        for r in range(fr.rows):
            for c in range(fr.cols):
                px[c, r] = tuple(rule(name, fr.base(c + 0.5, r + 0.5), c, r)) + (255,)
        out[name] = im
    return out


def demo_rule(name, p, c, r):
    """A plain example: zone A cloth, a dark centre stripe over the top and down the back, a band round the back
    and the sides, a zone B hem at the bottom edge."""
    x, y = p[0], p[1]
    if name != "top" and y < 24.0:
        return REF["B_LIGHT"]
    if name != "top" and y < 25.0:
        return REF["B_DARK"]
    if name != "top" and 29.0 <= y < 30.0:
        return REF["A_DARK"]
    if name != "side" and -1.0 <= x < 1.0:
        return REF["A_DARK"]
    return REF["A_LIGHT"]


def cmd_demo(hood, out):
    out.mkdir(parents=True, exist_ok=True)
    views = paint_views(hood, demo_rule)
    for name, im in views.items():
        im.save(out / f"{name}.png")
    sheet, problems = project(hood, views)
    assert not problems, problems
    sheet.save(out / f"{hood.id}_demo.png")
    preview(hood, sheet, views).save(out / "preview.png")
    print(f"{out}: side/back/top.png, {hood.id}_demo.png, preview.png")


def world_cells(fr, c, r):
    """{axis: whole skin pixel} of the view pixel (c, r) on the two axes its view shows."""
    out = {}
    for ax, v in ((fr.R, c), (fr.D, r)):
        k = next(i for i in range(3) if ax[i])
        o = int(round(fr.o[k]))
        out[k] = o + v if ax[k] > 0 else o - v - 1
    return out


def check_seams(hood, step=0.05):
    """Along every edge two faces share, at points `step` apart: the two texels that touch there (one on each
    face) sample view pixels within one skin pixel of the edge point on every axis their views show, and within
    one skin pixel of each other on every axis both views show (a pattern runs on across the edge). Uses a view
    set whose pixels encode their own coordinates. -> (points checked, failures, {offset between the two sides
    on a shared axis: count})."""
    enc = paint_views(hood, lambda name, p, c, r: (c, r, VIEW_NAMES.index(name) * 100))
    sheet, _ = project(hood, enc, strict=False)
    sp = sheet.load()
    edges = {}
    for f in hood.faces:
        idx = hood.part["faces"][f.index]["v"]
        for i in range(len(idx)):
            edges.setdefault(frozenset((idx[i], idx[(i + 1) % len(idx)])), []).append(f)
    fails, checked, spread = [], 0, {}
    for key, users in sorted(edges.items(), key=lambda e: sorted(e[0])):
        if len(users) != 2:
            continue                                    # an edge on the shell's surface
        A, B = (tuple(hood.part["vertices"][i]) for i in sorted(key))
        n = int(round(1 / step))
        for s in range(1, n):
            P = add(A, sub(B, A), s / n)
            at = f"{users[0].name}|{users[1].name} at {tuple(round(c, 2) for c in P)}"
            got = []
            for f in users:
                u, v = f.uv_of(P)
                cu, cv = sum(q[0] for q in f.uv) / len(f.uv), sum(q[1] for q in f.uv) / len(f.uv)
                tx, ty = int(math.floor(u + (cu - u) * 1e-4)), int(math.floor(v + (cv - v) * 1e-4))  # this face's
                rgb = sp[tx, ty][:3]
                cells = world_cells(hood.frames[VIEW_NAMES[rgb[2] // 100]], rgb[0], rgb[1])
                got.append(cells)
                for k, cell in cells.items():
                    if abs(cell - math.floor(P[k] + EPS)) > 1:
                        fails.append(f"{at}: {f.name} samples {'xyz'[k]} {cell - math.floor(P[k] + EPS):+d} px "
                                     "from the edge")
            checked += 1
            for k in set(got[0]) & set(got[1]):
                d = abs(got[0][k] - got[1][k])
                spread[d] = spread.get(d, 0) + 1
                if d > 1:
                    fails.append(f"{at}: the two sides sample {'xyz'[k]} {d} px apart")
    return checked, fails, spread


def selftest():
    hood = Hood()
    ok = True

    def report(name, good, detail=""):
        nonlocal ok
        ok &= bool(good)
        print(f"{'ok  ' if good else 'FAIL'} {name}" + (f": {detail}" if detail else ""))
    report("schema and views", True, "; ".join(f"{f.name} -> {f.view}" for f in hood.faces) + "; frames " +
           ", ".join(f"{n} {fr.cols}x{fr.rows}" for n, fr in hood.frames.items()))
    r = math.sqrt(0.5)
    rule = {(-1, 0, 0): "side", (1, 0, 0): "side", (0, 0, -1): "back", (0, 1, 0): "top", (0, 0, 1): None,
            (0, -1, 0): None, (-r, 0, -r): "side", (0, r, -r): "back", (r, r, 0): "side", (-0.6, 0.8, 0): "top"}
    wrong = [f"{n} -> {choose_view(n)}" for n, v in rule.items() if choose_view(n) != v]
    report("view rule", not wrong, "dominant axis, ties x before z before y, no view for front or down faces"
           + (": " + ", ".join(wrong) if wrong else ""))
    checked, fails, spread = check_seams(hood)
    report("seams", checked and not fails, f"{checked} points on the shared edges; the two sides sample "
           + ", ".join(f"{n} times {d} px apart" for d, n in sorted(spread.items())) + " on the shared axes"
           + (": " + "; ".join(fails[:6]) if fails else ""))
    # mirrored faces sample the same side-view pixels at mirrored points
    sm = hood.sample_map()
    bad, n = [], 0
    for f in hood.faces:
        if f.mirror is None or f.view != "side":
            continue
        for x, y in f.texels():
            p = hood.samples[(f.name, x, y)][0]
            u, v = f.mirror.uv_of((-p[0], p[1], p[2]))
            n += 1
            if sm[(f.mirror.name, int(math.floor(u)), int(math.floor(v)))] != sm[(f.name, x, y)]:
                bad.append(f"{f.name} ({x},{y})")
    report("mirror", n and not bad, f"{n} texels of mirrored side faces" + (": " + ", ".join(bad[:6]) if bad else ""))
    # a uniform view set gives a uniform sheet
    col = REF["A_LIGHT"]
    sheet, problems = project(hood, paint_views(hood, lambda *a: col))
    px = sheet.load()
    cells = {(x, y) for f in hood.faces for x, y in f.texels()}
    wrong = [(x, y) for y in range(sheet.height) for x in range(sheet.width)
             if px[x, y] != ((col + (255,)) if (x, y) in cells else (0, 0, 0, 0))]
    report("uniform", not problems and not wrong, f"{len(cells)} texels A_LIGHT, the rest transparent"
           + (f"; wrong at {wrong[:6]}" if wrong else ""))
    # refusals: the templates as they come, a transparent and an off-palette pixel
    tmpl = {name: template(hood, name) for name in VIEW_NAMES}
    _, problems = project(hood, tmpl)
    report("refuse the unpainted template", len(problems) == len(cells), f"{len(problems)} problems")
    views = paint_views(hood, lambda *a: col)
    c, r = next(iter(fill_area(hood, "back")))
    views["back"].putpixel((c, r), (0, 0, 0, 0))
    c2, r2 = next(iter(fill_area(hood, "side")))
    views["side"].putpixel((c2, r2), (1, 2, 3, 255))
    _, problems = project(hood, views)
    named = [q for q in problems if "transparent" in q][:1] + [q for q in problems if "#010203" in q][:1]
    report("refuse transparent and off-palette", len(named) == 2 and f"pixel ({c},{r})" in named[0]
           and all(" texel (" in q for q in problems), " / ".join(named))
    # round trip: random palette views, projected, rendered back from each view
    rnd = random.Random(56)
    pal = list(REF.values())
    views = paint_views(hood, lambda *a: pal[rnd.randrange(len(pal))])
    sheet, problems = project(hood, views)
    stats = {name: compare(hood, name, sheet, views[name]) for name in VIEW_NAMES}
    total = sum(n for n, _ in stats.values())
    diff = sum(len(b) for _, b in stats.values())
    report("round trip", not problems and total and diff <= 0.05 * total,
           ", ".join(f"{k} {len(b)}/{n}" for k, (n, b) in stats.items()) + " px differ (at most 5 % allowed)")
    # the projected sheet passes check.py in a copy of the test art
    with tempfile.TemporaryDirectory(prefix="hoodpaint-") as tmp:
        art = Path(tmp) / "art"
        shutil.copytree(ARMOR / "test_art", art)
        demo, _ = project(hood, paint_views(hood, demo_rule))
        for line in ("cloth", "leather"):
            sheet.save(art / line / f"{hood.id}_a.png")
        demo.save(art / "cloth" / f"{hood.id}_a.png")
        res = subprocess.run([sys.executable, str(ARMOR / "check.py"), "--art", str(art)], capture_output=True,
                             text=True, cwd=ARMOR)
        viol = [ln for ln in res.stdout.splitlines() if "VIOLATION" in ln]
        report("check.py", res.returncode == 0 and not viol,
               f"exit {res.returncode}, the projected sheets as cloth and leather hood_a.png in a copy of test_art"
               + (f"; {viol[:3]}" if viol else ""))
    print("selftest " + ("passed" if ok else "FAILED"))
    return 0 if ok else 1


def main():
    global S
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--selftest", action="store_true", help="run the tests")
    ap.add_argument("--part", default=str(PART), help="the polygon part's schema file (default: hood.json)")
    ap.add_argument("--scale", type=int, default=S, help=f"the guides' and the preview's scale (default {S})")
    sub_ = ap.add_subparsers(dest="cmd")
    p = sub_.add_parser("templates", help="the view templates to paint and their guides")
    p.add_argument("out")
    p = sub_.add_parser("project", help="project three painted views onto the sheet")
    p.add_argument("side")
    p.add_argument("back")
    p.add_argument("top")
    p.add_argument("-o", "--out", required=True, help="the sheet to write, e.g. hood_a.png")
    p = sub_.add_parser("preview", help="render a sheet from the three views (and compare with painted views)")
    p.add_argument("sheet")
    p.add_argument("--views", nargs=3, metavar=("SIDE", "BACK", "TOP"))
    p.add_argument("-o", "--out", default="preview.png")
    p = sub_.add_parser("demo", help="an example view set, its sheet and preview (test art)")
    p.add_argument("out")
    a = ap.parse_args()
    S = max(2, a.scale)
    if a.selftest:
        return selftest()
    if not a.cmd:
        ap.print_help()
        return 2
    hood = Hood(a.part)
    if a.cmd == "templates":
        cmd_templates(hood, Path(a.out))
    elif a.cmd == "project":
        sheet, problems = project(hood, load_views([a.side, a.back, a.top], hood))
        if problems:
            print(f"refused: {len(problems)} sample(s) not opaque reference colours (nothing written):")
            for ln in problems[:40]:
                print("  " + ln)
            if len(problems) > 40:
                print(f"  ... (+{len(problems) - 40})")
            return 1
        sheet.save(a.out)
        print(f"{a.out}: {hood.sheet[0]}x{hood.sheet[1]}, {sum(len(f.texels()) for f in hood.faces)} texels in "
              f"{len(hood.faces)} faces")
    elif a.cmd == "preview":
        sheet = Image.open(a.sheet).convert("RGBA")
        if sheet.size != hood.sheet:
            raise SystemExit(f"{a.sheet}: {sheet.width}x{sheet.height}, expected {hood.sheet[0]}x{hood.sheet[1]}")
        views = load_views(a.views, hood) if a.views else None
        preview(hood, sheet, views).save(a.out)
        print(a.out)
    elif a.cmd == "demo":
        cmd_demo(hood, Path(a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
