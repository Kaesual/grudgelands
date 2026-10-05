# Mapgen wp40 — settlements side (lane C2)

**Scope.** The settlement side of `mods/MAPGEN/grug_mapgen/wp40/`: the R7
cutover (`r7_loader.lua`, `r7_mapgen.lua`, `r7_runtime.lua`), the settlement
successor (`r7_settlement.lua` with its roster), the successor chain
(`r7_successor.lua`), anchor activation, roster and overlay
(`r7_anchor_activation.lua`, `r7_anchor_roster.lua`, `r7_zone_overlay.lua`),
roads (`road_layout.lua` profile DP, inputs and parameters; `road_writer.lua`),
dragon arenas (`arena_layout.lua`, `arena_writer.lua`), capitals
(`r7_capitals.lua`, `r7_capital_blueprint.lua`, `capital_protection.lua`,
`capital_planner.lua` parameters and pinning), the POI builders
(`r14_poi_blueprint.lua`, `r20_poi_blueprint.lua`, `r20_poi_catalog.lua`,
`r20_civic.lua`, `r31_pvp_catalog.lua`, `r31_pvp_poi_blueprint.lua`, the 24
`r7_*_blueprint.lua` stubs, `r7_wp13_library.lua`), protection
(`world_protection.lua`), the preparation envelope and caches
(`air_chunks.lua`, `preparation_source.lua`, `preparation_identity.lua`,
`layout_cache.lua`), the anchor/profile tables of `source/simple_map.lua`, the
settlement fitting in `height.lua` (lines 80–140, 800–1000, 2053–2063) and
the successor context in `r6_settlement.lua` (3320–3520). Consumers read for
the seams: `grug_core/settlement_sockets.lua`, `protection.lua`,
`water_guard.lua`, `zone_authority.lua` (protection part),
`starts_preload.lua` (preparation guard); `tools/seed_fleet/` and
`tools/r28_zone_atlas/world.lua`.

**Size.** Read fully: about 6,050 lines (the 24 files of the first group).
Read in part: about 13,300 lines (`road_layout.lua` 2,805, `capital_planner.lua`
2,999, `height.lua` 2,244, `r6_settlement.lua` 3,886, `r14`/`r31` builders,
`source/simple_map.lua`).

**Baseline.** `0f169898` (main). The working tree stayed unchanged for these
files during the review.

**Method.** I traced every per-chunk path from `core.register_on_generated`
(`r7_mapgen.lua:81`) through `plan_slice` → `writer.apply` → successor `settle`,
and every load-time path in `r7_loader.lua`. I grepped `mods/` before every
"missing/unused" claim. Measurements are LuaJIT 2.1 micro-runs of the real
modules in a scratch directory (no engine); each one is named where it is
used. Numbers are comparisons, not targets.

**Out of scope.** Terrain, biomes, ores, caves and ground cover (C1). The
internals of the wp13 compositions, `city_edge.lua`, `decor_kit.lua` and
`parts.lua` (C3); this lane covers only where they plug in. NPC spawning from
sockets (`grug_mobs/start_npcs.lua`, mobs lane).

## Summary

- **One writer, one order.** Each generated chunk runs `plan_slice` and then
  the R6 transaction. Its successor `settle` (`r7_successor.lua:97-118`) runs
  in this fixed order: road dressing → P9G plants → world content → anchor
  nodes → **every one of the 118 settlements** (6 starts, 6 capitals, 18
  Round 14 POIs, 70 Round 20 POIs, 18 Round 31 PvP POIs) → dragon arenas. A
  later pass overwrites an earlier one. Writes are clipped to the owner chunk
  (`inside_owner`), and every placement is a pure function of the plan, so
  chunk borders join seamlessly whatever the emerge order.
- **Positions are fixed, heights per seed.** All 118 anchors are fixed in
  `source/simple_map.lua:239-372`. The seed decides the fitted height, the
  roads, the capital layouts and the PvP camp race
  (`r31_pvp_catalog.camp_race`). A settlement's binding to its anchor exists
  in **three styles** (MGS-04).
- **Main plans, emerge replays.** Main builds the water, road and capital
  layouts once (cached in `grug_world_layouts.txt`, keyed by seed, a digest of
  the whole mapgen tree, the settings and the interpreter). Emerge receives
  the texts through `ipc_set` and never plans.
- **Lazy rebuilds are checked.** A lazy blueprint is rebuilt in emerge on its
  first touch and must hash to main's identity (`r7_settlement.lua:1339-1357`).
  Any composition that is not a pure function of its inputs crashes the
  generation. LuaJIT 2.1 randomizes the `pairs()` order of string keys per Lua
  state (measured; MGS-11), so **every order-relevant `pairs` result must be
  sorted**. The current code does this.
- **Many invariants are hard `error`s on the emerge thread.** Anchor support
  and root, stable anchor x/z, lazy identity, palette membership and the city
  edge floor all fail the transaction, which stops the server. The seed fleet
  stops before the writer, so none of these is tested across seeds (MGS-02).
- **Laziness works only for capitals.** For POIs and starts the "lazy"
  machinery is cosmetic. Their compositions are built eagerly at load in both
  environments and stay referenced. The emerge heap holds about 410 MiB of
  settlement cells (MGS-01).
