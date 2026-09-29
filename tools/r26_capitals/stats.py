#!/usr/bin/env python3
"""Round 26 Lane W: one table of render.lua's statistics, before and after.

  stats.py <out_root> [seedtag ...]
"""
import json
import os
import sys

CAPS = ['highcourt', 'dur_brannoc', 'nhal_veyr', 'gor_drazhak', 'lethariel', 'kezamba']
root = sys.argv[1]
tags = sys.argv[2:] or ['s1', 's42', 's8675309']
print('seed      variant cap          area  r_min-r_max  plots  ovf  fill_lo named_lo  arcs cross sq  towers  no_route        planner_s')
for t in tags:
    for v in ('before', 'after'):
        for c in CAPS:
            p = os.path.join(root, v, t, c + '.json')
            if not os.path.exists(p):
                continue
            J = json.load(open(p))
            s = J['stats']
            named = [q['id'] for q in J['left_out'] if q['tier'] != 'fill']
            fill = sum(1 for q in J['left_out'] if q['tier'] == 'fill')
            print(f"{t:9} {v:7} {c:12} {J['area'] / 1000:5.1f}k {s['rmin']:4.0f}-{s['rmax']:4.0f}"
                  f"    {s['placed']:2}/{s['total']:2} {s['overflowed']:4} {fill:6} {len(named):5}"
                  f"    {s['open_arcs']:4} {s['cross_lanes']:5} {s['squares']:2} {s['turrets']:6}"
                  f"  {(s.get('no_route') or '-').strip():15} {s['seconds']:.2f}"
                  + (f"  NAMED LEFT OUT: {' '.join(named)}" if named else '')
                  + (f"  REQUIRED MISSING: {' '.join(J['missing_required'])}" if J['missing_required'] else ''))
