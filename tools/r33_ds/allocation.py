#!/usr/bin/env python3
"""Round 33 lane DS: which signature loot feeds which recipe.

The data lane C4 copies: per tier, the enchant loot by channel (prefix and
suffix of a stat take different items), the six profession upgrades and the
Alchemy reagents. The checks keep the rules of docs/design/item_tiers.md
section 2: every input exists for both factions, a scarce input appears only
in a low-volume recipe and at most once per recipe, every input is of the
recipe's tier, and every usable signature has a use.

Usage:
  allocation.py            print the tables (Markdown)
  allocation.py --json     print the proposed enchants.json (prefix_loot /
                           suffix_loot / family_input per tier) and the
                           upgrade recipes; stored as enchants_r33.json and
                           upgrades_r33.json beside this script
  allocation.py --check    exit 1 on a rule violation
"""
import argparse
import json
import sys
from collections import Counter, defaultdict

import availability as A
import common as C

M = "grug_mobs:"
STATS = ("str", "dex", "int", "max_hp_percent", "max_mana_percent", "crit_percent",
         "attack_speed_percent", "dodge_percent", "armor_rating")
SHORT = {"str": "Str", "dex": "Dex", "int": "Int", "max_hp_percent": "HP",
         "max_mana_percent": "Mana", "crit_percent": "Crit", "attack_speed_percent": "Speed",
         "dodge_percent": "Dodge", "armor_rating": "Armor"}

# Enchant loot: tier -> stat -> (prefix item, suffix item). Prefixes keep
# today's inputs where they exist; suffixes follow the suffix animal where a
# signature fits it (Bear: teeth and claws, Fox: tails and hair, Owl: eyes,
# talismans and feathers, Ox: sinew, Raven: feathers and talismans, Eagle:
# claws, Hornet: venom and fangs, Cat: cat claws, Tortoise: shells and bone).
ENCHANT = {
    1: {"str": ("boar_tusk", "crab_leg"), "dex": ("rat_tail", "fine_sinew"),
        "int": ("crab_eye", "crab_eye"), "max_hp_percent": ("tattered_flesh", "fine_sinew"),
        "max_mana_percent": ("crab_eye", "bandit_talisman"),
        "crit_percent": ("bandit_talisman", "boar_tusk"),
        "attack_speed_percent": ("rat_tail", "rat_tail"),
        "dodge_percent": ("rat_fur_patch", "rat_tail"),
        "armor_rating": ("rat_fur_patch", "crab_leg")},
    2: {"str": ("ridged_boar_tusk", "fang"), "dex": ("sinewy_rat_tail", "tough_sinew"),
        "int": ("clear_crab_eye", "knotted_talisman"),
        "max_hp_percent": ("foul_flesh", "tough_sinew"),
        "max_mana_percent": ("clear_crab_eye", "knotted_talisman"),
        "crit_percent": ("ridged_boar_tusk", "fang"),
        "attack_speed_percent": ("sinewy_rat_tail", "sinewy_rat_tail"),
        "dodge_percent": ("dense_rat_fur", "sinewy_rat_tail"),
        "armor_rating": ("dense_rat_fur", "ridged_crab_shell")},
    3: {"str": ("stubborn_molar", "gnarled_boar_tusk"),
        "dex": ("balanced_weapon_strap", "braided_sinew"),
        "int": ("coded_talisman", "bound_wisp_mote"),
        "max_hp_percent": ("pickled_flesh", "braided_sinew"),
        "max_mana_percent": ("bound_wisp_mote", "clouded_reed_pearl"),
        "crit_percent": ("serrated_fang", "shearing_cat_claw"),
        "attack_speed_percent": ("balanced_weapon_strap", "barbed_feather"),
        "dodge_percent": ("coarse_spider_silk", "shearing_cat_claw"),
        "armor_rating": ("layered_crab_shell", "layered_crab_shell")},
    4: {"str": ("gritted_teeth", "warpack_fang"), "dex": ("reinforced_weapon_strap", "ape_hair"),
        "int": ("campaign_talisman", "storm_feather"),
        "max_hp_percent": ("leathery_flesh", "ironbound_sinew"),
        "max_mana_percent": ("campaign_talisman", "storm_feather"),
        "crit_percent": ("gritted_teeth", "razor_cat_claw"),
        "attack_speed_percent": ("reinforced_weapon_strap", "warpack_fang"),
        "dodge_percent": ("layered_spider_web", "razor_cat_claw"),
        "armor_rating": ("marching_bone", "storm_crab_shell")},
    5: {"str": ("clenched_jaw", "siegepack_fang"), "dex": ("siege_weapon_strap", "siege_weapon_strap"),
        "int": ("siege_talisman", "ash_feather"),
        "max_hp_percent": ("scorched_flesh", "scorched_flesh"),
        "max_mana_percent": ("siege_talisman", "siege_talisman"),
        "crit_percent": ("clenched_jaw", "siegepack_fang"),
        "attack_speed_percent": ("siege_weapon_strap", "scorch_venom"),
        "dodge_percent": ("siege_weapon_strap", "ash_feather"),
        "armor_rating": ("siege_bone", "clenched_jaw")},
    6: {"str": ("last_laugh_dentures", "unquiet_bone"),
        "dex": ("unbroken_weapon_strap", "silver_ape_hair"),
        "int": ("last_pay_talisman", "last_hex_shard"),
        "max_hp_percent": ("salt_cured_flesh", "salt_cured_flesh"),
        "max_mana_percent": ("last_pay_talisman", "salt_barbed_feather"),
        "crit_percent": ("last_laugh_dentures", "glass_cat_claw"),
        "attack_speed_percent": ("unbroken_weapon_strap", "glass_venom"),
        "dodge_percent": ("glass_spider_silk", "glass_cat_claw"),
        "armor_rating": ("unbroken_weapon_strap", "unquiet_bone")},
}

