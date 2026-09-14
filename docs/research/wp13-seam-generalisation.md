# WP13: the settlement seam generalisation, and Highcourt in the world

Increment record, 2026-09-15, rebased onto and re-measured against `main` at
`0f6a80f` (the round-B terrain merge). Implements section 2.2 of
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) and binds the
pilot capital of [wp13-highcourt.md](wp13-highcourt.md) into the WP40 R7 seam,
including the hand-off list of that document's section 7. Evidence:
`tools/wp13/evidence/20260915-seam-generalisation/`.

Contracts implemented: the capitals contract (2.2 the seam, 2.1 what a capital
is, 2.3 the budgets, 4 the user's rulings on the king's hall, the sockets and
the three walled races) and
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md) (capitals register
under their own key; the two fixed vendor offsets migrate when the first core
lands).

## 1. What shipped

| File | Change |
| --- | --- |
| `wp40/r7_settlement.lua` | rewritten: bounds and slot per profile, several blueprints per settlement in three kinds, lazy build/release, the socket export, the reserved anchor root, the avenue overlay's per-mapchunk assembly and its cross-run arbitration |
| `wp40/r7_highcourt_blueprint.lua` | **new**: the capital source -- the core's builder, the nine plot builders with their offsets, and the avenue overlay's runs and function |
| `wp40/r7_manifest.lua` | the field order and the settlement order are derived from the roster, one identity block per blueprint |
| `wp40/r7_successor.lua` | the settlement list is checked against the roster's keys in the roster's order |
| `wp40/r7_runtime.lua` | prepares every settlement once at load, builds the derived manifest order, publishes the planner source and the socket rows |
| `wp40/r7_loader.lua` | registers the starts' sockets first and every capital's after them |
| `wp13/avenue.lua` | **added** `M.palette_names(palette)`: every node name a run may write, which is what an overlay's identity and the shared content channel are closed over |
| `wp13/highcourt_district.lua` | two plot POSITIONS moved, on measured evidence (section 4) |
| `grug_mobs/start_npcs.lua` | serves every registered settlement, not only the six starts: a capital's readiness, one guard per patrol LOOP, idle spots grouped per composition, markers keyed by settlement |
| `grug_traders/vendors.lua` | capital vendors are socket-driven where a core has landed and offset-driven where none has |
| `tools/wp13/seam_kat.lua` | **new**: acceptance for the whole of contract section 2.2 |
| `tools/wp13/highcourt_probe/` | **new**: the disposable headless probe (surface, scan and full modes) |
| `tools/wp13/run_highcourt.sh` | **new**: the Highcourt engine pass, world kept so the probe's dumps survive |
| `tools/wp13/integration_fixture.lua` | drives all three blueprint kinds over the real owner grid |
| `tools/wp13/library_kat.lua`, `engine_cases.lua` | scoped to the roster's STARTS, which is what they are about |
| `tools/wp13/start_npcs_kat.lua` | a sixth state: a capital, its two loops and its separate markers |
| `tools/wp13/highcourt_timing.lua`, `final_micro.lua` | the seam's own two costs; the new KAT joins the interpreter pair |
| `tools/wp40/r7/micro_kat_fixture.lua` | one stub line: the trader environment now sees `register_on_mods_loaded` |

Not touched: the six start compositions, `capitals.lua`, `highcourt.lua`, and
every other file of the building library.

## 2. The seam, as implemented

### 2.1 A profile carries its slot and its bounds

`M.BOUNDS` holds the three authorized volumes of the contract -- `start`
(±63, y −2..24), `capital_core` (±47, y −2..40) and `capital_plot` (±15,
y −6..24) -- and a roster row names the one its primary blueprint is held to
plus, for a capital, the one its plots are held to. The literal that used to be
typed in three places is gone from all three: the bounds check and the per-cell
range read the descriptor's own entry, and the manifest's identity row reads the
bounds the roster handed it.

A row also carries `slot`, which is the anchor slot the zone session resolves
(`"start"` or `"capital"`), so the successor no longer asks for `"start"`.

### 2.2 A settlement may own several blueprints, of three kinds

