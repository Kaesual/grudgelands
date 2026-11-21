"""Presentation plates from the same packed node cells and tile atlas as the live view."""
import base64
import io
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from sites import FACTIONS, GOLD, LAMP, SLAB
import smoke

INK = '#172226'
PAPER = '#f0e4cc'
MUTED = '#a4b0ac'
GILT = '#d9b779'
EAST = '#468699'
WEST = '#a55747'


def font(size):
    return ImageFont.load_default(size=size)


def unit(v):
    return v / np.linalg.norm(v)


def sky(dx, dy, dz):
    # A matte beyond the survey boundary. It has no corresponding world cells.
    az = np.arctan2(dx, dz)
    elev = dy / np.sqrt(dx*dx + dz*dz + .00001)
    def band(e, lo, hi, c0, c1):
        t = np.clip((e-lo)/(hi-lo),0,1)[...,None]
        return np.array(c0)+(np.array(c1)-c0)*t
    rgb = band(elev,0,.62,(226,207,168),(113,145,151))
    low = .038 + .018*np.cos(az*11)+.013*np.sin(az*22)+.003*np.sin(az*57)
    near = .008 + .009*np.sin(az*13)+.007*np.cos(az*31)
    pine = np.maximum(0,np.cos(az*306))**2 * (.004+.005*np.sin(az*79)**2)
    for line,col in ((low,(164,164,145)),(near+pine,(122,139,125))):
        t = np.clip((line-elev)*720,0,1)[...,None]
        rgb += (col-rgb)*t
    ground = band(elev,-.65,-.003,(100,87,72),(151,143,119))
    return np.where((elev < -.006)[...,None],ground,rgb).astype(np.float32)


class Camera:
    def __init__(self, pose, w, h):
        a,b,fov = pose
        self.eye = np.array(a,dtype=np.float32)
        fwd = unit(np.array(b)-self.eye)
        right = unit(np.cross([0,1,0],fwd))
        up = np.cross(fwd,right)
        self.basis = np.array([right,-up,fwd],dtype=np.float32)
        self.f = h/(2*math.tan(math.radians(fov)/2))
        self.w,self.h = w,h
        horizontal = (np.arange(w,dtype=np.float32)+.5-w/2)/self.f
        vertical = (np.arange(h,dtype=np.float32)+.5-h/2)/self.f
        self.ray = (fwd[:,None,None]+right[:,None,None]*horizontal[None,None,:]
                    -up[:,None,None]*vertical[None,:,None]).astype(np.float32)

    def bounds(self, corners):
        p = (np.array(corners)-self.eye) @ self.basis.T
        if p[:,2].max()<=.05: return None
        if p[:,2].min()<=.05: return 0,self.w,0,self.h
        screen = p[:,:2]/p[:,2,None]*self.f+[self.w/2,self.h/2]
        x,y = np.floor(screen.min(axis=0)).astype(int)
        u,v = np.ceil(screen.max(axis=0)).astype(int)
        if u<=0 or x>=self.w or v<=0 or y>=self.h: return None
        return max(0,x),min(self.w,u),max(0,y),min(self.h,v)


