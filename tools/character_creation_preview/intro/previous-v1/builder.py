#!/usr/bin/env python3
"""Build the editable opening study with shipped castles, nodes and standards.

Offline proposal only. Never modifies the six accepted racial compositions,
native assets or world generation. The two standards reuse the camp mesh and
texture at castle scale (three times its camp size).
"""
import hashlib
import json
import random
import struct
import tempfile
from pathlib import Path
import scenery as S

HERE, ROOT, V, G, T = S.HERE, S.ROOT, S.V, S.G, S.T
OUT = HERE / 'intro'
spec = json.loads((OUT / 'scene.json').read_text())
reg = json.loads((ROOT / 'tools/building_templates/nodes.json').read_text())
palettes = T.Palettes(G.load_palettes('luajit', set(reg['nodes']) | set(reg.get('aliases', {}))))
cells, sources = {}, {}
rng = random.Random(spec['seed'])
def put(x, y, z, name, p2=0):
    assert name in reg['nodes'], name
    cells[x, y, z] = (name, p2)
def fill(x0, y0, z0, x1, y1, z1, name, p2=0):
    for x in range(x0, x1+1):
        for y in range(y0, y1+1):
            for z in range(z0, z1+1): put(x,y,z,name,p2)

# A shared approach, not two unrelated images. Restrained deterministic rubble.
for x in range(-72,73):
    for z in range(-65,92):
        path = abs(x) < 9 + max(z,0)*.10
        node = ('default:gravel' if rng.random()<.17 else 'grug_decor:castle_pavement_brick') if path else 'default:dirt_with_dry_grass'
        if rng.random()<.045: node='default:gravel'
        put(x,0,z,node)
        if z>65: fill(x,1,z,x,(z-63)//7,z,'default:stone')

for place in spec['buildings']:
    path=ROOT/'mods/MAPGEN/grug_mapgen/building_templates/templates'/(place['template']+'.tpl')
    lp=ROOT/'mods/MAPGEN/grug_mapgen/building_templates/layouts'/(place['town']+'.roster')
    template=T.parse_template(str(path)); layout=T.parse_layout(str(lp))
    placement=next(p for p in layout.uses if p['template']==place['template'])
    binding=G.placement_binding(palettes,layout,placement)
    stamp,bad=T.resolved_cells(template,T.resolve(template,palettes,binding),palettes)
    assert not bad,bad
    xs,ys,zs=zip(*stamp); cx,cz=(min(xs)+max(xs))//2,(min(zs)+max(zs))//2
    px,py,pz=place['at']
    for (x,y,z),(name,p2) in stamp.items():
        if name!='air' and reg['nodes'].get(name,{}).get('drawtype')!='airlike': put(px+x-cx,py+y,pz+z-cz,name,p2)
    for p in (path,lp): sources[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()

# Foreworks carry the prominent standards; their surfaces use game materials.
for side in (-1,1):
    stone='default:stonebrick' if side<0 else 'default:desert_stonebrick'
    edge='default:stone_block' if side<0 else 'default:acacia_tree'
    for cx,cz,top in ((side*17,7,15),(side*41,11,17)):
        fill(cx-3,1,cz-3,cx+3,top,cz+3,stone)
        for y in (3,top-3): fill(cx-3,y,cz-3,cx+3,y,cz+3,edge)
        for x in range(cx-3,cx+4,2):
            put(x,top+1,cz-3,edge);put(x,top+1,cz+3,edge)
        for z in range(cz-1,cz+3,2):
            put(cx-3,top+1,z,edge);put(cx+3,top+1,z,edge)
    a,b=sorted((side*20,side*38))
    fill(a,1,9,b,7,11,stone)
    for x in range(a,b+1,2): fill(x,8,9,x,9,11,edge)
    # Open central approach; low obstacles and stores give it a military scale.
    for z in (-9,-1):
        for x in range(a+4,b-2,3):
            fill(x,1,z,x,2,z,'default:tree' if side<0 else 'default:acacia_tree')
        fill(a+4,1,z,b-3,1,z,'default:tree' if side<0 else 'default:acacia_tree',12)
    for x,z in ((side*12,-6),(side*26,1)):
        put(x,1,z,'grug_decor:cottages_barrel')
        put(x+side*2,1,z+1,'default:coalblock')
    # Lamp beacons sit on the inner piers, using the actual luminous game node.
    fill(side*11,1,1,side*11,3,1,stone)
    put(side*11,4,1,'grug_materials:emberglass_lamp')
    put(side*11,1,-5,'grug_nodes:camp_fire')

for banner in spec['banners']:
    put(*banner['at'],'grug_mapgen:faction_banner_'+banner['faction'])
for _ in range(65):
    x,z=rng.randint(-55,55),rng.randint(-22,14)
    if abs(x)<9: continue
    put(x,1,z,rng.choice(['default:gravel','default:stone','default:dry_grass_2']))

textures, meshes, names, indices=V.Textures(),{},[],{}
scene=V.pack_cells({'spec':spec},[(*pos,*node) for pos,node in sorted(cells.items())],indices,names)
types,report=V.build_types(names,reg['nodes'],reg.get('aliases',{}),textures,meshes)
assert not report['skipped'] and not report['missing_mesh'] and not textures.missing,(report,textures.missing)
# Scale the existing banner mesh in this offline payload only. No new game asset.
scales={b['scale'] for b in spec['banners']};assert len(scales)==1
scale=scales.pop()
# Same animated-node export adapter as r69_camp_art/build.py: the static
# reader merges brush -1 chunks and leaves B3D's ten units per node intact.
name='grug_mapgen_faction_banner.b3d'
data=bytearray(Path(V.find_model(name)).read_bytes()); found=[]
def chunks(start,end):
    while start<end:
        tag=bytes(data[start:start+4]); length=struct.unpack_from('<i',data,start+4)[0]
        body,finish=start+8,start+8+length
        assert finish<=end
        if tag==b'BB3D': chunks(body+4,finish)
        elif tag==b'NODE': chunks(data.index(0,body)+41,finish)
        elif tag==b'MESH': chunks(body+4,finish)
        elif tag==b'TRIS':
            struct.pack_into('<i',data,body,len(found));found.append(body)
        start=finish
chunks(0,len(data));assert len(found)==3
with tempfile.TemporaryDirectory(prefix='grug-intro-mesh-') as temp:
    path=Path(temp)/name;path.write_bytes(data);buffers=V.parse_b3d(path)
meshes[name]=[[round(v*scale/10 if i%5<3 else v,5) for i,v in enumerate(buf)] for buf in buffers]
payload={'scenes':{'intro':scene},'types':types,'textures':textures.images,'meshes':meshes,'body':[]}
page=V.inline_renderer((HERE/'scenes.html.in').read_text())
page=page.replace('__PORTRAIT__',(HERE/'portrait.js').read_text())
page=page.replace("let selected='human'","let selected='intro'").replace("||'human'","||'intro'")
page=page.replace('t.colorSpace = THREE.SRGBColorSpace;','t.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;','renderer.outputEncoding = THREE.sRGBEncoding;')
for token,p in {'__THREE__':ROOT/'tools/r54_armor/vendor/three.min.js','__ORBIT__':ROOT/'tools/r69_camp_art/orbit.js','__LICENSE__':ROOT/'tools/r69_camp_art/THREE-LICENSE.txt'}.items():
    page=page.replace(token,p.read_text().replace('</','<\\/'))
scene['digest']=S.digest({'payload':payload,'page':page,'builder':Path(__file__).read_text(),'capture':(HERE/'render-scenes.mjs').read_text()})
page=page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
(OUT/'scenes.html').write_text(page)
(OUT/'scene-build.json').write_text(json.dumps({'intro':{'render_input':scene['digest'],'sources':sources,'cells':len(cells),'recipe':S.digest(spec)}},indent=2)+'\n')
print('Opening scene built:',len(cells),'nodes;',len(types),'types; no missing assets')
