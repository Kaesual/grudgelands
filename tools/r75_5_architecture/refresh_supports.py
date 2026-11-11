#!/usr/bin/env python3
"""Refresh existing decor support pins; leave all other bytes/placements intact."""
import json
from pathlib import Path
import re
import subprocess
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--report", default="support_changes.json")
args = parser.parse_args()
assert Path(args.report).name == args.report and args.report.endswith(".json")
ROOT = Path(__file__).resolve().parents[2]
rows = subprocess.check_output(['luajit', str(Path(__file__).with_suffix('.lua')), str(ROOT)], text=True)
changes = {}
for line in rows.splitlines():
    ident, pos, old, new = line.split('\t')
    changes[ident,pos] = (old,new)
p = ROOT/'mods/MAPGEN/grug_mapgen/wp40/city_decor_catalog.lua'
before = p.read_text()
lines = []; applied = set()
for line in before.splitlines(keepends=True):
    match = re.search(r'\{id="([^"]+)"',line)
    if match: ident = match[1]
    match = re.search(r'\{x=(-?\d+),y=(-?\d+),z=(-?\d+),',line)
    if match:
        key = ident, ':'.join(match.groups())
        if key in changes:
            old,new = changes[key]
            assert 'support="'+old+'"' in line
            line = line.replace('support="'+old+'"','support="'+new+'"')
            applied.add(key)
    lines.append(line)
after = ''.join(lines)
assert applied == set(changes)
assert re.sub(r'support="[^"]+"','support=""',before) == re.sub(r'support="[^"]+"','support=""',after)
p.write_text(after)
p = ROOT/'tools/r75_city/scene_samples.json'
samples = json.loads(p.read_text())
for sample in samples.values():
    for placement in sample['placements']:
        key = sample['id'], ':'.join(str(placement[k]) for k in ('x','y','z'))
        if key in changes:
            assert placement['support'] == changes[key][0]
            placement['support'] = changes[key][1]
p.write_text(json.dumps(samples,indent=2,sort_keys=True)+'\n')
if changes:
    (Path(__file__).parent/args.report).write_text(json.dumps([
        dict(id=i,position=p,before=a,after=b) for (i,p),(a,b) in sorted(changes.items())],indent=2)+'\n')
print(len(changes), 'support pins refreshed; every decoration target, node and orientation unchanged.')
