#!/usr/bin/env python3
"""Round 61 lane BANDQUESTS: write the band 31-40's quest structure.

The six contested band zones' quest files (Stormvault Heights, Ashenward
March, Glassroot Wilds of The Accord; Blackwind Rise, Bannerbreak Mesa,
Thunderroot Wilds of The Throng) are rebuilt on the Round 57 quest
foundation (docs/design/quests.md "The band 31-40"), from the story chapter
the user picked (round61-plan.md §2, §2a; chapter 3, every recommendation
K1-K13 "A", with the feasibility check's fixes):

- the shared tasks (one quest, one level, one title, a variant per zone,
  every host giver on the line `border`): the Corn (`border_meal`: Toren,
  Drek), the Melons (`border_melons`: Faeris, Rumela), the Chests
  (`border_stores`: Faeris, Orrel, Rumela), the Runner's Packet
  (`border_packets`, K10 A: a quest-only drop from the bandit archers of the
  six Round 20 bandit camps, an area per variant) and the reserve at the own
  mining camp's held load (`border_reserve`: Nella, Yarra);
- the zones' own tasks: the errands, the uses at the new recipe places and
  the camps' held loads, the zone's weapon on its solo quest (Scrip's and
  Rattle's in Ashenward and Bannerbreak, ids kept; a use at a new place in
  the other four), one optional group quest per zone (the elite leader:
  free, standalone, a trinket choice), the travels (ids kept, requiring
  nothing) and the departures at 40;
- chapter 3: A5 `story_accord_05` (Toren, the Ashenward Broken Load, to
  Audra Wainholt, the Ashenward camp's foreman; requires A4 and Scrip's
  `ashenward_rations_03`), A6 `story_accord_06` (the three Accord band
  foremen to Nella; requires A5 and the camp raid), T4 `story_throng_05`
  (Drek, the Bannerbreak Scattered Load, to Greda Stonehaul, the Bannerbreak
  camp's foreman; requires T3 and Rattle's `bannerbreak_ramp_03`) and T5
  `story_throng_06` (the three Throng band foremen to Yarra; requires T4 and
  the camp raid);
- the main line (41-60) in the two contested base files, only marked
  `story` (ids, objectives, levels, requires, lines, texts unchanged);
- the Round 58 guild content as shipped (`guild_t4_report_*`,
  `camp_hunt_t4`, `camp_hunt_t4_night`, `camp_site_raid`).

Every file is marked `"reworked": true`: free quests require only a level,
only story quests chain.

This script wrote the structure once with placeholder texts ("[PH] ...";
each names the draft's intent for the text lane); the texts are lane
BANDTEXT's, and once they land the JSON files are their source: rerunning
it without --check writes the placeholders back (the main line's texts are
the files' own and stay). Run from the repository root:

    python3 tools/r61_bandquests/build_structure.py [--check]

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
    ("elandor_stormvault_heights", "stormvault"),
    ("elandor_ashenward_march", "ashenward"),
    ("elandor_glassroot_wilds", "glassroot"),
    ("kragmar_blackwind_rise", "blackwind"),
    ("kragmar_bannerbreak_mesa", "bannerbreak"),
    ("kragmar_thunderroot_wilds", "thunderroot"),
]
ZONE_OF = {short: zone for zone, short in ZONES}

# The givers (grug_quests/npcs.lua: the Round 20 hosts; the Round 58
# foremen by their camp ids, the Ashenward and Bannerbreak ones titled Audra
# Wainholt and Greda Stonehaul since this round).
NPC = {
    "borin": "r20_anchor_027_host", "alna": "r20_anchor_028_host", "toren": "r20_anchor_031_host",
    "nella": "r20_anchor_032_host", "faeris": "r20_anchor_036_host", "vaska": "r20_anchor_039_host",
    "orrel": "r20_anchor_040_host", "drek": "r20_anchor_043_host", "yarra": "r20_anchor_044_host",
    "rumela": "r20_anchor_048_host",
}
FOREMAN = {short: "r58_foreman_mining_camp_" + zone.split("_", 1)[1] for zone, short in ZONES}
for short, npc in FOREMAN.items():
    NPC["foreman_" + short] = npc

# The givers' lines (at most two per giver, validate.lua): a shared quest
# needs one line every NPC giver of it has, so the hosts that give the
# shared quests carry `border` (the draft's line plan, §10), in place of
# their old local line beside `front` (Alna, Toren, Nella, Orrel, Drek,
# Yarra) or of their first line (Faeris, Rumela, who have no `front`).
# Borin's `passes` and Vaska's `ashes` give no shared quest and stay; the
# foremen keep `camp` and `guild`.
LINES = {
    "alna": ["border", "front"], "toren": ["border", "front"], "nella": ["border", "front"],
    "faeris": ["border", "canopy"], "orrel": ["border", "front"], "drek": ["border", "front"],
    "yarra": ["border", "front"], "rumela": ["border", "rainchar"],
}

HEALING = "grug_alchemy:potion_healing_t4"
MANA = "grug_alchemy:potion_mana_t4"
POTIONS = [{"item": HEALING, "count": 2}, {"item": MANA, "count": 2}]
PACKET = "grug_mobs:runners_packet"
# The tier-4 trinkets (grug_gear/trinkets.lua), plain: an extra for the
# optional group quests that carries no enchant (no reward budget).
TRINKETS_A = ["grug_gear:manawell_t4", "grug_gear:battlebeat_t4", "grug_gear:mercy_seal_t4"]
TRINKETS_B = ["grug_gear:last_light_t4", "grug_gear:apothecary_loop_t4", "grug_gear:reclaimers_mark_t4"]


def held_load(short):
    return "socket:mining_camp_%s/held_load" % ZONE_OF[short].split("_", 1)[1]


def kill(roles, count, area=None):
    row = {"type": "kill", "roles": list(roles), "count": count}
    if area:
        row["area"] = area
    return row


def item(name, count):
    return {"type": "item", "item": name, "count": count}


def talk(who):
    return {"type": "talk", "npc": NPC[who]}


def use(place, obj, label, hold):
    return {"type": "use", "place": place, "object": obj, "label": label, "hold": hold}


def armor(slot, affix):
    """One T4 armor piece per armor class (cloth, leather, metal), each with
    one author-fixed enchant: `affix` maps the class to (channel, stat)."""
    items = {"cloth": "grug_gear:%s_cloth_silkweave" % slot,
             "leather": "grug_gear:%s_leather_scaled" % slot,
             "metal": "grug_gear:%s_metal_silversteel" % slot}
    return [{"item": items[c], "affixes": [{"channel": affix[c][0], "stat": affix[c][1]}]}
            for c in ("cloth", "leather", "metal")]


# The first piece: the class's main stat as a prefix; the second (the
# Runner's Packet, late): a second stat as a suffix (grug_quality POOLS), as
# the bands 11-30.
EARLY = {"cloth": ("prefix", "int"), "leather": ("prefix", "dex"), "metal": ("prefix", "str")}
LATE = {"cloth": ("suffix", "max_mana_percent"), "leather": ("suffix", "crit_percent"),
        "metal": ("suffix", "max_hp_percent")}


def weapons(melee):
    """The zone's weapon choice: one T4 weapon per weapon line (caster,
    scout, warrior; Priest and Mage share), prefix and suffix each; the
    two-handed Staff where the Battle Axe is offered, the Wand beside the
    Sword."""
    caster = "grug_gear:staff_silversteel" if melee == "greataxe" else "grug_gear:wand_silversteel"
    warrior = {"sword": ("grug_gear:sword_silversteel", "crit_percent"),
               "greataxe": ("grug_gear:greataxe_silversteel", "max_hp_percent")}[melee]
    return [
        {"item": caster, "affixes": [{"channel": "prefix", "stat": "int"},
                                     {"channel": "suffix", "stat": "max_mana_percent"}]},
        {"item": "grug_gear:bow_silversteel", "affixes": [{"channel": "prefix", "stat": "dex"},
                                                          {"channel": "suffix", "stat": "attack_speed_percent"}]},
        {"item": warrior[0], "affixes": [{"channel": "prefix", "stat": "str"},
                                         {"channel": "suffix", "stat": warrior[1]}]},
    ]


def reward_choices(kind, melee=None):
    if kind == "potions":
        return [dict(c) for c in POTIONS]
    if kind.startswith("early:"):
        return armor(kind.split(":")[1], EARLY)
    if kind.startswith("late:"):
        return armor(kind.split(":")[1], LATE)
    if kind == "weapon":
        return weapons(melee)
    if kind in ("trinkets_a", "trinkets_b"):
        return [{"item": t} for t in (TRINKETS_A if kind == "trinkets_a" else TRINKETS_B)]
    raise ValueError(kind)


# ---------------------------------------------------------------- shared
# One quest, one level, one title each; each variant: its zone's giver, its
# zone-bound fields (use place, quest drop area) and its placeholder text.
# The first variant's zone is the quest's home (its own objectives).
# Every zone gives two one-enchant armor choices (E-reward-budget's limit;
# a shared quest counts in every zone that gives it) and a player takes a
# shared quest once, so armor sits only on shared quests given once per
# faction (the Melons: feet, the reserve: chest, both a prefix) and each
# faction's three zones give six pieces, every slot at least once
# (round61-plan.md §2 point 4; the review's fix): the Runner's Packet, given
# in all six zones, pays a potion choice.
SHARED = [
    {
        "id": "border_meal", "min_level": 31, "level": 32,
        "title": "A Meal Before the Road",
        "objectives": [item("grug_gathering:corn", 8)],
        "rewards": {"weight": 5, "choices": "potions"},
        "lesson": "A shared errand, a level only; the zone's early potion choice.",
        "duration_min": 8,
        "notes": "Draft §3 'A Meal Before the Road': Corn for the crews before the next run (Toren, Drek).",
        "towns": [
            ("ashenward", "toren", {"text": "Toren Waterbarrel feeds the crews before their next run: bring 8 "
                                            "Corn."}),
            ("bannerbreak", "drek", {"text": "Drek Rampbinder feeds the ramp crews before the next shift: bring "
                                             "8 Corn."}),
        ],
    },
    {
        "id": "border_melons", "min_level": 30, "level": 31,
        "title": "Something Fresh for the Carriers",
        "objectives": [item("grug_gathering:melon", 5)],
        "rewards": {"weight": 5, "choices": "early:feet"},
        "lesson": "A shared errand, the zone's first; the first armor choice (one enchant, a prefix).",
        "duration_min": 9,
        "notes": "Draft §3 'Something Fresh for the Carriers': Melons for the carriers (Faeris, Rumela).",
        "towns": [
            ("glassroot", "faeris", {"text": "Faeris Rootbinder wants the carriers on the grown paths to have "
                                             "something fresh: bring 5 Melons."}),
            ("thunderroot", "rumela", {"text": "Rumela Stormstep's carriers come back soaked and hungry: bring 5 "
                                               "Melons."}),
        ],
    },
    {
        "id": "border_stores", "min_level": 31, "level": 32,
        "title": "Keep the Stores Dry",
        "objectives": [item("default:chest", 3)],
        "rewards": {"weight": 5, "choices": "potions"},
        "lesson": "A shared errand, a level only; the zone's early potion choice.",
        "duration_min": 8,
        "notes": "Draft §3 'Keep the Stores Dry': dry keeping for stores, personal effects and message gear "
                 "(Faeris, Orrel, Rumela).",
        "towns": [
            ("glassroot", "faeris", {"text": "Faeris needs Chests so stores and spare material stay usable "
                                             "between runs: bring 3 Chests."}),
            ("blackwind", "orrel", {"text": "Orrel Hollowstep keeps recovered belongings dry until they go "
                                            "home: bring 3 Chests."}),
            ("thunderroot", "rumela", {"text": "Rumela keeps message gear and stores dry between the rains: bring "
                                               "3 Chests."}),
        ],
    },
    {
        "id": "border_packets", "min_level": 38, "level": 39,
        "title": "Words Worth Bringing Back",
        "objectives": [item(PACKET, 1)],
        "quest_drops": [{"item": PACKET, "chance": 3, "roles": ["entrenched_bandit_archer"],
                         "area": "elandor_stormvault_heights/slatehook"}],
        "rewards": {"weight": 6, "choices": "potions"},
        "lesson": "A shared quest drop from the bandit archers of the zone's Round 20 bandit camp (an area per "
                  "variant); a potion choice (given in all six zones, so no armor: the reward budget).",
        "duration_min": 12,
        "notes": "Draft §3 'Words Worth Bringing Back' (K10 A): the Runner's Packet, a soulbound quest-only item "
                 "(local messages, no proof of the front's plot), drops 1 in 3 from the camp's archers while "
                 "needed; the area keeps Blackwind's hideout archers out. Done once everywhere: no other text "
                 "claims a second camp.",
        "towns": [
            ("stormvault", "alna", {"area": "elandor_stormvault_heights/slatehook",
                                    "text": "Alna Archsight wants the intercepted messages back from the "
                                            "Waylayers at {name:slatehook}: bring a Runner's Packet."}),
            ("ashenward", "nella", {"area": "elandor_ashenward_march/coalbrand_yard",
                                    "text": "Nella Hedgeward wants the shift reports the Hedge Bowmen at "
                                            "{name:coalbrand_yard} took: bring a Runner's Packet."}),
            ("glassroot", "faeris", {"area": "elandor_glassroot_wilds/rootsnare",
                                     "text": "Faeris wants the carriers' messages back from the Bandit "
                                             "Fletchers at {name:rootsnare}: bring a Runner's Packet."}),
            ("blackwind", "orrel", {"area": "kragmar_blackwind_rise/pallcloth_den",
                                    "text": "Orrel wants the word of returned crews back from the Shroud "
                                            "Archers at {name:pallcloth_den}: bring a Runner's Packet."}),
            ("bannerbreak", "yarra", {"area": "kragmar_bannerbreak_mesa/sunderstrap_camp",
                                      "text": "Yarra Standardmender wants the questions about late deliveries "
                                              "back from the Trench Archers at {name:sunderstrap_camp}: bring a "
                                              "Runner's Packet."}),
            ("thunderroot", "rumela", {"area": "kragmar_thunderroot_wilds/rainchar_camp",
                                       "text": "Rumela wants her carriers' messages back from the Brigand "
                                               "Bowmen at {name:rainchar_camp}: bring a Runner's Packet."}),
        ],
    },
    {
        "id": "border_reserve", "min_level": 30, "level": 31,
        "title": "The Reserve Is for Them",
        "objectives": [use(held_load("ashenward"), "held_supplies", "Ready the reserve load", 4)],
        "rewards": {"weight": 5, "choices": "early:chest"},
        "lesson": "A shared use at the own mining camp's held load, once per faction; free, it needs neither "
                  "Scrip nor the story; the first armor choice (one enchant, a prefix).",
        "duration_min": 8,
        "notes": "Draft §3 and §4.2/§4.5 'The Reserve Is for Them': a replacement load already set aside at the "
                 "camp's loading ground, made ready for issue (Nella, Yarra).",
        "towns": [
            ("ashenward", "nella", {"place": held_load("ashenward"),
                                    "text": "Nella wants the replacement load at the guild camp's loading "
                                            "ground made ready for issue to her returning crews."}),
            ("bannerbreak", "yarra", {"place": held_load("bannerbreak"),
                                      "text": "Yarra wants the replacement load at the guild camp's loading "
                                              "ground made ready for the crews it was promised to."}),
        ],
    },
]

# ---------------------------------------------------------------- local
# Rows: id, giver, line, min level, level, objectives, weight, title, text
# (the intent), and optional turnin, choices, completion, requires, story,
# group, kept, duration, notes. A kept id keeps its objectives; every other
# id is new (round61-plan.md §3), but Rattle's (the brief: its quest asks
# only for Rattle now).
LOCAL = {
    "stormvault": {
        "melee": "greataxe",
        "quests": [
            {"id": "stormvault_passes_03", "giver": "borin", "line": "passes", "min_level": 30, "level": 31,
             "objectives": [item("grug_materials:silversteel_bar", 4)], "weight": 5, "choices": "early:head",
             "kept": True,
             "title": "A Proper Introduction to Rock",
             "text": "Borin Splitbolt keeps his tool occasion: bring 4 Silversteel Bars for the station's "
                     "picks, explained by today's crafting path.", "duration": 9},
            {"id": "stormvault_frostfin", "giver": "borin", "line": "passes", "min_level": 31, "level": 32,
             "objectives": [item("grug_fishing:frostfin", 4)], "weight": 5, "choices": "potions",
             "title": "A Meal With Some Variety",
             "text": "Borin wants his people at the station to eat something other than rations: bring 4 "
                     "Frostfin.", "duration": 10},
            {"id": "stormvault_road_ashenward", "giver": "borin", "line": "passes", "min_level": 30,
             "level": 31, "objectives": [talk("toren")], "weight": 1, "turnin": "toren", "kept": True,
             "title": "Word for Cinderline Watch",
             "text": "Borin sends the player to Toren Waterbarrel at Cinderline Watch, whose supplies feed the "
                     "same road; no earlier deed is claimed.", "duration": 10},
            {"id": "stormvault_road_archshadow", "giver": "borin", "line": "passes", "min_level": 32,
             "level": 33, "objectives": [talk("alna")], "weight": 1, "turnin": "alna", "kept": True,
             "title": "Alna Needs Good Eyes",
             "text": "Borin points the player to Alna Archsight at Archshadow Post, who needs usable "
                     "observations before the next load leaves.", "duration": 8},
            {"id": "stormvault_sighting_04", "giver": "alna", "line": "border", "min_level": 33, "level": 34,
             "objectives": [item("grug_materials:emberglass", 2)], "weight": 5, "choices": "late:legs",
             "kept": True,
             "title": "A Clearer View of Trouble",
             "text": "Alna needs Emberglass for the post's observation work, free beside Borin's request: "
                     "bring 2 Emberglass.", "duration": 14},
            {"id": "stormvault_survey_stand", "giver": "alna", "line": "border", "min_level": 36, "level": 37,
             "objectives": [use("survey_stand", "sighting_frame", "Set the sighting frame", 4)], "weight": 7,
             "choices": "weapon",
             "title": "A Reliable Stand",
             "text": "Alna wants her prepared sighting frame set back on its marked stand at the "
                     "{name:survey_stand} in the {name:highcrags}; no measured line of sight is asked.",
             "completion": "Alna's observers work from a fixed reference again.",
             "notes": "K6 A: the zone's solo quest with its weapon, at a new recipe place in the Highcrags.",
             "duration": 12},
            {"id": "stormvault_sighting_05", "giver": "alna", "line": "border", "min_level": 38, "level": 39,
             "objectives": [kill(["split_seam_warden"], 1)], "weight": 6, "choices": "trinkets_a",
             "group": True, "kept": True,
             "title": "Party: A Crack Is Not a Weakness",
             "text": "Alna asks for a party against {name:split_seam_warden} in the {name:stormcrags}, who "
                     "threatens the high work paths; optional, nothing needs it.",
             "notes": "The optional group quest (round61-plan.md §2 point 8): free, standalone, a trinket "
                      "choice as its extra; the survey stand needs neither its kill nor its spot.",
             "duration": 15},
            {"id": "stormvault_road_last_hedge", "giver": "alna", "line": "border", "min_level": 40, "level": 40,
             "objectives": [talk("nella")], "weight": 1, "turnin": "nella",
             "title": "Last Hedge Needs Observers",
             "text": "Alna sends the player to Nella Hedgeward at Last Hedge Redoubt, where the front's work "
                     "begins at once; no earlier deed is claimed.",
             "notes": "The departure at 40 (round61-plan.md §2 point 7): Alna's own front quests start at 44.",
             "duration": 10},
        ],
    },
    "ashenward": {
        "melee": "sword",
        "quests": [
            {"id": "ashenward_buckets", "giver": "toren", "line": "border", "min_level": 31, "level": 32,
             "objectives": [item("grug_farming:empty_iron_bucket", 3)], "weight": 5, "choices": "late:legs",
             "title": "Water Has to Be Shared Out",
             "text": "Toren needs Iron Buckets to issue water from the barrels that came in: bring 3 Iron "
                     "Buckets; empty ones will do.", "duration": 9},
            {"id": "ashenward_rations_03", "giver": "toren", "line": "border", "min_level": 32, "level": 33,
             "objectives": [kill(["quartermaster_scrip"], 1)], "weight": 7, "choices": "weapon", "kept": True,
             "title": "The Account of Quartermaster Scrip",
             "text": "Toren sends the player alone against {name:quartermaster_scrip} at the "
                     "{name:ration_camp}, who sells the supply under the line's own seal.",
             "completion": "Toren confirms Scrip's books never explained the empty bowls; in passing, "
                           "Requisition Clerk Odren Vell takes over the convoy books, a hand-over and nothing "
                           "more.",
             "notes": "The id stays (round61-plan.md §2 point 2: A5's free prerequisite); free, it requires "
                      "nothing; its one Accord follow-up is A5. The zone's weapon (§2a point 6).",
             "duration": 10},
            {"id": "ashenward_road_stormvault", "giver": "toren", "line": "border", "min_level": 30,
             "level": 31, "objectives": [talk("borin")], "weight": 1, "turnin": "borin", "kept": True,
             "title": "Splitbolt Needs Hands",
             "text": "Toren sends the player to Borin Splitbolt at Splitbolt Station with today's need for "
                     "help; Scrip is not assumed.", "duration": 10},
            {"id": "ashenward_road_glassroot", "giver": "toren", "line": "border", "min_level": 30,
             "level": 31, "objectives": [talk("faeris")], "weight": 1, "turnin": "faeris", "kept": True,
             "title": "The Grown Road",
             "text": "Toren sends the player to Faeris Rootbinder at Glassroot Gate, whose carriers use the "
                     "same supply; Scrip is not assumed.", "duration": 10},
            {"id": "ashenward_road_last_hedge", "giver": "toren", "line": "border", "min_level": 30,
             "level": 31, "objectives": [talk("nella")], "weight": 1, "turnin": "nella", "kept": True,
             "title": "Who Comes Back to Last Hedge",
             "text": "Toren sends the player to Nella Hedgeward at Last Hedge Redoubt, who sees who arrives at "
                     "the end of these roads; Scrip is not assumed.", "duration": 8},
            {"id": "ashenward_hedge_04", "giver": "nella", "line": "border", "min_level": 38, "level": 39,
             "objectives": [kill(["red_receipt_marshal"], 1)], "weight": 6, "choices": "trinkets_b",
             "group": True, "kept": True,
             "title": "Party: The Marshal's Receipts",
             "text": "Nella asks for a party against {name:red_receipt_marshal} at the {name:poacher_camp}, "
                     "who trades in stolen supplies; optional, nothing needs it.",
             "notes": "The optional group quest (round61-plan.md §2 point 8): free, standalone (the poacher "
                      "hunt before it is gone), a trinket choice as its extra; no story proof lies with him.",
             "duration": 15},
            # Chapter 3 (round61-plan.md §2 point 2, draft §5).
            {"id": "story_accord_05", "giver": "toren", "line": "border", "min_level": 34, "level": 35,
             "story": True, "requires": ["story_accord_04", "ashenward_rations_03"],
             "turnin": "foreman_ashenward",
             "objectives": [use("broken_load", "dispatch_record", "Secure the transport record", 4)],
             "weight": 5.5, "choices": "potions",
             "title": "Every Hand on the Road",
             "text": "Toren knows the raided transport's load is lost; he wants its remaining transport record "
                     "secured at the {name:broken_load} in the {name:wheelbreak} and taken to Audra Wainholt, "
                     "the foreman of the guild camp.",
             "completion": "Audra reads which drivers came back, what they salvaged and whom they brought; "
                           "the loss is assigned and the right help can be prepared (K2 A).",
             "notes": "A5 (story, 34): requires A4 and Scrip's free quest (its one Accord follow-up); turned in "
                      "at the Ashenward mining camp's foreman, titled Audra Wainholt (K12 A).",
             "duration": 12},
        ],
    },
    "glassroot": {
        "melee": "sword",
        "quests": [
            {"id": "glassroot_ladders", "giver": "faeris", "line": "canopy", "min_level": 34, "level": 35,
             "objectives": [item("default:ladder_wood", 10)], "weight": 5, "choices": "late:head",
             "title": "Rungs for the High Paths",
             "text": "Faeris's carriers climb between the grown paths of the Canopy on rungs the rain has rotted: "
                     "bring 10 Wooden Ladders.", "duration": 8,
             "notes": "The review's fix (round61-plan.md §2 point 4): Glassroot's own errand for the Accord's "
                      "sixth armor piece (a Basic recipe, made anywhere; not Melon, not a gated herb)."},
            {"id": "glassroot_road_ashenward", "giver": "faeris", "line": "canopy", "min_level": 30,
             "level": 31, "objectives": [talk("toren")], "weight": 1, "turnin": "toren", "kept": True,
             "title": "Supplies Through Cinderline",
             "text": "Faeris sends the player to Toren Waterbarrel at Cinderline Watch, where the same supply "
                     "problems run; no earlier deed is claimed.", "duration": 10},
            {"id": "glassroot_carrier_path", "giver": "faeris", "line": "canopy", "min_level": 38, "level": 39,
             "objectives": [use("carrier_path", "snare_bundle", "Loosen the snare", 4)], "weight": 7,
             "choices": "weapon",
             "title": "A Path for Those Coming Back",
             "text": "Faeris wants a prepared snare on the carriers' path loosened at the {name:carrier_path} "
                     "in the {name:canopy}, so her wardens can watch that stretch again.",
             "completion": "The stretch of path is usable again; a concrete relief, nothing more.",
             "notes": "K7 A: the zone's solo quest with its weapon, at a new recipe place in the Canopy, 64 "
                      "nodes from Canopy-Knuckle (the place rule).",
             "duration": 12},
            {"id": "glassroot_canopy_05", "giver": "faeris", "line": "canopy", "min_level": 38, "level": 39,
             "objectives": [kill(["canopy_knuckle"], 1)], "weight": 6, "choices": "trinkets_a",
             "group": True, "kept": True,
             "title": "Party: The Canopy's Own King",
             "text": "Faeris asks for a party against {name:canopy_knuckle} in the {name:canopy}, who has "
                     "hurt her wardens and broken their bows; optional, nothing needs it.",
             "notes": "The optional group quest (round61-plan.md §2 point 8): free, standalone, a trinket "
                      "choice as its extra.",
             "duration": 15},
            {"id": "glassroot_road_front", "giver": "faeris", "line": "canopy", "min_level": 40, "level": 40,
             "objectives": [talk("nella")], "weight": 1, "turnin": "nella", "kept": True,
             "title": "Where the Front Begins",
             "text": "Faeris sends the player to Nella Hedgeward at Last Hedge Redoubt; Canopy-Knuckle's fall "
                     "is not assumed.",
             "notes": "The departure at 40 (round61-plan.md §2 point 7); free, it requires nothing.",
             "duration": 10},
        ],
    },
    "blackwind": {
        "melee": "sword",
        "quests": [
            {"id": "blackwind_mushrooms", "giver": "vaska", "line": "ashes", "min_level": 30, "level": 31,
             "objectives": [item("grug_gathering:mushroom", 6)], "weight": 5, "choices": "early:head",
             "title": "Something for Those Who Wait",
             "text": "Vaska Ashlistener feeds the carriers and escorts who arrive at Ashveil Watch: bring 6 "
                     "Mushrooms.", "duration": 9},
            {"id": "blackwind_ashes_03", "giver": "vaska", "line": "ashes", "min_level": 30, "level": 31,
             "objectives": [talk("drek")], "weight": 1, "turnin": "drek", "kept": True,
             "title": "Ramps on the Mesa",
             "text": "Vaska sends the player to Drek Rampbinder at Red Ramp Post on Bannerbreak Mesa; no "
                     "earlier deed is claimed.", "duration": 10},
            {"id": "blackwind_ashes_04", "giver": "vaska", "line": "ashes", "min_level": 30, "level": 31,
             "objectives": [talk("orrel")], "weight": 1, "turnin": "orrel", "kept": True,
             "title": "Orrel Keeps What Is Left",
             "text": "Vaska sends the player to Orrel Hollowstep at Hollowarch Station, who keeps things usable "
                     "that someone will want to speak of with dignity.", "duration": 8},
            {"id": "blackwind_signal_lantern", "giver": "vaska", "line": "ashes", "min_level": 32, "level": 33,
             "objectives": [use(held_load("blackwind"), "signal_lantern", "Trim the signal lantern", 4)],
             "weight": 5, "choices": "late:chest",
             "title": "A Light for the Late Road",
             "text": "Vaska wants a signal lantern made ready on the loading ground of the guild camp, so late "
                     "arrivals have a light to steer by.", "duration": 9,
             "notes": "K11 A: the camp's held load (a town place every mining camp has)."},
            {"id": "blackwind_recovery_rest", "giver": "orrel", "line": "border", "min_level": 38, "level": 39,
             "objectives": [use("recovery_rest", "held_supplies", "Secure the shroud bundle", 4)], "weight": 7,
             "choices": "weapon",
             "title": "The Names Stay With the Cloth",
             "text": "Orrel wants a left-behind bundle of stolen shrouds, their owners' labels still on them, "
                     "secured at the {name:recovery_rest}, high in the zone.",
             "completion": "Orrel can organise the return to the right people; the kept label is the success.",
             "notes": "K8 A: the zone's solo quest with its weapon, at a new recipe place in the Deadmarch (the "
                      "38-40 moor; it falls back to the belt's woods where the moor forms no region, seed 42, "
                      "so the text names the place, not the kind).",
             "duration": 12},
            {"id": "blackwind_arch_group", "giver": "orrel", "line": "border", "min_level": 38, "level": 39,
             "objectives": [kill(["hollowbell_treant"], 1)], "weight": 6, "choices": "trinkets_b",
             "group": True, "kept": True,
             "title": "Party: The Bell in the Wood",
             "text": "Orrel asks for a party against {name:hollowbell_treant} in the {name:hollowwood}, whose "
                     "ringing makes the high wood dangerous; optional, nothing needs it.",
             "notes": "The optional group quest (round61-plan.md §2 point 8): free, standalone, a trinket "
                      "choice as its extra; the recovery rest lies away from it.",
             "duration": 15},
            {"id": "blackwind_road_red_ramp", "giver": "orrel", "line": "border", "min_level": 40, "level": 40,
             "objectives": [talk("drek")], "weight": 1, "turnin": "drek",
             "title": "Work Waiting at Red Ramp",
             "text": "Orrel sends the player to Drek Rampbinder at Red Ramp Post, where front work waits at "
                     "once; no earlier deed is claimed.",
             "notes": "The departure at 40 (round61-plan.md §2 point 7): Orrel's and Vaska's front lines start "
                      "at 46 and 53.",
             "duration": 10},
        ],
    },
    "bannerbreak": {
        "melee": "greataxe",
        "quests": [
            {"id": "bannerbreak_ramp_02", "giver": "drek", "line": "border", "min_level": 30, "level": 31,
             "objectives": [talk("yarra")], "weight": 1, "turnin": "yarra", "kept": True,
             "title": "Yarra Keeps the Names",
             "text": "Drek sends the player to Yarra Standardmender at Tornstandard Hold, who knows the people "
                     "behind the banners.", "duration": 8},
            {"id": "bannerbreak_ramp_03", "giver": "drek", "line": "border", "min_level": 34, "level": 35,
             "objectives": [kill(["provisioner_rattle"], 1)], "weight": 7, "choices": "weapon", "kept": True,
             "title": "Rattle's Bad Arithmetic",
             "text": "Drek sends the player alone against {name:provisioner_rattle} at the {name:supply_camp}, "
                     "who turned the camp workers' next working day into goods.",
             "completion": "The damage to ramp work, camp work and supply is named; no deal with the enemy "
                           "guild is claimed.",
             "notes": "The id stays (round61-plan.md §2 point 2: T4's free prerequisite); free, it requires "
                      "nothing; its one Throng follow-up is T4. Only Rattle now (the check: the Sapper and "
                      "Slinger count goes), the leader at 35 (subtypes.json). The zone's weapon (§2a point 6).",
             "duration": 10},
            {"id": "bannerbreak_standard_02", "giver": "yarra", "line": "border", "min_level": 30, "level": 31,
             "objectives": [talk("rumela")], "weight": 1, "turnin": "rumela", "kept": True,
             "title": "Word for Thunderstep",
             "text": "Yarra sends the player to Rumela Stormstep at Thunderstep Watch, who keeps the carriers "
                     "connected in the rain.", "duration": 10},
            {"id": "bannerbreak_standard_04", "giver": "yarra", "line": "border", "min_level": 37, "level": 38,
             "objectives": [kill(["unrelenting_husk"], 4, "kragmar_bannerbreak_mesa/redcut_flats")],
             "weight": 5, "choices": "late:legs", "kept": True,
             "title": "A Soldier's Due",
             "text": "Yarra wants the old watch of the Trench Mummies in the {name:redcut_flats} ended: "
                     "defeat 4 of them; honour does not need them standing.",
             "notes": "The id stays; free, no prerequisite, required by nothing (draft §4.5); not the camp "
                      "hunt's role (Muster Husks).",
             "duration": 10},
            {"id": "bannerbreak_standard_group", "giver": "yarra", "line": "border", "min_level": 38,
             "level": 39, "objectives": [kill(["banner_eater"], 1)], "weight": 6, "choices": "trinkets_a",
             "group": True, "kept": True,
             "title": "Party: The Banner-Eater",
             "text": "Yarra asks for a party against {name:banner_eater} at the {name:goblin_warcamp}, who "
                     "threatens the banners she sews the fallen's names into; optional, nothing needs it.",
             "notes": "The optional group quest (round61-plan.md §2 point 8): free, standalone (its old "
                      "prerequisite is gone), a trinket choice as its extra.",
             "duration": 15},
            # Chapter 3 (round61-plan.md §2 point 2, draft §5).
            {"id": "story_throng_05", "giver": "drek", "line": "border", "min_level": 35, "level": 36,
             "story": True, "requires": ["story_throng_04", "bannerbreak_ramp_03"],
             "turnin": "foreman_bannerbreak",
             "objectives": [use("scattered_load", "witness_record", "Secure the handover record", 4)],
             "weight": 5.5, "choices": "potions",
             "title": "The Hands Behind the Stores",
             "text": "Drek wants the remaining handover record of the raided load secured at the "
                     "{name:scattered_load} in the {name:warplains} and taken to Greda Stonehaul, the foreman "
                     "of the guild camp.",
             "completion": "Greda confirms which share of the promise to ramp crew, guards and guild workers "
                           "stays open; the carriers carry no blame (K3 A).",
             "notes": "T4 (story, 35): requires T3 and Rattle's free quest (its one Throng follow-up); turned "
                      "in at the Bannerbreak mining camp's foreman, titled Greda Stonehaul (K13 A).",
             "duration": 12},
        ],
    },
    "thunderroot": {
        "melee": "greataxe",
        "quests": [
            {"id": "thunderroot_storm_03", "giver": "rumela", "line": "rainchar", "min_level": 30, "level": 31,
             "objectives": [talk("vaska")], "weight": 1, "turnin": "vaska", "kept": True,
             "title": "Ashveil Listens Too",
             "text": "Rumela sends the player to Vaska Ashlistener at Ashveil Watch in Blackwind Rise; no "
                     "earlier deed is claimed.", "duration": 10},
            {"id": "thunderroot_reading_knots", "giver": "rumela", "line": "rainchar", "min_level": 32,
             "level": 33,
             "objectives": [use(held_load("thunderroot"), "reading_knots", "Secure the reading cord", 4)],
             "weight": 5, "choices": "late:legs",
             "title": "The Next Crew Should Know",
             "text": "Rumela wants a prepared reading cord with the carriers' reports secured on the loading "
                     "ground of the guild camp, for the next crew; no forecast, no riddle.", "duration": 9,
             "notes": "The camp's held load (a town place every mining camp has)."},
            {"id": "thunderroot_storm_vessel", "giver": "rumela", "line": "rainchar", "min_level": 38,
             "level": 39,
             "objectives": [use("storm_store", "storm_vessel", "Seal the storm vessel", 5)], "weight": 7,
             "choices": "weapon",
             "title": "One Stolen Storm Fewer",
             "text": "Rumela wants a stored storm vessel made useless at the {name:storm_store} in the "
                     "{name:stormglades}; no weather changes, no fight starts.",
             "completion": "A visible success of the zone's own before any party goes after Storm-Bottle.",
             "notes": "K9 A: the zone's solo quest with its weapon, at a new recipe place in the Stormglades; "
                      "the new object kind storm_vessel (the user's drop-03 P1 art).",
             "duration": 12},
            {"id": "thunderroot_rainchar_group", "giver": "rumela", "line": "rainchar", "min_level": 38,
             "level": 39, "objectives": [kill(["storm_bottle_witch"], 1)], "weight": 6, "choices": "trinkets_b",
             "group": True, "kept": True,
             "title": "Party: Storm-Bottle",
             "text": "Rumela asks for a party against {name:storm_bottle_witch} in the {name:heartwood}, whose "
                     "other stores and own violence remain; optional, nothing needs it.",
             "notes": "The optional group quest (round61-plan.md §2 point 8): free, standalone, a trinket "
                      "choice as its extra.",
             "duration": 15},
            {"id": "thunderroot_rainchar_04", "giver": "rumela", "line": "rainchar", "min_level": 40,
             "level": 40, "objectives": [talk("yarra")], "weight": 1, "turnin": "yarra", "kept": True,
             "title": "Standards at Tornstandard",
             "text": "Rumela sends the player to Yarra Standardmender at Tornstandard Hold; neither the vessel "
                     "nor Storm-Bottle is assumed.",
             "notes": "The departure at 40 (round61-plan.md §2 point 7); free, it requires nothing.",
             "duration": 10},
        ],
    },
}

# Chapter 3's closing steps: one quest each, a variant per band foreman of
# the faction, a travel to the host who points on to the Warmaster
# (round61-plan.md §2a point 5, draft §5, K5 A: pure travel).
CLOSERS = [
    {"id": "story_accord_06", "zones": ("stormvault", "ashenward", "glassroot"), "to": "nella",
     "min_level": 39, "level": 40, "requires": ["story_accord_05", "camp_site_raid"],
     "title": "The Cost of Holding Ground",
     "text": "The foreman sends the player with the evaluated report of the reported raid (own cargo with its "
             "own marks found ready for the enemy build, reached there by an open raid) to Nella Hedgeward at "
             "Last Hedge Redoubt.",
     "completion": "Nella names the open deliveries, the crews that need relief and the road the next watch "
                   "must hold, and points to the Warmaster at Ashenward Bastion.",
     "notes": "A6 (story, 39): requires A5 and the free camp raid (its one Accord follow-up); any of the three "
              "Accord band foremen gives it (a raid elsewhere counts)."},
    {"id": "story_throng_06", "zones": ("blackwind", "bannerbreak", "thunderroot"), "to": "yarra",
     "min_level": 40, "level": 40, "requires": ["story_throng_05", "camp_site_raid"],
     "title": "The Promise Still Stands",
     "text": "The foreman sends the player with the evaluated camp report (own supply laid ready for the enemy "
             "build, reached there by an open raid) to Yarra Standardmender at Tornstandard Hold.",
     "completion": "Yarra takes up the renewed delivery promise of The Oathdelvers for the original "
                   "recipients, names Tallykeeper Mardra only as the old countersignature, and points to the "
                   "Warmaster at Bannerbreak Warhold.",
     "notes": "T5 (story, 40, K1 A): requires T4 and the free camp raid (its one Throng follow-up); any of the "
              "three Throng band foremen gives it (a raid elsewhere counts)."},
]

# The Round 58 quests these files carry (kept as shipped).
GUILD_IDS = ("guild_t4_report_accord", "guild_t4_report_throng", "camp_hunt_t4", "camp_hunt_t4_night",
             "camp_site_raid")
# The main line (Round 36) in the two contested base files: only marked
# `story` (round61-plan.md §2 point 1).
MAIN_LINE = ("accord_main_impounded", "accord_main_standard", "accord_main_orders", "accord_main_audit",
             "accord_main_roll", "accord_main_stonegrudge", "accord_main_collector", "accord_main_final",
             "throng_main_01", "throng_main_03", "throng_main_04", "throng_main_05", "throng_main_greyvow",
             "throng_main_06", "throng_main_finale")

LESSONS = {
    "potions": "An early errand, a level only; the zone's potion choice.",
    "early": "A local task; the first armor choice (one enchant, a prefix).",
    "late": "A local task; the second armor choice (one enchant, a suffix).",
    "weapon": "The zone's solo quest; the weapon choice (prefix and suffix).",
    "trinkets": "The optional group quest: free, standalone, a trinket choice as its extra.",
}


def lesson_of(q):
    if q.get("story"):
        return "Chapter 3 of the story arc (story, may chain)."
    if q["objectives"][0]["type"] == "talk":
        return "A travel quest, free (a level only)."
    choices = (q.get("choices") or "").split(":")[0]
    return LESSONS.get(choices.replace("_a", "").replace("_b", ""), "A local task of the zone's own people.")


def shared_quests():
    """{zone: [quest]} for the shared quests, each in its first variant's
    file."""
    out = {}
    for spec in SHARED:
        variants = []
        first_zone = ZONE_OF[spec["towns"][0][0]]
        for index, (town, giver, fields) in enumerate(spec["towns"]):
            row = {"zone": ZONE_OF[town], "givers": [NPC[giver]]}
            if index > 0:
                if fields.get("area"):
                    row["quest_drops"] = [{"roles": list(spec["quest_drops"][0]["roles"]), "area": fields["area"]}]
                elif fields.get("place"):
                    row["objectives"] = [{"place": fields["place"]}]
            row["text"] = PH + fields["text"] + TBD
            variants.append(row)
        quest = {
            "id": spec["id"], "line": "border", "min_level": spec["min_level"], "level": spec["level"],
            "requires": [], "title": PH + spec["title"], "text": PH + spec["towns"][0][2]["text"] + TBD,
            "objectives": [dict(o) for o in spec["objectives"]],
        }
        if spec.get("quest_drops"):
            quest["quest_drops"] = [dict(d) for d in spec["quest_drops"]]
        quest["variants"] = variants
        rewards = {"weight": spec["rewards"]["weight"]}
        if spec["rewards"].get("choices"):
            rewards["choices"] = reward_choices(spec["rewards"]["choices"])
        quest["rewards"] = rewards
        quest.update({"lesson": spec["lesson"], "duration_min": spec["duration_min"],
                      "notes": "Round 61 BANDQUESTS. " + spec["notes"]})
        out.setdefault(first_zone, []).append(quest)
    return out


def closers():
    """{zone: [quest]}: A6 and T5, each in its first variant's file."""
    out = {}
    for spec in CLOSERS:
        variants = [{"zone": ZONE_OF[z], "givers": [FOREMAN[z]], "turnins": [NPC[spec["to"]]],
                     "text": PH + spec["text"] + TBD} for z in spec["zones"]]
        quest = {
            "id": spec["id"], "line": "guild", "min_level": spec["min_level"], "level": spec["level"],
            "requires": list(spec["requires"]), "story": True, "title": PH + spec["title"],
            "text": PH + spec["text"] + TBD, "completion": PH + spec["completion"] + TBD,
            "objectives": [talk(spec["to"])], "variants": variants, "rewards": {"weight": 2},
            "lesson": "Chapter 3 of the story arc (story, may chain): a travel from any band foreman of the "
                      "faction.",
            "duration_min": 10, "notes": "Round 61 BANDQUESTS. " + spec["notes"],
        }
        out.setdefault(ZONE_OF[spec["zones"][0]], []).append(quest)
    return out


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
        row["rewards"] = {"weight": q["weight"]}
        if q.get("choices"):
            row["rewards"]["choices"] = reward_choices(q["choices"], spec["melee"])
        row["lesson"] = lesson_of(q)
        row["duration_min"] = q["duration"]
        if q.get("group"):
            row["group"] = True
            row["optional"] = True
        note = q.get("notes") or ("The id stays (its objectives are unchanged); free, it requires nothing."
                                  if q.get("kept") else "Free play, a level only.")
        row["notes"] = "Round 61 BANDQUESTS. " + note
        rows.append(row)
    return rows