`M.descriptors(profile, source)` turns whatever the profile's blueprint file
returned into an ordered list. A start's file returns a blueprint and gets one
descriptor; a capital's file returns a **capital source**
(`grug_wp13_capital_source_v1`) and gets one per plot plus the core plus the
overlay. Each descriptor carries its kind, its bounds, its schema strings and
its manifest field prefix. An identity schema is derived from the blueprint's
own schema (`…_v1` → `…_identity_v1`), which is what keeps Hearthpine's
`grug_wp13_hearthpine_blueprint_identity_v1` exactly where it was.

The three kinds and what each means at settle time:

- **`anchor`** -- anchor-relative, exactly like a start. Local y = 0 lands on
  the fitted anchor. The capital core is one of these, and the same
  support/clearance rule the anchor writer asserts is checked on it.
- **`reference`** -- terrain-relative. The descriptor carries the plot's offset
  from the capital anchor and the composition carries its own reference column;
  the successor asks the **pure final height** of that one column ONCE per
  session, caches it, and projects every cell of the plot from it. The query is
  `planner_source.column_values_at(x, z)`, the same function
  `r7_anchor_roster.lua` authenticates every anchor's fitted height through.
- **`overlay`** -- no cells at all until a surface is handed to it. The avenues
  are `avenue.run(palette, spec, surface)` evaluated per mapchunk. An overlay's
  IDENTITY is therefore its **specification**: the runs in authored order, the
  carriageway width, the lamp rhythm, the look-around and the exact byte-sorted
  set of node names a run may write. That set is the new
  `avenue.palette_names`, and the seam refuses a cell whose name is outside it.

### 2.3 The manifest and the successor are derived from the roster

`r7_manifest.lua` is constructed with a settlement order built from the roster
in roster order, one row per settlement carrying its blueprints in blueprint
order. The field order is the fixed head, then the ten fields every blueprint
publishes under its own prefix, then the fixed tail. A start keeps its own
prefix, so `hearthpine_blueprint_sha256` is still spelled exactly that; Highcourt
publishes `highcourt_core_*`, `highcourt_market_granary_*` … and
`highcourt_avenue_*`. The manifest refuses an empty order, a settlement with no
blueprint and two settlements sharing a prefix.

The successor is handed the roster's keys and refuses a settlement list that is
not exactly those, in that order. The old check was `if not keys.hearthpine`.

### 2.4 Lazy construction, and what is not lazy

Identity is not lazy. The manifest is a closed document, so `M.prepare` builds
every blueprint once at load, validates it, writes its canonical identity bytes,
hashes them, and then **releases the cells** of a profile marked `lazy`. What it
keeps is the identity, the palette (the shared content channel is closed over
it) and the landmarks (the NPC sockets are in them). What lazy construction
hides is the 100,000-cell buffer, not the digest.

At run time a blueprint's cells are built on the first `bind_plan` whose
mapchunk touches its envelope, and released again after `IDLE_RELEASE` = 64
consecutive plans have touched nothing of it. A lazy rebuild is hashed again and
compared with the published identity, so a composition that is not a pure
function of its own source fails loudly instead of silently building a different
capital. Starts stay eager.

The duplicate-cell check uses a **packed integer key** (`((x+1024)*2048 +
(y+1024))*2048 + (z+1024)`, exact in a double because every bound is validated
inside ±1023) instead of one string per cell; the avenue's ground memo and the
per-settle overlay set use the world-space equivalent.

### 2.5 Two things only the successor can do

`avenue.run` is a pure function of ONE run and knows nothing of the road it
crosses, but a capital's four avenues and its four ring-street sides meet at
four corners. The successor therefore arbitrates, with two rules that are pure
functions of the run rectangles and are the same in every mapchunk, so a piece
of a run is still exactly that stretch of the whole:

1. **The first run wins a shared cell.** The runs are authored avenues first,
   ring street second, so the great road runs through and the side street yields
   at the kerb.
2. **No lamp standard in another road's carriageway.** A lamp stands on the
   verge, one node outside its own carriageway, and at a crossing that verge is
   the middle of the other road: Highcourt's lamp rhythm puts one pair exactly
   on each ring crossing. The three cells of such a standard are dropped.

