# Round 22 capital planner: audit (plan D60, §11)

Date: 2026-09-26. Read-only audit on main `94d88743`. Input for
[the design draft](round22-capital-planner-design.md). Line numbers refer to
that commit. "Measured" means a LuaJIT run or a parse of existing logs;
everything else was read in the code.

## Conclusions first

1. **The seam is already per-seed capable.** A capital reaches the world as
   one *source* (`grug_wp13_capital_source_v1`): a fixed core, a list of plots
   with `{id, x, z, build}` offsets, and one overlay of street/wall runs
   (`wp40/r7_highcourt_blueprint.lua:83-151`). Plot offsets already vary per
   seed today (district permutation). A planner can feed new offsets without
   touching plot identities, sockets or NPC code.
2. **What blocks a natural layout is geometry, not identity:** plots are only
   translated, never rotated (entry always on the local −z edge); every street
   and wall is an **axis-aligned run** (`axis`, `at`, `from`, `to`); the
   terrain fitting is a **512-node square with terraces**; four size literals
   (512, 704, 532, ±266) must move together.
3. **The alley-stub defect is a direct consequence of (2):** entries face −z
   whatever the street, and `plot_approach.lua` only looks for an east-west
   street south of the plot.
4. **Almost every consumer outside the mapgen addresses capital content by
   socket id** (`plot_id/socket_id`), not by coordinates, so it follows a
   moved plot automatically. The things that do not follow are the fixed
   square geometry: protection (532 square), guard-level membership, road
   reservations (half 256) and the lot tables.
5. **The city is sparse:** core plus all plots cover **10–12 %** of the 512
   square (measured). The four quadrants carry 9 buildings + 4 fill pieces each
   on a 44-node lot pitch.

## 1. How each capital is built today

### 1.1 Common structure (all six)

| Layer | What | Where | Kind |
|---|---|---|---|
| Civic core | 96×96 authored blueprint, anchor-relative, flat at the fitted reference height; king's hall, service court, waypoint plaza, market, 4 gatehouses/thresholds at radius 48–49 on the axes; protected boundary ring (hedge/parapet/bank/palisade) at radius 48 | `wp13/<capital>.lua` `M.core()` (e.g. `highcourt.lua:589-1244`); bounds `r7_settlement.lua:71` | **authored**, fixed |
| District plots | 4 districts × (9 building plots + 4 fill pieces); each plot a self-contained composition ≤ ±13 (bounds ±15, y −6..24) with a foundation skirt to −6 and a cleared airspace, projected from **one reference column** (its centre) | `wp13/<capital>_plot.lua` (e.g. `highcourt_plot.lua:1-50, 470-500`), `r7_settlement.lua:1298-1318` | **authored kit**, placed per lot |
| Lots | hand-tuned tables of lot centres per quadrant (±~230), checked against 9 **pre-Round-22** terrain seeds | `highcourt_quadrants.lua:140-222`; Kezamba searched by a packer (`kezamba_lots.lua:1-45`) | **authored table** |
| District → quadrant | seeded permutation (SHA-256 of the world seed) for Highcourt, Dur Brannoc, Gor Drazhak, Nhal Veyr; Lethariel 3 of 4 (mere precinct pinned NE); Kezamba pinned | `highcourt_quadrants.lua:224-330` | generated (per seed) |
| Streets | overlay runs: 4 avenues (core edge ±50 → ±261), square ring street at ±96, 7–8 district lanes; per mapchunk from the final column surface: 1-Lipschitz envelope, **one full node per column with stair treads**, junction plateaus, viaducts ≥3 raised, bridges over water, lamps every 8 | `highcourt.lua:395-417`, `avenue.lua:1-200`, `street_plan.lua` | generated per chunk from **authored axis runs** |
| Wall / edge | 4 runs on the 512 square edges (`WALL_AT=256`, turrets every 64, gatehouse on each axis); stone curtain ×3, orc palisade ×1, elf grove edge, Kezamba four thresholds only | `highcourt.lua:438-489`, `wall.lua:1-60`, `orc_palisade.lua`, `elf_grove.lua`, `kezamba_gate.lua` | generated per chunk from **authored axis runs** |
| Civic water | Kezamba cenote, Lethariel crown lake (both reach into the core), Highcourt canal (one level, raised rims, sealed 8 off natural water); shapes authored, levels from the fitted core | `wp40/water_authored.lua:1-60` | authored shape, fitted level |
| Ground | core flat; outside it **terraces** (step dwarf/orc 4, human 2, elf/undead/troll 3) inside the 512 square, blended to the incoming terrain over 96 nodes to 704 | `height.lua:184-205, 720-745, 873-900` | generated |

