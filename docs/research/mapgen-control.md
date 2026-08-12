# Map Generation Control Feasibility Study

Status: technical research complete. The game-design inputs that were open
when this study was written were resolved on 2026-08-12 in
`docs/design/world_zones.md` and `TODO-design-housing.md`. The remaining
choices are implementation engineering owned by WP40's mandatory pre-code
brief; this document does not change game-design decisions.

Evidence labels used throughout:

- **Verified fact** means that the statement is directly supported by the
  pinned engine source, the current Grudgelands implementation, or an explicit
  design source. Engine facts cite exact `file:line` ranges.
- **Inference** is a technical conclusion drawn from one or more verified
  facts. It is not an engine guarantee.
- **Recommendation** is the preferred implementation direction for a future
  work package. It is not implemented or decided by this study.
- **Historical open question** identifies information that was unresolved at
  the time of the research. Every such item is resolved or assigned to WP40 in
  the resolution sections below; none is an active owner-design blocker.

The pinned engine checkout examined here is Luanti commit
`df04879066de6eb94ca43996822a6dfacc74feca` (`5.16.0-74-gdf0487906`, described
by the project as 5.17.0-dev). No claim in this document assumes behavior from
an unpinned online version.

## Executive summary

**Verified facts.** Mapgen v7 completes terrain, its heightmap, biomes, caves,
ores, dungeons, decorations, dust, liquids, and lighting in that order. Only
after all of those stages does the mapgen-environment Lua callback run, still
against the engine's live mapgen VoxelManip and before the first map write
(`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:299-381`,
`reference_projects/luanti/src/emerge.cpp:733-755`). The regular/main Lua
`register_on_generated` callback is later: it runs after `finishBlockMake()` has
already blitted the generated data and processed liquids
(`reference_projects/luanti/src/emerge.cpp:588-626`,
`reference_projects/luanti/src/servermap.cpp:275-350`). Generated blocks are
loaded instead of regenerated on later emerge requests
(`reference_projects/luanti/src/emerge.cpp:545-581`).

**Inference.** The most realistic foundation is therefore v7 plus one
authoritative, deterministic mapgen-environment terrain/surface overlay. It can
retain the existing native caves, dungeons, ores, and depth strata wherever it
does not rewrite their nodes, while enforcing the authored continent, ocean,
zone, anchor, Holy Grounds, road, and island geometry before the first map
write. A broad equivalent pass in the main environment would perform a second
map write and consume main-thread time. Full `singlenode` Lua mapgen would give
maximum control but would also require Grudgelands to recreate terrain,
biomes, caves, dungeons, liquids, lighting, and most placement behavior: the
native singlenode implementation merely fills the central chunk with one node
and handles only that node's liquid/light cases
(`reference_projects/luanti/src/mapgen/mapgen_singlenode.cpp:17-69`).

**Recommendation.** Keep native v7 as the underground and relief substrate,
but make a single authored layer authoritative for:

1. the mainland and deep-ocean masks;
2. the exact 38-zone topology and logical `id_at(x, z)` result;
3. bounded, shared-edge boundary displacement and coast displacement;
4. terrain profiles inside capital, start, Holy Grounds, road, channel, and
   future dragon-island envelopes;
5. surface materials, logical biomes, authored vegetation, roads, and large
   structures affected by those profiles.

