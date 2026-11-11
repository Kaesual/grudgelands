#!/usr/bin/env python3
"""Offline authoring of the authorized guild and ordinary-service follow-up.

The scope is frozen before implementation. Structural special cases are bounded
by their existing geometry; this code never runs during world generation.
"""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import integrate as I
sys.path.insert(0, str(I.ROOT/'tools/city_architecture_rollout'))
import rules as R

SCOPE_SOURCE = '33b27633'
OPEN = {'hearthpine_workyard', 'highcourt_service_yard', 'kapok_drying_shed',
        'kezamba_trade_shed', 'gor_drazhak_bazaar_tannery'}
TWO_LEVEL = {'dawnmere_tollhouse', 'highcourt_martial_drill_yard',
             'dur_brannoc_garrison_drill_yard', 'gor_drazhak_war_drill_yard',
             'nhal_veyr_watch_drill_yard'}


def selected():
    catalog = json.loads(subprocess.check_output(['git', 'show', SCOPE_SOURCE+
        ':tools/city_architecture_specials/catalog.json'], cwd=I.ROOT, text=True))
    rows = {k:s for k,s in catalog.items() if s['priority'] == 'Als Nächstes' or
            s['template'] in {'dawnmere_tollhouse', 'nhal_veyr_watch_stables'}}
    assert len(rows) == 50 and len({s['template'] for s in rows.values()}) == 45
    return rows


def material(role, race):
    return I.ROWS['facade_'+role][I.RACES.index(race)]


def transform(tpl, before, nodes, race):
    roles = R.roles_of(tpl)
    guild = tpl.name.endswith('_miners_guild')
    if guild:
        # The hall has its own frame; yard timber, headframe, machines and
        # the six tier stones are protected independently of material roles.
        after = dict(before)
        for p, old in before.items():
            x,y,z = p; role = roles.get(p); new = None
            hall = 0 <= x <= 10 and 3 <= z <= 16
            boundary = hall and (x in (0,10) or z in (3,16))
            if hall and y <= 1 and role in R.SHELL | {'foundation'}:
                new = material('base',race)
            elif boundary and 2 <= y <= 5 and role in R.SHELL | {'foundation'}:
                pier = ((x in (0,10) and z in (3,8,12,16)) or (z == 3 and x in (4,6)))
                band = y == 5
                new = material('band' if band else 'frame' if pier else 'infill',race)
            elif boundary and y > 5 and role in R.SHELL:
                new = material('band' if race in ('orc','troll') else 'gable',race)
            elif role and role.startswith('roof_') and y >= 6 and -1 <= x <= 11 and 2 <= z <= 17:
                family = {'human':'default:brick','dwarf':I.D+'darkage_slate',
                          'undead':'default:obsidianbrick'}.get(race)
                if family: new = R.shaped(family,role)
            elif hall and y == 6 and role == 'ceiling' and race == 'orc':
                new = material('band' if boundary else 'roof_ridge',race)
            if new: after[p] = (new,old[1])
        mode = 'guild hall; protected ore yard'
    else:
        analysis = copy.deepcopy(tpl)
        if tpl.name in TWO_LEVEL:
            # Derive the lower load-bearing frame without mistaking the open
            # gallery, its floor and roof ties for one uninterrupted wall.
            for p in list(analysis.cells):
                if p[1] > 4 and roles.get(p) in R.ENVELOPE:
                    analysis.cells[p] = I.T.FORCE_AIR
        shape = R.profile(analysis)
        shape['residential'] = False
        if tpl.name in OPEN:
            # Interior and exterior faces of an open shed belong to the same
            # one-cell wall. Use only its outward-facing perimeter runs.
            columns = [q for f in shape['faces'] for q in f['columns']]
            lo = [min(q[i] for q in columns) for i in (0,1)]
            hi = [max(q[i] for q in columns) for i in (0,1)]
            shape['faces'] = [f for f in shape['faces'] if all(
                q[0] == (hi[0] if f['normal'][0] > 0 else lo[0]) if f['normal'][0] else
                q[1] == (hi[1] if f['normal'][1] > 0 else lo[1]) for q in f['columns'])]
            shape['belt'] = min(f['cap'] for f in shape['faces'])
        after = R.transfer(tpl,before,nodes,race,shape)
        facade = R.facade_cells(shape,roles)
        for p, old in before.items():
            role = roles.get(p); x,y,z = p
            if tpl.name in OPEN and role in ('post','beam') and p not in facade:
                after[p] = (material('frame',race),old[1])
            if tpl.name in TWO_LEVEL and y in (6,7,8) and role in R.SHELL:
                # Existing upper corner supports align with lower corners;
                # retain open gallery cells and the complete floor at y=5.
                pier = x in (0,8) and z in (0,8)
                after[p] = (material('band' if y == 8 else 'frame' if pier else 'infill',race),old[1])
            if race == 'human' and p in shape['roof']:
                after[p] = (R.shaped('default:brick',role),old[1])
        mode = 'open workshop' if tpl.name in OPEN else 'two-level gallery' if tpl.name in TWO_LEVEL else 'ordinary service facade'
    after = {p:(I.map_node(n),p2) for p,(n,p2) in after.items()}
    assert before.keys() == after.keys()
    for p, old in before.items():
        new = after[p]
        if old == new: continue
        role = roles.get(p)
        assert role in R.SHELL | {'foundation','ceiling'} or role.startswith('roof_'), (tpl.name,p,role)
        assert old[1] == new[1]
        for field in ('drawtype','node_box','collision_box','walkable','buildable_to'):
            assert nodes[old[0]].get(field) == nodes[new[0]].get(field), (tpl.name,p,field)
        if guild:
            x,y,z = p
            assert (0 <= x <= 10 and 3 <= z <= 16) or (role.startswith('roof_') and y >= 6 and -1 <= x <= 11 and 2 <= z <= 17)
    return after,mode


