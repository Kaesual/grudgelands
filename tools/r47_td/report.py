"""Round 47 lane TD: tables from tools/r47_td/measure.sh runs.

    python3 -I tools/r47_td/report.py RUN_DIR [RUN_DIR ...]

Each RUN_DIR holds a run.json. Runs with the same label (mode:species) are
repeats; per scene and window the table gives the mean over the repeats and,
in brackets, the spread (lowest..highest run). Columns:
  draws    the client's draw calls per frame ("Irr: drawcalls")
  kvert    thousands of vertices drawn per frame (renderMap SOLID + TRANS)
  blocks   MapBlocks drawn per frame
  ft       frame time mean and 95th percentile, ms (llvmpipe, see measure.sh)
  rss      the client's resident memory, MiB (mean over the window)
  mesh     the client's mesh making (ms, summed) from BUILT until meshed
Numbers are comparisons, never targets.
"""
import json
import os
import statistics
import sys


def window_stats(record):
    frames = sorted(record.get("frametimes_ms") or [])
    blocks = record.get("profiler") or []

    def avg(key):
        values = [b[key] for b in blocks if key in b]
        return statistics.mean(values) if values else 0.0

    vertices = avg("renderMap(SOLID): vertices drawn [#]") + avg("renderMap(TRANS): vertices drawn [#]")
    rss = record.get("rss_kib") or []
    return {
        "draws": avg("Irr: drawcalls"),
        "kvert": vertices / 1000,
        "blocks": avg("MapBlocks drawn [#]"),
        "ft": statistics.mean(frames) if frames else 0.0,
        "p95": frames[min(len(frames) - 1, int(len(frames) * 0.95))] if frames else 0.0,
        "rss": statistics.mean(rss) / 1024 if rss else 0.0,
        "frames": len(frames),
    }


def cell(values, fmt):
    if not values:
        return "-"
    mean = statistics.mean(values)
    if len(values) == 1:
        return fmt % mean
    return (fmt % mean) + " (" + (fmt % min(values)) + ".." + (fmt % max(values)) + ")"


def main():
    runs = {}
    for path in sys.argv[1:]:
        with open(os.path.join(path, "run.json")) as handle:
            run = json.load(handle)
        runs.setdefault(run["label"], []).append(run)
    for label, group in runs.items():
        order = group[0]["order"]
        print("### %s (%d run%s; load %s)\n" % (label, len(group), "" if len(group) == 1 else "s",
              ", ".join("/".join(r.get("loadavg", [])) for r in group)))
        print("| scene | trees | leaves | mesh ms | window | draws | kvert | blocks | ft mean | ft p95 | rss MiB |")
        print("|---|---|---|---|---|---|---|---|---|---|---|")
        for scene in order:
            built = group[0]["scenes"][scene]["built"].split()
            fields = dict(word.split("=", 1) for word in built if "=" in word)
            trees = fields.get("trees", "-")
            if fields.get("grove", "0") not in ("0", "nil"):
                trees += " (%s of them in the grove)" % fields["grove"]
            leaves = cell([float(r["scenes"][scene]["built"].split("leaves=")[1].split()[0])
                           for r in group if "leaves=" in r["scenes"][scene]["built"]], "%.0f")
            mesh = cell([r["scenes"][scene].get("mesh_ms", 0) for r in group], "%.0f")
            for window in ("W", "I"):
                stats = [window_stats(r["scenes"][scene]["windows"].get(window, {})) for r in group]
                print("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                    scene if window == "W" else "", trees if window == "W" else "",
                    leaves if window == "W" else "", mesh if window == "W" else "", window,
                    cell([s["draws"] for s in stats], "%.0f"),
                    cell([s["kvert"] for s in stats], "%.0f"),
                    cell([s["blocks"] for s in stats], "%.0f"),
                    cell([s["ft"] for s in stats], "%.1f"),
                    cell([s["p95"] for s in stats], "%.1f"),
                    cell([s["rss"] for s in stats], "%.0f")))
        print()


if __name__ == "__main__":
    main()
