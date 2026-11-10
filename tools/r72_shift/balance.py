#!/usr/bin/env python3
"""Round 72 lane SHIFT: The Second Shift's numbers, the pattern of
tools/r71_l20/balance.py. No game state: every number is modelled, not measured. Four
players, a Warrior, a Priest and two damage dealers, at player level = Expedition level
(round72-second-shift.md "Route and encounters"). From 61 to 69 they are 60, the level
cap, and deal the level malus (grug_core.level_malus) against mobs above them: the top
of the range is meant to be hard.

The fight model is tools/r36_r/numbers.py, imported as it is: mob HP and hits by
levels.lua's curves and the pressure fit (fitted at 60 at most), a mob swinging or
shooting once a second, the raw hit before armour, dodge, absorbs and heals. On top:

  * every pack is pulled whole: the party focuses one mob at a time, the raiders and
    normal miners first, then the elite miner, all alive mobs hitting all the while;
  * a player's benchmark is P(L)/8 a second at their own level, times the malus; the
    party deals PARTY of four benchmarks (the Priest's Smite a third of one, half its
    time on heals), and UPTIME of that while it moves, swaps targets and steps out of
    trap rings;
  * Auditor Nemm is an elite raider with the HP factor of its definition
    (skeleton_raider.lua `nemm._grug_hp_scale`); every MARK_S his marked spot makes the
    tank and the healer step aside once (MARK_STEP_S of their time), its hit avoided;
  * RECOVERY_S after a pack, to eat; WALK_NPS walking; WALL_WAIT_S at the wall trap;
  * the counts come from the shipped template's encounter lines. The plan's rule:
    add one normal per pack before raising HP (round72-plan.md §4 SHIFT); then the
    boss's HP factor brings the run at 40 into 10-20 minutes. Round 73 BOSSHP: the user
    set the factor from 20 to 14 (2026-11-10), the run at 40 is now about 9 minutes.

Ore and gem against mining is an ESTIMATE, the Seam's: the template's places shared by
the four, against the same minutes of a 1 x 2 tunnel in the tier's own rock.

Usage: python3 tools/r72_shift/balance.py
"""
import contextlib
import importlib.util
import io
import pathlib
import re
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[2]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    with contextlib.redirect_stdout(io.StringIO()):
        spec.loader.exec_module(module)
    return module


n = load(ROOT / "tools/r36_r/numbers.py", "r36_numbers")
seam = load(ROOT / "tools/r71_l20/balance.py", "r71_l20_balance")
income = seam.income

raider = (ROOT / "mods/ENTITIES/grug_mobs/skeleton_raider.lua").read_text()
HP_SCALE = int(re.search(r"nemm\._grug_hp_scale = (\d+)", raider).group(1))
MARK_S = int(re.search(r"local MARK_EVERY = (\d+)", raider).group(1))
loot = (ROOT / "mods/PLAYER/grug_expeditions/loot.lua").read_text()
shift_loot = loot[loot.index("second_shift = {"):]
COIN_FACTOR = int(re.search(r"coin_bags = \{\{factor = (\d+)\}\}", shift_loot).group(1))
TEMPLATE = ROOT / "mods/PLAYER/grug_expeditions/templates/second_shift.exp"

PLAYERS = 4
PARTY = (1 + 1 + 1 + 1 / 3) / 4  # Warrior, two damage dealers, a Priest healing half its time
UPTIME = 0.85
MARK_STEP_S = 1
RECOVERY_S = 30
WALK_STEPS = 284  # tools/r72_shift/portable_test.lua prints it: start to chest (Round 73: the drifts)
WALK_NPS = 4
WALL_WAIT_S = 1  # half the wall trap's 2 s period (8 s until Round 74), once
REWARDS_S = 120  # chest, eight nodes, the waystone
ELITE_ARMOR = n.TIERS["elite"][2] / 100
LEVELS = (40, 49, 50, 59, 60, 65, 69)
RUN_MIN = (10, 15)
CAP = seam.CAP


def read_template():
    data = TEMPLATE.read_bytes()
    head, _, rest = data.partition(b"\ndata ")
    size, _, stream = rest.partition(b"\n")
    lines = head.decode().split("\n")
    palette = [line[5:] for line in lines if line.startswith("node ")]
    sx, sy, sz = (int(v) for v in re.search(r"size (\d+) (\d+) (\d+)", head.decode()).groups())
    cells = zlib.decompress(stream[:int(size)])[:sx * sy * sz]
    packs, ambush = {}, {}
    waits = {line.split()[3] for line in lines if line.startswith("ambush ")}
    for line in lines:
        if line.startswith("encounter "):
            _, room, _, count, tier = line.split()[:5]
            if tier == "critter":
                continue  # Round 73: scenery, no fight
            row = (ambush if room in waits else packs).setdefault(room, {"normal": 0, "elite": 0, "boss": 0})
            row[tier] += int(count)
    ore = cells.count(palette.index(seam.TEMPLATE_ORE))
    gem = cells.count(palette.index(seam.TEMPLATE_GEM))
    return packs, ambush, ore, gem


