#!/usr/bin/env python3
"""Round 26 Lane W: top-down capital plans from render.lua's output.

  render.py <out_root> <seedtag> [variant ...]

<out_root>/<variant>/<seedtag>/<capital>.json + .layers (render.lua) become
  <out_root>/<variant>/<seedtag>/<capital>.png          one plan per capital
and, when both variants "before" and "after" exist,
  <out_root>/compare/<seedtag>_<capital>.png            before | after
  <out_root>/<seedtag>_overview.png                     the six pairs of one seed

Legend: hillshaded relief with contour lines every 2 nodes (every 10 darker),
water blue; network roads tan, avenues cream, lanes pale, bridges brown, decks
red-brown, squares pale discs; the civic core a pale square; plots coloured by
district -- REQUIRED plots with a thick yellow frame, NAMED buildings solid
with a dark frame, FILL pieces hatched without a frame; overflowed plots a
white frame; the wall in its model's colour (arcade over water lighter, civic
lake edge dotted), turrets as discs, bastions as larger diamonds, gatehouses
as dark red boxes; road ends white rings; the reserved 512 square white.
With render.lua's edge layer the wall is instead painted node by node as the
shipped writer builds it: face/parapet in the model's colour, the walk
lighter, turrets darker, gatehouse towers dark red and its passage pale red
(the gate box outlined), edge columns over water tinted blue.

  render.py <out_root> <seedtag> --crop <capital> <x> <z> <radius> [zoom]

crops before | after around world column (x, z) at `zoom` pixels per node
(default 8) into <out_root>/compare/<seedtag>_<capital>_<x>_<z>.png.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

S = 2  # pixels per node
CAPS = ['highcourt', 'dur_brannoc', 'nhal_veyr', 'gor_drazhak', 'lethariel', 'kezamba']
NAMES = {'highcourt': 'Highcourt', 'dur_brannoc': 'Dur Brannoc', 'lethariel': 'Lethariel',
         'nhal_veyr': 'Nhal Veyr', 'gor_drazhak': 'Gor Drazhak', 'kezamba': 'Kezamba'}


def font(size, bold=False):
    for p in ('/usr/share/fonts/dejavu-sans-fonts/DejaVuSans%s.ttf' % ('-Bold' if bold else ''),
              '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if bold else '')):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


FS, FM, FB = font(12), font(14), font(18, True)
PALETTE = [(232, 145, 45), (210, 60, 55), (125, 95, 215), (55, 165, 80), (40, 165, 195)]
WALLCOL = {'stone': (80, 78, 78), 'palisade': (120, 78, 38)}


def load_layers(path):
    """terrain, water, road code and (newer render.lua) the city edge code"""
    with open(path) as fh:
        n, x0, z0 = map(int, fh.readline().split())
        data = np.array(fh.read().split(), dtype=np.float64)
    data = data.reshape(-1, n, n)
    edge = data[3].astype(int) if data.shape[0] > 3 else None
    return n, x0, z0, data[0], data[1], data[2].astype(int), edge


def hillshade(h):
    gy, gx = np.gradient(h)
    az, alt = math.radians(315), math.radians(40)
    slope = np.pi / 2 - np.arctan(1.6 * np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    sh = np.sin(alt) * np.sin(slope) + np.cos(alt) * np.cos(slope) * np.cos(az - aspect)
    return np.clip(sh, 0, 1)


def relief(t, wy):
    land = wy <= -999
    lo, hi = np.percentile(t[land], 2), np.percentile(t[land], 98)
    u = np.clip((t - lo) / max(1.0, hi - lo), 0, 1)[..., None]
    low, mid, high = np.array([112, 148, 84]), np.array([170, 168, 110]), np.array([200, 186, 150])
    rgb = np.where(u < 0.5, low * (1 - 2 * u) + mid * 2 * u, mid * (2 - 2 * u) + high * (2 * u - 1))
    rgb = rgb * (0.5 + 0.6 * hillshade(t)[..., None])
    for step, k in ((2, 0.9), (10, 0.72)):
        c = np.floor(t / step)
        e = np.zeros(t.shape, bool)
        e[:, 1:] |= c[:, 1:] != c[:, :-1]
        e[1:, :] |= c[1:, :] != c[:-1, :]
        rgb[e] = rgb[e] * k
    wet = ~land
    depth = np.clip((wy - t) / 6.0, 0, 1)[..., None]
    water = np.array([95, 150, 210]) * (1 - depth) + np.array([45, 95, 175]) * depth
    rgb[wet] = water[wet]
    return rgb


def plan_image(J, n, T, WY, RC, EDGE=None):
    win = J['window']
    rgb = relief(T, WY)
    cls, kind = RC // 10, RC % 10
    surf = (cls >= 1) & (cls <= 6)
    net = surf & (kind <= 3)
    rgb[net] = (196, 170, 120)
    rgb[surf & (kind == 4)] = (240, 234, 214)
    rgb[surf & (kind == 5)] = (220, 212, 190)
    rgb[surf & (cls == 5)] = (170, 105, 55)
    rgb[surf & (cls == 4)] = (190, 80, 60)
    slope = (cls >= 7) & (cls <= 10)
    rgb[slope] = rgb[slope] * 0.75 + np.array([150, 130, 100]) * 0.25
    if EDGE is not None:
        # the edge as the shipped writer builds it, one node per column
        base = np.array(WALLCOL.get(J['dims']['model'], (80, 80, 80)), dtype=float)
        for code, c in ((1, base), (2, np.minimum(255, base + 80)), (3, (150, 35, 35)),
                        (4, (205, 95, 85)), (5, base * 0.7)):
            rgb[EDGE == code] = c
        wet_edge = (EDGE > 0) & (WY > -999)
        rgb[wet_edge] = rgb[wet_edge] * 0.6 + np.array([95, 150, 210]) * 0.4
    img = Image.fromarray(np.clip(rgb, 0, 255).astype('uint8')).resize((n * S, n * S), Image.NEAREST)
    d = ImageDraw.Draw(img, 'RGBA')

    def px(x, z):
        return ((x + win + 0.5) * S, (z + win + 0.5) * S)

    # reserved square and civic core
    d.rectangle([px(-256, -256), px(256, 256)], outline=(255, 255, 255, 200), width=1)
    core = J['P']['CORE']
    d.rectangle([px(-core, -core), px(core - 1, core - 1)], fill=(232, 226, 210, 235),
                outline=(90, 80, 60), width=2)
    d.text(px(-14, -6), 'core', fill=(90, 80, 60), font=FM)
    # squares
    for x, z, r in J['squares']:
        a, b = px(x - r, z - r), px(x + r, z + r)
        d.ellipse([a, b], fill=(238, 228, 200, 255), outline=(150, 130, 100))
    # canal
    if J.get('canal'):
        d.line([px(x, z) for x, z in J['canal']], fill=(50, 100, 200), width=5 * S)
    # plots
    names = sorted({p['district'] for p in J['plots']})
    dcol = {nm: PALETTE[i % len(PALETTE)] for i, nm in enumerate(names)}
    for p in J['plots']:
        a, b = px(p['x0'] - 0.5, p['z0'] - 0.5), px(p['x1'] + 0.5, p['z1'] + 0.5)
        c = dcol[p['district']]
        if p['tier'] == 'fill':
            d.rectangle([a, b], fill=c + (95,))
            # hatch
            x0, y0, x1, y1 = a[0], a[1], b[0], b[1]
            k = -(y1 - y0)
            while k < (x1 - x0):
                p0 = (x0 + max(0, k), y0 + max(0, -k))
                l = min(x1 - x0 - max(0, k), y1 - y0 - max(0, -k))
                d.line([p0, (p0[0] + l, p0[1] + l)], fill=c + (230,), width=1)
                k += 7
        else:
            d.rectangle([a, b], fill=c + (225,), outline=(25, 25, 25), width=1)
        if p['tier'] == 'required':
            d.rectangle([a[0] - 3, a[1] - 3, b[0] + 3, b[1] + 3], outline=(255, 230, 0), width=3)
        if p['overflow']:
            d.rectangle([a[0] - 1, a[1] - 1, b[0] + 1, b[1] + 1], outline=(255, 255, 255), width=2)
        if p['tier'] != 'fill':
            cx, cy = px(0.5 * (p['x0'] + p['x1']), 0.5 * (p['z0'] + p['z1']))
            ex, ey = px(p['ex'] + p['fx'] * 2, p['ez'] + p['fz'] * 2)
            d.line([(cx, cy), (ex, ey)], fill=(20, 20, 20), width=2)
    # wall
    dims = J['dims']
    col = WALLCOL.get(dims['model'], (80, 80, 80))
    wall = J['wall']
    m = len(wall)
    wpx = max(2, (2 * dims['half'] + 1) * S)
    for i in range(m if EDGE is None else 0):
        a, b = wall[i], wall[(i + 1) % m]
        if a[2] or b[2]:
            continue
        if a[4] and b[4]:
            d.line([px(a[0], a[1]), px(b[0], b[1])], fill=(255, 255, 255, 120), width=1)
            continue
        c = tuple(min(255, v + 70) for v in col) if (a[3] or b[3]) else col
        d.line([px(a[0], a[1]), px(b[0], b[1])], fill=c, width=wpx)
    for x, z, k in (J['turrets'] if EDGE is None else []):
        r = dims['turret']
        cx, cy = px(x, z)
        dark = tuple(int(v * 0.7) for v in col)
        if k == 'bastion':
            rr = (r + 2) * S
            d.polygon([(cx, cy - rr), (cx + rr, cy), (cx, cy + rr), (cx - rr, cy)], fill=dark,
                      outline=(15, 15, 15))
        else:
            d.ellipse([cx - r * S, cy - r * S, cx + r * S, cy + r * S], fill=dark, outline=(15, 15, 15))
    gd, gw = dims['depth'], dims['width']
    for g in J['gates']:
        pts = [px(g['x'] + g['dx'] * dd - g['dz'] * ww, g['z'] + g['dz'] * dd + g['dx'] * ww)
               for dd, ww in ((-gd, -gw), (gd, -gw), (gd, gw), (-gd, gw))]
        if EDGE is None:
            d.polygon(pts, fill=(150, 35, 35), outline=(15, 15, 15))
        else:
            d.polygon(pts, outline=(15, 15, 15))
        lx, ly = px(g['x'] + g['dx'] * 16, g['z'] + g['dz'] * 16)
        d.text((lx - 5, ly - 8), g['name'][0].upper(), fill=(255, 255, 255), font=FM)
    for x, z in J['ends']:
        cx, cy = px(x, z)
        d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], outline=(255, 255, 255), width=3)
    return img, dcol


def stats_lines(J):
    s = J['stats']
    lo = [p['id'] + ('' if p['tier'] == 'fill' else ' (' + p['tier'].upper() + ')') for p in J['left_out']]
    named_lo = sum(1 for p in J['left_out'] if p['tier'] != 'fill')
    lines = [
        f"{J['area'] / 1000:.0f} k m2, radius {s['rmin']:.0f}-{s['rmax']:.0f}, built {100 * s['built_share']:.0f} %, "
        f"plots {s['placed']}/{s['total']} (req {s['kit_required']}, named {s['kit_named']}, fill {s['kit_fill']}), "
        f"overflow {s['overflowed']}",
        f"left out {len(J['left_out'])} (named {named_lo}): {', '.join(lo) if lo else '-'}",
        f"rings {len(J['P']['RINGS'])}, open arcs {s['open_arcs']}, cross-lanes {s['cross_lanes']}, "
        f"squares {s['squares']}, spokes {s.get('spokes', 0)}{', plaza' if s.get('plaza') else ''}, wall {s['wall_length']:.0f} m, towers {s['turrets']}; planner {s['seconds']:.2f} s"
        + (f"; no route:{s['no_route']}" if s.get('no_route') else ''),
    ]
    if J['missing_required']:
        lines.append('REQUIRED MISSING (load failure): ' + ', '.join(J['missing_required']))
    return lines


def legend(d, x, y, J, dcol):
    col = WALLCOL.get(J['dims']['model'], (80, 80, 80))
    items = [((240, 234, 214), 'avenue'), ((220, 212, 190), 'lane / ring'), ((238, 228, 200), 'square'),
             ((196, 170, 120), 'network road / connector'), ((170, 105, 55), 'bridge'), ((190, 80, 60), 'deck'),
             (col, J['dims']['model'] + ' wall'), (tuple(min(255, v + 70) for v in col), 'wall over water'),
             (tuple(int(v * 0.7) for v in col), 'tower / bastion'), ((150, 35, 35), 'gatehouse'),
             (tuple(min(255, v + 80) for v in col), 'wall walk (edge layer)'),
             ((205, 95, 85), 'gate passage (edge layer)'),
             ((95, 150, 210), 'water')]
    for nm, c in dcol.items():
        items.append((c, 'district ' + nm.replace(J['key'] + '_', '')))
    for c, t in items:
        d.rectangle([x, y, x + 16, y + 12], fill=c, outline=(0, 0, 0))
        d.text((x + 22, y - 2), t, fill=(230, 230, 230), font=FS)
        y += 18
    d.rectangle([x, y, x + 16, y + 12], outline=(255, 230, 0), width=3)
    d.text((x + 22, y - 2), 'required plot', fill=(230, 230, 230), font=FS)
    y += 18
    d.rectangle([x, y, x + 16, y + 12], fill=(160, 160, 160), outline=(20, 20, 20))
    d.text((x + 22, y - 2), 'named building', fill=(230, 230, 230), font=FS)
    y += 18
    d.rectangle([x, y, x + 16, y + 12], fill=(90, 90, 90))
    for k in range(0, 16, 5):
        d.line([(x + k, y), (x + k + 12 if k + 12 <= 16 else x + 16, y + min(12, 16 - k))], fill=(200, 200, 200))
    d.text((x + 22, y - 2), 'fill piece (hatched)', fill=(230, 230, 230), font=FS)
    y += 18
    d.rectangle([x, y, x + 16, y + 12], outline=(255, 255, 255), width=2)
    d.text((x + 22, y - 2), 'overflowed to a neighbour', fill=(230, 230, 230), font=FS)
    y += 18
    d.ellipse([x, y, x + 14, y + 14], outline=(255, 255, 255), width=3)
    d.text((x + 22, y - 2), 'road end (network)', fill=(230, 230, 230), font=FS)
    y += 22
    for t in ('contours every 2 nodes (10 darker)', 'white square: reserved 512', 'north up (-z)',
              'black ticks: plot entry'):
        d.text((x, y), t, fill=(200, 200, 200), font=FS)
        y += 16


def render_one(root, variant, tag, cap, label=None):
    base = os.path.join(root, variant, tag, cap)
    if not os.path.exists(base + '.json'):
        return None
    J = json.load(open(base + '.json'))
    n, _, _, T, WY, RC, EDGE = load_layers(base + '.layers')
    img, dcol = plan_image(J, n, T, WY, RC, EDGE)
    head = 120
    canvas = Image.new('RGB', (img.width + 250, img.height + head + 10), (26, 26, 30))
    canvas.paste(img, (10, head))
    d = ImageDraw.Draw(canvas)
    title = f"{NAMES[cap]} - seed {J['seed']} - {label or variant}"
    if J.get('style'):
        title += f" - character: {J['style']}"
    d.text((10, 8), title, fill=(255, 255, 255), font=FB)
    for i, l in enumerate(stats_lines(J)):
        d.text((10, 36 + 18 * i), l, fill=(215, 215, 215), font=FM)
    legend(d, img.width + 22, head + 4, J, dcol)
    canvas.save(base + '.png')
    return canvas, img, J


def crop(root, tag, cap, x, z, r, zoom=8):
    """before | after around world column (x, z), `zoom` pixels per node, with
    the planned wall centre line (thin black) and its gap points (inside a
    gatehouse box, red dots) over the writer's edge"""
    tiles = []
    for v, label in (('before', 'BEFORE (main)'), ('after', 'AFTER (fix)')):
        base = os.path.join(root, v, tag, cap)
        J = json.load(open(base + '.json'))
        n, _, _, T, WY, RC, EDGE = load_layers(base + '.layers')
        img, _ = plan_image(J, n, T, WY, RC, EDGE)
        win = J['window']
        lx, lz = x - J['anchor']['x'], z - J['anchor']['z']
        im = img.crop(((lx - r + win) * S, (lz - r + win) * S, (lx + r + 1 + win) * S,
                       (lz + r + 1 + win) * S)).resize(((2 * r + 1) * zoom,) * 2, Image.NEAREST)
        d = ImageDraw.Draw(im, 'RGBA')

        def q(px_, pz_):
            return ((px_ - lx + r + 0.5) * zoom, (pz_ - lz + r + 0.5) * zoom)
        for k in range(0, 2 * r + 2):
            d.line([(k * zoom, 0), (k * zoom, im.height)], fill=(0, 0, 0, 28))
            d.line([(0, k * zoom), (im.width, k * zoom)], fill=(0, 0, 0, 28))
        wall = J['wall']
        d.line([q(p[0], p[1]) for p in wall] + [q(wall[0][0], wall[0][1])], fill=(0, 0, 0, 200), width=2)
        for p in wall:
            if p[2]:
                cx, cy = q(p[0], p[1])
                d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(230, 20, 20))
        tiles.append((im, label, J))
    head = 64
    w = max(sum(t[0].width for t in tiles) + 30, 1060)
    cv = Image.new('RGB', (w, tiles[0][0].height + head + 40), (26, 26, 30))
    d = ImageDraw.Draw(cv)
    J = tiles[1][2]
    d.text((10, 8), f"{NAMES[cap]} - seed {J['seed']} - around x {x}, z {z} (north up, -z), {zoom} px per node",
           fill=(255, 255, 255), font=FB)
    d.text((10, 32), 'wall face/parapet in the model colour, walk light, turret dark, gatehouse tower dark red, '
           'passage pale red, box outlined;', fill=(215, 215, 215), font=FS)
    d.text((10, 46), 'black: planned centre line, red dots: gap points (inside a gatehouse box); blue tint: over water',
           fill=(215, 215, 215), font=FS)
    ox = 10
    for im, label, _ in tiles:
        cv.paste(im, (ox, head))
        d.text((ox, head + im.height + 8), label, fill=(255, 255, 255), font=FM)
        ox += im.width + 10
    os.makedirs(os.path.join(root, 'compare'), exist_ok=True)
    p = os.path.join(root, 'compare', f'{tag}_{cap}_{x}_{z}.png')
    cv.save(p)
    print(p)


