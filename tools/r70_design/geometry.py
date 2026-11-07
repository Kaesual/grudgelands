"""Conservative design checks against exported template cells, not engine paths."""
import json
from functools import lru_cache
from pathlib import Path

HERE=Path(__file__).resolve().parent
RAW=json.loads((HERE/'data/geometry.json').read_text())
NODES=json.loads((HERE.parent/'building_templates/nodes.json').read_text())

@lru_cache(None)
def cells(key, ident):
    b=next(b for b in RAW['places'][key]['buildings'] if b['id']==ident)
    return {(x,y,z):RAW['names'][name-1] for x1,x2,y,z,name in b['runs'] for x in range(x1,x2+1)}

def solid(name):
    # The template gate treats door leaves/hidden halves as passable too.
    if name is None or name=='air' or name=='doors:hidden' or name.startswith('doors:door_'):
        return False
    # These composition plants are absent from the editor's node subset.
    # Their definitions in mods/BASE/default/nodes.lua set walkable=false.
    if name=='default:junglegrass' or any(name.startswith('default:'+p) for p in ['grass_','dry_grass_','fern_']):
        return False
    return NODES.get(name,{}).get('walkable',True)

def blocked(key,b,x,y,z,shifts):
    dx,dz=shifts.get(b['id'],(0,0))
    name=cells(key,b['id']).get((x-dx,y,z-dz))
    return name if solid(name) else None

def contains(b,x,z,margin=0):
    return b[0]-margin<=x<=b[2]+margin and b[1]-margin<=z<=b[3]+margin

def distance(b,x,z):
    return max(b[0]-x,0,x-b[2],b[1]-z,0,z-b[3])

def road_boxes(roads):
    for flat,width in roads:
        pts=list(zip(flat[::2],flat[1::2]));half=(width-1)//2
        for (ax,az),(bx,bz) in zip(pts,pts[1:]):
            assert ax==bx or az==bz, 'Only orthogonal streets are reserved'
            yield [ax-half,min(az,bz),ax+half,max(az,bz)] if ax==bx else [min(ax,bx),az-half,max(ax,bx),az+half]

@lru_cache(None)
def composition(key):
    return {(x,y,z):RAW['names'][name-1]
            for x1,x2,y,z,name in RAW['places'][key]['composition_runs'] for x in range(x1,x2+1)}
