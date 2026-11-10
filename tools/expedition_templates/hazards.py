"""Lava falls and the ambush stretch (Round 73 TOOLS; concept §4.5, §4.6).

For the wave 2 lanes. Write the floor first (relief.write), then the hazards: a lava fall
takes its basin cells out of the height map it is given.

    import hazards
    hazards.lava_fall(t, floor, 70, 31, "+x", source=FEET + 5, basin=[(0, 0), (0, 1)])
    left = hazards.alcove(t, floor, 40, 20, "-z", width=3, depth=3, height=4, mob=(1, 1.9))
    hazards.ambush(t, floor, "a1", 1, "drift", (39, 21, 41, 25),
                   [("grug_mobs:zombie", 40, 18), ("grug_mobs:zombie", 40, 28)])
    hazards.dark(t, zone_cells_with_margin)     # the sources that light them, empty: dark

A lava fall: the source in a closed niche above head height inside the wall beside a
floor cell, the falling column in a recess of that wall (open to the room, so it shows),
and the basin at its foot below the local floor: a source row two below the feet, and
over it the row of the floor's own nodes filled with flowing lava at the levels the
engine settles on (seven at the column, one less per node). Nothing of it is a walking
cell; the lava hold (grug_core/lava_guard.lua) keeps it as written. Not at a passage
mouth or a stair's foot (the proof's `lava` rule), never in the dark or an ambush.

An ambush (concept §4.5): a zone across the passage's full width, 2-3 nodes deep, on
flat floor in a long, nearly straight dark stretch with a light in sight at its end;
alcoves beside it (`alcove`), one marker each, melee mobs of the roster at the normal
tier, about half a room pack. Two candidates per Expedition, pick 1 (one group). Keep
it out of every pack's notice and out of sight of the start waystone; the proof's
`ambush` rule checks all of it on the written file.
"""
import registry

LAVA, FLOWING = "default:lava_source", "default:lava_flowing"
ROCK = "default:stone"
AXES = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}
FALLING, LEVEL_MAX = 8, 7  # mapnode.h LIQUID_FLOW_DOWN_MASK, LIQUID_LEVEL_MAX


def _solid(t, x, y, z, node):
    if not registry.walkable(t.get(x, y, z)):
        t.set(x, y, z, node)


def lava_fall(t, heights, x, z, wall, source, basin=((0, 0),), lip=ROCK, rock=ROCK):
    """A fall into the wall `wall` ("+x", ...) of the floor cell x, z: its recess is the
    wall cell beside it, its source at row `source` (at least three over the feet). The
    basin is the recess's foot plus the floor cells at `basin` offsets from x, z (0, 0 is
    the cell itself), which leave the height map. Returns the basin's room cells."""
    dx, dz = AXES[wall]
    h = heights[x, z]
    wx, wz = x + dx, z + dz
    if (wx, wz) in heights:
        raise ValueError(f"hazards: {wx},{wz} is floor, not wall")
    if source < h + 3:
        raise ValueError(f"hazards: the source at {source} is not above head height ({h} + 3)")
    room = [(x + bx, z + bz) for bx, bz in basin]
    for cell in room:
        if heights.get(cell) != h:
            raise ValueError(f"hazards: the basin cell {cell} is not floor at {h}")
    # The recess: closed on its sides, at its back and over the source.
    sx, sz = dz, dx  # across the wall
    for y in range(h - 3, source + 2):
        for cx, cz in ((wx + sx, wz + sz), (wx - sx, wz - sz), (wx + dx, wz + dz)):
            _solid(t, cx, y, cz, rock)
    _solid(t, wx, source + 1, wz, rock)
    # The lip: the room's cell in front of the source stays closed.
    _solid(t, x, source, z, lip)
    t.set(wx, source, wz, LAVA)
    for y in range(h, source):
        t.set(wx, y, wz, FLOWING, FALLING | LEVEL_MAX)
    # The basin: sources two below the feet, the floor's row over them flowing.
    t.set(wx, h - 2, wz, LAVA)
    t.set(wx, h - 1, wz, FLOWING, LEVEL_MAX)
    _solid(t, wx, h - 3, wz, rock)
    level = {(wx, wz): LEVEL_MAX}
    queue = [(wx, wz)]
    while queue:
        cx, cz = queue.pop(0)
        for ex, ez in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (cx + ex, cz + ez)
            if n in room and n not in level:
                level[n] = level[cx, cz] - 1
                queue.append(n)
    for bx, bz in room:
        if (bx, bz) not in level or level[bx, bz] < 1:
            raise ValueError(f"hazards: the basin cell {bx},{bz} is not joined to the fall")
        t.set(bx, h - 2, bz, LAVA)
        t.set(bx, h - 1, bz, FLOWING, level[bx, bz])
        _solid(t, bx, h - 3, bz, rock)
        for y in (h, h + 1):
            if t.get(bx, y, bz) != "air":
                raise ValueError(f"hazards: the basin cell {bx},{bz} is not open above")
    for cell in room:
        del heights[cell]
    # Every lava cell's sides at the basin's rows: lava, or a solid node (the floor's).
    for bx, bz in room + [(wx, wz)]:
        for y in (h - 2, h - 1):
            for ex, ez in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = t.get(bx + ex, y, bz + ez)
                if not (registry.walkable(n) or n in (LAVA, FLOWING)):
                    raise ValueError(f"hazards: the basin is open at {bx + ex},{y},{bz + ez}")
    return room