Native surface decorations that can collide with this overlay should be
disabled or replaced by an authored decoration stage. The engine's
decorations have already used the old v7 heightmap and biomemap before Lua sees
the chunk (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:323-367`,
`reference_projects/luanti/src/mapgen/mg_decoration.cpp:231-251`). The maps
returned to Lua are copies, not writable engine inputs
(`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:606-645`).

**Verified fact.** Native Luanti mapgen deliberately truncates the `u64` world
seed to signed 32 bits for compatibility
(`reference_projects/luanti/src/mapgen/mapgen.cpp:91-113`). `core.get_seed()`
does the same (`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:739-760`).
The only precision-safe Lua access to the entire seed is
`core.get_mapgen_setting("seed")`, which returns the unsigned 64-bit value as a
decimal string and explicitly warns not to convert it to a Lua number
(`reference_projects/luanti/doc/lua_api.md:7104-7116`).

**Inference.** WP40 can guarantee full-seed sensitivity for the authored
geometry, but it cannot make the underlying v7 terrain use the upper 32 seed
bits without an engine change or complete replacement mapgen. The authored
layer should hash the seed string with domain-separated field names and parse
only exact 32-bit hash lanes for `ValueNoise`/`PcgRandom`. This is Lua-5.1-safe
because every intermediate integer stays far below the double precision limit.

**Verified fact.** The engine explicitly says singlenode is currently the only
mapgen unaffected by its unfinished slice bug and enables multiple emerge
threads by default only for singlenode; a normal v7 world therefore defaults
to one emerge thread (`reference_projects/luanti/src/emerge.cpp:180-226`).

**Recommendation.** Specify deterministic output under arbitrary chunk request
order with `num_emerge_threads = 1`. Test multiple threads as a diagnostic, not
as a supported v7 guarantee. If arbitrary emerge parallelism is a hard
acceptance requirement, the recommended v7 architecture and the pinned
engine's own warning are in conflict.

**Resolution (2026-08-12).** The geometry inputs are now binding:
`docs/design/world_zones.md` fixes the Holy Grounds rectangle, both offshore
island centres and envelopes, channel and flight bands, shelf/deep-ocean
classification, separate land and boat graphs, planned-water semantics, and
the ten-zone housing geometry. The feasibility target is therefore exact: all
level 31-60 land zones are contested and editable outside explicit protected
exceptions; Holy Grounds is immutable through y = -700 and ordinary contested
depth begins at y = -701; dragon endpoints are offshore islands behind
immutable full-column channels; and housing claims occupy eligible dry areas
in ten level 11-30 zones rather than housing islands.

## Current implementation baseline

### Verified implementation facts

The running mapgen is an incremental v7 customization, not a complete Lua
mapgen:

- `grug_mapgen/init.lua` raises the v7 base and alternate terrain noise
  offsets and overrides the heat, humidity, and blend fields. The source
  explicitly warns that these overrides make fresh-world seams in existing
  worlds (`mods/MAPGEN/grug_mapgen/init.lua:16-31`,
  `mods/MAPGEN/grug_mapgen/init.lua:55-91`).
- The mod registers its own engine biomes, ores, and decorations, then loads an
  ocean-mask stage and a sparse structure stage
  (`mods/MAPGEN/grug_mapgen/init.lua:1-12`,
  `mods/MAPGEN/grug_mapgen/init.lua:93-102`).
- The current geometry is a pure x/z rectangle-and-noise model shared between
  Lua environments by loading the same `geometry.lua`; the main environment
  publishes the three rectangle constants through IPC and registers
  `ocean_mask_mapgen.lua`
  (`mods/MAPGEN/grug_mapgen/ocean_mask.lua:14-47`).
- `grug_core` still defines each faction landmass as x half-width 1500 with
  |z| = 100..1700, and its six capitals remain at x = -550/0/+550,
  z = -900/+900 (`mods/CORE/grug_core/init.lua:3-27`,
  `mods/CORE/grug_core/init.lua:78-91`). `territory_at` is a rectangle test and
  `zone_at` returns the legacy `strait/war_coast/coast/core/inner/outer`
  vocabulary from radial/band arithmetic
  (`mods/CORE/grug_core/init.lua:990-1051`). These are running-code facts, not
  target coordinates.
- Current protection stores axis-aligned POIs in main-environment mod storage,
  checks their array linearly, then applies rectangle territory/ocean ownership
  in the central `core.is_protected` override
  (`mods/CORE/grug_core/protection.lua:18-103`,
  `mods/CORE/grug_core/protection.lua:135-155`,
  `mods/CORE/grug_core/protection.lua:198-216`). It has no 38-zone, Holy,
  y=-701, deep-ocean subtype, or housing-claim policy yet.
- The ocean carve now runs in a mapgen-environment callback. The accompanying
  comments document that the earlier main-environment version ran after the
  first blit and wrote coastal chunks twice
  (`mods/MAPGEN/grug_mapgen/structures.lua:1-16`).
- Capital platforms, outposts, and bandit camps remain in the main-environment
  callback because their current decision path requires `grug_core`, mod
  storage, persisted POIs, and main-only APIs
  (`mods/MAPGEN/grug_mapgen/structures.lua:11-37`,
  `mods/MAPGEN/grug_mapgen/structures.lua:53-62`). It avoids VoxelManip work on
  chunks without a structure, reuses its data buffer, and writes/liquid-updates/
  relights only affected chunks
  (`mods/MAPGEN/grug_mapgen/structures.lua:847-890`).
- The existing capital-height comments record a real failure mode: a footprint
  median based on the current chunk's clipped heightmap made the decision depend
  on which chunk measured it, and an anchor-surface gate could deadlock at a
  vertical chunk edge (`mods/MAPGEN/grug_mapgen/structures.lua:78-126`).
- The ocean-mask migration LBM necessarily uses a heuristic because generated
  chunks do not run mapgen again. Its own analysis records both false negatives
  and a false-positive class where legal foliage can be cut
  (`mods/MAPGEN/grug_mapgen/ocean_mask.lua:50-62`,
  `mods/MAPGEN/grug_mapgen/ocean_mask.lua:88-178`). This is evidence that a
  post-hoc geometric migration cannot perfectly reconstruct generation intent
  from finished nodes.

The current engine registrations have useful properties worth retaining:

- Biomes supply native surface/filler nodes and engine biomemap integration.
- Ores run in registration order. Grudgelands' horizontal strata are registered
  last, so they convert surviving `default:stone` after other ores and after
  caves, but before dungeons and decorations
  (`mods/MAPGEN/grug_mapgen/ores.lua:13-32`,
  `mods/MAPGEN/grug_mapgen/ores.lua:228-283`). The engine confirms ore
  registration order and `wherein` replacement
  (`reference_projects/luanti/src/mapgen/mg_ore.cpp:31-45`,
  `reference_projects/luanti/src/mapgen/mg_ore.cpp:521-582`).
- The current mapgen-environment pass already uses the correct general
  lifecycle seam for pure chunk voxel work.

### Baseline limitations

**Inference.** The present rectangle/radial model is not a scalable source of
truth for 38 irregular zones and exact adjacency. Engine biome cuboids can
limit candidates, but the final choice is only nearest heat/humidity point
inside each candidate's x/y/z box
(`reference_projects/luanti/src/mapgen/mg_biome.cpp:231-278`). It cannot encode
an arbitrary planar graph, a no-jitter corridor, or exact ownership polygons.

**Inference.** The current split between pure geometry in the mapgen
environment and persistent POI decisions in the main environment is sound in
principle, but persistent *terrain* decisions are too late and create
order/migration complexity. WP40's fixed capital and start anchors should not
need a first-writer-wins storage decision for their terrain. Their target
profiles must be reproducible directly from world seed, anchor ID, and world
coordinates in every intersecting chunk.

**Recommendation.** Treat the existing implementation as a migration source,
not as the WP40 architecture contract. Retain useful registrations and content
IDs, but replace rectangle/radial classification, surface ownership, and
terrain-height decisions together. Do not layer a second 38-zone system on top
of the old radial APIs.

## Verified Luanti mapgen lifecycle

### Native v7 pipeline

**Verified fact.** For each new mapchunk, v7 performs the following sequence:

1. base, mountain, ridge-channel, and optional floatland terrain;
2. a heightmap over the central chunk;
3. biome noise, surface/filler replacement, and the biomemap;
4. noise caves, caverns, and random-walk caves;
5. all registered ores;
6. dungeons;
7. all registered decorations;
8. biome dust;
9. liquid queue discovery;
10. lighting.

The sequence is explicit at
`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:299-381`. The base terrain
uses four 2D noise fields, while mountains add 3D density and ridge "rivers"
are another 2D/3D noise channel rather than authored hydrology
(`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:390-457`,
`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:467-570`).

**Verified fact.** The native heightmap is made immediately after terrain and
records the highest walkable node only inside the supplied central y range
(`reference_projects/luanti/src/mapgen/mapgen.cpp:237-290`). It therefore does
not describe surface edits made later by biomes, decorations, dungeons, or Lua.

**Verified fact.** Biome generation uses the node above the central range,
replaces stone/water with biome top, filler, stone, water, and riverbed nodes,
and records the first detected stone surface in the biomemap
(`reference_projects/luanti/src/mapgen/mapgen.cpp:623-765`). The original biome
generator filters registrations by cuboid bounds and chooses the closest
heat/humidity point, with only vertical blend special handling
(`reference_projects/luanti/src/mapgen/mg_biome.cpp:231-278`).

**Verified fact.** Decorations execute in registration order with an incremented
block seed (`reference_projects/luanti/src/mapgen/mg_decoration.cpp:37-47`).
Ordinary surface decorations use the already computed heightmap and biomemap
(`reference_projects/luanti/src/mapgen/mg_decoration.cpp:231-251`). Schematic
placement clips writes outside the emerged VoxelManip, may use global random
probability calls, and reports whether the complete schematic fitted only
after the clipped blit (`reference_projects/luanti/src/mapgen/mg_schematic.cpp:150-219`).

### Lua callbacks and first write

**Verified fact.** One Lua mapgen environment is initialized per emerge thread.
It loads builtin code, then every registered mapgen script, then its
`on_mods_loaded` callbacks (`reference_projects/luanti/src/emerge.cpp:641-667`).
The C++ registry available in that state includes `AreaStore`, `ValueNoise`,
`ValueNoiseMap`, RNGs, VoxelManip, mapgen/util APIs, and IPC, but does not
register `StorageRef`/the mod-storage API
(`reference_projects/luanti/src/script/scripting_emerge.cpp:57-80`).

**Verified fact.** After v7 `makeChunk`, all mapgen-environment
`register_on_generated` callbacks receive the live mapgen VoxelManip, central
`minp`/`maxp`, and block seed. They run before `finishGen`
(`reference_projects/luanti/src/emerge.cpp:728-755`,
`reference_projects/luanti/src/script/cpp_api/s_mapgen.cpp:33-60`). The API
limits those callbacks to the current chunk data, forbids
`read_from_map()`/`write_to_map()`, and provides no node metadata
(`reference_projects/luanti/doc/lua_api.md:7678-7761`). Builtin `set_node` and
`get_node` in this environment are thin operations on `core.vmanip`, explicitly
without metadata (`reference_projects/luanti/builtin/emerge/env.lua:1-34`).

**Verified fact.** `finishBlockMake()` blits the entire emerged VoxelManip back,
processes its liquid queue, and marks only central blocks generated; one
mapblock of border data on every side is present but is not marked generated
(`reference_projects/luanti/src/servermap.cpp:200-257`,
`reference_projects/luanti/src/servermap.cpp:275-350`). The regular Lua
`register_on_generated` callback then runs in the main/server environment
(`reference_projects/luanti/src/emerge.cpp:588-626`). The API documents that
this main callback is after the map write, blocks the main thread, and is prone
to visible latency (`reference_projects/luanti/doc/lua_api.md:6580-6585`).

**Inference.** A mapgen-environment callback is the only public Lua seam that
can alter v7's completed native output without a second map write. The main
callback remains appropriate for sparse metadata, entities, persisted POI
records, or an LBM handoff, but not for the authoritative continent-wide
surface pass.

### Emerge area, ownership, and order hazards

**Verified fact.** With default `chunksize = 5`, the central mapchunk is
80 nodes along each axis (`reference_projects/luanti/src/defaultsettings.cpp:535-540`).
The engine emerges one additional 16-node mapblock on each side, so the mapgen
VoxelManip is normally 112 nodes per axis, or 1,404,928 voxel entries, although
only the central 80-node cube is the callback's `minp..maxp`
(`reference_projects/luanti/src/servermap.cpp:200-255`).

**Verified fact.** `VoxelManip:get_data(buffer)` copies the *entire* emerged
volume into the Lua table. `set_data` reads the entire table back, changes only
node content IDs (not `param1` or `param2`), and marks the whole volume as
present (`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:92-144`).
The Lua API calls these bulk arrays snapshots, recommends buffer reuse, and
notes that separate content/light/param2 setters update the VoxelManip's
internal state (`reference_projects/luanti/doc/lua_api.md:5422-5453`).

**Inference.** A bulk data table and the VoxelManip are two separate states.
If code calls `place_schematic_on_vmanip`, `set_node_at`, or another direct VM
operation after `get_data` and then calls `set_data` with the old snapshot, the
bulk write can replace the direct operation's content. Because `set_data`
leaves param2 untouched, it can even produce a new content ID paired with the
direct operation's stale param2. This is a write-order bug, not a threading
race.

**Recommendation.** Prefer one buffer-owned content pipeline. If a direct
VoxelManip operation is unavoidable, first commit all buffer edits with
`set_data`, then perform direct operations, never write the old buffer again,
and calculate liquids/lighting only after both stages. Large authored
structures should avoid the mixed model by using their deterministic compiled
voxel slices in the main buffer.

**Inference.** `emax` is a context and overgeneration margin, not safe ownership.
Because `blitBackAll` writes the full emerged area while only central blocks are
marked generated, writing a neighboring x/z shell can overwrite a neighbor's
independently generated result or create order-sensitive precursor data. The
existing ocean-mask shell cleanup is a pragmatic workaround for decorations
that spill beyond `maxp`, but it is not a robust general model for WP40.

**Recommendation.** Every authored feature must use central ownership:

- calculate candidates and read context in a halo as needed;
- write only voxels whose x/z owner lies in the callback's central
  `minp..maxp` (and normally whose y is central as well);
- render the intersecting slice of every global feature into each chunk rather
  than letting the chunk containing its anchor write across the shell;
- define a stable priority between terrain, water, roads, structures, surface
  dressing, and decorations so callback registration order is not an implicit
  conflict rule.

This "pull rendering" rule is essential for roads and structures that cross
chunk boundaries.

### Liquids and lighting

**Verified fact.** v7 calculates lighting before the Lua overlay. The bulk
`set_data` API changes content but leaves old `param1` lighting values in place
(`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:117-144`). If Lua
adds liquids it must call `VoxelManip:update_liquids()` after committing the
buffer to the VoxelManip
(`reference_projects/luanti/doc/lua_api.md:5534-5544`). In the mapgen
environment that operation adds to the current emerge thread's liquid queue;
in the main environment it adds to the server map's global queue
(`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1980-1998`).

**Verified fact.** `calc_lighting` first propagates sunlight over its specified
vertical range, then spreads light across the full emerged VoxelManip
(`reference_projects/luanti/src/mapgen/mapgen.cpp:466-473`,
`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:2001-2016`). Sunlight
is seeded from the row immediately above the requested range. If that row is
known and lacks full sun, propagation stops when `propagate_shadow` is true
(`reference_projects/luanti/src/mapgen/mapgen.cpp:476-507`). Lua validates that
the requested calculation box fits in the emerged area; the default excludes
one vertical mapblock from top and bottom
(`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:208-228`).

**Inference.** A terrain pass that opens a column to the sky cannot assume the
pre-overlay light is valid. A pass that fills a cavity likewise cannot leave
the old light behind. Blindly setting all changed nodes to sunlight or calling
`calc_lighting` with an arbitrary top boundary is also unsafe, because the
sunlight seed-row rule is material.

**Recommendation.** Perform content changes once, call `set_data` once, queue
liquids once if and only if liquid topology changed, and perform one final
lighting correction. The precise lighting range and any explicit sunlight
seeding used by the existing ocean pass should be retained only after tests
prove that opened sky, sealed caves, water columns, chunk tops, and vertical
generation order all converge to the same result.

## Capability matrix

The control levels in this matrix mean:

- **Native parameter control:** v7 can be tuned, but its procedural shape
  remains authoritative.
- **Post-process control:** Lua can replace the result in the mapgen VoxelManip;
  replacement is exact only for voxels it actually writes.
- **Authored control:** a project-owned world-coordinate function can be the
  source of truth, independent of engine climate or chunk request order.

| Concern | Verified engine capability | Realistic control with v7 + overlay | Preservation cost or limitation |
|---|---|---|---|
| Base heights and relief | Four v7 noise fields choose base height; mountain terrain adds a 3D density field (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:390-440`). | Native parameter control globally; exact authored caps, floors, terraces, blends, or height profiles by VoxelManip. | Filling above native terrain creates new solid volume without native caves/ores/dungeons. Lowering removes all native results in the cut volume. Exact preservation is possible only below an explicitly bounded rewrite shell. |
| Land/ocean mask | v7 fills stone below its terrain level, water at/below water level, and air above; it has no arbitrary continent mask (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:524-570`). | Full authored 2D column mask and coastline control, including immutable channels and later island footprints. | A full-depth ocean/channel rule is primarily a runtime protection/classification rule; generation only needs to author the relevant seabed/water volume. Already generated land is not automatically converted. |
| Engine biomes and surfaces | Biomes are cuboid-filtered nearest points in heat/humidity space and replace top/filler/stone/water before caves (`reference_projects/luanti/src/mapgen/mg_biome.cpp:231-278`, `reference_projects/luanti/src/mapgen/mapgen.cpp:623-765`). | Engine biomes remain useful as a first-pass material palette. Exact logical zone biome and final top/filler can be authored after v7. | The native biomemap cannot encode the 38-zone graph and is stale after terrain edits. Returned heightmap/biomemap tables are copies (`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:606-645`). Runtime gameplay must query Grudgelands geometry, not engine biome IDs. |
| Caves and caverns | Native stages run before ores and Lua (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:332-355`). | Preserve all unchanged nodes below the surface rewrite band. Optionally seal caves only inside explicit safe/structure envelopes. | Moving a surface downward can expose or erase caves; raising it does not extend native caves into the added volume. "Preserve caves" cannot be absolute inside rewritten cells. |
| Dungeons | Native dungeons run after ores and before decorations (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:353-363`). Dungeon generation avoids non-ground and existing/ungenerated-neighbor conditions (`reference_projects/luanti/src/mapgen/dungeongen.cpp:64-105`). | Preserve outside explicit authored replacement envelopes. Use generation notifications if later metadata/loot initialization is required. | A surface pass can cut a dungeon that intersects its shell; structures need an explicit conflict rule. Lua cannot ask v7 to regenerate a clipped dungeon elsewhere. |
| Ores and depth strata | All registered ores run in registration order and replace only configured `wherein` nodes (`reference_projects/luanti/src/mapgen/mg_ore.cpp:31-45`, `reference_projects/luanti/src/mapgen/mg_ore.cpp:521-582`). Public `generate_ores` also truncates the map seed to 32 bits (`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1571-1602`). | Keep current native ores and last-registered strata in unchanged rock. For exact race-region or logical-zone deposits, add a project-owned ore pass keyed to authored geometry. | New rock added above v7 contains neither native ore nor the correct stratum unless the overlay fills it through `grug_materials.stratum_node_for(y)` and deliberately adds authored deposits. Re-running all registered ores can double-place or change ordering. |
| Decorations | Native decorations run before Lua, use native heightmap/biomemap, and can place simple or schematic content (`reference_projects/luanti/src/mapgen/mg_decoration.cpp:37-47`, `reference_projects/luanti/src/mapgen/mg_decoration.cpp:231-251`). | Keep only decorations that cannot conflict with surface edits; replace final-surface vegetation and zone dressing with an authored candidate system after terrain. | Moving the ground leaves native trees floating or buried. Calling `core.generate_decorations(..., true)` again still uses the native mapgen biome data and requires exact chunk extents (`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1606-1667`); it is not a way to update that data. |
| Native ridge channels | v7's "rivers" are a threshold over ridge noise near water level (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:444-457`, `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:515-522`). | Accept them as incidental terrain where harmless, or disable/normalize them inside authored envelopes. | They do not connect chosen endpoints, enforce navigability, or model a drainage graph. They are unsuitable as authoritative rivers. |
| Authored rivers and lakes | No high-level API guarantees a connected hydrology network. VoxelManip can carve/fill nodes and queue liquids. | Full authored control from precomputed centerlines/basins and analytic cross sections. | Must solve slope, water levels, intersections, liquid updates, surface dressing, and cave leakage. Incidental v7 lakes inside housing masks otherwise make capacity seed-dependent. |
| Roads | No native road generator. | Full authored control from anchor graph, deterministic routes, cross section, and per-chunk intersection rendering. | Must define slope limits, bridge/tunnel policy, road grading and claim-exclusion envelopes, terrain precedence, and interaction with rivers/structures. |
| Small structures | Decoration schematics and `place_schematic_on_vmanip` are available. | Deterministic fixed placement is practical when the full footprint is inside the emerged VM, or when each chunk renders a deterministic slice. | The API reports `false` if the full schematic does not fit, but the underlying blit has already clipped in-bounds nodes (`reference_projects/luanti/src/mapgen/mg_schematic.cpp:195-219`, `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1775-1824`). Probabilistic schematic nodes use global random calls, so clipped per-chunk invocations are not a safe cross-chunk deterministic renderer (`reference_projects/luanti/src/mapgen/mg_schematic.cpp:150-190`). |
| Large structures and capitals | Lua can write arbitrary nodes in the current VoxelManip. Node metadata is unavailable in mapgen env (`reference_projects/luanti/doc/lua_api.md:7700-7707`, `reference_projects/luanti/doc/lua_api.md:7759-7761`). | Full shape control with a preprocessed, deterministic voxel definition and central-chunk slice rendering; defer metadata/entities via gennotify/LBM. | Whole-schematic placement from one owner chunk is not sufficient for footprints larger than the emerge halo. Terrain target y must be a global analytic decision, not a per-chunk statistic. |
| Runtime territory and housing | `AreaStore` indexes 3D cuboids and point/box intersections, but mods must persist it themselves (`reference_projects/luanti/doc/lua_api.md:8422-8467`). | Exact static polygon query plus AreaStore indices for dynamic cuboidal claims/exclusions. | AreaStore is not a polygon topology engine and is not itself canonical persistence. A static 38-polygon scan in every protection call would also be unnecessarily expensive. |

