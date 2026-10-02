# Named World Zones & PvP Geography

Decided 2026-08-10; complete named-zone pass 2026-08-11; fixed simple-map
rebase 2026-08-25; Battlegrounds naming/protection amendment 2026-08-27; R6
surface/resource decisions 2026-08-29, with later approved playtest revisions
folded into the relevant sections. This is the current named-zone authority;
the old radial "safe core + war coast" layout is retired. Catalog requirements
for unimplemented housing, PvP, war-front and encounter work remain binding
future scope. Delivery history is tracked separately in BACKLOG and the WP40
completion record.

**Round 22 rewrite (2026-09-25):** §7 (world model), §8.4 (landmarks), §9
(neighbors and roads), the capital ingress rule of §12 and §14 (acceptance)
were rewritten for natural terrain, borders, roads and water
(`../planning/round22-natural-world-plan.md`); §§1–3, the §8 and §11 intros
and §13.2 were aligned. The rewritten text describes the **target**; the
running mapgen follows as Round 22 Phases 3–5 land. The replaced WP40 text is
in this file as of commit `082982da`.

## 1. Authored macro-map, procedural local detail

- **Kragmar remains north and Elandor remains south.** They are distinct
  faction continents, but they are no longer separated along their whole
  front by mandatory open water.
- The continent parts meet along one continuous, narrow **Battlegrounds** land
  band. From west to east its four zones are Gravesalt Escarpment, The Broken
  Causeway, The Shattered Line and The Skyglass Canopy. This band contains the
  only normal overland crossings between the factions and provides several
  parallel traversable lanes rather than one blockable bridge; ocean separates
  the remaining coastlines.
- The Wyrmglass Crown and Stormscale Summit are separate level-60 offshore
  island zones beyond the western and eastern ends of that band. Neither has a
  land-neighbor edge. Their connections belong to a distinct boat/travel graph
  across immutable ocean channels, not to the land-adjacency graph.
- The macro-map is fixed by one authored layout rather than regenerated from
  each world seed. Every named zone has a stable hub, approximate extent,
  level range and biome palette, and every anchor has a fixed position. The
  world seed varies terrain, biome detail, content, the course of coastline
  and zone borders within bounded warps (§7.2, §7.3) and therefore the course
  of roads. It never moves a hub or an anchor, never puts an anchor into
  another zone or into the water and never changes the macro silhouette.
- The two faction sides are **progression and content-budget mirrors, not
  geometric mirrors**. They receive equivalent access to level bands,
  materials, PvP fronts, travel services and POI budgets, while their shapes,
  zone names, biome combinations and landmarks may differ.
- Each zone definition owns: display name and id, stable hub, macro region,
  optional ownership bias, `territory_rule`, exactly one `race_region`, level
  range, PvP rule, allowed biome
  list, signature terrain/property, mob and gathering palette, and reserved
  POI slots. `race_region` means cultural/geological provenance;
  it selects architecture, regional loot, one G1 gem, one G2 gem, one cultural
  material and one signature wood, but does not
  make a contested zone safe or politically controlled. `territory_rule`
  separately controls building and digging. Later quests and post-MVP POIs
  attach to the stable zone id.
- Every surface land zone, including both dragon islands, belongs to one of the
  six race regions. Open sea is outside this catalog; housing creates claims
  inside eligible home zones rather than separate housing zones. No neutral
  land zone may silently lose the regional material, architecture or quest
  hooks.
- A zone may contain several biomes, but its allowed biome list is fixed. A
  biome outside that list may never win inside the zone.

## 2. Surface progression

- Progression runs from the **outer side furthest from the enemy front** of
  each continent toward the faction contact front:
  1. outer race starting zones: levels **1–10**;
  2. adjacent home zones: levels **11–20**;
  3. central heartland: levels **21–30**;
  4. contested faction-front approaches and shared-front regions: levels
     **31–40**, **41–50**, **51–59** and the level-**60** endpoint summits.
- No level-1–30 zone is contested. Level-21–30 heartland may show military
  preparation and lead toward the front, but remains peaceful under the
  voluntary-tag rules of §4.
- **Every level-31–60 ordinary zone is contested**, including all six faction
  frontier approaches, all four Battlegrounds zones and both dragon islands.
  Capitals remain the peaceful civic exception described in §3.
- Most land where the faction continents meet is level 41–50 or 51–60. The six
  level-31–40 faction-front approaches and The Broken Causeway are the first
  contested destinations; their authored contacts introduce PvP without
  making the whole shared front a mid-level band.
- **Levels follow the zone (Round 22, decided 2026-09-25; replaces the R7.6
  axial bands).** Every surface position takes its level from the zone that
  owns it, so level and PvP status always agree and warped borders move both
  together. Inside a zone, the published `level_min..level_max` rises from
  the zone's home-facing side toward the faction front (Elandor toward +z,
  Kragmar toward -z), in three sub-ranges by cumulative integer thirds: 1–10
  becomes 1–3 / 4–6 / 7–10, 11–20 becomes 11–13 / 14–16 / 17–20, 51–59
  becomes 51–53 / 54–56 / 57–59, and 60 stays 60. How progress across the
  zone is measured is an implementation choice, as long as the level never
  leaves the zone's range, never falls toward the front and rises gradually.
- The Battlegrounds zones rise from both continent-facing sides toward the
  middle of the band. Wyrmglass and Stormscale are flat level 60. Capital
  zones use their published ranges but retain `civic_no_hostiles`.
- **Inner start band (decided 2026-09-17):** surface mob level is exactly
  **1** at integer horizontal Euclidean distance 0–100 nodes from each of the
  six authored start anchors and exactly **2** at distance 101–150 nodes.
  Beyond 150 nodes the start-zone gradient below applies. The outer
  starting-zone metadata remains levels **1–10**.
- **Start-zone gradient (Round 24, decided 2026-09-29):** in the six
  starting zones the surface level rises from the start toward the faction
  front instead of across the zone's whole z extent (the start sits mid-zone,
  so the old field put levels 7–9 right behind the 150-node band). Outside
  the start band the area behind the start, out to the home-facing coast,
  is **band 1** (its top level, 3); beside the start the level rises at half
  weight, so far flanks near a close front border can reach band 2 or 3; toward the front the
  level rises through band 2 (4–6) and reaches band 3 (7–10) only shortly
  before the front border, where it ends at 10 as before, so the step into
  the next zone is unchanged. Progress is `travelled / (travelled +
  remaining)` in cumulative thirds: `travelled` is the distance beyond the
  150-node band weighted by how far the offset points toward the front
  (full ahead, half beside, none behind) and `remaining` the distance along
  the front direction (Elandor +z, Kragmar −z) to the first column of a zone
  above the start range. The gradient is the start zones' surface level for
  every consumer (Round 24 ruling 25): spawn levels (`mob_level_at`) and the
  zone content level `surface_mob_level_at` that the mapgen reads
  (level-banded plants such as carrot, cassava and wild grain, vegetation
  resources, the P9G level bracket). Its border walk is cached per 8×8 cell
  and is a pure function of the cell, so every mapgen owner and every query
  order gets the same answer. Other zones keep their gradient.
- **Mob levels in zones with a spawn recipe (Round 28 ruling 34, Lane S1,
  2026-10-02).** A zone is a closed unit with planned progression: where its
  spawn data holds a recipe ([spawn_regions.md](spawn_regions.md)), each
  surface mob takes a level in its role's range of the spawn region it came
  from, named leaders the top of their region; the three sub-ranges toward
  the front above no longer apply to mobs there. Gameplay asks the surface
  level through `grug_core.mob_level_at`, which returns the region's level
  there (the level overlay); zones without a recipe keep the field. The
  field itself is never overlaid: it serves the mapgen's level-banded
  content, the depth floor and guards everywhere.
- The existing depth floor remains independent: underground level is the
  maximum of the local surface-zone level and the depth level from
  `combat_stats.md`.
- At **y = −701 and below**, every non-ocean land column is contested even
  beneath a peaceful surface zone, capital, functional anchor or active claim.
  Deep ocean and immutable dragon channels remain full-column exceptions.
- **Shore-height ruling (2026-09-17):** the first cardinal dry-land column
  beside any exposed water-surface node has its terrain surface at exactly the
  water-surface y. The inland terrain then continues through its existing bank
  blend. No dry shore column may end below its neighboring water surface.
  Where one bank touches two water surfaces (beside a river step), it takes
  the higher one, so nothing spills sideways and the step stays a water-water
  contact inside the channel (Round 22 Phase 5). Road bridges, decks and
  fords (§9) are functional crossings rather than dry-land banks and keep
  their own road grade.

## 3. Starting zones and capitals

- Every race has its own **outer level-1–10 starting zone and starting
  settlement**. New characters start there rather than in a capital. Until
  local graveyards exist, ordinary respawns return to that race's safe
  starting settlement.
- There are **six race capitals**, one for every race and three per faction.
  Every capital has its own named city zone in the central part of its
  continent.
- A capital zone is a peaceful, safe civic hub with **no hostile ambient
  enemies** and no automatic PvP tag. Its guards and important faction NPCs
  are level 60. The city itself is not a level-60 hostile leveling area.
- Each race has its own king, for **six kings total**. The race's capital is
  that king's seat. Housing is not a royal grant: the Housing Steward in
  every capital hands out the free Claim Stone from level 20 (`housing.md`;
  `world.md` §5 summarizes its world-facing integration).
- A capital is centered inside its city zone and has four fixed cardinal
  gates; the roads of §9 reach it through them. Its directional neighbors
  follow the world progression:
  - toward the outer starting side: a level-10–20 zone;
  - laterally along the central faction/capital axis: medium-level heartland;
  - toward the contested front: high-level territory.
- Capitals remain protected POIs and major waypoint/service hubs. They are
  destinations reached from the starting zones, not spawn bubbles.
- Capital zones use the same zone-based level rule as every other
  non-summit zone.
  Their exact level-60 guard rule and absence of ambient hostiles remain
  separate civic policy; no 20/25/30 gate/core progression profile exists.

## 4. PvP zones and voluntary flagging

- PvP state is explicit per player. A player is either **safe** or
  **PvP-tagged**.
- Entering a contested zone applies the PvP tag automatically. Leaving the
  zone does not remove it early.
- Entering y = −701 or below on any non-ocean land column applies the same
  automatic tag. Returning above that boundary under a peaceful surface zone
  starts the ordinary full safe-zone tail; it never clears the tag early.
- In a peaceful zone, an untagged player cannot receive unprovoked damage from
  an enemy player and cannot be selected as a valid hostile PvP damage target.
- An untagged player who voluntarily uses a hostile action against an enemy
  player is tagged before PvP eligibility and damage are resolved. They are
  then attackable by every enemy player, including in peaceful zones. If both
  players were safe, that first hostile effect is blocked and the target stays
  safe; §15.1's four-row transaction is authoritative.
- A tagged player may attack tagged enemies but may not use their own tag to
  initiate damage against an untagged player in a peaceful zone.
- Outside a contested zone, the tag expires **60 seconds after the last
  qualifying PvP contact**. Accepted hostile damage that lowers HP or consumes
  absorb refreshes both participants; effective support of a tagged ally
  refreshes helper and target. Misses, dodge, immunity, refusal and zero-effect
  damage/support do not refresh it. A contested zone keeps the tag forced;
  leaving it starts at least one full 60-second safe-zone tail even if no
  qualifying contact happened inside.
- Player death clears the tag immediately. The safe outer starting zones plus
  death cleanup make repeated spawn ganking impossible by rule.
- Melee, targeted skills, area effects and projectiles all use one central
  PvP-eligibility rule; no combat path may implement its own geographic
  exception.

## 5. War-front life

- The land connections are visibly active battlefields: walls, damaged
  fortresses, siege equipment, burned ground and other war remains form their
  shared visual layer.
- Faction NPC battles occur only through dedicated, bounded war-front
  populations and encounter anchors. Ordinary guards do not globally acquire
  every NPC.
- War-front squads have fixed population caps, place-bound respawn slots and
  authored clash points. They fight the opposing war-front faction, hostile
  players and dangerous local creatures.
- The MVP front is strategically static: NPC skirmishes do not permanently
  capture zones or move the faction boundary. Later quests may trigger local
  assaults without changing the macro-map.
- Existing anti-litter rules remain: NPC-versus-NPC and NPC-versus-mob kills
  produce no loot unless a player was involved.

## 6. Dragon endpoints

- The old plan of one dragon placed separately on each continent is retired.
- The macro-map has **two** endpoint regions, one where the western end of the
  shared front reaches the ocean and one at its eastern end. WP23 (delivered) populates
  both with an overworld dragon through one shared encounter chassis and two
  regional variants.
- Each overworld dragon lair occupies its own **offshore island** beyond one
  ocean endpoint of the Battlegrounds. An immutable full-column ocean channel
  separates it from every mainland coast, so it has no land, bridge or tunnel
  connection. Both factions receive equivalent authored boat access.
- Every dragon island is a contested level-60 mountain region with strong
  level-60 mountain creatures. Its silhouette culminates in a dragon mountain
  or summit lair (no hoard chest, WP audit E11).
- An overworld dragon is therefore always a PvP world boss. Reaching and
  fighting it exposes both factions to each other; it is never a private
  home-continent boss.
- The fixed `dragon` anchors are the encounter authority: the Wyrmglass Ice
  Dragon stands at **(-3260, -40)** and the Stormscale Jungle Wyvern at
  **(+3260, -40)**. Each is a clock-independent fixed-level-60 boss with three
  arena perches, a telegraphed breath line and ground slam, and a persistent
  30-minute wall-clock respawn. An active lair receives the final 60-second
  local visual/audio warning; a lair loaded late receives the whole minute.
