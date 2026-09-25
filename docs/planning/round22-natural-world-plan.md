# Round 22 plan: natural terrain, roads and water

Date: 2026-09-25. Coordinator: Claude Opus 5.5 (root), implementation by
Opus 5.5 subagents; the user may re-route per session
(`../process/agent-model-policy.md`, "Day-to-day routing rule").
Status: **in progress.** Phases 0–3 and 3b are done, accepted by the user, merged to main and synced (not pushed). Phase 5 (water) is running: W0 (cleanup) and W2a (rivers and lakes) merged; W2b and W2c running. Then Phase 4 (roads) (D30), then Phase 6. Each phase still needs the user's Go.

This document records the goal, the analysis it rests on, every decision taken
with the user on 2026-09-25 and its basis, the phases, and the guardrails
against complexity. It supersedes living design only where Phase 1 folds it
into `../design/`. Until then `../design/world_zones.md` remains the text of
record, and Phase 1 rewrites it.

## 1. Goal

A world that looks **beautiful and natural** to players:

- Every region has a recognizable character that loosely fits its race (dwarf
  lands a little more rugged, human lands gentler, and so on). These are
  accents and a feeling; the whole dwarf region does not have to be mountains.
- The map stays readable. Capitals, start areas and POIs stand reliably where
  players expect them.
- Terrain has variation at every scale: mountain ranges with ridges and
  valleys, hills, gentle lowlands, occasional cliffs. There are no geometric
  stamps, straight edges or S-curve ramps.
- Zone borders, including the Battlegrounds, blend into the landscape without
  long straight lines.
- Roads connect what matters, follow the terrain and look good. Rivers carve
  their valleys, and lakes have irregular shores.

Beauty and naturalness are judged by the user from images and playtests, not
by digests.

## 2. Analysis basis (measured 2026-09-25)

Offline probe against the real `terrain_height_at`, seed
`15140735923413111218`: the whole map on a 16-node grid plus two 2-node
windows (Gravesalt, Ashenward). The probe, analysis and render scripts live
outside the repo in `~/projects/grudgelands-orchestration/r22/terrain-probe/`
(see its README). They reproduce every number below in about a minute, and
Phase 2 reuses them for the before/after comparison.

### 2.1 How height is produced today

`mods/MAPGEN/grug_mapgen/wp40/height.lua` replaces v7's surface completely. v7
still supplies caves, ores and strata; its `mountains,ridges` flags have no
visible effect. Four layers are added on top of each other:

1. **Zone tables.** Every zone has one relief profile with a fixed elevation
   band (`source/simple_map.lua` `relief_profiles`). A 64-node lattice samples
   that profile's value noise (periods 256–1280). The lattice is smoothed once
   (1:2:1) and interpolated **linearly** (`height.lua` ~1220–1324).
2. **Detail.** Two value-noise octaves (periods 128 and 32, weights 3:1),
   3–16 nodes amplitude (~1183–1218, ~1359–1369).
3. **70 landmarks.** Axis-aligned ellipses, capsules and rectangles. Inside,
   height moves 3/4 of the way to another profile; around them runs a 64-node
   smootherstep collar (~1438–1502).
4. **Grading.** Starts, capitals, villages and other anchors, coastal cores,
   routes and water banks (~2792–2968).

All randomness is hash-lattice **value noise** with smootherstep interpolation
in Q16 integer arithmetic. There is no gradient noise, domain warp, ridged
noise or erosion.

Zone ownership is a power diagram around hubs placed on a regular grid, warped
only ±60 nodes on 256-node cells, so borders are long straight lines. The
Battlegrounds are a fixed rectangle (x ±2500, z ±250).

### 2.2 Measurements

| Quantity | Value |
|---|---|
| Std of land height by component: zone tables / landmarks / detail | 59 / 22 / **3.8** nodes |
| Relief below 32-node scale, Ashenward rolling hills (std) | **1 node** |
| 2-node steps with zero height change (Ashenward) | **76 %** (98 % ≤ 1) |
| Land using the mountain profile | **2.3 %** (dragon islands only) |
| Gradient directions within 0–10° of an axis (slope > 1/8) | 19 % vs 11 % expected |
| Land altered by grading | 13.6 % |
| Landmark collar, e.g. Ashenward | 39 → 74 nodes over 48 nodes, flat on both sides |
| Longest straight capsule edge | ~460 nodes (whitewall/escarpment), ~1100 (breachwall) |

Diagnosis: the terrain is a **terrace model built from geometric shapes**.
Zone tables and stamped landmarks carry the height, with a very thin smooth
noise veil on top. Almost everything between 2 and 64 nodes is missing, and so
is any noise type that forms ridges.

### 2.3 Cost facts

| Quantity | Value |
|---|---|
| Noise height per column (grid + landmarks + detail), LuaJIT | ~3 µs |
| Final height with all grading | 10–17 µs |
| One 80×80 chunk of noise height, evaluated once | ~20 ms |
| Average preparation time per chunk (`../research/pregen-fullspeed.md`) | ~240 ms |
| Height-session construction (built twice per process) | 9–11 s |

The noise itself is cheap. Cost scales with how often a column is queried: the
2026-09-03 hot-path review found ~120 k unmemoized queries per chunk in
planning. Richer noise is affordable **if** heights are memoized per chunk.

### 2.4 Other findings

- **Capitals in the clouds.** Cloud height is fixed per race mood
  (`mods/CORE/grug_core/atmosphere_zones.lua` ~199–312). Dur Brannoc ground is
  143 under a cloud layer at 150–168, and Nhal Veyr ground is 91 under
  110–134. Kezamba (66 vs 100–128) is marginal.
