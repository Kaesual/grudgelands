#!/usr/bin/env python3
"""Round 35 lane B: talent numbers for the user's decision (no game state).

Prints Markdown tables: every converted talent today (flat) and proposed
(percent of a level reference) at levels 10, 30 and 60 plus its anchor level,
and the level-60 figures the talent review quotes. The formulas mirror
grug_core/combat.lua (base_pool, baseline_weapon_damage, baseline_melee_total,
level_scale, armor_k) and the class growth of grug_classes/init.lua; the
portable fixture (portable_test.lua) checks the real code against the same
rule, so a drift between the two shows up there.

Usage: python3 tools/r35_b/numbers.py [conversion|review|decided]

`conversion` shows the shipped values (phase 2: Whitehot 30 % and Rimebite
25 % by the user's picks; the phase-1 proposal was 16 % and 13 %). `review`
keeps the phase-1 figures the user decided on; `decided` prints them before
and after the user's picks and the crit-cap check.
"""
import math
import sys


def P(L):  # class-neutral base pool
    return math.floor(20 + 5 * L + 0.66 * L * L + 0.5)


def bw(L):  # own-level 1H weapon (also the bow, family x1.0)
    return math.floor(4 + 0.35 * L + 0.5)


def B(L):  # a base hit before the damage scalar
    return bw(L) + (10 + 3 * (L - 1)) / 10


def scale(L):  # damage level scalar
    return P(L) / (8 * B(L))


def K(L):  # armor constant against a same-level attacker
    return 20 + 0.5 * L


def mage_sp(L):
    return (10 + 3 * (L - 1)) / 10


def priest_sp(L):
    return (10 + 2 * (L - 1)) / 10


def scout_dex10(L):
    return (10 + 2 * (L - 1)) / 10


def smite(L):
    return math.floor((bw(L) + priest_sp(L)) * 1.5 + 0.5)


def metal_set(L):  # four-piece metal line, linear through ilvl 12 -> 16, 57 -> 55
    return 16 + (L - 12) * (55 - 16) / 45


def warrior_reduction(R, L):
    return min(0.70, R / (R + K(L)))


# id, name, tier, ranks today (flat), proposed percents, unit, base (ability) fn,
# label of the base
TALENTS = [
    ("tinder", "Tinder", 1, [1, 2, 3, 4, 5], [4, 8, 12, 16, 20], "damage",
     lambda L: B(L), "Fireball"),
    ("sharpened_word", "Sharpened Word", 1, [1, 2, 3, 4, 5], [4, 8, 12, 16, 20],
     "damage", smite, "Smite"),
    ("strong_draw", "Strong Draw", 1, [1, 2, 3, 4, 5], [4, 8, 12, 16, 20],
     "damage", lambda L: bw(L) + scout_dex10(L), "Loose (bow + Dex/10)"),
    ("fine_edge", "Fine Edge", 1, [1, 2, 3, 4, 5], [4, 8, 12, 16, 20], "damage",
     lambda L: bw(L) + scout_dex10(L), "Scout sword swing"),
    ("warded_wrath", "Warded Wrath", 2, [1, 2, 3, 4], [4, 8, 12, 16], "damage",
     smite, "Smite"),
    ("brand", "Brand (base of the splash)", 3, [2, 3, 4], [6, 9, 12], "damage",
     lambda L: B(L), "Fireball"),
    ("cinderfall", "Cinderfall (base)", 3, [5, 7, 9], [15, 20, 25], "damage",
     lambda L: B(L), "Fireball"),
    ("word_of_ruin", "Word of Ruin (base)", 3, [6, 8, 10], [18, 24, 30], "damage",
     smite, "Smite"),
    ("rimebite", "Rimebite (base)", 4, [5], [25], "damage",
     lambda L: B(L) / 4, "Ice Nova"),
    ("whitehot", "Whitehot (window damage)", 4, [6], [30], "damage",
     lambda L: B(L), "Fireball"),
    ("longshot", "Longshot (hit beyond 25 m)", 4, [4], [11], "damage",
     lambda L: (bw(L) + scout_dex10(L)) * 2.25, "Loose at full draw"),
    ("ironbound", "Ironbound", 1, [1, 2, 3, 4, 5], [3, 6, 9, 12, 15], "armor",
     None, "armor rating"),
    ("unbroken", "Unbroken (emergency)", 4, [15], [33], "armor", None,
     "armor rating"),
]

