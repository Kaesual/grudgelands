# Round 22 Phase 0 audit: what goes, what stays, what the rebuild removes

Date: 2026-09-25. Read-only audit for [the Round 22 plan](../planning/round22-natural-world-plan.md)
(§6 Phase 0). No repository file was changed apart from this document; nothing
was deleted. Base: `main` at `082982da`.

Verdicts used throughout:

- **keep**: stays after the gate.
- **retire**: removed in the single mechanical deletion commit after the gate.
- **dies-with-rebuild**: removed or replaced by the Phase 3–5 lane that
  rebuilds that module. It is not deleted up front, because the running game
  still needs it until that lane lands (D4).

## Summary

| Quantity | Measured |
|---|---|
| `tools/` tracked | 7,585 files, **429 MB**, 238,386 code lines (lua/py/sh/c), 4.05 M text lines incl. logs/TSV |
| `tools/` untracked (gitignored, **not in git history**) | `tools/wp40/results/` **864 MB**, `tools/bin/` 0.4 MB (regenerable) |
| Proposed `tools/` keep set | 63 files, **4.4 MB**, 11,700 code lines |
| Proposed `tools/` retire | ~7,520 files, **~425 MB tracked**, ~226,700 code lines (+ 864 MB untracked, see Q2) |
| `wp40/` modules loaded at runtime (load trace) | 76 files, 34,966 lines |
| `wp40/` modules **never loaded** at runtime (retire) | **15 files, 18,634 lines, 842 KB** |
| Runtime consumers of `neighbors(id)` / `travel_links(id)` | **0 / 0** (only design text claims them) |
| Runtime consumers of `nearest_route_at` / `nearest_hydrology_at` | 0 / 0 outside the mapgen session |
| Gameplay-mod consumers of routes, hub stations, ingress corridors | 0 direct. Indirect: protection via `territory_rule_at` (ingress is `hard_protected`); quest text assumes roads |
| Gameplay-mod consumers of hydrology | 3 via `water_class_at == "planned_water"` (reed angelfish, mounts, gathering shore classes) |
| Gameplay-mod consumers of `holy_grounds` | 3 via the per-zone `territory_rule` (protection, mounts, atmosphere). None uses the rectangle |
| Landmarks | 70. Player-visible names: **3** (Kezamba cenote, Wyrmglass Dragonspire, Stormscale Dragonroost). Design-prose names: 16. Mapgen-only: 18. Unreferenced: 33 |

Headline findings:

1. **D14 needs no consumer migration.** Nothing in `mods/` calls
   `neighbors(id)` or `travel_links(id)`. The route-derived adjacency is exported
   only by `grug_zones`. Geometric adjacency can replace it, or it can be dropped
   (Q4). The "57 authoritative edges" rule lives only in design text
   (`world_zones.md` §9, `world.md` §2c), which the Phase 1 rewrite already
   targets.
2. **Quest text is the real road consumer.** It assumes roads for
   start→village (6 quests), start→capital (6) and capital→outpost/mine
   (20 "leaving the road" texts). D9's network (capitals, starts, villages)
   covers the first two. Outposts get trails (D19).
3. **The in-game world map is a pre-rendered PNG**
   (`grug_map_atlas_world.png`). `tools/r14_map/render_atlas.lua` draws it from
   `source.routes`, `island_routes`, zones, bays, islands and land primitives,
   so it goes stale with Phases 2b/3/4. The renderer is in the keep set.
4. **`source/catalog.lua` (3,058 lines, the old T2 catalog) is runtime-loaded
   for only 10×3 rare-mob patrol offsets** (`r7_consumer_payload.lua:78`). Its
   landmark, hydrology and tunnel tables are inert. This is a candidate for the
   D4 cleanup.
5. **Integer seam.** `grug_core/zone_authority.lua` requires integer anchor
   coordinates and an integer `terrain_height_at` at rare patrol points
   (`integer(y, …)`, :299). Its fail-closed load checks also require outposts to
   stay in their race region and anchors to stay in their zone. Float height
   (D2) and a stronger border warp (R7) must respect this seam.
6. **A banked-patch trap.** `tools/wp40/results/` is untracked. It holds three
   banked T2 patches, bay-transition briefs and reports that exist nowhere else,
   and 441 MB of T2 census raw data. Deleting it cannot be undone (Q2).

## 1. `tools/**`

**The running game needs nothing under `tools/`.** Measured three ways:

- `tools/sync_to_luanti.sh` copies only `mods/`, `game.conf`, `minetest.conf`,
  `settingtypes.txt` and `menu/`.
- `grep -rnE '(dofile|loadfile|require|io\.open)[^\n]*tools/' mods` finds 0 hits.
- The only non-comment `tools/` string in `mods/**/*.lua` is an error-message
  text (`r7_loader.lua:121`).

There is no CI, Makefile or hook (`git ls-files | grep -iE 'makefile|\.github|ci\.yml|hooks'` finds nothing).

### 1.1 Keep

| Item | Size | Reason / consumer |
|---|---|---|
| `luanti_headless.sh` | 151 lines | §5 smoke test. Also used via `PROBE=` by other harnesses |
| `sync_to_luanti.sh` | 27 lines | Delivery to the user's Flatpak (AGENTS.md, README, wp-workflow) |
| `build_lua51.sh` + untracked `bin/` | 49 lines; 0.4 MB, regenerable | AGENTS.md mandates `luac51 -p` on every Lua change. D1 suspends PUC *runs*; whether it also suspends this parse gate is Q3 |
| `r20/check_lua.sh` (extract to top level) | 31 lines | The only generic runner of `luac51 -p`, SETGLOBAL and the five `luanti-lua.md` sweeps |
| `check_fresh_server.py` | 42 lines | Optional. A cheap guard against reintroduced legacy/migration code (fresh-server rule) |
| `wp40/r6/common.lua` (optionally cut to ~70 lines: `read_file`, `hex`, `new_sha256`) | 229 lines | **External dependency:** `~/projects/grudgelands-orchestration/r22/terrain-probe/probe.lua` (`new_sha256`, `read_file`), `r22/prototype-b/zones_today.lua` and `r22/prototype-zones/today.lua` dofile it. Offline harnesses need it to inject `raw_sha256` into wp40 modules. It depends on no other tool file; it needs LuaJIT FFI + `libcrypto`, with a `sha256sum` fallback. Also used by ~150 tracked tool files that retire |
| `r19_preparation_fullspeed/` `run_native.py`, `instrument.py`, `compare.py` (`analyze()` only), README | ~1 k lines | **The method behind the ~240 ms/chunk baseline** (guardrail 5): 135.07 s / 561 tiles. It copies the *current* game, so it can be re-run against new mapgen. Its only pin is `--production-sha256`, checked against `grug_core/starts_preload.lua`, whose hash (`858df635…`) is unchanged. `compare.py main()` cannot be re-run: it asserts the frozen baselines. It needs `tools/bin/luac51` and a world under `tools/wp40/results/` (asserted, `run_native.py:72`). Whether ≥561 tiles still exist after the layout changes is unverified |
| `wp40/profile/` minus `evidence/` and the stale stage patch | ~0.1 MB | Real-engine per-mapchunk profiler. `git apply --check instrument-mapgen.patch` passes on today's tree; `instrument-settlement-stages.patch` does not. It needs re-anchoring after Phase 3 rewrites the callback, and a launcher that forwards the scratch user path |
| `r14_map/render_atlas.lua` | 1 file | Regenerates the in-game world-map PNG (headline 3). Must be ported to the new zone, coast and road data |
| Asset generators cited as provenance by 15 `LICENSE-media.md` files | ~25 files | See list below. Deleting them orphans licence rows |
| Capital-iteration kit from `wp13/` (for the §11 follow-up): `render_blueprint.py`, `preview.py`, `render_terraces.py`, `README-render.md`, `dump_blueprint.lua`, `dump_capital_plan.lua`, `dump_capital_part.lua`, `extract_tiles.py`, `node_tiles.json`, `run_capital.sh` + `capital_probe/`, `stub_registry.lua`, `capital_lots.lua`, `capital_wall.lua` | ~2 MB | Q5. `run_capital.sh` passes with missing digest pins (it records "unfrozen"). Whether it survives the height rebuild is unverified |