class Plates:
    def __init__(self, cells, rotations, types, images, smoke_index):
        self.cells = cells
        self.types = types
        ids = {t['name']:i+1 for i,t in enumerate(types)}
        xyz = np.array(list(cells))
        self.lo = xyz.min(axis=0)-2  # World centre of the first whole cell.
        self.grid = np.zeros(xyz.max(axis=0)-self.lo+3, dtype=np.uint8)
        self.grid[tuple((xyz-self.lo).T)] = [ids[n] for n in cells.values()]
        self.heights = np.max(np.where(self.grid!=0,np.arange(self.grid.shape[1])[None,:,None]+self.lo[1],-50),axis=1)
        # The registered blocks, slabs and stair boxes all fall on a half-node
        # lattice. Keep whole-node texture scale and split only the geometry.
        self.grid = self.grid.repeat(2,0).repeat(2,1).repeat(2,2)
        for pos, name in cells.items():
            mask = types[ids[name]-1].get('octants')
            if mask is None: continue
            corner = 2*(np.array(pos)-self.lo)
            bits = mask[rotations.get(pos,0)]
            for i in range(8):
                if not bits & (1<<i):
                    self.grid[tuple(corner+[i&1,(i>>1)&1,i>>2])] = 0
        self.tiles = np.array([[0]*6]+[t['tex'] for t in types])
        textures = [Image.open(io.BytesIO(base64.b64decode(url.split(',')[1]))).convert('RGB') for url in images]
        self.atlas = np.stack([np.array(im.resize((32,32),Image.Resampling.NEAREST)) for im in textures])
        self.means = self.atlas.mean(axis=(1,2)).astype(np.float32)
        raw = base64.b64decode(images[smoke_index].split(',')[1])
        self.smoke_tile = np.array(Image.open(io.BytesIO(raw)).convert('RGBA'))
        self.faces = []
        # A plane handles all exposed coplanar unit faces in one indexed operation.
        for axis in range(3):
            b,c = (k for k in range(3) if k!=axis)
            for side in (-1,1):
                exposed = (self.grid!=0) & (np.roll(self.grid,-side,axis=axis)==0)
                for a in np.flatnonzero(exposed.any(axis=(b,c))):
                    plane = exposed.take(a,axis)
                    u,v = np.nonzero(plane)
                    coord = self.lo[axis] - .25 + a*.5 + side*.25
                    corners = []
                    for ib in (u.min()-.5,u.max()+.5):
                        for ic in (v.min()-.5,v.max()+.5):
                            p = [0.,0.,0.]; p[axis],p[b],p[c] = coord,self.lo[b]-.25+ib*.5,self.lo[c]-.25+ic*.5
                            corners.append(p)
                    self.faces.append((axis,b,c,side,coord,np.where(plane,self.grid.take(a,axis),0),corners))
        self.lamp_id = ids[LAMP]

    def render(self, pose, size=(1120,640), survey=False):
        cam = Camera(pose,*size)
        rays,eye = cam.ray,cam.eye
        depth = np.full(size[::-1],np.inf,dtype=np.float32)
        face = np.zeros_like(depth,dtype=np.uint8)
        node = np.zeros_like(face)
        for axis,b,c,side,coord,plane,corners in self.faces:
            dist = coord-eye[axis]
            if dist*side>=0: continue
            bounds = cam.bounds(corners)
            if not bounds: continue
            x,u,y,v = bounds
            cut = np.s_[y:v,x:u]
            ray = rays[:,y:v,x:u]
            with np.errstate(divide='ignore',invalid='ignore'):
                t = dist/ray[axis]
            candidate = (t>.05)&(t<depth[cut])
            yy,xx = np.nonzero(candidate)
            if not yy.size: continue
            time = t[yy,xx]
            ib = np.floor(2*(eye[b]+.5-self.lo[b]+time*ray[b,yy,xx])).astype(int)
            ic = np.floor(2*(eye[c]+.5-self.lo[c]+time*ray[c,yy,xx])).astype(int)
            inside = (ib>=0)&(ic>=0)&(ib<plane.shape[0])&(ic<plane.shape[1])
            yy,xx = yy[inside],xx[inside]
            mat = plane[ib[inside],ic[inside]]
            hit = mat!=0
            yy,xx = yy[hit]+y,xx[hit]+x
            depth[yy,xx] = time[inside][hit]
            face[yy,xx] = ((2,3),(0,1),(4,5))[axis][side<0]
            node[yy,xx] = mat[hit]
        if survey:
            silhouette = Image.fromarray(np.uint8(node!=0)*255)
            shadow = np.asarray(silhouette.filter(ImageFilter.GaussianBlur(12)))/255
            shade = np.roll(shadow,9,axis=0)[...,None]
            fade = np.linspace(1,.68,cam.h)[:,None,None]
            rgb = (np.array([65,74,72]) * fade * (1-.42*shade)).astype(np.float32)
        else:
            rgb = sky(*rays)
        yy,xx = np.nonzero(node)
        t = depth[yy,xx]
        x,y,z = eye[:,None]+rays[:,yy,xx]*t
        f,n = face[yy,xx],node[yy,xx]
        tex = self.tiles[n,f]
        us = np.choose(f,[x,x,z,-z,-x,x])+.5
        vs = np.choose(f,[z,-z,y,y,y,y])+.5
        col = self.atlas[tex,(np.floor(-vs*32).astype(int)%32),(np.floor(us*32).astype(int)%32)].astype(np.float32)
        # Coarser distant sampling suppresses pattern shimmer on the road.
        mip = np.clip((t-11)/100,0,.7)[:,None]
        col += (self.means[tex]-col)*mip
        light = np.choose(f,[1.05,.65,.83,.82,.95,.89])
        # Bent daylight near masonry, sampled toward the sky over the actual site.
        occlusion = np.zeros(len(x),np.float32)
        for dx,dz,height,weight in ((1,1,1.6,.12),(2,2,3,.09),(4,3,5.5,.08),(7,5,8,.07)):
            ix = np.clip(np.floor(x+dx+.5).astype(int)-self.lo[0],0,self.heights.shape[0]-1)
            iz = np.clip(np.floor(z+dz+.5).astype(int)-self.lo[2],0,self.heights.shape[1]-1)
            occlusion += (self.heights[ix,iz]>y+height)*weight
        lum = np.where(n==self.lamp_id,1.22,light*(1-occlusion))
        col *= lum[:,None]
        fog = np.clip((t-16)/330,0,.75)**1.6
        col += (np.array([192,187,162])-col)*fog[:,None]
        rgb[yy,xx] = col
        self.draw_smoke(cam,depth,rgb)
        return Image.fromarray(np.uint8(np.clip(rgb,0,255)))


    def draw_smoke(self, cam, depth, rgb):
        fx = smoke.effect()
        sprites = [((np.array(p['at'])-cam.eye) @ cam.basis.T, p) for p in fx['puffs']]
        for (px,py,z), p in sorted(sprites,key=lambda v:-v[0][2]):
            if z <= .05: continue
            size = p['size']*cam.f/z
            left = cam.w/2 + px*cam.f/z - size/2
            top = cam.h/2 + py*cam.f/z - size/2
            l,r = max(0,math.ceil(left-.5)), min(cam.w,math.ceil(left+size-.5))
            t,b = max(0,math.ceil(top-.5)), min(cam.h,math.ceil(top+size-.5))
            if l>=r or t>=b: continue
            u = np.clip(((np.arange(l,r)+.5-left)*self.smoke_tile.shape[1]/size).astype(int),0,self.smoke_tile.shape[1]-1)
            v = np.clip(((np.arange(t,b)+.5-top)*self.smoke_tile.shape[0]/size).astype(int),0,self.smoke_tile.shape[0]-1)
            tex = self.smoke_tile[v[:,None],u]
            alpha = tex[:,:,3] / 255 * p['alpha'] * (z < depth[t:b,l:r])
            rgb[t:b,l:r] += (tex[:,:,:3] * (np.array(fx['tint'])/255) - rgb[t:b,l:r]) * alpha[:,:,None]


