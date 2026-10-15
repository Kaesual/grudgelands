#!/usr/bin/env python3
"""Lane MGPROF summarizer: per-chunk stage table from one or more boots.

Usage: summarize.py [--per-boot] [--median] [--pct|--hash] BOOT_DIR [BOOT_DIR...]
       summarize.py --first-start BOOT_DIR
  --median  cells show the median instead of the mean (with min-max)
  --pct     print a compact table instead: the statistic of each group and
            its share of the statistic of the callback total
  --hash    print the SHA-256 calls and raw core.sha256 ms per stage instead
  --first-start  the first start of a fresh world (lanes MEAS/MEAS2): wall and
            CPU seconds to "preparation complete" and to the end, and the
            preparation chunks by type with their callback totals

Each BOOT_DIR is an OUT directory of tools/mgprof/run.sh (server.log,
console.log). For every probe chunk (request ... done lines) it takes:
  * the GRUG_MGPROF line of the same minp (stage marks s.*, sub-timers u.*,
    counters c.*, callback total; mode=totals lines carry only the total);
  * the engine profiler windows printed between this chunk's request and the
    next one (console.log, info level): "Mapgen::makeChunk" and
    "Lua on_generated" (count x average ms, summed over the windows).
Stages are grouped as in the report (GROUPS); every fine stage belongs to
exactly one group, so the groups sum to the callback total. Prints Markdown.
"""
import re
import statistics
import sys
from pathlib import Path

GROUPS = [
    ("planner R5", ["plan_entry", "plan_r5"]),
    ("planner R6 columns", ["plan_r6_columns"]),
    ("planner R6 candidates", ["plan_r6_candidates"]),
    ("planner successor", ["plan_successor"]),
    ("VM get_data/param2", ["w_entry", "w_checks", "in_vm_get"]),
    ("input copy+zero", ["in_copy_zero"]),
    ("R5 adapter", ["r5_adapter"]),
    ("R5 adapter: setup + heightmap check", ["r5a_setup"]),
    ("R5 adapter: shadow get_data/param2", ["r5a_shadow_get"]),
    ("R5 adapter: resolve + validate pass", ["r5a_resolve_validate"]),
    ("R5 adapter: replay pass", ["r5a_replay"]),
    ("R5 adapter: shadow set_data/param2 + liquids", ["r5a_shadow_set"]),
    ("surface column passes (skin, P7, R9)", ["skin_columns", "p7", "r9_skin"]),
    ("R8 strata", ["r8_strata"]),
    ("R24 fill layers", ["r24_fill_layers"]),
    ("R8 cave mouth", ["r8_cave_mouth"]),
    ("P8 setup", ["p8_setup"]),
    ("P8 resources", ["p8_resources"]),
    ("P9 decorations", ["p9_decorations"]),
    ("successor roads", ["succ_roads"]),
    ("successor swamp", ["succ_swamp"]),
    ("successor P9G", ["succ_p9g"]),
    ("successor world content", ["succ_world_content"]),
    ("successor anchors", ["succ_anchors"]),
    ("successor settlements", ["succ_settlements"]),
    ("successor arena+glue", ["succ_closures", "succ_context", "succ_arena",
                              "succ_ledger", "evidence_runs"]),
    ("final diff scan", ["final_diff"]),
    ("VM write-back (set_data/param2)", ["commit_light_read", "commit_set_data"]),
    ("relight", ["commit_relight"]),
    ("update_liquids", ["commit_liquids"]),
    ("air check + tail", ["air_check", "tail"]),
]
SUBS = [("  of which P8 host scan", "p8_host_scan"),
        ("  of which P8 budget + root-draw setup", "p8_budget_draw_setup"),
        ("  of which P8 veins (root draws + growth)", "p8_veins_total"),
        ("  of which P8 vein growth (frontier + rank digests)", "p8_vein_growth"),
        ("  of which R5 shadow copies", "r5_shadow_copy"),
        ("  of which P9G scan + rank digests", "p9g_scan_and_rank_digests"),
        ("  of which P9G budget + sort", "p9g_budget_and_sort")]