- Each endpoint reserves an apex mining camp in the dangerous approach to the
  lair. Its building core is protected as a POI box (`world.md` §2 R1b);
  walls, tents, fences and dressing outside it are mutable. Its bounded
  functional anchor is hard-protected. It has no renewable sockets: renewable
  ores are removed entirely, camps included (user decision 2026-09-29,
  [WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
  E5), and natural veins remain finite (`world.md` §2 R4).

## 7. Horizontal and vertical world model

Rewritten for Round 22 (2026-09-25, `../planning/round22-natural-world-plan.md`
D1–D19). This section describes the target world. Until Round 22 Phases 3–5
land, the running mapgen still implements the WP40 model that this section
replaced; git history before this rewrite records that model.

### 7.1 Frame, hubs and fixed anchors

- World axes stay conventional: west/east is x, Kragmar lies north at positive
  z, Elandor lies south at negative z, and the shared front is centred on z = 0.
- One authored layout fixes the macro silhouette, the zone hubs, the island
  hubs and every anchor position. The world seed drives the warps of §7.2 and
  §7.3, so every world has its own coastline and zone borders, plus its own
  terrain and road courses (§9.2). It never moves a hub or an anchor, never
  changes which zone an anchor belongs to and never changes the macro
  silhouette a player learns from the map (Round 22 D24).
- When a world is built, one cheap self-check confirms that every anchor lies
  in its own zone and on land, every zone is connected and the dragon channels
  keep their width. If it fails for a seed, that world falls back to a weaker
  warp and logs a warning; it is a safeguard, not a test suite.
- Because coast, borders and roads differ per world, the server renders the
  world map for its own world at first start (§13.1, `world_map.md`).
- The **Battlegrounds** are the four front zones between the continents
  (§8.3). They have no special geometry: no rectangle, no exact edge and no
  technical role beyond being ordinary contested zones with story weight.
  Their borders with each other and with the faction frontiers are natural
  borders like every other zone border (§7.3). Both factions may dig and place
  ordinary terrain there at every depth, subject to tools and explicit
  protected envelopes (`world.md` §2 R1, R1b); no claim may be placed
  there. Their `territory_rule` is `contested_land` (Round 22 Phase 3, D22); the internal macro-region key
  `holy_grounds` is a legacy token without geometry or rights of its own.
- Unwarped authored mainland primitives stay within x = -2600..+2600 and
  z = -3000..+3000. These are source bounds, not a coastline or world border;
  the warped coast may leave them by at most the coast warp amplitude. Open
  sea continues outside the generated area.
- The Wyrmglass Crown and Stormscale Summit hubs are fixed at **(-3150, 0)**
  and **(+3150, 0)**. Each coastline remains inside its independently authored
  closed 600 by 700 envelope centred on that hub.
- The 38 stable zone hubs are:

  | Zone id | Hub (x, z) |
  |---|---:|
  | `elandor_hearthpine_vale` | (-1800, -2550) |
  | `elandor_copperfell_foothills` | (-1800, -2050) |
  | `elandor_dur_brannoc` | (-1800, -1500) |
  | `elandor_frostbarrow_shelf` | (-2400, -1500) |
  | `elandor_stormvault_heights` | (-1800, -700) |
  | `elandor_dawnmere_fields` | (0, -2550) |
  | `elandor_goldmead_vale` | (0, -2050) |
  | `elandor_highcourt` | (0, -1500) |
  | `elandor_whitebridge_shire` | (-900, -1500) |
  | `elandor_ashenward_march` | (0, -700) |
  | `elandor_silverleaf_glades` | (+1800, -2550) |
  | `elandor_starbough_vale` | (+1800, -2050) |
  | `elandor_lethariel` | (+1800, -1500) |
  | `elandor_lorindor` | (+900, -1500) |
  | `elandor_moonfall_wood` | (+2400, -1500) |
  | `elandor_glassroot_wilds` | (+1800, -700) |
  | `kragmar_stillgrave_hollow` | (-1800, +2550) |
  | `kragmar_mournfen` | (-1800, +2050) |
  | `kragmar_nhal_veyr` | (-1800, +1500) |
  | `kragmar_ossuary_reach` | (-2400, +1500) |
  | `kragmar_blackwind_rise` | (-1800, +700) |
  | `kragmar_sunscar_flats` | (0, +2550) |
  | `kragmar_redtusk_savanna` | (0, +2050) |
  | `kragmar_gor_drazhak` | (0, +1500) |
  | `kragmar_speargrass_reach` | (-900, +1500) |
  | `kragmar_bannerbreak_mesa` | (0, +700) |
  | `kragmar_kapok_cradle` | (+1800, +2550) |
  | `kragmar_raincall_basin` | (+1800, +2050) |
  | `kragmar_kezamba` | (+1800, +1500) |
  | `kragmar_whispering_reedlands` | (+900, +1500) |
  | `kragmar_totemwater_reach` | (+2400, +1500) |
  | `kragmar_thunderroot_wilds` | (+1800, +700) |
  | `front_wyrmglass_crown` | (-3150, 0) |
  | `front_gravesalt_escarpment` | (-2000, 0) |
  | `front_broken_causeway` | (-750, 0) |
  | `front_shattered_line` | (+750, 0) |
  | `front_skyglass_canopy` | (+2000, 0) |
  | `front_stormscale_summit` | (+3150, 0) |

- The six starting-settlement centres are (-1800, -2550), (0, -2550),
  (+1800, -2550), (-1800, +2550), (0, +2550) and (+1800, +2550).
  Each owns a centred **600 by 500 start core** wholly inside its starting
  zone, dry except for explicitly authored civic water.
- The six capital centres are (-1800, -1500), (0, -1500), (+1800, -1500),
  (-1800, +1500), (0, +1500) and (+1800, +1500). Each **512 by 512 build
  envelope** belongs wholly to its capital zone. The surrounding terrain blend
  may cross a zone border and does not enlarge political ownership. The
  envelope size stays. The former goal of smaller, denser capitals (Round 22
  §11) is retired (user decision 2026-09-29, WP audit A3): a capital's size
  fits its content, with a characteristic look (§12).
- Every anchor slot keeps its stable id and fixed x/z position. No world seed
  selects, moves or rejects a 2D anchor; terrain fitting adapts to the anchor.
- The macro silhouette remains legible as three outer prongs, one connected
  capital/heartland belt and one connected frontier per faction, joined by the
  Battlegrounds band.

### 7.2 Macro land and coastline

- The coarse land silhouette is a small authored set of simple primitives:
  three broad cultural lobes, a capital belt and a frontier on each mainland,
  the Battlegrounds band between them and one island shape per dragon
  endpoint. The primitives only define the coarse shape; nobody should be able
  to see them in the finished coast.
- The finished coastline is that silhouette under a **multi-scale warp** of
  the same family as the zone borders (§7.3), plus small-scale irregularity:
  coves, headlands, spits and occasional small islets near the shore. A small
  islet is ordinary land of the zone that owns the adjacent coast.
- Elandor and Kragmar are not coordinate reflections and may not share a
  reflected source record. Their silhouettes, bay placement and landmark
  composition stay culturally distinct while progression, resource and access
  budgets stay equivalent.
- Everything that must stay on a known side of the water keeps its place:
  start cores, capital envelopes, harbours, island landings and boat-route
  ends. The coast is pushed out or its warp
  damped locally there. Correctness comes from that local shaping in one pass,
  not from a repair pass, a topology census or an alternate layout.
- The final products are one connected mainland and two connected dragon
  islands, plus any small islets the coast warp creates. Every ordinary zone
  is nonempty and connected.

### 7.3 Zone ownership, neighbors and difficulty

- Zone ownership is one power diagram over all mainland zones, the four
  Battlegrounds zones included; each dragon island is its own single zone.
  Query points are displaced by a **multi-scale warp** of roughly ±150–250
  nodes, so borders meander at several scales and no long straight border line
  remains. A zone's centre may be a short line segment instead of its hub
  point where that keeps a band continuous: the four Battlegrounds zones and
  the six frontier zones use this, so the Battlegrounds form one continuous
  wavy band between the continents and no Elandor zone touches a Kragmar
  zone.
- The warp is damped near every fixed anchor, so each anchor's footprint
  (start core, capital envelope, village, outpost, camp, mine, clash site,
  dragon arena) stays inside its own zone. If an anchor would still leave its
  zone, the fix is stronger damping or a smaller warp, never a repair pass.
- Every zone stays one connected region. This is checked (§14), not solved.
- **Gameplay neighbors are geometric.** Two zones are neighbors when they
  share a land border of meaningful length; a single-point or very short
  contact does not count, and the implementation fixes the threshold.
  `neighbors(id)` returns that list. It is derived from the ownership
  function and is never imposed on it: no neighbor or graph requirement may
  shape a zone border (D14). The dragon islands have no land neighbors; their
  boat connections are in §9.4.
- Borders between logical biomes of neighboring zones blend over a narrow
  noise-dithered band instead of switching the palette on one line: within
  about 40 nodes of a border, one small noise jitter (about ±24 nodes) moves
  both the palette-zone and the biome-patch lookup (Round 22 Phase 3).
- Surface level follows the owning zone (§2). Warped borders therefore move
  level and PvP status together; there is no separate difficulty geometry.
  Capital guard floors, depth progression, civic hostility policy and
  fixed-level entities remain independent.

### 7.4 Water, coast and islands

- **Bays.** Four bays, one between each pair of outer prongs, keep the
  prongs visibly separated. Each opens to the ocean, stays at least 64 nodes
  wide, reaches no capital envelope and splits no zone. Bay outlines get the
  same coast warp as the rest of the shore; their authored centrelines live
  in the source data.
- **Water classes.** Every column is land, inland water (rivers, lakes, civic
  water), bay water, coastal shelf, deep ocean or dragon channel. The old
  hydrology rows were removed at the start of Round 22 Phase 5, which lays out
  all inland water anew: rivers and lakes from the terrain's drainage, civic
  water as authored lakes (below). Inland and
  bay water belong to the zone around them: a wet river or lake column has the
  zone-owned class `planned_water` (like a bay), its dry banks stay land.
  Shelf, bay water and every road/POI exclusion are excluded from cultural
  reservations and gathering sources. So are wet river and lake columns and
  their **water bank**, dry land within two nodes of such a column
  (exclusion kinds `inland_water` and `water_bank`, reason `route_or_water`,
  Round 22 Phase 5): no cultural reservation or gathering source stands in
  or right beside inland water, except content that seeks it (shore rows on
  the bank, freshwater plants in the water). Decorations are not claims and
  may grow on banks. Deep ocean and dragon channels are immutable at every y.
- **Dragon channels.** The two island channels are roughly 200 water nodes
  wide between mainland and island land; the construction self-check (§7.1)
  requires at least 104. Each shore contributes a 48-node flight-warning
  band (`mounts.md` §4.1). Filling, draining, bridging or tunnelling through
  the channel is forbidden.
- **Island approaches.** Each island keeps two boat approaches, one northern
  and one southern, each ending at a landing beach at a fixed point in the
  source data. The northern and southern boat routes to either island are
  roughly equal in length. Both approaches are open to both factions.
- **A river lies in a trough (Round 22, D54).** Its cross-section is a
  smooth trough blended into the terrain, like a lake drawn along a line: the
  ground is pulled down toward a bed below the reach's level, most on the
  centreline and fading out to the untouched terrain at the trough's edge.
  The trough is U-shaped (a flat floor) on gentle ground and V-shaped where
  the terrain stands high above the water; it is wide where the banks are
  high, so rivers in hills and mountains lower their whole valley. Its walls
  wobble with the terrain and a 2D noise, never parallel to the river. The
  water fills the trough up to the reach's level wherever the trough ground
  lies below it, so the water's width and shoreline vary with the terrain
  like a lake's shore, and the trough need not be full. There is no flat
  floodplain strip and no incised channel; the sand band beside a river is
  narrow (the near-water material rule reads twice the river distance).
- **River width (Round 22, D55).** The water width grows with the catchment
  and varies along the course by noise at two scales and by the terrain
  (wider on gentle ground): about 7-30 nodes of target width, at least about
  six nodes of water away from springs and sinks, wider at sea mouths. A
  spring starts as a brook about three nodes wide that widens to the river's
  width over about 160 nodes (Round 22 wave 2); above it the trough continues
  up the drainage as a dry gully of up to about 200 nodes that narrows and
  fades out. Into a sink and out of the spring after it the water narrows to
  the same brook. The valley (reach levels, course detours) is shaped for the
  full spring width, so the brook changes neither the course nor the levels.
  The course (centreline and meander) keeps the Phase 5 channel-width model,
  so the winding shape does not change with the water width.
- **Water steps down downstream.** Luanti water needs level surfaces, so a
  river's surface is constant along one reach and steps down to the next reach
  downstream through a small fall or rapids. Use few, simple step types:
  gentle terrain gets many small rapids (1–3 nodes), tall falls (up to about
  16) only on steep slopes. The two step types are a rapid (a drop of up to 3)
  and a fall; a lake's outflow over a step is river water, so it cannot flood
  the shore below. Next to a step the upper reach keeps to its channel, so its
  water does not flood the low bank up to the step's straight line.
- **Flow direction (Round 22, D56).** Reach levels never rise downstream:
  along a river, across the dry gap after a sink (the new stretch starts no
  higher than the one before), at confluences (a tributary's level at the
  junction caps its parent's levels below it, so a tributary meets its parent
  at or above the parent's surface; where the tributary's water can touch the
  parent's before the join, at the foot of a step or along channels running
  side by side, the parent is capped there so the tributary never lies beside
  it lower (side-by-side staircases may still touch with the tributary higher,
  spilling downstream), unless the parent would then cut deeper than its sink
  limit), at a lake mouth (a river meets the lake
  at the lake's level, at most three nodes above the river's own level at
  the shore, except where two touching lakes must share a level; a lake
  standing higher is lowered by at most four nodes and only while at least
  half of it stays wet, its basin above the new level turning to ordinary
  terrain; otherwise it keeps its level and shores and the river sinks
  before reaching it, as does a river that would run back into the lake it
  left) and
  between lakes (a lake fed by a river from another lake stands no
  higher than that lake, and at the same level when their water could meet).
  The trough's fill level absorbs the small raises. A drop that a junction
  or a sink imposes is spread upstream in steps the slope allows (D39), so
  flat ground gets no tall fall at a confluence.
- **Layout from drainage (Round 22, D38, D57).** Rivers and lakes come from
  the drainage of the natural terrain on a coarse grid, without erosion:
  shallow pits are breached, deeper basins keep a lake below their spill
  level, and wetland zones and water landmarks keep shallow ponds. Water
  keep-outs exist only for start towns (about 300 nodes around the start) and
  for each capital's protected civic core (the core's corner distance plus a
  margin, about 100-130 nodes, with an irregular edge); a capital's own lake
  (Lethariel's crown lake, Kezamba's cenote) keeps natural water off within
  its bounds. Water routes around every keep-out (a river may skirt a core in
  an arc). Rivers and lakes
  may cross the rest of a capital's reserved area: plots or lanes standing in
  water there are allowed until the capital planner (plan D60) builds the
  capital around its water, and the capital's and a start's terrace grading
  leave a river's trough untouched. A river starts and ends at the shore of
  its lake (no trough across the lake bed). Civic water and Moonfall's
  crescent lake are authored lakes in the same format.