### 2.6 The walkable surface, and the river

The contract says "pavement at surface". The first engine pass of this package
read that as the GROUND surface and paved a trench along a river bed: Highcourt
is the contract's own "river plateau" capital and WP40 leaves that river inside
the 512 envelope, so between local x 128 and x 210 the east avenue ran nine
nodes below the core with the water one node above it. A road is walked on the
surface a traveller stands on, so the successor hands `avenue.lua`
`max(terrain_y, water_y)` -- and because the settlement writer overwrites, the
result is a solid causeway and not paving floating on water. `avenue.lua` itself
is unchanged: it still queries no height of its own and still knows nothing
about water. `renders/avenue-east.png` is the road as built.

### 2.7 Sockets

`M.sockets(prepared, anchor, height_at)` returns a settlement's sockets ready
for `grug_core.register_settlement_sockets`. A plot's sockets are plot-relative
AND terrain-relative, so both corrections happen there and nowhere else: the
plot's offset from the anchor, and its reference height minus the anchor's. A
socket id is unique only within its own composition, so a plot's ids are
prefixed with the plot id and a slash. Highcourt publishes **95** sockets: one
king, two vendors, one waypoint, one quest, 13 guard posts, 28 patrol waypoints
in **six** loops and 49 idle spots.

## 3. The guard banner: the anchor root is reserved

The anchor writer puts one `grug_nodes:guard_banner` at (x, y + 1, z) of every
capital anchor, and it runs BEFORE the settlement writer. Highcourt's core has
`air` at exactly that cell -- it is `arrival`, the crossing of the two great
avenues -- so the settlement writer would have overwritten the banner with that
air and the capital watch of `camps.lua` would have had no node and no node
timer.

**Decision: the banner stays where it is, and the core's settle SKIPS that one
cell** (`reserve_anchor_root` in the roster profile). Three reasons, in order:

1. Nothing of the city is lost. The composition's cell there is air, and the
   writer still paves the anchor's own support at (x, y, z), so the banner
   stands on the citadel pavement of the crossing.
2. Nothing is blocked. `grug_nodes:guard_banner` is `walkable = false` by
   construction ("the post is a landmark, never an obstacle its own guards can
   get stuck on"), so a five-wide gate road crossing is still five wide.
3. Nothing else moves. The anchor roster, its digest, the 42-anchor population
   and every piece of WP40 evidence recorded against them are untouched, and the
   capital watch keeps the node its LBM and node timer hang off.

The alternative -- teaching the anchor writer a per-capital offset -- would have
made the anchor roster depend on the WP13 compositions, which is the wrong
direction for a seam whose whole point is that the roster is authenticated
independently.

## 4. The surface under every plot, measured on both gate seeds

The Highcourt hand-off (`wp13-highcourt.md` section 7, finding M2) expected the
32-node core-to-terrace blend band to be the problem and named four plots on it.
**The measurement refutes that and finds two different plots.** The probe samples
`grug_zones.terrain_height_at` -- the same pure final height the writer projects
with -- over every column of every plot footprint, and reports the fall under the
PERIMETER, because the perimeter is what the foundation skirt carries down and
the skirt reaches 6.

Before the move (`surface/surface-*-before-move.tsv`), perimeter fall:

| Plot | at | seed 531802985935182545 | seed 8675309 |
| --- | --- | --- | --- |
| market_granary | (72, −28) | 4 | 0 |
| market_stable | (72, 28) | 1 | 2 |
| market_workshop | (116, −28) | 2 | 2 |
| market_counting_house | (116, 28) | 1 | 1 |
| **market_well** | (152, −28) | **7** | 3 |
| market_watch | (152, 31) | 1 | 1 |
| market_grove | (76, −64) | 0 | 0 |
| **market_orchard** | (76, 64) | 5 | **8** |
| market_store | (116, −64) | 2 | 2 |

Two plots exceed the skirt, one on each seed, and the four blend-band plots are
not the ones that do: `market_well` at x = 152 is the district's widest plot (a
23 × 23 garden footprint) and catches a terrace joint, and `market_orchard` is
the one blend-band plot that does fall through, on the seed the other document
did not have.

