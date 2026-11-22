#!/usr/bin/env python3
"""Round 86 lane ROADS: the whole cross-section of today's walls per rule.

    python3 tools/r86_roads/sections.py OUT [SEED...]

Reads census.lua's "section" lines (R86_ROADS_SECTIONS=1) from OUT/<seed>.txt
and prints per rule the distribution over every wall of 3 or more: the largest
step between neighbouring columns anywhere from the road's edge to 6 beyond
the side zone and where it sits (road: within 3 of the edge, edge: within 3
of the side zone's edge, else mid band), the number of steps of more than 2,
the largest cliff (consecutive steps of more than 2: total rise, length,
start); then the depth of the cuts (the pre-road ground above the road at the
centreline and at the side zone's edge); then every wall of the SEEDs singly.
"""
import os
import statistics
import sys

out, singles = sys.argv[1], set(sys.argv[2:])
SIDE = 24
rows = []
for name in sorted(os.listdir(out)):
    if not name.endswith(".txt"):
        continue
    for line in open(os.path.join(out, name)):
        p = line.split()
        if not p or p[0] != "section":
            continue
        d = dict(kv.split("=", 1) for kv in p[3:])
        big, at = d["max"].split("@")
        cliff, rest = d["cliff"].split("/")
        clen, cat = rest.split("@")
        rows.append({"seed": name[:-4], "rule": p[1], "at": p[2], "wall": int(d["wall"]),
                     "depth": float(d["depth"]), "rise": float(d["rise"]), "big": abs(int(big)),
                     "big_at": int(at), "steep": int(d["steep"]), "cliff": int(cliff),
                     "clen": int(clen), "cat": int(cat)})


def where(e):
    return "road" if e < 3 else ("edge" if e >= SIDE - 3 else "mid")


def q(values, f):
    values = sorted(values)
    return values[min(len(values) - 1, int(f * len(values)))]


rules = []
for r in rows:
    if r["rule"] not in rules:
        rules.append(r["rule"])
for rule in rules:
    rs = [r for r in rows if r["rule"] == rule]
    big = [r["big"] for r in rs]
    pos = {}
    for r in rs:
        pos[where(r["big_at"])] = pos.get(where(r["big_at"]), 0) + 1
    steep = [r["steep"] for r in rs]
    cliff = [r["cliff"] for r in rs]
    cpos = {}
    for r in rs:
        if r["cliff"]:
            cpos[where(r["cat"])] = cpos.get(where(r["cat"]), 0) + 1
    print(f"{rule}: {len(rs)} walls; largest step median {statistics.median(big)} p90 {q(big, .9)} "
          f"max {max(big)}, at {pos}; steps > 2 per section median {statistics.median(steep)} "
          f"p90 {q(steep, .9)}; largest cliff rise median {statistics.median(cliff)} "
          f"p90 {q(cliff, .9)} max {max(cliff)}, length median "
          f"{statistics.median([r['clen'] for r in rs])}, starts at {cpos}; "
          f"sections with no step > 2: {sum(1 for v in steep if v == 0)}; "
          f"largest step <= 3: {sum(1 for v in big if v <= 3)}, <= 5: {sum(1 for v in big if v <= 5)}")
today = [r for r in rows if r["rule"] == "today"]
if today:
    dep = [r["depth"] for r in today]
    rise = [r["rise"] for r in today]
    print(f"depth at the centreline: median {statistics.median(dep):.1f} p90 {q(dep, .9):.1f} "
          f"max {max(dep):.1f}; ground above the road at the side zone's edge: median "
          f"{statistics.median(rise):.1f} p90 {q(rise, .9):.1f} max {max(rise):.1f}")
    b = [0, 0, 0, 0]
    for v in rise:
        b[0 if v <= 43 else 1 if v <= 60 else 2 if v <= 100 else 3] += 1
    print(f"  edge rise <= 43 (reachable inside 24 at today's slopes): {b[0]}, 43-60: {b[1]}, "
          f"60-100: {b[2]}, > 100: {b[3]}")
    b = [0, 0, 0, 0]
    for v in dep:
        b[0 if v <= 2 else 1 if v <= 6 else 2 if v <= 10 else 3] += 1
    print(f"  centreline depth <= 2: {b[0]}, 2-6: {b[1]}, 6-10: {b[2]}, > 10: {b[3]}")
for r in rows:
    if r["seed"] in singles:
        print(f"  {r['seed']} {r['at']} {r['rule']}: wall {r['wall']} depth {r['depth']:.1f} "
              f"rise {r['rise']:.1f}; largest step {r['big']} at {r['big_at']}; steps > 2: "
              f"{r['steep']}; cliff {r['cliff']} over {r['clen']} from {r['cat']}")
