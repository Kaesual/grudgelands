#!/usr/bin/env python3
"""Round 28 Lane A3: rendered mesh bounds vs collision/selection boxes.

Reads the entity dump written by the engine probe in tools/r28_a3/probe_dump
(one TSV row per mesh entity: name, mesh, visual_size x/y, collisionbox,
selectionbox, mobs_redo rotate, tier) and measures every .b3d it names.

Mesh bounds follow Irrlicht's B3D loader (irr/src/CB3DMeshFileLoader.cpp):
each VRTS vertex is transformed by the global matrix of the NODE that holds
the MESH chunk, global = parent * T * R * S, where R is built by
quaternion::getMatrix_transposed from the file's (w, x, y, z) rotation. This
is the bind pose; animation frames move limbs a little, so the numbers are a
rough guide. Luanti draws 1 mesh unit as 0.1 node at visual_size 1, with the
mesh x/z scaled by visual_size.x and y by visual_size.y, in the object's own
frame -- the frame a `rotate = true` selection box turns with.

Usage: mesh_bounds.py ENTITIES.tsv [REPO_ROOT]
"""

import math
import os
import struct
import sys


def quat_matrix(w, x, y, z):
    n = (w * w + x * x + y * y + z * z) ** 0.5 or 1.0
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


def local_matrix(t, s, r):
    m = quat_matrix(r[0], r[1], r[2], r[3])
    for col in range(3):
        for k in range(3):
            m[4 * col + k] *= s[col]
    m[12], m[13], m[14] = t
    return m


def mul(a, b):
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[4 * col + row] = sum(a[4 * k + row] * b[4 * col + k]
                                     for k in range(4))
    return out


def transform(m, v):
    x, y, z = v
    return (x * m[0] + y * m[4] + z * m[8] + m[12],
            x * m[1] + y * m[5] + z * m[9] + m[13],
            x * m[2] + y * m[6] + z * m[10] + m[14])


IDENTITY = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]


def inverse(m):
    """Inverse of an affine 4x4 (column-major, Irrlicht layout)."""
    a = [[m[4 * c + r] for c in range(3)] for r in range(3)]
    det = (a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1])
           - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
           + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]))
    inv = [[0.0] * 3 for _ in range(3)]
    for r in range(3):
        for c in range(3):
            r1, r2 = [i for i in range(3) if i != c]
            c1, c2 = [i for i in range(3) if i != r]
            minor = a[r1][c1] * a[r2][c2] - a[r1][c2] * a[r2][c1]
            inv[r][c] = (-1) ** (r + c) * minor / det
    out = [0.0] * 16
    for r in range(3):
        for c in range(3):
            out[4 * c + r] = inv[r][c]
    t = (m[12], m[13], m[14])
    for r in range(3):
        out[12 + r] = -sum(inv[r][k] * t[k] for k in range(3))
    out[15] = 1.0
    return out


def lerp(a, b, f):
    return tuple(x + (y - x) * f for x, y in zip(a, b))


def nlerp(a, b, f):
    if sum(x * y for x, y in zip(a, b)) < 0:
        b = tuple(-y for y in b)
    return lerp(a, b, f)


def channel_at(keys, frame, mix):
    """Irrlicht Channel::get: clamp at the ends, interpolate between keys."""
    if not keys:
        return None
    if frame <= keys[0][0]:
        return keys[0][1]
    for i in range(1, len(keys)):
        if keys[i][0] >= frame:
            f0, v0 = keys[i - 1]
            f1, v1 = keys[i]
            return mix(v0, v1, (frame - f0) / float(f1 - f0))
    return keys[-1][1]


class Joint:
    def __init__(self, parent, t, s, r):
        self.parent = parent
        self.t, self.s, self.r = t, s, r
        self.pos, self.scl, self.rot = [], [], []
        self.weights = []  # (global vertex index, strength)


