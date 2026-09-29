"""Material shares of the exposed side faces in a dump: solid voxels with an
air neighbour in x or z (inside the box, not on its cut edge) and at least
three nodes below their column's top (the rock face, not the grass lip).
Usage: face_share.py DUMP.tsv"""
import sys, collections
cells, top = {}, {}
xmax = zmax = 0
for line in open(sys.argv[1]):
    x, y, z, name, _ = line.rstrip("\n").split("\t")
    x, y, z = int(x), int(y), int(z)
    xmax, zmax = max(xmax, x), max(zmax, z)
    soft = ("leaves" in name or "tree" in name or "grass_" in name or "shrub" in name or
            "source" in name or "bone_pile" in name or "water" in name or "snow" == name[-4:])
    if soft:
        continue
    cells[(x, y, z)] = name
    if top.get((x, z), -999) < y:
        top[(x, z)] = y
count = collections.Counter()
for (x, y, z), name in cells.items():
    if x == 0 or z == 0 or x == xmax or z == zmax or top[(x, z)] - y < 3:
        continue
    if any((x + dx, y, z + dz) not in cells for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))):
        count[name] += 1
total = sum(count.values())
print("exposed face voxels %d" % total)
for name, n in count.most_common(12):
    print("  %-36s %6.2f%%" % (name, 100.0 * n / total))
