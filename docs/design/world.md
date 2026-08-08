# World Design

Decided spec (2026-08-05/06; continent redesign 2026-08-06). Implementation:
WP2 (mapgen, difficulty function, build restrictions), WP18 (continent
rework), WP6 (guards/outposts), WP13 (structures, villages); housing/Home
Stone get their own WPs when scheduled.

## 0. Canonical names

Decided 2026-08-06 (rename from the placeholder faction names). These
names are canonical for docs, code and content — do not reintroduce the
old ones.

| Thing | Display name | Internal id |
|-------|--------------|-------------|
| Southern faction | **The Accord** | `accord` |
| Northern faction | **The Throng** | `throng` |
| Southern continent (Accord homeland) | **Elandor** | `elandor` * |
| Northern continent (Throng homeland) | **Kragmar** | `kragmar` * |

\* The two continent ids are **reserved, not yet used in code**: today a
continent is only the sign of z (`grug_core.territory_at`). Use them if
and when a continent ever becomes a first-class id.

- In running prose the factions take the article: *the Accord*, *the
  Throng*; the full form "The Accord" is for titles and UI labels.
- Continent names are **independent of the faction names** — Elandor and
  Kragmar are places, and stay correct even if a faction is driven off
  its homeland in later story content.
- **Naming philosophy**: the faction names are *semantic* — an Accord is
  a pact between unlike peoples, a Throng is a mass that moves as one.
  The continent names are *phonetic* — melodic, vowel-rich Elandor in
  the south versus harsh, consonantal Kragmar in the north, so the map
  sounds like its cultures before a player reads a single quest.
- **Phase 3 (localization) note**: the German display names are "das
  Bündnis" (The Accord) and "die Meute" (The Throng); continent names
  stay untranslated. Docs remain English — this is recorded here only so
  the translation layer has a canonical source.

## 1. Geography: two continents

The world map is **two huge, separate islands — one continent per
faction** (WoW's two-continent memory): **Kragmar** in the north, home
of the Throng, and **Elandor** in the south, home of the Accord,
mirrored at z=0. Everything else is ocean.

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
  straight-edge continents, no mountain wall (the old x=±2000 wall was
  dropped in WP18; a post-generation ocean mask carves the coast instead).
- Each continent contains 3 race-flavored biome regions (section 7).
- **Fixed base layout, randomized within**: which race region lies in
  which compass direction is FIXED per faction (section 7); noise only
  jitters region borders and coastlines.
- **Civilization gradient** (decided 2026-08-06): the safe core + inner
  ring carry the settled race biomes (villages, roads, fields); outward
  every race band tips into its **wild nature variant** — shared nature
  biomes that exist on BOTH continents with identical base drops
  (section 8). **Made binding 2026-08-08**: a **carve box** of
  |x| ≤ 800, 600 ≤ |z| ≤ 1200 per continent (~20 % of the land) is
  reserved for the settled bands — no wild band may be *registered*
  there at all, and the centre band may not reach into the side
  capitals' ground. That is what turns the gradient from a tendency
  into a guarantee (§3); §8's "wild patches near the core" flavour is
  what it costs, and this settles the contradiction between the two
  sections in favour of the guarantee.
- All anchors (capital position, ring radii, coast caps) derive from the
  continent size constants in `grug_core` — world size is configurable at
  world creation (3000×1600 default; changing it requires a new world).

### Difficulty layout: "safe core + war coast"

Decided 2026-08-06. Two **decoupled** level fields, both centralized in
`grug_core`:

**Mob level** (`mob_level_at` — where you level): radial distance from
the **continent seat** (~(0, ±900)), with a per-direction cap, plus a
**level-1 bubble around every capital** (see below). Overworld caves add a
depth axis on top (combat_stats.md §3: level also grows 3 levels per 50
nodes below y=0 — the safe core is only safe on the surface, depth already
overtakes it at −83):

| Zone | Location | Mob level |
|------|----------|-----------|
| Capital bubble | ≤ 40 nodes from any of the six capital anchors (§3) | **1**, blending back into the field by 240 nodes |
| Safe core | x-elongated belt (≈ ±600 × ±300): the three race capitals (§3; the central one is the faction seat) | 1–10 |
| Inner ring | core edge … ~550 from the capital | 10–25 |
| Outer ring | ~550 … toward flank/back coasts | 25–45 |
| Flank & back coasts | shorelines at x≈±1500 / z≈±1700 | 45–60, elites |
| **War coast** (strait-facing band, z ≈ ±100…±300) | capped at | **~20–30**; outposts, first PvP quests (min level ~20) |
| Strait & beaches | z 0 … ±100 | lvl 1–5 neutral wildlife |

**The capital bubble** (decided with WP36, after a runtime report). The
radial field is centred on the continent *seat*, not on each capital, so
only the two central capitals (human/orc, x = 0) sat at field value n ≈ 0.
The four side capitals (dwarf/elf/undead/troll, x = ±550) sit at n = 0.217,
which the field reads as **level 8** — `zone_at` answered "core" there while
a fresh level-1 player's first neighbour was a level-8 boar (55 HP,
5.2 damage, against 30 player HP). Fix, inside `mob_level_at` only:

- **Level 1 within 40 nodes** of any of the six capital anchors (the spawn
  platform is 25×25, so the whole camp and a wide apron are level 1).
- **Linear blend back to the ambient field over the next 200 nodes**, fully
  restored at 240 nodes. 200 nodes is the width the "no jumps > 5" rule of
  biomes_mobs.md §1.5 needs: the steepest walk out of a side capital climbs
  1 → 17.6 across it, i.e. under 1 level per 10 nodes.
