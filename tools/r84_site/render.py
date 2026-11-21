#!/usr/bin/env python3
"""Round 84 SITE: pictures and numbers of the map centre per seed, from
site.lua's output (see run.sh).

  python3 tools/r84_site/render.py <dir> <picdir> <seed>...
      centre-<seed>.png per seed (relief, water, roads, placements, the
      200-node frame, the 100 x 100 footprint at (0, 0), a scale) and
      stats.json with the numbers of every seed
  python3 tools/r84_site/render.py --diff <dir> <picdir> <variant> <seed>...
      change-<variant>-<seed>.png: the whole world with every changed
      8-node sample and road cell (red outside the Battlegrounds, yellow in
      them), and the centre with the height change and both road sets
"""
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

R = 256          # half side of the centre window (nodes)
PX = 2           # pixels per node in the centre picture
FRAME = 200      # the study radius
FOOT = 50        # half side of the proposed 100 x 100 footprint
BG = {34, 35, 36, 37}
FONT = '/usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf'
FONT_B = '/usr/share/fonts/liberation-sans-fonts/LiberationSans-Bold.ttf'
ZONE_NAMES = {5: 'Stormvault Heights', 10: 'Ashenward March', 16: 'Glassroot Wilds',
              21: 'Blackwind Rise', 26: 'Bannerbreak Mesa', 32: 'Thunderroot Wilds',
              34: 'Gravesalt Escarpment', 35: 'The Broken Causeway', 36: 'The Shattered Line',
              37: 'The Skyglass Canopy', 8: 'Highcourt', 24: 'Gor Drazhak'}
SHORT = {'pvp_camp_low': 'war camp (low)', 'pvp_camp_high': 'war camp (high)',
         'pvp_fortress': 'fortress', 'rare_route': 'rare den', 'clash': 'clash site',
         'camp_construction': 'camp u. constr.', 'mining_camp': 'mining camp',
         'outpost': 'outpost', 'bandit_frontier': 'bandit camp', 'arena': 'ARENA'}


def font(size, bold=False):
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()


def load_centre(path):
    a = np.loadtxt(path, dtype=np.float64, converters={2: lambda s: float('nan') if s == b'nil' else float(s)})
    n = 2 * R + 1
    h = a[:, 2].reshape(n, n)       # [z + R, x + R]
    zone = a[:, 3].astype(int).reshape(n, n)
    cls = a[:, 4].astype(int).reshape(n, n)
    depth = a[:, 5].reshape(n, n)
    return h, zone, cls, depth


def load_anchors(path):
    out = []
    for line in open(path):
        f = line.rstrip('\n').split('\t')
        out.append({'id': f[0], 'zone': int(f[1]), 'slot': f[3], 'kind': f[4], 'mode': f[5],
                    'x': int(f[6]), 'z': int(f[7]), 'y': int(f[8]), 'core': float(f[9]),
                    'fit': float(f[10])})
    return out


def load_roads(path):
    out = {}
    for line in open(path):
        f = line.rstrip('\n').split('\t')
        r = out.setdefault(int(f[0]), {'kind': f[1], 'a': f[2], 'b': f[3], 'hw': f[7], 'pts': []})
        r['pts'].append((float(f[4]), float(f[5]), float(f[6])))
    return out


def middle_road(roads):
    for rid, r in roads.items():
        if r['kind'] == 'primary' and {r['a'], r['b']} == {'anchor_008', 'anchor_011'}:
            return rid, r
    return None, None


