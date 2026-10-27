#!/usr/bin/env python3
"""Round 62 lane FRONTQUESTS: write the front 41-60's quest structure.

The fourteen files of levels 41-60 that Round 61 left unflagged (the ten
`.front` files of the four contested hosts and six capitals, the four
Battlegrounds base files) are rebuilt on the Round 57 quest foundation
(docs/design/quests.md "The front 41-60"), from the story layer the user
picked (round62-plan.md §2, §2a; chapter-4 draft, every recommendation
K1-K13 "A", with the feasibility check's fixes):

- the main line (Round 36) is the story path: the 31 spine steps of
  tools/r36_qa (17) and tools/r36_qt (14), the four climaxes on Senn,
  Ninepins, Huskell and Chirr among them, are `story` and require only
  spine steps (K12 A: kz_front_04, Chirr, requires bw_front_ashveil_04,
  Huskell); their ids, objectives, levels, texts and hand-offs stay, each
  gets a placeholder completion; the war commander hunts stay optional
  story branches;
- every other front quest is free play: it requires only a level and has at
  most one follow-up per faction (the fortress raids' second camp, the
  island bounty pairs);
- the fortress quests (Round 31) as they ship;
- the shared front tasks (one quest, one level, one title, the hosts' line
  `border`, homed in the first variant's base file): the draft's F1-F10,
  Engine Nine and Last-Toll among them as optional group quests at 50;
- the hosts' and envoys' own tasks, the departures to Dorrin (K1 A), Thorga,
  Eriath, Vaska and Ossa, the Throng's island bounty pair at Thorga (K9 A);
- the Round 58 guild content in the Battlegrounds files as shipped;
- the reward pattern per faction and level band (round62-plan.md §2 point 5).

Every file is marked `"reworked": true`.

This script writes the structure with placeholder texts ("[PH] ..."; each
names the draft's intent for the text lane FRONTTEXT); the spine keeps its
shipped texts and gets placeholder completions. Once the real texts land
the JSON files are their source: rerunning it without --check writes the
placeholders back. Run from the repository root:

    python3 tools/r62_frontquests/build_structure.py [--check]

--check exits 1 when the files' structure differs from what the script
would write: everything but the texts (titles, texts, a giver's or race's
texts, completions, a variant's text and completion), so it holds once the
real texts are in. Python 3 standard library only.
"""
import argparse
import copy
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"

PH = "[PH] "
TBD = " Real text to follow."
NOTE = "Round 62 FRONTQUESTS. "

NPC = {
    # the Round 20 hosts
    "borin": "r20_anchor_027_host", "alna": "r20_anchor_028_host", "toren": "r20_anchor_031_host",
    "nella": "r20_anchor_032_host", "vaska": "r20_anchor_039_host", "orrel": "r20_anchor_040_host",
    "drek": "r20_anchor_043_host", "yarra": "r20_anchor_044_host",
    # the capital envoys
    "mariel": "r20_human_capital_envoy", "dorrin": "r20_dwarf_capital_envoy", "eriath": "r20_elf_capital_envoy",
    "thorga": "r20_orc_capital_envoy", "nalo": "r20_troll_capital_envoy", "ossa": "r20_undead_capital_envoy",
}
ZONE_OF = {"toren": "elandor_ashenward_march", "nella": "elandor_ashenward_march",
           "alna": "elandor_stormvault_heights", "borin": "elandor_stormvault_heights",
           "drek": "kragmar_bannerbreak_mesa", "yarra": "kragmar_bannerbreak_mesa",
           "orrel": "kragmar_blackwind_rise", "vaska": "kragmar_blackwind_rise"}

# The eight new recipe places (draft §4) and the places the draft reuses.
P1 = "front_broken_causeway/return_stand"
P2 = "front_shattered_line/relief_rest"
P3 = "front_broken_causeway/crossing_stand"
P4 = "front_gravesalt_escarpment/shoring_check"
P5 = "front_gravesalt_escarpment/work_laydown"
P6 = "front_gravesalt_escarpment/recovery_post"
P7 = "front_skyglass_canopy/carrier_clearing"
P8 = "front_skyglass_canopy/receiving_stand"
STORMVAULT_LOAD = "socket:mining_camp_stormvault_heights/held_load"
DUR_BRANNOC_APRON = "socket:dur_brannoc/forge_ore_yard/forge_ore_yard_loading_apron"
GOR_DRAZHAK_DEPOT = "socket:gor_drazhak/warren_cook_court/warren_cook_court_water_depot"
NHAL_VEYR_COURT = "socket:nhal_veyr/homes_mourners_hall/homes_mourners_hall_receiving_court"

# ---------------------------------------------------------------- rewards
# Tier 5 at item levels 41-50, tier 6 at 51-60 (grug_gear TIERS; survey
# §10). An equipment choice offers one item per armor class or weapon line.
ARMOR = {5: {"cloth": "silk", "leather": "sleek", "metal": "embersteel"},
         6: {"cloth": "stormweave", "leather": "nightscale", "metal": "abyssal_steel"}}
WEAPON = {5: "embersteel", 6: "abyssal_steel"}
# The first piece: the class's main stat as a prefix; the second: a second
# stat as a suffix (grug_quality POOLS), as the bands 11-40.
PREFIX = {"cloth": ("prefix", "int"), "leather": ("prefix", "dex"), "metal": ("prefix", "str")}
SUFFIX = {"cloth": ("suffix", "max_mana_percent"), "leather": ("suffix", "crit_percent"),
          "metal": ("suffix", "max_hp_percent")}
# Plain trinkets (grug_gear/trinkets.lua), no enchant (no reward budget):
# three sets, one of each form (amulet, ring, medallion).
TRINKETS = {"a": ("manawell", "battlebeat", "mercy_seal"), "b": ("last_light", "apothecary_loop", "reclaimers_mark"),
            "c": ("last_light", "battlebeat", "mercy_seal")}


def tier_of(level):
    return 5 if level <= 50 else 6


def armor(slot, tier, affix):
    return [{"item": "grug_gear:%s_%s_%s" % (slot, c, ARMOR[tier][c]),
             "affixes": [{"channel": affix[c][0], "stat": affix[c][1]}]}
            for c in ("cloth", "leather", "metal")]


def weapons(tier, melee):
    """One weapon per weapon line (caster, scout, warrior; Priest and Mage
    share), prefix and suffix each; the two-handed Staff where the Battle
    Axe is offered, the Wand beside the Sword."""
    metal = WEAPON[tier]
    caster = ("staff_" if melee == "greataxe" else "wand_") + metal
    warrior = {"sword": ("sword_" + metal, "crit_percent"), "greataxe": ("greataxe_" + metal, "max_hp_percent")}[melee]
    return [
        {"item": "grug_gear:" + caster, "affixes": [{"channel": "prefix", "stat": "int"},
                                                    {"channel": "suffix", "stat": "max_mana_percent"}]},
        {"item": "grug_gear:bow_" + metal, "affixes": [{"channel": "prefix", "stat": "dex"},
                                                       {"channel": "suffix", "stat": "attack_speed_percent"}]},
        {"item": "grug_gear:" + warrior[0], "affixes": [{"channel": "prefix", "stat": "str"},
                                                        {"channel": "suffix", "stat": warrior[1]}]},
    ]