# Profession upgrades: tier -> profession -> (signature A, signature B).
# Each also takes two of the profession's own material of the tier.
PROFESSIONS = ("weaponsmith", "armorsmith", "woodcarver", "leatherworker", "tailor", "goldsmith")
# Who enchants and upgrades which family (user ruling 2026-10-04: two
# professions dress every class in armour, weapon and offhand). Bows move from
# the Woodcarver to the Leatherworker, spellbooks from the Goldsmith to the
# Tailor.
OWNER = {"sword": "weaponsmith", "dagger": "weaponsmith", "greataxe": "weaponsmith",
         "metal_armor": "armorsmith", "shield": "armorsmith",
         "caster_weapon": "woodcarver",
         "leather_armor": "leatherworker", "bow": "leatherworker",
         "cloth_armor": "tailor", "spellbook": "tailor",
         "trinket": "goldsmith"}
FAMILY_LABEL = {"sword": "sword", "dagger": "dagger", "greataxe": "battle axe",
                "metal_armor": "metal armour", "shield": "shield",
                "caster_weapon": "staff, wand", "leather_armor": "leather armour",
                "bow": "bow", "cloth_armor": "cloth armour", "spellbook": "spellbook",
                "trinket": "trinket"}
FAMILIES = {prof: ", ".join(FAMILY_LABEL[f] for f in OWNER if OWNER[f] == prof)
            for prof in set(OWNER.values())}
