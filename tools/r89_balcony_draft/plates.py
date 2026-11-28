"""Presentation plates from the same packed node cells and tile atlas as the live view."""
import base64
import io
import math

import numpy as np
from PIL import Image, ImageFilter

from halls import LAMP
import smoke

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
        self.details = []
        for pos, name in cells.items():
            kind = types[ids[name] - 1]
            if 'boxes' in kind and 'octants' not in kind:
                self.grid[tuple(np.array(pos) - self.lo)] = 0
                for box in kind['boxes']:
                    ends = np.array(box).reshape(2, 3) + pos
                    self.details.append((ids[name], ends))
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

    def geometry(self, cam):
        size = (cam.w, cam.h)
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
        # The narrow parapet rails and the tall waystones fall between the
        # half-grid planes. Intersect their registered boxes at full precision.
        for material, (lo, hi) in self.details:
            corners = [[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1])
                       for z in (lo[2], hi[2])]
            bounds = cam.bounds(corners)
            if not bounds:
                continue
            x1, x2, y1, y2 = bounds
            region = np.s_[y1:y2, x1:x2]
            directions = rays[:, region[0], region[1]]
            with np.errstate(divide='ignore', invalid='ignore'):
                a = (lo-eye)[:, None, None] / directions
                b = (hi-eye)[:, None, None] / directions
            near = np.minimum(a, b)
            enter = near.max(axis=0)
            hit = (enter > .001) & (enter <= np.maximum(a, b).min(axis=0)) & (enter < depth[region])
            axis = near.argmax(axis=0)
            direction = np.take_along_axis(directions, axis[None, ...], axis=0)[0]
            face[region][hit] = (np.choose(axis, [2, 0, 4]) + (direction > 0))[hit]
            node[region][hit] = material
            depth[region][hit] = enter[hit]
        return depth, face, node

    def render(self, pose, size, survey=False):
        cam = Camera(pose, *size)
        rays, eye = cam.ray, cam.eye
        depth, face, node = self.geometry(cam)
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