### Capability conclusions

**Inference.** v7 is highly reusable as a *substrate*, but not as the authority
for the macro map. Global noise parameters can shape the statistical character
of relief; they cannot guarantee the mainland frame, fixed edges, anchors,
topology, channels, or authored routes. Every exact guarantee needs a
project-owned spatial function or a deterministic voxel overlay.

**Inference.** The phrase "preserve v7 caves, dungeons, ores, and strata" is
technically achievable only with a qualified meaning: preserve every existing
node outside the authored replacement volume. It is impossible to both replace
a voxel and preserve the different native result that previously occupied that
same voxel.

**Recommendation.** The WP40 specification should enumerate replacement
volumes by feature and priority. At minimum distinguish:

- surface material replacement only;
- shallow cut/fill shell;
- road and river cross sections;
- capital/start/Holy/structure exclusion envelopes;
- deliberately sealed or cleared safety volumes;
- full authored ocean/island columns near the playable macro map;
- untouched deep substrate.

## Recommended architecture

### Architecture comparison

Scores are relative to this project's constraints, not generic Lua mapgen
ratings. Performance assumes the implementation has a no-op prefilter and
buffer reuse.

| Architecture | Macro control | Complexity | Generation cost | Principal failure modes | Assessment |
|---|---:|---:|---:|---|---|
| v7 plus one Lua/VoxelManip surface pass | High for authored x/z geometry and bounded terrain volumes; native deep generation remains v7 | Medium-high | Medium; one native pipeline plus one bulk Lua read/write on affected chunks | Stale native decorations/maps, cut/fill feature loss, lighting and shell ownership | **Recommended base** |
| Engine biomes/decorations plus authored overlay | High only if the overlay owns final surface; medium if engine results remain authoritative | Medium-high | Medium; native placement is C++-fast, overlay adds Lua cost | Two competing sources of truth; native decorations placed at old heights | **Useful hybrid only with strict stage ownership** |
| Full Lua mapgen on singlenode | Maximum | Very high | High and project-owned; multiple emerge threads become available by default | Reimplement caves, dungeons, hydrology, biomes, ore order, lighting, spawn behavior; large regression surface | **Not justified for WP40** |
| v7 terrain plus authored logical zones, surface, routes, and sparse structures; native underground retained | High where the design demands it, native variability elsewhere | Medium-high | Lowest realistic cost for required guarantees | Interfaces between native and authored layers must be explicit | **Recommended hybrid** |
| v7 plus broad main-environment post-pass | High eventually | Medium | High server impact; second write and main-thread blocking | Visible lag, order with other callbacks, migrations, duplicated liquid/light work | **Reject for continent-wide work** |

### Why the hybrid is preferred

**Verified fact.** Singlenode does not call native biome, cave, ore, dungeon, or
decoration stages; its implementation fills ignore nodes with one registered
node and optionally updates liquid/light (`reference_projects/luanti/src/mapgen/mapgen_singlenode.cpp:31-69`).
The public Lua helpers can invoke all registered ores and decorations, but the
ore helper still uses the truncated 32-bit map seed and neither helper supplies
the missing cave/dungeon/terrain pipeline
(`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1571-1667`).

**Inference.** Full Lua mapgen would replace a large, tested C++ system merely
to gain exact surface geometry that a bounded overlay can already provide. It
also conflicts with the existing decision to retain v7 relief, caves, ores,
dungeons, and strata. Its only decisive technical advantage here is freedom
from v7's native shape and unfinished multithread slice problem.

**Recommendation.** Divide authority as follows:

| Layer | Authority |
|---|---|
| Native v7 | Base relief outside explicit authored profiles; caves, caverns, dungeons, generic ores, and the existing deep substrate |
| Existing Grudgelands ore registration | Global material strata and generic resources in native rock, retaining current registration order |
| Authored geometry kernel | Mainland/ocean/island/channel classification, stable zone ID, adjacency, boundary distance, race region, Holy Grounds, anchor and route data |
| Authored terrain/surface pass | Exact masks, bounded cut/fill, surface/filler repair, authored rivers/lakes/roads, fixed envelopes, logical-biome dressing |
| Main environment | Persistent POI/claim records, node metadata, entities, runtime protection, administration, and sparse post-generation initialization |

This ownership must be one-way. Engine biome IDs may help select an initial
surface, but no gameplay rule may infer zone, faction, level, housing, Holy
Grounds, ocean protection, or deep rights from them.

### Stage order inside the authored callback

**Recommendation.** A future implementation should make one explicit pipeline
for each affected chunk:

1. classify the chunk with cheap 2D spatial-grid and feature-envelope tests;
2. return before `get_data` when the chunk cannot be affected;
3. acquire the mapgen VoxelManip and reuse the content buffer;
4. compute authored column classifications and target profiles for central
   x/z positions;
5. apply terrain cut/fill and ocean/lake/river water;
6. repair top/filler material from the authored logical biome;
7. apply roads, bridge/tunnel decisions, structure terrain pads, and fixed
   structure slices in documented priority order;
8. apply authored decorations from global candidates whose roots or footprints
   intersect this central chunk;
9. write the content buffer to the VoxelManip once;
10. update liquids only when needed and correct lighting once;
11. emit only compact gennotify records needed by the main environment.

**Recommendation.** Avoid invoking `core.generate_decorations` after this
pipeline for final-surface content. Its `use_mapgen_biomes` mode reuses the
native mapgen object and requires the native central extents; there is no API
to replace that biomemap (`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1606-1667`).
Use native decorations only for categories proven independent of authored
surface height, such as carefully bounded cave content, or replace the
registrations with the authored candidate stage.

### Macro-geometry realization

The following feasibility assessment accepts the requested binding frame and
anchors as inputs, not as suggestions:

- mainland frame: x = -2600..+2600, z = -3000..+3000;
- capitals: x = -1800, 0, +1800 and z = -1500/+1500;
- starts: x = -1800, 0, +1800 and z = -2550/+2550;
- Holy Grounds edges: z = -250/+250;
- bounded seed-dependent internal borders and coasts;
- future offshore dragon islands separated from the mainland by immutable
  full-column ocean channels.

**Inference.** All fixed coordinates are safely representable as exact Lua
numbers. Exact frame and Holy z edges should be evaluated before noise. Coast
noise may only move the coast *inward* from a guaranteed outer land frame (or
inside another explicitly defined safe corridor), so no seed can create land
outside the contract or close a required ocean channel. Internal boundary
noise should move one shared edge once; independently perturbing both adjacent
zone polygons risks overlaps, gaps, and topology changes.

**Recommendation.** Represent every ordinary boundary as a canonical directed
edge owned by the lower stable edge ID. Sample a low-frequency, domain-separated
noise displacement along that edge, then clamp amplitude by all of:

- the design's per-edge maximum (ordinary boundary, coast, PvP boundary);
- half the local clearance to every nonincident edge;
- anchor/gate no-jitter envelopes;
- the minimum zone-core and route-corridor width budget;
- a junction taper that reaches zero at fixed graph vertices.

The displaced polyline is then referenced by both incident zones. This makes
adjacency structurally stable instead of something to rediscover from raster
output.

**Recommendation.** Treat capital and start envelopes as terrain constraints,
not as late structures. Each should have an analytic target-height function
defined over its complete blend envelope. A robust pattern is a fixed or
seed-derived anchor plateau height plus a smooth blend to the local v7 surface
sample at each column. Every chunk can evaluate the same value without mod
storage. The current per-chunk median experiment demonstrates why a clipped
heightmap statistic is not robust (`mods/MAPGEN/grug_mapgen/structures.lua:78-126`).

**WP40 engineering resolution.** The design calls anchor heights
terrain-derived. Before implementation, the WP40 engineering brief must freeze
one project-owned analytic derivation from the immutable world seed, anchor ID
and authored macro-relief field. It must be evaluable for the complete
envelope without reading generated nodes, consulting chunk request order or
persisting a first-writer decision. The evaluated height table/function is
shared immutably with every mapgen state. The investigated alternatives were:

1. choose a deterministic fixed height per anchor class and blend v7 into it;
2. implement a project-owned evaluator equivalent to the relevant v7 point
   height and sample a fixed world-coordinate footprint offline/at mapgen-state
   initialization;
3. precompute per-world anchor heights from the seed before any chunk is
   generated and transfer the immutable small table once through IPC.

Option 1 is most robust but does not by itself satisfy the decided
terrain-derived wording. Option 2 or a project-owned seeded macro-relief
equivalent satisfies the contract. Option 3 is acceptable only if the
precomputation itself does not read generated chunks and cannot race with
mapgen thread initialization. A main-environment first-writer decision is
forbidden.

**Recommendation.** Reserve the future dragon-island land masks and full-column
channels in WP40 even if their structures and encounters ship later. Terrain
need not expose unfinished content, but its immutable coordinate/classification
contract must exist before players can generate those chunks.

## Determinism and spatial-data design

### Seed handling without 64-bit loss

**Verified fact.** Lua numbers in this project are doubles, so unsigned 64-bit
seed values cannot generally be represented exactly. The engine documentation
calls the numeric seed from `get_mapgen_params` broken above 2^53-1 and directs
mods to the decimal string from `get_mapgen_setting("seed")`
(`reference_projects/luanti/doc/lua_api.md:7069-7116`). Native mapgen and
`core.get_seed` retain only signed low 32 bits
(`reference_projects/luanti/src/mapgen/mapgen.cpp:100-113`,
`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:739-760`). Builtin
`core.get_value_noise` and `_map` add that truncated `core.get_seed` value
(`reference_projects/luanti/builtin/emerge/env.lua:36-56`).

**Verified fact.** `core.sha256` is present in the async/mapgen utility API and
returns hex by default (`reference_projects/luanti/src/script/lua_api/l_util.cpp:587-602`,
`reference_projects/luanti/doc/lua_api.md:6398-6403`). Direct `ValueNoise`
objects use the supplied noise-parameter seed with an engine seed addend of
zero (`reference_projects/luanti/src/script/lua_api/l_noise.cpp:17-40`), unlike
the builtin `core.get_value_noise` wrapper.

**Recommendation.** The safe seed derivation is:

```text
seed_string = core.get_mapgen_setting("seed")       -- never tonumber()
digest = core.sha256("grug-map-v1\0" .. domain .. "\0" .. seed_string)
lane = exact integer represented by one 8-hex-digit digest slice
signed_lane = lane < 0x80000000 ? lane : lane - 0x100000000
```

