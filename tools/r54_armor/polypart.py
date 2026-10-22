"""Polygon parts of the armor catalog (Round 56, docs/technical/armor-format.md §1a).

A polygon part is a set of convex planar faces on one bone, in the catalog frame (skin pixels, rest pose,
absolute coordinates; right-handed, the character's right at -x). Its schema file (the first: the hood,
tools/r56_hood/hood.json, exported by the hood workshop page) gives `vertices`, `faces` (vertex indices
counter-clockwise seen from outside, per-vertex `uv` in sheet texels, the face's `rect`) and the `sheet` size.

  load(path)               the schema file as a dict
  validate(part, shell)    the §1a invariants -> list of problems (export.py --check fails on any)
  entry(part, ...)         the part as data/catalog.json carries it
  face_frame(normal)       the unwrap's (right, up) directions of a face (§1a "Unwrap")
"""
import json
import math
from pathlib import Path

FORMAT = "grudgelands-armor-poly 1"
PLANAR = 0.001          # px: a face's vertices off its plane
EPS = 1e-3              # px / texels: coordinates on a plane, UVs on a rect edge
HORIZONTAL = 0.954      # |normal y| above it: a top or bottom face (about 17.5 degrees, §1a)


# ---------- small vector maths ----------
def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(a):
    n = math.sqrt(dot(a, a))
    return (a[0] / n, a[1] / n, a[2] / n)


def texels(size):
    """Texel count for an extent of `size` skin pixels (armorlib.texels)."""
    return max(1, int(math.floor(size + 0.5)))


# ---------- faces ----------
def points(part, face):
    return [tuple(float(c) for c in part["vertices"][i]) for i in face["v"]]


def newell(pts):
    """The unit normal of a polygon by Newell's method: counter-clockwise seen from where it points."""
    n = [0.0, 0.0, 0.0]
    for i, p in enumerate(pts):
        q = pts[(i + 1) % len(pts)]
        n[0] += (p[1] - q[1]) * (p[2] + q[2])
        n[1] += (p[2] - q[2]) * (p[0] + q[0])
        n[2] += (p[0] - q[0]) * (p[1] + q[1])
    length = math.sqrt(dot(n, n))
    return None if length < 1e-12 else (n[0] / length, n[1] / length, n[2] / length)


def face_frame(n):
    """(right, up) of a face with outward unit normal n, seen from outside: up is world +y projected into the
    face; a near-horizontal face takes the back edge (a top face) or the front edge (a bottom face) as up."""
    if n[1] > HORIZONTAL:
        ref = (0.0, 0.0, -1.0)
    elif n[1] < -HORIZONTAL:
        ref = (0.0, 0.0, 1.0)
    else:
        ref = (0.0, 1.0, 0.0)
    k = dot(ref, n)
    up = unit((ref[0] - k * n[0], ref[1] - k * n[1], ref[2] - k * n[2]))
    return cross(up, n), up


def uv_map(pts, uvs, right, up):
    """The affine map (right, up) -> (u, v) of the fan triangles from the first vertex, as
    [[du/dr, du/du], [dv/dr, dv/du]] per triangle (None for a degenerate one)."""
    out = []
    for i in range(1, len(pts) - 1):
        e1, e2 = sub(pts[i], pts[0]), sub(pts[i + 1], pts[0])
        a = ((dot(e1, right), dot(e2, right)), (dot(e1, up), dot(e2, up)))
        det = a[0][0] * a[1][1] - a[0][1] * a[1][0]
        if abs(det) < 1e-9:
            out.append(None)
            continue
        inv = ((a[1][1] / det, -a[0][1] / det), (-a[1][0] / det, a[0][0] / det))
        d = [[uvs[i][k] - uvs[0][k], uvs[i + 1][k] - uvs[0][k]] for k in range(2)]
        out.append([[d[k][0] * inv[0][j] + d[k][1] * inv[1][j] for j in range(2)] for k in range(2)])
    return out


def on_shell(p, box):
    """The helm-box face planes (axis, value) the point p lies on (inside that face's rectangle)."""
    out = []
    for k in range(3):
        for c in (box[k], box[k + 3]):
            if abs(p[k] - c) < EPS and all(box[i] - EPS <= p[i] <= box[i + 3] + EPS for i in range(3) if i != k):
                out.append((k, c))
    return out


def poly2d(pts, n):
    """Points of a planar polygon in 2D coordinates of its plane."""
    right, up = face_frame(n)
    return [(dot(p, right), dot(p, up)) for p in pts]


