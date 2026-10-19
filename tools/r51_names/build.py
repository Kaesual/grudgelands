#!/usr/bin/env python3
"""Round 51 lane NAMES: the water families' ladders and names.

    python3 tools/r51_names/build.py           # write draft.json, page.html, page_local.html
    python3 tools/r51_names/build.py --check   # exit 1 when draft.json or page.html is stale

Reads the hand-written design (design.json: families, tiers, names), the
zones' level bands (simple_map.lua zone records), their belts (the shipped
recipes data/zones/<zone>.spawns.json), the bays and channels
(simple_map.lua source.bays, source.channels), the water survey
(survey/seed_*.json, written by water_survey.lua) and today's names
(data/names.json, subtypes.json). A family's slot in a zone is one per belt
whose terrain shows the family's water on at least one surveyed seed:
levels = the belt's levels within the family's tier role (the role covering
the whole belt; T3 starts at 20 for the capitals' L20-23 belts), key
<zone>/<role>/L<lo>-<hi> as tools/r38_names/inventory.py keys recipe slots.

Writes:
  draft.json       per family the sub-type rows (subtypes.json shape plus
                   `habitats`), the world slots, and `slots` in the Round 38
                   proposal format (key -> name, reason, ...), so
                   tools/r38_b1/gen_names.py --proposals draft.json and
                   tools/r38_names/check_rules.py read it as it is
  page.html        the preview page, content only (the publisher wraps it)
  page_local.html  the same page wrapped for file:// (not committed)

The gates over the draft run in check_draft.py; build.py embeds their
summary in the page. Python 3 standard library only; deterministic output.
"""
import argparse
import glob
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))

MOBS = "mods/ENTITIES/grug_mobs"
SIMPLE_MAP = "mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"
RECIPES = MOBS + "/data/zones"
NAMES = MOBS + "/data/names.json"
SUBTYPES = MOBS + "/data/subtypes.json"
DESIGN = "tools/r51_names/design.json"
SURVEY = "tools/r51_names/survey"
DRAFT = HERE / "draft.json"
PAGE = HERE / "page.html"
PAGE_LOCAL = HERE / "page_local.html"
EXISTING_FAMILIES = ("crab", "crocodile")
PROD_SEED = "3464175725660475642"


def text(rel):
    return (REPO / rel).read_text(encoding="utf-8")


def line_of(rel, pattern):
    m = re.search(pattern, text(rel))
    if not m:
        raise SystemExit("build: %r not found in %s" % (pattern, rel))
    return "%s:%d" % (rel, text(rel).count("\n", 0, m.start()) + 1)


