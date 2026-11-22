#!/usr/bin/env python3
"""The arena field of "Breach Road" as deterministic data (Round 85 lane BUILD).

Ports the approved draft's Python construction (tools/r84_arena_draft/sites.py:
Ground, field) to the data file the world generation reads,
mods/MAPGEN/grug_mapgen/wp40/breach_field.lua. No noise function runs at
generation: every wear pattern the draft draws with sin/cos is evaluated here.

    python3 tools/r85_build/gen_field.py           # write the data file
    python3 tools/r85_build/gen_field.py --check   # the file equals this output

What differs from the draft, and why (round85-plan.md §3.1, §4 BUILD):
* The footprint is the layout's closed-polygon rule (breach_layout.lua
  `inside`, 6,907 columns). The draft's raster has 50 more columns, all on its
  rim, where the arena keeps the natural surface anyway.
* World generation levels the whole hull to the datum (lane WORLD), so the
  draft's illustrative ±3 cut and fill at the rim is 0: rim columns keep the
  column's own natural surface at the datum ("keep").
* The draft's west/east ground (forest litter and dirt, mesa clay and dry
  dirt), its trodden paths (dry dirt on both sides) and its dressing (apple
  trunks, basalt) become roles the writer resolves per column from the biome
  the zone field puts there.
* Terraces are solid from the datum up (the draft model holds only the
  visible faces); the inner masonry follows the draft's own course rule.
The check below holds every other cell to the draft's own `field()` output.
"""
import argparse
import sys
from math import cos, sin
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools/r84_arena_draft'))
import sites  # noqa: E402
from sites import (APPLE, BRICK, CLAY, COBBLE, DIRT, FOREST, GRAVEL, ROCK,  # noqa: E402
                   RUBBLE, SOIL, STAIR, STONE, Ground, field)

OUT = ROOT / 'mods/MAPGEN/grug_mapgen/wp40/breach_field.lua'
HALF_X, HALF_Z = 49, 45
# The layout's footprint polygon (breach_layout.lua RIM and its point mirror).
RIM = sites.RIM
POLYGON = list(RIM) + [(-x, -z) for x, z in RIM[1:-1]]

KEEP, AIR = '=', '-'
ACCENT, BASE, PATH = '@accent', '@base', '@path'
# The dressing groups (sites.py field: "Left standing on the woodland
# margin, or exposed in the clay cut"), east-wing centres.
DRESS_CENTRES = ((37, 25), (30, -31))
DRESS_POSTS = ((0, 0, 4), (1, 0, 1), (-1, 0, 1), (0, 1, 1))


def on_segment(px, pz, a, b):
    (x1, z1), (x2, z2) = a, b
    if (x2 - x1) * (pz - z1) - (z2 - z1) * (px - x1) != 0:
        return False
    return min(x1, x2) <= px <= max(x1, x2) and min(z1, z2) <= pz <= max(z1, z2)


def inside(lx, lz):
    """breach_layout.lua M.inside, the same integer arithmetic."""
    if abs(lx) > HALF_X or abs(lz) > HALF_Z:
        return False
    odd, n = False, len(POLYGON)
    for i in range(n):
        a, b = POLYGON[i], POLYGON[(i + 1) % n]
        if on_segment(lx, lz, a, b):
            return True
        (x1, z1), (x2, z2) = a, b
        if (z1 > lz) != (z2 > lz) and \
                (((lx - x1) * (z2 - z1) < (x2 - x1) * (lz - z1)) == (z2 > z1)):
            odd = not odd
    return odd


def side(role, x):
    """A role as the draft drew it: west forest, east badlands; its trodden
    paths dry dirt on both sides."""
    if role == PATH:
        return DIRT
    if role == ACCENT:
        return FOREST if x < 0 else CLAY
    if role == BASE:
        return SOIL if x < 0 else DIRT
    return role


def drawn(ground, value, x, z):
    """A model value as the draft drew it (the rim: its illustrative ground)."""
    if value == KEEP:
        return ground.local_ground(x, z)
    if isinstance(value, tuple):
        return value[0]
    return side(value, x)


def path(name):
    """The draft's trodden dry dirt as the path role."""
    return PATH if name == DIRT else name


