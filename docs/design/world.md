# World Design

Decided spec (2026-08-05/06). Implementation: WP2 (mapgen, difficulty
function, build restrictions), WP6 (guards/outposts), WP13 (structures,
villages); housing/Home Stone get their own WPs when scheduled.

## 1. Geography & difficulty rings

North = Horde territory, south = Alliance territory, mirrored at z=0.
`wob_core.difficulty_at(pos)` = distance from the border, mapped to rings:

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
- **R4 — Ores/resources respawn** (node timers) in the open world, so a
  persistent world doesn't run dry. **Exception: no respawn inside guild
  mining claims and housing plots** — a claim's price buys its *finite*
  resources (`guilds.md` §3).
- **R5 — Guild property**: housing plots and mining claims are fully
  usable by all members of the owning guild, locked for everyone else
  (section 5, `guilds.md`).
- **No per-player land claims in the MVP**: open-world builds are "at
  your own risk"; the protected build space is your guild's housing
  plot. Revisit only if griefing becomes a real problem.

Implementation: one central `core.is_protected` override in `wob_core`
(faction + position check).

## 3. Capitals

One capital per faction, near the border at ~z=±200, fully protected
(indestructible). Contains:

- Faction spawn point.
- Class trainers + class POIs (e.g. special quest NPCs à la mount
  unlocks).
- Traders, quest givers, job trainers.
- A waypoint of the travel network (section 6).
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

## 5. Housing (frontier model, guild-owned)

A safe housing band lies beyond the deep heartland (z beyond ±2400): no
mobs, no PvP, "infinite" outward expansion. **Owner is always a guild**
(`guilds.md`) — a solo player founds a solo guild; groups pool housing.

- Plots on a tile grid with ample expansion reserve; **one plot per
  guild**. Bought is bought — no upkeep, no decay.
- Base plot with **mining rights below the surface**; **paid expansion
  in steps** (sides and depth, prices rising per step) — the central
  long-term gold sink. Tile reserve and step sizes are tuned so a guild
  can grow for a very long time and practically never reaches the
  maximum (numbers with the economy design,
  TODO-design-items-crafting.md §4).
- **Depth treasures**: greater depths hold exclusive, artificially
  limited gems/materials — ingredient source for high-end recipes. Like
  mining claims: **no respawn** — what is dug is gone (R4).
- All guild members build/dig inside the plot; everyone else is locked
  out.
- **Untouchable buffer strips** between tiles (nobody can build or dig
  there) — a wall around the plot is truly impenetrable.
- **Visitors are allowed** (plots can be entered and admired); who wants
  privacy builds a wall.
- Access via the plot's own waypoint (section 6).

## 6. Travel: waypoints & Home Stone

**Waypoint network** (Diablo/PoE model, decided 2026-08-06):

- Waypoints: spawn camp, capital, the own guild's housing plot, plus
  **~1 waypoint per ring per race region** across each territory
  (density is the tuning knob for how relaxed world travel feels).
- **Unlocked by visiting, per character** (player meta); the fog-of-war
  world map (section on WP12) shows discovered waypoints.
- Teleporting works **only while standing at a waypoint**
  (waypoint → waypoint), instant and free — travel time is the cost;
  mounts stay relevant.
- **No waypoints in enemy territory** (not claimable or usable there)
  and **none in the neutral borderland**.
- Phase 2 extension: **Nether crossings** link mirrored points
  (x, z) ↔ (x, −z) into enemy territory
  (TODO-design-nether.md until specced).

**Home Stone** (kept as the emergency/return valve):

- Teleport to the **own faction capital only**.
- **10 s cast time; taking damage interrupts** — not a combat escape.
- **60 min cooldown.**
- `/unstuck` (suicide command) remains the last resort for hard stuck
  states.

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
