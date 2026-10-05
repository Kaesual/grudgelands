#!/usr/bin/env python3
"""Round 35 lane B: talent numbers for the user's decision (no game state).

Prints Markdown tables: every converted talent today (flat) and proposed
(percent of a level reference) at levels 10, 30 and 60 plus its anchor level,
and the level-60 figures the talent review quotes. The formulas mirror
grug_core/combat.lua (base_pool, baseline_weapon_damage, baseline_melee_total,
level_scale, armor_k) and the class growth of grug_classes/init.lua; the
portable fixture (portable_test.lua) checks the real code against the same
rule, so a drift between the two shows up there.

Usage: python3 tools/r35_b/numbers.py [conversion|review]
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
    ("rimebite", "Rimebite (base)", 4, [5], [13], "damage",
     lambda L: B(L) / 4, "Ice Nova"),
    ("whitehot", "Whitehot (window damage)", 4, [6], [16], "damage",
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


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "conversion"
    {"conversion": conversion, "review": review}[what]()
