#!/usr/bin/env python3
"""Author the explicitly requested moon-shrine follow-up from its frozen source."""
import hashlib
import json
from pathlib import Path
import sys
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import integrate as I
sys.path.insert(0, str(ROOT/'tools/city_architecture_rollout'))
from rules import profile, transfer, roles_of, SHELL

name = 'silverleaf_moon_shrine'
path = I.BASE+'/templates/'+name+'.tpl'
nodes = json.loads((ROOT/'tools/building_templates/nodes.json').read_text())['nodes']
pal = I.T.Palettes(I.G.load_palettes('luajit',set(nodes)))
layout = I.T.parse_layout(str(ROOT/I.BASE/'layouts/silverleaf.layout'))
rec = next(p for p in layout.places if p['template'] == name)
binding = I.G.placement_binding(pal,layout,rec)
tpl = I.T.parse_template(path,text=I.source(path))
before, errors = I.T.resolved_cells(tpl,I.T.resolve(tpl,pal,binding),pal)
assert not errors, errors
shape = profile(tpl)
after = transfer(tpl,before,nodes,'elf',shape)
roles = roles_of(tpl)
changes = []
for p in sorted(before):
    if before[p] == after[p]: continue
    assert roles.get(p) in SHELL | {'foundation'}
    assert before[p][1] == after[p][1]
    for field in ('drawtype','node_box','collision_box','walkable','buildable_to'):
        assert nodes[before[p][0]].get(field) == nodes[after[p][0]].get(field), (p,field)
    changes.append(dict(position=p,role=roles[p],before=before[p],after=after[p]))
assert before.keys() == after.keys() and changes
assert all(before[p] == after[p] for p,r in roles.items() if r.startswith('roof_'))
placement = dict(layout=str(Path(layout.path).relative_to(ROOT)),line=rec['line'],town=layout.town,
                 race=layout.race,template=name,count=1,id=rec['id'],main=rec.get('main'),channels=rec['channels'])
report = dict(source=I.SOURCE,classification='map reset; authorized moon-shrine extension of round75.5',
    buildings={'silverleaf__'+name:dict(template=path,sha256=hashlib.sha256(I.source(path).encode()).hexdigest(),
        placements=[placement],race='elf',changes=changes,changed_cells=len(changes),
        geometry_preserved=True,protected_cells_unchanged=True,belt=shape['belt'])})
output=HERE/'shrine.json'
if '--write' in sys.argv:
    output.write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/path).write_text(I.bake(tpl,[dict(race='elf',before=before,after=after)],pal))
else:
    assert json.loads(output.read_text()) == json.loads(json.dumps(report))
    assert (ROOT/path).read_text() == I.bake(tpl,[dict(race='elf',before=before,after=after)],pal)
print('Moon shrine:',len(changes),'material cells; roofs, openings, geometry, furnishings and points preserved; belt y=',shape['belt'])
