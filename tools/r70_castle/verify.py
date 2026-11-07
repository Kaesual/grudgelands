#!/usr/bin/env python3
"""Static page/media and all-scene geometry QA; no browser or game fixture."""
import base64
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
import io
import json
import math
from pathlib import Path
import re
import subprocess
import tempfile
from PIL import Image
import light

HERE=Path(__file__).resolve().parent

class OfflineHTML(HTMLParser):
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=='script': assert not a.get('src'),'external script'
        for key in ('src','href'):
            if key in a: assert a[key].startswith(('data:','#')), (tag,a[key])


def geometry(race):
    keys=[race+'/'+v for v in ('current','crownward','high_seat','gate_crown')]
    d=json.loads(subprocess.check_output(['node',str(HERE/'geometry.js'),*keys],text=True))
    assert set(d['scenes'])==set(keys)
    triangles=0
    for meshes in d['scenes'].values():
        assert meshes
        for m in meshes:
            assert len(m['position'])%3==0 and len(m['index'])%3==0
            assert len(m['uv'])*3==len(m['position'])*2
            assert len(m['color'])==len(m['position'])
            assert all(math.isfinite(v) for field in ('position','uv','color') for v in m[field])
            assert max(m['index'])<len(m['position'])//3
            assert 0<=m['texture']<len(d['textures'])
            triangles+=len(m['index'])//3
    return race,triangles


def check_throne(payload):
    bronze='grug_materials:bronze_block'
    cap='grug_materials:slab_bronze_block'
    ornaments=['grug_guild:ornamented_'+m for m in
               ('iron','steel','silversteel','embersteel','abyssal_steel')]
    for race in payload['races']:
        key=race+'/crownward'; cells=light.decode_scene(payload,key)
        body={p:n for p,(n,_) in cells.items()
              if 19<=p[0]<=25 and 5<=p[1]<=14 and 28<=p[2]<=30}
        assert tuple(min(p[i] for p in body) for i in range(3))==(20,5,28),key
        assert tuple(max(p[i] for p in body) for i in range(3))==(24,11,30),key
        seat={p for p,n in body.items() if p[1]==6 and p[2]<30 and n.startswith('wool:')}
        assert seat=={(x,6,z) for x in range(21,24) for z in (28,29)},(key,seat)
        assert all(body[x,5,z]==bronze for x in range(20,25) for z in range(28,31)),key
        for x in (20,24):
            assert body[x,7,28]==body[x,7,29]==bronze,key
            assert body[x,8,28]==body[x,8,29]==cap,key
            assert (x,6,29) not in body, (key,'closed arm gap')
        for x,n in zip(range(20,25),ornaments):
            assert [p for p,(name,_) in cells.items() if name==n]==[(x,10,30)],(key,n)
            assert body[x,11,30]==(bronze if x==22 else cap),key
        # Test the actual seat/front, back and all five ornaments from player
        # eye height at the far end. The first occupied cell must be the target.
        for target in [(22,6,28),(22,8,30)]+[(x,10,30) for x in range(20,25)]:
            eye=(22,4.125,9); first=None
            for step in range(1,1001):
                q=tuple(math.floor(a+(b-a)*step/1000+.5) for a,b in zip(eye,target))
                if q in cells:
                    first=q; break
            assert first==target,(key,'throne sightline',target,first)
        # bosses.lua::king_def: player box * (8/7) * elite 1.4 = 0.96 x 2.72.
        # guard.lua + levels.lua: elite guards = 0.84 x 2.38. Test the union
        # from settled dais height (4.5) to initial socket feet (5); treating
        # every occupied cell as a full cube is conservative for slabs/lamps.
        points=payload['scenes'][key]['points']
        assert points['king']==[22,5,27],key
        for name,x,radius,height in (('king',22,.48,2.72),
                                    ('throne_guard_west',19,.42,2.38),
                                    ('throne_guard_east',25,.42,2.38)):
            assert points[name]==[x,5,27],(key,name)
            lo=(x-radius,4.5,27-radius); hi=(x+radius,5+height,27+radius)
            for p in cells:
                overlap=all(lo[i]<p[i]+.5-1e-9 and hi[i]>p[i]-.5+1e-9 for i in range(3))
                assert not overlap,(key,name,'body intersects',p)
            assert (x,4,27) in cells,(key,name,'missing support')
        assert math.isclose(27.5-(27+.48),.02,abs_tol=1e-9)
    print('Crownward: 3 x 2 seat; 5 x 3 x 7 bronze throne; five top stones; '
          'seven sightlines and king/guard bodies clear in all six palettes (king rear gap 0.02).')