def choices(kind, level):
    """A reward spec: potions, armor:<slot>:<prefix|suffix>,
    weapon:<sword|greataxe>, trinkets:<a|b|c>."""
    tier = tier_of(level)
    parts = kind.split(":")
    if parts[0] == "potions":
        return [{"item": "grug_alchemy:potion_healing_t%d" % tier, "count": 2},
                {"item": "grug_alchemy:potion_mana_t%d" % tier, "count": 2}]
    if parts[0] == "armor":
        return armor(parts[1], tier, PREFIX if parts[2] == "prefix" else SUFFIX)
    if parts[0] == "weapon":
        return weapons(tier, parts[1])
    if parts[0] == "trinkets":
        return [{"item": "grug_gear:%s_t%d" % (t, tier)} for t in TRINKETS[parts[1]]]
    raise ValueError(kind)


def rewards(weight, kind, level, copper=None):
    row = {"weight": weight}
    if copper is not None:
        row["copper"] = copper
    if kind:
        row["choices"] = choices(kind, level)
    return row


# ---------------------------------------------------------------- objectives
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
    return {"type": "talk", "npc": NPC[who]}


def use(place, obj, label, hold=4):
    return {"type": "use", "place": place, "object": obj, "label": label, "hold": hold}


# ---------------------------------------------------------------- the spine
# id: (requires, completion intent, reward kind or None). The ids, order,
# levels, objectives, texts and hand-offs stay (r36_qa, r36_qt); a reward
# kind replaces the choices (the weight stays).
SPINE = {
    # The Accord (17): chapter 1 at 41, chapter 2 at 46, chapter 3 at 53, the finale at 60.
    "accord_main_impounded": ([], "Toren is to find out who passes such bundles on; Audra Wainholt is named as the "
                              "source of the real list of needs; Odren Vell is not yet suspected (K2 A: the pay was "
                              "stopped before it reached the carriers and camp workers).", "potions"),
    "cinderline_front_05": (["accord_main_impounded"], "Toren can name the transport trail but not explain the brand "
                            "on the coins; he prepares the hand-over to Alna.", None),
    "cinderline_front_04": (["cinderline_front_05"], "Alna names the two things her next task tests: the bones and "
                            "the brand. No further names.", None),
    "archshadow_front_02": (["cinderline_front_04"], "Alna ties the bones' renewed service and the brand's renewed "
                            "payment to Senn's toll business and sends the player against the man who keeps the "
                            "crossing deadly.", None),
    "archshadow_front_03": (["archshadow_front_02"], "The evidence is enough for a report to the Warmaster; Chirr "
                            "appears as a further payer, and the link to The Throng stays a suspicion.", None),
    "accord_main_accounts": (["archshadow_front_03"], "The Warmaster ties toll, dead and pay together and sends the "
                             "player to a pledged standard on the Shattered Line; Audra's regular deliveries stay "
                             "apart from the suspect pay.", None),
    "accord_main_standard": (["accord_main_accounts"], "Nella recognises who holds the dead's muster together: "
                             "Ninepins. Her own free supply work stays separate.", None),
    "lasthedge_front_04": (["accord_main_standard"], "Ninepins enforced orders, he did not start the curse; Nella "
                           "points to the Warmaster, who wants the enemy's military side checked.", "trinkets:c"),
    "accord_main_orders": (["lasthedge_front_04"], "The orders show impounded pay and harmed Throng soldiers, "
                           "wrapped in real Ashenward forms with Odren Vell's countersignature (his former office "
                           "explained); the Warmaster wants them checked at the Courier's Stump.", None),
    "accord_main_audit": (["accord_main_orders"], "The Warmaster seals the finding about Vell; Audra gets the "
                          "practical correction for her deliveries, the guild is not blamed; the trail leads on to "
                          "Borin (K3 A, K4 A).", None),
    "accord_main_roll": (["accord_main_audit"], "Borin ties the trail to Huskell's watch and can offer free salvage "
                         "work; the attack on Huskell stays at its later level.", "potions"),
    "splitbolt_front_08": (["accord_main_roll"], "The roll lists soldiers of both armies and, freshly entered, Odren "
                           "Vell himself; Borin points to the payer's marks in the roots and to Eriath.",
                           "weapon:greataxe"),
    "splitbolt_front_06": (["splitbolt_front_08"], "Eriath names Chirr and his archers; Rusk may appear as Eriath's "
                           "own past, never as the player's deed.", None),
    "lethariel_front_04": (["splitbolt_front_06"], "Eriath explains why Chirr's death alone does not clear the "
                           "entries; next come Skyroot Crossing and the Tombroad tally-stone.", "armor:chest:suffix"),
    "accord_main_tally": (["lethariel_front_04"], "The Warmaster names Isquarre and prepares the group task; the own "
                          "names, Vell's among them, stay in the report.", None),
    "accord_main_collector": (["accord_main_tally"], "The Warmaster accepts the battle report and asks for the final "
                              "report; no new item, no new foe.", None),
    "accord_main_final": (["accord_main_collector"], "The Warmaster closes the human work (honest pay, supply and "
                          "the recovered names under clear responsibility; Audra stays at her post, Vell's name "
                          "stays the Accord's own responsibility, K6 A) and ends with the fixed last line; nothing "
                          "follows it.", "weapon:sword"),
    # The Throng (14).
    "throng_main_01": ([], "Greda Stonehaul's confirmed needs give the comparison; Drek follows the payment; Mardra "
                       "is not yet shown as the culprit.", "potions"),
    "bb_front_ramp_04": (["throng_main_01"], "Senn earns from the dead on the crossing and his accounts name Chirr "
                         "and seemingly Accord requisitions; Drek needs someone who can judge the entries for the "
                         "dead: Orrel.", None),
    "bb_front_ramp_05": (["bb_front_ramp_04"], "Orrel sets the inquiry at the Ashen Grave; Hush may be prepared as "
                         "a comparison for his way of keeping books.", None),
    "throng_main_02": (["bb_front_ramp_05"], "The Warmaster gets the link between names, pay and renewed service; "
                       "the pledged standard comes next.", None),
    "throng_main_03": (["throng_main_02"], "Yarra names Ninepins as the local enforcer; the barred name of the "
                       "standard's site appears in no text.", None),
    "bb_front_torn_05": (["throng_main_03"], "The renewed service can be broken locally, but Ninepins did not start "
                         "the money trail; the Warmaster turns the next inquiry to the enemy captain.", "trinkets:c"),
    "throng_main_04": (["bb_front_torn_05"], "The orders show Accord victims and impounded pay; the Warhold tally "
                       "marks lead to Tallykeeper Mardra, whose responsibility the Warmaster names openly; the "
                       "unaccepted pay is to leave circulation at Coinpit Hollow.", None),
    "throng_main_05": (["throng_main_04"], "Greda hears that honest work and its pay still stand; Mardra's removal "
                       "from her office takes no worker's claim (K5 A).", None),
    "throng_main_06": (["throng_main_05"], "Vaska ties the voices to Huskell's watch; her free tasks look after "
                       "those left behind and the recovered things.", "potions"),
    "bw_front_ashveil_04": (["throng_main_06"], "The roll holds dead of both armies and, last, Mardra; her guilt "
                            "gives the Undertithe no claim. Vaska points to Nalo and the payer in the Skyglass "
                            "Canopy.", None),
    "kz_front_04": (["bw_front_ashveil_04"], "Chirr turned a promised payment into branded claims; Nalo points "
                    "back to Vaska, who must have the last claim at the Tombroad tally-stone broken (K12 A: after "
                    "Huskell).", "armor:chest:suffix"),
    "throng_main_07": (["bw_front_ashveil_04", "kz_front_04"], "The Warmaster names Isquarre as the collector of "
                       "this claim and opens the later group finale; Mardra is not acquitted.", None),
    "throng_main_finale": (["throng_main_07"], "Vaska hears what remains after his fall and sends the player to the "
                           "Warmaster.", None),
    "throng_main_final": (["throng_main_finale"], "The military report and the responsibility for the names are "
                          "closed; Greda stands for promises that still hold, Mardra stays part of the faction's "
                          "own story; ends with the fixed last line, no new journey.", "weapon:greataxe"),
}
# The optional story branches (the war commanders, Round 36): story, a
# trinket choice, their requires as shipped.
BRANCHES = {"accord_main_stonegrudge": "trinkets:c", "throng_main_greyvow": "trinkets:c"}

