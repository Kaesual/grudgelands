# WP13 starts: round B of the user's playtest — the terrain half

Round A fixed three things inside the blueprints. Round B fixes three things
*around* them, all in the WP40 height/route/decoration layer; **no blueprint
file and no blueprint identity moved** (the WP13 fixture set digests
`758c3e8c5facc9eb…`, which is `main`'s own value at `6195555` after the visuals
and start-NPC lanes, and the six per-start engine digests and the combined
`206a86a057b0b6ed…` are the ones round A recorded).

The previous record is `tools/wp13/evidence/20260914-round-a-blueprints/`.
This round was independently reviewed at its first version; the review's
blocking finding (the approach outside its own claim exclusion) is what moved
the gate-axis geometry from `height.lua` into the compiled source, and both it
and the medium finding beside it are measured below from the rejected version as
well as from the fixed one.

## The three findings

### 1. The road arrived beside the gate, not at it

Every start blueprint opens a five-wide `main_street` on the z axis and puts
its `gate` at anchor.z ± 63, and the authored catalog agrees: it places that
start's `start_gate` station one node further out
(`mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua`, the six
`start:north`/`start:south` rows). The **compiled** route does not agree. Its
centreline begins at the zone hub, which IS the start anchor centre, and
`curved_route`'s first bowed leg pulls it off the axis immediately, so the road
crossed the build envelope diagonally and surfaced beside the gate. Measured at
the gate row (offset 64), road columns relative to the gate axis, identical on
both seeds because route geometry is seed-independent:

| start | before | after |
| --- | --- | --- |
| Hearthpine | −70 … −61 (10 wide) | −2 … +2 (5 wide) |
| Dawnmere | −7 … −1 (7 wide) | −2 … +2 (5 wide) |
| Silverleaf | +65 … +75 (11 wide) | −2 … +2 (5 wide) |
| Stillgrave | −72 … −63 (10 wide) | −2 … +2 (5 wide) |
| Sunscar | −67 … −58 (10 wide) | −2 … +2 (5 wide) |
| Kapok | +2 … +8 (7 wide) | −2 … +2 (5 wide) |

The gate-axis run is authored in the **compiled centreline**
(`source/simple_map.lua`, `START_GATE_ZONES`), not rebuilt in the height layer.
That is not a matter of taste. `exclude:route:<id>` — the claim exclusion that
makes `world.md` §2 R1's "ordinary roads remain claim-excluded" true — is
compiled from those same points, and so are `nearest_path_at`,
`path_corridor_member` and the planner's `route_or_water` reason. The first
version of this round rebuilt the leg inside `height.lua` instead, and the
independent review measured the consequence: **3,779 of 3,779 road columns on
Hearthpine's approach lay outside any claim exclusion** (Silverleaf 3,862 of
3,862, Stillgrave 3,798, Sunscar 3,702, Dawnmere 241, Kapok 261), because the
raster no longer followed the polyline the corridor was cut from. That is
reproduced in `measurements/road_protection-previous-head-*.tsv` and is zero
everywhere now.

A start route's first leg is therefore compiled as: the hub, the gate point at
anchor.z ± 128 (64 nodes outside the pad edge), **two eased vertices**, the leg's
**own second bow point unchanged**, and the authored crossing pin. The lateral
offset of the eased vertices follows smootherstep — exactly 17/81 and 64/81 at
t = 1/3 and 2/3, so it is integer arithmetic and not a float — while the axial
one stays linear, which is what makes an S instead of a re-spaced chord.

Keeping the leg's second bow point is the load-bearing part, and the review's
first version got it wrong: it REPLACED that point, and the point is the one
that decides the heading INTO the authored crossing pin. Turn at the pin, before
against the rejected version against now:

| route | authored | rejected version | now |
| --- | --- | --- | --- |
| `route_001` Hearthpine | 22.3° | 62.0° | **22.3°** |
| `route_004` Dawnmere | 67.9° | 64.7° | **67.9°** |
| `route_007` Silverleaf | 91.5° | 133.3° | **91.5°** |
| `route_010` Stillgrave | 96.5° | 136.1° | **96.5°** |
| `route_013` Sunscar | 101.1° | 138.3° | **101.1°** |
| `route_016` Kapok | 65.1° | 62.7° | **65.1°** |

Every pin turn is now byte-for-byte the authored one. Three of the six start
routes carry a 91–101° switchback at their crossing pin; that is pre-existing
authored geometry beyond the pin and this round leaves it exactly as it was,
which is why two of the numbers (Dawnmere, Kapok) are 3° *worse* than the
rejected version: matching the authored value is the rule, not beating it.

The turns this round introduces are all on the new leg-1 vertices, and none
exceeds 50° (`measurements/route_shape{,-before}.tsv`; the turn printed on a row
belongs to the vertex before it):

| route | gate point | ease 1 | ease 2 | kept bow | worst introduced | authored leg-1 turns |
| --- | --- | --- | --- | --- | --- | --- |
| `route_001` | 46.7° | 23.6° | 23.6° | 42.8° | 46.7° | 20.6°, 21.4° |
| `route_004` | 14.5° | 22.2° | 22.2° | 28.4° | 28.4° | 19.9°, 19.3° |
| `route_007` | 49.4° | 23.6° | 23.6° | 45.4° | 49.4° | 21.4°, 22.2° |
| `route_010` | 46.7° | 24.7° | 24.7° | 42.0° | 46.7° | 21.0°, 21.0° |
| `route_013` | 42.6° | 26.7° | 26.7° | 38.2° | 42.6° | 19.9°, 20.2° |
| `route_016` | 17.4° | 23.2° | 23.2° | 29.3° | 29.3° | 21.0°, 21.0° |

The trade is explicit: the authored bow turned ~20° per vertex because it never
had to break away from a straight run, and buying the on-axis approach costs up
to 49° at the gate point.

