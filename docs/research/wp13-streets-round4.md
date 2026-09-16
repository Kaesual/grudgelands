# WP13 — the streets after playtest 6 (2026-09-16)

Round 4, Lane G. Branch `wp13-r4-streets`, on `main` at `dfb32cd5` (the wave-3
merge: one street rule for all six capitals — road-wide envelope, junction
plateaus, viaducts on pillars, bridges over water).

Playtest 6 walked Lethariel and Kezamba in a fresh world on the user's own seed
`15912857179583385436` and said "otherwise looks really good, very satisfied".
It made three findings, all of them about the same two things: what stands on a
street's VERGE where another street joins, and two of Lethariel's streets being
one street.

The record of the rule set itself is
[wp13-street-geometry.md](wp13-street-geometry.md); this is the round that
closed two of its "what is open" items and measured a third.

---

## 1. The findings, and what each one is now

| # | The user's words (2026-09-16) | The answer |
| --- | --- | --- |
| 1 | Lethariel ~1900,−1400: "two street ENDS meet on a bridge over water; the rail of each protrudes into the other street." | The north-east ring corner over the mere. A verge lane is one node OUTSIDE its own carriageway, so at a corner it runs across the road that joins. `street_plan.verge_clearance` now names those cells and `avenue.run` writes nothing on them. §2 |
| 2 | Lethariel ~1700,−1400: "in +x and in −z, two streets overlay each other with a 2-node offset across the walking direction; the last one written wins and artefacts of the overwritten street remain." | The six side-by-side pairs wave 3 pinned and escalated. Each district lane now stands on the RING's own centre line and starts one column past the ring run it continues. §3 |
| 3 | Kezamba ~1800,1595: "at a street CROSSING over water the side rails leave only a one-node gap into the crossing — the same pattern as 1 with four ends. Wanted: railings, fences, verge posts and pillars end at the crossing square; the plateau square is rail-free towards every street that joins it." | The same rule as 1. The crossing of `avenue_north` and `ring_north` over water. §2 |

Nothing else about the street rule changed: the five rulings of playtest 5 are
untouched and their eleven mutations are still red (§7).

---

## 2. The verge ends at the street that joins it

### 2.1 What was wrong, in one sentence

`avenue.lua` writes the plank walk, the rail, the pillars and the lamp
standards on the two lanes one node outside its own carriageway. At a crossing,
at a corner and at a T-joint those two lanes lie INSIDE the other street's
carriageway — so every one of those things stood in the middle of the road that
joins. Over water, where a street is a bridge and the verge carries a rail at
every column, that is a fence across the junction, which is what the user saw
twice.

### 2.2 The rule

`wp13/street_plan.lua` gains `M.verge_clearance(streets, width)`. Per run and
per SIDE it answers the spans along the run where that verge lane lies inside
another street run's carriageway rectangle, merged. `M.attach` hands it to the
run as `clear_verge`, beside the junction squares and the barrier passages, and
all three travel the same way: derived from the run rectangles and the
carriageway width alone, so they are static, seed-free and already covered by
the overlay's identity bytes.

`avenue.run` writes NOTHING on a verge lane the answer names — no plank, no
rail, no pillar, no kerb footing, no standard.

Three properties make it the ruling and not "write less verge":

* **Per SIDE.** At a corner only one of the two verge lanes is inside the other
  road. The parapet on the OUTSIDE of the corner, where nothing joins, stays.
* **The deck stays continuous.** The cell the verge gives up is by construction
  a cell the joining run PAVES, at the plateau's own y. The walk is handed over,
  not interrupted.
* **It is a column question, not a plateau question.** The plateau square is
  the two carriageways' intersection; a verge lane is beside it. What decides is
  the verge cell's own column.

### 2.3 What the numbers say

`tools/wp13/street_geometry.lua` gained two columns, both read off the cells
the overlay writes:

* `verge_in_road` — cells a run writes on one of its two verge lanes whose
  column lies inside another street run's carriageway;
