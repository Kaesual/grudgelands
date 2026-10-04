#!/usr/bin/env python3
"""Build the player model with a cloak (Round 33 lane C3, round33-plan.md
§2.10; rules in docs/design/character_visuals.md §5b).

The cloak is the technique VoxeLibre's capes use (mcl_armor_character.b3d: a
thin box behind the body on its own `Cape` bone under the body, keyed per
animation frame so it hangs at rest and swings out while walking), applied to
OUR model: `mods/BASE/player_api/models/character.b3d` is read, a cloak box
and a `Cloak` bone are appended, and the result is written as
`mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d`. Nothing of the
original mesh, bones or keys changes, so every bone the game reads
(wield_geometry.lua) is the same. No VoxeLibre byte is copied: the geometry
and the swing curve are derived here from our own model.

Differences from VoxeLibre, and why:
  * the cloak is its OWN mesh buffer (a second TRIS chunk), so it is the
    model's SECOND texture -- `textures = {skin, cloak}`. The skin stays the
    64x32 composition every humanoid shares; the cloak texture is a separate
    32x32 image (outer face left, lining right), and "no cloak" is a fully
    transparent one. VoxeLibre paints its cape into an 8x12 corner of the
    skin itself;
  * it is longer (shoulders to above the knee, VoxeLibre's ends at the hip),
    so the swing is derived from the legs' own keys and a clearance check
    below proves the swinging legs never pass through it;
  * mobs keep `character.b3d`: only players use this file, so no NPC grows a
    cloak buffer it has no texture for.

Texture format (what a painter needs): 32x32 PNG. Columns 0-15 are the OUTER
face as seen from behind the character (left = the character's left), rows
0-31 shoulder to hem. Columns 16-31 are the LINING as seen from the front
(left = the character's right). The cloak's thin edges take the outer face's
border pixels (column 0, column 15, row 0, row 31). Transparent pixels are
holes (alpha test, as on the skin); keep the outer face opaque.

    python3 tools/r33_c3/gen_cloak_model.py           # write the model
    python3 tools/r33_c3/gen_cloak_model.py --check   # compare, exit 1 if stale

Pure Python 3, no third-party module.
"""
import argparse
import math
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "mods/BASE/player_api/models/character.b3d"
TARGET = REPO / "mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d"

# --- the cloak box, in model units (10 = one node) -------------------------
# The body box is x -2.1..2.1, y 6.3..12.6, z -1.05..1.05; +z is forward
# (wield_geometry.lua section 3), so the back is z = -1.05.
HALF_W = 2.05            # 0.05 inside the body width: the arms' inner faces
                         # (x = +-2.1) never share a plane with the cloak
TOP = 12.6               # the shoulders
LENGTH = 8.4             # 16 skin pixels: shoulders to just above the knee
GAP = 0.10               # behind the body's back face
THICK = 0.35
Z_IN = -1.05 - GAP
Z_OUT = Z_IN - THICK
PIVOT = (0.0, TOP, (Z_IN + Z_OUT) / 2)   # the hinge along the shoulders

# --- the swing (degrees away from the back, per Lua animation frame) ------
BASE = 3.0               # at rest the hem stands a little off the legs
WALK_FACTOR = 0.6        # of the legs' own swing: legs reach 45 deg -> 30 deg
SIT = 35.0               # sitting: the hem rests behind the seat, not in it
STAND_SWAY = 3.0         # a slow sway over the 80-frame idle loop
MINE_SWAY = 4.0          # the punch nudges it

# Animation ranges of player_api's registration (player_api/init.lua).
STAND, SIT_R, LAY, WALK, MINE, WALK_MINE = (0, 79), (81, 160), (162, 166), \
    (168, 187), (189, 198), (200, 219)


# --- b3d chunk tree ----------------------------------------------------------
class Chunk:
    def __init__(self, tag, head=b"", kids=None, raw=b""):
        self.tag, self.head, self.kids, self.raw = tag, head, kids, raw

    def encode(self):
        if self.kids is None:
            body = self.raw
        else:
            body = self.head + b"".join(kid.encode() for kid in self.kids)
        return self.tag.encode() + struct.pack("<i", len(body)) + body


def read_cstring(data, offset):
    end = data.index(b"\0", offset)
    return data[offset:end + 1], end + 1


def parse(data, offset, end):
    chunks = []
    while offset < end:
        tag = data[offset:offset + 4].decode()
        size = struct.unpack("<i", data[offset + 4:offset + 8])[0]
        start, stop = offset + 8, offset + 8 + size
        if tag == "BB3D":
            chunks.append(Chunk(tag, data[start:start + 4], parse(data, start + 4, stop)))
        elif tag == "NODE":
            name, cursor = read_cstring(data, start)
            head = name + data[cursor:cursor + 40]
            chunks.append(Chunk(tag, head, parse(data, cursor + 40, stop)))
        elif tag == "MESH":
            chunks.append(Chunk(tag, data[start:start + 4], parse(data, start + 4, stop)))
        else:
            chunks.append(Chunk(tag, raw=data[start:stop]))
        offset = stop
    return chunks


