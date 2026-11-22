#!/usr/bin/env python3
"""Round 86 lane ROADS: what moved between two digest.lua outputs.

    python3 tools/r86_roads/compare.py BEFORE AFTER ["x,z x,z ..."] [NEAR]

Prints the layout and spawn region lines that differ, the raster columns
whose final ground, road kind or overlay exclusion changed (counted, and
whether each lies within NEAR (default 48) of a listed column, a known wall;
every change elsewhere is listed), and per chunk whether its nodes and its
decoration candidates changed (candidates added or removed, with their
distance to the nearest changed column).
"""
import sys

before, after = sys.argv[1], sys.argv[2]
walls = [tuple(int(v) for v in p.split(",")) for p in (sys.argv[3] if len(sys.argv) > 3 else "").split()]
near = int(sys.argv[4]) if len(sys.argv) > 4 else 48


def lines(path):
    return dict(l.rsplit(" ", 1) for l in open(path).read().splitlines())


a, b = lines(before + "/layouts.txt"), lines(after + "/layouts.txt")
diff = [k for k in sorted(set(a) | set(b)) if a.get(k) != b.get(k)]
print(f"layouts, region maps, their fields and spots: {len(a)} lines, differing: "
      f"{diff or 'none'}")


def raster(path):
    out = {}
    for line in open(path):
        x, z, y, kind, excl = line.split()
        out[(int(x), int(z))] = (int(y), kind, excl)
    return out


ra, rb = raster(before + "/raster.tsv"), raster(after + "/raster.tsv")
print(f"raster columns: {len(ra)} before, {len(rb)} after, keys equal: {set(ra) == set(rb)}")


def wall_of(x, z):
    for i, (wx, wz) in enumerate(walls):
        if max(abs(x - wx), abs(z - wz)) <= near:
            return i
    return None


height, kind, excl, elsewhere = {}, {}, {}, []
changed = []
for key in ra:
    va, vb = ra[key], rb.get(key)
    if va == vb:
        continue
    changed.append(key)
    w = wall_of(*key)
    if w is None:
        elsewhere.append((key, va, vb))
    if va[0] != vb[0]:
        height[w] = height.get(w, 0) + 1
    if va[1] != vb[1]:
        kind[w] = kind.get(w, 0) + 1
    if va[2] != vb[2]:
        excl[w] = excl.get(w, 0) + 1
print(f"columns changed: {len(changed)}; height by wall {height}; road kind by wall {kind}; "
      f"exclusion by wall {excl} (None = not near a listed wall)")
left = [k for k in changed if ra[k][1] != "-" and rb[k][1] == "-"]
print(f"columns leaving the road (and its corridor where the exclusion changed): {len(left)}; "
      f"exclusion road_corridor -> other: "
      f"{sum(1 for k in changed if ra[k][2] == 'road_corridor' and rb[k][2] != 'road_corridor')}")
deepest = max([0] + [ra[k][0] - rb[k][0] for k in changed])
raised = max([0] + [rb[k][0] - ra[k][0] for k in changed])
print(f"largest change of a column: {raised} up, {deepest} down")
for key, va, vb in elsewhere[:40]:
    print(f"  elsewhere {key}: {va} -> {vb}")


def chunks(path):
    out = {}
    for line in open(path):
        p = line.split()
        c = dict(kv.split("=", 1) for kv in p[2:])
        out[p[1]] = (c["nodes"], set(c["candidates"].split(";")) if c["candidates"] else set())
    return out


ca, cb = chunks(before + "/chunks.txt"), chunks(after + "/chunks.txt")
for key in sorted(ca):
    na, da = ca[key]
    nb, db = cb[key]
    if na == nb and da == db:
        print(f"chunk {key}: identical")
        continue
    moved = sorted(da ^ db)
    far = 0
    for c in moved:
        x, y, z = (int(float(v)) for v in c.split(":"))
        d = min((max(abs(x - k[0]), abs(z - k[1])) for k in changed), default=999)
        if d > 2:
            far += 1
    print(f"chunk {key}: nodes {'same' if na == nb else 'changed'}, candidates {len(da)} -> "
          f"{len(db)} ({len(da - db)} gone, {len(db - da)} new, {far} of them more than 2 "
          f"from a changed column)")
