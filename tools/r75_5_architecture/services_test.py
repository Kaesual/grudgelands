#!/usr/bin/env python3
"""Structural regressions: detached machinery, open walls, upper galleries."""
import json
import services as S
I = S.I
nodes = json.loads((I.ROOT/'tools/building_templates/nodes.json').read_text())['nodes']
for shape in ('stair','stair_inner','stair_outer','slab'):
    nodes['study:reed_'+shape] = nodes[I.D+'cottages_reet_'+shape]
pal = I.T.Palettes(I.G.load_palettes('luajit',set(nodes)))
checks = 0
for spec in S.selected().values():
    name,race = spec['template'],spec['race']
    tpl = I.T.parse_template(name+'.tpl',text=I.source(I.BASE+'/templates/'+name+'.tpl'))
    before,errors = I.T.resolved_cells(tpl,I.T.resolve(tpl,pal,spec['binding']),pal)
    assert not errors
    after,_ = S.transform(tpl,before,nodes,race)
    roles = S.R.roles_of(tpl)
    # Floors, windows, doors, furniture, fixed machines and ALL air remain exact.
    for p,v in before.items():
        if roles.get(p) not in S.R.SHELL | {'foundation','ceiling'} and not roles.get(p,'').startswith('roof_'):
            assert after[p] == v,(name,p,'protected cell')
    checks += 1
    if name.endswith('_miners_guild'):
        for p,v in before.items():
            if p[0] >= 11 and not roles.get(p,'').startswith('roof_'):
                assert after[p] == v,(name,p,'ore yard')
        for z in (3,8,12,16):
            for y in (2,3,4):
                assert after[0,y,z][0] == S.material('frame',race),(name,'continuous hall pier')
        for x in range(2,8):
            for y in (2,3):
                assert before[x,y,16] == after[x,y,16],(name,'tier frieze')
        checks += 3
    if name in S.OPEN:
        # The formerly doubled back-wall post at x=1 is now infill; the
        # real post at x=4 and the detached front supports remain continuous.
        assert after[1,2,8][0] == S.material('infill',race),(name,'single-width frame')
        for y in (1,2,3):
            assert after[4,y,0][0] == S.material('frame',race),(name,'open front support')
        checks += 2
    if name in S.TWO_LEVEL:
        for x,z in ((0,0),(0,8),(8,0),(8,8)):
            for y in (2,3,6,7):
                assert after[x,y,z][0] == S.material('frame',race),(name,'stacked corner supports')
        assert any(v[0]=='air' and p[1]==7 for p,v in after.items())
        checks += 2
print('Guild/service structural regressions:',checks,'checks passed')
