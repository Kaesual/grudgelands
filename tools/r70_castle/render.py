#!/usr/bin/env python3
"""PNG studies from the shared viewer geometry and the R69 software rasterizer."""
import argparse
import base64
import importlib.util
import io
import hashlib
import re
import json
import math
from pathlib import Path
import subprocess
import numpy as np
from PIL import Image
from build import render_digest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('raster',HERE.parent/'r69_camp_art/render.py')
R=importlib.util.module_from_spec(spec);spec.loader.exec_module(R)
R.BG=(169,184,182)
R.VIEWS={'approach':((82,58,-62),(22,12,17)),
         'hall':((22,4.125,9),(22,8,29)),
         'top':((22,90,16.999),(22,0,17))}
FORMS=('crownward','high_seat','gate_crown')

def render(meshes, textures, view, width=1200, height=900):
    # 1.5x supersampling makes thin rope and scaffold rails readable in the overview.
    w,h = width*3//2,height*3//2
    eye,target = map(lambda v:np.array(v,dtype=float), R.VIEWS[view])
    forward = target-eye; forward /= np.linalg.norm(forward)
    right = np.cross([0.,1.,0.],forward); right /= np.linalg.norm(right)
    up = np.cross(forward,right)
    f = h/(2*math.tan(math.radians(70 if view=='hall' else 42)/2))
    depth = np.full((h,w),np.inf)
    color = np.zeros((h,w,3),dtype=np.float32)+R.BG
    for m in meshes:
        pos=np.asarray(m['position']).reshape(-1,3)
        uv=np.asarray(m['uv']).reshape(-1,2)
        shade=np.asarray(m['color']).reshape(-1,3)[:,0]
        indices=np.asarray(m['index']).reshape(-1,3)
        rel=pos-eye
        z=rel@forward
        screen=np.column_stack((w/2+f*(rel@right)/z,h/2-f*(rel@up)/z))
        tex=textures[m['texture']]
        for idx in indices:
            points=pos[idx]
            if not m['double'] and np.dot(np.cross(points[1]-points[0],points[2]-points[0]),eye-points.mean(axis=0))<=0:
                continue
            if z[idx].min()<=.05:
                continue
            R.raster(color,depth,screen[idx],z[idx],uv[idx],shade[idx],tex)
    return Image.fromarray(np.uint8(np.clip(color+.5,0,255))).resize((width,height),Image.Resampling.LANCZOS)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--form',choices=FORMS);ap.add_argument('--race',default='human',choices=('dwarf','human','elf','orc','undead','troll'))
    a=ap.parse_args()
    for form in (a.form,) if a.form else FORMS:
        key=a.race+'/'+form
        payload=json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',(HERE/'page.html').read_text(),re.S)[1])
        receipt={'inputs':render_digest(payload,key),'files':{}}
        data=json.loads(subprocess.check_output(['node',str(HERE/'geometry.js'),key,key+'@14'],text=True))
        textures=[np.asarray(Image.open(io.BytesIO(base64.b64decode(t.split(',',1)[1]))).convert('RGBA')) for t in data['textures']]
        for view in R.VIEWS:
            target=HERE/'renders'/f'{form}_{a.race}_{view}.png';target.parent.mkdir(exist_ok=True)
            render(data['scenes'][key+('@14' if view=='top' else '')],textures,view,1200,900).save(target,optimize=True)
            receipt['files'][target.name]=hashlib.sha256(target.read_bytes()).hexdigest()
            print(target.relative_to(HERE),flush=True)
        (HERE/'renders'/f'{form}_{a.race}.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')

if __name__=='__main__':main()
