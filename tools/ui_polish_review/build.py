#!/usr/bin/env python3
"""Package the local UI proposal board from immutable client evidence."""
from pathlib import Path
import argparse, json, re, runpy, shutil
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parent
GAME=ROOT.parents[1]
CAP=Path('/home/jan/projects/grudgelands-orchestration/ui-modernization/dialogs-2026-10-25/final')
OUT=ROOT/'dist'

def crop_box(im):
 a=np.asarray(im.convert('RGB')).astype(int); r,g,b=a[:,:,0],a[:,:,1],a[:,:,2]
 mask=(r<42)&(g>r+3)&(b>=g)&(b<57)
 ys=np.where(mask.sum(axis=1)>im.width*.15)[0]
 if not len(ys): return (0,0,im.width,im.height)
 y0,y1=int(ys[0]),int(ys[-1])+1
 xs=np.where(mask[y0:y1].sum(axis=0)>(y1-y0)*.35)[0]
 if not len(xs): return (0,0,im.width,im.height)
 return(max(0,int(xs[0])-8),max(0,y0-8),min(im.width,int(xs[-1])+9),min(im.height,y1+8))

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--captures',type=Path,default=CAP,help='Immutable three-resolution client capture directory')
 args=parser.parse_args(); CAP=args.captures
 if not CAP.is_dir(): parser.error('Capture archive is missing: '+str(CAP))
 (OUT/'shots').mkdir(parents=True,exist_ok=True); (OUT/'assets').mkdir(exist_ok=True); (OUT/'evidence').mkdir(exist_ok=True)
 captures={}
 for resolution in ['1035x696','1600x900','2560x1440']:
  captures[resolution]={}; (OUT/'shots'/resolution).mkdir(exist_ok=True)
  for p in sorted((CAP/resolution).glob('dark_*.png')):
   key=p.stem[5:]; im=Image.open(p).convert('RGB'); box=crop_box(im)
   im.save(OUT/'shots'/resolution/f'{key}.webp',lossless=True)
   im.crop(box).save(OUT/'shots'/resolution/f'{key}-focus.webp',lossless=True)
   captures[resolution][key]={'box':box,'size':im.size}
   if resolution=='1600x900':
    source=CAP/resolution/f'ui_capture_dark_{key}.txt'
    shutil.copyfile(source,OUT/'evidence'/f'{key}.txt')
 # Expose true native art as retained regions, never invent substitute trees/maps.
 for key,rect in {'talents':(.02,.18,.98,.60),'stats':(.05,.21,.43,.55),'map':(.01,.19,.43,.86),'map_zones':(.01,.19,.43,.86)}.items():
  im=Image.open(OUT/'shots/1600x900'/f'{key}-focus.webp'); w,h=im.size
  im.crop(tuple(int(v*(w if i%2==0 else h)) for i,v in enumerate(rect))).save(OUT/'assets'/f'native-{key}.webp',lossless=True)
 textures=['default_wood.png','default_cobble.png','default_coal_lump.png','default_stick.png','default_apple.png','default_paper.png','default_book.png','default_torch_on_floor.png','default_steel_ingot.png','grug_gear_item_sword_steel.png','grug_ui_icon_emblem.png','grug_mounts_icon_t1_accord.png','grug_mounts_icon_boat.png']
 texture_map={p.name:p for p in GAME.glob('mods/**/textures/*.png')}
 for t in textures:
  if t in texture_map: shutil.copyfile(texture_map[t],OUT/'assets'/t)
 # Full rendered text is read-only evidence for the proposal, including existing help prose.
 evidence={}
 for p in (OUT/'evidence').glob('*.txt'):
  s=p.read_text(); evidence[p.stem]={'form':s.split('\n',1)[0], 'controls':re.findall(r'(?:button(?:_exit)?|checkbox|dropdown|field|list|textlist)\[(?:\\.|[^\]])*\]',s)}
 (OUT/'evidence.js').write_text('window.EVIDENCE='+json.dumps(evidence,ensure_ascii=False)+';')
 (OUT/'captures.json').write_text(json.dumps(captures,indent=2))
 from content import PAGES
 (OUT/'content.js').write_text('window.PAGES='+json.dumps(PAGES,ensure_ascii=False)+';')
 for source in (ROOT/'src').iterdir(): shutil.copyfile(source,OUT/source.name)
 runpy.run_path(str(ROOT/'assets.py'),run_name='__main__')
 runpy.run_path(str(ROOT/'revision_assets.py'),run_name='__main__')
 expected={p['id'] for p in PAGES}
 for resolution,shots in captures.items():
  if set(shots)!=expected: raise ValueError('Capture census mismatch: '+resolution)
 print('Packaged',sum(len(v) for v in captures.values()),'actual client captures.')
