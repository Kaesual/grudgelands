#!/usr/bin/env python3
"""Round 71 lane L20: The Stilled Seam's numbers, for the user's decision. No game
state: every number is modelled, not measured. Three players at player level =
Expedition level, the only case tuned for (user, 2026-11-07).

The fight model is tools/r36_r/numbers.py, imported as it is: mob HP and hits by
levels.lua's curves and the pressure fit, a mob swinging once a second, the raw hit
before armour, dodge, absorbs and heals. On top of it:

  * every pack is pulled whole (user, 2026-11-07): the party focuses one mob at a time,
    the spiders first, then the elite, all alive mobs hitting all the while;
  * a player's benchmark is P(L)/8 a second; a party of Warrior, Mage and Priest deals
    PARTY of three benchmarks (the Priest's Smite 12 s for a normal mob, half its
    time on heals), and UPTIME of that while it moves, swaps targets and steps aside;
  * an elite's rock flies every 3 s in its ranged phase; a target in melee takes a swing
    a second and, undodged, the x3 wind-up every 12 s (numbers.py fight());
  * RECOVERY_S after a pack, to eat (no natural regeneration); WALK_NPS: walking speed;
  * every ratio scales with P(L), so levels 20 and 29 read alike: the table shows both.

Usage: python3 tools/r71_l20/balance.py
"""
import contextlib
import importlib.util
import io
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    with contextlib.redirect_stdout(io.StringIO()):
        spec.loader.exec_module(module)
    return module


n = load(ROOT / "tools/r36_r/numbers.py", "r36_numbers")
sys.path.insert(0, str(ROOT / "tools/r29_e4"))
income = load(ROOT / "tools/r29_e4/income.py", "income")

golem = (ROOT / "mods/ENTITIES/grug_mobs/golem.lua").read_text()
HP_SCALE = int(re.search(r"flintback\._grug_hp_scale = (\d+)", golem).group(1))
loot = (ROOT / "mods/PLAYER/grug_expeditions/loot.lua").read_text()
stilled = loot[loot.index("stilled_seam = {"):]
COIN_FACTOR = int(re.search(r"coin_bags = \{\{factor = (\d+)\}\}", stilled).group(1))

PLAYERS = 3
PARTY = (1 + 1 + 1 / 3) / 3  # Warrior, Mage, a Priest healing half its time at 2/3
UPTIME = 0.85
RECOVERY_S = 30
WALK_STEPS = 258  # tools/r71_l20/portable_test.lua, start to chest
WALK_NPS = 4
REWARDS_S = 120  # chest, eight nodes, the waystone
PACKS = (("a", 4, 0), ("b", 2, 1), ("c", 3, 1), ("d", 3, 1))
ELITE_ARMOR = n.TIERS["elite"][2] / 100
COPPER_BAND = {20: 10, 29: 26}  # grug_mobs.COIN_BAG, mean bag of the level's band
INCOME_H = {20: 433, 29: 971}  # income.py: net per hour, bands 10-20 and 20-30
KE_BAND = {20: 119, 29: 148}  # progression.md, kill equivalents of the band
MIN_BAND = {20: 111, 29: 138}  # income.py, minutes of the band
RUN_MIN = (10, 15)


def one_dps(level):
    return n.P(level) / 8


def pack_fight(level, spiders, elites):
    """Seconds and raw damage for the party, spiders first."""
    dps = PLAYERS * one_dps(level)
    spider_s = n.mob_hp(level, "normal") / dps
    elite_s = n.mob_hp(level, "elite") / (dps * ELITE_ARMOR)
    hit, elite_hit = n.mob_hit(level, "normal"), n.mob_hit(level, "elite")
    total = spiders * spider_s + elites * elite_s
    spider_seconds = spider_s * spiders * (spiders + 1) / 2
    damage = spider_seconds * hit + total * elites * elite_hit
    # The party really takes this long: PARTY and UPTIME stretch the pure fight time.
    return total, damage / (PARTY * UPTIME)


def boss(level):
    hp = n.mob_hp(level, "elite", HP_SCALE)
    dps = PLAYERS * one_dps(level) * ELITE_ARMOR
    real = dps * PARTY * UPTIME
    hit = n.mob_hit(level, "elite")
    ttk, tank, _ = n.fight(hp, real, 1, hit, True, False)
    rocks = ttk / 3 * hit
    return hp, hit, hp / dps, ttk, tank, rocks


