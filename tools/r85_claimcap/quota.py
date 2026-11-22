#!/usr/bin/env python3
"""Round 85 CLAIMCAP follow-up 2: the decided mask and the quota at placement.

  python3 tools/r85_claimcap/quota.py <outdir> <seed>...
      reads <outdir>/quota/<seed>-<faction>.npz (analyze.py), writes
      <outdir>/quota-<seed>.json and <outdir>/quota.md (production first, the
      other seeds as min / median / max).

The mask: A + B + C + D2 in the faction's seven level 11-30 zones and three
capital zones, one whole chunk from the capital's protected city shape
(applied to chunks with capital-zone ground: "cap"; or to every chunk: "all").

The quota, for every quest-named kind (a recipe kind with quest_target,
zone/kind): the claimed share of the kind's ground stays at most one half.
  area   ground = the kind's spawn cells (32 x 32) in its zone, counted in
         columns; a claim uses the columns of those cells inside its chunk
  cells  ground = the same cells, counted whole; a claim uses every cell it
         touches
Ground outside the mask counts as free (the half is of all the kind's ground).
"half of the claimable ground" is reported for comparison ("area_mask").

For each: the most simultaneous claims (a Lagrangian / LP upper bound by
subgradient descent and the best of several greedy fills; proven optimal
when they meet), the count when players claim in a plausible order (nearest
to an own capital first; uniformly random, 200 orders), the kinds that fill
up first, per zone and the capital rings.
"""
import json
import math
import os
import statistics
import sys

import numpy as np

FACTIONS = ['accord', 'throng']
RANDOM_ORDERS = 200


def lp_bound(A, b, iters=4000):
    """min over lambda >= 0 of sum(lambda b) + sum_c max(0, 1 - (A lambda)_c):
    the LP relaxation's value, an upper bound on the integer optimum."""
    if A.shape[0] == 0:
        return 0.0
    used = A.sum(0) > 0
    A, b = A[:, used].astype(float), b[used].astype(float)
    if A.shape[1] == 0:
        return float(A.shape[0])
    scale = 6400.0
    A, b = A / scale, b / scale
    lam = np.zeros(A.shape[1])
    best = math.inf
    for t in range(iters):
        red = 1 - A @ lam
        val = float(lam @ b + np.maximum(red, 0).sum())
        best = min(best, val)
        g = b - A[red > 0].sum(0)
        nrm = float(g @ g)
        if nrm == 0:
            break
        step = 0.5 / math.sqrt(t + 1)
        lam = np.maximum(0.0, lam - step * g / math.sqrt(nrm))
    return best


def fill(A, b, order):
    """Take chunks in the given order when every kind stays within b."""
    used = np.zeros(A.shape[1], np.int64)
    taken = []
    first_refusal = {}
    for n in order:
        row = A[n]
        over = (used + row) > b
        if over.any():
            for k in np.nonzero(over)[0]:
                first_refusal.setdefault(int(k), len(taken))
            continue
        used += row
        taken.append(int(n))
    return taken, first_refusal, used


def best_fill(A, b, rng):
    """The best of greedy fills by several cost orders and random tie breaks."""
    n = A.shape[0]
    if n == 0:
        return []
    bb = np.maximum(b, 1)
    costs = [(A / bb).sum(1), (A / bb).max(1), (A > 0).sum(1) + (A / bb).sum(1)]
    best = None
    for cost in costs:
        for r in range(20):
            jitter = rng.random(n) * 1e-6 if r else np.zeros(n)
            order = np.lexsort((jitter, cost))
            taken, _, used = fill(A, b, order)
            # add what still fits, in any order
            rest = [i for i in range(n) if i not in set(taken)]
            for i in rest:
                if not ((used + A[i]) > b).any():
                    used += A[i]
                    taken.append(i)
            if best is None or len(taken) > len(best):
                best = taken
    return best


def improve(A, b, taken):
    """Local search: drop one taken chunk when two others then fit."""
    taken = list(taken)
    while True:
        tset = set(taken)
        used = A[taken].sum(0) if taken else np.zeros(A.shape[1], np.int64)
        rest = np.array([i for i in range(A.shape[0]) if i not in tset], int)
        if len(rest) < 2:
            return taken
        done = False
        for r in sorted(taken, key=lambda t: -int((A[t] > 0).sum())):
            if not A[r].any():
                continue
            u = used - A[r]
            fits = rest[~((u + A[rest]) > b).any(1)]
            for a_ in range(len(fits)):
                ua = u + A[fits[a_]]
                ok = fits[a_ + 1:][~((ua + A[fits[a_ + 1:]]) > b).any(1)]
                if len(ok):
                    taken.remove(r)
                    taken += [int(fits[a_]), int(ok[0])]
                    done = True
                    break
            if done:
                break
        if not done:
            return taken


