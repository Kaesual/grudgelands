# Mapgen performance exploration (read-only Astra study, 2026-09-19)

Exploratory read-only analysis by GPT-6 Astra on the R9-MAP-C lane state 63b64752 (plateau attempts, coast band attribution) with the pinned engine source. Report only; no code changed. Feeds BACKLOG WP48 (writer post-processing, parallel emerge) and any later plateau decision. Measurements labelled analytic are LuaJIT probes on the portable harness, not engine runs.

## Summary

1. **Coast caching is the strongest immediate lever:** a provisional **6–10 s saving** against the current 78.9 s corpus warrants testing.
2. Whitebridge’s analytic planner fell from **2.91 s to 0.60 s** with retained lattice tiles and classification memoisation; its packed R5 plan stayed identical.
3. **Writer work contains avoidable repetition:** stop liquid-neighbour checks once a column is dirty, and omit discarded inner lighting.
4. Those two changes reduced a synthetic solid-sky chunk’s Lua writer time by **83%**; corpus savings remain unmeasured.
5. **Parallel emerge is already architecturally supported:** the callback already runs in a mapgen environment; conditional **2–4× throughput** is plausible.
6. Eight workers are neither automatically safe nor an 8× speedup: v7 ordering, duplicated caches, memory traffic and initialization need validation.
7. Native VM calls consume only **3.25 s** of the current corpus; `calc_lighting` itself consumes **0.45 s**.
8. A low plateau plus higher cave limits cannot create caves in rock that Lua adds after native cave generation.
9. The 97 callbacks include **87 owners outside the explicit ten-owner corpus**, largely from automatic start-area preloading.
10. No files were written, engine launched or agents started; the measurements below distinguish existing engine evidence from exploratory analytic probes.

## 1. Where the writer’s time goes

The inspected checkout is `63b64752a63dd213796eb511639943775c5573cb`; the engine reference is pinned at `df04879066de6eb94ca43996822a6dfacc74feca`.

For compact references below, **`wp40/` means `mods/MAPGEN/grug_mapgen/wp40/`**, and **`engine/` means `reference_projects/luanti/`**. All line numbers refer to this checkout.

**Measured totals**

| Configuration | Emerge wall time | Planner | Writer |
|---|---:|---:|---:|
| Reused natural-terrain baseline | 68.021 s | 31.414 s | 20.660 s |
| Plateau 441 | 99.276 s | 33.613 s | 50.779 s |
| Plateau 441, experimental bulk clear | 108.893 s | 35.558 s | 58.105 s |
| Plateau 128 | 87.796 s | 32.177 s | 40.021 s |
| Plateau 200 | 116.000 s | 32.925 s | 68.572 s |
| Current, plateau reverted | 78.916 s | 35.040 s | 27.014 s |
| Current, coast feature disabled | 66.467 s | 23.243 s | 27.087 s |

The original matched plateau-441 baseline was **69.638 s**, making that pair **+42.6%**. The often-quoted **+46%** uses the subsequently reused 68.021 s baseline. These are different comparisons. Source: [emerge-wall-clock.tsv:3](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/tools/r9_map_c/evidence/emerge-wall-clock.tsv:3).

Subtracting the instrumented native VM methods from writer time gives:

| Configuration | Native VM calls inside writer | Remaining writer time | Remaining share |
|---|---:|---:|---:|
| Baseline | 3.324 s | 17.336 s | 83.9% |
| Plateau 441 | 4.038 s | 46.741 s | 92.0% |
| Current | 3.248 s | 23.766 s | 88.0% |

“Remaining” includes Lua processing, buffer copies, successor passes, allocation/GC and measurement overhead. It is not a measured breakdown of individual loops. Sources: `tools/r9_map_c/evidence/profile-before-callback-summary.tsv` and `profile-after-callback-summary.tsv`, `vm_*_us` rows; instrumentation at `tools/wp40/profile/instrument-mapgen.patch:12`.

**The relevant scaling dimensions**

A normal owner contains **80³ = 512,000 voxels**, in **6,400 columns**. Its emerged VM contains **112³ = 1,404,928 voxels**. Let:

