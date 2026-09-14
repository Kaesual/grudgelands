# WP13 starts: round B of the user's playtest — the terrain half

Round A fixed three things inside the blueprints. Round B fixes three things
*around* them, all in the WP40 height/route/decoration layer; **no blueprint
file and no blueprint identity moved** (the KAT trio and the WP13 final micro
still digest `9b2466f08f84a246…`, the six per-start engine digests and the
combined `206a86a057b0b6ed…` are the ones round A recorded).

The previous record is `tools/wp13/evidence/20260914-round-a-blueprints/`.

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

`height.lua` rebuilds the surface geometry of that one leg: a straight
128-node run down the gate axis (64 of them outside the pad edge) at the gate
street's five-node width, then the ordinary bow from the first authored
centreline point outside the 256-node blend envelope onward. The gate side is
**derived** — it is the side the route's other station lies on, which is what
`main_street` and the authored gate stations both encode — and construction
fails if a start route's hub is not its anchor or its axis is not z.

Nothing was moved that is frozen: the route keeps its id, class, both stations
and both endpoint pins (run 1 is still the hub, at the start station's target
height), and the whole rebuilt stretch lies inside the anchor's own blend
envelope, which already excluded it. `make_path` gained an optional narrow
leading prefix; the three membership tests ask the segment width first and fall
back to the path width, while every bounding box and grid insertion keeps
reading the path's widest values as the upper bound they are.

**After**, both seeds, all six starts, every z row from 56 to 120 nodes out:
exactly five road columns at anchor.x−2 … anchor.x+2, no holes
(`measurements/gate_axis-*.tsv`). Inside the envelope the anchor fitting only
yields to a path's actual SURFACE, so those five columns are the road surface
and not its corridor.

Full route evidence (`tools/wp40/road_polish/measure.lua`, all 57 routes plus
spurs and island routes) moves **only the six start routes**
(`measurements/road_geometry-{before,after}.tsv`): the maximum step stays 1 and
the exact pin count stays 2 on every one of them; Hearthpine's observed cut and
fill are unchanged, Silverleaf's go from 3/63 to 7/67, Stillgrave's from 13/22
to 8/22, Sunscar's cut from 2 to 4, Dawnmere and Kapok keep theirs. No other
path in the world changed a single number.

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
| ring 74–127 | 43,416 | 43,416 | 1,144–4,470 | 690–3,930 | 41,607–42,203 |
| outside 128–160 | 38,016 | 1,045–5,599 | 550–5,088 | 37,360–37,444 | unchanged |

Band 128–160 loses 511 excluded columns per start, which is the one-node
negative edge of the half-open 256 square and not a rule change.

Measured in the engine, not inferred: `tools/wp13/engine_cases.lua` now
censuses real ground cover (a non-air, non-liquid node one above the surface)
per start in three bands, counting only columns the corpus actually emerged.
Identical on both seeds, both owner orders and both phases:

| start | apron 64–73 | ring 74–127 | wild 128–190 |
| --- | --- | --- | --- |
| Hearthpine | 0/588 | 101/1888 | not emerged |
| Dawnmere | 0/637 | 932/3999 | not emerged |
| Silverleaf | 0/588 | 100/1888 | not emerged |
| Stillgrave | 0/588 | 35/1676 | 1/212 |
| Sunscar | 0/637 | 814/3679 | 69/320 |
| Kapok | 0/588 | 100/1676 | 8/212 |

Where the corpus reaches past the envelope the ring's cover now matches the
untouched biome around it — Sunscar 22.1% against 21.6%, Kapok 6.0% against
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

