#!/usr/bin/env python3
"""Tools-only guild furniture study. Reads shipped templates; writes only here."""
import hashlib,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(ROOT/'tools/building_templates/viewer'))
import build_viewer as V, build_gallery as G, templates as T
reg=json.loads((ROOT/'tools/building_templates/nodes.json').read_text())
pal=T.Palettes(G.load_palettes('luajit',set(reg['nodes'])))
textures,meshes,names,indices,scenes={},{},[],{},{}
textures=V.Textures()
audit={}
CITIES={'human':'highcourt','dwarf':'dur_brannoc','elf':'lethariel','orc':'gor_drazhak','troll':'kezamba','undead':'nhal_veyr'}
def add(key,cells,title,description,camera,people=[]):
 spec={'title':title,'description':description,'camera':camera,'sky':'#253238','fog':[70,150],'tint':'#ffffff','people':people}
 scenes[key]=V.pack_cells({'spec':spec},[(*p,*v) for p,v in sorted(cells.items()) if reg["nodes"][v[0]]["drawtype"] != "airlike"],indices,names)
for race,city in CITIES.items():
 path=ROOT/'mods/MAPGEN/grug_mapgen/building_templates/templates'/f'{city}_miners_guild.tpl'
 tpl=T.parse_template(str(path))
 roster=T.parse_layout(str(ROOT/'mods/MAPGEN/grug_mapgen/building_templates/layouts'/f'{city}.roster'))
 placement=next(r for r in roster.uses if r['template']==tpl.name)
 binding=G.placement_binding(pal,roster,placement)
 cells,bad=T.resolved_cells(tpl,T.resolve(tpl,pal,binding),pal)
 assert not bad,bad
 furniture={p:tpl.legend[k] for p,k in tpl.cells.items() if k in tpl.legend and tpl.legend[k]['name'] in ('table_top','table_leg')}
 audit[race]={'template':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'cells':[{'position':p,'entry':e['text'],'resolved':cells[p]} for p,e in sorted(furniture.items())]}
 cut={p:v for p,v in cells.items() if p[1]<=2}
 people=[]
 for p in tpl.points:
  if p['group']=='sockets' and any(k=='id' and v.endswith(('_clerk','_exchange','_leader','_sorter')) for k,v in p['attrs']): people.append([p['x'],.5,p['z']])
 cam={'eye':[20,16,-3],'target':[6,0,10],'fov':43}
 proposed=dict(cut)
 for p in furniture: proposed.pop(p,None)
 for x,y,z in furniture:
  proposed[x,1,z]=('grug_decor:xdecor_table',0)
 for variant,data in [('before',cut),('after',proposed)]:
  add(race+'_'+variant,data,city.replace('_',' ').title()+' · '+('Bestand' if variant=='before' else 'Vorschlag'),
   'Dachschnitt bei y=2; graue Figuren sind 1,70-Block-Maßreferenzen, keine NPC-Renderings. Alle vier Arbeitsplätze bleiben an ihrem Ort.',cam,people)
 # Two isolated actual arrangements, rotated for a readable frontal comparison.
 if race=='human':
  leg=next(cells[p][0] for p,e in furniture.items() if e['name']=='table_leg')
  slab=next(cells[p][0] for p,e in furniture.items() if e['name']=='table_top')
  floor=next(cells[p][0] for p,k in tpl.cells.items() if k in tpl.legend and tpl.legend[k]['name']=='floor')
  detail={(x,0,z):(floor,0) for x in range(-5,6) for z in range(-2,3)}
  before=dict(detail);before[-3,1,0]=(leg,0);before[-3,2,0]=(slab,0)
  before[1,1,0]=(leg,0);before[2,1,0]=(slab,20);before[3,1,0]=(leg,0)
  after=dict(detail)
  for x in [-3,1,2,3]:after[x,1,0]=('grug_decor:xdecor_table',0)
  camera={'eye':[8,5,-12],'target':[0,1,0],'fov':42}
  for variant,data in [('before',before),('after',after)]:
   add('detail_'+variant,data,'Tische · '+('Bestand' if variant=='before' else 'Vorschlag'),
    'Links: Registrar. Rechts: die niedrigen Schreibtische. Gleiche Kamera, gleicher Boden. Maßfiguren: 1,70 Blöcke.',camera,[[-3,.5,1],[2,.5,1]])
 # Directly prove the current higher clerk desk and the three unsupported tops.
 assert sum(e['name']=='table_top' and p[1]==2 for p,e in furniture.items())==1
 assert sum(e['name']=='table_top' and e.get('o')==('facedir',20) for p,e in furniture.items())==3
 assert len({(x,z) for x,y,z in furniture})==10
assert len(audit)==6
types,report=V.build_types(names,reg['nodes'],reg.get('aliases',{}),textures,meshes)
assert not report['skipped'] and not report['missing_mesh'] and not textures.missing,(report,textures.missing)
body=[b for b in json.loads((ROOT/'tools/r54_armor/data/catalog.json').read_text())['body'] if b['id']!='hat']
payload={'scenes':scenes,'types':types,'textures':textures.images,'meshes':meshes,'body':body}
for scene in scenes.values():scene['digest']=hashlib.sha256((json.dumps(scene,sort_keys=True)+(HERE/'scenes.html.in').read_text()).encode()).hexdigest()
page=V.inline_renderer((HERE/'scenes.html.in').read_text())
page=page.replace('t.colorSpace = THREE.SRGBColorSpace;','t.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;','renderer.outputEncoding = THREE.sRGBEncoding;')
for token,path in {'__THREE__':ROOT/'tools/r54_armor/vendor/three.min.js','__ORBIT__':ROOT/'tools/r69_camp_art/orbit.js','__LICENSE__':ROOT/'tools/r69_camp_art/THREE-LICENSE.txt'}.items():page=page.replace(token,path.read_text().replace('</','<\\/'))
page=page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
(HERE/'scenes.html').write_text(page)
(HERE/'audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print('14 scenes; six templates measured; no missing nodes or media.')
