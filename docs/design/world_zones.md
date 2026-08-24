# Named World Zones & PvP Geography

Decided 2026-08-10; complete named-zone pass 2026-08-11. This document supersedes the old radial
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
- The macro-map is reproducible: every named zone has a stable approximate
  position, shape, level range, biome palette and fixed neighbors. Zone and
  coastline boundaries may vary only inside a bounded corridor; world seed
  noise must never change the adjacency graph. A landmark's authored mask and
  collar remain stable identities, but their effective terrain influence is
  clipped per column to the landmark's final owning zone and may never modify
  another zone.
- The two faction sides are **progression and content-budget mirrors, not
  geometric mirrors**. They receive equivalent access to level bands,
  materials, PvP fronts, travel services and POI budgets, while their shapes,
  zone names, biome combinations and landmarks may differ.
- Each zone definition owns: display name and id, `territory_rule`, exactly one
  `race_region`, level range, PvP rule, fixed neighbors, authored boundary,
  allowed biome list, signature terrain/property, mob and gathering palette,
  and reserved POI slots. `race_region` means cultural/geological provenance;
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
- Surface mob level comes from the named zone and its authored within-zone
  progression, with continuous blends at legal neighboring boundaries. The
  old radial distance from a faction seat is not part of the target model.
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
- Capital zones are the one non-leveling exception to a single bracket. Their
  technical surface profile rises smoothly from level 20 at the outer/home
  road gate through level 25 at the civic centre and lateral gates to level 30
  at the front-facing gate. This keeps all four approaches continuous; no
  ambient enemy uses the profile inside the protected city itself.

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

## 7. World frame, scale and authored variation

- World axes stay conventional: west/east is x, Kragmar lies north at positive
  z, Elandor lies south at negative z, and the shared front is centred on z = 0.
- The Holy Grounds is the exact no-jitter outer rectangle
  **x = −2500..+2500, z = −250..+250**. It is authored land rather than ocean,
  although it may contain fixed inland lakes. Inside that x/z rectangle,
  terrain is immutable from the surface through y = −700 inclusive; the
  universal contested T5/T6 rule resumes at y = −701.
- Its nominal internal west/east chain is split at x = −1500, 0 and +1500:
  Gravesalt Escarpment is 1000 nodes wide, The Broken Causeway 1500, The
  Shattered Line 1500 and The Skyglass Canopy 1000. Each shared internal edge
  may displace by at most 64 nodes in the band interior, but tapers back to its
  nominal fixed vertex where it meets z = −250 or +250. Both incident zones
  use that one displaced edge.
- The binding authored mainland frame is x = −2,600..+2,600 and
  z = −3,000..+3,000. Mainland coastlines taper and vary inside that frame; the
  frame is not a rectangular landmass or a hard world border. Open sea
  continues beyond it. The two separately authored dragon-island envelopes
  may sit beyond the mainland coast without extending the mainland frame.
- Each continent owns an analytic `planned_mainland_footprint` inside that
  frame. The footprint contains both generated dry land and all deliberately
  authored bay, lake, river, marsh and civic-water masks. Its final outer
  perimeter—not every internal water shoreline—is the boundary from which the
  exterior 80-node coastal shelf is measured.
- Each continent has a binding three-lobed outer silhouette. Three broad
  cultural peninsulas carry the west, centre and east start/home spines; two
  long authored bay-water masks enter from the outer coast between them and
  prevent the three outer progressions from gaining undeclared **land** edges.
  The bays end before the capital line. Capital zones and their level-21–30
  heartlands form one continuous west/east land belt, and the land broadens
  again into one continuous three-sector frontier before meeting the Holy
  Grounds. Thus each mainland reads as **three outer prongs → capital belt →
  closed war front** and remains one connected landmass.
- The bays are planned parts of the mainland rather than exterior ocean. They
  have no 80-node shelf transition and may never classify as `deep_ocean`,
  regardless of authored width or depth. Their x/z masks continue the adjacent
  named-zone ownership. One universal water node fills every side; the owning
  logical biome controls only bed, shore and decoration dressing. An explicit
  analytic seam resolves any two-shore split; a water-only seam does not add a
  land edge to §9's adjacency graph. Bay
  variation may not close a bay, split a peninsula, reach the capital belt, or
  create a forbidden land neighbor. The masks create no additional guaranteed
  coastal-housing cores. Elandor and Kragmar use independently authored base
  coast/bay polylines and independent deterministic noise salts; one may not
  be produced by reflecting the other's coordinates or noise.
- The four bay base masks are defined by directed outer-mouth-to-inner-head
  centreline samples. `half-width` is the perpendicular water radius:

  | Bay | Centreline samples `(x, z; half-width)` |
  |---|---|
  | Elandor west | (-980,-2940;360) → (-900,-2600;280) → (-1040,-2300;190) → (-980,-2000;80) |
  | Elandor east | (+900,-2920;330) → (+1080,-2580;250) → (+920,-2280;180) → (+1020,-1990;80) |
  | Kragmar west | (-1080,+2930;320) → (-1200,+2620;260) → (-940,+2300;190) → (-1060,+2010;80) |
  | Kragmar east | (+820,+2960;370) → (+700,+2630;250) → (+1050,+2320;170) → (+900,+1980;80) |

  The analytic base mask is the union of round-joined, variable-width segment
  capsules. For a directed sample segment `A -> B`, integer column `P`,
  `v = B - A`, `L = v dot v`, `N = (P - A) dot v` and
  `C = cross(v, P - A)`. At `N <= 0` or `N >= L`, strict squared distance to
  the corresponding endpoint is compared with that endpoint's squared
  half-width. At `0 < N < L`, let
  `width_num = rA * (L - N) + rB * N`; the column is base water exactly when
  `C^2 * L < width_num^2`. Equality is dry. This exact integer-rational
  predicate, `strict_rational_variable_width_capsule_union_v1`, is the one
  membership authority shared by mapgen, zone-water lookup and geometry
  audits; a Q16-rounded projection, host-float closest point or approximate
  distance may not decide membership. The implementation performs only
  semantics-preserving conservative early rejects and checked products whose
  exact values fit within `2^53 - 1`.
- The base-water owner is selected from the same exact segment projections,
  not from a second mask. Exact endpoint squared distances and interior
  rational squared distances choose the nearest centreline segment; its cross
  sign selects the declared side owner, and an exact distance or centreline
  tie belongs to the lower numeric zone ID. The inner head has a round cap and
  the outer mouth reaches the final planned-footprint perimeter, where the
  one declared mouth aperture retains exact Base-Bay water on perimeter
  equality and the strict exterior is discarded.
  The last listed sample is the fixed positive-width **head shoulder** `C`,
  with radius 80 and the original 160-node cross-section.
- Raw planned Bay water adds exactly two zero-jitter analytic **closure
  wings** per bay, eight in total. Each wing runs from `C` to one of the two
  existing dry triple junctions that flank that bay head and tapers linearly
  from radius 80 at `C` to radius zero at the junction `J`. Wing interiors are
  water; exact wing-side equality and `J` itself are dry. Both wings are
  required: together they close exactly the two otherwise-unowned head wedges.
  They approach the capital-belt boundary but put no water at a junction or in
  the belt interior.
- Closure wings change none of the pre-existing 57 dry land-edge controls, IDs
  or incident-zone pairs and create no dry edge or junction themselves. They
  are not a chord, dry fan or land-face continuation. Each wing's two sides
  continue the adjacent outer-bank and central-head zone ownership without
  adding those sides to the land graph. The original centreline samples, round
  head shoulder and outer mouth remain unchanged even though the raw planned-
  water mask is explicitly larger than the Base mask at the two closures.
