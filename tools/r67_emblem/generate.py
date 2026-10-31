#!/usr/bin/env python3
"""Build original Round 67 emblem proposals: Python 3, Pillow and numpy."""
import argparse
import hashlib
import io
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MAP = ROOT / 'mods/MAPGEN/grug_mapgen'
INV = ROOT / 'mods/PLAYER/grug_inventory/textures'
CLASSES = ROOT / 'mods/PLAYER/grug_classes/textures'
FACTIONS = ('accord', 'throng')
# Pass 4 retains the Pass 2/3 finish and samples the most frequent opaque cloth colour of each shipped PNG.
from collections import Counter
from heraldry import IDEAS, PAIRS, VARIANTS, IVORY, banner as draw_banner, down, icon


def sampled_palette():
    palette = {}
    for faction in FACTIONS:
        im = Image.open(MAP / f'textures/grug_mapgen_faction_banner_{faction}.png').convert('RGBA')
        data = np.array(im)
        colour = Counter(map(tuple, data[data[:, :, 3] == 255, :3])).most_common(1)[0][0]
        palette[faction] = ('#'+''.join(f'{c:02x}' for c in colour), IVORY)
    return palette


PALETTE = sampled_palette()
DARK = '#181e28'
# Immutable Pass 3 A1/B3 comparison inputs; stored beside the offline HTML.
PASS3_COMMIT = 'cf2e454a748e15bc0d5da7bda9376a4a3dd8565c'
PASS3_REFS = {
    'ref_pass3_emblem_accord.png': 'd0feee50f5d67a247edbb306a302f92df13fa366845b27bb37a58cf16bbe508b',
    'ref_pass3_banner_accord.png': '1dbd9e2bf8409f9288b86583e493c92ddc0993ef2377f2765b66ad014afc2337',
    'ref_pass3_emblem_throng.png': 'adf55de436dd883529176da7371d246e606f95cb144c73423621a97c0e985b45',
    'ref_pass3_banner_throng.png': 'b1aa7fd139b7f4720923f60572ba38a0241bfcbcd6ae593a3136e06e2f3df161',
}


def png(im):
    buf = io.BytesIO()
    im.save(buf, format='PNG', optimize=False)
    return buf.getvalue()


def chunks(data, start, end):
    while start < end:
        tag, size = struct.unpack_from('<4si', data, start)
        stop = start+8+size
        assert size >= 0 and stop <= end
        yield tag, start+8, stop
        start = stop
    assert start == end


def read_model():
    # Read the existing B3D at rest, including its three material buffers.
    path = MAP / 'models/grug_mapgen_faction_banner.b3d'
    data = path.read_bytes()
    assert data[:4] == b'BB3D'
    meshes = []
    def walk(start, end):
        for tag, a, b in chunks(data, start, end):
            if tag == b'NODE':
                zero = data.index(b'\0', a)
                transform = struct.unpack_from('<10f', data, zero+1)
                assert transform == (0,0,0,1,1,1,1,0,0,0), 'Unexpected rest transform'
                walk(zero+41,b)
            elif tag == b'MESH':
                meshes.append(list(chunks(data,a+4,b)))
    walk(12,len(data))
    assert len(meshes) == 1
    buffers = []
    for tag,a,b in meshes[0]:
        if tag == b'VRTS':
            assert struct.unpack_from('<3i', data,a) == (1,1,2)
            vertices = np.frombuffer(data[a+12:b], dtype='<f4').reshape(-1,8).copy()
        elif tag == b'TRIS':
            buffers.append(np.frombuffer(data[a+4:b], dtype='<i4').reshape(-1,3).copy())
    vertices[:,:3] /= 10.0
    assert len(buffers) == 3
    assert np.allclose(vertices[:4,6:], ((0,0),(1,0),(1,1),(0,1)))
    assert np.allclose(vertices[:4,:3], ((-.48,.5,-.52),(.48,.5,-.52),
                                      (.48,-1.5,-.52),(-.48,-1.5,-.52)))
    return vertices, buffers, hashlib.sha256(data).hexdigest()


def box(lo,hi):
    x,y,z = lo; X,Y,Z = hi
    pts = np.array([(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),
                    (x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)], dtype=float)
    faces = [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]
    return [(pts[list(f)],np.array([(0,1),(1,1),(1,0),(0,0)])) for f in faces]