def generate(write=False):
    nodes = json.loads((I.ROOT/'tools/building_templates/nodes.json').read_text())['nodes']
    # The archived transfer names the already shipped reed shapes as preview
    # nodes. Supply identical geometry, then map them to their stable game ids.
    for shape in ('stair','stair_inner','stair_outer','slab'):
        nodes['study:reed_'+shape] = nodes[I.D+'cottages_reet_'+shape]
    pal = I.T.Palettes(I.G.load_palettes('luajit',set(nodes)))
    report = dict(source=I.SOURCE, scope_source=SCOPE_SOURCE, classification='map reset', buildings={})
    groups = {}; templates = {}
    for key,spec in selected().items():
        name = spec['template']; path=I.BASE+'/templates/'+name+'.tpl'
        tpl = I.T.parse_template(path,text=I.source(path));templates[name]=tpl
        before,errors = I.T.resolved_cells(tpl,I.T.resolve(tpl,pal,spec['binding']),pal)
        assert not errors, errors
        after,mode = transform(tpl,before,nodes,spec['race'])
        roles = R.roles_of(tpl)
        changes = [dict(position=p,role=roles[p],before=before[p],after=after[p])
                   for p in sorted(before) if before[p] != after[p]]
        assert changes, name
        report['buildings'][key] = dict(template=path,sha256=hashlib.sha256(I.source(path).encode()).hexdigest(),
            placements=[spec['placement']],race=spec['race'],changes=changes,changed_cells=len(changes),
            typology=mode,geometry_preserved=True,protected_cells_unchanged=True)
        groups.setdefault(name,[]).append(dict(race=spec['race'],before=before,after=after))
    output = HERE/'services.json'
    if write: output.write_text(json.dumps(report,indent=2)+'\n')
    else: assert json.loads(output.read_text()) == json.loads(json.dumps(report))
    for name,uses in groups.items():
        expected = I.bake(templates[name],uses,pal)
        path = I.ROOT/I.BASE/'templates'/(name+'.tpl')
        if write: path.write_text(expected)
        else: assert path.read_text() == expected,name
    print('Service facades:',len(report['buildings']),'contexts,',len(groups),'templates;',
          sum(s['changed_cells'] for s in report['buildings'].values()),'changed material cells')
    return report

if __name__ == '__main__': generate('--write' in sys.argv)
