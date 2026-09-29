"""Print a coarse top-height map and material counts of a dump TSV."""
import sys, collections
path = sys.argv[1]
step = int(sys.argv[2]) if len(sys.argv) > 2 else 5
top = {}
mats = collections.Counter()
for line in open(path):
    x, y, z, name, _ = line.rstrip("\n").split("\t")
    x, y, z = int(x), int(y), int(z)
    mats[name] += 1
    if name in ("air",) or "leaves" in name or "grass_" in name or name.endswith("_1"):
        continue
    if top.get((x, z), -999) < y:
        top[(x, z)] = y
xs = sorted({k[0] for k in top}); zs = sorted({k[1] for k in top})
print("materials:", ", ".join("%s %d" % kv for kv in mats.most_common(14)))
print("z\\x " + " ".join("%4d" % x for x in xs[::step]))
for z in zs[::step]:
    print("%4d " % z + " ".join("%4d" % top.get((x, z), -1) for x in xs[::step]))
