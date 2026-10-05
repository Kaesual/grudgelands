# C3: Mapgen wp13 and the wp13/wp40 relationship

**Scope.** `mods/MAPGEN/grug_mapgen/wp13/` (60 files, 31,568 lines), the
top-level `grug_mapgen` files (`init.lua` 66, `jit_tuning.lua` 20,
`poi_displays.lua` 18, `world_nodes.lua` 171, `wp43_handoff.lua` 355), and the
wp40 files that form the seam to wp13: `r7_settlement.lua` (1,651),
`r7_runtime.lua` (772), `r7_loader.lua` (441), `r7_capital_blueprint.lua` (174),
`r7_capitals.lua` (275), `r7_wp13_library.lua` (52), `r7_successor.lua`,
`r7_mapgen.lua`, `r20_civic.lua`, `preparation_identity.lua`, the head of
`preparation_source.lua` and `layout_cache.lua`, the 24 `r7_*_blueprint.lua`
wrappers and the material and sort sections of the three POI builders
(`r14_poi_blueprint.lua`, `r20_poi_blueprint.lua`, `r31_pvp_poi_blueprint.lua`).

**Baseline.** `0f169898` (main). The working tree did not change under the
files I read.

**Method.**
- **Read in full:** `parts.lua`, `palette.lua`, `plot_approach.lua`,
  `city_edge.lua` and `capital_services.lua` in wp13; `r7_settlement.lua`,
  `r7_runtime.lua`, `r7_loader.lua`, `r7_capital_blueprint.lua`,
  `r7_capitals.lua`, `r7_wp13_library.lua`, `r7_successor.lua`, `r7_mapgen.lua`
  and `r20_civic.lua` in wp40; `init.lua`.
- **Read in part:** `decor_kit.lua` (lines 1–260 and 700–1016), the
  `highcourt_districts.lua`/`highcourt_district.lua` heads, the `nhal_veyr.lua`
  head.
- **Checked automatically:** the rest of wp13. The checks were the dofile
  graph, every exported `M.*` against the whole `mods/` and `tools/` tree, the
  `pairs` loops for order dependence, and the KAT mentions.
- **Measured** with `/usr/bin/luajit` harnesses in my scratch directory, on
  the real wp13/wp40 files under a minimal `core` stub: module-load counts,
  build times, rebuild determinism (same instance, second instance, reverse
  order, JIT on and off), retained memory, and the cost of `palette.new` and
  `Buffer:put`. No engine runs.

**Out of scope.** The wp40 world generator itself (height, water, roads,
zones, planner, capital planner, writer internals: lanes C1/C2), except where
the seam needs it.

## Summary

- **Every wp13 file runs at load.** All 60 files are reachable from
  `init.lua`, through `wp40/r7_loader.lua` → `r7_runtime.lua` → the
  `r7_*_blueprint.lua` wrappers, `r7_capital_blueprint.lua`,
  `r7_settlement.lua`, `r7_capitals.lua` and the POI builders. They run in
  **both** Lua environments (main and emerge). There is no dead file. The dead
  code is about 600 lines of generators inside live files (W13-09).
  `grug_traders/vendors.lua` also reads `wp13/capital_services.lua` at server
  load.
- **The split is an old work-package boundary, not an architecture.**
  - wp13 is mostly a pure, engine-free *composition library*: palettes, parts,
    buildings, the start, capital, district and plot builders, and the decor
    kit.
  - But wp13 also holds two **per-chunk runtime** modules, `city_edge.lua` and
    `plot_approach.lua`, and one piece of **game data**, `capital_services.lua`.
  - wp40 holds three whole **composition builders**: the r14, r20 and r31 POIs,
    about 900 lines, each with its own race materials. It also holds a
    **patch** to the wp13 start compositions (`r20_civic.lua`) and 24 wrapper
    files.
- **Compositions must be pure and deterministic.** Main builds every blueprint
  once and hashes it. Emerge rebuilds a lazy blueprint when a chunk first
  touches it and **fails hard** (`r7_settlement.lua:1344-1347`) if the rebuild
  hashes differently. I checked all 6 cores and 304 plots: the rebuild is
  identical in the same instance, in a second instance, in reverse order and
  under `-joff`.
- **Lazy POIs are not actually lazy.** Each one is built at load
  (`r7_runtime.lua:352`), and the descriptor's `build` closure keeps the built
  cell list alive forever (`r7_settlement.lua:780-783`). The same closure
  keeps a second copy of every eager start's cells. Measured, this is about
  214 MiB held only by those closures in the emerge environment (W13-01).
- **Main builds and hashes every composition on every boot**, also on a
  world-layout cache hit. In isolation that is about 3.5–4.3 s under LuaJIT
  (W13-02).
- **wp13 runs on each chunk in three places**, all through
  `r7_settlement.lua`'s `settle` for each of the **135** roster settlements:
  - `palette.new` once per settlement per non-air chunk (W13-07);
  - the capital plot collars (`plot_approach.surface`);
  - the city edge (`city_edge.cells`).
  A lazy rebuild (a composition build plus a re-hash) is a per-event spike of
  about 5–40 ms for a plot and about 0.2 s for a capital core.
- **Fragile spots.**
  - `parts.lua` hand-mirrors registry properties (`PARAM2_KIND`, `SHAPED`,
    `FULL_SOLID`, `PANE_CONNECTS`, `WILD_SOIL`). Its comments say "library_kat
    proves" these tables, but that KAT was retired in Round 22 (W13-03).
  - The capital collar and edge materials are declared in one wp40 file and
    used in another. A mismatch fails only in the emerge thread, at the first
    affected chunk (W13-06).
- **Naming that misleads.**
  - `write_hearthpine` is the writer for every settlement, and errors say
    "Hearthpine identity differs".
  - The `grug_wp13_*` schema strings are part of the identity bytes. They are
    frozen strings, not paths, so a directory rename does not need to touch
    them.
  - Six capital headers say the core spans ±47; it spans ±49.

## File table

"Load" means `init.lua` → `r7_loader` → `r7_runtime` in main, and
`r7_mapgen.lua` → `r7_runtime` in emerge. "Per chunk" means it runs in the
emerge `settle` path.