# ---------------------------------------------------------------- shared
# The draft's F1-F10 (§3): one quest, one level, one title, the hosts'
# line `border`, a variant per giver, homed in the first variant's base
# file. The check's fix for F1 (it repeated `border_meal`'s meal from the
# same givers): seed potatoes for the field plots instead of a meal.
SHARED = [
    {"id": "front_potatoes", "min_level": 41, "level": 42, "weight": 3, "reward": "potions",
     "title": "Seed for the Trampled Plots",
     "objectives": [item("grug_gathering:potato", 8)],
     "givers": [("toren", {"text": "Toren wants seed potatoes so the outposts' trampled field plots grow "
                                   "something of their own again: bring 8 Potatoes."}),
                ("drek", {"text": "Drek wants seed potatoes for the plots behind the ramps, so not every meal "
                                  "has to be hauled in: bring 8 Potatoes."})],
     "duration": 8, "notes": "Draft F1, the check's fix: another purpose than border_meal (Corn, the same givers): "
                             "seed for the field plots, not a meal; the early potion choice."},
    {"id": "front_return_light", "min_level": 42, "level": 43, "weight": 3, "reward": "armor:feet:prefix",
     "title": "A Light for the Return",
     "objectives": [use(P1, "signal_lantern", "Light the return lantern")],
     "givers": [("toren", {"text": "Toren wants the prepared return lantern at the "
                                   "{name:front_broken_causeway/return_stand} made ready, so his carters find the "
                                   "dry stand at dusk; no escort."}),
                ("drek", {"text": "Drek wants the return lantern at the {name:front_broken_causeway/return_stand} "
                                  "lit for the crews coming back across the floodmeadows; no escort."})],
     "duration": 10, "notes": "Draft F2: a use at the new recipe place P1 (the Causeway's floodmeadows); the first "
                              "armor choice of Ashenward and Bannerbreak."},
    {"id": "front_relief_count", "min_level": 43, "level": 44, "weight": 3, "reward": None,
     "title": "The Relief Is Counted",
     "objectives": [use(P2, "witness_record", "Record who has reported back")],
     "givers": [("nella", {"text": "Nella wants it written down at the {name:front_shattered_line/relief_rest} "
                                   "which of her work parties have reported back and where relief is missing."}),
                ("yarra", {"text": "Yarra wants to know which promised reliefs actually arrived: record the "
                                   "returns at the {name:front_shattered_line/relief_rest}."})],
     "duration": 10, "notes": "Draft F4: a use at the new recipe place P2 (the Shattered Line's approaches)."},
    {"id": "front_ford_salvage", "min_level": 44, "level": 45, "weight": 3, "reward": "weapon:sword",
     "title": "What the Ford Kept",
     "objectives": [use("r20_anchor_079", "held_supplies", "Secure the stranded load")],
     "givers": [("toren", {"text": "Toren wants the usable stores and tools of a stranded load secured at "
                                   "{name:r20_anchor_079}."}),
                ("drek", {"text": "Drek wants what can still be used of the stranded freight at "
                                  "{name:r20_anchor_079} secured before the water takes it."})],
     "duration": 12, "notes": "Draft F3: a use at the free clash site 079; the weapon of Ashenward and Bannerbreak "
                              "(a solo quest)."},
    {"id": "front_salt_stores", "min_level": 44, "level": 45, "weight": 3, "reward": None,
     "title": "Salt for the Stores",
     "objectives": [item("grug_cooking:salt_crust", 6)],
     "givers": [("nella", {"text": "Nella needs salt to keep the front's stores from spoiling; the Shattered "
                                   "Line's badlands have it: bring 6 Salt Crust."}),
                ("yarra", {"text": "Yarra needs salt so the stores last until the next delivery: bring 6 Salt "
                                   "Crust."})],
     "duration": 9, "notes": "Draft F5: Salt Crust (the Shattered Line, or a salt pan)."},
    {"id": "front_stormkelp", "min_level": 47, "level": 48, "weight": 3, "reward": "armor:legs:suffix",
     "title": "Stormkelp for the Field Kits",
     "objectives": [item("grug_gathering:stormkelp", 8)],
     "givers": [("alna", {"text": "Alna needs Stormkelp for the field kits she prepares herself: bring 8 "
                                  "Stormkelp."}),
                ("orrel", {"text": "Orrel needs Stormkelp for the field kits of the recovery parties: bring 8 "
                                   "Stormkelp."})],
     "duration": 9, "notes": "Draft F7: the host processes it; the second armor choice of Stormvault and "
                             "Blackwind."},
    {"id": "front_old_wire", "min_level": 48, "level": 49, "weight": 3, "reward": "armor:head:suffix",
     "title": "Cut the Old Wire",
     "objectives": [use("r20_anchor_083", "snare_bundle", "Cut the old snare wire")],
     "givers": [("nella", {"text": "Nella wants the old wire snares on the carriers' way through "
                                   "{name:r20_anchor_083} cut away; nothing about the ground changes."}),
                ("yarra", {"text": "Yarra wants the old snares at {name:r20_anchor_083} cleared off the path her "
                                   "carriers use."})],
     "duration": 11, "notes": "Draft F6: a use at the free clash site 083 (late in the zone); the second armor "
                              "choice of Ashenward and Bannerbreak."},
    {"id": "front_engine_nine", "min_level": 49, "level": 50, "weight": 6, "reward": "trinkets:a", "group": True,
     "title": "Party: Stop the Grinding",
     "objectives": [kill(["siege_engine_nine"], 1)],
     "givers": [("nella", {"text": "Nella asks for a party against {name:siege_engine_nine}, which threatens "
                                   "salvage and supply on the Shattered Line; optional, nothing needs it."}),
                ("yarra", {"text": "Yarra asks for a party against {name:siege_engine_nine} before it grinds "
                                   "another supply run down; optional, nothing needs it."})],
     "duration": 15, "notes": "Draft F8: the optional group quest (below 51: free, standalone, a trinket choice "
                              "as its extra, never the key reward); replaces lasthedge_front_05 and "
                              "bb_front_torn_06."},
    {"id": "front_last_toll", "min_level": 49, "level": 50, "weight": 6, "reward": "trinkets:b", "group": True,
     "title": "Party: Close the Toll",
     "objectives": [kill(["last_toll_construct"], 1)],
     "givers": [("alna", {"text": "Alna asks for a party against {name:last_toll_construct}, one more deadly grip "
                                  "on the Causeway's crossing; optional, nothing needs it."}),
                ("orrel", {"text": "Orrel asks for a party against {name:last_toll_construct}, which keeps the "
                                   "crossing a grave; optional, nothing needs it."})],
     "duration": 15, "notes": "Draft F9: the optional group quest (as F8); replaces archshadow_front_04 and "
                              "bw_front_hollow_03."},
    {"id": "front_beyond_line", "min_level": 50, "level": 50, "weight": 1, "reward": None,
     "title": "Work Beyond the Line",
     "objectives": [talk("borin")],
     "givers": [("nella", {"turnin": "borin",
                           "text": "Nella sends the player to Borin Splitbolt, who needs people for the work "
                                   "beyond the old front; no earlier deed is claimed."}),
                ("alna", {"turnin": "borin",
                          "text": "Alna sends the player to Borin Splitbolt, whose crews work beyond the old "
                                  "front; no earlier deed is claimed."}),
                ("yarra", {"turnin": "nalo",
                           "text": "Yarra sends the player to Nalo Pathdrum in Kezamba, whose carriers work "
                                   "beyond the old front; no earlier deed is claimed."})],
     "duration": 10, "notes": "Draft F10: the free departure at 50 (Nella or Alna to Borin, Yarra to Nalo), one "
                              "title and one level; replaces lasthedge_front_06, archshadow_front_05 and "
                              "bb_front_torn_07."},
]
FRONT_SHARED = tuple(spec["id"] for spec in SHARED)

