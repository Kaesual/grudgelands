#!/usr/bin/env python3
"""Build the three.js town viewer as one self-contained HTML file.

    python3 tools/building_templates/viewer/build_viewer.py -o /tmp/viewer.html
    python3 tools/building_templates/viewer/build_viewer.py dawnmere hearthpine -o out.html

Each positional argument is a start-town key (``dawnmere`` resolves to
``mods/MAPGEN/grug_mapgen/wp40/r7_dawnmere_blueprint.lua``) or a path to any
blueprint chunk; with none, all six start towns are built. The blueprints run
through ``export_blueprint.lua`` (plain LuaJIT, no engine), so the page always
shows exactly what the Lua code produces.

Node shapes come from ``tools/building_templates/nodes.json``, the real node
registry dumped by the ``node_dump`` probe (see ../README.md); textures are
resolved with the modifier support of ``render_blueprint.TextureBank`` and
meshes (.obj/.b3d) are read from the mods' ``models/`` directories. Python 3
plus Pillow only.
"""

import argparse
import base64
import io
import json
import os
import re
import shutil
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
WP13 = os.path.join(REPO, "tools", "wp13")
sys.path.insert(0, WP13)

from PIL import Image  # noqa: E402
import render_blueprint  # noqa: E402

BLUEPRINT_DIR = os.path.join(REPO, "mods", "MAPGEN", "grug_mapgen", "wp40")
NODES_JSON = os.path.join(os.path.dirname(HERE), "nodes.json")
TEMPLATE = os.path.join(HERE, "town.html")
RENDERER = os.path.join(HERE, "renderer.js")

# The six start towns in the order the viewer lists them.
START_TOWNS = [
    ("dawnmere", "Dawnmere Fields", "human"),
    ("hearthpine", "Hearthpine", "dwarf"),
    ("silverleaf", "Silverleaf Glade", "elf"),
    ("sunscar", "Sunscar", "orc"),
    ("kapok", "Kapok Cradle", "troll"),
    ("stillgrave", "Stillgrave Hollow", "undead"),
]

# Drawtypes the viewer draws; everything else (air, liquids' flowing parts,
# firelike, ...) is skipped and reported.
DRAWN = {"normal", "allfaces", "allfaces_optional", "glasslike",
         "glasslike_framed", "glasslike_framed_optional", "liquid",
         "nodebox", "mesh", "plantlike", "torchlike", "signlike"}


# Groups the "Trees & plants" toggle hides. Crops (group `plant`) are part of
# the fields' layout and stay.
VEG_GROUPS = ("tree", "leaves", "leafdecay", "flora", "grass", "sapling",
              "junglegrass", "dry_grass")


def find_lua():
    for cand in ("luajit", os.path.join(REPO, "tools", "bin", "lua51"),
                 "lua5.1", "lua"):
        if shutil.which(cand) or os.path.exists(cand):
            return cand
    sys.exit("no Lua 5.1 interpreter found")


