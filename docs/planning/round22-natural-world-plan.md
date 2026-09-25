# Round 22 plan: natural terrain, roads and water

Date: 2026-09-25. Coordinator: Claude Opus 5.5 (root), implementation by
Opus 5.5 subagents; the user may re-route per session
(`../process/agent-model-policy.md`, "Day-to-day routing rule").
Status: **in progress.** On 2026-09-25 the user approved Phases 0, 1 and 2/2b (prototypes in `~/projects/grudgelands-orchestration/r22/prototype-b/` and `prototype-zones/`, each with an `INTEGRATION.md`) and gave the Go for Phase 3 with variant (a): old roads and inland water are switched off until Phases 4/5, and the playtest after Phase 3 covers terrain, zones and coast only. Phases 4–6 still wait for an explicit Go.

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
   - Roads are walkable, with at most one node of step between neighboring
     road columns, so mounts and players can use them.
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
   - roads walkable (≤ 1 node step);
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
  6. Keep the ≤ 1-step grade, using cut and fill along the found path.
  7. Water crossings are chosen by cost (prefer narrow and shallow). Use one
     good bridge design (abutments, simple deck, railings) and fords for
     shallow water.
- **Removal:** the 57-edge graph, hub stations, shared junction grade solving
  and ingress corridors, with consumers adapted per the Phase 0 findings.
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
- **Gate:** user playtest.

### Phase 6 — Details and polish

- Rock and scree on steep slopes, cliff materials, transitions, and what the
  user finds while playing.
- Afterwards, the general runtime cleanup round (D4).

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
