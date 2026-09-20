"""Compare bounded actual source diagnostic rows, without rewriting expectations."""
import csv,json,sys
from pathlib import Path
out=Path(sys.argv[1]);before=list(csv.DictReader((out/'beach-sightlines-before.tsv').open(),delimiter='\t'))
after=list(csv.DictReader((out/'beach-sightlines-after.tsv').open(),delimiter='\t'))
assert len(before)==len(after)==8450
for a,b in zip(before,after):
 for field in ['case','x','z','owner_x','owner_z','class','claim','cave_claim','incoming','kind','functional_id','landmark','distance']:
  assert a[field]==b[field],(field,a,b)
 if a['run']==b['run']:
  for field in ['profile','width','coast_y','final']:assert a[field]==b[field],(field,a,b)
def peaks(rows,case):
 m={(int(r['x']),int(r['z'])):r for r in rows if r['case']==case};result=[]
 for (x,z),r in m.items():
  if r['class']!='land':continue
  ns=[m.get((x+dx,z+dz))for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]]
  if not all(ns) or not all(n['class']=='land'for n in ns):continue
  delta=[int(r['final'])-int(n['final'])for n in ns]
  if min(delta[:2])>=5 or min(delta[2:])>=5:result.append([x,z,int(r['final'])])
 return result
report=[]
for case in ['1','2']:
 old,new=peaks(before,case),peaks(after,case)
 assert old and not new,(case,old,new)
 report.append(dict(case=case,before_thin_high_columns=old,after_thin_high_columns=new,
  changed_heights=sum(a['final']!=b['final']for a,b in zip(before,after)if a['case']==case),
  rows=4225))
(out/'beach-comparison.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: 8450 real source columns; classification/exclusions/functionals/incoming/distance unchanged; no >=5-node thin dry spikes in either after rectangle')
