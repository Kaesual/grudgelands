# Progression — Pacing, Death, Reward Cadence

Partially decided (2026-08-06, from the design review). Quest structure
and level gates are still open — they land here before WP8/WP9.

## 1. Leveling pace

- **Level 60 in ~10–20 played hours** (2–3 evenings) — deliberately much
  faster than WoW. The endgame (PvP, apex bosses, housing, jobs) is the
  game; leveling is the on-ramp.
- Current curve (grug_xp: quadratic, ~20 same-level kills per level plus
  quests) is roughly on target; tune with playtests, not redesigns.
- **Rested XP** (WP21): logging out at an innkeeper accrues a rested
  bonus — rewards the irregular play patterns of a small server.

## 2. Reward cadence (the "new verbs" schedule)

Levels must keep delivering *decisions and buttons*, not just stats:

- **1 talent point every 3 levels** (20 points total at 60); talent
  trees hold 2 trees × 5 talents × 3 ranks = 30 ranks per class — you
  can fill two thirds: real choices, no full clear (WP11).
- **9 of 10 talents are numeric modifiers** (cheap to build, easy to
  balance); **exactly one capstone per tree**, unlocked at 8+ points in
  that tree, and **every capstone is a NEW active "main skill"** — this
  is the "new ability every ~10 levels" beat (e.g. Priest Holy capstone:
  Renew; further capstones designed with WP11).
- **Respec at the class trainer for gold**, price rising with level —
  repeatable per-character gold sink and the class trainer's purpose.
- **Level 30 — the race King's grant** (added 2026-08-07, placement revised
  2026-08-10): the housing
  questline hands over a personal isle (world.md §5). The one big
  non-combat reward beat in the curve, deliberately placed mid-run where
  talent points alone stop feeling like news, and the point from which
  gold gains a long-term purpose (economy.md §4.1).

## 3. Death rules (MVP — deliberately simple)

Decided 2026-08-06; refinements (graveyards at outposts, res sickness,
Priest resurrection) come later with WP6/WP19:

- Death = **respawn at the own race's safe outer starting settlement** with
  **full inventory**
  (no corpse run, no item loss, no durability-on-death mechanic).
- **XP loss: 25% of the progress within the current level, permanent**
  (never de-levels; grug_xp as shipped).
- The *distance* back is the real penalty: dying far from the spawn
  costs travel time — which scales naturally with how deep you pushed.
- **Open (decide before WP9):** whether PvP deaths skip the XP loss
  (leaning yes: PvP should not punish participation).

## 4. Quest structure & level gates — OPEN

To spec before WP8/WP9 (story frame: story.md): main-questline beats with hard
`min_level` gates; first PvP quests in the level-31–40 central contested
corridor, never below level 31 (`world_zones.md` §§2/8); gather/kill quests forcing named-zone
and biome exploration.
