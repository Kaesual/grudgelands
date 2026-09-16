# WP13 — one street rule for all six capitals (2026-09-16)

Wave 3, Lane S. Branch `wp13-w3-streets`, rebased onto `main` at `70dda602`
(Lanes A, X, C, F and P merged); written against `f37a0c5b`, the wave-2 merge
with six capitals, and re-measured whole on the rebased tree.

Playtest 5 walked Dur Brannoc and Lethariel and made five rulings about what a
capital's streets are. Every one of them is now a rule of `wp13/avenue.lua`, the
shared road module all six capitals build their avenues, ring streets, district
lanes, fill lanes and gate approaches out of — because a street rule that lives
in one capital is a street rule the other five do not have.

---

## 1. The rulings, and what each one is now

| # | The user's words (2026-09-16) | The rule |
| --- | --- | --- |
| 1 | "Streets follow the terrain exactly, a wild mix of stairs and orthogonal one-block jumps." | The road's ground at a position is the **highest of its five lanes'**, and one one-Lipschitz envelope of that field is the walking level of **every** lane. One cross profile per column of the run; at most one node of climb per column along it. |
| 2 | "The connecting street must be raised artificially at the junction." | A junction is a **square plateau on one y**, computed identically by both runs, applied as a ground **floor** so the envelope ramps up to it a node a column on every side. |
| 3 | The lamp posts follow the ground. | A standard foots at the **street's own level**, not at the verge column's ground. |
| 4 | Streets raised artificially must stand on **support pillars with open air beneath**. | A column raised `MIN_CLEAR` (3) or more carries the deck course and nothing else; pillars every `PIER` (8) columns on the two verge lanes; a smaller raise is still solid ground. |
| 5 | Lethariel's piers and railings: "super, I want that in Highcourt (and every other city where it is missing)." | Every street of every capital that stands over water is a **bridge**: deck one node over the water, nothing at or under the water line, piers on the verge lanes, a planked and railed walk over them — in that race's own palette. |

## 2. What the numbers say

`tools/wp13/street_geometry.lua` builds WP40's height session offline (the
construction `lane_routes.lua` uses — no engine, no world), runs every street run
of all six capitals through the real overlay seam, and reads the metrics off the
**cells the overlay writes**, not off the rule that wrote them. The same tool
measures both trees: it falls back to this branch's `street_plan.lua` when the
tree it is pointed at has none, and the junctions of a capital are a function of
its run rectangles alone, so both halves are asked the identical question.

Nine fixture seeds, six capitals, `--runs`:

| metric | before (`main` f37a0c5b) | after | the ruling |
| --- | --- | --- | --- |
| worst cross-profile spread | **5..8 nodes** | **0** | 1 |
| worst step along a run | 1 road-wide, **up to 3 per lane** | 1, **1 per lane** | 1 |
| worst spread over a junction square | **4..22 nodes** | **0** | 2 |
| worst step arriving at a junction | 1 | 1 | 2 |
| columns raised ≥ MIN_CLEAR | 924..2460 | 1498..4796 | 4 |
| …of those, solid fill | **all of them** | **0..5** | 4 |
| …of those, on pillars | 0..77 | 1498..4793 | 4 |
| street columns over water | 7475 (identical on all nine seeds) | 7475 | 5 |
| rails written | 0..1377 (Lethariel and Kezamba only) | 3702..5136 (all six) | 5 |
| lamps footing off the street | **1089..1244 of 4343** | **0 of 4444** | 3 |

Per capital on the gate seed 8675309, cross-profile spread before → after:
Highcourt 5 → 0, Dur Brannoc 7 → 0, Gor Drazhak 3 → 0, Lethariel 4 → 0,
Kezamba 6 → 0, Nhal Veyr 3 → 0. Junction spread before → after: 2, 14, 3, 2, 3,
3 → 0 everywhere.

