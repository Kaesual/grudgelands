#!/usr/bin/env python3
"""Round 59 lane BANDQUESTS: write the band 11-20's quest structure.

The six band zones' quest files (Copperfell Foothills, Goldmead Vale,
Starbough Vale of The Accord; Mournfen, Redtusk Savanna, Raincall Basin of
The Throng) are rebuilt on the Round 57 quest foundation
(docs/design/quests.md "The band 11-20"), from the story chapter the user
picked (round59-plan.md; every recommendation K1-K16 "A"):

- per zone the draft's frame: the repair material (one shared quest, six
  variants), a use at a place (the load record of Copperfell and Goldmead
  and the held supplies of Redtusk and Raincall are shared quests at a
  town place in the zone's bandit camp; Starbough's snares and Mournfen's
  names are local, at a recipe quest place), the witness (a travel quest to
  the camp's captive) and the named perpetrator (both local, K14), the
  departure to the capital's envoy (the six ids kept) and the camp hunt
  (`camp_hunt_t2`, Round 58's, kept as shipped);
- the local tasks of K15 (the steward, the local and the scout, mostly
  item objectives, one day hunt) and the reward pattern of ruling 18 at item
  levels 11-20: the steward's first quest a potion choice, a day hunt an
  armor piece with a prefix, the local's last craft another slot with a
  suffix, the perpetrator a weapon per weapon line with both.

Every file is marked `"reworked": true`: every quest is free play (only a
level), nothing chains; the guild report (`guild_t2_report_*`, story) and
the camp hunt stay as Round 58 shipped them, so do the mining camp's hub.

This script wrote the structure once with placeholder texts ("[PH] ...";
each names the draft's intent for the text lane); the texts are lane
BANDTEXT's (Round 59), and the JSON files are their source: rerunning it
without --check writes the placeholders back. Run from the repository root:

    python3 tools/r59_bandquests/build_structure.py [--check]

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
    # zone id, town short name, race
    ("elandor_copperfell_foothills", "copperfell", "dwarf"),
    ("elandor_goldmead_vale", "goldmead", "human"),
    ("elandor_starbough_vale", "starbough", "elf"),
    ("kragmar_mournfen", "mournfen", "undead"),
    ("kragmar_redtusk_savanna", "redtusk", "orc"),
    ("kragmar_raincall_basin", "raincall", "troll"),
]
ZONE_OF = {town: zone for zone, town, _ in ZONES}
RACE_OF = {town: race for _, town, race in ZONES}


def npc(town, role):
    """The band's quest NPCs (grug_quests/npcs.lua): steward, scout and
    captive of Round 14, the local of Round 15."""
    race = RACE_OF[town]
    return ("r15_%s_local" if role == "local" else "r14_%s_" + role) % race


# The hubs' lines (a line is a label; a shared quest needs one line every
# giver of it has, validate.lua). Per zone: the steward, the local, the
# scout, the captive.
LINES = {
    "copperfell": {"steward": ["survey", "supplies"], "local": ["workyard", "stores"],
                   "scout": ["watch"], "captive": ["dig"]},
    "goldmead": {"steward": ["harvest", "supplies"], "local": ["stores"],
                 "scout": ["watch"], "captive": ["testimony"]},
    "starbough": {"steward": ["boughs"], "local": ["stores"],
                  "scout": ["watch"], "captive": ["testimony"]},
    "mournfen": {"steward": ["fen"], "local": ["stores", "wax"],
                 "scout": ["watch"], "captive": ["testimony"]},
    "redtusk": {"steward": ["herd", "supplies"], "local": ["hides", "stores"],
                "scout": ["watch"], "captive": ["ransom"]},
    "raincall": {"steward": ["rains", "supplies"], "local": ["weave", "stores"],
                 "scout": ["watch"], "captive": ["tithe"]},
}

HEALING = "grug_alchemy:potion_healing_t2"
MANA = "grug_alchemy:potion_mana_t2"
POTIONS = [{"item": HEALING, "count": 2}, {"item": MANA, "count": 2}]


def kill(roles, count, area=None):
    row = {"type": "kill", "roles": list(roles), "count": count}
    if area:
        row["area"] = area
    return row


def item(name, count, group=False):
    return {"type": "item", ("group" if group else "item"): name, "count": count}


def talk(who):
    return {"type": "talk", "npc": who}


def use(place, obj, label, hold):
    return {"type": "use", "place": place, "object": obj, "label": label, "hold": hold}


def armor(slot, affix):
    """One T2 armor piece per armor class (cloth, leather, metal), each with
    one author-fixed enchant: `affix` maps the class to (channel, stat)."""
    items = {"cloth": "grug_gear:%s_cloth_woven" % slot,
             "leather": "grug_gear:%s_leather_cured" % slot,
             "metal": "grug_gear:%s_metal_iron" % slot}
    return [{"item": items[c], "affixes": [{"channel": affix[c][0], "stat": affix[c][1]}]}
            for c in ("cloth", "leather", "metal")]


# The first piece (the day hunt): the class's main stat as a prefix; the
# second (the local's last craft): a second stat as a suffix (grug_quality
# POOLS), as the start zones.
EARLY = {"cloth": ("prefix", "int"), "leather": ("prefix", "dex"), "metal": ("prefix", "str")}
LATE = {"cloth": ("suffix", "max_mana_percent"), "leather": ("suffix", "crit_percent"),
        "metal": ("suffix", "max_hp_percent")}


def weapons(melee):
    """The perpetrator's choice: one T2 weapon per weapon line (caster,
    scout, warrior; Priest and Mage share), prefix and suffix each; the
    two-handed Staff where the Battle Axe is offered, the Wand beside the
    Sword."""
    caster = "grug_gear:staff_iron" if melee == "greataxe" else "grug_gear:wand_iron"
    warrior = {"sword": ("grug_gear:sword_iron", "crit_percent"),
               "greataxe": ("grug_gear:greataxe_iron", "max_hp_percent")}[melee]
    return [
        {"item": caster, "affixes": [{"channel": "prefix", "stat": "int"},
                                     {"channel": "suffix", "stat": "max_mana_percent"}]},
        {"item": "grug_gear:bow_iron", "affixes": [{"channel": "prefix", "stat": "dex"},
                                                   {"channel": "suffix", "stat": "attack_speed_percent"}]},
        {"item": warrior[0], "affixes": [{"channel": "prefix", "stat": "str"},
                                         {"channel": "suffix", "stat": warrior[1]}]},
    ]


# ---------------------------------------------------------------- shared
# The tasks that are really the same (K14): the repair material in all six
# zones, the load record in Copperfell and Goldmead (draft K8), the held
# supplies in Redtusk and Raincall (K11). One quest, one level each; each
# variant: its zone's giver, its zone-bound fields and its placeholder text.
SHARED = [
    {
        "id": "band_repairs", "giver": "local", "line": "stores", "min_level": 11, "level": 12,
        "title": "Iron for the Repairs",
        "objectives": [item("grug_materials:iron_bar", 4), item("default:coal_lump", 4)],
        "rewards": {"weight": 4.5},
        "lesson": "The repair material: smelt iron, bring coal; the work goes on before the story does.",
        "duration_min": 12,
        "notes": "Draft §3, the shared repair help (Iron Bars and Coal Lumps for a repair the local needs).",
        "towns": {
            "copperfell": {"text": "Dagna needs 4 Iron Bars and 4 Coal Lumps to mend the worn rail fastenings "
                                   "of the ore carts."},
            "goldmead": {"text": "Alda needs 4 Iron Bars and 4 Coal Lumps for the fittings of a granary that "
                                 "can be locked again."},
            "starbough": {"text": "Lethri needs 4 Iron Bars and 4 Coal Lumps for the brackets of the "
                                  "walkways between the boughs."},
            "mournfen": {"text": "Edris needs 4 Iron Bars and 4 Coal Lumps for the rusted lantern holders "
                                 "above the mud."},
            "redtusk": {"text": "Morga needs 4 Iron Bars and 4 Coal Lumps for the fittings of the herd gate."},
            "raincall": {"text": "Amari needs 4 Iron Bars and 4 Coal Lumps for new clamps that keep the "
                                 "houses on their stilts."},
        },
    },
    {
        "id": "band_load_record", "giver": "steward", "line": "supplies", "min_level": 14, "level": 15,
        "title": "The Original Load Record",
        "objectives": [use("socket:copperfell_bandit_camp/load_record", "dispatch_record",
                           "Secure the load record", 4)],
        "rewards": {"weight": 5.5},
        "lesson": "A use at a place inside a hostile camp: clear a path, then hold.",
        "duration_min": 12,
        "notes": "Draft §3.1/§3.2 and K8 A: the original load record at a new place in the existing bandit "
                 "camp; the entry names the carter (Tovin) or the person booked as cargo (Pella).",
        "towns": {
            "copperfell": {"place": "socket:copperfell_bandit_camp/load_record",
                           "text": "Orrik wants the original load record secured from the bandits' load board "
                                   "in the {name:bandit_camp}: it still names Tovin as the carter, while the "
                                   "later accounts make his work disappear."},
            "goldmead": {"place": "socket:goldmead_bandit_camp/load_record",
                         "text": "Marta wants the load record secured from the bandits' load board in the "
                                 "{name:bandit_camp}: between the grain and the sacking stands Pella's name."},
        },
    },
    {
        "id": "band_held_supplies", "giver": "steward", "line": "supplies", "min_level": 18, "level": 19,
        "title": "The Held Supplies",
        "objectives": [use("socket:redtusk_bandit_camp/held_supplies", "held_supplies",
                           "Untie the held supplies", 4)],
        "rewards": {"weight": 5.5},
        "lesson": "A use at a place at a camp's edge, out of its leader's sight.",
        "duration_min": 12,
        "notes": "Draft §3.5/§3.6 and K11 A: supplies the bandits hold at the edge of the existing camp, "
                 "untied so they can go back; no water filling, no escort.",
        "towns": {
            "redtusk": {"place": "socket:redtusk_bandit_camp/held_supplies",
                        "text": "Borak wants the lashing cut on a water load Korr's bandits hold at the edge "
                                "of the {name:bandit_camp}: water the herders found together, sold back to them."},
            "raincall": {"place": "socket:raincall_bandit_camp/held_supplies",
                         "text": "Daro wants the stores and tools Vek's bandits took from the households that "
                                 "refused his tithe untied at the edge of the {name:bandit_camp}."},
        },
    },
]

# ---------------------------------------------------------------- local
# Per zone: the steward's first quest (the potion choice), the steward's
# handoff to the scout (kept id), the scout's errand, the local's craft,
# the day hunt (armor, prefix), the use quest where it is local, the
# witness (kept id), the local's second craft (armor, suffix), the
# perpetrator (weapon) and the departure (kept id). A kept id keeps its
# objectives; every other id is new (round59-plan.md §3).
# Rows: id, role of the giver, line, min level, level, objectives, weight,
# title, text (the intent), and optional turnin, choices, completion,
# duration.
LOCAL = {
    "copperfell": {
        "melee": "greataxe", "slots": ("chest", "feet"),
        "quests": [
            {"id": "copperfell_copper", "giver": "steward", "line": "survey", "min_level": 10, "level": 11,
             "objectives": [item("default:copper_lump", 8)], "weight": 4, "choices": "potions",
             "title": "Copper for the Scales",
             "text": "Orrik weighs fresh copper against the old ledger to see what the carts lost: bring "
                     "8 Copper Lumps from the seams.", "duration": 8},
            {"id": "copperfell_survey_03", "giver": "steward", "line": "survey", "min_level": 12, "level": 13,
             "objectives": [talk("r14_dwarf_scout")], "weight": 1, "turnin": "r14_dwarf_scout",
             "title": "The Tally to the Outpost",
             "text": "Orrik sends his cart tally to Mara Deepwatch at the outpost, who turns a loss report "
                     "back into a search for people.", "duration": 5},
            {"id": "copperfell_firewood", "giver": "scout", "line": "watch", "min_level": 12, "level": 13,
             "objectives": [item("tree", 12, group=True)], "weight": 4,
             "title": "Wood for the Watch Fire",
             "text": "Mara keeps a fire burning for the night watch over the cart road: bring 12 logs of any "
                     "tree.", "duration": 7},
            {"id": "copperfell_torches", "giver": "local", "line": "workyard", "min_level": 13, "level": 14,
             "objectives": [item("default:torch", 20)], "weight": 4.5,
             "title": "Light for the Shafts",
             "text": "Dagna keeps the work going: 20 Torches for the shafts and the cart road.", "duration": 8},
            {"id": "copperfell_watch_02", "giver": "scout", "line": "watch", "min_level": 14, "level": 15,
             "objectives": [kill(["surefoot_ibex"], 8, "elandor_copperfell_foothills/pine_slopes")],
             "weight": 5, "choices": "early",
             "title": "Stones on the Cart Road",
             "text": "Surefoot Ibex knock stones onto the cart road: hunt 8 of them by day in the "
                     "{name:pine_slopes}.", "duration": 9},
            {"id": "copperfell_watch_04", "giver": "scout", "line": "watch", "min_level": 16, "level": 17,
             "objectives": [talk("r14_dwarf_captive")], "weight": 1.5, "turnin": "r14_dwarf_captive",
             "title": "A Carter Among the Cargo",
             "text": "Mara sends the player to hear Tovin Ashthumb himself, held in the {name:bandit_camp}; "
                     "no fight is asked first.", "duration": 6},
            {"id": "copperfell_wage_chests", "giver": "local", "line": "workyard", "min_level": 16,
             "level": 17, "objectives": [item("default:chest_locked", 2)], "weight": 5, "choices": "late",
             "title": "Chests for the Wages",
             "text": "Dagna wants the crews' wages kept where no stamp can reach them: bring 2 Locked Chests.",
             "duration": 9},
            {"id": "copperfell_nog", "giver": "captive", "line": "dig", "min_level": 18, "level": 19,
             "objectives": [kill(["foreman_nog"], 1)], "weight": 7, "choices": "weapon",
             "title": "Take the Dig from {name:foreman_nog}",
             "text": "Tovin wants Goblin Foreman Nog's business spoiled: defeat {name:foreman_nog} at the "
                     "{name:goblin_dig}, who pays his crew from stamped, stolen purses.",
             "completion": "Tovin hears that Nog is down; his own wages are still owed.", "duration": 12},
        ],
    },
    "goldmead": {
        "melee": "sword", "slots": ("head", "feet"),
        "quests": [
            {"id": "goldmead_corn", "giver": "steward", "line": "harvest", "min_level": 10, "level": 11,
             "objectives": [item("grug_gathering:corn", 8)], "weight": 4, "choices": "potions",
             "title": "What the Vale Delivers",
             "text": "Marta counts what the vale can really deliver: bring 8 Corn from the fields.",
             "duration": 7},
            {"id": "goldmead_harvest_04", "giver": "steward", "line": "harvest", "min_level": 12, "level": 13,
             "objectives": [talk("r14_human_scout")], "weight": 1, "turnin": "r14_human_scout",
             "title": "Word for the Outpost",
             "text": "Marta sends word to Jon Vale at the outpost, who watches Hobb and his people.",
             "duration": 5},
            {"id": "goldmead_sunleaf", "giver": "scout", "line": "watch", "min_level": 12, "level": 13,
             "objectives": [item("grug_gathering:sunleaf", 5)], "weight": 4,
             "title": "Sunleaf for the Watch",
             "text": "Jon's watchers need a remedy for the long watches: bring 5 Sunleaf.", "duration": 8},
            {"id": "goldmead_potatoes", "giver": "local", "line": "stores", "min_level": 13, "level": 14,
             "objectives": [item("grug_gathering:potato", 8)], "weight": 4.5,
             "title": "Food for the Packers",
             "text": "Alda keeps the people who pack the harvest fed: bring 8 Potatoes.", "duration": 8},
            {"id": "goldmead_harvest_03", "giver": "steward", "line": "harvest", "min_level": 14, "level": 15,
             "objectives": [kill(["bristling_boar"], 8, "elandor_goldmead_vale/wheatfields")],
             "weight": 5, "choices": "early",
             "title": "Boars in the Wheat",
             "text": "Bristlebacks trample the wheat: hunt 8 of them by day in the {name:wheatfields}.",
             "duration": 10},
            {"id": "goldmead_watch_03", "giver": "scout", "line": "watch", "min_level": 17, "level": 17,
             "objectives": [talk("r14_human_captive")], "weight": 1.5, "turnin": "r14_human_captive",
             "title": "Pella Speaks for Herself",
             "text": "Jon sends the player straight to Pella Thatch, held in the {name:bandit_camp}, who "
                     "insists on making her own statement.", "duration": 6},
            {"id": "goldmead_fences", "giver": "local", "line": "stores", "min_level": 16, "level": 17,
             "objectives": [item("default:fence_wood", 8)], "weight": 5, "choices": "late",
             "title": "Fences for the Stores",
             "text": "Alda fences the store yard against the next requisition: bring 8 Apple Wood Fences.",
             "duration": 9},
            {"id": "goldmead_testimony_02", "giver": "captive", "line": "testimony", "min_level": 18,
             "level": 19, "objectives": [kill(["requisitioner_hobb"], 1)], "weight": 7, "choices": "weapon",
             "title": "End {name:requisitioner_hobb}'s Claim",
             "text": "Pella demands the fight against Bandit Requisitioner Hobb at the {name:requisition_camp}, "
                     "who booked her between the grain and the sacking.",
             "completion": "Pella's statement stands as a statement again.", "duration": 10},
        ],
    },
    "starbough": {
        "melee": "sword", "slots": ("head", "legs"),
        "quests": [
            {"id": "starbough_sunleaf", "giver": "steward", "line": "boughs", "min_level": 10, "level": 11,
             "objectives": [item("grug_gathering:sunleaf", 5)], "weight": 4, "choices": "potions",
             "title": "Sunleaf for the Snared",
             "text": "Ilyra sees the poaching first on the forest: bring 5 Sunleaf for the animals hurt by "
                     "the snares.", "duration": 8},
            {"id": "starbough_snares", "giver": "steward", "line": "boughs", "min_level": 11, "level": 12,
             "objectives": [use("snare_ground", "snare_bundle", "Cut the snare bundle", 3)], "weight": 4.5,
             "title": "A Knot With Another Purpose",
             "text": "Ilyra sends the player to the {name:snare_ground} in the {name:lower_boughs} to make a "
                     "snare bundle harmless; a knot that could hold up a young tree became a trap.",
             "completion": "The danger at that spot is gone.", "duration": 8},
            {"id": "starbough_boughs_04", "giver": "steward", "line": "boughs", "min_level": 12, "level": 13,
             "objectives": [talk("r14_elf_scout")], "weight": 1, "turnin": "r14_elf_scout",
             "title": "Word for Theren",
             "text": "Ilyra sends word to Theren Farstep at the outpost, who follows the traders.",
             "duration": 5},
            {"id": "starbough_torches", "giver": "scout", "line": "watch", "min_level": 12, "level": 13,
             "objectives": [item("default:torch", 20)], "weight": 4,
             "title": "Lights on the Poachers' Trails",
             "text": "Theren keeps a night watch on the poachers' trails: bring 20 Torches.", "duration": 7},
            {"id": "starbough_signs", "giver": "local", "line": "stores", "min_level": 13, "level": 14,
             "objectives": [item("default:sign_wall_wood", 6)], "weight": 4.5,
             "title": "Markers for the Paths",
             "text": "Lethri tends the paths and their markings: bring 6 Wooden Signs.", "duration": 8},
            {"id": "starbough_watch_01", "giver": "scout", "line": "watch", "min_level": 14, "level": 15,
             "objectives": [kill(["rabid_fox"], 7, "elandor_starbough_vale/greenwood")],
             "weight": 5, "choices": "early",
             "title": "Vixens in the Greenwood",
             "text": "Thicket Vixens harry the path wardens: hunt 7 of them by day in the {name:greenwood}.",
             "duration": 9},
            {"id": "starbough_watch_04", "giver": "scout", "line": "watch", "min_level": 16, "level": 16,
             "objectives": [talk("r14_elf_captive")], "weight": 1.5, "turnin": "r14_elf_captive",
             "title": "Nima Knows the Hands",
             "text": "Theren points the player to Nima Fern, held in the {name:bandit_camp}, who knows the "
                     "hands behind the snares.", "duration": 6},
            {"id": "starbough_ladders", "giver": "local", "line": "stores", "min_level": 16, "level": 17,
             "objectives": [item("default:ladder_wood", 10)], "weight": 5, "choices": "late",
             "title": "Ladders for the Walkways",
             "text": "Lethri keeps the walkways up the boughs passable: bring 10 Wooden Ladders.",
             "duration": 8},
            {"id": "starbough_testimony_03", "giver": "captive", "line": "testimony", "min_level": 18,
             "level": 19, "objectives": [kill(["snarekeeper_vetch"], 1)], "weight": 7, "choices": "weapon",
             "title": "Stand Against {name:snarekeeper_vetch}",
             "text": "Nima demands the fight against Poacher Snarekeeper Vetch {dir_from_giver:snarekeeper_vetch}"
                     " in the {name:high_boughs}, who turns tending knowledge into traps.",
             "completion": "Nima has named Vetch, and Vetch is down.", "duration": 12},
        ],
    },
    "mournfen": {
        "melee": "greataxe", "slots": ("head", "chest"),
        "quests": [
            {"id": "mournfen_markers", "giver": "steward", "line": "fen", "min_level": 10, "level": 11,
             "objectives": [item("default:sign_wall_wood", 6)], "weight": 4, "choices": "potions",
             "title": "Markers for the Graves",
             "text": "Mordec keeps the burials and their names: bring 6 Wooden Signs to mark graves whose old "
                     "markings rotted.", "duration": 7},
            {"id": "mournfen_names", "giver": "steward", "line": "fen", "min_level": 11, "level": 12,
             "objectives": [use("name_rest", "witness_record", "Copy the names from the marker", 5)],
             "weight": 4.5,
             "title": "The Names That Remain",
             "text": "Mordec sends the player to the {name:name_rest} in the {name:blightfields}: the readable "
                     "names on a damaged grave marking are copied before the next rain takes them.",
             "completion": "Mordec can match the names to people again; nobody is freed by it.",
             "duration": 8},
            {"id": "mournfen_fen_02", "giver": "steward", "line": "fen", "min_level": 12, "level": 13,
             "objectives": [talk("r14_undead_scout")], "weight": 1, "turnin": "r14_undead_scout",
             "title": "Word for Sera",
             "text": "Mordec sends word to Sera Vane at the outpost, who follows the transports.",
             "duration": 5},
            {"id": "mournfen_stakes", "giver": "scout", "line": "watch", "min_level": 12, "level": 13,
             "objectives": [item("tree", 12, group=True)], "weight": 4,
             "title": "Stakes for the Safe Paths",
             "text": "Sera marks the safe paths through the fen: bring 12 logs of any tree.", "duration": 7},
            {"id": "mournfen_torches", "giver": "local", "line": "wax", "min_level": 13, "level": 14,
             "objectives": [item("default:torch", 20)], "weight": 4.5,
             "title": "Lights Over the Mud",
             "text": "Edris keeps lights and paths usable: bring 20 Torches.", "duration": 7},
            {"id": "mournfen_fen_03", "giver": "steward", "line": "fen", "min_level": 14, "level": 16,
             "objectives": [kill(["bristling_boar"], 7, "kragmar_mournfen/barrowfields")],
             "weight": 5, "choices": "early",
             "title": "Tuskers in the Barrows",
             "text": "Plague Tuskers root up the barrows: hunt 7 of them by day in the {name:barrowfields}.",
             "duration": 10},
            {"id": "mournfen_effects_chests", "giver": "local", "line": "stores", "min_level": 16,
             "level": 17, "objectives": [item("default:chest_locked", 2)], "weight": 5, "choices": "late",
             "title": "Chests for the Effects",
             "text": "Edris keeps recovered personal effects with their names: bring 2 Locked Chests.",
             "duration": 9},
            {"id": "mournfen_watch_04", "giver": "scout", "line": "watch", "min_level": 18, "level": 18,
             "objectives": [talk("r14_undead_captive")], "weight": 1.5, "turnin": "r14_undead_captive",
             "title": "Hollis Saw It",
             "text": "Sera sends the player to Hollis Grey, held in the {name:bandit_camp}, who watched remains "
                     "being carried off.", "duration": 6},
            {"id": "mournfen_silt", "giver": "captive", "line": "testimony", "min_level": 18, "level": 19,
             "objectives": [kill(["reed_counter_silt"], 1)], "weight": 7, "choices": "weapon",
             "turnin": "r14_undead_scout",
             "title": "Close {name:reed_counter_silt}'s Count",
             "text": "Hollis demands the fight against Mirefolk Reed-Counter Silt at the {name:mire_nests}, who "
                     "counts bones as wares; the report goes to Sera.",
             "completion": "Sera takes the report; the remains were someone before they were wares.",
             "duration": 12},
        ],
    },
    "redtusk": {
        "melee": "greataxe", "slots": ("head", "feet"),
        "quests": [
            {"id": "redtusk_corn", "giver": "steward", "line": "herd", "min_level": 10, "level": 11,
             "objectives": [item("grug_gathering:corn", 8)], "weight": 4, "choices": "potions",
             "title": "Fodder for the Herds",
             "text": "Borak keeps the herds fed: bring 8 Corn.", "duration": 7},
            {"id": "redtusk_herd_04", "giver": "steward", "line": "herd", "min_level": 12, "level": 13,
             "objectives": [talk("r14_orc_scout")], "weight": 1, "turnin": "r14_orc_scout",
             "title": "Word for Kesh",
             "text": "Borak sends word to Kesh Longstride at the outpost, who watches where the water goes.",
             "duration": 5},
            {"id": "redtusk_sunleaf", "giver": "scout", "line": "watch", "min_level": 12, "level": 13,
             "objectives": [item("grug_gathering:sunleaf", 5)], "weight": 4,
             "title": "Sunleaf for the Watch",
             "text": "Kesh's watchers need a remedy for the dry heat: bring 5 Sunleaf.", "duration": 8},
            {"id": "redtusk_fences", "giver": "local", "line": "hides", "min_level": 13, "level": 14,
             "objectives": [item("default:fence_acacia_wood", 8)], "weight": 4.5,
             "title": "Fences for the Pens",
             "text": "Morga keeps herds, gates and supplies going: bring 8 Acacia Wood Fences.", "duration": 8},
            {"id": "redtusk_zebras", "giver": "scout", "line": "watch", "min_level": 14, "level": 15,
             "objectives": [kill(["watchful_zebra"], 8, "kragmar_redtusk_savanna/tallgrass")],
             "weight": 5, "choices": "early",
             "title": "Zebras at the Water",
             "text": "Waterhole Zebras crowd the herds off the water: hunt 8 of them by day in the "
                     "{name:tallgrass}.", "duration": 10},
            {"id": "redtusk_posts", "giver": "local", "line": "hides", "min_level": 16, "level": 17,
             "objectives": [item("tree", 12, group=True)], "weight": 5, "choices": "late",
             "title": "Posts for the Shelters",
             "text": "Morga builds shade over the waterholes: bring 12 logs of any tree.", "duration": 8},
            {"id": "redtusk_watch_03", "giver": "scout", "line": "watch", "min_level": 17, "level": 18,
             "objectives": [talk("r14_orc_captive")], "weight": 1.5, "turnin": "r14_orc_captive",
             "title": "Rokka Counts the Barrels",
             "text": "Kesh points the player to Rokka Emberhand, held in the {name:bandit_camp}, who knows the "
                     "loads and where they came from.", "duration": 6},
            {"id": "redtusk_korr", "giver": "captive", "line": "ransom", "min_level": 18, "level": 19,
             "objectives": [kill(["water_broker_korr"], 1)], "weight": 7, "choices": "weapon",
             "title": "End {name:water_broker_korr}'s Trade",
             "text": "Rokka demands the fight against Bandit Water-Broker Korr in the {name:bandit_camp}, who "
                     "sells shared water back to the people who found it.",
             "completion": "Korr's trade is over; Rokka can name the buyers.", "duration": 12},
        ],
    },
    "raincall": {
        "melee": "sword", "slots": ("chest", "legs"),
        "quests": [
            {"id": "raincall_melons", "giver": "steward", "line": "rains", "min_level": 10, "level": 11,
             "objectives": [item("grug_gathering:melon", 4)], "weight": 4, "choices": "potions",
             "title": "Melons From the Gardens",
             "text": "Daro tends the gardens and paths: bring 4 Melons.", "duration": 8},
            {"id": "raincall_rains_04", "giver": "steward", "line": "rains", "min_level": 12, "level": 13,
             "objectives": [talk("r14_troll_scout")], "weight": 1, "turnin": "r14_troll_scout",
             "title": "Word for Neshi",
             "text": "Daro sends word to Neshi Reedstep at the outpost, who follows the collectors.",
             "duration": 5},
            {"id": "raincall_sunleaf", "giver": "scout", "line": "watch", "min_level": 12, "level": 13,
             "objectives": [item("grug_gathering:sunleaf", 5)], "weight": 4,
             "title": "Sunleaf for the Watch",
             "text": "Neshi's watchers need a remedy for the wet season: bring 5 Sunleaf.", "duration": 8},
            {"id": "raincall_ladders", "giver": "local", "line": "weave", "min_level": 13, "level": 14,
             "objectives": [item("default:ladder_wood", 10)], "weight": 4.5,
             "title": "Ladders for the Stilt Houses",
             "text": "Amari keeps houses and clothes dry: bring 10 Wooden Ladders for the stilt houses.",
             "duration": 7},
            {"id": "raincall_watch_01", "giver": "scout", "line": "watch", "min_level": 14, "level": 15,
             "objectives": [kill(["reed_jungle_lynx"], 8, "kragmar_raincall_basin/cloudwood")],
             "weight": 5, "choices": "early",
             "title": "Servals in the Cloudwood",
             "text": "Servals stalk the collectors' paths: hunt 8 of them by day in the {name:cloudwood}.",
             "duration": 10},
            {"id": "raincall_dry_chests", "giver": "local", "line": "weave", "min_level": 16, "level": 17,
             "objectives": [item("default:chest_locked", 2)], "weight": 5, "choices": "late",
             "title": "Dry Stores for the Households",
             "text": "Amari keeps the households' stores dry and out of the collectors' reach: bring 2 Locked "
                     "Chests.", "duration": 9},
            {"id": "raincall_watch_04", "giver": "scout", "line": "watch", "min_level": 18, "level": 18,
             "objectives": [talk("r14_troll_captive")], "weight": 1.5, "turnin": "r14_troll_captive",
             "title": "Veko Promised Nothing",
             "text": "Neshi points the player to Veko Bluefeather, held in the {name:bandit_camp}, who refused a "
                     "tithe nobody agreed to.", "duration": 6},
            {"id": "raincall_tithe_01", "giver": "captive", "line": "tithe", "min_level": 18, "level": 19,
             "objectives": [kill(["tithe_keeper_vek"], 1)], "weight": 7, "choices": "weapon",
             "title": "End {name:tithe_keeper_vek}'s Claim",
             "text": "Veko demands the fight against Bandit Tithe-Keeper Vek in the {name:bandit_camp}, who "
                     "claims to sell the rain.",
             "completion": "Vek's claim is over; the neighbours who paid under threat are no cowards.",
             "duration": 12},
        ],
    },
}

# The departures (ids kept, round59-plan.md §2): free travel quests from 19
# to the capital's envoy, requiring nothing; the text carries the zone's
# case without claiming that the perpetrator fell.
DEPARTURES = {
    "copperfell": "Tovin sends the player to Dorrin Gateledger in Dur Brannoc: a counting-house stamp turns up "
                  "on stolen purses.",
    "goldmead": "Pella sends the player to Mariel Waybook in Highcourt with her own statement about Hobb and "
                "the capital mark he uses.",
    "starbough": "Nima sends the player to Eriath Boughwarden in Lethariel: the Bough-Seal is passed off as a "
                 "leave to take.",
    "mournfen": "Sera sends the player to Ossa Quietregister in Nhal Veyr: remains vanish and the register "
                "misses names; nothing claims Hollis is free.",
    "redtusk": "Rokka sends the player to Thorga Roadspeaker in Gor Drazhak with the loads she saw sold, "
               "whether Korr still lives or not.",
    "raincall": "Veko sends the player to Nalo Pathdrum in Kezamba with his refusal and the case; Vek's fall "
                "is told only by the fight's own completion.",
}

CAPITAL = {"copperfell": "Dur Brannoc", "goldmead": "Highcourt", "starbough": "Lethariel",
           "mournfen": "Nhal Veyr", "redtusk": "Gor Drazhak", "raincall": "Kezamba"}

# The Round 58 quests these files carry (kept as shipped).
GUILD_IDS = ("guild_t2_report_accord", "guild_t2_report_throng", "camp_hunt_t2")


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


LESSONS = {
    "potions": "The zone's first errand, a level only; the early potion choice.",
    "early": "A day hunt; the first armor choice (one enchant, a prefix).",
    "late": "A craft from Basic recipes; the second armor choice (one enchant, a suffix).",
    "weapon": "The named perpetrator at his place; the weapon choice (prefix and suffix).",
}


def shared_quests():
    """{zone: [quest]} for the shared quests, each in its first variant's file."""
    out = {}
    for spec in SHARED:
        order = [t for _, t, _ in ZONES if t in spec["towns"]]
        variants = []
        for town in order:
            fields = spec["towns"][town]
            row = {"zone": ZONE_OF[town], "givers": [npc(town, spec["giver"])]}
            if town != order[0] and fields.get("place"):
                row["objectives"] = [{"place": fields["place"]}]
            row["text"] = PH + fields["text"] + TBD
            variants.append(row)
        first = spec["towns"][order[0]]
        quest = {
            "id": spec["id"], "line": spec["line"], "min_level": spec["min_level"], "level": spec["level"],
            "requires": [], "title": PH + spec["title"], "text": PH + first["text"] + TBD,
            "objectives": [dict(o) for o in spec["objectives"]], "variants": variants,
            "rewards": dict(spec["rewards"]), "lesson": spec["lesson"], "duration_min": spec["duration_min"],
            "notes": "Round 59 BANDQUESTS. " + spec["notes"],
        }
        out.setdefault(ZONE_OF[order[0]], []).append(quest)
    return out


