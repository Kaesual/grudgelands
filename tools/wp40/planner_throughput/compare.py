#!/usr/bin/env python3
"""Compare three interleaved real-engine runs per output-preserving variant."""
import csv
import hashlib
import re
import statistics
import sys
from pathlib import Path

root = Path(sys.argv[1])
output = Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=False)
repo = Path(__file__).resolve().parents[3]
# Baseline 4403f01 with only the common profile callback instrumentation.
BASELINE_SNAPSHOT_SHA256 = "b525f6660723018d5f16e65e80291c7ca9ada10858116c697d26c18b8c2805fc"
changed_paths = ('./mods/MAPGEN/grug_mapgen/wp40/planner.lua',
                 './mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua')
snapshots = {}
identity = None
runs = {}
for variant in ('baseline', 'optimized'):
    runs[variant] = []
    for number in range(1, 4):
        path = root / f'{variant}-{number}'
        summary = dict(line.split('\t', 1) for line in
                       (path / 'summary.tsv').read_text().splitlines())
        environment = dict(line.split('\t', 1) for line in
                           (path / 'environment.tsv').read_text().splitlines())
        assert summary['cold_mapgen_callbacks'] == '10'
        assert summary['disk_mapgen_callbacks'] == '0'
        assert summary['disk_loaded_blocks'] == '1250'
        assert summary['full_voxels'] == '5120000'
        assert environment['settlement_stages'] == '0'
        current = (summary['full_digest'], summary['full_vocabulary_digest'],
                   summary['sample_digest'], environment['seed'],
                   (path / 'engine-version.txt').read_bytes(),
                   (path / 'harness.sha256').read_bytes())
        if identity is None:
            identity = current
        assert identity == current, (path, 'output or measurement inputs differ')
        manifest_bytes = (path / 'snapshot-files.sha256').read_bytes()
        manifest_hash = hashlib.sha256(manifest_bytes).hexdigest()
        assert manifest_hash == summary['snapshot_manifest_sha256'], path
        snapshot = {}
        for line in manifest_bytes.decode().splitlines():
            digest, name = line.split('  ', 1)
            assert name not in snapshot, (path, 'duplicate snapshot path')
            snapshot[name] = digest
        if variant == 'baseline':
            assert manifest_hash == BASELINE_SNAPSHOT_SHA256, (path, 'baseline differs')
        else:
            baseline = snapshots['baseline']
            assert snapshot.keys() == baseline.keys(), (path, 'snapshot paths differ')
            differences = {name for name in snapshot if snapshot[name] != baseline[name]}
            assert differences == set(changed_paths), (path, 'production diff differs')
            for name in changed_paths:
                expected = hashlib.sha256((repo / name).read_bytes()).hexdigest()
                assert snapshot[name] == expected, (path, 'reviewed source differs', name)
        if variant in snapshots:
            assert snapshot == snapshots[variant], (path, 'variant changed between runs')
        snapshots[variant] = snapshot
        callbacks = [dict(re.findall(r'(\w+)=([^ ]+)', line)) for line in
                     (path / 'cold/profile-events.log').read_text().splitlines()
                     if 'PROFILE_CALLBACK ' in line]
        assert len(callbacks) == 10
        runs[variant].append(callbacks)

with (output / 'owners.tsv').open('w') as stream:
    writer = csv.writer(stream, delimiter='\t', lineterminator='\n')
    writer.writerow(('variant', 'owner', 'plan_median_us', 'writer_median_us',
                     'callback_median_us', 'callback_min_us', 'callback_max_us'))
    for variant, population in runs.items():
        for index in range(10):
            positions = {rows[index]['minp'] for rows in runs['baseline'] + runs['optimized']}
            assert len(positions) == 1
            writer.writerow((variant, positions.pop(), *(
                statistics.median(int(rows[index][key]) for rows in population)
                for key in ('plan_us', 'writer_us', 'total_us')),
                min(int(rows[index]['total_us']) for rows in population),
                max(int(rows[index]['total_us']) for rows in population)))
with (output / 'aggregate.tsv').open('w') as stream:
    writer = csv.writer(stream, delimiter='\t', lineterminator='\n')
    writer.writerow(('variant', 'population', 'metric', 'median_us', 'min_us', 'max_us'))
    for variant, population in runs.items():
        for label, indices in (('all', range(10)), ('surface', range(9)), ('deep', (9,))):
            for key in ('plan_us', 'writer_us', 'total_us'):
                totals = [sum(int(rows[i][key]) for i in indices) for rows in population]
                writer.writerow((variant, label, key, statistics.median(totals),
                                 min(totals), max(totals)))
print('PASS: six engine runs, bound source snapshots, identical output and timing harness; 5,120,000 voxels/run')
