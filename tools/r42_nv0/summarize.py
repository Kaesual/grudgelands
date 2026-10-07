#!/usr/bin/env python3
"""Round 42 NV0: summarize the navigation probe's result file.

    python3 tools/r42_nv0/summarize.py RESULTS.json [AFTER.json] [--out FILE]
                                       [--compact FILE]

Prints a Markdown summary: the movers, per mover a table over the scenes
(reached, time to the goal, searches and their cost, the stuck triggers of
today's code), the batches' step cost, and whatever calibration the run
holds (self-movement ratios from the tracks, find_path against padding and
distance, the scenes' smallest padding and fan radius, natural terrain, the
walkable-line test, the 40 chasers). With AFTER.json it adds a before/after
table per scene and mover. --compact writes the result file without the
per-step tracks (small enough to keep as evidence).
"""
import json
import math
import sys

WINDOWS = (0.5, 1.0)
THRESHOLDS = (0.2, 0.3, 0.4, 0.5)
ARRIVE = {"post": 2.0, "follow": 5.0, "villager": 1.6}
COMBAT_NEAR = 3.0  # melee reach: inside it a chaser stops on purpose


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def fmt(value, digits=1):
    if value is None:
        return "-"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def pct(values, p):
    if not values:
        return None
    s = sorted(values)
    return s[max(0, min(len(s) - 1, math.ceil(len(s) * p) - 1))]


def table(header, rows):
    out = ["| " + " | ".join(header) + " |",
           "|" + "|".join("---" for _ in header) + "|"]
    for row in rows:
        out.append("| " + " | ".join(fmt(c) for c in row) + " |")
    return "\n".join(out)


def triggers(trial):
    parts = []
    for key, value in sorted((trial.get("smart_mobs") or {}).items()):
        parts.append(f"{key} {value}")
    for key, value in sorted((trial.get("counts") or {}).items()):
        if key == "hits":
            continue
        parts.append(f"{key} {value}")
    if trial.get("stall_max"):
        parts.append(f"stall_max {trial['stall_max']:.0f}s")
    return ", ".join(parts) if parts else "none"


def scene_order(data):
    return [s["name"] for s in data["meta"].get("scenes") or []]


def mover_order(data):
    seen = []
    for trial in data.get("trials") or []:
        if trial["mover"] not in seen:
            seen.append(trial["mover"])
    return seen


def index_trials(data):
    return {(t["mover"], t["scene"]): t for t in data.get("trials") or []}


def movers_section(data):
    rows = []
    for mid, m in (data.get("movers") or {}).items():
        rows.append([mid, m.get("entity"), m.get("kind"), m.get("width"),
                     m.get("height"), m.get("walk_velocity"),
                     m.get("run_velocity"), m.get("stepheight"),
                     m.get("fear_height"), m.get("floats"), m.get("tier"),
                     m.get("T")])
    return "## Movers\n\n" + table(
        ["mover", "entity", "kind", "width", "height", "walk", "run", "step",
         "fear", "floats", "tier", "trial s"], rows)


def trials_section(data):
    out = ["## Scenes per mover (today's code)"]
    trials = index_trials(data)
    for mover in mover_order(data):
        rows = []
        for scene in scene_order(data):
            t = trials.get((mover, scene))
            if not t:
                continue
            rows.append([scene, t["reached"], t.get("t_goal"), t.get("min_d"),
                         t.get("searches"), t.get("found"),
                         round((t.get("search_us") or 0) / 1000, 2),
                         t.get("search_max_us"), triggers(t)])
        out.append(f"### {mover}\n\n" + table(
            ["scene", "reached", "t goal s", "min dist", "searches", "found",
             "search ms", "largest us", "stuck triggers / events"], rows))
    return "\n\n".join(out)


def batches_section(data):
    rows = []
    for b in data.get("batches") or []:
        rows.append([b["mover"], b["steps"], b.get("mob_us_p50"),
                     b.get("mob_us_p99"), b.get("mob_us_max"), b.get("fp_calls"),
                     round((b.get("fp_us") or 0) / 1000, 2), b.get("fp_max_step_us")])
    if not rows:
        return ""
    return ("## Batches (all lanes of one mover at once; wall-clock us, noisy)\n\n"
            + table(["mover", "steps", "mob step us p50", "p99", "max",
                     "find_path calls", "find_path ms", "largest step fp us"],
                    rows))