class B3D:
    def __init__(self, data):
        self.data = data
        self.joints = []
        self.verts = []  # bind-pose positions (node transform applied)
        self.verts_start = 0

    def chunks(self, start, end):
        pos = start
        while pos + 8 <= end:
            tag = self.data[pos:pos + 4].decode("latin-1")
            size = struct.unpack_from("<i", self.data, pos + 4)[0]
            yield tag, pos + 8, pos + 8 + size
            pos += 8 + size

    def string(self, pos):
        endp = self.data.index(b"\0", pos)
        return self.data[pos:endp], endp + 1

    def node(self, start, end, parent, parent_glob):
        _, pos = self.string(start)
        vals = struct.unpack_from("<10f", self.data, pos)
        pos += 40
        joint = Joint(parent, vals[0:3], vals[3:6], vals[6:10])
        index = len(self.joints)
        self.joints.append(joint)
        glob = mul(parent_glob, local_matrix(joint.t, joint.s, joint.r))
        for tag, cstart, cend in self.chunks(pos, end):
            if tag == "NODE":
                self.node(cstart, cend, index, glob)
            elif tag == "MESH":
                # Like the loader's VerticesStart: BONE ids count from the
                # most recently read MESH, wherever the bone node sits.
                self.verts_start = len(self.verts)
                self.mesh(cstart + 4, cend, glob)
            elif tag == "BONE":
                p = cstart
                while p + 8 <= cend:
                    vid, w = struct.unpack_from("<If", self.data, p)
                    if w > 0:
                        joint.weights.append((vid + self.verts_start, w))
                    p += 8
            elif tag == "KEYS":
                flags = struct.unpack_from("<i", self.data, cstart)[0]
                p = cstart + 4
                while p < cend:
                    frame = max(1, struct.unpack_from("<i", self.data, p)[0]) - 1
                    p += 4
                    if flags & 1:
                        joint.pos.append((frame, struct.unpack_from("<3f", self.data, p)))
                        p += 12
                    if flags & 2:
                        joint.scl.append((frame, struct.unpack_from("<3f", self.data, p)))
                        p += 12
                    if flags & 4:
                        joint.rot.append((frame, struct.unpack_from("<4f", self.data, p)))
                        p += 16

    def mesh(self, start, end, glob):
        for tag, cstart, cend in self.chunks(start, end):
            if tag == "VRTS":
                self.vrts(cstart, cend, glob)

    def vrts(self, start, end, glob):
        flags, sets, set_size = struct.unpack_from("<3i", self.data, start)
        floats = 3 + (3 if flags & 1 else 0) + (4 if flags & 2 else 0) \
            + sets * set_size
        stride = floats * 4
        pos = start + 12
        while pos + stride <= end:
            self.verts.append(transform(glob, struct.unpack_from("<3f", self.data, pos)))
            pos += stride

    def load(self):
        assert self.data[:4] == b"BB3D", "not a B3D file"
        size = struct.unpack_from("<i", self.data, 4)[0]
        for tag, cstart, cend in self.chunks(12, 8 + size):
            if tag == "NODE":
                self.node(cstart, cend, None, IDENTITY)
        self.bind = self.globals(None)
        self.bind_inv = [inverse(m) for m in self.bind]
        return self

    def globals(self, frame):
        out = []
        for j in self.joints:
            t, s, r = j.t, j.s, j.r
            if frame is not None:
                t = channel_at(j.pos, frame, lerp) or t
                s = channel_at(j.scl, frame, lerp) or s
                r = channel_at(j.rot, frame, nlerp) or r
            local = local_matrix(t, s, r)
            out.append(mul(out[j.parent], local) if j.parent is not None
                       else local)
        return out

    def bounds(self, frame=None):
        """Bind pose (frame None) or the software-skinned pose at a frame."""
        pts = self.verts
        if frame is not None and any(j.weights for j in self.joints):
            anim = self.globals(frame)
            acc = [[0.0, 0.0, 0.0, 0.0] for _ in self.verts]
            for i, j in enumerate(self.joints):
                if not j.weights:
                    continue
                skin = mul(anim[i], self.bind_inv[i])
                for vid, w in j.weights:
                    p = transform(skin, self.verts[vid])
                    a = acc[vid]
                    a[0] += p[0] * w
                    a[1] += p[1] * w
                    a[2] += p[2] * w
                    a[3] += w
            pts = [(a[0] / a[3], a[1] / a[3], a[2] / a[3]) if a[3] > 0
                   else v for a, v in zip(acc, self.verts)]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        return lo, hi

    def key_frames(self, first, last):
        frames = {first, last}
        for j in self.joints:
            for keys in (j.pos, j.scl, j.rot):
                for f, _ in keys:
                    if first <= f <= last:
                        frames.add(f)
        return sorted(frames)

    def animated_bounds(self, ranges):
        """Union over every key frame of the given (first, last) clips."""
        lo = [float("inf")] * 3
        hi = [float("-inf")] * 3
        for first, last in ranges:
            for f in self.key_frames(first, last):
                a, b = self.bounds(f)
                lo = [min(x, y) for x, y in zip(lo, a)]
                hi = [max(x, y) for x, y in zip(hi, b)]
        return lo, hi