- `P` be voxels covered by planned runs, including unchanged outcomes.
- `M` be actually modified voxels.
- `R` be planned runs.
- `B` be the expanded lighting-context volume.

| Work | Scaling | Evidence |
|---|---|---|
| Full VM reads, validation, copying and intent-array clearing | Emerged volume, even for eventual no-ops | `wp40/r6_settlement.lua:2064`, `2072`, `2084` |
| R5 target preflight | `P`, despite caching target values | `wp40/map_adapter.lua:1071` |
| Initial R5 resolution and dirty intent | `P`; liquid checks can add six neighbour resolutions per changed voxel | `wp40/map_adapter.lua:1243`, `1318` |
| R5 expanded light-context scan | `B`, with another run lookup/resolution for planned owner voxels | `wp40/map_adapter.lua:1362`, `1373`, `1402` |
| R5 replay | `P`, recomputing already validated outcomes | `wp40/map_adapter.lua:1470` |
| Surface/structure/resource successors | Columns, selected candidate volumes and eligible resource populations | `wp40/r6_settlement.lua:2140`, `2310`, `2448`, `2908` |
| Final R6 dirty scan | All 512,000 owner voxels; additional semantic work on `M` | `wp40/r6_settlement.lua:3212` |
| Final light validation/restoration | Expanded context plus full emerged-buffer traversals | `wp40/r6_settlement.lua:3288`, `3408`, `3416` |

The important distinction is **planned versus changed**: several expensive passes revisit every planned voxel, including cave-preservation and equal-content outcomes.

There is also **discarded inner lighting work**. R6 invokes R5 through a shadow VM whose lighting and liquid setters do nothing. Nevertheless, R5 calculates lighting context, seed runs and restoration buffers before R6 calculates the authoritative combined transaction. This is explicit in [r6_settlement.lua:2098](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:2098).

Conversely, the large R6 canonical replay at `r6_settlement.lua:3055` is excluded in runtime mode. It must not be charged to production merely because it appears in the source.

**Where the plateau increase appears in the actual corpus**

Grouping existing callback logs by owner minimum Y:

| Slice | Callbacks | Baseline writer | Plateau-441 writer |
|---|---:|---:|---:|
| −32…47 | 46 | 14.503 s | 18.003 s |
| 48…127 | 43 | 5.253 s | 28.376 s |
| 128…207 | 6 | 0.253 s | 3.414 s |
| Other two slices | 2 | 0.652 s | 0.988 s |

The **49 slices starting at Y=48 or 128 account for approximately 87% of the writer increase** against the reused baseline. That strongly supports sky-normalisation work as the plateau bottleneck.

The baseline has **24 equal-content callbacks**, versus only **3** with the plateau. Lit callbacks rise from **72 to 93**. However, plateau 128, 200 and 441 have the same result-category counts; those counts alone cannot explain their non-monotonic timings.

These aggregations use the existing logs referenced by `profile-invocations.txt:7`, `13`, `16`, and `20`, particularly `/tmp/map-c-profile-before-bulk-1/cold/profile-events.log` and `/tmp/map-c-profile-after-3/cold/profile-events.log`. The logs contain no per-phase modified-voxel totals, so a precise whole-corpus attribution to individual Lua loops is unavailable.

**Read-only analytic probes**

I loaded source variants only into memory and used the existing R6 offline fixtures with the runtime constructor. These exercise the real planner and R5/R6 writer code, but use synthetic VM data and fixture content semantics; they omit production R7 successors and production-only strata. They are not engine benchmarks.

For a completely solid owner at Y=48…127, cleared to sky, separate LuaJIT processes produced these medians over the final three of four applications:

| Variant | Writer CPU time excluding analytic VM methods | Change |
|---|---:|---:|
| Original | 384.7 ms | — |
| Stop liquid-neighbour checks after the column is dirty | 113.3 ms | −70.5% |
| Also omit discarded R5 shadow lighting | 66.6 ms | −82.7% |

All variants modified 512,000 voxels and retained identical owner content/param2/light SHA-256:

`924b09fc4948ef2ea221f5808a3c0b98f131e1ee775f5590e35380bcd3b94f69`

