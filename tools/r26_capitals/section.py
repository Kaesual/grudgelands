#!/usr/bin/env python3
"""Round 27 wall fixes: draw section.lua's vertical sections, before | after.

  section.py <before.tsv> <after.tsv> <out.png> <title> [zoom=14]

Terrain brown up to each column's ground, water blue up to its surface, road
columns marked on the ground line, and the edge cells the writer builds:
stakes, logs and masonry dark, walks and slabs lighter, earth banks olive;
air cells the writer clears are left open. An edge node with nothing under it
(air, or a column's empty space above the ground) is outlined red; a
gatehouse lintel spanning its passage between two towers is meant to.
"""
import sys

from PIL import Image, ImageDraw, ImageFont


def font(size):
    for p in ('/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf',
              '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def load(path):
    cols = []
    for line in open(path):
        f = line.rstrip('\n').split('\t')
        cells = {}
        for c in f[6:]:
            y, _, name = c.partition(':')
            cells[int(y)] = name
        cols.append({'x': int(f[1]), 'z': int(f[2]), 'ground': int(f[3]),
                     'water': None if f[4] == '-' else int(f[4]), 'road': f[5] == '1', 'cells': cells})
    return cols


def colour(name):
    if 'slab' in name or 'path' in name or 'paving' in name or 'tile' in name:
        return (196, 170, 120)
    if 'dirt' in name or 'soil' in name:
        return (120, 110, 60)
    if 'light' in name or 'lamp' in name or 'torch' in name:
        return (250, 220, 90)
    if 'tree' in name or 'log' in name or 'wood' in name or 'stake' in name or 'cap' in name:
        return (92, 58, 30)
    return (95, 95, 100)


def panel(cols, lo, hi, z, label):
    w, h = len(cols) * z, (hi - lo + 1) * z
    im = Image.new('RGB', (w, h + 22), (205, 225, 240))
    d = ImageDraw.Draw(im)

    def box(i, y):
        return (i * z, (hi - y) * z, (i + 1) * z - 1, (hi - y + 1) * z - 1)
    for i, c in enumerate(cols):
        for y in range(lo, hi + 1):
            if y <= c['ground']:
                d.rectangle(box(i, y), fill=(150, 110, 70))
            elif c['water'] is not None and y <= c['water']:
                d.rectangle(box(i, y), fill=(70, 120, 200))
        if c['road']:
            d.rectangle(box(i, c['ground']), fill=(215, 200, 160))
        solid = {y: n for y, n in c['cells'].items() if n != 'air'}
        for y, n in c['cells'].items():
            if lo <= y <= hi:
                if n == 'air':
                    if y > c['ground']:
                        d.rectangle(box(i, y), fill=(205, 225, 240))
                    else:
                        d.rectangle(box(i, y), fill=(235, 235, 235))
        for y, n in solid.items():
            if lo <= y <= hi:
                d.rectangle(box(i, y), fill=colour(n), outline=(40, 40, 40))
                below = y - 1
                held = below in solid or (below <= c['ground'] and c['cells'].get(below) != 'air')
                if not held:
                    d.rectangle(box(i, y), outline=(230, 20, 20), width=2)
    for y in range(lo, hi + 1):
        d.line([(0, (hi - y) * z), (w, (hi - y) * z)], fill=(0, 0, 0, 30))
    d.text((4, h + 4), label, fill=(0, 0, 0), font=font(13))
    return im


def main():
    a, b = load(sys.argv[1]), load(sys.argv[2])
    out, title = sys.argv[3], sys.argv[4]
    z = int(sys.argv[5]) if len(sys.argv) > 5 else 14
    ys = []
    for cols in (a, b):
        for c in cols:
            ys += [c['ground']] + list(c['cells'].keys())
    lo, hi = min(ys) - 2, max(ys) + 2
    lo = max(lo, max(c['ground'] for c in a + b) - 14)
    pa = panel(a, lo, hi, z, 'BEFORE (main)')
    pb = panel(b, lo, hi, z, 'AFTER (fix)')
    cv = Image.new("RGB", (max(pa.width + pb.width + 30, 1100), pa.height + 60), (26, 26, 30))
    d = ImageDraw.Draw(cv)
    d.text((10, 8), title, fill=(255, 255, 255), font=font(15))
    d.text((10, 30), f"columns {a[0]['x']},{a[0]['z']} -> {a[-1]['x']},{a[-1]['z']}; red outline: an edge node with "
           'nothing under it (meant only for a lintel spanning the passage between two towers)',
           fill=(215, 215, 215), font=font(12))
    cv.paste(pa, (10, 50))
    cv.paste(pb, (pa.width + 20, 50))
    cv.save(out)
    print(out)


main()
