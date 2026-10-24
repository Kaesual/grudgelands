#!/usr/bin/env python3
"""Round 60 lane CAPITALS: write the six capital quest files' structure.

The six capitals (Highcourt, Dur Brannoc and Lethariel of The Accord; Gor
Drazhak, Kezamba and Nhal Veyr of The Throng) are reworked on the Round 57
quest foundation (docs/design/quests.md "The capitals"), from the chapter
the user picked (round60-plan.md §2, §2a; the chapter-2 draft's every
recommendation K1-K13 "A"):

- every file is marked `"reworked": true`: every quest is free play (a
  level only) but the story quests; nothing else chains, and the cooks'
  dispatch quests and the envoys' departures are free handovers;
- chapter 1 (`story_accord_01/02`, `story_throng_01/02`, Round 59) stays as
  it ships: this script copies those four quests from the shipped files
  (tools/r59_storyquests/build_structure.py --check compares them), and the
  hubs keep the envoys' lines `envoy` and `front` and the guild leaders'
  hubs;
- shared quests where the task is the same (one title, the capital's voice
  in its variant): the envoys' Torches (all six), the night's Debtbound
  Zombies (Highcourt, Dur Brannoc, Lethariel, Nhal Veyr), the Alchemy quest
  (all six; an Elixir of Precision I, plan §2 point 6, §2a points 4-5) and
  the cooks' Raw Meat (Lethariel, Gor Drazhak, Kezamba, Nhal Veyr; Kezamba's
  cook's line `smokehouse` becomes `provisions`, the line the others give it
  on);
- the capital climaxes as free local quests, each its named leader alone
  (Penn, Brakk, Rusk, Garr; Takka's `kezamba_offerings_04` and Hush's
  `nhal_veyr_vigil_03` keep their ids, the latter because chapter 2's T3
  requires it, plan §3);
- chapter 2's T3 (`story_throng_04`, Ossa -> the public register by Nhal
  Veyr's Miner's Guild house -> Iven Lastshift);
- the capitals' own day hunts and errands the draft keeps (§4), and the
  dispatch and departure ids as shipped. Varda's Mire Carp is lane
  BANDQUESTS' shared fish quest (homed in Totemwater Reach, on Varda's
  `provisions` line): this script writes none.

The structure is written once with placeholder texts ("[PH] ... Real text
to follow.", each naming the draft's intent for the text lane); once the
texts land the JSON files are their source, and rerunning the script
without --check writes the placeholders back. Run from the repository root:

    python3 tools/r60_capitals/build_structure.py [--check]

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

# Capital order is the variant order: a shared quest lives in its first
# variant's file (quests.md "Shared quests"). key -> zone, race.
CAPITALS = [
    ("highcourt", "elandor_highcourt", "human"),
    ("dur_brannoc", "elandor_dur_brannoc", "dwarf"),
    ("lethariel", "elandor_lethariel", "elf"),
    ("gor_drazhak", "kragmar_gor_drazhak", "orc"),
    ("kezamba", "kragmar_kezamba", "troll"),
    ("nhal_veyr", "kragmar_nhal_veyr", "undead"),
]
ZONE = {key: zone for key, zone, _ in CAPITALS}
RACE = {key: race for key, _, race in CAPITALS}

# Chapter 1 (Round 59 STORYQUESTS, its own generator's): copied as shipped.
CHAPTER1 = {"highcourt": ("story_accord_01", "story_accord_02"),
            "gor_drazhak": ("story_throng_01", "story_throng_02")}

# The lines: a line is only a label, a shared quest needs one line every
# giver of it has (validate.lua E-line); every giver keeps at most two.
LINES = {"envoy": ["envoy", "front"], "cook": ["provisions", "dispatch"], "leader": ["guild"]}


def envoy(capital):
    return "r20_%s_capital_envoy" % RACE[capital]


def cook(capital):
    return "r20_%s_capital_cook" % RACE[capital]


def leader(capital):
    return "r58_guild_leader_" + capital


GIVER = {"envoy": envoy, "cook": cook, "leader": leader}


def kill(roles, count, area=None):
    row = {"type": "kill", "roles": list(roles), "count": count}
    if area:
        row["area"] = area
    return row


def item(name, count, roles=None, area=None):
    row = {"type": "item", "item": name, "count": count}
    if roles:
        row["roles"] = list(roles)
    if area:
        row["area"] = area
    return row


def talk(who):
    return {"type": "talk", "npc": who}


def use(place, obj, label, hold):
    return {"type": "use", "place": place, "object": obj, "label": label, "hold": hold}


# Rewards (capitals are excepted from the zone budget, quests.md "The rework
# flag"): T3 potions at reward level 21 and above (grug_alchemy effects.lua
# TIER_LEVELS), the T3 materials choice of the band's camp hunts.
POTIONS_T3 = [{"item": "grug_alchemy:potion_healing_t3", "count": 2},
              {"item": "grug_alchemy:potion_mana_t3", "count": 2}]
MATERIALS_T3 = [{"item": "grug_mobs:heavy_leather", "count": 3},
                {"item": "grug_mobs:heavy_cloth", "count": 3},
                {"item": "grug_materials:steel_bar", "count": 2}]

# The Alchemy quest's product (plan §2 point 6, §2a points 4-5): Sunleaf (in
# every start zone since Round 60 HERBS) + Boar Tusk (the start zones' boars
# by day) + a Glass Bottle, brewed at the capital's Brewing Stand.
PRECISION = "grug_alchemy:elixir_precision_t1"

# The capital's Alchemy trainer: its service plot (capital_services.lua
# PLOTS.alchemist), named in words in the text (a trainer is no quest NPC).
TRAINER = {
    "highcourt": "the herb garden in the lore quarter",
    "dur_brannoc": "the brewhouse on the terraces",
    "lethariel": "the brewhouse among the homes",
    "gor_drazhak": "the herb house in the bone quarter",
    "kezamba": "the herbalist's under the vines",
    "nhal_veyr": "the physic house in the market",
}

# T3's town place (K4 A): a quest_place socket in the extra_sockets of Nhal
# Veyr's Miner's Guild plot (wp13/nhal_veyr_district.lua), on the forecourt
# in front of the house, reachable from the street.
T3_PLACE = "socket:nhal_veyr/miners_guild/miners_guild_public_register"
# T3's prerequisites (plan §3, the cross-lane ids): T2a `story_throng_03`
# (lane BANDQUESTS, Ossuary Reach), the free `ossuary_rubbings_03`
# (BANDQUESTS, id kept) and the free Hush quest `nhal_veyr_vigil_03` (here,
# id kept). Until this branch is rebased on BANDQUESTS' merge, T2a does not
# exist here and T3 requires T2 (`story_throng_02`) in its place.
T3_REQUIRES = ["story_throng_02", "ossuary_rubbings_03", "nhal_veyr_vigil_03"]

# ---------------------------------------------------------------- shared
# One quest, one level each; each variant: its capital's giver, its
# zone-bound fields (a kill's or an item source's area) and its text.
SHARED = [
    {
        "id": "capital_torches", "giver": "envoy", "line": "envoy", "min_level": 20, "level": 20,
        "title": "Light for the City's Work",
        "objectives": [item("default:torch", 20)],
        "rewards": {"weight": 3},
        "lesson": "A Basic craft at the first capital visit: coal and sticks, no profession.",
        "duration_min": 8,
        "notes": "Draft §4 and K12 A: every envoy asks for Torches for the capital's own services; one "
                 "title, the occasion in each capital's voice.",
        "capitals": {
            "highcourt": {"text": "Mariel Waybook needs 20 Torches for the night roads to the chapel and the "
                                  "petitioners' late queue."},
            "dur_brannoc": {"text": "Dorrin Gateledger needs 20 Torches for the gate watch and the late carts "
                                    "at the ancestor hall."},
            "lethariel": {"text": "Eriath Boughwarden needs 20 Torches for the tenders' paths under the "
                                  "old trees, kept low and careful."},
            "gor_drazhak": {"text": "Thorga Roadspeaker needs 20 Torches for the muster yard and the roads "
                                    "the recruits march out on."},
            "kezamba": {"text": "Nalo Pathdrum needs 20 Torches for the pilgrims' boardwalks to the "
                                "cenote after dark."},
            "nhal_veyr": {"text": "Ossa Quietregister needs 20 Torches for the graveside visits of the "
                                  "living, who still need to see."},
        },
    },
    {
        "id": "capital_night_dead", "giver": "envoy", "line": "envoy", "min_level": 21, "level": 22,
        "title": "Debts That Walk at Night",
        "objectives": [kill(["debtbound_zombie"], 3, "elandor_highcourt/commons")],
        "rewards": {"weight": 2.5, "choices": POTIONS_T3},
        "lesson": "A short night hunt on the capital's outskirts; a third of a day hunt's count.",
        "duration_min": 8,
        "notes": "Draft §4 and K12 A: one shared night task against the Debtbound Zombies in four "
                 "capitals; the night count about a third of the day hunts' (ruling 12).",
        "capitals": {
            "highcourt": {"area": "elandor_highcourt/commons",
                          "text": "Mariel: Debtbound Zombies wander the commons after dark with somebody's "
                                  "unpaid tolls; lay three to rest."},
            "dur_brannoc": {"area": "elandor_dur_brannoc/pastures",
                            "text": "Dorrin: Debtbound Zombies knock at the pasture gates at night to collect "
                                    "debts long settled; lay three to rest."},
            "lethariel": {"area": "elandor_lethariel/glades",
                          "text": "Eriath: Debtbound Zombies trample the saplings in the glades at night; "
                                  "grant three of them peace before dawn does it harder."},
            "nhal_veyr": {"area": "kragmar_nhal_veyr/blightfields",
                          "text": "Ossa: Debtbound Zombies walk the blightfields at night with debts that "
                                  "stand in no register of hers; lay three to rest."},
        },
    },
    {
        "id": "capital_precision", "giver": "envoy", "line": "envoy", "min_level": 19, "level": 20,
        "title": "A Steady Hand for a Rash Promise",
        "objectives": [item(PRECISION, 1)],
        "rewards": {"weight": 3},
        "lesson": "Learn Alchemy at the capital's trainer, gather where you started, brew at the capital's "
                  "Brewing Stand; a friend's elixir counts too.",
        "duration_min": 15,
        "notes": "Plan §2 point 6, §2a points 4-5, draft §4 'Die Alchemy-Aufgabe' and K13 A: one shared "
                 "quest, one elixir everywhere (Precision I: Sunleaf, Boar Tusk, Glass Bottle), each envoy's "
                 "own playful occasion; the text names the trainer's plot in words and sends the player back "
                 "where they started by their start settlement's waystone, never naming the start zone. The "
                 "one quest the r45_st check lets ask for a grug_alchemy item.",
        "capitals": {
            "highcourt": {"text": "Mariel claimed at the little shooting match that a calm record-keeper aims as "
                                  "well as any guard, and now has to prove it. Learn the brew from the Alchemy "
                                  "trainer at {trainer}; Sunleaf grows and young boars roam back where you "
                                  "started, and your first village's waystone takes you there."},
            "dur_brannoc": {"text": "Dorrin means to win the throw at an old pan plate, while Varda only asks "
                                    "that the good pan survives. Learn the brew from the Alchemy trainer at "
                                    "{trainer}; Sunleaf and boars wait back where you started, by your first "
                                    "village's waystone."},
            "lethariel": {"text": "Eriath wants to answer at the butts the remark that envoys only ever hit "
                                  "decisions. Learn the brew from the Alchemy trainer at {trainer}; the "
                                  "ingredients grow and roam back where you started, by your first village's "
                                  "waystone."},
            "gor_drazhak": {"text": "Thorga mocked a recruit's aim and now has to step up to the target "
                                    "herself. Learn the brew from the Alchemy trainer at {trainer}; Sunleaf and "
                                    "boars wait back where you started, by your first village's waystone."},
            "kezamba": {"text": "Nalo wants to hit a hanging fruit target before Teshani takes it back for "
                                "the kitchen. Learn the brew from the Alchemy trainer at {trainer}; the "
                                "ingredients wait back where you started, by your first village's waystone."},
            "nhal_veyr": {"text": "Ossa keeps an old list of hits and wants her own entry improved before "
                                  "another century passes over it. Learn the brew from the Alchemy trainer at "
                                  "{trainer}; Sunleaf and boars wait back where you started, by your first "
                                  "village's waystone."},
        },
        "completion": {
            "highcourt": "Mariel: whatever the match brings, the elixir promises no hit; she thanks the player "
                         "with dry humour.",
            "dur_brannoc": "Dorrin: the pan plate may ring, the good pan stays whole; no guarantee of a win.",
            "lethariel": "Eriath: a steady hand, not a promised hit; the remark will be answered either way.",
            "gor_drazhak": "Thorga: she takes her turn at the target; the elixir guarantees nothing.",
            "kezamba": "Nalo: the fruit may yet reach the kitchen; the elixir guarantees no hit.",
            "nhal_veyr": "Ossa: she will enter the result honestly, whatever it is.",
        },
    },
    {
        "id": "capital_raw_meat", "giver": "cook", "line": "provisions", "min_level": 20, "level": 21,
        "title": "Meat for the Capital's Kitchen",
        "objectives": [item("mobs:meat_raw", 8, ["moss_antler_stag"], "elandor_lethariel/glades")],
        "rewards": {"weight": 2},
        "lesson": "A daytime errand on the capital's outskirts.",
        "duration_min": 8,
        "notes": "Draft §4 and the check's fix: the cooks' simple Raw Meat deliveries as one shared task "
                 "(Highcourt's cook asks for a Gnarled Boar Tusk, Varda's Mire Carp is BANDQUESTS' fish "
                 "quest); each capital's day game as the named source.",
        "capitals": {
            "lethariel": {"roles": ["moss_antler_stag"], "area": "elandor_lethariel/glades",
                          "text": "Mirael Petalpot: the Star Hall wants a meal worthy of its deliberations, "
                                  "ready before they end; 8 Raw Meat from the glades' game by day."},
            "gor_drazhak": {"roles": ["watchful_zebra"], "area": "kragmar_gor_drazhak/steppe",
                            "text": "Gorla Longladle: the ladle commands, and hungry fighters line up; 8 Raw "
                                    "Meat from the steppe's game by day."},
            "kezamba": {"roles": ["reed_tapir"], "area": "kragmar_kezamba/canopy",
                        "text": "Teshani Smokereed: half of Kezamba follows its nose to the smokehouse; 8 Raw "
                                "Meat from the canopy's game by day."},
            "nhal_veyr": {"roles": ["moss_antler_stag"], "area": "kragmar_nhal_veyr/blightfields",
                          "text": "Velis Mourningbowl: places set for mourners who forgot there is a kitchen; "
                                  "8 Raw Meat from the blightfields' game by day."},
        },
    },
]

# ---------------------------------------------------------------- local
# Per capital its own quests: (id, giver, turnin or None, line, min, level,
# objectives, weight, choices or None, text, completion or None, lesson,
# duration, notes). A kept id keeps its shipped objectives (plan §3: new ids
# where objectives change, but the ids the story needs and the handovers).
KEPT = "Round 60 CAPITALS: the id stays (objectives unchanged); free play, a level only."
NEW = "Round 60 CAPITALS: a new id (its objectives changed); free play, a level only."
HANDOVER = ("Round 60 CAPITALS: the handover id stays; free play, it requires nothing and claims no earlier "
            "deed (draft §10).")


def climax(qid, role, minimum, level, text, completion, notes=NEW):
    return {"id": qid, "giver": "envoy", "line": "envoy", "min_level": minimum, "level": level,
            "objectives": [kill([role], 1)], "weight": 4.5, "choices": MATERIALS_T3,
            "text": text, "completion": completion, "climax": True,
            "lesson": "The capital's named leader at his camp, alone: the capital's local finale.",
            "duration": 12, "notes": notes}


def handover(qid, giver, turnin, minimum, level, weight, text, lesson, duration, line):
    return {"id": qid, "giver": giver, "turnin": turnin, "line": line, "min_level": minimum, "level": level,
            "objectives": [talk(turnin)], "weight": weight, "text": text, "lesson": lesson,
            "duration": duration, "notes": HANDOVER}


def departure(qid, turnin, minimum, level, weight, text, duration=10):
    return handover(qid, "envoy", turnin, minimum, level, weight, text,
                    "Capital to contested handoff at 30.", duration, "envoy")


def dispatch(qid, turnin, minimum, level, weight, text, duration=10):
    return handover(qid, "cook", turnin, minimum, level, weight, text, "Capital to band handoff.", duration,
                    "dispatch")


LOCAL = {
    "highcourt": [
        climax("highcourt_penn", "tollmaster_penn", 27, 29,
               "Mariel: Bandit Tollmaster Penn dresses private collections as royal tolls at his camp; end "
               "his business. Penn alone is the task.",
               "Mariel: the complaints stop with Penn; the crown's mark is the crown's again."),
        {"id": "highcourt_provisions_01", "giver": "cook", "line": "provisions", "min_level": 21, "level": 22,
         "objectives": [item("grug_mobs:gnarled_boar_tusk", 1, ["furrow_boar"], "elandor_highcourt/commons")],
         "weight": 1.5,
         "text": "Ansel Ovenward: his bread board rocks and the royal kitchen lends pegs with conditions; one "
                 "Gnarled Boar Tusk from the commons' boars by day.",
         "lesson": "A daytime errand that leaves your enchant stock alone.", "duration": 8, "notes": KEPT},
        {"id": "highcourt_provisions_venison", "giver": "cook", "line": "provisions", "min_level": 21,
         "level": 22, "objectives": [kill(["moss_antler_stag"], 6, "elandor_highcourt/commons")], "weight": 3,
         "text": "Ansel: the palace ordered venison for the long table and left the hunting to whoever "
                 "stands by his oven; six of the commons' bucks by day.",
         "lesson": "Neutral daytime game on the capital commons.", "duration": 9, "notes": KEPT},
        dispatch("highcourt_dispatch_01", "r20_anchor_016_host", 21, 22, 1,
                 "Ansel: he paid for river baskets and got a confident promise; ask Merren Oakstamp at "
                 "Whitebridge Market Close what became of the order.", 8),
        dispatch("highcourt_dispatch_02", "r20_anchor_031_host", 29, 29, 1,
                 "Ansel: the watch at Cinderline eats his bread and stands between the Accord's homes and "
                 "the fighting; offer Toren Waterbarrel help in Ashenward March, at 30 or later."),
    ],
    "dur_brannoc": [
        climax("durbrannoc_brakk", "ore_factor_brakk", 27, 29,
               "Dorrin: Goblin Ore-Factor Brakk buys stolen ore and pays in stamped purses at the goblin "
               "camp; close his account. Brakk alone is the task.",
               "Dorrin: Brakk's account is closed; the stamped purses lose their buyer."),
        {"id": "durbrannoc_provisions_optional", "giver": "cook", "line": "provisions", "min_level": 24,
         "level": 26, "objectives": [kill(["hill_ram"], 6, "elandor_dur_brannoc/uplands")], "weight": 3.5,
         "text": "Varda Copperpan: a ram for the roast; six of the uplands' rams by day.",
         "lesson": "A day hunt of the middle belt.", "duration": 9, "notes": KEPT},
        dispatch("durbrannoc_dispatch_01", "r20_anchor_014_host", 21, 22, 1,
                 "Varda: Edda Tarnmantle in Frostbarrow Shelf waits for the other half of her order; go and "
                 "ask what she needs.", 8),
        dispatch("durbrannoc_dispatch_whitebridge", "r20_anchor_016_host", 22, 23, 1,
                 "Varda: a neighbour's table; Merren Oakstamp in Whitebridge Shire could use a helper."),
        dispatch("durbrannoc_dispatch_highcourt", "r20_human_capital_envoy", 22, 23, 1,
                 "Varda: her recommendation to Mariel Waybook in Highcourt, who always has work."),
        dispatch("durbrannoc_dispatch_lorindor", "r20_anchor_018_host", 22, 23, 1,
                 "Varda: room at another hearth; Ilwen Petalmeasure in Lorindor could use a helper."),
        departure("durbrannoc_gate_stormvault", "r20_anchor_027_host", 29, 30, 1,
                  "Dorrin: Borin Splitbolt in Stormvault Heights needs stone-steady help at the front; go at "
                  "30 or later."),
        departure("durbrannoc_gate_ashenward", "r20_anchor_031_host", 29, 30, 1,
                  "Dorrin: beyond our own gate, Toren Waterbarrel in Ashenward March needs help; go at 30 or "
                  "later."),
        departure("durbrannoc_gate_glassroot", "r20_anchor_036_host", 29, 30, 1,
                  "Dorrin: the weight of our word; Faeris Rootbinder in Glassroot Wilds needs help; go at 30 "
                  "or later."),
    ],
    "lethariel": [
        climax("lethariel_rusk", "bough_counter_rusk", 27, 28,
               "Eriath: Poacher Bough-Counter Rusk marks the old trees for the axe with an abused bough-seal "
               "at the poacher camp; stop him. Rusk alone stands for the false records.",
               "Eriath: the seal means tending again; Rusk's handwriting may yet turn up elsewhere."),
        {"id": "lethariel_wardens_opt_01", "giver": "envoy", "line": "envoy", "min_level": 24, "level": 25,
         "objectives": [kill(["redfang_fox"], 6, "elandor_lethariel/greatwood")], "weight": 2.5,
         "text": "Eriath: the foresters know which roots trip them; it is the teeth between the roots; six of "
                 "the greatwood's vixens by day.",
         "lesson": "A day hunt in the greatwood.", "duration": 9, "notes": KEPT},
        dispatch("lethariel_dispatch_01", "r20_anchor_018_host", 21, 22, 1,
                 "Mirael Petalpot: Ilwen Petalmeasure's berry deliveries keep shrinking; ask her at Lorindor "
                 "Berrycourt what the tolls cost.", 8),
        dispatch("lethariel_dispatch_02", "r20_anchor_035_host", 21, 22, 1,
                 "Mirael: Lethen Moonledger forgets his bread collections; find out at the Moonfall "
                 "Observatory what keeps him.", 8),
        departure("lethariel_wardens_04", "r20_anchor_036_host", 29, 30, 1.5,
                  "Eriath: the Glassroot Wilds lie beyond our walls; report to Faeris Rootbinder at Glassroot "
                  "Gate, at 30 or later."),
    ],
    "gor_drazhak": [
        {"id": "gor_drazhak_stingers", "giver": "envoy", "line": "envoy", "min_level": 19, "level": 21,
         "objectives": [kill(["dust_stinger"], 3, "kragmar_gor_drazhak/steppe")], "weight": 2,
         "text": "Thorga Roadspeaker: a sentry needs both feet; three of the steppe's scorpions at night.",
         "lesson": "A short night hunt; a third of a day hunt's count.", "duration": 8, "notes": NEW},
        {"id": "gor_drazhak_muster_02", "giver": "envoy", "line": "envoy", "min_level": 23, "level": 25,
         "objectives": [kill(["dustpack_hyena"], 8, "kragmar_gor_drazhak/badlands")], "weight": 4.5,
         "text": "Thorga: the hyenas take the recruits' lunch; eight of the badlands' hyenas by day.",
         "lesson": "A day hunt in the badlands.", "duration": 12, "notes": KEPT},
        climax("gor_drazhak_garr", "ration_broker_garr", 27, 28,
               "Thorga: Bandit Ration-Broker Garr sells Korr's stolen rations again at the toll camp; stop "
               "his profit. Garr alone is the task, and no finished Redtusk case is assumed.",
               "Thorga: the bowls are filled from honest stores again."),
        dispatch("gor_drazhak_dispatch_01", "r20_anchor_022_host", 21, 22, 1.5,
                 "Gorla Longladle: spears out, word back; Brakka Jarward at Speargrass Wellhold needs hands."),
        dispatch("gor_drazhak_dispatch_02", "r20_anchor_024_host", 22, 23, 1.5,
                 "Gorla: salt keeps a friendship; take her regards to Taleko Drycord at Whisperreed Landing.",
                 12),
        departure("gor_drazhak_muster_04", "r20_anchor_043_host", 29, 29, 1.5,
                  "Thorga: your place in the line; Drek Rampbinder on Bannerbreak Mesa needs help, at 30 or "
                  "later."),
    ],
    "kezamba": [
        {"id": "kezamba_robbers", "giver": "envoy", "line": "envoy", "min_level": 20, "level": 21,
         "objectives": [kill(["toll_bandit"], 3, "kragmar_kezamba/canopy")], "weight": 2,
         "text": "Nalo Pathdrum: someone with boots receives the shrine's offerings; three of the canopy's "
                 "robbers at night.",
         "lesson": "A short night hunt; a third of a day hunt's count.", "duration": 8, "notes": NEW},
        {"id": "kezamba_offerings_04", "giver": "envoy", "line": "envoy", "min_level": 28, "level": 29,
         "objectives": [kill(["offering_broker_takka"], 1)], "weight": 4.5, "choices": MATERIALS_T3,
         "text": "Nalo: Bandit Offering-Broker Takka sells stolen offerings back to the pilgrims at the toll "
                 "camp, and made the pilgrim paths dangerous on purpose; end his trade.",
         "completion": "Nalo: people kneel at the water because they choose to pray again.",
         "climax": True, "lesson": "The capital's named leader at his camp, alone: the capital's local "
                                   "finale.", "duration": 10, "notes": KEPT},
        {"id": "kezamba_smokehouse_02", "giver": "cook", "line": "provisions", "min_level": 24, "level": 25,
         "objectives": [item("grug_mobs:gnarled_boar_tusk", 2, ["monstrous_boar"], "kragmar_kezamba/vinewood")],
         "weight": 2,
         "text": "Teshani Smokereed: the smokehouse racks need new hooks; two Gnarled Boar Tusks from the "
                 "vinewood's Vine Razorbacks.",
         "lesson": "A daytime drop errand.", "duration": 8, "notes": KEPT},
        dispatch("kezamba_dispatch_whispering", "r20_anchor_024_host", 21, 22, 0.5,
                 "Teshani: reeds for smoked fish; give Taleko Drycord at Whisperreed Landing her regards."),
        dispatch("kezamba_dispatch_totemwater", "r20_anchor_047_host", 21, 22, 0.5,
                 "Teshani: Tokai Knotreader foresees everything but the last fish; ask him at Totemwater Post "
                 "what the river says."),
        departure("kezamba_front_thunderroot", "r20_anchor_048_host", 29, 30, 0.5,
                  "Nalo: carry the drumbeat to Rumela Stormstep at Thunderstep Watch, at 30 or later."),
        departure("kezamba_front_blackwind", "r20_anchor_039_host", 29, 30, 0.5,
                  "Nalo: a voice for Ashveil; Vaska Ashlistener on Blackwind Rise needs help, at 30 or later.",
                  14),
    ],
    "nhal_veyr": [
        {"id": "nhal_veyr_vigil_03", "giver": "envoy", "line": "envoy", "min_level": 26, "level": 28,
         "objectives": [kill(["mortuary_clerk_hush"], 1)], "weight": 4.5, "choices": MATERIALS_T3,
         "text": "Ossa Quietregister: Hush once worked at the shared register and kept working copies from "
                 "that post (K11 A); he now enters our dead as debtors in the tombfields. End his collection.",
         "completion": "Ossa: the collection ends; the names stay, and his copies stay a question.",
         "climax": True, "lesson": "The capital's named leader, alone: the local finale and one of chapter "
                                   "2's prerequisites (T3).", "duration": 12,
         "notes": "Round 60 CAPITALS: the id stays although its revenants are gone (plan §3: T3 requires "
                  "it); free play, a level only, its one Throng follow-up is T3."},
        {"id": "story_throng_04", "story": True, "giver": "envoy", "turnin": leader("nhal_veyr"),
         "line": "envoy", "min_level": 29, "level": 29, "requires": T3_REQUIRES,
         "objectives": [use(T3_PLACE, "claim_notice", "Post the claim notice", 3)],
         "weight": 3, "choices": POTIONS_T3,
         "text": "Chapter 2 (T3, Strike the False Claim): Ossa has brought the findings together with Iven and "
                 "the supply; the player posts the confirmed correction at the public register in front of "
                 "the Miner's Guild house and reports to Iven Lastshift. No verdict of the player's own.",
         "completion": "Iven Lastshift: which claims are struck and why the original names stay; he keeps "
                       "the true records for whoever comes with an old sheet later.",
         "lesson": "Chapter 2's Throng close: a town place in the capital and the leader's turn-in.",
         "duration": 8, "notes": "Round 60 CAPITALS: T3 (draft §5, K4 A); requires T2a, the free "
                                  "ossuary_rubbings_03 and nhal_veyr_vigil_03."},
        dispatch("nhal_veyr_dispatch_01", "r20_anchor_020_host", 20, 21, 1.5,
                 "Velis Mourningbowl: Sovel Namekeeper at Ossuary Ledgerstead needs help with the waking "
                 "gravewood; pass on Velis's regards.", 8),
        dispatch("nhal_veyr_dispatch_orc_wellhold", "r20_anchor_022_host", 24, 25, 1,
                 "Velis: Brakka Jarward at Speargrass Wellhold could use another pair of hands."),
        dispatch("nhal_veyr_dispatch_orc_capital", "r20_orc_capital_envoy", 24, 25, 1,
                 "Velis: Thorga Roadspeaker in Gor Drazhak wants help with the roads.", 12),
        dispatch("nhal_veyr_dispatch_troll", "r20_anchor_024_host", 24, 25, 1,
                 "Velis: Taleko Drycord at Whisperreed Landing has work; mind the damp.", 15),
        departure("nhal_veyr_vigil_04", "r20_anchor_039_host", 29, 30, 1.5,
                  "Ossa: Vaska Ashlistener at Ashveil Watch on Blackwind Rise needs help, at 30 or later; no "
                  "finished Hush case is assumed."),
    ],
}


def ph(text):
    return PH + text + TBD


def shared_quests():
    """{zone: [quest]} for the shared quests, each in its first variant's file."""
    out = {}
    for spec in SHARED:
        order = [key for key, _, _ in CAPITALS if key in spec["capitals"]]
        variants = []
        for capital in order:
            fields = spec["capitals"][capital]
            row = {"zone": ZONE[capital], "givers": [GIVER[spec["giver"]](capital)]}
            override = {k: fields[k] for k in ("roles", "area") if k in fields}
            if capital != order[0] and override:
                row["objectives"] = [override]
            row["text"] = ph(fields["text"].replace("{trainer}", TRAINER[capital]))
            if spec.get("completion"):
                row["completion"] = ph(spec["completion"][capital])
            variants.append(row)
        quest = {"id": spec["id"], "line": spec["line"], "min_level": spec["min_level"],
                 "level": spec["level"], "requires": [], "title": PH + spec["title"], "text": variants[0]["text"]}
        if spec.get("completion"):
            quest["completion"] = variants[0]["completion"]
        quest.update({"objectives": [dict(o) for o in spec["objectives"]], "variants": variants,
                      "rewards": dict(spec["rewards"]), "lesson": spec["lesson"],
                      "duration_min": spec["duration_min"], "notes": "Round 60 CAPITALS. " + spec["notes"]})
        out.setdefault(ZONE[order[0]], []).append(quest)
    return out


