#!/usr/bin/env python3
"""Compare full posed mesh envelopes against actual six-capital emitted cells.

Non-air cells are conservatively treated as full cubes, including thin rails,
troughs and roof slabs. A disjoint envelope therefore proves every vertex and
triangle is disjoint too. Air, floor contact, other display envelopes and the
trainer/front aisle are checked separately; no collisionbox substitutes here.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import numpy as np
from b3d_pose import evaluate

p=argparse.ArgumentParser();p.add_argument('repo');p.add_argument('scratch');a=p.parse_args()
repo=Path(a.repo);out=Path(a.scratch)
models={};inputs=[]
for line in (out/'catalog.tsv').read_text().splitlines():
 key,name,scale,frame,textures=line.split('\t');path=next((repo/'mods').rglob(name))
 data=evaluate(path,float(frame));data.update(key=key,scale=float(scale),textures=textures.split('|'))
 vertices=np.array([v for m in data['meshes'] for v in m['vertices']])*float(scale)/10
 data['bounds']=[vertices.min(0).tolist(),vertices.max(0).tolist()]
 models[key]=data;inputs.append((path.relative_to(repo),hashlib.sha256(path.read_bytes()).hexdigest()))
source=(repo/'mods/ENTITIES/grug_mobs/capital_displays.lua').read_text()
constants=dict((k,float(v)) for k,v in re.findall(r'(\w+)=(-?[0-9]+\.[0-9]+)',source.split('local FOOT_Y={')[1].split('}')[0]))
assert set(constants)==set(models)
for key,model in models.items():
 assert abs(constants[key]-model['bounds'][0][1])<1e-8, ('production grounding differs',key)
(out/'posed-models.json').write_text(json.dumps(models))
lines=[line.split('\t') for line in (out/'stables.tsv').read_text().splitlines()]
cities=['highcourt','dur_brannoc','lethariel','nhal_veyr','gor_drazhak','kezamba']
races=['human','dwarf','elf','undead','orc','troll'];result=[]
margin=.01
for city,race in zip(cities,races):
 faction='accord' if race in races[:3] else 'throng';envelopes=[]
 cells=[r for r in lines if r[0]==city and r[1]=='cell']
 trainer=[r for r in lines if r[0]==city and r[1]=='socket' and r[5]=='riding_trainer'][0]
 trainer_pos=np.array(list(map(float,trainer[2:5])))
 for row in lines:
  if row[0]!=city or row[1]!='socket' or row[5]!='mount_display':continue
  tier=int(row[6]);key=('t1_'+faction if tier==1 else race if tier==2 else ('expert_' if tier==3 else 'master_')+faction)
  model=models[key];lo,hi=np.array(model['bounds']);position=np.array(list(map(float,row[2:5])))
  # Catalog stand[1], actual runtime yaw pi, absolute authored floor grounding.
  position[1]=position[1]-.5+.02-lo[1]
  lower=np.array([-hi[0],lo[1],-hi[2]])+position
  upper=np.array([-lo[0],hi[1],-lo[2]])+position
  for cell in cells:
   xyz=np.array(list(map(float,cell[2:5])))
   assert not (np.all(xyz+.5+margin>lower) and np.all(xyz-.5-margin<upper)),(city,key,'cell overlap',cell,lower,upper)
  # Front service aisle two nodes deep and actual trainer volume are disjoint.
  assert lower[2]>trainer_pos[2]+.4+margin,(city,key,'trainer/front clearance')
  for oldlo,oldhi in envelopes:
   assert not (np.all(oldhi+margin>lower) and np.all(oldlo-margin<upper)),(city,key,'display overlap')
  envelopes.append((lower,upper))
  result.append({'city':city,'model':key,'tier':tier,'position':position.tolist(),
                 'min':lower.tolist(),'max':upper.tolist(),'solid_cell_hits':0})
(out/'clearance.json').write_text(json.dumps({'margin_nodes':margin,'displays':result},indent=2)+'\n')
(out/'model-inputs.sha256').write_text(''.join(sha+'  '+str(path)+'\n' for path,sha in sorted(set(inputs))))
print('PASS: 24 full posed envelopes vs all emitted non-air cell cubes, other mounts and trainer/front aisle; 0.01-node margin')
