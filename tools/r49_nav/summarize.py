#!/usr/bin/env python3
"""Round 49 NAV probe summary (tools/r49_nav/run.sh's r49nav_results.json).

Usage: python3 tools/r49_nav/summarize.py RESULTS.json [--events SCENE MOVER]

Prints a Markdown table per mover: reached or not, when and from where, the
static checks at the start (the walkable line to the target, the engine's
search with padding 6 and 12), the detector's window verdicts, the counted
failures by kind, the condensed event sequence and a classification:

  reached            the mob struck the target (from below: it stood lower)
  never stuck        the detector never ended a window "stuck"
  no path -> give up stuck, every search failed or was rejected, give-up
  line exit loop     the clear-line exit failed (line_fail) before a give-up
  stuck on path      the mob got stuck on a found path before a give-up
  other              none of these

--events prints one trial's full event list.
"""
import json
import sys

KEEP = {
    "stuck", "found", "no_path", "rejected", "refused", "cap_wait",
    "leave_stuck", "leave_line", "leave_drift", "leave_end", "give_up",
    "line_fail", "path_stuck", "search_fail", "stop_attack", "re_engage",
    "hit",
}


def condensed(events):
    out = []
    first_hit = True
    for row in events:
        kind = row[1]
        if kind not in KEEP:
            continue
        if kind == "hit":
            if not first_hit:
                continue
            first_hit = False
        label = kind
        if out and out[-1][0] == label:
            out[-1][1] += 1
        else:
            out.append([label, 1, row[0]])
    parts = []
    for label, n, t in out:
        parts.append(f"{label}@{t:g}" + (f"x{n}" if n > 1 else ""))
    return " ".join(parts)


def classify(trial):
    c = trial.get("counts") or {}
    tgt_h = trial["target"][2]
    if trial.get("reached"):
        at = trial.get("hit_at") or [None, None, None]
        below = at[2] is not None and at[2] < tgt_h - 0.5
        base = "reached (from below)" if below else "reached"
        if c.get("nav_stuck"):
            base += " after stuck"
        return base
    if not c.get("nav_stuck") and not c.get("win_stuck"):
        return "never stuck"
    if c.get("give_up"):
        if c.get("line_fail"):
            return "line exit loop -> give up"
        if c.get("path_stuck"):
            return "stuck on path -> give up"
        if c.get("nav_no_path") or c.get("nav_rejected") or c.get("nav_refused"):
            return "stuck -> no path -> give up"
        return "give up (other)"
    return "other"


def windows(trial):
    c = trial.get("counts") or {}
    ratios = trial.get("ratios") or []
    free = [r for r in ratios if r >= 0.3]
    low_free = sum(1 for r in free if r < 0.6)
    return (f"{c.get('win_stuck', 0)}/{c.get('win_free', 0)}"
            f" (free<0.6: {low_free})")


def fails(trial):
    c = trial.get("counts") or {}
    keys = ["search_fail", "path_stuck", "line_fail", "give_up", "stop_attack"]
    return " ".join(f"{k}={c[k]}" for k in keys if c.get(k)) or "-"


SYMBOLS = [
    ("air", "."), ("bush_stem", "S"), ("bush_leaves", "b"),
    ("blueberry", "u"), ("_quarter", "Q"), ("_base", "r"), ("_branch", "r"),
    ("_twig", "r"), ("tree", "T"), ("leaves", "l"), ("needles", "l"),
    ("grass", ","), ("fern", ","), ("flower", ","), ("water", "~"),
]


def symbol(name):
    for key, sym in SYMBOLS:
        if key in name:
            return sym
    return "#"


