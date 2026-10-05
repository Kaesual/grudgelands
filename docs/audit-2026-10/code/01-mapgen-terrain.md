# C1 — Mapgen wp40, terrain side

**Scope.** `mods/MAPGEN/grug_mapgen/` top level (`init.lua` 66, `jit_tuning.lua`
20, `world_nodes.lua` 171, `poi_displays.lua` 18, `wp43_handoff.lua` 355) and the
terrain side of `wp40/` (37,922 Lua lines in total): the loader and IPC
(`r7_loader.lua` 441, `r7_mapgen.lua` 93, `r7_runtime.lua` 772, `r5.lua` 211,
`r6.lua` 309, `r7_successor.lua` 139), the column source (`zones.lua` 1,679,
`height.lua` 2,244, `simple_map.lua` 870, `zone_field.lua` 939,
`terrain_field.lua` 1,077, `water_layout.lua` 2,338), the planners
(`planner.lua` 1,042, `r6_planner.lua` 808), the VM writer
(`r6_settlement.lua` 3,886, `map_adapter.lua` 1,301), content and vegetation
(`r6_content.lua` 919, `r6_hash.lua` 229, `r6_templates.lua` 413,
`habitat_registry.lua` 403, `r7_p9g.lua` 675, `world_content.lua` 229,
`world_content_catalog.lua` 58), and `air_chunks.lua`, `preparation_source.lua`,
`preparation_identity.lua`, `layout_cache.lua`, `r7_native.lua` (ores).

**Baseline.** `0f169898` (main). `git diff --stat 0f169898 -- mods/MAPGEN` is
empty: nothing in scope changed during the review.

**Method.** Read in full: the loader chain (`init.lua` → `r7_loader.lua` →
`r7_runtime.lua` → `r6.lua`/`r5.lua`), the emerge callback `r7_mapgen.lua`,
`air_chunks.lua`, `r6_planner.lua`, `planner.lua`, `map_adapter.lua`
(construction and apply), `r6_settlement.lua` (helpers, construction, the
whole `apply_impl`; the evidence-only `scan_census_cube` /
`scan_horizontal_owner` skimmed), `zones.lua`, `height.lua`, `r7_p9g.lua`,
`world_content.lua`, `r7_successor.lua`, `preparation_source.lua`,
`layout_cache.lua`, `r6_hash.lua`, the surface selector of `r6_content.lua`
(lines 560–905). Skimmed: `terrain_field.lua` (simplex, octaves),
`zone_field.lua` (sample path), `simple_map.lua` (classification, exclusion
shapes), the water sampler of `water_layout.lua` (lines 2009–2337),
`r7_native.lua` (ore rows), `r6_templates.lua` (probability draw), `index128.lua`
(footprint query). Engine facts checked in `reference_projects/luanti`
(`src/emerge.cpp:742-757`, `src/script/lua_api/l_vmanip.cpp:111`).

**Measurements** (LuaJIT 2.1, scratch dir, idle priority, no engine; the
portable world `tools/r28_zone_atlas/world.lua` seed 1 with the real
`zones.lua` planner source, the real `r6_content.lua` surface selector over the
synthetic contract of `tools/r23_tree_line/harness.lua`, the real R5 planner,
R5 adapter and R6 planner). Numbers are comparisons, not targets:

| What | Result |
|---|---|
| `column_values_at`, 6,400 owner columns, all caches cold | 45–110 ms (land, start, capital chunk) |
| same, the 144 × 144 area the R6 planner's halo touches | 167–305 ms |
| owner recompute after column-cache eviction, height memo warm | 13 ms |
| 5 × 5 chunk columns in ring order: column-cache misses per owner column | 1.79 with the halo, 1.04 without; 69 vs 45 ms per chunk column |
| 9 × 9 chunk columns, R6 planner incl. column source | 140 ms per chunk column; 1.32 misses per owner column |
| one R6 decoration cell (`build_cell`, land) | 2.1 ms (0.5 ms on sea) |
| R6 `plan_slice`, first chunk of a land column / a stacked chunk | 140–151 ms / 7–13 ms |
| candidates in a land plan with the root outside the owner | 45–48 % |
| `select_surface` over 6,400 columns | 19–23 ms first, 4–9 ms repeat |
| `r6_hash.digest` (C SHA-256 via ffi, as `core.sha256`) | 0.5 µs per call |
| R5 `plan_slice` / R5 adapter `apply` (fake VM), surface chunk | ~3 ms / 34–38 ms (27–33 ms with the replay pass cut out) |
| `r6_settlement` buffer reset (7 × 1.4 M) / owner diff scan (512 k) | 2.5 ms / 1 ms |
| column-cache hit path (`zones.lua:1410`) vs plain lookup | 49 ns vs 13 ns per call |
| `surface_mob_level_at` over 6,400 columns | 2.7–5.6 ms |
| Lua heap: bounded query caches after 81 chunk columns | +81 MiB (column cache, height memo, field memos), +8 MiB R6 cell cache |
| eleven retained 1.4 M-entry Lua arrays | 176 MiB |

**Out of scope.** Settlements, capitals, start towns, POIs, roads, arenas and
blueprint placement (`r7_settlement.lua`, `capital_planner.lua`,
`road_layout.lua`, `road_writer.lua`, `r7_anchor_*`, `r1x/r2x/r3x_*` blueprints:
lane C2), the wp13 library (lane C3), runtime renewal in `grug_farming` (items
lane). I note where the terrain pipeline calls into them.

## Summary