### 1.2 Per capital (measured with LuaJIT, canonical assignment)

| Capital | Anchor | Plots (incl. fill) | Overlay runs | Edge | Core cells / sockets | Plot cells / sockets | Plot centres span |
|---|---|---|---|---|---|---|---|
| Highcourt | 0, −1500 | 52 | 19 (4 avenue, 4 ring, 7 lane, 4 wall) | stone curtain | 104 457 / 75 | 275 132 / 207 | x −224..220, z −232..224 |
| Dur Brannoc | −1800, −1500 | 52 | 20 (8 lanes) | stone curtain | 98 404 / 65 | 271 644 / 230 | ±234 |
| Gor Drazhak | 0, 1500 | 52 | 20 | palisade on rampart | 97 082 / 79 | 275 942 / 262 | ±212 |
| Lethariel | 1800, −1500 | 44 (mere quarter has 3 + 2) | 19 (grove edge) | open, planted belt | 93 168 / 83 | 219 502 / 196 | x −216..218, z −210..234 |
| Kezamba | 1800, 1500 | 52 (9/9/11/7 + 16 fill, pinned) | 12 (no lanes, 4 thresholds) | open, thresholds | 71 800 / 54 | 246 309 / 234 | x −200..188, z −184..214 |
| Nhal Veyr | −1800, 1500 | 52 | 20 | stone curtain | 100 300 / 76 | 269 545 / 224 | ±216 |

- Building all cells of one capital (core + every plot) costs **0.3–0.35 s**
  in LuaJIT (measured, `os.clock`).
- Plot footprint mean **350–410 m²** (≈ 20×20); core + plots = **9.7–11.9 %**
  of the 512² square (measured from the D63 identity dump
  `perf-d63/out/sid_h7.tsv`).
- Special cases: Lethariel's lore district is pinned to the mere quarter
  (`lethariel_quadrants.lua:31`); Kezamba's districts are pinned and its lots
  were searched by a packer (`kezamba_lots.lua:1-45`) — the only capital
  whose lots were computed rather than hand-placed.

### 1.3 Envelope and fitting

- Build envelope 512, blend 704, protection 532 (512 + 2×10), overlay bound
  ±266: `source/simple_map.lua:477-482` (profiles), `:495` (hard recipe),
  `r7_settlement.lua:79-80` (overlay bound). Kinds: all hard literals.
- Reference height: natural centre clamped to the civic core's cut/fill
  interval `[N−24, N+16]` (`height.lua:170-182, 720-745`).
- Terrain around the core: damped in the terrain field (calm bowl keyed to
  the core, irregular edge, D28) — but the **fitting still terraces the whole
  512 square** and blends over a square 96-node collar
  (`height.lua:873-900`: `half_open_square_excess(... fitting_width)`,
  `capital_terrace_value`, `band_value` at `:823-850`). The square blend edge
  is the likely source of the straight grading edge at Nhal Veyr (§4).
- Rivers crossing the reserved area keep their trough: the grading fades out
  over carved columns (`keep_trough`, `height.lua:924-940`).
- Water keep-out around each capital core: core corner distance (68) + 32,
  grown up to 30 % by noise ⇒ **100–130 nodes** (`terrain_data.lua:265-269`,
  `height.lua:253-265`).

## 2. Consumers of a capital's layout

Classification: **F** = must follow the new per-seed layout; **C** = only
needs the fixed civic core; **A** = follows automatically (addresses content
by plot/socket id, positions resolved from the plan at load); **O** =
obsolete/replaced.

### 2.1 Inside the mapgen

