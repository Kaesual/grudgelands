# WP40 T5-0 engine-seam probe — package contract

Status: **proposed package contract, awaiting user acceptance. Not an
implementation, not a shipped-WP claim, and not authoritative game design.
Until it is accepted it authorizes no code, no world, no engine run and no
evidence commit.**

This file specifies a small, tools-only, disposable T5-0 engine-seam probe. It
does not build the probe. Every number, coordinate, operation count and gate
below is a specification to be implemented and then measured; no sentence here
records a measurement that has been taken. Where a fact is settled by pinned
engine source it is cited as such; where it can only be settled by running the
engine it is placed in the runtime-measurement column and stays there.

The pinned engine reference is `reference_projects/luanti` at
`df04879066de6eb94ca43996822a6dfacc74feca` (5.17.0-dev). The repository
reference is `1b38943`. Every engine claim carries a
`reference_projects/luanti/…:line` citation; every repository claim carries a
`<path>:line` citation.

**Size of the package, stated once and enforced everywhere below:**
2 arms × 2 orders × 3 mapchunks = **12 mapchunk generations** in **4** engine
invocations. No other total appears in this document.

---

## 1. Authority, and what acceptance authorizes

### 1.1 Authority ranking

| Document | Status | Effect on this contract |
| --- | --- | --- |
| [`docs/design/world_zones.md`](../design/world_zones.md) | decided player-visible world design (`wp40-acceleration-and-delivery-plan.md:16-17`) | this contract changes none of it |
| [`wp40-engineering-brief.md`](wp40-engineering-brief.md) | "Final pre-code engineering contract; independently reviewed 2026-08-13" (`:3-5`) | **binding**; wins every conflict |
| [`wp40-t2-contracts.md`](wp40-t2-contracts.md) | "contract file. Created 2026-08-18 by the plan's own relocation rule." (`:3-4`) | **binding** |
| [`wp40-t2-plan.md`](wp40-t2-plan.md) | T2 state and ordering (`wp40-acceleration-and-delivery-plan.md:20`) | binding for the locked-surface list (`:222-237`) |
| [`wp40-source-authority.md`](wp40-source-authority.md) | "derived implementation authority. Not game design." (`:3`) | not consumed here |
| [`wp40-reality-corrections.md`](wp40-reality-corrections.md) | "evidence history. Not a contract." (`:3`) | not consumed here |
| [`wp40-acceleration-and-delivery-plan.md`](wp40-acceleration-and-delivery-plan.md) | "discussion draft … Not an implementation contract and not authoritative game design." (`:3-6`) | motivates this package; **loses every conflict with the brief** (section 4) |

### 1.2 Naming hazard: "T5" is overloaded

