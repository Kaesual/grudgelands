#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build the Round 68 ICONS proposals, measurements and offline preview.

python3 tools/r68_icons/generate.py [--check]
Requires Python 3, Pillow and numpy; never starts Lua or writes game assets.
"""
import argparse
import base64
import hashlib
import html
import io
import itertools
import json
from pathlib import Path
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

from art import GEMS, METALS, SETTINGS, candidates

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
VERSIONS = ('old', 'a', 'b')
GROUPS = {
    'bars': [k+'_bar' for k in METALS],
    'settings': ['setting_'+k for k in SETTINGS],
    'gems': [s+'_'+k for k in GEMS for s in ('rough','cut')] + ['quartz','abyssal_crystal'],
    'metal_blocks': [k+'_block' for k in METALS],
    'gem_blocks': [k+'_block' for k in (*GEMS,'abyssal_crystal')],
}
TITLES = {'bars':'Metal bars', 'settings':'Jewellery settings', 'gems':'Gems and minerals',
          'metal_blocks':'Metal storage blocks', 'gem_blocks':'Gem and crystal storage blocks'}
IDEAS = {
    'bars': ('A · Cast ingots', 'Sloping, tapered castings with a different surface cue for each metal.',
             'B · Forged billets', 'Broad horizontal billets with clipped ends and legible working marks.',
             'A', 'The longer ingot silhouette and sloping light fit the shipped tools; B makes the surface marks easier to compare.'),
    'settings': ('A · Loose bezels', 'An empty open socket, with copper or gold trim where the recipe calls for it.',
                 'B · Ring blanks', 'An empty prong crown above a hollow ring shank, ready for a separate stone.',
                 'A', 'A loose mount can become a ring, amulet or seal; its larger open centre reads more clearly at 16 px.'),
    'gems': ('A · Crystal to jewel', 'Individual natural specimens become distinct radial cuts, with a broad brilliant diamond.',
             'B · Rock to jewel', 'Mineral exposures in broken host rock become broad step cuts, with a tall diamond.',
             'A', 'The six rough silhouettes stay cleaner without host rock; the broad diamond crown clearly marks the top gem.'),
}
METHOD = ('CIE76 ΔE: sRGB → linear RGB → CIE XYZ D65 → Lab; compute the Euclidean '
          'distance at each matching pixel and average only where BOTH alpha values are 255. '
          'No alignment, resizing, compositing, or background pixels enter the metric. '
          'N is the number of shared opaque pixels. Shape differences are deliberately not scored. '
          'These numbers are a guide, never a threshold; judge the 16 px strips first.')


def png(im):
    out = io.BytesIO()
    im.save(out, format='PNG', optimize=False, compress_level=9)
    return out.getvalue()


def label(key):
    return key.replace('_',' ').title().replace('Copper Inlaid','Copper-inlaid').replace('Gold Filigreed','Gold-filigreed')


def current_icons():
    """Read the real texture expressions, without executing any Lua.

    Engine transcription checked at pinned local reference:
    src/client/imagesource.cpp:486-519, 830-846;
    irr/include/SColor.h:343-351. colorize rounds an f32 interpolation;
    brighten truncates (127.5 + 0.5 * channel). Transparent pixels stay
    transparent. All source icon alpha values are binary.
    """
    ores = (ROOT/'mods/ITEMS/grug_materials/ores.lua').read_text()
    goldsmith = (ROOT/'mods/ITEMS/grug_artisans/goldsmith.lua').read_text()
    processed = ores.split('local PROCESSED_VISUALS = {',1)[1].split('\n}',1)[0]
    items = ores.split('local ITEM_VISUALS = {',1)[1].split('\n}',1)[0]
    expressions = {}
    rows = re.findall(r'(\w+)\s*=\s*\{"([^"]+)",\s*"([^"]+)"\}',processed)
    assert len(rows) == 10
    for key, item, block in rows:
        expressions[key+'_bar'] = item
        expressions[key+'_block'] = block
    for key, source, tint in re.findall(r'(\w+)\s*=\s*\{"([^"]+)",\s*"([^"]+)"\}',items):
        expr = source+'^[colorize:'+tint
        if key in GEMS:
            expressions['rough_'+key] = expr
            expressions['cut_'+key] = expr+'^[brighten'
            expressions[key+'_block'] = expr
        elif key in ('quartz','abyssal_crystal'):
            expressions[key] = expr
            if key == 'abyssal_crystal':
                expressions[key+'_block'] = expr
    tints = re.search(r'\(\{((?:"[0-9a-f]{6}",?\s*){6})\}\)\[tier\]',goldsmith)
    assert tints
    for key, tint in zip(SETTINGS,re.findall(r'"([0-9a-f]{6})"',tints[1])):
        expressions['setting_'+key] = 'default_gold_ingot.png^[colorize:#'+tint+':100'
    images, provenance = {}, {}
    for key, expr in expressions.items():
        parts = expr.split('^')
        source = ROOT/'mods/BASE/default/textures'/parts[0]
        a = np.asarray(Image.open(source).convert('RGBA')).copy()
        assert a.shape == (16,16,4)
        assert set(np.unique(a[:,:,3])) <= {0,255}
        for mod in parts[1:]:
            if mod.startswith('[colorize:'):
                _, tint, ratio = mod.split(':')
                c = np.array([int(tint[i:i+2],16) for i in (1,3,5)]+[255],dtype=np.float32)
                weight = np.float32(int(ratio))/np.float32(255)
                v = a.astype(np.float32)*(np.float32(1)-weight)+c*weight
                mask = a[:,:,3]>0
                a[mask] = np.floor(v[mask]+np.float32(.5)).astype(np.uint8)
            elif mod == '[brighten':
                a[:,:,:3] = ((a[:,:,:3].astype(np.uint16)+255)//2).astype(np.uint8)
            else:
                raise ValueError('Unsupported current texture modifier: '+mod)
        images[key] = Image.fromarray(a)
        provenance[key] = {'expression':expr, 'source':str(source.relative_to(ROOT)),
                           'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
    assert set(images) == set(itertools.chain.from_iterable(GROUPS.values()))
    return images, provenance


def lab(im):
    a = np.asarray(im,dtype=np.float64)[:,:,:3]/255
    linear = np.where(a <= .04045, a/12.92, ((a+.055)/1.055)**2.4)
    xyz = linear @ np.array([[.4124564,.3575761,.1804375],
                            [.2126729,.7151522,.0721750],
                            [.0193339,.1191920,.9503041]]).T
    xyz /= np.array([.95047,1,1.08883])
    delta = 6/29
    f = np.where(xyz > delta**3, np.cbrt(xyz), xyz/(3*delta**2)+4/29)
    return np.stack((116*f[:,:,1]-16,500*(f[:,:,0]-f[:,:,1]),200*(f[:,:,1]-f[:,:,2])),axis=2)


def distance(a,b):
    mask = (np.asarray(a)[:,:,3]==255)&(np.asarray(b)[:,:,3]==255)
    n = int(mask.sum())
    return {'delta_e':round(float(np.linalg.norm(lab(a)-lab(b),axis=2)[mask].mean()),4) if n else None,
            'shared_opaque_pixels':n}


def measurements(sets):
    data = {'method':METHOD, 'pairs':{}, 'rough_cut':{}}
    for group, keys in GROUPS.items():
        data['pairs'][group] = {}
        for v in VERSIONS:
            rows = [{'first':a,'second':b,**distance(sets[v][a],sets[v][b])}
                    for a,b in itertools.combinations(keys,2)]
            rows.sort(key=lambda x: (float('inf') if x['delta_e'] is None else x['delta_e'],x['first'],x['second']))
            data['pairs'][group][v] = rows
    for v in VERSIONS:
        data['rough_cut'][v] = [{'gem':k,**distance(sets[v]['rough_'+k],sets[v]['cut_'+k])} for k in GEMS]
    return data


def number(value):
    return 'n/a' if value is None else f'{value:.2f}'


def summary(data):
    lines = ['# Distinctness measurements', '', METHOD, '',
             'Three closest pairs per scope and version. The gem scope contains all 14 items,',
             'including minerals and both gem states; blocks have their own scopes.',
             'Every pair is in `measurements.json` and the expandable preview tables.', '',
             '| Scope | Version | Pair | ΔE | N |', '|---|---|---|---:|---:|']
    for group, versions in data['pairs'].items():
        for v, rows in versions.items():
            for row in rows[:3]:
                lines.append(f'| {TITLES[group]} | {v.upper()} | {label(row["first"])} / {label(row["second"])} | {number(row["delta_e"])} | {row["shared_opaque_pixels"]} |')
    lines += ['', '## Rough versus cut', '', '| Gem | Old ΔE | A ΔE | B ΔE |', '|---|---:|---:|---:|']
    for i,k in enumerate(GEMS):
        lines.append('| '+label(k)+' | '+' | '.join(number(data['rough_cut'][v][i]['delta_e']) for v in VERSIONS)+' |')
    lines += ['', '## Known weak pairs, before and after', '', '| Pair | Old ΔE | A ΔE | B ΔE |', '|---|---:|---:|---:|']
    for a,b in [('tin_bar','steel_bar'),('silver_bar','silversteel_bar'),('iron_bar','silversteel_bar'),
                ('copper_bar','bronze_bar'),('rough_garnet','rough_ruby'),('cut_garnet','cut_ruby'),('quartz','cut_diamond')]:
        group = 'bars' if a.endswith('_bar') else 'gems'
        values = []
        for v in VERSIONS:
            row = next(x for x in data['pairs'][group][v] if {x['first'],x['second']}=={a,b})
            values.append(number(row['delta_e']))
        lines.append('| '+label(a)+' / '+label(b)+' | '+' | '.join(values)+' |')
    return '\n'.join(lines)+'\n'


def wall(texture, mixed=None):
    """4 x 3 front tiles, plus top/right faces with constant simple shading.

    This is a texture tiling study, not an engine screenshot or alpha-mode
    simulation. Transparent old gem pixels show the neutral backing.
    """
    cols, rows = (len(mixed),1) if mixed else (4,3)
    width, height = cols*16, rows*16
    front = Image.new('RGBA',(width,height),'#293139')
    for y in range(rows):
        for x in range(cols):
            front.alpha_composite(mixed[x] if mixed else texture,(x*16,y*16))
    out = Image.new('RGBA',(width+16,height+16),(0,0,0,0))
    d = ImageDraw.Draw(out)
    for x in range(width):
        for z in range(8):
            c = front.getpixel((x,z))
            d.polygon([(x+2+z,10-z),(x+3+z,10-z),(x+4+z,9-z),(x+3+z,9-z)],fill=tuple(min(255,round(v*1.10)) for v in c[:3])+(255,))
    for y in range(height):
        for z in range(8):
            c = front.getpixel((width-16+z,y))
            d.polygon([(width+2+z,10+y-z),(width+3+z,9+y-z),(width+3+z,10+y-z),(width+2+z,11+y-z)],fill=tuple(round(v*.68) for v in c[:3])+(255,))
    out.alpha_composite(front,(2,10))
    return out


def image_tag(im,size,alt,cls=''):
    uri = base64.b64encode(png(im)).decode()
    w,h = im.size
    return f'<img class="{cls}" width="{size}" height="{round(size*h/w)}" alt="{html.escape(alt,quote=True)}" src="data:image/png;base64,{uri}">'


def strip(sets,v,keys,size):
    return '<div class="strip">'+''.join('<span class="slot" title="'+html.escape(label(k),quote=True)+'">'+image_tag(sets[v][k],size,label(k))+'</span>' for k in keys)+'</div>'


def samples(im,name):
    return '<div class="samples">'+''.join('<span class="sample"><span class="slot">'+image_tag(im,s,name)+'</span><small>'+str(s)+' px</small></span>' for s in (16,32,64))+'</div>'


def pair_table(rows):
    return '<table class="numbers"><thead><tr><th>Pair</th><th>ΔE</th><th>N</th></tr></thead><tbody>'+''.join(
        f'<tr><td>{label(r["first"])} / {label(r["second"])}</td><td>{number(r["delta_e"])}</td><td>{r["shared_opaque_pixels"]}</td></tr>' for r in rows)+'</tbody></table>'


def preview(sets,data):
    page = ['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Grudgelands · Material studies · Round 68</title><style>
:root{color-scheme:dark;--paper:#10171d;--panel:#18232b;--line:#35434b;--ink:#e9e5da;--muted:#a9b7bb;--gold:#e4bc73}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:15px/1.55 system-ui,sans-serif}
main{max-width:1300px;margin:auto;padding:42px 26px 72px}h1,h2,h3,p{margin-top:0}h1{font:500 48px/1.1 Georgia,serif;max-width:760px;margin-bottom:20px}
h2{font:400 30px Georgia,serif;margin:0 0 12px}h3{font-size:18px;margin-bottom:8px}p{max-width:900px}.eyebrow{font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:var(--gold)}
.muted,small{color:var(--muted)}a{color:var(--gold)}nav{display:flex;flex-wrap:wrap;gap:18px;margin:26px 0 38px}nav a{text-decoration:none}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}.card{padding:22px;background:var(--panel);border:1px solid var(--line);border-top:3px solid var(--gold)}
.card p{font-size:14px}.pick{color:var(--gold);font-weight:700}section{border-top:1px solid var(--line);padding-top:32px;margin-top:44px;scroll-margin-top:20px}
.ideas{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin:22px 0}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;text-align:left}
th,td{padding:12px;border-bottom:1px solid var(--line);vertical-align:middle}th{color:var(--muted);font-size:12px;letter-spacing:.05em;text-transform:uppercase}
.comparison{min-width:900px}.comparison th:first-child{width:190px}.comparison td{height:116px}.comparison tbody tr:hover{background:#19232b}
.samples{display:flex;gap:13px;align-items:flex-end}.sample{display:flex;align-items:center;flex-direction:column;gap:6px}.sample small{font-size:10px}
.slot{display:inline-flex;align-items:center;justify-content:center;background:#29333c;border:1px solid #44515b;padding:5px;flex:none}img{image-rendering:pixelated;object-fit:contain;vertical-align:middle}
.strip{display:flex;gap:3px;margin:10px 0 16px;flex-wrap:nowrap;width:max-content}.strip .slot{padding:3px}.inventory{padding:15px 20px;background:var(--panel);margin:16px 0}
.inventory h3{margin:0}.callout{border-left:3px solid var(--gold);background:var(--panel);padding:20px;margin:24px 0}.twostates{display:flex;gap:16px}.twostates>div{flex:1}
.gemrow td{padding-bottom:20px}.state{font-size:12px;color:var(--muted);margin:4px 0 8px}.gemcomparison{min-width:1230px}.gemcomparison th:first-child{width:130px}
.walltable{min-width:830px}.walltable td{padding:18px 10px}.numbers{font-size:13px}.numbers td:not(:first-child){text-align:right;font-variant-numeric:tabular-nums}.numbers th:not(:first-child){text-align:right}
.metrics{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}.metrics h3{margin-top:20px}details{margin:16px 0}summary{cursor:pointer;color:var(--gold)}.foot{font-size:12px;color:var(--muted)}
@media(max-width:800px){main{padding:25px 16px}.cards,.metrics,.ideas{grid-template-columns:1fr}h1{font-size:36px}.samples{gap:8px}}
</style><main><div class="eyebrow">Grudgelands / Round 68 / Art proposals</div>
<h1>Metals, empty mounts<br>and stones with character.</h1>
<p class="muted">Two original 16 × 16 pixel families per group. Start with the native inventory strips, then compare the larger samples. Nothing on this page is installed in the game.</p><div class="cards">''']
    for group, (a,ad,b,bd,pick,why) in IDEAS.items():
        page.append(f'<article class="card"><h3>{TITLES[group]}</h3><p class="pick">Recommendation: {pick}</p><p>{why}</p><p><b>{a}</b> — {ad}<br><b>{b}</b> — {bd}</p></article>')
    page.append('</div><nav>'+''.join(f'<a href="#{g}">{TITLES[g]}</a>' for g in GROUPS)+'<a href="#measurements">Measurements</a><a href="#credits">Credits</a></nav>')
    page.append('<p class="foot">All item samples have transparent backgrounds; solid node textures are opaque RGBA. Light comes from the upper left. One screen pixel per source pixel at 16 px when browser zoom is 100%; device pixel density may differ.</p>')
    for group in ('bars','settings','gems'):
        page.append(f'<section id="{group}"><h2>{TITLES[group]}</h2>')
        a,ad,b,bd,_,_ = IDEAS[group]
        page.append(f'<div class="ideas"><p><b>{a}</b><br>{ad}</p><p><b>{b}</b><br>{bd}</p></div>')
        if group == 'bars':
            page.append('<p class="muted">Tin: soft pale casting. Iron: warm, dark hammer marks. Steel: neutral ground face. Silver: warm white polish. Silversteel: cool double ridge. Copper is red; bronze is ochre. Embersteel has a fire-bright edge; Abyssal Steel keeps a dark body.</p>')
            refs = [(k,ROOT/'mods/ITEMS/grug_gear/textures'/f'grug_gear_item_head_metal_{k}.png') for k in ('bronze','iron','steel','silversteel','embersteel','abyssal_steel')]
            page.append('<details><summary>Unchanged shipped armour · palette context</summary><div class="strip">'+''.join('<span class="sample">'+image_tag(Image.open(p).convert('RGBA'),48,label(k))+'<small>'+label(k)+'</small></span>' for k,p in refs)+'</div><p class="foot">Palette anchors only; armour is unchanged. Weapon and trinket ramps also informed the bars, especially iron and embersteel.</p></details>')
        if group == 'settings':
            page.append('<p class="muted">T1 Tin · T2 Iron · T3 Copper-inlaid Steel · T4 Gold · T5 Gold-filigreed Embersteel · T6 Gold-filigreed Abyssal Steel. The centre is empty in every proposal.</p>')
            page.append('<details><summary>Unchanged shipped trinkets · T1–T6 metal context</summary><div class="strip">'+''.join('<span class="sample">'+image_tag(Image.open(ROOT/'mods/ITEMS/grug_gear/textures'/f'grug_gear_trinket_battlebeat_t{i}.png').convert('RGBA'),48,f'Shipped T{i} trinket')+f'<small>T{i}</small></span>' for i in range(1,7))+'</div><p class="foot">The stones belong to the finished trinkets, not to the proposed empty mounts.</p></details>')
        for v in VERSIONS:
            page.append(f'<div class="inventory"><h3>{"Current" if v=="old" else "Variant "+v.upper()} · whole group</h3><div class="scroll">'+strip(sets,v,GROUPS[group],16)+strip(sets,v,GROUPS[group],32)+'</div></div>')
        page.append('<div class="scroll"><table class="comparison '+('gemcomparison' if group=='gems' else '')+'"><thead><tr><th>Item</th><th>Current</th><th>Variant A</th><th>Variant B</th></tr></thead><tbody>')
        if group == 'gems':
            for i,k in enumerate(GEMS,1):
                page.append(f'<tr class="gemrow"><td><b>{label(k)}</b><br><small>T{i}</small></td>')
                for v in VERSIONS:
                    page.append('<td><div class="twostates">'+''.join('<div><div class="state">'+s.title()+'</div>'+samples(sets[v][s+'_'+k],label(s+'_'+k))+'</div>' for s in ('rough','cut'))+'</div></td>')
                page.append('</tr>')
            keys = ['quartz','abyssal_crystal']
        else:
            keys = GROUPS[group]
        for k in keys:
            page.append(f'<tr><td><b>{label(k)}</b></td>'+''.join('<td>'+samples(sets[v][k],label(k))+'</td>' for v in VERSIONS)+'</tr>')
        page.append('</tbody></table></div>')
        if group == 'gems':
            page.append('<div class="callout"><h3>Garnet beside Ruby</h3><p>Warm, dark garnet and vivid crimson ruby; square versus pear in A, hexagon versus round in B. Read left to right: rough garnet, rough ruby, cut garnet, cut ruby.</p>')
            for v in VERSIONS:
                page.append('<b>'+v.upper()+'</b><div class="scroll">'+strip(sets,v,['rough_garnet','rough_ruby','cut_garnet','cut_ruby'],16)+strip(sets,v,['rough_garnet','rough_ruby','cut_garnet','cut_ruby'],32)+'</div>')
            page.append('</div><p class="foot">Abyssal Crystal stays a raw mineral. Its block follows the crystal palette; it is not a cut gem and gains no cut item. The current registry places it at harvest tier 5, although the brief called it T6; these proposals change no tiers.</p>')
        page.append('</section>')
    for group in ('metal_blocks','gem_blocks'):
        page.append(f'<section id="{group}"><h2>{TITLES[group]}</h2>')
        page.append('<p class="muted">'+('A: quiet solid cast faces. B: two offset courses of metal billets. Pick with the matching bar variant.' if group=='metal_blocks' else 'A: one broad polished facet. B: paired step-cut slabs. Pick with the matching gem variant.')+'</p>')
        for v in VERSIONS:
            mixed = wall(None,[sets[v][k] for k in GROUPS[group]])
            page.append('<div class="inventory"><h3>'+v.upper()+' · all blocks</h3><div class="scroll">'+strip(sets,v,GROUPS[group],16)+strip(sets,v,GROUPS[group],32)+image_tag(mixed,mixed.width*3,'Mixed block wall '+v)+'</div></div>')
        page.append('<div class="scroll"><table class="comparison"><thead><tr><th>Face texture</th><th>Current</th><th>A</th><th>B</th></tr></thead><tbody>')
        for k in GROUPS[group]:
            page.append('<tr><td>'+label(k)+'</td>'+''.join('<td>'+samples(sets[v][k],label(k))+'</td>' for v in VERSIONS)+'</tr>')
        page.append('</tbody></table></div><h3>Wall studies · four blocks wide, three high</h3><p class="foot">Front tiles repeat without gaps; the top is 10% lighter and the side 32% darker. These are software texture studies, not engine captures. Current gem transparency shows a neutral backing.</p><div class="scroll"><table class="walltable"><thead><tr><th>Material</th><th>Current</th><th>A</th><th>B</th></tr></thead><tbody>')
        for k in GROUPS[group]:
            page.append('<tr><td>'+label(k)+'</td>'+''.join('<td>'+image_tag(wall(sets[v][k]),240,label(k)+' wall '+v)+'</td>' for v in VERSIONS)+'</tr>')
        page.append('</tbody></table></div></section>')
    page.append('<section id="measurements"><h2>Distinctness, with limits</h2><p>'+METHOD+'</p><p class="muted">OLD uses the shipped texture expressions and engine rounding, including the cut-gem brighten modifier. Each scope is measured separately; the gem scope includes all 14 rough, cut and mineral items.</p>')
    for group in GROUPS:
        page.append('<h3>'+TITLES[group]+'</h3><div class="metrics">')
        for v in VERSIONS:
            rows = data['pairs'][group][v]
            page.append('<div><h3>'+v.upper()+' · closest three</h3>'+pair_table(rows[:3])+f'<details><summary>All {len(rows)} pairs</summary>'+pair_table(rows)+'</details></div>')
        page.append('</div>')
    page.append('<h3>Rough versus cut · every gem</h3><table class="numbers"><tr><th>Gem</th><th>Old ΔE / N</th><th>A ΔE / N</th><th>B ΔE / N</th></tr>')
    for i,k in enumerate(GEMS):
        page.append('<tr><td>'+label(k)+'</td>'+''.join('<td>'+number(data['rough_cut'][v][i]['delta_e'])+' / '+str(data['rough_cut'][v][i]['shared_opaque_pixels'])+'</td>' for v in VERSIONS)+'</tr>')
    page.append('</table></section><section id="credits"><h2>Provenance &amp; delivery</h2><p>Original candidates: GPT-6 Astra, 2026-10-31; CC0-1.0 to the extent rights exist. All 94 candidate PNGs are coordinate drawings from Python, Pillow and numpy. Generator code: GPL-3.0-or-later. Shipped gear palettes informed the colour ramps; no source pixels enter a candidate.</p><p>Current comparison images retain CC BY-SA 3.0: BlockMen (gold ingot, diamond and the credited iron/steel ingot), Gambit (copper and bronze ingots), kilbith (tin ingot and metal blocks). Source records: mods/BASE/default/README.txt and license.txt. Modifications: the game’s own colour and brighten modifiers, nearest-neighbour enlargement, and shaded wall layouts. These comparison derivatives are CC BY-SA 3.0 and are not candidate assets.</p><p class="foot">CC BY-SA 3.0: Attribution-ShareAlike 3.0 Unported. Credit the named authors and mark modifications; adaptations remain under the same licence. Full vendored notice is included in comparison-license.txt beside this page. See tools/r68_icons/LICENSE-media.md for source paths and candidate coverage.</p><p class="foot">Review at 100% browser zoom on desktop and web target screens. The user picks A/B independently for bars, settings and gems; matching blocks follow the bars/gems. No runtime, saved state, recipes or version declaration changes. Classification: compatible proposal assets only.</p></section></main></html>')
    return '\n'.join(page)


def contact_sheet(sets, group):
    keys = GROUPS[group]
    width = max(960,len(keys)*92+120)
    out = Image.new('RGB',(width,430),'#18232b')
    d = ImageDraw.Draw(out)
    d.text((16,12),TITLES[group]+' / 16 px and 48 px / Current, A, B', fill='#e9e5da')
    for row,v in enumerate(VERSIONS):
        y = 50+row*125
        d.text((12,y+30),v.upper(),fill='#e4bc73')
        for col,k in enumerate(keys):
            x = 90+col*92
            for size,dy in ((16,0),(48,25)):
                im=sets[v][k].resize((size,size),Image.Resampling.NEAREST)
                out.paste(im,(x,y+dy),im)
            short=k.replace('setting_','').replace('rough_','R ').replace('cut_','C ').replace('_bar','')
            d.text((x,y+80),short[:14],fill='#a9b7bb')
    return out


def build():
    proposed = candidates()
    old,provenance = current_icons()
    sets = {'old':old}
    outputs = {}
    for v in ('a','b'):
        sets[v] = {}
        for group in ('bars','settings','gems'):
            for key,im in proposed[group+'_'+v].items():
                assert im.mode=='RGBA' and im.size==(16,16)
                alpha = np.asarray(im)[:,:,3]
                assert set(np.unique(alpha)) <= {0,255}
                if key.endswith('_block'):
                    assert np.all(alpha==255)
                    a=np.asarray(im)
                    assert np.array_equal(a[:,0],a[:,-1]) and np.array_equal(a[0],a[-1])
                else:
                    assert 0 in alpha and 255 in alpha and all(alpha[y,x]==0 for x,y in ((0,0),(15,0),(0,15),(15,15)))
                sets[v][key] = im
                outputs[f'candidates/{group}_{v}/{key}.png'] = png(im)
        assert set(sets[v])==set(old)
    assert len([k for k in outputs if k.startswith('candidates/')])==94
    for k,im in old.items():
        outputs['preview/current/'+k+'.png'] = png(im)
    data = measurements(sets)
    outputs['measurements.json'] = (json.dumps(data,indent=2)+'\n').encode()
    outputs['MEASUREMENTS.md'] = summary(data).encode()
    outputs['current_sources.json'] = (json.dumps(provenance,indent=2,sort_keys=True)+'\n').encode()
    outputs['preview/index.html'] = preview(sets,data).encode()
    notice = (ROOT/'mods/BASE/default/license.txt').read_text()
    notice = notice.split('Licenses of media (textures, models and sounds)',1)[1]
    notice = notice.split('\n-----------------------\n',1)[0]
    outputs['preview/comparison-license.txt'] = ('Licenses of media (textures, models and sounds)'+notice).encode()
    for group in ('bars','settings','gems'):
        outputs['preview/'+group+'_comparison.png'] = png(contact_sheet(sets,group))
    return outputs,data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true',help='verify committed outputs without modifying them')
    args = parser.parse_args()
    outputs,data = build()
    errors = []
    for rel,content in outputs.items():
        path = HERE/rel
        if args.check:
            if not path.exists() or path.read_bytes()!=content:
                errors.append(rel)
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(content)
    expected = set(outputs)
    for directory in ('candidates','preview'):
        for path in (HERE/directory).rglob('*'):
            if path.is_file() and str(path.relative_to(HERE)) not in expected:
                errors.append('unexpected output: '+str(path.relative_to(HERE)))
    for group,versions in data['pairs'].items():
        for v,rows in versions.items():
            print(f'{group:14} {v.upper():3}: '+ '; '.join(f'{r["first"]}/{r["second"]} {number(r["delta_e"])} (N={r["shared_opaque_pixels"]})' for r in rows[:3]))
    if errors:
        print('FAIL: '+'\n'.join(errors),file=sys.stderr)
        return 1
    print(('PASS: verified ' if args.check else 'Wrote ')+f'{len(outputs)} reproducible outputs; 94 candidate PNGs, 47 current comparisons; no game assets changed.')
    return 0


if __name__=='__main__':
    raise SystemExit(main())