**Moved**, after sweeping every legal position on a 4-node grid over the whole
quadrant on BOTH seeds and intersecting the results (legality = inside the
envelope, clear of the core, clear of all four 32-node gate corridors, off all
eight street runs, one node clear of every other plot):

- `market_well` (152, −28) → **(192, −28)**: stays on the east avenue's own
  line with the granary and the workshop, further out. Perimeter fall 0 on both
  seeds.
- `market_orchard` (76, 64) → **(112, 64)**: stays on the ring street's z = 64
  line beside `market_store`. Perimeter fall 0 on both seeds.

After the move (`surface/surface-user-seed.tsv`,
`surface/surface-boundary-seed.tsv`) the worst perimeter fall of the whole
district is **4** on the user seed and **2** on the boundary seed, against a
skirt of 6.

One thing measured and NOT fixed: `market_counting_house` sees the surface RISE
12 nodes above its reference column on the user seed, against an airspace clear
that reaches 13. It is covered, by one node. It is recorded in section 9.

## 5. Measurements

### 5.1 Build time, both interpreters

`timing.sh` / `timing.txt`, three runs each, `os.clock` CPU milliseconds:

| Subject | LuaJIT | PUC 5.1 |
| --- | --- | --- |
| module load | 12.6 – 12.8 ms | 17.1 – 17.4 ms |
| core (101 831 cells) | 111.7 – 112.6 ms | 346.9 – 359.7 ms |
| district, nine plots (57 761 cells) | 50.5 – 52.2 ms | 150.6 – 154.9 ms |
| one 209-node avenue run (1 237 cells) | 2.9 – 3.1 ms | 2.3 – 2.3 ms |
| **seam prepare** (all 11 blueprints built, hashed, released) | 286.7 – 309.9 ms | 904.4 – 925.2 ms |
| **seam first touch** (core rebuilt, hashed, compared, 101 830 cells written) | 238.6 ms | 626.6 ms |

The engine's own LuaJIT agrees: the probe timed the core at 137.6 – 164.3 ms
across boots and the nine plots at 3.3 – 10.6 ms each.

Against the contract's section 2.3 budget: core **101 831 of 150 000** cells,
largest plot **9 274 of 12 000**, whole capital including the overlay **168 758
of 400 000** written cells. "Builds in a few seconds under LuaJIT when first
touched" is 0.24 s, and 0.63 s under the fallback interpreter.

### 5.2 Per-mapchunk cost

`highcourt/probe.txt`, one boot, seed 531802985935182545. The corpus is the 33
mapchunks the capital's blueprints and avenues actually touch, derived from the
real geometry, plus three kinds of control:

| Kind | chunks | first | steady mean | worst | best |
| --- | --- | --- | --- | --- | --- |
| warm-up (open land, not counted) | 1 | 21.96 s | -- | -- | -- |
| **Highcourt** | 33 | 0.99 s | **0.452 s** | 0.99 s | 0.10 s |
| Lethariel (a capital with no WP13 cells) | 8 | 11.69 s | 2.30 s | 13.92 s | 0.19 s |
| open land / the Dawnmere start | 3 | 0.73 s | 0.42 s | 0.85 s | 0.003 s |

The warm-up mapchunk carries the emerge environment's whole one-time R7
construction -- the content channel, the R6 session and this package's identity
pass over every settlement -- which is why it is emerged first and not counted:
charging it to whichever mapchunk happened to be first is what made the first
version of this measurement read 18.4 s for a core chunk.

Lethariel is the honest control: WP40 fits, flattens, terraces and protects it
exactly like Highcourt and it has no WP13 blueprints at all. Highcourt's
mapchunks are **cheaper** than that control's, so the capital settlement's own
contribution is inside the noise of the terrain work around it.

Against the contract's "no more than 2× the ~0.5 s Dawnmere chunk": the steady
mean is **0.452 s** and the worst single mapchunk 0.99 s, which is under 2× the
nominal 0.5 s. The worst is the FIRST Highcourt mapchunk, which is where the
capital's own lazy construction lands; every later one is under 0.9 s. The per-chunk height cost is bounded by the avenue ground memo: a
run's profile is read once per session and shared by every mapchunk that clips
it, so the stacked mapchunks over one avenue do not re-read it once each.

