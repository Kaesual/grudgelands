"""Material shares of a dump in the mountain interior: above NATIVE_TOP (the
highest native-v7 heightmap value of the box's chunks, from the [r24t]
lines) and at least 41 below each column's top.
Usage: interior_share.py DUMP.tsv NATIVE_TOP"""
import sys, collections
path, native_top = sys.argv[1], int(sys.argv[2])
cells, top = {}, {}
for line in open(path):
    x, y, z, name, _ = line.rstrip("\n").split("\t")
    x, y, z = int(x), int(y), int(z)
    cells[(x, y, z)] = name
    if not ("leaves" in name or "tree" in name or "grass" in name or "shrub" in name or
            "source" in name or "bone_pile" in name) and top.get((x, z), -999) < y:
        top[(x, z)] = y
count = collections.Counter()
for (x, y, z), name in cells.items():
    if y > native_top and top[(x, z)] - y >= 41:
        count[name] += 1
total = sum(count.values())
print("interior voxels %d" % total)
for name, n in count.most_common(14):
    print("  %-36s %6.2f%%" % (name, 100.0 * n / total))