# Profession products that count as progression crafts, besides enchants and
# upgrades (grug_professions/tailor.lua, leatherworker.lua,
# grug_artisans/goldsmith.lua; the spellbook moves to the Tailor).
PRODUCTS = {
    "weaponsmith": {}, "armorsmith": {}, "woodcarver": {},
    "leatherworker": {1: "8-slot bag", 2: "16-slot bag", 4: "24-slot bag", 5: "32-slot bag"},
    "tailor": dict((t, "spellbook" + {1: ", 8-slot bag", 2: ", 16-slot bag", 4: ", 24-slot bag",
                                         5: ", 32-slot bag"}.get(t, "")) for t in range(1, 7)),
    "goldsmith": dict((t, "six trinkets") for t in range(1, 7)),
}
OWN_MATERIAL = {
    "weaponsmith": ("Bronze Bar", "Iron Bar", "Steel Bar", "Silversteel Bar", "Embersteel Bar", "Abyssal Steel Bar"),
    "armorsmith": ("Bronze Bar", "Iron Bar", "Steel Bar", "Silversteel Bar", "Embersteel Bar", "Abyssal Steel Bar"),
    "woodcarver": ("Seasoned Wood", "Polished Wood", "Hardened Wood", "Inlaid Wood", "Lacquered Wood", "Heartwood Wood"),
    "leatherworker": ("Light Leather", "Cured Leather", "Heavy Leather", "Scaled Hide", "Sleek Leather", "Nightscale Leather"),
    "tailor": ("Patch Bolt", "Woven Bolt", "Heavy Bolt", "Silkweave Bolt", "Silk Bolt", "Stormweave Bolt"),
    "goldsmith": ("Tin Setting", "Iron Setting", "Copper-inlaid Steel Setting", "Gold Setting",
                  "Gold-filigreed Embersteel Setting", "Gold-filigreed Abyssal Steel Setting"),
}
LOW_VOLUME = {"weaponsmith", "woodcarver", "goldsmith"}  # one or two items per tier
UPGRADE = {
    1: {"weaponsmith": ("boar_tusk", "rat_tail"), "armorsmith": ("crab_leg", "rat_fur_patch"),
        "woodcarver": ("fine_sinew", "boar_tusk"), "leatherworker": ("rat_fur_patch", "tattered_flesh"),
        "tailor": ("rat_tail", "tattered_flesh"), "goldsmith": ("crab_eye", "bandit_talisman")},
    2: {"weaponsmith": ("ridged_boar_tusk", "fang"), "armorsmith": ("ridged_crab_shell", "dense_rat_fur"),
        "woodcarver": ("tough_sinew", "ridged_boar_tusk"), "leatherworker": ("dense_rat_fur", "foul_flesh"),
        "tailor": ("knotted_talisman", "sinewy_rat_tail"), "goldsmith": ("clear_crab_eye", "knotted_talisman")},
    3: {"weaponsmith": ("serrated_fang", "gnarled_boar_tusk"),
        "armorsmith": ("layered_crab_shell", "braided_sinew"),
        "woodcarver": ("braided_sinew", "bound_wisp_mote"),
        "leatherworker": ("coarse_spider_silk", "braided_sinew"),
        "tailor": ("coarse_spider_silk", "clouded_reed_pearl"),
        "goldsmith": ("clasped_purse", "clouded_reed_pearl")},
    4: {"weaponsmith": ("scarred_bear_claw", "marching_bone"),
        "armorsmith": ("storm_crab_shell", "ironbound_sinew"),
        "woodcarver": ("bitter_resin", "storm_feather"),
        "leatherworker": ("ape_hair", "leathery_flesh"),
        "tailor": ("layered_spider_web", "campaign_talisman"),
        "goldsmith": ("campaign_purse", "campaign_talisman")},
    5: {"weaponsmith": ("siege_cat_claw", "scorch_venom"), "armorsmith": ("siege_bone", "siege_weapon_strap"),
        "woodcarver": ("ash_feather", "siegepack_fang"), "leatherworker": ("siege_weapon_strap", "scorched_flesh"),
        "tailor": ("siege_talisman", "scorch_venom"), "goldsmith": ("clenched_jaw", "siege_talisman")},
    6: {"weaponsmith": ("salt_bear_claw", "unquiet_bone"),
        "armorsmith": ("unquiet_bone", "unbroken_weapon_strap"),
        "woodcarver": ("salt_barbed_feather", "rime_sinew"),
        "leatherworker": ("silver_ape_hair", "salt_cured_flesh"),
        "tailor": ("glass_spider_silk", "glass_venom"),
        "goldsmith": ("last_hex_shard", "last_pay_talisman")},
}