In the original synthetic sky case, initial R5 intent consumed roughly **64%** of Lua writer time, inner lighting preparation **14%**, and final R6 dirty scanning approximately **8–10%**. A separate synthetic surface-fill case put initial intent around **53–60%**, inner lighting around **12%**, and replay around **12%**. These illustrate the mechanism; they are not asserted as production-corpus percentages.

**The cheapest concrete changes**

1. **Short-circuit the existential liquid test per column.**  
   At [map_adapter.lua:1318](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua:1318), skip subsequent liquid work once `dirty_liquid[column]` is set. Apply the corresponding guard to `column_liquid` at `r6_settlement.lua:3247`. The output is an OR over the column; finding another witness adds nothing. This preserves valid-input voxel bytes and dirty-column results. It does not eliminate scans in columns that never become liquid-dirty, and skipped validation/error paths require review.

2. **Give the composed R5 writer an explicit “outer transaction owns lighting” mode.**  
   Suppress the inner expanded scan and shadow light transaction; retain the real R6 final transaction. The isolated probe saved another **47 ms per solid-sky chunk** after the first change. A provisional corpus saving of **2–4 s** is reasonable to test, not established evidence. Preserve required ignore/context validation at the outer boundary.

3. **Carry resolved changed intervals forward.**  
   Record compact final CID/param2 intervals during resolution; use those intervals for replay and for an affected-region scan after successors. Split intervals where preservation policy, old semantics or target values differ. This removes repeated resolver calls and makes semantic bookkeeping depend more closely on changed runs. An additional **1–4 s on the current corpus** is a sizing hypothesis; fragmentation and allocation could erase it. Risk is higher because successor overwrites can restore original bytes, and final dirty decisions must compare against the immutable original.

The first two changes together warrant a provisional **2–5 s target on the current corpus**, and potentially **10–20 s in a plateau-heavy corpus**. Those estimates overlap and must not be added to the individual estimates.

Even an ideal interval implementation still requires **Ω(M) actual voxel writes**, plus full-buffer work imposed by the VM API. “Proportional to changed runs” is achievable for decisions and bookkeeping, not for every memory operation.

## 2. Why the coast lattice is slower than the ray search

The current implementation **runs the ray search first and adds the lattice fallback afterward**. It does not replace the rays.

At [height.lua:5207](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/mods/MAPGEN/grug_mapgen/wp40/height.lua:5207), an eligible query checks four directions up to 16 nodes: at most **64 classifications**, plus the query’s own classification. The lattice runs only if no ray found usable water (`height.lua:5224`).

For 6,400 distinct eligible inland columns, a single evaluation therefore costs up to:

- **409,600 ray classifications**;
- **6,400 query classifications**;
- additional lattice construction and lookup work.

Each lattice build classifies **46² = 2,116 samples**, then performs **20² × 27² = 291,600 distance-loop iterations**. Of the 729 offsets per query, 480 pass the annulus test. Evidence: `height.lua:5086–5139`.

**The cache geometry is mismatched**

The lattice retains only one tile, keyed by `floor(x/80), floor(z/80)`. Engine owners start at:

`floor((coordinate + 32) / 80) * 80 - 32`

Consequently, a normal engine owner spans four lattice tiles. A row-wise traversal repeatedly replaces the single cached tile. A full eligible traversal can trigger approximately **160 builds rather than four**. Sources: `height.lua:5069`, `5141`; `tools/wp40/profile/probe/init.lua:34`.

**Measured analytic example: Whitebridge**

Seed 0, owner minimum `(-432,-32,-1552)`:

| Measurement | Original | Retain lattice tiles | Also memoise classification |
|---|---:|---:|---:|
| Planner CPU time | 2.909 s | 2.239 s | 0.600 s |
| Lattice builds | 79 | 4 | 4 |
| Classification requests through the instrumented helper | 1,701,729 | 1,543,029 | 1,543,029 |
| Underlying classifier evaluations | 1,701,729 | 1,543,029 | 19,985 |

The original performed **1,412,733 ray classifications**, across repeated coast evaluations and planner context queries. Its 79 lattice builds added about **23 million distance-loop iterations**.

The packed R5 plan remained identical:

`5bfa7bd3c1f368374123173138c623953c7a32ff2c2e77b778edd3a2d5518981`

