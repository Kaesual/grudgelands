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
# Masts are broken (user, 2026-10-19: the full 15.9-node mast was clearly too
# long): letter -> height in nodes above the deck (param2 = 16 * height).
MASTS = {"M": 6.0, "n": 4.5, "k": 2.5}
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


def noise(seed, a, b):
    """Smooth value noise in [0, 1) on an integer lattice (ragged, not square,
    holes)."""
    ia, ib = math.floor(a), math.floor(b)
    ta, tb = a - ia, b - ib
    ta, tb = ta * ta * (3 - 2 * ta), tb * tb * (3 - 2 * tb)
    c00, c10 = mix(seed, ia, ib), mix(seed, ia + 1, ib)
    c01, c11 = mix(seed, ia, ib + 1), mix(seed, ia + 1, ib + 1)
    return (c00 + (c10 - c00) * ta) * (1 - tb) + (c01 + (c11 - c01) * ta) * tb


class Hull:
    """The hull form in its own frame: x along the ship, u across, v up from
    the keel's bottom. It narrows toward bow and stern and toward the keel."""

    def __init__(self, length=20, beam=3.5, depth=4.6, sheer=1.2, castle=(4, 1)):
        self.length, self.beam, self.depth, self.sheer = length, beam, depth, sheer
        self.castle_len, self.castle_h = castle

    def keel(self, x):
        n = self.length - 1
        bow = max(0.0, (x - (n - 6)) / 6.0)
        stern = max(0.0, (2.5 - x) / 2.5)
        return 3.2 * bow * bow + 1.0 * stern * stern

    def deck(self, x):
        n = self.length - 1
        mid = n / 2.0
        d = self.depth + self.sheer * ((x - mid) / mid) ** 2
        bow = max(0.0, (x - 0.7 * n) / (0.3 * n))
        d += 1.0 * bow * bow            # the bow rises
        if x < self.castle_len:
            d += self.castle_h
        return d

    def half_width(self, x):
        n = self.length - 1
        a, b = 0.25 * n, 0.45 * n
        if x < a:
            return self.beam * (0.5 + 0.5 * math.sqrt(x / a))
        if x <= b:
            return self.beam
        t = (x - b) / (n - b)
        return self.beam * math.cos(t * math.pi / 2) ** 0.8 + 0.2

    def width_at(self, x, v):
        k, d = self.keel(x), self.deck(x)
        t = min(1.0, max(0.0, (v - k) / max(0.5, d - k)))
        return max(0.4, self.half_width(x) * t ** 0.7)


