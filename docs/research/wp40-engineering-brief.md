# WP40 Simple Named-Zone World — Engineering Contract

Status: **current WP40 engineering authority; fixed-layout V1e R2 was
independently and visually accepted 2026-08-27. The R3 vertical contract and
four-seed feasibility preflight are green; R3 implementation acceptance is
next.**

This contract implements the product rules in
[world_zones.md](../design/world_zones.md). The independently reviewed
[simple-map rebase plan](wp40-simple-map-rebase-plan.md) owns the R0–R8
delivery sequence. The independently reviewed
[R3 vertical contract](wp40-simple-map-r3-contract.md) owns R3's exact
implementation and evidence boundary. This file owns the technical target.
The former exact T2
partition/topology compiler, its source authority, package plans, PCC/F1/F2
gate and evidence runners are readable history only.

WP40 remains fresh-world-only. Production uses native v7 with one emerge
thread. Native v7 owns caves, ores, dungeons and strata; Grudgelands owns one
fixed horizontal layout, one globally queryable surface-height field and one
consolidated surface transaction.

## 1. Preserved and retired scope

WP40 still delivers:

- 38 stable named zones and the complete progression/PvP catalog;
- six starts, six capitals, 100 stable anchor slots and two dragon endpoints;
- 57 reliable land routes split 30 primary, 24 secondary and three trails;
- four boat links with two approaches per island;
- two independently authored faction silhouettes, four open bays, exact Holy
  Grounds, two offshore islands, a nominal shelf and immutable channels/ocean;
- ten housing masks and four 600 by 300 coastal housing cores;
- logical biomes, relief, landmarks, difficulty, terrain height, policy and
  public query APIs;
- G1/G2, cultural, access, parity, apex-socket and housing-capacity evidence;
  and
- one deterministic VoxelManip transaction preserving native substrate.

The rebase retires seed-selected macro layouts, exact polygon partitions,
half-open faces, boundary rasters/identities, the requirement that all 61 safe
contact pairs own a nonzero boundary, the closed coast-component roster, exact
Euclidean shelf distance, the capital 20/25/30 difficulty profile, and the old
compiled-geometry schema plus PCC/F1/F2 final gate.

Historical artifacts remain unchanged factual evidence. They do not constrain
the new schema.

## 2. Authoritative horizontal model

### 2.1 Source families

One compact versioned source defines:

- layout metadata and macro-region bounds;
- 38 zone records with stable id, hub, optional bias, policy, target
  difficulty, biome palette and relief;
- starts, capitals and fixed ownership cores;
- independently authored mainland/island additive and subtractive primitives;
- exact unwarped Holy Grounds;
- four bay-water masks and two immutable channel masks;
- 57 land routes, four boat routes and explicit crossing interfaces;
- 100 fixed anchor slots: 16 directly authored and 84 layout-fixed from the
  accepted V1d seed-zero positions;
- ten housing masks and four coastal cores;
- named hydrology/landmark masks; and
- six protected capital-ingress chains.

The source is data. It contains no winner search, boundary repair, face
materialization or fallback geometry. Exhaustive validation derives the
diagnostic geometric-contact evidence from that source.

### 2.2 Fixed layout and seed ownership

The horizontal geometry layout id remains `wp40-simple-map-v1d`; its current
source revision id is `wp40-simple-map-v1e`. Land, zone ownership, routes,
water classes, housing masks and all 100 anchor positions are identical across
world seeds. The 84 former candidate-based anchors retain the accepted V1d
seed-zero coordinates plus their approved candidate index as provenance, but
the alternatives are no longer live geometry. The full canonical seed string
controls broad/detail height lattices, logical-biome detail, decorations,
resources and content variation.

Public constructors bind the complete seed string once and never pass it
through a Lua number. The SVG uses preview seed `0` for seeded vertical and
content context while displaying the single fixed 2D anchor roster.

### 2.3 Warp and safe arithmetic

Mainland, island and non-fixed zone-ownership queries use one layout-bound
integer warp:

- 256-node cells and at most 60 nodes displacement per axis;
- one halo cell beyond every queried primitive/shelf extent;
- identical warp applied to query point and eligible hubs;
- rounded integer coordinates before ownership scoring; and
- validation below `2^53 - 1`, with displacement Lipschitz constant below
  one and no fold.

The Holy Grounds macro/protection rectangle and fixed ownership cores are
unwarped; internal Holy Grounds zone ownership reuses the common warp. Outside
the padded interesting extent, queries fail closed to deep ocean/no zone.

### 2.4 Land and water