def main():
    print("# The Stilled Seam, modelled")
    print()
    print("Three players at the Expedition's level; PARTY %.2f, UPTIME %.2f." % (PARTY, UPTIME))
    print()
    print("| Level | Pack | Mobs | Pure fight | With party and uptime | Raw damage, party pools |")
    print("|---:|---|---|---:|---:|---:|")
    totals = {}
    for level in (20, 29):
        fight_s = 0
        for name, spiders, elites in PACKS:
            pure, damage = pack_fight(level, spiders, elites)
            fight_s += pure
            print("| %d | %s | %d spiders, %d elite | %.1f s | %.1f s | %.2f |" % (
                level, name, spiders, elites, pure, pure / (PARTY * UPTIME),
                damage / (PLAYERS * n.P(level))))
        totals[level] = fight_s / (PARTY * UPTIME)
    print()
    print("| Level | P(L) | Spider HP / hit | Elite HP / hit | Flintback HP |"
          " Full benchmark | Party | Tank in melee, pools | Rocks only, pools |")
    print("|---:|---:|---|---|---:|---:|---:|---:|---:|")
    boss_s = {}
    for level in (20, 29):
        hp, hit, full, ttk, tank, rocks = boss(level)
        boss_s[level] = ttk
        print("| %d | %d | %d / %d | %d / %d | %d | %.0f s | %.0f s | %.1f | %.1f |" % (
            level, n.P(level), n.mob_hp(level, "normal"), n.mob_hit(level, "normal"),
            n.mob_hp(level, "elite"), hit, hp, full, ttk, tank / n.P(level), rocks / n.P(level)))
    print()
    print("Flintback: the elite's HP x %d. A Priest's Heal alone is 25 %% of a pool every 5 s: %.1f pools "
          "in the fight." % (HP_SCALE, 0.05 * boss_s[20]))
    print()
    print("| Level | Packs, fighting | Packs, with %d s recovery each | Flintback | Walk | Rewards | Run |" % RECOVERY_S)
    print("|---:|---:|---:|---:|---:|---:|---:|")
    for level in (20, 29):
        packs = totals[level] + RECOVERY_S * len(PACKS)
        walk = WALK_STEPS / WALK_NPS
        run = packs + boss_s[level] + walk + REWARDS_S
        print("| %d | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min |" % (
            level, totals[level] / 60, packs / 60, boss_s[level] / 60, walk / 60, REWARDS_S / 60, run / 60))
    print()
    ke = 12 + 3 * 4 + 4
    print("## XP: 12 normal + 3 elite + 1 boss = %d kill equivalents, shared by those present" % ke)
    print()
    print("| Run | Player | M(L) | XP per run, 3 players | KE each | KE/h at %s min | Band pace KE/h | Share of pace |"
          % " / ".join(str(m) for m in RUN_MIN))
    print("|---:|---:|---:|---:|---:|---|---:|---|")
    for level in (20, 29):
        m = 25 + 5 * level
        each = ke * m // PLAYERS
        rates = [ke / PLAYERS * 60 / minutes for minutes in RUN_MIN]
        pace = KE_BAND[level] / MIN_BAND[level] * 60
        print("| +%d | %d | %d | %d | %.1f | %s | %.0f | %s |" % (
            level - 20, level, m, each, ke / PLAYERS, " / ".join("%.0f" % r for r in rates), pace,
            " / ".join("%.0f %%" % (100 * r / pace) for r in rates)))
    print()
    print("## Coins: the chest pays a bag of %d x a kill's bag at the run's level" % COIN_FACTOR)
    print()
    print("| Run | Mean bag | Chest coins | A quarter hour of income | Chest gear sold | Chest coins per hour, 15 min runs | Income/h |")
    print("|---:|---:|---:|---:|---:|---:|---:|")
    # income.py's price lists start at tier 1: the index is the tier less one.
    for level, tier in ((20, 1), (29, 2)):
        coins = COPPER_BAND[level] * COIN_FACTOR
        prices = {"weapon": income.WEAPON[tier], "chest": income.CHEST[tier], "other": income.OTHER[tier]}
        mean = sum(income.buyback(prices[slot]) * count for slot, count in income.GEAR_POOL) / 26.0
        gear = mean * 3 + 0.25 * mean * 6
        print("| %d | %dc | %dc | %.0fc | %.0fc | %dc | %dc |" % (
            level, COPPER_BAND[level], coins, INCOME_H[level] / 4, gear, coins * 4, INCOME_H[level]))
    print()
    registry = (ROOT / "mods/PLAYER/grug_quests/registry.lua").read_text()
    prices = re.search(r"COPPER_PRICE = \{([\d, ]+)\}", registry).group(1).split(",")
    copper = (8 * int(prices[1]) * 4 + 50) // 100  # grug_quests.quest_copper, tier 2
    print("Quest: weight 4 at level 20 pays %d XP and %dc, once (the human's +10 %% XP on top)."
          % (4 * (25 + 5 * 20), copper))


main()
