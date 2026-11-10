"""Floor relief by stairs (Round 73 TOOLS; concept §4.1, plan §3.2). The only writer of
floor stairs: no source derives a stair's shape or param2 itself.

For the wave 2 lanes. A height map is a dict {(x, z): h}, h the first air row of the
column: the feet of a player standing there. Keep one map for the whole floor (rooms and
passages merged), so stairs where two parts meet see both.

    import relief
    room = relief.flat(cells, FEET)                         # a flat room, on purpose
    room = relief.vary(cells, FEET, seed=7, keep=mouths + trap_cells, features=[
        relief.pit(60, 28, 6, depth=2, gentle=90),          # a sunken floor, a long run east
        relief.rise(52, 22, 4, height=1),                   # and a low rise in a corner
        relief.terrace(66, 30, angle=180, levels=2)])       # terraces climbing to the west
    floor = relief.merge(room, passage_heights, other_room) # one map; refuses two heights
    relief.check(floor, flat=trap_cells)                    # raises on a broken map
    relief.carve(t, floor, top=lambda x, z: floor[x, z] + 5)  # air from the feet up
    relief.write(t, floor, "cobble", floor=lambda x, z: ROCK) # floor nodes and stairs

The rules (concept §4.1): neighbours (all eight) differ by one at most; a stair stands
in the higher cell's floor node, facing the lower side, inner and outer at corners; no
ridge or trench one node wide (every stair shape must fit); trap cells and their
neighbours flat; a pit keeps two solid rows over the template's bottom. `vary` makes a
room uneven out of the box (§4.1.10): irregular outlines, a gentle and a steep side,
several features; an even room is a choice (`flat`).

A stair's quarters: a cell at height h has four quarters (its corners). A quarter is low
(its top at h - 1, the stair's step) when a neighbour touching that corner is lower,
else high (h - 0.5, flush with the flat floor). Two adjacent low quarters make a normal
stair, one an inner, three an outer (mods/BASE/stairs/init.lua node boxes; facedir p
turns the box's +z to +x, mapnode.cpp transformNodeBox).
"""
import math
import random

import registry

ROCK = "default:stone"
SHAPE_PREFIX = {"normal": "stairs:stair_", "inner": "stairs:stair_inner_", "outer": "stairs:stair_outer_"}
# High quarters at param2 0 as (qx, qz) corners.
HIGH = {"normal": ((-1, 1), (1, 1)), "inner": ((-1, 1), (1, 1), (-1, -1)), "outer": ((-1, 1),)}
CORNERS = ((-1, -1), (1, -1), (-1, 1), (1, 1))
NEIGHBOURS = tuple((dx, dz) for dz in (-1, 0, 1) for dx in (-1, 0, 1) if dx or dz)


def _turn(qx, qz, p):
    for _ in range(p % 4):
        qx, qz = qz, -qx
    return qx, qz


SHAPES = {}  # frozenset of high corners -> (shape, param2)
for _shape, _high in HIGH.items():
    for _p in range(4):
        SHAPES[frozenset(_turn(qx, qz, _p) for qx, qz in _high)] = (_shape, _p)


def flat(cells, h):
    return {cell: h for cell in cells}


def merge(*maps):
    """One map of several; a column given two heights is refused (one surface each)."""
    out = {}
    for heights in maps:
        for cell, h in heights.items():
            if out.get(cell, h) != h:
                raise ValueError(f"relief: {cell[0]},{cell[1]} has two surfaces, {out[cell]} and {h}")
            out[cell] = h
    return out


def stair_at(heights, x, z):
    """None for a flat cell, else (shape, param2); refuses a cell no stair fits."""
    h = heights[x, z]
    high = set()
    for qx, qz in CORNERS:
        if not any(heights.get((x + dx, z + dz), h) < h for dx, dz in ((qx, 0), (0, qz), (qx, qz))):
            high.add((qx, qz))
    if len(high) == 4:
        return None
    found = SHAPES.get(frozenset(high))
    if not found:
        raise ValueError(f"relief: {x},{z}: no stair fits (a peak or a diagonal ridge)")
    return found


