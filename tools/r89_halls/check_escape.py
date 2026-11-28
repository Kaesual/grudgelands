#!/usr/bin/env python3
"""Round 89 lane HALLS: can a player end up stuck for good in an arena hall
after the hall rewrite (the migration 0.89.0, upgrade contract §5.9 "A
player in the way": "a later composition needs the same check")?

The pattern of tools/r69_camp/check_escape.py, on the arena's halls: a
player who logged out in a hall, or stands there during the rewrite, may
stand inside a new solid cell (the stair's bearings, the stair hood's walls,
the deck, the barrier). The engine lets a body leave a node it overlaps by
more than half (`axisAlignedCollision`, the inner margin in
src/collision.cpp); only entering a further node collides. So a body can
leave for any free neighbour, and it is held only where no neighbour is free.

The check is cell-centred: for every body position in each hall box (feet
cell y 1..18 of the hall frame, head cell above), a body standing in the
middle of one column, every walkable node a full cube (slabs, the rail, the
waystone and the barrier included: conservative). It lists the positions
overlapping a walkable cell and of those the ones with no way out: no free
body position beside them at the same height or one up, no open cell under
the feet to fall through, and no free position straight above while the
cells over the head stay open. It also counts how many of those positions
were open in the halls before (0.88.0's templates, the draft's baseline
copies): only there can a player be found after the rewrite. A body straddling two columns is not modelled, and movement is
client-side, so this is no proof and no engine test. The backstop is Return
Home (out of combat, off its cooldown); a held position whose head cell
suffocates (`grug_core.should_suffocate`) ends in a death and a respawn.
Exit 1 lists any held position that does not suffocate and was open in
0.88.0 (one held in a cell that was solid before is listed, not counted).

The cells come from tools/r89_halls/cells.lua (LuaJIT, the arena's model
over the shipped templates); the node fields from
tools/building_templates/nodes.json.

Usage: python3 tools/r89_halls/check_escape.py
"""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
NODES = json.loads((ROOT / 'tools/building_templates/nodes.json').read_text())['nodes']
BASELINE = ROOT / 'tools/r89_balcony_draft/baseline'


def model_cells():
    out = subprocess.run(['luajit', 'tools/r89_halls/cells.lua', '.'], cwd=ROOT,
                         capture_output=True, text=True, check=True).stdout
    cells = {'accord': {}, 'throng': {}}
    for line in out.splitlines():
        faction, u, y, v, name = line.split()
        cells[faction][int(u), int(y), int(v)] = name
    return cells


def baseline_open(faction):
    """The hall-frame cells the 0.88.0 template leaves open ('.')."""
    open_cells, layer, row = set(), None, 0
    for line in (BASELINE / ('breach_%s.tpl' % faction)).read_text().splitlines():
        if line.startswith('layer '):
            layer, row = int(line.split()[1]), 0
        elif line == 'points':
            layer = None
        elif layer is not None and line.startswith('|'):
            for x, key in enumerate(line[1:-1]):
                if key == '.':
                    if faction == 'accord':
                        open_cells.add((20 - x, layer, 15 - row))
                    else:
                        open_cells.add((x, layer, row - 15))
            row += 1
    return open_cells


def walkable(name):
    if name.startswith('@'):
        return True
    return name != 'air' and NODES[name].get('walkable', True) is not False


def suffocates(name):
    """grug_core.should_suffocate for a player out of stasis, without noclip."""
    if name.startswith('@'):
        return True   # the field's dirt and clay
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
    everything = model_cells()
    for faction in ('accord', 'throng'):
        cells = everything[faction]
        before = baseline_open(faction)

        def solid(u, y, v):
            return walkable(cells.get((u, y, v), 'air'))

        def free(u, y, v):
            return not solid(u, y, v) and not solid(u, y + 1, v)
        embedded, was_open, held, doomed, bad, inside = 0, 0, [], 0, [], []
        held_open = 0
        for u in range(0, 21):
            for v in range(-15, 16):
                for y in range(1, 19):
                    if free(u, y, v):
                        continue
                    embedded += 1
                    if (u, y, v) in before and (u, y + 1, v) in before:
                        was_open += 1
                    out = False
                    for du, dv in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        out = out or free(u + du, y, v + dv) or \
                            (not solid(u, y + 2, v) and free(u + du, y + 1, v + dv))
                    out = out or not solid(u, y - 1, v)
                    rise = y
                    while not out and rise < 19 and not solid(u, rise + 2, v):
                        rise += 1
                        out = free(u, rise, v)
                    if out:
                        continue
                    held.append((u, y, v))
                    if (u, y, v) in before and (u, y + 1, v) in before:
                        held_open += 1
                    if suffocates(cells[u, y + 1, v]):
                        doomed += 1
                    else:
                        row = ((u, y, v), cells[u, y, v], cells[u, y + 1, v])
                        (bad if (u, y, v) in before and (u, y + 1, v) in before
                         else inside).append(row)
        print('%-7s %d body positions in a walkable cell (%d of them open in 0.88.0), %d with '
              'no way out (%d open in 0.88.0), %d of those suffocate, %d do not (%d of these '
              'open in 0.88.0)' % (faction, embedded, was_open, len(held), held_open, doomed,
                                   len(bad) + len(inside), len(bad)))
        for row in bad:
            print('    open in 0.88.0:', row)
        for row in inside:
            print('    solid in 0.88.0, so nobody stands there:', row)
        worst += len(bad)
        total += len(held)
    print('no way out: %d positions, %d without suffocation that a player could have stood '
          'in' % (total, worst))
    return 1 if worst else 0


if __name__ == '__main__':
    sys.exit(main())