- **Lowering only** — a bubble never raises a level, and outside 240 nodes
  the field is bit-identical to what it was.
- It is a term of the *radial* part: the war-coast/strait caps and, above
  all, the **depth floor** still run afterwards. Caves under a capital are
  not level 1 — at y = −200 every capital reads level 11, exactly as before.
  Below the capitals the depth axis alone now decides at all six (the side
  capitals used to read a flat 8 down to −140).
- The radial field itself is deliberately **not** re-shaped: `zone_at`, the
  guard field, the 24 outpost anchors and the 12 bandit-camp anchors keep
  their values to the node. `difficulty_at` is the one derived quantity that
  necessarily moves, because it is *defined* as (mob level − 1)/59: inside a
  bubble it now reads 0. Nothing consumes it yet.

**Guard level** (`guard_level_at` — anti-invasion gating; the field exists
since WP18, the guards that read it arrive with WP6): runs
**inverse** to mob level — elite city watch (60+) in the capital, spawn
village and safe core, solid guards at villages/roads, moderate at the
war coast (~local mob level +5). Rationale: the safe core must be safe
against high-level *invaders*, not just low-level mobs; pushing deeper
means weaker mobs but ever harder guards (classic WoW capitals).

- Invasion is funneled by design: the strait leads to the enemy's
  mid-level war coast (the PvP stage); landings at flank/back coasts
  fail against lvl 50–60 zones — scoped to |z| ≳ 450 (decided with
  WP18): the war-coast cap fades continuously over z 300..600, so the
  flank corners nearest the strait ramp 30→60 instead of being elite.
  A landing that comes in slightly wide of the war coast still lands
  next to the PvP stage, which is the funnel working as intended; any
  x-dependent cap would reintroduce a level cliff at the band edge.
  Nether crossings (Phase 2) are the endgame deep strike into the
  hinterland.
- Players level 1–15 play deep inland — no forced early PvP; quests
  first send players to the war coast at ~lvl 20+.

## 2. Destructibility

Rationale: free digging/building would break guard gating (tunneling),
elite mobs (pillar cheese) and territory borders. One territorial rule:

- **R1 — Own faction territory**: digging and building allowed at any
  depth, except in protected zones (capital, outposts, villages, quest
  structures, small radius around spawn).
  - **Shape of a POI protection zone**: vertically it starts **30 nodes
    below the POI's base level and runs upward without a limit** — nobody
    towers over a capital, nobody tunnels in from directly beneath it,
    while deep mining below the POI stays free. Horizontally the zone
    belongs to the POI: the placeholder **spawn platforms protect only
    their own footprint** (the terrain right next to them must stay
    diggable — a terrain-adaptive platform can end up against a hillside
    and a player has to be able to dig out), while **villages, outposts
    and the real capitals (WP13 structures) also protect ≥ 10 nodes of
    surrounding terrain** in x/z.
  - **POI registry** (`grug_core.add_poi{id, x, z, half, y_base}`, WP6):
    every non-capital protected structure registers itself here instead
    of hard-coding a zone. `half` is the **final** x/z half-extent —
    the ≥ 10 nodes of surround are already included by the caller, the
    registry adds nothing; `y_base` is the ground height the **mapgen**
    resolved for that structure, so the registry entry is also the
    persisted height decision every later mapchunk slice reads back.
    The whole registry lives in mod storage (idempotent by id) and is
    scanned by the central `core.is_protected`, applying the vertical
    rule above (`POI_PROTECT_DEPTH` = 30 below `y_base`, then upward
    without limit). Anchors whose terrain comes out flooded or too steep
    are **skipped** — best effort, the minimum of §9 is a promise about
    the layout, not about every single coordinate.
- **R2 — Enemy territory**: no digging, no node placement of any kind —
  **including torches, ladders etc.** Items remain usable. Darkness and
  danger in enemy land are a feature.
- **R3 — Ocean**: everything outside the two continent rectangles
  (strait, coastal ocean, open sea) is locked for everyone — no digging,
  no placement. Each faction can only build INSIDE its own continent
  rectangle. Sole exception: the player housing isles (R5, section 5).
- **R4 — Nothing regrows** (decided 2026-08-08): ores and resources do
  **not** respawn. A mined-out vein is gone, everywhere, for good. The
  world does not run dry because **depth supplies without bound** (R6,
  §5.3, `combat_stats.md` §3) — the price of a material is paid in danger
  and travel, never in waiting for a timer. Renewable ore would have
  capped every material's value at its respawn interval and turned mining
  into a rotation instead of an expedition. **Sole exception: renewable
  nodes inside indestructible structures**, where the walls are protected
  (R1) and no player can build a farm around the node. In the MVP that
  exception is **exactly one structure kind: the mining camps** of §4.
  - **10–15 renewable resource nodes per camp**, in the **tier of the
    camp's own region** (§2 R6 / `items_crafting.md` §3.0.1) — so a camp
    is where a player gets T3 stock without a −400 expedition, and the
    camp's garrison is the price.
  - **Respawn 2–4 hours per node**, not minutes. A camp is a destination
    worth a trip every few sessions, never a farm rotation; the interval
    is deliberately an order of magnitude above the 15–30 min the removed
    world-wide mechanic used, because a handful of nodes at a guarded
    place is a different thing from a vein under every hill.
  - Other POI kinds may join the exception later, one renewable node type
    per kind, once camps have proven the shape. Nothing else regrows
    today.
- **R5 — Housing isles**: a housing isle's 100×100 build
  box belongs to its **owner, a character rather than a guild** (§5):
  the owner and the characters on their *trusted* list build and dig
  there down to the purchased depth, everyone else may look and not
  touch. A guild owns no land anywhere (`guilds.md` §3).
