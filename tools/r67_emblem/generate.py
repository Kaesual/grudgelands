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
PALETTE = {'accord': ('#3f6fce', '#bcd6ff'), 'throng': ('#c41e3a', '#ffd0c8')}
DARK = '#181e28'
IVORY = '#f3e7ce'
SCALE = 6
IDEAS = {
    'a': ('Wing & Tusk', 'Oathwing', 'Oathjaw',
          'Two wings join around a keystone: different peoples holding one line.',
          'Two rising tusks share one heavy jaw: a people that cannot be bought or broken.'),
    'b': ('Root & Horn', 'Threefold Root', 'Gathering Horn',
          'Three broad boughs grow from one rooted trunk: the pact belongs to its homelands.',
          'One sweeping rally horn calls scattered strength into a single force.'),
    'c': ('Lance & Maul', 'Crossed Lances', 'Breaker Maul',
          'Two interlocked lances guard a common centre: a pact defended together.',
          'A broad war maul carries one uncompromising edge: many hands behind one blow.'),
}


def polygon(draw, points, fill):
    draw.polygon([(round(x * SCALE), round(y * SCALE)) for x, y in points], fill=fill)


def curve(start, segments):
    # Sample original cubic geometry; no vector asset or font is an input.
    result = [start]
    for c1, c2, end in segments:
        p0 = np.array(result[-1], dtype=float)
        p1, p2, p3 = map(lambda p: np.array(p, dtype=float), (c1, c2, end))
        for t in np.linspace(0, 1, 25)[1:]:
            p = (1-t)**3*p0 + 3*(1-t)**2*t*p1 + 3*(1-t)*t*t*p2 + t**3*p3
            result.append(tuple(p))
    return result


def motif(faction, variant):
    # A large, two-tone UI sigil; its alpha also defines the banner ink.
    im = Image.new('RGBA', (100*SCALE, 100*SCALE))
    d = ImageDraw.Draw(im)
    base, light = PALETTE[faction]
    if variant == 'a' and faction == 'accord':
        polygon(d, [(6,17),(36,30),(50,18),(64,30),(94,17),(86,44),
                    (73,49),(78,53),(64,61),(50,87),(36,61),(22,53),
                    (27,49),(14,44)], base)
        polygon(d, [(6,17),(36,30),(43,43),(19,35)], light)
        polygon(d, [(94,17),(64,30),(57,43),(81,35)], light)
        polygon(d, [(50,28),(60,40),(50,69),(40,40)], light)
    elif variant == 'a':
        polygon(d, [(8,13),(24,28),(29,49),(38,60),(62,60),(71,49),
                    (76,28),(92,13),(88,58),(75,78),(50,91),(25,78),(12,58)], base)
        polygon(d, [(8,13),(24,28),(29,49),(38,60),(27,59),(19,47)], light)
        polygon(d, [(92,13),(76,28),(71,49),(62,60),(73,59),(81,47)], light)
        polygon(d, [(32,71),(50,79),(68,71),(50,87)], light)
    elif variant == 'b' and faction == 'accord':
        polygon(d, [(50,7),(66,27),(62,34),(79,24),(90,41),(72,56),
                    (57,57),(57,67),(77,79),(81,90),(50,80),(19,90),
                    (23,79),(43,67),(43,57),(28,56),(10,41),(21,24),
                    (38,34),(34,27)], base)
        polygon(d, [(50,7),(57,28),(50,44),(43,28)], light)
        polygon(d, [(21,24),(40,45),(31,46),(15,40)], light)
        polygon(d, [(79,24),(60,45),(69,46),(85,40)], light)
        polygon(d, [(50,54),(54,72),(50,80),(46,72)], light)
    elif variant == 'b':
        outline = curve((12,18), [((-1,44),(7,72),(27,85)),
            ((49,100),(80,90),(92,59)), ((75,77),(52,76),(40,60)),
            ((32,50),(33,39),(39,29))])
        outline += [(45,25),(18,10)]
        polygon(d, outline, base)
        highlight = curve((12,18), [((-1,44),(7,72),(27,85))])
        highlight += [(32,72)]
        highlight += curve((32,72), [((17,59),(17,40),(25,25))])[1:]
        highlight += [(39,29),(45,25),(18,10)]
        polygon(d, highlight, light)
        tip = curve((92,59), [((75,77),(52,76),(40,60))])
        tip += [(48,82)]
        polygon(d, tip, light)
    elif variant == 'c' and faction == 'accord':
        spear = [(9,8),(35,16),(29,23),(82,81),(73,89),(20,31),(13,38)]
        polygon(d, spear, base)
        polygon(d, [(100-x,y) for x,y in spear], base)
        polygon(d, [(9,8),(26,18),(20,25),(13,38)], light)
        polygon(d, [(91,8),(74,18),(80,25),(87,38)], light)
        polygon(d, [(50,36),(63,50),(50,64),(37,50)], light)
    else:
        polygon(d, [(10,18),(27,9),(36,19),(65,19),(76,10),(91,24),
                    (86,49),(65,47),(62,39),(58,39),(58,74),(66,82),
                    (50,93),(34,82),(42,74),(42,39),(35,39),(29,50),
                    (10,45)], base)
        polygon(d, [(10,18),(27,9),(36,19),(65,19),(76,10),(91,24),
                    (75,28),(27,28)], light)
        polygon(d, [(46,40),(53,40),(53,75),(46,81)], light)
    return im


