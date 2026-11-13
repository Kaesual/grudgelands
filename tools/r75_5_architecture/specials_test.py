#!/usr/bin/env python3
"""Protect collision, open circulation and the exceptional special-building forms."""
import json
import specials as S
I = S.I
nodes = json.loads((I.ROOT/'tools/building_templates/nodes.json').read_text())['nodes']
for shape in ('stair','stair_inner','stair_outer','slab'):
    nodes['study:reed_'+shape] = nodes[I.D+'cottages_reet_'+shape]
pal = I.T.Palettes(I.G.load_palettes('luajit',set(nodes)))
checks = 0
for material,source in (('marble','grug_decor:darkage_marble'),
                        ('ors','grug_decor:darkage_ors_block'),
                        ('basalt','grug_decor:darkage_basalt_block'),
                        ('junglewood','default:junglewood')):
    for shape in ('bottom','middle','top'):
        old=nodes['grug_decor:castle_pillar_stone_block_'+shape]
        new=nodes['grug_decor:city_pillar_'+material+'_'+shape]
        for field in ('node_box','collision_box','selection_box','drawtype','walkable','paramtype','paramtype2'):
            assert old.get(field)==new.get(field),(material,shape,field)
        assert new['tiles']==nodes[source]['tiles']
        assert new['groups']['not_in_creative_inventory']==1
        assert new['groups']['crossbrace_connectable']==old['groups']['crossbrace_connectable']
        checks+=1
for spec in S.selected().values():
    name=spec['template'];race=spec['race'];kind=spec['kind']
    tpl=I.T.parse_template(name+'.tpl',text=I.source(I.BASE+'/templates/'+name+'.tpl'))
    before,errors=I.T.resolved_cells(tpl,I.T.resolve(tpl,pal,spec['binding']),pal)
    assert not errors
    after=S.transform(tpl,before,nodes,spec);roles=S.R.roles_of(tpl)
    # All air, fixtures, doors, stairs outside roof roles, floors and planting
    # stay exact. Compare actual physical properties at EVERY occupied cell.
    for p,old in before.items():
        new=after[p];role=roles.get(p,'')
        if old[0]=='air' or role in S.PROTECTED or not role:
            assert new==old,(name,p,'protected circulation or fixture')
        if old[0]!='air':
            for field in ('node_box','collision_box','walkable','climbable','liquidtype'):
                assert nodes[old[0]].get(field)==nodes[new[0]].get(field),(name,p,field)
        assert old[1]==new[1],(name,p,'orientation')
    checks+=1
    if name in ('kezamba_carver_yard','kezamba_shore_carvers'):
        z=6 if name=='kezamba_carver_yard' else 7
        for y in (1,2,4,5):
            assert after[3,y,z]==before[3,y,z],(name,'carved workpiece remains a log')
        checks+=1
    if kind=='ruin':
        wood=[p for p,r in roles.items() if r in ('wall','post')]
        assert wood and all(after[p][0]=='grug_trees:gravewood_wood' for p in wood)
        assert any(v[0]=='air' for v in after.values())
        checks+=1
    if name in S.CAPITAL_ROYAL:
        for p,r in roles.items():
            if r in ('castle_paving','castle_slit','signature_slab') or (race=='troll' and r.startswith('roof_')):
                assert before[p]==after[p],(name,p,'combat space or ceremonial roof')
        checks+=1
    if name=='highcourt_market_stable':
        assert all(after[p][0] in ('grug_trees:gravewood_wood','default:junglewood')
                   for p,r in roles.items() if r=='post')
        checks+=1
    if kind=='tower':
        for p,r in roles.items():
            if p[1]==5 or (p[1]>=6 and before[p][0]=='air'):
                assert after[p]==before[p],(name,p,'tower gallery or open upper stage')
        checks+=1
    if kind=='treehouse':
        current=I.T.parse_template(I.ROOT/I.BASE/'templates'/(name+'.tpl'))
        for p,key in tpl.cells.items():
            assert bool(tpl.legend.get(key,{}).get('late'))==bool(current.legend.get(current.cells[p],{}).get('late'))
        for p,r in roles.items():
            if r!='wall':assert before[p]==after[p],(name,p,'treehouse platform/access/roof')
        checks+=1
    if name in S.OPEN_SHRINE:
        roof=[p for p,r in roles.items() if r=='signature_slab']
        assert roof and all(after[p][0]=='grug_decor:darkage_marble_slab' for p in roof)
        green=[p for p,v in after.items() if v[0]=='grug_decor:darkage_serpentine']
        assert green and {p[1] for p in green}=={6}
        checks+=1
    if name=='kezamba_moot_house':
        for p,r in roles.items():
            if r=='path' or r.startswith('roof_'):assert before[p]==after[p]
        checks+=1
print('Special-building regressions:',checks,'checks passed')
