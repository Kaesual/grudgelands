# Named World Zones & PvP Geography

Decided 2026-08-10; complete named-zone pass 2026-08-11; fixed simple-map
rebase 2026-08-25. This document supersedes the old radial
"safe core + war coast" surface layout in `world.md` and
`biomes_mobs.md`. The shipped WP18/WP36 map still uses that old layout;
WP40 replaces it with the complete catalog and contracts below.

## 1. Authored macro-map, procedural local detail

- **Kragmar remains north and Elandor remains south.** They are distinct
  faction continents, but they are no longer separated along their whole
  front by mandatory open water.
- The continent parts meet along one continuous, narrow **Holy Grounds** land
  band. From west to east its four zones are Gravesalt Escarpment, The Broken
  Causeway, The Shattered Line and The Skyglass Canopy. This band contains the
  only normal overland crossings between the factions and provides several
  parallel traversable lanes rather than one blockable bridge; ocean separates
  the remaining coastlines.
- The Wyrmglass Crown and Stormscale Summit are separate level-60 offshore
  island zones beyond the western and eastern ends of that band. Neither has a
  land-neighbor edge. Their connections belong to a distinct boat/travel graph
  across immutable ocean channels, not to the land-adjacency graph.
- The macro-map is fixed by one versioned layout rather than regenerated from
  each world seed. Every named zone has a stable hub, approximate extent,
  level range and biome palette. World-seed variation begins with secondary
  anchor selection, terrain, biome detail and content; it never moves land,
  zone ownership, main routes or the water classes shown by the canonical 2D
  map.
- The two faction sides are **progression and content-budget mirrors, not
  geometric mirrors**. They receive equivalent access to level bands,
  materials, PvP fronts, travel services and POI budgets, while their shapes,
  zone names, biome combinations and landmarks may differ.
- Each zone definition owns: display name and id, stable hub, macro region,
  optional ownership bias, `territory_rule`, exactly one `race_region`, level
  range, surface difficulty target, PvP rule, route neighbors, allowed biome
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
  frontier approaches, all four Holy Grounds zones and both dragon islands.
  Capitals remain the peaceful civic exception described in §3.
- Most land where the faction continents meet is level 41–50 or 51–60. The six
  level-31–40 faction-front approaches and The Broken Causeway are the first
  contested destinations; their authored contacts introduce PvP without
  making the whole shared front a mid-level band.
- Surface mob level comes from one authored target per named zone. One fixed,
  component-aware continuous difficulty field blends those targets across the
  world; the published level range remains content metadata rather than a
  second within-zone control field. The old radial distance from a faction
  seat and exact gate/core progression fields are not part of the target
  model.
- The existing depth floor remains independent: underground level is the
  maximum of the local surface-zone level and the depth level from
  `combat_stats.md`.
- At **y = −701 and below**, every non-ocean land column is contested even
  beneath a peaceful surface zone, capital, functional anchor or active claim.
  Deep ocean and immutable dragon channels remain full-column exceptions.

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
  that king's seat. Housing is not a royal level-30 grant: the separate
  passive, invulnerable Housing Steward owns the free level-20 Claim Stone
  introduction defined by `housing.md`; `world.md` §5 summarizes its
  world-facing integration.
- A capital is centered inside its city zone and has main roads in all four
  cardinal directions. Its directional neighbors follow the world
  progression:
  - toward the outer starting side: a level-10–20 zone;
  - laterally along the central faction/capital axis: medium-level heartland;
  - toward the contested front: high-level territory.
- Capitals remain protected POIs and major waypoint/service hubs. They are
  destinations reached from the starting zones, not spawn bubbles.
- Capital zones use the same one-target difficulty rule as every other zone.
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
  shared front reaches the ocean and one at its eastern end. WP23 populates
  both with an overworld dragon through one shared encounter chassis and two
  regional variants.
- Each overworld dragon lair occupies its own **offshore island** beyond one
  ocean endpoint of the Holy Grounds. An immutable full-column ocean channel
  separates it from every mainland coast, so it has no land, bridge or tunnel
  connection. Both factions receive equivalent authored boat access.
- Every dragon island is a contested level-60 mountain region with strong
  level-60 mountain creatures. Its silhouette culminates in a dragon mountain,
  summit or hoard.
- An overworld dragon is therefore always a PvP world boss. Reaching and
  fighting it exposes both factions to each other; it is never a private
  home-continent boss.
- Each endpoint reserves an apex mining camp in the dangerous approach to the
  lair. Its ordinary walls, tents, fences and dressing are mutable and
  claim-excluded. Only its bounded functional anchor and exactly **12 protected
  renewable sockets—two Citrine, two Garnet, two Jade, two Diamond, two
  Sapphire and two Ruby**—are hard-protected. Natural veins remain finite;
  only these protected sockets
  use `world.md` §2 R4's existing 2–4 h renewable-node exception. The material
  catalog supplies the item/node ids; zone code stores the six semantic gem
  species and never owns their registered itemstrings.

## 7. Fixed horizontal world model

### 7.1 Frame, landmarks and stable hubs

- World axes stay conventional: west/east is x, Kragmar lies north at positive
  z, Elandor lies south at negative z, and the shared front is centred on z = 0.
- The layout id is `wp40-simple-map-v1`. Land, zone hubs, macro ownership,
  main routes, housing masks and water classes are identical for every world
  seed using that layout.
- The Holy Grounds is the exact, unwarped closed rectangle
  **x = -2500..+2500, z = -250..+250**. It is land and may contain explicit
  planned water. Its internal west/east ownership uses the four Holy hubs
  below. Terrain is immutable from the surface through y = -700 inclusive;
  the universal contested T5/T6 rule resumes at y = -701.
- The authored mainland extent is x = -2600..+2600 and z = -3000..+3000.
  This is a source/validation bound, not a rectangular coastline or a world
  border. Open sea continues outside the generated area.
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
  Each owns a centred **600 by 500 dry start core** wholly inside its starting
  zone, with its 256 by 256 settlement blend and primary route exit intact.
- The six capital centres are (-1800, -1500), (0, -1500), (+1800, -1500),
  (-1800, +1500), (0, +1500) and (+1800, +1500). Each exact **512 by 512
  build envelope** belongs wholly to its capital zone. The surrounding
  704 by 704 visual terrain blend may cross a zone boundary and does not
  enlarge political ownership.
- Each starting zone has only its corresponding home zone as a mandatory route
  neighbor. Each cultural spine then reaches its capital and faction front.
  The macro silhouette remains legible as three outer prongs, one connected
  capital/heartland belt and one connected frontier per faction.

### 7.2 Macro land and authored variation

- Land is a small authored union/difference of axis-aligned capsules, rounded
  rectangles and ellipses. It contains three broad cultural lobes, a capital
  connection and a frontier connection on each independently authored
  mainland, the exact Holy Grounds rectangle, and one island shape per dragon
  endpoint.
- Elandor and Kragmar are not coordinate reflections and may not share a
  reflected source record. Their silhouettes, bay placement and visible
  landmark composition remain culturally distinct while satisfying equivalent
  progression, resource and access budgets.
- Mainland and island shape queries use one layout-bound low-frequency
  coordinate warp with 1024-node cells and at most 32 nodes of displacement
  per axis. The same warp applies to zone hubs before ownership scoring. Source
  validation proves safe integer bounds and a displacement Lipschitz constant
  below one, so the transform cannot fold space. The Holy Grounds rectangle
  and fixed ownership cores are unwarped.
- Local coastline, biome and terrain beauty comes primarily from the later
  height/detail fields. There is no seed-selected polygon partition, boundary
  raster, topology census, repair pass or alternate winner layout.
