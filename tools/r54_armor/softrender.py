"""Pure-Python software renderer (Pillow + numpy) for render.py --engine soft.

The same scene as the chromium/three.js page in render.py: the skeleton with
the pivots of character.b3d, rest and walk pose (legs +-0.6 rad, arms opposite,
panel swing 0.06 + 1.2|leg| front / 0.06 + 1.1|leg| back), left limbs as
mirrored right ones, z rotations of the catalog, the race skin with the inner
paint, and the palette-swapped box sheets. Perspective camera (fov 30) with
the same positions; z-buffered, perspective-correct textured triangles with
nearest-neighbour texel lookup and an alpha test (alpha < 128 writes nothing);
back faces culled; flat per-face Lambert shading with the page's lights (sky
hemisphere 0.75 + directional 0.62 from the camera's upper left). Rendered at
SS x the cell size and box-filtered down. Deterministic.
"""
import math

import numpy as np
from PIL import Image

import armorlib as L

SS = 2                                    # supersampling factor
SKY = np.array([1.0, 1.0, 1.0])
GROUND = np.array([0x6A, 0x64, 0x58]) / 255.0
HEMI, SUN = 0.75, 0.62
FACES = ["top", "bottom", "right", "front", "left", "back"]


# ---------- matrices ----------
def T(x, y, z):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def R(axis, a):
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    if axis == "x":
        m[1, 1], m[1, 2], m[2, 1], m[2, 2] = c, -s, s, c
    elif axis == "y":
        m[0, 0], m[0, 2], m[2, 0], m[2, 2] = c, s, -s, c
    else:
        m[0, 0], m[0, 1], m[1, 0], m[1, 1] = c, -s, s, c
    return m


def Sc(x, y, z):
    return np.diag([x, y, z, 1.0])


def bone_frames(bones, stature, walk):
    """World matrix of each bone's frame (origin at its pivot), as the page builds them."""
    legA = 0.6 if walk else 0.0
    s = legA / 0.785
    rot = {"leg_r": legA, "leg_l": -legA, "arm_r": -s * 0.6, "arm_l": s * 0.6,
           "panel_f": -(0.06 + 1.2 * legA), "panel_b": 0.06 + 1.1 * legA, "head": 0.0}
    P = {k: np.array(v, float) for k, v in bones.items()}
    G = {"body": Sc(stature, stature, stature) @ T(*P["body"])}
    for n in ("head", "arm_r", "arm_l", "leg_r", "leg_l", "panel_f", "panel_b"):
        G[n] = G["body"] @ T(*(P[n] - P["body"])) @ R("x", rot[n])
    return G, P


def placements(G, P, bone, mirror, rot):
    """World matrices taking rest-pose model points of a box (right copy) to the world."""
    out = []
    targets = [(bone, False)]
    if mirror:
        targets.append(("body" if bone == "body" else bone.replace("_r", "_l"), True))
    pv = P[bone]
    for tb, mir in targets:
        m = G[tb] @ (Sc(-1, 1, 1) if mir else np.eye(4))
        if rot:
            axis, deg, o = rot
            o = np.array(o, float)
            m = m @ T(*(o - pv)) @ R(axis, math.radians(deg)) @ T(*(-o))
        else:
            m = m @ T(*(-pv))
        out.append(m)
    return out


# ---------- scene ----------
def quads(box, rects, tex):
    """[(4 local corners, 4 texel-space uv, rect, local normal, tex)] for the six faces."""
    out = []
    for face in FACES:
        rx, ry, rw, rh = rects[face]
        cs, uvs = [], []
        for u, v in ((0, 0), (1, 0), (1, 1), (0, 1)):
            cs.append(L.face_point(box, face, u, v))
            uvs.append((rx + u * rw, ry + v * rh))
        out.append((np.array(cs, float), np.array(uvs, float), (rx, ry, rw, rh),
                    np.array(L.FACE_NORMAL[face], float), tex))
    return out


def skin_rects(uv, dims):
    u, v = uv
    w, h, d = dims
    return {"top": (u + d, v, w, d), "bottom": (u + d + w, v, w, d), "right": (u, v + d, d, h),
            "front": (u + d, v + d, w, h), "left": (u + d + w, v + d, d, h), "back": (u + 2 * d + w, v + d, w, h)}


def build_scene(cat, tier, stature, walk):
    """World-space faces: list of (corners 4x3, uv 4x2, rect, world normal, tex array)."""
    G, P = bone_frames(cat["bones"], stature, walk)
    faces = []
    skin = np.asarray(tier["skin_img"].convert("RGBA"))
    items = [(b["box"], b["bone"], b["mirror"], None, skin_rects(b["uv"], b["dims"]), skin) for b in cat["body"]]
    for s in tier["boxes"]:
        W, H, D = (L.texels(s["box"][i + 3] - s["box"][i]) for i in range(3))
        items.append((s["box"], s["bone"], s["mirror"], s["rot"], L.sheet_faces(W, H, D),
                      np.asarray(s["img"].convert("RGBA"))))
    for box, bone, mirror, rot, rects, tex in items:
        for M in placements(G, P, bone, mirror, rot):
            nm = np.linalg.inv(M[:3, :3]).T
            for cs, uvs, rect, n, tx in quads(box, rects, tex):
                wc = (M[:3, :3] @ cs.T).T + M[:3, 3]
                wn = nm @ n
                wn /= np.linalg.norm(wn)
                faces.append((wc, uvs, rect, wn, tx))
    return faces