- **R6 — Rock strata** (decided 2026-08-07): below the surface the stone
  is layered into **six strata, one per material tier**, with boundaries
  at **−100 / −300 / −500 / −700 / −1000 / bedrock**. A stratum can only
  be broken by a tool of its own tier or better (engine mechanism: the
  node's `level` group against the tool's `groupcaps.maxlevel`). Depth
  — and with it the whole metal ladder — is therefore gated by the tool
  a character can already make, not by a rule the server has to police.
  **The layering is identical on the continent and on the housing
  isles**: on the continent the tool tier alone gates you, on an isle
  you need the tool tier **and** the purchased depth step (§5.3). The
  six tiers and their materials live in `items_crafting.md`.
  - The strata are, top to bottom, **`default:stone` (T1 — the ordinary
    world stone *is* the first stratum, no new node), then
    `grug_materials:slate`, `:basalt`, `:granite`, `:emberrock` and
    `:abyssal_rock`** down to bedrock.
  - **Every stratum drops ordinary cobble.** The gate is about *access*,
    not about building material — the build economy of this section does
    not end at −100.
  - **Cave walls inherit their stratum**, so a deep cave is not a free
    bypass: walking into a cave at −600 does not hand a low-level
    character rock or ore they could not have dug from above.
- **No per-player land claims in the MVP**: open-world builds are "at
  your own risk"; the protected build space is your own housing isle
  (§5). Revisit only if griefing becomes a real problem.

Implementation: one central `core.is_protected` override in `grug_core`
(faction + position check).

## 2b. Ocean zones & deep-sea danger

The ocean is layered by distance from the nearest land — and since
2026-08-07 "land" includes the housing isles (§5), so every isle carries
its own coastal ring:

- **Coastal sea** (~1500 nodes around each continent, **150 nodes around
  each housing isle**): guaranteed real ocean — the terrain generates,
  but it MUST be water, no islands. This is the **reef band** and active
  gameplay space: coral, kelp, fish and harmless-to-low-level shore
  wildlife (decided 2026-08-07; the biome registration and its roster
  land with the ocean-content WP, biomes_mobs.md §1.2).
- **Open sea (beyond the coastal band)**: deliberately deadly. Massively
  oversized high-level guard mobs that one-shot anything — the **Kraken
  Guard** (lvl 100, no drops, no XP) ships with WP18, gated on
  `grug_core.open_sea_at`. **Deep-sea creatures also destroy boats**
  (decided 2026-08-07): no boat item exists yet, but the rule is binding
  for whoever adds one — otherwise a boat turns the deterrent into a
  ferry. Players are not meant to reach the world edge, and not meant to
  travel between housing isles by sea.
- **The housing band** (|z| ≥ 4000 behind each continent, §5.6) is open
  sea with allocated isles punched into it: deadly water between the
  isles, safe inside each isle's 150-node ring. **`open_sea_at` must
  therefore answer false inside those rings** — today it is a pure
  distance-from-the-continent test (`OCEAN_COASTAL_WIDTH` 1500, so open
  sea starts at |z| = 3200) and would happily spawn Kraken Guards on
  somebody's beach.
- **The strait between the continents is NOT extra dangerous** — danger
  only guards the places players are not supposed to go, never the
  faction-vs-faction crossing.

## 3. Capitals

**Three race capitals per continent** (decided 2026-08-06, WoW model):
each race's capital sits in the safe-core belt of its band, centrally
in the race's own biome, and is protected (indestructible) per the POI
rule of §2 — the structure plus ≥ 10 nodes of surrounding terrain, from
30 nodes below its base level upward. The
**central race's capital (Humans/Orcs, ~(0, ±900)) doubles as the
faction seat**: the faction King (raid boss), guild manager, and
faction-wide services live there.

**"In the race's own biome" is a guarantee, not a hope (decided
2026-08-08).** It used to be neither enforced nor true: on a random
seed the intended biome won at the anchor in 22–63 % of cases at four
of the six capitals — the human capital came up deep forest, the dwarf
capital meadows, undead and troll savanna. What ships now:

- **Guaranteed radius R = 200.** In the whole ±200 box around every one
  of the six anchors, exactly **one** biome is registered — the race's
  own. Verified over 200 random seeds at 100 %.
- **How**: geometry, not climate tuning. The engine filters biome
  cuboids on the raw integer position *before* it reads heat/humidity
  (`BiomeGenOriginal::calcBiomeFromNoise`), so a containment argument is
  seed-proof, while the climate at a capital is effectively a coin flip
  of the seed (spread 1000 over a 3000×1600 continent leaves only ~5
  independent large-octave samples per continent — even collapsing every
  settled point onto the noise mean scored 0 % at four capitals, and the
  engine's `weight` knob tops out at 56–94 % while distorting shares
  everywhere else).
- **The carve box** (§1) pushes the four wild side bands out to
  |x| ≥ 801, moves the badlands/deep-forest back country to |z| ≥ 1201,
  narrows the centre band to |x| ≤ 349 over its whole z range, and lets
  the side settled bands reach in to |x| ≥ 201.
  R = min(800 − 550, 550 − 350) = 200; the theoretical maximum is 274,
  because two neighbouring capitals are only 550 apart. Registration
  detail and the resulting biome table: `biomes_mobs.md` §1.3.
  The centre band first shipped as three slabs (a narrow belt inside the
  box, full-width front and back slabs outside it) to keep the wide
  centre↔side overlaps; that was **rolled back the same day** because the
  slabs' four new cuboid faces cost 1 500 nodes of straight ground border
  — three quarters of the whole regression the carve caused. Only the
  deep forest still needs slabs, because only it needs a hole in the
  middle of its cuboid. See the D4 note in `biomes_mobs.md` §1.3 before
  re-proposing them.