- The final horizontal products are exactly one connected mainland and two
  connected islands. Every ordinary zone is nonempty and connected. No route
  corridor, start core, capital envelope, housing core or required anchor is
  rescued by growing land or moving its endpoint.

### 7.3 Zone ownership and difficulty

- Zone ownership is an integer power diagram restricted to five macro regions:
  the 16 Elandor-mainland zones, 16 Kragmar-mainland zones, four Holy Grounds
  zones, and one single-zone region for each island.
- For point `p` and eligible zone `z`, ownership minimizes
  `squared_distance(w(p), w(z.hub)) - z.bias`. Warped coordinates are rounded
  to integer nodes before scoring. Stable numeric zone id breaks an exact tie.
  Coordinate deltas remain at most 8192 and `abs(bias) <= 2^24`, keeping
  every score and comparison exactly representable in Lua's safe integer
  range.
- The complete 600 by 500 start cores and 512 by 512 capital envelopes are
  explicit fixed-owner overrides. The underlying power owner must already
  agree throughout each core; the override may not create a detached zone
  island.
- The 57-route graph in section 9 is the gameplay-neighbor graph. Geometric
  contact is permitted only for the complete 61-pair allowlist consisting of
  those 57 route pairs plus the four historical outer-flank pairs. An allowed
  pair need not touch, and no geometric dual or stable boundary identity is
  materialized.
- Every zone has one authored surface difficulty target. Targets are sampled
  on a fixed 32-node Q16 lattice and smoothed separately on the mainland and
  on each island with a separable triangular 192-node radius. Queries use two
  sequential one-axis integer interpolations. Every orthogonally adjacent
  walkable surface pair and every ordinary route step differs by at most two
  levels. Water travel, rather than an exempt land discontinuity, separates
  the level-60 islands.
- Published zone level ranges continue to govern content identity. Capital
  guard floors, depth progression and fixed level entities remain independent
  policy and are not encoded as extra difficulty-control points.

### 7.4 Planned water, coast and islands

- Four simple zone-owned bays keep the three outer prongs visibly separated:

  | Bay | Authored centreline samples (x, z; half-width) |
  |---|---|
  | Elandor west | (-980,-2940;360) -> (-900,-2600;280) -> (-1040,-2300;190) -> (-980,-2000;80) |
  | Elandor east | (+900,-2920;330) -> (+1080,-2580;250) -> (+920,-2280;180) -> (+1020,-1990;80) |
  | Kragmar west | (-1080,+2930;320) -> (-1200,+2620;260) -> (-940,+2300;190) -> (-1060,+2010;80) |
  | Kragmar east | (+820,+2960;370) -> (+700,+2630;250) -> (+1050,+2320;170) -> (+900,+1980;80) |

  Each bay is one round-joined variable-width capsule mask. It remains open
  and connected from outer water to its head, never narrows below 64 nodes,
  reaches neither capital belt nor housing core, disconnects no prong and
  creates no new land contact. Its deterministic nearest centreline/zone-id
  tie assigns mainland ownership without adding a gameplay edge.
- Horizontal water classification has one total precedence:
  1. exact fixed features: Holy Grounds and ownership cores are land except
     for a planned-water submask declared by that same fixed feature;
  2. closed explicit planned/bay-water masks;
  3. ordinary macro land;
  4. closed immutable dragon-channel masks;
  5. the nominal coastal shelf; and
  6. deep ocean.
- A declared interior planned-water submask retains its fixed feature's zone
  ownership and returns planned water; unrelated general planned-water masks
  cannot cut fixed land. Fixed land and every warped additive land primitive
  use closed membership.
  Planned-water subtractive masks stay unchanged when the shelf is computed
  and win over ordinary land. `expanded_land_at(r)` expands each positive
  land primitive and fixed-land extent by `r` after the query point is
  warped. It is consulted only after fixed land, planned water, ordinary land
  and channel masks fail; equality belongs to the shelf. Thus
  `expanded_land_at(80) and not land_at` is one deterministic **nominal
  80-node shelf**, not an exact Euclidean distance to every corner of the final
  CSG silhouette.
- Shelf policy and exterior dressing inherit from the same nearest eligible
  mainland hub. Planned water remains part of its named zone. Shelf, every
  planned-water mask and every route/POI exclusion is claim-ineligible.
  Deep ocean and dragon channels are immutable at every y.
- The two island channels keep at least 200 water nodes between final mainland
  and island land. Each shore contributes an exact 48-node flight-warning band,
  leaving at least 104 nodes of hard no-flight water. Filling, draining,
  bridging or tunnelling through the complete channel is forbidden.
- Each island retains two distinct 96-node-wide boat approaches and landing
  beaches, centred at z = -125 and z = +125. The southern and northern
  faction-oriented route lengths to either island differ by at most 10%.
  Both approaches are open to both factions and are stored only in the
  separate boat/travel graph.
- Every generated surface-water class uses `default:water_source`. Logical
  biome and named-landmark records change bed, shore, depth and decorations,
  never liquid identity. Subterranean lava is outside this rule.

### 7.5 Paths, anchors and housing

- Roads, trails, future rail, rivers and boat routes are independent typed
  centrelines between fixed stations. A dry path never creates land. It must
  fit the land mask with its complete corridor, or use an explicit bridge,
  ford, tunnel, causeway, ferry or boat interface.
- Primary roads use a 7-node visible surface and 16-node exclusion corridor;
  secondary roads use 5/12; trails use 3/8. The complete corridor remains
  claim-ineligible even after players alter the visible path.
- Required POIs receive explicit secondary-road or trail spurs. Fixed gates,
  crossings and POI endpoints never move. Ordinary roads and adequate
  alternate bridges remain mutable; only irreplaceable functional pieces may
  receive bounded hard protection.
- The 100 stable anchor slots retain their ids. Fixed anchors keep fixed x/z;
  secondary anchors use small ordered candidate sets validated against the
  frozen 2D model. A full-seed hash selects once from that valid set. Height
  grading must fit the selected candidate and may not reject it, move it or
  select again.
- Housing is available only in the ten zones listed by `world.md` section 5.
  A true housing-centre mask means the complete 101 by 101 future reservation
  passes every static exclusion. Candidate envelopes for all secondary anchor
  alternatives are excluded before world-seed selection, so eligibility is
  fixed by layout.
- Copperfell Foothills, Mournfen, Starbough Vale and Raincall Basin each keep
  one continuous coastal housing core with at least 600 nodes of shoreline
  frontage and 300 nodes of buildable inland depth. Every wholly contained
  eligible 101 by 101 reservation has at most 12 nodes of natural-ground
  relief and contains no mandatory cliff, ravine, river or lake.
- Housing capacity uses the fixed-layout 111 by 111 origin lattice and the
  canonical deterministic packing portfolio. It is measured once per layout,
  not repeated across identical geometry seeds; varying-seed resource and
  content audits remain separate.

### 7.6 Height, relief and visual structure

- The project owns one globally queryable integer surface-height field
  `H(full_seed_string, x, z)`, exposed as `terrain_height_at`. It combines
  bounded broad/detail lattices, the zone relief profiles, authored landmarks
  and deterministic grading. It never reads a generated chunk, engine spawn
  level or chunk-local v7 heightmap as global authority.
- Native v7 remains the substrate for caves, ores, dungeons and strata. The
  final surface pass preserves those products outside the shallow authored
  shell and never runs a second competing terrain writer.
