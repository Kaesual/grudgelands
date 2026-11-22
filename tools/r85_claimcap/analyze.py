#!/usr/bin/env python3
"""Round 85 CLAIMCAP: numbers and pictures from claimcap.lua's runs.

  python3 tools/r85_claimcap/analyze.py <outdir> <seed>...
      reads <outdir>/runs/<seed>/ (claimcap.lua), writes
      <outdir>/results-<seed>.json per seed, <outdir>/tables.md (the report's
      tables: the first seed is production, the others min / median / max)
      and <outdir>/claimcap-<faction>.png for the first seed.

Rule sets for one 80 x 80 chunk (x from 80 cx - 32 to 80 cx + 47, the same
in z), cumulative:
  A   every column passes grug_housing's column_problem for the faction (its
      level 11-30 home zones, no capital zone, no coastal shelf, no sea, no
      protected deep water, no town or landmark column)
  B   A, and no settlement core or hard footprint within 16 nodes (the
      placement check's feature_in; cross-checked per chunk against the exact
      answer claimcap.lua records)
  C   B, and no protected road column (road half width + 1, x/z only)
  D1  C, and no camp region cell (spawn_regions_core), no leader spot and no
      quest place within 16 nodes
  D2  D1, and no named rare's route point within 16 nodes
  D3  D2, and no cell of the largest region of a quest-named kind
  D3d D2, and no cell of a dense kind (instead of D3)
  D4  D2, and no cell of any region of a quest-named kind
"""
import json
import math
import os
import statistics
import sys

import numpy as np

FACTIONS = ['accord', 'throng']
FNAME = {'accord': 'The Accord', 'throng': 'The Throng'}
PCODE = {0: 'ok', 1: 'shelf', 2: 'sea', 3: 'enemy', 4: 'low_level', 5: 'high_level',
         6: 'capital_zone', 7: 'not_home', 8: 'town', 9: 'deep_water', 10: 'other',
         255: 'not_computed'}
SPOT = 16          # a leader, quest place or rare route point spoils a chunk this close
CH = 80            # chunk side
SIDE, RAD = 101, 50
LEVELS = ['A', 'B', 'C', 'D1', 'D2', 'D3', 'D3d', 'D4']
FONT = '/usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf'
FONT_B = '/usr/share/fonts/liberation-sans-fonts/LiberationSans-Bold.ttf'


def tsv(path):
    with open(path) as f:
        return [line.rstrip('\n').split('\t') for line in f if line.strip()]


def window_any(mask, m):
    """True where mask holds a True within m columns (Chebyshev), inside the frame."""
    if m == 0:
        return mask.copy()
    H, W = mask.shape
    S = np.zeros((H + 1, W + 1), np.int32)
    S[1:, 1:] = mask.astype(np.int32).cumsum(0, dtype=np.int32).cumsum(1, dtype=np.int32)
    r0 = np.clip(np.arange(H) - m, 0, H)
    r1 = np.clip(np.arange(H) + m + 1, 0, H)
    c0 = np.clip(np.arange(W) - m, 0, W)
    c1 = np.clip(np.arange(W) + m + 1, 0, W)
    out = S[r1][:, c1] - S[r0][:, c1] - S[r1][:, c0] + S[r0][:, c0]
    return out > 0


def fill_rect(mask, x0, z0, xa, xb, za, zb):
    """Set the inclusive world rectangle xa..xb, za..zb."""
    H, W = mask.shape
    a, b = max(0, xa - x0), min(W, xb - x0 + 1)
    c, d = max(0, za - z0), min(H, zb - z0 + 1)
    if a < b and c < d:
        mask[c:d, a:b] = True


def road_raster(rows, x0, z0, W, H):
    mask = np.zeros((H, W), bool)
    by = {}
    for r in rows:
        by.setdefault(r[0], []).append((float(r[2]), float(r[3]), float(r[1])))
    for pts in by.values():
        reach = pts[0][2]
        r2 = reach * reach
        for (ax, az, _), (bx, bz, _) in zip(pts, pts[1:]):
            xa = int(math.floor(min(ax, bx) - reach)) - x0
            xb = int(math.ceil(max(ax, bx) + reach)) - x0 + 1
            za = int(math.floor(min(az, bz) - reach)) - z0
            zb = int(math.ceil(max(az, bz) + reach)) - z0 + 1
            xa, xb, za, zb = max(0, xa), min(W, xb), max(0, za), min(H, zb)
            if xa >= xb or za >= zb:
                continue
            X = np.arange(xa, xb)[None, :] + x0
            Z = np.arange(za, zb)[:, None] + z0
            vx, vz = bx - ax, bz - az
            l2 = vx * vx + vz * vz
            u = ((X - ax) * vx + (Z - az) * vz) / l2 if l2 > 0 else np.zeros_like(X + Z, float)
            u = np.clip(u, 0, 1)
            dx, dz = X - ax - u * vx, Z - az - u * vz
            mask[za:zb, xa:xb] |= dx * dx + dz * dz <= r2
    return mask


def greedy_pack(valid):
    """Row-major first-fit of non-overlapping 101 x 101 squares on valid centres."""
    H, W = valid.shape
    blocked = np.zeros((H, W), bool)
    placed = []
    for r in range(H):
        # blocked[r] only changes in columns a placement in this row already
        # passed (c - 100 .. c + 100), so the candidates are read once per row
        cand = np.flatnonzero(valid[r] & ~blocked[r])
        idx = 0
        while idx < len(cand):
            c = int(cand[idx])
            placed.append((r, c))
            blocked[r:r + SIDE, max(0, c - SIDE + 1):c + SIDE] = True
            idx = int(np.searchsorted(cand, c + SIDE))
    return placed


def random_pack(valid, seed, runs=3):
    """Free placement as players do it (an estimate): valid centres in a
    random order, each taken when no earlier square overlaps it (random
    sequential placement); the mean over `runs` orders."""
    H, W = valid.shape
    flat = np.flatnonzero(valid)
    counts = []
    for k in range(runs):
        rng = np.random.default_rng(int(seed) % (2 ** 32) + k)
        blocked = np.zeros((H, W), bool)
        n = 0
        for v in rng.permutation(flat):
            r, c = divmod(int(v), W)
            if blocked[r, c]:
                continue
            n += 1
            blocked[max(0, r - SIDE + 1):r + SIDE, max(0, c - SIDE + 1):c + SIDE] = True
        counts.append(n)
    return sum(counts) / len(counts)


def lattice_pack(valid):
    best, arg = 0, (0, 0)
    for oz in range(SIDE):
        sub = valid[oz::SIDE]
        for ox in range(SIDE):
            n = int(sub[:, ox::SIDE].sum())
            if n > best:
                best, arg = n, (ox, oz)
    return best, arg


