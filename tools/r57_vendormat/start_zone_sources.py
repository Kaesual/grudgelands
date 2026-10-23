#!/usr/bin/env python3
"""Round 57 VENDORMAT: what a new character can still get without a vendor.

Reads grug_mobs' data (zones/*.spawns.json, subtypes.json, drops.json) and
prints, for each of the six start zones (recipe anchor "start"), the mobs of
the level 1-10 belts that drop Leather, Light Leather or Linen Scrap, with
their drop chance (1 in N). Then the T1 band of copper and tin from
grug_mapgen's resource table (wp40/r6_content.lua RESOURCE_EXPECTED).
Exit status 1 when a start zone has no source of one of the three items.

Usage: python3 tools/r57_vendormat/start_zone_sources.py
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "mods", "ENTITIES", "grug_mobs", "data")
ITEMS = ("mobs:leather", "grug_mobs:light_leather", "grug_mobs:linen_scrap")


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as handle:
        return json.load(handle)


def band_of(level):
    # Bracket b covers levels 10*(b-1)+1 .. 10*b (grug_gear.BRACKETS).
    return str((level - 1) // 10 + 1)


def main():
    roles = {row["role"]: row for row in load("subtypes.json")}
    drops = {row["family"]: row for row in load("drops.json")}
    missing = []
    for path in sorted(glob.glob(os.path.join(DATA, "zones", "*.spawns.json"))):
        zone = json.load(open(path, encoding="utf-8"))
        recipe = zone.get("recipe", {})
        if recipe.get("from", {}).get("anchor") != "start":
            continue
        found = {item: {} for item in ITEMS}
        for belt in recipe.get("belts", []):
            low, high = belt["levels"]
            if low > 10:
                continue
            kinds = belt.get("kinds", {})
            for kind in kinds.values():
                for slot in ("day", "night"):
                    entries = kind.get(slot, [])
                    if isinstance(entries, str):  # "open": that kind's list
                        entries = kinds.get(entries, {}).get(slot, [])
                    for entry in entries:
                        role = roles.get(entry["role"])
                        if not role:
                            continue
                        table = drops.get(role.get("drops") or role["family"], {})
                        for level in range(low, min(high, 10) + 1):
                            for row in table.get("bands", {}).get(band_of(level), []):
                                if row["item"] in found:
                                    key = "%s (%s, L%d-%d)" % (role["display"],
                                        entry["role"], low, min(high, 10))
                                    found[row["item"]][key] = row["chance"]
        print(zone["zone"])
        for item in ITEMS:
            rows = found[item]
            if not rows:
                missing.append((zone["zone"], item))
            text = ", ".join("%s 1/%d" % (k, v) for k, v in sorted(rows.items()))
            print("  %-24s %s" % (item, text or "NONE"))
    content = open(os.path.join(ROOT, "mods", "MAPGEN", "grug_mapgen", "wp40",
        "r6_content.lua"), encoding="utf-8").read()
    for key in ("copper", "tin"):
        match = re.search(r"\b%s = \{(\d+), (\d+), \{([^}]*)\}" % key, content)
        print("%s: first tier %s, vein cap %s, denominators per tier %s" %
            (key, match.group(1), match.group(2), match.group(3)) if match else
            "%s: NOT FOUND" % key)
        if not match or match.group(1) != "1":
            missing.append(("mapgen", key))
    if missing:
        print("MISSING:", missing)
        return 1
    print("RESULT PASS: every start zone has all three drops at levels 1-10; "
        "copper and tin start in T1 rock")
    return 0


if __name__ == "__main__":
    sys.exit(main())