| File(s) | Loaded at runtime? | Used by | Status |
|---|---|---|---|
| `parts.lua` | yes, both envs, **332× per env** | every composition; `r7_settlement` (turned plots in `cells_of`); `r31_pvp_poi_blueprint` (`rotate_param2`); `r7_capital_blueprint` (`less_bytes`); `city_edge` | live; `less_bytes`, `sort_cells_zyx` and `rot` are duplicated in wp40 (W13-10) |
| `palette.lua` | yes, 56× per env | every composition; `r7_settlement` **per chunk** (`palette.new`, W13-07); `r7_runtime` (start ground band); `r7_capital_blueprint`; `city_edge`; `decor_kit` | live; race materials duplicated in 3 wp40 POI builders (W13-04) |
| `plot_approach.lua` | yes | `r7_settlement` **per chunk** (collars and approaches); `preparation_source` (`rot`, constants); `r31_pvp_poi_blueprint` (`rot`); digested by `preparation_identity` | live runtime helper filed in the library; `rot` = `capital_planner.M.rot` |
| `city_edge.lua` | yes | `r7_capital_blueprint` (names, `make`) → `r7_settlement` **per chunk** (overlay cells); digested by `preparation_identity` | live runtime helper filed in the library |
| `capital_services.lua` | yes, 19× per env, plus once in the server env | `r7_capitals` (required plots); six `*_plot.lua` (`decorate`); `grug_traders/vendors.lua` | live; ids copied into `grug_home/locations.lua` and `grug_housing/manager.lua` (W13-11) |
| `decor_kit.lua` | yes, 25× per env | `r14_poi_blueprint`, `r20_poi_blueprint`, every start and capital plot builder | live (Round 36) |
| `hearthpine`, `dawnmere`, `silverleaf`, `stillgrave`, `sunscar`, `kapok` | yes, **eager**, built at load in both envs | `wp40/r7_<key>_blueprint.lua` (3-line wrappers) → `r7_runtime`; then patched by `wp40/r20_civic.lua` | live; the final start = wp13 output + wp40 patch (W13-08) |
| `highcourt`, `dur_brannoc`, `lethariel`, `nhal_veyr`, `gor_drazhak`, `kezamba` (cores) | yes, lazy (main builds at load, emerge on touch) | `r7_capital_blueprint.kit` → `r7_runtime`; `r7_capitals.plan_all` (core landing) | live; headers stale (±47, "overlay modules") |
| `*_districts.lua` (6) and district rosters (`*_district*.lua`, 16) | yes | `r7_capital_blueprint.kit` | live; comments reference retired KAT and "the quadrant's nine lots" |
| `*_plot.lua` (6), `kezamba_lots.lua` | yes, lazy | district rosters; `nhal_veyr.lua` also loads `nhal_veyr_plot` for its two handles | live |
| `buildings`, `capitals`, `dressing`, `layout`, `roofs`, `interiors`, `precinct_ring` | yes (dressing 168×, roofs and interiors 89×, buildings 62× per env) | compositions | live; `capitals.wall_segment`, `wall_tower`, `stilt_platform`, `water_channel` dead (W13-09) |
| `elf_parts`, `undead_parts`, `troll_parts`, `troll_palette`, `dwarf_dressing`, `kezamba_lagoon` | yes | their capital and plot builders | live; `troll_parts.fish_landing`, `palette_names` and `kezamba_lagoon` `M.ENVELOPE`, `REFERENCE_Y`, `WATER_SURFACE_Y`, `LAGOON_COLUMNS`, `RAVINE_COLUMNS` dead |
| top level: `init.lua`, `jit_tuning.lua`, `world_nodes.lua`, `poi_displays.lua` | yes (`jit_tuning` in both envs) | engine | live; `poi_display_<race>` used by the r14 and r20 builders |
| top level: `wp43_handoff.lua` | yes (main, `r7_loader:25`) | `r7_loader`; hashed in `r7_r6_manifest.lua:40` and `r6_content.lua:66` | live; frozen evidence hash rows are wp40's concern |
| wp40 `r7_wp13_library.lua` | yes | 6 start wrappers, `r7_capital_blueprint`, r14 and r20 builders | live seam (locates wp13 via `debug.getinfo`) |
| wp40 `r7_<18 POIs>_blueprint.lua`, `r7_<6 starts>_blueprint.lua` | yes | `r7_settlement.roster[*].blueprint_file` | live boilerplate (W13-05) |

Tool-only consumers of wp13: 22 files under `tools/` (`tools/wp13/*`,
`r36_w`, `r36_w2`, `r36_p`, `r26_capitals`, `r25_*`, `r31_s` and others).
Example: `tools/wp13/dump_capital_part.lua` still says the capital generators
are "not wired into a settlement yet" (line 4).

## Findings table

