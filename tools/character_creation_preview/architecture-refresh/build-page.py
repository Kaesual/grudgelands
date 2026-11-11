#!/usr/bin/env python3
"""Create the local native-camera comparison and opening-logo UI proposal."""
import base64
import hashlib
import json
from pathlib import Path
import re
import struct
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
RACES={'human':'Menschen','dwarf':'Zwerge','elf':'Elfen','orc':'Orcs','troll':'Trolle','undead':'Untote'}

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def payload(p): return json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',p.read_text(),re.S)[1])
def cells(data,race):
    return {(x,y,z):(data['types'][t]['name'],p2) for x,y,z,t,p2 in struct.iter_unpack('<hhhHB',base64.b64decode(data['scenes'][race]['cells']))}
old=payload(HERE.parent/'native/scenes.html'); new=payload(HERE/'native/scenes.html')
build=json.loads((HERE/'native/scene-build.json').read_text())
audit={}
for race,label in RACES.items():
    a,b=cells(old,race),cells(new,race)
    spec=json.loads((HERE/'native/scenes'/f'{race}.json').read_text())
    before_spec=json.loads((HERE.parent/'native/scenes'/f'{race}.json').read_text())
    assert spec==before_spec,race
    image=HERE/'native/renders'/f'{race}.png'
    receipt=json.loads(image.with_suffix('.json').read_text())
    assert receipt['input']==build[race]['render_input'] and receipt['output']==sha(image)
    assert (receipt['width'],receipt['height'])==(1540,1400)
    audit[race]=dict(label=label,changed_cells=sum(a.get(p)!=b.get(p) for p in a.keys()|b.keys()),cells=len(b),
                    removed_cells=len(a.keys()-b.keys()),added_cells=len(b.keys()-a.keys()),
                    camera_unchanged=True,scene_recipe_unchanged=True,templates=[b['template'] for b in spec['buildings']],
                    old_image_sha256=sha(HERE.parent/'native/renders'/f'{race}.png'),new_image_sha256=sha(image))
(HERE/'comparison.json').write_text(json.dumps(audit,indent=2)+'\n')
page=(HERE/'page.html.in').read_text().replace('__DATA__',json.dumps(audit,ensure_ascii=False))
(HERE/'index.html').write_text(page)
print(json.dumps({r:a['changed_cells'] for r,a in audit.items()}))
