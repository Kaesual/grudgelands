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

`T5` in `wp40-engineering-brief.md:1975` ("T5-entry availability") and `:3209-3210`
("the accessible `y = -701 .. -1000` T5 entry band") is a **resource depth
tier**, not a task. Only section 7 of the brief (`:4091` the `T5` task row,
`:4106` "Only T5 owns the VoxelManip adapter and transaction.", `:4117`) and
`wp40-acceleration-and-delivery-plan.md:475-533` mean the terrain adapter.
Everywhere below, `T5` and `T5-0` mean the adapter task and this probe. No
sentence here refers to the depth tier.

### 1.3 What acceptance authorizes

Acceptance of this contract authorizes exactly one follow-on package that:

1. creates files only under `tools/wp40/t5_probe/` (section 8);
2. runs six headless disposable-world engine captures (section 10) on the
   designated host;
3. commits reviewed evidence under `tools/wp40/evidence/t5-probe-<digest>/`;
4. reports the observations of section 11 and the risks of section 21.

Acceptance authorizes **none** of: a production file change, a `mods/` change,
a production registration, a second reusable VoxelManip adapter, a schema or
operation-type freeze, a run of `tools/sync_to_luanti.sh`
(`docs/process/wp-workflow.md:42-45`), an edit to any of the six locked T2
surfaces (`wp40-t2-plan.md:227-234`), or any movement of full T5 ahead of T3
and T4 (`wp40-acceleration-and-delivery-plan.md:477-479`).

---

## 2. Probe definition

T5-0 is a tools-only, disposable, headless engine-seam probe that generates six
fixed mapchunks of a production-like Grudgelands world in two request orders
under three arms — a driver-only substrate control, a driver plus a
zero-VoxelManip-call mapgen script, and the same driver plus a four-case
synthetic mapgen payload — and compares decoded node lanes, exact VoxelManip
operation counts, callback timings and Lua heap between them, so that a wrong
assumption about the Luanti mapgen seam (script loading, callback contract,
bidirectional IPC, `set_data`/`set_param2_data` separation, bounded lighting,
conditional `update_liquids`, central-slice ownership across a later
neighbour's generation, and what timing/memory facilities the mapgen state
actually exposes) surfaces now rather than after T4, without creating
production code, without freezing any T2/T3/T4-owned schema or vocabulary, and
without claiming representative production performance.

---

## 3. Scope and non-claims

### 3.1 In scope

- The engine seams enumerated in section 7, measured against the pinned-source
  expectations recorded there.
- The four micro-cases of `wp40-acceleration-and-delivery-plan.md:497-502`,
  instantiated exactly as section 10 defines them.
- Two chunk request orders with a paired control per order (section 10.7).
- Callback wall time via `core.get_us_time()` and Lua heap via
  `collectgarbage("count")` in both states; process RSS best-effort (section
  12.4).

### 3.2 Non-claims

T5-0 does **not** prove, establish, validate, freeze or make any claim about:

1. the final T2 compiled payload, its records or its field names — T2 owns them
   (`wp40-engineering-brief.md:4088`, `:2247-2257` for what the dataset
   contains, `:2259-2261` for what it may never contain);
2. the `grug_zones` public API — T3 owns it (`:4089`);
3. the closed typed resolver matrix, the four named resolver pairs, the final
   per-voxel operation plan, the deferred-coverage extension, the exact-host-only
   deep resource type or the offline dungeon-guard oracle — T4 owns them
   (`:4090`, `:2109-2113`, and specifically `:2113` "There is no universal
   numeric \"higher feature wins\" fallback.");