- **Civic water (Round 22, D26, D34, D42).** Authored lakes sit on the fitted
  terrain (`wp40/water_authored.lua`): the Kezamba cenote and the Lethariel
  crown lake two nodes below their civic pads, inside the civic core exactly
  on the committed blueprint footprints (the Kezamba lagoon mask, the
  Lethariel `MERE`), outside it with warped coves and points, a carved bed
  (the cenote's in ledges) and shores shaped into banks and low natural dams;
  Highcourt's two blueprint river arms and their outflow as one civic canal
  of river water, gently meandering, with one level everywhere (D58 interim):
  halfway between the lowest ground of its banks and the highest ground under
  it, the trough carved into the terrain where that is higher and the rim
  raised to the level (a raised bank) where it is lower; no rapids and no link
  to world water: where a natural river or lake comes within eight nodes the
  canal ends there in its sealed rim. Steps between planned surfaces that do
  lie in protected territory (a river crossing a capital) flow like any other:
  the water guard exempts exactly that flow. Small
  ponds beside the Dawnmere and Sunscar starts: Sunscar's two waterholes at
  the lowest ground of their banks, Dawnmere's pond 40 nodes south of the
  pad one node below the pad's level (Round 22 D78); no authored water or
  its bank shaping reaches a start town's pad or protected band. Authored water and its bank shaping keep at least eight nodes off
  every district plot and fill lot (margin included), so the plots stand on
  the ground they were measured on. Moonfall's crescent lake (D41) lies on a
  calm bowl the landmark adds to the terrain field (like a steep POI's, at
  the mean natural height), with its own natural-water keep-out, so rivers
  and drainage lakes bend around it.
- **Lakes have irregular shores** with coves and shallow margins.
- Every wet river reach uses `default:river_water_source` /
  `default:river_water_flowing`. This non-renewable, range-two liquid keeps
  river edges and the pools below falls from regenerating hanging source
  sheets. Oceans, bays, lakes and civic water use `default:water_source`.
  Every river and lake bed is sealed three nodes deep, and its banks are
  sealed too, so inland water does not drain into the caves of its own
  mapchunk; the top node of a sealed bed or bank keeps its surface material
  (bed patches, shore material, biome top). A native cave of a neighbouring mapchunk generated later can
  still cut up to about 13 nodes into an already generated one (engine
  behaviour); forced-order engine tests found no bed cut open that way.
- Wet inland beds vary in depth with the terrain detail; continental bays are
  6–10 nodes deep; the coastal shelf slopes from the shore to deep water; deep
  ocean and dragon channels are 24 nodes deep.
- Wet beds use deterministic patches of their bed material, sand, gravel and
  stone; mud remains the dominant swamp bed. Dry continental beaches are
  plain sand (no gravel speckles; Round 22 Phase 6).
- **Coast shape (Round 22, D27):** the coast takes its shape from the
  terrain field alone: it mostly ramps gently to the water, with occasional
  steep coasts. There are no geometric coast profiles, runs or fixed beach
  slopes.
- **Shore profile (Round 22, D35):** the height runs continuously through the
  waterline. Where the terrain is gentle, a beach slopes down to the water
  surface, the first water is one node deep and the floor deepens across a
  shallow shelf (the reef depths) before falling to the deep sea; steep
  terrain may still meet the sea steeply. Boat water keeps its own minimum
  depth.
- **Near-water materials (Round 22, D27):** one rule derived from the final
  terrain, near the water. Low, gentle ground within roughly 40 nodes of the
  water is sand above three sandstone filler nodes. Steep
  ground at the water and the edges of cliffs are gravel or stone. Mountain
  land, including both dragon islands, never gets dry sand; where mountain
  land borders other land the switch is dithered by noise, not a line. The
  height, slope and reach limits are jittered by noise, so material edges
  follow the terrain and never run straight. This rule is the only source of
  dry beach sand: the palette beach biome shows shingle and rock wherever the
  rule gives no sand. Lake and river banks (Phase 5) reuse the same rule with
  their own water surface; river banks count their distance twice, so the
  sand beside a river stays a narrow band (D54).
- **Shore height:** the first cardinal dry-land column beside any exposed
  water surface has its terrain surface at exactly the water-surface y (§2).
  No dry shore column ends below its neighboring water surface. Bridges,
  fords and other functional crossings keep their own grade.

### 7.5 Roads, anchors and housing

- Roads, trails and boat routes follow §9. A road never creates land; its
  corridor stays on land or crosses inland water by bridge or ford. Shelf,
  deep ocean and dragon channels are forbidden to roads.
- Primary roads use a 7-node surface, secondary roads 5 and trails 3. The
  mapgen exclusion corridor is the road surface, its cut and fill slopes and
  2 nodes beyond the road edge; vegetation, POI content and spawns keep off
  it.
- Roads and open-world bridges are world-protected (Round 25 ruling 15,
  `world.md` §2 R1b): the road's half width plus 1 node on each side
  (Round 28 ruling 1: primary 9, secondary 7, trail 5 nodes, inside the
  vegetation exclusion above) and ±5 nodes around the road
  surface, checked analytically against the planned centreline segments.
  Claims may contain roads; the corridor stays protected inside them.
- Starts keep their start-pad fitting (`settlements.md`); capitals keep their
  96-node civic core and terrace contract (§12).
- **POIs sit in the terrain (Round 22, D33).** Every other anchor keeps its
  x/z, and its height comes from the terrain: the lower median of the natural
  ground under its building core (village and home bandit camp 24; frontier
  bandit camp (`bandit_frontier`, user decision 2026-09-29, WP audit E1),
  outpost, Mirefolk camp and clash site 16; mine 20; dragon and apex mine 32; rare
  route 12 nodes), at least one node above water. Only that core is flat.
  A short collar follows the core's outline with round corners and a
  noise-varied width and returns to natural terrain: about 6 nodes on level
  ground, longer where the core's edge stands higher or lower than the
  ground, and never more than about 28 nodes. Where the natural ground under
  the core varies by more than about 40 nodes (dragon arenas, apex mines and
  POIs on steep slopes), a small calm bowl in the terrain field first turns
  the slope or summit into a shelf at the local ground's mean height, with an
  irregular edge. There are no square plates. Vegetation is kept off only
  the core and a 4-node margin.
- **No housing masks** (Round 25 ruling 4). The former authored housing
  masks and the four coastal housing areas are removed from the layout and
  the zone data. Claim eligibility is `housing.md` §2 only: the whole claim
  lies in the claimant's own level-11–30 home zones and keeps 16 nodes from
  every hard-protected footprint and every POI, village or camp core
  (Round 25 ruling 27). Mapgen generates
  nothing housing-specific. Placed Claim Stones change nothing about
  generation; inside an active claim there is no natural renewal
  (`housing.md` §6.4).

### 7.6 Height, relief and visual structure

- **One height field.** The project owns one globally queryable surface
  height `H(seed, x, z)`, exposed as `terrain_height_at`. It is a pure
  function of seed and position, independent of chunk order, so planning can
  query any column before its chunk exists and chunk borders never show
  seams. Floating-point arithmetic is allowed; byte identity across hardware
  is not a goal (D2); the public `terrain_height_at` still returns an integer
  node y. It never reads a generated chunk, the engine spawn level or a v7
  heightmap as authority.
- **Variation at every scale.** Relief comes from gradient noise summed over
  several octaves down to about 8 nodes, a domain warp that bends features
  away from any grid, and ridged noise that forms mountain ranges with ridges
  and valleys. Hills, gentle lowlands and occasional cliffs appear naturally.
  No geometric stamps, straight edges or S-curve ramps.
- **Regional character.** Every zone has a character preset: base elevation,
  roughness and ridge share. Presets blend into each other over roughly
  300–500 nodes along a warped distance, so no terrace or step appears at a
  zone border. Race accents are mild: dwarf lands a little more rugged, human
  lands gentler, and so on, without making a whole region one landform. The
  six character ids and their typical elevation above water level are:

  | Character id | Typical elevation above water |
  |---|---:|
  | `wetland_delta` | +2..+24 |
  | `lowland` | +8..+56 |
  | `rolling_hills` | +24..+96 |
  | `plateau` | +56..+144 |
  | `highland` | +96..+224 |
  | `mountain` | +160..+360 |

  These are typical ranges, not hard limits; noise and landmarks may leave
  them locally. Biome patches do not change relief.
- **Landmarks** are one or two strong features per zone (§8.4). Each is a
  soft field of one of the §8.4 types with a warped outline and free
  orientation. A landmark changes
  the character parameters or adds a shape inside its field and fades out
  softly; it is never an axis-aligned stamp.
- **Transitions need not be smooth.** Occasional cliffs, steep slopes and
  escarpments may come from the noise itself or from a landmark; the former
  rule that every abrupt feature needs a named landmark is retired.
- **Calm ground around cities.** Roughness is damped around starts and
  capitals, keyed to the start pad and the capital civic core. Start pads
  sit in a small calm bowl that follows the pad (Round 22, D78): calm
  through the protected band (§12, damping to 10 nodes beyond the pad's
  edge, then fading in so slowly that the band stays calm), then natural
  relief returns over a fade whose width follows the land round the town —
  about 60 nodes on level ground, up to about 200 where the town sits in a
  hollow or on a rise (the fade is the ground's height difference to the
  calm level over a grade of 0.3), so the rise or fall back to the natural
  ground is a hill, never a wall; the fade's outer edge varies with noise.
  Around a
  capital only the 96×96 civic core is flat: the calm zone around it keeps
  long-wave hills and hollows (wavelengths of about 100 nodes and more, a
  race-specific amplitude of roughly ±8–12 nodes, no fine detail) out to
  about 200–260 nodes, full natural relief returns by about 400–580 nodes,
  and that outer edge varies with noise, so the zone is round around the city
  but never a clean circle (D76, §12). The capital planner lays its city out
  on this ground. Each capital's ground sits
  well below its region's cloud layer: clouds are placed relative to the
  region, at least about 60 nodes above capital ground. Capital and start
  fitting must stay within their cut/fill limits on the new terrain.
- **Order of grading.** Start, capital, road and anchor grading override
  natural relief in that order of functional necessity. On a road's visible
  surface, the road grade wins. Roads are walkable: their profile runs in half-node
  steps (slabs), at most ½ node between neighboring road columns (Round 22
  D49).
- **Natural cave roofs and openings (2026-09-20):** native v7 caves remain
  authoritative; no synthetic cave-mouth writer runs. After terrain and
  surface refinement, dry eligible columns receive a three-node skin below
  their final surface, clipped at y = -37. Native air opens naturally only
  when at least four consecutive air nodes lie below the surface and either a
  cardinal neighbor is at least two nodes lower or all nine columns of the
  centred 3x3 neighborhood have that air run. Otherwise the skin closes a thin
  roof. Start and capital build squares, POI building cores, road corridors,
  functional water and road operations and foundations are excluded from
  both filling and opening.
- **Fresh-world surface and vegetation refinement (2026-09-13):** logical
  biome ownership stays unchanged. Dry surfaces combine coherent 32-node and
  8-node material fields at weights 3:1; filler depth varies from 1–4 nodes
  on a 64-node field. Wet-bed and beach-shore patches follow §7.4; dry swamp
  surfaces retain mud.
  The base R6 surface table is refined by the following fertile palettes;
  all existing biome decorations accept every fertile variant at their
  existing density and retain their species, elevation and protection rules.

  | Biome | Fertile surfaces (existing nodes) |
  |---|---|
  | Meadows | grass, dirt, forest litter |
  | Pine hills | coniferous litter, forest litter, grass |
  | Elf forest | silver litter, forest litter, grass |
  | Deep forest | forest litter, coniferous litter, grass |
  | Jungle edge | rainforest litter, canopy litter, mud |
  | Deep jungle / jungle fringe | canopy litter, rainforest litter, mud |
  | Savanna | dry grass, dry dirt, mesa clay |
  | Badlands / eastern badlands | mesa clay, dry dirt |
  | Blight / bone forest | blight dirt, bone litter |

  Ordinary-biome patch values below 300 choose the second fertile surface;
  values 300–439 choose the third (or repeat the base where only two exist).
  Values 440–780 keep the base, 781–880 expose gravel, and above 880 expose
  stone. Crags retain gravel and stone; snowy crags retain snow, gravel and
  stone, with the existing elevation-gated crags pine exception. No new
  snowy-crag species or gathering resources are introduced.
  On final-terrain rises of at least 12 nodes across an eight-node sample,
  patch values above 760 expose stone. Eight-node detail values above 680
  interrupt gentle ordinary-biome outcrops with native soil pockets. Low
  decorations (settlement class 4) accept gravel with one-quarter eligible
  roots. Trees and trunks do not root on these gravel variants; native crags
  pines keep their existing gravel support. Stone remains bare. Planner,
  prospective settlement and actual writer use the same biome-and-substrate
  eligibility.
- **Steep ground (Round 22 Phase 6).** Every dry natural column outside the
  near-water rule, the badlands and the swamp reads its final terrain: the
  drop to its lowest cardinal neighbour (a wet neighbour counts at its water
  surface) and the grade over six nodes. A grade from 2.0 to 4.0 nodes per
  node (the limit jittered by two noise scales, so rock and soil alternate in
  patches) or a drop of 6–8 nodes makes a **bare rock face** (stone top and
  filler). A drop of 2 or more below that keeps the column's top over a
  **stone filler** (a soil lip over a rock face; no dirt shows on a face).
  Gentle ground at the foot of a rise of 6–10 nodes within three nodes is
  **gravel scree** in noise patches. Rock faces and lips skip the shallow
  strata, so no band follows a cliff face. Graded pads, hard foundations and
  road corridors keep their surfaces. Trees and plants do not root on bare
  rock.
- **Vegetation and altitude (Round 23 Phase 2, user rulings 2026-09-28).**
  One rule (`habitat_registry.lua` `vegetation_rule`) is read by the
  decoration planner, the surface selector and runtime vegetation renewal
  (farming.md "Wild plant renewal"). Every value is a function of the
  column's position, planned terrain height, logical biome and zone; no
  neighbour column is read. Integer fixed point, identical in LuaJIT and PUC.
  - **Lines.** Tree start y 160, tree line y 220, snow line y 280. A smooth
    field (80-node period plus a 20-node detail, weights 3:1) shifts all three
    together by at most ±15 nodes, so the lines form tongues and bays. Warm
    biomes (deep jungle, jungle edge, jungle fringe, savanna, both badlands)
    and every biome of the Skyglass Canopy (the cloud forest) have all lines
    40 higher; the other biomes keep the base. Measured on four seeds
    (coarse analytic grid): 12.2 % of dry land lies at or above the tree
    start, 5.1 % at or above the tree line, 2.6 % beyond the shrub band and
    1.9 % under the snow cap.
  - **Trees** thin linearly from the tree start to zero at the tree line.
    The crags snowy pine keeps full density 30 nodes longer and then thins to
    zero at the same line: it is the typical last tree.
  - **Shrubs.** As trees thin, the biome's own shrub rises linearly from its
    catalog density to three times it at the tree line, holds that for 20
    nodes and falls to zero 40 nodes above the tree line: pine bush in the
    pine hills and crags, bush in the meadows, deep forest and elf forest,
    acacia bush in the savanna, dry shrub in the blight and bone forest.
    Crags, deep forest, elf forest and bone forest have no shrub of their own
    below the band; band-only rows (crags pine bush `3/500` on gravel, deep
    and elf forest bush `1/250`, bone forest dry shrub `3/200`) grow only
    there, from zero at the tree start to the same peak.
  - **Ground cover** (grass, ferns, junglegrass, reeds, the blueberry bush
    and the dry shrubs of badlands, savanna and swamp) keeps its density up
    to the snow line: the alpine meadow between the shrub band and the snow.
  - **Snow.** At and above the snow line the dry top is `default:snowblock`
    with `default:snow` dust over the column's own filler; in the 20 nodes
    below it, snow dust lies in patches (a 10-node field) whose share rises
    from none at the foot of the band to all at the line. Steep rock faces
    (above) stay bare rock; shores, start towns and water columns get no
    snow. No ice, no slope-aspect rule. A column with snow (cap or dust)
    hosts no decoration.
  - **Forests and clearings.** Trees are multiplied by a forest field: groves
    from a 224-node field (0.24–1.76 of the mean) times clearings from a
    64/20-node field (zero below a threshold, a short ramp above), which
    gives groves of roughly 150–300 nodes and clearings of 40–100. The field
    is rescaled per zone: each zone's scale makes its mean over the zone's
    land (a fixed 16-node grid) one, and the scales are interpolated
    bilinearly from a 64-node lattice (each lattice point takes the scale of
    its zone), so no zone border shows a step and every zone keeps its mean
    tree density within a few percent (measured 0.97–1.03). Deep forest and
    deep jungle trees are then multiplied by 1.5. Shrubs and ground cover are
    not affected.
  - **Planner.** Each decoration row's class (tree, last tree, shrub,
    band-only shrub, cover) picks one factor per column. A column is eligible
    with probability factor ÷ (class maximum), the class maximum being 5 for
    trees, 3 for shrubs and 1 for cover, and the 16×16 cell budget is scaled
    by the class maximum, so the expected placements are the catalog density
    times the factor. Cover rows keep their former eligibility wherever the
    factor is one.
  - **Shrubs on slopes.** Shrub templates (the shrub and band-only shrub
    rows) place like the engine's own schematics: a leaf (a cell without
    force placement) that would hit ground is left out instead of rejecting
    the whole bush. The stem keeps the full rule, so no bush floats or buries
    its stem. Trees keep the whole-template clearance rule.
- **Substrate.** Native v7 remains the substrate for caves, ores, dungeons
  and strata, but its heightmap never selects the final surface, a mask, an
  operation or a priority. The writer may read that heightmap only as a local
  pre-cave datum for the current owner slice: ordinary native cave air and
  liquid at or below that datum survive, while sky-side void above it may be
  normalized to the final surface.
- Broad authored writes never begin below y = -37. Exact foundation, path,
  crossing, tunnel, seal and water operations may replace content only inside
  their owned volumes. Project-native ore, resource and stratum content at the
  final surface, in authored water above it or above the final surface cap is
  replaceable where required to materialize the height and water; supporting
  solids below the surface otherwise remain unchanged. Foreign, unknown and
  unavailable content remains a transaction veto. Native dungeons stay
  disjoint below the authored range, and no second competing terrain writer
  runs.
- **Shallow subsurface strata (2026-09-18):** below top soil and filler, the
  first 40 nodes contain deterministic three-node secondary-stone bands,
  three-node gravel lenses and two-node dirt pockets; wetland-delta and swamp
  pockets use `default:clay`. Palette secondaries are sandstone under savanna,
  basalt under badlands, desert stone as the existing closest limestone under
  meadows, slate under pine hills and mossy cobble as the existing closest
  mossy stone under jungle. Slate and basalt here are the decorative any-pick
  rocks `grug_materials:slate`/`:basalt` (Round 24), never tier rock. This
  pass replaces immutable-input native stone and terrain-fill stone (below).
  It skips air, liquids, ores, dungeon blocks, functional volumes and every
  protected or excluded surface. Its depth loop is clipped at y = -37. The native ore records (gravel blob, five deep
  strata of the tier rocks `grug_materials:t2_stone`..`t6_stone`, three
  decorative nests) remain authoritative below it.
- **Terrain fill (Round 24, rulings 9–15).** Where the final surface lies
  above native v7, the terrain fill (R5 opcode 27, `[-37, terrain_y - 1]`)
  closes the gap with `default:stone`. A fill voxel is stone the fill wrote
  into native void (air, water or plants) that no later stage changed. It is
  treated like native stone near the surface: the resource pass counts it as
  a `default:stone` host with the same budget per 16³ cell and the same veins
  (ores stay in `default:stone` only), and the shallow strata above replace
  it. Fill 41 or more nodes below the column's surface (mountain interiors)
  carries sparse horizontal layers: absolute y plus a smooth per-column
  offset (bilinear on a 48-node lattice, ±5 nodes) selects a 13-node slab;
  a slab of the column's zone holds one layer of 2–4 nodes with probability
  9/20, its rock drawn from the biome palette (sandstone, desert stone and
  granite under savanna and beach; desert stone, sandstone and basalt under
  both badlands; basalt, slate and granite under blight and bone forest;
  granite, slate and desert stone under meadows, elf forest and deep forest;
  slate, granite and basalt elsewhere). A 16³ lattice cell holds a
  gravel (3/5) or dirt (2/5) pocket with probability 3/10, or a rock nest
  of the palette's decorative rocks with probability 1/10: an ellipsoid of
  radii 2–3 × 2 × 2–3 inside the cell. Stone stays clearly dominant
  (measured 81 % stone plus 4 % ores in a real mountain interior, 89 % stone
  in the fixture). Nothing carves caves into the fill; the seam to native
  v7 may cut through veins, bands and caves. Lava is unchanged.
