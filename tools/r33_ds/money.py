#!/usr/bin/env python3
"""Round 33 lane DS: sale values, repair factor, crown and upgrade costs, the
culture vendor's price bands, and the income model before and after.

The income model is tools/r29_e4/income.py, imported unchanged (its --check
compares the shipped mount and respec tables and fails since Round 31; lane
C5 repairs that). "After" adds the Round 33 terms to the same per-band
estimate:

  * gear drops sold: every normal kill drops white 5 % / blue 2 % / gold 1 %
    (plan 2.1), sold at the Common buy-back x1 / x3 / x6; the item is a
    uniform pick over the tier's 26 equippables (6 weapons, 3 chests,
    9 other armour pieces, shield, spellbook, 6 trinkets). An upper bound:
    a player keeps what he wears.
  * repair at the proposed factor on the same wear as income.py (Uncommon
    gear, x3); the Rare (x6) column shows a player in gold gear.

Usage: money.py [--factor F]
"""
import argparse
import math
import sys

import common as C

sys.path.insert(0, str(C.REPO / "tools" / "r29_e4"))
import income as I  # noqa: E402

WEAPON, CHEST, OTHER = I.WEAPON, I.CHEST, I.OTHER
POOL = (("weapon", 6), ("chest", 3), ("other", 17))  # 26 equippables per tier
DROP = {"white": (5.0, 1), "blue": (2.0, 3), "gold": (1.0, 6)}  # percent, sale multiplier
REPAIR_TODAY = 0.20
REPAIR_PROPOSED = 1.00
SIGNATURE_VALUE = (7, 18, 45, 112, 280, 700)  # economy.md: 7c x tier factor
OWN_MATERIAL_VALUE = {  # sell value of one own material (R3 registry dump)
    "metal bar": (1, 1, 2, 8, 24, 64), "leather": (2, 2, 2, 2, 80, 82),
    "cloth bolt": (2, 10, 26, 28, 4, 42), "graded wood": (0, 0, 0, 0, 0, 0),
    "setting": (2, 2, 3, 6, 27, 67)}


def buyback(price):
    """economy.md section 2: 5 % of the purchase price, rounded up."""
    return int(math.ceil(0.05 * price - 1e-9))


def slot_prices(tier):
    return {"weapon": WEAPON[tier], "chest": CHEST[tier], "other": OTHER[tier]}


def sale_table():
    out = ["| Slot | Quality | T1 | T2 | T3 | T4 | T5 | T6 and item level 61+ |",
           "|---|---|---:|---:|---:|---:|---:|---:|"]
    for slot, label in (("weapon", "Weapon"), ("chest", "Chest"),
                        ("other", "Head, legs, feet, shield, spellbook, trinket")):
        for quality, (_, mult) in DROP.items():
            cells = [C.money(buyback(slot_prices(t)[slot]) * mult) for t in range(6)]
            out.append("| %s | %s (×%d) | %s |" % (label, quality, mult, " | ".join(cells)))
    return out


def drop_sale_per_kill(tier):
    prices = slot_prices(tier)
    mean = sum(buyback(prices[slot]) * n for slot, n in POOL) / 26.0
    return sum(pct / 100.0 * mult * mean for pct, mult in DROP.values())


def repair_per_kill(tier, factor, quality):
    armour = (CHEST[tier] + 4 * OTHER[tier]) / 5.0
    wear = I.ACTIONS_PER_KILL * WEAPON[tier] + I.HITS_PER_KILL * armour
    return factor * quality * wear / I.WEAR_USES[tier]


def income_tables(factor):
    bands = I.estimate()
    out = ["| Band | Net/h today | Gear sales/h | Repair/h today | Repair/h new (blue) | "
           "Repair/h new (gold) | Net/h after (blue) | Change | Repair share today → after (blue / gold) |",
           "|---|---:|---:|---:|---:|---:|---:|---:|---|"]
    after = []
    for tier, b in enumerate(bands):
        hours = b["hours"]
        sales = b["kills"] * drop_sale_per_kill(tier)
        rep_today = b["repair"]
        rep_blue = b["kills"] * repair_per_kill(tier, factor, 3)
        rep_gold = b["kills"] * repair_per_kill(tier, factor, 6)
        gross = b["copper"] + b["loot"] + sales - b["potions"]
        net_after = gross - rep_blue
        after.append(net_after / hours)
        out.append("| %s | %s | %s | %s | %s | %s | %s | %+.1f %% | %.1f %% → %.1f %% / %.1f %% |" % (
            b["band"], C.money(b["per_hour"]), C.money(sales / hours), C.money(rep_today / hours),
            C.money(rep_blue / hours), C.money(rep_gold / hours), C.money(net_after / hours),
            100.0 * (net_after / hours / b["per_hour"] - 1),
            100.0 * rep_today / (b["net"] + rep_today), 100.0 * rep_blue / gross, 100.0 * rep_gold / gross))
    return out, bands, after


def priced(target):
    return C.money(I.income_round(target))


def sinks(bands, after):
    t6_today, t6_after = bands[5]["per_hour"], after[5]
    out = ["| Sink | Rule | Price (today's band-6 income) | Price (after) |", "|---|---|---:|---:|"]
    for label, rule, minutes in (("Crown fee (option 1)", "30 min of band-6 income", 30),
                                 ("Crown fee (option 2, proposed)", "1 h of band-6 income", 60),
                                 ("Crown fee (option 3)", "2 h of band-6 income", 120)):
        out.append("| %s | %s | %s | %s |" % (label, rule, priced(t6_today * minutes / 60.0),
                                               priced(t6_after * minutes / 60.0)))
    return out


def upgrade_costs(bands):
    out = ["| Tier | Two signatures | Two own materials (bar … setting) | Total sell value | "
           "Minutes of the band's income |", "|---:|---:|---|---:|---:|"]
    for tier in range(6):
        sig = 2 * SIGNATURE_VALUE[tier]
        mats = [2 * v[tier] for v in OWN_MATERIAL_VALUE.values()]
        total = sig + max(mats)
        out.append("| T%d | %s | %s–%s | up to %s | %.1f |" % (
            tier + 1, C.money(sig), C.money(min(mats)), C.money(max(mats)), C.money(total),
            60.0 * total / bands[tier]["per_hour"]))
    return out


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--factor", type=float, default=REPAIR_PROPOSED)
    args = ap.parse_args(argv)
    lines = ["## Sale values of dropped gear (Common buy-back × quality)", ""] + sale_table()
    table, bands, after = income_tables(args.factor)
    lines += ["", "## Income per band before and after (repair factor %.2f, today %.2f)" % (
        args.factor, REPAIR_TODAY), ""] + table
    lines += ["", "## Crown fee", ""] + sinks(bands, after)
    lines += ["", "## Upgrade inputs in sell value", ""] + upgrade_costs(bands)
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
