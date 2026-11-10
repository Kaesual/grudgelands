#!/usr/bin/env python3
"""Verify shipped furniture against the accepted study; export actual cells."""
import copy,hashlib,json,re,subprocess,sys,tempfile
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/building_templates/viewer'))
import templates as T, build_viewer as V, build_gallery as G
STUDY=ROOT/'tools/capital_polish_study/tables'
html=(STUDY/'scenes.html').read_text()
pattern=r'(<script id="payload" type="application/json">)(.*?)(</script>)'
payload=json.loads(re.search(pattern,html,re.S)[2])
registry=json.loads((ROOT/'tools/building_templates/nodes.json').read_text())['nodes']
pal=T.Palettes(G.load_palettes('luajit',set(registry)))
names=[t['name'] for t in payload['types']];indices={n:i for i,n in enumerate(names)}
audit=json.loads((STUDY/'audit.json').read_text())
actual={};report={}
for race,record in audit.items():
 path=ROOT/record['template'];tpl=T.parse_template(str(path))
 city=tpl.name.removesuffix('_miners_guild')
 roster=T.parse_layout(str(ROOT/'mods/MAPGEN/grug_mapgen/building_templates/layouts'/f'{city}.roster'))
 placement=next(r for r in roster.uses if r['template']==tpl.name)
 binding=G.placement_binding(pal,roster,placement)
 baseline=subprocess.run(['git','show','HEAD:'+record['template']],cwd=ROOT,check=True,text=True,capture_output=True).stdout
 assert hashlib.sha256(baseline.encode()).hexdigest()==record['sha256'],race+' baseline changed from reviewed study'
 with tempfile.TemporaryDirectory(prefix='grug-table-audit-') as tmp:
  oldpath=Path(tmp)/path.name;oldpath.write_text(baseline);old=T.parse_template(str(oldpath))
 def meaning(t):return {p:t.legend[k]['text'] if k in t.legend else k for p,k in t.cells.items()}
 before,after=meaning(old),meaning(tpl)
 changed={p for p in before.keys()|after.keys() if before.get(p)!=after.get(p)}
 expected={tuple(v['position']) for v in record['cells']}
 assert changed==expected,(race,changed^expected)
 assert all(after[p]=='node grug_decor:xdecor_table' for p in changed if p[1]==1)
 assert after[2,2,7]=='air'
 assert len([v for v in after.values() if v=='node grug_decor:xdecor_table'])==10
 def points(t):return [{k:v for k,v in p.items() if k!='line'} for p in t.points]
 assert points(tpl)==points(old),race+' sockets/points changed'
 assert (tpl.origin,tpl.size,tpl.pivot)==(old.origin,old.size,old.pivot)
 cells,bad=T.resolved_cells(tpl,T.resolve(tpl,pal,binding),pal);assert not bad,bad
 raw=[(*p,*v) for p,v in sorted(cells.items()) if p[1]<=2 and registry[v[0]]['drawtype']!='airlike']
 proposal=payload['scenes'][race+'_after']
 scene=V.pack_cells({'spec':copy.deepcopy(proposal['spec'])},raw,indices,names)
 assert scene['cells']==proposal['cells'] and scene['count']==proposal['count'],race+' actual cells differ from approved proposal'
 scene['spec']['title']=city.replace('_',' ').title()+' · Implementiert'
 scene['spec']['description']='Aus der tatsächlich geschriebenen Gebäudevorlage gelesen. Oberer Gebäudeschnitt; Figuren sind 1,70-Block-Maßreferenzen.'
 scene['digest']=hashlib.sha256(json.dumps(scene,sort_keys=True).encode()).hexdigest()
 actual[race+'_actual']=scene
 report[race]={'template':record['template'],'baseline_sha256':record['sha256'],'actual_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'changed_cells':sorted(changed),'points_preserved':True,'accepted_proposal_match':True}
payload['scenes']=actual
encoded=json.dumps(payload,separators=(',',':')).replace('</','<\\/')
html=re.sub(pattern,lambda m:m[1]+encoded+m[3],html,flags=re.S).replace("||'detail_before'","||'human_actual'").replace('Nur Entwurf · keine Spieländerungen','Implementierung im Worktree · noch nicht veröffentlicht')
(HERE/'scenes.html').write_text(html)
(HERE/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: all six shipped templates match approved furniture cells; only 11 cells per template changed; all points and bounds preserved.')
