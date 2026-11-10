#!/usr/bin/env python3
"""Replace authored fence/slab tables using the editor serializer and shared gate.

The complete batch is validated before any shipped file is written. No validator
rules or template metadata are changed. This is a bounded maintenance script,
not a new editor feature. A second invocation verifies exact installed hashes.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/building_templates/editor'))
import serve as E
T = E.T
BASE = ROOT / 'mods/MAPGEN/grug_mapgen/building_templates/templates'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def meanings(t):
    return {p: t.legend[k]['text'] if k in t.legend else k for p, k in t.cells.items()}

def points(t):
    return [{k: v for k, v in p.items() if k != 'line'} for p in t.points]

def proposal(path, data):
    old = T.parse_template(str(path), text=data.decode())
    tops = {p for p, k in old.cells.items() if k in old.legend
            and old.legend[k]['kind'] == 'role' and old.legend[k]['name'] == 'table_top'}
    legs = {p for p, k in old.cells.items() if k in old.legend
            and old.legend[k]['kind'] == 'role' and old.legend[k]['name'] == 'table_leg'}
    if not tops and not legs:
        return None
    expected_legs = {(x, y-1, z) for x, y, z in tops}
    assert legs == expected_legs, (path.name, 'unpaired furniture', legs ^ expected_legs)
    assert not tops & legs
    m = E.tplfile.load(data.decode(), str(path))
    # Retain existing key widths. All former leg keys become complete tables;
    # top keys become air only at the explicitly audited positions.
    leg_keys = {old.cells[p] for p in legs}
    m.legend = [[k, 'node grug_decor:xdecor_table' if k in leg_keys else value]
                for k, value in m.legend]
    for x, y, z in tops:
        row = m.layers[y-m.origin[1]][z-m.origin[2]]
        i = (x-m.origin[0]) * m.cell
        m.layers[y-m.origin[1]][z-m.origin[2]] = row[:i] + '.' * m.cell + row[i+m.cell:]
    body = {'name': old.name, 'hash': sha(data), 'cell': m.cell,
            'legend': m.legend, 'layers': m.layers,
            'points': [[p[1], p[2], p[3]] for p in m.points]}
    return old, body, tops, legs

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--save', action='store_true')
    args = parser.parse_args()
    report_path = HERE / 'save-report.json'
    if report_path.exists():
        report = json.loads(report_path.read_text())
        for row in report['templates']:
            assert sha((BASE / (row['name']+'.tpl')).read_bytes()) == row['output_sha256'], row['name']
        print('Already installed: all output hashes match; no writes or repeated validation.')
        return
    editor = E.Editor(str(ROOT))
    replacements, rows, pending = {}, [], []
    for path in sorted(BASE.glob('*.tpl')):
        data = path.read_bytes()
        p = proposal(path, data)
        if not p:
            continue
        old, body, tops, legs = p
        name, checked_path, checked_data, text = editor.edited_text(body)
        assert checked_data == data and Path(checked_path) == path
        new = T.parse_template(str(path), text=text)
        before, after = meanings(old), meanings(new)
        changed = {p for p in before.keys() | after.keys() if before.get(p) != after.get(p)}
        assert changed == tops | legs, name
        assert all(after[p] == 'air' for p in tops)
        assert all(after[p] == 'node grug_decor:xdecor_table' for p in legs)
        assert points(old) == points(new)
        assert (old.origin, old.size, old.pivot, old.races) == (new.origin, new.size, new.pivot, new.races)
        replacements[editor.relative(name)] = text
        rows.append({'name': name, 'source_sha256': sha(data), 'output_sha256': sha(text.encode()),
                     'table_cells': len(legs), 'changed_cells': len(changed),
                     'removed_tops': sorted(tops), 'installed_tables': sorted(legs),
                     'points_unchanged': True, 'other_cells_unchanged': True})
        pending.append((path, data, text.encode()))
    assert len(rows) == 153 and sum(r['table_cells'] for r in rows) == 575, 'Inventory changed; inspect before proceeding'
    print('Prepared 153 templates / 575 table cells. Validating entire candidate batch...', flush=True)
    report = E.check.validate(ROOT, 'file', replacements, builds=True)
    known = E.check.known_defects(ROOT)
    errors, warnings = [], list(report.warnings)
    for finding in report.errors:
        rule, where, pos, _ = finding
        if any(d[:3] == (where, rule, pos) for d in known):
            warnings.append(finding)
        else:
            errors.append(finding)
    result = {'templates': rows, 'classification': 'map reset',
              'validation': {'errors': errors, 'warnings': warnings, 'counts': report.counts,
                             'rosters': report.rosters, 'baseline': report.baseline,
                             'builds': True}}
    (HERE / 'proposal-report.json').write_text(json.dumps(result, indent=2)+'\n')
    assert not errors, errors
    print('Shared candidate gate PASS: zero errors; %d warnings.' % len(warnings), flush=True)
    if not args.save:
        return
    # Verify every source before the first write, then again per file. Preserve
    # a durable exact baseline for review, including prior worktree fixes.
    for path, data, _ in pending:
        assert path.read_bytes() == data, str(path) + ' changed during validation'
    snapshot = HERE / 'before'
    snapshot.mkdir(exist_ok=True)
    for path, data, output in pending:
        old = snapshot / path.name
        if old.exists():
            assert old.read_bytes() == data, str(old) + ' snapshot differs'
        else:
            old.write_bytes(data)
        assert path.read_bytes() == data, str(path) + ' changed before write'
        E.write_atomic(str(path), output)
        assert path.read_bytes() == output
    report_path.write_text(json.dumps(result, indent=2)+'\n')
    print('Saved 153 templates: 1150 furniture cells, no changed points or other cells.')

if __name__ == '__main__':
    main()