def hull_cells(hull, heel_deg, pitch_deg, seed, cut=None, holes=(), deck_loss=0.35, rail_loss=0.5):
    """Rasterize the hull form into {(x, y, z): letter}: a one-block shell of
    planks (the cells of the form with an open face), the keel and stem in
    logs, a rib every third station (a log where the shell is, a deck beam
    across the deck), heeled by heel_deg about the long axis and pitched by
    pitch_deg (the bow end up), so it sinks unevenly.

    cut = ('above'|'below', x) breaks the hull there, raggedly (ribs and
    keel reach further). holes: (x0, x1, side, cover) shell regions where
    smooth noise takes the planks away, leaving the ribs; deck_loss and
    rail_loss the share of deck and rail planks gone, in patches."""
    heel, pitch = math.radians(heel_deg), math.tan(math.radians(pitch_deg))
    cs, sn = math.cos(heel), math.sin(heel)
    axis = hull.depth * 0.45
    L = hull.length
    mid = (L - 1) / 2.0
    zr = int(math.ceil(hull.beam + 5))
    y0, y1 = -8, int(math.ceil(hull.depth + hull.castle_h + hull.sheer + 8))

    def frame(x, y, z):
        dy = y - axis + (x - mid) * pitch * -1.0
        return axis + dy * cs + z * sn, -dy * sn + z * cs   # v, u

    def solid(x, y, z):
        if x < 0 or x >= L:
            return False
        v, u = frame(x, y, z)
        if v < hull.keel(x) - 0.5 or v > hull.deck(x) + 0.49:
            return False
        return abs(u) < hull.width_at(x, v) + 0.5

    def rail(x, y, z):
        if x < 1 or x >= L - 1:
            return False
        v, u = frame(x, y, z)
        d = hull.deck(x)
        if not (d + 0.49 < v <= d + 1.49):
            return False
        w = hull.width_at(x, d)
        return w - 0.5 <= abs(u) < w + 0.5

    def rib(x):
        return x % 3 == 1 and 1 < x < L - 3

    cells, kinds = {}, {}
    for x in range(L):
        for y in range(y0, y1):
            for z in range(-zr, zr + 1):
                if solid(x, y, z):
                    if all(solid(x + dx, y + dy, z + dz) for dx, dy, dz in
                           ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))):
                        continue
                    v, u = frame(x, y, z)
                    k, d = hull.keel(x), hull.deck(x)
                    w = hull.width_at(x, v)
                    deck = v >= d - 0.5 and abs(u) < hull.width_at(x, d) - 0.5
                    if abs(u) < 0.7 and v < k + 0.9:
                        letter, kind = ("L" if x < L - 2 else "Y"), "keel"
                    elif abs(u) < 0.6 and x == L - 1:
                        letter, kind = "Y", "keel"          # the stem
                    elif rib(x) and deck:
                        letter, kind = "P", "beam"
                    elif rib(x):
                        letter, kind = "P", ("rib_side" if abs(u) > w * 0.6 else "rib_floor")
                    else:
                        letter, kind = "P", ("deck" if deck else "shell")
                    cells[(x, y, z)], kinds[(x, y, z)] = letter, kind
                elif rail(x, y, z):
                    cells[(x, y, z)], kinds[(x, y, z)] = "P", "rail"
    # the stem post stands one node over the bow
    tip = [p for p in cells if p[0] == L - 1]
    if tip:
        top = max(tip, key=lambda p: p[1])
        cells[(top[0], top[1] + 1, top[2])], kinds[(top[0], top[1] + 1, top[2])] = "Y", "keel"
    # the break of a part: ragged, ribs and keel reach further
    if cut is not None:
        side, cx = cut
        for (x, y, z) in list(cells):
            edge = cx + int(noise(seed + 7, y / 1.7, z / 1.7) * 4) - 1 + int(mix(seed, 7, y, z) * 2)
            if kinds[(x, y, z)] in ("keel", "rib", "beam"):
                edge += 2 if side == "above" else -2
            if (side == "above" and x < edge) or (side == "below" and x > edge):
                del cells[(x, y, z)]
    # planks lost in patches: shell between the ribs, deck, rail
    for (x, y, z), letter in list(cells.items()):
        kind = kinds[(x, y, z)]
        if letter != "P" or kind in ("beam", "rib_side", "rib_floor"):
            continue
        v, u = frame(x, y, z)
        jitter = 0.22 * (mix(seed, x, y, z) - 0.5)
        if kind == "rail":
            gone = noise(seed + 9, x / 2.2, u) + jitter < rail_loss
        elif kind == "deck":
            gone = noise(seed + 5, x / 2.6, u / 1.6) + jitter < deck_loss
        else:
            gone = False
            for x0, x1, s, cover in holes:
                if x0 <= x <= x1 and (s == 0 or u * s > 0.2) and v > hull.keel(x) + 0.9 and \
                        noise(seed + 3 + s, x / 2.4, v / 1.7) + jitter < cover:
                    gone = True
                    break
        if gone:
            del cells[(x, y, z)]
    # ribs and deck beams show as logs only where the planking beside them
    # is gone; under whole planking they stay planks
    for (x, y, z), letter in list(cells.items()):
        kind = kinds[(x, y, z)]
        if kind in ("beam", "rib_side", "rib_floor") and \
                ((x - 1, y, z) not in cells or (x + 1, y, z) not in cells):
            cells[(x, y, z)] = "Y" if kind == "rib_side" else "Z"
    return cells, frame


def free_above(cells, pos, height=1):
    x, y, z = pos
    return all((x, y + i, z) not in cells for i in range(1, int(math.ceil(height)) + 1))


def floor_of(cells, sink):
    return min(p[1] for p in cells) + sink