TITLES = {
    "highcourt_penn": "The Last Unauthorised Stamp",
    "highcourt_provisions_01": "A Peg for the Bread Board",
    "highcourt_provisions_venison": "The Long Table",
    "highcourt_dispatch_01": "The Empty River Baskets",
    "highcourt_dispatch_02": "Bread for the March",
    "durbrannoc_brakk": "Close Brakk's Account",
    "durbrannoc_provisions_optional": "A Ram for the Roast",
    "durbrannoc_dispatch_01": "The Other Half of Edda's Order",
    "durbrannoc_dispatch_whitebridge": "A Neighbour's Table",
    "durbrannoc_dispatch_highcourt": "Varda's Recommendation",
    "durbrannoc_dispatch_lorindor": "Room at Another Hearth",
    "durbrannoc_gate_stormvault": "Stone Enough to Stand On",
    "durbrannoc_gate_ashenward": "Beyond Our Own Gate",
    "durbrannoc_gate_glassroot": "The Weight of Our Word",
    "lethariel_rusk": "What the Seal Was For",
    "lethariel_wardens_opt_01": "A Forester's Path",
    "lethariel_dispatch_01": "The Missing Half of the Pie",
    "lethariel_dispatch_02": "Bread Does Not Keep Star-Time",
    "lethariel_wardens_04": "Where the Writ Wears Thin",
    "gor_drazhak_stingers": "A Sentry Needs Both Feet",
    "gor_drazhak_muster_02": "Lunch Is Not Included",
    "gor_drazhak_garr": "His Profit, Our Empty Bowls",
    "gor_drazhak_dispatch_01": "Spears Out, Word Back",
    "gor_drazhak_dispatch_02": "Salt Keeps a Friendship",
    "gor_drazhak_muster_04": "Your Place in the Line",
    "kezamba_robbers": "The Spirits Left Footprints",
    "kezamba_offerings_04": "The Price of a Prayer",
    "kezamba_smokehouse_02": "Keep Supper Hanging",
    "kezamba_dispatch_whispering": "Regards from the Smokehouse",
    "kezamba_dispatch_totemwater": "Even Seers Need Supper",
    "kezamba_front_thunderroot": "Carry the Drumbeat",
    "kezamba_front_blackwind": "A Voice for Ashveil",
    "nhal_veyr_vigil_03": "The Account Is Closed",
    "story_throng_04": "Strike the False Claim",
    "nhal_veyr_dispatch_01": "My Regards Keep Better",
    "nhal_veyr_dispatch_orc_wellhold": "Sister Errand: Hands Attached",
    "nhal_veyr_dispatch_orc_capital": "Sister Errand: Someone Turns Up",
    "nhal_veyr_dispatch_troll": "Sister Errand: Try to Stay Dry",
    "nhal_veyr_vigil_04": "A Debt Freely Owed",
}