- **Roads.** Every one of the 38 zones has a hub station, and 57 routes join
  hubs (30 primary, 24 secondary, 3 trails) plus 74 POI spurs. The six
  contested hubs each have **six** roads, which are the six star junctions.
  Each route is a polyline with 3 points per leg, bowed only 48–80 nodes.
  `world_zones.md` §9 makes these 57 edges the authoritative gameplay
  neighbors for travel, quests and `neighbors(id)`.
- **Capital ingress corridors.** §12 forces a 128-node-wide hard-protected
  corridor from every capital's front gate to the Battlegrounds rectangle,
  which is where "enemy capitals connected by fixed roads" comes from.
- **Anchors today:** 6 starts, 6 capitals, 12 villages, 24 outposts, 16 clash
  sites, 6 mines, 2 apex mines, 12 bandit camps, 4 mirefolk camps, 2 dragons,
  10 rare routes.
- **Code volume:** `wp40/` has ~33 k runtime-loaded lines and ~20 k lines that
  are never loaded at runtime (T2 census, partition, validation). `tools/` has
  ~265 k lines and 1.3 GB, of which `tools/wp40` is ~130 k lines. Runtime code
  embeds fail-closed identity and population checks: `height.lua` fails unless
  there are exactly 70 landmarks, 100 anchors, 25 hydrology reaches and so on.
  It has 241 "evidence", 89 "digest" and 146 `fail(` sites.

## 3. Decisions (2026-09-25, user with coordinator)

| # | Decision | Basis |
|---|---|---|
| D1 | **Ignore PUC Lua 5.1** during all mapgen development: no PUC runs, parity tests or gates. At most one optional "does it run without crashing" smoke test once the mapgen is finished. | A playable server with this mapgen needs LuaJIT anyway, and every server has it. Earlier rounds burned days of CPU on dual-interpreter suites. |
| D2 | **Floating point instead of Q16 integers** in the new height, road and water code. | Byte identity across platforms is not needed; the user always generates fresh worlds. Floats are faster and much simpler to write. Accepted residue: after a hardware move, new chunks could differ minimally. |
| D3 | **Retire `tools/`** and the `wp40` modules that are never loaded at runtime, after the Phase 0 audit. Git keeps the history. | Most of it serves requirements that no longer exist: KAT digests, PUC parity, census shards, evidence ledgers. |
| D4 | **Clean runtime code only where this round rebuilds it** (height, zone borders, roads, water). A general cleanup round comes at the very end. | A big-bang removal of embedded checks is itself a risky refactor. |
| D5 | **Minimal test policy** (§5). | Validation should protect gameplay, not freeze bytes. |
| D6 | Terrain direction is **B**: gradient noise, domain warp, ridged noise, zone character blended as parameters, soft landmark fields. **C** (coarse erosion) is decided after the B prototype. | B delivers most of the visual gain chunk-locally and cheaply. C's worth is best judged against B images, and it adds startup cost, a cache file and river coupling. |
| D7 | **Damp roughness around starts and capitals.** Their x/z positions stay about where they are; their heights may change. Capital ground ends up well below its region's clouds. | Readability and reliable cities; fixes "standing in fog". |
| D8 | **Zone borders become natural**, the Battlegrounds included. The Battlegrounds lose every technical special role: no rectangle, no special geometry. They remain only a story area; guard-vs-guard fights come later. | User ruling. PvP depends on zone **level band** (1–30 pacified, 31–60 contested), not on the Battlegrounds. |
| D9 | **Road network reduced to what matters:** capitals, starts and villages. Roads also enter the contested zones but need not reach the Battlegrounds. Drop the forced capital-to-Battlegrounds ingress corridors (§12) and the "57 authoritative edges" rule (§9). No star junctions (≤ 3–4 branches), no long straight segments, routes found by pathfinding over the terrain. Ugly open-world bridges are a named target. | User ruling. The current graph rules escalated into overly complex graph and grade problems. |
| D10 | **Water:** rivers carve their own valleys and meander, water surfaces step down downstream, lakes get irregular shores. A drainage-driven layout is an option tied to C. | User agreed; the complexity warning (§4) applies with full force. |
| D11 | **Capitals need not look rectangular.** | User wish; the scope limit is in §8 (R4). |
| D12 | **Plan first, start tomorrow at the earliest**, and only on explicit Go. | User. |
| D13 | **Landmarks reduced to one or two strong features per zone**, each a soft field of a fitting type (ridge band, basin, mesa, lake, dry river, escarpment). Keep the names that content or story uses; retire the rest; adjust referencing content and blueprints. | User, answering Q1. Fewer, clearer accents read better than 70 weak overlapping ones. |
| D14 | **Hierarchy: zones → roads.** Zones border each other naturally, and gameplay neighbors come from **geometric zone adjacency**. The road network is an overlay on top, never the defining graph. **Form follows function:** no graph requirement may drive zone shapes, and nothing may require a graph to be "solved". | User. The first mapgen attempt demanded a graph that could not be solved for days. The goal is simple code and a beautiful world; a graph is only a means. |
| D15 | **Roads are a cheap overlay.** They are routed once at construction, and routing plus rasterization should add as little ongoing complexity as possible. They should look good. | User. |
| D16 | **Capital footprints:** this round shapes only the organic outer edge (terrace/blend outline), or merely prepares for the follow-up (§11). No district or blueprint rework. Nothing this round may work against the follow-up goal. | User. The follow-up makes capitals denser and more natural. |
| D17 | **Coastline included**, improved cheaply with the same multi-scale warp as zone borders. | User, answering Q4. |
| D18 | **Road endpoints in contested zones:** the outpost or clash site nearest the home side. Roads need not reach the Battlegrounds. | User, answering Q2. |
| D19 | **Outposts, mines and camps** get narrow natural trails where cheap. This goal may be relaxed if it brings unexpected complexity. | User, answering Q3. |