* `plateau_rail` — of those, the RAIL cells at a position inside one of the
  run's own junction squares.

Six capitals × nine fixture seeds:

| seed | `verge_in_road` before | after | `plateau_rail` before | after |
| --- | --- | --- | --- | --- |
| 531802985935182545 | 2662 | **0** | 228 | **0** |
| 8675309 | 2508 | **0** | 208 | **0** |
| 15912857179583385436 | 2490 | **0** | 195 | **0** |
| 0 | 2617 | **0** | 236 | **0** |
| 1 | 2405 | **0** | 177 | **0** |
| 2 | 2469 | **0** | 183 | **0** |
| 42 | 2417 | **0** | 172 | **0** |
| 12345 | 2695 | **0** | 228 | **0** |
| 999999999 | 2540 | **0** | 190 | **0** |

Per capital on the gate seed 8675309, `verge_in_road` before → after:
Highcourt 379 → 0, Dur Brannoc 409 → 0, Gor Drazhak 280 → 0, Lethariel 940 → 0,
Kezamba 236 → 0, Nhal Veyr 264 → 0.

What it costs in furniture, same nine seeds: **414 of 4444 lamp standards**
(4444 → 4030 on every seed, because the lamp rhythm and the run rectangles are
both seed-free) and 3–6 % of the rails (e.g. 5112 → 4848 on the gate seed).
Every one of them stood in another street. Nothing else moved: cross-profile
spread stays 0, worst step 1, `junc_spread` 0, `junc_step` 1 and `lamps_off` 0
on all nine seeds.

### 2.4 The successor's own lamp rule is still there, and still earns its place

`wp40/r7_settlement.lua`'s cross-run arbitration rule 2 drops a lamp standard
whose verge cell is inside another RUN's carriageway. It is not the same rule:
it sees every run of the overlay, the curtain wall and the gate cones included,
and the road module is handed only the street rectangles. So it stays, and the
seam KAT's `overlay` row measures the change: **10 standards dropped → 2**.
The eight that went are the street-against-street cases the module no longer
emits; the two that remain are a street against something that is not a street.

---

## 3. Lethariel's six pairs of parallel streets

### 3.1 What was wrong

Wave 3 measured six side-by-side stretches, all Lethariel's: a district lane at
±98 running alongside a ring side at ±96 for 97 columns each, three of the five
lanes of one being three of the five lanes of the other
([wp13-street-geometry.md](wp13-street-geometry.md) §8, first bullet). Two
streets two nodes apart are one street; the road-wide envelope gives the two
runs two answers for a shared column, the seam's first-run-wins arbitration
picks one, and the other's cells stay where the winner did not cover them. It
was the only unwalkable step left in the six capitals.

### 3.2 The change

Each of the six lanes is now **the ring street carrying on past its own
corner**: it stands on the ring's centre line (±96, not ±98) and begins one
column past the end of the ring run it continues (±97, not 0). The `northeast`
quadrant's shore walk was never beside a ring run and is unchanged.

Three things follow:

* the lane and the ring are **collinear and share no column**, so there is
  nothing to arbitrate;
* the lane meets the **perpendicular** ring run at the corner, which is an
  ordinary junction — so the corner's plateau covers the ring's last columns AND
  the lane's first ones and pins both to one y. A collinear seam with a plateau
  under it cannot step;
* the two lanes of a quadrant meet the two ring sides at the same corner, so
  each ring corner is **one four-way junction group**.

Lethariel's own two lane/lane butt joints went with the change: the ring street
now stands between the two halves that used to meet at 0.

### 3.3 What the numbers say

