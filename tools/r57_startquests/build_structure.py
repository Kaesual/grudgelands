#!/usr/bin/env python3
"""Round 57 lane STARTQUESTS: write the six start zones' quest structure.

The six start-zone quest files (levels 1-10) are rebuilt on the Round 57
quest foundation (docs/design/quests.md "The start zones"): nine shared quests
with one variant per start zone that offers them, and four local quests per
zone (two hunts with the armor choices, the zone's finale with the weapon
choice, and its `*_departure` handover). Every file is marked
`"reworked": true`.

This script wrote the structure once, with placeholder texts ("[PH] ...").
After lane STARTTEXT has written the real texts the JSON files are the
source: rerunning the script overwrites every text with its placeholder
(it keeps the hubs, the identity line and the six departure quests as they
are in the files). Run from the repository root:

    python3 tools/r57_startquests/build_structure.py [--check]

--check exits 1 when the files differ from what the script would write.
Python 3 standard library only.
"""
import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"

# Zone order is the variant order: a shared quest lives in its first
# variant's file (quests.md "Shared quests").
ZONES = [
    # zone id, town short name, race, the home (level 1-2) kind, the zone's
    # mob names the placeholder texts quote
    ("elandor_dawnmere_fields", "dawnmere", "human"),
    ("elandor_hearthpine_vale", "hearthpine", "dwarf"),
    ("elandor_silverleaf_glades", "silverleaf", "elf"),
    ("kragmar_sunscar_flats", "sunscar", "orc"),
    ("kragmar_kapok_cradle", "kapok", "troll"),
    ("kragmar_stillgrave_hollow", "stillgrave", "undead"),
]
ELDER = {town: "r14_%s_elder" % race for _, town, race in ZONES}
COOK = {town: "r20_%s_start_cook" % race for _, town, race in ZONES}
ZONE_OF = {town: zone for zone, town, _ in ZONES}

PH = "[PH] "
# A placeholder text's second sentence (the texts are two to four sentences).
TBD = " Real text to follow."

HEALING = "grug_alchemy:potion_healing_t1"
MANA = "grug_alchemy:potion_mana_t1"


def kill(roles, count, area=None):
    row = {"type": "kill", "roles": list(roles), "count": count}
    if area:
        row["area"] = area
    return row


def item(name, count, roles=None, area=None, group=False):
    row = {"type": "item", ("group" if group else "item"): name, "count": count}
    if roles:
        row["roles"] = list(roles)
    if area:
        row["area"] = area
    return row


def armor(slot, affix):
    """A choice of one armor piece per armor class (cloth, leather, metal),
    each with one author-fixed enchant: `affix` maps the class to
    (channel, stat)."""
    items = {"cloth": "grug_gear:%s_cloth_patch" % slot,
             "leather": "grug_gear:%s_leather_light" % slot,
             "metal": "grug_gear:%s_metal_bronze" % slot}
    return [{"item": items[c], "affixes": [{"channel": affix[c][0], "stat": affix[c][1]}]}
            for c in ("cloth", "leather", "metal")]


# The level-5 piece: the class's main stat as a prefix; the level-7/8 piece:
# a second stat as a suffix (enchant pools: grug_quality POOLS).
EARLY = {"cloth": ("prefix", "int"), "leather": ("prefix", "dex"), "metal": ("prefix", "str")}
LATE = {"cloth": ("suffix", "max_mana_percent"), "leather": ("suffix", "crit_percent"),
        "metal": ("suffix", "max_hp_percent")}


def weapons(melee):
    """The finale's choice: one weapon per weapon line (caster, scout,
    warrior; Priest and Mage share), prefix and suffix each. A zone with the
    two-handed Battle Axe offers the two-handed Staff, a zone with the Sword
    the Wand (for the spellbook)."""
    caster = "grug_gear:staff_bronze" if melee == "greataxe" else "grug_gear:wand_bronze"
    warrior = {"sword": ("grug_gear:sword_bronze", "crit_percent"),
               "greataxe": ("grug_gear:greataxe_bronze", "max_hp_percent")}[melee]
    return [
        {"item": caster, "affixes": [{"channel": "prefix", "stat": "int"},
                                     {"channel": "suffix", "stat": "max_mana_percent"}]},
        {"item": "grug_gear:bow_bronze", "affixes": [{"channel": "prefix", "stat": "dex"},
                                                     {"channel": "suffix", "stat": "attack_speed_percent"}]},
        {"item": warrior[0], "affixes": [{"channel": "prefix", "stat": "str"},
                                         {"channel": "suffix", "stat": warrior[1]}]},
    ]