def export(lua, path):
    proc = subprocess.run(
        [lua, os.path.join(HERE, "export_blueprint.lua"), path],
        cwd=REPO, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit("export failed for %s:\n%s" % (path, proc.stderr))
    bounds, boxes, points, cells = None, [], [], []
    for line in proc.stdout.splitlines():
        f = line.split("\t")
        if f[0] == "#bounds":
            bounds = [int(v) for v in f[1:7]]
        elif f[0] == "#box":
            boxes.append([f[1]] + [int(v) for v in f[2:8]])
        elif f[0] == "#point":
            points.append([f[1]] + [int(v) for v in f[2:5]])
        elif f[0] and not f[0].startswith("#"):
            cells.append((int(f[0]), int(f[1]), int(f[2]), f[3], int(f[4])))
    return bounds, boxes, points, cells


# -- textures -------------------------------------------------------------

class Textures:
    def __init__(self):
        self.bank = render_blueprint.TextureBank(render_blueprint.DEFAULT_TILES)
        self.specs = {}      # key -> index
        self.images = []     # base64 PNG data URIs
        self.missing = set()

    def index(self, tile):
        """Texture index for one tile entry (string or table), or -1."""
        if isinstance(tile, dict):
            spec = tile.get("name") or tile.get("image") or ""
            anim = tile.get("animation") or {}
        else:
            spec, anim = tile or "", {}
        if not spec:
            return -1
        key = spec + "|" + json.dumps(anim, sort_keys=True)
        if key in self.specs:
            return self.specs[key]
        img = self.bank.texture(spec)
        if img is None:
            self.missing.add(spec)
            self.specs[key] = -1
            return -1
        if anim.get("type") == "vertical_frames":
            w = img.width
            fh = max(1, round(w * anim.get("aspect_h", 16) / max(1, anim.get("aspect_w", 16))))
            img = img.crop((0, 0, w, min(fh, img.height)))
        elif anim.get("type") == "sheet_2d":
            fw = img.width // max(1, anim.get("frames_w", 1))
            fh = img.height // max(1, anim.get("frames_h", 1))
            img = img.crop((0, 0, fw, fh))
        buf = io.BytesIO()
        img.save(buf, format="PNG", optimize=True)
        self.images.append("data:image/png;base64," +
                           base64.b64encode(buf.getvalue()).decode("ascii"))
        self.specs[key] = len(self.images) - 1
        return self.specs[key]


# -- meshes ---------------------------------------------------------------

def find_model(name):
    for root in (os.path.join(REPO, "mods"),):
        for dirpath, _, files in os.walk(root):
            if os.path.basename(dirpath) == "models" and name in files:
                return os.path.join(dirpath, name)
    return None


def parse_obj(path):
    """Triangles per material buffer as flat [x,y,z,u,v,...] lists.

    Luanti's (Irrlicht's) OBJ loader mirrors X and flips V; the V flip
    cancels against three.js's bottom-up V, so only X is negated here.
    """
    verts, uvs, buffers, current = [], [], [], None
    mtl_index = {}
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            p = line.split()
            if not p:
                continue
            if p[0] == "v":
                verts.append((-float(p[1]), float(p[2]), float(p[3])))
            elif p[0] == "vt":
                uvs.append((float(p[1]), float(p[2])))
            elif p[0] == "usemtl":
                if p[1] not in mtl_index:
                    mtl_index[p[1]] = len(buffers)
                    buffers.append([])
                current = buffers[mtl_index[p[1]]]
            elif p[0] == "f":
                if current is None:
                    buffers.append([])
                    current = buffers[-1]
                idx = []
                for item in p[1:]:
                    parts = item.split("/")
                    vi = int(parts[0])
                    ti = int(parts[1]) if len(parts) > 1 and parts[1] else 0
                    vi = vi - 1 if vi > 0 else len(verts) + vi
                    ti = (ti - 1 if ti > 0 else len(uvs) + ti) if ti else None
                    idx.append((vi, ti))
                # Mirroring X flips the winding; emit fans reversed.
                for k in range(1, len(idx) - 1):
                    for vi, ti in (idx[0], idx[k + 1], idx[k]):
                        x, y, z = verts[vi]
                        u, v = uvs[ti] if ti is not None else (0.0, 0.0)
                        current.extend((x, y, z, u, v))
    return [b for b in buffers if b]


def _mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def _node_matrix(pos, scale, quat):
    """Local NODE transform T * R * S as Irrlicht builds it.

    B3D stores the rotation as (w, x, y, z); Irrlicht's quaternion matrix is
    the transpose of the textbook one, which is what makes door_a.b3d's
    90 degree X turn stand the door up (x, y, z) -> (x, z, -y).
    """
    w, x, y, z = quat
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
         [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
         [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)]]
    rt = [[r[j][i] for j in range(3)] for i in range(3)]
    return [[rt[i][0] * scale[0], rt[i][1] * scale[1], rt[i][2] * scale[2], pos[i]]
            for i in range(3)] + [[0.0, 0.0, 0.0, 1.0]]


def parse_b3d(path):
    """Static B3D (doors): triangles per brush, every vertex taken through
    the full NODE transform chain (translation, rotation, scale)."""
    data = open(path, "rb").read()
    buffers = {}
    identity = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]

    def read_cstr(pos):
        end = data.index(b"\0", pos)
        return data[pos:end].decode("latin-1"), end + 1

    def walk(pos, end, matrix):
        while pos + 8 <= end:
            tag = data[pos:pos + 4].decode("latin-1")
            size = struct.unpack_from("<i", data, pos + 4)[0]
            body, nxt = pos + 8, pos + 8 + size
            if tag == "BB3D":
                walk(body + 4, nxt, matrix)
            elif tag == "NODE":
                _, q = read_cstr(body)
                vals = struct.unpack_from("<10f", data, q)
                local = _node_matrix(vals[0:3], vals[3:6], vals[6:10])
                walk(q + 40, nxt, _mat_mul(matrix, local))
            elif tag == "MESH":
                walk(body + 4, nxt, matrix)
            elif tag == "VRTS":
                flags, sets, ssize = struct.unpack_from("<3i", data, body)
                q = body + 12
                stride = 12 + (12 if flags & 1 else 0) + (16 if flags & 2 else 0) + 4 * sets * ssize
                walk.verts = []
                m = matrix
                while q + stride <= nxt:
                    x, y, z = struct.unpack_from("<3f", data, q)
                    t = q + 12 + (12 if flags & 1 else 0) + (16 if flags & 2 else 0)
                    u, v = struct.unpack_from("<2f", data, t) if sets and ssize >= 2 else (0.0, 0.0)
                    walk.verts.append(tuple(
                        m[i][0] * x + m[i][1] * y + m[i][2] * z + m[i][3] for i in range(3)
                    ) + (u, 1.0 - v))
                    q += stride
            elif tag == "TRIS":
                brush = struct.unpack_from("<i", data, body)[0]
                out = buffers.setdefault(brush, [])
                q = body + 4
                while q + 12 <= nxt:
                    # Irrlicht keeps the file order, and in the viewer's
                    # frame that order already faces outward.
                    for i in struct.unpack_from("<3i", data, q):
                        out.extend(walk.verts[i])
                    q += 12
            pos = nxt
    walk.verts = []
    walk(0, len(data), identity)
    return [buffers[k] for k in sorted(buffers)]