def main():
    if len(sys.argv) > 3 and sys.argv[3] == '--crop':
        a = sys.argv
        crop(a[1], a[2], a[4], int(a[5]), int(a[6]), int(a[7]), int(a[8]) if len(a) > 8 else 8)
        return
    root, tag = sys.argv[1], sys.argv[2]
    variants = sys.argv[3:] or ['before', 'after']
    res = {}
    for v in variants:
        for c in CAPS:
            r = render_one(root, v, tag, c, {'before': 'BEFORE (main)', 'after': 'AFTER (Round 26)'}.get(v))
            if r:
                res[(v, c)] = r
                print(os.path.join(root, v, tag, c + '.png'))
    if not all((v, c) in res for v in ('before', 'after') for c in CAPS):
        return
    os.makedirs(os.path.join(root, 'compare'), exist_ok=True)
    for c in CAPS:
        a, b = res[('before', c)][0], res[('after', c)][0]
        cv = Image.new('RGB', (a.width + b.width + 10, max(a.height, b.height)), (60, 60, 64))
        cv.paste(a, (0, 0))
        cv.paste(b, (a.width + 10, 0))
        p = os.path.join(root, 'compare', f'{tag}_{c}.png')
        cv.save(p)
        print(p)
    # overview: per capital a before | after pair
    T = 470
    cols = 2
    pw = 2 * T + 12
    ph = T + 64
    cv = Image.new('RGB', (cols * pw + (cols + 1) * 16, 3 * ph + 60), (26, 26, 30))
    d = ImageDraw.Draw(cv)
    seed = res[('after', CAPS[0])][2]['seed']
    d.text((16, 14), f"Seed {seed}: the six capitals, BEFORE (main, left) and AFTER (Round 26, right) - north up",
           fill=(255, 255, 255), font=FB)
    for i, c in enumerate(CAPS):
        x = 16 + (i % cols) * (pw + 16)
        y = 50 + (i // cols) * ph
        for k, v in enumerate(('before', 'after')):
            _, img, J = res[(v, c)]
            win = J['window']
            # crop to the reserved square + a margin
            m = int((win - 262) * S)
            im = img.crop((m, m, img.width - m, img.height - m)).resize((T, T), Image.LANCZOS)
            cv.paste(im, (x + k * (T + 12), y + 22))
            s = J['stats']
            nlo = sum(1 for p in J['left_out'] if p['tier'] != 'fill')
            d.text((x + k * (T + 12), y + T + 26),
                   f"{J['area'] / 1000:.0f} k m2, plots {s['placed']}/{s['total']}, named left out {nlo}, "
                   f"towers {s['turrets']}, {s['seconds']:.2f} s", fill=(210, 210, 210), font=FS)
        style = res[('after', c)][2].get('style')
        d.text((x, y), NAMES[c] + (f"  (after: {style})" if style else ''), fill=(255, 255, 255), font=FM)
    p = os.path.join(root, f'{tag}_overview.png')
    cv.save(p)
    print(p)


if __name__ == '__main__':
    main()
