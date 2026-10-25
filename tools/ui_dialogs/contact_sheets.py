#!/usr/bin/env python3
"""Downsample real-client frames for visual inspection; originals stay intact."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import sys
root=Path(sys.argv[1]); out=Path(sys.argv[2]); out.mkdir(parents=True,exist_ok=True)
files=sorted(root.glob('*.png'))
font=ImageFont.truetype('/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf',17)
for start in range(0,len(files),6):
    group=files[start:start+6]; tiles=[]
    for path in group:
        im=Image.open(path).convert('RGB'); im.thumbnail((720,500))
        tile=Image.new('RGB',(740,530),'#202426');tile.paste(im,((740-im.width)//2,28))
        ImageDraw.Draw(tile).text((10,5),path.stem,fill='#eeeae1',font=font)
        tiles.append(tile)
    sheet=Image.new('RGB',(1480,1590),'#202426')
    for i,t in enumerate(tiles):sheet.paste(t,((i%2)*740,(i//2)*530))
    sheet.save(out/f'{root.name}-{start//6+1:02}.jpg',quality=90)
