# World Design

Decided spec (2026-08-05/06; continent redesign 2026-08-06; named-zone
redesign 2026-08-10). Implementation: WP2/WP18 are the currently shipped
map, WP6 supplies guards/outposts, WP40 replaces the surface geography with
the named-zone map, and WP13 then supplies structures and villages. The
binding macro-map and PvP rules are in `world_zones.md`.

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

## 1. Geography: two continents and named zones

**Kragmar remains north and Elandor remains south.** They are distinct faction
continents joined along the continuous four-zone Holy Grounds land band. The
Wyrmglass Crown and Stormscale Summit are separate offshore dragon islands
beyond its western and eastern ends and have no land-neighbor edges. Ocean
separates the remaining coast. The old mandatory open-water strait, three-loop
contact model and exact geometric mirroring are retired.

The target surface map is a stable graph of named zones. Position, neighbors,
level range, PvP status, biome palette and strategic landmarks are fixed;
bounded noise may vary only local borders and terrain detail. Both faction
sides have equivalent progression and content budgets but deliberately
different shapes and zone identities. Full contract: `world_zones.md` §1.

Each mainland has a memorable three-lobed progression silhouette. Three outer
cultural peninsulas hold the start/home spines and are separated by two long
bays; they join at a continuous west/east capital-and-heartland belt, then
broaden into a closed three-sector frontier at the Holy Grounds. Elandor and
Kragmar share that topology but use independent base polylines and noise, never
mirrored coast geometry. The bays stop before the capital belt and may not
create or remove zone neighbors.

The capital/heartland belt uses base z = -1900..-1100 in Elandor and
+1100..+1900 in Kragmar; the frontier then occupies the land through z = -250
or +250 respectively. Exact seven-cell x intervals and the separator control
vertices are binding in `world_zones.md` §7. They leave every fixed capital's
704×704 terrain blend inside its own zone and quickly rebalance the three
frontier sectors before their paired Holy-Grounds contacts.

### Difficulty layout: outer starts to high-level front

Surface progression moves from the outer side of each continent toward the
faction front:

| World layer | Level | Role |
|-------------|-------|------|
| Outer race starting zones | 1–10 | safe spawn settlements, one per race |
| Home zones | 11–20 | safe early questing; roads toward the capitals |
| Central heartland | 21–30 | safe capital approaches and middle progression |
| Frontier and Holy Grounds | 31–40 / 41–50 / 51–59 | contested war infrastructure and dangerous wildlife |
| Offshore dragon islands | 60 | contested apex mining and world-boss destinations |
| Capital city zones | no hostile ambient enemies | safe hubs; level-60 guards and important NPCs |

No level-1–30 zone is contested. Automatic PvP begins in every level-31–40
frontier zone and remains forced through all higher ordinary zones. The four
Holy Grounds zones provide the continuous mainland faction contact; both
level-60 dragon zones are offshore islands without land-neighbor edges.
Named zones and an authored within-zone gradient replace radial distance as
the surface input to `mob_level_at`. The depth floor remains unchanged and
can still overtake the local surface level underground.

Physical height is a separate authored field. Each land zone chooses one of
six water-level-relative macro-relief profiles—wetland/delta +2..+24, lowland
+8..+56, rolling hills +24..+96, plateau +56..+144, highland +96..+224 or
mountain +160..+360—and may add explicitly masked secondary profiles. V7
provides fine natural detail inside those envelopes. Sharp cliffs, ravines and
steps require named landmark masks; roads, civic envelopes, structures and the
guaranteed coastal-housing cores apply their own grading afterward.

Every capital sits centrally in its own city zone with four cardinal roads.
The road toward the outer side reaches a level-10–20 neighbor, lateral roads
along the capital axis reach medium-level heartland, and the road toward the
faction front reaches high-level territory. These safe progression spines and
both west/east capital axes are primary roads. Cross-links and all twelve
frontier/Holy-Grounds contacts are secondary roads; across the front they form
six distributed north/south crossings rendered as damaged military routes,
not one intact arterial road. Capital defense is the one fixed guard rule: its
guards and important NPCs are level 60.

### Current implementation before WP40

WP18/WP36 still ship two 3000×1600 rectangles, a 200-node strait, radial
`core/inner/outer/coast/war_coast` fields, capital spawn bubbles and exact
z-mirroring. Those values remain a description of the running code only; they
are not constraints on the new macro-map. WP40 removes or migrates every
consumer before WP13 authors permanent structures.

## 2. Destructibility

Rationale: free digging/building would break guard gating (tunneling),
elite mobs (pillar cheese) and territory borders. One territorial rule:

