#!/usr/bin/env python3
"""Round 85 MASK: the game's claim mask (tools/r85_mask/run.lua) against the
capacity study's decided mask and quota ground (tools/r85_claimcap,
analyze.py's quota/<seed>-<faction>.npz).

  python3 tools/r85_mask/compare.py <run outdir> <study outdir> <seed>

Prints per faction: the mask chunks of both and their differences, every
quest kind whose ground differs, and every mask chunk whose columns per kind
differ. Exit 1 when a chunk set differs.
"""
import os
import sys

import numpy as np


def tsv(path):
    with open(path) as f:
        return [line.rstrip('\n').split('\t') for line in f if line.strip()]


def main():
    run, study, seed = sys.argv[1], sys.argv[2], sys.argv[3]
    ours = {}
    for fac, cx, cz in tsv(os.path.join(run, 'mask.tsv')):
        ours.setdefault(fac, set()).add((int(cx), int(cz)))
    kinds = {k: (int(c), int(g)) for k, c, g, _ in tsv(os.path.join(run, 'kinds.tsv'))}
    cols = {}
    for fac, cx, cz, kid, n in tsv(os.path.join(run, 'columns.tsv')):
        cols.setdefault((fac, int(cx), int(cz)), {})[kid] = int(n)
    bad = 0
    for fac in ('accord', 'throng'):
        d = np.load(os.path.join(study, 'quota', '%s-%s.npz' % (seed, fac)))
        info, A, kcells = d['info'], d['A'], d['kcells']
        names = dict(zip(d['zone_ids'].tolist(), d['zone_names'].tolist()))
        del names
        # the study's kind keys are (zone numeric id, kind id); ours "<zone id>/<kind>"
        kzone, kname = d['kzone'].tolist(), d['kname'].tolist()
        theirs = {(int(r[0]), int(r[1])) for r in info}
        mine = ours.get(fac, set())
        only_s, only_o = sorted(theirs - mine), sorted(mine - theirs)
        print('%s: study %d, game %d, only in the study %d %s, only in the game %d %s' % (
            fac, len(theirs), len(mine), len(only_s), only_s[:10], len(only_o), only_o[:10]))
        if only_s or only_o:
            bad = 1
        # kinds: match by kind name and cell count
        by_name = {}
        for k, (c, g) in kinds.items():
            by_name.setdefault(k.split('/', 1)[1], []).append((k, c))
        kmap = {}
        for q, (z, n) in enumerate(zip(kzone, kname)):
            cands = [k for k, c in by_name.get(n, []) if c == int(kcells[q])]
            if len(cands) == 1:
                kmap[q] = cands[0]
            else:
                print('  kind %s/%s (%d cells): game candidates %s' % (z, n, kcells[q], by_name.get(n)))
        diff_chunks = 0
        for row, a in zip(info, A):
            key = (fac, int(row[0]), int(row[1]))
            if key[1:] not in mine:
                continue
            want = {kmap[q]: int(v) for q, v in enumerate(a) if v and q in kmap}
            have = cols.get(key, {})
            have = {k: v for k, v in have.items() if k in kmap.values()}
            if want != have:
                diff_chunks += 1
                if diff_chunks <= 5:
                    print('  columns differ at %s: study %s game %s' % (key[1:], want, have))
        print('  quest kinds %d (study %d), mask chunks whose columns differ: %d' % (
            sum(1 for k in kinds if k in kmap.values()), len(kcells), diff_chunks))
    return bad


if __name__ == '__main__':
    sys.exit(main())
