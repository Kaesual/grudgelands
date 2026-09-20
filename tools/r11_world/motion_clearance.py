"""Verify sampled full-yaw ground envelopes along actual authored waypoint lanes."""
import json,sys
from pathlib import Path
import numpy as np
out=Path(sys.argv[1]);margin=.01
motion={r['model']:r for r in json.loads((out/'motion-bounds.json').read_text())}
rest=json.loads((out/'clearance.json').read_text())['displays']
lines=[r.split('\t')for r in (out/'stables.tsv').read_text().splitlines()]
checks=[]
for r in rest:
 if r['tier']>2:continue
 city,key=r['city'],r['model'];m=motion[key]
 sockets=[v for v in lines if v[0]==city and v[1]=='socket']
 home=next(v for v in sockets if v[5]=='mount_display' and int(v[6])==r['tier'])
 endpoints=[next(v for v in sockets if v[7]==home[7]+'_walk_'+end) for end in ['a','b']]
 xs=[float(v[2])for v in endpoints];zs=[float(v[4])for v in endpoints]
 radius=m['radius'];lo=np.array([min(xs)-radius,.52,min(zs)-radius])
 hi=np.array([max(xs)+radius,.52+m['max_y']-m['min_y'],max(zs)+radius])
 for v in lines:
  if v[0]!=city or v[1]!='cell':continue
  p=np.array(list(map(float,v[2:5])))
  assert not(np.all(p+.5+margin>lo) and np.all(p-.5-margin<hi)),(city,key,'solid',v)
 assert lo[2]>-5.6+margin,(city,key,'front aisle')
 for other in rest:
  if other['city']!=city or other['tier']<3:continue
  assert not(np.all(np.array(other['max'])+margin>lo) and
   np.all(np.array(other['min'])-margin<hi)),(city,key,'resting flyer')
 for old in checks:
  if old['city']==city:
   assert not(np.all(np.array(old['max'])+margin>lo) and
    np.all(np.array(old['min'])-margin<hi)),(city,'ground neighbors')
 checks.append(dict(city=city,model=key,min=lo.tolist(),max=hi.tolist(),
  frames=m['frames'],foot_y=m['min_y'],margin=margin))
(out/'motion-clearance.json').write_text(json.dumps(checks,indent=2)+'\n')
print('PASS: 12 ground yaw-swept sampled clip envelopes along authored lanes vs six shelters, four-per-city population and front aisle; move-minimum grounding required')
