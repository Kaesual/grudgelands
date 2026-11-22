#!/usr/bin/env python3
"""Round 86 lane ROADS: the census table from tools/r86_roads/run.sh output.

    python3 tools/r86_roads/summary.py OUT [MIN]

A wall is a cluster whose largest step is at least MIN (default 3: the cut's
own rock face adds at most 2 between neighbouring columns). Prints per rule
the seeds with walls, the count, the heights' distribution, where they stand
(an arena leg, a capital, elsewhere), per wall of today's rule the reach at
which today's 2:1 face would meet the ground, the steepest face rise along
today's walls under each rule, the run times and every seed with walls.
"""
import os
import re
import statistics
import sys

out = sys.argv[1]
low = int(sys.argv[2]) if len(sys.argv) > 2 else 3
seeds, failed = {}, []
for name in sorted(os.listdir(out)):
    if not name.endswith(".txt"):
        continue
    seed = name[:-4]
    text = open(os.path.join(out, name)).read()
    head = re.search(r"^seed \d+ .*build=([\d.]+) census=([\d.]+)", text, re.M)
    if not head:
        failed.append(seed)
        continue
    s = {"build": float(head.group(1)), "census": float(head.group(2)), "rules": {}, "walls": {},
         "faces": {}}
    for line in text.splitlines():
        p = line.split()
        if p[0] == "rule":
            s["rules"][p[1]] = dict(kv.split("=", 1) for kv in p[2:])
        elif p[0] == "wall":
            s["walls"].setdefault(p[1], []).append({
                "h": int(p[2]), "n": int(p[3]), "x": int(p[4]), "z": int(p[5]), "road": p[6],
                "kind": p[7], "where": p[10], "arena": int(p[11]), "rise": float(p[12]),
                "need": p[13]})
        elif p[0] == "faces":
            s["faces"][p[1]] = [int(v.split(":")[1]) for v in p[2:]]
    seeds[seed] = s

print(f"seeds {len(seeds)} read, {len(failed)} failed {' '.join(failed)}")
builds = [s["build"] for s in seeds.values()]
census = [s["census"] for s in seeds.values()]
print(f"seconds per seed: build {statistics.mean(builds):.1f} (max {max(builds):.1f}), "
      f"census {statistics.mean(census):.1f} (max {max(census):.1f})")
rules = []
for s in seeds.values():
    for r in s["rules"]:
        if r not in rules:
            rules.append(r)
BUCKETS = [(3, 5), (6, 9), (10, 19), (20, 29), (30, 10 ** 9)]
for rule in rules:
    with_walls, total, top, buckets, where = 0, 0, 0, [0] * len(BUCKETS), {}
    asked = 0
    for s in seeds.values():
        if rule not in s["rules"]:
            continue
        asked += 1
        ws = [w for w in s["walls"].get(rule, []) if w["h"] >= low]
        if ws:
            with_walls += 1
        total += len(ws)
        for w in ws:
            top = max(top, w["h"])
            for i, (a, b) in enumerate(BUCKETS):
                if a <= w["h"] <= b:
                    buckets[i] += 1
            where[w["where"]] = where.get(w["where"], 0) + 1
    dist = " ".join(f"{a}-{b if b < 10 ** 9 else ''}:{n}" for (a, b), n in zip(BUCKETS, buckets))
    print(f"rule {rule}: {asked} seeds, {with_walls} with walls >= {low}, {total} walls, "
          f"max {top}; heights {dist}; where {where}")
    faces = [v for s in seeds.values() for v in s["faces"].get(rule, [])]
    if faces:
        print(f"  steepest face rise along today's walls: max {max(faces)}, "
              f"median {statistics.median(faces)}")
need = {}
rise = [0, 0]
for s in seeds.values():
    for w in s["walls"].get("today", []):
        if w["h"] >= low:
            n = w["need"]
            k = ">128" if n.startswith(">") else ("<=32" if int(n) <= 32 else "<=40" if int(n) <= 40
                else "<=48" if int(n) <= 48 else "<=64" if int(n) <= 64 else "<=128")
            need[k] = need.get(k, 0) + 1
            rise[0 if w["rise"] < 2 else 1] += 1
print(f"today's walls: reach at which the 2:1 face meets the ground {need}; "
      f"natural rise beyond the edge < 2: {rise[0]}, >= 2: {rise[1]}")
print("seeds with walls (today): seed count max heights [where]")
rows = []
for seed, s in seeds.items():
    ws = [w for w in s["walls"].get("today", []) if w["h"] >= low]
    if ws:
        rows.append((max(w["h"] for w in ws), seed, ws))
for top, seed, ws in sorted(rows, reverse=True):
    hs = ",".join(f"{w['h']}{'a' if w['where'] == 'arena' else 'c' if w['where'] == 'capital' else ''}"
                  for w in ws)
    print(f"  {seed} {len(ws)} {top} {hs}")