Added at the Phase 0/1 gates (2026-09-25):

| # | Decision | Basis |
|---|---|---|
| D20 | **Mob levels follow the owning zone,** rising inside each zone toward the front; the R7.6 axial bands are retired. | User, on the Phase 2b finding that warped borders put 13.8% of land on the wrong side of the level-30/31 PvP line under position-based bands. |
| D21 | **Rough targets over exact rules.** Housing capacity is not measured; "ample level-20–30 land" suffices. Coastal housing frontage, depth and relief are rough targets. New rules default to guide values, not hard conditions. | User: many former hard conditions never needed to be hard and cost much time. |
| D22 | **Audit Q1–Q6 as recommended** (`../research/round22-audit.md` §7): keep list as proposed; archive the unique text of `tools/wp40/results/` outside the repo and delete the rest; keep the `luac51 -p` parse gate; keep `neighbors` as geometric adjacency and drop `travel_links`, `nearest_route_at`, `nearest_hydrology_at`; keep the WP13 capital kit; rename the `holy_grounds` territory token to `contested_land`. | User. |
| D23 | **Phase 1 text approved.** | User. |
| D24 | **Coast and zone borders vary per world seed.** Hubs, anchors and the macro silhouette stay fixed; anchors stay in their zone and on land by construction; a construction-time self-check falls back to a weaker warp on failure. The server renders the world map per world at first start. Coast-dependent content (river mouths, boat routes, landings, coastal housing) is derived from the coast rather than hand-placed. | User, after the coordinator's risk estimate: small risk, little extra work, and the map must be rendered per world anyway because roads depend on seed-dependent terrain. |
| D25 | **Terrain direction B accepted; option C (coarse erosion) deferred.** The prototype look (variant B base plus two continental mountain ranges and hill country) is the target; ruggedness is judged in the playtest. C may return after the playtest if valleys are missing. | User, 2026-09-25, on the round-2 prototype images. |
| D26 | **All inland water moves to Phase 5,** including civic water: Kezamba cenote, Lethariel crown lake, Highcourt river arms, Dawnmere and Sunscar ponds. Phase 3 keeps none, so Kezamba and Lethariel show dry basins in the Phase 3 playtest. Phase 5 embeds them naturally: the lake with irregular shores and possibly a river, a real river through Highcourt; the cenote stays a self-contained sinkhole with a more natural rim. | User, 2026-09-25, after discussing a split; one rule is simpler and lets Phase 5 embed city water in the landscape. |
| D27 | **Geometric coast profiles are retired.** The Round 8/9 rules (48-node runs, beach/bluff/cliff/terraced-cliff draws, fixed beach ramps, minimum cliff height) fought the new field and made pillars, notches and raised beaches, worst in dwarf highlands. The coast's shape comes from the terrain alone; only a material rule remains (sand on low, gentle shores; gravel/stone on steep or mountain shores), derived from the actual terrain. The shore rule (first dry column at water level) stays. | User playtest 2026-09-25; the user never asked for cliffs and the fixed beach slope was an unnecessary rule. |
| D28 | **Capital surroundings:** only the civic core is flat. Around it, terrain keeps long-wave variation (hills and hollows over ~100+ nodes) with limited amplitude, without fine detail, and the calm zone's edge is irregular, not round. Constraint until the capital rework: district plots still stand (plot warnings stay near zero). Terrain shape belongs to this round; buildings, walls, density and footprint belong to the capital rework (§11). | User playtest: "too flat and too round". |
| D29 | **No time budgets that change output.** The world-map relief renders at one fixed resolution on every server (one-time cost at first start, cached); hardware must never change what is produced. | User: time budgets are hardware-dependent and create bug classes. |
| D30 | **Water before roads:** Phase 5 (water) runs before Phase 4 (roads). Rivers carve valleys that roads then follow, and roads cross water where pathfinding finds it cheap, so bridges and fords fall out of routing instead of being retrofitted. Phase numbers stay as names. | User question, coordinator recommendation. |
| D31 | **Temporary defects are allowed** in intermediate states (e.g. capitals, quest texts saying "follow the road") when their repair is a planned step of this round. Everything is repaired by the end of the round. | User. |
| D32 | **Performance numbers are reports, not targets.** Guardrail 5 asks for a before/after comparison with the same method to catch gross regressions; there is no pass/fail limit. The real measure is whether chunk loading is noticeable in play. | User. |
| D33 | **POIs sit in the terrain.** A POI's height comes from the terrain under its footprint (a typical ground value), not the other way round. Only the small building core is fitted, with a short natural blend that follows the footprint; no large square plates. On steep slopes a bounded local adjustment in a small radius, the rest carried by foundations; performance first. POI x/z stay fixed (no per-seed site search). | User, on stale-rule finding R4 (41–47 of 88 POIs cut/filled ≥16 nodes). |
| D34 | **City water follows the terrain.** Phase 5 lays out water by the terrain; a fork at Highcourt is welcome if it arises naturally, not forced. An approximate location for a city's own water (e.g. the Lethariel lake) may stay authored; its shape comes from the terrain. The capital rework adapts the lots; until then defects there are allowed (D31). | User; refines stale-rule decision 3. |
| D35 | **Beaches run smoothly into the water.** The height profile is continuous through the waterline (no land floor/sea floor jump), so beaches have no mini-cliff and no gravel lip; shallow shore water also gives corals room. Coral density and sea plants beyond that are Phase 6. | User playtest of Phase 3b. |
| D36 | **Shore crabs spawn on sandy shore near water,** not gated by a narrow level band that zone-based levels (D20) no longer produce along most beaches, and not on inland sand. | User playtest of Phase 3b. |
| D37 | **Stale-rule audit decisions** (`../research/round22-stale-rules.md` §5), all as recommended: POI fitting per D33 now; planner water contract relaxed to "river water by column", named-relation checks dropped (Phase 5 start); Highcourt per D34; route and river layouts computed once in main and handed to emerge via `ipc_set`, no cache file (Phases 5/4); surface spawn caps raised to 600 and jungle/papyrus gates made relative to terrain/water; high relief without native caves accepted, checked in the Phase 6 playtest; design-text cleanup as one commit before Phase 5. | User. |

