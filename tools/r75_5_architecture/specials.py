#!/usr/bin/env python3
"""Bake the approved remaining city proposals, with explicit typology boundaries."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import integrate as I
import services as S
R = S.R
SCOPE_SOURCE = 'cbc67f1f'
CAPITAL_ROYAL = {'highcourt_kings_hall','dur_brannoc_kings_hall','lethariel_kings_hall',
                 'gor_drazhak_warlord_hall','kezamba_kings_hall','nhal_veyr_mausoleum'}
OPEN_COLONNADE = {'dur_brannoc_terrace_market','kezamba_vine_moot'}
OPEN_SHRINE = {'lethariel_mere_shrine','lethariel_plot_mere_shrine'}
PROTECTED = {'floor','castle_paving','plaza','path','ground','ground_bare','rug','rug_accent',
             'door','door_hidden','window','castle_slit','seat','railing','fence','storage',
             'tree_log','tree_leaves','hearth','workbench','table_top','table_leg','planter'}


def selected():
    rows = json.loads(subprocess.check_output(['git','show',SCOPE_SOURCE+
        ':tools/city_architecture_specials/catalog.json'],cwd=I.ROOT,text=True))
    rows = {k:s for k,s in rows.items() if s['status']=='pending'}
    assert len(rows)==87 and len({s['template'] for s in rows.values()})==72
    return rows


def mat(role,race): return I.ROWS['facade_'+role][I.RACES.index(race)]


def royal(tpl,before,roles,race):
    """The existing castle's piers, tower corners and cornices carry the frame.

    All floor/dais paving, stairs, throne, lamps, slits and furniture are kept.
    The hall's open side arcades are never rebuilt or inferred from a footprint.
    """
    after = dict(before)
    towers = [(0,0,8,7,25),(36,0,44,7,25),(0,30,4,34,33),
              (40,30,44,34,33),(16,0,28,6,18)]
    for p,(old,p2) in before.items():
        x,y,z=p;role=roles.get(p);new=None
        if role=='foundation': new=mat('base',race)
        elif role in ('signature','castle_wall') and y>=3:
            # Stone remains the dominant fabric, including dwarf gables.
            frame=False;band=False
            for x0,z0,x1,z1,top in towers:
                if x0<=x<=x1 and z0<=z<=z1 and y<=top:
                    frame=(x in (x0,x1) and z in (z0,z1))
                    band=y in (top-3,top)
                    break
            else:
                frame=((x in (2,3,4,40,41,42) and z in (9,10,16,22,27,32)) or
                       (x in (4,40) and z in (8,32)) or
                       (z in (0,1,8) and x in (18,26)))
                band=(y==16 and 4<=x<=40 and 8<=z<=32)
            new=mat('monument_band' if band else 'monument_frame' if frame else 'masonry',race)
            if race=='elf' and not frame and not band and x in (4,40) and 12<=y<=15 and 8<z<32:
                new=mat('infill',race)
        elif role=='window_frame': new=mat('monument_frame',race)
        elif role=='beam': new=mat('open_wood',race)
        elif role and role.startswith('roof_') and race=='dwarf':
            new=R.shaped(I.D+'darkage_slate',role)
        if new:after[p]=(new,p2)
    return after


def transform(tpl,before,nodes,spec):
    race,kind=spec['race'],spec['kind'];roles=R.roles_of(tpl);after=dict(before)
    def put(p,new):
        if before[p][0]!='air':after[p]=(new,before[p][1])
    def full(p):return nodes[before[p][0]]['drawtype']=='normal'
    def pillar(p):
        suffix=tpl.legend[tpl.cells[p]]['variant'].lstrip('_')
        put(p,mat('pillar_'+suffix,race))
    name=tpl.name
    if name in CAPITAL_ROYAL:
        after=royal(tpl,before,roles,race)
    elif kind=='tower':
        analysis=copy.deepcopy(tpl)
        for p in analysis.cells:
            if p[1]>4 and roles.get(p) in R.ENVELOPE:analysis.cells[p]=I.T.FORCE_AIR
        shape=R.profile(analysis);shape['residential']=False
        after=R.transfer(tpl,before,nodes,race,shape)
        for p,role in roles.items():
            x,y,z=p
            if y in (6,7,8) and role in R.SHELL:
                put(p,mat('band' if y==8 else 'frame' if x in (0,8) and z in (0,8) else 'infill',race))
            if race=='human' and p in shape['roof']:put(p,R.shaped('default:brick',role))
    elif kind=='ruin':
        for p,role in roles.items():
            # Only replace the already-stone feet and rough wood remnants.
            # No missing part is reconstructed; surviving accent moss stays.
            if role=='foundation':put(p,'default:mossycobble')
            elif role in ('wall','post') and full(p):put(p,'grug_trees:gravewood_wood')
    elif kind=='treehouse':
        floor=min(p[1] for p,r in roles.items() if r=='floor')
        walls=[p for p,r in roles.items() if r=='wall']
        xmin,xmax=min(p[0] for p in walls),max(p[0] for p in walls)
        zmin,zmax=min(p[2] for p in walls),max(p[2] for p in walls)
        top=max(p[1] for p in walls)
        for p in walls:
            x,y,z=p
            put(p,mat('band' if y==top else 'frame' if x in (xmin,xmax) and z in (zmin,zmax) else 'infill',race))
        # Roof slabs already are marble. Leave trunk supports, floor, railing,
        # access stair and all late air masks exactly as authored.
        assert top>floor
    elif name=='kezamba_shrine':
        for p,role in roles.items():
            if role in ('plaza_edge','signature') and full(p):put(p,mat('base',race))
            # Totem timber, pale ritual bands and steps remain intact.
    elif name=='kezamba_moot_house':
        for p,role in roles.items():
            x,y,z=p
            if role=='signature' and y<=0:put(p,mat('base',race))
            elif role=='post':put(p,'default:junglewood')
            elif role=='wall':
                # Already massive raised basalt walls remain stone. Regular
                # corner strips form their edge above the raised platform.
                put(p,mat('monument_frame' if x in (0,8) else 'masonry',race))
            # Platform y4, access steps y1..3 and dark ceremonial roof stay.
    elif kind=='colonnade' or name in OPEN_COLONNADE or name in OPEN_SHRINE:
        for p,role in roles.items():
            y=p[1]
            if role=='pillar':pillar(p)
            elif role=='plaza_edge':put(p,mat('base',race))
            elif role=='castle_wall':put(p,mat('frame' if race=='troll' else 'monument_frame',race))
            elif role=='signature':
                put(p,mat('base' if name in OPEN_SHRINE and y<=2 else 'monument_band' if y==(6 if name in OPEN_SHRINE else 5) else 'monument_frame',race))
            elif role=='signature_slab':
                put(p,mat('stone_slab',race))
    elif kind=='gate':
        for p,role in roles.items():
            x,y,z=p
            if role in ('castle_wall','signature') and full(p):
                frame=x in (0,3,9,12) or (y in (5,6) and 3<=x<=9)
                band=y==6
                put(p,mat('base' if y<=0 else 'monument_band' if band else 'monument_frame' if frame else 'masonry',race))
            elif role in ('signature_slab','castle_wall_stair'):
                put(p,mat('stone_slab' if role.endswith('slab') else 'stone_stair',race))
    elif name=='highcourt_market_stable':
        for p,role in roles.items():
            if role=='post':put(p,mat('open_wood',race))
        # The shared roof is already wood; preserve it as a pen shelter.
    elif kind in ('market','yard','well','memorial') and name!='silverleaf_covered_market':
        for p,role in roles.items():
            if role=='plaza_edge':put(p,mat('base',race))
            elif role=='post' and kind!='memorial':
                # The first carved totem is a workpiece, not a house support.
                # Keep its bark at the carver socket just like the log piles.
                carving = name in ('kezamba_carver_yard','kezamba_shore_carvers') and p[0]==3 and p[2]==(6 if name=='kezamba_carver_yard' else 7)
                if not carving:put(p,mat('open_wood',race))
            elif role=='beam':put(p,mat('open_wood',race))
            elif role=='pillar':pillar(p)
            elif role in ('signature','castle_wall') and full(p):
                put(p,mat('monument_frame',race))
            elif role=='signature_slab':put(p,mat('stone_slab',race))
            # Low cobble walls retain their connected boxes and old material;
            # market awnings, stalls, working props and candle timber stay.
    else:
        # Enclosed sacred halls and the two ordinary sheltered structures.
        # Roof lanterns have their own existing posts above the main eave.
        shape=R.profile(tpl);shape['residential']=False
        if name=='silverleaf_covered_market':
            columns=[q for f in shape['faces'] for q in f['columns']]
            lo=[min(q[i] for q in columns) for i in (0,1)]
            hi=[max(q[i] for q in columns) for i in (0,1)]
            shape['faces']=[f for f in shape['faces'] if all(
                q[0]==(hi[0] if f['normal'][0]>0 else lo[0]) if f['normal'][0] else
                q[1]==(hi[1] if f['normal'][1]>0 else lo[1]) for q in f['columns'])]
            shape['belt']=min(f['cap'] for f in shape['faces'])
        after=R.transfer(tpl,before,nodes,race,shape)
        facade=R.facade_cells(shape,roles)
        for p,role in roles.items():
            if name=='silverleaf_covered_market' and role in ('post','beam') and p not in facade:put(p,mat('frame',race))
            if race=='human' and p in shape['roof']:put(p,R.shaped('default:brick',role))
            if race=='troll' and kind=='sacred' and p in shape['roof']:after[p]=before[p]
            if name=='sunscar_warlord_hall' and p in facade:
                put(p,mat('band' if facade[p] in ('pier','tie') else 'monument_frame',race))
            if role=='plaza_edge':put(p,mat('base',race))
    after={p:(I.map_node(n),p2) for p,(n,p2) in after.items()}
    assert before.keys()==after.keys()
    for p,old in before.items():
        new=after[p]
        if old==new:continue
        role=roles.get(p)
        assert role and role not in PROTECTED,(name,p,role)
        assert old[1]==new[1],(name,p,'orientation')
        for f in ('drawtype','node_box','collision_box','selection_box','walkable','buildable_to'):
            assert nodes[old[0]].get(f)==nodes[new[0]].get(f),(name,p,f,old,new)
    return after


def generate(write=False):
    nodes=json.loads((I.ROOT/'tools/building_templates/nodes.json').read_text())['nodes']
    for shape in ('stair','stair_inner','stair_outer','slab'):
        nodes['study:reed_'+shape]=nodes[I.D+'cottages_reet_'+shape]
    pal=I.T.Palettes(I.G.load_palettes('luajit',set(nodes)))
    report=dict(source=I.SOURCE,scope_source=SCOPE_SOURCE,classification='map reset',buildings={})
    groups={};templates={}
    for key,spec in selected().items():
        name=spec['template'];path=I.BASE+'/templates/'+name+'.tpl'
        tpl=I.T.parse_template(path,text=I.source(path));templates[name]=tpl
        before,errors=I.T.resolved_cells(tpl,I.T.resolve(tpl,pal,spec['binding']),pal)
        assert not errors,errors
        after=transform(tpl,before,nodes,spec)
        roles=R.roles_of(tpl)
        changes=[dict(position=p,role=roles[p],before=before[p],after=after[p]) for p in sorted(before) if before[p]!=after[p]]
        assert changes,(name,'approved proposal produced no material change')
        report['buildings'][key]=dict(template=path,sha256=hashlib.sha256(I.source(path).encode()).hexdigest(),
            placements=[spec['placement']],race=spec['race'],changes=changes,changed_cells=len(changes),
            typology=spec['kind'],geometry_preserved=True,protected_cells_unchanged=True)
        groups.setdefault(name,[]).append(dict(race=spec['race'],before=before,after=after))
    output=HERE/'specials.json'
    if write:output.write_text(json.dumps(report,indent=2)+'\n')
    else:assert json.loads(output.read_text())==json.loads(json.dumps(report))
    for name,uses in groups.items():
        expected=I.bake(templates[name],uses,pal);path=I.ROOT/I.BASE/'templates'/(name+'.tpl')
        if write:path.write_text(expected)
        else:assert path.read_text()==expected,name
    print('Remaining proposals:',len(report['buildings']),'contexts,',len(groups),'templates;',
          sum(s['changed_cells'] for s in report['buildings'].values()),'material cells')
    return report

if __name__=='__main__':generate('--write' in sys.argv)
