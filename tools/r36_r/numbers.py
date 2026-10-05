#!/usr/bin/env python3
"""Round 36 lane R: the rift boss's numbers against a dragon and a front
elite (round36-plan.md §4.3), for the user's decision. No game state.

The model is the same-level benchmark of combat_stats.md ("Same-level TTK
check") over the level-60 fit of grug_core/combat.lua and the mob curves of
grug_mobs/levels.lua:
  * a level-60 player deals the baseline hit P(60)/8 = 337 a second (the
    Warrior's sword and the Mage's Fireball; a Priest's Smite about 219 a
    second), times the target's armour group (elite 80 %, a boss-tier dragon
    100 %) and the level malus (a level-70 dragon: -50 %);
  * a mob swings once a second; its hit reaches the player after the
    pressure fit at the default `grug_mob_damage_scale` 1.5, before the
    player's own armour, dodge, absorbs and heals (the KAT's "raw" pressure);
  * an elite winds up every 10 s after 4 s of melee (2 s rooted, no swing)
    for a x3 frontal hit on the one it faces; the rift boss also casts its
    void pulse every 14 s after the first 8 s (2 s rooted) for x2 on every
    player within 6 nodes;
  * the dragon is shown with its plain swing only: its breath, lightning,
    dive and gust (boss_dragons.lua) and the arena hazards come on top.
Time to kill divides the HP by the group's damage per second; damage taken
is the fight's total for the tank (the target) and for each other player
in pulse range, also in neutral level-60 pools (2696 HP).

Usage: python3 tools/r36_r/numbers.py
"""
import math


def P(L):
    return math.floor(20 + 5 * L + 0.66 * L * L + 0.5)


def base_dmg(L):
    return 2 + 0.3 * L + 0.005 * L * L


def round1(x):
    return math.floor(x * 10 + 0.5) / 10


TIERS = {"normal": (1, 1, 100), "elite": (3, 1.8, 80), "boss": (None, 1, 100)}
DAMAGE_SCALE = 1.5


def mob_hp(L, tier, scale=1.0, flat=None):
    hp_mult = TIERS[tier][0]
    hp = flat if flat is not None else math.floor((20 + 5 * L + 0.66 * L * L) * hp_mult + 0.5)
    return math.floor(hp * scale + 0.5)


def mob_hit(L, tier):
    raw = round1(base_dmg(L) * TIERS[tier][1]) * DAMAGE_SCALE
    pressure = (math.floor(P(min(L, 60)) / 27) - 0.000001) / base_dmg(min(L, 60))
    return max(1, math.ceil(raw * pressure))


def malus(player, mob):
    excess = mob - (player + 5)
    return 1 if excess <= 0 else max(0.1, 1 - 0.1 * excess)


def player_dps(mob_level, tier):
    return P(60) / 8 * TIERS[tier][2] / 100 * malus(60, mob_level)


def fight(hp, dps_one, players, hit, telegraph, pulse):
    """Seconds to kill and damage to the tank and to another player."""
    ttk = hp / (dps_one * players)
    tank = other = 0
    tg_next, pulse_next, rooted = 4, 8, 0
    t = 0
    while t < ttk:
        if rooted > 0:
            rooted -= 1
            if rooted == 0 and casting == "telegraph":
                tank += 3 * hit
            elif rooted == 0 and casting == "pulse":
                tank += 2 * hit
                other += 2 * hit
        elif pulse and t >= pulse_next:
            casting, rooted, pulse_next = "pulse", 2, t + 2 + 14
        elif telegraph and t >= tg_next:
            casting, rooted, tg_next = "telegraph", 2, t + 2 + 10
        else:
            tank += hit
        t += 1
    return ttk, tank, other


def row(label, L, tier, scale=1.0, flat=None, telegraph=True, pulse=False):
    hp = mob_hp(L, tier, scale, flat)
    hit = mob_hit(L, tier)
    dps = player_dps(L, tier)
    cells = []
    for players in (1, 2, 3):
        ttk, tank, other = fight(hp, dps, players, hit, telegraph, pulse)
        pool = P(60)
        cells.append("%.0f s / %.1fk (%.1f) / %s" % (
            ttk, tank / 1000, tank / pool,
            ("%.1fk" % (other / 1000)) if players > 1 and pulse else "-"))
    print("| %s | %d | %d | %d | %s |" % (label, hp, hit, round(dps), " | ".join(cells)))


print("Rift boss vs a dragon and a front elite, level-60 players (numbers.py model).")
print("Cells: time to kill / damage to the tank (in level-60 pools) / damage to each other player.")
print()
print("| Encounter | HP | Hit | DPS of one player | 1 player | 2 players | 3 players |")
print("|---|---:|---:|---:|---|---|---|")
row("Rift boss (L60 elite x2 HP, pulse)", 60, "elite", scale=2, pulse=True)
row("Rift boss at x3 HP (the first proposal)", 60, "elite", scale=3, pulse=True)
row("Dragon (L70 boss, swing only)", 70, "boss", flat=18000, telegraph=False)
row("Front elite leader (L59, Glass-Throat)", 59, "elite", scale=1.5)
row("War commander (L60 elite leader)", 60, "elite", scale=1.5)
