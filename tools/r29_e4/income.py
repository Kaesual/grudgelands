#!/usr/bin/env python3
"""Round 29 lane E4: the simple income estimate and the prices it sets.

Economy plan (docs/planning/economy-vendor-plan.md) section 5 and lane E4:
reliable net solo income per level band = quest copper plus expected loot
payout, minus routine repair and potions, per played hour. No checksummed
ledger (WP44 lighter pass, D1); this script is the whole record.

Inputs:
  * quests      one leveling route per faction (r28common.track_route, the
                ledger's route definition): the shipped quest files walked
                by ledger.py (one-time quests, no repeatables, no race XP
                perk). Copper is the game's rule (grug_quests.quest_copper):
                rewards.copper, else round_half_up(0.08 x P(T) x weight).
  * kills       the band's kill equivalents (progression.md) times the XP
                share quests do not pay as rewards or gathering: quest
                kills, drop kills and free play, all at the band's level.
  * loot        the band's median kill payout measured by
                tools/r29_e1/band_payout.sh (the real price module over
                grug_mobs/data/drops.json, leader bonus rows left out; bands
                4 and 5 smoothed in Round 30 lane E).
  * time        progression.md section 1, level 60 in about 10-20 played
                hours: the midpoint, 15 h, split over the bands by their
                kill equivalents.
  * repair      per kill ACTIONS_PER_KILL wear points on the weapon and
                HITS_PER_KILL on a random armour piece (durability_repair.md),
                band-tier Uncommon gear (quality x3), ceil left out (the
                quote rounds per item, this is an hourly mean).
  * potions     POTIONS_PER_HOUR Weak Healing Potions at 8c (the only
                vendor potion, every tier).

Round 33 terms (docs/design/item_tiers.md section 6.5; the shipped prices use
them, `estimate()` without them stays the Round 29 baseline that
tools/r33_ds/money.py compares against):
  * gear sales  every kill's gear drop sold: white 5 % / blue 2 % / gold 1 %
                at the Common buy-back x1 / x3 / x6, the item a uniform pick
                over the tier's 26 equippables (6 weapons, 3 chests, 17 other:
                head, legs, feet, shield, spellbook, 6 trinkets). An upper
                bound: a player keeps what he wears.
  * repair      the factor rises from 0.20 to REPAIR_FACTOR (1.00) on the
                same wear.

Prices (economy.md section 4.1 rounding, the section 4 respec sink and the
section 4.2 targets): the four riding tiers at 15 min / 45 min / 2 h / 5 h
of the income at their level's bracket (ceil(level / 10), as respec), the
Boat like Apprentice and the Improved Boat like Journeyman Riding (travel
plan ruling 3), respec at 5 min per bracket, the Crownbinder's fee at 1 h of
band-6 income (item_tiers.md section 4).

Usage:
  income.py            print the estimate and the prices (Markdown)
  income.py --check    also compare the prices with the shipped Lua tables
                       (grug_mounts.PRICES, grug_classes.RESPEC_PRICES,
                       grug_traders.CROWN_FEE); exit 1 on a difference
  income.py --self-test
"""
import argparse
import math
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "tools" / "r28_design"))
import r28common as C  # noqa: E402
import ledger as L  # noqa: E402

ROUTES = ("dwarf", "orc")  # one per faction: Accord, Throng
LOOT_PER_KILL = (4.3, 9.0, 16.7, 43.6, 119.5, 239.3)  # band median, bands 1-6
PACE_HOURS = 15.0
POTIONS_PER_HOUR = 4
POTION_PRICE = 8
ACTIONS_PER_KILL = 4
HITS_PER_KILL = 3
QUALITY = 3
# economy.md section 2 (Common slot prices) and durability_repair.md (uses).
WEAPON = (25, 65, 160, 400, 1000, 2500)
CHEST = (20, 50, 130, 320, 800, 2000)
OTHER = (15, 35, 80, 200, 500, 1250)
WEAR_USES = (1000, 1500, 2000, 2500, 3000, 4000)
COPPER_PRICE = (25, 65, 160, 400, 1000, 2500)  # grug_quests.COPPER_PRICE