- **R1 — Own faction territory**: digging and building is allowed except in an
  active housing claim or a bounded hard-protected world-content volume.
  Hard-protected content is limited to complete capitals/gates/aprons,
  complete starting settlements (decided 2026-08-13: the full 128×128 build
  envelope plus a 10-node apron — the same envelope-plus-apron rule as a
  capital; spawn, waypoint, graveyard and service platforms all lie inside
  it), essential service/quest/waypoint/graveyard platforms,
  small functional NPC and renewable-resource anchors, and a bridge or gate
  for which no adequate alternate route exists. Ordinary roads, villages,
  outpost/camp shells, ruins, tents, fences and battlefield dressing are
  generated once, remain claim-excluded and may be changed under their zone's
  terrain rule. A start settlement needs no runtime pit or flood detection:
  by construction of `world_zones.md` §7's 600×500 dry start core (no planned
  water, forced cliff or ravine; gentle start grading only), an enclosed or
  flooded start cannot generate.
  - **Shape of a hard-protected world volume**: its authored x/z footprint is
    exact and protection runs upward without limit and downward through
    y = -700 inclusive. At y = -701 and below, the universal contested deep
    rule wins even beneath a capital. Each hard-protected footprint contains
    only the functional/core structure plus its explicitly authored apron; a
    structure type does not gain a blanket ten-node surround merely from its
    name.
  - **Indirect mutation fails closed** (decided 2026-08-13): hard-protected
    volumes are guarded against indirect mutation exactly like active claims
    (`housing.md` §6.4). Explosions, fire, liquid flow — including downhill
    flow originating outside the footprint — falling nodes, terrain-changing
    mobs, machines and scripted effects cannot alter protected state; inside
    hard-protected world content no player permission exists, so every such
    path is suppressed or the affected nodes are restored. The central
    mutation predicate and spatial indexes are shared with the claim system
    (`housing.md` §8). There is no rollback system: protected volumes need
    none, and destruction of the mutable layer deliberately persists
    (`housing.md` §7.2).
  - **World-content registry**: every hard-protected non-capital anchor
    registers a stable id and final x/z extent rather than hard-coding a zone.
    The registry separately stores mutable claim-exclusion/grading envelopes
    for ordinary roads and structures; those envelopes never become mutation
    protection. Terrain-derived placement heights are immutable mapgen output,
    but no first generated chunk owns the decision. The running pre-WP40
    placeholder generator may skip an anchor whose candidate terrain is
    flooded or too steep; this is legacy behavior, not the target contract.
    WP40/WP13 must select a deterministic reserved fallback candidate inside
    the owning envelope or fail that seed's generation audit. A mandatory
    graph/POI anchor may never disappear silently.
- **R2 — Peaceful enemy territory**: in level-1–30 land, an enemy faction may
  not dig or place any node, including torches and ladders. Items remain
  usable. At y = -701 and below the universal contested deep rule overrides
  land-side faction ownership.
- **R2b — Contested land and Holy Grounds**: every ordinary level-31–60
  frontier or dragon-island zone has no construction owner; both factions may
  dig and place subject to tools and explicit protected envelopes. The four
  Holy Grounds zones are immutable from the surface through y = -700; ordinary
  contested depth resumes at y = -701. Dragon channels remain immutable at
  every y. A cultural `race_region` never grants terrain rights
  (`world_zones.md` §§8.3/11).
- **R3 — Water columns**: classification is analytic in x/z and does not
  change when players fill or drain nodes. Every authored bay, lake, river,
  marsh channel, cenote or other water mask inside a
  `planned_mainland_footprint` remains part of its named zone and can never be
  deep ocean. The editable 80-node `coastal_shelf` starts only outside the
  final analytic footprint perimeter and inherits the adjacent perimeter
  zone's faction/PvP terrain rights; `deep_ocean` beyond that band is immutable
  at every y. Dragon-channel masks override the shelf and make their complete
  columns immutable from world bottom to top. Every exterior-ocean class
  remains non-flyable, while planned zone water inherits its zone's flight
  rule. Housing uses dry mainland claims and has no island exception.
- **R4 — Nothing regrows** (decided 2026-08-08): ores and resources do
  **not** respawn. A mined-out vein is gone, everywhere, for good. The
  world does not run dry because **depth supplies without bound** (R6,
  §4c, `combat_stats.md` §3) — the price of a material is paid in danger
  and travel, never in waiting for a timer. Renewable ore would have
  capped every material's value at its respawn interval and turned mining
  into a rotation instead of an expedition. **Sole exception: renewable
  nodes inside protected functional socket anchors**, where the bounded
  mechanism is protected (R1) and no player can privatize it. Ordinary camp
  walls, tents, fences and dressing remain mutable and claim-excluded. In the
  MVP that exception is **exactly one structure kind: the mining camps** of
  §4.
  - **10–15 renewable resource nodes per camp**, in the **tier of the
    camp's own region** (§2 R6 / `items_crafting.md` §3.0.1) — so a camp
    is where a player gets T3 stock without a −400 expedition, and the
    camp's garrison is the price.
    - The two level-60 apex camps at the dragon endpoints are the fixed
      exception to the single regional-tier content rule: each has exactly
      **12 nodes, two each of Citrine, Garnet, Jade, Diamond, Sapphire and
      Ruby**. Both factions may
      mine those nodes under R2b while each functional socket/anchor remains
      protected. Ordinary camp construction remains mutable. They remain
      mining camps, so they do not create a second renewable-structure kind.
  - **Respawn 2–4 hours per node**, not minutes. A camp is a destination
    worth a trip every few sessions, never a farm rotation; the interval
    is deliberately an order of magnitude above the 15–30 min the removed
    world-wide mechanic used, because a handful of nodes at a guarded
    place is a different thing from a vein under every hill.
  - Other POI kinds may join the exception later, one renewable node type
    per kind, once camps have proven the shape. Nothing else regrows
    today.