Asset generators cited in `LICENSE-media.md` files:

- `gen_mob_item_textures.py`
- `branding/`
- `wp13/gen_weapon_ladder.py`, `wp13/gen_character_visuals.py`
- `wp26/gen_dual_furnace_textures.py`
- `r8_mob1/gen_boss_art.py`, `r9_boss/gen_guard_skins.py`
- `r10_art/`: `build_armor_assets.sh`, `build_boar_tusk.sh`,
  `import_crop_stages.sh`, `build_crop_stage_sheet.py`,
  `import_harvest_icons.sh`, `render_mount_icons.{sh,py}`
- `r12_art/`: `build_assets.py`, README, `sources/`
- `r12_farming/`: `build_corn_segments.sh`, `build_family_silhouettes.sh`
- `r15_map/render_headings.py`
- `r18_art/manifest.json`
- `wp40/quality/build_gravewood.py`

The keep set measures **63 tracked files, 4.4 MB, 11,700 code lines**, with every
path above resolved against `git ls-files tools`. An optional move to e.g.
`tools/assets/` would require editing the 15 licence files; staying in place
needs no edit.

Not in the keep set, but reference material for the §5 visual tool:
`wp40/quality/terrain_views.lua` + `plot_terrain.py` (hillshade before/after),
`wp40/road_polish/measure.lua` (road step check), `wp40/water_road/measure.lua`.
All three bind to today's fixtures, and git keeps them.

### 1.2 Retire

| Group | Directories | Size (tracked) | Why it can go |
|---|---|---|---|
| wp13 evidence | `wp13/evidence/` (4,346 files) | **323 MB** | Round evidence (logs/TSV/PNG) |
| wp13 KATs, probes and per-capital gates | ~30 KATs (blueprint, library, seam, start_npcs, settlement_sockets, gear_catalogue, route_gates, lane_*, precinct_ring, street_kat, …), `*_kat`/`*_plots`/`*_lots`/`*_identities` per capital, bush/npc/npc_load/weapon/highcourt probes, `run_highcourt.sh`, `run_engine.sh` + `engine_cases.lua`, `final_micro.lua` | ~1.5 MB | KAT/digest gates (§5 dropped) |
| WP40 T0–T2/simple-map oracles | `wp40/t1_*`, `t2_*`, `run_t*`, `simple_map_r2..r5*`, `v1e*`, audits, `fixtures/` (11 MB), `evidence/`, `r6/` (except `common.lua`), `r7/`, `r8/`, `quality/` (except `build_gravewood.py`), `resource_sampling/`, `dungeon_probe/`, `runtime_probe/`, `tree_slices/`, `water_road/`, `road_polish/`, `planner_throughput/`, `cb1_*`, README | ~19 MB, ~100 k code lines | Census/partition/PUC/digest oracles (D3, §5). The README calls itself a "historical exact-T2 harness" |
| Old mapgen round harnesses | `r8_map_a`, `r9_map_c`, `r10_map_b`, `r10_world`, `r10_capital_phase`, `r11_world`, `r6_shore`, `r6_start_band`, `r7_level_bands`, `biomecheck` | ~13 MB | Bound to today's height authority. `biomecheck` models the retired Lua-biome layer |
| Round-final composites and integration evidence | `r10_integration` (25.6 MB), `r11/12/13/14/15_integration`, `r13_stations`, `r14..r19_final`, `r20`, `round21` | ~33 MB | Registration smoke is covered by `luanti_headless.sh` |
| Gameplay KATs of finished rounds | `r5_*`, `r6_balance`, `r6_food_buffs`, `r6_hotfix`, `r7_food`, `r8_alch/cook/prof/tags`, `r9_ench/farm/prof/trinkets/ui/mounts`, `r10_equip/farm/gameplay/engine`, `r11_combat/farm/gear/repair/scout_traders/vegetation/followup/game`, `r12_food/recipes/skills`, `r13_enchants/equipment`, `r14_fishing/fixes/map (except render_atlas)/parties/quests/selection/ui`, `r15_quests/ui_followup`, `r16_*`, `r17*`, `round17`, `r18_*` (except `r18_art/manifest.json`), `r19_hud/idle_health/map/pursuit/ui`, `r20_input/ux`, `r21_aquatic/furnace`, `wp11`, `wp26` (except generator), `wp39`, `wp43`, `wp45`, `ui` | ~3.7 MB, ~36 k code lines | KATs of accepted rounds (§5 dropped) |
| Probes and review galleries | `spawn_probe`, `r9_mob2`, `r14_pregen`, `r16_surface`, `r18_preparation`, `r15_hud`, `r10_cap` (15 MB), `r11_art`, `r14_poi`, `r15_poi` (6.5 MB), `r20_pois`, and the gallery parts of `r10_art`/`r12_art`/`r18_art` | ~26 MB | One-off probes/renders |
| Performance baselines | `r9_perf`, `r19_preparation_budget`, `r19_preparation_diagnosis` | ~6 MB | Frozen old baselines. The current method stays (1.1) |
| Evidence-only | `r11_interaction`, `r11_scout`, `r12_pose`, `r12_ui`, `docs/check_api_citations.lua`, untracked empty `r14_story/` | 0.1 MB | Logs only / historical helper |

Retire deletions also require text edits in live docs. These cite retiring
tools and must change in the same commit:

- AGENTS.md: resource_sampling, `quality/final_micro.lua`, `wp13/run_engine.sh`, WP40 profiler wording.
- `docs/process/cross-cli-orchestration.md`: `run_engine.sh`, `final_micro.sh`, `r7/micro_kat`, `r6/run.sh`, `wp11/static.sh`.
- `docs/technical/module-guide.md`: "tools/wp39 … must stay green".
- `docs/design/skill_trees.md`: wp11, r19_ui, r19_final.
- `docs/design/items_crafting.md`: `wp13/gear_catalogue_kat`.
- VENDOR.md: `wp11/run_cadence_probe.sh`, `wp26/smelting_kat`, `wp13/decor_registry_kat`.
- BACKLOG.md: `r9_map_c/evidence`, `wp40/r7/source_audit.sh`.
- `docs/STATUS.md`: link to `tools/r20/evidence/pois/index.html`.

Code comments in `mods/` that cite tool paths (about 40, e.g.
`wp13/avenue.lua:35`) are harmless and can go in the D4 cleanup.

### 1.3 Untracked `tools/wp40/results/` (864 MB, not recoverable from git)

| Entry | Size | Note |
|---|---|---|
| `t2_census/` | 441 MB | T2 census raw TSVs (2026-08-19). T2 is retired |
| `payload-cache/` | 342 MB | Regenerable cache |
| `preparation-fullspeed-*`, `preparation-budget-*`, `pregen-cpu-diagnosis-*` | 3 × 20 MB | Disposable worlds. Receipts are tracked |
| `step2-/step2b-sweep-artifacts/`, `step3-gap-artifacts/`, `r8/` (12 of 13 dirs untracked-only), `t0-baseline/`, run logs | ~21 MB | T2/R8 evidence cited by research docs |
| `bay-transition-package-w11-stop-artifacts/`, `bay-transition-package-stop-artifacts/`, `bay-transition-2c-stop-artifacts/` | ~0.5 MB | **Banked patches.** None applies (forward or reverse) to today's tree. The accepted attempt landed as `931e8578` |
| `attachment-anatomy-artifacts/` | 1 MB | Contains scripts (`analyse.py`, `report.py`, `run-fleet.sh`) that exist only here |
| 24 top-level `.md`/`.sh`/`.conf`/`.tsv` briefs and reports | ~0.25 MB | Unique documents. `wp40-t2-contracts.md` cites several |

`r19_preparation_fullspeed/run_native.py` needs the *directory*
`tools/wp40/results/` to exist; it does not need its contents.

## 2. `wp40` modules never loaded at runtime

**Method: a load trace.**

1. A disposable `GAME_PATCH` wrapped the global `dofile`/`loadfile` at the top
   of `grug_mapgen/init.lua` (main environment) and `wp40/r7_mapgen.lua` (emerge
   environment) and logged every path.
2. One isolated boot ran:
   `LC_ALL=C KEEP=1 SEED=15140735923413111218 GAME_PATCH=… tools/luanti_headless.sh 240`.
3. Result: PASS, 0 `ERROR`/`ModError`, 2,779 trace lines (1,469 main,
   1,310 emerge). World preparation ran, so the emerge-side writer executed.
4. Cleanup: the temp directory was removed and `pgrep -f '^luanti.bin'` was
   empty afterwards.

`r7_mapgen.lua` is loaded by the engine through `register_mapgen_script`, so it
counts as loaded. All 70 `wp13/` files were loaded.

Cross-checks:

- Every non-comment `dofile`/`loadfile`/`loadstring` in `mods/` was listed.
- The dynamic loads all resolve to traced files:
  - `r7_runtime.lua:180` (`profile.blueprint_file`)
  - `r7_wp13_library.lua:49`
  - `r7_runtime.lua:366-370` (`preparation_source`/`preparation_identity`)
- `compiler.lua:146` loads a dynamic `impl_path`, but `compiler.lua` itself is
  never loaded.
- The 15 basenames were grepped in every loaded file and every gameplay mod with
  `[\"/]NAME(\.lua)?[\"]|/NAME\.lua|\bNAME\s*=\s*dofile`. The only hits were
  unrelated string values (`"template"`, `"exact"`, `"boundary"`).
- `preparation_identity.lua` hashes 15 source files via `io.open`. None of the
  15 unloaded modules is in its list.

| Module | Lines | Purpose (file header) | Used by | Verdict |
|---|---:|---|---|---|
| `geometry/partition.lua` | 8,812 | T2 partition compiler | tools/wp40 T2 only (26 files) | retire |
| `validation/t2_source.lua` | 4,815 | Stage-1 validation of the T2 authored catalog | tools (28) | retire |
| `geometry/extreme.lua` | 934 | T2 extreme-corpus selector | tools (14) | retire |
| `geometry/boundary.lua` | 708 | T2 S1 boundary materialization | tools (24) | retire |
| `geometry/raster.lua` | 506 | T2 rasterization/displacement | tools (25) | retire |
| `geometry/exact.lua` | 433 | Exact rational geometry for the T2 compiler | tools (32) | retire |
| `geometry/template.lua` | 404 | T2 terrain-template primitives | tools (2) | retire |
| `geometry/relief.lua` | 378 | T2 relief/landmark masks | tools (4) | retire |
| `validation.lua` | 364 | Stage 1/2/3 validation + IPC seam of the T2 design | tools (1) | retire |
| `geometry/authored.lua` | 343 | T2 projection of the authored source | tools (2) | retire |
| `compiled_schema.lua` | 291 | T2 compiled-world projection | tools (9) | retire |
| `compiler.lua` | 288 | T2 compile entry (fails closed until T2 installs it) | tools (3) | retire |
| `analytic_record.lua` | 160 | T2 record shaper | tools (2) | retire |
| `seed_corpus.lua` | 114 | Fixed 32-seed corpus | tools (37) | retire |
| `init.lua` (wp40) | 84 | Pure foundation loader used by offline harnesses | tools (4) | retire |
| **Total** | **18,634** | | | |

Every user of these modules is in the tools retire set. About 50 research docs
mention them as history; git keeps that history.

Runtime-loaded but nearly inert: `source/catalog.lua` (3,058 lines). The only
field read at runtime is `anchors[91..100].patrol_offsets`
(`r7_consumer_payload.lua:78`). **Keep for now.** For the D4 cleanup, move the
30 patrol points into `source/simple_map.lua` and retire the file.

## 3. Embedded fail-closed / evidence / digest code in the rebuilt modules

Measured per section: `grep -c` of `fail(`, `evidence`, `digest`, `kat` and
`sha256` inside line ranges. Word counts overstate what can go:
`derived_water_evidence` in `height.lua` is a *functional* object (coast profile,
`landmark_excluded_at`), not a ledger.

At runtime both environments construct with `runtime_mode = true`
(`r6.new_runtime` / `new_authority` → `r5.new_runtime` /
`new_source_runtime` → `zones.new_*_runtime` → `height.new_runtime`). So every
`if not runtime_mode` / `not runtime_construction` branch, `module.new`,
`canonical_kat*`, `artifact_evidence`, `*_lattice_digest`, `quality_*_records`,
`diagnose_final_axis_violations` and the `*_micro_kat` functions are dead at
runtime. Only tools call them.

### `height.lua` (5,838 lines; 146 `fail(`, 241 "evidence", 89 "digest")

Note: the file sits at Lua 5.1's upvalue ceiling (its own comment at ~l.5685).
This is a practical reason to rebuild rather than extend it.