Land is a small union/difference of closed axis-aligned capsules, rounded
rectangles and ellipses. Elandor and Kragmar have separately authored source
records and digests; reflection is a validation failure.

The total classifier is:

1. exact start/capital cores: fixed land except civic water declared for that
   same core;
2. the four mutable dry coastal-core capsules, which override the warped
   macro coast, ordinary ownership and hydrology;
3. the deep-ocean cap of a matched outer bay mouth;
4. explicit closed bay water;
5. ordinary macro hydrology or land, including the exact Holy rectangle;
6. closed immutable dragon channels;
7. nominal shelf; and
8. deep ocean.

`expanded_land_at(r)` expands fixed-land extents and each positive primitive
by `r` after the query coordinate is warped. It does not shrink or expand
subtractive planned-water masks. It is consulted only after fixed land,
planned water, ordinary land and channels fail. Equality is included. The
shelf is therefore `expanded_land_at(80) and not land_at`: deterministic and
shared by policy/SVG, but not exact Euclidean distance to every final CSG
corner.

The four outer bay mouths become ownerless deep ocean at warped z = -3000 on
Elandor and warped z = +3000 on Kragmar. Because this uses the existing shared
warp, the transverse boundary meanders gently without another field or water
algorithm. Declared interior water retains the fixed feature's zone ownership and is
classified as planned water; unrelated general water masks cannot cut fixed
land. The four bays stay open/connected, at least 64 nodes wide, outside
capital and housing cores, and create no new land contact. Deep ocean and
channels are immutable full columns. Planned water keeps zone ownership and
is claim-ineligible. Shelf policy/dressing uses the nearest eligible mainland
hub. Every wet named WP40 hydrology reach materializes later as non-renewable,
range-two `default:river_water_source` / `default:river_water_flowing`.
Oceans, bays and other non-hydrology surface water use
`default:water_source`. The three orthogonal contact-face waterfalls leave a
one-source-node-deep receiver opening in the lower bed and rely on native
liquid simulation for falling columns; the planner never authors a falling
water column.

### 2.5 Zone ownership and difficulty

After fixed cores, `id_at` restricts candidates to one macro region and
minimizes:

```text
squared_distance(w(point), w(zone.hub)) - zone.bias
```

Stable numeric id breaks a tie. Deltas are at most 8192 and
`abs(bias) <= 2^24`.

The 57-route graph alone defines `neighbors(id)`. Exhaustive validation records
all emergent geometric contacts as diagnostic layout evidence; contact neither
creates a route edge nor requires an allowlist or stable boundary identity. No
boundary dual is produced.

Difficulty is independent of boundary geometry. Each zone contributes one
target to a 32-node Q16 lattice. Separate mainland/island components use a
separable triangular 192-node-radius smoothing pass and sequential one-axis
integer interpolation. Adjacent walkable nodes and route steps differ by at
most two levels.

### 2.6 Paths, anchors and housing

Every path has stable id, kind, class, ordered centreline, corridor, endpoints
and explicit crossing interfaces. Land-route, POI-spur and protected-ingress
corridors must fit ordinary land or locally owned planned water. Planned-water
intersections are deterministic terrain-grading spans; coastal shelf, deep
ocean and immutable dragon channels remain forbidden. Paths never add or
repair horizontal land. Required POIs receive explicit spurs. Boat links
remain outside the land-neighbor graph.

Six capital ingress records each concatenate the existing capital/front
primary route with one existing frontier/Holy secondary route. Their
128-node-wide shallow hard-protection corridor runs continuously from the
capital build envelope into the exact Holy Grounds rectangle. It adds no graph
edge, route search or land geometry; the canonical KAT binds its capital,
ordered route ids and width.

R2 freezes all 100 anchor x/z positions. The 84 migrated records preserve
their accepted V1d seed-zero candidate index only as provenance; no seed hash
selects an anchor. R3 terrain grading must fit every frozen position;
rejection, reselection and endpoint movement are forbidden.

`housing_eligible_at(x,z)` means the complete 101 by 101 future reservation
passed every static exclusion. Exactly the 100 actual anchor envelopes and 74
actual POI-spur corridors are excluded; retired alternatives reserve no land.
Packing runs once per layout over all 111 by 111 origins with the retained
graph greedies, 16 layout-bound hash orders, biased and row/reverse orders,
constructive extrema and upper bound.

## 3. Global height and mapgen composition

### 3.1 Height authority

`H(full_seed_string,x,z)` / `terrain_height_at` is a project-owned integer
field composed from bounded broad/detail lattices, the zone relief profiles,
bounded secondary profiles, simple landmark masks and deterministic grading
for starts, capitals, housing cores, routes and fixed anchors.