| Consumer | Where | Reads | Class | What changes |
|---|---|---|---|---|
| Lot tables + district permutation | `wp13/*_quadrants.lua`, `kezamba_lots.lua` | authored centres | **O** | replaced by the planner's plot list |
| Street/lane/wall runs | `wp13/<capital>.lua` `M.avenues/ring/wall/wall_plan`, `*_quadrants.lua` `M.LANES` | axis runs | **O/F** | replaced by planner output; runs must become polylines if streets/walls are not axis-aligned |
| Plot projection | `r7_settlement.lua:1298-1318` (`base_of`) | `descriptor.offset` + reference column | **F** | needs a per-plot `turns` (rotation) and optionally a planner-given base height |
| Plot rects for civic water | `r7_settlement.lua:901-920` (`plot_rects`) | plot boxes | **A** | follows the plot list |
| Terrain audit (log only) | `r7_settlement.lua:947-1018` | plot boxes vs terrain | **A** | becomes the planner's own legality test |
| Plot approaches | `wp13/plot_approach.lua`, `r7_settlement.lua:1360-1460, 1518-1560` | −z entry, x-axis streets | **O** | replaced (plots face their lane) |
| Street overlay per chunk | `r7_settlement.lua:652-755` (`prepare_overlay`), `avenue.lua`, `street_plan.lua`, `wall.lua` | axis runs | **F/O** | polyline streets → road module sampler; walls → polyline raster |
| Capital fitting | `height.lua:720-745, 873-900` | 512/704 square, terraces | **F** | key to the planner's outline; drop square terraces |
| Water keep-out | `height.lua:253-265`, `terrain_data.lua:268-269` | civic core | **C** | unchanged |
| Civic water rows | `water_authored.lua` | authored capsule chains | **C / F** | lake + cenote stay (core); Highcourt canal becomes planner output (D58) |
| Hard protection + guard level 60 | `zones.lua:698-800` (`capital_member`), recipe `simple_map.lua:495` | 532 square | **F** | follow the planner outline (or keep the square; question U4) |
| Planner/resource exclusions | `simple_map.lua` anchor-blend squares (704²; stale-rule R10: 12.4–12.8 % of land) | 704 square | **F** | key to outline or reserved area |
| Road network | road lane `setup.lua:14-19` (capital node, reserved square half 256, ring of joinable edge cells) | reserved area | **C** | unchanged: roads end at the reserved edge (D59) |
| Manifest / identities | `r7_settlement.lua:756-900`; plot identity = its cells | plot cells | **A** | unchanged as long as rotation happens at projection time |
| Lazy build/release | `r7_settlement.lua:83-88, 1462-1500` | plot boxes | **A** | unchanged |
| Kezamba lagoon raster | `wp13/kezamba_lagoon.lua:45-53` (frozen 30 354-column mask in ±256) | authored | **C** | stays with the cenote |

### 2.1b Mapgen-internal constraints a per-seed layout must respect

(From the background sweep of `wp40/`; V = read in code, I = inferred.)

| Constraint | Where | Consequence |
|---|---|---|
| **Order cycle (I):** blueprints and their `plot_rects` are built by the `r7_runtime` factory **before** any height session and feed `height.lua`'s authored-lake capping (civic water keeps ≥ ~10 off plots) | `r7_runtime.lua:106-111, 192-232`; `height.lua:468-498` | a planner that runs after height, water and roads cannot feed plot rects back into height; civic water must stop depending on plots (plots avoid water instead) |
| Emerge accepts only `{schema, manifest_sha256, full_seed, projection, water_layout}` | `r7_loader.lua:128-134`, `r7_mapgen.lua:31-48` | the capital layout needs its own payload field (the road lane adds `road_layout` the same way) |
| Emerge must reproduce main's manifest SHA; manifest has one block per blueprint prefix (plot ids) with count, bounds, population, reach box, delta SHA | `r7_manifest.lua:130-142, 373-427, 507-535, 618-626` | plot ids and cells may stay; the overlay identity (runs with axis/at/from/to) changes per seed and must come from the payload in both environments |
| Overlay identity = every run's id/axis/at/from/to + reach box; runs must stay inside ±266 | `r7_settlement.lua:662-745` | polyline streets need a different overlay kind or the road-module raster |
| Capital centre column must carry `land_grade` with the anchor's feature id | `r7_anchor_roster.lua:46-59` | the core fitting stays |
| Preparation identity hashes every plot box (offset + reference height) | `preparation_source.lua:27-76`; consumed by `grug_map/base.lua:331`, `grug_core/starts_preload.lua:71-92` | becomes per seed; fine for fresh worlds, but the planner must run before it |
| D66 R6 planner cell cache reads static exclusions only | `r6_planner.lua:605-645`, `simple_map.lua:383-482` | any per-seed capital exclusion must be resolved before the first `build_cell` |
| 704 blend square is a **static exclusion** for resources, ores, cultural candidates, strata/cave entrances, P9G plants, housing; the 532 square refuses decorations | `simple_map.lua:408-466, 536-567`; `r6_settlement.lua:784-844, 2660-2671`; `world_content.lua:70-77` | keeping the square (U4) keeps all of these unchanged; shrinking it moves them all |
| Zone-field self-check: the 532 square must be in-zone and on land | `zone_field.lua:246-267, 722-729` | unchanged if the square stays |
| Overlay memos per column persist for the session | `r7_settlement.lua:1245-1260, 1363-1372` | unbounded growth (I); worth fixing when streets move to the road sampler |
| Nhal Veyr edge: z 1804 = centre + 304, i.e. 48 nodes into the square 256..352 blend band; next to a lake the "fitted column loses its water" rule (`height.lua:1141-1149`) likely turns the straight blend line into a straight shore (I) | `height.lua:879-888` | removing the square grade removes it |