def load_mesh(name):
    path = find_model(name)
    if path is None:
        return None
    if name.endswith(".obj"):
        bufs = parse_obj(path)
    elif name.endswith(".b3d"):
        bufs = parse_b3d(path)
    else:
        return None
    return [[round(v, 5) for v in b] for b in bufs]


# -- node types -----------------------------------------------------------

def tile_list(def_tiles):
    tiles = list(def_tiles or [])
    if not tiles:
        return []
    while len(tiles) < 6:
        tiles.append(tiles[-1])
    return tiles[:6]


def as_boxes(value):
    if not value:
        return []
    if isinstance(value[0], (int, float)):
        return [list(value)]
    return [list(b) for b in value]


def matches(entry, name, groups):
    if entry.startswith("group:"):
        return groups.get(entry[6:], 0) not in (0, None)
    return entry == name


def build_types(names, registry, aliases, textures, meshes):
    types, report = [], {"skipped": {}, "missing_mesh": set()}
    resolved = [aliases.get(n, n) for n in names]
    for name, real in zip(names, resolved):
        d = registry.get(real)
        if d is None:
            report["skipped"][name] = "unknown"
            types.append(None)
            continue
        dt = d.get("drawtype", "normal")
        if dt not in DRAWN:
            report["skipped"][name] = dt
            types.append(None)
            continue
        alpha = d.get("use_texture_alpha")
        if alpha is True:
            alpha = "blend"
        t = {
            "name": name,
            "dt": dt,
            "p2": d.get("paramtype2", "none"),
            "tex": [textures.index(tl) for tl in tile_list(d.get("tiles"))],
            "world": [bool(isinstance(tl, dict) and tl.get("align_style") == "world")
                      for tl in tile_list(d.get("tiles"))],
            "alpha": alpha or ("clip" if dt in ("plantlike", "torchlike", "signlike",
                                                 "allfaces_optional", "allfaces",
                                                 "glasslike", "glasslike_framed",
                                                 "glasslike_framed_optional", "mesh",
                                                 "nodebox") else "opaque"),
            "vs": d.get("visual_scale", 1.0) or 1.0,
            "light": d.get("light_source", 0) or 0,
        }
        overlay = tile_list(d.get("overlay_tiles"))
        if overlay:
            t["ovl"] = [textures.index(tl) for tl in overlay]
        if dt == "nodebox":
            nb = d.get("node_box") or {}
            kind = nb.get("type", "regular")
            if kind in ("fixed", "leveled"):
                t["boxes"] = as_boxes(nb.get("fixed"))
            elif kind == "connected":
                t["boxes"] = as_boxes(nb.get("fixed"))
                conn = {}
                for side in ("top", "bottom", "front", "left", "back", "right"):
                    for prefix in ("connect_", "disconnected_"):
                        bx = as_boxes(nb.get(prefix + side))
                        if bx:
                            conn[prefix + side] = bx
                for key in ("disconnected", "disconnected_sides"):
                    bx = as_boxes(nb.get(key))
                    if bx:
                        conn[key] = bx
                t["conn"] = conn
                t["connects_to"] = d.get("connects_to") or []
                t["connect_sides"] = d.get("connect_sides")
            elif kind == "wallmounted":
                t["wall"] = {k: as_boxes(nb.get(k)) for k in
                             ("wall_top", "wall_bottom", "wall_side")}
            else:  # regular
                t["boxes"] = [[-0.5, -0.5, -0.5, 0.5, 0.5, 0.5]]
        elif dt == "mesh":
            mesh = d.get("mesh") or ""
            if mesh not in meshes:
                meshes[mesh] = load_mesh(mesh)
            if meshes[mesh] is None:
                report["missing_mesh"].add(mesh)
                t["dt"] = "nodebox"
                t["boxes"] = [[-0.5, -0.5, -0.5, 0.5, 0.5, 0.5]]
            else:
                t["mesh"] = mesh
                # Mesh buffer i draws with tiles[i]; tile_list pads to 6.
                t["tex"] = [textures.index(tl) for tl in
                            (list(d.get("tiles") or []) + [None] * 8)[:8]]
                last = next((x for x in reversed(t["tex"]) if x >= 0), -1)
                t["tex"] = [x if x >= 0 else last for x in t["tex"]]
        groups = d.get("groups") or {}
        if (any(groups.get(g) for g in VEG_GROUPS) or
                real.startswith("grug_trees:") or "bush" in real or
                real == "default:apple"):
            t["veg"] = 1
        t["_groups"] = groups
        t["_real"] = real
        types.append(t)

    # Resolve connects_to against the types actually present.
    for t in types:
        if not t or "connects_to" not in t:
            continue
        targets = []
        for j, other in enumerate(types):
            if other and any(matches(e, other["_real"], other["_groups"])
                             for e in t["connects_to"]):
                targets.append(j)
        t["ct"] = targets
        del t["connects_to"]
    for t in types:
        if t:
            del t["_groups"]
            del t["_real"]
    return types, report