def print_geometry(trial):
    """One natural trial's nodes, a layer per y (x right, z down), with the
    start (A) and the target (B) marked in their feet layers."""
    site = trial["site"]
    g = site["geometry"]
    frame = trial["frame"]
    minp, maxp, pal, cells = g["minp"], g["maxp"], g["palette"], g["cells"]
    nx = maxp["x"] - minp["x"] + 1
    nz = maxp["z"] - minp["z"] + 1
    start = (frame["x"], frame["y"] + 1, frame["z"])
    tu, tv, th = trial["target"]
    target = (frame["x"] + tu, frame["y"] + th, frame["z"] + tv)
    print(f"{trial['scene']} {trial['mover']}: obstacle {site.get('obstacle_node')}"
          f" at {site.get('obstacle')}, start {start}, target {target}")
    print("legend: . air, # ground/other, T trunk, Q quarter trunk, r root/limb,"
          " l leaves, b bush leaves, S bush stem, u blueberry, , plants, ~ water")
    i = 0
    for y in range(minp["y"], maxp["y"] + 1):
        rows = []
        for z in range(minp["z"], maxp["z"] + 1):
            row = ""
            for x in range(minp["x"], maxp["x"] + 1):
                ch = symbol(pal[cells[i] - 1])
                if (x, y, z) == start:
                    ch = "A"
                elif (x, y, z) == target:
                    ch = "B"
                row += ch
                i += 1
            rows.append(row)
        print(f"y {y} (h {y - frame['y']}):")
        for row in rows:
            print("  " + row)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    data = json.load(open(sys.argv[1]))
    trials = data["trials"]
    # Empty Lua tables come back as null.
    for t in trials:
        for key in ("events", "ratios", "track"):
            t[key] = t.get(key) or []
        t["counts"] = t.get("counts") or {}
    if len(sys.argv) >= 4 and sys.argv[2] == "--geometry":
        for t in trials:
            if t["scene"] == sys.argv[3] and t.get("site"):
                print_geometry(t)
                return 0
        print("no such natural trial")
        return 1
    if len(sys.argv) >= 5 and sys.argv[2] == "--events":
        for t in trials:
            if t["scene"] == sys.argv[3] and t["mover"] == sys.argv[4]:
                print(json.dumps(t.get("static")))
                for row in t["events"]:
                    print(row)
                return 0
        print("no such trial")
        return 1
    meta = data.get("meta", {})
    print("# Round 49 NAV probe summary\n")
    print(f"Seed {meta.get('seed')}, navigation {json.dumps(meta.get('nav'))},"
          f" probe CPU {meta.get('cpu_s')} s.\n")
    print("| mover | entity | width | height | run | reach | step | attack |")
    print("|---|---|---|---|---|---|---|---|")
    for mid, m in data.get("movers", {}).items():
        print(f"| {mid} | {m.get('entity')} | {m.get('width')} | {m.get('height')}"
              f" | {m.get('run_velocity')} | {m.get('reach')} | {m.get('stepheight')}"
              f" | {m.get('attack_type')} |")
    print()
    for b in data.get("batches", []):
        print(f"- batch {b['mover']}: {b['seconds']} s, CPU {b.get('cpu_s')} s,"
              f" module counters {json.dumps(b.get('counters'))}")
    print()
    notes = {s["name"]: s for s in meta.get("scenes", [])}
    movers = []
    for t in trials:
        if t["mover"] not in movers:
            movers.append(t["mover"])
    for mover in movers:
        print(f"## {mover}\n")
        print("| scene | target u,v,h | result | t hit | hit at u,v,h | min d |"
              " line0 | p6 | p12 | windows stuck/free | searches/found |"
              " fails | sequence |")
        print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        for t in trials:
            if t["mover"] != mover:
                continue
            st = t.get("static") or {}
            c = t.get("counts") or {}
            p6 = st.get("path6", 0)
            if p6 and st.get("path6_ok") is False:
                p6 = f"{p6} rej"
            p12 = st.get("path12", 0)
            if p12 and st.get("path12_ok") is False:
                p12 = f"{p12} rej"
            hit_at = t.get("hit_at")
            site = t.get("site")
            name = t["scene"]
            if site:
                node = (site.get("obstacle_node") or "").split(":")[-1]
                name += f" ({node}, d {site.get('dist')}, dh {site.get('dh')})"
            print(f"| {name} | {','.join(str(x) for x in t['target'])}"
                  f" | {classify(t)} | {t.get('t_hit', '')}"
                  f" | {','.join(str(x) for x in hit_at) if hit_at else ''}"
                  f" | {t.get('min_d')} | {st.get('line')} | {p6} | {p12}"
                  f" | {windows(t)} | {c.get('searches', 0)}/{c.get('searches_found', 0)}"
                  f" | {fails(t)} | {condensed(t.get('events', []))} |")
        print()
    print("## Scenes\n")
    for name, s in notes.items():
        print(f"- `{name}`: {s.get('note')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
