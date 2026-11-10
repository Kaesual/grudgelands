"""Light from things that belong there (Round 73 TOOLS; concept §4.4).

For the wave 2 lanes. No grid: every source sits at an authored point (a desk, a door,
the ore, a junction), or at a point `spread` picks, a seeded irregular choice with a
minimum spacing, never a modulo of coordinates. Torch 12, hanging lantern 13, candle 12,
lava 13 (the registry's light_source).

    import light
    light.torch(t, 60, FEET + 2, 31)                  # on the wall beside the cell
    light.lantern(t, 64, 23, FEET + 3, top)           # on a rope from the roof
    light.candle(t, 61, FEET + 1, 10)                 # on a desk, the cell above it
    for x, z in light.spread(cells, 4, spacing=9, seed=5, avoid=dark_cells):
        light.lantern(t, x, z, FEET + 3, top)
    levels = light.levels(t)                          # the engine's light, for a look
    levels[light.index(t, x, y, z)]

The proof (proofs.lua) checks the zones: fighting floor at 4 or more (6 on 75 %),
arrival, waystones, chest and door at 6, the ambush dark, and a light in sight from every
cell below 4.
"""
import random

import registry
from shaping import hang

TORCH = "default:torch_wall"
LANTERN = "grug_decor:xdecor_lantern_hanging"
CANDLE = "grug_decor:xdecor_candle"
# wallmounted param2 by the wall the node hangs on.
WALL = {(-1, 0): 3, (1, 0): 2, (0, -1): 5, (0, 1): 4}


def torch(t, x, y, z, wall=None):
    """A wall torch in the open cell x, y, z on the wall beside it (`wall`: "+x", "-x",
    "+z", "-z", else the first solid side)."""
    sides = [{"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}[wall]] if wall else list(WALL)
    if t.get(x, y, z) != "air":
        raise ValueError(f"light: {x},{y},{z} is no open cell for a torch")
    for dx, dz in sides:
        if registry.walkable(t.get(x + dx, y, z + dz)):
            t.set(x, y, z, TORCH, WALL[dx, dz])
            return
    raise ValueError(f"light: no wall beside {x},{y},{z} for a torch")


def lantern(t, x, z, y, top):
    """A lantern at y on a rope up to the roof (stops at the first solid node)."""
    hang(t, x, z, y, top)


def candle(t, x, y, z):
    """A candle on whatever stands below (a table, a crate, the floor)."""
    if t.get(x, y, z) != "air" or not registry.walkable(t.get(x, y - 1, z)):
        raise ValueError(f"light: no place for a candle at {x},{y},{z}")
    t.set(x, y, z, CANDLE)


def spread(cells, count, spacing, seed, avoid=()):
    """Up to `count` of `cells` in a seeded random order, each at least `spacing` nodes
    from the others and from `avoid` points."""
    order = sorted(cells)
    random.Random(seed).shuffle(order)
    taken = [tuple(p[:2]) for p in avoid]
    chosen = []
    for x, z in order:
        if len(chosen) == count:
            break
        if all((x - ax) ** 2 + (z - az) ** 2 >= spacing * spacing for ax, az in taken):
            chosen.append((x, z))
            taken.append((x, z))
    return sorted(chosen)


def index(t, x, y, z):
    return z * t.sy * t.sx + y * t.sx + x


def levels(t, cells=None, palette=None):
    """The engine's light over a template or written cells: a source's light loses one
    per node into every node that lets light through. Returns a bytearray by index().
    `cells`/`palette` read a written file instead (preview.py)."""
    cells = t.cells if cells is None else cells
    palette = t.palette if palette is None else palette
    sx, sy, sz = t.sx, t.sy, t.sz
    passes = [registry.lets_light(n) for n in palette]
    own = [registry.light(n) for n in palette]
    out = bytearray(len(cells))
    buckets = [[] for _ in range(15)]
    for i, node in enumerate(cells):
        if own[node]:
            out[i] = own[node]
            buckets[own[node]].append(i)
    plane = sx * sy
    for value in range(14, 1, -1):
        for i in buckets[value]:
            if out[i] != value:
                continue
            x, rest = i % sx, i // sx
            y, z = rest % sy, rest // sy
            for j, ok in ((i - 1, x > 0), (i + 1, x < sx - 1), (i - sx, y > 0), (i + sx, y < sy - 1),
                          (i - plane, z > 0), (i + plane, z < sz - 1)):
                if ok and out[j] < value - 1 and passes[cells[j]]:
                    out[j] = value - 1
                    buckets[value - 1].append(j)
    return out