`pinned_point_index` moves from 4 to 6 on the six start routes, because the two
extra vertices sit in front of the pin. It is no longer a constant anywhere:
`curved_route` returns the index of its first leg's end, `source/simple_map.lua`
asserts that index is 6 for a start route and 4 otherwise AND that the point it
names is the authored crossing pin (checked for every route, which is how the
reviewer's "prove the pin position is unchanged" is proven), and
`simple_map.lua`'s validator derives the same 6-or-4 from the start anchors
instead of demanding 4.

The vertex count rises by two per start route — `route_001` 10 → 12, the other
five 7 → 9 — so the world's graded-segment population goes from 476 to
476 + 6 × 2 = **488**. That number is a frozen tripwire in
`wp40/zones.lua:800`, and it is updated in the same commit with the arithmetic
in a comment; without it the game does not boot at all. The graded-path
population is unchanged at 139: this round adds no path. See "Frozen
expectations this round moves" below for the one tool that still carries 476.

The gate side is **derived** — it is the side the route's other station lies on,
which is what `main_street` and the authored gate stations both encode — and
`source/simple_map.lua` asserts that the six gate-axis zones are exactly the
zones of the six start anchors, that each anchor sits on its zone hub (checked
against `anchor_rows` rather than trusted), and that the gate run does not
overshoot the bow point it eases into.

Nothing frozen moved: the route keeps its id, its class, both stations, both
endpoint pins (`centreline[1]` and `centreline[#centreline]` are still the two
station positions, which `simple_map.lua` validates), its class widths, its
`pinned_point_index` and its vertex count. `height.lua` only rasterises what the
source says; its `start_gate_prefix` verifies that the compiled centreline
really opens on the gate axis and reports the one thing the source cannot
express, namely that the first segment carries the gate street's five-node width
instead of the route class's seven. `make_path` gained an optional narrow
leading prefix; the three membership tests ask the segment width first and fall
back to the path width, while every bounding box and grid insertion keeps
reading the path's widest values as the upper bound they are.

**The compiled layout is load-bearing for the six start routes.** Those three
`fail()` paths in `start_gate_prefix` are the contract: a source edit that moved
a start hub off its anchor, took a start off its z axis, or dropped the axis run
stops construction instead of quietly putting the road beside the gate again.

**The 16-wide route exclusion moved with the road, and other rules ride on it.**
`exclude:route:<id>` is not only the claim rule: `r6_settlement.lua` reads the
same answer for resource sockets and cultural sites, and `housing_mask` points
are refused wherever `static_exclusion_values_at` answers. So the strip that is
now closed to claims, housing and cultural placement is the new corridor rather
than the old diagonal one, over roughly 250 nodes per start. Every one of those
consumers becomes MORE restrictive along the new road and less restrictive along
the old diagonal, which is the protective direction; the six starts' own 148-node
cores and their blend envelopes are unchanged, so nothing that was protected
stopped being protected. No separate measurement of housing eligibility was
taken.

Every road column within 400 nodes of every start is inside a compiled claim
exclusion, on both seeds, in all three bands — 0 unprotected of 663–4,296 road
columns per start per band (`measurements/road_protection-*.tsv`). Pristine main
measures 0 as well, so the invariant is restored rather than newly claimed.

**After**, both seeds, all six starts, every z row from 56 to 120 nodes out:
exactly five road columns at anchor.x−2 … anchor.x+2, no holes
(`measurements/gate_axis-*.tsv`). Inside the envelope the anchor fitting only
yields to a path's actual SURFACE, so those five columns are the road surface
and not its corridor.

Full route evidence (`tools/wp40/road_polish/measure.lua`, all 57 routes plus
spurs and island routes) moves **all six start routes and nothing else**
(`measurements/road_geometry-{before,after}.tsv`, before = `main` at `6195555`):
the maximum step stays 1 and the exact pin count stays 2 on every one of them,
and the observed cut and fill barely move.

| route | nodes | max cut | max fill |
| --- | --- | --- | --- |
| `route_001` | 611 -> 673 | 78 -> 77 | 38 -> 39 |
| `route_004` | 621 -> 621 | 8 -> 8 | 10 -> 10 |
| `route_007` | 611 -> 678 | 3 -> 2 | 63 -> 63 |
| `route_010` | 620 -> 683 | 13 -> 13 | 22 -> 20 |
| `route_013` | 622 -> 683 | 2 -> 2 | 1 -> 1 |
| `route_016` | 620 -> 620 | 4 -> 4 | 56 -> 56 |

The node counts rise because a straight run out of the gate followed by an S is
a longer road than a single bow. `route_004` and `route_016` keep every summary
metric and move only their water-bound digest -- **their centrelines moved like
the other four**; only these particular aggregates coincide, which is a property
of the metric and not of the geometry. No path outside these six changed a
number.

### 2. The blend ring was bare, and TWO gates said so

The 256-node blend ring carried no trees, plants or grass, so every start read
as a cut-out square. One compiled claim exclusion,
`exclude:anchor:anchor_00N:01`, covers the anchor's whole blend envelope, and
it was consulted twice:

- `r6_settlement.lua` rejects a decoration candidate on any excluded column;
- `r6_planner.lua` only grants a `land_grade` column a decoration host
  (`p7_support`) when it is `dry_start_grade`, and that test asked
  `not excluded` against the full claim rule. Since every dry start-grade
  column is inside that one exclusion, **the branch was unreachable** and the
  entire envelope had no host at all.

Narrowing only the first gate changed nothing, which is why the ring census
below exists: after that commit the engine still reported `0/1888` cover.

`static_exclusion_values_at` now takes a `purpose`. nil is the territory rule
and answers every compiled exclusion; `"vegetation"` **skips** exactly the six
start anchors' blend envelopes and lets the remaining shapes in the bucket
answer. Skipping and not short-circuiting is the whole point: the blend
envelope is the FIRST shape in its bucket, so returning early there would have
opened the pad as well. Because the others still answer, the start's own
148-node hard core (`exclude:active:hard:anchor_00N`), the road corridors,
planned water and the coast projection stay clear. Three call sites pass the
new purpose — the two decoration loops in `r6_settlement.lua` and the
`dry_start_grade` test in `r6_planner.lua`, there after the anchor-id match so
the extra query never runs outside those six envelopes. Resources, cultural
sites, the census and every claim consumer keep the full rule.

Columns per start by Chebyshev band, seed 531802985935182545
(`measurements/ring_bands-*.tsv`; `host_claim` is the old planner predicate,
`host_vegetation` the new one):

| band | columns | claim excl. | veg. excl. | host before | host after |
| --- | --- | --- | --- | --- | --- |
| pad 0–63 | 16,129 | 16,129 | 16,129 | 0 | 0 |
| apron 64–73 | 5,480 | 5,480 | 5,480 | 0 | 0 |
| ring 74–127 | 43,416 | 43,416 | 1,196–4,521 | 691–3,930 | 42,204–42,221 |
| outside 128–160 | 38,016 | 1,045–5,599 | 550–5,088 | 37,360–37,444 | unchanged |

Band 128–160 loses 511 excluded columns per start, which is the one-node
negative edge of the half-open 256 square and not a rule change. The boundary
seed gives the same counts to within a few columns
(`measurements/ring_bands-8675309.tsv`).

**The gate approach keeps a road's ordinary shoulder.** The review's F2 was the
other half of the same defect: with the approach missing from the compiled
centreline its corridor exclusion was missing too, so vegetation could host one
node off a five-wide carriageway. Measured as the smallest |dx| at which a
decoration may host, at z offsets 80/100/120 out of the gate
(`measurements/road_shoulder-*.tsv`):

| | approach, before | approach, after | ordinary stretch of the same route |
| --- | --- | --- | --- |
| all six starts | 3 | 9 | 9–23 (9 where nothing else excludes) |

Nine is exactly the ±8 clear corridor a primary route's 16-wide claim exclusion
gives, on both seeds, so the approach is now indistinguishable from the rest of
its own road.

Measured in the engine, not inferred: `tools/wp13/engine_cases.lua` now
censuses real ground cover (a non-air, non-liquid node one above the surface)
per start in three bands, counting only columns the corpus actually emerged.
Identical on both seeds, both owner orders and both phases:

| start | apron 64–73 | ring 74–127 | wild 128–190 |
| --- | --- | --- | --- |
| start | apron, user/boundary | ring, user/boundary | wild, user/boundary |
| --- | --- | --- | --- |
| Hearthpine | 0/588 · 0/588 | 96/1888 · 99/1888 | not emerged |
| Dawnmere | 0/637 · 0/637 | 935/3999 · 602/3999 | not emerged |
| Silverleaf | 0/588 · 0/588 | 98/1888 · 97/1888 | not emerged |
| Stillgrave | 0/588 · 0/588 | 35/1676 · 29/1676 | 1/212 · 2/212 |
| Sunscar | 0/637 · 0/637 | 823/3679 · 962/3679 | 69/320 · 83/320 |
| Kapok | 0/588 · 0/588 | 99/1676 · 105/1676 | 8/212 · 10/212 |

Where the corpus reaches past the envelope the ring's cover matches the
untouched biome around it — Sunscar 22.4% against 21.6%, Kapok 5.9% against
3.8%, Stillgrave 2.1% against 0.5% on a 212-column sample — and the protected
footprint is still bare. Before this round every ring number was `0/…`.

### 3. The pad edge was an exact square

A start pad is a half-open 128-node square, flat at the fitted reference
height, and the 64 nodes outside it smootherstep down to the natural terrain;
the inner edge of that ramp was an exact square. `height.lua` now pushes it
outward by 0..6 nodes from one seed-derived value-noise lattice per start
(period 24, smootherstepped, memoised on demand because a fitting's bucket cell
reaches further than its own envelope) and shrinks the ramp's span by the same
amount.

Outward-only and span-compensated is what keeps every invariant: a column
inside the 128 square still has excess 0 and therefore weight Q, and a column
at the outer envelope edge still has weight 0, so the 256 boundary stays
continuous and nothing escapes the fitting's bucket.

Terrain height per column in a 281-node box around each start, with the jitter
branch in `fitting_grade_at` disabled against enabled on otherwise identical
bytes — disabling exactly that branch is what makes this an A/B of the jitter
and not of the whole round (`measure/pad_edge_delta.sh`,
`measurements/pad_edge_height_delta.tsv`):

| band | columns | changed, user seed | changed, boundary seed | max delta |
| --- | --- | --- | --- | --- |
| pad 0–63 | 16,129 | 0 | 0 | 0 |
| apron 64–73 | 5,480 | 0 | 0 | 0 |
| ring 74–127 | 43,416 | 1,768–6,311 | 1,616–5,280 | 1–2 |
| outside 128–140 | 13,936 | 0 | 0 | 0 |

A repeat run on the same seed is byte-identical; the other seed gives a
different pattern. The start quality record now publishes the outline itself as
512 jitter offsets along the pad's four sides, and
`tools/wp13/terrain_fixture.lua` prints their range and digest per seed and per
start: observed minimum 0–2, maximum 4–6, and a different digest for every one
of its 5 × 6 rows (`terrain-luajit.tsv`). That fixture keeps every assertion it
had — spawn surface, flat 3 × 3 spawn pad, junction target and every graded road
endpoint exactly `reference_y` — and its first eleven columns are identical to
the pre-change run, so no start's fitted height moved.

**Honest limit of this fix.** The WP40 blend is gentle by construction — a
64-node smootherstep carrying at most eight nodes of cut or fill — so a 0..6
node jitter of the transition radius can only move the rendered contour by one
or two nodes, and the *flat* radius measured per ray was already irregular
before it (63 … 126 nodes, 27–41 distinct values per start,
`measurements/pad_edge-*.tsv`). After finding 2 the most visible square around
a start is the **treeline on the 148-node protection square**, which is a rule
from `world.md` §2 R1 and not a look. Softening that outline — suppressing
vegetation on a jittered band just outside the apron instead of on the apron
edge — is the next lever if the user still sees an edge, and it was left out of
this round on purpose rather than by oversight.

## Checks

| Gate | Result |
| --- | --- |
| `tools/bin/luac51 -p`, changed files | PASS, 8 files |
| `tools/bin/luac51 -p`, tree-wide | PASS, 462 files |
| SETGLOBAL, changed files | 0 on every one |
| Five plain-5.1 sweeps, changed files | zero hits |
| Five sweeps, `mods/*/grug_*` | only the three pre-existing `minetest.conf` comment mentions in `grug_core` |
| `tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `tools/wp40/r7/run.sh unit` | PASS (see the note below) |
| `library_kat` + `blueprint_kat` + `integration_fixture`, LuaJIT vs PUC 5.1 | byte-identical, `758c3e8c5facc9eb…` — main's own digest after the visuals and start-NPC lanes, unmoved by this round |
| `quality_geometry_micro_kat`, LuaJIT vs PUC 5.1 | byte-identical, `7c35fa5d26d0a984…` (new `start_edge` row) |
| `tools/wp13/terrain_fixture.lua`, 5 seeds × 6 starts | PASS |
| `tools/wp13/final_micro.lua` pair | byte-identical, `758c3e8c5facc9eb…` |
| Engine gate, six starts, both seeds | all eight runs agree on `206a86a057b0b6ed…` |
| Road claim protection, both seeds | 0 unprotected road columns on all six approaches |

`bash static.sh`, `bash kat.sh`, `bash final-micro.sh`, `bash engine.sh` and
`bash measure.sh <absent absolute dir>` reproduce all of it.

### Which frozen digests moved

Before means `main` at `6195555`, measured on the same immutable tree the
route evidence was taken against.

| Digest | Before | After | Why |
| --- | --- | --- | --- |
| WP13 KAT trio / `final_micro.lua` | `758c3e8c5facc9eb…` | unchanged | this round touches no blueprint, no `wp13/` library file and no `r7_*` file |
| Engine gate, combined and per start | `206a86a057b0b6ed…` | unchanged | the settlements are written where they were |
| `height.relief_lattice_digest` | `525620d5767fe976…` | unchanged | the natural terrain model is untouched |
| `height.base_lattice_digest` | `1a28c24004d5c0bd…` | unchanged | same |
| `height.canonical_kat_digest` | `9ae3a835a54596c9…` | `2dae886258b2f466…` | it covers the graded-route rasters and the visible-surface classification, and the six start routes' first legs are compiled differently |
| `quality_geometry_micro_kat` output | (pre-round bytes) | `7c35fa5d26d0a984…` | one new `start_edge` row exercising the pad-edge jitter arithmetic |
| route `nodes` / `exact_pin_digest` / `lower_bound_digest` | — | changed for all six start routes | every other path in the world is byte-identical |
| `source.routes[i].centreline` for the six start routes | — | two vertices inserted (10 → 12, 7 → 9) | the gate-axis run and the two eased vertices; ids, classes, stations, endpoint pins, widths and the crossing-pin POSITION are unchanged |
| `source.routes[i].pinned_point_index` for the six start routes | 4 | 6 | the same point, two vertices further along; derived from the curve now and asserted to name the authored crossing pin |
| graded segment population (`wp40/zones.lua:800`) | 476 | 488 | 6 start routes x 2 inserted vertices; the graded PATH population stays 139 |

Two construction metrics move with them: `construction_sha256_calls` 5,147 →
5,154 and `water_operation_count` 4,396 → 4,397, because the six legs pass
slightly different water. `graded_path_count` (139), the relief profile, octave
and base-lattice populations are unchanged.
`measurements/height_digests-{before,after}-531802985935182545.tsv` and
`measure/height_digests.lua`.

### Frozen expectations this round moves

- **`mods/MAPGEN/grug_mapgen/wp40/zones.lua:800`**, the graded path/segment
  tripwire, 476 → 488. Updated here with the arithmetic in a comment, because
  the two inserted vertices per start route are exactly 12 more segments and the
  game refuses to load otherwise (`ModError: WP40 R4: graded path/segment
  population differs`, caught by the engine pass before this was fixed).
- **`tools/wp40/simple_map_r4_validate.lua`** carries the same 476 in three
  places (lines 478, 804 and 832, the last one inside the R4 construction
  receipt). That is historical R4 evidence, not a current gate — it is not run by
  `tools/wp40/r7/run.sh` and rewriting a receipt is not this lane's call — so it
  is **left at 476 and will fail against this source** until the WP40 lane
  resyncs it, in the same way as the changed-production roster. Flagged rather
  than edited.

### What could not run here, and why

- **`tools/wp40/r7/run.sh static`** cannot pass, for reasons that all predate
  this lane: its `\bminetest\.` sweep hits the three `minetest.conf` comment
  mentions in `mods/CORE/grug_core`; the changed-production roster
  `tools/wp40/r7/changed_production_lua.txt` still has 142 rows while the
  derived population on `main` is 151 (round A's `starts_preload.lua`, plus the
  visuals and start-NPC lanes' nine files); and the two frozen expectations
  further down `source_audit.sh` (deleted-legacy 7 against 12, and the micro-KAT
  binding) are known stale. This round adds exactly one row of its own,
  `mods/MAPGEN/grug_mapgen/wp40/simple_map.lua`, for 152. The roster and the
  audit are WP40-lane state and the coordinator resyncs them in one commit after
  the wave, so they were deliberately left alone here.
- **`tools/wp40/r7/run.sh unit`** failed on `main` before this lane started:
  `anchor_activation_kat.lua` still handed the successor a single settlement
  config instead of the roster list the fourth WP13 increment introduced. That
  one call is repaired here, because every mode of `run.sh` runs `run_unit`
  first and nothing could be verified otherwise.
- **`tools/wp40/quality/final_micro.sh`** and the **R7 integration KAT**
  (`adapter_cli.lua integration-kat`, and with it `run.sh integration|freeze|
  pilot|fleet`) both need the `reference_projects/luanti` submodule — the first
  for its input manifest, the second because `tools/wp40/r6/fixtures.lua` reads
  `doc/lua_api.md`. An agent worktree deliberately does not initialise
  submodules: they share `.git/modules` with the user's own checkout, and moving
  a pinned commit as a side effect is forbidden. The
  `quality_geometry_micro_kat` component — the one that covers this round's new
  arithmetic — was run under both interpreters directly and is in the table
  above; the engine gate is the broader integration evidence that did run.

## Engine gate

One gate, six starts, two seeds, sequential, headless Luanti 5.17.0 through the
isolated Flatpak launcher. Each seed is a full `run_engine.sh` pass: forward and
reverse owner order, each with its own cold world and its own disk-only reload.

**All eight runs agree on one digest:**
`206a86a057b0b6ed4cb5ee71df67413e0f40b70f0b486ea3947bbbbb99eac9a6` — the digest
round A recorded, which is the contract this round is held to.

| Start | Authored cells | Torches lit | Per-start digest | Fitted y, user seed | Fitted y, boundary seed |
| --- | --- | --- | --- | --- | --- |
| Hearthpine | 61,932 | 74 | `03311c95b8463c42…` | 25 | 16 |
| Dawnmere | 66,361 | 98 | `19f8c63f3de9dfe0…` | 17 | 21 |
| Silverleaf | 71,495 | 113 | `a81a370a26a293f6…` | 21 | 42 |
| Stillgrave | 51,641 | 78 | `13f3cff1f580eb6d…` | 54 | 48 |
| Sunscar | 57,227 | 112 | `de46c91105d36125…` | 27 | 46 |
| Kapok | 72,535 | 87 | `e11c30ec9e88b7ce…` | 20 | 17 |

Every per-start digest and every fitted y is the one round A recorded. No
`ERROR` and no `ModError` in any of the eight server logs, and the startup
preload reported all six starts ready in each of them (44.0–48.5 s cold,
8.8–9.2 s from disk). `pgrep -af 'luanti.bin --server'` scoped to this run's
output path was empty after each seed, and both scratch directories were
removed. The process table was NOT compared as a whole and no `luanti.bin` was
killed by name: the user runs a GUI client and another lane was running its own
headless server at the same time.

## Files

`measure/` holds the nine offline measurement scripts, `measurements/` their
output (the 8 MB per-column height dumps are reproducible, not committed),
`user-seed/` and `boundary-seed/` the engine evidence, `final-micro/` the
frozen-byte pair, `static.txt` the static gates, `kat-*.txt`,
`geometry-*.txt` and `terrain-luajit.tsv` the fixtures.
`files.sha256` is the frozen-byte manifest, regenerated by `files.sha256.sh`.

Before/after measurements were taken against immutable copies of two trees:
`main` at `6195555` for everything called "before", and this round's own bytes
with only the pad-edge jitter branch disabled for the pad-edge A/B. The
`road_protection-previous-head` and `road_shoulder-previous-head` receipts were
taken against this branch's first (rejected) version, to reproduce the review's
F1 and F2 measurements before fixing them.