- **R5 — Active Claim Stones**: per-character Claim Stones provide the only
  permanent player-owned protection (§5). The owner and same-faction trusted
  characters may change ordinary nodes and use ordinary functional content
  inside the active cube; every applicable world, faction, immutable-water,
  hard-anchor and depth rule is evaluated first. A claim never grants terrain
  rights outside its current active volume, never privatizes its complete
  future reservation and never reaches the contested deep layer.
- **R6 — Natural depth and resource harvesting**: six visual strata retain the
  boundaries at **−100 / −300 / −500 / −700 / −1000 / bedrock**, but rock
  identity and engine `level`/`groupcaps.maxlevel` no longer gate progression.
  Every dig resolves three independent questions in order:
  1. territory/protection: may this player change this position;
  2. natural depth: does the wielded pick reach the target y;
  3. resource harvest: is that pick tier high enough to receive this natural
     ore or gem's drop.

  | Tier | Canonical metal/pick | Maximum natural depth | Visual stratum opened |
  |---|---|---:|---|
  | T1 | Bronze | y = −100 | Stone |
  | T2 | Iron | y = −300 | Slate |
  | T3 | Steel | y = −500 | Basalt |
  | T4 | Silversteel | y = −700 | Granite |
  | T5 | Embersteel | y = −1000 | Emberrock |
  | T6 | Abyssal Steel | map floor (−31000) | Abyssal Rock |

  Wood and Stone starter picks share the T1 maximum. The strata, top to
  bottom, remain `default:stone`, `grug_materials:slate`, `:basalt`,
  `:granite`, `:emberrock` and `:abyssal_rock`; they are cosmetic stone-like
  excavation material and all drop ordinary cobble. Every real pick may break
  one when its y is legal, including a player-placed decorative copy near the
  surface. Higher tiers gain speed through explicit tool `times`, never
  `leveldiff`. Cave walls inherit the local stratum, but an exposed cave wall
  does not bypass the target-y check.

  The exact political split follows those boundaries: **y = −700 is the last
  protected shallow node; y = −701 is the first universally contested deep
  node**. T5 occupies y = −701..−1000 and T6 y = −1001..−31000. On every
  non-ocean land column, both factions may dig and place at y = −701 and below,
  even beneath a capital, hard-protected anchor, road or active claim. Deep
  ocean and immutable dragon channels remain full-column exceptions.

  Natural resources use a separate minimum-pick property: T1 harvests Copper,
  Tin, Coal, Iron and Quartz; T2 harvests Gold and all G1 gems (Citrine,
  Garnet, Jade); T3 harvests Silver; T4 harvests Emberglass and all G2 gems
  (Diamond, Sapphire, Ruby); T5 harvests Abyssal Crystal. An under-tier real
  pick at an otherwise legal y destroys the resource with no drop, profession
  yield, XP or quest credit at ×4/×6/×8/×10 effective dig time for a shortfall
  of one/two/three/four-or-more tiers, consumes one ordinary pick use and gives
  explicit shatter feedback. Bare hands and non-picks cannot do this. Crafted
  storage/building blocks are never natural resources: any real pick recovers
  them where territory allows, and they always drop themselves.

Implementation: one central `core.is_protected` override in `grug_core`
(faction + position check).

## 2b. Ocean zones & deep-sea danger

Water type is an authored x/z classification, not a test of the node currently
occupying a position (`world_zones.md` §7):

- **Planned zone water:** bays, lakes, rivers, marsh channels, cenotes and
  other authored water inside a continent's `planned_mainland_footprint` remain
  part of their named zone. All use the same `default:water_source` as every
  other generated surface water body; the owning logical biome or an explicit
  landmark changes only bed, shore, depth and decorations. They inherit the
  zone's terrain, PvP and flight rules and can never become deep ocean. Their
  authored masks remain claim-ineligible even if players later fill or drain
  them.
- **Coastal shelf:** the first 80 nodes outside the final analytic perimeter of
  a planned mainland or island footprint. This is editable under the adjacent
  perimeter zone's terrain policy and reserved for later coral, kelp, fish,
  coastal materials and shore wildlife. It is never housing-claim ground.
- **Deep ocean:** every ordinary ocean column beyond the shelf, immutable at
  every y. This remains the deliberately deadly open sea patrolled by the
  level-100 Kraken Guard (no drops or XP). Playable-boat ownership,
  acquisition, speed, damage, destruction and return/respawn behavior are not
  defined by this world-geometry rule (`TODO-design-boats.md`).
- **Dragon channels:** separate full-column immutable masks between the
  mainland and the two offshore islands. They are required boat routes and do
  not inherit the deep-ocean Kraken/boat-destruction rule. Their warning and
  hard-flight bands come from the same 2D distance field. Each channel carries
  two distinct 96-node-wide approaches centred at z = -125 and z = +125,
  joining its Holy Grounds endpoint to two inward-shore island beaches. Both
  are usable by both factions; their north/south orientation only equalizes
  travel from Kragmar and Elandor.
The compatibility `open_sea_at` predicate must become true only for
`deep_ocean`; it is false for planned zone water, shelf and dragon channel. The
shipped WP18 rectangle/strait lookup remains running-code history only and is
replaced by WP40.

## 2c. PvP geography and player tag

