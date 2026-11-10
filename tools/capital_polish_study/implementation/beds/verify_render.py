#!/usr/bin/env python3
"""Verify full bed pairs, rear wall and access; prepare saved actual-template views."""
from pathlib import Path
from collections import deque
import base64,hashlib,json,re,sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/building_templates/viewer'))
import templates as T,build_viewer as V,build_gallery as G
reg=json.loads((ROOT/'tools/building_templates/nodes.json').read_text())
pal=T.Palettes(G.load_palettes('luajit',set(reg['nodes'])|set(reg['aliases'])))
layout=T.parse_layout(str(ROOT/'mods/MAPGEN/grug_mapgen/building_templates/layouts/dawnmere.layout'))
rec=next(r for r in layout.places if r['template']=='dawnmere_harvest_inn')
binding=G.placement_binding(pal,layout,rec)
name='dawnmere_harvest_inn.tpl'
old=T.parse_template(str(HERE/'before'/name));new=T.parse_template(str(HERE/'after'/name))
def meaning(t):return {p:t.legend[k]['text'] if k in t.legend else k for p,k in t.cells.items()}
a,b=meaning(old),meaning(new)
expected={(x,1,z) for x in (1,3) for z in (12,13,14)}
assert {p for p in a if a[p]!=b[p]}==expected
assert [{k:v for k,v in p.items() if k!='line'} for p in old.points]==[{k:v for k,v in p.items() if k!='line'} for p in new.points]
assert (old.origin,old.size,old.pivot)==(new.origin,new.size,new.pivot)
# Check all current templates for matching directed halves and boundary heads.
counts={'templates_with_beds':0,'complete_beds':0};issues=[];boundary=[]
for path in sorted((ROOT/'mods/MAPGEN/grug_mapgen/building_templates/templates').glob('*.tpl')):
 t=T.parse_template(str(path));beds={p:t.legend[k]['text'] for p,k in t.cells.items() if k in t.legend and re.match(r'(role bed(?:_fancy)? |node beds:)',t.legend[k]['text'])}
 if beds:counts['templates_with_beds']+=1
 for (x,y,z),entry in beds.items():
  face=int(re.search(r'o=facedir:(\d+)',entry)[1]) if 'o=facedir:' in entry else 0
  dx,dz=((0,1),(1,0),(0,-1),(-1,0))[face]
  if '_bottom' in entry:
   counts['complete_beds']+=1
   target=(x+dx,y,z+dz)
   other=beds.get(target,'')
   # Fallback ids may differ, but family, half and orientation must agree.
   core=lambda s:s.split(' else=')[0]
   if core(other)!=core(entry.replace('_bottom','_top')):issues.append([path.stem,[x,y,z],entry,other])
  if '_top' in entry and (x in (0,t.pivot[0]-1) or z in (0,t.pivot[1]-1)):
   boundary.append([path.stem,[x,y,z],entry])
assert not issues,issues
assert not boundary,boundary
cells={}
for key,t in [('before',old),('after',new)]:
 c,bad=T.resolved_cells(t,T.resolve(t,pal,binding),pal);assert not bad
 cells[key]=c
for x in (1,3):
 assert cells['after'][x,1,12]==('beds:bed_bottom',0)
 assert cells['after'][x,1,13]==('beds:bed_top',0)
 assert reg['nodes'][cells['after'][x,1,14][0]]['walkable']
 # Every bed box stays within its own cell, so both complete beds now fit
 # wholly inside the wall envelope. The two-cell selection box is not mesh.
 for z in (12,13):
  box=reg['nodes'][cells['after'][x,1,z][0]]['node_box']['fixed']
  boxes=[box] if isinstance(box[0],(float,int)) else box
  assert all(all(-.5<=v<=.5 for v in row) for row in boxes)
# Conservative 2-node-high walking cells from inside the front door to each
# bed foot approach. Decorations marked walkable count as blocked.
c=cells['after'];start=(5,2);queue=deque([start]);seen={start}
def free(x,z):
 return all(not reg['nodes'].get(c.get((x,y,z),('air',0))[0],{}).get('walkable',False) for y in (1,2))
assert free(*start)
while queue:
 x,z=queue.popleft()
 for q in ((x+1,z),(x-1,z),(x,z+1),(x,z-1)):
  if 1<=q[0]<=9 and 1<=q[1]<=13 and q not in seen and free(*q):seen.add(q);queue.append(q)
assert (1,11) in seen and (3,11) in seen
report={'changed_cells':sorted(expected),'points_preserved':True,'bed_pairs':counts,'invalid_pairs':issues,'boundary_heads':boundary,'interior_bed_approaches_reachable':True,'note':'Conservative static two-high occupancy check, not native pathfinding; all sockets unchanged.'}
(HERE/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
# Same camera for each actual-cell pair; hide the upper wall/roof to expose
# the mattress positions. The outside wall view retains the wall to y=4.
tex=V.Textures();source=tex.bank.texture
from PIL import Image
def texture(n):
 if n=='blank.png':return Image.open(ROOT/'mods/ENTITIES/grug_mobs/textures/grug_mobs_blank.png').convert('RGBA')
 return source(n)
tex.bank.texture=texture
meshes={};names=[];indices={};scenes={}
for key,c in cells.items():
 for view,eye,target,fov in [('inside',[7,8,7],[2,1,13],46),('outside',[7,4,20],[2,1.4,14],48)]:
  cut={p:v for p,v in c.items() if -1<=p[0]<=7 and 9<=p[2]<=15 and p[1]<=(1 if view=='inside' else 4) and v[0]!='air'}
  spec={'title':key+' '+view,'description':'Saved actual Dawnmere inn geometry; cropped for the bed and rear-wall detail.','camera':{'eye':eye,'target':target,'fov':fov},'sky':'#26343c','fog':[100,200],'tint':'#ffffff'}
  scenes[key+'-'+view]=V.pack_cells({'spec':spec},[(*p,*v) for p,v in sorted(cut.items())],indices,names)
types,missing=V.build_types(names,reg['nodes'],reg['aliases'],tex,meshes)
assert not missing['skipped'] and not missing['missing_mesh'] and not tex.missing
payload={'scenes':scenes,'types':types,'textures':tex.images,'meshes':meshes,'body':[]}
page=V.inline_renderer((ROOT/'tools/character_creation_preview/scenes.html.in').read_text()).replace('__PORTRAIT__','function placePortrait(){}').replace("||'human'","||'after-inside'")
page=page.replace('t.colorSpace = THREE.SRGBColorSpace;','t.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;','renderer.outputEncoding = THREE.sRGBEncoding;')
for token,path in {'__THREE__':'tools/r54_armor/vendor/three.min.js','__ORBIT__':'tools/r69_camp_art/orbit.js','__LICENSE__':'tools/r69_camp_art/THREE-LICENSE.txt'}.items():page=page.replace(token,(ROOT/path).read_text().replace('</','<\\/'))
digest=hashlib.sha256(json.dumps({'payload':payload,'page':page,'builder':Path(__file__).read_text()},sort_keys=True).encode()).hexdigest()
for s in scenes.values():s['digest']=digest
(HERE/'scenes.html').write_text(page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/')))
print(json.dumps(report))
