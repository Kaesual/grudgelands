# World Design

Decided spec (2026-08-05/06; continent redesign 2026-08-06; named-zone
redesign 2026-08-10; R6 camp quantity 2026-08-29), with later approved
playtest revisions folded into the relevant sections. The current surface is
the WP40 named-zone map. Structure delivery and outstanding content are tracked
in BACKLOG WP13; the binding macro-map is in `world_zones.md`, the PvP rules
in [pvp.md](pvp.md).
Planned travel, housing and depth mechanics below remain approved scope, not a
claim that their work packages are complete.

## 0. Canonical names

Decided 2026-08-06 (rename from the placeholder faction names;
Battlegrounds macro-region name 2026-08-27). These names are canonical for
docs, code and content — do not reintroduce the old ones.

| Thing | Display name | Internal id |
|-------|--------------|-------------|
| Southern faction | **The Accord** | `accord` |
| Northern faction | **The Throng** | `throng` |
| Southern continent (Accord homeland) | **Elandor** | `elandor` * |
| Northern continent (Throng homeland) | **Kragmar** | `kragmar` * |
| Shared macro region | **Battlegrounds** | `holy_grounds` ** |

\* These are canonical continent identities. Territory and zone membership
come from the authored zone authority, never merely the sign of z.

\** `holy_grounds` is a legacy internal token. The Battlegrounds have no
special geometry or rights (Round 22, `world_zones.md` §7.1); it survives
only as the macro-region key of the four Battlegrounds zones, whose territory
token is `contested_land`. It is not a player-facing name and implies no
terrain protection.

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
continents joined along the continuous four-zone Battlegrounds land band. The
Wyrmglass Crown and Stormscale Summit are separate offshore dragon islands
beyond its western and eastern ends and have no land-neighbor edges. Ocean
separates the remaining coast. The old mandatory open-water strait, three-loop
contact model and exact geometric mirroring are retired.

The target surface map is a stable set of named zones. Hub position, level
range, PvP status, biome palette and strategic landmarks are fixed by the
layout; the world seed varies terrain, content and the natural course of coast
and zone borders, never the hubs, anchors or macro silhouette. Zones border
each other naturally, and neighbors follow from those borders. Both faction
sides have equivalent progression and content budgets but deliberately
different shapes and zone identities. Full contract: `world_zones.md` §1.

Each mainland has a memorable three-lobed progression silhouette. Three outer
cultural peninsulas hold the start/home spines and are separated by two long
bays; they join at a continuous capital-and-heartland belt, then broaden into
a three-sector frontier at the Battlegrounds. Elandor and Kragmar share that
high-level composition but use separately authored coarse land shapes, never
mirrored coast geometry. A multi-scale warp gives the coast coves and
headlands and gives zone borders a natural course; nothing straight or
rectangular remains, including the Battlegrounds. The bays stay outside the
capital envelopes.

The fixed hubs, coarse land shapes and warped power ownership in
`world_zones.md` §7 are the sole horizontal authority. Each 512×512 capital
envelope is guaranteed to its capital zone; its wider terrain blend may cross
a zone border and is not an ownership constraint. Gameplay neighbors are the
geometric land neighbors; roads are an overlay and never define them
(`world_zones.md` §9).

### Difficulty layout: outer starts to high-level front

Surface progression moves from the outer side of each continent toward the
faction front:

| World layer | Level | Role |
|-------------|-------|------|
| Outer race starting zones | 1–10 | safe spawn settlements, one per race |
| Home zones | 11–20 | safe early questing; roads toward the capitals |
| Central heartland | 21–30 | safe capital approaches and middle progression |
| Frontier and Battlegrounds | 31–40 / 41–50 / 51–60 | contested war infrastructure and dangerous wildlife |
| Offshore dragon islands | 60 | contested apex mining and world-boss destinations |
| Capital city zones | no hostile ambient enemies | safe hubs; level-60 guards and important NPCs |

No level-1–30 zone is contested. Every level-31–40 frontier zone and every
higher ordinary zone is contested ground, which flags every player for PvP
([pvp.md](pvp.md)). The four
Battlegrounds zones provide the continuous mainland faction contact; both
level-60 dragon zones are offshore islands without land-neighbor edges.
Named zones and an authored within-zone gradient replace radial distance as
the surface input to `mob_level_at`. The depth floor remains unchanged and
can still overtake the local surface level underground.

Physical height is a separate field with variation at every scale: mountain
ranges with ridges and valleys, hills, gentle lowlands and occasional cliffs.
Each land zone has a character preset (wetland/delta, lowland, rolling hills,
plateau, highland or mountain) that blends softly into its neighbors, with
mild race accents, and one or two strong landmark features. Terrain is
calmer around starts and capitals, and capital ground sits well below the
region's clouds. Roads, civic envelopes and structures apply their own
grading afterward. Full contract: `world_zones.md` §7.6.

Every capital sits centrally in its own city zone with four cardinal gates.
Toward the outer side lies a level-10–20 neighbor, laterally along the capital
axis medium-level heartland, and toward the faction front high-level
territory. Roads connect capitals, starts and villages and reach into each
contested frontier zone; they follow the terrain, branch at T or Y junctions
and need not reach the Battlegrounds (`world_zones.md` §9). Capital defense is
the one fixed guard rule: its guards and important NPCs are level 60.

### Day/night and exterior visibility

One complete world day lasts **20 real minutes**. The shared phase boundary is
04:30/19:30 engine time: the day phase, including dawn and dusk, lasts **15
minutes**, and the night phase lasts **5 minutes**. The clock advances at 60x
during the day phase and 108x during the night phase; changing phase changes
speed without jumping the current world time.

