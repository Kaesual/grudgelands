"""The offhand parts of the character models (Round 55 lane MODEL,
round55-plan.md §4 MODEL; the contract is docs/technical/offhand-format.md
and tools/r55_offhand/offhand.py, imported here, never copied).

Geometry and key maths for gen_cloak_model.py, all in the ARMOR CATALOG
FRAME at rest (skin pixels, right-handed, x = the character's left, y up,
z forward; armor-format.md §1); gen_cloak_model.py converts to the model
(to_model, one x flip, so it reverses every triangle) and writes the B3D.

  * the shield, one copy per size step (format doc §3.1, UVs §4);
  * the open book's six boxes (§3.2, UVs §4);
  * the two back cards (§3.3) and the two cloak wings (§3.4, UVs §6);
  * a bone key's rotation and translation at a clip frame (§2.3) and the
    quaternion helpers the steadiness needs.

A part is a list of vertices (position, normal, uv), triangles and a label
per vertex. Every face is wound so that cross(v1 - v0, v2 - v0) points
along its outward normal (in this right-handed frame); `face` asserts it per
triangle, and each part proves its normals outward on its own (a closed
shield copy has a positive volume, a convex box or prism has every face
normal pointing away from its centre).

Pure Python 3, no third-party module.
"""
import math
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools/r55_offhand"))
import offhand as oh  # noqa: E402  (the contract)

FACES = oh.FACES
FACE_NORMAL = {"front": (0, 0, 1), "back": (0, 0, -1), "right": (-1, 0, 0), "left": (1, 0, 0),
               "top": (0, 1, 0), "bottom": (0, -1, 0)}
WING_TEX = oh.WINGS_SIZE      # 16 x 32: the left half the outer face, the right the lining


# --- small vector maths ------------------------------------------------------------
def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def scale(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(a):
    n = math.sqrt(dot(a, a))
    return scale(a, 1.0 / n)


def mat_vec(m, v):
    """A 3x3 matrix (rows) times a column vector."""
    return tuple(m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] for i in range(3))


def transpose(m):
    return tuple(tuple(m[j][i] for j in range(3)) for i in range(3))


mat_mul = oh.mat_mul


# --- quaternions (w, x, y, z), standard: q acts on column vectors as R(q) -----------
def quat_from_matrix(m):
    """The unit quaternion of a 3x3 rotation matrix (rows), w >= 0."""
    tr = m[0][0] + m[1][1] + m[2][2]
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        q = (0.25 * s, (m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s)
    elif m[0][0] > m[1][1] and m[0][0] > m[2][2]:
        s = math.sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2
        q = ((m[2][1] - m[1][2]) / s, 0.25 * s, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s)
    elif m[1][1] > m[2][2]:
        s = math.sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2
        q = ((m[0][2] - m[2][0]) / s, (m[0][1] + m[1][0]) / s, 0.25 * s, (m[1][2] + m[2][1]) / s)
    else:
        s = math.sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2
        q = ((m[1][0] - m[0][1]) / s, (m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, 0.25 * s)
    n = math.sqrt(sum(c * c for c in q))
    q = tuple(c / n for c in q)
    return q if q[0] >= 0 else tuple(-c for c in q)


def quat_matrix(q):
    w, x, y, z = q
    return ((1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)),
            (2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)),
            (2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)))


def quat_mean(quats):
    """The normalized mean of unit quaternions, each turned to the first's
    hemisphere (the same rotation either sign)."""
    ref = quats[0]
    acc = [0.0, 0.0, 0.0, 0.0]
    for q in quats:
        sign = 1 if sum(a * b for a, b in zip(q, ref)) >= 0 else -1
        for i in range(4):
            acc[i] += sign * q[i]
    n = math.sqrt(sum(c * c for c in acc))
    return tuple(c / n for c in acc)


def slerp(a, b, t):
    """Spherical interpolation along the shorter arc."""
    d = sum(x * y for x, y in zip(a, b))
    if d < 0:
        b, d = tuple(-c for c in b), -d
    if d > 0.9995:
        return unitq(tuple(x + (y - x) * t for x, y in zip(a, b)))
    th = math.acos(d)
    sa, sb = math.sin((1 - t) * th) / math.sin(th), math.sin(t * th) / math.sin(th)
    return tuple(x * sa + y * sb for x, y in zip(a, b))


def unitq(q):
    n = math.sqrt(sum(c * c for c in q))
    return tuple(c / n for c in q)


