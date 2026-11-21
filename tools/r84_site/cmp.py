#!/usr/bin/env python3
"""Round 84 SITE: what a variant (site.lua arena/through/...) changes against
the shipped world (base) of the same seed, split into the four Battlegrounds
zones (34-37) and everything else.

  python3 tools/r84_site/cmp.py <dir> <variant> <seed>...   (dir holds
  base-<seed>/ and <variant>-<seed>/ from site.lua); prints a summary and
  writes <dir>/<variant>-<seed>/diff.json (the changed whole-world grid
  samples outside the Battlegrounds, the moved anchors, the changed roads).
"""
import json
import math
import sys

BG = {34, 35, 36, 37}


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
        out[f[0]] = {'zone': int(f[1]), 'zone_id': f[2], 'slot': f[3], 'kind': f[4],
                     'mode': f[5], 'x': int(f[6]), 'z': int(f[7]), 'y': int(f[8]),
                     'core': float(f[9]), 'fit': float(f[10])}
    return out


def roads(path):
    out = {}
    for line in open(path):
        f = line.rstrip('\n').split('\t')
        r = out.setdefault(int(f[0]), {'kind': f[1], 'a': f[2], 'b': f[3], 'pts': []})
        r['pts'].append((float(f[4]), float(f[5]), float(f[6])))
    return out


def main():
    d, variant, seeds = sys.argv[1], sys.argv[2], sys.argv[3:]
    for seed in seeds:
        b, v = f'{d}/base-{seed}', f'{d}/{variant}-{seed}'
        meta, wb = load_world(b + '/world.txt')
        _, wv = load_world(v + '/world.txt')
        step, x0, z0 = meta['step'], meta['min_x'], meta['min_z']

        def zone_at(x, z):
            i = min(max(int(round((x - x0) / step)), 0), len(wb) - 1)
            j = min(max(int(round((z - z0) / step)), 0), len(wb[0]) - 1)
            return int(wb[i][j].split(':')[0])

        print(f'===== {variant} seed {seed}')
        texts = {}
        for t in ('placement', 'water', 'road', 'capital'):
            texts[t] = open(f'{b}/{t}.txt').read() == open(f'{v}/{t}.txt').read()
        print(' layout texts identical:', ', '.join(f'{k} {"yes" if s else "NO"}' for k, s in texts.items()))
        # anchors
        ab, av = anchors(b + '/anchors.tsv'), anchors(v + '/anchors.tsv')
        moved = []
        for k, a in ab.items():
            n = av[k]
            if (a['x'], a['z'], a['y']) != (n['x'], n['z'], n['y']):
                moved.append({'id': k, 'zone': a['zone'], 'zone_id': a['zone_id'], 'kind': a['kind'],
                              'from': [a['x'], a['z'], a['y']], 'to': [n['x'], n['z'], n['y']],
                              'bg': a['zone'] in BG, 'only_y': (a['x'], a['z']) == (n['x'], n['z'])})
        out_bg = [m for m in moved if not m['bg']]
        print(f' anchors changed: {len(moved)} ({len(out_bg)} outside the Battlegrounds)')
        for m in out_bg:
            what = 'fitted y only' if m['only_y'] else 'moved'
            print(f"   {m['id']} {m['zone_id']} {m['kind']} {what} {tuple(m['from'])} -> {tuple(m['to'])}")
        # whole-world grid
        changed = {'bg': 0, 'out': 0}
        out_samples = []
        by_zone = {}
        for i, (cb, cv) in enumerate(zip(wb, wv)):
            if cb == cv:
                continue
            x = x0 + i * step
            for j, (sb, sv) in enumerate(zip(cb, cv)):
                if sb == sv:
                    continue
                z = z0 + j * step
                pb, pv = sb.split(':'), sv.split(':')
                zb, zv = int(pb[0]), int(pv[0])
                inside = zb in BG and (zv in BG or zv == 0)
                if inside:
                    changed['bg'] += 1
                    continue
                changed['out'] += 1
                what = []
                if pb[0] != pv[0]:
                    what.append('zone')
                if pb[1] != pv[1]:
                    what.append('height')
                if pb[2] != pv[2] or pb[3] != pv[3]:
                    what.append('water')
                dh = (int(pv[1]) - int(pb[1])) / 4 if pb[1] != 'n' and pv[1] != 'n' else None
                out_samples.append({'x': x, 'z': z, 'zone': zb, 'zone_to': zv, 'what': what,
                                    'dh': dh, 'water': [pb[2], pv[2], pb[3], pv[3]]})
                key = zb
                e = by_zone.setdefault(key, {'n': 0, 'what': {}, 'max_dh': 0, 'near': 1e9, 'far': 0})
                e['n'] += 1
                for w in what:
                    e['what'][w] = e['what'].get(w, 0) + 1
                if dh is not None:
                    e['max_dh'] = max(e['max_dh'], abs(dh))
                r = math.hypot(x, z)
                e['near'] = min(e['near'], r)
                e['far'] = max(e['far'], r)
        total = sum(len(c) for c in wb)
        print(f" grid samples ({step}-node, {total}) changed: {changed['bg']} inside the Battlegrounds, "
              f"{changed['out']} outside")
        for zn, e in sorted(by_zone.items(), key=lambda t: -t[1]['n']):
            print(f"   zone {zn}: {e['n']} samples {e['what']} max |dh| {e['max_dh']:.2f}, "
                  f"{e['near']:.0f}-{e['far']:.0f} from (0,0)")
        # roads
        rb, rv = roads(b + '/roads.tsv'), roads(v + '/roads.tsv')
        road_changes = []
        for rid in sorted(set(rb) | set(rv)):
            a, n = rb.get(rid), rv.get(rid)
            if a and n and a['pts'] == n['pts'] and (a['a'], a['b']) == (n['a'], n['b']):
                continue
            sa = {(round(p[0]), round(p[1])): p[2] for p in (a['pts'] if a else [])}
            sn = {(round(p[0]), round(p[1])): p[2] for p in (n['pts'] if n else [])}
            diff = [p for p in set(sa) ^ set(sn)] + [p for p in set(sa) & set(sn) if sa[p] != sn[p]]
            zones = {}
            for p in diff:
                zn = zone_at(*p)
                zones[zn] = zones.get(zn, 0) + 1
            outside = {k: c for k, c in zones.items() if k not in BG}
            road_changes.append({'id': rid, 'kind': (a or n)['kind'],
                                 'ends': [(a or n)['a'], (a or n)['b']],
                                 'ends_to': [n['a'], n['b']] if n else None,
                                 'points': [len(sa), len(sn)], 'changed_cells': len(diff),
                                 'zones': zones, 'outside': outside,
                                 'far': max((math.hypot(*p) for p in diff), default=0)})
        rout = [r for r in road_changes if r['outside']]
        print(f' roads changed: {len(road_changes)} ({len(rout)} with changed cells outside the Battlegrounds)')
        for r in road_changes:
            flag = 'OUT ' if r['outside'] else '    '
            print(f"   {flag}road {r['id']} {r['kind']} {r['ends'][0]}-{r['ends'][1]}: "
                  f"{r['changed_cells']} cells, zones {dict(sorted(r['zones'].items()))}, "
                  f"farthest {r['far']:.0f}")
        json.dump({'texts': texts, 'moved': moved, 'grid': changed, 'grid_by_zone': by_zone,
                   'grid_out': out_samples[:20000], 'roads': road_changes},
                  open(v + '/diff.json', 'w'))


if __name__ == '__main__':
    main()
