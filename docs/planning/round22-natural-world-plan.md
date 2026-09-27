# Round 22 plan: natural terrain, roads and water

Date: 2026-09-25. Coordinator: Claude Opus 5.5 (root), implementation by
Opus 5.5 subagents; the user may re-route per session
(`../process/agent-model-policy.md`, "Day-to-day routing rule").
Status: **in progress.** Phases 0–3, 3b, 5 and 5b are done, **accepted by the user** (water accepted 2026-09-26), merged, synced and pushed (8aaeeb9f). The context is compacted now (D62). Next, on the user's Go: three packages together — the Phase 4 road prototype, the D63 performance analysis and the D64 chunk-edge analysis; later the capital planner (D60, §11) and Phase 6.

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
| D40 | *(Superseded by D57, 2026-09-26.)* **Capital water keep-out covers the whole built area** (about 280 nodes from the core, irregular noise edge like the D28 calm edge), so districts stay dry and rivers bend around cities naturally instead of in circle arcs; rivers may still pass close by. Starts keep ~300–320. | Prototype: rivers crossed the district ring (155–260) at almost every capital; circular bends around the 140 ring. |
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
| D52 | **Moonfall keeps its crescent lake in a calm bowl** added to the terrain field around the landmark (radius ~120, blend ~90, the steep-POI bowl mechanism), with a natural-water keep-out; the terrain and rivers around it change. | User, 2026-09-26, on lane W2b's images: the landmark sits on a 30–90-node coastal slope on every seed. |
| D53 | *(Superseded by D58, 2026-09-26: one level, no rapids.)* **Highcourt's canals are one continuous canal with river water and small 1-node rapids** (like the natural rivers), not a chain of basins with dry weirs. As built: 1-node steps, 2 where the ground drops faster (max 2 on the tested seeds). | User, 2026-09-26, on lane W2b's images ("sausage chain"). |

Decisions after the Phase 5 playtest (2026-09-26, user with coordinator):

