"""Lua mapgen time (planner slice + writer) per chunk, before vs after, on the
chunks both runs generated. Groups: Orc coal box (x -256..256, z 2294..2806)
and the mountain boxes (x < -1100)."""
import re, sys
def load(path):
    rows = {}
    for line in open(path):
        m = re.search(r"\[r24t\] (-?\d+),(-?\d+),(-?\d+) us=(\d+) cpu_us=(\d+) hmin=(-?\d+) hmax=(-?\d+)", line)
        if m:
            x, y, z, us, cpu, hmin, hmax = map(int, m.groups())
            rows[(x, y, z)] = (us, cpu, hmin, hmax)
    return rows
before, after = load(sys.argv[1]), load(sys.argv[2])
common = sorted(set(before) & set(after))
def group(k):
    x, y, z = k
    if -352 <= x <= 256 and 2208 <= z <= 2806: return "orc"
    if x <= -1100 and 900 <= z <= 1200: return "mountain"
    if -700 <= x <= -500: return "cliff2"
    return "other"
for g in ["orc", "mountain", "cliff2", "other"]:
    ks = [k for k in common if group(k) == g]
    if not ks: continue
    bu = sum(before[k][0] for k in ks); au = sum(after[k][0] for k in ks)
    bc = sum(before[k][1] for k in ks); ac = sum(after[k][1] for k in ks)
    print("%-8s chunks %3d  wall %.2f s -> %.2f s (%+.1f%%)  cpu %.2f s -> %.2f s (%+.1f%%)" % (
        g, len(ks), bu / 1e6, au / 1e6, 100.0 * (au - bu) / bu, bc / 1e6, ac / 1e6, 100.0 * (ac - bc) / bc))
    # per y layer for the mountain
    if g == "mountain":
        for y in sorted({k[1] for k in ks}):
            kk = [k for k in ks if k[1] == y]
            b = sum(before[k][1] for k in kk); a = sum(after[k][1] for k in kk)
            print("   y %5d chunks %2d cpu %.2f -> %.2f s (%+.1f%%)" % (y, len(kk), b / 1e6, a / 1e6, 100.0 * (a - b) / b))
print("only before:", len(set(before) - set(after)), "only after:", len(set(after) - set(before)))
