#!/usr/bin/env python3
"""Round 60 lane BANDQUESTS: write the band 21-30's quest structure.

The eight band zones' quest files (Frostbarrow Shelf, Whitebridge Shire,
Lorindor, Moonfall Wood of The Accord; Ossuary Reach, Speargrass Reach,
Whispering Reedlands, Totemwater Reach of The Throng) are rebuilt on the
Round 57 quest foundation (docs/design/quests.md "The band 21-30"), from the
story chapter the user picked (round60-plan.md §2a point 6; every
recommendation K1-K13 "A", with the feasibility check's fixes):

- the shared tasks (one quest, one level, a variant per zone): the steel
  help at the six mines (`band_steel`, K5 A: Zali's too), the shore hunt
  (`band_shore_pinchers`: Hedra, Orya, Lethen, Tokai), the snare ground
  (`band_snares`: Lorindor, Moonfall), the corn (`band_corn`: Whitebridge,
  Speargrass), the planks (`band_planks`: Moonfall, Totemwater) and the fish
  (`band_mire_carp`: Totemwater and Varda in Dur Brannoc);
- the zones' own tasks: the first errand (the potion choice), a use at a
  new place or a hunt (the first armor piece, a prefix), a later errand (the
  second armor piece, a suffix), the named leader (the weapon, prefix and
  suffix), the travels and departures (ids kept, requiring nothing);
- chapter 2's band steps: A3 `story_accord_03` (Brodd Deeppeg, the held
  load in the Frostbarrow mining camp, to Kelda), A4 `story_accord_04`
  (Kelda to Hadrin Beamset; requires A3 and Nib's `frostbarrow_cutting_04`)
  and T2a `story_throng_03` (Rellis Shalemark, the claim rest in the
  Barrowlands, to Mereth); `ossuary_rubbings_03` keeps its id for T3
  (lane CAPITALS) and gains Rellis as a second giver;
- the Round 58 guild content as shipped (`guild_t3_report_*`,
  `camp_hunt_t3`, `camp_hunt_t3_night`).

Every file is marked `"reworked": true`: free quests require only a level,
only story quests chain.

This script wrote the structure once with placeholder texts ("[PH] ...";
each names the draft's intent for the text lane); the texts are lane
BANDTEXT's, and once they land the JSON files are their source: rerunning
it without --check writes the placeholders back. Run from the repository
root:

    python3 tools/r60_bandquests/build_structure.py [--check]

--check exits 1 when the files' structure differs from what the script
would write: everything but the texts (titles, texts, completions, a
variant's text and completion), so it holds once the real texts are in.
Python 3 standard library only.
"""
import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"

PH = "[PH] "
TBD = " Real text to follow."

# Zone order is the variant order: a shared quest lives in its first
# variant's file (quests.md "Shared quests").
ZONES = [
    # zone id, short name
    ("elandor_frostbarrow_shelf", "frostbarrow"),
    ("elandor_whitebridge_shire", "whitebridge"),
    ("elandor_lorindor", "lorindor"),
    ("elandor_moonfall_wood", "moonfall"),
    ("kragmar_ossuary_reach", "ossuary"),
    ("kragmar_speargrass_reach", "speargrass"),
    ("kragmar_whispering_reedlands", "reedlands"),
    ("kragmar_totemwater_reach", "totemwater"),
]
ZONE_OF = {short: zone for zone, short in ZONES}
ZONE_OF["dur_brannoc"] = "elandor_dur_brannoc"

# The givers (grug_quests/npcs.lua; the foremen are Round 58's, Brodd
# Deeppeg and Rellis Shalemark by their camp ids).
NPC = {
    "edda": "r20_anchor_014_host", "hedra": "r20_anchor_026_host", "kelda": "r20_anchor_061_host",
    "brodd": "r58_foreman_mining_camp_frostbarrow_shelf",
    "merren": "r20_anchor_016_host", "jessa": "r20_anchor_030_host", "halen": "r20_anchor_062_host",
    "ilwen": "r20_anchor_018_host", "orya": "r20_anchor_034_host", "saevin": "r20_anchor_063_host",
    "lethen": "r20_anchor_035_host",
    "sovel": "r20_anchor_020_host", "mereth": "r20_anchor_038_host", "neris": "r20_anchor_064_host",
    "rellis": "r58_foreman_mining_camp_ossuary_reach",
    "brakka": "r20_anchor_022_host", "gorren": "r20_anchor_065_host", "morga": "r20_anchor_042_host",
    "taleko": "r20_anchor_024_host", "enashi": "r20_anchor_046_host", "zali": "r20_anchor_066_host",
    "tokai": "r20_anchor_047_host",
    "varda": "r20_dwarf_capital_cook",
    # turn-ins outside the band
    "hadrin": "r58_guild_leader_dur_brannoc", "borin": "r20_anchor_027_host",
    "toren": "r20_anchor_031_host", "faeris": "r20_anchor_036_host", "vaska": "r20_anchor_039_host",
    "yarra": "r20_anchor_044_host", "dorrin": "r20_dwarf_capital_envoy",
    "mariel": "r20_human_capital_envoy", "ossa": "r20_undead_capital_envoy",
}

# The givers' lines (a line is a label; a shared quest needs one line every
# NPC giver of it has, validate.lua, at most two per giver). The chapter
# check's line plan: `shore` for Hedra, Orya, Lethen and Tokai (the shore
# hunt; the snares and the planks ride on it), Tokai's second line
# `provisions` with Varda's (the fish), `steel` for the six mine leaders,
# Merren's and Brakka's shared `journeys` (the corn), Mereth's `camp` from
# Rellis' lines (the travel to Neris they share). Only the givers listed
# change; every other giver keeps its shipped lines.
LINES = {
    "hedra": ["watch", "shore"], "kelda": ["cutting", "steel"],
    "halen": ["materials", "steel"],
    "orya": ["wardenry", "shore"], "saevin": ["cutting", "steel"],
    "lethen": ["stars", "shore"],
    "mereth": ["rubbings", "camp"], "neris": ["dig", "steel"],
    "gorren": ["yard", "steel"],
    "zali": ["cut", "steel"],
    "tokai": ["shore", "provisions"],
}

HEALING = "grug_alchemy:potion_healing_t3"
MANA = "grug_alchemy:potion_mana_t3"
POTIONS = [{"item": HEALING, "count": 2}, {"item": MANA, "count": 2}]

# The town places (Round 59 kind: a quest_place socket): Rimebell Watch's
# signal stand and Market Close's basket check (wp40/r20_poi_blueprint.lua),
# the mining camp's held load (wp40/r58_camp_blueprint.lua).
SIGNAL_STAND = "socket:r20_anchor_026/signal_stand"
BASKET_CHECK = "socket:r20_anchor_016/basket_check"
HELD_LOAD = "socket:mining_camp_frostbarrow_shelf/held_load"
FOLIO = "grug_mobs:dispatch_folio"