**Which capitals have water under a street at all** was measured rather than
assumed, and it is three: Highcourt (10 runs, 2811 columns), Lethariel (6 runs,
2528) and Kezamba (4 runs, 2136). Dur Brannoc, Gor Drazhak and Nhal Veyr have
none. The set of wet columns is **byte-identical on all nine fixture seeds** —
a planned water body is a property of the static world plan, which is what the
seam's own `wet(x, z)` now publishes.

## 3. How the junction plateau works, and what is proved about it

`wp13/street_plan.lua` (new) takes a capital's street run **rectangles** and
answers, per run, the squares it shares with another street and which stretch of
each other run those squares are. It is handed the rectangles and never a height,
because a run list is static — the same on every world and every seed, and
already inside the overlay's identity bytes.

`avenue.run` gives the square its height:

    J = max over every run standing in the square of
        that run's BARE one-Lipschitz envelope over the square

computed from the same `surface` callback and the same two sweeps. It is applied
as a **ground floor**, and that is what makes the approaches right for free:
raising the square's ground to J lifts the envelope on both sides a node at a
time, and over the square the envelope is J exactly — every column of it is at J,
and no column outside it can push one above J, because J is already at or above
the bare envelope there.

**THE TWO RUNS AGREEING IS MEASURED, NOT CONSTRUCTED**, and the independent
review of 2026-09-16 was right to say so. The windows are not identical: a run's
own contribution is `bare[p]`, the envelope over its whole piece window
`[from − reach, to + reach]`, while every other member's contribution is an
envelope over `square ± reach`. The first is wider, so a run's self-contribution
can only be ≥ what another run computes for it; nothing forces them equal. What
makes them equal is that a column outside `square ± reach` is more than `reach`
away and would have to stand more than `reach` nodes above everything between it
and the square to bind — which WP40's terracing (cut 24, fill 16) cannot produce,
and which is the same assumption `reach` itself rests on.

So it is held by measurement: the reviewer's own probe reads every run's
published `plateaus` and compares the y each member computed for the same group —
**plateau_disagree = 0 on all six capitals × four seeds**, 8–19 junction groups
per capital. `tools/wp13/street_kat.lua` §9 holds the same property on a profile
built to break it: the ground is flat under the square and a ridge stands
eighteen columns away on the crossing run's axis, so the plateau's height can
only come from the other run's envelope reaching over that distance. Clip that
window to the square — the mutation the review ran — and the two runs disagree by
2 nodes and the KAT goes red.

Two details the measurement forced:

* **Two squares that share a column are ONE junction.** Three streets meet in one
  place often enough: Lethariel's east avenue crosses the ring street at 94..98
  and a district lane at 96..100, and taken as independent pairs those took
  levels 22 and 23 on the gate seed, leaving the ring's own square a node out of
  true. The plan merges squares transitively and every member computes the
  maximum over the same set of profiles.
* **The other run's window is not clipped to its span.** A run reads `reach`
  columns beyond both its ends, so clipping there computed a different envelope
  from the one that run computes for itself. Seed 999999999 disagreed by exactly
  one node at Highcourt's north-west ring corner until that clamp came off.

**Bounded window, and therefore chunk independence.** J reads the ground of the
participating runs within `reach` of the square and of nothing else, and the
square is a function of the run rectangles. `tools/wp13/street_kat.lua` section 7
cuts every run of every case at **every** column and compares the union with the
whole; the capital KATs do the same over their own profiles.

**What is measured and not proved:** two junctions on one run that are closer to
each other than the difference of their plateau levels would each lift the
other's square. Merging handles the case where the squares overlap; junctions
that are close but disjoint are not merged, and the guarantee there is
measurement — `junc_spread` is 0 on six capitals × nine seeds, and the KAT's
junction sections go red the moment it is not.

## 4. The bridge, and why Lethariel's water mask is gone

The seam hands a road the **water surface** where water stands, not the bed under
it, so the first version of `avenue.lua` laid a solid causeway at the water line —
which cut Lethariel's 38 527-column mere into six lakes and dammed three of
Highcourt's rivers. Lethariel answered with `elf_bridge.lua` and a hand-measured
span table, because that module ramped its lift from nothing at the shore to one
node inside the span so the deck stayed one-Lipschitz, and **that** is what
needed the whole span.