Peaceful and contested status belongs to the named surface zone. No level
1–30 surface zone is contested; every ordinary level-31–60 frontier, Holy
Grounds and dragon-island zone is contested. Independently of the surface
zone, every non-ocean land position at **y = −701 and below** is contested.
Entering a contested zone automatically applies the player's PvP tag; an
untagged player in a peaceful zone cannot receive unprovoked enemy-player
damage.

An untagged peaceful-zone player who makes a server-valid hostile contact is
tagged before resolution. Against an equally safe player that first effect is
blocked; against an already tagged player it may land. Effective PvP
HP/absorb damage and effective support of a tagged ally refresh the timer;
misses, dodge, immunity and zero effect do not. Outside contested zones the
tag lasts **60 seconds** after the last qualifying contact, death clears it,
disconnect does not, and leaving contested ground starts a full tail. Every
melee, cast, area and projectile path uses the central eligibility seam. Full
transaction, boundary, lifecycle, visitor and HUD rules:
`world_zones.md` §§4/15.

## 3. Capitals

There are **three race capitals per continent**, one per race and six total.
Each sits in its own central named city zone and is protected
(indestructible) per the POI rule of §2 — the final build envelope plus its
authored 10-node apron, upward without limit and downward through y = −700.
The ordinary contested deep rule resumes at y = −701 even below a capital.

- A capital is a safe civic hub with **no hostile ambient enemies**.
- Its guards and important faction NPCs are level 60; the killable race king
  is the explicit level-65 elite exception and is protected by four level-60
  elite royal guards (`world_zones.md` §12).
- Its center has main roads in all four cardinal directions: toward level
  10–20 home territory, laterally into medium-level heartland and toward the
  high-level contested front (`world_zones.md` §3).
- New characters and ordinary fallback respawns use their race's outer
  level-1–10 starting settlement, not the capital.
- Every race has its own king in its own capital: **six kings total**. Housing
  is instead unlocked at level 20 through the separate passive, invulnerable
  Housing Steward and the open-world Claim Stone design of §5; no king grants
  land or housing.
- Capitals hold class trainers, class POIs, traders, quest givers, job
  trainers and a major waypoint. No capital is a superior faction-wide
  administrative seat in the MVP; shared faction services use the same
  service definition in all three faction capitals.
- Race flair comes from architecture and NPCs (per-race wood/build sets,
  `biomes_mobs.md` §5; elven capital = treehouses). Mechanical race perks hang
  on individual vendors (§7).

### Current WP18/WP36 capital anchors

The running map still places the six placeholder platforms at x = 0/±550,
z = ±900 and uses them as spawn points. Its following carve guarantee is an
implementation record until WP40/WP13 replace the platforms; it does not
constrain the new city-zone geometry.

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

The shipped platform watch remains level 60 and continues to use its guard
banner until the real cities land. The target king/royal-guard binding, reset,
death and group-respawn rules are decided in `world_zones.md` §12 and replace
the generic future-bodyguard placeholder below.

## 4. Outposts & patrols

Military outposts, road forts and war-front anchors are reserved by named
zones. They enforce authored routes and make the zone's strategic role visible:

- Roles: guard spawner/anchor, quest hub, graveyard/respawn point for the
  own faction, protector of resource-rich mining sites (e.g. a dwarven
  mining camp — resource site + conflict point in one). Such a site is
  **world content, not a purchasable claim**: it is guarded, never owned,
  and anyone permitted by the zone rule who fights past the garrison may mine
  it. Under R4 a **mining camp is the only place in
  the world where anything regrows at all**, precisely because its
  small functional anchor and renewable sockets are indestructible: 10–15
  renewable nodes in the region's own material tier on a 2–4 h respawn
  (numbers and rationale in §2 R4). Its ordinary walls, tents and dressing
  remain mutable under the local terrain policy.
  That is what makes such a camp a travel destination and a conflict
  point rather than scenery — and it is why a camp needs a garrison worth
  fighting. **Mining camps do not exist as a structure yet** — this
  section has so far named them only as a *role* an outpost can carry;
  authoring them (schematic, garrison, protection footprint) belongs to
  the world-structures package.
- Guard level normally follows the local named zone and the post's role;
  capital guards are the fixed exception at level 60. A guard at level ≥ 60
  is automatically an elite (scale/tint/telegraph, `combat_stats.md` §3).
- Each named zone reserves its required outposts, road patrol legs and special
  camps explicitly. The old fixed minimum of 24 ring outposts is not a target
  budget; the complete zone catalog must replace it with equivalent faction
  coverage before any old anchor is removed.
- **Ordinary guards attack enemy players and monsters, never arbitrary NPCs**
  (`attack_npcs = false`). Dedicated war-front soldiers are the scoped
  exception: their authored encounter anchors may target the opposing
  war-front population, hostile players and dangerous local creatures.
- War-front squads use fixed population caps, place-bound respawn slots and
  fixed clash points. Their fights are ambient life only and do not capture a
  zone or move the faction boundary in the MVP (`world_zones.md` §5).
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
- **Character-bound NPCs** (later escort NPCs) are bound to a character instead
  of a place: they follow their
  character wherever it goes while it lives. When the character dies
  they become **unbound** (roam free where they stand); when the
  character respawns, the old bodyguards **despawn** and it comes back
  with a fresh set. (Spec now; implementation lands with the King/raid
  WP.)