def kill(roles, count, area=None):
    row = {"type": "kill", "roles": list(roles), "count": count}
    if area:
        row["area"] = area
    return row


def item(name, count, group=False, roles=None, area=None):
    row = {"type": "item", ("group" if group else "item"): name, "count": count}
    if roles:
        row["roles"] = list(roles)
    if area:
        row["area"] = area
    return row


def talk(who):
    return {"type": "talk", "npc": NPC[who]}


def use(place, obj, label, hold):
    return {"type": "use", "place": place, "object": obj, "label": label, "hold": hold}


def armor(slot, affix):
    """One T3 armor piece per armor class (cloth, leather, metal), each with
    one author-fixed enchant: `affix` maps the class to (channel, stat)."""
    items = {"cloth": "grug_gear:%s_cloth_heavy" % slot,
             "leather": "grug_gear:%s_leather_heavy" % slot,
             "metal": "grug_gear:%s_metal_steel" % slot}
    return [{"item": items[c], "affixes": [{"channel": affix[c][0], "stat": affix[c][1]}]}
            for c in ("cloth", "leather", "metal")]


# The first piece: the class's main stat as a prefix; the second: a second
# stat as a suffix (grug_quality POOLS), as the band 11-20.
EARLY = {"cloth": ("prefix", "int"), "leather": ("prefix", "dex"), "metal": ("prefix", "str")}
LATE = {"cloth": ("suffix", "max_mana_percent"), "leather": ("suffix", "crit_percent"),
        "metal": ("suffix", "max_hp_percent")}


def weapons(melee):
    """The named leader's choice: one T3 weapon per weapon line (caster,
    scout, warrior; Priest and Mage share), prefix and suffix each; the
    two-handed Staff where the Battle Axe is offered, the Wand beside the
    Sword."""
    caster = "grug_gear:staff_steel" if melee == "greataxe" else "grug_gear:wand_steel"
    warrior = {"sword": ("grug_gear:sword_steel", "crit_percent"),
               "greataxe": ("grug_gear:greataxe_steel", "max_hp_percent")}[melee]
    return [
        {"item": caster, "affixes": [{"channel": "prefix", "stat": "int"},
                                     {"channel": "suffix", "stat": "max_mana_percent"}]},
        {"item": "grug_gear:bow_steel", "affixes": [{"channel": "prefix", "stat": "dex"},
                                                    {"channel": "suffix", "stat": "attack_speed_percent"}]},
        {"item": warrior[0], "affixes": [{"channel": "prefix", "stat": "str"},
                                         {"channel": "suffix", "stat": warrior[1]}]},
    ]


# ---------------------------------------------------------------- shared
# One quest, one level each; each variant: its zone's giver, its zone-bound
# fields (kill roles and area, use place) and its placeholder text. The
# first variant's zone is the quest's home (its own objectives).
SHARED = [
    {
        "id": "band_steel", "line": "steel", "min_level": 23, "level": 24,
        "title": "Steel for the Work",
        "objectives": [item("grug_materials:steel_bar", 4)],
        "rewards": {"weight": 4.5},
        "lesson": "The shared steel help of the six mines; each mine leader names the guild in this first offer.",
        "duration_min": 12,
        "notes": "Draft §3 'Stahl für die Arbeit' (K5 A: Zali's pumps too) and §7: the mine leader's first quest "
                 "carries the guild membership.",
        "towns": [
            ("frostbarrow", "kelda", {"text": "Kelda Screesort of The Charter of Stone needs 4 Steel Bars for the "
                                              "prop fittings at Tarncut Mine; without sound props her crew stops."}),
            ("whitebridge", "halen", {"text": "Halen Chalkthumb gives The Charter of Stone measurements builders "
                                              "rely on: 4 Steel Bars for his slipped survey mount."}),
            ("lorindor", "saevin", {"text": "Saevin Rootscribe holds the guild's work to the ground that carries "
                                            "it: 4 Steel Bars to brace the cutting at the old roots."}),
            ("ossuary", "neris", {"text": "Neris Fossilhand of The Oathdelvers keeps old finds with their names "
                                          "while she digs: 4 Steel Bars to shore up the dig."}),
            ("speargrass", "gorren", {"text": "Gorren Redpick keeps The Oathdelvers' promise of working tools: "
                                              "4 Steel Bars for tools and the sorting tables."}),
            ("reedlands", "zali", {"text": "Zali Runoff keeps a wet cut working for The Oathdelvers: 4 Steel Bars "
                                           "for worn pump mounts and rods."}),
        ],
    },
    {
        "id": "band_shore_pinchers", "line": "shore", "min_level": 24, "level": 25,
        "title": "A Free Stand on the Shore",
        "objectives": [kill(["armored_crab"], 6, "elandor_frostbarrow_shelf/icy_shore")],
        "rewards": {"weight": 5},
        "lesson": "The shared shore hunt, by day, at the zone's own shore.",
        "duration_min": 10,
        "notes": "Draft §3 'Freier Stand am Ufer': Barnacle Pinchers at each zone's shore kind.",
        "towns": [
            ("frostbarrow", "hedra", {"area": "elandor_frostbarrow_shelf/icy_shore",
                                      "text": "Hedra Rimebell wants a safe footing at the landing: drive back 6 "
                                              "Barnacle Pinchers by day on the {name:icy_shore}."}),
            ("lorindor", "orya", {"area": "elandor_lorindor/shell_strand",
                                  "text": "Orya Petalward wants room for the shore watch: 6 Barnacle Pinchers by "
                                          "day on the {name:shell_strand}."}),
            ("moonfall", "lethen", {"area": "elandor_moonfall_wood/moonstrand",
                                    "text": "Lethen Moonledger's observers need their feet: 6 Barnacle Pinchers "
                                            "by day on the {name:moonstrand}."}),
            ("totemwater", "tokai", {"area": "kragmar_totemwater_reach/shallows",
                                     "text": "Tokai Knotreader wants room for the fishing gear: 6 Barnacle "
                                             "Pinchers by day in the {name:shallows}."}),
        ],
    },
    {
        "id": "band_snares", "line": "shore", "min_level": 21, "level": 22,
        "title": "Loosen the Snares",
        "objectives": [use("elandor_lorindor/snare_ground", "snare_bundle", "Cut the snare bundle", 3)],
        "rewards": {"weight": 4.5},
        "lesson": "A use at a recipe place in the open: the same act in two woods.",
        "duration_min": 9,
        "notes": "Draft §3 'Schlingen lösen' (K9 A): the snare grounds of Lorindor's Berrywoods and Moonfall's "
                 "Eaves.",
        "towns": [
            ("lorindor", "orya", {"place": "elandor_lorindor/snare_ground",
                                  "text": "Orya Petalward has an answer to the silent birds: make the snares at "
                                          "the {name:snare_ground} in the {name:berrywoods} useless."}),
            ("moonfall", "lethen", {"place": "elandor_moonfall_wood/snare_ground",
                                    "text": "Lethen Moonledger wants the marked snares at the {name:snare_ground} "
                                            "in the {name:eaves} cut; false forest signs are poor company for an observer."}),
        ],
    },
    {
        "id": "band_corn", "line": "journeys", "min_level": 20, "level": 21,
        "title": "The Waiting Still Eat",
        "objectives": [item("grug_gathering:corn", 8)],
        "rewards": {"weight": 4, "choices": "potions"},
        "lesson": "The zone's first errand, a level only; the early potion choice.",
        "duration_min": 8,
        "notes": "Draft §3 'Vorrat für die Wartenden'.",
        "towns": [
            ("whitebridge", "merren", {"text": "Merren Oakstamp feeds the people whose paid delivery never "
                                               "came: bring 8 Corn."}),
            ("speargrass", "brakka", {"text": "Brakka Jarward feeds the cutting crews before the next shift: "
                                              "bring 8 Corn."}),
        ],
    },
    {
        "id": "band_planks", "line": "shore", "min_level": 22, "level": 23,
        "title": "Sound Wood",
        "objectives": [item("wood", 15, group=True)],
        "rewards": {"weight": 4},
        "lesson": "A shared material errand: planks of any wood.",
        "duration_min": 8,
        "notes": "Draft §3 'Brauchbares Holz' (Lethen's sighting posts, Tokai's trap lids).",
        "towns": [
            ("moonfall", "lethen", {"text": "Lethen Moonledger replaces split sighting posts: bring 15 Wooden "
                                            "Planks of any wood."}),
            ("totemwater", "tokai", {"text": "Tokai Knotreader needs lids for the fish traps instead of crab "
                                             "shells: bring 15 Wooden Planks of any wood."}),
        ],
    },
    {
        "id": "band_mire_carp", "line": "provisions", "min_level": 20, "level": 21,
        "title": "Fish for the Table",
        "objectives": [item("grug_fishing:mire_carp", 4)],
        "rewards": {"weight": 4, "choices": "potions"},
        "lesson": "A fishing errand, a level only; Totemwater's first quest and Varda's pie.",
        "duration_min": 10,
        "notes": "Draft §3 'Fisch für den Tisch': Tokai in Totemwater and Varda Copperpan in Dur Brannoc (her "
                 "provisions line); lane CAPITALS adds no Mire Carp quest of its own.",
        "towns": [
            ("totemwater", "tokai", {"text": "Tokai Knotreader admits a seer needs lunch: bring 4 Mire Carp."}),
            ("dur_brannoc", "varda", {"text": "Varda Copperpan's fish pie wants 4 Mire Carp, and she has opinions "
                                              "about who should catch them."}),
        ],
    },
]