**Walkability** — `tools/wp13/walkability.lua` (moved this round out of wave
3's evidence directory into the tool directory) builds each capital's road the
way the seam does and counts neighbouring road columns whose walking level
differs by two or more. Six capitals × nine seeds; every capital but Lethariel
is 0 on both trees.

| seed | Lethariel, `main` dfb32cd5 | Lethariel, branch |
| --- | --- | --- |
| 531802985935182545 | 11 | **0** |
| 8675309 | 3 | **0** |
| 15912857179583385436 | 7 | **0** |
| 0 | 7 | **0** |
| 1 | 3 | **0** |
| 2 | 14 | **0** |
| 42 | 3 | **0** |
| 12345 | 6 | **0** |
| 999999999 | 3 | **0** |

**All 54 capital/seed pairs are now 0, worst step 0.** The worst step on main
was 2 on every seed, and every example it printed was a lane/ring pair:
`1704,−1460 (lane_northwest_spine, y=30)` beside `1705,−1460 (ring_west, y=28)`
on the user's own seed.

**The lots** — `luajit tools/wp13/lethariel_plots.lua .` re-derives every
district and fill lot of all four quadrants on all nine seeds against the run
rectangles: **0 illegal lots**, "every Lethariel lot is dry, inside the skirt
and under its own roof on all 9 seeds". The lane band moved two nodes towards
the ±72/±124 lot columns and still clears them by ten.

**The inventory** — `street_kat.lua` §8: Lethariel 15 street runs, 24 junction
records, **0 parallel overlaps** (it was 15/30/8). Tree-wide the inventory is
now **12 butt joints and no side-by-side pair** (it was 14 and 6): Dur Brannoc,
Gor Drazhak and Nhal Veyr keep four each, Lethariel has none left.

That is two fewer butt joints than the brief projected. The brief expected the
six side-by-side pairs to become nothing and Lethariel's two lane/lane butt
joints to survive; they did not, because the two spine lanes that used to meet
at z = 0 are now at opposite ends of the ring side that runs between them.

**And §8 is an assertion now, not a row somebody reads.** It pins the
inventory as a property: a parallel overlap must be two COLLINEAR runs sharing
exactly one column. A composition that grows a side-by-side pair again turns the
KAT red instead of changing a digest.

### 3.4 What it cost

Per-mapchunk time, Lethariel, gate seed 531802985935182545, `run_capital.sh
full` on both trees (wave 3's own engine record against this branch's):

| | wave 3 | branch |
| --- | --- | --- |
| capital mapchunks | 100 | 100 |
| steady mean | 534 547 µs | 551 612 µs |
| worst | 974 915 µs | 1 167 292 µs |

+3.2 % on the mean. **It is an upper bound and not a clean measurement**: the
workstation was carrying four other round-4 lanes and at least two other
headless servers throughout, and wave 3's own record carries the same caveat.
The re-derived plots cost nothing by construction — they are the same plots on
the same offsets; only the run rectangles moved.

---

## 4. The corner read-back (`capital_probe`)

### 4.1 The cause

Wave 3 left this open: Highcourt's `corner` region — 49 572 cells over four
boxes, which wave 3 called the largest any capital publishes and which this
round measured against Nhal Veyr's 66 091 — came back with 12 000 and 14 125
`ignore` nodes on two passes of four, on an idle machine
([wp13-street-geometry.md](wp13-street-geometry.md) §9). `run_capital.sh` grew a
guard that refuses to compare such a digest ("re-take the pass; do NOT re-freeze
this digest"), and the guard has been firing on a read that was the probe's own.

A node read loads nothing: the engine answers `ignore` for a mapblock that is
not resident, and **emerging a box is not the same as keeping it**. The probe
emerged each box and read it one server step later, and between those two
moments nothing held the blocks. Two further holes were in the same loop: an
errored or cancelled emerge still decrements the callback's own counter, so a
half-finished box looked finished; and a box that came back short was written
into the file and the digest anyway.

### 4.2 The fix

* **Held.** Every mapblock of a box is force-held (transient) between its
  emerge and its read and released straight afterwards. `run_capital.sh` raises
  `max_forceloaded_blocks` for the disposable probe world, because the engine's
  default is 16 and Highcourt's district region is several hundred blocks. The
  blocks are in memory already; the hold is bookkeeping and not a second copy.
* **Checked.** The emerge outcome is read, not assumed.
* **Re-read.** A box that still comes back with anything ignored, or with an
  errored emerge, is thrown away and taken again, up to four times. That is why
  the read now buffers: a half-read box may reach neither the file nor the
  digest.

Every region publishes `<label>_held`, `_unheld`, `_emerge_trouble` and
`_retries` beside `_ignored`, so a pass says which of the three did the work.
**The guard in `run_capital.sh` is unchanged** — it is correct, it just has
nothing left to refuse.

### 4.3 What the numbers say

**Four consecutive `run_capital.sh full` passes of Highcourt on seed 8675309**,
on the branch, one server at a time on a workstation also carrying four other
round-4 lanes:

| pass | `corner_cells` | `corner_ignored` | `corner_held` | `corner_retries` | `corner_emerge_trouble` |
| --- | --- | --- | --- | --- | --- |
| a | 49 572 | **0** | 96 | 0 | 0 |
| b | 49 572 | **0** | 126 | **1** | 0 |
| c | 49 572 | **0** | 96 | 0 | 0 |
| d | 49 572 | **0** | 96 | 0 | 0 |

Every region of every pass reads the identical cell count — core 43 075, plot
7253, avenue 63 866, district 195 126, approach 21 866, rampart 29 674, gate
11 910, corner 49 572 — and every one has `ignored = 0`. The four `avenue`
digests are the same value, which is this package's determinism check on the
engine side, and `rampart`, `corner` and `gate` match the values committed
before this round on all four.

**Pass b is the interesting one.** One corner box came back short even with its
blocks held, and the retry read it whole: `corner_retries = 1`, `held` 126
instead of 96 (the box was held twice), `ignored` 0. So the hold alone would not
have been enough on that pass, and the belt-and-braces is not decoration. Not
one pass in the campaign needed a second retry, and `emerge_trouble` was 0
throughout — the emerge itself never errored, which rules out the other
hypothesis.

**Two Nhal Veyr passes** on 531802985935182545, whose `corner` region is the
tree's largest at **66 091 cells**: `corner_ignored = 0` on both, cell counts
identical, one retry on the second pass (`corner_held` 144 against 120), no
emerge trouble. Its `rampart`, `corner` and `gate` digests match the committed
values on both passes.

So the brief's gate is met: **six consecutive passes, `<label>_ignored = 0` on
every region of every one of them**, and the `run_capital.sh` "re-take the pass"
branch did not fire once — on a workstation that was NOT idle.

---

## 5. Highcourt's walker ring and `find_path` (goal D)

### 5.1 `min_walker_ring=1` — the cause, and it is not street or lot geometry

Wave 3 escalated it and proved it pre-existing
(`docs/research/wp13-polish-wave3.md` §5.1): at least one of Highcourt's
walkers is handed a wander ring of ONE spot, and a ring of one is a walker that
never moves. This lane was asked to find the cause and to fix it if it turned
out to be geometry.

It is not. `tools/wp13/evidence/20260916-streets-r4/walker_ring.lua` replays,
with no engine and no world, the two rules of
`mods/ENTITIES/grug_mobs/start_npcs.lua` that decide a ring — the 80/20 split
(every fifth `idle` spawn socket in authored order hosts a walker) and
`bounded_spots` (a walker's ring is the idle sockets of ITS OWN COMPOSITION
within `WALK_RADIUS` = 20, topped up to `WALK_MIN_RING` = 3 "from whatever the
composition can actually offer"). It reads the three constants out of the
production file rather than retyping them.

| capital | sockets | idle spawn | walkers | worst ring | the walker | its composition's idle sockets |
| --- | --- | --- | --- | --- | --- | --- |
| highcourt | 256 | 108 | 22 | **1** | `market_workshop/market_workshop_gate_idle` | **1** |
| dur_brannoc | 269 | 106 | 22 | **1** | `forge_store/forge_store_gate_idle` | **1** |
| gor_drazhak | 315 | 104 | 21 | 2 | `bazaar_brewhouse/bazaar_brewhouse_idle_grog_bench` | 2 |
| lethariel | 253 | 106 | 22 | **1** | `martial_lodge/martial_lodge_gate_idle` | **1** |
| kezamba | 262 | 101 | 21 | **1** | `shore_house/shore_house_gate_idle` | **1** |
| nhal_veyr | 274 | 116 | 24 | **1** | `market_grave_field/market_grave_field_gate_idle` | **1** |

**The cause, in one sentence: a composition that publishes exactly ONE idle
socket has nothing to top a ring up from, and the every-fifth counter lands on
it.** Five of the six capitals have one, not just Highcourt — Highcourt is
simply the one a probe was pointed at. Moving a street or a lot cannot change
it; what can is either a second idle socket in those compositions or a top-up
that may reach outside the composition.

**Not this lane's, and named rather than left as "something is wrong at
Highcourt":** it belongs to whoever owns the socket placement of those plots
(`wp13/*_plot.lua` / `*_districts.lua` rosters) or to the walker rule in
`grug_mobs/start_npcs.lua`. The probe already fails a capital pass on it, which
is why a `full` pass of a capital with the defect reports `errors=1`.

### 5.2 The non-zero `find_path` — measured, still open

Wave 3 measured 21–30 `core.find_path` calls in a 30-second capital window
(41–59 a minute) against zero at a start, on `main` and on its own branch
alike, and named `patrol.lua`'s stuck rescue as the only caller a settlement
has. This lane did not change patrol routes, guard behaviour or the wall walk;
the one thing it changed that a guard can stand on is the verge furniture, and
removing a rail from the middle of a street can only help a stuck guard.

This lane did not re-measure it: the workstation carried four other round-4
lanes and two to four other headless servers throughout, and a `find_path`
count in a quiet window measured on a busy host says nothing wave 3's own
record does not already say with the same caveat. **It stays open, with wave
3's numbers and wave 3's suspect.**

---

## 6. The digests that moved

<!--ENGINE-DIGESTS-->

---

## 7. What a reviewer should look at

1. **`street_plan.verge_clearance`'s two branches.** A parallel run covers a
   verge lane over its whole span or not at all; a crossing run covers it over
   its own width where the lane is inside its span. Both are clipped to the
   street's own span and merged. The side is the hand `avenue.lua` counts lanes
   in — get it backwards and the rule takes the parapet where nothing joins and
   leaves it where a street does, which is mutation 3 of `mutation.py`.
2. **That the deck really is continuous.** §11(c) of the KAT asserts it on the
   synthetic pond; the real-terrain claim rests on `walkability.lua` being 0 on
   all 54 capital/seed pairs, which reads the road as the seam writes it and
   would see a hole.
3. **Lethariel's corners.** Each is now one four-way junction group; the
   plateau's symmetry argument (§3 of wp13-street-geometry.md) is what makes the
   collinear seam between a ring side and its lane safe, and `junc_spread` 0 on
   nine seeds is what says it holds.
4. **The probe's retry loop.** It is bounded (four attempts) and it commits
   only a clean box; a region that cannot be read whole still reaches the gate
   with a non-zero `_ignored` and still fails the pass.
5. **The KAT's own coverage.** Four new mutations (`mutation.py` in this
   round's evidence) plus the eleven of wave 3, all red. Two of the four are
   deliberately NOT "turn the rule off": each narrows the clearance so that
   exactly one of the two shapes §11 builds keeps its rail, which is what says
   the section holds the butt joint and the crossing separately.
6. **Chunk independence of the new input.** §11(d) cuts the crossing's own
   avenue at every one of its 96 interior columns and compares the union of the
   two pieces with the whole, cell for cell — the invariant the module lives
   inside, re-checked for a rule that reads a new per-position table.

---

## 8. What is open

* **`min_walker_ring=1` in five of the six capitals — NOT this lane's, with a
  name attached.** See §5.
* **A non-zero `find_path` in a quiet capital window.** See §5.
* **The gate-arrival ramp is still Kezamba's alone.** Goal E of this lane's
  brief, optional and not started:
  `T(p) = min(D(p), g + |p − gate|)` out of `kezamba_ramp.lua` and Nhal Veyr's
  `gate_road` and into `avenue.lua` would retire two per-capital
  post-processes.
* **Junctions that are close but disjoint** — unchanged from wave 3 §3:
  measured flat on nine seeds, not proved.

---

## 9. What to look at in a FRESH world

A capital's streets are mapgen, so an existing world keeps the old ones: this
needs a **new world**, and the user's own seed `15912857179583385436` is the one
the findings were made in.

1. **Lethariel ~1900,−1400** — the north-east ring corner over the mere, where
   the two bridge ends meet. The rail of each should now stop at the other
   street's kerb; the square itself is open on both sides; the parapet on the
   OUTSIDE of the corner — the water side — is still there.
2. **Lethariel ~1700,−1400** — the north-west corner. There should be ONE
   street here, not two two nodes apart, and no leftover paving beside it. The
   ring's west side now carries on north as the district lane and the seam
   between them is inside the corner plateau, so there is no step.
3. **Kezamba ~1800,1595** — the crossing over water. All four arms should open
   into the square with the full carriageway, not through a one-node gap, and
   the square should carry no rail, post or pillar.
4. **Any street corner in any capital** — the rule is every capital's, so
   Highcourt's ring corners, Dur Brannoc's gate crossings and Gor Drazhak's
   lanes got it too. What should NOT have happened: a gap in a bridge parapet
   anywhere except where a street joins, or a stretch of bridge deck with
   nothing to walk on.
5. **The lamps.** 414 standards of 4444 are gone — every one of them stood in
   the middle of a joining street. The remaining rhythm should read the same
   walking down a street; a crossing simply has no standard in it.

---

## 10. Files

| file | what changed |
| --- | --- |
| `mods/MAPGEN/grug_mapgen/wp13/street_plan.lua` | `verge_clearance`, attached by `attach`; the inventory header |
| `mods/MAPGEN/grug_mapgen/wp13/avenue.lua` | the `clear_verge` spans, consumed per side in the verge pass |
| `mods/MAPGEN/grug_mapgen/wp13/lethariel_quadrants.lua` | the six district lanes on the ring's own centre lines |
| `mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua` | append-only: `clear_verge` on the prepared run and on the spec the successor hands `avenue.run` |
| `tools/wp13/capital_probe/init.lua` | the dump read: hold, check, re-read, commit; four new counters per region |
| `tools/wp13/run_capital.sh` | `max_forceloaded_blocks` for the probe's world |
| `tools/wp13/street_geometry.lua` | `verge_in_road` and `plateau_rail` |
| `tools/wp13/street_kat.lua` | §11 (the verge clearance) and §8 as an assertion |
| `tools/wp13/walkability.lua` | **moved** out of wave 3's evidence directory; the two run-spec fields |
| `tools/wp13/lethariel_kat.lua`, `kezamba_lots.lua`, `integration_fixture.lua` | the same two run-spec fields, so the offline road is the road the engine writes |

`tools/wp13/lane_routes.lua` is deliberately NOT in that list: it builds its
runs in WORLD coordinates, where a span in the run's own coordinates would mean
something else, and what it measures is the CARRIAGEWAY — the verge clearance
cannot move a cell it reads. Its gate is green on all nine seeds
(`illegal=0 walk_faults=0 cross_faults=0 lamp_faults=0`).
| `tools/wp13/evidence/20260916-streets/mutation.py` | one anchor re-indented — the verge block gained a level |
| `tools/wp13/evidence/20260916-streets-r4/` | the evidence |