def node_name(chunk):
    return chunk.head[:chunk.head.index(b"\0")].decode()


def find_node(chunks, name):
    for chunk in chunks:
        if chunk.tag in ("BB3D", "NODE"):
            if chunk.tag == "NODE" and node_name(chunk) == name:
                return chunk
            hit = find_node(chunk.kids, name)
            if hit:
                return hit
    return None


def kid(chunk, tag):
    for k in chunk.kids:
        if k.tag == tag:
            return k
    raise SystemExit("gen_cloak_model: no %s chunk in %s" % (tag, chunk.tag))


# --- quaternions and matrices in Irrlicht's convention ----------------------
# The same math tools/r28_a3/mesh_bounds.py documents: a NODE's local matrix
# is T * R * S with R from quaternion::getMatrix_transposed.
def quat_matrix(w, x, y, z):
    n = math.sqrt(w * w + x * x + y * y + z * z) or 1.0
    w, x, y, z = w / n, x / n, y / n, z / n
    d = [0.0] * 16
    d[0] = 1 - 2 * y * y - 2 * z * z
    d[4] = 2 * x * y + 2 * z * w
    d[8] = 2 * x * z - 2 * y * w
    d[1] = 2 * x * y - 2 * z * w
    d[5] = 1 - 2 * x * x - 2 * z * z
    d[9] = 2 * z * y + 2 * x * w
    d[2] = 2 * x * z + 2 * y * w
    d[6] = 2 * z * y - 2 * x * w
    d[10] = 1 - 2 * x * x - 2 * y * y
    d[15] = 1.0
    return d


def local_matrix(pos, rot):
    m = quat_matrix(*rot)
    m[12], m[13], m[14] = pos
    return m


def mul(a, b):
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[4 * col + row] = sum(a[4 * k + row] * b[4 * col + k] for k in range(4))
    return out


def apply(m, v):
    return tuple(m[row] * v[0] + m[4 + row] * v[1] + m[8 + row] * v[2] + m[12 + row]
                 for row in range(3))


def inverse_rigid(m):
    # rotation part transposed, translation -R^T t (every matrix here is rigid)
    r = [m[0], m[4], m[8], 0, m[1], m[5], m[9], 0, m[2], m[6], m[10], 0, 0, 0, 0, 1]
    t = (m[12], m[13], m[14])
    for row in range(3):
        r[12 + row] = -(r[row] * t[0] + r[4 + row] * t[1] + r[8 + row] * t[2])
    return r


def node_bind(chunk):
    name_len = chunk.head.index(b"\0") + 1
    values = struct.unpack("<10f", chunk.head[name_len:name_len + 40])
    return values[0:3], values[6:10]