# ---------------------------------------------------------------- shared
# Each shared quest: its fields, and per town that offers it the variant's
# zone-bound objective fields and its placeholder text. The base objectives
# are the first variant's.
SHARED = [
    {
        "id": "start_boars", "giver": "elder", "line": "hunt", "min_level": 1, "level": 2,
        "title": "Piglets in the Fields",
        "objectives": lambda v: [kill(["small_boar"], 8, v["area"])],
        "rewards": {"weight": 3, "choices": [{"item": HEALING, "count": 2}, {"item": MANA, "count": 2}]},
        "lesson": "First hunt by day, offered at once with the night's rats; the early potion choice.",
        "duration_min": 8,
        "text": "Hunt 8 {mob} by day in the {{name:{area}}}.",
        "towns": {
            "dawnmere": {"area": "home_fields", "mob": "Barley Piglets"},
            "hearthpine": {"area": "timberline", "mob": "Pine Piglets"},
            "silverleaf": {"area": "home_glades", "mob": "Glade Piglets"},
            "sunscar": {"area": "wellfields", "mob": "Scrub Piglets"},
            "kapok": {"area": "yam_beds", "mob": "Yam Piglets"},
            "stillgrave": {"area": "dead_furrows", "mob": "Barrow Piglets"},
        },
    },
    {
        "id": "start_rats", "giver": "cook", "line": "pantry", "min_level": 1, "level": 2,
        "title": "Rats in the Grain Sacks",
        "objectives": lambda v: [kill(["large_rat"], 3, v["area"]),
                                 item("grug_mobs:rat_fur_patch", 1, ["large_rat"], v["area"])],
        "rewards": {"weight": 2},
        "lesson": "Night target at a third of the day count (one night suffices); ordinary loot has uses.",
        "duration_min": 6,
        "text": "Kill 3 {mob} after dark in the {{name:{area}}} and bring me 1 Rat Fur Patch.",
        "towns": {
            # Dawnmere's rats: the meadows (its home fields' rats bear the
            # same name, Barn Rat, and count too).
            "dawnmere": {"area": "meadows", "mob": "Barn Rats"},
            "hearthpine": {"area": "timberline", "mob": "Timber Rats"},
            "silverleaf": {"area": "home_glades", "mob": "Fern Rats"},
            "sunscar": {"area": "wellfields", "mob": "Dust Rats"},
            "kapok": {"area": "yam_beds", "mob": "Moss Rats"},
            "stillgrave": {"area": "dead_furrows", "mob": "Grave Rats"},
        },
    },
    {
        "id": "start_stone", "giver": "elder", "line": "tools", "min_level": 1, "level": 2,
        "title": "Stone for the Wall",
        "objectives": lambda v: [item("stone", 10, group=True)],
        "rewards": {"weight": 2, "items": [{"item": "grug_materials:pick_stone", "count": 1},
                                           {"item": "grug_materials:axe_stone", "count": 1}]},
        "lesson": "Craft a Wooden Pickaxe to dig stone; the reward is the next tools, never the request.",
        "duration_min": 6,
        "text": "Make a Wooden Pickaxe, dig 10 stone of any kind outside town and bring it to me.",
    },
    {
        "id": "start_fuel", "giver": "cook", "line": "kitchen", "min_level": 1, "level": 2,
        "title": "Fuel for the Oven",
        "objectives": lambda v: [item("tree", 5, group=True), item("default:coal_lump", 5)],
        "rewards": {"weight": 2.5},
        "lesson": "Any log counts, coal from the rock; town plants are protected.",
        "duration_min": 8,
        "text": "Bring me 5 logs of any tree and 5 Coal Lumps from the rock outside town.",
    },
    {
        "id": "start_dead", "giver": "elder", "line": "hunt", "min_level": 3, "level": 4,
        "title": "The Restless Dead",
        "objectives": lambda v: [kill([v["role"]], 3, v["area"])],
        "rewards": {"weight": 1.5},
        "lesson": "A night target at a third of the day count.",
        "duration_min": 5,
        "text": "Lay 3 {mob} to rest in the {{name:{area}}}{when}.",
        "towns": {
            "hearthpine": {"role": "braindead_zombie", "area": "shingle", "mob": "Pit Shufflers",
                           "when": " after dark"},
            "silverleaf": {"role": "braindead_zombie", "area": "strand", "mob": "Dune Stumblers",
                           "when": " after dark"},
            "sunscar": {"role": "befuddled_husk", "area": "strand", "mob": "Sun-Dried Husks",
                        "when": " after dark"},
            "kapok": {"role": "braindead_zombie", "area": "rootways", "mob": "Root Shufflers",
                      "when": " after dark"},
            "stillgrave": {"role": "braindead_zombie", "area": "ashfields", "mob": "Nameless Shufflers",
                           "when": ""},
        },
    },
    {
        "id": "start_crabs", "giver": "cook", "line": "pantry", "min_level": 4, "level": 5,
        "title": "Crab Legs for Supper",
        "objectives": lambda v: [item("grug_mobs:crab_leg", 2, v["roles"], v["area"])],
        "rewards": {"weight": 2},
        "lesson": "Shore loot by day; keep what your enchants need.",
        "duration_min": 6,
        "text": "Bring me 2 Crab Legs from the {mob} in the {{name:{area}}}.",
        "towns": {
            "hearthpine": {"roles": ["quiet_shore_crab", "giant_crab"], "area": "rockpools",
                           "mob": "Pebble Crabs and Boulder Crabs"},
            "silverleaf": {"roles": ["quiet_shore_crab"], "area": "strand", "mob": "Sand Fiddlers"},
            "sunscar": {"roles": ["quiet_shore_crab", "giant_crab"], "area": "saltflats",
                        "mob": "Fiddler Crabs and Sand Snappers"},
            "kapok": {"roles": ["quiet_shore_crab"], "area": "shallows", "mob": "Fiddler Crabs"},
            "stillgrave": {"roles": ["quiet_shore_crab", "giant_crab"], "area": "saltbones",
                           "mob": "Ghost Crabs and Bone Snappers"},
        },
    },
    {
        "id": "start_meat", "giver": "cook", "line": "kitchen", "min_level": 4, "level": 5,
        "title": "The Smokehouse Share",
        "objectives": lambda v: [item("mobs:meat_raw", 10)],
        "rewards": {"weight": 2, "items": [{"item": "mobs:meat", "count": 3}]},
        "lesson": "Hunt loot is useful; raw food cooks in the oven.",
        "duration_min": 4,
        "text": "Bring me 10 Raw Meat from your hunts; I cook a share for you.",
    },
    {
        "id": "start_bars", "giver": "elder", "line": "tools", "min_level": 5, "level": 6,
        "title": "Metal for the Mending",
        "objectives": lambda v: [item("grug_materials:copper_bar", 3), item("grug_materials:tin_bar", 3)],
        "rewards": {"weight": 2, "items": [{"item": "grug_smelting:dual_furnace", "count": 1}]},
        "lesson": "Ore to bar in a Furnace; the Dual Furnace makes the first alloy.",
        "duration_min": 10,
        "text": "Smelt 3 Copper Bars and 3 Tin Bars and bring them to me; you get a Dual Furnace.",
    },
    {
        "id": "start_bronze", "giver": "elder", "line": "tools", "min_level": 7, "level": 8,
        "title": "Bronze for the Road",
        "objectives": lambda v: [item("grug_materials:bronze_bar", 3)],
        "rewards": {"weight": 2, "items": [{"item": "grug_materials:pick_bronze", "count": 1}]},
        "lesson": "Alloys in the Dual Furnace; the Bronze Pickaxe digs Iron.",
        "duration_min": 12,
        "text": "Make 3 Bronze Bars in a Dual Furnace and bring them to me; you get a Bronze Pickaxe.",
    },
]
ALL_TOWNS = {town: {} for _, town, _ in ZONES}

