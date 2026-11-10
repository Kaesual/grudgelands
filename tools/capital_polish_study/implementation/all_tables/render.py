#!/usr/bin/env python3
"""Build six before/after cutaways from the saved and installed real templates."""
import copy,hashlib,json,re,sys
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/building_templates/viewer'))
import build_viewer as V,build_gallery as G,templates as T
reg=json.loads((ROOT/'tools/building_templates/nodes.json').read_text())
pal=T.Palettes(G.load_palettes('luajit',set(reg['nodes'])|set(reg['aliases'])))
_,lays=G.read_sources(str(ROOT/'mods/MAPGEN/grug_mapgen/building_templates'))
selected=[('dawnmere_field_cottage','Wohnhaus'),('highcourt_homes_tavern','Taverne'),('dur_brannoc_deep_scriptorium','Schreibsaal'),('highcourt_market','Markt'),('kezamba_moot_house','Erhöhte Tische'),('nhal_veyr_market_bonesmith','Nhal Veyr')]
textures=V.Textures();meshes={};names=[];indices={};scenes={};sources={}
original_texture=textures.bank.texture
def texture(name):
 if name=='blank.png':return Image.open(ROOT/'mods/ENTITIES/grug_mobs/textures/grug_mobs_blank.png').convert('RGBA')
 return original_texture(name)
textures.bank.texture=texture
for name,label in selected:
 before=HERE/'before'/(name+'.tpl');after=ROOT/'mods/MAPGEN/grug_mapgen/building_templates/templates'/(name+'.tpl')
 old=T.parse_template(str(before))
 tops=[p for p,k in old.cells.items() if k in old.legend and old.legend[k].get('kind')=='role' and old.legend[k]['name']=='table_top']
 assert tops,name
 floor=min(p[1]-2 for p in tops);cut=max(p[1] for p in tops)
 xs,ys,zs=zip(*tops)
 xmin,xmax,zmin,zmax=max(old.origin[0],min(xs)-3),min(old.origin[0]+old.size[0]-1,max(xs)+3),max(old.origin[2],min(zs)-3),min(old.origin[2]+old.size[2]-1,max(zs)+3)
 cx,cz=(xmin+xmax)/2,(zmin+zmax)/2
 reach=max(xmax-xmin,zmax-zmin,5)*1.25
 camera={'eye':[cx+reach*.7,floor+reach*.95,cz-reach],'target':[cx,floor+.7,cz],'fov':42}
 lay,rec=next((l,r) for l in lays for r in (l.places if l.kind=='layout' else l.uses) if r['template']==name)
 binding=G.placement_binding(pal,lay,rec)
 for variant,path in [('before',before),('after',after)]:
  tpl=T.parse_template(str(path));cells,bad=T.resolved_cells(tpl,T.resolve(tpl,pal,binding),pal);assert not bad
  raw=[(*p,*v) for p,v in sorted(cells.items()) if floor<=p[1]<=cut and xmin<=p[0]<=xmax and zmin<=p[2]<=zmax and reg['nodes'][v[0]]['drawtype']!='airlike']
  spec={'title':label+' · '+('Bestand' if variant=='before' else 'Umgesetzt'),'description':name+' — Tatsächliche Vorlagen, gleicher Ausschnitt und gleiche Kamera. Dach und obere Wände ausgeblendet.','camera':camera,'sky':'#263338','fog':[100,200],'tint':'#ffffff','people':[]}
  key=name+'_'+variant;scenes[key]=V.pack_cells({'spec':spec},raw,indices,names)
  sources[key]={'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'crop':{'floor':floor,'cut':cut,'x':[xmin,xmax],'z':[zmin,zmax]}}
types,report=V.build_types(names,reg['nodes'],reg.get('aliases',{}),textures,meshes)
assert not report['skipped'] and not report['missing_mesh'] and not textures.missing,(report,textures.missing)
body=[];payload={'scenes':scenes,'types':types,'textures':textures.images,'meshes':meshes,'body':body}
for key,scene in scenes.items():scene['digest']=hashlib.sha256(json.dumps({'scene':scene,'source':sources[key],'types':types,'textures':textures.images,'adapter':Path(__file__).read_text()},sort_keys=True).encode()).hexdigest()
page=V.inline_renderer((ROOT/'tools/capital_polish_study/tables/scenes.html.in').read_text())
page=page.replace('t.colorSpace = THREE.SRGBColorSpace;','t.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;','renderer.outputEncoding = THREE.sRGBEncoding;')
for token,path in {'__THREE__':ROOT/'tools/r54_armor/vendor/three.min.js','__ORBIT__':ROOT/'tools/r69_camp_art/orbit.js','__LICENSE__':ROOT/'tools/r69_camp_art/THREE-LICENSE.txt'}.items():page=page.replace(token,path.read_text().replace('</','<\\/'))
page=page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/')).replace("||'detail_before'","||'dawnmere_field_cottage_after'").replace('Nur Entwurf · keine Spieländerungen','Implementierung im Worktree · noch nicht veröffentlicht')
(HERE/'scenes.html').write_text(page);(HERE/'render-sources.json').write_text(json.dumps(sources,indent=2)+'\n')
print('12 scenes prepared from six actual before/after template pairs; no missing media.')
