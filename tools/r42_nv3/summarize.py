#!/usr/bin/env python3
"""Round 42 NV3: a Markdown summary of one or more nv3_results.json files
(tools/r42_nv3/run.sh), one row per settlement and file, in the order given:

    python3 tools/r42_nv3/summarize.py BEFORE.json [MORE.json ...]

Columns: searches (every core.find_path call while the settlement was
watched) per minute, the largest single search, the navigation's own count,
walker arrivals and spots given up, patrol waypoints advanced, snaps, one-spot
walkers, and the route cache's figures where the code has one."""
import json
import sys


def label(path):
    return path.rsplit("/", 2)[-2] if "/" in path else path


def main(paths):
    rows = []
    streets = []
    census = []
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        for s in data.get("settlements", []):
            fp, nav = s["find_path"], s["nav"]
            walkers = s.get("walkers") or []
            arrivals = sum(w["arrivals"] for w in walkers)
            given_up = sum(w["give_ups"] for w in walkers)
            walking = sum(1 for w in walkers if w["walker"])
            adv = sum(p["advances"] for p in s.get("patrols") or [])
            buckets = fp.get("buckets") or []
            cache = s.get("cache") or {}
            cache_text = "-"
            if cache:
                cache_text = ("legs %d (ok %d, none %d, street %d), searches %d "
                              "(%.1f ms, max %d us), smoothing %.1f ms, corners %d, "
                              "streets read %.1f ms") % (
                    cache.get("legs", 0), cache.get("ok", 0), cache.get("none", 0),
                    cache.get("street_legs", 0), cache.get("searches", 0),
                    cache.get("search_us", 0) / 1000, cache.get("max_us", 0),
                    cache.get("smooth_us", 0) / 1000, cache.get("corners", 0),
                    cache.get("streets_us", 0) / 1000)
            rows.append("| %s | %s %s | %d s | %d (%.1f/min; per 30 s %s) | %d us (d %.1f) | %d | %d/%d/%d | %d / %d | %d | %d | %d | %s |" % (
                label(path), s["kind"], s["key"], s["obs"], fp["n"], fp["per_min"],
                "/".join(str(b) for b in buckets) or "0", fp["max_us"], fp["max_d"],
                nav["searches"], len(walkers), walking, s["one_spot_walkers"],
                arrivals, given_up, adv, s["snaps"], nav.get("cap_waits", 0), cache_text))
        for c in data.get("census") or []:
            legs = c.get("legs") or []
            census.append("- %s: %d distinct legs (directed) through the cache in %.1f s: "
                          "walkers %d (ok %d, no route %d), patrols %d (ok %d, no route %d, "
                          "over the streets %d); this pass %d searches, %.1f ms; the whole cache "
                          "%d legs, %d searches, %.1f ms searching (largest %d us), %.1f ms "
                          "smoothing, %.1f ms reading the streets, %d corners, Lua heap +%.0f KiB "
                          "over the pass" % (
                              label(path) + " " + path.rsplit("/", 1)[-1], len(legs), c["seconds"], c["walker"]["legs"],
                              c["walker"]["ok"], c["walker"]["none"], c["patrol"]["legs"],
                              c["patrol"]["ok"], c["patrol"]["none"], c["patrol"].get("street", 0),
                              c["searches"], c["search_ms"], c["cache"]["legs"],
                              c["cache"]["searches"], c["cache"]["search_us"] / 1000,
                              c["cache"]["max_us"], c["cache"]["smooth_us"] / 1000,
                              c["cache"].get("streets_us", 0) / 1000, c["cache"]["corners"],
                              c["lua_kib_delta"]))
        if data.get("streets"):
            st = data["streets"]
            streets.append("- %s %s: road layout %d bytes, module load %d us, deserialize %d us, "
                           "%d streets (%d points) of this capital, +%.0f KiB while the whole "
                           "layout is held, +%.0f KiB after it is dropped" % (
                               label(path), st["key"], st["text_bytes"], st["load_us"],
                               st["deserialize_us"], st["streets"], st["street_points"],
                               st["lua_kib_with_layout"], st["lua_kib_after_drop"]))
    print("# NV3 probe summary (seed 42)\n")
    print("| run | settlement | watched | searches | largest | nav searches | "
          "ambling/walkers/one-spot | arrivals / spots given up | patrol advances | "
          "snaps | cap waits | route cache |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for row in rows:
        print(row)
    if census:
        print("\n## Census (every leg of the settlement's walkers and patrols)\n")
        for line in census:
            print(line)
    if streets:
        print("\n## Street data\n")
        for line in streets:
            print(line)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