def projection(texture, vertices, buffers):
    # Rasterize the actual mesh. The supporting post/beam are illustrative.
    w,h = 840,680
    camera = np.array([2.05,.65,-4.8])
    target = np.array([0,-.65,-.2])
    forward = target-camera; forward /= np.linalg.norm(forward)
    right = np.cross([0,1,0],forward); right /= np.linalg.norm(right)
    up = np.cross(forward,right)
    focal = h/(2*math.tan(math.radians(43)/2))
    yy = np.linspace(0,1,h)[:,None,None]
    rgb = np.array([40,48,56])[None,None,:]*(1-yy)+np.array([22,28,34])[None,None,:]*yy
    canvas = np.broadcast_to(rgb,(h,w,3)).copy()
    depth = np.full((h,w),np.inf)
    tex = np.array(texture.convert('RGBA'))
    def triangle(points,uv,color=None):
        p = points-camera
        z = p@forward
        if np.any(z <= .05):
            return
        screen = np.column_stack((w/2+(p@right)*focal/z,h/2-(p@up)*focal/z))
        low = np.maximum(np.floor(screen.min(axis=0)).astype(int),[0,0])
        high = np.minimum(np.ceil(screen.max(axis=0)).astype(int),[w-1,h-1])
        if np.any(high<low):
            return
        x0,y0=low; x1,y1=high
        gx,gy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
        a,b,c=screen
        denom=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(denom)<1e-9:
            return
        wa=((b[1]-c[1])*(gx-c[0])+(c[0]-b[0])*(gy-c[1]))/denom
        wb=((c[1]-a[1])*(gx-c[0])+(a[0]-c[0])*(gy-c[1]))/denom
        wc=1-wa-wb
        inv=wa/z[0]+wb/z[1]+wc/z[2]
        distance=1/np.maximum(inv,1e-9)
        valid=(wa>=-1e-7)&(wb>=-1e-7)&(wc>=-1e-7)&(distance<depth[y0:y1+1,x0:x1+1])
        if color is None:
            u=(wa*uv[0,0]/z[0]+wb*uv[1,0]/z[1]+wc*uv[2,0]/z[2])*distance
            v=(wa*uv[0,1]/z[0]+wb*uv[1,1]/z[1]+wc*uv[2,1]/z[2])*distance
            pixels=tex[np.clip((v*tex.shape[0]).astype(int),0,tex.shape[0]-1),
                       np.clip((u*tex.shape[1]).astype(int),0,tex.shape[1]-1)]
            valid &= pixels[:,:,3]>127
            rgb=pixels[:,:,:3]*.93
        else:
            normal=np.cross(points[1]-points[0],points[2]-points[0])
            normal/=max(np.linalg.norm(normal),1e-9)
            shade=.72+.28*abs(normal@np.array([-.4,.7,-.59]))
            rgb=np.broadcast_to(np.array(color)*shade,(*valid.shape,3))
        patch=canvas[y0:y1+1,x0:x1+1]; patch[valid]=rgb[valid]
        depth[y0:y1+1,x0:x1+1][valid]=distance[valid]
    for lo,hi in [((-.10,-2.2,.10),(.10,.96,.30)),
                  ((-.88,.55,.06),(.88,.73,.26))]:
        for pts,uv in box(lo,hi):
            for ids in [(0,1,2),(0,2,3)]:
                triangle(pts[list(ids)],uv[list(ids)],(112,87,59))
    for material,triangles in enumerate(buffers):
        for ids in triangles:
            triangle(vertices[ids,:3],vertices[ids,6:],
                     None if material==0 else ((132,103,66) if material==1 else (104,83,57)))
    return down(Image.fromarray(np.clip(canvas,0,255).astype('uint8')), (420,340))


