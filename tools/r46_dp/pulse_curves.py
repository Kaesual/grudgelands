#!/usr/bin/env python3
"""Round 46 lane DP, design note: offline numbers for the depth pulse.

Estimates only (no engine run). Prints, per depth, the depth level, the
arrival rate under each start-depth option, the per-player cap options, the
time share spent fighting arrivals and the kill-equivalents per hour a player
at depth-level parity would earn from arrivals alone.

Assumptions (stated, not measured):
  * depth_level is the shipped term (grug_mapgen/wp40/zones.lua depth_level);
  * one arrival takes SECONDS_PER_KILL to kill at parity (8 hits per
    same-level mob by construction, combat_stats.md section 2, at about 1 s a
    hit, plus the approach);
  * lane XP's rule (round46-plan.md ruling 5): a same-level kill is 1 KE.

Usage: python3 tools/r46_dp/pulse_curves.py
"""

SECONDS_PER_KILL = 10.0
R_MAX = 6.0

OPTIONS = {
    # name: (Y0, SPAN) -> rate = min(R_MAX, max(0, (-y - Y0) * R_MAX / SPAN))
    "S1 WP34 (-300)": (300, 1700),
    "S2 (-100)": (100, 1900),
    "S3 (-40)": (40, 1960),
}

DEPTHS = [-40, -100, -150, -200, -300, -400, -500, -700, -1000, -1500, -2000]


def depth_level(y):
    if y <= -992:
        return 60
    numerator = -3 * y
    base = numerator // 50
    value = base + 1 if numerator - base * 50 >= 25 else base
    return max(1, min(60, value))


def rate(y, y0, span):
    return min(R_MAX, max(0.0, (-y - y0) * R_MAX / span))


def cap_by_band(y):
    """C2: the cap steps with the tool tiers (T2-T3 / T4-T5 / T6)."""
    if y > -500:
        return 2
    if y > -1000:
        return 4
    return 6


def main():
    names = list(OPTIONS)
    print("Arrivals per minute (and mean seconds between arrivals)")
    print("%7s %5s " % ("y", "lvl") + " ".join("%17s" % n for n in names)
          + " %6s" % "capC2")
    for y in DEPTHS:
        cells = []
        for n in names:
            r = rate(y, *OPTIONS[n])
            cells.append("%6.2f (%5s s)" % (r, "%.0f" % (60 / r) if r > 0 else "-"))
        print("%7d %5d " % (y, depth_level(y)) + " ".join("%17s" % c for c in cells)
              + " %6d" % cap_by_band(y))
    print()
    print("At depth-level parity (player level = depth level, d = 0):")
    print("fight share = rate x %.0f s / 60 s; KE/h = rate x 60 (1 KE per kill)"
          % SECONDS_PER_KILL)
    print("%7s %5s " % ("y", "lvl") + " ".join("%17s" % n for n in names))
    for y in DEPTHS:
        cells = []
        for n in names:
            r = rate(y, *OPTIONS[n])
            cells.append("%3.0f %% / %4.0f KE/h" % (min(100, r * SECONDS_PER_KILL / 60 * 100),
                                                 r * 60))
        print("%7d %5d " % (y, depth_level(y)) + " ".join("%17s" % c for c in cells))
    print()
    print("Reference: designed levelling pace about 65 KE/h; own-level grinding")
    print("100-200 KE/h (research-xp-quests.md section 2). No XP above level 60.")
    print()
    # Telegraph particle budget per arrival (proposal in the note).
    windup = 2 * 12  # two 1 s spawners of 12 (particles.lua clamps time to 1 s)
    burst = 8        # the body appears
    fade = 8         # an arrival that lost its target phases out
    print("Particles: wind-up %d + arrival %d = %d per arrival over about 2.3 s;"
          % (windup, burst, windup + burst))
    print("fade-out %d; at most one wind-up pending per player, so <= %d per"
          % (fade, windup + burst + fade))
    print("player at once; ten deep players in one cave <= %d."
          % (10 * (windup + burst + fade)))


if __name__ == "__main__":
    main()
