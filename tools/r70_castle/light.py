"""Offline night bank from the engine's node-light rules, with no sky/fill light.

Source: pinned Luanti src/script/common/c_content.cpp (CPT_LIGHT propagation),
src/voxelalgorithms.cpp::spread_light (six neighbours, minus one per step),
src/light.cpp::set_light_curve and src/defaultsettings.cpp (display curve).
The registry supplies paramtype and light_source. This models the bank, not
the client's shaders, bloom, auto exposure, ambient moonlight or smooth light.
"""
from collections import deque
import math
from statistics import median

DIRECTIONS=((1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1))


def propagate(cells,registry):
    """Finite source flood; absent cells are air, opaque nodes block it.

    No world boundary is needed: every source has finite level <= 14.
    Even opaque emitters seed the bank, as they do in the engine.
    """
    opaque={p for p,(name,_) in cells.items()
            if name!='air' and registry[name].get('paramtype')!='light'}
    bank={p:int(registry[name].get('light_source',0))
          for p,(name,_) in cells.items() if registry[name].get('light_source',0)}
    assert all(0<v<=14 for v in bank.values())
    queue=deque(sorted(bank,key=lambda p:-bank[p]))
    while queue:
        x,y,z=queue.popleft(); level=bank[x,y,z]-1
        if level<=0: continue
        for dx,dy,dz in DIRECTIONS:
            q=x+dx,y+dy,z+dz
            if q not in opaque and bank.get(q,0)<level:
                bank[q]=level; queue.append(q)
    return bank


def measure(bank,heads,king):
    values=[bank.get(p,0) for p in heads]
    return {'columns':len(values),'median':median(values),
            'at_most_3':sum(v<=3 for v in values),'zero':values.count(0),
            'min':min(values),'max':max(values),'king_head':bank.get(king,0),
            'histogram':[values.count(v) for v in range(15)]}


def display_curve():
    """Engine default LUT, gamma 1.0; sRGB brightness, no exposure uplift."""
    table=[0]
    for level in range(1,15):
        x=level/15
        value=(-.5*x+1.5)*x*x+.2*math.exp(-.5*((x-.5)/.2)**2)
        table.append(max(table[-1]+1,min(254,int(255*value))))
    return table+[255]


LUT=display_curve()


def linear_brightness(level):
    s=LUT[int(level)]/255
    return s/12.92 if s<=.04045 else ((s+.055)/1.055)**2.4


def decode_scene(payload,key):
    """Decode the shared viewer's packed x,y,z,type,param2 cells."""
    import base64
    import struct
    scene=payload['scenes'][key]
    raw=base64.b64decode(scene['cells'])
    assert len(raw)==scene['count']*9
    return {(x,y,z):(payload['types'][t]['name'],p2)
            for x,y,z,t,p2 in struct.iter_unpack('<hhhHB',raw)}
