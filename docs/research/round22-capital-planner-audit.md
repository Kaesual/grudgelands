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
   moved plot automatically. What does not follow: **twelve hard-coded plot
   socket ids** (six inns, six cooks; a missing one is a load error), the
   **inn arrival offset in world +x** (breaks when plots rotate), planned-water
   flow in protected territory (canals), persisted NPC state (the layout
   must be identical on every boot), and the fixed square geometry:
   protection (532), guard level 60, the 704 exclusion square and road
   reservations (half 256).
6. **Load-order cycle:** blueprints and plot rectangles are built before the
   height session and feed the civic-water capping. A planner that runs after
   height, water and roads needs that dependency reversed (§2.1b).
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

### 2.2 Outside the mapgen (full sweep of `mods/` except `grug_mapgen`)

**Bottom line:** no mod outside the mapgen keeps capital coordinates of its
own. Every NPC, service, quest giver and home position comes from one
registry, `grug_core.settlement_sockets_at(key)`, which the mapgen fills at
every load (`wp40/r7_loader.lua:42-100`). Core sockets are anchor + offset at
the fitted anchor height; district-plot sockets are plot offset + the final
height of the plot's reference column, with ids prefixed `"<plot_id>/"`
(`CORE/grug_core/settlement_sockets.lua:172-184`, `r7_settlement.lua:1020-1080`).
So most consumers follow a moved plot automatically. What does not follow is
listed first.

**Breaks or needs work if the layout varies per seed**