def local_quests(town, departure):
    spec = LOCAL[town]
    rows = []
    for q in spec["quests"]:
        giver = npc(town, q["giver"])
        row = {"id": q["id"], "line": q["line"], "giver": giver, "turnin": q.get("turnin", giver),
               "min_level": q["min_level"], "level": q["level"], "requires": [],
               "title": PH + q["title"], "text": PH + q["text"] + TBD}
        if q.get("completion"):
            row["completion"] = PH + q["completion"] + TBD
        row["objectives"] = q["objectives"]
        row["rewards"] = {"weight": q["weight"]}
        if q.get("choices"):
            row["rewards"]["choices"] = reward_choices(q["choices"], spec)
        row["lesson"] = LESSONS.get(q.get("choices"), "A local task of the zone's own people (draft K15).")
        row["duration_min"] = q["duration"]
        row["notes"] = "Round 59 BANDQUESTS: free play, a level only."
        rows.append(row)
    dep = {k: departure[k] for k in ("id", "line", "giver", "turnin", "min_level", "level")}
    dep.update({"requires": [], "title": PH + "The Case Goes to " + CAPITAL[town],
                "text": PH + DEPARTURES[town] + TBD,
                "objectives": departure["objectives"], "rewards": {"weight": departure["rewards"]["weight"]},
                "lesson": departure.get("lesson", "Home zone to capital handoff."),
                "duration_min": departure.get("duration_min", 8),
                "notes": "Round 59 BANDQUESTS: the departure id stays; free from 19, it requires nothing "
                         "and claims no earlier deed (draft §1, §2)."})
    rows.append(dep)
    return rows


def hubs(town, shipped):
    """The shipped hubs with the band givers' lines of LINES; the mining
    camp's hub as shipped."""
    out = []
    for hub in shipped:
        hub = json.loads(json.dumps(hub))
        for giver in hub["givers"]:
            for role, lines in LINES[town].items():
                if giver["npc"] == npc(town, role):
                    giver["lines"] = list(lines)
        out.append(hub)
    return out


# The text fields (lane BANDTEXT's since Round 59): --check compares the rest,
# the structure.
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
    for zone, town, _ in ZONES:
        path = QUESTS / ("%s.quests.json" % zone)
        data = json.loads(path.read_text(encoding="utf-8"))
        departure = next(q for q in data["quests"] if q["id"] == "%s_departure" % town)
        guild = [q for q in data["quests"] if q["id"] in GUILD_IDS]
        quests = shared.get(zone, []) + local_quests(town, departure) + guild
        out = {"zone": data["zone"], "reworked": True, "identity": data["identity"],
               "hubs": hubs(town, data["hubs"]), "quests": quests}
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