def algae(cells, seed, sink, share=0.4):
    """Algae planks on planks whose top is open water (none in the sand)."""
    floor = floor_of(cells, sink)
    for (x, y, z), letter in list(cells.items()):
        if letter == "P" and y >= floor and (x, y + 1, z) not in cells and \
                mix(seed, 99, x, y, z) < share:
            cells[(x, y, z)] = "A"


def mast(cells, frame, hull, x, letter):
    """A broken mast on the deck plank or beam of station x nearest the
    centre line, with open water above for its height."""
    height = MASTS[letter]
    best = None
    for (cx, y, z), l in cells.items():
        if cx != x or l not in "PAZ" or not free_above(cells, (cx, y, z), height):
            continue
        v, u = frame(cx, y, z)
        if v > hull.deck(x) + 0.49 or v < hull.deck(x) - 1.5:
            continue
        score = (-abs(round(u)), y)
        if best is None or score > best[0]:
            best = (score, (cx, y, z))
    if best is None:
        raise SystemExit("no deck for the mast at station %d" % x)
    cells[best[1]] = letter


def details(cells, seed, sink, wanted):
    """Rooted details on planks whose top is open water: wanted = [(letter,
    count)]; algae tufts on algae planks, rope and sail on plain ones; picked
    by hash, at least three nodes apart."""
    floor = floor_of(cells, sink)
    taken = []
    for n, (letter, count) in enumerate(wanted):
        base = "A" if letter == "G" else "P"
        spots = sorted((mix(seed, 31 + n, *p), p) for p, l in cells.items()
                       if l == base and p[1] >= floor and free_above(cells, p))
        for _, p in spots:
            if count == 0:
                break
            if all(max(abs(p[0] - q[0]), abs(p[2] - q[2])) >= 3 for q in taken):
                cells[p] = letter
                taken.append(p)
                count -= 1


def scatter(cells, seed, sink, box, planks, logs):
    """Loose planks and a few short logs on and in the sand around a wreck,
    inside box = (x0, x1, z0, z1), never touching the wreck or each other."""
    floor = floor_of(cells, sink)

    def clear(x, z):
        return not any((x + dx, y, z + dz) in cells for dx in (-1, 0, 1) for dz in (-1, 0, 1)
                       for y in range(floor - 1, floor + 3))

    wreck = set(cells)

    def near(x, z):
        return any((x + dx, y, z + dz) in wreck for dx in range(-3, 4) for dz in range(-3, 4)
                   for y in range(floor - 1, floor + 2))
    x0, x1, z0, z1 = box
    i = 0
    while (planks or logs) and i < 2000:
        i += 1
        x = x0 + int(mix(seed, i, 1) * (x1 - x0 + 1))
        z = z0 + int(mix(seed, i, 2) * (z1 - z0 + 1))
        y = floor if mix(seed, i, 3) < 0.65 else floor - 1   # resting or flush in the sand
        if logs and i % 2 == 0:
            along_x = mix(seed, i, 5) < 0.5
            n = 2 + int(mix(seed, i, 6) * 3)
            run = [(x + k, z) if along_x else (x, z + k) for k in range(n)]
            if near(x, z) and all(x0 <= a <= x1 and z0 <= b <= z1 and clear(a, b) for a, b in run):
                for k, (a, b) in enumerate(run):
                    cells[(a, y if k < n - 1 else floor - 1, b)] = "L" if along_x else "Z"
                logs -= 1
        elif planks and clear(x, z) and near(x, z):
            cells[(x, y, z)] = "A" if mix(seed, i, 4) < 0.45 else "P"
            if mix(seed, i, 7) < 0.35 and clear(x + 1, z):
                cells[(x + 1, floor, z)] = "P"
            planks -= 1