# ---------------------------------------------------------------- local
# Rows of the hosts' and envoys' own front quests (line `front`, in the
# giver's `.front` file): id, giver, min level, level, objectives, weight,
# reward, title, text (the intent), and optional turnin, completion, group,
# optional, requires, copper, duration, notes. Every id is new; a kept id
# ("keep") takes the shipped quest's objectives, titles and texts.
LOCAL = {
    "elandor_stormvault_heights": [
        {"id": "archshadow_crossing", "giver": "alna", "min_level": 44, "level": 45, "weight": 3,
         "reward": "armor:chest:prefix",
         "objectives": [use(P3, "sighting_frame", "Sight the ground for the crossing")],
         "title": "Ground Worth Crossing",
         "text": "Alna wants the prepared sighting frame at the {name:front_broken_causeway/crossing_stand} used "
                 "to judge which ground of the Causeway still carries a load.",
         "duration": 11, "notes": "Draft AL1: a use at the new recipe place P3 (the Causeway's wraithwood); "
                                  "Stormvault's first armor choice."},
        {"id": "archshadow_road_dorrin", "giver": "alna", "turnin": "dorrin", "min_level": 45, "level": 45,
         "weight": 1, "reward": None, "objectives": [talk("dorrin")],
         "title": "Dur Brannoc Can Supply It",
         "text": "Alna sends the player to Dorrin Gateledger in Dur Brannoc, who coordinates the extra work and "
                 "supply from there; neither Alna's investigation nor a capital quest is needed.",
         "duration": 10, "notes": "Draft AL2 (K1 A): the free departure to Dorrin at 45; the check's fix: no "
                                  "'Guild' in the title (Dorrin is the envoy, Hadrin the guild leader)."},
        {"id": "archshadow_tools_held", "giver": "alna", "min_level": 48, "level": 49, "weight": 3,
         "reward": "weapon:greataxe",
         "objectives": [use(STORMVAULT_LOAD, "held_supplies", "Ready the held tool load")],
         "title": "Tools Held Ready",
         "text": "Alna wants a tool load already set aside at the guild camp's loading ground made ready for "
                 "repairs at the front.",
         "duration": 10, "notes": "Draft AL3: the Stormvault camp's free held load (a town place); Stormvault's "
                                  "weapon (a solo quest)."},
        {"id": "splitbolt_shoring_check", "giver": "borin", "min_level": 50, "level": 51, "weight": 4.5,
         "reward": "armor:head:prefix",
         "objectives": [use(P4, "sighting_frame", "Sight the ground for the shoring")],
         "title": "Before the Weight Comes",
         "text": "Borin wants a prepared point at the {name:front_gravesalt_escarpment/shoring_check} checked for "
                 "ground that carries shoring, before anyone salvages near Huskell's watch.",
         "duration": 11, "notes": "Draft BO1: a use at the new recipe place P4 (Gravesalt's saltflats); free "
                                  "from Borin's arrival at 50; Stormvault's first 51-60 armor choice."},
        {"id": "splitbolt_road_eriath", "giver": "borin", "turnin": "eriath", "min_level": 51, "level": 51,
         "weight": 1, "reward": None, "objectives": [talk("eriath")],
         "title": "A Word for Eriath",
         "text": "Borin sends the player to Eriath Boughwarden in Lethariel, who needs help with the ways and work "
                 "sites of the Skyglass Canopy; Huskell is not assumed.",
         "duration": 10, "notes": "Draft BO2: the free departure to Eriath at 51 (Eriath's work opens at 51)."},
        {"id": "splitbolt_storm_tuna", "giver": "borin", "min_level": 52, "level": 53, "weight": 4.5,
         "reward": "potions", "objectives": [item("grug_fishing:storm_tuna", 5)],
         "title": "A Meal Between Shifts",
         "text": "Borin wants his salvage crews fed between shifts: bring 5 Storm Tuna.",
         "duration": 10, "notes": "Draft BO3: the early 51-60 potion choice (from 52)."},
        {"id": "splitbolt_braces", "giver": "borin", "min_level": 55, "level": 56, "weight": 5,
         "reward": "armor:legs:suffix",
         "objectives": [use(P5, "held_supplies", "Ready the brace load")],
         "title": "Braces Before Salvage",
         "text": "Borin wants the prepared bracing timbers at the {name:front_gravesalt_escarpment/work_laydown} "
                 "checked and made ready for the next salvage.",
         "duration": 11, "notes": "Draft BO4 (K10 A: held_supplies, no new object): a use at the new recipe place "
                                  "P5 (Gravesalt's blight terraces); Stormvault's second 51-60 armor choice."},
        {"keep": "splitbolt_front_09", "requires": [], "reward": "trinkets:a",
         "notes": "Draft BO5 (K11 A): the optional group quest on Salt-Counter, standalone from its level; its id "
                  "and objective stay, its prerequisite goes; a trinket choice."},
    ],
    "elandor_lethariel": [
        {"id": "lethariel_carrier_path", "giver": "eriath", "min_level": 51, "level": 52, "weight": 4.5,
         "reward": "armor:chest:prefix",
         "objectives": [use(P7, "snare_bundle", "Loosen the carriers' snare")],
         "title": "A Path for Carriers",
         "text": "Eriath wants old snares taken out of a carriers' passage at the "
                 "{name:front_skyglass_canopy/carrier_clearing}; ordinary use of the land, no plot yet.",
         "duration": 11, "notes": "Draft ER1: a use at the new recipe place P7 (Skyglass clearings); Eriath's work "
                                  "from 51."},
        {"id": "lethariel_cocoa", "giver": "eriath", "min_level": 52, "level": 53, "weight": 4.5,
         "reward": "armor:legs:prefix", "objectives": [item("grug_gathering:wild_cocoa", 6)],
         "title": "Something Warm to Share",
         "text": "Eriath wants something warm for the people at the far work sites: bring 6 Wild Cocoa.",
         "duration": 9, "notes": "Draft ER2."},
        {"id": "lethariel_received", "giver": "eriath", "min_level": 54, "level": 55, "weight": 5,
         "reward": "armor:feet:suffix",
         "objectives": [use(P8, "dispatch_record", "Confirm the delivery")],
         "title": "Received in Good Order",
         "text": "Eriath wants an ordinary supply delivery confirmed at the "
                 "{name:front_skyglass_canopy/receiving_stand}; it hides no proof against Chirr.",
         "duration": 11, "notes": "Draft ER3: a use at the new recipe place P8 (Skyglass rootways)."},
        {"id": "lethariel_watch_names", "giver": "eriath", "min_level": 58, "level": 59, "weight": 5,
         "reward": "weapon:sword",
         "objectives": [use("r20_anchor_085", "witness_record", "Record the watch's names")],
         "title": "The Watch Still Has Names",
         "text": "Eriath wants the names and personal records of a lost watch secured at {name:r20_anchor_085}; "
                 "remembrance and salvage, no ritual.",
         "duration": 12, "notes": "Draft ER4: a use at the free clash site 085; Lethariel's weapon (a solo "
                                  "quest)."},
        {"keep": "lethariel_front_05", "requires": [], "reward": "trinkets:b",
         "notes": "Draft ER5 (K11 A): the optional group quest on Glass-Throat, standalone from its level; its id "
                  "and objective stay, its prerequisite goes; a trinket choice."},
    ],
    "elandor_dur_brannoc": [
        {"id": "durbrannoc_returned_tools", "giver": "dorrin", "min_level": 45, "level": 46, "weight": 3,
         "reward": "armor:legs:prefix",
         "objectives": [use(DUR_BRANNOC_APRON, "dispatch_record", "Check the returned tools")],
         "title": "What Came Back",
         "text": "Dorrin wants the tools that came back from the front checked against their ordinary dispatch "
                 "record at the forge yard's loading apron.",
         "duration": 9, "notes": "Draft DO1 (K1 A): the town place of Dur Brannoc's forge yard (chapter 1's, "
                                 "another label); the Accord's third 41-50 giver (capitals are budget-exempt)."},
        {"id": "durbrannoc_labels", "giver": "dorrin", "min_level": 46, "level": 47, "weight": 3,
         "reward": "armor:head:suffix", "objectives": [item("default:paper", 10)],
         "title": "Labels for the Next Load",
         "text": "Dorrin wants new, readable labels for tools and deliveries: bring 10 Paper.",
         "duration": 8, "notes": "Draft DO2: Paper, a Basic recipe."},
        {"id": "durbrannoc_last_step", "giver": "dorrin", "min_level": 48, "level": 49, "weight": 3,
         "reward": "weapon:greataxe",
         "objectives": [use("r20_anchor_080", "sighting_frame", "Sight the last sound step")],
         "title": "The Last Sound Step",
         "text": "Dorrin wants it judged at {name:r20_anchor_080} where a repair of the aqueduct still finds "
                 "firm footing.",
         "duration": 12, "notes": "Draft DO3: a use at the free clash site 080; Dur Brannoc's weapon (a solo "
                                  "quest)."},
        {"keep": "durbrannoc_front_01"},
        {"keep": "durbrannoc_front_02"},
        {"keep": "accord_main_island_cairn", "requires": [],
         "notes": "Draft DO6: the optional island use, free from 60 without a story prerequisite."},
    ],
    "elandor_highcourt": [
        {"keep": "highcourt_front_01"},
        {"keep": "highcourt_front_02"},
        {"keep": "accord_main_island_wreck", "requires": [],
         "notes": "Draft MA3: the optional island use, free from 60 without a story prerequisite."},
    ],
    "kragmar_bannerbreak_mesa": [
        {"id": "bb_ramp_road_thorga", "giver": "drek", "turnin": "thorga", "min_level": 42, "level": 42,
         "weight": 1, "reward": None, "objectives": [talk("thorga")],
         "title": "Supplies from Gor Drazhak",
         "text": "Drek sends the player to Thorga Roadspeaker in Gor Drazhak: the front needs her help with food "
                 "and equipment; no earlier deed is claimed.",
         "duration": 10, "notes": "Draft DR1: the free departure to Thorga at 42 (her work at 42, 44 and 45)."},
    ],
    "kragmar_blackwind_rise": [
        {"id": "hollow_strap_names", "giver": "orrel", "min_level": 48, "level": 49, "weight": 3,
         "reward": "armor:chest:prefix",
         "objectives": [use("r20_anchor_083", "witness_record", "Record the names on the gear")],
         "title": "A Name on the Strap",
         "text": "Orrel wants the markings on left-behind watch gear at {name:r20_anchor_083} recorded, so the "
                 "things go to the right people.",
         "duration": 11, "notes": "Draft OR1: a use at the free clash site 083 (beside F6's snares, another "
                                  "object); Blackwind's first armor choice."},
        {"id": "hollow_not_salvage", "giver": "orrel", "min_level": 50, "level": 50, "weight": 4.5,
         "reward": "weapon:greataxe",
         "objectives": [use("r20_anchor_076", "claim_notice", "Post the notice of claim")],
         "title": "Before It Becomes Salvage",
         "text": "Orrel wants a notice posted at {name:r20_anchor_076} that the belongings of the remnant's dead "
                 "are claimed for their kin, so salvage crews leave them.",
         "duration": 11, "notes": "Draft OR2, the check's fix (it repeated blackwind_recovery_rest's secured "
                                  "bundle): a posted claim against salvage instead (claim_notice, an existing "
                                  "kind); a use at the free clash site 076; Blackwind's weapon (a solo quest, "
                                  "reward level 50: the band 41-50)."},
        {"id": "hollow_road_ashveil", "giver": "orrel", "turnin": "vaska", "min_level": 52, "level": 52,
         "weight": 1, "reward": None, "objectives": [talk("vaska")],
         "title": "Ashveil Keeps the Record",
         "text": "Orrel sends the player to Vaska Ashlistener at Ashveil Watch, who looks after the higher front "
                 "and the word that comes back from it.",
         "duration": 8, "notes": "Draft OR3: the free travel to Vaska at 52."},
        {"id": "ashveil_rock_salt", "giver": "vaska", "min_level": 52, "level": 53, "weight": 4.5,
         "reward": "armor:head:prefix", "objectives": [item("grug_gathering:rock_salt", 6)],
         "title": "Keep What Can Be Kept",
         "text": "Vaska needs salt to keep the supplies and the recovered things from spoiling; no magic: bring 6 "
                 "Rock Salt.",
         "duration": 9, "notes": "Draft VA1; Blackwind's first 51-60 armor choice."},
        {"id": "ashveil_road_ossa", "giver": "vaska", "turnin": "ossa", "min_level": 53, "level": 53,
         "weight": 1, "reward": None, "objectives": [talk("ossa")],
         "title": "A Place for Their Belongings",
         "text": "Vaska sends the player to Ossa Quietregister in Nhal Veyr, who receives the personal effects of "
                 "the dead; offered before Vaska's main-line part.",
         "duration": 10, "notes": "Draft VA2: the free departure to Ossa at 53."},
        {"id": "ashveil_next_party", "giver": "vaska", "min_level": 54, "level": 55, "weight": 5,
         "reward": "armor:feet:suffix",
         "objectives": [use(P5, "dispatch_record", "Leave word for the next party")],
         "title": "Word for the Next Party",
         "text": "Vaska wants word left at the {name:front_gravesalt_escarpment/work_laydown} for the next work "
                 "party: what was recovered and what still lies out there.",
         "duration": 11, "notes": "Draft VA3, the check's fix (a signal lantern repeated blackwind_signal_lantern): "
                                  "a dispatch record at the new recipe place P5 (beside Borin's braces, another "
                                  "object); Blackwind's second 51-60 armor choice."},
        {"id": "ashveil_vigil_torches", "giver": "vaska", "min_level": 55, "level": 56, "weight": 4.5,
         "reward": None, "objectives": [item("default:torch", 20)],
         "title": "Light for Those Who Wait",
         "text": "Vaska wants torches for the vigil of those who wait at Ashveil Watch for word of their dead: "
                 "bring 20 Torches.",
         "duration": 8, "notes": "Draft VA4, the check's fix (Mushrooms repeated Vaska's 'Something for Those "
                                 "Who Wait'): torches for the vigil instead of food."},
        {"keep": "bw_front_ashveil_05", "requires": [], "reward": "trinkets:a",
         "notes": "Draft VA5 (K11 A): the optional group quest on Salt-Counter, standalone from its level; its id "
                  "and objective stay, its prerequisite goes; a trinket choice."},
    ],
    "kragmar_kezamba": [
        {"id": "kezamba_melons", "giver": "nalo", "min_level": 50, "level": 51, "weight": 4.5,
         "reward": "armor:chest:prefix", "objectives": [item("grug_gathering:melon", 6)],
         "title": "Fruit for the Carriers",
         "text": "Nalo wants food for his carriers that starts no quarrel with another beast: bring 6 Melons.",
         "duration": 9, "notes": "Draft NA1: Nalo's first task at 50 (F10 sends Yarra's players)."},
        {"id": "kezamba_message_knots", "giver": "nalo", "min_level": 52, "level": 53, "weight": 4.5,
         "reward": "potions",
         "objectives": [use(P7, "reading_knots", "Read the carriers' knots")],
         "title": "A Message That Arrives",
         "text": "Nalo wants the prepared way-messages of his carriers read at the "
                 "{name:front_skyglass_canopy/carrier_clearing}; no riddle, no new rules.",
         "duration": 10, "notes": "Draft NA2: a use at the new recipe place P7; the early 51-60 potion choice."},
        {"id": "kezamba_root_load", "giver": "nalo", "min_level": 55, "level": 56, "weight": 5,
         "reward": "weapon:greataxe",
         "objectives": [use(P8, "sighting_frame", "Sight the root crossing under load")],
         "title": "Roots Under the Load",
         "text": "Nalo wants it judged at the {name:front_skyglass_canopy/receiving_stand} whether a root "
                 "crossing still carries a load; no bridge, no change to the roots.",
         "duration": 11, "notes": "Draft NA3: a use at the new recipe place P8; Kezamba's weapon (a solo quest)."},
        {"keep": "kz_front_05", "requires": [], "reward": "trinkets:b",
         "notes": "Draft NA4 (K11 A): the optional group quest on Glass-Throat, standalone from its level; its id "
                  "and objective stay, its prerequisite goes; a trinket choice."},
    ],
    "kragmar_gor_drazhak": [
        {"id": "gordrazhak_ember_eel", "giver": "thorga", "min_level": 42, "level": 43, "weight": 3,
         "reward": "armor:head:prefix", "objectives": [item("grug_fishing:ember_eel", 5)],
         "title": "Food for the Next Load",
         "text": "Thorga wants provisions for the next load to the front: bring 5 Ember Eel.",
         "duration": 9, "notes": "Draft TH1; the Throng's capital share of the 41-50 pattern."},
        {"id": "gordrazhak_water_depot", "giver": "thorga", "min_level": 44, "level": 45, "weight": 3,
         "reward": "armor:chest:suffix",
         "objectives": [use(GOR_DRAZHAK_DEPOT, "held_supplies", "Release the front load")],
         "title": "Ready at the Water Depot",
         "text": "Thorga wants a prepared load for the front checked and released at the cook court's water "
                 "depot.",
         "duration": 9, "notes": "Draft TH2: the town place of Gor Drazhak's cook court (chapter 1's, another "
                                 "object and label)."},
        {"id": "gordrazhak_fangs", "giver": "thorga", "min_level": 45, "level": 46, "weight": 3,
         "reward": "weapon:sword",
         "objectives": [item("grug_mobs:siegepack_fang", 3, ["warpack_hyena"], "front_shattered_line/trenches")],
         "title": "A Fang Through the Strap",
         "text": "Thorga wants Siegepack Fangs as proof of what straps and gear must stand up to; the Siegepack "
                 "Hyenas of the {name:front_shattered_line/trenches} carry them: bring 3.",
         "duration": 11, "notes": "Draft TH3 (K7 A): the item only, no kill count (a mob drop: still a fight); "
                                  "Gor Drazhak's weapon (a solo quest). The Sinkmire Viper hunt, a camp hunt's "
                                  "role, is gone."},
        {"id": "gordrazhak_krait_bounty", "giver": "thorga", "min_level": 60, "level": 60, "weight": 0, "copper": 600,
         "reward": None, "optional": True,
         "objectives": [kill(["glass_fang_serpent"], 6, "front_stormscale_summit/scorchlands")],
         "title": "Optional: Krait Season",
         "text": "Thorga posts a bounty on the Kraits of the {name:front_stormscale_summit/scorchlands} on "
                 "Stormscale Summit, by day; coin, no leveling.",
         "duration": 15, "notes": "Draft TH4 (K9 A): the Throng's island bounty, another mob than the Accord's "
                                  "(the check: glass_fang_serpent reads 'Krait' on Stormscale); weight 0, copper "
                                  "like the Accord's."},
        {"id": "gordrazhak_last_offering", "giver": "thorga", "min_level": 60, "level": 60, "weight": 0,
         "copper": 800, "reward": None, "group": True, "optional": True, "requires": ["gordrazhak_krait_bounty"],
         "objectives": [kill(["last_offering_ape"], 1)],
         "title": "Party: The Last Offering",
         "text": "Thorga asks for a party against {name:last_offering_ape} on Stormscale Summit; optional, "
                 "nothing needs it.",
         "duration": 15, "notes": "Draft TH5 (K9 A): the bounty's one follow-up, the island elite (a recorded "
                                  "exception: the island elites stay per faction, plan §2 point 4)."},
        {"keep": "throng_main_island_wreck", "requires": [],
         "notes": "Draft TH6: the optional island use, free from 60 without a story prerequisite."},
    ],
    "kragmar_nhal_veyr": [
        {"id": "nhalveyr_receiving", "giver": "ossa", "min_level": 53, "level": 54, "weight": 4.5,
         "reward": "armor:legs:prefix",
         "objectives": [use(NHAL_VEYR_COURT, "held_supplies", "Sort the returned belongings")],
         "title": "A Receiving Place",
         "text": "Ossa wants the personal effects prepared for their return sorted at the mourners' hall's "
                 "receiving court.",
         "duration": 9, "notes": "Draft OS1: the town place of Nhal Veyr's mourners' hall (chapter 1's, another "
                                 "object)."},
        {"keep": "nv_front_01", "min_level": 54, "level": 55, "reward": "weapon:sword",
         "notes": "Draft OS2 (K8 A): Glass Silk from the Gossamer Widows (night, the Skyglass rootways); its id and "
                  "objective stay, it opens at 54; Nhal Veyr's weapon (a solo quest)."},
        {"id": "nhalveyr_not_salvage", "giver": "ossa", "min_level": 56, "level": 57, "weight": 5,
         "reward": "armor:legs:suffix",
         "objectives": [use(P6, "witness_record", "Record the names on the effects")],
         "title": "Not Entered as Salvage",
         "text": "Ossa wants the names on personal effects recorded at the "
                 "{name:front_gravesalt_escarpment/recovery_post} before they vanish into ordinary salvage.",
         "duration": 11, "notes": "Draft OS3: a use at the new recipe place P6 (Gravesalt's tombwood, away from "
                                  "Huskell)."},
        {"keep": "throng_main_island_cairn", "requires": [],
         "notes": "Draft OS4: the optional island use, free from 60 without a story prerequisite."},
    ],
}