- **Protection has two layers.** Towns, capitals and anchor columns are hard
  footprints (territory `hard_protected`, which `world_alterable` sees). Roads
  and the 106 POI/village/camp boxes are the Round 25 `world_feature_at`
  layer, which only `core.is_protected` sees (dig/place). The actor-neutral
  terrain-damage guard therefore does **not** cover POIs or roads yet
  (MGS-08, known in BACKLOG WP46).
- **Capital geometry is spread as literals across five files** (MGS-05).
- **Round 36 roads (`C_STEP` 0.05 → 0.5).** The code matches the design
  doc; the DP is unchanged apart from the per-change cost
  (`road_layout.lua:874-955`). The new value also reaches the capital streets
  and connectors through `with_params` (Noted N-1).

## Findings table

| ID | Sev | Category | Title | Location |
|---|---|---|---|---|
| MGS-01 | Medium | Perf | Emerge keeps ~410 MiB of settlement cells: POI "laziness" is cosmetic, starts held three times | `r7_runtime.lua:341-361`, `r7_settlement.lua:778-784, 849, 1389-1394` |
| MGS-02 | Medium | Agent-trap | Writer-time asserts stop the server and lie outside the seed fleet | `r7_anchor_activation.lua:86-198`, `r7_settlement.lua:1214-1220, 1339-1357, 1521, 1607`; `tools/r28_zone_atlas/world.lua:113-119` |
| MGS-03 | Low | Agent-trap / Perf | Plot-collar palette declared in two places, checked only at generation, rebuilt per chunk for all 118 settlements | `r7_capital_blueprint.lua:113-125`, `r7_settlement.lua:1514-1522` |
| MGS-04 | Medium | Duplication / Legacy | Three ways to bind a settlement to its anchor; three POI builders; five per-race material tables | `r7_settlement.lua:382-434, 452-487`; `r20_poi_catalog.lua`; `r14_poi_blueprint.lua:49-56`; `r20_poi_blueprint.lua:40-47` |
| MGS-05 | Medium | Agent-trap | Capital, start and anchor-table magic numbers repeated across files | `r7_settlement.lua:103, 1537`; `capital_protection.lua:45`; `capital_planner.lua:55-60`; `r7_capitals.lua:197, 235`; `r7_anchor_roster.lua:23, 78-81`; `r7_zone_overlay.lua:119, 136` |
| MGS-06 | Low | Agent-trap | Start cook/oven sockets hard-coded twice, by two different rules, with no clearance check | `r7_settlement.lua:130-137, 1144-1155`; `r20_civic.lua:30-39` |
| MGS-07 | Low | Duplication | PvP fortress gate side computed twice; only one copy honours a `turns` override | `r7_settlement.lua:445-450`; `road_layout.lua:2630-2637` |
| MGS-08 | Low | Agent-trap | The terrain-damage guard (`world_alterable`) does not cover roads or POI boxes | `grug_core/protection.lua:39-59`; `water_guard.lua:24-32` |
| MGS-09 | Low | Legacy | The dragon arena's protection box comes from four written air cells | `r20_poi_blueprint.lua:60-69`; `world_protection.lua:129-152` |
| MGS-10 | Low | Agent-trap | The seed fleet and three other tools hand-mirror `r7_runtime`'s assembly | `tools/r28_zone_atlas/world.lua:21-127`, `tools/r27_minimap/world.lua`, `tools/r26_capitals/world.lua`, `tools/r25_capital_plots/harness.lua` |
| MGS-11 | Low | Agent-trap | `pairs` order varies per Lua state under LuaJIT; one POI builder sorts its palette with locale `<` | `r14_poi_blueprint.lua:391-392`; `r7_settlement.lua:564-567` |
| MGS-12 | Low | Duplication | Byte-order compare and z/y/x cell sort copied 8+ times | `r20_civic.lua:6-27, 51-54`; `r20_poi_blueprint.lua:6-27, 246-249`; `r31_pvp_poi_blueprint.lua:423-426`; others below |

## Findings

