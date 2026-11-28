#!/usr/bin/env python3
"""Build both templates, matched plates and the offline pick page. --check compares every byte."""
import argparse
import base64
import io
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from halls import BARRIER, BARRIER_BOX, FACTIONS, HERE, ROOT, bounds, cutaway, draft, flights, layout_box
import arena
import build_viewer as viewer
from plates import Plates
import smoke
from verify import check_hall, check_sightlines


def photo(image):
    buf = io.BytesIO()
    image.save(buf, 'JPEG', quality=91, subsampling=0, optimize=True)
    return buf.getvalue()


def uri(data):
    return 'data:image/jpeg;base64,' + base64.b64encode(data).decode('ascii')


def octants(boxes):
    # From Round 84. The gallery's narrow rails use exact boxes instead.
    masks = []
    for turn in range(4):
        mask = 0
        for i in range(8):
            x, y, z = (.25 if i & axis else -.25 for axis in (1, 2, 4))
            for _ in range(turn):
                x, z = -z, x
            if any(a < x < d and b < y < e and c < z < f for a, b, c, d, e, f in boxes):
                mask |= 1 << i
        masks.append(mask)
    return masks


def layers(text):
    grid = {}
    for block in text.split('\nlayer ')[1:]:
        y, *rows = block.splitlines()
        grid[int(y)] = [row[1:-1] for row in rows[:31]]
    return grid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    check = parser.parse_args().check

    def emit(path, data):
        data = data.encode() if isinstance(data, str) else data
        if check:
            if not path.is_file() or path.read_bytes() != data:
                raise SystemExit(f'Out of date: {path.relative_to(ROOT)}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)

    field, rotations = arena.field()
    registry = json.loads(Path(viewer.NODES_JSON).read_text())
    states = {}
    plans = {}
    nodes = {'proposed': {BARRIER: {
        'status': 'Pending game registration',
        'geometry': 'Invisible, light-transmitting full cube',
        'blocks': ['walking', 'flight', 'falling', 'aiming rays', 'projectiles'],
        'selectable': False, 'diggable': False, 'build_against': False,
    }}}
    for faction in FACTIONS:
        filename = f'breach_{faction}.tpl'
        before, after, text, counts = draft(faction)
        assert set(after.values()) - {BARRIER} <= registry['nodes'].keys()
        check_hall(faction, before, after, registry['nodes'])
        emit(HERE / 'templates' / filename, text)
        baseline = (HERE / 'baseline' / filename).read_text()
        plans[faction] = dict(before=layers(baseline), after=layers(text), counts=counts,
                              legend=dict(line.split(' node ') for line in text.split('legend\n')[1]
                                          .split('\nend')[0].splitlines()))
        nodes[faction] = sorted(set(after.values()))
        for state, model in [('before', before), ('after', after)]:
            states[faction, state, False] = arena.placed(faction, model)
            states[faction, state, True] = arena.placed(faction, cutaway(model, state == 'after'))
    emit(HERE/'nodes.json', json.dumps(nodes, indent=2)+'\n')
    names = sorted(set(field.values()).union(*(set(m.values()) for m in states.values())))
    indexes = {name: i for i, name in enumerate(names)}
    textures = viewer.Textures()
    types, report = viewer.build_types(names, registry['nodes'], registry['aliases'], textures, {})
    smoke_index = textures.index(smoke.TEXTURE)
    assert not (report['skipped'] or report['missing_mesh'] or textures.missing)
    for t in types:
        node = registry['nodes'][t['name']]
        assert node['liquidtype'] == 'none' and t['dt'] in ('normal', 'nodebox', 'glasslike')
        if 'boxes' in t and all(c in (-.5, 0, .5) for box in t['boxes'] for c in box):
            t['octants'] = octants(t['boxes'])

    def pack(cells):
        rows = [(*p, name, rotations.get(p, 0)) for p, name in sorted(cells.items())]
        return viewer.pack_cells({}, rows, indexes, names)['cells']

    payload = dict(types=types, textures=textures.images, field=pack(field), halls={},
                   smoke=dict(texture=smoke_index, **smoke.effect()), plans=plans, images={},
                   barrier={f: layout_box(f, BARRIER_BOX) for f in FACTIONS},
                   boxes={f: bounds(f) for f in FACTIONS}, poses={f: arena.poses(f) for f in FACTIONS},
                   views={k: t[0] for k, t in arena.VIEWS.items()},
                   runs=[[u, v, rise] for (u, v), rise in flights().items()])
    for faction in FACTIONS:
        other = next(f for f in FACTIONS if f != faction)
        for state in ('before', 'after'):
            for lifted in (False, True):
                key = f'{faction}-{state}' + ('-cut' if lifted else '')
                hall = states[faction, state, lifted]
                payload['halls'][key] = pack(hall)
                cells = field | states[other, state, False] | hall
                artist = Plates(cells, rotations, types, textures.images, smoke_index)
                if state == 'after' and not lifted:
                    check_sightlines(artist, faction)
                for view, pose in payload['poses'][faction].items():
                    if lifted != (view == 'cut'):
                        continue
                    image = photo(artist.render(pose, (960, 540), survey=lifted))
                    basename = f'{faction}-{state}-{view}'
                    emit(HERE / 'renders' / (basename + '.jpg'), image)
                    payload['images'][basename] = uri(image)
                print(f'{key} plates {"matched" if check else "built"}', flush=True)

    page = (HERE/'page.html').read_text()
    page = page.replace('__CANVAS__', (HERE/'canvas.js').read_text())
    page = page.replace('__CONTROLS__', (HERE/'controls.js').read_text())
    page = page.replace('__DATA__', json.dumps(payload, separators=(',', ':')).replace('</', '<\\/'))
    emit(HERE/'index.html', page)
    print(f'PASS · two parsed halls, both walks, sealed balconies and exterior rays, {len(names)} registered scene nodes, '
          f'{len(payload["images"])} plates, layer plans and offline page '
          + ('reproduced.' if check else 'written.'))


if __name__ == '__main__':
    main()
