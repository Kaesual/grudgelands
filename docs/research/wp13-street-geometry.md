# WP13 — one street rule for all six capitals (2026-09-16)

Wave 3, Lane S. Branch `wp13-w3-streets`, off `main` at `f37a0c5b`.

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

computed from the same `surface` callback, over the same `reach` window, by the
same two sweeps. Two runs that never see each other therefore compute the
identical J. It is applied as a **ground floor**, and that is what makes the
approaches right for free: raising the square's ground to J lifts the envelope on
both sides a node at a time, and over the square the envelope is J exactly —
every column of it is at J, and no column outside it can push one above J,
because J is already at or above the bare envelope there.

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
route's own piers under the middle of it and nothing under the edges. That is the
0..5 solid columns a seed in the table above.

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
4. **The KAT's own coverage.** Five mutations, one per ruling, each caught by that
   ruling's own section — `tools/wp13/evidence/20260916-streets/mutation.txt`.

## 8. What is open

* **Lethariel's district lanes overlap its ring street.** Six pairs, up to 97
  columns each, three of the five lanes of each the same columns: `ring_west` at
  x = −96 and `lane_northwest_spine` at x = −98 are two streets two nodes apart,
  which is one street. That is a composition defect and not a street-geometry
  one — moving a lane's centre line moves the plots that stand along it — so it
  is **measured, pinned and reported, not fixed here**
  (`street_kat.lua` section 8 pins the inventory; the other sixteen parallel
  overlaps in the tree are butt joints of one column, where two collinear runs
  meet end to end, and those need nothing).
* **The gate-arrival ramp is still Kezamba's alone.** `kezamba_ramp.lua` brings an
  avenue down to its gate point at free-terrain height (contract §2.1.1); the
  other five capitals rely on their terrain being gentler there, and Nhal Veyr
  has its own `gate_road`. Generalising the one rule
  `T(p) = min(D(p), g + |p − gate|)` into `avenue.lua` would retire two
  per-capital post-processes. Not done here; it is a separate rule from the five
  rulings.
* **Junctions that are close but disjoint** — see §3.

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

## 10. Files

| file | what changed |
| --- | --- |
| `mods/MAPGEN/grug_mapgen/wp13/avenue.lua` | the five rulings; the road-wide envelope, the plateau, the viaduct, the bridge, the lamp rule |
| `mods/MAPGEN/grug_mapgen/wp13/street_plan.lua` | **new** — the junction squares of a capital, from the run rectangles |
| `mods/MAPGEN/grug_mapgen/wp13/elf_bridge.lua` | **removed** — the bridge is every capital's now |
| `mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua` | append-only: `wet(x, z)` at the overlay seam, and the junctions travelling with a run |
| the six compositions | append-only: the junction attachment in `overlay_runs`; the four private kerb parapets and Lethariel's water plan removed |
| `tools/wp13/street_geometry.lua` | **new** — the measurement |
| `tools/wp13/street_kat.lua` | **new** — the property, eight sections, both interpreters |
| six existing KATs + the integration fixture | they asserted the road this replaces |
| `tools/wp13/evidence/20260916-streets/` | the evidence |