It is not needed. A wet column carries `water + LIFT` into the road's own ground
field, the maximum of two one-Lipschitz fields is one-Lipschitz, and the envelope
is therefore flush with the road at the shore **by construction**. A wet column
becomes a per-column question, `wp40/r7_settlement.lua` publishes it as a third
value out of the `column_values_at` call it already made, and `elf_bridge.lua`
and `M.water_plan` are both gone. With the ramp gone so are the two abutment
columns that used to stand at the water line: the KAT now asserts **zero**
carriageway cells at or under the water, not two.

Every role a bridge needs — `floor`, `railing`, `post`, `light_post`, and
`signature` with its `wall_accent` fallback — is a **required** role of every race
(`wp13/palette.lua`), so this needed no new palette binding in any capital.

## 5. Why `MIN_CLEAR` is the viaduct threshold

The ruling says "solid ground fill stays only where the raise is small" and the
brief offers `MIN_CLEAR` as the natural reading. It is, and for the module's own
reason: `MIN_CLEAR` is already the number for *a road fits under this*. A deck
written at the walking level leaves `raise - 1` nodes of air under it, so a raise
of exactly 3 leaves 2 — which is exactly a player — and every raise above it
leaves `MIN_CLEAR` or more. Below 3 a column is a terrace stair on fill, and a
rail on every tread would turn the ordinary road into a trench.

**One exception, and the crossing KAT is what found it.** A position the crossing
rule put **on a WP40 route's deck** is filled and not pillared: a route's bridge
may be narrower than the carriageway, and the outer lanes are then an abutment
that has to be solid, or the road beside the deck hangs in the air with the
route's own piers under the middle of it and nothing under the edges.

**That exception has NO real-terrain coverage, and the 0..5 solid columns in the
table above are something else.** Both halves of that sentence are the
independent review's and both are measured:

* `tools/wp13/lane_routes.lua` reports `spanned = 0` on every one of the nine
  fixture seeds, on this branch and on `main` alike: **no WP40 route deck crosses
  a street of any capital on any fixture seed**. The `on_deck` branch of the fill
  rule is therefore exercised by `lane_crossing_kat.lua` §4's synthetic profiles
  and by nothing else.
* The 0..5 columns that are raised ≥ MIN_CLEAR and still solid are **Nhal Veyr's
  gate-tunnel floor**: all of them are the five lanes of one position, `p = 253`
  on `avenue_north`, which is `gate_at − wall.HALF` — the first column of the
  band `nhal_veyr.lua`'s own "THE GATE TUNNEL'S FLOOR" fills from the band's
  lowest ground up to the road. There is no deck within ±3 lanes of any of them.
  `nhal_veyr_kat.lua` §(c) excludes exactly that band for exactly that reason.

## 6. What this cost

The junction rule reads the other run's window as well as its own, and the verge
is read wherever something stands on it rather than only at a lamp. Measured by
`tools/wp13/evidence/20260916-streets/overlay_bench.lua`, which builds every
street run of every capital over one synthetic terraced surface and runs
unchanged on both trees:

| | before | after |
| --- | --- | --- |
| all six capitals' whole street network | 108.1 ms | 154.2 ms (+43 %) |
| `surface` calls | 125 844 | 250 352 (+99 %) |

A junction whose square lies outside the piece's own window is skipped
altogether — its floor could only ever be written at columns the piece does not
contain — and that is where most of the query count went: the seam's own
`height_cache` row in `tools/wp13/seam_kat.lua` falls from **4274 to 1739** calls
for the same fixture.