# Signatures that keep no recipe use, with the reason (item_tiers.md 2.4).
SELL_ONLY = {
    "raptor_claw": "one faction (Throng start zone only)",
    "fox_tail": "one faction (Accord only)",
    "mild_venom": "one faction (Throng only)",
    "blunt_croc_tooth": "one faction (Throng only)",
    "hooked_cat_claw": "one faction (Throng only)",
    "brush_fox_tail": "one faction (Accord only)",
    "stolen_purse": "one faction (Accord only); a trash-class purse",
    "reed_pearl": "one faction (Throng only)",
    "thin_slime_gel": "one faction (Throng only)",
    "bitter_venom": "one faction (Throng only)",
    "wisp_mote": "one faction (Throng only)",
    "ridged_croc_tooth": "one faction (Throng only)",
    "silver_tip_fox_tail": "one faction (Accord only)",
    "etched_bone": "one faction (Throng only)",
    "mourning_resin": "one faction (Throng only)",
    "concentrated_venom": "one faction (Throng only)",
    "bone_chitin": "one faction (Throng only)",
    "layered_bone_chitin": "one faction (Throng only)",
    "restless_wisp_mote": "one faction (Accord only)",
    "hex_bottle_shard": "one faction (Throng only)",
    "chipped_core": "no placed source (stone golems are not in a spawn recipe)",
    "veined_core": "no regular source (one unique elite)",
    "siege_core": "no regular source (two unique elites)",
    "abyssal_crab_shell": "no placed source (the reef lurker is not in a spawn recipe)",
    "saltpack_fang": "scarce (one zone, few hounds); a hunter's trophy",
    "salt_chitin": "scarce (one zone, rare weevil); a hunter's trophy",
}

