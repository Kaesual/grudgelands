"""Fail closed on frozen hashes, actual writer/engine disagreements or unexplained deltas."""
import argparse
import collections
import csv
import gzip
import hashlib
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('repo', type=Path)
p.add_argument('evidence', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)

def rows(path):
    text = gzip.decompress(path.read_bytes()).decode() if path.suffix == '.gz' else path.read_text()
    result = []
    for line in text.splitlines():
        if not line or line.startswith('#'):
            continue
        v = line.split('\t')
        result.append((tuple(map(int, v[:3])), tuple(v[3:])))
    assert len(dict(result)) == len(result), path
    return result

def digest(values):
    return hashlib.sha256('\n'.join(':'.join(map(str, pos + value)) for pos, value in values).encode()).hexdigest()

def load(kind, filename):
    return rows(a.evidence / kind / (filename + '.gz'))

def changed(x, y):
    return {pos for pos in x.keys() | y.keys() if x.get(pos) != y.get(pos)}

heights = []
for period in ('historical', 'precap'):
    heights.append({(int(x), int(z)): int(y) for x, z, y in csv.reader(
        (a.evidence / 'receipts' / ('lethariel-' + period + '-heights.tsv')).open(), delimiter='\t')})
gormasks = [dict(rows(a.evidence / 'masks' / ('gor-' + v + '.tsv.gz'))) for v in ('old', 'new')]
gorfull = [dict(rows(a.evidence / 'full-world' / ('gor_drazhak-' + v + '.tsv.gz'))) for v in ('old', 'new')]
summary = []
for capital in ('highcourt', 'dur_brannoc', 'gor_drazhak', 'nhal_veyr', 'lethariel', 'kezamba'):
    for label in ('avenue', 'rampart', 'corner', 'gate'):
        filename = capital + '-' + label + '.tsv'
        if not (a.evidence / 'old-world' / (filename + '.gz')).exists():
            assert capital in ('lethariel', 'kezamba') and label != 'avenue'
            continue
        old_rows, new_rows = load('old-world', filename), load('new-world', filename)
        old, new = dict(old_rows), dict(new_rows)
        engine_receipt = gzip.decompress((a.evidence / 'engine' / ('final-' + capital) / 'overlay-delta.tsv.gz').read_bytes()).decode()
        engine_row = next(row for row in csv.DictReader(engine_receipt.splitlines(), delimiter='\t') if row['label'] == label)
        assert engine_row['candidate'] == '8dd1c8e463a13ccc356cdade123875471b398707'
        assert digest(new_rows) == engine_row['new_digest'] and len(new_rows) == int(engine_row['new_cells'])
        historical, precap, fixed = [dict(load(v, filename)) for v in ('historical', 'precap', 'fixed')]
        expected = a.repo / 'tools/wp13/evidence/20260915-capital-terrain' / capital / (label + '-digest-531802985935182545.txt')
        words = expected.read_text().split()
        old_count = int(next(w.split('=')[1] for w in words if w.startswith('overlay_cells=')))
        assert digest(old_rows) == words[0] and len(old_rows) == old_count, (capital, label, 'old hash')
        assert all(new.get(pos) == value for pos, value in fixed.items()), (capital, label, 'actual writer mismatch')
        prior, inner = changed(historical, precap), changed(precap, fixed)
        if label != 'avenue':
            assert not inner, (capital, label, 'outer production regression')
        else:
            assert all(40 <= pos[0] <= 50 and -12 <= pos[2] <= 12 for pos in inner)
        if label == 'gate':
            assert old_rows == new_rows, (capital, 'outer gate regression')
        counts = collections.Counter()
        detail = []
        for pos in sorted(changed(old, new)):
            before, after = old.get(pos), new.get(pos)
            # Any authored endpoint that exists must agree with the engine.
            if historical.get(pos) is not None:
                assert before == historical[pos], (capital, pos, 'historical writer mismatch')
            if fixed.get(pos) is not None:
                assert after == fixed[pos], (capital, pos, 'fixed writer mismatch')
            if pos in inner:
                category = 'accepted_inner_projection'
            elif pos in prior:
                category = 'prior_world_authored_projection'
            elif capital == 'lethariel':
                x, y, z = pos
                assert heights[0][x, z] != heights[1][x, z]
                for value, height in ((before, heights[0][x, z]), (after, heights[1][x, z])):
                    if value is not None:
                        assert value == ('grug_nodes:dirt_with_silver_litter', '0') and y == height
                category = 'prior_world_surface_height'
            elif capital == 'gor_drazhak' and label == 'avenue':
                assert 40 <= pos[0] <= 50 and -12 <= pos[2] <= 12
                assert gormasks[0].get(pos) != gormasks[1].get(pos)
                for mask, world in zip(gormasks, gorfull):
                    if mask.get(pos) is not None:
                        assert mask[pos] == world[pos] == ('grug_decor:castle_stonewall', '0')
                    else:
                        assert world[pos] == ('default:dry_dirt', '0')
                category = 'accepted_inner_nonpalette_foundation'
            else:
                raise AssertionError((capital, label, pos, before, after, 'unexplained'))
            counts[category] += 1
            detail.append(dict(position=pos, old=before, new=after, category=category))
        (a.output / (capital + '-' + label + '-delta.json')).write_text(json.dumps(detail, indent=2) + '\n')
        summary.append(dict(capital=capital, label=label, old_sha256=digest(old_rows), new_sha256=digest(new_rows),
                            old_cells=len(old_rows), new_cells=len(new_rows), changed_coordinates=len(detail),
                            accepted_inner=counts['accepted_inner_projection'] + counts['accepted_inner_nonpalette_foundation'],
                            prior_world=counts['prior_world_authored_projection'] + counts['prior_world_surface_height'],
                            unexplained=0, status='match' if not detail else 'attributed'))
assert len(summary) == 18
# Controlled Highcourt replay isolates earlier world/terrain changes from builders.
for label in ('avenue', 'rampart', 'corner', 'gate'):
    filename = 'highcourt-' + label + '.tsv'
    assert load('terrain-control', filename) == load('precap', filename)
with (a.output / 'summary.tsv').open('w') as f:
    writer = csv.DictWriter(f, fieldnames=list(summary[0]), delimiter='\t')
    writer.writeheader()
    writer.writerows(summary)
print('PASS 18 exact historical hashes; 18 final engine/source checks; zero unexplained changed coordinates')
