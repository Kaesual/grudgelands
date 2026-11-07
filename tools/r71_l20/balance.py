#!/usr/bin/env python3
"""Round 71 lanes L20 and RANGE: The Stilled Seam's numbers, for the user's decision. No
game state: every number is modelled, not measured. Three players, a Warrior, a Priest
and one damage dealer, at player level = Expedition level, the only case tuned for
(user, 2026-11-07). From 61 to 69 they are 60, the level cap, and deal the level malus
(grug_core.level_malus) against mobs above them: the top of the range is meant to be hard.

The fight model is tools/r36_r/numbers.py, imported as it is: mob HP and hits by
levels.lua's curves and the pressure fit (fitted at 60 at most), a mob swinging once a
second, the raw hit before armour, dodge, absorbs and heals. On top of it:

  * every pack is pulled whole (user, 2026-11-07): the party focuses one mob at a time,
    the spiders first, then the elite, all alive mobs hitting all the while;
  * a player's benchmark is P(L)/8 a second at their own level, times the malus; a party
    of Warrior, Mage and Priest deals PARTY of three benchmarks (the Priest's Smite 12 s
    for a normal mob, half its time on heals), and UPTIME of that while it moves, swaps
    targets and steps aside;
  * an elite's rock flies every 3 s in its ranged phase; a target in melee takes a swing
    a second and, undodged, the x3 wind-up every 12 s (numbers.py fight());
  * RECOVERY_S after a pack, to eat (no natural regeneration); WALK_NPS: walking speed;
  * damage is shown in the players' own pools, P(player level). Up to 60 every ratio
    scales with P(L), so all levels of 20-60 read alike.

Ore and gem against mining (lane RANGE, an ESTIMATE, not measured): the shipped
template's ore and gem places shared by the three, against the same minutes of a 1 x 2
tunnel in the tier's own rock with the tier's own pick; the assumptions are MINING_*.

Usage: python3 tools/r71_l20/balance.py
"""
import contextlib
import importlib.util
import io
import pathlib
import re
import sys
import zlib

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
aggro = (ROOT / "mods/ENTITIES/grug_mobs/aggro.lua").read_text()
COPPER = [int(v) for v in re.search(r"copper = \{([\d, ]+)\}", aggro).group(1).split(",")]
catalogue = (ROOT / "mods/PLAYER/grug_expeditions/catalogue.lua").read_text()
TIERS = [(int(t), int(lo), int(hi), ore, gem) for t, lo, hi, ore, gem in re.findall(
    r'\{tier = (\d+), min_level = (\d+), max_level = (\d+),\s*ore = "([^"]+)", gem = "([^"]+)"\}',
    catalogue)]
TEMPLATE_ORE, TEMPLATE_GEM = re.search(
    r'M\.TEMPLATE_ORE, M\.TEMPLATE_GEM = "([^"]+)", "([^"]+)"', catalogue).groups()
mining = (ROOT / "mods/ITEMS/grug_materials/mining.lua").read_text()
PICK_S = {int(t): float(s) for t, s in re.findall(r"\[(\d)\] = \{tier = \d, key = \"\w+\", ordinary_time = ([\d.]+)",
                                                  mining)}
registry = (ROOT / "mods/ITEMS/grug_materials/registry.lua").read_text()
RESOURCE = dict(re.findall(r'name = "([^"]+)",\s*natural_node = "([^"]+)"', registry))
RESOURCE = {node: name for name, node in RESOURCE.items()}

PLAYERS = 3
PARTY = (1 + 1 + 1 / 3) / 3  # Warrior, Mage, a Priest healing half its time at 2/3
UPTIME = 0.85
RECOVERY_S = 30
WALK_STEPS = 258  # tools/r71_l20/portable_test.lua, start to chest
WALK_NPS = 4
REWARDS_S = 120  # chest, eight nodes, the waystone
PACKS = (("a", 4, 0), ("b", 2, 1), ("c", 3, 1), ("d", 3, 1))
ELITE_ARMOR = n.TIERS["elite"][2] / 100
LEVELS = (20, 29, 39, 49, 59, 60, 65, 69)
RUN_MIN = (10, 15)
CAP = 60