# Alchemy: tier -> product -> (first, second); every row also takes a Glass
# Bottle. Herbs and cooking goods carry their mod prefix, mob loot does not.
G, K = "grug_gathering:", "grug_cooking:"
ALCHEMY = {
    1: {"Healing Potion I": (G + "gravemoss", G + "sunleaf"),
        "Mana Potion I": (G + "gravemoss", "group:grug_cooking_root"),
        "Elixir of Vigor I": (G + "sunleaf", "tattered_flesh"),
        "Elixir of Focus I": (G + "gravemoss", "crab_eye"),
        "Elixir of Precision I": (G + "sunleaf", "boar_tusk"),
        "Stoneskin Elixir I": (G + "gravemoss", "crab_leg")},
    2: {"Healing Potion II": (G + "dragonweed", G + "sunleaf"),
        "Mana Potion II": (G + "dragonweed", K + "sugar_cane"),
        "Elixir of Vigor II": (G + "dragonweed", "tough_sinew"),
        "Elixir of Focus II": (G + "dragonweed", "clear_crab_eye"),
        "Elixir of Precision II": (G + "dragonweed", "fang"),
        "Stoneskin Elixir II": (G + "dragonweed", "ridged_crab_shell"),
        "Antivenom": (G + "dragonweed", "venom_gland"),
        "Swiftness Draught": (G + "dragonweed", "fang")},
    3: {"Healing Potion III": (G + "crimson_lotus", G + "gravemoss"),
        "Mana Potion III": (G + "crimson_lotus", K + "sugar_cane"),
        "Elixir of Vigor III": (G + "crimson_lotus", "bear_claw"),
        "Elixir of Focus III": (G + "crimson_lotus", K + "cave_cap"),
        "Elixir of Precision III": (G + "crimson_lotus", "serrated_fang"),
        "Stoneskin Elixir III": (G + "crimson_lotus", "layered_crab_shell"),
        "Cave Draught": (K + "cave_cap", "bound_wisp_mote")},
    4: {"Healing Potion IV": (G + "crimson_lotus", "leathery_flesh"),
        "Mana Potion IV": (G + "crimson_lotus", "venom_sac"),
        "Elixir of Vigor IV": (G + "crimson_lotus", "ironbound_sinew"),
        "Elixir of Focus IV": (G + "crimson_lotus", "campaign_talisman"),
        "Elixir of Precision IV": (G + "crimson_lotus", "razor_cat_claw"),
        "Stoneskin Elixir IV": (G + "crimson_lotus", "shiny_scale")},
    5: {"Healing Potion V": (K + "ember_moss", G + "crimson_lotus"),
        "Mana Potion V": (G + "stormkelp", G + "crimson_lotus"),
        "Elixir of Vigor V": (K + "ember_moss", "scorched_flesh"),
        "Elixir of Focus V": (K + "ember_moss", K + "cave_cap"),
        "Elixir of Precision V": (K + "ember_moss", "siegepack_fang"),
        "Stoneskin Elixir V": (G + "stormkelp", "siege_bone"),
        "Deepwater Elixir": (G + "stormkelp", K + "cave_cap")},
    6: {"Healing Potion VI": (G + "wild_cocoa", K + "ember_moss"),
        "Mana Potion VI": (G + "wild_cocoa", G + "stormkelp"),
        "Elixir of Vigor VI": (G + "wild_cocoa", "salt_cured_flesh"),
        "Elixir of Focus VI": (G + "wild_cocoa", "last_hex_shard"),
        "Elixir of Precision VI": (K + "ember_moss", "sharp_feather"),
        "Stoneskin Elixir VI": (G + "wild_cocoa", "unquiet_bone")},
}
# Ingredient tiers outside grug_mobs (grug_cooking/init.lua:180-187,
# grug_alchemy/recipes.lua:7-24).
OTHER_TIERS = {G + "gravemoss": 1, G + "sunleaf": 1, "group:grug_cooking_root": 1,
               G + "dragonweed": 2, K + "sugar_cane": 2, G + "crimson_lotus": 3,
               K + "cave_cap": 3, K + "ember_moss": 5, G + "stormkelp": 5, G + "wild_cocoa": 6}

# Rough demand weight per use, for the load column (how often players need it).
DEMAND = {"str": 3, "dex": 2.5, "int": 3, "max_hp_percent": 3, "max_mana_percent": 2,
          "crit_percent": 2, "attack_speed_percent": 1, "dodge_percent": 1.5, "armor_rating": 1.5}


def uses():
    """item -> list of (tier, label, demand)"""
    out = defaultdict(list)
    for tier, stats in ENCHANT.items():
        for stat, (pre, suf) in stats.items():
            out[M + pre].append((tier, "enchant %s prefix" % SHORT[stat], DEMAND[stat] / 2.0))
            out[M + suf].append((tier, "enchant %s suffix" % SHORT[stat], DEMAND[stat] / 2.0))
    for tier, rows in UPGRADE.items():
        for prof, pair in rows.items():
            for item in pair:
                out[M + item].append((tier, "upgrade %s" % prof, 1.5 if prof in LOW_VOLUME else 2.5))
    for tier, rows in ALCHEMY.items():
        for product, pair in rows.items():
            for item in pair:
                if ":" not in item:
                    out[M + item].append((tier, product, 1.0))
    return out


def progression_table():
    out = ["| Profession | Families | " + " | ".join("T%d" % t for t in range(1, 7)) + " |",
           "|---|---|" + "---|" * 6]
    for prof in PROFESSIONS:
        cells = []
        for tier in range(1, 7):
            parts = ["enchants", "upgrade"]
            if PRODUCTS[prof].get(tier):
                parts.append(PRODUCTS[prof][tier])
            cells.append(", ".join(parts))
        out.append("| %s | %s | %s |" % (prof.capitalize(), FAMILIES[prof], " | ".join(cells)))
    return out


