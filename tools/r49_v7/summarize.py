#!/usr/bin/env python3
"""Round 49 lane V7: the v7 flag variants side by side.

Usage: summarize.py [--compact] VARIANT=BOOT_DIR [VARIANT=BOOT_DIR ...]
  e.g. summarize.py baseline=tools/r49_v7/evidence/baseline \
           nomountains=tools/r49_v7/evidence/nomountains \
           noridges=tools/r49_v7/evidence/noridges

Each BOOT_DIR is an OUT directory of tools/r49_v7/run.sh (tools/mgprof/run.sh
with tally.patch). Prints Markdown:
  1. per chunk and variant: the callback total without the V7 tally pass
     (`v7_tally`, a measuring-only pre-pass), coarse stage groups, the engine's
     makeChunk, the probe's request-to-done wall and the writer result;
  2. per chunk and variant: the R5 voxel tally (planned cut_natural voxels and
     the ones holding v7 rock = cleared; planned fill_void voxels, the native
     cave content kept under v7's heightmap and the void filled), the modified
     voxels and the P8 fill-ore hosts;
  3. per variant: the first start (preparation) and the chunk results of every
     callback of the boot (air skips, deep skips), the server CPU.
--compact prints instead one table with the mean over the boots of each
variant (boots named like "baseline2" count as "baseline"): request-to-done
wall, makeChunk, the callback total and its flag-dependent part (FLAG_STAGES:
the stages whose work depends on what v7 made), then the sums per chunk
column with chunks per second of one emerge thread (chunks / summed wall).
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "mgprof"))
import summarize as mg  # noqa: E402  (tools/mgprof/summarize.py)

COARSE = [
    ("planner", ["plan_entry", "plan_r5", "plan_r6_columns", "plan_r6_candidates",
                 "plan_successor"]),
    ("VM in", ["w_entry", "w_checks", "in_vm_get", "in_copy_zero"]),
    ("R5 adapter", ["r5_adapter", "r5a_setup", "r5a_shadow_get", "r5a_resolve_validate",
                    "r5a_replay", "r5a_shadow_set"]),
    ("strata+skin+fill layers", ["skin_columns", "p7", "r9_skin", "r8_strata",
                                 "r24_fill_layers", "r8_cave_mouth"]),
    ("P8 fill ores", ["p8_setup", "p8_resources"]),
    ("P9+P9G", ["p9_decorations", "succ_p9g"]),
    ("other successors", ["succ_closures", "succ_context", "succ_roads", "succ_swamp",
                          "succ_world_content", "succ_anchors", "succ_settlements",
                          "succ_arena", "succ_ledger", "evidence_runs"]),
    ("diff+write+light+liquids", ["final_diff", "commit_light_read", "commit_set_data",
                                  "commit_relight", "commit_liquids"]),
    ("air check+tail", ["air_check", "tail"]),
]
TALLY = "v7_tally"
# Stages whose work depends on v7's input (writes, fill hosts, air skip); the
# planner, P9/P9G and the other successors read only our own plan.
FLAG_STAGES = ["R5 adapter", "strata+skin+fill layers", "P8 fill ores",
               "diff+write+light+liquids", "air check+tail"]


def stage_ms(prof, names):
    return sum(int(prof.get("s." + n, 0)) for n in names) / 1000.0


def total_ms(prof):
    return (int(prof["total_us"]) - int(prof.get("s." + TALLY, 0))) / 1000.0


def count(prof, name):
    return int(prof.get("c." + name, 0))


def counted(prof, prefix):
    return sum(int(v) for k, v in prof.items() if k.startswith("c." + prefix))


def k(n):
    return "0" if n == 0 else f"{n / 1000:.0f}k" if n >= 10000 else f"{n / 1000:.1f}k"


def compact(boots):
    variants = []
    for name, _, _ in boots:
        base = re.sub(r"\d+$", "", name)
        if base not in variants:
            variants.append(base)
    ids = [row["id"] for row in boots[0][2]]
    groups = dict(COARSE)

    def values(cid, base=None):
        # (wall, makeChunk, Lua, flag-dependent Lua, flag-independent Lua)
        out = []
        for name, _, rows in boots:
            if base is not None and re.sub(r"\d+$", "", name) != base:
                continue
            row = next((r for r in rows if r["id"] == cid and "prof" in r), None)
            if row is None:
                continue
            p = row["prof"]
            flag = sum(stage_ms(p, groups[g]) for g in FLAG_STAGES)
            out.append((row.get("wall_ms", 0.0), row["engine"].get("Mapgen::makeChunk", 0.0),
                        total_ms(p), flag, total_ms(p) - flag))
        return out

    def mean(vals, i):
        return sum(v[i] for v in vals) / len(vals) if vals else float("nan")

    print("## Per chunk, mean over the boots of a variant (ms)\n")
    print("`norm. wall` replaces the boot's flag-independent Lua (planner, VM read, "
          "P9/P9G, other successors) by its mean over every boot, so the cold-planner "
          "and slow-process spread of identical work does not decide the comparison.\n")
    head = ["chunk"]
    for base in variants:
        head += [f"{base} wall", "norm. wall", "makeChunk", "Lua", "flag-dep. Lua"]
    print("| " + " | ".join(head) + " |")
    print("|" + "---|" * len(head))
    sums = {}
    for cid in ids:
        cells = [cid]
        column = cid.split("_")[0] if "_" in cid else cid
        if cid.startswith(("A_U", "B_U")):
            column = "deep (U1/U3/U6)"
        independent = mean(values(cid), 4)
        for base in variants:
            vals = values(cid, base)
            wall = mean(vals, 0)
            norm = wall - mean(vals, 4) + independent
            row = [wall, norm, mean(vals, 1), mean(vals, 2), mean(vals, 3)]
            cells += [f"{v:.0f}" for v in row]
            acc = sums.setdefault((column, base), [0] + [0.0] * 5)
            acc[0] += 1
            for i, v in enumerate(row):
                acc[i + 1] += v
        print("| " + " | ".join(cells) + " |")
    print("\n## Per chunk column: sums (ms) and chunks per second of one emerge thread "
          "(chunks / summed norm. wall; raw wall in brackets)\n")
    head = ["column", "chunks"]
    for base in variants:
        head += [f"{base} norm. wall", "makeChunk", "flag-dep. Lua", "chunks/s"]
    print("| " + " | ".join(head) + " |")
    print("|" + "---|" * len(head))
    columns = []
    for column, _ in sums:
        if column not in columns:
            columns.append(column)
    for column in columns:
        n = sums[(column, variants[0])][0]
        cells = [column, str(n)]
        for base in variants:
            acc = sums[(column, base)]
            cells += [f"{acc[2]:.0f}", f"{acc[3]:.0f}", f"{acc[5]:.0f}",
                      f"{1000 * acc[0] / acc[2]:.1f} ({1000 * acc[0] / acc[1]:.1f})"]
        print("| " + " | ".join(cells) + " |")


def main(argv):
    compact_mode = bool(argv) and argv[0] == "--compact"
    if compact_mode:
        argv = argv[1:]
    boots = []
    for arg in argv:
        name, _, path = arg.partition("=")
        boots.append((name, Path(path), mg.parse_boot(path)))
    if compact_mode:
        compact(boots)
        return 0
    ids = [row["id"] for row in boots[0][2]]
    print("## Stages (ms; total without the V7 tally pass)\n")
    head = ["chunk", "variant", "total"] + [c[0] for c in COARSE] + [
        "makeChunk", "wall", "result"]
    print("| " + " | ".join(head) + " |")
    print("|" + "---|" * len(head))
    for cid in ids:
        for name, _, rows in boots:
            row = next((r for r in rows if r["id"] == cid), None)
            if row is None or "prof" not in row:
                continue
            prof = row["prof"]
            cells = [cid, name, f"**{total_ms(prof):.0f}**"]
            cells += [f"{stage_ms(prof, names):.0f}" for _, names in COARSE]
            mk = row["engine"].get("Mapgen::makeChunk")
            cells += [f"{mk:.0f}" if mk is not None else "-",
                      f"{row.get('wall_ms', 0):.0f}", prof.get("result", "?")]
            print("| " + " | ".join(cells) + " |")
    print("\n## R5 voxel tally and writes (voxels)\n")
    head = ["chunk", "variant", "cut planned", "cleared (v7 rock)", "fill planned",
            "kept cave air", "kept cave liquid", "filled air", "filled liquid",
            "filled other", "modified", "P8 fill hosts", "fill ores", "v7 hm columns"]
    print("| " + " | ".join(head) + " |")
    print("|" + "---|" * len(head))
    for cid in ids:
        for name, _, rows in boots:
            row = next((r for r in rows if r["id"] == cid), None)
            if row is None or "prof" not in row:
                continue
            p = row["prof"]
            filled_air = count(p, "v7_fill_air")
            filled_liq = count(p, "v7_fill_liquid")
            filled_other = counted(p, "v7_fill_") - filled_air - filled_liq
            cells = [cid, name, k(count(p, "v7_plan_cut_natural")), k(counted(p, "v7_clear_")),
                     k(count(p, "v7_plan_fill_void")), k(count(p, "v7_keep_cave_air")),
                     k(count(p, "v7_keep_cave_liquid")), k(filled_air), k(filled_liq),
                     k(filled_other), k(count(p, "modified_voxels")),
                     k(count(p, "p8_fill_hosts")), k(count(p, "p8_placed_nodes")),
                     str(count(p, "v7_heightmap_columns_in_chunk"))]
            print("| " + " | ".join(cells) + " |")
    print("\n## Whole boot\n")
    head = ["variant", "callbacks", "writer ran", "air skip", "deep skip",
            "prep chunks", "prep s (first step to ready)", "prep Lua ms (sum)",
            "server CPU s (end)", "wall s"]
    print("| " + " | ".join(head) + " |")
    print("|" + "---|" * len(head))
    for name, path, rows in boots:
        lines = (path / "mgprof.txt").read_text(errors="replace").splitlines()
        results, prep_lua = {}, 0.0
        probe_minps = {r["minp"] for r in rows}
        for line in lines:
            f = dict(kv.split("=", 1) for kv in line.split("GRUG_MGPROF ", 1)[1].split())
            res = f.get("result", "?")
            results[res] = results.get(res, 0) + 1
            if f["minp"] not in probe_minps:
                prep_lua += total_ms(f)
        log = (path / "server.log").read_text(errors="replace")
        prep = re.search(r"preparation complete chunks=(\d+) step_wall_s=([0-9.]+)", log)
        cpu = re.search(r"cpu_s=([0-9.]+) at the end", log)
        wall = re.search(r"wall_s=(\d+)", (path / "headless.txt").read_text())
        air = results.get("air_skip", 0)
        deep = results.get("deep_skip", 0)
        n = sum(results.values())
        print("| " + " | ".join([
            name, str(n), str(n - air - deep), str(air), str(deep),
            prep.group(1) if prep else "-", prep.group(2) if prep else "-",
            f"{prep_lua:.0f}", cpu.group(1) if cpu else "-",
            wall.group(1) if wall else "-"]) + " |")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