- Every land zone declares exactly one primary relief profile:

  | Relief id | Elevation above water level |
  |---|---:|
  | `wetland_delta` | +2..+24 |
  | `lowland` | +8..+56 |
  | `rolling_hills` | +24..+96 |
  | `plateau` | +56..+144 |
  | `highland` | +96..+224 |
  | `mountain` | +160..+360 |

  Explicit bounded secondary profiles and named landmarks may modify that
  base. Biome patches do not implicitly change relief.
- Ordinary profile transitions are smooth. A cliff, ravine, escarpment,
  waterfall basin or other abrupt macro feature exists only through a named
  authored landmark. Start, capital, housing, route and selected-anchor grading
  overrides general relief in that order of functional necessity.
- Landmarks have stable ids, one declared owner and bounded masks. Owner
  clipping prevents a landmark from modifying another zone but never silently
  satisfies its route, housing, anchor or grading obligations.
- The map promises no target journey duration. Reliable route placement,
  visible terrain structure and available travel methods determine travel
  time. Strategic separators are physical terrain or explicit water, never
  invisible walls.

## 8. Zone catalog

Biome percentages are target shares of ordinary land surface after fixed
roads and structures. A ±5 percentage-point per-zone tolerance is allowed;
the faction resource audit in §11 is binding. “Settled”, “forest”,
“mountain”, “savanna”, “jungle”, “swamp” and “war” refer to the existing mob
families and paired drop tables in `biomes_mobs.md` §3. A palette does not
automatically enable every gatherable or mob of that biome: the zone's level
and explicit content palette still gate them.

POI abbreviations:

- **S** = starting settlement, graveyard and waypoint;
- **C** = capital, king, service hub and waypoint;
- **V** = mandatory village; **O×n** = n ordinary outpost slots;
- **B** = one of the two fixed bandit camps for that race;
- **M** = that race's one peaceful renewable mining camp;
- **W** = a fixed Mirefolk wetland camp;
- **K×n** = n dedicated war-front clash anchors;
- **D/M6** = dragon lair plus the all-six-gem apex mining camp;
- **R:name** = the migrated named-rare route.

Peaceful §8.1 zones use `territory_rule = "accord_home"` and peaceful §8.2
zones use `territory_rule = "throng_home"`. Every level-31–60 ordinary
frontier or island uses `territory_rule = "contested_land"`: both factions may
edit ordinary terrain subject to tools and explicit protected envelopes. The
four Holy Grounds zones instead use `territory_rule = "holy_grounds"`; they
are immutable through y = -700 and become ordinary contested depth at
y = -701. `race_region` never changes any of these rights.

### 8.1 Elandor — Accord

| Stable id | Display name | Race | Level / PvP | Allowed biome share | Identity, content and reserved POIs |
|---|---|---|---|---|---|
| `elandor_hearthpine_vale` | Hearthpine Vale | Dwarf | 1–10 peaceful | pine hills 90 / crags 10 | Sheltered pine bowl, warm springs and a novice quarry; settled mobs; **S** |
| `elandor_copperfell_foothills` | Copperfell Foothills | Dwarf | 11–20 peaceful | pine hills 75 / crags 25 | Copper-stained streams, switchback road and pine terraces; settled mobs; gravemoss; **V, O, B** |
| `elandor_dur_brannoc` | Dur Brannoc | Dwarf | capital, civic L20–30 profile, peaceful | pine hills 60 / crags 40 | Terraced granite citadel around a forge chasm; no ambient hostiles; **C** |
| `elandor_frostbarrow_shelf` | Frostbarrow Shelf | Dwarf | 21–30 peaceful | pine hills 55 / crags 40 / swamp 5 | Wind shelf, burial cairns and frozen tarns; mountain mobs, dragonweed; **V, O, M** |
| `elandor_stormvault_heights` | Stormvault Heights | Dwarf | 31–40 **contested** | crags 75 / snowy crags 25 | Lightning-scarred ridge and a giant natural arch; mountain mobs; **O×2, B, R:Korgan's Bane** |
| `elandor_dawnmere_fields` | Dawnmere Fields | Human | 1–10 peaceful | meadows 85 / deep forest 5 / swamp 10 | Sunrise fields, ponds and hedgerows; settled mobs; **S** |
| `elandor_goldmead_vale` | Goldmead Vale | Human | 11–20 peaceful | meadows 65 / deep forest 20 / swamp 15 | River mills, orchards and old farm roads; settled mobs, sunleaf; **V, O, B, R:Grimtusk** |
| `elandor_highcourt` | Highcourt | Human | capital, civic L20–30 profile, peaceful | meadows 80 / deep forest 20 | Brick-and-white-stone city on a river fork; no ambient hostiles; **C** |
| `elandor_whitebridge_shire` | Whitebridge Shire | Human | 21–30 peaceful | meadows 50 / deep forest 35 / swamp 15 | Old arched bridge, oak copses and market villages; settled/forest mobs, marshbloom; **V, O, M, W** |
| `elandor_ashenward_march` | Ashenward March | Human | 31–40 **contested** | deep forest 50 / meadows 30 / swamp 20 | Burned woodland, trenches and the first active frontier; forest/war mobs; **O×2, B, K×2, R:Old Whitefang** |
| `elandor_silverleaf_glades` | Silverleaf Glades | Elf | 1–10 peaceful | elf forest 95 / deep forest 5 | Pale trees, clear streams and circular glades; settled mobs; **S** |
| `elandor_starbough_vale` | Starbough Vale | Elf | 11–20 peaceful | elf forest 80 / deep forest 20 | Terraced silverwood slopes and early canopy paths; settled mobs, sunleaf; **V, O, B** |
| `elandor_lethariel` | Lethariel | Elf | capital, civic L20–30 profile, peaceful | elf forest 90 / deep forest 10 | Treehouse crown around a lake and white-marble roots; no ambient hostiles; **C** |
| `elandor_lorindor` | Lorindor | Elf | 21–30 peaceful | elf forest 50 / deep forest 30 / swamp 20 | Small woodland state southwest of Lethariel, remembered for pale stags, silverwood orchards, white flowers and marsh-fed berry terraces; **V, O, M, W** |
| `elandor_moonfall_wood` | Moonfall Wood | Elf | 21–30 peaceful | elf forest 40 / deep forest 45 / swamp 15 | Crescent lake beneath a fallen great silverwood; forest mobs; **O** |
| `elandor_glassroot_wilds` | Glassroot Wilds | Elf | 31–40 **contested** | deep forest 45 / jungle fringe 35 / elf forest 10 / swamp 10 | Huge roots gripping glassy pale cliffs; forest and lower-jungle mobs; **O, B** |

### 8.2 Kragmar — Throng