PACKS, AMBUSH, ORE_PLACES, GEM_PLACES = read_template()
FOUGHT = sorted(room for room in PACKS if room != "boss")


def one_dps(level):
    return seam.one_dps(level)


def pool(level):
    return seam.pool(level)


def pack_fight(level, normals, elites):
    """Seconds of pure fighting and raw damage for the party, normals first."""
    dps = PLAYERS * one_dps(level)
    normal_s = n.mob_hp(level, "normal") / dps
    elite_s = n.mob_hp(level, "elite") / (dps * ELITE_ARMOR)
    hit, elite_hit = n.mob_hit(level, "normal"), n.mob_hit(level, "elite")
    total = normals * normal_s + elites * elite_s
    normal_seconds = normal_s * normals * (normals + 1) / 2
    damage = normal_seconds * hit + total * elites * elite_hit
    return total, damage / (PARTY * UPTIME)


def ambush_table():
    """Round 73: an ambush candidate against a room pack, by the same fight model (a run
    arms one candidate; its mobs come at once, so it is pulled whole like a pack)."""
    print("## The ambush (Round 73): one of %d candidates armed per run" % len(AMBUSH))
    print()
    print("Each candidate: %s. Against the room packs' mean, in fighting time and raw damage taken." % (
        "; ".join("%s %d normal" % (room, AMBUSH[room]["normal"]) for room in sorted(AMBUSH))))
    print()
    print("| Level | Ambush s | Room pack s (mean) | Time share | Ambush pools | Room pack pools (mean) | Damage share |")
    print("|---:|---:|---:|---:|---:|---:|---:|")
    room = sorted(AMBUSH)[0]
    for level in LEVELS:
        a_s, a_d = pack_fight(level, AMBUSH[room]["normal"], AMBUSH[room]["elite"])
        rooms = [pack_fight(level, PACKS[r]["normal"], PACKS[r]["elite"]) for r in FOUGHT]
        p_s = sum(r[0] for r in rooms) / len(rooms)
        p_d = sum(r[1] for r in rooms) / len(rooms)
        pools = PLAYERS * pool(level)
        print("| %d | %.1f | %.1f | %.0f %% | %.2f | %.2f | %.0f %% |" % (
            level, a_s / (PARTY * UPTIME), p_s / (PARTY * UPTIME), 100 * a_s / p_s, a_d / pools, p_d / pools,
            100 * a_d / p_d))
    print()


def boss(level):
    hp = n.mob_hp(level, "elite", HP_SCALE)
    dps = PLAYERS * one_dps(level) * ELITE_ARMOR
    real = dps * PARTY * UPTIME * (1 - MARK_STEP_S / MARK_S)
    hit = n.mob_hit(level, "elite")
    ttk, tank, _ = n.fight(hp, real, 1, hit, True, False)
    return hp, hit, ttk, tank