# Mining, an estimate: a 1 x 2 tunnel; per metre two nodes at the pick's own time on
# its tier's rock (cracky 3, grug_materials PICK_PROFILES) plus MINING_STEP_S to aim and
# step; MINING_UPTIME of the time at the face (torches, a full bag, the way down and
# up); every metre shows MINING_SEEN host nodes (the two dug, two in each side wall, the
# floor and the roof), and an ore shown is an ore dug.
MINING_STEP_S = 0.3
MINING_UPTIME = 2 / 3
MINING_SEEN = 8
# Host nodes per resource node in the tier's own rock (world_zones.md section 11,
# Round 21 table; a half row counts its lower half, where a miner of it goes).
DENSITY = {
    2: {"default:stone_with_gold": 512, "grug_materials:stone_with_jade": 512},
    3: {"grug_materials:stone_with_silver": 256, "grug_materials:stone_with_garnet": 512},
    4: {"grug_materials:stone_with_emberglass": 256, "grug_materials:stone_with_sapphire": 512},
    5: {"grug_materials:abyssal_crystal_ore": 512, "grug_materials:stone_with_ruby": 512},
    6: {"grug_materials:abyssal_crystal_ore": 256, "grug_materials:stone_with_diamond": 512},
}


def player_level(level):
    return min(level, CAP)


def one_dps(level):
    """One benchmark against a mob of `level`, by a player at their own level or 60."""
    p = player_level(level)
    return n.P(p) / 8 * n.malus(p, level)


def pool(level):
    return n.P(player_level(level))


