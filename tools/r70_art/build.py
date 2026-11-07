#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Round 70 original pixel art and node-box studies. Media: CC0-1.0.

Python 3, Pillow and numpy. No engine, server, browser or network is used.
All writes stay beside this script; --check builds in memory and compares.
"""
import argparse
import base64
import hashlib
import html
import io
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
NEAREST = Image.Resampling.NEAREST
TIERS = ('iron', 'steel', 'silversteel', 'embersteel', 'abyssal_steel')
NAMES = ('Iron', 'Steel', 'Silversteel', 'Embersteel', 'Abyssal Steel')
# Exact ramps of the shipped Round 68 A bars (art.py METAL).
METALS = {
    'iron': '302e2b 3e3c3a 686460 86817c b0aaa4',
    'steel': '343a40 686868 939393 bfc3c6 eaeaea',
    'silversteel': '29384d 7c91ab b6c5d6 e2eaf1 ffffff',
    'embersteel': '291d23 4a1812 8c3e32 cc6639 ffb858',
    'abyssal_steel': '25243f 2e243e 5a4a74 8874a6 d4c4ea',
}
OUTPUTS = {}
SOURCES = {}
IMAGES = {}


def png(im):
    stream = io.BytesIO()
    im.save(stream, 'PNG', optimize=False, compress_level=9)
    return stream.getvalue()


def emit(path, data):
    if isinstance(data, Image.Image):
        IMAGES[path] = data
        data = png(data)
    if isinstance(data, str):
        data = data.encode('utf-8')
    OUTPUTS[path] = data


def json_text(data):
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + '\n'


def source(path):
    raw = (ROOT / path).read_bytes()
    SOURCES[path] = hashlib.sha256(raw).hexdigest()
    return Image.open(io.BytesIO(raw)).convert('RGBA')


def source_text(path):
    raw=(ROOT/path).read_bytes()
    SOURCES[path]=hashlib.sha256(raw).hexdigest()
    return raw.decode('utf-8')


def rgb(value):
    return tuple(bytes.fromhex(value.lstrip('#')))


def noise(x, y, seed=0):
    # Integer hash, independent of Python's random/hash implementation.
    n = ((x + 19) * 374761393 + (y + 37) * 668265263 + seed * 144269) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return (n ^ (n >> 16)) & 255


def rock(seed=9, base=(102, 103, 101), span=13):
    im = Image.new('RGBA', (16, 16))
    for y in range(16):
        for x in range(16):
            # Low-contrast, horizontal tool marks; no tile-edge frame.
            xx, yy = x % 15, y % 15
            v = (noise(xx // 3, yy, seed) % 7 - 3) * span // 6
            v += noise(xx, yy, seed) % 5 - 2
            im.putpixel((x, y), tuple(max(0, min(255, c + v)) for c in base) + (255,))
    return im


def thread(variant):
    im = Image.new('RGBA', (16, 16))
    d = ImageDraw.Draw(im)
    edge, wood, woodlight = '#3e3028', '#91613b', '#c49760'
    shadow, body, light = '#9a9178', '#d9d0af', '#fff3d0'
    if variant == 'a':
        # Upright bobbin, separated wooden flanges and a loose strand.
        d.polygon([(4,1),(11,1),(13,3),(11,5),(11,11),(13,12),(12,14),(3,14),(2,12),(4,10),(4,5),(2,3)], fill=edge)
        d.polygon([(3,3),(5,2),(10,2),(12,3),(10,4),(5,4)], fill=woodlight)
        d.line([(6,2),(9,2)], fill=wood)
        d.rectangle((4,5,10,10), fill=body)
        d.line([(4,5),(4,10)], fill=light)
        for y in (6,8,10):
            d.line([(6,y),(10,y-1)], fill=shadow)
        d.polygon([(3,12),(5,11),(10,11),(12,12),(10,13),(4,13)], fill=wood)
        d.line([(4,12),(9,12)], fill=woodlight)
        d.line([(11,9),(13,9),(14,11),(14,13)], fill=light)
    elif variant == 'b':
        # Round yarn ball: broad crossing windings, no wood.
        d.polygon([(5,2),(10,2),(13,4),(14,7),(13,11),(10,13),(5,13),(2,10),(1,6),(3,3)], fill=edge)
        d.polygon([(5,3),(10,3),(12,5),(13,8),(11,11),(8,12),(4,11),(2,7),(3,5)], fill=body)
        d.line([(3,5),(5,6),(9,8),(12,9)], fill=shadow, width=2)
        d.line([(5,3),(4,5),(4,8),(7,11)], fill=light)
        d.line([(9,3),(8,5),(7,6)], fill=light)
        d.line([(12,5),(11,7),(8,10),(6,11)], fill=light)
        d.line([(10,12),(12,14),(14,14)], fill=body)
    else:
        # Folded skein: long hollow loop with an unmistakable centre tie.
        d.polygon([(6,1),(10,1),(12,3),(11,6),(10,8),(11,11),(10,14),(6,15),(3,13),(3,10),(4,8),(3,5),(4,2)], fill=edge)
        d.polygon([(6,2),(10,2),(11,4),(9,8),(10,12),(9,13),(6,14),(4,12),(5,8),(4,5),(5,3)], fill=body)
        d.line([(6,3),(5,5),(6,8),(5,11),(6,13)], fill=light)
        d.line([(9,3),(8,5),(7,6)], fill=shadow)
        d.line([(8,10),(8,12),(7,13)], fill=shadow)
        d.rectangle((4,7,10,8), fill=wood)
        d.line([(5,7),(9,7)], fill=woodlight)
    return im


def ornament(variant, tier):
    im = rock()
    mask = Image.new('L', (16,16))
    d = ImageDraw.Draw(mask)
    if variant == 'a':
        # A continuous diagonal ribbon crosses the face, wrapping on the torus.
        for offset in (-16,0,16):
            path = [(offset-1,16),(offset+3,12),(offset+3,9),
                    (offset+8,9),(offset+8,4),(offset+12,4),(offset+16,0)]
            d.line(path, fill=255)
        if tier >= 1:
            d.line([(4,2),(6,2),(6,4)], fill=255)
        if tier >= 2:
            d.line([(11,11),(13,11),(13,13)], fill=255)
        if tier >= 3:
            d.point((4,4), fill=255)
            d.point((11,13), fill=255)
        if tier >= 4:
            d.line([(2,6),(4,6)], fill=255)
            d.line([(10,1),(10,2)], fill=255)
    elif variant == 'b':
        # A centred forged quarry seal; intentionally no rectangular border.
        d.line([(7,3),(11,7),(7,11),(3,7),(7,3)], fill=255)
        d.rectangle((6,6,8,8), fill=255)
        if tier >= 1:
            d.line([(7,1),(7,2)], fill=255)
            d.line([(7,12),(7,13)], fill=255)
        if tier >= 2:
            d.line([(1,7),(2,7)], fill=255)
            d.line([(12,7),(13,7)], fill=255)
        if tier >= 3:
            for x,y in ((3,3),(11,3),(3,11),(11,11)):
                d.line([(x,y+1),(x,y),(x+1,y)], fill=255)
        if tier >= 4:
            d.line([(5,2),(9,2)], fill=255)
            d.line([(5,12),(9,12)], fill=255)
    else:
        # A rising carved sprig, with successive tiers adding metal leaves.
        d.line([(3,13),(5,11),(6,9),(8,7),(9,5),(11,3)], fill=255)
        d.line([(6,9),(3,8),(2,6),(5,7),(6,9)], fill=255)
        d.line([(9,5),(9,2),(11,1),(11,3)], fill=255)
        if tier >= 1:
            d.line([(7,8),(10,8),(12,6),(9,6)], fill=255)
        if tier >= 2:
            d.line([(5,11),(8,12),(11,10),(8,10)], fill=255)
        if tier >= 3:
            d.line([(8,6),(6,4),(4,4),(5,6)], fill=255)
        if tier >= 4:
            d.line([(3,13),(1,12),(1,10)], fill=255)
            d.line([(11,3),(13,3),(14,1)], fill=255)
    # Recess and lip, all shading local to the inlay, never a block-edge frame.
    original = mask.copy()
    for y in range(16):
        for x in range(16):
            if original.getpixel((x,y)):
                q=((x+1)%16,(y+1)%16)
                if not original.getpixel(q):
                    im.putpixel(q, (64,65,64,255))
    ramp = [rgb(c)+(255,) for c in METALS[TIERS[tier]].split()]
    for y in range(16):
        for x in range(16):
            if mask.getpixel((x,y)):
                # Broad body, sparse top-left glints, darker returned corners.
                idx = 3 if (x+y)%5 in (0,1) else 2
                if (x+2*y)%13 == 0:
                    idx=4
                im.putpixel((x,y),ramp[idx])
    return im


def machine_textures():
    tex = {'dressed_stone': rock(18,(105,104,98),20),
           'grindstone': rock(5,(123,120,109),23),
           'iron': rock(3,(68,66,61),13),
           'soot': rock(1,(34,32,30),8),
           'leather': rock(23,(86,56,39),14),
           'sand': rock(13,(170,153,109),16),
           'slag': rock(7,(67,60,57),17),
           'timber': rock(21,(104,73,43),25)}
    d=ImageDraw.Draw(tex['timber'])
    for x in (2,6,11,14):
        d.line([(x,0),(x,5),(x-1,8),(x-1,15)],fill='#493724')
        d.line([(x+1,1),(x+1,6)],fill='#966e43')
    d=ImageDraw.Draw(tex['grindstone'])
    for x,y in ((2,3),(9,2),(4,10),(12,11)):
        d.line([(x,y),(x+2,y+1)],fill='#625f55')
    brick=rock(6,(99,94,85),16)
    d=ImageDraw.Draw(brick)
    for y in (0,8):
        d.line([(0,y),(15,y)],fill='#44433f')
    d.line([(7,1),(7,7)],fill='#44433f')
    d.line([(0,9),(0,15)],fill='#44433f')
    tex['firebrick']=brick
    rubble=rock(12,(94,91,83),23)
    d=ImageDraw.Draw(rubble)
    for x,y in ((2,2),(9,1),(5,7),(12,8),(1,12),(9,13)):
        d.polygon([(x,y),(x+3,y-1),(x+4,y+1),(x+2,y+3),(x,y+2)],fill='#7d796d',outline='#42413c')
    tex['rubble']=rubble
    return tex


def box(bounds, texture, part):
    return {'bounds':list(bounds), 'texture':texture, 'part':part}


def machine(kind, variant):
    boxes=[]
    def b(x0,y0,z0,x1,y1,z1,t,p):
        boxes.append(box((x0,y0,z0,x1,y1,z1),t,p))
    def octagon(cx,cy,cz,r,height,t,p):
        # Five horizontal-depth strips make a heavy eight-sided horizontal drum.
        for za,zb,half in ((-1,-.75,.5),(-.75,-.5,.75),(-.5,.5,1),(.5,.75,.75),(.75,1,.5)):
            b(cx-r*half,cy,cz+r*za,cx+r*half,cy+height,cz+r*zb,t,p)
    if kind=='grinder' and variant=='a':
        dims=(2,2,2)
        b(.12,0,.12,1.88,.28,1.88,'dressed_stone','foundation')
        b(.3,.28,.45,1.7,.75,1.7,'dressed_stone','mill bed')
        octagon(1,.75,1.1,.76,.28,'grindstone','lower millstone')
        octagon(1,1.07,1.1,.67,.32,'grindstone','runner stone')
        b(.9,1.39,1,1.1,1.72,1.2,'iron','spindle')
        b(.96,1.62,.35,1.1,1.76,1.1,'timber','turning handle')
        b(.96,1.76,.3,1.1,1.96,.44,'timber','hand grip')
        b(.16,.32,.05,1.25,.44,.62,'timber','catch tray')
        for x in (.16,1.13):
            b(x,.44,.05,x+.12,.62,.62,'timber','tray side')
        b(.29,.44,.15,.7,.52,.53,'rubble','ground gravel')
        b(.75,.44,.15,1.1,.5,.53,'sand','sand sample')
        b(.47,1.39,1.05,.66,1.54,1.24,'rubble','feed cobble')
        b(.58,1.39,1.26,.83,1.6,1.47,'rubble','feed cobble')
    elif kind=='grinder' and variant=='b':
        dims=(2,2,2)
        b(.08,0,.12,1.92,.25,1.9,'dressed_stone','foundation')
        for x in (.15,1.65):
            b(x,.25,.4,x+.2,1.88,.68,'timber','front post')
            b(x,.25,1.5,x+.2,1.88,1.75,'timber','rear post')
            b(x-.04,.5,.36,x+.24,.68,.73,'iron','post strap')
        for cx in (.67,1.31):
            # Three strips approximate each horizontal crusher roller.
            b(cx-.23,.73,.65,cx+.23,1.25,1.48,'grindstone','crusher roller')
            b(cx-.31,.88,.65,cx+.31,1.1,1.48,'grindstone','roller shoulder')
            b(cx-.07,.9,.35,cx+.07,1.04,1.65,'iron','roller axle')
            for z in (.76,1.03,1.3):
                b(cx-.12,1.25,z,cx+.12,1.34,z+.12,'iron','crushing rib')
        for z in (.68,1.5):
            b(.35,1.44,z,1.65,1.9,z+.12,'timber','hopper lip')
        for x in (.36,1.52):
            b(x,1.44,.8,x+.12,1.9,1.5,'timber','hopper cheek')
        b(.55,1.57,.92,1.35,1.76,1.42,'rubble','feed cobble')
        b(.23,.26,.08,1.76,.38,.6,'timber','output tray')
        b(.35,.38,.18,.9,.49,.56,'rubble','gravel sample')
        b(1,.38,.18,1.63,.46,.56,'sand','sand sample')
        b(1.24,.55,.28,1.38,1.03,.42,'iron','crank arm')
        b(1.24,.55,.06,1.4,.7,.31,'timber','crank grip')
    elif kind=='grinder':
        dims=(2,3,2)
        b(.06,0,.15,1.94,.3,1.9,'dressed_stone','foundation')
        for x in (.13,1.65):
            b(x,.3,.8,x+.22,2.9,1.1,'timber','gantry post')
            for y in (.42,2.42):
                b(x-.03,y,.77,x+.25,y+.14,1.13,'iron','post strap')
        b(.12,2.62,.72,1.89,2.9,1.19,'timber','gantry head')
        b(.28,.3,.25,1.71,.62,1.66,'dressed_stone','mortar bed')
        for x in (.28,1.56):
            b(x,.62,.25,x+.15,.84,1.66,'dressed_stone','mortar cheek')
        b(.43,.62,.4,1.56,.72,1.51,'rubble','crushed stone')
        for x,y in ((.57,.8),(1.11,1.35)):
            b(x,y,.86,x+.16,2.66,1.03,'timber','stamp shaft')
            b(x-.15,y,.66,x+.32,y+.36,1.24,'iron','stamp head')
        b(.26,2.15,.65,1.73,2.3,1.28,'timber','guide beam')
        b(.3,.31,.02,1.6,.42,.25,'timber','sample ledge')
        b(.43,.42,.04,.86,.49,.22,'sand','sand sample')
    elif kind=='furnace' and variant=='a':
        dims=(2,3,2)
        b(.08,0,.08,1.92,.28,1.93,'dressed_stone','foundation')
        b(.2,.28,.58,1.8,2.16,1.85,'firebrick','shaft body')
        b(.48,2.16,.86,1.52,2.65,1.7,'firebrick','shoulder')
        b(.62,2.65,1,1.38,3,1.64,'firebrick','capped flue')
        b(.62,2.91,.99,1.38,3,1.65,'iron','flue rim')
        b(.64,.55,.55,1.36,1.28,.6,'soot','cold firebox recess')
        for x in (.5,1.36):
            b(x,.48,.43,x+.14,1.42,.64,'dressed_stone','firebox jamb')
        b(.5,1.28,.43,1.5,1.43,.66,'dressed_stone','firebox lintel')
        for x in (.74,.98,1.22):
            b(x,.58,.5,x+.04,1.23,.56,'iron','grate bar')
        for y in (.4,1.83):
            b(.18,y,.55,1.82,y+.12,1.87,'iron','shaft band')
        b(.86,.3,.22,1.14,.45,.62,'slag','cold pouring lip')
        b(.57,.28,.04,1.47,.34,.38,'iron','ingot mould')
        b(.72,.34,.1,1.29,.4,.27,'iron','cooled casting')
    elif kind=='furnace' and variant=='b':
        dims=(2,2,2)
        b(.1,0,.12,1.9,.25,1.92,'dressed_stone','foundation')
        b(.22,.25,.64,1.49,.75,1.75,'firebrick','hearth bed')
        octagon(.86,.75,1.19,.61,.48,'firebrick','crucible surround')
        octagon(.86,1.23,1.19,.61,.1,'iron','crucible rim')
        octagon(.86,1.333,1.19,.44,.018,'soot','empty cold crucible')
        b(.26,.76,1.76,1.44,1.94,1.9,'firebrick','rear hood')
        b(.26,1.78,1.3,1.44,2,1.9,'firebrick','hood cap')
        b(.61,.34,.61,1.12,.65,.65,'soot','air inlet')
        b(1.48,.37,.78,1.85,.6,1.44,'leather','closed bellows')
        b(1.46,.59,.76,1.87,.69,1.46,'timber','bellows board')
        b(.72,1.12,.29,1,1.28,.67,'slag','pouring spout')
        b(.4,.25,.04,1.36,.32,.42,'iron','casting tray')
        for x in (.51,.9):
            b(x,.32,.12,x+.26,.39,.32,'iron','cooled ingot')
    else:
        dims=(3,2,2)
        b(.08,0,.1,2.91,.25,1.9,'dressed_stone','foundation')
        b(.18,.25,.8,1.93,1.62,1.84,'firebrick','oven body')
        b(.18,.4,.65,.48,1.4,1.84,'firebrick','left pier')
        b(1.6,.4,.65,1.93,1.4,1.84,'firebrick','right pier')
        b(.47,.46,.77,1.61,1.2,.81,'soot','cold arch recess')
        for x,y,w in ((.48,1.08,.2),(.67,1.27,.2),(.86,1.42,.39),(1.24,1.27,.2),(1.43,1.08,.2)):
            b(x,y,.57,x+w,y+.2,.89,'dressed_stone','stepped arch voussoir')
        b(.25,1.65,.75,1.85,1.83,1.87,'dressed_stone','hood ledge')
        b(.69,1.83,1.13,1.4,2,1.75,'iron','low flue cap')
        b(.49,.43,.48,1.64,.57,.81,'slag','worn hearth lip')
        for x in (.64,.9,1.16,1.42):
            b(x,.61,.72,x+.045,1.06,.78,'iron','hearth grate')
        b(2.03,.25,.56,2.76,.64,1.58,'firebrick','mould bench')
        b(1.86,.64,.48,2.88,.78,1.64,'iron','bench top')
        for z in (.68,1.12):
            b(2.08,.78,z,2.67,.84,z+.22,'soot','mould bed')
            b(2.16,.84,z+.03,2.57,.9,z+.18,'iron','cooled casting')
    occupied=set()
    for item in boxes:
        x0,y0,z0,x1,y1,z1=item['bounds']
        assert 0 <= x0 < x1 <= dims[0] and 0 <= y0 < y1 <= dims[1] and 0 <= z0 < z1 <= dims[2]
        for x in range(math.floor(x0), math.ceil(x1)):
            for y in range(math.floor(y0), math.ceil(y1)):
                for z in range(math.floor(z0), math.ceil(z1)):
                    occupied.add((x,y,z))
    return {'kind':kind,'variant':variant.upper(),'dimensions_xyz':dims,
            'construction':'node boxes, split and clipped at integer cell boundaries',
            'coordinates':'metres/nodes; origin lower front left; +y up, +z rear; front -z',
            'reserved_cells':math.prod(dims),'occupied_cells':len(occupied),
            'occupied_cell_coordinates':sorted(occupied),'boxes':boxes,
            'textures':{key:'../textures/'+key+'.png' for key in sorted({b['texture'] for b in boxes})},
            'runtime':'Static decorative nodes only. No light, fire, particles, sound, animation, timers or interaction.',
            'uv':'16 texels per node, repeating in world-aligned face planes; see README for integration limits.'}


def render(boxes, textures, size=(420,360), camera=(6,4,-8), focus=(1,1,1), span=4):
    """Orthographic ray/box render of the JSON geometry; nearest texture lookup."""
    cam=np.array(camera,dtype=float)
    forward=-cam/np.linalg.norm(cam)
    right=np.cross([0,1,0],forward); right/=np.linalg.norm(right)
    up=np.cross(forward,right)
    w,h=size
    u=(np.arange(w)+.5-w/2)*span/w
    v=(h/2-np.arange(h)-.5)*span/w
    origin=(np.array(focus)[None,None,:]-forward*30
            +u[None,:,None]*right+v[:,None,None]*up)
    depth=np.full((h,w),np.inf)
    result=np.zeros((h,w,4),dtype=np.uint8)
    for item in boxes:
        bounds=np.array(item['bounds'],dtype=float)
        enter=np.full((h,w),-np.inf)
        leave=np.full((h,w),np.inf)
        axis=np.zeros((h,w),dtype=np.int8)
        for a in range(3):
            if abs(forward[a])<1e-9:
                valid=(origin[:,:,a]>=bounds[a])&(origin[:,:,a]<=bounds[a+3])
                leave=np.where(valid,leave,-np.inf)
                continue
            t0=(bounds[a]-origin[:,:,a])/forward[a]
            t1=(bounds[a+3]-origin[:,:,a])/forward[a]
            near,far=np.minimum(t0,t1),np.maximum(t0,t1)
            axis=np.where(near>enter,a,axis)
            enter=np.maximum(enter,near);leave=np.minimum(leave,far)
        hit=(enter<=leave)&(enter<depth)&(enter>0)
        if not np.any(hit):
            continue
        p=origin[hit]+enter[hit,None]*forward
        a=axis[hit]
        tx=np.where(a==0,p[:,2],p[:,0])
        ty=np.where(a==1,p[:,2],-p[:,1])
        tex=np.asarray(textures[item['texture']])
        pixels=tex[(np.floor(ty*16).astype(int)%16), (np.floor(tx*16).astype(int)%16)].copy()
        shade=np.where(a==1,1.08,np.where(a==0,.72,.91))
        pixels[:,:3]=np.clip(pixels[:,:3]*shade[:,None],0,255).astype(np.uint8)
        result[hit]=pixels; depth[hit]=enter[hit]
    return Image.fromarray(result)


def hall_scene(spec, textures, shipped):
    dims=spec['dimensions_xyz']
    offset=(.3,0,.6)
    boxes=[]
    for item in spec['boxes']:
        shifted=[v+offset[i%3] for i,v in enumerate(item['bounds'])]
        boxes.append(box(shifted,item['texture'],item['part']))
    boxes.extend([
        box((-1,-.2,-.6,4.8,0,3.5),'existing_stone','hall floor'),
        box((-1,0,3.1,4.8,2,3.4),'existing_cobble','two-course stone plinth'),
        box((-1,2,3.1,4.8,3.4,3.4),'existing_wood','timber infill'),
        box((-1,0,-.3,-.75,2,3.4),'existing_cobble','side plinth'),
        box((-1,2,-.3,-.75,3.4,3.4),'existing_wood','side infill'),
    ])
    for x in (-.8,2.1,4.55):
        boxes.append(box((x,0,2.9,x+.23,3.6,3.45),'timber','hall post'))
    boxes.append(box((-.8,3.2,2.9,4.8,3.5,3.45),'timber','hall beam'))
    # A neutral wooden scale mannequin, 1.8 nodes tall; no NPC art is proposed.
    for bounds in ((3.67,0,.25,3.81,.8,.45),(3.94,0,.25,4.08,.8,.45),
                   (3.65,.8,.2,4.1,1.4,.5),(3.75,1.43,.22,4,1.8,.48),
                   (3.47,.86,.24,3.62,1.35,.44),(4.12,.86,.24,4.27,1.35,.44)):
        boxes.append(box(bounds,'scale_figure','1.8-node scale figure'))
    all_tex=dict(textures,existing_stone=shipped['stone'],existing_cobble=shipped['cobble'],
                 existing_wood=shipped['wood'],scale_figure=rock(0,(147,134,109),5))
    return render(boxes,all_tex,(560,420),focus=(1.7,1.35,1.4),span=7.6)


def wall(im, count=5):
    out=Image.new('RGBA',(16*count,16*count))
    for y in range(count):
        for x in range(count):
            out.paste(im,(16*x,16*y))
    return out


def tag(im, alt, width=None, cls=''):
    w,h=im.size
    width=width or w
    return (f'<img class="{cls}" alt="{html.escape(alt,quote=True)}" width="{width}" '
            f'height="{round(h*width/w)}" src="data:image/png;base64,'
            +base64.b64encode(png(im)).decode()+'">')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    shipped={k:source('mods/BASE/default/textures/default_'+k+'.png')
             for k in ('stone','stone_brick','cobble','wood','gravel','sand','paper','stick')}
    for k in TIERS:
        shipped[k]=source('mods/ITEMS/grug_materials/textures/grug_materials_'+k+'_bar.png')
        assert shipped[k].size==(16,16)
        assert {tuple(p) for p in np.asarray(shipped[k]).reshape(-1,4)}-{(0,0,0,0)} <= {rgb(c)+(255,) for c in METALS[k].split()}
    assert shipped['stone'].size==shipped['paper'].size==(16,16)
    # Reconstruct the current icon's uniform colorize modifier for comparison.
    current=shipped['paper'].copy()
    for y in range(16):
        for x in range(16):
            p=current.getpixel((x,y))
            current.putpixel((x,y),tuple((p[i]*140+rgb('d8d1bd')[i]*115)//255 for i in range(3))+(p[3],))
    shipped['thread_today']=current
    for key,im in shipped.items():
        emit('context/'+key+'.png',im)
    for v in 'abc':
        emit(f'candidates/thread/{v}/thread.png',thread(v))
        for tier,key in enumerate(TIERS):
            im=ornament(v,tier)
            emit(f'candidates/stone/{v}/{key}.png',im)
            emit(f'previews/stone_{v}_{key}_wall.png',wall(im))
            emit(f'previews/stone_{v}_{key}_cube.png',render(
                [box((0,0,0,1,1,1),'face','full cube')],{'face':im},
                (144,144),camera=(6,4,-8),focus=(.5,.5,.5),span=1.75))
    textures=machine_textures()
    for name,im in textures.items():
        emit(f'candidates/machines/textures/{name}.png',im)
    specs={}
    for kind in ('grinder','furnace'):
        for v in 'abc':
            spec=machine(kind,v); specs[kind+'_'+v]=spec
            emit(f'candidates/machines/{kind}_{v}/geometry.json',json_text(spec))
            w,h,d=spec['dimensions_xyz']
            emit(f'previews/{kind}_{v}_front.png',render(spec['boxes'],textures,(320,320),
                camera=(0,0,-1),focus=(w/2,1.45,d/2),span=3.5))
            emit(f'previews/{kind}_{v}_hall.png',hall_scene(spec,textures,shipped))
    build_page(shipped,specs,textures)
    build_contact_sheet()
    build_licences()
    emit('source_manifest.json',json_text(SOURCES))
    validate(specs)
    # The manifest covers the generated files, excluding itself to avoid recursion.
    emit('manifest.json',json_text({p:hashlib.sha256(data).hexdigest() for p,data in sorted(OUTPUTS.items())}))
    bad=[]
    expected=set(OUTPUTS)
    for folder in ('candidates','context','previews'):
        if (HERE/folder).exists():
            for p in (HERE/folder).rglob('*'):
                if p.is_file() and str(p.relative_to(HERE)) not in expected:
                    bad.append('unexpected: '+str(p.relative_to(HERE)))
    for name,data in sorted(OUTPUTS.items()):
        path=HERE/name
        if args.check:
            if not path.exists() or path.read_bytes()!=data:
                bad.append('different/missing: '+name)
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
    if bad:
        raise SystemExit('\n'.join(bad))
    print(f'{"CHECK PASS" if args.check else "BUILT"}: {len(OUTPUTS)} files; '
          f'28 candidate textures; 6 node-box proposals; 24 choices; standalone HTML.')


# Page generation and local validation are below; candidates never depend on HTML.

THREAD_COPY = {
    'a': ('Wooden spool', 'A firm wooden silhouette and pale winding. The loose end says thread even at 16 px.'),
    'b': ('Yarn ball', 'Soft, round and almost entirely fibre. Broad crossing strands distinguish it from a smooth stone.'),
    'c': ('Tied skein', 'A long folded bundle with a warm central tie. More handmade; less instantly familiar at native size.'),
}
MACHINE_COPY = {
    'grinder_a': ('Hand quern', 'Two broad millstones, a turning handle and a divided catch tray. A quiet, substantial workshop tool.',
                  'The exposed stones make grinding legible. Its low silhouette leaves the hall and the Stonewright visible.'),
    'grinder_b': ('Twin rollers', 'A timber hopper feeds two ribbed stone rollers. A front crank and output tray show the material path.',
                  'The mechanism reads clearly from the front; the timber frame competes more with the hall posts.'),
    'grinder_c': ('Stamp mill', 'Two iron-shod stamps hang at different heights over a stone mortar. A tall timber gantry frames the work.',
                  'The strongest distant silhouette, but taller and visually busier behind a service NPC.'),
    'furnace_a': ('Banded shaft', 'A heavy firebrick shaft with iron straps, a recessed cold grate and a pouring lip over an ingot mould.',
                  'The shaft, grate and casting mould identify a smelting furnace immediately, with a compact footprint.'),
    'furnace_b': ('Crucible hearth', 'An open, cold crucible below a short rear hood, with closed bellows and two cooled castings at the front.',
                  'The clearest metalworking detail from above. Its bowl is harder to read from a level front view.'),
    'furnace_c': ('Vaulted hearth', 'A broad stepped arch, a low hood and an attached mould bench. Soot and the worn hearth lip suggest long use.',
                  'A generous workshop centrepiece. The three-cell width needs more wall space in the existing hall.'),
}
STONE_COPY = {
    'a': ('Running inlay', 'An open, stepped ribbon runs diagonally across the stone. Higher tiers add small metal returns between the ribbons.',
          'My pick for all five tiers: the ornament continues across a wall without outlining each block. The same route keeps the family recognisable.'),
    'b': ('Quarry seal', 'A forged lozenge around a small metal boss; additional points and corner marks build a formal heraldic rhythm.',
          'Strong as a single accent or throne-room pier. Its regular seals are deliberately more visible on a whole wall.'),
    'c': ('Metal sprig', 'A cut sprig rises through the face, adding leaves as the metal tier rises. A softer ornamental language.',
          'The richest individual decoration. The repeated leaf silhouette is more decorative and less architectural than A.'),
}


def pick(group, variant, recommended=False):
    return (f'<label class="pick-control"><input type="radio" name="{group}" value="{variant.upper()}">'
            f'<span>Choose {variant.upper()}</span></label>'
            + ('<span class="recommend">My pick</span>' if recommended else ''))


def title(letter, name):
    return f'<div class="card-title"><span class="letter">{letter.upper()}</span><h3>{name}</h3></div>'


def build_page(shipped, specs, textures):
    css=(HERE/'style.css').read_text()
    js=(HERE/'picks.js').read_text()
    out=['<!doctype html><html lang="en"><head><meta charset="utf-8">',
         '<meta name="viewport" content="width=device-width, initial-scale=1">',
         '<meta name="color-scheme" content="light dark">',
         '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; img-src data:; style-src \'unsafe-inline\'; script-src \'unsafe-inline\'; connect-src \'none\'; base-uri \'none\'; form-action \'none\'">',
         '<title>Grudgelands · Round 70 art studies</title><style>',css,'</style></head><body>',
         '<a class="skip" href="#thread">Skip to the proposals</a>',
         '<header><div class="topline"><a href="#top" class="brand">GRUDGELANDS <span>/ ART 70</span></a>',
         '<label class="theme">Appearance <select id="theme"><option value="system">System</option><option value="light">Light</option><option value="dark">Dark</option></select></label></div>',
         '<div class="hero" id="top"><p class="eyebrow">The Stonewright studies · 07 November 2026</p>',
         '<h1>Stone, metal<br>&amp; thread.</h1>',
         '<p class="lede">Tools for the mining hall. Ornament earned in the depths.<br>Three directions for each piece, ready for your choice.</p>',
         '<div class="hero-materials">',
         tag(shipped['stone'],'Existing plain stone',64),
         *[tag(shipped[k],n+' Bar, shipped palette',48) for k,n in zip(TIERS,NAMES)],
         tag(IMAGES['candidates/thread/a/thread.png'],'Thread proposal A',64),
         '</div><p class="caption">Existing stone and metal bars · original Thread study</p>',
         '</div><nav aria-label="Sections"><a href="#thread">01 Thread</a><a href="#grinder">02 Grinder</a>',
         '<a href="#furnace">03 Smelting furnace</a><a href="#stone">04 Ornamented stones</a><a href="#selection">Your choices</a></nav></header><main>',
         '<p class="intro">All candidates are proposals. The badges show my recommendations; no choice is preselected. ',
         'Pick each piece independently. Every view is embedded in this page and works offline.</p>',
         '<section id="thread"><div class="section-heading"><p class="eyebrow">01 / Inventory</p><h2>Thread</h2></div>',
         '<p>Pale flax, warm wood, a dark outline. Three silhouettes drawn directly at the game’s native 16 × 16 px. ',
         'Each strip places the candidate between the shipped Stick and Iron Bar.</p>',
         '<div class="current">',tag(shipped['thread_today'],'Current Thread: tinted paper',32),
         '<span>Today: tinted paper</span></div><div class="three-up">']
    for v,(name,desc) in THREAD_COPY.items():
        out.extend(['<article class="card">',title(v,name),'<p>'+desc+'</p><div class="icon-tests">'])
        for size in (16,32,64):
            out.append(f'<div class="inventory-row"><span class="size">{size} px</span><div class="slots">')
            for key,im in [('Stick',shipped['stick']),('Thread '+v.upper(),IMAGES[f'candidates/thread/{v}/thread.png']),('Iron Bar',shipped['iron'])]:
                out.append('<span class="slot">'+tag(im,key,size)+'</span>')
            out.append('</div></div>')
        out.extend(['</div><div class="pick-row">',pick('thread',v,v=='a'),'</div></article>'])
    out.extend(['</div><p class="reason"><strong>My recommendation: A.</strong> The wooden flanges, pale winding and free end give Thread its own silhouette at 16 px. B reads as yarn; C needs a longer look.</p></section>'])
    for kind,number,label in (('grinder','02','Grinder'),('furnace','03','Smelting furnace')):
        out.extend([f'<section id="{kind}"><div class="section-heading"><p class="eyebrow">{number} / Mining hall</p><h2>{label}</h2></div>',
                    '<p>Front elevation at a shared scale, then a hall-corner study in existing stone, cobble and timber. ',
                    'The small wooden figure is 1.8 nodes tall. These are software studies of the proposed geometry, not game captures.</p>',
                    '<div class="three-up machines">'])
        for v in 'abc':
            key=kind+'_'+v; spec=specs[key]
            name,desc,judgement=MACHINE_COPY[key]
            w,h,d=spec['dimensions_xyz']
            out.extend(['<article class="card">',title(v,name),'<p>'+desc+'</p>',
                        '<figure class="front">',tag(IMAGES[f'previews/{key}_front.png'],label+' '+v.upper()+' front elevation',320),
                        '<figcaption>Front · same scale</figcaption></figure>',
                        '<figure class="hall">',tag(IMAGES[f'previews/{key}_hall.png'],label+' '+v.upper()+' in a hall corner',560),
                        '<figcaption>Hall corner · 1.8-node figure</figcaption></figure>',
                        f'<p class="dimensions"><strong>{w} wide × {d} deep × {h} high</strong><br>{spec["occupied_cells"]} occupied cells / {spec["reserved_cells"]} reserved</p>',
                        '<p class="judgement">'+judgement+'</p>',
                        '<details><summary>Construction &amp; textures</summary>',
                        f'<p>Static node boxes in {spec["occupied_cells"]} cells, cut at cell boundaries. {len(spec["boxes"])} authored boxes before cell splitting. No mesh needed. ',
                        'Reserve the stated bounding box plus an open approach in front.</p>',
                        '<p>New 16 × 16 faces, shared where named: '+', '.join(k.replace('_',' ') for k in spec['textures'])+'.</p>',
                        '<p>All textures are opaque. No light source, flames, glow, smoke, particles, movement, sound or service logic. Furnace interiors are cold soot and slag.</p>',
                        '</details><div class="pick-row">',pick(kind,v,v=='a'),'</div></article>'])
        out.extend(['</div><p class="reason"><strong>My recommendation: A.</strong> ',MACHINE_COPY[kind+'_a'][2],'</p></section>'])
    out.extend(['<section id="stone"><div class="section-heading"><p class="eyebrow">04 / Prestige masonry</p><h2>Five metals.<br>One family.</h2></div>',
                '<p>Full blocks only. All three directions use the same new, unframed stone ground and the exact colour ramps of the shipped bars. ',
                'The ornament grows with rank: Iron 4, Steel 5, Silversteel 6, Embersteel 7, Abyssal Steel 8.</p>',
                '<p>Each tile is shown as one cube, its flat face and a 5 × 5 wall with no added grout or random rotations. ',
                'The strip compares all five tiers with the existing plain stone. Each metal can be picked separately.</p>'])
    for v,(name,desc,reason) in STONE_COPY.items():
        out.extend([f'<div class="stone-family" id="stone-{v}">',title(v,name),'<p>'+desc+'</p>',
                    '<div class="family-row"><figure>',tag(shipped['stone'],'Existing plain stone',64),'<figcaption>Plain stone</figcaption></figure>'])
        for k,n in zip(TIERS,NAMES):
            out.extend(['<figure>',tag(IMAGES[f'candidates/stone/{v}/{k}.png'],n+' '+v.upper()+' beside plain stone',64),'<figcaption>'+n+'</figcaption></figure>'])
        out.append('</div><div class="stone-grid">')
        for k,n in zip(TIERS,NAMES):
            face=IMAGES[f'candidates/stone/{v}/{k}.png']
            out.extend(['<article class="stone-card"><h4>'+n+'</h4>',
                        '<div class="stone-alone">',tag(IMAGES[f'previews/stone_{v}_{k}_cube.png'],n+' '+v.upper()+' full block',112),
                        '<div>',tag(face,n+' '+v.upper()+' 16 px face enlarged four times',48),tag(shipped[k],n+' shipped bar',32),'</div></div>',
                        '<figure class="wall">',tag(IMAGES[f'previews/stone_{v}_{k}_wall.png'],n+' '+v.upper()+' wall: five by five identical blocks',160),
                        '<figcaption>5 × 5 wall</figcaption></figure>',
                        '<div class="pick-row">',pick(k,v,v=='a'),'</div></article>'])
        out.extend(['</div><p class="reason">'+reason+'</p></div>'])
    out.extend(['</section><section id="selection"><div class="section-heading"><p class="eyebrow">Your choices</p><h2>The set you want.</h2></div>',
                '<p>Selections stay in this browser when storage is available. Copy the summary and send it with your feedback. ',
                'This page sends nothing and installs nothing.</p><noscript><p>JavaScript is off. You can still inspect every proposal; record your choices manually.</p></noscript>',
                '<div class="selection-grid" id="selection-list"></div>',
                '<label class="summary-label" for="pick-summary">Selection summary</label>',
                '<textarea id="pick-summary" rows="10" readonly>Thread: —\nGrinder: —\nSmelting furnace: —\nIron: —\nSteel: —\nSilversteel: —\nEmbersteel: —\nAbyssal Steel: —</textarea>',
                '<div class="actions"><button type="button" id="copy">Copy choices</button><button type="button" id="reset" class="secondary">Clear choices</button><span id="feedback" role="status" aria-live="polite"></span></div>',
                '</section><section class="notes" id="notes"><p class="eyebrow">About these studies</p>',
                '<p><strong>Compatible, tools only.</strong> No game assets, Lua, recipes, world state or hall templates change in this lane. ',
                'Placement in the six real halls and desktop/web acceptance belong to the installation lane. ',
                'The existing sorter is beside the west wall: the machines require a revised work bay, not insertion into that occupied strip.</p>',
                '<details><summary>Materials, licences &amp; reproduction</summary>',
                '<p>Original candidate pixels and box compositions: GPT-6 Astra, CC0-1.0. Generator and page code: GPL-3.0-or-later. ',
                'Candidates are drawn from coordinates and colour ramps; no existing texture pixels are copied into them. ',
                'The metal ramps match the Round 68 bars by GPT-6 Astra, CC0-1.0.</p>',
                '<p>Comparison textures and hall context: minetest_game contributors, vendored in mods/BASE/default; ',
                'Attribution from the vendored README: stone — Cisoun; cobble — Neuromancer, based on Brane praefect; ',
                'wood and stick — BlockMen; sand — VanessaE; paper — Gambit; stone brick — paramat. These retain CC BY-SA 3.0 Unported. ',
                'Gravel is CC0-1.0, by sofar, derived from Gambit’s light gravel. The source notice below governs the embedded images. ',
                'Modifications: nearest-neighbour enlargement, the current Thread colour tint and shaded hall views. ',
                'Those comparison derivatives retain CC BY-SA 3.0; the original candidates remain CC0.</p>',
                '<p>Licence identifiers: CC0-1.0 (creativecommons.org/publicdomain/zero/1.0/); ',
                'CC BY-SA 3.0 (creativecommons.org/licenses/by-sa/3.0/); GPL-3.0-or-later (gnu.org/licenses/gpl-3.0.html). ',
                'Source: github.com/luanti-org/minetest_game, vendored commit b5243f3. No external resources are requested by this page.</p>',
                '<p>Rebuild from the repository root: <code>python3 tools/r70_art/build.py</code>; verify with <code>--check</code>. ',
                'Every candidate, geometry file, comparison, render and this page is reproduced byte for byte. ',
                'Fronts and hall views are an orthographic renderer of the same JSON boxes. They do not simulate game lighting or final node-box UVs.</p>',
                '<details><summary>Full vendored media notice</summary><pre>',html.escape(source_text('mods/BASE/default/license.txt')),
                '</pre></details></details></section></main><footer>GRUDGELANDS · ROUND 70 ART · PROPOSALS BY GPT-6 ASTRA</footer><script>',js,'</script></body></html>'])
    emit('page.html',''.join(out))


def build_contact_sheet():
    sheet=Image.new('RGB',(1200,1100),'#e2dfd4')
    d=ImageDraw.Draw(sheet)
    d.text((24,12),'ROUND 70 / ORIGINAL PIXEL STUDIES — A, B, C',fill='#262c2b')
    for col,v in enumerate('abc'):
        x=24+col*400
        d.text((x,40),'Thread '+v.upper(),fill='#262c2b')
        for size,dx in ((16,0),(32,48),(64,110)):
            im=IMAGES[f'candidates/thread/{v}/thread.png'].resize((size,size),NEAREST)
            sheet.paste(im,(x+dx,64),im)
        for row,kind in enumerate(('grinder','furnace')):
            im=IMAGES[f'previews/{kind}_{v}_hall.png'].resize((380,285),NEAREST)
            sheet.paste(im,(x,150+row*290),im)
            d.text((x,136+row*290),kind.title()+' '+v.upper(),fill='#262c2b')
        d.text((x,737),'Stone '+v.upper()+' / native face and 5 x 5 wall',fill='#262c2b')
        for tier,k in enumerate(TIERS):
            im=IMAGES[f'candidates/stone/{v}/{k}.png'].resize((48,48),NEAREST)
            sheet.paste(im,(x+tier*70,762))
            im=IMAGES[f'previews/stone_{v}_{k}_wall.png'].resize((70,70),NEAREST)
            sheet.paste(im,(x+tier*70,830))
        im=IMAGES[f'previews/stone_{v}_abyssal_steel_wall.png'].resize((160,160),NEAREST)
        sheet.paste(im,(x,920))
    emit('previews/overview.png',sheet)


def build_licences():
    rows=['# Round 70 ART media inventory\n\nGenerated by `build.py`. Every PNG is listed separately.\n\n',
          'Original candidates: **GPT-6 Astra, CC0-1.0**. Original pixel drawings and ',
          'box compositions are dedicated to the public domain under ',
          '[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). ',
          'No existing pixel art is copied into a candidate. Colour ramps follow the shipped bars.\n\n',
          'Context sources: [vendored attribution](../../mods/BASE/default/README.txt), ',
          '[vendored licence](../../mods/BASE/default/license.txt), ',
          '[material media inventory](../../mods/ITEMS/grug_materials/LICENSE-media.md). ',
          'Upstream for default textures: [minetest_game](https://github.com/luanti-org/minetest_game), ',
          'vendored commit `b5243f3` (code/media provenance, not a design reference). ',
          '[CC BY-SA 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/).\n\n',
          '| File | Author / source | Licence | Modification |\n|---|---|---|---|\n']
    context={
        'stone':('Cisoun','CC BY-SA 3.0'),
        'stone_brick':('paramat','CC BY-SA 3.0'),
        'cobble':('Neuromancer, based on Brane praefect','CC BY-SA 3.0'),
        'wood':('BlockMen','CC BY-SA 3.0'),
        'gravel':('sofar, derived from Gambit’s light gravel','CC0-1.0'),
        'sand':('VanessaE','CC BY-SA 3.0'),
        'paper':('Gambit','CC BY-SA 3.0'),
        'stick':('BlockMen','CC BY-SA 3.0'),
    }
    for path in sorted(IMAGES):
        key=Path(path).stem
        if path.startswith('candidates/'):
            who='GPT-6 Astra / original coordinates in build.py'; lic='CC0-1.0'; change='Original work'
        elif path.startswith('context/'):
            if key in TIERS:
                who=f'GPT-6 Astra / grug_materials_{key}_bar.png';lic='CC0-1.0';change='Decoded and re-encoded, pixels unchanged'
            elif key=='thread_today':
                who='Gambit / default_paper.png';lic='CC BY-SA 3.0';change='Current Thread tint #d8d1bd, ratio 115/255'
            else:
                who,lic=context[key];who+=f' / default_{key}.png';change='Decoded and re-encoded, pixels unchanged'
        elif key.endswith('_hall') or key=='overview':
            who='GPT-6 Astra; Cisoun, Neuromancer / Brane praefect, BlockMen (embedded hall textures)'
            lic='CC BY-SA 3.0';change='Original geometry with shaded, tiled source textures; overview also scales and arranges candidates'
        else:
            who='GPT-6 Astra / original candidates';lic='CC0-1.0';change='Nearest-sampled rendering or identical-tile wall'
        rows.append(f'| [{path}]({path}) | {who} | {lic} | {change} |\n')
    rows.append('\n`page.html` embeds these images, including the vendored notice. Existing images and their derived hall renders retain their listed licences; embedding them does not relicense the original candidates. The code (`build.py`, `picks.js`, `style.css`) is GPL-3.0-or-later under the repository [licence](../../LICENSE.txt).\n')
    emit('LICENSE-media.md',''.join(rows))


def validate(specs):
    from html.parser import HTMLParser
    class Audit(HTMLParser):
        def __init__(self):
            super().__init__(); self.ids=set(); self.anchors=[]; self.images=0; self.radios={}
        def handle_starttag(self,tag,attrs):
            a=dict(attrs)
            if 'id' in a:
                assert a['id'] not in self.ids, a['id']
                self.ids.add(a['id'])
            for key in ('href','src'):
                if key in a:
                    assert a[key].startswith(('#','data:image/png;base64,')), a[key]
            if tag=='a':
                self.anchors.append(a['href'][1:])
            if tag=='img':
                raw=base64.b64decode(a['src'].split(',',1)[1],validate=True)
                im=Image.open(io.BytesIO(raw)); im.load()
                assert a.get('alt') and im.width>0
                self.images+=1
            if tag=='input' and a.get('type')=='radio':
                self.radios.setdefault(a['name'],[]).append(a['value'])
                assert 'checked' not in a
            assert tag not in ('iframe','object','embed','link'),tag
    audit=Audit();audit.feed(OUTPUTS['page.html'].decode())
    assert set(audit.anchors)<=audit.ids
    assert len(audit.radios)==8 and all(sorted(v)==list('ABC') for v in audit.radios.values())
    for path,im in IMAGES.items():
        if not path.startswith('candidates/'):
            continue
        assert im.size==(16,16) and im.mode=='RGBA',path
        alpha=set(im.getchannel('A').tobytes())
        assert alpha==({0,255} if '/thread/' in path else {255}),path
    for spec in specs.values():
        for path in spec['textures'].values():
            assert 'candidates/machines/'+path.removeprefix('../') in OUTPUTS
    emit('audit.json',json_text({'html_images_decoded':audit.images,'choice_groups':8,
        'choices':24,'all_candidates_native_16px':True,'candidate_textures':28,
        'machine_geometry_files':6,'static_html_resource_audit':'pass',
        'browser_or_game_acceptance':'not claimed'}))


if __name__=='__main__':
    main()