# ---------------------------------------------------------------- local
# Per town: the level-5 hunt (armor, one enchant), the level-7/8 hunt
# (another slot, one enchant), the finale (a weapon with prefix and suffix)
# and the departure (kept as shipped, `requires` the finale). Ids of quests
# whose objectives did not change are kept (the finales `*_hunt_05` and a
# few hunts), every other quest has a new id.
LOCAL = {
    "dawnmere": {
        "mid": {"id": "dawnmere_hunt_03", "title": "Henthieves in the Pastures", "min_level": 4, "level": 5,
                "objectives": [kill(["small_fox"], 8, "pastures")], "weight": 3, "slot": "chest",
                "text": "Hunt 8 Henthieves by day in the {name:pastures}."},
        "late": {"id": "dawnmere_hunt_04", "title": "Snappers on the Wreck Coast", "min_level": 7, "level": 8,
                 "objectives": [kill(["giant_crab"], 5, "wreck_coast")], "weight": 2.5, "slot": "legs",
                 "text": "Kill 5 Wreck Snappers by day on the {name:wreck_coast}."},
        # Dawnmere has no undead and no low shore kind for the shared crab
        # legs: its cook keeps her own shore-and-pasture errand (objectives
        # as shipped, so the id stays).
        "extra": [{"id": "dawnmere_pantry_02", "line": "pantry", "giver": "cook",
                   "title": "A Brush and a Better Supper", "min_level": 7, "level": 8,
                   "objectives": [item("grug_mobs:crab_leg", 2, ["giant_crab"], "wreck_coast"),
                                  item("grug_mobs:fox_tail", 1, ["small_fox"], "pastures")],
                   "weight": 2, "lesson": "Keep what your enchants need, hand in what they do not.",
                   "duration_min": 7,
                   "text": "Bring me 2 Crab Legs from the Wreck Snappers on the {name:wreck_coast} and "
                           "1 Fox Tail from the Henthieves in the {name:pastures}."}],
        "final": {"id": "dawnmere_hunt_05", "melee": "sword", "chief": "confused_bandit_chief",
                  "camp": "bandit_camp", "weight": 4,
                  "text": "Defeat 7 Grain Pilferers at the {name:bandit_camp}, then {name:confused_bandit_chief}."},
    },
    "hearthpine": {
        "mid": {"id": "hearthpine_hunt_04", "title": "Ibex on the High Pines", "min_level": 4, "level": 5,
                "objectives": [kill(["young_ibex"], 8, "high_pines")], "weight": 3, "slot": "head",
                "text": "Hunt 8 Ibex Kids by day in the {name:high_pines}."},
        "late": {"id": "hearthpine_boulder_crabs", "title": "Boulder Crabs", "min_level": 7, "level": 8,
                 "objectives": [kill(["giant_crab"], 5, "rockpools")], "weight": 2.5, "slot": "feet",
                 "text": "Kill 5 Boulder Crabs by day in the {name:rockpools}."},
        "final": {"id": "hearthpine_hunt_05", "melee": "greataxe", "chief": "muddled_ore_chief",
                  "camp": "ore_thief_camp", "weight": 4.5,
                  "text": "Defeat 7 Ore Thieves at the {name:ore_thief_camp}, then {name:muddled_ore_chief}."},
    },
    "silverleaf": {
        "mid": {"id": "silverleaf_hunt_04", "title": "Russet Kits in the Seedbeds", "min_level": 4, "level": 5,
                "objectives": [kill(["small_fox"], 8, "foxglades")], "weight": 3, "slot": "feet",
                "text": "Hunt 8 Russet Kits by day in the {name:foxglades}."},
        "late": {"id": "silverleaf_grunters", "title": "Acorn Grunters", "min_level": 6, "level": 7,
                 "objectives": [kill(["aggressive_boar"], 5, "foxglades")], "weight": 2.5, "slot": "head",
                 "text": "Kill 5 Acorn Grunters by day in the {name:foxglades}."},
        "final": {"id": "silverleaf_hunt_05", "melee": "sword", "chief": "misguided_poacher_chief",
                  "camp": "poacher_camp", "weight": 5,
                  "text": "Defeat 7 Fern Poachers or Wood Thieves at the {name:poacher_camp}, then "
                          "{name:misguided_poacher_chief}."},
    },
    "sunscar": {
        "mid": {"id": "sunscar_hunt_03", "title": "Dustrunners on the Plains", "min_level": 4, "level": 5,
                "objectives": [kill(["young_plains_runner"], 8, "runner_plains")], "weight": 3, "slot": "chest",
                "text": "Hunt 8 Dustrunners by day on the {name:runner_plains}."},
        "late": {"id": "sunscar_scorpions", "title": "Rock Scorpions", "min_level": 6, "level": 7,
                 "objectives": [kill(["irritable_scorpion"], 6, "runner_plains")], "weight": 3, "slot": "legs",
                 "text": "Kill 6 Rock Scorpions by day on the {name:runner_plains}."},
        "final": {"id": "sunscar_hunt_05", "melee": "greataxe", "chief": "water_thief_chief",
                  "camp": "thieves_camp", "weight": 4.5,
                  "text": "Defeat 6 Water Thieves at the {name:thieves_camp}, then {name:water_thief_chief}."},
    },
    "kapok": {
        "mid": {"id": "kapok_tapirs", "title": "Tapir Calves in the Broadleaf", "min_level": 4, "level": 5,
                "objectives": [kill(["young_tapir"], 8, "broadleaf_wood")], "weight": 3, "slot": "head",
                "text": "Hunt 8 Tapir Calves by day in the {name:broadleaf_wood}."},
        "late": {"id": "kapok_hunt_04", "title": "Bushpigs in the Thornwood", "min_level": 7, "level": 8,
                 "objectives": [kill(["aggressive_boar"], 8, "thornwood")], "weight": 3.5, "slot": "feet",
                 "text": "Hunt 8 Bushpigs by day in the {name:thornwood}."},
        "final": {"id": "kapok_hunt_05", "melee": "sword", "chief": "offering_thief_chief",
                  "camp": "thieves_camp", "weight": 4.5,
                  "text": "Defeat 6 Offering Thieves at the {name:thieves_camp}, then {name:offering_thief_chief}."},
    },
    "stillgrave": {
        "mid": {"id": "stillgrave_fawns", "title": "Gaunt Fawns on the Moor", "min_level": 4, "level": 5,
                "objectives": [kill(["young_gaunt_stag"], 8, "blightmoor")], "weight": 3, "slot": "legs",
                "text": "Hunt 8 Gaunt Fawns by day on the {name:blightmoor}."},
        "late": {"id": "stillgrave_plague_boars", "title": "Plague Boars", "min_level": 6, "level": 7,
                 "objectives": [kill(["aggressive_boar"], 6, "blightmoor")], "weight": 3, "slot": "chest",
                 "text": "Kill 6 Plague Boars by day on the {name:blightmoor}."},
        "final": {"id": "stillgrave_hunt_05", "melee": "greataxe", "chief": "grave_robber_chief",
                  "camp": "robbers_camp", "weight": 4.5,
                  "text": "Defeat 6 Grave Robbers at the {name:robbers_camp}, then {name:grave_robber_chief}."},
    },
}