def stats_of(d, seed):
    h, zone, cls, depth = load_centre(f'{d}/centre.tsv')
    n = 2 * R + 1
    zz, xx = np.mgrid[-R:R + 1, -R:R + 1]
    disc = xx * xx + zz * zz <= FRAME * FRAME
    land = (cls == 0) & disc
    # grade over an 8-node baseline (the heights are whole nodes, so a
    # 1-node baseline reads every terrace step as a slope)
    slope = np.full(h.shape, np.nan)
    slope[4:-4, 4:-4] = np.hypot((h[4:-4, 8:] - h[4:-4, :-8]) / 8, (h[8:, 4:-4] - h[:-8, 4:-4]) / 8)
    s_land = slope[land & ~np.isnan(slope)]
    water = (cls != 0) & disc
    names = {1: 'lake', 2: 'river', 3: 'bay', 4: 'belt', 5: 'channel', 6: 'open_sea'}
    wshare = {names[c]: round(float(((cls == c) & disc).sum() / disc.sum()) * 100, 1)
              for c in names if ((cls == c) & disc).any()}
    sq = (xx >= -FOOT) & (xx < FOOT) & (zz >= -FOOT) & (zz < FOOT)
    hs = np.sort(h[sq])
    ref = hs[(len(hs) - 1) // 2]
    zones_in = sorted(set(int(v) for v in np.unique(zone[disc])))
    # the nearest column outside the Battlegrounds
    out_bg = ~np.isin(zone, list(BG))
    rr = np.hypot(xx, zz)
    near_out = float(rr[out_bg].min()) if out_bg.any() else None
    an = load_anchors(f'{d}/anchors.tsv')
    roads = load_roads(f'{d}/roads.tsv')
    rid, mr = middle_road(roads)
    mid = None
    if mr:
        pts = mr['pts']
        cross = []
        for (x1, z1, y1), (x2, z2, y2) in zip(pts, pts[1:]):
            if (z1 <= 0 < z2) or (z2 <= 0 < z1):
                t = -z1 / (z2 - z1)
                cross.append((x1 + t * (x2 - x1), y1 + t * (y2 - y1)))
        dmin = min(math.hypot(p[0], p[1]) for p in pts)
        inside = sum(1 for p in pts if math.hypot(p[0], p[1]) <= FRAME)
        xs = [p[0] for p in pts if abs(p[1]) <= FRAME]
        mid = {'road_id': rid, 'cross_x_at_z0': [round(c[0], 1) for c in cross],
               'cross_y': [round(c[1], 1) for c in cross], 'min_dist_to_centre': round(dmin, 1),
               'points_within_200': inside,
               'x_range_for_abs_z_le_200': [round(min(xs), 1), round(max(xs), 1)] if xs else None,
               'through_footprint': any(abs(p[0]) < FOOT and abs(p[1]) < FOOT for p in pts)}
    forts = [{'id': a['id'], 'zone': a['zone'], 'x': a['x'], 'z': a['z'],
              'dist': round(math.hypot(a['x'], a['z']))} for a in an if a['kind'] == 'pvp_fortress']
    near = []
    on_foot = []
    for a in an:
        if a['kind'] == 'arena':
            continue
        half = a['core'] / 2
        dx = max(abs(a['x']) - half, 0)
        dz = max(abs(a['z']) - half, 0)
        if math.hypot(dx, dz) <= FRAME:
            near.append({'id': a['id'], 'zone': a['zone'], 'kind': a['kind'], 'x': a['x'],
                         'z': a['z'], 'core': a['core'], 'dist': round(math.hypot(a['x'], a['z']))})
        fh = a['fit'] / 2
        if abs(a['x']) - fh < FOOT and abs(a['z']) - fh < FOOT:
            on_foot.append(a['id'])
    return {
        'seed': seed,
        'land_height': [float(np.nanmin(h[land])), float(np.nanmax(h[land]))] if land.any() else None,
        'relief_200': float(np.nanmax(h[land]) - np.nanmin(h[land])) if land.any() else None,
        'slope_p50': round(float(np.percentile(s_land, 50)), 3),
        'slope_p90': round(float(np.percentile(s_land, 90)), 3),
        'slope_max': round(float(s_land.max()), 2),
        'steep_share_gt_0_5': round(float((s_land > 0.5).mean()) * 100, 1),
        'steep_share_gt_1': round(float((s_land > 1).mean()) * 100, 1),
        'water_share_200': round(float(water.sum()) / disc.sum() * 100, 1),
        'water_by_class': wshare,
        'foot_100': {'min': float(hs[0]), 'max': float(hs[-1]), 'lower_median': float(ref),
                     'cut': int(round(np.clip(h[sq] - ref, 0, None).sum())),
                     'fill': int(round(np.clip(ref - h[sq], 0, None).sum())),
                     'water_columns': int((cls[sq] != 0).sum()),
                     'zones': sorted(set(int(v) for v in np.unique(zone[sq])))},
        'zones_within_200': zones_in,
        'nearest_non_bg_column': round(near_out, 1) if near_out is not None else None,
        'middle_road': mid, 'fortresses': forts, 'placements_within_200': near,
        'fitting_square_on_footprint': on_foot,
    }


def ramp(t):
    # low green -> ochre -> brown -> light grey
    stops = [(0.0, (70, 125, 70)), (0.35, (150, 160, 90)), (0.6, (180, 150, 95)),
             (0.85, (140, 105, 80)), (1.0, (225, 220, 215))]
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        m = (t >= t0) & (t <= t1)
        f = ((t - t0) / (t1 - t0))[m]
        for k in range(3):
            out[..., k][m] = c0[k] + (c1[k] - c0[k]) * f
    return out


def to_px(x, z):
    return (x + R) * PX + PX / 2, (R - z) * PX + PX / 2


def render_centre(d, seed, st, path, title_extra=''):
    h, zone, cls, depth = load_centre(f'{d}/centre.tsv')
    lo, hi = st['land_height'] if st['land_height'] else (0, 1)
    rgb = ramp((h - lo) / max(hi - lo, 1))
    gz, gx = np.gradient(h)
    # light from the north-west
    shade = np.clip(1 + (-gx + gz) * 0.35, 0.55, 1.35)
    rgb = np.clip(rgb * shade[..., None], 0, 255)
    inland = (cls == 1) | (cls == 2)
    sea = cls >= 3
    rgb[inland] = np.array([70, 130, 200]) * 1.0
    rgb[sea] = np.array([40, 80, 150])
    # zone borders
    border = np.zeros(h.shape, bool)
    border[:, 1:] |= zone[:, 1:] != zone[:, :-1]
    border[1:, :] |= zone[1:, :] != zone[:-1, :]
    rgb[border] = (20, 20, 20)
    img = np.flipud(rgb).astype(np.uint8)        # row 0 = z +R (north up)
    img = np.kron(img, np.ones((PX, PX, 1), dtype=np.uint8))
    W = img.shape[1]
    panel = 430
    canvas = Image.new('RGB', (W + panel, W + 40), (250, 248, 244))
    canvas.paste(Image.fromarray(img), (0, 40))
    dr = ImageDraw.Draw(canvas)
    oy = 40

    def P(x, z):
        px, py = to_px(x, z)
        return px, py + oy
    roads = load_roads(f'{d}/roads.tsv')
    mid_id, _ = middle_road(roads)
    for rid, r in roads.items():
        if rid == mid_id:
            continue
        hw = float(r['hw'] or 1.5)
        col = (110, 80, 50) if r['kind'] != 'trail' else (150, 115, 80)
        for x, z, _ in r['pts']:
            if abs(x) <= R and abs(z) <= R:
                px, py = P(x, z)
                rad = max(hw * PX, 1.5)
                dr.ellipse((px - rad, py - rad, px + rad, py + rad), fill=col)
    if mid_id is not None:
        r = roads[mid_id]
        hw = float(r['hw'] or 3.5)
        for x, z, _ in r['pts']:
            if abs(x) <= R and abs(z) <= R:
                px, py = P(x, z)
                rad = hw * PX
                dr.ellipse((px - rad, py - rad, px + rad, py + rad), fill=(215, 40, 30))
    # the frame and the footprint
    cx, cy = P(0, 0)
    for k in range(0, 360, 4):
        a0, a1 = math.radians(k), math.radians(k + 2)
        dr.line((cx + FRAME * PX * math.cos(a0), cy + FRAME * PX * math.sin(a0),
                 cx + FRAME * PX * math.cos(a1), cy + FRAME * PX * math.sin(a1)),
                fill=(255, 255, 255), width=3)
    x0, y0 = P(-FOOT, FOOT)
    x1, y1 = P(FOOT, -FOOT)
    dr.rectangle((x0, y0, x1, y1), outline=(230, 0, 200), width=3)
    dr.line((cx - 8, cy, cx + 8, cy), fill=(0, 0, 0), width=2)
    dr.line((cx, cy - 8, cx, cy + 8), fill=(0, 0, 0), width=2)
    # anchors
    f_small, f_mid, f_big = font(15), font(17), font(22, True)
    an = load_anchors(f'{d}/anchors.tsv')
    for a in an:
        half = a['core'] / 2
        if a['slot'] in ('capital', 'start'):
            continue
        if abs(a['x']) - half > R or abs(a['z']) - half > R:
            continue
        ax0, ay0 = P(a['x'] - half, a['z'] + half)
        ax1, ay1 = P(a['x'] + half, a['z'] - half)
        col = (255, 230, 0) if a['kind'] != 'arena' else (230, 0, 200)
        dr.rectangle((ax0, ay0, ax1, ay1), outline=(0, 0, 0), width=4)
        dr.rectangle((ax0, ay0, ax1, ay1), outline=col, width=2)
        label = SHORT.get(a['kind'], a['kind'])
        tx, ty = ax1 + 4, ay0 - 2
        dr.text((tx, ty), label, font=f_small, fill=(0, 0, 0), stroke_width=3,
                stroke_fill=(255, 255, 255))
    # fortresses outside the window: an arrow at the edge
    for fo in st['fortresses']:
        if abs(fo['x']) <= R and abs(fo['z']) <= R:
            continue
        s = R / max(abs(fo['x']), abs(fo['z']))
        ex, ez = fo['x'] * s * 0.93, fo['z'] * s * 0.93
        px, py = P(ex, ez)
        dr.polygon([(px, py - 10), (px - 8, py + 6), (px + 8, py + 6)] if fo['z'] > 0 else
                   [(px, py + 10), (px - 8, py - 6), (px + 8, py - 6)], fill=(0, 0, 0))
        dr.text((px + 12, py - 9), f"fortress {fo['dist']} nodes ({fo['x']}, {fo['z']})",
                font=f_small, fill=(0, 0, 0), stroke_width=3, stroke_fill=(255, 255, 255))
    # axis ticks and scale
    for v in range(-R + 6, R, 50):
        pass
    for v in range(-250, 251, 50):
        px, _ = P(v, 0)
        dr.line((px, oy, px, oy + 8), fill=(0, 0, 0), width=1)
        _, py = P(0, v)
        dr.line((0, py, 8, py), fill=(0, 0, 0), width=1)
    sx, sy = 20, oy + W - 30
    dr.rectangle((sx - 6, sy - 24, sx + 100 * PX + 50, sy + 14), fill=(255, 255, 255))
    dr.line((sx, sy, sx + 100 * PX, sy), fill=(0, 0, 0), width=4)
    for k in (0, 50, 100):
        dr.line((sx + k * PX, sy - 6, sx + k * PX, sy + 6), fill=(0, 0, 0), width=2)
    dr.text((sx, sy - 24), '0         50        100 nodes', font=f_small, fill=(0, 0, 0))
    dr.text((W - 70, oy + 10), 'N (+z)', font=f_mid, fill=(0, 0, 0), stroke_width=3,
            stroke_fill=(255, 255, 255))
    dr.text((10, 8), f'Seed {seed}{title_extra}: the map centre, x and z -256..256',
            font=f_big, fill=(0, 0, 0))
    # panel
    x = W + 16
    y = oy + 4
    lines = [('Legend', True),
             ('red road: the middle road (Highcourt - Gor Drazhak)', False),
             ('brown: other roads, trails lighter', False),
             ('blue: lake / river, dark blue: sea', False),
             ('black line: zone border, 35 The Broken Causeway (west)', False),
             ('  and 36 The Shattered Line (east)', False),
             ('yellow boxes: placed POIs (building core)', False),
             ('white dashed circle: 200 nodes from (0, 0)', False),
             ('magenta square: 100 x 100 at (0, 0)', False),
             ('', False),
             ('Within 200 nodes (measured)', True),
             (f"land height {st['land_height'][0]:.0f} .. {st['land_height'][1]:.0f} "
              f"(relief {st['relief_200']:.0f})", False),
             (f"grade (8-node) median {st['slope_p50']:.2f}, 90 % {st['slope_p90']:.2f}, "
              f"max {st['slope_max']:.1f}", False),
             (f"steeper than 1:2: {st['steep_share_gt_0_5']} %, than 1:1: {st['steep_share_gt_1']} % of land", False),
             (f"water: {st['water_share_200']} % " + ', '.join(f'{k} {v}' for k, v in st['water_by_class'].items()), False),
             (f"zones: {', '.join(str(z) for z in st['zones_within_200'])}", False),
             ('', False),
             ('100 x 100 at (0, 0)', True),
             (f"height {st['foot_100']['min']:.0f} .. {st['foot_100']['max']:.0f}, "
              f"lower median {st['foot_100']['lower_median']:.0f}", False),
             (f"levelling to it: cut {st['foot_100']['cut']}, fill {st['foot_100']['fill']} nodes",
              False),
             (f"water columns {st['foot_100']['water_columns']}, zones "
              f"{st['foot_100']['zones']}", False),
             ('', False),
             ('Middle road', True)]
    m = st['middle_road']
    if m:
        lines += [(f"crosses z = 0 at x = {m['cross_x_at_z0']}", False),
                  (f"closest to (0, 0): {m['min_dist_to_centre']} nodes", False),
                  (f"x range for |z| <= 200: {m['x_range_for_abs_z_le_200']}", False),
                  (f"passes the 100 x 100 square: {'yes' if m['through_footprint'] else 'no'}", False)]
    lines += [('', False), ('Fortresses', True)]
    for fo in st['fortresses']:
        lines.append((f"{fo['id']} zone {fo['zone']} at ({fo['x']}, {fo['z']}): {fo['dist']} nodes", False))
    lines += [('', False), ('Placements within 200', True)]
    for a in sorted(st['placements_within_200'], key=lambda a: a['dist']):
        lines.append((f"{SHORT.get(a['kind'], a['kind'])} ({a['x']}, {a['z']}), {a['dist']} nodes", False))
    for text, bold in lines:
        dr.text((x, y), text, font=font(16, bold), fill=(0, 0, 0))
        y += 22
    # colour bar
    y += 10
    for i in range(200):
        c = ramp(np.array([i / 199]))[0].astype(int)
        dr.line((x + i * 2, y, x + i * 2 + 1, y + 14), fill=tuple(c))
    dr.text((x, y + 16), f'{lo:.0f}', font=f_small, fill=(0, 0, 0))
    dr.text((x + 360, y + 16), f'{hi:.0f}', font=f_small, fill=(0, 0, 0))
    dr.text((x + 150, y + 16), 'land height (y)', font=f_small, fill=(0, 0, 0))
    canvas.save(path, optimize=True)


def render_diff(d, variant, seed, path):
    import cmp as C  # noqa: the comparison's loaders
    meta, wb = C.load_world(f'{d}/base-{seed}/world.txt')
    _, wv = C.load_world(f'{d}/{variant}-{seed}/world.txt')
    nx, nz = len(wb), len(wb[0])
    zone = np.zeros((nx, nz), int)
    chg = np.zeros((nx, nz), int)
    for i in range(nx):
        rb, rv = wb[i], wv[i]
        for j in range(nz):
            zb = int(rb[j].split(':', 1)[0])
            zone[i, j] = zb
            if rb[j] != rv[j]:
                chg[i, j] = 1
    step, x0, z0 = meta['step'], meta['min_x'], meta['min_z']
    rgb = np.full((nx, nz, 3), (40, 80, 150), float)
    land = zone > 0
    rgb[land] = (205, 205, 195)
    rgb[np.isin(zone, list(BG))] = (175, 190, 175)
    border = np.zeros(zone.shape, bool)
    border[1:, :] |= zone[1:, :] != zone[:-1, :]
    border[:, 1:] |= zone[:, 1:] != zone[:, :-1]
    rgb[border] = (90, 90, 90)
    inb = np.isin(zone, list(BG))
    rgb[(chg == 1) & inb] = (240, 200, 0)
    rgb[(chg == 1) & ~inb] = (220, 0, 0)
    img = np.transpose(rgb, (1, 0, 2))[::-1].astype(np.uint8)   # rows: z, north up
    world = Image.fromarray(img)
    dr = ImageDraw.Draw(world)
    rb_, rv_ = load_roads(f'{d}/base-{seed}/roads.tsv'), load_roads(f'{d}/{variant}-{seed}/roads.tsv')

    def wp(x, z):
        return (x - x0) / step, (nz - 1) - (z - z0) / step

    def cells(r):
        return {(round(p[0]), round(p[1])) for p in r['pts']} if r else set()
    for rid in set(rb_) | set(rv_):
        a, b = cells(rb_.get(rid)), cells(rv_.get(rid))
        for x, z in a ^ b:
            i = min(max(int(round((x - x0) / step)), 0), nx - 1)
            j = min(max(int(round((z - z0) / step)), 0), nz - 1)
            px, py = wp(x, z)
            col = (240, 200, 0) if zone[i, j] in BG else (220, 0, 0)
            dr.point((px, py), fill=col)
    # scale and title
    W, H = world.size
    canvas = Image.new('RGB', (W, H + 70), (250, 248, 244))
    canvas.paste(world, (0, 70))
    dc = ImageDraw.Draw(canvas)
    dc.text((10, 6), f'Seed {seed}, variant "{variant}": changed 8-node samples and road cells',
            font=font(20, True), fill=(0, 0, 0))
    dc.text((10, 36), 'red: outside the four Battlegrounds zones, yellow: inside them (green-grey); '
            'grey lines: zone borders; 1 px = 8 nodes', font=font(15), fill=(0, 0, 0))
    sx, sy = 20, H + 50
    dc.line((sx, sy, sx + 1000 / step, sy), fill=(0, 0, 0), width=3)
    dc.text((sx, sy - 20), '1000 nodes', font=font(14), fill=(0, 0, 0))
    canvas.save(path, optimize=True)


if __name__ == '__main__':
    sys.path.insert(0, __file__.rsplit('/', 1)[0])
    if sys.argv[1] == '--diff':
        d, pic, variant = sys.argv[2], sys.argv[3], sys.argv[4]
        for seed in sys.argv[5:]:
            render_diff(d, variant, seed, f'{pic}/change-{variant}-{seed}.png')
            print('wrote', f'{pic}/change-{variant}-{seed}.png')
    else:
        d, pic = sys.argv[1], sys.argv[2]
        allst = {}
        for seed in sys.argv[3:]:
            st = stats_of(f'{d}/base-{seed}', seed)
            allst[seed] = st
            render_centre(f'{d}/base-{seed}', seed, st, f'{pic}/centre-{seed}.png')
            print('wrote', f'{pic}/centre-{seed}.png')
        json.dump(allst, open(f'{pic}/stats.json', 'w'), indent=1)