Lua 5.1 does not have the ternary operator shown above; it is pseudocode. The
real conversion must use an `if`. Parse at most eight hex digits at a time with
arithmetic or `tonumber(hex, 16)`: every lane is at most 2^32-1 and therefore
exact in a double. Feed distinct signed lanes to direct `ValueNoise`/
`ValueNoiseMap` instances or as `PcgRandom` seed/sequence values. Include a
geometry schema version and a domain name such as `coast`, `edge:<id>`,
`logical-biome`, `road:<id>`, or `decoration:<id>` so adding one random consumer
does not shift unrelated output.

**Inference.** Two worlds whose decimal seeds share the same low 32 bits will
have the same native v7 substrate but different authored geometry if their
full seed strings differ. This is the strongest guarantee available without
replacing v7 or modifying the engine. WP40 must state that scope explicitly.

### Chunk-order independence

**Verified fact.** A mapgen callback can access only the current chunk's
VoxelManip, and IPC incurs serialization-like work on every access
(`reference_projects/luanti/doc/lua_api.md:7700-7707`,
`reference_projects/luanti/doc/lua_api.md:7826-7849`). Previously generated
blocks are returned from memory/disk without generation
(`reference_projects/luanti/src/emerge.cpp:545-581`).

**Recommendation.** All mapgen results must be functions of immutable inputs:

```text
node = F(world-seed-string, geometry-version, world-position,
         fixed authored data, native node snapshot)
```

They must not depend on callback count, prior IPC writes, mod storage, wall
clock, global RNG state, a previously generated neighbor, or which chunk first
encountered an anchor. Read immutable small IPC configuration once when each
mapgen state loads, validate a checksum, then keep it local. Do not perform IPC
lookups inside `id_at` or any per-column loop.

**Recommendation.** Roads, structures, rivers, and decorations must use global
candidates and central-chunk slice rendering:

- derive candidate roots from a world-aligned grid or a fixed feature ID;
- inspect all candidate cells in a halo equal to maximum footprint radius;
- resolve conflicts with a total order `(feature-priority, stable-id)`;
- render only the voxels owned by the current central chunk;
- make every probability decision from the candidate ID and domain seed, not
  from iteration history.

This guarantees the same feature at a chunk boundary even if either side is
generated first.

### Emerge parallelism

**Verified fact.** The engine creates one mapgen object and Lua state per emerge
thread (`reference_projects/luanti/src/emerge.cpp:190-197`,
`reference_projects/luanti/src/emerge.cpp:641-667`). It enables multiple
threads by default only for singlenode because singlenode is the only mapgen
not affected by the unfinished slice bug
(`reference_projects/luanti/src/emerge.cpp:180-188`). Automatic thread
selection otherwise bottoms out at one and caps its auto-selected value at
four, with a conservative 1 GB RAM estimate per thread
(`reference_projects/luanti/src/emerge.cpp:200-226`).

**Inference.** Project-owned pure Lua can be made thread-safe, but WP40 cannot
truthfully promise that the complete v7 result is independent of arbitrary
parallel emerge scheduling when the pinned engine states the opposite for its
own native slice generation.

**Recommendation.** Make one emerge thread part of the supported production
world-generation profile. An audit with two and four explicit threads is still
valuable: differences should be recorded and localized, and no authored-layer
race is acceptable. A future engine update can relax the production constraint
only after the engine issue and the full regression corpus are reverified.

### Static zone topology and `id_at(x, z)`

**Recommendation.** Store the 38-zone definition in four related forms generated
from one authored source:

1. a stable registry indexed by numeric ID and canonical string ID, containing
   faction/race region, level band, logical biome palette, and policy flags;
2. an explicit symmetric adjacency set, with edge IDs and edge type (land,
   Holy boundary, coast, channel/boat connection if applicable);
3. canonical vertices and shared boundary polylines, each displaced once;
4. a spatial acceleration grid.

A suitable acceleration grid uses fixed world-aligned cells, approximately
128x128 nodes:

- a homogeneous cell stores one direct zone/ocean ID;
- a boundary cell stores only candidate polygon/edge IDs and their bounding
  boxes;
- `id_at` first indexes the cell in O(1), then performs exact half-open
  point-in-polygon/side-of-polyline tests only for that short candidate list;
- a deterministic boundary tie rule, such as the lower canonical zone ID owning
  points exactly on an ordinary shared edge, prevents disagreement between
  mapgen and runtime.

**Inference.** Scanning 38 polygons per surface column would probably be
acceptable during rare offline checks but is unnecessary in mapgen and too
costly for hot protection/mob/mount queries. AreaStore is not the replacement:
it indexes inclusive cuboids and intersections, not arbitrary shared polygons
(`reference_projects/luanti/doc/lua_api.md:8422-8467`).

**Recommendation.** Use integer or fixed-point boundary samples wherever
possible. Floating-point noise may generate the samples, but commit the
resulting polyline vertices to deterministic integer/fixed-point coordinates
before topology tests. Keep all coordinate products below Lua's exact integer
range and avoid implicit dependence on table iteration order.

### Logical biomes and coherent boundary variation

**Recommendation.** Logical biome selection should be a second project-owned
field inside each zone, not the engine's biomemap. Use low-frequency patch
noise and zone palette weights, then apply a border blend only within a bounded
distance of a shared edge. Derive the decision from world coordinates and a
domain seed so it is coherent across chunks. Do not make a per-node random
choice that creates salt-and-pepper surfaces.

The offline audit should measure each zone's area reassignment and enforce the
design budget (currently approximately plus/minus five percent). Because the
zone topology is evaluated first, logical-biome noise can never change zone
identity or adjacency.

### Runtime 3D territory rules

**Recommendation.** Keep horizontal classification and vertical policy
separate. A policy query should first classify x/z, then apply precedence in a
documented order. Against the newer TODO model, the feasibility ordering is:

1. deep ocean or an immutable dragon channel: immutable for every y;
2. any non-deep-ocean column at y <= -701: universal contested/editable;
3. Holy Grounds polygon at y >= -700: immutable;
4. explicit POI, road, capital/start, and structure envelopes at their defined
   vertical ranges: immutable or rule-specific;
5. an active housing claim: owner/trust/depth rule, subject to its y limits;
6. level 31-60 land: contested/editable outside the protected exceptions;
7. level 1-30 land: faction-territory protection outside owner permissions and
   explicit exceptions.

`race_region_at(x, z)` should be an independent x/z projection used for
cultural content and deep spawns. It must not grant territory ownership. The
projection continues below the surface until an explicit ocean/channel rule
takes precedence.

**Resolution (2026-08-12).** `world_zones.md` §§7.2-7.3 fixes the required
classes and precedence: planned land-zone water, the exact exterior 80-node
`coastal_shelf`, `deep_ocean`, and overriding
`immutable_dragon_channel` masks. Planned water is never deep ocean; only deep
ocean and dragon channels are full-column immutable.

### Housing masks and dynamic claims

**Recommendation.** Separate static eligibility from dynamic ownership:

- Static: zone membership in the ten approved level 11-30 zones, water/coast
  mask, fixed boundary clearance, road/POI/anchor/structure exclusion
  envelopes, terrain/slope rules, and y placement rule.
- Dynamic reservation: exact future 101x101 x/z footprint plus the required
  gap, independent of the currently purchased build tier.
- Dynamic active claim: the current tier's 3D cube, using the same x/y/z
  radius around the Claim Stone.

Use a main-environment AreaStore for active 3D claims, a second AreaStore with
degenerate y=0 cuboids for 2D reservation projections, and a third for dynamic
exclusions if they exist. Maintain canonical serialized records in mod storage;
the engine explicitly states that AreaStore does not persist itself
(`reference_projects/luanti/doc/lua_api.md:8425-8430`).

**Recommendation.** Precompute a center-eligibility mask that is already eroded
by the full future footprint radius and every static exclusion. A compact
run-length raster, bitset, distance field, or grid of homogeneous/candidate
cells is more appropriate than testing the complete 101x101 footprint node by
node for every UI hover. On actual placement, always run the exact polygon,
terrain, node-water, and AreaStore intersection validation before committing.

**Inference.** Housing capacity is not derivable from gross zone area. It
depends on eroded masks, road and POI envelopes, water, slope, gap rules, and
packing fragmentation. The required 32-seed simulated-placement audit is the
correct feasibility gate.

### Mapgen versus runtime data requirements

| Data/function | Mapgen requirement | Runtime requirement |
|---|---|---|
| 38-zone registry and adjacency | Immutable, compact, loadable in every emerge Lua state; drives surfaces/resources/candidates. | Same IDs and semantics for UI, PvP, mobs, quests, protection, and diagnostics. |
| `id_at(x,z)`, race region, boundary distance | Allocation-free inner loops over up to 6,400 surface columns per default chunk; no IPC per query. | Allocation-free hot point query for dig/place/mount/mob checks; same half-open tie rule. |
| Seed-derived edges/coasts/logical biomes | Construct once per mapgen state from the exact seed string or load one checksummed immutable snapshot. | Construct/load once on main initialization; never infer from generated nodes. |
| POI/road/structure anchors | Fixed geometry and exclusion envelopes known before player claims; render central slices. | Public queries keep hard-protection volumes separate from road/camp claim exclusions; persistent functional metadata lives here. |
| Housing eligibility | Static authored mask only; mapgen may use it to reserve terrain quality and avoid conflicting decorations. | Static mask plus final-node validation, dynamic reservation and active-claim AreaStores, canonical mod-storage records. |
| Territory/depth policy | Needed only where generation/resource placement depends on the policy; no player identity or mod storage. | Full precedence with player faction/ACL, y=-701, Holy, ocean, hard-protected anchors, mutable road exclusions, and claim rules. |
| Debug/export data | Optional counters and compact gennotify; no file writes in hot callbacks. | Admin diagnostics; offline tooling produces heavy images/reports. |

**Recommendation.** Share one pure geometry module and one generated immutable
dataset between the environments, but keep mapgen adapters and runtime adapters
separate. This avoids calling unavailable main APIs in mapgen while preventing
two independently reimplemented classifiers.

## Terrain/structure generation details

### Surface and terrain pass contract

**Recommendation.** Define the terrain pass as a set of column operations,
each with an explicit lower and upper y bound, rather than as "replace the
surface." For each central x/z column the pass should derive:

- spatial class: land zone, coastal shelf, deep ocean, dragon channel, or
  authored inland water;
- native surface estimate and exact current top scan bounds;
- authored target surface and maximum cut/fill distance;
- logical biome and top/filler palette;
- intersecting fixed envelopes, route cross sections, and structure volumes;
- the lowest y the pass is authorized to change.