# (price table index, name, level, minutes of income)
MOUNTS = ((1, "Apprentice Riding", 15, 15), (2, "Journeyman Riding", 30, 45),
          (3, "Expert Riding", 45, 120), (4, "Master Riding", 60, 300))
BOATS = ((5, "Boat", 1), (6, "Improved Boat", 2))  # priced like that riding tier
RESPEC_MINUTES = 5
CROWN_MINUTES = 60  # the Crownbinder's fee: 1 h of band-6 income
REPAIR_FACTOR_R29 = 0.20
REPAIR_FACTOR = 1.00  # grug_repair.FACTOR since Round 33
# Gear drops per normal kill (round33-plan.md section 2.1): percent and sale
# multiplier per quality; the tier's 26 equippables by slot price.
GEAR_DROPS = ((5.0, 1), (2.0, 3), (1.0, 6))
GEAR_POOL = (("weapon", 6), ("chest", 3), ("other", 17))

MOUNT_FILE = REPO / "mods" / "PLAYER" / "grug_mounts" / "catalog.lua"
RESPEC_FILE = REPO / "mods" / "PLAYER" / "grug_classes" / "talents_ui.lua"
CROWN_FILE = REPO / "mods" / "ENTITIES" / "grug_traders" / "crown.lua"


def income_round(target):
    """economy.md section 4.1: the coarsest of 1s / 25c / 5c / 1c whose
    nearest multiple stays within 5 % of the target; midpoints round up."""
    for step in (100, 25, 5, 1):
        value = int(math.floor(target / step + 0.5)) * step
        if value > 0 and abs(value - target) <= 0.05 * target:
            return value
    return max(1, int(math.floor(target + 0.5)))