- Final planned bay water fills isolated single-column dry notches in the raw
  mask, once and simultaneously across all bays, so planned water carries no
  one-column dry intrusions. Each compiled bay stores its sorted fill columns
  as the only downstream fill authority, and ownership follows that bay's
  existing exact rational owner policy without introducing a new tie. The
  qualifying predicate and its rejection cases are compiler concerns: see
  [wp40-source-authority.md](../research/wp40-source-authority.md) §7.
- Bay banks are integer-column boundaries derived from the final planned-water
  classifier, not literal shore polylines. The source declares 20
  coordinate-free bank components, five per bay, each naming its bay, two
  terminals, its one incident face arc, canonical direction and water side —
  and no coordinates, controls or copied shape. The compiler resolves every
  terminal and materializes every chain exactly once; all consumers use that
  one component ID and its byte-identical stations.
- The three terminal kinds — mouth aperture, land-edge transition and wing
  junction — share one resolution authority. It rejects rather than falling
  back, and it changes neither aperture membership nor the compiled aperture
  payload. Wing endpoints are trace-independent. Terminal resolution, the
  trace algorithm and wing-tail selection are compiler concerns: see
  [wp40-source-authority.md](../research/wp40-source-authority.md) §3.
- The horizontal classifier first evaluates the independent final literal
  planned-footprint perimeter. A point strictly outside is exterior. Exactly
  four checksum-covered mouth-aperture records—one for each Base Bay—bind the
  existing Bay ID and first centreline sample to the incident perimeter and
  its two spans, without copying a second mouth shape. On perimeter equality
  inside one such aperture, exact
  `strict_rational_variable_width_capsule_union_v1` membership and its existing
  owner rule take precedence and return planned water. The four perpendicular
  analytic cross-sections remain exactly 720, 660, 640 and 740 nodes for
  Elandor west/east and Kragmar west/east respectively. Immediately strictly
  outside an aperture begins that coast's `coastal_shelf`.
- Every other exact perimeter-equality point remains inside the finite mainland
  footprint and is dry land owned by the incident `perimeter_span.zone_id`. At
  an exact declared clipped shared-edge-to-perimeter
  attachment, the canonical shared-edge half-open rule takes precedence and a
  geometric equality belongs to the lower numeric incident zone ID. At a
  perimeter vertex between two incident spans with no attachment, the lower
  numeric span-zone ID wins. Outside the four apertures, `coastal_shelf` begins
  strictly outside the dry equality boundary.
- Each compiled aperture is one nonempty contiguous half-open interval
  `[first_station, end_station)` in the canonical deduplicated perimeter-
  station order. `first_station` and the station immediately preceding
  `end_station` are included planned water with the exact Base-Bay owner;
  `end_station` is excluded, and both it and the station immediately before
  `first_station` must fail the strict Base-Bay predicate and fall through to
  dry perimeter ownership. Every included station must pass that predicate for
  the one referenced Bay. The interval may not wrap, overlap another aperture
  or acquire a second run. An
  exact Base-Bay segment/centreline tie inside it retains the existing lower-
  numeric shore-owner rule; exact analytic bank equality is not strict water
  and therefore falls through to the dry span/attachment/vertex precedence.
- In the strict footprint interior the classifier tests base bay water and its
  exact centreline owner, then closure-wing-exclusive water and its explicit
  side owner, then the canonical half-open dry-face result. Closure wings are
  always clipped to strict footprint interior and may never use a mouth-
  aperture exception. Base-Bay water may reach perimeter equality only through
  its one declared aperture; no other perimeter water is permitted.
- The two wings of one bay have a stable order, permitted only after validation
  proves that their integer interiors do not overlap outside the base mask. A
  wing-centre tie belongs to the lower numeric zone ID. Raw dry membership may
  overlap on a declared shared edge or junction, but its half-open tie still
  returns one zone. Any undeclared dry cross-face seam or intersection outside
  final planned water is invalid.
- The 61-edge land-boundary dual is reconstructed only from its declared edge
  IDs: the pre-existing 57 records remain byte-identical and §7 adds four
  boundary-only flank records. Water wings confer no land adjacency. The
  literal analytic outer footprint and its perimeter remain independent
  authority: dry faces and water masks are clipped and validated against that
  perimeter, never unioned to infer it, and the exterior shelf is measured only
  from that perimeter.
- Each bay shoreline may displace normally from that base by at most **48
  nodes**, with wavelength at least 256, and tapers to zero at every listed
  sample. The mouths are 640–740 nodes wide and the base head shoulders are 160
  before variation; no accepted seed may leave less than 64 nodes of open base
  water at a shoulder. The base head shoulders remain 80–110 nodes outside the
  capital-belt base edge.
  The directed centreline is also the deterministic base-water ownership seam
  between the two adjacent shore-side zones; an exact tie resolves by
  stable zone id, and the seam never enters the land-adjacency graph.
  This variation leaves the authored centreline and four base samples
  unchanged and varies one symmetric effective half-width, never independent
  left/right banks. Bank-station selection, the noise field, its 96-station
  taper and the exact width predicate are compiler concerns: see
  [wp40-source-authority.md](../research/wp40-source-authority.md) §7.
- The Wyrmglass Crown and Stormscale Summit island centres are fixed at
  **(−3150, 0)** and **(+3150, 0)**. Each has a binding 600×700 authoring
  envelope: the centered closed axis-aligned rectangle with x radius 300 and
  z radius 350. Its authored, culturally distinct coastline stays inside that
  rectangle. After all mainland and island coast
  variation, every island shore remains separated from every mainland land
  point by at least **200 ocean nodes**.
- From either final shore, the first **48 ocean nodes** form the flight warning
  band. Removing both warning bands from the certified minimum channel leaves
  at least **104 nodes** of hard no-flight ocean. The complete water channel,
  including both warning bands, is immutable at every y. Terrain, protection,
  flight and boat-route validation derive these masks from the same geometry.
- Ordinary exterior coasts use an analytic horizontal water classification
  derived from the final outer perimeter of the planned mainland or island
  footprint, never from the nodes currently present. Equality on the final
  mainland perimeter is dry land except for the four exact planned-water mouth
  apertures above. The first **80 nodes strictly outside that perimeter** form
  `coastal_shelf`, and beyond them begins `deep_ocean`. Shelf columns inherit
  the adjacent perimeter zone's
  `race_region`, PvP state and terrain policy: the home faction may edit a
  peaceful shelf, both factions may edit a contested shelf, and the universal
  contested deep rule applies at y = -701 and below. `deep_ocean` is immutable
  at every y and cannot occur anywhere inside a planned mainland footprint.
- An `immutable_dragon_channel` 2D mask overrides ordinary shelf distance.
  Every x/z point inside it denotes an immutable full-height column regardless
  of whether its current node is water, air, seabed or deep rock. Players
  therefore cannot fill, drain, bridge or tunnel through a channel. Both the
  warning and hard-flight sub-bands remain terrain-immutable.
- Horizontal classification has one exact precedence. Planned Base-Bay water
  is considered first in strict mainland interior or on its own mouth-
  aperture equality; closure-wing water is strict-mainland-interior-only.
  Mainland, island and the
  fixed Holy Grounds footprint—including every perimeter equality—then return
  land. Only a point outside all three closed land authorities is strict
  exterior, where membership in either closed integer dragon-channel polygon,
  including its own segment equality, returns `immutable_dragon_channel`;
  remaining strict exterior becomes shelf or deep ocean. A channel therefore
  never steals land, a land-perimeter equality, an aperture, Base-Bay water or
  closure-wing water.