def alcove(t, heights, x, z, side, width, depth, height, floor=ROCK, mob=None):
    """An ambush alcove into the wall beside the passage cell x, z: `depth` nodes deep
    toward `side`, `width` along the wall (centred on x, z), `height` rows of air over a
    flat floor at the passage's height, joined to it directly. `mob` (width, height in
    nodes, from its collision box at its tier's scale) refuses an alcove it would not fit
    with a node of head room. Returns the cells; they join `heights`."""
    dx, dz = AXES[side]
    h = heights[x, z]
    if mob and (width < mob[0] or depth < mob[0] or height < mob[1] + 1):
        raise ValueError(f"hazards: a {mob[0]} x {mob[1]} mob does not fit a {width} x {depth} x {height} alcove")
    ax, az = dz, dx  # along the wall
    cells = []
    for k in range(1, depth + 1):
        for i in range(width):
            off = i - (width - 1) // 2
            cx, cz = x + dx * k + ax * off, z + dz * k + az * off
            if (cx, cz) in heights:
                continue
            t.set(cx, h - 1, cz, floor)
            for y in range(h, h + height):
                t.set(cx, y, cz, "air")
            cells.append((cx, cz))
    for cell in cells:
        heights[cell] = h
    return cells


def dark(t, cells_y):
    """The light at each (x, y, z) of `cells_y`: the cells that are not dark, as
    (x, y, z, level). An ambush zone with its margin and its alcoves must give none."""
    import light
    levels = light.levels(t)
    return [(x, y, z, levels[light.index(t, x, y, z)]) for x, y, z in cells_y if levels[light.index(t, x, y, z)]]


def ambush(t, heights, group, pick, room, zone, markers):
    """An ambush candidate through the template's writer (template.py `ambush`): the zone
    (x0, z0, x1, z1), both corners included, on flat floor; one `normal` marker per
    (mob, x, z), each on the floor at the zone's height (an alcove's). Returns the zone's
    cells."""
    x0, z0, x1, z1 = (int(v) for v in zone)
    cells = [(x, z) for z in range(min(z0, z1), max(z0, z1) + 1) for x in range(min(x0, x1), max(x0, x1) + 1)]
    levels = {heights.get(c) for c in cells}
    if len(levels) != 1 or None in levels:
        raise ValueError(f"hazards: the ambush {group} lies on no flat floor: {sorted(levels, key=str)}")
    y = levels.pop()
    for mob, x, z in markers:
        if heights.get((x, z)) != y:
            raise ValueError(f"hazards: the ambush {group}'s marker {x},{z} is not on its floor at {y}")
    t.ambush(group, pick, room, x0, y, z0, x1, z1)
    for mob, x, z in markers:
        t.encounter(room, mob, 1, "normal", int(x), y, int(z))
    return cells
