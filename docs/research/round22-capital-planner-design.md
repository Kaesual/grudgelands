# Round 22 capital planner: design draft (plan D60, §11)

Date: 2026-09-26. Status: **draft for the user's decisions.** Facts and
file references: [the audit](round22-capital-planner-audit.md). Nothing here
is decided until the user answers §9.

## 1. Goal

- Capitals become **denser and more natural** and **fit their landscape**:
  a smaller, non-rectangular city inside the reserved area, shaped by height,
  water and incoming roads.
- The **civic core stays as it is** (protected, dry, unchanged).
- **Start towns are untouched.**
- A one-time computation at server start in main, after height, water and
  roads, handed to emerge like the water and road layouts (D37).

## 2. Recommendation in short

**Option A, "kit placement on a planned street net":** keep the core and all
existing plot compositions; the planner computes, per seed, the city
outline, four cardinal gates, avenues and lanes as **polylines**, and places
the existing plots **rotated to face their lane**. Streets, lanes and
connectors are rasterized by the **road module** (one street system, D59).
Walls follow the outline as a new polyline raster. Denser first by packing
the same 52 plots into roughly half the area; extra infill houses only if
the user still finds it empty (stop point).

## 3. Mechanism options

All three share the frame: reserved area = today's 512 square (D59); the
core and its four core gates stay; plot ids named by consumers are always
placed (audit §2.2).

| | **A — Kit placement on a planned street net** (recommended) | **B — Growth grammar from the core** | **C — Hybrid: A plus parametric infill** |
|---|---|---|---|
| Idea | Outline → gates → avenues core-gate→city-gate → lanes branching off → pack existing plots along lanes, rotated to face them → fill pieces in the gaps | Streets grow from the core gates by rules (extend, branch, bend with the terrain), blocks between streets are split into lots, houses generated to fit each lot | A for structure; then the leftover street frontage gets small generated houses (race `cottage`/`shed`/`longhouse` generators already in `buildings.lua`) |
| Reuses | core, all 300+ plot compositions, sockets, NPC code, water rows, road module routing/profile/raster | core, palettes, part generators | everything A reuses + start-town building generators |
| New code (estimate) | planner module (~800–1200 lines), plot rotation at projection, polyline wall raster, payload | planner (~1500+), lot splitter, parametric house/interior/socket generator per race (large) | A + infill placer (~300) |
| Look | organic outline and streets; buildings are today's (already accepted) | potentially most natural and densest; houses new and unproven | A plus visibly denser street fronts |
| Risk | medium: rotation seam, polyline walls | high: new architecture per race, sockets/interiors, many playtest rounds | medium (A) + low (infill is scenery) |
| Complexity creep | bounded by the kit | open-ended (the "grammar" becomes the project) | bounded if infill stays scenery-only |
| Perf frame (estimate) | +1–2 s main per capital, +6–12 s start; chunk cost as today (cells + road sampler) | similar main cost; more cells | A + a few k cells |

**Why A:** the buildings, interiors, NPC work spots and services are the
expensive, accepted part; the layout around them is what the user dislikes.
A changes only the layout. B rebuilds what already works. C is A's natural
second step and a stop point, not a separate plan.

## 4. How option A works (steps in main, per capital)

1. **Sample once** a 2-node height/water/road grid of the reserved area
   (~65 k samples; estimate ≤ 1 s).
2. **Buildable mask:** dry, outside rivers/lakes plus a bank margin,
   slope under a limit, outside road corridors that already cross the area.
3. **Outline:** grow from the core over the buildable mask to a target area
   (rough guide §6), smoothed by noise, cut back by steep ground and large
   water. Rivers may lie inside the outline; they are crossed, not avoided.
4. **Gates (four, cardinal):** each gate sits on the outline where the
   cardinal ray from the core meets it, slid along the outline (within a
   bound, e.g. ±60) toward the road ends it serves (§5).
