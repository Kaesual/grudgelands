#!/usr/bin/env python3
"""Round 51 lane WRECK, design step: the shipwreck shapes as data.

    python3 -I tools/r51_wreck/shapes.py           # write tools/r51_wreck/shapes/*.json
    python3 -I tools/r51_wreck/shapes.py --check   # fail if a file is stale
    python3 -I tools/r51_wreck/shapes.py --print   # print each shape's layers

Every shape is one small JSON file the build step turns into a schematic
mechanically (format in DESIGN.md "Shape files"): a palette of one-letter
cells (node name + param2; "." keeps what the world has there) and the
layers from the bottom up, each a list of rows (z) of letters (x). x runs
along the ship (the bow at +x), z across it, y up. `seabed` is the number of
layers that lie below the top of the sand: layer `seabed` is the first one
above it.

The hull, bow and stern come from one hull form (a small single-masted coastal
ship, our own design): a log keel, log ribs every third station, a shell of
waterlogged planks, a planked deck with a raised stern deck and a one-block
rail. Each shape heels the form about its long axis, breaks it (planks gone
between the ribs, deck holes, a jagged break for the bow and stern parts) and
sinks its lowest layers into the sand. The debris field is laid out by hand.
Damage comes from a fixed integer hash, so the files are reproducible.
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "shapes")

# The proposed nodes (DESIGN.md "Node list"). Logs are facedir: 0 upright,
# 4 along z, 12 along x. Rooted nodes: the mast is leveled (height =
# param2 / 16 nodes), the small details are one node high (param2 0).
N_PLANKS = "grug_nodes:wreck_planks"
N_ALGAE_PLANKS = "grug_nodes:wreck_planks_algae"
N_LOG = "grug_nodes:wreck_log"
N_MAST = "grug_nodes:wreck_mast"
N_ROPE = "grug_nodes:wreck_rope"
N_SAIL = "grug_nodes:wreck_sail"
N_ALGAE = "grug_nodes:wreck_algae"
N_BALLAST = "default:mossycobble"

PALETTE = {
    ".": None,
    "P": {"name": N_PLANKS, "param2": 0},
    "A": {"name": N_ALGAE_PLANKS, "param2": 0},
    "L": {"name": N_LOG, "param2": 12},
    "Z": {"name": N_LOG, "param2": 4},
    "Y": {"name": N_LOG, "param2": 0},
    "R": {"name": N_ROPE, "param2": 0},
    "S": {"name": N_SAIL, "param2": 0},
    "G": {"name": N_ALGAE, "param2": 0},
    "C": {"name": N_BALLAST, "param2": 0},
}
# masts per shape: letter -> height in nodes (param2 = 16 * height, at most 255)
MASTS = {"M": 15.9375, "m": 3.0, "n": 4.5, "k": 2.0}
for letter, height in MASTS.items():
    PALETTE[letter] = {"name": N_MAST, "param2": min(255, int(round(height * 16)))}


def mix(*values):
    """A small deterministic integer hash in [0, 1)."""
    h = 2166136261
    for v in values:
        h = ((h ^ (v & 0xffffffff)) * 16777619) & 0xffffffff
        h ^= h >> 13
        h = (h * 0x5bd1e995) & 0xffffffff
        h ^= h >> 15
    return h / 4294967296.0


class Hull:
    """The hull form in its own frame: x along the ship, u across, v up from
    the keel's bottom."""

    def __init__(self, length=20, beam=3.3, depth=4.4, sheer=1.4, castle=(5, 2)):
        self.length, self.beam, self.depth, self.sheer = length, beam, depth, sheer
        self.castle_len, self.castle_h = castle

    def keel(self, x):
        n = self.length - 1
        bow = max(0.0, (x - (n - 6)) / 6.0)
        stern = max(0.0, (2.0 - x) / 2.0)
        return 3.0 * bow * bow + 0.5 * stern

    def deck(self, x):
        n = self.length - 1
        mid = n / 2.0
        d = self.depth + self.sheer * ((x - mid) / mid) ** 2
        bow = max(0.0, (x - 0.7 * n) / (0.3 * n))
        d += 1.2 * bow * bow            # the bow rises
        if x < self.castle_len:
            d += self.castle_h
        return d

    def half_width(self, x):
        n = self.length - 1
        a, b = 0.2 * n, 0.45 * n
        if x < a:
            return self.beam * (0.7 + 0.3 * x / a)
        if x <= b:
            return self.beam
        t = (x - b) / (n - b)
        return self.beam * math.cos(t * math.pi / 2) ** 0.8 + 0.2

    def width_at(self, x, v):
        k, d = self.keel(x), self.deck(x)
        t = min(1.0, max(0.0, (v - k) / max(0.5, d - k)))
        return max(0.45, self.half_width(x) * t ** 0.38)


