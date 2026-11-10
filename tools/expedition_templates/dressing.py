"""Surface dressing in clusters (Round 73 TOOLS; concept §4.7).

For the wave 2 lanes. Moss, carpets, bones and skulls lie on walking cells only when
they are not walkable (a walkable one raises the floor for navigation); no gathering
source and no crop anywhere; cobwebs and hanging moss high up, never in a body's rows.
A few, in clusters: a density map from `clusters`, rolled per cell by a seeded hash, so
the floor and its stairs (relief.write with `mossy`) agree.

    import dressing, relief
    damp = dressing.clusters(cells, count=3, radius=4, seed=4)   # density 0..1 by cell
    dressing.scatter(t, floor, ["grug_nodes:moss_carpet", "grug_nodes:lichen_carpet"],
                     density=damp, seed=4, avoid=trap_cells)
    moss = dressing.mossy(damp, seed=9)                          # a function of x, z
    relief.write(t, floor, lambda x, z: "mossycobble" if moss(x, z) else "cobble",
                 floor=lambda x, z: "default:mossycobble" if moss(x, z) else ROCK)
    dressing.walls(t, floor, "default:mossycobble", damp, seed=9)  # the rock beside it
    dressing.hang(t, floor, "grug_decor:xdecor_cobweb", corners, seed=2, clear=4)
"""
import random
import zlib

import registry
import relief

ROCK = "default:stone"


def roll(seed, x, z, salt=0):
    """A number in [0, 1) fixed by the seed and the cell: the same on every build."""
    return (zlib.crc32(f"{seed},{x},{z},{salt}".encode()) & 0xffffff) / 0x1000000


def clusters(cells, count, radius, seed, strength=0.8):
    """A density map: `count` seeded centres among `cells`, the density falling from
    `strength` at a centre to 0 at `radius` nodes."""
    order = sorted(cells)
    centres = random.Random(seed).sample(order, min(count, len(order)))

    def density(x, z):
        best = 0.0
        for cx, cz in centres:
            d = ((x - cx) ** 2 + (z - cz) ** 2) ** 0.5
            best = max(best, strength * (1 - d / radius))
        return best
    density.centres = centres
    return density


def mossy(density, seed):
    """A function of x, z: True where the density's roll says moss."""
    return lambda x, z: roll(seed, x, z) < density(x, z)


def _allowed_on_floor(node):
    if registry.walkable(node):
        raise ValueError(f"dressing: {node} is walkable and would raise the floor")
    if registry.harvest(node):
        raise ValueError(f"dressing: {node} can be harvested (loot outside the chest)")
    if registry.liquid(node) or "cobweb" in node:
        raise ValueError(f"dressing: {node} may not lie on a walking cell")


def scatter(t, heights, nodes, density, seed, avoid=(), cells=None):
    """One of `nodes` on each walking cell (in its feet row, where it is air) the
    density's roll picks; `avoid` cells (floor traps: their mark goes in that air) stay
    clear, and so do stair cells (a carpet on a stair's step hangs in the air). Returns the
    cells dressed."""
    for node in nodes:
        _allowed_on_floor(node)
    avoid = set(avoid)
    done = []
    for x, z in sorted(cells if cells is not None else heights):
        h = heights[x, z]
        if (x, z) in avoid or t.get(x, h, z) != "air" or roll(seed, x, z) >= density(x, z):
            continue
        if relief.stair_at(heights, x, z):
            continue
        t.set(x, h, z, nodes[int(roll(seed, x, z, 1) * len(nodes))])
        done.append((x, z))
    return done


def walls(t, heights, node, density, seed, rows=4, replace=(ROCK,)):
    """The rock facing the floor (the first `rows` rows over each cell's feet) becomes
    `node` where the density's roll picks it: moss patches on the walls."""
    for x, z in sorted(heights):
        h = heights[x, z]
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = x + dx, z + dz
            if (nx, nz) in heights or roll(seed, nx, nz) >= density(x, z):
                continue
            for y in range(h, h + rows):
                if 0 <= nx < t.sx and 0 <= nz < t.sz and t.get(nx, y, nz) in replace:
                    t.set(nx, y, nz, node)


def hang(t, heights, node, density, seed, clear=4, cells=None):
    """`node` (cobwebs, hanging moss) under the roof of each cell the roll picks, only
    where the roof's first air row lies `clear` nodes or more over the feet (never in a
    body's rows, never under the free height the proof asks for). Returns the cells."""
    if registry.walkable(node) or registry.harvest(node):
        raise ValueError(f"dressing: {node} cannot hang")
    done = []
    for x, z in sorted(cells if cells is not None else heights):
        h = heights[x, z]
        if roll(seed, x, z, 2) >= density(x, z):
            continue
        y = h
        while y + 1 < t.sy and t.get(x, y + 1, z) == "air":
            y += 1
        if y >= h + clear and t.get(x, y, z) == "air":
            t.set(x, y, z, node)
            done.append((x, z))
    return done