Three additional horizontal locations also retained their R5 plan digests. Their smaller gains confirm that Whitebridge is a hotspot, not a representative average.

**The historical column-cache problem is already partly fixed**

`column_values_at` currently has a **65,536-entry runtime cache**, returning all 20 tuple fields. Evidence mode deliberately bypasses it. See [zones.lua:1559](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/mods/MAPGEN/grug_mapgen/wp40/zones.lua:1559) and `1676`.

The remaining gap is lower down:

- `height.lua:1961` forwards `classified_values` directly to the horizontal classifier.
- `simple_map.lua:1923` performs warp, ownership, bay and hydrology classification without a complete-result memo.
- A column-cache miss obtains both terrain and functional surface values, which can independently traverse coast composition: `zones.lua:1580`, `1595`.

**Cheapest fix:** preserve several lattice tiles and add a bounded coordinate-keyed classification cache, scoped to the immutable world/seed session. Reuse the existing column-cache pattern, including explicit tuple lengths and correct caching of nil/false values. Keep the lattice’s world-space four-node sampling, distance rounding and tie order unchanged.

Do not memoise the final coast target solely by `(x,z)`: `supplied_incoming` participates in its result. Cache classification or shore-search metadata instead.

The measured engine ablation removes **the entire coast feature**, saving 11.798 s of planner time and 12.449 s of wall time. It is **not a lattice-versus-ray comparison** and changes terrain bytes. Recovering **6–10 s through equivalent caching** is a plausible experiment target, not a measured engine result. Source: `tools/r9_map_c/evidence/lane-notes.txt:91`.

Implementation must also respect the existing plain-Lua-5.1 upvalue constraint; an earlier coast instrumentation attempt already exceeded it (`lane-notes.txt:99`).

## 3. Plateau feasibility

**No listed v7 parameter solves the missing-rock problem.**

The native sequence is terrain → heightmap → biomes → caves → ores/dungeons/decorations → lighting, followed by our Lua callback. See [mapgen_v7.cpp:320](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/reference_projects/luanti/src/mapgen/mapgen_v7.cpp:320).

Native cave generation:

- skips chunks above native `max_stone_y`;
- skips existing air and water;
- excavates eligible ground nodes already present.

Evidence: `engine/src/mapgen/mapgen.cpp:833`, `847`, `878`; `engine/src/mapgen/cavegen.cpp:104–126`.

If native terrain height is `H` and authored height is `T`, a low native surface leaves the later fill `H < y ≤ T` absent when caves run. Raising cave limits cannot carve that absent rock.

| Parameter | Actual effect | Why it does not solve authored fill |
|---|---|---|
| `mgv7_cave_width` | Threshold for intersecting noise caves; sufficiently high values disable tunnels | Changes excavation of existing ground, not where rock exists |
| `mgv7_cavern_limit` | Raises the upper cavern envelope | Native `max_stone_y` and ground-node checks still apply |
| `mgv7_large_cave_depth` | Raises the allowed large-random-walk range | Generation still uses native ground and heightmap |
| `mgv7_dungeon_ymin` | Sets the lower dungeon bound | Dungeons are generated “only in ground”; this is not cave coverage |

Relevant defaults are at `engine/src/mapgen/mapgen_v7.h:30`. Raising `cave_width` should not be described as “raising caves”: it raises the excavation threshold.

To provide native rock everywhere below `T` while leaving every voxel above `T` as air requires native geometry to follow `T`. Generic v7 NoiseParams cannot reproduce the full authored composition of capitals, hydrology, terraces and local grades. Merely ensuring native noise stays below `T` guarantees the opposite problem: uncaved authored fill.

**Ranked options**

| Rank | Option | Expected cost | Output consequence |
|---|---|---|---|
| 1 | Keep natural v7; optimise classification caching and existing normalisation | Lowest implementation cost; savings discussed above | Intended byte-preserving; does **not** supply caves throughout later fill |
| 2 | Add a deterministic cave mask only inside authored fill | One bounded fill traversal plus bulk noise generation; initially budget **50–200 ms per affected chunk**, unmeasured | **Changes cave, resource, lighting and potentially liquid bytes** |
| 3 | Reconsider a high plateau after writer optimisation | Still writes every removed sky voxel; perhaps recover 10–20 s of the measured penalty, but no passing result exists | **Changes native cave/ore geometry and output bytes** |
| 4 | Add an engine facility accepting authored terrain heights or exposing a native cave pass after fill | Potentially efficient runtime; substantial engine/API and maintenance work | New engine contract; output equivalence is unproven |