def surface_role(ground, x, z):
    """sites.py Ground.surface with the side-bound ground and the trodden dry
    dirt as roles and the rim as the natural surface."""
    h = ground.heights[x, z]
    if (x, z) in ground.stairs:
        return STAIR
    noise = sin(x * .29 + sin(z * .14) * 2) + .8 * cos(z * .22 - x * .09)
    if abs(x) <= 3:
        return path(ground.road(x, z))
    if (x, z) in ground.flank_paths:
        return GRAVEL if noise > .45 else PATH
    if (x, z) in ground.rim:
        return KEEP
    if h in (3, 6):
        if any(ground.heights.get((x + dx, z + dz), h) < h
               for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            return STONE
        if 7 <= abs(z) <= 11 or (h == 6 and abs(x) < 21):
            return BRICK if noise > -.6 else COBBLE
        return GRAVEL if noise > 1 else (COBBLE if noise < -.7 else PATH)
    if abs(x) < 8 or noise < -.75:
        return GRAVEL if noise < -.2 else PATH
    return ACCENT if noise > .6 else BASE


def masonry(x, y, z):
    """sites.py field: a terrace's courses above the datum."""
    return BRICK if y % 3 == 2 else (RUBBLE if (x + z) % 9 < 2 else COBBLE)


def dressing(ground):
    """Both variants of every dressing group: 'trunk' (the draft's west,
    sites.py APPLE posts and the branch) and 'rock' (its east, basalt)."""
    groups = []
    for s in (-1, 1):
        for cx, cz in DRESS_CENTRES:
            x0, z0 = s * cx, s * cz
            trunk, rock = [], []
            for dx, dz, high in DRESS_POSTS:
                x, z = s * (cx + dx), s * (cz + dz)
                y = ground.heights[x, z]
                for top, cells in ((high, trunk), (min(high, 2), rock)):
                    for yy in range(y + 1, y + top + 1):
                        cells.append((x - x0, yy, z - z0))
            y = ground.heights[x0, z0]
            trunk += [(s, y + 3, 0), (s, y + 4, 0)]
            groups.append({'x': x0, 'z': z0, 'trunk': trunk, 'rock': rock})
    return groups


def build():
    ground = Ground()
    # Lane WORLD levels the hull: the draft's rim cut and fill is 0.
    for p in ground.rim:
        ground.heights[p] = 0
    draft = field(ground)
    groups = dressing(ground)
    dressed = {}
    for g in groups:
        variant = 'trunk' if g['x'] < 0 else 'rock'
        for dx, y, dz in g[variant]:
            dressed[g['x'] + dx, y, g['z'] + dz] = APPLE if variant == 'trunk' else ROCK
    model, problems = {}, []
    for (x, z), h in ground.heights.items():
        if not inside(x, z):
            if (x, z) not in ground.rim:
                problems.append(('outside the footprint, not rim', x, z))
            continue
        for y in range(0, h):
            model[x, y, z] = masonry(x, y, z)
        role = surface_role(ground, x, z)
        model[x, h, z] = (STAIR, ground.stairs[x, z]) if role == STAIR else role
    # The draft's other cells: piers, arches, breastworks, footings, rubble,
    # the road marker and the hearths (they replace a surface where they meet
    # it); the dressing is resolved per biome.
    for (x, y, z), name in draft.items():
        if y < 0 or not inside(x, z):
            continue
        if (x, y, z) in dressed:
            if dressed[x, y, z] != name:
                problems.append(('dressing differs', x, y, z, name))
            continue
        if name in (APPLE, ROCK):
            problems.append(('dressing outside its group', x, y, z, name))
            continue
        here, h = model.get((x, y, z)), ground.heights[x, z]
        if here is None:
            model[x, y, z] = name
        elif y < h:
            if here != name:
                problems.append(('fill differs', x, y, z, name, here))
        elif drawn(ground, here, x, z) != name:
            # an extra that replaces the surface (a hearth's basalt)
            model[x, y, z] = name
    for p in dressed:
        if p not in draft:
            problems.append(('dressing cell not in the draft', p))
    # Every cell the draft holds, resolved the draft's way, equals the model.
    for (x, y, z), name in draft.items():
        if y < 0 or not inside(x, z) or (x, y, z) in dressed:
            continue
        if drawn(ground, model[x, y, z], x, z) != name:
            problems.append(('cell differs', x, y, z, name, model[x, y, z]))
    if problems:
        raise SystemExit('gen_field: the port differs from the draft: %r' % problems[:10])
    for x in range(-HALF_X, HALF_X + 1):
        for z in range(-HALF_Z, HALF_Z + 1):
            if inside(x, z) and (x, z) not in ground.heights:
                raise SystemExit('gen_field: footprint column %d,%d has no ground' % (x, z))
    return ground, model, groups


def render(ground, model, groups):
    entries = []
    index = {}

    def key(value):
        if value in (KEEP, AIR):
            return value
        if value not in index:
            index[value] = len(entries)
            entries.append(value)
        return CHARS[index[value]]
    columns = {}
    for (x, y, z), value in model.items():
        columns.setdefault((x, z), {})[y] = value
    # entries in a fixed order: fixed nodes by name, then stairs, then roles
    order = sorted({v for v in model.values()}, key=lambda v: (
        1 if isinstance(v, tuple) else (2 if isinstance(v, str) and v.startswith('@') else 0),
        v if isinstance(v, str) else (v[0], v[1])))
    for value in order:
        if value != KEEP:
            key(value)
    lines = []
    for z in range(-HALF_Z, HALF_Z + 1):
        for x in range(-HALF_X, HALF_X + 1):
            if not inside(x, z):
                continue
            cells = columns[x, z]
            top = max(cells)
            codes = ''.join(key(cells[y]) if y in cells else AIR for y in range(0, top + 1))
            lines.append('%d %d %s' % (x, z, codes))
    out = ['-- The arena "Breach Road": its field (terraces, stairs, breastworks, rim,',
           '-- dressing) relative to the site, local x east, z north, y above the datum.',
           '-- GENERATED by tools/r85_build/gen_field.py from the approved draft',
           '-- (tools/r84_arena_draft/sites.py); do not edit, regenerate.',
           '--   entries   index -> {node name, param2} or a role "@accent", "@base",',
           '--             "@path"',
           '--             (the column\'s biome family, breach_model.lua)',
           '--   columns   one line per footprint column "x z codes": codes[1] is y 0',
           '--             (the datum), one character per node upward; a letter is',
           '--             an entry (CHARS order), "=" keeps the natural surface,',
           '--             "-" is air',
           '--   dressing  per group its centre and both variants\' cells {dx, y, dz}',
           'return {', '\tversion = 1,', '\tchars = "%s",' % CHARS, '\tentries = {']
    for value in entries:
        if isinstance(value, tuple):
            out.append('\t\t{"%s", %d},' % value)
        else:
            out.append('\t\t{"%s", 0},' % value)
    out.append('\t},')
    out.append('\tcolumns = [[')
    out += lines
    out.append(']],')
    out.append('\tdressing = {')
    for g in groups:
        def cells(lst):
            return ', '.join('{%d, %d, %d}' % c for c in lst)
        out.append('\t\t{x = %d, z = %d,' % (g['x'], g['z']))
        out.append('\t\t\ttrunk = {%s},' % cells(g['trunk']))
        out.append('\t\t\trock = {%s}},' % cells(g['rock']))
    out.append('\t},')
    out.append('}')
    return '\n'.join(out) + '\n'


CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    ground, model, groups = build()
    text = render(ground, model, groups)
    if args.check:
        if not OUT.exists() or OUT.read_text() != text:
            raise SystemExit('Out of date: %s (run tools/r85_build/gen_field.py)' %
                             OUT.relative_to(ROOT))
        print('PASS: %s equals the generator\'s output' % OUT.relative_to(ROOT))
    else:
        OUT.write_text(text)
        print('wrote %s' % OUT.relative_to(ROOT))
    stairs = sum(1 for v in model.values() if isinstance(v, tuple))
    print('%d footprint columns, %d cells, %d stair nodes, %d dressing groups' % (
        sum(1 for x in range(-HALF_X, HALF_X + 1) for z in range(-HALF_Z, HALF_Z + 1)
            if inside(x, z)), len(model), stairs, len(groups)))


if __name__ == '__main__':
    main()
