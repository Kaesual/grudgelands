# World Design

Decided spec (2026-08-05/06). Implementation: WP2 (mapgen, difficulty
function, build restrictions), WP6 (guards/outposts), WP13 (structures,
villages); housing/Home Stone get their own WPs when scheduled.

## 1. Geography & difficulty rings

North = Horde territory, south = Alliance territory, mirrored at z=0.
`wow_core.difficulty_at(pos)` = distance from the border, mapped to rings:

| Zone | z-range (mirrored N/S) | Mob/guard level |
|------|------------------------|-----------------|
| Neutral borderland | −64 … +64 | lvl 1–5 neutral wildlife; PvP quest hotspot |
| Starter ring (capital at ~z=±200) | 64 … 400 | lvl 1–10 |
| Midlands | 400 … 1000 | lvl 10–30 |
| Heartland | 1000 … 1800 | lvl 30–50, elites |
| Deep heartland (raid areas, Phase 2) | 1800 … 2400 | lvl 50–60+, raid bosses |
| Housing frontier (safe zone) | beyond ±2400 | no mobs, no PvP |

- East–west: **soft world border at ~x=±2000** (ocean/mountains), so
  content density stays high and outposts can cover the width.
- Each territory contains 3 race-flavored biome regions (section 7).
- An invader crossing the border meets the enemy's weak starter zone
  first; every step deeper means stronger guards/mobs — spatial level
  gating by design.

## 2. Destructibility

Rationale: free digging/building would break guard gating (tunneling),
elite mobs (pillar cheese) and territory borders. One territorial rule:

- **R1 — Own faction territory**: digging and building allowed at any
  depth, except in protected zones (capital, outposts, villages, quest
  structures, small radius around spawn).
- **R2 — Enemy territory**: no digging, no node placement of any kind —
  **including torches, ladders etc.** Items remain usable. Darkness and
  danger in enemy land are a feature.
- **R3 — Neutral borderland**: no digging/placement for anyone (readable,
  fair PvP battlefield).
- **R4 — Ores/resources respawn** (node timers), at least in mining
  zones, so a persistent world doesn't run dry. Outpost mining zones are
  an *additional* rich-resource incentive, not the only source.
- **R5 — Housing plots**: fully freely buildable by the owner (section 5).
- **No per-player land claims in the MVP**: open-world builds are "at
  your own risk"; the protected build space is your housing plot.
  Revisit only if griefing becomes a real problem.

Implementation: one central `core.is_protected` override in `wow_core`
(faction + position check).

## 3. Capitals

One capital per faction, near the border at ~z=±200, fully protected
(indestructible). Contains:

- Faction spawn point.
- Class trainers + class POIs (e.g. special quest NPCs à la mount
  unlocks).
- Traders, quest givers, job trainers.
- Housing portal building (door/NPC teleports to the player's own plot).
- Elite guards — a capital raid is a Phase-2+ group event, not a solo
  gank. The faction **King** sits here as a heavily guarded raid boss
  with top-tier loot rolls (see items/crafting design).
- **Race districts, cosmetic only**: themed vendor/NPC groupings with
  race flair — no hard borders or district mechanics. Mechanical race
  perks hang on the individual vendor, not the district.

## 4. Outposts & patrols

Military outposts across each territory enforce the level gating:

- Roles: guard spawner/anchor, quest hub, graveyard/respawn point for the
  own faction, protector of resource-rich mining zones (e.g. a dwarven
  mining camp — resource site + conflict point in one).
- **Guard level = ring level + 5** — guards beat equal-level intruders;
  groups or higher-level players can push through.
- Between outposts: **ambient patrols** whose level also scales with
  `difficulty_at` — closes the "just walk around the outpost" hole.
- Density: roughly one outpost per ring per ~500 m east–west.
- **Rare patrol mobs**: some areas have hard-to-kill rare mobs with
  limited/low spawn rates and special loot — a deliberate incentive for
  cross-faction raids (loot details: items/crafting design).

## 5. Housing (frontier model)

A safe housing band lies beyond the deep heartland (z beyond ±2400): no
mobs, no PvP, "infinite" outward expansion.

- Plots on a **128 m tile grid** (ample expansion reserve per player).
- **Base plot 16×16**, with **mining rights ~16 nodes below the
  surface**; one plot per player (MVP).
- **Paid expansion in steps** (+8 per side or −16 depth per step, prices
  rising per step) — the central long-term gold sink.
- **Depth treasures**: greater depths hold exclusive, artificially
  limited gems/materials — ingredient source for high-end recipes (ties
  into crafting/economy).
- Only the owner can build/dig inside the plot.
- **Untouchable buffer strips** between tiles (nobody can build or dig
  there) — a wall around the plot is truly impenetrable.
- **Visitors are allowed** (plots can be entered and admired), but only
  the owner builds/digs; who wants privacy builds a wall.
- Access from the capital via the housing portal (section 3) or the Home
  Stone.

## 6. Home Stone

Teleport item/skill, so nobody is ever trapped (e.g. deep in enemy
territory):

- Two targets: a) the faction capital, b) the own housing plot.
- **3–5 s cast time; taking damage interrupts the cast** — it is not a
  combat escape.
- **No cooldown** — usable as often as desired (convenience decision,
  2026-08-06).

## 7. Races

Races are a light-weight layer: no separate starting zones or capitals
per race; instead race-flavored regions within the faction territory,
small villages, and perks around vendors/professions.

| Faction | Race | Region flavor |
|---------|------|---------------|
| Alliance | Humans | plains/meadows |
| Alliance | Dwarves | mountains/hills |
| Alliance | Elves | forests |
| Horde | Orcs | savanna/badlands |
| Horde | Trolls | jungle/swamp |
| Horde | Undead | dark forest/blight |

(Own names/flavor later — no 1:1 Blizzard copies.)

- 3 races per faction = 3 biome regions per territory (satisfies the "≥2
  biomes per territory" mapgen requirement).
- Race choice at character creation (after faction, before class), stored
  in player meta. Visuals (skins) can come later.
- MVP perks: **discount at own-race vendors + one race-exclusive vendor
  per race**.
- Race-exclusive professions/recipes (e.g. only elven tailors craft the
  top mage robe): design hook now, implemented with jobs (WP10)/Phase 2.
- **No class restrictions per race in the MVP** (only 3 classes — locks
  would frustrate more than they flavor); revisit in Phase 2 with 7
  classes.
- Small race villages in the race regions (traders, flavor, later
  race-specific job trainers) — content for WP13.