def png(im):
    buf = io.BytesIO()
    im.save(buf, format='PNG', optimize=False)
    return buf.getvalue()


def down(im, size):
    return im.resize(size, Image.Resampling.LANCZOS)


def banner(faction, large_motif):
    # Keep the shipped cloth alpha byte-for-byte; repaint every RGB value.
    reference = Image.open(MAP / f'textures/grug_mapgen_faction_banner_{faction}.png').convert('RGBA')
    im = Image.new('RGBA', (128*SCALE, 256*SCALE), PALETTE[faction][0])
    d = ImageDraw.Draw(im)
    base = np.array(Image.new('RGB', (1,1), PALETTE[faction][0]).getpixel((0,0)))
    shade = tuple((base * .76).astype(int)) + (255,)
    # The source viewBox is centred vertically: x'=1.28*x, y'=1.28*y+25.6.
    def cloth(points, color):
        polygon(d, [(x*1.28, y*1.28+25.6) for x,y in points], color)
    cloth([(6,3),(16,3),(16,138),(50,151),(84,138),(84,3),(94,3),
           (94,142),(50,157),(6,142)], shade)
    pts = [(12,8),(88,8),(88,138),(50,151),(12,138),(12,8)]
    d.line([(round(x*1.28*SCALE), round((y*1.28+25.6)*SCALE)) for x,y in pts],
           fill=IVORY, width=2*SCALE, joint='curve')
    # One modest hem and a square, undistorted motif above cloth centre.
    ink_mask = down(large_motif.getchannel('A'), (92*SCALE,92*SCALE))
    ink = Image.new('RGBA', ink_mask.size, IVORY)
    ink.putalpha(ink_mask)
    im.alpha_composite(ink, (18*SCALE,76*SCALE))
    im = down(im, (128,256))
    im.putalpha(reference.getchannel('A'))
    data = np.array(im)
    data[data[:,:,3] == 0, :3] = 0
    return Image.fromarray(data)


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
    board=Image.new('RGB',(1200,1020),DARK)
    d=ImageDraw.Draw(board)
    font=ImageFont.load_default(size=22)
    small=ImageFont.load_default(size=14)
    d.text((30,24),'GRUDGELANDS / FACTION EMBLEMS',font=font,fill=IVORY)
    d.text((30,59),'A recommended  /  UI sizes 16, 24, 32, 64  /  existing banner mesh',font=small,fill='#a8b4c4')
    for i,key in enumerate(IDEAS):
        y=106+i*300
        d.text((30,y),key.upper()+' / '+IDEAS[key][0],font=font,fill=IVORY)
        for j,f in enumerate(FACTIONS):
            x=30+j*590
            d.text((x,y+35),'The '+f.title(),font=small,fill=PALETTE[f][1])
            icon=images[f'emblem_{f}_{key}.png']
            for size,dx in [(16,0),(24,45),(32,100),(64,160)]:
                im=down(icon,(size,size));board.paste(im,(x+dx,y+105-size//2),im)
                d.text((x+dx,y+150),str(size),font=small,fill='#a8b4c4')
            view=images[f'view_{f}_{key}.png'].resize((296,240),Image.Resampling.LANCZOS)
            board.paste(view,(x+250,y+30))
        d.line((30,y+285,1170,y+285),fill='#35404e')
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
        for key in IDEAS:
            large=motif(f,key)
            put(f'emblem_{f}_{key}.png',down(large,(100,100)),True)
            cloth=banner(f,large)
            put(f'banner_{f}_{key}.png',cloth,True)
            put(f'view_{f}_{key}.png',projection(cloth,vertices,buffers))
        refs={f'ref_emblem_{f}.png':INV/f'grug_inventory_faction_{f}.png',
              f'ref_banner_{f}.png':MAP/f'textures/grug_mapgen_faction_banner_{f}.png'}
        for name,path in refs.items():
            out[HERE/'preview'/name]=path.read_bytes()
            images[name]=Image.open(path).convert('RGBA')
            sources[name]={'source':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        put(f'view_{f}_current.png',projection(images[f'ref_banner_{f}.png'],vertices,buffers))
    for kind,ids in [('class',('warrior','scout','mage','priest')),
                     ('race',('human','dwarf','elf','orc','troll','undead'))]:
        for key in ids:
            path=CLASSES/f'grug_{kind}_{key}.png'
            name=f'ref_{kind}_{key}.png'
            out[HERE/'preview'/name]=path.read_bytes()
            sources[name]={'source':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    put('contact.png',contact_sheet(images))
    out[HERE/'preview/index.html']=html_page(IDEAS,FACTIONS)
    manifest={'model':{'source':str((MAP/'models/grug_mapgen_faction_banner.b3d').relative_to(ROOT)),
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
