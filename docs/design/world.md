# World Design

Decided spec (2026-08-05/06; continent redesign 2026-08-06). Implementation:
WP2 (mapgen, difficulty function, build restrictions), WP18 (continent
rework), WP6 (guards/outposts), WP13 (structures, villages); housing/Home
Stone get their own WPs when scheduled.

## 1. Geography: two continents

The world map is **two huge, separate islands — one continent per
faction** (WoW's two-continent memory). Horde in the north, Alliance in
the south, mirrored at z=0. Everything else is ocean.

- **Ocean strait along z=0**: water at least until z=±100; there the
  faction continents begin. Minimum 200 nodes of open water between the
  continents. Crossing to the enemy continent means crossing the strait
  (swimming; boats later) — the strait itself is NOT extra dangerous
  (section 2b).
- **Continent gameplay rectangle**: z = ±100 … ±2100, x = −2000 … +2000
  (4000×2000 per faction). This rectangle is the *legal* bound (build
  rights, ring math); the **visible coastline is soft/noisy** and wanders
  inside it, like biome transitions — no straight-edge continents, no
  mountain wall (the old x=±2000 wall is dropped with WP18).
- Each continent contains 3 race-flavored biome regions (section 7).
- **Fixed base layout, randomized within**: which race region lies in
  which compass direction is FIXED per faction (section 7); noise only
  wobbles region borders and coastlines.
- All anchors (capital position, ring radii, coast caps) derive from the
  continent size constants in `wob_core` — world size is configurable at
  world creation (4000×2000 default; changing it requires a new world).

### Difficulty layout: "safe core + war coast"

Decided 2026-08-06. Two **decoupled** level fields, both centralized in
`wob_core`:

**Mob level** (`mob_level_at` — where you level): radial distance from
the capital (continent center, ~(0, ±1100)), with a per-direction cap:

| Zone | Location | Mob level |
|------|----------|-----------|
| Safe core | radius ~300 around the capital (spawn village, race villages) | 1–10 |
| Inner ring | core edge … ~600 from the capital | 10–25 |
| Outer ring | ~600 … toward flank/back coasts | 25–45 |
| Flank & back coasts | shorelines at x≈±2000 / z≈±2100 | 45–60, elites |
| **War coast** (strait-facing band, z ≈ ±100…±300) | capped at | **~20–30**; outposts, first PvP quests (min level ~20) |
| Strait & beaches | z 0 … ±100 | lvl 1–5 neutral wildlife |

**Guard level** (`guard_level_at`, WP6 — anti-invasion gating): runs
**inverse** to mob level — elite city watch (60+) in the capital, spawn
village and safe core, solid guards at villages/roads, moderate at the
war coast (~local mob level +5). Rationale: the safe core must be safe
against high-level *invaders*, not just low-level mobs; pushing deeper
means weaker mobs but ever harder guards (classic WoW capitals).

- Invasion is funneled by design: the strait leads to the enemy's
  mid-level war coast (the PvP stage); landings at flank/back coasts
  fail against lvl 50–60 zones. Nether crossings (Phase 2) are the
  endgame deep strike into the hinterland.
- Players level 1–15 play deep inland — no forced early PvP; quests
  first send players to the war coast at ~lvl 20+.

## 2. Destructibility

Rationale: free digging/building would break guard gating (tunneling),
elite mobs (pillar cheese) and territory borders. One territorial rule:

- **R1 — Own faction territory**: digging and building allowed at any
  depth, except in protected zones (capital, outposts, villages, quest
  structures, small radius around spawn).
- **R2 — Enemy territory**: no digging, no node placement of any kind —
  **including torches, ladders etc.** Items remain usable. Darkness and
  danger in enemy land are a feature.
- **R3 — Ocean**: everything outside the two continent rectangles
  (strait, coastal ocean, open sea) is locked for everyone — no digging,
  no placement. Each faction can only build INSIDE its own continent
  rectangle. Sole exception: guild housing cubes (R5, section 5).
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

## 2b. Ocean zones & deep-sea danger

The ocean is layered by distance from the coast:

- **Coastal ocean (~2000 nodes around each continent)**: guaranteed real
  ocean — the terrain generates, but it MUST be water, no islands. The
  coast is active gameplay space (e.g. special farmable underwater mobs);
  content lands with its own WPs.
- **Open sea (beyond the coastal ocean)**: deliberately deadly. Massively
  oversized high-level guard mobs (lvl ~100 — e.g. giant octopuses) that
  one-shot anything. Sea travel is discouraged by design; players are not
  meant to reach the world edge or swim to housing islands.
- **The strait between the continents is NOT extra dangerous** — danger
  only guards the places players are not supposed to go, never the
  faction-vs-faction crossing.

## 3. Capitals

One capital per faction, **in the continent center** (~(0, ±1100), heart
of the safe core), fully protected (indestructible). Contains:

- The **faction spawn** sits in a small starter village right next to
  the capital (inside the safe core), not in the capital itself.
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
- **Guard level follows the inverse guard field** (`guard_level_at`,
  section 1): elite garrisons in the core, ~local mob level +5 at the
  war coast — guards beat equal-level intruders; groups or higher-level
  players can push through.
- Between outposts: **ambient patrols** on the same guard field — closes
  the "just walk around the outpost" hole.
- Density: roughly one outpost per ring per ~500 m east–west.
- **Rare patrol mobs**: some areas have hard-to-kill rare mobs with
  limited/low spawn rates and special loot — a deliberate incentive for
  cross-faction raids (loot details: items/crafting design).

## 5. Housing (ocean model, guild-owned)

Housing moves off-continent (continent redesign 2026-08-06): guild
housing lies **in the safe ocean beyond the coastal zone** (|z| ≳ 5000,
"behind" the own continent), allocated **on demand** when a guild buys
land — no mobs, no PvP, effectively unlimited reserve. **Owner is always
a guild** (`guilds.md`) — a solo player founds a solo guild; groups pool
housing.

Decided anchors (the open layout questions — one island per guild vs. a
contiguous housing shelf, sizes, access — live in
`TODO-design-housing.md` until settled):

- **One housing area per guild**, generated/allocated when bought.
  Bought is bought — no upkeep, no decay.
- **Build rights (x/z extent) and mining rights (y depth) are bought
  SEPARATELY, in paid steps** with rising prices; together they define
  the cube the guild may edit — the central long-term gold sink. A fresh
  purchase starts with a small part of a much larger reserved area
  (numbers with the economy design, TODO-design-items-crafting.md §4).
- **Depth treasures**: greater depths hold exclusive, artificially
  limited gems/materials — ingredient source for high-end recipes. Like
  mining claims: **no respawn** — what is dug is gone (R4).
- All guild members build/dig inside the cube; everyone else is locked
  out. The surrounding ocean is unbuildable for everyone (R3), so the
  safe buffer between guild areas is automatic.
- **Visitors are allowed** (areas can be entered and admired); who wants
  privacy builds a wall.
- Access via the area's own waypoint (section 6) — the deadly open sea
  (2b) is not the intended travel path.

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
  and **none in the strait/ocean** (except each guild's housing
  waypoint, section 5).
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
  biomes per territory" mapgen requirement). The compass layout is FIXED
  per faction (e.g. Alliance: dwarves always west) — only region borders
  and coastlines are noise-randomized (section 1).
- **Each race region holds its race village at the safe-core edge**;
  since the difficulty rings run ACROSS the x-bands, every band spans
  the full 1–60 progression — a player can level entirely inside their
  race's flavor region; changing biomes is an invitation, not a must.
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