| Stable id | Display name | Race | Level / PvP | Allowed biome share | Identity, content and reserved POIs |
|---|---|---|---|---|---|
| `kragmar_stillgrave_hollow` | Stillgrave Hollow | Undead | 1–10 peaceful | blight 90 / bone forest 5 / swamp 5 | Quiet cemetery basin and sheltered gravewood; settled mobs; **S** |
| `kragmar_mournfen` | Mournfen | Undead | 11–20 peaceful | blight 60 / bone forest 10 / swamp 30 | Drowned grave roads, black reeds and low mist; settled/swamp mobs, gravemoss; **V, O, B, W** |
| `kragmar_nhal_veyr` | Nhal Veyr | Undead | capital, civic L20–30 profile, peaceful | blight 75 / bone forest 25 | Black-stone necropolis on stepped terraces; no ambient hostiles; **C** |
| `kragmar_ossuary_reach` | Ossuary Reach | Undead | 21–30 peaceful | blight 40 / bone forest 50 / swamp 10 | Fossil ridges and gravewood copses; forest mobs, dragonweed; **V, O, M** |
| `kragmar_blackwind_rise` | Blackwind Rise | Undead | 31–40 **contested** | bone forest 65 / blight 30 / swamp 5 | Ash-wind upland crossed by natural bone arches; forest mobs; **O×2, B, R:Marrowclaw** |
| `kragmar_sunscar_flats` | Sunscar Flats | Orc | 1–10 peaceful | savanna 95 / badlands 5 | Dry golden grass, shade rocks and shallow waterholes; settled mobs; **S** |
| `kragmar_redtusk_savanna` | Redtusk Savanna | Orc | 11–20 peaceful | savanna 75 / badlands 25 | Red gullies, acacia wells and hunting roads; settled/savanna mobs, sunleaf; **V, O, B, R:Ashmaw** |
| `kragmar_gor_drazhak` | Gor Drazhak | Orc | capital, civic L20–30 profile, peaceful | savanna 60 / badlands 40 | Adobe-and-basalt fortress at a mesa crossroads; no ambient hostiles; **C** |
| `kragmar_speargrass_reach` | Speargrass Reach | Orc | 21–30 peaceful | savanna 55 / badlands 40 / swamp 5 | Tall cutting grass, dry rivers and hunting stones; savanna/mountain mobs; **V, O, M** |
| `kragmar_bannerbreak_mesa` | Bannerbreak Mesa | Orc | 31–40 **contested** | badlands 70 / savanna 25 / swamp 5 | Wind-torn standards, red trenches and siege ramps; mountain/war mobs, dragonweed; **O×2, B, K×2, R:Dustwing** |
| `kragmar_kapok_cradle` | Kapok Cradle | Troll | 1–10 peaceful | jungle edge 90 / swamp 10 | Sheltered jungle basin beneath one giant kapok; settled/jungle-edge mobs; **S** |
| `kragmar_raincall_basin` | Raincall Basin | Troll | 11–20 peaceful | jungle edge 65 / deep jungle 15 / swamp 20 | Monsoon pools and waterfall stairs; settled/jungle-edge mobs, sunleaf; **V, O, B** |
| `kragmar_kezamba` | Kezamba | Troll | capital, civic L20–30 profile, peaceful | jungle edge 75 / deep jungle 20 / swamp 5 | Stilt-and-stone city around a stepped cenote; no ambient hostiles; **C** |
| `kragmar_whispering_reedlands` | Whispering Reedlands | Troll | 21–30 peaceful | jungle edge 45 / deep jungle 25 / swamp 30 | Flooded reed maze crossed by raised totem paths; jungle-edge/swamp mobs, marshbloom; **V, O, M, W** |
| `kragmar_totemwater_reach` | Totemwater Reach | Troll | 21–30 peaceful | jungle edge 35 / deep jungle 45 / swamp 20 | Broad river delta marked by colossal carved totems; jungle-edge/swamp mobs; **O** |
| `kragmar_thunderroot_wilds` | Thunderroot Wilds | Troll | 31–40 **contested** | deep jungle 55 / east badlands 30 / swamp 15 | Storm forest with exposed roots and ochre stone islands; jungle mobs; **O, B** |

### 8.3 Holy Grounds and offshore dragon islands

All six zones below have one cultural `race_region` and automatic-PvP status
`contested`. The four mainland zones form the immutable shallow Holy Grounds;
the two endpoint zones are editable contested islands separated from the
mainland by full-column immutable ocean channels. §11 defines their resource
and terrain rules without deriving political ownership from cultural origin.

| Stable id | Display name | Race region | Level | Allowed biome share | Identity, content and reserved POIs |
|---|---|---|---|---|---|
| `front_wyrmglass_crown` | The Wyrmglass Crown | Dwarf | 60 | crags 55 / snowy crags 30 / beach 15 | Offshore ring-mountain island, crystalline fault terraces and dragon hoard; mountain/war mobs; **D/M6, K×1** |
| `front_gravesalt_escarpment` | Gravesalt Escarpment | Undead | 51–59 | bone forest 55 / blight 15 / swamp 15 / beach 15 | White salt cliffs cut with tomb galleries and a coastal war road; forest/war mobs, stormkelp; **K×2** |
| `front_broken_causeway` | The Broken Causeway | Human | 31–40 | meadows 40 / deep forest 25 / swamp 35 | Collapsed royal road over marsh and river: raised causeway, ford and aqueduct path form three routes; war mobs; **K×3, R:Captain Bonerattle** |
| `front_shattered_line` | The Shattered Line | Orc | 41–50 | badlands 65 / savanna 20 / swamp 15 | Main battlefield of breached walls, western trenches, eastern siege ramp and burned no-man's-land; mountain/war mobs; **K×3, R:Captain Bonerattle** |
| `front_skyglass_canopy` | The Skyglass Canopy | Elf | 51–59 | jungle fringe 60 / deep forest 25 / elf forest 15 | Cloud forest above pale escarpments, hanging roots and two high approaches; high-jungle/war mobs, crimson lotus; **K×2, R:Silkfang** |
| `front_stormscale_summit` | Stormscale Summit | Troll | 60 | deep jungle 50 / east badlands 20 / swamp 15 / beach 15 | Offshore jungle-clad volcanic island, thunder terraces and dragon hoard; high-jungle/war mobs, stormkelp; **D/M6, K×1, R:Emerald Coil** |

### 8.4 Binding relief and landmark assignment

The tables below assign the §7 relief fields independently of biome palettes.
Every listed landmark id is stable registry data and must resolve to one
deterministic bounded authored mask and one owning `zone_id`. Authored masks do
not disappear or change identity where their fixed edge meets another zone;
their effective terrain influence is the mask/collar intersected with that
final owner. The clipped result may not block a required route, and clipping
does not waive a landmark's local route, housing, capital or grading
obligations.

#### Dwarf progression region

The offshore Wyrmglass endpoint is assigned with the complete Holy
Grounds/dragon group rather than inferred from its Dwarf `race_region`.

| Zone | Primary relief | Secondary relief | Required landmarks and constraints |
|---|---|---|---|
| Hearthpine Vale | `lowland` | `rolling_hills` rim | `hearthpine_bowl`: a sheltered low basin containing the start envelope and warm springs, enclosed by a low wooded rim with an unobstructed primary-road exit toward Copperfell |
| Copperfell Foothills | `rolling_hills` | bounded inland `highland` spurs | `copperfell_drainage`: copper-stained streams descend from the inland spurs toward the west coast without entering the guaranteed housing core; `copperfell_coastal_terraces`: the 600×300 gentle housing core overrides ordinary relief and retains its §7/§14 limits |
| Dur Brannoc | `plateau` | none outside civic grading | `dur_brannoc_granite_terrace`: the complete capital terrain/blend envelope sits on a broad granite shelf; `dur_brannoc_forge_chasm`: a protected central civic chasm that does not cut any of the four fixed road gates |
| Frostbarrow Shelf | `plateau` | bounded `highland` ridges | `frostbarrow_escarpment`: a visible authored shelf edge with alternate traversable approaches; `frostbarrow_tarns`: several shallow frozen tarn basins separated from fixed anchors and road corridors; the remaining plateau carries the wind-cairn fields |
| Stormvault Heights | `highland` | two bounded `mountain` ridges | `stormvault_arch`: a lightning-scarred natural arch carrying one principal passage between the two ridges; every macro travel neck remains at least 96 nodes and an alternate route survives independently of the arch |

#### Human progression region

