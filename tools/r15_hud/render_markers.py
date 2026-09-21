#!/usr/bin/env python3
"""Orthographic mesh bounds from the shipped OBJ vertices; not a GUI capture."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
root=Path(__file__).resolve().parents[2]
font=ImageFont.truetype('/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf',16)
image=Image.new('RGB',(900,470),'#24313a');draw=ImageDraw.Draw(image)
def y(world):return 60+(2.8-world)*320
for column,symbol in enumerate(('question','exclamation')):
    base=column*450
    draw.text((base+20,15),symbol+' — actual OBJ projection',font=font,fill='white')
    for height,label in [(2.754,'fixed top: 2.754'),(2.334,'new bottom: 2.334'),(2.0,'name anchor: 2.0')]:
        draw.line((base+15,y(height),base+430,y(height)),fill='#617480')
        draw.text((base+18,y(height)+2),label,font=font,fill='#a4b5bf')
    vertices=[];faces=[]
    for line in (root/f'mods/PLAYER/grug_quests/models/grug_quests_{symbol}.obj').read_text().splitlines():
        if line.startswith('v '):vertices.append(tuple(map(float,line.split()[1:])))
        elif line.startswith('f '):faces.append([int(v)-1 for v in line.split()[1:]])
    for x,scale,attach,label in [(base+240,1,27,'before'),(base+350,5,24.84,'5×')]:
        for face in faces:
            if all(vertices[i][2]==-0.07 for i in face):
                draw.polygon([(x+vertices[i][0]*scale/10*320,y((attach+vertices[i][1]*scale)/10)) for i in face],fill='#ffd700')
        draw.text((x-20,350),label,font=font,fill='white')
draw.text((20,414),'World heights above NPC origin; current quest NPC parent scale = 1.',font=font,fill='white')
draw.text((20,438),'Parent scaling multiplies both bounds equally. GUI nametag overlap still needs playtest.',font=font,fill='#a4b5bf')
image.save(root/'tools/r15_hud/gallery/marker-bounds.png')
