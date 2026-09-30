#!/usr/bin/env python3
"""Round 27 wall fixes: one before/after table of gate_gaps.lua fleets.

  wall_summary.py MAIN.tsv BRANCH.tsv

Totals over the seeds both files hold (gap, leak, road, dip, cross, named,
req, open, float, fgate, hang), the open and line columns by road kind, and
per capital: open, float, dip and named/req.
"""
import re
import sys

COLS = ['gap', 'caps', 'leak', 'off', 'road', 'dip', 'cross', 'named', 'req',
        'open', 'float', 'fgate', 'hang']
CAPS = ['highcourt', 'dur_brannoc', 'nhal_veyr', 'gor_drazhak', 'lethariel', 'kezamba']


def load(path):
    rows = {}
    for line in open(path):
        f = line.rstrip('\n').split('\t')
        if len(f) < 15 or f[1] in ('ERROR', 'MISSING'):
            rows[f[0]] = None
            continue
        tot = dict(zip(COLS, map(int, f[1:14])))
        caps = {}
        for key, body in re.findall(r'(\w+)\[([^\]]*)\]', f[14]):
            d = {}
            for kv in body.split(';'):
                k, _, v = kv.partition('=')
                d[k] = v
            caps[key] = d
        rows[f[0]] = (tot, caps)
    return rows


def kinds(rows, field):
    out = {}
    for r in rows.values():
        if not r:
            continue
        for d in r[1].values():
            for kv in filter(None, d.get(field, '').split(',')):
                k, _, v = kv.partition(':')
                out[k] = out.get(k, 0) + int(v)
    return out


a, b = load(sys.argv[1]), load(sys.argv[2])
seeds = [s for s in a if s in b and a[s] and b[s]]
bad = [s for s in set(a) | set(b) if not (a.get(s) and b.get(s))]
print(f'seeds compared: {len(seeds)}' + (f'  (errors or missing: {" ".join(sorted(bad))})' if bad else ''))
print(f'{"":24}{"main":>12}{"branch":>12}   seeds with >0 (main -> branch)')
for c in COLS:
    ta = sum(a[s][0][c] for s in seeds)
    tb = sum(b[s][0][c] for s in seeds)
    na = sum(1 for s in seeds if a[s][0][c] > 0)
    nb = sum(1 for s in seeds if b[s][0][c] > 0)
    print(f'{c:24}{ta:12}{tb:12}   {na} -> {nb}')
for field in ('openk', 'linek'):
    ka, kb = kinds({s: a[s] for s in seeds}, field), kinds({s: b[s] for s in seeds}, field)
    print(f'{field} by road kind: main {dict(sorted(ka.items()))}  branch {dict(sorted(kb.items()))}')
print()
print(f'{"capital":14}' + ''.join(f'{c:>16}' for c in ('open', 'float', 'fgate', 'dip', 'line', 'named', 'req')))
for cap in CAPS:
    cells = []
    for c in ('open', 'float', 'fgate', 'dip', 'line', 'named', 'req'):
        va = sum(int(a[s][1][cap].get(c, 0)) for s in seeds if cap in a[s][1])
        vb = sum(int(b[s][1][cap].get(c, 0)) for s in seeds if cap in b[s][1])
        cells.append(f'{va:>7} -> {vb:<5}')
    print(f'{cap:14}' + ''.join(f'{x:>16}' for x in cells))
# per capital and seed: dips and road columns better / worse
for c in ('dip', 'road'):
    better = worse = same = 0
    for s in seeds:
        for cap in CAPS:
            va, vb = int(a[s][1][cap][c]), int(b[s][1][cap][c])
            if vb < va:
                better += 1
            elif vb > va:
                worse += 1
            else:
                same += 1
    print(f'per capital and seed, {c}: better {better}, worse {worse}, same {same}')