def check():
    problems = []
    for prof in PROFESSIONS:
        if not any(OWNER[f] == prof for f in OWNER):
            problems.append("%s owns no enchant family" % prof)
    for family in ("sword", "dagger", "greataxe", "metal_armor", "shield", "caster_weapon",
                   "leather_armor", "bow", "cloth_armor", "spellbook", "trinket"):
        if family not in OWNER:
            problems.append("family %s has no owner" % family)
    items = C.mob_items()
    avail = A.item_availability()
    used = uses()

    def tier_of(item):
        if item in OTHER_TIERS:
            return OTHER_TIERS[item]
        return items[item]["tier"] if item in items else None

    for tier, stats in ENCHANT.items():
        if set(stats) != set(STATS):
            problems.append("T%d enchant stats incomplete" % tier)
    for tier, rows in UPGRADE.items():
        if set(rows) != set(PROFESSIONS):
            problems.append("T%d upgrades incomplete" % tier)
        for prof, (a, b) in rows.items():
            if a == b:
                problems.append("T%d %s upgrade repeats one signature" % (tier, prof))
            scarce = [x for x in (a, b) if avail[M + x]["grade"] == "scarce"]
            if len(scarce) > 1 or (scarce and prof not in LOW_VOLUME):
                problems.append("T%d %s upgrade: scarce input %s" % (tier, prof, scarce))
    for tier, stats in ENCHANT.items():
        for stat, pair in stats.items():
            for item in pair:
                if avail[M + item]["grade"] == "scarce":
                    problems.append("T%d enchant %s: scarce input %s" % (tier, stat, item))
    for item, rows in used.items():
        grade = avail[item]["grade"] if item in avail else "?"
        if grade == "one faction":
            problems.append("%s is one faction only but used" % item)
        if item[len(M):] in SELL_ONLY:
            problems.append("%s is listed sell-only but used" % item)
        for tier, label, _ in rows:
            own = tier_of(item)
            if own is None:
                problems.append("%s is not a catalogue item" % item)
            elif own > tier:
                problems.append("%s (T%d) used in a T%d recipe" % (item, own, tier))
            elif items[item]["kind"] == "signature" and own != tier:
                problems.append("%s (T%d) signature used outside its tier (T%d)" % (item, own, tier))
    for tier, rows in ALCHEMY.items():
        for product, pair in rows.items():
            tiers = [tier_of(x if ":" in x else M + x) for x in pair]
            if None in tiers or max(tiers) != tier:
                problems.append("%s has no tier-%d ingredient (%s)" % (product, tier, tiers))
            for x in pair:
                if ":" not in x and avail[M + x]["grade"] == "one faction":
                    problems.append("%s uses one-faction %s" % (product, x))
    for item_id, row in items.items():
        if row["kind"] != "signature":
            continue
        short = item_id[len(M):]
        if item_id not in used and short not in SELL_ONLY:
            problems.append("%s has neither a use nor a sell-only reason" % item_id)
    return problems


def enchants_json():
    current = {row["tier"]: row for row in C.load_json(C.ENCHANTS)}
    out = []
    for tier in range(1, 7):
        out.append({"tier": tier,
                    "prefix_loot": {s: M + ENCHANT[tier][s][0] for s in STATS},
                    "suffix_loot": {s: M + ENCHANT[tier][s][1] for s in STATS},
                    "family_input": current[tier]["family_input"]})
    return out


def upgrades_json():
    out = []
    for tier in range(1, 7):
        for prof in PROFESSIONS:
            a, b = UPGRADE[tier][prof]
            out.append({"tier": tier, "profession": prof,
                        "families": sorted(f for f in OWNER if OWNER[f] == prof),
                        "own_material_count": 2,
                        "signatures": [M + a, M + b], "target_item_level": 10 * tier})
    return out


