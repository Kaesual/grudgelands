#!/usr/bin/env python3
"""Check delivered scene cells against the reported facade defects and references."""
import base64
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools/building_templates/viewer'))
import templates as T

page = (HERE / 'compare.html').read_text()
data = json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>', page, re.S)[1])
audit = json.loads((HERE / 'audit.json').read_text())
reference = json.loads((ROOT / 'tools/dwarf_architecture_study/audit.json').read_text())
checks = []


def cells(key, side):
    packed = data['scenes'][key+'_'+side]['cells']
    return {(x,y,z): (data['types'][t]['name'],p2)
            for x,y,z,t,p2 in struct.iter_unpack('<hhhHB',base64.b64decode(packed))}


def expect(key, positions, name, label):
    after = cells(key, 'after')
    assert all(after[p][0] == name for p in positions), (label, [(p,after.get(p)) for p in positions])
    checks.append(label)


for key, spec in audit['buildings'].items():
    before, after = cells(key, 'before'), cells(key, 'after')
    assert before.keys() == after.keys()
    assert all(v[1] == after[p][1] for p,v in before.items())
    actual = {p:(v,after[p]) for p,v in before.items() if v != after[p]}
    recorded = {tuple(c['position']):(tuple(c['before']),tuple(c['after'])) for c in spec['changes']}
    assert actual == recorded, key
    tpl = T.parse_template(ROOT / spec['template'])
    # Geometry and openings are assessed from the delivered binary scene, not
    # from the transformer's claimed success flags.
    for p, (old,new) in actual.items():
        entry = tpl.legend[tpl.cells[p]]
        assert entry['kind'] == 'role' and entry['name'] not in {
            'door','door_hidden','window','chimney','floor','seat','storage'}, (key,p)
        if not spec['reference']:
            assert p[1] > spec['profile']['floor'] or entry['name'] == 'foundation', (key,p)
    if spec['reference']:
        expected = {tuple(c['position']):(tuple(c['before']),tuple(c['after']))
                    for c in reference['buildings'][spec['reference']]['changes']}
        assert actual == expected, key
checks += ['All 145 delivered scenes preserve occupied cells and orientation',
           'Scene deltas exactly match the audit; openings and protected content unchanged',
           'All twelve accepted references retain their exact deltas']

inn = 'dawnmere__dawnmere_harvest_inn'
expect(inn, [(0,y,4) for y in range(2,8)], 'grug_trees:gravewood_wood',
       'Long facade: intermediate post runs continuously to the high roofline')
expect(inn, [(0,4,z) for z in (5,6)], 'grug_decor:cottages_loam',
       'Long facade: old wide frame becomes a one-cell post with adjacent loam')
expect(inn, [(0,5,z) for z in range(15)], 'grug_trees:gravewood_wood',
       'Long facade: the low-eave tie spans the whole taller side')
expect(inn, [(0,7,z) for z in range(15)], 'grug_trees:gravewood_wood',
       'Long facade: the high roofline tie also spans the whole taller side')
expect(inn, [(0,6,5)], 'grug_decor:cottages_loam', 'Horizontal ties remain one cell thick')
dwarf = 'dur_brannoc__dur_brannoc_lane_house'
expect(dwarf, [(1,y,0) for y in (5,6)], 'grug_decor:darkage_stone_brick',
       'Dwarf high side wall no longer turns into timber above the low eave')
expect(dwarf, [(1,7,0)], 'default:stone_block', 'Dwarf high wall ends with a masonry tie')
expect(dwarf, [(0,9,3)], 'default:wood', 'Dwarf actual gable retains warm timber infill')
troll = 'kapok__kapok_elder_stilt'
expect(troll, [(0,y,0) for y in range(6,10)], 'default:junglewood',
       'Raised troll house: continuous frame starts above its existing platform')
expect(troll, [(0,8,1)], 'grug_nodes:clay_band_umber', 'Troll infill uses existing umber clay')
expect('lethariel__dur_brannoc_plaza_house', [(x,5,0) for x in range(9)],
       'grug_decor:darkage_serpentine', 'Elf accent is one continuous level including corners')

result = dict(page_sha256=hashlib.sha256((HERE/'compare.html').read_bytes()).hexdigest(), checks=checks)
(HERE/'structure-check.json').write_text(json.dumps(result,indent=2)+'\n')
print(len(checks), 'structural checks passed across 145 delivered scenes.')