- Exterior dressing inherits one `coast_source_zone_id` from the nearest
  allowed compiled outer-coast component. The closed roster is the 18
  mainland `perimeter_span` components, the Gravesalt west and Skyglass east
  fixed Holy outer-coast arcs, and the Wyrmglass and Stormscale island arcs;
  closing edges are excluded. This value is
  inheritance only and never changes zone membership, race region, territory
  or adjacency. It is `nil` outside the compiled interesting extent. The exact
  distance measure and its tie-break order are compiler concerns: see
  [wp40-source-authority.md](../research/wp40-source-authority.md) §8.
- Each dragon channel contains two guaranteed **96-node-wide boat approach
  corridors**, centred at **z = -125** and **z = +125**. On each island, the
  southern route is the shorter approach from Elandor and the northern route
  the shorter approach from Kragmar; this is geographic orientation only, and
  both routes are open to every player. The mainland ends are authored in
  Gravesalt Escarpment for The Wyrmglass Crown and The Skyglass Canopy for
  Stormscale Summit. Each route crosses directly to a distinct landing beach
  on the island's inward-facing shore. Coast variation may shape the route but
  may not narrow, merge or remove either corridor, and the two faction-oriented
  route lengths to either island may differ by no more than 10%.
- Authored bays, lakes, rivers, marsh channels, cenotes and other planned water
  remain part of their named zone rather than becoming ocean classes. They
  inherit that zone's PvP, terrain and flight policy and may be bridged, filled
  or drained wherever that policy permits. Their authored water masks remain
  claim-ineligible even after player modification. A water-only boundary
  between two owning zones is resolved deterministically but is excluded from
  the land-adjacency graph.
- All generated surface water has one player-facing identity and uses
  `default:water_source`: planned inland water, connected bays, exterior shelf,
  deep ocean and dragon channels do not introduce distinct salt, fresh,
  brackish, brine, faction or regional liquid nodes. WP40 normalises any v7
  surface river-water output inside its authoritative overlay accordingly.
  Subterranean lava and other non-water liquids are outside this rule.
- Water variation is environmental rather than a liquid taxonomy. Ordinary
  water bed, shore and decorations derive from the active logical biome's
  existing surface/riverbed palette. A named landmark may explicitly override
  bed material, shoreline material, depth and decoration set inside its fixed
  mask—for example a cenote, salt pan, crater lake or grave marsh—but it still
  contains the universal water node. There is no zone-wide `water_profile`,
  `water_kind`, salt/fresh metadata or gameplay distinction to expose through
  `grug_zones`.
- The six capital centres are fixed x/z map anchors:

  | Faction | West | Centre | East |
  |---|---:|---:|---:|
  | Kragmar | (−1800, +1500) | (0, +1500) | (+1800, +1500) |
  | Elandor | (−1800, −1500) | (0, −1500) | (+1800, −1500) |

  Their surface y is resolved from terrain and the capital-platform contract;
  seed variation may not move their x/z centres.
- The binding base extent of Elandor's continuous capital/heartland belt is
  **z = -1900..-1100**; Kragmar's is **z = +1100..+1900**. At the capital
  latitude its seven west/east base cells are:

  | x interval | Elandor | Kragmar |
  |---:|---|---|
  | -2600..-2200 | Frostbarrow Shelf | Ossuary Reach |
  | -2200..-1400 | Dur Brannoc | Nhal Veyr |
  | -1400..-400 | Whitebridge Shire | Speargrass Reach |
  | -400..+400 | Highcourt | Gor Drazhak |
  | +400..+1400 | Lorindor | Whispering Reedlands |
  | +1400..+2200 | Lethariel | Kezamba |
  | +2200..+2600 | Moonfall Wood | Totemwater Reach |

  Each 800-node capital cell contains its complete 704×704 terrain-blend
  envelope with 48 nodes to either base x edge and either belt edge. That
  48-node margin is reserved layout space, not boundary-noise allowance:
  visible zone boundaries may curve outside an envelope but may never enter or
  reassign any part of it.
- Elandor's frontier occupies the base band **z = -1100..-250** and Kragmar's
  **z = +250..+1100**. The two frontier separator base polylines use these
  fixed control vertices:

  | Separator | Elandor south→north/front | Kragmar north→south/front |
  |---|---|---|
  | west/centre | (-1400,-1100) → (-900,-900) → (-750,-250) | (-1400,+1100) → (-900,+900) → (-750,+250) |
  | centre/east | (+400,-1100) → (+900,-900) → (+750,-250) | (+400,+1100) → (+900,+900) → (+750,+250) |

  The belt-side vertices preserve the exact §9 heartland/front contacts. The
  rapid shift to approximately equal-width frontier sectors prevents the extra
  Elf/Troll heartland cells from also granting a much larger frontier. The
  Holy-side vertices create the paired two-zone contacts against the four
  fixed Holy Grounds intervals. Shared boundary variation may move at most 64
  nodes between control vertices and tapers to zero at all three vertices.
- The six starting/respawn-settlement centres are fixed on the same race axes:

  | Faction | West | Centre | East |
  |---|---:|---:|---:|
  | Kragmar | (−1800, +2550) | (0, +2550) | (+1800, +2550) |
  | Elandor | (−1800, −2550) | (0, −2550) | (+1800, −2550) |

  Their surface y is terrain-derived and seed variation may not move their x/z
  centres. Each stands inside its race's claim-free level-1–10 starting zone.
- Every centre lies in a guaranteed **600×500 dry start core**, centred on the
  anchor: total x width 600 (`centre x ±300`) and total z depth 500 (`centre z
  ±250`). A core belongs wholly to its level-1–10 starting zone and
  contains no planned water, forced cliff, ravine or other zone. Its complete
  256×256 starting-settlement terrain-blend envelope and unobstructed primary
  road exit therefore fit inside it on every accepted seed.
- Each starting zone is the seaward cap of exactly one cultural peninsula and
  has only its corresponding level-11–20 home zone as a **land** neighbor. The
  home zone wraps both flanks and the landward side of the start cap, then
  continues as a broad neck to the capital belt. The two authored bays keep
  different start/home spines from acquiring extra land edges. The western and
  eastern home zones use their outer side-coast frontage for the guaranteed
  housing strips below; a centre home zone need not reach the exterior coast.
- At the outer edge of the capital belt (`z = -1900` for Elandor and `z =
  +1900` for Kragmar), each home neck terminates in exactly its capital-cell
  base interval: west `x = -2200..-1400`, centre `x = -400..+400`, east `x =
  +1400..+2200`. Thus Copperfell Foothills/Mournfen feed Dur Brannoc/Nhal Veyr,
  Goldmead Vale/Redtusk Savanna feed Highcourt/Gor Drazhak, and Starbough
  Vale/Raincall Basin feed Lethariel/Kezamba. The primary race spine passes
  through the start core, home neck and capital gate without a detour.