def pack_cells(entry, cells, type_index, names):
    """Pack (x, y, z, name, param2) cells into a town entry."""
    for c in cells:
        if c[3] not in type_index:
            type_index[c[3]] = len(names)
            names.append(c[3])
    xs = bytearray()
    for x, y, z, name, p2 in cells:
        xs += struct.pack("<hhhHB", x, y, z, type_index[name], p2)
    entry["count"] = len(cells)
    entry["cells"] = base64.b64encode(bytes(xs)).decode("ascii")
    return entry


def pack_town(key, label, race, path, lua, type_index, names):
    bounds, boxes, points, cells = export(lua, path)
    return pack_cells({
        "key": key, "label": label, "race": race,
        "source": os.path.relpath(path, REPO),
        "bounds": bounds, "boxes": boxes, "points": points,
    }, cells, type_index, names)


DIFF_KINDS = ["added", "removed", "replaced", "turned"]


def pack_reworked(base, spec, lua, type_index, names):
    """A town entry built from a workshop `after` export, with its diff.

    `spec` is TOWN=BASELINE,AFTER[,LABEL]. The export is moved into the
    blueprint's local frame with the placement diff_town finds, and cropped
    to the blueprint square (and nothing below its lowest layer).
    """
    import diff_town  # imports this module; load it lazily
    town, _, files = spec.partition("=")
    parts = files.split(",")
    if len(parts) < 2:
        sys.exit("--compare wants TOWN=BASELINE,AFTER[,LABEL]")
    baseline, after = parts[0], parts[1]
    label = parts[2] if len(parts) > 2 else "reworked"
    result = diff_town.diff(town, baseline, after, lua)
    sys.stderr.write(diff_town.summary(result).splitlines()[1] + "\n")
    meta, cells = diff_town.load_export(after)
    ax, az = meta["anchor"]
    dy, r = result["placement"]["dy"], result["placement"]["turns"]
    b = base["bounds"]
    local = []
    for (wx, wy, wz), (name, p2) in cells.items():
        lx, lz = diff_town.untrun(wx - ax, wz - az, r)
        ly = wy - dy
        if b[0] <= lx <= b[3] and b[2] <= lz <= b[5] and ly >= b[1]:
            local.append((lx, ly, lz, name, p2))
    local.sort(key=lambda c: (c[1], c[2], c[0]))
    key = re.sub(r"[^\w-]", "_", "%s-%s" % (town, label))
    entry = {
        "key": key, "label": "%s \u00b7 %s" % (base["label"], label), "race": base["race"],
        "source": os.path.basename(after),
        "bounds": base["bounds"], "boxes": base["boxes"], "points": base["points"],
        "partner": base["key"],
        "diff": [[c["x"], c["y"], c["z"], DIFF_KINDS.index(c["kind"]),
                  "%s %d" % tuple(c["before"]), "%s %d" % tuple(c["after"])]
                 for c in result["changes"]],
        "noise": sum(result["noise"].values()),
    }
    base["partner"] = key
    return pack_cells(entry, local, type_index, names)


