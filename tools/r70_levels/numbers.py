#!/usr/bin/env python3
"""Round 70 lane LEVELS: what the Round 70 boss numbers and the new level
malus do to fights (round70-plan.md §2.10), for the user's decision. No game
state; every number is modelled, not measured.

The model is tools/r36_r/numbers.py, imported as it is: players at the
same-level benchmark, the mob curves of levels.lua, the pressure fit of
grug_core.mob_pressure_scale. malus() there is the shipped rule; old_malus()
here is the one before Round 70, for the "today" rows. Armour is added here:
grug_core.armor_k grows 8.5 per attacker level above 60, so the same armour
stops less from a higher-level boss. Ratings are a full set at item level 60
(grug_gear ARMOR_LINES: 57.6 metal, 41.9 leather, 15.7 cloth).

The General runs on the King's chassis; his row uses the same model fight.

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


def old_malus(player, mob):
    excess = mob - (player + 5)
    return 1 if excess <= 0 else max(0.1, 1 - 0.1 * excess)


def armor_k(level):
    return 20 + 0.5 * min(level, 60) + 8.5 * max(level - 60, 0)


def dps(tier, factor):
    return n.P(60) / 8 * n.TIERS[tier][2] / 100 * factor


def cell(fight, players):
    ttk, tank, _ = fight(players)
    return "%.0f s / %.1f" % (ttk, tank / n.P(60))


def boss_row(label, hp, hit, factor, fight):
    print("| %s | %d | %d | %.2f | %s | %s | %s |" % (label, hp, hit, factor,
          cell(fight, 1), cell(fight, 3), cell(fight, 5)))


def king(label, level, factor):
    hp, hit, one = n.mob_hp(level, "elite"), n.mob_hit(level, "elite"), dps("elite", factor)
    boss_row(label, hp, hit, factor, lambda players: n.king_fight(hp, one, players, hit, 1))


def dragon(label, hp, factor):
    hit, one = n.mob_hit(70, "boss"), dps("boss", factor)
    boss_row(label, hp, hit, factor, lambda players: n.dragon_fight(hp, one, players, hit, 1, False))


print("Bosses: time to kill / damage to the tank in level-60 pools; the mob alone, level-60 players.")
print()
print("| Encounter | HP | Hit | Malus | 1 player | 3 players | 5 players |")
print("|---|---:|---:|---:|---|---|---|")
king("King 65, before", 65, old_malus(60, 65))
king("King 70", 70, n.malus(60, 70))
king("General 65, before", 65, old_malus(60, 65))
king("General 65", 65, n.malus(60, 65))
dragon("Dragon 70, 18k, before", 18000, old_malus(60, 70))
dragon("Dragon 70, 30k", 30000, n.malus(60, 70))
print()
print("Same armour, one mob hit after armour (share stopped):")
print()
print("| Armour | General 65 | King 70 | Dragon 70 |")
print("|---|---:|---:|---:|")
for name, rating in ARMOR:
    cells = []
    for level, tier in ((65, "elite"), (70, "elite"), (70, "boss")):
        stopped = min(0.7, rating / (rating + armor_k(level)))
        cells.append("%d (%.0f %%)" % (round(n.mob_hit(level, tier) * (1 - stopped)), 100 * stopped))
    print("| %s %.1f | %s |" % (name, rating, " | ".join(cells)))
print()
print("Everyday levelling: a normal mob 3 levels above the player, solo, baseline hit P(L)/8 a")
print("second. Damage taken is one kill's in the player's own pools (raw, before armour).")
print()
print("| Player level | Mob level | Mob HP | TTK before | TTK now | Pools before | Pools now |")
print("|---:|---:|---:|---:|---:|---:|---:|")
for level in (10, 20, 30, 40, 50, 57):
    mob = level + 3
    hp, hit, one = n.mob_hp(mob, "normal"), n.mob_hit(mob, "normal"), n.P(level) / 8
    before, now = hp / one, hp / (one * n.malus(level, mob))
    print("| %d | %d | %d | %.1f s | %.1f s | %.2f | %.2f |" % (level, mob, hp, before, now,
          before * hit / n.P(level), now * hit / n.P(level)))
print()
print("The malus by gap, before and now:")
print()
print("| Gap | " + " | ".join(str(g) for g in (1, 2, 3, 5, 6, 8, 10, 12, 15, 20)) + " |")
print("|---" + "|---:" * 10 + "|")
print("| Before | " + " | ".join("%.2f" % old_malus(1, 1 + g) for g in (1, 2, 3, 5, 6, 8, 10, 12, 15, 20)) + " |")
print("| Now | " + " | ".join("%.2f" % n.malus(1, 1 + g) for g in (1, 2, 3, 5, 6, 8, 10, 12, 15, 20)) + " |")