It is globally queryable without emerging a chunk, independent of request
order and identical in engine/offline loaders. Engine spawn level, native
heightmap and generated nodes are never global placement authority.

### 3.2 Overlap and operation priority

The pure planner emits typed operations in this precedence:

1. preserve native/foreign protected content;
2. fixed hard foundations;
3. bridge/tunnel/ford/causeway interfaces;
4. typed paths;
5. base terrain and shallow shell repair;
6. explicit water;
7. biome surface material;
8. resources; and
9. decorations.

The planner resolves ownership before mutation. It has no arbitrary CSG
operation language, geometry repair or late anchor selection.

### 3.3 Native-content preservation

Native v7 runs first. The consolidated adapter:

- preserves caves below its owned shallow shell;
- preserves registered WP43 strata and ore veins;
- does not overwrite dungeon nodes or foreign protected content;
- performs one content-id pass and one final lighting/liquid update; and
- gives each central mapchunk deterministic write ownership with read-only
  halo data where needed.

Mapchunk-order and owner-slice fixtures must remain byte-identical.

### 3.4 Biomes, decorations and resources

The evaluator chooses a logical biome only from the owning zone's palette.
The content layer maps that frozen id to top/filler/shore/bed nodes,
decorations and spawn/gathering records. It never changes zone, height or
biome selection.

Resources consume final zone/race-region/depth and WP43 material APIs.
Generic placement, cultural placement and protected apex sockets remain
separate. The 32-seed evidence owns varying content/supply, not fixed topology.

### 3.5 Initialization and memory

Each emerge Lua state constructs the same immutable evaluator from source and
the full seed string. Layout-derived tables are precomputed once per state.
Hot scalar queries allocate no result tables. Sparse routes, hydrology and
anchors use a 128-node x/z index; zone lookup scans only its macro-region
roster.

## 4. Query and compatibility contract

The pure 2D surface is:

```text
macro_region_at(x, z)
land_at(x, z)
id_at(x, z)
water_class_at(x, z)
nearest_path_at(x, z, optional_kind)
selected_anchor_2d(zone_id, slot_id)
```

The final `grug_zones` registry exposes defensive-copy `get`, `at`,
`neighbors`, `travel_links` and `anchor`; allocation-free `id_at`,
`biome_at`, `race_region_at`, `faction_at`, `territory_rule_at`,
`pvp_rule_at`, `surface_mob_level_at`, `mob_level_at`,
`guard_level_at`, `terrain_height_at`, `water_class_at`; indexed
`nearest_route_at`/`nearest_hydrology_at`; and
`housing_eligible_at`.

All coordinate queries use finite safe Lua numbers and nearest-integer,
half-away-from-zero normalization. Invalid input is a programmer error.

### 4.1 Legacy query consumers

| Current helper | Complete productive consumer group | R7 target |
|---|---|---|
| `grug_core.surface_level_at` | `grug_core/init.lua` capital setup; `grug_mapgen/structures.lua` outpost/camp placement; `tools/wp40/runtime_probe/init.lua` | compatibility adapter to `terrain_height_at`; no difficulty mapping and no chunk heightmap/global spawn-level fallback |
| `grug_core.territory_at` | internal zone/mob/guard helpers; `grug_core/protection.lua`; `grug_mobs/golem.lua`, `rabbit.lua`, `camps.lua`, `rares.lua` | direct `faction_at` for culture/faction gates; `territory_rule_at` for protection; temporary adapter only where required |
| `grug_core.zone_at` | central indirect `_grug_spawn_zones` dispatcher in `grug_mobs/init.lua` (27 definitions in 26 mob files); `bandit.lua`; `skeleton_archer.lua`; internal guard floor; runtime probe | one explicit derived coarse-bucket adapter from named zone, water and depth; then migrate content rows and delete |
| `grug_core.mob_level_at` | `grug_mobs/levels.lua`; internal guard/difficulty helpers; runtime probe | `grug_zones.mob_level_at` |
| `grug_core.guard_level_at` | guard branch in `grug_mobs/levels.lua` | `grug_zones.guard_level_at` |
| `grug_core.difficulty_at` | no productive caller beyond its definition | small compatibility adapter or explicit removal after API audit |
| `grug_core.open_sea_at` | Kraken leash call and captured function value `_grug_spawn_check` in `grug_mobs/kraken.lua`; runtime probe | `water_class_at == "deep_ocean"`; replace old seat-rectangle leash direction |
| central protection | `grug_core/protection.lua`; all engine/default/mobs/material callers flow through `core.is_protected` | one policy override using `territory_rule_at`, player faction and bounded hard volumes while preserving bypass and previous-handler delegation |