def solve(A, b, rng):
    lb = improve(A, b, best_fill(A, b, rng))
    ub = lp_bound(A, b)
    return {'lb': len(lb), 'ub': round(ub, 2), 'proven': math.floor(ub + 1e-6) <= len(lb)}, lb


def study(path, seed):
    d = np.load(path)
    A_area, C, info, kcells = d['A'].astype(np.int64), d['C'].astype(np.int64), d['info'], d['kcells']
    names = dict(zip(d['zone_ids'].tolist(), d['zone_names'].tolist()))
    kz, kn = d['kzone'].tolist(), d['kname'].tolist()
    klabel = ['%s / %s' % (names[z], k) for z, k in zip(kz, kn)]
    cap_ids = set(d['cap_ids'].tolist())
    rng = np.random.default_rng(int(seed) % (2 ** 32))
    out = {'kinds': len(kcells), 'kind_cells': int(kcells.sum())}
    cand = {'area': (A_area, kcells * 1024 // 2),
            'cells': (C, kcells // 2),
            'area_mask': (A_area, A_area.sum(0) // 2)}
    for scope in ('cap', 'all'):
        sel = np.ones(len(info), bool) if scope == 'cap' else info[:, 4] == 1
        idx = np.nonzero(sel)[0]
        S = {'mask': int(len(idx)),
             'no_quest_ground': int((A_area[idx].sum(1) == 0).sum()),
             'pairs': int((A_area[idx] > 0).sum())}
        for cname, (M, b) in cand.items():
            if scope == 'all' and cname == 'area_mask':
                continue
            Mi = M[idx]
            res, lb = solve(Mi, b, rng)
            R = dict(res)
            # plausible orders
            dist = info[idx, 5]
            near = np.lexsort((info[idx, 1], info[idx, 0], dist))
            taken, fr, used = fill(Mi, b, near)
            R['nearest'] = len(taken)
            R['nearest_first_full'] = sorted(((v, klabel[k]) for k, v in fr.items()))[:8]
            rnd, firsts = [], {}
            for r in range(RANDOM_ORDERS):
                t, f, _ = fill(Mi, b, rng.permutation(len(idx)))
                rnd.append(len(t))
                for k, v in f.items():
                    firsts.setdefault(k, []).append(v)
            R['random'] = [min(rnd), statistics.median(rnd), max(rnd)]
            R['random_full'] = sorted(((statistics.median(v), len(v), klabel[k]) for k, v in firsts.items()))
            # per kind
            kinds = []
            for k in range(len(kcells)):
                col = Mi[:, k]
                touch = np.sort(col[col > 0])
                own = int((np.cumsum(touch) <= b[k]).sum())
                kinds.append({'kind': klabel[k], 'capital_zone': kz[k] in cap_ids, 'cells': int(kcells[k]),
                              'touching': int(len(touch)), 'own_capacity': own,
                              'mask_share_of_limit': round(float(touch.sum()) / max(1, b[k]), 2)})
            R['kinds'] = kinds
            # per zone (majority zone) and the capital rings, each alone
            zones_ = {}
            for z in sorted(set(info[idx, 2].tolist())):
                zi = np.nonzero(info[idx, 2] == z)[0]
                zr, _ = solve(Mi[zi], b, rng)
                zones_[names[z]] = {'mask': int(len(zi)), 'alone_lb': zr['lb'], 'alone_ub': zr['ub'],
                                    'in_best': int(sum(1 for t in lb if info[idx[t], 2] == z)),
                                    'nearest': int(sum(1 for t in taken if info[idx[t], 2] == z))}
            R['zones'] = zones_
            ci = np.nonzero(info[idx, 3] == 1)[0]
            cr, _ = solve(Mi[ci], b, rng)
            R['capital_chunks'] = {'mask': int(len(ci)), 'alone_lb': cr['lb'], 'alone_ub': cr['ub'],
                                   'in_best': int(sum(1 for t in lb if info[idx[t], 3] == 1)),
                                   'nearest': int(sum(1 for t in taken if info[idx[t], 3] == 1))}
            S[cname] = R
        out[scope] = S
    return out


def mmm(vals):
    vals = [v for v in vals if v is not None]
    if not vals:
        return '-'
    med = statistics.median(vals)
    f = lambda v: ('%d' % v) if float(v).is_integer() else ('%.1f' % v)
    return '%s / %s / %s' % (f(min(vals)), f(med), f(max(vals)))


def main():
    outdir, seeds = sys.argv[1], sys.argv[2:]
    res = []
    for seed in seeds:
        r = {fac: study(os.path.join(outdir, 'quota', '%s-%s.npz' % (seed, fac)), seed) for fac in FACTIONS}
        r['seed'] = seed
        with open(os.path.join(outdir, 'quota-%s.json' % seed), 'w') as f:
            json.dump(r, f, indent=1, default=lambda o: o.item() if hasattr(o, 'item') else str(o))
        res.append(json.loads(json.dumps(r, default=lambda o: o.item() if hasattr(o, 'item') else str(o))))
        print('quota', seed)
    prod, oth = res[0], res[1:]
    L = []
    w = L.append
    w('# CLAIMCAP follow-up 2: the quota (generated by tools/r85_claimcap/quota.py)\n')
    w('Production seed %s first; the other %d seeds as min / median / max.\n' % (prod['seed'], len(oth)))
    head = '| Measure | Accord prod | Accord others | Throng prod | Throng others |\n|---|---:|---:|---:|---:|'

    def row(name, fn):
        cells = []
        for fac in FACTIONS:
            v = fn(prod[fac])
            cells.append(str(v))
            cells.append(mmm([fn(r[fac]) for r in oth]))
        w('| %s | %s |' % (name, ' | '.join(cells)))

    for scope, title in (('cap', 'distance rule on chunks with capital-zone ground'),
                         ('all', 'distance rule on every chunk')):
        w('\n## Q-%s: %s\n' % (scope, title))
        w(head)
        row('mask chunks', lambda F: F[scope]['mask'])
        row('mask chunks in no quest kind\'s ground', lambda F: F[scope]['no_quest_ground'])
        for c in ('area', 'cells', 'area_mask'):
            if c not in prod['accord'][scope]:
                continue
            row('%s: most at once (best fill)' % c, lambda F, c=c: F[scope][c]['lb'])
            row('%s: LP upper bound' % c, lambda F, c=c: F[scope][c]['ub'])
            row('%s: proven optimal (seeds)' % c, lambda F, c=c: int(F[scope][c]['proven']))
            row('%s: nearest-capital order' % c, lambda F, c=c: F[scope][c]['nearest'])
            row('%s: random order, median of %d' % (c, RANDOM_ORDERS), lambda F, c=c: F[scope][c]['random'][1])
            row('%s: random order, worst of %d' % (c, RANDOM_ORDERS), lambda F, c=c: F[scope][c]['random'][0])
            for key, nm in (('mask', 'mask'), ('alone_lb', 'most at once alone'),
                            ('in_best', 'in the best fill'), ('nearest', 'in the nearest-capital order')):
                row('%s: chunks with capital-zone ground: %s' % (c, nm),
                    lambda F, c=c, key=key: F[scope][c]['capital_chunks'][key])
    for fac in FACTIONS:
        w('\n## Per zone, %s, production (cap scope; area rule)\n' % fac)
        w('| Zone | mask | alone max (area) | alone max (cells) | in the best fill | nearest order |')
        w('|---|---:|---:|---:|---:|---:|')
        Z = prod[fac]['cap']['area']['zones']
        Zc = prod[fac]['cap']['cells']['zones']
        for zn, e in Z.items():
            w('| %s | %d | %d | %d | %d | %d |' % (zn, e['mask'], e['alone_lb'], Zc[zn]['alone_lb'], e['in_best'],
                                               e['nearest']))
        w('\n## Kinds, %s, production (cap scope)\n' % fac)
        w('| Kind | cells | mask chunks touching | own capacity (area) | own capacity (cells) | mask ground / limit (area) |')
        w('|---|---:|---:|---:|---:|---:|')
        Ka = prod[fac]['cap']['area']['kinds']
        Kc = prod[fac]['cap']['cells']['kinds']
        for a, c in zip(Ka, Kc):
            w('| %s | %d | %d | %d | %d | %.2f |' % (a['kind'], a['cells'], a['touching'], a['own_capacity'],
                                                   c['own_capacity'], a['mask_share_of_limit']))
        w('\nFirst refusals in the nearest-capital order (area: claims placed before the kind refused one): ' +
          ', '.join('%s after %d' % (k, v) for v, k in prod[fac]['cap']['area']['nearest_first_full']))
        w('\nFirst refusals in random orders (area: median claims placed before, share of orders): ' +
          ', '.join('%s %g (%d%%)' % (k, m, round(100 * n / RANDOM_ORDERS))
                    for m, n, k in prod[fac]['cap']['area']['random_full'][:10]))
    w('\n## Tight kinds on every seed (cap scope; own capacity below half of the mask chunks touching it)\n')
    w('| Seed | Faction | Kind | touching | own capacity (area) | own capacity (cells) |')
    w('|---|---|---|---:|---:|---:|')
    for r in res:
        for fac in FACTIONS:
            for a, c in zip(r[fac]['cap']['area']['kinds'], r[fac]['cap']['cells']['kinds']):
                if a['touching'] and (a['own_capacity'] * 2 < a['touching'] or c['own_capacity'] * 2 < c['touching']):
                    w('| %s | %s | %s | %d | %d | %d |' % (r['seed'], fac, a['kind'], a['touching'],
                                                          a['own_capacity'], c['own_capacity']))
    with open(os.path.join(outdir, 'quota.md'), 'w') as f:
        f.write('\n'.join(L) + '\n')
    print('wrote', os.path.join(outdir, 'quota.md'))


if __name__ == '__main__':
    main()
