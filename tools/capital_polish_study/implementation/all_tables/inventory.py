#!/usr/bin/env python3
"""Read-only furniture inventory; never writes shipped sources."""
import collections,hashlib,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/building_templates/viewer'))
import templates as T,build_gallery as G
base=ROOT/'mods/MAPGEN/grug_mapgen/building_templates'
reg=json.loads((ROOT/'tools/building_templates/nodes.json').read_text())
pal=T.Palettes(G.load_palettes('luajit',set(reg['nodes'])|set(reg['aliases'])))
tpls,lays=G.read_sources(str(base));uses=collections.defaultdict(list)
for lay in lays:
 for rec in (lay.places if lay.kind=='layout' else lay.uses):uses[rec['template']].append((lay,rec))
rows=[];other=[];counts=collections.Counter();placed_tables=collections.Counter();air_above=[];existing=collections.Counter();heights=collections.Counter()
for t in tpls:
 def ent(p):return t.legend.get(t.cells.get(p),{})
 pairs=[]
 for pos in t.cells:
  e=ent(pos)
  if e.get('kind')=='role' and e.get('name')=='table_top':
   x,y,z=pos;leg=(x,y-1,z)
   assert ent(leg).get('kind')=='role' and ent(leg).get('name')=='table_leg',(t.name,pos)
   assert not e.get('o') and not ent(leg).get('o'),(t.name,pos)
   pairs.append({'top':pos,'leg':leg,'above':ent((x,y+1,z)).get('text'),'below':ent((x,y-2,z)).get('text')})
   heights[y]+=1
   if ent((x,y+1,z)):air_above.append({'template':t.name,'top':pos,'above':ent((x,y+1,z))['text']})
 legs=[p for p in t.cells if ent(p).get('kind')=='role' and ent(p).get('name')=='table_leg']
 assert len(legs)==len(pairs),(t.name,'orphan legs')
 if pairs:
  rows.append({'template':t.name,'path':str(Path(t.path).relative_to(ROOT)),'sha256':hashlib.sha256(Path(t.path).read_bytes()).hexdigest(),'count':len(pairs),'pairs':pairs,'uses':[{'source':str(Path(l.path).relative_to(ROOT)),'count':r.get('count',1)} for l,r in uses[t.name]]})
  counts['candidate_templates']+=1;counts['paired_cells']+=len(pairs)
 counts['templates']+=1
 bindings=[(str(Path(l.path).relative_to(ROOT)),G.placement_binding(pal,l,r)) for l,r in uses[t.name]] or [('fallback',{'main':pal.bind(t.races[0] if t.races else 'human')})]
 seen=set()
 for source,binding in bindings:
  cells,bad=T.resolved_cells(t,T.resolve(t,pal,binding),pal)
  assert not bad,(t.name,bad)
  for pos,(name,p2) in cells.items():
   marker=(pos,name,p2)
   if marker in seen:continue
   seen.add(marker)
   nd=reg['nodes'].get(name,{})
   if nd.get('groups',{}).get('slab') or 'slab' in name:
    x,y,z=pos;below=cells.get((x,y-1,z))
    if below and ('fence' in below[0] or reg['nodes'].get(below[0],{}).get('groups',{}).get('fence')):
     if ent(pos).get('name')!='table_top':other.append({'template':t.name,'position':pos,'top':name,'top_entry':ent(pos).get('text'),'below':below[0],'below_entry':ent((x,y-1,z)).get('text'),'source':source})
   if name in ['grug_decor:cottages_table','grug_decor:xdecor_table','grug_decor:capital_counter']:existing[name]+=1
counts['other_slab_fence_pairs']=len(other)
report={'counts':dict(counts),'top_heights':dict(heights),'existing_tables_resolved_unique_per_template':dict(existing),'candidates':rows,'occupied_above':air_above,'other_slab_fence_pairs':other}
(HERE/'inventory.json').write_text(json.dumps(report,indent=2)+'\n')
(HERE/'candidates.tsv').write_text('template\tpairs\n'+''.join(f'{r["template"]}\t{r["count"]}\n' for r in rows))
print(json.dumps({k:v for k,v in report.items() if k not in ('candidates','other_slab_fence_pairs')},indent=2))
print('Other slab-over-fence patterns:',json.dumps(other,indent=2))