def name(item):
    items = C.mob_items()
    key = item if ":" in item else M + item
    if key in items:
        return items[key]["name"]
    if key == "group:grug_cooking_root":
        return "a root vegetable (Carrot, Cassava ...)"
    return key.split(":")[1].replace("_", " ").title()


def tables():
    items = C.mob_items()
    avail = A.item_availability()
    used = uses()
    out = ["### Enchant loot per channel", "",
           "| Stat | " + " | ".join("T%d prefix / suffix" % t for t in range(1, 7)) + " |",
           "|---|" + "---|" * 6]
    for stat in STATS:
        cells = ["%s / %s" % (name(ENCHANT[t][stat][0]), name(ENCHANT[t][stat][1])) for t in range(1, 7)]
        out.append("| %s | %s |" % (SHORT[stat], " | ".join(cells)))
    out += ["", "### Upgrade recipes (each also takes 2 × the own material of the tier)", "",
            "| Profession (families) | " + " | ".join("T%d" % t for t in range(1, 7)) + " |",
            "|---|" + "---|" * 6]
    for prof in PROFESSIONS:
        cells = ["%s + %s" % (name(UPGRADE[t][prof][0]), name(UPGRADE[t][prof][1])) for t in range(1, 7)]
        out.append("| %s (%s) | %s |" % (prof.capitalize(), FAMILIES[prof], " | ".join(cells)))
    out += ["", "### Counting recipes per profession and tier", ""] + progression_table()
    out += ["", "### Own material of the upgrade and of its enchants", "",
            "| Profession | " + " | ".join("T%d" % t for t in range(1, 7)) + " |", "|---|" + "---|" * 6]
    for prof in PROFESSIONS:
        out.append("| %s | %s |" % (prof.capitalize(), " | ".join(OWN_MATERIAL[prof])))
    out += ["", "### Every signature and its uses", "",
            "| Tier | Signature | Zones A/T/F | Grade | Uses | Load | Today |",
            "|---:|---|---|---|---|---:|---|"]
    rows = [(r["tier"], k) for k, r in items.items() if r["kind"] == "signature"]
    today_used = {M + x for t in C.load_json(C.ENCHANTS) for x in
                  [v[len(M):] for v in t["stat_loot"].values()]}
    for tier, item_id in sorted(rows):
        a = avail[item_id]
        label = "; ".join(lbl for _, lbl, _ in used.get(item_id, [])) or (
            "sell-only: " + SELL_ONLY.get(item_id[len(M):], "?"))
        load = sum(d for _, _, d in used.get(item_id, []))
        today = "enchant" if item_id in today_used else ("recipe" if item_id == M + "fang" else "—")
        out.append("| %d | %s | %d/%d/%d | %s | %s | %.1f | %s |" % (
            tier, items[item_id]["name"], a["accord"], a["throng"], a["front"], a["grade"],
            label, load, today))
    sig = [k for _, k in rows]
    new = [k for k in sig if k in used and k not in today_used and k != M + "fang"]
    out += ["", "Signatures: %d; with a use: %d (today 27); newly used: %d; sell-only: %d." % (
        len(sig), sum(1 for k in sig if k in used), len(new), sum(1 for k in sig if k not in used))]
    out += ["", "### Alchemy (each also takes a Glass Bottle)", "",
            "| Tier | Product | Ingredients |", "|---:|---|---|"]
    for tier in range(1, 7):
        for product, pair in ALCHEMY[tier].items():
            out.append("| %d | %s | %s + %s |" % (tier, product, name(pair[0]), name(pair[1])))
    return out


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    if args.json:
        print(json.dumps({"enchants": enchants_json(), "upgrades": upgrades_json()}, indent=2))
        return 0
    print("\n".join(tables()))
    if args.check:
        problems = check()
        for line in problems:
            print("ALLOCATION FAIL " + line)
        print("R33 DS ALLOCATION CHECK %s" % ("FAIL" if problems else "PASS"))
        return 1 if problems else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