def check_lighting(payload):
    # Hand-computed probes guard attenuation and the distinction between
    # collision and light propagation (glass/stairs transmit, wool does not).
    registry={'air':{'paramtype':'light'},'lamp':{'paramtype':'light','light_source':14},
              'stone':{'paramtype':'none'},'glass':{'paramtype':'light'}}
    cells={(0,0,0):('lamp',0)}
    bank=light.propagate(cells,registry)
    assert bank[0,0,0]==14 and bank[4,3,2]==5 and bank.get((14,0,0),0)==0
    cells.update({p:('stone',0) for p in light.DIRECTIONS})
    assert light.propagate(cells,registry)=={(0,0,0):14}
    cells[1,0,0]=('glass',0)
    assert light.propagate(cells,registry)[2,0,0]==12
    assert light.LUT[0]==0 and light.LUT[-1]==255
    assert all(a<b for a,b in zip(light.LUT,light.LUT[1:]))
    registry=payload['light_nodes']
    for form in payload['forms']:
        for race in payload['races']:
            key=race+'/'+form; cells=light.decode_scene(payload,key)
            bank=light.propagate(cells,registry)
            heads=[]
            for x in range(5,40):
                for z in range(9,32):
                    feet=(4 if z==25 else 5) if 15<=x<=29 and 25<=z<=31 else 3
                    if (x,feet,z) not in cells and (x,feet+1,z) not in cells:
                        heads.append((x,feet+1,z))
            result=light.measure(bank,heads,(22,6,27))
            assert result==payload['metrics'][form][race]['night_light'], (key,result)
            assert result['columns']==payload['metrics'][form][race]['hall_reachable']
            # Same metrics as the independent checker's shipped Highcourt sample:
            # median 7; 86/725 dark columns. The king must also be well lit.
            assert result['median']>=7 and result['king_head']>=11, (key,result)
            assert result['at_most_3']/result['columns']<=86/725 and result['zero']==0,(key,result)
            lamps=[p for p,(n,_) in cells.items() if registry[n]['light_source']]
            assert len(lamps)==32, (key,len(lamps))
            # A missing beam row must be caught, even with all side lamps intact.
            damaged={p:v for p,v in cells.items() if not
                     ((p[1]==8 and p[2] in (17,26) and p in lamps) or p==(22,4,27))}
            old=light.measure(light.propagate(damaged,registry),heads,(22,6,27))
            assert old['median']<7 and old['king_head']<11, (key,old)
            # The raised chair must remain visible down the central processional
            # line; no lamp or beam may cross seat, back or crown sightlines.
            for target_y in ((6,8,10) if form=='crownward' else (6,9,12)):
                for step in range(1,190):
                    z=9+step/10; y=4.125+(target_y-4.125)*(z-9)/21
                    q=(22,math.floor(y+.5),math.floor(z+.5))
                    if q[2]<28: assert q not in cells, (key,'blocked throne sightline',q)
        print(f'{form}: all six palettes night median {result["median"]}, '
              f'<=3: {result["at_most_3"]}/{result["columns"]}, zero {result["zero"]}, king {result["king_head"]}.')


def main():
    html=(HERE/'page.html').read_text(); OfflineHTML().feed(html)
    assert len(html.encode())<=15_000_000, 'page exceeds 15 MB'
    assert not re.search(r'^__(PAYLOAD|RENDERER|THREE|ORBIT|STILLS)__$',html,re.M)
    assert '@media(max-width:800px)' in html and 'prefers-color-scheme:dark' in html
    assert 'https://' not in re.sub(r'/\*.*?\*/|//[^\n]*','',html,flags=re.S).split('<script id="payload"')[0].split('<script>')[0]
    for script in re.findall(r'<script>(.*?)</script>',html,re.S):
        with tempfile.NamedTemporaryFile('w',suffix='.js') as f:
            f.write(script);f.flush();subprocess.run(['node','--check',f.name],check=True)
    payload=json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',html,re.S)[1])
    assert len(payload['scenes'])==24
    check_throne(payload)
    check_lighting(payload)
    for texture in payload['textures']:
        Image.open(io.BytesIO(base64.b64decode(texture.split(',',1)[1]))).verify()
    embedded=re.findall(r'<img [^>]*src="data:image/webp;base64,([^"]+)"',html)
    assert len(embedded)==18, len(embedded)
    for encoded in embedded:
        im=Image.open(io.BytesIO(base64.b64decode(encoded))); assert im.size==(1200,900); im.verify()
    for path in sorted((HERE/'renders').glob('*.png')):
        im=Image.open(path); assert im.size==(1200,900),path; im.verify()
    # Independent geometry exports, capped at two Node processes.
    with ThreadPoolExecutor(max_workers=2) as ex:
        for race,triangles in ex.map(geometry,payload['races']): print(f'{race}: 4 scenes, {triangles} triangles valid.')
    print(f'Offline references, JS syntax, PNG/WebP decoding, 24 geometry exports PASS. Page: {len(html.encode()):,} bytes.')
    print('Night light bank checked; browser events, engine rendering and mobile interaction are NOT certified.')

if __name__=='__main__':main()
