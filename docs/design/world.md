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
- **Continent gameplay rectangle**: z = ±100 … ±1700, x = −1500 … +1500
  (3000×1600 per faction; shrunk 2026-08-06 from the 4000×2000 draft for
  a realistic population — the world should FEEL big through content
  density and travel pacing, not through emptiness). This rectangle is
  the *legal* bound (build rights, ring math); the **visible coastline
  is soft/noisy** and wanders inside it, like biome transitions — no
  straight-edge continents, no mountain wall (the old x=±2000 wall is
  dropped with WP18).
- Each continent contains 3 race-flavored biome regions (section 7).
- **Fixed base layout, randomized within**: which race region lies in
  which compass direction is FIXED per faction (section 7); noise only
  wobbles region borders and coastlines.
- **Civilization gradient** (decided 2026-08-06): the safe core + inner
  ring carry the settled race biomes (villages, roads, fields); outward
  every race band tips into its **wild nature variant** — shared nature
  biomes that exist on BOTH continents with identical base drops
  (section 8).
- All anchors (capital position, ring radii, coast caps) derive from the
  continent size constants in `wob_core` — world size is configurable at
  world creation (3000×1600 default; changing it requires a new world).

### Difficulty layout: "safe core + war coast"

Decided 2026-08-06. Two **decoupled** level fields, both centralized in
`wob_core`:

**Mob level** (`mob_level_at` — where you level): radial distance from
the capital (continent center, ~(0, ±900)), with a per-direction cap.
Overworld caves add a depth axis on top (combat_stats.md §3: level also
grows ~+1 per 20 nodes below y=0 — the safe core is only safe on the
surface):

| Zone | Location | Mob level |
|------|----------|-----------|
| Safe core | x-elongated belt (≈ ±600 × ±300): the three race capitals (§3; the central one is the faction seat) | 1–10 |
| Inner ring | core edge … ~550 from the capital | 10–25 |
| Outer ring | ~550 … toward flank/back coasts | 25–45 |
| Flank & back coasts | shorelines at x≈±1500 / z≈±1700 | 45–60, elites |
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

- **Coastal ocean (~1500 nodes around each continent)**: guaranteed real
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

**Three race capitals per continent** (decided 2026-08-06, WoW model):
each race's capital sits in the safe-core belt of its band, centrally
in the race's own biome, fully protected (indestructible). The
**central race's capital (Humans/Orcs, ~(0, ±900)) doubles as the
faction seat**: the faction King (raid boss), guild manager, and
faction-wide services live there. Each capital contains:

- The **spawn point for characters of its race** — players start (and
  respawn) in their own race's capital.
- Class trainers + class POIs (e.g. special quest NPCs à la mount
  unlocks).
- Traders, quest givers, job trainers.
- A waypoint of the travel network (section 6).
- Elite guards — a capital raid is a Phase-2+ group event, not a solo
  gank. The faction **King** sits in the faction seat as a heavily
  guarded raid boss with top-tier loot rolls (see items/crafting
  design).
- Race flair through architecture and NPCs (per-race wood/build sets,
  biomes TODO; elven capital = treehouses). Mechanical race perks hang
  on individual vendors (§7).

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

## 4b. Apex world bosses (dragons & kin)

Decided 2026-08-06 (staged; first stage is a late-Phase-1/early-Phase-2
WP). Every apex boss shares the same tech — oversized entity
(`visual_size` 4–6×), fixed lair POI with hoard chest, **stationary
arena fight** (holds its ledge, hops between ~3 fixed positions; never
kites into terrain, sidesteps pathfinding exploits), telegraphed attacks
(the elite wind-up mechanic scaled up), respawn timer — but each has a
**distinct skill set** so it threatens in its own way.

- **Stage 1 — one dragon per continent**: "the Mountain Wyrm" in the
  mountain/badlands race region at the outer ring (~lvl 50). Visible
  from far away — a progression carrot you can see at level 8 and fight
  at 50. Skill sketch: ranged breath line (`dogshoot` + telegraph) +
  ground-slam AoE.
- **Stage 2 (Phase 2) — the enemy's dragon is the flagship PvP raid**:
  killing it mounts its head in your capital + grants a temporary
  faction-wide buff — visible prestige that guarantees the retaliation
  raid.