For option 2, 50 affected chunks at that provisional budget would add **2.5–10 s**. This is an engineering allowance, not a benchmark result. The useful bound is structural: at most 512,000 owner voxels, preferably only fill intervals, rather than manufacturing and clearing whole sky slices. `ValueNoiseMap:get_3d_map_flat` is available for bulk noise; per-voxel Lua noise-object calls would be the wrong implementation. See `engine/doc/lua_api.md:7728`, `9893`, `9919`.

A mask must be world-coordinate deterministic and respect foundations, skin, water and native-cave interfaces. The disabled connected-mouth writer is not a substitute for general fill caves: it requires a continuing native component (`wp40/r6_settlement.lua:2330`).

The current API exposes native ore/decor generation but no equivalent `generate_caves` call (`engine/src/script/lua_api/l_mapgen.cpp:2104`). A cheap post-fill native cave call therefore needs engine work.

Finally, lowering the plateau is not a demonstrated optimisation: **200 is slower than 441**, and even the deep slice’s writer time varies substantially. Modified volume, input semantics, JIT behaviour and run conditions need separating before attributing that ordering to height.

## 4. Parallel emerge

**The migration has already happened.**

The loader publishes an IPC payload and calls `core.register_mapgen_script`; each mapgen environment builds its own runtime and registers the VM callback:

- [r7_loader.lua:126](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/mods/MAPGEN/grug_mapgen/wp40/r7_loader.lua:126)
- [r7_mapgen.lua:47](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/mods/MAPGEN/grug_mapgen/wp40/r7_mapgen.lua:47)

There is no large main-thread callback to port.

**State inventory**

| State or dependency | Ownership and mutability | Parallel consequence |
|---|---|---|
| IPC seed, manifest hash and content projection | Published at load; workers retrieve their own values | Keep immutable after publication |
| Source catalogs, manifests, schemas, deterministic constants | Worker-local tables, read-only after construction | Duplicated initialization/memory |
| Registered node definitions and CID/name mappings | Transferred definitions/read-only engine lookups | Available in mapgen env; definition callbacks are not callable there |
| Content semantics, resource catalogs, template identities | Frozen lookup data after construction | Safe to duplicate |
| Template/MTS and blueprint caches | Worker-local, some lazy materialisation | Repeated first-use cost per worker |
| Height/warp/hydrology/coast memo tables | Mutable worker-local caches | No cross-thread Lua race; cache history and memory multiply |
| `column_values_at` cache | Mutable 65,536-entry cache per worker | Reduced inter-chunk reuse when work is distributed |
| Planner arrays, generation counters, allocator and metrics | Mutable per runtime | Keep plan and apply on the same worker |
| R5 target caches, dirty arrays, VM/light scratch | Mutable per writer instance | Large duplicated buffers |
| R6 original/final arrays, occupancy, intent, resource eligibility and successor state | Mutable per writer instance | Large duplicated buffers; no shared instance |
| P9G, anchor and settlement planning state; road/plot/deck memos | Mutable per successor instance, with immutable identities | Audit history independence, not merely thread safety |
| Heightmap and current VM | Engine-owned current-worker data | Fetch/use only during that worker’s callback |
| Hash/PRNG helpers | Seeded local deterministic state | No shared global RNG dependency found |
| `core.settings`, mapgen settings and paths | Read at initialization; selected settings captured | Freeze relevant configuration before worker startup |
| Main-world mod storage and public `grug_*` authorities | Main environment; not used by the R7 writer chain | Keep preload/socket/storage orchestration there |

Evidence anchors: `wp40/r7_runtime.lua:91`, `232`, `247`, `264`; `r6_settlement.lua:884`; `r7_settlement.lua:1180`; `r6_hash.lua:183`; `r7_template_source.lua:45`.