# ---------------------------------------------------------------- local
# Per zone: the first errand (potions), its travels, the use or hunt (the
# first armor piece), the later errand (the second), the named leader (the
# weapon) and the departure; chapter 2's band steps. A kept id keeps its
# objectives; every other id is new (round60-plan.md §3).
# Rows: id, giver, line, min level, level, objectives, weight, title, text
# (the intent), and optional turnin, choices, completion, requires, story,
# quest_drops, duration, notes.
LOCAL = {
    "frostbarrow": {
        "melee": "greataxe", "slots": ("head", "chest"),
        "quests": [
            {"id": "frostbarrow_melons", "giver": "edda", "line": "sleds", "min_level": 20, "level": 21,
             "objectives": [item("grug_cooking:frost_melon", 5)], "weight": 4, "choices": "potions",
             "title": "Something Fresh for the Sled Drivers",
             "text": "Edda Tarnmantle wants the returning sled drivers to find more than hard rations: bring 5 "
                     "Frost Melons.", "duration": 9},
            {"id": "frostbarrow_sleds_hedra", "giver": "edda", "line": "sleds", "min_level": 21, "level": 22,
             "objectives": [talk("hedra")], "weight": 1, "turnin": "hedra", "kept": True,
             "title": "Hedra's View of the Track",
             "text": "Edda sends the player to Hedra Rimebell at Rimebell Watch, who knows where the returning "
                     "drivers lose their way.", "duration": 6},
            {"id": "frostbarrow_sleds_02", "giver": "edda", "line": "sleds", "min_level": 22, "level": 23,
             "objectives": [talk("kelda")], "weight": 1, "turnin": "kelda", "kept": True,
             "title": "Word for Tarncut",
             "text": "Edda sends word to Kelda Screesort at Tarncut Mine, whose crew waits on the same sleds.",
             "duration": 6},
            {"id": "frostbarrow_signal", "giver": "hedra", "line": "watch", "min_level": 22, "level": 23,
             "objectives": [use(SIGNAL_STAND, "signal_lantern", "Trim the signal lantern", 4)], "weight": 5,
             "choices": "early",
             "title": "The Reliable Light",
             "text": "Hedra wants the signal lantern at Rimebell Watch's signal stand made ready, so the next "
                     "return in bad weather has a light to steer by.",
             "completion": "The lantern burns; Hedra trusts it more than any promise.", "duration": 8},
            {"id": "frostbarrow_stove_coal", "giver": "edda", "line": "sleds", "min_level": 26, "level": 27,
             "objectives": [item("default:coal_lump", 12)], "weight": 5, "choices": "late",
             "title": "Coal for the Warming Hut",
             "text": "Edda keeps Tarnwatch Fold's warming hut lit for the drivers who come back half frozen: "
                     "bring 12 Coal Lumps.", "duration": 9},
            {"id": "frostbarrow_cutting_04", "giver": "kelda", "line": "cutting", "min_level": 28, "level": 29,
             "objectives": [kill(["powder_counter_nib"], 1), item(FOLIO, 1)],
             "quest_drops": [{"item": FOLIO, "chance": 1, "roles": ["powder_counter_nib"]}],
             "weight": 7, "choices": "weapon", "kept": True,
             "title": "An Explosive Miscalculation",
             "text": "Kelda sends the player against Goblin Powder-Counter Nib in the {name:rimewood}, who stole "
                     "the blasting powder; the Dispatch Folio of blank delivery forms went with it.",
             "completion": "Kelda recognises the stolen form set in the Folio: blank sheets beside abused "
                           "settlements. It explains Nib's theft, not every paper of chapter 1.",
             "notes": "The id stays (round60-plan.md §3: A4's prerequisite); its one Accord follow-up is A4. "
                      "K3 A: the Dispatch Folio, a soulbound quest-only item, drops from Nib every time.",
             "duration": 14},
            {"id": "frostbarrow_departure", "giver": "kelda", "line": "cutting", "min_level": 29, "level": 30,
             "objectives": [talk("borin")], "weight": 1, "turnin": "borin", "kept": True,
             "title": "A Miner for Splitbolt",
             "text": "Kelda sends the player to Borin Splitbolt at Splitbolt Station in Stormvault Heights, "
                     "where the Accord needs people who keep their heads under falling stone; no earlier deed "
                     "is claimed.", "duration": 10,
             "notes": "The departure id stays; free from 29, it requires nothing (round60-plan.md §2 point 1)."},
            # Chapter 2 (round60-plan.md §2a point 6, draft §5).
            {"id": "story_accord_03", "giver": "brodd", "line": "guild", "min_level": 24, "level": 25,
             "story": True, "requires": ["story_accord_02"], "turnin": "kelda",
             "objectives": [use(HELD_LOAD, "dispatch_record", "Secure the dispatch record", 4),
                            use(HELD_LOAD, "held_supplies", "Release the held load", 4)],
             "weight": 5.5, "choices": "potions",
             "title": "Held in Our Name",
             "text": "Brodd Deeppeg has the props meant for Tarncut Mine held in the camp's yard under a "
                     "later order; the guild and the supply office confirmed the original release. Secure the "
                     "abused record and release the load, in either order; Kelda takes the report.",
             "completion": "Kelda names the crew waiting on those props and confirms the load is ready for "
                           "Tarncut again. She knows the form; what proves its source is still to come.",
             "notes": "A3 (K2 A): the held load at a quest_place socket of the mining camp blueprint.",
             "duration": 12},
            {"id": "story_accord_04", "giver": "kelda", "line": "cutting", "min_level": 29, "level": 29,
             "story": True, "requires": ["story_accord_03", "frostbarrow_cutting_04"], "turnin": "hadrin",
             "objectives": [talk("hadrin")], "weight": 2,
             "title": "Under a Joint Seal",
             "text": "Kelda wants the held delivery and Nib's form set judged together: take both to Hadrin "
                     "Beamset at the Miner's Guild house in Dur Brannoc.",
             "completion": "Hadrin keeps three things apart: the real delivery, the stolen forms and their "
                           "unauthorised use. The case is sealed; the next supply post of the arc is Toren "
                           "Waterbarrel at Cinderline Watch in Ashenward March.",
             "notes": "A4: wholly band-file data; requires A3 and Nib's free quest (their one Accord "
                      "follow-up).", "duration": 12},
        ],
    },
    "whitebridge": {
        "melee": "sword", "slots": ("legs", "feet"),
        "quests": [
            {"id": "whitebridge_river_halen", "giver": "jessa", "line": "river", "min_level": 22, "level": 23,
             "objectives": [talk("halen")], "weight": 1, "turnin": "halen",
             "title": "Have the Ramp Measured",
             "text": "Jessa Axlewright sends the player to Halen Chalkthumb at Bridgechalk Dig, who should fix "
                     "the ferry ramp's repair to a measure that holds.", "duration": 6},
            {"id": "whitebridge_basket_check", "giver": "merren", "line": "baskets", "min_level": 22, "level": 23,
             "objectives": [use(BASKET_CHECK, "dispatch_record", "Check the pickup records", 4)], "weight": 5,
             "choices": "early",
             "title": "Two Pickups for One Basket",
             "text": "Merren Oakstamp wants the stored baskets at Market Close checked against the pickup "
                     "records; two buyers hold slips for the same basket.",
             "completion": "Merren sees which slip is real; her market keeps its good name.", "duration": 8},
            {"id": "whitebridge_baskets_03", "giver": "merren", "line": "baskets", "min_level": 24, "level": 25,
             "objectives": [kill(["basket_poacher_thorn"], 1)], "weight": 5.5, "choices": "late", "kept": True,
             "title": "Thorn's Double Sale",
             "text": "Merren sends the player against Basket-Poacher Thorn in the {name:willowbanks}, who sells "
                     "the same goods twice.",
             "completion": "Thorn sells nothing more; Merren's customers get their baskets.", "duration": 9},
            {"id": "whitebridge_ramp_stone", "giver": "halen", "line": "materials", "min_level": 25, "level": 26,
             "objectives": [item("default:stonebrick", 20)], "weight": 5,
             "title": "Stone for the Ferry Ramp",
             "text": "Halen measures the ferry ramp's repair to what it must carry: bring 20 Stone Bricks.",
             "duration": 9},
            {"id": "whitebridge_journey_lorindor", "giver": "merren", "line": "journeys", "min_level": 24,
             "level": 24, "objectives": [talk("ilwen")], "weight": 1, "turnin": "ilwen", "kept": True,
             "title": "The Other End of the River Trade",
             "text": "Merren sends the player to Ilwen Petalmeasure in Lorindor, the other end of the river "
                     "trade.", "duration": 10},
            {"id": "whitebridge_journey_dur_brannoc", "giver": "merren", "line": "journeys", "min_level": 24,
             "level": 24, "objectives": [talk("dorrin")], "weight": 1, "turnin": "dorrin", "kept": True,
             "title": "Word for Dur Brannoc",
             "text": "Merren sends word of the double sales to Dorrin Gateledger in Dur Brannoc.",
             "duration": 10},
            {"id": "whitebridge_journey_frostbarrow", "giver": "merren", "line": "journeys", "min_level": 24,
             "level": 24, "objectives": [talk("edda")], "weight": 1, "turnin": "edda", "kept": True,
             "title": "Baskets for the Cold",
             "text": "Merren sends the player to Edda Tarnmantle in Frostbarrow Shelf, who waits on the same "
                     "deliveries.", "duration": 10},
            {"id": "whitebridge_river_02", "giver": "jessa", "line": "river", "min_level": 28, "level": 29,
             "objectives": [kill(["ferryman_murk"], 1)], "weight": 7, "choices": "weapon", "kept": True,
             "title": "Murk's Final Fare",
             "text": "Jessa sends the player against Mirefolk Ferryman Murk at the {name:ferry_camp}, who "
                     "extorts the needed passage from the carters.",
             "completion": "The passage is free again; the carters pay for the river, not for Murk.",
             "duration": 10},
            {"id": "whitebridge_materials_02", "giver": "halen", "line": "materials", "min_level": 29,
             "level": 29, "objectives": [talk("borin")], "weight": 1, "turnin": "borin", "kept": True,
             "title": "Measures for Splitbolt",
             "text": "Halen sends the player to Borin Splitbolt in Stormvault Heights, where sound measures "
                     "are needed; no earlier deed is claimed.", "duration": 10,
             "notes": "The departure id stays; free from 29, it requires nothing."},
        ],
    },
    "lorindor": {
        "melee": "sword", "slots": ("head", "legs"),
        "quests": [
            {"id": "lorindor_marshbloom", "giver": "ilwen", "line": "berries", "min_level": 20, "level": 21,
             "objectives": [item("grug_gathering:marshbloom", 6)], "weight": 4, "choices": "potions",
             "title": "A Taste After a Long Road",
             "text": "Ilwen Petalmeasure feeds the harvesters and carriers: bring 6 Marshbloom.",
             "duration": 9},
            {"id": "lorindor_berries_orya", "giver": "ilwen", "line": "berries", "min_level": 21, "level": 22,
             "objectives": [talk("orya")], "weight": 1, "turnin": "orya",
             "title": "Why the Wood Goes Quiet",
             "text": "Ilwen sends the player to Orya Petalward at Petalbank Wardenry: the missing birdsong is "
                     "an observation Orya takes seriously.", "duration": 6},
            {"id": "lorindor_harvest_chests", "giver": "ilwen", "line": "berries", "min_level": 22, "level": 23,
             "objectives": [item("default:chest", 3)], "weight": 5, "choices": "early",
             "title": "Chests That Arrive",
             "text": "Ilwen knows a neat crate list from a harvest that arrives: bring 3 Chests for the loads "
                     "that leave Berrycourt.", "duration": 8},
            {"id": "lorindor_cutting_02", "giver": "saevin", "line": "cutting", "min_level": 24, "level": 25,
             "objectives": [talk("kelda")], "weight": 1, "turnin": "kelda", "kept": True,
             "title": "A Word With Kelda",
             "text": "Saevin Rootscribe recommends Kelda Screesort at Tarncut Mine; the visit opens no story "
                     "on its own.", "duration": 10},
            {"id": "lorindor_journeys_01", "giver": "ilwen", "line": "journeys", "min_level": 24, "level": 25,
             "objectives": [talk("mariel")], "weight": 1, "turnin": "mariel", "kept": True,
             "title": "Word for Highcourt",
             "text": "Ilwen sends word of the missing deliveries to Mariel Waybook in Highcourt.",
             "duration": 10},
            {"id": "lorindor_journeys_02", "giver": "ilwen", "line": "journeys", "min_level": 24, "level": 25,
             "objectives": [talk("merren")], "weight": 1, "turnin": "merren", "kept": True,
             "title": "The Other End of the Basket Trade",
             "text": "Ilwen sends the player to Merren Oakstamp in Whitebridge Shire, who waits on the same "
                     "loads.", "duration": 10},
            {"id": "lorindor_ward_torches", "giver": "orya", "line": "wardenry", "min_level": 26, "level": 27,
             "objectives": [item("default:torch", 20)], "weight": 5, "choices": "late",
             "title": "Lights for the Wardens' Rounds",
             "text": "Orya's wardens walk the paths at night where the birds went quiet: bring 20 Torches.",
             "duration": 8},
            {"id": "lorindor_iss", "giver": "ilwen", "line": "berries", "min_level": 28, "level": 29,
             "objectives": [kill(["pearl_counter_iss"], 1)], "weight": 7, "choices": "weapon",
             "title": "Close the Pearl Account",
             "text": "Ilwen sends the player against Mirefolk Pearl-Counter Iss at the {name:pearl_camp}, who "
                     "claims the result of everyone's work.",
             "completion": "Iss's account is closed; the harvest reaches its people.", "duration": 12},
            {"id": "lorindor_berries_04", "giver": "ilwen", "line": "berries", "min_level": 29, "level": 30,
             "objectives": [talk("toren")], "weight": 1, "turnin": "toren", "kept": True,
             "title": "The Road to Ashenward",
             "text": "Ilwen sends the player to Toren Waterbarrel at Cinderline Watch in Ashenward March; no "
                     "earlier deed is claimed.", "duration": 10,
             "notes": "The departure id stays; free from 29, it requires nothing."},
        ],
    },
    "moonfall": {
        "melee": "greataxe", "slots": ("chest", "feet"),
        "quests": [
            {"id": "moonfall_glass", "giver": "lethen", "line": "stars", "min_level": 20, "level": 21,
             "objectives": [item("default:glass", 6)], "weight": 4, "choices": "potions",
             "title": "A Pane Without a Crack",
             "text": "Lethen Moonledger needs Glass for the shield pane of an instrument; the player brings "
                     "the material, Lethen does the work: bring 6 Glass.", "duration": 8},
            {"id": "moonfall_sighting", "giver": "lethen", "line": "stars", "min_level": 23, "level": 24,
             "objectives": [use("elandor_moonfall_wood/sighting_post", "sighting_frame",
                                "Set up the sighting frame", 4)], "weight": 5, "choices": "early",
             "title": "A Fixed Point of Reference",
             "text": "Lethen wants the prepared sighting frame set up at the {name:sighting_post} in the "
                     "{name:deepwood}, a reference the false forest signs cannot move.",
             "completion": "Lethen has a point to measure from again.", "duration": 9},
            {"id": "moonfall_ladders", "giver": "lethen", "line": "stars", "min_level": 26, "level": 27,
             "objectives": [item("default:ladder_wood", 10)], "weight": 5, "choices": "late",
             "title": "Ladders for the Platforms",
             "text": "Lethen's observers climb to their platforms on rungs older than his patience: bring 10 "
                     "Wooden Ladders.", "duration": 8},
            {"id": "moonfall_snares_03", "giver": "lethen", "line": "stars", "min_level": 28, "level": 29,
             "objectives": [kill(["snarewarden_bracken"], 1)], "weight": 7, "choices": "weapon", "kept": True,
             "title": "A Warden in Name Alone",
             "text": "Lethen sends the player against Poacher Snarewarden Bracken in the {name:elderwood}, who "
                     "deals with Vetch and Rusk; their fall is not assumed.",
             "completion": "Bracken's false signs come down with him.", "duration": 12},
            {"id": "moonfall_snares_04", "giver": "lethen", "line": "stars", "min_level": 29, "level": 30,
             "objectives": [talk("faeris")], "weight": 1, "turnin": "faeris", "kept": True,
             "title": "The Trade Beyond the Wood",
             "text": "Lethen sends the player to Faeris Rootbinder at Glassroot Gate, where Bracken's trade "
                     "reaches; his case is not claimed.", "duration": 10,
             "notes": "The departure id stays; free from 29, it requires nothing."},
        ],
    },
    "ossuary": {
        "melee": "greataxe", "slots": ("chest", "legs"),
        "quests": [
            {"id": "ossuary_gravewood", "giver": "sovel", "line": "names", "min_level": 20, "level": 21,
             "objectives": [item("grug_trees:gravewood_wood", 10)], "weight": 4, "choices": "potions",
             "title": "A Second Readable Copy",
             "text": "Sovel Namekeeper copies damaged labels onto new name boards: bring 10 Gravewood Planks "
                     "from the bone forest.", "duration": 8,
             "notes": "Draft §3.5's Paper replaced (check: papyrus grows only on warm shores): a local wood."},
            {"id": "ossuary_names_02", "giver": "sovel", "line": "names", "min_level": 21, "level": 22,
             "objectives": [talk("mereth")], "weight": 1.5, "turnin": "mereth", "kept": True,
             "title": "Paper Remembers",
             "text": "Sovel sends the player to Mereth Rubbinghand at Boneledger Post, who copies and compares.",
             "duration": 8},
            {"id": "ossuary_names_01", "giver": "sovel", "line": "names", "min_level": 22, "level": 23,
             "objectives": [kill(["briarpack_wolf"], 8, "kragmar_ossuary_reach/bonewood")], "weight": 5,
             "choices": "early", "kept": True,
             "title": "Misfiled in a Wolf",
             "text": "Ash Howlers drag off labelled remains: hunt 8 of them by day in the {name:bonewood}.",
             "duration": 10},
            {"id": "ossuary_record_chests", "giver": "mereth", "line": "rubbings", "min_level": 26, "level": 27,
             "objectives": [item("default:chest", 3)], "weight": 5, "choices": "late",
             "title": "Dry Keeping for the Copies",
             "text": "Mereth keeps every copy beside the stone it came from: bring 3 Chests to keep them dry.",
             "duration": 8},
            {"id": "ossuary_archivist", "giver": "neris", "line": "dig", "min_level": 27, "level": 28,
             "objectives": [kill(["marrow_archivist"], 1)], "weight": 7, "choices": "weapon",
             "title": "Filed Under Theft",
             "text": "Neris Fossilhand sends the player against Skeleton Marrow Archivist in the "
                     "{name:deepwood}, who stole her chisel.",
             "completion": "The chisel's thief is down; Neris makes no claim about whom he served.",
             "duration": 12},
            {"id": "ossuary_dig_04", "giver": "neris", "line": "dig", "min_level": 28, "level": 29,
             "objectives": [talk("vaska")], "weight": 1, "turnin": "vaska", "kept": True,
             "title": "Ashveil Keeps Its Own Records",
             "text": "Neris sends the player to Vaska Ashlistener at Ashveil Watch in Blackwind Rise; no "
                     "earlier deed is claimed.", "duration": 10,
             "notes": "The departure id stays; free from 28, it requires nothing."},
            {"id": "story_throng_03", "giver": "rellis", "line": "guild", "min_level": 24, "level": 25,
             "story": True, "requires": ["story_throng_02"], "turnin": "mereth",
             "objectives": [use("claim_rest", "witness_record", "Secure the copied claim", 4)],
             "weight": 5.5, "choices": "potions",
             "title": "The Copy Between Them",
             "text": "Rellis Shalemark wants an original name record and the new claim built on it secured at "
                     "the {name:claim_rest} in the {name:barrowlands} before weather or another hand ruins them; Mereth is the one to "
                     "read them. He claims no certainty about who did it.",
             "completion": "Mereth sees the new claim repeat a correction found only in an official register "
                           "copy, not on the stone: someone worked from an existing copy.",
             "notes": "T2a (K1 A): requires T2; lane CAPITALS' T3 requires it and ossuary_rubbings_03.",
             "duration": 10},
        ],
    },
    "speargrass": {
        "melee": "greataxe", "slots": ("head", "feet"),
        "quests": [
            {"id": "speargrass_grass_morga", "giver": "brakka", "line": "grass", "min_level": 22, "level": 23,
             "objectives": [talk("morga")], "weight": 1, "turnin": "morga",
             "title": "Morga Knows the Missing Colours",
             "text": "Brakka Jarward sends the player to Morga Cutgrass at Cutgrass Watch, who gathers the "
                     "reports of vanished banners.", "duration": 6},
            {"id": "speargrass_journeys_01", "giver": "brakka", "line": "journeys", "min_level": 22, "level": 23,
             "objectives": [talk("ossa")], "weight": 1.5, "turnin": "ossa", "kept": True,
             "title": "Promises Outlast Breath",
             "text": "Brakka sends the player to Ossa Quietregister in Nhal Veyr with the names of the crews "
                     "she counts.", "duration": 12},
            {"id": "speargrass_yard_02", "giver": "gorren", "line": "yard", "min_level": 24, "level": 25,
             "objectives": [item("grug_mobs:shearing_cat_claw", 3, roles=["reed_stalking_tiger"],
                                 area="kragmar_speargrass_reach/tallgrass")], "weight": 5, "choices": "early",
             "kept": True,
             "title": "Put the Claws to Work",
             "text": "Gorren Redpick tries Shearing Cat Claws as tool tips: bring 3, from the Tallgrass Tigers "
                     "of the {name:tallgrass}.", "duration": 10},
            {"id": "speargrass_crew_gates", "giver": "brakka", "line": "grass", "min_level": 25, "level": 26,
             "objectives": [item("doors:gate_acacia_wood_closed", 4)], "weight": 5,
             "title": "Gates for the Crew Yard",
             "text": "Brakka counts the people who go out to work and wants them counted back in: bring 4 "
                     "Acacia Wood Gates for the crew yard.", "duration": 8},
            {"id": "speargrass_banners", "giver": "morga", "line": "watch", "min_level": 27, "level": 28,
             "objectives": [use("banner_cache", "held_supplies", "Secure the stolen banners", 4)], "weight": 5,
             "choices": "late",
             "title": "Secure the Abandoned Loot",
             "text": "Morga wants a bundle of the stolen banners secured at the {name:banner_cache} in the "
                     "{name:hunting_grounds}, a load left behind away from the goblins' camp.",
             "completion": "The colours belong to the people who served under them again.", "duration": 9},
            {"id": "speargrass_rakk", "giver": "morga", "line": "watch", "min_level": 28, "level": 29,
             "objectives": [kill(["banner_broker_rakk"], 1)], "weight": 7, "choices": "weapon",
             "title": "Our Colours Are Not for Sale",
             "text": "Morga sends the player against Goblin Banner-Broker Rakk at the {name:goblin_camp}, who "
                     "sells stolen banners back to their bearers.",
             "completion": "Rakk's trade in other people's colours is over.", "duration": 12},
            {"id": "speargrass_watch_03", "giver": "morga", "line": "watch", "min_level": 29, "level": 29,
             "objectives": [talk("vaska")], "weight": 1.5, "turnin": "vaska", "kept": True,
             "title": "Stand Where the Ash Falls",
             "text": "Morga sends the player to Vaska Ashlistener in Blackwind Rise; no earlier deed is "
                     "claimed.", "duration": 12,
             "notes": "The departure id stays; free from 29, it requires nothing."},
        ],
    },
    "reedlands": {
        "melee": "sword", "slots": ("chest", "feet"),
        "quests": [
            {"id": "whispering_melons", "giver": "taleko", "line": "reeds", "min_level": 20, "level": 21,
             "objectives": [item("grug_gathering:melon", 4)], "weight": 4, "choices": "potions",
             "title": "Something for the Carriers",
             "text": "Taleko Drycord keeps the carriers at Whisperreed Landing fed: bring 4 Melons.",
             "duration": 9},
            {"id": "whispering_reeds_enashi", "giver": "taleko", "line": "reeds", "min_level": 22, "level": 23,
             "objectives": [talk("enashi")], "weight": 1, "turnin": "enashi",
             "title": "Who Disputes the Claim",
             "text": "Taleko sends the player to Enashi Reedvoice at Reedvoice Station, who contradicts those "
                     "who make the water their own.", "duration": 6},
            {"id": "whispering_journey_speargrass", "giver": "taleko", "line": "journeys", "min_level": 22,
             "level": 23, "objectives": [talk("brakka")], "weight": 0.5, "turnin": "brakka", "kept": True,
             "title": "An Invitation to Speargrass",
             "text": "Taleko sends the player to Brakka Jarward in Speargrass Reach, an ally of the exchange.",
             "duration": 10},
            {"id": "whispering_journey_ossuary", "giver": "taleko", "line": "journeys", "min_level": 22,
             "level": 23, "objectives": [talk("sovel")], "weight": 0.5, "turnin": "sovel", "kept": True,
             "title": "An Invitation to Ossuary",
             "text": "Taleko sends the player to Sovel Namekeeper in Ossuary Reach, an ally of the exchange.",
             "duration": 10},
            {"id": "whispering_cut_01", "giver": "zali", "line": "cut", "min_level": 24, "level": 25,
             "objectives": [kill(["reed_crocodile"], 6, "kragmar_whispering_reedlands/mudbanks")], "weight": 5,
             "choices": "early", "kept": True,
             "title": "That Is No Floating Log",
             "text": "Zali Runoff's stone carriers keep meeting Logbacks: hunt 6 of them in the "
                     "{name:mudbanks}.", "duration": 10},
            {"id": "whispering_route_signs", "giver": "taleko", "line": "reeds", "min_level": 25, "level": 26,
             "objectives": [item("default:sign_wall_wood", 6)], "weight": 5,
             "title": "Signs for the Crossings",
             "text": "Taleko keeps the exchange routes open and marked: bring 6 Wooden Signs for the "
                     "crossings.", "duration": 8},
            {"id": "whispering_seized_stores", "giver": "enashi", "line": "voice", "min_level": 26, "level": 27,
             "objectives": [use("seized_stores", "held_supplies", "Free the seized stores", 4)], "weight": 5,
             "choices": "late",
             "title": "Loosen the Held Bundles",
             "text": "Enashi wants the stores seized by the toll-takers made ready for return at the "
                     "{name:seized_stores} in the {name:reedbanks}.",
             "completion": "The bundles can go back to the people they were taken from.", "duration": 9,
             "notes": "The check's fix: the place stands in the open (the Reedbanks), not in Hushwater Nests, "
                      "whose members stand up to 24 nodes from its centre."},
            {"id": "whispering_voice_02", "giver": "enashi", "line": "voice", "min_level": 28, "level": 29,
             "objectives": [kill(["tollkeeper_ush"], 1)], "weight": 7, "choices": "weapon", "kept": True,
             "title": "The River Has No Purse",
             "text": "Enashi sends the player against Mirefolk Tollkeeper Ush at the {name:mire_nests}, who "
                     "charges for every crossing.",
             "completion": "The river charges nobody now.", "duration": 12},
            {"id": "whispering_front_bannerbreak", "giver": "enashi", "line": "voice", "min_level": 29,
             "level": 30, "objectives": [talk("yarra")], "weight": 0.5, "turnin": "yarra", "kept": True,
             "title": "Standards at Bannerbreak",
             "text": "Enashi sends the player to Yarra Standardmender at Tornstandard Hold; Ush's fall is not "
                     "assumed.", "duration": 10,
             "notes": "The departure id stays; free from 29, it requires nothing."},
        ],
    },
    "totemwater": {
        "melee": "sword", "slots": ("head", "legs"),
        "quests": [
            {"id": "totemwater_reading", "giver": "tokai", "line": "shore", "min_level": 23, "level": 24,
             "objectives": [use("reading_bank", "reading_knots", "Secure the reading cord", 4)], "weight": 5,
             "choices": "early",
             "title": "Check the Knots by the River",
             "text": "Tokai Knotreader tests his reading against what he sees: secure his prepared reading cord "
                     "at the {name:reading_bank} in the {name:reedbanks}; no swimming is asked.",
             "completion": "Tokai rereads the cord and likes the answer less.", "duration": 9},
            {"id": "totemwater_enashi", "giver": "tokai", "line": "shore", "min_level": 24, "level": 25,
             "objectives": [talk("enashi")], "weight": 1, "turnin": "enashi",
             "title": "Hear a Second Voice",
             "text": "Tokai sends the player to Enashi Reedvoice in the Whispering Reedlands to put the water "
                     "travellers' reports together.", "duration": 8},
            {"id": "totemwater_weir_fences", "giver": "tokai", "line": "provisions", "min_level": 26, "level": 27,
             "objectives": [item("default:fence_junglewood", 8)], "weight": 5, "choices": "late",
             "title": "Fences for the Weirs",
             "text": "Tokai's fishers want their weirs back in the water: bring 8 Jungle Wood Fences.",
             "duration": 8},
            {"id": "totemwater_knots_04", "giver": "tokai", "line": "shore", "min_level": 28, "level": 29,
             "objectives": [kill(["reed_maw_crocodile"], 1)], "weight": 7, "choices": "weapon", "kept": True,
             "title": "The Name Beneath the Water",
             "text": "Tokai names Crocodile Reed-Maw as the known danger {dir_from_giver:reed_maw_crocodile} and "
                     "sends the player against it; the reading cord is not assumed.",
             "completion": "The old hungry danger of Tokai's knots was the Reed-Maw.", "duration": 12},
            {"id": "totemwater_front_bannerbreak", "giver": "tokai", "line": "shore", "min_level": 29,
             "level": 30, "objectives": [talk("yarra")], "weight": 0.5, "turnin": "yarra", "kept": True,
             "title": "Knots for Bannerbreak",
             "text": "Tokai sends the player to Yarra Standardmender at Tornstandard Hold; no earlier deed is "
                     "claimed.", "duration": 10,
             "notes": "The departure id stays; free from 29, it requires nothing."},
        ],
    },
}