- The shared start/home base boundaries are the following directed polylines.
  Their endpoints deliberately lie in authored bay water or beyond the
  mainland frame:

  | Start / home boundary | Control vertices `(x, z)` |
  |---|---|
  | Hearthpine Vale / Copperfell Foothills | (-2700,-2760) → (-2310,-2570) → (-2150,-2210) → (-1800,-2140) → (-1450,-2210) → (-1050,-2250) |
  | Dawnmere Fields / Goldmead Vale | (-1050,-2250) → (-650,-2230) → (-350,-2170) → (0,-2120) → (+350,-2180) → (+650,-2240) → (+950,-2250) |
  | Silverleaf Glades / Starbough Vale | (+950,-2250) → (+1450,-2210) → (+1800,-2150) → (+2150,-2230) → (+2310,-2580) → (+2700,-2740) |
  | Stillgrave Hollow / Mournfen | (-2700,+2740) → (-2320,+2580) → (-2160,+2210) → (-1800,+2140) → (-1440,+2200) → (-970,+2260) |
  | Sunscar Flats / Redtusk Savanna | (-970,+2260) → (-660,+2240) → (-360,+2180) → (0,+2130) → (+360,+2190) → (+680,+2230) → (+1020,+2250) |
  | Kapok Cradle / Raincall Basin | (+1020,+2250) → (+1440,+2200) → (+1800,+2140) → (+2160,+2210) → (+2320,+2590) → (+2700,+2760) |

  Mapgen clips each varied polyline against the final analytic land mask. The
  clipped result must be exactly one connected transverse land boundary with
  one shoreline endpoint on each side of its cultural peninsula; water and
  out-of-frame remnants are discarded. The start zone is always the seaward
  side and the home zone the landward side.
  A declared edge/perimeter attachment has one joint endpoint, not a connector
  or a post-raster snap. Each displaced edge raster is split into maximal
  final-dry intervals, and exactly one interval must satisfy both ordered
  source obligations; zero or multiple qualifying intervals reject, and
  longest-, first- or index-based selection is forbidden. The six edges
  carrying the eight bay transitions resolve their terminals jointly against
  one combined probe, so an edge never picks two terminals independently. The
  interval, probe and terminal algorithms are compiler concerns: see
  [wp40-source-authority.md](../research/wp40-source-authority.md) §4.
- Shared start/home boundaries use the ordinary maximum 64-node displacement,
  wavelength and shared-edge rules, tapering to zero at every listed control
  vertex. Their base geometry stays at least 96 nodes from the corresponding
  600×500 dry start core, and the varied line must retain at least **32 nodes**
  of clearance from it. Variation may not enter a dry core or primary-road
  corridor, produce a second clipped component, sever a home neck, undercut a
  coastal-housing guarantee, move a capital-belt contact or change the
  land-neighbor graph. Elandor and Kragmar use separate coordinate sets and
  separate noise salts; neither runtime mask may be obtained by reflection.
- The base outer perimeter of each `planned_mainland_footprint` is the directed
  chain below, listed from the western Holy-Grounds endpoint around the outer
  side to the eastern endpoint. The straight shared land edge back along `z =
  -250` or `z = +250` closes the analytic polygon; that closing edge is not a
  coast. These chains describe the **outer planned-footprint perimeter**, not
  the dry shores within the two authored bays:

  - Elandor: `(-2500,-250) → (-2470,-650) → (-2490,-1050) →
    (-2560,-1500) → (-2600,-1900) → (-2580,-2200) → (-2600,-2500) →
    (-2470,-2760) → (-2250,-2920) → (-1800,-2960) → (-1350,-2920) →
    (-980,-2940) → (-520,-2910) → (0,-2960) → (+460,-2930) →
    (+900,-2920) → (+1320,-2930) → (+1800,-2950) → (+2240,-2925) →
    (+2470,-2740) → (+2600,-2500) → (+2580,-2200) → (+2600,-1900) →
    (+2550,-1500) → (+2490,-1050) → (+2530,-650) → (+2500,-250)`.
  - Kragmar: `(-2500,+250) → (-2540,+620) → (-2480,+1050) →
    (-2560,+1480) → (-2600,+1900) → (-2580,+2200) → (-2600,+2500) →
    (-2480,+2750) → (-2260,+2920) → (-1800,+2960) → (-1440,+2940) →
    (-1080,+2930) → (-560,+2940) → (0,+2970) → (+440,+2920) →
    (+820,+2960) → (+1280,+2920) → (+1800,+2960) → (+2250,+2920) →
    (+2480,+2760) → (+2600,+2500) → (+2580,+2200) → (+2600,+1900) →
    (+2540,+1500) → (+2500,+1000) → (+2550,+600) → (+2500,+250)`.
- Four zero-jitter land-boundary records close the outer home/heartland flanks
  without changing any of the pre-existing 57 edge records:

  | Edge | Directed endpoints | Incident zones |
  |---|---|---|
  | `land_058` | `(-2600,-1900) -> (-2200,-1900)` | Copperfell Foothills / Frostbarrow Shelf |
  | `land_059` | `(2200,-1900) -> (2600,-1900)` | Starbough Vale / Moonfall Wood |
  | `land_060` | `(-2600,1900) -> (-2200,1900)` | Mournfen / Ossuary Reach |
  | `land_061` | `(2200,1900) -> (2600,1900)` | Raincall Basin / Totemwater Reach |

  Each segment joins an existing literal outer-perimeter vertex to an existing
  capital-belt junction. These four adjacencies are **boundary-only**: they
  carry no route class/station/interface, road surface/corridor, route or
  capital-road gate product, travel/traversability promise, or content
  operation. They do carry the ordinary checksum-covered shared-boundary
  relief gate `G` controls required by §7, with no route semantics. Touching a
  perimeter vertex does not grant coast authority; the existing literal
  perimeter spans remain the sole outer-coast and shelf source. The four
  records change no perimeter, shelf, base bay, closure wing, start core or
  600×300 coastal-housing geometry.
- The four first bay samples `(-980,-2940)`, `(+900,-2920)`,
  `(-1080,+2930)` and `(+820,+2960)` are exact outer-perimeter vertices. Bay
  geometry meets the perimeter there, and each sample owns exactly one of the
  four mouth-aperture records above. Base-Bay water crosses equality only in
  that record's exact half-open interval; all remaining equality is dry.
  Subtracting the resulting mask from dry land creates the bay shores without
  making those shores exterior shelf.
- Ordinary outer-coast displacement is at most 96 nodes, uses wavelength at
  least 256 and tapers to zero at every listed perimeter vertex. It stays
  inside the binding mainland frame, retains at least 32 nodes from every dry
  start core and clips the six start/home lines without moving their interior
  vertices. A seed that breaks those constraints is invalid rather than
  silently clamped into a different topology.
- On each western/eastern side, the two perimeter segments between the fixed
  `|z| = 1900`, `|z| = 2200` and `|z| = 2500` vertices are the guaranteed
  coastal-housing frontage. Their final shoreline stays inside `|x| =
  2580..2600`. Coast and start/home variation are jointly damped there so a
  connected 300-node-deep home-zone core remains inland along the complete
  at-least-600-node shoreline arc. This local envelope overrides the ordinary
  96-node coast budget and is audited after every static exclusion.
- Four existing level-11–20 housing zones receive guaranteed coastal housing
  land: Copperfell Foothills and Mournfen on the western mainland coasts,
  Starbough Vale and Raincall Basin on the eastern mainland coasts. Each must
  contain a continuous, gently buildable housing-eligible strip along its
  shoreline. After coastline variation and every static exclusion are applied,
  that strip must retain at least **600 nodes of continuous shoreline frontage**
  and **300 nodes of buildable inland depth**. This is a minimum usable geometry,
  not a rectangular visible boundary or a guaranteed Claim-Stone quota: the
  authored strip may curve and taper with the natural coast, but no accepted
  seed may undercut either dimension. Inside this guaranteed strip, every
  possible 101×101 reservation that remains wholly in its core has at most
  **12 nodes of natural ground-height variation**. Its generated ground may
  retain small waves and ordinary surface detail, but the core contains no
  mandatory cliff, ravine, river or lake. Ground height ignores trees,
  structures and later player edits. A Claim Stone's complete reserved 101×101
  projection remains on land and may touch, but never cross, the final
  shoreline; planned zone water and coastal shelf are public terrain and never
  part of a housing reservation. This gentle-core guarantee is a mapgen audit,
  not a general runtime slope restriction on Claim-Stone placement elsewhere.

