#!/usr/bin/env python3
"""Convert the player model to glTF for the realm website (Round 39 lane WG,
round39-web-data-plan.md §4.3).

Reads mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d with the B3D
reader of tools/r33_c3/gen_cloak_model.py and writes
tools/web_data/model/grug_visuals_character.glb:

  * one skinned mesh, one primitive per B3D mesh buffer in the model's
    texture order: "skin" (the body) and "cloak", each with its own material;
  * the skeleton (Body, Head, Arm_Left, Arm_Right, Leg_Right, Leg_Left,
    Cloak) under the root node Player, one bone per vertex as in the B3D;
  * one animation clip per player_api animation in CLIPS, timed in seconds
    at player_api's animation_speed, every clip starting at 0.

Coordinates follow Luanti's glTF loader exactly (irr/src/
CGLTFMeshFileLoader.cpp): it mirrors z (point (x, y, z) -> (x, y, -z),
quaternion (x, y, z, w) -> (x, y, -z, w)) and reverses the index list, so
this script applies the inverse of both and the engine rebuilds the B3D's own
mesh. In glTF terms the character stands on y = 0, up is +y, 10 units are
one node, and it faces -z.

Why not assimp (`assimp export ... -fglb2`, tried first): its geometry,
skeleton, skin and poses are right, but it writes one clip of all 221 frames
on the file's ANIM rate (60 fps, frame N at N/60 s) instead of player_api's
named ranges at 30 fps, one shared material for both buffers, and optional
extensions; check_glb.py fails it on the clips and the materials. Fixing
that afterwards means rewriting the glb anyway, so this script writes it.

    python3 tools/web_data/model/build_glb.py           # write the glb
    python3 tools/web_data/model/build_glb.py --check   # exit 1 if stale

Pure Python 3, no third-party module. Test: check_glb.py next to it.
"""
import argparse
import json
import math
import re
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools/r33_c3"))
import gen_cloak_model as b3d  # noqa: E402  (the B3D chunk reader)

SOURCE = REPO / "mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d"
PLAYER_API = REPO / "mods/BASE/player_api/init.lua"
TARGET = REPO / "tools/web_data/model/grug_visuals_character.glb"

CLIPS = ("stand", "walk")
# One material per mesh buffer, in the texture order of grug_visuals'
# registration (apply.lua: textures = {skin, cloak}).
MATERIALS = ("skin", "cloak")
COPYRIGHT = ("CC BY-SA 3.0: celeron55, MirceaKitsune, Jordach et al. "
             "(player_api character.b3d); cloak by the Grudgelands project")

FLOAT, UBYTE, USHORT = 5126, 5121, 5123
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963


def player_api_animations():
    """{name: (first, last)} and the speed of player_api's registration."""
    text = PLAYER_API.read_text()
    block = text[text.index('register_model("character.b3d"'):]
    speed = float(re.search(r"animation_speed\s*=\s*([\d.]+)", block).group(1))
    anims = {m.group(1): (int(m.group(2)), int(m.group(3))) for m in
             re.finditer(r"(\w+)\s*=\s*\{\s*x\s*=\s*(\d+)\s*,\s*y\s*=\s*(\d+)", block)}
    return anims, speed


# --- B3D -> engine data --------------------------------------------------------
def node_trs(chunk):
    """Bind translation, scale, rotation (w, x, y, z) of a NODE chunk."""
    name_len = chunk.head.index(b"\0") + 1
    v = struct.unpack("<10f", chunk.head[name_len:name_len + 40])
    return v[0:3], v[3:6], v[6:10]