def shared_quests():
    """{zone: [quest]} for the shared quests, each in its first variant's file."""
    out = {}
    for spec in SHARED:
        towns = spec.get("towns") or ALL_TOWNS
        order = [t for _, t, _ in ZONES if t in towns]
        first = towns[order[0]]
        base_objectives = spec["objectives"](first)
        variants = []
        for town in order:
            fields = towns[town]
            row = {"zone": ZONE_OF[town],
                   "givers": [ELDER[town] if spec["giver"] == "elder" else COOK[town]]}
            if town != order[0]:
                own = spec["objectives"](fields)
                diff = []
                for base, mine in zip(base_objectives, own):
                    diff.append({k: mine[k] for k in ("roles", "area") if k in mine and mine.get(k) != base.get(k)})
                if any(diff):
                    row["objectives"] = diff
                row["text"] = PH + spec["text"].format(**fields) + TBD
            variants.append(row)
        quest = {
            "id": spec["id"],
            "line": spec["line"],
            "min_level": spec["min_level"],
            "level": spec["level"],
            "requires": [],
            "title": PH + spec["title"],
            "text": PH + spec["text"].format(**first) + TBD,
            "objectives": base_objectives,
            "variants": variants,
            "rewards": spec["rewards"],
            "lesson": spec["lesson"],
            "duration_min": spec["duration_min"],
        }
        out.setdefault(ZONE_OF[order[0]], []).append(quest)
    return out


