#!/usr/bin/env python3
"""Move both Dawnmere inn beds inside and restore their overwritten rear wall."""
from pathlib import Path
import hashlib
import json
import sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/building_templates/editor'))
import serve as E
name='dawnmere_harvest_inn'
editor=E.Editor(ROOT)
path=Path(editor.path_of(name))
snapshot=HERE/'before'/path.name
snapshot.parent.mkdir(exist_ok=True)
if not snapshot.exists():snapshot.write_bytes(path.read_bytes())
m=E.tplfile.load(path.read_text(),str(path))
old=E.tplfile.load(snapshot.read_text(),str(snapshot))
def get(model,x,y,z):return model.layers[y-model.origin[1]][z-model.origin[2]][x-model.origin[0]]
def put(x,y,z,k):
 yy,zz,xx=y-m.origin[1],z-m.origin[2],x-m.origin[0]
 row=m.layers[yy][zz];m.layers[yy][zz]=row[:xx]+k+row[xx+1:]
legend=dict(m.legend)
for x in (1,3):
 assert dict(old.legend)[get(old,x,1,13)]=='role bed variant=_bottom'
 assert dict(old.legend)[get(old,x,1,14)]=='role bed variant=_top'
 assert get(old,x,1,12)=='.'
 put(x,1,12,get(old,x,1,13))
 put(x,1,13,get(old,x,1,14))
 # x=1 belongs to the vertical window frame (as x=4/5/8 on this wall).
 # x=3 lies below glazing and takes the same low accent course as x=2/6/7.
 restore=get(old,1,2,14) if x==1 else get(old,2,1,14)
 assert dict(old.legend)[restore]==('role window_frame' if x==1 else 'role wall_accent')
 put(x,1,14,restore)
body={'name':name,'hash':E.sha(path.read_bytes()),'cell':m.cell,'legend':m.legend,'layers':m.layers,'points':[[x,y,z] for _,x,y,z,_ in m.points],'confirm':True}
_,_,_,text=editor.edited_text(body)
if path.read_text()==text:
 print('Already installed; editor Save not repeated.')
else:
 # First save must build on the actual initial file, preserving concurrent
 # changes by refusing a stale source. Later table edits are independent.
 assert path.read_bytes()==snapshot.read_bytes(),'Template changed; reload and coordinate with its other editor.'
 result=editor.save(body)
 (HERE/'save-report.json').write_text(json.dumps({'template':str(path.relative_to(ROOT)),'before_sha256':E.sha(snapshot.read_bytes()),'after_sha256':E.sha(path.read_bytes()),'result':result},indent=2)+'\n')
 print('Two beds shifted inwards; six cells saved through the editor validator.')
