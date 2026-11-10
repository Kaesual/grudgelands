#!/usr/bin/env python3
"""Check six installed castles and prepare actual-template web-renderer evidence."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/r70_castle'))
spec = importlib.util.spec_from_file_location('castle_study', ROOT / 'tools/r70_castle/build.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)
V, T, G = C.V, C.T, C.G
registry = json.loads(Path(V.NODES_JSON).read_text())
nodes = registry['nodes']
palettes = T.Palettes(G.load_palettes(V.find_lua(), set(nodes) | set(registry.get('aliases', {}))))
BASE = ROOT / 'mods/MAPGEN/grug_mapgen/building_templates/templates'
report = {}


def read(path, race):
    template = T.parse_template(str(path))
    cells, bad = T.resolved_cells(template, T.resolve(template, palettes, C.capital_binding(palettes, race)), palettes)
    assert not bad
    return template, cells


for race, name in C.OLD.items():
    path = BASE / (name + '.tpl')
    before, old = read(HERE / 'before' / path.name, race)
    after, new = read(path, race)
    assert [{k:v for k,v in p.items() if k!='line'} for p in after.points] == [{k:v for k,v in p.items() if k!='line'} for p in before.points]
    changed = {p for p in new if old[p] != new[p]}
    assert len(changed) == (492 if race == 'troll' else 502), (race,len(changed))
    # Kezamba binds ten structurally changed wall-role cells to the same basalt.
    same_role_edits = [(p,before.legend[before.cells[p]]['text'],after.legend[after.cells[p]]['text']) for p in new if before.cells[p] != after.cells[p] and old[p] == new[p]]
    assert len(same_role_edits) == (10 if race == 'troll' else 0), same_role_edits
    assert path.read_bytes() == (HERE / 'proposed' / path.name).read_bytes()
    # Throne: actual resolved height, open rear arm gaps and retained ornaments.
    assert all(new[x,5,z][0].startswith('wool:') for x in range(21,24) for z in (28,29))
    for x in (20,24):
        assert new[x,6,28][0] == new[x,6,29][0] == 'grug_materials:bronze_block'
        assert new[x,7,28][0] == new[x,7,29][0] == new[x,5,29][0] == 'air'
    assert all(new[x,9,30] == old[x,10,30] for x in range(20,25))
    assert all(new[x,10,30] == old[x,11,30] for x in range(20,25))
    # Original king/guards retain their empty collision volumes, including the
    # conservative union of initial socket feet and settled platform height.
    for x, radius, height in ((22,.48,2.72),(19,.42,2.38),(25,.42,2.38)):
        lo, hi = (x-radius,4.5,27-radius),(x+radius,5+height,27+radius)
        assert all(not all(lo[i] < p[i]+.5 and hi[i] > p[i]-.5 for i in range(3))
                   for p,v in new.items() if v[0] != 'air')
    for x,out in ((4,2),(40,42)):
        for z in (9,10,16,22,27):
            assert all(new[xx,y,z][0] != 'air' for xx in range(min(x,out),max(x,out)+1) for y in range(3,11))
        for lo,hi in ((11,15),(17,21),(23,26),(28,29)):
            assert all(new[x,y,z][0] == 'air' for z in range(lo,hi+1) for y in range(3,11))
        xx = x + (1 if x == 4 else -1)
        for old_z,new_z in zip((11,17,23,29),(10,16,22,27)):
            for y in (6,7):
                assert new[xx,y,new_z] == old[xx,y,old_z]
                assert new[xx,y,old_z][0] == 'air'
        for z in (14,20):
            assert new[x+(2 if x==4 else -2),3,z][0] == 'air'
    # Roof edge fill: full block preserves the old upper slab's top. Stair
    # courses and every non-ridge interior slab remain byte-equivalent cells.
    for z in (8,32):
        for x in range(5,40,2):
            y = 18 + min(x-4,40-x)//2
            assert old[x,y,z][1] == 20
            assert new[x,y,z] == old[22,28,z]
            assert new[x,y-1,z][0] != 'air'
    for z in range(8,33):
        assert new[22,27,z] == old[22,28,z]
        assert new[22,28,z] == (old[22,27,z][0],0)
    for p,v in old.items():
        if p[1] >= 18 and p[0] != 22 and 9 <= p[2] <= 31:
            assert new[p] == v
        if p[1] >= 18 and nodes.get(v[0],{}).get('groups',{}).get('stair'):
            assert new[p] == v
    report[race] = {'changed_template_cells':502,'changed_resolved_cells':len(changed),'gable_gaps_closed':36,'ridge_cells':50,
                    'points_preserved':len(after.points),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                    'king_guard_boxes_clear':True,'joined_piers_and_open_bays':True,'roof_stairs_and_interior_slabs_preserved':True}
    if race == 'human':
        human, original = new, old

tex, meshes, names, indices, packed = V.Textures(), {}, [], {}, {}
scenes = {
    'throne': (human, [26,9.5,18], [22,7.4,28.5], 48),
    'pillars': (human, [14,6.2,13], [3,5,21], 65),
    'roof-before': (original, [17,25,-10], [17,24,8], 42),
    'roof-final': (human, [17,25,-10], [17,24,8], 42),
    'roof-overview': (human, [56,40,-14], [22,17,19], 45),
}
for key,(cells,eye,target,fov) in scenes.items():
    source = cells
    if key == 'throne':
        source = {p:v for p,v in cells.items() if 14<=p[0]<=30 and 3<=p[1]<=13 and 23<=p[2]<=32}
    if key in ('roof-before','roof-final'):
        # A front gable slice removes the foreground towers from the camera.
        source = {p:v for p,v in cells.items() if 4<=p[0]<=40 and p[1]>=17 and 8<=p[2]<=10}
    spec = {'title':key,'description':'Installed castle templates / preserved original gable slice',
            'camera':{'eye':eye,'target':target,'fov':fov},'sky':'#a3b7bd','fog':[120,200],'tint':'#ffffff'}
    packed[key] = V.pack_cells({'spec':spec},[(*p,*v) for p,v in sorted(source.items()) if v[0]!='air'],indices,names)
types, missing = V.build_types(names,nodes,registry.get('aliases',{}),tex,meshes)
assert not missing['skipped'] and not missing['missing_mesh'] and not tex.missing
payload={'scenes':packed,'types':types,'textures':tex.images,'meshes':meshes,'body':[]}
page=V.inline_renderer((ROOT/'tools/character_creation_preview/scenes.html.in').read_text())
page=page.replace('__PORTRAIT__','function placePortrait(){}').replace("||'human'","||'throne'")
page=page.replace('t.colorSpace = THREE.SRGBColorSpace;','t.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;','renderer.outputEncoding = THREE.sRGBEncoding;')
for token,file in {'__THREE__':'tools/r54_armor/vendor/three.min.js','__ORBIT__':'tools/r69_camp_art/orbit.js','__LICENSE__':'tools/r69_camp_art/THREE-LICENSE.txt'}.items():
    page=page.replace(token,(ROOT/file).read_text().replace('</','<\\/'))
digest=hashlib.sha256(json.dumps({'payload':payload,'page':page,'builder':Path(__file__).read_text(),'sources':report},sort_keys=True).encode()).hexdigest()
for scene in packed.values():
    scene['digest']=digest
page=page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
(HERE/'scenes.html').write_text(page)
(HERE/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: all six installed castles; 502 template edits each; 216 gable gaps closed; all points preserved; king/guard boxes clear; no missing media.')
