# Progression — Pacing, Death, Reward Cadence

Decided rules (established 2026-08-06; housing cadence integrated 2026-08-12).
Detailed quest catalogs are authored with WP8/WP9.

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
- **Level 20 — first Claim Stone:** a short introduction from the passive,
  invulnerable Housing Steward unlocks the first free owner-bound Claim Stone.
  It may be placed only in the authored level-11–30 housing zones and starts
  the non-combat home-progression line ([housing.md](housing.md) §2;
  `economy.md` §4.1).
- **Levels 35 / 50 / 60 — claim upgrades:** the same stable stone may reach
  tiers II / III / IV by paying the universal-metal and measured-income costs.
  Claims never buy mining depth or a private material source.
- **Level 60 — additional claims when enabled:** a second or third stone is an
  endgame sink gated by all existing stones being tier IV, the configured
  per-character limit and the faction live-stone capacity.

## 3. Death rules (MVP — deliberately simple)

Decided 2026-08-06; PvP exemption decided 2026-08-13; refinements
(graveyards at outposts, res sickness, Priest resurrection) come later with
WP6/WP19:

The respawn and inventory rules apply to every death; the XP consequence
depends on the death's attribution.

- Death = **respawn at the own race's safe outer starting settlement** with
  **full inventory**
  (no corpse run, no item loss, no durability-on-death mechanic).
- **PvE XP loss: 25% of the progress within the current level, permanent**
  (never de-levels; the PvE target preserves `grug_xp`'s shipped amount).
- **Confirmed PvP deaths cost no XP.** A death whose final HP-lowering
  committed transaction is attributed by the single PvP authority
  (`grug_pvp.classify_death`, WP41) to an eligible hostile player applies
  no XP loss. Every other death — PvE, environment, unclassified — keeps
  the 25% rule. Standing in contested ground or carrying the PvP tag never
  grants the exemption, and a death whose final commit is environmental
  (fall or lava after PvP damage) is unclassified and keeps the loss. The
  attribution seam belongs to WP41; the exemption is applied centrally in
  the XP death path (WP9 wiring), never by individual combat paths.
- The *distance* back is the real penalty: dying far from the spawn
  costs travel time — which scales naturally with how deep you pushed.
## 4. Quest structure & level gates

- Main-questline beats use hard `min_level` gates (`story.md`).
- First PvP quests begin in the level-31–40 contested approaches and
  Battlegrounds entry, never below level 31 (`world_zones.md` §§2/8).
- Gather and kill objectives use stable named-zone ids and authored biome/
  resource palettes so progression teaches exploration rather than old radial
  ring coordinates.