R7 KATs cover Holy y = -700/-701, peaceful enemy, contested land,
planned water, shelf, deep ocean, channel, capital hard volume, capital
ingress corridor interior/edge/exterior,
`protection_bypass`, empty names and delegation to the prior protection
handler.

### 4.2 Hidden coordinate/anchor consumers

The cutover also owns these non-query migrations:

- `grug_core/init.lua`: six capital literals, spawn/platform persistence,
  24 outpost candidates and 12 bandit-camp candidates;
- `grug_factions/init.lua`: join/respawn calls to the old spawn state machine;
- `grug_traders/vendors.lua`: trader slots derived from old capital literals;
- `grug_mobs/camps.lua`: outpost patrol positions;
- `grug_mobs/rares.lua`: ten raw three-point rare patrol routes; and
- `grug_mapgen/biomes.lua`: old rectangular biome cuboids.

Starts, capitals, outposts, camps and rare routes migrate to final stable
anchors/payload records. Local trader offsets may remain relative to the final
capital anchor. No runtime retry geometry chooses a different x/z or global y.

### 4.3 Active writer inventory

The current load order in `grug_mapgen/init.lua` is: legacy v7
terrain/climate overrides; disabled WP40 T1 foundation; old biomes, ores and
decorations; `ocean_mask.lua`; then `structures.lua`.

Four active Lua write paths must disappear atomically:

| Legacy path | Active write |
|---|---|
| ocean mapgen writer | `ocean_mask.lua` registers `ocean_mask_mapgen.lua`, whose mapgen-environment callback mutates the engine VM |
| ocean healing LBM | `grug_mapgen:ocean_mask_heal` performs runtime `bulk_set_node` writes from old coast geometry |
| structures callback | main-environment `register_on_generated` writes capitals, outposts and bandit fires after the engine blit |
| capital repair | `grug_core.ensure_camp_platform_built` can perform a non-mapgen VoxelManip repair write during spawn/emerge handling |

Old engine biome, ore and decoration registrations are part of the same audit:
R6 surface decorations/resources may not coexist with their legacy
registrations. Only a closed retained-native allowlist (including required
strata/substrate) survives.

R7 loads and validates the final payload, activates every query adapter,
registers exactly one new writer, removes both legacy loader paths and all four
writes above, switches anchors/protection/content, and only then permits a
fresh-world run. There is no legacy-writer runtime fallback.

### 4.4 R7 removal/no-double-writer gates

The durable R7 audit uses `rg` with explicit expected counts:

```sh
# No legacy query outside the central adapter.
rg -n --glob '*.lua' \
  'grug_core\.(surface_level_at|territory_at|zone_at|mob_level_at|guard_level_at|difficulty_at|open_sea_at)\b' \
  mods/ENTITIES mods/ITEMS mods/MAPGEN mods/PLAYER

# No old loaders, IPC or healing LBM.
rg -n 'dofile\(path \.\. "/(ocean_mask|structures)\.lua"\)' \
  mods/MAPGEN/grug_mapgen/init.lua
rg -n 'ocean_mask_mapgen\.lua|grug_mapgen:continent|grug_mapgen:ocean_mask_heal' \
  mods/MAPGEN/grug_mapgen --glob '*.lua'

# No old global height authority.
rg -n --glob '*.lua' \
  'core\.get_spawn_level\s*\(|get_mapgen_object\s*\(\s*"heightmap"' \
  mods/CORE/grug_core mods/MAPGEN/grug_mapgen

# Exactly one new Grudgelands writer/loader; no runtime repair writes.
rg -n 'core\.register_on_generated\s*\(' mods/MAPGEN/grug_mapgen --glob '*.lua'
rg -n 'core\.register_mapgen_script\s*\(' mods/MAPGEN/grug_mapgen --glob '*.lua'
rg -n 'core\.bulk_set_node\s*\(|vm:write_to_map\s*\(' \
  mods/MAPGEN/grug_mapgen --glob '*.lua'

# Old coordinate providers and protection geometry gone.
rg -n --glob '*.lua' \
  'grug_core\.(capitals|get_spawn_pos|outpost_anchors|outpost_candidates|bandit_camp_anchors|bandit_camp_candidates)\b' \
  mods/ENTITIES mods/ITEMS mods/MAPGEN mods/PLAYER
rg -n 'in_capital_zone|in_poi_zone|protected_zone_in_box|POI_PROTECT_DEPTH|grug_core\.territory_at' \
  mods/CORE/grug_core/protection.lua mods/MAPGEN/grug_mapgen --glob '*.lua'
```

