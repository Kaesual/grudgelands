# WP13 round 3, lane 1: capital terrain

Evidence for [docs/research/wp13-capital-terrain.md](../../../../docs/research/wp13-capital-terrain.md),
taken on branch `wp13-r3-terrain`, rebased onto `main` at `658b6763`
(after lane 2's floating-bushes fix and lane 3's lane/route crossing rule),
2026-09-15.

Two playtest findings, both terrain, both WP40's:

1. the capital terrace risers were vertical, so every terrace edge was a wall a
   player cannot climb (jump height 1);
2. a capital's whole graded envelope resolved to `default:stone`, so all six
   looked like the same slab.

## What is here, and what re-runs it

| Path | What | How to re-run |
| --- | --- | --- |
| `static.txt` | plain-5.1 parser, SETGLOBAL counts, the five sweeps, the fresh-server audit | `./static.sh` |
| `final-micro/` | the interpreter pair over every WP13 fixture, the six-start terrain fixture, the six-capital walkability fixture, and the two byte-identity proofs for the starts | `./final-micro.sh` |
| `fields/after-<capital>-<seed>.tsv` | the pure final height and land class of every column of the ±250 envelope, on this branch | `tools/wp13/run_highcourt.sh <out> field <seed>` / `tools/wp13/run_capital.sh <out> dur_brannoc field <seed>` |
| `fields/before-<capital>-<seed>.tsv` | the same on `main` at 19abee02 | the same runners from a `main` checkout |
| `measurements/walkability.txt` | the before/after/natural tables of the research note | `./measure.sh` |
| `measurements/plot-legality-*.txt` | the 36 Highcourt lots and the 9 Dur Brannoc plots against both gate seeds. `-unrepaired` is main's committed lot grid on THIS branch's terrain, which is the three failures; `-after` is the repaired grid, and `-before` is the repaired grid on main's terrain, which shows the three moves cost nothing on the old ground either | `./measure.sh`, plus main's own `highcourt_plots.lua` for the unrepaired row |
| `highcourt/avenue-digest-<seed>.txt`, `dur_brannoc/<label>-digest-<seed>.txt` | the built road, rampart and gate overlays as READ BACK OUT OF THE FINISHED MAP; `run_highcourt.sh` and `run_capital.sh` gate against these | see "The values that are not frozen forever" |
| `engine/<capital>-<seed>/` | one isolated headless boot per capital per gate seed: the probe log, the error counts, the plot surface report, the per-mapchunk timings | `tools/wp13/run_highcourt.sh <out> full <seed>`, `tools/wp13/run_capital.sh <out> dur_brannoc full <seed>` |
| `renders/` | the terraces from above and in section, before and after; the built ground of each capital's east avenue strip, before and after | `./renders.sh <after engine dir> <before engine dir>` |
| `ground-census.txt` | the node census of those built strips, which is the "no longer a stone slab" evidence | `./renders.sh` writes it |
| `files.sha256` | the frozen-byte manifest of every input and every artefact | `./files.sha256.sh` |

## The values that are not frozen forever

`highcourt/avenue-digest-<seed>.txt` and `dur_brannoc/{avenue,rampart,gate}-digest-<seed>.txt`
are the built overlays, and WP40 terrain changes move the ground they follow.
They are "look at what moved and say why" gates, not constants. **This package
moved all of them on purpose**: every capital terrace riser became a band of
one-block ground steps, so the surface the avenue, the ring street and the
curtain wall are laid on moved with it.

The expectation file lives with the lane that last CHANGED the ground, which is
why `run_highcourt.sh` and `run_capital.sh` now read them from here rather than
from `20260915-highcourt-districts/` and `20260915-dur-brannoc/`.

## The review round, and what it changed

The first version of this package was reviewed and two of its claims were
wrong. Both are fixed here and the evidence for both is in
`measurements/`:

* **The band's quantiser was not translation invariant.** `round_ratio` rounds
  half away from zero, so for an even divisor the lattice bin around zero is one
  node narrower than the rest, and the band built on it emitted a two-node step
  on a plain one-node-per-column ramp for step 2 and step 4.
  `measurements/band-bound.txt` is the exhaustive one-dimensional sweep that
  finds it and that proves the fixed operator's bound; `measurements/phase-*`
  and `measurements/relief-attribution.txt` are the real-capital measurements.
  Highcourt's worst 4-neighbour rise goes back from 5 to 4 (main's value) and
  its ±250 residue from 12 to 6 per mille.
* **The residue is not "the ground's own rock".** Measured column by column
  against the ungraded relief, 59.5 % of Dur Brannoc's residual unclimbable
  columns sit where the relief itself steps at most one node. The fixture header
  and the note say so now.

The fixture also measured only three of a column's four neighbours (never −z);
it measures four and every ceiling was re-taken against that.

## What was already red before this lane, and stays that way

Three things this package did NOT break and did NOT fix:

* **`tools/wp40/run_simple_map_r5.sh` cannot start.** Its preflight refuses the
  tree with `disabled R5 source contains activation API` — R7 shipped and
  enabled the mapgen the R5 preflight still expects to be disabled. Measured on
  `main` at 19abee02, not on this branch.
* **The frozen seed-0 zones canonical KAT is historical, not live.** The value
  the R4/R5 lineage carries (`tools/wp40/simple_map_r5_common.lua`,
  `docs/research/wp40-simple-map-r{4,5}-artifact.tsv`) is
  `8b5145180d…b9b8aa`. The same digest computed on `main` at 19abee02 is
  `ec6dcc3151…92a554`, and on this branch it is `9ea1e861e8…0b5b4d`. It had
  therefore already moved away from the frozen value before this lane touched
  anything; it is a record of the accepted R4 implementation commit
  `9486891`, not a gate anyone has been maintaining. It is **not re-frozen
  here** — that is a WP40 decision with its own provenance, not a side effect of
  a WP13 lane. The two measurements are in `measurements/zones-seed0.txt`.
* **`tools/wp40/r6/micro_kat.lua` "short-vein witness differs"** was already red
  on `main` before this lane, as the brief records.
  `measurements/wp40-r6-micro-kat.txt` carries both runs.
* **`tools/wp40/quality/final_micro.sh` stops at `grug_traders/vendors.lua:290,
  attempt to call field 'noncombatant'`** on `main` and on this branch, at the
  same fixture and with byte-identical rows before it
  (`measurements/wp40-quality-micro-*`). It arrived with `19abee02`, the socket
  contract extension, not with this lane. What this lane DID move in that
  runner is `tools/wp40/planner_throughput/fixture.lua`, whose dry-anchor
  witness asserted that `anchor_007` may not keep its biome surface; anchors
  1..12 may now, 13 and up may not, and the fixture says so.

## Engine isolation

Every boot went through `tools/wp13/run_highcourt.sh` or
`tools/wp13/run_capital.sh`: a fresh `mktemp -d` directory as `LUANTI_USER_PATH`
and as every XDG directory, the log inside it, a `timeout --kill-after`, a kill
scoped to this run's own world path, and the scratch directory removed on exit.
Ports 31001-31042 (this lane's block is 31000-31099); the one `main` baseline
capital boot used 31399, which was measured free first, because
`run_capital.sh` on the pre-rebase `main` still refused anything outside
31300-31399. That guard is now `31000-31999` on main (lane 3), and this branch
takes main's side of it unchanged.
Nothing under the user's personal Flatpak folder was touched and no
`luanti.bin --server` process belonging to these runs survives them.
