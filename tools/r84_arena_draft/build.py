#!/usr/bin/env python3
"""Build the templates, survey plates and portable arena comparison, or verify with --check."""
import argparse
import base64
from collections import deque
import io
import json
import math
from pathlib import Path
import string
import sys

from PIL import Image

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT/'tools/building_templates/viewer'))
import build_viewer as viewer
import templates

from sites import FACTIONS, FIRST, FLIGHTS, GOLD, LAMP, SITE, STAIR, Ground, field, hall, poses, surroundings
import smoke
from plates import Plates, overview, plan


def template(site, faction, model):
    # Store each hall already facing the road, with a normal 0-based pivot.
    east = faction=='accord'
    def local(u,v):
        return (20-u,15-v) if east else (u,15+v)
    def point(group,u,y,v,attrs):
        x,z = local(u,v)
        return f'{group} {x} {y} {z} {attrs}'
    cells = {}
    for (u,y,v),name in model.items():
        x,z = local(u,v)
        cells[x,y,z] = name
    sy = max(y for _,y,_ in cells)+1
    keys = dict(zip(sorted(set(cells.values())),string.ascii_uppercase))
    name = f'{site.key}_{faction}'
    out = ['grudgelands-building-template 1',f'name {name}','pivot 21 31','origin 0 0 0',
           f'size 21 {sy} 31','cell 1','races '+('human' if east else 'orc'),'','legend']
    out += [f'{key} node {material}' for material,key in keys.items()]
    out.append('end')
    for y in range(sy):
        out += ['',f'layer {y}']
        for z in range(31):
            out.append('|'+''.join(keys.get(cells.get((x,y,z)),'.') for x in range(21))+'|')
    face = 3 if east else 1
    out += ['','points',point('inside',6,1,0,'id=muster'),point('sockets',5,1,0,'id=arrival'),
            point('arena_marker',4,1,0,'id=waystone')]
    for v in (-8,8):
        out += [point('doors',12,1,v,f'face={face} id=sill_{v+8}'),
                point('arena_exit',20,1,(-10 if v<0 else 10),f'face={face}')]
    for x,z in ((1,1),(11,29)) if not east else ((9,1),(19,29)):
        out.append(f'room_corner {x} 0 {z} top=7 closed=true id=muster')
    out += ['end','']
    txt = '\n'.join(out)
    path = HERE/'templates'/f'{name}.tpl'
    read = templates.parse_template(str(path),txt)
    assert read.pivot==(21,31) and read.size==(21,sy,31)
    assert len(read.cells)==21*sy*31 and templates.UNCHANGED not in read.cells.values()
    solids = {p:read.legend[k]['name'] for p,k in read.cells.items() if k!=templates.FORCE_AIR}
    assert solids==cells
    return path,txt,solids


