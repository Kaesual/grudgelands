#!/usr/bin/env python3
"""Original CC0 hood paint, authored in side/back/top views. No random choices.

python3 -B art/drop-02/src/build.py
Only writes inside this drop. The game supplies read-only art and projection tools.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import zipfile

sys.dont_write_bytecode = True
from PIL import Image, ImageColor

DROP = Path(__file__).resolve().parents[1]
SRC = DROP / 'src'
ARCHIVE = SRC / 'source.zip'
GAME = Path.home() / 'projects/grudgelands'
SYMBOLS = {'H':'#F0F0F0', 'L':'#C8C8C8', 'M':'#A0A0A0', 'D':'#787878',
           'S':'#505050', 'O':'#282828', 'r':'#A07850', 's':'#6E5034',
           'A':'#E07070', 'a':'#B04848', 'B':'#70A0E0', 'b':'#4870B0', 'G':'#FFC040'}
INK = {s: ImageColor.getrgb(c) + (255,) for s,c in SYMBOLS.items()}
NAMES = {'cloth':['Patch','Woven','Heavy cloth','Silkweave','Silk','Stormweave'],
         'leather':['Light','Cured','Heavy leather','Hardened','Sleek','Nightscale']}
IDEAS = {'p1':'Quiet crown', 'p2':'Turned edge'}
INTROS = {
 'p1': "A single crown seam descends into a small rear finish, with the hood dyed to match its helm. Cloth develops a tiny embroidered point; leather develops a stitched central join and a small seam cap. A one-pixel lining edge leaves the material fields calm.",
 'p2': "The hood is tailored from broad, uninterrupted panels, with the workmanship concentrated at the turned lower edge. Cloth gains a fine binding and corner tacks; leather gains a rolled welt and discreet edge fasteners. There is no central ornament, and the hood shares the helm's material colour."
}
PROGRESSION = {
 ('p1','cloth'):[
  'A small repaired swatch and two dull stitches establish the plain hood.',
  'The patch gives way to a continuous crown seam and a single rear tack.',
  'A deeper lower fold and a two-pixel seam end give the heavier cloth more weight.',
  'The seam ends in a tiny three-stitch point above the burgundy lining.',
  'The point closes into one small gold diamond on the pearl material.',
  'A silver tip finishes the diamond; a narrow lustre along the crown suits the dark blue cloth.'
 ],
 ('p1','leather'):[
  'A rough central join and two dull stitches hold the light hide together.',
  'An even join and cleaner crown seam replace the rough repair.',
  'A deeper seam channel and one small lower tack reinforce the heavier hide.',
  'The seam gains a second fastening and a short protective cap.',
  'A smoother crown highlight and a brighter cap accompany the mask.',
  'Paired pale stitches secure the capped join above the veil lining.'
 ],
 ('p2','cloth'):[
  'A small side repair interrupts a plain, slightly uneven turned hem.',
  'A continuous level hem and balanced folds replace the repair.',
  'A narrow darker piping line supports the lining, with two end tacks.',
  'The binding turns neatly upward at both corners, with small warm fasteners.',
  'A fine gold thread crosses the pearl hood immediately above its blue lining.',
  'A pale silver binding and two raised corner stitches finish the dark blue hood.'
 ],
 ('p2','leather'):[
  'A short repaired edge and two coarse tacks finish the light hide.',
  'A clean rolled welt replaces the uneven lower edge.',
  'The welt gains a second material shade and two end fasteners.',
  'Turned welt corners and two extra stitches strengthen the hardened hide.',
  'A smooth narrow highlight runs over the welt beside the sleek mask.',
  'A precise pale stitched edge and raised corner tacks finish the veil hood.'
 ]
}


def capture_source(game: Path):
    if ARCHIVE.exists():
        return
    base = game / 'tools/r54_art/art'
    inputs = {'art/' + p.relative_to(base).as_posix():p.read_bytes()
              for p in sorted(base.rglob('*')) if p.is_file()}
    for key, rel in {'hood.json':'tools/r56_hood/hood.json',
                     'reference.json':'tools/r54_armor/data/palettes.json',
                     'blank.png':'tools/r54_armor/templates/blank/hood.png'}.items():
        inputs[key] = (game / rel).read_bytes()
    inputs['projector-sha256.json'] = (json.dumps({rel:hashlib.sha256((game/rel).read_bytes()).hexdigest()
        for rel in ('tools/r56_hood/views.py','tools/r54_armor/data/catalog.json')}, indent=2)+'\n').encode()
    with zipfile.ZipFile(ARCHIVE,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,data in sorted(inputs.items()):
            info=zipfile.ZipInfo(name,date_time=(2026,10,22,0,0,0))
            info.external_attr=0o100644 << 16
            z.writestr(info,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    (SRC/'source-sha256.json').write_text(json.dumps({k:hashlib.sha256(v).hexdigest()
        for k,v in sorted(inputs.items())},indent=2)+'\n')


def tool(game: Path, args: list[str]):
    p=subprocess.run([sys.executable,'-B',str(game/'tools/r56_hood/views.py'),*args],
        cwd=DROP,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),capture_output=True,text=True)
    if p.returncode:
        raise RuntimeError(p.stdout+p.stderr)
    return p.stdout


def projection_module(game: Path):
    spec=importlib.util.spec_from_file_location('hood_views',game/'tools/r56_hood/views.py')
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def paint_views(V, hood, proposal: str, line: str, t: int):
    """All marks are placed on the three view canvases, never on face rectangles.

    Back/top: 12x14. Side: 14x14. One view pixel = one skin pixel.
    Back rows increase downwards; top rows increase toward the face.
    Side x increases toward the face. Top x reverses relative to back x.
    """
    areas={n:V.fill_area(hood,n) for n in V.VIEW_NAMES}
    ims={n:Image.new('RGBA',(hood.frames[n].cols,hood.frames[n].rows)) for n in V.VIEW_NAMES}
    def dot(n,x,y,c):
        if (x,y) in areas[n]:
            ims[n].putpixel((x,y),INK[c])
    def row(n,y,x0,x1,c):
        for x in range(x0,x1+1): dot(n,x,y,c)
    def col(n,x,y0,y1,c):
        for y in range(y0,y1+1): dot(n,x,y,c)

    # Large material fields. Highlights face upward; the lower back is shaded.
    for n,area in areas.items():
        for x,y in area:
            c='M'
            if n=='top':
                c='L' if 3<=x<=8 else 'M'
                if y>=10: c='M'
            elif n=='back':
                if y<=2: c='L'
                if y>=11 or (y==10 and (line=='leather' or t>=3)): c='D'
            elif n=='side':
                c='L' if y==1 else 'M'
                if y>=11 or (y==10 and (line=='leather' or t>=3)): c='D'
            dot(n,x,y,c)

    # A is lining, only the lower edge and the thin front lip.
    row('back',12,1,10,'a')
    row('side',12,1,2,'a')
    row('top',12,1,10,'a')
    if t>=3:
        row('top',12,4,7,'A')

    if line=='cloth':
        # A few broad creases continue the helm's restrained vertical folds.
        col('back',3,4,7 if t<4 else 6,'L')
        col('back',8,5,8 if t<4 else 7,'M' if t==1 else 'L')
        if proposal=='p1':
            col('top',6,1,10,'M' if t<3 else 'D')
            col('back',5,1,7,'D')
            if t==1:
                for y in (7,8): row('back',y,3,4,'D')
                dot('back',3,6,'b'); dot('back',4,9,'b')
                dot('back',2,12,'D')
            if t==2:
                dot('back',5,9,'b')
            if t==3:
                dot('back',5,8,'b'); dot('back',5,9,'B')
            if t>=4:
                # One tiny finish: never a border around the entire rear panel.
                dot('back',4,8,'b'); dot('back',6,8,'b'); dot('back',5,9,'B')
            if t>=5:
                dot('back',5,7,'B')
            if t==6:
                dot('back',5,10,'b')
                col('top',5,2,7,'L')
                row('top',3,3,4,'H')
        else:
            # No middle seam or motif. The hem and its turned corners carry rank.
            if t==1:
                for y in (8,9): row('back',y,2,3,'D')
                dot('back',2,7,'b'); dot('back',3,10,'b')
                dot('back',2,12,'D')
            if t>=2:
                row('back',11,2,9,'M')
                dot('back',3,11,'b'); dot('back',8,11,'b')
            if t>=3:
                row('back',11,1,10,'D')
                dot('back',2,11,'b'); dot('back',9,11,'b')
            if t>=4:
                dot('back',2,10,'b'); dot('back',9,10,'b')
                dot('back',2,11,'B'); dot('back',9,11,'B')
            if t>=5:
                row('back',11,1,10,'b')
                row('side',11,1,2,'b')
                dot('back',2,11,'B'); dot('back',9,11,'B')
            if t==6:
                row('back',11,3,8,'B')
                dot('back',2,10,'B'); dot('back',9,10,'B')
                row('top',3,3,4,'H')
    else:
        # Hide has firmer joins and shorter highlights, no embroidery.
        row('top',4,3,4,'L')
        row('top',4,7,8,'L')
        col('back',3,4,5,'L')
        if proposal=='p1':
            col('top',6,1,10,'D')
            col('back',5,1,10,'D')
            if t>=3:
                col('back',5,7,10,'S')
            if t==1:
                dot('back',4,6,'D'); dot('back',5,4,'b'); dot('back',5,8,'b')
                dot('back',2,12,'D')
            if t>=2:
                dot('back',5,4,'b'); dot('back',5,8,'b')
            if t>=3:
                dot('back',5,10,'b')
            if t>=4:
                dot('back',5,4,'B')
                dot('back',5,8,'B')
                dot('back',6,10,'b')
            if t>=5:
                dot('back',5,10,'B'); dot('back',6,10,'b')
                row('top',3,3,4,'H')
            if t==6:
                dot('back',6,4,'b'); dot('back',6,8,'b')
                dot('back',6,10,'B')
        else:
            if t==1:
                row('back',11,2,9,'D')
                dot('back',3,11,'b'); dot('back',8,11,'b')
                dot('back',2,12,'D')
            if t>=2:
                row('back',11,1,10,'r')
                row('side',11,1,2,'r')
                dot('back',3,11,'b'); dot('back',8,11,'b')
            if t>=3:
                row('back',10,1,10,'D')
                dot('back',2,11,'B'); dot('back',9,11,'B')
            if t>=4:
                dot('back',2,10,'r'); dot('back',9,10,'r')
                dot('back',4,11,'b'); dot('back',7,11,'b')
            if t>=5:
                row('back',11,3,8,'L')
                dot('back',4,11,'b'); dot('back',7,11,'b')
                row('top',3,3,4,'H')
            if t==6:
                dot('back',2,10,'B'); dot('back',9,10,'B')
                dot('back',4,11,'B'); dot('back',7,11,'B')

    # Brush strokes include all tinted view pixels, including bleed-only samples.
    # Narrow side tips have no texel centre inside the polygon at rows 11/12;
    # their visible edge still samples those texels. Preserve the painted hem
    # there instead of replacing it with a nearest interior pixel from row 10.
    return ims


def build(game: Path=GAME):
    capture_source(game)
    with zipfile.ZipFile(ARCHIVE) as z:
        source={n:z.read(n) for n in z.namelist()}
    assert {k:hashlib.sha256(v).hexdigest() for k,v in sorted(source.items())} == json.loads((SRC/'source-sha256.json').read_text())
    for rel,sha in json.loads(source['projector-sha256.json']).items():
        assert hashlib.sha256((game/rel).read_bytes()).hexdigest()==sha, f'Read-only projector input changed: {rel}'
    (SRC/'hood.json').write_bytes(source['hood.json'])
    V=projection_module(game)
    hood=V.Hood(SRC/'hood.json')
    tool(game,['--part',str(SRC/'hood.json'),'--scale','16','templates',str(DROP/'views/templates')])
    for proposal in ('p1','p2'):
        dest=DROP/proposal
        for name,data in sorted(source.items()):
            if name.startswith('art/'):
                p=dest/name[4:]; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(data)
        tiers=json.loads(source['art/tiers.json'])
        for v in ('a','c'):
            p=dest/'leather'/f'helm_{v}.png'
            im=Image.open(p).convert('RGBA'); im.putpixel((14,11),INK['B']); im.save(p,compress_level=9)
        for line in ('cloth','leather'):
            for t,v in enumerate('abcdef',1):
                painted=paint_views(V,hood,proposal,line,t)
                vd=DROP/'views'/proposal/line/f'T{t}'
                vd.mkdir(parents=True,exist_ok=True)
                paths=[]
                for n in V.VIEW_NAMES:
                    p=vd/f'{n}.png'; painted[n].save(p,compress_level=9); paths.append(str(p))
                tool(game,['--part',str(SRC/'hood.json'),'project',*paths,'-o',str(dest/line/f'hood_{v}.png')])
                tier=tiers[line][f'T{t}']
                if 'hood' not in tier['on']: tier['on'].insert(tier['on'].index('helm')+1,'hood')
                tier.setdefault('variant',{})['hood']=v
        (dest/'tiers.json').write_text(json.dumps(tiers,indent=1)+'\n')
        notes=[f'# {proposal.upper()}: {IDEAS[proposal]}','',INTROS[proposal],'']
        for line in ('cloth','leather'):
            for t,(name,description) in enumerate(zip(NAMES[line],PROGRESSION[proposal,line]),1):
                notes.append(f'- {line.title()} T{t} {name}: {description}')
        notes += ['', 'Original hood paint: CC0 1.0. Main fields use the tier material colours; zone A is narrow lining and zone B is small stitching, binding or fittings. Picked palettes are unchanged.',
                  '', 'Leather T1 and T3 each have exactly one repaired pixel: sheet (14,11) is B_LIGHT. Alpha, face windows and chin strips are unchanged. All other inherited PNGs are byte-identical to the source snapshot.', '']
        (dest/'notes.md').write_text('\n'.join(notes))
        print(f'{proposal}: 12 hoods projected from 36 painted views; 2 one-pixel helm repairs',flush=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--game',type=Path,default=GAME)
    build(ap.parse_args().game)