The active chain uses available APIs: SHA-256, settings/readback, CID lookup, schematic reading, `get_mapgen_object("heightmap")`, and methods on the supplied VM. It does not require player APIs, node metadata or mod-storage access inside the writer. The engine explicitly documents per-thread environments, transferred registries and absent node metadata at `engine/doc/lua_api.md:7681–7760`.

Automatic start preloading does use mod storage, timers and `emerge_area`, but in the main environment: `mods/CORE/grug_core/starts_preload.lua:39`, `180`, `296`.

**What must change**

The one-thread setting is enforced in several places, not just configuration:

- `minetest.conf:28`
- `wp40/r7_runtime.lua:80`
- `wp40/r7_r6_manifest.lua:211`
- `wp40/mapgen_manifest.lua:42`
- `wp40/source/catalog.lua:75`
- `wp40/planner.lua:482`
- `wp40/map_adapter.lua:375`

Updating these requires coherent contract/pin changes and fixtures. Manifest/source hashes will change even if voxel output remains identical.

The main correctness risk is native generation order. The pinned engine explicitly says v7 is affected by the **unfinished-slice bug**, enables automatic multithreading only for singlenode, and caps automatic selection at four threads because of locking costs. See [emerge.cpp:180](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/reference_projects/luanti/src/emerge.cpp:180).

Worker-local Lua state does not remove interactions through overlapping native halos, lighting, cave overgeneration and final map commits. Compare adjacent and vertically stacked owners in different generation orders before accepting byte equivalence.

**Memory**

R5 and R6 alone retain approximately **15 full emerged-volume numeric arrays**: about **161 MiB of numeric slots**, before Lua table capacity, resource arrays, planner caches and blueprints. The analytic R6 runtime reported approximately **320 MiB of Lua heap before constructing its input VM**. Eight workers therefore imply several gigabytes of runtime state, plus the main authority and engine data.

Sources: `wp40/map_adapter.lua:600`, `r6_settlement.lua:884`.

**Expected wall-clock speedup**

Existing native profiler logs give:

| Configuration | Worker Lua | Native generation | Unattributed wall time |
|---|---:|---:|---:|
| Baseline | 52.074 s | 2.960 s | 12.987 s |
| Current | 62.054 s | 2.910 s | 13.952 s |

The unattributed remainder is **not a measured main-thread CPU total**. It includes initialization, queue dispatch, waiting and scheduling as well as serialized work.

If that remainder stayed fixed and all measured worker work divided perfectly:

| Workers | Baseline wall time | Current wall time |
|---:|---:|---:|
| 1 | 68.021 s | 78.916 s |
| 2 | 40.504 s | 46.434 s |
| 4 | 26.746 s | 30.193 s |
| 8 | 19.867 s | 22.072 s |

These are illustrative Amdahl calculations, **not predictions**. The serial ten-request tail, duplicated cache warming, initialization and memory bandwidth reduce scaling. For planning, **2–4× on an otherwise idle eight-core host** is a defensible hypothesis; measure two and four workers before expecting anything from eight.

Native generation and worker Lua run outside the environment lock; loading/commit stages acquire it. Evidence: `engine/src/emerge.cpp:549`, `591`, `728`.

A single-thread measurement on a loaded eight-core host is useful only as a controlled paired comparison. It does not predict idle latency or eight-worker performance: boost frequency, SMT competition, cache pressure and memory bandwidth differ. The recorded invocations use `nice -n 19`, making workload contention particularly relevant (`profile-invocations.txt:2`).

## 5. Engine-side costs paid unnecessarily

The current corpus’s instrumented VM budget is small:

| Native VM operation group | Total |
|---|---:|
| Content read/write | 0.912 s |
| Param2 read/write | 0.704 s |
| Light read/write | 1.103 s |
| `calc_lighting` | 0.450 s |
| `set_lighting` | 0.008 s |
| `update_liquids` | 0.071 s |
| Area lookup | <0.001 s |
| **Total** | **3.248 s** |

This is **4.1% of emerge wall time**. Native v7 generation adds approximately 2.910 s outside the Lua writer.