- **Cliffs and near-surface nests (Round 24 B2).** In the top 40 nodes
  of a column, below its filler, where the shallow strata apply (same exclusions:
  protected, functional, water, towns), untouched native or fill
  `default:stone` takes the lattice's rock nests; on steep columns (rock
  faces and lips) it also takes the same horizontal layers, so strata break
  through cliff faces in native rock and in fill alike. Gravel and dirt
  pockets stay out of those 40 nodes, the depth-relative shallow strata stay
  off steep columns, and ores and strata bands are never replaced.
- **Decorative nests (Round 24, ruling 14).** Native blob ores place nests
  of `grug_materials:slate` (y −400…−40), `grug_materials:granite`
  (y −900…−200) and `grug_materials:basalt` (below y −600) in
  `default:stone` and every tier rock: blob size 7, one blob per 28³ nodes
  of the range (about one voxel in 120 per rock).
- The map promises no target journey duration. Road placement, visible
  terrain structure and available travel methods determine travel time.
  Strategic separators are physical terrain or explicit water, never
  invisible walls.

## 8. Zone catalog

Biome numbers are positive integer weights over one unbiased palette roll in
the inclusive range 0..99 and total exactly 100 per zone. In authored order,
each entry owns exactly its stated number of roll values. The winning roll
labels one variable-area logical-biome patch, so these weights are not surface-
area quotas and a generated seed need not realize every palette entry in every
zone. Every result belongs to its owning zone's palette; spot checks may
record realized shares. Nothing rerolls or repairs a zone to meet an area
percentage. The faction resource audit in §11 remains binding. “Settled”,
“forest”, “mountain”, “savanna”, “jungle”, “swamp” and “war” refer to the
existing mob families and paired drop tables in `biomes_mobs.md` §3. A
palette does not automatically enable every gatherable or mob of that biome:
the zone's level and explicit content palette still gate them.

Mob families additionally carry the day/night role defined in
`biomes_mobs.md` §4. The closed palette is resolved at the current clock; a
non-capital palette with fewer than two explicit night families admits its
documented family fallback. Empty capital palettes remain
`civic_no_hostiles`, and the start towns (pad and band, §12) still refuse hostile spawns
before palette or fallback authority is considered, from the town's protected floor
upward (its placement height − 100, Round 24 ruling 30); caves deeper
under a start town keep their ordinary population.

POI abbreviations:

- **S** = starting settlement, graveyard and waypoint;
- **C** = capital, king, service hub and waypoint;
- **V** = mandatory village; **O×n** = n ordinary outpost slots;
- **B** = one of the two fixed bandit camps for that race;
- **M** = that race's one peaceful mining camp;
- **W** = a fixed Mirefolk wetland camp;
- **K×n** = n dedicated war-front clash anchors;
- **D/M6** = dragon lair plus the apex mining camp;
- **R:name** = the migrated named-rare route.

Peaceful §8.1 zones use `territory_rule = "accord_home"` and peaceful §8.2
zones use `territory_rule = "throng_home"`. Every level-31–60 ordinary
frontier or island uses `territory_rule = "contested_land"`: both factions may
edit ordinary terrain subject to tools and explicit protected envelopes. The
four Battlegrounds zones use `territory_rule = "contested_land"` too; only
their macro-region key keeps the legacy `holy_grounds` name, without geometry
or rights (§7.1).
`race_region` never changes any of these rights.

### 8.1 Elandor — Accord

| Stable id | Display name | Race | Level / PvP | Biome roll weights | Identity, content and reserved POIs |
|---|---|---|---|---|---|
| `elandor_hearthpine_vale` | Hearthpine Vale | Dwarf | 1–10 peaceful | pine hills 90 / crags 10 | Sheltered pine bowl, warm springs and a novice quarry; settled mobs; day Fox/Ibex from band 2, night Giant Rat; **S** |
| `elandor_copperfell_foothills` | Copperfell Foothills | Dwarf | 11–20 peaceful | pine hills 75 / crags 25 | Copper-stained streams, switchback road and pine terraces; settled mobs; day Fox/Ibex, night Goblin Raid; gravemoss; **V, O, B** |
| `elandor_dur_brannoc` | Dur Brannoc | Dwarf | capital, civic L20–30 profile, peaceful | pine hills 60 / crags 40 | Terraced granite citadel around a forge chasm; no ambient hostiles; **C** |
| `elandor_frostbarrow_shelf` | Frostbarrow Shelf | Dwarf | 21–30 peaceful | pine hills 55 / crags 40 / swamp 5 | Wind shelf, burial cairns and frozen tarns; mountain mobs and day Ibex; night Goblin Raid/Snow Leopard; dragonweed; **V, O, M** |
| `elandor_stormvault_heights` | Stormvault Heights | Dwarf | 31–40 **contested** | crags 75 / snowy crags 25 | Lightning-scarred ridge and a giant natural arch; mountain mobs; day Ibex, night Frost Stray/Goblin Raid/Snow Leopard; **O×2, B, R:Korgan's Bane** |
| `elandor_dawnmere_fields` | Dawnmere Fields | Human | 1–10 peaceful | meadows 85 / deep forest 5 / swamp 10 | Sunrise fields, ponds and hedgerows; settled mobs; day Wild Turkey and band-2 Fox, night Giant Rat; **S** |
| `elandor_goldmead_vale` | Goldmead Vale | Human | 11–20 peaceful | meadows 65 / deep forest 20 / swamp 15 | River mills, orchards and old farm roads; settled mobs, day Fox/Wild Turkey, sunleaf; night Poacher; **V, O, B, R:Grimtusk** |
| `elandor_highcourt` | Highcourt | Human | capital, civic L20–30 profile, peaceful | meadows 80 / deep forest 20 | Brick-and-white-stone city on a river fork; no ambient hostiles; **C** |
| `elandor_whitebridge_shire` | Whitebridge Shire | Human | 21–30 peaceful | meadows 50 / deep forest 35 / swamp 15 | Old arched bridge, oak copses and market villages; settled/forest mobs, marshbloom; night Poacher/Wisp; **V, O, M, W** |
| `elandor_ashenward_march` | Ashenward March | Human | 31–40 **contested** | deep forest 50 / meadows 30 / swamp 20 | Burned woodland, trenches and the first active frontier; forest/war mobs; night Poacher/Wisp/Ashen Treant; **O×2, B, K×2, R:Old Whitefang** |
| `elandor_silverleaf_glades` | Silverleaf Glades | Elf | 1–10 peaceful | elf forest 95 / deep forest 5 | Pale trees, clear streams and circular glades; settled mobs; day Song Bird and band-2 Fox, night Giant Rat and band-3 Poacher; **S** |
| `elandor_starbough_vale` | Starbough Vale | Elf | 11–20 peaceful | elf forest 80 / deep forest 20 | Terraced silverwood slopes and early canopy paths; settled mobs, day Fox, sunleaf; night Poacher; **V, O, B** |
| `elandor_lethariel` | Lethariel | Elf | capital, civic L20–30 profile, peaceful | elf forest 90 / deep forest 10 | Treehouse crown around a lake and white-marble roots; no ambient hostiles; **C** |
| `elandor_lorindor` | Lorindor | Elf | 21–30 peaceful | elf forest 50 / deep forest 30 / swamp 20 | Small woodland state southwest of Lethariel, remembered for pale stags, silverwood orchards, white flowers and marsh-fed berry terraces; night Poacher/Wisp; **V, O, M, W** |
| `elandor_moonfall_wood` | Moonfall Wood | Elf | 21–30 peaceful | elf forest 40 / deep forest 45 / swamp 15 | Crescent lake beneath a fallen great silverwood; forest mobs; night Poacher/Wisp; **O** |
| `elandor_glassroot_wilds` | Glassroot Wilds | Elf | 31–40 **contested** | deep forest 45 / jungle fringe 35 / elf forest 10 / swamp 10 | Huge roots gripping glassy pale cliffs; forest and lower-jungle mobs; night Wisp; **O, B** |

### 8.2 Kragmar — Throng

| Stable id | Display name | Race | Level / PvP | Biome roll weights | Identity, content and reserved POIs |
|---|---|---|---|---|---|
| `kragmar_stillgrave_hollow` | Stillgrave Hollow | Undead | 1–10 peaceful | blight 90 / bone forest 5 / swamp 5 | Quiet cemetery basin and sheltered gravewood; settled mobs; night Giant Rat; **S** |
| `kragmar_mournfen` | Mournfen | Undead | 11–20 peaceful | blight 60 / bone forest 10 / swamp 30 | Drowned grave roads, black reeds and low mist; settled/swamp mobs, night Wisp, gravemoss; **V, O, B, W** |
| `kragmar_nhal_veyr` | Nhal Veyr | Undead | capital, civic L20–30 profile, peaceful | blight 75 / bone forest 25 | Black-stone necropolis on stepped terraces; no ambient hostiles; **C** |
| `kragmar_ossuary_reach` | Ossuary Reach | Undead | 21–30 peaceful | blight 40 / bone forest 50 / swamp 10 | Fossil ridges and gravewood copses; forest mobs, night Gravewood Treant, dragonweed; **V, O, M** |
| `kragmar_blackwind_rise` | Blackwind Rise | Undead | 31–40 **contested** | bone forest 65 / blight 30 / swamp 5 | Ash-wind upland crossed by natural bone arches; forest mobs, night Gravewood Treant; **O×2, B, R:Marrowclaw** |
| `kragmar_sunscar_flats` | Sunscar Flats | Orc | 1–10 peaceful | savanna 95 / badlands 5 | Dry golden grass, shade rocks and shallow waterholes; settled mobs; day Plains Runner (fighting prey) and band-2 Scorpion, night Giant Rat and band-2 Scorpion and Sun-Dried Husk; **S** |
| `kragmar_redtusk_savanna` | Redtusk Savanna | Orc | 11–20 peaceful | savanna 75 / badlands 25 | Red gullies, acacia wells and hunting roads; settled/savanna mobs, sunleaf; night Scorpion and Sun-Dried Husk; **V, O, B, R:Ashmaw** |
| `kragmar_gor_drazhak` | Gor Drazhak | Orc | capital, civic L20–30 profile, peaceful | savanna 60 / badlands 40 | Adobe-and-basalt fortress at a mesa crossroads; no ambient hostiles; **C** |
| `kragmar_speargrass_reach` | Speargrass Reach | Orc | 21–30 peaceful | savanna 55 / badlands 40 / swamp 5 | Tall cutting grass, dry rivers and hunting stones; savanna/mountain mobs; day Speargrass Tiger; night Scorpion/Goblin Raid; **V, O, M** |
| `kragmar_bannerbreak_mesa` | Bannerbreak Mesa | Orc | 31–40 **contested** | badlands 70 / savanna 25 / swamp 5 | Wind-torn standards, red trenches and siege ramps; mountain/war mobs, night Scorpion/Goblin Raid, dragonweed; **O×2, B, K×2, R:Dustwing** |
| `kragmar_kapok_cradle` | Kapok Cradle | Troll | 1–10 peaceful | jungle edge 90 / swamp 10 | Sheltered jungle basin beneath one giant kapok; settled/jungle-edge mobs; day band-2 Tapir, Viper and Jungle Lynx, night Giant Rat and band-2 Viper; **S** |
| `kragmar_raincall_basin` | Raincall Basin | Troll | 11–20 peaceful | jungle edge 65 / deep jungle 15 / swamp 20 | Monsoon pools on stepped slopes; settled/jungle-edge mobs, day Tapir, night Viper, sunleaf; **V, O, B** |
| `kragmar_kezamba` | Kezamba | Troll | capital, civic L20–30 profile, peaceful | jungle edge 75 / deep jungle 20 / swamp 5 | Stilt-and-stone city around a stepped cenote; no ambient hostiles; **C** |
| `kragmar_whispering_reedlands` | Whispering Reedlands | Troll | 21–30 peaceful | jungle edge 45 / deep jungle 25 / swamp 30 | Flooded reed maze crossed by raised totem paths; jungle-edge/swamp mobs, day Tapir, night Wisp, marshbloom; **V, O, M, W** |
| `kragmar_totemwater_reach` | Totemwater Reach | Troll | 21–30 peaceful | jungle edge 35 / deep jungle 45 / swamp 20 | Broad river mouth and marsh ponds marked by colossal carved totems; jungle-edge/swamp mobs, day Tapir, night Wisp; **O** |
| `kragmar_thunderroot_wilds` | Thunderroot Wilds | Troll | 31–40 **contested** | deep jungle 55 / east badlands 30 / swamp 15 | Storm forest with exposed roots and ochre stone islands; jungle mobs; night Bog Witch; **O, B** |

### 8.3 Battlegrounds and offshore dragon islands

All six zones below have one cultural `race_region` and automatic-PvP status
`contested`. The four mainland zones form the shared, mutable Battlegrounds;
the two endpoint zones are editable contested islands separated from the
mainland by full-column immutable ocean channels. §11 defines their resource
and terrain rules without deriving political ownership from cultural origin.

| Stable id | Display name | Race region | Level | Biome roll weights | Identity, content and reserved POIs |
|---|---|---|---|---|---|
| `front_wyrmglass_crown` | The Wyrmglass Crown | Dwarf | 60 | crags 55 / snowy crags 30 / beach 15 | Offshore ring-mountain island, crystalline fault terraces and dragon hoard; mountain/war mobs; night Frost Stray/Snow Leopard/Rift Spawn; **D/M6, K×1** |
| `front_gravesalt_escarpment` | Gravesalt Escarpment | Undead | 51–59 | bone forest 55 / blight 15 / swamp 15 / beach 15 | White salt cliffs cut with tomb galleries and a coastal war road; forest/war mobs; night Bog Witch/Rift Spawn; stormkelp; **K×2** |
| `front_broken_causeway` | The Broken Causeway | Human | 31–40 | meadows 40 / deep forest 25 / swamp 35 | Collapsed royal road over marsh and river, with remnants of a raised causeway, fords and an aqueduct; war mobs; 24 h War Construct; night Wisp/Bog Witch; **K×3, R:Captain Bonerattle** |
| `front_shattered_line` | The Shattered Line | Orc | 41–50 | badlands 65 / savanna 20 / swamp 15 | Main battlefield of breached walls, western trenches, eastern siege ramp and burned no-man's-land; mountain/war mobs; day Speargrass Tiger; 24 h War Construct; night Scorpion and Sun-Dried Husk; **K×3, R:Captain Bonerattle** |
| `front_skyglass_canopy` | The Skyglass Canopy | Elf | 51–59 | jungle fringe 60 / deep forest 25 / elf forest 15 | Cloud forest above pale escarpments, hanging roots and two high approaches; high-jungle/war mobs, crimson lotus; **K×2, R:Silkfang** |
| `front_stormscale_summit` | Stormscale Summit | Troll | 60 | deep jungle 50 / east badlands 20 / swamp 15 / beach 15 | Offshore jungle-clad volcanic island, thunder terraces and dragon hoard; high-jungle/war mobs; night Bog Witch/Rift Spawn; stormkelp; **D/M6, K×1, R:Emerald Coil** |

The identity column is flavour. Routes, trenches, siege ramps, galleries and
approaches named there may appear as POI or dressing content (§8.4); the road
network (§9.2) owes none of them.

Underground casts ignore the surface clock. Light and the exact y band drive
spawning, and flying families have no near-ground bias.

| Depth band | Level band | Cast |
|---|---|---|
| 0 to −100 | 1–6 | Cave Bat, Cave Crawler, Giant Rat and Spiderling |
| −100 to −300 | 6–18 | Giant Spider, Lost Miner, Blood Bat, Goblin Miner and Goblin Miner Slinger |
| −300 to −500 | 18–30 | Stone Golem, Oerkki, Glowwing and Crystal Shard |
| −500 to −700 | 30–42 | Dungeon Master, Crystal Shard, Oerkki and Stone Golem |
| −700 to −1000 | 42–60 contested T5 | Lava Flan, Ember Wisp, Dungeon Master and Stone Mite |
| Below −1000 | 60 contested T6 | Lava Flan, Ember Wisp, Land Guard and Rift Spawn |

### 8.4 Relief character and landmarks

Rewritten for Round 22 (D13). Every zone keeps its relief character id
(§7.6) and has one or two strong landmark features. Each terrain landmark is
a soft field of one type—ridge band, escarpment, mesa, valley or dry river,
basin or lake, dome, caldera or peak—with a warped outline, free orientation
and a soft fade (§7.6). A capital's named feature is part of its civic
blueprint and fitting, not a terrain field, because the capital damping would
flatten a field anyway. Landmarks never block a road or a fixed anchor, and
roads route around or through them by cost (§9.2).