- **Royal guards are the decided exception:** the living king is authoritative,
  all four guards always path toward it, its evade/teleport relocates the group,
  and its death makes survivors retreat/despawn. The entire five-NPC encounter
  returns together after the persistent 15-minute respawn; royal guard slots
  never refill independently (`world_zones.md` §12).
- **Respawn slots**: every anchor has a configured **maximum population**
  and refills toward it one NPC at a time. Each refill takes a
  **configurable interval** (either an exact duration or a min–max
  range rolled per refill). Slots are independent: if 2 of 4 bodyguards
  die, exactly 2 refills queue up. The royal encounter is the explicit
  group-reset/group-respawn exception above. Intervals in force today:
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

Every apex boss shares the same tech — oversized entity
(`visual_size` 4–6×), fixed lair POI with hoard chest, **stationary
arena fight** (holds its ledge, hops between ~3 fixed positions; never
kites into terrain, sidesteps pathfinding exploits), telegraphed attacks
(the elite wind-up mechanic scaled up), respawn timer — but each has a
**distinct skill set** so it threatens in its own way.

- The old stage-one rule **one dragon per continent is retired**. The world
  gets two offshore overworld dragons, one beyond each Holy Grounds endpoint,
  implemented through one encounter chassis with two regional variants.
- Every overworld dragon occupies a separate **offshore island** beyond one
  ocean endpoint of the Holy Grounds. An immutable full-column channel removes
  land, bridge and tunnel access; both factions receive equivalent authored
  boat routes through separate 96-node northern and southern approaches. Each
  island is a contested level-60 mountain zone with strong level-60 creatures,
  war remains and a culminating summit or hoard.
- An overworld dragon is a PvP world boss from its first stage, not a private
  home-continent boss. Its skill sketch remains ranged breath line
  (`dogshoot` + telegraph) plus ground-slam AoE.
- Each dragon owns a separate rolling 24-hour, wall-clock boss-loot lockout per
  character. Receiving one dragon's personal boss reward starts only that
  dragon's timer; players may still join repeat kills without another reward,
  and the other dragon remains independently eligible.
- Dragon personal loot uses the same participation bounds as a royal
  encounter: a living ledger participant must be within **60 nodes** of the
  dragon at death, while a ledger participant slain during the active attempt
  by the encounter, another encounter NPC or an enemy player retains
  eligibility for **60 seconds**. Proximity alone never adds a player, and a
  full encounter reset clears both participation and death-grace records.
- A slain overworld dragon has a fixed **30-minute base respawn** measured in
  persistent wall-clock time; server downtime counts. At the earliest one
  minute before it can return, an active lair starts an unmistakable local
  60-second visual and audible warning, then spawns the dragon. If the lair is
  unloaded when that warning should begin, its next activation starts the full
  warning and the spawn is delayed until the warning completes. The returning
  dragon receives no temporary invulnerability.
- A dragon island is contested at all times, whether its dragon is alive, dead
  or in the respawn warning. The warning merely concentrates both factions at
  a predictable objective; it never enables, disables or changes the island's
  PvP rule.
- Each endpoint also contains the all-six-gem apex mining camp defined by §2
  R4. Both the boss and the mine are contested endgame objectives.
- **Phase 2+ — additional regional apex creatures**, same code, own
  kits: e.g. jungle giant serpent (poison pools, submerges), blight bone
  colossus (knockback slam, summons adds). The dragon stays the biggest.
- **Phase 3 — the Nether dragon lord** as the demonic story capstone
  (story.md; only if the population supports larger raids).

## 4c. Deep T5/T6 is contested endgame territory

The political deep layer begins at **y = −701**, independently of the surface
zone. T5 occupies y = −701..−1000; T6 begins at y = −1001 and continues to the
map floor. Both factions may excavate, place and fight there under §2 R6. Race
region still projects down from the surface column for regional resource and
content selection, but it grants no territorial ownership.

T6 is a destination as well as the last material band. Regular mobs remain
capped at level 60; danger beyond the cap comes from the environment and the
player-centric depth-arrival pulse in `biomes_mobs.md` §4.1, not level-80
statistics. Flat connected lava lakes with an air dome and a usable shore are
the authored environment example. Cheap `ore_type = "blob"` lava pockets may
add ambience, but do not replace the lake pass. Pure chunk-local voxel work
belongs in the mapgen environment and uses a y-range fast path above the band.

Deep mining pays in raw materials rather than a separate gear-drop layer. The
first resource-calibration pass uses these bounded density multipliers for
ordinary continental ores, G1/G2 gems and Abyssal Crystal:

| Depth | Resource density |
|---|---:|
| y = −1001..−1499 | normal T6 density |
| y = −1500..−1999 | +25% |
| y ≤ −2000 | +50%, capped |

The bonus is a deterministic placement budget, never runtime ore respawn. It
does not multiply trophies, king or dragon loot, protected camp sockets,
claims or quest rewards. The band has no dedicated apex boss in the MVP and
its creatures retain their ordinary family drops.

## 5. Housing: open-world Claim Stones

