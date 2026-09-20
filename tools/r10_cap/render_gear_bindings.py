#!/usr/bin/env python3
"""Label real registered item art used by the immutable authored display entities.
This contact sheet proves item/texture binding, not engine wielditem extrusion.
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw
scratch=Path(sys.argv[1])
gear=json.loads((scratch/'gear-visuals.json').read_text())
canvas=Image.new('RGB',(1050,390),'#303030');draw=ImageDraw.Draw(canvas)
draw.text((15,12),'Actual registered display item artwork (nearest-neighbour). Not an engine screenshot.',fill='white')
for index,tag in enumerate(('weapon','armor','jewel')):
 row=gear[tag];image=Image.open(row['texture']).convert('RGBA').resize((256,256),Image.Resampling.NEAREST)
 x=20+350*index;canvas.paste(image,(x+20,55),image)
 draw.text((x,325),tag+' display: '+row['item'],fill='white')
 draw.text((x,347),'Authored socket; noncollectible render entity',fill='white')
canvas.save(scratch/'gear-bindings.png')