# ---------------------------------------------------------------- ratios

def goal_of(trial, data):
    scenes = {s["name"]: s for s in data["meta"].get("scenes") or []}
    scene = scenes.get(trial["scene"]) or {}
    return 14.0, 0.0, scene.get("goal_h", 1)


def windows_of(trial, data, width):
    """(ratio, label, t_end) for every window of `width` seconds in which the
    mob wanted to move the whole time and was not at its goal."""
    track = trial.get("track") or []
    gu, gv, _ = goal_of(trial, data)
    near = COMBAT_NEAR if trial["kind"] == "combat" else ARRIVE.get(trial["kind"], 1.5)
    t_goal = trial.get("t_goal")
    out = []
    i = 0
    for j in range(1, len(track)):
        tj = track[j][0]
        while i + 1 < j and tj - track[i + 1][0] >= width:
            i += 1
        ti = track[i][0]
        if tj - ti < width or tj - ti > width * 1.6:
            continue
        if t_goal is not None and tj >= t_goal:
            break
        seg = track[i:j + 1]
        if any(s[4] <= 0.05 for s in seg[1:]):
            continue
        if any(math.hypot(s[1] - gu, s[2] - gv) <= near for s in seg):
            continue
        cmd = sum(s[4] for s in seg[1:]) / (len(seg) - 1)
        moved = math.hypot(seg[-1][1] - seg[0][1], seg[-1][2] - seg[0][2])
        ratio = moved / (cmd * (tj - ti))
        coll = sum(1 for s in seg[1:] if s[5] & 4)
        # A walker is nudged once a second and the engine zeroes the blocked
        # part of its velocity, so a walker pushing a trunk collides only in
        # the step after each nudge: "free" also needs the second before the
        # window without a collision.
        before = any(s[5] & 4 for s in track[:i + 1] if s[0] >= ti - 1.0)
        if coll == 0 and not before:
            label = "free"
        elif coll > 0:
            label = "contact"
        else:
            label = "after contact"
        out.append((ratio, label, tj))
    return out


def speed_class(trial, data):
    m = (data.get("movers") or {}).get(trial["mover"]) or {}
    if trial["kind"] == "combat":
        return f"run {m.get('run_velocity')}"
    return f"walk {m.get('walk_velocity')}"


def ratio_section(data):
    groups = {}
    first_flag = []
    for trial in data.get("trials") or []:
        if not trial.get("track"):
            continue
        for width in WINDOWS:
            key = (trial["kind"] == "combat" and "combat" or "walk",
                   speed_class(trial, data), width)
            g = groups.setdefault(key, {"free": [], "contact": [],
                                        "after contact": [], "open_scene": []})
            for ratio, label, _ in windows_of(trial, data, width):
                g[label].append(ratio)
                if trial["scene"] == "open":
                    g["open_scene"].append(ratio)
    if not groups:
        return ""
    rows = []
    for key in sorted(groups):
        g = groups[key]
        row = [key[0], key[1], key[2], len(g["free"]),
               pct(g["free"], 0.01), pct(g["free"], 0.05), pct(g["free"], 0.5),
               len(g["open_scene"]), pct(g["open_scene"], 0.01),
               len(g["contact"]), pct(g["contact"], 0.5), pct(g["contact"], 0.9),
               len(g["after contact"]), pct(g["after contact"], 0.5)]
        rows.append([round(c, 2) if isinstance(c, float) else c for c in row])
    out = ["## Self-movement ratio (moved / commanded speed x window)",
           "Windows end at every server step; only windows in which the mob "
           "wanted to move the whole time, outside its reach or arrival radius "
           "and before reaching the goal. free = no horizontal node collision "
           "in the window or the second before it; contact = a collision in "
           "the window; after contact = none in the window but one in the "
           "second before (a walker resting against an obstacle between its "
           "1 Hz nudges). The open scene is the clean free-walking sample.",
           table(["kind", "speed", "window s", "free n", "free p1", "free p5",
                  "free p50", "open n", "open p1", "contact n", "contact p50",
                  "contact p90", "after n", "after p50"], rows)]
    rows = []
    for key in sorted(groups):
        g = groups[key]
        for th in THRESHOLDS:
            fp = sum(1 for r in g["free"] if r < th)
            fo = sum(1 for r in g["open_scene"] if r < th)
            hit = sum(1 for r in g["contact"] if r < th)
            rest = sum(1 for r in g["after contact"] if r < th)
            rows.append([key[0], key[1], key[2], th,
                         f"{fp}/{len(g['free'])}",
                         f"{fo}/{len(g['open_scene'])}",
                         f"{hit}/{len(g['contact'])}",
                         f"{rest}/{len(g['after contact'])}"])
    out.append("Flagged windows per threshold (free and open scene: false "
               "alarms; contact and after contact: detections):\n\n" + table(
                   ["kind", "speed", "window s", "threshold", "free flagged",
                    "open-scene flagged", "contact flagged",
                    "after-contact flagged"], rows))
    # Detection latency: first collision and first flag (ratio < 0.3) per trial.
    rows = []
    for trial in data.get("trials") or []:
        track = trial.get("track") or []
        if not track or trial["scene"] == "open":
            continue
        first_coll = next((s[0] for s in track if s[5] & 4), None)
        width = 0.5 if trial["kind"] == "combat" else 1.0
        flags = [t for r, _, t in windows_of(trial, data, width) if r < 0.3]
        stuck_time = 0.0
        prev = None
        for r, _, t in windows_of(trial, data, width):
            if prev is not None and r < 0.3:
                stuck_time += t - prev
            prev = t
        rows.append([trial["mover"], trial["scene"], trial["reached"], first_coll,
                     flags[0] if flags else None, round(stuck_time, 1)])
    out.append("Per trial: first horizontal collision, first window under 0.3 "
               "(0.5 s in combat, 1 s otherwise) and the time spent under it:\n\n"
               + table(["mover", "scene", "reached", "first collision s",
                        "first flag s", "flagged s"], rows))
    return "\n\n".join(out)