def main():
    print("# The Second Shift, modelled, levels 40-69")
    print()
    print("Four players at the Expedition's level, 60 at most; PARTY %.2f, UPTIME %.2f." % (PARTY, UPTIME))
    print("Packs from the template: %s." % ", ".join(
        "%s %d normal + %d elite" % (room, PACKS[room]["normal"], PACKS[room]["elite"]) for room in FOUGHT))
    print()
    print("| Level | Players | Malus | Packs %s, with party and uptime | Raw damage, party pools |" %
          " / ".join(room[-1] for room in FOUGHT))
    print("|---:|---:|---:|---|---|")
    packs_s = {}
    for level in LEVELS:
        times, pools = [], []
        for room in FOUGHT:
            pure, damage = pack_fight(level, PACKS[room]["normal"], PACKS[room]["elite"])
            times.append(pure / (PARTY * UPTIME))
            pools.append(damage / (PLAYERS * pool(level)))
        packs_s[level] = sum(times)
        print("| %d | %d | %.2f | %s s | %s |" % (
            level, seam.player_level(level), n.malus(seam.player_level(level), level),
            " / ".join("%.1f" % t for t in times), " / ".join("%.2f" % d for d in pools)))
    print()
    print("| Level | Normal HP / hit | Elite HP / hit | Nemm HP | Party | Tank in melee, pools |")
    print("|---:|---|---|---:|---:|---:|")
    boss_s, tank_pools = {}, {}
    for level in LEVELS:
        hp, hit, ttk, tank = boss(level)
        boss_s[level], tank_pools[level] = ttk, tank / pool(level)
        print("| %d | %d / %d | %d / %d | %d | %.0f s | %.1f |" % (
            level, n.mob_hp(level, "normal"), n.mob_hit(level, "normal"),
            n.mob_hp(level, "elite"), hit, hp, ttk, tank / pool(level)))
    print()
    print("Nemm: the elite's HP x %d, a mark every %d s. A Priest's Heal alone is 25 %% of a pool every"
          " 5 s: %.1f pools in the fight at 40, %.1f at 69." % (HP_SCALE, MARK_S, 0.05 * boss_s[40],
                                                               0.05 * boss_s[69]))
    print()
    print("| Level | Packs, fighting | Packs, with %d s recovery each | Nemm | Walk and wall | Rewards | Run |"
          " Packs / boss / tank vs 40 |" % RECOVERY_S)
    print("|---:|---:|---:|---:|---:|---:|---:|---|")
    run_min = {}
    for level in LEVELS:
        packs = packs_s[level] + RECOVERY_S * len(FOUGHT)
        walk = WALK_STEPS / WALK_NPS + WALL_WAIT_S
        run = packs + boss_s[level] + walk + REWARDS_S
        run_min[level] = run / 60
        print("| %d | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min | x%.2f / x%.2f / x%.2f |" % (
            level, packs_s[level] / 60, packs / 60, boss_s[level] / 60, walk / 60, REWARDS_S / 60, run / 60,
            packs_s[level] / packs_s[40], boss_s[level] / boss_s[40], tank_pools[level] / tank_pools[40]))
    print()
    ambush_table()
    normals = sum(PACKS[room]["normal"] for room in FOUGHT)
    elites = sum(PACKS[room]["elite"] for room in FOUGHT)
    ke = normals + 4 * elites + 4
    bands = income.estimate(round33=True)
    print("## XP: %d normal + %d elite + 1 boss = %d kill equivalents, shared by those present" % (
        normals, elites, ke))
    print()
    print("| Run | Player | M(L) | XP per run, 4 players | KE each | KE/h at %s min | Band pace KE/h | Share of pace |"
          % " / ".join(str(m) for m in RUN_MIN))
    print("|---:|---:|---:|---:|---:|---|---:|---|")
    for level in LEVELS:
        p = seam.player_level(level)
        if level >= CAP:
            print("| %d | %d | - | - | - | - | - | the level cap: no XP |" % (level, p))
            continue
        m = 25 + 5 * level
        each = ke * m // PLAYERS
        rates = [ke / PLAYERS * 60 / minutes for minutes in RUN_MIN]
        lo, hi = income.C.BANDS[seam.band(level) - 1]
        pace = income.C.ke_between(lo, hi) / (bands[seam.band(level) - 1]["hours"] * 60) * 60
        print("| %d | %d | %d | %d | %.1f | %s | %.0f | %s |" % (
            level, p, m, each, ke / PLAYERS, " / ".join("%.0f" % r for r in rates), pace,
            " / ".join("%.0f %%" % (100 * r / pace) for r in rates)))
    print()
    print("## Coins: the chest pays a bag of %d x a kill's bag at the run's level" % COIN_FACTOR)
    print()
    print("| Run | Mean bag | Chest coins | Income over the run's length | Chest gear sold | Income/h |")
    print("|---:|---:|---:|---:|---:|---:|")
    for level in LEVELS:
        b = seam.band(level)
        coins = seam.COPPER[b - 1] * COIN_FACTOR
        prices = {"weapon": income.WEAPON[b - 1], "chest": income.CHEST[b - 1], "other": income.OTHER[b - 1]}
        mean = sum(income.buyback(prices[slot]) * count for slot, count in income.GEAR_POOL) / 26.0
        gear = mean * 3 + 0.25 * mean * 6
        per_hour = bands[b - 1]["per_hour"]
        print("| %d | %dc | %dc | %.0fc | %.0fc | %.0fc |" % (
            level, seam.COPPER[b - 1], coins, per_hour * run_min[level] / 60, gear, per_hour))
    print()
    registry_q = (ROOT / "mods/PLAYER/grug_quests/registry.lua").read_text()
    prices = re.search(r"COPPER_PRICE = \{([\d, ]+)\}", registry_q).group(1).split(",")
    copper = (8 * int(prices[3]) * 4 + 50) // 100  # grug_quests.quest_copper, tier 4
    print("Quest: weight 4 at level 40 pays %d XP and %dc, once (the human's +10 %% XP on top)."
          % (4 * (25 + 5 * 40), copper))
    print()
    print("## Ore and gem against mining (ESTIMATE), per player and run")
    print()
    print("The template holds %d ore and %d gem places, shared by %d players." % (
        ORE_PLACES, GEM_PLACES, PLAYERS))
    print()
    print("| Run | Tier | Ore, gem | Run | Host nodes mined in that time | Ore: run / mining | Gem: run / mining |")
    print("|---:|---|---|---:|---:|---|---|")
    for level in LEVELS:
        tier, _, _, ore, gem = seam.tier_of(level)
        metre_s = 2 * seam.PICK_S[tier] + seam.MINING_STEP_S
        hosts = run_min[level] * 60 * seam.MINING_UPTIME / metre_s * seam.MINING_SEEN
        mined_ore, mined_gem = hosts / seam.DENSITY[tier][ore], hosts / seam.DENSITY[tier][gem]
        run_ore, run_gem = ORE_PLACES / PLAYERS, GEM_PLACES / PLAYERS
        print("| %d | T%d | %s, %s | %.1f min | %.0f | %.2f / %.1f = %.0f %% | %.2f / %.1f = %.0f %% |" % (
            level, tier, seam.RESOURCE.get(ore, ore), seam.RESOURCE.get(gem, gem), run_min[level], hosts,
            run_ore, mined_ore, 100 * run_ore / mined_ore, run_gem, mined_gem, 100 * run_gem / mined_gem))


main()