| Zone | Primary relief | Secondary relief | Required landmarks and constraints |
|---|---|---|---|
| Dawnmere Fields | `lowland` | small `wetland_delta` headwater masks | `dawnmere_headwaters`: connected shallow spring ponds and streams among the fields and hedgerows; their flood masks remain outside the start build envelope and its primary-road exit |
| Goldmead Vale | `lowland` | bounded `rolling_hills` shoulders | `goldmead_millriver`: one reliable mill river follows the valley floor without dividing a required road corridor; `goldmead_orchard_slopes`: gently buildable orchard shoulders overlook the river and remain ordinary housing-eligible terrain outside static exclusions |
| Highcourt | `rolling_hills` | none outside civic and river grading | `highcourt_riverfork`: two authored river arms frame a raised, flood-safe capital plateau; the complete civic envelope and all four fixed road approaches are graded and no river channel enters the protected city core |
| Whitebridge Shire | `lowland` | bounded `wetland_delta` floodplains | `whitebridge_crossing`: the old mutable arched bridge carries the capital-axis road across the main river; `whitebridge_ford`: a spatially separate traversable ford supplies an adequate alternate crossing, so destruction of the bridge cannot sever the route and does not justify hard protection |
| Ashenward March | `rolling_hills` | low `wetland_delta` depressions | `ashenward_burnscar`: a burned ridge makes the old war line visible without becoming a sole choke; `ashenward_trenchbelt`: a broad interrupted trench system preserves independent secondary approaches to The Broken Causeway and The Shattered Line |

#### Elf progression region

| Zone | Primary relief | Secondary relief | Required landmarks and constraints |
|---|---|---|---|
| Silverleaf Glades | `lowland` | small `rolling_hills` grove masks | `silverleaf_gladechain`: a sequence of large circular glades joined by clear streams and the primary road; neither streams nor grove rims enter the start build envelope or close its route toward Starbough |
| Starbough Vale | `rolling_hills` | bounded inland `highland` spurs | `starbough_canopy_steps`: terraced forest slopes carry the early canopy paths without making them mandatory bridges; `starbough_coastal_gardens`: the eastern 600×300 gentle housing core overrides ordinary relief and retains its §7/§14 limits |
| Lethariel | `rolling_hills` | none outside civic and lake grading | `lethariel_crownlake`: a central lake surrounded by concentric living-tree and white-marble capital terraces; four fixed root-and-stone ramps align with the road gates, remain inside capital protection and keep every approach independently passable |
| Lorindor | `rolling_hills` | one bounded `wetland_delta` depression | `lorindor_silverorchards`: pale-stag clearings, silverwood orchards and white-flower meadows identify the small state southwest of Lethariel; `lorindor_berrymarsh`: walkable berry terraces border the marsh depression without entering fixed road or POI envelopes |
| Moonfall Wood | `lowland` | bounded `wetland_delta` lake mask | `moonfall_crescent`: a crescent lake beneath one monumental fallen silverwood; separate routes around both shores ensure that neither the tree nor a single lakeside path controls access |
| Glassroot Wilds | `highland` | bounded `mountain` cliff masks | `glassroot_pale_cliffs`: pale glassy rock steps create the visible rise toward the front; `glassroot_rootways`: enormous roots supply optional natural paths rather than irreplaceable bridges, while independent secondary approaches to The Shattered Line and The Skyglass Canopy remain open |

#### Undead progression region

| Zone | Primary relief | Secondary relief | Required landmarks and constraints |
|---|---|---|---|
| Stillgrave Hollow | `lowland` | small `rolling_hills` rim masks | `stillgrave_basin`: a quiet cemetery basin containing the start envelope; `stillgrave_ringbarrows`: low grave mounds and gravewood form a broken outer ring without entering the start build envelope or closing the primary road toward Mournfen |
| Mournfen | `wetland_delta` | dry `lowland` islands and housing override | `mournfen_drowned_roads`: broken roads cross the black-reed marsh outside the guaranteed housing core and always retain alternate dry or shallow passages; `mournfen_dryward`: one continuous dry coastal rise supplies the western 600×300 gentle housing core and retains its §7/§14 limits without marsh water inside it |
| Nhal Veyr | `plateau` | none outside civic grading | `nhal_veyr_necropolis`: the complete capital envelope occupies a raised black-stone necropolis of concentric grave terraces; four broad graded ramps align with the fixed road gates and remain inside capital protection |
| Ossuary Reach | `rolling_hills` | bounded `highland` fossil ridges | `ossuary_spine`: one prominent fossil-ridge line crosses the zone without sealing any road or housing corridor; `ossuary_gravewoods`: sheltered low depressions hold gravewood copses outside fixed anchors and exclusion envelopes, with no additional terrain-protection rule |
| Blackwind Rise | `highland` | bounded `plateau` shoulders | `blackwind_bonearches`: multiple natural bone arches provide optional passages rather than mandatory bridges; `blackwind_ashcuts`: ash-wind valleys preserve independent secondary approaches to Gravesalt Escarpment and The Broken Causeway |

#### Orc progression region

| Zone | Primary relief | Secondary relief | Required landmarks and constraints |
|---|---|---|---|
| Sunscar Flats | `lowland` | small `rolling_hills` rock masks | `sunscar_open_flats`: a broad open golden savanna contains the start envelope and its primary-road exit; `sunscar_waterholes`: several shallow waterholes and shade-rock clusters remain outside the protected start core and never form a continuous barrier |
| Redtusk Savanna | `rolling_hills` | bounded `plateau` badland islands | `redtusk_gullies`: branching red dry gullies remain interrupted at every road and housing corridor; `redtusk_wellchain`: old acacia wells mark the primary route without becoming required functional water sources |
| Gor Drazhak | `plateau` | none outside civic grading | `gor_drazhak_crossmesa`: the complete capital envelope occupies one broad basalt mesa centred on the four-way road crossing; four independent graded ramps align with the fixed gates and remain inside capital protection |
| Speargrass Reach | `rolling_hills` | low bounded `plateau` tablelands | `speargrass_dryriver`: a wide seasonal dry riverbed crosses the zone without severing the capital axis; `speargrass_hunting_stones`: distant standing stones mark the route and horizon outside fixed anchors and housing exclusions |
| Bannerbreak Mesa | `plateau` | bounded `highland` mesa rims | `bannerbreak_crowned_mesa`: a high tableland crowned by torn standards defines the frontier silhouette; `bannerbreak_siegeramps`: two spatially separate old siege ramps preserve independent secondary approaches to The Broken Causeway and The Shattered Line and may not converge into one route neck |

#### Troll progression region

| Zone | Primary relief | Secondary relief | Required landmarks and constraints |
|---|---|---|---|
| Kapok Cradle | `lowland` | small `wetland_delta` depressions | `kapok_worldtree_basin`: one monumental kapok dominates a geographically sheltered basin; its roots, crown and water masks remain outside the protected start build envelope and primary-road exit, and the basin adds no terrain-protection rule of its own |
| Raincall Basin | `rolling_hills` | bounded `highland` steps and `wetland_delta` pools | `raincall_falls`: several inland waterfalls join monsoon pools without crossing a fixed road or POI envelope; `raincall_coastal_steps`: the eastern 600×300 gentle housing core remains dry, overrides ordinary relief and retains its §7/§14 limits |
| Kezamba | `plateau` | none outside civic and cenote grading | `kezamba_cenote`: a broad stepped central cenote is surrounded by flood-safe stilt-and-stone capital terraces; four independent graded ramps align with the fixed road gates and remain inside capital protection |
| Whispering Reedlands | `wetland_delta` | broad dry `lowland` levees | `whispering_reedmaze`: a legible reed maze fills the wet mask without enclosing an anchor or road; `whispering_totemways`: several independent raised routes cross it, while housing eligibility is confined to broad dry levees rather than narrow paths |
| Totemwater Reach | `wetland_delta` | bounded `lowland` delta islands | `totemwater_delta`: a broad branching river delta retains at least two independent dry routes around its principal arms; `totemwater_colossi`: several colossal carved totems provide long-range orientation outside road and anchor footprints |
| Thunderroot Wilds | `highland` | bounded `plateau` islands and small wet depressions | `thunderroot_exposures`: enormous exposed roots provide optional paths rather than required bridges; `thunderroot_ochresteps`: ochre rock terraces shape the storm-forest skyline while independent secondary approaches to The Shattered Line and The Skyglass Canopy remain open |