def verify_site(site, ground, cells, halls):
    def clear(x,z):
        h = ground.heights[x,z]
        assert (x,h,z) in cells
        assert all((x,h+i,z) not in cells for i in (1,2,3)), (x,h,z)
    for x in range(-3,4):
        for z in range(-site.rz,site.rz+1):
            assert ground.heights[x,z]==0
            clear(x,z)
    for x,z,dx,dz,width,base,rise in FLIGHTS:
        for sign in (-1,1):
            for w in range(-width,width+1):
                for i in range(-1,rise+1):
                    xx,zz = sign*(x+dx*i+dz*w),sign*(z+dz*i+dx*w)
                    clear(xx,zz)
                    assert ground.heights[xx,zz] == base + min(rise,max(0,i+1))
                    if 0 <= i < rise:
                        assert cells[xx,ground.heights[xx,zz],zz] == STAIR
                        assert ground.stairs[xx,zz] == (1 if dx else 0) + (2 if sign<0 else 0)
    # Three adjacent rider lines between each gateway and the centre road.
    for sign in (-1,1):
        for z in (8,9,10,-8,-9,-10):
            for x in range(23):
                clear(sign*x,sign*z)
    for x,z in ground.flank_paths:
        assert ground.heights[x,z] == 0
        clear(x,z)
    # Eye-to-eye rays from each crown to three positions on the centre road.
    # Test even partial blocks as whole cubes to give a conservative sightline.
    for sign in (-1,1):
        start = (17*sign,8,22*sign)
        for road_z in (3,5,7):
            end = (0,2,road_z*sign)
            assert 23 < math.dist(start,end) < 27
            for i in range(161):
                voxel = tuple(math.floor(a+(b-a)*i/160+.5) for a,b in zip(start,end))
                assert voxel not in cells, voxel
    for x,y,z in smoke.EMITTERS:
        assert cells[x,int(y),z] and (x,int(y)+1,z) not in cells
    for faction,m in halls.items():
        for v in range(-6,6):
            assert all((7,y,v) not in m for y in (1,2))
        assert m[4,2,0]==LAMP
        for sign in (-1,1):
            # Each exit has its own path from the stone to the field, with
            # the other return court excluded from the search.
            start = (5,0)
            seen, todo = {start},deque([start])
            while todo:
                u,v = todo.popleft()
                for du,dv in ((1,0),(-1,0),(0,1),(0,-1)):
                    p = (u+du,v+dv)
                    if p in seen or not (1<=p[0]<=20 and 0<=sign*p[1]<=14): continue
                    x,_,z = site.place(faction,p[0],0,p[1])
                    if (x,6,z) in cells and all((x,y,z) not in cells for y in (7,8)):
                        seen.add(p); todo.append(p)
            assert (20,sign*10) in seen and (12,sign*8) in seen
            assert all(m[12,0,sign*v]==GOLD for v in range(6,10))
            # Every ray between the paired door rectangles crosses the middle
            # plane between their extreme jambs, below the traverse's top.
            assert all((16,y,sign*v) in m for y in range(1,6) for v in range(5,13))
            assert all((u,y,0) in m for u in range(12,21) for y in range(1,6))
    def occup(faction):
        return {(u,y,v) for u,y,v in halls[faction] if y<=4}
    assert occup('accord')==occup('throng')
    assert len({max(y for _,y,_ in m) for m in halls.values()})==1
    # Verify the high spur has a side stair approach and a level rear way
    # to the hall. Coordinates stop inside the broken breastwork.
    for sign in (-1,1):
        for x,z in [(16,z) for z in range(13,25)] + [(x,24) for x in range(16,29)] + [(28,z) for z in range(16,25)]:
            clear(sign*x,sign*z)
    assert len(ground.stairs)==180


def octants(boxes):
    """Masks for the offline ray renderers, derived from the registered node boxes."""
    masks = []
    for turn in range(4):
        bits = 0
        for i in range(8):
            x,y,z = (.25 if i & axis else -.25 for axis in (1,2,4))
            for _ in range(turn):
                x,z = -z,x
            if any(b[0]<x<b[3] and b[1]<y<b[4] and b[2]<z<b[5] for b in boxes):
                bits |= 1<<i
        masks.append(bits)
    return masks


def image_bytes(im,fmt,**options):
    out = io.BytesIO()
    im.save(out,format=fmt,**options)
    return out.getvalue()