# The Round 58 quests these files carry (kept as shipped).
GUILD_IDS = ("guild_t3_report_accord", "guild_t3_report_throng", "camp_hunt_t3", "camp_hunt_t3_night")

LESSONS = {
    "potions": "The zone's first errand, a level only; the early potion choice.",
    "early": "A use at a place or a day hunt; the first armor choice (one enchant, a prefix).",
    "late": "A later errand or use; the second armor choice (one enchant, a suffix).",
    "weapon": "The named leader; the weapon choice (prefix and suffix).",
}


def reward_choices(kind, spec):
    if kind == "potions":
        return [dict(c) for c in POTIONS]
    if kind == "early":
        return armor(spec["slots"][0], EARLY)
    if kind == "late":
        return armor(spec["slots"][1], LATE)
    if kind == "weapon":
        return weapons(spec["melee"])
    raise ValueError(kind)


def shared_quests():
    """{zone: [quest]} for the shared quests, each in its first variant's
    file; Rellis' second giver of ossuary_rubbings_03 is a variant too."""
    out = {}
    for spec in SHARED:
        variants = []
        first_zone = ZONE_OF[spec["towns"][0][0]]
        for index, (town, giver, fields) in enumerate(spec["towns"]):
            row = {"zone": ZONE_OF[town], "givers": [NPC[giver]]}
            if index > 0:
                if fields.get("area"):
                    row["objectives"] = [{"roles": list(spec["objectives"][0]["roles"]), "area": fields["area"]}]
                elif fields.get("place"):
                    row["objectives"] = [{"place": fields["place"]}]
            row["text"] = PH + fields["text"] + TBD
            variants.append(row)
        quest = {
            "id": spec["id"], "line": spec["line"], "min_level": spec["min_level"], "level": spec["level"],
            "requires": [], "title": PH + spec["title"], "text": PH + spec["towns"][0][2]["text"] + TBD,
            "objectives": [dict(o) for o in spec["objectives"]], "variants": variants,
        }
        rewards = {"weight": spec["rewards"]["weight"]}
        if spec["rewards"].get("choices"):
            rewards["choices"] = reward_choices(spec["rewards"]["choices"], None)
        quest["rewards"] = rewards
        quest.update({"lesson": spec["lesson"], "duration_min": spec["duration_min"],
                      "notes": "Round 60 BANDQUESTS. " + spec["notes"]})
        out.setdefault(first_zone, []).append(quest)
    return out