def analyse(run, seed, want_picture=False, outdir=None):
    meta = {r[0]: r[1:] for r in tsv(os.path.join(run, 'meta.tsv'))}
    zones = {}
    for r in tsv(os.path.join(run, 'zones.tsv')):
        zones[int(r[0])] = {'id': r[1], 'name': r[2], 'faction': r[3], 'lmin': int(r[5]),
                            'lmax': int(r[6]), 'accord': r[9], 'throng': r[10]}
    settlements = [{'key': r[0], 'label': r[1], 'slot': r[2], 'zone': int(r[4]),
                    'x': int(r[5]), 'z': int(r[6])} for r in tsv(os.path.join(run, 'settlements.tsv'))]
    boxes = tsv(os.path.join(run, 'boxes.tsv'))
    roads = tsv(os.path.join(run, 'roads.tsv'))
    cells = tsv(os.path.join(run, 'cells.tsv'))
    leaders = tsv(os.path.join(run, 'leaders.tsv'))
    places = tsv(os.path.join(run, 'places.tsv'))
    rares = tsv(os.path.join(run, 'rares.tsv'))
    res = {'seed': seed, 'factions': {}}
    for fac in FACTIONS:
        x0, z0, W, H = (int(v) for v in meta['frame_' + fac])
        raw = np.fromfile(os.path.join(run, 'raster_%s.bin' % fac), np.uint8).reshape(4, H, W)
        zid, wc, pa, terr = raw[0], raw[1], raw[2], raw[3]
        hgt = np.fromfile(os.path.join(run, 'height_%s.bin' % fac), '<i2').reshape(H // 4, W // 4)
        claim_ids = sorted(n for n, z in zones.items() if z[fac] == 'claim')
        cont_ids = sorted(n for n, z in zones.items() if z[fac] == 'contested')
        computed = zid != 255
        okA = (pa == 0) & computed
        in_claim = np.isin(zid, claim_ids)
        okCont = computed & np.isin(zid, cont_ids) & np.isin(wc, [1, 2]) & (terr == 3)
        # settlement cores and hard footprints
        feat = np.isin(terr, [4, 7])
        for b in boxes:
            fill_rect(feat, x0, z0, int(b[2]), int(b[3]), int(b[4]), int(b[5]))
        dil = {m: window_any(feat, m) for m in (16, 8, 0)}
        road = road_raster(roads, x0, z0, W, H)
        # D layers
        def cell_mask(pred):
            m = np.zeros((H, W), bool)
            for c in cells:
                if pred(c):
                    i, j = int(c[1]), int(c[2])
                    fill_rect(m, x0, z0, 32 * i, 32 * i + 31, 32 * j, 32 * j + 31)
            return m
        camp = cell_mask(lambda c: c[5] == '1')
        spots = np.zeros((H, W), bool)
        for l in leaders:
            x, z = int(l[2]), int(l[3])
            fill_rect(spots, x0, z0, x - SPOT, x + SPOT, z - SPOT, z + SPOT)
        for p in places:
            x, z = int(p[2]), int(p[3])
            fill_rect(spots, x0, z0, x - SPOT, x + SPOT, z - SPOT, z + SPOT)
        rare = np.zeros((H, W), bool)
        for r in rares:
            for k in range(4, 10, 2):
                x, z = int(r[k]), int(r[k + 1])
                fill_rect(rare, x0, z0, x - SPOT, x + SPOT, z - SPOT, z + SPOT)
        qlarge = cell_mask(lambda c: c[5] == '0' and c[6] == '1' and c[8] == '1')
        dense = cell_mask(lambda c: c[5] == '0' and c[7] == 'dense')
        qany = cell_mask(lambda c: c[5] == '0' and c[6] == '1')

        nbz, nbx = H // CH, W // CH
        cx0, cz0 = (x0 + 32) // CH, (z0 + 32) // CH

        def blk(a):
            return a.reshape(nbz, CH, nbx, CH)

        def ball(a):
            return blk(a).all(axis=(1, 3))

        def bany(a):
            return blk(a).any(axis=(1, 3))

        def bsum(a):
            return blk(a).sum(axis=(1, 3))

        touched = bany(in_claim)
        n_okA = bsum(okA)
        passA = n_okA == CH * CH
        passA_touch = ball(okA | okCont) & (n_okA * 2 >= CH * CH)
        passA_open = ball(okA | okCont)
        fB = {m: bany(dil[m]) for m in (16, 8, 0)}
        fC = bany(road)
        fD1 = bany(camp | spots)
        fD2 = fD1 | bany(rare)
        fD3 = fD2 | bany(qlarge)
        fD3d = fD2 | bany(dense)
        fD4 = fD2 | bany(qany)

        # exact feature_in cross-check
        exact = {}
        for r in tsv(os.path.join(run, 'chunks_%s.tsv' % fac)):
            exact[(int(r[0]), int(r[1]))] = (r[3] != '-', r[4] != '-', r[5] != '-')
        mism = 0
        compm = ball(computed)
        for (cx, cz), e in exact.items():
            bx, bz = cx - cx0, cz - cz0
            # touched chunks only: a ring chunk at the frame's edge may have a
            # feature beyond the computed frame (it fails A anyway)
            if compm[bz, bx] and touched[bz, bx] and (bool(fB[16][bz, bx]) != e[0] or bool(fB[8][bz, bx]) != e[1] or
                                  bool(fB[0][bz, bx]) != e[2]):
                mism += 1

        # majority claim zone of each touched chunk
        zb = blk(np.where(in_claim, zid, 0))
        major = np.zeros((nbz, nbx), int)
        for bz, bx in zip(*np.nonzero(touched)):
            cnt = np.bincount(zb[bz, :, bx, :].ravel(), minlength=40)
            cnt[0] = 0
            major[bz, bx] = int(cnt.argmax())
        # usability
        water_share = bsum(wc == 2) / (CH * CH)
        land_s = (wc[2::4, 2::4] == 1) & (hgt != -32768)
        hb = hgt.reshape(nbz, 20, nbx, 20).astype(float)
        lb = land_s.reshape(nbz, 20, nbx, 20)
        hmax = np.where(lb, hb, -1e9).max(axis=(1, 3))
        hmin = np.where(lb, hb, 1e9).min(axis=(1, 3))
        span = np.where(lb.any(axis=(1, 3)), hmax - hmin, np.nan)
        # distances
        own = [s for s in settlements if zones.get(s['zone'], {}).get('faction') == fac]
        caps = [s for s in own if s['slot'] == 'capital']
        ways = [s for s in own if s['slot'] in ('start', 'capital')] + \
               [s for s in settlements if s['key'] == 'pvp_fortress_' + fac]
        towns = [s for s in own if s['slot'] in ('start', 'capital') or s['slot'].startswith('village_')]

        def nearest(lst, x, z):
            return min(math.hypot(s['x'] - x, s['z'] - z) for s in lst)

        levels = {
            'A': passA,
            'B': passA & ~fB[16],
            'C': passA & ~fB[16] & ~fC,
            'D1': passA & ~fB[16] & ~fC & ~fD1,
            'D2': passA & ~fB[16] & ~fC & ~fD2,
            'D3': passA & ~fB[16] & ~fC & ~fD3,
            'D3d': passA & ~fB[16] & ~fC & ~fD3d,
            'D4': passA & ~fB[16] & ~fC & ~fD4,
        }
        F = {'touched': int(touched.sum()), 'feature_mismatch': mism, 'chunks_exact': len(exact),
             'levels': {k: int(v.sum()) for k, v in levels.items()},
             'zones': {}}
        for n in claim_ids:
            zt = touched & (major == n)
            F['zones'][zones[n]['name']] = {'touched': int(zt.sum()),
                                            **{k: int((v & (major == n)).sum()) for k, v in levels.items()}}
        # first excluding rule set, per touched chunk (for the picture)
        first = np.full((nbz, nbx), '', object)
        first[touched] = 'E'
        first[touched & fD2] = 'D'
        first[touched & fC] = 'C'
        first[touched & fB[16]] = 'B'
        first[touched & ~passA] = 'A'

        # Q2: today's squares
        Bcol = okA & ~dil[16]
        Ccol = Bcol & ~road
        F['area_B_columns'] = int(Bcol.sum())
        F['area_C_columns'] = int(Ccol.sum())
        F['upper_squares_B'] = Bcol.sum() / (SIDE * SIDE)
        F['upper_chunks_B'] = Bcol.sum() / (CH * CH)
        sq = {}
        for name, col in (('B', Bcol), ('C', Ccol)):
            valid = ~window_any(~col, RAD)
            valid[:RAD, :] = valid[-RAD:, :] = False
            valid[:, :RAD] = valid[:, -RAD:] = False
            g = greedy_pack(valid)
            lat, off = lattice_pack(valid)
            zc = {}
            for r, c in g:
                zn = zones[int(zid[r, c])]['name']
                zc[zn] = zc.get(zn, 0) + 1
            rnd = random_pack(valid, seed) if name == 'B' else None
            sq[name] = {'valid_centres': int(valid.sum()), 'greedy': len(g), 'lattice': lat,
                        'random': rnd,
                        'lattice_offset': off, 'greedy_zones': zc}
            if name == 'B':
                valid_B = valid
                greedy_B = g
        F['squares'] = sq
        # probe cross-check with grug_housing's validate
        agree = disagree = 0
        bad = []
        for r in tsv(os.path.join(run, 'validate_%s.tsv' % fac)):
            x, z, ok = int(r[0]), int(r[1]), r[2] == '1'
            v = bool(valid_B[z - z0, x - x0])
            if v == ok:
                agree += 1
            else:
                disagree += 1
                bad.append(r)
        F['validate'] = {'agree': agree, 'disagree': disagree, 'examples': bad[:5],
                         'accepted': sum(1 for r in tsv(os.path.join(run, 'validate_%s.tsv' % fac))
                                         if r[2] == '1')}

        # Q3 usability per level
        def usable(mask):
            idx = np.nonzero(mask)
            ws = water_share[idx]
            sp = span[idx]
            sp = sp[~np.isnan(sp)]
            return {'n': int(mask.sum()),
                    'mostly_water': int((ws > 0.5).sum()),
                    'any_water_quarter': int((ws > 0.25).sum()),
                    'span_median': float(np.median(sp)) if len(sp) else None,
                    'span_p90': float(np.percentile(sp, 90)) if len(sp) else None,
                    'span_gt20': int((sp > 20).sum()), 'span_gt40': int((sp > 40).sum())}
        F['usable'] = {k: usable(levels[k]) for k in ('C', 'D2', 'D3')}

        # Q4 spread and distances (D2 and C)
        def spread(mask):
            d_cap, d_way, d_town = [], [], []
            for bz, bx in zip(*np.nonzero(mask)):
                x = x0 + CH * bx + 40
                z = z0 + CH * bz + 40
                d_cap.append(nearest(caps, x, z))
                d_way.append(nearest(ways, x, z))
                d_town.append(nearest(towns, x, z))
            per = [int((mask & (major == n)).sum()) for n in claim_ids]
            out = {'zones_with_any': sum(1 for p in per if p > 0),
                   'top_zone_share': (max(per) / sum(per)) if sum(per) else None,
                   'min_zone': min(per), 'max_zone': max(per)}
            for k, d in (('capital', d_cap), ('waystone', d_way), ('town', d_town)):
                if d:
                    out[k] = {'median': float(np.median(d)), 'p90': float(np.percentile(d, 90)),
                              'max': float(max(d))}
            return out
        F['spread'] = {k: spread(levels[k]) for k in ('C', 'D2', 'D3')}

        # Q5 slivers and relaxed variants
        failA_t = touched & ~passA
        badfrac = 1 - n_okA / (CH * CH)
        sl = {}
        rest = ~fB[16] & ~fC & ~fD2
        for t in (0.01, 0.05, 0.10, 0.25):
            m = failA_t & (badfrac <= t)
            sl['<=%d%%' % round(t * 100)] = {'fail_A': int(m.sum()), 'then_pass_B_C_D2': int((m & rest).sum())}
        # reasons of the bad columns in chunks failing A by at most 10 %
        m10 = failA_t & (badfrac <= 0.10)
        reasons = {}
        pab = blk(pa)
        for bz, bx in zip(*np.nonzero(m10)):
            vals, cnts = np.unique(pab[bz, :, bx, :], return_counts=True)
            for v, c in zip(vals, cnts):
                if v != 0:
                    reasons[PCODE[int(v)]] = reasons.get(PCODE[int(v)], 0) + int(c)
        sl['reasons_columns_<=10%'] = reasons
        # chunk reasons: a chunk failing A, by the first problem of its bad columns
        why = {}
        for bz, bx in zip(*np.nonzero(failA_t)):
            vals, cnts = np.unique(pab[bz, :, bx, :], return_counts=True)
            d = {PCODE[int(v)]: int(c) for v, c in zip(vals, cnts) if v != 0}
            k = max(d, key=d.get)
            why[k] = why.get(k, 0) + 1
        sl['fail_A_main_reason'] = why
        F['slivers'] = sl
        F['margin'] = {
            'B16': int((passA & ~fB[16]).sum()), 'B8': int((passA & ~fB[8]).sum()),
            'B0': int((passA & ~fB[0]).sum()),
            'C_with_B8': int((passA & ~fB[8] & ~fC).sum()),
            'D2_with_B8': int((passA & ~fB[8] & ~fC & ~fD2).sum()),
            'D2_with_B0': int((passA & ~fB[0] & ~fC & ~fD2).sum()),
        }

        def var(pA):
            return {'A': int(pA.sum()), 'B': int((pA & ~fB[16]).sum()),
                    'C': int((pA & ~fB[16] & ~fC).sum()), 'D2': int((pA & ~fB[16] & ~fC & ~fD2).sum())}
        F['variants'] = {'today': var(passA), 'touch_31_40': var(passA_touch),
                         'open_31_40': var(passA_open)}
        F['borderline_A_le1pct'] = int((failA_t & (badfrac <= 0.01)).sum())
        # FOLLOW-UP (capital zones): the faction's three capital zones as claim
        # ground (zone_problem with the capital zone admitted: a column whose
        # only problem is "capital_zone" and whose territory at the world top
        # is the faction's home), and a distance of d whole chunks from every
        # chunk holding a column of the capital's protected city shape
        # (capital_protection.lua: inside the wall line, the wall and its
        # 21-node band; the hard footprint, territory "hard_protected").
        cap_ids = sorted(n for n, z in zones.items() if z[fac] == 'capital')
        home_code = 1 if fac == 'accord' else 2
        in_cap = np.isin(zid, cap_ids)
        okCap = computed & in_cap & (pa == 6) & (terr == home_code)
        okNew = okA | okCap
        passN = ball(okNew)
        wall_cols = (terr == 4) & in_cap
        wallch = bany(wall_cols)
        # D3h: per quest-named kind, its regions largest first until they hold
        # at least half of the kind's cells
        regs = {}
        for c in cells:
            if c[5] == '0' and c[6] == '1':
                regs.setdefault((c[0], c[4]), {}).setdefault(c[3], []).append(c)
        half_cells = []
        for (zn_, kid), rr in regs.items():
            tot = sum(len(v) for v in rr.values())
            acc = 0
            for rid, v in sorted(rr.items(), key=lambda kv: (-len(kv[1]), int(kv[0]))):
                if acc * 2 >= tot:
                    break
                half_cells.extend(v)
                acc += len(v)
        qhalf = np.zeros((H, W), bool)
        for c in half_cells:
            i, j = int(c[1]), int(c[2])
            fill_rect(qhalf, x0, z0, 32 * i, 32 * i + 31, 32 * j, 32 * j + 31)
        fD3h = fD2 | bany(qhalf)
        base = passN & ~fB[16] & ~fC
        nlev = {'A': passN, 'B': passN & ~fB[16], 'C': base, 'D1': base & ~fD1, 'D2': base & ~fD2,
                'D3': base & ~fD3, 'D3h': base & ~fD3h, 'D4': base & ~fD4}
        oldlev = {'A': passA, 'B': levels['B'], 'C': levels['C'], 'D1': levels['D1'],
                  'D2': levels['D2'], 'D3': levels['D3'], 'D3h': passA & ~fB[16] & ~fC & ~fD3h,
                  'D4': levels['D4']}
        has_cap = bany(in_cap)
        touched2 = bany(in_claim | in_cap)
        zb2 = blk(np.where(in_claim | in_cap, zid, 0))
        major2 = np.zeros((nbz, nbx), int)
        for bz, bx in zip(*np.nonzero(touched2)):
            cnt = np.bincount(zb2[bz, :, bx, :].ravel(), minlength=40)
            cnt[0] = 0
            major2[bz, bx] = int(cnt.argmax())
        capsets = {cs['zone']: cs for cs in settlements if cs['slot'] == 'capital'}
        CAP = {'touched_capital_zone_chunks': int(has_cap.sum()),
               'capital_land_chunks': int(bany(in_cap & np.isin(wc, [1, 2]) & (terr != 4)).sum()),
               'wall_chunks': int(wallch.sum()), 'old_D3h': int(oldlev['D3h'].sum()),
               'dist': {}}
        for dd in (0, 1, 2, 3):
            wex = window_any(wallch, dd) if dd else wallch.copy()
            row = {}
            for lev in ('A', 'B', 'C', 'D1', 'D2', 'D3', 'D3h', 'D4'):
                new = nlev[lev] & ~wex
                add = new & ~oldlev[lev]
                row[lev] = {'total': int(new.sum()), 'added': int(add.sum()),
                            'old_lost': int((oldlev[lev] & wex).sum()),
                            'added_in_capital_majority': int((add & np.isin(major2, cap_ids)).sum())}
            # per zone (majority zone, claim and capital zones), D3 and D2
            # (the distance rule applied to chunks with capital-zone ground only)
            row['zones'] = {zones[n]['name']: {lev: int((nlev[lev] & ~(wex & has_cap) & (major2 == n)).sum())
                                               for lev in ('C', 'D2', 'D3')}
                            for n in claim_ids + cap_ids}
            # what D removes among the added chunks that pass A, B, C and the wall rule
            addC = nlev['C'] & ~wex & ~oldlev['C']
            row['d_removes_in_added'] = {
                'C': int(addC.sum()),
                'camp_leader_place': int((addC & fD1).sum()),
                'rare': int((addC & ~fD1 & bany(rare)).sum()),
                'quest_largest': int((addC & ~fD2 & bany(qlarge)).sum()),
                'quest_half': int((addC & ~fD2 & bany(qhalf)).sum()),
                'quest_any': int((addC & ~fD2 & bany(qany)).sum())}
            # building ground and distances of the added D3 chunks
            addD3 = nlev['D3'] & ~wex & ~oldlev['D3']
            idx = np.nonzero(addD3)
            sp = span[idx]
            sp = sp[~np.isnan(sp)]
            ws = water_share[idx]
            dcap = []
            for bz, bx in zip(*idx):
                xc, zc = x0 + CH * bx + 40, z0 + CH * bz + 40
                dcap.append(min(math.hypot(cs['x'] - xc, cs['z'] - zc) for cs in capsets.values()
                                if zones[cs['zone']]['faction'] == fac))
            row['usable_added_D3'] = {
                'n': int(addD3.sum()), 'mostly_water': int((ws > 0.5).sum()),
                'water_gt25': int((ws > 0.25).sum()),
                'span_median': float(np.median(sp)) if len(sp) else None,
                'span_gt20': int((sp > 20).sum()), 'span_gt40': int((sp > 40).sum()),
                'cap_median': float(np.median(dcap)) if dcap else None,
                'cap_min': float(min(dcap)) if dcap else None,
                'cap_max': float(max(dcap)) if dcap else None}
            CAP['dist'][str(dd)] = row
        # the capital zones' spawn content
        czs = {}
        for n in cap_ids:
            cz_cells = [c for c in cells if int(c[0]) == n]
            nc = len(cz_cells)
            czs[zones[n]['name']] = {
                'cells': nc,
                'camp_cells': sum(1 for c in cz_cells if c[5] == '1'),
                'quest_cells': sum(1 for c in cz_cells if c[5] == '0' and c[6] == '1'),
                'quest_largest_cells': sum(1 for c in cz_cells if c[5] == '0' and c[6] == '1' and c[8] == '1'),
                'quest_half_cells': sum(1 for c in half_cells if int(c[0]) == n),
                'quest_kinds': sorted({c[4] for c in cz_cells if c[5] == '0' and c[6] == '1'}),
                'leaders': [l[1] for l in leaders if int(l[0]) == n],
                'places': [q[1] for q in places if int(q[0]) == n]}
        CAP['capital_zone_content'] = czs
        # D3's sensitivity: quest-named kinds of this faction's claim zones,
        # their region sizes, and the D3 chunks owed to a near tie (the second
        # region at least 80 % of the largest)
        kinds = []
        tie_cells = []
        for (zn_, kid), rr in regs.items():
            if int(zn_) not in claim_ids:
                continue
            sizes = sorted((len(v) for v in rr.values()), reverse=True)
            tot = sum(sizes)
            kinds.append({'zone': int(zn_), 'kind': kid, 'regions': len(sizes), 'cells': tot,
                          'largest': sizes[0], 'second': sizes[1] if len(sizes) > 1 else 0})
            if len(sizes) > 1 and sizes[1] >= 0.8 * sizes[0]:
                big = max(rr.items(), key=lambda kv: (len(kv[1]), -int(kv[0])))
                tie_cells.extend(big[1])
        tie = np.zeros((H, W), bool)
        for c in tie_cells:
            i, j = int(c[1]), int(c[2])
            fill_rect(tie, x0, z0, 32 * i, 32 * i + 31, 32 * j, 32 * j + 31)
        d3only = levels['D2'] & ~levels['D3']
        shares = [k['largest'] / k['cells'] for k in kinds]
        F['d3_stats'] = {
            'quest_kinds': len(kinds),
            'kinds_one_region': sum(1 for k in kinds if k['regions'] == 1),
            'kinds_near_tie': sum(1 for k in kinds if k['regions'] > 1 and k['second'] >= 0.8 * k['largest']),
            'largest_share_median_pct': int(round(100 * float(np.median(shares)))) if shares else None,
            'largest_share_lt_half': sum(1 for v in shares if v < 0.5),
            'largest_region_cells_max': max((k['largest'] for k in kinds), default=0),
            'd3_removed_chunks': int(d3only.sum()),
            'd3_removed_near_tie': int((d3only & bany(tie)).sum())}
        F['capitals'] = CAP
        # FOLLOW-UP 2 (the quota): the decided mask (A + B + C + D2 in the
        # seven claim zones and the three capital zones, one whole chunk from
        # the city shape) and every quest-named kind's ground per mask chunk,
        # written for quota.py
        wex1 = window_any(wallch, 1)
        mask_cap = nlev['D2'] & ~(wex1 & has_cap)
        mask_all = nlev['D2'] & ~wex1
        qkeys = sorted({(int(c[0]), c[4]) for c in cells
                        if c[5] == '0' and c[6] == '1' and int(c[0]) in claim_ids + cap_ids})
        qindex = {k: n for n, k in enumerate(qkeys)}
        kcells = np.zeros(len(qkeys), int)
        kidx = np.full((H, W), -1, np.int16)
        cellkind = {}
        for c in cells:
            key = (int(c[0]), c[4])
            if c[5] == '0' and c[6] == '1' and key in qindex:
                q = qindex[key]
                kcells[q] += 1
                i, j = int(c[1]), int(c[2])
                cellkind[(i, j)] = q
                xa_, za_ = 32 * i - x0, 32 * j - z0
                if 0 <= xa_ and xa_ + 32 <= W and 0 <= za_ and za_ + 32 <= H:
                    kidx[za_:za_ + 32, xa_:xa_ + 32] = q
                else:
                    fill = np.zeros((H, W), bool)
                    fill_rect(fill, x0, z0, 32 * i, 32 * i + 31, 32 * j, 32 * j + 31)
                    kidx[fill] = q
        kb = blk(kidx)
        chunks_q = list(zip(*np.nonzero(mask_cap)))
        A = np.zeros((len(chunks_q), len(qkeys)), np.int32)
        Ccnt = np.zeros((len(chunks_q), len(qkeys)), np.int32)
        info = np.zeros((len(chunks_q), 6), np.int64)
        for n, (bz, bx) in enumerate(chunks_q):
            v = kb[bz, :, bx, :].ravel()
            v = v[v >= 0]
            if len(v):
                A[n] = np.bincount(v, minlength=len(qkeys))
            xa_, za_ = x0 + CH * bx, z0 + CH * bz
            for i in range(xa_ // 32, (xa_ + CH - 1) // 32 + 1):
                for j in range(za_ // 32, (za_ + CH - 1) // 32 + 1):
                    q = cellkind.get((i, j))
                    if q is not None:
                        Ccnt[n, q] += 1
            xc, zc = xa_ + 40, za_ + 40
            dcap = min(math.hypot(cs['x'] - xc, cs['z'] - zc) for cs in capsets.values()
                       if zones[cs['zone']]['faction'] == fac)
            info[n] = (bx + cx0, bz + cz0, major2[bz, bx], int(has_cap[bz, bx]),
                       int(mask_all[bz, bx]), int(round(dcap)))
        qdir = os.path.join(outdir, 'quota')
        os.makedirs(qdir, exist_ok=True)
        np.savez_compressed(os.path.join(qdir, '%s-%s.npz' % (seed, fac)), A=A, C=Ccnt, info=info,
                            kcells=kcells, kzone=np.array([k[0] for k in qkeys]),
                            kname=np.array([k[1] for k in qkeys]),
                            zone_names=np.array([zones[n]['name'] for n in sorted(zones)]),
                            zone_ids=np.array(sorted(zones)), claim_ids=np.array(claim_ids),
                            cap_ids=np.array(cap_ids))
        if want_picture:
            COLc = {'A': (120, 120, 120), 'B': (235, 190, 30), 'C': (230, 115, 25),
                    'D': (150, 70, 180), 'W': (215, 60, 60), 'E': (40, 160, 60),
                    '3': (20, 60, 170), '2': (50, 130, 220), '1': (130, 200, 245)}
            wex = {dd: window_any(wallch, dd) for dd in (1, 2, 3)}
            firstc = np.full((nbz, nbx), '', object)
            firstc[touched2] = 'W'
            firstc[touched2 & ~wex[1]] = '1'
            firstc[touched2 & ~wex[2]] = '2'
            firstc[touched2 & ~wex[3]] = '3'
            firstc[touched2 & ~wex[1] & oldlev['D3']] = 'E'
            firstc[touched2 & (fD3)] = 'D'
            firstc[touched2 & fC] = 'C'
            firstc[touched2 & fB[16]] = 'B'
            firstc[touched2 & ~passN] = 'A'
            r1 = CAP['dist']['1']['D3']
            cnt = {k: int((firstc == k).sum()) for k in COLc}
            items = [('E', 'eligible in the seven claim zones (A, B, C, D3)', cnt['E']),
                     ('3', 'added, eligible with 3 chunks to the city shape', cnt['3']),
                     ('2', 'added, eligible with 2 (not 3) chunks', cnt['2']),
                     ('1', 'added, eligible with 1 (not 2) chunk', cnt['1']),
                     ('W', 'passes A-D3 but within 1 chunk of the city shape', cnt['W']),
                     ('D', 'D3: camp, leader, place, rare point or largest quest region', cnt['D']),
                     ('C', 'C: a protected road crosses it', cnt['C']),
                     ('B', 'B: within 16 nodes of a settlement core or footprint', cnt['B']),
                     ('A', 'A: not wholly claim or capital-zone ground', cnt['A'])]
            labels = [(n, zones[n]['name']) for n in claim_ids + cap_ids]
            title = ('%s with its capital zones as claim ground (A, B, C, D3), seed %s (production): '
                     '%d claim-zone chunks + %d / %d / %d in the capital zones at 1 / 2 / 3 chunks from the city'
                     % (FNAME[fac], seed, int(oldlev['D3'].sum()), CAP['dist']['1']['D3']['added'],
                        CAP['dist']['2']['D3']['added'], CAP['dist']['3']['D3']['added']))
            extra = [('red', 'red: the capital\'s protected city shape (wall line, wall, 21-node band) and the '
                      'chunks that hold any of it')]
            draw_map(os.path.join(outdir, 'claimcap-%s-capitals.png' % fac), title, x0, z0, zid, wc, terr,
                     hgt, road, boxes, touched2, firstc, COLc, items, None, claim_ids + cap_ids, labels,
                     settlements, extra, 'Added chunks: not eligible under today\'s zones. ', wall_cols,
                     wallch, nbx, nbz)
        res['factions'][fac] = F

        if want_picture:
            draw(fac, seed, outdir, x0, z0, W, H, zid, wc, terr, hgt, road, boxes, touched, first,
                 levels['D3'], levels['D2'], claim_ids, zones, settlements, F, cx0, cz0, nbx, nbz)
    return res


def draw(fac, seed, outdir, x0, z0, W, H, zid, wc, terr, hgt, road, boxes, touched, first,
         d3ok, d2ok, claim_ids, zones, settlements, F, cx0, cz0, nbx, nbz):
    """The first picture: the seven claim zones, chunks by the first rule set
    that excludes them (A, B, C, D = D2), D3 hatched."""
    L = F['levels']
    COL = {'A': (120, 120, 120), 'B': (235, 190, 30), 'C': (230, 115, 25),
           'D': (150, 70, 180), 'E': (40, 160, 60)}
    items = [('E', 'eligible (passes A, B, C, D)', L['D2']),
             ('D', 'D: camp, leader, quest place or rare route point', L['C'] - L['D2']),
             ('C', 'C: a protected road crosses it', L['B'] - L['C']),
             ('B', 'B: within 16 nodes of a settlement core or footprint', L['A'] - L['B']),
             ('A', 'A: not wholly claim ground (zone border, coast, sea, deep water)', F['touched'] - L['A'])]
    hatch = (first == 'E') & ~d3ok
    labels = [(n, '%s  (%d of %d)' % (zones[n]['name'], F['zones'][zones[n]['name']]['D2'],
                                      F['zones'][zones[n]['name']]['touched'])) for n in claim_ids]
    title = ('%s: claim zones on the 80 x 80 chunk grid, seed %s (production). '
             'Eligible after all of A-D: %d of %d claim-zone chunks' % (FNAME[fac], seed, L['D2'], F['touched']))
    extra = [('hatch', 'hatched: eligible, but in the largest region of a quest-named mob kind (D3): %d'
              % (L['D2'] - L['D3']))]
    foot = 'Zone labels: eligible chunks of chunks touching the zone (by majority zone). '
    draw_map(os.path.join(outdir, 'claimcap-%s.png' % fac), title, x0, z0, zid, wc, terr, hgt, road,
             boxes, touched, first, COL, items, hatch, claim_ids, labels, settlements, extra, foot,
             None, None, nbx, nbz)


def draw_map(path, title, x0, z0, zid, wc, terr, hgt, road, boxes, touched, first, COL, items,
             hatch, ground_ids, labels, settlements, extra, foot, outline_cols, outline_chunks,
             nbx, nbz):
    from PIL import Image, ImageDraw, ImageFont
    S = 2  # nodes per pixel
    bz_idx, bx_idx = np.nonzero(touched)
    bxa, bxb = max(0, bx_idx.min() - 1), min(nbx, bx_idx.max() + 2)
    bza, bzb = max(0, bz_idx.min() - 1), min(nbz, bz_idx.max() + 2)
    xa, xb, za, zb = bxa * CH, bxb * CH, bza * CH, bzb * CH
    sl = (slice(za, zb, S), slice(xa, xb, S))
    Z = zid[sl]
    WC = wc[sl]
    T = terr[sl]
    h = hgt[za // 4:zb // 4, xa // 4:xb // 4].astype(float)
    h = np.where(h == -32768, np.nan, h)
    hn = np.nan_to_num(h, nan=np.nanmedian(h))
    gz, gx = np.gradient(hn)
    shade = np.clip(0.78 + 0.05 * (-gx - gz), 0.45, 1.0)
    shade = np.repeat(np.repeat(shade, 2, 0), 2, 1)[:Z.shape[0], :Z.shape[1]]
    img = np.zeros(Z.shape + (3,), float)
    img[:] = np.array([196, 190, 170], float)
    img *= shade[..., None]
    img[WC == 2] = [140, 182, 222]
    img[np.isin(WC, [3, 4, 5])] = [104, 142, 196]
    img[Z == 255] = [225, 225, 225]
    notclaim = ~np.isin(Z, ground_ids) & (Z != 255)
    img[notclaim] = img[notclaim] * 0.55 + 255 * 0.45
    alpha = 0.5
    ch = CH // S
    for bz in range(bza, bzb):
        for bx in range(bxa, bxb):
            k = first[bz, bx]
            if not k:
                continue
            ra, ca = (bz - bza) * ch, (bx - bxa) * ch
            img[ra:ra + ch, ca:ca + ch] = img[ra:ra + ch, ca:ca + ch] * (1 - alpha) + \
                np.array(COL[k], float) * alpha
    R = road[za:zb, xa:xb]
    R = R.reshape(R.shape[0] // S, S, R.shape[1] // S, S).any(axis=(1, 3))
    img[R] = [70, 45, 25]
    img[np.isin(T, [4, 7])] = [30, 30, 30]
    edge = np.zeros(Z.shape, bool)
    edge[:, 1:] |= (Z[:, 1:] != Z[:, :-1])
    edge[1:, :] |= (Z[1:, :] != Z[:-1, :])
    edge &= (Z != 255)
    img[edge] = [20, 20, 20]
    if outline_cols is not None:
        O = outline_cols[za:zb, xa:xb]
        O = O.reshape(O.shape[0] // S, S, O.shape[1] // S, S).any(axis=(1, 3))
        oe = np.zeros(O.shape, bool)
        oe[:, 1:] |= O[:, 1:] != O[:, :-1]
        oe[1:, :] |= O[1:, :] != O[:-1, :]
        oe = window_any(oe, 1)
        img[oe] = [220, 20, 20]
    img = np.flipud(img)  # +z is north: up
    pic = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    Hp, Wp = pic.size[1], pic.size[0]
    top = 60
    bottom = 60 + 34 * ((len(items) + 2) // 3 + len(extra)) + 40
    canvas = Image.new('RGB', (max(Wp + 40, 1900), Hp + top + bottom), (250, 250, 248))
    canvas.paste(pic, (20, top))
    d = ImageDraw.Draw(canvas)
    f_title = ImageFont.truetype(FONT_B, 26)
    f_lab = ImageFont.truetype(FONT_B, 20)
    f_small = ImageFont.truetype(FONT, 16)
    f_leg = ImageFont.truetype(FONT, 19)

    def to_px(x, z):
        return 20 + (x - (x0 + xa)) / S, top + Hp - (z - (z0 + za)) / S

    def hatch_box(X0, Y0, w, hgt_, fill):
        for t in range(0, w + hgt_, 8):
            d.line([(X0 + max(0, t - hgt_), Y0 + min(t, hgt_)), (X0 + min(t, w), Y0 + max(0, t - w))],
                   fill=fill, width=1)

    for bz in range(bza, bzb):
        for bx in range(bxa, bxb):
            if not first[bz, bx]:
                continue
            X0, Y1 = to_px(x0 + bx * CH, z0 + bz * CH)
            X1, Y0 = to_px(x0 + (bx + 1) * CH, z0 + (bz + 1) * CH)
            d.rectangle([X0, Y0, X1, Y1], outline=(255, 255, 255))
            if hatch is not None and hatch[bz, bx]:
                hatch_box(X0, Y0, ch, ch, (20, 90, 30))
    if outline_chunks is not None:
        for bz, bx in zip(*np.nonzero(outline_chunks)):
            if bza <= bz < bzb and bxa <= bx < bxb:
                X0, Y1 = to_px(x0 + bx * CH, z0 + bz * CH)
                X1, Y0 = to_px(x0 + (bx + 1) * CH, z0 + (bz + 1) * CH)
                d.rectangle([X0, Y0, X1, Y1], outline=(200, 0, 0), width=2)
    for b in boxes:
        a = to_px(int(b[2]), int(b[5]) + 1)
        c = to_px(int(b[3]) + 1, int(b[4]))
        if 20 <= a[0] <= Wp + 20 and top <= a[1] <= top + Hp:
            d.rectangle([a[0], a[1], c[0], c[1]], outline=(0, 0, 0), width=2)

    def halo(xy, text, font, fill=(0, 0, 0)):
        x, y = xy
        for dx in (-2, -1, 0, 1, 2):
            for dy in (-2, -1, 0, 1, 2):
                d.text((x + dx, y + dy), text, font=font, fill=(255, 255, 255), anchor='mm')
        d.text((x, y), text, font=font, fill=fill, anchor='mm')

    taken = []
    for s_ in settlements:
        if s_['slot'] in ('capital', 'start') or s_['slot'].startswith('village_'):
            p = to_px(s_['x'], s_['z'])
            if 20 <= p[0] <= Wp + 20 and top <= p[1] <= top + Hp:
                halo((p[0], p[1] - 16), s_['label'], f_small, fill=(60, 0, 0))
                taken.append((p[0], p[1] - 16))
    full = zid[za:zb:8, xa:xb:8]
    for n, text in labels:
        rr, cc = np.nonzero(full == n)
        if len(rr) == 0:
            continue
        x = x0 + xa + 8 * cc.mean()
        z = z0 + za + 8 * rr.mean()
        px, py = to_px(x, z)
        best = max(((px, py + dy) for dy in (0, -36, 36, -72, 72)),
                   key=lambda q: min([abs(q[1] - t[1]) * 6 + abs(q[0] - t[0]) for t in taken] or [1e9]) +
                   (0 if q[1] == py else -40))
        halo(best, text, f_lab, fill=(10, 30, 110))
    d.text((20, 18), title, font=f_title, fill=(0, 0, 0))
    y = top + Hp + 18
    x = 20
    for i, (k, text, n) in enumerate(items):
        xx = x + (i % 3) * 620
        yy = y + (i // 3) * 34
        d.rectangle([xx, yy, xx + 26, yy + 22], fill=tuple(int(v * 0.5 + 200 * 0.5) for v in COL[k]),
                    outline=(0, 0, 0))
        d.text((xx + 36, yy + 1), '%s: %d' % (text, n), font=f_leg, fill=(0, 0, 0))
    yy = y + ((len(items) + 2) // 3) * 34
    for kind, text in extra:
        if kind == 'hatch':
            d.rectangle([x, yy, x + 26, yy + 22], fill=(150, 205, 155), outline=(0, 0, 0))
            hatch_box(x, yy, 26, 22, (20, 90, 30))
        elif kind == 'red':
            d.rectangle([x, yy, x + 26, yy + 22], outline=(200, 0, 0), width=3)
        d.text((x + 36, yy + 1), text, font=f_leg, fill=(0, 0, 0))
        yy += 34
    d.text((x, yy), 'Dark brown: roads; black boxes: settlement cores; black fill: towns, landmarks; '
           'pale: not claim ground; light grey: not computed.', font=f_leg, fill=(60, 60, 60))
    d.text((x, yy + 30), foot + 'North is up; 1 pixel = 2 nodes; chunk = 80 x 80 nodes.', font=f_leg,
           fill=(60, 60, 60))
    canvas.save(path, optimize=True)
    print('wrote', path, canvas.size)


def mmm(vals):
    vals = [v for v in vals if v is not None]
    if not vals:
        return '-'
    med = statistics.median(vals)
    fmt = (lambda v: '%d' % v) if all(float(v).is_integer() for v in vals) else (lambda v: '%.0f' % v)
    return '%s / %s / %s' % (fmt(min(vals)), fmt(med) if float(med).is_integer() else '%.1f' % med, fmt(max(vals)))


def tables(results, out):
    prod, others = results[0], results[1:]
    L = []
    w = L.append
    w('# CLAIMCAP tables (generated by tools/r85_claimcap/analyze.py)\n')
    w('Production seed %s first; the other %d seeds as min / median / max.\n' % (prod['seed'], len(others)))
    # Table 1
    w('\n## T1 Chunk columns eligible per rule set (whole faction)\n')
    w('| Rule set | Accord prod | Accord others | Throng prod | Throng others |')
    w('|---|---:|---:|---:|---:|')
    rows = [('claim-zone chunks touched', lambda F: F['touched'])] + \
        [(k, (lambda k: lambda F: F['levels'][k])(k)) for k in LEVELS]
    for name, fn in rows:
        cells = []
        for fac in FACTIONS:
            cells.append(str(fn(prod['factions'][fac])))
            cells.append(mmm([fn(r['factions'][fac]) for r in others]))
        w('| %s | %s |' % (name, ' | '.join(cells)))
    # Table 1b per zone
    for fac in FACTIONS:
        w('\n## T1-%s Per zone (chunk assigned to its majority claim zone)\n' % fac)
        w('| Zone | touched | A | B | C | D1 | D2 | D3 | D3d | D4 | D2 others | squares (B, greedy) |')
        w('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
        for zn, e in prod['factions'][fac]['zones'].items():
            oth = mmm([r['factions'][fac]['zones'].get(zn, {}).get('D2') for r in others])
            sqz = prod['factions'][fac]['squares']['B']['greedy_zones'].get(zn, 0)
            w('| %s | %d | %s | %s | %s |' % (zn, e['touched'], ' | '.join(str(e[k]) for k in LEVELS), oth, sqz))
    # Table 2
    w('\n## T2 Today\'s 101 x 101 claims under today\'s rules (A + B; roads allowed)\n')
    w('| Measure | Accord prod | Accord others | Throng prod | Throng others |')
    w('|---|---:|---:|---:|---:|')
    rows = [('eligible columns (A and B)', lambda F: F['area_B_columns']),
            ('upper estimate: columns / 10201', lambda F: round(F['upper_squares_B'])),
            ('valid centres', lambda F: F['squares']['B']['valid_centres']),
            ('greedy packing (row-major first fit)', lambda F: F['squares']['B']['greedy']),
            ('best 101-lattice packing', lambda F: F['squares']['B']['lattice']),
            ('free placement, random order (estimate, mean of 3)', lambda F: round(F['squares']['B']['random'])),
            ('greedy packing, no road in the square', lambda F: F['squares']['C']['greedy']),
            ('chunks: rule B (same rules, chunk grid)', lambda F: F['levels']['B']),
            ('chunks: rule C', lambda F: F['levels']['C']),
            ('chunks: rule D2', lambda F: F['levels']['D2']),
            ('upper estimate for chunks: columns / 6400', lambda F: round(F['upper_chunks_B'])),
            ('validate probes: accepted / agreeing / disagreeing',
             lambda F: '%d / %d / %d' % (F['validate']['accepted'], F['validate']['agree'], F['validate']['disagree']))]
    for name, fn in rows:
        cells = []
        for fac in FACTIONS:
            cells.append(str(fn(prod['factions'][fac])))
            vals = [fn(r['factions'][fac]) for r in others]
            cells.append(mmm(vals) if not vals or not isinstance(vals[0], str) else
                         ('agree %d of %d' % (sum(r['factions'][fac]['validate']['agree'] for r in others),
                                              sum(r['factions'][fac]['validate']['agree'] +
                                                  r['factions'][fac]['validate']['disagree'] for r in others))))
        w('| %s | %s |' % (name, ' | '.join(cells)))
    # Table 3
    w('\n## T3 Building ground of the eligible chunks\n')
    w('| Level | Measure | Accord prod | Accord others | Throng prod | Throng others |')
    w('|---|---|---:|---:|---:|---:|')
    for lev in ('C', 'D2', 'D3'):
        for name, key in (('chunks', 'n'), ('mostly water (> 50 %)', 'mostly_water'),
                          ('water > 25 %', 'any_water_quarter'),
                          ('land height span, median', 'span_median'), ('span, 90th pct', 'span_p90'),
                          ('span > 20 nodes', 'span_gt20'), ('span > 40 nodes', 'span_gt40')):
            cells = []
            for fac in FACTIONS:
                v = prod['factions'][fac]['usable'][lev][key]
                cells.append('-' if v is None else ('%.0f' % v if isinstance(v, float) else str(v)))
                cells.append(mmm([r['factions'][fac]['usable'][lev][key] for r in others]))
            w('| %s | %s | %s |' % (lev, name, ' | '.join(cells)))
    # Table 4
    w('\n## T4 Spread and distances (chunk centre to the nearest own capital, waystone, town; nodes)\n')
    w('| Level | Measure | Accord prod | Accord others | Throng prod | Throng others |')
    w('|---|---|---:|---:|---:|---:|')
    for lev in ('C', 'D2', 'D3'):
        rows = [('zones with an eligible chunk (of 7)', lambda s: s['zones_with_any']),
                ('fewest / most in one zone', None),
                ('share of the busiest zone', lambda s: s['top_zone_share'] and round(100 * s['top_zone_share'])),
                ('capital: median', lambda s: s.get('capital', {}).get('median')),
                ('capital: max', lambda s: s.get('capital', {}).get('max')),
                ('waystone: median', lambda s: s.get('waystone', {}).get('median')),
                ('waystone: max', lambda s: s.get('waystone', {}).get('max')),
                ('town or village: median', lambda s: s.get('town', {}).get('median')),
                ('town or village: max', lambda s: s.get('town', {}).get('max'))]
        for name, fn in rows:
            cells = []
            for fac in FACTIONS:
                s = prod['factions'][fac]['spread'][lev]
                if fn is None:
                    cells.append('%d / %d' % (s['min_zone'], s['max_zone']))
                    cells.append(mmm([r['factions'][fac]['spread'][lev]['min_zone'] for r in others]) + ' (min)')
                    continue
                v = fn(s)
                cells.append('-' if v is None else '%.0f' % v)
                cells.append(mmm([fn(r['factions'][fac]['spread'][lev]) for r in others]))
            w('| %s | %s | %s |' % (lev, name, ' | '.join(cells)))
    # Table 5
    w('\n## T5 What the exact one-chunk rule loses, and the levers\n')
    w('| Measure | Accord prod | Accord others | Throng prod | Throng others |')
    w('|---|---:|---:|---:|---:|')
    rows = []
    for t in ('<=1%', '<=5%', '<=10%', '<=25%'):
        rows.append(('fail A by %s of the columns' % t, (lambda t: lambda F: F['slivers'][t]['fail_A'])(t)))
        rows.append(('... of which pass B, C, D2', (lambda t: lambda F: F['slivers'][t]['then_pass_B_C_D2'])(t)))
    rows += [('B with margin 16 (today)', lambda F: F['margin']['B16']),
             ('B with margin 8', lambda F: F['margin']['B8']),
             ('B with margin 0 (core itself only)', lambda F: F['margin']['B0']),
             ('D2 with margin 8', lambda F: F['margin']['D2_with_B8']),
             ('D2 with margin 0', lambda F: F['margin']['D2_with_B0'])]
    for var in ('touch_31_40', 'open_31_40'):
        for lev in ('A', 'B', 'C', 'D2'):
            rows.append(('%s: %s' % (var, lev), (lambda var, lev: lambda F: F['variants'][var][lev])(var, lev)))
    for name, fn in rows:
        cells = []
        for fac in FACTIONS:
            cells.append(str(fn(prod['factions'][fac])))
            cells.append(mmm([fn(r['factions'][fac]) for r in others]))
        w('| %s | %s |' % (name, ' | '.join(cells)))
    w('\nMain reason of the chunks that fail A (production, chunks by the most frequent problem of their '
      'forbidden columns):\n')
    for fac in FACTIONS:
        w('- %s: %s' % (FNAME[fac], ', '.join('%s %d' % kv for kv in sorted(
            prod['factions'][fac]['slivers']['fail_A_main_reason'].items(), key=lambda kv: -kv[1]))))
    w('\nForbidden columns in the chunks that fail A by at most 10 % (production):\n')
    for fac in FACTIONS:
        w('- %s: %s' % (FNAME[fac], ', '.join('%s %d' % kv for kv in sorted(
            prod['factions'][fac]['slivers']['reasons_columns_<=10%'].items(), key=lambda kv: -kv[1]))))
    w('\nCross-checks: chunk feature test (margins 16, 8, 0) against the exact feature_in on every '
      'claim-zone chunk, mismatching chunks: %s.' % (', '.join(
        '%s seed %s: %d' % (fac, r['seed'], r['factions'][fac]['feature_mismatch'])
        for r in results for fac in FACTIONS if r['factions'][fac]['feature_mismatch']) or
        'none on any seed'))
    w('Probe centres checked with grug_housing validate: %d, disagreeing with the raster: %d.' % (
        sum(r['factions'][f]['validate']['agree'] + r['factions'][f]['validate']['disagree']
            for r in results for f in FACTIONS),
        sum(r['factions'][f]['validate']['disagree'] for r in results for f in FACTIONS)))
    with open(out, 'w') as f:
        f.write('\n'.join(L) + '\n')


def tables_capitals(results, out):
    """The follow-up's tables (capital zones as claim ground, D3's weak points)."""
    prod, others = results[0], results[1:]
    L = []
    w = L.append

    def row(name, fn):
        cells = []
        for fac in FACTIONS:
            v = fn(prod['factions'][fac])
            cells.append('-' if v is None else ('%.0f' % v if isinstance(v, float) else str(v)))
            cells.append(mmm([fn(r['factions'][fac]) for r in others]))
        w('| %s | %s |' % (name, ' | '.join(cells)))

    head = '| Measure | Accord prod | Accord others | Throng prod | Throng others |\n|---|---:|---:|---:|---:|'
    w('# CLAIMCAP follow-up tables: capital zones (generated by tools/r85_claimcap/analyze.py)\n')
    w('Production seed %s first; the other %d seeds as min / median / max.\n' % (prod['seed'], len(others)))
    w('\n## F1 Totals with the capital zones as claim ground\n')
    w(head)
    row('chunks holding the capital city shape (wall chunks)', lambda F: F['capitals']['wall_chunks'])
    row('capital-zone land chunks touched', lambda F: F['capitals']['capital_land_chunks'])
    for lev in ('D3', 'D2'):
        row('seven claim zones today, %s' % lev, (lambda lev: lambda F: F['levels'][lev])(lev))
        for dd in ('1', '2', '3'):
            row('%s, %s chunk(s) from the city: added' % (lev, dd),
                (lambda lev, dd: lambda F: F['capitals']['dist'][dd][lev]['added'])(lev, dd))
            row('%s, %s chunk(s): new total, distance rule only in capital zones' % (lev, dd),
                (lambda lev, dd: lambda F: F['levels'][lev] + F['capitals']['dist'][dd][lev]['added'])(lev, dd))
            row('%s, %s chunk(s): new total, distance rule everywhere' % (lev, dd),
                (lambda lev, dd: lambda F: F['capitals']['dist'][dd][lev]['total'])(lev, dd))
            row('%s, %s chunk(s): claim-zone chunks the rule everywhere removes' % (lev, dd),
                (lambda lev, dd: lambda F: F['capitals']['dist'][dd][lev]['old_lost'])(lev, dd))
    row('D3, 0 chunks (only B\'s 16 nodes): added', lambda F: F['capitals']['dist']['0']['D3']['added'])
    for fac in FACTIONS:
        w('\n## F1-%s Per zone, production (majority zone; D3 at 1 / 2 / 3 chunks, D2 at 2; the distance '
          'rule applied to chunks with capital-zone ground)\n' % fac)
        w('| Zone | D3 d1 | D3 d2 | D3 d3 | D2 d2 | D3 d2 others |')
        w('|---|---:|---:|---:|---:|---:|')
        P = prod['factions'][fac]['capitals']['dist']
        for zn in P['1']['zones']:
            oth = mmm([r['factions'][fac]['capitals']['dist']['2']['zones'].get(zn, {}).get('D3') for r in others])
            w('| %s | %d | %d | %d | %d | %s |' % (zn, P['1']['zones'][zn]['D3'], P['2']['zones'][zn]['D3'],
                                                   P['3']['zones'][zn]['D3'], P['2']['zones'][zn]['D2'], oth))
    w('\n## F2 What D removes among the added chunks that pass A, B, C (1 chunk from the city)\n')
    w(head)
    for key, name in (('C', 'added chunks passing A, B, C'), ('camp_leader_place', 'D1: camp, leader or place'),
                      ('rare', 'D2: rare route point (after D1)'),
                      ('quest_largest', 'D3: largest quest-kind region (after D2)'),
                      ('quest_half', 'D3h: half of each quest kind (after D2)'),
                      ('quest_any', 'D4: any quest-kind region (after D2)')):
        row(name, (lambda key: lambda F: F['capitals']['dist']['1']['d_removes_in_added'][key])(key))
    w('\n## F3 The capital zones\' spawn content (production; 32-node land cells)\n')
    w('| Zone | cells | camp | quest-kind | largest quest regions | half rule | quest kinds | leaders | places |')
    w('|---|---:|---:|---:|---:|---:|---|---|---|')
    for fac in FACTIONS:
        for zn, c in prod['factions'][fac]['capitals']['capital_zone_content'].items():
            w('| %s | %d | %d | %d | %d | %d | %s | %s | %s |' % (
                zn, c['cells'], c['camp_cells'], c['quest_cells'], c['quest_largest_cells'],
                c['quest_half_cells'], ', '.join(c['quest_kinds']), ', '.join(c['leaders']) or '-',
                ', '.join(c['places']) or '-'))
    w('\n## F4 Building ground of the added D3 chunks, and the distance to the capital (anchor, nodes)\n')
    w(head)
    for dd in ('1', '2', '3'):
        for key, name in (('n', 'chunks'), ('mostly_water', 'mostly water'), ('water_gt25', 'water > 25 %'),
                          ('span_median', 'height span median'), ('span_gt20', 'span > 20'),
                          ('span_gt40', 'span > 40'), ('cap_min', 'to the capital: min'),
                          ('cap_median', 'to the capital: median'), ('cap_max', 'to the capital: max')):
            row('d%s: %s' % (dd, name), (lambda dd, key: lambda F: F['capitals']['dist'][dd]['usable_added_D3'][key])(dd, key))
    for key, name in (('n', 'chunks'), ('mostly_water', 'mostly water'), ('span_median', 'height span median'),
                      ('span_gt20', 'span > 20'), ('span_gt40', 'span > 40')):
        row('seven claim zones, D3: %s' % name, (lambda key: lambda F: F['usable']['D3'][key])(key))
    w('\n## F5 D3\'s weak points (claim zones only)\n')
    w(head)
    for key, name in (('quest_kinds', 'quest-named kinds'), ('kinds_one_region', '... with one region'),
                      ('kinds_near_tie', '... second region >= 80 % of the largest'),
                      ('largest_share_median_pct', 'largest region\'s share of its kind, median %'),
                      ('largest_share_lt_half', 'kinds whose largest region holds < half'),
                      ('largest_region_cells_max', 'largest region, cells (max)'),
                      ('d3_removed_chunks', 'chunks D3 removes beyond D2'),
                      ('d3_removed_near_tie', '... of which touch a near-tie kind\'s largest region')):
        row(name, (lambda key: lambda F: (round(F['d3_stats'][key], 2) if isinstance(F['d3_stats'][key], float)
                                          else F['d3_stats'][key]))(key))
    row('claim zones today: D2', lambda F: F['levels']['D2'])
    row('claim zones today: D3', lambda F: F['levels']['D3'])
    row('claim zones today: D3h (half of each quest kind)', lambda F: F['capitals']['old_D3h'])
    row('claim zones today: D4 (every quest-kind region)', lambda F: F['levels']['D4'])
    with open(out, 'w') as f:
        f.write('\n'.join(L) + '\n')


def main():
    outdir, seeds = sys.argv[1], sys.argv[2:]
    results = []
    for i, seed in enumerate(seeds):
        cache = os.path.join(outdir, 'results-%s.json' % seed)
        run = os.path.join(outdir, 'runs', seed)
        if i > 0 and os.path.exists(cache) and os.path.getmtime(cache) > os.path.getmtime(
                os.path.join(run, 'meta.tsv')):
            with open(cache) as f:
                results.append(json.load(f))
            continue
        r = analyse(run, seed, want_picture=(i == 0), outdir=outdir)
        with open(cache, 'w') as f:
            json.dump(r, f, indent=1, default=lambda o: o.item() if hasattr(o, 'item') else str(o))
        results.append(json.loads(json.dumps(r, default=lambda o: o.item() if hasattr(o, 'item') else str(o))))
        print('analysed', seed)
    tables(results, os.path.join(outdir, 'tables.md'))
    tables_capitals(results, os.path.join(outdir, 'capitals.md'))
    print('wrote', os.path.join(outdir, 'tables.md'))


if __name__ == '__main__':
    main()