Use the native heightmap as a cheap initial estimate only. It was computed
before biomes, caves, dungeons, decorations, and Lua, and is vertically clamped
to the central chunk (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:320-364`,
`reference_projects/luanti/src/mapgen/mapgen.cpp:237-290`). If the algorithm
needs the final current top, scan the VoxelManip content within a bounded band
and classify nodes by an explicit replaceable-content set.

**Recommendation.** Make the ordinary surface rewrite band shallow and
design-owned. Its exact thickness is an open WP40 parameter, but its semantics
must be:

- no write below the band unless a named feature (ocean, river, road cut,
  structure foundation, safety clearance) owns a deeper envelope;
- fill new natural rock using `grug_materials.stratum_node_for(y)` rather than
  always using `default:stone`;
- replace only known natural terrain/surface/vegetation content in ordinary
  blending, preserving dungeon/structure/foreign nodes;
- allow deliberate force replacement only inside explicitly protected authored
  structure or channel volumes;
- never use a content-name heuristic at runtime to reconstruct whether an old
  generated column was meant to be cut. The current healing LBM demonstrates
  that such inference has unavoidable ambiguous cases
  (`mods/MAPGEN/grug_mapgen/ocean_mask.lua:88-178`).

**Inference.** A shallow shell preserves native underground results below its
floor byte-for-byte. It does not preserve features that intersect the shell,
and it cannot cause caves, ores, or dungeons to appear inside newly added
terrain. Where a capital plateau adds a large volume, the choices are to accept
solid authored fill, add an authored cave/ore rule for that volume, or cap the
maximum upward adjustment. Re-running all native ore registrations after fill
is unsafe because it can process existing rock a second time and does not
recreate caves or dungeons.

### Land, coast, ocean, and immutable channels

**Recommendation.** Define two separate products from one coast geometry:

1. a generation mask with target seabed/shelf and water-column profiles;
2. a runtime policy mask with `land`, editable shelf, deep ocean, and immutable
   channel classifications valid at every y.

The outer mainland guarantee should be constructive. Start with the fixed
x/z frame, reserve the Holy Grounds connections and island channels, then
permit coast noise only inside a finite coast band. Clamp the displacement so
that it cannot:

- move outside x = -2600..+2600 or z = -3000..+3000;
- remove an anchor or its complete no-jitter/blend envelope;
- break a required land connection or reduce it below its minimum width;
- close or narrow an immutable ocean channel below its certified width;
- create an unplanned island or land bridge.

**Inference.** An unbounded noise threshold followed by a 32-seed visual check
is not a proof of these properties. The property should follow from amplitude
clamps and reserved corridors; the 32-seed audit then verifies the
implementation of the proof conditions.

**Recommendation.** Treat deep-ocean/channel immutability as analytic runtime
classification, not as a vertical stack of protected areas. A single x/z
predicate followed by y precedence is faster and cannot leave vertical gaps.
The generation pass may stop below its authored seabed, while protection still
classifies the same column as immutable at y = -31000. This is essential for
the no-tunnel/no-bridge/no-seabed-mine rule.

### Holy Grounds

**Verified design input.** The material-progression model fixes the
north/south edges at z = -250 and z = +250, makes Holy Grounds authored land,
protects it through y = -700 inclusive, and reopens ordinary contested depth at
y = -701 (`TODO-design-material-progression.md:424-443`). The completed map
plan fixes the west/east extent at x = -2500..+2500
(`docs/design/world_zones.md` §7.1).

**Recommendation.** Encode Holy Grounds as a stable polygon with the two fixed
z edges and separately authored west/east coast transitions. Do not derive it
from the level of its neighboring zones or from a noisy shared-front label.
The terrain pass should reserve its complete land connections before applying
coast noise. Runtime policy should test the Holy polygon only after the
full-column deep-ocean/channel exception and the y <= -701 deep override.

**Resolution (2026-08-12).** `world_zones.md` §§7.1 and 9.3 fix the Holy
Grounds rectangle at x = -2500..+2500 and z = -250..+250, its internal
junctions, coast closure, land graph, six north/south crossings and paired
island boat routes. WP40 must consume that registry rather than infer another
shape from level labels or generated coast nodes.

### Caves, dungeons, ores, and depth layers

**Verified fact.** Native cave generation precedes ores, while dungeons follow
ores (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:332-363`). Native
biome generation precedes both and its biomemap can filter cave and ore
behavior. Ores receive the native `mg->biomemap` and native signed-32-bit map
seed (`reference_projects/luanti/src/mapgen/mg_ore.cpp:82-96`).

**Inference.** If future G1/G2 cultural resources must follow the authored
`race_region_at(x, z)` projection exactly at depth, engine biome-filtered ore
registrations are the wrong authority. Engine biomes may differ from logical
zones and cannot express the exact race polygons. Those resources need a
project-owned ore placement pass, or their registration must use broad
`wherein`/depth rules followed by authored filtering that does not double-roll.

**Recommendation.** Preserve the current native generic ore and stratum order,
then add only exact-geometry resource categories in a deterministic authored
stage. Each candidate should be derived from world-aligned 3D cells and a
domain seed; test host-node and depth/race policy before replacement. This
avoids a scan of every rock node for most chunks and avoids using logical zone
IDs as native biome names.

**Recommendation.** Establish explicit conflict priorities:

```text
immutable authored structure/channel shell
  > authored structure interior and road/river engineering
  > native dungeon/foreign structure preservation outside those envelopes
  > authored exact-region resource
  > existing generic ore/stratum node
  > ordinary terrain/surface dressing
```

This is an implementation recommendation, not a design change. The exact
resource-versus-dungeon rule remains an open content decision.

### Rivers and lakes

**Inference.** v7 ridge channels can remain as incidental gullies only where
the design accepts them. They cannot satisfy fixed road crossings, navigable
routes, inland-lake locations, or guaranteed connection. An authored river is
a structure-like feature with a centerline, bed profile, width, bank blend,
water level, and conflict priority.

**Recommendation.** Author hydrology at macro scale before chunk generation:

- fixed source/mouth/basin IDs and a connected graph;
- integer/fixed-point centerline samples in world coordinates;
- monotonically non-rising downstream bed/water levels where continuous water
  is required;
- deterministic width and bank cross sections;
- reserved bridge/ford interfaces with roads;
- a terrain modification envelope and an exclusion envelope for housing/POIs.

Each chunk renders all segment/basin slices intersecting its central area. Do
not run an A* or downstream flood search limited to the current chunk. If a
seed-dependent route solver is used, compute the whole graph from the global
authored height field once per world/mapgen state and require a stable
tie-breaking order.

**WP40 engineering resolution.** Only registered planned-water and landmark
masks may survive as surface water inside the authored mainland and islands.
The authoritative surface pass normalizes incidental v7 surface water outside
those masks; native underground liquids remain governed by the separately
frozen rewrite-shell contract. This keeps housing eligibility and the 32-seed
capacity audit functions of authored geometry rather than chunk-local v7
accidents.

### Roads

**Recommendation.** Represent roads as stable route IDs connecting fixed POI
and gate anchors, with a seed-independent topology and bounded seed-dependent
shape inside reserved corridors. Route geometry should include:

- centerline and cumulative distance;
- paved/shoulder/terrain-blend widths;
- maximum grade and cross-slope;
- bridge, ford, tunnel, and switchback markers;
- shallow protection/exclusion envelope through its decided y floor;
- a total priority against rivers, structures, and ordinary terrain.

`road_distance_at(x, z)` and `road_id_at(x, z)` should share the spatial grid
used by zone boundaries. Housing eligibility should use the final road
exclusion envelope, not a separately approximated centerline buffer.

**Inference.** Roads can be fully chunk-order independent when each segment is
defined globally and terrain is forced to its analytic cross section. A road
whose path is selected from whatever neighboring chunks have already generated
cannot be.

### Capitals, starts, POIs, and structures

**Recommendation.** The six fixed capitals and six fixed starts require three
separate envelopes:

1. an inner footprint where terrain and structure placement are exact;
2. a terrain blend envelope that guarantees approachability and grade;
3. a no-jitter/exclusion envelope that constrains zone edges, coasts, roads,
   waterways, decorations, and housing.

All three must be in the static geometry source. The requested x/z anchors are
not sufficient on their own to guarantee a usable structure site.

**Recommendation.** Large structures should be compiled into deterministic
voxel records split by world-aligned owner chunk or queried by footprint
intersection. A structure ID determines rotation, palette, and optional node
variants. Per-node probability should be resolved once from `(structure ID,
local coordinate)` rather than by calling a clipped schematic independently in
each chunk. Only the central chunk's slice is written.

The mapgen environment should emit compact gennotify records for metadata or
entity initialization. The engine explicitly offers custom gennotify to carry
serialized data from mapgen to the main environment, and lists dungeon/cave/
decoration notifications as well (`reference_projects/luanti/doc/lua_api.md:5775-5805`,
`reference_projects/luanti/doc/lua_api.md:7711-7720`). The main environment can
then set metadata or register the persistent POI without rewriting terrain.
LBMs remain appropriate for idempotent initialization when the receiving block
loads.

**Resolution (2026-08-12).** The shallow layer ends uniformly at y = -700;
y = -701 and below is universally contested and editable on every non-ocean
land column. WP40 must compile hard-protected capitals, functional anchors and
irreplaceable route structures with their authored x/z envelopes and this
common deep floor. Ordinary roads, camp shells and replaceable bridges instead
have 2D claim-exclusion/grading envelopes and remain mutable. Full-column deep
ocean and dragon channels remain the only water precedence exceptions.

### Decorations after an authored surface

**Recommendation.** Split decorations into categories:

- **native subsurface-safe:** cave decorations whose inputs and y ranges cannot
  be invalidated by the surface pass;
- **authored surface:** trees, plants, boulders, ruins, and water-edge dressing
  placed after final terrain from logical zone/biome data;
- **fixed structures:** POIs and reserved set pieces with explicit IDs and
  envelopes;
- **deferred runtime content:** nodes needing metadata/entities initialized by
  gennotify/LBM.

For authored surface decoration, use world-aligned candidate cells with halo
queries and stable conflict ordering. Candidate validity must test the final
VoxelManip surface and the static exclusion masks. This removes floating-tree
cleanup and prevents native decorations from occupying road or capital volume.

### `emax`, write ordering, and vertical slices

**Verified fact.** The engine's emerged box includes neighboring blocks and
`blitBackAll` writes it, but border blocks remain ungenerated
(`reference_projects/luanti/src/servermap.cpp:213-255`,
`reference_projects/luanti/src/servermap.cpp:287-350`). A mapgen VoxelManip
cannot `read_from_map` or `write_to_map` explicitly in the mapgen environment
(`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:35-55`,
`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:147-168`).

**Recommendation.** Apply these ownership rules:

- `minp..maxp` is the only normal write ownership box;
- `emin..emax` may be read for light, surface context, and feature-footprint
  validation;
- no x/z shell cleanup; remove the source of post-overlay native surface spill
  instead;
- vertical features render the slice owned by the current y chunk from the same
  analytic definition;
- never persist a height because one vertical slice happened to see a usable
  heightmap first;
- compare complete content/param2/light hashes under ascending, descending, and
  randomized vertical chunk generation.

**Inference.** There may be narrow cases where a lighting seed or engine
overgeneration node in the vertical shell must be adjusted. Such a write must
be isolated, justified by the lighting algorithm, and tested separately; it
must not become general permission to render neighboring terrain.

## Performance model

### Work per generated mapchunk

At default `chunksize = 5`, one surface mapchunk has 80x80 = 6,400 central
columns and 80^3 = 512,000 central nodes. The emerged VoxelManip normally has
112^3 = 1,404,928 entries because of the one-mapblock border. The dimensions
follow directly from the engine default and emerge construction
(`reference_projects/luanti/src/defaultsettings.cpp:535-540`,
`reference_projects/luanti/src/servermap.cpp:200-255`).

One default mapchunk contains 5x5x5 = 125 central MapBlocks. Generation and the
Lua callback operate on that mapchunk unit, so a measured callback cost can be
reported as `time / 125` for an amortized per-MapBlock number, but it cannot be
scheduled or optimized as 125 independent callback invocations.

**Verified fact.** Each bulk `get_data` and `set_data` loops over that entire
1.4-million-entry emerged volume, not only the central chunk or changed nodes
(`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:92-144`). The
current structure implementation notes that a fresh Lua table is approximately
11 MB and therefore reuses one buffer (`mods/MAPGEN/grug_mapgen/structures.lua:60-62`,
`mods/MAPGEN/grug_mapgen/structures.lua:854-857`).

**Inference.** The dominant Lua costs on an affected chunk are likely:

1. C++ to Lua copying of the full content array;
2. Lua to C++ copying of the full array;
3. per-column classification and bounded vertical scans/writes;
4. lighting over a large emerged volume;
5. liquid discovery when water topology changes.

The zone lookup itself should be small if it uses a spatial grid. Multiple
independent VoxelManip passes would repeat the two largest copying costs and
increase garbage pressure.

**Recommendation.** Use these fast paths and counters:

- classify x/z chunk overlap and y band before fetching a VoxelManip buffer;
- return immediately for deep chunks with no exact-region ore work;
- do not assume remote surface ocean can skip the mask unless an explicit
  finite world-generation boundary makes native out-of-frame land irrelevant;
- reuse per-mapgen-state arrays for voxel data, 2D noise, zone IDs, heights,
  candidates, and modified-column flags;
- combine terrain, surface, road, structure, and authored decoration writes
  into one content-buffer transaction;
- skip `set_data`, liquid update, and lighting if no voxel changed;
- count classified columns, scanned voxels, modified voxels, liquid-changing
  voxels, candidates considered/accepted, and lighting calls in benchmark mode.

For very sparse one-node initialization, direct `set_node_at` may beat a bulk
copy; the API itself warns VoxelManip is not necessarily faster for small
changes (`reference_projects/luanti/doc/lua_api.md:5381-5402`). Profile rather
than forcing every sparse operation through the large buffer.