ANCHOR = {1: 30, 2: 35, 3: 45, 4: 50}
FIRST = {1: 2, 2: 12, 3: 26, 4: 42}  # first level a rank can be held
LEVELS = [10, 30, 60]


def reference(unit, L):
    return K(L) if unit == "armor" else B(L)


def fmt(x):
    return ("%.1f" % x).rstrip("0").rstrip(".") if abs(x) < 100 else "%d" % round(x)


def per_rank(values, L, unit, percent):
    out = []
    for v in values:
        raw = v * reference(unit, L) / 100 if percent else v
        out.append(fmt(raw * scale(L)) if unit == "damage" else fmt(raw))
    return " / ".join(out)


def conversion():
    print("| Talent | Tier (held from) | Anchor | Level | Today per rank | "
          "Proposed per rank | Today, full ranks | Proposed, full ranks |")
    print("|---|---|---|---|---|---|---|---|")
    for tid, name, tier, today, prop, unit, base, label in TALENTS:
        first = True
        levels = sorted(set(LEVELS + [ANCHOR[tier]]))
        for L in levels:
            reach = L >= FIRST[tier]
            t_full = today[-1]
            p_full = prop[-1] * reference(unit, L) / 100
            if unit == "damage":
                t_txt = "+%s (%.0f%% of %s)" % (fmt(t_full * scale(L)), 100 * t_full / base(L), label)
                p_txt = "+%s (%.0f%%)" % (fmt(p_full * scale(L)), 100 * p_full / base(L))
            else:
                # Unbroken's emergency rating is added after its x1.65.
                R = 2 * metal_set(L) * (1.65 if tid == "unbroken" else 1)
                t_txt = "+%s rating (%.0f%% of K); reduction %.1f%% -> %.1f%%" % (
                    fmt(t_full), 100 * t_full / K(L), 100 * warrior_reduction(R, L),
                    100 * warrior_reduction(R + t_full, L))
                p_txt = "+%s rating (%g%% of K); %.1f%% -> %.1f%%" % (
                    fmt(p_full), prop[-1], 100 * warrior_reduction(R, L),
                    100 * warrior_reduction(R + p_full, L))
            lvl = "L%d" % L
            if L == ANCHOR[tier]:
                lvl = "**L%d**" % L
            if not reach:
                lvl += " (not reachable)"
            cells = [name if first else "",
                     ("T%d (L%d)" % (tier, FIRST[tier])) if first else "",
                     ("L%d: %s %%" % (ANCHOR[tier], " / ".join("%g" % p for p in prop))) if first else "",
                     lvl, per_rank(today, L, unit, False), per_rank(prop, L, unit, True),
                     t_txt, p_txt]
            print("| " + " | ".join(cells) + " |")
            first = False