def contact_sheet(images):
    board = Image.new('RGB', (1320, 1260), DARK)
    d = ImageDraw.Draw(board)
    font = ImageFont.load_default(size=22)
    small = ImageFont.load_default(size=14)
    d.text((24, 22), 'GRUDGELANDS / HART & BOAR / PASS 4', font=font, fill=IVORY)
    d.text((24, 57), 'Recommended: H1 + K1. Pairs: 1 painted livery / 2 cut ivory / 3 needlework.', font=small, fill='#a8b4c4')
    for j, faction in enumerate(FACTIONS):
        y = 108 + j*365
        d.text((24, y), 'THE '+faction.upper()+' / '+('HARTS' if j==0 else 'BOARS'), font=font, fill=IVORY)
        for i, key in enumerate(VARIANTS):
            x = 24+i*435
            label, title, _ = IDEAS[faction][key]
            d.text((x, y+39), label+' / '+title, font=small, fill=IVORY)
            emblem = images[f'emblem_{faction}_{key}.png']
            board.paste(emblem, (x, y+77), emblem)
            for size, dx in ((16, 122), (24, 169), (32, 218), (64, 277)):
                im = down(emblem, (size, size))
                board.paste(im, (x+dx, y+109-size//2), im)
                d.text((x+dx, y+151), str(size), font=small, fill='#a8b4c4')
            flat = down(images[f'banner_{faction}_{key}.png'], (64, 128))
            board.paste(flat, (x+18, y+201), flat)
            view = down(images[f'view_{faction}_{key}.png'], (231, 187))
            board.paste(view, (x+126, y+167))
    d.line((24, 835, 1296, 835), fill='#35404e')
    d.text((24, 858), 'COMPARISON / unchanged Pass 3 A1/B3 and shipped art', font=font, fill=IVORY)
    for i, (key, faction) in enumerate((('pass3', 'accord'), ('pass3', 'throng'), ('current', 'accord'), ('current', 'throng'))):
        x = 24+i*328
        prefix = 'ref_pass3_' if key=='pass3' else 'ref_'
        d.text((x, 903), ('PASS 3' if key=='pass3' else 'SHIPPED')+' / '+faction.title(), font=small, fill=IVORY)
        emblem = images[prefix+f'emblem_{faction}.png']
        for size, dx in ((16, 0), (24, 40), (32, 90), (64, 148)):
            im = down(emblem, (size, size))
            board.paste(im, (x+dx, 963-size//2), im)
        view = down(images[f'view_{faction}_{key}.png'], (294, 238))
        board.paste(view, (x, 1006))
    return board


def head_sheet(images):
    board = Image.new('RGB', (1200, 920), DARK)
    d = ImageDraw.Draw(board)
    font = ImageFont.load_default(size=20)
    small = ImageFont.load_default(size=13)
    d.text((24, 18), 'PASS 4 / FRONTAL HERALDRY / H1 + K1 recommended', font=font, fill=IVORY)
    for j, faction in enumerate(FACTIONS):
        for i, key in enumerate(VARIANTS):
            x, y = 50+i*400, 63+j*420
            label, title, _ = IDEAS[faction][key]
            d.text((x, y), label+' / '+title, font=small, fill=IVORY)
            large = images[f'large_{faction}_{key}.png']
            board.paste(large, (x, y+21), large)
            for n, size in enumerate((16,24,32,64)):
                im = down(images[f'emblem_{faction}_{key}.png'], (size,size))
                xx = x+25+n*70
                board.paste(im, (xx, y+342-size//2), im)
                d.text((xx, y+381), str(size)+' px', font=small, fill='#a8b4c4')
    return board


def outputs():
    from preview_page import html_page
    out={}
    images={}
    sources={}
    vertices,buffers,model_hash=read_model()
    def put(name,im,candidate=False):
        data=png(im)
        images[name]=im
        out[HERE/'preview'/name]=data
        if candidate:
            out[HERE/'candidates'/name]=data
    for f in FACTIONS:
        for key in VARIANTS:
            large=icon(f,key,PALETTE)
            put(f'emblem_{f}_{key}.png',down(large,(100,100)),True)
            put(f'large_{f}_{key}.png',down(large,(300,300)))
            reference=Image.open(MAP/f'textures/grug_mapgen_faction_banner_{f}.png').convert('RGBA')
            cloth=draw_banner(f,key,PALETTE,reference)
            put(f'banner_{f}_{key}.png',cloth,True)
            put(f'view_{f}_{key}.png',projection(cloth,vertices,buffers))
        refs={f'ref_emblem_{f}.png':INV/f'grug_inventory_faction_{f}.png',
              f'ref_banner_{f}.png':MAP/f'textures/grug_mapgen_faction_banner_{f}.png'}
        for name,path in refs.items():
            out[HERE/'preview'/name]=path.read_bytes()
            images[name]=Image.open(path).convert('RGBA')
            sources[name]={'source':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        put(f'view_{f}_current.png',projection(images[f'ref_banner_{f}.png'],vertices,buffers))
        for kind in ('emblem', 'banner'):
            name = f'ref_pass3_{kind}_{f}.png'
            path = HERE/'preview'/name
            data = path.read_bytes()
            assert hashlib.sha256(data).hexdigest()==PASS3_REFS[name], name+' changed'
            out[path] = data
            images[name] = Image.open(io.BytesIO(data)).convert('RGBA')
            sources[name] = {'source':f'tools/r67_emblem/candidates/{kind}_{f}_{1 if f == "accord" else 3}.png',
                             'commit':PASS3_COMMIT, 'sha256':PASS3_REFS[name]}
        put(f'view_{f}_pass3.png',projection(images[f'ref_pass3_banner_{f}.png'],vertices,buffers))
    for kind,ids in [('class',('warrior','scout','mage','priest')),
                     ('race',('human','dwarf','elf','orc','troll','undead'))]:
        for key in ids:
            path=CLASSES/f'grug_{kind}_{key}.png'
            name=f'ref_{kind}_{key}.png'
            out[HERE/'preview'/name]=path.read_bytes()
            sources[name]={'source':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    put('contact.png',contact_sheet(images))
    put('heads.png',head_sheet(images))
    out[HERE/'preview/index.html']=html_page(IDEAS,FACTIONS,PAIRS)
    manifest={'pass':4, 'pairs':PAIRS, 'recommendation':{'accord':'1','throng':'1'}, 'variants':IDEAS, 'palette':PALETTE, 'palette_sampling':'Most frequent fully opaque RGB in each shipped banner', 'model':{'source':str((MAP/'models/grug_mapgen_faction_banner.b3d').relative_to(ROOT)),
                        'sha256':model_hash,'front_vertices_nodes':vertices[:4,:3].astype(float).round(5).tolist(),
                        'front_uvs':vertices[:4,6:].tolist(), 'material_buffers':['cloth','rod','straps']},
              'references':sources,'candidate_sha256':{str(p.relative_to(HERE)):hashlib.sha256(b).hexdigest()
                  for p,b in sorted(out.items()) if p.parent.name=='candidates'}}
    out[HERE/'manifest.json']=(json.dumps(manifest,indent=2,sort_keys=True)+'\n').encode()
    # Artifact checks only: no runtime fixture, engine or Lua execution.
    for p,data in out.items():
        if p.parent.name!='candidates':
            continue
        im=Image.open(io.BytesIO(data))
        assert im.mode=='RGBA'
        assert im.size==((100,100) if p.name.startswith('emblem') else (128,256))
        assert im.getchannel('A').getextrema()==(0,255)
        if p.name.startswith('banner'):
            f=p.name.split('_')[1]
            assert im.getchannel('A').tobytes()==images[f'ref_banner_{f}.png'].getchannel('A').tobytes()
        else:
            a=np.array(im)[:,:,3]
            assert not np.any(a[[0,-1],:]) and not np.any(a[:,[0,-1]])
        assert data==out[HERE/'preview'/p.name]
    from html.parser import HTMLParser
    class Links(HTMLParser):
        def handle_starttag(self,tag,attrs):
            for key,value in attrs:
                if key in ('src','href'):
                    assert not any(s in value for s in (':','//','..')),value
                    assert value.startswith('#') or HERE/'preview'/value in out,value
            assert tag!='script'
    Links().feed(out[HERE/'preview/index.html'].decode())
    return out


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true',help='Regenerate in memory and compare all outputs')
    args=parser.parse_args()
    generated=outputs()
    unexpected=[p for folder in ('candidates','preview') for p in (HERE/folder).glob('*') if p not in generated]
    if unexpected:
        raise SystemExit('Unexpected output files: '+', '.join(str(p) for p in unexpected))
    stale=[]
    for path,data in generated.items():
        if args.check:
            if not path.exists() or path.read_bytes()!=data:
                stale.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
    if stale:
        raise SystemExit('Stale outputs: '+', '.join(stale))
    print(f'r67_emblem: {len(generated)} outputs '+('verified' if args.check else 'written')+
          '; 12 candidates; exact banner alpha; local preview references OK')


if __name__=='__main__':
    main()