| ID | Sev | Category | Title | Location |
|---|---|---|---|---|
| W13-01 | Medium | Perf / Legacy | Emerge keeps every start's and POI's cells up to three times (≈300 MiB measured; lazy POIs are not lazy) | `wp40/r7_settlement.lua:780-783,849,1374-1394`; `wp40/r7_runtime.lua:352-360` |
| W13-02 | Medium | Perf | Main builds and hashes every composition on every boot, also on a layout-cache hit (≈3.5–4.3 s isolated) | `wp40/r7_runtime.lua:264-279,341-381`; `wp40/r7_settlement.lua:546-683` |
| W13-03 | Medium | Agent-trap | 38 wp13 files claim a retired KAT "asserts/proves" invariants; the registry mirror tables in `parts.lua` have no check | `wp13/parts.lua:65-421`, `wp13/palette.lua:92`, 38 files |
| W13-04 | Medium | Duplication | Five sources of per-race materials (wp13 palette, r14, r20, r31, `SURFACE_TWIN`/`decor_kit.RACE`) | `wp13/palette.lua:96-761`; `wp40/r14_poi_blueprint.lua:47-60`; `wp40/r20_poi_blueprint.lua:39-46`; `wp40/r31_pvp_poi_blueprint.lua:37-68`; `wp40/r7_runtime.lua:198-200` |
| W13-05 | Medium | Legacy / Agent-trap | The wp13/wp40 split no longer matches what lives where; misleading names; 24 wrapper files | directory layout; `wp40/r7_settlement.lua:1585-1590`; `wp40/r6_settlement.lua:3492-3496` |
| W13-06 | Low | Agent-trap | Collar materials are declared in `r7_capital_blueprint` and used in `r7_settlement`; a mismatch fails only in emerge at the first collar chunk | `wp40/r7_capital_blueprint.lua:113-127`; `wp40/r7_settlement.lua:1515-1522` |
| W13-07 | Low | Perf | `palette.new` runs per settlement per non-air chunk (135×, ≈0.84 ms and ≈485 KiB garbage per chunk) | `wp40/r7_settlement.lua:1515`; `wp13/palette.lua:790-883` |
| W13-08 | Low | Agent-trap | wp40 patches the wp13 start compositions by coordinate (`r20_civic`, `START_TRAINERS`); no offline tool applies the patch | `wp40/r20_civic.lua:28-57`; `wp40/r7_settlement.lua:130-137,1144-1155`; `wp40/r7_runtime.lua:356-358` |
| W13-09 | Low | Legacy | About 600 lines of dead generators and constants in live files | `wp13/capitals.lua:757-1027,1828-2010`; `wp13/troll_parts.lua:138-190,517-625`; `wp13/kezamba_lagoon.lua:41-46` |
| W13-10 | Low | Duplication | `less_bytes` ×6, `sort_cells_zyx` ×3, `rot` ×2; the comment justifying the copy is obsolete | `wp13/parts.lua:992-1007`; `wp40/r7_settlement.lua:495-506`; `wp40/r20_poi_blueprint.lua:6-27`; `wp40/r20_civic.lua:6-27`; `wp13/plot_approach.lua:20-27`; `wp40/capital_planner.lua:228-234` |
| W13-11 | Low | Duplication | Capital service and inn plot ids copied into two other mods instead of read from `capital_services.lua` | `mods/PLAYER/grug_home/locations.lua:10-15`; `mods/PLAYER/grug_housing/manager.lua:22-32` |
| W13-12 | Low | Perf | Module re-instantiation: 969 `dofile` per env (parts 332×); ≈0.6 s and ≈19 MiB avoidable, output-identical | all wp13 loaders; `wp40/r7_wp13_library.lua:47-50` |
| W13-13 | Low | Perf | A capital core is built twice on a first start (`plan_all` core landing) | `wp40/r7_capitals.lua:192`; `wp40/r7_runtime.lua:359` |
| W13-14 | Low | Perf | Lazy rebuilds likely thrash under the row-major preparation order; each rebuild re-hashes | `wp40/r7_settlement.lua:126,1337-1394`; `mods/CORE/grug_core/preparation_plan.lua:121` |
| W13-15 | Low | Bug (latent) | The r14 POI builder sorts its palette with locale `<`; a PUC build in a non-C collation can refuse to load | `wp40/r14_poi_blueprint.lua:392`; `wp40/r7_settlement.lua:562-568` |

## Findings

### W13-01 Emerge keeps every start's and POI's cells up to three times

- **Severity:** High. **Category:** Perf / Legacy. **Confidence:** Verified
  for the retention (code plus measurement). Plausible for the GC impact.
- **Location:**
  - `wp40/r7_settlement.lua:780-783`: `build = function() return source end`
  - `wp40/r7_settlement.lua:849`, `1374-1394` (`cells_of`, `release`)
  - `wp40/r7_runtime.lua:352-360`
- **What:**
  - For every one-blueprint settlement (the 6 starts and all 106 r14, r20 and
    r31 POIs), `r7_runtime` builds the full cell list at load
    (`dofile(profile.blueprint_file)(blueprint_options, profile)`).
  - `M.descriptors` then wraps the result in a closure, `build = function()
    return source end`. That closure lives as long as `prepared.descriptor`,
    which is for the life of the emerge session.
  - **Lazy POIs:** `prepare_one` drops the prepared cell copy
    (`if profile.lazy then prepared.cells = nil end`), but the closure still
    holds the original list. The "lazy rebuild" in `cells_of` just re-validates
    that same table. Laziness saves nothing but the session copy.
  - **Eager starts:** the session keeps three copies:
    1. the source list (closure);
    2. `prepared.cells` (new `{x,y,z,param2,name}` tables);
    3. after the first touch, `state.cells` (new `{x,y,z,content_ref,param2}`
       tables). `release` never frees it for an eager blueprint
       (`if state.cells and not state.blueprint.cells`).
- **Measured (LuaJIT, real files):**
  - Starts plus POIs held only by the build closures: **213.8 MiB**. The whole
    prepared set: 312 MiB.
  - The 6 starts are 381,189 cells; one copy is ≈97 MiB (267 B per cell
    table).
  - The perf review reports the emerge environment at **630–648 MiB live
    after a full collection**, with one collection taking **407–694 ms**
    (`docs/research/perf-review-2026-10-r32.md:169-171`). These structures are
    roughly half of that heap.
  - Main frees them after load (its heap is 67–69 MiB on a later start), but
    they are part of main's boot peak.
- **Impact:**
  - Server RSS: the perf review measured 2.9–3.3 GB VmHWM on a first
    generation.
  - Longer GC cycles on the emerge thread, which delays chunk delivery. It
    does not scale with players, but it is paid for the whole session.
- **Better:**
  1. For one-blueprint settlements, store a *builder* in the descriptor
     instead of the result. For example: `build = function() return
     dofile(file)(options, profile) end`, or have the POI wrappers return a
     function. Then lazy POIs are really lazy and `cells_of`'s identity check
     becomes a real rebuild check.
  2. For eager starts, drop the source after `prepare_cells` (the validated
     copy is enough). Also let `cells_of` reuse or replace `prepared.cells`,
     not keep both. Optionally store the session cells as flat number arrays:
     5 × 381k doubles ≈ 15 MiB instead of ≈97 MiB.
  - Effort S–M.
  - Risk: identity bytes must not change. They do not: only the lifetimes
    change.
  - Check: `tools/r36_w` and the main/emerge manifest agreement in an engine
    boot. No seed fleet is needed, since no footprint changes.
  - Overlap: lanes C1/C2 own `r7_settlement.lua`; coordinate.