5. **Avenues:** core gate → city gate, routed on a fine grid (the road
   module's `routed` with a "street" kind) so they bend with the terrain and
   bridge rivers.
6. **Lanes:** branch off avenues at a rough pitch (~30–36), follow contours
   where possible, end in small squares or at the wall.
7. **Plots:** candidate positions along each lane at plot-depth setback;
   legality as today (dry, fall ≤ 6 under the skirt, rise ≤ clear) evaluated
   on the sampled grid with window min/max; each plot is **rotated so its
   entry faces its lane**; required plots first (inn, cook, eight service
   plots, stable; audit §2.2), then districts grouped by
   quarter (districts keep their identity, only their place varies), then
   fill pieces in the leftover space.
8. **Wall** along the outline (walled capitals), turrets every ~64, a
   gatehouse at each gate; open capitals keep a planted edge or thresholds.
9. **Connectors:** road end at the reserved edge → nearest suitable gate,
   road module routing and raster (§5).
10. **Canals (Highcourt only, D58):** optional, one level per system, from
    the planner's lane geometry; emitted as water rows in today's
    `water_authored` format.
11. **Output:** plot list `{id, x, z, turns, y}`, street/lane/connector
    polylines, wall polyline with gate positions, canal rows, outline — a
    text payload next to `water_layout`/`road_layout` (estimate 10–30 KB).

**Changes to existing code (estimate):**

| Piece | Change |
|---|---|
| `r7_settlement.lua` plot projection | accept `turns` (rotate cells, param2, sockets, landmarks at projection; identity stays the unrotated cells) and plot offsets from the payload |
| `wp40/r7_<capital>_blueprint.lua` | plots and overlay from the planner payload instead of lot tables |
| streets | city streets become road-module polylines of a "street"/"lane" kind with race paving and lamps; retires `avenue.lua`, `street_plan.lua`, `plot_approach.lua` for capitals |
| walls | new polyline wall raster (distance to polyline, walk level as a ≤ 1/column profile, turrets/gatehouses stamped as parts); retires the axis-run `wall.lua` for capitals |
| `height.lua` capital fitting | keep the flat core + damping; drop the square 512 terraces and square blend (audit §1.3) |
| lot tables, quadrant permutations | deleted |
| load order (audit §2.1b) | today blueprints and `plot_rects` exist before the height session and feed civic-water capping; the planner runs after height/water/roads, so: civic lakes no longer look at plots (the planner keeps plots off civic water instead), the planner's canal is added to the height session as a second step in main, and both environments build the capital sources from the payload |
| payload | new `capital_layout` field accepted by `r7_mapgen.lua` (like `road_layout`); manifest and preparation identity computed after the planner |

## 5. Gates, connectors, walls, water

- **Gates:** four, one per cardinal direction, facing it (gatehouse axis
  N/S/E/W). A gate that no road uses stays a gate (§9.2 design rule).
- **Road ends** (audit §6): 2–5 per capital, often near corners, sometimes
  two on one side. Assignment: each road end goes to the gate with the
  cheapest connector; a gate may take two connectors that merge before it
  (T junction as in the road network). No road is forced to a specific gate.
- **Connectors** run in the band between the city wall and the reserved edge
  (the city is smaller than the reserved area), with the road module's
  routing, profile (≤ ½ per column, slabs) and raster, so they look like the
  road they continue. The road module must expose point-to-point routing
  after the network build (today `routed` is internal to `build`, and the
  routing grid exists only in main — so connectors are built in main and
  shipped in the payload).
- **Walls may cross rivers:** over water the wall becomes a bridge-wall (an
  arcade of piers with the walk on top, water passing below); no water gate
  mechanics.
- **Bridges for lanes** come from the road module's deck/bridge system.
- **Rivers in the reserved area** stay natural; the planner treats their
  corridor (water + bank margin) as unbuildable and bridges it where an
  avenue or lane must cross. Plots never stand in water.
- **Canals (D58):** one water level per system, not connected to world
  water, clear of natural rivers (sealed or interrupted near them). Only
  Highcourt gets one; the user allowed reworking its core water if needed.
  Lethariel's lake and Kezamba's cenote stay as authored (they are in the
  core).

## 6. Size and density (rough guide values, D21)

| Quantity | Today (measured) | Proposal (rough target) |
|---|---|---|
| City footprint | 512 × 512 square (262 k m²) | organic outline of **~110–150 k m²** (≈ radius 190–220 from the anchor) |
| Built share (core + plots) | 10–12 % | **~20–30 %** |
| Plot pitch along a lane | 44 | ~30–36 |
| Buildings | 36 (+16 fill) | same 52 first; +10–20 infill cottages only if still empty (option C) |
| Reserved area | 512 (D59) | unchanged; the band outside the wall is countryside + connectors |

## 7. What varies per seed and how consumers follow

| Varies | Consumers | How they follow |
|---|---|---|
| Plot positions and rotation | NPC placement, patrol loops, profession vendors, trainers, public stations, stable/mount displays, map markers | automatically: sockets are computed from the plan at load and addressed by `plot/socket` id (audit §2.2) |
| Which plots exist | 6 inn plots (`grug_home/locations.lua`), 6 cook plots (`content_npcs.lua`), 8 service plots per capital (`capital_services.PLOTS`), the stable | **required plots are always placed** (a missing one is a load error); only other plots may be left out on cramped seeds (question 12) |
| Plot rotation | inn arrival = socket + 1 in **world +x** (`grug_home/init.lua:9`) | rotate the arrival offset with the plot (small change in `grug_home`, or publish the arrival as its own socket) |
| Canals, water under cross-river walls | planned-water flow exception of the water guard (`grug_core/water_guard.lua`) | report them as planned water in `column_values_at` |
| Whole layout | persisted NPC markers and entity positions (`start_npcs.lua`) | layout is a pure function of seed and code; identical on every boot of a world (a planner change inside an existing world orphans NPCs — acceptable in fresh-server mode) |
| Quest texts | `content_civic.lua` names district buildings (kept), "beyond its walls" for all six (already wrong for the open capitals) | fix the two open capitals' texts (question 13) |
| Design text | `world_zones.md` §12 "four fixed 32-node road gates" + gate table | rewrite when the planner is integrated |
| Outline, wall, gates | protection (532 square), guard level 60, exclusions | keep the square (recommended, U4): the reserved area stays protected; nothing else needs the outline |
| Streets, connectors | roads, map | map may draw them via `road_polylines()` (optional) |
| Canal | civic water rows | payload rows in the existing format |
| District placement | none outside the mapgen | districts keep their plot ids |
| Fixed | core, core gates, core sockets (king, royal guards, envoys, traders, gate-tower patrols) | unchanged |

## 8. Staging, risks and complexity budget

**Staging**
1. **Offline prototype, Highcourt first** (most issues: canal, rivers,
   stubs), on 3 seeds, using the road lane's harness and the real height,
   water and road layouts. Images: top-down city plan over relief (outline,
   wall, gates, streets, plots coloured by district, water), road ends and
   connectors; one isometric render of a street using
   `tools/wp13/render_blueprint.py`. Stats: plots placed, required plots all
   placed, plots in water (0), approach length per plot, built share,
   planner time.
2. User judges; then the other five capitals in the prototype.
3. **Integration only after roads are merged and playtested.**

**Stop points (in order):**
1. After the Highcourt prototype: if the outline/street net needs a second
   repair round for the same symptom → simplify (e.g. radial avenues +
   straight-ish lanes).
2. If polyline walls do not look right in one round → fall back to walls of
   long straight segments with turrets at the bends.
3. If connector routing inside the band fights the wall → gates snap to the
   nearest road end on each side, connector is a short straight stretch.
4. Infill houses (option C) only after the user sees A.

**Drop first if it grows:** canals (Highcourt keeps its interim canal),
infill, per-race wall variants beyond material, lane squares/plazas,
map drawing of streets.

**Risks**

| Risk | Mitigation |
|---|---|
| Plot rotation breaks param2/sockets/doors | reuse `parts.stamp` rotation; check sockets stay walkable (existing `finish` test) |
| Required plot finds no legal spot on steep/wet seeds | relax legality for required plots (terrace pad), log; never drop them |
| Road-module streets look too "rural" in town | race paving, kerbs and lamps as street materials; judged in images |
| Main start cost grows | reports only (D32); escalate if clearly slower |
| Emerge cost | unchanged order of magnitude: plot cells as today, streets via the road sampler (8–14 ms per crossed chunk) |

## 9. Questions for the user

1. **Mechanism:** option A (kit placement on a planned street net), with C
   (infill) as a later stop point? *Recommendation: yes.*
2. **Streets:** capital streets use the road module's profile (half steps
   with slabs, ≤ ½ per column) instead of today's one-node stair treads, so
   the city and its connectors are one system? *Recommendation: yes.*