Orientation schematic; §9, not this table, defines exact adjacency:

| North → south | West | Centre | East |
|---|---|---|---|
| Kragmar outer/home | Stillgrave Hollow → Mournfen | Sunscar Flats → Redtusk Savanna | Kapok Cradle → Raincall Basin |
| Kragmar capitals/heartland | Nhal Veyr / Ossuary Reach | Gor Drazhak / Speargrass Reach | Kezamba / Whispering Reedlands / Totemwater Reach |
| Kragmar frontier | Blackwind Rise | Bannerbreak Mesa | Thunderroot Wilds |
| Holy Grounds mainland | Gravesalt Escarpment | Broken Causeway / Shattered Line | Skyglass Canopy |
| offshore dragon islands | Wyrmglass Crown | — | Stormscale Summit |
| Elandor frontier | Stormvault Heights | Ashenward March | Glassroot Wilds |
| Elandor capitals/heartland | Dur Brannoc / Frostbarrow Shelf | Highcourt / Whitebridge Shire | Lethariel / Lorindor / Moonfall Wood |
| Elandor home/outer | Copperfell Foothills → Hearthpine Vale | Goldmead Vale → Dawnmere Fields | Starbough Vale → Silverleaf Glades |
- The map promises no target journey duration. Fixed anchors, authored road
  routes, terrain and the player's available mount determine actual travel
  time; roads must be geographically legible and must not add artificial
  detours merely to reach a duration target.
- Ordinary zone boundaries may move at most **64 nodes** from their authored
  base edge, coastlines at most **96** within their binding envelopes, and a
  peaceful/contested boundary at most **32**. Boundary noise has a wavelength
  of at least 256 nodes. A
  96-node buffer around fixed anchors and road gates has no boundary jitter.
  For every no-jitter source, damping is exactly zero at world Chebyshev
  distance `d∞ <= 96`, fades by smootherstep to `d∞ = 192`, and is full beyond
  it. Multiple sources use their minimum factor, and reversing an authored
  segment reverses the same factors rather than changing them. The exact
  damping formula and its fixed-point evaluation are in
  [wp40-source-authority.md](../research/wp40-source-authority.md) §1.1; this paragraph states the guarantee, not the computation.
  Displacement is applied exactly once per record: authored controls shift
  along canonical normals, one record-wide topology ceiling is selected, and a
  single final raster emits the result. There is no second displacement, snap
  or interpolation, and a remaining failure rejects the seed rather than
  selecting another ceiling.
- Each planned mainland closes through a fixed zero-displacement six-edge
  closure, so neither mainland silhouette varies at its closing arcs.
- The four-way Ashenward and Bannerbreak junctions carry fixed zero-jitter
  departure stations so no digital one-edge trunk can form. The four degree-two
  junctions whose columns are bay water dissolve entirely into declared
  edge-to-bank transitions; the remaining 34 relief junctions keep their
  incident edge pairs, and all eight perimeter attachments stay separate
  terminal authorities. After every category resolves, all 38 dry faces must
  still be closed and counterclockwise, and either simple or — since the
  2026-08-20 §11.5-C correction as completed by §11.9
  (`wp40-t2-contracts.md`) — accepted with window-guarded join-local,
  locally non-crossing self-touches at bay-transition terminals (zero-width
  filament appendixes and interior-beside pinches), their region truth
  derived by winding.
- The measured extreme-corpus seeds are scored on pre-displacement source
  stations only, so seed selection never depends on the compiled result it
  selects.
  The fixed-point arithmetic, ceiling scan, closure resolver, junction gates
  and exact scoring identity are compiler concerns: see
  [wp40-source-authority.md](../research/wp40-source-authority.md) §§1, 2 and 5.
- No zone core may narrow below 256 nodes and no authored travel corridor below
  96 nodes. This is the macro-terrain neck that keeps a route traversable, not
  the narrower road/claim-exclusion width below. Seed variation may not remove
  a route, create a new neighbor or cut a POI off from its road.
- Macro relief is a zone property independent of logical biome, level,
  `race_region` and territory. Its six standard profiles use inclusive surface
  elevation bands relative to the configured mapgen water level:

  | Relief id | Elevation above water level |
  |---|---:|
  | `wetland_delta` | +2..+24 |
  | `lowland` | +8..+56 |
  | `rolling_hills` | +24..+96 |
  | `plateau` | +56..+144 |
  | `highland` | +96..+224 |
  | `mountain` | +160..+360 |

  Every land zone declares exactly one primary relief profile. It may contain
  deterministic, explicitly bounded secondary-profile masks; biome patches do
  not implicitly change relief. V7 supplies natural fine structure inside the
  authored envelope, while the authoritative surface overlay keeps ordinary
  terrain inside the selected band.
  The mapping is inclusive of both band endpoints, so each profile's stated
  elevation range is exactly reachable. Its exact formula and input clamping
  are compiler concerns: see
  [wp40-source-authority.md](../research/wp40-source-authority.md) §7.
- Ordinary profile and zone transitions blend smoothly. A forced cliff,
  ravine, escarpment or abrupt elevation step exists only through a named,
  authored landmark mask. Roads, capital and starting-settlement terrain,
  structure envelopes and the four guaranteed coastal-housing cores apply
  their own grading after general relief and take precedence where they
  overlap. The per-zone profile and landmark assignment is binding registry
  data rather than an emergent result of v7 noise.
  Each of the 38 multi-edge endpoint junctions carries one authored relief
  record, and relief blends across a shared boundary over a 96-station support
  on each side. Two supports can never overlap: an edge shorter than 192
  station steps is rejected outright rather than blended. Junction selection,
  the weighting and the landmark replacement hash are compiler concerns: see
  [wp40-source-authority.md](../research/wp40-source-authority.md) §7.
- The common macro-relief height `H` exists on every zone-owned authored
  surface column: ordinary dry land, dry residue adopted into a zone face by
  the partition authority, and all zone-owned Planned Water. It does not exist
  on the exterior coastal shelf, deep ocean or immutable dragon channels,
  whose separate exterior profiles apply. If raw dry faces meet on a declared
  shared edge or junction, the canonical half-open face rule selects one zone
  before `H` is evaluated.
- Final surface ownership is resolved exactly once for each `H`-domain column
  before landmark composition. An authored exact mask or positive collar has
  effective influence only where that owner equals the landmark's declared
  `zone_id`; elsewhere its effective mask and weight are zero. Missing or
  ambiguous ownership inside the `H` domain is invalid world data. This owner
  clip preserves the authored mask and collar as registry and diagnostic
  identities rather than rewriting either one to follow a seed-varied border.
- Every named-landmark collar with positive influence contributes to the
  natural surface in its declared `base_h_priority` order after the owner clip;
  a higher-priority landmark is applied later to the already-composed height.
  Zero-influence and foreign-owner collars do not participate. The exact
  authored landmark mask remains its own identity and is never replaced or
  erased by the owner clip, collar-distance calculation or overlap priority.
  Required-route clearance is checked against the final composed surface and
  the later route product.
- Owner clipping alone never authorizes an abrupt final terrain feature. C-a2
  structurally proves that every cardinally adjacent Dry-to-Dry final-owner
  change maps to a compiled final land-edge or junction support and that the
  post-landmark heights enter its existing 96-station blend. An undeclared dry
  owner seam is invalid world data. Adopted residue belongs to its final dry
  face and creates no separate dry cross-face authority. C-b proves final
  Planned-Water bed and bank continuity, including internal Bay or Wing owner
  seams; D-2 proves every `H`-to-exterior coast, shelf or channel transition.