# --- a part --------------------------------------------------------------------------
class Part:
    """Vertices (position, normal, uv), triangles and a label per vertex, in
    the catalog frame."""

    def __init__(self):
        self.verts, self.tris, self.labels = [], [], []
        self.pieces = []          # vertex index lists, each a convex piece (the clearance report)

    def piece(self, start):
        """Mark the vertices from `start` on as one convex piece."""
        self.pieces.append(list(range(start, len(self.verts))))

    def face(self, label, pts, uvs, normal):
        """A flat convex polygon, fanned from its first point; each triangle
        wound so cross(v1 - v0, v2 - v0) points along `normal`."""
        base = len(self.verts)
        for p, uv in zip(pts, uvs):
            self.verts.append((tuple(p), tuple(normal), tuple(uv)))
            self.labels.append(label)
        for i in range(1, len(pts) - 1):
            c = cross(sub(pts[i], pts[0]), sub(pts[i + 1], pts[0]))
            d = dot(c, normal)
            if abs(d) < 1e-9:
                raise SystemExit("offhand_model: degenerate triangle on %s" % label)
            self.tris.append((base, base + i, base + i + 1) if d > 0 else (base, base + i + 1, base + i))

    def extend(self, other):
        base = len(self.verts)
        self.verts += other.verts
        self.labels += other.labels
        self.tris += [tuple(base + i for i in t) for t in other.tris]
        self.pieces += [[base + i for i in piece] for piece in other.pieces]

    def mapped(self, point, direction):
        """A copy with every position through `point` and every normal
        through `direction` (a rigid motion or a uniform scale with it)."""
        out = Part()
        out.verts = [(point(p), unit(direction(n)), uv) for p, n, uv in self.verts]
        out.tris, out.labels, out.pieces = list(self.tris), list(self.labels), list(self.pieces)
        return out


def plane_normal(pts, hint):
    """The unit normal of a flat polygon, on the side of `hint`."""
    n = unit(cross(sub(pts[1], pts[0]), sub(pts[2], pts[0])))
    return n if dot(n, hint) > 0 else scale(n, -1)


def signed_volume(part):
    """Six times the enclosed volume: positive for a closed mesh wound outward."""
    return sum(dot(part.verts[a][0], cross(part.verts[b][0], part.verts[c][0])) for a, b, c in part.tris)


def assert_away_from(part, centre, what):
    """Every face normal of a convex piece points away from its centre."""
    for a, b, c in part.tris:
        mid = scale(add(add(part.verts[a][0], part.verts[b][0]), part.verts[c][0]), 1 / 3)
        if dot(part.verts[a][1], sub(mid, centre)) <= 0:
            raise SystemExit("offhand_model: %s has an inward face" % what)


def placed(placement, size=1.0):
    """(point, direction) maps of an item placement (format doc §2.2)."""
    r = oh.euler(placement["rot"], placement["order"])
    return (lambda p: oh.place(placement, p, size)), (lambda n: mat_vec(r, n))


def atlas_uv(atlas, rect, col, row):
    """An atlas UV at (col, row) in 0..1 across a face rectangle."""
    aw, ah = atlas["size"]
    x, y, w, h = rect
    return ((x + col * w) / aw, (y + row * h) / ah)


def inset(rect, col, row):
    """(col, row) moved half a texel into the rectangle: a strip that takes a
    face's border texels (the shield rim, the wing edges) samples their
    centres, never the neighbouring sheet."""
    _, _, w, h = rect
    return (min(max(col, 0.5 / w), 1 - 0.5 / w), min(max(row, 0.5 / h), 1 - 0.5 / h))