def problems(heights, flat=()):
    """Every way the map breaks concept §4.1, as text; empty when it holds."""
    found = []
    for (x, z), h in sorted(heights.items()):
        for dx, dz in NEIGHBOURS:
            nh = heights.get((x + dx, z + dz))
            if nh is not None and abs(nh - h) > 1:
                found.append(f"{x},{z} at {h} beside {x + dx},{z + dz} at {nh}: more than one node")
        for dx, dz, axis in ((1, 0, "x"), (0, 1, "z")):
            a, b = heights.get((x - dx, z - dz)), heights.get((x + dx, z + dz))
            if a is not None and b is not None and (a < h > b or a > h < b):
                found.append(f"{x},{z}: a {'ridge' if a < h else 'trench'} one node wide along {axis}")
        try:
            stair_at(heights, x, z)
        except ValueError as error:
            found.append(str(error)[len("relief: "):])
        if h - 1 < 2:
            found.append(f"{x},{z}: the floor at {h - 1} leaves less than two rows below")
    for x, z in flat:
        h = heights.get((x, z))
        if h is None:
            found.append(f"{x},{z}: a trap cell off the floor")
            continue
        for dx, dz in NEIGHBOURS:
            nh = heights.get((x + dx, z + dz))
            if nh is not None and nh != h:
                found.append(f"{x},{z}: a trap cell beside {x + dx},{z + dz} at {nh}, not flat")
    return found


def check(heights, flat=()):
    found = problems(heights, flat)
    if found:
        raise ValueError("relief: " + "; ".join(found[:6]) + (f"; ... {len(found)} problems" if len(found) > 6 else ""))
    return heights


def _material(stair, x, z):
    material = stair(x, z) if callable(stair) else stair
    if material not in registry.stair_sets():
        raise ValueError(f"relief: {material} has no stair set (concept §4.1.8: ask the coordinator)")
    return material


def write(t, heights, stair, floor=ROCK, cells=None, fill_from=None, fill=ROCK, flat=()):
    """The floor node of every cell (at h - 1): a stair where the cell is higher than a
    neighbour, else `floor` (a node or a function of x, z). `stair` is a material with a
    stair set ("cobble", "mossycobble", ...) or a function of x, z giving one. `cells`
    limits the writing to some cells of the map (the neighbours still count). With
    `fill_from`, rows from it up to the floor node are filled with `fill` (a rise over a
    room carved before). The map is checked first."""
    check(heights, flat)
    for x, z in sorted(cells if cells is not None else heights):
        h = heights[x, z]
        if fill_from is not None:
            for y in range(fill_from, h - 1):
                t.set(x, y, z, fill)
        found = stair_at(heights, x, z)
        if found:
            shape, p = found
            t.set(x, h - 1, z, SHAPE_PREFIX[shape] + _material(stair, x, z), p)
        else:
            t.set(x, h - 1, z, floor(x, z) if callable(floor) else floor)


def carve(t, heights, top, node="air", cells=None):
    """Air (or `node`) from each cell's feet row up to `top` (a row or a function of x,
    z), both included: the body's room over the floor."""
    for x, z in sorted(cells if cells is not None else heights):
        last = top(x, z) if callable(top) else top
        for y in range(heights[x, z], last + 1):
            t.set(x, y, z, node)


def top_over(heights, clear, roof=None):
    """A `top` for `carve` and shaping.roof that follows the floor: at least `clear` nodes
    of air over each cell (the tallest mob plus one, concept §4.1.4), or `roof(x, z)`
    when that is higher."""
    def top(x, z):
        own = heights[x, z] + clear - 1
        return max(own, roof(x, z)) if roof else own
    return top


# ---- Height-map variety (concept §4.1.10) ---------------------------------------------

class Feature:
    """A pit, a rise or a terrace: a field of levels over the room, before it is cut to
    whole steps. Levels change one per `steep` nodes; on the side `gentle` names (degrees
    from the middle: 0 is the +x side, 90 the +z side) the run stretches to `stretch` times
    that, so one side is a long gentle run and the other a short steep one."""

    def __init__(self, sign, x, z, radius, levels, gentle, steep, stretch, seed, wobble, angle=None):
        self.sign, self.x, self.z, self.radius, self.levels = sign, x, z, radius, levels
        self.steep, self.stretch, self.wobble = max(1.0, steep), max(1.0, stretch), wobble
        self.angle = None if angle is None else math.radians(angle)
        rng = random.Random(seed if seed is not None else (x * 7349) ^ (z * 9151) ^ int(radius * 31))
        self.waves = [(rng.uniform(0.3, 1) * wobble, k, rng.uniform(0, 2 * math.pi)) for k in (2, 3, 5)]
        # Uneven by default (concept §4.1.10): a seeded gentle side unless one is named;
        # `gentle=False` makes every side alike, on purpose.
        if gentle is None and angle is None:
            gentle = rng.uniform(0, 360)
        self.gentle = None if gentle is None or gentle is False else math.radians(gentle)

    def run(self, direction):
        """The nodes per level toward `direction` (radians)."""
        if self.gentle is None:
            return self.steep
        lean = max(0.0, math.cos(direction - self.gentle)) ** 2
        return self.steep * (1 + (self.stretch - 1) * lean)

    def field(self, x, z):
        dx, dz = x - self.x, z - self.z
        if self.angle is not None:
            # A terrace: the line through x, z across `angle`, wavy along its length.
            along = dx * math.cos(self.angle) + dz * math.sin(self.angle)
            across = -dx * math.sin(self.angle) + dz * math.cos(self.angle)
            edge = sum(a * self.radius * math.sin(k * across / max(self.radius, 1) + phase)
                       for a, k, phase in self.waves)
            return (along - edge) / self.run(self.angle) + 1
        r = math.hypot(dx, dz)
        theta = math.atan2(dz, dx)
        outline = self.radius * (1 + sum(a * math.cos(k * theta + phase) for a, k, phase in self.waves))
        return (outline - r) / self.run(theta) + 1