### Emerge thread versus main thread

**Verified fact.** Native generation and mapgen-environment Lua execute in the
emerge thread before finish; regular `register_on_generated` runs later while
`finishGen` holds the server environment lock
(`reference_projects/luanti/src/emerge.cpp:588-626`,
`reference_projects/luanti/src/emerge.cpp:728-755`). The API warns the latter
blocks the main thread (`reference_projects/luanti/doc/lua_api.md:6580-6585`).

**Recommendation.** Put all broad, pure voxel and geometry work in the mapgen
environment. Keep main-environment generation work proportional to the number
of actual fixed POIs/metadata records in a chunk and perform no second broad
terrain write. Runtime protection uses prebuilt indices and pure classifiers;
it must never invoke a mapgen scan or IPC.

### Scaling to 100 players

**Inference.** Mapgen cost scales with newly explored chunks, not directly with
connected-player count. One hundred players nevertheless increase the chance
of simultaneous exploration fronts, so a single v7 emerge thread can become a
throughput bottleneck while main-thread postprocessing would become a latency
bottleneck. Increasing v7 emerge threads is not a supported shortcut because
of the engine's unfinished slice warning.

**Recommendation.** Capacity planning should use an adversarial exploration
trace, not only single-player walking:

- 100 simulated/requesting players split across multiple new frontiers;
- high-speed ground and flight envelopes consistent with mounts;
- teleport arrivals at opposite fixed anchors;
- a cold-cache generation burst followed by steady exploration;
- concurrent ordinary server load, measuring main-step p95/p99 as well as
  chunk throughput and emerge queue depth.

The mapgen itself should have a per-chunk budget derived from the required
world-generation throughput, not an assumed percentage of a 100-player server
tick. Establish the number only after benchmarks on the target host.

### Work to perform offline or once per world

**Recommendation.** Move the following out of per-chunk hot paths:

- validation and compilation of the 38-zone topology;
- shared-edge sampling rules, spatial-grid construction, polygon bounding
  boxes, and adjacency symmetry checks;
- road/river graph topology and fixed control corridors;
- structure schematic conversion to deterministic voxel slices and footprint
  indices;
- static exclusion-envelope unions and housing-footprint erosion;
- 32-seed geometry, route, coast, and capacity audits;
- PNG/SVG/CSV debug exports and aggregate area statistics.

Seed-dependent derived geometry can be computed once per mapgen Lua state or
transferred once as an immutable checked data set. Avoid transferring a large
table through IPC repeatedly because every IPC access performs serialization-
like work (`reference_projects/luanti/doc/lua_api.md:7833-7849`).

**WP40 measurement.** The pre-code engineering brief chooses either per-state
construction or one immutable transfer, and the WP40 benchmark corpus records
initialization latency, serialized/allocated size and steady-state chunk cost
for that choice. Production remains constrained to one v7 emerge thread; a
future multithread architecture requires a separate re-evaluation.

## Migration and fresh-world constraints

### What the engine regenerates

**Verified fact.** Emerge first accepts a block already marked generated in
memory or on disk and starts map generation only if no generated block is
available (`reference_projects/luanti/src/emerge.cpp:545-581`). During
`finishBlockMake`, only the central blocks are marked generated; the shell is
not (`reference_projects/luanti/src/servermap.cpp:325-350`).

**Inference.** Changing geometry code affects only newly generated blocks.
There is no automatic reconciliation of an old rectangle coast, radial zone,
road, anchor platform, ocean classification, or native decoration with the new
38-zone result. New chunks next to old chunks will form seams. Runtime
`id_at(x,z)` will immediately apply the new logical policy even where old nodes
still embody the old terrain, producing an additional node/policy mismatch.

**Recommendation.** WP40 must be fresh-world-only. A supported world should
store an immutable map-geometry manifest in main-environment mod storage,
including at least:

- full seed string hash (not a numeric seed);
- geometry schema/version;
- authored data checksum;
- engine pin and critical mapgen settings/chunksize;
- zone/road/structure dataset versions;
- production emerge-thread setting.

On startup, a mismatch should fail loudly or put the world into an explicit
administrative migration mode; it must not silently generate new geometry next
to old blocks. The mapgen environment reads immutable manifest-equivalent
configuration from packaged files or one IPC snapshot, since mod storage is not
registered there (`reference_projects/luanti/src/script/scripting_emerge.cpp:57-80`).

### Why an LBM is not a geometry migration

**Inference.** An LBM can initialize or make an idempotent local repair when a
block loads. It cannot recover the original pre-overlay v7 heightmap, know
which player edits are intentional, reconstruct a global road across unloaded
chunks, or safely distinguish native, authored, and player-placed nodes. The
current coast-healing LBM's documented false-positive and false-negative
classes are a concrete example
(`mods/MAPGEN/grug_mapgen/ocean_mask.lua:88-178`).

**Recommendation.** Do not propose an LBM that reshapes existing worlds to the
WP40 map. Realistic alternatives are:

1. require a new world (recommended);
2. provide a one-off offline database transformation with backups, player-edit
   exclusion records, and a full visual/hash audit (much higher cost and still
   risky);
3. retain old geometry forever for that world and start the new rules only on
   a new server/world.

### Future dragon islands

**Inference.** "Add the islands later" is safe only for structures/entities on
terrain whose geometry WP40 already generated. If island land or its channel
mask is introduced after nearby chunks have been explored, those generated
chunks will not rerun mapgen and the island/channel can be partial or absent.

**Resolution.** WP40 fixes and generates both decided island terrain
envelopes, immutable channels, warning/hard travel masks, equivalent boat
approaches and zone IDs. Later WPs may populate them; introducing different
island terrain after WP40 would require an explicit new fresh-world boundary.

### Rollout gate

**Recommendation.** Before a production world is created:

- freeze the geometry data and its checksum;
- run the complete 32-seed audit and choose/record the production seed;
- run deterministic order and performance tests using production settings;
- export and review all logical map layers for that seed;
- generate a disposable full macro-map world and inspect anchors, routes,
  coasts, Holy Grounds, channels, housing capacity, caves, strata, liquids, and
  lighting;
- only then create the persistent world.

After production generation starts, changes to geometry, noise derivation,
mapgen registrations, chunksize, or v7 flags are world-format changes even if
Lua APIs remain compatible.

## Automated and runtime test strategy

### Test layers

**Recommendation.** Use four complementary test layers:

1. pure geometry/property tests without Luanti;
2. offline raster/vector export and graph analysis;
3. headless Luanti generation and database/hash inspection;
4. GUI/runtime exploration and administrative diagnostics.

Pure tests are the fast gate; engine tests prove lifecycle behavior; visual
tests catch terrain quality that a topology assertion cannot.

### 32-seed geometry audit

The seed corpus should be fixed in the repository and include:

- ordinary short decimal seeds;
- 0, 1, and the maximum unsigned 64-bit decimal seed;
- values around 2^31, 2^32, and 2^53;
- at least four pairs with identical low 32 bits but different upper bits;
- seeds chosen to exercise extreme positive/negative coast and edge noise;
- the intended production seed once selected.

**Recommendation.** For every seed assert:

- exactly 38 stable zone IDs, no duplicate/missing registry entry;
- explicit adjacency is symmetric and exactly matches the revised graph;
- displaced polygons have no gaps, overlaps, self-intersections, or accidental
  point/edge contacts;
- ordinary edge displacement, coast displacement, PvP-edge displacement, and
  wavelength remain inside their budgets;
- each zone retains its required core and every required corridor meets minimum
  width;
- every capital/start anchor and complete reserved envelope remains land,
  inside the intended stable zone, and inside its no-jitter clearance;
- capital/start coordinates are exact, not nearest sampled approximations;
- Holy north/south boundaries remain exactly z = -250/+250;
- logical biome shares stay inside their per-zone tolerance;
- upper seed bits change authored fields for same-low-32 seed pairs while the
  test records that native v7 may remain the same.

### Adjacency, route, and coast continuity

**Recommendation.** Raster tests alone are insufficient for exact adjacency.
Validate the canonical shared-edge graph before rasterization, then validate
the raster as a second view. For every road, river, coast, and channel:

- trace connected components and require the expected endpoint component;
- sample every intersection with an 80-node chunk boundary and compare both
  neighboring chunk evaluations;
- assert road width, shoulder, exclusion width, grade, cross-slope, and
  bridge/ford/tunnel markers;
- assert coast is a closed, non-self-intersecting boundary;
- assert each dragon channel is connected to deep ocean, contains no land
  bridge, meets minimum navigable width, and remains separate from incidental
  inland water;
- assert both faction boat-route lengths/access budgets are within the decided
  equivalence tolerance.

### Holy Grounds, ocean, depth, and territory

Build a table-driven policy oracle. At boundary points, polygon interiors,
anchors, claims, roads, POIs, coastal shelf, deep ocean, and channels, test y
values around every transition, including at least surface, -50, -699, -700,
-701, -702, and depth-band boundaries.

Against the newer model, required assertions include:

- Holy Grounds immutable at y >= -700 and contested/editable at y <= -701;
- ordinary land capital/POI/road/faction restrictions cannot survive the deep
  y <= -701 override;
- deep ocean and immutable dragon channels deny editing at every tested y;
- level 31-60 ordinary terrain is contested/editable outside protected
  envelopes;
- level 1-30 faction ownership remains effective through y = -700;
- race-region projection remains stable with depth and never grants edit
  ownership;
- housing claims and reservations never privatize y <= -701.

### Housing feasibility and packing

For each of the 32 seeds:

- construct the exact static housing mask in all ten eligible zones;
- erode it by the full radius-50 future footprint and all boundary/road/POI/
  water/terrain exclusions;
- verify every accepted center's complete 101x101 footprint;
- run deterministic best-case, worst-case, random, edge-biased, and
  road-biased placement sequences with the ten-node gap;
- report capacity per zone, race, faction, fragmentation, and rejection cause;
- require the decided capacity target under an explicitly chosen placement
  model rather than claiming capacity from total area.

Runtime claim tests must additionally exercise simultaneous placement attempts,
reservation versus active-cube intersections, expansion, ACL changes,
abandonment/recovery, restart/reload of canonical mod-storage records, and
AreaStore reconstruction.

### Chunk-order and cross-boundary determinism

Generate the same bounded region in at least these request orders:

- x/z row-major and reverse row-major;
- random order with a fixed test seed;
- anchor-containing chunks first and last;
- vertical slices bottom-up, top-down, and randomized;
- both sides of each road/river/structure boundary first;
- sparse teleport-like requests separated by unloaded gaps, then fill gaps.

Compare central mapblock hashes of content ID, param2, and both light banks.
Exclude database timestamps and other non-map content. Any content or param2
difference is a failure. A light difference is also a failure unless the test
first proves that an engine liquid/light settling phase intentionally converges
it; in that case compare again after a fixed convergence procedure.

Run the authoritative suite with one emerge thread. Also run two/four-thread
diagnostics and attribute differences to native v7 versus authored output. Do
not weaken authored determinism because native v7 has a documented engine bug.

### Terrain preservation tests

Instrument representative chunks and compare native-v7 snapshots to final
output:

- all nodes below the declared ordinary rewrite floor must match exactly;
- all changed nodes must fall inside a named feature envelope and allowed
  replaceable set, unless marked force-authored;
- generic ore/stratum counts below the floor must match;
- cave connectivity samples below the floor must match;
- dungeon nodes outside force-authored envelopes must match;
- newly filled rock must use the correct `grug_materials` stratum for y;
- no native surface decoration may remain floating, buried, inside a road, or
  inside a fixed exclusion envelope;
- water changes must have liquid updates and no suspended boundary walls;
- opened sky, sealed cave, cliff, water, structure interior, and vertical chunk
  edge lighting must be correct.

This suite makes the qualified preservation promise measurable.

### Visual debug exports and runtime tools

**Recommendation.** Provide offline SVG/PNG layers and CSV/JSON summaries for:

- zone fill, canonical/displaced boundaries, IDs, levels, faction/race region;
- explicit graph edges and unexpected raster contacts;
- coast/shelf/deep-ocean/channel classes;
- capitals, starts, POIs, no-jitter and terrain-blend envelopes;
- roads, rivers, lakes, gradients, crossings, claim-exclusion corridors and
  hard-protected functional envelopes;