| # | Decision | Basis |
|---|---|---|
| D54 | **River cross-section is a trough ("Mulde"),** like a lake along a line: the river carves a smooth trough blended organically into the terrain (V-shaped in steep ground, U-shaped in flat ground, never a stamped channel), whose width varies along the course with flow, noise and terrain. The water fills the trough up to the reach's flat level; wet is where the trough ground lies below the level, so the water width and the shoreline vary by themselves and the trough need not be full. No flat floodplain strip; the sand band beside rivers becomes narrow, its material following the real bank slope. | User playtest: every river looked the same (several nodes of flat sand, then an incised channel); lake shores look very good everywhere. |
| D55 | **Rivers are wider:** about twice today's water width, minimum about 6 nodes of water, with clearly more width variation along the course. Upstream of the point where a river reaches its minimum width, its trough continues as a dry gully that fades out (no 1–2-node trickles). | User playtest: 1–2-node rivers look wrong; width barely varied. |
| D56 | **Unambiguous flow direction:** reach levels never rise downstream, confluences included (a tributary meets its parent at or above the parent's level). The trough's fill level absorbs inaccuracies of the bed profile. | User playtest: water surfaces rose and fell "in illogical order", most visibly in Highcourt. |
| D57 | **Water keep-outs only for start towns and protected capital cores** (supersedes D40). Rivers and lakes may cross a capital's reserved area outside its core; defects there (plots or lanes in water) are allowed until the capital planner package (D60) repairs them. Start towns keep a water keep-out of about 300 and a fixed layout. | User: water may flow everywhere except through start towns and capital cores; the capital planner gets the tools to handle any situation (walls over rivers, bridges). A dry river bed beside Highcourt came from the old keep-out or the sink relaxation. |
| D58 | **Canals:** one canal system holds **one water level** everywhere. Its trough follows the terrain and is filled to the highest level that spills nowhere; its rims may be raised artificially (walls) to guarantee a minimum depth. Canals are not connected to world water: the capital planner routes them clear of natural rivers, or takes a river's level where it crosses one; where rapids or several levels meet, it picks a suitable joining point and seals the canal against conflicting water or interrupts it there. Built by the capital planner (D60). Interim for Phase 5b: Highcourt's canal becomes one level with raised rims where needed, interrupted where natural water comes close. | User, 2026-09-26: connecting to world water is a risk (the planner may find no suitable river). |
| D59 | **Capitals keep a reserved maximum area** (as today's envelope). The road network is built before the capital layout and runs up to the edge of the reserved area. The capital planner places walls and the four gates by its own rules inside the area; each gate faces one cardinal direction and sits so that the planner can connect it with a connector road from the gate to the road end at the reservation edge. | User, 2026-09-26. |
| D60 | **New work package "capital planner"** after water and roads: a one-time start computation after height, water and roads. Protected civic cores stay untouched (no water, no changes). Within the reserved area it places districts, houses, lanes, walls (which may cross rivers), bridges, the four gates with connector roads (D59) and canals (D58), so each capital fits its landscape. It absorbs the §11 goals (denser, more natural capitals) and the alley-stub defect. Start towns stay fixed and protected. | User, 2026-09-26. |
| D61 | **Water bugs fixed in Phase 5b:** bright stripes at chunk edges on deep lake floors (lighting); civic water steps show no flowing water (natural rivers do). | User playtest. |
| D62 | **Compaction point moves:** after the user accepts water (Phase 5b), before roads — so road work starts with a clean context (supersedes compaction point 2). | User, 2026-09-26. |
| D63 | **Performance analysis package, parallel to the road prototype** (start right after the D62 compaction), as preparation for the general cleanup round (D4). One agent in its own worktree finds where the mapgen can get faster and estimates gain and risk per item. **Byte-identical changes only** (algorithmic improvements, removing redundant checks and dead work); anything that changes the world — e.g. dropping a noise octave — is excluded and at most listed in one line as "deliberately excluded". Guardrails: (1) areas the road integration will rebuild (road IDs in the planner, road overlay/raster, exclusion kinds) are only flagged "re-check after roads"; (2) nothing is merged during the road integration — the agent may prototype and prove byte-identical patches in its worktree (probe grids on several seeds + engine full digest, as in W0) to measure instead of estimate; small changes in code the roads surely do not touch (e.g. the per-voxel light integer checks) may be proposed to the user one by one earlier; (3) timing with paired before/after runs and the noise reported; big measurement runs when no heavy road run is active. Deliverable: a ranked list (measured gain, risk, proof method, "before/after roads") plus the proven patches; performance numbers stay reports (D32). | User, 2026-09-26: no specific pain point; the agent finds the potential itself; the world looks good and must not change. |
| D64 | **"Chunk edge" package, parallel to the road prototype** (start after the D62 compaction, a third package next to D63): find a robust, performant solution for everything that happens in the halo of an already generated neighbour chunk — lighting, sealing river/lake beds where later v7 caves cut in (accepted for now, Phase 6 note), v7's provisional overtop blocks. Start from an invariant, e.g. "every node's final light equals a from-scratch recomputation regardless of generation order", instead of per-case heuristics. **Analysis first:** the agent writes the invariant, two or three solution paths with effort, risk and cost, and their effect on bed sealing and the pre-existing checkerboard too-bright nodes; the user picks one before implementation. Performance counts: the cost must stay within a reasonable frame (today's correction costs roughly 0.5–1 % of chunk time; a clearly larger cost is escalated). Evidence with the lighting checks (census + windows in several generation orders), used with judgement: a tool for lighting changes, not a gate on every change — quick, reduced runs while iterating, the full run once before merge; no new measurement corset (user, 2026-09-26). The D63 performance agent leaves the lighting/halo code alone and only flags findings there. | User, 2026-09-26, after four review rounds on chunk-edge lighting (W3a, Fix A). |

Decision on the D64 analysis (2026-09-26, user accepted all
recommendations; analysis in
`~/projects/grudgelands-orchestration/r22/chunk-edge-d64/ANALYSIS.md`):

| # | Decision | Basis |
|---|---|---|
| D65 | **Chunk-edge light: path B, exact relight of the VM interior with the VM's outer 1-node shell as boundary.** Zero both light banks inside the shell, a Lua sun pass per column in three vertical groups (block above the owner, owner, block below; a fresh group neither blocks nor carries sun), then engine spread only; replaces `presun`, the min-merge and Fix A. **With B1:** owner columns under a still-fresh chunk above take their sky from the plan's column tuple instead of "open above water level". The full-volume light-buffer validations are dropped (one light read, a few checked values). **B2** (hand sun changes deeper than 16 rows to `core.fix_light` on the main thread) **later, only if visible in play. B3** (repair the 1-node v7 noise-tunnel slivers in the top row of an already generated chunk below) **not now.** | The order probe found three failure classes the lighting checks did not see: stale v7 daylight in sealed caves (1 800–7 000 nodes per box), daylight under roofs at chunk tops when the chunk above came first (6 169 in a Highcourt box; the checker-order too-bright nodes are this class), and missing lamp/torch light at chunk borders because the min-merge can never brighten an older neighbour (up to 30 418 nodes, down to −11). The path B prototype: 0/0 in three boxes and all orders, light identical across orders, checker windows 0/0 (main 21); the light transaction costs 9.6 ms per chunk instead of 39 ms. Open: small −1/−2 residues at Highcourt (river water on mapblock-aligned columns, night light above torches) to be explained during implementation. |

Decision on the D63 analysis (2026-09-26, user accepted all
recommendations; report in
`~/projects/grudgelands-orchestration/r22/perf-d63/REPORT.md`):

| # | Decision | Basis |
|---|---|---|
| D66 | **Merge the seven byte-identical D63 patches now,** after an independent review and before the road integration starts (the road prototype is offline): R6 planner cell cache, LuaJIT `hotexit=200` in main and emerge, writer anchor-grade memo, allocation-free `prepare_cells`, direct-mapped field-sample memo, packed-key blueprint sort, `param2_kind` memo. **Re-check the planner cell cache's purity** when the road-corridor exclusion kind joins the static exclusions. **Cleanup round (D4):** remove the two redundant full-volume validity checks (`map_adapter.lua`, `r6_settlement.lua`, ~1 % of chunk time); make the main-start terrain audit (`settlement_terrain_findings`, log warnings only, ~3.7 s) switchable — default off since roads and the capital planner are merged; lanes that change ground near settlements (e.g. D76) run with `grug_mapgen_terrain_audit = true` in their checks; emerge re-preparing all settlement blueprints (~3.5 s); noise code still 38 % interpreted. Column cache 64k → 256k dropped (gain within noise, +50 MB). | Engine, three swapped pairs over 98 chunks: chunk time ×0.61–0.69 (~500 → ~320 ms on expensive chunks), main construction ×0.72–0.81, emerge construction ×0.64–0.73. Byte identity: engine digest over 50 M voxels on two seeds, whole-map probe grids on three seeds, 510 blueprint identities. |

Decisions on the Phase 4 road prototype (2026-09-26, user; prototype in
`~/projects/grudgelands-orchestration/r22/phase4-proto/`):

| # | Decision | Basis |
|---|---|---|
| D67 | **Integrate variant p4** (hard ≤ ½ rule, routing preference for grades gentler than ~1:4) on the shared 16-node grid; **no stairs on trails; no tunnels yet** (decide after the playtest); **Stormvault's outpost `anchor_027` stays** the showcase mountain road. **More connections:** all trail candidates are built (no cost budget; drop one only for a stated reason), and the loop threshold is lowered for about 2–4 loops per world. **Decks** only as a one-sided gallery (uphill side on the ground or in a shallow cut, downhill side on pillars — typical at serpentines) or as a short valley crossing (both ends on the ground, about ≤ 32 long, ground below lower than both ends); any other deck (free on both sides, the profile lagging behind the terrain) is a route error and feeds back into routing cost (D51); metric: free deck columns outside short crossings, rough target 0. **Cuts:** cut slopes get the terrain's own surface (grass/dirt, rock in stone), retaining walls only at the foot of deep cuts; on steep side slopes a half gallery (shallow uphill cut, downhill half on pillars) beats a deep uphill cut; cuts deeper than ~6 cost more in routing. | Prototype: p4 cuts deep-cut runs and long decks sharply against the hard rule for ~4 % more length; 70–80 % of deck columns were already one-sided, but 105–258 per world floated free on both sides (mostly the Stormvault serpentine); 7–10 % of road points lie in 2–6-node cuts, < 1 % deeper. The user: roads should look like "yes, this is how one would build a road"; floating roads only one-sided at serpentines or as short crossings; cuts are always unsightly. |
| D68 | **After the D67 self-gate (2026-09-26):** round one of the D67 rules cut free decks by only 19–74 % while deep cut banks grew 4–5× and road construction doubled (7–8 s → 15–17 s), and it turned the Stormvault serpentine into a long ridge-face gallery. Cause: the 16-node routing grid cannot see sub-cell cliffs (20–30 nodes of drop over ~20 nodes inside one cell). Next: **one bounded attempt with sub-cell relief in routing** (steep cells only, carved ground sampled at the four half-cell points once in main, route on the steeper of coarse and sub-cell grade). If it does not clearly reduce free decks without worse cuts or detours: **fall back** to round one without the hard routing grade cap and without feedback re-routing (keep the half-gallery term, all trails, the lower loop threshold) and judge the rest in the playtest. **Free decks are an accepted last resort,** avoided where possible; no trails are dropped for them and no trail cost budget returns. Stormvault stays; revisit `anchor_028` only if the playtest shows floating roads there. | User. |
| D69 | **Capital planner design accepted** (all 13 questions as recommended in `docs/research/round22-capital-planner-design.md` §9): option A — keep the civic core and all plot kits, plan per seed an organic outline, four cardinal gates (always four), avenues and lanes, and place the existing plots rotated to face their lane (fixes the approach stubs); infill houses (option C) later as a stop point. Streets and connectors use the road module's half-step profile. Walls follow the outline as polylines (fallback: straight segments with turrets); Lethariel and Kezamba stay unwalled with a planted edge/thresholds. The 532 square stays the protected area and guard-level-60 zone; the city stays inside it. Rough size ~110–150 k m², 20–30 % built. Four districts stay recognisable groups. Highcourt's canal is rebuilt by the planner (dropped first if it grows). The band between wall and reserved edge stays natural terrain first. Non-required plots may be left out on cramped seeds (count logged); required plots (inn, cook, eight service plots, stable) are always placed. "Beyond its walls" is reworded for the two open capitals when the planner lands. Order: offline Highcourt prototype first, the other five after its look is accepted, integration after roads are merged and playtested. | User, 2026-09-26, on the audit and design draft. |
| D70 | **Capital planner prototype decisions (Highcourt, 2026-09-26):** avenues plus two terrain-bent rings stay the base, loosened by a few cross-lanes, rings not closed everywhere and small squares at crossings (bounded effort, so six capitals don't repeat one pattern); target area ~100 k m² first (infill houses only if still empty); plots that don't fit overflow into the neighbouring district before any is left out, and only fields and fill pieces may be left out (named district buildings such as library and scriptorium stay, quest texts name them); shore walls with kinks are fine; the simple one-level quay canal along ring 2 stays; a gate may shift more than 60 to avoid water; **start cost** (measured 2.6–3.9 s per capital, 70–75 % sampling) is cut in integration with carved-ground sampling (estimate ~1–1.5 s per capital), re-measured after integration and escalated if it stays clearly higher. Next: apply these to Highcourt, then the other five capitals in the offline prototype while roads integrate. | User, on `~/projects/grudgelands-orchestration/r22/capital-proto/` (option A: 0 plots in water, required plots always placed, 0 grade violations, rotation checked on 52 plots × 3 turns with 0 illegal writes; Nhal Veyr's straight grading edge gone with the square terrace dropped). |
| D71 | **World start cost (2026-09-26):** the longer start is accepted (main loader ~11 → ~19 s with roads, plus the capital planner later). **Layouts are cached in the world folder** (partly supersedes D37's "no cache file"): water, road and later capital layout texts are stored once per world and reused on later boots, keyed by everything they depend on (seed, mapgen source identity, relevant settings), rebuilt when the key differs, never trusted without a matching key. **Plus a bounded, output-identical speed pass on the road build** (same layout text before/after). Both after the road merge, in one lane. | User, on the road integration's start cost. |
| D72 | **Capital planner round 2 (all six capitals × three seeds, 2026-09-26):** accepted as recommended — planner start cost ~2.2 s per capital (~13 s for six; with the D71 cache only on a world's first start), no 3-node grid; Kezamba's lakeside market stays pinned to the lake and its 9–11 plots overflow into the neighbouring district; fields, pastures and gardens left out on cramped ground (0–6 per capital) are fine; the open capitals' planted belt plus four thresholds is enough for now; density (24–29 % built) and whether the six capitals look too alike (round outline, central core, cross of avenues, two rings) are judged in-game after integration, infill houses and more variety after that. Integration must rotate the inn arrival offset with its plot (with the fixed +x rule 5 of 6 inns are blocked in some rotation). Integration starts after the road playtest (D69). | User, on `~/projects/grudgelands-orchestration/r22/capital-proto/` round 2 (100 k m² each, required plots 9/9, 0 plots in water, 0 grade violations, rotation checked on all 304 plots). |
| D73 | **Order after the road merge (2026-09-26, amends D69/D71):** the capital planner integration starts right after the road merge, in parallel with the user's road + light playtest (road changes after the playtest flow into the planner automatically, since it computes connectors from the current road layout at every world start); the output-identical road build speed pass runs in parallel (road module only); the world-folder layout cache comes after the capital integration, so it also covers the capital layout; the next playtest then includes the new capitals. | User. |
| D74 | **Road surface materials after the road playtest (2026-09-27):** exactly one surface material per road everywhere (may differ per race/zone), also on decks and galleries on pillars — no second (wood) surface where a road stands on supports; **no railings/fences anywhere** (on curved roads they read as a chaotic collection of fences, not a railing); pillars may use a second material. **True bridges** over rivers and lakes may be wood, but then the **whole bridge stretch** (the contiguous raised section that crosses the water, bank to bank) is wood; never mixed wood/stone within a section by support situation. | User playtest: the routes look great and fit; only the half-wood/half-stone surfaces and the fences on curved decks look wrong. |
| D75 | **Trails and railings (2026-09-27):** trails use the race's road material, only narrower (no gravel with stone slabs — one material per road, D74). Railings in capitals only on straight streets and bridges; curved ones get none (curved railings look broken). Authored straight civic structures keep theirs; the capital planner rails a planner-made street bridge or deck only where that section is straight. | User. |
| D76 | **Capital surroundings after the capital playtest (2026-09-27):** the flat, bare plateau outside the walls is too large. (1) The calm, flattened area is still made before the capital planner runs (the planner plans on it); it only becomes somewhat smaller than today and rounder instead of square, still large enough that any city layout fits easily; outside it the natural terrain, trees and ground cover come back. (2) Protection (immutable zone) = everything inside the walls, the walls themselves, and a band of 10–20 nodes around the walls; outside the band normal rules apply. The old 532-node square protection (`hard_capital_build_plus_apron_v1`) is replaced. (3) The band has restricted vegetation (no trees, no ground cover) so players see where protection ends. (4) Shape: organic, following the wall polyline (roughly round); an approximation is fine — a union of rectangles or a coarse precomputed raster (e.g. 4-node cells: inside/outside) — as long as protection checks stay cheap. Everything inside the walls must be covered. | User playtest. Open for the package: what exactly makes the plateau flat and bare (anchor damping mask radius in `terrain_field.lua`, the capital collar, vegetation suppression in the protected square) and what the planner needs as calm ground; protection consumers (`grug_core` hard volumes, guard level 60, water guard, housing/claims masks, preparation boxes) must accept the new shape. |
| D77 | **Phase 6 surface look (2026-09-27):** (a) rock amount "less": steep slopes turn to bare rock from a grade of about 2.0–4.0 nodes per node (noise jittered), steeper steps keep soil over a stone face; (b) the gravel speckles in beach sand stay removed; (c) shore crab chances stay retuned to the measured near-water share (Shore Crab 300, Reef Lurker 1100); (d) high relief keeps the native caves as they are (option A); own cave tunnels in the terrain fill (option B) are a possible later package. | User, on the p6-look images and the representative sample numbers (`~/projects/grudgelands-orchestration/r22/p6-look/README.md`). |
| D78 | **Start town surroundings (2026-09-27), like D76 for the capitals:** (1) the start towns' layout and town ground (the flat 128-node pad) stay unchanged. (2) Protection = the town ground plus a band of 10–20 nodes around it (following the pad outline with rounded corners), replacing the 148-node square (`hard_start_core_v1`) and any larger anchor-blend envelope that refuses vegetation, ground cover, gathering or claims; terrain editing is forbidden in the band, and the band has no trees and no ground cover so players see where protection ends. (3) The band carries a natural transition from the town ground to the surrounding natural surface: block types change irregularly (noise), so no straight edge or hard corner of the pad stays visible. (4) The calm plateau becomes smaller so natural terrain starts right beyond the band; the height transition starts in the band and runs out softly just beyond it (hills, never a cliff or a wall); outside the band the ground may be slightly graded in the first nodes but is vegetated and editable as normal. Reuse the D76 mechanism (band, consumers); the band around a square pad can be an analytic rounded-square distance. Starts after the D76 merge. | User playtest: the start towns' pad is stamped into the world as a visible square, the flat plateau is large and the protected area somewhat too large; the user likes layout and ground. |

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
  - Capital endpoints: roads end at the edge of each capital's reserved area
    (D59); the capital planner (D60) later places the gates and connects
    them. This replaces "endpoints from the blueprint gates" (stale-rule
    R11/D22). POIs already sit in the terrain (D33), so trails end on
    natural ground.
  - Rivers are wider after Phase 5b (D55), so bridges get longer; water may
    cross capital reserved areas (D57).
  - Route the network once in main and hand it to emerge via `ipc_set`, no
    cache file (D37). Measured: an 8-node whole-map grid costs ~13 s on the
    natural field, ~45 s on final heights, per build.
  - Map hook: `road_polylines()` in `mods/PLAYER/grug_map/base.lua` returns
    `{}` today; fill it and the map base re-renders.
  - Water exists first (D30), so crossings fall out of routing.
  - **Seams left by the water phase:** `height.water_coarse_grid()` (the
    16-node natural-field grid the water layout is built on, main only) for
    the routing cost grid; `planner_source.overlay_exclusion_at` (W2c) —
    add a road-corridor exclusion kind there; the water layout text travels
    in the same `ipc_set` payload (field `water_layout`, ~125 KB), roads get
    their own field; the world map already draws rivers
    (`river_polylines()` next to the empty `road_polylines()`); planner road
    feature IDs map unknown IDs to ordinal 0 today (W0) — intern a few
    generic road/bridge IDs (stale-rule R2); the water guard in `grug_core`
    allows only planned step flow in protected territory (W3a).
  - Water may now cross capital reserved areas (D57); roads end at the
    reserved area's edge (D59), so roads never need to cross water inside a
    capital.
  - The capital planner (D60) must be able to route the connector from a
    road end to its gate with the same routing, profile and raster (§11), so
    the road module exposes point-to-point routing as a reusable function.
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

- **As built (merged `7a30f0e0`, 2026-09-26):** option 2 per D68 — p4 grade
  preference, all 40 trails, loops at network/straight ratio 1.3 (2–4 per
  world, a loop whose core pin doesn't fit is dropped), half-gallery profile
  term; no hard routing cap, no feedback re-routing, no sub-cell grade
  (option 1 measured and dropped: 2–5× more free decks, cuts to 57, build
  17–28 s). `wp40/road_layout.lua` (built once in main, `ipc_set` field
  `road_layout`, 144–153 KB), raster in `height.lua` `final_values_at`
  (roads never change a POI/village building core; every road end is pinned
  to the fitted pad and meets it walkably), `wp40/road_writer.lua` (road
  material + slabs, decks/bridges with pillars, retaining walls, materials
  per race; stamps win; since D74 one surface material per road, no rails,
  whole wooden bridge runs), `road_corridor` exclusion kind,
  world map `road_polylines()`, preparation bounds, `/road_spots` and a start
  log line with showcase spots. Road build 8–10 s in main; road chunks
  +3–13 % chunk time. Evidence: engine 0 steps > ½, 0 seam defects, 0 leaks;
  main vs emerge identical. Open: free decks remain as the accepted last
  resort (mostly Stormvault and mountain trails); `layout.connect` needs a
  session-level re-serialize/sampler rebuild/memo flush for the capital
  planner; a dropped core pin (never seen) is not logged yet; old
  `source/catalog.lua` route tables and dead planner bridge/ford/causeway/
  tunnel branches are for the D4 cleanup.

- **Capital planner as built (merged `631fde41`, 2026-09-27):**
  `wp40/capital_planner.lua`, `r7_capitals.lua` (`plan_all` once in main after
  height, water and roads; fails loudly on an unplaced required plot),
  `r7_capital_blueprint.lua` (replaces the six per-capital blueprints),
  `wp13/city_edge.lua` (polyline walls, gatehouses, turrets, palisade, planted
  belt with four thresholds, arcades over water); streets, lanes, squares and
  connectors are road-module roads added through `session.add_roads`, the
  Highcourt quay canal through `add_authored`; `ipc_set` field
  `capital_layout`; plots rotated to face their lane (inn arrival rotates);
  `height.lua` drops the square terraces for a `capital_collar` (40) profile
  field; city streets stop at the core footprint (±49); a lake-side axis
  without a core landing starts its avenue on the nearest dry shore
  (Lethariel). Evidence: 32 seeds offline and 8 engine boots clean (the one
  post-merge FAIL was a harness port collision, tool fixed `13b4647c`); civic
  cores, all 304 plot builds and start towns byte-identical to before;
  rotation 0 wrong of 4 059 sockets and 657 doors; main vs emerge identical;
  plot warnings on seed 1 41 → 0; main loader +7.5 s on a fresh start.
  Accepted: the Dur Brannoc connector ford step (7 columns on s8675309), a
  fence post at one lane junction mouth, a connector through a turret
  leaves a hole. Open for the cleanup round: y culling of edge/collar work,
  the overlay bounds table mixing anchor-relative x/z with absolute y.
- **D71 as built (merged `e3d69a3d`):** `<worldpath>/grug_world_layouts.txt`
  holds the water, road (incl. city streets) and capital layout texts plus
  diagnostics, keyed by format, full seed, a digest of every `.lua` under
  `grug_mapgen`, the v7 settings and the Lua interpreter; any mismatch or
  damage rebuilds, deleting it is always safe; the preparation identity
  binds a digest of the texts. Main loader ~25.4 s on a miss, ~8.4 s on a
  hit (seed 42). Any `grug_mapgen` Lua edit rebuilds once. Open (low): a
  hit that passes all hashes but fails construction stops instead of
  rebuilding (only possible with a hand-edited, re-hashed file); fixed in
  the cleanup round (lane B).

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
  lower than its parent, contained). **W2c merged 8909c913** (map rivers,
  water/bank exclusion kinds via `overlay_exclusion_at` — Phase 4 can add
  road corridors there — freshwater content, sand/gravel tops over the water
  seal, SOURCE_PROJECTION pin removed). Review nice-to-haves for Phase 6 /
  cleanup: the settlement analytic mirror differs from the writer on sealed
  anchor-grade/POI-collar columns (write the top over opcodes 17/18 only
  where `analytic_p7_support_ref` is non-nil); dead `scratch.wet_surface` in
  `r6_planner.lua`; crab `near_water` scan cost; river width comment
  mismatch in `grug_map/base.lua`; the housing scan (101² exclusion queries
  near water) needs care when housing gets a consumer; settlement time on
  river chunks +22–38 % (report). Papyrus and Frost Melon densities are gut
  values for the playtest. **W2b merged 68869173** (+ 4a318076): Kezamba
  cenote, Lethariel crown lake, Highcourt canal (D53), Dawnmere/Sunscar
  ponds, Moonfall bowl and crescent (D52); civic water keeps ≥ 8 nodes off
  every plot (`r7_settlement.plot_rects`); wet civic columns drop
  `land_grade` (its air clearance had beaten water). Notes for Phase 6: the
  exclusion `bank_d` prefilter relies on the authored warp gradient (≈ 2
  nodes of slack at Dawnmere; add a comment or a checker line); the
  Highcourt canal starts and ends blind and its east arm is nearly straight
  (user judges in the playtest); ~+12 % chunk time on lake chunks (report).
  **Phase 5 complete, waiting for the user's playtest.** Deviation from
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

### Phase 5b — Water rework after the playtest (2026-09-26)

- **Goal:** rivers that sit organically in the landscape (D54–D56), water
  allowed everywhere except start towns and capital cores (D57), and the
  playtest bugs fixed (D61).
- **Lane W3a — bugs (small):**
  - lighting: deep lake floors show bright stripes along chunk edges (the
    interior is lit correctly by depth); find the cause (lighting pass range
    or propagation at chunk borders) and fix it; check the sea floor too;
  - civic water steps do not flow (Highcourt), while natural river steps do;
    find why (liquid update not queued for the settlement writer's region,
    or neighbouring air cleared/overwritten) and fix it, since the capital
    planner will need it;
  - Highcourt canal interim (D58): one level for the whole canal, rims raised
    where needed, interrupted with a sealed end where natural water comes
    close.
- **W3a lighting decision (user, 2026-09-26):** after three review rounds on
  chunk-edge lighting (too bright under deep water; too dark under water
  crossing a chunk top; too dark under not-yet-generated blocks above halo
  columns), the fix is "Option 2": seed sunlight at every ignore→real
  transition whose original day light is 15, with one shared helper for the
  settlement writer and the map adapter; the probe counts liquids and
  non-liquids against a reference. Fallback "Option 1" only if that round
  does not reach 0/0 or costs noticeably: keep the old light below ignore in
  halo columns (never worse than before).
  - **W3a merged (2026-09-26):** lighting — v7 lit its temporary
    geometry and spread that light up to 14 nodes into an already generated
    neighbour, which the writer restored; the halo now takes the lower of
    original and recomputed light inside the relit box (engine: brighter
    liquid nodes 19772 → 0 at the lake, 158 → 0 sea floor, 328 → 0 river);
    review fix: the zeroed slice above the owner now takes the sun from each
    sunlit seed (day bank), so water crossing a chunk top is no longer too
    dark (Lethariel crown lake 58216 too-dark nodes on main → 0; all eight
    probe windows 0 too bright and 0 too dark); second review fix: every
    real segment below a still-fresh (ignore) block in the relit box also
    takes the sun (shared `halo_light` helper in `map_adapter.lua`, used by
    both light transactions); liquids and other light-transparent nodes 0
    too dark in three forced generation orders, the few too-bright nodes of
    one order identical on main (the owner's sun scan ignores shade from the
    chunk above, older behaviour).
    Civic steps — `grug_core`'s water guard reverted all flow in protected
    territory; planned step flow is now exempt (Highcourt steps flowing
    0/276 → 266/276 before the canal became one level). Canal — one level
    halfway between the lowest bank ground and the highest ground under it
    (raised banks up to 6, trough cut up to 6 on the three seeds), sealed
    8 nodes off natural water (checked with keep-outs shrunk to ~core).
- **Lighting regression found after the W3a merge (2026-09-26):** a broad
  census (30×30 chunks, normal order) showed ~391 k too-dark air nodes under
  open sky on main 84c1c9dc (base f6e66330: 3): `presun` seeded sun only at
  the first real node below ignore, which is v7's provisional overtop stone.
  User decision: **Fix A** — every sunlight-passing node with original day
  light 15 in such halo columns starts a sun run (census back to 3 / 0). The
  census joins the windows as the lighting check
  (`~/projects/grudgelands-orchestration/r22/lighting-checks/`), run when
  lighting code changes, reduced while iterating — not on every change.
- **Result (2026-09-26, merged 4d74c2e8, after three review rounds):**
  troughs blended into the terrain (U in flat, V in steep ground), water
  width median 13–14 (was 7), fewer than 6 nodes only at 1–6 samples per
  seed, width variation doubled; levels never rise downstream (0 on three
  seeds, confluences and lakes included); dry source gullies; hard
  keep-outs only for start towns (300) and capital cores (~100–130) plus a
  disc around the crown lake and cenote — the soft lens around cores was
  tried and rejected (it folded centrelines), so rivers bend around cores in
  arcs (user judges in the playtest); lakes are lowered at most 4 and only if
  half their cells stay wet, otherwise the river sinks before the lake with
  a tapered end; tall falls at flat confluences spread over small steps;
  POI and keep-out detours smoothed. Capital plot warnings 26–58 per seed
  (allowed, D57). Chunk time about +3 %, layout build ~5 s, payload
  ~125 KB (reports). Lighting Fix A merged 9f8cbf44 (census 3/0 like the
  pre-W3a base).
- **User acceptance (2026-09-26):** "very satisfied"; water is done. Only
  Highcourt's civic water is still somewhat "chaotic" — in the worst case the
  capital planner reworks the water inside the civic core too (see §11).
- **Lane W3b — rivers v2:**
  - trough model (D54): a smooth V/U trough blended into the terrain, width
    varying with flow, noise and terrain; water fills to the flat reach level;
    wet where trough ground < level; no floodplain strip; narrow sand band;
  - width (D55): about 2× today's water width, minimum ~6, more variation;
    sources start as a dry gully that deepens into the river;
  - flow direction (D56): reach levels never rise downstream, confluences
    included (fixes the two reverse confluences left from W2a);
  - keep-outs (D57): only start towns (~300) and protected capital cores
    (core plus a small margin, irregular edge); remove the lot-derived
    capital keep-out and the apron; check the dry river bed beside Highcourt;
  - keep what the user liked: river courses, the amount of water, lake shores;
  - update `world_zones.md` §7.4 to the new rules.
- **Evidence before merge (user sees images):** whole map on 3 seeds;
  cross-sections at ~8 places (mountain, hills, lowland, mouth, confluence,
  source gully); 1-node windows before/after; statistics of water width
  (min/median/max, variation along a river); a monotonicity check of reach
  levels including confluences; containment 0; chunk seams 0; engine probe
  (liquids as planned, rapids flowing at steps, no leaks); capital plot
  warnings reported (allowed, D57); chunk and start time (reports).
- **Then:** the user's playtest. When the user accepts water, the plan and
  handover are updated and the context is compacted (D62) before Phase 4.

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
- Corrected by the D64 analysis (2026-09-26): the "river-bed holes" on seed
  8675309 are not v7 caves cutting into a neighbour. All sampled holes are
  identical in every generation order; they are planned river columns beside
  Highcourt (river:26) and at a tributary junction (river:1) that the capital
  builds over with pavement and soil, with no water anywhere — the dry river
  bed beside Highcourt, owned by the capital planner (§11). The only
  order-dependent content change is 1-node air slivers from v7 noise tunnels
  in the top row (y = 47/127) of an already generated chunk below; harmless
  underground, not observed on a bed seal; repair (B3) deferred (D65).
- **Chunk-edge light, as built (D65, merged `eb5f19e3`, 2026-09-26):**
  `halo.relight` in `r6_settlement.lua` (R5's unreachable standalone light
  transaction and `halo_light` removed from `map_adapter.lua`); B1 reads
  "open sky" as terrain, water and bridge deck not above the owner's top;
  sunlit light sources at a sun entry defer to the node below. Evidence:
  content and param2 unchanged vs main (six boxes, 55 M nodes); order probe
  0/0 in all orders; full lighting check windows 0/0 in every order (checker
  was 49 too bright), census 8/0 = flowing-water artefacts; light transaction
  ~11 ms instead of ~38 ms per chunk. Engine residue, identical on main:
  after a block reload, `update_block_border_lighting` relights some block
  faces one darker (e.g. 469 river nodes −1 in a Highcourt box; gone with
  unloading off). Known limits (review): chunks whose writer changes nothing
  light-relevant keep v7's native light (mostly deep pure-v7 chunks); B2
  also covers a newly shaded column whose bottom shell keeps a stored 15;
  B1 predicts surface-cave mouths as closed until the chunk above exists.
  Lighting-check targets `river_cross47` and `river_rapids` are stale since
  W3b moved the rivers (tool note, not re-targeted).
- **Capital surroundings (D76, first Phase 6 package):** a somewhat smaller,
  rounder flat area, still made before planning and large enough for any
  layout (margin measured over seeds), natural terrain and vegetation back
  outside it, protection = city + walls + a 10–20-node vegetation-free band instead
  of the 532 square. Prototype/measure first (plateau width and bareness
  before/after on three seeds, planner results unchanged: required plots,
  0 plots in water, 0 grade violations), then integrate with the protection
  consumers; images for the user.
- **D76 as built (lane `worktree-agent-a226fe183a93176d1`):** the flat, bare
  ring had two causes: the terrain field's capital bowl (`terrain_field.lua`
  damping, calm to 260 and faded out by 520–750; the 40-node collar only
  shapes the core's edge) and the claim exclusions — trees refused in the
  532 hard square, ground cover and gathering refused in the whole 704-node
  anchor-blend square. Now the bowl is calm to 200 and faded out by 400
  (+ up to 45 % edge noise), centred on the civic core; damping below 0.1 to
  256–266 (was 304–352). A capital's hard protection and its claim envelope
  are one shape, the protected city (`wp40/capital_protection.lua`): inside
  the planned wall line (open capitals: the same outline under their belt),
  the civic lake where the outline crosses it, plus 9 (edge reach) + 12 (band)
  nodes; integer column intervals per row, built from the capital layout text
  in main and emerge (~0.04 s for six), handed to every horizontal session
  through a holder; the 532 square stays only as the index box and zone-field
  keypoint (keypoints identical). Every protection consumer answers from the
  zone authority or the static exclusions, so none needed its own change;
  comments/docs updated. Connectors search up to 16× (was 4×). Offline over
  48 seeds × 6 capitals (`~/projects/grudgelands-orchestration/r22/d76/`):
  required plots 288/288, 0 plots in water, 0 connector failures (main: 1),
  wall ≤ 250 from the anchor (95 % ≤ 215), calm margin beyond the farthest
  wall point 7–100 nodes (mean 51; ring averages — in the worst direction the
  natural share reaches 0.1 at about 249); protected area 122–156 k m² per capital
  (was 283 k); land refusing trees within 448 nodes ~110 k m² (was ~265 k),
  ground cover ~115 k m² (was ~460 k). Layouts move (terrain changed): 94 % of
  plots at other positions, placed plots per capital unchanged on average.
  Street grade steps (> ½ between adjacent road columns) exist on main too
  (54 in 9 of 288 plans) and now 85 in 15. They are not only at the gates:
  of 60 on the final 24-seed run, 34 lie within 12 of the wall line, 10 well
  inside the city and 16 more than 12 outside (e.g. Lethariel s11: deck y 41.5
  beside a cut at y 38, r 146; Dur Brannoc s3: a primary road deck at y 70
  beside grade 64–65, 26 outside the wall). Cause: the road module joins
  roads of different levels (deck against cut or grade) with a step; the
  rougher ground round the smaller plateau makes that more frequent. Open as
  a D49 (½-node rule) follow-up for the road module, not fixed here. Variant 210/480 hit one required-plot failure (Kezamba,
  seed 2024), which shows the pinned-lake placement is layout-fragile, not
  plateau-size-bound. Engine (3 seeds, `grug_mapgen_terrain_audit` on):
  boots clean, protection answers right at 30/30 test points per seed
  (inside, wall, band, just beyond, far); across Highcourt's and Lethariel's
  edge 0 trees and 0 ground cover in the band, vegetation right beyond it
  (main: none within 30 of the old square's inside); terrain audit findings
  0/2/0 (main 0/0/1); main layout build +0.5–2 s; chunks in the ring round
  the city 430–480 ms instead of 330–355 (they now carry ordinary terrain and
  vegetation; ordinary chunks 1000 nodes out 350–490 ms in both trees); D77's
  steep rock now also shows on steep ground right beyond the band (it skips
  only protected columns); public protection calls near a capital ~1.6–1.7 µs
  instead of ~1.0–1.4 (fewer points short-circuit as protected; the lookup
  itself ~19 ns vs 3), elsewhere unchanged. The protection
  does not ride the IPC payload: both environments build it from the
  `capital_layout` text and the authored civic lakes. The two findings on seed
  8675309 are Lethariel plots with 1–2 flooded columns near the crown lake.
  Review follow-up: the edge reach is 9, not 6 (a gatehouse box is
  compass-aligned while its gate may slide ~34° along the wall, so a corner
  reaches ~8.7 beyond the wall line); the band is 12 beyond the outermost
  structure, 21 from the wall line. Over all 288 layouts the band beyond the
  nearest structure measures 10.8–17.5 (stone; ≥ 10.8 at gatehouses),
  12.7–18.5 (palisade), 13.7–20.5 (open; the top only where a civic lake
  reaches just past the outline, otherwise ≤ 19.1).
- **Start town surroundings (D78, after D76):** town layout and pad unchanged; smaller plateau; a 10–20-node protected, vegetation-free band around the pad with a
  noise-based material transition and a soft height transition; replaces the 148 square
  and larger bare envelopes. Before/after images on three seeds for the user.
- **D78 as built (lane `worktree-agent-a4fedc58f408c8429`, evidence and images
  in `~/projects/grudgelands-orchestration/r22/d78/`):** the flat, bare
  surroundings had three causes: the terrain field's start bowl (a warped
  circle calm to 70 from the anchor, faded out by 300, so damping stayed
  below 0.5 out to ~100 beyond the pad), the pad's 64-node square grading
  ramp (flat to ~30 beyond the pad, straight edges), and the claim
  exclusions — ground cover and gathering refused in the whole 256-node
  anchor-blend square, trees in the 148 square minus a jittered apron. Now:
  (1) the start town (`source/simple_map.lua` `hard_start_town_v1`: pad 128
  + band 12, true distance, rounded corners, index box 152) is both the hard
  core and the claim envelope (`simple_map.lua` kind `start_town`); the
  apron treeline code is gone; the zone authority's hard row asks the
  horizontal session (`start_protection_member`); `grug_mobs` spawn refusal
  uses the same rounded shape; zone-field keypoints 148 → 152 leave the zone
  field identical on all 24 test seeds (scale, bulges, bonuses, a 50-node
  owner/coast grid). (2) Grading: the flat pad grows by the old 0–6 noise
  offset, then a 24-node collar (`start_collar`, POI-collar noise, rounded
  corners) instead of the square ramp. (3) The bowl follows the pad: pad
  distance, unwarped, calm to 10, then a fade whose width follows the land:
  the 90th percentile of |natural − target| on square rings 30–90 beyond the
  pad over a grade of 0.3, within 60–200 (+ up to 40 % noisy edge); 75 of 144
  starts get the minimum, hilly ones up to 200 (a fixed small bowl gave
  rises of ~0.9 grade next to towns in hollows, variants B/C/D). (4) The
  band's surface: `height.lua` `start_ground_at` gives the town's pad ground
  (race palette `ground`, via `r7_runtime.lua`; Sunscar's
  `default:dirt_with_dry_grass` is not an R6 surface node, its mapgen twin
  `default:dry_dirt_with_dry_grass` has the same top texture) 2–10 nodes
  into the band along a 14-period noise outline with a 3-node dithered edge;
  the R6 surface selector lays it as the top (`planner_source.start_ground_at`).
  Offline, 24 seeds × 6 starts (before = main 8f467033): pad fittings all
  feasible (cut ≤ 4, fill ≤ 5, was 8/6), 0 wet pad columns; damping m ≥ 0.1
  at a median 30 beyond the pad (27–71; before 33, 1–69), m ≥ 0.5 at 50
  (45–133; before 100, 57–135); mean final slope 13–30 beyond the pad 0.09,
  31–45 0.15, 46–60 0.21, 61–80 0.24 (before 0.01–0.05, 0.10, 0.11, 0.13;
  natural 0.25–0.26), worst start ≤ 0.39 up to 80 nodes out, steep (D77 rock
  grade) ≤ 1 % of any ring; areas in a ±256 window per start: trees refused
  22.9 k m² (was 17.7), ground cover refused 23.1 k m² (was 65.5), protected
  22.9 k m² (was 21.9). Engine (3 seeds × 2 trees, terrain audit on): boots
  PASS, 0 ERROR; protection test points 78/78 per run (pad, band 6/11/12,
  beyond 13/20/40/300, band corners, territory + world_alterable + mob
  refusal); band 0 trees / 0 ground cover on six corner quadrants (was
  294–330 trees, 411–638 cover), vegetation right beyond it (13–42: 1446–1687
  trees, 1773–2371 cover); town ground on 98–100 % of band tops next to the
  pad, ~51–62 % at d 12; terrain audit findings 0/2/0 both trees; start NPC
  rosters place as before; start-corner chunks 422–537 ms per mapchunk
  (before 395–426: natural terrain and vegetation now), controls 217–290 in
  both; protection calls unchanged (territory_rule_at near starts 1.5–2.0 µs
  both). Open: a dry river trough (D57 `keep_trough`) beside Dawnmere on seed
  424242 keeps 3-node steps 1–20 nodes from the pad (84 such columns on
  main, 161 now with the shorter collar); the water lane's call.
- **Surface look and natural content, as built (lane p6-look, 2026-09-27;
  evidence and images in `~/projects/grudgelands-orchestration/r22/p6-look/`):**
  steep ground gets bare rock faces (grade 2.0–4.0 nodes per node, noise
  jittered, or a drop of 6–8; the "less rock" setting of D77), stone under the
  soil where a column stands 2+ above a neighbour, and gravel scree at the foot
  of rises; no strata on those faces (no dirt on cliff faces any more; on a
  representative sample of 28 random windows per seed, 14 % / 4 % of crag tops
  and 5 % / 0.5 % of meadow and forest tops change, gravel/snow mob host
  area −13 % / −5 %, stone golem hosts on crags +5 % / +3 %); beach sand has no
  gravel speckles (the Phase 3b "sparse gravel" rule, own commit); reefs grow
  in bays too, one cell in four, plus kelp meadows; every force-placed
  decoration cell (trunks, stems, roots; Luanti's force_place) may take the
  natural stone body below the soil, which lets the emergent jungle tree's sunk
  roots place (accepted 56 → 281 of ~850 candidates on six jungle boxes); the stone golem row above y 300 uses chance 12000 (bare
  crags offer ~1.3× the hosts per area); crab chances 300 / 1100 from the
  measured near-water share (~18 %); the crab `near_water` scan costs 2–3 µs
  and stays. Planner column values identical; roads, graded pads and capitals
  unchanged except sand for speckles near water; ores in steep natural columns
  relocate with their hosts. Chunk time about +7 % against main 9cf07071
  (pairs 1.065 and 1.074, noise pair 1.031; report).
  High relief has no native caves above y ~160 (v7 carves only its own low
  terrain; air share 1.2 % below y 40, 0.1 % at 80–160, 0 above 240): kept as
  is (D77 option A); own tunnels in the terrain fill are a possible later
  package.
- **Collected items open from the lanes (Phase 6):** two reverse river
  confluences (tributary lower than its parent, contained); the Dur Brannoc
  connector ford step (accepted; road-module bank-seal clamp with the city
  kit profile); free decks as last resort (mostly Stormvault, mountain
  trails); stale lighting-check targets `river_cross47`, `river_rapids`.
- **End-of-round check: full-world preparation** (`grug_prepare_full_world`,
  user, 2026-09-26). The preparation scheduler
  (`grug_core/starts_preload.lua`, `preparation_plan.lua`) takes its volume
  from the mapgen's surface authority (`wp40/preparation_source.lua`: tile
  boxes from the settlement blueprints (rotated plot boxes, collar and
  approach, city edge reach since the capital planner), column bounds from `column_values_at` ground, water, functional and
  upper/lower heights). Roads (decks, pillars, cut slopes) and the
  capital planner (rotated plots, walls, new outline) change what lies above
  and below the ground. A short headless run with the option on, not a full
  preparation: it starts, prepares a few tiles around a capital, a road deck
  and a bridge without errors, and those features lie inside the prepared
  bounds.
- Afterwards, the general runtime cleanup round (D4).

### Cleanup round (D4): collected items

Removal and simplification only where it is safe; output byte-identical
unless an item says otherwise; one independent review per lane. Collected
from the lanes and reviews of this round:
- **Dead code and data:** old `source/catalog.lua` route tables; dead planner
  bridge/ford/causeway/tunnel branches; dead `scratch.wet_surface` in
  `r6_planner.lua`; unused `canal_rows` in `r7_runtime.lua`; stale comments
  (e.g. river width in `grug_map/base.lua`).
- **Redundant work (D66):** the two redundant full-volume validity checks
  (`map_adapter.lua`, `r6_settlement.lua`, ~1 % of chunk time); make the
  main-start terrain audit (`settlement_terrain_findings`, ~3.7 s) switchable;
  emerge re-preparing all settlement blueprints (~3.5 s); noise code still
  38 % interpreted.
- **Capital planner:** y culling of the city edge and collar work (every
  vertically stacked chunk over a capital computes all columns today); the
  `BOUNDS.capital_overlay` table mixes anchor-relative x/z with absolute y
  (split it); log a dropped core pin.
- **Layout cache (D71):** a hit that passes all hashes but fails
  construction should fall back to a fresh build; an unreadable `.lua` in
  the key's tree aborts the load (warn and rebuild instead).
- **Mapgen correctness nits:** the settlement analytic mirror differs from
  the writer on sealed anchor-grade/POI-collar columns (write the top over
  opcodes 17/18 only where `analytic_p7_support_ref` is non-nil); crab
  `near_water` scan cost; B3 order-dependent 1-node air slivers (D65,
  deferred).
- **Later consumers:** the housing scan (101² exclusion queries near water)
  needs care when housing gets a consumer.
- **As built, lane B (redundant work + D71 fallbacks):** both per-voxel VM
  scalar checks removed (the R5 adapter only sees R6's shadow copies; the
  engine fills the whole volume with u16/u8 integers); the terrain audit runs
  only with `grug_mapgen_terrain_audit` (default off since roads and the
  capital planner are merged; lanes that change ground near settlements, e.g.
  D76, run with `grug_mapgen_terrain_audit = true` in their checks; on three
  seeds it found one plot, Lethariel `mere_mourning` on s1 with 1 submerged
  column, fall and rise within limits); main hands emerge its preparations of every lazy cell
  blueprint over IPC (`r7_settlement.handover`), emerge checks the handover
  against its roster and every lazy rebuild against main's identity and
  landmarks (a main/emerge divergence now stops generation at the blueprint's
  first touch instead of at emerge load); a D71 hit that fails construction
  and an unreadable mapgen source the runtime does not load both warn and
  build afresh. Engine digest equal on two seeds (111
  and 110 chunks incl. capitals, roads, bridges, water, a village); emerge
  construction ×0.52–0.59 (~7 → ~3.8 s), main loader ×0.89–0.93, chunk time
  within noise. Evidence `r22/cleanup-b/`.

### Orchestration and compaction points

The coordinator cuts the remaining work into packages that belong together
thematically and technically, runs independent lanes in parallel, and
compacts its context only at these points:

1. **After Phase 3b and the user's decisions on the stale-rule audit, before
   water starts.** Before compacting, this plan is brought up to date and a
   short handover note records branches, worktrees, agent results and open
   points that do not belong in the plan.
2. ~~Not between water and roads.~~ Superseded by D62: **after the user
   accepts water (Phase 5b), before roads (Phase 4)**, with the plan and
   handover brought up to date first.
3. Next candidate point: after roads, before Phase 6 and the capital
   planner (D60).

After the D62 compaction three packages start together: the Phase 4 road
prototype, the D63 performance analysis and the D64 chunk-edge analysis.

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

## 11. Capital planner package (D60): denser, more natural capitals

Recorded 2026-09-25 as a later goal; on 2026-09-26 turned into the capital
planner work package that follows water and roads (D57–D60).

- **When and how:** a one-time computation at server start, after height,
  water and roads, like the other layout steps. It knows where water and
  roads are.
- **Protected:** civic cores (no water, no changes) and the start towns
  (fixed layout, protected from water).
- **Reserved area:** each capital keeps a reserved maximum area; roads end at
  its edge (D59). Inside it the planner decides districts, houses, lanes,
  walls, the four cardinal gates and connector roads from each gate to the
  road end at the edge.
- **Gates and connector roads (user, 2026-09-26, on the road prototype):**
  roads may meet the reserved area anywhere on its edge, also near a
  corner. The planner places the gates freely but takes the incoming road
  ends into account, and it builds the last stretch from a road end to its
  gate with the **road module's own routing, profile and raster** (same
  grade rule, cross-section and look). So the road integration must expose
  routing between two arbitrary points as a reusable function, not only the
  one-time network build.
- **Water:** rivers and lakes may cross the reserved area (D57). Walls may
  run over rivers, lanes cross them by bridges. Canals follow D58 (one level
  per canal system, trough filled to the highest non-spilling level, raised
  rims allowed, no connection to world water; clear of natural rivers, or
  take their level at a crossing, sealed or interrupted against conflicting
  water).
- **Interim:** until this package, defects inside the reserved area are
  allowed (D31, D57); Highcourt's canal is a one-level interim (Phase 5b).
- **Civic water in the core:** the user allows the planner to rework
  Highcourt's civic water (canal on a dam, somewhat chaotic) even inside the
  otherwise protected civic core, if that is what it takes.
- **Known items for this package (found in Phase 5b):** Nhal Veyr's capital
  grading edge shows as a straight line (e.g. z = 1804 on seed 8675309 beside
  a lake; pre-existing); arcs of rivers around hard core keep-outs (the soft
  lens was tried and rejected, W3b); dry source gullies look straight in the
  flat capital bowls; plots and lanes in rivers inside the reserved areas.

- **Decisions on the audit and design (D69, 2026-09-26):** see
  `docs/research/round22-capital-planner-audit.md` and
  `docs/research/round22-capital-planner-design.md`; all 13 questions
  answered as recommended there.

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