COUNTS = ["r5_runs", "candidates", "p8_active_resources", "p8_host_eligible_calls",
          "p8_eligible_hosts", "p8_placed_nodes", "p8_veins", "p8_frontier_host_calls",
          "p8_rank_digests", "p8_root_draws", "p8_frontier_candidates", "modified_voxels",
          "light_columns", "liquid_columns", "succ_write_road", "succ_write_p9g",
          "succ_write_anchor", "succ_write_hearthpine", "cell_cache_miss"]
PROFILER = re.compile(r"EmergeThread: (Mapgen::makeChunk|Lua on_generated) \[ms\] _*\s+(\d+)x\s+([0-9.]+)")
REQUEST = re.compile(r"\[mgprof_probe\] request id=(\S+) minp=(\S+)")
DONE = re.compile(r"\[mgprof_probe\] done id=(\S+) minp=\S+ action=(\d+) wall_ms=([0-9.]+)")


def parse_boot(path):
    path = Path(path)
    chunks, order = {}, []
    for line in (path / "server.log").read_text(errors="replace").splitlines():
        m = REQUEST.search(line)
        if m:
            chunks[m.group(1)] = {"id": m.group(1), "minp": m.group(2), "engine": {}}
            order.append(m.group(1))
        m = DONE.search(line)
        if m:
            chunks[m.group(1)]["wall_ms"] = float(m.group(3))
        if "GRUG_MGPROF " in line:
            fields = dict(kv.split("=", 1) for kv in line.split("GRUG_MGPROF ", 1)[1].split())
            for row in chunks.values():
                if row["minp"] == fields["minp"] and "prof" not in row:
                    row["prof"] = fields
    current = None
    console = path / "console.log"
    for line in console.read_text(errors="replace").splitlines() if console.exists() else []:
        m = REQUEST.search(line)
        if m:
            current = chunks.get(m.group(1))
            continue
        m = PROFILER.search(line)
        if m and current is not None:
            engine = current["engine"]
            engine[m.group(1)] = engine.get(m.group(1), 0) + int(m.group(2)) * float(m.group(3))
            engine[m.group(1) + " n"] = engine.get(m.group(1) + " n", 0) + int(m.group(2))
    return [chunks[i] for i in order]


def ms(us):
    return us / 1000.0


STAT = statistics.mean


def fmt(values):
    if not values:
        return "-"
    mean = STAT(values)
    if len(values) == 1:
        return f"{mean:.1f}"
    return f"{mean:.1f} ({min(values):.0f}-{max(values):.0f})"


def pct_table(ids, stage_rows):
    print("| stage: ms (% of total) | " + " | ".join(ids) + " |")
    print("|---|" + "---|" * len(ids))
    totals = {cid: STAT([ms(int(p["total_us"])) for p in stage_rows(cid)]) for cid in ids}
    rows = []
    for name, keys in GROUPS:
        cells, show = [], False
        for cid in ids:
            v = STAT([ms(sum(int(p.get("s." + k, 0)) for k in keys)) for p in stage_rows(cid)])
            share = 100.0 * v / totals[cid]
            show = show or share >= 0.5
            cells.append(f"{v:.0f} ({share:.0f}%)" if v >= 0.5 else "0")
        if keys == ["p8_resources"]:
            rows.append((name, cells, True))
            for label, sub in SUBS:
                if sub.startswith("p8_"):
                    sub_cells = []
                    for cid in ids:
                        vals = [ms(int(p.get("u." + sub, 0))) for p in stage_rows(cid)
                                if "u." + sub in p]
                        sub_cells.append(f"{STAT(vals):.0f}" if vals else "-")
                    rows.append((label, sub_cells, True))
        else:
            rows.append((name, cells, show))
    small = [0.0] * len(ids)
    for name, cells, show in rows:
        if show:
            print(f"| {name} | " + " | ".join(cells) + " |")
    for name, keys in GROUPS:
        for i, cid in enumerate(ids):
            v = STAT([ms(sum(int(p.get("s." + k, 0)) for k in keys)) for p in stage_rows(cid)])
            if not any(n == name and sh for n, _, sh in rows):
                small[i] += v
    print("| other stages (each < 0.5 % everywhere) | " + " | ".join(
        f"{v:.1f}" for v in small) + " |")
    print("| **callback total** | " + " | ".join(f"**{totals[c]:.0f}**" for c in ids) + " |")