def find_mesh(root, name):
    for base, _, files in os.walk(os.path.join(root, "mods")):
        if name in files:
            return os.path.join(base, name)
    return None


def parse_box(text):
    if text == "nil":
        return None, False
    parts = text.split(",")
    return [float(p) for p in parts[:6]], "rotate" in parts[6:]


def to_nodes(lo, hi, sx, sy):
    return [lo[0] * sx / 10, lo[1] * sy / 10, lo[2] * sx / 10,
            hi[0] * sx / 10, hi[1] * sy / 10, hi[2] * sx / 10]


def excess(box, mb):
    """How far the mesh sticks out of the box: (horizontal, vertical) nodes."""
    return (max(box[0] - mb[0], box[2] - mb[2], mb[3] - box[3],
                mb[5] - box[5], 0),
            max(box[1] - mb[1], mb[4] - box[4], 0))


def fmt(values):
    return ",".join("%.2f" % v for v in values)


def main():
    tsv = sys.argv[1]
    root = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..")
    cache = {}
    print("\t".join(["entity", "mesh", "vs", "bind_pose_nodes",
                     "stand_clip_nodes", "all_clips_nodes(stand+walk/fly)",
                     "collisionbox",
                     "selectionbox", "excess_xz", "excess_y",
                     "stand_box_rounded"]))
    with open(tsv) as fh:
        for line in fh:
            row = line.rstrip("\n").split("\t")
            if len(row) < 6 or not row[1].endswith(".b3d"):
                continue
            name, mesh, vsx, vsy, col, sel = row[:6]
            ranges = []
            for clip in (row[7].split(",") if len(row) > 7 and row[7] else []):
                first, last = clip.split("-")
                ranges.append((int(first), int(last)))
            if mesh not in cache:
                path = find_mesh(root, mesh)
                cache[mesh] = B3D(open(path, "rb").read()).load() \
                    if path else None
            model = cache[mesh]
            if not model:
                print(name + "\t" + mesh + "\tMISSING")
                continue
            sx, sy = float(vsx), float(vsy)
            bind = to_nodes(*model.bounds(), sx, sy)
            stand = to_nodes(*model.animated_bounds(ranges[:1]), sx, sy) \
                if ranges else bind
            anim = to_nodes(*model.animated_bounds(ranges), sx, sy) \
                if ranges else bind
            selbox = parse_box(sel)[0] or parse_box(col)[0]
            if not selbox:
                continue
            # Excess is judged on the stand clip: the pose a player aims at
            # most of the time (the bind pose of the birds and dragons has
            # its wings spread, which no idle mob shows).
            ex_xz, ex_y = excess(selbox, stand)
            # The rotated selection box the lane writes: the stand-clip mesh
            # bounds, horizontally never narrower than the collision
            # footprint, rounded outward to 0.05 node.
            colbox = parse_box(col)[0] or stand
            lo = [min(stand[0], colbox[0]), stand[1], min(stand[2], colbox[2])]
            hi = [max(stand[3], colbox[3]), stand[4], max(stand[5], colbox[5])]
            proposal = [math.floor(round(v * 20, 6)) / 20 for v in lo] + \
                [math.ceil(round(v * 20, 6)) / 20 for v in hi]
            print("\t".join([name, mesh, vsx, fmt(bind), fmt(stand),
                             fmt(anim), col, sel, "%.2f" % ex_xz,
                             "%.2f" % ex_y, fmt(proposal)]))


if __name__ == "__main__":
    main()
