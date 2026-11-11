#!/usr/bin/env python3
"""Bake the accepted browser cells into the existing template/palette format.

The accepted study is immutable; its source templates live at SOURCE. This is
an offline authoring tool, never a mapgen pass. --check verifies game output.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = '48d69ef0'
BASE = 'mods/MAPGEN/grug_mapgen/building_templates'
AUDIT = ROOT / 'tools/city_architecture_rollout/audit.json'
sys.path.insert(0, str(ROOT / 'tools/building_templates/viewer'))
sys.path.insert(0, str(ROOT / 'tools/building_templates/editor'))
import build_gallery as G
import templates as T
import tplfile as F

RACES = ['dwarf', 'human', 'elf', 'orc', 'troll', 'undead']
D = 'grug_decor:'
# Columns are RACES. These roles describe construction, not former material
# patches. Legacy roles retain their bindings for every excluded structure.
ROWS = {
 'facade_base': ['default:stone_block', 'default:stone_block', 'default:silver_sandstone_block', 'default:desert_stonebrick', D+'darkage_basalt_brick', 'default:mossycobble'],
 'facade_home_base': ['default:stone_block', 'default:brick', 'default:silver_sandstone_block', 'default:desert_stonebrick', 'default:junglewood', 'default:mossycobble'],
 'facade_frame': ['default:stone_block', 'grug_trees:gravewood_wood', D+'darkage_marble', D+'darkage_ors_block', 'default:junglewood', D+'darkage_basalt_block'],
 'facade_infill': [D+'darkage_stone_brick', D+'cottages_loam', 'grug_trees:silverwood_wood', D+'darkage_adobe', 'grug_nodes:clay_band_umber', D+'castle_dungeon_stone'],
 'facade_gable': ['default:wood', D+'cottages_loam', 'grug_trees:silverwood_wood', D+'darkage_adobe', 'grug_nodes:clay_band_umber', 'grug_trees:gravewood_wood'],
 'facade_band': ['default:stone_block', 'grug_trees:gravewood_wood', D+'darkage_serpentine', 'default:desert_stonebrick', 'default:junglewood', D+'darkage_basalt_block'],
 'facade_rustic_infill': [D+'darkage_stone_brick', D+'cottages_loam', 'grug_trees:silverwood_wood', D+'darkage_adobe', 'default:jungletree', D+'castle_dungeon_stone'],
 'facade_roof_ridge': [D+'darkage_slate', 'default:wood', D+'darkage_marble', 'default:desert_sandstone', D+'cottages_reet', 'default:obsidianbrick'],
}
for shape in ['stair', 'stair_inner', 'stair_outer', 'slab']:
    ROWS['facade_roof_'+shape] = [D+'darkage_slate_'+shape, 'stairs:'+shape+'_wood', D+'darkage_marble_'+shape,
                                'stairs:'+shape+'_desert_sandstone', D+'cottages_reet_'+shape, 'stairs:'+shape+'_obsidianbrick']
# Only marble's straight stair/slab exist; unused elf corner bindings use its
# existing roof kit, and are nevertheless real nodes and valid facedir shapes.
ROWS['facade_roof_stair_inner'][2] = 'stairs:stair_inner_silver_sandstone_block'
ROWS['facade_roof_stair_outer'][2] = 'stairs:stair_outer_silver_sandstone_block'

# Public human service roofs use the accepted red tile family.
for shape in ('ridge', 'stair', 'stair_inner', 'stair_outer', 'slab'):
    values = list(ROWS['facade_roof_'+shape])
    values[1] = 'default:brick' if shape == 'ridge' else 'stairs:'+shape+'_brick'
    ROWS['facade_service_roof_'+shape] = values

from special_materials import ROWS as SPECIAL_ROWS
ROWS.update(SPECIAL_ROWS)


def source(path):
    return subprocess.check_output(['git', 'show', SOURCE+':'+str(path)], cwd=ROOT, text=True)


def map_node(name):
    return name.replace('study:reed_', D+'cottages_reet_')


def palette_block():
    lines = ['-- Round 75.5: structural facade roles, baked into the reviewed templates.',
             '-- Legacy roles stay intact for camps, royal halls and special buildings.']
    for role in ROWS:
        lines.append('M.required[#M.required + 1] = "'+role+'"')
    for i, race in enumerate(RACES):
        lines.append('')
        for role, values in ROWS.items():
            lines.append('M.races.'+race+'.'+role+' = "'+values[i]+'"')
    return '\n'.join(lines)+'\n\n'


def original_palettes(names):
    # Freeze the predicates too: a new param2 kind must not silently alter the
    # expected old result for an excluded building.
    with tempfile.TemporaryDirectory(prefix='grug-r75-5-source-') as directory:
        wp = Path(directory)/'mods/MAPGEN/grug_mapgen/wp13'
        wp.mkdir(parents=True)
        for name in ('palette.lua','parts.lua','troll_palette.lua'):
            (wp/name).write_text(source('mods/MAPGEN/grug_mapgen/wp13/'+name))
        names_file = Path(directory)/'names.txt'
        names_file.write_text('\n'.join(sorted(names))+'\n')
        output = subprocess.check_output(['luajit',str(ROOT/'tools/building_templates/viewer/palettes.lua'),
                                          'palettes',str(names_file)],cwd=directory,text=True)
        return T.Palettes(json.loads(output))


def contexts(audit, pal, old_pal):
    _, layouts = G.read_sources(str(ROOT / BASE))
    approved = {}
    for key, spec in audit['buildings'].items():
        for p in spec['placements']:
            approved[(p['layout'], p['line'])] = (key, spec)
    result = {}
    old = {}
    for layout in layouts:
        rel = str(Path(layout.path).relative_to(ROOT))
        assert hashlib.sha256(Path(layout.path).read_bytes()).hexdigest() == audit['layouts'][rel]
        for rec in layout.places + layout.uses:
            name = rec['template']
            path = BASE+'/templates/'+name+'.tpl'
            if name not in old:
                text = source(path)
                old[name] = T.parse_template(path, text=text)
            tpl = old[name]
            binding = G.placement_binding(pal, layout, rec)
            old_binding = G.placement_binding(old_pal, layout, rec)
            before, errors = T.resolved_cells(tpl, T.resolve(tpl, old_pal, old_binding), old_pal)
            assert not errors, errors
            after = dict(before)
            found = approved.get((rel, rec['line']))
            if found:
                key, spec = found
                assert hashlib.sha256(source(path).encode()).hexdigest() == spec['sha256']
                for c in spec['changes']:
                    p = tuple(c['position'])
                    assert before[p] == tuple(c['before']), (key, p, before[p], c['before'])
                    after[p] = (map_node(c['after'][0]), c['after'][1])
            result.setdefault(name, []).append(dict(binding=binding, before=before, after=after,
                 scene=found[0] if found else None, layout=rel, line=rec['line'], race=layout.race))
    return old, result


def bake(tpl, uses, pal, source_text=None):
    m = F.load(source_text if source_text is not None else source(BASE+'/templates/'+tpl.name+'.tpl'), tpl.path)
    # Two-character keys avoid arbitrary capacity limits in shared templates.
    # Keep one-character files where the completed legend still fits.
    entries = {key: text for key, text in m.legend}
    order = [key for key, _ in m.legend]
    reverse = {text: key for key, text in m.legend}
    next_id = 0
    def add(text):
        nonlocal next_id
        if text not in reverse:
            key = '@new'+str(next_id); next_id += 1
            entries[key] = text; order.append(key); reverse[text] = key
        return reverse[text]
    cells = dict(tpl.cells)
    for p in sorted(cells):
        if not any(u['before'].get(p) != u['after'].get(p) for u in uses):
            continue
        original = tpl.cells[p]
        desired = {}
        for u in uses:
            desired.setdefault(u['race'], set()).add(u['after'][p])
        # Palette-dependent uses may retain an old binding. A new facade
        # assignment must be identical for all uses of the same race.
        assert all(len(v) == 1 for v in desired.values()), (tpl.name, p, desired)
        targets = {race: next(iter(v)) for race, v in desired.items()}
        candidates = [role for role, values in ROWS.items()
                      if all(values[RACES.index(race)] == target[0] for race, target in targets.items())]
        old_role = tpl.legend[original].get('name', '')
        if old_role == 'foundation':
            candidates.sort(key=lambda r: (r not in ('facade_base', 'facade_home_base'), r))
        def entry(role, target):
            kind = pal.kind(target[0])
            assert kind in ('none', 'facedir'), (tpl.name, p, target, kind)
            channel = tpl.legend[original].get('channel')
            return ('role '+role+(' channel='+channel if channel else '')
                    +(' o=facedir:'+str(target[1]) if kind == 'facedir' else '')
                    +(' late' if tpl.legend[original].get('late') else ''))
        texts = {entry(candidates[0], t) for t in targets.values()} if candidates else set()
        if len(texts) == 1 and set(targets) == set(tpl.races):
            cells[p] = add(next(iter(texts)))
        else:
            choices = dict(tpl.legend[original].get('choices', {}))
            if not choices:
                choices['*'] = original
            for race, target in sorted(targets.items()):
                if all(u['before'][p] == target for u in uses if u['race'] == race):
                    continue
                role = next(r for r, values in ROWS.items() if values[RACES.index(race)] == target[0])
                choices[race] = add(entry(role, target))
            cells[p] = add('race '+' '.join(r+'='+v for r, v in sorted(choices.items())))
    # Prune reachable entries before assigning real keys; no nested switches.
    needed = {k for k in cells.values() if k not in (T.FORCE_AIR, T.UNCHANGED)}
    todo = list(needed)
    while todo:
        text = entries[todo.pop()]
        refs = [v.split('=',1)[1] for v in text.split()[1:] if '=' in v and
                (text.startswith('race ') or v.startswith('else='))]
        for key in refs:
            if key in entries and key not in needed:
                needed.add(key); todo.append(key)
    order = [k for k in order if k in needed]
    m.cell = max(tpl.cell, 1 if len(order) <= len(F.ALPHABET) else 2)
    keys = list(F.ALPHABET) if m.cell == 1 else [a+b for a in F.ALPHABET for b in F.ALPHABET]
    mapping = {k: ('A'+k if m.cell > tpl.cell else k) for k in order if not k.startswith('@new')}
    available = iter([k for k in keys if k not in set(mapping.values())])
    for k in order:
        if k not in mapping: mapping[k] = next(available)
    def rewritten(text):
        words = text.split()
        for i, word in enumerate(words):
            if '=' in word and (words[0] == 'race' or word.startswith('else=')):
                k, v = word.split('=',1)
                if v in mapping: words[i] = k+'='+mapping[v]
        return ' '.join(words)
    m.legend = [[mapping[k], rewritten(entries[k])] for k in order]
    x0,y0,z0 = m.origin; sx,sy,sz = m.size
    m.layers = [[''.join('.'*m.cell if cells[x,y,z] == T.FORCE_AIR else ' '*m.cell
                        if cells[x,y,z] == T.UNCHANGED else mapping[cells[x,y,z]]
                        for x in range(x0,x0+sx)) for z in range(z0,z0+sz)] for y in range(y0,y0+sy)]
    return F.dump(m)


def lua(value):
    if isinstance(value, str): return json.dumps(value)
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, list): return '{'+','.join(lua(v) for v in value)+'}'
    if isinstance(value, dict): return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in sorted(value.items()))+'}'
    return str(value)


def live_original(jobs):
    """Resolve frozen source templates with real planting and late-cell order."""
    with tempfile.TemporaryDirectory(prefix='grug-frozen-scenes-') as directory:
        manifest = []
        for job in jobs:
            path = Path(directory)/(job['name']+'.tpl')
            if not path.exists(): path.write_text(source(BASE+'/templates/'+job['name']+'.tpl'))
            manifest.append(dict(job,source_file=str(path)))
        path = Path(directory)/'jobs.lua'; path.write_text('return '+lua(manifest)+'\n')
        output = subprocess.check_output(['luajit',str(ROOT/'tools/city_architecture_specials/export.lua'),
            str(ROOT),str(path)],cwd=ROOT,text=True)
    result = [{} for _ in jobs]
    for line in output.splitlines():
        i,x,y,z,n,p2 = line.split('\t')
        result[int(i)-1][int(x),int(y),int(z)] = n,int(p2)
    return result


def runtime(uses):
    with tempfile.TemporaryDirectory(prefix='grug-r75-5-proof-') as directory:
        jobs = []
        planted_jobs = []
        planted_uses = []
        for name, group in sorted(uses.items()):
            tpl = T.parse_template(ROOT/BASE/'templates'/(name+'.tpl'))
            if not (tpl.meta.get('undergrowth') or any(p['group']=='trees' for p in tpl.points)): continue
            for u in group:
                if u['scene']:
                    planted_jobs.append(dict(name=name,race=u['race'],id='proof',binding=u['binding']))
                    planted_uses.append(u)
        for u, actual in zip(planted_uses, live_original(planted_jobs) if planted_jobs else []):
            for p,v in u['after'].items():
                if v != u['before'].get(p): actual[p] = v
            u['live_after'] = actual
        for name, group in sorted(uses.items()):
            # Planted scenes compare frozen live planting plus only approved
            # material deltas; authored air must not erase generated vegetation.
            for u in group:
                if not u['scene']: continue
                path = Path(directory)/(str(len(jobs))+'.cells')
                path.write_text(''.join('%d %d %d %s %d\n' % (*p,*v) for p,v in sorted(u.get('live_after',u['after']).items())))
                jobs.append(dict(name=name,race=u['race'],binding=u['binding'],cells=str(path),exact=True))
        manifest = Path(directory)/'jobs.lua'
        manifest.write_text('return '+lua(jobs)+'\n')
        subprocess.run(['luajit',str(ROOT/'tools/r75_5_architecture/runtime.lua'),str(ROOT),str(manifest)],check=True,cwd=ROOT)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--runtime', action='store_true')
    args = parser.parse_args()
    if args.write:
        p = 'mods/MAPGEN/grug_mapgen/wp13/palette.lua'
        text = source(p)
        (ROOT/p).write_text(text.replace('local function contains(list, value)', palette_block()+'local function contains(list, value)'))
    nodes = json.loads((ROOT/'tools/building_templates/nodes.json').read_text())['nodes']
    for shape in ('stair', 'stair_inner', 'stair_outer', 'slab'):
        node = nodes[D+'cottages_reet_'+shape]
        reference = nodes['stairs:'+shape+'_junglewood']
        for field in ('drawtype','node_box','collision_box','selection_box','walkable','buildable_to','paramtype2'):
            assert node.get(field) == reference.get(field), (shape, field)
        assert node['tiles'] == [dict(name=nodes[D+'cottages_reet']['tiles'][0],backface_culling=True)]
    names = set(nodes) | {n for values in ROWS.values() for n in values}
    pal = T.Palettes(G.load_palettes('luajit', names))
    audit = json.loads(AUDIT.read_text())
    # The original 145-scene study stays immutable. The user subsequently
    # authorized this one religious building as an explicit extension.
    shrine_path = ROOT/'tools/r75_5_architecture/shrine.json'
    shrine = json.loads(shrine_path.read_text())
    assert shrine['source'] == SOURCE
    assert set(shrine['buildings']) == {'silverleaf__silverleaf_moon_shrine'}
    assert not (set(audit['buildings']) & set(shrine['buildings']))
    audit['buildings'].update(shrine['buildings'])
    services_path = ROOT/'tools/r75_5_architecture/services.json'
    services = json.loads(services_path.read_text())
    assert services['source'] == SOURCE
    assert len(services['buildings']) == 50
    assert not (set(audit['buildings']) & set(services['buildings']))
    audit['buildings'].update(services['buildings'])
    specials_path = ROOT/'tools/r75_5_architecture/specials.json'
    specials = json.loads(specials_path.read_text())
    assert specials['source'] == SOURCE and len(specials['buildings']) == 87
    assert not (set(audit['buildings']) & set(specials['buildings']))
    audit['buildings'].update(specials['buildings'])
    old, uses = contexts(audit, pal, original_palettes(names))
    changed = 0
    for name, group in sorted(uses.items()):
        if not any(u['scene'] for u in group): continue
        path = ROOT/BASE/'templates'/ (name+'.tpl')
        expected = bake(old[name], group, pal)
        if args.write: path.write_text(expected)
        assert path.read_text() == expected, (name, 'generated template differs')
        changed += 1
    checked = []
    for name, group in sorted(uses.items()):
        tpl = T.parse_template(ROOT/BASE/'templates'/(name+'.tpl'))
        original = old[name]
        assert (tpl.origin, tpl.size, tpl.pivot, tpl.races, tpl.meta) == (
            original.origin, original.size, original.pivot, original.races, original.meta), name
        assert [{k:v for k,v in p.items() if k != 'line'} for p in tpl.points] == [
            {k:v for k,v in p.items() if k != 'line'} for p in original.points], name
        for p,k in original.cells.items():
            assert bool(original.legend.get(k,{}).get('late')) == bool(tpl.legend.get(tpl.cells[p],{}).get('late')), (name,p,'late order')
        for u in group:
            actual, errors = T.resolved_cells(tpl, T.resolve(tpl, pal, u['binding']), pal)
            assert not errors, (name, errors)
            actual = {p:(n,pal.canonical_param2(n,p2)) for p,(n,p2) in actual.items()}
            u['after'] = {p:(n,pal.canonical_param2(n,p2)) for p,(n,p2) in u['after'].items()}
            diff = [(p,u['after'].get(p),actual.get(p)) for p in set(actual)|set(u['after']) if actual.get(p) != u['after'].get(p)]
            assert not diff, (name,u['race'],diff[:8])
            checked.append(dict(template=name, layout=u['layout'], line=u['line'], scene=u['scene'],
                                cells=len(actual), sha256=hashlib.sha256(repr(sorted(actual.items())).encode()).hexdigest()))
    result = dict(source=SOURCE, classification='map reset', templates=changed, placements=checked,
                  study_sha256=hashlib.sha256(AUDIT.read_bytes()).hexdigest(),
                  shrine_sha256=hashlib.sha256(shrine_path.read_bytes()).hexdigest(),
                  services_sha256=hashlib.sha256(services_path.read_bytes()).hexdigest(),
                  specials_sha256=hashlib.sha256(specials_path.read_bytes()).hexdigest())
    (ROOT/'tools/r75_5_architecture/proof.json').write_text(json.dumps(result,indent=2)+'\n')
    if args.runtime:
        runtime(uses)
    print('Exact approved cells and protected metadata:', changed, 'templates,', len(checked), 'placement contexts.')

if __name__ == '__main__': main()