| Section (lines) | fail / evidence / digest | Content | Verdict | Consumer impact |
|---|---|---|---|---|
| Population pins (1063-1065) | — | Exactly 6 relief profiles, 70 landmarks, 100 anchors, 42 hard, 25 hydrology, 15 interfaces | dies-with-rebuild (P3/P5) | None. They trip as soon as D13 or the P4/P5 work changes counts (R2) |
| Lattice/grid + construction digests (1043-1330) | 11 / 3 / 16 | Zone-table lattice, counted SHA, lattice digests | dies-with-rebuild (P3) | None outside tools |
| Detail + landmarks + natural height (1331-1544) | 9 / 5 / 0 | 2 octaves, 70 stamped landmarks, collar | dies-with-rebuild (P3) | `landmark_excluded_at` must be re-derived from the soft fields (see §4) |
| Hydrology, contact faces, water banks (1545-2371) | 24 / 61 / 11 | Reach scalars, 3 hard-coded waterfall contact faces with exact bounds (≈l.326-344 and 2165 `#contact_face_records ~= 3`) | dies-with-rebuild (P5) | Planner water queries keep their seam (`water_surface_at`, `hydrology_transition_values_at`) |
| Anchor fitting + coastal grade (2372-3047) | 22 / 2 / 2 | Start/capital reference height, terraces, apron, cut/fill limits, coastal cores | **keep, adapt** (P3 lane 2) | Guards the §4 hard core (capitals/starts fit). The profile checks (`civic_width ~= 96`) stay; they are keyed to the civic core |
| Junctions + paths + island routes (3048-3643) | 30 / 8 / 1 | Hub/gate stations, junction targets, pins | dies-with-rebuild (P4) | Nothing outside mapgen |
| Public session + KAT/evidence (3644-4336) | 5 / 142 / 39 | Runtime session (keep) + non-runtime ledger session (dead) | keep the runtime half; the ledger half dies-with-rebuild | `hard_protection_volumes`, `selected_anchor_3d_by_id` feed zones → protection. Keep |
| Path surface, fords, landings (4337-5159) | 20 / 14 / 13 | Road raster, ford caps, `coupled_grade.solve_paths` | dies-with-rebuild (P4/P5) | — |
| Composition + coast profile (5160-5550) | 2 / 4 / 0 | `composed_land_values_at`, lattice shore, `coast_profile_at` | keep, adapt (P3/D17) | `coast_profile_at`/`coast_material_at` are read by `planner`, `r6_content`, `r6_planner`, `r6_settlement` |
| Final-axis scan (5551-5694) | 9 / 0 / 0 | Road-axis grade violations, `connected path endpoint differs` | dies-with-rebuild (P4). Replaced by the §5 "≤1 step" check | — |
| Module API + micro-KATs (5695-5838) | 0 / 1 / 2 | `new`, `new_runtime_checked`, `diagnose…`, 2 micro-KATs | dies-with-rebuild (dead at runtime) | tools only |

### `simple_map.lua` (2,698 lines; 104 `fail(`)

| Section (lines) | fail | Content | Verdict | Impact |
|---|---:|---|---|---|
| `validate_source` counts (407-424) | — | 32 fixed populations (routes 57, stations 62, gates 24, spurs 74, landmarks 70, hydrology 25, claim_exclusions 314, …) | dies-with-rebuild | Trips on any count change (R2) |
| Validate zones/primitives/bays/islands/channels (447-591) | 19 | Coast and zone geometry | dies-with-rebuild (P2b/P3) | — |
| Validate stations, gates, anchors, routes, crossings, boats, island routes, spurs, apex (592-944) | 32 | Route-gate rules, the "capital reached by exactly four routes" assert, the gate approach of 144 | dies-with-rebuild (P4). Keep the anchor/apex parts in reduced form | — |
| Validate landmarks (945-954) | 1 | `numeric_id == index` | dies-with-rebuild (P3) | — |
| Validate hydrology (955-1090) | 9 | Civic-hydrology overlap with its fixed core, waterfall faces | dies-with-rebuild (P5) | — |
| Validate housing / ingress / hard / claims (1091-1171) | 7 | — | housing keep-adapt; ingress dies (P4); claims re-derived | Housing is not implemented yet |
| Warp, difficulty, precompute (1172-1829) | 12 | ±60 warp on 256 cells, power-diagram owner, `holy_grounds` lateral difficulty | dies-with-rebuild (P2b/P3) | **`mob_level_at` depends on it** (16 call sites in mobs, traders, fishing). Front-zone levels must be re-derived without the rectangle |
| Session classification (1830-2314) | 2 | `water_class`, macro region, `id_at` | keep the seam, rebuild behind it | `id_at`, `biome_at`, `water_class_at` have gameplay consumers (§4) |
| `neighbors`, `nearest_path_at`, `nearest_hydrology_at`, `path_corridor_member` (2315-2420) | 3 | Route-derived queries | dies-with-rebuild (P4/P5) | No caller anywhere (grep `nearest_path_at\|path_corridor_member` → definition only) |
| Housing queries (2448-2571) | 3 | — | keep | Used by r6_settlement exclusions |
| `canonical_kat` (2572-2698) | 0 | KAT encoder | dies-with-rebuild (dead at runtime) | tools only |

### `source/simple_map.lua` (1,221 lines; 19 `assert`, 0 `fail`)

| Table | Verdict |
|---|---|
| `route_rows`, `route_stations`, `capital_gates`, `route_curve`, `poi_spurs`, `island_routes`, `crossing_interfaces`, `capital_ingresses`, ingress hard rows, the 19 route asserts | dies-with-rebuild (P4) |
| `landmarks` and the three role sets | dies-with-rebuild (P3, D13) |
| `hydrology`, `hydrology_interfaces`, profiles | dies-with-rebuild (P5) |
| `holy_grounds` rectangle, `warp`, `mainland_partition`, `land_primitives`, `bays`/`islands`/`channels` outline | dies-with-rebuild (P2b/P3; D8, D17) |
| `zones` rows (attributes: territory, PvP, levels, biomes), `anchors`, `anchor_profiles`, `apex_sockets`, `region_resources`, `housing_policy`, start/capital hard recipes | **keep** (anchors x/z stay approximately put, D7) |
| `claim_exclusions` (314 rows, built from all of the above) | keep the mechanism, re-derive the rows |

### `zones.lua` (1,865 lines; 93 `fail(`)