At low natural sunlight the player lighting owner raises the sunlight ratio to
a moderate **0.30 floor**. This improves outdoor night travel while preserving
the absence of sunlight in enclosed caves. Cave Draught night vision composes
through the same owner at **0.45** and never makes a naturally brighter time of
day darker. Dawn and dusk keep the engine's smooth light curve above the active
floor. These values are game rules, not new user settings.

## 2. Destructibility

Rationale: free digging/building would break guard gating (tunneling),
elite mobs (pillar cheese) and territory borders. One territorial rule:

- **R1 — Own faction territory**: digging and building is allowed except in an
  active Claim Stone claim without the claim's permission (R5), a bounded
  hard-protected world-content volume, a protected road corridor or a
  protected POI box (R1b).
  Hard-protected content is limited to complete capital cities (inside the
  wall line, the wall or planted edge and a bare band beyond it,
  `world_zones.md` §12),
  complete starting settlements (the start town, Round 22 D78: the full
  128×128 build envelope plus a bare band of 12 nodes round it with rounded
  corners, `world_zones.md` §12; spawn, waypoint, graveyard and service
  platforms all lie inside it), essential service/quest/waypoint/graveyard platforms, and small
  functional NPC anchors. Outside the road corridors
  and POI boxes below, village, outpost and camp shells, ruins, tents, fences
  and battlefield dressing are generated once and may be changed under their
  zone's terrain rule. A start settlement needs no runtime pit or flood
  detection: by construction of `world_zones.md` §7's 600×500 dry start core
  (no planned water, forced cliff or ravine; gentle start grading only), an
  enclosed or flooded start cannot generate.
  - **Shape of a hard-protected world volume** (Round 24 ruling 30): its
    authored x/z footprint is exact and protection runs upward without limit
    and downward through its **placement height − 100** inclusive. The
    placement height is the final surface y at the footprint's centre column:
    the anchor for a capital's protected city or a start town, the anchor's
    fitted surface for an outpost or bandit-camp functional column. Below that floor the position follows the
    ordinary rules of its column — the zone's territory rule down to y = −500,
    the universal contested deep rule from y = −501 — and mapgen treats it
    like any other ground (ores, gems, rock layers, nests). Each
    hard-protected footprint contains
    only the functional/core structure plus its explicitly authored apron; a
    structure type does not gain a blanket ten-node surround merely from its
    name.
  - **Indirect mutation fails closed** (decided 2026-08-13): hard-protected
    volumes are guarded against indirect mutation. Explosions, fire, liquid
    flow — including downhill flow originating outside the footprint —
    falling nodes, terrain-changing mobs, machines and scripted effects cannot
    alter protected state; inside hard-protected world content no player
    permission exists, so every such path is suppressed or the affected nodes
    are restored. There is no rollback system: protected volumes need none,
    and destruction of the mutable layer deliberately persists.
  - **World-content registry**: every hard-protected non-capital anchor
    registers a stable id and final x/z extent rather than hard-coding a zone.
    The registry separately stores the mapgen grading envelopes of ordinary
    roads and structures; those envelopes are not mutation protection (road
    and POI protection use the corridors and boxes below). Terrain-derived
    placement heights are immutable mapgen output,
    but no first generated chunk owns the decision. Terrain fitting adapts to
    every fixed reserved anchor position; WP13 may not invent a replacement
    position. The construction self-check (`world_zones.md` §7.1) confirms
    that every anchor lies in its own zone and on land, so no POI anchor
    disappears silently.