- logical biomes and per-zone shares;
- housing center eligibility, rejection reason, and simulated claims;
- terrain height/slope/cut/fill magnitude;
- mount ocean warning/hard masks and candidate illegal island approaches.

At runtime, an admin-only point diagnostic should display geometry version,
seed checksum, x/z zone and race region, boundary distance, logical biome,
ocean class, road/POI/claim intersections, territory result at the player's y,
and the rule that won precedence. A temporary particle/HUD overlay is safer
than permanent debug nodes. Runtime diagnostics must use the same public
classifier, not a parallel reimplementation.

### Reproducible performance benchmarks

Benchmark a fixed corpus containing:

- a deep no-op chunk;
- inland ordinary surface;
- zone boundary;
- coast/shelf/deep-ocean transition;
- Holy boundary;
- capital/start blend envelope;
- road, river/lake, and crossing;
- large structure slice;
- dragon island/channel;
- worst-case dense authored decorations and exact-region ores.

Record engine commit, game commit, seed, mapgen settings, chunksize,
`num_emerge_threads`, LuaJIT versus bundled Lua 5.1, hardware, and whether caches
are warm. Report p50/p95/max callback time, total chunk time, chunks/s, peak
memory/RSS, Lua allocation/GC where available, full-buffer get/set counts,
modified voxel count, lighting/liquid calls, and main-thread step latency.

Run each case enough times to separate initialization from steady state. A
regression threshold should compare against the current WP18/WP36 baseline and
against the immediately preceding WP40 revision. The 100-player exploration
trace is a separate system test, not a substitute for the micro-corpus.

## Risks and implementation resolutions

### Historical design-source conflicts (resolved 2026-08-12)

This table records the conflicts found while the repository was in a staged
design transition. They are no longer active inputs: `world_zones.md` now uses
universal level-31-60 contest rules, separate land/boat graphs, offshore
dragons and the ten-zone claim model; `world.md` composes contested terrain
with bounded hard-protected functional anchors; the material handoff uses the
same ten housing zones; and WP40's Backlog row names the final geometry and
audits. The evidence column remains as historical provenance for why each
correction was required.

| Historical conflict | Resolution now binding |
|---|---|
| Four level-31-40 frontier approaches were peaceful. | Every level-31-60 ordinary zone is contested; `world_zones.md` §8 carries the corrected rows. |
| Shared-front terrain had a blanket immutable/resource-only rule. | Ordinary contested terrain is mutable; only bounded functional anchors, irreplaceable route structures, claims and Holy Grounds receive their explicit protection. |
| Dragon endpoints were mainland contact zones in one overloaded graph. | Both endpoints are offshore and retain stable IDs; §9 separates land adjacency from four exact boat-route edges. |
| `world.md` still contained private housing-island target geometry. | WP40 generates no housing islands; the ten-zone dry-land eligibility masks and exclusions are its only housing geometry inputs. Remaining island text elsewhere is shipped-history/integration debt, never mapgen authority. |
| Material notes mentioned only four level-21-30 homestead zones. | Both TODOs now name all ten level-11-30 housing zones: six home zones and four inter-capital zones. |
| WP40 was called design-ready before the geometry and audits were complete. | Its Backlog contract now names the completed geometry/audits and requires a reviewed pre-code engineering brief plus measured capacity/performance outputs. |

### Technical risk register

Each item below keeps facts, inference, alternatives, and recommendation
separate.

#### R1 — Native v7 cannot honor a full-64-bit seed contract

- **Problem/inference:** A requirement that *all* terrain differ for every
  distinct u64 seed is not achievable with native v7 on the pinned engine.
- **Primary evidence:** v7 stores `(s32)params->seed` and explicitly documents
  the entropy loss (`reference_projects/luanti/src/mapgen/mapgen.cpp:100-113`).
  Lua's numeric seed path is also unsafe above 2^53
  (`reference_projects/luanti/doc/lua_api.md:7069-7116`).
- **Alternatives:** accept native low-32 substrate plus full-seed authored
  geometry; use singlenode/full Lua mapgen; patch/fork the engine and accept a
  world-format compatibility break.
- **Recommendation:** Scope the guarantee to all Grudgelands-authored geometry
  and random fields. Document native v7's low-32 limitation in WP40 acceptance.

#### R2 — Arbitrary parallel v7 generation is not a reliable acceptance target

- **Problem/inference:** Pure Lua can avoid races, but the complete output may
  still vary or fail under multiple v7 emerge threads.
- **Primary evidence:** the engine states singlenode is the only mapgen not
  affected by its unfinished slice bug and enables multiple threads by default
  only there (`reference_projects/luanti/src/emerge.cpp:180-188`).
- **Alternatives:** support one thread; accept/test known multithread risk;
  switch to singlenode/full Lua; update the pinned engine after the issue is
  fixed and reverify.
- **Recommendation:** Pin production generation to one emerge thread and make
  arbitrary chunk *request order* the supported determinism guarantee.

#### R3 — Engine surface decorations are stale before the overlay runs

- **Problem/inference:** Trees and schematics are placed using native surface
  height/biome, then the Lua overlay moves or replaces that surface. Floating,
  buried, clipped, or excluded decorations result.
- **Primary evidence:** decorations execute before the Lua callback and use
  `mg->heightmap`/`mg->biomemap`
  (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:361-379`,
  `reference_projects/luanti/src/mapgen/mg_decoration.cpp:231-251`). Lua receives
  copies with no setter (`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:606-645`).
- **Alternatives:** leave them and clean up heuristically; constrain terrain
  movement; disable conflicting native registrations and place authored surface
  decorations after the overlay.
- **Recommendation:** use the third option. Keep only native categories proven
  independent of the changed surface.

#### R4 — "Preserve all caves, dungeons, ores, and strata" is overbroad

- **Problem/inference:** Replacing a voxel cannot preserve its prior content.
  Raising terrain creates a volume native stages never processed; lowering
  terrain deletes features in the cut.
- **Primary evidence:** caves, ores, dungeons, and decorations are complete
  before Lua (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:332-379`).
- **Alternatives:** no terrain height changes; bound the rewrite shell and
  qualify preservation; recreate features in added/cut volumes.
- **Recommendation:** specify byte-for-byte preservation below named rewrite
  floors and explicit exceptions inside feature envelopes. Do not promise the
  impossible absolute form.

#### R5 — Shell writes can make results order-dependent

- **Problem/inference:** Treating `emax` as ownership allows a chunk to modify
  ungenerated border blocks that another chunk later owns.
- **Primary evidence:** the VM emerges a one-block border, blits it all, but
  marks only central blocks generated
  (`reference_projects/luanti/src/servermap.cpp:213-255`,
  `reference_projects/luanti/src/servermap.cpp:287-350`).
- **Alternatives:** keep shell cleanup and build extensive order tests; serialize
  neighbor ownership through IPC; render only central slices and eliminate the
  source of surface spill.
- **Recommendation:** central ownership/pull rendering. Reserve shell writes for
  narrowly proven lighting mechanics only.

#### R6 — Cross-chunk schematics can be partial and probabilistically unstable

- **Problem/inference:** Calling one large schematic from whichever chunk sees
  its anchor clips the structure to that VM. Repeating it from chunks may
  resolve randomized nodes differently and overwrite in a different order.
- **Primary evidence:** schematic blitting skips positions outside the VM,
  invokes `myrand` for optional nodes, and only then reports whether the whole
  volume fits (`reference_projects/luanti/src/mapgen/mg_schematic.cpp:150-219`).
- **Alternatives:** require every schematic to fit the emerge halo; place later
  from main against a deliberately emerged region; compile deterministic voxel
  slices and render by central ownership.
- **Recommendation:** deterministic sliced structures for capitals and other
  large fixed builds; use the native API only for bounded small schematics.

#### R7 — Terrain-derived anchor heights are underspecified

- **Problem/inference:** Different chunks or vertical slices can see different
  portions of the footprint, so a median/first-writer rule is not a global
  terrain property.
- **Primary evidence:** the engine heightmap is central-range and pre-biome
  (`reference_projects/luanti/src/mapgen/mapgen.cpp:237-290`,
  `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:320-330`); the current
  implementation documents clipped-median bias and a vertical-edge deadlock
  (`mods/MAPGEN/grug_mapgen/structures.lua:78-126`).
- **Alternatives:** fixed authored y; global analytic v7-point sampling; an
  immutable precomputed anchor-height table.
- **Recommendation:** define one of these in design before implementation,
  preferably a fixed/seed-derived analytic plateau profile. Do not persist a
  height chosen by whichever generated chunk arrives first.

#### R8 — A broad main-environment overlay would duplicate writes and cause lag

- **Problem/inference:** It would execute after the generated VM has already
  been written, then run bulk copies/light/liquids under the server environment
  lock.
- **Primary evidence:** first blit happens in `finishBlockMake` before main Lua
  (`reference_projects/luanti/src/servermap.cpp:275-300`,
  `reference_projects/luanti/src/emerge.cpp:588-626`); the API warns that the
  callback blocks the main thread (`reference_projects/luanti/doc/lua_api.md:6580-6585`).
- **Alternatives:** main pass; mapgen-environment pass; full Lua mapgen.
- **Recommendation:** mapgen environment for all broad pure voxel work; main
  only for sparse persistence/metadata.

#### R9 — Large VoxelManip passes can dominate generation cost

- **Problem/inference:** Even a shallow edit copies 1.4 million entries in each
  direction at default chunksize; multiple passes multiply that cost.
- **Primary evidence:** default chunksize and border construction yield the
  dimensions (`reference_projects/luanti/src/defaultsettings.cpp:535-540`,
  `reference_projects/luanti/src/servermap.cpp:200-255`); get/set traverse the
  full volume (`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:92-144`).
- **Alternatives:** direct node calls for sparse work; multiple simpler bulk
  stages; one consolidated bulk pass with no-op prefilter.
- **Recommendation:** consolidate and prefilter, but benchmark sparse versus
  bulk paths for each feature class.

#### R10 — Lighting can remain stale after content changes

- **Problem/inference:** `set_data` changes content only, and sunlight depends
  on the state immediately above the calculation range. Incorrect range or
  write ordering can preserve light in filled terrain or darkness under opened
  sky.
- **Primary evidence:** content-only setter
  (`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:117-144`) and
  sunlight seed-row behavior
  (`reference_projects/luanti/src/mapgen/mapgen.cpp:476-507`).
- **Alternatives:** rely on old light; stamp light values manually; perform one
  tested post-edit lighting correction with carefully chosen bounds.
- **Recommendation:** the third option, backed by vertical-order and boundary
  hash tests. Manual stamping should be minimal and evidence-driven.

#### R11 — Future islands cannot be retrofitted reliably after exploration

- **Problem/inference:** Existing generated chunks will never see new island or
  channel generation code.
- **Primary evidence:** generated blocks are returned without regeneration
  (`reference_projects/luanti/src/emerge.cpp:545-581`).
- **Alternatives:** author terrain/channels now; require a future fresh world;
  build an offline destructive migration.
- **Recommendation:** author and generate the full geometry in WP40, populate it
  later.

#### R12 — AreaStore and IPC are easy to misuse

- **Problem/inference:** AreaStore does not represent shared polygons or persist
  canonical claims, and per-query IPC would add serialization-like work.
- **Primary evidence:** AreaStore is a cuboid/point intersection index and must
  be persisted by the mod (`reference_projects/luanti/doc/lua_api.md:8422-8467`);
  IPC serializes/copies on access (`reference_projects/luanti/doc/lua_api.md:7826-7849`).
- **Alternatives:** polygon scan; spatial grid for static zones plus AreaStore
  for dynamic cuboids; use IPC as the live query service.
- **Recommendation:** static geometry grid plus main-only AreaStores; IPC once
  for immutable setup/checksum, never in hot queries.

#### R13 — Exact cultural depth resources cannot rely on native biome filters

- **Problem/inference:** Authored race-region polygons and engine climate
  biomes can disagree, so a biome-filtered ore can appear in the wrong cultural
  column or fail to appear in the right one.
- **Primary evidence:** engine biome choice is cuboid plus climate distance
  (`reference_projects/luanti/src/mapgen/mg_biome.cpp:231-278`), and ores use the
  engine biomemap (`reference_projects/luanti/src/mapgen/mg_ore.cpp:82-96`).