Landmark ids are stable where content or story uses them. Only three are
player-visible today: `kezamba_cenote` (quest "Smoke Above the Cenote"),
`wyrmglass_dragonspire` and `stormscale_dragonroost` (world-map labels).

| Zone | Character | Landmarks (type): intent |
|---|---|---|
| Hearthpine Vale | `lowland` | `hearthpine_bowl` (basin): sheltered low bowl around the start with warm springs and a low wooded rim |
| Copperfell Foothills | `rolling_hills` | `copperfell_drainage` (valley): copper-stained stream valleys running down to the west coast |
| Dur Brannoc | `plateau` | `dur_brannoc_granite_terrace`, `dur_brannoc_forge_chasm` (civic): granite citadel terraces around the forge chasm |
| Frostbarrow Shelf | `plateau` | `frostbarrow_escarpment` (escarpment): the visible edge of the wind shelf; `frostbarrow_tarns` (basin): shallow frozen tarns on the shelf |
| Stormvault Heights | `highland` | `stormvault_arch` (ridge band): a lightning-scarred ridge carrying the giant natural arch |
| Dawnmere Fields | `lowland` | `dawnmere_headwaters` (basin): shallow spring ponds and streams among the fields |
| Goldmead Vale | `lowland` | `goldmead_millriver` (valley): the mill river's broad valley floor |
| Highcourt | `rolling_hills` | `highcourt_riverfork` (civic): the raised city between two river arms |
| Whitebridge Shire | `lowland` | `whitebridge_crossing` (valley): the main river valley with the old arched bridge |
| Ashenward March | `rolling_hills` | `ashenward_burnscar` (basin): a burned hollow that marks the old war line |
| Silverleaf Glades | `lowland` | `silverleaf_gladechain` (basin): a chain of large round glades joined by clear streams |
| Starbough Vale | `rolling_hills` | `starbough_canopy_steps` (escarpment): terraced silverwood slopes |
| Lethariel | `rolling_hills` | `lethariel_crownlake` (civic): the central lake inside the tree-crown city |
| Lorindor | `rolling_hills` | `lorindor_silverorchards` (dome): gentle orchard hills; `lorindor_berrymarsh` (basin): the marsh depression with berry terraces |
| Moonfall Wood | `lowland` | `moonfall_crescent` (lake): the crescent lake beneath the fallen great silverwood |
| Glassroot Wilds | `highland` | `glassroot_pale_cliffs` (escarpment): pale glassy cliff steps rising toward the front |
| Stillgrave Hollow | `lowland` | `stillgrave_basin` (basin): the quiet cemetery basin around the start; `stillgrave_ringbarrows` (ridge band): a broken ring of low grave mounds around the basin, which the start dressing refers to |
| Mournfen | `wetland_delta` | `mournfen_drowned_roads` (basin): the black-reed marsh with its drowned grave roads |
| Nhal Veyr | `plateau` | `nhal_veyr_necropolis` (civic): the raised necropolis of grave terraces |
| Ossuary Reach | `rolling_hills` | `ossuary_spine` (ridge band): one prominent fossil ridge across the zone |
| Blackwind Rise | `highland` | `blackwind_bonearches` (ridge band): the upland with natural bone arches; `blackwind_ashcuts` (valley): ash-wind valleys |
| Sunscar Flats | `lowland` | `sunscar_waterholes` (basin): shallow waterholes among shade rocks |
| Redtusk Savanna | `rolling_hills` | `redtusk_gullies` (dry river): branching red dry gullies |
| Gor Drazhak | `plateau` | `gor_drazhak_crossmesa` (civic): the basalt mesa at the four-way crossing |
| Speargrass Reach | `rolling_hills` | `speargrass_dryriver` (dry river): a wide seasonal riverbed; `speargrass_hunting_stones` (mesa): low tablelands with standing stones |
| Bannerbreak Mesa | `plateau` | `bannerbreak_crowned_mesa` (mesa): the high tableland crowned by torn standards |
| Kapok Cradle | `lowland` | `kapok_worldtree_basin` (basin): the sheltered basin under the giant kapok |
| Raincall Basin | `rolling_hills` | `raincall_falls` (escarpment): stepped slopes with monsoon pools |
| Kezamba | `plateau` | `kezamba_cenote` (civic): the stepped central cenote |
| Whispering Reedlands | `wetland_delta` | `whispering_reedmaze` (basin): the flooded reed maze |
| Totemwater Reach | `wetland_delta` | `totemwater_delta` (basin): a broad river mouth among marsh ponds |
| Thunderroot Wilds | `highland` | `thunderroot_exposures` (escarpment): storm-forest steps with exposed roots; `thunderroot_ochresteps` (mesa): ochre rock terraces |
| The Wyrmglass Crown | `mountain` | `wyrmglass_ring` (caldera): the ring-mountain island; `wyrmglass_dragonspire` (peak): the dragon summit, beside rather than on the arena |
| Gravesalt Escarpment | `highland` | `gravesalt_whitewall` (escarpment): the white salt cliffs with several passes |
| The Broken Causeway | `wetland_delta` | `broken_marsh` (basin): marsh, river arms and lakes around the old causeway |
| The Shattered Line | `plateau` | `shattered_breachwall` (ridge band): the long breached ridge of the old fortress line |
| The Skyglass Canopy | `highland` | `skyglass_escarpment` (escarpment): the pale cliff line under the cloud forest |
| Stormscale Summit | `mountain` | `stormscale_caldera` (caldera): the volcanic ring; `stormscale_dragonroost` (peak): the summit edge beside the dragon arena |

The table decides two points the round plan left open: a capital's feature
is civic fitting rather than a terrain field, and the dragon peaks stand
beside the arenas rather than on them.

**Retired as terrain landmarks:** every other former landmark id, among them
the coastal terraces and Mournfen dryward (their successors, the coastal
housing areas, are removed as well, Round 25 ruling 4), trench belts, siege
ramps, rootways, hanging ways, tomb galleries, war-coast strips, fault fields
and gem terraces. None
is player-visible. Their flavor (trenches, siege ramps, colossi, galleries)
may return as POI or dressing content; anchors that stood in them, such as the
apex mining camps, keep their positions. Content that only referenced a retired
id is adjusted when the new mapgen lands.

## 9. Zone neighbors, roads and trails

Rewritten for Round 22 (D9, D14, D15, D18, D19). **Hierarchy: zones, then
roads.** Zones border each other naturally (§7.3) and gameplay neighbors come
from that geometry. The road network is an overlay on top of the finished
world, never the graph that defines it. Form follows function: no road or
graph requirement may shape a zone, and nothing may require a graph to be
"solved". Connectivity is checked, not solved.

### 9.1 Zone neighbors

- Gameplay neighbors for travel, quests and `neighbors(id)` are the
  geometric land neighbors of §7.3.
- The dragon islands have no land neighbors. Their boat connections (§9.4)
  are travel links, not neighbors.

### 9.2 Road network

- **What roads connect.** Capitals, starting settlements and villages, plus
  one endpoint in each contested frontier zone: the outpost or clash site
  nearest the home side. Roads enter the contested zones but need not reach
  the Battlegrounds.
- **Shape of the network.** A spanning tree over those endpoints plus a few
  loops where a loop is short and useful. Junctions are T or Y shaped with at
  most three or four branches; there are no star junctions.
- **Routing (as built, Round 22 Phase 4).** Routes are found once, when
  the world session is built in main, by pathfinding over the water layout's
  16-node grid of the natural terrain (grade, cross slope, rivers, lakes,
  reserved areas), and handed to the map generator as data; the result is
  kept in the world folder and reused on later boots (§13.4). Turns cost, so steep slopes are climbed by serpentines with
  long legs one grid cell (16 nodes) apart. The path is smoothed into a
  curve with a small lateral wiggle on gentle ground, so no long straight
  segment appears.
- **Network.** The capitals of a faction are chained west to east; starts,
  villages and the contested endpoints then join the nearest road (T
  junctions, at least 64 nodes apart); loops are added where the network
  distance between two same-faction settlements within 1,100 nodes is more
  than 1.3 times the straight distance (up to four per world; two to four on
  the tested seeds).