def review():
    print("| Level | P(L) | base hit raw B | scalar | base hit effective | K(L) | "
          "plate+shield rating | reduction | x1.65 (Unbroken) |")
    print("|---|---|---|---|---|---|---|---|---|")
    for L in [10, 20, 30, 42, 50, 60]:
        R = 2 * metal_set(L)
        print("| %d | %d | %.1f | %.2f | %d | %.1f | %.0f | %.1f%% | %.1f%% |" % (
            L, P(L), B(L), scale(L), math.floor(B(L) * scale(L)), K(L), R,
            100 * warrior_reduction(R, L), 100 * warrior_reduction(1.65 * R, L)))
    print()
    for L in [30, 60]:
        print("### Level %d (same-level normal mob, own-level gear, no enchants)" % L)
        print()
        rows = []
        # Warrior: Strike every second, Mighty Blow whenever 25 rage is there.
        strength = (10 + 3 * (L - 1)) / 10
        dex_w = 10 + (L - 1)
        crit_w = 0.05 + 0.0005 * dex_w

        def warrior_dps(stoke=0, spite=0, heavy=0, crit=0.0):
            income = 8 + stoke + 3 + spite  # one swing and one hit taken per second
            f = min(1.0, income / 25)
            mb = math.floor(bw(L) * (1.5 + 0.05 * heavy)) + strength
            return (B(L) + f * (mb - B(L))) * (1 + min(0.30, crit_w + crit))
        base = warrior_dps()
        rows.append(("Warrior", "baseline raw/s (Strike + Mighty Blow, crit)", "%.1f" % base))
        for label, kw in [("Heavy Hand 5/5", dict(heavy=5)), ("Stoke 4/4", dict(stoke=4)),
                          ("Spite 5/5", dict(spite=5)), ("Keen Edge 5/5", dict(crit=0.05))]:
            rows.append(("Warrior", label, "%+.1f%% DPS" % (100 * (warrior_dps(**kw) / base - 1))))
        rui = 10 * B(L) * 0.20 / 120  # ten swings at +20 crit points each 120 s
        rows.append(("Warrior", "Ruination (capstone)", "%+.1f%% DPS" % (100 * rui / base)))
        R = 2 * metal_set(L)
        red = warrior_reduction(R, L)
        ehp = lambda r: 1 / (1 - r)
        rows.append(("Warrior", "plate+shield reduction", "%.1f%%" % (100 * red)))
        rows.append(("Warrior", "Ironbound 5/5 (proposed) EHP",
                     "%+.1f%%" % (100 * (ehp(warrior_reduction(R + 0.15 * K(L), L)) / ehp(red) - 1))))
        rows.append(("Warrior", "Unbroken x1.65 EHP vs same level",
                     "%+.1f%%" % (100 * (ehp(warrior_reduction(1.65 * R, L)) / ehp(red) - 1))))
        Kb = 50 + 8.5 * 10  # a level-70 dragon
        boss = lambda r: min(0.70, r / (r + Kb))
        rows.append(("Warrior", "Unbroken x1.65 EHP vs a level-70 dragon",
                     "%+.1f%% (%.0f%% -> %.0f%%)" % (100 * (ehp(boss(1.65 * R)) / ehp(boss(R)) - 1),
                                                    100 * boss(R), 100 * boss(1.65 * R))))
        rows.append(("Warrior", "Weathered 4/4 EHP", "+6.0%"))
        hold = 0.40 * P(L)
        incoming = math.floor(P(L) / 27) * (1 - red)
        rows.append(("Warrior", "Hold Ground 3/3 absorb vs one mob's hits",
                     "%d absorb = %.0f s of one mob" % (hold, hold / incoming)))
        # Mage: Fireball each second while mana lasts.
        sp_m = mage_sp(L)
        regen = lambda pool, cf=0: max(0.25 * (1 + 0.15 * L), 0.0025 * pool) * (1 + 2 * cf)
        cost = round(0.06 * P(L))
        oom = lambda pool, cf=0, c=cost: pool / (c - regen(pool, cf))
        t0 = oom(P(L))
        rows.append(("Mage", "Fireball casts before out of mana", "%.1f s" % t0))
        rows.append(("Mage", "Deep Well 5/5 time to OOM", "%+.0f%%" % (100 * (oom(1.15 * P(L)) / t0 - 1))))
        rows.append(("Mage", "Cold Focus 5/5 time to OOM", "%+.0f%%" % (100 * (oom(P(L), 0.5) / t0 - 1))))
        rows.append(("Mage", "Tinder 5/5 (proposed)", "+20%% of a base hit = %+.0f%% Fireball" % (100 * 0.2 * B(L) / B(L))))
        crit_m = 0.05 + 0.0005 * (10 + (L - 1))
        rows.append(("Mage", "Firebrand 4/4", "%+.1f%% DPS" % (100 * 0.04 / (1 + crit_m))))
        wh = 8 * 0.16 * B(L) / 120
        rows.append(("Mage", "Whitehot (capstone): damage / mana per 120 s",
                     "%+.1f%% DPS; saves %.0f%% of the pool" % (100 * wh / B(L), 8 * 3)))
        rb = (0.13 * B(L) + sp_m / 2) / 12
        rows.append(("Mage", "Rimebite (capstone), one target", "%+.1f%% DPS" % (100 * rb / B(L))))
        cf = 0.25 * B(L) + sp_m
        rows.append(("Mage", "Cinderfall 3/3 per target (proposed)", "%.0f%% of a Fireball, 2x its mana" % (100 * cf / B(L))))
        rows.append(("Mage", "Glacial Ward 3/3", "%.0f%% of Mage HP per 30 s" % (100 * 0.20 * (1 + sp_m / 100) / 0.9)))
        # Priest
        sp_p = priest_sp(L)
        sm = smite(L)
        rows.append(("Priest", "Smite raw / cast (2 s)", "%d" % sm))
        rows.append(("Priest", "Swift Word 4/4 (2 s -> 1.4 s)", "%+.0f%% Smite DPS, %+.0f%% mana per second" % (100 * (2 / 1.4 - 1), 100 * (2 / 1.4 - 1))))
        rows.append(("Priest", "Sharpened Word 5/5 (proposed)", "%+.0f%% Smite" % (100 * 0.2 * B(L) / sm)))
        cloth = 2.3 + 0.222 * L
        inc_p = math.floor(P(L) / 27) * (1 - cloth / (cloth + K(L)))
        rec = 0.12 * P(L) * (1 + sp_p / 100)
        rows.append(("Priest", "Recompense 3/3 absorb per Smite vs one mob",
                     "%d per 2 s = %.0f%% of the mob's %d per 2 s" % (rec, 100 * rec / (2 * inc_p), 2 * inc_p)))
        mend = 4 * 0.10 * P(L) * (1 + sp_p / 100)
        heal = 0.30 * P(L) * (1 + sp_p / 100)
        rows.append(("Priest", "Mend 3/3 vs Heal (Gentle Hand 5/5): heal per mana",
                     "%.1f vs %.1f" % (mend / round(0.06 * P(L)), heal / round(0.08 * P(L)))))
        wor = 0.30 * B(L) + sp_p
        wor_eff = wor * scale(L)
        rows.append(("Priest", "Last Word (capstone): extra healing per 180 s",
                     "%d HP = %.0f%% of Priest HP" % (wor_eff, 100 * wor_eff / P(L))))
        # Scout
        dex_s = scout_dex10(L)
        arrow = bw(L) + dex_s
        loose = arrow * 2.25 / 2.5
        rows.append(("Scout", "Loose full draw raw/s (2.5 s)", "%.1f (%.0f%% of Strike)" % (loose, 100 * loose / B(L))))
        rows.append(("Scout", "Fletching 4/4 (1.5 s)", "%+.0f%% Loose DPS" % (100 * (2.5 / 1.5 - 1))))
        rows.append(("Scout", "Twin Shot 3/3", "+70% per full draw, two arrows"))
        q = (arrow + 0.2 * B(L)) * 2.25 * 1.7 / 1.5
        rows.append(("Scout", "Quarry draw chain (Strong Draw, Fletching, Twin Shot)",
                     "%.1f raw/s = %.1fx a warrior's %.1f" % (q, q / base, base)))
        sword = bw(L) + dex_s
        op = math.floor(bw(L) * 2.8) + dex_s - sword
        rows.append(("Scout", "Opening 3/3 + Follow Through 3/3 from behind",
                     "%+.0f%% melee DPS when it lands" % (100 * op / 6 / sword)))
        dodge = 0.001 * (10 + 2 * (L - 1))
        rows.append(("Scout", "base dodge; Light Step 5/5 + Shifting Weight 3/3",
                     "%.1f%% -> %.1f%%" % (100 * dodge, 100 * min(0.30, dodge + 0.08))))
        print("| Class | Figure | Value |")
        print("|---|---|---|")
        for r in rows:
            print("| %s | %s | %s |" % r)
        print()