### 5.3 Cross-run arbitration

Counted in the successor's metrics and asserted by `seam_kat.lua` on the
mapchunk that holds a real crossing: the four crossings cost 16 dropped lamp
standards and 100 cells claimed by two runs at once over the KAT's owner set.

## 6. Verification

### (a) The KATs, both interpreters

`tools/wp13/seam_kat.lua` is the new acceptance for contract section 2.2: the
three bounds entries and the start's still being the replaced literal; a
blueprint one node outside its envelope refused and the same cells accepted
under the capital core's wider entry; the roster's slots; eleven blueprints with
eleven distinct identity SHAs, in the order core / nine plots / overlay, each
inside its own envelope and all cell-less because the settlement is lazy; the
sockets, unique after prefixing, and refused without a height query; the
manifest order derived and its three refusals; the reserved anchor root kept and
the anchor's support written; a plot projected from its reference column at a
height that is deliberately not the anchor's; the reference height asked once
per session; release after `IDLE_RELEASE` misses and rebuild on the next touch;
a drifting composition refused; the overlay's two pieces equal to the whole run
cell for cell and every name inside the overlay palette; the cross-run
arbitration; and the successor's roster check.

`integration_fixture.lua` drives all three kinds over the real owner grid: every
expected cell written exactly once, by the owner that contains it, with the
overlay's expectation recomputed from the whole runs.

`start_npcs_kat.lua` gained a sixth state: a capital is not placed before its
area is emerged, is placed in full on one pass with no player near once it is,
carries one guard per patrol loop with each guard walking only its own loop's
waypoints, gives a district villager only its own plot's idle spots, and keeps
markers separate from the start of the same race. **That state found a real
defect in this package**: `socket_occupied` still compared the race where
`install` now writes the settlement key, which freed every marker and spawned a
twin on every heartbeat. Fixed, with the reason in the comment.

`final-micro.sh`: one LuaJIT process and one PUC 5.1 process over the frozen
inputs, hashed before and after, running every WP13 fixture:

```
WP13 FINAL MICRO PAIR BYTE-IDENTICAL
c4a93a7d5ec0f65ae59dd22cbf5eaabd873ef0f7f107398d52917fcf9d0ac394  micro-luajit.tsv
c4a93a7d5ec0f65ae59dd22cbf5eaabd873ef0f7f107398d52917fcf9d0ac394  micro-puc51.tsv
```

### (b) The six starts are byte-identical

The six blueprint identity SHA-256s the seam computes are unchanged, which the
`wp13_integration` row of the micro pair carries:
`e07ac54b…` (hearthpine), `81d78a7a…` (dawnmere), `258ca31c…` (silverleaf),
`a0f41a3b…` (stillgrave), `10e67e0e…` (sunscar), `651193c7…` (kapok) -- the same
six the round-A record carries.

### (c) Engine

`tools/wp13/run_engine.sh` over the six starts, both gate seeds, forward and
reverse owner order, each with its own cold world and its own disk-only reload:
twelve digests, all identical to the committed round-A values.

| | user seed 531802985935182545 | boundary seed 8675309 |
| --- | --- | --- |
| owners | 44 | 62 |
| hearthpine | `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c` | same |
| dawnmere | `19f8c63f3de9dfe052f0143c52486e60938f2543b96b53e20af3fa3d35787c95` | same |
| silverleaf | `a81a370a26a293f676a78f35b9e1f18dd9487320d8de9849b1151b86eb763a4c` | same |
| stillgrave | `13f3cff1f580eb6d79146ee0233e0f46ff0227ba37b0f2a001fd0a16625d2ca1` | same |
| sunscar | `de46c91105d3612598cc415e79a8fd44e45dc8f299971a331fd090d42e1da3c0` | same |
| kapok | `e11c30ec9e88b7ce16f8942cd12f4bb5449fc489bf96c48004f5405790f8fd01` | same |
| combined | `206a86a057b0b6ed4cb5ee71df67413e0f40b70f0b486ea3947bbbbb99eac9a6` | same |

