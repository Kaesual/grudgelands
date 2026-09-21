#!/usr/bin/env python3
"""Original compass triangles, drawn from polygons; no imported image assets."""
from pathlib import Path
import math
from PIL import Image, ImageDraw
out=Path(__file__).resolve().parents[2]/'mods/PLAYER/grug_map/textures'
for name,color in [('gold','#ffd34f'),('cyan','#55e1ff')]:
 for frame in range(16):
  a=frame*math.tau/16
  # Yaw zero faces +z (map north); positive yaw faces map west.
  points=[]
  for x,y in [(0,-12),(8,10),(0,6),(-8,10)]:
   points.append(((16+x*math.cos(a)+y*math.sin(a))*4,
                  (16-x*math.sin(a)+y*math.cos(a))*4))
  im=Image.new('RGBA',(128,128))
  draw=ImageDraw.Draw(im)
  draw.polygon(points,fill=color)
  draw.line(points+[points[0]],fill='#19150f',width=7,joint='curve')
  im.resize((32,32),Image.Resampling.LANCZOS).save(out/f'grug_map_heading_{name}_{frame:02d}.png')
print('headings=32 original 32x32 RGBA')