# ------------------------------------------------------------ calibration

def calib_section(data):
    calib = data.get("calib") or {}
    out = []
    field = calib.get("field")
    if field:
        rows = [[r["d"], r["pad"], r.get("box_cells"), r.get("found_us"),
                 r.get("found_max"), r.get("diag_us"), r.get("nopath_us"),
                 r.get("nopath_max"), r.get("found_ok"), r.get("nopath_ok")]
                for r in field]
        out.append("## find_path on the flat field (median of 5, us)\n\n" + table(
            ["d", "pad", "box cells", "found", "found max", "diagonal",
             "no path", "no path max", "found ok", "no path ok"], rows))
    sc = calib.get("scenes")
    if sc:
        rows = []
        for r in sc:
            found = [p for p in r["pads"] if p["found"]]
            first = found[0] if found else {}
            p4 = next((p for p in r["pads"] if p["pad"] == 4), {})
            p24 = next((p for p in r["pads"] if p["pad"] == 24), {})
            rows.append([r["scene"], r["from"], r.get("line_clear"),
                         r.get("min_pad"), first.get("len"), first.get("head2"),
                         first.get("head3"), first.get("wide"),
                         p4.get("us"), p4.get("found"), p24.get("us"),
                         r.get("fan_r_narrow"), r.get("fan_r_wide")])
        out.append("## Scenes: smallest padding, path checks, fan radius\n\n"
                   "From the start (0,0) or the blocked cell to the goal; "
                   "head2/head3 = waypoints without head room for a 2/3-node "
                   "mob, wide = waypoints a mob wider than one node scrapes; "
                   "fan r = smallest radius of a candidate (toward the goal, "
                   "height band 2, path at padding 4) with a walkable line on "
                   "to the goal (narrow: half width 0.3, wide: 0.7).\n\n" + table(
                       ["scene", "from", "line clear", "min pad", "len", "head2",
                        "head3", "wide", "pad4 us", "pad4 found", "pad24 us",
                        "fan r narrow", "fan r wide"], rows))
    land = calib.get("land")
    if land:
        rows = []
        for d in sorted({r["d"] for r in land}):
            sel = [r for r in land if r["d"] == d and r.get("target")]
            ok4 = [r for r in sel if r.get("ok4")]
            ok24 = [r for r in sel if r.get("ok24")]
            fail4 = [r["us4"] for r in sel if not r.get("ok4")]
            line = [r for r in sel if r.get("line")]
            ratio = [r["len24"] / d for r in ok24 if r.get("len24")]
            rows.append([d, len(sel), len(ok4), len(ok24), len(line),
                         pct([r["us4"] for r in ok4], 0.5),
                         pct([r["us4"] for r in ok4], 1.0),
                         pct(fail4, 0.5), pct(fail4, 1.0),
                         pct([r["us24"] for r in ok24], 0.5),
                         pct([r["us24"] for r in sel if not r.get("ok24")], 1.0),
                         pct(ratio, 0.5)])
        out.append("## Natural terrain: found paths against distance\n\n"
                   + table(["d", "targets", "found pad4", "found pad24",
                            "line walkable", "pad4 found us p50", "max",
                            "pad4 fail us p50", "max", "pad24 found us p50",
                            "pad24 fail max", "len/d p50"], rows))
    fan = calib.get("fan")
    if fan:
        rows = []
        for r in sorted({x["r"] for x in fan}):
            for band in sorted({x["band"] for x in fan}):
                sel = [x for x in fan if x["r"] == r and x["band"] == band]
                st = [x for x in sel if x.get("standable")]
                ok = [x for x in st if x.get("path4")]
                rows.append([r, band, len(sel), len(st), len(ok),
                             pct([x["us4"] for x in ok], 0.5),
                             pct([x["us4"] for x in st], 1.0),
                             pct([x.get("check_us", 0) for x in sel], 0.5)])
        out.append("## Natural terrain: candidate fan (5 candidates at 0, +-20, "
                   "+-40 deg per direction)\n\n" + table(
                       ["ring r", "band +-", "directions", "standable",
                        "path pad4", "path us p50", "path us max",
                        "check us p50"], rows))
    line = calib.get("line")
    if line:
        out.append("## Walkable-line prototype cost\n\n" + table(
            ["d", "us per test", "clear"],
            [[r["d"], r["us"], r["clear"]] for r in line]))
    c40 = calib.get("chasers40")
    if c40:
        rows = [[k, v] for k, v in c40.items() if not isinstance(v, dict)]
        rows.append(["smart_mobs", ", ".join(f"{k} {v}" for k, v in
                                             sorted((c40.get("smart_mobs") or {}).items()))])
        out.append("## 40 blocked chasers (20 s)\n\n" + table(["metric", "value"], rows))
    return "\n\n".join(out)