- **R1b — Roads and POIs are protected** (Round 25 rulings 15–17,
  2026-09-29), in every territory and for every player:
  - **Roads**, their bridges and future waypoints. Sideways the corridor is
    the road's own half width plus 1 node of terrain on each side (Round 28
    ruling 1; Round 25 had 3): `primary` roads are 7 wide, so 9 nodes are
    protected; `secondary` 5 → 7; `trail` 3 → 5. Vertically it covers ±5
    nodes around the road surface. The vegetation claim exclusion (the road,
    its side slopes and 2 nodes beyond the edge: 11 / 9 / 7 nodes) stays
    strictly wider, so no plant that nobody may harvest grows on protected
    road ground, at mapgen or by renewal. The check
    is analytic — the distance to the planned centreline segment — and each
    segment is registered in the existing 128-node candidate grid of the
    zone authority's protection index; nothing is rasterised.
  - **POIs, villages and camps**: horizontally their building core
    (`world_zones.md` §7.5), vertically from 10 nodes below the placement
    height up to 10 nodes above the highest node the POI template places.
    These boxes live in the same grid. Hard-protected functional anchors
    keep their own R1 volume.
  - **Inside a Claim Stone claim** roads are allowed, but the road corridor
    stays protected for everyone, the claim owner included: world protection
    wins over claim permissions. A claim keeps 16 nodes from every POI,
    village and camp core box (`housing.md` §2, §9; Round 25 ruling 27).
  - **Future fire and explosions** spare these corridors and boxes as well as
    the hard-protected content of R1 (user decision 2026-09-29,
    [WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
    E7). Nothing in the game damages terrain today; the guard is deferred work
    (WP46).
- **R2 — Peaceful enemy territory**: in level-1–30 land, an enemy faction may
  not dig or place any node, including torches and ladders. Items remain
  usable. At y = -501 and below the universal contested deep rule overrides
  land-side faction ownership.
- **R2b — Contested land and Battlegrounds**: every ordinary level-31–60
  frontier or dragon-island zone has no construction owner; both factions may
  dig and place subject to tools and explicit protected envelopes (R1, R1b).
  The four
  Battlegrounds zones follow the same shared edit rule at every y, remain
  claim-excluded and follow the Round 14 contested-mainland flight rule. Dragon
  channels remain immutable at every y. A cultural `race_region` never grants
  terrain rights (`world_zones.md` §§8.3/11).
- **R3 — Water columns**: classification is analytic in x/z and does not
  change when players fill or drain nodes. Every authored lake, river, marsh
  channel, cenote and the landward part of each bay mask remains planned water
  in its named zone. The four declared outer bay-mouth caps instead become
  ownerless `deep_ocean` at warped z = -3000 on Elandor and z = +3000 on
  Kragmar. The editable nominal `coastal_shelf` is exactly
  `expanded_land_at(80) and not land_at` and inherits the nearest eligible
  mainland hub's faction/PvP terrain rights; `deep_ocean` beyond that band and
  in those four mouth caps is immutable at every y. Dragon-channel masks
  override the shelf and make their complete columns immutable from world
  bottom to top. Every exterior-ocean class remains non-flyable, while planned
  zone water inherits its zone's flight rule. Claims exist only in the
  eligible home zones (`housing.md` §2). Their planned water may lie in a
  claim; the shelf is excluded although it belongs to a zone, and the ocean
  has no zone (Round 25 ruling 23). The islands hold no claims.
- **R4 — Natural minerals do not regrow** (revised 2026-09-20): ores and mineral resources do
  **not** respawn. A mined-out vein is gone, everywhere, for good. The
  world does not run dry because **depth supplies without bound** (R6,
  §4c, `combat_stats.md` §3) — the price of a material is paid in danger
  and travel, never in waiting for a timer. Renewable ore would have
  capped every material's value at its respawn interval and turned mining
  into a rotation instead of an expedition. Wild plants instead follow the
  habitat-driven renewal in [farming.md](farming.md); no ore, gem, Rock
  Salt or Salt Crust joins that plant exception. **There is no mineral
  exception:** renewable ores are removed entirely, mining camps and the apex
  camps included (user decision 2026-09-29,
  [WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29) E5).
- **R5 — Active Claim Stones**: a fuelled Claim Stone provides the only
  player-owned protection (§5, `housing.md`). Inside its 101 × 101 column
  from y = −100 upward, only the owner and players on its permission list may
  act: "Interact" allows use only (doors, trapdoors, gates, chests, furnaces,
  stations), "Everything" adds digging and building. Every world, faction and
  R1b rule is evaluated
  first and wins over any claim permission. A claim never reaches below
  y = −100, so never the contested deep layer. When its fuel runs out the
  claim protects nothing and the ordinary territory rule applies again.
- **R6 — Tier rock and resource harvesting** (Round 24, 2026-09-29; details
  in `items_crafting.md` §3.0.4): six tier rocks keep the band boundaries at
  **−100 / −300 / −500 / −700 / −1000 / bedrock**, and the rock's tier, not
  the target y, decides which pick digs it. Every dig resolves two questions:
  1. territory/protection: may this player change this position;
  2. pick tier: is the wielded pick at least the tier of the target rock or
     resource.

  | Tier | Canonical metal/pick | Band | Tier rock |
  |---|---|---|---|
  | T1 | Bronze | y ≥ −100 | `default:stone` |
  | T2 | Iron | −101…−300 | `grug_materials:t2_stone` |
  | T3 | Steel | −301…−500 | `grug_materials:t3_stone` |
  | T4 | Silversteel | −501…−700 | `grug_materials:t4_stone` |
  | T5 | Embersteel | −701…−1000 | `grug_materials:t5_stone` |
  | T6 | Abyssal Steel | below −1000 | `grug_materials:t6_stone` |

  Wood and Stone starter picks are T1 picks. All six rocks display as "Stone",
  drop ordinary cobble and are gated by engine node `level` against pick
  `maxlevel`, so a too-weak pick cannot dig them at all; a higher pick digs
  lower rock faster. Cave walls show the local rock. Loose ground (dirt, sand,
  gravel, clay, snow, mud, mesa clay, ash ground) has no gate: hand, skill hand,
  shovel and pick dig it, a shovel fastest. Decorative Slate, Basalt and
  Granite are any-pick building rock that drops itself.

  The exact political split follows those boundaries: **y = −500 is the last
  node of faction home territory; y = −501, the first T4 node, is the first
  universally contested deep node** (Round 31; it was −701). T4 occupies
  y = −501..−700, T5 y = −701..−1000 and T6 y = −1001..−31000. On every
  non-ocean land column, both factions may dig and place at y = −501 and below,
  even beneath a road or active claim. Hard-protected capitals, start towns
  and functional anchors end 100 nodes below their placement height (§2 R1,
  Round 24 ruling 30), well above this boundary. Deep ocean and immutable
  dragon channels remain full-column exceptions.

  Natural resources need the pick of the layer where they first appear, at any
  depth: T1 digs Copper, Tin, Coal, Iron, Quartz and Citrine; T2 Gold and
  Jade; T3 Silver and Garnet; T4 Emberglass and Sapphire; T5 Abyssal Crystal
  and Ruby; T6 Diamond. Each gem occurs only in the rock of its own tier,
  everywhere (`items_crafting.md` §3.0.1). A weaker pick cannot dig the ore at all
  (the former under-tier shatter path is retired). Crafted storage/building
  blocks are never natural resources: any real pick recovers them where
  territory allows, and they always drop themselves.

Implementation: one central `core.is_protected` override in `grug_core`
(faction + position check, including the R1b road corridors and POI boxes);
`grug_housing` adds the claim check (`housing.md` §6).

**Protection hints** (`items_crafting.md` §3.0.4): a refused edit names the
protecting layer, e.g. "Town – protected", "Landmark – protected", "Road –
protected", "Village – protected" (and similar for other POI kinds), "Home of
<owner> – protected" for an active claim, or the territory ("Accord home
territory – protected").

## 2b. Ocean zones & deep-sea danger

Water type is an authored x/z classification, not a test of the node currently
occupying a position (`world_zones.md` §7):

- **Planned zone water:** the landward parts of bays, lakes, rivers, marsh
  channels, cenotes and other authored water inside a named zone remain part
  of their named zone. River water columns use non-renewable, range-two
  `default:river_water_source` / `default:river_water_flowing`; oceans, bays,
  lakes and other surface water use `default:water_source`. The owning logical
  biome or an explicit landmark changes bed, shore, depth and decorations
  within that material rule. Step transitions between river reaches (falls,
  rapids) are defined by Round 22 Phase 5; WP40 does not author
  falling-liquid columns. Planned
  water inherits the zone's terrain, PvP and flight rules and can never become
  deep ocean. For Claim Stones it counts as ground of its zone
  (`housing.md` §2). The four explicitly declared outer bay-mouth caps are
  excluded from this class and use the deep-ocean rule below.
- **Coastal shelf:** the nominal exterior band where
  `expanded_land_at(80) and not land_at` holds around authored positive
  mainland or island shapes. This is editable under the nearest eligible
  mainland hub's zone terrain policy. Coral, kelp and wild-source coverage
  follow `world_zones.md`'s Round 10 rules; further coastal materials and shore
  wildlife retain their own content scope. Although it belongs to a zone, it
  is never claim ground (Round 25 ruling 23).
  As exterior water it has no authored surface or guard level. Ordinary
  `mob_level_at` is nil at normalized y >= 0; harmless/fixed shore wildlife is
  independently levelled. Below normalized y = 0, shelf caves use the standard
  capped/rounded depth level alone.
- **Deep ocean:** every ordinary ocean column beyond the shelf plus the four
  declared outer bay-mouth caps, immutable at every y. This remains the
  deliberately deadly open sea patrolled by the level-100 Kraken Guard (no
  drops or XP). It has no ordinary surface, guard or mob-level result: the
  Kraken is a hand-set fixed entity outside those resolvers. Boat acquisition,
  summoning, movement and damage are decided in [boats.md](boats.md);
  what this world-geometry rule owns is the pursuit contract below.
- **Dragon channels:** separate full-column immutable masks between the
  mainland and the two offshore islands. They are required boat routes and
  carry no Kraken Guard at all. Their warning and
  hard-flight bands come from the same 2D distance field. Each channel carries
  two boat approaches, one northern and one southern, joining its
  Battlegrounds endpoint to two inward-shore island beaches at fixed landing
  points, each with a wooden pier ([boats.md](boats.md) §7.1). Both are
  usable by both factions; their north/south orientation only roughly
  equalizes travel from Kragmar and Elandor. They have no ordinary surface,
  guard or mob-level result.

**Kraken Guard pursuit** (travel plan ruling 7, user 2026-10-02; supersedes
the residual-allowance model decided 2026-08-13). The deep sea is dangerous
because of what the guard does, not because water damages a boat:

- The Kraken Guard **spawns only in `deep_ocean`**. Neither the coastal shelf,
  nor planned zone water, nor a dragon channel ever spawns one.
- **It swims 10 nodes/s while it stands in a deep-ocean column and 5 nodes/s
  everywhere else**, with a view range of 40. Ten is above the improved
  boat's 8, and any hit ejects a boat's rider into the water (`boats.md` §6),
  so a guard that sees a boat in deep ocean catches it and ends the trip.
- **The leash is simple:** the guard ignores the generic leash and soft
  de-aggro, and once a second it checks its own position; outside deep ocean
  it drops its target and holds position. Shelf water, planned zone water and
  the dragon channels are therefore never pursued into beyond the deep-ocean
  edge, and a dragon channel is safe passage for that reason alone; no
  separate channel exception is needed.

The `open_sea_at` adapter is true only for `deep_ocean`; it is false for
planned zone water, shelf and dragon channel (`world_zones.md` §13.3).

## 2c. PvP geography and the flag

Peaceful and contested status belongs to the named surface zone. No level
1–30 surface zone is contested; every ordinary level-31–60 frontier,
Battlegrounds and dragon-island zone is contested. Independently of the surface
zone, every non-ocean land column at **y = −501 and below** (depth tier T4) is
contested; T1–T3 under peaceful land stay peaceful. Deep ocean and the dragon
channels are neither.

Two enemy players can harm each other only while **both are flagged**
(Round 31, WP41). Contested ground and enemy territory flag a player by
location; the "Flag me for PvP" button and PvP contact flag for 60 s; only
own peaceful land clears the location flag; death clears every flag. No
attack, heal or area effect changes anyone's flag, and an unflagged enemy is
no valid target. Rules, numbers, interface and the PvP fortresses and camps:
[pvp.md](pvp.md); geography: `world_zones.md` §4.

## 3. Capitals

There are **three race capitals per continent**, one per race and six total.
Each sits in its own central named city zone and is protected
(indestructible) per the POI rule of §2 — its planned city: everything inside
the wall line, the wall or palisade with its
gatehouses and turrets, and a band at least 12 nodes beyond the edge's outermost
structure (21 nodes from the wall line, 12–18 beyond gatehouses, turrets and
wall faces) that carries no trees and no ground
cover, so players see where the protection ends (Round 22, D76;
`world_zones.md` §12). It runs upward without limit and downward through the
capital anchor's placement height − 100 (Round 24 ruling 30); below that the
capital zone's ordinary territory rule applies, and the contested deep rule
from y = −501.

- A capital is a safe civic hub with **no hostile ambient enemies**.
- All six capitals are walled (Round 23 ruling 2026-09-28, which walled
  Lethariel and Kezamba as well; `settlements.md`).
- Its guards and important faction NPCs are level 60; the killable race king
  is the explicit level-65 elite exception and is protected by four level-60
  elite royal guards (`world_zones.md` §12).
- Its center has four cardinal gates facing level 10–20 home territory,
  medium-level heartland and the high-level contested front; roads reach it
  through them (`world_zones.md` §§3, 9).
- New characters use their race's outer level-1–10 starting settlement.
  Respawns follow the bound innkeeper home; the starting settlement is the
  default. See [home travel](home_travel.md).
- Every race has its own king in its own capital: **six kings total**. Housing
  instead comes from the Housing Steward, a service NPC in every capital who
  hands out the Claim Stone from level 20 (§5); no king grants land or
  housing.
- Capitals hold class POIs, traders, quest givers, job trainers and a major
  waypoint. **There is no class trainer** (user ruling 4 of 2026-09-16,
  `skill_trees.md` §5, `progression.md` §2): new skills come only from the
  talent tree, and the respec is bought in the talent UI, not from an NPC.
  Profession trainers and public stations occupy themed outer-district premises.
  A separate Riding Trainer sells the four riding steps in each capital's shared-design
  outer stable (`mounts.md` §1); profession trainers do not teach Riding. No capital is a superior faction-wide
  administrative seat in the MVP; shared faction services use the same
  service definition in all three faction capitals.
- Race flair comes from architecture and NPCs (per-race wood/build sets,
  `biomes_mobs.md` §5; elven capital = treehouses). Mechanical race perks hang
  on individual vendors (§7).

### Capital services and encounters

The capital watch remains level 60 and still uses its guard banner; the six
WP13 cities stand around it since 2026-09-16 (`settlements.md`, "Capitals in
the world"). The king/royal-guard binding, reset, death and group-respawn
rules are implemented by the six level-65 king entities and their four
level-60 royal guards per capital. They consume the authored `king` and royal
guard sockets; the king alone owns reset, death and group-respawn authority as
specified in `world_zones.md` §12.

## 4. Outposts & patrols

Military outposts, road forts and war-front anchors are reserved by named
zones. They watch roads and frontiers and make the zone's strategic role
visible:

- Roles: guard spawner/anchor, quest hub, graveyard/respawn point for the
  own faction, protector of resource-rich mining sites (e.g. a dwarven
  mining camp — resource site + conflict point in one). Such a site is
  **world content, not a purchasable claim**: it is guarded, never owned,
  and anyone permitted by the zone rule who fights past the garrison may mine
  it. Minerals never regrow there either (§2 R4); wild plants follow the
  separate [farming.md](farming.md) rules. Its small functional anchor is
  indestructible; its ordinary walls, tents and dressing remain mutable under
  the local terrain policy. The six mining camps exist as Round 20 POI art
  (WP13).
- The T3 positional guard base is `nil` in every exterior class, including
  editable shelf, where no guard post may exist. It is exactly level 60 inside
  a capital's protected city (§3) only inside its protected volume (from the
  capital anchor's placement height − 100 upward, Round 24 ruling 30).
  Below that floor and everywhere else on non-exterior columns it is
  `min(70, max(20, surface_level_at(pos)))`. WP13 may later raise that non-nil
  generic base outside the shallow capital hard volume, capped at 70, but may
  never lower it; exterior nil remains nil. Ordinary and royal capital guards
  inside the shallow hard volume remain exactly 60. The fixed level-65 king is
  separate from both resolvers.
  A guard at level ≥ 60 is automatically an elite (scale/tint/telegraph,
  `combat_stats.md` §3). A Round 31 PvP garrison sets level and tier at
  placement instead: fortress guards level 60 elite, a Battlegrounds camp's
  guards a level of the camp's three-level band and never elite, its captain
  no elite either but a named leader at the band's top: 1.15× size and 1.5×
  the HP of his level, like the start zones' leaders (`grug_mobs.LEADER`;
  `grug_mobs/pvp_garrison.lua`).
- Each named zone reserves its required outposts, patrols and special camps
  explicitly. The old fixed minimum of 24 ring outposts is not a target
  budget; the complete zone catalog must replace it with equivalent faction
  coverage before any old anchor is removed.
- **Ordinary guards attack enemy players and monsters, never arbitrary NPCs**
  (`attack_npcs = false`). Dedicated war-front soldiers are the scoped
  exception: their authored encounter anchors may target the opposing
  war-front population, hostile players and dangerous local creatures.
  **The veto belongs to the non-combatant, not to the attacker** (decided
  2026-09-15, revising the universal rule of the same day): monsters and guards
  may each initiate against the other and either may lose, while **villagers,
  elders and vendors are never a target for anything** — they cancel every
  punch, so a fight with one can never end. Guard versus guard stays off across
  factions. A new civilian family declares itself non-combatant
  (`grug_mobs.noncombatant`); nothing narrows an attacker's `attack_npcs` on its
  behalf.
- **PvP fortresses and camps** (Round 31, pvp-plan rulings 17–22): one
  fortress per faction in its middle 31–40 zone, on the Battlegrounds half
  beside the middle road, which keeps its own course, with a trail from the
  gate (Ashenward Bastion, Bannerbreak Warhold) and, in each of the four
  Battlegrounds zones, one lower and one higher camp per faction, 16 camps.
  Positions, spacing (at least 120 nodes between PvP POIs) and protection
  (the blueprint plus a 10-node margin): `world_zones.md` §16. Each fortress
  has a waystone (§6). A camp holds 4 (lower) or 5 (higher) guards of its
  race and band and its named captain, a leader of the band's top level, not
  an elite; a fortress 12 level-60 elite guards and its General's group.
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
  never refill independently (`world_zones.md` §12). A PvP fortress's General
  and his two bodyguards (Round 31) are the same encounter on the same rules.
- **Respawn slots**: every anchor has a configured **maximum population**
  and refills toward it one NPC at a time. Each refill takes a
  **configurable interval** (either an exact duration or a min–max
  range rolled per refill). Slots are independent: if 2 of 4 bodyguards
  die, exactly 2 refills queue up. The royal encounter is the explicit
  group-reset/group-respawn exception above. Intervals in force today:
  bandit/mirefolk camps **30–60 s** per slot (Round 28 ruling 37,
  biomes_mobs.md §4; the recipe camps of biomes_mobs.md §4.2 use the same
  slot model without a node),
  guard posts **180–360 s** — clearing an outpost buys a while of open
  road; a PvP fortress's guards keep that rhythm, a Battlegrounds camp's
  guards return after **100–140 s** and its captain after **270–330 s**
  (Round 31 coordinator defaults, rough values for the playtest). A **freshly generated** anchor owes its full garrison from the
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
(`visual_size` 4–6×), fixed lair POI (no hoard chest: the personal boss
reward replaces it, user decision 2026-09-29, WP audit E11), **stationary
arena fight** (holds its ledge and visibly walks between about three authored
rest positions; it never teleports during idle roaming, kites into terrain or
uses that walk to sidestep pathfinding exploits). A blocked rest route stops,
rests and retries another authored position on the existing cadence.
Telegraphed attacks (the elite wind-up mechanic scaled up), respawn timer — but
each has a **distinct skill set** so it threatens in its own way.

A dragon may begin or finish a hostile skill only while it has a valid living
hostile target. Peaceful players are excluded from acquisition; losing the
target cancels the active wind-up/action. Periodic scorch damage counts as
combat damage for the ordinary five-second combat window.

**Dragon arenas** (Round 31, user ruling `round31-plan.md` §6 item 11):

- Each dragon fights in a round arena of **radius 40** around its spawn
  point, on the island's own ground: a gently swelling floor (0–2 nodes)
  whose outer edge wanders 0–3 nodes beyond the radius; sparse rim stones
  (stone on Wyrmglass, mossy cobble on Stormscale) mark the radius. The
  arena's square (82 × 82, from 10 below to 22 above the floor) is a
  protected POI core; the dragon's own breath patches stay possible in it.
- **The arena edge is the leash.** A hostile player inside the arena (within
  the radius, 10 below to 24 above the floor) is a target at any height and
  distance; a player outside it is never acquired or targeted (nor by the
  whelps), holds no threat or engagement on the dragon (dropped once a
  second), cannot taunt it or hand it over through heal threat, and a punch,
  shot or ability from outside does not hurt the dragon or its whelps. When
  an engaged dragon has no hostile living player left inside its arena, the
  fight ends: the encounter resets (participation, whelps, enrage, full
  health) and the dragon flies back to its spawn point and lands. A re-pull
  is a fresh attempt. There is no distance or contact leash for dragons.
- **The dragon's wrath** (user ruling 2026-10-03): a player who takes part in
  the fight (damages the dragon or its whelps, is targeted by them or hit by
  them inside the arena, or heals or shields a participant from within the
  arena radius + 15 nodes of its centre) is flagged for that fight. While the
  fight runs, a flagged player outside the arena takes **500 damage per
  second** (armour never reduces it, no shield soaks it, never PvP contact), with a
  chat warning on leaving, a "Dragon's Wrath" status and its own death
  message. The flags end together, at once, when the dragon dies or resets;
  a participant's death or logout drops only that player.
- **Wyrmglass hazards:** patches of thin ice flush with the floor that break
  into ice water when a player stands on one node for 1.5 s (the node and its
  four neighbours) and freeze again 20 s after nobody stands in them; ice
  water deals **250 damage per second** and slows. Three flat frost-stone
  terraces one and two nodes high, clearly distinct from the ice.
- **Stormscale hazards:** six glowing ember fissures one node deep and one or
  two wide, framed by basalt, dealing **350 damage per second**, no slow; five
  fallen trunks one node high (players jump over them, the wyvern walks or
  flies over them; not cover).
- Hazard damage is a fixed amount per second through `set_hp` (node damage),
  so armour does not reduce it and it is never PvP contact; the absorb
  shield still soaks it, as it soaks dragon scorch. No hazard lies within 9
  nodes of the spawn, within 4.6 of a perch or within 4 of the edge.

- The old stage-one rule **one dragon per continent is retired**. The world
  gets two offshore overworld dragons, one beyond each Battlegrounds endpoint,
  implemented through one encounter chassis with two regional variants.
- Every overworld dragon occupies a separate **offshore island** beyond one
  ocean endpoint of the Battlegrounds. An immutable full-column channel removes
  land, bridge and tunnel access; both factions receive roughly equivalent
  boat routes through separate northern and southern approaches. Each
  island is a contested level-60 mountain zone with strong level-60 creatures,
  war remains and a culminating summit lair.
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
- Each endpoint also contains an apex mining camp (`world_zones.md` §6; no
  renewable sockets, §2 R4). Both the boss and the camp are contested endgame
  objectives.
- **Phase 2+ — additional regional apex creatures**, same code, own
  kits: e.g. jungle giant serpent (poison pools, submerges), blight bone
  colossus (knockback slam, summons adds). The dragon stays the biggest.
- **V2 — the Nether dragon lord** as part of the first large post-V1 content
  update, whose Nether has its own mapgen, story line and mob cast; the Fire
  Dragon and the wider Nether encounter reserve stay reserved until then.

## 4c. Deep T4–T6 is contested endgame territory

The political deep layer begins at **y = −501** (depth tier T4; Round 31, it
was −701), independently of the surface zone. T4 occupies y = −501..−700, T5
y = −701..−1000; T6 begins at y = −1001 and continues to the map floor. Both factions may excavate, place and fight there under §2 R6. Race
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
ordinary continental ores, Diamond (the only gem below −1000) and Abyssal
Crystal:

| Depth | Resource density |
|---|---:|
| y = −1001..−1499 | normal T6 density |
| y = −1500..−1999 | +25% |
| y ≤ −2000 | +50%, capped |

The bonus is a deterministic placement budget, never runtime ore respawn. It
does not multiply trophies, king or dragon loot, claims or quest rewards. The band has no dedicated apex boss in the MVP and
its creatures retain their ordinary family drops.

## 5. Housing: open-world Claim Stones

The complete Claim Stone contract is [housing.md](housing.md) (Round 25,
2026-09-29); this section only summarizes its world-facing integration.
Private housing islands, royal land grants, purchased depth rights and guild
land do not exist.

- A claim is a 101 × 101 column around one Claim Stone, from y = −100
  upward without limit. Each player has one soulbound stone, handed out free
  by the Housing Steward in every capital from level 20.
- The whole square must lie in the claimant's own faction home territory, in
  its level-11–30 zones (seven per faction), and may not touch a level-1–10 or
  level-31+ zone, a capital zone or the other faction's territory, and keeps
  16 nodes from hard-protected footprints and from POI, village and camp
  cores (Round 25 ruling 27; blend envelopes are no barrier). Lakes, rivers and
  bay water inside an eligible zone may lie in a claim; the shelf and the
  ocean may not. There are no housing masks and no coastal
  housing areas. Claims never overlap but may touch.
- A placed stone is a draft that protects nothing and crumbles after
  5 minutes unless the owner activates it with 5 lumps; for 12 hours after
  activation it cannot be picked up (Round 26, `housing.md` §2a).
- The stone burns coal lumps or charcoal (one lump = 7 h 16 min; 99 lumps
  ≈ 30 days) as a "paid until" timestamp; server downtime counts. Without
  fuel the claim protects nothing, and anyone may destroy the stone with a
  pick.
- While fuelled, only the owner and players on its permission list may act
  there: "Interact" allows use only (doors, trapdoors, gates, chests,
  furnaces, stations); "Everything" adds digging and building. World
  protection (§2 R1, R1b) wins over every claim
  permission, the owner's included: roads through a claim stay protected.
- No natural renewal (wild plants, trees) and no hostile mob spawns inside
  an active claim; mobs may walk in. An expired claim renews and spawns
  normally.
- The claim can be the owner's travel-home target (§6).

## 6. Travel: innkeeper homes, waypoints and boats

The current V1 return and death destination is the twelve-location
[innkeeper home system](home_travel.md). A player's own Claim Stone can be the
travel-home target instead (home stone, below). The waypoint network is a
separate travel feature, part of V1 (user decision 2026-09-29,
[WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29) B2;
WP17).

**Waypoint network** (the classic action-RPG model, decided 2026-08-06; built in Round 29,
[travel plan](../planning/travel-boats-waypoints-plan.md) §1.1 "Waypoints"):

- Waypoints: every race starting settlement, every capital and, since
  Round 31, each faction's PvP fortress (pvp-plan ruling 18), and no others
  (no zone-hub waypoints; user decision 2026-09-29). Each is a **waystone**
  node (`grug_mapgen:waystone`) the mapgen places at the centre of the
  settlement's waypoint pad, in the cell of its `travel_waypoint` socket
  ([settlements.md](settlements.md#waypoint-pads)). A faction's network is its
  three starts, three capitals and its fortress, seven waystones.
- **Unlocked by visiting, per character** (player meta
  `grug_home:waypoints`): standing within 8 nodes horizontally (and 8 up or
  down) of an own-faction waystone, checked once a second, or right-clicking
  it, discovers it with one flash and chat line "Waypoint discovered: <name>".
  The character's own start counts as discovered from creation.
- **Right-click** opens the list of the seven own-faction waypoints: "You are
  here", **Travel** (discovered) or a greyed "Not yet visited".
- **Travel** works **only while standing at a waystone** (within the same
  reach), waystone to waystone: instant, free, no cooldown, alive and out of
  combat. It runs through the innkeeper return's own path (`grug_home.travel`
  in `grug_home/travel.lua`: dismount, emerge, re-validation on the next
  server step, safe arrival) and arrives beside the destination stone (the
  socket's arrival side first, then the next free side). A failed preparation
  leaves the player in place with a message. It never touches the 30-minute
  home cooldown. Travel time is the cost; mounts stay relevant.
- **No waypoints in enemy territory**: an enemy faction's waystone is inert
  (no unlock, no use, one line on right-click). None stand in ordinary ocean
  or on the dragon islands.
- The world map and the minimap show discovered waypoints as the marker kind
  `waypoint` ([world_map.md](world_map.md)); undiscovered ones are not shown.
  The initial cartographic atlas has no fog of war. Showing terrain or a
  waypoint on the map never unlocks waypoint travel; only visiting the
  waystone does. There is no `/unstuck`.
- Phase 2 extension: **Nether crossings** link authored, level-equivalent
  named-zone portal pairs into enemy territory
  (`TODO-design-nether.md` until specced).

**Home stone** (Round 25, `housing.md` §8): the player's own Claim Stone can
be the "travel home" target of the innkeeper return, with the same 30-minute
cooldown. The arrival is the stone's arrival cube. When the stone is picked up
or destroyed, the target falls back to the player's bound innkeeper (the
starting-town innkeeper when none is bound), with a message; binding an
innkeeper also replaces a claim home. Death still respawns at the bound
innkeeper. This replaces the former Home Stone channel (10-second cast,
60-minute cooldown).


**Boats** are the third travel mode next to walking/riding and the waypoint
network, and the only access to both dragon islands. A boat is a water mount:
an owner-bound skill item bought from the Shipwright at every capital stable
(base boat at level 15, improved boat at level 30), summoned only while the
player stands or swims in water, ejected by any hit, and never left empty in
the world. The complete contract lives in [boats.md](boats.md); the water they
move through is classified in §2b above. Boats never teleport and are not part
of the waypoint network.

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

(Own names/flavor later — no 1:1 copies from existing games.)

- The authored layout (hubs and anchors, `world_zones.md` §7.1) fixes every
  race's approximate compass position, starting zone and capital. Seed
  variation changes local borders but never moves or exchanges them.
- The two factions receive equivalent access to all level/material bands, but
  race geography is not required to be a geometric mirror. A character begins
  in its race's outer starting settlement and reaches its central capital
  through the safe early-level roads.
- Race choice at character creation (after faction, before class), stored
  in player meta. The look follows the class
  ([character_visuals.md](character_visuals.md) §1.1).
- Until faction, race and class are all complete, the player is held in
  **character-creation stasis**: movement, jumping and gravity are frozen,
  current velocity is cancelled and engine immortality prevents damage and
  drowning. The mandatory faction → race → class → look forms use an opaque dark
  backdrop; no physical lobby or generated holding room exists. Choosing a
  race starts an asynchronous emerge of that race's start behind the remaining
  UI. The first class choice is stored at once as a *pending* class; only when
  that emerge succeeds is the player positioned exactly once, the class
  persisted as the character's class and the pre-stasis physics/immortality
  state restored. Disconnects reconstruct stasis from the still-incomplete
  identity (a pending class does not complete it), stale callbacks cannot
  release a later session, and emerge failure stays safe with an explicit
  retry.
- **Character creation can always be paused** (Round 24 ruling 32). Esc
  really closes every creation dialog (faction, race, class, look, waiting
  screen)
  and nothing reopens it by itself, so the next Esc reaches the native game
  menu; the player stays in stasis. While creation is unfinished the player's
  inventory formspec is the current step (the inventory key continues), and a
  screen hint says "Character creation paused – press I to continue" while no
  dialog is open ("World ready – press I to continue" once preparation
  finished meanwhile, a retry hint after a failure). When preparation finishes
  while the waiting screen is open, the next step replaces it; when it was
  dismissed only the hint changes; a failure never forces the dialog open.
  Faction, race, the pending class and the confirmed look are stored in player
  meta at once (a look in progress is not), so a reconnect continues at the
  first missing step. There is no kick button.
  After completion the normal inventory returns.
- MVP perks (revised 2026-08-06 — a perk must be FELT from level 1, a
  vendor discount is invisible for the first ten hours): **one visible
  passive per race** + the vendor discount as a bonus. Passives
  (implementation: WP19, race registry hook): Dwarf −20% fall damage, applied
  after the max-HP fall conversion; absorb never applies to fall damage (`combat_stats.md` §2) ·
  Troll +50% out-of-combat mana regeneration and +50% food healing
  (instant and per tick; Round 26) · Undead ignored by zombies at night
  (unless the player attacked that zombie) · Orc +1 rage per hit taken ·
  Elf +5 m ability range (**ranged/spell abilities only** — melee abilities
  keep their own reach, `classes.md` §2b) · Human +10% quest XP. Plus **one
  race-exclusive vendor per race** (WP7). Implementation state (WP19): the
  troll perk `ooc_regen_mult` (1.5) multiplies out-of-combat mana
  regeneration and food healing (`grug_food.heal_multiplier`, instant and per
  tick); there is no natural HP regeneration (WP21 closed 2026-09-29), and
  rage decay is unaffected. The
  human bonus is a latent hook (`grug_classes.get_xp_bonus`)
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
- Universal base recipes and professions are never race-exclusive; there is
  no cultural finishing (removed in Round 33). Equipment remains tradeable
  and wearable by every race.
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
- Nature mobs use the fixed aggressive/neutral dispositions in
  `biomes_mobs.md`. Aggressive families can engage players and NPCs; neutral
  hunted wildlife does not become aggressive merely because it is in wilderness.
- **Mob density is deliberately high**: target ~1 visible mob per 15–20 m of
  travel in wilderness zones. Current density and spawn eligibility follow
  `biomes_mobs.md` §0/§4; old ring-cell counts are historical evidence.

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

The 24 outpost anchors and 12 bandit camps are live, and since WP40 R7 they
are no longer ring-derived: their positions come from the authored anchor
layout (`grug_mobs/camps.lua`, `grug_core.outpost_at`). The delivered regional
structure subset is six villages, six outposts and six bandit camps
(`settlements.md`); BACKLOG WP13 tracks the remaining roster.

Life measures (cheap on a voxel budget): named NPCs with one-liner barks,
visible patrols, light/smoke details and a quest board per village. Ordinary
guards fight monsters and eligible enemy players; only dedicated war-front
units fight opposing faction NPCs. NPC levels follow their named zone/role.
Guard levels use the positional base above, with exact level-60 capital
defense in the shallow capital hard volume; a later authored post role may only
raise the generic base outside that volume within its cap. Kings retain their
separate fixed level 65.

**Drop rule (anti-litter, decided 2026-08-06)**: mobs and NPCs drop
loot ONLY when a player was involved — details in combat_stats.md §3
(player-tag flag). Faction NPCs drop only to ENEMY players (PvP kills);
a wolf slain by a guard drops nothing.
