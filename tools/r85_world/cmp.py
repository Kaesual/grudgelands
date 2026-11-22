#!/usr/bin/env python3
"""Round 85 WORLD: what the arena moved against an earlier world, per seed.

Reads two output folders of tools/r84_site/site.lua (variant "base"), one
made on the earlier tree and one on this one, and compares them as
tools/r84_site/cmp.py does, except that roads are matched by their cells,
not by their ids (the middle road is three roads now, so every later road's
id shifts): the middle road (Highcourt - Gor Drazhak before; every road
from an arena mouth now) is reported on its own, and every other road cell
that only one world holds is a moved road cell. A changed whole-world grid
sample within about NEAR nodes of a moved road cell or of the middle road
(old or new) is counted as the roads' (their cut, fill, fords and banks);
one in the zones of the middle road's two capitals (CAPITAL_ZONES) as their
capital layout's (its streets and gates meet the middle road, Round 22
capital planner); the rest is reported.

  python3 tools/r85_world/cmp.py <old dir> <new dir> <seed>...
      (<dir>/base-<seed>/ from tools/r84_site/run.sh); prints a summary per
      seed and writes <new dir>/base-<seed>/moved.json
"""
import json
import math
import sys

BG = {34, 35, 36, 37}
NEAR = 16
MIDDLE_OLD = ('anchor_008', 'anchor_011')
CAPITAL_ZONES = {8, 24}


def load_world(path):
    with open(path) as f:
        head = f.readline().split()
        meta = dict(zip(head[1::2], map(int, head[2::2])))
        rows = [line.split() for line in f]
    return meta, rows


def anchors(path):
    out = {}
    for line in open(path):
        f = line.rstrip('\n').split('\t')
        out[f[0]] = {'zone': int(f[1]), 'zone_id': f[2], 'kind': f[4],
                     'x': f[6], 'z': f[7], 'y': f[8]}
    return out


def road_cells(path):
    middle, other = {}, {}
    for line in open(path):
        f = line.rstrip('\n').split('\t')
        a, b = f[2], f[3]
        cell = (round(float(f[4])), round(float(f[5])))
        is_middle = (a, b) == MIDDLE_OLD or a.startswith('breach_') or b.startswith('breach_')
        (middle if is_middle else other)[cell] = float(f[6])
    return middle, other


def main():
    old_dir, new_dir, seeds = sys.argv[1], sys.argv[2], sys.argv[3:]
    for seed in seeds:
        b, v = f'{old_dir}/base-{seed}', f'{new_dir}/base-{seed}'
        meta, wb = load_world(b + '/world.txt')
        _, wv = load_world(v + '/world.txt')
        step, x0, z0 = meta['step'], meta['min_x'], meta['min_z']

        def zone_at(x, z):
            i = min(max(int(round((x - x0) / step)), 0), len(wb) - 1)
            j = min(max(int(round((z - z0) / step)), 0), len(wb[0]) - 1)
            return int(wb[i][j].split(':')[0])

        print(f'===== seed {seed}')
        texts = {t: open(f'{b}/{t}.txt').read() == open(f'{v}/{t}.txt').read()
                 for t in ('placement', 'water', 'road', 'capital')}
        print(' layout texts identical:', ', '.join(f'{k} {"yes" if s else "NO"}' for k, s in texts.items()))
        ab, av = anchors(b + '/anchors.tsv'), anchors(v + '/anchors.tsv')
        moved = [k for k in ab if (ab[k]['x'], ab[k]['z'], ab[k]['y']) != (av[k]['x'], av[k]['z'], av[k]['y'])]
        out_anchors = [k for k in moved if ab[k]['zone'] not in BG]
        print(f' anchors moved: {len(moved)}, outside the Battlegrounds: {len(out_anchors)}'
              + (' ' + ', '.join(f"{k} ({ab[k]['zone_id']} {ab[k]['kind']})" for k in out_anchors)
                 if out_anchors else ''))
        mb, ob = road_cells(b + '/roads.tsv')
        mv, ov = road_cells(v + '/roads.tsv')
        moved_cells = set(ob) ^ set(ov)
        moved_cells |= {p for p in set(ob) & set(ov) if ob[p] != ov[p]}
        by_zone = {}
        for p in moved_cells:
            zn = zone_at(*p)
            by_zone[zn] = by_zone.get(zn, 0) + 1
        out_cells = {k: c for k, c in by_zone.items() if k not in BG}
        middle_zones_old, middle_zones_new = {}, {}
        for cells, zones in ((mb, middle_zones_old), (mv, middle_zones_new)):
            for p in cells:
                zn = zone_at(*p)
                zones[zn] = zones.get(zn, 0) + 1
        print(f' middle road: {len(mb)} cells before, {len(mv)} now; zones before '
              f'{dict(sorted(middle_zones_old.items()))}, now {dict(sorted(middle_zones_new.items()))}')
        print(f' other roads: {len(moved_cells)} cells moved, by zone {dict(sorted(by_zone.items()))}')
        # road cells (moved ones and both middle roads) on a NEAR grid
        near = set()
        for p in list(moved_cells) + list(mb) + list(mv):
            for dz in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    near.add((p[0] // NEAR + dx, p[1] // NEAR + dz))
        grid = {'bg': 0, 'out_road': 0, 'out_capital': 0, 'out_other': 0}
        other_samples, other_zones = [], {}
        for i, (cb, cv) in enumerate(zip(wb, wv)):
            if cb == cv:
                continue
            x = x0 + i * step
            for j, (sb, sv) in enumerate(zip(cb, cv)):
                if sb == sv:
                    continue
                z = z0 + j * step
                pb, pv = sb.split(':'), sv.split(':')
                zb = int(pb[0])
                if zb in BG and (int(pv[0]) in BG or pv[0] == '0'):
                    grid['bg'] += 1
                elif (x // NEAR, z // NEAR) in near and pb[0] == pv[0]:
                    grid['out_road'] += 1
                elif zb in CAPITAL_ZONES and pb[0] == pv[0]:
                    grid['out_capital'] += 1
                else:
                    grid['out_other'] += 1
                    other_zones[zb] = other_zones.get(zb, 0) + 1
                    if len(other_samples) < 200:
                        other_samples.append({'x': x, 'z': z, 'before': sb, 'now': sv})
        print(f" grid samples changed: {grid['bg']} in the Battlegrounds, {grid['out_road']} outside "
              f"beside a moved road, {grid['out_capital']} in the two capitals' zones, "
              f"{grid['out_other']} otherwise {dict(sorted(other_zones.items()))}")
        for s in other_samples[:8]:
            print(f"   {s['x']},{s['z']}: {s['before']} -> {s['now']}")
        json.dump({'texts': texts, 'anchors_moved': moved, 'anchors_moved_outside': out_anchors,
                   'middle_old': middle_zones_old, 'middle_new': middle_zones_new,
                   'road_cells_by_zone': by_zone, 'road_cells_outside': out_cells, 'grid': grid,
                   'grid_other_by_zone': other_zones, 'grid_other': other_samples},
                  open(v + '/moved.json', 'w'))


if __name__ == '__main__':
    main()
