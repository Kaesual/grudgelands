#!/usr/bin/env python3
"""Render candidate templates through the shared viewer's triangles, with no GUI.

Node.js executes only the existing geometry builder; Pillow/numpy rasterize
its textured triangles with a depth buffer, alpha clipping, UV repeat and
interpolated vertex shading. No browser, server or game process is launched.
"""
import argparse
import base64
import io
import json
import math
from pathlib import Path
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
VARIANTS = ('wallwright', 'first_lift', 'panel_yard')
VIEWS = {'gate': ((27,23,-32),(0,2,0)), 'rear': ((-28,24,32),(0,2,0)),
         'top': ((0,40,-.001),(0,0,0))}
BG = (183,194,188)


def raster(color, depth, screen, z, uv, shade, texture):
    h,w = depth.shape
    x0,x1 = max(0,math.floor(screen[:,0].min())), min(w-1,math.ceil(screen[:,0].max()))
    y0,y1 = max(0,math.floor(screen[:,1].min())), min(h-1,math.ceil(screen[:,1].max()))
    if x0>x1 or y0>y1:
        return
    a,b,c = screen
    area = (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    if abs(area)<1e-8:
        return
    xx = np.arange(x0,x1+1)[None,:]+.5
    yy = np.arange(y0,y1+1)[:,None]+.5
    def edge(p,q):
        return ((q[0]-p[0])*(yy-p[1])-(q[1]-p[1])*(xx-p[0]))/area
    weights = np.array([edge(b,c), edge(c,a), edge(a,b)])
    inside = np.all(weights >= -1e-7, axis=0)
    if not inside.any():
        return
    persp = weights/z[:,None,None]
    reciprocal = persp.sum(axis=0)
    zz = 1/np.where(inside,reciprocal,1)
    old = depth[y0:y1+1,x0:x1+1]
    mask = inside & (zz<old)
    if not mask.any():
        return
    u = (persp*uv[:,0,None,None]).sum(axis=0)*zz
    v = (persp*uv[:,1,None,None]).sum(axis=0)*zz
    th,tw = texture.shape[:2]
    tx = np.floor((u%1)*tw).astype(np.int64).clip(0,tw-1)
    ty = np.floor(((1-v)%1)*th).astype(np.int64).clip(0,th-1)
    sample = texture[ty,tx]
    mask &= sample[:,:,3]>=128
    if not mask.any():
        return
    light = (persp*shade[:,None,None]).sum(axis=0)*zz
    # Equivalent sRGB texture decoding, linear vertex multiplication and output encoding.
    s = sample[:,:,:3]/255.
    linear = np.where(s<=.04045,s/12.92,((s+.055)/1.055)**2.4)*np.maximum(0,light[:,:,None])
    out = np.where(linear<=.0031308,12.92*linear,1.055*np.maximum(linear,0)**(1/2.4)-.055)
    color[y0:y1+1,x0:x1+1][mask] = np.clip(out[mask]*255,0,255)
    old[mask] = zz[mask]


def render(meshes, textures, view, width=1200, height=900):
    # 1.5x supersampling makes thin rope and scaffold rails readable in the overview.
    w,h = width*3//2,height*3//2
    eye,target = map(lambda v:np.array(v,dtype=float), VIEWS[view])
    forward = target-eye; forward /= np.linalg.norm(forward)
    right = np.cross([0.,1.,0.],forward); right /= np.linalg.norm(right)
    up = np.cross(forward,right)
    f = h/(2*math.tan(math.radians(42)/2))
    depth = np.full((h,w),np.inf)
    color = np.zeros((h,w,3),dtype=np.float32)+BG
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
            raster(color,depth,screen[idx],z[idx],uv[idx],shade[idx],tex)
    return Image.fromarray(np.uint8(np.clip(color+.5,0,255))).resize((width,height),Image.Resampling.LANCZOS)


def overview():
    # Fixed fonts from Pillow keep the build independent of local desktop fonts.
    font=ImageFont.load_default(size=22)
    small=ImageFont.load_default(size=16)
    cellw,cellh=560,420
    sheet=Image.new('RGB',(3*cellw,6*(cellh+66)+110),(23,29,28))
    d=ImageDraw.Draw(sheet)
    d.text((24,18),'GRUDGELANDS / CAMP SITES UNDER CONSTRUCTION',font=font,fill=(235,219,181))
    for i,label in enumerate(('GATE QUARTER','FAR SIDE','PLAN')):
        d.text((i*cellw+24,72),label,font=small,fill=(179,188,177))
    for race_idx,race in enumerate(('human','orc')):
        for vi,variant in enumerate(VARIANTS):
            row=race_idx*3+vi
            y=110+row*(cellh+66)
            label=f'{"ABC"[vi]} / {variant.replace("_"," ").title()}   |   {"The Accord / Human" if race=="human" else "The Throng / Orc"}'
            if variant=='first_lift':label+='   / RECOMMENDED'
            d.text((24,y+18),label,font=small,fill=(235,219,181))
            for i,view in enumerate(VIEWS):
                image=Image.open(HERE/'renders'/f'{variant}_{race}_{view}.png')
                sheet.paste(image.resize((cellw,cellh),Image.Resampling.LANCZOS),(i*cellw,y+58))
    sheet.save(HERE/'renders/overview.png',optimize=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--race',choices=('human','orc','all'),default='all')
    ap.add_argument('--variant',choices=VARIANTS)
    ap.add_argument('--no-overview',action='store_true',help='For independent parallel variant renders')
    args=ap.parse_args()
    races=('human','orc') if args.race=='all' else (args.race,)
    variants=(args.variant,) if args.variant else VARIANTS
    keys=[r+'/'+v for r in races for v in variants]
    data=json.loads(subprocess.check_output(['node',str(HERE/'geometry.js'),*keys],text=True))
    textures=[np.asarray(Image.open(io.BytesIO(base64.b64decode(t.split(',',1)[1]))).convert('RGBA')) for t in data['textures']]
    (HERE/'renders').mkdir(exist_ok=True)
    for key in keys:
        race,variant=key.split('/')
        for view in VIEWS:
            path=HERE/'renders'/f'{variant}_{race}_{view}.png'
            render(data['scenes'][key],textures,view).save(path,optimize=True)
            print(path.relative_to(HERE),flush=True)
    if not args.no_overview and all((HERE/'renders'/f'{v}_{r}_{a}.png').exists() for v in VARIANTS for r in ('human','orc') for a in VIEWS):
        overview()
        print('renders/overview.png',flush=True)

if __name__=='__main__':
    main()