| Consumer | Where | Problem | Class |
|---|---|---|---|
| Innkeeper / home arrival | `PLAYER/grug_home/locations.lua:10-15` (6 hard-coded plot socket ids: `terrace_alehouse/…`, `homes_tavern/…`, `homes_longhouse/…`, `homes_lane_house/…`, `warren_clan_house/…`, `vine_longhouse/…`); `grug_core.assign_innkeeper_socket` (`settlement_sockets.lua:306-319`) | a missing plot id is a **load error**; the arrival is `socket.pos + (1, −0.49, 0)` in **world +x** (`grug_home/init.lua:9`) — with a rotated plot that cell may be a wall, `safe_arrival` (`travel.lua:29-46`) then returns nil ("Home arrival is unavailable") and death respawn falls back to the start (`travel.lua:108-122`) | **F (pinned)** |
| Capital cook quest givers | `PLAYER/grug_quests/content_npcs.lua:35-50` (6 hard-coded plot ids, e.g. `homes_bakehouse/…_quest_cook`) | missing plot id asserts at load (`grug_quests/registry.lua:75-87`, `grug_map/providers.lua:58-61`) | **F (pinned)** |
| Capital service plots | `wp13/capital_services.lua:4-39` (`M.PLOTS`, 8 service plots per capital; trainers, public stations) | must exist on every seed | **F (pinned)** |
| Planned-water flow guard | `CORE/grug_core/water_guard.lua:17-60`; exception predicate `grug_mapgen/init.lua:15-41` from `column_values_at` water id/y | flow in protected territory is reverted unless it is planned water: planner canals and water under cross-river walls must be reported as planned water | **F** |
| Hard protection (R1) | `grug_core/protection.lua:29-47` → `zones.lua:779-790, 871-875` | 532 square; any plot, wall, bridge or connector outside ±266 would be mutable world | **C (square)** |
| Guard level 60 | `grug_mobs/levels.lua:346-347` → `zones.lua:792-800, 921` | 532 square; a barracks outside it would get field levels | **C (square)** |
| Mob spawn palettes | `ENTITIES/grug_mobs/spawn_policy.lua:36-99, 338-339` | capital **zone** has no ambient hostiles; only the 512 envelope is guaranteed zone-owned (`world.md:77-80`) | **C** (city must stay in its zone) |
| Persisted NPC state | mod storage `startnpc:<key>:<socket_id>` (`start_npcs.lua:427-439, 731-746`); entity staticdata with world positions (`:1058-1180`); orphans are neither matched nor removed (`:784-787`) | the layout must be **identical on every boot of a world** (deterministic from seed and code); a planner code change inside an existing world leaves orphan NPCs — acceptable in fresh-server mode | **F (determinism)** |
| Full-world preparation identity | `grug_core/starts_preload.lua:80-95` asserts `preparation_source.identity`, built from plot boxes (`wp40/preparation_source.lua:26-75`) | per seed is fine; plot boxes must come from the plan; a planner change rejects resuming a full-mode world (fresh-server mode) | **A** |
| Quest texts | `PLAYER/grug_quests/content_civic.lua` | name district buildings (terrace/homes/market bakehouse, mourners' hall, warren cook court, shore smokehouse "above the cenote", muster yard) — fine while those plots exist; "beyond its walls" for **all six** capitals, incl. the open Lethariel and Kezamba (already inaccurate); "gates", "follow the road" (lines 44–689) | text only |
| Design text | `world_zones.md:1223-1238` ("Four fixed 32-node-wide road gates", gate→zone table) | contradicts per-seed gates; the follow-up paragraph already says the planner places them | text only |

**Follows automatically (A) or needs only the fixed core (C)**

| Consumer | Where | Class |
|---|---|---|
| NPC placement engine, every role; capital detected via `grug_core.capital_anchor` | `ENTITIES/grug_mobs/start_npcs.lua:528-551, 553-759, 1182-1249` | A |
| District patrol loops, barracks/tower posts | same engine, `socket.group` (`:620-633`) | A |
| Gatehouse posts, gate-tower loops, royal guards, kings, city-ring loop | core sockets (`start_npcs.lua:293-315, 703-705`; `highcourt.lua:240-255`); the outer wall carries no NPCs (`settlements.md:281-282`) | C |
| Residents, spares, walkers (every 5th idle in authored order) | `start_npcs.lua:166-215, 634-674` | A (walker choice follows socket order) |
| NPC scan radius | `start_npcs.lua:164, 612-619` (farthest socket + 48) | A |
| Race vendors (core), profession vendors (plots) | `ENTITIES/grug_traders/vendors.lua:482-551, 677-692` | C / A |
| Trainers, repair providers | `ITEMS/grug_repair/providers.lua:34-39` (NPC within 2 of its socket) | A |
| Riding trainer, mount/gear displays | `PLAYER/grug_mounts/trainer.lua:5-32`; `grug_mobs/capital_displays.lua:42-58` (walk pairs by id convention) | A |
| Public crafting/brewing stations | `PLAYER/grug_jobs/station_nodes.lua:235-246`; `ITEMS/grug_alchemy/recipes.lua:186-199` | A |
| Envoy quest givers | `content_npcs.lua:36-51` (core sockets) | C |
| Capital readiness | `start_npcs.lua:1222-1249` (anchor banner or any socket block) | C |
| World map: labels, service/quest/home markers | `PLAYER/grug_map/page.lua:16-24, 64-75`; `providers.lua:29-91` | C / A |
| World map: roads, rivers, cache key | `grug_map/base.lua:104-120, 322-356` (`road_polylines()` stub; key = seed, preparation identity, anchor heights, water layout) | optional: draw walls/streets |
| Cloud base | `CORE/grug_core/atmosphere_zones.lua:348-371` (9 samples at ±48 around the anchor) | C |
| Terrain-damage guard (mobs, explosions) | mobs_redo `core.is_protected(pos, "")` → `protection.lua:39-41` (always protected for empty names) | unaffected |
| Death respawn fallback, home persistence | `grug_factions/init.lua:233, 371-384`; player meta ids | unaffected |
| Farming ecology | `ITEMS/grug_farming/ecology.lua:64-75, 133-148` | unaffected |
| Starts-only preparation | `grug_core/preparation_plan.lua:45-61` (starts only) | unaffected |

**Searched, found nothing:** runtime housing or claims (no housing mod
exists yet), music/ambience zones, district names in the HUD, fixed
in-capital coordinates in quests, any read of a city gate position or axis
outside the mapgen.

**Rules for the planner that follow from this:**
1. **Required plots** are always placed: the inn plot, the cook plot, the
   eight service plots (`capital_services.PLOTS`) and the stable. Only other
   plots may be left out on cramped seeds.
2. The inn arrival offset must rotate with the plot (or be published as its
   own socket) — a one-line change in `grug_home`, or a mapgen-side arrival
   landmark.
3. The layout is a pure function of seed and code, so every boot of a world
   registers the same sockets.
4. The city (plots, walls, gates, connectors) stays inside the 532 square
   and inside the capital zone, unless U4 is answered otherwise.
5. Planner canals are planned water in `column_values_at`.

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
| Claim/resource exclusion 704, cave core 512, hard 532 | `source/simple_map.lua:408-466, 536-578`; readers in `r6_settlement.lua:148-240, 784-844, 2332-2341, 2660-2671`, `r6_planner.lua:274-314, 483`, `world_content.lua:70-77`, `simple_map.lua:598-602` | hard | unchanged while the reserved square stays; `route_corridor` recipe exists but has no rows (`simple_map.lua:530`) |
| Calm bowl `capital_r_in` 260 / `r_out` 520 (comment ties 260 to plots ~240 out) | `terrain_data.lua:74-83`; `terrain_field.lua:745-783, 849-907` | data | can shrink with the city (keyed to the anchor) |
| Legacy copy of the sizes and gate stations at ±256 | `source/catalog.lua:136-140, 1658-1676` (loaded only for rare patrol offsets, `r7_runtime.lua:304-307`) | dead for capitals | delete in cleanup |
| Hard-coded ±266 / ±265 besides the overlay bound | `r7_settlement.lua:1536` (approach clip), `preparation_source.lua:49-52` | hard | a fifth and sixth copy of the square |
| Descriptor checks | `r7_settlement.lua:539-565, 607-633, 662-666, 723-729, 783-817, 1136-1141, 1330-1336` (plot x/z within ±1023, cells in plot bounds, overlay width/reach, lazy rebuild SHA equal, anchor literals) | fail-closed | all satisfiable by a planner; the lazy rebuild needs a deterministic `build()` per seed |
| Manifest | `r7_manifest.lua:130-142, 373-427, 507-535, 618-626` | derived | emerge must reproduce main's manifest SHA, so emerge needs the plan (payload) |
| Anchor roster check (capital centre = `land_grade` with the anchor's feature id) | `r7_anchor_roster.lua:46-59` | fail-closed | unchanged (core fitting stays) |
| `num_emerge_threads = 1` pin | `r7_runtime.lua:85-86` | hard | unchanged |

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

- §2.1b, §2.2 and §3 come from two read-only sweeps (all of `mods/` outside
  the mapgen; `wp40/` and the shared mapgen modules) plus spot checks. The
  per-capital `wp13` district files were read only where cited.
- Claimed research KATs (`tools/wp13/blueprint_kat.lua`, `highcourt_kat.lua`)
  cited by `wp13-npc-sockets-contract.md` no longer exist; the surviving
  capital probe `tools/wp13/capital_probe/service_witness.lua:10, 75` pins 8
  service plots per capital.
- The Nhal Veyr edge cause is inferred from the code, not probed.
- No engine run was made for this audit.