- **Stage 3 (Phase 2+) — one apex per race region**, same code, own
  kits: e.g. jungle giant serpent (poison pools, submerges), blight bone
  colossus (knockback slam, summons adds). The dragon stays the biggest.
- **Phase 3 — the Nether dragon lord** as the demonic story capstone
  (story.md; only if the population supports larger raids).

## 5. Housing (ocean model, guild-owned)

Housing moves off-continent (continent redesign 2026-08-06): guild
housing lies **in the safe ocean beyond the coastal zone** (|z| ≳ 4000,
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
- **Each race region holds its race village inside the safe core** (the
  core is x-elongated exactly so the village belt fits, section 1); from
  its village outward through its band to its coast, every race region
  spans nearly the full progression — a player can level mostly inside
  their race's flavor region; changing biomes is an invitation, not a
  must.
- Race choice at character creation (after faction, before class), stored
  in player meta. Visuals (skins) can come later.
- MVP perks (revised 2026-08-06 — a perk must be FELT from level 1, a
  vendor discount is invisible for the first ten hours): **one visible
  passive per race** + the vendor discount as a bonus. Passives
  (implementation: WP19, race registry hook): Dwarf −20% fall damage ·
  Troll +50% out-of-combat regen · Undead ignored by zombies at night ·
  Orc +1 rage per hit taken · Elf +5 m ability range · Human +10% quest
  XP. Plus **one race-exclusive vendor per race** (WP7).
- Race-exclusive professions/recipes (e.g. only elven tailors craft the
  top mage robe): design hook now, implemented with jobs (WP10)/Phase 2.
- **No class restrictions per race in the MVP** (only 3 classes — locks
  would frustrate more than they flavor); revisit in Phase 2 with 7
  classes.
- Small race villages in the race regions (traders, flavor, later
  race-specific job trainers) — content for WP13.

## 8. Nature biomes (shared wilderness)

Decided 2026-08-06 (ring model); the full biome/mob catalog is being
specced in `TODO-design-biomes.md` (blocker for WP18 mapgen + WP6 mob
rosters).

- Nature biomes are **unsettled** (no faction NPCs except passing
  patrols), exist on **both continents with identical base drops** (base
  recipes work everywhere), and are the designated **quest wilderness**
  ("go into the adjacent jungle and kill a snake").
- Placement follows the difficulty rings: each race band's outer part IS
  its nature variant (dwarven pine hills → high crags; elven forest →
  deep forest; troll jungle edge → deep jungle …). Difficulty and biome
  reinforce each other: jungle/high mountains are high-level BY
  POSITION.
- Working level bands (final in the biome TODO): coast/beach 5–25,
  deep forest 10–30, swamp 25–40, jungle 35–55, high mountains 40–60.
- **Nature mobs are aggressive on sight against players AND NPCs**
  (patrols visibly fight wolves — free world "life").
- **Mob density is deliberately high**: target ~1 visible mob per
  15–20 m of travel in wilderness rings (per-biome spawn parameters in
  the biome TODO; the WP6 pathfinding/performance pass is the blocker
  for this density).

## 9. Settlements & world life

POI budget **per race band** (deterministic anchors + patch-driven
extras, WP13/WP18):

- 1 **race capital** in the safe core (section 3) — spawn, trainers,
  traders, waypoint; the central band's capital is the faction seat.
- **Race-biome patches across the band** (section 8/biomes TODO): high
  chance of a small village/settlement with NPCs per patch, lower
  chance of a military outpost — settlements thin out and level up
  with the rings.
- 1 **flavor camp** in the inner ring (e.g. a race-owned miners' camp:
  small building, chests, 2–3 NPCs; doubles as the mining-zone anchor
  of section 4).
- 1 **military outpost per ring** as the guaranteed minimum (section 4;
  patch outposts come on top).
- 1 **apex lair** in the outer ring (section 4b, staged).

Life measures (cheap on a voxel budget): named NPCs with one-liner
barks, visible patrols between outpost ↔ village that really fight
nature mobs on the way, light/smoke details, a quest board per village.
**NPC and guard levels always match the surrounding wilderness**
(`guard_level_at` reflects the local ring).

**Drop rule (anti-litter, decided 2026-08-06)**: mobs and NPCs drop
loot ONLY when a player was involved — details in combat_stats.md §3
(player-tag flag). Faction NPCs drop only to ENEMY players (PvP kills);
a wolf slain by a guard drops nothing.