def node_keys(chunk):
    keys = {}
    for k in chunk.kids:
        if k.tag != "KEYS":
            continue
        flags = struct.unpack("<i", k.raw[:4])[0]
        assert flags == 7, "expected pos+scale+rot keys"
        for i in range((len(k.raw) - 4) // 44):
            frame, *rest = struct.unpack("<i10f", k.raw[4 + 44 * i:48 + 44 * i])
            keys[frame] = (tuple(rest[0:3]), tuple(rest[6:10]))
    return keys


# --- the swing curve ----------------------------------------------------------
def leg_swing(leg_keys, frame):
    """Degrees the leg stands off vertical at Lua frame `frame` (file frame + 1)."""
    _, rot = leg_keys[frame + 1]
    w = max(-1.0, min(1.0, abs(rot[0])))
    return 180.0 - 2 * math.degrees(math.acos(w))


def swing(frame, leg_keys):
    if STAND[0] <= frame <= STAND[1]:
        return BASE + STAND_SWAY * math.sin(math.pi * frame / 80.0) ** 2
    if SIT_R[0] <= frame <= SIT_R[1]:
        return SIT
    if WALK[0] <= frame <= WALK[1] or WALK_MINE[0] <= frame <= WALK_MINE[1]:
        return BASE + WALK_FACTOR * abs(leg_swing(leg_keys, frame))
    if MINE[0] <= frame <= MINE[1]:
        return BASE + MINE_SWAY * math.sin(math.pi * (frame - MINE[0]) / 9.0)
    return BASE  # lay and the single frames between the ranges


# --- clearance: separating-axis test between two convex boxes ---------------
def box_axes(corners):
    # corners in the order of BOX_CORNERS below: three edge directions
    o = corners[0]
    return [tuple(corners[i][k] - o[k] for k in range(3)) for i in (1, 2, 4)]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def overlap(box_a, box_b, margin=0.0):
    axes = box_axes(box_a) + box_axes(box_b)
    axes += [cross(a, b) for a in box_axes(box_a) for b in box_axes(box_b)]
    for axis in axes:
        if sum(c * c for c in axis) < 1e-9:
            continue
        pa = [sum(p[k] * axis[k] for k in range(3)) for p in box_a]
        pb = [sum(p[k] * axis[k] for k in range(3)) for p in box_b]
        length = math.sqrt(sum(c * c for c in axis))
        if max(pa) + margin * length < min(pb) or max(pb) + margin * length < min(pa):
            return False
    return True


def corners_of(x0, x1, y0, y1, z0, z1):
    # index bits: 1 = x1, 2 = y1, 4 = z1
    return [(x1 if i & 1 else x0, y1 if i & 2 else y0, z1 if i & 4 else z0) for i in range(8)]


# --- building ------------------------------------------------------------------
def cloak_geometry():
    """24 vertices (4 per face, own normals and UVs) and 12 triangles."""
    x0, x1 = -HALF_W, HALF_W
    y0, y1 = TOP - LENGTH, TOP
    px = 1.0 / 32.0
    faces = [
        # (normal, four corners as (x, y, z, u, v)), corner order around the
        # face; triangles (0,1,2) and (0,2,3) must face outward, checked below.
        ((0, 0, -1), [(x0, y0, Z_OUT, 0.0, 1.0), (x0, y1, Z_OUT, 0.0, 0.0),
                      (x1, y1, Z_OUT, 0.5, 0.0), (x1, y0, Z_OUT, 0.5, 1.0)]),
        ((0, 0, 1), [(x1, y0, Z_IN, 0.5, 1.0), (x1, y1, Z_IN, 0.5, 0.0),
                     (x0, y1, Z_IN, 1.0, 0.0), (x0, y0, Z_IN, 1.0, 1.0)]),
        ((-1, 0, 0), [(x0, y0, Z_IN, px, 1.0), (x0, y1, Z_IN, px, 0.0),
                      (x0, y1, Z_OUT, 0.0, 0.0), (x0, y0, Z_OUT, 0.0, 1.0)]),
        ((1, 0, 0), [(x1, y0, Z_OUT, 0.5, 1.0), (x1, y1, Z_OUT, 0.5, 0.0),
                     (x1, y1, Z_IN, 0.5 - px, 0.0), (x1, y0, Z_IN, 0.5 - px, 1.0)]),
        ((0, 1, 0), [(x0, y1, Z_OUT, 0.0, 0.0), (x0, y1, Z_IN, 0.0, px),
                     (x1, y1, Z_IN, 0.5, px), (x1, y1, Z_OUT, 0.5, 0.0)]),
        ((0, -1, 0), [(x0, y0, Z_IN, 0.0, 1.0 - px), (x0, y0, Z_OUT, 0.0, 1.0),
                      (x1, y0, Z_OUT, 0.5, 1.0), (x1, y0, Z_IN, 0.5, 1.0 - px)]),
    ]
    verts, tris = [], []
    for normal, quad in faces:
        base = len(verts)
        for x, y, z, u, v in quad:
            verts.append(((x, y, z), normal, (u, v)))
        for a, b, c in ((0, 1, 2), (0, 2, 3)):
            p = [quad[i][:3] for i in (a, b, c)]
            n = cross(tuple(p[1][k] - p[0][k] for k in range(3)),
                      tuple(p[2][k] - p[0][k] for k in range(3)))
            # the source mesh winds so that cross(v1-v0, v2-v0) points outward
            if sum(n[k] * normal[k] for k in range(3)) <= 0:
                raise SystemExit("gen_cloak_model: inward triangle")
            tris.append((base + a, base + b, base + c))
    return verts, tris


def build():
    data = SOURCE.read_bytes()
    root = parse(data, 0, len(data))
    player = find_node(root, "Player")
    body = find_node(root, "Body")
    legs = {name: node_keys(find_node(root, name)) for name in ("Leg_Left", "Leg_Right")}
    mesh = kid(player, "MESH")
    vrts = kid(mesh, "VRTS")
    flags, sets, size = struct.unpack("<3i", vrts.raw[:12])
    assert (flags, sets, size) == (1, 1, 2), "expected normals + one UV set"
    first = (len(vrts.raw) - 12) // 32
    frame_count = len(node_keys(body))

    verts, tris = cloak_geometry()
    vrts.raw += b"".join(struct.pack("<8f", *pos, *normal, *uv) for pos, normal, uv in verts)
    tris_raw = struct.pack("<i", 0) + b"".join(
        struct.pack("<3i", *(first + i for i in t)) for t in tris)
    # A second TRIS chunk is a second mesh buffer, i.e. the model's second
    # material and texture (CB3DMeshFileLoader: one buffer per TRIS chunk).
    mesh.kids.insert(mesh.kids.index(kid(mesh, "TRIS")) + 1, Chunk("TRIS", raw=tris_raw))

    # The Cloak bone: child of Body, identity rotation, at the hinge.
    body_pos, body_rot = node_bind(body)
    body_bind = local_matrix(body_pos, body_rot)
    local_pivot = apply(inverse_rigid(body_bind), PIVOT)
    bone = struct.pack("<10f", *local_pivot, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)
    weights = b"".join(struct.pack("<if", first + i, 1.0) for i in range(len(verts)))
    keys, curve = [], []
    for file_frame in range(1, frame_count + 1):
        angle = swing(file_frame - 1, legs["Leg_Left"])
        curve.append(angle)
        half = math.radians(angle) / 2
        # Rotation about the bone's x axis. Under Body's half turn about y
        # that axis is model -x, so a positive angle lifts the hem to -z
        # (backwards) -- asserted by the clearance pass below.
        keys.append(struct.pack("<i10f", file_frame, *local_pivot, 1.0, 1.0, 1.0,
                                math.cos(half), math.sin(half), 0.0, 0.0))
    cloak = Chunk("NODE", b"Cloak\0" + bone, [
        Chunk("BONE", raw=weights),
        Chunk("KEYS", raw=struct.pack("<i", 7) + b"".join(keys)),
    ])
    body.kids.append(cloak)
    out = b"".join(chunk.encode() for chunk in root)
    return out, curve, (body, legs, local_pivot)


def check_clearance(curve, rig):
    """Every frame: the cloak must stay behind the body and clear both legs."""
    body, legs, local_pivot = rig
    body_keys = node_keys(body)
    bind_body = local_matrix(*node_bind(body))
    leg_nodes = {name: find_node([body], name) for name in legs}
    cloak_box = corners_of(-HALF_W, HALF_W, TOP - LENGTH, TOP, Z_OUT, Z_IN)
    bind_cloak = mul(bind_body, local_matrix(local_pivot, (1, 0, 0, 0)))
    worst = None
    for frame, angle in enumerate(curve):
        file_frame = frame + 1
        body_now = local_matrix(*body_keys[file_frame])
        half = math.radians(angle) / 2
        cloak_now = mul(body_now, local_matrix(local_pivot, (math.cos(half), math.sin(half), 0, 0)))
        skin = mul(cloak_now, inverse_rigid(bind_cloak))
        cloak = [apply(skin, p) for p in cloak_box]
        rest_hem = apply(mul(body_now, inverse_rigid(bind_body)), (0, TOP - LENGTH, Z_OUT))
        moved = apply(skin, (0, TOP - LENGTH, Z_OUT))
        if angle > 1 and not moved[2] < rest_hem[2]:
            raise SystemExit("gen_cloak_model: a positive swing does not lift the hem backwards")
        for name, node in leg_nodes.items():
            leg_bind = mul(bind_body, local_matrix(*node_bind(node)))
            leg_now = mul(body_now, local_matrix(*node_keys(node)[file_frame]))
            leg_skin = mul(leg_now, inverse_rigid(leg_bind))
            x0, x1 = (-2.1, 0.0) if name == "Leg_Left" else (0.0, 2.1)
            leg = [apply(leg_skin, p) for p in corners_of(x0, x1, 0.0, 6.3, -1.05, 1.05)]
            if overlap(cloak, leg):
                raise SystemExit("gen_cloak_model: cloak meets %s at frame %d (swing %.1f)"
                                 % (name, frame, angle))
        if frame >= SIT_R[0] and frame <= SIT_R[1]:
            low = min(p[1] for p in cloak)
            worst = low if worst is None else min(worst, low)
    return worst


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true",
                        help="compare with the shipped model, exit 1 if it differs")
    args = parser.parse_args()
    out, curve, rig = build()
    sit_low = check_clearance(curve, rig)
    if args.check:
        if not TARGET.exists() or TARGET.read_bytes() != out:
            print("gen_cloak_model: %s is stale, re-run without --check" %
                  TARGET.relative_to(REPO))
            return 1
        print("gen_cloak_model: model up to date")
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_bytes(out)
    walk = [curve[f] for f in range(WALK[0], WALK[1] + 1)]
    print("gen_cloak_model: wrote %s (%d bytes); swing stand %.1f-%.1f, walk %.1f-%.1f, "
          "sit %.1f (hem at y %.2f), legs clear in all %d frames" % (
              TARGET.relative_to(REPO), len(out),
              min(curve[STAND[0]:STAND[1] + 1]), max(curve[STAND[0]:STAND[1] + 1]),
              min(walk), max(walk), SIT, sit_low, len(curve)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
