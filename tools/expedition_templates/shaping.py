"""Small authoring helpers for the three Expedition sources.

Roofs are filled all the way into the hull: a rib has no top to stand on.
Wall dress replaces solid rock only; the combat floor and sight rows stay put.
"""

ROCK = "default:stone"
AIR = "air"
LANTERN = "grug_decor:xdecor_lantern_hanging"
ROPE = "grug_decor:xdecor_rope"
TORCH = "default:torch_wall"


def cells_of(rects):
    return {(x, z) for x0, z0, x1, z1 in rects
            for z in range(z0, z1) for x in range(x0, x1)}


def roof(t, cells, old_top, height, material):
    """`height` gives the first solid cell, `material` its visible underside."""
    for x, z in sorted(cells):
        y = height(x, z)
        t.box(x, y, z, x, old_top + 1, z, ROCK)
        t.set(x, y, z, material(x, z))


def walls(t, cells, bottom, top, material):
    """Paint the rock facing a room, including the irregular edges of its roof."""
    for x, z in sorted(cells):
        for dx, dz in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nx, nz = x + dx, z + dz
            if (nx, nz) in cells:
                continue
            for y in range(bottom, top + 1):
                if t.get(nx, y, nz) == ROCK:
                    t.set(nx, y, nz, material(nx, y, nz))


def hang(t, x, z, y, top):
    """Hang from the actual roof, stopping before its first solid node."""
    if t.get(x, y, z) != AIR:
        return
    t.set(x, y, z, LANTERN)
    for cy in range(y + 1, top + 1):
        if t.get(x, cy, z) != AIR:
            break
        t.set(x, cy, z, ROPE)


def cap_props(t, cells, feet, top, nodes, cap):
    """A low display under a closed hood cannot be used as a step.

    Keep the original eye row open: these fixed props must not acquire a new
    sight screen. The gap between their top and the hood is less than a body.
    """
    for x, z in sorted(cells):
        if t.get(x, feet, z) in nodes:
            t.box(x, feet + 2, z, x, top, z, cap)


def wall_lights(t, cells, feet, step=3):
    """Side light beneath the overhangs; no source in the three body rows."""
    for x, z in sorted(cells):
        if t.get(x, feet, z) != AIR or t.get(x, feet + 3, z) != AIR:
            continue
        for dx, dz, face in ((-1, 0, 3), (1, 0, 2), (0, -1, 5), (0, 1, 4)):
            if (z if dx else x) % step:
                continue
            if t.get(x + dx, feet + 3, z + dz) not in (AIR, ROPE, TORCH, LANTERN):
                t.set(x, feet + 3, z, TORCH, face)
                break