The complete authoritative Claim Stone contract is `housing.md`; this section
summarizes its world-facing integration and does not replace it. Housing is
per-character protected land inside the authored mainland. Private housing
islands, royal land grants, purchased depth rights and any guild land or
administration system do not exist in the target design.

### 5.1 Eligibility, tiers and reservation

- Claim Stones may be placed only in ten peaceful housing zones: Copperfell
  Foothills, Goldmead Vale, Starbough Vale, Mournfen, Redtusk Savanna,
  Raincall Basin, Whitebridge Shire, Lorindor, Speargrass Reach and Whispering
  Reedlands. The six level-1–10 starting zones are claim-free.
- A passive, invulnerable Housing Steward in every capital unlocks the first
  free owner-bound stone through a level-20 introduction quest. The configured
  faction pool must have a live slot; a failed issuance creates and consumes
  nothing. The MVP default is one stone per character. The integer setting
  `grug_housing_max_claims_per_character` supports 1..3 without migration and
  defaults to 1.
- The stone is the centre of an active protection cube:

  | Tier | Required level | Radius | Active volume |
  |---|---:|---:|---:|
  | I | 20 | 20 | 41³ |
  | II | 35 | 30 | 61³ |
  | III | 50 | 40 | 81³ |
  | IV | 60 | 50 | 101³ |

- A tier-I placement immediately reserves the complete future 101×101 x/z
  footprint. Different owners' projected reservations may never overlap at
  any y and require ten completely unclaimed nodes between edges. The exact
  pair test expands only the candidate radius-50 AABB by ten nodes and rejects
  an intersection with another owner's stored radius-50 AABB; two radius-50
  centres therefore differ by at least 111 nodes on a critical axis. Same-owner
  reservations may overlap, but each stone consumes its own faction slot.
- The complete reservation must pass the authored housing mask and must not
  intersect a zone/peace boundary, planned water, coastal shelf, capital,
  starting core, road/corridor, waypoint, graveyard, village/outpost/camp/POI
  envelope, dynamic-POI candidate envelope or other static exclusion. Roads
  and ordinary POI shells remain mutable even though their analytic envelopes
  exclude claims.
- Placement is forbidden below y = −50, derived from the T1 natural-depth
  limit minus the maximum radius. No claim can therefore reach deep T5/T6.
  Claims are dry-land housing only: no protected underwater claims or private
  harbors.
- Copperfell Foothills, Mournfen, Starbough Vale and Raincall Basin each retain
  a continuous gentle coastal housing core with at least 600 shoreline nodes,
  300 nodes of buildable inland depth and at most 12 nodes of natural-ground
  relief in every wholly contained 101×101 reservation. Elsewhere there is no
  general runtime slope test.

### 5.2 Ownership, ACL and active-world behavior

- Every stable claim id has one owner. Up to ten same-faction characters may
  be trusted. Trust permits digging, placement and ordinary door, workstation
  and unsealed-inventory use; it grants no ownership. Only the owner may edit
  trust, upgrade, recover or relocate the stone. Claim Stone items are
  owner-bound and non-tradeable.
- At overlapping same-owner claims, a non-owner must be trusted by every
  covering claim; denial wins. The registry, not per-node placer metadata,
  owns ordinary content in the active volume. There are no separately
  player-locked chests in the MVP.
- The outer world rule always wins before the ACL. Deep ocean, dragon
  channels, hard-protected world content, the reserved Home-Stone arrival
  column and y = −701 contested depth cannot be overridden by a claim.
- The two nodes directly above the Claim Stone are a permanent clear arrival
  column. No player may place a node, torch or liquid there.
- Natural spawn candidates of every class are rejected inside the active cube,
  but claims do not despawn, repel, pacify or block creatures that enter from
  outside. Combat rules remain unchanged inside a home.
- Claim protection covers indirect mutation as well as direct digging:
  explosions, fire, liquids, falling nodes, terrain-changing mobs, machines
  and scripted effects require attributable owner/trusted/admin permission and
  fail closed when attribution is unavailable. Ordinary crop/tree growth and
  normal workstation operation are the bounded benign exceptions.
- Crops and player-grown plants may extend beyond a boundary. Nodes outside the
  active cube are ordinary unprotected world content. Every ordinary shipped
  growable must stay within ten horizontal nodes of its source; larger future
  growables need a separate rule.
- Owners may place every ordinary block they legitimately possess; there is no
  race, faction, biome or material-tier palette. Player workstations, cooking
  stations, doors and unsealed inventories use the claim ACL but grant no
  profession, recipe or material permission.
- Claim farming may grow `[food]` crops and `[spice Tn]` plants only. Healing
  herbs, ores, race/cultural materials and found-only mushrooms, wild cocoa and
  rock salt remain world resources. Housing adds no livestock or stable system.
- Claim boundaries are transient and client-scoped, never permanent nodes,
  walls or entities. Crossing a boundary or receiving a denied action briefly
  shows that claim's sparse cube-edge outline to the affected player; a denial
  also identifies the owner. Events are throttled per player and claim. Owners
  and trusted characters may request a temporary full outline, while placement
  preview distinguishes the active cube from the radius-50 reservation.

### 5.3 Costs, recovery and persistence