- **Alternatives:** accept approximate cultural distribution; make engine
  cuboids approximate the polygons; place exact-region resources in an authored
  stage.
- **Recommendation:** authored placement for any resource whose design contract
  is exact by race region.

#### R14 — Housing capacity can be invalidated by incidental v7 water/relief

- **Problem/inference:** If eligibility excludes actual inland water and steep
  terrain, native seed variation changes usable area and fragments 101x101
  reservations. A simple authored-zone-area calculation overstates capacity.
- **Primary evidence:** the housing model requires the complete future footprint
  and excludes boundaries, civic/POI/road corridors, shelf, selected inland
  water, and deep ocean (`TODO-design-housing.md:91-113`,
  `TODO-design-housing.md:249-271`).
- **Alternatives:** normalize terrain/water in housing cells; evaluate masks
  from the final generated terrain for every seed; reserve large authored flat
  housing subareas.
- **Recommendation:** combine authored capacity corridors with exact final-node
  validation and use simulated packing on all 32 seeds. Decide the treatment of
  incidental lakes before accepting capacity.

#### R15 — Flight-proof island channels require more than a coastline test

- **Problem/inference:** A channel can be water yet still permit high-altitude
  drift after forced dismount or expose an unintended land/tunnel route if its
  runtime mask differs from terrain.
- **Primary evidence:** the mount design requires horizontal ocean
  classification at every y and a hard no-flight strip before each shore,
  including drift prevention (`docs/design/mounts.md:189-220`).
- **Alternatives:** larger channels/hard bands; teleport-back barrier; accept
  flight access.
- **Recommendation:** derive terrain, immutable column, warning, and hard-flight
  masks from one channel geometry and simulate maximum-speed/height approaches.
  Exact width remains a design question.

#### R16 — Engine setting or geometry changes silently create seams

- **Problem/inference:** Even without changing node registrations, altered v7
  noise or authored geometry changes only future chunks.
- **Primary evidence:** the current mod uses `override_meta=true` and already
  warns that old worlds get seams (`mods/MAPGEN/grug_mapgen/init.lua:16-31`).
- **Alternatives:** allow seams; freeze all inputs per world; migrate offline or
  start fresh.
- **Recommendation:** geometry manifest plus hard compatibility gate and a
  fresh-world rollout.

### WP40 pre-code engineering brief and measured outputs

No owner-design question remains. `world_zones.md` §§7-14 and
`TODO-design-housing.md` bind items formerly listed here: Holy Grounds and
island geometry, all water classes, stable IDs and separate land/boat graphs,
the common y = -700 shallow floor, planned surface water, exact housing zones
and static eligibility, and the 32-seed capacity/audit model.

Before an implementation subagent changes mapgen code, the WP40 orchestrator
must write and review a short engineering brief that freezes:

1. the analytic, chunk-order-independent terrain-derived target-height
   function for every capital, start and mandatory structure envelope;
2. the authored terrain rewrite shell, maximum cut/fill behavior and exact
   treatment of caves, dungeons, liquids and strata intersecting that shell;
3. the category table for native versus authored surface/cave decorations and
   the deterministic normalization of unregistered v7 surface water;
4. the resource-placement split: generic depth resources that remain native
   versus cultural/zone resources that use the exact authored registry;
5. whether immutable seed-derived registries are built per mapgen state or
   transferred once, including initialization and memory measurements; and
6. the benchmark thresholds and corpus for cold generation, sustained
   throughput, main-step latency, peak memory, modified-voxel counts and
   lighting/liquid work relative to the WP18/WP36 baseline.

Production uses one v7 emerge thread and guarantees arbitrary chunk-request
order, not unsupported parallel v7 generation. The full decimal seed controls
all Grudgelands-authored geometry; native v7 relief retains its documented
signed-low-32-bit limitation. Both points are acceptance facts, not selectable
alternatives. Capacity defaults and performance numbers are measured WP40
outputs and must be recorded before its final integration gate.

## Source index

### Project design and research sources read

- `AGENTS.md` — repository rules, current mapgen architecture notes, Lua 5.1
  and pinned-engine constraints.
- `docs/design/world_zones.md` — 38 stable zone catalog, current adjacency,
  fixed anchors/envelopes, boundary budgets, and the older rules identified as
  conflicts above.
- `docs/design/world.md` — current terrain/protection/depth/structure rules and
  the obsolete shared-front, mainland-dragon, and housing-island assumptions.
- `TODO-design-material-progression.md`, especially §§3 and 11 plus the final
  integration handoff — newer territory, y=-701, Holy Grounds, offshore dragon,
  shelf/deep-ocean, and WP40 requirements.
- `TODO-design-housing.md` — newer ten-zone open-world claims, 101x101 future
  reservation, exclusions, spatial indices, persistence, and capacity audit.
- `docs/design/mounts.md` — altitude-independent ocean/territory lookup,
  warning/hard-flight bands, Holy flight, and dragon-island access proof.
- `docs/research/luanti-lua.md` — project briefing on Lua 5.1, mapgen Lua-state
  isolation, safe integer range, IPC, VoxelManip, and available APIs; all engine
  claims used in this study were then checked against the primary sources below.
- `BACKLOG.md` — current WP40 scope/status and downstream dependencies.

### Current Grudgelands implementation read

- `mods/MAPGEN/grug_mapgen/init.lua` — v7 noise overrides and stage loading.
- `mods/MAPGEN/grug_mapgen/geometry.lua` — pure current rectangle/coast
  geometry and fast box/cap queries.
- `mods/MAPGEN/grug_mapgen/biomes.lua` — current engine biome registration and
  cuboid/climate layout.
- `mods/MAPGEN/grug_mapgen/ores.lua` — generic ore and last-registered stratum
  definitions.
- `mods/MAPGEN/grug_mapgen/decorations.lua` — current engine decoration set and
  ordering assumptions.
- `mods/MAPGEN/grug_mapgen/ocean_mask.lua` — main-environment setup, IPC,
  mapgen-script registration, and legacy healing LBM.
- `mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua` — mapgen-environment ocean
  carve, shell handling, surface redressing, liquids, and lighting.
- `mods/MAPGEN/grug_mapgen/structures.lua` — main-environment capital/outpost/
  camp placement, persistent height decisions, VoxelManip write path, and
  documented chunk-edge failures.
- `mods/CORE/grug_core/init.lua` — current rectangle constants, capital/anchor
  tables, radial territory/zone/level functions, and platform persistence.
- `mods/CORE/grug_core/protection.lua` — current POI registry, linear protection
  checks, rectangle territory ownership, and ocean denial.

### Pinned Luanti primary sources read and cited

- `reference_projects/luanti/doc/lua_api.md:5375-5615` — VoxelManip bulk/snapshot,
  mapgen VM, liquids, and schematic/ore/decoration APIs.
- `reference_projects/luanti/doc/lua_api.md:5740-5805` — mapgen objects and
  generation notifications.
- `reference_projects/luanti/doc/lua_api.md:6580-6585` — main-environment
  post-generation callback timing and lag warning.
- `reference_projects/luanti/doc/lua_api.md:7069-7116` — broken numeric seed and
  precision-safe seed string.
- `reference_projects/luanti/doc/lua_api.md:7678-7761` — mapgen environment,
  callbacks, isolation, available classes/functions, and absent metadata.
- `reference_projects/luanti/doc/lua_api.md:7826-7870` — IPC copying, CAS, and
  blocking warning.
- `reference_projects/luanti/doc/lua_api.md:8422-8496` — AreaStore semantics,
  intersections, cache, and non-persistence.
- `reference_projects/luanti/doc/lua_api.md:9662-9684` and
  `reference_projects/luanti/doc/lua_api.md:9863-9920` —
  PcgRandom and direct/wrapped ValueNoise behavior.
- `reference_projects/luanti/src/emerge.cpp:175-226` — mapgen objects per thread,
  default multithreading policy, slice-bug warning, and resource cap.
- `reference_projects/luanti/src/emerge.cpp:545-770` — generated-block reuse,
  mapgen execution, mapgen Lua callback, first finish/write, and main Lua
  callback.
- `reference_projects/luanti/src/servermap.cpp:200-350` — central chunk,
  one-mapblock emerged border, full blit, and generated flags.
- `reference_projects/luanti/src/defaultsettings.cpp:535-543` — default mapgen,
  water level, map limit, and chunksize.
- `reference_projects/luanti/src/mapgen/mapgen.cpp:91-113` — deliberate u64 to
  s32 native seed truncation.
- `reference_projects/luanti/src/mapgen/mapgen.cpp:237-290` — heightmap ground
  search and vertical bounds.
- `reference_projects/luanti/src/mapgen/mapgen.cpp:414-525` — light storage,
  sunlight seeding, and spreading.
- `reference_projects/luanti/src/mapgen/mapgen.cpp:623-766` — biome top/filler/
  water replacement and biomemap construction.
- `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:299-381` — exact v7 stage
  order.
- `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:390-457` and
  `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:467-573` —
  base terrain, mountains, ridge channels, and node placement.
- `reference_projects/luanti/src/mapgen/mapgen_singlenode.cpp:17-75` — complete
  native singlenode behavior.
- `reference_projects/luanti/src/mapgen/mg_biome.cpp:163-278` — climate maps,
  cuboid eligibility, and nearest-point biome choice.
- `reference_projects/luanti/src/mapgen/mg_decoration.cpp:37-47`,
  `reference_projects/luanti/src/mapgen/mg_decoration.cpp:68-121`, and
  `reference_projects/luanti/src/mapgen/mg_decoration.cpp:125-256` — registration order, placement constraints, heightmap/biomemap
  use, and placement iteration.
- `reference_projects/luanti/src/mapgen/mg_ore.cpp:31-45`,
  `reference_projects/luanti/src/mapgen/mg_ore.cpp:82-96`, and
  `reference_projects/luanti/src/mapgen/mg_ore.cpp:521-582` — ore ordering,
  seed/biomemap inputs, and stratum replacement.
- `reference_projects/luanti/src/mapgen/mg_schematic.cpp:145-219` — clipping,
  optional-node randomness, rotation, and complete-fit result.
- `reference_projects/luanti/src/mapgen/cavegen.cpp:55-120` — native noise-cave
  iteration and biome interaction.
- `reference_projects/luanti/src/mapgen/dungeongen.cpp:64-105` — dungeon ground,
  neighbor, and non-ground preservation checks.
- `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:588-646` — copied
  mapgen objects and VoxelManip emerged bounds.
- `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:739-799` and
  `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:892-907` —
  truncated `get_seed`, deprecated numeric parameters, and string
  mapgen settings.
- `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1571-1667` — public
  ore/decoration generation, seed truncation, and native biome constraints.
- `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1775-1824` —
  schematic-on-VoxelManip API and fit result.
- `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1980-2016` — mapgen
  versus main liquid queues and lighting bounds.
- `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:35-55`,
  `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:92-175`, and
  `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:200-228` — mapgen
  read/write restrictions, full-volume data copies,
  content-only set, write behavior, liquid, and lighting calls.
- `reference_projects/luanti/src/script/lua_api/l_noise.cpp:17-65` — direct
  ValueNoise construction and zero world-seed addend.
- `reference_projects/luanti/src/script/lua_api/l_util.cpp:587-602` — SHA-256
  implementation exposed to Lua.
- `reference_projects/luanti/src/script/scripting_emerge.cpp:29-80` — separate
  emerge Lua state and its exact registered classes/API modules.
- `reference_projects/luanti/src/script/cpp_api/s_mapgen.cpp:33-60` — callback
  VoxelManip/minp/maxp/blockseed binding.
- `reference_projects/luanti/builtin/emerge/env.lua:1-64` — current-VM node
  helpers, absent metadata, and truncated-seed noise wrappers.
- `reference_projects/luanti/builtin/emerge/register.lua:49-56` — mapgen
  callback registration tables.

### Source limitations

This study does not rely on web documentation or behavior from a newer Luanti
release. It does not benchmark the proposed implementation because no
implementation was authorized or created. Performance conclusions are
operation-count models derived from the pinned source and must be replaced by
measurements during WP40 prototyping. Design conflicts are reported rather
than resolved; where they conflict, the newer material-progression and housing
TODO model is the feasibility target as instructed.