# Every `.front` file's quests in play order: a spine id, a fortress id
# (kept as shipped), or a LOCAL row of that file (by its id or "keep").
FRONT_FILES = {
    "elandor_ashenward_march": [
        "cinderline_front_05", "cinderline_front_04", "lasthedge_front_04",
        "ashenward_bastion_call", "ashenward_bastion_steel", "ashenward_bastion_trophies",
        "ashenward_bastion_scouting", "ashenward_bastion_picket_broken", "ashenward_bastion_picket_shattered",
        "ashenward_bastion_warcamp_broken", "ashenward_bastion_warcamp_shattered",
        "ashenward_bastion_picket_skyglass", "ashenward_bastion_picket_gravesalt",
        "ashenward_bastion_warcamp_skyglass", "ashenward_bastion_warcamp_gravesalt"],
    "elandor_stormvault_heights": [
        "archshadow_crossing", "archshadow_road_dorrin", "archshadow_front_02", "archshadow_front_03",
        "accord_main_accounts", "archshadow_tools_held",
        "splitbolt_shoring_check", "splitbolt_road_eriath", "splitbolt_storm_tuna", "splitbolt_braces",
        "splitbolt_front_08", "splitbolt_front_06", "splitbolt_front_09"],
    "elandor_lethariel": [
        "lethariel_carrier_path", "lethariel_cocoa", "lethariel_received", "lethariel_watch_names",
        "lethariel_front_04", "accord_main_tally", "lethariel_front_05"],
    "elandor_dur_brannoc": [
        "durbrannoc_returned_tools", "durbrannoc_labels", "durbrannoc_last_step",
        "durbrannoc_front_01", "durbrannoc_front_02", "accord_main_island_cairn"],
    "elandor_highcourt": ["highcourt_front_01", "highcourt_front_02", "accord_main_island_wreck"],
    "kragmar_bannerbreak_mesa": [
        "bb_ramp_road_thorga", "bb_front_ramp_04", "bb_front_ramp_05", "bb_front_torn_05",
        "bannerbreak_warhold_call", "bannerbreak_warhold_steel", "bannerbreak_warhold_trophies",
        "bannerbreak_warhold_scouting", "bannerbreak_warhold_picket_shattered", "bannerbreak_warhold_picket_broken",
        "bannerbreak_warhold_warcamp_shattered", "bannerbreak_warhold_warcamp_broken",
        "bannerbreak_warhold_picket_gravesalt", "bannerbreak_warhold_picket_skyglass",
        "bannerbreak_warhold_warcamp_gravesalt", "bannerbreak_warhold_warcamp_skyglass"],
    "kragmar_blackwind_rise": [
        "throng_main_02", "hollow_strap_names", "hollow_not_salvage", "hollow_road_ashveil", "ashveil_rock_salt",
        "ashveil_road_ossa", "ashveil_next_party", "ashveil_vigil_torches", "bw_front_ashveil_04",
        "bw_front_ashveil_05", "throng_main_07", "throng_main_final"],
    "kragmar_kezamba": ["kezamba_melons", "kezamba_message_knots", "kezamba_root_load", "kz_front_04", "kz_front_05"],
    "kragmar_gor_drazhak": [
        "gordrazhak_ember_eel", "gordrazhak_water_depot", "gordrazhak_fangs", "gordrazhak_krait_bounty",
        "gordrazhak_last_offering", "throng_main_island_wreck"],
    "kragmar_nhal_veyr": ["nhalveyr_receiving", "nv_front_01", "nhalveyr_not_salvage", "throng_main_island_cairn"],
}
# The four contested host base files: their main-line steps (completions,
# rewards) and the shared front quests homed there.
BASE_FILES = ("elandor_ashenward_march", "elandor_stormvault_heights", "kragmar_bannerbreak_mesa",
              "kragmar_blackwind_rise")
