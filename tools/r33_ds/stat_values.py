#!/usr/bin/env python3
"""Round 33 lane DS: the enchant value curves and the per-class check.

Every enchant, crafted or dropped, is worth value(stat, L) with
L = min(item level, 10 x enchant tier) (round33-plan.md section 2.3). The
curves are a + b L + c L^2 (c = 0 for most), fitted so one enchant gives about the same
relative gain within its kind for the class that wants it (section 2.9):

    target(L) = 1.6 % + 0.04 % x L    (2.0 % at L 10, 4.0 % at L 60, 4.4 % at L 70)

Usage:
  stat_values.py            print the value tables and the class check (Markdown)
  stat_values.py --check    also exit 1 when a kind spreads beyond SPREAD
"""
import argparse
import sys

import common as C
import models as M

# stat: (a, b, c, decimals, minimum): value = a + b L + c L^2, rounded
CURVES = {
    "str": (0.8, 0.15, 0.0025, 0, 1),
    "int": (0.8, 0.15, 0.0025, 0, 1),
    "dex": (0.8, 0.13, 0.0019, 0, 1),
    "crit_percent": (1.7, 0.044, 0.0, 1, 0),
    "attack_speed_percent": (1.6, 0.04, 0.0, 1, 0),
    "max_hp_percent": (1.6, 0.04, 0.0, 1, 0),
    "max_mana_percent": (2.2, 0.03, 0.0, 1, 0),
    "dodge_percent": (1.5, 0.032, 0.0, 1, 0),
    "armor_rating": (0.0, 0.08, 0.0, 1, 0.5),
}
ORDER = ("str", "dex", "int", "crit_percent", "attack_speed_percent",
         "max_hp_percent", "max_mana_percent", "dodge_percent", "armor_rating")
LABEL = {"str": "Strength", "dex": "Dexterity", "int": "Intelligence",
         "crit_percent": "Crit %", "attack_speed_percent": "Attack speed %",
         "max_hp_percent": "Max HP %", "max_mana_percent": "Max Mana %",
         "dodge_percent": "Dodge %", "armor_rating": "Armor rating"}
# Today's fixed crafted values (grug_quality ENCHANT_VALUES), for comparison.
TODAY = {"str": (2, 3, 5, 7, 9, 10), "dex": (2, 3, 5, 7, 9, 10), "int": (2, 3, 5, 7, 9, 10),
         "crit_percent": (0.5, 0.8, 1.2, 1.6, 2.0, 2.5),
         "attack_speed_percent": (4, 6, 8, 10, 12, 14),
         "max_hp_percent": (1, 2, 2, 3, 4, 5), "max_mana_percent": (1, 2, 2, 3, 4, 5),
         "dodge_percent": (0.5, 0.8, 1.2, 1.6, 2.0, 2.5), "armor_rating": (1, 2, 3, 4, 5, 6)}
SPREAD = 1.35  # tolerated max/min ratio inside one kind ("roughly equal")


def target(level):
    return (1.6 + 0.04 * level) / 100.0


def curve_value(stat, level):
    a, b, c, decimals, minimum = CURVES[stat]
    raw = a + b * level + c * level * level
    value = C.rnd(raw * 10 ** decimals) / float(10 ** decimals)
    value = max(minimum, value)
    return int(value) if decimals == 0 else value


def enchant_value(stat, ilvl, tier):
    """The coded rule: value of an enchant of `tier` (1..7) on an item of
    `ilvl` (1..70)."""
    return curve_value(stat, max(1, min(int(ilvl), 10 * int(tier))))


def fmt(stat, value):
    return ("%d" % value) if CURVES[stat][3] == 0 else ("%.1f" % value)


def coefficient_table():
    out = ["| Stat | a | b | c | decimals | minimum |", "|---|---:|---:|---:|---:|---:|"]
    for stat in ORDER:
        a, b, c, decimals, minimum = CURVES[stat]
        out.append("| %s | %g | %g | %g | %d | %g |" % (LABEL[stat], a, b, c, decimals, minimum))
    return out


def value_tables():
    out = ["### Values at the tier tops (upgraded or found at the top)", "",
           "| Stat | Formula | T1 (10) | T2 (20) | T3 (30) | T4 (40) | T5 (50) | T6 (60) | "
           "T7 (65) | T7 (70) | Today T1 → T6 |",
           "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|"]
    for stat in ORDER:
        a, b, c, decimals, minimum = CURVES[stat]
        formula = ("%s%g × L" % (("%g + " % a) if a else "", b)) + ((" + %g × L²" % c) if c else "")
        formula += (", whole number, at least %d" % minimum) if decimals == 0 else ", one decimal"
        cells = [fmt(stat, enchant_value(stat, 10 * t, t)) for t in range(1, 7)]
        cells += [fmt(stat, enchant_value(stat, 65, 7)), fmt(stat, enchant_value(stat, 70, 7))]
        today = " / ".join(("%g" % v) for v in TODAY[stat])
        out.append("| %s | %s | %s | %s |" % (LABEL[stat], formula, " | ".join(cells), today))
    out += ["", "### Values on plain bases (vendor or crafted item level 3/10/20/30/40/50)", "",
            "| Stat | T1 (3) | T2 (10) | T3 (20) | T4 (30) | T5 (40) | T6 (50) |",
            "|---|---:|---:|---:|---:|---:|---:|"]
    for stat in ORDER:
        cells = [fmt(stat, enchant_value(stat, C.BASE_ILVL[t - 1], t)) for t in range(1, 7)]
        out.append("| %s | %s |" % (LABEL[stat], " | ".join(cells)))
    return out


