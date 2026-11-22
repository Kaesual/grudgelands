#!/usr/bin/env python3
"""Round 85 WORLD: pictures of the arena's site per seed, for the user.

  python3 tools/r85_world/render.py <site dir> <old dir> <picdir> <seed>...
      <site dir>/<seed>/ from tools/r85_world/site.lua (centre.tsv, roads.tsv,
      site.tsv); <old dir>/base-<seed>/roads.tsv from tools/r84_site/site.lua
      on the earlier tree (the middle road before, dashed). Writes
      site-<seed>.png per seed: the relief after levelling, water, roads, the
      footprint (the draft's rim) and the levelled hull, the blend, the
      Battlegrounds zone border, the 200-node search window, (0, 0), the site
      and a numbers panel; summary.json with every seed's numbers.
  python3 tools/r85_world/render.py --profiles <site dir> <picdir> <seed>...
      profile-<seed>.png: the ground before and after along the road and
      across both halls, and the added grade round the site.
"""
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

PX = 2
FONT = '/usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf'
FONT_B = '/usr/share/fonts/liberation-sans-fonts/LiberationSans-Bold.ttf'
RIM = [(0, -45), (6, -45), (9, -38), (17, -36), (25, -39), (37, -32), (40, -24), (48, -21),
       (49, -15), (49, 16), (46, 21), (38, 29), (30, 38), (18, 40), (10, 35), (6, 45), (0, 45)]
POLY = RIM + [(-x, -z) for x, z in RIM[1:-1]]
HULL = [(-49, -16), (-46, -21), (-30, -38), (-6, -45), (6, -45), (25, -39), (37, -32), (48, -21),
        (49, -15), (49, 16), (46, 21), (30, 38), (6, 45), (-6, 45), (-25, 39), (-37, 32), (-48, 21),
        (-49, 15)]
INK, INK2, SURF = (11, 11, 11), (82, 81, 78), (252, 252, 251)
BLUE, ORANGE, RED, YELLOW = (42, 120, 214), (235, 104, 52), (227, 73, 72), (237, 161, 0)


def font(size, bold=False):
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()


def load_site(d):
    meta = {}
    for line in open(d + '/site.tsv'):
        k, v = line.rstrip('\n').split('\t', 1)
        meta[k] = v
    a = np.loadtxt(d + '/centre.tsv', dtype=np.float64)
    n = int(round(math.sqrt(len(a))))
    half = int(a[:, 0].max())
    g = lambda c: a[:, c].reshape(n, n)  # [z + half, x + half]
    return meta, half, g(2), g(3), g(4).astype(int), g(5).astype(int), g(6).astype(int), g(7).astype(int)


def load_roads(path, middle_test):
    roads = {}
    for line in open(path):
        f = line.rstrip('\n').split('\t')
        r = roads.setdefault(f[0], {'a': f[2], 'b': f[3], 'kind': f[1], 'pts': []})
        r['pts'].append((float(f[4]), float(f[5])))
    return [r for r in roads.values() if middle_test(r)], [r for r in roads.values() if not middle_test(r)]


def shade(h):
    gz, gx = np.gradient(h)
    nx, nz = -gx, -gz
    light = (nx * -0.7 + nz * 0.7 + 1.2) / np.sqrt(nx * nx + nz * nz + 1.0)
    return np.clip(light, 0, 1.4) / 1.4


def tint(h, lo, hi):
    t = np.clip((h - lo) / max(hi - lo, 1), 0, 1)[..., None]
    low, high = np.array([196, 214, 170]), np.array([214, 190, 150])
    return low * (1 - t) + high * t