# The four Battlegrounds files: flagged, their Round 58 content as shipped.
BATTLEGROUNDS = ("front_broken_causeway", "front_shattered_line", "front_gravesalt_escarpment",
                 "front_skyglass_canopy")


# ---------------------------------------------------------------- building
def lesson_of(row):
    if row["objectives"][0]["type"] == "talk":
        return "A travel quest, free (a level only): a departure to a giver with work at once."
    if row.get("group"):
        return "An optional group quest: free, standalone, a trinket choice as its extra."
    if (row.get("rewards") or {}).get("weight") == 0:
        return "An island bounty: coin, no leveling."
    return "A free front task of the giver's own people (a level only)."


def insert_after(quest, after, key, value):
    """`quest` with `key` = `value` placed after the key `after` (or at the
    end), the other keys in their order."""
    out = {}
    placed = False
    for k, v in quest.items():
        if k == key:
            continue
        out[k] = v
        if k == after and not placed:
            out[key] = value
            placed = True
    if not placed:
        out[key] = value
    return out


def spine_quest(quest):
    """A spine step as shipped: story, its spine requires, a placeholder
    completion and its reward (the weight stays)."""
    requires, completion, kind = SPINE[quest["id"]]
    quest = copy.deepcopy(quest)
    quest["requires"] = list(requires)
    quest = insert_after(quest, "requires", "story", True)
    quest = insert_after(quest, "text", "completion", PH + completion + TBD)
    if kind:
        quest["rewards"] = rewards(quest["rewards"]["weight"], kind, quest["level"])
    else:
        quest["rewards"] = {"weight": quest["rewards"]["weight"]}
    return quest