# --- the class check ----------------------------------------------------------

def check_points():
    points = []
    for band in range(1, 7):
        points.append(("T%d mid" % band, band * 10 - 5, band * 10 - 5))
        points.append(("T%d top" % band, band * 10, band * 10))
    points.append(("T7 65", 60, 65))
    points.append(("T7 70", 60, 70))
    return points


def pct(x):
    return "%.1f" % (100 * x)


def class_rows(cls, level, ilvl):
    """{kind: [(label, gain)]} for one class at one point; the enchant at
    L = ilvl (found or upgraded gear at the character's level)."""
    v = lambda stat: enchant_value(stat, ilvl, C.tier_of_level(ilvl))
    rows = {}
    if cls == "warrior":
        d = lambda stat, **kw: M.gain(M.warrior_dps, level, ilvl, stat, v(stat), **kw)
        rows["damage"] = [("Str", d("str")), ("Crit", d("crit_percent")),
                          ("Attack speed", d("attack_speed_percent"))]
        rows["damage (battle axe)"] = [("Str", d("str", family="greataxe")),
                                       ("Crit", d("crit_percent", family="greataxe")),
                                       ("Attack speed", d("attack_speed_percent", family="greataxe"))]
        s = lambda stat, **kw: M.ehp_gain("warrior", level, ilvl, stat, v(stat), **kw)
        rows["survival"] = [("HP", s("max_hp_percent")), ("Armor (2H)", s("armor_rating")),
                            ("Armor (shield)", s("armor_rating", shield=True)),
                            ("Armor (shield, foe +5)", s("armor_rating", shield=True,
                                                         attacker=level + 5))]
        rows["Dex rider"] = [("Dex → damage", d("dex")), ("Dex → EHP", s("dex"))]
    elif cls == "scout":
        d = lambda stat: M.gain(M.scout_dps, level, ilvl, stat, v(stat))
        rows["damage"] = [("Dex", d("dex")), ("Crit", d("crit_percent")),
                          ("Attack speed", d("attack_speed_percent"))]
        s = lambda stat: M.ehp_gain("scout", level, ilvl, stat, v(stat))
        rows["survival"] = [("HP", s("max_hp_percent")), ("Dodge", s("dodge_percent"))]
        rows["Dex rider"] = [("Dex → EHP", s("dex"))]
    elif cls == "mage":
        d = lambda stat: M.gain(M.mage_damage, level, ilvl, stat, v(stat))
        rows["damage"] = [("Int", d("int")), ("Crit", d("crit_percent")), ("Mana", d("max_mana_percent"))]
        rows["survival"] = [("HP", M.ehp_gain("mage", level, ilvl, "max_hp_percent", v("max_hp_percent")))]
    elif cls == "priest":
        h = lambda stat: M.gain(M.priest_healing, level, ilvl, stat, v(stat))
        d = lambda stat: M.gain(M.priest_smite, level, ilvl, stat, v(stat))
        rows["healing"] = [("Int", h("int")), ("Crit", h("crit_percent")), ("Mana", h("max_mana_percent"))]
        rows["damage (Smite)"] = [("Int", d("int")), ("Crit", d("crit_percent")), ("Mana", d("max_mana_percent"))]
        rows["survival"] = [("HP", M.ehp_gain("priest", level, ilvl, "max_hp_percent", v("max_hp_percent")))]
    return rows


# Kinds the spread check covers, with the stats it compares; the rest is
# reported, not checked (the documented exceptions of item_tiers.md section
# 3.4: the battle axe's flat Strength, the shield at the 70 % armor cap, the
# Dexterity rider, the Priest's healing Intelligence and Smite).
CHECKED = {("warrior", "damage"): None, ("warrior", "survival"): ("HP", "Armor (2H)"),
           ("scout", "damage"): None, ("scout", "survival"): None,
           ("mage", "damage"): None, ("priest", "healing"): ("Crit", "Mana")}
SPREAD_T1_MID = 1.5  # one or two attribute points cannot be finer


