#!/usr/bin/env python3
"""Apply the approved castle edits through the existing editor's validated Save."""
from pathlib import Path
import argparse
import copy
import hashlib
import importlib.util
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
EDITOR = ROOT / 'tools/building_templates/editor'
sys.path.insert(0, str(EDITOR))
spec = importlib.util.spec_from_file_location('template_editor', EDITOR / 'serve.py')
E = importlib.util.module_from_spec(spec)
spec.loader.exec_module(E)
T = E.tplfile
NAMES = ('dur_brannoc_kings_hall', 'highcourt_kings_hall', 'lethariel_kings_hall',
         'gor_drazhak_warlord_hall', 'nhal_veyr_mausoleum', 'kezamba_kings_hall')
BASE = ROOT / 'mods/MAPGEN/grug_mapgen/building_templates/templates'


def proposal(original):
    m = copy.deepcopy(original)
    def key(entry):
        for k, text in m.legend:
            if text == entry:
                return k
        k = next(k for k in T.ALPHABET if all(k != old for old, _ in m.legend))
        m.legend.append([k, entry])
        return k
    def at(x, y, z):
        return m.layers[y][z][x]
    def put(x, y, z, value):
        row = m.layers[y][z]
        m.layers[y][z] = row[:x] + value + row[x + 1:]
    # Keep the approved footprint, upholstery and ornament row. Remove one
    # full base layer and the half-node caps above the lowered arm blocks.
    for y in range(5, 12):
        for z in range(28, 31):
            for x in range(20, 25):
                put(x, y, z, '.')
    for y in range(6, 12):
        for z in range(28, 31):
            for x in range(20, 25):
                put(x, y - 1, z, original.layers[y][z][x])
    for x in (20, 24):
        for z in (28, 29):
            put(x, 7, z, '.')
    # The approved joined piers replace the lower inner side wall. Fill their
    # backs and the front slot; each bay opens directly onto the large hall.
    for x, outside in ((4, 2), (40, 42)):
        material = original.layers[4][17][x]
        for z in range(9, 30):
            pier = z in (9, 10, 16, 22, 27)
            for y in range(3, 11):
                put(x, y, z, material if pier else '.')
                if pier:
                    for xx in range(min(x, outside), max(x, outside) + 1):
                        put(xx, y, z, material)
        xx = x + (1 if x == 4 else -1)
        for old_z, new_z in zip((11, 17, 23, 29), (10, 16, 22, 27)):
            for y in (6, 7):
                put(xx, y, new_z, original.layers[y][old_z][xx])
                put(xx, y, old_z, '.')
        for z in (14, 20):
            put(x + (2 if x == 4 else -2), 3, z, '.')
    # Shift the same 1.5-node ridge group down half a node using existing forms.
    full_roof = key('role roof_ridge channel=roof')
    lower_roof = key('role roof_slab channel=roof')
    for z in range(8, 33):
        put(22, 27, z, full_roof)
        put(22, 28, z, lower_roof)
    # Upper slabs leave half-node daylight gaps over the gable walls. Fill
    # only these end-course cells; all interior roof slabs/stairs stay intact.
    for z in (8, 32):
        for x in range(5, 40, 2):
            y = 18 + min(x - 4, 40 - x) // 2
            assert dict(original.legend)[original.layers[y][z][x]] == 'role roof_slab channel=roof o=facedir:20'
            put(x, y, z, full_roof)
    assert m.points == original.points
    return m


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--save', action='store_true', help='Use validated editor Save for shipped templates')
    args = parser.parse_args()
    editor = E.Editor(str(ROOT))
    report = {}
    for name in NAMES:
        path = BASE / (name + '.tpl')
        snapshot = HERE / 'before' / path.name
        snapshot.parent.mkdir(exist_ok=True)
        if not snapshot.exists():
            snapshot.write_bytes(path.read_bytes())
        old = T.load(snapshot.read_text(), str(snapshot))
        m = proposal(old)
        body = {'name': name, 'hash': E.sha(path.read_bytes()), 'cell': m.cell,
                'legend': m.legend, 'layers': m.layers,
                'points': [[x, y, z] for _, x, y, z, _ in m.points], 'confirm': True}
        _, _, _, text = editor.edited_text(body)
        expected = HERE / 'proposed' / path.name
        expected.parent.mkdir(exist_ok=True)
        expected.write_text(text)
        # Rerunning is allowed only on the preserved baseline or exact output.
        assert path.read_bytes() in (snapshot.read_bytes(), text.encode()), 'Unexpected template edit: ' + name
        changes = sum(a != b for la, lb in zip(old.layers, m.layers)
                      for ra, rb in zip(la, lb) for a, b in zip(ra, rb))
        assert changes == 502, (name, changes)
        result = {'changed_cells': changes, 'source_sha256': E.sha(snapshot.read_bytes()),
                  'target_sha256': E.sha(text.encode())}
        if args.save:
            if path.read_text() == text:
                result['save'] = {'saved': True, 'unchanged': True, 'reason': 'Exact previously validated output'}
            else:
                print('Validated editor Save: ' + name, flush=True)
                try:
                    result['save'] = editor.save(body)
                except E.Refused as exc:
                    result['refused'] = {'reason': exc.reason, 'details': exc.extra}
                    report[name] = result
                    (HERE / 'save-report.json').write_text(json.dumps(report, indent=2) + '\n')
                    raise
        report[name] = result
        (HERE / ('save-report.json' if args.save else 'proposal-report.json')).write_text(json.dumps(report, indent=2) + '\n')
        print(name + ': ' + str(changes) + ' cells', flush=True)


if __name__ == '__main__':
    main()