def hull_cells(hull, heel_deg, seed, keep_x=None, cut=None, holes=(), deck_holes=0.18,
               rail_loss=0.35):
    """Rasterize the hull form heeled by heel_deg into {(x, y, z): letter}.

    keep_x (lo, hi) keeps that x range; cut = ('above'|'below', x) breaks the
    hull there with a jagged edge (ribs and keel reach one node further).
    holes: list of (x0, x1, side, chance) shell regions whose planks go."""
    heel = math.radians(heel_deg)
    cs, sn = math.cos(heel), math.sin(heel)
    axis = hull.depth * 0.45
    L = hull.length
    zr = int(math.ceil(hull.beam + 4))
    y0, y1 = -5, int(math.ceil(hull.depth + hull.castle_h + hull.sheer + 5))

    def frame(y, z):
        dy = y - axis
        return axis + dy * cs + z * sn, -dy * sn + z * cs   # v, u

    def solid(x, y, z):
        if x < 0 or x >= L:
            return False
        v, u = frame(y, z)
        if v < hull.keel(x) - 0.5 or v > hull.deck(x) + 0.49:
            return False
        return abs(u) < hull.width_at(x, v) + 0.5

    def rail(x, y, z):
        if x < 0 or x >= L:
            return False
        v, u = frame(y, z)
        d = hull.deck(x)
        if not (d + 0.49 < v <= d + 1.49):
            return False
        w = hull.width_at(x, d)
        return w - 0.5 <= abs(u) < w + 0.5

    cells = {}
    for x in range(L):
        for y in range(y0, y1):
            for z in range(-zr, zr + 1):
                if solid(x, y, z):
                    boundary = any(not solid(x + dx, y + dy, z + dz) for dx, dy, dz in
                                   ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)))
                    if not boundary:
                        continue
                    v, u = frame(y, z)
                    k, d = hull.keel(x), hull.deck(x)
                    w = hull.width_at(x, v)
                    if abs(u) < 0.75 and v < k + 0.9:
                        letter = "L" if x < L - 2 else "Y"
                    elif x % 3 == 1 and 1 < x < L - 3 and v < d - 0.5:
                        letter = "Y" if abs(u) > w * 0.62 else "Z"
                    elif abs(u) < 0.6 and x == L - 1:
                        letter = "Y"        # the stem
                    else:
                        letter = "P"
                    cells[(x, y, z)] = letter
                elif rail(x, y, z):
                    cells[(x, y, z)] = "P"
    # the break of a part
    if cut is not None:
        side, cx = cut
        for (x, y, z), letter in list(cells.items()):
            edge = cx + int(mix(seed, 7, y, z) * 3) - 1
            if letter in "LYZ":
                edge += 1 if side == "above" else -1
            if (side == "above" and x < edge) or (side == "below" and x > edge):
                del cells[(x, y, z)]
    if keep_x is not None:
        for key in [k for k in cells if not keep_x[0] <= k[0] <= keep_x[1]]:
            del cells[key]
    # planks lost between the ribs, deck holes, a broken rail
    for (x, y, z), letter in list(cells.items()):
        if letter != "P":
            continue
        v, u = frame(y, z)
        d = hull.deck(x)
        is_rail = v > d + 0.49
        is_deck = not is_rail and v >= d - 0.5 and abs(u) < hull.width_at(x, d) - 0.5
        r = mix(seed, x, y, z)
        if is_rail and r < rail_loss:
            del cells[(x, y, z)]
        elif is_deck and r < deck_holes:
            del cells[(x, y, z)]
        elif not is_deck and not is_rail:
            for x0, x1, s, chance in holes:
                if x0 <= x <= x1 and u * s > 0.3 and v > hull.keel(x) + 0.9 and r < chance:
                    del cells[(x, y, z)]
                    break
    return cells, frame