| Section (lines) | fail | Verdict | Impact |
|---|---:|---|---|
| `validate_factory_authority` (351-413): counts zones 38, routes 57, boats 4, island routes 8, anchors 100, spurs 74, hydrology 25, hard 42, recipes 4, ingresses 6, claim exclusions 314, housing reservation | 6 | dies-with-rebuild | — |
| Counted SHA / construction accounting (428-440) | — | dies-with-rebuild | — |
| Route-derived `neighbor_ids` (551-578) | 2 | dies-with-rebuild (P4). **Replace with geometric adjacency or drop** (D14, Q4) | 0 runtime consumers (§4.1) |
| Boats/travel records + anchors (579-677) | 4 | keep (anchors); boats per D17 | `travel_links` has 0 consumers |
| Route path index, pins 139 paths / 488 segments (789-891) | 9 | dies-with-rebuild (P4) | It feeds only `nearest_route_at` (0 consumers) |
| Hydrology index, pin 102 segments (892-957) | 5 | dies-with-rebuild (P5) | It feeds `planner_source.hydrology_metric_values_at` (planner, r6_settlement). Re-derive |
| Ingress bounds (958-1051) | 9 | dies-with-rebuild (P4, D9) | Protection shrinks (§4) |
| Hard rows (1052-1150), public API + compatibility (1151-1414) | 9 | **keep** (seam) | Protection, guard level 60 in capitals, `territory_rule_at` |
| KAT/evidence (1415-1517) | 0 | dies-with-rebuild (dead at runtime) | tools only |
| `planner_source` (1570-1839) | 17 | keep the seam | planner, farming `ecology.lua` (`functional_surface_values_at`) |

### `coupled_grade.lua` (158 lines, no checks)

A heap-based shared one-step grade solver for intersecting path axes. Its sole
caller is `height.lua:4738` (`solve_paths`). **dies-with-rebuild (P4)**, unless
the Phase 4 lane chooses to reuse it for T/Y junctions. When it goes, the same
change must remove:

- the `dofile` in `r7_runtime.lua:98`
- the dependency allowlist entries in `zones.lua:197`, `r5.lua:20` and
  `r6.lua:10`
- **its entry in `preparation_identity.lua`'s hashed file list** (l.7). That
  list is read with `assert(io.open)`, so a missing file aborts game load.

### Fail-closed code outside the five modules that the rebuild can trip (R2)

| Where | Check | Tripped by |
|---|---|---|
| `grug_core/zone_authority.lua:134-152, 177-212` | Anchor x/y/z are integers; `id_at(anchor)` equals its zone; start/capital `faction_at` | Border warp (R7), float height (D2) |
| `zone_authority.lua:214-252` | Each outpost stays in its race region; 4 per race | Border warp near outposts (R7) |
| `zone_authority.lua:254-310` | Rare anchor not in deep ocean; patrol offsets ≤80; `integer(terrain_height_at)` | Coast (D17); float height (D2) |
| `r7_manifest.lua:452-486` | 6 frozen digests + `SOURCE_PROJECTION_SHA256` (catalogs, templates, cultural, consumer payload) | Changes to anchor identities, zone ids or rare patrol offsets. Terrain height alone does not trip it (the payload hashes identities, not positions) |
| `r7_anchor_roster.lua:72`, `r7_zone_overlay.lua:9,23`, `r7_manifest.lua:319,362` | 42 roster rows, 36 protected columns, family counts | Only if the anchor population changes |
| `r6_settlement.lua:834` | 24 apex sockets | Only if the apex population changes |
| `r7_r6_manifest.lua` INPUT_ROWS | Historical file hashes (AGENTS.md, design docs…) | Inert data (not re-read at runtime, `grep io.open` finds nothing). D4 cleanup |

## 4. Runtime consumers of roads, stations, neighbors, Battlegrounds, landmarks, hydrology and ingress

Searched the whole `mods/` tree:

- the `grug_zones` method names with `.`/`:` and as strings;
- aliases (`zones_api`, `zones.`, `grug_mapgen.wp40.`);
- the `grug_core` adapters;
- words `road|route|station|ingress|hydrolog|landmark|holy|battleground|macro_region|planned_water`.

`grug_zones` is the only published world authority (`zone_authority.lua:5-24`).
It is an immutable proxy, so it cannot be iterated dynamically.

### 4.1 Route-based zone "neighbors" (R1, D14)

| Consumer | Uses | Can geometric adjacency (D14) serve it? |
|---|---|---|
| `grug_zones.neighbors(id)` export (`zone_authority.lua:8` → `zones.lua:1163`) | Built from `source.routes` (`zones.lua:551-578`) | **Yes.** No caller exists. Re-derive from the zone function (shared border ≥ N nodes), or drop the method (Q4) |
| `simple_map.lua:2315` `session.neighbors` (horizontal session) | Scans `source.routes` | Yes / drop. No caller |
| `grug_zones.travel_links(id)` (boats) | `source.boat_paths` | Not route-based. No caller. Keep or drop with D17 |
| Quests (`grug_quests/*`) | **No** call. Travel handoffs are hand-authored NPC→NPC targets (`registry.lua:40`) | Not needed |
| Travel (`grug_home/travel.lua`) | `start_position` only | Not needed |
| Mob levels / zone progression | `mob_level_at` from the axial difficulty bands (simple_map 1620-1829), not neighbors | Not needed. Must be rebuilt without the Battlegrounds rectangle |
| tools (`simple_map_r4_*`, `r7/micro_kat_fixture`, `r7/consumer_contract_kat`) | KATs | Retire |
| Design text: `world_zones.md` §9 (l.944 "57 routed pairs are the authoritative gameplay neighbors used by travel, quests and `neighbors(id)`"), §13 API list (l.1421), `world.md` §2c (l.56-76), ROADMAP l.15 | Claims only | Phase 1 rewrites them |

Grep: `neighbors\s*\(|travel_links\s*\(|"neighbors"` over `mods` finds only the
three definitions and the export list. `grep -rniE neighbo` over all mods found
no zone-level use (the other hits are ABM `neighbors`, comments, and
voxel-neighbor code).

**Verdict: every consumer can be served by geometric adjacency, and none needs
adapting beyond the export itself.**

### 4.2 Other consumers