Added at the Phase 5 prototype gate (2026-09-25, user accepted all
recommendations; prototype and images in
`~/projects/grudgelands-orchestration/r22/phase5-proto/`):

| # | Decision | Basis |
|---|---|---|
| D38 | **Water layout from drainage, without erosion.** Priority-flood, flow directions and accumulation on a 16-node grid of the natural field; shallow pits (≤ ~24) are breached, deeper ones keep a lake below their spill level with the shore where the fine terrain lies below the surface; wetland zones and water landmarks keep shallow ponds. Built once in main (~4 s), handed to emerge via `ipc_set` (~70 KB). Option C stays deferred. | Prototype W1: rivers lie in plausible valleys, lakes get irregular shores for free; 0 containment violations on 3 seeds; +2–4 % field cost on ordinary chunks, ~+6 % tile time on river chunks. Supersedes the "drainage only with C" wording of D10. |
| D39 | **Steps follow the slope:** gentle terrain gets many small steps (rapids of 1–3 nodes); tall falls (up to ~16) only on steep slopes. | Prototype showed mostly 10–16-node falls even in gentle hills. |
| D40 | **Capital water keep-out covers the whole built area** (about 280 nodes from the core, irregular noise edge like the D28 calm edge), so districts stay dry and rivers bend around cities naturally instead of in circle arcs; rivers may still pass close by. Starts keep ~300–320. | Prototype: rivers crossed the district ring (155–260) at almost every capital; circular bends around the 140 ring. |
| D41 | **Water landmarks that do not arise naturally:** Moonfall's crescent lake is an authored lake (same format as civic water); Raincall shows monsoon ponds instead of a waterfall stair and Totemwater a river mouth with marsh ponds instead of a branching delta (design text adjusted). | Prototype: none of the three emerged from drainage; a Raincall source hint made a U-bend and seeped. |
| D42 | **Highcourt:** no forced fork (D34). A natural river passes nearby on most seeds; the blueprint's two dry river arms are filled as civic canals, like the Kezamba cenote, the Lethariel lake and the start ponds. | No natural fork on 3 seeds; the lots are cut around the arms. |
| D43 | **Lake count may vary by seed** (1.7–2.7 % of land on the tested seeds; some seeds get many mountain lakes). | User. |

Road shape decisions (2026-09-25, user with coordinator, before Phase 4):