def quest_copper(quest):
    rewards = quest.get("rewards") or {}
    if isinstance(rewards.get("copper"), int):
        return rewards["copper"]
    weight = rewards.get("weight") or 0
    if weight <= 0:
        return 0
    level = quest.get("level", 1) if isinstance(quest.get("level"), int) else 1
    tier = max(1, min(6, (level - 1) // 10 + 1))
    return max(1, C.round_half_up(0.08 * COPPER_PRICE[tier - 1] * weight))


class CopperLedger(L.Ledger):
    """The ledger's walk, also summing each quest's copper into its band."""

    def run_quest(self, zone, q, acc):
        super().run_quest(zone, q, acc)
        acc["copper"] += quest_copper(q)


def route_bands(design, existing, race):
    ledger = CopperLedger(design, existing)
    for zone, lines, levels, label in C.track_route(race):
        band = (tuple(C.band_of_level(levels[0])[:2]) if levels
                else L.zone_band(L.Route(), design, zone))
        ledger.run_zone(zone, band, lines, levels, label)
    out = []
    for index, band in enumerate(C.BANDS):
        lo, hi = band[0], band[1]
        acc = ledger.per_band[(lo, hi)]
        need = C.xp_between(lo, hi)
        killed = max(0.0, need - acc["rewards"] - acc["gathering"])
        out.append({"copper": acc["copper"], "kills": C.ke_between(lo, hi) * killed / need})
    return out


def repair_per_kill(tier, factor=REPAIR_FACTOR_R29):
    armour = (CHEST[tier] + 4 * OTHER[tier]) / 5.0  # chest, head, legs, feet, offhand
    wear = ACTIONS_PER_KILL * WEAPON[tier] + HITS_PER_KILL * armour
    return factor * QUALITY * wear / WEAR_USES[tier]


def buyback(price):
    """economy.md section 2: 5 % of the purchase price, rounded up."""
    return -(-price // 20)


def gear_sales_per_kill(tier):
    """Expected sale value of one normal kill's gear drop (Round 33)."""
    prices = {"weapon": WEAPON[tier], "chest": CHEST[tier], "other": OTHER[tier]}
    mean = sum(buyback(prices[slot]) * n for slot, n in GEAR_POOL) / 26.0
    return sum(pct / 100.0 * mult * mean for pct, mult in GEAR_DROPS)


def estimate(round33=False):
    design = C.Design(C.DEFAULT_DESIGN, C.GAME_ZONE_DIRS)
    if design.errors:
        raise SystemExit("design errors: " + "; ".join(design.errors))
    existing = C.load_existing(C.DEFAULT_EXISTING)
    routes = {race: route_bands(design, existing, race) for race in ROUTES}
    total_ke = C.ke_between(1, C.LEVEL_CAP)
    bands = []
    for index, band in enumerate(C.BANDS):
        hours = PACE_HOURS * C.ke_between(band[0], band[1]) / total_ke
        copper = sum(routes[r][index]["copper"] for r in ROUTES) / len(ROUTES)
        kills = sum(routes[r][index]["kills"] for r in ROUTES) / len(ROUTES)
        loot = kills * LOOT_PER_KILL[index]
        if round33:
            loot += kills * gear_sales_per_kill(index)
            repair = kills * repair_per_kill(index, REPAIR_FACTOR)
        else:
            repair = kills * repair_per_kill(index)
        potions = hours * POTIONS_PER_HOUR * POTION_PRICE
        net = copper + loot - repair - potions
        bands.append({"band": "%d → %d" % (band[0], band[1]),
                      "routes": {r: routes[r][index] for r in ROUTES},
                      "hours": hours, "copper": copper, "kills": kills, "loot": loot,
                      "repair": repair, "potions": potions, "net": net, "per_hour": net / hours})
    return bands


def bracket(level):
    return max(1, min(6, -(-level // 10)))


def prices(bands):
    mounts = {}
    for index, name, level, minutes in MOUNTS:
        target = bands[bracket(level) - 1]["per_hour"] * minutes / 60.0
        mounts[index] = (name, level, minutes, target, income_round(target))
    for index, name, reference in BOATS:
        ref = mounts[reference]
        mounts[index] = (name, ref[1], ref[2], ref[3], ref[4])
    respec = [income_round(b["per_hour"] * RESPEC_MINUTES / 60.0) for b in bands]
    respec_targets = [b["per_hour"] * RESPEC_MINUTES / 60.0 for b in bands]
    crown_target = bands[5]["per_hour"] * CROWN_MINUTES / 60.0
    return mounts, respec, respec_targets, (crown_target, income_round(crown_target))


def money(copper):
    gold, rest = divmod(int(copper), 10000)
    silver, cu = divmod(rest, 100)
    if gold:
        return "%dg %ds %dc" % (gold, silver, cu)
    if silver:
        return "%ds %dc" % (silver, cu)
    return "%dc" % cu


def report(bands, mounts, respec, respec_targets, crown, baseline):
    out = ["# Round 29 E4 income estimate (with the Round 33 terms)", "",
           "Routes: %s (one per faction). Pace %.0f h to level 60 split by kill equivalents; "
           "loot per kill = band median plus the expected gear-drop sale; %d potions/h at %dc; "
           "repair %d weapon uses and %d armour hits per kill on Uncommon gear at factor %.2f."
           % (", ".join(ROUTES), PACE_HOURS, POTIONS_PER_HOUR, POTION_PRICE, ACTIONS_PER_KILL,
              HITS_PER_KILL, REPAIR_FACTOR), "",
           "| Band | Net/h Round 29 terms | Gear sales/h | Repair/h before | Repair/h after | "
           "Net/h after | Change |", "|---|---:|---:|---:|---:|---:|---:|"]
    for index, b in enumerate(bands):
        before = baseline[index]
        sales = b["kills"] * gear_sales_per_kill(index)
        out.append("| %s | %.0fc | %.0fc | %.0fc | %.0fc | %.0fc | %+.1f %% |" % (
            b["band"], before["per_hour"], sales / b["hours"], before["repair"] / b["hours"],
            b["repair"] / b["hours"], b["per_hour"], 100.0 * (b["per_hour"] / before["per_hour"] - 1)))
    out += ["",
           "| Band | Minutes | Kills (%s) | Kills/h | Quest copper (%s) | Loot/kill | Loot | Repair | "
           "Potions | Net | Net per hour |" % (" / ".join(ROUTES), " / ".join(ROUTES)),
           "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for index, b in enumerate(bands):
        out.append("| %s | %.0f | %s | %.0f | %s | %.1fc | %.0fc | %.0fc | %.0fc | %.0fc | %.0fc |" % (
            b["band"], b["hours"] * 60, " / ".join("%.0f" % b["routes"][r]["kills"] for r in ROUTES),
            b["kills"] / b["hours"], " / ".join("%.0f" % b["routes"][r]["copper"] for r in ROUTES),
            LOOT_PER_KILL[index], b["loot"], b["repair"], b["potions"], b["net"], b["per_hour"]))
    out += ["", "| Price | Level | Income time | Target | Price |", "|---|---:|---|---:|---:|"]
    for index in sorted(mounts):
        name, level, minutes, target, price = mounts[index]
        out.append("| %s | %d | %s | %.0fc | %s |" % (name, level, "%d min" % minutes if minutes < 60
                                                       else "%g h" % (minutes / 60.0), target, money(price)))
    for index, price in enumerate(respec):
        out.append("| Respec, bracket %d | %d-%d | %d min | %.0fc | %s |" % (
            index + 1, index * 10 + 1, index * 10 + 10, RESPEC_MINUTES, respec_targets[index], money(price)))
    out.append("| Crown fee | 60 | 1 h | %.0fc | %s |" % (crown[0], money(crown[1])))
    return "\n".join(out)


def lua_table(path, name):
    m = re.search(re.escape(name) + r"\s*=\s*\{([^}]*)\}", path.read_text(encoding="utf-8"))
    if not m:
        return None
    return [int(x) for x in re.findall(r"\d+", m.group(1))]


def lua_number(path, name):
    m = re.search(re.escape(name) + r"\s*=\s*(\d+)", path.read_text(encoding="utf-8"))
    return int(m.group(1)) if m else None


def check(mounts, respec, crown):
    problems = []
    want = [mounts[i][4] for i in sorted(mounts)]
    have = lua_table(MOUNT_FILE, "grug_mounts.PRICES")
    if have != want:
        problems.append("grug_mounts.PRICES is %s, the estimate gives %s" % (have, want))
    have = lua_table(RESPEC_FILE, "grug_classes.RESPEC_PRICES")
    if have != respec:
        problems.append("grug_classes.RESPEC_PRICES is %s, the estimate gives %s" % (have, respec))
    have = lua_number(CROWN_FILE, "grug_traders.CROWN_FEE")
    if have != crown[1]:
        problems.append("grug_traders.CROWN_FEE is %s, the estimate gives %s" % (have, crown[1]))
    return problems


def self_test():
    cases = ((737, 725), (750, 750), (18, 18), (120.4, 125), (1000, 1000), (16430, 16400),
             (97, 100), (96, 100), (95, 95), (3, 3), (0.4, 1))
    failures = ["income_round(%s) = %s, expected %s" % (t, income_round(t), e)
                for t, e in cases if income_round(t) != e]
    if quest_copper({"level": 3, "rewards": {"weight": 3}}) != 6:
        failures.append("T1 3-KE quest pays 6c")
    if quest_copper({"level": 55, "rewards": {"weight": 3}}) != 600:
        failures.append("T6 3-KE quest pays 6s")
    if quest_copper({"level": 55, "rewards": {"weight": 0, "copper": 40}}) != 40:
        failures.append("explicit copper wins")
    for line in failures:
        print("FAIL " + line)
    print("R29 E4 SELF-TEST %s checks=%d" % ("FAIL" if failures else "PASS", len(cases) + 3))
    return 1 if failures else 0


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)
    if args.self_test:
        return self_test()
    bands = estimate(round33=True)
    mounts, respec, respec_targets, crown = prices(bands)
    print(report(bands, mounts, respec, respec_targets, crown, estimate()))
    if args.check:
        problems = check(mounts, respec, crown)
        for line in problems:
            print("CHECK FAIL " + line)
        print("R29 E4 CHECK %s" % ("FAIL" if problems else "PASS"))
        return 1 if problems else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