def rubbings_03():
    """ossuary_rubbings_03 (id and talk objective kept, T3's prerequisite):
    Mereth's free travel to Neris, Rellis a second giver (line `camp`)."""
    text = ("Mereth Rubbinghand, or Rellis Shalemark at the guild camp, sends the player to Neris Fossilhand, "
            "who explains the fresh cuts on overwritten names and the stolen chisel.")
    return {
        "id": "ossuary_rubbings_03", "line": "camp", "min_level": 25, "level": 26, "requires": [],
        "title": PH + "A Chisel Leaves Its Signature", "text": PH + text + TBD,
        "objectives": [talk("neris")],
        "variants": [{"zone": "kragmar_ossuary_reach", "givers": [NPC["mereth"], NPC["rellis"]],
                      "turnins": [NPC["neris"]], "text": PH + text + TBD}],
        "rewards": {"weight": 1.5}, "lesson": "A travel quest with two givers in one zone.",
        "duration_min": 10,
        "notes": "Round 60 BANDQUESTS: the id stays (round60-plan.md §3: lane CAPITALS' T3 requires it, its one "
                 "Throng follow-up); free, it requires nothing.",
    }


def local_quests(town):
    spec = LOCAL[town]
    rows = []
    for q in spec["quests"]:
        giver = NPC[q["giver"]]
        row = {"id": q["id"], "line": q["line"], "giver": giver, "turnin": NPC[q.get("turnin", q["giver"])],
               "min_level": q["min_level"], "level": q["level"], "requires": list(q.get("requires", []))}
        if q.get("story"):
            row["story"] = True
        row["title"] = PH + q["title"]
        row["text"] = PH + q["text"] + TBD
        if q.get("completion"):
            row["completion"] = PH + q["completion"] + TBD
        row["objectives"] = q["objectives"]
        if q.get("quest_drops"):
            row["quest_drops"] = q["quest_drops"]
        row["rewards"] = {"weight": q["weight"]}
        if q.get("choices"):
            row["rewards"]["choices"] = reward_choices(q["choices"], spec)
        if q.get("story"):
            row["lesson"] = "Chapter 2 of the story arc (story, may chain)."
        elif q["objectives"][0]["type"] == "talk":
            row["lesson"] = "A travel quest, free (a level only)."
        else:
            row["lesson"] = LESSONS.get(q.get("choices"), "A local task of the zone's own people.")
        row["duration_min"] = q["duration"]
        note = q.get("notes") or ("The id stays (its objectives are unchanged)." if q.get("kept") else
                                  "Free play, a level only.")
        row["notes"] = "Round 60 BANDQUESTS. " + note
        rows.append(row)
    return rows