# --- the shield (§3.1, §4) -----------------------------------------------------------
def shield_copy(params, atlas, step):
    """One size copy, placed at rest; label shield_<step>."""
    sh = params["shield"]
    shape, boss = sh["shape"], sh.get("boss")
    out, lv = oh.shield_outline(shape)
    W, T, B, H = lv["W"], lv["T"], lv["B"], shape["height"]
    thick = shape["thick"]
    faces = atlas["sheets"]["shield_%d" % step]["faces"]
    label = "shield_%d" % step

    def front_z(x):
        return oh.shield_front_z(shape, x)

    def uv_front(x, y, rim=False):
        col, row = (x + W) / (2 * W), (T - y) / H
        if rim:
            col, row = inset(faces["front"], col, row)
        return atlas_uv(atlas, faces["front"], col, row)

    def uv_back(x, y):
        return atlas_uv(atlas, faces["back"], (W - x) / (2 * W), (T - y) / H)

    part = Part()
    # the outline is clockwise seen from the front, from the top left
    halves = ([out[1], out[2], out[3], out[4], out[5]],     # x >= 0
              [out[1], out[0], out[7], out[6], out[5]])     # x <= 0
    for half in halves:
        start = len(part.verts)
        pts = [(x, y, front_z(x)) for x, y in half]
        part.face(label, pts, [uv_front(x, y) for x, y in half], plane_normal(pts, (0, 0, 1)))
        pts = [(x, y, front_z(x) - thick) for x, y in half]
        part.face(label, pts, [uv_back(x, y) for x, y in half], plane_normal(pts, (0, 0, -1)))
        part.piece(start)
    for i in range(len(out)):
        (x0, y0), (x1, y1) = out[i], out[(i + 1) % len(out)]
        pts = [(x0, y0, front_z(x0)), (x1, y1, front_z(x1)),
               (x1, y1, front_z(x1) - thick), (x0, y0, front_z(x0) - thick)]
        uvs = [uv_front(x0, y0, True), uv_front(x1, y1, True), uv_front(x1, y1, True), uv_front(x0, y0, True)]
        # clockwise outline: the outward side of an edge (dx, dy) is (-dy, dx)
        part.face(label, pts, uvs, plane_normal(pts, (-(y1 - y0), x1 - x0, 0)))
    if signed_volume(part) <= 0:
        raise SystemExit("offhand_model: the shield is wound inward")
    if boss:
        r = boss["radius"]
        by = (T + B) / 2 + boss["lift"] * (T - (T + B) / 2)
        base = [(-r, by - r), (r, by - r), (r, by + r), (-r, by + r)]
        apex = (0.0, by, front_z(0) + boss["height"])
        cone = Part()
        for i in range(4):
            (x0, y0), (x1, y1) = base[i], base[(i + 1) % 4]
            pts = [(x0, y0, front_z(x0)), (x1, y1, front_z(x1)), apex]
            hint = ((x0 + x1) / 2, (y0 + y1) / 2 - by, 0)
            cone.face(label, pts, [uv_front(x0, y0), uv_front(x1, y1), uv_front(0.0, by)],
                      plane_normal(pts, hint))
        assert_away_from(cone, (0.0, by, front_z(r)), "the shield boss")
        cone.piece(0)
        part.extend(cone)
    point, direction = placed(sh["place"], sh["sizes"][step])
    return part.mapped(point, direction)


# --- the book (§3.2, §4) -------------------------------------------------------------
def book(params, atlas, face_point):
    """The open book placed at rest; labels book_<box>. `face_point` is
    armor-format.md §4's face orientation (gen_cloak_model.face_point)."""
    bk = params["book"]
    boxes = oh.book_boxes(bk["shape"], bk["ribbon"])
    point, direction = placed(bk["place"])
    part = Part()
    for box_id in oh.BOOK_BOXES:
        box = boxes[box_id]
        faces = atlas["sheets"][box_id]["faces"]
        if set(faces) != set(FACES) - set(oh.BOOK_SKIP.get(box_id, ())):
            raise SystemExit("offhand_model: atlas faces of %s do not match the format doc" % box_id)
        turn = oh.euler([0, oh.book_turn(bk["shape"], box_id), 0], "Y")
        piece = Part()
        for face in FACES:
            if face not in faces:
                continue
            corners = ((0, 0), (1, 0), (1, 1), (0, 1))
            pts = [face_point(box, face, u, v) for u, v in corners]
            piece.face("book_" + box_id, pts, [atlas_uv(atlas, faces[face], u, v) for u, v in corners],
                       FACE_NORMAL[face])
        x0, y0, z0, x1, y1, z1 = box
        assert_away_from(piece, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), "book " + box_id)
        piece.piece(0)
        part.extend(piece.mapped(lambda p, t=turn: mat_vec(t, p), lambda n, t=turn: mat_vec(t, n)))
    return part.mapped(point, direction)


# --- the back cards (§3.3) -------------------------------------------------------------
BACK_U = {"cloak": (0.0, 0.5), "body": (0.5, 1.0)}   # each card's half of the 32 x 16 back texture


def back_card(params, gap, card):
    """The `card` ("cloak" or "body") at rest: two triangle pairs, each `gap`
    px off the card's plane to its own side; the side facing the card's +z
    shows the image unmirrored, from its half of the back texture. Label
    back_<card>."""
    half = params["back"]["size"] / 2
    u0, u1 = BACK_U[card]
    corners = (((-half, half), (u0, 0)), ((half, half), (u1, 0)), ((half, -half), (u1, 1)),
               ((-half, -half), (u0, 1)))
    part = Part()
    for side in (1, -1):
        part.face("back_" + card, [(x, y, side * gap) for (x, y), _ in corners], [uv for _, uv in corners],
                  (0, 0, side))
    part.piece(0)
    point, direction = placed(params["back"][card])
    return part.mapped(point, direction)


