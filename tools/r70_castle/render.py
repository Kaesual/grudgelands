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
import light

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('raster',HERE.parent/'r69_camp_art/render.py')
R=importlib.util.module_from_spec(spec);spec.loader.exec_module(R)
R.BG=(169,184,182)
R.VIEWS={'approach':((82,58,-62),(22,12,17)),
         'hall':((22,4.125,9),(22,8,29)),
         'night':((22,4.125,9),(22,8,29)),
         'entrance':((22,4.125,3),(22,6,15)),
         'throne':((27,9,22),(22,9,29)),
         'top':((22,90,16.999),(22,0,17))}
FORMS=('crownward','high_seat','gate_crown')

def render(meshes, textures, view, width=1200, height=900, bank=None):
    # 1.5x supersampling makes thin rope and scaffold rails readable in the overview.
    w,h = width*3//2,height*3//2
    eye,target = map(lambda v:np.array(v,dtype=float), R.VIEWS[view])
    forward = target-eye; forward /= np.linalg.norm(forward)
    right = np.cross([0.,1.,0.],forward); right /= np.linalg.norm(right)
    up = np.cross(forward,right)
    fov=70 if view in ('hall','night','entrance','throne') else 42
    f = h/(2*math.tan(math.radians(fov)/2))
    depth = np.full((h,w),np.inf)
    color = np.zeros((h,w,3),dtype=np.float32)+(R.BG if bank is None else (0,0,0))
    for m in meshes:
        pos=np.asarray(m['position']).reshape(-1,3)
        uv=np.asarray(m['uv']).reshape(-1,2)
        shade=np.asarray(m['color']).reshape(-1,3)[:,0]
        indices=np.asarray(m['index']).reshape(-1,3)
        rel=pos-eye
        z=rel@forward
        # Triangles crossing the near plane are discarded below. Their vertices
        # may lie on the camera plane; avoid meaningless division warnings.
        divisor=np.where(np.abs(z)<1e-10,1e-10,z)
        screen=np.column_stack((w/2+f*(rel@right)/divisor,h/2-f*(rel@up)/divisor))
        tex=textures[m['texture']]
        for idx in indices:
            points=pos[idx]
            if not m['double'] and np.dot(np.cross(points[1]-points[0],points[2]-points[0]),eye-points.mean(axis=0))<=0:
                continue
            if z[idx].min()<=.05:
                continue
            lighting=shade[idx]
            if bank is not None:
                # Sample just outside each face, nudged toward its centre so
                # cube corners don't accidentally sample the next opaque node.
                normal=np.cross(points[1]-points[0],points[2]-points[0])
                norm=np.linalg.norm(normal)
                if norm<=1e-10: continue
                normal/=norm
                centre=points.mean(axis=0)
                samples=points*.999+centre*.001+normal*.01
                levels=[bank.get(tuple(np.floor(q+.5).astype(int)),0) for q in samples]
                lighting=lighting*np.array([light.linear_brightness(v) for v in levels])
            R.raster(color,depth,screen[idx],z[idx],uv[idx],lighting,tex)
    return Image.fromarray(np.uint8(np.clip(color+.5,0,255))).resize((width,height),Image.Resampling.LANCZOS)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--form',choices=FORMS);ap.add_argument('--race',default='human',choices=('dwarf','human','elf','orc','undead','troll'))
    a=ap.parse_args()
    for form in (a.form,) if a.form else FORMS:
        key=a.race+'/'+form
        payload=json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',(HERE/'page.html').read_text(),re.S)[1])
        receipt={'inputs':render_digest(payload,key),'files':{}}
        bank=light.propagate(light.decode_scene(payload,key),payload['light_nodes'])
        data=json.loads(subprocess.check_output(['node',str(HERE/'geometry.js'),key,key+'@14'],text=True))
        textures=[np.asarray(Image.open(io.BytesIO(base64.b64decode(t.split(',',1)[1]))).convert('RGBA')) for t in data['textures']]
        for view in R.VIEWS:
            target=HERE/'renders'/f'{form}_{a.race}_{view}.png';target.parent.mkdir(exist_ok=True)
            render(data['scenes'][key+('@14' if view=='top' else '')],textures,view,1200,900,
                   bank if view=='night' else None).save(target,optimize=True)
            receipt['files'][target.name]=hashlib.sha256(target.read_bytes()).hexdigest()
            print(target.relative_to(HERE),flush=True)
        (HERE/'renders'/f'{form}_{a.race}.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')

if __name__=='__main__':main()