def drop_loose(cells, sink):
    """Remove pieces that hang in the water: keep what connects (by faces or
    edges) to a cell in the sand or resting on it."""
    floor = floor_of(cells, sink)
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
    sink = 2
    cells, frame = hull_cells(hull, 16, 4, 11, holes=[(5, 13, 1, 0.62), (12, 16, -1, 0.42), (2, 5, -1, 0.3)],
                              deck_loss=0.42)
    mast(cells, frame, hull, 10, "M")
    algae(cells, 11, sink)
    details(cells, 11, sink, [("G", 4), ("R", 2), ("S", 2)])
    scatter(cells, 12, sink, (-2, 21, -7, 7), 6, 2)
    return finish("wreck.hull", "Whole hull",
                  "The whole ship, listing to one side, its stern deeper in the sand than its bow. Planking "
                  "gone in patches so the ribs show, most of the deck gone down to its beams, the main mast "
                  "broken a few nodes above the deck; loose planks and timbers around it.", cells, sink)


def shape_bow():
    hull = Hull()
    sink = 2
    cells, frame = hull_cells(hull, 40, -4, 23, cut=("above", 8), holes=[(8, 15, 1, 0.5), (8, 12, -1, 0.35)],
                              deck_loss=0.5)
    algae(cells, 23, sink, 0.45)
    details(cells, 23, sink, [("G", 3), ("R", 1)])
    scatter(cells, 24, sink, (6, 20, -6, 6), 4, 1)
    return finish("wreck.bow", "Bow part",
                  "The front half, broken off behind the main mast, lying on its side with the nose dug into "
                  "the sand; the ragged break shows ribs, beams and keel. Planks strewn behind it.", cells, sink)


def shape_stern():
    hull = Hull()
    sink = 2
    cells, frame = hull_cells(hull, -18, -7, 37, cut=("below", 10), holes=[(4, 10, -1, 0.55), (6, 10, 1, 0.3)],
                              deck_loss=0.4)
    mast(cells, frame, hull, 7, "n")
    algae(cells, 37, sink, 0.4)
    details(cells, 37, sink, [("S", 2), ("G", 3), ("R", 1)])
    scatter(cells, 38, sink, (-2, 14, -7, 7), 4, 1)
    return finish("wreck.stern", "Stern part",
                  "The back half with the raised stern deck, listing the other way, its broken end sunk deep "
                  "into the sand; the main mast a stump, sail tatters on the stern.", cells, sink)


def shape_debris():
    """A field of loose wreckage, laid out by hand (about 18 x 14). Layer 1 is
    the first above the sand; layer 0 is sunk (flush with the sand top)."""
    c = {}

    def put(x, y, z, letter):
        c[(x, y, z)] = letter
    # a keel piece flush in the sand with a rib cage rising from it, uneven
    for x in range(2, 10):
        put(x, 0, 4, "L")
    for x, hs in ((3, (3, 2)), (6, (3, 3)), (9, (2, 1))):
        for s, h in zip((-1, 1), hs):
            for y in range(1, h):
                put(x, y, 4 + 2 * s, "Y")
            if h >= 3:
                put(x, h, 4 + s, "Y")
        put(x, 0, 3, "Z")
        put(x, 0, 5, "Z")
    # a strip of hull planking still on the ribs at the bottom
    for x in (4, 5, 7):
        put(x, 1, 2, "A" if x == 5 else "P")
    # the fallen main mast, full logs, half buried towards its foot
    for x in range(6, 15):
        put(x, 0 if x < 9 else 1, 10, "L")
    # a hull panel lying flat, a few stacked
    for x in range(11, 15):
        for z in range(5, 8):
            if (x, z) not in ((14, 5), (11, 7)):
                put(x, 1, z, "P")
    put(12, 2, 6, "P")
    # ballast stones
    for x, z in ((0, 3), (1, 3), (0, 4), (1, 4), (1, 5), (0, 6)):
        put(x, 1, z, "C")
    put(1, 2, 4, "C")
    algae(c, 51, 1, 0.5)
    scatter(c, 52, 1, (-1, 14, -1, 13), 9, 2)
    details(c, 51, 1, [("G", 4), ("S", 2), ("R", 1)])
    return finish("wreck.debris", "Debris field",
                  "Loose wreckage on the sand: a keel piece with an uneven rib cage, the fallen main mast in "
                  "full logs, a flat hull panel, loose planks and timbers, a heap of ballast stones.", c, 1)


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
     "use": "the deck plank a broken mast stands on; height = param2 / 16 nodes (main mast 96 = 6, stumps 2.5-4.5)"},
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
