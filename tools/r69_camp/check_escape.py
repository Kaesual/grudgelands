#!/usr/bin/env python3
"""Round 69 lane CAMP: can a player end up stuck for good in a camp site?

A player who logged out in a camp, or stands there during the box rewrite,
may stand inside a new solid cell. The engine lets a body leave a node it
overlaps by more than half (`axisAlignedCollision`, the inner margin in
src/collision.cpp); only entering a further node collides. So a body can
leave for any free neighbour, and it is held only where no neighbour is free.

The check is cell-centred: for every body position in the box (feet cell
y 1..8, head cell above), for every race, it takes a body standing in the
middle of one column, and every walkable node as a full cube. It lists the
positions overlapping a walkable cell and of those the ones with no way out:
no free body position beside them at the same height or one up, no open cell
under the feet to fall through, and no free position straight above while the
cells over the head stay open (a body rises through what it overlaps, standing
on the node it has cleared). A body straddling two columns is not modelled,
and movement is client-side, so this is no proof and no engine test. The
backstop for such a body is Return Home (out of combat, off its cooldown),
and a held position whose head cell suffocates (`grug_core.should_suffocate`)
ends in a death and a respawn. Exit 1 lists any held position that does not.

Usage: python3 tools/r69_camp/check_escape.py
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
RACES = {'dwarf': 'accord', 'human': 'accord', 'elf': 'accord',
         'undead': 'throng', 'orc': 'throng', 'troll': 'throng'}
R = 11
NODES = json.loads((ROOT / 'tools/building_templates/nodes.json').read_text())['nodes']


def cells_of(race):
    script = '''return function()
return dofile("mods/MAPGEN/grug_mapgen/wp40/r58_camp_blueprint.lua")({}, {
 blueprint_schema=1, art={kind="camp_construction",race="%s",faction="%s",turns=0}})
end
''' % (race, RACES[race])
    with tempfile.TemporaryDirectory(prefix='r69-camp-escape-') as tmp:
        path = Path(tmp) / 'export.lua'
        path.write_text(script)
        out = subprocess.run(['luajit', 'tools/building_templates/viewer/export_blueprint.lua',
                              str(path)], cwd=ROOT, capture_output=True, text=True,
                             check=True).stdout
    cells = {}
    for line in out.splitlines():
        if not line.startswith('#'):
            x, y, z, name, _ = line.split('\t')
            cells[int(x), int(y), int(z)] = name
    return cells


def walkable(name):
    return name != 'air' and NODES[name].get('walkable', True) is not False


def suffocates(name):
    """grug_core.should_suffocate for a player out of stasis, without noclip."""
    d = NODES[name]
    box = d.get('collision_box')
    node = d.get('node_box')
    return walkable(name) and d.get('liquidtype') in (None, 'none') and \
        (box is None or box.get('type') == 'regular') and \
        (node is None or node.get('type') == 'regular') and \
        d.get('drawtype') in (None, 'normal') and \
        d.get('sunlight_propagates') is not True and \
        d.get('groups', {}).get('disable_suffocation') != 1


def main():
    worst, total = 0, 0
    for race in RACES:
        cells = cells_of(race)
        def solid(x, y, z):
            return (x, y, z) in cells and walkable(cells[x, y, z])
        def free(x, y, z):
            return not solid(x, y, z) and not solid(x, y + 1, z)
        embedded, held, doomed, bad = 0, [], 0, []
        for x in range(-R, R + 1):
            for z in range(-R, R + 1):
                for y in range(1, 9):
                    if free(x, y, z):
                        continue
                    embedded += 1
                    out = False
                    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        out = out or free(x + dx, y, z + dz) or \
                            (not solid(x, y + 2, z) and free(x + dx, y + 1, z + dz))
                    out = out or not solid(x, y - 1, z)
                    rise = y
                    while not out and rise < 9 and not solid(x, rise + 2, z):
                        rise += 1
                        out = free(x, rise, z)
                    if out:
                        continue
                    held.append((x, y, z))
                    if suffocates(cells[x, y + 1, z]):
                        doomed += 1
                    else:
                        bad.append(((x, y, z), cells[x, y, z], cells[x, y + 1, z]))
        print('%-7s %d body positions in a walkable cell, %d with no way out, %d of those '
              'suffocate, %d do not' % (race, embedded, len(held), doomed, len(bad)))
        for row in bad:
            print('   ', row)
        worst += len(bad)
        total += len(held)
    print('no way out: %d positions, %d without suffocation' % (total, worst))
    return 1 if worst else 0


if __name__ == '__main__':
    sys.exit(main())
