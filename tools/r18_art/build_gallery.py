#!/usr/bin/env python3
"""Package generated PNGs and build illustrative review sheets (not GUI captures)."""
import hashlib
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
TEX = ROOT / 'mods/PLAYER/grug_abilities/textures'
manifest = json.loads((HERE / 'manifest.json').read_text())
for asset in manifest['assets']:
    target = TEX / asset['file']
    if not target.exists():
        Image.open(asset['source']).convert('RGB').resize((64, 64), Image.Resampling.LANCZOS).save(target)
    asset['sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()
(HERE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
# Before is an illustrative reconstruction of the old color-orb + weapon scheme.
colors = {}
for source in ('kits.lua', 'scout.lua'):
    text = (ROOT / 'mods/PLAYER/grug_abilities' / source).read_text()
    for part in text.split('grug_abilities.register_ability({')[1:]:
        aid = re.search(r'id\s*=\s*"([^"]+)"', part)
        col = re.search(r'color\s*=\s*"(#[0-9a-fA-F]+)"', part)
        if aid and col:
            colors[aid[1]] = col[1]
scout = {'loose','snare_shot','sidestep','sprint','pinning_shot','opening'}
warrior = {'strike','charge','mighty_blow','hamstring','taunt','hold_ground'}
gear = ROOT / 'mods/ITEMS/grug_gear/textures'
def before(aid):
    orb = Image.open(TEX / 'grug_abilities_orb.png').convert('RGBA').resize((32,32),Image.Resampling.NEAREST)
    col = colors.get(aid, '#ffffff'); rgb = tuple(int(col[i:i+2],16) for i in (1,3,5))
    orb.putdata([(r*rgb[0]//255,g*rgb[1]//255,b*rgb[2]//255,a*150//255) for r,g,b,a in orb.getdata()])
    weapon = 'grug_gear_bow_wood.png' if aid in scout else ('grug_gear_item_sword_iron.png' if aid in warrior else 'grug_gear_item_staff_wood.png')
    w = Image.open(gear / weapon).convert('RGBA').resize((32,32),Image.Resampling.NEAREST)
    orb.alpha_composite(w)
    return orb
sheet = Image.new('RGB',(1200,1160),'#232630'); draw = ImageDraw.Draw(sheet)
draw.text((16,12),'R18 active-skill art | illustrative reconstruction, NOT live GUI | before / 32px normal / cooldown / charge / 128px',fill='white')
for i,a in enumerate(manifest['assets']):
    x = 16 + (i % 4)*300; y = 45 + (i//4)*184
    draw.text((x,y),a['id'],fill='white')
    icon = Image.open(TEX/a['file']).convert('RGBA')
    b = before(a['id']); sheet.paste(b,(x,y+20),b)
    tiny = icon.resize((32,32),Image.Resampling.LANCZOS)
    for j in range(3):
        state = tiny.copy()
        if j:
            d=ImageDraw.Draw(state); d.rectangle((2,28,29,30),fill='#050505')
            d.rectangle((2,28,15 if j==1 else 23,30),fill='#e6c540' if j==1 else '#79db62')
        sheet.paste(state,(x+40*(j+1),y+20),state)
    sheet.paste(icon.resize((128,128),Image.Resampling.NEAREST),(x+160,y+20))
    draw.text((x,y+61),'old   ready  CD    charge',fill='#bfc4d0')
    draw.text((x,y+79),'32px, illustrative bars',fill='#a8adba')
sheet.save(HERE/'contact-sheet.png')
html=['<!doctype html><meta charset="utf-8"><title>R18 skill icon review</title><style>body{background:#232630;color:#eee;font:16px sans-serif}img{image-rendering:pixelated}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:20px}article{background:#30343e;padding:12px}.small{width:32px;height:32px}.large{width:128px;height:128px;margin:12px}</style><h1>R18 skill icon review</h1><p>Actual 32 CSS pixels and 128 pixels. Browser zoom 100%. Contact sheet includes illustrative before and wear-bar states; these are not live GUI captures.</p><a href="contact-sheet.png">Before / after / cooldown / charge sheet</a><div class="grid">']
for a in manifest['assets']:
    src='../../mods/PLAYER/grug_abilities/textures/'+a['file']
    html.append(f'<article><strong>{a["id"]}</strong><br><img class="small" src="{src}"><img class="large" src="{src}"></article>')
html.append('</div>'); (HERE/'gallery.html').write_text('\n'.join(html))
print('Packaged',len(manifest['assets']),'64x64 PNGs; gallery:',HERE/'gallery.html')
