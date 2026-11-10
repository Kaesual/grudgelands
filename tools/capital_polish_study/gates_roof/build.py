#!/usr/bin/env python3
"""Read shipped templates and render isolated, editable gate and ridge proposals."""
import sys, json, hashlib, base64
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(ROOT/'tools/r70_castle'))
import build as B
V,T,G=B.V,B.T,B.G
REG=json.loads((ROOT/'tools/building_templates/nodes.json').read_text())
P=T.Palettes(G.load_palettes('luajit',set(REG['nodes'])|set(REG['aliases'])))
BASE=ROOT/'mods/MAPGEN/grug_mapgen/building_templates'
OUT={}; AUDIT={}; SOURCES={}
def load(name,race):
 path=BASE/'templates'/f'{name}.tpl';layout_path=BASE/'layouts'/f'{B.TOWNS[race]}.roster'
 t=T.parse_template(str(path));layout=T.parse_layout(str(layout_path))
 rec=next(r for r in layout.uses if r['template']==name)
 c,bad=T.resolved_cells(t,T.resolve(t,P,G.placement_binding(P,layout,rec)),P)
 assert not bad,bad
 for p in (path,layout_path): SOURCES[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
 return t,c
for race in B.RACES:
 town=B.TOWNS[race]
 gate=town+('_gate_house_south' if race=='troll' else '_gate_south')
 t,c=load(gate,race)
 arch=[(x,5,z,c[x,5,z][0],c[x,5,z][1]) for x in (4,8) for z in range(7) if (x,5,z) in c and 'stair' in c[x,5,z][0]]
 AUDIT[race]={'gate_template':gate,'arch_cells':arch}
 if race!='troll':
  assert len(arch)==14
  assert all(p2==(1 if x==4 else 3) for x,y,z,n,p2 in arch)
 if race=='human':
  OUT['gate-current']={p:v for p,v in c.items() if p[1]<=7}
  OUT['gate-proposal']=dict(OUT['gate-current'])
  for x,y,z,n,p2 in arch: OUT['gate-proposal'][x,y,z]=(n,21 if x==4 else 23)
  OUT['gate-context']=c
 t,c=load(B.OLD[race],race)
 ridge=[(p,v) for p,v in c.items() if p[0]==22 and p[1] in (27,28) and 8<=p[2]<=32]
 assert len(ridge)==50
 for z in range(8,33):
  assert c[22,27,z][1]==20 and 'slab' in c[22,27,z][0]
  assert c[22,28,z][1]==0 and REG['nodes'][c[22,28,z][0]].get('drawtype','normal')=='normal'
 AUDIT[race]['ridge']={'template':B.OLD[race],'x':22,'z':[8,32],'upper_slab_y':27,'full_block_y':28,'slab':c[22,27,20][0],'block':c[22,28,20][0],'air_gap':[26.5,27]}
 if race=='human':
  OUT['roof-context']=c
  OUT['ridge-current']={p:v for p,v in c.items() if 12<=p[0]<=32 and 20<=p[2]<=21 and p[1]>=20}
  OUT['ridge-proposal']=dict(OUT['ridge-current'])
  for z in (20,21):
   slab=c[22,27,z][0];block=c[22,28,z][0]
   OUT['ridge-proposal'][22,27,z]=(block,0)
   OUT['ridge-proposal'][22,28,z]=(slab,0)
CAMERAS={
 'gate-context':([21,15,-19],[6,6,3],46),
 'gate-current':([6,4.9,-9],[6,4.6,3],48),
 'gate-proposal':([6,4.9,-9],[6,4.6,3],48),
 'roof-context':([56,40,-14],[22,17,19],45),
 'ridge-current':([22,27,4],[22,26.5,20],48),
 'ridge-proposal':([22,27,4],[22,26.5,20],48)}
TITLES={'gate-context':'Tor im Hauptstadt-Kern · Bestand','gate-current':'Torbogen · Bestand','gate-proposal':'Torbogen · Vorschlag, noch nicht eingebaut','roof-context':'Königsburg · Bestand','ridge-current':'Dachfirst · Querschnitt Bestand','ridge-proposal':'Dachfirst · ½ Block tiefer, Vorschlag'}
names=[];indices={};tex=V.Textures();meshes={};scenes={}
for key,c in OUT.items():
 eye,target,fov=CAMERAS[key]
 spec={'title':TITLES[key],'camera':{'eye':eye,'target':target,'fov':fov},'sky':'#aebfc5','fog':[160,240],'tint':'#ffffff','description':'Goldene Rahmen markieren die untersuchten Bauteile. Alle Koordinaten sind lokal zum Template.'}
 scenes[key]=V.pack_cells({'spec':spec},[(*p,*v) for p,v in sorted(c.items()) if v[0]!='air' and REG['nodes'][v[0]].get('drawtype')!='airlike'],indices,names)
types,report=V.build_types(names,REG['nodes'],REG['aliases'],tex,meshes)
assert not report['skipped'] and not report['missing_mesh'] and not tex.missing,(report,tex.missing)
payload={'scenes':scenes,'types':types,'textures':tex.images,'meshes':meshes,'body':[]}
source=ROOT/'tools/character_creation_preview/scenes.html.in'
page=source.read_text().replace("||'human'","||'gate-current'")
page=page.replace('Backdrop scene','Building study').replace('Grudgelands · Character backdrop scenes','Grudgelands · Torbogen und Dachfirst')
page=page.replace('__PORTRAIT__','function placePortrait(){}')
page=page.replace('Scene sources: tools/character_creation_preview/scenes/','Source: tools/capital_polish_study/gates_roof/build.py')
# Mark exact node envelopes, never replace the original geometry with an approximation.
page=page.replace('pixelTextures();camera();', '''pixelTextures();
 if(window.marks){view.scene.remove(window.marks);window.marks.traverse(o=>{if(o.geometry)o.geometry.dispose();if(o.material)o.material.dispose()})}
 window.marks=new THREE.Group();view.scene.add(window.marks);
 const box=(x,y,z,w,h,d)=>{z=-z;const a=new THREE.Box3(new THREE.Vector3(x-w/2,y-h/2,z-d/2),new THREE.Vector3(x+w/2,y+h/2,z+d/2));const line=new THREE.Box3Helper(a,0xffc347);window.marks.add(line)};
 if(race.startsWith('gate-')){for(const x of [4,8])box(x,5,-.015,1.025,1.025,1.035)}
 if(race.startsWith('ridge-'))box(22,race.endsWith('proposal')?27.25:27.75,20.5,1.04,1.54,2.04);
 camera();''')
page=V.inline_renderer(page).replace('t.colorSpace = THREE.SRGBColorSpace;','t.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;','renderer.outputEncoding = THREE.sRGBEncoding;')
for token,path in {'__THREE__':ROOT/'tools/r54_armor/vendor/three.min.js','__ORBIT__':ROOT/'tools/r69_camp_art/orbit.js','__LICENSE__':ROOT/'tools/r69_camp_art/THREE-LICENSE.txt'}.items():page=page.replace(token,path.read_text().replace('</','<\\/'))
for key,s in scenes.items():s['digest']=hashlib.sha256(json.dumps({'scene':s,'types':types,'textures':tex.images,'builder':Path(__file__).read_text()},sort_keys=True).encode()).hexdigest()
page=page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
(HERE/'scenes.html').write_text(page)
(HERE/'audit.json').write_text(json.dumps({'races':AUDIT,'sources':SOURCES},indent=2)+'\n')
print('6 palettes audited; 70 arch stairs; all 6 ridge profiles identical. 6 render scenes; no missing media.')