- Each stone owns stable id, owner and tier. Upgrades are sequential,
  transactional and performed through the placed stone; failure consumes
  nothing. Recovery, relocation, inactivity and reissue preserve paid tier.

  | Upgrade | Level | Material | Ledger-money target |
  |---|---:|---:|---:|
  | I → II | 35 | 4 Silversteel Bars | 30 min reliable T4 net solo income |
  | II → III | 50 | 8 Embersteel Bars | 90 min reliable T5 net solo income |
  | III → IV | 60 | 12 Abyssal Steel Bars | 3 h reliable T6 net solo income |

  Measured income excludes rare jackpots and player trade and is net of routine
  repairs/consumables. Copper outputs use the fixed coarsest-denomination,
  within-5%, midpoint-up rounding rule.
- A second/third stone is available only at level 60, when every owned stone is
  tier IV and the configured personal limit and faction pool both permit it.
  They cost 12/24 Abyssal Steel Bars plus 5 h/10 h of reliable T6 net solo
  income and create a new stable tier-I id. Existing ids are grandfathered if
  the setting is later lowered.
- A placement is bound for four real wall-clock hours; offline and server-down
  time count. Only an administrator may remove it early. Afterward the owner
  may recover it through the controlled menu. Recovery deactivates protection,
  reservation, ACL and Home destination, leaves all construction/inventories
  in place and returns the live item or persistent recovery escrow. Each new
  placement starts a new binding; an upgrade does not.
- The canonical registry distinguishes live `placed`, `inventory`,
  `recovery_escrow` and transient transaction locations from slot-free
  `dormant`. Every live location consumes one faction slot. Registry generation
  numbers and one canonical live location invalidate stale ItemStacks without
  cloning or reviving protection; spatial indexes are rebuilt from mod storage.
- Each faction has an administrator-configurable live-Stone limit. Its safe
  default is selected below the measured capacity of the real exclusion masks
  over 32 representative seeds, never inferred from gross zone area or an
  arbitrary population quota.
- Issuance is first come, first served, with no wait list or reservation. The
  integer `grug_housing_inactivity_days` setting ranges 0..3650 and defaults to
  0 (disabled). With decay enabled and a full legal pool, an issuance request
  atomically makes the oldest eligible live id dormant and transfers exactly
  that released slot. The requester receives one of their already owned dormant
  ids when applicable; otherwise a new id is created within the personal limit.
  Owner activity is the latest successful login; it refreshes every owned live
  id before issuance is checked. Equal inactivity timestamps resolve by stable
  claim id.
  When assigned exceeds a lowered limit, new issuance pauses and ordinary
  decay/reissue removes nobody.
- Every Housing Steward shows an interaction-time snapshot for the visitor's
  faction: assigned, free and configured-limit counts. Assigned includes
  placed, inventory and recovery-escrow stones; free is never negative. At a
  full pool with decay enabled the UI shows only the aggregate number currently
  eligible for on-demand reclamation, never owner names or positions; during an
  administrative overhang it reports that issuance is paused. A snapshot
  creates no reservation or queue position.
- Dormancy removes the live stone/item/escrow, protection, reservation, ACL and
  Home destination but retains stable id, owner, paid tier and audit/notice
  state. Buildings and inventories remain unarchived in the world and become
  ordinary unclaimed content. Voluntary dormancy uses the same result and is
  owner-available after the four-hour binding; administrators may force it.
  Reissue is free, preserves tier and competes for a faction slot normally.
- With decay enabled, the stone menu states the exact eligibility time and the
  first issuance warns that buildings and inventories are never archived. A
  successful reclamation persists a one-shot notice for the previous owner
  with zone/coordinates when placed, reclamation time, inactivity duration and
  retained tier; it remains available through the Steward until acknowledged.
- Administrators receive inspect, index-rebuild, forced-recovery,
  forced-dormancy and stone-recovery tools. Every forced operation is logged
  and never deletes buildings or inventory contents.
- Runtime protection uses a persistent registry mirrored into separate spatial
  indexes for active 3D volumes, maximum-radius x/z reservation projections and
  claim-exclusion envelopes. Dig/place and natural-spawn checks are point
  queries, never node scans or protection globalsteps.

## 6. Travel: waypoints & Home Stone

**Waypoint network** (Diablo/PoE model, decided 2026-08-06):

- Waypoints: every race starting settlement, every capital and the authored
  travel hubs reserved by named zones. Exact density is part of the zone
  catalog; every main progression route must connect to the network.
- **Unlocked by visiting, per character** (player meta); the fog-of-war
  world map (section on WP12) shows discovered waypoints.
- Teleporting works **only while standing at a waypoint**
  (waypoint → waypoint), instant and free — travel time is the cost;
  mounts stay relevant.
- **No waypoints in enemy territory** (not unlockable or usable there) and
  none in ordinary ocean or on the dragon islands.
- Phase 2 extension: **Nether crossings** link authored, level-equivalent
  named-zone portal pairs into enemy territory
  (`TODO-design-nether.md` until specced).

**Home Stone** is bound to housing rather than a capital:

- It teleports only to the owner's currently bound, active Claim Stone and has
  no capital fallback. Player state stores a stable `home_claim_id`; the first
  placed claim binds automatically, and with later multiple claims the owner
  rebinds by physically interacting with the chosen stone. Recovery/dormancy
  disables the destination; re-placing the same stable id makes it valid again.
