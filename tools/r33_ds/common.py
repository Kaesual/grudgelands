"""Round 33 lane DS: shared game formulas and data loaders.

Every formula here is the shipped one (file references in the comments), so
the tables in docs/design/item_tiers.md are computed, not guessed. Read-only:
nothing in this folder writes into mods/.
"""
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
MOBS = REPO / "mods" / "ENTITIES" / "grug_mobs" / "data"
ENCHANTS = REPO / "mods" / "ITEMS" / "grug_professions" / "data" / "enchants.json"


def rnd(x):
    """Lua's math.floor(x + 0.5)."""
    return int(math.floor(x + 0.5))


# --- grug_core/combat.lua ---------------------------------------------------

def pool(level):
    """P(L), combat.lua:85-88; L clamped to 1..60."""
    level = max(1, min(60, level))
    return rnd(20 + 5 * level + 0.66 * level * level)


def baseline_weapon(level):
    """Bw(L), combat.lua:94-97 (the spell and fit reference, not an item)."""
    return rnd(4 + 0.35 * level)


def armor_k(attacker_level):
    """K(L) of the armor formula, combat_stats.md section 2."""
    return 20 + 0.5 * min(attacker_level, 60) + 8.5 * max(attacker_level - 60, 0)


def armor_reduction(rating, attacker_level):
    return min(0.70, rating / (rating + armor_k(attacker_level)))


# --- grug_gear/init.lua -----------------------------------------------------

WEAPONS = {  # family: (factor, full_punch_interval), grug_gear/init.lua:222-227
    "sword": (1.0, 1.0), "dagger": (0.7, 0.7), "greataxe": (1.5, 1.4),
    "staff": (1.2, 1.4), "wand": (1.0, 1.0), "bow": (1.0, 1.0),
}
BOW_DRAW = 2.5          # _grug_bow_draw_time
FULL_DRAW = 2.25        # Loose at full draw, scout.lua:63-71
ARMOR_LINES = {"metal": (5.6, 0.86667), "leather": (3.2667, 0.64444),
               "cloth": (2.3333, 0.22222)}
ARMOR_SHARES = (0.22, 0.35, 0.27, 0.16)
BASE_ILVL = (3, 10, 20, 30, 40, 50)   # vendor/crafted bases per material tier


def weapon_damage(ilvl, family):
    factor = WEAPONS[family][0]
    return max(1, rnd(rnd(4 + 0.35 * ilvl) * factor))


def armor_set(line, ilvl):
    base, per = ARMOR_LINES[line]
    return sum(max(1, rnd((base + per * ilvl) * share)) for share in ARMOR_SHARES)


# --- grug_classes -----------------------------------------------------------

GROWTH = {"warrior": (3, 0, 1), "mage": (0, 3, 1), "priest": (1, 2, 1),
          "scout": (1, 1, 2)}           # (str, int, dex) per level
HP_FACTOR = {"warrior": 1.2, "priest": 1.0, "mage": 0.9, "scout": 1.0}
ARMOR_LINE = {"warrior": "metal", "scout": "leather", "mage": "cloth",
              "priest": "cloth"}


def attributes(cls, level):
    g = GROWTH[cls]
    return {"str": 10 + g[0] * (level - 1), "int": 10 + g[1] * (level - 1),
            "dex": 10 + g[2] * (level - 1)}


# Crit and Dexterity (user ruling 2026-10-04, Round 33 DS rework): Dexterity
# gives 0.05 % crit (was 0.1 %) and 0.1 % dodge per point; a crit deals x2
# (was x1.5) for damage and heals. TODAY_* keep the shipped values for the
# before/after comparison.
CRIT_PER_DEX = 0.0005
CRIT_MULT = 2.0
TODAY_CRIT_PER_DEX = 0.001
TODAY_CRIT_MULT = 1.5


def crit_chance(dex, extra_pp=0.0, per_dex=None):
    per_dex = CRIT_PER_DEX if per_dex is None else per_dex
    return min(0.30, 0.05 + per_dex * dex + extra_pp / 100.0)


def crit_factor(crit, mult=None):
    """Expected damage or healing factor of a crit chance."""
    return 1 + ((CRIT_MULT if mult is None else mult) - 1) * crit


def dodge_chance(dex, extra_pp=0.0):
    return min(0.30, 0.001 * dex + extra_pp / 100.0)


def tier_of_level(level):
    """Item level or character level -> tier 1..7 (61+ is T7)."""
    return max(1, min(7, (int(level) - 1) // 10 + 1))


# --- data loaders -----------------------------------------------------------

def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def mob_items():
    return {row["id"]: row for row in load_json(MOBS / "items.json")}


def drop_sources():
    """item -> [(family, band or 'leader', chance 1:N)]"""
    out = {}
    for fam in load_json(MOBS / "drops.json"):
        for band, rows in fam["bands"].items():
            for row in rows:
                out.setdefault(row["item"], []).append((fam["family"], int(band), row["chance"]))
        for row in fam.get("leader_bonus", []):
            out.setdefault(row["item"], []).append((fam["family"], "leader", row.get("chance", 1)))
    return out


def money(copper):
    copper = int(round(copper))
    gold, rest = divmod(copper, 10000)
    silver, cu = divmod(rest, 100)
    if gold:
        return "%dg %ds %dc" % (gold, silver, cu) if cu else ("%dg %ds" % (gold, silver) if silver else "%dg" % gold)
    if silver:
        return "%ds %dc" % (silver, cu) if cu else "%ds" % silver
    return "%dc" % cu