def drop_tier(level):
    return max(1, min(6, (int(level) - 1) // 10 + 1))


def load_zones():
    src = text(SIMPLE_MAP)
    pat = re.compile(r'zone\((\d+),"(\w+)","([^"]+)","(\w+)",(false|"\w+"),"(\w+)","(\w+)",'
                     r'(\d+),(\d+),"(\w+)",(-?\d+),(-?\d+),\{([^}]*)\}(,true)?\)')
    zones = []
    for m in pat.finditer(src):
        num, lo, hi = int(m.group(1)), int(m.group(8)), int(m.group(9))
        civic = bool(m.group(14))
        if civic:
            role = "capital"
        elif lo == 1:
            role = "start zone"
        elif m.group(6).endswith("_home"):
            role = "home zone"
        elif num in (33, 38):
            role = "dragon island"
        elif num >= 34:
            role = "battlegrounds"
        else:
            role = "contested"
        zones.append({
            "id": m.group(2), "num": num, "name": m.group(3), "race": m.group(4),
            "faction": m.group(5).strip('"') if m.group(5) != "false" else None,
            "continent": "Elandor" if num <= 16 else ("Kragmar" if num <= 32 else "Front"),
            "band": [lo, hi], "role": role, "biomes": re.findall(r'"(\w+)"', m.group(13)),
            "record": "%s:%d" % (SIMPLE_MAP, src.count("\n", 0, m.start()) + 1),
        })
    if len(zones) != 38:
        raise SystemExit("build: expected 38 zone records, got %d" % len(zones))
    return zones


def load_bays_channels(zones):
    src = text(SIMPLE_MAP)
    by_num = {z["num"]: z["id"] for z in zones}
    bays = []
    for m in re.finditer(r'\{id="(bay_\w+)",region="\w+",shore_zone_ids=\{([\d,]+)\}', src):
        bays.append({"id": m.group(1), "zones": [by_num[int(n)] for n in m.group(2).split(",")],
                     "where": "%s:%d" % (SIMPLE_MAP, src.count("\n", 0, m.start()) + 1)})
    islands = {}
    for m in re.finditer(r'\{id="(island_\w+)",region="\w+",zone_numeric_id=(\d+),polygon=polygon\(([^\n]*?)\)\}', src):
        xs = [int(x) for x in re.findall(r"point\((-?\d+),", m.group(3))]
        islands[m.group(1)] = (by_num[int(m.group(2))], sum(xs) / len(xs))
    channels = []
    for m in re.finditer(r'\{id="(channel_\w+)",polygon=polygon\(([^\n]*?)\),warning_width', src):
        xs = [int(x) for x in re.findall(r"point\((-?\d+),", m.group(2))]
        cx = sum(xs) / len(xs)
        island = min(islands.values(), key=lambda v: abs(v[1] - cx))[0]
        channels.append({"id": m.group(1), "zone": island,
                         "where": "%s:%d" % (SIMPLE_MAP, src.count("\n", 0, m.start()) + 1)})
    if len(bays) != 4 or len(channels) != 2:
        raise SystemExit("build: expected 4 bays and 2 channels in %s" % SIMPLE_MAP)
    return bays, channels


def load_survey():
    seeds = {}
    for path in sorted(glob.glob(str(REPO / SURVEY / "seed_*.json"))):
        doc = json.loads(Path(path).read_text(encoding="utf-8"))
        seeds[doc["seed"]] = doc
    if PROD_SEED not in seeds or len(seeds) < 2:
        raise SystemExit("build: run tools/r51_names/survey.sh first (no survey in %s)" % SURVEY)
    order = [PROD_SEED] + sorted(s for s in seeds if s != PROD_SEED)
    per = {}
    for seed in order:
        for z in seeds[seed]["zones"]:
            for b in z["belts"]:
                row = per.setdefault((z["zone"], b["id"]), {"shore": [], "bank": [], "swamp_bank": [], "land": []})
                for k in row:
                    row[k].append(b[k])
    return order, per, {s: [seeds[s]["world_seconds"], seeds[s]["regions_seconds"]] for s in order}


def belts_of(zone_id):
    rel = "%s/%s.spawns.json" % (RECIPES, zone_id)
    data = json.loads(text(rel))
    where = line_of(rel, r'"belts"')
    return [{"id": b["id"], "levels": list(b["levels"])} for b in data["recipe"]["belts"]], where


def role_for(roles, levels):
    """The family's role covering the whole belt, the highest tier first."""
    fits = [r for r in roles if r["levels"][0] <= levels[0] and levels[1] <= r["levels"][1]]
    if not fits:
        return None
    return max(fits, key=lambda r: r["levels"][0])


def habitats_in(family, belt_survey, zone_id, channels):
    found = []
    shore = any(belt_survey["shore"])
    bank = any(belt_survey["bank"])
    for h in family["habitats"]:
        if h == "shore" and shore:
            found.append("shore")
        elif h == "belt" and shore:
            found.append("belt")
        elif h == "freshwater" and bank:
            found.append("freshwater")
        elif h == "channel" and shore and any(c["zone"] == zone_id for c in channels):
            found.append("channel")
    return found


def build_model():
    design = json.loads(text(DESIGN))
    zones = load_zones()
    bays, channels = load_bays_channels(zones)
    seeds, survey, seconds = load_survey()
    names = json.loads(text(NAMES))["names"]
    subtypes = {s["role"]: s for s in json.loads(text(SUBTYPES))}
    tiers = design["tiers"]

    zone_rows = []
    for z in zones:
        belts, belts_where = belts_of(z["id"])
        for b in belts:
            b["survey"] = survey[(z["id"], b["id"])]
        zone_rows.append(dict(z, belts=belts, belts_where=belts_where,
                              bays=[b["id"] for b in bays if z["id"] in b["zones"]],
                              channels=[c["id"] for c in channels if c["zone"] == z["id"]],
                              sea=any(any(b["survey"]["shore"]) for b in belts),
                              fresh=any(any(b["survey"]["bank"]) for b in belts)))

    families, subtype_rows, slots = [], [], {}
    for fam in design["families"]:
        f = dict(fam)
        if fam.get("roles"):
            roles = []
            for r in fam["roles"]:
                lv = tiers[r["tier"]]
                roles.append(dict(r, levels=list(lv), where=line_of(DESIGN, r'"role": "%s"' % r["role"])))
            used = defaultdict(list)
            for z in zone_rows:
                for b in z["belts"]:
                    hab = habitats_in(fam, b["survey"], z["id"], channels)
                    if not hab:
                        continue
                    role = role_for(roles, b["levels"])
                    if role is None:
                        raise SystemExit("build: no %s role covers %s %s" % (fam["id"], z["id"], b["levels"]))
                    lo, hi = max(b["levels"][0], role["levels"][0]), min(b["levels"][1], role["levels"][1])
                    key = "%s/%s/L%d-%d" % (z["id"], role["role"], lo, hi)
                    slots[key] = {
                        "name": role["name"], "family": fam["id"], "role": role["role"], "base": fam["base"],
                        "tier": "normal", "drop_tier": "T%d" % drop_tier(lo), "disposition": fam["behaviour"],
                        "zone": z["id"], "belt": b["id"], "levels": [lo, hi], "habitats": hab,
                        "seeds": {"shore": b["survey"]["shore"], "freshwater": b["survey"]["bank"],
                                  "swamp_pools": b["survey"]["swamp_bank"]},
                        "reason": "Round 51 NAMES draft: %s %s (%s, L%d-%d), %s; zone belt %s" % (
                            fam["label"], role["tier"], role["name"], role["levels"][0], role["levels"][1],
                            " and ".join(design["habitats"][h]["label"].lower() for h in hab), b["id"]),
                    }
                    used[role["role"]].append(key)
            kept = []
            for r in roles:
                if not used[r["role"]]:
                    raise SystemExit("build: role %s has no slot; drop it from design.json" % r["role"])
                r["slots"] = sorted(used[r["role"]])
                kept.append(r)
                subtype_rows.append({
                    "role": r["role"], "family": fam["id"], "base": fam["base"], "display": r["name"],
                    "size": r["size"], "disposition": fam["behaviour"], "tier": "normal",
                    "levels": r["levels"], "drops": fam["id"],
                    "habitats": sorted({h for k in r["slots"] for h in slots[k]["habitats"]}),
                    "notes": "Round 51 NAMES draft, tier %s. Fish loot (S14): drops.json rows are the MOBS "
                             "lane's." % r["tier"]})
            f["roles"] = kept
        families.append(f)

    # Today's water slots of the families that stay (crab, crocodile).
    existing = []
    for key, name in sorted(names.items()):
        scope, source, band = key.split("/")
        sub = subtypes.get(source)
        if scope == "world" or not sub or sub["family"] not in EXISTING_FAMILIES:
            continue
        lo, hi = (int(x) for x in band[1:].split("-"))
        existing.append({"key": key, "name": name, "family": sub["family"], "role": source, "zone": scope,
                         "levels": [lo, hi], "tier": sub["tier"], "disposition": sub["disposition"],
                         "where": line_of(NAMES, re.escape('"%s"' % key))})

    world = []
    for w in design["world_slots"]:
        row = dict(w)
        if w["status"] == "existing":
            if names.get(w["key"]) != w["name"]:
                raise SystemExit("build: %s is %r in names.json, design says %r" % (w["key"], names.get(w["key"]), w["name"]))
            row["where"] = line_of(NAMES, re.escape('"%s"' % w["key"]))
        else:
            row["where"] = line_of(DESIGN, re.escape('"key": "%s"' % w["key"]))
        world.append(row)

    sources = {
        "zone_records": line_of(SIMPLE_MAP, r"source\.zones = \{"),
        "bays": line_of(SIMPLE_MAP, r"source\.bays = \{"),
        "channels": line_of(SIMPLE_MAP, r"source\.channels = \{"),
        "level_band": line_of(MOBS + "/subtypes.lua", r"function grug_mobs\.level_band"),
        "name_rules": line_of("docs/design/biomes_mobs.md", r"\*\*Names \(Round 38"),
        "kraken_level": line_of(MOBS + "/kraken.lua", r"_grug_fixed_level = 70"),
        "water_authority": line_of(MOBS + "/spawn_policy.lua", r"local INDEPENDENT_AUTHORITY = \{"),
        "terrain_types": line_of(MOBS + "/spawn_regions_core.lua", r"M\.SHORE_SHARE = "),
        "survey": SURVEY + "/seed_<seed>.json (tools/r51_names/water_survey.lua)",
        "design": DESIGN,
        "names": NAMES,
        "subtypes": SUBTYPES,
    }
    land_families = sorted({s["family"] for s in subtypes.values()})
    return {
        "design": design, "zones": zone_rows, "bays": bays, "channels": channels, "seeds": seeds,
        "survey_seconds": seconds, "families": families, "subtypes": subtype_rows,
        "slots": dict(sorted(slots.items())), "existing": existing, "world": world, "sources": sources,
        "land_family_count": len(land_families), "land_subtype_count": len(subtypes),
    }


def draft_doc(m):
    fams = {}
    for f in m["families"]:
        fams[f["id"]] = {k: f[k] for k in ("label", "status", "behaviour", "follows_ashore", "habitats", "base",
                                            "why") if k in f}
        fams[f["id"]]["source"] = f["source"]
    return {
        "notes": ("Round 51 lane NAMES: the draft the MOBS lane turns into data. `subtypes` are rows for "
                  "data/subtypes.json (plus `habitats`, the water bands a slot's kinds host); `world` are the "
                  "fixed-level world slots (names.json keys world/<entity>/L<n>-<n>); `slots` are the zone "
                  "slots in the Round 38 proposal format, so tools/r38_b1/gen_names.py --proposals "
                  "tools/r51_names/draft.json writes them into names.json once the recipes place the roles. "
                  "Written by tools/r51_names/build.py from design.json and the water survey."),
        "seeds": m["seeds"],
        "habitats": {k: v["label"] for k, v in m["design"]["habitats"].items()},
        "families": fams,
        "subtypes": m["subtypes"],
        "world": [{k: w[k] for k in ("key", "family", "entity", "name", "tier", "level", "habitats", "status")
                   if k in w} for w in m["world"]],
        "slots": m["slots"],
    }


def render_json(doc):
    return json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


def page_data(m, gates):
    keep_zone = ("id", "name", "num", "race", "faction", "continent", "band", "role", "record", "belts",
                 "belts_where", "bays", "channels", "sea", "fresh")
    counts = {
        "families_new": sum(1 for f in m["families"] if f["status"] == "new"),
        "families_kept": sum(1 for f in m["families"] if f["status"] == "existing"),
        "left_out": len(m["design"]["left_out"]),
        "new_slots": len(m["slots"]),
        "new_names": len({s["name"] for s in m["slots"].values()} |
                         {w["name"] for w in m["world"] if w["status"] == "new"}),
        "new_world": sum(1 for w in m["world"] if w["status"] == "new"),
        "subtypes": len(m["subtypes"]),
        "existing_slots": len(m["existing"]),
        "land_families": m["land_family_count"], "land_subtypes": m["land_subtype_count"],
    }
    return {
        "habitats": m["design"]["habitats"], "tiers": m["design"]["tiers"], "tier_note": m["design"]["tier_note"],
        "families": m["families"], "left_out": m["design"]["left_out"], "world": m["world"],
        "zones": [{k: z[k] for k in keep_zone} for z in m["zones"]],
        "slots": m["slots"], "existing": m["existing"], "seeds": m["seeds"],
        "survey_seconds": m["survey_seconds"], "sources": m["sources"], "counts": counts, "gates": gates,
    }


def render_page(data):
    css = (HERE / "page.css").read_text(encoding="utf-8")
    js = (HERE / "page.js").read_text(encoding="utf-8")
    blob = json.dumps(data, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    blob = blob.replace("</", "<\\/")
    return ("<title>Water Mob Names</title>\n<style>\n%s</style>\n"
            '<div id="app"><p class="loading">Loading the water families…</p></div>\n'
            '<script type="application/json" id="names-data">%s</script>\n'
            "<script>\n%s</script>\n" % (css, blob, js))


def wrap_local(page):
    return ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1">\n</head>\n<body>\n'
            "%s</body>\n</html>\n" % page)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 when draft.json or page.html is stale")
    args = ap.parse_args(argv)
    m = build_model()
    draft = render_json(draft_doc(m))
    import check_draft  # noqa: E402  (reads the draft built here)
    gates = check_draft.run(json.loads(draft))
    page = render_page(page_data(m, gates))
    if args.check:
        stale = [str(p) for p, new in ((DRAFT, draft), (PAGE, page))
                 if not p.exists() or p.read_text(encoding="utf-8") != new]
        if stale:
            print("build: stale %s (rerun tools/r51_names/build.py)" % ", ".join(stale))
            return 1
        print("build: draft.json and page.html are current (%d zone slots, %d sub-types)" % (
            len(m["slots"]), len(m["subtypes"])))
        return 0
    DRAFT.write_text(draft, encoding="utf-8")
    PAGE.write_text(page, encoding="utf-8")
    PAGE_LOCAL.write_text(wrap_local(page), encoding="utf-8")
    print("build: wrote %s (%d zone slots, %d sub-types, %d world slots), %s (%d KiB) and %s" % (
        DRAFT.name, len(m["slots"]), len(m["subtypes"]), len(m["world"]), PAGE.name,
        len(page.encode("utf-8")) // 1024, PAGE_LOCAL.name))
    print("gates: %s" % gates["summary"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
