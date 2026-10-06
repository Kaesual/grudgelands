#!/usr/bin/env python3
"""Check grug_visuals_character.glb against the .b3d it was converted from
(Round 39 lane WG, round39-web-data-plan.md §4.3).

    python3 tools/web_data/model/check_glb.py [GLB [B3D]]

Both files are evaluated here, independently of the converter: the .b3d in
the engine's B3D semantics (irr/src/CB3DMeshFileLoader.cpp: file frame N is
engine frame N-1, a NODE's matrix is T * R * S with R from
quaternion::getMatrix_transposed, keys interpolated as SkinnedMesh does), the
.glb in plain glTF 2.0 semantics (seconds, standard quaternions, LINEAR
slerp). glTF is right-handed and the engine left-handed; Luanti's glTF loader
mirrors z (CGLTFMeshFileLoader.cpp convertHandedness), so a glTF point
(x, y, z) is the engine point (x, y, -z).

Checks: the glb's structure (header, chunks, buffer views, accessor bounds
and min/max, indices, node tree, skin, animation samplers, what Luanti's
loader refuses); bone names and hierarchy; vertex and triangle counts per
primitive; positions, normals and UVs per vertex; the triangle winding a
culling viewer needs; one material per primitive in the model's texture order;
the skin weights; the rest pose; every clip against player_api's frame range
and speed (key count, duration), and per frame the skinned bounding box and
every skinned vertex, plus the half frames between keys (interpolation).
Prints the numbers, exits 1 on any failure. Python 3 standard library only.
"""
import json
import math
import re
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
GLB = REPO / "tools/web_data/model/grug_visuals_character.glb"
B3D = REPO / "mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d"
PLAYER_API = REPO / "mods/BASE/player_api/init.lua"

# The clips the glb must carry; any other clip must be a player_api animation.
REQUIRED_CLIPS = ("stand", "walk")
# Material names per primitive: the texture order of grug_visuals'
# registration (apply.lua: textures = {skin, cloak}).
MATERIALS = ("skin", "cloak")

# Model units (10 = one node). Measured deviations are about 1e-6; a clip
# read one frame off moves the stand pose by about 0.015.
TOL = 1e-3
TOL_UV = 1e-6

errors = []


def fail(msg):
    errors.append(msg)


# --- small 4x4 math, row-major m[r][c] ---------------------------------------
def mat_mul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def mat_apply(m, p, w=1.0):
    return tuple(m[r][0] * p[0] + m[r][1] * p[1] + m[r][2] * p[2] + m[r][3] * w for r in range(3))


def quat_rot(w, x, y, z):
    """Standard rotation matrix of the unit quaternion (w, x, y, z)."""
    n = math.sqrt(w * w + x * x + y * y + z * z) or 1.0
    w, x, y, z = w / n, x / n, y / n, z / n
    return [[1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y), 0.0],
            [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x), 0.0],
            [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y), 0.0],
            [0.0, 0.0, 0.0, 1.0]]


def trs(t, rot, s):
    m = [row[:] for row in rot]
    for r in range(3):
        for c in range(3):
            m[r][c] *= s[c]
        m[r][3] = t[r]
    return m


