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
  * the dragon is shown with its plain swing only in the first table: its
    breath, lightning, dive and gust (boss_dragons.lua) and the arena hazards
    come on top.
Time to kill divides the HP by the group's damage per second; damage taken
is the fight's total for the tank (the target) and for each other player
in pulse range, also in neutral level-60 pools (2696 HP).

Round 37 lane MP adds the second table, the dragons' ground fight with the
breath fan and the King of Lethariel's volley, each before and after MOC-04
(round37-plan.md §2.1.5). A breath projectile punches with 1.5 x the mob's
damage (boss_dragons.lua projectile_hit), so it reaches the tank as 1.5 x
the hit above; until Round 37 all three projectiles homed on the locked
target and hit together (4.5 x), now only the middle one homes (1.5 x) and
the side ones fly straight. On the ground the dragon, in 0.05 s steps,
swings once a second while it does nothing else; its breath winds up 1.25 s
and cools down 6 s; the Stormscale Wyvern alternates breath and lightning
(1.5 s wind-up, 2 x the hit, 8 s cooldown); the gust (the tank is within 8
nodes) winds up 1.25 s every 12 s and holds the next attack 2 s; at half HP
the cooldowns shrink to 70 % (enrage). The dive (airborne only), the
whelps, the hazards and the displacement are left out. A bystander in a
side line takes one breath projectile (1.5 x the hit). The King: a level-65
elite whose signature (2 s cast, 8 s cooldown, the first after 4 s) is the
volley, three arrows of 1 x the hit each until Round 37, now one on the
target; he swings once a second otherwise and winds up as an elite.

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


DT = 0.05
BREATH = {"windup": 1.25, "cooldown": 6, "mult": 1.5}
LIGHTNING = {"windup": 1.5, "cooldown": 8, "mult": 2}
GUST = {"windup": 1.25, "cooldown": 12, "recover": 2}


def dragon_fight(hp, dps_one, players, hit, fan_hits, lightning):
    """Seconds to kill, damage to the tank, and the breath's share of it."""
    t, left, tank, breath = 0.0, hp, 0.0, 0.0
    primary, gust, swing = 2.0, GUST["cooldown"], 0.0
    action, lightning_next, enraged = None, False, False
    while left > 0:
        left -= dps_one * players * DT
        if not enraged and left <= hp / 2:
            enraged = True
            primary *= 0.7
            gust *= 0.7
        factor = 0.7 if enraged else 1
        primary, gust = max(0, primary - DT), max(0, gust - DT)
        if action:
            action["left"] -= DT
            if action["left"] <= 0:
                kind = action["kind"]
                if kind == "breath":
                    amount = fan_hits * BREATH["mult"] * hit
                    tank += amount
                    breath += amount
                    primary = BREATH["cooldown"] * factor
                elif kind == "lightning":
                    tank += LIGHTNING["mult"] * hit
                    primary = LIGHTNING["cooldown"] * factor
                else:
                    primary = max(primary, GUST["recover"])
                action = None
        elif gust <= 0:
            gust = GUST["cooldown"] * factor
            action = {"kind": "gust", "left": GUST["windup"]}
        elif primary <= 0:
            if lightning and lightning_next:
                lightning_next = False
                action = {"kind": "lightning", "left": LIGHTNING["windup"]}
            else:
                lightning_next = lightning
                action = {"kind": "breath", "left": BREATH["windup"]}
        else:
            swing += DT
            if swing >= 1:
                swing -= 1
                tank += hit
        t += DT
    return t, tank, breath


def king_fight(hp, dps_one, players, hit, volley_hits):
    """The King of Lethariel: swings, an elite wind-up, the volley."""
    t, left, tank, volley = 0.0, hp, 0.0, 0.0
    cast_cd, cast_left, tg_next, tg_left, swing = 4.0, 0.0, 4.0, 0.0, 0.0
    while left > 0:
        left -= dps_one * players * DT
        if cast_left > 0:
            cast_left -= DT
            if cast_left <= 0:
                tank += volley_hits * hit
                volley += volley_hits * hit
                cast_cd = 8.0
        elif tg_left > 0:
            tg_left -= DT
            if tg_left <= 0:
                tank += 3 * hit
                tg_next = t + 10
        else:
            cast_cd = max(0, cast_cd - DT)
            if cast_cd <= 0:
                cast_left = 2.0
            elif t >= tg_next:
                tg_left = 2.0
            else:
                swing += DT
                if swing >= 1:
                    swing -= 1
                    tank += hit
        t += DT
    return t, tank, volley


def fan_row(label, hits, fight_cells):
    pool = P(60)
    cells = []
    for players in (1, 2, 3):
        ttk, tank, share = fight_cells(players, hits)
        cells.append("%.0f s / %.1fk (%.1f) / %.1fk" % (ttk, tank / 1000, tank / pool, share / 1000))
    print("| %s | %s |" % (label, " | ".join(cells)))


print()
print("Round 37 MP: the breath fan and the King's volley, before and after MOC-04.")
print("Cells: time to kill / damage to the tank (in level-60 pools) / the breath's or volley's share.")
print()
print("| Encounter | 1 player | 2 players | 3 players |")
print("|---|---|---|---|")
dragon_hit = mob_hit(70, "boss")
dragon_dps = player_dps(70, "boss")
for name, lightning in (("Wyrmglass Ice Dragon", False), ("Stormscale Wyvern", True)):
    for label, hits in (("before: 3 locked hits", 3), ("now: 1 hit", 1)):
        fan_row("%s, %s" % (name, label), hits,
                lambda players, hits, lightning=lightning: dragon_fight(
                    18000, dragon_dps, players, dragon_hit, hits, lightning))
king_hp, king_hit, king_dps = mob_hp(65, "elite"), mob_hit(65, "elite"), player_dps(65, "elite")
for label, hits in (("before: 3 arrows on the target", 3), ("now: 1 arrow", 1)):
    fan_row("King of Lethariel (L65 elite), %s" % label, hits,
            lambda players, hits: king_fight(king_hp, king_dps, players, king_hit, hits))
print()
print("A bystander in a breath's side line takes %d (1.5 x the dragon's hit of %d) per breath;"
      % (round(1.5 * dragon_hit), dragon_hit))
print("one in a volley's side line %d (the King's hit)." % king_hit)