def overlap2d(a, b):
    """Do two convex 2D polygons overlap with positive area (separating-axis test)?"""
    for poly in (a, b):
        for i in range(len(poly)):
            e = (poly[(i + 1) % len(poly)][0] - poly[i][0], poly[(i + 1) % len(poly)][1] - poly[i][1])
            axis = (-e[1], e[0])
            sa = [q[0] * axis[0] + q[1] * axis[1] for q in a]
            sb = [q[0] * axis[0] + q[1] * axis[1] for q in b]
            if min(max(sa), max(sb)) - max(min(sa), min(sb)) <= 1e-6 * math.hypot(*axis):
                return False
    return True


# ---------- the schema file ----------
def load(path):
    return json.loads(Path(path).read_text())


def validate(part, shell):
    """The §1a invariants of a schema file; `shell` is the closing box [x0, y0, z0, x1, y1, z1] (the helm).
    Returns a list of problems (empty: valid)."""
    errs = []
    pid = part.get("id", "?")

    def bad(msg):
        errs.append(f"{pid}: {msg}")
    if part.get("format") != FORMAT:
        bad(f"format {part.get('format')!r}, expected {FORMAT!r}")
    V = part.get("vertices") or []
    faces = part.get("faces") or []
    sw, sh = part.get("sheet") or (0, 0)
    if not V or not faces:
        bad("no vertices or no faces")
        return errs
    names = [f.get("name") for f in faces]
    if len(set(names)) != len(names):
        bad("face names are not unique")
    normals, flat = {}, {}
    for f in faces:
        name = f["name"]
        idx = f["v"]
        if len(idx) < 3 or len(set(idx)) != len(idx) or any(not 0 <= i < len(V) for i in idx):
            bad(f"{name}: needs at least 3 distinct valid vertex indices")
            continue
        if len(f.get("uv", [])) != len(idx):
            bad(f"{name}: one uv per vertex")
            continue
        pts = points(part, f)
        n = newell(pts)
        if n is None:
            bad(f"{name}: degenerate (no area)")
            continue
        normals[name] = n
        c = tuple(sum(p[k] for p in pts) / len(pts) for k in range(3))
        off = max(abs(dot(sub(p, c), n)) for p in pts)
        if off > PLANAR:
            bad(f"{name}: not planar ({off:.4f} px off its plane, at most {PLANAR})")
        for i in range(len(pts)):
            a, b, q = pts[i - 1], pts[i], pts[(i + 1) % len(pts)]
            if dot(cross(sub(b, a), sub(q, b)), n) <= 1e-9:
                bad(f"{name}: not strictly convex at vertex {idx[i]}")
                break
        if all(on_shell(p, shell) for p in pts):
            planes = set.intersection(*(set(on_shell(p, shell)) for p in pts))
            if planes:
                bad(f"{name}: lies on the {part.get('shell', 'shell')}'s surface (such faces are not emitted)")
        # unwrap: rect inside the sheet, UVs inside the rect, orientation, texel size
        x, y, w, h = f["rect"]
        if x < 0 or y < 0 or x + w > sw or y + h > sh or w < 1 or h < 1:
            bad(f"{name}: rect {f['rect']} outside the {sw}x{sh} sheet")
        for (u, v), i in zip(f["uv"], idx):
            if not (x - EPS <= u <= x + w + EPS and y - EPS <= v <= y + h + EPS):
                bad(f"{name}: uv ({u}, {v}) of vertex {i} outside its rect {f['rect']}")
        right, up = face_frame(n)
        for m in uv_map(pts, f["uv"], right, up):
            if m is None:
                bad(f"{name}: a degenerate fan triangle")
            elif not (m[0][0] > 0 and m[1][1] < 0 and abs(m[0][0]) >= abs(m[0][1]) and abs(m[1][1]) >= abs(m[1][0])):
                bad(f"{name}: unwrap orientation (u must run to the viewer's right, v down, seen from outside)")
                break
        ext = [max(dot(p, d) for p in pts) - min(dot(p, d) for p in pts) for d in (right, up)]
        if (w, h) != (texels(ext[0]), texels(ext[1])):
            bad(f"{name}: rect {w}x{h} texels, its extent {ext[0]:.3f} x {ext[1]:.3f} px gives "
                f"{texels(ext[0])}x{texels(ext[1])}")
        flat[name] = (pts, n, dot(c, n))
    # rectangles disjoint
    for i, a in enumerate(faces):
        for b in faces[i + 1:]:
            ax, ay, aw, ah = a["rect"]
            bx, by, bw, bh = b["rect"]
            if ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah:
                bad(f"rects of {a['name']} and {b['name']} overlap")
    # coplanar faces must not overlap
    for i, a in enumerate(faces):
        for b in faces[i + 1:]:
            if a["name"] not in flat or b["name"] not in flat:
                continue
            pa, na, da = flat[a["name"]]
            pb, nb, db = flat[b["name"]]
            if abs(dot(na, nb)) > 1 - 1e-6 and abs(da - dot(nb, na) * db) < EPS:
                if overlap2d(poly2d(pa, na), poly2d(pb, na)):
                    bad(f"{a['name']} and {b['name']} are coplanar and overlap")
    # closed shell: every edge shared by two faces (once each way) or on the shell's surface
    edges = {}
    for f in faces:
        idx = f["v"]
        for i in range(len(idx)):
            edges.setdefault((idx[i], idx[(i + 1) % len(idx)]), []).append(f["name"])
    for (a, b), users in sorted(edges.items()):
        if len(users) > 1:
            bad(f"edge {a}-{b} runs the same way in {', '.join(users)} (inconsistent winding)")
        if (b, a) in edges:
            continue
        pa, pb = tuple(V[a]), tuple(V[b])
        if not set(on_shell(pa, shell)) & set(on_shell(pb, shell)):
            bad(f"edge {a}-{b} of {users[0]} is open (not shared by two faces, not on the shell's surface)")
    # winding outward: per connected group of faces, the signed volume about the shell's centre is positive
    centre = tuple((shell[k] + shell[k + 3]) / 2 for k in range(3))
    group = {f["name"]: f["name"] for f in faces}

    def root(x):
        while group[x] != x:
            x = group[x]
        return x
    by_edge = {}
    for f in faces:
        idx = f["v"]
        for i in range(len(idx)):
            by_edge.setdefault(frozenset((idx[i], idx[(i + 1) % len(idx)])), []).append(f["name"])
    for users in by_edge.values():
        for u in users[1:]:
            group[root(u)] = root(users[0])
    volume = {}
    for f in faces:
        pts = [sub(p, centre) for p in points(part, f)]
        vol = sum(dot(pts[0], cross(pts[i], pts[i + 1])) for i in range(1, len(pts) - 1))
        volume[root(f["name"])] = volume.get(root(f["name"]), 0.0) + vol
    for g, vol in volume.items():
        if vol <= 0:
            bad(f"faces around {g}: wound inward (signed volume {vol / 6:.2f} px^3 about the shell's centre)")
    # symmetry about x = 0
    mirror = {}
    for i, p in enumerate(V):
        j = next((j for j, q in enumerate(V) if abs(q[0] + p[0]) < EPS and abs(q[1] - p[1]) < EPS
                  and abs(q[2] - p[2]) < EPS), None)
        if j is None:
            bad(f"vertex {i} {p} has no mirror image in x")
        mirror[i] = j
    if None not in mirror.values():
        sets = {frozenset(f["v"]) for f in faces}
        for f in faces:
            if frozenset(mirror[i] for i in f["v"]) not in sets:
                bad(f"{f['name']}: no mirrored face")
    return errs


def entry(part, area, label, label_en, shell, source):
    """The part as data/catalog.json carries it: the box keys the sheet tools read (`faces` = name -> rect on the
    sheet, `sheet`, slot, bone, mirror) and its geometry (`vertices`, `polys` with the outward normal)."""
    polys = []
    for f in part["faces"]:
        n = newell(points(part, f))
        polys.append({"name": f["name"], "piece": f.get("piece"), "v": list(f["v"]),
                      "uv": [[round(u, 4), round(v, 4)] for u, v in f["uv"]], "rect": list(f["rect"]),
                      "normal": [round(c, 6) + 0.0 for c in n]})
    return {"id": part["id"], "label": label, "label_en": label_en, "area": area, "slot": part["slot"],
            "bone": part["bone"], "kind": "poly", "shell": shell, "mirror": False, "source": source,
            "vertices": [[round(c, 4) for c in p] for p in part["vertices"]], "sheet": list(part["sheet"]),
            "faces": {p["name"]: p["rect"] for p in polys}, "polys": polys}
