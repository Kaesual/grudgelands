#!/usr/bin/env python3
"""Round 33 lane DS: where each mob loot item can be farmed.

For every (drop family, band) the zones whose spawn recipe places a sub-type
of that family at that band (belts, camps and leaders; the band is the
sub-type's own level range clipped to the belt), split by faction: `elandor_`
zones are The Accord's, `kragmar_` The Throng's, `front_` shared. A rough
share sums each belt's day/night weights (Round 28 recipe format), a camp
counts CAMP and a unique leader LEADER per zone (camps hold six slots on a
30-60 s respawn; leaders are one mob on 300 s). Rough figures for picking
recipe inputs, not a spawn simulation.

Grades: "one faction" when only one faction's zones (no front zone) place
it, "none" without any placed source, else by drops per weighted spawn
(share / chance): common >= 0.15, regular >= 0.05, scarce below.

Usage: availability.py [--items]   (--items: one line per catalogue item)
"""
import glob
import sys
from collections import defaultdict

import common as C

CAMP = 0.05
LEADER = 0.005


def band_of(level):
    return max(1, min(6, (int(level) - 1) // 10 + 1))


def presence():
    subs = {row["role"]: row for row in C.load_json(C.MOBS / "subtypes.json")}
    zones = defaultdict(set)      # (family, band) -> zones
    share = defaultdict(float)    # (family, band) -> rough weight
    for path in sorted(glob.glob(str(C.MOBS / "zones" / "*.spawns.json"))):
        data = C.load_json(path)
        zone, recipe = data["zone"], data["recipe"]
        belts = {belt["id"]: belt for belt in recipe.get("belts", [])}

        def place(role, lo, hi, weight=0.0):
            sub = subs.get(role)
            if not sub:
                return
            family = sub.get("drops") or sub["family"]
            a, b = max(lo, sub["levels"][0]), min(hi, sub["levels"][1])
            if a > b:
                a, b = sub["levels"]
            for band in {band_of(a), band_of(b)}:
                zones[(family, band)].add(zone)
                share[(family, band)] += weight

        for belt in recipe.get("belts", []):
            lo, hi = belt["levels"]
            kinds = belt["kinds"]
            for kind in kinds.values():
                for clock in ("day", "night"):
                    rows = kind.get(clock)
                    if isinstance(rows, str):
                        rows = kind.get(rows)
                    if not isinstance(rows, list):
                        continue
                    total = float(sum(r["weight"] for r in rows)) or 1.0
                    for r in rows:
                        place(r["role"], lo, hi, belt["share"] / 100.0 * r["weight"] / total
                              / (2 * len(kinds)))
        for camp in recipe.get("camps", []):
            belt = belts.get(camp.get("belt"))
            lo, hi = belt["levels"] if belt else (1, 60)
            total = float(sum(r["weight"] for r in camp.get("roster", []))) or 1.0
            for r in camp.get("roster", []):
                place(r["role"], lo, hi, CAMP * r["weight"] / total)
        for leader in recipe.get("leaders", []):
            sub = subs.get(leader["role"])
            if sub:
                place(leader["role"], sub["levels"][0], sub["levels"][1], LEADER)
    return zones, share


def faction_split(zone_set):
    out = {"accord": 0, "throng": 0, "front": 0}
    for zone in zone_set:
        if zone.startswith("elandor_"):
            out["accord"] += 1
        elif zone.startswith("kragmar_"):
            out["throng"] += 1
        else:
            out["front"] += 1
    return out


def item_availability():
    """item -> {'sources': [...], 'accord', 'throng', 'front', 'share', 'grade'}"""
    zones, share = presence()
    items = C.mob_items()
    sources = C.drop_sources()
    out = {}
    for item_id in items:
        zset, weight, srcs = set(), 0.0, []
        for family, band, chance in sources.get(item_id, []):
            srcs.append("%s/%s 1:%s" % (family, band, chance))
            if band == "leader":
                continue
            zset |= zones.get((family, band), set())
            weight += share.get((family, band), 0.0) / float(chance)
        split = faction_split(zset)
        both = (split["accord"] and split["throng"]) or split["front"]
        count = len(zset)
        if not count:
            grade = "none"
        elif not both:
            grade = "one faction"
        elif weight >= 0.15:
            grade = "common"
        elif weight >= 0.05:
            grade = "regular"
        else:
            grade = "scarce"
        out[item_id] = dict(split, zones=count, share=weight, grade=grade, sources=srcs)
    return out


def main(argv):
    avail = item_availability()
    items = C.mob_items()
    print("| Tier | Item | Kind | Sources | Zones A/T/F | Rough share | Grade |")
    print("|---:|---|---|---|---|---:|---|")
    for item_id, row in sorted(items.items(), key=lambda kv: (kv[1]["tier"], kv[1]["family"], kv[0])):
        a = avail[item_id]
        print("| %d | %s | %s | %s | %d/%d/%d | %.2f | %s |" % (
            row["tier"], row["name"], row["kind"], "; ".join(a["sources"][:4]),
            a["accord"], a["throng"], a["front"], a["share"], a["grade"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
