#!/usr/bin/env python3
"""Build the editable opening study with distinct fortifications, shipped nodes and standards.

Offline proposal only. Never modifies the six accepted racial compositions,
native assets or world generation. The two standards reuse the camp mesh and
texture at castle scale (three times its camp size).
"""
import json
import math
import hashlib
import random
import struct
import tempfile
from pathlib import Path
import scenery as S

HERE, ROOT, V = S.HERE, S.ROOT, S.V
OUT = HERE / 'intro'
spec = json.loads((OUT / 'scene.json').read_text())
reg = json.loads((ROOT / 'tools/building_templates/nodes.json').read_text())

cells, sources = {}, {}
rng = random.Random(spec['seed'])
def put(x, y, z, name, p2=0):
    assert name in reg['nodes'], name
    cells[x, y, z] = (name, p2)
def fill(x0, y0, z0, x1, y1, z1, name, p2=0):
    for x in range(x0, x1+1):
        for y in range(y0, y1+1):
            for z in range(z0, z1+1): put(x,y,z,name,p2)

def background_height(x,z):
    # Broad low undulations replace the straight stone terrace beyond the front.
    ramp=min(1,max(0,(z-60)/15))
    return max(0,math.floor(ramp*(2.2+1.2*math.sin(x*.085+z*.045)+.9*math.cos(z*.11-x*.025))))