def branch_quest(quest):
    quest = copy.deepcopy(quest)
    quest["rewards"] = rewards(quest["rewards"]["weight"], BRANCHES[quest["id"]], quest["level"])
    return quest


def kept_quest(quest, spec):
    """A kept free quest: its objectives, titles and texts as shipped; the
    row's requires, levels and reward."""
    quest = copy.deepcopy(quest)
    for key in ("min_level", "level"):
        if key in spec:
            quest[key] = spec[key]
    if "requires" in spec:
        quest["requires"] = list(spec["requires"])
    if spec.get("reward"):
        weight = quest["rewards"]["weight"]
        copper = quest["rewards"].get("copper")
        quest["rewards"] = rewards(weight, spec["reward"], quest["level"], copper)
    if spec.get("notes"):
        quest["notes"] = NOTE + spec["notes"]
    return quest


def local_quest(row):
    out = {"id": row["id"], "line": "front", "giver": NPC[row["giver"]],
           "turnin": NPC[row.get("turnin", row["giver"])], "min_level": row["min_level"], "level": row["level"],
           "requires": list(row.get("requires", [])), "title": PH + row["title"], "text": PH + row["text"] + TBD}
    if row.get("completion"):
        out["completion"] = PH + row["completion"] + TBD
    out["objectives"] = copy.deepcopy(row["objectives"])
    out["rewards"] = rewards(row["weight"], row.get("reward"), row["level"], row.get("copper"))
    out["lesson"] = lesson_of(out)
    out["duration_min"] = row["duration"]
    if row.get("group"):
        out["group"] = True
    if row.get("group") or row.get("optional"):
        out["optional"] = True
    out["notes"] = NOTE + row["notes"]
    return out


