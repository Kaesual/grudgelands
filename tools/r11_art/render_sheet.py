#!/usr/bin/env python3
"""Render the actual stored R11 ART inventory media into one review sheet."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else ".").resolve()
out=Path(sys.argv[2] if len(sys.argv)>2 else "/tmp/r11-art-sheet.png")
rows=[]
def add(label,path,treatment=None):
 im=Image.open(root/path).convert("RGBA")
 if treatment == "iron":
  alpha=im.getchannel("A")
  im=ImageEnhance.Color(im).enhance(0.0)
  im=ImageEnhance.Brightness(im).enhance(0.88)
  im.putalpha(alpha)
 elif treatment == "embersteel":
  alpha=im.getchannel("A")
  grade=Image.new("RGBA",im.size,(159,36,24,255))
  im=Image.blend(im,grade,112/255)
  im.putalpha(alpha)
 rows.append((label,im))
gear=Path("mods/ITEMS/grug_gear/textures")
for label,file in [("Starter","grug_gear_bow_wood.png"),("Bronze","grug_gear_bow_lebethron.png"),
 ("Iron/Steel/Abyssal","grug_gear_bow_birch.png"),("Silversteel","grug_gear_bow_mallorn.png"),
 ("Embersteel","grug_gear_bow_alder.png")]:add("Bow "+label,gear/file)
for material in ("bronze","iron","steel","silversteel","embersteel","abyssal_steel"):
 treatment=material if material in ("iron","embersteel") else None
 suffix=" (runtime grade)" if treatment else ""
 add("Shield "+material+suffix,gear/("grug_gear_shield_"+material+".png"),treatment)
add("Spellbook",gear/"grug_gear_spellbook.png");add("Arrow",gear/"grug_gear_arrow.png")
inv=Path("mods/PLAYER/grug_inventory/textures")
for size in ("small","medium","large"):add("Bag "+size,inv/("grug_inventory_bag_"+size+".png"))
q=Image.open(root/inv/"grug_inventory_quiver.png").convert("RGBA").resize((64,64),Image.Resampling.LANCZOS)
rows.append(("Quiver runtime 64px",q))
farm=Path("mods/ITEMS/grug_farming/textures")
for seed in ("barley","beetroot","carrot","corn","cotton","melon","potato","pumpkin","strawberry"):
 add("Seed "+seed,farm/("grug_farming_seed_"+seed+".png"))
scale=8; cellw,cellh=196,154; cols=5
sheet=Image.new("RGBA",(cols*cellw,((len(rows)+cols-1)//cols)*cellh),(34,36,42,255))
d=ImageDraw.Draw(sheet)
for i,(label,im) in enumerate(rows):
 x=(i%cols)*cellw;y=(i//cols)*cellh
 if im.width <= 64 and im.height <= 64:
  im=im.resize((im.width*6,im.height*6),Image.Resampling.NEAREST)
 im.thumbnail((112,112),Image.Resampling.NEAREST)
 sheet.alpha_composite(im,(x+(cellw-im.width)//2,y+8))
 d.text((x+8,y+124),label,fill=(238,238,238,255))
out.parent.mkdir(parents=True,exist_ok=True);sheet.convert("RGB").save(out,optimize=True)
print(out)