`T5` at `wp40-engineering-brief.md:1975` and `:3209-3210` is a **resource depth
tier**, not a task. Only section 7 of the brief (`:4091`, `:4106` "Only T5 owns
the VoxelManip adapter and transaction.", `:4117`) and
`wp40-acceleration-and-delivery-plan.md:475-533` mean the terrain adapter.
Everywhere below, `T5` and `T5-0` mean the adapter task and this probe; no
sentence here refers to the depth tier.

### 1.3 What acceptance authorizes

Acceptance authorizes exactly one follow-on package that creates files only under
`tools/wp40/t5_probe/` (section 8), runs **four** headless disposable-world engine
captures (section 10) on the designated host, commits reviewed evidence under
`tools/wp40/evidence/t5-probe-<digest>/`, and reports the observations of section
11 and the risks of section 21.

It authorizes **none** of: a production file change, a `mods/` change, a
production registration, a second reusable VoxelManip adapter, a schema or
operation-type freeze, a run of `tools/sync_to_luanti.sh`
(`docs/process/wp-workflow.md:42-45`), an edit to any of the six locked T2
surfaces (`wp40-t2-plan.md:227-234`), or any movement of full T5 ahead of T3 and
T4 (`wp40-acceleration-and-delivery-plan.md:477-479`).

## 2. Probe definition

T5-0 is a tools-only, disposable, headless engine-seam probe that generates
three fixed mapchunks of a production-like Grudgelands world in two request
orders under two arms — a registered mapgen script whose callback performs zero
VoxelManip calls, and the same script carrying a synthetic write payload — and
compares decoded node lanes, exact VoxelManip operation counts, callback
timings and Lua heap between them, so that a wrong assumption about the Luanti
mapgen seam (script loading, callback contract, bidirectional IPC,
`set_data`/`set_param2_data` separation, dirty-gated lighting with a bounded
light upload, conditional `update_liquids`, central-slice persistence across a
later neighbour's generation, and what timing/memory facilities the mapgen
state actually exposes) surfaces now rather than after T4, without creating
production code, without freezing any T2/T3/T4-owned schema or vocabulary, and
without claiming representative production performance.

---

## 3. Scope and non-claims

### 3.1 In scope

- The engine seams enumerated in section 7, measured against the pinned-source
  expectations recorded there.
- The four micro-cases of `wp40-acceleration-and-delivery-plan.md:497-502`,
  instantiated over three mapchunks exactly as section 10 defines them.
- Two chunk request orders with a paired control per order (section 10.7).
- Callback wall time via `core.get_us_time()` and Lua heap via
  `collectgarbage("count")` in both states; process RSS best-effort (section
  12.4).

### 3.2 Non-claims

T5-0 does **not** prove, establish, validate, freeze or make any claim about:

1. the final T2 compiled payload, its records or its field names — T2 owns them
   (`wp40-engineering-brief.md:4088`, `:2247-2257`, `:2259-2261`);
2. the `grug_zones` public API — T3 owns it (`:4089`);
3. the closed typed resolver matrix, the four named resolver pairs, the
   per-voxel operation plan, the deferred-coverage extension, the
   exact-host-only deep resource type or the offline dungeon-guard oracle — T4
   owns them (`:4090`, `:2109-2113`);
4. final operation types or conflict rules of any kind;
5. the production T5 adapter or transaction (`:4106` "Only T5 owns the
   VoxelManip adapter and transaction.");
6. representative production performance. No threshold in `:3339-3358` is
   evaluated, approached or claimed, and the brief itself records that "No
   number in this section claims a successful measurement" (`:3471-3472`);
7. full dungeon, resource or biome behaviour; T5, T9 or release readiness;
8. logical-biome→content mappings, top/filler, decoration candidates, water
   normalization or the authored vein catalog — T6/T7 own them (`:4092-4093`);
9. **any statistical property of its own timings.** Every timing is `n = 1`:
   one run per (arm, order) cell, no warm-up, no repetition, no variance, no
   outlier rule. The summary carries `timings_are_golden: false` and
   `timing_replicates: 1`, and the cost projection is one unreplicated sample
   multiplied by **four** (section 14.3);
10. **a settled liquid state.** The `liquid_update = 86400` pin suppresses
    `Server::AsyncRunStep`'s periodic global drain
    (`reference_projects/luanti/src/server.cpp:781-792`) and **nothing else**:
    `finishBlockMake`'s `transformLiquidsLocal`
    (`reference_projects/luanti/src/servermap.cpp:300`) and a later neighbour's
    own local transform remain part of every O1/O2 result (section 10.15). What
    the probe compares is the **post-generation result after bounded local
    transform, before background settling**. It does not substitute for the
    brief's "frozen liquid-settling procedure" (`:3005`) or "frozen quiescence
    limit" (`:1405`), and it says nothing about a normally stepping server;
11. **whole-chunk byte identity.** Every byte comparison is evidenced on CORE
    and SEAM only: **388,096 distinct voxels** of the **1,536,000** central
    voxels the three measured chunks contain, or **25.3 %** (section 14.3). Per
    chunk, CORE is 110,592 of 512,000, or 21.6 %. A containment pass means "no
    difference in the compared regions", not "no difference in the chunk", and
    the summary says it in those words;
12. **that loading a mapgen script is byte-neutral.** Answering that needs a
    script-free control arm and this scope has none: `A1` — script registered,
    callback performs zero VoxelManip calls — is the paired control, so every
    comparison is `B − A1` inside a world that already loads the probe's mapgen
    script;
13. **a generic engine unfinished-slice overwrite bug.** Section 10.13 records
    why no deterministic controlled negative is constructible at this scope;
    micro-case 4 is a bounded paired-order persistence observation that reports
    order effects without attributing their cause.

It also does **not** move full T5 ahead of T3 and T4
(`wp40-acceleration-and-delivery-plan.md:477-479`).

### 3.3 The register these non-claims are written in

This package adopts, by reference, the non-claim register the repository already
uses: a static-only pass makes no installed-host claim and host evidence
corroborates rather than replaces the pinned source audit
(`tools/wp40/dungeon_probe/README.md:60-63`); a measured count is a non-portable
observation and not a golden acceptance value, with only its sign invariant
(`:37-38`); and a finite oracle claims nothing about unexplored coverage
(`wp40-engineering-brief.md:3047-3048`).

By the same rule: every count, timing, digest and byte comparison this probe
produces is a non-portable observation of one host, one engine build, one seed
and one repository commit. Only the *relations* the gates assert — equality,
inequality, exact operation counts, and emptiness of a named delta — are
invariant, and only within a single run set.

## 4. Acceleration plan §8 versus the binding brief

`wp40-acceleration-and-delivery-plan.md:475-533` is the origin of this package
and is a discussion draft (`:3-6`). Five points differ from
`wp40-engineering-brief.md`; in every case the brief wins.

| # | Acceleration plan §8 | Binding brief | Resolution |
| --- | --- | --- | --- |
| a | one baseline capture — "the same chunks once without and once with the injected probe" (`:490-491`) | every schedule needs its own paired control with the same order (`:3029-3038`) | **Two arms, both orders. Four runs, not two.** `B − A1` isolates the payload and each order carries its own paired `A1` control (10.1, 10.6, 10.7, 10.9). A third, script-free arm would also have isolated "a mapgen script exists"; it is out of scope, and non-claim 12 records the consequence |
| b | new evidence "is limited to the missing directions and operations, including mapgen-to-main IPC" (`:513-516`) | "There is no IPC access in `H`, `id_at`, a spatial query, column loop, candidate loop, or generated-chunk callback." (`:2278-2279`); "IPC is never a cache-miss or runtime recovery channel." (`:2318`) | **Capability telemetry only, explicitly not adopted.** The per-callback `ipc_set` is labelled `production_adopted: false` in-band (12.3), is performed identically in both arms so it cancels in `B − A1`, and the contract records that production may not do this |
| c | "The primary substrate is the current production-like Grudgelands baseline" (`:487-491`), which runs `mgv7_dungeon_ymax = 31000` | the vertical contract binds `mgv7_dungeon_ymax = -193` (`:335-337`, `:2970-2971`) | **Do not pin it (section 5).** The probe runs the engine default 31000, which is what the repository at `1b38943` actually produces (`tools/wp40/evidence/t0-post-wp43-wp18-wp36/70adabd28401e820ec86e8786bf0da368225c8624e42ed02dd3bce175fd3cafc/raw/run-001.map_meta.txt:175`), records it, and claims nothing about `-193`. `mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua:86` is source-catalog **intent**: the file *is* `dofile`d in the main state on every load (`mods/MAPGEN/grug_mapgen/init.lua:94` → `wp40/init.lua:18` → `wp40/compiler.lua:61`), but its value never reaches a mapgen setting — there is no `core.set_mapgen_setting` anywhere under `mods/` |
| d | the probe performs VoxelManip writes in a mapgen callback | "No task may introduce a second geometry evaluator, placement path, or VoxelManip transaction for convenience." (`:4080-4081`) | **The probe IS a second VoxelManip write path, and this is the mitigation, stated explicitly:** it is not a task in the T0–T9 decomposition, creates no file under `mods/`, is registered by no production code path, uses deliberately foreign vocabulary (section 9), and is deleted before T5 begins with the review proving its absence (section 20). The brief's sentence forbids a second transaction *inside the WP40 task graph for convenience*; this probe is outside that graph and exists to test the seam the single transaction will later use |
| e | silent about the locked T2 surfaces | "No work package may touch them as a side effect." (`wp40-t2-plan.md:237`) | **Section 8.3 carries the explicit clause** naming all six files and the reviewer check |
## 5. Substrate manifest

Every row is bound into the manifest digest (section 13.2). "Class" is
`repo` (pinned by a committed file), `engine` (engine default, not pinned
anywhere the engine reads it), or `probe` (pinned by this probe's generated
configuration).

| Item | Value | Source | Class | Recorded at runtime? |
| --- | --- | --- | --- | --- |
| game tree | `git archive` of `1b38943` | pattern: `tools/wp40/run_dungeon_probe.sh:62` | probe | yes — archive commit SHA in the manifest digest |
| mapgen | `v7` | `game.conf:7-8` (`allowed_mapgens = v7`, `default_mapgen = v7`) | repo | yes — `map_meta.txt` |
| `fixed_map_seed` | `40200517` | precedent `tools/wp40/run_dungeon_probe.sh:82` | probe | yes |
| `num_emerge_threads` | `1` | default `0` at `reference_projects/luanti/src/defaultsettings.cpp:511`; auto-multithreading only for singlenode at `reference_projects/luanti/src/emerge.cpp:187-188`; clamp at `:202-224` | probe | yes |
| `secure.trusted_mods` | `grug_wp40_t5_probe` | precedent `tools/wp40/capture_t0_baseline.sh:126` | probe | yes |
| `server_announce` | `false` | precedent `tools/wp40/run_dungeon_probe.sh:73-79` | probe | yes |
| `enable_ipv6` | `false` | — | probe | yes |
| `bind_address` | `127.0.0.1` | — | probe | yes |
| `port` | `32000 + run` | rule at `tools/wp40/capture_t0_baseline.sh:120` | probe | yes |
| engine log flags | `--log-timestamp none --color never` | `tools/wp40/capture_t0_baseline.sh:145` | probe | n/a (makes the log byte-comparable) |
| `chunksize` | `5` | `reference_projects/luanti/src/defaultsettings.cpp:539` | engine | yes (`map_meta.txt:124`) |
| `water_level` | `1` | evidence `run-001.map_meta.txt:125` | engine | yes |
| `mg_flags` | `caves, dungeons, light, decorations, biomes, ores` | `reference_projects/luanti/src/mapgen/mapgen.cpp:210`; evidence `:126` | engine | yes |
| `mgv7_spflags` | `mountains, ridges, nofloatlands, caverns` | evidence `:141` | engine | yes |
| `mgv7_dungeon_ymin` | `-31000` | evidence `:206` | engine | yes |
| `mgv7_dungeon_ymax` | `31000` | evidence `:175` | engine | yes — **not** `-193`; see section 4c |
| `mgv7_large_cave_depth` | `-33` | evidence `:111` | engine | yes |
| `mgv7_cavern_limit` | `-256` | evidence `:152` | engine | yes |
| `mgv7_cave_width` | `0.0900000036` | evidence `:191` | engine | yes |
| `mapgen_limit` | `31007` | evidence `:130` | engine | yes |
| `liquid_update` | **`86400`** (engine default `1.0`) | default `reference_projects/luanti/src/defaultsettings.cpp:533`; read once into `m_liquid_transform_every` at `reference_projects/luanti/src/server.cpp:597`; the drain it gates is `:781-792` | **probe** | yes — **a deliberate determinism pin, explicitly not a production-like value.** It suppresses **only** the periodic global drain, and not `finishBlockMake`'s per-chunk `transformLiquidsLocal`; section 10.15 states exactly what it does and does not remove |
| `liquid_loop_max` | `100000` | `reference_projects/luanti/src/defaultsettings.cpp:531`, bound on `transformLiquidsLocal` at `reference_projects/luanti/src/servermap.cpp:300` | engine | yes |
| `liquid_queue_purge_time` | `0` | `reference_projects/luanti/src/defaultsettings.cpp:532` | engine | yes |
| `mgv7_np_terrain_base` | offset 14, scale 70, spread 600³, seed 82341, octaves 5, persist 0.6, lacunarity 2.0 | `mods/MAPGEN/grug_mapgen/init.lua:24-27` | repo | yes — `core.get_mapgen_setting_noiseparams` |
| `mgv7_np_terrain_alt` | offset 10, scale 25, spread 600³, seed 5934, octaves 5, persist 0.6, lacunarity 2.0 | `mods/MAPGEN/grug_mapgen/init.lua:28-31` | repo | yes |
| `mg_biome_np_heat` | offset 50, scale 35, spread 1000³, seed 5349, octaves 3, persist 0.5, lacunarity 2.0, `eased` | `mods/MAPGEN/grug_mapgen/init.lua:44-48` | repo | yes |
| `mg_biome_np_humidity` | offset 50, scale 35, spread 1000³, seed 842, octaves 3, persist 0.5, lacunarity 2.0, `eased` | `mods/MAPGEN/grug_mapgen/init.lua:49-53` | repo | yes |
| `mg_biome_np_heat_blend` | offset 0, scale 4, spread 32³, seed 13, octaves 2, persist 1.0, lacunarity 2.0, `eased` | `mods/MAPGEN/grug_mapgen/init.lua:82-86` | repo | yes |
| `mg_biome_np_humidity_blend` | offset 0, scale 4, spread 32³, seed 90003, octaves 2, persist 1.0, lacunarity 2.0, `eased` | `mods/MAPGEN/grug_mapgen/init.lua:87-91` | repo | yes |
| continent rectangle | `X_HALF = 1500`, `Z_MIN = 100`, `Z_MAX = 1700` | `mods/CORE/grug_core/init.lua:13-15` | repo | yes — republished over IPC at `mods/MAPGEN/grug_mapgen/ocean_mask.lua:46` |
| `COAST_NOISE` | offset 75, scale 75, spread 300³, seed-difference 91744, octaves 3, persist 0.55 | `mods/MAPGEN/grug_mapgen/geometry.lua:69-73` | repo | no — it is not a mapgen setting; created lazily and sampled in both states |
| probe arm | `A1` \| `B` | this contract, section 10.1 | probe | yes |
| probe order | `O1` \| `O2` | this contract, section 10.6 | probe | yes |

Exactly six `core.set_mapgen_setting_noiseparams(..., true)` calls exist in the
game, all in `mods/MAPGEN/grug_mapgen/init.lua`; there is no plain
`core.set_mapgen_setting` anywhere in `mods/`. Everything in the `engine` class
is left at the engine default deliberately: it is the substrate the repository
actually produces today, and pinning it would create a substrate the rest of
the project does not run.

The realized values are captured twice and both captures are bound into the
manifest digest: the world's `map_meta.txt` is copied verbatim into the raw
evidence, and the driver reads every listed setting back in-band with
`core.get_mapgen_setting` / `core.get_mapgen_setting_noiseparams` and emits it
as a `manifest` record (12.3). A disagreement between the two is a
run abort (section 15, `A-06`).

---

## 6. Existing-writer inventory and coordinate selection

### 6.1 Existing writers, and whether they fire at the probe coordinates

The probe coordinates are `k_y = 0`, `k_z = 9`, `k_x ∈ {8, 10, 11}`
(section 6.3). "Fires?" answers for those three mapchunks only.

| # | Mechanism | Owner | `file:line` | What it writes | Fires? | Deciding guard |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | mgv7 `makeChunk` stages: terrain, heightmap, biomes, caves/caverns/randomwalk, ores, dungeons, decorations, dust, liquid, lighting | engine | `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:321-379` | the chunk; 10.13 works out which stages are central-only and which reach the full emerged area | **yes, all** | none. Deterministic: `blockseed = getBlockSeed2(full_node_min, seed)` (`:318`) |
| 2 | native dungeons | engine | `reference_projects/luanti/src/mapgen/mapgen.cpp:890-899`, write range `:952` | dungeon walls/stairs/air over the **full emerged** range | **yes, where the noise gate passes** | `node_min.Y > max_stone_y \|\| node_min.Y > dungeon_ymax \|\| node_max.Y < dungeon_ymin` (`:892-894`) is false with the engine-default `±31000`; then `num_dungeons >= 1` (`:896-899`) |
| 3 | registered biomes (20, each carrying `node_dungeon`/`_alt`/`_stair`) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/biomes.lua:112-116` | biome top/filler/stone/dungeon node identity | **yes** | none |
| 4 | registered ores (4 blob + scatter bands + 5 strata) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/ores.lua:45-46,64-65,83-84,122-123,261-263` | ore nodes inside their y bands | **yes, for every band meeting `[-32,47]`** | per-ore `y_min`/`y_max` |
| 5 | registered decorations (~40, every one `y_min = 1`) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/decorations.lua:93`, `:114` | schematics and simple decorations above y = 1 | **yes** | `y_min = 1` is inside central y `[-32,47]` |
| 6 | 26 `register_alias("mapgen_*")` | `default` | `mods/BASE/default/mapgen.lua:7-37` | which node the engine writes for each mapgen slot | **yes (indirectly)** | none |
| 7 | Ocean Mask mapgen callback (carve, water fill, sunlight stamp, `update_liquids`, `calc_lighting`) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua:515-518` | column carve + `default:water_source` + `param1` + light | **no** | `if not box_needs_mask(minp, maxp, SHELL) then return end` (`:516-518`), derived in 6.2. Evaluated **before** the first `vm:` call (`:520`), so a skipped chunk costs zero VoxelManip operations |
| 8 | Ocean Mask healing LBM | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/ocean_mask.lua:606` | idempotent coastal re-carve | **no** | LBMs are reached only from `activateBlock` (`reference_projects/luanti/src/serverenvironment.cpp:576`, `:581`), called only at `:957`/`:968` over `m_active_blocks` = forceload list ∪ player radius. `grep -rn forceload mods/` is empty and the probe world has no player |
| 9 | `structures.lua` main-environment `on_generated` | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/structures.lua:776` | camp/outpost/fire nodes | **callback runs, writes nothing** | early return at `:850-852` before the first VoxelManip fetch at `:854`; 6.4 proves the three lists are empty here |
| 10 | `chunk_near_outpost` / `chunk_near_bandit_camp` POI and mod-storage decisions (x/z only, any y) | `grug_mapgen` | `structures.lua:559-567`, `:761-769`, `chunk_covers` `:492-495` | POI records / mod storage, no nodes | **no** | 6.4 |
| 11 | `grug_core.ensure_camp_platform_built` — a **live** main-environment VoxelManip writer (`get_voxel_manip` `:336`, `read_from_map` `:337`, `build_camp` `:364`, `write_to_map` `:387`), ≤ 3 attempts per capital per session (`:288`) | `grug_mapgen` / `grug_core` | `structures.lua:288-364`, `:387`; fallback stub `mods/CORE/grug_core/init.lua:768-770` | capital platform nodes | **no** | only at the six capital anchors `(0, ±900)`, `(±550, ±900)` (`mods/CORE/grug_core/init.lua:84-91`, `SEAT_Z = 900` `:27`) |
| 12 | capital startup sweep: six `core.after(60 + 15·(i − 1))` timers (`:934-935`, `:946`) → possibly `core.emerge_area` around each capital | `grug_core` | `mods/CORE/grug_core/init.lua:934-950`, emerge `:903-921`, seed-dependent short-circuit `:887-893` | generates map on its own at t ≈ 60…135 s | **not inside the measured chunks or their emerged shells**, but a run-comparability hazard | 6.5 and D5 |
| 13 | `grug_mobs` camp/banner LBMs | `grug_mobs` | `mods/ENTITIES/grug_mobs/camps.lua:733`, `:755` | metadata and node timers only, never content | **no** | as row 8; and `grug_mobs` never sets `on_map_load`, so mobs use the ABM branch (`mods/ENTITIES/mobs/api.lua:4162-4174`), never the LBM branch (`:4150-4160`) |
| 14 | `mods/MAPGEN/grug_mapgen/wp40/init.lua` | `grug_mapgen` | `:8-10` | nothing — `enabled = false`, zero `core.register_*`; `wp43_handoff.lua` is never `dofile`d | **no** | inert |
| 15 | the T5-0 payload | this package | `tools/wp40/t5_probe/payload/mapgen.lua` | section 10 | **arm B only** | arm switch |

**No chunk anywhere in this world is free of engine writers.** Rows 1–6 fire in
every chunk of every arm. That is acceptable for exactly two reasons:
*determinism* — every one of rows 1–6 is a pure function of `blockseed`
(`mapgen_v7.cpp:318`), the frozen mapgen settings and the frozen registrations,
so identical settings, registrations, coordinates and request order produce
identical bytes — and *arm-to-arm cancellation* — the two arms differ only by
one configuration key, and that key changes only what the payload's callback
*does*, not whether a mapgen script exists (10.2), so the mod set, archive tree,
seed, registration order and request order are byte-identical and rows 1–6
vanish from `B − A1`.

Cancellation stops being valid the moment any of the following holds, and each
is a gate: the registered content set differs between arms
(`content_id_table_sha256`, abort `A-04`); the realized mapgen settings differ
(`manifest` comparison, `A-06`); the request order differs (the driver is
byte-identical in both arms and emits its realized order, `A-07`); or rows 1–6
are themselves order-dependent in the compared region — which is *expected* in
SEAM and is exactly why every order carries its own paired `A1` control (10.6,
10.9).

### 6.2 Ocean Mask: the exact metric, and the derivation

`box_needs_mask(minp, maxp, grow)` (`mods/MAPGEN/grug_mapgen/geometry.lua:237-243`)
returns `false` if `maxp.y < MASK_MIN_Y`, else
`box_distance_range(minp, maxp, grow) < TAPER + INSET_MAX`. `box_distance_range`
(`:209-227`) computes, for the box grown by `grow` in x and z,
`ax_far = max(|minp.x|, |maxp.x|) + grow`, `az_far` likewise in z,
`az_near = (minp.z > 0) and max(minp.z - grow, 0) or …`, and
`lo = min(X_HALF - ax_far, az_near - Z_MIN, Z_MAX - az_far)`.

`lo` is the **inland-signed distance**, minimised over the grown box, to the
nearer of the two mirrored continent rectangles: positive inside, negative
outside (`:99-111`, `continent_distance`). The mask therefore fires when `lo` is
**small**, and is skipped only when `lo >= TAPER + INSET_MAX = 300` — only for a
box every column of which is at least 300 nodes **inland**. `TAPER = 150`,
`INSET_MAX = 150` (`:36-37`); `SHELL = 16` (`:60`); `SEA_FLOOR_CAP = -15` and
`MASK_MIN_Y = -14` (`:143`, `:151`). The callback passes `SHELL` as `grow`
(`ocean_mask_mapgen.lua:516`) and the central chunk as `minp`/`maxp` — the
callback's `minp`/`maxp` are the central chunk, not the emerged area
(`reference_projects/luanti/src/script/cpp_api/s_mapgen.cpp:37-39`).

With `k_z = 9` the central z range is `[688, 767]`, so `az_near = 672`,
`az_far = 783`, `az_near - Z_MIN = 572` and `Z_MAX - az_far = 917`. With
`k_y = 0` the central y range is `[-32, 47]`, so `maxp.y = 47` is not below
`MASK_MIN_Y` and the first guard does not decide.

| `k_x` | central x | `ax_far` | `X_HALF - ax_far` | `lo` | `lo >= 300`? | `box_needs_mask` |
| --- | --- | --- | --- | --- | --- | --- |
| 8 | `[608, 687]` | 703 | 797 | **572** | yes | **false** |
| 10 | `[768, 847]` | 863 | 637 | **572** | yes | **false** |
| 11 | `[848, 927]` | 943 | 557 | **557** | yes | **false** |

The binding margin is the strait-facing front edge for `k_x ∈ {8, 10}` and the
flank for `k_x = 11`; both exceed 300 by more than 250 nodes, so the exclusion is
not marginal.

**Rejected coordinate family.** A family far out at sea — say `k_x ∈ {30 … 35}`,
central x `2368 … 2847` — does *not* escape the mask: there `X_HALF - ax_far` is
`-963 … -1363`, `lo < 300` holds, and the mask fires in every such chunk, carving
and flooding every column and calling `update_liquids()` and `calc_lighting()`
(`ocean_mask_mapgen.lua:520-560`). Because all mapgen scripts share one Lua state
per emerge thread (`reference_projects/luanti/src/emerge.cpp:641-668`,
`reference_projects/luanti/src/emerge_internal.h:56`) and all
`register_on_generated` callbacks run in full in registration order
(`reference_projects/luanti/builtin/emerge/register.lua:56`,
`reference_projects/luanti/builtin/common/register.lua:23-29`, mode 0
short-circuits nothing), an ocean family would make arm `A1`'s
zero-VoxelManip-call contract unachievable and micro-case 3's water cell
meaningless in a chunk that is already water. The inland family is chosen for
those reasons, not for convenience.

### 6.3 The coordinate lattice and the measured set

The vertical lattice is `wp40-engineering-brief.md:398-399`:

```
central(k) = [-32 + 80k,  47 + 80k]
full(k)    = [-48 + 80k,  63 + 80k]
```

It follows from `chunksize = 5`
(`reference_projects/luanti/src/defaultsettings.cpp:539`), `MAP_BLOCKSIZE 16`
(`reference_projects/luanti/src/constants.h:64`) and `EMERGE_EXTRA_BORDER{1,1,1}`
MapBlocks = 16 nodes per side (`reference_projects/luanti/src/servermap.h:175`,
applied at `reference_projects/luanti/src/servermap.cpp:213-214`, `:325-326`).
Central chunk = 80³ = 512,000 nodes; emerged VM = 112³ = 1,404,928;
`emin = minp - 16`, `emax = maxp + 16`.

**Measured set:** `k_y = 0`, `k_z = 9`, `k_x ∈ {8, 10, 11}` — three mapchunks.

| `k_x` | central box | emerged box | Carries |
| --- | --- | --- | --- |
| 8 | `(608,-32,688) … (687,47,767)` | `(592,-48,672) … (703,63,783)` | micro-cases 2 and 3 (`case = "bounded"`) |
| 10 | `(768,-32,688) … (847,47,767)` | `(752,-48,672) … (863,63,783)` | micro-case 4, low half (`case = "4lo"`) |
| 11 | `(848,-32,688) … (927,47,767)` | `(832,-48,672) … (943,63,783)` | micro-case 4, high half (`case = "4hi"`) |

**The three chunks are not contiguous: `k_x = 9` is an ungenerated gap chunk**,
never requested in either order. Two consequences, both load-bearing:
`k_x = 8` has **no generated neighbour in any direction, in either order**, so
nothing in the run can rewrite any part of its central slice — which is what
makes `V-01`, `V-02` and `V-04` clean containment and order-stability tests
rather than confounded ones; and `k_x = 10` and `k_x = 11` **are adjacent**, so
each is the other's only generated neighbour and the seam at `x = 847 | 848` is
the sole place a later generation can reach a previously generated central slice
— micro-case 4's object of study.

`content_ignore_count` expectations are **unchanged by the gap**: every compared
region (CORE(8), CORE(10), CORE(11), SEAM) lies strictly inside a *generated*
central slice, so `content_ignore_count == 0` remains a hard gate on every digest
record (12.5). The gap chunk's central slice is partly covered by the emerged
shells of `k_x = 8` (`x ∈ [688, 703]`) and `k_x = 10` (`x ∈ [752, 767]`), created
and blitted back but never marked generated
(`reference_projects/luanti/src/servermap.cpp:341-346`); no compared region
contains any of those voxels, and no readback can trigger the gap chunk's
generation (12.6).

### 6.4 Structure exclusion

`chunk_covers(minp, maxp, x, z, half)` (`mods/MAPGEN/grug_mapgen/structures.lua:492-495`)
is `maxp.x >= x - half and minp.x <= x + half and maxp.z >= z - half and minp.z <= z + half`.
The three anchor families are capitals, half `CAMP_HALF = 12`, at `(0, ±900)`
and `(±550, ±900)` (`mods/CORE/grug_core/init.lua:84-91`, `SEAT_Z = 900` `:27`);
outposts, half `OUTPOST_HALF = 4`, over `grug_core.outpost_candidates`
(`:266-291`, accessor `:306`) — 24 anchors plus retries; and bandit camps, half
`0`, over `grug_core.bandit_camp_candidates` (`:411-444`, accessor `:453`) — 12
anchors plus two lateral retries each.

Enumerating all 138 candidate points and projecting each through `chunk_covers`
onto the `central(k)` lattice yields the envelope `|x| ≤ 1354`, `|z| ≤ 1554` and
exactly **122 distinct `(k_x, k_z)` chunk columns**. The three measured columns
`(8,9)`, `(10,9)` and `(11,9)` are not among them: at `k_z = 9` the entire range
`k_x ∈ [-14, 14]` is structure-free. Therefore `camps`, `outposts` and `fires`
are all empty for every measured chunk, `structures.lua:850-852` returns before
`core.get_mapgen_object("voxelmanip")` at `:854`, and neither
`chunk_near_outpost` (`:559-567`) nor `chunk_near_bandit_camp` (`:761-769`) —
the two x/z-only tests that write POI records and mod storage at any y — is ever
satisfied.

The implementation package must reproduce this enumeration as a committed
self-test (`tools/wp40/t5_probe/coordinate_audit.lua`, 8.1) that recomputes the
122-column set from `mods/CORE/grug_core/init.lua` and asserts the three
measured columns are absent. A hand-copied list is not acceptable evidence.

### 6.5 The capital startup sweep, and why it does not touch the measured bytes

The sweep emerges `(cx − 16, −16, cz − 16) … (cx + 16, 120, cz + 16)` around
each capital (`mods/CORE/grug_core/init.lua:903-921`), on six timers at
`SWEEP_DELAY + (i − 1) · SWEEP_STAGGER` = `60 + 15·(i − 1)` seconds — t ≈ 60 …
135 s (constants `:934-935`, the `core.after` at `:946`). Its z extent is
`[884, 916]`, whose containing chunk column is `k_z = 11`
(`central(11) = [848, 927]`, emerged z `[832, 943]`). The measured chunks'
emerged z range is `[672, 783]` — disjoint by 49 nodes, and the z separation
decides for every capital x column, so no chunk the sweep can generate shares a
voxel with any measured chunk or its emerged shell.

The sweep is therefore **not** a hazard to the measured bytes. It **is** a
hazard to run-to-run comparability: it puts unrelated emerge work on the same
single emerge thread and CPU at t ≈ 60 s, and its short-circuit at
`mods/CORE/grug_core/init.lua:887-893` depends on whether `core.get_spawn_level`
answers, which is seed-dependent and cannot be settled from source. Both
statements are recorded, and the in-run deadlines of 14.2 exist to make the
question moot rather than to answer it.

## 7. Engine-source citation table

### 7.1 Seams

| # | Seam | Verdict | Lua state | Pinned-source citations | Runtime measurement |
| --- | --- | --- | --- | --- | --- |
| S1 | `core.register_mapgen_script(path)` | **AVAILABLE** | **server only** | `reference_projects/luanti/src/script/lua_api/l_server.cpp:643` (`l_register_mapgen_script`), `:654` (`m_mapgen_init_files.emplace_back`), `:723` (`API_FCT` inside `Initialize`); `:726-735` `InitializeAsync` does not contain it. Each emerge thread builds its own Lua state and loads each registered script in registration order (`reference_projects/luanti/src/emerge.cpp:641-668`, loop `:655-658`), then fires `on_mods_loaded` (`:660`); `initScripting` is called once per thread from `run()` (`:684`). `INIT = "emerge"`: `reference_projects/luanti/src/script/scripting_emerge.cpp:29-54`, `reference_projects/luanti/builtin/init.lua:84-85` | already production-proven — `mods/MAPGEN/grug_mapgen/ocean_mask.lua:47` calls it today. Probe measures only script **load wall time** and its callback's **registration index** |
| S2 | `core.register_on_generated(vmanip, minp, maxp, blockseed)` | **AVAILABLE** | mapgen | registration table `reference_projects/luanti/builtin/emerge/register.lua:56`; invocation `reference_projects/luanti/src/script/cpp_api/s_mapgen.cpp:41` (`LuaVoxelManip::create(L, bmdata->vmanip, true)`), `:45-47` (`core.vmanip`), `:50-55` (four args, `runCallbacks(4, RUN_CALLBACKS_MODE_FIRST)`), `:59-60` (nils `core.vmanip`); `minp`/`maxp` are the central chunk `:37-39`. Order: `reference_projects/luanti/src/emerge.cpp:737` `makeChunk` → `:745` `on_generated` → `:753` `finishGen` → `:622-623` main-env `environment_OnGenerated`. `LuaError` → `setAsyncFatalError` + `cancelBlockMake` (`:746-757`) | callback wall time; that all registered callbacks really run (mode 0 short-circuits nothing, `reference_projects/luanti/builtin/common/register.lua:23-29`); the probe's index in `core.registered_on_generateds` |
| S3a | IPC main → mapgen | **AVAILABLE** | both | `ModApiIPC::Initialize` in the emerge state `reference_projects/luanti/src/script/scripting_emerge.cpp:78`, server state `reference_projects/luanti/src/script/scripting_server.cpp:159`, async `:114`; one shared store on `Server` (`reference_projects/luanti/src/server.h:349`, `:157-173`); `API_FCT`s `reference_projects/luanti/src/script/lua_api/l_ipc.cpp:140-143`; deep copy `:21`, `:40`; userdata rejected `:23`; type support `reference_projects/luanti/src/script/common/c_packer.cpp:342-401` | already production-proven — `ocean_mask.lua:46` sets, `ocean_mask_mapgen.lua:60` gets. Probe measures unpack wall time and round-trip fidelity |
| S3b | IPC mapgen → main | **AVAILABLE by source, UNTESTED here** | both | same store, same functions, both states — see S3a. `ipc_cas` is a real CAS (`l_ipc.cpp:65-87`); `ipc_poll(key, ms)` **blocks the calling thread** on a condvar (`:104-121`); there is **no** key enumeration (`:128-133`) | **the genuinely new direction.** Probe writes from the mapgen state and reads from main, recording latency and whether a poll is needed. There is no push notification |
| S4 | IPC at mapgen-script **load** time | **AVAILABLE** | mapgen | `ModApiIPC::Initialize` runs in the `EmergeScripting` constructor before `loadMod` (`scripting_emerge.cpp:78`, `emerge.cpp:641-668`); no init-time guard exists in `l_ipc.cpp` | load-time `ipc_get` wall time |
| S4b-i | `core.vmanip` at load time | **ABSENT — it is `nil`** | mapgen | set only around a callback (`s_mapgen.cpp:45-47`, nilled `:59-60`); the mapgen's own `vm` pointer is cleared after each chunk (`emerge.cpp:635`) | **nothing.** The probe records `type(core.vmanip)` as telemetry only |
| S4b-ii | `core.get_mapgen_object("voxelmanip")` outside a callback | **ABSENT (null dereference, not a clean error)** | mapgen | `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:609-619` reads `mg->vm` at `:610` and dereferences it at `:616` and `:619` with no null check, and `mg->vm` is `nullptr` outside a callback (`emerge.cpp:635`) | **nothing.** A source-settled prohibition |
| S4b-iii | `update_liquids()` at load time | **NOT EXPRESSIBLE — an object method on the VoxelManip, not a global** | mapgen | it exists only as `LuaVoxelManip:update_liquids` (`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:201-206`), which fetches its receiver with `checkObjectValid(L, 1)` and forwards to `ModApiMapgen::update_liquids(L, o->vm)` (`l_mapgen.cpp:1980-1999`). With no VoxelManip object there is nothing to call it on, so "calling it at load time" is an unreachable state, not a guarded one | **nothing.** Recorded so the prohibition is not mis-stated as a runtime guard |
| S4c | `VoxelManip()` as a constructor in the mapgen state | **ABSENT — returns no values** | mapgen | `l_vmanip.cpp:429` opens `create_object` with `GET_ENV_PTR`, which expands to `GET_ENV_PTR_NO_MAP_LOCK` (`reference_projects/luanti/src/script/lua_api/l_internal.h:54-56`); on a null env that macro logs a deprecation line and does `return 0` (`:44-51`, `return 0` at `:49`) — **zero return values, not a `nil`**. `EmergeScripting` never calls `setEnv`, so the env is always null there | `type(VoxelManip)` and, from one guarded `pcall`, the **number of values returned** (expected 0) — never the value of a first result |
| S4d | `core.get_seed`, `get_mapgen_params`, `get_mapgen_chunksize`, `get_mapgen_edges`, `get_mapgen_setting`, `core.settings`, `get_us_time`, `get_version` at load time | **AVAILABLE** | mapgen | `l_mapgen.cpp:2104-2130`; `reference_projects/luanti/src/script/lua_api/l_util.cpp:862-911` | values, and that they agree with the main state's view |
| S4f | `core.registered_nodes` in the mapgen state | **AVAILABLE, with defaults applied** | mapgen | the registration tables are transferred into the emerge state and reassembled at `reference_projects/luanti/builtin/emerge/register.lua:8-27`, each node definition getting `__index = all.nodedef_default` (`:16`) so unset fields resolve to their registered defaults; alias fallthrough `:45` | that the light-relevant and liquid properties the dirty predicates need (10.10) resolve for every content ID the probe writes |
| S5 | mapgen VoxelManip surface | **AVAILABLE, with hard prohibitions** | mapgen | callback arg 1 and `core.get_mapgen_object("voxelmanip")` wrap the same `MMVManip` with `is_mapgen_vm = true` (`s_mapgen.cpp:41`, `l_mapgen.cpp:609-621`). 18 methods at `l_vmanip.cpp:499-518`. See 7.2 | per-call wall time and allocation cost; nothing about availability |
| S6 | emerged area vs central slice | **AVAILABLE** | mapgen | `get_emerged_area` `l_vmanip.cpp:377-387`. **No engine guard restricts Lua writes to the central slice**; border blocks are blitted back but not marked generated (`reference_projects/luanti/src/servermap.cpp:341-346`) | that `emin`/`emax` are exactly `minp-16`/`maxp+16` for these chunks |
| S7 | lighting | **AVAILABLE** | mapgen | mgv7 already lit the chunk before the Lua callback (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:377-379`; `MG_LIGHT` in the default flags `reference_projects/luanti/src/mapgen/mapgen.cpp:210`, `reference_projects/luanti/src/mapgen/mapgen.h:23`). Lua `calc_lighting` runs the same `Mapgen::calcLighting` (`l_vmanip.cpp:208-229` → `l_mapgen.cpp:2001-2017` → `mapgen.cpp:466-472`): `propagateSunlight(pmin,pmax)` then `spreadLight(full emerged)`. The Lua **default** region differs from mgv7's own — Lua defaults to `emin+(0,16,0) … emax-(0,16,0)` (`l_vmanip.cpp:219-222`), mgv7 uses `node_min-(0,1,0) … node_max+(0,1,0)` (`mapgen_v7.cpp:378-379`). Out-of-bounds → `LuaError` (`l_vmanip.cpp:225-226`); `propagate_shadow` defaults true. **There is no "lighting already handled" flag**: `MapBlock::m_lighting_complete` is merely a member initialised to `0xFFFF` (`reference_projects/luanti/src/mapblock.h:542`) and nothing downstream consults it to skip relighting | whether the bounded light upload of 10.10 yields order-stable `param1` across O1/O2 in CORE and SEAM |
| S8 | liquids | **AVAILABLE** | mapgen | mgv7 already ran `updateLiquid` over the full emerged area (`mapgen_v7.cpp:370`), queueing into `bmdata.transforming_liquid`. Lua `update_liquids()` repeats the scan over the full emerged area and appends to the same queue (`l_mapgen.cpp:1993-1997`, `emerge.cpp:731`). `finishBlockMake` drains it via `transformLiquidsLocal` bounded by `liquid_loop_max` (`servermap.cpp:300`), remainder to the global queue (`:305-308`) | wall time of one `update_liquids()` over 1,404,928 nodes, and whether the **post-generation result after bounded local transform, before background settling** is order-stable |
| S9 | timing in the mapgen state | **AVAILABLE (monotonic only)** | mapgen | the mapgen state's util table is `ModApiUtil::InitializeAsync` (`scripting_emerge.cpp:77`); `core.get_us_time()` at `l_util.cpp:866`, body `:77-82`, `reference_projects/luanti/src/porting.h:188-193` + `:156-161` → `CLOCK_MONOTONIC_RAW`. Sandbox whitelists `os.clock/date/difftime/getenv/time` (`reference_projects/luanti/src/script/cpp_api/s_security.cpp:173-179`); `secure.enable_security` defaults true (`reference_projects/luanti/src/defaultsettings.cpp:512`). **Not registered in the emerge state**: `core.get_gametime`, `core.get_timeofday` (`reference_projects/luanti/src/script/lua_api/l_env.cpp:1604-1616`), `core.get_server_uptime` (`l_server.cpp:726-735`) | resolution and monotonicity in practice; whether `os.clock` is usable as a cross-check |
| S10 | memory in the mapgen state | **PARTIAL — Lua heap only** | mapgen | only `collectgarbage` is whitelisted (`s_security.cpp:127`). **No engine-side memory counter is exposed to any Lua state** — absent from `l_util.cpp:862-911`, `l_server.cpp:726-735`, `l_mapgen.cpp:2104-2130`. The profiler is loaded only from the `INIT == "game"` branch (`builtin/init.lua:52-53`); the emerge branch loads only `builtin/emerge/init.lua` (`:84-85`). `reference_projects/luanti/doc/lua_api.md:5668-5670` warns VoxelManip memory is invisible to the Lua GC | the magnitude of `collectgarbage("count")` movement across a `get_data` of 1,404,928 entries — with the caveat that the ~1.4 M-node C++ buffer is **not** in that number |
| S11 | insecure environment in the mapgen state | **ABSENT — proven twice over** | mapgen | `request_insecure_environment` is in `ModApiUtil::Initialize` only (`l_util.cpp:770`), and an explicit source comment at `:888` — `// no request_insecure_environment here! mod origins are not tracked securely here.` — sits inside `InitializeAsync`, which **is** the mapgen state's table (`scripting_emerge.cpp:77`). Even if reached, `EmergeScripting` inherits `modNamesAreTrusted() == false` (`reference_projects/luanti/src/script/cpp_api/s_security.h:80`; only `reference_projects/luanti/src/script/scripting_server.h:54` overrides to true), so `getCurrentModName` returns `""` (`s_security.cpp:726-732`) and `checkModNameWhitelisted` fails on the empty name (`s_security.cpp:760-771`, reached from `l_util.cpp:529-531`) | **nothing — this cannot be measured because it cannot exist.** The absence is the recorded result (`has_request_insecure_environment: false`). **This is the single statement of the S11 proof;** 12.4 and 21 reference it and do not restate it |
| S12 | determinism and chunk order | **HAZARD PRESENT BY CONSTRUCTION** | both | per-chunk decisions are order-independent (`mapgen_v7.cpp:318`) and the mapgen Lua state persists across callbacks on its thread (`reference_projects/luanti/src/emerge_internal.h:56`) while per-chunk C++ state does not (`emerge.cpp:692`, `reference_projects/luanti/src/emerge.h:47`). **But** `initBlockMake` emerges chunk ± 1 block and seeds the border from whatever is on the map (`servermap.cpp:229-244`, `:253-254`, `reference_projects/luanti/src/map.cpp:804-806`), and `blitBackAll` writes that border back with `overwrite_generated = true` (`servermap.cpp:291`, `reference_projects/luanti/src/map.h:334-335`, `map.cpp:860-896`). Liquid update and light spreading both run over the full padded area (`mapgen_v7.cpp:370`, `mapgen.cpp:471-472`). The engine's own comment names the upstream issue at `emerge.cpp:181-186`, "Singlenode is currently the only mapgen not affected by the unfinished slice bug", referencing `https://github.com/luanti-org/luanti/issues/9357` — **cited as engine-documented context for why request order matters, not as something this probe tests** (10.13). Chunk order is request-driven FIFO (`emerge.cpp:487-490`, `:698-711`) with load-balanced thread assignment (`:437-455`) | **the magnitude and location of any order effect** in CORE and SEAM, separately for the paired control and the treatment (10.9, `V-06`) |
| S13 | engine identity | **AVAILABLE** | both | `core.get_version()` at `l_util.cpp:893` (async/emerge) and `:775` (server); fields `:540-564` — `hash` present only when it differs from `string`. `core.get_game_info()` also in the emerge state (`l_server.cpp:734`). `jit` table whitelisted (`s_security.cpp:193-203`, `:319-326`) and simply absent on PUC | the realized `string`/`hash`/`is_dev`/`jit.version` on the run host |
| S14 | per-voxel provenance | **ABSENT** | mapgen | the only voxel flags are `VOXELFLAG_NO_DATA` and `CHECKED1..4` (`reference_projects/luanti/src/voxel.h:349-353`), and `CHECKED*` are lighting/liquid scratch bits. `LuaVoxelManip` exposes 18 methods (`l_vmanip.cpp:499-518`) and **no flags accessor of any kind**. `get_data` collapses `NO_DATA` to `CONTENT_IGNORE` (`:109`), making them indistinguishable. In a **mapgen** VM `NO_DATA` is never set at all: `initBlockMake` pre-creates every block in the full area (`servermap.cpp:229-244`) before `initialEmerge` (`:254`), and `initialEmerge` only sets `NO_DATA` where `getBlockNoCreateNoEx` returns null (`map.cpp:804-816`), which can no longer happen; a never-generated shell block is a fresh MapBlock of `CONTENT_IGNORE` (`reference_projects/luanti/src/mapblock.cpp:110`). `block->isGenerated()` is not bound to Lua | **nothing — this cannot be measured because it does not exist.** It is why halo/border provenance is established by controlling generation order (10.6) rather than by an in-callback signal, and why CORE excludes the outer MapBlock (10.3) |

### 7.2 The mapgen VoxelManip surface, in full

All citations `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp`.

| Method | Lines | Contract that matters here |
| --- | --- | --- |
| `get_data([buf])` | `:92-114` | 1-indexed flat array over the **entire emerged area**; `NO_DATA` collapses to `CONTENT_IGNORE` at `:109`; optional reuse buffer at `:97`, applied `:102-105` |
| `set_data(t)` | `:117-145` | content IDs only; **clears `VOXELFLAG_NO_DATA` over the whole area as a side effect**; errors on a non-table |
| `get_param2_data([buf])` / `set_param2_data(t)` | `:308-355` | same full-volume contract |
| `get_light_data([buf])` / `set_light_data(t)` | `:259-306` | this is **`param1`** = `day + night*16`, full volume. `get_light_data` accepts a reuse buffer at `:264` |
| `calc_lighting([pmin],[pmax],[shadow])` | `:208-229` | mapgen-VM only; defaults at `:219-222`; out-of-bounds `LuaError` at `:225-226` |
| `set_lighting(light,[pmin],[pmax])` | `:231-257` | mapgen-VM only |
| `update_liquids()` | `:201-206` → `l_mapgen.cpp:1980-1999` | appends to the emerge thread's queue |
| `get_emerged_area()` | `:377-387` | returns `MinEdge`, `MaxEdge` |
| `was_modified()` | `:362-375` | whole-VM boolean; `reference_projects/luanti/doc/lua_api.md:5662` says do not use it — **the probe does not** |
| `update_map()` | `:357-360` | **pure no-op, `return 0`** — the probe does not call it |
| `get_node_at` / `set_node_at` | `:499-518` (registration) | per-node accessors; **the probe does not call them** — every access is whole-buffer, so operation counts stay exact |
| `write_to_map` | `:147-157` | **forbidden, hard `LuaError` in the mapgen env** (`:156-157`) |
| `read_from_map` | `:35-45` | **forbidden, hard `LuaError` in the mapgen env** (`:44-45`) |
| `initialize` | `:58-66` | throws on a mapgen VM (`:65-66`) |
| `close` | `:389-396` | throws on a mapgen VM (`:395-396`) |

**The engine writes the mapgen VM back automatically**:
`reference_projects/luanti/src/emerge.cpp:599` → `reference_projects/luanti/src/servermap.cpp:291`
`data->vmanip->blitBackAll(changed_blocks)` with `overwrite_generated` defaulting
to true (`reference_projects/luanti/src/map.h:334-335`). Lua must not and cannot
call `write_to_map`. The VM's lifetime ends with the callback
(`reference_projects/luanti/src/emerge.h:47`); a retained reference raises
`"LuaVoxelManip::checkObjectValid(): vm is null"` (`l_vmanip.cpp:18-22`).

### 7.3 Split: settled by source versus left for runtime measurement

**Settled by pinned source — re-confirmed at most, never re-litigated:** S1
availability and state; S2 signature, argument meaning and call order;
S3a/S3b/S4 IPC availability in both states; the S4b-i/ii/iii and S4c
prohibitions; S4f the presence and default resolution of `core.registered_nodes`
in the mapgen state; S5 the method set and its four hard prohibitions; S6
emerged geometry and the absence of a write guard; S7 the absence of a
"lighting handled" flag and the Lua-versus-mgv7 default region difference; S8
that mgv7 already ran a full-area liquid update; S9 the API set and the three
absent time functions; S10 the absence of any engine memory counter; S11 the
absence of the insecure environment; S12 the border-seeding and blit-back
mechanism; S14 the total absence of per-voxel provenance.

**Left for runtime measurement — nothing below is asserted anywhere in this
contract:** every wall time and every heap number; S3b's practical latency and
whether a poll is required; the magnitude and extent of any S12 order effect in
CORE and SEAM; whether `B − A1` is byte-identical across O1 and O2; the realized
values of `c` / `p` / `q` / `l`; whether the run fits the in-run deadlines;
whether process RSS is obtainable at all on the run host; and the realized value
of every setting in section 5's `engine` class.

## 8. Implementation boundary and file ownership

### 8.1 Every file the follow-on package may create

**The package boundary, defined once.** Sections 17 and 18 reference this and do
not restate it. The follow-on package may create or modify a file **only** if its
path matches one of these four patterns, and nothing else:

```
tools/wp40/t5_probe/**                       # the probe tree (this section)
tools/wp40/evidence/t5-probe-*/**            # reviewed evidence (13.3)
.gitattributes                               # one appended line (13.3)
docs/research/wp40-t5-0-engine-probe-contract.md   # this contract only
```

The `docs/` entry is exhaustive and deliberately names one file. It excludes in
particular `wp40-engineering-brief.md`, `wp40-t2-contracts.md` and
`wp40-t2-plan.md` — the authorities 1.1 declares binding — and equally
`docs/design/world_zones.md`, `docs/design/world.md`,
`docs/process/wp-workflow.md`, `docs/research/luanti-lua.md`, `AGENTS.md` and
`ROADMAP.md`. A boundary check phrased as "…and `docs/`" would let the package
silently edit the very documents it is measured against.

| Path (all under `tools/wp40/t5_probe/`) | Purpose |
| --- | --- |
| `README.md` | contract link, non-claims, how to re-run, evidence layout, disposal rule and checks |
| `run_t5_probe.sh` | runner: preflight, static gates, self-tests, four engine captures, evidence assembly |
| `verify_log.sh` | fail-closed three-stage gate on one run's raw log (12.5) |
| `compare_runs.sh` | cross-run digest comparison; verdicts `V-01`…`V-09`; 10.13's cascade; emits and gates the comparison stream (12.7) |
| `selftest.sh` | every offline negative fixture of section 16 for both gates, **plus** the manifest-digest fixture in the shape of `tools/wp40/dungeon_probe/digest_audit.sh:17-43` |
| `digest_lib.sh` | thin re-use wrapper; canonicalization follows `tools/wp40/dungeon_probe/digest_lib.sh:27-34` and `:50-56` |
| `coordinate_audit.lua` | recomputes the 122-column structure envelope and the Ocean Mask derivation of 6.2 from repository source, asserting the three measured columns are excluded |
| `driver/mod.conf` | driver mod manifest; `depends = grug_mapgen` so the payload registers **after** `ocean_mask_mapgen.lua` |
| `driver/init.lua` | main-state driver: arm switch, IPC publish and readback, emerge scheduling, main-env `on_generated` telemetry, bounded readback, lane digests, deadlines, shutdown |
| `payload/mapgen.lua` | the registered mapgen script: load-time telemetry, the box literals, the case dispatcher |
| `payload/vm_proxy.lua` | the counting/timing wrapper; **the only file permitted to touch the raw VoxelManip object** |

That is **eleven** files. The package creates **no** production file, **no** file
under `mods/`, **no** production registration and **no** second reusable adapter.
The driver mod loads only because the generated disposable world's game tree
contains it; nothing in the committed game tree references it. **Files an earlier
draft listed and this one does not**, so the reduction is visible rather than
silent: `verify_log_test.sh`, `compare_runs_test.sh` and `digest_audit.sh` are
one `selftest.sh`; `payload/cases.lua` is folded into `payload/mapgen.lua`;
`driver/readback.lua` into `driver/init.lua`; and `probe_tree_manifest.sh` is
dropped with the content-hash disposal apparatus it served (section 20).

### 8.2 Rules the implementation inherits and may not renegotiate

| Rule | Source |
| --- | --- |
| `#!/usr/bin/env bash` + `set -euo pipefail`; paths from `BASH_SOURCE`, never hardcoded; runners `bash -n` themselves and their siblings; one `WP40 t5-probe …` success line, failures to stderr | `tools/wp40/run_dungeon_probe.sh` |
| Exit codes `0` pass, `2` preflight failure or refusal to overwrite an immutable result, `124` outer timeout (always fails the capture) | `tools/wp40/README.md:1113-1117`. This package additionally uses `1` for a failed gate and `127` for a missing tool, matching the sibling runners; both are stated here because `tools/wp40/README.md` does not fix them |
| `rg` preflight mandatory and non-negotiable; `jq` hard-required up front | `tools/wp40/run_t1.sh:4-9`; `AGENTS.md:133-136` (until 2026-08-15 a missing `rg` made nine gates report success without running); `tools/wp40/run_dungeon_probe.sh:15-18` |
| Self-tests and static gates run **before** the expensive half; the expensive half is opt-in and skip-not-fail | `tools/wp40/run_dungeon_probe.sh:20-27`, `:29-32` |
| `tools/bin/luac51 -p` on every probe Lua file; `luac51 -l -p \| grep SETGLOBAL` → zero lines for a tools-only file, at most one (the mod table) for a mod `init.lua`; the five sweeps of `docs/research/luanti-lua.md:310-321` run **explicitly** against `tools/`, because `AGENTS.md:130-133` scopes them to `mods/*/grug_*` | in-tree implementations `tools/wp40/t2_source_audit.sh:363-393`, `tools/wp40/run_t2_partition_c2_selected.sh:43-55`; `docs/research/luanti-lua.md:260-261` (a single mod-table global is permitted, not required; `tools/wp40/dungeon_probe/init.lua` has zero) |
| The twelve do-not-write rules: `core.*` never `minetest.*`; `unpack` not `table.unpack`; `math.floor(a/b)` not `//`; no `\x`, `\u{}` or `\z` escapes; `string.char(124)` instead of a literal pipe so sweep 4 stays clean | `docs/research/luanti-lua.md:240-266`, `:266` |
| `WP40_LUA_BIN` defaulting to LuaJIT; offline self-tests under a dual-interpreter byte gate comparing stdout **and** exit status | `tools/wp40/run_t2_s1_authority.sh:38-45`; `tools/wp40/run_t2_s11_acceptance.sh:22-44` |
| A T5-0 engine-seam probe is a **layer-6** activity, and a real fallback-engine run is a separate gate never inferred from offline equality | `docs/research/luanti-lua.md:346-371`; `docs/process/wp-workflow.md:78-79` |
| `tools/sync_to_luanti.sh` is never called | `docs/process/wp-workflow.md:42-45`; `tools/wp40/README.md:1105-1109`; `tools/wp40/dungeon_probe/README.md:62-63` |
| Scratch under `mktemp -d /tmp/grudgelands-wp40-t5-probe.XXXXXX` with a matching `case`/`esac` prefix guard and `trap cleanup EXIT INT TERM`; the slug is distinct from every existing script's | `tools/wp40/run_dungeon_probe.sh:39-46` |
| Results are immutable: refuse to overwrite an existing result directory, exit 2. `tools/wp40/results/` is ignored; reviewed evidence is committed by overriding `WP40_RESULTS_ROOT` | `tools/wp40/capture_t0_baseline.sh:81-83`, `:18-21`; `.gitignore:11`; `tools/wp40/README.md:1109-1111` |
| Raw evidence is whitespace-protected by extending `.gitattributes` | `.gitattributes:1`; rationale `tools/wp40/dungeon_probe/README.md:48-51`; reviewer instruction `tools/wp40/README.md:393-404` |
| **Do not copy `--terminal`** — it logs an ncurses error in every capture | `tools/wp40/run_dungeon_probe.sh:117` |

### 8.3 Locked T2 surfaces — explicit clause

The follow-on package **touches none of the six locked T2 surfaces**
(`wp40-t2-plan.md:227-234`), neither by editing them, nor by `dofile`ing them,
nor by depending on or duplicating their behaviour:

```
tools/wp40/t2_s1_authority.lua
mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua
mods/MAPGEN/grug_mapgen/wp40/canonical.lua
mods/MAPGEN/grug_mapgen/wp40/deterministic.lua
mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua
mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua
```

"No work package may touch them as a side effect." (`wp40-t2-plan.md:237`) In
particular, `mods/MAPGEN/grug_mapgen/wp40/canonical.lua` is a locked surface and
the probe's canonical serialization (section 12.6) is defined independently and
must not import or reproduce it. The reviewer check is in section 18, item 3.

---

## 9. Synthetic payload definition

**Schema tag:** `grug_wp40_t5_probe_synthetic_v0`. It is the first canonicalized
line of the payload digest (shape of
`tools/wp40/dungeon_probe/digest_lib.sh:27-28`) and the `schema` field of every
JSON record. The trailing `v0` announces that nothing here is a version-1
anything.

**What the payload contains — exactly four things:**

1. **six literal box tuples** — the write extents of 10.10, as
   `{minx, miny, minz, maxx, maxy, maxz}` integer sextuples with no name, type,
   priority or owner field;
2. **five literal registered node names** — `"air"`; `"default:stone"`
   (`mods/BASE/default/nodes.lua:259`); `"default:water_source"` (`:2204`,
   `paramtype = "light"` `:2231`, `liquidtype = "source"` `:2239`);
   `"default:goldblock"` (`:1298-1304`; opaque, no light source, no
   `paramtype2`, `is_ground_content = false` at `:1301`); and
   `"stairs:stair_cobble"` (`mods/BASE/stairs/init.lua:525-534`;
   `paramtype = "light"` `:98`, `paramtype2 = "facedir"` `:99`) — each resolved
   once per mapgen state through `core.get_content_id`, which the emerge state
   registers in `ModApiItem::InitializeAsync`
   (`reference_projects/luanti/src/script/lua_api/l_item.cpp:716-720`, the
   `API_FCT` at `:719`);
3. **one integer `param2` constant** (`1`), written into the facedir box;
4. **a case dispatcher** keyed on `minp.x` alone, with three branches.

**What it deliberately avoids.** The payload borrows no record name, field name,
operation-type name, conflict rule, priority ordering, resolver identifier, zone
identifier, feature identifier, envelope name or vocabulary token from T2
(`wp40-engineering-brief.md:2249-2257`, and by construction none of
`:2259-2261`), T3 (`:4089`, `:2423-2470`), T4 (`:4090`, `:2109-2113`) or T6/T7
(`:4092-4093`). The reason is not stylistic: a synthetic payload that reuses the
production vocabulary invites the next reader to treat its shape as a precedent,
and this probe's whole value depends on nobody being able to claim later that
T5-0 "already decided" a field name. `default:water_source` is used only as a
**registered node name that exists in this world**; that is not an adoption of
the single decided surface-water identity (`:1354-1355`), and the probe makes no
hydrology claim.

**The payload registers zero nodes.** The driver and payload call
`core.register_node` zero times, so the world's content-ID assignment is
identical in both arms — which is what makes the asserted-identical id→name
table of 10.4 sound.

## 10. Test matrix — the four micro-cases over three mapchunks

### 10.1 Two arms, four logical micro-cases

| Arm | Mapgen script | Callback body | Purpose |
| --- | --- | --- | --- |
| `A1` | **registered** | zero VoxelManip calls and zero writes on all three chunks; load-time telemetry, IPC and per-callback timing only | **micro-case 1 and the paired control at the same time** |
| `B` | **registered** (identical file) | the three-chunk synthetic payload | treatment |

`B − A1` is the payload delta and the only delta this probe computes. The four
micro-cases of `wp40-acceleration-and-delivery-plan.md:497-502` map onto it as:

| Micro-case | Where it lives | What it establishes |
| --- | --- | --- |
| **1 — zero-VoxelManip callback / control** | **arm `A1`, all three chunks** — it is the arm, not a dedicated chunk | the floor cost of a mapgen callback that dispatches and returns, and the paired per-order control every byte comparison is measured against |
| **2 — bounded cut/fill cell** | chunk `k_x = 8` | one content transaction with a bounded content dirty set, dirty-gated lighting with a bounded light upload |
| **3 — water plus an independently exercised `param2` cell** | chunk `k_x = 8`, **separate coordinates and a separate mask** from micro-case 2 | that `set_param2_data` is a distinct, separately gated upload alongside `set_data`, proved by which boxes changed rather than by how many voxels changed |
| **4 — the two halves of one boundary-crossing feature** | chunks `k_x = 10` and `k_x = 11` | whether each half persists across the other chunk's later generation, in both orders (10.13) |

Micro-cases 2 and 3 are colocated in one chunk on purpose: they share one
`get_data`, one lighting sequence and one liquid decision, so colocating them
costs one chunk instead of two while keeping their write masks disjoint by
coordinate.

### 10.2 One mod set, one archive, one switch

There is exactly **one** driver mod and **one** payload file in all four runs,
and `core.register_mapgen_script` is called in **both** arms.

The driver mod is copied into the archived **game** tree under
`<archive>/mods/`, exactly as both in-tree precedents do
(`tools/wp40/run_dungeon_probe.sh:63-65`,
`tools/wp40/capture_t0_baseline.sh:105-108`), where game mods load
unconditionally. The generated `minetest.conf` names the mod only in
`secure.trusted_mods`, for the best-effort process-metric read of 12.4 — that is
**not** the loading mechanism, and nothing in the committed game tree references
the mod.

The arm is one generated configuration key, read by the driver at load time and
republished over IPC: `grug_wp40_t5_probe.arm = A1 | B`. Consequently the mod
set, dependency graph, load order, mapgen-script registration and the payload's
index in `core.registered_on_generateds` are byte-identical in both arms — the
arms differ only in what the callback *does*; the injected-payload digest is
identical in every run; and the only per-run configuration difference is two keys
(`arm`, `order`) plus the per-run `port`. The price is non-claim 12: with no
script-free arm, the probe cannot say whether registering a mapgen script is
itself byte-neutral.

### 10.3 Regions

| Region | Definition | Size | Why |
| --- | --- | --- | --- |
| **CORE** | each measured chunk's central slice shrunk by one MapBlock (16 nodes) on every side: `x ∈ [-16+80k_x, 31+80k_x]`, `y ∈ [-16, 31]`, `z ∈ [704, 751]` | 48³ = 110,592 nodes per chunk | it excludes exactly the rind a neighbour's generation reaches **through direct emerged-VM overlap** — the mechanism and its citations are S12 and `mapgen.cpp:952` for native dungeons, and are not restated here. **The shrink is not a claim of immunity to every neighbour side effect:** it does not exclude a later neighbour's `transformLiquidsLocal` reaching shared border liquid (10.15), light propagating inward from a relit border (`V-02`'s margin argument bounds that), or any main-environment callback. For `k_x = 8` those residual channels are closed by construction anyway, because no neighbour of `k_x = 8` is ever generated (6.3) |
| **SEAM** | the named box `(824, -16, 696) … (871, 23, 735)` | 48 × 40 × 40 = 76,800 nodes | straddles the `x = 847 \| 848` chunk boundary by 24 nodes on each side and contains both micro-case-4 write extents and both of their light-write boxes. Compared arm-to-arm **within** an order, and across orders against its paired control |

Micro-cases 2 and 3 write only inside CORE(8); micro-case 4 writes only inside
SEAM, and its write extents are disjoint from CORE(10) and CORE(11).

CORE(11).

### 10.4 Comparison lanes

Following `wp40-engineering-brief.md:3004-3011` — "Database bytes, compression
order, timestamps, and block serialization layout are not compared" (`:3004-3005`)
— the probe compares **decoded node lanes**, not database bytes: `content`
(2 bytes, big-endian, the `get_data` value), `param2` (1 byte), `light_day`
(`param1 % 16`) and `light_night` (`math.floor(param1 / 16)`).

The brief hashes "content IDs mapped back to canonical registered node names"
(`:3009`). The probe hashes the raw content IDs **and** asserts (`X-01`) that the
id→name table is byte-identical across the run set; given that assertion the two
are equivalent, because a bijection applied identically to both sides of an
equality test cannot change its outcome. Emitting a node name per node would
multiply the compared payload by roughly an order of magnitude for no additional
discriminating power. If the assertion fails the run aborts (`A-04`) and no lane
comparison is reported. The probe registers **zero** nodes precisely so it can
hold (section 9).

**Canonical form of `content_id_table_sha256`:** labelled `key=value` lines in
the shape of `tools/wp40/dungeon_probe/digest_lib.sh:27-34`, first line
`schema=wp40-t5-probe-content-id-table-v1`, then one `name=` / `id=` pair per
registered node **sorted ascending by node name**, hashed with `core.sha256`.
Two rules are load-bearing and are reviewer item 14: **the id must be bound, not
only the name** — a digest over a sorted name list alone satisfies `X-01` while
leaving a permuted id assignment undetected, which would make every content-lane
comparison differ for a reason unrelated to the payload — and **the order must be
an explicit `table.sort`, never `pairs()`**, whose iteration order is unspecified
and would abort all four runs with `A-04`.

### 10.5 Case-to-chunk assignment

| Chunk | `case` | Carries | Content write | `param2` write |
| --- | --- | --- | --- | --- |
| `k_x = 8` | `"bounded"` | micro-cases 2 and 3 | 4 boxes, 2,048 voxels, all strictly inside CORE(8) | 1 box, 512 voxels |
| `k_x = 10` | `"4lo"` | micro-case 4, low half | 1 box, 512 voxels, inside SEAM, disjoint from CORE(10) | none |
| `k_x = 11` | `"4hi"` | micro-case 4, high half | 1 box, 512 voxels, inside SEAM, disjoint from CORE(11) | none |

The literal boxes are in 10.10. In arm `A1` the callback emits the same `case`
value for the same chunk and performs no write of any kind.

### 10.6 Orders

**O1** = ascending `k_x`: 8, 10, 11. **O2** = descending `k_x`: 11, 10, 8. Both
are serialized one chunk at a time — `core.emerge_area(pos, pos, cb)` at the
chunk centre, completion `calls_remaining == 0`, chained with
`core.after(0, emerge_next)`, the pattern of
`tools/wp40/dungeon_probe/init.lua:9`, `:29`, `:36-37`. Kick-off is
`core.register_on_mods_loaded` plus one `core.after(0, …)` (`:42`, `:75`), never
a globalstep. Termination is `core.request_shutdown(msg, false, 0.1)`; the
0.1-second delay is the `tools/wp40/runtime_probe/init.lua:179` pattern and
exists so appended log writes flush.

### 10.7 The full matrix

| Run | Arm | Order | Chunks generated, in request order | World | Port |
| --- | --- | --- | --- | --- | --- |
| 1 | `A1` | `O1` | `k_x` 8, 10, 11 | fresh disposable | 32001 |
| 2 | `A1` | `O2` | `k_x` 11, 10, 8 | fresh disposable | 32002 |
| 3 | `B` | `O1` | `k_x` 8, 10, 11 | fresh disposable | 32003 |
| 4 | `B` | `O2` | `k_x` 11, 10, 8 | fresh disposable | 32004 |

`4 runs × 3 chunks = 12 mapchunk generations`, the total stated in the header.
Every run gets its own fresh disposable world; no world is reused between arms or
orders (13.1).

### 10.8 Cross-run assertions that must hold before any comparison is reported

| ID | Assertion | Failure |
| --- | --- | --- |
| `X-01` | `content_id_table_sha256` identical across all four runs | abort `A-04` |
| `X-02` | realized mapgen-settings digest identical across all four runs | abort `A-06` |
| `X-03` | realized emerge order identical within an order across arms | abort `A-07` |
| `X-04` | injected payload digest identical across all four runs | abort `A-02` |
| `X-05` | engine identity (`version.string`, `version.hash`, `lua_runtime`) identical across all four runs | abort `A-03` |
| `X-06` | for every chunk that legitimately obtains them — all three chunks in arm `B` — `emin`/`emax` equal `minp − 16` / `maxp + 16`. Arm-`A1` callbacks report `null` by contract (section 12.3) and are **skipped**, not asserted; S6's runtime confirmation is therefore scoped to arm `B` | abort `A-08` |

### 10.9 Verdicts

`O` ranges over `{O1, O2}`. "Equal" always means equal decoded-lane SHA-256 over
the named region.

| ID | Comparison | Expected | If it does not hold |
| --- | --- | --- | --- |
| `V-01` | **content and `param2`:** `CORE(B, O) == CORE(A1, O)` over **CORE minus the union of the case's content/`param2` write boxes**, per chunk | equal | the payload wrote content or `param2` outside its declared extent. **Gate fails.** Evaluated on **both** lanes; narrowing it to content silently loses `param2` containment (reviewer item 6). Residuals: 108,544 voxels for `k_x = 8`; the full 110,592 for `k_x` 10 and 11, whose write extents do not meet CORE at all. The union, not a bounding box — see `digest_excl` in 12.3 |
| `V-02` | **light lanes:** `CORE(B, O) == CORE(A1, O)` over **CORE minus the light-write box**, per chunk | equal | the probe's light upload escaped its declared box. **Gate fails.** Residuals: 52,560 voxels for `k_x = 8`, 102,346 for each of `k_x` 10 and 11. **Attributing a failure to the probe rather than the engine needs a margin argument, and here it is.** For `k_x = 8` it is unconditional: no neighbour of that chunk is ever generated (6.3). For `k_x` 10 and 11 the neighbour's *native* `calcLighting` does see arm-differing border content — in O2, chunk 10 generates with chunk 11's bar already on the map — so a native light difference really can propagate inward. It cannot reach CORE: `spreadLight` decays each bank by exactly 1 per node (`reference_projects/luanti/src/mapgen/mapgen.cpp:438-445`) and stops at `light <= 1` (`:432`) from a maximum of `LIGHT_SUN = 15` (`reference_projects/luanti/src/light.h:22`), so a difference originating at `x = 848` reaches no further inward than `x = 833`, while CORE(10) ends at `x = 831`; symmetrically `x = 847 + 15 = 862` against CORE(11) starting at `x = 864`. **A 2-node margin on each side**, and the bar's y and z extents lie strictly inside CORE's, so x is the whole argument. Within that margin a `V-02` failure is a probe bug, not an engine observation; the engine-side residual is `A-16` |
| `V-03` | **the delta is present where declared:** on `content`, `digest_incl(B, O) != digest_incl(A1, O)` over every named box whose `dirty_content_by_box` entry is non-zero, and equal over every box whose entry is zero; on `param2`, `digest_incl` differs over the **facedir** box iff `dirty_param2_by_box.facedir > 0`, and is **equal** over `cut`, `fill`, `water`, `4lo` and `4hi` always — the last two because micro-case 4 declares no `param2` write at all (10.10) | as stated | equality inside a box with a non-zero by-box dirty count means the write did not survive the blit — a first-class engine result, not a gate failure. A `param2` difference over any of the five boxes the payload never writes `param2` into **is** a gate failure: the write mask was not the declared box. This verdict is evaluable only because `chunk_callback` carries the by-box counts; the scalars cannot answer it |
| `V-04` | `CORE(B, O1) == CORE(B, O2)` per chunk, per lane | equal | order dependence inside CORE, read against `V-06`'s CORE half. For `k_x = 8` both are expected equal trivially, since no neighbour of that chunk is ever generated (6.3), so a difference there is a finding about mapgen-state carry-over rather than about neighbours |
| `V-05` | **content and `param2` over SEAM:** the paired-order cascade of 10.13 | a licensed outcome, not necessarily "equal" | outcomes are `no_delta`, `persisted`, `order_effect`, `no_stable_baseline`, `inconclusive`, `no_signal_by_construction`. Only `persisted` with its corroboration is a pass. **No outcome attributes a cause to the engine** |
| `V-06` | **the paired control's own order dependence, in both compared regions:** `CORE(A1, O1) == CORE(A1, O2)` per chunk and `SEAM(A1, O1) == SEAM(A1, O2)`, per lane | unknown, measured | any difference is reported **separately** as native engine order dependence, localized by `first_diff`. Both halves are load-bearing: the SEAM half is what `V-05` is read against, and the CORE half is what `V-04` is read against — without it a native order effect confined to CORE(10) or CORE(11) would be misread as a payload effect. The digests already exist in both arms and both orders, so this costs no extra readback |
| `V-07` | operation counts equal the matrix of 10.11, conditioned on the arm and on the `c`/`p`/`q`/`l` predicates the same record carries | equal | gate fails |
| `V-08` | **light lanes over SEAM:** `SEAM(B, O1) == SEAM(B, O2)` and `SEAM(B, Oi) == SEAM(A1, Oi)` | unknown, measured | an observation only. Arm `A1` performs zero lighting calls, so a light-lane `B − A1` is a different computation per arm over overlapping inputs, not a payload delta. **This probe does not test the brief's halo-light idempotence exception** (`wp40-engineering-brief.md:1471-1474`): with the restore of 10.10 it writes no halo light at all |
| `V-09` | **quiescence:** the two readback digest sets of 10.15, ≥ 2 s apart, identical in every run | equal | **no verdict of any kind is reported** — abort `A-13` |

### 10.10 Case definitions

All boxes are inclusive integer ranges. "Write extent" is the fixed set of
voxels the payload assigns; "realized dirty set" is the subset whose value
actually changes, which depends on the native baseline and is therefore
**measured, not asserted**.

#### The four realized predicates, and the conditionality rule

Every count and every verdict in this section is conditional on predicates the
callback computes from its own pre-write buffers, before any write. **The rule
is stated once here and is never repeated per case.**

| Symbol | Predicate | Computed from |
| --- | --- | --- |
| `c` | the realized **content** dirty set is non-empty | the `get_data` buffer versus the intended content IDs |
| `p` | the realized **`param2`** dirty set is non-empty | the `get_param2_data` buffer versus the intended values, over the declared `param2` mask only |
| `q` | **liquid dirty:** some voxel in the realized content dirty set has an old **or** new node whose `liquidtype` is not `"none"` | `core.registered_nodes` in the mapgen state (S4f), resolved once at load time |
| `l` | **`light_dirty`:** some voxel in the realized content dirty set has old and new nodes differing in `L(id) = (paramtype == "light", sunlight_propagates, light_source)` | the same load-time resolution as `q` |

`L` is the brief's rule — "every voxel whose old and final nodes differ in
`light_propagates`, `sunlight_propagates`, or `light_source`"
(`wp40-engineering-brief.md:1426-1428`) — in the Lua-visible fields those C++
members are read from: `light_propagates = (param_type == CPT_LIGHT)`
(`reference_projects/luanti/src/script/common/c_content.cpp:884`), `paramtype`
`:861`, `sunlight_propagates` `:885`, `light_source` `:936-937`, `liquidtype`
`:907-908`. Unset fields resolve through `nodedef_default` (S4f).

**The conditionality rule.** This contract states **no precondition** that any
of `c`, `p`, `q`, `l` is true. Every realized dirty count is emitted — per box
in `dirty_content_by_box` / `dirty_param2_by_box`, and as their scalar sums — and
every expected call count and every expected verdict reads the predicates off the
same record. A run in which one comes out false is an observation (section 15),
never a failure. Four consequences follow, all deliberate:

- `l` and `q` are defined over the realized **content** dirty set, so
  `c = false ⇒ l = false ∧ q = false`. **A realized content no-op performs zero
  lighting and zero liquid work** — the brief's own rule (`:2172-2175`,
  `:1086-1087`).
- `param2` carries no light-relevant property, so a `param2`-only change leaves
  `l` false: `paramtype2 = "facedir"` (`mods/BASE/stairs/init.lua:99`) is a
  rotation.
- `l` is genuinely conditional, not a disguised constant. Micro-case 4 writes
  `default:goldblock`, which sets no `paramtype`, no `sunlight_propagates` and no
  `light_source` (`mods/BASE/default/nodes.lua:1298-1304`), exactly like
  `default:stone` (`:259`): into stone it does **no lighting work at all**, into
  air it runs the full sequence. Which happens is measured, never assumed.
- Every writing case captures the same evidence, listed once: per-call wall time,
  the four predicates and all realized dirty counts, both
  `collectgarbage("count")` samples, that chunk's four lane digests, its
  `digest_excl` residuals, `digest_incl` over each of its named boxes, the
  light-restore counter and hash pair, and its `case_baseline`.

#### The mandated operation sequence, for any case that writes

Seven steps in this order, on the same mapgen VoxelManip, with no intervening
map write:

1. `get_emerged_area()`, then `get_data(buf)` into a payload-owned reuse buffer
   (`l_vmanip.cpp:97`); `get_param2_data(buf2)` too if the case declares a
   `param2` mask.
2. Compute the realized dirty sets, per box and in total, and the four
   predicates. Nothing is written yet, so these buffers are also the case's
   native baseline (`case_baseline`).
3. If `l`: `get_light_data(snap)` — the pre-commit `param1` snapshot over the
   **full emerged VM** (`wp40-engineering-brief.md:1435`).
4. If `c`: exactly one `set_data`. If `p`: exactly one `set_param2_data` — two
   separately gated uploads, never conflated (`:2168-2171`, `:2181-2183`).
5. If `l`: exactly one `set_lighting(0, light_write_box)` zeroing both banks
   (`:1439-1441`), then exactly one `calc_lighting(pmin, pmax, true)` over the
   complete emerged x/z extent and the central chunk's y range (`:1446-1450`),
   then `get_light_data(calc)` (`:1451`).
6. If `l`: **restore.** Set `calc[i] := snap[i]` for every voxel outside the
   `light_write_box`. Then verify with a traversal built **independently** of the
   restore's (12.6): `restored_outside_dirty_mismatch_count` must be `0` and
   `light_outside_box_snapshot_sha256` must equal
   `light_outside_box_restored_sha256`. This is the brief's step 4 — "restores
   the snapshotted `param1` byte outside the analytically allowed dirty/owned
   light result … Any computed difference outside the allowed result is also
   reported as a preservation failure" (`:1451-1455`). Either check failing is
   abort `A-16`.
7. If `l`: exactly one `set_light_data(calc)`. If `q`: exactly one
   `update_liquids()` (`:1395-1398`).

**`light_write_box`, defined once:**
`(content write extent bounding box ⊕ 15, clipped at the emerged boundary) ∩ (central slice minp..maxp)`.
The `⊕ 15` and the emerged clip are the brief's light-dirty region (`:1426-1430`);
the intersection with the central slice is this probe's own restriction, and it
is what makes step 6 bound the light upload to the callback's **own owner
slice**. The probe therefore writes no halo light, in any case, in either arm —
a deliberate narrowing of the brief, which permits halo light writes as its sole
derived-state exception (`:1471-1474`). This probe declines the permission so its
light lanes carry containment evidence rather than a self-inflicted artefact.

**Deliberate non-implementation.** The probe does not perform the brief's step 2
— `set_lighting` day-15/night-0 stamping on analytically sky-open final-air boxes
(`:1442-1445`) — having no analytic geometry to prove sky-openness with. Its
light values are therefore **not** the production light values and it makes no
lighting-correctness claim; it measures call shape, cost, bounded upload and
order-stability.

#### Chunk `k_x = 8` — micro-cases 2 and 3 (`case = "bounded"`)

CORE(8) is `x ∈ [624, 671]`, `y ∈ [-16, 31]`, `z ∈ [704, 751]`. All four write
boxes are 8³ = 512 voxels and every one is **strictly** inside it —
`624 < 628`, `667 < 671`; `-16 < -8`, `7 < 31`; `704 < 712`, `719 < 751`.

| Box | Extent | Written value | Micro-case |
| --- | --- | --- | --- |
| `cut` | `(628, 0, 712) … (635, 7, 719)` | `air` | 2 |
| `fill` | `(628, -8, 712) … (635, -1, 719)` | `default:stone` | 2 |
| `water` | `(644, 0, 712) … (651, 7, 719)` | `default:water_source` | 3 |
| `facedir` | `(660, 0, 712) … (667, 7, 719)` | `stairs:stair_cobble`, `param2 = 1` | 3 |

- **Content write extent:** the **union**, 2,048 voxels. Its bounding box
  `(628, -8, 712) … (667, 7, 719)` is 5,120 voxels and is used for one purpose
  only — deriving `light_write_box`. Every containment check and every
  `digest_excl` exclusion uses the union (12.3). **`param2` mask:** the `facedir`
  box alone, 512 voxels, so `param2_mask ⊊ content_extent` with
  `content_extent \ param2_mask = cut ∪ fill ∪ water` = 1,536 voxels.
- **Separation is proved by coordinate, not cardinality** — two disjoint sets can
  have equal size, so realized *counts* prove nothing. The gate is: (i)
  `param2_extent` equals the `facedir` literal and the four content boxes equal
  theirs (stage-2 assertions 7 and 12); (ii) the `param2` lane `digest_incl` over
  `cut`, `fill` and `water` is **equal** between `B` and `A1` in the same order;
  (iii) over `facedir` it **differs** iff `dirty_param2_by_box.facedir > 0`; (iv)
  `set_data` and `set_param2_data` are counted separately and gated on `c` and
  `p` independently. Together these say *which voxels* carry a `param2` change.
- **`light_write_box`:** bounding box ⊕ 15 = `(613, -23, 697) … (682, 22, 734)`;
  neither the emerged box `(592,-48,672)…(703,63,783)` nor the central slice
  `(608,-32,688)…(687,47,767)` clips it, so 70 × 46 × 38 = **122,360** voxels.
  Both clips are still applied as formulas so the code is correct where they
  would bite. **`calc_lighting` region:** `(592, -32, 672) … (703, 47, 783)`.
- **Negative mutations:** (i) widen `cut` by one node in `+x` to `x = 636` — a
  voxel inside the bounding box but outside the union, so only union semantics
  catches it: the `digest_excl` residual must change and the gate must fail with
  `payload wrote outside its declared extent`; (ii) `set_data` twice —
  `bounded set_data count is not 1`; (iii) extend the `param2` write to `water` —
  `param2 lane changed outside the declared param2 write mask`.

#### Chunks `k_x = 10` and `k_x = 11` — micro-case 4 (`case = "4lo"` / `"4hi"`)

One solid `default:goldblock` bar, cross-section 8 × 8 in y and z, spanning
`x ∈ [840, 855]` globally, written as two halves by two owners:

| Half | Chunk | Write extent | Owner's central slice | `light_write_box` (33,212 voxels each) |
| --- | --- | --- | --- | --- |
| `4lo` | `k_x = 10` | `(840, 0, 712) … (847, 7, 719)` | `[768, 847]` — last 8 x-nodes | `⊕ 15 = (825,-15,697)…(862,22,734)`, ∩ `x ∈ [768, 847]` → `(825, -15, 697) … (847, 22, 734)`, 23 × 38 × 38 |
| `4hi` | `k_x = 11` | `(848, 0, 712) … (855, 7, 719)` | `[848, 927]` — first 8 x-nodes | `⊕ 15 = (833,-15,697)…(870,22,734)`, ∩ `x ∈ [848, 927]` → `(848, -15, 697) … (870, 22, 734)`, 23 × 38 × 38 |

- **Neither chunk writes a single voxel of content, `param2` or `param1` outside
  its own central slice** — for content and `param2` that is the brief's
  central-owner-slice rule (`wp40-engineering-brief.md:1088-1090`); for `param1`
  it follows from the `light_write_box` definition and the step-6 restore.
- The two light-write boxes are disjoint, their union `x ∈ [825, 870]` is
  contiguous across the boundary, and **both are inside SEAM**. That containment
  is what fixes the half-depth at 8 rather than 16: the brief's 15-node
  neighbourhood condition (`:1428-1433`) is satisfied by a 16-deep half too, but
  its light-write box would start at `x = 817`, outside SEAM, and the light lanes
  could no longer be compared over a single named box.
- **`calc_lighting` region:** `(752, -32, 672) … (863, 47, 783)` for `k_x = 10`,
  `(832, -32, 672) … (943, 47, 783)` for `k_x = 11`. **`param2` mask:** none, so
  that dirty set is **empty by construction** — which 10.13's aggregation rule
  uses and `V-03` turns into an expected `param2`-lane equality over both boxes.
- **Why `default:goldblock`:** chosen for the five-minute user test of section 19
  — at these coordinates the native column is overwhelmingly likely to be solid
  stone, and a `default:stone` bar inside stone is invisible, as is a *missing*
  half of one. Its `is_ground_content = false`
  (`mods/BASE/default/nodes.lua:1301`) also has the mechanical consequence 10.13
  works out, and which is why micro-case 4 is **not** a generic overwrite test.
- **Negative mutations:** (i) let `k_x = 10` write the whole bar — fail with
  `payload wrote outside its central owner slice`, detected by the payload's own
  extent check **and** by the SEAM digest diverging from the two-half
  expectation; (ii) swap the halves — same fragment.

### 10.11 Operation-count matrix

Exact maxima per chunk, per callback, counted by the proxy of section 10.12.
`c` / `p` / `q` / `l` are the realized predicates of section 10.10, read from
the **same record** the counts are on — never from a hardcoded number.

| Method | arm `A1`, every chunk | `bounded` | `4lo` / `4hi` |
| --- | --- | --- | --- |
| `get_emerged_area` | 0 | 1 | 1 |
| `get_data` | 0 | 1 | 1 |
| `get_param2_data` | 0 | 1 | 0 |
| `set_data` | 0 | `c ? 1 : 0` | `c ? 1 : 0` |
| `set_param2_data` | 0 | `p ? 1 : 0` | 0 |
| `get_light_data` | 0 | `l ? 2 : 0` | `l ? 2 : 0` |
| `set_lighting` | 0 | `l ? 1 : 0` | `l ? 1 : 0` |
| `calc_lighting` | 0 | `l ? 1 : 0` | `l ? 1 : 0` |
| `set_light_data` | 0 | `l ? 1 : 0` | `l ? 1 : 0` |
| `update_liquids` | 0 | `q ? 1 : 0` | `q ? 1 : 0` |
| `write_to_map`, `read_from_map`, `initialize`, `close`, `update_map`, `was_modified`, `get_node_at`, `set_node_at` | 0 | 0 | 0 |

The `set_lighting` count of 1 is "the canonical bounded box count produced for
that dirty set; it is not a second upload count"
(`wp40-engineering-brief.md:1457-1458`) — here the canonical box count is 1
because every `light_write_box` is a single axis-aligned box by construction.

### 10.12 The counting proxy

The payload never holds the raw VoxelManip. `payload/vm_proxy.lua` wraps it in a
plain table with one entry per method of `l_vmanip.cpp:499-518`: the ten the
probe may call (10.11) forward to the real object and, per call, increment a
named counter and record a `core.get_us_time()` delta; the other eight raise
immediately with `forbidden VoxelManip method: <name>`, so an accidental call is
a loud failure rather than an uncounted one.

Self-reported counters alone are not acceptable evidence, because a bug that
skips a call also skips its counter. A static grep sweep in the shape of
`tools/wp40/t2_source_audit.sh:363-393` therefore asserts that raw-VoxelManip
access appears in exactly one file. The scoping matters as much as the pattern —
`t2_source_audit.sh` avoids self-matching by restricting its sweep to production
paths, and this package copies the scoping and not only the shape:

```
rg -n --glob 'tools/wp40/t5_probe/payload/**.lua' \
   --glob '!tools/wp40/t5_probe/payload/vm_proxy.lua' \
   -e 'core\.vmanip' -e 'get_mapgen_object' -e '(^|[^%w_])vm:[a-z_]+' \
   ; test $? -eq 1
```

Three exclusions are stated rather than discovered. **The runner is out of
scope** — `run_t5_probe.sh` contains all three pattern literals because it
*implements* the sweep. **`vm_proxy.lua` is the one permitted holder**, excluded
by path. And **`payload/mapgen.lua` necessarily receives the raw object** as
callback argument 1
(`reference_projects/luanti/src/script/cpp_api/s_mapgen.cpp:50-55`), so it must
pass that argument straight into `vm_proxy.wrap(...)` on the first statement of
the callback and never bind it to a matched name — the reviewer reads that one
line rather than trusting the sweep for it. The `vm:` pattern is anchored on a
non-word character so an identifier merely *ending* in `vm` does not match.

**Stated exemption: the main-state readback.** `driver/init.lua` legitimately
uses a raw main-state VoxelManip — `core.get_voxel_manip()` plus `read_from_map`,
legal outside the emerge environment (`l_vmanip.cpp:44-45` forbids
`read_from_map` only in the mapgen environment). It is outside the sweep's path
scope because it is not the payload, makes no mapgen-VM call, and runs after
every chunk has been generated.

### 10.13 Micro-case 4: what it can and cannot show

#### Why this is a persistence observation and not an overwrite test

An earlier draft claimed a `default:goldblock` bar crossing a chunk boundary
could confirm the engine's *unfinished slice bug*
(`reference_projects/luanti/src/emerge.cpp:181-186`,
`https://github.com/luanti-org/luanti/issues/9357`). **It cannot, and every such
claim is withdrawn.** Against the pinned source:

| Step | Pinned source | Consequence for the bar |
| --- | --- | --- |
| mgv7 regenerates terrain, ores and decorations over the **central** chunk only | `generateTerrain()` at `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:467`, x/z loops `node_min..node_max` at `:529-530`; `placeAllOres(this, blockseed, node_min, node_max)` `:355`; `placeAllDecos(this, blockseed, node_min, node_max)` `:363` | a later neighbour does not normally rewrite the previous central chunk's terrain, ores or decorations at all |
| `DungeonGen` **does** run over `full_node_min..full_node_max` | `reference_projects/luanti/src/mapgen/mapgen.cpp:952` | it reaches the previous chunk's central slice … |
| … but explicitly preserves nodes with `is_ground_content = false` | `reference_projects/luanti/src/mapgen/dungeongen.cpp:85-96`, whose own comment says the rule exists "to avoid dungeons that generate out beyond the edge of a mapchunk destroying nodes added by mods in 'register_on_generated()'" | … and must not touch a marker with that property |
| `default:goldblock` has exactly that property | `mods/BASE/default/nodes.lua:1301`, definition `:1298-1304` | the chosen marker is **survivable by design** |
| liquids cannot replace a solid non-liquid node, and lighting only writes `param1` | `updateLiquid` over the emerged area (`mapgen_v7.cpp:370`); `calcLighting` (`mapgen.cpp:466-472`) | neither can remove the bar from the content lane |

So `blitBackAll` (`reference_projects/luanti/src/servermap.cpp:291`) reads and
writes back *the same* marker, and "the bar survived" is what the engine is built
to produce — not evidence that a generic mod write in a neighbour's reach
survives. **The opposite choice is no better:** a marker with
`is_ground_content = true` would be eligible for `DungeonGen`'s rewrite and for
the native writers of 6.1 rows 1–6, so a difference could never be attributed to
the seam rather than to a dungeon or ore blob landing in the write extent.
**Neither choice yields a clean generic overwrite test at this scope, and this
contract does not invent one.** A deterministic controlled negative would need a
dungeon-free substrate or a native-writer-free coordinate, and neither exists
here (6.1: "No chunk anywhere in this world is free of engine writers"). The gap
is recorded, not papered over.

**What micro-case 4 is, then:** a bounded, paired-order **persistence and seam
observation**. It asks whether each half is still present in the compared decoded
lanes after the other chunk has generated, in both orders, and reports the paired
`O1`/`O2` comparison with localization. It attributes no cause. S12's citation of
issue 9357 stands as engine-documented context for *why request order is worth
controlling*, and nowhere as something this probe confirms.

#### The reading rule for `V-05`

Digests cannot be subtracted: a SHA-256 says *whether* two byte strings differ,
never *how*. Localization comes from `digest_incl`, which digests each named
write box on its own, and `first_diff` (12.7). Four equality predicates,
evaluated **per lane** over SEAM:

- `P1` := `SEAM(B, O1) == SEAM(B, O2)` — the treatment is order-stable;
- `P2` := `SEAM(A1, O1) == SEAM(A1, O2)` — the paired control is order-stable;
- `P3` := `SEAM(B, O1) == SEAM(A1, O1)` — the delta is *empty* in O1;
- `P4` := `SEAM(B, O2) == SEAM(A1, O2)` — the delta is *empty* in O2.

They are the four edges of a 4-cycle over an equivalence relation, so **exactly
three true is impossible**; observing it can only mean a digest was computed over
the wrong bytes, and it aborts (`A-14`). The remaining twelve combinations are
decided by one ordered cascade — first matching row wins, and every legal
combination matches exactly one:

| # | Condition | Outcome | `verdict.result` | What may be said |
| --- | --- | --- | --- | --- |
| 0 | exactly three of `P1`…`P4` true | — | — | impossible; abort `A-14` |
| 1 | `P3 ∧ P4` | `no_delta` | `inconclusive` | no detectable SEAM change in either order. Read `V-03`, `digest_incl` over both halves and `dirty_content_by_box` before concluding anything |
| 2 | `P3 ≠ P4` | `inconclusive` | `inconclusive` | the delta is empty in exactly one order — the payload's bytes coincide with native content in that order only. Localize; conclude nothing |
| 3 | `¬P2` | `no_stable_baseline` | `inconclusive` | the paired control is itself order-dependent over SEAM, so no SEAM difference is attributable to the payload. The escalation over the halves' `digest_incl` may state at most whether their own extents are byte-identical across orders — not why |
| 4 | `P1` | `persisted` | `pass` | both arms order-stable and the delta non-empty in both orders: each half is still present in the compared lanes after the other chunk generated, in both orders — for this seed, this chunk pair and this synthetic bar, not generalized (`wp40-engineering-brief.md:3047-3048`). **Corroboration is mandatory:** `digest_incl(B, O1)` must equal `digest_incl(B, O2)` on **both** halves and differ from `digest_incl(A1, O)` on both, or the row is downgraded to `inconclusive` and the discrepancy reported |
| 5 | otherwise (`¬P1 ∧ P2 ∧ ¬P3 ∧ ¬P4`) | `order_effect` | `result` | the treatment's SEAM bytes differ across orders while the paired control's do not. **Reported as an observed order effect with its cause not attributed** — the mechanism table above says why a bar of this construction cannot separate "the write was overwritten" from any other order-sensitive difference. The report names the half, the order and the x range from `digest_incl` and `first_diff` |

Row 4 is the only pass. **What would settle a `no_stable_baseline` run:** a run
set in which the paired control *is* order-stable over the compared box — re-run
at a different `fixed_map_seed`, or re-run with SEAM narrowed to a sub-box over
which `A1(O1) == A1(O2)` holds, chosen from the failing run's `first_diff`. Both
are follow-on runs; the probe reports the outcome and names the route.

**Per-lane aggregation.** The cascade runs per lane over `content` and `param2`.
A lane whose realized dirty count is **zero by construction** — declared so in
10.10, not merely observed as zero in `dirty_*_by_box` — is recorded
`no_signal_by_construction` and excluded from the aggregate; for micro-case 4
that is the `param2` lane, always. A lane whose by-box count is zero **as an
observation**, where the case declared a write, is *not* excluded: it is
`inconclusive` and reported, because a payload that wrote nothing where it
declared a write is itself a finding. The aggregate over contributing lanes is
`pass` if every one lands on row 4 with its corroboration, `result` if any lands
on row 5 and none fails, `inconclusive` otherwise; if **every** lane is
`no_signal_by_construction` the aggregate is that, never `pass` — which cannot
arise here, since `content` always contributes. Per-lane rows are emitted in full
alongside the aggregate.

**Why the light lanes are not in `V-05`.** With the step-6 restore each half's
light upload is bounded to its own central slice, so the probe writes no halo
light and the light lanes carry no payload-side seam signal. What they *can*
still show is the engine's own re-lighting: when `k_x = 11` generates, its native
`calcLighting` covers its full emerged area (`mapgen.cpp:466-472`) including
`k_x = 10`'s `x ∈ [832, 847]`, and `blitBackAll` writes that back
(`servermap.cpp:291`) — over content that differs between the arms. `V-08`
reports that separately as an observation, **not** as a test of the brief's
halo-light idempotence exception (`:1471-1474`), because this probe deliberately
writes no halo (10.10).

### 10.14 Scope reduction, stated plainly

`wp40-engineering-brief.md:2965-2966` decides "identical canonical mapblock
output across nine fixed request schedules in the supported one-thread
configuration", enumerated at `:2975-2987`. **Only six of the nine schedule
shapes are instantiable by a synthetic payload:** schedules 4 (`:2979-2980`),
5 (`:2981`) and 8 (`:2984-2985`) are defined over anchors, fixed interfaces,
resolver interfaces and chunk-crossing features that T2 and T4 own, and a
synthetic bar is not one of them.

The probe exercises **two orders, not nine schedules**, over **three chunks**,
not the frozen feature corpus. Its result must never be presented as, cited as,
or folded into the §6.2 gate, which additionally requires "All one-thread
schedule hashes must match bit-for-bit" (`:3022`), a paired native control per
schedule (`:3029-3038`), and a decoded canonical serialization the probe does
not implement (`:3004-3016`). The brief's "frozen liquid-settling procedure"
(`:3005`) and "frozen quiescence limit" (`:1405`, `:1946`) are named but nowhere
numerically defined; 10.15 gives the probe's honest substitute for the number
nobody has decided.

### 10.15 What the `liquid_update` pin does and does not remove

The pin suppresses **only the periodic global drain**: `Server::AsyncRunStep`
drains the server-wide `m_transforming_liquid` only when
`m_liquid_transform_timer` reaches `m_liquid_transform_every`
(`reference_projects/luanti/src/server.cpp:781-792`, period read once at `:597`);
that drain is the sole caller of `ServerMap::transformLiquids` and the only route
to the purge branch (`reference_projects/luanti/src/servermap.cpp:1260`). At
86400 s it cannot fire inside a run whose outer timeout is 180 s.

**Everything generation-local survives the pin and remains part of every O1/O2
result.** `finishBlockMake` drains each chunk's own queue through
`transformLiquidsLocal` bounded by `liquid_loop_max` (`servermap.cpp:300`) and
pushes the remainder into the global queue (`:305-308`) whether or not that queue
is ever drained; and a **later neighbour's** `transformLiquidsLocal` runs over
*its* changed blocks, which include the shared border blocks it just blitted, so
it can still touch liquid in a region a previously generated chunk owns. For
`k_x` 10 and 11 that region is inside SEAM; for `k_x = 8` it cannot happen at
all, because that chunk has no generated neighbour (6.3).

So what the probe compares is the **post-generation result after bounded local
transform, before background settling** — not "the state left by generation
alone", and not a settled state. That is exactly the T5 seam: `update_liquids()`
"scans the VM and queues candidates but does not itself settle the liquid before
the following Lua statement" (`wp40-engineering-brief.md:1395-1398`), and
"`finishBlockMake` later performs engine liquid transformation and any
engine-owned node-light updates" (`:1402-1404`). Background settling over seconds
is server housekeeping, not a T5 seam.

**Why no settling-window assertion exists.** The number of *global* drain passes
a chunk would receive before readback is a function of elapsed wall time, which
differs per arm and per order — O1 and O2 are exact reverses, so `k_x = 11` is
generated third in one and first in the other, and its generation-to-readback
window necessarily differs by two mapchunk generations. Any tolerance loose
enough to accept that is loose enough to permit a multi-pass difference. The pin
removes the variable at its root instead.

**What the two-pass digest proves.** Every run digests the compared regions
**twice**, at least two seconds apart, emitting both sets (`digest.pass`). With
the periodic drain suppressed the two passes are expected to be identical; a
difference means the drain ran anyway — a wrong or ignored `liquid_update`, an
engine build that reads it elsewhere — or that something else moved between
passes. Either is a fault in the run, not a property of the seam: `V-09`, abort
`A-13`. `generated_us` and `readback_us` are retained as evidence but gate
nothing; the inter-pass separation and the quiescence criterion are probe-local
and are emitted with `settling_is_probe_local: true`.

## 11. Required seams and observations, mapped

| Mandate item | Already settled by source | What the probe adds |
| --- | --- | --- |
| the real engine can load the mapgen environment | S1, and **production-proven**: `mods/MAPGEN/grug_mapgen/ocean_mask.lua:47` calls it today | load wall time and callback registration index |
| exercise the IPC mechanism | main → mapgen: S3a, and **production-proven** (`ocean_mask.lua:46` → `ocean_mask_mapgen.lua:60`) | unpack time; **new**: the mapgen → main direction (S3b) over the four keys of 12.4 |
| exercise an owner slice | S6 gives the geometry and the absence of a write guard | **new**: whether each micro-case-4 half persists in the compared lanes across the other chunk's generation, in both orders (10.13) |
| at most one content and optional `param2` upload | S5, signature level only | **new**: exact enforced counts under a proxy, with the `param2` mask separated from the content mask **by coordinate** |
| liquid/lighting work only when dirty | S7/S8 give the mechanisms | **new**: the realized `q` and `l` predicates, the conditional counts they gate, and the bounded light upload with its independently verified restore proof |
| the same bytes in different chunk orders | S12 says the opposite is possible by construction | **new**: measured per lane in CORE and SEAM, against a paired control per order in **both** regions (`V-06`) |
| callback time | S9 gives `core.get_us_time()` | **new**: the numbers |
| peak working memory | S10 gives only `collectgarbage` in the mapgen state; S11 says why no process metric is reachable there | **new**: Lua-heap movement in both states; process RSS best-effort in the **main** state only |

**Genuinely new evidence — the short list.** Everything else above is
re-confirmation. (1) mapgen → main IPC actually delivers all four keys, at what
latency, and whether a blocking `ipc_poll` (`l_ipc.cpp:104-121`) is needed. (2)
`set_param2_data` behaves as a separately gated upload alongside `set_data`, with
the two masks separated by coordinate. (3) The realized values of `c`, `p`, `q`
and `l`, and that a realized content no-op really does cost zero lighting and
zero liquid calls. (4) That the bounded light upload holds — restore counter
zero, outside-box hashes equal, under an independent verification traversal.
(5) Reordered chunk generation with a byte comparison, CORE and SEAM, treatment
and paired control. (6) The actual cost of one full-volume `get_data` /
`set_data` / `get_param2_data` / `set_param2_data` / `get_light_data` /
`set_light_data` / `calc_lighting` / `update_liquids` over 1,404,928 nodes on
the designated host.

## 12. Measurement schema

### 12.1 Emission

One line per record, through the mapgen state's and the main state's `core.log`
(`reference_projects/luanti/src/script/lua_api/l_util.cpp:864` in
`InitializeAsync`, `:739` in `Initialize`):
`core.log("action", "WP40_T5_PROBE_JSON " .. core.write_json(fields))` —
compact, never pretty (the pattern of
`tools/wp40/dungeon_probe/init.lua:17`). Extraction is by marker **index**, never
by prefix (`tools/wp40/dungeon_probe/verify_log.sh:32-39`). That covers the run
stream only; the comparison stream (12.7) is written by `compare_runs.sh` after
the engine has exited.

### 12.2 Common fields — on every run-stream record

| Field | Type | Value |
| --- | --- | --- |
| `schema` | string | `"grug_wp40_t5_probe_synthetic_v0"` |
| `tag` | string | the discriminator; one of the run-stream tags of 12.3 |
| `arm` | string | `"A1"` \| `"B"` |
| `order` | string | `"O1"` \| `"O2"` |
| `run_id` | string | `"<arm>-<order>"`, e.g. `"B-O2"` |
| `state` | string | `"main"` \| `"mapgen"` |
| `seq` | integer | 1-based, strictly increasing by 1 within one `state` |

Unlike the dungeon probe, which carries a `schema` field only on the derived
summary (`tools/wp40/dungeon_probe/verify_log.sh:153`), **every record here
carries one**. The comparison stream of 12.7 has a different common-field set,
because a cross-run record has no single `arm`, `order` or `run_id`.

### 12.3 Record shapes — the run stream

`vec3` means `{x, y, z}` integers. `int_or_unavailable` means integer **or** the
literal string `"unavailable"` — never absent. Every cardinality below is **per
run** and is enforced by stage 2 of `verify_log.sh`. The two cross-run records —
`verdict` and `first_diff` — are **not** part of this stream; they belong to the
comparison stream of 12.7 and must never appear in a run log.

| `tag` | Cardinality | Fields (all mandatory; `exact_keys` enforced) |
| --- | --- | --- |
| `manifest` | 1, `state = "main"`, `seq = 1` | `engine_string`, `engine_hash`:string\|`"unavailable"`, `engine_is_dev`:bool, `lua_runtime`, `game_id`, `seed`, `mapgen_settings`:object string→string, `mapgen_noiseparams_sha256`, `content_id_table_sha256`, `content_id_count`:int, `mod_list_sha256`, `payload_digest`, `arm_switch_value`, `emerge_order`:array of **3** ints (the `k_x` in request order), `t0_us`:int |
| `mapgen_state_init` | **1** in both arms, `state = "mapgen"` — `num_emerge_threads = 1` means one emerge thread and therefore one mapgen Lua state (`reference_projects/luanti/src/emerge.cpp:641-668`, called once per thread at `:684`) | `load_us`, `ipc_get_us`, `ipc_set_us`:int, `ipc_get_ok`:bool, `ipc_set_key`:string (always `"grug_wp40_t5_probe:mapgen_state"`, 12.4), `seed`, `chunksize`:int, `mapgen_edges_min`/`_max`:vec3, `callback_index`:int (`#core.registered_on_generateds` after the payload registers), `vmanip_ctor_type`:string, `vmanip_ctor_return_count`:int (S4c: expected `0`), `has_request_insecure_environment`, `has_get_gametime`, `has_get_timeofday`, `has_get_server_uptime`, `registered_nodes_available` (S4f):bool, `lua_bytes`:int |
| `chunk_callback` | **3** per run in both arms, `state = "mapgen"` | `case`:`"bounded"`\|`"4lo"`\|`"4hi"`, `kx`:int, `minp`/`maxp`:vec3, `emin`/`emax`:vec3\|`null`, `blockseed`:int, `ops`:object of all 18 method names→int (zeros included), `op_us`:object string→int, `callback_us`:int, `write_extent_content`, `write_extent_param2`:int, `param2_extent_min`/`_max`:vec3\|`null`, `dirty_content`, `dirty_param2`:int, **`dirty_content_by_box`**, **`dirty_param2_by_box`**:object `box_name`→int, `dirty_liquid` (`q`), `dirty_light` (`l`):bool, `light_write_box_min`/`_max`:vec3\|`null`, `light_write_voxels`:int (`0` when `l` false), `restored_outside_dirty_mismatch_count`:int, `light_outside_box_snapshot_sha256`, `light_outside_box_restored_sha256`:string\|`""`, `lua_bytes_before`/`_after`:int, `ipc_set_us`:int, `ipc_set_key`:string (`"grug_wp40_t5_probe:chunk:<kx>"`, 12.4), `production_adopted`:bool (always `false`; section 4b). **The by-box counts are what `V-03` and 10.13 actually consume**; the scalars are their sums and stage 2 checks that. Their key sets are fixed by the case: `dirty_content_by_box` has `cut`/`fill`/`water`/`facedir` for `"bounded"` and the single key `"4lo"`/`"4hi"` otherwise; `dirty_param2_by_box` has only `facedir` for `"bounded"` and is `{}` for the case-4 chunks, whose `param2` set is empty by construction. **`emin`/`emax` are `null` in every arm-`A1` callback**, because the only Lua routes to them are `vm:get_emerged_area()` (`l_vmanip.cpp:377-387`) and `core.get_mapgen_object("voxelmanip")` (`l_mapgen.cpp:609-619`), both of which arm `A1` must not call. The three light fields are `null`/`""` whenever `l` is false. Keys are always present; only values are `null` |
| `main_on_generated` | 3 per run | `minp`/`maxp`:vec3, `blockseed`:int, `callback_us`:int |
| `emerge_done` | 3 per run | `kx`:int, `action`:string (`core.EMERGE_*` names, `tools/wp40/runtime_probe/init.lua:83-89`), `calls_remaining`, `elapsed_us`, `deadline_us`:int, `generated_us`:int (evidence only, gates nothing — 10.15) |
| `ipc_readback` | 1, `state = "main"`; `keys_expected` is **4** in both arms — one load-time key plus one per chunk callback (12.4) | `keys_expected`, `keys_found`:int, `keys`:array of 4 strings (the exact key names, sorted), `poll_used`:bool, `total_us`:int, `values_sha256`:string |
| `digest` | 4 lanes × (3 CORE + 1 SEAM) × 2 passes = **32** | `pass`:1\|2, `region`:`"core"`\|`"seam"`, `kx`:int\|`-1`, `lane`:`"content"`\|`"param2"`\|`"light_day"`\|`"light_night"`, `node_count`:int, `sha256`, `box_min`/`box_max`:vec3, `content_ignore_count`:int (from the content read of the same box, emitted on every lane's record), `readback_us`:int |
| `digest_excl` | 4 lanes × 3 chunks × 2 passes = **24**, in **both** arms over the **same** regions. The excluded region is fixed by the lane, never chosen: content and `param2` carry `"write_extent"` (feeding `V-01`), the light lanes carry `"light_write_box"` (feeding `V-02`). `V-01`/`V-02` compare `B` against `A1` over an excluded region and digests cannot be subtracted, so an arm-`B`-only emission would make the out-of-extent-write detector unrunnable | as `digest`, plus `excluded_kind`:`"write_extent"`\|`"light_write_box"`, **`excluded_boxes`**:array of `{min:vec3, max:vec3}`, and `excluded_voxels`:int — the digest of CORE **minus the union** of `excluded_boxes`. **The region is a box *list*, not a single box, and that is load-bearing:** `k_x = 8`'s content write extent is four disjoint boxes whose bounding box is 5,120 voxels against a union of 2,048, so a bounding-box exclusion would hide any write into the 3,072-voxel gap between them and make negative-test row 27 a vacuous pass. The literal lists are those of 10.10: for `excluded_kind = "write_extent"`, the four boxes `cut`/`fill`/`water`/`facedir` when `kx = 8` and the single `4lo`/`4hi` box otherwise; for `"light_write_box"`, that chunk's single light-write box. `excluded_voxels` is `\|CORE ∩ union\|`, so **`node_count + excluded_voxels == 110,592` on every record** — 2,048 / 108,544 and 58,032 / 52,560 for `kx = 8`, 0 / 110,592 and 8,246 / 102,346 for `kx` 10 and 11 |
| `digest_incl` | 2 lanes (`content`, `param2`) × 6 named boxes (`cut`, `fill`, `water`, `facedir`, `4lo`, `4hi`) × 2 passes = **24**, in **both** arms. The light lanes are excluded: no retained verdict consumes a light-lane included-extent digest | as `digest`, plus `included_extent_min`/`_max`:vec3 and `box_name`:string — the digest **of** the named box. `V-03` and 10.13's corroboration consume it; `digest_excl` alone cannot answer them |
| `case_baseline` | **3** per run in arm **`B` only**, from the payload's pre-write buffers, `state = "mapgen"`. It cannot exist in `A1`, which makes zero VoxelManip calls, and need not: in `B` the buffers read at the top of the callback *are* the native pre-write state | `case`:string, `anchor_column`:vec3 (x/z column at the centre of the content write extent), `native_surface_y`:int\|`null` (highest non-`air` y in that column's central slice, scanned down from `maxp.y`), `native_content_at_extent`:object node name→count over the write extent before the write, `native_air_count`, `native_liquid_count`:int. This is what section 19 hands the user instead of a guess |
| `process_metrics` | 1, `state = "main"` | `available`:bool, `rss_bytes`, `rss_peak_bytes`, `virtual_bytes`:int_or_unavailable, `cpu_seconds`:number\|`"unavailable"`, `lua_bytes_main`:int, `reason`:string\|`""` |
| `settling` | 1, `state = "main"` | `liquid_update_s`:number (read back; expected `86400`), `periodic_drain_suppressed`:bool, `interpass_wait_s`:number (≥ `2.0`), `quiescent`:bool, `settling_is_probe_local`:bool (always `true`) |
| `abort` | 0 or 1 | `code`: the **closed set** `"A-01"` … `"A-16"` of section 15, with no gaps and no reserved upper bound, so adding a code without updating that list is a gate failure rather than a silently rejected record; `reason`, `detail`:string |
| `complete` | 1, terminal, `state = "main"` | `ok`:bool, `chunks_generated`:int (expected `3`), `records_emitted`:int, `total_us`, `emerge_deadline_us`, `run_deadline_us`:int, `emerge_deadline_met`, `run_deadline_met`:bool (14.2) |
### 12.4 IPC keys, and process metrics as best-effort

**The four IPC keys.** The mapgen state writes exactly four keys per run, which
is what `ipc_readback.keys_expected = 4` counts: one at mapgen-script load time,
`grug_wp40_t5_probe:mapgen_state`, and one per chunk callback,
`grug_wp40_t5_probe:chunk:<kx>` for `kx ∈ {8, 10, 11}`. Each `ipc_set_us` field
times its own key's write, and `ipc_readback.keys` carries the four names sorted,
so the count and the timings cannot drift apart. The main state polls for all
four (S3b: there is no push and no key enumeration), and `values_sha256` digests
their unpacked values in that sorted order.

**Lua heap** via `collectgarbage("count")` is **mandatory** in both states,
emitted as `lua_bytes*` on `mapgen_state_init`, `chunk_callback` and
`process_metrics`.

**Process RSS / `VmHWM`** via the main-state trusted-mod `/proc/self/status`
read (the `tools/wp40/runtime_probe/init.lua:35-50` mechanism, enabled by
`secure.trusted_mods` per `tools/wp40/capture_t0_baseline.sh:126`) is
**best-effort**: if `core.request_insecure_environment()` returns nil, or
`/proc/self/status` cannot be read, or a field is absent, the probe records the
**literal string** `"unavailable"` with a non-empty `reason` and continues. It
must **not** hard-error the way `tools/wp40/runtime_probe/init.lua:6-10` does,
and must **not** silently drop the field the way that probe's `kibibytes()`
helper does (`:39-42`; `:41` returns
`value and assert(tonumber(value)) * 1024 or nil`, so a non-matching line makes
the field vanish from the JSON entirely) — `exact_keys` makes the vanishing case
impossible here. This use is the documented exception to `AGENTS.md:170-171` and
`docs/research/luanti-lua.md:234` ("**We never use it.**"), declared in the
driver's first two comment lines and in `driver/mod.conf` in the shape of
`tools/wp40/runtime_probe/init.lua:1-2` and `runtime_probe/mod.conf:3`.

**Alternative considered and rejected:** shell-side sampling of the engine
process's RSS by PID. It is implemented nowhere in `tools/wp40/` today, and
under Flatpak the process the launcher exposes is not the engine process —
`tools/wp40/capture_t0_baseline.sh:255` records exactly this, and the committed
`tools/wp40/evidence/t0-post-wp43-wp18-wp36/70adabd28401e820ec86e8786bf0da368225c8624e42ed02dd3bce175fd3cafc/raw/run-001.time.txt:2`
shows `User time (seconds): 0.00` for a run that generated map.

**No mapgen-state process metric is available through the public Lua API of the
pinned unmodified engine.** The proof is S11, stated there once. Its absence is
emitted as a positive observation:
`mapgen_state_init.has_request_insecure_environment` is expected to be `false`.

### 12.5 Fail-closed parsing

Three stages, in the shape of `tools/wp40/dungeon_probe/verify_log.sh`. They
gate the **run stream** (12.3); the comparison stream has its own gate (12.7).

**Stage 1** — marker-index extraction (`:32-39`), then every extracted line must
parse as a JSON **object**
(`jq -ce 'if type == "object" then . else error("record is not an object") end'`,
`:48-49`). Two properties of the in-tree extractor are closed here rather than
inherited. The awk extractor (`:33-39`) silently **drops** every line without
the marker, so corrupt non-marker content is never gated at all: stage 1
therefore adds a **non-marker garbage gate** — after extraction, the residual
(the raw log minus the extracted marker lines minus the engine's own known
log-line shapes, matched by an explicit committed regex whose bytes are bound
into the manifest digest) must be empty, or the run fails with
`raw log contains ungated non-marker content`. And a raw log whose marker count
is zero fails with `no JSON records found` before any jq stage runs; zero
records is never a vacuous pass.

**Stage 2** — one slurped `jq -se` assertion over the whole stream (`:51-138`),
reusing the primitive shape of `:54-65` (`is_integer`, `exact_keys($wanted)`,
`vector`, `trim`, `flag_set`). It **must be built from per-assertion
`error("…")` calls, not from one composed boolean**: the in-tree template
evaluates to a single truth value and emits no message, so it cannot satisfy
section 16, which requires a distinct `grep -qF` fragment per row. Every
assertion is written as
`if <predicate> then . else error("<exact fragment>") end`, and section 16's
fragments are the literal `error()` arguments.

| # | Stage-2 assertion |
| --- | --- |
| 1 | every record has `schema == "grug_wp40_t5_probe_synthetic_v0"`, a `tag` in the closed **run-stream** tag set, and satisfies `exact_keys` for its tag — no extra key, no missing key. This is what makes the `"unavailable"` marker of 12.4 mandatory rather than optional |
| 2 | no record carries `tag` `"verdict"` or `"first_diff"`, and none carries a `stream` field: those belong to the comparison stream (12.7) and would be judged by the wrong schema here |
| 3 | `arm ∈ {A1, B}`; `arm`, `order` and `run_id` constant within one file; `run_id == arm .. "-" .. order` |
| 4 | `seq` 1-based and contiguous within each `state` partition; the first `state == "main"` record is `manifest`; the last record overall is `complete`; terminal ordering in the shape of `:131-137` |
| 5 | per-tag cardinality exactly as tabulated in 12.3, **conditioned on the arm** — `case_baseline` at zero outside arm `B`, and `digest`, `digest_excl`, `digest_incl` present in **both** arms over identical regions |
| 6 | geometry, in the shape of `:101-114`: `maxp - minp == {79,79,79}`; where `emin` is non-`null`, `emin == minp - {16,16,16}` and `emax == maxp + {16,16,16}` (**skipped, not inverted**, for arm-`A1` callbacks, where those fields are `null` by contract); every content and `param2` write extent contained in `minp..maxp`; every `light_write_box` contained in `minp..maxp` **and** in the computed emerged box |
| 7 | **every compared region pinned to its literal contract coordinates.** `region = "core"` ⇒ `box_min`/`box_max` equal `(-16 + 80·kx, -16, 704) … (31 + 80·kx, 31, 751)`; `region = "seam"` ⇒ exactly `(824, -16, 696) … (871, 23, 735)` with `kx = -1`; `digest_incl.included_extent` equals the literal box its `box_name` names in 10.10; and `digest_excl.excluded_boxes` equals, element for element and in order, the literal **list** its `kx` and `excluded_kind` name in 12.3 — four boxes for `kx = 8` / `write_extent`, one otherwise. Without this pin a **displaced but successfully loaded** readback box passes everything: uniform air at high y yields `content_ignore_count == 0`, uniform lanes, `P1`…`P4` all true, and `V-05` reports a clean row over a region the contract never named |
| 8 | `node_count + excluded_voxels == 110592` on every `digest_excl` record, and `excluded_voxels` equals the tabulated value for its `kx` and `excluded_kind` (12.3). This is what makes the union semantics checkable rather than merely declared |
| 9 | the operation-count matrix of 10.11, per `case`, with the `c`/`p`/`q`/`l` conditionals read from the same record and **conditioned on the arm**: in arm `A1` every counter in `ops` is zero for every case, so the arm-`B` matrix is applied only in arm `B`. In particular every lighting counter is **zero** when `dirty_light` is false, and `update_liquids` zero when `dirty_liquid` is false |
| 10 | the by-box dirty counts sum to their scalars — `dirty_content == (dirty_content_by_box \| add)` and likewise for `param2` — and their key sets are exactly those 12.3 fixes for the record's `case` |
| 11 | the light-restore proof on every `chunk_callback` with `dirty_light == true`: `restored_outside_dirty_mismatch_count == 0` and `light_outside_box_snapshot_sha256 == light_outside_box_restored_sha256`, both non-empty; and both hash fields `""` with the counter `0` when `dirty_light` is false |
| 12 | the `param2` mask identity on the `bounded` record: `param2_extent_min`/`_max` equal the `facedir` box literal, and `write_extent_param2 == 512` |
| 13 | every measured chunk's `emerge_done.action` equals the generated action (`core.EMERGE_GENERATED`, `tools/wp40/runtime_probe/init.lua:83-89`); a chunk served `FROM_MEMORY`, `FROM_DISK`, `CANCELLED` or `ERRORED` was not generated by this run and its digests are meaningless |
| 14 | `content_ignore_count == 0` on every `digest` and `digest_excl` record for both CORE and SEAM. This closes a vacuous-readback hole: `get_data` collapses `NO_DATA` into `CONTENT_IGNORE` (`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:109`) and S14 records that the two are then indistinguishable, so two runs that both failed to load a region would produce identical `CONTENT_IGNORE` runs and pass every equality verdict, `V-05` included |
| 15 | both digest passes present and `settling.quiescent == true`; `production_adopted == false` on every `chunk_callback`; `settling_is_probe_local == true`; `ipc_readback.keys` is exactly the four keys of 12.4 |

**Stage 3** — the summary is generated with `jq -nc` and **re-parsed** with a
second `jq -e` including regex shape checks (`:144-175`, `:178-214`). The
engine-version gate is a regex whose own bytes are bound into the manifest
digest (`tools/wp40/run_dungeon_probe.sh:60`,
`tools/wp40/dungeon_probe/verify_log.sh:70`,
`tools/wp40/dungeon_probe/digest_lib.sh:54`). Non-golden values are labelled
in-band, the way `tools/wp40/dungeon_probe/verify_log.sh:166` writes
`positive_count_is_golden: false`; here the labels are
`timings_are_golden: false`, `timing_replicates: 1`,
`settling_is_probe_local: true` and `version_match: <bool>`.

### 12.6 Canonical serialization of the compared bytes

`core.write_json` key order is observed-sorted, not contracted, so **no digest is
ever taken over probe JSON as emitted**: any such digest re-canonicalizes with
`jq -S -c` first, and the lane digests are not taken over JSON at all. They are
taken over a packed byte string built in Lua — `content` two bytes per node as
`string.char(math.floor(id / 256), id % 256)`, `param2`, `light_day` and
`light_night` one byte each — in ascending flat index over the compared box, in
the engine's own `VoxelArea` order, **x fastest, then y, then z slowest**:

```
i = (z - MinEdge.Z) * extent.Y * extent.X + (y - MinEdge.Y) * extent.X + (x - MinEdge.X)
```

(`reference_projects/luanti/src/voxel.h:267-273`), with `MinEdge`/`extent` from
the **compared box**, not the emerged area. The full axis order is stated so an
independent implementation reproduces the digest byte for byte. Peak string size
is bounded by hashing per box per lane (≤ 221,184 bytes for a CORE content lane)
and rolling the leaves up with the labelled `key=value` canonicalization of 13.2.
A region that is a box *list* (`digest_excl`, 12.3) is serialized by traversing
CORE in the same ascending order and **skipping** every index inside the union —
never by traversing the boxes.

`core.sha256` is registered in both states the probe uses: the **main** state via
`ModApiUtil::Initialize`
(`reference_projects/luanti/src/script/lua_api/l_util.cpp:777`), where the lane
digests are computed from the readback, and the **mapgen** state via
`ModApiUtil::InitializeAsync` (`:895`), where step 6's two light hashes are
computed.

**The light-restore verification traversal must be independent of the restore
traversal.** Step 6 restores `calc[i] := snap[i]` outside the `light_write_box`.
If the counter and the two hashes re-walked the *same* index set the restore
walked, wrong index arithmetic would be checked against itself: the counter would
be 0 and the hashes would agree whatever the restore did, and `A-16` could never
fire. The verification pass is therefore built from scratch — iterate world
coordinates `(x, y, z)` over the emerged box in ascending `z`/`y`/`x`, compute
`i` from the formula above with `MinEdge`/`extent` of the **emerged** area, and
decide inside/outside by comparing `(x, y, z)` against the `light_write_box`
**literals**, never against an index range, an offset table or any value the
restore loop produced. It hashes one z-slab at a time (112 × 112 = 12,544 bytes)
with the 112 slab digests rolled up the same way, so peak Lua string size stays
under 13 KB rather than 1.3 MB. Reviewer item 9 checks that the two traversals
share no code.

**Readback loading.** The main-state readback uses one
`core.get_voxel_manip():read_from_map(box_min, box_max)` per compared box. Every
CORE box is MapBlock-aligned inside a generated central slice, and every MapBlock
the SEAM box touches lies inside `k_x = 10`'s or `k_x = 11`'s generated central
slice, so **no readback can trigger generation of the gap chunk** `k_x = 9`
(6.3). `mods/MAPGEN/grug_mapgen/wp40/canonical.lua` is a locked T2 surface
(`wp40-t2-plan.md:229`); the probe neither imports nor reproduces it, which is
why the serialization above is defined here from scratch.

### 12.7 The comparison stream — `verdict` and `first_diff`

`verdict` and `first_diff` are **cross-run** records. They are computed by
`compare_runs.sh` after all four captures, from their summaries, and are written
to a separate `comparison.jsonl` in the evidence tree — never into a run's raw
log. That separation is forced: a `V-05` record comparing `B-O1` against `A1-O2`
has no single `arm`, no single `order` and no single `run_id`, so it cannot
satisfy 12.2, and it is written by a shell process after the engine exited, so it
cannot participate in a run's `seq` partition or precede that run's terminal
`complete` record.

**Common fields on every comparison-stream record** — a different set from 12.2:

| Field | Type | Value |
| --- | --- | --- |
| `schema` | string | `"grug_wp40_t5_probe_synthetic_v0"` |
| `stream` | string | `"comparison"` — present on this stream only, and the discriminator the run gate rejects on |
| `tag` | string | `"verdict"` \| `"first_diff"` |
| `seq` | integer | 1-based, contiguous over the whole comparison file |
| `run_id_a`, `run_id_b` | string | the two runs the record was computed from, each `"<arm>-<order>"` |

| `tag` | Cardinality | Fields (all mandatory; `exact_keys` enforced) |
| --- | --- | --- |
| `first_diff` | **exactly one per differing compared digest pair, zero for an equal pair.** The cardinality is gated on that condition: a differing pair with no `first_diff` fails, because 10.13's cascade and `V-06` tell the reader to localize with it | `comparison`:string (e.g. `"SEAM:A1:O1-vs-O2"`), `lane`, `region`:string, `flat_index`:int (1-based ascending `VoxelArea` index within the compared box), `pos`:vec3, `value_a`, `value_b`:int |
| `verdict` | one per (verdict ID, lane) actually evaluated | `id`:`"V-01"`…`"V-09"`, `lane`:string\|`"all"`, `result`: closed set `"pass"`\|`"fail"`\|`"result"`\|`"inconclusive"`\|`"no_signal"`, `predicates`:object string→bool (`V-05`'s four; empty otherwise), `outcome`:string (`V-05`'s cascade outcome; `""` otherwise), `detail`:string |

**Its gate.** `compare_runs.sh` applies the same fail-closed discipline as 12.5
to this file, built from per-assertion `error("…")` calls: every record is a JSON
object carrying the five common fields and satisfying `exact_keys` for its tag;
`seq` is 1-based and contiguous; every `run_id_a`/`run_id_b` names one of the
four runs of 10.7; every `id` is in `V-01` … `V-09` and every `result` and
`outcome` is in its closed set; a `V-05` record reporting `pass` on any outcome
other than `persisted` fails; and the `first_diff` cardinality condition above
holds against the digest pairs the same script compared.

**And the run gate rejects them.** Stage 2 of `verify_log.sh` asserts that no
record in a raw log carries `tag` `"verdict"` or `"first_diff"`, or a `stream`
field at all, failing with `comparison record in a run log`. Without that, a
comparison record pasted into a run log would be judged by the wrong schema.

## 13. Evidence and reproducibility

### 13.1 Archive base, injection proof and disposable worlds

`git archive HEAD | tar -x` into a temporary game root, copy the probe files in,
recompute the payload digest from the copied bytes, and **refuse to continue if
it differs from the working-tree digest** — the shape of
`tools/wp40/run_dungeon_probe.sh:58-71` (archive `:62`, copy `:63-65`, recompute
`:66-67`, refusal `:68-71`). The archive base commit SHA is recorded and bound
into the manifest digest. Because `.gitignore:8` excludes `tools/bin/` from any
`git archive` export, interpreters needed by in-export gates are copied
explicitly, the way `tools/wp40/run_t2_census_gates.sh:76` does immediately after
its archive at `:75`.

Worlds are disposable: `mktemp -d /tmp/grudgelands-wp40-t5-probe.XXXXXX` with a
matching `case`/`esac` prefix guard and `trap cleanup EXIT INT TERM`
(`run_dungeon_probe.sh:39-46`); layout in the shape of `:48-56`; `world.mt` in
the shape of `:73-79` / `tools/wp40/capture_t0_baseline.sh:109-115`;
`minetest.conf` plus fixed seed in the shape of `:81-96` /
`capture_t0_baseline.sh:116-127`, including the per-run `port = 32000 + run` rule
at `:120`; headless invocation in the shape of `run_dungeon_probe.sh:105-120` /
`capture_t0_baseline.sh:134-146`, with `--log-timestamp none --color never`
(`:145`) because that is what makes a server log byte-comparable, and **without**
`--terminal`. Freshness is by construction only; nothing asserts `map.sqlite` was
absent, and the honest cache disclaimer of `capture_t0_baseline.sh:239-241` is
copied verbatim into every run's summary.

### 13.2 Digests

SHA-256 only. The canonicalization rule is labelled `key=value` lines with a
versioned `schema=` first line, **never** a `sha256sum` output line, which would
embed a path. The in-tree templates are
`tools/wp40/dungeon_probe/digest_lib.sh:27-34` (per-file payload digest:
`schema=` line, then `file_name=` / `file_content_sha256=` per file) and `:50-56`
(manifest digest: `schema=` line, then `game_archive_commit_sha1=`,
`probe_payload_sha256=`, `engine_version_regex_sha256=`,
`config_content_sha256=`), each piped through `sha256sum | awk '{print $1}'`.
`tools/wp40/capture_t0_baseline.sh:63-68` hashes `sha256sum` output lines
including their paths; that is the anti-pattern, and this package does not copy
it.

The T5-0 manifest digest uses `schema=wp40-t5-probe-manifest-v1` and binds the
archive commit SHA, the payload digest, the engine-version regex digest, the
configuration bytes of all **four** runs, the coordinate-set literal and the case
write-extent literals. It is **proven by a fixture, not asserted** — same bytes
at two different paths must produce the same digest, one appended line must
change it — in the shape of `tools/wp40/dungeon_probe/digest_audit.sh:17-43`,
implemented inside `selftest.sh`. The evidence directory is named by the manifest
digest (`run_dungeon_probe.sh:144-149`), and each run directory carries a
self-excluding per-directory manifest in the shape of
`capture_t0_baseline.sh:263-267`.

### 13.3 Engine identity, attribution and directories

Engine and runtime identity are captured in-band via `core.get_version()` in both
states (`tools/wp40/runtime_probe/init.lua:154`, `:162-164`, `:171`, noting
`rawget(_G, "jit")` for `strict.lua` safety) and host-side via `flatpak info` /
`--version` / LuaJIT detection (`tools/wp40/capture_t0_baseline.sh:56-61`) plus
`tools/wp40/collect_host.sh`, whose unavailable values degrade to the literal
`"unavailable"`. The installed Flatpak is **5.16.1** while the pinned reference
is **5.17.0-dev `df04879`**; the mismatch is recorded, not hidden — the summary
carries `version_match: false` in the shape of `capture_t0_baseline.sh:231-234`,
so every runtime observation is an observation of 5.16.1 that corroborates rather
than replaces the pinned-source audit of section 7.

Every `verdict` record names the two runs it was computed from (12.7), and the
summary never mixes arms across orders except in the named `V-05`/`V-06`/`V-08`
cross-order comparisons.

Scratch lives under the guarded `mktemp` root and is deleted on exit. Results go
to `tools/wp40/results/t5_probe/<manifest-digest>/` (ignored by `.gitignore:11`),
refusing to overwrite an existing directory with exit 2
(`capture_t0_baseline.sh:81-83`). Reviewed evidence is promoted to
`tools/wp40/evidence/t5-probe-<manifest-digest>/` by overriding
`WP40_RESULTS_ROOT` (`:18-21`, `tools/wp40/README.md:1109-1111`), and
`.gitattributes` is extended to disable Git's whitespace diagnostic for that
tree's `raw.log` files only, exactly as `.gitattributes:1` does today.

## 14. Runtime and CPU budget

### 14.1 Ceilings

| Quantity | Ceiling |
| --- | --- |
| engine invocations | **4** — strictly serial |
| distinct measured mapchunks | **3** |
| generated mapchunks per run / in total | **3** / **12** |
| **emerge-phase** wall time per run, `register_on_mods_loaded` to the last `emerge_done` | **< 45 s**, asserted in-run (14.2) |
| **whole-run** wall time per run, to the `complete` record | **< 60 s**, asserted on that record (14.2) |
| outer `timeout` per engine invocation | 180 s; exit 124 always fails the capture (`tools/wp40/README.md:1116-1117`) |
| **expected** total engine wall time | a few minutes. Per-run in-server work is three mapchunk generations plus **at most 17** full-volume buffer marshals in arm `B` — 7 for `bounded` (`get_data`, `get_param2_data`, two `get_light_data`, `set_data`, `set_param2_data`, `set_light_data`) and 5 for each case-4 half — and fewer whenever `c`, `p` or `l` is false. The outer timeout is a ceiling, **not** an expectation: 4 × 180 s must never be quoted as the expected cost |
| concurrent offline Lua processes | ≤ 8 (`tools/wp40/README.md:439`) |

These wall-time figures are a **LuaJIT** budget. The installed Flatpak runtime
is LuaJIT-only (`tools/wp40/capture_t0_baseline.sh:59-60`, `:257`), so this is a
documentation bound rather than a live risk — but a PUC-5.1 engine would not fit
it. The repository's measured PUC-to-LuaJIT ratios are "2.8x on validation-heavy
paths, 16.2x on an exhaustive numeric sweep, 26.5x on a full seed-0 compile"
(`tools/wp40/README.md:436-437`), and this probe's hot path is a full-volume
numeric sweep, so a PUC engine run needs its own re-derived budget.

**Reconciliation with the "4–12 chunks, a few minutes" sizing.** The measured
set is **three distinct mapchunks** and the total is **12 mapchunk
generations**, both inside 4–12. The multiplication by four is the
paired-control-per-order design the sizing itself requires: a single baseline
capture cannot attribute an order delta, having no per-order control to subtract
(section 4a, `wp40-engineering-brief.md:3029-3038`). Engine runs are serialized
because they contend for the same host, emerge thread and page cache, and
because `wp40-engineering-brief.md:3257-3261` binds any comparison to "the same
recorded target host, engine build, Lua runtime, mapgen settings, exact request
trace, cache class, and disposable-world state".

### 14.2 The in-run deadlines, and why exceeding them invalidates the run

`mods/CORE/grug_core/init.lua:934-950` unconditionally schedules six capital
sweeps at `SWEEP_DELAY + (i − 1) · SWEEP_STAGGER` = `60 + 15·(i − 1)` seconds
(constants `:934-935`, the `core.after` at `:946`), each of which may call
`core.emerge_area` (`:903-921`) on a branch whose short-circuit depends on
`core.get_spawn_level` (`:887-893`) and is therefore seed-dependent and
unknowable from source. The first fires at t ≈ 60 s and the last at t ≈ 135 s.

The driver records `t0 = core.get_us_time()` inside
`core.register_on_mods_loaded` and asserts an **emerge deadline of 45 s**,
checked on every `emerge_done` and before the first readback pass, and a **run
deadline of 60 s**, checked on the `complete` record and covering both readback
passes, the ≈ 5.63 M node-lane readings of 14.3, and the inter-pass settling
wait. The second is not redundant: that tail is unbounded work after the emerge
phase, and arm `B` performs up to 17 full-volume marshals arm `A1` never
performs, so `B`'s tail can straddle t ≈ 60 s while `A1`'s does not — exactly the
per-arm asymmetry `A-09` prevents. Splitting at 45 s leaves the whole run inside
the window before the first sweep fires. With three chunks the margin is larger
than the deadlines require; they are set by the external hazard, not by the work,
and are unchanged.

On violation the driver emits `abort` with code `A-09` and calls
`core.request_shutdown(msg, false, 0.1)`; the shell gate then fails the run.
Exceeding a deadline **invalidates** the run rather than merely slowing it:
after t ≈ 60 s unrelated mapchunks are being generated on the same emerge
thread, the map file has grown, the page cache has changed, and the four runs
would no longer share the identical realized emerge sequence `X-03` requires. A
slow run and a contaminated run are indistinguishable from the outside. The
measured chunks and their emerged shells are disjoint from every sweep box
(6.5), so the hazard is to **run-to-run comparability**, not to the measured
bytes.

### 14.3 Measured cost projection, folded into the first real capture

The projection is **not** a fifth engine invocation. Arm `B` order `O1` — the
more expensive arm, and therefore the honest basis — runs first with the outer
timeout at 180 s and its output is **retained**. Its per-case `callback_us`,
per-call `op_us`, `emerge_done.elapsed_us`, both readback passes and whole-run
wall time are recorded, and the projection
`projected_total_wall_s = 4 × observed_run_wall_s` is committed into the package
README together with the observed margin against the two deadlines. If that run
passed every gate **it is the B/O1 capture** and three invocations remain — four
in total. Only a *failed* projection costs an extra invocation, and a failed
projection stops the package and returns to this contract rather than trimming a
case.

**The projection is one unreplicated sample and must be labelled as one.** The
README states the multiplication in those words rather than presenting the
product as an estimate with a known error. Consistently, **every timing this
probe emits is n = 1** — one run per (arm, order) cell, no repetition, no
warm-up, no variance statistic, no outlier rule — recorded in 3.2 item 9 and in
the summary as `timings_are_golden: false` and `timing_replicates: 1`. **There is
no repetition control**: no environment variable multiplies the cell count, and
no median, minimum or maximum is computed anywhere, because a digest has no
median and a single sample has no spread.

**Volume literals.** Three figures are stated because they differ, and the
contract freezes the first:

- **hashed volume per run, per lane, per pass: 408,576 nodes** — 3 × 110,592
  CORE plus 76,800 SEAM, the `digest` records. **This is the frozen contract
  literal.**
- **distinct compared volume per run: 388,096 nodes.** SEAM overlaps CORE(10)
  and CORE(11) by 10,240 voxels each — SEAM's `x ∈ [824, 831]` lies inside
  CORE(10)'s `x ∈ [784, 831]` and SEAM's `x ∈ [864, 871]` inside CORE(11)'s
  `x ∈ [864, 911]`, over 40 y-values and 32 z-values each — so 20,480 voxels are
  hashed twice. The duplication is deliberate: the two boxes answer different
  verdicts and are compared against different partners. 388,096 of the three
  chunks' 1,536,000 central voxels is the **25.3 %** figure of non-claim 11.
- **total hashing work per run: ≈ 5.63 M node-lane readings.** The `digest`
  literal alone understates it, because `digest_excl` re-hashes CORE minus an
  excluded region on the same four lanes: per pass that is 329,728 readings on
  each of the two content/`param2` lanes and 257,252 on each light lane —
  1,173,960 — against `digest`'s 1,634,304 and `digest_incl`'s 6,144, so
  2,814,408 per pass and **5,628,816 per run**, about **1.7 ×** the naive
  `4 × 408,576 × 2`. Readback and packing cost is proportional to that total,
  not to the frozen literal.

Both volume literals, the total, and both chunk counts are contract literals;
any increase is a contract change.

## 15. STOP / abort conditions for the future probe run

These abort a **run**: the capture stops and reports an abort code instead of
producing verdicts. They are distinct from section 21's specification-level
conditions.

| Code | Condition | Detection |
| --- | --- | --- |
| `A-01` | `rg` or `jq` missing | preflight (`tools/wp40/run_t1.sh:4-9`, `tools/wp40/run_dungeon_probe.sh:15-18`); exit 127 |
| `A-02` | injected payload digest differs from the working-tree digest | `tools/wp40/run_dungeon_probe.sh:68-71` shape; exit 1 |
| `A-03` | engine version does not match the pinned regex, or differs between runs | stage-3 regex gate; `X-05` |
| `A-04` | `content_id_table_sha256` differs between any two runs | `X-01` |
| `A-05` | a mapgen callback raised a `LuaError` — the engine turns this into `setAsyncFatalError` + `cancelBlockMake` (`reference_projects/luanti/src/emerge.cpp:746-757`), so the chunk is never generated | missing `emerge_done` or a non-`GENERATED` action |
| `A-06` | realized mapgen settings differ between runs, or the in-band read disagrees with `map_meta.txt` | `X-02` |
| `A-07` | the realized emerge order differs from the requested order, or between arms | `X-03` |
| `A-08` | `emin`/`emax` are non-`null` and not `minp − 16` / `maxp + 16`, or are non-`null` in arm `A1` | `X-06` |
| `A-09` | either in-run deadline is exceeded — 45 s emerge phase, 60 s whole run | 14.2 |
| `A-10` | the outer `timeout` fires | exit 124. The partial raw log **must be preserved** into the results directory before `trap cleanup` runs: an outer timeout is the one abort with no in-band record, so discarding its log would leave the most interesting failure with no evidence |
| `A-11` | the payload attempted a forbidden VoxelManip method | the proxy raises `forbidden VoxelManip method: <name>` |
| `A-12` | a realized write extent is not contained in `minp..maxp` | the payload's containment check plus stage-2 assertion 6 |
| `A-13` | the two readback digest passes disagree — after the `liquid_update` pin this means the periodic drain ran anyway or something else moved between passes | `V-09`, 10.15 |
| `A-14` | an impossible predicate combination in 10.13's cascade (exactly three of `P1`…`P4` true) | `compare_runs.sh`; it can only mean a digest was computed over the wrong bytes |
| `A-15` | a measured chunk's `emerge_done.action` is not the generated action, or `content_ignore_count != 0` in a compared region | stage 2, 12.5 |
| `A-16` | **light preservation failure**: `restored_outside_dirty_mismatch_count != 0`, or the snapshot and restored outside-box hashes differ, under the independent verification traversal of 12.6 (10.10 step 6; `wp40-engineering-brief.md:1451-1455`) | payload assertion before `set_light_data`, re-checked by stage-2 assertion 11 |

Explicitly **not** aborts — these are results and are reported: `B − A1` differs
across orders (`V-05`); the paired control is itself order-dependent in CORE or
SEAM (`V-06`); a cascade row that licenses no conclusion (recorded
`inconclusive`, never a pass and never an abort); the light lanes differ across
arms or orders (`V-08`); process RSS is `"unavailable"`; and any of `c`, `p`,
`q`, `l` coming out false, or a realized dirty set smaller than its write extent,
or zero.

## 16. Negative tests

Each of the **43** rows is a deliberate corruption a gate **must** abort on, with
the exact fragment it must abort with. The harness shape is
`tools/wp40/run_t2_census_gates.sh:35-51` — `expect_failure` at `:37-50`, the
fragment matched at `:44` by `grep -qF`. Fixtures are generated inline the way
`tools/wp40/dungeon_probe/verify_log_test.sh:33-41` and `:43-57` generate theirs;
no fixture file is committed. "Applied to" names the stream: `raw log` and
`injected tree` are gated by `verify_log.sh` / `run_t5_probe.sh`, `comparison` by
`compare_runs.sh` (12.7).

| # | Corruption | Applied to | Reason fragment |
| --- | --- | --- | --- |
| 1 | empty file | raw log | `no JSON records found` |
| 2 | a marker line whose payload is not valid JSON; second fixture: random base64 with the marker prefix prepended to each line | raw log | `parse error` — what `jq` itself prints, **not** `record is not an object`, which fires only for valid JSON of the wrong type |
| 3 | `WP40_T5_PROBE_JSON [1,2,3]` — valid JSON, wrong type | raw log | `record is not an object` |
| 4 | truncated after the manifest record | raw log | `terminal record is not complete` |
| 5 | random base64 appended with **no marker prefix**, so the awk extractor drops every line and the jq stages never see them | raw log | `raw log contains ungated non-marker content` — without the stage-1 garbage gate this fixture is a vacuous pass, which is the hole it closes |
| 6 | delete `.schema` from one record | raw log | `record is missing schema` |
| 7 | set `.schema = "…_v1"` on one record | raw log | `unexpected record schema` |
| 8 | delete `.emin.z` from one arm-`B` `chunk_callback` | raw log | `vector shape invalid` |
| 9 | add an extra key to one `chunk_callback`; second fixture: delete `process_metrics.rss_bytes` instead of setting it to `"unavailable"` | raw log | `record has unexpected keys` |
| 10 | paste a `verdict` record — and, in a second fixture, a `first_diff` — into a raw log | raw log | `comparison record in a run log` — those tags belong to the comparison stream (12.7) and would otherwise be judged by the wrong schema |
| 11 | drop `seq = 4` from the main partition | raw log | `seq is not contiguous` |
| 12 | set `.arm = "A1"` on one record of a `B` run | raw log | `arm is not constant within a run` |
| 13 | a non-zero `ops` counter on an arm-`A1` `chunk_callback` | raw log | `arm A1 performed a VoxelManip call` |
| 14 | `ops.set_data = 2` for `case = "bounded"` | raw log | `bounded set_data count is not 1` |
| 15 | `ops.set_param2_data = 0` with `dirty_param2 > 0` | raw log | `set_param2_data count does not match the realized param2 dirty set` |
| 16 | `param2_extent_min`/`_max` set to the content extent bounding box | raw log | `param2 write mask is not the declared facedir box` |
| 17 | the `param2` lane `digest_incl` over the `water` box differing between the two arms of one order | comparison | `param2 lane changed outside the declared param2 write mask` |
| 18 | `ops.update_liquids = 1` with `dirty_liquid = false` | raw log | `update_liquids called with an empty liquid dirty set` |
| 19 | `ops.update_liquids = 0` with `dirty_liquid = true` | raw log | `liquid dirty set is nonempty but update_liquids was not called` |
| 20 | `ops.calc_lighting = 1` (second fixture: `ops.set_light_data = 1`) with `dirty_light = false` | raw log | `lighting call performed with an empty light dirty set` |
| 21 | `ops.set_light_data = 0` with `dirty_light = true` | raw log | `light dirty set is nonempty but set_light_data was not called` |
| 22 | `restored_outside_dirty_mismatch_count = 1` (second fixture: the two outside-box hashes differ) with `dirty_light = true` | raw log | `param1 outside the light write box was not restored` |
| 23 | change one entry of `dirty_content_by_box` so the entries no longer sum to `dirty_content` | raw log | `dirty counts by box do not sum to the scalar` |
| 24 | give a `"4lo"` record a `dirty_content_by_box` keyed `cut`/`fill`/`water`/`facedir` | raw log | `dirty by-box key set is wrong for this case` |
| 25 | `chunk_callback.maxp.x = minp.x + 80` | raw log | `central chunk extent is not 80 nodes` |
| 26 | widen a case-4 write extent past `maxp.x` | raw log | `payload wrote outside its central owner slice` |
| 27 | widen the `cut` box by one node in `+x`, to `x = 636` — **inside** the four boxes' bounding box but outside their union, so only union semantics catches it | comparison | `payload wrote outside its declared extent` |
| 28 | replace a `k_x = 8` `digest_excl.excluded_boxes` with the single 5,120-voxel bounding box | raw log | `excluded region is not the declared box list` |
| 29 | set `digest_excl.excluded_voxels` so it no longer complements `node_count` | raw log | `CORE residual and excluded voxels do not sum to 110592` |
| 30 | displace one `digest` record's box by 64 nodes in `+y`, lanes internally consistent | raw log | `compared box is not at its contract coordinates` |
| 31 | set one `emerge_done.action` to the `FROM_DISK` action | raw log | `measured chunk was not generated by this run` |
| 32 | `digest.content_ignore_count = 1` on one CORE record | raw log | `compared region contains CONTENT_IGNORE` |
| 33 | emit only `pass = 1` digests, or make the two passes disagree on one box | raw log | `quiescence proof failed` |
| 34 | `production_adopted = true` on a `chunk_callback` | raw log | `probe IPC telemetry must not be marked production adopted` |
| 35 | drop one entry from `ipc_readback.keys`, or rename one | raw log | `ipc key set is not the four declared keys` |
| 36 | an `abort` record carrying `code = "A-99"` | raw log | `abort code is not in the closed set` |
| 37 | `complete.run_deadline_met = false`; second fixture `emerge_deadline_met = false` | raw log | `run deadline exceeded` / `emerge deadline exceeded`. **Sited at the log gate, not the engine:** a real in-run deadline of 0 µs needs a live capture, and this suite runs *before* the expensive half |
| 38 | a `chunk_callback` cardinality of 2 or 4 in one run | raw log | `chunk_callback cardinality is not 3` |
| 39 | flip one hex character of a `digest.sha256` in one of two compared runs | comparison | `core digest mismatch` |
| 40 | change `content_id_table_sha256` in one of two runs | comparison | `content id table is not identical across arms` |
| 41 | three of `P1`…`P4` true and one false in a synthetic verdict input | comparison | `impossible predicate combination` |
| 42 | a `V-05` record reporting `pass` on any outcome other than `persisted` | comparison | `inconclusive row reported as a pass` |
| 43 | a differing compared digest pair with no `first_diff` record emitted | comparison | `differing digest pair has no first_diff record` |

**How this table changed and why the count rose.** Two duplicate pairs were
merged — the two `parse error` fixtures into row 2 and the two
`record has unexpected keys` fixtures into row 9 — and six rows were added for
gates that did not exist before: 10, 23, 24, 28, 29 and 35. Coverage grew; only
duplication shrank. No other pair of rows exercises the same gate with the same
fragment, so no further consolidation is available.

Two checks are not in the table because they are not corruptions of an emitted
stream: the injected-payload digest refusal (`A-02`, fragment
`injected probe payload digest differs`), exercised by `run_t5_probe.sh` against
a mutated injected tree, and the manifest-digest fixture (`digest is path
sensitive` / `digest did not change`) in `selftest.sh`. Neither needs an engine
capture, and neither does any of the 43 rows — all of them run **before** the
expensive half (`tools/wp40/run_dungeon_probe.sh:20-27`). Every fragment is a
literal `error("…")` argument in a stage-2 assertion or a literal `printf` in
`compare_runs.sh`; see 12.5 on why stage 2 cannot be one composed boolean. Row 2
asserts on the fragment `jq` itself prints, and since the harness asserts
substring containment the exact observed message is recorded in the evidence
rather than pinned here.

## 17. Definition of done for the future implementation package

Outcomes only. Each one's checkable form is the section-18 item in brackets;
this section does not restate the check.

| # | The package is done when … | §18 |
| --- | --- | --- |
| 1 | all **eleven** files of 8.1 exist and every created or modified path matches its four-pattern boundary | 1, 3 |
| 2 | every probe Lua file passes the static gates and sweeps of 8.2, and `coordinate_audit.lua` recomputes the 122-column envelope and the Ocean Mask derivation under both interpreters with byte-identical stdout and identical exit status (`tools/wp40/run_t2_s11_acceptance.sh:22-44`) | 13 |
| 3 | `selftest.sh` passes: all **43** rows of section 16 abort with their exact fragments, plus the two non-stream fixtures named there, and none needs an engine capture | 15 |
| 4 | the cost projection of 14.3 is committed, labelled as one unreplicated sample, and its run is reused as the B/O1 capture, so the package costs **four** engine invocations and not five | 24 |
| 5 | all **four** runs complete inside both deadlines with no abort code, each generating exactly **three** mapchunks — **12** in total — or the package reports the abort and stops | 17, 24 |
| 6 | all six cross-run assertions `X-01` … `X-06` hold and `V-09` holds in every run; no verdict is reported without them | 16, 17 |
| 7 | all **nine** verdicts `V-01` … `V-09` are computed and reported, `inconclusive` and "different" outcomes included, with 10.13's cascade applied verbatim and no outcome rewritten as a probe failure | 18, 19, 20 |
| 8 | the run stream and the comparison stream are emitted and gated separately, and neither contains the other's records | 12, 15 |
| 9 | every observation of section 11's short list has a recorded value or a recorded `"unavailable"` with a reason | — |
| 10 | the evidence tree is committed under `tools/wp40/evidence/t5-probe-<manifest-digest>/` with raw logs, `comparison.jsonl`, per-run summaries, `map_meta.txt` copies, host manifest and self-excluding checksums | 14 |
| 11 | `tools/wp40/t5_probe/README.md` carries the non-claims of 3.2 verbatim — the `n = 1`, 25.3 %, no-script-free-control and no-generic-overwrite-test items included — plus the `version_match: false` note of 13.3, the `timings_are_golden` / `timing_replicates` labels, and section 20's rule and checks | 19, 22 |
| 12 | section 19's runtime test plan is in the completion summary (`docs/process/wp-workflow.md:74-79`) | 23 |
| 13 | no production file, no `mods/` file and none of the six locked T2 surfaces appears in the package diff, and no `docs/` path other than this contract | 1, 2, 3, 21 |

## 18. Independent-review checklist

Every item is objectively checkable; a reviewer who cannot check an item must
fail it. Items reference the owning section rather than re-deriving it.

| # | Item | How it is checked |
| --- | --- | --- |
| 1 | **Boundary** | `git diff --name-only` matches the four patterns of 8.1 and nothing else. A checklist phrased as "…and `docs/`" is itself a failure |
| 2 | **No production registration** | `rg -n 'grug_wp40_t5_probe' mods/ game.conf minetest.conf` returns nothing |
| 3 | **Locked surfaces** | `git diff --name-only` intersected with the six paths of 8.3 is empty, and `rg -n 'wp40/canonical\|wp40/deterministic\|geometry/(exact\|raster\|boundary)\|t2_s1_authority' tools/wp40/t5_probe/` returns nothing |
| 4 | **Proxy discipline** | the sweep of 10.12 is run **with its stated path scoping** and returns nothing; a repository-wide sweep is itself a failure. The reviewer also reads the first statement of `payload/mapgen.lua`'s callback by eye, and checks `driver/init.lua`'s raw VoxelManip against the stated exemption |
| 5 | **Forbidden methods** | the proxy defines all eighteen methods of `l_vmanip.cpp:499-518`, forwards the ten of 10.11 and raises on the other eight |
| 6 | **Operation counts and lane-split containment** | stage-2 assertion 9 implements 10.11 exactly, including the `c`/`p`/`q`/`l` conditionals and the arm conditioning — not "at most", not "approximately". `V-01` is evaluated on **both** the content and `param2` lanes, `V-02` on the light lanes; narrowing `V-01` to the content lane loses `param2` containment and fails |
| 7 | **Conditional counts are conditional** | `update_liquids`, `set_param2_data` and every lighting call are gated on a predicate the record itself carries. A realized content no-op shows zero lighting and zero liquid calls |
| 8 | **Bounded light upload** | every `chunk_callback` with `dirty_light = true` carries `restored_outside_dirty_mismatch_count == 0` and two equal, non-empty outside-box hashes, and the restore happens **before** `set_light_data` (10.10 step 6). Calling `set_light_data` on the unrestored buffer fails this item even if every digest happens to match |
| 9 | **The light-restore verification is independent of the restore** | the reviewer reads both loops and confirms they share no index set, no offset table and no helper: the verification pass walks world coordinates, recomputes `i` from 12.6's formula, and decides inside/outside from the `light_write_box` literals. A verification that re-walks whatever the restore walked can never fail, so `A-16` would be dead — this item is the only thing standing between Technical High 3 and a decorative gate |
| 10 | **`param2` separation is by coordinate** | the evidence is the mask identity and per-box `digest_incl` comparisons of 10.10, **not** a comparison of the two realized dirty counts. "The two dirty counts differ" offered as the proof fails this item: two disjoint sets can have equal size |
| 11 | **The excluded region is a box list** | `digest_excl.excluded_boxes` carries four boxes for `k_x = 8` / `write_extent` and `node_count + excluded_voxels == 110592` on every record (12.3, stage-2 assertions 7–8). An implementation that excludes the 5,120-voxel bounding box instead of the 2,048-voxel union has silently disabled the out-of-extent detector and fails |
| 12 | **Two streams, two gates** | `verdict` and `first_diff` appear only in `comparison.jsonl` and never in a raw log; the run gate rejects them (stage-2 assertion 2) and `compare_runs.sh` gates them against 12.7's own common-field set. A `verify_log.sh` that tries to apply 12.2 to a cross-run record fails this item |
| 13 | **Coordinates** | `coordinate_audit.lua` recomputes rather than restates; the 122-column set and the three `lo` values of 6.2 come out of source, and the audit shows `box_needs_mask` is false because `lo ≥ 300` (deep inland), not because the box is far from the continent |
| 14 | **Digest canonicalization** | no digest is taken over a `sha256sum` output line containing a path; every digest input starts with a `schema=` line; the fixture of 13.2 proves both. `content_id_table_sha256` binds `id=` as well as `name=`, from an explicit `table.sort`, never a `pairs()` walk (10.4) |
| 15 | **JSON discipline** | every run-stream record carries the seven common fields of 12.2 and every comparison record the five of 12.7; `exact_keys` is enforced per tag; no field is ever absent. Both gates are built from per-assertion `error("…")` calls, so section 16's fragments actually exist |
| 16 | **Vacuous readback** | stage 2 asserts the generated `emerge_done.action` for all three chunks and `content_ignore_count == 0` on every CORE and SEAM digest |
| 17 | **Settling** | the generated `minetest.conf` pins `liquid_update = 86400`; the manifest records its **exact** consequence — periodic global drain suppressed, generation-local transform not (10.15); `V-09`'s two-pass proof is implemented with both passes in evidence. There must be **no** generation-to-readback window assertion, and a fixed `core.after` wait offered *in place of* the pin fails |
| 18 | **Localization records** | `digest_incl` and `first_diff` are emitted, and 10.13's cascade is implemented over the four named predicates with `inconclusive` as a first-class value |
| 19 | **No claim inflation** | no sentence asserts a threshold from `wp40-engineering-brief.md:3339-3358` was met (non-claim 6), presents a timing as portable (non-claim 9), claims byte-neutrality for loading a mapgen script (non-claim 12), **presents micro-case 4 as a test of the engine's unfinished-slice bug** (non-claim 13), or presents the two orders as the §6.2 nine-schedule gate (10.14) |
| 20 | **Failure is reported, not swallowed** | verdicts `V-03` … `V-08` are present with their measured outcomes, `inconclusive` rows included |
| 21 | **No sync** | `rg -n 'sync_to_luanti' tools/wp40/t5_probe/` returns nothing |
| 22 | **Disposal** | section 20's two checks are written into the package README |
| 23 | **Runtime plan** | the completion summary contains section 19's plan with concrete coordinates |
| 24 | **Counts** | every generation-count, run-count, cardinality and hashed-volume literal in the README and summaries agrees with 4 runs × 3 chunks = 12, 408,576 `digest` nodes per run per lane per pass, and 388,096 distinct compared nodes |

## 19. Five-minute user runtime test plan

Agents cannot run the Flatpak GUI; the user is the runtime tester
(`docs/process/wp-workflow.md:74-79`).

### 19.1 Getting a world

The runner supports `WP40_T5_PROBE_KEEP_WORLD=1`. When set, after the arm-`B`
order-`O1` capture passes its gates, the runner copies that run's world to
`tools/wp40/results/t5_probe/<manifest-digest>/world-B-O1/` (ignored by
`.gitignore:11`, never committed) **before** `trap cleanup` removes the temporary
root, and prints the absolute path plus the steps below. The evidence copy under
`tools/wp40/evidence/` is separate, read-only and never re-hashed afterwards.

The user copies that directory into
`~/.var/app/org.luanti.luanti/.minetest/worlds/` — the sibling of the `games/`
directory `tools/sync_to_luanti.sh:10` targets and of the `debug.txt` at
`AGENTS.md:71` — and opens it with the installed Grudgelands game. **This is
visual inspection only.** The world came from a `git archive` of `1b38943` while
the installed game is whatever was last synced, and the Ocean Mask healing LBM,
mob ABMs and node timers run as soon as a player is present
(`reference_projects/luanti/src/serverenvironment.cpp:576`, `:581`, `:957`,
`:968`) and may modify it. No digest is ever recomputed from a world opened in
the GUI.

Two things are expected and are not defects. **Unsettled liquid:** the capture
pins `liquid_update = 86400`, so the world was saved before the periodic drain
ever ran; the user's own configuration restores the 1.0-second period and the
queue settles within seconds of play. **An ungenerated column at
`x ∈ [688, 767]`:** `k_x = 9` is the gap chunk (6.3) and was never requested; the
GUI generates it on demand using the *installed* game, so nothing there is
evidence of anything.

### 19.2 Setup, and what the probe already recorded

```
/grantme fly, fast, noclip, teleport, settime
/time 12000
```

The runner prints, alongside the world path, a block taken verbatim from the
run's `case_baseline` records: per case, the anchor column, `native_surface_y`,
the native content counts over the write extent, and the realized `c` / `p` / `q`
/ `l` predicates. **The table below refers to those recorded values rather than
assuming what the world looks like.** If `native_surface_y` for the case-4
columns is above `y = 7`, the bar is buried and the user is told so first.

### 19.3 The five minutes

| Step | Where | What to look at | Red flag |
| --- | --- | --- | --- |
| 1 | `/teleport 848 4 715`, then `noclip` along `x` from 835 to 860 | the micro-case-4 **gold** bar crossing `x = 847 \| 848`: one continuous 16-node run of `default:goldblock`, 8 nodes each side, 8 × 8 in cross-section. `noclip` is required — `native_surface_y` will normally put the bar inside solid rock | the bar is 8 nodes long instead of 16, one half is missing, or the halves are offset. A reportable observation, not a display artefact — 10.13 says what may and may not be concluded from it |
| 2 | `/teleport 848 <native_surface_y + 3> 715` | lighting continuity across `x = 848` **at the surface**; underground light is uniformly 0, so a seam is not observable at the bar's own depth | a visible vertical light seam whose edge sits exactly at `x = 848`. If `native_surface_y` is `null` for both case-4 columns, skip this step and say so |
| 3 | `/teleport 648 4 715` (`noclip`), then east to 663 | the micro-case-3 cells: 8 × 8 × 8 of water at `x ∈ [644, 651]`, `y ∈ [0, 7]`, `z ∈ [712, 719]`, and 8 nodes east 8 × 8 × 8 of cobblestone stairs at `x ∈ [660, 667]`, all facing the same way | stairs with random rotations — the probe writes `param2 = 1` uniformly over that box and no `param2` at all elsewhere |
| 4 | `/teleport 631 4 715` (`noclip`) | the micro-case-2 cut/fill cell: an 8 × 8 × 8 air pocket at `y ∈ [0, 7]` directly on an 8 × 8 × 8 stone block at `y ∈ [-8, -1]`, at `x ∈ [628, 635]`, `z ∈ [712, 719]` | the pocket is filled, or the stone slab is missing — the transaction did not survive the blit |
| 5 | anywhere else in `x ∈ [608, 687]` or `x ∈ [768, 927]` at `z ∈ [688, 767]` | ordinary untouched v7 Grudgelands terrain | **any** artificial-looking block, flat plane or hole outside the six declared write boxes. `V-01` should have caught it |
| 6 | anywhere in the three chunks | dig down a few nodes; look for unknown-node placeholders | a purple/`unknown node` block means a content-ID mismatch between the archive game and the installed game — record it and stop; the world is then not comparable |

Total flying distance is under 500 nodes. **This pass confirms no digest, no
timing, no operation count and no order comparison** — those come only from the
headless captures and their gates, and a GUI session corroborates but does not
replace them, in the sense of `tools/wp40/dungeon_probe/README.md:60-61`.

## 20. Disposal and non-reuse

**Rule.** Probe code is discarded when the real T5 package is cut. It "never
becomes a parallel production path or production adapter foundation"
(`wp40-acceleration-and-delivery-plan.md:530-532`). The durable result is this
contract, the package README and the committed evidence.

**Mechanics.** The first commit of the real T5 package deletes the tree entirely
(`git rm -r tools/wp40/t5_probe`). `tools/wp40/evidence/t5-probe-<digest>/` is
**retained** — committed, reviewed, immutable. Working notes, kept worlds and
unreviewed captures live under `tools/wp40/results/` (`.gitignore:11`) and are
left to be deleted.

**The disposal proof the T5 review runs** — two commands with expected output,
written into the package README so the later reviewer need not rediscover them:

```
# (1) the probe tree no longer exists
test ! -d tools/wp40/t5_probe

# (2) no probe identifier appears anywhere outside the evidence tree
rg -n 'grug_wp40_t5_probe|t5_probe' \
   mods/ tools/ docs/ game.conf minetest.conf \
   --glob '!tools/wp40/evidence/**' \
   --glob '!docs/research/wp40-t5-0-engine-probe-contract.md'
#   -> must print nothing (rg exits 1)
```

Check (2) covers `docs/` as well, excluding only this contract, which necessarily
names the identifiers. `rg` must be present before it is trusted — a missing `rg`
exits 127 and would read as "no matches" (`AGENTS.md:133-136`) — so the review
runs the `rg` preflight of `tools/wp40/run_t1.sh:4-9` first.

**Stated limitation.** These are name-based checks and a rename defeats them. An
earlier draft proposed a committed per-file content-hash manifest plus a
`comm`-based tree-wide comparison to close that; it is dropped as
disproportionate for an eleven-file probe whose deletion is a single `git rm -r`
visible in one diff. The residual risk is someone deliberately copying a probe
file into production and editing its identifiers, which a content hash would also
not survive, and which ordinary review of the T5 diff is the right instrument
for.

## 21. Specification-level STOP conditions

Conditions that would have stopped this **specification**, evaluated at contract
time; distinct from section 15's run-level aborts. Each row gives the verdict and
points at the section that carries the argument. **No row restates one.**

| # | Specification-level stop condition | Verdict | Argument lives in |
| --- | --- | --- | --- |
| 1 | Existing writers cannot be isolated or attributed. | **not fired**, after one correction | 6.1 (every writer with its deciding guard; determinism plus arm-to-arm cancellation under two conditions and four gates), 6.2 and 6.4 (the two game-Lua writers isolated by cited guards), S14 (why no in-callback provenance signal is used). **The correction:** the first coordinate family considered — deep ocean — fails this row (6.2, "Rejected coordinate family") |
| 2 | The required IPC direction is unsupported or ambiguous in pinned source. | **not fired** | S3a (already production-proven in this repository), S3b (unambiguous in pinned source; no push and no key enumeration is a design fact, so main polls), 12.4 (the four keys), 4b (measured as telemetry, never adopted) |
| 3 | Instrumentation would require production edits. | **not fired** | 8.1 (eleven files, all under `tools/wp40/t5_probe/`), 10.2 (the arm is one generated configuration key, not a code change), 10.12 (per-call counting by a proxy table with a static grep gate, not by patching engine or game) |
| 4 | A needed measurement requires an unbounded or insecure design. | **not fired**, honest near miss — risk **R1** | S11 (no mapgen-state process metric exists through the public Lua API), 12.4 (main-state RSS demoted to best-effort with a mandatory `"unavailable"` and a `reason`; the rejected shell-side alternative), 14.1 (every other measurement bounded by contract literals) |
| 5 | Chunk-order identity cannot be defined without T3/T4 semantics. | **not fired**, honest near miss — risk **R2** | 10.4 and 12.6 (the identity is definable over engine artifacts only, and the probe defines its own canonical serialization), 10.14 (what is *not* definable is three of the nine request **schedules** — a schedule-set reduction, not a failure to define the identity) |
| 6 | The probe would need to freeze a real production payload/schema. | **not fired** | section 9 (six box sextuples, five node names, one `param2` constant, a three-way dispatcher, and a vocabulary borrowed from nobody; `v0` says nothing here is a version-1 anything), section 20 (the tree is deleted before T5 begins) |
| 7 | The proposed evidence cannot distinguish baseline behaviour from the injected delta. | **not fired for the payload delta; explicitly not answered for the script-presence delta** | 10.2 and 10.8 (the arms differ in exactly one configuration key, verified by `X-01` … `X-06` before any comparison is reported), 10.3 (the CORE/SEAM split). What this scope does **not** answer is whether loading a mapgen script is itself byte-neutral — that needed a third, script-free arm, and it is non-claim 12 rather than a quiet assumption |

**One additional check beyond the mandated seven — package cost and
non-interference.** Cost is **not exceeded**: 4 runs, 12 generated mapchunks, 11
files, one strictly serial engine sequence, the ceilings of 14.1 and a cost
projection folded into the first capture (14.3), against "small, roughly one
compact tools-only package plus review"
(`wp40-acceleration-and-delivery-plan.md:528`). Non-interference is clean: no
existing writer is disabled (`:491-493`; 6.1 names every overlap),
`tools/sync_to_luanti.sh` is never called, reference pins are never modified, and
every world is disposable and guarded.

**No hard stop condition fired.** Three near misses must be surfaced:

**R1 — process RSS requires the main-state insecure environment.** *Mitigation:*
best-effort with an explicit `"unavailable"` marker and a `reason`, never a hard
error and never a vanishing field (12.4).

**R2 — three of nine §6.2 schedules are not instantiable** (`wp40-engineering-brief.md:2979-2985`).
*Mitigation:* stated plainly in 10.14; README and summary are gated against
presenting the result as the §6.2 gate (reviewer item 19).

**R3 — engine-native chunk-order dependence exists by construction, and this
probe cannot attribute its cause** (S12). *Mitigation:* paired per-order controls
in **both** compared regions (`V-06`); CORE excludes exactly the rind a
neighbour's emerged VM reaches; and 10.13's cascade reports an observed order
effect **without attributing it**, recording why no deterministic controlled
negative is constructible at this scope. The probe reduces the *risk of
misattribution*, not the order dependence itself.

## 22. Player-visible impact

**Player-visible impact: none.** In the form required by
`wp40-acceleration-and-delivery-plan.md:635-655`: a player would notice
**nothing** — the package changes no file under `mods/`, adds no registration to
the shipped game, and produces only disposable worlds that are never
distributed; the optional kept world of 19.1 is a developer artefact under an
ignored path. **Everything remains native v7 behaviour** — the probe pins no
mapgen behaviour setting, and the three chunks it generates are ordinary
Grudgelands v7 chunks plus a synthetic marker inside six declared boxes.
**Nothing is simplified or omitted compared with decided design**, because this
package implements no design; section 9 explains why that is the point. **No
fresh-world regeneration is required** and no existing or future player world is
affected. **No `docs/design/` rule is needed or changed**: the authoritative
passages remain [`docs/design/world_zones.md`](../design/world_zones.md) and
[`docs/design/world.md`](../design/world.md), which this contract restates
neither of and links both. Per `:647-649` that is sufficient; the only user
decision required is acceptance of this contract (1.3).

## 23. Open decisions

**None.** Every decision this contract needed is closed in the section that owns
it, and each of those sections is reachable from the heading list above; §17 and
§18 turn the closed decisions into checkable items. No decision is deferred to
the implementation package, and none is left to the implementer's judgement.