def inline_renderer(html):
    """Put renderer.js into a page at ``__RENDERER__``.

    The page's own module script already imports ``three`` and the orbit
    controls, so the module's import lines go and its ``export`` keywords
    become plain declarations in the page's scope.
    """
    with open(RENDERER, "r", encoding="utf-8") as fh:
        src = fh.read()
    src = re.sub(r"^import [^\n]*\n", "", src, flags=re.M)
    src = re.sub(r"^export (?=(?:async )?function |const |let |class )", "", src, flags=re.M)
    if re.search(r"^\s*(?:import|export)\b", src, flags=re.M):
        sys.exit("renderer.js: an import or export the inliner does not handle")
    return html.replace("__RENDERER__", src.replace("</", "<\\/"))


def write_page(path, template, title, payload, standalone):
    """Fill a page template (title, renderer, payload) and write it."""
    with open(template, "r", encoding="utf-8") as fh:
        html = fh.read()
    blob = json.dumps(payload, separators=(",", ":")).replace("</", "<\\/")
    html = inline_renderer(html.replace("__TITLE__", title))
    html = html.replace("__PAYLOAD__", blob)
    if standalone:
        html = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
                '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
                '</head>\n<body>\n' + html + '\n</body>\n</html>\n')
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(html)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("towns", nargs="*", help="start-town keys or blueprint paths")
    ap.add_argument("-o", "--out", required=True, help="output HTML file")
    ap.add_argument("--title", default="Grudgelands Start Towns")
    ap.add_argument("--compare", action="append", default=[], metavar="TOWN=BASELINE,AFTER[,LABEL]",
                    help="add the town as rebuilt in a workshop world, with its diff "
                         "against the baseline export (repeatable)")
    ap.add_argument("--standalone", action="store_true",
                    help="wrap in a full HTML document for opening the file locally "
                         "(the Artifact publisher adds that wrapper itself)")
    args = ap.parse_args(argv)

    known = {k: (k, label, race) for k, label, race in START_TOWNS}
    picks = args.towns or [k for k, _, _ in START_TOWNS]
    jobs = []
    for pick in picks:
        if pick in known:
            k, label, race = known[pick]
            jobs.append((k, label, race,
                         os.path.join(BLUEPRINT_DIR, "r7_%s_blueprint.lua" % k)))
        elif os.path.exists(pick):
            base = os.path.basename(pick).replace("_blueprint.lua", "").replace("r7_", "")
            base = re.sub(r"[^\w-]", "_", base)  # view codes accept [\w-]+
            jobs.append((base, base, "", os.path.abspath(pick)))
        else:
            sys.exit("unknown town or path: %s" % pick)

    with open(NODES_JSON, "r", encoding="utf-8") as fh:
        reg = json.load(fh)
    registry, aliases = reg["nodes"], reg.get("aliases", {})

    lua = find_lua()
    textures, meshes, type_index, names = Textures(), {}, {}, []
    compare_towns = [spec.partition("=")[0] for spec in args.compare]
    for town in compare_towns:
        if town in known and not any(j[0] == town for j in jobs):
            k, label, race = known[town]
            jobs.append((k, label, race,
                         os.path.join(BLUEPRINT_DIR, "r7_%s_blueprint.lua" % k)))
    towns = []
    for k, label, race, path in jobs:
        base = pack_town(k, label, race, path, lua, type_index, names)
        towns.append(base)
        for spec in args.compare:
            if spec.partition("=")[0] == k:
                towns.append(pack_reworked(base, spec, lua, type_index, names))
    types, report = build_types(names, registry, aliases, textures, meshes)

    payload = {
        "towns": towns,
        "types": types,
        "textures": textures.images,
        "meshes": {k: v for k, v in meshes.items() if v is not None},
    }
    write_page(args.out, TEMPLATE, args.title, payload, args.standalone)

    sys.stderr.write("towns: %s\n" % ", ".join("%s (%d cells)" % (t["key"], t["count"])
                                               for t in towns))
    sys.stderr.write("node types: %d, textures: %d, meshes: %d, size: %.1f MB\n" % (
        len(types), len(textures.images), len(payload["meshes"]),
        os.path.getsize(args.out) / 1e6))
    for name, why in sorted(report["skipped"].items()):
        sys.stderr.write("not drawn: %s (%s)\n" % (name, why))
    for mesh in sorted(report["missing_mesh"]):
        sys.stderr.write("mesh not found, drawn as cube: %s\n" % mesh)
    for spec in sorted(textures.missing):
        sys.stderr.write("texture missing: %s\n" % spec)
    return 0


if __name__ == "__main__":
    sys.exit(main())