`tools/wp13/run_highcourt.sh` is the capital's own pass: one headless boot
through an isolated scratch directory, 45 mapchunks emerged one at a time, zero
ERROR and zero ModError lines. Its NPC counts:

| Settlement | placed |
| --- | --- |
| each of the six starts | `guards 3/3 flair 4/4 vendor 1/1 quest 1/1 new 9 pending 0` |
| Highcourt, first readiness pass | `guards 17/19 flair 30/49 vendor 2/2 quest 1/1 new 50 pending 21` |

71 of Highcourt's 95 sockets carry an NPC (the king and the waypoint carry
none by design, and 22 patrol waypoints are route data behind their six loop
leaders). 50 went in on the readiness pass, which is every socket whose own
mapblock was loaded at that moment; the remaining 21 are the far district plots
and the upper gate-tower decks, which fill in on the heartbeat as a player walks
up. Both
capital vendors stand on their sockets, so `vendors.lua` places none of its own
at Highcourt.

### (d) Static gates

`static.sh` / `static.txt`: `tools/bin/luac51 -p` and the SETGLOBAL count on
every file this package touched (all PASS, all zero globals except the probe's
own single mod table), the whole `mods` and `tools` trees parse under plain 5.1,
and the five sweeps scoped first to the touched files and then to
`mods/*/grug_*` and `tools/wp13`. Every sweep hit is a pre-existing comment or
the standalone-CLI `os.exit` pattern the dumpers have carried since the renderer
landed; no touched file contributes one. `check_fresh_server.py` PASS.

## 7. Highcourt as built, for the coordinator to look at

`renders/`, drawn by `tools/wp13/render_blueprint.py` from TSVs the probe read
back **out of the finished map**, not from the composition:

| File | What |
| --- | --- |
| `renders/core-ne.png` | the whole civic core in terrain, from the +x/+z corner |
| `renders/core-sw.png` | the same from the opposite diagonal |
| `renders/plot-granary.png` | the `market_granary` district plot on its own terrace |
| `renders/avenue-east.png` | the east avenue from the gatehouse down the terraces, across the river causeway, to the gate station |
| `renders/avenue-east-night.png` | the same at night, which is what the lamp line is for |
| `renders/tsv/*.tsv` | the three dumps themselves, anchor-relative |

## 8. Protection

Nothing to add, as the contract states, and confirmed here: `source/simple_map.lua`
gives every capital anchor the `hard_capital_build_plus_apron_v1` recipe -- a
532 × 532 centred half-open square from y = −700 upward, unbounded above -- plus
`hard_capital_ingress_corridor_v1`, a 128-wide corridor along its two routes.
The 512 envelope, the four gate stations at ±256 and every avenue and ring run
of this package are inside that square; the widest thing it writes is a plot
perimeter at x = 203, 63 nodes clear of the edge. The capital footprint and its
corridors are already in the frozen anchor roster digest, which the six-start
engine gate re-verified unchanged.

## 9. Open points

1. **The river causeway has no parapet.** The east avenue crosses the river as
   a five-wide paved causeway at water level with its lamp line continuing
   across, which is walkable and reads as a road, but a real bridge -- piers,
   parapet, an arch -- is a composition decision and belongs to the capitals
   lane. The seam's part (following the walkable surface) is done.
2. **The avenue does not clear its own airspace.** `avenue.run` writes pavement,
   treads and lamps and nothing else, so a tree the engine's decoration pass put
   on the road stays standing on it. No such tree appeared in this seed's
   renders, but nothing prevents one. A `clear` course over the carriageway is
   an `avenue.lua` change.
3. **`market_counting_house` clears its airspace by one node.** The surface
   rises 12 above its reference column on the user seed against a clear that
   reaches 13. Measured, covered, and worth a second look when the other three
   districts are authored.
4. **The other three districts and the quadrant permutation** are the next
   increment's, as `wp13-highcourt.md` section 9 already says.
5. **The five remaining capitals** need only a capital source file each; the
   seam takes any number of them, and `M.BOUNDS` already carries their volumes.
6. **The user has not walked Highcourt.** Nothing here is accepted until they
   have.