def local_quests(town, departure):
    spec, elder = LOCAL[town], ELDER[town]
    rows = []
    for key, affix in (("mid", EARLY), ("late", LATE)):
        q = spec[key]
        rows.append({
            "id": q["id"], "line": "hunt", "giver": elder, "turnin": elder,
            "min_level": q["min_level"], "level": q["level"], "requires": [],
            "title": PH + q["title"], "text": PH + q["text"] + TBD,
            "objectives": q["objectives"],
            "rewards": {"weight": q["weight"], "choices": armor(q["slot"], affix)},
            "lesson": "A local hunt; the %s armor choice (one enchant, item level %d)." % (q["slot"], q["level"]),
            "duration_min": 9 if key == "mid" else 12,
        })
    for q in spec.get("extra", []):
        npc = elder if q["giver"] == "elder" else COOK[town]
        rows.append({
            "id": q["id"], "line": q["line"], "giver": npc, "turnin": npc,
            "min_level": q["min_level"], "level": q["level"], "requires": [],
            "title": PH + q["title"], "text": PH + q["text"] + TBD,
            "objectives": q["objectives"], "rewards": {"weight": q["weight"]},
            "lesson": q["lesson"], "duration_min": q["duration_min"],
        })
    f = spec["final"]
    camp_count = {"dawnmere": 7, "hearthpine": 7, "silverleaf": 7}.get(town, 6)
    camp_roles = ["furtive_poacher", "confused_bandit"] if town == "silverleaf" else ["confused_bandit"]
    rows.append({
        "id": f["id"], "line": "hunt", "giver": elder, "turnin": elder,
        "min_level": 8, "level": 9, "requires": [],
        "title": PH + "The Finale: {name:%s}" % f["chief"],
        "text": PH + f["text"] + TBD,
        "completion": PH + "The town's own story is closed; the weapon is the zone's reward." + TBD,
        "objectives": [kill(camp_roles, camp_count, "%s/%s" % (ZONE_OF[town], f["camp"])),
                       kill([f["chief"]], 1)],
        "rewards": {"weight": f["weight"], "choices": weapons(f["melee"])},
        "lesson": "A camp pack plus a named leader; the weapon choice (prefix and suffix).",
        "duration_min": 12,
        "climax": True,
    })
    departure = dict(departure)
    departure["requires"] = [f["id"]]
    rows.append(departure)
    return rows