- **No coverage hole**: the narrowed centre band without the side-band
  extension to |x| ≥ 201 would leave 5 % of the land with no eligible
  biome at all, which generates as bare stone (measured negative control:
  478 799 land columns). Verified on the shipped registrations: **0** land
  columns without a biome, at every y from 4 to 31000.
- **Accepted residual (D5)**: `grug_swamp` (y 1..6) and `grug_beach`
  (y 1..4) are universal, x/z-unlimited and are **not** carved. A
  capital whose terrain surface lands at y ≤ 6 can therefore still come
  up swamp or beach — measured at ~30 % of the box at y 5–6 and ~75 % at
  y 4. Accepted rather than split both into z-slabs as well: the camp
  platform sits at the engine spawn level and our terrain baseline is
  lifted ~6–10 nodes above sea level, so a capital that low is a corner
  case, and the cost would be six more registrations plus their deco
  lists.

Each capital contains:

- The **spawn point for characters of its race** — players start (and
  respawn) in their own race's capital.
- Class trainers + class POIs (e.g. special quest NPCs à la mount
  unlocks).
- Traders, quest givers, job trainers.
- A waypoint of the travel network (section 6).
- Elite guards — a capital raid is a Phase-2+ group event, not a solo
  gank. **Real since WP6**: each spawn platform carries a **guard
  banner** node that keeps 2–3 faction guards standing on it, and
  because the capitals sit in zone `core` the guard field floors them at
  60 → every capital guard is an automatic elite (scale, tint,
  telegraph). Capital banners get **no patrol leg** — that garrison
  holds the platform. The faction **King** sits in the faction seat as a
  heavily guarded raid boss with top-tier loot rolls (see items/crafting
  design); his **bodyguards are character-bound** — they follow him,
  run free while he is dead, and are replaced by a fresh set when he
  respawns (binding model: §4a). To his OWN faction he is the **liege
  who grants the housing isles** (§5, decided 2026-08-07): the level-30
  housing questline ends at his throne, which is the one time a player
  meets their own King as something other than the enemy's raid target.
- Race flair through architecture and NPCs (per-race wood/build sets,
  biomes_mobs.md §5; elven capital = treehouses). Mechanical race perks hang
  on individual vendors (§7).

## 4. Outposts & patrols

Military outposts across each territory enforce the level gating:

- Roles: guard spawner/anchor, quest hub, graveyard/respawn point for the
  own faction, protector of resource-rich mining sites (e.g. a dwarven
  mining camp — resource site + conflict point in one). Such a site is
  **world content, not a purchasable claim**: it is guarded, never owned,
  and anyone who fights past the garrison may dig it (guilds hold no
  land — `guilds.md` §3). Under R4 a **mining camp is the only place in
  the world where anything regrows at all**, precisely because its
  structure is indestructible: 10–15 renewable nodes in the region's own
  material tier on a 2–4 h respawn (numbers and rationale in §2 R4).
  That is what makes such a camp a travel destination and a conflict
  point rather than scenery — and it is why a camp needs a garrison worth
  fighting. **Mining camps do not exist as a structure yet** — this
  section has so far named them only as a *role* an outpost can carry;
  authoring them (schematic, garrison, protection footprint) belongs to
  the world-structures package.
- **Guard level follows the inverse guard field** (`guard_level_at`,
  section 1): elite garrisons in the core, ~local mob level +5 at the
  war coast — guards beat equal-level intruders; groups or higher-level
  players can push through. A guard at level ≥ 60 is automatically an
  elite (scale/tint/telegraph, combat_stats.md §3).
- **The guaranteed minimum is FOUR outposts per race band** — one per
  ring — i.e. **24 in the world** (6 bands × 4). All are deterministic,
  derived from the band's capital anchor (`grug_core.outpost_anchors`):
  they sit at the capital's own x, at |z| = **250** (war coast), **500**
  (inner) and **1350** (outer); the **coast** post goes to the band's
  own shoreline — the two flank bands to x = **±1350** at the capital's
  z, the centre band to the back shore at |z| = **1550**. An anchor whose
  terrain resolves flooded or too steep is skipped (best-effort, §9).
  Anything denser than this minimum — the old "roughly one outpost per
  ring per ~500 m east–west" — is the job of WP13's patch/settlement
  pass (biomes_mobs.md §1.4), not of the guaranteed layout.
- Between outposts: **ambient patrols** on the same guard field — closes
  the "just walk around the outpost" hole. One guard per post is
  designated **patroller** and walks the leg toward the next ring inward
  (coast → outer → inner → war coast, and the war-coast post walks back
  inward so the chain has no dead end); the designation rotates
  **hourly**. The patroller is exempt from the leash's evade-home rule —
  being far from its post is the whole point.
- **Guards attack enemy players and monsters, never other NPCs**
  (`attack_npcs = false`): a deliberate MVP simplification, so faction
  NPC brawls cannot start themselves. Own-faction and *factionless*
  players (brand-new characters still on the spawn platform) are vetoed
  during target acquisition.
- **Rare patrol mobs**: some areas have hard-to-kill rare mobs with
  limited/low spawn rates and special loot — a deliberate incentive for
  cross-faction raids (loot details: items/crafting design).

### 4a. NPC binding & respawn slots (decided 2026-08-07)

Every stationary NPC population (outpost guards, capital watch, bandit/
mirefolk camps, later miners, king bodyguards, …) follows ONE model:

- **Place-bound NPCs** are bound to their anchor (guard banner, camp
  fire, mine, platform): after losing aggro they **evade home** —
  untouchable, running at 1.5× run speed, normal again on arrival;
  a blocked walk falls back to a teleport snap after ~40 s
  (combat_stats.md §4 carries the full evade rule) — and while idle
  they **roam only a small radius around it** — **20 nodes**,
  horizontal, enforced as a gentle steer home once a second while the
  NPC is idle. The patroller role is the one designed exception.
- **Character-bound NPCs** (the king's bodyguards, later escort NPCs)
  are bound to a character instead of a place: they follow their
  character wherever it goes while it lives. When the character dies
  they become **unbound** (roam free where they stand); when the
  character respawns, the old bodyguards **despawn** and it comes back
  with a fresh set. (Spec now; implementation lands with the King/raid
  WP.)
- **Respawn slots**: every anchor has a configured **maximum population**
  and refills toward it one NPC at a time. Each refill takes a
  **configurable interval** (either an exact duration or a min–max
  range rolled per refill). Slots are independent: if 2 of 4 bodyguards
  die, exactly 2 refills queue up. Intervals in force today:
  bandit/mirefolk camps **120–300 s** per slot (biomes_mobs.md §4),
  guard posts **180–360 s** — clearing an outpost buys a while of open
  road. A **freshly generated** anchor owes its full garrison from the
  moment it exists, so a camp nobody has visited yet is manned when the
  first player walks up.
- **Dormant catch-up** (the Luanti reality: no timers tick in unloaded
  areas): the anchor keeps its **slot timestamps in persistent state**
  (node meta / entity state), not in running timers. When the area
  activates again, the anchor computes how many refills the elapsed
  time has earned and spawns them **immediately**, and the remainder
  continues on the normal interval. Example (interval 7 min): 3 guards
  died 15 min ago in a since-dormant area → on the next player's
  arrival 2 spawn at once (⌊15/7⌋), the third ~6 min later. The clock is
  **world time** (it runs while players are elsewhere, stands still
  while the server is off) and it starts when the anchor **notices** the
  death — an anchor cannot count losses in an area nobody was in.

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

## 4c. The T6 band below −1000 is endgame territory (decided 2026-08-08)

**The deepest stratum is content, not only a material tier.** Below
**−1000** the rock is Abyssal Rock (§2 R6, `items_crafting.md` §3.0.4)
and nothing but a **T6 tool** breaks it, so the band is unreachable
until the very top of the material ladder. That makes it the one region
of the world whose *entry requirement* is endgame by construction — the
same role §4b's apex bosses fill by level, expressed as a depth instead
of as a boss, which is why the rule lives next to them and not in §2:
§2 R6 owns **who may break the rock**, this section owns **what is down
there waiting**.

**Decided: the band's role is to carry endgame content** — dangerous
underground *environments*, the worked example being **lava lakes**,
together with a creature roster appropriate to the players who can get
there. The depth axis has always been the "alternative progression path
to travelling out" (`combat_stats.md` §3); below −1000 it stops being
only a resource axis and becomes a destination, so that the last pick on
the ladder buys a place to go and not merely a harder wall.

Two constraints the content has to respect, both already decided
elsewhere:

- **Regular mobs still cap at level 60** (`combat_stats.md` §3). What
  makes the band deadly is the environment and the **rate of arrival**,
  not bigger numbers — a level-60 roster under permanent pressure, never
  a level-80 one. The rate itself is the **depth phase-in pulse**, and
  it is a spawn rule: it lives in `biomes_mobs.md` §4.1, which also owns
  the roster the pulse delivers below −1000.
- **This is a continental band, not an isle one.** A housing isle runs
  through the same six strata (§5.3) but is protected, private and free
  of hostile spawns (§5.6); an isle's step 6 buys **treasure** (§5.4),
  the continent's −1000 buys **danger**. The two must not converge, or
  the isle becomes the safe way to farm the deep band.

**Lava lakes are a `register_on_generated` VoxelManip pass** (decided
2026-08-08), next to the continent ocean mask
(`grug_mapgen/ocean_mask_mapgen.lua`, in the mapgen environment since
WP36) and the camp platforms (`grug_mapgen/structures.lua`, main
environment) — pure voxel work with no need of `grug_core`, mod storage
or the POI registry belongs in the mapgen env — plus **cheap
`ore_type = "blob"` lava pockets** in `group:grug_stratum` rock for
ambience. Only a pass can express what the worked example actually
promises — a *flat, connected* lava surface with an air dome over it and
a shore to stand on; a blob has no shape control and yields pockets, not
lakes. The pass carries a **chunk-box fast path** so it costs nothing
above −1000, the way the ocean mask already skips inland chunks.

A *deep biome* buys less here than it looks like it does, which is why
it is not the mechanism: the six strata are **stratum ores registered
last** and convert `default:stone` wholesale (`items_crafting.md`
§3.0.4), so a biome's own `node_stone` would simply be overwritten and
only its cave/decoration layer would survive.

**No apex boss of its own in the MVP** (decided 2026-08-08). The band
carries itself on the phase-in roster, the lava lakes and its resource
density. §4b's apex bosses are deliberately **visible outdoor carrots**
— the Mountain Wyrm is a thing you see at level 8 and fight at 50 — and
a boss behind a T6 pickaxe is the exact opposite of that, so a deep apex
is not the same design object under a different sky. It arrives later as
its own §4b stage, once the band has content at all; the lair/hoard/
arena tech is generic and waits. Authoring the zone and its boss at the
same time would mean inventing both against nothing.

**The band gets no drop layer of its own.** What it pays out is raw
material; its creatures drop exactly what their families drop everywhere
else, and being deep adds nothing to a loot table (`items_crafting.md`
§5, which carries the argument).

## 5. Housing: the King's isles (player-owned)

Decided 2026-08-07 — replaces the guild-owned ocean plots of the
2026-08-06 continent redesign. **Fiction first**: beyond the coastal sea
behind each continent lies a scattered chain of unspoiled isles, barren
above the rock and rich below it. The **King grants one isle to subjects
who have earned merit** — housing is *unlocked by a questline* with
`min_level` **30** (story.md §2), never bought. Rationale: housing used
to be pure mechanics with no reason to exist in the world; tying it to
the crown also gives the own faction's King his first friendly role
(§3).

### 5.1 Ownership & the isle

- **One isle per character** (changed 2026-08-07 from per-guild; guilds
  keep the bank and the roles — `guilds.md`). Granted is granted: no
  upkeep, no decay, no way to lose it.
- **Build box: 100 × 100 nodes in x/z, from the purchased depth to the
  sky.** The box IS the extent of the build and dig right (§2 R5), which
  keeps `is_protected` a plain box test on a hot path.
- **Free digging down to the seabed plane at y = −30** — that is the
  isle's own worthless body. Everything below it is bought (§5.3).
- A **skirt of ~50 nodes radius** falls from the box edge to the seabed.
  The skirt is scenery and is protected for **everyone including the
  owner**: isles keep their silhouette seen from the water, and nobody
  floods their own cellar by landscaping the shoreline.
- **Teleport pad**: a small indestructible platform on the isle's
  continent-facing shore, protected as its own footprint from 5 below to
  6 above — deliberately NOT the unlimited-upward POI rule of §2, or the
  owner could never roof it over. The pad is a waypoint of the travel
  network (§6) and the only intended way in or out.

### 5.2 Isle styles

A **one-time style choice** when the isle is granted. Styles differ in
surface palette, vegetation and skirt profile only — **the resource
content below the seabed is identical**, so no style is the good one:

| Style | Look | Skirt |
|---|---|---|
| Coral Shore | white sand, palms, shallow reef | gentle |
| Pinecrag | grey stone, conifers, boulder fields | steep |
| Ashen Rock | black volcanic rock, basalt columns, sparse growth | steep, cliffed |
| Mistwood | dark soil, gravewood, heavy undergrowth | gentle |

Re-styling an existing isle for gold is a reserved Phase-2 sink, not MVP.

### 5.3 Depth rights — the central gold sink

The only paid axis (x/z is a gift — you do not buy land from your
liege). **Six steps, one per rock stratum** (revised 2026-08-07 from ten
steps of 50 nodes to −530): every step opens exactly the stratum that
the matching tool tier can break, so an isle's ladder and the
continent's are the same six layers (§2 R6).

| Step | Opens down to | Rock tier | Price |
|---|---|---|---|
| free | −30 (the seabed) | — | — |
| 1 | −100 | T1 | 50c |
| 2 | −300 | T2 | 2s |
| 3 | −500 | T3 | 6s |
| 4 | −700 | T4 | 20s |
| 5 | −1000 | T5 | 60s |
| 6 | bedrock | T6 | **1g** |

≈ **1.9 g for the full ladder**. **Both gates apply and neither
substitutes for the other**: a bought step is worthless without a tool
of that tier, and a T6 pick digs nothing on an isle whose step 6 is
unpaid. Against a lifetime income to level 60 of
about 1 g and endgame farming of 6–12 s/h (items_crafting.md §8), the
first steps are reachable soon after the level-30 grant and the last are
a genuine endgame fortune — the ladder deliberately outlives the level
cap. Bought steps are permanent.

This price table is the same one in `economy.md` §4.1 and
`items_crafting.md` §8.4 — the three must not drift apart.

The isle is built by a VoxelManip pass, which does not get the strata
for free the way the continent does (they ride on the mapgen's ore
stage, §2 R6) — the generator asks
`grug_materials.stratum_node_for(y)` for the rock of a depth and places
it itself, so the two ladders cannot drift apart.

### 5.4 What is down there: treasure clusters, not a mine

**Housing mining is a treasure hunt, not a second ore economy** (decided
2026-08-07, **re-affirmed and made generous 2026-08-08**). The
continental depth axis — ores by biome and depth, cave mobs scaling 3
levels per 50 nodes (combat_stats.md §3) — stays the world's mining
game, and a safe private isle must not undercut it by selling the same
ore without the danger.

**Why the shape, and not a continental ore field**: an isle is 100×100
and runs from the seabed at −30 to bedrock, i.e. **~9.7 million nodes**.
At continental ore density that is tens of thousands of ore nodes on
protected (R5), mob-free, PvP-free, travel-free ground — an owner would
never mine the continent again, and the whole depth danger of §4c would
be a rule that applies to other people. The second argument is the
sink's own: the depth ladder is the game's central gold sink (§5.3), and
**a sink must pay out a known amount**. An ore field pays out whatever
the seed felt like.

- The isle's rock is **barren between the clusters**. Each depth step
  holds a **fixed, deterministic set of clusters** — positions rolled
  per isle, count and contents identical for everyone. A step is
  therefore a *calculable payout*, which is what makes its price
  balanceable at all. The count does **not** scale with a stratum's
  height: a deeper step costs more because its clusters carry a higher
  material tier, not because it holds more of them.
- **The clusters are deliberately generous** (2026-08-08): the
  2026-08-07 working value of 8 clusters × 20–40 nodes is a floor, not a
  target, and each step's clusters are filled **in that step's own rock
  tier** (§5.3). Every bought step has to read as a real payday for the
  gold it cost — that, not an ore field, is how "mining an isle is worth
  it" is delivered. The exact count and fill per step is authored in the
  housing package against the price ladder above.
- **No respawn** (R4, the world-wide rule): a mined-out cluster is gone.
  That is precisely why the ladder keeps costing — the next payout is the
  next step.
- Contents follow the strata (§5.3): steps 1–3 ordinary building and
  smithing stock, steps 4–5 the deep metals and their gems, **step 6
  Abyssal Crystal**, the T6 material and the race-signature ingredient
  (items_crafting.md §4 / §5.5). Since 2026-08-08 the crystal also has a
  continental deposit below −1000 (items_crafting.md §3.0.1), so the
  isle is the *safe* source of it, no longer the only one — what the
  ladder sells exclusively is the six materials below.
- **Six isle-exclusive materials, one per depth step** (decided
  2026-08-08). Each step additionally holds **one rare material that
  exists nowhere else in the world** — not on the continent, not in any
  drop table. Non-renewable like everything else on an isle (R4: an isle
  is editable ground, so nothing regrows there), and reserved for
  special recipes. This is what gives the 1.9 g ladder a reason to exist
  of its own now that the T6 alloy is no longer hostage to it.
  - **All six are named, textured and placed; exactly one of them does
    anything in the MVP** — the **Amplifier**, applicable **once per
    item**, raising **all of that item's prefix and suffix values by
    10 %** (`items_crafting.md` §6b.8 owns the effect and its rules).
  - The other five are visible, collectable forerunners. Placing them
    now and wiring their recipes later is what keeps every future
    material addition **out of mapgen**: the isles already hold the
    stock, so a later recipe package needs no world change and no
    regenerated isle.
- **Finder items are mandatory infrastructure, not flavor**: a step is
  100×100 nodes wide and up to 300 deep, and nobody strip-mines millions
  of them. From
  the moment housing unlocks, vendors sell a cheap **Dowsing Rod**
  (nearest un-mined cluster within 64 m, direction only, 30 s cooldown);
  the **Goldsmith** profession crafts the better **Gem Detector**
  (longer range, distance readout) — one of that profession's two
  reasons to exist (professions.md §2).

### 5.5 Access rights

Two grantable levels, managed by the owner at the pad:

| Level | May | Who |
|---|---|---|
| Visitor | enter, look | own guild members automatically, plus a per-character whitelist |
| Trusted | build, dig, open containers | per-character whitelist only; implies Visitor |
| Owner | everything, both lists, buys depth steps | the grantee |

- Deliberately **guild-wide for visiting, character-wise for trust**:
  "who may see my isle" is a social question, "who may empty my chests"
  is a friendship question. There is one toggle, not three — trust
  covers building, digging and containers together.
- **One documented exception**: the guild-bank terminal (`guilds.md`
  §3.1) is usable by every guild member standing on the isle regardless of
  trust level, subject to the guild's own role rules.

### 5.6 Placement & generation

- Isles sit on a **deterministic allocation grid**: one slot per
  **1000 × 1000** cell in the housing band (|z| ≥ 4000 behind the own
  continent). Slot index → coordinates is a computation, never a search.
- The band's seabed is flat at **y = −30**, which makes generation cheap:
  the mapgen pass fills only the skirt cone and the isle body, and only
  where the registry marks a slot **allocated**. An unallocated slot
  generates as plain ocean — the same VoxelManip cap-and-flood pattern
  the continent mask already uses everywhere else (WP18).
  *Implementation note*: Luanti generates deterministically from the
  seed, so an isle cannot appear in chunks that were already emerged as
  ocean. Either skip such slots at allocation time or accept a one-time
  forced regeneration of those few chunks.
- **1000 nodes of pitch minus the 150-node safe ring ⇒ ≥ 700 nodes of
  deadly open water between neighbours.** Swimming to the isle next door
  is a long trip through §2b's deep sea, and that is the point: isles are
  reached by waypoint, not by water.
- No hostile spawns, no PvP, and **no workbenches, trainers or vendors**
  on isles (inventory_equipment.md §4 keeps workbenches in capitals and
  villages) — the isles must not become a substitute capital.

### 5.7 Farming on the isle: cooking ingredients only (decided 2026-08-08)

- **A player may farm on their own isle.** It is protected ground (§2
  R5) inside the owner's own build box (§5.1), which makes it the one
  place in the world where a planted crop is safe from somebody else's
  spade — so the isle is where farming belongs, and the isle grant is
  what hands a character a field.
- **Only cooking ingredients grow there.** That is exactly the `[food]`
  and `[spice Tn]` lines of `biomes_mobs.md` §2 — potatoes, corn,
  apples, berries, melon, plus the three spices sunleaf, marshbloom and
  stormkelp — and nothing else.
- **Never the healing herbs.** Gravemoss, dragonweed and crimson lotus
  are Alchemist-gathered and **never farmable, anywhere**
  (`biomes_mobs.md` §2): they grow on bare stone, gravel, mesa clay,
  dead-wood litter and jungle floor — ground no plough touches — and
  that is what keeps every healing herb bound to a journey into its own
  biome. A private isle must not become the shortcut around that.
- **Never the found-only ingredients.** Mushrooms, wild cocoa and rock
  salt stay found in the world (`biomes_mobs.md` §2), so the top of the
  cooking ladder stays a reason to travel — T6 cooking needs
  level-50+ ingredients (`items_crafting.md` §3.7) — and "find cocoa in
  the jungle" stays usable as a quest goal.
- **The restriction is on the plant set, not on who uses the harvest.**
  Spices are cooking ingredients *and* Alchemist reagents
  (`biomes_mobs.md` §2), so a farmed spice is still a spice. What an
  isle can never produce is a **healing herb** — and the Alchemist's
  tier keystones (`items_crafting.md` §2.3) and its potion recipes
  (§3.6) all call for one, so no part of the alchemy ladder becomes
  farmable.
- **Farming itself is post-MVP**: the crop layer is `BACKLOG.md`'s
  **WP32** (Phase 2), and it adapts an existing farming mod rather than
  inventing one. This section decides the *place* and the *permitted
  set*; the plant list stays `biomes_mobs.md` §2's.

## 6. Travel: waypoints & Home Stone

**Waypoint network** (Diablo/PoE model, decided 2026-08-06):

- Waypoints: spawn camp, capital, the own housing isle's pad (plus the
  pads of isles you are allowed to visit, §5.5), and
  **~1 waypoint per ring per race region** across each territory
  (density is the tuning knob for how relaxed world travel feels).