# --- the wings (§3.4, §6) --------------------------------------------------------------
def wings(params, cloak_x, mid_z, hem_y, top_y):
    """Both wings at rest: the hinge line at z = mid_z from hem_y up to
    top_y - drop, inset into the cloak (side faces at x = +-cloak_x) by
    e = thick / 2 * sin(angle) + 0.05 px (offhand.wing_hinge_x), the outer
    corner width + e out from the hinge's bottom; labels wing_l (the
    character's left, +x) and wing_r, the mirror image showing the same
    texels."""
    w = params["wings"]
    if abs(cloak_x - oh.CLOAK_HALF_W) > 1e-9:
        raise SystemExit("offhand_model: the cloak's half-width differs from offhand.CLOAK_HALF_W")
    hinge_x = oh.wing_hinge_x(w)
    span = w["width"] + (cloak_x - hinge_x)
    y0, y1 = hem_y, top_y - w["drop"]
    tw, th = WING_TEX
    outer_rect = (0, 0, tw // 2, th)          # in texels of the 16 x 32 image

    def uv(a, b, lining=False, edge=False):
        """a: 0 at the hinge .. 1 at the outer corner; b: 0 at the top .. 1 at the hem."""
        if lining:
            return ((tw / 2 + a * tw / 2) / tw, b)
        col, row = 1 - a, b                    # in the outer face's half
        if edge:
            col, row = inset(outer_rect, col, row)
        return (col * (tw / 2) / tw, row)

    # the left wing before the turn: corners (a, b) and their points
    corners = ((0.0, 0.0), (0.0, 1.0), (1.0, 1.0))      # hinge top, hinge bottom, outer corner

    def at(a, b, dz):
        return (hinge_x + a * span, y1 - b * (y1 - y0), mid_z + dz)
    out_z, in_z = -w["thick"] / 2, w["thick"] / 2
    left = Part()
    left.face("wing_l", [at(a, b, out_z) for a, b in corners], [uv(a, b) for a, b in corners], (0, 0, -1))
    left.face("wing_l", [at(a, b, in_z) for a, b in corners], [uv(a, b, True) for a, b in corners], (0, 0, 1))
    # the triangle's centre in its plane; the two edge quads face away from it
    centre = ((3 * hinge_x + span) / 3, (y1 + 2 * y0) / 3, mid_z)
    for (a0, b0), (a1, b1) in ((corners[1], corners[2]), (corners[2], corners[0])):
        pts = [at(a0, b0, out_z), at(a1, b1, out_z), at(a1, b1, in_z), at(a0, b0, in_z)]
        uvs = [uv(a0, b0, edge=True), uv(a1, b1, edge=True), uv(a1, b1, edge=True), uv(a0, b0, edge=True)]
        mid = at((a0 + a1) / 2, (b0 + b1) / 2, 0)
        left.face("wing_l", pts, uvs, plane_normal(pts, (mid[0] - centre[0], mid[1] - centre[1], 0)))
    assert_away_from(left, centre, "the left wing")
    left.piece(0)
    # turned about the hinge line so the outer edge moves forward (+z)
    turn = oh.euler([0, -w["angle"], 0], "Y")
    hinge = (hinge_x, 0.0, mid_z)
    left = left.mapped(lambda p: add(hinge, mat_vec(turn, sub(p, hinge))), lambda n: mat_vec(turn, n))
    right = left.mapped(lambda p: (-p[0], p[1], p[2]), lambda n: (-n[0], n[1], n[2]))
    right.labels = ["wing_r"] * len(right.labels)
    # the mirror turns every triangle over: wind them outward again
    right.tris = [(a, c, b) for a, b, c in right.tris]
    both = Part()
    both.extend(left)
    both.extend(right)
    return both


# --- bone keys (§2.3) ----------------------------------------------------------------
def entry_at(entry, i, period):
    """(rot, pos) of a clip entry at clip frame i: a static entry as it is,
    keyed entries linear per component, wrapping over `period` for a looping
    clip (None: a one-shot holds its last key), as gen_cloak_model.spec_angle."""
    if "keys" not in entry:
        return list(entry.get("rot", [0, 0, 0])), list(entry.get("pos", [0, 0, 0]))
    keys = [[k["frame"]] + list(k.get("rot", [0, 0, 0])) + list(k.get("pos", [0, 0, 0]))
            for k in entry["keys"]]
    if len(keys) == 1:
        row = keys[0]
    else:
        frame = i
        if period:
            frame = frame % period
            if frame < keys[0][0]:
                frame += period
            keys = keys + [[keys[0][0] + period] + keys[0][1:]]
        row = keys[-1] if not period and frame >= keys[-1][0] else keys[0]
        for a, b in zip(keys, keys[1:]):
            if a[0] <= frame <= b[0]:
                t = (frame - a[0]) / (b[0] - a[0])
                row = [a[k] + (b[k] - a[k]) * t for k in range(len(a))]
                break
    return row[1:4], row[4:7]