- **One chunk is one transaction.** `r7_mapgen.lua:81-93` runs, per generated
  80³ chunk, `session.plan_slice` (R5 run planner `planner.lua`, then the R6
  decoration planner `r6_planner.lua`, then the R7 successor's `plan_slice`)
  and `writer.apply` = `r6_settlement.lua` `apply_impl`, which copies the VM,
  runs the R5 adapter on a shadow VM, then the surface skin, P7 surface, strata,
  fill layers, P8 ores, P9 decorations, the successor (roads, P9G gathering,
  world content, anchors, settlements, arenas) and finally one `set_data` and a
  from-scratch relight. **`r6_settlement.lua` is the terrain VM writer**, not a
  settlement module; towns live in `r7_settlement.lua`.
- **Everything is a pure function of (seed, x, z)**, recomputed independently
  in main and in emerge. The only per-world state that crosses is the layout
  texts (water, roads, capitals) in the `ipc_set` payload and the world-folder
  layout cache. The column source is `zones.lua` `planner_source.column_values_at`
  (a 20-value tuple) over `height.lua` (fitting, shore, roads, inland water)
  over `simple_map.lua`/`zone_field.lua` (classification) and
  `terrain_field.lua` (noise).
- **Where the time goes** (measured parts above, per chunk column of a fresh
  land area): column source 45–110 ms cold (halo-inflated to ~1.3–1.8× misses),
  R6 decoration cells ~50 ms inherent (2.1 ms × 25 owner cells) plus the
  halo, the R5 adapter ~30 ms per surface chunk, `select_surface` passes
  5–20 ms each, plus unmeasured: P8 ores, P9 templates, P9G, the successor,
  relight (~10 ms per the Round 22 D65 record) and the engine's
  `get_data`/`set_data` marshalling of 1.4 M entries per array. With
  `num_emerge_threads = 1` pinned, this per-chunk cost is the exploration
  throughput of the whole server.
- **Caches are bounded but big**: column cache 65,536 rows (`zones.lua:1302`),
  height memo 48 chunk blocks × 27 tables (`height.lua:88`, `:610`), field and
  classification memos 65,536 slots each, R6 cell cache 4,096 cells
  (`r6_planner.lua:608`). Together ~90 MiB once full, plus ~220 MiB of
  retained full-volume buffers (MGT-06).
- **Fail-closed everywhere**: about 350 `fail()` calls in the per-chunk
  modules. An error in `on_generated` is a fatal server error
  (`emerge.cpp:745-747`), and the seed fleet never runs the per-chunk path
  (MGT-01).
- **Chunk borders**: the writer writes only its 80³ owner. Decorations that
  would cross it are rejected (MGT-03); the surface skin reads the VM shell and
  so depends on generation order (MGT-09); supports below the owner come from
  an analytic mirror of the R5/P7 rules (MGT-08, MGT-10).
- **Two parallel rule copies must stay in step**: the R5 planner's runs and the
  `analytic_*` replay in `r6_settlement.lua:1554-1727`; and the runtime
  assembly in `r7_runtime.lua` and its six tool mirrors (MGT-07).

## Findings table

| ID | Sev | Category | Title | Location |
|---|---|---|---|---|
| MGT-01 | Medium | Agent-trap | Any per-chunk tripwire stops the server, and no seed run exercises the per-chunk path | `r7_mapgen.lua:81-93`, `planner.lua:863-865`, `r6_planner.lua:413-418` |
| MGT-02 | Medium | Perf | The R6 decoration planner builds a 2-cell halo whose candidates the writer never places | `r6_planner.lua:206-209`, `:679-706`; `r6_settlement.lua:3142-3144` |
| MGT-03 | Medium | Legacy | Owner-only writes drop every tree that crosses a chunk border: grid and contour stripes without trees | `r6_settlement.lua:3205-3210` |
| MGT-04 | Medium | Perf | Surface-only passes run in every chunk, also far below or above the surface | `r6_settlement.lua:148-214`, `r6_planner.lua:656-678`, `world_content.lua:95` |
| MGT-05 | Medium | Perf | P9G repeats its whole 2-D scan in every vertically active chunk and asks the analytic surface once per row | `r7_p9g.lua:467-520`, `:280-297` |
| MGT-06 | Low | Perf | The emerge environment retains ~220 MiB of full-volume buffers, two of them pure shadow copies | `r6_settlement.lua:1197-1214`, `map_adapter.lua:548-549`, `planner.lua:556-561` |
| MGT-07 | Medium | Duplication | The runtime assembly is copied into six tool harnesses; the seed fleet depends on one copy | `tools/r28_zone_atlas/world.lua` and five more |
| MGT-08 | Medium | Agent-trap | The analytic R5/P7 mirror duplicates the planner's seal and surface rules | `r6_settlement.lua:1554-1727`, `planner.lua:747-911` |
| MGT-09 | Low | Bug | The surface-skin opening reads the VM shell: emerge-order dependent at chunk borders | `r6_settlement.lua:34-73`, `:2603-2627` |
| MGT-10 | Low | Bug | A plant rooted on a lower chunk's surface ignores a skin opening there | `r6_settlement.lua:3211-3219`, `r7_p9g.lua:351-356`, `world_content.lua:61-64` |
| MGT-11 | Low | Perf | Decoration placement builds every template cell and draws every probability before the cheap rejections | `r6_settlement.lua:3146-3240` |
| MGT-12 | Low | Legacy | The R5 adapter runs on a shadow VM with a second resolve pass and a full-run prewarm | `map_adapter.lua:986-999`, `:1107-1208`; `r6_settlement.lua:2512-2541` |
| MGT-13 | Low | Perf | The column-cache hit path validates and `unpack`s on every call | `zones.lua:1410-1421` |
| MGT-14 | Low | Legacy | Evidence, capture and replay machinery no tool uses still lives in the production modules | `r7_runtime.lua:425-633`, `r6.lua:90-291`, `r6_settlement.lua:3529-3673` |
| MGT-15 | Low | Agent-trap | "Disabled" headers, R-number names and dual-meaning fields mislead | `r5.lua:1`, `r6.lua:1,25`, `planner.lua:1`, `world_content_catalog.lua:24-36` |
| MGT-16 | Low | Duplication | Small helpers copied per module (P9G digest, heap sort, seed phase, steep memo) | `r7_p9g.lua:75-88`, `r6_planner.lua:447-467` |
| MGT-17 | Low | Legacy | Surface-cave planning is dead code behind an always-nil query and an undocumented setting | `zones.lua:157-160`, `r6_settlement.lua:1028-1033` |

## Findings

### MGT-01 Any per-chunk tripwire stops the server, and no seed run exercises the per-chunk path
- **Severity** Medium / **Category** Agent-trap (bug-prone) / **Confidence** Verified (engine path and test coverage); no tripwire is known to fire today.
- **Location:** `r7_mapgen.lua:81-93`; examples `planner.lua:863-865`, `r6_planner.lua:413-418`, `r6_settlement.lua:1576-1578`, `:3073-3075`, `r7_p9g.lua:538-540`; engine `reference_projects/luanti/src/emerge.cpp:745-757`.
- **What:** the per-chunk modules carry about 350 `fail()` calls (`r6_settlement` 97, `map_adapter` 71, `zones` 68, `planner` 62, `r7_p9g` 35, `r6_planner` 21): bounds (`candidate bound exceeded`, `resource frontier bound exceeded`), tripwires (`sealed water column outside river_water_in`), and identity checks re-run per chunk. A `LuaError` in `on_generated` reaches `m_server->setAsyncFatalError(e)` (`emerge.cpp:747`): the whole server stops. `tools/seed_fleet/seed.lua` builds only the load path (`tools/r28_zone_atlas/world.lua`, up to the anchor roster). It never runs `plan_slice` or the writer. The per-chunk path is exercised only by engine runs on a few areas and seeds. `planner:plan_slice`, `settlement:apply` and `adapter:apply` also wrap their core in `pcall` and rethrow with `error(result, 0)` (`r6_planner.lua:733-736`, `r6_settlement.lua:3803-3806`, `map_adapter.lua:1257-1261`), which drops the traceback.
- **Impact:** a rare-geometry case on an untested seed or a far corner of the map ends the session for every player when someone walks there, and the log gives only a message without a stack. A new agent adding a `fail()` to the per-chunk path is adding a server crash.
- **Better:** (1) add a per-chunk smoke to the seed fleet: plan and settle a few hundred owners per seed (corners, coasts, river mouths, capital edges) against a fake VM, as the R5 adapter probe above did. That costs a few seconds per seed (M). (2) keep the tracebacks: use `xpcall` with `debug.traceback` in the three wrappers (S). (3) Jan should decide whether production should log and leave a chunk native v7 instead of crashing. The transaction writes nothing before its last validation, so a failed chunk stays as v7 made it. That is visibly wrong terrain but no stall. This is a design decision.
- **Verification (phase 2):** Confirmed — `fail()` raises `error(code .. ": " .. message, 0)` without a position (e.g. `r6_planner.lua:18-20`), the three wrappers rethrow with `error(result, 0)` (`r6_planner.lua:733-736`, `r6_settlement.lua:3803-3806`, `map_adapter.lua:1257-1261`), a `LuaError` in `on_generated` reaches `setAsyncFatalError` (`emerge.cpp:745-747`), and `tools/seed_fleet/seed.lua` only loads `r28_zone_atlas/world.lua` and checks tributary joins, with no `plan_slice` or `apply`. Re-grep gives 346 `fail(` calls in the six modules (planner 54, plus 8 other `*fail(` forms), many of them construction- or fixture-only, so fewer than 350 lie on the per-chunk path; same mechanism as MGS-02, and the two smoke proposals should become one fleet extension.

### MGT-02 The R6 decoration planner builds a 2-cell halo whose candidates the writer never places
- **Severity** Medium / **Category** Perf / **Confidence** Verified (dead output traced; cost measured)
- **Location:** `r6_planner.lua:206-209` (halo from the largest template), `:679-706` (9 × 9 cells copied per chunk); `r6_settlement.lua:3142-3144` (only roots inside the owner are placed).
- **What:** owners are 16-aligned (min = −32 + 80k), so a chunk owns exactly 5 × 5 decoration cells. `plan_slice_core` builds or copies `floor(min/16) - halo .. floor(max/16) + halo` with `halo = 2`, i.e. 81 cells. The writer's P9 loop places only `root_x/root_z/root_y` inside the owner and reserves occupancy only for accepted candidates. A grep of `candidate_values` and `candidate_cell_*` finds no other runtime reader (only the evidence fixture). Halo candidates therefore never change a byte, and removing them leaves the output identical: cells are independent and the owner cells keep their relative order.
- **Impact:** measured on seed 1: the first chunk of a land column costs 140–151 ms in `plan_slice`, of which 56/81 of the cell builds are halo. The halo pulls the column source over 144 × 144 instead of 80 × 80 (167–305 ms cold instead of 45–110 ms). The 65,536-row column cache then holds barely three halos: 1.79 misses per owner column in a 5 × 5 ring (1.04 without the halo, 69 vs 45 ms per chunk column) and 1.32 in a 9 × 9 raster. Every stacked chunk also copies ~800 candidate rows of 14 numbers and the P9 loop scans them four times. At the exploration frontier, cells of chunk columns that are generated much later or never are built anyway.
- **Better:** in runtime mode set `halo_x, halo_z = 0, 0` (keep the halo for the evidence constructor if it is still wanted). S effort. Check: one engine profile pair (`tools/wp40/profile`) with identical full-corpus digests, as the R9 comparison procedure prescribes. Expected: planner and column-source time down by roughly a fifth to a third, and the first-chunk spike down about 3×.
- **Verification (phase 2):** Partly confirmed — the dead output holds: a cell's roots are its own 16 × 16 columns (`r6_planner.lua:374`, `:562`), owners are 16-aligned, the P9 loop skips out-of-owner roots without side effects (`r6_settlement.lua:3142-3144`), and the contract itself calls the halo "outcome-inert" diagnostic coverage (`wp40-simple-map-r6-contract.md:735-740`); re-run with the real R6 planner, halo 2 against a patched halo 0, the owner-root candidate sequences matched in 131 of 131 chunk columns (seed 1, three areas, ~38 k candidates). The cost is overstated, because the lane's 5 × 5 model re-swept the 144 × 144 halo for every column and ignored the cell cache: in ring order with the real planner and the R5 reach sweep, halo 0 saves 6–25 % (151 → 142 ms per chunk column over 9 × 9, 168 → 143 and 168 → 126 over 5 × 5), the first-chunk `plan_slice` is 1.3–1.8× (not ~3×) and misses are 1.31–1.33 against 1.06–1.07 per owner column; still a byte-identical S fix, Medium stands.

### MGT-03 Owner-only writes drop every tree that crosses a chunk border: grid and contour stripes without trees
- **Severity** Medium / **Category** Legacy (visible in play) / **Confidence** Verified (rule), Plausible (visibility)
- **Location:** `r6_settlement.lua:3205-3210` (`clipped_owner`), contract `docs/research/wp40-simple-map-r6-contract.md:720-733`.
- **What:** a decoration is accepted only if its whole rotated template box lies inside the 80³ owner of its root. Templates: `emergent_jungle_tree.mts` 7 × 37 × 7 with `offset_y_minus_4` (rows −4..32), `jungle_tree` 5 × 17 × 5, `pine_tree` 5 × 16 × 5, `aspen_tree` 5 × 14 × 5, `acacia_tree` 9 × 9 × 9. A root survives only if `min_y + 4 <= root_y <= max_y - 32` for the emergent tree: 44 of 80 heights, and 74 of 80 positions per horizontal axis. The budget is fixed per 2-D cell before the rejection, and rejection has no retry.
- **Impact:** about 45 % of emergent jungle trees and 20–30 % of the other tall trees are lost. The loss is not spread out. No tall tree roots on terrain within its height below every chunk top (y ≡ 47 mod 80: for emergent trees, ground at y 15..46, 95..126, …), which makes contour bands on jungle and pine hillsides. There is also a 2–4-node treeless line along every 80-node x/z chunk border in dense forest. The contract calls the loss "expected and may be material". Whether players notice is a question for Jan.
- **Better:** Luanti's own decorations solve this by writing into the 16-node shell. Here the acceptance tests read VM content (clearance, occupancy), which is why the owner rule exists. With today's knowledge: make a tree's acceptance a pure function of the plan (2-D cell, planned terrain, exclusions, other planned trees), then let every chunk write the part of each accepted tree that intersects its owner. The tree is then the same whatever the generation order. L effort; it changes the world, so it needs a seed fleet run and an engine pair.
- **Verification (phase 2):** Confirmed — `clipped_owner` tests the whole rotated box with no retry (`r6_settlement.lua:3205-3210`), and the emergent tree's box is y −4..32, 7 × 7 centred (`r6_templates.lua:311-326`, schematic 7 × 37 × 7); the R6 artifact measured 746 `clipped_owner` of 1,599 emergent candidates (47 %) and 27 % for `jungle_tree` on seed 1 (`docs/research/wp40-simple-map-r6-artifact.tsv`). The contract accepts the loss (`wp40-simple-map-r6-contract.md:724`), but neither it nor AGENTS.md mentions the bands. Two small corrections: the rejected emergent ground band is y ≡ 15..50 mod 80, because the next chunk's bottom four rows are also rejected; and runtime renewal (`grug_farming/renewal.lua`, `grug_tree_regrowth` on by default) may slowly refill the deficit with saplings, but only near players.

### MGT-04 Surface-only passes run in every chunk, also far below or above the surface
- **Severity** Medium / **Category** Perf / **Confidence** Verified (code paths), measured per pass
- **Location:** `r6_settlement.lua:148-214` (`r8_apply_strata`), contrast `:456-458`; `r6_planner.lua:656-678` (`column_tuple` with `select_surface` for all 6,400 columns); `world_content.lua:95`.
- **What:** `r8_apply_strata` runs `static_exclusion_values_at`, possibly `protected_only_floor_at` and `select_surface` for every owner column, then loops depth 41..40 and drops every y below `floor_y = -37`. It has no early return. The fill-layer pass beside it has one (`bottom > max_y`, `:458`). The R6 planner computes the full surface tuple (`select_surface`, exclusions, `surface_cave_run_at`) for every column of every chunk. Only P7 (terrain within the owner), dust and the P9G vertical check read it. `world_content.lua:95` computes `surface_mob_level_at` for every non-excluded land column before testing whether `ground + 1` lies in the chunk.
- **Impact:** underground chunks are a large share of all chunks generated around a surface player (view range reaches below the surface). Each one pays about one warm `plan_slice` (7–13 ms), one strata pass (`select_surface` 4–9 ms, exclusions ~1 ms) and 3–6 ms of zone levels for nothing. That is ~20 ms per deep chunk, ~5–10 % of the per-chunk budget.
- **Better:** (a) `r8_apply_strata`: return when `max_y < floor_y` or when `min_y > terrain_max` (S, byte-identical). (b) `world_content`: move the level lookup inside the `y` check (S). (c) `r6_planner`: compute `select_surface` only for columns whose `terrain_y - filler_depth .. terrain_y + 1` meets the owner, or make the surface refs lazy for P7 (M). Each step can be verified by an identical-digest engine pair.
- **Verification (phase 2):** Confirmed — `r8_apply_strata` has no early exit, calls `static_exclusion_values_at` and `select_surface` for every owner column and then discards every y (`r6_settlement.lua:148-214`, called unconditionally at `:2814`), while `r24_apply_fill_layers` returns at `:458`; `world_content.lua:95` computes the level before the `y` test at `:96-97`, and `r7_mapgen.lua:88` skips only air chunks above the surface. The ~20 ms per deep chunk adds up parts measured elsewhere; nobody measured a deep chunk directly.

### MGT-05 P9G repeats its whole 2-D scan in every vertically active chunk and asks the analytic surface once per row
- **Severity** Medium / **Category** Perf / **Confidence** Verified (structure), Plausible (magnitude, not measured)
- **Location:** `r7_p9g.lua:467-520` (12 rows × 25 cells × 256 columns per active chunk), `:280-297` (`analytic_p7_ref` per row), `:81-88` (digest per eligible column).
- **What:** P9G's eligibility, rank digests and budget are a pure function of the 2-D cell ("The fixed 2-D budget prefix is shared by every vertical callback", `:533-535`). Yet every chunk whose y range holds any root rescans all 6,400 columns for all 12 rows. For each column in a zone the row lists, it calls `analytic_p7_ref` (surface selector, hydrology seal) once per matching row. The decoration planner solved the same problem with its cell cache (`r6_planner.lua:601-640`); P9G has none.
- **Impact:** hills and mountains put the surface into 2–3 vertical chunks per chunk column. Each repeats ~3 × 6,400 analytic surface queries (one `select_surface` pass costs 4–9 ms measured) plus a SHA per eligible column. Estimated 20–40 ms per active chunk.
- **Better:** cache the per-cell ranked and budgeted prefix like `cached_cell_rows` (bounded FIFO), and memoise `analytic_p7_ref` per column within one settle. Byte-identical. M effort.
- **Verification (phase 2):** Confirmed — once `vertical_active` is set (any owner column's root in the y range, `r7_p9g.lua:384-397`), `settle` rescans all 25 cells × 256 columns for each catalog row and digests every eligible column (`:480-506`), and `geographic_reason` calls `analytic_p7_ref` after the zone, biome and shore tests (`:280-297`). There is no per-cell cache. The 20–40 ms remains an unmeasured estimate: the zone test runs first, so the analytic count depends on how many rows a zone lists.

### MGT-06 The emerge environment retains ~220 MiB of full-volume buffers, two of them pure shadow copies
- **Severity** Medium / **Category** Perf (memory) / **Confidence** Verified (sizes computed; the array cost measured)
- **Location:** `r6_settlement.lua:1197-1214` (ten `MAX_VOLUME = 112³` arrays), `:1232-1233` (512 k), `map_adapter.lua:548-549` (two more 112³), `planner.lua:556-561` (`run_values` 198,400 × 9), `r6_planner.lua:213-218` (`MAX_CANDIDATES × 14 = 917 k` although runtime uses at most 16,384 candidates).
- **What:** a 1.4 M-entry Lua array sits in a 2²¹-slot array part, 16 MiB each. Eleven of them measured 176 MiB in LuaJIT. Counting the R5 run buffer and the oversized R6 candidate buffer, the emerge environment holds ~220 MiB of retained buffers before any cache. The adapter's `data_buffer`/`param2_buffer` exist only to receive `shadow.get_data` copies of `original_data` and to be copied back into `final_data` (`r6_settlement.lua:2514-2527`). Measured on top: the bounded query caches fill to ~81 MiB (column cache, height memo, field memos) plus ~8–14 MiB of R6 cells after ~80 chunk columns.
- **Impact:** this explains most of the "630–745 MiB live, grows with generated chunks" that `docs/research/perf-review-2026-10-r32.md` R5 left open. It grows until the bounded caches are full, then stays flat. It is not a leak, but it costs 2.9–3.3 GB resident in total.
- **Better:** let the adapter read and write `final_data`/`final_param2` directly (−32 MiB and four 1.4 M copies, S–M). Size `candidate_values` by `candidate_capacity` in runtime mode (−6 MiB, S). Allocate `original_light` and the three `intent_*` side arrays lazily or pack them (M). Record the cache budget (column cache, height blocks) in the module guide so the next memory review can account for it.
- **Verification (phase 2):** Partly confirmed, severity changed to Low — the sizes hold. Ten 112³ arrays sit in `r6_settlement.lua:1197-1214` and two in `map_adapter.lua:548-549`, plus R5 `run_values` (198,400 × 9) and the R6 candidates (65,536 × 14), all grown by appending (`counting_allocator.lua:123-125`); these 14 arrays re-measured at 216 MiB in LuaJIT (+4 MiB `resource_host_base`), and the adapter buffers are pure shadow copies (`r6_settlement.lua:2514-2527`). The attribution is overstated: the perf review's 630–648 MiB was taken after a full GC at the first chunk, with the caches nearly empty, which fits ~220 MiB of buffers plus MGS-01's ~410 MiB of settlement cells. The 2.9–3.3 GB is the whole process, and the recoverable part here (adapter −32 MiB, candidates −6 MiB, lazy side arrays) is roughly 40–100 MiB of ~3 GB.

### MGT-07 The runtime assembly is copied into six tool harnesses; the seed fleet depends on one copy
- **Severity** Medium / **Category** Duplication (Agent-trap) / **Confidence** Verified
- **Location:** `tools/r28_zone_atlas/world.lua`, `tools/r27_minimap/world.lua`, `tools/r26_capitals/world.lua`, `tools/r25_road_poi/world.lua`, `tools/r25_capital_plots/harness.lua`, `tools/r23_tree_line/world_source.lua`; all "mirror `r7_runtime.lua`" by hand.
- **What:** the order of construction (water layout, roads, start grounds with `SURFACE_TWIN`, capital planning on a reused height session, canal rows, protection install, zones session, roster) is repeated in each harness. `tools/seed_fleet/seed.lua` builds its world through `r28_zone_atlas/world.lua`.
- **Impact:** a change to the runtime wiring (a new dependency, a reordered step) silently makes the seed fleet and the atlas tools test a different world than the game builds. Agents follow AGENTS.md and trust the fleet's "all seeds build".
- **Better:** expose one pure assembly function from `wp40` (the part of `r7_runtime.lua` up to the zones session) that takes `sha256` and returns the sessions, and have the runtime and every harness call it. M effort; the fleet output must not change.
- **Verification (phase 2):** Confirmed — all six files exist and say they mirror `r7_runtime.lua` (e.g. `tools/r28_zone_atlas/world.lua:8`, `tools/r25_capital_plots/harness.lua:6`), and `tools/seed_fleet/seed.lua` builds its world through `r28_zone_atlas/world.lua`. This duplicates MGS-10 in `02-mapgen-settlements.md`, which rates the same issue Low; consolidation should give both one severity (Medium is defensible, since the fleet is the cross-seed gate).

### MGT-08 The analytic R5/P7 mirror duplicates the planner's seal and surface rules
- **Severity** Medium / **Category** Agent-trap (Duplication) / **Confidence** Verified
- **Location:** `r6_settlement.lua:1554-1602` (`wet_river_at`, `analytic_hydrology_seal`), `:1604-1714` (`analytic_p7_material_ref`, `analytic_r5_material_cid`); `planner.lua:747-911` (`wet_river_at`, `bank_seal_values`, `add_column_candidates`).
- **What:** the real terrain comes from the R5 runs (`planner.lua`) resolved by the adapter, then P7. The decision "is there a natural support here" for P7 bed/bank tops (`:2710`, `:2750`), P9 decoration hosts (`decoration_support_ref`), P9G and world-content plants whose support lies below the owner comes from a hand-written replay of the same priorities, seal rule and cave runs. The comments say "as in the planner" and "Exact single-voxel replay of the frozen R5 P2-P6 winner".
- **Impact:** a change to `add_column_candidates` (a new run kind, a seal width) that is not mirrored makes plants float or vanish at the bottom row of chunks and on sealed banks, only where the support is analytic. No current check compares the two.
- **Better:** derive both from one rule table: a function returning the column's runs that the planner emits and the analytic path queries. Until then, add a portable fixture that compares `analytic_r5_material_cid` with the planner's resolved runs over a few thousand columns (rivers, anchors, capitals). S for the fixture, M for the merge.
- **Verification (phase 2):** Confirmed — `wet_river_at`/`analytic_hydrology_seal` (`r6_settlement.lua:1562-1602`, "tripwire, as in the planner") and the "Exact single-voxel replay of the frozen R5 P2-P6 winner" (`:1654`) re-implement `planner.lua`'s seal and candidate rules by hand. A grep of `tools/` and `mods/` finds no use of the analytic functions outside `r6_settlement.lua`, so no check compares the two copies.

### MGT-09 The surface-skin opening reads the VM shell: emerge-order dependent at chunk borders
- **Severity** Low / **Category** Bug / **Confidence** Plausible (code traced; frequency not measured)
- **Location:** `r6_settlement.lua:34-73` (`r9_surface_skin_open`: own column depths 1..4 and a 3 × 3 neighbourhood), `:2603-2627` (`native_class_at` and `preserved_native_air_at` read `original_data` anywhere in the emerged area; "Below-owner halo cells are already the committed result of the preceding slice").
- **What:** for owner-edge columns, and for a surface within four nodes above the owner bottom, the decision reads the 16-node shell. A shell block of a not-yet-generated neighbour holds ignore. Per the writer's own light comment (`:1311-1318`), fresh groups hold ignore at the probes. A generated neighbour's shell holds its final content. So the same column opens (a hole into a native cave) or gets a sealed skin depending on which chunk the single emerge thread made first. The code assumes the chunk below is always made first; spiral emerge order does not guarantee that.
- **Impact:** a rare one-node difference at chunk borders: a hole or no hole. Cosmetic, but it breaks "same seed, same world" across play sessions. The profiler's cold/disk digest comparison cannot see it, because both use one order.
- **Better:** decide the opening from immutable inputs only: the planned column tuple, plus native air read strictly inside the owner. Treat neighbour columns outside the owner as "not open". S effort; it changes a few bytes per world.

### MGT-10 A plant rooted on a lower chunk's surface ignores a skin opening there
- **Severity** Low / **Category** Bug / **Confidence** Plausible
- **Location:** `r6_settlement.lua:3211-3219` (support outside the owner: only `decoration_support_ref`), `r7_p9g.lua:351-356` (`analytic_lower_owner`), `world_content.lua:61-64`.
- **What:** when `terrain_y = min_y - 1` (ground at y ≡ 47 mod 80), the root sits in this chunk and the support in the chunk below. The analytic support knows nothing of the R9 opening (`surface_skin_column == 2` writes air at `terrain_y`, `:2682-2688`), which depends on native caves.
- **Impact:** an occasional plant, P9G source or tree floating over a one-node hole on those contour lines.
- **Better:** this goes away with MGT-09 (opening from planned data only). Otherwise let the analytic path ask the same opening predicate.

### MGT-11 Decoration placement builds every template cell and draws every probability before the cheap rejections
- **Severity** Low / **Category** Perf / **Confidence** Verified (structure), Plausible (magnitude)
- **Location:** `r6_settlement.lua:3146-3204` (one table per template cell including air, a SHA draw per cell whose probability is not 0/254), `:3205-3240` (owner, host and exclusion checks afterwards), `:3228-3229` (`exclusion_reason(x, z, …)` once per voxel of the box).
- **What:** for a 9 × 9 × 9 acacia that is 729 tables and up to a SHA per leaf before `clipped_owner` or `wrong_host` rejects the tree. The exclusion is a column property but is asked for every y of the box (×9 … ×37).
- **Impact:** estimated 10–25 ms per forest chunk, plus GC churn in the emerge thread.
- **Better:** run the owner, host and per-column exclusion checks first (exclusion once per x/z), then build only the included cells. Byte-identical. S.

### MGT-12 The R5 adapter runs on a shadow VM with a second resolve pass and a full-run prewarm
- **Severity** Low / **Category** Legacy / **Confidence** Verified, measured
- **Location:** `map_adapter.lua:746-837` (full plan validation per chunk), `:986-999` (prewarm over every run voxel), `:1107-1187` and `:1191-1208` (`resolve_voxel` twice per voxel); `r6_settlement.lua:2512-2541` (shadow VM).
- **What:** these layers are left from the separate R5 contract round. R6 hands R5 a fake VM, R5 validates its own plan again, resolves each voxel once for bookkeeping and once to write, and copies the buffers back.
- **Impact:** measured with a fake VM: 34–38 ms per surface chunk with both passes, 27–33 ms with the replay cut. So 5–10 % of a chunk goes into the adapter's redundancy, and 1,300 lines into its maintenance.
- **Better:** short term, store `final_cid/final_p2` in the first pass and drop the replay and the prewarm (S). Long term, resolve the R5 runs directly into `final_data` inside `r6_settlement` and delete the shadow VM and the duplicate buffers (with MGT-06; L).

### MGT-13 The column-cache hit path validates and `unpack`s on every call
- **Severity** Low / **Category** Perf / **Confidence** Verified, measured
- **Location:** `zones.lua:1410-1421` (`normalize_xz` with `finite_number`/`integer`, then `unpack(row, 1, 20)`).
- **What:** `height.lua:21-23` itself records that `unpack` stops LuaJIT traces. LuaJIT -jv shows `stitch unpack` here. Measured 49 ns per hit against 13 ns for a plain lookup with explicit returns.
- **Impact:** with roughly 100–200 k hits per chunk (planners, writer passes, P9G, world content, steep and shore neighbours), that is ~4–7 ms per chunk.
- **Better:** a `column_values_at_int` for internal callers that already pass integers, returning `row[1] … row[20]` explicitly. Keep the validating entry for external callers. S.

### MGT-14 Evidence, capture and replay machinery no tool uses still lives in the production modules
- **Severity** Low / **Category** Legacy / **Confidence** Verified (grep of `tools/` and `mods/` for `new_evidence`, `new_capture`, `scan_census_cube`, `scan_horizontal_owner`, `arm_private_capture`, `evidence_mode`: only the defining files)
- **Location:** `r7_runtime.lua:425-633` (`evidence_mode`), `r6.lua:90-291` (five construction modes), `r6_settlement.lua:1792-2335` (evidence fixture, census scan), `:3529-3673` (canonical runs, replay), `counting_allocator.lua` (allocation accounting), the R6 planner's `capture_groups`.
- **What:** the retired R6/R8 evidence suites (AGENTS.md: "retired … historical evidence") are gone, but the modes stay in the writer. `r6_settlement.lua` is 3,886 lines; perhaps a third is evidence-only.
- **Impact:** every change to the writer must keep code compiling and consistent that nothing runs. It is the main reason the writer is hard to read. It also keeps closures at Lua 5.1's 60-upvalue limit (`planner.lua:441-444`, `r6_settlement.lua:1334`).
- **Better:** delete the evidence and capture constructors and the replay after Jan confirms the evidence suites will not return (M). Follow fresh-server mode: no compatibility branch.

### MGT-15 "Disabled" headers, R-number names and dual-meaning fields mislead
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
- **Location:** `r5.lua:1` ("Internal, disabled … R7 owns activation"), `:457-466` (`production_enabled = false`), `r6.lua:1`, `:25` (`STATUS = "disabled_r6_surface_resource_content"`), `planner.lua:1`, `zones.lua:1`, `r6_planner.lua:1`, `r6_settlement.lua:2417` ("R6 is disabled" on a wrong call mode); `world_content_catalog.lua:24-36` (`min`/`max` are zone levels for surface rows, world y for cave rows); `r6_planner.lua:157-170` (`surface_y_at_most_32` means "not a mountain zone").
- **What:** the live production path presents itself as disabled. Files are named after contract rounds (R5, R6, R8, R9, R24, R30), not after what they do. `r6_settlement.lua` is the terrain writer.
- **Impact:** new agents misjudge dead and live code and edit the wrong copy.
- **Better:** fix the headers and status strings, and add a one-screen map "file → job" to the module guide. Renaming is optional. S.

### MGT-16 Small helpers copied per module (P9G digest, heap sort, seed phase, steep memo)
- **Severity** Low / **Category** Duplication / **Confidence** Verified
- **Location:** `r7_p9g.lua:75-88` (its own `frame`/`digest`, varargs plus a fresh table per call, beside `r6_hash.lua:73-104`); heap sort in `r6_planner.lua:447-467`, `r7_p9g.lua:179-204`, `r6_settlement.lua:962-994`; the `phase` seed fold in five modules (`r6_settlement.lua:110-113`, `:335-338`, `zones.lua:16-19`, `r6_content.lua:608-611`, `world_content.lua:10-11`); `bspline` in `terrain_field.lua:209` and `water_layout.lua:51`. Two surface selectors (planner, writer) each hold their own 65,536-slot steep memo (`r6_content.lua:734-735`).
- **Impact:** small; risky only where the copies define hashes (a fix applied to one copy changes that module's world).
- **Better:** move the digest frame and heap sort into `r6_hash.lua` (or a tiny shared helper), and share one selector between the planner and the writer. S.

### MGT-17 Surface-cave planning is dead code behind an always-nil query and an undocumented setting
- **Severity** Low / **Category** Legacy / **Confidence** Verified
- **Location:** `zones.lua:157-160` (`run_at` returns nil), `:3-181` (candidate factory still built); `planner.lua:886-907`, `r6_settlement.lua:1611-1612`, `:1692-1693` (branches never taken); `r6_settlement.lua:1028-1033`, `:2845-2867` (R8 mouth writer behind `grug_mapgen_r8_cave_writer_disabled`, default true, absent from `settingtypes.txt`).
- **Impact:** about 400 lines and a per-column call that returns nil. A hidden setting turns on an unreviewed writer path.
- **Better:** remove the R8 mouth writer, the surface-cave factory and the nil branches. Keep `r9_surface_skin_open`, which is live. S–M.

## Hot-path inventory

Per generated chunk (emerge thread, one at a time):

| Path | Runs | Cost class (measured or reasoned) |
|---|---|---|
| `air_chunks.untouched` (`air_chunks.lua:63-73`) | every chunk above y 1 | heightmap scan, cheap; `writer_top` memoised per x/z (64 entries), cold ~12 k `column_bounds` calls once per chunk column |
| R5 `plan_slice` (`planner.lua:950-991`) | every non-air chunk | ~3 ms warm; +12 neighbour tuples per column near rivers |
| R6 `plan_slice` (`r6_planner.lua:642-718`) | every non-air chunk | 7–13 ms warm (`column_tuple` × 6,400 plus a copy of 81 cells); first chunk of a column 140–151 ms (cells 2.1 ms each, SHA rank per eligible column and row) |
| column source cold (`zones.lua:1329-1408` → `height.lua`) | first touch of a column, or after eviction | ~9 µs per column cold, ~2 µs with the height memo warm, 49 ns on a hit |
| successor `plan_slice` (`r7_successor.lua:76-84`) | every chunk | P9G vertical test (cheap); world, anchor and every settlement bind (C2) |
| buffer reset (`r6_settlement.lua:2504-2509`) | every non-air chunk | 2.5 ms |
| R5 adapter (`map_adapter.lua:948-1248`) | chunks with runs (y ≥ −37) | 27–38 ms (two passes), fake VM |
| surface skin and P7 (`r6_settlement.lua:2635-2802`) | every chunk | column loops; cheap below the surface |
| strata (`r8_apply_strata`) | every chunk (MGT-04) | `select_surface` pass 4–9 ms warm |
| fill layers (`r24_apply_fill_layers`) | chunks reaching y ≥ −37 | per voxel below terrain − 41; cheap integer noise |
| P8 resources (`r6_settlement.lua:2881-3132`) | every chunk with host rock | per 16³ cell and tier: two SHA, a Park-Miller draw, a SHA per frontier voxel (≤ 8-node veins) |
| P9 decorations (`:3135-3319`) | chunks holding roots | MGT-11; scans all candidates 4× |
| road dressing, anchors, settlements, arenas | every chunk | lane C2 |
| P9G (`r7_p9g.lua:426-646`) | vertically active chunks | MGT-05 |
| world content (`world_content.lua:69-224`) | every chunk | 3–6 ms zone levels; cave rows ~1.5 ms per 512 k voxels (measured, hash test first) |
| owner diff and classify (`r6_settlement.lua:3684-3740`) | every chunk | ~1 ms scan plus classify on changed voxels |
| `set_data`/`set_param2_data`, relight (`halo.relight`), `update_liquids` | changed chunks | relight ~10 ms (Round 22 D65 record) |
| engine VM marshalling (`l_vmanip.cpp:111`) | every non-air chunk | `get_data`, `get_param2_data` (+ `get_light_data`, `set_*` when changed) each move 1.4 M entries through `lua_rawseti`; not measured, fixed per chunk |

Main environment (per event / at load):

- Load: two full constructions of the runtime (main authority plus emerge runtime). On a layout-cache hit, main still spends 4.2–4.4 s (perf review #22). `init.lua:49-65` runs a full GC at load and empties the query caches at the first step.
- `grug_core` water guard → `init.lua:20-40` predicate: up to five `column_values_at` per liquid transform inside protected territory. Cache-backed; fine.
- Gameplay zone queries (`surface_mob_level_at`, `territory_rule_at`, `terrain_height_at`): 0.4–0.9 µs warm per call (measured for the level). In main the column cache refills on demand after the first-step `drop_caches`.
- Runtime renewal through `vegetation_density.lua` (grug_farming): not reviewed here.

## Bug-prone areas

- **`r6_settlement.lua` `apply_impl`** (`:2411-3794`): about 1,400 lines in one closure at Lua 5.1's upvalue limit. Stages communicate through shared mutable arrays (`occupancy`, `intent_*`), and the order matters (P7 before strata before P8 before P9 before the successor). A new stage is easy to put in the wrong place.
- **Chunk-border semantics:** owner-only writes (MGT-03), shell reads (MGT-09) and the analytic support below the owner (MGT-08, MGT-10). Anything that reads outside `min..max` must be immutable or planned data.
- **Two rule copies:** the planner's runs and the analytic mirror (MGT-08); the runtime assembly and its tool mirrors (MGT-07).
- **Fatal tripwires in the per-chunk path** (MGT-01): the seed fleet does not cover them.
- **`height.lua` memo purity:** column blocks can be evicted mid-computation by neighbour queries (`:1170-1173`, `:1727-1729`). The code survives because every value is pure and recomputed. A non-pure addition (a counter, a lazily fixed reference) would break silently.
- **Determinism:** `x ^ 2` is guarded by sweep 6; `^3`, `^1.4`, `^1.5` (`terrain_field.lua:211`, `:506`, `:542`) are documented as identical in both modes (`docs/research/luanti-lua.md:261`). A new float path inside a trace that LuaJIT folds differently would make main and emerge disagree by a node.

## Noted (no action)

- The native strata rows in `r7_native.lua:400-428` repeat `grug_materials` TIER bounds as literals. The runtime does not cross-check them, but `tools/r24_mining/fixture.lua:843-850` rebuilds the expected rows from `TIERS`.
- `grug_mapgen_r8_native_baseline` (`r7_mapgen.lua:72-74`, `:86`) skips the writer entirely. It is a measurement toggle, absent from `settingtypes.txt`; a copied test config would make native v7 worlds.
- `zones.lua:763-765` flushes the whole front-border cache when it reaches 65,536 entries (a one-off re-walk, not FIFO). Harmless.
- Three horizontal sessions in emerge (zones, height, R6) keep separate 65,536-slot field memos; the cost is a few MiB. The stale-rules review counted 2.28 zone-field samples per column (`docs/research/round22-stale-rules.md` H2).
- `simple_map.lua:17` and `r6_content.lua:594` keep per-seed module-level caches. With one seed per process they never grow.
- `air_chunks.lua` relies on `preparation_source` envelopes. The arena dressing stays within a few nodes of the ground (`arena_writer.lua:62-76`), inside the template reach, so the fast path stays correct (C2 owns the arenas).
- The tripwire `sealed water column outside river_water_in` looks sound: every wet river column lies within its wettest contributing segment's marked reach (`water_layout.lua:2084-2100`, `:2133-2147`).

## Open questions for Jan

1. Have you seen tree-free bands on jungle or pine hillsides (about every 80 nodes of height) or straight tree-free lines in dense forest? (MGT-03 decides whether the L-sized fix is worth it.)
2. If a mapgen check fails in production, should the server stop as now, or log and leave that chunk as native v7 terrain? (MGT-01)
3. Will the WP40 evidence and capture modes ever run again, or may they be deleted from `r6_settlement.lua`, `r6.lua` and `r7_runtime.lua`? (MGT-14)
4. Should the seed fleet also plan and settle a sample of chunks per seed, a few seconds each, so per-chunk checks are covered? (MGT-01)