| # | Decision | Basis |
|---|---|---|
| D44 | **Road cross-section per column** from road height vs terrain: uphill the terrain is cut to road level with a ~1:1 slope back (a low stone retaining wall at the foot of high cuts); downhill up to ~2 nodes of difference is a natural sloped embankment (dirt/grass), never a vertical wall; beyond that the road becomes a **deck on pillars** (posts every ~4–6 nodes down to the ground, railing on the open edge). Hillside galleries, valley crossings and bridges over water are one deck-and-pillar system. | User: the old mapgen's solid road foundations on slopes steeper than 45° looked like giant walls. |
| D45 | **Serpentines emerge from grade-limited routing;** hairpins get a flat turning platform and their legs stay ≥ ~16 nodes apart (the shared 16-node grid). | User and coordinator. |
| D46 | **Tunnels are staged:** Phase 4 first ships routing, cuts, embankments and decks; then images show where deep cuts over ridges appear, and only there a tunnel rule is added (about 7 wide, 5 high, stone arch lining, torches about every 8 nodes, portals; e.g. from more than ~8–10 nodes of cut over some length). Dropped if it gets complex; routing then avoids ridges by cost. | User: tunnels are welcome if they look good. |
| D47 | **Height changes use slabs, not full-block jumps.** The player step height is 0.6, so a slab turns every 1-node rise into two walkable half steps; slabs have no orientation, so curves with height change work. The existing `stairs` mod provides them. Sloped ramp nodes are at most a Phase 6 look option (their collision stays stepped). | User. |
| D48 | **One deck, pillar and railing design** to start, with materials per race. | User. |
| D49 | **Grade rule:** the road profile runs in half-node steps and neighbouring road columns differ by at most ½ node (max grade 1:2, every rise walkable without jumping, a slab on every half step). On top of that hard rule, routing cost prefers gentle grades (penalty rising above roughly 1:4; the exact preference is chosen by comparing variants in the Phase 4 prototype). | User: half-block steps walk far better and allow a finer, better-fitted profile. |
| D50 | **Stairs only on trails:** the narrow trails to outposts, mines and camps (D19) may use stair flights (up to 1:1) on straight stretches; main roads stay ≤ 1:2 with slabs (mounts, later carts). Compared as a variant in the prototype. | Stairs have an orientation and look wrong in curves. |
| D51 | **No long ramps into flat land.** Routing follows the terrain so the road lies near ground level; the profile both cuts and fills (never only fills downward from a high point); no fixed high control points (bridges sit on bank height with small clearance, junctions and gates take their ground's height). Metric: the longest stretch where the road lies more than 2 nodes above or below the terrain; a large value means the route is wrong and the costs get tuned, not longer ramps built. | User: in the old mapgen, ramps ran far into flat land before reaching their height. |

All §9 questions are answered.

## 4. Guardrails for the whole round

1. **Complexity budget.** Each phase states its intended mechanism up front.
   Stop and rethink when:
   - a sub-problem needs a second repair round for the same symptom,
   - a solver or graph problem appears that the plan did not foresee,
   - the scope grows past the phase's lane list.

   The response is simplify or relax (drop a guarantee, accept an
   approximation, cut a feature), not escalate. The coordinator raises such
   points with the user instead of pushing through.
2. **Visual acceptance first.** Every phase that changes the look produces
   before/after relief images and a short stats block with the same tool, and
   the user judges them. Numbers support the judgment; they never replace it.
3. **Keep the hard core small.** Things that stay non-negotiable:
   - Height and surface are **pure functions of (seed, x, z)** and globally
     queryable. Chunks generate in arbitrary order and planning needs heights
     before a chunk exists; without this there are seams at chunk borders.
   - Starts and capitals keep their approximate x/z and stay in their zone.
   - Roads are walkable without jumping: at most ½ node between neighboring
     road columns (D49), so mounts and players can use them.
   - Towns and POIs are never damaged; the terrain-damage guard still applies.
4. **Interfaces over rewrites.** Settlement, P9G and writer code consume height
   through existing seams: `terrain_height_at`, `functional_surface_values_at`,
   water surface queries and zone lookup. Keep those seams and change what is
   behind them. Touch settlement code only where a seam really has to change.
5. **Performance.** Memoize heights per chunk when the new height lands. Any
   phase that changes per-chunk cost reports chunk time against the ~240 ms
   baseline with the same measuring method.
6. **No PUC.** No byte comparisons, no digest pins, no fixed population counts
   in new code.
7. **Form follows function (D14).** Graphs, networks and connectivity rules
   serve the world; they are never a goal of their own. If a phase starts to
   require a graph property that has to be solved, searched or proven, and the
   world would look no better for it, drop the property.
8. **Do not block the follow-up (D16).** Capital-related changes this round
   must leave room for a smaller, denser capital. Examples: capital fitting
   parameters stay data-driven rather than hard-coded; damping masks and
   capital target heights are keyed to the civic core, not to the 512/704
   envelope.

## 5. Minimal test policy (D5)

Kept, and to be built or kept small:

1. **Smoke test:** load the game headless (`tools/luanti_headless.sh`,
   `LC_ALL=C`), generate a few dozen chunks around every start and capital,
   and check that there are no errors and no surviving processes.
2. **Visual tool:** a whole-map relief render plus height, slope and roughness
   statistics, reusing the Phase 2 prototype harness. This becomes the main
   instrument.
3. **Playability checks** (cheap, offline where possible):
   - no spawn in water;
   - starts and capitals connected by road;
   - roads walkable (≤ ½ node between neighbouring road columns, D49);
   - POI footprints on solid ground;
   - fixed anchors inside their own zone.
4. **Chunk seam check:** the same column queried from two adjacent chunks gives
   the same result.

Dropped: KATs, digests, evidence ledgers, census and partition suites, PUC
parity, fixed counts and identity strings.

## 6. Phases

Phases 0 and 2 are independent and may run in parallel. Each phase ends with a
user gate.

### Phase 0 — Audit (read-only)

- **Goal:** know what can go, what must stay and what dies anyway with this
  round's rebuild.
- **Scope:**
  - `tools/**`;
  - the `wp40` modules not loaded at runtime;
  - the embedded fail-closed and evidence code in the modules this round
    rebuilds (`height.lua`, `simple_map.lua`, `zones.lua`, `coupled_grade.lua`,
    route and hydrology parts of `source/simple_map.lua`);
  - every runtime consumer of routes, route stations, `neighbors(id)`,
    `holy_grounds`/`territory_rule`, landmarks, hydrology records and capital
    ingress corridors, across quests, mobs, patrols, atmosphere, zone
    authority, HUD, housing and claims.
- **Also in scope:**
  - every consumer of landmark names (content, blueprints, dressing, quests),
    as input to D13's selection;
  - everything that depends on the 512/704 capital envelope size, as input
    for the follow-up (§11), recorded but not changed.
- **Deliverable:** `../research/round22-audit.md` with a table of item → keep /
  retire / dies-with-rebuild, reason, and consumer impact. It must name every
  consumer of route-based zone "neighbors" and confirm that geometric zone
  adjacency (D14) can serve each of them.
- **Model:** 1 Opus subagent, medium effort. It measures and does not guess;
  every "unused" claim is backed by a grep or load trace.
- **Gate:** the user approves the table. Deletion happens afterwards as one
  mechanical commit.

### Phase 1 — Design rewrite

- **Goal:** the design text says what the user means.
- **Scope in `../design/world_zones.md`:**
  - §7.1–7.6: relief as regional character with soft transitions; landmarks as
    soft feature fields; the smoothness-only rule removed; cities damp
    roughness; capital height below clouds.
  - §7.4: the water principles of D10.
  - §9: the reduced road network of D9; zone adjacency decoupled from roads.
  - §12: the capital ingress corridors removed; capital footprint per R4.
  - §13–14: acceptance by the §5 policy.
  - PUC, KAT and census obligations struck.
  - The Round 21 note annotated as superseded where it conflicts.
- §8.4 landmark tables: the reduced set of D13 (one or two strong features per
  zone, with type and intent).
- Zone adjacency as the gameplay neighbor relation, with roads as an overlay
  (D14, D15). Road endpoints and trails per D18/D19.
- Coastline principles (D17).
- Align `world.md` §1 and §2c and the Battlegrounds wording with D8.
- Record the capital follow-up goal (§11) in the settlements design as a
  planned direction.
- **Model:** coordinator drafts, 1 Opus subagent checks consistency across
  docs.
- **Gate:** the user approves the text.

### Phase 2 — Terrain prototype B (scratchpad only)

- **Goal:** a height field the user likes, before any integration.
- **Mechanism:** a standalone float LuaJIT module `height(seed, x, z)` using
  today's zone ownership and anchor positions as inputs:
  - gradient noise (simplex or OpenSimplex-style) as fBm with 6–8 octaves,
    down to about 8 nodes;
  - domain warp;
  - a ridged multifractal for mountain character;
  - optional derivative-damped fBm ("erosion look").
- **Region character** consists of parameters per zone: base elevation,
  roughness and ridge share. They are blended over roughly 300–500 nodes with
  a warped distance, so no terraces appear at borders. Race accents are mild.
- **Landmarks** follow D13: one or two strong soft fields per zone with warped
  outlines and free orientation, for example a ridge band, basin, mesa or
  escarpment. The prototype uses a provisional selection that Phase 0/1
  finalize.
- **Damping masks** around starts (~300 nodes) and capitals (~500 nodes), plus
  capital target heights, for example ≤ ~80 above water, well below the
  region's clouds.
- **Harness:** whole-map and window renders, the §2.2 stats for comparison,
  per-column cost, and a cut/fill check against each capital's current
  `max_cut`/`max_fill`.
- **Iteration:** quick image rounds with the user. No repo coupling and no
  tests beyond the harness.
- **Model:** 1 Opus subagent for the module and harness, coordinator for
  direction; a second subagent only for parallel variants.
- **Gate:** look accepted, and a decision on C.

### Phase 2b — Zone border prototype (scratchpad, together with Phase 2)

- Replace the ±60 border warp with a multi-scale warp of roughly ±150–250
  nodes. Constraint: every fixed anchor stays inside its own zone; damp the
  warp near anchors if needed.
- Render the zone map for the user.
- **Coastline (D17):** give the continent outline, today built from capsule
  and rounded-rectangle land primitives, the same multi-scale warp, plus
  small-scale irregularity such as coves and headlands. Bays and islands
  follow. Keep starts, capitals and harbours or landings on the correct side
  of the water.
- Zones must stay contiguous and border each other plausibly. There are no
  graph targets for borders (D14).
- Evaluate biome blending at zone borders (noise dither instead of hard palette
  switches) and rate its cost.

### Phase 3 — Terrain integration

- **Goal:** the accepted prototype becomes the world.
- **Scope:**
  - Replace the grid, landmark and detail stack with the new function.
  - Remove the fail-closed pins that block it.
  - Adapt capital and start fitting to the damping masks.
  - Add the per-chunk height memo.
  - Set clouds relative to the region, for example at least capital ground
    plus 60.
  - Apply the zone border warp (2b) and remove the Battlegrounds rectangle
    (D8).
  - Smoke test, fresh world.
- **Lanes (as run, 2026-09-25):**
  A. horizontal: zones and coast, levels by zone, `holy_grounds` rename,
     geometric neighbors, coastal housing from the coast, old roads and inland
     water off;
  B. height: new field, damping and anchor fitting, per-chunk memo, chunk time;
  C. per-world map render and region-relative clouds.
- **Gate:** user playtest.

### Phase 3b — Post-playtest round (2026-09-25)

Findings of the user's Phase 3 playtest; the terrain direction is confirmed
("looks really good for the first time"). Run in parallel:
1. **Coast (D27):** remove the geometric coast profiles from `height.lua`
   and `world_zones.md` §7.4; add the terrain-derived material rule; compare
   human and dwarf coasts before/after by image.
2. **Capital surroundings (D28):** flat civic core, long-wave limited
   variation around it, irregular edge; plot warnings measured.
3. **Map relief (D29):** fixed resolution, no time budget.
4. **Capital alley stubs:** house-to-lane path segments point in one direction
   and end in the void. Check whether Phase 3 caused it. If yes, fix now; if
   it predates Round 22, it moves to the capital rework (§11).
5. **Stale-rule audit (read-only):** find rules in the world/design docs and
   assumptions in runtime mapgen code that date from the old flat world or
   WP40 and no longer fit (like the coast profiles), plus known hot-path
   costs (e.g. scattered `terrain_height_at` at 3–4 ms on the old code). Each
   finding gets keep / relax / remove and a reason; the user decides. Scope:
   world and mapgen rules and code that Phases 4–6 touch, not the whole
   codebase.

Gate: user look at the fixes and decisions on the audit list.

**Result (2026-09-25, merged):** coast profiles retired, terrain-derived
shore material with a reusable `bank_material_at(x, z, water_y, distance)`
hook; beaches continuous through the waterline; capitals flat only in the
core with long-wave limited relief and an irregular calm edge (plot warnings
0); POIs sit in the terrain (D33) with calm bowls for steep ones (dragon
arenas on summit shelves), vegetation exclusion cropped to core + 4; island
coasts at the channels jittered; world-map relief at a fixed 8-node grid
(~22 s once per world); surface spawn caps 600, jungle/papyrus gates relative,
shore crabs on sand near water; design text cleaned per the stale-rule
audit; the capital alley stubs predate Round 22 and moved to §11. Chunk time
~258 ms/tile (report only, D32).

### Phase 4 — Roads v2

- **Goal:** a small, natural-looking network.
- **Principle (D14, D15):** roads are an overlay, routed once at construction
  and cheap afterwards. The network is whatever a simple greedy construction
  yields. Connectivity is checked, not solved.
- **Mechanism:**
  1. Nodes are capitals, starts and villages, plus one endpoint per contested
     zone: the outpost or clash site nearest the home side (D18). The
     Battlegrounds need no road.
  2. Build a spanning tree plus a few loops. Junctions are T/Y with at most 3–4
     branches.
  3. Outposts, mines and camps get **narrow natural trails** where cheap, as
     the same routing with a smaller width. Relax or drop this if it causes
     unexpected complexity (D19).
  4. Pathfinding runs once at construction on an 8-node cost grid (slope,
     water, cliffs) and is cached for the session.
  5. Smooth the result into a spline and raster it as many short pieces.
  6. Keep the ≤ ½-node grade (D49), using cut and fill along the found path.
  7. Water crossings are chosen by cost (prefer narrow and shallow). Use one
     good bridge design (abutments, simple deck, railings) and fords for
     shallow water.
- **Removal:** the 57-edge graph, hub stations, shared junction grade solving
  and ingress corridors, with consumers adapted per the Phase 0 findings.
- **Start points from Phases 3/3b:**
  - Road nodes also serve the quest texts (audit): start→village,
    start→capital, capital→outpost/mine "follow the road" beats.
  - Capital endpoints come from the blueprint gates (stale-rule R11/D22); POIs
    already sit in the terrain (D33), so trails end on natural ground.
  - Route the network once in main and hand it to emerge via `ipc_set`, no
    cache file (D37). Measured: an 8-node whole-map grid costs ~13 s on the
    natural field, ~45 s on final heights, per build.
  - Map hook: `road_polylines()` in `mods/PLAYER/grug_map/base.lua` returns
    `{}` today; fill it and the map base re-renders.
  - Water exists first (D30), so crossings fall out of routing.
- **Road shape (D44–D51, 2026-09-25):**
  - Cross-section per column: uphill cut with ~1:1 slope back, downhill
    embankment up to ~2 nodes, beyond that a deck on pillars with railing;
    bridges are the same deck system. One design, materials per race.
  - Profile in half-node steps, ≤ ½ node between neighbouring road columns,
    slabs on half steps; routing prefers gentle grades; serpentines with
    flat hairpin platforms, legs ≥ ~16 apart; stairs only on straight trail
    stretches.
  - Tunnels only after the first images, where deep ridge cuts appear (D46).
- **Order:** an offline prototype first (like Phase 5), reusing the water
  lane's 16-node grid. It shows the whole map, a serpentine on a mountain, a
  bridge, a hillside gallery on pillars and long profiles with the half
  steps, and compares variants: hard 1:2 only vs an added preference for
  ~1:4 or ~1:3, and stairs on trails vs none. Metrics per variant: detour
  factor (road length / straight distance), number of hairpins, longest
  stretch > 2 nodes off the terrain (D51), cut/fill/deck column counts,
  construction time. The user picks, then integration.
- **Gate:** user playtest.

### Phase 5 — Water v2

- **Goal:** rivers in valleys, natural lakes.
- **Mechanism:**
  - A river corridor lowers terrain into a valley profile.
  - The water surface is constant per reach and steps down downstream, with
    small falls or rapids at the steps.
  - The centreline meanders by noise and its width varies.
  - Lake shores become irregular for all lakes.
- With C: river layout from drainage.
- **Watch point:** this is the highest-complexity area. Luanti water needs
  level surfaces. Transitions, contact faces and waterfalls are where earlier
  rounds spent effort, so relax early, for example with fewer, simpler step
  types.
- **Start points from Phases 3/3b (do first, one commit):** remove the old R5
  planner water/road contract and the legacy source tables it pins (routes,
  stations, spurs, crossings, ingresses, landmarks, hydrology in
  `source/simple_map.lua`), including the "4 routes per capital" load assert
  and the frozen manifest checksum that pins rule-token names; relax the
  planner to "river water by column" (D37, stale-rule R1–R3). **Done as lane
  W0 (merged 97dedcc8, output byte-identical, planning ~9 % faster).** Its
  seam: `height.river_water_at(x, z)` returns any non-empty name for river
  columns (river water, bed seal); `height.river_water_in(box)` must be true
  near rivers or bank seals are skipped; lakes return nil and get ordinary
  water; transitions are rejected until step types exist. Review notes for
  the integration lane: lakes above sea level are unsealed today (seal all
  inland water or route lakes through the river path, since native caves
  survive under the heightmap); fix the `water_class` of river/lake columns
  (`reed_angelfish.lua` and settlement paths read it); make a wet river
  column with `river_water_in == false` fail loudly; keep `river_water_in`
  cheap (called per voxel in `r6_settlement.lua`); the `r7_manifest`
  roll-up pin will trip on freshwater content (remove pins per guardrail 6
  when it does).
  **W2a (water integration) merged 0dce6bed** after review and one fix
  round: capital keep-out = farthest lot corner + 16 (280–355, noise edge,
  soft apron), plot warnings 0; chunk time +4.5 % median, server start
  +1.8 s (reports). Open for Phase 6: two reverse confluences (tributary
  lower than its parent, contained). Running: W2b (authored water) and W2c
  (map, water claim exclusions, freshwater content). Deviation from
  stale-rule D3 found in the engine: at reach steps the **higher** reach
  decides the bank ("lower decides" let a lake-to-river fall spill sideways
  and spawn new sources), and a lake's outlet step face holds river water.
  Then:
  - compute the river/lake layout once in main and hand it to emerge via
    `ipc_set` (D37);
  - city water follows the terrain (D34): the Lethariel lake keeps an authored
    approximate location in the city's north-east, the Kezamba cenote stays a
    self-contained sinkhole, a Highcourt fork only if natural;
  - the shore rule needs an exception at river steps (stale-rule D3);
  - reuse `bank_material_at` for banks;
  - freshwater content waits for this phase: papyrus (add a lower bound,
    swamps need water so the Whispering Reedlands get reeds), waterweed,
    lilies, Reed Angelfish (cap y 80 to revisit); decide whether shore crabs
    also use lake/river sand;
  - soften the straight 1–2-node contour at the dragon-channel box edges in
    the sea floor (Phase 3b review).
- **Gate:** user playtest.

### Phase 6 — Details and polish

- Rock and scree on steep slopes, cliff materials, transitions, and what the
  user finds while playing.
- Collected so far: cliff faces show dirt before stone; fine gravel speckles
  in sand; more corals and sea plants (the reef rule only uses the
  coastal-shelf class — extend to bays/near-shore sea); outpost `anchor_041`
  collar overlaps rare route `anchor_098`'s core (`height.lua`
  `fitting_grade_at` takes the first candidate); golem density on high stone
  mountains after the cap raise; emergent jungle trees may be refused by the
  writer (−4 offset, `docs/research/wp13-floating-bushes.md`); high relief
  may lack native caves (check in playtest); shore-crab spawn rate retune.
