import csv,re,statistics,sys
from pathlib import Path
out=Path(sys.argv[1]);out.mkdir(exist_ok=True,parents=True)
evidence=Path(sys.argv[2])
groups={label:[evidence/'performance'/(label+'-'+str(i)) for i in range(1,4)] for label in ['baseline','sampler']}
identity=None;seen={};results={};aggregate={}
for label,paths in groups.items():
 runs=[];digests=set()
 for p in paths:
  s=dict(l.split('\t',1) for l in (p/'summary.tsv').read_text().splitlines())
  assert s['cold_mapgen_callbacks']=='10' and s['disk_mapgen_callbacks']=='0' and s['disk_loaded_blocks']=='1250' and s['full_voxels']=='5120000'
  this=(s['full_vocabulary_digest'],(p/'engine-version.txt').read_text(),(p/'harness.sha256').read_text())
  if identity is None:identity=this
  assert this==identity,(p,'measurement inputs differ')
  digests.add(s['full_digest'])
  r=[dict(re.findall(r'(\w+)=([^ ]+)',l)) for l in (p/'cold/profile-events.log').read_text().splitlines() if 'PROFILE_CALLBACK ' in l]
  assert len(r)==10;runs.append(r)
 assert len(digests)==1,'same-seed repeats differ';seen[label]=digests.pop()
 results[label]=runs
 aggregate[label]={}
 for name,indices in [('all',range(10)),('surface',range(9))]:
  values=[sum(int(r[i]['total_us']) for i in indices) for r in runs]
  aggregate[label][name]=(statistics.median(values),min(values),max(values))
assert seen['baseline']!=seen['sampler'],'ore layout should differ'
with (out/'performance.tsv').open('w') as f:
 w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(['variant','owner','runs','plan_median_us','writer_median_us','callback_median_us','callback_min_us','callback_max_us'])
 for label,runs in results.items():
  for i in range(10):
   pos={r[i]['minp'] for r in runs};assert len(pos)==1
   w.writerow([label,pos.pop(),3,*[statistics.median(int(r[i][k]) for r in runs) for k in ['plan_us','writer_us','total_us']],min(int(r[i]['total_us']) for r in runs),max(int(r[i]['total_us']) for r in runs)])
with (out/'performance-aggregate.tsv').open('w') as f:
 w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(['variant','population','callback_sum_median_us','min_us','max_us'])
 for label,d in aggregate.items():
  for name,values in d.items():w.writerow([label,name,*values])
print(aggregate)
