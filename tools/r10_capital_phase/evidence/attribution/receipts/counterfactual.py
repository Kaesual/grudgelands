from pathlib import Path
import csv,hashlib,json
r=Path('/tmp/grudgelands-r10/overlay-attribution');repo=Path.cwd();report=[]
def read(p):
 result={}
 for line in p.read_text().splitlines():
  if not line or line.startswith('#'):continue
  row=line.split('\t');result[tuple(map(int,row[:3]))]=tuple(row[3:])
 return result
for capital,labels in [('gor_drazhak',['avenue','rampart','corner']),('lethariel',['avenue'])]:
 for label in labels:
  mask=r/'historical-masks'/(capital+'-'+label+'-mask.tsv')
  if not mask.exists():continue
  hist=read(r/'historical-output'/(capital+'-'+label+'.tsv'));writes=read(mask)
  now=read(r/'final-output'/(capital+'-'+label+'.tsv'))
  names=set((r/'final-output'/(capital+'-road-names.txt')).read_text().splitlines())
  engine=read(Path('/tmp/grudgelands-r10-final-engines/capitals-v2')/capital/(capital+'-'+label+'.tsv'))
  extras={p:v for p,v in engine.items() if v[0] in names and p not in now}
  assert all(v[0]==('default:dry_dirt' if capital=='gor_drazhak' else 'grug_nodes:dirt_with_silver_litter') for v in extras.values())
  conflict={p:v for p,v in extras.items() if p in writes}
  kept={p:v for p,v in extras.items() if p not in writes}
  result=dict(hist);result.update(kept)
  def order(p):
   if label=='corner':return (int(p[0]>0)*2+int(p[2]>0),p[2],p[1],p[0])
   return(p[2],p[1],p[0])
  ordered=sorted(result,key=order)
  data='\n'.join(':'.join(map(str,p+result[p])) for p in ordered)
  digest=hashlib.sha256(data.encode()).hexdigest()
  words=(repo/'tools/wp13/evidence/20260915-capital-terrain'/capital/(label+'-digest-531802985935182545.txt')).read_text().split()
  expected_count=int(next(w.split('=')[1] for w in words if w.startswith('overlay_cells=')))
  row=dict(capital=capital,label=label,sha256=digest,count=len(result),expected_sha256=words[0],expected_count=expected_count,extras=len(extras),old_write_conflicts=len(conflict),match=digest==words[0] and len(result)==expected_count)
  report.append(row)
  (r/(capital+'-'+label+'-counterfactual.tsv')).write_text(''.join('\t'.join(map(str,p+result[p]))+'\n' for p in ordered))
(r/'counterfactual.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