4. final operation types or conflict rules of any kind;
5. the production T5 adapter or transaction (`:4106` "Only T5 owns the
   VoxelManip adapter and transaction.");
6. representative production performance. No threshold in
   `wp40-engineering-brief.md:3339-3358` is evaluated, approached or claimed by
   this probe, and the brief itself records that "No number in this section
   claims a successful measurement" (`:3471-3472`);
7. full dungeon, resource or biome behaviour;
8. T5, T9 or release readiness;
9. logical-biome→content mappings, top/filler, decoration candidates, water
   normalization or the authored vein catalog — T6/T7 own them (`:4092-4093`);
10. **any statistical property of its own timings.** Every timing this probe
    emits is `n = 1`: one run per (arm, order) cell, no warm-up, no repetition,
    no variance, no outlier rule, no confidence interval. The summary carries
    `timings_are_golden: false` and `timing_replicates: 1`, and the cost
    projection is explicitly one unreplicated sample multiplied by six
    (section 14.3);
12. **a settled liquid state.** The probe pins `liquid_update = 86400` to
    suppress `Server::AsyncRunStep`'s background drain
    (`reference_projects/luanti/src/server.cpp:781-792`) for the bounded
    lifetime of the run, so what it compares is the **deterministic
    post-generation** liquid state — `update_liquids()`'s queueing plus
    `finishBlockMake`'s `transformLiquidsLocal` bounded by `liquid_loop_max`
    (`reference_projects/luanti/src/servermap.cpp:300`, spill at `:304-308`).
    It is not a settled state, it does not substitute for the brief's
    "frozen liquid-settling procedure" (`wp40-engineering-brief.md:3005`) or
    "frozen quiescence limit" (`:1405`), and it makes no claim about how liquid
    behaves once a server steps normally;
11. **whole-chunk byte identity.** `V-01`'s wording — "loading a mapgen script
    changes generated bytes" — is evidenced on CORE and SEAM only: 110,592 of
    each measured chunk's 512,000 central voxels, or **21.6%**, plus the SEAM
    box. The outer 16-node rind of every central slice is deliberately excluded
    (section 10.3) and is never compared. A `V-01` pass therefore means "no
    difference in the compared regions", not "no difference in the chunk", and
    the summary states it in those words.

It also does **not** move full T5 ahead of T3 and T4
(`wp40-acceleration-and-delivery-plan.md:477-479`).

### 3.3 Register of the non-claim statements this contract adopts

This package writes its non-claims in the register already established in the
repository, and adopts these sentences by reference:

> "A static-only PASS makes no installed-host claim. Host evidence corroborates
> but does not replace the pinned 5.17-dev source audit. The probe never syncs
> or modifies the installed Grudgelands game, reference pins, or a persistent
> world." — `tools/wp40/dungeon_probe/README.md:60-63`

> "That count is recorded as a non-portable observation, not a golden
> acceptance value; only positivity is invariant." —
> `tools/wp40/dungeon_probe/README.md:37-38`

> "This finite oracle does not claim unexplored exterior coverage." —
> `wp40-engineering-brief.md:3047-3048`

> "This is deliberately a sound over-approximation and a veto, not a positive
> per-node classifier." — `wp40-engineering-brief.md:1304-1305`

> "Explicit two- and four-emerge-thread runs are diagnostic only because pinned
> v7 does not promise arbitrary parallel slice independence." —
> `wp40-engineering-brief.md:3061-3062`

By the same rule: every count, timing, digest and byte comparison this probe
produces is a non-portable observation of one host, one engine build, one seed
and one repository commit. Only the *relations* the gates assert — equality,
inequality, exact operation counts, and emptiness of a named delta — are
invariant, and only within a single run set.

---

## 4. Acceleration plan §8 versus the binding brief

`wp40-acceleration-and-delivery-plan.md:475-533` is the origin of this package
and is a discussion draft (`:3-6`). Five points of it differ from
`wp40-engineering-brief.md`. In every case the brief wins.

| # | Acceleration plan §8 | Binding brief | Resolution in this contract |
| --- | --- | --- | --- |
| a | "captures the same chunks once without and once with the injected probe" — one baseline capture (`:488-490`) | every schedule needs its own paired WP40-disabled native control world with the same order; "if either the native controls or the WP40 worlds differ across schedules, the rollout manifest fails" (`:3029-3038`) | **Three arms, both orders (D1/D9).** Six runs, not two. `A1 − A0` isolates mapgen-script presence; `B − A1` isolates the payload; each order carries its own paired controls (sections 10.7, 10.9). |
| b | new evidence "is limited to the missing directions and operations, including mapgen-to-main IPC" (`:513-516`) | "There is no IPC access in `H`, `id_at`, a spatial query, column loop, candidate loop, or generated-chunk callback." (`:2278-2279`); "IPC is never a cache-miss or runtime recovery channel." (`:2318`) | **Measured as capability telemetry only, explicitly not adopted.** The payload's per-callback `ipc_set` is labelled `production_adopted: false` in-band (section 12.2, tag `chunk_callback`), is present in both the A1 and B payloads so it cancels in `B − A1`, and the contract records that production may not do this. |
| c | "The primary substrate is the current production-like Grudgelands baseline" (`:487-491`), which runs `mgv7_dungeon_ymax = 31000` | the vertical contract binds `mgv7_dungeon_ymax = -193` (`:335-337`, `:2970-2971`) | **D4: do not pin it.** The probe runs the engine default 31000, which is what the repository at `1b38943` actually produces (`tools/wp40/evidence/t0-post-wp43-wp18-wp36/70adabd28401e820ec86e8786bf0da368225c8624e42ed02dd3bce175fd3cafc/raw/run-001.map_meta.txt:175`), records it, and makes **no** claim about `-193`. `mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua:86` is source-catalog **intent**. The file *is* `dofile`d in the main state on every load (`mods/MAPGEN/grug_mapgen/init.lua:93` → `mods/MAPGEN/grug_mapgen/wp40/init.lua:18` → `mods/MAPGEN/grug_mapgen/wp40/compiler.lua:61`), but its value never reaches a mapgen setting: there is no `core.set_mapgen_setting` anywhere under `mods/`, and the committed `run-001.map_meta.txt:175` shows the engine default `31000`. It is never treated as substrate. |
| d | the probe performs VoxelManip writes in a mapgen callback | "No task may introduce a second geometry evaluator, placement path, or VoxelManip transaction for convenience." (`:4080-4081`) | **The probe IS a second VoxelManip write path, and this is the mitigation, stated explicitly, not implicitly:** it is not a task in the T0–T9 decomposition; it creates no file under `mods/`; it is registered by no production code path; its vocabulary is deliberately foreign (section 9); it is deleted or archived before T5 begins and the T5 review proves its absence by the four concrete checks of section 20.3. The brief's sentence forbids a second transaction *inside the WP40 task graph for convenience*; this probe is outside that graph and exists to test the seam the single transaction will later use. |
| e | silent about the locked T2 surfaces | "No work package may touch them as a side effect." (`wp40-t2-plan.md:237`) | **Section 8.3 carries the explicit clause** naming all six files and the reviewer check. |

---

## 5. Substrate manifest

Every row is bound into the manifest digest (section 13.3). "Class" is
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
| `liquid_update` | **`86400`** (engine default `1.0`) | default `reference_projects/luanti/src/defaultsettings.cpp:533`; read once into `m_liquid_transform_every` at `reference_projects/luanti/src/server.cpp:597`; the drain it gates is `reference_projects/luanti/src/server.cpp:781-792` | **probe** | yes — **a deliberate determinism pin, explicitly not a production-like value.** `Server::AsyncRunStep` accumulates `m_liquid_transform_timer` and drains the server-wide queue only when it reaches `m_liquid_transform_every` (`:783`); at 86400 s that cannot happen inside a run whose outer timeout is 180 s. Consequence, stated in this row: the probe compares the **deterministic post-generation** liquid state and never a settled one (section 10.15, non-claim 12 in section 3.2). It also suppresses the purge branch, whose `liquid_queue_purge_time` is read inside `transformLiquids` itself (`reference_projects/luanti/src/servermap.cpp:1260`), reachable only from that same drain |
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
| probe arm | `A0` \| `A1` \| `B` | this contract, section 10.1 | probe | yes |
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
as a `manifest` record (section 12.2). A disagreement between the two is a
run abort (section 15, `A-06`).

---

## 6. Existing-writer inventory and coordinate selection

### 6.1 Existing writers, and whether they fire at the probe coordinates

The probe coordinates are `k_y = 0`, `k_z = 9`, `k_x ∈ {6, 7, 8, 9, 10, 11}`
(section 6.3). "Fires?" answers for those six mapchunks only.

| # | Mechanism | Owner | `file:line` | What it writes | Fires? | Deciding guard |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | mgv7 `makeChunk` C++ stages: terrain, heightmap, biomes, caves/caverns/randomwalk, ores, dungeons, decorations, dust, liquid, lighting | engine | `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:321-379` | the entire chunk | **yes, all of them** | none — unconditional for a v7 chunk. Deterministic: `blockseed = getBlockSeed2(full_node_min, seed)` (`:318`) |
| 2 | native dungeons | engine | `reference_projects/luanti/src/mapgen/mapgen.cpp:890-899`, write range `:952` | dungeon walls/stairs/air over the **full emerged** range | **yes, where the noise gate passes** | `node_min.Y > max_stone_y \|\| node_min.Y > dungeon_ymax \|\| node_max.Y < dungeon_ymin` (`:892-894`) is false with the engine-default `±31000`; then `num_dungeons >= 1` (`:896-899`) |
| 3 | registered biomes (20, each carrying `node_dungeon`/`node_dungeon_alt`/`node_dungeon_stair`) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/biomes.lua:112-116` | biome top/filler/stone/dungeon node identity | **yes** | none |
| 4 | registered ores (4 blob + scatter bands + 5 strata) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/ores.lua:45-46,64-65,83-84,122-123,261-263` | ore nodes inside their y bands | **yes, for every band whose y range meets `[-32,47]`** | per-ore `y_min`/`y_max` |
| 5 | registered decorations (~40, every one `y_min = 1`) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/decorations.lua:93`, `:114` | schematics and simple decorations above y = 1 | **yes** | `y_min = 1` is inside central y `[-32,47]` |
| 6 | 26 `register_alias("mapgen_*")` | `default` | `mods/BASE/default/mapgen.lua:7-37` | determines *which* node the engine writes for each mapgen slot | **yes (indirectly)** | none |
| 7 | Ocean Mask mapgen callback (carve, water fill, sunlight stamp, `update_liquids`, `calc_lighting`) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua:515-518` | column carve + `default:water_source` + `param1` + light | **no** | `if not box_needs_mask(minp, maxp, SHELL) then return end` (`:516-518`). Derivation in section 6.2. The guard is evaluated **before** the first `vm:` call (`:520` is the first), so a skipped chunk costs zero VoxelManip operations |
| 8 | Ocean Mask healing LBM | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/ocean_mask.lua:606` | idempotent coastal re-carve | **no** | LBMs are reached only from `activateBlock` (`reference_projects/luanti/src/serverenvironment.cpp:576`, `:581`), called only at `:957`/`:968` over `m_active_blocks`, which is the forceload list ∪ player radius. `grep -rn forceload mods/` is empty and the probe world has no player |
| 9 | `structures.lua` main-environment `on_generated` (camps, outposts, bandit fires) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/structures.lua:776` | camp/outpost/fire nodes | **callback runs, writes nothing** | early return at `:850-852` (`if #camps == 0 and #outposts == 0 and #fires == 0 then return end`) — no VoxelManip is fetched (`:854` is the first). Section 6.4 proves the three lists are empty at these coordinates |
| 10 | `chunk_near_outpost` / `chunk_near_bandit_camp` POI and mod-storage decisions (x/z only, any y) | `grug_mapgen` | `mods/MAPGEN/grug_mapgen/structures.lua:559-567`, `:761-769`, `chunk_covers` at `:492-495` | POI records / mod storage, no nodes | **no** | section 6.4 |
| 11 | `grug_core.ensure_camp_platform_built` — a **live** main-environment VoxelManip writer (`get_voxel_manip` `:336`, `read_from_map` `:337`, `build_camp` call `:364`, `write_to_map` `:387`), ≤ 3 attempts per capital per session (`MAX_BUILD_ATTEMPTS = 3`, `:288`) | `grug_mapgen` / `grug_core` | `mods/MAPGEN/grug_mapgen/structures.lua:288-364`, `:387`; fallback stub only at `mods/CORE/grug_core/init.lua:768-770` | capital platform nodes | **no** | only at the six capital anchors `(0, ±900)`, `(±550, ±900)` (`mods/CORE/grug_core/init.lua:84-91`, `SEAT_Z = 900` at `:27`) |
| 12 | unconditional capital startup sweep: six `core.after(60 + 15·i)` timers → `request_camp_platform` → possibly `core.emerge_area((cx−16,−16,cz−16) … (cx+16,120,cz+16))` | `grug_core` | `mods/CORE/grug_core/init.lua:934-950`, emerge at `:903-921`, seed-dependent short-circuit at `:887-893` | generates map on its own at t ≈ 60/75/90/105/120/135 s | **not inside the measured chunks or their emerged shells**, but it is a run-comparability hazard | section 6.5 and D5 |
| 13 | `grug_mobs` camp/banner LBMs | `grug_mobs` | `mods/ENTITIES/grug_mobs/camps.lua:733`, `:755` | metadata and node timers only, never node content | **no** | same as row 8; and `grug_mobs` never sets `on_map_load`, so mobs use the ABM branch (`mods/ENTITIES/mobs/api.lua:4162-4174`), never the LBM branch (`:4150-4160`) |
| 14 | `mods/MAPGEN/grug_mapgen/wp40/init.lua` | `grug_mapgen` | `:8-10` | nothing — `enabled = false`, zero `core.register_*`; `wp43_handoff.lua` is never `dofile`d | **no** | inert |
| 15 | the T5-0 payload | this package | `tools/wp40/t5_probe/payload/mapgen.lua` | section 10 | **arm B only** | arm switch |

**No chunk anywhere in this world is free of engine writers.** Rows 1–6 fire in
every chunk of every arm. That is acceptable for exactly two reasons, and stops
being acceptable when either fails:

- *Determinism.* Every one of rows 1–6 is a pure function of `blockseed`
  (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:318`), the frozen mapgen
  settings and the frozen registrations. Given identical settings and
  registrations, identical chunk coordinates and identical request order, they
  produce identical bytes.
- *Arm-to-arm cancellation.* The three arms differ only by the value of one
  configuration key (section 10.2). The mod set, the archive tree, the seed and
  the request order are byte-identical, so rows 1–6 contribute identically to
  `A0`, `A1` and `B`, and vanish from `A1 − A0` and `B − A1`.

Cancellation stops being valid the moment any of the following holds, and each
is a gate:

1. the registered content set differs between arms — detected by the
   `content_id_table_sha256` equality assertion (section 10.8, abort `A-04`);
2. the realized mapgen settings differ between arms — detected by the
   `manifest` record comparison (abort `A-06`);
3. the request order differs between arms — the driver is byte-identical in all
   arms and emits its realized order, which is compared (abort `A-07`);
4. rows 1–6 are themselves order-dependent in the compared region — this is
   *expected* in the SEAM region and is exactly why every order carries its own
   paired `A1` control (section 10.9, D9).

### 6.2 Ocean Mask: the exact metric, and the derivation

`box_needs_mask(minp, maxp, grow)` (`mods/MAPGEN/grug_mapgen/geometry.lua:237-243`)
returns:

```
if maxp.y < MASK_MIN_Y then return false end
local lo = box_distance_range(minp, maxp, grow)
return lo < TAPER + INSET_MAX
```

`box_distance_range` (`mods/MAPGEN/grug_mapgen/geometry.lua:209-227`) computes,
for the box grown by `grow` in x and z:

```
ax_far  = max(|minp.x|, |maxp.x|) + grow
ax_near = (minp.x > 0) and max(minp.x - grow, 0)
          or (maxp.x < 0) and max(-maxp.x - grow, 0)
          or 0
az_far  = max(|minp.z|, |maxp.z|) + grow
az_near = (minp.z > 0) and max(minp.z - grow, 0)
          or (maxp.z < 0) and max(-maxp.z - grow, 0)
          or 0
lo = min(X_HALF - ax_far, az_near - Z_MIN, Z_MAX - az_far)
```

`lo` is the **inland-signed distance**, minimised over the grown box, to the
nearer of the two mirrored continent rectangles: positive inside the rectangle,
negative outside it (`mods/MAPGEN/grug_mapgen/geometry.lua:99-111`,
`continent_distance`). The mask therefore fires when `lo` is **small**, and is
skipped only when `lo >= TAPER + INSET_MAX = 300`, i.e. only for a box every
column of which is at least 300 nodes **inland**. `TAPER = 150` and
`INSET_MAX = 150` are at `mods/MAPGEN/grug_mapgen/geometry.lua:36-37`;
`SHELL = 16` at `:60`; `SEA_FLOOR_CAP = surface_cap(-SHELF_WIDTH) = -15` and
`MASK_MIN_Y = SEA_FLOOR_CAP + 1 = -14` at `:143`, `:151`.

The callback passes `SHELL` as `grow` (`ocean_mask_mapgen.lua:516`) and the
central chunk as `minp`/`maxp` — the callback's `minp`/`maxp` are the central
chunk, not the emerged area
(`reference_projects/luanti/src/script/cpp_api/s_mapgen.cpp:37-39`).

With `k_z = 9` the central z range is `[688, 767]`, so `az_near = 672` and
`az_far = 783`, giving `az_near - Z_MIN = 572` and `Z_MAX - az_far = 917`.
With `k_y = 0` the central y range is `[-32, 47]`, so `maxp.y = 47` is not
below `MASK_MIN_Y = -14` and the first guard does not decide.

| `k_x` | central x | `ax_far` | `X_HALF - ax_far` | `lo` | `lo >= 300`? | `box_needs_mask` |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | `[448, 527]` | 543 | 957 | **572** | yes | **false** |
| 7 | `[528, 607]` | 623 | 877 | **572** | yes | **false** |
| 8 | `[608, 687]` | 703 | 797 | **572** | yes | **false** |
| 9 | `[688, 767]` | 783 | 717 | **572** | yes | **false** |
| 10 | `[768, 847]` | 863 | 637 | **572** | yes | **false** |
| 11 | `[848, 927]` | 943 | 557 | **557** | yes | **false** |

The binding margin is the strait-facing front edge (`az_near - Z_MIN = 572`)
for five of the six chunks and the flank (`X_HALF - ax_far = 557`) for `k_x = 11`.
Both exceed 300 by more than 250 nodes, so the exclusion is not marginal.

**Rejected coordinate family, and why it is rejected.** A coordinate family far
out at sea — for example `k_x ∈ {30 … 35}`, central x `2368 … 2847` — does *not*
escape the Ocean Mask. There `ax_far = 2463 … 2863`, so
`X_HALF - ax_far = -963 … -1363`, `lo` is strongly negative, `lo < 300` holds,
and `box_needs_mask` returns **true**: the mask fires in every such chunk and
carves every column down to `SEA_FLOOR_CAP = -15`, floods it, stamps sunlight
runs and calls `update_liquids()` and `calc_lighting()`
(`mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua:520-560`). Because all mapgen
scripts share one Lua state per emerge thread
(`reference_projects/luanti/src/emerge.cpp:641-668`,
`reference_projects/luanti/src/emerge_internal.h:56`) and all
`register_on_generated` callbacks are appended to one table
(`reference_projects/luanti/builtin/emerge/register.lua:56`) which
`RUN_CALLBACKS_MODE_FIRST` executes **in full** in registration order
(`reference_projects/luanti/builtin/common/register.lua:23-27`, mode 0 keeps
only the first return value and short-circuits nothing), an ocean coordinate
family would make Case 1a — "zero VoxelManip calls of any kind in this
mapchunk" — unachievable, would destroy Case 1b's isolation of `get_data`
cost (the mask already performs one), and would make Case 3's water cell
meaningless in a chunk that is already water. The inland family is chosen for
those reasons, not for convenience.

### 6.3 The coordinate lattice and the measured set

The vertical lattice is `wp40-engineering-brief.md:398-399`:

```
central(k) = [-32 + 80k,  47 + 80k]
full(k)    = [-48 + 80k,  63 + 80k]
```

This follows from `chunksize = 5` (`reference_projects/luanti/src/defaultsettings.cpp:539`),
`MAP_BLOCKSIZE 16` (`reference_projects/luanti/src/constants.h:64`) and
`EMERGE_EXTRA_BORDER{1,1,1}` MapBlocks = 16 nodes per side
(`reference_projects/luanti/src/servermap.h:175`, applied at
`reference_projects/luanti/src/servermap.cpp:213-214`, `:264-265`, `:325-326`).
Central chunk = 80³ = 512,000 nodes; emerged VM = 112³ = 1,404,928 nodes;
`emin = minp - 16`, `emax = maxp + 16`.

**Measured set:** `k_y = 0`, `k_z = 9`, `k_x ∈ {6, 7, 8, 9, 10, 11}` — six
mapchunks.

| `k_x` | central box | emerged box | Case |
| --- | --- | --- | --- |
| 6 | `(448,-32,688) … (527,47,767)` | `(432,-48,672) … (543,63,783)` | 1a |
| 7 | `(528,-32,688) … (607,47,767)` | `(512,-48,672) … (623,63,783)` | 1b |
| 8 | `(608,-32,688) … (687,47,767)` | `(592,-48,672) … (703,63,783)` | 2 |
| 9 | `(688,-32,688) … (767,47,767)` | `(672,-48,672) … (783,63,783)` | 3 |
| 10 | `(768,-32,688) … (847,47,767)` | `(752,-48,672) … (863,63,783)` | 4, low half |
| 11 | `(848,-32,688) … (927,47,767)` | `(832,-48,672) … (943,63,783)` | 4, high half |

### 6.4 Structure exclusion

`chunk_covers(minp, maxp, x, z, half)` (`mods/MAPGEN/grug_mapgen/structures.lua:492-495`)
is `maxp.x >= x - half and minp.x <= x + half and maxp.z >= z - half and minp.z <= z + half`.
The three anchor families and their halves are:

- capitals, half `CAMP_HALF = 12`, at `(0, ±900)` and `(±550, ±900)`
  (`mods/CORE/grug_core/init.lua:84-91`, `SEAT_Z = 900` at `:27`);
- outposts, half `OUTPOST_HALF = 4`, over `grug_core.outpost_candidates`
  (`mods/CORE/grug_core/init.lua:266-291`, accessor `:306`) — 24 anchors plus retries;
- bandit camps, half `0`, over `grug_core.bandit_camp_candidates`
  (`mods/CORE/grug_core/init.lua:411-444`, accessor `:453`) — 12 anchors plus two lateral
  retries each.

Enumerating all 138 candidate points and projecting each through
`chunk_covers` onto the `central(k)` lattice yields the full envelope
`|x| ≤ 1354`, `|z| ≤ 1554` and exactly **122 distinct `(k_x, k_z)` chunk
columns**. The six measured columns `(6,9) … (11,9)` are not among them: at
`k_z = 9` the entire range `k_x ∈ [-14, 14]` is structure-free. Therefore
`camps`, `outposts` and `fires` are all empty for every measured chunk,
`structures.lua:850-852` returns before `core.get_mapgen_object("voxelmanip")`
at `:854`, and neither `chunk_near_outpost` (`:559-567`) nor
`chunk_near_bandit_camp` (`:761-769`) — the two x/z-only tests that write POI
records and mod storage at any y — is ever satisfied.

The implementation package must reproduce this enumeration as a committed
self-test (`tools/wp40/t5_probe/coordinate_audit.lua`, section 8.1) that
recomputes the 122-column set from `mods/CORE/grug_core/init.lua` and asserts
the six measured columns are absent. A hand-copied list is not acceptable
evidence.

### 6.5 The capital startup sweep, and why it does not touch the measured bytes

The sweep emerges `(cx − 16, −16, cz − 16) … (cx + 16, 120, cz + 16)` around
each capital (`mods/CORE/grug_core/init.lua:903-921`). For the two capitals
nearest in z, `z ∈ [884, 916]`; the containing chunk column is `k_z = 11`
(`central(11) = [848, 927]`) whose **emerged** z range is `[832, 943]`. The
measured chunks' emerged z range is `[672, 783]`. The two are disjoint by 49
nodes. The capital x columns are `k_x ∈ {-7, 0, 7}`, whose emerged x ranges
are likewise disjoint from `k_x ∈ {6 … 11}` except for `k_x = 7`, and there the
z separation already decides.

So the sweep is **not** a hazard to the measured bytes. It **is** a hazard to
run-to-run comparability: it puts unrelated emerge work on the same single
emerge thread and the same CPU at t ≈ 60 s, and its short-circuit at
`mods/CORE/grug_core/init.lua:887-893` depends on whether `core.get_spawn_level`
answers, which is seed-dependent and cannot be settled from source. Both
statements are recorded, and D5's in-run deadlines (section 14.2)
exists to make the question moot rather than to answer it.

---

## 7. Engine-source citation table

### 7.1 Seams

| # | Seam | Verdict | Lua state | Pinned-source citations | What the probe must still measure at runtime |
| --- | --- | --- | --- | --- | --- |
| S1 | `core.register_mapgen_script(path)` | **AVAILABLE** | **server only** | `reference_projects/luanti/src/script/lua_api/l_server.cpp:643` (`l_register_mapgen_script`), `:654` (`m_mapgen_init_files.emplace_back`), `:723` (`API_FCT` inside `Initialize`); `:726-735` `InitializeAsync` does not contain it. Each emerge thread builds its own Lua state and loads each registered script in registration order, then fires `on_mods_loaded`: `reference_projects/luanti/src/emerge.cpp:641-668`, `:684`, `reference_projects/luanti/src/emerge_internal.h:56`. `INIT = "emerge"` and `builtin/emerge/init.lua`: `reference_projects/luanti/src/script/scripting_emerge.cpp:29-54`, `reference_projects/luanti/builtin/init.lua:84-85` | already production-proven: `mods/MAPGEN/grug_mapgen/ocean_mask.lua:47` calls it today. Re-confirmed, not discovered. Probe measures only script **load wall time** and the **registration index** of its own callback |
| S2 | `core.register_on_generated(vmanip, minp, maxp, blockseed)` in the mapgen state | **AVAILABLE** | mapgen | registration table `reference_projects/luanti/builtin/emerge/register.lua:56`; invocation `reference_projects/luanti/src/script/cpp_api/s_mapgen.cpp:41` (`LuaVoxelManip::create(L, bmdata->vmanip, true)`), `:45-47` (`core.vmanip`), `:50-55` (four args, `runCallbacks(4, RUN_CALLBACKS_MODE_FIRST)`), `:59-60` (nils `core.vmanip`); `minp`/`maxp` are the central chunk `:37-39`. Order: `reference_projects/luanti/src/emerge.cpp:737` `makeChunk` → `:745` `on_generated` → `:753` `finishGen` → `:622-623` main-env `environment_OnGenerated`. `LuaError` → `setAsyncFatalError` + `cancelBlockMake` (`:746-757`) | callback wall time; that all registered callbacks really run (mode 0 short-circuits nothing, `reference_projects/luanti/builtin/common/register.lua:23-27`); the probe's own index in `core.registered_on_generateds` |
| S3a | IPC main → mapgen | **AVAILABLE** | both | `ModApiIPC::Initialize` in the emerge state at `reference_projects/luanti/src/script/scripting_emerge.cpp:78`, server state `reference_projects/luanti/src/script/scripting_server.cpp:159`, async `:114`; one shared store on `Server` (`reference_projects/luanti/src/server.h:349`, `:157-173`); `API_FCT`s at `reference_projects/luanti/src/script/lua_api/l_ipc.cpp:140-143`; deep copy `script_pack`/`script_unpack` (`:21`, `:40`); userdata rejected `:23`; type support `reference_projects/luanti/src/script/common/c_packer.cpp:342-401` | already production-proven: `mods/MAPGEN/grug_mapgen/ocean_mask.lua:46` sets, `mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua:60` gets. Re-confirmed, not discovered. Probe measures unpack wall time and payload round-trip fidelity |
| S3b | IPC mapgen → main | **AVAILABLE by source, UNTESTED in this repository** | both | same store, same functions, both states — see S3a. `ipc_cas` is a real CAS (`reference_projects/luanti/src/script/lua_api/l_ipc.cpp:65-87`); `ipc_poll(key, ms)` **blocks the calling thread** on a condvar (`:104-121`); there is **no** key enumeration (`:128-133`) | **the genuinely new direction.** Probe writes from the mapgen state and reads from the main state, records latency and whether a poll is needed. There is no push notification: main must poll |
| S3c | `core.save_gen_notify(id, data)` per-chunk mapgen → main push | **AVAILABLE, conditional** | mapgen writes, main reads | `API_FCT` `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:2122`, body `:1082-1100`; silently returns false unless the **main** state pre-registered the id via `core.set_gen_notify` (`:2080`; `reference_projects/luanti/src/mapgen/mapgen.cpp:1002-1013`); main reads it via `core.get_mapgen_object("gennotify").custom[id]` (`:676-711`); cleared at `reference_projects/luanti/src/emerge.cpp:634` | that the registration/read handshake actually delivers a per-chunk record, and its cost |
| S4 | IPC at mapgen-script **load** time | **AVAILABLE** | mapgen | `ModApiIPC::Initialize` runs in the `EmergeScripting` constructor before `loadMod` (`reference_projects/luanti/src/script/scripting_emerge.cpp:78`, `reference_projects/luanti/src/emerge.cpp:641-668`); no init-time guard exists in `reference_projects/luanti/src/script/lua_api/l_ipc.cpp` | load-time `ipc_get` wall time |
| S4b | `core.vmanip`, `core.get_mapgen_object("voxelmanip")`, `update_liquids()` at load time | **ABSENT (NULL deref, not a clean error)** | mapgen | `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:609-613` with `reference_projects/luanti/src/emerge.cpp:635` (`m_mapgen->vm = nullptr`); `l_mapgen.cpp:1982-1989` with `reference_projects/luanti/src/emerge_internal.h:58` and `reference_projects/luanti/src/emerge.cpp:475`, `:731`, `:759` | **nothing — the probe must not call them at load time.** Recorded as a source-settled prohibition |
| S4c | `VoxelManip()` as a constructor in the mapgen state | **ABSENT (returns nil, always)** | mapgen | `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:426-449` uses `GET_ENV_PTR` (`reference_projects/luanti/src/script/lua_api/l_internal.h:44-51`) and `EmergeScripting` never calls `setEnv` | the probe records `type(VoxelManip)` and the result of one guarded call as telemetry |
| S4d | `core.get_seed`, `core.get_mapgen_params`, `core.get_mapgen_chunksize`, `core.get_mapgen_edges`, `core.get_mapgen_setting`, `core.settings`, `core.get_us_time`, `core.get_version` at load time | **AVAILABLE** | mapgen | `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:2104-2130`; `reference_projects/luanti/src/script/lua_api/l_util.cpp:862-911` | values, and that they agree with the main state's view |
| S4e | `ValueNoise` / `ValueNoiseMap` at mapgen-script **load** time | **AMBIGUOUS — documentation and implementation disagree** | mapgen | `reference_projects/luanti/doc/lua_api.md:9871` and `:9909` say they "require the mapgen environment to be initalized, do not use at load time"; the implementation path via `core.get_seed` (`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:740-750`) suggests it works, and `LuaValueNoise`/`LuaValueNoiseMap` are registered in the emerge state at `reference_projects/luanti/src/script/scripting_emerge.cpp:63-64`. `mods/MAPGEN/grug_mapgen/geometry.lua:28-31` documents the restriction and creates its noise lazily to avoid the question | **a runtime-measurement item.** The probe creates one noise object at load time inside `pcall`, records `ok` and the error text, and samples it once. Neither outcome is a failure; both are results |
| S5 | mapgen VoxelManip surface | **AVAILABLE, with hard prohibitions** | mapgen | callback arg 1 and `core.get_mapgen_object("voxelmanip")` wrap the same `MMVManip` with `is_mapgen_vm = true` (`s_mapgen.cpp:41`, `l_mapgen.cpp:609-621`). 18 methods at `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:499-518`. See section 7.2 | per-call wall time and allocation cost; nothing about availability |
| S6 | emerged area vs central slice | **AVAILABLE** | mapgen | `get_emerged_area` `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:377-387`. **There is no engine guard restricting Lua writes to the central slice**; border blocks are blitted back but not marked generated (`reference_projects/luanti/src/servermap.cpp:341-346`) | that `emin`/`emax` are exactly `minp-16`/`maxp+16` for these chunks |
| S7 | lighting | **AVAILABLE** | mapgen | mgv7 already lit the chunk before the Lua callback (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:374-379`; `MG_LIGHT` in the default flags `reference_projects/luanti/src/mapgen/mapgen.cpp:210`, `reference_projects/luanti/src/mapgen/mapgen.h:23`). Lua `calc_lighting` runs the same `Mapgen::calcLighting` (`l_mapgen.cpp:2009-2015`, `reference_projects/luanti/src/mapgen/mapgen.cpp:466-472`): `propagateSunlight(pmin,pmax)` then `spreadLight(full emerged)`. The Lua **default** region differs from mgv7's own: Lua defaults to `emin+(0,16,0) … emax-(0,16,0)` (`l_vmanip.cpp:219-222`), mgv7 uses `node_min-(0,1,0) … node_max+(0,1,0)`. Out-of-bounds → `LuaError` (`:225-226`). `propagate_shadow` defaults true. **There is no "lighting already handled" flag**: `MapBlock::m_lighting_complete` merely defaults to `0xFFFF` (`reference_projects/luanti/src/mapblock.h:542`, `reference_projects/luanti/src/mapblock.cpp:690`) and nothing re-lights downstream (`reference_projects/luanti/src/servermap.cpp:287-291`) | whether the explicit `calc_lighting` region of section 10.4 yields order-stable `param1` across O1/O2 in CORE and in SEAM |
| S8 | liquids | **AVAILABLE** | mapgen | mgv7 already ran `updateLiquid` over the full emerged area (`mapgen_v7.cpp:369-370`), queueing into `bmdata.transforming_liquid`. Lua `update_liquids()` repeats the scan over the full emerged area and appends to the same queue (`l_mapgen.cpp:1993-1997`, `reference_projects/luanti/src/emerge.cpp:731`). `finishBlockMake` drains it via `transformLiquidsLocal` bounded by `liquid_loop_max` (`reference_projects/luanti/src/servermap.cpp:300`), remainder to the global queue (`:305-308`) | wall time of one `update_liquids()` over 1,404,928 nodes, and whether the settled result is order-stable |
| S9 | timing in the mapgen state | **AVAILABLE (monotonic only)** | mapgen | the mapgen state's util table is `ModApiUtil::InitializeAsync` (`reference_projects/luanti/src/script/scripting_emerge.cpp:77`); `core.get_us_time()` at `reference_projects/luanti/src/script/lua_api/l_util.cpp:866`, body `:77-82`, `reference_projects/luanti/src/porting.h:188-193` + `:156-161` → `CLOCK_MONOTONIC_RAW`. Sandbox whitelists `os.clock/date/difftime/getenv/time` (`reference_projects/luanti/src/script/cpp_api/s_security.cpp:173-179`); `secure.enable_security` defaults true (`reference_projects/luanti/src/defaultsettings.cpp:512`). **Not registered in the emerge state**: `core.get_gametime`, `core.get_timeofday` (`reference_projects/luanti/src/script/lua_api/l_env.cpp:1604-1616`), `core.get_server_uptime` (`l_server.cpp:726-735`) | resolution and monotonicity in practice; whether `os.clock` is usable as a cross-check |
| S10 | memory in the mapgen state | **PARTIAL — Lua heap only** | mapgen | only `collectgarbage` is whitelisted (`s_security.cpp:127`). **No engine-side memory counter is exposed to any Lua state** — absent from `l_util.cpp:862-911`, `l_server.cpp:726-735`, `l_mapgen.cpp:2104-2130`. The profiler is loaded only from the `INIT == "game"` branch (`reference_projects/luanti/builtin/init.lua:52-53`); the emerge branch loads only `builtin/emerge/init.lua` (`:84-85`). `reference_projects/luanti/doc/lua_api.md:5668-5670` warns VoxelManip memory is invisible to the Lua GC | the magnitude of `collectgarbage("count")` movement across a `get_data` of 1,404,928 entries — with the explicit caveat that the ~1.4 M-node C++ buffer is **not** in that number |
| S11 | insecure environment in the mapgen state | **ABSENT — proven twice over** | mapgen | `request_insecure_environment` is in `ModApiUtil::Initialize` only (`reference_projects/luanti/src/script/lua_api/l_util.cpp:770`), and there is an explicit source comment at `:888` — `// no request_insecure_environment here! mod origins are not tracked securely here.` — inside `InitializeAsync`, which **is** the mapgen state's table (`scripting_emerge.cpp:77`). Even if reached, `EmergeScripting` inherits `modNamesAreTrusted() == false` (`reference_projects/luanti/src/script/cpp_api/s_security.h:80`; only `reference_projects/luanti/src/script/scripting_server.h:54` overrides to true), so `getCurrentModName` returns `""` (`s_security.cpp:726-732`) and `checkModNameWhitelisted` fails on the empty name (`s_security.cpp:760-771`, reached from `l_util.cpp:529-531`) | **nothing — this cannot be measured because it cannot exist.** The absence is itself a recorded result (section 12.4) |
| S12 | determinism and chunk order | **HAZARD PRESENT BY CONSTRUCTION** | both | per-chunk decisions are order-independent (`mapgen_v7.cpp:318`) and the mapgen Lua state persists across callbacks on its thread (`emerge_internal.h:56`) while per-chunk C++ state does not (`reference_projects/luanti/src/emerge.cpp:692`, `reference_projects/luanti/src/emerge.h:47`). **But** `initBlockMake` emerges chunk ± 1 block and seeds the border from whatever is currently on the map (`reference_projects/luanti/src/servermap.cpp:229-244`, `:253-254`, `reference_projects/luanti/src/map.cpp:804-806`), and `blitBackAll` writes that border back with `overwrite_generated = true` (`reference_projects/luanti/src/servermap.cpp:291`, `reference_projects/luanti/src/map.h:334-335`, `reference_projects/luanti/src/map.cpp:860-896`). Liquid update and light spreading both run over the full padded area (`mapgen_v7.cpp:370`, `reference_projects/luanti/src/mapgen/mapgen.cpp:471-472`). The engine's own comment names it: `reference_projects/luanti/src/emerge.cpp:181-186`, "Singlenode is currently the only mapgen not affected by the unfinished slice bug", referencing `https://github.com/luanti-org/luanti/issues/9357`. Chunk order is request-driven FIFO (`reference_projects/luanti/src/emerge.cpp:487-490`, `:698-711`) with load-balanced thread assignment (`:437-455`) | **the magnitude and location of the effect** in CORE and in SEAM, separately for the native control (`A1`) and the treatment (`B`) — see D9 / section 10.9 |
| S13 | engine identity | **AVAILABLE** | both | `core.get_version()` at `l_util.cpp:893` (async/emerge) and `:775` (server); fields at `:540-564` — `hash` present only when it differs from `string`. `core.get_game_info()` also in the emerge state (`l_server.cpp:734`). `jit` table whitelisted (`s_security.cpp:193-203`, `:319-326`) and simply absent on PUC | the realized `string`/`hash`/`is_dev`/`jit.version` on the run host |
| S14 | per-voxel provenance | **ABSENT** | mapgen | the only voxel flags are `VOXELFLAG_NO_DATA` and `CHECKED1..4` (`reference_projects/luanti/src/voxel.h:349-353`), and `CHECKED*` are lighting/liquid scratch bits. `LuaVoxelManip` exposes 18 methods (`l_vmanip.cpp:499-518`) and **no flags accessor of any kind**. `get_data` collapses `NO_DATA` to `CONTENT_IGNORE` (`:109`), making them indistinguishable. In a **mapgen** VM `NO_DATA` is never set at all: `initBlockMake` pre-creates every block in the full area (`servermap.cpp:229-244`) before `initialEmerge` (`:254`), and `initialEmerge` only sets `NO_DATA` where `getBlockNoCreateNoEx` returns null (`map.cpp:804-816`), which can no longer happen; a never-generated shell block is a fresh MapBlock of `CONTENT_IGNORE` (`reference_projects/luanti/src/mapblock.cpp:110`). `block->isGenerated()` is not bound to Lua (`grep -rn "isGenerated\|is_generated" reference_projects/luanti/src/script/` is empty) | **nothing — this cannot be measured because it does not exist.** It is the reason halo/border provenance must be established by controlling generation order (section 10.6) rather than by an in-callback signal, and the reason the CORE region excludes the outer MapBlock (section 10.5) |

### 7.2 The mapgen VoxelManip surface, in full

All citations `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp`.

| Method | Lines | Contract that matters here |
| --- | --- | --- |
| `get_data([buf])` | `:92-114` | 1-indexed flat array over the **entire emerged area**; `NO_DATA` collapses to `CONTENT_IGNORE` at `:109`; optional reuse buffer at `:99` |
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
| `write_to_map` | `:147-157` | **forbidden, hard `LuaError` in the mapgen env** (`:155-156`) |
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

**Settled by pinned source — the probe re-confirms at most, and never
re-litigates:** S1 availability and state; S2 signature, argument meaning and
call order; S3a/S3b/S4 availability of IPC in both states; S4b/S4c
prohibitions; S5 method set and its four hard prohibitions; S6 emerged geometry
and the absence of a write guard; S7 the absence of a "lighting handled" flag
and the difference between the Lua and mgv7 default regions; S8 that mgv7
already ran a full-area liquid update; S9 the API set and the absence of
`get_gametime`/`get_timeofday`/`get_server_uptime`; S10 the absence of any
engine memory counter; S11 the absence of the insecure environment; S12 the
border-seeding and blit-back mechanism; S14 the total absence of per-voxel
provenance.

**Deliberately left for runtime measurement — nothing below is asserted
anywhere in this contract:** every wall time and every heap number; S3b's
practical latency and whether a poll is required; S3c's delivery of a custom
gennotify record end to end; S4e's ValueNoise-at-load-time ambiguity; the
magnitude and exact extent of S12's order effect in CORE and SEAM; whether
`A1 − A0` is empty; whether `B − A1` is byte-identical across O1 and O2;
whether the whole run fits inside the in-run deadlines; whether process RSS
is obtainable at all through `secure.trusted_mods` on the run host; and the
realized value of every setting in section 5's `engine` class.

---

## 8. Implementation boundary and file ownership

### 8.1 Every file the follow-on package may create

**The package boundary, defined once.** This is the single definition; sections
17 and 18 reference it rather than restating it, and the three statements must
never drift apart. The follow-on package may create or modify a file **only** if
its path matches one of these four patterns, and nothing else:

```
tools/wp40/t5_probe/**                       # the probe tree (this section)
tools/wp40/evidence/t5-probe-*/**            # reviewed evidence (section 13.6)
.gitattributes                               # one appended line (section 13.6)
docs/research/wp40-t5-0-engine-probe-contract.md   # this contract only
```

The `docs/` entry is exhaustive and deliberately names one file. In particular
the package may **not** touch
`docs/research/wp40-engineering-brief.md`,
`docs/research/wp40-t2-contracts.md`,
`docs/research/wp40-t2-plan.md`,
`docs/design/world_zones.md`,
`docs/design/world.md`,
`docs/process/wp-workflow.md`,
`docs/research/luanti-lua.md`,
`AGENTS.md` or `ROADMAP.md` — the first three are the authorities section 1.1
declares binding, and a boundary check phrased as "…and `docs/`" would let the
package silently edit the very documents it is measured against.

All probe code is under `tools/wp40/t5_probe/`.

| Path | Purpose | Owner |
| --- | --- | --- |
| `tools/wp40/t5_probe/README.md` | package contract link, non-claims, how to re-run, evidence layout | this package |
| `tools/wp40/t5_probe/run_t5_probe.sh` | runner: preflight, static gates, self-tests, six engine captures, evidence assembly | this package |
| `tools/wp40/t5_probe/verify_log.sh` | fail-closed three-stage JSON gate (section 12.5) | this package |
| `tools/wp40/t5_probe/verify_log_test.sh` | negative fixtures for `verify_log.sh` (section 16) | this package |
| `tools/wp40/t5_probe/compare_runs.sh` | cross-run digest comparison; the `A1−A0` / `B−A1` / `O1↔O2` verdicts `V-01`…`V-09`; section 10.13's four-predicate truth table; the `first_diff` and `verdict` records | this package |
| `tools/wp40/t5_probe/compare_runs_test.sh` | negative fixtures for `compare_runs.sh` | this package |
| `tools/wp40/t5_probe/digest_audit.sh` | fixture proving the manifest digest, in the shape of `tools/wp40/dungeon_probe/digest_audit.sh:17-43` | this package |
| `tools/wp40/t5_probe/coordinate_audit.lua` | recomputes the 122-column structure envelope and the Ocean Mask derivation of section 6.2 from repository source, and asserts the six measured columns are excluded | this package |
| `tools/wp40/t5_probe/driver/mod.conf` | driver mod manifest; `depends = grug_mapgen` so the payload registers **after** `ocean_mask_mapgen.lua` | this package |
| `tools/wp40/t5_probe/driver/init.lua` | main-state driver: arm switch, IPC publish, gennotify registration, emerge scheduling, main-env `on_generated` telemetry, readback, digests, deadline, shutdown | this package |
| `tools/wp40/t5_probe/driver/readback.lua` | main-state bounded readback + lane digests | this package |
| `tools/wp40/t5_probe/payload/mapgen.lua` | the registered mapgen script: load-time telemetry, the case dispatcher, the counted VM proxy | this package |
| `tools/wp40/t5_probe/payload/cases.lua` | the four micro-cases as pure box arithmetic | this package |
| `tools/wp40/t5_probe/payload/vm_proxy.lua` | the counting/timing wrapper; **the only file permitted to touch the raw VoxelManip object** | this package |
| `tools/wp40/t5_probe/probe_tree_manifest.sh` | emits the per-file `path` + `sha256` manifest of section 20.2 into the evidence tree, so disposal is checkable by content | this package |
| `tools/wp40/t5_probe/digest_lib.sh` | thin re-use wrapper; canonicalization rules follow `tools/wp40/dungeon_probe/digest_lib.sh:27-34` and `:50-56` | this package |

That is sixteen files. The follow-on package creates **no** production file, **no** file under
`mods/`, **no** production registration, and **no** second reusable adapter.
The driver mod is loaded only because the generated disposable world's
`minetest.conf` names it; nothing in the committed game tree references it.

### 8.2 Rules the implementation inherits and may not renegotiate

- `#!/usr/bin/env bash` + `set -euo pipefail`; paths derived from `BASH_SOURCE`,
  never hardcoded; runners `bash -n` themselves and their siblings; a single
  `WP40 t5-probe …` success line, failures to stderr
  (`tools/wp40/run_dungeon_probe.sh`).
- Exit codes: `0` pass, `2` preflight failure or refusal to overwrite an
  immutable result, `124` outer timeout — always fails the capture — are the
  three the repository already fixes (`tools/wp40/README.md:1113-1117`). This
  package additionally uses `1` for a failed gate and `127` for a missing tool,
  matching the sibling runners' behaviour; both are stated here because
  `tools/wp40/README.md` does not fix them.
- `rg` preflight is mandatory and non-negotiable (`tools/wp40/run_t1.sh:4-9`;
  `AGENTS.md:133-136` — until 2026-08-15 a missing `rg` made nine gates report
  success without running). `jq` is hard-required up front
  (`tools/wp40/run_dungeon_probe.sh:15-18`).
- Self-tests and static gates run **before** the expensive half
  (`tools/wp40/run_dungeon_probe.sh:20-27`); the expensive half is opt-in and
  skip-not-fail (`:29-32`).
- Static gates on every probe Lua file: `tools/bin/luac51 -p <file>`;
  `tools/bin/luac51 -l -p <file> | grep SETGLOBAL` → **zero** lines for a
  tools-only file and **at most one** — the mod table only — for a mod
  `init.lua` (`docs/research/luanti-lua.md:260-261` permits a single mod-table
  global; it does not require one, and `tools/wp40/dungeon_probe/init.lua` has
  zero); and the
  five grep sweeps of `docs/research/luanti-lua.md:310-321` run **explicitly**
  against `tools/`, because `AGENTS.md:130-133` scopes the documented sweeps to
  `mods/*/grug_*` and they do not cover `tools/`. In-tree implementations to
  copy: `tools/wp40/t2_source_audit.sh:363-393`,
  `tools/wp40/run_t2_partition_c2_selected.sh:43-55`.
- The twelve do-not-write rules of `docs/research/luanti-lua.md:240-266` apply
  in full: `core.*` never `minetest.*` (`:266`); `unpack` not `table.unpack`;
  `math.floor(a/b)` not `//`; no `\x`, `\u{}` or `\z` escapes;
  `string.char(124)` instead of a literal pipe so sweep 4 stays clean.
- Interpreter selection `WP40_LUA_BIN` defaulting to LuaJIT
  (`tools/wp40/run_t2_s1_authority.sh:38-45`); the offline self-tests run under
  a dual-interpreter byte gate comparing stdout **and** exit status
  (`tools/wp40/run_t2_s11_acceptance.sh:22-44`).
- A T5-0 engine-seam probe is a **layer-6** activity
  (`docs/research/luanti-lua.md:346-371`), and a real fallback-engine run is a
  separate gate never inferred from offline equality
  (`docs/process/wp-workflow.md:78-79`).
- `tools/sync_to_luanti.sh` is never called
  (`docs/process/wp-workflow.md:42-45`; `tools/wp40/README.md:1105-1109`;
  `tools/wp40/dungeon_probe/README.md:62-63`).
- Scratch directories use `mktemp -d /tmp/grudgelands-wp40-t5-probe.XXXXXX`
  with a matching `case`/`esac` prefix guard and
  `trap cleanup EXIT INT TERM` (`tools/wp40/run_dungeon_probe.sh:39-46`); the
  slug is distinct from every existing script's slug.
- Results are immutable: refuse to overwrite an existing result directory and
  exit 2 (`tools/wp40/capture_t0_baseline.sh:81-83`).
  `tools/wp40/results/` is ignored (`.gitignore:11`); reviewed evidence is
  committed by overriding `WP40_RESULTS_ROOT`
  (`tools/wp40/capture_t0_baseline.sh:18-21`, `tools/wp40/README.md:1109-1111`).
- Raw evidence is whitespace-protected by extending `.gitattributes`
  (`.gitattributes:1` is the existing precedent; rationale
  `tools/wp40/dungeon_probe/README.md:48-51`, reviewer instruction
  `tools/wp40/README.md:393-404`).
- **Do not copy `--terminal`** (`tools/wp40/run_dungeon_probe.sh:117`) — it logs
  an ncurses error in every capture.

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
must not import or reproduce it. The reviewer check is in section 18, item 12.

---

## 9. Synthetic payload definition

### 9.1 Schema tag

```
grug_wp40_t5_probe_synthetic_v0
```

The tag appears as the first canonicalized line of the payload digest
(`schema=grug_wp40_t5_probe_synthetic_v0`, in the shape of
`tools/wp40/dungeon_probe/digest_lib.sh:27-28`) and as the `schema` field of
every JSON record (section 12.1). The trailing `v0` is deliberate: it announces
that nothing here is a version-1 anything.

### 9.2 What the payload contains

Exactly four things, and nothing else:

1. **six literal box tuples** — the write extents of section 10, expressed as
   `{minx, miny, minz, maxx, maxy, maxz}` integer sextuples with no name, no
   type, no priority and no owner field;
2. **five literal registered node names** — `"air"`, `"default:stone"`
   (`mods/BASE/default/nodes.lua:259`), `"default:water_source"`
   (`mods/BASE/default/nodes.lua:2204`), `"default:goldblock"`
   (`mods/BASE/default/nodes.lua:1298-1302`, opaque, no light source, no
   `paramtype2`) and `"stairs:stair_cobble"` (registered from
   `mods/BASE/stairs/init.lua:525-535`, `paramtype2 = "facedir"` at `:99`),
   resolved once per mapgen state through `core.get_content_id`;
3. **one integer `param2` constant** (`1`), written into the facedir box;
4. **a case dispatcher** keyed on `minp.x` alone.

### 9.3 What the payload deliberately avoids, and why

The payload borrows **no** record name, field name, operation-type name,
conflict rule, priority ordering, resolver identifier, zone identifier,
feature identifier, envelope name, or vocabulary token from T2, T3, T4, T6 or
T7. Specifically:

- it contains none of the T2 dataset record kinds enumerated at
  `wp40-engineering-brief.md:2249-2257`, and by construction none of the things
  the payload may never contain at `:2259-2261`;
- it uses no `grug_zones` name, because T3 owns that API
  (`wp40-engineering-brief.md:4089`, `:2423-2470`);
- it uses no typed operation name, no resolver-pair name, no veto class and no
  replaceable-set name, because T4 owns the closed matrix
  (`wp40-engineering-brief.md:4090`, `:2109-2113`);
- it uses no logical-biome ID, no top/filler role, no decoration candidate
  identifier and no vein catalog name, because T6/T7 own them (`:4092-4093`).

The reason is not stylistic. A synthetic payload that reuses the production
vocabulary invites the next reader to treat its shape as a precedent, and this
probe's whole value depends on nobody being able to claim later that T5-0
"already decided" a field name. `default:water_source` is used only as a
**registered node name** that exists in this world; that reuse is not an
adoption of the single decided surface-water identity of
`wp40-engineering-brief.md:1354-1355`, and the probe makes no hydrology claim.

### 9.4 The payload registers zero nodes

The driver and payload call `core.register_node` zero times, so the content-ID
assignment of the world is identical in all three arms. This is what makes
D2's "asserted-identical id→name table" sound; see section 10.8.

---

## 10. Test matrix — the four micro-cases

### 10.1 Three arms

| Arm | Driver | Mapgen script | Purpose |
| --- | --- | --- | --- |
| `A0` | yes | **not registered** | substrate control — the world the game produces on its own |
| `A1` | yes | registered; callback performs **zero VoxelManip calls** and zero writes (pure observation and telemetry) | null-payload control — isolates "a mapgen script exists and a callback ran" from "the payload wrote" |
| `B` | yes | registered; the four-case payload | treatment |

`B − A1` is the payload delta. **`A1 − A0` must be empty.** A non-empty
`A1 − A0` proves that merely loading a mapgen script and registering a callback
changes generated bytes, which is a first-class result, not a probe bug, and is
reported as such (section 15 distinguishes it from an abort).

### 10.2 One mod set, one archive, one switch

There is exactly **one** driver mod and **one** payload file in all six runs.

**How the driver mod is loaded.** It is copied into the archived **game** tree,
under `<archive>/mods/`, exactly as both in-tree precedents do
(`tools/wp40/run_dungeon_probe.sh:63-65`,
`tools/wp40/capture_t0_baseline.sh:105-108`), where game mods load
unconditionally without any `minetest.conf` entry. The generated
`minetest.conf` names the mod only in `secure.trusted_mods`, for the
best-effort process-metric read of section 12.4 — it is **not** the loading
mechanism, and nothing in the committed game tree references the mod.

The arm is selected by a single generated configuration key read by the driver
at load time:

```
grug_wp40_t5_probe.arm = A0 | A1 | B
```

The driver calls `core.register_mapgen_script` if and only if the arm is `A1`
or `B`; the payload reads the same key over IPC and selects null or four-case
behaviour. Consequences that make the attribution sound:

- the mod set, the dependency graph and therefore the mod load order are
  byte-identical in every arm;
- the injected-payload digest is identical in every run, so one digest covers
  the whole run set;
- the only per-run configuration difference is two keys (`arm`, `order`) plus
  the per-run `port`.

### 10.3 Regions

| Region | Definition | Size | Why |
| --- | --- | --- | --- |
| **CORE** | each measured chunk's central slice shrunk by one MapBlock (16 nodes) on every side: `x ∈ [-16+80k_x, 31+80k_x]`, `y ∈ [-16, 31]`, `z ∈ [704, 751]` | 48³ = 110,592 nodes per chunk | immune to a later neighbour's shell rewrite: a neighbour's emerged area reaches exactly 16 nodes in (`reference_projects/luanti/src/servermap.h:175`), and `blitBackAll` writes that border back with `overwrite_generated = true` (`servermap.cpp:291`, `map.h:334-335`). Native dungeons also write the **full emerged** range (`reference_projects/luanti/src/mapgen/mapgen.cpp:952`), which is a second reason the outer MapBlock is excluded |
| **SEAM** | the named box `(824, -16, 696) … (871, 23, 735)` | 48 × 40 × 40 = 76,800 nodes | straddles the `x = 847 \| 848` chunk boundary by 24 nodes on each side and contains the full 15-node light expansion of both Case-4 halves. Compared arm-to-arm **within** an order, and across orders only against its paired control |

Cases 1a, 1b, 2 and 3 write only inside CORE. Case 4 writes only inside SEAM,
deliberately.

### 10.4 Comparison lanes

Following `wp40-engineering-brief.md:3004-3011` — "Database bytes, compression
order, timestamps, and block serialization layout are not compared" (`:3004-3005`)
— the probe compares **decoded node lanes**, not database bytes:

| Lane | Bytes per node | Derivation |
| --- | --- | --- |
| `content` | 2, big-endian | `get_data` value |
| `param2` | 1 | `get_param2_data` value |
| `light_day` | 1 | `param1 % 16` |
| `light_night` | 1 | `math.floor(param1 / 16)` |

The brief hashes "content IDs mapped back to canonical registered node names"
(`:3009`). The probe instead hashes the raw content IDs **and** separately
asserts that the id→name table is byte-identical across every arm and order of
the run set (section 10.8). Given that assertion, the two are equivalent: a
bijection applied identically to both sides of an equality test cannot change
the test's outcome. The probe takes this route because emitting a node name per
node would multiply the compared payload by roughly an order of magnitude —
740,352 compared nodes per run, against a 2-byte integer per node — for no
additional discriminating power. The equality assertion is a hard gate, not an
assumption: if it fails, the run aborts (`A-04`) and no lane comparison is
reported.

The probe registers **zero** nodes precisely so that this assertion can hold
(section 9.4).

**Canonical form of `content_id_table_sha256`.** Because this one digest is the
sole justification for hashing raw content IDs, its input is defined exactly and
not left to the implementer. It is built in the labelled `key=value` shape of
`tools/wp40/dungeon_probe/digest_lib.sh:27-34`:

```
schema=wp40-t5-probe-content-id-table-v1
name=<registered node name>
id=<numeric content id from core.get_content_id(name)>
name=<next registered node name>
id=<...>
...
```

with entries **sorted ascending by node name** and the resulting text hashed
with `core.sha256`. Two rules are load-bearing and are reviewer items:

- **the id must be bound, not only the name.** A digest over a sorted name list
  alone satisfies `X-01` while leaving a *permuted id assignment* undetected —
  which would make `CORE(A1) != CORE(A0)` in the content lane and be reported
  as `V-01`, a fabricated engine finding that passes every other gate;
- **the order must be an explicit sort, never `pairs()`.** `pairs()` over
  `core.registered_nodes` is unspecified in iteration order, so a `pairs()`-built
  table produces a different digest on every run and aborts all six of them
  (`A-04`). The implementer collects names into an array, `table.sort`s it, and
  emits in that order.

### 10.5 Case-to-chunk assignment

| Chunk | Case | Purpose |
| --- | --- | --- |
| `k_x = 6` | **1a — total no-op** | zero VoxelManip calls of any kind in the probe callback. Establishes the floor cost of "a mapgen callback ran and returned" |
| `k_x = 7` | **1b — observe-only no-op** | exactly one `get_data`, zero writes, zero lighting, zero liquid. `1a` vs `1b` isolates the cost of one `get_data` over 1,404,928 nodes, which S5 and S10 make the single largest suspected cost |
| `k_x = 8` | **2 — bounded cut/fill cell** | one content transaction, bounded lighting, no `param2` |
| `k_x = 9` | **3 — water cell** | liquid and lighting completion, plus a **separate** non-empty `param2` dirty set so `set_param2_data` is exercised independently of `set_data` (`wp40-engineering-brief.md:2170-2172`, `:2181-2183`) |
| `k_x = 10`, `k_x = 11` | **4 — chunk-boundary feature** | one feature crossing `x = 847 \| 848`, each chunk writing only its own central-slice half (`wp40-engineering-brief.md:1088-1090`), generated in both orders |

### 10.6 Orders

- **O1** = ascending `k_x`: 6, 7, 8, 9, 10, 11.
- **O2** = descending `k_x`: 11, 10, 9, 8, 7, 6.

Both are serialized one chunk at a time: `core.emerge_area(pos, pos, cb)` at the
chunk centre, completion is `calls_remaining == 0`, chained with
`core.after(0, emerge_next)` — the pattern of
`tools/wp40/dungeon_probe/init.lua:9`, `:29`, `:36-37`. Kick-off is
`core.register_on_mods_loaded` plus one `core.after(0, …)`
(`tools/wp40/dungeon_probe/init.lua:42`, `:75`), never a globalstep.
Termination is `core.request_shutdown(msg, false, 0.1)`; the 0.1-second delay is
the `tools/wp40/runtime_probe/init.lua:179` pattern and exists so appended log
writes flush.

Runs = 3 arms × 2 orders = **6**. Generated mapchunks = **36**.

### 10.7 The full matrix

| Run | Arm | Order | World | Port |
| --- | --- | --- | --- | --- |
| 1 | `A0` | `O1` | fresh disposable | 32001 |
| 2 | `A0` | `O2` | fresh disposable | 32002 |
| 3 | `A1` | `O1` | fresh disposable | 32003 |
| 4 | `A1` | `O2` | fresh disposable | 32004 |
| 5 | `B` | `O1` | fresh disposable | 32005 |
| 6 | `B` | `O2` | fresh disposable | 32006 |

Every run gets its own fresh disposable world; no world is reused between arms
or orders. Freshness is **by construction only** — the world directory is
created inside a fresh `mktemp -d` — and nothing asserts that `map.sqlite` was
absent. That limitation is recorded verbatim in the evidence, together with the
honest cache disclaimer of `tools/wp40/capture_t0_baseline.sh:239-241`
(`filesystem_page_cache: "unknown_uncontrolled"`, `cold_cache_claim: false`).

### 10.8 Cross-run assertions that must hold before any comparison is reported

| ID | Assertion | Failure |
| --- | --- | --- |
| `X-01` | `content_id_table_sha256` identical across all six runs | abort `A-04` |
| `X-02` | realized mapgen-settings digest identical across all six runs | abort `A-06` |
| `X-03` | realized emerge order identical within an order across arms | abort `A-07` |
| `X-04` | injected payload digest identical across all six runs | abort `A-02` |
| `X-05` | engine identity (`version.string`, `version.hash`, `lua_runtime`) identical across all six runs | abort `A-03` |
| `X-06` | for every chunk that legitimately obtains them — cases 2, 3, 4lo, 4hi in arm `B` — `emin`/`emax` equal `minp − 16` / `maxp + 16`. Cases 1a/1b and every arm-`A1` callback report `null` by contract (section 12.3) and are **skipped**, not asserted; S6's runtime confirmation is therefore scoped to the four chunks that call `get_emerged_area` | abort `A-08` |

### 10.9 Verdicts

| ID | Comparison | Expected | If it does not hold |
| --- | --- | --- | --- |
| `V-01` | `CORE(A1, O) == CORE(A0, O)` for all six chunks, all four lanes, `O ∈ {O1, O2}` | equal | **result, not abort**: "loading a mapgen script and registering a zero-call callback changes generated bytes." Reported prominently; all downstream `B − A1` verdicts are then qualified as "measured against a control that is itself not neutral" |
| `V-02a` | **content and `param2` lanes:** `CORE(B, O) == CORE(A1, O)` over **CORE minus the case write extent** | equal | correctness failure of the payload — it wrote content or `param2` outside its declared extent. Gate fails. This is the real out-of-extent-write detector and it is evaluated on **both** lanes; narrowing it to the content lane alone silently loses `param2` containment (reviewer item 6 checks that the narrowing is not made) |
| `V-02b` | **light lanes:** `CORE(B, O) == CORE(A1, O)` over **CORE minus the light-dirty box** | equal | light spread outside the declared light-dirty box. Gate fails. The residual set is smaller than `V-02a`'s by construction, because `calc_lighting` relights a designed region: 54,276 CORE voxels remain for case 2, 42,724 for case 3, and 102,346 for each case-4 chunk (section 10.10 gives the boxes). For case 4 the light-dirty box is **not contained in CORE** — it straddles the CORE/SEAM boundary — so this residual certifies only the CORE-interior part and carries **no** containment evidence for the halo portion, which `V-08` reports separately. That limitation is stated, never asserted away |
| `V-03` | `digest_incl(B, O)` differs from `digest_incl(A1, O)` on the content lane over each written case's write extent (cases 2, 3, 4); and on the `param2` lane over case 3's facedir sub-box while being equal over case 3's water sub-box | different where the realized dirty set is non-empty | if equal where the realized dirty count is non-zero, the payload's writes did not survive the blit — a first-class engine result, not a gate failure |
| `V-04` | `CORE(B, O1) == CORE(B, O2)` per chunk, per lane | equal | order dependence inside CORE — a first-class engine result, reported against `V-06` |
| `V-05` | **content and `param2` lanes only:** the difference-of-differences truth table of section 10.13, evaluated over SEAM | a licensed conclusion, not necessarily "equal" | **the load-bearing result.** A predicate combination that licenses no conclusion is recorded as `inconclusive` and is never read as a pass. Light lanes are excluded here and handled by `V-08`; see `F`-note in section 10.13 for why |
| `V-06` | `SEAM(A1, O1) == SEAM(A1, O2)`, per lane | unknown, measured | any residual difference is reported **separately** as native engine order dependence, localized by a `first_diff` record, and is what `V-05` must be read against |
| `V-07` | operation counts equal the exact per-case table of section 10.11, conditioned on the arm | equal | gate fails |
| `V-08` | **light lanes over SEAM**, reported separately: `SEAM(B, O1) == SEAM(B, O2)` and `SEAM(B, Oi) == SEAM(A1, Oi)` on `light_day` and `light_night` | unknown, measured | reported as a test of the brief's halo-light idempotence exception (`wp40-engineering-brief.md:1471-1474`), **never** as evidence about the seam. Arm `A1` performs zero lighting calls, so a light-lane `B − A1` is not a payload delta at all — it is a different computation per arm over overlapping, order-dependent inputs |
| `V-09` | **quiescence proof:** the two readback digest sets of section 10.15, taken at least 2 s apart, are identical in every run | equal, **trivially**, because `liquid_update = 86400` suppresses the background drain for the whole run (section 5) | **no verdict of any kind is reported** — abort `A-13`. After the pin, a difference no longer means "liquid is still settling"; it means the drain ran anyway, or something else in the world moved between the two passes. Either is a fault in the run rather than a property of the seam |

### 10.10 Case definitions

All boxes are inclusive integer ranges. All are inside the relevant chunk's
CORE (cases 1a–3) or SEAM (case 4). "Write extent" is the fixed set of voxels
the payload assigns; "realized dirty set" is the subset whose value actually
changes, which depends on the native baseline and is therefore **measured, not
asserted**.

#### Case 1a — total no-op (`k_x = 6`)

- **Purpose:** the floor. Establish the cost of a mapgen callback that returns
  immediately, and confirm that a chunk with a registered callback and zero VM
  calls is byte-identical to the same chunk with no script at all.
- **Coordinates:** none. The callback reads `minp.x`, dispatches, and returns.
- **Baseline / expected delta:** `CORE(B) == CORE(A1) == CORE(A0)`, all four
  lanes, both orders. Expected treatment delta: **empty**.
- **Dirty sets:** content 0, `param2` 0, light 0, liquid 0.
- **Permitted VoxelManip calls:** **none**, of any name, maximum 0 each.
- **Captured:** callback wall time (`core.get_us_time()` at entry and exit),
  `collectgarbage("count")` before and after, the four CORE lane digests.
- **Pass/fail:** operation counters all zero **and** `CORE(B) == CORE(A1)` for
  all four lanes in both orders.
- **Negative mutation:** insert a single `vm:get_emerged_area()` call. The gate
  must fail with `case 1a performed a VoxelManip call`, driven by the proxy
  counter, not by inspection of the source.

#### Case 1b — observe-only no-op (`k_x = 7`)

- **Purpose:** isolate the cost of one full-volume `get_data` (1,404,928
  entries) with no write, no lighting and no liquid, and confirm that reading
  alone changes nothing.
- **Coordinates:** whole emerged area, implicitly.
- **Baseline / expected delta:** `CORE(B) == CORE(A1)`, all lanes. Expected
  treatment delta: **empty bytes, non-zero time**.
- **Dirty sets:** content 0, `param2` 0, light 0, liquid 0.
- **Permitted VoxelManip calls:** `get_data` exactly 1 (into a payload-owned
  reuse buffer, `l_vmanip.cpp:99`); every other method exactly 0.
- **Captured:** callback wall time split into `before_get_data`, `get_data`,
  `after`; `collectgarbage("count")` before and after; the four CORE lane
  digests.
- **Pass/fail:** `get_data == 1`, all other counters 0, `CORE(B) == CORE(A1)`.
- **Negative mutation:** call `get_data` twice. The gate must fail with
  `case 1b get_data count is not 1`.

#### Case 2 — bounded cut/fill surface cell (`k_x = 8`)

- **Purpose:** one content transaction with a bounded, non-empty content dirty
  set and an empty `param2` dirty set, plus the full bounded-lighting sequence.
- **Coordinates:**
  - cut box `(640, 0, 720) … (647, 7, 727)` → `air`, 512 voxels;
  - fill box `(640, -8, 720) … (647, -1, 727)` → `default:stone`, 512 voxels.
  - Both are strictly inside CORE for `k_x = 8` (`x ∈ [624, 671]`,
    `y ∈ [-16, 31]`, `z ∈ [704, 751]`).
- **Write extent:** 1024 voxels. **Realized content dirty set:** measured,
  `0 ≤ d ≤ 1024`; the payload counts voxels whose content ID actually changes
  and emits the count.
- **`param2` dirty set:** **empty by construction** — this case never calls
  `get_param2_data` or `set_param2_data`. This is what makes Case 3's separate
  `param2` set meaningful.
- **Light-dirty box:** write extent expanded by 15 on each axis and clipped at
  the emerged boundary (`wp40-engineering-brief.md:1428-1430`) =
  `(625, -23, 705) … (662, 22, 742)`, 38 × 46 × 38 = **66,424** voxels. No
  clipping occurs for this chunk (emerged x `[592, 703]`, y `[-48, 63]`,
  z `[672, 783]`), but the clip is applied as a formula so the code is correct
  for a chunk where it would.
- **Liquid dirty predicate:** `∃ voxel in the realized content dirty set whose
  old **or** new content ID is a registered liquid` (evaluated from
  `core.registered_nodes[...].liquidtype`, resolved once at mapgen-state load
  time). Cutting a column that happens to contain native water makes this true;
  cutting dry stone makes it false. **The count is therefore conditional and is
  not asserted here** — the payload emits both the predicate and the count, and
  the gate asserts `update_liquids == 1` if and only if the predicate is true.
- **Permitted VoxelManip calls, exact maxima:**

  | Method | Max | Condition |
  | --- | --- | --- |
  | `get_emerged_area` | 1 | always |
  | `get_data` | 1 | always |
  | `set_data` | 1 | if and only if realized content dirty set is non-empty (`wp40-engineering-brief.md:2168-2170`, `:2182-2183`) |
  | `get_param2_data` | 0 | — |
  | `set_param2_data` | 0 | — |
  | `get_light_data` | 2 | one `param1` snapshot before the content commit (`:1435`), one read of the calculated buffer after `calc_lighting` (`:1451`) |
  | `set_lighting` | 1 | the single canonical light-dirty box, zeroing both banks (`:1439-1441`) |
  | `calc_lighting` | 1 | `propagate_shadow = true`, region `(emin.x, minp.y, emin.z) … (emax.x, maxp.y, emax.z)` = `(592, -32, 672) … (703, 47, 783)` (`:1446-1448`) |
  | `set_light_data` | 1 | one final full-buffer upload (`:1451-1453`) |
  | `update_liquids` | 1 | if and only if the liquid dirty predicate is true (`:1395-1398`) |
  | every other method | 0 | — |

- **Deliberate non-implementation:** the probe does **not** perform the brief's
  step 2 — bounded `set_lighting` day-15/night-0 stamping on analytically
  sky-open final-air boxes, which "never stamps water or an inferred cave
  opening" (`wp40-engineering-brief.md:1442-1445`) — because it has no analytic
  geometry to prove sky-openness with. Consequently the probe's resulting light
  values are **not** the production light values and the probe makes no
  lighting-correctness claim. It measures the call shape, the cost, and the
  order-stability of whatever the engine produces.
- **Captured:** per-call wall time from the proxy; realized dirty counts;
  `collectgarbage("count")` before/after; the four CORE lane digests; the
  digest of `CORE minus the write extent`.
- **Pass/fail:** exact operation counts as tabulated; `CORE(B) == CORE(A1)`
  over `CORE minus the write extent`; `CORE(B) != CORE(A1)` inside the write
  extent whenever the realized dirty set is non-empty;
  `CORE(B, O1) == CORE(B, O2)`.
- **Negative mutations:** (i) widen the cut box by one node in `+x` — the
  `CORE minus write extent` digest must change and the gate must fail with
  `payload wrote outside its declared extent`; (ii) call `set_data` twice — the
  gate must fail with `case 2 set_data count is not 1`; (iii) force
  `update_liquids` when the predicate is false — the gate must fail with
  `update_liquids called with an empty liquid dirty set`.

#### Case 3 — water cell with a separate `param2` dirty set (`k_x = 9`)

- **Purpose:** exercise liquid and lighting completion, and prove
  `set_param2_data` is a distinct, separately gated upload — "'One content
  commit' means at most one `set_data()` upload; it does not conflate the
  engine's distinct content and `param2` arrays" (`wp40-engineering-brief.md:2181-2183`).
- **Coordinates:**
  - water box `(712, 0, 720) … (719, 7, 727)` → `default:water_source`, 512
    voxels;
  - facedir box `(728, 0, 720) … (735, 7, 727)` → `stairs:stair_cobble` with
    `param2 = 1`, 512 voxels.
  - Both strictly inside CORE for `k_x = 9` (`x ∈ [704, 751]`).
- **Write extent:** content 1024 voxels; `param2` 512 voxels.
- **Dirty sets:** realized content dirty set measured, `0 ≤ d ≤ 1024`; realized
  `param2` dirty set measured, `0 ≤ p ≤ 512`. The two sets are **different sets
  with different sizes**, which is the point of the case.
- **Light-dirty box:** union of the two boxes `(712, 0, 720) … (735, 7, 727)`
  expanded by 15 and clipped = `(697, -15, 705) … (750, 22, 742)`,
  54 × 38 × 38 = **77,976** voxels. Emerged x for `k_x = 9` is `[672, 783]`, so
  again no clipping occurs.
- **Liquid dirty predicate:** as Case 2. Writing `default:water_source` makes
  it true unless every target voxel already held that exact content ID; the
  payload emits the predicate and the gate asserts `update_liquids == 1` if and
  only if it is true. The count is conditional and is not asserted here.
- **Permitted VoxelManip calls, exact maxima:** as Case 2, plus
  `get_param2_data` max 1 and `set_param2_data` max 1 (the latter if and only if
  the realized `param2` dirty set is non-empty). `calc_lighting` region
  `(672, -32, 672) … (783, 47, 783)`.
- **Captured:** as Case 2, plus the `param2` lane digest over the facedir box
  and the separate realized `param2` dirty count.
- **Pass/fail:** exact operation counts; `set_param2_data == 1` with
  `set_data == 1` and the two dirty counts differing; the `param2` lane inside
  the facedir box differs from `A1` while the `param2` lane inside the water box
  does not; `CORE(B, O1) == CORE(B, O2)`.
- **Negative mutations:** (i) merge the two boxes so the `param2` set equals the
  content set — the gate must fail with
  `param2 dirty set is not separate from the content dirty set`; (ii) write
  `param2` without `set_param2_data` (i.e. fold it into `set_data`) — the gate
  must fail with `case 3 set_param2_data count is not 1`; (iii) suppress
  `update_liquids` while the predicate is true — the gate must fail with
  `liquid dirty set is nonempty but update_liquids was not called`.

#### Case 4 — one feature crossing a chunk boundary (`k_x = 10` and `k_x = 11`)

- **Purpose:** the load-bearing case. Test whether a central-slice write
  survives a later neighbour's generation, in both orders.
- **The feature:** one solid `default:goldblock` bar, cross-section 8 × 8 in y
  and z, spanning `x ∈ [840, 855]` globally. The node is chosen for the
  five-minute user test of section 19, not for aesthetics: at these coordinates
  `y ∈ [0, 7]` and 572 nodes inland the native column is overwhelmingly likely
  to be solid stone, and a `default:stone` bar inside stone is invisible — as is
  a *missing* half of one, which is precisely the observation section 19 calls
  load-bearing. `default:goldblock`
  (`mods/BASE/default/nodes.lua:1298-1302`) is opaque, is not a light source,
  and has no `paramtype2`, so it changes nothing about the case's light
  relevance, its liquid predicate or its empty `param2` dirty set — only its
  visibility:
  - `k_x = 10` writes `(840, 0, 712) … (847, 7, 719)` — 512 voxels, the last 8
    x-nodes of its own central slice;
  - `k_x = 11` writes `(848, 0, 712) … (855, 7, 719)` — 512 voxels, the first 8
    x-nodes of its own central slice.
  - Neither chunk writes a single voxel of **content or `param2`** outside its
    own central slice. This is the brief's central-owner-slice rule made
    concrete: "Each callback writes only the central owner chunk's intersection
    with the global shell, so crossing a vertical or horizontal chunk edge
    neither widens the shell nor gives the first-requested chunk ownership of
    its neighbor's nodes." (`wp40-engineering-brief.md:1088-1090`)
  - **Light is different and the claim does not extend to it.** The mandated
    `calc_lighting` region below reaches into the neighbour's central slice, and
    `spreadLight` covers the whole emerged area regardless of the region
    argument (`reference_projects/luanti/src/mapgen/mapgen.cpp:466-472`), after
    which `blitBackAll(overwrite_generated = true)` writes it back
    (`reference_projects/luanti/src/servermap.cpp:291`). Halo light writes are
    the brief's **sole** derived-state exception to central content ownership —
    they "may not alter content or `param2`, and the resulting values must be
    idempotent when a neighboring owner chunk is later generated"
    (`wp40-engineering-brief.md:1471-1474`) — and this probe tests that
    idempotence separately under `V-08` rather than folding it into the seam
    verdict (section 10.13)
- **Write extent:** 512 voxels per chunk, 1024 total.
- **`param2` dirty set:** empty. **Liquid dirty predicate:** as Case 2 — a
  solid node replacing native water makes it true.
- **Light-dirty box:** per chunk, write extent ⊕ 15, clipped:
  - `k_x = 10`: `(825, -15, 697) … (862, 22, 734)` = 38³ = **54,872** voxels,
    inside emerged x `[752, 863]`;
  - `k_x = 11`: `(833, -15, 697) … (870, 22, 734)` = 38³ = **54,872** voxels,
    inside emerged x `[832, 943]`.
  - Both satisfy `wp40-engineering-brief.md:1428-1433` — every changed content
    voxel has its complete 15-node neighbourhood inside the 16-node emerge
    border. That condition is **not** what fixes the half-depth at 8: a 16-deep
    half would satisfy it too (a write at `x = 832` expands to `x = 817`, still
    inside `k_x = 10`'s emerged `[752, 863]`). The binding constraint is **SEAM
    containment**: SEAM starts at `x = 824`, and a 16-deep half would put its
    light-dirty box at `x = 817`, outside SEAM, so the light lanes could not be
    compared over a single named box at all.
- **Permitted VoxelManip calls, exact maxima:** as Case 2 (no `param2` calls).
  `calc_lighting` region `(752, -32, 672) … (863, 47, 783)` for `k_x = 10` and
  `(832, -32, 672) … (943, 47, 783)` for `k_x = 11`.
- **Captured:** the four SEAM lane digests per run and per pass; the
  `digest_incl` digests of both bar halves in **every** arm; per-half realized
  dirty counts; per-call timings; the `case_baseline` record for each half.
- **Pass/fail:** the content and `param2` lanes are decided by the four-predicate
  truth table of section 10.13 (`V-05`), read against the native control's own
  order difference (`V-06`) and localized by `digest_incl` and `first_diff`. A
  combination that licenses no conclusion is `inconclusive`, never a pass. The
  light lanes are excluded from this verdict and reported separately under
  `V-08` as a test of the brief's halo-light idempotence exception
  (`wp40-engineering-brief.md:1471-1474`).
- **Negative mutations:** (i) let `k_x = 10` write the whole bar
  `x ∈ [840, 855]`, i.e. 8 nodes into its neighbour's central slice — the gate
  must fail with `payload wrote outside its central owner slice`, detected by
  the payload's own extent check against `minp`/`maxp` **and** by the SEAM
  digest diverging from the two-half expectation; (ii) swap the two halves so
  each chunk writes the other's — same reason fragment.

### 10.11 Operation-count summary

Exact maxima per chunk, per callback, counted by the proxy of section 10.12.
**This table is arm `B` only.** In arm `A1` every counter is zero for every
case, and in arm `A0` no `chunk_callback` record exists at all; the stage-2 gate
conditions on the arm accordingly (section 12.5).
`c` = realized content dirty set non-empty; `p` = realized `param2` dirty set
non-empty; `q` = liquid dirty predicate true.

| Method | 1a | 1b | 2 | 3 | 4 (each half) |
| --- | --- | --- | --- | --- | --- |
| `get_emerged_area` | 0 | 0 | 1 | 1 | 1 |
| `get_data` | 0 | 1 | 1 | 1 | 1 |
| `set_data` | 0 | 0 | `c ? 1 : 0` | `c ? 1 : 0` | `c ? 1 : 0` |
| `get_param2_data` | 0 | 0 | 0 | 1 | 0 |
| `set_param2_data` | 0 | 0 | 0 | `p ? 1 : 0` | 0 |
| `get_light_data` | 0 | 0 | 2 | 2 | 2 |
| `set_lighting` | 0 | 0 | 1 | 1 | 1 |
| `calc_lighting` | 0 | 0 | 1 | 1 | 1 |
| `set_light_data` | 0 | 0 | 1 | 1 | 1 |
| `update_liquids` | 0 | 0 | `q ? 1 : 0` | `q ? 1 : 0` | `q ? 1 : 0` |
| `write_to_map`, `read_from_map`, `initialize`, `close`, `update_map`, `was_modified`, `get_node_at`, `set_node_at` | 0 | 0 | 0 | 0 | 0 |

The preparation-call count of 1 is "the canonical bounded box count produced for
that dirty set; it is not a second upload count"
(`wp40-engineering-brief.md:1457-1458`) — here the canonical box count is 1
because the probe's dirty sets are single axis-aligned boxes by construction.

### 10.12 The counting proxy

The payload never holds the raw VoxelManip. `payload/vm_proxy.lua` wraps it in a
plain table whose eighteen entries forward to the real object and, per call,
increment a named counter and record a `core.get_us_time()` delta. Every method
the probe does not use is present in the proxy and raises immediately with
`forbidden VoxelManip method: <name>`, so an accidental call is a loud failure
rather than an uncounted one.

The gate that keeps this honest is static, not conventional. Self-reported
counters alone are not acceptable evidence, because a bug that skips a call
would also skip its counter — so a grep sweep in the shape of
`tools/wp40/t2_source_audit.sh:363-393` asserts that raw-VoxelManip access
appears in exactly one file. The scoping matters as much as the pattern:
`t2_source_audit.sh` avoids self-matching by restricting its sweep to
production paths, and this package must copy the scoping and not only the
shape. The sweep is therefore defined as:

```
rg -n --glob 'tools/wp40/t5_probe/payload/**.lua' \
   --glob '!tools/wp40/t5_probe/payload/vm_proxy.lua' \
   -e 'core\.vmanip' \
   -e 'get_mapgen_object' \
   -e '(^|[^%w_])vm:[a-z_]+' \
   ; test $? -eq 1
```

Three exclusions are stated rather than discovered:

- **the runner is out of scope.** `run_t5_probe.sh` contains all three pattern
  literals because it *implements* the sweep; a repository-wide sweep would
  match itself and fail;
- **`vm_proxy.lua` is the one permitted holder** and is excluded by path;
- **`payload/mapgen.lua` necessarily receives the raw object** as callback
  argument 1 (`reference_projects/luanti/src/script/cpp_api/s_mapgen.cpp:50-55`).
  It must pass that argument straight into `vm_proxy.wrap(...)` on the first
  statement of the callback and never bind it to a name matched by the pattern;
  the reviewer reads that one line rather than trusting the sweep for it. The
  `vm:` pattern is anchored on a non-word character precisely so an identifier
  merely *ending* in `vm` does not match.

**Stated exemption: the main-state readback.** `driver/readback.lua` legitimately
uses a raw main-state VoxelManip — `core.get_voxel_manip()` plus `read_from_map`,
which are legal outside the emerge environment
(`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:44-45` forbids
`read_from_map` only in the mapgen environment). It is outside the sweep's path
scope because it is not the payload, it makes no mapgen-VM call, and it runs
after every chunk has been generated. The exemption is named here so it cannot
be mistaken for an oversight.

### 10.13 Why Case 4's failure is a result, not a probe bug

Work the mechanism out explicitly.

In **O1**, `k_x = 10` generates first and writes its half of the bar into
`x ∈ [840, 847]`. Those voxels lie in `k_x = 10`'s **central** slice
(`[768, 847]`) — and simultaneously in `k_x = 11`'s emerged **border**
(`k_x = 11` full = `[832, 943]`). When `k_x = 11` is then requested,
`initBlockMake` creates the full area including those blocks and seeds the
VoxelManip from whatever is currently on the map
(`reference_projects/luanti/src/servermap.cpp:229-244`, `:254`,
`reference_projects/luanti/src/map.cpp:804-806`). mgv7 then regenerates terrain,
ores, dungeons, decorations, liquids and light over parts of the padded area
(`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:321-379`; dungeons
specifically over the full emerged range,
`reference_projects/luanti/src/mapgen/mapgen.cpp:952`), and `finishBlockMake`
calls `blitBackAll(changed_blocks)` with `overwrite_generated = true`
(`reference_projects/luanti/src/servermap.cpp:291`,
`reference_projects/luanti/src/map.h:334-335`), writing that border back to the
map. In **O2** the roles reverse exactly.

Therefore the outcome *"the engine does not preserve a central-slice write
across a later neighbour's generation"* is a legitimate, high-value **result**.
It is exactly the failure mode that `wp40-engineering-brief.md:1088-1090` and
`:1100-1103` exist to prevent, and it is the known upstream *unfinished slice
bug* that the engine itself names at
`reference_projects/luanti/src/emerge.cpp:181-186` and
`https://github.com/luanti-org/luanti/issues/9357`.

**Reading rule, so the outcome is reported rather than swallowed.**

Digests cannot be subtracted: a SHA-256 tells you *whether* two byte strings
differ, never *how*. The difference-of-differences is therefore defined as a
truth table over four equality predicates that a digest **can** answer, and the
localization comes from two additional record kinds (section 12.3): `digest_incl`,
which digests each case's own write extent and Case 3's two named sub-boxes, and
`first_diff`, which carries the lane, region, flat index, decoded world
coordinate and both byte values of the first differing voxel.

The four predicates, evaluated per lane over SEAM:

- `P1` := `SEAM(B, O1) == SEAM(B, O2)` — the treatment is order-stable;
- `P2` := `SEAM(A1, O1) == SEAM(A1, O2)` — the native control is order-stable;
- `P3` := `SEAM(B, O1) == SEAM(A1, O1)` — the payload delta is *empty* in O1;
- `P4` := `SEAM(B, O2) == SEAM(A1, O2)` — the payload delta is *empty* in O2.

`P1`…`P4` are the four edges of a 4-cycle over an equivalence relation, so any
combination with exactly three true is impossible; the harness asserts that and
aborts (`A-14`) if it observes one, because it would mean a digest was computed
over the wrong bytes.

| `P1` | `P2` | `P3` | `P4` | Conclusion licensed |
| --- | --- | --- | --- | --- |
| T | T | T | T | The payload produced no detectable SEAM change in either order, and both arms are order-stable. **Inconclusive about the seam** — Case 4 wrote nothing detectable. Read `V-03`, `digest_incl` over the two bar halves, and the realized dirty counts before concluding anything |
| T | T | T | F | **impossible** — abort `A-14` |
| T | T | F | T | **impossible** — abort `A-14` |
| T | T | F | F | **Clean pass**, subject to one corroboration. Both arms are order-stable over SEAM and the payload delta is non-empty in both orders, so the central-slice write survived a later neighbour's generation in both orders — for this seed, this chunk pair and this synthetic bar, and explicitly not generalized (`wp40-engineering-brief.md:3047-3048`). The corroboration is mandatory, not optional: `digest_incl(B, O1)` must equal `digest_incl(B, O2)` on **both** bar halves and must differ from `digest_incl(A1, O)` on both. If either fails, the row is downgraded to `inconclusive` and the discrepancy is reported, because a whole-SEAM equality can hold while the bar's own extents do not |
| T | F | T | T | **impossible** — abort `A-14` |
| T | F | T | F | The treatment is order-stable, the native control is not, and the payload delta is empty in O1 but not O2. **Inconclusive** — the payload's bytes coincide with native content in one order only. Localize with `digest_incl` and `first_diff` before drawing any conclusion |
| T | F | F | T | Mirror of the previous row. **Inconclusive**; localize |
| T | F | F | F | **Engine-native order dependence present; the treatment's final SEAM bytes are nevertheless order-stable.** Stated precisely: `SEAM(B, O1) == SEAM(B, O2)` is directly observed, but the *delta* `B − A1` is **not** order-stable, because its control moved — `A1(O1) != A1(O2)`. The licensed statement is about `B`'s bytes, not about the delta. The native difference is reported separately under `V-06` and localized with `first_diff`; the bar itself is checked with `digest_incl` over the two write extents and reported as a separate observation |
| F | T | T | T | **impossible** — abort `A-14` |
| F | T | T | F | The native control is order-stable, the treatment is not, and the payload delta is empty in O1 only. **Inconclusive**; localize |
| F | T | F | T | Mirror. **Inconclusive**; localize |
| F | T | F | F | **The load-bearing negative result.** The native control is order-stable over SEAM but the treatment is not, so the difference is attributable to the payload's own central-slice write failing to survive the later neighbour's generation. The report names which half of the bar changed, in which order, and at which x range, from `digest_incl` over the two write extents and from `first_diff`. This is the upstream *unfinished slice bug* observed (`reference_projects/luanti/src/emerge.cpp:181-186`, `https://github.com/luanti-org/luanti/issues/9357`) — a result, never "the probe failed" |
| F | F | T | T | Both arms are order-dependent and the payload delta is empty in both. **Inconclusive** — the probe wrote nothing detectable and the engine moved underneath it |
| F | F | T | F | **Inconclusive**; localize |
| F | F | F | T | **Inconclusive**; localize |
| F | F | F | F | **Inconclusive, and it can never become the negative result.** `P2` is false, so the native control is not order-stable over SEAM and there is no stable baseline against which any SEAM difference could be attributed to the payload. The escalation to `digest_incl` over the two bar halves is still run, but it may conclude at most one of two things, both enumerated below, and neither of them is `F T F F`'s conclusion |

**The `F F F F` escalation, enumerated.** The escalation compares
`digest_incl` over the two bar halves and has exactly two outcomes. There is no
`otherwise` branch anywhere in this table, and no row defaults to a conclusion.

| Escalation outcome | Licensed statement | `V-05` |
| --- | --- | --- |
| `digest_incl(B, O1) == digest_incl(B, O2)` on **both** halves | "the bar's own write extents are byte-identical across orders." Nothing further: `P2` is false, so the SEAM difference is not attributable to the payload, and the bar's own stability is not evidence that the *seam* is stable | `inconclusive`, with the bar-identity observation recorded separately |
| `digest_incl(B, O1) != digest_incl(B, O2)` on **either** half | "the bar's own write extents are **not** byte-identical across orders." The report names the half, the order and the x range from `first_diff`. It may **not** say the central-slice write failed to survive, because with `P2` false the same difference is equally consistent with native order dependence inside the write extent itself — a dungeon or cave regenerating at `x ∈ [840, 855]` would produce it with the payload behaving perfectly | `inconclusive`, with the bar-difference observation recorded separately |

**What additional evidence would settle an `F F F F` run.** Attribution needs a
run set in which the native control *is* order-stable over the compared box —
that is, `P2` true. Two routes are available without changing this contract's
design: re-run at a different `fixed_map_seed`, or re-run with SEAM narrowed to
a sub-box over which `A1(O1) == A1(O2)` holds, chosen from the `first_diff`
record of the failing run. Both are follow-on runs and neither is performed
automatically; the probe reports `inconclusive` and names the route.

`inconclusive` is a first-class verdict value emitted in the `verdict` record.
A combination that licenses no conclusion is **never** read as a pass, and the
summary may not report `V-05` as satisfied on an `inconclusive` row. The only
row that licenses the load-bearing negative result is `F T F F`; the only row
that licenses a pass is `T T F F` with its corroboration.

**How the per-lane rows aggregate into one `V-05`.** The truth table is
evaluated **per lane** over the two lanes `V-05` covers, `content` and `param2`.
A lane whose dirty set is empty by construction for the compared case cannot
produce a signal and must not be allowed to drag the verdict down: Case 4's
`param2` dirty set is empty by design (section 10.10), so that lane can only
land on `T T T T` or `F F T T`, both of which would otherwise read as
`inconclusive`. The rules:

1. a lane whose realized dirty count for the compared case is **zero by
   construction** — declared so in the case definition, not merely observed as
   zero — is recorded as **`no_signal_by_construction`** and is **excluded from
   the aggregate**. For Case 4 that is the `param2` lane, always;
2. a lane whose dirty count is zero **as an observation**, where the case
   declares it non-empty, is *not* excluded. It is `inconclusive` and is
   reported, because a payload that wrote nothing where it declared a write is
   itself a finding;
3. the aggregate `V-05` is computed over the **contributing** lanes only:
   the negative result if any contributing lane lands on `F T F F`; `pass` if
   every contributing lane lands on `T T F F` **with** its corroboration;
   `inconclusive` otherwise;
4. if **every** lane is `no_signal_by_construction` the aggregate is
   `no_signal_by_construction`, never `pass`. That cannot arise for Case 4,
   whose `content` lane always contributes;
5. the per-lane rows are emitted in full alongside the aggregate, so a reader
   can always see which lane decided the verdict.

For Case 4 as specified exactly one lane contributes — `content` — so the
aggregate `V-05` is the content lane's row, and the `param2` lane is recorded as
`no_signal_by_construction` rather than counted as a second inconclusive vote.

**Why the light lanes are excluded from `V-05`.** Case 4's central-owner-slice
claim above is stated for content and `param2`, and only for those. The
lighting work is different in kind: for `k_x = 10` the mandated `calc_lighting`
region reaches `x = 863`, which is 16 nodes inside `k_x = 11`'s central slice
`[848, 927]`, and S7 records that `spreadLight` covers the whole emerged area
regardless of the region argument
(`reference_projects/luanti/src/mapgen/mapgen.cpp:466-472`), after which
`blitBackAll(overwrite_generated = true)` writes it back
(`reference_projects/luanti/src/servermap.cpp:291`). Halo light writes are the
brief's **sole** derived-state exception to central content ownership: they
"may not alter content or `param2`, and the resulting values must be idempotent
when a neighboring owner chunk is later generated"
(`wp40-engineering-brief.md:1471-1474`). Arm `A1` performs zero lighting calls,
so a light-lane `B − A1` is not a payload delta comparable across orders — it
is a different computation per arm over overlapping, order-dependent inputs.
`V-08` therefore reports the light lanes separately, as a test of that
idempotence exception. Stated plainly: without this separation the probe could
publish the engine's unfinished-slice bug as confirmed on the strength of its
own lighting artefact.

### 10.14 Scope reduction, stated plainly

`wp40-engineering-brief.md:2965-2966` decides "identical canonical mapblock
output across nine fixed request schedules in the supported one-thread
configuration", enumerated at `:2975-2987`. **Only six of the nine schedule
shapes are instantiable by a synthetic payload.** Schedules 4 (`:2979-2980`),
5 (`:2981`) and 8 (`:2984-2985`) are defined over anchors, fixed interfaces,
resolver interfaces and chunk-crossing features — objects T2 and T4 own — and a
synthetic bar is not one of them. They are explicitly out of scope.

The probe exercises **two orders, not nine schedules**, over six chunks, not
the frozen feature corpus. Its result must never be presented as, cited as, or
folded into the §6.2 gate. That gate additionally requires "All one-thread
schedule hashes must match bit-for-bit" (`:3022`), a paired native control per
schedule (`:3029-3038`), and a decoded canonical serialization the probe does
not implement (`:3004-3016`).

Two further named-but-undefined objects: the "frozen liquid-settling procedure"
(`:3005`) and the "frozen quiescence limit" (`:1405`, `:1946`) are named in the
brief but nowhere numerically defined. Section 10.15 gives the probe's honest
substitute for the number nobody has decided.

### 10.15 Post-generation liquid settling is suppressed, not waited out

Post-generation liquid settling is **not** under the probe's control, and no
fixed wait can make it so. `finishBlockMake` drains the chunk's own queue
bounded by `liquid_loop_max` (`reference_projects/luanti/src/servermap.cpp:300`)
and pushes the remainder into the server-wide `m_transforming_liquid`
(`:304-308`). That global queue is drained inside `Server::AsyncRunStep`
whenever `m_liquid_transform_timer` reaches `m_liquid_transform_every`
(`reference_projects/luanti/src/server.cpp:781-792`), **unconditionally** — no
player, no active block, no forceload — with the period read once from
`liquid_update` at `:597` and defaulting to `1.0`
(`reference_projects/luanti/src/defaultsettings.cpp:533`). It is the only
background drain: `ServerMap::transformLiquids` has exactly one caller
(`reference_projects/luanti/src/server.cpp:792`), and the purge branch's
`liquid_queue_purge_time` is read inside it (`servermap.cpp:1260`), so it is
reachable only through the same gate.

The number of drain passes a chunk receives before readback is therefore a
function of **elapsed wall time**, which differs per arm — `A0` runs no probe
callback while `B` performs roughly 23 full-volume buffer marshals — and per
order, because a chunk's position in the sequence changes. **That difference
cannot be equalized.** O1 and O2 are exact reverses, so `k_x = 10` is generated
fifth in one and second in the other; its generation-to-readback window
necessarily differs by three mapchunk generations. Any tolerance loose enough
to accept that is loose enough to permit a multi-pass difference, so an
equalization assertion could not do its job even in principle.

**The contract therefore removes the time dependence at its root: it pins
`liquid_update = 86400` in the generated `minetest.conf`** (section 5). With the
background drain suppressed for the whole bounded lifetime of the run, what the
probe reads back is the state left by generation alone.

**Why this is the honest scope and not a dodge.** The state the probe then
compares is exactly the T5 seam: `update_liquids()` "scans the VM and queues
candidates but does not itself settle the liquid before the following Lua
statement" (`wp40-engineering-brief.md:1395-1398`), and "`finishBlockMake` later
performs engine liquid transformation and any engine-owned node-light updates"
(`:1402-1404`) — that is `transformLiquidsLocal` bounded by `liquid_loop_max`
(`servermap.cpp:300`) plus the spill at `:304-308`, and it is a pure function of
generation, not of wall time. Queueing plus the bounded local transform is what
a T5 mapgen callback can influence. Background settling over seconds is not a
T5 seam, it is server housekeeping, and the brief's "frozen liquid-settling
procedure" (`:3005`) and "frozen quiescence limit" (`:1405`, `:1946`) remain
undefined, so there is no number to conform to. The probe measures the seam it
can attribute and declines the one it cannot.

**What survives from the two-pass digest, and what it now proves.** The
quiescence proof is kept but re-purposed. Every run digests the compared
regions **twice**, the passes separated by at least two seconds, and both sets
are emitted (`digest.pass` = 1 or 2). With the drain suppressed the two passes
are expected to be **trivially identical**; a difference therefore no longer
means "liquid is still settling", it means the drain ran anyway — a wrong or
ignored `liquid_update`, an engine build that reads it elsewhere — or that
something else in the world moved between the passes. Either is a fault in the
run, not a property of the seam. No verdict of any kind is reported unless the
two sets are identical: verdict `V-09`, abort `A-13`.

`generated_us` on `emerge_done` and `readback_us` on every digest record are
**retained as evidence** — they let a reader see each chunk's
generation-to-readback window — but after this pin they **gate nothing**. There
is no settling-window assertion and no tolerance; the earlier `A-15` that
attempted one is withdrawn as unsatisfiable by construction.

The two-second inter-pass separation and the quiescence criterion remain
probe-local and are emitted with `settling_is_probe_local: true`.

---

## 11. Required seams and observations, mapped

| Mandate item | Settled by source already | What the probe establishes |
| --- | --- | --- |
| the real engine can load the mapgen environment | **yes** — S1, and **already production-proven**: `mods/MAPGEN/grug_mapgen/ocean_mask.lua:47` calls `core.register_mapgen_script` today | re-confirmation plus load wall time and callback registration index |
| exercise the IPC mechanism | **main → mapgen: yes**, and **already production-proven**: `ocean_mask.lua:46` sets, `ocean_mask_mapgen.lua:60` gets | re-confirmation plus unpack time; **new**: the mapgen → main direction (S3b) and the `save_gen_notify`/`set_gen_notify` per-chunk channel (S3c) |
| exercise an owner slice | partially — S6 establishes the geometry and that no engine guard exists | **new**: whether a central-slice write survives a neighbour's later generation (Case 4) |
| at most one content and optional `param2` upload | signature-level only — S5 | **new**: exact enforced counts under a proxy, with `param2` separated from content (Case 3) |
| liquid/lighting work only when dirty | S7/S8 establish the mechanisms | **new**: exact conditional counts and their cost |
| the same bytes in different chunk orders | **no** — S12 says the opposite is possible by construction | **new**: measured, per lane, in CORE and SEAM, against a paired control per order |
| callback time | S9 establishes `core.get_us_time()` exists and is monotonic | **new**: the numbers |
| peak working memory | S10 establishes only `collectgarbage` exists in the mapgen state, and S11 proves process metrics are impossible there | **new**: Lua-heap movement in both states; process RSS best-effort in the **main** state only |

**Genuinely new evidence — the short list.** Everything else above is
re-confirmation:

1. mapgen → main IPC actually delivers, and at what latency, and whether a
   blocking `ipc_poll` (`l_ipc.cpp:104-121`) is needed;
2. the `set_gen_notify` / `save_gen_notify` / `gennotify.custom` handshake
   delivers a per-chunk record end to end;
3. `set_param2_data` behaves as a separately gated upload alongside `set_data`
   on the same mapgen VM;
4. reordered chunk generation with a byte comparison — CORE and SEAM, treatment
   and paired control;
5. whether `A1 − A0` is empty;
6. whether `ValueNoise` at mapgen-script load time works despite
   `reference_projects/luanti/doc/lua_api.md:9871` (S4e);
7. the actual cost of one full-volume `get_data` / `set_data` /
   `get_light_data` / `set_light_data` / `calc_lighting` / `update_liquids`
   over 1,404,928 nodes on the designated host.

---

## 12. Measurement schema

### 12.1 Emission

One line per record, through the mapgen state's and the main state's `core.log`
(`reference_projects/luanti/src/script/lua_api/l_util.cpp:864` in
`InitializeAsync`, `:739` in `Initialize`):

```
core.log("action", "WP40_T5_PROBE_JSON " .. core.write_json(fields))
```

Compact, never pretty (the pattern of `tools/wp40/dungeon_probe/init.lua:17`).
Extraction is by marker **index**, never by prefix
(`tools/wp40/dungeon_probe/verify_log.sh:32-39`).

### 12.2 Common fields — on every record

Closing gap P11-1: unlike the dungeon probe, which carries a `schema` field
only on the derived summary (`tools/wp40/dungeon_probe/verify_log.sh:153`),
**every record here carries one**.

| Field | Type | Value |
| --- | --- | --- |
| `schema` | string | `"grug_wp40_t5_probe_synthetic_v0"` |
| `tag` | string | the discriminator; one of the tags below |
| `arm` | string | `"A0"` \| `"A1"` \| `"B"` |
| `order` | string | `"O1"` \| `"O2"` |
| `run_id` | string | `"<arm>-<order>"`, e.g. `"B-O2"` |
| `state` | string | `"main"` \| `"mapgen"` |
| `seq` | integer | 1-based, strictly increasing by 1 within one `state` |

### 12.3 Record shapes

`vec3` means `{x: integer, y: integer, z: integer}`. `int_or_unavailable` means
integer **or** the literal string `"unavailable"` — never absent.

| `tag` | Cardinality | Fields (all mandatory; `exact_keys` is enforced) |
| --- | --- | --- |
| `manifest` | exactly 1, `state = "main"`, `seq = 1` | `engine_string`:string, `engine_hash`:string\|`"unavailable"`, `engine_is_dev`:boolean, `lua_runtime`:string, `game_id`:string, `seed`:string, `mapgen_settings`:object of string→string, `mapgen_noiseparams_sha256`:string, `content_id_table_sha256`:string, `content_id_count`:integer, `mod_list_sha256`:string, `payload_digest`:string, `arm_switch_value`:string, `emerge_order`:array of integer (the six `k_x` in request order), `t0_us`:integer |
| `mapgen_state_init` | ≥ 1 in arms `A1`/`B`, **0 in `A0`** (no mapgen script is registered there); `state = "mapgen"` | `state_index`:integer (from `ipc_cas` on a counter key), `load_us`:integer, `ipc_get_us`:integer, `ipc_get_ok`:boolean, `ipc_set_us`:integer, `seed`:string, `chunksize`:integer, `mapgen_edges_min`:vec3, `mapgen_edges_max`:vec3, `callback_index`:integer (`#core.registered_on_generateds` after the payload registers), `value_noise_at_load_ok`:boolean, `value_noise_at_load_error`:string\|`""`, `value_noise_sample`:number\|`"unavailable"`, `vmanip_ctor_type`:string, `has_request_insecure_environment`:boolean, `has_get_gametime`:boolean, `has_get_timeofday`:boolean, `has_get_server_uptime`:boolean, `lua_bytes`:integer |
| `chunk_callback` | 6 per run in arms `A1`/`B`, 0 in `A0`; `state = "mapgen"` | `case`:string (`"1a"`\|`"1b"`\|`"2"`\|`"3"`\|`"4lo"`\|`"4hi"`), `kx`:integer, `minp`:vec3, `maxp`:vec3, `emin`:vec3\|`null`, `emax`:vec3\|`null`, `blockseed`:integer, `ops`:object of string→integer (all 18 method names, zeros included), `op_us`:object of string→integer, `callback_us`:integer, `write_extent_content`:integer, `write_extent_param2`:integer, `dirty_content`:integer, `dirty_param2`:integer, `dirty_liquid`:boolean, `light_dirty_voxels`:integer, `lua_bytes_before`:integer, `lua_bytes_after`:integer, `ipc_set_us`:integer, `production_adopted`:boolean (always `false`; see section 4b), `save_gen_notify_ok`:boolean. **`emin`/`emax` are `null` whenever the case is forbidden to obtain them** — cases `1a` and `1b`, and every callback in arm `A1` — because the only Lua routes are `vm:get_emerged_area()` (`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:377-387`) and `core.get_mapgen_object("voxelmanip")` (`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:609-621`), both of which those cases must not call. The keys are always present; only the values are `null` |
| `main_on_generated` | 6 per run | `minp`:vec3, `maxp`:vec3, `blockseed`:integer, `gennotify_present`:boolean, `gennotify_value`:string\|`""`, `callback_us`:integer |
| `emerge_done` | 6 per run | `kx`:integer, `action`:string (from the `core.EMERGE_*` names, `tools/wp40/runtime_probe/init.lua:83-89`), `calls_remaining`:integer, `elapsed_us`:integer, `deadline_us`:integer, `generated_us`:integer (absolute `core.get_us_time()` at completion, for the section 10.15 settling-window assertion) |
| `ipc_readback` | exactly 1 in every arm, `state = "main"`; `keys_expected` is **6 in arms `A1`/`B` and 0 in `A0`**, which registers no mapgen script and therefore has no mapgen state to publish from | `keys_expected`:integer, `keys_found`:integer, `poll_used`:boolean, `total_us`:integer, `values_sha256`:string |
| `digest` | 4 lanes × (6 CORE + 1 SEAM) × **2 passes** = 56 per run | `pass`:integer (`1` or `2`, section 10.15), `region`:string (`"core"`\|`"seam"`), `kx`:integer\|-1, `lane`:string (`"content"`\|`"param2"`\|`"light_day"`\|`"light_night"`), `node_count`:integer, `sha256`:string, `box_min`:vec3, `box_max`:vec3, `content_ignore_count`:integer (voxels read back as `CONTENT_IGNORE`; emitted on every lane's record from the content read of the same box), `readback_us`:integer (absolute `core.get_us_time()` when the box was read) |
| `digest_excl` | **32 per run** = 4 lanes × 4 written chunks (`k_x` 8, 9, 10, 11) × 2 passes, emitted in **every** arm over the **same** boxes so `B` and `A1` are comparable. The `excluded_kind` is fixed by the lane, not chosen: the `content` and `param2` lanes always carry `"write_extent"` (feeding `V-02a`) and the two light lanes always carry `"light_dirty_box"` (feeding `V-02b`), so each lane appears once per chunk per pass and the total is 32, never 64. `V-02a` and `V-02b` are `CORE(B, O) == CORE(A1, O)` over an excluded box, and digests cannot be subtracted (section 10.13), so an arm-`B`-only emission would make the out-of-extent-write detector unrunnable | as `digest`, plus `excluded_extent_min`:vec3, `excluded_extent_max`:vec3, `excluded_kind`:string (`"write_extent"` for the `V-02a` content/`param2` residual, `"light_dirty_box"` for the `V-02b` light residual) — the digest of CORE **minus** the named box |
| `digest_incl` | **48 per run** = 4 lanes × (4 write extents for `k_x` 8, 9, 10, 11 **plus** Case 3's two named sub-boxes) × 2 passes = 4 × 6 × 2; emitted in **every** arm over the same boxes so `B` and `A1` are comparable | as `digest`, plus `included_extent_min`:vec3, `included_extent_max`:vec3, `sub_box`:string (`""`, `"water"` or `"facedir"`) — the digest **of** the named box. This is what `V-03` and section 10.13's escalation row consume; `digest_excl` alone cannot answer them |
| `case_baseline` | 4 per run in arm **`B` only** (cases 2, 3, 4lo, 4hi), emitted by the payload from its single pre-write `get_data` buffer; `state = "mapgen"`. It cannot exist in `A1`, which performs zero VoxelManip calls by definition, or in `A0`, which has no payload — and it does not need to: in arm `B` the buffer read at the top of the callback *is* the native pre-write state, because nothing in the probe has written yet | `case`:string, `anchor_column`:vec3 (the x/z column at the centre of the case's write extent), `native_surface_y`:integer\|`null` (highest non-`air` y in the central slice of that column, scanned downward from `maxp.y`; `null` if the column is air throughout), `native_content_at_extent`:object of string→integer (registered node name → voxel count over the write extent, before the write), `native_air_count`:integer, `native_liquid_count`:integer. This is what section 19 hands the user instead of a guess about what they will see |
| `first_diff` | **exactly one per differing compared digest pair**, and zero when a pair is equal; `state = "main"`; emitted by `compare_runs.sh` into the comparison summary rather than by the engine run. The cardinality is **gated on that condition**: a comparison whose two digests differ but which emits no `first_diff` fails, because seven truth-table rows and `V-06` instruct the reader to localize with it and an absent record makes them unfollowable | `comparison`:string (e.g. `"SEAM:A1:O1-vs-O2"`), `lane`:string, `region`:string, `flat_index`:integer (1-based ascending VoxelArea index within the compared box), `pos`:vec3 (decoded world coordinate), `value_a`:integer, `value_b`:integer, `run_id_a`:string, `run_id_b`:string |
| `verdict` | one per verdict ID actually evaluated, `state = "main"`; emitted by `compare_runs.sh` | `id`:string (`"V-01"` … `"V-09"`), `lane`:string\|`"all"`, `result`:string (`"pass"`\|`"fail"`\|`"result"`\|`"inconclusive"`), `predicates`:object of string→boolean (for `V-05`, the four of section 10.13), `run_id_a`:string, `run_id_b`:string, `detail`:string |
| `process_metrics` | exactly 1, `state = "main"` | `available`:boolean, `rss_bytes`:int_or_unavailable, `rss_peak_bytes`:int_or_unavailable, `virtual_bytes`:int_or_unavailable, `cpu_seconds`:number\|`"unavailable"`, `lua_bytes_main`:integer, `reason`:string\|`""` |
| `settling` | exactly 1, `state = "main"` | `liquid_update_s`:number (read back at run time; expected `86400`), `background_drain_suppressed`:boolean (`liquid_update_s` exceeds the outer timeout), `interpass_wait_s`:number (at least `2.0`), `quiescent`:boolean (the two digest passes agreed), `settling_is_probe_local`:boolean (always `true`) |
| `abort` | 0 or 1 | `code`:string, one of the **closed set** `"A-01"`, `"A-02"`, `"A-03"`, `"A-04"`, `"A-05"`, `"A-06"`, `"A-07"`, `"A-08"`, `"A-09"`, `"A-10"`, `"A-11"`, `"A-12"`, `"A-13"`, `"A-14"`, `"A-15"` — enumerated here rather than given as a range, so adding an abort code without updating this list is a gate failure rather than a silently rejected record; `reason`:string, `detail`:string. The set is exactly the codes of section 15, with no gaps and no reserved upper bound |
| `complete` | exactly 1, terminal, `state = "main"` | `ok`:boolean, `chunks_generated`:integer, `records_emitted`:integer, `total_us`:integer, `emerge_deadline_us`:integer, `emerge_deadline_met`:boolean, `run_deadline_us`:integer, `run_deadline_met`:boolean (section 14.2) |

### 12.4 Process metrics are best-effort, not a gate

Lua heap via `collectgarbage("count")` is **mandatory** in both states and is
emitted as `lua_bytes*` fields on `mapgen_state_init`, `chunk_callback` and
`process_metrics`.

Process RSS / `VmHWM` via the main-state trusted-mod `/proc/self/status` read
(the `tools/wp40/runtime_probe/init.lua:35-50` mechanism, enabled by
`secure.trusted_mods` per `tools/wp40/capture_t0_baseline.sh:126`) is
**best-effort**:

- if `core.request_insecure_environment()` returns nil, or `/proc/self/status`
  cannot be read, or a field is absent, the probe records the **literal string**
  `"unavailable"` with a non-empty `reason` and continues;
- it must **not** hard-error the way `tools/wp40/runtime_probe/init.lua:6-10`
  does;
- it must **not** silently drop the field the way that probe's `kibibytes()`
  helper does (`tools/wp40/runtime_probe/init.lua:39-42`: `:41` returns
  `value and assert(tonumber(value)) * 1024 or nil`, so a non-matching
  `/proc/self/status` line makes the field vanish from the JSON entirely). The
  `exact_keys` gate of section 12.5 makes the vanishing case impossible here.

This use is the documented exception to `AGENTS.md:170-171` and
`docs/research/luanti-lua.md:234` ("**We never use it.**"), declared in the
driver's first two comment lines and in `driver/mod.conf` in the shape of
`tools/wp40/runtime_probe/init.lua:1-2` and
`tools/wp40/runtime_probe/mod.conf:3`.

**Alternative considered and rejected:** shell-side sampling of the engine
process's RSS by PID. It is not implemented anywhere in `tools/wp40/` today,
and under Flatpak the process the launcher exposes is not the engine process —
`tools/wp40/capture_t0_baseline.sh:255` records exactly this
("GNU time observes the Flatpak launcher, not the engine process"), and the
committed `tools/wp40/evidence/t0-post-wp43-wp18-wp36/70adabd28401e820ec86e8786bf0da368225c8624e42ed02dd3bce175fd3cafc/raw/run-001.time.txt:2`
shows `User time (seconds): 0.00` for a run that generated map. Building a
correct PID-tracking sampler is a larger package than this probe.

**No mapgen-state process metric is possible at any price.** S11 proves the
insecure environment is absent from the mapgen state twice over — by API table
(`reference_projects/luanti/src/script/lua_api/l_util.cpp:888`) and by trust
model (`reference_projects/luanti/src/script/cpp_api/s_security.h:80` versus
`reference_projects/luanti/src/script/scripting_server.h:54`). That absence is
itself a recorded result: `mapgen_state_init.has_request_insecure_environment`
is emitted and is expected to be `false`.

### 12.5 Fail-closed parsing

Three stages, in the shape of `tools/wp40/dungeon_probe/verify_log.sh`:

**Stage 1** — marker-index extraction (`:32-39`), then every extracted line must
parse as a JSON **object**:

```
jq -ce 'if type == "object" then . else error("record is not an object") end'
```

(`:48-49`). An empty extraction is a failure, not a pass.

Two properties of the in-tree extractor have to be closed here rather than
inherited. First, the awk marker-index extractor
(`tools/wp40/dungeon_probe/verify_log.sh:33-39`) silently **drops** every line
that does not carry the marker, so corrupt non-marker content in a raw log is
never gated at all. Stage 1 therefore adds a **non-marker garbage gate**: after
extraction, the residual — the raw log minus the extracted marker lines minus
the engine's own known log-line shapes, matched by an explicit committed regex
whose bytes are bound into the manifest digest — must be empty, or the run
fails with `raw log contains ungated non-marker content`. Second, a raw log
whose marker count is zero fails with `no JSON records found` before any jq
stage runs; zero records is never a vacuous pass.

**Stage 2** — one slurped `jq -se` assertion over the whole stream (`:51-138`),
reusing the primitive shape of `:54-65` (`is_integer`, `exact_keys($wanted)`,
`vector`, `trim`, `flag_set`).

**Stage 2 must be built from per-assertion `error("…")` calls, not from one
composed boolean.** The in-tree template at
`tools/wp40/dungeon_probe/verify_log.sh:51-138` evaluates to a single truth
value and emits no message, so it cannot satisfy section 16, which requires
a distinct `grep -qF` reason fragment for every row it assigns to stage 2 —
the count is derived from that table, not fixed here, so adding a row cannot
leave a stale number behind. Every assertion below is written as
`if <predicate> then . else error("<exact fragment>") end`, and the fragment
strings in section 16 are the literal `error()` arguments.

The assertions:

- every record has `schema == "grug_wp40_t5_probe_synthetic_v0"`;
- every record has a `tag` present in the closed tag set;
- every record satisfies `exact_keys` for its tag — no extra key, no missing
  key. This is what makes the `"unavailable"` marker of section 12.4 mandatory
  rather than optional;
- `arm`, `order` and `run_id` are constant within one file and
  `run_id == arm .. "-" .. order`;
- `seq` is 1-based and contiguous within each `state` partition;
- the first `state == "main"` record is `manifest` and the last record overall
  is `complete`;
- per-tag cardinality exactly as tabulated in section 12.3, **conditioned on the
  arm** — including `mapgen_state_init` and `chunk_callback` at zero in `A0`,
  `case_baseline` at zero outside arm `B`, and `digest`, `digest_excl` and
  `digest_incl` present in **every** arm over identical boxes — `V-02a`/`V-02b`
  compare `B` against `A1` over an excluded box and digests cannot be
  subtracted, so an arm-scoped emission would make them unrunnable;
- `first_diff` cardinality: exactly one record for every compared digest pair
  whose two digests differ, and none for a pair that is equal;
- geometry invariants, in the shape of `:101-114`:
  `maxp - minp == {79,79,79}`; **where `emin` is non-`null`**,
  `emin == minp - {16,16,16}` and `emax == maxp + {16,16,16}`; every write
  extent contained in `minp..maxp`; every light-dirty box contained in the
  chunk's computed emerged box; every CORE box equal to
  `minp + 16 … maxp - 16`; and **every compared box pinned to its literal
  contract coordinates** — a `digest`, `digest_excl` or `digest_incl` record
  with `region = "core"` must carry `box_min`/`box_max` equal to
  `(-16 + 80·kx, -16, 704) … (31 + 80·kx, 31, 751)` for its own `kx`, a record
  with `region = "seam"` must carry exactly
  `(824, -16, 696) … (871, 23, 735)` with `kx = -1`, and every
  `included_extent` / `excluded_extent` must equal the literal box its `case`
  and `sub_box` name in section 10.10. Without this pin a **displaced but
  successfully loaded** readback box passes everything: a box of uniform air at
  high y yields `content_ignore_count == 0`, uniform lanes, `P1`…`P4` all true,
  and `V-05` reports the clean row over a region the contract never named. The
  `emin`/`emax` assertion is **skipped, not
  inverted**, for cases `1a`/`1b` and for every arm-`A1` callback, where those
  fields are `null` by contract (section 12.3) — asserting them there would be
  tautological, and S6's runtime confirmation is therefore established only on
  the chunks that legitimately call `get_emerged_area` (cases 2, 3, 4lo, 4hi in
  arm `B`), which is recorded as such;
- the operation-count table of section 10.11, evaluated per `case` with the
  `c` / `p` / `q` conditionals read from the same record, and **conditioned on
  the arm**: in arm `A1` every counter in `ops` must be zero for every case, so
  the arm-`B` per-case table is applied only in arm `B`. Without this
  conditioning arm `A1` fails the gate in every run;
- every measured chunk's `emerge_done.action` equals the generated action
  (`core.EMERGE_GENERATED`, `tools/wp40/runtime_probe/init.lua:83-89`); a chunk
  served `FROM_MEMORY`, `FROM_DISK`, `CANCELLED` or `ERRORED` was not generated
  by this run and its digests are meaningless;
- `content_ignore_count == 0` on every `digest` and `digest_excl` record for
  both CORE and SEAM. This closes a vacuous-readback hole: `get_data` collapses
  `NO_DATA` into `CONTENT_IGNORE`
  (`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:109`) and S14
  records that the two are then indistinguishable, so two runs that both failed
  to load a region would produce identical `CONTENT_IGNORE` runs and pass every
  equality verdict, `V-05` included;
- both digest passes are present and `settling.quiescent == true`
  (section 10.15);
- `production_adopted == false` on every `chunk_callback`;
- `settling_is_probe_local == true`;
- terminal ordering, in the shape of `:131-137`.

**Stage 3** — the summary is generated with `jq -nc` and **re-parsed** with a
second `jq -e` including regex shape checks (`:144-175` and `:178-214`). The
engine-version gate is a regex whose own bytes are bound into the manifest
digest (`tools/wp40/run_dungeon_probe.sh:60`,
`tools/wp40/dungeon_probe/verify_log.sh:70`,
`tools/wp40/dungeon_probe/digest_lib.sh:54`). Non-golden values are labelled
in-band, the way `tools/wp40/dungeon_probe/verify_log.sh:166` writes
`positive_count_is_golden: false`; here the corresponding labels are
`timings_are_golden: false`, `settling_is_probe_local: true` and
`version_match: <bool>`.

### 12.6 Canonical serialization of the compared bytes

`core.write_json` key order is observed-sorted, not contracted, so **no digest
is ever taken over probe JSON as emitted**. Two rules close gap P11-9:

1. any digest over probe JSON re-canonicalizes with `jq -S -c` first;
2. the lane digests are not taken over JSON at all. They are taken over a
   packed byte string built in Lua:
   - `content`: two bytes per node, `string.char(math.floor(id / 256), id % 256)`;
   - `param2`, `light_day`, `light_night`: one byte per node;
   - node order is ascending flat index over the box, in the engine's own
     `VoxelArea` order — **x fastest, then y, then z slowest**:
     `i = (z - MinEdge.Z) * extent.Y * extent.X + (y - MinEdge.Y) * extent.X + (x - MinEdge.X)`
     (`reference_projects/luanti/src/voxel.h:267-273`), with `MinEdge`/`extent`
     taken from the **compared box**, not from the emerged area. The full axis
     order is stated so an independent implementation reproduces the digest byte
     for byte;
   - `core.sha256(buffer)` (`reference_projects/luanti/src/script/lua_api/l_util.cpp:777`).

   Peak string size is bounded by hashing **per box per lane** (≤ 221,184 bytes
   for a CORE content lane) and then rolling the leaves up with the labelled
   `key=value` canonicalization of section 13.3. Two-level digests keep peak Lua
   memory bounded and make a differing chunk localizable without re-running.

`mods/MAPGEN/grug_mapgen/wp40/canonical.lua` is a locked T2 surface
(`wp40-t2-plan.md:229`); the probe neither imports nor reproduces it, and the
serialization above is defined here from scratch for that reason.

---

## 13. Evidence and reproducibility

### 13.1 Archive base and injection proof

`git archive HEAD | tar -x` into a temporary game root, copy the probe files in,
recompute the payload digest from the copied bytes, and **refuse to continue if
it differs from the digest computed from the working tree** — the shape of
`tools/wp40/run_dungeon_probe.sh:58-71` (archive at `:62`, copy at `:63-65`,
recompute at `:66-67`, refusal at `:68-71`). The archive base commit SHA is
recorded and bound into the manifest digest. Because `.gitignore:8` excludes
`tools/bin/` from any `git archive` export, interpreters needed by in-export
gates are copied explicitly, the way `tools/wp40/run_t2_census_gates.sh:76`
does immediately after its archive at `:75`.

### 13.2 Disposable worlds

`mktemp -d /tmp/grudgelands-wp40-t5-probe.XXXXXX` with a matching `case`/`esac`
prefix guard and `trap cleanup EXIT INT TERM`
(`tools/wp40/run_dungeon_probe.sh:39-46`); layout in the shape of `:48-56`;
`world.mt` in the shape of `:73-79` / `tools/wp40/capture_t0_baseline.sh:109-115`;
`minetest.conf` plus fixed seed in the shape of `:81-96` /
`tools/wp40/capture_t0_baseline.sh:116-127`, including the per-run
`port = 32000 + run` rule at `:120`; headless invocation in the shape of
`tools/wp40/run_dungeon_probe.sh:105-120` /
`tools/wp40/capture_t0_baseline.sh:134-146`, with
`--log-timestamp none --color never` (`:145`) because that is what makes a
server log byte-comparable, and **without** `--terminal`.

Freshness is by construction only; nothing asserts `map.sqlite` was absent. The
honest cache disclaimer of `tools/wp40/capture_t0_baseline.sh:239-241` is copied
verbatim into every run's summary.

### 13.3 Digests

SHA-256 only. The canonicalization rule is labelled `key=value` lines with a
versioned `schema=` first line, **never** a `sha256sum` output line, which would
embed a path. The in-tree template is
`tools/wp40/dungeon_probe/digest_lib.sh:27-34`:

```
	{
		printf 'schema=wp40-dungeon-probe-payload-v1\n'
		for name in mod.conf init.lua mapgen.lua; do
			content_digest="$(wp40_sha256_file_content "$directory/$name")"
			printf 'file_name=%s\n' "$name"
			printf 'file_content_sha256=%s\n' "$content_digest"
		done
	} | sha256sum | awk '{print $1}'
```

and `:50-56`:

```
	{
		printf 'schema=wp40-dungeon-probe-manifest-v3\n'
		printf 'game_archive_commit_sha1=%s\n' "$game_archive_commit"
		printf 'probe_payload_sha256=%s\n' "$probe_payload_digest"
		printf 'engine_version_regex_sha256=%s\n' "$engine_regex_digest"
		printf 'config_content_sha256=%s\n' "$config_content_digest"
	} | sha256sum | awk '{print $1}'
```

The T5-0 manifest digest uses `schema=wp40-t5-probe-manifest-v1` and binds:
archive commit SHA, payload digest, engine-version regex digest, the
configuration bytes of all six runs, the coordinate-set literal, and the case
write-extent literals. The digest is **proven by a fixture, not asserted** —
same bytes at two different paths must produce the same digest, one appended
line must change it — in the shape of
`tools/wp40/dungeon_probe/digest_audit.sh:17-43`. The evidence directory is
named by the manifest digest (`tools/wp40/run_dungeon_probe.sh:144-149`), and
each run directory carries a self-excluding per-directory manifest in the shape
of `tools/wp40/capture_t0_baseline.sh:263-267`.

`tools/wp40/capture_t0_baseline.sh:63-68` hashes `sha256sum` output lines
including their paths. That is the anti-pattern; this package uses
`digest_lib.sh` and does not copy it.

### 13.4 Engine and runtime identity

In-band via `core.get_version()` in both states
(`tools/wp40/runtime_probe/init.lua:154`, `:162-164`, `:171`, noting
`rawget(_G, "jit")` for `strict.lua` safety), and host-side via
`flatpak info` / `--version` / LuaJIT detection
(`tools/wp40/capture_t0_baseline.sh:56-61`) plus `tools/wp40/collect_host.sh`,
whose unavailable values degrade to the literal `"unavailable"`.

The installed Flatpak is **5.16.1** while the pinned reference is
**5.17.0-dev `df04879`**. The mismatch is recorded, not hidden: the run summary
carries `version_match: false` in the shape of
`tools/wp40/capture_t0_baseline.sh:231-234`. Every runtime observation is
therefore an observation of 5.16.1 and corroborates rather than replaces the
pinned-source audit of section 7.

### 13.5 Attribution

The summary states, per verdict, which pair of runs produced it, and never
mixes arms across orders except in the explicitly named `V-05`/`V-06` cross-order
comparisons. Every verdict record carries the two `run_id` values it was
computed from.

### 13.6 Directories

Scratch under the guarded `mktemp` root, deleted on exit. Results under
`tools/wp40/results/t5_probe/<manifest-digest>/` (ignored by `.gitignore:11`),
refusing to overwrite an existing directory with exit 2
(`tools/wp40/capture_t0_baseline.sh:81-83`). Reviewed evidence is promoted to
`tools/wp40/evidence/t5-probe-<manifest-digest>/` by overriding
`WP40_RESULTS_ROOT` (`tools/wp40/capture_t0_baseline.sh:18-21`,
`tools/wp40/README.md:1109-1111`), and `.gitattributes` is extended to disable
Git's whitespace diagnostic for that tree's `raw.log` files only, exactly as
`.gitattributes:1` does today.

---

## 14. Runtime and CPU budget

### 14.1 Ceilings

| Quantity | Ceiling |
| --- | --- |
| distinct measured mapchunks | **6** |
| generated mapchunks per run | 6 |
| generated mapchunks total | 36 (6 runs × 6) |
| **emerge-phase** wall time per run, from `register_on_mods_loaded` to the last `emerge_done` | **< 45 s**, asserted in-run (section 14.2) |
| **whole-run** wall time per run, to the `complete` record — emerge, both readback passes, packing, hashing and the inter-pass settling wait included | **< 60 s**, asserted on the `complete` record (section 14.2) |
| outer `timeout` per engine invocation | 180 s; exit 124 always fails the capture (`tools/wp40/README.md:1116-1117`) |
| **expected** total engine wall time | a few minutes. The per-run in-server work is small — six mapchunk generations plus roughly 23 full-volume buffer marshals in arm `B`. The outer timeout is a ceiling, **not** an expectation: 6 × 180 s of timeout budget is not the expected cost and must never be quoted as one |
| concurrent engine invocations | **1** — the six runs are strictly serial |
| concurrent offline Lua processes (static gates, self-tests) | ≤ 8 (`tools/wp40/README.md:439`) |

The wall-time figures are a **LuaJIT** budget. The installed Flatpak runtime is
LuaJIT-only (`tools/wp40/capture_t0_baseline.sh:59-60` detects it; `:257`
records "Flatpak runtime is LuaJIT only"), so this is a documentation bound
rather than a live risk — but a PUC-5.1 engine would not fit it. The
repository's measured PUC-to-LuaJIT ratios are "2.8x on validation-heavy paths,
16.2x on an exhaustive numeric sweep, 26.5x on a full seed-0 compile"
(`tools/wp40/README.md:436-437`), and this probe's hot path is a full-volume
numeric sweep, so a PUC engine run would need its own re-derived budget.

**Reconciliation with the "4–12 chunks, a few minutes" sizing.** The measured
chunk set is **six distinct mapchunks**, which is inside 4–12. The 36 chunk
*generations* are a consequence of the paired-control-per-order design that the
sizing itself requires: a single baseline capture cannot attribute an order
delta, because it has no per-order control to subtract (section 4a, and
`wp40-engineering-brief.md:3029-3038`). Six runs over six chunks is the
smallest design that satisfies both.

Engine runs are serialized because they contend for the same host, the same
single emerge thread and the same page cache, and because
`wp40-engineering-brief.md:3257-3261` binds any comparison to "the same recorded
target host, engine build, Lua runtime, mapgen settings, exact request trace,
cache class, and disposable-world state" and records that "A comparison against
a different checkout, host, or cache class is diagnostic only."

### 14.2 The in-run deadlines, and why exceeding them invalidates the run

`mods/CORE/grug_core/init.lua:934-950` unconditionally schedules six
`core.after(60 + 15·i)` capital sweeps, each of which may call
`core.emerge_area` (`:903-921`) on a branch whose short-circuit depends on
`core.get_spawn_level` (`:887-893`) and is therefore seed-dependent and
unknowable from source.

The driver records `t0 = core.get_us_time()` inside
`core.register_on_mods_loaded` and asserts **two** deadlines, because the
emerge phase is not the whole run and arm `B` has a far longer tail than arm
`A0`:

- **emerge deadline, 45 s.** On every `emerge_done` and before the first
  readback pass: `core.get_us_time() - t0 < 45 * 1000000`.
- **run deadline, 60 s.** On the `complete` record:
  `core.get_us_time() - t0 < 60 * 1000000`, covering both readback passes, the
  packing and hashing of 740,352 nodes across four lanes, and the inter-pass
  settling wait of section 10.15.

The second is not redundant. Readback, packing, hashing and settling are
unbounded work that happens *after* the emerge phase, and arm `B` performs
roughly 23 full-volume buffer marshals that arm `A0` never performs — so `B`'s
tail can straddle t ≈ 60 s while `A0`'s does not, which is exactly the per-arm
asymmetry `A-09` exists to prevent. Splitting the emerge phase off at 45 s
leaves the whole run, tail included, inside the 60-second window before the
first capital sweep fires.

On violation of either, the driver emits an `abort` record with code `A-09` and
calls `core.request_shutdown(msg, false, 0.1)`; the shell gate then fails the
run.

Exceeding the deadline **invalidates** the run rather than merely slowing it,
because after t ≈ 60 s the world is no longer the world the other five runs
measured: unrelated mapchunks are being generated on the same emerge thread,
the map file has grown, the page cache has changed, and — most importantly —
the six runs would no longer share an identical realized emerge sequence, which
`X-03` requires. A slow run and a contaminated run are indistinguishable from
the outside, so the probe refuses to guess.

Both statements are recorded: the measured chunks and their emerged shells are
disjoint from every capital sweep box (section 6.5), so the hazard is to
**run-to-run comparability**, not to the measured bytes themselves.

### 14.3 Measured cost projection, folded into the first real capture

The projection is **not** a seventh engine invocation. The run order is fixed so
that the projection *is* the first real capture:

1. run arm `B`, order `O1` first, with the outer timeout at 180 s, and
   **retain its output**;
2. record its per-case `callback_us`, per-call `op_us`,
   `emerge_done.elapsed_us`, both readback passes and the whole-run wall time,
   and commit the projection into the package README:
   `projected_total_wall_s = 6 × observed_run_wall_s`, together with the
   observed margin against the 45-second and 60-second deadlines;
3. if that run passed every gate, **it is the B/O1 capture** and only five
   invocations remain. Six invocations total. Only a *failed* projection costs
   an extra invocation, and a failed projection stops the package and returns
   to this contract rather than trimming a case.

Arm `B` order `O1` is chosen because it is the most expensive arm and therefore
the honest basis for a projection.

**The projection is one unreplicated sample and must be labelled as one.**
`projected_total_wall_s = 6 × observed_run_wall_s` multiplies a single
measurement by six; the README states that in those words rather than
presenting the product as an estimate with a known error. Consistently with
this, **every timing this probe emits is n = 1**: one run per (arm, order)
cell, no repetition, no warm-up, no variance statistic and no outlier rule.
That is recorded in the non-claims register (section 3.2) and in the summary as
`timings_are_golden: false` and `timing_replicates: 1`.

An optional repetition control is provided for anyone who wants more than one
sample, following the in-tree precedent `WP40_REPETITIONS`
(`tools/wp40/capture_t0_baseline.sh:22`, recorded in the manifest at `:226`):
`WP40_T5_PROBE_REPETITIONS=<n>` repeats **every** cell `n` times with a fresh
disposable world each time. When `n > 1` the reported timing per cell is the
**median** of the `n` samples, the minimum and maximum are recorded alongside
it, `timing_replicates` carries `n`, and the byte verdicts of section 10.9 must
hold for **every** replicate, not for the median — a digest has no median. The
default is `n = 1` and no gate depends on `n > 1`.

Nothing in this package may become a large terrain sweep or a visual sweep. Two
volume figures are stated because they differ, and the contract freezes the
first:

- **hashed volume per run, per lane, per pass: 740,352 nodes** — 6 × 110,592
  CORE plus 76,800 SEAM. **This is the frozen contract literal**, because it is
  what the readback and hashing cost is proportional to.
- **distinct compared volume per run: 719,872 nodes.** SEAM overlaps CORE(10)
  and CORE(11) by 10,240 voxels each — SEAM's `x ∈ [824, 831]` lies inside
  CORE(10)'s `x ∈ [784, 831]` and SEAM's `x ∈ [864, 871]` inside CORE(11)'s
  `x ∈ [864, 911]`, over 40 y-values and 32 z-values in each case — so 20,480
  voxels are hashed twice, once under a CORE box and once under the SEAM box.
  The duplication is deliberate: the two boxes answer different verdicts and are
  compared against different partners.

The generated volume is 6 mapchunks per run. Both volume literals and the chunk
count are contract literals; any increase is a contract change.

---

## 15. STOP / abort conditions for the future probe run

These abort a **run** — the capture stops and reports an abort code instead of
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
| `A-08` | `emin`/`emax` are non-`null` and are not `minp − 16` / `maxp + 16`, or are non-`null` on a case forbidden to obtain them | `X-06` |
| `A-09` | either in-run deadline is exceeded — 45 s emerge phase, 60 s whole run | section 14.2 |
| `A-10` | the outer `timeout` fires | exit 124. The partial raw log **must be preserved** into the results directory before the `trap cleanup` runs, exactly as the `A-09` in-run path preserves its `abort` record — an outer timeout is the one abort with no in-band record, so discarding its log would leave the most interesting failure with no evidence at all |
| `A-11` | the payload attempted a forbidden VoxelManip method | the proxy raises `forbidden VoxelManip method: <name>` |
| `A-12` | the payload's realized write extent is not contained in `minp..maxp` | the payload's own containment check, plus the stage-2 geometry invariant |
| `A-13` | the quiescence proof failed — the two readback digest passes disagree, which after the `liquid_update` pin means the background drain ran anyway or something else moved between passes | `V-09`, section 10.15 |
| `A-14` | an impossible predicate combination was observed in section 10.13's truth table (exactly three of `P1`…`P4` true) | `compare_runs.sh`; it can only mean a digest was computed over the wrong bytes |
| `A-15` | a measured chunk's `emerge_done.action` is not the generated action, or `content_ignore_count != 0` in a compared box | stage 2, section 12.5 |

Explicitly **not** aborts — these are results and are reported:

- `A1 − A0` is non-empty (verdict `V-01`);
- `B − A1` differs across orders (verdict `V-05`, section 10.13);
- `SEAM(A1, O1) != SEAM(A1, O2)` (verdict `V-06`);
- a section 10.13 predicate combination that licenses no conclusion — recorded
  as `inconclusive`, never as a pass and never as an abort;
- the light lanes differ across arms or orders (verdict `V-08`);
- `ValueNoise` at load time fails (S4e);
- process RSS is `"unavailable"` (section 12.4);
- the realized dirty set is smaller than the write extent, or zero.

---

## 16. Negative tests

Each of the 40 rows is a deliberate corruption the gate **must** abort on, with the exact
reason fragment it must abort with. The harness shape is
`tools/wp40/run_t2_census_gates.sh:35-51` — `expect_failure` at `:37-50`, with
the fragment matched at `:44` by `grep -qF`. Fixtures are generated inline the
way `tools/wp40/dungeon_probe/verify_log_test.sh:33-41` and `:43-57` generate
theirs; no fixture file is committed.

| # | Corruption | Applied to | Reason fragment the gate must abort on |
| --- | --- | --- | --- |
| 1 | empty file | raw log | `no JSON records found` |
| 2 | `printf 'fixture WP40_T5_PROBE_JSON {"tag":"BROKEN",}'` — a marker line whose payload is not valid JSON | raw log | `parse error` — the fragment is what `jq` itself prints (`jq: error … Expected another key-value pair`), **not** `record is not an object`, which only fires for a line that parses as valid JSON of the wrong type. Row 2a below covers that case |
| 3 | `printf 'fixture WP40_T5_PROBE_JSON [1,2,3]'` — valid JSON, wrong type | raw log | `record is not an object` |
| 4 | truncated after a valid header — the manifest record only | raw log | `terminal record is not complete` |
| 5 | `head -c 4096 /dev/urandom \| base64` appended to an otherwise valid log — **no marker lines**, so the awk marker-index extractor (`tools/wp40/dungeon_probe/verify_log.sh:33-39`) drops every one of them and the jq stages never see them | raw log | `raw log contains ungated non-marker content` — the stage-1 non-marker garbage gate of section 12.5. Without that gate this fixture is a vacuous pass, which is exactly the hole it exists to close |
| 6 | the same garbage with the marker prefix prepended to each line | raw log | `parse error` |
| 7 | delete `.schema` from one record | raw log | `record is missing schema` |
| 8 | set `.schema = "grug_wp40_t5_probe_synthetic_v1"` on one record | raw log | `unexpected record schema` |
| 9 | delete `.emin.z` from one `chunk_callback` | raw log | `vector shape invalid` |
| 10 | add an extra key to one `chunk_callback` | raw log | `record has unexpected keys` |
| 11 | drop `seq = 4` from the main partition | raw log | `seq is not contiguous` |
| 12 | set `.arm = "A0"` on one record of a `B` run | raw log | `arm is not constant within a run` |
| 13 | set `chunk_callback.ops.get_data = 1` for `case = "1a"` | raw log | `case 1a performed a VoxelManip call` |
| 14 | set `chunk_callback.ops.get_data = 2` for `case = "1b"` | raw log | `case 1b get_data count is not 1` |
| 15 | set `chunk_callback.ops.set_data = 2` for `case = "2"` | raw log | `case 2 set_data count is not 1` |
| 16 | set `chunk_callback.ops.set_param2_data = 0` with `dirty_param2 > 0` | raw log | `case 3 set_param2_data count is not 1` |
| 17 | set `dirty_param2 = dirty_content` for `case = "3"` | raw log | `param2 dirty set is not separate from the content dirty set` |
| 18 | set `ops.update_liquids = 1` with `dirty_liquid = false` | raw log | `update_liquids called with an empty liquid dirty set` |
| 19 | set `ops.update_liquids = 0` with `dirty_liquid = true` | raw log | `liquid dirty set is nonempty but update_liquids was not called` |
| 20 | set `chunk_callback.maxp.x = minp.x + 80` | raw log | `central chunk extent is not 80 nodes` |
| 21 | widen a Case-4 write extent past `maxp.x` | raw log | `payload wrote outside its central owner slice` |
| 22 | flip one hex character of a `digest.sha256` in one of two runs being compared | two summaries | `core digest mismatch` |
| 23 | change `content_id_table_sha256` in one of two runs | two summaries | `content id table is not identical across arms` |
| 24 | change one byte of the injected payload after the digest is computed | injected tree | `injected probe payload digest differs` |
| 25 | set the engine-version regex to `^0[.]0[.]0$` | manifest | `engine version does not match` |
| 26 | a synthetic raw log whose `complete` record carries `run_deadline_met = false` (and, in a second fixture, `emerge_deadline_met = false`) | raw log | `run deadline exceeded` / `emerge deadline exceeded`. **Re-sited from the engine to the log gate**: setting the real in-run deadline to 0 µs requires a live capture, and this suite runs *before* the expensive half. The deadline arithmetic itself is exercised by the offline unit fixture, not by burning an engine invocation |
| 27 | delete `process_metrics.rss_bytes` instead of setting it to `"unavailable"` | raw log | `record has unexpected keys` |
| 28 | set `production_adopted = true` on a `chunk_callback` | raw log | `probe IPC telemetry must not be marked production adopted` |
| 29 | same configuration bytes stored at a second path must yield the same manifest digest; one appended line must change it | digest fixture | `digest is path sensitive` / `digest did not change` |
| 30 | set one measured chunk's `emerge_done.action` to the `FROM_DISK` action | raw log | `measured chunk was not generated by this run` |
| 31 | set `digest.content_ignore_count = 1` on one CORE record | raw log | `compared region contains CONTENT_IGNORE` |
| 32 | emit only `pass = 1` digests, or make the two passes disagree on one box | raw log | `quiescence proof failed` |
| 33 | set `arm = "A1"` while leaving arm-`B` operation counts in `ops` | raw log | `arm A1 performed a VoxelManip call` |
| 34 | set `mapgen_state_init` cardinality to 1 in an `A0` run | raw log | `A0 must register no mapgen script` |
| 35 | make three of `P1`…`P4` true and one false in a synthetic verdict input | two summaries | `impossible predicate combination` |
| 36 | a `probe_tree_manifest` file hash that also matches a tracked file outside the evidence tree | disposal fixture | `probe file content survives outside the evidence tree` |
| 37 | an `abort` record carrying `code = "A-99"` | raw log | `abort code is not in the closed set` |
| 38 | displace one `digest` record's `box_min`/`box_max` by 64 nodes in `+y` while leaving the lanes internally consistent | raw log | `compared box is not at its contract coordinates` |
| 39 | a compared digest pair whose two `sha256` values differ, with no `first_diff` record emitted for it | two summaries | `differing digest pair has no first_diff record` |
| 40 | a `V-05` summary reporting `pass` on a row whose four predicates are `F F F F` | two summaries | `inconclusive row reported as a pass` |

All 40 rows run **before** the expensive half
(`tools/wp40/run_dungeon_probe.sh:20-27`) — none of them requires a live engine
capture, which is why row 24 was re-sited. Every fragment in the right-hand
column is a literal `error("…")` argument in stage 2 or a literal `printf` in
`compare_runs.sh`; see section 12.5 on why stage 2 cannot be one composed
boolean. Rows 2 and 4a assert on the fragment `jq` itself prints, not on a
fragment this contract invented — the harness asserts substring containment
(`grep -qF`), so `parse error` matches whatever `jq`'s full message is on the
installed version, and the exact observed message is recorded in the evidence
rather than pinned here.

---

## 17. Definition of done for the future implementation package

1. Every file of section 8.1 exists, and every created or modified path matches
   the four-pattern boundary definition of section 8.1 — no other `docs/` path,
   and in particular none of the binding authorities.
2. Every probe Lua file passes `tools/bin/luac51 -p`; `SETGLOBAL` counts are
   zero for tools-only files and **at most one** for the driver `init.lua`, and
   that one only the mod table (`docs/research/luanti-lua.md:260-261` permits a
   single mod-table global; it does not require one, and
   `tools/wp40/dungeon_probe/init.lua` has zero); the five
   sweeps of `docs/research/luanti-lua.md:310-321` run explicitly against
   `tools/wp40/t5_probe/` and are clean.
3. `coordinate_audit.lua` recomputes the 122-column structure envelope and the
   Ocean Mask derivation of section 6.2 from repository source and passes under
   both interpreters with byte-identical stdout and identical exit status
   (`tools/wp40/run_t2_s11_acceptance.sh:22-44`).
4. `digest_audit.sh` passes.
5. `verify_log_test.sh` and `compare_runs_test.sh` pass; all **40** rows of
   section 16 abort with their exact fragments, and none of them requires an
   engine capture.
6. The measured cost projection of section 14.3 is committed, labelled as one
   unreplicated sample, and its run is reused as the B/O1 capture so the package
   costs six engine invocations and not seven.
7. All six runs complete within both deadlines — 45 s emerge phase, 60 s whole
   run — with no abort code, or the package reports the abort and stops.
8. All six cross-run assertions `X-01` … `X-06` hold, and `V-09`'s quiescence
   proof holds in every run. No verdict is reported without it.
9. All **nine** verdicts `V-01` … `V-09` are computed and reported, including
   the ones whose outcome is "different" and the ones that come out
   `inconclusive` — section 10.13's truth table is applied verbatim, an
   `inconclusive` row is never reported as a pass, and no outcome is rewritten
   as a probe failure.
10. Every observation of section 11's "genuinely new evidence" short list has a
    recorded value or a recorded `"unavailable"` with a reason.
11. The evidence tree is committed under
    `tools/wp40/evidence/t5-probe-<manifest-digest>/` with raw logs, per-run
    summaries, the cross-run comparison, `map_meta.txt` copies, host manifest
    and self-excluding checksums.
12. `tools/wp40/t5_probe/README.md` carries the non-claims of section 3.2
    verbatim — including the `n = 1` and 21.6 % scoping items — the
    `version_match: false` note of section 13.4, the `timings_are_golden: false`
    and `timing_replicates` labels, section 20.3's four checks written out so a
    later reviewer need not rediscover them, and the disposal rule of section 20.
13. The evidence tree contains the `probe_tree_manifest` of section 20.2,
    with one `file_path` / `file_content_sha256` pair per probe file.
14. The five-minute user runtime test plan of section 19 is in the completion
    summary (`docs/process/wp-workflow.md:74-79`).
15. No production file, no `mods/` file and none of the six locked T2 surfaces
    appears in the package diff, and no `docs/` path other than this contract.

---

## 18. Independent-review checklist

For the reviewer of the future probe package. Every item is objectively
checkable; a reviewer who cannot check an item must fail it.

1. **Boundary.** `git diff --name-only` on the package branch matches the
   four-pattern boundary definition of section 8.1 and nothing else. A diff
   touching any other `docs/` path — in particular
   `wp40-engineering-brief.md`, `wp40-t2-contracts.md` or `wp40-t2-plan.md` —
   fails, and a checklist phrased as "…and `docs/`" is itself a failure.
2. **No production registration.** `rg -n 'grug_wp40_t5_probe' mods/ game.conf minetest.conf`
   returns nothing.
3. **Locked surfaces.** `git diff --name-only` intersected with the six paths of
   section 8.3 is empty; and `rg -n 'wp40/canonical|wp40/deterministic|geometry/(exact|raster|boundary)|t2_s1_authority' tools/wp40/t5_probe/`
   returns nothing.
4. **Proxy discipline.** The sweep of section 10.12 is run **with its stated
   path scoping** — `payload/**.lua` minus `vm_proxy.lua`, anchored `vm:`
   pattern — and returns nothing. A repository-wide sweep is itself a failure:
   it would match `run_t5_probe.sh`, which implements the sweep. The reviewer
   additionally reads the first statement of `payload/mapgen.lua`'s callback by
   eye and confirms callback argument 1 goes straight into `vm_proxy.wrap(...)`,
   and confirms `driver/readback.lua`'s main-state raw VoxelManip against the
   stated exemption of section 10.12.
5. **Forbidden methods.** The proxy defines all eighteen methods of
   `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:499-518` and
   raises on the eight the contract forbids (§7.2 lists eighteen; §10.11 permits ten).
6. **Operation counts and lane-split containment.** The stage-2 `jq` assertion
   implements section 10.11 exactly, including the `c` / `p` / `q` conditionals
   and the **arm** conditioning — not "at most", not "approximately". Separately:
   `V-02a` is evaluated on **both** the content and `param2` lanes over CORE
   minus the write extent, and `V-02b` on the light lanes over CORE minus the
   light-dirty box. An implementation that silently narrows `V-02` to the
   content lane in order to get a green run has lost `param2` containment and
   fails this item.
7. **Conditional counts are conditional.** `update_liquids` and
   `set_param2_data` are gated on a predicate the record itself carries, never
   on a hardcoded number.
8. **Coordinates.** `coordinate_audit.lua` recomputes rather than restates; the
   122-column set and the six `lo` values of section 6.2 come out of source, not
   out of this document.
9. **Ocean Mask sign.** The audit demonstrates that `box_needs_mask` is false
   because `lo ≥ 300` (deep inland), not because the box is far from the
   continent. A reviewer seeing the opposite argument fails the item.
10. **Digest canonicalization.** No digest is taken over a `sha256sum` output
    line containing a path; every digest input starts with a `schema=` line;
    the fixture of section 13.3 proves both properties.
11. **JSON discipline.** Every record carries `schema`, `tag`, `arm`, `order`,
    `run_id`, `state`, `seq`; `exact_keys` is enforced per tag; no field is ever
    absent — `"unavailable"` or `null` is used instead. Stage 2 is built from
    per-assertion `error("…")` calls, not one composed boolean, so section 16's
    fragments actually exist.
12. **Vacuous readback.** Stage 2 asserts `emerge_done.action` is the generated
    action for all six chunks and `content_ignore_count == 0` on every CORE and
    SEAM digest. Without both, two runs that failed to load a region produce
    identical `CONTENT_IGNORE` runs and pass every equality verdict including
    `V-05`.
13. **Settling.** The generated `minetest.conf` pins `liquid_update = 86400`
    and the substrate manifest records it as a determinism pin with its
    consequence; `V-09`'s two-pass quiescence proof is implemented and both
    passes are in evidence. There must be **no** generation-to-readback window
    assertion: O1 and O2 are exact reverses, so that window necessarily differs
    by three mapchunk generations and any such gate aborts every run set. A
    fixed `core.after` settling wait offered *in place of* the pin also fails
    this item.
14. **Content-ID digest.** `content_id_table_sha256` binds `id=` as well as
    `name=`, is built from an explicit `table.sort`, and is not a `pairs()`
    walk (section 10.4). A name-only digest fails this item.
15. **Localization records.** `digest_incl` and `first_diff` are emitted, and
    section 10.13's truth table is implemented over the four named predicates
    with `inconclusive` as a first-class verdict value. A summary that reports
    `V-05` as satisfied on an `inconclusive` row fails this item.
16. **No claim inflation.** The README and summary contain no sentence asserting
    a threshold from `wp40-engineering-brief.md:3339-3358` was met, no sentence
    presenting the two orders as the §6.2 nine-schedule gate, and no sentence
    presenting a timing as portable.
17. **Failure is reported, not swallowed.** Verdicts `V-01`, `V-05`, `V-06` and
    `V-08` are present with their measured outcomes, and section 10.13's truth
    table is implemented verbatim, `inconclusive` rows included.
18. **No sync.** `rg -n 'sync_to_luanti' tools/wp40/t5_probe/` returns nothing.
19. **Disposal clause.** Section 20's four concrete checks are written into the
    package README so the later T5 reviewer can run them without rediscovering
    them.
20. **Runtime plan.** The completion summary contains section 19's plan with
    concrete coordinates.

---

## 19. Five-minute user runtime test plan

Agents cannot run the Flatpak GUI; the user is the runtime tester
(`docs/process/wp-workflow.md:74-79`). The probe world is disposable and
headless-generated, so the user needs a world to look at before any of this is
possible.

### 19.1 Getting a world

The runner supports `WP40_T5_PROBE_KEEP_WORLD=1`. When set, after the arm-`B`
order-`O1` capture completes and its gates pass, the runner copies that run's
world directory to
`tools/wp40/results/t5_probe/<manifest-digest>/world-B-O1/` (ignored by
`.gitignore:11`, never committed) **before** the `trap cleanup` removes the
temporary root, and prints the absolute path plus the exact steps below. The
evidence copy under `tools/wp40/evidence/` is separate, read-only and is never
re-hashed after a GUI session.

The user then copies that directory into the Flatpak worlds folder — exactly
`~/.var/app/org.luanti.luanti/.minetest/worlds/` on this host, the sibling of
the `games/` directory `tools/sync_to_luanti.sh:10` targets and of the
`debug.txt` named at `AGENTS.md:71` — and opens it with the installed
Grudgelands game. **This is visual inspection only.** The
world was generated from a `git archive` of `1b38943`, while the installed game
is whatever was last synced; the Ocean Mask healing LBM, mob ABMs and node
timers will run as soon as a player is present
(`reference_projects/luanti/src/serverenvironment.cpp:576`, `:581`, `:957`,
`:968`) and may modify the world. No digest is ever recomputed from a world
that has been opened in the GUI.

**Expect unsettled liquid, and do not report it as a defect.** The capture pins
`liquid_update = 86400` (section 5), so the retained world was saved before the
server's background liquid drain ever ran
(`reference_projects/luanti/src/server.cpp:781-792`). Opening it under the
user's own configuration restores the default `1.0`-second period and the queue
settles normally within the first seconds of play. Water that is briefly a
standing wall on load — around the Case-3 cell in particular — is the expected
consequence of the pin, not a finding.

### 19.2 Setup, once in the world

```
/grantme fly, fast, noclip, teleport, settime
/time 12000
```

### 19.3 What the probe already recorded

The runner prints, alongside the world path, a short block taken verbatim from
the run's `case_baseline` records: for each of cases 2, 3, 4lo and 4hi, the
anchor column, the recorded `native_surface_y`, and the recorded native content
counts over the write extent. **The table below refers to those recorded values
rather than assuming what the world looks like.** If `native_surface_y` for the
case-4 columns is above `y = 7`, the bar is buried and the user is told so
before flying anywhere — the visual check is then "look at the gold block
through `noclip`", not "fly along the bar".

### 19.4 The five minutes

| Step | Where | What to look at | Red flag |
| --- | --- | --- | --- |
| 1 | `/teleport 848 4 715`, then `noclip` along `x` from 835 to 860 | The Case-4 **gold** bar crossing the `x = 847 \| 848` chunk boundary. It should be one continuous 16-node run of `default:goldblock`, 8 nodes each side of the boundary, 8 × 8 in cross-section. `noclip` is required, not optional: the printed `native_surface_y` will normally put the bar inside solid rock | **the bar is 8 nodes long instead of 16**, or one half is missing, or the two halves are offset. That is the load-bearing result of section 10.13 and it is what the probe exists to find. Report it; it is not a display artefact |
| 2 | `/teleport 848 <native_surface_y + 3> 715` from the printed value | Lighting continuity across `x = 848` **at the surface**. Underground light is uniformly 0, so a light seam is not observable at the bar's own depth — this step must be done above ground | a visible vertical light seam: a slab of terrain one shade darker or brighter whose edge sits exactly at `x = 848`. If the printed `native_surface_y` is `null` for both case-4 columns, skip this step and say so; there is no surface to look at |
| 3 | `/teleport 716 6 723` (`noclip`) | The Case-3 water cell: an 8 × 8 × 8 block of water at `x ∈ [712,719]`, `y ∈ [0,7]`, and immediately east of it an 8 × 8 × 8 block of cobblestone stairs at `x ∈ [728,735]` all facing the same way. Compare against the printed `native_content_at_extent` for case 3 | water that has not settled or is still a standing wall after a minute; stairs with random rotations (the probe writes `param2 = 1` uniformly) |
| 4 | `/teleport 643 4 723` (`noclip`) | The Case-2 cut/fill cell, compared against the printed case-2 baseline: an 8 × 8 × 8 air pocket at `y ∈ [0,7]` sitting directly on an 8 × 8 × 8 stone block at `y ∈ [-8,-1]`, at `x ∈ [640,647]`, `z ∈ [720,727]` | the pocket is filled, or the stone slab is missing — meaning the transaction did not survive the blit |
| 5 | `/teleport 487 40 727` then `/teleport 567 40 727` | The Case-1a and Case-1b chunks. They must look like ordinary untouched v7 Grudgelands terrain — biomes, trees, ores where you dig | **any** artificial-looking block, any flat plane, any hole. A no-op case that left a mark is a serious result |
| 6 | anywhere in the six chunks | Dig down a few nodes; look for unknown-node placeholders | a purple/`unknown node` block anywhere means a content-ID mismatch between the archive game and the installed game — record it and stop, since the world is then not comparable |

Total flying distance is under 500 nodes; the whole pass fits in five minutes
with `fast` enabled.

### 19.5 What this pass does not establish

It does not confirm any digest, any timing, any operation count or any order
comparison. Those come only from the headless captures and their gates. A GUI
session corroborates but does not replace them, in the same sense as
`tools/wp40/dungeon_probe/README.md:60-61`.

---

## 20. Disposal and non-reuse

### 20.1 Rule

Probe code is discarded when the real T5 package is cut. It "never becomes a
parallel production path or production adapter foundation"
(`wp40-acceleration-and-delivery-plan.md:530-532`). The durable result is this
contract, the package README, and the committed evidence — not a second
adapter.

### 20.2 Mechanics

1. The first commit of the real T5 package deletes `tools/wp40/t5_probe/` in its
   entirety (`git rm -r tools/wp40/t5_probe`).
2. The evidence tree `tools/wp40/evidence/t5-probe-<manifest-digest>/` is
   **retained** — it is committed, reviewed, immutable, and is the only durable
   artefact besides this document.
3. Working notes, kept worlds and unreviewed captures live under
   `tools/wp40/results/` (`.gitignore:11`) and are simply left to be deleted.
4. The evidence tree carries a **`probe_tree_manifest`**: one labelled
   `key=value` block per probe file, in the
   `tools/wp40/dungeon_probe/digest_lib.sh:27-34` shape, with
   `schema=wp40-t5-probe-tree-manifest-v1` first and then, sorted by path,
   `file_path=<path relative to tools/wp40/t5_probe/>` and
   `file_content_sha256=<content digest>` for every file the package created.
   It is what makes disposal checkable by **content** rather than by name.

### 20.3 The concrete checks the T5 review runs

Not a promise — three commands with expected output. A name-based check alone
is defeatable by rename: copying a probe file into `mods/` and changing the
schema tag would pass every identifier grep, and `--diff-filter=d` does not
catch copy-then-delete-with-edits below git's rename-similarity threshold. The
third check is therefore a **content** comparison against the committed
`probe_tree_manifest`.

```
# (1) the probe tree no longer exists
test ! -d tools/wp40/t5_probe

# (2) no probe file survives anywhere in the T5 diff except as a deletion
git diff --diff-filter=d --name-only <t5-base>..HEAD -- tools/wp40/t5_probe
#   -> must print nothing

# (3) no probe file CONTENT survives anywhere in the tree, under any name.
#     For every file_content_sha256 in the committed probe_tree_manifest,
#     no tracked file outside the evidence tree may hash to it.
git ls-files -z -- mods tools docs game.conf minetest.conf \
  | grep -zv '^tools/wp40/evidence/' \
  | xargs -0 sha256sum \
  | awk '{print $1}' | sort -u > /tmp/t5-tree-hashes
awk -F= '/^file_content_sha256=/{print $2}' \
  tools/wp40/evidence/t5-probe-*/probe_tree_manifest | sort -u \
  > /tmp/t5-probe-hashes
comm -12 /tmp/t5-tree-hashes /tmp/t5-probe-hashes
#   -> must print nothing

# (4) belt and braces: no probe identifier appears anywhere outside the evidence
rg -n 'grug_wp40_t5_probe|t5_probe|grug_wp40_t5_probe_synthetic_v0' \
   mods/ tools/ docs/ game.conf minetest.conf \
   --glob '!tools/wp40/evidence/**' \
   --glob '!docs/research/wp40-t5-0-engine-probe-contract.md'
#   -> must print nothing (rg exits 1)
```

Check (4) covers `docs/` as well as `mods/` and `tools/`, excluding only this
contract itself, which necessarily names the identifiers. `rg` must be present
before check (4) is trusted — a missing `rg` exits 127 and would read as "no
matches" (`AGENTS.md:133-136`). The T5 review runs the `rg` preflight of
`tools/wp40/run_t1.sh:4-9` first.

---

## 21. Specification-level STOP conditions

These are conditions that would have stopped this **specification**, evaluated
now, at contract time. They are distinct from section 15's run-level aborts.

| # | Specification-level stop condition | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Existing writers cannot be isolated or attributed. | **not fired**, after one correction | Section 6.1 enumerates every writer that can touch the probe coordinates with its deciding guard. The two game-Lua writers are **isolated by cited guards**: the Ocean Mask by `box_needs_mask` returning false (`mods/MAPGEN/grug_mapgen/geometry.lua:237-243`; `lo ∈ {557, 572} ≥ 300` per the derivation of section 6.2), evaluated before its first `vm:` call at `mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua:520`; and `structures.lua` by its `:849-851` early return, proven by the 122-column enumeration of section 6.4. The engine's own writers (section 6.1 rows 1–6) cannot be excluded anywhere in this world and are instead **attributed** by determinism (`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:318`) plus arm-to-arm cancellation, under the two named conditions and four named gates of section 6.1. Attribution deliberately does **not** use an in-callback provenance signal, because S14 proves none exists: `LuaVoxelManip` exposes no flags accessor (`reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:499-518`), `get_data` collapses `NO_DATA` to `CONTENT_IGNORE` (`:109`), `NO_DATA` is never set at all in a mapgen VM (`reference_projects/luanti/src/servermap.cpp:229-244` before `:254`, `reference_projects/luanti/src/map.cpp:804-816`), and `block->isGenerated()` is not bound to Lua. Provenance is therefore established externally, by controlling generation order (section 10.6) and by the region split (section 10.3). **The correction:** the first coordinate family considered — deep ocean — fails this row, because `box_needs_mask` returns *true* far from the continent and the Ocean Mask would co-write every measured chunk (section 6.2, "Rejected coordinate family") |
| 2 | The required IPC direction is unsupported or ambiguous in pinned source. | **not fired** | **main → mapgen is not merely supported, it is already production-proven** in this repository: `mods/MAPGEN/grug_mapgen/ocean_mask.lua:46` sets `grug_mapgen:continent` and `mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua:60` reads it in the mapgen state. **mapgen → main is unambiguous in pinned source:** there is exactly one `ModIPCStore` on `Server` (`reference_projects/luanti/src/server.h:349`, `:157-173`), `ModApiIPC::Initialize` is registered in the emerge state (`reference_projects/luanti/src/script/scripting_emerge.cpp:78`) and in the server state (`reference_projects/luanti/src/script/scripting_server.cpp:159`), both states get the same four functions (`reference_projects/luanti/src/script/lua_api/l_ipc.cpp:140-143`), and the deep copy runs in both directions (`:21`, `:40`) with a real CAS (`:65-87`). The one qualification is a **design fact, not an ambiguity**: there is no push and no notification — `ipc_poll(key, ms)` blocks the calling thread on a condvar (`:104-121`) and there is no key enumeration (`:128-133`), so the main state must poll, or use the per-chunk `core.save_gen_notify` channel (`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:2122`, body `:1082-1100`), which itself returns false unless main pre-registered the id via `core.set_gen_notify` (`:2080`; `reference_projects/luanti/src/mapgen/mapgen.cpp:1002-1013`). **Re-confirmation versus new evidence:** availability of both directions and of load-time IPC (S3a, S3b, S4) is settled by source and is re-confirmation only; the genuinely new runtime evidence is items 1 and 2 of section 11's short list — that a mapgen-state write is actually readable from the main state, at what latency, whether a blocking poll is needed, and whether the `set_gen_notify` / `save_gen_notify` / `gennotify.custom` handshake delivers a per-chunk record end to end. Section 4b binds the capability to telemetry: it is measured, never adopted for production (`wp40-engineering-brief.md:2278-2279`, `:2318`) |
| 3 | Instrumentation would require production edits. | **not fired** | Section 8.1 lists sixteen files, all under `tools/wp40/t5_probe/`. The arm switch is one generated `minetest.conf` key read by the driver, not a code change, so the mod set, the dependency graph and the mod load order are byte-identical in every arm (section 10.2). No file under `mods/`, no production registration, no second reusable adapter, and none of the six locked T2 surfaces (section 8.3, `wp40-t2-plan.md:227-237`). The instrumentation that could plausibly have demanded a production or engine edit — exact per-call VoxelManip counting — is done by a proxy table inside the probe payload with a static grep gate confining raw-VM access to one file (section 10.12), not by patching the engine, the game, or a `grug_*` mod. Reviewer items 1–4 and the three commands of section 20.3 enforce it mechanically |
| 4 | A needed measurement requires an unbounded or insecure design. | **not fired**, honest near miss — see risk **R1** | The one measurement that could demand an insecure design is process RSS / `VmHWM`. In the **mapgen** state it is impossible at any price, and that is settled twice over by source: `request_insecure_environment` is absent from `ModApiUtil::InitializeAsync` with an explicit refusal comment at `reference_projects/luanti/src/script/lua_api/l_util.cpp:888`, and that table **is** the mapgen state's (`reference_projects/luanti/src/script/scripting_emerge.cpp:77`); even if reached, `EmergeScripting` inherits `modNamesAreTrusted() == false` (`reference_projects/luanti/src/script/cpp_api/s_security.h:80` versus `reference_projects/luanti/src/script/scripting_server.h:54`). In the **main** state it is obtainable only through `secure.trusted_mods`, the documented exception to `AGENTS.md:170-171` and `docs/research/luanti-lua.md:234`. The design does not become insecure or unbounded because the measurement is demoted to best-effort with a mandatory literal `"unavailable"` and a `reason` string, never a hard error and never a vanishing field (section 12.4); the setting cannot reach the mapgen state (S11), does not change generated bytes, and is recorded in the manifest (section 5); and the rejected shell-side alternative is recorded with its reason. Every other measurement is bounded by contract literals: 6 mapchunks per run, 740,352 hashed nodes per run per lane per pass, the exact operation-count maxima of section 10.11, in-run deadlines of 45 s and 60 s (section 14.2) and a 180-second outer timeout (section 14.1). The absence in the mapgen state is emitted as a positive observation rather than left implicit (`has_request_insecure_environment: false`) |
| 5 | Chunk-order identity cannot be defined without T3/T4 semantics. | **not fired**, honest near miss — see risk **R3** | The identity **is** definable without borrowing T3 or T4 semantics, because the brief states it over engine artifacts only: decoded, canonically serialized mapblocks with separate SHA-256 hashes for content IDs mapped back to registered node names, `param2`, low-nibble day light, high-nibble night light, the combined node tuple, liquid state and gennotify records, explicitly excluding database bytes, compression order, timestamps and block serialization layout (`wp40-engineering-brief.md:3004-3016`). Not one of those requires a zone, a public geography query, a typed resolver, an operation type or a conflict rule. The probe instantiates four of those lanes (section 10.4) and defines its own canonical serialization from scratch (section 12.6) without importing or reproducing the locked `mods/MAPGEN/grug_mapgen/wp40/canonical.lua` (`wp40-t2-plan.md:229`). What is **not** definable without T2/T4-owned objects is three of the nine request **schedules** — 4, 5 and 8 (`wp40-engineering-brief.md:2979-2985`) are stated over anchors, fixed interfaces, resolver interfaces and chunk-crossing features. That is a scope reduction of the schedule set (section 10.14, risk R2), not a failure to define the identity, and the probe never presents its two orders as the §6.2 gate. Separately, order **effects** exist by construction (S12) and are paired rather than eliminated — that is risk R3, not this row |
| 6 | The probe would need to freeze a real production payload/schema. | **not fired** | Section 9.2: the payload contains exactly six literal integer box sextuples, four registered node names, one integer `param2` constant, and a dispatcher keyed on `minp.x`. Section 9.3: it borrows no record name, field name, operation-type name, conflict rule, priority ordering, resolver identifier, zone identifier, envelope name or catalog name from T2 (`wp40-engineering-brief.md:2249-2257`, and by construction none of `:2259-2261`), T3 (`:4089`, `:2423-2470`), T4 (`:4090`, `:2109-2113`) or T6/T7 (`:4092-4093`). The schema tag `grug_wp40_t5_probe_synthetic_v0` is deliberately foreign vocabulary and its `v0` announces that nothing here is a version-1 anything. `default:water_source` is reused only as a registered node name that exists in this world and is **not** an adoption of the single decided surface-water identity (`:1354-1355`). There is therefore nothing in the payload that could be frozen, and section 20 deletes the whole tree before T5 begins, with the T5 review proving its absence by the three commands of section 20.3 |
| 7 | The proposed evidence cannot distinguish baseline behaviour from the injected delta. | **not fired** | This is exactly what the **three-arm design** and the **CORE/SEAM split** answer. A two-run design (`wp40-acceleration-and-delivery-plan.md:488-491`) cannot separate "a mapgen script was loaded and a callback ran" from "the payload wrote"; three arms do. `A1 − A0` isolates the former and `B − A1` the latter (section 10.1); `A1 − A0` is expected empty, and a non-empty result is reported as a first-class finding (`V-01`, section 10.9) rather than silently absorbed into the payload delta. Attribution power is maximised by making the arms differ in exactly one generated configuration key: one driver mod, one payload file, byte-identical mod set, dependency graph, load order and content-ID assignment (section 10.2), verified by cross-run assertions `X-01` … `X-06` **before** any comparison is reported (section 10.8). The **CORE/SEAM split** gives the delta a defined domain. CORE is the central slice shrunk by exactly the 16-node rind a later neighbour's `blitBackAll` can rewrite (`reference_projects/luanti/src/servermap.h:175`, `reference_projects/luanti/src/servermap.cpp:291`, `reference_projects/luanti/src/map.h:334-335`) and which native dungeons also reach (`reference_projects/luanti/src/mapgen/mapgen.cpp:952`), so cases 1a, 1b, 2 and 3 are compared where no neighbour can interfere. SEAM is the named box around `x = 847 \| 848` where that interference **is** the object of study, compared as a difference-of-differences with the native control's own order difference reported separately (`V-05` / `V-06`, section 10.13). Baseline behaviour is never inferred or modelled: it is measured in its own runs, over the same world geometry, in both orders |

**One additional check this contract applied beyond the mandated seven.**
*Package cost, and non-interference with the existing world.* The cost verdict
is **not exceeded**: 6 runs, 36 generated mapchunks, 16 files, one strictly
serial engine sequence, the hard ceilings of section 14.1, and a mandatory
measured cost projection before the first full run (section 14.3), against
"small, roughly one compact tools-only package plus review"
(`wp40-acceleration-and-delivery-plan.md:528`). The non-interference verdict is
likewise clean: no existing writer is disabled — "It may not silently disable
an existing writer; any unavoidable overlap is either excluded by the test
coordinates or named in the expected baseline"
(`wp40-acceleration-and-delivery-plan.md:491-493`) — section 6.1 names every
overlap, `tools/sync_to_luanti.sh` is never called (section 8.2), reference pins
are never modified, and every world is disposable and guarded (section 13.2).

**No hard stop condition fired for this specification.** Three near misses must
be surfaced rather than smoothed:

### R1 — process RSS requires the main-state insecure environment

Lua heap is available everywhere; process RSS and `VmHWM` are not. In the
mapgen state they are impossible at any price (S11, proven twice over). In the
main state they require `secure.trusted_mods` to name the driver mod, which is
a documented exception to `AGENTS.md:170-171` and
`docs/research/luanti-lua.md:234`.

*Mitigation:* best-effort with an explicit `"unavailable"` marker and a
`reason` string, never a hard error and never a vanishing field (section 12.4);
the rejected shell-side alternative is recorded with its reason; the
mapgen-state impossibility is emitted as a positive observation
(`has_request_insecure_environment: false`) rather than left implicit.

### R2 — three of nine §6.2 schedules are not instantiable

Schedules 4, 5 and 8 (`wp40-engineering-brief.md:2979-2985`) are defined over
anchors, fixed interfaces, resolver interfaces and chunk-crossing features that
T2 and T4 own and a synthetic payload does not have.

*Mitigation:* stated plainly in section 10.14; the probe exercises two orders,
not nine schedules; the README and the summary are gated against presenting the
result as the §6.2 gate (reviewer item 12).

### R3 — engine-native chunk-order dependence exists by construction

`initBlockMake` seeds borders from the map and `blitBackAll` writes them back
with `overwrite_generated = true`; the engine itself names the *unfinished slice
bug* at `reference_projects/luanti/src/emerge.cpp:181-186`. The probe cannot
eliminate this.

*Mitigation:* paired per-order controls (`A0` and `A1` in both O1 and O2);
CORE defined to exclude exactly the rewritable rind; SEAM compared as a
difference-of-differences with the native control's own order difference
reported separately (`V-06`); and section 10.13's explicit rule that a Case-4
divergence is a result to be reported, never a probe bug to be swallowed.

---

## 22. Player-visible impact

**Player-visible impact: none.**

In the form required by `wp40-acceleration-and-delivery-plan.md:635-655`:

- **What a player would visibly notice:** nothing. The package changes no file
  under `mods/`, adds no registration to the shipped game, and produces only
  disposable worlds that are never distributed. The optional kept world of
  section 19.1 is a developer inspection artefact under an ignored path, not a
  shipped world.
- **What remains deliberately native v7 behaviour:** everything. The probe
  pins no mapgen behaviour setting; the six chunks it generates are ordinary
  Grudgelands v7 chunks plus a synthetic marker inside four of them.
- **What is simplified or omitted compared with decided design:** nothing —
  this package implements no design. The synthetic payload deliberately
  implements *no* design, and section 9.3 explains why that is the point.
- **Whether fresh-world regeneration is required:** no. No existing or future
  player world is affected.
- **Which existing `docs/design/` rules authorize the result:** none are needed
  and none are changed. The authoritative passages remain
  [`docs/design/world_zones.md`](../design/world_zones.md) and
  [`docs/design/world.md`](../design/world.md); this contract restates neither
  and links both.

Per `wp40-acceleration-and-delivery-plan.md:647-649`, a package that implements
existing design without deviation needs only the links and a "no design change"
statement, and no redundant user approval for the design question. This is that
statement. The user decision this contract *does* require is acceptance of the
contract itself (section 1.3).

---

## 23. Open decisions

**None.**

Every decision this contract needed is closed in the section named:

| Question | Closed in |
| --- | --- |
| three arms versus one baseline | 10.1, 10.2 |
| comparison regions and lanes | 10.3, 10.4 |
| exact coordinates and their justification | 6.2, 6.3, 6.4, 6.5 |
| which settings are pinned and which are recorded | 5, and section 4c for `mgv7_dungeon_ymax` |
| the t = 60 s hazard | 6.5, 14.2 |
| process metrics as best-effort, and the rejected alternative | 12.4 |
| the synthetic schema tag and its avoided vocabulary | 9 |
| case-to-chunk assignment, write extents, dirty sets, exact operation counts | 10.5, 10.10, 10.11 |
| how Case 4's failure is reported rather than swallowed | 10.13 |
| scope reduction against the nine §6.2 schedules | 10.14 |
| the mapgen-callback registration order relative to the Ocean Mask | 8.1 (`driver/mod.conf` depends on `grug_mapgen`), 6.2 |
| how conditional operation counts are expressed | 10.10, reviewer item 7 |
| canonical serialization of the compared bytes | 12.6 |
| how the user obtains a world to inspect | 19.1 |
| how the T5 review proves no probe code entered production | 20.2, 20.3 |
| how post-generation liquid settling is removed as a variable | 10.15 (`liquid_update = 86400` pin; `V-09` proves the drain stayed suppressed) |
| how a digest-only design localizes a difference | 10.13, and the `digest_incl` / `first_diff` records of 12.3 |
| which lanes carry containment evidence and which do not | 10.9 (`V-02a`/`V-02b`), 10.13's light-lane exclusion |
| the exact package boundary, `docs/` included | 8.1, referenced by 17.1 and reviewer item 1 |
| repetition, variance and the n = 1 statement | 14.3, 3.2 item 10 |