- **Verification (phase 2):** Confirmed, severity changed to Medium (MGS-01 is the same issue; one severity for both). The mechanism holds. Emerge builds every non-capital composition (`r7_runtime.lua:352-354`), and the handover copy in `prepare` keeps the descriptor (`r7_settlement.lua:900-914`), whose `build = function() return source end` (`:780-783`) stays reachable from the writer's `on_generated` closure. Re-measured (`v6/mem.lua`): closures 215 MiB (POIs 117, starts 98), plus start `prepared.cells` 98 MiB, plus the content-ref copy 97.5 MiB once the starts generate. That makes about 313 MiB in every session and about 410 MiB on a fresh world. Not High: the collector is incremental, and 407–694 ms was a probe's explicit full collection on the emerge thread. A full collection with all 313 MiB live takes 92 ms in isolation. The gain is mainly 7–10 % of the 2.9–3.3 GB VmHWM, which is not player-visible.

### W13-02 Main builds and hashes every composition on every boot

- **Severity:** Medium. **Category:** Perf. **Confidence:** Plausible. The
  costs were measured in isolation; I did not take an engine boot profile.
- **Location:** `wp40/r7_runtime.lua:264-279`, `341-381`;
  `wp40/r7_settlement.lua:546-683` (`prepare_cells`).
- **What:**
  - On a world-layout cache hit, `capital_layout_text` is given, so the
    pre-prepared `capital_plots` table stays empty (`r7_runtime.lua:272`).
  - `M.prepare(..., prepared_handover or capital_plots)` then builds and hashes
    every capital core and plot in main again (`prepare_one`).
  - All starts and POIs are built as well (W13-01).
- **Measured (LuaJIT, isolated):**
  - 6 starts plus 6 capital kits, cores and 304 plots: **2.75 s**.
  - 106 POIs: 0.38 s.
  - `prepare_cells` (validation and identity bytes, without SHA): **+38 %**
    over the build.
  - In total ≈3.5–4.3 s per boot. The perf review measured a later start at
    **8.0–9.1 s** in total.
  - Profile: `Buffer:put`/`fill` ≈45 %, `sort_cells_zyx` ≈16 %.
  - `Buffer:put` with a packed numeric key instead of `x..":"..y..":"..z` is
    ≈2× faster on puts (0.022 → 0.012 s per 141k puts). Cell order comes from
    `order`, so identity is unaffected.
- **Impact:** every server start, first or later; the identity work is
  repeated in a fresh world as well.
- **Better (in order of effort):**
  1. A packed numeric key in `parts.Buffer` (S). The same applies to
     `Buffer:at`, and `resolve_panes` uses it.
  2. A module memo (W13-12, S).
  3. Optional (M): cache main's lazy preparations (the `M.handover` plain
     records, already serializable) in the world folder under the existing
     world key. The source digest covers wp13. On a hit, main skips the
     builds; emerge still re-checks each lazy blueprint on first touch.
  - Risk: low, since identity checks remain in emerge.
- **Verification (phase 2):** Confirmed — main passes `prepared_handover or capital_plots` with a nil handover (`r7_runtime.lua:359-360`), and `capital_plots` is filled only on a layout-cache miss (`:269-277`). On a hit, `prepare_one` therefore builds and validates every core and plot, plus all starts and POIs. A main-boot emulation (`v6/boot.lua`, no SHA) took 4.1 s: capitals 3.0 s, starts and POIs 1.1 s. A cache miss does the same work, because the design is "main BUILDS every blueprint once and hashes it" (`:242`). The fix is a new identity cache, not a regression repair. Medium stands: this is about half of the measured 8–9 s later start and is paid on every headless boot.

### W13-03 Stale "KAT asserts/proves" claims; registry mirror tables without a check

