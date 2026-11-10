#!/usr/bin/env python3
"""Install the approved arch orientation through the real template editor save path."""
import hashlib,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/building_templates/editor'))
import serve
T=serve.T
NAMES=[city+'_gate_south' for city in ('highcourt','dur_brannoc','lethariel','gor_drazhak','nhal_veyr')]
def digest(b):return hashlib.sha256(b).hexdigest()

def main():
 editor=serve.Editor(ROOT)
 audit=json.loads((HERE/'save-audit.json').read_text()) if (HERE/'save-audit.json').exists() else {}
 for name in NAMES:
  path=Path(editor.path_of(name));old=path.read_bytes();model=serve.tplfile.load(old.decode(),str(path))
  before=T.parse_template(str(path))
  entries={k:text for k,text in model.legend}
  assert entries['H']=='role castle_wall_stair o=facedir:1 else=air'
  assert entries.get('I','role castle_wall_stair o=facedir:3 else=air')=='role castle_wall_stair o=facedir:3 else=air'
  expected={(x,5,z) for x in (4,8) for z in range(7)}
  if 'V' in entries:
   assert entries['V']=='role castle_wall_stair o=facedir:21 else=air'
   assert entries['W']=='role castle_wall_stair o=facedir:23 else=air'
   assert all(before.cells[x,y,z]==('V' if x==4 else 'W') for x,y,z in expected)
   baseline=HERE/'before'/(name+'.tpl')
   original=T.parse_template(str(baseline))
   changed={p for p in original.cells if original.cells[p]!=before.cells[p]}
   assert changed==expected
   assert [{k:v for k,v in q.items() if k!='line'} for q in original.points]==[{k:v for k,v in q.items() if k!='line'} for q in before.points]
   audit.setdefault(name,{'source_sha256':digest(baseline.read_bytes()),'output_sha256':digest(old),'changed_cells':14,'positions':sorted(expected),'editor_save':{'saved':True,'note':'Previous editor.save completed; post-save comparison initially counted source line offsets. Verified semantics without repeating validator.'}})
   (HERE/'save-audit.json').write_text(json.dumps(audit,indent=2)+'\n')
   print(name+': already installed; no validator repeated',flush=True)
   continue
  snapshots=HERE/'before';snapshots.mkdir(exist_ok=True)
  snapshot=snapshots/(name+'.tpl')
  if snapshot.exists():assert snapshot.read_bytes()==old
  else:snapshot.write_bytes(old)
  assert 'V' not in entries and 'W' not in entries
  model.legend.extend([['V','role castle_wall_stair o=facedir:21 else=air'],['W','role castle_wall_stair o=facedir:23 else=air']])
  for x,y,z in expected:
   assert before.cells[x,y,z]==('H' if x==4 else 'I')
   row=model.layers[y-model.origin[1]][z-model.origin[2]]
   i=x-model.origin[0]
   model.layers[y-model.origin[1]][z-model.origin[2]]=row[:i]+('V' if x==4 else 'W')+row[i+1:]
  body={'name':name,'hash':digest(old),'cell':model.cell,'legend':model.legend,'layers':model.layers,'points':[[p[1],p[2],p[3]] for p in model.points],'confirm':True}
  print(name+': editor save and validator',flush=True)
  result=editor.save(body)
  assert not result['errors'],result
  after=T.parse_template(str(path))
  assert [{k:v for k,v in q.items() if k!='line'} for q in before.points]==[{k:v for k,v in q.items() if k!='line'} for q in after.points]
  changed={p for p in before.cells if before.cells[p]!=after.cells[p]}
  assert changed==expected,changed^expected
  assert all(after.legend[k]['text']==v['text'] for k,v in before.legend.items() if k in after.legend)
  assert before.size==after.size and before.origin==after.origin and before.pivot==after.pivot
  audit[name]={'source_sha256':digest(old),'output_sha256':digest(path.read_bytes()),'changed_cells':14,'positions':sorted(expected),'editor_save':result}
  (HERE/'save-audit.json').write_text(json.dumps(audit,indent=2)+'\n')
  print(name+': saved, exactly14 oriented nodes; points/box retained',flush=True)
if __name__=='__main__':main()