That is the **whole** network of a capital in 17..30 ms, spread by the seam over
the ~108 mapchunks the capital occupies, against a measured capital mapchunk of
0.6..1.2 s (`capital_worst_us` 1 153 334 and `capital_steady_mean_us` 626 195 on
the Dur Brannoc gate-seed pass of this branch, against 923 574 / 463 914 to
1 131 608 / 566 321 in the committed wave-2 passes — on a workstation running
four other lanes' engine passes at the same time, so that comparison is an upper
bound and not a clean measurement). And the query count is an upper bound on what the engine pays: the
seam keeps one `column_values_at` answer per column per session, so a column two
runs both read is paid for once there and twice in the bench.

## 7. What a reviewer should look at

1. **The symmetry of J.** Both sides of a junction must compute the same number
   from the same inputs. The places that can break it are the window (§3), the
   `wet` lift inside `other_envelope`, and the merge order in
   `street_plan.junctions` — the last is sorted by the run list's own index, so
   it does not depend on the order pairs were found in.
2. **The viaduct exception.** `on_deck` is decided per position and applied to
   every lane of it; check that a position both wet and on a deck cannot be
   filled (it cannot: the fill test excludes a wet lane first).
3. **The verge query memo.** `verge_surface` is what keeps the "one query per
   column" property the capital KATs assert; a second call site that read a verge
   without it would break that assertion rather than pass silently.
4. **The KAT's own coverage.** Eleven mutations: five of the lane's own, one per
   ruling (`mutation.txt`), and the six the independent review wrote against it
   (`mutation-review.txt`), including the junction window, the off-centre square
   and the pier rhythm. All eleven go red, each on the section that owns the
   rule.
5. **The three gates that had to learn the viaduct rule**, because a column with
   open air under it is the ruling and not a defect:
   `tools/wp13/lane_crossing_kat.lua`, `tools/wp13/lane_routes.lua` and
   `tools/wp13/kezamba_lots.lua gates`. Each allows the third case only where
   `top − ground >= MIN_CLEAR`, so a cell hanging over ground the road did not
   raise is still a defect.

## 8. What is open

* **Lethariel's district lanes overlap its ring street — ESCALATED to the
  coordinator, with the number.** Six pairs, up to 97 columns each, three of the
  five lanes of each the same columns: `ring_west` at x = −96 and
  `lane_northwest_spine` at x = −98 are two streets two nodes apart, which is one
  street.

  What that costs is now measured rather than described.
  `tools/wp13/evidence/20260916-streets/walkability.lua` builds each capital's
  road the way the seam does — every street run in the composition's own order,
  first run wins a shared cell — and counts **neighbouring road columns whose
  walking level differs by two or more**, which is a step no player can climb:

  | seed | highcourt | dur_brannoc | gor_drazhak | lethariel | kezamba | nhal_veyr |
  | --- | --- | --- | --- | --- | --- | --- |
  | 8675309, main | 16 | 613 | 0 | 20 | 70 | 2 |
  | 8675309, **branch** | 0 | 0 | 0 | **3** | 0 | 0 |
  | 531802985935182545, main | 24 | 656 | 0 | 20 | 18 | 4 |
  | 531802985935182545, **branch** | 0 | 0 | 0 | **11** | 0 | 0 |
  | user's seed, main | 8 | 8 | 8 | 1 | 56 | 2 |
  | user's seed, **branch** | 0 | 0 | 0 | **7** | 0 | 0 |
  | 999999999, main | 88 | 153 | 0 | 64 | 67 | 5 |
  | 999999999, **branch** | 0 | 0 | 0 | **3** | 0 | 0 |

  Dur Brannoc goes from 613–656 unwalkable pairs, worst step 12 and 18 nodes, to
  zero. **Every residual in the six capitals is at Lethariel's lane/ring
  overlap**, worst step 2, e.g. `1895,−1583 (ring_east, y = 28)` beside
  `1896,−1583 (lane_southeast_spine, y = 30)`.

  The per-run view is a regression in isolation and is recorded as one: on `main`
  the two parallel runs agreed on 288–291 of their 291 shared columns, because a
  per-lane envelope gives the same answer to whichever run owns the column; on
  this branch the road-wide envelope makes them disagree on up to 129 of 291, by
  up to 2 nodes. First-run-wins arbitration hides most of it, which is why the
  built count is 3–11 and not 129. It is the right trade — 20 → 3 on the same
  seed — but **Lethariel is the capital whose bridge the user praised and it is
  now the only one of the six with a step in it.**

  Moving a lane's centre line moves the plots that stand along it, so it is not
  this lane's to do: it is **pinned** (`street_kat.lua` §8 holds the overlap
  inventory) and handed over. The other fourteen parallel overlaps in the tree
  are butt joints of one column, where two collinear runs meet end to end, and
  those need nothing (14 butt joints + 6 side-by-side = the 20 the KAT's
  inventory row counts).