3. **Walls:** walls follow the organic outline as polylines (diagonal
   masonry is slightly stepped), or long straight segments with turrets at
   the bends? *Recommendation: polylines, with the segment variant as the
   fallback.*
4. **Protection:** keep the 532 square as the protected area and guard-level
   zone (the band outside the wall stays protected countryside), or protect
   only the outline? *Recommendation: keep the square — protection, guard
   level 60, the 704 resource/claim exclusion and the zone self-check all
   stay unchanged; the city then must stay inside the square and its zone.*
5. **Size target:** city of roughly 110–150 k m² (about half today's
   envelope), built share 20–30 %? *Recommendation: yes, as a rough guide.*
6. **Districts:** keep four districts as recognisable groups (a quarter
   each, placed where the ground allows), or mix plots freely along streets?
   *Recommendation: keep groups; placement by the planner.*
7. **Gates with no road:** always four gates, even when only two roads
   arrive? *Recommendation: yes (design rule §9.2).*
8. **Highcourt canal:** rebuild it with the planner (one level, along
   lanes), or drop it and let the natural river be Highcourt's water?
   *Recommendation: rebuild, but drop first if it grows.*
9. **Open capitals (Lethariel, Kezamba):** keep them unwalled with a planted
   edge/thresholds on the new outline? *Recommendation: yes.*
10. **Countryside band** between wall and reserved edge: leave natural
    terrain, or add fields and pastures there? *Recommendation: natural
    first; fields are a later polish item.*
11. **Order:** Highcourt prototype first, the other five after its look is
    accepted, integration after roads are merged and playtested?
    *Recommendation: yes.*
12. **Cramped seeds:** may the planner leave out non-required plots (houses,
    fill pieces) when the ground has no room, instead of forcing them onto
    bad ground? Required plots (inn, cook, eight service plots, stable) are
    always placed. *Recommendation: yes, and log the count.*
13. **Quest texts:** "beyond its walls" is used for all six capitals,
    including the open Lethariel and Kezamba. Reword those two when the
    planner lands? *Recommendation: yes (text only).*