### 2.2 Outside the mapgen (sampled sweep; see §6)

| Consumer | Where | Reads | Class |
|---|---|---|---|
| NPC roster placement (guards, patrols, residents, vendors, spare spots) | `ENTITIES/grug_mobs/start_npcs.lua:560-760`, registry `grug_core.register_settlement_sockets` | sockets computed by `r7_settlement.sockets()` (`:1020-1080`) from plot offset + reference height | **A** — sockets move with their plot |
| Patrol loops (city ring, gate towers, one per district) | `start_npcs.lua:600-625, 1116` | socket `group` | **A** for district loops; gate-tower and core loops **C** |
| NPC identity scan radius | `start_npcs.lua:606-620` | max socket distance + margin | **A** (shrinks with a smaller city) |
| Inn / home binding / respawn | `PLAYER/grug_home/locations.lua:10-15` | `plot/socket` ids, e.g. `homes_tavern/homes_tavern_gate_idle` | **A** — needs the plot to exist on every seed |
| Cook quest givers, envoys | `PLAYER/grug_quests/content_npcs.lua:35-51` | `plot/socket` ids (cooks) or core socket ids (envoys) | **A** / **C** |
| Capital displays (stable mounts, service displays) | `ENTITIES/grug_mobs/capital_displays.lua`, `grug_mounts/trainer.lua:6-7` | sockets | **A** |
| Profession vendors | `ENTITIES/grug_traders/vendors.lua` | vendor sockets in plots | **A** |
| Capital readiness | `start_npcs.lua:1222-1240` | anchor or any socket block loaded | **A** |
| Mob spawn policy | `ENTITIES/grug_mobs/spawn_policy.lua:36-99` | zone id | unaffected |
| World map | `PLAYER/grug_map/page.lua:19-21` (labels), `base.lua` `road_polylines()` | anchor + polylines | **F** only if the map should draw walls/streets (not today) |
| Protection, water guard, terrain-damage guard | `grug_core` via `territory_rule_at` → `capital_member` | 532 square | **F** (see U4) |

**Rule for the planner:** every plot id that a consumer names (inn,
cook, profession vendors, stable, trainers) must be placed on every seed.
Today all 52 are placed unconditionally; a planner that drops plots for lack
of room must never drop these (a "required" flag per plot).

## 3. What depends on sizes, gates and identities

| Dependency | Where | Kind | Planner impact |
|---|---|---|---|
| Envelope 512 / blend 704 | `simple_map.lua:477-482` | hard ×6 | becomes the **reserved area** (kept) plus an outline inside it |
| Protection 532 | `simple_map.lua:495` | hard | keep square or follow outline (U4) |
| Overlay bound ±266 | `r7_settlement.lua:79-80` | hard | keep (reserved area) |
| Core 96 / radius 48–49 / core gates on axes | every `wp13/<capital>.lua` | authored | **unchanged** (protected core) |
| City gates `GATE_OUT` 261 (256 Kezamba), wall at ±256, turrets ±64/128/192 | `highcourt.lua:395, 438-446` ×4 capitals, `kezamba.lua:233` | hard | replaced by planner gates |
| Road ends | road lane: reserved square half 256, ring cells, `RING_GAP` 160 | road module | fixed by D59 |
| Ring street ±96, lanes, lots | per-capital tables | hard | replaced |
| Blueprint identities | 510 settlement identity rows; plot identity = its cells, not its position | derived | unchanged if rotation is applied at projection |
| District permutation hash | `*_quadrants.lua` | per seed | replaced by planner choice |