def shared_quest(spec):
    variants = []
    for index, (giver, fields) in enumerate(spec["givers"]):
        row = {"zone": ZONE_OF[giver], "givers": [NPC[giver]]}
        if fields.get("turnin"):
            row["turnins"] = [NPC[fields["turnin"]]]
        if index > 0 and fields.get("turnin") and spec["objectives"][0].get("npc") != NPC[fields["turnin"]]:
            row["objectives"] = [{"npc": NPC[fields["turnin"]]}]
        row["text"] = PH + fields["text"] + TBD
        variants.append(row)
    quest = {"id": spec["id"], "line": "border", "min_level": spec["min_level"], "level": spec["level"],
             "requires": [], "title": PH + spec["title"], "text": PH + spec["givers"][0][1]["text"] + TBD,
             "objectives": copy.deepcopy(spec["objectives"]), "variants": variants,
             "rewards": rewards(spec["weight"], spec.get("reward"), spec["level"])}
    quest["lesson"] = lesson_of(dict(quest, group=spec.get("group")))
    quest["duration_min"] = spec["duration"]
    if spec.get("group"):
        quest["group"] = True
        quest["optional"] = True
    quest["notes"] = NOTE + spec["notes"]
    return quest


def read(name):
    return json.loads((QUESTS / name).read_text(encoding="utf-8"))


def dump(data):
    # Round 65 ruling 3: a quest names only its level (accepted from level -
    # 2); the minimum levels written above are history.
    for quest in data.get("quests") or []:
        quest.pop("min_level", None)
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def build():
    """{path: text} of every file the script writes."""
    files = {}
    shipped = {}
    for zone in FRONT_FILES:
        for q in read("%s.front.quests.json" % zone)["quests"]:
            shipped[q["id"]] = q
    base = {zone: read("%s.quests.json" % zone) for zone in BASE_FILES}
    for zone, data in base.items():
        for q in data["quests"]:
            shipped[q["id"]] = q
    local = {}
    for zone, rows in LOCAL.items():
        for row in rows:
            local[row.get("id") or row["keep"]] = row
    for zone, order in FRONT_FILES.items():
        quests = []
        for qid in order:
            row = local.get(qid)
            if qid in SPINE:
                quests.append(spine_quest(shipped[qid]))
            elif row and row.get("keep"):
                quests.append(kept_quest(shipped[qid], row))
            elif row:
                quests.append(local_quest(row))
            else:
                quests.append(copy.deepcopy(shipped[qid]))  # a fortress quest as shipped
        out = {"zone": zone, "reworked": True, "quests": quests}
        files[QUESTS / ("%s.front.quests.json" % zone)] = dump(out)
    shared = {}
    for spec in SHARED:
        shared.setdefault(ZONE_OF[spec["givers"][0][0]], []).append(shared_quest(spec))
    for zone, data in base.items():
        data = copy.deepcopy(data)
        quests = []
        for q in data["quests"]:
            if q["id"] in FRONT_SHARED:
                continue
            if q["id"] in SPINE:
                q = spine_quest(q)
            elif q["id"] in BRANCHES:
                q = branch_quest(q)
            quests.append(q)
        data["quests"] = quests + shared.get(zone, [])
        files[QUESTS / ("%s.quests.json" % zone)] = dump(data)
    for zone in BATTLEGROUNDS:
        data = read("%s.quests.json" % zone)
        out = {"zone": data["zone"], "reworked": True}
        out.update({k: v for k, v in data.items() if k not in ("zone", "reworked")})
        files[QUESTS / ("%s.quests.json" % zone)] = dump(out)
    return files


# The text fields (lane FRONTTEXT's): --check compares the rest, the structure.
TEXT_FIELDS = ("title", "text", "texts", "completion")
VARIANT_TEXT_FIELDS = ("text", "completion")


def structure(text):
    data = json.loads(text)
    for quest in data.get("quests") or []:
        for key in TEXT_FIELDS:
            quest.pop(key, None)
        for variant in quest.get("variants") or []:
            for key in VARIANT_TEXT_FIELDS:
                variant.pop(key, None)
    return data


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