def plan(site, ground, field, halls):
    scale = 7
    im = Image.new('RGB', (1120,838), INK)
    d = ImageDraw.Draw(im)
    dx,dy = 52,79
    def point(x,z):
        return dx+(x+site.rx+.5)*scale, dy+(site.rz-z+.5)*scale
    def tile(x,z,col):
        a,b = point(x,z)
        d.rectangle((a-3.5,b-3.5,a+2.5,b+2.5),fill=col)
    d.text((42,17),'Breach Road',font=font(32),fill=PAPER)
    d.text((254,30),'SURVEY OF THE TERRACES',font=font(15),fill=GILT)
    road, gallery, upper, rim = '#837763','#ab8964','#dbb984','#505e58'
    for (x,z),y in ground.heights.items():
        col = {0:road,3:gallery,6:upper}.get(y,rim)
        if (x,z) in ground.rim: col = rim
        if abs(x)<=3: col='#b0a28a'
        if (x,z) in ground.stairs: col='#f4dfb9'
        tile(x,z,col)
    for (x,z),fd in ground.stairs.items():
        a,b = point(x,z)
        if fd%2: d.line((a+(-2 if fd==1 else 2),b-3,a+(-2 if fd==1 else 2),b+3),fill=INK)
        else: d.line((a-3,b+(2 if fd==0 else -2),a+3,b+(2 if fd==0 else -2)),fill=INK)
    for (x,y,z),mat in field.items():
        if y>ground.heights[x,z]:
            tile(x,z,'#605b58' if mat==SLAB else '#454c4b')
    for faction in FACTIONS:
        m = halls[faction]
        for (u,y,v),mat in m.items():
            if y: continue
            x,_,z = site.place(faction,u,y,v)
            col = EAST if faction=='accord' else WEST
            if u>=12: col = '#93785c'
            if (u,2,v) in m: col = '#333c3e'
            if u==12 and mat==GOLD: col = '#ffe06a'
            if (u,v)==(4,0): col = '#fff6e3'
            tile(x,z,col)
    for x,_,z in smoke.EMITTERS:
        a,b = point(x,z)
        d.ellipse((a-7,b-7,a+7,b+7),outline='#222d31',width=4)
        d.ellipse((a-6,b-6,a+6,b+6),outline='#f2c188',width=2)
        d.line((a-2,b,a+2,b),fill=PAPER)
    for x in range(-40,41,10):
        a,_=point(x,0)
        d.text((a,dy-8),str(x),anchor='ms',font=font(12),fill=MUTED)
    for z in range(-40,41,10):
        _,b=point(0,z)
        d.text((dx-8,b),str(z),anchor='rm',font=font(12),fill=MUTED)
    right=789
    def label(y,txt,size=17,col=PAPER): d.text((right,y),txt,font=font(size),fill=col)
    label(80,'North up    /    +z north, +x east',15,GILT)
    label(115,'99 by 91 nodes',30)
    label(159,'Roofs lifted · origin on road',17,MUTED)
    for i,(color,txt) in enumerate(((road,'0     Road and apron'),(gallery,'+3   Ruined galleries'),
            (upper,'+6   Halls and lookout spurs'),('#efe1c8','|||    Stair flight · 5 wide'),
            (rim,'Graded biome fringe'),('#454c4b','Masonry, stumps and rocks'),
            (EAST,'The Accord · friendly interior'),(WEST,'The Throng · friendly interior'),
            ('#ffe06a','Bronze sill'),('#fff6e3','Waystone marker'))):
        y=220+i*29
        d.rectangle((right,y+3,right+17,y+17),fill=color)
        d.text((right+29,y),txt,font=font(16),fill=PAPER)
    d.ellipse((right,540,right+14,554),outline='#f2c188',width=2)
    d.text((right+25,535),'Smoke wells',font=font(19),fill=GILT)
    for i,(x,y,z) in enumerate(smoke.EMITTERS):
        label(568+25*i, f'{("E","W")[i]}   ({x:+d}, {y:+g}, {z:+d})',16)
    label(625,'Emitter centres (x, y, z)',14,MUTED)
    for k in range(2):
        d.rectangle((right+k*10*scale,687,right+(k+1)*10*scale,694),fill=PAPER if k==0 else '#827764')
    label(704,'0                10               20 nodes',13,MUTED)
    d.line((42,739,1078,739),fill='#566160')
    d.text((42,753),'Gate to gate at z = +9',font=font(17),fill=PAPER)
    d.text((42,780),'West to east · elevations in nodes',font=font(14),fill=MUTED)
    def section(x,h):
        return 689+x*13,809-h*7
    for x in range(-23,24):
        h=ground.heights[x,9]
        col={0:road,3:gallery,6:upper}.get(h,gallery)
        for half in (-.25,.25):
            level=h
            if (x,9) in ground.stairs:
                fd=ground.stairs[x,9]
                if (half<0)==(fd==1): level-=.5
            a,b=section(x+half-.25,level)
            d.rectangle((a,b,a+6.5,816),fill=col)
    for x,h in ((-22,6),(-14,3),(0,0),(14,3),(22,6)):
        a,b=section(x,h)
        d.text((a,b-3),f'{h:+d}' if h else '0',anchor='ms',font=font(15),fill=PAPER)
    return im


def overview(sites, plates):
    im=Image.new('RGB',(1460,1039),INK)
    d=ImageDraw.Draw(im)
    d.text((28,18),'Breach Road',font=font(38),fill=PAPER)
    d.text((29,72),'Identical cameras at the north approach and above the site',font=font(19),fill=MUTED)
    for i,s in enumerate(sites):
        x=28+i*716
        d.text((x,120),s.name if i==0 else 'Second pass',font=font(27),fill=GILT)
        d.text((x,158),s.summary,font=font(17),fill=PAPER)
        for key,y,title in [('arrival',200,'Road approach'),('aerial',620,'Whole site')]:
            plate = plates[s.key,key]
            if key=='aerial': plate = plate.crop((67,67,1047,627))
            im.paste(plate.resize((688,393),Image.Resampling.LANCZOS),(x,y))
            d.text((x,y+395),title,font=font(15),fill=MUTED)
    return im
