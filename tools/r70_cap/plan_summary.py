#!/usr/bin/env python3
"""Per capital over the seeds of tools/r70_cap/plan_seeds.sh: plots against the study's `today`
(tools/r70_design/data/checker-fleet.json), required plots, unrouted streets, new ones named."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
rows = {r["seed"]: r for r in json.loads((HERE.parent / "r70_design/data/checker-fleet.json").read_text())["rows"]}
out = Path(sys.argv[1])
seeds = sorted(p.stem for p in out.glob("*.json"))
for capital in ["highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"]:
    deltas, missing, infeasible, routes, new = [], 0, 0, 0, []
    for seed in seeds:
        data = json.loads((out / (seed + ".json")).read_text())
        cap = data.get("capitals", {}).get(capital)
        if not cap:
            missing += 1
            continue
        before = rows.get(seed, {}).get("today", {}).get("capitals", {}).get(capital)
        if before:
            deltas.append(len(cap["plots"]) - before["plots"])
        missing += len(cap["missing_required"])
        fails = cap["failures"] if isinstance(cap["failures"], dict) else {}
        infeasible += fails.get("infeasible") or 0
        labels = fails.get("no_route") or []
        labels = labels if isinstance(labels, list) else str(labels).split()
        was = (before or {}).get("failures") or {}
        was = set(str(was.get("no_route", "")).split()) if isinstance(was, dict) else set()
        new += [seed[:6] + ":" + str(label) for label in labels if label not in was]
        routes += len(labels)
    mean = sum(deltas) / len(deltas) if deltas else 0
    print("%-12s %d seeds, plots mean %+.2f worst %+d best %+d, required missing %d, "
          "unrouted %d, infeasible %d" % (capital, len(seeds), mean, min(deltas or [0]),
                                          max(deltas or [0]), missing, routes, infeasible))
    if new:
        print("  new unrouted: " + " ".join(new))