# Terrain: a churned siege front. The old paved route survives only as
# disconnected fragments; the trench exposes lower, supported layers.
for x in range(-75,76):
    for z in range(-65,137):
        scar = abs(x - (z//8)%5 + 2) < 5 and -17 < z < 39
        pit = ((x+3)/9)**2 + ((z+10)/6)**2 < 1
        level = -1 if scar or pit else 0
        put(x,-2,z,'default:stone')
        put(x,-1,z,'default:dirt')
        t=((x//4*73856093 ^ z//4*19349663 ^ spec['seed'])%100)/100
        node='default:dirt' if t<.83 else ('default:gravel' if t<.96 else 'grug_decor:darkage_basalt_rubble')
        if abs(x)<4 and 8<z<55 and (x+z)%7<3 and not scar:
            node='grug_decor:castle_pavement_brick'
        put(x,level,z,node)
        if z>60:
            h=background_height(x,z)
            for y in range(0,h): put(x,y,z,'default:dirt')
            put(x,h,z,'default:dirt_with_grass')

# Exact shipped tree generator; saved seeds make the sparse distant groups
# reproducible. These selected variants have no surface roots, so the ground
# may undulate underneath their crowns without floating root branches.
trees=S.load_trees([spec])
for tree in spec['trees']:
    x,_,z=tree['at'];y=background_height(x,z)+1
    assert z>60 and cells[x,y-1,z][0]=='default:dirt_with_grass'
    for dx,dy,dz,name,p2,root in trees[f"{tree['species']}:{tree['seed']}"]:
        assert not root, 'Choose a root-free seed for the rolling background'
        at=x+dx,y+dy,z+dz
        assert at[2]>60, 'Background trees must not alter the approved front'
        old=cells.get(at)
        if old:
            leafy=lambda node: reg['nodes'][node].get('drawtype') in ('allfaces_optional','plantlike')
            assert leafy(name) or leafy(old[0]), ('tree collision',tree,at,old,name)
            if leafy(name): continue
        put(*at,name,p2)
for source in (HERE/'export-trees.lua',ROOT/'mods/MAPGEN/grug_mapgen/wp40/treegen.lua',
               ROOT/'mods/MAPGEN/grug_mapgen/wp40/tree_templates.lua'):
    sources[str(source.relative_to(ROOT))]=hashlib.sha256(source.read_bytes()).hexdigest()

def clear(x0,y0,z0,x1,y1,z1):
    for x in range(x0,x1+1):
        for y in range(y0,y1+1):
            for z in range(z0,z1+1): cells.pop((x,y,z),None)

def parapet(x0,z0,x1,z1,y,stone):
    fill(x0,y,z0,x1,y,z0,stone);fill(x0,y,z1,x1,y,z1,stone)
    fill(x0,y,z0,x0,y,z1,stone);fill(x1,y,z0,x1,y,z1,stone)
    for x in range(x0,x1+1,3):
        fill(x,y+1,z0,x+1,y+2,z0,stone);fill(x,y+1,z1,x+1,y+2,z1,stone)
    for z in range(z0+2,z1,3):
        fill(x0,y+1,z,x0,y+2,z+1,stone);fill(x1,y+1,z,x1,y+2,z+1,stone)

# The Accord: low defensive curtain, deep buttresses, two unequal bastions
# and an offset flat-roof keep. No civic gable or mirror of the opposite side.
a=spec['fortifications']['accord']
stone='default:stonebrick'; trim='default:stone_block'
x0,z0,x1,z1,top=a['wall']
fill(x0,0,z0,x1,top,z1,stone);parapet(x0,z0,x1,z1,top+1,trim)
for x in range(x0+2,x1,6):
    fill(x,1,z0-2,x+1,top-2,z0,trim)
x0,z0,x1,z1,top=a['keep']
fill(x0,0,z0,x1,top,z1,stone);parapet(x0,z0,x1,z1,top+1,trim)
for x,z,top in a['towers']:
    fill(x-6,0,z-6,x+6,top,z+6,stone)
    for y in (4,top-6,top): fill(x-6,y,z-6,x+6,y,z+6,trim)
    for xx in (x-6,x+5): fill(xx,1,z-8,xx+1,top-3,z-6,trim)
    parapet(x-6,z-6,x+6,z+6,top+1,trim)
    for xx in (x-3,x+3):
        fill(xx,top-11,z-6,xx,top-8,z-6,'default:coalblock')
    # Different service aperture than the massive keep's covered fighting deck.
    fill(x-1,2,z-6,x+1,5,z-6,'default:coalblock')
# Damage removes part of the forward left curtain, spilling debris outward.
clear(-34,9,17,-30,16,20)
for xx,zz in [(-34,14),(-32,13),(-29,15),(-31,11)]:
    put(xx,1,zz,trim)

# The Throng: a staggered timber fighting platform on a rough basalt plinth,
# open braces, iron collars and irregular upright palisades. Unequal heights,
# footprints and construction give the faction a completely separate skyline.
t=spec['fortifications']['throng']
wood='default:acacia_tree'; plank='default:acacia_wood'
rock='grug_decor:darkage_basalt_brick'; iron='grug_guild:ornamented_iron'
x0,z0,x1,z1,top=t['palisade']
for x in range(x0,x1+1):
    h=top+(x*7%5)
    fill(x,0,z0,x,h,z0+2,wood)
    put(x,h+1,z0+1,wood)
for y in (3,8): fill(x0,y,z0-1,x1,y,z0-1,plank)
for x,z,top in t['towers']:
    fill(x-6,0,z-6,x+6,7,z+6,rock)
    for dx,dz in [(-6,-6),(6,-6),(-6,6),(6,6)]:
        fill(x+dx,8,z+dz,x+dx+1,top+2,z+dz+1,wood)
        for y in (10,20,top-1): fill(x+dx,y,z+dz,x+dx+1,y,z+dz+1,iron)
    for y in (15,top-5):
        fill(x-8,y,z-8,x+8,y+1,z+8,plank)
        for xx in range(x-8,x+9,3):
            fill(xx,y+2,z-8,xx,y+4,z-8,wood)
        fill(x-8,y+2,z-8,x+8,y+2,z-8,wood,12)
        fill(x-8,y+2,z+8,x+8,y+2,z+8,wood,12)
    # Diagonal braces are genuinely stepped timber, not a painted overlay.
    for i in range(12):
        fill(x-5+i,8+i,z-6,x-4+i,9+i,z-6,wood)
        fill(x+5-i,8+i,z-6,x+6-i,9+i,z-6,wood)
    fill(x-4,top-4,z-3,x+4,top-1,z+4,plank)
    for xx in (x-5,x,x+5):
        fill(xx,top,z-5,xx,top+4+(xx%3),z-5,wood)
# Banner hangs from a solid timber panel on the front fighting platform.
fill(24,14,17,30,21,17,plank)

# A displaced, broken trench revetment leads diagonally into the distance.
for z in range(-20,30,3):
    x=5+(z//9)%3
    fill(x,0,z,x,1,z+1,'default:tree')
    if z%2==0: put(x-1,0,z,'default:tree',12)
# Chevaux-de-frise, broken siege frames and coal-dark scorch patches.
for cx,cz,length in [(-13,-6,12),(12,4,9),(-7,19,10),(22,-14,8)]:
    fill(cx-length//2,1,cz,cx+length//2,1,cz,'default:tree',12)
    for xx in range(cx-length//2,cx+length//2+1,4):
        for i in range(4):
            put(xx,i,cz-2+i,'default:tree')
            put(xx,i,cz+2-i,'default:tree')
for x,_,z in spec['fires']:
    for dx in range(-2,3):
        for dz in range(-2,3):
            if dx*dx+dz*dz<7: put(x+dx,0,z+dz,'default:coalblock')
    put(x,1,z,'grug_nodes:camp_fire')
# Ammunition, barrels and shattered stone around the defended approaches.
for x,z in [(-23,2),(-25,7),(31,4),(33,8)]:
    put(x,1,z,'grug_decor:cottages_barrel')
for _ in range(130):
    x,z=rng.randint(-48,48),rng.randint(-23,10)
    if abs(x)<5 and z<0: continue
    if (x,0,z) in cells and (x,1,z) not in cells:
        put(x,1,z,rng.choice(['default:stone','grug_decor:darkage_basalt_rubble','default:gravel']))
for banner in spec['banners']:
    put(*banner['at'],'grug_mapgen:faction_banner_'+banner['faction'])
# Every used node and its media are represented in the payload digest below.
sources['authored_fortifications']='intro/scene.json + intro.py (no castle template stamping)'
for source in [Path(__file__), HERE/'intro-atmosphere.js', HERE/'render-scenes.mjs',
               HERE/'scenes.html.in', HERE/'portrait.js', HERE/'scenery.py',
               ROOT/'tools/building_templates/viewer/renderer.js',
               ROOT/'tools/r54_armor/vendor/three.min.js', ROOT/'tools/r69_camp_art/orbit.js']:
    sources[str(source.relative_to(ROOT))]=hashlib.sha256(source.read_bytes()).hexdigest()

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
effects={'smoke':textures.index('default_item_smoke.png^[colorize:#30343a:220'),'fire':textures.index('mobs_fire_particle.png')}
assert not textures.missing,textures.missing
payload={'effects':effects,'scenes':{'intro':scene},'types':types,'textures':textures.images,'meshes':meshes,'body':[]}
page=V.inline_renderer((HERE/'scenes.html.in').read_text())
page=page.replace('__PORTRAIT__',(HERE/'portrait.js').read_text())
page=page.replace('const reference=new THREE.Group();', (HERE/'intro-atmosphere.js').read_text()+'\nconst reference=new THREE.Group();')
page=page.replace('pixelTextures();camera();','introAtmosphere(spec);pixelTextures();camera();')
page=page.replace("let selected='human'","let selected='intro'").replace("||'human'","||'intro'")
page=page.replace('t.colorSpace = THREE.SRGBColorSpace;','t.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;','renderer.outputEncoding = THREE.sRGBEncoding;')
for token,p in {'__THREE__':ROOT/'tools/r54_armor/vendor/three.min.js','__ORBIT__':ROOT/'tools/r69_camp_art/orbit.js','__LICENSE__':ROOT/'tools/r69_camp_art/THREE-LICENSE.txt'}.items():
    page=page.replace(token,p.read_text().replace('</','<\\/'))
scene['digest']=S.digest({'payload':payload,'page':page,'builder':Path(__file__).read_text(),'capture':(HERE/'render-scenes.mjs').read_text()})
page=page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
(OUT/'scenes.html').write_text(page)
(OUT/'scene-build.json').write_text(json.dumps({'intro':{'render_input':scene['digest'],'sources':sources,'cells':len(cells),'recipe':S.digest(spec)}},indent=2)+'\n')
print('Opening scene built:',len(cells),'nodes;',len(types),'types; no missing assets')