# ---------- rasteriser ----------
def camera(dirv, dist, w, h, target=(0.0, 17.5, 0.0), fov=30.0):
    """Perspective camera looking at `target` from `dist` along `dirv` (the
    Round 55 offhand render passes its own target and field of view)."""
    d = np.array(dirv, float)
    d /= np.linalg.norm(d)
    tgt = np.array(target, float)
    pos = tgt + d * dist
    f = tgt - pos
    f /= np.linalg.norm(f)
    r = np.cross(f, [0.0, 1.0, 0.0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    side = np.cross(d, [0.0, 1.0, 0.0])
    side /= np.linalg.norm(side)
    sun = d * 40 + side * 25 + np.array([0.0, 45.0, 0.0])
    sun /= np.linalg.norm(sun)
    return {"pos": pos, "f": f, "r": r, "u": u, "t": math.tan(math.radians(fov / 2)), "w": w, "h": h, "sun": sun}


def project(cam, p):
    rel = p - cam["pos"]
    zc = rel @ cam["f"]
    xc, yc = rel @ cam["r"], rel @ cam["u"]
    asp = cam["w"] / cam["h"]
    sx = (xc / zc) / (cam["t"] * asp)
    sy = (yc / zc) / cam["t"]
    return (sx + 1) * 0.5 * cam["w"], (1 - sy) * 0.5 * cam["h"], zc


def shade(cam, n):
    hemi = (GROUND + (SKY - GROUND) * (0.5 * n[1] + 0.5)) * HEMI
    return hemi + SUN * max(0.0, float(n @ cam["sun"]))


def raster_tri(color, zbuf, P, Z, UV, rect, tex, light):
    """P: 3x2 screen points, Z: camera depths, UV: 3x2 texel-space coords."""
    h, w = zbuf.shape
    x0, x1 = max(0, int(math.floor(P[:, 0].min()))), min(w - 1, int(math.ceil(P[:, 0].max())))
    y0, y1 = max(0, int(math.floor(P[:, 1].min()))), min(h - 1, int(math.ceil(P[:, 1].max())))
    if x0 > x1 or y0 > y1:
        return
    area = (P[1, 0] - P[0, 0]) * (P[2, 1] - P[0, 1]) - (P[1, 1] - P[0, 1]) * (P[2, 0] - P[0, 0])
    if abs(area) < 1e-9:
        return
    xs = np.arange(x0, x1 + 1) + 0.5
    ys = np.arange(y0, y1 + 1)[:, None] + 0.5

    def edge(a, b):
        return ((P[b, 0] - P[a, 0]) * (ys - P[a, 1]) - (P[b, 1] - P[a, 1]) * (xs - P[a, 0])) / area
    w0, w1, w2 = edge(1, 2), edge(2, 0), edge(0, 1)
    inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
    if not inside.any():
        return
    iz = w0 / Z[0] + w1 / Z[1] + w2 / Z[2]
    z = 1.0 / np.where(inside, iz, 1.0)
    u = (w0 * UV[0, 0] / Z[0] + w1 * UV[1, 0] / Z[1] + w2 * UV[2, 0] / Z[2]) * z
    v = (w0 * UV[0, 1] / Z[0] + w1 * UV[1, 1] / Z[1] + w2 * UV[2, 1] / Z[2]) * z
    rx, ry, rw, rh = rect
    tx = np.clip(np.floor(u).astype(np.int64), rx, rx + rw - 1)
    ty = np.clip(np.floor(v).astype(np.int64), ry, ry + rh - 1)
    texel = tex[ty, tx]
    zsub = zbuf[y0:y1 + 1, x0:x1 + 1]
    m = inside & (texel[..., 3] >= 128) & (z < zsub)
    if not m.any():
        return
    zsub[m] = z[m]
    csub = color[y0:y1 + 1, x0:x1 + 1]
    csub[m] = np.minimum(texel[..., :3][m] * light, 255.0)


def render_view(faces, cell, dist, bg):
    w, h = cell["w"] * SS, cell["h"] * SS
    cam = camera(cell["dir"], dist, w, h)
    color = np.empty((h, w, 3), float)
    color[:] = bg
    zbuf = np.full((h, w), np.inf)
    for wc, uvs, rect, n, tex in faces:
        centre = wc.mean(axis=0)
        if n @ (cam["pos"] - centre) <= 0:         # back face
            continue
        pts = [project(cam, p) for p in wc]
        if min(p[2] for p in pts) < 1.0:
            continue
        S = np.array([[p[0], p[1]] for p in pts])
        Z = np.array([p[2] for p in pts])
        light = shade(cam, n) / 1.0
        for a, b, c in ((0, 1, 2), (0, 2, 3)):
            raster_tri(color, zbuf, S[[a, b, c]], Z[[a, b, c]], uvs[[a, b, c]], rect, tex, light)
    img = Image.fromarray(np.clip(color + 0.5, 0, 255).astype(np.uint8), "RGB")
    return img.reduce(SS) if SS > 1 else img


def render(cat, tiers, cells, W, H, dist, stature, bg):
    out = Image.new("RGB", (W, H), tuple(bg))
    scenes = {}
    for c in cells:
        key = (c["tier"], c["walk"])
        if key not in scenes:
            scenes[key] = build_scene(cat, tiers[c["tier"]], stature, c["walk"])
        out.paste(render_view(scenes[key], c, dist, np.array(bg, float)), (c["x"], c["y"]))
    return out
