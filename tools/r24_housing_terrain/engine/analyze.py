"""Lane I engine evidence: timing, per-chunk digests and dump content.
Usage: analyze.py BEFORE_DIR AFTER_DIR"""
import re, sys, collections
before_dir, after_dir = sys.argv[1], sys.argv[2]

def chunks(path):
    t, d = {}, {}
    for line in open(path):
        m = re.search(r"\[r24t\] (-?\d+),(-?\d+),(-?\d+) us=(\d+) cpu_us=(\d+)", line)
        if m:
            x, y, z, us, cpu = map(int, m.groups())
            t[(x, y, z)] = (us, cpu)
        m = re.search(r"\[r24d\] (-?\d+),(-?\d+),(-?\d+) (\d+-\d+)", line)
        if m:
            d[tuple(map(int, m.groups()[:3]))] = m.group(4)
    return t, d

tb, db = chunks(before_dir + "/server.log")
ta, da = chunks(after_dir + "/server.log")
def group(k):
    x, y, z = k
    if 368 <= x <= 527 and 1968 <= z <= 2127: return "housing H (x 368..527, z 1968..2127)"
    if 608 <= x <= 767 and 1968 <= z <= 2127: return "non-housing N (x 608..767, z 1968..2127)"
    return "other (Orc start probe box, neighbours)"
common = sorted(set(tb) & set(ta))
print("timing: Lua planner slice + writer per chunk, same chunks before (main) and after (branch)")
for g in sorted({group(k) for k in common}):
    ks = [k for k in common if group(k) == g]
    bu = sum(tb[k][0] for k in ks); au = sum(ta[k][0] for k in ks)
    bc = sum(tb[k][1] for k in ks); ac = sum(ta[k][1] for k in ks)
    print("  %-42s chunks %3d  wall %6.2f s -> %6.2f s (%+.1f%%)  cpu %6.2f s -> %6.2f s (%+.1f%%)" % (
        g, len(ks), bu / 1e6, au / 1e6, 100.0 * (au - bu) / bu, bc / 1e6, ac / 1e6,
        100.0 * (ac - bc) / bc))
print("only before:", len(set(tb) - set(ta)), "only after:", len(set(ta) - set(tb)))
print("content digests per chunk (node names + param2):")
dc = sorted(set(db) & set(da))
for g in sorted({group(k) for k in dc}):
    ks = [k for k in dc if group(k) == g]
    diff = [k for k in ks if db[k] != da[k]]
    print("  %-42s chunks %3d identical %3d differ %3d %s" % (g, len(ks), len(ks) - len(diff),
        len(diff), " ".join("%d,%d,%d" % k for k in diff[:12])))

GROUND = re.compile(r"stone|dirt|sand|gravel|clay|mud|cobble|granite|slate|basalt")
BAND = {"default:sandstone", "default:gravel", "default:dirt", "default:clay",
        "default:desert_stone", "default:mossycobble", "grug_materials:slate",
        "grug_materials:basalt", "grug_materials:granite"}
def dump(path):
    cols = collections.defaultdict(dict)
    for line in open(path):
        x, y, z, name, _ = line.rstrip("\n").split("\t")
        cols[(int(x), int(z))][int(y)] = name
    stats = collections.Counter()
    for (x, z), col in cols.items():
        tops = [y for y, n in col.items() if GROUND.search(n)]
        if not tops: continue
        top = max(tops)
        stats["columns"] += 1
        for y, n in col.items():
            d = top - y
            if y > top:
                if n.endswith("_source") and "water" not in n and "lava" not in n:
                    stats["surface sources"] += 1
                    stats["src " + n] += 1
                elif "water" not in n:
                    stats["above-ground plants and trees"] += 1
            elif 5 <= d <= 40:
                stats["depth 5-40 nodes"] += 1
                if n in BAND: stats["depth 5-40 band/layer nodes"] += 1
                if "_with_" in n: stats["depth 5-40 ore nodes"] += 1
            elif d > 40:
                if y < top - 2 and n.endswith("_source") and "water" not in n and "lava" not in n:
                    stats["cave sources"] += 1
    return stats
print("dump boxes (64 x 64 columns; depth measured from the column's top ground node):")
for label, path in (("H before", before_dir + "/r24_dump_H.tsv"), ("H after", after_dir + "/r24_dump_H.tsv"),
                    ("N before", before_dir + "/r24_dump_N.tsv"), ("N after", after_dir + "/r24_dump_N.tsv")):
    s = dump(path)
    n = s["depth 5-40 nodes"]
    srcs = ", ".join("%s %d" % (k[4:], v) for k, v in sorted(s.items()) if k.startswith("src "))
    print("  %-9s band/layer share at depth 5-40: %5.1f%%  ores: %4.1f%%  surface sources %2d (%s)  plants/trees above ground %d  cave sources %d" % (
        label, 100.0 * s["depth 5-40 band/layer nodes"] / n, 100.0 * s["depth 5-40 ore nodes"] / n,
        s["surface sources"], srcs or "-", s["above-ground plants and trees"], s["cave sources"]))