**Lighting bounds do not mean what a superficial API reading suggests.** The writer already passes a bounded region and limits above-water shadow scanning. However, the binding passes the *full VM bounds* separately to native `calcLighting`; sunlight uses the supplied region, while `spreadLight` scans the full emerged volume. Sources: [l_mapgen.cpp:2001](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:2001), `engine/src/mapgen/mapgen.cpp:466`, `512`; `wp40/r6_settlement.lua:3390`.

Narrowing the Lua arguments therefore does not eliminate the full spread scan. Conversely, changing propagation/restoration bounds can change light bytes. Removing **discarded shadow lighting**, discussed in §1, has a much stronger case than weakening final lighting.

**Buffer reuse avoids allocation, not traversal.** `get_data` and `set_data` still marshal every emerged voxel. Param2 and light accessors behave similarly. See `engine/src/script/lua_api/l_vmanip.cpp:92`, `117`, `259`, `308`.

The current writer already conditionally skips content/param2 setters and light/liquid work. Param2 cannot simply be assumed zero: preserved native content and previously generated halo structures can carry meaningful values.

**Liquid queue updates are cheap, but consequential.** The Lua binding scans the full VM when called. Final map commit also processes the chunk’s liquid queue synchronously; deferring periodic liquid updates does not disable this path. Sources: `engine/src/script/lua_api/l_mapgen.cpp:1980`; [servermap.cpp:291](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/reference_projects/luanti/src/servermap.cpp:291).

Thus:

- Stopping redundant Lua checks after establishing the same dirty result is a good optimisation.
- Removing the eventual `update_liquids` call can change resulting fluid behaviour and bytes for a saving of only about 71 ms over this corpus.

**There is no `write_to_map(false)` opportunity.** The callback already relies on automatic engine commit. Explicit `write_to_map` is prohibited in a mapgen environment (`engine/src/script/lua_api/l_vmanip.cpp:147`).

**Other secondary opportunities**

- Avoid copying shadow content/param2 buffers back and forth through an adapter interface when direct transaction buffers can satisfy the same contract.
- Clear only actually used intent regions, with careful generation tagging, instead of resetting every halo entry.
- Deduplicate target preflight by distinct role/Y/aux requirements.
- Preserve full final light restoration unless equivalent native range operations are introduced.

These target Lua memory traffic. Their savings are smaller than the liquid-neighbour and coast-classification findings. Removing native caves, ores, lighting or heightmap processing without equivalent replacement would change output or invalidate preservation decisions.

## 6. Measurement method and representativeness

**The current corpus measures fresh-server startup plus exploration.**

The declared ten owners cover three adjacent pine owners, a capital, front, battleground, crossing, channel, island and deep slice (`tools/wp40/profile/probe/cases.lua:4`).

At the same time, the game automatically emerges six start areas, each **128×128 horizontally**, extending **24 nodes below and 80 above the spawn**, with two requests active at once. See [starts_preload.lua:19](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/mods/CORE/grug_core/starts_preload.lua:19) and `296`.

The probe starts its elapsed clock during load and counts all generated callbacks, not just callbacks belonging to its current request (`tools/wp40/profile/probe/init.lua:75`, `78`, `268`).

Existing logs show:

- **97 generated owners**, only ten belonging to the explicit owner set.
- **87 other owners** account for 16.165 s of baseline writer time and 43.923 s of plateau-441 writer time.
- The second and third explicit pine requests generate **zero new mapchunks**, yet wait approximately **12.56 s and 15.74 s** while other queued work proceeds.
- The first three requests finish around the completion of the start preloads.

This is meaningful evidence for first-start provisioning. It is not a clean estimate of ordinary wilderness generation, nor 97 independent samples from the ten selected places.

It also overweights settlement/start geometry and upper slices, includes only one seed and one deep owner, and does not establish worst-case coast, resource or multiplayer exploration performance.

**The single most useful noise reduction**

Replace the reused historical baseline with **five fresh paired comparisons**, alternating A→B and B→A order. Report the paired ratios, their median and dispersion. Do not compare several new variants exclusively with one old baseline.

The observed approximately ±6% differences are not a statistical confidence interval; five pairs cannot be promised to meet a 3% acceptance threshold. If the interval still spans the threshold, the result remains inconclusive.

