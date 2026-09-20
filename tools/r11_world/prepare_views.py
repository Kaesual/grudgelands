#!/usr/bin/env python3
"""Resolve current emitted cells and real node textures for Blender evidence."""
import json
import sys
from pathlib import Path
repo=Path(sys.argv[1]);scratch=Path(sys.argv[2]);sys.path.insert(0,str(repo/'tools/wp13'))
from render_blueprint import TextureBank,node_boxes
bank=TextureBank(str(repo/'tools/wp13/node_tiles.json'),[str(repo/'mods')])
defs={}
for line in (scratch/'decor.tsv').read_text().splitlines():
 row=line.split('\t');name=row[1].lstrip(':')
 if row[0]=='node':defs[name]={'tiles':row[2].split('|'),'mesh':row[3],'drawtype':row[4],'boxes':[]}
 else:defs[name]['boxes'].append(list(map(float,row[2:])))
(scratch/'resolved').mkdir(exist_ok=True);resolved={}
def texture(spec):
 if spec not in resolved:
  import hashlib
  filename=hashlib.sha256(spec.encode()).hexdigest()+'.png'
  bank.texture(spec).save(scratch/'resolved'/filename);resolved[spec]=str(scratch/'resolved'/filename)
 return resolved[spec]
rooms={}
for line in (scratch/'all-services.tsv').read_text().splitlines():
 row=line.split('\t');key=row[0]
 if key not in ('highcourt/riding','highcourt/forge','highcourt/tailor'):continue
 room=rooms.setdefault(key,{'cells':[],'sockets':[]})
 if row[1]=='socket':room['sockets'].append(row[2:]);continue
 x,y,z=map(int,row[2:5]);name=row[5];param2=int(row[6])
 # Bounded R11 cutaways: remove the stable roof only, shop courses y>=4.
 # Keep every front product frame and all six full-height shelter posts.
 if y<0 or y>=(6 if key.endswith('/riding') else 4):continue
 definition=defs.get(name)
 if definition:
  boxes=definition['boxes'];tiles=definition['tiles'];mesh=definition['mesh']
 else:
  entry=bank.nodes.get(name,{})
  tiles=entry.get('tiles',[]);mesh='-'
  if not tiles and name.startswith('wool:'):tiles=['wool_'+name.split(':')[1]+'.png']
  if not tiles:raise ValueError('unresolved actual node '+name)
  boxes=[[v-.5 for v in box] for box,_ in node_boxes(entry.get('shape','cube'),param2,15)]
 room['cells'].append({'pos':[x,y,z],'boxes':boxes,'tiles':[texture(t) for t in tiles],
                       'mesh':str(repo/'mods/ITEMS/grug_decor/models'/mesh) if mesh!='-' else None})
gear={}
for line in (scratch/'gear.tsv').read_text().splitlines():
 tag,item,spec=line.split('\t');gear[tag]={'item':item,'texture':texture(spec)}
(scratch/'texture-specs.json').write_text(json.dumps(resolved,sort_keys=True,indent=2))
(scratch/'gear-visuals.json').write_text(json.dumps(gear))
(scratch/'rooms.json').write_text(json.dumps(rooms));print(len(rooms),'cutaway rooms; unresolved textures:',dict(bank.warnings))