def top_deck_cell(cells, frame, hull, x, u_want=0.0, height=1):
    """The highest deck plank of station x nearest the centre line u_want
    with `height` nodes of open water above it."""
    best = None
    for (cx, y, z), letter in cells.items():
        if cx != x or letter not in "PA" or not free_above(cells, (cx, y, z), height):
            continue
        v, u = frame(y, z)
        if v > hull.deck(x) + 0.49:
            continue
        score = (abs(u - u_want) < 0.8, y, -abs(u - u_want))
        if best is None or score > best[0]:
            best = (score, (cx, y, z))
    return best[1] if best else None


def free_above(cells, pos, height=1):
    x, y, z = pos
    return all((x, y + i, z) not in cells for i in range(1, int(math.ceil(height)) + 1))


def algae(cells, seed, sink, share=0.3):
    """Algae planks on planks whose top is open water (none in the sand)."""
    floor = min(p[1] for p in cells) + sink
    for (x, y, z), letter in list(cells.items()):
        if letter == "P" and y >= floor and (x, y + 1, z) not in cells and \
                mix(seed, 99, x, y, z) < share:
            cells[(x, y, z)] = "A"


def place(cells, pos, letter, height=1):
    if pos is None or not free_above(cells, pos, height):
        raise SystemExit("no free water above %s for %s" % (pos, letter))
    cells[pos] = letter


def drop_loose(cells, sink):
    """Remove pieces that hang in the water: keep what connects (by faces or
    edges) to a cell in the sand or resting on it."""
    floor = min(p[1] for p in cells) + sink
    seen = set(p for p in cells if p[1] <= floor)
    todo = list(seen)
    steps = [(dx, dy, dz) for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)
             if 0 < abs(dx) + abs(dy) + abs(dz) <= 2]
    while todo:
        x, y, z = todo.pop()
        for dx, dy, dz in steps:
            q = (x + dx, y + dy, z + dz)
            if q in cells and q not in seen:
                seen.add(q)
                todo.append(q)
    for p in [p for p in cells if p not in seen]:
        del cells[p]


def finish(key, title, note, cells, sink):
    drop_loose(cells, sink)
    xs = [p[0] for p in cells]
    ys = [p[1] for p in cells]
    zs = [p[2] for p in cells]
    x0, y0, z0 = min(xs), min(ys), min(zs)
    sx, sy, sz = max(xs) - x0 + 1, max(ys) - y0 + 1, max(zs) - z0 + 1
    layers = []
    for y in range(sy):
        rows = []
        for z in range(sz):
            rows.append("".join(cells.get((x + x0, y + y0, z + z0), ".") for x in range(sx)))
        layers.append(rows)
    used = sorted(set("".join("".join(r) for r in layers)) - {"."})
    return {
        "schema": "grug_r51_wreck_shape_v1",
        "key": key,
        "title": title,
        "note": note,
        "size": {"x": sx, "y": sy, "z": sz},
        "seabed": sink,
        "palette": {k: PALETTE[k] for k in used},
        "layers": layers,
    }


def shape_hull():
    hull = Hull()
    cells, frame = hull_cells(hull, 14, 11, holes=[(6, 12, 1, 0.75), (13, 15, -1, 0.4)])
    algae(cells, 11, 2)
    place(cells, top_deck_cell(cells, frame, hull, 9, 0.0, 16), "M", 16)
    place(cells, top_deck_cell(cells, frame, hull, 15), "k", 2)
    place(cells, top_deck_cell(cells, frame, hull, 17, 0.9), "R")
    place(cells, top_deck_cell(cells, frame, hull, 2, -1.0), "S")
    place(cells, top_deck_cell(cells, frame, hull, 12, -1.2), "G")
    return finish("wreck.hull", "Whole hull",
                  "The whole ship, listing a little, two layers in the sand. Planks gone between the ribs "
                  "amidships on the high side, holes in the deck, the main mast standing.", cells, 2)


