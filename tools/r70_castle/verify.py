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


def main():
    html=(HERE/'page.html').read_text(); OfflineHTML().feed(html)
    assert not re.search(r'^__(PAYLOAD|RENDERER|THREE|ORBIT|STILLS)__$',html,re.M)
    assert '@media(max-width:800px)' in html and 'prefers-color-scheme:dark' in html
    assert 'https://' not in re.sub(r'/\*.*?\*/|//[^\n]*','',html,flags=re.S).split('<script id="payload"')[0].split('<script>')[0]
    for script in re.findall(r'<script>(.*?)</script>',html,re.S):
        with tempfile.NamedTemporaryFile('w',suffix='.js') as f:
            f.write(script);f.flush();subprocess.run(['node','--check',f.name],check=True)
    payload=json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',html,re.S)[1])
    assert len(payload['scenes'])==24
    for texture in payload['textures']:
        Image.open(io.BytesIO(base64.b64decode(texture.split(',',1)[1]))).verify()
    for path in sorted((HERE/'renders').glob('*.png')):
        im=Image.open(path); assert im.size==(1200,900),path; im.verify()
    # Independent geometry exports, capped at two Node processes.
    with ThreadPoolExecutor(max_workers=2) as ex:
        for race,triangles in ex.map(geometry,payload['races']): print(f'{race}: 4 scenes, {triangles} triangles valid.')
    print('Offline references, JS syntax, texture/PNG decoding, 24 geometry exports PASS.')
    print('Browser layout/events, mobile interaction and engine lighting are NOT certified.')

if __name__=='__main__':main()