def band(level):
    return max(1, min(6, (level - 1) // 10 + 1))


def tier_of(level):
    for row in TIERS:
        if level <= row[2]:
            return row
    return TIERS[-1]


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


def template_places():
    """The shipped template's cells of the template ore and gem, counted."""
    data = (ROOT / "mods/PLAYER/grug_expeditions/templates/stilled_seam.exp").read_bytes()
    head, _, rest = data.partition(b"\ndata ")
    size, _, stream = rest.partition(b"\n")
    palette = [line[5:].decode() for line in head.split(b"\n") if line.startswith(b"node ")]
    sx, sy, sz = (int(v) for v in re.search(rb"size (\d+) (\d+) (\d+)", head).groups())
    cells = zlib.decompress(stream[:int(size)])[:sx * sy * sz]
    return cells.count(palette.index(TEMPLATE_ORE)), cells.count(palette.index(TEMPLATE_GEM))


def main():
    print("# The Stilled Seam, modelled, levels 20-69")
    print()
    print("Three players at the Expedition's level, 60 at most; PARTY %.2f, UPTIME %.2f." % (PARTY, UPTIME))
    print()
    print("| Level | Players | Malus | Pack a / b / c / d, with party and uptime | Raw damage a / b / c / d, party pools |")
    print("|---:|---:|---:|---|---|")
    packs_s = {}
    for level in LEVELS:
        times, pools = [], []
        for _, spiders, elites in PACKS:
            pure, damage = pack_fight(level, spiders, elites)
            times.append(pure / (PARTY * UPTIME))
            pools.append(damage / (PLAYERS * pool(level)))
        packs_s[level] = sum(times)
        print("| %d | %d | %.2f | %s s | %s |" % (
            level, player_level(level), n.malus(player_level(level), level),
            " / ".join("%.1f" % t for t in times), " / ".join("%.2f" % d for d in pools)))
    print()
    print("| Level | Spider HP / hit | Elite HP / hit | Flintback HP | Party | Tank in melee, pools | Rocks only, pools |")
    print("|---:|---|---|---:|---:|---:|---:|")
    boss_s, tank_pools = {}, {}
    for level in LEVELS:
        hp, hit, _, ttk, tank, rocks = boss(level)
        boss_s[level], tank_pools[level] = ttk, tank / pool(level)
        print("| %d | %d / %d | %d / %d | %d | %.0f s | %.1f | %.1f |" % (
            level, n.mob_hp(level, "normal"), n.mob_hit(level, "normal"),
            n.mob_hp(level, "elite"), hit, hp, ttk, tank / pool(level), rocks / pool(level)))
    print()
    print("Flintback: the elite's HP x %d. A Priest's Heal alone is 25 %% of a pool every 5 s: %.1f pools "
          "in the fight at 20, %.1f at 69." % (HP_SCALE, 0.05 * boss_s[20], 0.05 * boss_s[69]))
    print()
    print("| Level | Packs, fighting | Packs, with %d s recovery each | Flintback | Walk | Rewards | Run |"
          " Packs / boss / tank vs 20 |" % RECOVERY_S)
    print("|---:|---:|---:|---:|---:|---:|---:|---|")
    run_min = {}
    for level in LEVELS:
        packs = packs_s[level] + RECOVERY_S * len(PACKS)
        walk = WALK_STEPS / WALK_NPS
        run = packs + boss_s[level] + walk + REWARDS_S
        run_min[level] = run / 60
        print("| %d | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min | x%.2f / x%.2f / x%.2f |" % (
            level, packs_s[level] / 60, packs / 60, boss_s[level] / 60, walk / 60, REWARDS_S / 60, run / 60,
            packs_s[level] / packs_s[20], boss_s[level] / boss_s[20], tank_pools[level] / tank_pools[20]))
    print()
    ke = 12 + 3 * 4 + 4
    bands = income.estimate(round33=True)
    print("## XP: 12 normal + 3 elite + 1 boss = %d kill equivalents, shared by those present" % ke)
    print()
    print("| Run | Player | M(L) | XP per run, 3 players | KE each | KE/h at %s min | Band pace KE/h | Share of pace |"
          % " / ".join(str(m) for m in RUN_MIN))
    print("|---:|---:|---:|---:|---:|---|---:|---|")
    for level in LEVELS:
        p = player_level(level)
        if level >= CAP:
            print("| %d | %d | - | - | - | - | - | the level cap: no XP |" % (level, p))
            continue
        m = 25 + 5 * level
        each = ke * m // PLAYERS
        rates = [ke / PLAYERS * 60 / minutes for minutes in RUN_MIN]
        lo, hi = income.C.BANDS[band(level) - 1]
        pace = income.C.ke_between(lo, hi) / (bands[band(level) - 1]["hours"] * 60) * 60
        print("| %d | %d | %d | %d | %.1f | %s | %.0f | %s |" % (
            level, p, m, each, ke / PLAYERS, " / ".join("%.0f" % r for r in rates), pace,
            " / ".join("%.0f %%" % (100 * r / pace) for r in rates)))
    print()
    print("## Coins: the chest pays a bag of %d x a kill's bag at the run's level" % COIN_FACTOR)
    print()
    print("| Run | Mean bag | Chest coins | A quarter hour of income | Chest gear sold | Chest coins per hour, 15 min runs | Income/h |")
    print("|---:|---:|---:|---:|---:|---:|---:|")
    # income.py's price lists start at tier 1: the index is the band less one.
    for level in LEVELS:
        b = band(level)
        coins = COPPER[b - 1] * COIN_FACTOR
        prices = {"weapon": income.WEAPON[b - 1], "chest": income.CHEST[b - 1], "other": income.OTHER[b - 1]}
        mean = sum(income.buyback(prices[slot]) * count for slot, count in income.GEAR_POOL) / 26.0
        gear = mean * 3 + 0.25 * mean * 6
        per_hour = bands[b - 1]["per_hour"]
        print("| %d | %dc | %dc | %.0fc | %.0fc | %dc | %.0fc |" % (
            level, COPPER[b - 1], coins, per_hour / 4, gear, coins * 4, per_hour))
    print()
    registry_q = (ROOT / "mods/PLAYER/grug_quests/registry.lua").read_text()
    prices = re.search(r"COPPER_PRICE = \{([\d, ]+)\}", registry_q).group(1).split(",")
    copper = (8 * int(prices[1]) * 4 + 50) // 100  # grug_quests.quest_copper, tier 2
    print("Quest: weight 4 at level 20 pays %d XP and %dc, once (the human's +10 %% XP on top)."
          % (4 * (25 + 5 * 20), copper))
    print()
    ore_places, gem_places = template_places()
    print("## Ore and gem against mining (ESTIMATE), per player and run")
    print()
    print("The template holds %d ore and %d gem places, shared by %d players. Mining: a 1 x 2 tunnel in the"
          " tier's rock with its pick, %.1f s a metre beside the digs, %.0f %% at the face, %d host nodes"
          " shown a metre." % (ore_places, gem_places, PLAYERS, MINING_STEP_S, 100 * MINING_UPTIME, MINING_SEEN))
    print()
    print("| Run | Tier | Ore, gem | Run | Host nodes mined in that time | Ore: run / mining | Gem: run / mining |")
    print("|---:|---|---|---:|---:|---|---|")
    for level in LEVELS:
        tier, _, _, ore, gem = tier_of(level)
        metre_s = 2 * PICK_S[tier] + MINING_STEP_S
        hosts = run_min[level] * 60 * MINING_UPTIME / metre_s * MINING_SEEN
        mined_ore, mined_gem = hosts / DENSITY[tier][ore], hosts / DENSITY[tier][gem]
        run_ore, run_gem = ore_places / PLAYERS, gem_places / PLAYERS
        print("| %d | T%d | %s, %s | %.1f min | %.0f | %.2f / %.1f = %.0f %% | %.2f / %.1f = %.0f %% |" % (
            level, tier, RESOURCE.get(ore, ore), RESOURCE.get(gem, gem), run_min[level], hosts,
            run_ore, mined_ore, 100 * run_ore / mined_ore, run_gem, mined_gem, 100 * run_gem / mined_gem))


main()