PROBE_KV = re.compile(r"(\w+)=(-?[0-9.]+)")


def chunk_type(minp_y, maxp_y, result):
    if result == "air_skip":
        return "air (writer skipped)"
    if minp_y >= -32:
        return "surface (y >= -32)"
    if minp_y == -112:
        return "B (-112..-33)"
    if maxp_y <= -113:
        return "wholly underground (y <= -113)"
    return "other"


def first_start(path):
    """One fresh-world boot of run.sh: the starts preload, then the corpus."""
    path = Path(path)
    head = dict(PROBE_KV.findall((path / "headless.txt").read_text()))
    probe, prep, corpus, done = {}, [], [], False
    for line in (path / "server.log").read_text(errors="replace").splitlines():
        for key, marker in [("loaded", "] loaded "), ("step", "] first server step "),
                            ("ready", "] preparation complete "), ("end", " at the end")]:
            if "[mgprof_probe]" in line and marker in line:
                probe[key] = {k: float(v) for k, v in PROBE_KV.findall(line)}
                if key == "end":  # "cpu_s=X at the end step_wall_s=Y epoch=Z"
                    probe[key]["cpu_s"] = float(line.split("cpu_s=")[1].split()[0])
                if key == "ready":
                    done = True
        # Boots before lane MEAS have only the probe's 1 s polling line.
        m = re.search(r"\] preparation ready after .*\((\d+)/(\d+) chunks\)", line)
        if m:
            probe.setdefault("ready", {"chunks": float(m.group(2))})
            done = True
        if "GRUG_MGPROF " in line:
            fields = dict(kv.split("=", 1) for kv in line.split("GRUG_MGPROF ", 1)[1].split())
            (corpus if done else prep).append(fields)
    launch = float(head["launch_epoch"]) if "launch_epoch" in head else None

    def since_launch(key):
        if launch is None or key not in probe:
            return "-"
        return f"{probe[key]['epoch'] - launch:.0f}"

    step_s = probe.get("ready", {}).get("step_wall_s")
    print("| first start | wall s from launch (+-1) | wall s from first server step | server CPU s |")
    print("|---|---|---|---|")
    print(f"| mods loaded (probe init) | {since_launch('loaded')} | - | "
          f"{probe.get('loaded', {}).get('cpu_s', '-')} |")
    print(f"| first server step | {since_launch('step')} | 0 | "
          f"{probe.get('step', {}).get('cpu_s', '-')} |")
    print(f"| preparation complete | {since_launch('ready')} | "
          f"{step_s if step_s is not None else '-'} | {probe.get('ready', {}).get('cpu_s', '-')} |")
    end_launch = (f"{float(head['log_end_epoch']) - launch:.0f} (log end)"
                  if launch is not None and "log_end_epoch" in head else since_launch("end"))
    print(f"| end (after the corpus of {len(corpus)} chunks) | {end_launch} | "
          f"{probe.get('end', {}).get('step_wall_s', '-')} | {probe.get('end', {}).get('cpu_s', '-')} |")
    print()
    # Engine profiler windows up to the probe's "preparation complete" line.
    engine = {}
    console = path / "console.log"
    for line in console.read_text(errors="replace").splitlines() if console.exists() else []:
        if ("] preparation complete " in line or "] preparation ready after " in line
                or REQUEST.search(line)):
            break
        m = PROFILER.search(line)
        if m:
            engine[m.group(1)] = engine.get(m.group(1), 0) + int(m.group(2)) * float(m.group(3))
            engine[m.group(1) + " n"] = engine.get(m.group(1) + " n", 0) + int(m.group(2))
    groups = {}
    for fields in prep:
        lo, hi = fields["minp"].split(","), fields["maxp"].split(",")
        name = chunk_type(int(lo[1]), int(hi[1]), fields.get("result"))
        groups.setdefault(name, []).append(ms(int(fields["total_us"])))
        groups.setdefault((name, int(lo[1])), []).append(ms(int(fields["total_us"])))
    expected = int(probe.get("ready", {}).get("chunks", -1))
    print(f"| preparation chunks ({len(prep)} callbacks, plan total {expected}) "
          "| chunks | Lua callback total ms: sum | mean (min-max) |")
    print("|---|---|---|---|")
    order = ["air (writer skipped)", "surface (y >= -32)", "B (-112..-33)",
             "wholly underground (y <= -113)", "other"]
    for name in order:
        if name in groups:
            values = groups[name]
            print(f"| {name} | {len(values)} | {sum(values):.0f} | {fmt(values)} |")
            heights = sorted(k[1] for k in groups if isinstance(k, tuple) and k[0] == name)
            for y in heights if len(heights) > 1 else []:
                values = groups[(name, y)]
                print(f"| &nbsp;&nbsp;of which minp y = {y} | {len(values)} | "
                      f"{sum(values):.0f} | {fmt(values)} |")
    every = [v for key, values in groups.items() if isinstance(key, str) for v in values]
    if every:
        print(f"| **all** | **{len(every)}** | **{sum(every):.0f}** | {fmt(every)} |")
    for key in ["Lua on_generated", "Mapgen::makeChunk"]:
        if key in engine:
            print(f"| engine profiler: {key} | {engine[key + ' n']} | {engine[key]:.0f} | "
                  f"{engine[key] / max(engine[key + ' n'], 1):.1f} |")
    print()
    if step_s and step_s > 0 and every:
        busy = sum(every) + engine.get("Mapgen::makeChunk", 0)
        print(f"Emerge thread: {len(every) / step_s:.2f} chunks/s over the preparation "
              f"({len(every)} chunks in {step_s:.1f} s from the first server step); "
              f"Lua callbacks + makeChunk = {busy / 1000:.1f} s "
              f"({100 * busy / 1000 / step_s:.0f} % of that wall).")