def site_picture(seed, site_dir, old_dir, picdir):
    meta, half, nat, fin, zone, water, road, graded = load_site(f'{site_dir}/{seed}')
    sx, sz, datum = int(meta['x']), int(meta['z']), int(meta['datum'])
    n = 2 * half + 1
    lo, hi = np.percentile(fin, 2), np.percentile(fin, 98)
    rgb = tint(fin, lo, hi) * (0.55 + 0.45 * shade(fin))[..., None]
    blend = graded == 2
    rgb[blend] = rgb[blend] * 0.72 + np.array([98, 80, 214]) * 0.28
    rgb[water > 0] = np.array([120, 170, 230])
    rgb[road == 2] = rgb[road == 2] * 0.8 + 255 * 0.2
    rgb[road == 1] = np.array([110, 104, 96])
    img = np.flipud(rgb.astype(np.uint8))  # north up
    W = n * PX
    base = Image.fromarray(img).resize((W, W), Image.NEAREST)
    panel = 430
    out = Image.new('RGB', (W + panel, W), SURF)
    out.paste(base, (0, 0))
    d = ImageDraw.Draw(out)

    def P(x, z):
        return ((x + half + 0.5) * PX, (half - z + 0.5) * PX)

    # zone border 35/36
    zb = (zone[:, 1:] != zone[:, :-1]) & (zone[:, 1:] > 0) & (zone[:, :-1] > 0)
    for j, i in zip(*np.nonzero(zb)):
        if (j + i) % 3 == 0:
            x, z = i - half, j - half
            d.point(P(x, z), fill=(255, 255, 255))
    # old middle road, dashed
    mid_old, _ = load_roads(f'{old_dir}/base-{seed}/roads.tsv',
                            lambda r: (r['a'], r['b']) == ('anchor_008', 'anchor_011'))
    for r in mid_old:
        pts = [p for p in r['pts'] if abs(p[0]) <= half and abs(p[1]) <= half]
        for k in range(0, len(pts) - 6, 12):
            d.line([P(*pts[k]), P(*pts[k + 6])], fill=YELLOW, width=3)
    mid_new, _ = load_roads(f'{site_dir}/{seed}/roads.tsv',
                            lambda r: r['a'].startswith('breach_') or r['b'].startswith('breach_'))
    for r in mid_new:
        pts = [P(*p) for p in r['pts'] if abs(p[0]) <= half and abs(p[1]) <= half]
        if len(pts) > 1:
            d.line(pts, fill=RED, width=2)
    d.polygon([P(sx + x, sz + z) for x, z in HULL], outline=(255, 255, 255))
    d.polygon([P(sx + x, sz + z) for x, z in POLY], outline=INK)
    # window, centre, site
    c0 = P(0, 0)
    r200 = 200 * PX
    d.ellipse([c0[0] - r200, c0[1] - r200, c0[0] + r200, c0[1] + r200], outline=INK2, width=1)
    d.line([c0[0] - 10, c0[1], c0[0] + 10, c0[1]], fill=INK, width=2)
    d.line([c0[0], c0[1] - 10, c0[0], c0[1] + 10], fill=INK, width=2)
    cs = P(sx, sz)
    d.ellipse([cs[0] - 4, cs[1] - 4, cs[0] + 4, cs[1] + 4], fill=RED, outline=INK)
    # scale bar
    d.rectangle([20, W - 34, 20 + 100 * PX, W - 28], fill=INK)
    d.text((20, W - 26), '100 nodes', fill=INK, font=font(16))
    d.text((W - 60, 14), 'N ↑', fill=INK, font=font(20, True))

    x0 = W + 24
    y = 24
    d.text((x0, y), 'Breach Road — site', fill=INK, font=font(26, True)); y += 40
    d.text((x0, y), f'seed {seed}', fill=INK2, font=font(17)); y += 34
    rows = [
        ('site (centre)', f"{sx}, {sz}  ({float(meta['offset']):.0f} from 0, 0)"),
        ('datum (road y)', meta['datum']),
        ('blend reach', f"{meta['reach']} nodes"),
        ('zones under the hull', meta['zones'].replace('35', 'Causeway').replace('36', 'Shattered L.')),
        ('', ''),
        ('', 'chosen site   vs   at (0, 0)'),
        ('relief under hull', f"{meta['site_relief']}   vs   {meta['centre_relief']}"),
        ('mean earthwork', f"{meta['site_earth']}   vs   {meta['centre_earth']}"),
        ('largest rim step', f"{meta['site_step']}   vs   {meta['centre_step']}"),
        ('blend reach', f"{float(meta['site_reach']):.0f}   vs   {float(meta['centre_reach']):.0f}"),
        ('water columns', f"{meta['site_wet']}   vs   {meta['centre_wet']}"),
        ('', ''),
        ('added grade, max', f"{meta['grade_excess_max']}  (limit 1.25)"),
        ('steepest after / before', f"{meta['grade_final_max']} / {meta['grade_natural_max']}"),
        ('middle road at z = 0', f"x = {meta['road_crossing_x']}"),
        ('checks', meta['failures']),
    ]
    for k, v in rows:
        d.text((x0, y), k, fill=INK2, font=font(16))
        d.text((x0 + 190, y), str(v), fill=INK, font=font(16))
        y += 26
    y += 16
    legend = [((120, 170, 230), 'water'), ((110, 104, 96), 'road surface'),
              (RED, 'middle road now'), (YELLOW, 'middle road before (dashed)'),
              (INK, 'footprint (the draft\'s rim)'), ((255, 255, 255), 'levelled hull; zone border dots'),
              ((150, 135, 220), 'blend (graded ground)'), (INK2, 'search window, 200 nodes')]
    for col, label in legend:
        d.rectangle([x0, y + 3, x0 + 22, y + 15], fill=col, outline=INK2)
        d.text((x0 + 32, y), label, fill=INK, font=font(16))
        y += 26
    out.save(f'{picdir}/site-{seed}.png')
    return meta


