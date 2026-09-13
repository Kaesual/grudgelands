from pathlib import Path
import re, csv, sys, collections, json
root=Path(sys.argv[1]); dest=Path(sys.argv[2]);dest.mkdir(exist_ok=True,parents=True)
FIELDS=['eligible','budget','planned','accepted','collisions','shortfall','placed']
def read(path):
 summary=dict(l.split('\t',1) for l in (path/'summary.tsv').read_text().splitlines())
 assert summary['cold_mapgen_callbacks']=='10' and summary['disk_mapgen_callbacks']=='0' and summary['disk_loaded_blocks']=='1250'
 rows={}
 for l in (path/'cold/server.log').read_text().splitlines():
  if 'GRUG_RESOURCE_AUDIT\t' not in l:continue
  f=l.split('GRUG_RESOURCE_AUDIT\t')[1].split('\t');key=tuple(f[:6]);assert key not in rows
  rows[key]=dict(zip(FIELDS,map(int,f[6:])));r=rows[key]
  assert r['placed']+r['shortfall']==r['budget']
 counts=collections.Counter();normalized={}
 for phase in ['cold','disk']:
  normalized[phase]={};phasecounts=collections.Counter()
  for l in (path/phase/'profile-events.log').read_text().splitlines():
   d=dict(re.findall(r'(\w+)=([^ ]+)',l))
   if d.get('event')=='ore_count':phasecounts[d['resource']]+=int(d['nodes'])
   if d.get('event')=='normalized_owner':normalized[phase][d['case']]=(d['normalized'],d['param2'],d['light'])
  if phase=='cold':counts=phasecounts
  else:assert counts==phasecounts
 assert normalized['cold']==normalized['disk'] and len(normalized['cold'])==10
 placed=collections.Counter()
 for k,r in rows.items():placed[k[0]]+=r['placed']
 assert placed==counts, (path,placed-counts,counts-placed)
 return rows,normalized['cold'],summary
result=[];grouped=collections.defaultdict(lambda:collections.Counter());whole=collections.Counter();types=set();tiers=set();bands=set()
for seed in range(5):
 b,bnorm,bs=read(root/('baseline-'+str(seed)));p,pnorm,ps=read(root/('sampler-'+str(seed)))
 assert b.keys()==p.keys() and bnorm==pnorm,('keys or non-ore terrain/light differ',seed)
 assert bs['full_vocabulary_digest']==ps['full_vocabulary_digest']
 assert bs['full_digest']!=ps['full_digest'],'expected changed ore positions'
 for key in sorted(b):
  assert all(b[key][f]==p[key][f] for f in ['eligible','budget','planned']),(seed,key)
  types.add(key[0]);tiers.add(key[4]);bands.add(key[5])
  for variant,rows in [('baseline',b),('sampler',p)]:
   for f,n in rows[key].items():
    grouped[(key[0],key[4],variant)][f]+=n
    whole[(variant,f)]+=n
  result.append([seed,*key,*[b[key][f] for f in FIELDS],*[p[key][f] for f in FIELDS]])
with (dest/'groups.tsv').open('w') as f:
 w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(['case_pack','resource','cell_x','cell_y','cell_z','tier','band']+['baseline_'+n for n in FIELDS]+['sampler_'+n for n in FIELDS]);w.writerows(result)
with (dest/'resources.tsv').open('w') as f:
 w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(['resource','tier','variant']+FIELDS)
 for key,d in sorted(grouped.items()): w.writerow([*key,*[d[n] for n in FIELDS]])
report={'owners':50,'seeds':3,'field_groups':len(result),'resource_types':sorted(types),'tiers':sorted(tiers),'bands':sorted(bands),'normalized_content_param2_light_equal':True,'vm_ore_count_matches_placed':True,'budget_eligible_planned_equal':True}
for variant in ['baseline','sampler']:report[variant]={f:whole[(variant,f)] for f in FIELDS}
(dest/'summary.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