- A shared-boundary relief junction influences an incident edge only while
  that edge's chosen final raster still ends at the exact authored junction.
  A clipped terminal elsewhere keeps the edge's native relief gate and does
  not create a replacement junction. Bay transitions, perimeter attachments
  and perimeter vertices retain their separate topology identities.
- Authored land roads use exactly three classes. A **primary road** has a
  7-node visible surface inside a 16-node-wide claim-exclusion corridor; it
  carries the race spines, capital axis and other principal capital routes. A
  **secondary road** has a 5-node surface inside a 12-node corridor and serves
  villages and major POIs. A **trail** has a 3-node surface inside an 8-node
  corridor and serves small POIs. The complete corridor, not only the visible
  surface, is permanently ineligible for housing claims.
- Road centrelines may meander naturally and deterministically between their
  authored anchors. Their gate, bridge and POI-connection endpoints are fixed,
  and variation may not change the road class, disconnect the route or leave
  its exclusion corridor. Ordinary road nodes are generated once and then
  follow their zone's terrain mutability; their analytic exclusion corridors
  remain even when players alter or remove the visible road.
- A bridge or gate is hard-protected only when no adequate alternate route
  exists. Ordinary bridges, gates and road dressing remain mutable and
  claim-excluded like the road they serve.
- Strategic separators are visible terrain, never invisible walls: western
  and eastern ocean, the two immutable dragon channels, rivers, cliffs,
  ravines, fortress walls and mountain passes. The Holy Grounds must provide
  several distributed north/south lanes across its four-zone west/east chain;
  the islands are reached only through their authored boat approaches.

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
not disappear or change identity when a seed-varied boundary crosses them;
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

## 9. Fixed adjacency graph

The graph is undirected. Commas mean direct zone neighbors; no omitted pair may
become adjacent through seed variation. Its land-boundary dual has exactly 61
edges: the original 57 routed edges plus the four boundary-only outer-flank
edges `land_058` through `land_061`. The latter establish polygon adjacency but
do not imply a road, route profile/station/interface, corridor, route or
capital-road gate product, traversability guarantee or content operation. Their
ordinary shared-boundary relief gate `G` controls have no route semantics.

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
  chain shares a land edge.
- Both Stormvault Heights and Blackwind Rise neighbor Gravesalt Escarpment and
  The Broken Causeway.
- Both Ashenward March and Bannerbreak Mesa neighbor The Broken Causeway and
  The Shattered Line.
- Both Glassroot Wilds and Thunderroot Wilds neighbor The Shattered Line and
  The Skyglass Canopy.
- The Wyrmglass Crown and Stormscale Summit have **no land neighbors**. Their
  four boat routes are stored in a separate travel graph: a z = -125 southern
  and z = +125 northern approach to each island. Wyrmglass routes connect
  Gravesalt Escarpment to two distinct inward-shore landing beaches; Stormscale
  routes do the same from The Skyglass Canopy. These authored travel edges are
  open to both factions and never make two zones polygon neighbors.

The overlapping frontier-to-Holy edges distribute crossings across the whole
band and prevent one bridge or zone from becoming the sole faction route.

### 9.4 Authored land-route classes

The authored land-route graph remains exactly the original 57 edges: 30
primary, 24 secondary and 3 trail. It is intentionally not identical to the
61-edge land-boundary dual. `land_058` through `land_061` are excluded from the
route graph and have no route class or station sequence.

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
  plus the existing 10-node surround. Capital zone lookup reports the smooth
  directional civic profile from §3: level 20 at the home gate, 25 at the
  centre and lateral gates, and 30 at the front gate. Elandor rises northward;
  Kragmar rises southward. Hostile ambient spawning is disabled and level-60
  guards remain explicit.
- A fixed 96×96 civic core contains the king's hall, waypoint and principal
  service court. Four 32-node-wide no-jitter road gates leave north/east/south/
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

- WP40 keeps v7 for base relief, caves, ores and dungeons, then applies one
  authoritative authored land/zone/surface pass. A fully custom terrain
  generator is rejected.
- Engine climate competition is not authoritative inside the authored world.
  T2 geometry applies one full-seed, source-policy-bound coherent selector to
  the owning zone's weighted palette and compiles the resulting logical biome
  IDs. The selector policy and results are checksum-covered geometry. T6 maps
  those IDs to top, filler and decoration content but never selects or remaps
  an ID. Gameplay consumers use the logical zone-biome API, not
  `core.get_biome_data`.
- The land pass may carve ocean or fill an authored land connection, but must
  preserve caves, registered depth strata, ore veins and dungeons below the
  rewritten surface shell. Capital/start envelopes own their terrain after
  the general pass.
- Each zone definition stores its primary relief id plus any deterministic
  secondary-profile and named-landmark masks. The surface-height field retains
  v7-scale natural detail inside the applicable §7 elevation band; ordinary
  transition blends and explicit grading overrides are resolved before
  surface material, decorations, structures and road dressing are placed.
- Every ordinary zone stores authored surface-level control points at its core
  and road gates. Home-facing gates use the low end of the zone bracket,
  front-facing gates the high end and lateral gates the neighboring
  progression value; the interior field interpolates smoothly and clamps to
  the zone's published range. Neighboring ordinary gates share a value within
  two levels. The only exceptions are the visibly gated western/eastern
  endgame jumps in §14. A level-60 endpoint is flat 60 before the independent
  depth floor.
- `grug_zones` owns the registry and exposes at least:
  `get(id)`, `at(pos)`, `id_at(x, z)`, `biome_at(pos)`,
  `race_region_at(pos)`, `faction_at(pos)`, `territory_rule_at(pos)`,
  `pvp_rule_at(pos)`, `surface_level_at(pos)`, `neighbors(id)` and
  `anchor(zone_id, slot_id)`. Returned definitions are caller-owned copies
  or read-only by convention; consumers may not mutate the registry.
- The allocation-free feature surface is
  `nearest_boundary_at(x, z)`, `nearest_route_at(x, z)` and
  `nearest_hydrology_at(x, z)`. Each returns
  `(stable_id, nonnegative_integer_distance)` or `(nil, nil)` outside the
  compiled interesting extent or when that validated family contains zero
  records. It selects by exact Euclidean distance to, respectively, the closed
  compiled boundary geometry, closed route-corridor envelope or closed x/z
  hydrology-exclusion envelope. Zero means exactly on a boundary or on/inside
  an envelope; every positive distance rounds up so a distinct feature less
  than one node away cannot alias zero. Exact-distance ties use canonical
  numeric ID, then stable string ID. `housing_eligible_at(x, z)` is the
  separate boolean for the complete static radius-50 center mask and never
  checks dynamic claims.
- `coast_source_zone_id_at(x, z)` applies the closed 22-component roster and
  exact rational distance/tie rule in §7. It returns that dressing/inheritance
  zone ID inside the compiled interesting extent or `nil` outside it; the
  result never participates in `id_at`, footprint membership or adjacency.
- Every node-addressed public query accepts only finite Lua-number coordinates
  in `-(2^53 - 1)..(2^53 - 1)` before and after normalization. Each coordinate
  rounds to its nearest integer with exact half ties away from zero. Invalid,
  unsafe, absent or malformed coordinates are programmer errors; there is no
  string coercion, clamp or fallback. This matches Luanti's
  [`math.round` and `math.isfinite`](../../reference_projects/luanti/builtin/common/math.lua):35-48,
  documented
  [`vector.round`](../../reference_projects/luanti/doc/lua_api.md):4319-4325,
  and engine node conversion through
  [`read_v3s16`](../../reference_projects/luanti/src/script/common/c_converter.cpp):260-271
  and
  [`doubleToInt`](../../reference_projects/luanti/src/util/numeric.h):341-363.