- **Severity:** Medium. **Category:** Agent-trap. **Confidence:** Verified.
- **Location:**
  - `wp13/parts.lua:65-201` (`PARAM2_KIND`, `SHAPED`), `260-291`
    (`PANE_CONNECTS`), `300-381` (`FULL_SOLID`), `405-415` (`WILD_SOIL`),
    `780-784` (`PANE_NAMES`).
  - The comments at `parts.lua:144-147`, `167-169`, `194-195`, `542-545`,
    `776-778`.
  - 38 of 60 wp13 files mention "KAT", for example `capitals.lua:34` ("the
    KAT measures it"), `dur_brannoc.lua:132` ("The KAT asserts the resulting
    multiset"), `dwarf_dressing.lua:12-16`, `highcourt_district.lua:44`.
- **What:**
  - `library_kat` and the composition KAT were retired in Round 22: no file
    of that name exists under `tools/`.
  - `grep library_kat tools` finds nothing. The current fixtures that load
    wp13 (`tools/r36_w`, `r36_w2`, `r31_s`, `r33_c5`, `r29_w`, `r34_f3`) check
    decor, benches, sockets and bounds. They do not check:
    - the registry property tables;
    - the "no cell floats" or "paved over air" rules;
    - the vendor multiset;
    - patrol-loop closure;
    - generator extents.
  - Stale structural comments in the same family:
    - all six capital headers give the core bounds as ±47 (`highcourt.lua:6`
      and the others); the cores span ±49 (measured);
    - `nhal_veyr.lua:7-9` and `gor_drazhak.lua:6` describe "run
      specifications the overlay modules turn into the avenues ... curtain
      wall", which is now the capital planner and `city_edge`;
    - `highcourt_district.lua:42` and `nhal_veyr_district.lua:43` mention "the
      quadrant's nine lots";
    - `tools/wp13/dump_capital_part.lua:4` says "not wired into a settlement
      yet".
- **Impact:**
  - An agent adding a palette node trusts that a check guards the property
    tables. Two misses fail loudly at build: `Buffer:put` refuses a param2 on
    an unlisted node, and the torch support check errors.
  - Others are silent:
    - a pane that should connect but is missing from `PANE_CONNECTS` gets the
      wrong shape;
    - a ground missing from `WILD_SOIL` gets no flora;
    - a slab missing from `SHAPED` cannot be turned upside down.
- **Better:**
  - Rewrite the claims in the past tense or delete them (S).
  - If Jan wants a guard, add one small fixture (S–M): load
    `tools/wp13/stub_registry.lua`, which still exists, and compare
    `PARAM2_KIND`, `SHAPED`, `FULL_SOLID` and `PANE_CONNECTS` against the
    registry groups and drawtypes for every name a composition emits. That is
    the one KAT section with real silent-failure value.
  - Fix the ±47 headers.
- **Verification (phase 2):** Confirmed — 38 of 60 wp13 files mention "KAT". `library_kat` survives only in `parts.lua` comments (144, 167, 194, 399, 542), and no file under `tools/` or `mods/` outside `parts.lua` reads `PARAM2_KIND`, `SHAPED`, `FULL_SOLID`, `PANE_CONNECTS` or `WILD_SOIL`. `tools/wp13/stub_registry.lua` exists. `highcourt.lua:6` says ±47, while `M.BOUNDS.capital_core` is ±49 (`r7_settlement.lua:77`).

### W13-04 Five sources of per-race materials

- **Severity:** Medium. **Category:** Duplication. **Confidence:** Verified.
- **Location:**
  - `wp13/palette.lua:96-761`: the authority for starts and capitals.
  - `wp40/r14_poi_blueprint.lua:47-60` (`palettes`, `roof_blocks`).
  - `wp40/r20_poi_blueprint.lua:39-46`.
  - `wp40/r31_pvp_poi_blueprint.lua:37-68` (`FORT`, `CAMP`).
  - `wp40/r7_runtime.lua:198-200` (`SURFACE_TWIN`).
  - `wp13/decor_kit.lua:35-50` (`M.RACE`).
- **What:** three POI builders carry their own race-to-node tables, and they
  differ from the race palette. Examples:
  - The orc ground is `default:dry_dirt_with_dry_grass` in all three POI
    builders, but `default:dirt_with_dry_grass` in `palette.lua:538`, which
    `r7_runtime` remaps for the start band only.
  - The human POI roof is slate, while the palette's human roof is
    `stairs:*_wood`.
  - POIs also place decor-kit pieces drawn from the **wp13 palette**
    (`decor.brush(..., spec.race)`, `r14_poi_blueprint.lua:362`). One POI
    therefore mixes two material sources.
- **Impact:** a material change in `palette.lua`, for example a new race
  ground, reaches starts, capitals, collars, the city edge and POI decor. It
  does **not** reach POI buildings and grounds. An agent cannot tell which is
  intended.
- **Better:**
  - Decide (open question 2). Either the POI builders read their roles from
    `palette.new(race)`, or each table gets a one-line comment saying the
    difference is deliberate.
  - Effort M if unified. That changes POI cells and needs a render review.
    No seed fleet is needed, since it is node swaps only.
- **Verification (phase 2):** Confirmed — the tables are at `r14_poi_blueprint.lua:47-60`, `r20_poi_blueprint.lua:40-47`, `r31_pvp_poi_blueprint.lua:37-72` and `decor_kit.lua:35-50`. The orc POI ground is `default:dry_dirt_with_dry_grass`, against `palette.lua:538`. One caveat: the `SURFACE_TWIN` comment (`r7_runtime.lua:195-200`) says `default:dirt_with_dry_grass` is not an R6 mapgen surface node. The orc-ground difference is therefore probably deliberate, not drift. The duplication finding stands; it overlaps MGS-04.

### W13-05 The wp13/wp40 split no longer matches what lives where

- **Severity:** Medium. **Category:** Legacy / Agent-trap. **Confidence:**
  Verified.
- **Location:** the directory layout (see the file table). Also
  `wp40/r7_settlement.lua:1585-1590` (`write_hearthpine`) and
  `wp40/r6_settlement.lua:3492-3496` ("Hearthpine identity differs", "Hearthpine
  owner is ignore" for every settlement).
- **What:**
  - **Composition code in wp40.** The r14, r20 and r31 POI builders (each with
    its own put/fill/key buffer and its own palette) and `r20_civic.lua` (a
    patch on wp13 starts) live in wp40.
  - **Runtime or game-data code in wp13.** `city_edge.lua` and
    `plot_approach.lua` run on each chunk inside the world writer;
    `capital_services.lua` is read by `grug_traders`.
  - **Wrapper boilerplate.** Twenty-four `r7_*_blueprint.lua` files exist only
    so that `roster[*].blueprint_file` has a path:
    - 18 POI wrappers of 9 lines each re-derive `here` and call
      `r14_poi_blueprint` with a schema, race and kind that are already in the
      roster row;
    - 6 start wrappers each make one `library.composition(key)` call.
  - **Misleading names.**
    - `write_hearthpine` writes every settlement, and the error text in
      `r6_settlement.lua` names Hearthpine for every settlement.
    - "wp13" and "wp40" are work-package numbers, not roles.
    - Schema strings `grug_wp13_*` / `grug_r14_*` / `grug_r20_*` /
      `grug_r31_*` are frozen identity text, so they are not a reason to keep
      the paths.
- **Impact:**
  - An agent looking for "the building library" misses a third of it, which
    is in wp40.
  - An agent editing a wrapper changes nothing.
  - An agent reading "Hearthpine" in a crash log looks in the wrong place.
  - The two-directory split is justified as a *seam*: a pure, offline-
    renderable composition library on one side, the world generator on the
    other. The current file placement and names do not follow that seam.
- **Better:** a cleanup plan, in order, each step independently mergeable:
  1. **No behaviour change (S).**
     - Delete the W13-09 dead code.
     - Dedupe the W13-10 helpers by pointing wp40 at `parts`/`plot_approach`.
     - Fix the stale comments (W13-03).
     - Rename `write_hearthpine` to `write_settlement` and change the
       r6_settlement error texts. `write_hearthpine` is a context method name
       in `r6_settlement`/`r7_settlement`; check the frozen R6 contract docs
       first.
     - Verify with a cell digest per composition before and after (as in my
       harness), plus `tools/r36_w`.
  2. **Perf (S).** W13-01, W13-07, W13-12, W13-13 and the Buffer key from
     W13-02.
  3. **Seam placement (M).**
     - Replace the 24 wrappers with a roster field (`composition = "hearthpine"`
       or `builder = "r14"`) that `r7_runtime` resolves.
     - Move the r14, r20 and r31 builders and `r20_civic` into the library
       directory.
     - Move `city_edge`/`plot_approach` next to the writer, or label them
       clearly.
     - Paths change: `preparation_identity.lua:17` and the layout-cache key
       change. A fresh world is fine.
  4. **Rename (L, optional).** Rename `wp13/` to `settlements/` and `wp40/` to
     `world/`. Churn: 22 tool files reference wp13 paths, 82 reference wp40
     paths, and 14 mod files outside mapgen. Docs that cite paths stay as
     historical. I recommend steps 1–2 now, step 3 when the POI work next
     touches the builders, and step 4 only if tools are being retired anyway.
  - Risk overall: low for runtime, because identities are pinned by digest.
    The main risk is tool breakage.
- **Verification (phase 2):** Confirmed — there are 24 wrappers: 18 POI stubs of 9 lines that only re-pass schema, race and kind, and 6 start wrappers of 19–22 lines that each make one `library.composition` call. `r6_settlement.lua:3492,3496` raise "Hearthpine identity differs" / "Hearthpine owner is ignore" for every settlement. The POI builders and `r20_civic.lua` live in wp40, while `city_edge.lua` and `plot_approach.lua` run per chunk from `r7_settlement.lua`.

### W13-06 Collar materials declared in one wp40 file, used in another

- **Severity:** Medium. **Category:** Agent-trap. **Confidence:** Verified.
- **Location:**
  - `wp40/r7_capital_blueprint.lua:113-127` adds
    `p.node("ground")`, `p.node("subsoil")`,
    `p.maybe("castle_paving") or p.node("plaza")` and
    `p.maybe("castle_wall_stair") or p.node("roof_stair")` to the overlay
    names.
  - `wp40/r7_settlement.lua:1515-1522` resolves the same four roles per settle
    and fails with `"plot approach material is outside settlement palette"`
    inside `fit_write`.
- **What:** the set of nodes the collars may write is closed at load by the
  first file, but used by the second. If the collar code picks another role
  (say `path` for the approach), the load still succeeds. The failure comes
  in the **emerge thread** at the first chunk that writes a collar, which
  aborts the server mid-session. `city_edge` has the same structure
  (`M.names` against the writers), but there it is derived from one `roles()`
  table, so it holds structurally.
- **Impact:** a crash that only appears when a player or the preparation
  reaches a capital, not at boot. No test covers it.
- **Better:**
  - Resolve the four refs once in `config.new` (or in `M.config`) and fail at
    load if a capital settlement lacks one. This also fixes W13-07.
  - Better still, derive both lists from one function in `plot_approach.lua`.
  - Effort S.
- **Verification (phase 2):** Confirmed, severity changed to Low (same issue as MGS-03, settled there). The lists are duplicated at `r7_capital_blueprint.lua:118-121` and `r7_settlement.lua:1515-1519`, and they fail in emerge only when a collar is written. Low, because the error is loud and names itself, `r7_capital_blueprint.lua:108-111` documents the coupling, and `refs` covers the capital's whole palette union (`r7_settlement.lua:1181-1190`). A role change crashes only if no core, plot or edge cell of that capital uses the node. The `palette.new` loop covers the 118 roster settlements (W13-07's 135 is wrong) and costs 0.77 ms per non-air chunk.

### W13-07 `palette.new` runs per settlement per non-air chunk

- **Severity:** Low. **Category:** Perf. **Confidence:** Verified (code and
  measurement).
- **Location:** `wp40/r7_settlement.lua:1515`; `wp13/palette.lua:790-883`.
- **What:**
  - `tail.settle` calls `approach_palettes.new(profile.race)` before any early
    exit. `r7_successor.lua` calls `settle` for all **135** roster settlements
    on every non-air chunk (`r6_settlement.lua:3512`).
  - `palette.new` copies about 89 roles, runs `contains()` linear scans (≈80 ×
    89 string compares) and allocates four closures. `maybe()` scans again.
- **Measured:** 6.2 µs per call, i.e. **≈0.84 ms and ≈485 KiB of garbage per
  chunk**. A steady mapchunk costs about 0.5 s, so this is under 1 %, but it
  is pure waste and adds GC pressure on the emerge thread.
- **Better:**
  - Compute the four refs once per settlement in `config.new`, or skip them
    for settlements with no reference plots (only the 6 capitals have
    collars).
  - Separately, make `palette.lua` keep a declared-role set instead of
    `contains()` scans. That also speeds every composition build.
  - Effort S.

### W13-08 wp40 patches the wp13 start compositions by coordinate

- **Severity:** Low. **Category:** Agent-trap. **Confidence:** Verified.
- **Location:**
  - `wp40/r20_civic.lua:28-57`: clears (1..2, 1..2, ±13) and writes a furnace
    at (4, 1, ±13); z is +13 for dwarf, human and elf, −13 for the rest.
  - `wp40/r7_settlement.lua:130-137` and `1144-1155`: `START_TRAINERS` plus
    `quest_cook`/`cook_oven` sockets at the same coordinates.
  - `wp40/r7_runtime.lua:356-358`.
- **What:** the start the game builds is the wp13 composition plus a wp40
  patch. `grep r20_civic tools mods` finds only `r7_runtime.lua`, so no
  offline tool applies the patch. That includes `tools/r36_w` (reachability,
  windows), `r36_w2` (benches), `tools/wp13/dump_blueprint.lua` and the render
  pages. They all judge a start without the cook's verge and furnace.
- **Impact:**
  - An agent re-authoring a start street near (1..4, ±13) breaks the cook
    station without any test noticing.
  - Renders and walkability checks do not show what ships.
- **Better:**
  - Move the civic edit into the six start compositions (wp13), or into
    `decor_kit` as a "cook verge" piece, and the sockets into their landmarks.
    Then `START_TRAINERS` and `r20_civic.lua` disappear.
  - Or at least apply `r20_civic` in the r36 fixtures' start loader.
  - Effort S–M. It changes start identities (a fresh world).

### W13-09 About 600 lines of dead generators in live files

- **Severity:** Low. **Category:** Legacy. **Confidence:** Verified.
  Each name was grepped as a whole word over `mods/` and `tools/`, including
  string dispatch (`make = "..."`).
- **Location:**
  - `wp13/capitals.lua`: `wall_segment` (757-874, only mentioned in a comment
    at 927), `wall_tower` (875-1027), `stilt_platform` (1828-1932),
    `water_channel` (1933-2010).
  - `wp13/troll_parts.lua`: `palette_names` (138-190; its comment describes
    the pre-planner overlay identity), `fish_landing` (517-625).
  - `wp13/kezamba_lagoon.lua:41-46`: `M.REACH`/`ENVELOPE`/`REFERENCE_Y`/
    `WATER_SURFACE_Y`/`LAGOON_COLUMNS`/`RAVINE_COLUMNS`. Its own comment calls
    them "historical".
- **What:** these pieces belong to the curtain walls and edges of the
  pre-planner era. `city_edge.lua` replaced them in Round 22/23.
- **Impact:** about 600 lines an agent may "fix" or reuse, believing them
  live.
- **Better:** delete them (S); identities do not change. Or keep them as a
  documented parts shelf if Jan wants them for later content (open question
  3).

### W13-10 Helper duplication across the seam

- **Severity:** Low. **Category:** Duplication. **Confidence:** Verified.
- **Location:**
  - `less_bytes`: `wp13/parts.lua:996`, `wp40/r7_settlement.lua:495`,
    `wp40/layout_cache.lua:35`, `wp40/r6_hash.lua:47`, `wp40/r7_p9g.lua:66`,
    plus inline copies in `r20_civic.lua:50-53`, `r20_poi_blueprint.lua:246-248`
    and `r31_pvp_poi_blueprint.lua:423-425`.
  - `sort_cells_zyx`: `parts.lua:642`, `r20_poi_blueprint.lua:6-27`,
    `r20_civic.lua:6-27`. Both copies say they copy `parts.lua`. The r14 and
    r31 builders instead use Lua-comparator sorts. The `parts.lua:631-635`
    comment records that comparator sorts were a sixth of blueprint
    construction.
  - Rotation: `plot_approach.lua:20-27` `rot` is identical to
    `capital_planner.lua:228-234` `M.rot`.
- **What:** `parts.lua:992-995` justifies the r7_settlement copy as being "for
  the consumers that never load this library". But `r7_settlement.lua:69` now
  loads `parts.lua`.
- **Impact:** a change to the byte-order rule or the rotation convention must
  be made in up to 8 places. A missed one gives a load failure at best and a
  turned plot whose sockets and cells disagree at worst.
- **Better:** point wp40 at `parts.less_bytes`, `parts.sort_cells_zyx` and
  `plot_approach.rot`. The wp40 files that cannot load wp13 (`r6_hash`,
  `r7_p9g`, `layout_cache`) may keep theirs. Effort S.

### W13-11 Capital service and inn plot ids copied into two other mods

- **Severity:** Low. **Category:** Duplication. **Confidence:** Verified.
- **Location:**
  - `mods/PLAYER/grug_home/locations.lua:10-15`: the inn sockets, equal to
    `capital_services.INNS`.
  - `mods/PLAYER/grug_housing/manager.lua:22-32`: the tailor plot sockets,
    equal to `capital_services.PLOTS[city].tailor`.
  - In contrast, `grug_traders/vendors.lua:485-497` reads
    `wp13/capital_services.lua`.
- **Impact:** renaming a plot means three edits. A mismatch fails loudly at
  load (the socket is missing), so this is not silent.
- **Better:** read `capital_services.lua` in both mods, as `grug_traders`
  does. Effort S.

### W13-12 Module re-instantiation: 969 `dofile` per environment

- **Severity:** Low. **Category:** Perf. **Confidence:** Verified (measured).
- **Location:** every wp13 loader (`dofile(directory .. "/parts.lua")` and so
  on); `wp40/r7_wp13_library.lua:47-50`.
- **What:** each composition re-loads its dependencies. Per environment:
  - `parts.lua` executes 332×;
  - `dressing.lua` 168×;
  - `roofs` and `interiors` 89× each;
  - `buildings` 62×;
  - `palette` 56×.
- **Measured:** memoizing only the leaf modules by path (`parts`, `palette`,
  `roofs`, `interiors`, `capital_services` and so on) gives byte-identical
  cells over all starts, capitals and plots and three POIs (same digest). It
  takes the run from 2.75 s to 2.16 s and the retained heap from 124.7 to
  105.4 MiB. Memoizing loader results per directory would save more. No wp13
  module writes into another module's table (grepped).
- **Better:** give `r7_wp13_library` a `load(name)` cache, and have the
  loaders call it instead of `dofile`. Effort S. It must stay plain Lua 5.1
  (`require` is disabled in the sandbox).

### W13-13 A capital core is built twice on a first start

- **Severity:** Low. **Category:** Perf. **Confidence:** Verified.
- **Location:** `wp40/r7_capitals.lua:192`
  (`local core_cells = kit.core.build().cells` for `core_landing`);
  `wp40/r7_runtime.lua:359`, where `prepare` builds it again because the
  cache holds only plot prefixes.
- **Impact:** ≈0.1 s per core, ≈0.6 s per first start.
- **Better:** prepare the cores alongside the plots at `r7_runtime.lua:273-276`
  and pass their cells or landmarks to `plan_all`. Effort S.

### W13-14 Lazy rebuilds likely thrash under the row-major preparation order

- **Severity:** Low. **Category:** Perf. **Confidence:** Plausible. I did not
  measure rebuild counts; the order and constants are verified.
- **Location:**
  - `wp40/r7_settlement.lua:126` (`IDLE_RELEASE = 64`), `1337-1394`, `1465-1470`.
  - `mods/CORE/grug_core/preparation_plan.lua:121` ("x varies fastest").
- **What:**
  - The idle counter advances on every non-air chunk anywhere.
  - Full preparation walks tiles row by row in x, so a blueprint spanning two
    z-rows of tiles is touched, released after more than 64 chunks, and
    rebuilt when the next row arrives.
  - A capital core spans 2–3 rows; a plot spans 1–2.
  - Each rebuild costs a composition build (5–40 ms for a plot, ≈100–130 ms
    for a core), the identity bytes (+38 %), SHA-256 over ≈40 B per cell, the
    turn (`parts.buffer` re-put and `resolve_panes`) and the ref mapping.
- **Impact:** a few seconds of emerge time per full preparation (estimate:
  ≈2–3 s per capital). Small against the whole preparation, but avoidable.
- **Better:** release on distance from the last touch (in chunk rows) instead
  of a global counter, or key `IDLE_RELEASE` to the preparation's row width.
  Measure `build_calls` from `tail.metrics` on one preparation first. Effort S.

### W13-15 The r14 POI builder sorts its palette with locale `<`

- **Severity:** Low. **Category:** Bug (latent). **Confidence:** Verified for
  the code; the trigger is hypothetical today.
- **Location:**
  - `wp40/r14_poi_blueprint.lua:392`: `table.sort(palette)`.
  - The check at `wp40/r7_settlement.lua:562-568`, which refuses a palette not
    in byte order.
- **What:**
  - PUC Lua 5.1 compares strings with `strcoll`.
  - Luanti sets `LC_ALL` from the environment and resets only `LC_NUMERIC`
    (`reference_projects/luanti/src/gettext.cpp:162-229`). The user's
    `LANG=de_DE.UTF-8`.
  - The other three builders use explicit byte comparators.
  - I checked all 18 r14 palettes: de_DE collation order equals byte order
    **today**. LuaJIT compares bytes, so the default build is unaffected.
  - A future name pair like `abc_z` / `abca` would make a PUC-fallback server
    refuse to load (`... palette differs`).
  - The planned final PUC smoke test runs under `LC_ALL=C` (headless rule), so
    it would not catch this.
- **Better:** `table.sort(palette, parts.less_bytes)`. One line, S.

## Hot-path inventory

| Path | Frequency | Cost class | Notes |
|---|---|---|---|
| `r7_successor.settle` → `r7_settlement` `tail.settle` ×135 | every non-air chunk (air chunks return early, `r7_mapgen.lua:84`) | low per settlement; ≈0.84 ms per chunk dominated by `palette.new` | W13-07. The footprint string key is one alloc per settlement. `prepare_approaches` is cached after the first call. |
| `tail.bind_plan` ×135 | every non-air chunk | cheap | integer box tests over ≈54 states per capital; drives `IDLE_RELEASE` |
| Collar loop (`plot_approach.surface` per column, then `column()` planner query) | chunks inside the 6 capitals' reserved squares; only the first chunk of a vertical footprint stack (`write_span` y-culling) or those overlapping its recorded range | medium per such chunk: 6400 probes, each with a `x/32..":"..z/32` string and a bucket scan; planner queries only on collar columns | planner query cost is wp40's (C1/C2) |
| `city_edge.cells` | the same chunks, when the overlay box is active | low–medium: per column a bucket lookup, `gate_of` (4 gates) and a turret loop (redundant with the bucket coverage); near columns add `nearest()`, a planner query and a closure | pure function of (x, z); y-culled |
| Settlement cell write loop | every chunk an active blueprint's box touches | proportional to the **whole** blueprint (start ≈65k cells, core ≈100k), not the chunk slice: `inside_owner` per cell | a spatial index per chunk would cut it; wp40 code |
| `cells_of` lazy rebuild | first touch after a release (W13-14) | spike: plot 5–40 ms, core ≈0.2 s (build, identity bytes, SHA, turn, refs) | must stay deterministic: verified for all cores and plots |
| Main boot: build and prepare every composition | per server start | ≈3.5–4.3 s isolated (W13-02); plus ≈0.6 s core double build on a first start (W13-13) | |
| Emerge boot: starts, POIs, capital kits | per server start | ≈0.8 s isolated | memory, not time, is the issue (W13-01) |
| `palette.new`, `city_edge.new` at load | per settlement, per capital | negligible | |
| Server-step paths | none in wp13 | n/a | `init.lua`'s planned-water-flow callback uses wp40's `column_values_at` (event-driven by `grug_core`) |

## Bug-prone areas

- **Composition determinism.** A lazy rebuild that differs from main's
  identity is a hard error in the emerge thread (`r7_settlement.lua:1344-1356`).
  Any of these in a composition would crash a running server at the first
  touch:
  - a hidden mutable loader-level state;
  - `pairs` over table-keyed data;
  - float math that differs between JIT and the interpreter.
  
  It is clean today: I verified two instances, reverse build order and
  `-joff`. The `pairs` loops in wp13 are all order-independent (max, exists or
  unique-match).
- **Name sets closed at load, used per chunk.** These include the collar
  materials (W13-06) and the city-edge `M.names` against the writers. A cell
  name outside the settlement palette fails in emerge at runtime, not at boot.
- **`parts.lua` property tables.** They mirror the registry by hand
  (W13-03). `decor_kit.view` deliberately bypasses `Buffer:put`'s checks so
  that POIs can lay logs (param2 4/12). Those pieces must never reach a turned
  plot, where `rotate_param2` would refuse them.
- **The start = composition + `r20_civic` patch + `START_TRAINERS` sockets.**
  This is a coordinate coupling across directories (W13-08).
- **Triple-declared capital race.** It appears in the `r7_settlement` roster,
  in `r7_capital_blueprint.CAPITALS[key].race` and in the composition's own
  `palettes.new("human")`. They are consistent today.

## Noted (no action)

- `preparation_identity.lua:9-19` digests only `city_edge` and
  `plot_approach` from wp13. The "authority changed" guard does not see a
  composition change during a resumed preparation. This is moot in
  fresh-server mode; the layout and region caches do digest the whole tree.
- `approach_findings` (a plot with no street within 12 nodes) appear only in
  `tail.metrics`, never in the log (`r7_settlement.lua:1418-1419`).
- Micro costs:
  - `parts.rotate_param2` allocates its wallmounted `step` table per call
    (`parts.lua:476`);
  - `plot_approach.surface` builds a string key per column
    (`plot_approach.lua:39`);
  - `city_edge.cells` allocates a writer closure per near column
    (`city_edge.lua:469`).
- `r31_pvp_poi_blueprint` rotates param2 without `canonical_param2`/
  `resolve_panes`. It writes no panes today, so this is harmless.
- `nhal_veyr.lua` loads `nhal_veyr_plot.lua` (and through it its whole
  dependency set) only to read two palette handles (`CRYPT`, `VAULT`).

## Open questions for Jan

1. Is a directory rename (`wp13` → `settlements`, `wp40` → `world`) worth the
   churn in about 100 tool files and in the docs? Or should we only move
   misplaced files (the POI builders, `r20_civic`, `city_edge`,
   `plot_approach`) when they are next touched?
2. POI materials: should the r14, r20 and r31 POIs use the race palette
   (a visible change, so it needs a render look)? Or are their own tables a
   deliberate, different look?
3. Delete the dead pre-planner generators (`wall_tower`, `stilt_platform`,
   `water_channel`, `fish_landing` and so on), or keep them as a parts shelf
   for later content?
4. Given the minimal-test preference: should one small fixture guard the
   `parts.lua` registry mirror tables against `tools/wp13/stub_registry.lua`?
   It is the one retired-KAT check whose failures are silent.