def compare_section(before, after):
    tb, ta = index_trials(before), index_trials(after)
    rows = []
    for mover in mover_order(before):
        for scene in scene_order(before):
            b, a = tb.get((mover, scene)), ta.get((mover, scene))
            if not b or not a:
                continue
            rows.append([mover, scene,
                         f"{fmt(b['reached'])} / {fmt(a['reached'])}",
                         f"{fmt(b.get('t_goal'))} / {fmt(a.get('t_goal'))}",
                         f"{b.get('searches')} / {a.get('searches')}",
                         f"{round((b.get('search_us') or 0) / 1000, 2)} / "
                         f"{round((a.get('search_us') or 0) / 1000, 2)}",
                         f"{b.get('search_max_us')} / {a.get('search_max_us')}"])
    return "## Before / after\n\n" + table(
        ["mover", "scene", "reached", "t goal s", "searches", "search ms",
         "largest us"], rows)


def main(argv):
    args, out_path, compact = [], None, None
    i = 0
    while i < len(argv):
        if argv[i] == "--out":
            out_path = argv[i + 1]
            i += 2
        elif argv[i] == "--compact":
            compact = argv[i + 1]
            i += 2
        else:
            args.append(argv[i])
            i += 1
    if not args:
        print(__doc__)
        return 2
    data = load(args[0])
    parts = [f"# NV0 probe summary ({args[0]})",
             f"Seed {data['meta'].get('seed')}, settings "
             f"{json.dumps(data['meta'].get('settings'), sort_keys=True)}, "
             f"A* budget {data['meta'].get('path_budget_us')} us/step."]
    if data.get("movers"):
        parts.append(movers_section(data))
    if data.get("trials"):
        parts.append(trials_section(data))
        parts.append(batches_section(data))
        parts.append(ratio_section(data))
    parts.append(calib_section(data))
    if len(args) > 1:
        parts.append(compare_section(data, load(args[1])))
    text = "\n\n".join(p for p in parts if p) + "\n"
    if out_path:
        with open(out_path, "w", encoding="utf-8") as handle:
            handle.write(text)
    else:
        sys.stdout.write(text)
    if compact:
        for trial in data.get("trials") or []:
            trial.pop("track", None)
        with open(compact, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=1, sort_keys=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