- `faction_at(pos)` returns `"accord"`, `"throng"` or `nil` for contested/open
  ground; it never derives ownership from `race_region`. `territory_rule_at`
  returns the complete 3D construction/mining policy, including
  `contested_land`, `holy_grounds`, protected envelopes and immutable ocean
  channels. `pvp_rule_at(pos)` likewise applies the y = −701 contested-deep
  override rather than returning only the surface zone's rule.
- `grug_core.difficulty_at`, `mob_level_at`, `guard_level_at`,
  territory protection and open-sea checks become compatibility consumers of
  that API. `surface_level_at(pos)` returns `nil` for every exterior class:
  shelf, deep ocean and immutable dragon channel. On land and zone-owned
  planned water, the independent depth floor remains
  `max(surface_level_at(pos), depth_level_at(y))`.
- On exterior shelf, `mob_level_at(pos)` returns `nil` at normalized `y >= 0`
  and the standard capped/rounded depth level alone at normalized `y < 0`.
  Harmless or fixed shore wildlife does not use an ordinary surface level.
  Deep ocean and immutable dragon channels have no ordinary mob-level result;
  the hand-set deep-ocean Kraken Guard remains fixed level 100 outside this
  resolver, and channels do not inherit it.
- T3's positional `grug_core.guard_level_at(pos)` base returns `nil` in every
  exterior class, including editable shelf. It returns exactly 60 inside the
  exact capital 512×512 build envelope plus its 10-node hard-protection apron
  only at normalized `y >= -700`; at `y <= -701` and everywhere else on
  non-exterior columns it returns
  `min(70, max(20, surface_level_at(pos)))`. WP13 may later raise that generic
  non-nil base outside the shallow capital hard volume, capped at 70, but may
  never lower it. Exterior nil remains nil and permits no guard post. Ordinary
  and royal guards inside the shallow capital volume remain exactly 60. The
  king is a separate fixed level-65 entity and uses neither resolver. T3 does
  not invent post roles.
- Zone lookup uses a prebuilt spatial grid plus exact boundary resolution;
  hot paths may not scan all 38 definitions or a complete feature family. The
  same compiled index/evaluator proves nearest-feature results and the final
  housing-center predicate. Boundary variation is derived from the full world
  seed without converting an unsafe 64-bit seed through a Lua number.
- All fixed placements resolve through zone anchor ids. No dependent WP may
  retain a raw WP18 ring name or coordinate.
- Anchor slot ids are stable data: `start`, `capital`, `village_<n>`,
  `outpost_<n>`, `bandit_<n>`, `mine`, `mirefolk`, `clash_<n>`, `dragon`,
  `apex_mine` and `rare_<stable_rare_id>`. The §8 abbreviations determine
  which slots exist; absent slots return `nil` rather than being synthesized
  by a consumer.

## 14. WP40 acceptance gate

- Registry: exactly 38 unique zones, every land zone has one valid race
  region and one valid primary relief id, the undirected graph equals §9, and
  all six start→capital paths are peaceful. The graph has exactly 61 land-
  boundary edges: the original 57 records are byte-identical and `land_058`
  through `land_061` have their exact §7 endpoints, pairs and zero-jitter
  boundary-only contract. The separate route graph remains exactly 57 edges,
  split 30 primary, 24 secondary and 3 trail. The checksum-covered selector
  policy produces one coherent compiled logical biome ID inside the owning
  palette at every authored result. Every secondary relief or sharp terrain
  feature has an explicit bounded mask, stable landmark id and owning zone.
  Every §8.4 landmark exists exactly once, modifies no column outside its
  final owner, and satisfies its local route, anchor and grading constraints.
  Authored overhang remains diagnostic evidence rather than a second owner or
  automatic acceptance failure. Route/hydrology, exterior geometry, and
  housing/capital products independently prove their respective final-area
  obligations; owner clipping cannot satisfy those gates silently. Each of
  the six existing capital anchors is centered in and contained by its exact
  build-plus-10 hard-protection mask.
  T2 creates no WP13 capital guard, defense, king or structure anchor; WP13
  later validates those authored anchors against the same mask.
- Geography: the complete four-zone Holy Grounds land chain and all six paired
  frontier contacts exist on every tested seed. Each continent retains exactly
  three connected outer peninsulas separated by two open bays, one continuous
  capital/heartland belt and one continuous frontier; no bay reaches the belt,
  no peninsula is cut off and no forbidden outer-zone adjacency appears.
  Elandor's and Kragmar's coast/bay masks are not reflected copies. Neither
  dragon island gains a land edge, no zone vanishes, no fixed anchor changes
  zone, no route neck violates §7, and every island retains distinct
  96-node-wide approaches at z = -125 and z = +125. For either island, its
  Elandor- and Kragmar-oriented route lengths differ by at most 10%. From each
  of the four landing beaches, an island land route reaches both the dragon
  arena and apex mine; neither destination lies on the only route to the other.
- Outer perimeter: both base footprint chains pass through every §7 vertex in
  order, close only along their shared Holy-Grounds land edge and remain inside
  the mainland frame after variation. All four bay mouths retain their exact
  outer vertex, no dry start core approaches the final coast within 32 nodes,
  and the Elandor and Kragmar chains/noise are independently authored rather
  than reflected. The four `|z| = 1900..2500` side arcs stay inside `|x| =
  2580..2600` and retain their complete housing depth.
  Exhaustive equality fixtures prove exactly four nonempty, contiguous,
  non-overlapping half-open Base-Bay mouth apertures with their exact source
  references and 720/660/640/740-node analytic cross-sections. Every included
  equality station is planned water under the exact Base-Bay predicate and
  opens to shelf immediately outside; the first and last included stations,
  the excluded end, both outside-adjacent probes and their ties are
  deterministic. Every other final perimeter station is dry mainland: an
  ordinary span station returns its `perimeter_span.zone_id`; a declared
  clipped shared-edge attachment uses the shared-edge half-open/lower-numeric
  tie first; and an unattached vertex between two spans returns the lower
  numeric span-zone ID.
- Starts/homes: every fixed start anchor retains its complete centred 600×500
  dry core, and its 256×256 settlement blend plus primary-road exit lies wholly
  inside that core. Each start cap has exactly one land neighbor—its own home
  zone—and every home zone remains connected from both start flanks to its
  exact west, centre or east capital-belt base interval. No coast or shared-edge
  variation changes those contacts or the §9 land graph. Every start/home
  boundary passes through all of its §7 control vertices before variation,
  clips to exactly one connected land component with two shoreline endpoints
  and keeps at least 32 nodes from its dry start core after variation.
- Bays: all four base masks pass through their complete §7 sample tables,
  retain exactly one half-open planned-water mouth aperture through the outer
  perimeter, retain the unchanged round radius-80 head shoulder outside the
  capital belt and never narrow below 64 nodes after variation. Each bay has
  exactly two zero-jitter closure wings from that
  shoulder to its two existing head-flanking dry triple junctions. Both wings
  are present, their side equality and terminal junctions are dry, and no wing
  water enters the capital-belt interior. The base centre seam and explicit
  wing-side owners assign every planned-water point deterministically without
  adding a land neighbor. Base masks are clipped to strict footprint interior
  plus their own mouth aperture; Wings remain strict-interior-only. No Bay
  point classifies as shelf or deep ocean. The coordinate-free raw-mask notch
  pass then exhausts every integer `P` in each deduplicated finite Bay envelope
  exactly once. Seed 0 has counts `0/0/0/0`; the max-u64 R16 seed has
  Elandor-west/Elandor-east/Kragmar-west/Kragmar-east counts `1/1/1/0`.
  Those three fill columns are globally unique, have one dry cardinal
  connector and seven raw-water neighbours owned only by their Bay, and use
  the existing exact Base-Bay owner projection. The sorted per-Bay payload is
  the only downstream fill authority.