* **The gate-arrival ramp is still Kezamba's alone.** `kezamba_ramp.lua` brings an
  avenue down to its gate point at free-terrain height (contract §2.1.1); the
  other five capitals rely on their terrain being gentler there, and Nhal Veyr
  has its own `gate_road`. Generalising the one rule
  `T(p) = min(D(p), g + |p − gate|)` into `avenue.lua` would retire two
  per-capital post-processes. Not done here; it is a separate rule from the five
  rulings.
* **Junctions that are close but disjoint** — see §3.
* **Highcourt's `corner` region cannot be read reliably** (§9): two of four
  passes lost a quarter of it to unloaded mapblocks. The gate now names the
  condition; making the read reliable belongs to the lane that owns
  `capital_probe`'s corner region.

## 9. The digests that moved

An overlay's manifest identity is its SPECIFICATION and not its cells, so the
only two things this lane can move are overlay identity rows and the
built-geometry digests `run_capital.sh` gates on.

* **Four `avenue` overlay identities**: Highcourt, Dur Brannoc, Kezamba and Nhal
  Veyr, whose road palette union gained the bridge vocabulary. Gor Drazhak's and
  Lethariel's did not move — their unions already carried those names from the
  palisade and from the elf bridge.
* **Seventeen frozen built-geometry digests** under
  `tools/wp13/evidence/20260915-capital-terrain/`: nine `avenue` (Dur Brannoc on
  three seeds, Highcourt on two, Gor Drazhak, Kezamba, Lethariel and Nhal Veyr on
  the gate seed), four `rampart` and four `gate`. The road moved by design;
  a `rampart` or `gate` region moved because the ROAD cells inside it moved —
  the avenue is the first run and wins every cell it and the curtain share.
  `wall.lua` is untouched and its own KAT row is byte-identical. No `corner`
  digest moved.
* **Nothing else.** The six start identities are byte-identical to `main`'s, and
  every core, plot and settlement identity root is unchanged.

Every one of the seventeen was re-frozen from a clean engine pass of this branch
(`errors=0 complete=1`), and a second pass of Dur Brannoc on the gate seed
afterwards reported `avenue`, `rampart` and `gate` matching the committed values
— which is also this package's determinism check on the engine side.

**After the rebase onto `70dda602`** ten more passes re-verified all 28 frozen
values on the merged tree: **24 confirmed unchanged and 4 moved** — Highcourt's
`rampart` and `gate` on both gate seeds, which Lane P froze before this lane's
road moved the cells inside those two regions, exactly as the independent review
predicted. Both Highcourt passes were then re-run and report all four regions
matching.

### And the corner read-back is flaky — the gate now says so instead of blaming the road

Highcourt's `corner` region is the largest any capital publishes (49 572 cells),
and on **two of four** passes of seed 8675309, on an idle machine with no other
server running, it came back with 12 000 and 14 125 `ignore` nodes in it: the
engine had unloaded part of the region before the probe read it, which
`capital_probe`'s own header warns of. `run_capital.sh` compared the digest
anyway, so an unloaded read was indistinguishable from a moved road — and would
have cost a lane a merge.

It now reads `<label>_ignored` beside the digest and fails with its own message
("re-take the pass; do NOT re-freeze this digest") rather than comparing. The two
clean reads both give `cc6da1b7…`, the committed value. **The emerge-and-read
order of that region is Lane P's and is not fixed here** — this lane only stops
the gate from mis-reporting it.