Keep engine image, snapshots, seed, request order and host conditions fixed. CPU affinity, avoiding a busy SMT sibling, and recording frequency/load are useful controls; setting a governor alone does not control shared-cache or memory contention.

**Separate the two products being measured**

Retain a clearly labelled fresh-start measurement, including preloads. Add a separate steady-state exploration measurement after preload and initialization quiesce, using fresh owners outside those regions. Warm-up must not generate the owners later used as timed cold-generation cases.

Finally, the recorded performance runs had **`full_digest=false`**. Their 370 sampled positions do not establish complete byte equality. Even the optional full digest currently covers ten owners—**5.12 million voxels**—while 97 callbacks process **49.664 million owner voxels**. A byte-preserving performance gate should canonically hash every generated owner after timing, including content, param2 and light, and compare persistence after reload.

The existing digest design and its scope are documented at [profile/README.md:48](/home/jan/projects/grudgelands/.claude/worktrees/r9-perf-explore/tools/wp40/profile/README.md:48).

## Recommended order of work for WP48

1. **Establish a trustworthy comparison.** Preserve the current engine/snapshot identities, separate startup from exploration, enable full output verification, and use fresh alternating pairs. Add coarse writer-stage attribution only to diagnostic runs; instrumentation can change JIT traces.

2. **Add the two liquid-column short-circuits.** This is the smallest implementation change with a demonstrated mechanism and strong synthetic evidence. Preserve dirty results, final buffers and liquid calls.

3. **Retain multiple lattice tiles, then memoise classification.** Measure these separately. Preserve all classification tuple fields, nil results, world-grid anchors and tie-breaking. Bound memory and check cache eviction/order independence.

4. **Suppress discarded inner R5 lighting through an explicit composition contract.** Keep the outer combined lighting transaction and equivalent required validation.

5. **Only then introduce changed-interval replay and dirty-region tracking.** Cover successor cancellation, cave-preserved param2, liquids, ignore halos and light restoration. Avoid another optimisation limited to the initial clear loop.

6. **Evaluate two and four emerge workers as a separate change.** Update every thread-count contract coherently; require reordered adjacent/vertical-owner equivalence and measure initialization, memory and throughput separately.

7. **Treat broader cave coverage as a design/output change.** Keep it outside the byte-preserving performance package. Prefer a bounded fill-only prototype over immediately restoring the rejected plateau.

Implementation validation should follow the repository’s interpreter strategy: LuaJIT development/exhaustive runs, plain-5.1 parser/static gates, then one compact final-byte PUC-5.1 micro-KAT and the same fixture under LuaJIT with identical canonical digest. No intermediate exhaustive PUC runs are needed.

## Open questions

- **Missing planning context:** this checkout’s `TODO-round9.md` stops at ruling 20; the requested §4.30–§4.36 and BACKLOG WP48 are absent. Later decisions are represented here through the user brief and lane notes, not a reviewed WP48 contract.
- **Incomplete production fixture:** the R7 analytic fixture failed first on missing `default:shovel_wood` override support, then on `beds:bed_bottom` after an in-memory stub experiment. Successful measurements therefore used R6 runtime fixtures; they do not validate the complete production R7 boundary.
- **Exact engine identity:** logs identify Luanti 5.17.0 and LuaJIT `2.1.1784272936`; local analytic probes used LuaJIT `2.1.1767980792`. The measured executable’s exact relationship to the reference commit remains unverified.
- **Remaining attribution:** phase timings and modified-voxel/run counts are needed to explain plateau 200 versus 441, and to turn the proposed savings ranges into corpus measurements.
- **Parallel correctness:** the pinned v7 unfinished-slice warning remains an unresolved obstacle to claiming byte-identical multithreaded output.
- **Acceptance scope:** voxel equality, dirty-operation equality and failure/validation behaviour should be distinguished explicitly when removing redundant checks.

**User-run runtime test plan:** after implementation, compare fresh-world cold generation and disk reload with complete owner digests; inspect capitals, wide coasts, cave roofs, chunk seams, sunlight and water. Test reordered adjacent and vertically stacked owners before enabling additional emerge threads. Retain the separate real fallback-Lua-5.1 engine check. None of these engine tests was run during this study.