- The exhaustive finite mainland-footprint oracle assigns every integer x/z
  column to exactly one final planned-bay-water owner or one dry zone face, with
  zero final gap and zero final overlap. It proves exact
  `strict_rational_variable_width_capsule_union_v1` base-mask membership and
  same-projection owner selection; strict wing membership and equality-dry
  sides; exactly two otherwise-unowned head wedges closed per bay; no integer
  overlap between a bay's two wings outside its base mask; and the correct
  owner on both sides and centre tie.
  It exercises all eight exact `J` points and adjacent columns, proving each
  junction dry and the capital-belt interior water-free. A separate dry-face
  oracle requires at least one raw dry face outside final planned water. Raw
  multiplicity there is permitted only on declared shared edges and junctions,
  where the canonical half-open rule selects the owner; every undeclared
  cross-face seam or intersection rejects. Inside final planned water there is
  no raw-dry-face requirement because water precedence owns the column. The
  oracles also
  prove unchanged base capsules, samples and 160-node head shoulders, an
  unchanged independent outer perimeter and shelf, the byte-identical original
  57 edge records and the exact four added boundary-only records. Each added
  edge occurs in its two incident face cycles with opposing directions; its
  half-open boundary tie is unique, and only the existing perimeter-span
  records own coast and shelf. The oracle separately exhausts the four mouth
  apertures, ordinary dry-span equality, declared clipped attachments and
  unattached perimeter vertices under the exact precedence above. The whole-
  footprint oracle reports zero
  gaps, zero overlaps and zero invalid cross-face intersections, and
  reconstructs the exact 61-edge land dual. All 32 seeds rerun the same
  partition and topology oracle; no visual inspection substitutes for it.
- Authored-source validation proves one checksum-covered, symbolically closed
  authority graph before displacement; only the compiled per-seed stage
  materializes concrete face polygons. This staging distinction changes neither
  the final topology nor any acceptance case. Per-correction acceptance
  evidence lives in
  [wp40-source-authority.md](../research/wp40-source-authority.md) §6.
- Roads: every required route connects its authored endpoints, keeps its
  primary 7/16, secondary 5/12 or trail 3/8 surface/corridor class, and exposes
  the identical deterministic corridor to Claim-Stone validation. Seed
  variation never moves a fixed gate, bridge or POI connection. Ordinary road
  nodes remain mutable; only bridges and gates without an adequate alternate
  route receive hard protection. The exact §9.4 edge classification holds:
  every spine and capital-axis edge is primary, every listed cross-link and
  frontier/Holy edge is secondary, all six north/south Holy crossings remain
  complete, and every internal Holy edge retains a trail. The result is exactly
  30 primary, 24 secondary and 3 trail edges. The four boundary-only flank
  edges have no route class/station/interface, surface/corridor, route or
  capital-road gate product, travel promise or content operation and do not
  alter those counts. Their ordinary checksum-covered shared-boundary relief
  gate `G` controls remain mandatory and carry no route semantics.
- Relief: outside explicit coasts, named landmarks and grading overrides,
  generated natural ground remains inside its active relief profile's
  water-level-relative band. Ordinary transitions contain no accidental cliff
  or ravine; every abrupt feature resolves to a catalogued landmark mask. Road,
  civic, structure and coastal-housing grading wins deterministically over the
  general profile on all 32 seeds.
- Coordinates: Holy Grounds remains exactly x = −2500..+2500 and
  z = −250..+250; its internal junction vertices remain at x = −1500, 0 and
  +1500 on both outer edges. The capital belts retain base edges at |z| = 1100
  and 1900, all six 704×704 blend envelopes remain inside their assigned
  800-node cells, and both frontier separators pass through all six fixed
  §7 control vertices before bounded variation. Island centres and complete
  600×700 envelopes are exact, final land masks stay inside them, channel width
  never falls below 200 nodes, each warning band is exactly 48 nodes and the
  hard strip is never narrower than 104.
- Level/PvP: every ordinary progression and capital road-gate transition is
  continuous within 2 mob levels. The optional western/eastern high-front
  gates are deliberate endgame jumps from 31–40 into 51–60; each requires a
  visible fortified threshold, destination-level map label, contested-zone
  warning and unobstructed turnaround before hostile population. Every
  level-31–60 ordinary zone is contested; no level-1–30 zone is.
- Level-query edges: after coordinate normalization, capital center and exact
  hard-mask-edge samples return guard level 60 at y = -700, while the sample
  one node outside returns the generic base. At y = -701 all three return the
  generic base. Surface and guard level are nil on every exterior class; shelf
  mob level is nil at normalized y = 0 and depth-only at y = -1. Deep ocean and
  channel ordinary mob level remain nil, without changing the fixed level-100
  deep-ocean Kraken.
- Biomes/content: T2's compiled selector agrees with the full-seed slow oracle
  and no logical biome, mob family or gathering node appears outside its zone
  palette. T6 only maps the compiled IDs to content. Every
  `logical biome × zone` cell has at least one valid ambient spawn or is
  explicitly marked civic/no-hostiles.
- Economy: the §11 G1/G2, cultural-material, signature-wood, POI, rare and
  loot-source audits pass over at least 32 representative seeds. They prove
  native, enemy-contested, deep-cross-border, apex-camp and trade routes,
  including practical T4 access to the opposing faction-exclusive G2.
- Territory: `race_region` never grants construction rights; ordinary
  level-31–60 frontier/island terrain is editable by both factions, Holy
  Grounds is immutable through y = -700 and contested/editable at y = -701,
  dragon channels are immutable at every y, and all 24 apex gem sockets are
  reachable and diggable with their required tool. Every camp's small
  functional anchor remains protected, while ordinary walls, tents and
  battlefield dressing follow the zone's mutable terrain policy.
- Water: ordinary shelf is exactly 80 nodes outward from the final analytic
  planned-footprint perimeter and inherits the adjacent perimeter zone's
  policy. Deep ocean and dragon-channel 2D columns are
  immutable at every y. No deep-ocean column occurs inside either mainland;
  all authored bays, lakes, rivers and other planned water remain
  land-zone-classified, use `default:water_source`, derive ordinary dressing
  from the owning logical biome and stay claim-ineligible. No generated surface
  water uses a regional/faction liquid or `default:river_water_source`; named
  landmark dressing changes only bed, shore, depth and decorations. The four
  coastal housing zones each retain at least 600 continuous shoreline nodes and
  300 nodes of buildable inland depth after final coastline variation and all
  static exclusions. Every possible 101×101 reservation wholly inside each
  guaranteed core has no more than 12 nodes of generated natural-ground relief
  and intersects no forced cliff, ravine, river or lake, while every accepted
  reservation stays completely outside shelf water. The 32-seed packing audit
  reports actual capacity rather than treating this geometry minimum as a
  Claim-Stone quota.
- Migration: starts/respawns, 24 outposts, 12 bandit camps, rare routes,
  patrols, camps, surface mobs, gathering slots, waypoint/map/boss anchors,
  territory checks and mount boundaries all use zone ids. Only then may the
  retired `core/inner/outer/coast/war_coast` fields and full-water strait be
  deleted.
- Mapgen: fresh-world-only; Lua 5.1 syntax, deterministic registry tests,
  headless generation samples, sunlight/content-ignore checks and a
  representative chunk-time comparison against WP18 are mandatory before the
  user's fresh-world GUI test.

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