def local_quests(capital):
    rows = []
    for q in LOCAL[capital]:
        giver = GIVER[q["giver"]](capital)
        row = {"id": q["id"], "line": q["line"]}
        if q.get("story"):
            row["story"] = True
        row.update({"giver": giver, "turnin": q.get("turnin", giver), "min_level": q["min_level"],
                    "level": q["level"], "requires": list(q.get("requires", [])),
                    "title": PH + TITLES[q["id"]], "text": ph(q["text"])})
        if q.get("completion"):
            row["completion"] = ph(q["completion"])
        row["objectives"] = q["objectives"]
        row["rewards"] = {"weight": q["weight"]}
        if q.get("choices"):
            row["rewards"]["choices"] = [dict(c) for c in q["choices"]]
        row["lesson"] = q["lesson"]
        row["duration_min"] = q["duration"]
        if q.get("climax"):
            row["climax"] = True
        row["notes"] = q["notes"]
        rows.append(row)
    return rows


def hubs(capital):
    """The capital's two hubs: the envoy and the cook; the guild leader alone
    (Round 59, anchored at the zone as the camps' foreman hubs are)."""
    return [
        {"id": capital, "anchor": capital,
         "givers": [{"npc": envoy(capital), "lines": list(LINES["envoy"])},
                    {"npc": cook(capital), "lines": list(LINES["cook"])}]},
        {"id": capital + "_guild", "anchor": "zone",
         "givers": [{"npc": leader(capital), "lines": list(LINES["leader"])}]},
    ]


# The text fields (the text lane's): --check compares the rest, the structure.
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
    for capital, zone, _ in CAPITALS:
        path = QUESTS / ("%s.quests.json" % zone)
        data = json.loads(path.read_text(encoding="utf-8"))
        by_id = {q["id"]: q for q in data["quests"]}
        chapter1 = [by_id[qid] for qid in CHAPTER1.get(capital, ())]
        quests = chapter1 + shared.get(zone, []) + local_quests(capital)
        out = {"zone": data["zone"], "reworked": True, "identity": data["identity"],
               "hubs": hubs(capital), "quests": quests}
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