- **Unlocked by visiting, per character** (player meta); the fog-of-war
  world map (section on WP12) shows discovered waypoints.
- Teleporting works **only while standing at a waypoint**
  (waypoint → waypoint), instant and free — travel time is the cost;
  mounts stay relevant.
- **No waypoints in enemy territory** (not claimable or usable there)
  and **none in the strait/ocean** (except the housing isles' pads,
  section 5).
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
| Accord | Humans | plains/meadows |
| Accord | Dwarves | mountains/hills |
| Accord | Elves | forests |
| Throng | Orcs | savanna/badlands |
| Throng | Trolls | jungle/swamp |
| Throng | Undead | dark forest/blight |

(Own names/flavor later — no 1:1 Blizzard copies.)

- 3 races per faction = 3 biome regions per territory (satisfies the "≥2
  biomes per territory" mapgen requirement). The compass layout is FIXED
  per faction (e.g. Accord: dwarves always west) — only region borders
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
  Troll +50% out-of-combat regen · Undead ignored by zombies at night
  (unless the player attacked that zombie) · Orc +1 rage per hit taken ·
  Elf +5 m ability range (**ranged/spell abilities only** — melee abilities
  keep their own reach, `classes.md` §2b) · Human +10% quest XP. Plus **one
  race-exclusive vendor per race** (WP7). Implementation state (WP19): the
  troll regen multiplier reaches mana today and MUST be consumed by WP21's
  HP regen (rage decay is unaffected — a troll warrior only benefits from WP21
  on); the human bonus is a latent hook (`grug_classes.get_xp_bonus`)
  that activates when WP8's quests tag their XP with source="quest".
- **The vendor perk, quantified** (decided 2026-08-07 in WP7 — the perk
  was named above but never given numbers):
  - **One race-exclusive vendor per race**, standing in that race's
    capital (§3), and **only members of that race may trade there**.
    That exclusivity is what carries the perk: it is a shop the other
    five races cannot open at all, not a discount tag on a shared one.
  - **Same-race discount: 10 %** off that vendor's buy prices, rounded
    down and never below 1c. **Buy-back prices are not discounted**
    (economy.md §2 — discounting both ends would close the 25 % spread).
  - Both are the *bonus* on top of the visible passive, in line with the
    rule above that a perk must be FELT from level 1: the passive does
    the felt work, the vendor is the flavor that pays off later.
- Race-exclusive professions/recipes (e.g. only elven tailors craft the
  top mage robe): design hook now, implemented with jobs (WP10)/Phase 2.
- **No class restrictions per race in the MVP** (only 3 classes — locks
  would frustrate more than they flavor); revisit in Phase 2 with 7
  classes.
- Small race villages in the race regions (traders, flavor, later
  race-specific job trainers) — content for WP13.

## 8. Nature biomes (shared wilderness)

Decided 2026-08-06 (ring model); the full biome/mob catalog is being
specced in `biomes_mobs.md` (implementation spec for WP18 mapgen + WP6 mob
rosters).

- Nature biomes are **unsettled** (no faction NPCs except passing
  patrols), exist on **both continents with identical base drops** (base
  recipes work everywhere), and are the designated **quest wilderness**
  ("go into the adjacent jungle and kill a snake").
- Placement follows the difficulty rings: each race band's outer part IS
  its nature variant (dwarven pine hills → high crags; elven forest →
  deep forest; troll jungle edge → deep jungle …). Difficulty and biome
  reinforce each other: jungle/high mountains are high-level BY
  POSITION. **Since 2026-08-08 no nature biome is registered inside the
  carve box** (§1/§3): wild patches start outside |x| ≤ 800,
  600 ≤ |z| ≤ 1200, not "anywhere, thinning inward".
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
- **Race-biome patches across the band** (section 8, catalog: biomes_mobs.md): high
  chance of a small village/settlement with NPCs per patch, lower
  chance of a military outpost — settlements thin out and level up
  with the rings.
- 1 **flavor camp** in the inner ring (e.g. a race-owned miners' camp:
  small building, chests, 2–3 NPCs; doubles as the mining-zone anchor
  of section 4).
- 1 **military outpost per ring** as the guaranteed minimum — four per
  band, 24 in the world, at the deterministic anchors of section 4
  (patch outposts come on top with WP13).
- 1 **apex lair** in the outer ring (section 4b, staged).

Life measures (cheap on a voxel budget): named NPCs with one-liner
barks, visible patrols between the outposts that really fight nature
mobs on the way, light/smoke details, a quest board per village. Guards
and patrols fight **monsters and enemy players only** — NPC-vs-NPC is
off (`attack_npcs = false`, section 4), so the "free world life" is
guards versus wildlife, never a faction brawl starting itself.
**NPC and guard levels always match the surrounding wilderness**
(`guard_level_at` reflects the local ring).

**Drop rule (anti-litter, decided 2026-08-06)**: mobs and NPCs drop
loot ONLY when a player was involved — details in combat_stats.md §3
(player-tag flag). Faction NPCs drop only to ENEMY players (PvP kills);
a wolf slain by a guard drops nothing.
