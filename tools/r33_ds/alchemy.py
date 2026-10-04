#!/usr/bin/env python3
"""Round 33 lane DS: potions and elixirs T1-T6 with their values.

Healing and mana potions restore fixed amounts (plan 2.7: about half a
Priest's base pool at the tier's top level). Elixirs follow the enchant
curves of stat_values.py at the tier's top: Vigor, Focus and Precision give
two enchants' worth of their stat; Stoneskin gives one armor enchant, which
for cloth and leather wearers is about two enchants of effective HP (the
armor curve is fitted to plate).

Usage: alchemy.py
"""
import sys

import allocation as AL
import common as C
import stat_values as S

POTION = (70, 200, 400, 650, 1000, 1350)
LEVEL = (1, 11, 21, 31, 41, 51)
ROMAN = ("I", "II", "III", "IV", "V", "VI")
WEAK_POTION = 35  # the vendor's Weak Healing Potion, half of Healing Potion I


def elixir_value(product, tier):
    top = 10 * tier
    if product.startswith("Elixir of Vigor"):
        return "+%.1f %% maximum HP, 15 min" % (2 * S.curve_value("max_hp_percent", top))
    if product.startswith("Elixir of Focus"):
        return "+%.1f %% maximum Mana, 15 min" % (2 * S.curve_value("max_mana_percent", top))
    if product.startswith("Elixir of Precision"):
        return "+%.1f percentage points Crit, 15 min" % (2 * S.curve_value("crit_percent", top))
    if product.startswith("Stoneskin"):
        return "+%.1f armor rating, 30 min" % S.curve_value("armor_rating", top)
    if product.startswith("Healing Potion"):
        return "restores %d HP at once" % POTION[tier - 1]
    if product.startswith("Mana Potion"):
        return "restores %d Mana at once" % POTION[tier - 1]
    return {"Antivenom": "clears all poison (unchanged)",
            "Swiftness Draught": "+10 % movement speed for 5 s (unchanged)",
            "Cave Draught": "night vision for 10 min (unchanged)",
            "Deepwater Elixir": "water breathing for 10 min (unchanged)"}[product]


def tables():
    out = ["| Tier | Level | Product | Effect | Ingredients (+ Glass Bottle) |",
           "|---:|---:|---|---|---|"]
    for tier in range(1, 7):
        for product, pair in AL.ALCHEMY[tier].items():
            out.append("| %d | %d | %s | %s | %s + %s |" % (
                tier, LEVEL[tier - 1], product, elixir_value(product, tier),
                AL.name(pair[0]), AL.name(pair[1])))
    out += ["", "Potion check: amount against half the base pool at the tier's top level.", "",
            "| Tier | Amount | 50 % of P(10 T) | Share of a level-(10 T) Warrior / Priest / Mage HP |",
            "|---:|---:|---:|---|"]
    for tier in range(1, 7):
        level = 10 * tier
        pool = C.pool(level)
        shares = " / ".join("%.0f %%" % (100.0 * POTION[tier - 1] / (pool * C.HP_FACTOR[c]))
                            for c in ("warrior", "priest", "mage"))
        out.append("| %d | %d | %d | %s |" % (tier, POTION[tier - 1], pool // 2, shares))
    return out


def main(argv):
    print("\n".join(tables()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
