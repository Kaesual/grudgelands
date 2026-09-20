"""Bounded authored ground clips, integer-frame mesh bounds and yaw sweep.
Fractional-frame visual acceptance remains a GUI check; 0.1 node margin is
conservative numeric clearance, not a proof of arbitrary animation interpolation.
"""
import sys,json
from pathlib import Path
import numpy as np
repo=Path(sys.argv[1]);out=Path(sys.argv[2])
sys.path.insert(0,str(repo/'tools/r10_cap'))
from b3d_pose import evaluate
result=[]
for line in (out/'motion-catalog.tsv').read_text().splitlines():
 key,name,scale,first,last=line.split('\t');scale=float(scale)/10
 path=next((repo/'mods').rglob(name));radius=0;low=1e9;high=-1e9
 for frame in range(int(first),int(last)+1):
  model=evaluate(path,frame)
  verts=np.array([v for m in model['meshes'] for v in m['vertices']])*scale
  radius=max(radius,float(np.sqrt(verts[:,0]**2+verts[:,2]**2).max()))
  low=min(low,float(verts[:,1].min()));high=max(high,float(verts[:,1].max()))
 result.append(dict(model=key,frames=int(last)-int(first)+1,radius=radius,min_y=low,max_y=high))
(out/'motion-bounds.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
