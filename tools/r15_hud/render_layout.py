#!/usr/bin/env python3
"""Schematic of actual fixture HUD definitions; not an engine screenshot."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
source = Path(sys.argv[1])
out = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
for w,h,s in [(1280,720,1),(1000,750,1.25),(640,480,1)]:
    rows = [line.split('\t') for line in (source/f'layout-{w}x{h}-scale{s}.tsv').read_text().splitlines()]
    image=Image.new('RGB',(w,h),'#24313a');draw=ImageDraw.Draw(image)
    font=ImageFont.truetype('/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf',round(15*s))
    draw.text((12,10),'LAYOUT SCHEMATIC — engine font/rendering needs GUI check',fill='#b3bcc1',font=font)
    for row in rows:
        kind,px,py,ox,oy,ax,ay,sx,sy,color,text=row
        x=float(px)*w+float(ox)*s;y=float(py)*h+float(oy)*s
        ax=float(ax);ay=float(ay)
        if kind=='image':
            width=float(sx)*s;height=float(sy)*s
            if width<=0 or not text:continue
            x+=(ax-1)*width/2;y+=(ay-1)*height/2
            tint='#'+text.split('#')[-1].split(':')[0]
            draw.rectangle((x,y,x+width,y+height),fill=tint)
        elif text:
            lines=text.split('\\n');line_height=18*s
            y+=(ay-1)*len(lines)*line_height/2
            for line in lines:
                width=draw.textlength(line,font=font)
                draw.text((x+(ax-1)*width/2,y),line,font=font,fill=f'#{int(color):06x}')
                y+=line_height
    # Shared stack context, labelled; these are schematic neighbours.
    for middle,label in [(-92,'Mana / Rage'),(-112,'Life'),(-132,'Breath'),(-154,'Skill'),(-176,'Money')]:
        x=w/2;y=h+middle*s
        if middle>=-132:
            draw.rectangle((x-90*s,y-8*s,x+90*s,y+8*s),outline='#758c99')
        draw.text((x,y),label,font=font,fill='#b3bcc1',anchor='mm')
    draw.rectangle((w/2-224*s,h-62*s,w/2+224*s,h-4*s),outline='#ac9772')
    draw.text((w/2,h-32*s),'HOTBAR',font=font,fill='#ac9772',anchor='mm')
    draw.line((w/2-6,h/2,w/2+6,h/2),fill='#b3bcc1')
    draw.line((w/2,h/2-6,w/2,h/2+6),fill='#b3bcc1')
    image.save(out/f'layout-{w}x{h}-scale{s}.png')
