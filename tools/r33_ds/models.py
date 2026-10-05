"""Round 33 lane DS: per-class output models built from the shipped formulas.

Each model returns one number whose ratio before/after an enchant is the
enchant's worth for that class (combat_stats.md section 2; the ability and
regeneration code paths are cited in docs/design/item_tiers.md, Appendix A).

Damage models use the attribute terms continuously (Str/10, not floor): the
expected value over all characters, since the floor only decides at which
point of a class's own growth a bonus point lands.
"""
import math

import common as C

FIGHT = 60.0  # seconds of a mana-bound fight (an elite, a chain of pulls)


def _add(add, key):
    return float(add.get(key, 0.0)) if add else 0.0


def warrior_dps(level, ilvl, add=None, family="sword"):
    """Strike on the weapon's swing clock plus Mighty Blow procs on rage.

    Rage: +8 per landed swing, +3 per hit taken (one mob hit per second,
    minus dodged hits). Mighty Blow replaces a due swing at 25 rage with
    floor(1.5 W) + melee bonus (kits.lua:357-399).
    """
    a = C.attributes("warrior", level)
    weapon = C.weapon_damage(ilvl, family)
    melee = (a["str"] + _add(add, "str")) / 10.0
    dex = a["dex"] + _add(add, "dex")
    swings = (1 + _add(add, "attack_speed_percent") / 100.0) / C.WEAPONS[family][1]
    taken = 1.0 - C.dodge_chance(dex, _add(add, "dodge_percent"))
    procs = min(swings, (8 * swings + 3 * taken) / 25.0)
    extra = math.floor(1.5 * weapon) - weapon
    crit = C.crit_chance(dex, _add(add, "crit_percent"))
    return (swings * (weapon + melee) + procs * extra) * C.crit_factor(crit)


def scout_dps(level, ilvl, add=None):
    """Full-draw Loose: (bow + Dex/10) x 2.25 every 2.5 s / (1 + bow speed)."""
    a = C.attributes("scout", level)
    dex = a["dex"] + _add(add, "dex")
    shots = (1 + _add(add, "attack_speed_percent") / 100.0) / C.BOW_DRAW
    hit = (C.weapon_damage(ilvl, "bow") + dex / 10.0) * C.FULL_DRAW
    crit = C.crit_chance(dex, _add(add, "crit_percent"))
    return shots * hit * C.crit_factor(crit)


def _fight_mana(level, add):
    """Mana available in a FIGHT-second fight that starts full: the pool plus
    in-combat regeneration max(0.25 (1 + 0.15 L), 0.0025 x max mana)
    (grug_abilities/init.lua:131-145)."""
    base = C.pool(level)
    maximum = base * (1 + _add(add, "max_mana_percent") / 100.0)
    regen = max(0.25 * (1 + 0.15 * level), 0.0025 * maximum)
    return maximum + regen * FIGHT


def _cost(level, percent):
    return max(1, C.rnd(C.pool(level) * percent / 100.0))


def mage_damage(level, ilvl, add=None):
    """Fireball until the fight's mana runs out: Bw(L) + Int/10 per cast,
    6 % of P(L) per cast, at most one cast a second (kits.lua:545-620)."""
    a = C.attributes("mage", level)
    casts = min(FIGHT, _fight_mana(level, add) / _cost(level, 6))
    hit = C.baseline_weapon(level) + (a["int"] + _add(add, "int")) / 10.0
    crit = C.crit_chance(a["dex"] + _add(add, "dex"), _add(add, "crit_percent"))
    return casts * hit * C.crit_factor(crit)


def priest_healing(level, ilvl, add=None):
    """Heal until the fight's mana runs out: 25 % P x the support factor
    1 + gear Int / 10 / B(L) (Round 36; Round 33 had 1 + Int/1000), 8 % P
    per cast, heals crit like damage (kits.lua support_value,
    grug_classes/stats.lua get_support_factor, combat.lua heal_player)."""
    a = C.attributes("priest", level)
    casts = _fight_mana(level, add) / _cost(level, 8)
    amount = 0.25 * C.pool(level) * (1 + _add(add, "int") / 10.0 / C.base_hit(level))
    crit = C.crit_chance(a["dex"] + _add(add, "dex"), _add(add, "crit_percent"))
    return casts * amount * C.crit_factor(crit)


def priest_smite(level, ilvl, add=None):
    """Smite until the fight's mana runs out: 1.5 x (Bw + Int/10), 5 % P,
    one cast every 2 s (kits.lua:737-795)."""
    a = C.attributes("priest", level)
    casts = min(FIGHT / 2.0, _fight_mana(level, add) / _cost(level, 5))
    hit = 1.5 * (C.baseline_weapon(level) + (a["int"] + _add(add, "int")) / 10.0)
    crit = C.crit_chance(a["dex"] + _add(add, "dex"), _add(add, "crit_percent"))
    return casts * hit * C.crit_factor(crit)


def ehp(cls, level, ilvl, add=None, shield=False, attacker=None):
    """Effective HP against a same-level (or given) attacker's melee:
    HP / ((1 - dodge) (1 - armor reduction))."""
    a = C.attributes(cls, level)
    hp = C.pool(level) * C.HP_FACTOR[cls] * (1 + _add(add, "max_hp_percent") / 100.0)
    line = C.ARMOR_LINE[cls]
    rating = C.armor_set(line, ilvl) + _add(add, "armor_rating")
    if shield:
        rating += C.armor_set("metal", ilvl)
    reduction = C.armor_reduction(rating, attacker or level)
    dodge = C.dodge_chance(a["dex"] + _add(add, "dex"), _add(add, "dodge_percent"))
    return hp / ((1 - dodge) * (1 - reduction))


def gain(fn, level, ilvl, stat, value, **kw):
    """Relative output gain of one enchant {stat: value} for a damage or
    healing model."""
    return fn(level, ilvl, {stat: value}, **kw) / fn(level, ilvl, None, **kw) - 1


def ehp_gain(cls, level, ilvl, stat, value, **kw):
    return ehp(cls, level, ilvl, {stat: value}, **kw) / ehp(cls, level, ilvl, None, **kw) - 1