- The cast is a **10-second stationary channel** and cannot begin while
  `grug_core.in_combat(player)` is true. Movement more than 0.1 nodes, death or
  logout interrupts; camera rotation and smaller engine correction do not.
- PvP interruption uses the central events from `world_zones.md` §15. A
  server-valid hostile attempt or effective support performed by the channeler
  interrupts even when a safe→safe effect is blocked. Accepted hostile damage
  that lowers HP or consumes absorb, and effective support received by the
  channeler, also interrupt. Misses, dodge, immunity, eligibility refusal,
  zero-effect support and the PvP tag alone do not.
- The destination is loaded/emerged and its claim, stone and clear arrival
  column are validated before the cast and again at completion. Arrival is the
  standing node above the stone; temporary entity overlap cannot grief it.
- The **60-minute cooldown** starts only after a successful teleport and is a
  persisted wall-clock timestamp. Failure or interruption consumes no cooldown.
- `/unstuck` (suicide command) remains the last resort for hard stuck
  states.

## 7. Races

Races are a light-weight character layer with strong geographic identity:
each race has one outer level-1–10 starting zone and settlement, one central
capital and additional race-flavored zones/settlements within faction
territory.

| Faction | Race | Region flavor |
|---------|------|---------------|
| Accord | Humans | plains/meadows |
| Accord | Dwarves | mountains/hills |
| Accord | Elves | forests |
| Throng | Orcs | savanna/badlands |
| Throng | Trolls | jungle/swamp |
| Throng | Undead | dark forest/blight |

(Own names/flavor later — no 1:1 Blizzard copies.)

- The authored zone graph fixes every race's approximate compass position,
  starting zone, capital and cultural routes. Seed variation may jitter local
  borders but never move or exchange them.
- The two factions receive equivalent access to all level/material bands, but
  race geography is not required to be a geometric mirror. A character begins
  in its race's outer starting settlement and reaches its central capital
  through the safe early-level roads.
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
    (`economy.md` §2): the target payout remains ceiling-rounded 5% of the
    applicable purchase or authoritative reference price.
  - Both are the *bonus* on top of the visible passive, in line with the
    rule above that a perk must be FELT from level 1: the passive does
    the felt work, the vendor is the flavor that pays off later.
- Universal base recipes and professions are never race-exclusive. Cultural
  Finishing is the identity seam: the profession owning an item family may
  apply only the player crafter's own character culture, while an allied
  cultural-master service offers the same supplied-material operation. WP10
  owns those workstation/service paths; WP5 owns the per-stack finish/effect
  channel. Finished equipment remains tradeable and wearable by every race.
- **No class restrictions per race in the MVP** (only 3 classes — locks
  would frustrate more than they flavor); revisit in Phase 2 with 7
  classes.
- Small race villages in the named race zones (traders, flavor, later
  race-specific job trainers) — content for WP13 after WP40 fixes their slots.

## 8. Nature biomes (shared wilderness)

The full biome/mob inventory lives in `biomes_mobs.md`; WP40 assigns that
inventory to named-zone palettes without changing its cross-faction material
symmetry.

- Nature biomes are **unsettled** (no faction NPCs except passing
  patrols), exist on **both continents with identical base drops** (base
  recipes work everywhere), and are the designated **quest wilderness**
  ("go into the adjacent jungle and kill a snake").
- Placement follows each named zone's fixed allowed-biome list. Every zone may
  contain several biomes, but no biome outside its list may appear there.
  Difficulty and biome still reinforce each other: high mountains and the
  dragon endpoints are high-level because their named zones say so, not
  because a global ring happened to reach them.
- **Nature mobs are aggressive on sight against players AND NPCs**
  (patrols visibly fight wolves — free world "life").
- **Mob density is deliberately high**: target ~1 visible mob per 15–20 m of
  travel in wilderness zones. WP40 must re-derive every `biome × named zone`
  spawn cell before replacing the old ring vocabulary.

## 9. Settlements & world life

POI budgets are authored **per named zone**. Every faction receives an
equivalent total and equivalent progression access, but the positions and
local compositions need not mirror.

- 1 safe outer starting settlement per race (six total).
- 1 central race capital and king per race (six total).
- Authored village, flavor-camp, mining-camp, outpost, patrol and quest slots
  appropriate to each zone's identity and level.
- Dedicated fort, camp and clash-point slots in contested war-front zones.
- Dragon lairs only at the contested level-60 ocean endpoints (§4b).

WP18/WP6 currently provide 24 ring-derived outpost anchors and 12 bandit
camps. These stay live until WP40 proves and installs the replacement zone
budget; WP13 then turns the reserved slots into real structures.

Life measures (cheap on a voxel budget): named NPCs with one-liner barks,
visible patrols, light/smoke details and a quest board per village. Ordinary
guards fight monsters and eligible enemy players; only dedicated war-front
units fight opposing faction NPCs. NPC and guard levels match the named zone
except for the fixed level-60 capital defense.

**Drop rule (anti-litter, decided 2026-08-06)**: mobs and NPCs drop
loot ONLY when a player was involved — details in combat_stats.md §3
(player-tag flag). Faction NPCs drop only to ENEMY players (PvP kills);
a wolf slain by a guard drops nothing.