def node_keys(chunk):
    """{engine frame: (pos, scale, rot)}; B3D file frame N is engine frame N-1."""
    keys = {}
    for k in chunk.kids:
        if k.tag != "KEYS":
            continue
        flags = struct.unpack("<i", k.raw[:4])[0]
        if flags != 7:
            raise SystemExit("build_glb: expected position, scale and rotation keys")
        for i in range((len(k.raw) - 4) // 44):
            frame, *v = struct.unpack("<i10f", k.raw[4 + 44 * i:48 + 44 * i])
            keys[frame - 1] = (tuple(v[0:3]), tuple(v[3:6]), tuple(v[6:10]))
    return keys


def bones_of(root_chunk):
    """Depth-first NODE chunks below the mesh node, with their parent's index."""
    out = []

    def visit(chunk, parent):
        for kid in chunk.kids:
            if kid.tag == "NODE":
                out.append((kid, parent))
                visit(kid, len(out) - 1)
    visit(root_chunk, None)
    return out


# --- handedness (the inverse of CGLTFMeshFileLoader's convertHandedness) -------
def gl_vec(v):
    return [v[0], v[1], -v[2]]


def gl_quat(wxyz):
    w, x, y, z = wxyz
    n = math.sqrt(w * w + x * x + y * y + z * z)
    return [x / n, y / n, -z / n, w / n]


def quat_matrix(q):
    """Column-major 4x4 of a glTF quaternion (x, y, z, w)."""
    x, y, z, w = q
    return [1 - 2 * (y * y + z * z), 2 * (x * y + w * z), 2 * (x * z - w * y), 0,
            2 * (x * y - w * z), 1 - 2 * (x * x + z * z), 2 * (y * z + w * x), 0,
            2 * (x * z + w * y), 2 * (y * z - w * x), 1 - 2 * (x * x + y * y), 0,
            0, 0, 0, 1]


def mat_mul(a, b):
    return [sum(a[4 * k + r] * b[4 * c + k] for k in range(4)) for c in range(4) for r in range(4)]


def local_matrix(t, q):
    m = quat_matrix(q)
    m[12], m[13], m[14] = t
    return m


def inverse_rigid(m):
    r = [m[0], m[4], m[8], 0, m[1], m[5], m[9], 0, m[2], m[6], m[10], 0, 0, 0, 0, 1]
    for row in range(3):
        r[12 + row] = -(r[row] * m[12] + r[4 + row] * m[13] + r[8 + row] * m[14])
    return r


def unit(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return [c / n for c in v]


# --- the binary buffer ----------------------------------------------------------
class Builder:
    def __init__(self):
        self.bin = bytearray()
        self.views, self.accessors = [], []

    def add(self, fmt, rows, type_, ctype, target=None, bounds=False):
        """One tightly packed bufferView + accessor; returns the accessor index."""
        while len(self.bin) % 4:
            self.bin.append(0)
        start = len(self.bin)
        for row in rows:
            self.bin += struct.pack("<" + fmt, *row)
        view = {"buffer": 0, "byteOffset": start, "byteLength": len(self.bin) - start}
        if target:
            view["target"] = target
        self.views.append(view)
        acc = {"bufferView": len(self.views) - 1, "componentType": ctype,
               "count": len(rows), "type": type_}
        if bounds:
            # min/max of the stored (float32-rounded) values
            size = struct.calcsize("<" + fmt)
            stored = [struct.unpack_from("<" + fmt, self.bin, start + i * size)
                      for i in range(len(rows))]
            acc["min"] = [min(r[c] for r in stored) for c in range(len(stored[0]))]
            acc["max"] = [max(r[c] for r in stored) for c in range(len(stored[0]))]
        self.accessors.append(acc)
        return len(self.accessors) - 1


def build():
    data = SOURCE.read_bytes()
    root = b3d.parse(data, 0, len(data))
    player = b3d.find_node(root, "Player")
    mesh = b3d.kid(player, "MESH")
    t, s, r = node_trs(player)
    if any(abs(a - b) > 1e-6 for a, b in zip(t + s + r, (0, 0, 0, 1, 1, 1, 1, 0, 0, 0))):
        raise SystemExit("build_glb: the mesh node is not at the origin")

    vrts = b3d.kid(mesh, "VRTS")
    if struct.unpack("<3i", vrts.raw[:12]) != (1, 1, 2):
        raise SystemExit("build_glb: expected normals and one UV set")
    verts = [struct.unpack_from("<8f", vrts.raw, 12 + 32 * i)
             for i in range((len(vrts.raw) - 12) // 32)]
    buffers = [[struct.unpack_from("<3i", k.raw, 4 + 12 * i) for i in range((len(k.raw) - 4) // 12)]
               for k in mesh.kids if k.tag == "TRIS"]
    if len(buffers) != len(MATERIALS):
        raise SystemExit("build_glb: %d mesh buffers, materials for %d" % (len(buffers), len(MATERIALS)))

    bones = bones_of(player)
    bone_of = {}
    for j, (chunk, _) in enumerate(bones):
        for kid in chunk.kids:
            if kid.tag == "BONE":
                for i in range(len(kid.raw) // 8):
                    vid, w = struct.unpack_from("<if", kid.raw, 8 * i)
                    if w == 0:
                        continue
                    if w != 1 or vid in bone_of:
                        raise SystemExit("build_glb: vertex %d is not on exactly one bone" % vid)
                    bone_of[vid] = j

    out = Builder()
    gl = {"asset": {"version": "2.0", "generator": "tools/web_data/model/build_glb.py",
                    "copyright": COPYRIGHT},
          "scene": 0, "scenes": [{"name": "Scene", "nodes": [0]}]}

    # Nodes: 0 = Player (the skinned mesh), 1.. = the bones depth-first.
    nodes = [{"name": "Player", "mesh": 0, "skin": 0, "children": []}]
    globals_ = []
    for j, (chunk, parent) in enumerate(bones):
        t, s, r = node_trs(chunk)
        if any(abs(c - 1) > 1e-6 for c in s):
            raise SystemExit("build_glb: scaled bind pose on %s" % b3d.node_name(chunk))
        node = {"name": b3d.node_name(chunk), "translation": gl_vec(t), "rotation": gl_quat(r)}
        nodes.append(node)
        (nodes[0] if parent is None else nodes[parent + 1]).setdefault("children", []).append(j + 1)
        local = local_matrix(node["translation"], node["rotation"])
        globals_.append(local if parent is None else mat_mul(globals_[parent], local))
    gl["nodes"] = nodes
    gl["skins"] = [{"name": "Armature", "joints": list(range(1, len(bones) + 1)),
                    "inverseBindMatrices": out.add("16f", [inverse_rigid(m) for m in globals_],
                                                   "MAT4", FLOAT)}]

    # Mesh: one primitive per buffer, its vertices in first-use order.
    primitives = []
    for k, tris in enumerate(buffers):
        order = []
        for tri in tris:
            for v in tri:
                if v not in order:
                    order.append(v)
        local = {v: i for i, v in enumerate(order)}
        if any(v not in bone_of for v in order):
            raise SystemExit("build_glb: unweighted vertex in buffer %d" % k)
        attrs = {
            "POSITION": out.add("3f", [gl_vec(verts[v][0:3]) for v in order], "VEC3", FLOAT,
                                ARRAY_BUFFER, bounds=True),
            "NORMAL": out.add("3f", [gl_vec(unit(verts[v][3:6])) for v in order], "VEC3", FLOAT,
                              ARRAY_BUFFER),
            "TEXCOORD_0": out.add("2f", [verts[v][6:8] for v in order], "VEC2", FLOAT, ARRAY_BUFFER),
            "JOINTS_0": out.add("4B", [(bone_of[v], 0, 0, 0) for v in order], "VEC4", UBYTE,
                                ARRAY_BUFFER),
            "WEIGHTS_0": out.add("4f", [(1, 0, 0, 0) for _ in order], "VEC4", FLOAT, ARRAY_BUFFER),
        }
        # The reversed list: the engine reverses it back to the B3D's.
        indices = [local[v] for tri in tris for v in tri][::-1]
        primitives.append({"attributes": attrs, "material": k, "mode": 4,
                           "indices": out.add("H", [(i,) for i in indices], "SCALAR", USHORT,
                                              ELEMENT_ARRAY_BUFFER)})
    gl["meshes"] = [{"name": "Character", "primitives": primitives}]
    # Textures come from the game (Lua) or the website, never from the file:
    # Luanti warns on images. Alpha-tested like Luanti's entities.
    gl["materials"] = [{"name": name, "alphaMode": "MASK", "alphaCutoff": 0.5,
                        "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1],
                                                 "metallicFactor": 0, "roughnessFactor": 1}}
                       for name in MATERIALS]

    # Clips.
    anims, speed = player_api_animations()
    keys = [node_keys(chunk) for chunk, _ in bones]
    gl["animations"] = []
    for name in CLIPS:
        first, last = anims[name]
        frames = range(first, last + 1)
        times = out.add("f", [((f - first) / speed,) for f in frames], "SCALAR", FLOAT, bounds=True)
        samplers, channels = [], []
        for j, bone_keys in enumerate(keys):
            if any(abs(c - 1) > 1e-6 for f in frames for c in bone_keys[f][1]):
                raise SystemExit("build_glb: scale keys on %s" % nodes[j + 1]["name"])
            rots, prev = [], None
            for f in frames:
                q = gl_quat(bone_keys[f][2])
                # Same rotation, sign chosen next to the previous key, so
                # every interpolator takes the short way.
                if prev and sum(a * b for a, b in zip(q, prev)) < 0:
                    q = [-c for c in q]
                rots.append(q)
                prev = q
            for path, rows, fmt in (("translation", [gl_vec(bone_keys[f][0]) for f in frames], "3f"),
                                    ("rotation", rots, "4f")):
                samplers.append({"input": times, "interpolation": "LINEAR",
                                 "output": out.add(fmt, rows, "VEC%s" % fmt[0], FLOAT)})
                channels.append({"sampler": len(samplers) - 1,
                                 "target": {"node": j + 1, "path": path}})
        gl["animations"].append({"name": name, "channels": channels, "samplers": samplers,
                                 "extras": {"luanti_frames": [first, last], "fps": speed}})

    gl["accessors"], gl["bufferViews"] = out.accessors, out.views
    while len(out.bin) % 4:
        out.bin.append(0)
    gl["buffers"] = [{"byteLength": len(out.bin)}]
    text = json.dumps(gl, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(out.bin)
    return (b"glTF" + struct.pack("<II", 2, total)
            + struct.pack("<I", len(text)) + b"JSON" + text
            + struct.pack("<I", len(out.bin)) + b"BIN\0" + bytes(out.bin))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true",
                        help="compare with the committed glb, exit 1 if it differs")
    args = parser.parse_args()
    glb = build()
    if args.check:
        if not TARGET.exists() or TARGET.read_bytes() != glb:
            print("build_glb: %s is stale, re-run without --check" % TARGET.relative_to(REPO))
            return 1
        print("build_glb: glb up to date")
        return 0
    TARGET.write_bytes(glb)
    print("build_glb: wrote %s (%d bytes)" % (TARGET.relative_to(REPO), len(glb)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