def profile_picture(seed, site_dir, picdir):
    meta, half, nat, fin, zone, water, road, graded = load_site(f'{site_dir}/{seed}')
    sx, sz = int(meta['x']), int(meta['z'])
    reach = int(meta['reach'])
    span = 49 + reach + 40
    W, H = 1500, 1100
    out = Image.new('RGB', (W, H), SURF)
    d = ImageDraw.Draw(out)
    d.text((30, 20), f'Breach Road — ground before and after, seed {seed}', fill=INK, font=font(26, True))
    d.text((30, 58), f"site {sx}, {sz}, datum {meta['datum']}, blend reach {reach}; "
           f"added grade max {meta['grade_excess_max']} over 4 nodes", fill=INK2, font=font(17))

    def at(arr, x, z):
        return arr[z + half, x + half]

    def chart(box, title, samples):
        x1, y1, x2, y2 = box
        d.text((x1, y1 - 30), title, fill=INK, font=font(18, True))
        ys = [v for s in samples for v in (s[1], s[2])]
        lo, hi = min(ys) - 4, max(ys) + 4
        tmin, tmax = samples[0][0], samples[-1][0]

        def Q(t, v):
            return (x1 + (t - tmin) / (tmax - tmin) * (x2 - x1), y2 - (v - lo) / (hi - lo) * (y2 - y1))
        for k in range(int(lo // 10) * 10, int(hi) + 1, 10):
            if k >= lo:
                d.line([Q(tmin, k), Q(tmax, k)], fill=(232, 232, 228))
                d.text((x1 - 44, Q(tmin, k)[1] - 9), str(k), fill=INK2, font=font(14))
        for t in (-49 - reach, -49, 49, 49 + reach):
            d.line([Q(t, lo), Q(t, hi)], fill=(205, 205, 200))
        d.text(Q(-49, hi), ' hull', fill=INK2, font=font(14))
        d.text(Q(-49 - reach, hi), ' blend', fill=INK2, font=font(14))
        d.line([Q(s[0], s[1]) for s in samples], fill=ORANGE, width=2)
        d.line([Q(s[0], s[2]) for s in samples], fill=BLUE, width=2)
        d.line([(x2 - 330, y1 - 20), (x2 - 300, y1 - 20)], fill=ORANGE, width=3)
        d.text((x2 - 294, y1 - 29), 'natural ground', fill=INK, font=font(15))
        d.line([(x2 - 170, y1 - 20), (x2 - 140, y1 - 20)], fill=BLUE, width=3)
        d.text((x2 - 134, y1 - 29), 'after levelling', fill=INK, font=font(15))
        d.text(((x1 + x2) / 2 - 80, y2 + 8), 'nodes from the site centre', fill=INK2, font=font(14))
    along = [(t, at(nat, sx, sz + t), at(fin, sx, sz + t)) for t in range(-span, span + 1)
             if abs(sz + t) <= half]
    across = [(t, at(nat, sx + t, sz + 8), at(fin, sx + t, sz + 8)) for t in range(-span, span + 1)
              if abs(sx + t) <= half]
    chart((90, 130, 1450, 440), 'Along the road (south → north, through both mouths)', along)
    chart((90, 520, 1450, 830), 'Across both halls (west → east, 8 nodes north of the centre)', across)
    # added-grade map round the site
    r = 49 + reach + 8
    g = np.zeros((2 * r + 1, 2 * r + 1))
    for j in range(-r, r + 1):
        for i in range(-r, r + 1):
            x, z = sx + i, sz + j
            if abs(x) + 4 > half or abs(z) + 4 > half:
                continue
            e = max(abs(at(fin, x + 4, z) - at(fin, x, z)) - abs(at(nat, x + 4, z) - at(nat, x, z)),
                    abs(at(fin, x, z + 4) - at(fin, x, z)) - abs(at(nat, x, z + 4) - at(nat, x, z))) / 4
            g[j + r, i + r] = e if at(road, x, z) == 0 else 0
    img = np.zeros(g.shape + (3,))
    pos = np.clip(g / 1.0, 0, 1)[..., None]
    neg = np.clip(-g / 1.0, 0, 1)[..., None]
    img[:] = 245
    img = img * (1 - pos) + np.array([227, 73, 72]) * pos
    img = img * (1 - neg) + np.array([42, 120, 214]) * neg
    tile = Image.fromarray(np.flipud(img).astype(np.uint8)).resize((2 * (2 * r + 1),) * 2, Image.NEAREST)
    td = ImageDraw.Draw(tile)
    td.polygon([((x + r + 0.5) * 2, (r - z + 0.5) * 2) for x, z in HULL], outline=INK)
    sz_ = min(230, tile.size[0])
    tile = tile.resize((sz_, sz_))
    out.paste(tile, (90, 860))
    d.text((340, 870), 'Grade the levelling adds (4-node baseline), red up to +1.0,', fill=INK, font=font(16))
    d.text((340, 894), 'blue where it makes the ground gentler; roads left out.', fill=INK, font=font(16))
    d.text((340, 930), f"Steepest after {meta['grade_final_max']}, before {meta['grade_natural_max']}"
           f" (rise per node).", fill=INK2, font=font(16))
    out.save(f'{picdir}/profile-{seed}.png')


def main():
    if sys.argv[1] == '--profiles':
        site_dir, picdir, seeds = sys.argv[2], sys.argv[3], sys.argv[4:]
        for s in seeds:
            profile_picture(s, site_dir, picdir)
        return
    site_dir, old_dir, picdir, seeds = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    summary = {}
    for s in seeds:
        summary[s] = site_picture(s, site_dir, old_dir, picdir)
    json.dump(summary, open(f'{picdir}/summary.json', 'w'), indent=1, sort_keys=True)


if __name__ == '__main__':
    main()