## 10. Files

| file | what changed |
| --- | --- |
| `mods/MAPGEN/grug_mapgen/wp13/avenue.lua` | the five rulings; the road-wide envelope, the plateau, the viaduct, the bridge, the lamp rule |
| `mods/MAPGEN/grug_mapgen/wp13/street_plan.lua` | **new** — the junction squares of a capital, from the run rectangles |
| `mods/MAPGEN/grug_mapgen/wp13/elf_bridge.lua` | **removed** — the bridge is every capital's now |
| `mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua` | append-only: `wet(x, z)` at the overlay seam, and the junctions travelling with a run |
| the six compositions | append-only: the junction attachment in `overlay_runs`; the four private kerb parapets and Lethariel's water plan removed |
| `tools/wp13/street_geometry.lua` | **new** — the measurement |
| `tools/wp13/street_kat.lua` | **new** — the property, ten sections, both interpreters |
| `tools/wp13/kezamba_lots.lua`, `tools/wp13/lethariel_plots.lua`, `tools/wp13/lane_routes.lua` | the three road gates that still asked for solid ground under a viaduct, and the two that were building a causeway because nobody handed them the seam's `wet(x, z)` |
| `tools/wp13/run_capital.sh` | the digest gate refuses a region that came back with `ignore` nodes in it instead of comparing it |
| six existing KATs + the integration fixture | they asserted the road this replaces |
| `tools/wp13/evidence/20260916-streets/` | the evidence, including `gates.sh` (every road gate as a gate), `walkability.lua` (the headline number) and the eleven mutations |

---

## 11. Round 4 (2026-09-16): what playtest 6 closed of section 8

Appended by round 4, Lane G, branch `wp13-r4-streets`. The record of that round
is **[wp13-streets-round4.md](wp13-streets-round4.md)**; nothing above this line
is rewritten, because it is the record of what wave 3 measured.

Two of section 8's open items are closed and one is measured:

* **Lethariel's district lanes no longer overlap its ring street.** Each of the
  six lanes now stands on the RING's own centre line and starts one column past
  the end of the ring run it continues, so the pair is collinear, shares no
  column and is pinned to one y by the ring corner's plateau. The walkability
  table of section 8 is **0 on all six capitals and all nine seeds**, worst step
  0, where Lethariel's residual was 3/11/7/3 there and 3..14 over the full nine.
  The inventory section 9 of the KAT pins is now **12 butt joints and no
  side-by-side pair**, and it is an assertion rather than a printed row.
* **Highcourt's `corner` region can be read reliably.** `capital_probe` holds a
  dump box's mapblocks in memory between its emerge and its read, checks the
  emerge outcome instead of assuming it, and reads a short box again. Four
  consecutive Highcourt passes on 8675309 and two Nhal Veyr passes on the other
  gate seed all report `corner_ignored = 0`; one pass of each needed one retry.
  The gate that refuses an `ignore`-bearing digest is unchanged and did not fire.
* **A third finding of playtest 6 is a rule this record did not have**: a run's
  VERGE lane is one node outside its own carriageway, so at a crossing, a corner
  or a T-joint it runs across the road that joins, and everything standing on it
  — rail, plank walk, pillar, lamp standard — stood in the middle of that road.
  2405..2695 such cells over six capitals and nine seeds, now 0.

Still open from section 8: the gate-arrival ramp (`kezamba_ramp.lua`), and
junctions that are close but disjoint.

**One path above is stale and deliberately not rewritten:** section 8 and this
package's README name `tools/wp13/evidence/20260916-streets/walkability.lua`.
Round 4 moved that file to **`tools/wp13/walkability.lua`** — a gate every round
re-runs belongs beside the other road gates rather than inside one round's
evidence — and gave it the two run-spec fields the seam hands a run. It is the
same programme; a tree that carries neither field still builds the road it used
to, which is what keeps it able to measure `main`.
