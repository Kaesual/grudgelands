#!/usr/bin/env python3
"""Round 49 lane CACHE: summarize a shell-order probe boot.

    python3 -I tools/r49_cache/analyze.py OUT/probe.txt

probe.txt holds the probe's [r49cache] lines and the GRUG_MGPROF lines of the
boot (tools/r49_cache/run_probe.sh). Per phase: the chunks the probe
generated, and for every chunk column the chunks with Lua work in generation
order. The first such chunk of a column pays the cold column cost; a later
one "re-pays" it when its zones column cache misses reach half a column
(3,200 of the column's 6,400 columns; a new column with its halo misses about
7,200-7,500). For those the planner's column stages (R5 planner and R6
columns) are summed against the warm chunks' median. Also the other caches'
misses and evictions on later chunks, and the Lua heap.
"""
import re
import statistics
import sys

REPAY = 3200
SKIPS = {"deep_skip", "air_skip"}


def fields(line):
    out = {}
    for token in line.split():
        if "=" in token:
            key, value = token.split("=", 1)
            out[key] = value
    return out


def num(row, key):
    try:
        return float(row.get(key, 0))
    except ValueError:
        return 0.0


def main(path):
    requests = {}  # chunk key -> (phase, player, n, d)
    callbacks = []  # GRUG_MGPROF rows in order
    events = []
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if "GRUG_MGPROF " in line:
                row = fields(line[line.index("GRUG_MGPROF "):])
                callbacks.append(row)
            elif "[r49cache]" in line:
                text = line[line.index("[r49cache]") + len("[r49cache] "):].strip()
                events.append(text)
                if text.startswith("req "):
                    row = fields(text)
                    requests[row["chunk"]] = (int(row["phase"]), int(row["player"]),
                                              int(row["n"]), int(row["d"]))
    for text in events:
        if not text.startswith(("req ", "done ")):
            print("probe:", text)
    phases = {}
    for index, row in enumerate(callbacks):
        key = row.get("minp", "")
        if key not in requests:
            continue
        phase = requests[key][0]
        row["_index"] = index
        row["_player"] = requests[key][1]
        phases.setdefault(phase, []).append(row)
    print()
    print("preparation and other callbacks (not requested by the probe):",
          sum(1 for row in callbacks if row.get("minp", "") not in requests))
    for phase in sorted(phases):
        rows = phases[phase]
        print()
        print(f"## phase {phase}: {len(rows)} chunks generated")
        results = {}
        for row in rows:
            results[row.get("result", "?")] = results.get(row.get("result", "?"), 0) + 1
        print("results:", ", ".join(f"{k} {v}" for k, v in sorted(results.items())))
        columns = {}
        for row in rows:
            if row.get("result") in SKIPS:
                continue
            x, _, z = row["minp"].split(",")
            columns.setdefault((int(x), int(z)), []).append(row)
        firsts, laters = [], []
        for chunks in columns.values():
            firsts.append(chunks[0])
            laters.extend(chunks[1:])
        warm = [num(r, "s.plan_r5") + num(r, "s.plan_r6_columns") for r in laters
                if num(r, "cc_misses") < REPAY]
        warm_median = statistics.median(warm) / 1000 if warm else 0.0
        repaid = [r for r in laters if num(r, "cc_misses") >= REPAY]
        print(f"chunk columns with Lua work: {len(columns)}; first chunks {len(firsts)}, "
              f"later chunks {len(laters)}")

        def stats(label, group):
            if not group:
                print(f"  {label}: none")
                return
            misses = [num(r, "cc_misses") for r in group]
            column_ms = [(num(r, "s.plan_r5") + num(r, "s.plan_r6_columns")) / 1000
                         for r in group]
            total_ms = [num(r, "total_us") / 1000 for r in group]
            cand_ms = [num(r, "s.plan_r6_candidates") / 1000 for r in group]
            print(f"  {label}: {len(group)} chunks; column cache misses mean "
                  f"{statistics.mean(misses):.0f} (max {max(misses):.0f}); planner R5 + "
                  f"R6 columns mean {statistics.mean(column_ms):.1f} ms, sum "
                  f"{sum(column_ms):.0f} ms; R6 candidates sum {sum(cand_ms):.0f} ms; "
                  f"callback mean {statistics.mean(total_ms):.0f} ms")

        stats("first chunks", firsts)
        stats("later chunks", laters)
        stats("later chunks re-paying (misses >= %d)" % REPAY, repaid)
        if repaid:
            extra = sum((num(r, "s.plan_r5") + num(r, "s.plan_r6_columns")) / 1000 -
                        warm_median for r in repaid)
            print(f"  re-paid column cost: about {extra:.0f} ms over the warm median "
                  f"({warm_median:.1f} ms per chunk)")
            gaps = []
            for chunks in columns.values():
                for previous, row in zip(chunks, chunks[1:]):
                    if num(row, "cc_misses") >= REPAY:
                        gaps.append(row["_index"] - previous["_index"])
            print("  chunks generated between a column's previous chunk and its "
                  f"re-paying one: median {statistics.median(gaps):.0f}, min {min(gaps)}, "
                  f"max {max(gaps)}")
        lua = [r for r in rows if r.get("result") not in SKIPS]
        for counter in ("cc_evictions", "c.cell_cache_miss", "c.cell_cache_eviction",
                        "c.p9g_cache_hit", "c.p9g_cache_miss", "c.p9g_cache_eviction",
                        "c.front_cache_miss", "c.front_cache_flush", "c.cave_cache_miss",
                        "c.cave_cache_eviction"):
            total = sum(num(r, counter) for r in rows)
            later_total = sum(num(r, counter) for r in laters)
            print(f"  {counter}: {total:.0f} (on later chunks {later_total:.0f})")
        roots = [num(r, "c.p9g_cache_roots") for r in rows if num(r, "c.p9g_cache_miss")]
        if roots:
            print(f"  P9G kept roots per column: mean {statistics.mean(roots):.1f}, "
                  f"max {max(roots):.0f}")
        p9g_ms = {"miss": [], "hit": []}
        for r in lua:
            if num(r, "c.p9g_cache_hit"):
                p9g_ms["hit"].append(num(r, "s.succ_p9g") / 1000)
            elif num(r, "c.p9g_cache_miss"):
                p9g_ms["miss"].append(num(r, "s.succ_p9g") / 1000)
        for kind, values in p9g_ms.items():
            if values:
                print(f"  P9G stage on a {kind}: {len(values)} chunks, mean "
                      f"{statistics.mean(values):.1f} ms")
        heap = [num(r, "heap_after_kb") for r in rows]
        print(f"  Lua heap after a callback (emerge environment): "
              f"{min(heap) / 1024:.0f}-{max(heap) / 1024:.0f} MB")


if __name__ == "__main__":
    main(sys.argv[1])