- Accepted as is (user, Phase 3 playtest): natural cave mouths that open into
  flooded pits at sea level.
- Afterwards, the general runtime cleanup round (D4).

### Orchestration and compaction points

The coordinator cuts the remaining work into packages that belong together
thematically and technically, runs independent lanes in parallel, and
compacts its context only at these points:

1. **After Phase 3b and the user's decisions on the stale-rule audit, before
   water starts.** Before compacting, this plan is brought up to date and a
   short handover note records branches, worktrees, agent results and open
   points that do not belong in the plan.
2. **Not between water (Phase 5) and roads (Phase 4):** road planning needs the
   full water context.
3. Next candidate point: after roads, before Phase 6.

## 7. Where we go for the optimum, and where we relax

| Go for the optimum | Relax on purpose |
|---|---|
| Terrain look (B, maybe C) | Tests, digests, KATs, PUC |
| Road routing and bridge look | Integer arithmetic and cross-platform byte identity |
| River valleys and lake shores | The 57-edge graph, hub stations, ingress corridors |
| Natural zone borders | Fixed landmark count and shapes |
| Capital height below clouds | The "transitions are always smooth" rule |

## 8. Risks and coordinator critique

- **R1 — Zone neighbors are wired to roads.** `world_zones.md` §9 makes route
  edges the gameplay neighbors used by travel, quests and `neighbors(id)`.
  Decided (D14): geometric zone adjacency replaces them. Phase 0 finds every
  consumer. Watch that adjacency is only **derived** from the zone function,
  never imposed as a constraint on it.
