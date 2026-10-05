#!/usr/bin/env python3
"""Round 36 lane K: class fine-tuning numbers for the user's decision.

Prints Markdown tables (no game state is read or written):

  heal     the Priest's Heal today (1 + Int/1000) against the proposed rule
           (gear Intelligence over a base hit), per cast, per second and per
           mana; the main-stat sets of all four classes; the one-enchant
           check; every support effect that shares the factor
  set      the full damage sets per class today and proposed (Scout with the
           proposed Dexterity curve, Priest healing with the proposed rule)
  scout    where the Scout's extra set gain comes from and the Dexterity
           curve candidates
  spells   spell damage rounded before the level scalar (today) against one
           floor after it (proposed), per spell
  all      everything above (default)

The game formulas come from tools/r33_ds (common.py, models.py,
stat_values.py), which mirror the shipped code (item_tiers.md Appendix A);
the fit block (base pool, baseline weapon, a base hit, level scalar) is the
one of grug_core/combat.lua. Numbers are comparisons, never targets.

Phase 2 shipped the proposals (the user's picks, 2026-10-05): "today" is
the Round 35 state kept as constants here (DEX_TODAY, factor_today); tables
that read the r33_ds curves directly (the main-stat sets, the Scout split)
now show the shipped Dexterity curve.

Usage: python3 tools/r36_k/numbers.py [heal|set|scout|spells|all]
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "r33_ds"))

import common as C  # noqa: E402
import models as M  # noqa: E402
import stat_values as S  # noqa: E402

LEVELS = ((30, 30), (45, 45), (60, 60), (60, 70))  # (character level, item level)
SET_POINTS = ((30, 30), (45, 45), (60, 60), (60, 65), (60, 70))
HEAL_SHARE = 25.0     # Heal: 25 % of P(L), kits.lua
HEAL_COST = 8         # % of P(L)
HEAL_COOLDOWN = 4.0   # s
FIGHT = M.FIGHT       # the 60 s mana-bound fight of item_tiers.md
DEX_TODAY = (0.8, 0.13, 0.0019, 0, 1)  # Round 33-35
DEX_PROPOSED = (0.8, 0.13, 0.0011, 0, 1)  # only c changes: 0.0019 -> 0.0011


# --- the fit block (grug_core/combat.lua) ---------------------------------

def bw(level):
    return C.baseline_weapon(level)


def base_hit(level):
    """grug_core.baseline_melee_total: own-level sword + Warrior Str/10."""
    level = max(1, min(60, level))
    return bw(level) + (10 + 3 * (level - 1)) / 10


def scale(level):
    level = max(1, min(60, level))
    return C.pool(level) / (8 * base_hit(level))


def naked_int(cls, level):
    return C.attributes(cls, level)["int"]


# --- support factor: today and proposed -----------------------------------

def factor_today(cls, level, int_total):
    """kits.lua support_value: 1 + spell power / 100 = 1 + Int / 1000."""
    return 1 + int_total / 1000.0


def factor_proposed(cls, level, int_total):
    """Gear Intelligence (Intelligence above the class's own level growth)
    counts like a Mage's on Fireball: Int/10 over a base hit, so a character
    without Intelligence gear gets exactly the listed pool share."""
    return 1 + (int_total - naked_int(cls, level)) / 10.0 / base_hit(level)


def factor_const(cls, level, int_total, k=300.0, share_scale=None):
    """The alternative in kind: a constant divisor, 1 + Int / k."""
    return 1 + int_total / k


RULES = {"today": factor_today, "proposed": factor_proposed}


def ev(stat, ilvl):
    return S.enchant_value(stat, ilvl, C.tier_of_level(ilvl))


def priest_heal(level, add=None, rule="today", share=HEAL_SHARE):
    """One Heal: amount before crit (continuous, like the Round 33 models;
    `shown` is heal_player's floor), the expected crit factor, per second
    (one cast per cooldown), per mana, and the healing of a 60 s fight that
    starts with a full pool and spends all its mana on Heal (the Round 33
    check's model, models.priest_healing: no cooldown cap, since Shield, Mend
    and Smite share the pool)."""
    add = add or {}
    a = C.attributes("priest", level)
    int_total = a["int"] + add.get("int", 0)
    amount = C.pool(level) * share / 100.0 * RULES[rule]("priest", level, int_total)
    crit = C.crit_factor(C.crit_chance(a["dex"] + add.get("dex", 0), add.get("crit_percent", 0)))
    cost = max(1, C.rnd(C.pool(level) * HEAL_COST / 100.0))
    casts = M._fight_mana(level, add) / cost
    return {"amount": amount, "shown": math.floor(amount), "crit": crit, "per_second": amount * crit / HEAL_COOLDOWN,
            "per_mana": amount * crit / cost, "fight": casts * amount * crit, "int": int_total,
            "cost": cost}


def int_set(ilvl):
    return {"int": 8 * ev("int", ilvl)}


def heal_set(ilvl, mana=False):
    add = {"int": 8 * ev("int", ilvl), "crit_percent": 2 * ev("crit_percent", ilvl)}
    if mana:
        add["max_mana_percent"] = 6 * ev("max_mana_percent", ilvl)
    return add


def pct(x):
    return "%+.1f %%" % (100 * x)


def heal_tables():
    out = ["### Heal per cast, per second and per mana", "",
           "Level-L Priest without talents, crit from its own Dexterity plus gear "
           "(×2 per crit), one Heal per 4 s cooldown, 8 % of P(L) mana. \"Int set\": "
           "Intelligence on all eight items at the item level; \"heal set\": the Int set "
           "plus two Crit enchants.", "",
           "| Level / item level | Gear | Int | Factor today → proposed | Heal per cast | "
           "Per second | Per mana | Change |",
           "|---|---|---:|---|---|---|---|---:|"]
    for level, ilvl in LEVELS:
        for label, add in (("none", None), ("Int set", int_set(ilvl)), ("heal set", heal_set(ilvl))):
            if label == "none" and ilvl != level:
                continue
            t = priest_heal(level, add, "today")
            p = priest_heal(level, add, "proposed")
            out.append("| %d / %s | %s | %d | %.3f → %.3f | %d → %d | %.1f → %.1f | %.2f → %.2f | %s |" % (
                level, ilvl if label != "none" else "—", label, t["int"],
                factor_today("priest", level, t["int"]), factor_proposed("priest", level, t["int"]),
                t["shown"], p["shown"], t["per_second"], p["per_second"],
                t["per_mana"], p["per_mana"], pct(p["per_second"] / t["per_second"] - 1)))
    out += ["", "Per second and per mana move together: the rule changes the amount, "
            "not the cost or the cooldown."]

    out += ["", "### What the main-stat set adds, per class", "",
            "The class's attribute on all eight items, nothing else, against the same "
            "character in the same gear without enchants (the item level's weapon on both "
            "sides). Warrior: Strike plus Mighty Blow; Scout: full-draw Loose; Mage: "
            "Fireball; Priest: Heal (per second and per mana alike) and Smite.", "",
            "| Level / item level | Attribute per enchant | Warrior (Str) | Scout (Dex) | "
            "Mage (Int) | Priest Heal today | Priest Heal proposed | Priest Smite |",
            "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for level, ilvl in LEVELS:
        w = M.warrior_dps(level, ilvl, {"str": 8 * ev("str", ilvl)}) / M.warrior_dps(level, ilvl) - 1
        s = M.scout_dps(level, ilvl, {"dex": 8 * ev("dex", ilvl)}) / M.scout_dps(level, ilvl) - 1
        m = M.mage_damage(level, ilvl, int_set(ilvl)) / M.mage_damage(level, ilvl) - 1
        ht = priest_heal(level, int_set(ilvl), "today")["per_second"] / priest_heal(level, None, "today")["per_second"] - 1
        hp = priest_heal(level, int_set(ilvl), "proposed")["per_second"] / priest_heal(level, None, "proposed")["per_second"] - 1
        sm = M.priest_smite(level, ilvl, int_set(ilvl)) / M.priest_smite(level, ilvl) - 1
        out.append("| %d / %d | Str %d · Dex %d · Int %d | %s | %s | %s | %s | %s | %s |" % (
            level, ilvl, ev("str", ilvl), ev("dex", ilvl), ev("int", ilvl),
            pct(w), pct(s), pct(m), pct(ht), pct(hp), pct(sm)))

    out += ["", "### One enchant (the item_tiers.md §1.2 check, Priest healing)", "",
            "Gain of one enchant at the point's item level for a Priest of that level "
            "(Heal over a 60 s fight, as the check measures it; `stat_values.py` keeps a "
            "kind within ×1.35).", "",
            "| Point | Target | Int today | Int proposed | Crit | Mana | Spread proposed |",
            "|---|---:|---:|---:|---:|---:|---:|"]
    for name, level, ilvl in S.check_points():
        if not (name.endswith("top") or name.startswith("T7")):
            continue
        base = {r: priest_heal(level, None, r)["fight"] for r in RULES}
        gain = lambda stat, r: priest_heal(level, {stat: ev(stat, ilvl)}, r)["fight"] / base[r] - 1
        it, ip = gain("int", "today"), gain("int", "proposed")
        cr, mn = gain("crit_percent", "proposed"), gain("max_mana_percent", "proposed")
        trio = [ip, cr, mn]
        out.append("| %s | %.1f | %.1f | %.1f | %.1f | %.1f | ×%.2f |" % (
            name, 100 * S.target(ilvl), 100 * it, 100 * ip, 100 * cr, 100 * mn,
            max(trio) / min(trio) if min(trio) > 0 else float("inf")))
    out += ["", "The check's model (`models.priest_healing`): Heal until the fight's mana "
            "runs out, so Mana counts in full; the 4 s cooldown is left out because Shield, "
            "Mend and Smite share the pool. \"Int today\" is the shipped column of §1.2."]

    out += ["", "### Every support amount that shares the factor", "",
            "`kits.lua` `support_value` (base pool × share × factor) feeds Heal, Hearten's "
            "splash (65 % of the Heal), Mend's ticks, Shield, Recompense's absorb and the "
            "Mage's Glacial Ward; one rule changes all of them. Factors at level 60:", "",
            "| Character | Gear | Int | Today | Proposed | Change |", "|---|---|---:|---:|---:|---:|"]
    for cls in ("priest", "mage"):
        for label, ilvl in (("none", None), ("Int set, item level 60", 60), ("Int set, item level 70", 70)):
            total = naked_int(cls, 60) + (8 * ev("int", ilvl) if ilvl else 0)
            t, p = factor_today(cls, 60, total), factor_proposed(cls, 60, total)
            out.append("| %s 60 | %s | %d | ×%.3f | ×%.3f | %s |" % (
                cls.capitalize(), label, total, t, p, pct(p / t - 1)))
    out += ["", "Not following: Word of Ruin's drain (it heals a share of the damage dealt, "
            "which already carries Int/10 like every spell), Hold Ground (the neutral pool, "
            "no spell power), potions and food (fixed or max-HP amounts)."]

    out += ["", "### The alternative in kind: a constant divisor", "",
            "`1 + Int / k` with a smaller k keeps today's shape. With k = 300 and Heal's "
            "share lowered to keep today's level-60 Heal without gear (25 % → 19.8 %):", "",
            "| Level | Heal without gear vs today | Int set gain (item level = level) |",
            "|---:|---:|---:|"]
    share = HEAL_SHARE * factor_today("priest", 60, naked_int("priest", 60)) / factor_const(
        "priest", 60, naked_int("priest", 60))
    for level in (10, 30, 45, 60):
        n_int = naked_int("priest", level)
        naked = share * factor_const("priest", level, n_int) / (HEAL_SHARE * factor_today("priest", level, n_int))
        set_int = n_int + 8 * ev("int", level)
        gain = factor_const("priest", level, set_int) / factor_const("priest", level, n_int)
        out.append("| %d | %s | %s |" % (level, pct(naked - 1), pct(gain - 1)))
    out += ["", "The level growth of Intelligence then decides part of the Heal (so the share "
            "must be re-based and every support text changes), and gear Intelligence is "
            "worth half as much at level 30 as at 60."]
    return out


# --- the full damage sets ----------------------------------------------------

def with_dex(curve, fn):
    saved = S.CURVES["dex"]
    S.CURVES["dex"] = curve
    try:
        return fn()
    finally:
        S.CURVES["dex"] = saved


def set_gains(level, ilvl):
    """r33_ds build_doc.full_set_lines generalised to a level: against the
    same character in plain gear of the item level (item level 60 for the
    T7 points)."""
    ref = 60 if ilvl > 60 else ilvl
    v = lambda s: ev(s, ilvl)
    dmg = lambda s: {s: 8 * v(s), "crit_percent": 2 * v("crit_percent"),
                     "attack_speed_percent": v("attack_speed_percent")}
    w = M.warrior_dps(level, ilvl, dmg("str")) / M.warrior_dps(level, ref) - 1
    s = M.scout_dps(level, ilvl, dmg("dex")) / M.scout_dps(level, ref) - 1
    short = M.mage_damage(level, ilvl, {"int": 8 * v("int"), "crit_percent": 2 * v("crit_percent")}) \
        / M.mage_damage(level, ref) - 1
    bound = M.mage_damage(level, ilvl, {"int": 8 * v("int"), "crit_percent": 2 * v("crit_percent"),
                                        "max_mana_percent": 6 * v("max_mana_percent")}) / M.mage_damage(level, ref) - 1
    heal = {}
    for rule in RULES:
        base = priest_heal(level, None, rule)
        heal[rule] = (priest_heal(level, heal_set(ilvl), rule)["per_second"] / base["per_second"] - 1,
                      priest_heal(level, heal_set(ilvl, True), rule)["fight"] / base["fight"] - 1)
    return w, s, short, bound, heal


def set_tables():
    out = ["### The full set per class", "",
           "Damage sets as item_tiers.md §1.1: the attribute on all eight items, two Crit "
           "enchants, Attack speed on the weapon (Warrior, Scout); the Mage's six other "
           "channels Mana for the mana-bound fight. Priest heal set: Intelligence on all "
           "eight items and two Crit enchants (per second), plus six Mana (60 s fight). "
           "Against the same character in plain gear of the item level (item level 60 for "
           "65 and 70).", "",
           "| Level / item level | Warrior | Scout today | Scout proposed | Mage short / mana-bound "
           "| Priest Heal today (per s / 60 s) | Priest Heal proposed (per s / 60 s) |",
           "|---|---:|---:|---:|---|---|---|"]
    for level, ilvl in SET_POINTS:
        w, s_today, short, bound, heal = with_dex(DEX_TODAY, lambda: set_gains(level, ilvl))
        s_new = with_dex(DEX_PROPOSED, lambda: set_gains(level, ilvl))[1]
        out.append("| %d / %d | %s | %s | %s | %s / %s | %s / %s | %s / %s |" % (
            level, ilvl, pct(w), pct(s_today), pct(s_new), pct(short), pct(bound),
            pct(heal["today"][0]), pct(heal["today"][1]),
            pct(heal["proposed"][0]), pct(heal["proposed"][1])))
    out += ["", "The Warrior, Mage and Priest columns do not depend on the Dexterity curve "
            "(their sets carry no Dexterity)."]
    return out


# --- the Scout ---------------------------------------------------------------

def scout_parts(level, ilvl, ref):
    a = C.attributes("scout", level)
    dex = 8 * ev("dex", ilvl)
    hit = (C.weapon_damage(ilvl, "bow") + (a["dex"] + dex) / 10.0) / (C.weapon_damage(ref, "bow") + a["dex"] / 10.0)
    c0 = C.crit_chance(a["dex"])
    c_dex = C.crit_chance(a["dex"] + dex)
    c_all = C.crit_chance(a["dex"] + dex, 2 * ev("crit_percent", ilvl))
    return {"hit": hit, "dexcrit": C.crit_factor(c_dex) / C.crit_factor(c0),
            "critench": C.crit_factor(c_all) / C.crit_factor(c_dex),
            "speed": 1 + ev("attack_speed_percent", ilvl) / 100.0, "crit": (c0, c_all)}


def warrior_parts(level, ilvl, ref):
    a = C.attributes("warrior", level)
    strength = 8 * ev("str", ilvl)
    hit = (C.weapon_damage(ilvl, "sword") + (a["str"] + strength) / 10.0) / (
        C.weapon_damage(ref, "sword") + a["str"] / 10.0)
    c0 = C.crit_chance(a["dex"])
    c_all = C.crit_chance(a["dex"], 2 * ev("crit_percent", ilvl))
    total = M.warrior_dps(level, ilvl, {"str": strength, "crit_percent": 2 * ev("crit_percent", ilvl),
                                        "attack_speed_percent": ev("attack_speed_percent", ilvl)}) / M.warrior_dps(level, ref)
    speed = 1 + ev("attack_speed_percent", ilvl) / 100.0
    critench = C.crit_factor(c_all) / C.crit_factor(c0)
    return {"hit": hit, "dexcrit": 1.0, "critench": critench, "speed": speed, "crit": (c0, c_all),
            "blow": total / (hit * critench * speed)}


def scout_tables():
    out = ["### Where the Scout's extra comes from", "",
           "Level 60, the full damage set against plain item-level-60 gear, split into "
           "factors that multiply to the set's gain. \"Hit\": weapon and attribute on the "
           "hit (Strike for the Warrior, full-draw Loose for the Scout); \"crit from "
           "Dexterity\": the set's Dexterity at 0.05 points of Crit each; \"Mighty Blow\": "
           "the Warrior's rage hit adds a fixed `floor(1.5 W) − W` that no Strength "
           "raises, so it dilutes his gain.", "",
           "| Item level | Class | Hit | Crit from Dexterity | Crit enchants | Attack speed "
           "| Mighty Blow | Crit chance | Set |",
           "|---:|---|---:|---:|---:|---:|---:|---|---:|"]
    for ilvl in (60, 65, 70):
        for cls, fn in (("Warrior", warrior_parts), ("Scout", scout_parts)):
            p = fn(60, ilvl, 60)
            blow = p.get("blow", 1.0)
            total = p["hit"] * p["dexcrit"] * p["critench"] * p["speed"] * blow
            out.append("| %d | %s | ×%.3f | ×%.3f | ×%.3f | ×%.3f | ×%.3f | %.1f → %.1f %% | %s |" % (
                ilvl, cls, p["hit"], p["dexcrit"], p["critench"], p["speed"], blow,
                100 * p["crit"][0], 100 * p["crit"][1], pct(total - 1)))

    out += ["", "### Dexterity curve candidates", "",
            "`value = round(a + b L + c L²)`, at least 1, L = the enchant's item level "
            "(item_tiers.md §1.1). Scout set as above (Warrior: +33.5 / +40.2 / +47.0 / "
            "+57.4 / +69.4 %). \"Scout Dex\": one enchant's damage gain against the "
            "check's target; \"rider\": a Warrior's, Mage's or Priest's dodge from one "
            "Dexterity enchant as a share of a Dodge enchant, item level 60.", "",
            "| Curve | Dex at 10 / 20 / 30 / 40 / 50 / 60 / 65 / 70 | Scout set 30 / 45 / 60 / 65 / 70 "
            "| Scout Dex T6 top / T7 70 (target 4.0 / 4.4) | Rider at 60 | Class check |",
            "|---|---|---|---|---:|---|"]
    candidates = (("today: 0.8 + 0.13 L + 0.0019 L²", DEX_TODAY, None),
                  ("**proposed: c = 0.0011**", DEX_PROPOSED, None),
                  ("c = 0.0012", (0.8, 0.13, 0.0012, 0, 1), None),
                  ("c = 0.0010", (0.8, 0.13, 0.0010, 0, 1), None),
                  ("c = 0.0015", (0.8, 0.13, 0.0015, 0, 1), None),
                  ("today, Dexterity stops at item level 60", DEX_TODAY, 60))
    for label, curve, stop in candidates:
        def row():
            orig = S.enchant_value

            def capped(stat, ilvl, tier):
                if stat == "dex" and stop:
                    ilvl = min(ilvl, stop)
                return orig(stat, ilvl, tier)

            S.enchant_value = capped
            try:
                vals = [ev("dex", L) for L in (10, 20, 30, 40, 50, 60, 65, 70)]
                sets = [set_gains(lv, il)[1] for lv, il in SET_POINTS]
                g60 = M.gain(M.scout_dps, 60, 60, "dex", ev("dex", 60))
                g70 = M.gain(M.scout_dps, 60, 70, "dex", ev("dex", 70))
                rider = 0.1 * ev("dex", 60) / ev("dodge_percent", 60)
                _, problems = S.class_check()
            finally:
                S.enchant_value = orig
            return vals, sets, g60, g70, rider, problems
        vals, sets, g60, g70, rider, problems = with_dex(curve, row)
        out.append("| %s | %s | %s | %.1f / %.1f | %.2f | %s |" % (
            label, " / ".join(str(v) for v in vals),
            " / ".join("%+.1f" % (100 * s) for s in sets), 100 * g60, 100 * g70, rider,
            "pass" if not problems else "%d spread failures" % len(problems)))
    out += ["", "Plain bases (vendor and crafted item levels 3 / 10 / 20 / 30 / 40 / 50), "
            "today → proposed: " + " / ".join(
                "%d → %d" % (with_dex(DEX_TODAY, lambda il=il: ev("dex", il)),
                             with_dex(DEX_PROPOSED, lambda il=il: ev("dex", il)))
                for il in C.BASE_ILVL) + "."]
    return out


# --- spell rounding ------------------------------------------------------------

def talent(percent, level):
    """get_talent_bonus for a level-scaled damage key: value * B(L) / 100."""
    return percent * base_hit(level) / 100


def spells(level, int_total):
    """(name, raw before the scalar, today's pre-scalar value)."""
    b = bw(level)
    power = int_total / 10.0
    rnd = lambda x: math.floor(x + 0.5)  # spell_damage_value at 0 % timed spell damage
    out = [("Fireball", b + power, None),
           ("Fireball, Tinder 5/5", b + power + talent(20, level), None),
           ("Brand splash 3/3", talent(12, level) + power / 2, None),
           ("Ice Nova", (b + power) / 4, None),
           ("Ice Nova, Rimebite", (b + power) / 4 + talent(25, level) + power / 2, None),
           ("Cinderfall 3/3", talent(25, level) + power, None)]
    sm_raw = (b + power) * 1.5
    out.append(("Smite", sm_raw, rnd(math.floor(sm_raw + 0.5))))
    sw = talent(20, level)
    out.append(("Smite, Sharpened Word 5/5", sm_raw + sw, rnd(math.floor(sm_raw + 0.5) + sw)))
    out.append(("Word of Ruin 3/3", talent(30, level) + power, None))
    return [(n, raw, rnd(raw) if today is None else today) for n, raw, today in out]


def settle(level, amount):
    """scale_player_damage: one floor after the level scalar, at least 1."""
    if amount <= 0:
        return 0
    return max(1, math.floor(amount * scale(level)))


def spell_tables():
    out = ["### Spells: round before the scalar (today) or floor once after it (proposed)", "",
           "Damage after the level scalar, before crit and the target-level malus (the "
           "tooltip number). Mage spells for a Mage, Smite and Word of Ruin for a Priest, "
           "each without Intelligence gear; talents at full rank. \"Largest\": the largest "
           "difference over levels 1–60 and 0–300 Intelligence from gear.", "",
           "| Spell | L30 today → proposed | L45 today → proposed | L60 today → proposed | Largest |",
           "|---|---|---|---|---:|"]
    names = [n for n, _, _ in spells(60, 0)]
    for i, name in enumerate(names):
        cls = "priest" if name.startswith(("Smite", "Word")) else "mage"
        cells = []
        for level in (30, 45, 60):
            _, raw, today = spells(level, naked_int(cls, level))[i]
            cells.append("%d → %d" % (settle(level, today), settle(level, raw)))
        worst = 0
        for level in range(1, 61):
            for gear in range(0, 301):
                _, raw, today = spells(level, naked_int(cls, level) + gear)[i]
                worst = max(worst, abs(settle(level, today) - settle(level, raw)))
        out.append("| %s | %s | ±%d |" % (name, " | ".join(cells), worst))
    out += ["", "Loose already floors once after the scalar (Round 35); Mighty Blow and "
            "Opening floor the weapon part by design and are not changed. Charge has no "
            "pre-scalar rounding."]
    return out


def main(argv):
    what = argv[0] if argv else "all"
    parts = {"heal": heal_tables, "set": set_tables, "scout": scout_tables, "spells": spell_tables}
    if what not in parts and what != "all":
        print(__doc__)
        return 2
    lines = []
    for name in (parts if what == "all" else [what]):
        lines += parts[name]() + [""]
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