- **Grade (Round 22, D49–D51, D67).** Roads are walkable by players and
  mounts without jumping: the profile runs in half-node steps with a slab on
  every half step, at most ½ node between neighboring road columns (max grade
  1:2). Routing prefers grades gentler than about 1:4; hairpins and junction
  mouths are flat. There are no stairs, also not on trails. The profile both
  cuts and fills and stays near the ground: no long ramps into flat land and
  no high fixed control points (junctions and start gates take their
  ground's height). Where two roads' surfaces touch outside a junction mouth
  (running alongside, a level crossing, a connector beside the road it
  continues, a road's own legs), the later road meets the earlier one's
  level, so the ½-node rule also holds across the contact.
- **Cross-section (Round 22, D44, D67).** Uphill the terrain is cut to road
  level with a slope back of about 1:1 (steeper rock beyond 6 nodes); the cut
  slope keeps the terrain's own surface (grass, dirt, rock), and a low
  retaining wall stands only at the foot of deep cuts. Downhill up to about
  2 nodes is a natural embankment, never a vertical wall; beyond that the road
  is a deck on pillars (no railing, D74). On steep side slopes a half gallery
  (a shallow uphill cut, the downhill half on pillars) is preferred to a deep
  uphill cut. Decks belong to one-sided galleries (typical at serpentines)
  and short valley crossings (both ends on the ground, about 32 nodes or
  less); a deck free on both sides elsewhere is a last resort where the
  terrain falls faster than a road may (D68).
- **Water crossings** are chosen by cost, preferring narrow and shallow
  places. Bridges are the same deck with pillars down to the river bed, at
  least 2 nodes above the water; where the road runs below the
  water surface it fords on a raised bed with at least one node of water over
  it. A cut never lowers ground below nearby water.
- **Materials per race (D48, D74).** Every road has exactly one surface
  material everywhere, on the ground and on decks and galleries on pillars
  alike, and its half-step slabs are of the same material; no railings or
  fences, except that a capital street's deck or bridge carries a fence on
  its open edge where the street runs straight (D75: the heading turns less
  than about 8° over 8 points either side). Pillars are a second material. A true bridge is wood as a
  whole: a raised run (consecutive deck or bridge points of one road) that
  crosses water takes the race's bridge wood on every column, surface and
  slabs, bank to bank and two nodes onto each bank, whatever supports it;
  every other raised run keeps the road material, and fords keep it too. Surface, slab / bridge wood /
  pillars / retaining wall per race: humans cobble / wood / tree trunk /
  stone brick; dwarves stone block / pine wood / stone brick / stone brick;
  elves silver sandstone block / aspen wood / aspen trunk / silver sandstone
  brick; undead stone brick / pine wood / mossy cobble / mossy cobble; orcs
  desert cobble / acacia wood / acacia trunk / desert stone brick; trolls
  mossy cobble / jungle wood / jungle trunk / mossy cobble. Trails use the
  same materials as roads, only narrower (D75); a trail bridge is wood like a
  road bridge.
- **Classes.** Roads between capitals and from capitals toward starts are
  primary (7 wide); roads to villages and into the contested zones are
  secondary (5 wide). See §7.5 for the corridor.
- **Capitals (D59).** Roads end at the edge of a capital's reserved square
  (512 nodes); the capital planner places the gates and connects them to the
  road ends with the same routing, profile and raster (the road module's
  kit, joined to the road layout).
- **Starts.** A start's road leaves its gate toward the own capital along a
  straight 32-node stretch beyond the town's 64-node gate line, level with
  the start pad. A second road from the same start (a loop) branches off the
  first road in a Y junction where it leaves that road's surface instead of
  running on top of its gate stretch.
- Retired: the 57-edge authoritative route graph, hub stations in every zone,
  star junctions, the shared junction grade solve and the capital ingress
  corridors.

### 9.3 Trails

- Every outpost, mine, bandit and Mirefolk camp on the two mainlands that is
  not already a road endpoint gets a trail (3 wide), routed like a road that
  may be a little steeper, joining the nearest road (D19, D67). A trail is
  never dropped for its cost or for a floating deck (D68).

### 9.4 Offshore travel

- The Wyrmglass Crown and Stormscale Summit have no land routes. Their four
  boat routes form a separate travel graph: a southern and a northern
  approach to each island (§7.4). Wyrmglass routes start from the
  Gravesalt Escarpment coast; Stormscale routes start from The Skyglass
  Canopy coast. They are open to both factions and never add a land neighbor.

## 10. Race-region character

| Race region | G1 / G2 | Cultural material / wood | Geographic and content language |
|---|---|---|---|
| Dwarf | Garnet / Sapphire | Runeslate / Mountain Pine | pine shelves, granite, snow ridges, quarries, golems, feathers, heavy leather and gravemoss/dragonweed |
| Human | Citrine / Diamond | Sunwax / Oak | fields, oak woods, river forks, marsh roads, boars, wolves, stags, bandits, leather/cloth, food and sunleaf |
| Elf | Jade / Sapphire | Moonresin / Silverwood | silverwood, pale cliffs, lakes, canopy paths, forest/jungle predators, silk, scaled hide, berries and high-tier lotus |
| Undead | Citrine / Ruby | Gravesalt / Gravewood | blight basins, bone ridges, salt cliffs, drowned roads, undead/forest families, cloth, leather and gravemoss/dragonweed |
| Orc | Garnet / Diamond | Red Ochre / Spikethorn Acacia | ochre grass, dry rivers, red mesas, siege earthworks, savanna/mountain families, feathers, leather and golem materials |
| Troll | Jade / Ruby | Spirit Resin / Kapok | kapok basins, rivers, reed mazes, storm jungle, swamp/jungle families, silk, scaled hide, marshbloom and high-tier lotus |

Race visuals may use different trophies and building materials, while the
paired base drop tables remain economically equivalent.

G1 comprises Citrine, Garnet and Jade; G2 comprises Diamond, Sapphire and
Ruby. Accord therefore has native Diamond/Sapphire and seeks foreign Ruby;
Throng has native Diamond/Ruby and seeks foreign Sapphire. The six universal
metal/pick tiers never consume these regional gems or cultural materials, so a
player can reach the contested source before an ordinary high-tier gear recipe
asks for it.

## 11. Resource, loot and POI budgets

**Round 22 note (2026-09-25):** the budgets and parity rules below are
design targets, confirmed by spot checks on representative seeds (§14.1),
not by multi-seed population gates, a resource census or a release
supply/access gate. Sampling and hashing algorithms are specified by the
code, not by this document.

- Each race has exactly one safe start, one home zone, one capital, at least
  one level-21–30 heartland and one level-31–40 frontier; exactly one
  endgame-front zone is culturally assigned to its `race_region`. Elf and Troll
  each have a second heartland; their zones are correspondingly smaller so
  this is not extra resource volume.
- Each race receives exactly **two mandatory villages, four ordinary outpost
  slots, two bandit camps and one peaceful mining camp**. Each faction
  therefore retains WP6's 12 outposts and 6 bandit camps.
- For every race, the first bandit slot is in its 11–20 home zone and supplies
  linen cloth; the second is in its 31–40 frontier and supplies heavy cloth.
  This fixed one-to-one layout keeps Tailoring access equal despite different
  geography.
- Fixed Mirefolk camps are Whitebridge Shire and Lorindor for the Accord,
  Mournfen and Whispering Reedlands for the Throng.
- Named rares migrate as listed in §8. Their level is clamped into the owning
  zone's band; no old ring coordinate survives.
- Every non-city zone exposes its race region's assigned G1 and G2 species only
  where their authored depth/tier curves permit them. G1 rises through T4,
  retains its T4 density in T5/ordinary T6 and then receives the shared deep-T6
  multiplier. G2 is sparse in T4 (1×), clearer in T5 (2×) and abundant in
  ordinary T6 (4×), with initial targets of approximately one eligible ore per
  2,048/1,024/512 host nodes per species (Round 21 calibration). All G2 requires a T4 pick to harvest.
- **Round 21 density calibration (accepted 2026-09-24):**
  numbers below are eligible host nodes per target resource node. Dashes mean
  absent. Tiers are absolute-Y strata; existing deep multipliers apply afterward.
  Keep existing vein caps and first-appearance/harvest boundaries. These are
  placement budgets, not independent discovery odds or measured mining time.

  | Resource | T1 | T2 | T3 | T4 | T5 | T6 |
  |---|---:|---:|---:|---:|---:|---:|
  | Coal | 64 | 128 | 128 | 128 | 128 | 128 |
  | Copper | 96 | 192 | 384 | 384 | 384 | 384 |
  | Tin | 96 | 192 | 384 | 384 | 384 | 384 |
  | Iron | 128 | 96 | 192 | 384 | 384 | 384 |
  | Quartz | 128 | 256 | 512 | 512 | 512 | 512 |
  | Gold | — | 512 | 256 | 128 | 256 | 256 |
  | Silver | — | — | 256 | 128 | 256 | 512 |
  | Emberglass | — | — | — | 256 | 128 | 256 |
  | Abyssal Crystal | — | — | — | — | 512 | 256 |
  | Assigned G1 species | — | 2048 | 1024 | 512 | 512 | 512 |
  | Assigned G2 species | — | — | — | 2048 | 1024 | 512 |

  The quarter-density floor retains older inputs at depth; T1 Iron keeps its
  former density as a bootstrap exception. Gold peaks at T4 and remains
  useful at T5/T6, matching Goldsmith demand.
- Natural-resource placement and its accessible-host denominator admit only
  horizontal classes `land` and zone-owned `planned_water`. Rivers, lakes,
  marsh channels, cenotes and the landward bay masks therefore retain their
  underground geology. `coastal_shelf`, `deep_ocean` and
  `immutable_dragon_channel` admit no natural resource. Eligibility still
  requires the exact WP43 stratum host at y; water, bed material, routes,
  dungeons, foreign nodes and protected content are not hosts.
- **Fixed and protected ground** (every anchor's claim envelope — a capital's
  protected city, a start town, the square of a POI, village, camp or
  outpost — and every hard core) hosts no
  natural resource inside its protected volume: from its placement height −
  100 upward (Round 24 ruling 30). The placement height is the anchor's
  fitted surface; where several such
  shapes hold a column, the lowest floor wins. Below that floor the column
  takes ores, gems, rock layers and nests like any other ground (the former
  rule kept these columns ore-free down to y = −700).
- **Below the floor everything is ordinary ground** (ruling 30 addendum,
  2026-09-29). Where a column's claim exclusion comes only from protected
  shapes (anchor envelopes, hard cores, hard footprints), the writers apply
  their normal rules below its floor: world-content cave rows (cave cap,
  ember moss) at the cave voxel's y; P9G gathering roots at the root y (the
  dragon islands' coast envelopes stay nonblocking on dry land, as always);
  world-content surface rows at the plant's y; cultural reservations when
  the whole reservation box (root .. root + 7) lies below the floor; strata
  bands and the near-surface nests and cliff layers per voxel. This matters
  for POI envelopes on steep ground: an envelope 112 nodes wide can reach
  shore or valley ground 100–300 nodes below its anchor. Start towns and
  capitals never do (their lowest ground lies 79–100 nodes above the
  floor). Non-protection exclusions keep applying at every depth to the
  writers they bind today: planned-water and coast shapes (the cave rule
  and every surface writer; P9G excepted on the dry islands), the overlay
  exclusions (road corridors, inland water, water banks) for the surface
  writers, and functional kinds and hard foundations at the surface. Runtime
  renewal applies the same rules (`farming.md`).
- **Natural-resource root sampling:** each resource/16-node cell/host/tier/
  deep-band group keeps its eligible-host count, density budget and balanced
  capped vein targets. Roots are drawn from a deterministic per-world stream
  without repeats, so natural ore is finite and reproducible for a world seed.
- **Natural-resource parity:** the six race regions receive about the same
  natural-resource rate, within roughly 5%: accepted natural veins per
  accessible host volume, counting all universal resources plus the region's
  assigned G1 and G2. Placed natural nodes are a separate density concern.
  Spot-checked on representative seeds.
- Every race region supplies its cultural material ordinarily at the surface
  for its own architecture, trade and quests and supplies one concentrated T4
  source in exactly one race-frontier zone. Foreign cultural material is
  optional PvP-counter input and never a universal progression requirement.
  Ordinary opportunity density is exactly one per 4,096 eligible logical-
  biome columns; the listed concentrated zone uses one per 1,024. No
  Battlegrounds zone receives the concentrated rate.

  | Race | Cultural material | Eligible logical biomes | Concentrated T4 zone |
  |---|---|---|---|
  | Human | Sunwax | `grug_meadows`, `grug_deep_forest` | `elandor_ashenward_march` |
  | Dwarf | Runeslate | `grug_pine_hills`, `grug_crags`, `grug_crags_snowy` | `elandor_stormvault_heights` |
  | Elf | Moonresin | `grug_elf_forest`, `grug_deep_forest`, `grug_jungle_fringe` | `elandor_glassroot_wilds` |
  | Undead | Gravesalt | `grug_blight`, `grug_bone_forest`, `grug_swamp`, `grug_beach` | `kragmar_blackwind_rise` |
  | Orc | Red Ochre | `grug_savanna`, `grug_badlands` | `kragmar_bannerbreak_mesa` |
  | Troll | Spirit Resin | `grug_jungle_edge`, `grug_deep_jungle`, `grug_swamp`, `grug_badlands_east` | `kragmar_thunderroot_wilds` |

  R6 selects and records deterministic invisible opportunity slots; WP33
  registers and realizes their visible source features through the same WP40
  writer. Every slot reserves the centred 5 by 5 horizontal square from
  `surface_y - 1` through `surface_y + 7`. A registration may occupy any
  subset of that envelope; a larger footprint is rejected. Slots never move,
  retry or search for fallback ground, and the envelope is collision space,
  not a structure, yield promise or R6 world mutation. The ratified WP33
  registration is exactly one source cell at `(0, 1, 0)` with
  `lower_two_policy = "preserve_p7"`; it replaces neither P7 top nor filler.
  No production world is generated with permanently empty cultural
  reservations.
- Each faction-native exclusive G2 species has at least one practical
  contested level-31+ surface route: Ruby for Accord raiders and Sapphire for
  Throng raiders. The y = −701 deep opening also permits cross-border mining
  beneath the opposing race-region columns. Trade remains an alternative, never the only route.
- Every level-31–60 frontier and dragon-island zone has no home-faction
  construction owner. Both factions may dig and place ordinary terrain there,
  subject to tools, explicit hard-protected capital or functional-anchor
  envelopes and the protected road corridors and POI boxes (`world.md` §2
  R1b). Beyond those, road and camp grading envelopes do not block terrain
  mutation.
  This applies equally to all six faction frontier approaches and to both
  dragon islands.
- The four Battlegrounds zones follow the same shared construction rule at
  every y: both factions may dig and place ordinary terrain, while no housing
  claim may privatize it. Explicit hard-protected functional anchors retain
  their bounded envelopes. The immutable ocean channels around the dragon
  islands remain non-editable at every y; protected lair/camp structures keep
  their own envelopes.
- `race_region`, `territory_rule` and `pvp_rule` are independent registry
  fields. In particular, a Human/Orc/Dwarf/Undead/Elf/Troll cultural label
  grants no home-faction terrain privilege in any contested zone.
- For paired base resources—leather grades, cloth, silk, feathers, healing
  herbs, spices and alchemy reagents—the expected gather/drop opportunity per
  faction must be within **±10%** over the reachable zone area of each level
  bracket. Different families may carry the same paired table.
- T1 gravemoss is supplied by Copperfell Foothills / Mournfen; T2 dragonweed
  by the Dwarf/forest side and Undead/Orc wilds; T3 crimson lotus only by the
  level-51–59 Skyglass Canopy / level-60 Stormscale Summit palettes. Marshbloom
  uses Lorindor, Whitebridge Shire, Ossuary Reach and Whispering Reedlands;
  this 2026-08-31 ruling replaces the former Mournfen row with Ossuary Reach
  to preserve paired level-21–30 supply. Stormkelp uses both endpoint island
  coasts and the Gravesalt, Skyglass and Shattered Line coasts.
- Zone level controls gear tier. A visual biome patch never authorizes a mob,
  drop or gathering tier above the zone's content palette.

The exact WP33 named-zone source sets are closed as follows. A source requires
both membership in its set and its matching logical-biome/host predicate; a
compatible biome patch outside these ids grants no source.

| Source | Exact stable zone ids |
|---|---|
| Gravemoss | `elandor_copperfell_foothills`; `kragmar_mournfen` |
| Dragonweed | `elandor_ashenward_march`; `elandor_frostbarrow_shelf`; `kragmar_bannerbreak_mesa`; `kragmar_ossuary_reach` |
| Crimson Lotus | `front_skyglass_canopy`; `front_stormscale_summit` |
| Sunleaf | `elandor_goldmead_vale`; `elandor_starbough_vale`; `kragmar_raincall_basin`; `kragmar_redtusk_savanna` |
| Marshbloom | `elandor_lorindor`; `elandor_whitebridge_shire`; `kragmar_ossuary_reach`; `kragmar_whispering_reedlands` |
| Stormkelp | `front_gravesalt_escarpment`; `front_shattered_line` (swamp mud only); `front_skyglass_canopy`; `front_stormscale_summit`; `front_wyrmglass_crown` |
| Potato | `elandor_ashenward_march`; `elandor_dawnmere_fields`; `elandor_goldmead_vale`; `elandor_whitebridge_shire`; `front_broken_causeway` |
| Corn | `elandor_ashenward_march`; `elandor_dawnmere_fields`; `elandor_goldmead_vale`; `elandor_whitebridge_shire`; `front_broken_causeway`; `front_shattered_line`; `kragmar_bannerbreak_mesa`; `kragmar_redtusk_savanna`; `kragmar_speargrass_reach`; `kragmar_sunscar_flats` |
| Melon | `elandor_glassroot_wilds`; `front_skyglass_canopy`; `front_stormscale_summit`; `kragmar_kapok_cradle`; `kragmar_raincall_basin`; `kragmar_thunderroot_wilds`; `kragmar_totemwater_reach`; `kragmar_whispering_reedlands` |
| Mushroom | `elandor_ashenward_march`; `elandor_glassroot_wilds`; `elandor_lorindor`; `elandor_moonfall_wood`; `elandor_whitebridge_shire`; `front_broken_causeway`; `front_gravesalt_escarpment`; `front_skyglass_canopy`; `front_stormscale_summit`; `kragmar_blackwind_rise`; `kragmar_ossuary_reach`; `kragmar_speargrass_reach` (swamp mud only); `kragmar_thunderroot_wilds`; `kragmar_totemwater_reach`; `kragmar_whispering_reedlands` |
| Wild Cocoa | `front_skyglass_canopy`; `front_stormscale_summit` |
| Rock Salt | `front_gravesalt_escarpment`; `front_stormscale_summit`; `front_wyrmglass_crown` |

The exact host rules are: Gravemoss uses Pine Hills coniferous litter in
Copperfell or Blight dirt in Mournfen; Dragonweed uses Crags gravel in
Frostbarrow, Deep Forest litter in Ashenward, Bone Forest litter in Ossuary or
Badlands mesa clay in Bannerbreak; Crimson Lotus uses Canopy litter in
Skyglass Jungle Fringe or Stormscale Deep Jungle; Sunleaf uses the owning
zone's Meadows grass, Elf Forest silver litter, Savanna dry grass or Jungle
Edge rainforest litter; Marshbloom uses Swamp mud; Potato uses Meadows grass;
Corn uses Meadows grass or Savanna dry grass; Melon uses Jungle Edge
rainforest litter or Deep Jungle/Jungle Fringe canopy litter; Mushroom uses
Deep Forest litter, Bone Forest litter or Swamp mud; and Wild Cocoa uses Deep
Jungle/Jungle Fringe canopy litter.

Stormkelp and Rock Salt are shore predicates rather than engine beach
decorations. Their root is dry land with exact accepted P7 support and at least
one cardinal neighbor classified as planned water, coastal shelf, deep ocean
or immutable dragon channel; diagonal contact is insufficient. Rock Salt also
requires logical biome `grug_beach`. In Gravesalt its support is exactly
`default:sand`; in Stormscale and Wyrmglass its support is `default:stone` or
`default:gravel`. These are zone-scoped alternatives, not a global expansion
of accepted hosts. The analytic P7 support and actual settled/lower-owner
support must identify the same accepted node. Stormkelp does not require the
beach biome, so the Skyglass coast also hosts it. The three
Rock Salt zone endpoints remain exact; Salt Crust is a distinct Cooking item.

The claim-exclusion records `exclude:coast:island_wyrmglass` and
`exclude:coast:island_stormscale` describe whole-island envelopes rather than
occupied cells. For P9G gathering placement only, either record is therefore
nonblocking when the candidate's authenticated water class is exactly `land`.
All earlier anchor, route and authored-water exclusions keep priority, every
other coast exclusion remains blocking, and support, clearance, occupancy and
one-cell settlement checks are unchanged.

## 12. Capital and start envelopes

- Every capital keeps a 512×512 reserved area (D59); roads end at its edge and
  the planned city lies inside it. **The protected city (Round 22, D76)** is
  the capital's hard-protected POI and its claim and resource exclusion
  envelope at once: everything inside the planned wall line, the wall or
  palisade with its gatehouses and turrets, the capital's own civic lake where
  the outline crosses it (Lethariel's crown lake, Kezamba's cenote), and a
  band of at least 12 nodes beyond the edge's outermost structure (a gatehouse
  corner: gatehouses stay compass-aligned while their gates slide along the
  wall) — 21 nodes from the
  wall line, about 17.5 beyond a stone wall's face. The band grows no trees and
  no ground cover, so players see where the protection ends; beyond it the
  zone's ordinary rules apply (vegetation, ground cover, resources, caves;
  capital zones hold no claims, `housing.md` §2). The shape is computed
  once per world start from the capital layout
  (`wp40/capital_protection.lua`, integer column intervals per row, a lookup
  of one row and one or two comparisons) and always lies inside
  the reserved square and the capital zone (the zone field keeps the 532-node
  square round the reserved area in-zone on land). It replaces the former
  532-node protected square and the 704-node claim square. Capital lookup
  uses the same zone-based level rule as other land. Hostile ambient spawning
  is disabled (the capital zones' mob palettes are empty) and level-60 guards
  remain explicit.
- Capital grading flattens only the dry capital-owned 96×96 civic core.
  The target reference interval for natural height N is [N-24, N+16],
  intersected over core columns with water lower bounds. A feasible interval
  clamps the natural centre; an infeasible interval uses its rounded midpoint.
  The highest civic water level plus one remains a hard lower bound even when
  the terrain interval is infeasible. Any resulting cut/fill excess is
  reported rather than hidden or used to move the fixed core.
  Outside the core a 40-node collar (the capital profile's `capital_collar`)
  with a noisy edge (the POI collar rule of
  §7.6) blends back to the damped terrain; there are no terraces and no square
  blend (Round 22 capital planner, D70), so no straight grading edge.
- **Round 22 (D7, D11, D16, D28, D76):** terrain roughness is damped around
  each capital before the capital planner runs (the planner lays the city out
  on this calm ground). The calm bowl is round and centred on the civic core:
  no fine detail out to 200 nodes, damping below 0.1 to about 255–265,
  full natural relief again by about 400–580 along an irregular,
  noise-varied edge (no straight edge, no cliff ring); trees and ground cover
  return right beyond the protected band (first bullet). Over 48 seeds the
  planned wall reached at most 250 nodes from the anchor (95 % of the outline
  within 215), so every layout stands on calm ground. Only the civic core is
  flat; the ground around it keeps long-wave hills and hollows of limited
  height (§7.6). Each capital's target ground height sits well below its
  region's clouds (§7.6).
- A fixed 96×96 civic core contains the king's hall, the current waypoint
  socket and principal service court, and four core gates on the axes. It
  stays as authored and free of natural water. The future WP17 waypoint pad
  may stand anywhere in the city (user decision 2026-09-29, WP audit A5).
- **The capital planner (Round 22, D60, D69, D70, D72; Round 26 Lane W; as
  built):** once per world start, in main, after height, water and roads,
  every capital's city is laid out in its landscape
  (`wp40/capital_planner.lua`), and the layout travels to emerge with the
  water and road layouts. Per capital and seed:
  - an organic outline of about 100 k m² (a rough guide, D21) inside the
    reserved 512 square, which avoids water and steep ground and keeps a
    26-node band to the reserved area's edge as countryside. Since Round 26
    (plan rulings 1–4) it is more irregular but still **star-shaped**: one
    wall point per ray from the anchor, so `r_at`/`inside` are unchanged. It
    has less smoothing and more outline noise, snaps to nearby crests, slope
    tops and shorelines, prefers the near bank of a river or lake (water met
    beyond about 70 nodes out is crossed only at three times the cost), and
    each ray is clamped against the broadly smoothed outline so there are no
    deep bays or lobes;
  - **a character per capital** (D72 follow-up; settings table `M.STYLE`,
    applied after the edge kind's settings in `r7_capitals.lua`), within the
    planner's legality rules:
    - *Highcourt*, royal city: a broad curtain following its river, towers at
      bends and beside the gatehouses, two rings plus the quay canal and a
      large royal plaza on the long side's avenue;
    - *Dur Brannoc*, mountain hold: an angular wall of seven to nine straight
      faces on the crests with a tower on every corner (accepted by the user
      although it breaks with the other cities' style), the outer ring
      parallel to the faces and a star of straight radial streets;
    - *Nhal Veyr*, walled necropolis: a long closed curtain with a steady
      tower rhythm, one round ring only, and rows of lanes out to the wall,
      each ending in a small square; graveyards and fields mix with houses;
    - *Gor Drazhak*, war camp: the roughest, jagged palisade, gates turned
      the same way into a pinwheel of winding avenues, a large war yard, a
      broken outer ring, many cross-lanes and lanes out to the wall;
    - *Lethariel*, lakeside city: a flowing curtain along the crown lake,
      few towers (about 7–10), gates turned the other way and an off-centre
      inner ring;
    - *Kezamba*, jungle city: an irregular palisade round the cenote, an
      off-centre inner ring, a market plaza, winding avenues and lanes into
      the green.
    The open land between the outer ring and the wall is a mix of fields and
    houses; no capital is enlarged to fill it;
  - four gates, one per cardinal direction, slid along the outline toward the
    incoming road ends and off water; road ends reach the reserved area's edge
    anywhere (§9), and connector roads (the road module's own routing,
    half-step profile and raster) join them to their gates;
  - avenues from each core gate through its city gate, terrain-bent ring
    lanes (two by default; their count, shape and gaps vary with the
    character above), cross-lanes and small flat squares at crossings and
    lane ends; streets and connectors are road-module roads
    (≤ ½ node between neighbouring columns, slabs on half steps, bridges over
    water, §9); the street surface stops at the civic core's edge, where the
    core gate takes the passage over. No street ends over water: where the
    core's edge on an axis is civic water without a core landing
    (Lethariel's crown mere) that avenue starts on the dry shore nearest the
    core gate, and an avenue whose gate has no connector runs on past wet
    ground outside the gate to the first dry ground;
  - the existing district plots, each turned in quarter turns so its entry
    faces its street, with a short path to it; the four districts stay
    recognisable groups (one quarter each where the ground allows, overflow
    into a neighbouring quarter). Required plots (the inn, the eight service
    plots with the cook and the stable) are always placed (a capital missing
    one fails the load, named); named buildings are left out only when no
    legal spot remains anywhere (rare), fill dressings first. Placement runs in tiers
    (required, other named buildings, fill), each through all its passes
    (own quarter, neighbours, opposite, relaxed anywhere; fill only the first
    two) before the next tier starts (Round 25 Lane H). If a plan still
    leaves out a named or required building, the planner replans the city at
    +8 % and then +16 % area (clamped inside the reserved square) and keeps
    the plan with the fewest dropped buildings (Round 26); the load-failure
    guard for required plots stays. Plots never stand in water. Lethariel's mere precinct and Kezamba's shore market stay beside
    their civic lake;
  - the edge by race: a stone curtain with turrets and gatehouses (Highcourt,
    Dur Brannoc, Nhal Veyr, and since Round 23 Lethariel's light curtain), or a
    palisade on its rampart (Gor Drazhak, and since Round 23 Kezamba's
    jungle-log palisade); Lethariel and Kezamba keep the narrower footprint
    their former planted belts were planned with. Walls follow the outline as
    polylines, their walk walkable on half steps, and cross rivers as arcades
    or timber decks with the walk out of the water; a capital's civic lake is
    its edge where it crosses the outline, the wall continuous on land and
    ending a few nodes into the water in a closed head. Towers (Round 26):
    evenly spaced on long stretches at each capital's own rhythm, at sharp
    wall bends (the ordinary turret, no separate bastion shape) and beside
    the gatehouses where the character asks for it;
  - Highcourt's one-level quay canal beside its outer ring lane (D58), sealed
    off natural water.
  The layout is a pure function of the seed and the code, so every boot of a
  world has the same city; it is built on the world's first start and reused
  from the world folder afterwards (§13.4).
- The former 128-node hard-protected capital ingress corridors from each
  front gate to the Battlegrounds are retired (Round 22, D9). Capitals are
  reached by the ordinary roads of §9 and the planner's connectors.
- Four district roles: Market/Professions, Martial/Garrison, Lore/Spiritual
  and Residential/Cultural. Which quarter each takes is the planner's choice
  (by room, with the pinned lake districts above).
- Terrain forms differ by race: Dur Brannoc is a granite terrace, Highcourt a
  gentle river plateau, Lethariel a terraced grove, Nhal Veyr a raised
  necropolis, Gor Drazhak a mesa shelf and Kezamba a drained/stilted cenote
  terrace. None is allowed to depend on accidental v7 land.
- The six kings are equal civic rulers and killable level-65 elite NPCs. Every
  king has exactly four level-60 elite royal guards. The king is the tallest
  figure in his hall: final `visual_size` 1.6 (2.72 nodes, box and model
  alike) against his elite guards' 1.4 (2.38 nodes) (Round 28 ruling 9). No capital is a superior
  faction seat. Shared faction services use the same service definition in all
  three capitals; race services and the king remain local. Essential services
  are delivered by separate passive, invulnerable NPCs and never depend on the
  king being alive.
- A king is the authoritative entity for the five-NPC royal encounter. Its
  throne anchor, ordinary chase/leash rules and 15-second no-contact rule own
  the encounter state. The guards have no independent home target: while the
  king lives they always path toward and follow its current position.
- When the king evades it returns to its throne and heals fully. If the king's
  return path reaches the ordinary failed-path threshold, the king teleports to
  its anchor and all four guards are moved with it in the same reset. A guard
  whose own path fails snaps to the king's current position; it never moves or
  overrides the king. A full reset restores all four guard slots together, so
  raiders cannot permanently dismantle the retinue one guard at a time.
- Killing the king wins the encounter immediately. Any surviving royal guards
  retreat and despawn without additional loot. The king and all four guards
  respawn together at full health after 15 minutes. The absolute wall-clock
  respawn timestamp is persistent and server downtime counts. They receive no
  temporary invulnerability on respawn.
- King rewards use **personal encounter loot**, never one shared Crown drop on
  the ground. The encounter keeps its own participation ledger for the current
  attempt. An enemy-faction player enters it through accepted damage to the
  king or a royal guard, or through effective healing or shielding of an
  eligible participating attacker. The killing blow grants no special claim.
  At the king's death, a living ledger participant must be within **60 nodes**
  of the king to qualify. A ledger participant who died within the previous
  **60 seconds** during that active attempt remains eligible even after
  respawning; death to the royal encounter, another encounter NPC or an enemy
  player all count. Mere presence inside the radius never creates eligibility.
  A full encounter reset clears the participation ledger and every death-grace
  record. Each qualifying participant who is not locked to that king receives
  exactly one Fallen Crown carrying that king's race provenance. Each king
  owns a separate rolling 24-hour, wall-clock loot
  lockout per character. Awarding its Crown starts that king's timer; repeat
  kills remain allowed but award no further Crown from that king until it
  expires. The other kings' timers are independent, so an attacker may earn one
  Crown from each of the opposing faction's three kings in the same daily raid
  circuit.
- Each starting settlement has a 128×128 build envelope (the start pad, its
  town and town ground unchanged) and a guaranteed road to the home zone.
  **The start town (Round 22, D78)** is its hard-protected POI and its claim
  and resource exclusion envelope at once: the pad and every column within
  12 nodes of it (true distance, so the corners are rounded quarter circles;
  152 nodes across on the axes, about 23 k m² instead of the former 148
  square plus the 256-node claim square). Spawn, waypoint, graveyard and
  every service platform lie inside it; `world.md` §2 R1 owns the
  protection semantics. The band grows no trees and no ground cover, so
  players see where the protection ends, and carries the town's own ground
  out into the natural surface: the pad's ground node reaches 2–10 nodes
  into the band along a smooth noise outline with a dithered edge, beyond it
  the biome's surface, so no straight edge or corner of the pad shows. The
  pad's grading runs as a collar round it (the flat grows by 0–6 nodes along
  a noise outline, then a 24-node ramp with a noisy edge and rounded
  corners), starting in the band and running out just beyond it. Beyond the
  band the zone's ordinary rules apply (vegetation, ground cover, resources,
  caves; starting zones hold no claims). The first mandatory road beat
  reaches the race capital at level 10 and unlocks its waypoint and civic-service
  introduction.

## 13. Mapgen and public zone contract

### 13.1 Horizontal and vertical authority

- WP40 uses native v7 as the cave, ore, dungeon and stratum substrate. One
  project-owned horizontal evaluator and R3's globally queryable
  `H(full_seed_string, x, z)` own the final surface, water, logical biome,
  route and policy products. The native heightmap is not planner input or
  global height authority; the adapter may use it only for the local pre-cave
  owner-slice preservation distinction fixed above.
- At R7 cutover, native registration is closed at zero Lua biomes, one retained
  gravel blob and the five T2--T6 strata, with zero engine decorations. The
  legacy clay, silver-sand and dirt blobs, every scatter resource and every
  engine decoration are absent. The six existing v7 terrain/climate
  NoiseParams remain the exact authenticated native baseline in both main and
  emerge environments; they are inputs to the authored evaluator, never a
  competing biome authority.
- The pure horizontal module exposes at least
  `macro_region_at(x,z)`, `land_at(x,z)`, `id_at(x,z)`,
  `water_class_at(x,z)`, `neighbors(id)` and
  `selected_anchor_2d(zone_id,slot_id)`. The world-map renderer and the mapgen
  adapter consume this same evaluator; no renderer-owned geometry exists.
- Engine climate competition is not authoritative inside the authored world.
  A full-seed selector chooses only from the owning zone's logical-biome
  palette. Surface content maps that frozen logical id to nodes and
  decorations without selecting a different biome.
- Surface writing uses one short typed priority:
  native protected content, fixed hard foundations, named or derived crossing
  spans, paths, terrain repair, explicit water, biome surface, resources and
  decorations. R3 `T` is materialized across clipped vertical owner slices:
  broad fills begin at y = -37, sky clearing ends at the upper mapgen owner
  edge, and no global per-column voxel array is built. Ordinary native cave
  air/liquid at or below the current slice's pre-cave v7 height survives;
  exact authored operations may replace their owned volumes. Native solid
  substrate below `T` otherwise survives, project-native content at/on/above
  the authored surface is replaceable where R3 height/water requires it, and
  deep dungeons remain vertically disjoint.
- The new evaluator, compatibility adapters and consolidated VoxelManip
  callback remain disabled until one atomic production cutover removes both
  legacy WP18 geography writers. Two Grudgelands surface-writing pipelines are
  never enabled in one build.

### 13.2 Public `grug_zones` surface

The final registry exposes:

- defensive-copy `get(id)`, `at(pos)`, `neighbors(id)` (geometric land
  neighbors, §9.1) and `anchor(zone_id,slot_id)`;
- allocation-free `id_at`, `biome_at`, `race_region_at`, `faction_at`,
  `territory_rule_at`, `pvp_rule_at`, `surface_mob_level_at`,
  `mob_level_at`, `guard_level_at`, `terrain_height_at` and
  `water_class_at`.

The mask-based `housing_eligible_at` centre predicate is removed with the
housing masks (Round 25 ruling 4). `grug_housing` validates a claim itself
from these queries and the protection index (`housing.md` §2).

Route and hydrology queries (`travel_links`, `nearest_route_at`,
`nearest_hydrology_at`) left the public surface in Round 22 (D22); Phases 4
and 5 add road and water queries back only where a consumer needs them.

No stable `nearest_boundary_at`, boundary id or coast-component id is public.
A later consumer may add an approximate scalar margin query, but may not
restore boundary materialization without a separately reviewed requirement.

Node-addressed public queries take integer node coordinates. One evaluator
instance binds one canonical full seed string; public queries never accept a
numeric-truncated seed.

### 13.3 Policy and consumer adapters

- `surface_mob_level_at` means the zone-based surface level of §2 (the zone
  field plus the inner start band, and in the six starting zones the
  start-zone gradient); the mapgen's level-banded content reads it.
  `terrain_height_at` means elevation. Existing
  `grug_core.surface_level_at(x,z)` already means terrain height and retains
  that semantic through the `terrain_height_at` adapter.
- `mob_level_at(pos)` combines the surface difficulty
  (`surface_mob_level_at`) with the independent depth floor on land and zone-owned planned water. Exterior shelf returns nil
  at y >= 0 and the depth floor alone below y = 0. Deep ocean and dragon
  channels have no ordinary mob-level result; the Kraken Guard remains a
  separate fixed level-100 entity.
- `guard_level_at(pos)` is nil for every exterior class. Inside a capital's
  protected city (§12: inside the wall line, the edge and its band) it is
  exactly 60 inside the capital's protected volume (from the capital anchor's
  placement height − 100 upward, Round 24 ruling 30). Below that floor and
  everywhere else on non-exterior land it returns the existing generic base
  `min(70, max(20, surface_mob_level_at(pos)))`. The fixed level-65 king
  remains outside this resolver.
- `faction_at` returns `accord`, `throng` or nil and never derives
  construction rights from `race_region`. `territory_rule_at` and
  `pvp_rule_at` apply full 3D precedence: bounded hard protection (each
  footprint from its placement height − 100 upward), immutable
  deep ocean/channels, planned-water/shelf inheritance,
  ordinary land and the y = -701 contested-depth override.
- Current `grug_core.territory_at`, `zone_at`, `mob_level_at`,
  `guard_level_at`, `open_sea_at` and protection callers consume the
  `grug_zones` authority through explicit adapters. `difficulty_at` is gone;
  callers use the level APIs directly. `open_sea_at` maps to deep ocean, not
  planned water or a dragon channel. The old
  `core/inner/outer/coast/war_coast/ocean/strait/underground` buckets are not
  current spawn authority and have no compatibility path.
- All fixed placements resolve through stable zone anchor ids. Slot vocabulary
  remains `start`, `capital`, `village_<n>`, `outpost_<n>`,
  `bandit_<n>`, `mine`, `mirefolk`, `clash_<n>`, `dragon`,
  `apex_mine` and `rare_<stable_rare_id>`. An absent slot returns nil;
  consumers never synthesize a replacement coordinate.
- Zone lookup scans only the small eligible macro-region set. Hot paths do
  not scan every feature record and reuse one x/z classification for the
  complete vertical column. Roads and water (Phases 4 and 5) choose their own
  spatial index.

### 13.4 World-folder layout cache (Round 22, D71)

- Main builds three layouts per world: inland water (§7.4), roads (§9) and
  the capital layouts (§12). They travel to emerge as texts in the `ipc_set`
  payload; emerge never builds them. The same payload carries
  `prepared_blueprints`, main's preparations of the lazy settlement
  blueprints (`docs/design/settlements.md`), which the cache does not store.
- After the first build, main stores exactly those three texts in the world
  folder, in `grug_world_layouts.txt` (`wp40/layout_cache.lua`). A later boot
  loads them **only when the stored key equals the current key** and then
  builds its sessions from the texts, exactly as emerge does. Every other
  case builds the layouts afresh and atomically replaces the file.
- The key holds a format version, the full world seed, a digest of every Lua
  file of the `grug_mapgen` mod (the whole tree, so a new or edited module
  can never be missed; any edit to the mapgen code rebuilds once), the v7
  mapgen settings and the Lua interpreter. Nothing else feeds the layouts.
- The file is text: a format line, the key lines, one section per text
  (water, road, capital) and one small diagnostics section (the first
  start's capital and road log lines, the road showcase spots for
  `/road_spots`, the build seconds), each with its length and SHA-256, and a
  final SHA-256 over everything before it. A missing, truncated, edited or
  otherwise damaged file is never used: it is rebuilt (a damaged file with
  a warning), and never stops the load. A file that passes every hash but
  whose texts do not construct (only possible when edited and re-hashed by
  hand) is treated the same way: a warning, a fresh build, the file
  replaced. A mapgen source file that cannot be read leaves no key: the
  layouts are built afresh and nothing is cached on that boot (a warning).
  This only covers files the runtime does not load (e.g. a stray file); an
  unreadable file the runtime loads still stops the load when it is read.
- The file is written with `core.safe_file_write` (temporary file, then
  rename), so a crash mid-write cannot leave a half file.
- One log line per boot names the result: `world layouts: cache hit` with
  the skipped build seconds, or `cache miss (<reason>)` with the build
  seconds and the stored size.
- The full-world preparation identity (the "authority changed" guard) binds
  a digest of the three texts besides its source files, so it changes when
  a world's layouts or those sources change, whether the layouts were built
  or loaded.
- Deleting the file is always safe: the next boot rebuilds the same layouts.

## 14. World acceptance

Rewritten for Round 22 (D1, D5). Validation protects gameplay; it does not
freeze bytes. The user judges beauty and naturalness from images and
playtests; numbers support that judgment and never replace it.

### 14.1 Checks that stay

- **Smoke test.** Load the game headless (`tools/luanti_headless.sh`,
  `LC_ALL=C`), generate a few dozen chunks around every start and capital, and
  confirm there are no errors and no surviving processes.
- **Visual tool.** A whole-map relief render plus height, slope and roughness
  statistics. Every change to the look produces before/after images and a
  short stats block with this tool.
- **Playability checks,** cheap and offline where possible:
  - no spawn in water;
  - starts and capitals are connected by road;
  - roads are walkable (at most ½ node between neighboring road columns);
  - POI footprints stand on solid ground;
  - every fixed anchor lies inside its own zone;
  - every zone is one connected region;
  - the dragon channels keep their §7.4 widths.
- **Chunk seam check.** The same column queried from two adjacent chunks
  gives the same result.
- **Performance.** A change that alters per-chunk cost reports chunk time
  against the current baseline with the same measuring method.
- The §11 resource and access budgets remain design requirements; spot
  checks confirm them, not multi-seed population gates.

### 14.2 Retired

Known-answer tests, digests and pins, evidence ledgers, census and partition
suites, byte-identical canonical artifacts, PUC Lua 5.1 parity runs, fixed
population counts and identity strings. During mapgen development PUC Lua is
ignored completely; at most one optional crash smoke test under PUC runs once
the mapgen is finished.

## 15. Exact PvP eligibility contract (WP41)

WP41 is part of V1 (user decision 2026-09-29,
[WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29) B4).

### 15.1 Peaceful-zone transaction

“Hostile attempt” means a server-validated contact with an enemy player or a
protected enemy-faction combatant/object. Clicking air, missing the
authoritative ray, a filtered ally or an invalid/out-of-range target does not
tag anybody.

| Attacker before | Player target before | Peaceful-zone result |
|---|---|---|
| safe | safe | attacker becomes tagged; this first effect is blocked and target stays safe |
| safe | tagged | attacker becomes tagged before resolution; effect may land |
| tagged | safe | effect is blocked; target stays safe |
| tagged | tagged | effect may land |

- A valid blocked swing consumes its weapon cadence as a combat miss but pays
  no landed-hit proc, rage or on-hit effect. A launched cast/projectile keeps
  its ordinary launch cost; target-dependent settlement effects do not run.
- Entering or already standing in contested ground forces both enemy players
  tagged before the same table is evaluated. Contested ground includes every
  non-ocean land position at y = −701 and below, regardless of the surface
  zone's peaceful status.
- Deep-ocean and immutable dragon-channel columns — the geography class that
  is neither peaceful nor contested — use the same four-row table above and
  never force the tag (decided 2026-08-13). Only contested ground forces it;
  the contested islands and shores force it on arrival as usual, so a boat
  approach is not a forced-PvP corridor while voluntary flagging still works
  everywhere.
- A hostile action against an enemy capital/outpost guard, war-front unit or
  protected faction combat object tags the player before PvE/NPC damage is
  resolved. Ordinary hostile creatures do not affect PvP state.

### 15.2 Support and timer refresh

- A heal that restores HP, a shield that adds absorb, a cleanse that removes a
  harmful PvP effect, or a combat-relevant buff applied to a tagged ally tags
  the helper and refreshes both players. A failed, rejected or zero-effect
  support action does neither.
- Effective periodic support ticks repeat that contact while their source is
  online and attributable. Merely standing near a tagged player has no effect.
- PvP damage refreshes both participants only when accepted damage lowers HP
  or consumes at least one point of absorb. Miss, dodge, immunity, eligibility
  refusal and zero post-mitigation damage do not refresh the timer.
- Combat with a protected enemy-faction combatant refreshes the involved
  player's timer on the same HP/absorb rule. NPCs themselves have no player tag.
- Outside contested ground, the displayed expiry is 60 seconds after the last
  qualifying hostile/support contact. Leaving contested ground sets it to at
  least `now + 60` even if no fight occurred.

### 15.3 AoE, projectiles and boundaries

- Eligibility is resolved at the instant each target would receive an effect,
  using both current positions, current zone lookups and a snapshot of player
  states for that resolution. The launch zone does not grant future damage.
- Direct projectiles use their owner as attacker. Collision with a safe enemy
  in peaceful ground tags the owner but does not damage that first safe target.
- A one-shot AoE snapshots all targets before tagging its owner, tags the owner
  once if it made a valid hostile contact, then resolves every target from the
  same snapshot so iteration order cannot change who is protected.
- A persistent area remembers the targets eligible at creation. A safe enemy
  who deliberately walks into an already active field is ignored and cannot
  force the remote owner into PvP. Newly entering tagged enemies may be
  affected if the owner is tagged; each real HP/absorb result refreshes normally.
- The central eligibility function rechecks zone state synchronously, so a
  high-speed crossing or teleport cannot fit between the movement poll and a
  combat callback.

### 15.4 Lifecycle, visibility and enemy visitors

- PvP expiry is stored as an absolute timestamp in player meta. Disconnect
  never clears it; offline wall time counts down. Reconnecting in a contested
  zone forces the tag again.
- Death clears the tag and every attributable hostile player DoT/field that
  could immediately re-tag the respawned character. Respawning inside
  contested ground would force it again, although the MVP respawns are safe.
- HUD: tagged players see a crossed-swords status and `PvP 0:SS`; forced
  contested state reads `PvP — CONTESTED`. Entry shows the zone title plus
  “Contested Territory — PvP enabled” for 2.5 seconds. The Target Frame shows
  a sword for tagged enemies and a shield for protected safe enemies.
- Enemy visitors may physically traverse peaceful territory and fight ordinary
  creatures. Faction guards still acquire them; PvP safety protects only from
  enemy players. Enemy vendors, kings, quest objects, protected storage,
  waypoint unlock/use and faction POIs refuse interaction.
- Essential service NPCs are passive and invulnerable. Kings and royal guards
  are damageable combatants; a valid hostile action against either tags the
  visitor before damage resolves, just like an attack on another damageable
  enemy guard, which lets defending players join.

### 15.5 WP41 public seam and acceptance

- One `grug_pvp` service owns `state(player)`, `tag(player, reason)`,
  `hostile_attempt(attacker, target, context)`,
  `support_contact(helper, target, context)` and
  `damage_committed(attacker, target, hp_loss, absorb_loss)`. The precise
  return record is implementation-owned, but it must distinguish blocked,
  combat-miss and damage-eligible outcomes.
- Ordinary tools/fists, authoritative swings, hostile casts, AoE,
  `grug_projectiles`, guards and later effects call this seam. No caller
  reads player meta or zone PvP flags directly.
- Automated coverage crosses the four-row table with peaceful/contested,
  ordinary melee, ability swing, targeted cast, projectile and AoE; it also
  covers full absorb, dodge, support, boundary crossing, death and reconnect.
  Existing WP39 exact-once, cadence, rage, proc and projectile tests remain
  green.

## 16. Bounded war-front life (WP42)

Scope (user decision 2026-09-29, WP audit B5/B6): the scripted NPC battles
below come after V1. Small PvP POIs — forts and camps with NPCs — may come in
V1. WP42 may ship before WP41, with war units treating today's enemy-faction
players as hostile until the `grug_pvp` seam exists.

- Twelve zones are contested. Eight of them carry the current war-activity
  budget: Ashenward March, Bannerbreak Mesa and all six §8.3 zones. Their §8
  **K** slots total 16 clash anchors; the four newly contested outer frontier
  approaches have no dedicated clash slot in the MVP.
- One zone may run at most one clash at a time. A clash is two mechanically
  matched four-NPC squads: one veteran/captain, two melee guards and one
  ranged guard. Regional skins, names and weapons differ; level comes from the
  zone, with level 60 fixed at both endpoints.
- An anchor becomes eligible when a player is within 128 nodes and its
  deterministic 8–14 minute cooldown has elapsed. It spawns one complete
  clash, never refills individual casualties, never catches up multiple missed
  fights and schedules the next cooldown only after resolution or withdrawal.
- If no player remains within 160 nodes for 90 seconds, surviving dedicated
  units withdraw/despawn and the anchor schedules its next window. With all
  eight zones observed simultaneously the hard maximum is 64 dedicated war
  NPCs; ordinary wildlife and guards keep their existing budgets.
- War units acquire only opposing dedicated war units, eligible hostile
  players and dangerous creatures that attack a squad member. Ordinary guards
  retain `attack_npcs = false`; war units do not roam out of their authored
  encounter leash.
- NPC-only kills produce no drops. With enemy-player involvement, existing
  guard war-trophy/heavy-cloth rules apply; own-faction units never become a
  farm. The MVP has no refilling supply crates. Every contested zone reserves
  a non-loot quest-interaction slot for WP9 instead.
- Clash outcomes do not move borders, alter zone ownership, disable roads or
  grant a persistent buff. WP13 supplies walls, forts and siege art; WP42 owns
  units, schedules and place-bound encounter state only.
- Automated tests prove the per-zone/global caps, no catch-up, unload cleanup,
  exact opposing-target filter, player-involvement loot rule and unchanged
  ordinary-guard behavior. A headless soak observes all eight zones at once
  before the user's visual battlefield test.

### Round 10 Cooking wild sources, field soil and shallow reefs

All fifteen Cooking plant identities below have independent wild source nodes
`grug_mapgen:<key>_source`, yielding `grug_cooking:<key>`. Their farm seed/stage
identities remain `grug_farming:seed_<key>` and `<key>_1`…`<key>_4`.
Those are rooted logical-stage identities. Tall cultivated families may use
hidden, non-owning upper helper nodes; wild sources remain single-node.
Potato/Corn retain the exact separate WP33 sources above. All seventeen families
are farmable on legal editable ground. Salt Crust is neither Rock Salt nor an
alias, and Frost Melon is distinct from the existing gathering Melon.

The six starts are Hearthpine, Dawnmere, Silverleaf, Stillgrave, Sunscar and
Kapok. Their paired level-11–20 homes are Copperfell, Goldmead, Starbough,
Mournfen, Redtusk and Raincall. "Accord" and "Throng" subsets select the first
and last three respectively. Bands use the existing cumulative thirds: start
bands 1–2 mean levels 1–6 and bands 2–3 mean 4–10.

| Key | Named zones / level or depth | Logical hosts and actual support | Shore / density |
|---|---|---|---|
| wild_grain | six starts 4–10; six homes 11–20 | meadow, pine, elf, savanna, blight, jungle-edge ordinary viable soil variants | none; 1/256 |
| carrot | three Accord starts 1–6 | meadow, pine, elf viable soils | none; 1/256 |
| cassava | three Throng starts 1–6 | savanna, blight, jungle-edge viable soils | none; 1/256 |
| wild_onion | Accord starts and paired homes | deep forest, pine, elf viable soils | none; 1/512 |
| fire_pepper | Throng starts and paired homes | badlands mesa clay, savanna/blight/jungle-edge viable soils | none; 1/512 |
| pumpkin | six paired homes 11–20 | meadow soil, swamp mud, blight soil | none; 1/256 |
| blightberry | Mournfen 11–20 | blight viable soil | none; 1/256 |
| sunberry | Redtusk 11–20 | savanna viable soil | none; 1/256 |
| jungle_berry | Raincall 11–20 | jungle-edge viable soil | none; 1/256 |
| frost_melon | Frostbarrow, Whitebridge 21–30 | crags gravel or swamp mud, or sand in either, at a freshwater margin (Round 22 Phase 5: margins are mostly sand) | fresh cardinal contact; 1/64 (the margin is a thin band) |
| sugar_cane | every named zone and band with a shore | shore sand only; no rock support | fresh or sea cardinal contact; 1/256 |
| bamboo_shoot | every named zone with matching shore host | jungle-edge, deep-jungle or swamp; sand or mud | fresh or sea cardinal contact; 1/256 |
| cave_cap | continental cave air at y −500…−100 | actual T1–T4 tier rock support (`default:stone`, `grug_materials:t2_stone`..`t4_stone`) | no surface placement; 1/768 |
| salt_crust | Shattered Line bands 2–3, levels 44–50 | badlands mesa clay | none; 1/512 |
| ember_moss | continental cave air at y ≤ −701 | actual T5 tier rock (`grug_materials:t5_stone`) support | no surface placement; 1/1024 |

A viable soil is a matching nonrock fertile patch of that logical biome;
ordinary dirt, relevant litter, mud, dry dirt, moss soil and ash soil do not
turn an unrelated logical biome into a host. Actual final support is checked,
not assumed from the nominal biome. Surface sources stand above that support;
cave sources require real preserved air above real exposed stone. No source
may replace a functional surface, foundation, route or water.
Cave eligibility follows the purpose-specific WORLD guards, not broad natural
landmark envelopes; under a town, POI core, anchor grade or hard foundation
those guards end at the column's protected floor (placement height − 100,
Round 24 ruling 30), below which cave sources place normally. Candidate
rejection does not move, retry or refill it.

The accepted Mushroom set additionally includes `kragmar_speargrass_reach` on
its swamp-mud host. Stormkelp additionally includes `front_shattered_line`,
restricted there to swamp-mud shores. Other closed WP33 rows remain unchanged.

Second-soil patches use coherent existing terrain variation: meadow dirt,
pine gravel, savanna dry/cracked earth, jungle mud, blight ash ground and elf
moss soil. Ash ground and moss soil reuse shipped licensed textures; neither
adds an ore, currency or separate farming progression. Mountain/rocky shore
rules retain priority. Authored settlement fields use actual dry/wet farming
soil, with the existing current-load timer activation and nearby-water rule.
Capital protection remains effective; editable ground requires no housing.

Shallow reefs use deterministic 16-node reef-cell patches plus column selection,
only in sea water with bed depth 2–10: the coastal shelf and, since Round 22
Phase 6, the continental bays. One cell in four carries a small or large coral
patch, and loose kelp meadows (soft noise-bounded areas, one sand column in
six, 2–6 tall) grow on sand beds at least three deep. The six default coral variants and rooted
sand-with-kelp replace eligible natural bed nodes, with their actual rooted
geometry/height semantics. Lakes, rivers, planned freshwater and functional
surfaces receive no reef content. There is one terrain/VM writer and no competing
engine decoration pass or global density/census target.

## Round 14 flight policy

Decided 2026-09-21. Ordinary contested mainland and all mainland Battlegrounds
allow flight for both factions. Safe faction home zones (including capitals)
allow only their own faction to fly. Other POIs inherit the surrounding zone.
Both dragon islands prohibit flight for both factions, despite their contested
status. Existing ocean/channel no-flight rules remain. See `mounts.md` section 4.

## Round 21 natural-surface iteration

**Superseded in part by Round 22 (2026-09-25):** the height rules below
(64-node lattice, 1:2:1 smoothing, 128/32 detail scales and weights,
lowland/rolling amplitudes, "no additional noise octave") are replaced by
§7.6. The lake-edge and beach/cliff rules are replaced by Phase 5 water
(natural lake shores, levels from the terrain) and the shore material rule
in §7.4. The coral rule remains. The waterweed, lily and fish rules remain
and are hosted by Phase 5 inland water: waterweed in lakes and, at half the
rate, in river reaches away from rapids and falls; lilies and Reed Angelfish
in lakes only (a river holds river water).

Approved 2026-09-24. Preserve continental profile roles and ranges. The broad
64-node lattice is smoothed once with 1:2:1 weights; the two existing detail
scales are 128/32 nodes with 3:1 weights. Lowland and rolling amplitudes are
9 and 12 respectively. No additional noise octave is evaluated. Corals form
varied deterministic patches at similar overall density. Rooted freshwater
waterweed sparsely decorates safe, 2–6-node-deep freshwater over natural sand
without displacing the water column. Thin waterlilies occupy the air node
immediately above a similarly safe freshwater surface and remain passable.
Reed Angelfish use existing capped critter spawning, without XP, quality loot
or fishing changes.

The freshwater family is the Reed Angelfish, using ElCeejo's MIT-licensed
Animalia angelfish mesh and texture at commit
`5895f403fd43a9464e06b3675af3495f50565a3f`. It swims only in freshwater
source columns over natural sand and never leaves the water (it cannot climb
a bank, and shore plants and waterlilies are not water to it); stranded away
from water it flops in place. It gives no XP, drops exactly one ordinary Raw
Fish (like a land critter's one meat; the better fish come only from
fishing) and uses the ambient spawn cap of two. It has no school, breeding,
pathfinding or fishing integration.