#### Holy Grounds and dragon-island group

| Zone | Primary relief | Secondary relief | Required landmarks and constraints |
|---|---|---|---|
| The Wyrmglass Crown | `mountain` | bounded `highland` fault terraces and two inner-shore `lowland` landing coves | `wyrmglass_ring`: an apparently closed mountain ring remains traversable by several land routes; `wyrmglass_faultfields`: crystalline terraces contain the protected functional anchor and reachable deposits of the all-six-gem apex mining camp; `wyrmglass_dragonspire`: the elevated dragon arena is independently reachable from both z = -125 and z = +125 east-shore landings and does not gate access to the mine |
| Gravesalt Escarpment | `highland` | one `mountain` salt escarpment and small `wetland_delta` salt pans | `gravesalt_whitewall`: the visible white escarpment contains multiple fixed passes rather than one choke; `gravesalt_tombways`: shallow generated tomb galleries remain traversable but immutable with the surrounding Holy Grounds and do not replace either surface crossing; `gravesalt_warcoast`: the two north/south military routes connect separately to the z = -125 and z = +125 Wyrmglass embarkation corridors |
| The Broken Causeway | `wetland_delta` | broad raised `lowland` islands | `broken_threeways`: a damaged raised causeway, a broad ford and an aqueduct path form three distinct north/south routes; `broken_marsh`: fixed lakes, river arms and marsh fill the intervening ground without placing both assigned frontier crossings behind one route or structure |
| The Shattered Line | `plateau` | bounded `rolling_hills` crater fields and low wet trench depressions | `shattered_breachwall`: a fortress line has several permanent traversable breaches; `shattered_noman`: broad burned no-man's-land carries trenches and craters without closing either north/south crossing; `shattered_siegeramp`: the eastern siege ramp remains separate from both crossings and the internal west/east trail |
| The Skyglass Canopy | `highland` | bounded `mountain` pale cliffs and `rolling_hills` forest terraces | `skyglass_escarpment`: several fixed ascents cross the pale cliff line; `skyglass_hangingways`: root and canopy paths remain optional alternatives over the terraces; `skyglass_warcoast`: the two north/south military routes connect separately to the z = -125 and z = +125 Stormscale embarkation corridors |
| Stormscale Summit | `mountain` | bounded `highland` volcanic terraces and two inner-shore `lowland` landing coves | `stormscale_caldera`: a volcanic mountain ring retains several independent ascents; `stormscale_gemterraces`: thunder terraces contain the protected functional anchor and reachable deposits of the second all-six-gem apex mining camp; `stormscale_dragonroost`: the summit-edge dragon arena is independently reachable from both z = -125 and z = +125 west-shore landings and does not gate access to the mine |

## 9. Authored travel and allowed-contact graph

The graph is undirected. The 57 routed pairs are the authoritative gameplay
neighbors used by travel, quests and `neighbors(id)`. The four outer-flank
pairs listed below are additionally allowed to touch geometrically but carry
no route, corridor, traversability guarantee or content operation. An allowed
pair need not touch in the final layout; every omitted pair is forbidden from
touching. No geometric boundary dual is created.

### 9.1 Accord internal graph

- Dwarf spine: Hearthpine Vale — Copperfell Foothills — Dur Brannoc —
  Stormvault Heights.
- Human spine: Dawnmere Fields — Goldmead Vale — Highcourt —
  Ashenward March.
- Elf spine: Silverleaf Glades — Starbough Vale — Lethariel —
  Glassroot Wilds.
- Capital axis, west to east: Frostbarrow Shelf — Dur Brannoc —
  Whitebridge Shire — Highcourt — Lorindor — Lethariel — Moonfall Wood.
- Heartland/front cross-links: Frostbarrow Shelf — Stormvault Heights;
  Whitebridge Shire — Ashenward March; Lorindor — Glassroot Wilds;
  Moonfall Wood — Glassroot Wilds; Stormvault Heights — Ashenward March —
  Glassroot Wilds.
- Boundary-only outer-flank contacts: Copperfell Foothills — Frostbarrow
  Shelf; Starbough Vale — Moonfall Wood.

### 9.2 Throng internal graph

- Undead spine: Stillgrave Hollow — Mournfen — Nhal Veyr —
  Blackwind Rise.
- Orc spine: Sunscar Flats — Redtusk Savanna — Gor Drazhak —
  Bannerbreak Mesa.
- Troll spine: Kapok Cradle — Raincall Basin — Kezamba —
  Thunderroot Wilds.
- Capital axis, west to east: Ossuary Reach — Nhal Veyr —
  Speargrass Reach — Gor Drazhak — Whispering Reedlands — Kezamba —
  Totemwater Reach.
- Heartland/front cross-links: Ossuary Reach — Blackwind Rise;
  Speargrass Reach — Bannerbreak Mesa; Whispering Reedlands —
  Thunderroot Wilds; Totemwater Reach — Thunderroot Wilds;
  Blackwind Rise — Bannerbreak Mesa — Thunderroot Wilds.
- Boundary-only outer-flank contacts: Mournfen — Ossuary Reach; Raincall Basin
  — Totemwater Reach.

### 9.3 Holy Grounds land graph and offshore travel

- The Holy Grounds land chain is Gravesalt Escarpment — The Broken Causeway —
  The Shattered Line — The Skyglass Canopy. No nonconsecutive pair in this
  chain is a route neighbor or allowed geometric contact.
- Both Stormvault Heights and Blackwind Rise have routes to Gravesalt Escarpment and
  The Broken Causeway.
- Both Ashenward March and Bannerbreak Mesa have routes to The Broken Causeway and
  The Shattered Line.
- Both Glassroot Wilds and Thunderroot Wilds have routes to The Shattered Line and
  The Skyglass Canopy.
- The Wyrmglass Crown and Stormscale Summit have **no land routes**. Their
  four boat routes are stored in a separate travel graph: a z = -125 southern
  and z = +125 northern approach to each island. Wyrmglass routes connect
  Gravesalt Escarpment to two distinct inward-shore landing beaches; Stormscale
  routes do the same from The Skyglass Canopy. These authored travel edges are
  open to both factions and never add a land-route neighbor.

The overlapping frontier-to-Holy edges distribute crossings across the whole
band and prevent one bridge or zone from becoming the sole faction route.

### 9.4 Authored land-route classes

The authored land-route graph remains exactly 57 edges: 30 primary, 24
secondary and 3 trail. The four allowed outer-flank contacts are excluded from
the route graph and have no route class or station sequence.

- Every edge in the six race spines and both west/east capital axes is a
  **primary road**. The primary classification ends at the race frontier; it
  does not create one intact arterial road across the Holy Grounds.
- Every edge listed as a heartland/front cross-link in §9.1 and §9.2 is a
  **secondary road**. Major villages, mining camps, outposts and other major
  POIs join their nearest primary or secondary route through a secondary spur.