def main():
    args = sys.argv[1:]
    if "--first-start" in args:
        for a in args:
            if not a.startswith("--"):
                first_start(a)
        return
    global STAT
    per_boot = "--per-boot" in args
    if "--median" in args:
        STAT = statistics.median
    boots = [parse_boot(a) for a in args if not a.startswith("--")]
    ids = [row["id"] for row in boots[0]]
    stage_boots = [[r for r in b] for b in boots
                   if b and b[0].get("prof", {}).get("mode") == "stages"]
    total_boots = [b for b in boots if b and b[0].get("prof", {}).get("mode") == "totals"]

    def stage_rows(chunk_id):
        return [r["prof"] for b in stage_boots for r in b if r["id"] == chunk_id and "prof" in r]

    if "--hash" in args:
        # SHA-256 calls per stage (h.<stage>=calls/us/bytes; count from the
        # first boot that has it, raw core.sha256 time as the mean of them).
        stages = sorted({k for b in stage_boots for r in b for k in r.get("prof", {})
                         if k.startswith("h.")})
        print("| SHA-256 per stage: calls / raw ms | " + " | ".join(ids) + " |")
        print("|---|" + "---|" * len(ids))
        for key in stages:
            cells = []
            for cid in ids:
                vals = [p[key] for p in stage_rows(cid) if key in p]
                if not vals:
                    cells.append("-")
                    continue
                calls = int(vals[0].split("/")[0])
                raw = STAT([int(v.split("/")[1]) / 1000 for v in vals])
                cells.append(f"{calls} / {raw:.1f}")
            print(f"| {key[2:]} | " + " | ".join(cells) + " |")
        return
    if "--pct" in args:
        pct_table(ids, stage_rows)
        return
    # Main table: chunk x group, ms, mean (min-max) over the stage boots.
    print("| stage (ms) | " + " | ".join(ids) + " |")
    print("|---|" + "---|" * len(ids))
    covered = set()
    for name, keys in GROUPS:
        covered.update(keys)
        cells = []
        for cid in ids:
            vals = [ms(sum(int(p.get("s." + k, 0)) for k in keys)) for p in stage_rows(cid)]
            cells.append(fmt(vals))
        print(f"| {name} | " + " | ".join(cells) + " |")
        owner = {"p8_resources": "p8_", "r5_adapter": "r5_", "succ_p9g": "p9g_"}
        if len(keys) == 1 and keys[0] in owner:
            for label, sub in SUBS:
                if sub.startswith(owner[keys[0]]):
                    cells = [fmt([ms(int(p.get("u." + sub, 0))) for p in stage_rows(cid)])
                             for cid in ids]
                    print(f"| {label} | " + " | ".join(cells) + " |")
    cells = []
    for cid in ids:
        rows = stage_rows(cid)
        rest = []
        for p in rows:
            extra = [k for k in p if k.startswith("s.") and k[2:] not in covered]
            rest.append(ms(sum(int(p[k]) for k in extra)))
        cells.append(fmt(rest))
    print("| (unlisted stages) | " + " | ".join(cells) + " |")
    print("| **callback total (stage boots)** | " + " | ".join(
        fmt([ms(int(p["total_us"])) for p in stage_rows(cid)]) for cid in ids) + " |")
    print("| stage sum - total | " + " | ".join(
        fmt([ms(sum(int(v) for k, v in p.items() if k.startswith("s.")) - int(p["total_us"]))
             for p in stage_rows(cid)]) for cid in ids) + " |")
    if total_boots:
        print("| callback total (totals boot) | " + " | ".join(
            fmt([ms(int(r["prof"]["total_us"])) for b in total_boots for r in b
                 if r["id"] == cid and "prof" in r]) for cid in ids) + " |")
    for key, label in [("Lua on_generated", "engine: Lua on_generated (all boots)"),
                       ("Mapgen::makeChunk", "engine: Mapgen::makeChunk (all boots)")]:
        print(f"| {label} | " + " | ".join(
            fmt([r["engine"][key] for b in boots for r in b
                 if r["id"] == cid and key in r["engine"]]) for cid in ids) + " |")
    print("| probe request-to-done wall (all boots) | " + " | ".join(
        fmt([r["wall_ms"] for b in boots for r in b if r["id"] == cid and "wall_ms" in r])
        for cid in ids) + " |")
    print()
    # Counters are the same work in every boot; a counter only some boots
    # carry (a later instrumentation) is taken from the first boot that has it.
    print("| count (first stage boot carrying it) | " + " | ".join(ids) + " |")
    print("|---|" + "---|" * len(ids))
    first = {}
    for boot in stage_boots:
        for r in boot:
            merged = first.setdefault(r["id"], {})
            for key, value in r.get("prof", {}).items():
                merged.setdefault(key, value)
    for key in ["result", "cc_hits", "cc_misses", "cc_evictions"] + ["c." + c for c in COUNTS]:
        print(f"| {key.replace('c.', '')} | " + " | ".join(
            str(first.get(cid, {}).get(key, 0)) for cid in ids) + " |")
    if per_boot:
        print()
        for index, boot in enumerate(boots, 1):
            print(f"boot {index}: " + ", ".join(
                f"{r['id']}={ms(int(r['prof']['total_us'])):.0f}"
                f"/{r['engine'].get('Lua on_generated', 0):.0f}"
                f"/mk{r['engine'].get('Mapgen::makeChunk', 0):.0f}"
                for r in boot if "prof" in r))


if __name__ == "__main__":
    main()