- **R2 — Embedded checks resist change.** Population and identity pins in
  runtime code will fail as soon as counts or shapes change. Phase 3/4 lanes
  remove them in the modules they touch. Anything else that trips surfaces to
  the coordinator.
- **R3 — Capital fitting under rougher terrain.** Damping plus target heights
  must keep capitals inside their cut/fill limits. The prototype measures
  this, so it is not found in-game.
- **R4 — "Capitals need not be rectangles."** The capital blueprints (WP13:
  96×96 civic core, four quadrants, gate axes) are square by construction.
  Decided (D16): this round does at most the organic outer edge. District
  layout, density and footprint belong to the follow-up (§11).
- **R5 — Water.** See Phase 5. The most likely place for complexity creep.
- **R6 — Startup cost with C.** Erosion costs seconds to minutes per world and
  needs a cache file, because the height session is built twice per process.
- **R7 — Border warp vs content.** Stronger warp can push existing content out
  of its zone: housing masks, claim exclusions, biome shares. Keep anchors
  pinned, and the rest follows the zone function.
- **R8 — Coastline.** The continent outline is made of capsules and rounded
  rectangles. Decided (D17): in Phase 2b. Risk: bays, landings, boat paths and
  coastal housing cores reference fixed coordinates, so they must follow the
  new coast or be re-derived from it.