def class_check():
    out, problems = [], []
    for cls in ("warrior", "scout", "mage", "priest"):
        kinds = None
        lines = []
        for name, level, ilvl in check_points():
            rows = class_rows(cls, level, ilvl)
            if kinds is None:
                kinds = list(rows)
                header = ["Point", "Target"]
                for kind in kinds:
                    header += ["%s: %s" % (kind, label) for label, _ in rows[kind]]
                lines.append("| " + " | ".join(header) + " |")
                lines.append("|" + "---|" * 2 + "---:|" * (len(header) - 2))
            cells = [name, pct(target(ilvl))]
            for kind in kinds:
                cells += [pct(g) for _, g in rows[kind]]
                if (cls, kind) in CHECKED:
                    only = CHECKED[(cls, kind)]
                    gains = [g for label, g in rows[kind] if only is None or label in only]
                    limit = SPREAD_T1_MID if name == "T1 mid" else SPREAD
                    if min(gains) <= 0 or max(gains) / min(gains) > limit:
                        problems.append("%s %s at %s: %s" % (cls, kind, name,
                                                             ", ".join(pct(g) for g in gains)))
            lines.append("| " + " | ".join(cells) + " |")
        out += ["#### %s" % cls.capitalize(), "", "Gain in % of one enchant at the point's item "
                "level (damage, healing or effective HP against a same-level mob)."] + [""] + lines + [""]
    return out, problems


def dex_split():
    """Dexterity measured in other enchants: its crit and dodge points as a
    share of a Crit and a Dodge enchant of the same item level, and the
    Scout's damage from it against a Crit enchant."""
    out = ["| Item level | Dexterity | Crit points (share of a Crit enchant) | "
           "Dodge points (share of a Dodge enchant) | Scout: damage vs a Crit enchant |",
           "|---:|---:|---:|---:|---:|"]
    for ilvl in (10, 20, 30, 40, 50, 60, 70):
        tier = C.tier_of_level(ilvl)
        dex = enchant_value("dex", ilvl, tier)
        crit = enchant_value("crit_percent", ilvl, tier)
        dodge = enchant_value("dodge_percent", ilvl, tier)
        level = min(ilvl, 60)
        scout = M.gain(M.scout_dps, level, ilvl, "dex", dex) / M.gain(
            M.scout_dps, level, ilvl, "crit_percent", crit)
        out.append("| %d | %d | %.2f (%.2f) | %.1f (%.2f) | ×%.2f |" % (
            ilvl, dex, 100 * C.CRIT_PER_DEX * dex, 100 * C.CRIT_PER_DEX * dex / crit,
            0.1 * dex, 0.1 * dex / dodge, scout))
    return out


def base_change():
    """Damage or healing without gear: the new crit rules against today's."""
    import models

    def run(fn, level, per_dex, mult):
        saved = (C.CRIT_PER_DEX, C.CRIT_MULT)
        C.CRIT_PER_DEX, C.CRIT_MULT = per_dex, mult
        try:
            return fn(level, level)
        finally:
            C.CRIT_PER_DEX, C.CRIT_MULT = saved

    rows = ["| Level | Warrior | Scout | Mage | Priest (heal) | Priest (Smite) |",
            "|---:|---:|---:|---:|---:|---:|"]
    fns = (models.warrior_dps, models.scout_dps, models.mage_damage,
           models.priest_healing, models.priest_smite)
    for level in (1, 10, 30, 60):
        cells = []
        for fn in fns:
            new = run(fn, level, C.CRIT_PER_DEX, C.CRIT_MULT)
            old = run(fn, level, C.TODAY_CRIT_PER_DEX, C.TODAY_CRIT_MULT)
            cells.append("%+.1f %%" % (100 * (new / old - 1)))
        rows.append("| %d | %s |" % (level, " | ".join(cells)))
    return rows


def talent_check():
    """The shipped crit talents under the new rules: a level-60 Warrior,
    Mage or Scout without crit gear; damage gain of the talent."""
    rows = ["| Talent | Effect | Class | Gain today (×1.5) | Gain new (×2) |",
            "|---|---|---|---:|---:|"]
    base = {"warrior": 69, "mage": 69, "scout": 128}
    cases = (("Keen Edge 5/5", "+5 crit points", "warrior", 5, 30),
             ("Firebrand 4/4", "+4 crit points", "mage", 4, 30),
             ("Cold Eye 4/4", "+4 crit points", "scout", 4, 30),
             ("Ruination window", "+20 crit points, cap 50 %, 10 s per 120 s", "warrior", 20, 50))
    for name, effect, cls, pp, cap in cases:
        cells = []
        for per_dex, mult in ((C.TODAY_CRIT_PER_DEX, C.TODAY_CRIT_MULT), (C.CRIT_PER_DEX, C.CRIT_MULT)):
            crit = min(0.30, 0.05 + per_dex * base[cls])
            boosted = min(cap / 100.0, 0.05 + per_dex * base[cls] + pp / 100.0)
            cells.append("%+.1f %%" % (100 * ((1 + (mult - 1) * boosted) / (1 + (mult - 1) * crit) - 1)))
        rows.append("| %s | %s | %s | %s |" % (name, effect, cls.capitalize(), " | ".join(cells)))
    return rows


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args(argv)
    lines = value_tables()
    check, problems = class_check()
    print("\n".join(lines + [""] + check + ["", "#### Dexterity in other enchants", ""] + dex_split()
                     + ["", "#### Without gear: new crit rules against today's", ""] + base_change()
                     + ["", "#### Crit talents", ""] + talent_check()))
    if args.check:
        for line in problems:
            print("SPREAD FAIL " + line)
        print("R33 DS STAT CHECK %s (spread limit %.2f)" % ("FAIL" if problems else "PASS", SPREAD))
        return 1 if problems else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