| Record | Runtime consumer | Kind | Impact of the rebuild | Verdict |
|---|---|---|---|---|
| Routes / spurs / island routes | height grading, `r5.lua` relations, `simple_map`/`zones` indexes, `r6_settlement` ingress exclusion, claim exclusions `exclude:route:*` | mapgen-internal | Replaced by the P4 overlay | dies-with-rebuild |
| Routes (content) | Quest text: `grug_quests/content.lua` `road =` ×6 (start→village), `content_civic.lua` "follow the road" ×6 (start→capital), "leaving the road / safer roads / keep to the route" ×20 (capital→outposts/mines); named flavour roads ("Copper Road", "Mill Road", "Redtusk Road", "Raincall Road", "fen road") | player text | P4 must connect start↔village and start↔capital. Outposts via trails (D19). The §5 check "starts and capitals connected by road" should include villages | keep text; P4 requirement |
| Routes (map) | `grug_map_atlas_world.png`, rendered by `tools/r14_map/render_atlas.lua` from `source.routes`/`island_routes`/zones/bays/islands/land primitives | player map | Stale after P2b/P3/P4 | re-render (keep tool) |
| Hub stations / capital gates | `height.lua:3144-3232` (junction grading), `simple_map.lua:592-630` (validation). Zone `hub` x/z also seeds the power diagram | mapgen-internal | Hub stations and star junctions go (D9). Gates at ±256 stay tied to the blueprints' `GATE_OUT` (§6) | dies-with-rebuild; gates keep |
| `nearest_route_at`, `nearest_hydrology_at` | none outside the session | — | — | dies-with-rebuild (or drop from the export) |
| Capital ingress corridors | `zones.lua` hard rows → `territory_rule_at` = `hard_protected` → `grug_core.world_alterable`/`world_protected_for_faction` (`protection.lua`, `water_guard.lua`, `grug_farming/bucket.lua`, `ecology.lua`, `boss_dragons.lua`); `r6_settlement.lua:841-885` (no resources in the corridor) | protection | Corridors become ordinary territory: players can dig there, and resources may spawn. No consumer needs the corridor itself | dies-with-rebuild (P4, D9) |
| Battlegrounds rectangle `holy_grounds` | `simple_map` classification (1953, 2030) and the lateral difficulty profile (1737-1829) | mapgen-internal | Removed (D8). **Front-zone mob levels need a new rule** | dies-with-rebuild |
| Territory rule `"holy_grounds"` on zones 34-37 | `protection.lua:18-20` (alterable), `grug_mounts/entity.lua:152` (flight legal), `atmosphere_zones.lua:390` (Battlegrounds mood) | per-zone attribute | Unaffected if the four zones keep the rule string. Renaming the token (D8 wording) would touch 3 consumers + `zones.lua:513,1408` | keep (Q6) |
| Hydrology (`planned_water` class) | `grug_mobs/reed_angelfish.lua:6` (spawns only in `planned_water`), `grug_mounts/entity.lua:137-138` (treated like land for flight), `grug_gathering/catalog.lua:67-69` (shore classes) | water class | P5 must keep a `planned_water` class for inland rivers/lakes | keep class, rebuild records |
| Hydrology (mapgen) | `planner.lua` (108 refs), `r5.lua`, `r6_planner`, `r6_settlement` via `hydrology_metric_values_at`/`hydrology_transition_values_at` | mapgen-internal | Seams kept, data rebuilt | dies-with-rebuild |
| Landmarks (terrain) | `height.lua` base_H/target_T; `landmark_excluded_at` → `r6_settlement.lua:711` (resource exclusion); `coastal_housing_cores.landmark_id` (4 rows need a rectangle landmark); hydrology rows' `landmark_id` | mapgen-internal | Replaced by soft fields (D13). `landmark_excluded_at` to be re-derived or dropped | dies-with-rebuild |
| `blueprint.landmarks` in `r7_settlement.lua`/`preparation_source.lua` | **Not terrain landmarks.** These are WP13 socket/plot marks | — | unaffected | keep |
| Outpost patrols (`camps.lua:330-338`), rare patrols (`rares.lua`, `grug_core.rare_route`) | Outpost chain and rare anchor offsets, straight lines over terrain | anchors | Not road-based. Rougher terrain may block straight patrol lines (playtest item) | keep |
| Housing / claims (`housing_eligible_at`) | No caller outside mapgen; `r6_settlement` uses the exclusions | — | Re-derive from the new roads/water | keep mechanism |
| HUD / map page | `grug_map/page.lua:66` `grug_zones.at` (zone name), socket markers | zone lookup | Seam kept | keep |

## 5. Landmark names (input for D13 / R9)

Method (landmark agent):

- Scanned all 11,145 tracked text files outside `reference_projects/`.
- Pattern types: exact id (`(?<![A-Za-z0-9])<id>`), display phrase with
  `[ _\-]?` word joints (case-insensitive), plural pass, and partial distinctive
  words (reported only as "possible").
- Scan scripts and raw hits are in the session scratchpad (not in the repo).

**Every landmark has these baseline references, so they are omitted below:**

- its definition row in `source/simple_map.lua`;
- the role sets;
- the inert mirror in `source/catalog.lua`;
- one row in `world_zones.md` §8.4.

**No landmark name appears in** locale/`.tr`/`.txt`/`.json` files under `mods/`,
README, ROADMAP, BACKLOG, `story.md`, `quests.md` or `world_map.md`.

Current distribution: 11 zones have 1 landmark, 22 have 2 and 5 have 3
(zones 33, 34, 36, 37, 38). Only those five exceed the D13 cap of two.

Legend: **P** = player-visible text, **D** = design prose outside §8.4,
**M** = other mapgen data/code, **U** = unreferenced. Shapes: E ellipse,
C capsule, R rectangle. Roles: h hydrology, r route, t target_T.