def pit(x, z, radius, depth=1, gentle=None, steep=1, stretch=3, seed=None, wobble=0.18):
    """A sunken floor round x, z: `depth` levels down from the outline (`radius` nodes,
    irregular by `wobble`) to its middle. Its gentle side is seeded unless `gentle` names
    one (degrees) or is False (every side as steep)."""
    return Feature(-1, x, z, radius, depth, gentle, steep, stretch, seed, wobble)


def rise(x, z, radius, height=1, gentle=None, steep=1, stretch=3, seed=None, wobble=0.18):
    """A raised area round x, z: `height` levels up; `gentle` as for `pit`."""
    return Feature(1, x, z, radius, height, gentle, steep, stretch, seed, wobble)


def terrace(x, z, angle, levels=1, steep=2, seed=None, wobble=0.15, width=8):
    """Terraces climbing from the line through x, z toward `angle` (degrees: 0 is +x),
    `levels` steps of `steep` nodes each (the last level runs on to the walls); the edge
    waves along its length by `wobble` times `width`."""
    return Feature(1, x, z, width, levels, None, steep, 1, seed, wobble, angle=angle)


def vary(cells, base, features, seed=0, keep=(), keep_radius=1):
    """A height map over `cells` from `base`: the rises' and terraces' levels up, the
    pits' down. `keep` cells (passage mouths, trap cells) and their neighbours within
    `keep_radius` stay at `base`, the relief climbing from them at most one per node. The
    map is repaired where features meet (a step too many, a ridge one node wide) and
    checked; a map that cannot be repaired raises."""
    cells = set(cells)
    keep = list(keep)

    def kept(x, z):
        if not keep:
            return math.inf
        return max(0, min(max(abs(x - kx), abs(z - kz)) for kx, kz in keep) - keep_radius)

    heights = {}
    for x, z in cells:
        up = down = 0.0
        room = kept(x, z)
        for feature in features:
            value = min(max(0.0, min(feature.field(x, z), feature.levels)), room)
            if feature.sign > 0:
                up = max(up, value)
            else:
                down = max(down, value)
        heights[x, z] = base + math.floor(up) - math.floor(down)
    repair(heights, base, frozen={(x + dx, z + dz) for x, z in keep
                                  for dz in range(-keep_radius, keep_radius + 1)
                                  for dx in range(-keep_radius, keep_radius + 1)})
    return check(heights, flat=[k for k in keep if k in heights and keep_radius >= 1])


def repair(heights, base, frozen=(), rounds=200):
    """Move every cell that breaks a rule one level, until none does: a ridge or a peak
    down, a trench up, a step of two toward its neighbour (the cell farther from `base`
    moves). `frozen` cells never move."""
    frozen = set(frozen)
    for _ in range(rounds):
        changed = False
        for (x, z), h in sorted(heights.items()):
            if (x, z) in frozen:
                continue
            move = 0
            for dx, dz in NEIGHBOURS:
                nh = heights.get((x + dx, z + dz))
                if nh is not None and abs(nh - h) > 1 and abs(nh - base) <= abs(h - base):
                    move = 1 if nh > h else -1
            for dx, dz in ((1, 0), (0, 1)):
                a, b = heights.get((x - dx, z - dz)), heights.get((x + dx, z + dz))
                if a is not None and b is not None:
                    if a < h > b:
                        move = -1
                    elif a > h < b:
                        move = 1
            if not move:
                try:
                    stair_at(heights, x, z)
                except ValueError:
                    move = -1
            if move:
                heights[x, z] = h + move
                changed = True
        if not changed:
            return heights
    return heights