def hubs(shipped):
    """The shipped hubs with the givers' lines of LINES."""
    lines_of = {NPC[name]: lines for name, lines in LINES.items()}
    out = []
    for hub in shipped:
        hub = json.loads(json.dumps(hub))
        for giver in hub["givers"]:
            if giver["npc"] in lines_of:
                giver["lines"] = list(lines_of[giver["npc"]])
        out.append(hub)
    return out


# The text fields (lane BANDTEXT's): --check compares the rest, the structure.
TEXT_FIELDS = ("title", "text", "texts", "completion")
VARIANT_TEXT_FIELDS = ("text", "completion")


def structure(text):
    """A quest file's JSON without its texts (titles, texts, a giver's or
    race's texts, completions, a variant's text and completion): ids, hubs,
    givers and turn-ins, lines, levels, requirements, story, objectives,
    places, rewards and the design notes."""
    data = json.loads(text)
    for quest in data.get("quests") or []:
        for key in TEXT_FIELDS:
            quest.pop(key, None)
        for variant in quest.get("variants") or []:
            for key in VARIANT_TEXT_FIELDS:
                variant.pop(key, None)
    return data


def build():
    shared = shared_quests()
    files = {}
    for zone, town in ZONES:
        path = QUESTS / ("%s.quests.json" % zone)
        data = json.loads(path.read_text(encoding="utf-8"))
        guild = [q for q in data["quests"] if q["id"] in GUILD_IDS]
        quests = shared.get(zone, []) + local_quests(town)
        if town == "ossuary":
            quests.append(rubbings_03())
        out = {"zone": data["zone"], "reworked": True, "identity": data["identity"],
               "hubs": hubs(data["hubs"]), "quests": quests + guild}
        files[path] = json.dumps(out, indent=2, ensure_ascii=False) + "\n"
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    files = build()
    if args.check:
        differ = [p for p, text in files.items() if structure(p.read_text(encoding="utf-8")) != structure(text)]
        for p in differ:
            print("differs: %s" % p.relative_to(REPO))
        print("build_structure: %d files, %d differ" % (len(files), len(differ)))
        return 1 if differ else 0
    differ = [p for p, text in files.items() if p.read_text(encoding="utf-8") != text]
    for p, text in files.items():
        p.write_text(text, encoding="utf-8")
    print("build_structure: wrote %d files (%d changed)" % (len(files), len(differ)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
