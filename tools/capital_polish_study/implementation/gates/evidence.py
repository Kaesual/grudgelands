#!/usr/bin/env python3
"""Verify installed gate semantics and prepare one real-template capture."""
import sys,json,re,base64,struct,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/r70_castle'))
import build as B
V,T,G=B.V,B.T,B.G
reg=json.loads((ROOT/'tools/building_templates/nodes.json').read_text())
pal=T.Palettes(G.load_palettes('luajit',set(reg['nodes'])|set(reg['aliases'])))
study=ROOT/'tools/capital_polish_study/gates_roof'
html=(study/'scenes.html').read_text()
payload=json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',html,re.S)[1])
indices={t['name']:i for i,t in enumerate(payload['types'])};names=list(indices)
checks={}
for race in ('human','dwarf','elf','orc','undead'):
 city=B.TOWNS[race];name=city+'_gate_south';path=ROOT/'mods/MAPGEN/grug_mapgen/building_templates/templates'/(name+'.tpl')
 a=T.parse_template(str(HERE/'before'/(name+'.tpl')));b=T.parse_template(str(path))
 roster=T.parse_layout(str(ROOT/'mods/MAPGEN/grug_mapgen/building_templates/layouts'/(city+'.roster')))
 placement=next(r for r in roster.uses if r['template']==name);binding=G.placement_binding(pal,roster,placement)
 before,bad=T.resolved_cells(a,T.resolve(a,pal,binding),pal);assert not bad
 after,bad=T.resolved_cells(b,T.resolve(b,pal,binding),pal);assert not bad
 expected={(x,5,z) for x in (4,8) for z in range(7)}
 changes={p for p in before if before[p]!=after[p]}
 assert changes==expected
 for x,y,z in expected:
  assert before[x,y,z][0]==after[x,y,z][0]
  assert after[x,y,z][1]==(21 if x==4 else 23)
 assert [{k:v for k,v in p.items() if k!='line'} for p in a.points]==[{k:v for k,v in p.items() if k!='line'} for p in b.points]
 checks[race]={'template':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'changed_cells':len(changes),'unmodified_cells':len(before)-len(changes),'points_unchanged':True}
 if race=='human':
  old=payload['scenes']['gate-proposal'];proposed={(x,y,z):(payload['types'][i]['name'],p2) for x,y,z,i,p2 in struct.iter_unpack('<hhhHB',base64.b64decode(old['cells']))}
  drawn={p:v for p,v in after.items() if p[1]<=7 and v[0]!='air' and reg['nodes'][v[0]].get('drawtype')!='airlike'}
  assert drawn==proposed,'Installed render geometry differs from approved preview'
  scene=V.pack_cells({'spec':old['spec']},[(*p,*v) for p,v in sorted(drawn.items())],indices,names)
  scene['spec']['title']='Torbogen · umgesetzt im Worktree'
  scene['spec']['description']='Direkt aus dem gespeicherten Highcourt-Template. Geometrie stimmt exakt mit dem freigegebenen Vorschlag überein.'
  scene['digest']=hashlib.sha256(json.dumps({'scene':scene,'types':payload['types'],'textures':payload['textures'],'source':checks[race],'adapter':Path(__file__).read_text()},sort_keys=True).encode()).hexdigest()
payload['scenes']={'gate-installed':scene}
html=re.sub(r'<script id="payload" type="application/json">.*?</script>',lambda _: '<script id="payload" type="application/json">'+json.dumps(payload,separators=(',',':'))+'</script>',html,flags=re.S).replace("||'gate-current'","||'gate-installed'")
(HERE/'scenes.html').write_text(html)
(HERE/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
print('5 gates /70 orientation fixes; all other geometry and sockets unchanged; approved render geometry exact match.')
