#!/usr/bin/env python3
"""Reconcile the exact native catalog while retaining existing visibility policy."""
import json
import pathlib
import re
import sys

repo = pathlib.Path(__file__).resolve().parents[2]
source = repo / 'mods/PLAYER/grug_jobs/basics_routes.lua'
old = {}
for line in source.read_text().splitlines():
    if not line.startswith('\t{station='):
        continue
    values = dict(re.findall(r'(station|output|method|owner|main_material)="([^"]*)"', line))
    values['width'] = int(re.search(r'width=(\d+)', line)[1])
    values['shapeless'] = 'shapeless=true' in line
    values['inputs'] = json.loads('[' + re.search(r'inputs=\{(.*?)\}', line)[1] + ']')
    key = tuple(values[k] for k in ('station', 'output', 'method', 'width', 'shapeless')) + (tuple(values['inputs']),)
    assert key not in old
    old[key] = (values, line)

rows = {}
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    if '[r12recipe] ' not in line:
        continue
    fields = line.split('[r12recipe] ', 1)[1].split('\t')
    if len(fields) < 6:
        continue
    station, output, method, width, shapeless, owner = fields[:6]
    decode = lambda text: bytes.fromhex(text).decode()
    key = (station, decode(output), method, int(width), shapeless == '1', tuple(map(decode, fields[6:])))
    if key[1] == '':  # Engine hand/toolrepair sentinel, omitted by production UI.
        continue
    owner = 'general' if owner == 'general' else 'profession'
    assert key not in rows, 'duplicate native route'
    rows[key] = owner

assert len(rows) > 500, 'incomplete native capture'
simple = {'grug_cooking:bread', 'grug_fishing:cooked_fish', 'mobs:meat'}
result, additions, removals, changed = [], [], [], []
for key, owner in sorted(rows.items()):
    if key in old:
        previous, line = old[key]
        if previous['owner'] != owner:
            assert key[1] in simple and owner == 'general', ('unexpected ownership change', key)
            line = line.replace('owner="profession"', 'owner="general",starter=true')
            changed.append(key[1])
    else:
        station, output, method, width, shapeless, inputs = key
        assert (output == 'grug_farming:hoe_stone' and owner == 'general') or (output.startswith('grug_alchemy:mixture_') and owner == 'profession'), ('unexpected new route', key)
        quote = lambda value: json.dumps(value, ensure_ascii=False)
        line = '\t{station=%s,output=%s,method=%s,width=%d,shapeless=%s,inputs={%s},owner=%s%s},' % (
            quote(station), quote(output), quote(method), width, str(shapeless).lower(),
            ','.join(map(quote, inputs)), quote(owner), ',starter=true' if owner == 'general' else '')
        additions.append(output)
    result.append(line)
for key in old:
    if key not in rows:
        assert key[1] in {'default:sword_wood', 'default:sword_stone', 'grug_gear:staff_wood', 'grug_gear:bow_wood'} or any('_imbue_' in item or '_temper_' in item for item in (key[1],) + key[5]), ('unexpected removed route', key)
        removals.append(key[1])
source.write_text('-- Exact native engine catalog captured by tools/r13_integration/catalog_probe.\n-- Each route has one semantic owner; unchanged visibility policies are retained.\nreturn {\n' + '\n'.join(result) + '\n}\n')
print(json.dumps({'routes': len(rows), 'added': additions, 'removed': removals, 'ownership_changed': changed}, indent=2))
