import sys, numpy as np
sys.path.insert(0, "/tmp/claude-1000/-home-jan-projects-grudgelands/91ecbd76-d170-44c2-bdbc-709677e54187/scratchpad")
from model import *

B = load_biomes("biomes.csv")
NAMES = [b["name"] for b in B]
TOPS = [b["node_top"] for b in B]
UNIVERSAL = {"grug_swamp", "grug_beach", "grug_ocean", "grug_underground"}

for zsign, cont in ((1, "THRONG"), (-1, "ACCORD")):
    d = build(10, zsign, B)
    L, X, Z, h = d["land"], d["X"], d["Z"], d["h"]
    hm, hu = d["heat"].mean(), d["hum"].mean()
    hs, hus = d["heat"].std(), d["hum"].std()
    print("=" * 76)
    print("%s  field mean %.1f/%.1f  sigma %.1f/%.1f" % (cont, hm, hu, hs, hus))
    print("  climate point distance from THIS seed's field mean:")
    rows = []
    for i, b in enumerate(B):
        elig = ((h >= b["y_min"]) & (h <= b["y_max"]) & (X >= b["x_min"]) &
                (X <= b["x_max"]) & (Z >= b["z_min"]) & (Z <= b["z_max"]))
        if not (elig & L).any():
            continue
        dh, du = b["heat"] - hm, b["humidity"] - hu
        rows.append((math.hypot(dh, du), b["name"], b["heat"], b["humidity"],
                     dh / hs, du / hus))
    for dist, nm, ht, hu_, sh, su in sorted(rows):
        print("    %-24s %3d/%-3d  dist %5.1f   (%+.2f sigma heat, %+.2f sigma hum)"
              % (nm, ht, hu_, dist, sh, su))

    # eligible-registration / eligible-VISUAL count per land column
    nreg = np.zeros(X.shape, np.int32)
    tops_per_col = [[] for _ in range(X.size)]
    Xf = X.ravel(); Zf = Z.ravel(); hf = h.ravel()
    for i, b in enumerate(B):
        if b["name"] in UNIVERSAL:
            continue
        e = ((hf >= b["y_min"]) & (hf <= b["y_max"]) & (Xf >= b["x_min"]) &
             (Xf <= b["x_max"]) & (Zf >= b["z_min"]) & (Zf <= b["z_max"]))
        nreg += e.reshape(X.shape).astype(np.int32)
        for j in np.nonzero(e)[0]:
            tops_per_col[j].append(TOPS[i])
    nvis = np.array([len(set(t)) for t in tops_per_col]).reshape(X.shape)
    Lm = L
    tot = Lm.sum()
    print("\n  land columns by number of eligible LAND registrations:")
    for k in range(0, 5):
        c = (Lm & (nreg == k)).sum()
        if c:
            print("    %d registration(s): %6.2f%%" % (k, 100 * c / tot))
    print("  land columns by number of eligible distinct node_top VISUALS:")
    for k in range(0, 5):
        c = (Lm & (nvis == k)).sum()
        if c:
            print("    %d visual(s): %6.2f%%" % (k, 100 * c / tot))

    # how big is the region where the only eligible visual is rainforest litter?
    rain = np.array([set(t) == {"default:dirt_with_rainforest_litter"}
                     for t in tops_per_col]).reshape(X.shape)
    print("  land where the ONLY eligible land visual is rainforest litter: %.2f%%"
          % (100 * (Lm & rain).sum() / tot))
    forest = np.array([set(t) == {"grug_nodes:dirt_with_forest_litter"}
                       for t in tops_per_col]).reshape(X.shape)
    print("  land where the ONLY eligible land visual is forest litter:     %.2f%%"
          % (100 * (Lm & forest).sum() / tot))
    print()