- All twelve frontier/Holy-Grounds edges are secondary roads paired into six
  complete north/south crossings:

  - Stormvault Heights — Gravesalt Escarpment — Blackwind Rise;
  - Stormvault Heights — The Broken Causeway — Blackwind Rise;
  - Ashenward March — The Broken Causeway — Bannerbreak Mesa;
  - Ashenward March — The Shattered Line — Bannerbreak Mesa;
  - Glassroot Wilds — The Shattered Line — Thunderroot Wilds;
  - Glassroot Wilds — The Skyglass Canopy — Thunderroot Wilds.

  These are geographically neutral and open to both factions. Their secondary
  classification guarantees a traversable five-node route and twelve-node
  exclusion corridor, not intact paving: within the Holy Grounds they appear
  as damaged military roads, passes, fords and ruin paths.
- Each of the three consecutive internal Holy-Grounds edges has at least one
  **trail** crossing it. Together these trails preserve west/east alternative
  movement without turning the complete front into an intact primary road.
- Minor POIs connect by trails. A trail or secondary spur may end at its POI;
  it does not add an undeclared zone-neighbor edge.

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
  12,000/6,000/3,000 host nodes per species. All G2 requires a T4 pick to
  harvest. The total expected natural vein count plus the one ordinary camp
  budget is equal for all six race regions within **±5%**, normalized by
  accessible host volume rather than number of zones.
- Every race region supplies its cultural material ordinarily at the surface
  for its own architecture, trade and quests, and supplies a concentrated T4
  source in contested level-31+ land or its projected deep column. Foreign
  cultural material is optional PvP-counter input and never a universal
  progression requirement.
- Both apex camps contain the same count of every one of the six gem species:
  exactly two renewable sockets per species per island.
  Endpoint deposits are a shared bonus and do not compensate a deficient home
  budget.
- Each faction-native exclusive G2 species has at least one practical
  contested level-31+ surface route: Ruby for Accord raiders and Sapphire for
  Throng raiders. The y = −701 deep opening also permits cross-border mining
  beneath the opposing race-region columns, and both islands provide all six
  species by boat. Trade remains an alternative, never the only route.
- Every level-31–60 frontier and dragon-island zone has no home-faction
  construction owner. Both factions may dig and place ordinary terrain there,
  subject to tools and explicit hard-protected capital,
  functional-anchor or irreplaceable-route envelopes. Ordinary road and camp
  envelopes exclude claims and grade mapgen but do not block terrain mutation.
  This applies equally to all six faction frontier approaches and to both
  dragon islands.
- The four Holy Grounds zones are the shallow exception: neither faction may
  dig or place from the surface through y = -700 inclusive. At y = -701 and
  below, the universal contested deep rule resumes. The immutable ocean
  channels around the dragon islands remain non-editable at every y; protected
  lair/camp structures and their renewable sockets keep their own envelopes.
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
  uses the four fixed wetland-source zones; stormkelp uses both endpoint coasts
  and both high coastal approaches.
- Zone level controls gear tier. A visual biome patch never authorizes a mob,
  drop or gathering tier above the zone's content palette.

## 12. Capital and start envelopes

- Every capital zone has a 512×512 fixed build envelope and a terrain blend
  ring extending to 704×704. The protected POI is the final build envelope
  plus the existing 10-node surround. Only the 512×512 build envelope is
  guaranteed capital-zone ownership; the larger visual blend may cross a zone
  edge. Capital lookup uses the zone's single surface difficulty target.
  Hostile ambient spawning is disabled and level-60 guards remain explicit.
- A fixed 96×96 civic core contains the king's hall, waypoint and principal
  service court. Four fixed 32-node-wide road gates leave north/east/south/
  west. The road itself is authored by WP13 inside that reserved corridor.

| Capital | Outer/home gate | Front gate | West gate | East gate |
|---|---|---|---|---|
| Dur Brannoc | south → Copperfell Foothills | north → Stormvault Heights | Frostbarrow Shelf | Whitebridge Shire |
| Highcourt | south → Goldmead Vale | north → Ashenward March | Whitebridge Shire | Lorindor |
| Lethariel | south → Starbough Vale | north → Glassroot Wilds | Lorindor | Moonfall Wood |
| Nhal Veyr | north → Mournfen | south → Blackwind Rise | Ossuary Reach | Speargrass Reach |
| Gor Drazhak | north → Redtusk Savanna | south → Bannerbreak Mesa | Speargrass Reach | Whispering Reedlands |
| Kezamba | north → Raincall Basin | south → Thunderroot Wilds | Whispering Reedlands | Totemwater Reach |
- Four quadrant slots hold Market/Professions, Martial/Garrison,
  Lore/Spiritual and Residential/Cultural districts. The four roles are fixed;
  the world seed may permute their quadrants and choose a building variant.
- Terrain forms differ by race: Dur Brannoc is a granite terrace, Highcourt a
  gentle river plateau, Lethariel a terraced grove, Nhal Veyr a raised
  necropolis, Gor Drazhak a mesa shelf and Kezamba a drained/stilted cenote
  terrace. None is allowed to depend on accidental v7 land.
- The six kings are equal civic rulers and killable level-65 elite NPCs. Every
  king has exactly four level-60 elite royal guards. No capital is a superior
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
- Each starting settlement has a 128×128 build envelope, a blend ring out to
  256×256, protected spawn/waypoint/graveyard and a guaranteed road to the
  home zone. The first mandatory road beat reaches the race capital at level
  10 and unlocks its waypoint and civic-service introduction.

## 13. Mapgen and public zone contract

### 13.1 Horizontal and vertical authority

- WP40 uses native v7 only as the cave, ore, dungeon and stratum substrate.
  One project-owned horizontal evaluator and one globally queryable
  `H(full_seed_string, x, z)` own the final surface, water, logical biome,
  route and policy products.
- The pure horizontal module exposes at least
  `macro_region_at(x,z)`, `land_at(x,z)`, `id_at(x,z)`,
  `water_class_at(x,z)`, `nearest_path_at(x,z,optional_kind)` and
  `selected_anchor_2d(zone_id,slot_id)`. The canonical SVG and the mapgen
  adapter consume this same evaluator; no renderer-owned geometry exists.
- Engine climate competition is not authoritative inside the authored world.
  A full-seed selector chooses only from the owning zone's logical-biome
  palette. Surface content maps that frozen logical id to nodes and
  decorations without selecting a different biome.
- Surface writing uses one short typed priority:
  native protected content, fixed hard foundations, explicit crossing
  interfaces, paths, terrain repair, explicit water, biome surface, resources
  and decorations. Caves, ores, dungeons and strata outside the shallow
  authored shell survive the transaction.
- The new evaluator, compatibility adapters and consolidated VoxelManip
  callback remain disabled until one atomic production cutover removes both
  legacy WP18 geography writers. Two Grudgelands surface-writing pipelines are
  never enabled in one build.

### 13.2 Public `grug_zones` surface

The final registry exposes:

- defensive-copy `get(id)`, `at(pos)`, `neighbors(id)`,
  `travel_links(id)` and `anchor(zone_id,slot_id)`;
- allocation-free `id_at`, `biome_at`, `race_region_at`, `faction_at`,
  `territory_rule_at`, `pvp_rule_at`, `surface_mob_level_at`,
  `mob_level_at`, `guard_level_at`, `terrain_height_at` and
  `water_class_at`; and
- indexed `nearest_route_at`, `nearest_hydrology_at` and the unconditional
  `housing_eligible_at` centre predicate.