The first, second, third, coordinate and old-protection groups expect zero
outside named compatibility/retained-native allowlists. Callback/loader output
must show exactly one active new WP40 writer. Any retained ore/decor registration
has one explicit native-substrate allowlist row; old surface scatter and
decoration registrations expect zero.

## 5. Verification, performance and interpreters

- R1/R2 validate the fixed layout exhaustively on its finite integer extent:
  connectivity, ownership cores, routes, contacts, bays, water, housing, safe
  arithmetic and deterministic SVG/canonical data.
- Long full-layout scans and all 32-seed content/resource populations run
  under LuaJIT.
- Plain PUC Lua 5.1 owns syntax/static gates and targeted representative KATs.
  Canonical PUC/LuaJIT artifacts and digests must be byte-identical.
- The retired T2 full-`W`, PCC, F1 and F2 rounds are not run on the new
  schema. Their immutable outputs remain historical evidence.
- Lua under `tools/wp40/` receives explicit `tools/bin/luac51 -p`,
  SETGLOBAL and Lua-5.1 do-not-write checks because mod sweeps do not cover it.
- Publish an 80 by 80 horizontal LuaJIT classification benchmark with its host,
  interpreter, absolute result and WP18-relative result. The measurement is
  comparative evidence, not a fixed acceptance threshold: no absolute or
  regression limit becomes binding without a measured whole-mapchunk budget
  and a documented derivation. Reuse one x/z result for a vertical column.
- R7/R8 add engine/offline parity, native preservation, owner-slice,
  mapchunk-order, content-ignore, lighting/liquid and rollout evidence.

The real fallback-engine GUI run remains user-executed.

## 6. Delivery authority

The reviewed rebase plan owns:

- **R0:** documentation authority only; no production code.
- **R1:** pure fixed 2D evaluator, validation and canonical SVG.
- **V1:** mandatory user visual approval; source tuning only.
- **R2:** freeze accepted 2D source, anchors, housing and invariants.
- **R3:** pure global height, final fixed-anchor heights and relief.
- **R4:** complete disabled geography/policy payload and adapters.
- **R5:** disabled typed planner and consolidated map adapter.
- **R6:** content/resources and 32-seed evidence.
- **R7:** atomic production cutover and consumer migration.
- **R8:** release evidence and runtime handoff.

Any source defect fails with its record. It never activates land growth,
endpoint movement, anchor reselection, a second writer or old topology code.

## 7. Engine-research conformance

This contract covers every engineering subject required by
[mapgen-control.md](mapgen-control.md):

| Required subject | Owning section |
|---|---|
| globally queryable analytic height and terrain fitting | 3.1 |
| deterministic overlap/priority and operation plan | 3.2 |
| caves, dungeons, ores, strata and native preservation | 3.3 |
| biome, decoration, water and resource placement | 3.4 |
| per-emerge initialization, memory and hot queries | 3.5 |
| benchmark corpus, interpreter ownership and thresholds | 5 |

The engine facts in `mapgen-control.md` and `luanti-lua.md` remain
authoritative. Horizontal simplification does not relax Lua 5.1 compatibility,
emerge-order independence, native preservation or measured performance.

## 8. Closed R0 supersession table

| Former surface | R0 standing |
|---|---|
| `wp40-source-authority.md` | superseded exact-compiler evidence |
| `wp40-t2-plan.md` | superseded ordering; no live next task or lock |
| `wp40-t2-contracts.md` | superseded package/gate evidence |
| `wp40-acceleration-and-delivery-plan.md` | superseded delivery plan |
| `wp40-puc-final-gate-inventory.md` | superseded PCC/F1/F2 measurement record |
| `tools/wp40/run_t2_puc_core.sh` | historical PCC reproducer only |
| `tools/wp40/run_t2_partition.sh` | historical partition/F1 reproducer only |
| `tools/wp40/run_t2_extreme_conformance.sh` | historical F2 reproducer only |
| `tools/wp40/README.md` | historical exact-T2 harness guide; simple R stages must identify themselves explicitly |
| WP40 clauses in `AGENTS.md`, `wp-workflow.md`, `luanti-lua.md` | replaced by simple-map R1-R8 LuaJIT/targeted-PUC policy |

`wp40-t2-handover.md` is already marked superseded;
`wp40-reality-corrections.md` and
`wp40-t2-degeneracy-completeness.md` are already evidence/analysis records.
They remain readable history without redundant new status labels.

The former stage-S1 six-file lock and winner-seed rule are dissolved. Current
R1-R7 work may deliberately replace those files under ordinary review; no old
branch/worktree merges automatically, and no old pool/winner artifact may be
relabelled as simple-map evidence.