def mark_story(quest):
    """A main-line quest as shipped, with `"story": true` after its
    `requires` (nothing else changes)."""
    out = {}
    for key, value in quest.items():
        if key == "story":
            continue
        out[key] = value
        if key == "requires":
            out["story"] = True
    return out


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
    shared, closing = shared_quests(), closers()
    files = {}
    for zone, town in ZONES:
        path = QUESTS / ("%s.quests.json" % zone)
        data = json.loads(path.read_text(encoding="utf-8"))
        by_id = {q["id"]: q for q in data["quests"]}
        main = [mark_story(by_id[i]) for i in MAIN_LINE if i in by_id]
        guild = [q for q in data["quests"] if q["id"] in GUILD_IDS]
        # Round 62: the shared front quests (41-60) homed in these base
        # files are tools/r62_frontquests/build_structure.py's, kept as written.
        front = [q for q in data["quests"] if q.get("level", 0) > 40 and q["id"] not in MAIN_LINE]
        quests = shared.get(zone, []) + local_quests(town) + closing.get(zone, []) + main + guild + front
        # Round 65 ruling 3: a quest names only its level (accepted from
        # level - 2); the minimum levels written above are history.
        for quest in quests:
            quest.pop("min_level", None)
        out = {"zone": data["zone"], "reworked": True, "identity": data["identity"],
               "hubs": hubs(data["hubs"]), "quests": quests}
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