`housing_eligible_at(x,z) == true` means the complete 101 by 101 future
reservation passed every static exclusion. It never checks dynamic claims.
No stable `nearest_boundary_at`, boundary id or coast-component id is public.
A later consumer may add an approximate scalar margin query, but may not
restore boundary materialization without a separately reviewed requirement.

Every node-addressed public query accepts only finite Lua-number coordinates
inside the exact safe-integer range before and after nearest-integer,
half-away-from-zero normalization. Invalid, unsafe or malformed coordinates
are programmer errors rather than clamped or coerced input. One evaluator
instance binds one canonical full seed string; public queries never accept a
numeric-truncated seed.

### 13.3 Policy and compatibility

- `surface_mob_level_at` means the continuous gameplay-difficulty field.
  `terrain_height_at` means elevation. Existing
  `grug_core.surface_level_at(x,z)` already means terrain height and retains
  that semantic; it redirects to `terrain_height_at` only at the atomic
  cutover.
- `mob_level_at(pos)` combines the surface difficulty with the independent
  depth floor on land and zone-owned planned water. Exterior shelf returns nil
  at y >= 0 and the depth floor alone below y = 0. Deep ocean and dragon
  channels have no ordinary mob-level result; the Kraken Guard remains a
  separate fixed level-100 entity.
- `guard_level_at(pos)` is nil for every exterior class. Inside the capital
  512 by 512 build envelope plus its ten-node hard-protection apron it is
  exactly 60 at y >= -700. At y <= -701 and everywhere else on non-exterior
  land it returns the existing generic base
  `min(70, max(20, surface_mob_level_at(pos)))`. The fixed level-65 king
  remains outside this resolver.
- `faction_at` returns `accord`, `throng` or nil and never derives
  construction rights from `race_region`. `territory_rule_at` and
  `pvp_rule_at` apply full 3D precedence: bounded hard protection, immutable
  deep ocean/channels, shallow Holy Grounds, planned-water/shelf inheritance,
  ordinary land and the y = -701 contested-depth override.
- Existing `grug_core.territory_at`, `zone_at`, `mob_level_at`,
  `guard_level_at`, `difficulty_at`, `open_sea_at` and protection
  callers migrate through explicit adapters. `open_sea_at` maps to deep
  ocean, not planned water or a dragon channel. Old
  `core/inner/outer/coast/war_coast/ocean/strait/underground` spawn buckets
  may exist only as a temporary derived adapter.
- All fixed placements resolve through stable zone anchor ids. Slot vocabulary
  remains `start`, `capital`, `village_<n>`, `outpost_<n>`,
  `bandit_<n>`, `mine`, `mirefolk`, `clash_<n>`, `dragon`,
  `apex_mine` and `rare_<stable_rare_id>`. An absent slot returns nil;
  consumers never synthesize a replacement coordinate.
- Zone lookup scans only the small eligible macro-region set. A 128-node x/z
  index serves route, hydrology and other sparse-feature queries. Hot paths do
  not scan every feature record and reuse one x/z classification for the
  complete vertical column.

## 14. WP40 acceptance gate

### 14.1 Fixed 2D product

- Exactly 38 unique zones exist. Every zone hub lies in its zone; every zone is
  nonempty and connected on the complete integer-node grid of the finite
  authored extent.
- The result contains exactly one connected mainland and two connected
  islands. The Holy Grounds rectangle, six dry start cores, six capital
  ownership envelopes, island centres/envelopes and all fixed anchors retain
  their authored positions and owners.
- The 57 land routes connect their authored endpoints, stay inside land except
  at explicit crossing interfaces and remain split into exactly 30 primary,
  24 secondary and three trail classes with 7/16, 5/12 and 3/8 widths. An
  ordinary two-zone route enters no undeclared third zone. Required POI spurs
  and the separate boat graph are complete.
- Every emergent geometric contact belongs to section 9's complete 61-pair
  allowlist; allowed pairs need not all occur. No forbidden contact, detached
  sliver or path-created land is accepted.
- All four bays remain open and connected from outer water to their heads,
  stay at least 64 nodes wide, reach neither capital belt nor housing core,
  disconnect no prong and create no new land contact.
- Water precedence is total. Holy Grounds remains exact; deep ocean and both
  dragon channels are immutable; the nominal shelf uses the shared
  `expanded_land_at(80) and not land_at` classifier. Each island keeps two
  distinct 96-node approaches at z = -125 and z = +125, at most 10% route
  parity, a 48-node warning band on each shore and at least 104 hard no-flight
  nodes.
- Exactly ten whole-footprint housing-centre masks pass all static exclusions.
  The four coastal cores retain 600-node frontage and 300-node depth.
- One source snapshot produces byte-identical canonical 2D data and SVG.
  The SVG independently displays land/water, zones/labels, difficulty/PvP,
  routes, fixed and candidate anchors, ownership cores and housing masks. It
  reports validation failures but never mutates source data to repair them.

### 14.2 Height, policy and content

- One globally queryable project-owned height field is independent of emerge
  order and agrees between offline and engine loaders. It never uses engine
  spawn level or a generated chunk as global height authority.
- Every required relief profile, logical-biome palette, named landmark and
  anchor slot exists exactly once with a valid owner. Kragmar and Elandor
  source records are independently authored rather than reflected.
- The final difficulty lattice changes by at most two levels between every
  orthogonally adjacent walkable surface pair and along every ordinary route.
  Capital guard/depth/fixed-entity rules remain separate and exact.
- Selected anchors come from their 2D-frozen valid candidate set through one
  bounded hash choice. Terrain fitting succeeds without rejection, reselection
  or endpoint movement.
- Every wholly contained eligible 101 by 101 reservation in a coastal housing
  core has at most 12 nodes of natural relief. Housing capacity is reported
  from the fixed-layout canonical packing portfolio with an auditable upper
  bound.
- The G1/G2, cultural-resource, regional-parity, practical
  opposing/deep/island-access and 24-apex-slot ledgers pass over 32
  representative content seeds. Native, enemy-contested, deep-cross-border,
  apex-camp and trade access remain practical; all protected apex sockets are
  reachable and diggable with their required tool.
- Every `logical biome x zone` cell has a valid content result or an explicit
  civic/no-hostiles declaration. Surface water remains
  `default:water_source`; surface content never remaps logical ownership.

### 14.3 Mapgen, performance and rollout

- The pure typed planner has one deterministic operation order and preserves
  native caves, ores, dungeons and strata outside its owned shallow slices.
  Mapchunk order, owner-slice, content-ignore, lighting and liquid fixtures are
  deterministic.
- The new public adapters and writer become live only in the atomic cutover
  that removes `ocean_mask.lua` and `structures.lua` from the production
  pipeline. Repository checks prove that no second Grudgelands geography
  writer remains enabled.
- An 80 by 80 horizontal LuaJIT classification benchmark is no slower than
  5 ms median. Its absolute and relative difference from WP18 is published;
  more than 2 ms of added horizontal cost requires review. One horizontal
  result is reused for a vertical column.
- Lua source and tools pass plain Lua 5.1 syntax/static gates. Long full-layout
  and 32-seed populations run under LuaJIT. Targeted representative PUC 5.1
  KATs produce byte-identical canonical artifacts/digests. The retired exact
  T2 PCC/F1/F2 and topology populations remain historical evidence, not gates
  for the simple schema.
- WP40 is fresh-world-only. Headless generation, deterministic replay and the
  user's fresh-world GUI test complete release evidence. Migration of starts,
  respawns, outposts, camps, rares, patrols, mobs, gathering, waypoints, map,
  bosses, territory and mounts to zone ids is verified before old coarse
  geography fields are removed.

## 15. Exact PvP eligibility contract (WP41)

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