### MGS-01 Emerge keeps ~410 MiB of settlement cells: POI "laziness" is cosmetic, starts held three times
- **Severity** Medium / **Category** Perf (memory, GC pause) / **Confidence** Verified (reference chain traced, sizes measured)
- **Location:** `r7_runtime.lua:341-361`, `r7_settlement.lua:778-784`, `:849`, `:1339-1394`; `r7_mapgen.lua:72-75`
- **What:** For every non-capital settlement, `r7_runtime.lua:352-354` runs the
  composition at load in **both** environments:
  ```lua
  source = dofile(wp40_directory .. "/" .. profile.blueprint_file)(blueprint_options, profile)
  if type(source) == "function" then source = source(blueprint_options) end
  ```
  `M.descriptors` then wraps it as
  `build = function() return source end` (`r7_settlement.lua:780-783`), so the
  composition stays reachable from the settlement config as long as the
  writer lives (`r7_mapgen.lua` keeps `built.writer` in the `on_generated`
  closure).
  - `prepare_one` drops `prepared.cells` for lazy profiles (`:849`), and
    `release` drops the content-ref copy after `IDLE_RELEASE` (`:1389-1394`).
    The raw composition is never freed, so for the 106 POIs "lazy" saves
    nothing, and the main→emerge handover saves only the hashing. The comment
    at `r7_runtime.lua:245-248` ("Emerge builds only the starts and the city
    edge overlays here") reads as if emerge skipped the composition; it does
    not.
  - Starts (eager) keep three copies: the composition (via the `build`
    closure), `prepared.cells` (`:672`) and, once their chunks are
    generated, the content-ref copy `state.cells` (`:1374-1386`), which
    `release` never drops for an eager blueprint (`:1390`).
  - Only the capitals' core and plot builders are real builders, so only they
    are truly lazy.

  **Measured** (LuaJIT, real modules, one copy each, after full collections):

  | Copy | Size |
  |---|---|
  | 106 POI compositions (452,130 cells) | **116 MiB**, built in 0.40 s |
  | 6 start compositions (381,184 cells) | 98.9 MiB |
  | Start `prepared` copy | 100.7 MiB |
  | Start content-ref copy | 95.1 MiB |

  Together that is about 316 MiB in every session and about 410 MiB in a
  session that generates the starts (a fresh world; `starts_preload`). The
  largest POI kinds by cells are PvP fortresses (81,634), PvP camps (100,640
  for both bands) and Round 14 villages/camps (62,208). A full GC with only
  the start copies live took 97 ms in the micro-run.
- **Impact:** The Round 32 review measured the emerge environment at
  630–648 MiB live and **407–694 ms per full collection** on the emerge thread
  (`docs/research/perf-review-2026-10-r32.md:170-172`), with process RSS of
  2.9–3.3 GB on a first generation. Settlement cells are probably the
  majority of that live heap. Every GC cycle traverses them, delaying chunk
  delivery to players. This is the largest single memory lever in the
  mapgen.
- **Better** (M):
  1. A lazy profile's `build` should re-run the composition, for example
     `function() return dofile(file)(options, profile) end`, so that nothing
     holds its cells between touches. Emerge then needs no composition at load
     at all, because the handover already carries identity, palette, bounds
     and landmarks.
  2. For eager starts, drop the `source` reference after `prepare` and build
     `state.cells` from `prepared.cells` once, then drop `prepared.cells` too.
  3. Optionally store cells as packed parallel arrays (x, y, z, ref, param2)
     instead of one table per cell. That is about 5–6× less memory per cell
     in LuaJIT and much less GC traversal.

  Identity bytes do not change if the cell order is kept. Risk: the lazy
  rebuild then really re-runs the composition, which is what the identity
  check exists for. Verify with one engine boot (heap log line,
  `init.lua:47-66`).
- **Verification (phase 2):** Confirmed (Medium; W13-01 is the same issue, settled there to Medium too) — the chain is real. `r7_runtime.lua:352-354` builds every non-capital composition in emerge. `prepare` takes the handover copy (`r7_settlement.lua:900-914`) but sets `copy.descriptor` to the descriptor whose `build = function() return source end` (`:780-783`). That descriptor is reached from `config` → successor → `built.writer` → the `on_generated` closure (`r7_mapgen.lua:72-86`). Re-measured with a main→handover→emerge emulation (scratch `v6/mem.lua`): POI sources 117 MiB, start sources 98 MiB, start `prepared.cells` 98 MiB, start content-ref copy 97.5 MiB. That is 313 MiB in every session and about 410 MiB once the starts generate; about 215 MiB of it is held only by the closures. The GC part is overstated: in normal play the collector is incremental, and 407–694 ms was a probe's explicit full collection. A full collection with all 313 MiB live took 92 ms in isolation. The gain is mainly 7–10 % of the 2.9–3.3 GB VmHWM, which is not player-visible.

### MGS-02 Writer-time asserts stop the server and lie outside the seed fleet
- **Severity** Medium / **Category** Agent-trap (bug-prone) / **Confidence** Verified
- **Location:**
  - anchors: `r7_anchor_activation.lua:86-93` (column authority), `:168-181` (support), `:188-198` (root)
  - settlements: `r7_settlement.lua:1214-1220` (stable anchor x/z, emerge only), `:1233-1242` (city edge floor), `:1344-1357` (lazy identity), `:1521` and `:1607-1609` (palette membership), `:1258-1260` (final height)
  - writer: `r6_settlement.lua:3481-3492` (escape, ignore)
  - fleet: `tools/r28_zone_atlas/world.lua:113-119`, `tools/seed_fleet/seed.lua:12-14`
- **What:** All of these run during `on_generated` (or, for `config.new`, at
  emerge construction) and raise errors that abort the generation, which
  stops the server.
  - The seed fleet builds the "portable world" only up to the anchor roster
    and overlay (`world.lua:117-119`). No settlement `config.new`, no `settle`
    and no anchor activation runs there.
  - The historical crash on seed 15912857179583385436
    (`r7_anchor_activation.lua:104-109`) was exactly this kind of writer-time
    assert, and the fleet would not have caught it.
  - Main never compares a roster row's hard-coded `x`/`z` with the source
    anchor. `settlement_sockets` (`r7_runtime.lua:654-657`) and
    `preparation_source` (`:101-102`) compare only `id`. A mismatch therefore
    surfaces only when the emerge script constructs, after main has already
    registered sockets and protection from the source anchor.
  - The anchor column check accepts `planned_water` (`:86`), but the support
    check refuses every liquid and any non-surface opcode (`:168-176`). An
    anchor whose column ever became planned water would crash. This does not
    happen today.
- **Impact:** A placement change that passes `quick`/`full` can still stop
  the server on the first chunk that touches the affected settlement, on some
  seeds only. Agents trust the fleet summary line (AGENTS.md "Seed fleet").
- **Better** (M): Extend `seed.lua` with a pure "settle smoke":
  - build the settlement configs as `r7_runtime` does;
  - run `config.new` for every settlement against the overlay session and
    planner source (x/z, floor, palette);
  - run `cells_of` once per lazy blueprint (identity and landmarks);
  - evaluate the anchor column-authority tuple per roster row.

  The support/root byte checks need the R6 writer and stay engine-only. Cost
  is about +1–2 s per seed (the compositions measured 0.4 s for POIs and
  about 2 s for the six capitals' plots in LuaJIT). Depends on MGS-10.
- **Verification (phase 2):** Confirmed — a Lua error in emerge is fatal (`reference_projects/luanti/src/emerge.cpp:624-625`, `setAsyncFatalError`). `seed.lua` stops at the roster/overlay (`tools/r28_zone_atlas/world.lua:114-119`), and AGENTS.md:892-903 still asks for a `quick` fleet on "world writer's logic" changes, so the trap is real. Two nuances. First, the `config.new` checks (x/z, city-edge floor) run when emerge constructs the successor (`r7_runtime.lua:475-512`), so they stop every boot of an affected seed, not the first chunk. Second, the historical crash depended on emerge order (`r7_anchor_activation.lua:101-108`), and the proposed pure smoke would not have caught it either.

### MGS-03 Plot-collar palette declared in two places, checked only at generation, rebuilt per chunk for all 118 settlements
- **Severity** Medium / **Category** Agent-trap, Perf / **Confidence** Verified (perf measured)
- **Location:** `r7_capital_blueprint.lua:113-125` and `r7_settlement.lua:1514-1522`; `wp13/palette.lua:790-830`
- **What:** The collar and approach materials enter the shared palette in
  `r7_capital_blueprint.lua`:
  ```lua
  for _, name in ipairs({p.node("ground"), p.node("subsoil"),
      p.maybe("castle_paving") or p.node("plaza"),
      p.maybe("castle_wall_stair") or p.node("roof_stair")}) do
  ```
  `settle` resolves the same four roles again at every call
  (`r7_settlement.lua:1515-1519`). `fit_write` fails with "plot approach
  material is outside settlement palette" (`:1521`) only when a capital chunk
  is generated. Editing one list and not the other passes the load and the
  seed fleet, then stops the server at the first capital chunk.
  - Separately, `approach_palettes.new(profile.race)` runs **for all 118
    settlements on every chunk**, far-away POIs included.
    `palette.new` validates every role with two linear `contains` scans
    (`wp13/palette.lua:826-830`). **Measured:** 0.76 ms per chunk under JIT,
    2.0 ms with `-joff` (118 handles plus four role lookups). A surface chunk
    costs about 300 ms of Lua (`round23-full-column-preparation.md:96-99`), so
    this is about 0.25–0.7 %.
- **Impact:** A latent crash for whoever edits collar materials, plus a small
  but pointless per-chunk cost.
- **Better** (S): Resolve the four refs once in `config.new` (only for
  settlements with `reference` blueprints) from one shared helper that
  `r7_capital_blueprint.source` also uses to build its name list. The check
  then fails at load, and `settle` stops building palette handles. No
  identity change.
- **Verification (phase 2):** Confirmed, severity changed to Low (W13-06 is the same issue). The same four roles appear at `r7_capital_blueprint.lua:118-121` and `r7_settlement.lua:1515-1519`. The perf claim holds: `palette.new` runs for all 118 roster settlements (the roster has 118 entries) on every non-air chunk. Re-measured (`v6/pal.lua`): 0.77 ms JIT and 2.04 ms `-joff` per chunk, 402 KiB of garbage. Low, because the failure is loud and names itself, `r7_capital_blueprint.lua:108-111` documents the coupling, and `refs` is built from the capital's whole palette union (`r7_settlement.lua:1181-1190`). A changed role therefore fails only if no core, plot or edge cell of that capital uses the node. The per-chunk cost is under 1 %.

### MGS-04 Three ways to bind a settlement to its anchor; three POI builders; five per-race material tables
- **Severity** Medium / **Category** Duplication / Legacy / **Confidence** Verified
- **Location:** `r7_settlement.lua:153-417` (starts, capitals, Round 14 rows with hard-coded `anchor_id`, `numeric_id`, `x`, `z`); `r20_poi_catalog.lua` (`number`, `x`, `z` per row); `r7_settlement.lua:452-487` (Round 31: resolved from `source.anchors` by zone and slot); `source/simple_map.lua:239-372` (the authority); the 18 nine-line stubs `r7_{copperfell,goldmead,starbough,mournfen,redtusk,raincall}_{village,outpost,bandit_camp}_blueprint.lua`
- **What:** The same position lives in two files for 100 of the 118
  settlements. Only Round 31 derives it.
  - Two generators build villages, outposts and bandit camps:
    `r14_poi_blueprint.lua` (the home zones) and `r20_poi_blueprint.lua`
    (everything else). Each has its own house builder, path logic and
    per-race palette (`r14_poi_blueprint.lua:49-62` vs
    `r20_poi_blueprint.lua:40-47`).
  - Two more per-race tables exist: Round 31 `FORT`/`CAMP`
    (`r31_pvp_poi_blueprint.lua:37-72`) and `road_writer.MATERIALS`
    (`:34-60`). Together with `wp13/palette.lua` races that makes five.
  - Round 20 catalog rows also repeat each profile's `building_core_width` as
    `width`. Only the dragon rows are tied to it by a fixture
    (`tools/r31_da2/portable_test.lua:53`).
- **Impact:** Moving an anchor, adding a POI or retuning a race's look means
  editing 2–5 places. Mismatches are mostly loud (emerge `config.new`; see
  MGS-02 for why "loud" is late). A wrong `width` is silent: cells would sit
  on unflattened collar.
- **Better** (M): Derive every roster row from `source.anchors` by
  (zone, slot) as `M.pvp_profiles` does. Generate the Round 14 rows and stubs
  from a small table like `r20_poi_catalog`. Take POI `width` from the anchor
  profile. Long term, merge the Round 14 and Round 20 builders behind one
  house/path kit and one race material table. Identity bytes change only if
  compositions change; roster order must stay (the manifest order).
- **Verification (phase 2):** Confirmed — Round 14 rows hard-code `anchor_id`/`x`/`z` (`r7_settlement.lua:382-416`), Round 20 rows copy them from `r20_poi_catalog.lua` (`:420-433`), and only Round 31 derives them from `source.anchors` (`:452-487`). The per-race tables are at `r14_poi_blueprint.lua:47-60`, `r20_poi_blueprint.lua:40-47` and `r31_pvp_poi_blueprint.lua:37-72`. The x/z mismatch check (`:1214-1220`) runs when emerge is constructed, so it fails on every boot, early and loudly. Medium stands for the duplication.

### MGS-05 Capital, start and anchor-table magic numbers repeated across files
- **Severity** Medium / **Category** Agent-trap / **Confidence** Verified
- **Location:**
  - **Reserved square 266/532:**
    - `source/simple_map.lua` `hard_capital_city_v1 bound_width=532`
    - `r7_settlement.lua:103` (`±266`)
    - `capital_protection.lua:45` (`BOUND_HALF = 266`, half-open, while `r7_settlement` is inclusive)
    - `capital_planner.lua:55, 60` (`HALF = 256`, `BAND = 26`, comment "within 230")
  - **Civic core 48/49/52/96:**
    - `capital_planner.lua:56-58` (`CORE = 48`, `CORE_GATE = 49`, `CORE_KEEP = 52`)
    - `r7_settlement.lua:77` (`capital_core ±49`)
    - `r7_settlement.lua:1537` (`math.abs(lx) > 49`, a literal, not read from `M.BOUNDS`)
    - `r7_capitals.lua:197` (`along >= 46 and along <= 49`)
    - `r7_capitals.lua:235` (`built = 96 * 96`)
    - `simple_map.lua` `civic_width = 96`
  - **Anchor table layout:**
    - `r7_anchor_roster.lua:23` (`#source.anchors ~= 118`), `:78-81` (`7..12`, `25..48`, `49..60`, `42`, `6`/`24`/`12`)
    - `r7_zone_overlay.lua:119, 136` (`42`, `36`)
    - `source/simple_map.lua:502` (`for anchor_index = 1, 12`)
  - **World bounds:** `±3740/±3340` in `world_protection.lua:50`, `height.lua:82` and the same bounds in `zones.lua`
- **What/Impact:** Each constant encodes one fact in several modules. Most
  violations fail loudly at load (the reserved-square checks, the roster
  counts). Some do not:
  - The literal 49 at `:1537` silently decides which columns get plot
    collars.
  - `core_landing`'s 46..49 silently decides whether an avenue starts at the
    core.
  - Adding one anchor anywhere but the end of `anchor_rows` renumbers every
    later anchor, which breaks the hard-coded Round 14 and Round 20 ids
    (MGS-04).
- **Better** (S–M): Publish the facts once (for example
  `source.capital = {reserved_half, core_half, ...}` and roster index ranges
  derived from `template_id`/`slot_id`) and read them everywhere. Replace the
  literal 49 with `M.BOUNDS.capital_core.max.x`. No identity change.
- **Verification (phase 2):** Confirmed — the literal 49 is at `r7_settlement.lua:1537` next to `M.BOUNDS.capital_core` ±49 (`:77`). Also confirmed: `along >= 46 and along <= 49` at `r7_capitals.lua:197`, `96 * 96` at `:235`, `BOUND_HALF = 266` (`capital_protection.lua:45`) against `HALF = 256`/`BAND = 26` (`capital_planner.lua:55,60`), `#source.anchors ~= 118` and the index ranges 7..12/25..48/49..60 (`r7_anchor_roster.lua:23,78-81`). The silent cases are as described.

### MGS-06 Start cook/oven sockets hard-coded twice, by two different rules, with no clearance check
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
- **Location:** `r7_settlement.lua:130-137` (`START_TRAINERS`), `:1144-1155` (`quest_cook` at `(2,1,±13)`, `cook_oven` at `(4,1,±13)`); `r20_civic.lua:30, 38-39` (air at `x=1..2`, furnace at `(4,1,z)`)
- **What:** `r20_civic` chooses the side by race
  (`dwarf/human/elf → +13`). `sockets` chooses it by the sign of the trainer's
  z (`position.z > 0 and 13 or -13`). The two agree today because the three
  +z trainers are the dwarf, human and elf starts. These sockets bypass the
  composition: nothing checks that `(2,1,±10)` or `(2,1,±13)` is air on solid
  ground.
- **Impact:** A start re-layout can put a trainer or cook inside a wall
  without any load error.
- **Better** (S): Author these three sockets in `r20_civic.lua` as landmarks
  next to the cells it edits, with one side rule, and add a clearance check
  (air at y 1–2, solid at y 0) at socket compilation for anchor blueprints
  whose cells are at hand.

### MGS-07 PvP fortress gate side computed twice; only one copy honours a `turns` override
- **Severity** Low / **Category** Duplication / **Confidence** Verified
- **Location:** `r7_settlement.lua:445-450` (`pvp_gate_turns`, with `row.turns` override); `road_layout.lua:2630-2637` (`gate_x`/`gate_z` by the sign of x and `fac == "elandor"`)
- **What/Impact:** The two agree for every row today, because no row sets
  `turns`. A `turns` override in `r31_pvp_catalog.rows`, which the code
  explicitly supports, would turn the gate while the trail still leaves
  toward x = 0 and meets the wall. Each copy also uses its own faction
  vocabulary (accord/throng vs elandor/kragmar).
- **Better** (S): Let `road_layout.inputs` ask `pvp_gate_turns` (or a shared
  pure helper in `r31_pvp_catalog`) and turn the unit vector.

### MGS-08 The terrain-damage guard (`world_alterable`) does not cover roads or POI boxes
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
- **Location:** `grug_core/protection.lua:39-59`; `water_guard.lua:24-32`; `zone_authority.lua:490-500, 518-535`
- **What:** `world_alterable` is the territory rule (`accord_home`,
  `throng_home`, `contested_land`) plus registered guards. Towns, capitals
  and the 36 anchor columns are covered (`hard_protected`,
  `r7_zone_overlay.lua:156-158`). The Round 25 layer of roads and the 106
  village/camp/POI/fortress boxes (`world_feature_at`) is only in
  `world_protected_for_faction`, that is, dig/place. BACKLOG WP46 records
  this ("a future consumer must"). The auto-memory note for the guard and
  WP46 step 1, however, name `world_alterable` as *the* guard.
  - Today the gap only lets planned and bucket water flow into village cores
    and onto roads, because the water guard asks `world_alterable`.
  - Nothing in the game burns or explodes.
  - Cost is a non-issue: one territory query plus a short guard list per
    liquid event.
- **Impact:** The first fire or explosion lane that calls `world_alterable`
  as documented would leave every POI core and road destructible.
- **Better** (S, when WP46 is scheduled): Add `world_feature_at(pos) == nil`
  to a new `grug_core.terrain_damage_allowed(pos)` and point the memory
  note, WP46 and `world.md` at that one predicate. Keep `world_alterable` for
  water. Decide whether water may enter POI cores (Open question 2).

### MGS-09 The dragon arena's protection box comes from four written air cells
- **Severity** Low / **Category** Legacy / **Confidence** Verified (effect Plausible)
- **Location:** `r20_poi_blueprint.lua:60-69`; `world_protection.lua:129-152`; `r7_settlement.lua:627-631`
- **What:** Protection boxes are the blueprint's **cell** bounds, and
  `prepare_cells` requires the declared bounds to equal the cells' actual
  extent. To make the protected box cover the 82-node arena, the blueprint
  writes `air` at `(±41/40, 12, 0)` and `(0, 12, ±41/40)`. Where the collar
  terrain at the arena edge is 12 or more above the floor, that punches a
  one-node hole into the slope at four points per arena. That terrain is
  unlikely on the fitted terrace, so the effect is plausible but not
  observed.
- **Better** (S): Let a blueprint declare a protection box separate from its
  cell bounds (a landmark such as `protect = {min, max}`), read it in
  `settlement_boxes`, and drop the four cells. Check the dragon blueprint's
  identity change against `tools/r36_w` baseline rules.

### MGS-10 The seed fleet and three other tools hand-mirror `r7_runtime`'s assembly
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
- **Location:** `tools/r28_zone_atlas/world.lua:21-127` (used by `tools/seed_fleet/seed.lua`), `tools/r27_minimap/world.lua`, `tools/r26_capitals/world.lua`, `tools/r25_capital_plots/harness.lua`. Copied details include the start-ground twin table (`world.lua:46-52` vs `r7_runtime.lua:194-213`) and the capital canal/protection join order (`world.lua:89-107` vs `r7_runtime.lua:309-340`).
- **What/Impact:** A change to the construction order in `r7_runtime` (a new
  layout, a different join order, a new start-ground rule) must be repeated
  in each copy. Otherwise the fleet proves a world the game never builds.
  Nothing detects drift.
- **Better** (M): Split `r7_runtime`'s pure layout and session assembly
  (everything before `build`) into one module that takes the SHA seam and an
  optional engine table, and have the tools call it. That module is also the
  natural home for the MGS-02 settle smoke.

### MGS-11 `pairs` order varies per Lua state under LuaJIT; one POI builder sorts its palette with locale `<`
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified (measured)
- **Location:** `r14_poi_blueprint.lua:391-392` (`table.sort(palette)`); validated in byte order by `r7_settlement.lua:564-567`
- **What:**
  - **`pairs` order.** Three runs of the same 10-key table under
    `/usr/bin/luajit` (2.1.1767980792) gave two different `pairs` orders
    (scratch `order.lua`). Main and emerge are separate Lua states, and the
    lazy-rebuild check compares main's SHA with emerge's, so a composition
    whose output depends on `pairs` order over string keys would stop the
    server. I checked every `pairs` in this lane's placement code (Round
    14/20/31 builders, `r20_civic`, `arena_layout`, `road_layout`,
    `capital_planner`, `r7_capitals`): each one feeds a set or is sorted
    afterwards. The rule is not in `docs/research/luanti-lua.md`.
  - **Locale sort.** `r14` sorts its palette with Lua `<`. LuaJIT compares
    with memcmp, but the required PUC 5.1 fallback uses `strcoll`, and
    Luanti sets `LC_ALL` from the environment
    (`reference_projects/luanti/src/gettext.cpp:223`). I found no current
    name pair that collates differently in `de_DE`. A future pair where `_`
    meets a letter at the same position (for example `x_b` vs `xa`) would
    fail the load on PUC with a non-C locale.
- **Better** (S): Sort with the shared `less_bytes` (MGS-12). Add "never let
  `pairs` order over string keys reach output; LuaJIT randomizes it per
  state" to the luanti-lua.md do-not-write list.

### MGS-12 Byte-order compare and z/y/x cell sort copied 8+ times
- **Severity** Low / **Category** Duplication / **Confidence** Verified
- **Location:**
  - **`sort_cells_zyx` copies:** `r20_civic.lua:6-27` and `r20_poi_blueprint.lua:6-27` (both copied from `wp13/parts.lua`)
  - **Inline byte comparators:** `r20_civic.lua:51-54`, `r20_poi_blueprint.lua:246-249`, `r31_pvp_poi_blueprint.lua:423-426`
  - **`less_bytes` copies:** `r7_settlement.lua:495-506`, `r6_hash.lua:47`, `r7_p9g.lua:66`, `r7_content.lua:163`, `layout_cache.lua:35-41`
  - **Unsorted outlier:** `r14_poi_blueprint.lua:392` (MGS-11)
- **Better** (S): One `bytes.lua` (or `parts.less_bytes` / `parts.sort_cells_zyx`) used by every builder. No identity change, because the order is the same.

## Hot-path inventory

| Path | Frequency | Cost class | Notes |
|---|---|---|---|
| `air_chunks.untouched` (`air_chunks.lua:63-73`) | every chunk above water level | O(6400) heightmap scan; first call per footprint scans the envelope (≤ 3.2 ms measured in Round 23), then memo | fine |
| successor `bind_plan` (`r7_successor.lua:76-84`, `r7_settlement.lua:1447-1474`) | every chunk | ≈ 430 box tests (118 settlements plus about 300 capital plots) | fine |
| `road_writer.dress` (`road_writer.lua:172-236`) | every chunk at **every** height, deep ones included | 6400 `road_column_at` per chunk (coordinate checks plus a column memo lookup) | cheap per call; a y-cull per column range would skip underground chunks, but it is not worth a finding |
| anchor activation `settle` (`r7_anchor_activation.lua:67-233`) | every chunk; work only if an anchor root lies in the owner | O(42) | fine |
| settlement `settle` × 118 (`r7_settlement.lua:1476-1634`) | every chunk | per settlement: footprint string, **palette handle (MGS-03: 0.76 ms JIT / 2.0 ms interpreter per chunk in total)**, ledger table | only the palette part is avoidable |
| active blueprint cell loop (`:1569-1595`) | chunks overlapping a start, core, plot or POI box | O(all cells of the blueprint) per overlapping chunk: a start is about 63 k cells, a core about 100 k; stub micro-run 0.67 ms JIT / 4.0 ms interpreter per 54 k-cell pass | fine; it could bucket cells by chunk if starts grow |
| plot collars (`:1529-1566`) | first chunk of each footprint inside a capital's ±266 square; later chunks are y-culled by `write_span` | 6400 `plot_approach.surface` probes (one string key each) plus column queries | fine |
| city edge overlay (`:1596-1619`) | same culling | `city_edge.cells(rect)` | fine |
| lazy rebuild (`cells_of`, `:1337-1387`) | first touch after > 64 idle plans | composition + validation + SHA + turn + ref copy. Measured compositions: about 0.10 s per core and 0.18–0.25 s per capital's plots (6 capitals: 304 plots, 2.12 M cells) | about 1–2 rebuilds per blueprint per full preparation sweep (z-x tile rows); fine |
| `arena_writer.dress` (`arena_writer.lua:202-246`) | every chunk; work only over the two 81 × 81 arenas | `hazard_at` per column | fine |
| `world_protection.kind_at` (`world_protection.lua:275-339`) | every dig/place (`core.is_protected`), every mob probe (`roam_avoid`, 8 probes every 4–5 s per mob), spawn checks | 128-node index, then ≤ 16-segment runs per candidate | fine |
| `world_alterable` (`protection.lua:56-59`) | every guarded liquid flow event | territory rule plus guard list | fine |
| load (main, first start) | once per world | water, road and capital layouts (cached afterwards), all compositions (≈ 0.4 s POIs, ≈ 2 s capitals in LuaJIT), protection index | the transient boot heap includes MGS-01's copies until `init.lua`'s collection |
| load (emerge) | every boot | all non-capital compositions are built again (MGS-01); the handover saves only hashing | see MGS-01 |

## Bug-prone areas

- **Successor order.** Roads, then P9G, world content, anchors, settlements
  and arenas. Each later pass overwrites earlier ones, and the anchor asserts
  read the bytes the earlier passes left. Moving a pass, or letting a road
  or plant reach an anchor root, crashes the generation (MGS-02).
- **Lazy identity.** Any composition change that makes output depend on
  anything but its inputs (iteration order, time, a mutable shared table)
  crashes the first touch in emerge, not the load (MGS-11).
- **`reserve_anchor_root`** must hold air at `(0,1,0)` and sit where the
  anchor writer runs. It is set blanket on all Round 20 and Round 31 rows
  (`r7_settlement.lua:433, 481`), although only anchors 7–12 and 25–60 carry
  a node.
- **POI fitting** (`height.lua:851-907`). The core height is the lower median
  of the natural ground with no cut/fill limit; the collar is clamped to
  6..28 nodes whatever the step. On steep ground this gives steep ramps, and
  roads may drop their core pin (a logged step). Only Round 31 rows have a
  relief rule (≤ 40, chosen offline).
- **Capital plots vs final ground.** Plots are placed on the planner's sample
  before the streets' cut and fill. The terrain audit is off by default
  (`r7_loader.lua:287-312`).
- **Two roster vocabularies** (accord/throng vs elandor/kragmar, slot strings
  vs template ids) meet in `world_protection.settlement_kind` (slot regex),
  `road_layout.inputs` and `pvp_gate_turns`.

## Noted (no action)

- **N-1 `C_STEP` 0.5** (`road_layout.lua:79-84`) is inherited by the capital
  streets and connectors (`capital_planner.lua:252-263` does not override it;
  `with_params` copies `DEFAULT_P`, `road_layout.lua:2799-2803`). The commit
  and `world_zones.md` mention roads only. It is not a defect: it only shapes
  profiles and does not change feasibility. Header comment, inline comment
  and design doc agree ("0 on the measured seeds").
- **N-2** `IDLE_RELEASE = 64` (`r7_settlement.lua:126`) is reasoned in "plans
  walking clear of a capital". Full-column preparation runs about 8.5 chunks
  per tile, so 64 plans are about 7.5 tile columns, roughly one capital
  width. That is still sane.
- **N-3** `preparation_identity.lua:9-19`'s default file list is hand-kept,
  while the layout cache digests the whole tree. The full-preparation guard
  (`starts_preload.lua:101-104`) therefore misses composition changes that
  keep the boxes. Fresh-server mode makes this moot.
- **N-4** `r7_anchor_activation.lua:86` accepts `planned_water` columns that
  the support check would then refuse. No anchor is on planned water today.
- **N-5** `capital_protection` is half-open (`>= H`, `:159`), while
  `r7_settlement`'s overlay square is inclusive (`:103`). The 36-node slack
  hides the difference.

## Open questions for Jan

1. Was the `quick` seed fleet run after `e0933651`? The AGENTS.md rule from
   `0f169898` asks for it on road changes. Should the capital street log
   figures (unpinned, infeasible) be compared before and after, since
   `C_STEP` changed them too?
2. Water may currently flow into village, camp and POI cores and onto roads
   (only towns and capitals are guarded). Keep it that way until WP46, or
   extend the water guard now?
3. Is about +1–2 s per seed acceptable for a pure settle smoke in the seed
   fleet (MGS-02)?
4. MGS-01 is worth roughly 300–400 MiB of the emerge heap and part of its
   0.4–0.7 s GC pauses. Is server memory a concern for the target host, or
   should this wait for WP48?