def decided():
    """The review figures the user's phase-2 picks change, before -> after."""
    print("| Level | Figure | Before (phase 1) | After (picked) |")
    print("|---|---|---|---|")
    for L in (30, 60):
        strength = (10 + 3 * (L - 1)) / 10
        crit_w = 0.05 + 0.0005 * (10 + (L - 1))

        def warrior(heavy_step, heavy=0, crit=0.0):
            f = min(1.0, 11 / 25)
            mb = math.floor(bw(L) * (1.5 + heavy_step * heavy)) + strength
            return (B(L) + f * (mb - B(L))) * (1 + min(0.30, crit_w + crit))
        base = warrior(0)
        row = lambda fig, a, b: print("| %d | %s | %s | %s |" % (L, fig, a, b))
        row("Heavy Hand 5/5", "%+.1f%% DPS" % (100 * (warrior(0.05, 5) / base - 1)),
            "%+.1f%% DPS" % (100 * (warrior(0.10, 5) / base - 1)))
        row("Keen Edge 5/5", "%+.1f%% DPS" % (100 * (warrior(0, crit=0.05) / base - 1)),
            "%+.1f%% DPS" % (100 * (warrior(0, crit=0.10) / base - 1)))
        arrow = bw(L) + scout_dex10(L)
        q_old = (arrow + 0.2 * B(L)) * 2.25 * 1.7 / 1.5
        q_new = (arrow + 0.2 * B(L)) * 2.25 * 1.6 / 2.0
        row("Quarry draw chain vs a Warrior", "%.1f raw/s = %.1fx" % (q_old, q_old / base),
            "%.1f raw/s = %.1fx" % (q_new, q_new / base))
        cloth = 2.3 + 0.222 * L
        inc = math.floor(P(L) / 27) * (1 - cloth / (cloth + K(L)))
        rec = 0.12 * P(L) * (1 + priest_sp(L) / 100)
        row("Recompense 3/3 vs one mob's damage", "%.0f%% (every Smite, 2 s)" % (100 * rec / (2 * inc)),
            "%.0f%% (at most every 6 s)" % (100 * rec / (6 * inc)))
        row("Swift Word 4/4", "+43% Smite rate", "+25% Smite rate")
        rui_old, rui_new = 10 * 0.20 / 120, 15 * 0.20 / 60
        row("Ruination", "%+.1f%% DPS" % (100 * rui_old * B(L) / base), "%+.1f%% DPS" % (100 * rui_new * B(L) / base))
        if L >= 42:
            wh_old, wh_new = 8 * 0.16 / 120, 8 * 0.30 / 60
            row("Whitehot", "%+.1f%% DPS, 24%% of the pool per 120 s" % (100 * wh_old),
                "%+.1f%% DPS, 24%% of the pool per 60 s" % (100 * wh_new))
            sp = mage_sp(L)
            row("Rimebite, one target", "%+.1f%% DPS" % (100 * (0.13 * B(L) + sp / 2) / 12 / B(L)),
                "%+.1f%% DPS" % (100 * (0.25 * B(L) + sp / 2) / 12 / B(L)))
            wor = (0.30 * B(L) + priest_sp(L)) * scale(L)
            row("Last Word per trigger (extra healing)", "%d HP = %.0f%% of HP" % (wor, 100 * wor / P(L)),
                "%d HP = %.0f%% of HP (a second cast drains 150%%)" % (2.5 * wor, 250 * wor / P(L)))
        row("Hardened 3/3", "+0.9% HP", "+6% HP")
        row("Weathered 4/4", "+6% HP", "+10% HP")
        row("Cold Focus 5/5 time to OOM", "%+.0f%%" % (100 * (oom_time(L, 1.0, 0.5) - 1)),
            "%+.0f%%" % (100 * (oom_time(L, 1.0, 1.0) - 1)))
        row("Charge damage (after the scalar)", "%.1f" % (3 * scale(L)), "%.1f" % (0.12 * B(L) * scale(L)))
    print()
    print("Crit with full crit enchants at level 60 (two Crit enchants of the damage set, item level 60 / 70;")
    print("Elixir of Precision VI +8.6):")
    print()
    print("| Class | Base (Dex) | + 2 Crit enchants | + talent (2/rank) | + Elixir VI |")
    print("|---|---|---|---|---|")
    for cls, dex, talent in (("Warrior", 69, 10), ("Mage", 69, 8), ("Priest", 69, 10),
                             ("Scout (Dex on all eight items)", 128 + 8 * 15, 8)):
        base = 5 + 0.05 * dex
        print("| %s | %.1f %% | %.1f / %.1f %% | %.1f / %.1f %% | %.1f / %.1f %% (cap 30) |" % (
            cls, base, base + 8.6, base + 9.6, base + 8.6 + talent, base + 9.6 + talent,
            base + 8.6 + talent + 8.6, base + 9.6 + talent + 8.6))


def oom_time(L, pool_mult, cold_focus):
    """Time to empty at one Fireball per second, relative to no talent."""
    def t(pool, cf):
        regen = max(0.25 * (1 + 0.15 * L), 0.0025 * pool) * (1 + 2 * cf)
        return pool / (round(0.06 * P(L)) - regen)
    return t(pool_mult * P(L), cold_focus) / t(P(L), 0)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "conversion"
    {"conversion": conversion, "review": review, "decided": decided}[what]()
