#!/usr/bin/env python3
"""Round 70 lane LEVELS: what level 70 Kings and level 75 dragons do to their
encounters (round70-plan.md §2.10), for the user's decision. No game state.

The model is tools/r36_r/numbers.py, imported as it is: level-60 players at
the same-level benchmark, the level malus of grug_core.level_malus, the mob
curves of levels.lua, the pressure fit of grug_core.mob_pressure_scale. Armour
is added here: grug_core.armor_k grows 8.5 per attacker level above 60, so
the same armour stops less from a higher-level boss. Ratings are a full set at
item level 60 (grug_gear ARMOR_LINES: 57.6 metal, 41.9 leather, 15.7 cloth).

The rows marked "malus at N" show the proposals for the question in the lane
report: the fight with the malus taken at level N instead of the boss's level.

Usage: python3 tools/r70_levels/numbers.py
"""
import contextlib
import importlib.util
import io
import pathlib

path = pathlib.Path(__file__).resolve().parent.parent / "r36_r" / "numbers.py"
spec = importlib.util.spec_from_file_location("r36_numbers", path)
n = importlib.util.module_from_spec(spec)
with contextlib.redirect_stdout(io.StringIO()):
    spec.loader.exec_module(n)

ARMOR = (("metal", 57.6), ("leather", 41.9), ("cloth", 15.7))


def armor_k(level):
    return 20 + 0.5 * min(level, 60) + 8.5 * max(level - 60, 0)


def dps(malus_level, tier):
    return n.player_dps(malus_level, tier)


def cell(fight, players):
    ttk, tank, _ = fight(players)
    return "%.0f s / %.1fk (%.1f)" % (ttk, tank / 1000, tank / n.P(60))


def dragon(label, level, hp, malus_level):
    hit, one = n.mob_hit(level, "boss"), dps(malus_level, "boss")
    fight = lambda players: n.dragon_fight(hp, one, players, hit, 1, False)
    print("| %s | %d | %d | %d | %s | %s | %s |" % (label, hp, hit, round(one),
          cell(fight, 1), cell(fight, 3), cell(fight, 5)))


def king(label, level, malus_level):
    hp, hit, one = n.mob_hp(level, "elite"), n.mob_hit(level, "elite"), dps(malus_level, "elite")
    fight = lambda players: n.king_fight(hp, one, players, hit, 1)
    print("| %s | %d | %d | %d | %s | %s | %s |" % (label, hp, hit, round(one),
          cell(fight, 1), cell(fight, 3), cell(fight, 5)))


print("Time to kill / damage to the tank (level-60 pools), the mob alone, level-60 players.")
print()
print("| Encounter | HP | Hit | DPS of one | 1 player | 3 players | 5 players |")
print("|---|---:|---:|---:|---|---|---|")
king("King, today (65)", 65, 65)
king("King at 70", 70, 70)
king("King at 70, malus at 65", 70, 65)
dragon("Dragon, today (70, 18k)", 70, 18000, 70)
dragon("Dragon at 75, 30k", 75, 30000, 75)
dragon("Dragon at 75, 30k, malus at 70", 75, 30000, 70)
print()
print("Same armour, one mob hit after armour (share stopped):")
print()
print("| Armour | King 65 | King 70 | Dragon 70 | Dragon 75 |")
print("|---|---:|---:|---:|---:|")
for name, rating in ARMOR:
    cells = []
    for level, tier in ((65, "elite"), (70, "elite"), (70, "boss"), (75, "boss")):
        stopped = min(0.7, rating / (rating + armor_k(level)))
        cells.append("%d (%.0f %%)" % (round(n.mob_hit(level, tier) * (1 - stopped)), 100 * stopped))
    print("| %s %.1f | %s |" % (name, rating, " | ".join(cells)))
