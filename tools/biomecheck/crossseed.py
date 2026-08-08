import os, sys, numpy as np, random
# The tool lives next to its own modules and next to the biomes.csv that
# dump_biomes.lua writes; both used to be absolute paths into the scratchpad of
# the session that built the tool, which died with it (WP36 fix).
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model
from model import load_biomes, build

B = load_biomes(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "biomes.csv"))
NAMES = [b["name"] for b in B]
TOPS = [b["node_top"] for b in B]
RAIN = "default:dirt_with_rainforest_litter"
STEP = 20

rng = random.Random(20260808)
seeds = [model.SEED] + [rng.randint(-2**31, 2**31 - 1) for _ in range(29)]

print("seed_s32            cont  rain%  jungle_edge%  deep_jungle%  top1  top1%  heatmean heatsd hummean humsd")
rows = {1: [], -1: []}
for sd in seeds:
    model.SEED = sd
    for zs in (1, -1):
        d = build(STEP, zs, B)
        L = d["land"]; tot = L.sum()
        ids, cnt = np.unique(d["bid"][L], return_counts=True)
        share = {NAMES[i]: 100 * c / tot for i, c in zip(ids, cnt)}
        vis = {}
        for i, c in zip(ids, cnt):
            vis[TOPS[i]] = vis.get(TOPS[i], 0) + 100 * c / tot
        rain = vis.get(RAIN, 0.0)
        t1 = max(vis.items(), key=lambda kv: kv[1])
        rows[zs].append((sd, rain, share.get("grug_jungle_edge", 0),
                         share.get("grug_deep_jungle", 0), t1[0], t1[1]))
        print("%-19d %5s %6.2f %8.2f %12.2f  %-38s %6.2f  %7.2f %6.2f %7.2f %6.2f" % (
            sd, "T" if zs > 0 else "A", rain, share.get("grug_jungle_edge", 0),
            share.get("grug_deep_jungle", 0), t1[0], t1[1],
            d["heat"].mean(), d["heat"].std(), d["hum"].mean(), d["hum"].std()))
        sys.stdout.flush()

for zs, nm in ((1, "THRONG"), (-1, "ACCORD")):
    a = np.array([r[1] for r in rows[zs]])
    print("\n%s rainforest-litter share over %d seeds: mean %.2f%% sd %.2f%% min %.2f%% max %.2f%%"
          % (nm, len(a), a.mean(), a.std(), a.min(), a.max()))
    print("   percentiles 10/25/50/75/90: " + " ".join("%.1f" % v for v in np.percentile(a, [10, 25, 50, 75, 90])))
    print("   this world (seed %d) = %.2f%%  -> percentile %.0f" %
          (seeds[0], a[0], 100 * (a < a[0]).mean()))
    t1 = np.array([r[5] for r in rows[zs]])
    print("   largest single visible top share: mean %.1f%% sd %.1f%% max %.1f%% (this world %.1f%%)"
          % (t1.mean(), t1.std(), t1.max(), t1[0]))
    from collections import Counter
    print("   which node wins most often: " + str(Counter(r[4] for r in rows[zs]).most_common()))