def shape_bow():
    hull = Hull()
    cells, frame = hull_cells(hull, 58, 23, cut=("above", 9), holes=[(9, 13, 1, 0.55)],
                              deck_holes=0.25)
    algae(cells, 23, 2, 0.4)
    place(cells, top_deck_cell(cells, frame, hull, 15), "k", 2)
    place(cells, top_deck_cell(cells, frame, hull, 18, 0.0), "R")
    place(cells, top_deck_cell(cells, frame, hull, 12, 1.0), "G")
    return finish("wreck.bow", "Bow part",
                  "The front half, broken off behind the main mast and fallen on its side; the break shows "
                  "ribs and keel. A stump of the foremast, a rope end at the bow.", cells, 2)


def shape_stern():
    hull = Hull()
    cells, frame = hull_cells(hull, -16, 37, cut=("below", 9), holes=[(4, 9, -1, 0.6)])
    algae(cells, 37, 3, 0.35)
    place(cells, top_deck_cell(cells, frame, hull, 7), "n", 4.5)
    place(cells, top_deck_cell(cells, frame, hull, 2, 1.0), "S")
    place(cells, top_deck_cell(cells, frame, hull, 3, -1.0), "S")
    place(cells, top_deck_cell(cells, frame, hull, 6, 1.2), "G")
    return finish("wreck.stern", "Stern part",
                  "The back half with the raised stern deck, listing the other way, sunk three layers. "
                  "The broken main mast stands as a stump; sail tatters on the stern rail.", cells, 3)


def shape_debris():
    """A field of loose wreckage, laid out by hand (16 x 14). Layer 1 is the
    first above the sand; layer 0 is sunk (flush with the sand top)."""
    c = {}

    def put(x, y, z, letter):
        c[(x, y, z)] = letter
    # a keel piece flush in the sand with a rib cage rising from it
    for x in range(2, 9):
        put(x, 0, 4, "L")
    for x in (3, 6):
        for s in (-1, 1):
            put(x, 1, 4 + 2 * s, "Y")
            put(x, 2, 4 + 2 * s, "Y")
            put(x, 3, 4 + s, "Y")
        put(x, 0, 3, "Z")
        put(x, 0, 5, "Z")
    del c[(6, 3, 3)]            # one rib broken short
    # the fallen main mast, full logs, half buried towards its foot
    for x in range(5, 14):
        put(x, 0 if x < 8 else 1, 10, "L")
    # loose planks, a hull panel lying flat, a few stacked
    for x, z in ((10, 2), (11, 2), (11, 3), (12, 3), (13, 5), (1, 9), (2, 10), (2, 11), (9, 12), (14, 9)):
        put(x, 1, z, "P")
    for x in range(9, 13):
        for z in range(6, 8):
            put(x, 1, z, "P")
    put(10, 2, 6, "P")
    # ballast stones
    for x, z in ((0, 3), (1, 3), (0, 4), (1, 4), (1, 5)):
        put(x, 1, z, "C")
    put(1, 2, 4, "C")
    algae(c, 51, 1, 0.45)
    # details on single planks
    c[(10, 1, 7)] = "S"
    c[(13, 1, 5)] = "R"
    c[(2, 1, 11)] = "G"
    c[(12, 1, 3)] = "G"
    c[(11, 1, 3)] = "A"
    c[(9, 1, 12)] = "S"
    c[(4, 1, 10)] = "L"
    for p in [p for p, l in c.items() if l in "RSG"]:
        assert free_above(c, p), p
    return finish("wreck.debris", "Debris field",
                  "Loose wreckage on the sand: a keel piece with its rib cage, the fallen main mast in full "
                  "logs, a flat hull panel, loose planks and a heap of ballast stones.", c, 1)


SHAPES = (shape_hull, shape_bow, shape_stern, shape_debris)