def data_uri(data,kind):
    return 'data:image/'+kind+';base64,'+base64.b64encode(data).decode('ascii')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    def emit(path, data):
        data = data.encode() if isinstance(data,str) else data
        if args.check:
            if not path.exists() or path.read_bytes()!=data:
                raise SystemExit(f'Out of date: {path.relative_to(ROOT)}')
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
    reg = json.loads(Path(viewer.NODES_JSON).read_text())
    ground = Ground()
    terrain = field(ground)
    cells = surroundings(ground)
    cells.update(terrain)
    halls = {}
    for faction in FACTIONS:
        m = halls[faction] = hall(faction)
        path,txt,solids = template(SITE,faction,m)
        emit(path,txt)
        x0 = SITE.back-20 if faction=='accord' else -SITE.back
        cells.update({(x+x0,y+6,z-15):n for (x,y,z),n in solids.items()})
    verify_site(SITE,ground,cells,halls)
    materials = sorted(set(cells.values()))
    for name in materials:
        node = reg['nodes'][name]
        assert node['drawtype'] in ('normal','glasslike','nodebox') and node['liquidtype']=='none'
    emit(HERE/'nodes.json',json.dumps({SITE.key:materials},indent=2)+'\n')
    names, textures, meshes = [],viewer.Textures(),{}
    packed = viewer.pack_cells({'poses':poses()},[(*p,n,ground.stairs.get((p[0],p[2]),0) if n==STAIR else 0)
                                                  for p,n in sorted(cells.items())],{},names)
    types,report = viewer.build_types(names,reg['nodes'],reg['aliases'],textures,meshes)
    for t in types:
        if t['dt']=='nodebox':
            assert all(c in (-.5,0,.5) for box in t['boxes'] for c in box)
            t['octants'] = octants(t['boxes'])
    smoke_index = textures.index(smoke.TEXTURE)
    assert not (report['skipped'] or report['missing_mesh'] or textures.missing)
    rotations = {(x,ground.heights[x,z],z):v for (x,z),v in ground.stairs.items()}
    artist = Plates(cells,rotations,types,textures.images,smoke_index)
    figures, plates = {'breach':{},'first':{}}, {}
    for key,pose in poses().items():
        im = artist.render(pose,survey=key=='aerial')
        if key in ('arrival','accord','throng','inside','aerial','high','side'):
            emit(HERE/'renders'/f'breach_{key}.png',image_bytes(im,'PNG'))
        figures['breach'][key] = data_uri(image_bytes(im,'JPEG',quality=89,subsampling=0),'jpeg')
    # Match the archived camera matrices for the two comparison pairs.
    plates['breach','arrival'] = artist.render(([0,3.5,42],[0,5,-3],64))
    plates['breach','aerial'] = artist.render(([66,89,93],[0,0,8],48),survey=True)
    survey = image_bytes(plan(SITE,ground,terrain,halls),'PNG')
    emit(HERE/'renders/breach_plan.png',survey)
    figures['breach']['plan'] = data_uri(survey,'png')
    # First-pass plates are the original picks, archived losslessly in place.
    for key in ('arrival','aerial','accord','throng','inside','plan'):
        ext = 'jpg' if key=='aerial' else 'png'
        path = HERE/'renders'/f'first_{key}.{ext}'
        im = Image.open(path)
        if key in ('arrival','aerial'): plates['first',key] = im
        if key=='plan': data = data_uri(path.read_bytes(),'png')
        elif key=='aerial': data = data_uri(path.read_bytes(),'jpeg')
        else: data = data_uri(image_bytes(im,'JPEG',quality=89,subsampling=0),'jpeg')
        figures['first'][key] = data
    sheet = overview((FIRST,SITE),plates)
    emit(HERE/'renders/overview.png',image_bytes(sheet,'PNG'))
    payload = {'types':types,'textures':textures.images,'meshes':meshes,'scene':packed,
               'sites':{s.key:vars(s) for s in (SITE,FIRST)},'figures':figures,
               'smoke':dict(texture=smoke_index,**smoke.effect())}
    page = viewer.inline_renderer((HERE/'page.html').read_text())
    page = page.replace('t.colorSpace = THREE.SRGBColorSpace;', 't.encoding = THREE.sRGBEncoding;')
    page = page.replace('img.onload = () => { t.needsUpdate = true; };',
                        'img.onload = () => { t.needsUpdate = true; opts.onTexture?.(); };')
    page = page.replace('__CANVAS__',(HERE/'canvas.js').read_text())
    page = page.replace('__MEDIA__',(HERE/'credits.txt').read_text())
    page = page.replace('__OVERVIEW__',data_uri(image_bytes(sheet,'JPEG',quality=84),'jpeg'))
    page = page.replace('renderer.outputColorSpace = THREE.SRGBColorSpace;', 'renderer.outputEncoding = THREE.sRGBEncoding;')
    for key,p in {'THREE':ROOT/'tools/r54_armor/vendor/three.min.js',
                  'ORBIT':ROOT/'tools/r69_camp_art/orbit.js','LICENSE':ROOT/'tools/r69_camp_art/THREE-LICENSE.txt'}.items():
        page = page.replace('__'+key+'__',p.read_text().replace('</','<\\/'))
    page = page.replace('__DATA__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
    emit(HERE/'index.html',page)
    print(f'PASS · {len(materials)} shipped nodes, {len(ground.heights)} ground columns, '
          '12 stair flights, four screened exits, two parsed halls, plates, comparison and offline page '
          +('reproduced.' if args.check else 'written.'))



if __name__=='__main__':
    main()
