import sys, numpy as np
import os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from model import *
from collections import Counter

STEP = 10
# biomes.csv sits next to this script (see diagnose.py), not in the CWD.
B = load_biomes(os.path.join(HERE, "biomes.csv"))
NAMES = [b["name"] for b in B]
TOPS = [b["node_top"] for b in B]


def flood(mask_grid, labels):
    """Largest 4-connected region of equal `labels` inside mask_grid.
    Returns (size_cells, label, (xmin,xmax,zmin,zmax) index bbox)."""
    H, W = labels.shape
    seen = np.zeros((H, W), bool)
    best = (0, None, None)
    for z0 in range(H):
        for x0 in range(W):
            if seen[z0, x0] or not mask_grid[z0, x0]:
                continue
            lab = labels[z0, x0]
            stack = [(z0, x0)]
            seen[z0, x0] = True
            n = 0
            zmin = zmax = z0
            xmin = xmax = x0
            while stack:
                z, x = stack.pop()
                n += 1
                if z < zmin: zmin = z
                if z > zmax: zmax = z
                if x < xmin: xmin = x
                if x > xmax: xmax = x
                for dz, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nz, nx = z + dz, x + dx
                    if 0 <= nz < H and 0 <= nx < W and not seen[nz, nx] \
                            and mask_grid[nz, nx] and labels[nz, nx] == lab:
                        seen[nz, nx] = True
                        stack.append((nz, nx))
            if n > best[0]:
                best = (n, lab, (xmin, xmax, zmin, zmax))
    return best


def band_of(X):
    b = np.full(X.shape, "centre", dtype=object)
    b = np.where(X < -275, "west", b)
    b = np.where(X > 275, "east", b)
    return b


for zsign, cont in ((1, "THRONG / Kragmar (z>0)"), (-1, "ACCORD / Elandor (z<0)")):
    d = build(STEP, zsign, B)
    L = d["land"]
    bid, X, Z = d["bid"], d["X"], d["Z"]
    tot = L.sum()
    print("=" * 78)
    print(cont, " land columns %d (%.1f%% of the rectangle)" % (tot, 100 * tot / L.size))
    print("  heat  mean %6.2f sigma %5.2f  min %6.1f max %6.1f" %
          (d["heat"].mean(), d["heat"].std(), d["heat"].min(), d["heat"].max()))
    print("  humid mean %6.2f sigma %5.2f  min %6.1f max %6.1f" %
          (d["hum"].mean(), d["hum"].std(), d["hum"].min(), d["hum"].max()))

    print("\n-- share per REGISTRATION (of land) --")
    ids, cnt = np.unique(bid[L], return_counts=True)
    for i, c in sorted(zip(ids, cnt), key=lambda t: -t[1]):
        print("   %-24s %6.2f%%" % (NAMES[i], 100 * c / tot))
    reach = set(int(i) for i in ids)
    print("   reachable registrations here: %d" % len(reach))

    print("\n-- share per VISIBLE node_top (of land) --")
    vis = Counter()
    for i, c in zip(ids, cnt):
        vis[TOPS[i]] += c
    for t, c in vis.most_common():
        print("   %-40s %6.2f%%" % (t, 100 * c / tot))

    print("\n-- share per race BAND (column % within the band) --")
    bands = band_of(X)
    for bn in ("west", "centre", "east"):
        m = L & (bands == bn)
        ids2, cnt2 = np.unique(bid[m], return_counts=True)
        s = ", ".join("%s %.1f%%" % (NAMES[i], 100 * c / m.sum())
                      for i, c in sorted(zip(ids2, cnt2), key=lambda t: -t[1])[:6])
        print("   %-7s (%5d cols): %s" % (bn, m.sum(), s))

    print("\n-- share per RING --")
    ring = zone_at(X, Z, d["eff"])
    for rn in ("war_coast", "core", "inner", "outer", "coast"):
        m = L & (ring == rn)
        if not m.sum():
            continue
        ids2, cnt2 = np.unique(bid[m], return_counts=True)
        s = ", ".join("%s %.1f%%" % (NAMES[i], 100 * c / m.sum())
                      for i, c in sorted(zip(ids2, cnt2), key=lambda t: -t[1])[:6])
        print("   %-10s (%5d cols): %s" % (rn, m.sum(), s))

    print("\n-- x-strip breakdown (which registration wins each overlap) --")
    strips = [(-1500, -1251, "bone only"), (-1250, -801, "bone|blight"),
              (-800, -350, "blight only"), (-349, -201, "blight|centre"),
              (-200, 200, "centre only"), (201, 349, "centre|east"),
              (350, 800, "east only"), (801, 1150, "east|wild"),
              (1151, 1250, "east|wild(+fringe)"), (1251, 1500, "wild only")]
    for xa, xb, lbl in strips:
        m = L & (X >= xa) & (X <= xb)
        if not m.sum():
            continue
        ids2, cnt2 = np.unique(bid[m], return_counts=True)
        s = ", ".join("%s %.0f%%" % (NAMES[i], 100 * c / m.sum())
                      for i, c in sorted(zip(ids2, cnt2), key=lambda t: -t[1])[:4])
        print("   x %5d..%5d %-20s land %5d: %s" % (xa, xb, lbl, m.sum(), s))

    print("\n-- largest contiguous region --")
    n, lab, bb = flood(L, bid)
    xa = d["xs"][bb[0]]; xb = d["xs"][bb[1]]
    za = d["zs"][bb[2]]; zb = d["zs"][bb[3]]
    print("   by REGISTRATION: %-22s %d cells = %.2f Mnode^2 (%.1f%% of land), bbox x %d..%d z %d..%d"
          % (NAMES[lab], n, n * STEP * STEP / 1e6, 100 * n / tot, xa, xb, min(za, zb), max(za, zb)))
    topid = np.array([TOPS.index(t) if t else -1 for t in TOPS])
    vlab = np.where(bid >= 0, topid[np.clip(bid, 0, None)], -1)
    n2, lab2, bb2 = flood(L, vlab)
    xa = d["xs"][bb2[0]]; xb = d["xs"][bb2[1]]
    za = d["zs"][bb2[2]]; zb = d["zs"][bb2[3]]
    print("   by VISIBLE TOP:  %-22s %d cells = %.2f Mnode^2 (%.1f%% of land), bbox x %d..%d z %d..%d"
          % (TOPS[lab2], n2, n2 * STEP * STEP / 1e6, 100 * n2 / tot, xa, xb, min(za, zb), max(za, zb)))
    print()