# The node list (DESIGN.md "Node list"). tiles: top, bottom, sides as
# texture files (ARTS's tools/r51_sea or the repo's default textures);
# special: the rooted extension's texture. Every block drops an ordinary
# block (round plan §4.1).
NODES = [
    {"name": N_PLANKS, "key": "wreck.planks", "description": "Waterlogged Planks", "new": True,
     "drawtype": "normal", "paramtype2": "none", "tiles": ["wreck_planks"] * 3, "drop": "default:wood",
     "use": "hull shell, deck, rail, loose planks"},
    {"name": N_ALGAE_PLANKS, "key": "wreck.planks_algae", "description": "Waterlogged Planks with Algae",
     "new": True, "drawtype": "normal", "paramtype2": "none", "tiles": ["wreck_planks_algae"] * 3,
     "drop": "default:wood", "use": "planks whose top lies open in the water (about a third)"},
    {"name": N_LOG, "key": "wreck.log", "description": "Waterlogged Log", "new": True, "drawtype": "normal",
     "paramtype2": "facedir", "tiles": ["wreck_log_top", "wreck_log_top", "wreck_log"], "drop": "default:tree",
     "use": "keel, stem, ribs, the fallen mast (ARTS recommends its own log over default:tree)"},
    {"name": N_MAST, "key": "wreck.mast", "description": "Waterlogged Planks (mast step)", "new": True,
     "drawtype": "plantlike_rooted", "paramtype2": "leveled", "waving": 0, "tiles": ["wreck_planks"] * 3,
     "special": "wreck_mast", "drop": "default:wood",
     "use": "the deck plank a mast stands on; height = param2 / 16 nodes (main mast 255 = 15.9, stumps 2-4.5)"},
    {"name": N_ROPE, "key": "wreck.rope", "description": "Waterlogged Planks (rope end)", "new": True,
     "drawtype": "plantlike_rooted", "paramtype2": "none", "waving": 1, "tiles": ["wreck_planks"] * 3,
     "special": "wreck_rope", "drop": "default:wood", "use": "a rope coil on a deck plank, one node"},
    {"name": N_SAIL, "key": "wreck.sail", "description": "Waterlogged Planks (sail tatters)", "new": True,
     "drawtype": "plantlike_rooted", "paramtype2": "none", "waving": 1, "tiles": ["wreck_planks"] * 3,
     "special": "wreck_sail", "drop": "default:wood", "use": "torn sail strips on a rail or loose plank, one node"},
    {"name": N_ALGAE, "key": "wreck.algae", "description": "Waterlogged Planks with Algae (tuft)", "new": True,
     "drawtype": "plantlike_rooted", "paramtype2": "none", "waving": 1, "tiles": ["wreck_planks_algae"] * 3,
     "special": "wreck_algae", "drop": "default:wood", "use": "an algae tuft on an algae plank, one node"},
    {"name": N_BALLAST, "key": "wreck.ballast", "description": "Mossy Cobblestone", "new": False,
     "drawtype": "normal", "paramtype2": "none", "tiles": ["default_mossycobble"] * 3,
     "drop": "default:mossycobble", "use": "the ballast heap of the debris field (exists)"},
]


def nodes_file():
    return {"schema": "grug_r51_wreck_nodes_v1", "nodes": NODES}


def render(shape):
    return json.dumps(shape, indent=1, sort_keys=True) + "\n"


def outputs():
    """[(file name, data)] for every shape and the node list."""
    out = []
    for make in SHAPES:
        shape = make()
        out.append((shape["key"].split(".")[1] + ".json", shape))
    out.append(("nodes.json", nodes_file()))
    return out


def print_shape(shape):
    s = shape["size"]
    print("%s %dx%dx%d seabed %d" % (shape["key"], s["x"], s["y"], s["z"], shape["seabed"]))
    for y in range(s["y"] - 1, -1, -1):
        print("y=%d%s" % (y, "  (sunk)" if y < shape["seabed"] else ""))
        for row in shape["layers"][y]:
            print("   " + row)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--print", action="store_true")
    args = parser.parse_args()
    stale = 0
    os.makedirs(OUT, exist_ok=True)
    for name, data in outputs():
        path = os.path.join(OUT, name)
        text = render(data)
        if args.print and "layers" in data:
            print_shape(data)
        if args.check:
            try:
                with open(path, encoding="utf-8") as handle:
                    current = handle.read()
            except OSError:
                current = None
            if current != text:
                print(name, "is stale: run shapes.py")
                stale += 1
            continue
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        print("wrote", os.path.relpath(path))
    if args.check:
        print("shapes stale" if stale else "shapes current")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
