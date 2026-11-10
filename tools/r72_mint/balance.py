#!/usr/bin/env python3
"""Round 72 lane MINT: The Last Mint's numbers, for the user's decision. No game state:
every number is modelled, not measured. Four players, a Warrior, a Priest and two damage
dealers, at player level = Expedition level, 60 at most: from 61 to 69 they are 60, the
level cap, and deal the level malus (grug_core.level_malus) against mobs above them, so
61-69 stays hard (user, 2026-11-07). Target: 10-20 minutes at 60.

The fight model is tools/r36_r/numbers.py, as tools/r71_l20/balance.py uses it for The
Stilled Seam: mob HP and hits by levels.lua's curves and the pressure fit, a mob swinging
once a second, the raw hit before armour, dodge, absorbs and heals. On top of it:

  * every pack is pulled whole: the party kills the normals first (Seeps, then Wisps),
    then the elite, every living mob hitting all the while; a Wisp shoots every 2 s
    (shoot_interval) instead of swinging; an elite winds up its x3 slam every 12 s;
  * a player's benchmark is P(L)/8 a second at their own level, times the malus; the party
    deals PARTY of four benchmarks (the Priest at 2/3 half the time, healing the rest) and
    UPTIME of that while it moves, swaps targets and steps out of the floor rings;
  * RECOVERY_S after a pack, to eat; the walk at WALK_NPS over the route the fixture
    measures; LAKE_S for six jumps a player, crossing one top apart and waiting for a shot
    to pass on two of the gaps; REWARDS_S for the chest, the eight nodes and the waystone;
  * the traps' hits come on top and are not modelled (45 % of a pool each, a ring to step
    out of, a shot to wait for).

The roster and Duewarden's HP factor are read from the shipped template and land_guard.lua;
the rule for setting them (the brief): one normal more per pack before more HP.

Round 73: the ambush (concept section 4.5), two candidates with one armed per run, each
about half a room pack: its fight against the room packs' mean (time and raw damage), and
one ambush's fight in the run's time. Critters are scenery and fight nobody.

Ore and gem against mining (an ESTIMATE, as the Seam's): the template's places shared by
the four, against the same minutes of a 1 x 2 tunnel in T6 rock with T6's pick.

Usage: python3 tools/r72_mint/balance.py
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

sentinel = (ROOT / "mods/ENTITIES/grug_mobs/land_guard.lua").read_text()
HP_SCALE = int(re.search(r"duewarden\._grug_hp_scale = (\d+)", sentinel).group(1))
loot = (ROOT / "mods/PLAYER/grug_expeditions/loot.lua").read_text()
mint_loot = loot[loot.index("last_mint = {"):]
COIN_FACTOR = int(re.search(r"coin_bags = \{\{factor = (\d+)\}\}", mint_loot).group(1))
aggro = (ROOT / "mods/ENTITIES/grug_mobs/aggro.lua").read_text()
COPPER = [int(v) for v in re.search(r"copper = \{([\d, ]+)\}", aggro).group(1).split(",")]
catalogue = (ROOT / "mods/PLAYER/grug_expeditions/catalogue.lua").read_text()
TEMPLATE_ORE, TEMPLATE_GEM = re.search(
    r'M\.TEMPLATE_ORE, M\.TEMPLATE_GEM = "([^"]+)", "([^"]+)"', catalogue).groups()
mining = (ROOT / "mods/ITEMS/grug_materials/mining.lua").read_text()
PICK_S = {int(t): float(s) for t, s in re.findall(r"\[(\d)\] = \{tier = \d, key = \"\w+\", ordinary_time = ([\d.]+)",
                                                  mining)}

PLAYERS = 4
PARTY = (1 + 1 + 1 + 1 / 3) / 4  # Warrior, two damage dealers, a Priest healing half its time at 2/3
UPTIME = 0.85
RECOVERY_S = 30
WALK_STEPS = 130 + 178 + 37  # tools/r72_mint/portable_test.lua: to the lake, from it, across it (Round 73)
WALK_NPS = 4
LAKE_S = 60
REWARDS_S = 120
WISP_INTERVAL = 2
ELITE_ARMOR = n.TIERS["elite"][2] / 100
LEVELS = (60, 61, 63, 65, 67, 69)
TARGET_MIN = (10, 20)
CAP = 60
# Mining, an estimate (the Seam's): T6 rock, its pick, a 1 x 2 tunnel.
MINING_STEP_S = 0.3
MINING_UPTIME = 2 / 3
MINING_SEEN = 8
DENSITY = {"grug_materials:abyssal_crystal_ore": 256, "grug_materials:stone_with_diamond": 512}
T6_ORE, T6_GEM = "grug_materials:abyssal_crystal_ore", "grug_materials:stone_with_diamond"


def template():
    data = (ROOT / "mods/PLAYER/grug_expeditions/templates/last_mint.exp").read_bytes()
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
            _, room, mob, count, tier, *_ = line.split()
            if tier == "critter":
                continue
            (ambush if room in waits else packs).setdefault(room, []).append((mob.split(":")[1], tier, int(count)))
    return packs, ambush, cells.count(palette.index(TEMPLATE_ORE)), cells.count(palette.index(TEMPLATE_GEM))


PACKS, AMBUSHES, ORE_PLACES, GEM_PLACES = template()


def player_level(level):
    return min(level, CAP)


def one_dps(level):
    p = player_level(level)
    return n.P(p) / 8 * n.malus(p, level)


def pool(level):
    return n.P(player_level(level))


def pack_fight(level, members):
    """Seconds of fighting and raw damage taken, normals first (Seeps, then Wisps)."""
    dps = PLAYERS * one_dps(level) * PARTY * UPTIME
    normals = sorted((m for m in members if m[1] == "normal"), key=lambda m: m[0] != "lava_flan")
    elites = [m for m in members if m[1] == "elite"]
    order = [(mob, 1) for mob, _, count in normals for _ in range(count)]
    t, damage = 0.0, 0.0
    alive = [mob for mob, _ in order]
    for mob, _ in order:
        seconds = n.mob_hp(level, "normal") / dps
        hit = n.mob_hit(level, "normal")
        for other in alive:
            damage += seconds * hit / (WISP_INTERVAL if other == "ember_wisp" else 1)
        damage += seconds * len(elites) * n.mob_hit(level, "elite")
        alive.remove(mob)
        t += seconds
    for _ in elites:
        hp = n.mob_hp(level, "elite") / ELITE_ARMOR
        seconds, tank, _ = n.fight(hp, dps, 1, n.mob_hit(level, "elite"), True, False)
        t += seconds
        damage += tank
    return t, damage


def boss(level):
    hp = n.mob_hp(level, "elite", HP_SCALE)
    real = PLAYERS * one_dps(level) * ELITE_ARMOR * PARTY * UPTIME
    hit = n.mob_hit(level, "elite")
    ttk, tank, _ = n.fight(hp, real, 1, hit, True, False)
    return hp, hit, ttk, tank


def roster_line():
    parts = []
    for room in sorted(PACKS):
        counts = {}
        for mob, tier, count in PACKS[room]:
            counts[(tier, mob)] = counts.get((tier, mob), 0) + count
        parts.append("%s %s" % (room, ", ".join("%d %s %s" % (c, t, m) for (t, m), c in sorted(counts.items()))))
    return "; ".join(parts)


def main():
    print("# The Last Mint, modelled, levels 60-69")
    print()
    print("Four players at the Expedition's level, 60 at most; PARTY %.2f, UPTIME %.2f." % (PARTY, UPTIME))
    print("Roster (the template): %s. Duewarden: an elite's HP x %d." % (roster_line(), HP_SCALE))
    print()
    rooms = [r for r in sorted(PACKS) if r != "boss"]
    print("| Level | Malus | Packs %s, fighting | Raw damage taken, party pools |" % " / ".join(rooms))
    print("|---:|---:|---|---|")
    packs_s = {}
    for level in LEVELS:
        times, pools = [], []
        for room in rooms:
            t, damage = pack_fight(level, PACKS[room])
            times.append(t)
            pools.append(damage / (PLAYERS * pool(level)))
        packs_s[level] = sum(times)
        print("| %d | %.2f | %s s | %s |" % (level, n.malus(player_level(level), level),
                                           " / ".join("%.0f" % t for t in times),
                                           " / ".join("%.2f" % d for d in pools)))
    print()
    print("| Level | Seep HP / hit | Elite HP / hit | Duewarden HP | Fight | Tank in melee, pools |")
    print("|---:|---|---|---:|---:|---:|")
    boss_s = {}
    for level in LEVELS:
        hp, hit, ttk, tank = boss(level)
        boss_s[level] = ttk
        print("| %d | %d / %d | %d / %d | %d | %.0f s | %.1f |" % (
            level, n.mob_hp(level, "normal"), n.mob_hit(level, "normal"), n.mob_hp(level, "elite"), hit, hp,
            ttk, tank / pool(level)))
    print()
    def tally(rows):
        counts = {}
        for mob, tier, count in rows:
            counts[(tier, mob)] = counts.get((tier, mob), 0) + count
        return ", ".join("%d %s %s" % (c, t, m) for (t, m), c in sorted(counts.items()))
    print("## The ambush: %s; one armed per run" % "; ".join(
        "%s %s" % (room, tally(rows)) for room, rows in sorted(AMBUSHES.items())))
    print()
    print("| Level | Ambush fight | Room packs' mean | Share | Raw damage, pools | Room packs' mean | Share |")
    print("|---:|---:|---:|---:|---:|---:|---:|")
    ambush_s = {}
    for level in LEVELS:
        fights = [pack_fight(level, PACKS[room]) for room in rooms]
        mean_t = sum(t for t, _ in fights) / len(fights)
        mean_d = sum(d for _, d in fights) / len(fights)
        t, d = max(pack_fight(level, rows) for rows in AMBUSHES.values()) if AMBUSHES else (0, 0)
        ambush_s[level] = t
        party = PLAYERS * pool(level)
        print("| %d | %.0f s | %.0f s | %.2f | %.2f | %.2f | %.2f |" % (
            level, t, mean_t, t / mean_t, d / party, mean_d / party, d / mean_d))
    print()
    print("| Level | Packs | + %d s each to eat | Ambush | Duewarden | Walk | Lake | Rewards | Run |" % RECOVERY_S)
    print("|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    run_min = {}
    for level in LEVELS:
        packs = packs_s[level] + RECOVERY_S * len(rooms)
        ambush = ambush_s[level] + (RECOVERY_S if AMBUSHES else 0)
        walk = WALK_STEPS / WALK_NPS
        run = packs + ambush + boss_s[level] + walk + LAKE_S + REWARDS_S
        run_min[level] = run / 60
        print("| %d | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min | %.1f min |" % (
            level, packs_s[level] / 60, packs / 60, ambush / 60, boss_s[level] / 60, walk / 60, LAKE_S / 60,
            REWARDS_S / 60, run / 60))
    lo, hi = TARGET_MIN
    verdict = "inside" if lo <= run_min[60] <= hi else "OUTSIDE"
    print()
    print("At 60 a run takes %.1f minutes, %s the target of %d-%d; at 69 %.1f (x%.2f)." % (
        run_min[60], verdict, lo, hi, run_min[69], run_min[69] / run_min[60]))
    print()
    # One ambush is armed per run: its normals count once.
    normals = sum(c for room in rooms for _, t, c in PACKS[room] if t == "normal") + \
        max((sum(c for _, _, c in rows) for rows in AMBUSHES.values()), default=0)
    elites = sum(c for room in rooms for _, t, c in PACKS[room] if t == "elite")
    ke = normals + 3 * elites + 4
    print("## XP: %d normal + %d elite + 1 boss = %d kill equivalents, shared by those present" % (
        normals, elites, ke))
    print()
    print("At 60 and above the players are at the cap and earn no XP; a level 58 or 59 player in a run "
          "at 60 gets %.1f KE of %d XP (M(L) = 25 + 5 L) per run." % (ke / PLAYERS, 25 + 5 * 59))
    print()
    print("## Coins: the chest pays a bag of %d x a kill's bag (band 6)" % COIN_FACTOR)
    print()
    bands = income.estimate(round33=True)
    per_hour = bands[5]["per_hour"]
    coins = COPPER[5] * COIN_FACTOR
    prices = {"weapon": income.WEAPON[5], "chest": income.CHEST[5], "other": income.OTHER[5]}
    mean = sum(income.buyback(prices[slot]) * count for slot, count in income.GEAR_POOL) / 26.0
    gear = mean * 3 + 0.25 * mean * 6
    print("| Mean bag | Chest coins | Income in a run's time at 60 | Chest gear sold | Income/h |")
    print("|---:|---:|---:|---:|---:|")
    print("| %dc | %dc | %.0fc | %.0fc | %.0fc |" % (COPPER[5], coins, per_hour * run_min[60] / 60, gear, per_hour))
    print()
    print("## Ore and gem against mining (ESTIMATE), per player and run")
    print()
    print("The template holds %d ore and %d gem places, shared by %d players; T6 writes Abyssal Crystal and "
          "Diamond in them." % (ORE_PLACES, GEM_PLACES, PLAYERS))
    print()
    print("| Run | Minutes | Host nodes mined in that time | Abyssal Crystal: run / mining | Diamond: run / mining |")
    print("|---:|---:|---:|---|---|")
    for level in LEVELS:
        metre_s = 2 * PICK_S[6] + MINING_STEP_S
        hosts = run_min[level] * 60 * MINING_UPTIME / metre_s * MINING_SEEN
        mined_ore, mined_gem = hosts / DENSITY[T6_ORE], hosts / DENSITY[T6_GEM]
        run_ore, run_gem = ORE_PLACES / PLAYERS, GEM_PLACES / PLAYERS
        print("| %d | %.1f | %.0f | %.2f / %.1f = %.0f %% | %.2f / %.1f = %.0f %% |" % (
            level, run_min[level], hosts, run_ore, mined_ore, 100 * run_ore / mined_ore, run_gem, mined_gem,
            100 * run_gem / mined_gem))


main()