Terrain height per column in a 281-node box around each start, before against
after (`measurements/pad_edge_height_delta.tsv`):

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
the pre-change run, so no start's fitted height moved. The whole route evidence
is byte-identical across this change, so no road moved either.

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
| `tools/bin/luac51 -p`, changed files | PASS, 7 files |
| `tools/bin/luac51 -p`, tree-wide | PASS, 443 files |
| SETGLOBAL, changed files | 0 on every one |
| Five plain-5.1 sweeps, changed files | zero hits |
| Five sweeps, `mods/*/grug_*` | only the three pre-existing `minetest.conf` comment mentions in `grug_core` |
| `tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `tools/wp40/r7/run.sh unit` | PASS (see the note below) |
| `library_kat` + `blueprint_kat` + `integration_fixture`, LuaJIT vs PUC 5.1 | byte-identical, `9b2466f08f84a246…` — the round-A digest |
| `quality_geometry_micro_kat`, LuaJIT vs PUC 5.1 | byte-identical, `7c35fa5d26d0a984…` (new `start_edge` row) |
| `tools/wp13/terrain_fixture.lua`, 5 seeds × 6 starts | PASS |
| `tools/wp13/final_micro.lua` pair | byte-identical, `9b2466f08f84a246…` |
| Engine gate, six starts, both seeds | all eight runs agree on `206a86a057b0b6ed…` |

`bash static.sh`, `bash kat.sh`, `bash final-micro.sh`, `bash engine.sh` and
`bash measure.sh <absent absolute dir>` reproduce all of it.

### Which frozen digests moved

| Digest | Before | After | Why |
| --- | --- | --- | --- |
| WP13 KAT trio / `final_micro.lua` | `9b2466f08f84a246…` | unchanged | no blueprint byte moved |
| Engine gate, combined and per start | `206a86a057b0b6ed…` | unchanged | the settlements are written where they were |
| `height.relief_lattice_digest` | `525620d5767fe976…` | unchanged | the natural terrain model is untouched |
| `height.base_lattice_digest` | `1a28c24004d5c0bd…` | unchanged | same |
| `height.canonical_kat_digest` | `9ae3a835a54596c9…` | `766d931d78dea52c…` | it covers the graded-route rasters and the visible-surface classification, and the six start routes' first legs were rebuilt |
| `quality_geometry_micro_kat` output | (round A bytes) | `7c35fa5d26d0a984…` | one new `start_edge` row exercising the pad-edge jitter arithmetic |
| route `exact_pin_digest` / `lower_bound_digest` | — | changed for exactly `route_001/004/007/010/013/016` | the six start routes; every other path's numbers are byte-identical |

Two construction metrics move with them: `construction_sha256_calls` 5,147 →
5,156 and `water_operation_count` 4,396 → 4,399, because the six rebuilt legs
pass slightly different water. `graded_path_count` (139), the relief profile,
octave and base-lattice populations are unchanged.
`measurements/height_digests-{before,after}-531802985935182545.tsv` and
`measure/height_digests.lua`.

### What could not run here, and why

- **`tools/wp40/r7/run.sh static`** cannot pass, for three reasons that all
  predate this lane: its `\bminetest\.` sweep hits the three `minetest.conf`
  comment mentions in `mods/CORE/grug_core`; the changed-production roster
  `tools/wp40/r7/changed_production_lua.txt` is missing round A's
  `mods/CORE/grug_core/starts_preload.lua`; and the two frozen expectations
  further down `source_audit.sh` (deleted-legacy 7 against 12, and the
  micro-KAT binding) are known stale. This round adds a fourth roster entry,
  `mods/MAPGEN/grug_mapgen/wp40/simple_map.lua`, so the derived population is
  now 144 against the frozen 142. The roster and the audit belong to the WP40
  lane and were deliberately left alone.
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
preload reported all six starts ready in each of them (12.6 s to the first,
37.9 s to 6/6 on the user seed's cold run). `pgrep -af 'luanti.bin --server'`
scoped to this run's output path was empty after each seed, and both scratch
directories were removed. The process table was NOT compared as a whole and no
`luanti.bin` was killed by name: the user runs a GUI client and another lane was
running its own headless server at the same time.

## Files

`measure/` holds the four offline measurement scripts, `measurements/` their
output (the 8 MB per-column height dumps are reproducible, not committed),
`user-seed/` and `boundary-seed/` the engine evidence, `final-micro/` the
frozen-byte pair, `static.txt` the static gates, `kat-*.txt`,
`geometry-*.txt` and `terrain-luajit.tsv` the fixtures.
`files.sha256` is the frozen-byte manifest, regenerated by `files.sha256.sh`.
