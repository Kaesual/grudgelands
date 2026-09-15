"""How high does the avenue stand above its own ground, as BUILT?

Dur Brannoc's causeway parapet exists because the blend from its flat civic
core to the granite terraces falls faster than a road may descend, so its east
avenue leaves the ground on an eight-to-ten-node embankment with nothing at its
edge. This measures the same thing for Nhal Veyr from the read-back dump: the
deepest column of CARRIAGEWAY the writer had to fill.

The curtain's gatehouse stands in the same dump and is masonry dozens of
courses deep, so the count is over the road's own paving inside the envelope
and not over every cell in the file.
"""
import collections
import sys

path = sys.argv[1]
ROAD = {"grug_decor:castle_pavement_brick",
        "grug_decor:castle_pavement_brick_stair",
        "grug_decor:castle_pavement_brick_slab"}
LIMIT = 240

col = collections.defaultdict(list)
for line in open(path):
    if line.startswith("#"):
        continue
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 4:
        continue
    x, y, z, name = int(parts[0]), int(parts[1]), int(parts[2]), parts[3]
    if abs(x) > LIMIT or abs(z) > LIMIT or (abs(x) < 52 and abs(z) < 52):
        continue
    col[(x, z)].append((y, name))

worst = 0
worst_at = None
histogram = collections.Counter()
for key, cells in col.items():
    ys = [y for y, n in cells if n in ROAD]
    if not ys:
        continue
    span = max(ys) - min(ys)
    histogram[span] += 1
    if span > worst:
        worst, worst_at = span, key
print("deepest column of carriageway fill: %d courses at %s" % (worst, worst_at))
for span in sorted(histogram):
    print("   fill %2d: %d columns" % (span, histogram[span]))