def mat_inverse(m):
    """Inverse of an affine 4x4."""
    a = [row[:3] for row in m[:3]]
    det = (a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1])
           - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
           + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]))
    inv = [[0.0] * 3 for _ in range(3)]
    for r in range(3):
        for c in range(3):
            rows = [i for i in range(3) if i != c]
            cols = [i for i in range(3) if i != r]
            minor = (a[rows[0]][cols[0]] * a[rows[1]][cols[1]]
                     - a[rows[0]][cols[1]] * a[rows[1]][cols[0]])
            inv[r][c] = (-1) ** (r + c) * minor / det
    t = [-sum(inv[r][k] * m[k][3] for k in range(3)) for r in range(3)]
    return [inv[0] + [t[0]], inv[1] + [t[1]], inv[2] + [t[2]], [0.0, 0.0, 0.0, 1.0]]


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def normalize(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def slerp(a, b, t):
    """glTF LINEAR rotation: spherical, along the shorter arc."""
    d = sum(a[i] * b[i] for i in range(4))
    if d < 0:
        b, d = tuple(-c for c in b), -d
    if d > 0.9995:
        return normalize(lerp(a, b, t))
    th = math.acos(min(1.0, d))
    sa, sb = math.sin((1 - t) * th) / math.sin(th), math.sin(t * th) / math.sin(th)
    return tuple(a[i] * sa + b[i] * sb for i in range(4))


def irr_slerp(a, b, t):
    """quaternion::slerp with its default threshold 0.05 (nlerp above 0.95)."""
    d = sum(a[i] * b[i] for i in range(4))
    if d < 0:
        a, d = tuple(-c for c in a), -d
    if d <= 0.95:
        th = math.acos(d)
        sa, sb = math.sin(th * (1 - t)) / math.sin(th), math.sin(th * t) / math.sin(th)
        return tuple(a[i] * sa + b[i] * sb for i in range(4))
    return normalize(lerp(a, b, t))


def bbox(points):
    return [min(p[i] for p in points) for i in range(3)] + \
           [max(p[i] for p in points) for i in range(3)]


def mirror(p):
    return (p[0], p[1], -p[2])


# --- the .b3d, as the engine reads it ----------------------------------------
class B3DNode:
    def __init__(self, name, parent, t, s, r):
        self.name, self.parent = name, parent
        self.t, self.s, self.r = t, s, r          # r = (w, x, y, z) as in the file
        self.weights = {}                         # vertex id -> weight
        self.pos, self.scale, self.rot = {}, {}, {}  # engine frame -> value
        self.kids = []


def read_b3d(path):
    data = path.read_bytes()
    model = {"verts": [], "tris": [], "nodes": [], "mesh_node": None}

    def cstring(off):
        end = data.index(b"\0", off)
        return data[off:end].decode(), end + 1

    def walk(off, end, parent):
        while off < end:
            tag = data[off:off + 4].decode()
            size = struct.unpack_from("<i", data, off + 4)[0]
            start, stop = off + 8, off + 8 + size
            if tag == "BB3D":
                walk(start + 4, stop, parent)
            elif tag == "NODE":
                name, cur = cstring(start)
                v = struct.unpack_from("<10f", data, cur)
                node = B3DNode(name, parent, v[0:3], v[3:6], v[6:10])
                model["nodes"].append(node)
                if parent:
                    parent.kids.append(node)
                walk(cur + 40, stop, node)
            elif tag == "MESH":
                model["mesh_node"] = parent
                walk(start + 4, stop, parent)
            elif tag == "VRTS":
                flags, sets, size_ = struct.unpack_from("<3i", data, start)
                stride = 3 + (3 if flags & 1 else 0) + (4 if flags & 2 else 0) + sets * size_
                cur = start + 12
                while cur < stop:
                    v = struct.unpack_from("<%df" % stride, data, cur)
                    nrm = v[3:6] if flags & 1 else None
                    uv_at = 3 + (3 if flags & 1 else 0) + (4 if flags & 2 else 0)
                    model["verts"].append((v[0:3], nrm, v[uv_at:uv_at + 2]))
                    cur += 4 * stride
            elif tag == "TRIS":
                n = (size - 4) // 12
                model["tris"].append([struct.unpack_from("<3i", data, start + 4 + 12 * i)
                                      for i in range(n)])
            elif tag == "BONE":
                for i in range(size // 8):
                    vid, w = struct.unpack_from("<if", data, start + 8 * i)
                    parent.weights[vid] = parent.weights.get(vid, 0.0) + w
            elif tag == "KEYS":
                flags = struct.unpack_from("<i", data, start)[0]
                stride = 1 + (3 if flags & 1 else 0) + (3 if flags & 2 else 0) + (4 if flags & 4 else 0)
                cur = start + 4
                while cur < stop:
                    frame = struct.unpack_from("<i", data, cur)[0] - 1   # engine frames are 0-based
                    v = struct.unpack_from("<%df" % (stride - 1), data, cur + 4)
                    i = 0
                    if flags & 1:
                        parent.pos[frame], i = v[i:i + 3], i + 3
                    if flags & 2:
                        parent.scale[frame], i = v[i:i + 3], i + 3
                    if flags & 4:
                        parent.rot[frame], i = v[i:i + 4], i + 4
                    cur += 4 * stride
            off = stop
    walk(0, len(data), None)
    return model


def irr_rot(r):
    # quaternion::getMatrix_transposed of the file's (w, x, y, z): the
    # transpose of the standard matrix, i.e. the conjugate rotation.
    w, x, y, z = r
    return quat_rot(w, -x, -y, -z)


def key_at(keys, frame, bind, rot=False):
    """SkinnedMesh::Channel::get: clamp outside, interpolate inside."""
    if not keys:
        return bind
    frames = sorted(keys)
    if frame <= frames[0]:
        return keys[frames[0]]
    if frame >= frames[-1]:
        return keys[frames[-1]]
    hi = next(f for f in frames if f >= frame)
    if hi == frame:
        return keys[hi]
    lo = max(f for f in frames if f < frame)
    t = (frame - lo) / (hi - lo)
    if rot:
        # engine quaternions are stored (x, y, z, w); our tuples are (w, x, y, z)
        a, b = keys[lo], keys[hi]
        q = irr_slerp((a[1], a[2], a[3], a[0]), (b[1], b[2], b[3], b[0]), t)
        return (q[3], q[0], q[1], q[2])
    return lerp(keys[lo], keys[hi], t)


def b3d_globals(model, frame):
    """Global matrix per node at `frame` (None = the bind pose)."""
    out = {}
    for node in model["nodes"]:        # parents come before their children
        if frame is None:
            t, s, r = node.t, node.s, node.r
        else:
            t = key_at(node.pos, frame, node.t)
            s = key_at(node.scale, frame, node.s)
            r = key_at(node.rot, frame, node.r, rot=True)
        local = trs(t, irr_rot(r), s)
        out[node] = mat_mul(out[node.parent], local) if node.parent else local
    return out


def b3d_skinned(model, frame):
    bind = b3d_globals(model, None)
    now = b3d_globals(model, frame)
    mesh_m = bind[model["mesh_node"]]
    base = [mat_apply(mesh_m, v[0]) for v in model["verts"]]
    acc = [[0.0, 0.0, 0.0] for _ in base]
    seen = [0.0] * len(base)
    for node in model["nodes"]:
        if not node.weights:
            continue
        skin = mat_mul(now[node], mat_inverse(bind[node]))
        for vid, w in node.weights.items():
            p = mat_apply(skin, base[vid])
            for i in range(3):
                acc[vid][i] += w * p[i]
            seen[vid] += w
    return [tuple(a) if seen[i] else base[i] for i, a in enumerate(acc)]


# --- the .glb -----------------------------------------------------------------
COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
              5125: ("I", 4), 5126: ("f", 4)}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


class Glb:
    def __init__(self, path):
        data = path.read_bytes()
        self.size = len(data)
        self.json, self.bin = {}, b""
        if len(data) < 20 or data[:4] != b"glTF":
            fail("glb: no glTF header")
            return
        version, length = struct.unpack_from("<II", data, 4)
        if version != 2:
            fail("glb: container version %d, want 2" % version)
        if length != len(data):
            fail("glb: header length %d, file %d" % (length, len(data)))
        off, chunks = 12, []
        while off + 8 <= len(data):
            clen, ctype = struct.unpack_from("<II", data, off)
            if clen % 4:
                fail("glb: chunk at %d is not 4-byte aligned" % off)
            chunks.append((ctype, data[off + 8:off + 8 + clen]))
            off += 8 + clen
        if off != len(data):
            fail("glb: trailing bytes after the chunks")
        if not chunks or chunks[0][0] != 0x4E4F534A:
            fail("glb: the first chunk is not JSON")
            return
        self.json = json.loads(chunks[0][1].decode("utf-8"))
        if len(chunks) > 1:
            if chunks[1][0] != 0x004E4942:
                fail("glb: the second chunk is not BIN")
            self.bin = chunks[1][1]
        self.cache = {}

    def get(self, key):
        return self.json.get(key, [])

    def accessor(self, idx):
        """Elements of an accessor as tuples (bounds checked in validate())."""
        if idx in self.cache:
            return self.cache[idx]
        acc = self.get("accessors")[idx]
        fmt, size = COMPONENTS[acc["componentType"]]
        width = WIDTH[acc["type"]]
        view = self.get("bufferViews")[acc["bufferView"]]
        stride = view.get("byteStride") or size * width
        base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        out = [struct.unpack_from("<%d%s" % (width, fmt), self.bin, base + i * stride)
               for i in range(acc["count"])]
        self.cache[idx] = out
        return out


def validate(glb):
    """Structure, accessor bounds and the limits of Luanti's glTF loader."""
    j = glb.json
    if j.get("asset", {}).get("version") != "2.0":
        fail("glb: asset.version is not 2.0")
    if j.get("extensionsRequired"):
        fail("glb: extensionsRequired %s (Luanti refuses any)" % j["extensionsRequired"])
    if "images" in j:
        fail("glb: embedded or referenced images (Luanti warns; textures come from Lua)")
    buffers = glb.get("buffers")
    if len(buffers) != 1 or "uri" in buffers[0]:
        fail("glb: want exactly one buffer, the BIN chunk")
        return False
    blen = buffers[0]["byteLength"]
    if not blen <= len(glb.bin) < blen + 4:
        fail("glb: buffer byteLength %d vs BIN chunk %d" % (blen, len(glb.bin)))
        return False
    for i, view in enumerate(glb.get("bufferViews")):
        end = view.get("byteOffset", 0) + view["byteLength"]
        if view.get("buffer") != 0 or end > blen:
            fail("bufferView %d: outside the buffer" % i)
        stride = view.get("byteStride")
        if stride is not None and (stride % 4 or not 4 <= stride <= 252):
            fail("bufferView %d: byteStride %s" % (i, stride))
    views = glb.get("bufferViews")
    for i, acc in enumerate(glb.get("accessors")):
        if acc.get("componentType") not in COMPONENTS or acc.get("type") not in WIDTH:
            fail("accessor %d: bad componentType or type" % i)
            continue
        if not 0 <= acc.get("bufferView", -1) < len(views):
            fail("accessor %d: no bufferView" % i)
            continue
        size = COMPONENTS[acc["componentType"]][1]
        width = WIDTH[acc["type"]]
        view = views[acc["bufferView"]]
        stride = view.get("byteStride") or size * width
        off = acc.get("byteOffset", 0)
        if off % size or (view.get("byteOffset", 0) + off) % size:
            fail("accessor %d: misaligned" % i)
        if acc["count"] < 1 or off + stride * (acc["count"] - 1) + size * width > view["byteLength"]:
            fail("accessor %d: runs past its bufferView" % i)
            continue
        if "min" in acc or "max" in acc:
            vals = glb.accessor(i)
            lo = [min(v[c] for v in vals) for c in range(width)]
            hi = [max(v[c] for v in vals) for c in range(width)]
            for got, want, what in ((acc.get("min"), lo, "min"), (acc.get("max"), hi, "max")):
                if got is None or any(abs(g - w) > 1e-6 * max(1, abs(w)) for g, w in zip(got, want)):
                    fail("accessor %d: %s %s, data %s" % (i, what, got, want))
    if errors:
        return False

    nodes = glb.get("nodes")
    parent = {}
    for i, node in enumerate(nodes):
        for c in node.get("children", []):
            if not 0 <= c < len(nodes) or c in parent:
                fail("node %d: bad or shared child %s" % (i, c))
            parent[c] = i
    for i in range(len(nodes)):
        seen, k = set(), i
        while k in parent:
            if k in seen:
                fail("node tree has a cycle at %d" % i)
                break
            seen.add(k)
            k = parent[k]
    scenes = glb.get("scenes")
    if not scenes or not 0 <= j.get("scene", 0) < len(scenes):
        fail("glb: no default scene")
    for s in scenes:
        for n in s.get("nodes", []):
            if n in parent:
                fail("scene root %d has a parent" % n)

    accs = glb.get("accessors")
    skins = glb.get("skins")
    for i, skin in enumerate(skins):
        if any(not 0 <= jn < len(nodes) for jn in skin["joints"]):
            fail("skin %d: joint is no node" % i)
        ibm = skin.get("inverseBindMatrices")
        if ibm is None or accs[ibm]["type"] != "MAT4" or accs[ibm]["count"] != len(skin["joints"]):
            fail("skin %d: inverseBindMatrices do not match the joints" % i)
    for mi, mesh in enumerate(glb.get("meshes")):
        for pi, prim in enumerate(mesh["primitives"]):
            where = "mesh %d primitive %d" % (mi, pi)
            attrs = prim["attributes"]
            counts = {accs[a]["count"] for a in attrs.values()}
            if len(counts) != 1:
                fail(where + ": attribute counts differ")
                continue
            count = counts.pop()
            if count >= 65535:
                fail(where + ": too many vertices for Luanti")
            if prim.get("mode", 4) != 4:
                fail(where + ": not triangles")
            if "material" in prim and not 0 <= prim["material"] < len(glb.get("materials")):
                fail(where + ": bad material")
            if "indices" in prim:
                acc = accs[prim["indices"]]
                if acc["type"] != "SCALAR" or acc["componentType"] not in (5121, 5123, 5125):
                    fail(where + ": bad index accessor")
                idx = [v[0] for v in glb.accessor(prim["indices"])]
                if len(idx) % 3 or any(v >= count or v >= 65535 for v in idx):
                    fail(where + ": index out of range")
            for name, typ in (("POSITION", "VEC3"), ("NORMAL", "VEC3"), ("TEXCOORD_0", "VEC2"),
                              ("JOINTS_0", "VEC4"), ("WEIGHTS_0", "VEC4")):
                if name not in attrs:
                    fail(where + ": no " + name)
                elif accs[attrs[name]]["type"] != typ:
                    fail(where + ": %s is not %s" % (name, typ))
            if errors:
                continue
            if "min" not in accs[attrs["POSITION"]]:
                fail(where + ": POSITION without min/max")
            if accs[attrs["JOINTS_0"]]["componentType"] not in (5121, 5123):
                fail(where + ": JOINTS_0 must be unsigned byte or short")
            if accs[attrs["WEIGHTS_0"]]["componentType"] != 5126:
                fail(where + ": WEIGHTS_0 must be float")
            if any(abs(math.sqrt(sum(c * c for c in n)) - 1) > 1e-4
                   for n in glb.accessor(attrs["NORMAL"])):
                fail(where + ": NORMAL not unit length")
            if any(abs(sum(w) - 1) > 1e-4 for w in glb.accessor(attrs["WEIGHTS_0"])):
                fail(where + ": weights do not sum to 1")
    for node_i, node in enumerate(nodes):
        if "skin" in node and ("mesh" not in node or not 0 <= node["skin"] < len(skins)):
            fail("node %d: bad skin" % node_i)
        if "mesh" in node and "skin" in node:
            njoints = len(skins[node["skin"]]["joints"])
            for prim in glb.get("meshes")[node["mesh"]]["primitives"]:
                if any(c >= njoints for v in glb.accessor(prim["attributes"]["JOINTS_0"]) for c in v):
                    fail("node %d: joint index past the skin" % node_i)
    for ai, anim in enumerate(glb.get("animations")):
        samplers = anim.get("samplers", [])
        targets = set()
        for ch in anim.get("channels", []):
            tgt = ch.get("target", {})
            if not 0 <= ch.get("sampler", -1) < len(samplers) or \
                    not 0 <= tgt.get("node", -1) < len(nodes):
                fail("animation %d: bad channel" % ai)
                continue
            path = tgt.get("path")
            if path not in ("translation", "rotation", "scale"):
                fail("animation %d: path %s (Luanti: no morph weights)" % (ai, path))
            if (tgt["node"], path) in targets:
                fail("animation %d: two channels on one target" % ai)
            targets.add((tgt["node"], path))
            if "matrix" in nodes[tgt["node"]]:
                fail("animation %d: animates a matrix node (Luanti refuses)" % ai)
            smp = samplers[ch["sampler"]]
            if smp.get("interpolation", "LINEAR") not in ("LINEAR", "STEP"):
                fail("animation %d: interpolation %s" % (ai, smp["interpolation"]))
            inp, outp = accs[smp["input"]], accs[smp["output"]]
            if inp["type"] != "SCALAR" or inp["componentType"] != 5126 or "min" not in inp:
                fail("animation %d: bad input accessor" % ai)
            times = [v[0] for v in glb.accessor(smp["input"])]
            if times[0] < 0 or any(b <= a for a, b in zip(times, times[1:])):
                fail("animation %d: times not increasing from >= 0" % ai)
            want = "VEC4" if path == "rotation" else "VEC3"
            if outp["type"] != want or outp["count"] != inp["count"] or outp["componentType"] != 5126:
                fail("animation %d: output does not match its input" % ai)
            elif path == "rotation" and any(abs(math.sqrt(sum(c * c for c in q)) - 1) > 1e-4
                                            for q in glb.accessor(smp["output"])):
                fail("animation %d: rotation not unit length" % ai)
    return not errors


def glb_node_trs(node):
    t = node.get("translation", (0.0, 0.0, 0.0))
    x, y, z, w = node.get("rotation", (0.0, 0.0, 0.0, 1.0))
    s = node.get("scale", (1.0, 1.0, 1.0))
    return t, (w, x, y, z), s


def sample(glb, smp_idx, anim, time):
    smp = anim["samplers"][smp_idx]
    times = [v[0] for v in glb.accessor(smp["input"])]
    vals = glb.accessor(smp["output"])
    if time <= times[0]:
        return vals[0]
    if time >= times[-1]:
        return vals[-1]
    hi = next(i for i, t in enumerate(times) if t >= time)
    if times[hi] == time or smp.get("interpolation", "LINEAR") == "STEP":
        return vals[hi] if times[hi] == time else vals[hi - 1]
    t = (time - times[hi - 1]) / (times[hi] - times[hi - 1])
    if len(vals[hi]) == 4:
        return slerp(vals[hi - 1], vals[hi], t)
    return lerp(vals[hi - 1], vals[hi], t)


def glb_globals(glb, anim=None, time=0.0):
    nodes = glb.get("nodes")
    over = {}
    if anim is not None:
        for ch in anim["channels"]:
            over[(ch["target"]["node"], ch["target"]["path"])] = sample(glb, ch["sampler"], anim, time)
    out = {}

    def visit(i, parent_m):
        node = nodes[i]
        t, r, s = glb_node_trs(node)
        t = over.get((i, "translation"), t)
        s = over.get((i, "scale"), s)
        if (i, "rotation") in over:
            x, y, z, w = over[(i, "rotation")]
            r = (w, x, y, z)
        if "matrix" in node:
            m = node["matrix"]
            local = [[m[c * 4 + r_] for c in range(4)] for r_ in range(4)]
        else:
            local = trs(t, quat_rot(*r), s)
        out[i] = mat_mul(parent_m, local) if parent_m else local
        for c in node.get("children", []):
            visit(c, out[i])
    for scene in glb.get("scenes"):
        for root in scene["nodes"]:
            visit(root, None)
    return out


def glb_skinned(glb, mesh_node, anim=None, time=0.0):
    """Per primitive the skinned positions (glTF space)."""
    node = glb.get("nodes")[mesh_node]
    skin = glb.get("skins")[node["skin"]]
    g = glb_globals(glb, anim, time)
    ibms = glb.accessor(skin["inverseBindMatrices"])
    joint_m = [mat_mul(g[jn], [[ibm[c * 4 + r] for c in range(4)] for r in range(4)])
               for jn, ibm in zip(skin["joints"], ibms)]
    out = []
    for prim in glb.get("meshes")[node["mesh"]]["primitives"]:
        a = prim["attributes"]
        pos, js, ws = glb.accessor(a["POSITION"]), glb.accessor(a["JOINTS_0"]), glb.accessor(a["WEIGHTS_0"])
        prim_out = []
        for p, jv, wv in zip(pos, js, ws):
            acc = [0.0, 0.0, 0.0]
            for jn, w in zip(jv, wv):
                if w:
                    q = mat_apply(joint_m[jn], p)
                    for i in range(3):
                        acc[i] += w * q[i]
            prim_out.append(tuple(acc))
        out.append(prim_out)
    return out


# --- player_api's animation table ---------------------------------------------
def player_api_animations():
    text = PLAYER_API.read_text()
    block = text[text.index('register_model("character.b3d"'):]
    speed = float(re.search(r"animation_speed\s*=\s*([\d.]+)", block).group(1))
    anims = {m.group(1): (int(m.group(2)), int(m.group(3))) for m in
             re.finditer(r"(\w+)\s*=\s*\{\s*x\s*=\s*(\d+)\s*,\s*y\s*=\s*(\d+)", block)}
    return anims, speed


# --- the comparison -------------------------------------------------------------
def max_dev(a, b):
    return max(abs(x - y) for x, y in zip(a, b))


def main():
    glb_path = Path(sys.argv[1]) if len(sys.argv) > 1 else GLB
    b3d_path = Path(sys.argv[2]) if len(sys.argv) > 2 else B3D
    glb = Glb(glb_path)
    if errors or not validate(glb):
        return report()
    model = read_b3d(b3d_path)
    nodes = glb.get("nodes")

    # Bones: names and the parent among bones.
    bones = [n for n in model["nodes"] if n.weights]

    def bone_parent(n):
        p = n.parent
        while p is not None and not p.weights:
            p = p.parent
        return p.name if p else None
    want_bones = {n.name: bone_parent(n) for n in bones}
    mesh_nodes = [i for i, n in enumerate(nodes) if "mesh" in n and "skin" in n]
    if len(mesh_nodes) != 1:
        fail("want exactly one skinned mesh node, found %d" % len(mesh_nodes))
        return report()
    mesh_node = mesh_nodes[0]
    joints = glb.get("skins")[nodes[mesh_node]["skin"]]["joints"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}

    def joint_parent(i):
        p = parent.get(i)
        while p is not None and p not in joints:
            p = parent.get(p)
        return nodes[p].get("name") if p is not None else None
    got_bones = {nodes[i].get("name"): joint_parent(i) for i in joints}
    if got_bones != want_bones:
        fail("bones: glb %s, b3d %s" % (got_bones, want_bones))
    if "Cloak" not in got_bones:
        fail("bones: no Cloak bone")

    # Primitives: counts, vertices, UVs, normals, winding, weights, materials.
    prims = glb.get("meshes")[nodes[mesh_node]["mesh"]]["primitives"]
    if len(prims) != len(model["tris"]):
        fail("primitives: glb %d, b3d mesh buffers %d" % (len(prims), len(model["tris"])))
        return report()
    vmap = []        # per primitive: glb vertex -> b3d vertex
    bone_of = {}
    for n in bones:
        for vid, w in n.weights.items():
            if w > 0.5:
                bone_of[vid] = n.name
    worst = {"pos": 0.0, "uv": 0.0, "normal": 0.0}
    for k, (prim, tris) in enumerate(zip(prims, model["tris"])):
        where = "primitive %d" % k
        a = prim["attributes"]
        idx = [v[0] for v in glb.accessor(prim["indices"])]
        # Vertices pair by content (mirrored position, UV, normal), so the
        # check does not depend on the converter's vertex order; the
        # triangles must then be the same set.
        b3d_idx = [v for tri in tris for v in tri]
        count = glb.get("accessors")[a["POSITION"]]["count"]
        pos, nrm, uv = glb.accessor(a["POSITION"]), glb.accessor(a["NORMAL"]), glb.accessor(a["TEXCOORD_0"])
        js, ws = glb.accessor(a["JOINTS_0"]), glb.accessor(a["WEIGHTS_0"])
        free = sorted(set(b3d_idx))
        if count != len(free) or len(idx) != len(b3d_idx):
            fail("%s: %d vertices %d triangles, b3d buffer %d vertices %d triangles" % (
                where, count, len(idx) // 3, len(free), len(tris)))
        m = {}
        for g in range(count):
            p, n = mirror(pos[g]), mirror(nrm[g])
            for b in free:
                bp, bn, buv = model["verts"][b]
                if max_dev(p, bp) <= TOL and max_dev(uv[g], buv) <= TOL_UV and \
                        (bn is None or max_dev(n, normalize(bn)) <= TOL):
                    m[g] = b
                    free.remove(b)
                    break
            else:
                fail("%s: vertex %d (%s, uv %s) has no b3d counterpart" % (
                    where, g, ", ".join("%.3f" % c for c in p), ", ".join("%.4f" % c for c in uv[g])))
        vmap.append(m)
        if len(m) == count:
            got = sorted(tuple(sorted(m[idx[t + i]] for i in range(3))) for t in range(0, len(idx), 3))
            if got != sorted(tuple(sorted(t)) for t in tris):
                fail("%s: the triangles differ from the b3d's" % where)
        for g, b in m.items():
            bp, bn, buv = model["verts"][b]
            worst["pos"] = max(worst["pos"], max_dev(mirror(pos[g]), bp))
            worst["uv"] = max(worst["uv"], max_dev(uv[g], buv))
            if bn:
                worst["normal"] = max(worst["normal"], max_dev(mirror(nrm[g]), normalize(bn)))
            top = max(range(4), key=lambda i: ws[g][i])
            if nodes[joints[js[g][top]]].get("name") != bone_of.get(b):
                fail("%s: vertex %d weighted to %s, b3d %s" % (
                    where, g, nodes[joints[js[g][top]]].get("name"), bone_of.get(b)))
        inward = 0
        for t in range(0, len(idx), 3):
            p0, p1, p2 = (pos[idx[t + i]] for i in range(3))
            e1 = [p1[i] - p0[i] for i in range(3)]
            e2 = [p2[i] - p0[i] for i in range(3)]
            n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
            vn = [sum(nrm[idx[t + i]][c] for i in range(3)) for c in range(3)]
            if sum(n[c] * vn[c] for c in range(3)) <= 0:
                inward += 1
        if inward:
            fail("%s: %d triangles wound against their normals (culled in a viewer)" % (where, inward))
        mats = glb.get("materials")
        if "material" not in prim:
            fail(where + ": no material")
        else:
            mat = mats[prim["material"]]
            if mat.get("name") != (MATERIALS[k] if k < len(MATERIALS) else None):
                fail("%s: material %r, want %r" % (where, mat.get("name"), MATERIALS[k:k + 1]))
            tex = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
            slot = tex["index"] if tex else k   # Luanti's texture slot
            if slot != k:
                fail("%s: Luanti texture slot %d, want %d" % (where, slot, k))
        print("check_glb: %s %-5s %3d vertices %3d triangles" % (
            where, MATERIALS[k] if k < len(MATERIALS) else "?", count, len(idx) // 3))
    if len({p.get("material") for p in prims}) != len(prims):
        fail("primitives share a material")
    if worst["pos"] > TOL or worst["uv"] > TOL_UV or worst["normal"] > TOL:
        fail("vertex data: position %.2g, uv %.2g, normal %.2g" % (worst["pos"], worst["uv"], worst["normal"]))
    if errors:
        return report()

    def compare(b3d_pts, glb_prims):
        dev_v, all_g = 0.0, []
        for m, gp in zip(vmap, glb_prims):
            for g, b in m.items():
                p = mirror(gp[g])
                all_g.append(p)
                dev_v = max(dev_v, max_dev(p, b3d_pts[b]))
        used = sorted({b for m in vmap for b in m.values()})
        return max_dev(bbox(all_g), bbox([b3d_pts[b] for b in used])), dev_v

    # The rest pose: the nodes' own transforms must reproduce the mesh.
    dev_box, dev_v = compare(b3d_skinned(model, None), glb_skinned(glb, mesh_node))
    print("check_glb: rest pose, bbox deviation %.2g, vertex %.2g" % (dev_box, dev_v))
    if max(dev_box, dev_v) > TOL:
        fail("rest pose deviates by %.3g" % max(dev_box, dev_v))

    # Clips.
    anims, speed = player_api_animations()
    clips = {a.get("name"): a for a in glb.get("animations")}
    for name in REQUIRED_CLIPS:
        if name not in clips:
            fail("no clip %r" % name)
    for name, anim in clips.items():
        if name not in anims:
            fail("clip %r is no player_api animation" % name)
            continue
        first, last = anims[name]
        times = sorted({v[0] for ch in anim["channels"]
                        for v in glb.accessor(anim["samplers"][ch["sampler"]]["input"])})
        want = [(f - first) / speed for f in range(first, last + 1)]
        if len(times) != len(want) or max_dev(times, want) > 1e-5:
            fail("clip %s: %d keys %.4f..%.4f s, want %d keys 0..%.4f s (frames %d-%d at %g fps)" % (
                name, len(times), times[0], times[-1], len(want), want[-1], first, last, speed))
            continue
        worst_box = worst_v = worst_half = 0.0
        for f in range(first, last + 1):
            box, dv = compare(b3d_skinned(model, f),
                              glb_skinned(glb, mesh_node, anim, (f - first) / speed))
            worst_box, worst_v = max(worst_box, box), max(worst_v, dv)
            if f < last:
                _, dh = compare(b3d_skinned(model, f + 0.5),
                                glb_skinned(glb, mesh_node, anim, (f + 0.5 - first) / speed))
                worst_half = max(worst_half, dh)
        print("check_glb: clip %-5s frames %d-%d, %d keys, %.4f s at %g fps; max deviation "
              "bbox %.2g, vertex %.2g, half frames %.2g" % (
                  name, first, last, len(want), want[-1], speed, worst_box, worst_v, worst_half))
        if max(worst_box, worst_v) > TOL or worst_half > TOL:
            fail("clip %s deviates: bbox %.3g, vertex %.3g, half frames %.3g" % (
                name, worst_box, worst_v, worst_half))
    print("check_glb: %s, %d bytes, bones %s" % (
        glb_path.name, glb.size, ", ".join(sorted(got_bones))))
    return report()


def report():
    for e in errors:
        print("check_glb: FAIL " + e)
    if errors:
        return 1
    print("check_glb: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