- **R9 — Landmark reduction (D13).** Dropping names can orphan content
  references. Phase 0 lists them, and Phase 1 decides per name.
- **R10 — Trails for minor POIs (D19).** This could multiply routing and
  raster work by the number of POIs (~70). Mitigation: shared cost grid, short
  trails that join the nearest road, and an early relaxation if cost or
  complexity grows.

## 9. Answered questions (2026-09-25)

| Question | Answer | Recorded as |
|---|---|---|
| Q1 Landmarks: keep all 70 as soft fields, or reduce? | Reduce to one or two strong features per zone | D13 |
| Q2 Road endpoint per contested zone | Outpost or clash site nearest the home side | D18 |
| Q3 Outposts, mines, camps | Narrow natural trails where cheap; may be relaxed | D19 |
| Q4 Coastline | Include, improve cheaply | D17 |

## 10. Next step

On the user's explicit Go, and not before:
1. Brief and start Phase 0 (audit) and Phase 2/2b (prototype harness first,
   then variants) in parallel.
2. Draft Phase 1 while the audit runs, so the rewrite can use its findings.

## 11. Follow-up round goal: denser, more natural capitals

Recorded 2026-09-25 as the target of a later round, not this one.

- Keep the civic core as it is.
- The surrounding city moves closer together:
  - higher building density and count;
  - smaller total area than today's 512×512 build envelope and 704 blend;
  - a natural, non-rectangular outline.
- Intent: more flair. Today's capitals are large and fairly empty.
- This round only supports and prepares it (D16, guardrail 8). Phase 0
  records what depends on the current envelope size.
- **Known defect to fix there (found in the Phase 3 playtest, predates Round
  22):** house-to-lane approach stubs. Every plot puts its doorstep path on
  its −z edge and is never turned toward its lane
  (`wp13/highcourt_plot.lua` ~291–299, entry ~495; the other capitals'
  `*_plot.lua` alike); `wp13/plot_approach.lua` ~15–27 only looks for streets
  on that side within 24 nodes and otherwise paves an 8-node stub into open
  ground (`r7_settlement.lua` ~1346–1353, writer ~1503–1523). On the default
  seed only 12–16 of 52 stubs per capital reach a street. Introduced in Round
  21 (`e5611479`, `4575d691`). Fix: turn plots toward their nearest street, or
  route approaches around buildings.