| # | Landmark | Zone | Shape | Roles | References | Class |
|---|---|---|---|---|---|---|
| 1 | hearthpine_bowl | 1 Hearthpine | E | – | – | U |
| 2 | copperfell_drainage | 2 Copperfell | C | h | hyd `hydro_copperfell_streams` | M |
| 3 | copperfell_coastal_terraces | 2 | R | t | coastal core (must stay a rectangle) | M |
| 4 | dur_brannoc_granite_terrace | 3 Dur Brannoc | R 352 | t | wp13 comments; world_zones prose; settlements.md | D |
| 5 | dur_brannoc_forge_chasm | 3 | C | t | §8 "forge chasm" | D |
| 6 | frostbarrow_escarpment | 4 Frostbarrow | C | – | – | U |
| 7 | frostbarrow_tarns | 4 | E | h | hyd; §8 "frozen tarns"; POI echo "Tarnwatch Fold", "Tarncut Mine" | D+M |
| 8 | stormvault_arch | 5 Stormvault | E | r | §8 concept only | U |
| 9 | dawnmere_headwaters | 6 Dawnmere | C | h | hyd (civic core zone 6) | M |
| 10 | goldmead_millriver | 7 Goldmead | C | h | hyd; waterfall `highcourt_goldmead_fall` (hard-coded contact face) | M |
| 11 | goldmead_orchard_slopes | 7 | E | – | – | U |
| 12 | highcourt_riverfork | 8 Highcourt | C 280×352 | h | 3 hyd reaches in the civic envelope; confluence + waterfall; §8 "city on a river fork" | D+M |
| 13 | whitebridge_crossing | 9 Whitebridge | C | h,r | hyd; bridge crossing (route_021) | M |
| 14 | whitebridge_ford | 9 | C | h,r | hyd; ford crossing (route_032) | M |
| 15 | ashenward_burnscar | 10 Ashenward | C | – | – | U |
| 16 | ashenward_trenchbelt | 10 | R | r | §8 "trenches" (weak) | U |
| 17 | silverleaf_gladechain | 11 Silverleaf | C | – | – | U |
| 18 | starbough_canopy_steps | 12 Starbough | E | – | – | U |
| 19 | starbough_coastal_gardens | 12 | R | t | coastal core | M |
| 20 | lethariel_crownlake | 13 Lethariel | E | t,h | hyd lake in the civic envelope | M |
| 21 | lorindor_silverorchards | 14 Lorindor | E | – | – | U |
| 22 | lorindor_berrymarsh | 14 | E | h | hyd; POI echo "Lorindor Berrycourt" | M |
| 23 | moonfall_crescent | 15 Moonfall | E | h | hyd; §8 "crescent lake" | D+M |
| 24 | glassroot_pale_cliffs | 16 Glassroot | C | – | §8 "pale cliffs" (weak) | D |
| 25 | glassroot_rootways | 16 | C | r | – (the quest "rootways" hits are Kapok, unrelated) | U |
| 26 | stillgrave_basin | 17 Stillgrave | E | – | – | U |
| 27 | stillgrave_ringbarrows | 17 | E | – | `wp13/stillgrave.lua:134` dresses the start for it | M |
| 28 | mournfen_drowned_roads | 18 Mournfen | C | h,r | hyd `hydro_mournfen_marsh` | M |
| 29 | mournfen_dryward | 18 | R | t | coastal core | M |
| 30 | nhal_veyr_necropolis | 19 Nhal Veyr | R 352 | t | "necropolis" throughout the wp13 capital; settlements.md; world_zones prose | D |
| 31 | ossuary_spine | 20 Ossuary | C | – | – | U |
| 32 | ossuary_gravewoods | 20 | E | – | – | U |
| 33 | blackwind_bonearches | 21 Blackwind | E | r | §8 "natural bone arches" | D |
| 34 | blackwind_ashcuts | 21 | C | – | – | U |
| 35 | sunscar_open_flats | 22 Sunscar | R | – | – | U |
| 36 | sunscar_waterholes | 22 | E | h | hyd (civic core zone 22); §8 "waterholes" | D+M |
| 37 | redtusk_gullies | 23 Redtusk | C | r | §8 "red gullies" (weak) | D |
| 38 | redtusk_wellchain | 23 | C | – | – | U |
| 39 | gor_drazhak_crossmesa | 24 Gor Drazhak | R 352 | t | – (capital terrain by convention) | U |
| 40 | speargrass_dryriver | 25 Speargrass | C | h,r | hyd (dry channel); §8 "dry rivers" (weak) | D+M |
| 41 | speargrass_hunting_stones | 25 | E | – | §8 "hunting stones" | D |
| 42 | bannerbreak_crowned_mesa | 26 Bannerbreak | E | – | – | U |
| 43 | bannerbreak_siegeramps | 26 | C | r | §8 "siege ramps"; POI echo "Red Ramp Post" | D |
| 44 | kapok_worldtree_basin | 27 Kapok | E | – | – | U |
| 45 | raincall_falls | 28 Raincall | C | h | 5 hyd reaches, 4 rapids/falls + `raincall_reedmaze_fall` (hard-coded contact face) | M (most wired) |
| 46 | raincall_coastal_steps | 28 | R | t | coastal core | M |
| 47 | **kezamba_cenote** | 29 Kezamba | E | t,h | hyd (civic core); `height.lua:621`, `r7_settlement.lua:313`, `r7_kezamba_blueprint.lua`, wp13 `kezamba*.lua` (~30), frozen `kezamba_lagoon` raster; **quest "Smoke Above the Cenote"** (`content_civic.lua:620`) | **P** |
| 48 | whispering_reedmaze | 30 Whispering | R | h | hyd; waterfall lower end; §8 "reed maze" | D+M |
| 49 | whispering_totemways | 30 | C | r | – | U |
| 50 | totemwater_delta | 31 Totemwater | C | h | hyd | M |
| 51 | totemwater_colossi | 31 | E | – | – | U |
| 52 | thunderroot_exposures | 32 Thunderroot | C | r | – | U |
| 53 | thunderroot_ochresteps | 32 | E | – | – | U |
| 54 | wyrmglass_ring | 33 Wyrmglass | E | r | – (zone silhouette) | U |
| 55 | wyrmglass_faultfields | 33 | R | t | hosts apex-mine POI #89 at its centre; POI echo "Wyrmglass Fault Camp" | U |
| 56 | **wyrmglass_dragonspire** | 33 | E | t | **atlas label "Wyrmglass Dragonspire"** (`r20_poi_catalog.lua:62` → `grug_map`) | **P** |
| 57 | gravesalt_whitewall | 34 Gravesalt | C | h,r | hyd `hydro_gravesalt_pans`; 2 causeways; `gravesalt_broken_fall` (hard-coded contact face) | M |
| 58 | gravesalt_tombways | 34 | R | r | inert catalog tunnel link; POI echo "Tombroad Ambush" | U |
| 59 | gravesalt_warcoast | 34 | C | r | T2-only | U |
| 60 | broken_threeways | 35 Broken Causeway | R | r | POI echoes (#78-80) | U |
| 61 | broken_marsh | 35 | R | h | hyd; 3 crossings + waterfall lower end | M |
| 62 | shattered_breachwall | 36 Shattered Line | C | r | §8 "breached walls" (weak) | D |
| 63 | shattered_noman | 36 | R | – | §8 "no-man's-land"; POI echo "No-Man's Orchard" | D |
| 64 | shattered_siegeramp | 36 | C | r | §8 "siege ramp"; POI echo "Siege Ramp Foot" | D |
| 65 | skyglass_escarpment | 37 Skyglass | C | r | inert catalog tunnel link | U |
| 66 | skyglass_hangingways | 37 | R | r | – | U |
| 67 | skyglass_warcoast | 37 | C | r | T2-only | U |
| 68 | stormscale_caldera | 38 Stormscale | E | r | – (zone silhouette) | U |
| 69 | stormscale_gemterraces | 38 | R | t | hosts apex-mine POI #90; POI echo "Stormscale Gem Camp" | U |
| 70 | **stormscale_dragonroost** | 38 | E | t | **atlas label "Stormscale Dragonroost"** | **P** |

Things D13 must respect:

- **Three names are player-visible** and must be kept:
  - `kezamba_cenote` (a quest title);
  - `wyrmglass_dragonspire` and `stormscale_dragonroost` (map labels of the
    dragon POIs at the landmark centres).
- **Four coastal housing cores** (Copperfell, Starbough, Mournfen, Raincall)
  reference their landmark by id and require a rectangle.
- **Three waterfalls are hard-coded contact faces:**
  `highcourt_goldmead_fall`, `gravesalt_broken_fall`, `raincall_reedmaze_fall`.
- **Water inside capital envelopes:** Highcourt rivers, the Lethariel lake and
  the Kezamba cenote. The planner requires civic hydrology to overlap its fixed
  core.
- **Renumbering:** `height.lua:1412` and `simple_map.lua:947` require
  `numeric_id == index`.

All of the above die with the P3/P5 rebuild; they are listed so that the Phase 1
selection names what the new soft fields must provide.

## 6. Dependencies on the 512/704 capital envelope (recorded for §11, not changed)

Method (envelope agent):

- Grepped `\b(512|256|704|352|532|266)\b` and
  `capital_core|blend_width|fitting_width|building_core_width|capital_gates|exclude_anchor_blend|hard_capital_build_plus_apron`.
- Grepped `GATE_OUT|WALL_AT|WALL_END|WALL_SIDE|TURRETS|TOWERS|EDGE_AT|GATE_POINT|ENVELOPE|THRESHOLD`
  in `wp13/`.
- Grepped capital radius names in the gameplay mods.

Kinds: **hard** = a literal that must change by hand; **derived** = follows
automatically from another value.

| Area | Where | Value | Kind |
|---|---|---|---|
| Root envelope | `source/simple_map.lua:30` `capital_core` | 512×512 | hard |
| Capital profiles (×6) | `source/simple_map.lua:865-870` | `fitting_width=512`, `blend_width=704`, `civic_width=96`, `max_cut=24`, `max_fill=16` | hard (a second copy of 512) |
| Hard protection | `source/simple_map.lua:1079` `hard_capital_build_plus_apron_v1` | `total_width=532` (512 + 2×10) | hard (third copy) |
| r7 overlay limit | `r7_settlement.lua:79-80` (±266); duplicate literal `:1507` | ±266 | hard (fourth copy) |
| Gates | `CAPITAL_GATE_OFFSET = width_x/2` (`source:253-255`, square assert) | ±256 | derived |
| Route approach | `CAPITAL_GATE_APPROACH=144` + 24 via pins at hub ±400 (`source:203-205, 260, 462-468` assert) | 144 / 400 | hard (dies with P4) |
| Capital landmarks | granite_terrace, necropolis, crossmesa 352×352; riverfork 280×352; crownlake/cenote ~250 | 352 | hard by convention (dies with P3) |
| Water in the envelope | Highcourt rivers, Lethariel lake, Kezamba cenote + `wp13/kezamba_lagoon.lua:45-53` (`ENVELOPE=256`, frozen 30,354-column raster) | — | hard |
| Blend/fitting code | `height.lua:2565-2586, 2777-2850`; `simple_map.lua:604-630, 1293-1318, 1437-1455, 2140-2250`; `zones.lua:966-1038, 1126-1137` | from the profile | derived |
| Blueprint walls/gates | `GATE_OUT=261` (highcourt, dur_brannoc, nhal_veyr, lethariel, gor_drazhak_quadrants); Kezamba `GATE_OUT=256` + `THRESHOLD=10` (exactly at the 266 limit); `WALL_AT=256/WALL_END=261/WALL_SIDE=252`, towers ±64/128/192 (×4 capitals); Lethariel `EDGE_*`; Nhal Veyr `GATE_POINT=256` | — | hard |
| Lot tables | 6 capitals' quadrant/lot/lane tables (~780 coordinates, max \|246\|) | — | hard; terrain-verified on 9 seeds via `tools/wp13/capital_lots.lua` (kept) |
| Gameplay | guard level 60 inside 532 (`zones.lua` `capital_member`); protection; NPC scan radius from sockets (`start_npcs.lua:600-620`); map markers | — | derived |
| Unaffected | civic core 96 / ±48-49 / 32 blend; `precinct_ring.lua` radius 48; ring streets at ±96 | — | civic-core-coupled |
| Design rules | `world_zones.md` §12 (512/704/10/96/32/128), §7.1, §7.3, §7.5, §13.3; `world.md` §1, §4; `settlements.md` "Capitals in the world"; `docs/research/wp13-capitals-pois-contract.md` §1-§4; ~35 research docs | — | text |

Coupling points for a smaller capital:

- **Four independent size literals** must move together, with no cross-check
  between them: 512 root, 512/704 profile, 532 hard recipe, ±266 overlay.
- Blueprint wall/gate constants and six lot tables must be *re-derived* with
  the lot predicates, not scaled.
- Envelope water and the Kezamba lagoon raster.
- A non-rectangular outline conflicts with the square asserts,
  `centered_half_open_square` footprints, `fixed_owner_at` rectangles and the
  symmetric wall runs.

For guardrail 8: Phase 3 damping masks and target heights should key off
`civic_width` (96), not `fitting_width`/`blend_width`. Which of the
`r7_manifest.lua` pinned digests would move on a shrink is **unverified**.

## 7. Open questions for the user

1. **Scope of the tools deletion.** Is the keep list in §1.1 right? The main
   choice is between the asset generators cited in licence files (keep them in
   place, or move them and edit 15 licence files) and deleting them outright,
   which orphans the provenance rows.
2. **`tools/wp40/results/` (864 MB, untracked, not in git).** Delete completely,
   or first archive the ~1.5 MB of unique text (three banked T2 patches,
   bay-transition briefs/reports, the untracked `attachment-anatomy` scripts)
   outside the repo, e.g. `~/projects/grudgelands-orchestration/archive/`?
   Recommendation: archive the small text, delete the rest.
3. **`luac51 -p` parse gate during mapgen work.** D1 drops PUC runs. Does it
   also drop AGENTS.md's mandatory `luac51 -p` + sweeps on every Lua change
   (cheap, static)? Recommendation: keep the static gate; it guards the
   plain-5.1 hard requirement for the engine's fallback build.
4. **`neighbors(id)` after D14.** No code calls it. Re-derive it from geometric
   zone adjacency (cheap, keeps the API that `world_zones.md` documents), or
   remove it together with `travel_links`/`nearest_route_at`/`nearest_hydrology_at`
   from the public surface? Recommendation: keep `neighbors` as derived
   adjacency and drop the other three.
5. **Capital-iteration kit from `tools/wp13/`** (renderers, dumpers,
   `run_capital.sh`, lot/wall predicates, ~2 MB). Keep it for the §11 follow-up,
   or retire it and rebuild when that round starts?
6. **Battlegrounds token.** D8 removes the rectangle. Should the four front
   zones keep the territory rule string `"holy_grounds"`? It drives protection,
   mount flight and the Battlegrounds mood (3 consumers). Keeping it costs
   nothing; renaming touches 3 consumers + `zones.lua`.

## 8. Confidence and what is unverified

- **Measured:** runtime load set (engine trace, one seed); `neighbors`/
  `travel_links`/`nearest_*` absence (grep incl. string and alias forms);
  `tools/` sizes (`git ls-files` + `stat`); keep-set size; profiler patch
  applicability (`git apply --check`); `starts_preload.lua` hash.
- **Traced statically, not run:** atlas label path for the dragon POIs; quest
  text consumers; protection effect of dropping ingress corridors.
- **Unverified:**
  - whether `run_native.py` still finds ≥561 tiles after the layout changes;
  - whether `run_capital.sh`/`capital_probe` survive the height rebuild;
  - which `r7_manifest.lua` digests move on a capital shrink;
  - contents of the 12 untracked `results/r8` directories beyond their names;
  - orchestration folders other than `~/projects/grudgelands-orchestration/r22/`
    were not searched for `tools/` references.
- **Other:**
  - The load trace covers one boot and one seed. Conditional loads were
    cross-checked by grep.
  - Design docs (`world_zones.md`, `world.md`, `settlements.md`, `housing.md`)
    were being edited in the working tree during this audit, so design line
    numbers above refer to HEAD `082982da` and may shift.