## 4. Known §11 defects and their causes

| Defect | Cause (pinned where possible) |
|---|---|
| **House-to-lane approach stubs** (12–16 of 52 per capital reach a street on the default seed) | Every plot composition puts its entry on the local −z edge (`highcourt_plot.lua:491`, likewise `dur_brannoc_plot.lua:489`, `gor_drazhak_plot.lua:504`, `nhal_veyr_plot.lua:543`, `lethariel_plot.lua:432`, `kezamba_plot.lua:397`) and plots are only translated, never rotated (`highcourt_districts.lua` `resolve` copies `x, z` only). `plot_approach.lua:15-27` only accepts an **x-axis** street **south** of the plot within 24 nodes; otherwise it paves an 8-node stub toward −z into open ground. Its comment says "north edge", the code tests `run.at < p.min_z` (south). |
| **Plots and lanes in rivers** | Lot tables were verified on 9 old-terrain seeds; since D57 rivers may cross the reserved area; plots are written without a water test (`r7_settlement.lua:925-935`), and the audit only logs (26–58 plot warnings per seed, plan Phase 5b). |
| **Dry river bed beside Highcourt** | Planned river columns (river:26) under capital pavement/soil: the settlement writer builds over them (plan Phase 6 note, D64 analysis). Same root cause as above. |
| **Nhal Veyr straight grading edge** (z ≈ 1804 on seed 8675309, beside a lake) | Probably the square fitting: terraces across the 512 square blended over a square 96-node collar (`height.lua:873-900`); the edge becomes visible where the damped field meets undamped lake terrain. Not verified by a probe. |
| **River arcs around core keep-outs**, **straight dry gullies in the flat capital bowls** | Hard keep-out disc of 100–130 around the core (`terrain_data.lua:268-269`); the soft lens was rejected (W3b). Not a planner defect as such; the planner can hide them (walls, bridges, parks), not remove them. |
| **Highcourt civic water "chaotic"** | Canal authored along the corridors left by the old lot grid (`highcourt_quadrants.lua:21-24`), one level with raised rims (W3a interim, D58), sealed where natural water comes close. |

## 5. Cost today

| Item | Value | Source |
|---|---|---|
| Main construction (whole mapgen start) | 11.1–11.8 s | D63 report, HEAD pairs |
| of which settlement terrain audit (log warnings only) | ~3.7 s | D63 report |
| Emerge construction | 6.6–7.1 s, of which re-preparing all settlement blueprints ~3.5 s | D63 report |
| Building one capital's cells (core + plots) | 0.3–0.35 s LuaJIT | measured here |
| Chunk time, capital-core chunks vs start chunks | median **640–740 ms** vs **230–250 ms** (HEAD runs of D63, n = 4 capital chunks, first chunk includes the lazy capital build — indicative only) | parsed from `perf-d63/runs/fin*/cold/profile-events.log` |
| Road network build (for comparison) | 5.3–7.7 s main | road lane `phase4-int/INTEGRATION.md` |
| Road sampler per crossed chunk | 8–14 ms | same |

## 6. Road ends at the reserved edge (road lane intermediate outputs)

Parsed from `phase4-int/out/s{1,42,8675309}_p4_points.tsv` (primary and
secondary roads; the lane is still iterating, so treat as indicative):

- **2–5 road ends per capital**, not four. Examples: Kezamba 2 (seed
  8675309), Gor Drazhak 5 (seeds 1, 8675309).
- Ends lie anywhere on the edge; **about 40 % sit within 64 nodes of a
  corner**, and a side often gets two ends while another gets none (Gor
  Drazhak seed 1: two on the south side, one each E/N/W).
- End heights within one capital differ by up to ~30 nodes (Dur Brannoc
  y 63–94, seed 1).

## 7. What this audit did not cover

- The out-of-mapgen sweep in §2.2 was a targeted grep (socket registry, home
  locations, quest NPCs, mounts, map, spawn policy, protection), not an
  exhaustive read of every quest text. Two background sweeps were still
  running when this was written; their findings should be merged before the
  prototype brief.
- The Nhal Veyr edge cause is inferred from the code, not probed.
- No engine run was made for this audit.