def full_area(zone, quest):
    """Areas in the files are written zone-qualified, as the shipped files do."""
    def fix(row, own_zone):
        if row.get("area") and "/" not in row["area"]:
            row["area"] = "%s/%s" % (own_zone, row["area"])
    for row in quest.get("objectives") or []:
        fix(row, zone)
    for variant in quest.get("variants") or []:
        for row in variant.get("objectives") or []:
            fix(row, variant["zone"])
    return quest


def build():
    shared = shared_quests()
    files = {}
    for zone, town, _ in ZONES:
        path = QUESTS / ("%s.quests.json" % zone)
        data = json.loads(path.read_text())
        departure = next(q for q in data["quests"] if q["id"] == "%s_departure" % town)
        quests = [full_area(zone, q) for q in shared.get(zone, [])]
        quests += [full_area(zone, q) for q in local_quests(town, departure)]
        out = {"zone": data["zone"], "reworked": True, "identity": data["identity"],
               "hubs": data["hubs"], "quests": quests}
        files[path] = json.dumps(out, indent=2, ensure_ascii=False) + "\n"
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    files = build()
    differ = [p for p, text in files.items() if p.read_text() != text]
    if args.check:
        for p in differ:
            print("differs: %s" % p.relative_to(REPO))
        return 1 if differ else 0
    for p, text in files.items():
        p.write_text(text)
    print("build_structure: wrote %d files (%d changed)" % (len(files), len(differ)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
