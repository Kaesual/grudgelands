# WP13 Nhal Veyr — evidence, 2026-09-15

Record: [`docs/research/wp13-nhal_veyr.md`](../../../../docs/research/wp13-nhal_veyr.md).

Tree: branch `wp13-w2-nhal-veyr`, rebased onto `main` at `f5583e13`
(Lane N's wave-2 vendor entities, Lane R's routes ending at the capital
gates, and Lane D's Dur Brannoc upgrade with the seeded quadrant
assignment in the probe).

| Path | What |
| --- | --- |
| `static.sh` / `static.txt` | `luac51 -p` and the SETGLOBAL count per touched file and tree-wide, the five plain-5.1 sweeps scoped and tree-wide, the fresh-server audit |
| `identity.sh` / `identity.txt` | what this package did NOT move: the six start blueprint identities and `library_kat` / `blueprint_kat` / `highcourt_kat` / `dur_brannoc_kat`, byte-identical on this tree and on an export of `main` at `f5583e13`, the corner reconciliation included |
| `final-micro.sh` / `final-micro/` | the one bounded final-byte process: every WP13 fixture under LuaJIT and under PUC 5.1, the two outputs byte-identical |
| `timing.lua` / `timing.txt` | build time of the capital and of the seam, three runs under each interpreter. It is HERE and not in `tools/wp13/capital_timing.lua` because that harness reads `capital.district.plots` — one district — and builds the road with the dwarf palette; see the record's open point 2 |
| `terrain/grid-<seed>.tsv` | a 4-node grid of the whole 512 envelope plus its collar, ALL NINE seeds |
| `terrain/wall-<seed>.tsv` | the ground under the four candidate curtain-wall lines, every column, lane by lane across the wall's thickness, all nine seeds |
| `terrain/probe-<seed>.txt` | the `terrain` probe's own summary: range, worst step and wet columns per line |
| `terrain/calibration.txt` | how much 4-node sampling understates a relief, measured against the 1-node wall lines of the same dumps: a fall by at most one node and a rise by at most two |
| `lots.sh`, `lot-legality.txt` | the verdict of `tools/wp13/nhal_veyr_plots.lua` on the committed grids over ALL NINE seeds: every lot dry, inside the skirt, under its own roof and inside its own quarter on every world, and every plot fitting the lot it stands on |
| `lot-repair.txt` | the `--repair` run the committed grids came from — 43 of the 52 lots moved when the rule went from two seeds to nine |
| `terrain_all.sh` | the terrain pass on all nine seeds, which is the input of both predicates |
| `wall_all.sh`, `wall-legality.txt` | `tools/wp13/capital_wall.lua` over the nine seeds as eight pairs: water, the step along each line, the face overlap, the gate, and the CORNER STEP |
| `wall-across-capitals.txt` | the same predicate on Dur Brannoc and Highcourt over the two gate seeds, for the comparison the corner finding rests on |
| `gates.sh`, `gates/` | Lane R's own acceptance, `tools/wp13/route_gates.lua --strict`, over all nine fixture seeds: where each of the 24 incoming routes ends, the step between the route's graded surface and the BUILT avenue at each gate point, the walk in from 64 nodes outside, and the ground just inside the gate. `route_faults=0 city_faults=0` on every seed |
| `corners/` | the corner reconciliation's own proof: every cell of all four wall runs of Highcourt and Dur Brannoc, built whole out of the real WP40 height session, before (`main` at `f5583e13`) against after, on both gate seeds — plus the classification that says every moved cell is inside a corner's look-around window, and the corner step read off the same dumps |
| `mutations.sh` | does the work-socket rule bite, and does the corner clamp? Four mutations against a tar copy of the tree, never the tree: delete the quarry face, retype a `pray` socket to `mine`, lift the votive lights a course, and disarm `wall.lua` section 1b. All four red |
| `surface_all.sh`, `surface/surface-<seed>.tsv` | the per-plot surface, perimeter fall, rise, submerged columns and margin on ALL NINE seeds of `capital_anchor_fixture.lua` |
| `surface/audit-summary.tsv` | the same nine seeds in one table: the audit findings of all three capitals, the worst perimeter fall and the submerged count |
| `surface/audit-<seed>.txt` | the seam's own load-time `audit_terrain` findings for every settlement on that seed, which is the authority the offline predicate is a pre-flight for |
| `full_runs.sh`, `nhal_veyr/probe-<seed>.txt` | the engine pass: per-mapchunk timings by kind, the socket inventory, the loop inventory, the dump counts and digests |
| `nhal_veyr/npcs-<seed>.txt` | every placement line of that boot, and the roster summary |
| `nhal_veyr/approach.py` / `approach.txt` | how high the avenue stands above its own ground AS BUILT, on the steepest of the four axes and out to the gate point at 261 — the span of every cell in a carriageway column, the road top against the FREE TERRAIN at the gate, the rail, and a hole check. It replaces `embankment.py`, which read the east avenue only, clipped at 240, and counted paving courses instead of fill; the review of 2026-09-16 was right that it could not see the case it was quoted for |
| `nhal_veyr/errors.txt` | the error-line inventory of the three full passes |
| `nhal_veyr/harness.sha256` | the probe and runner bytes those passes ran |
| `errors.sh` | what an engine pass of this capital may log: nothing. It allowed two until the rebase onto Lane N's wave-2 vendor entities (`c8050057`) |
| `renders.sh`, `renders/*.png` | Nhal Veyr as built in terrain, drawn from the map read-back — plus `capital-plan.png` / `capital-plan-night.png`, the WHOLE capital on one flat plane out of `tools/wp13/dump_capital_plan.lua` with this world's own quadrant permutation, `gate-approach*.png` down the north avenue to its gate, and `wall-corner.png` where two runs' walks meet at a corner turret |
| `renders/tsv/*.tsv` | the read-back dumps themselves, anchor-relative, the renderer's input. `nhal_veyr-plan.tsv` is NOT kept here: the whole-capital plan is 21 MB and `renders.sh` regenerates it from `dump_capital_plan.lua` in a second |
| `files.sha256` / `files.sha256.sh` | the frozen-byte manifest of every input and every artefact |

## Reproducing, from the repository root

```sh
bash tools/wp13/evidence/20260915-nhal_veyr/static.sh
bash tools/wp13/evidence/20260915-nhal_veyr/final-micro.sh
luajit tools/wp13/evidence/20260915-nhal_veyr/timing.lua . luajit

# What this package did not move. The second column needs a pristine main.
bash tools/wp13/evidence/20260915-nhal_veyr/identity.sh .

# The ground, before any composition is designed against it, on all nine seeds.
# `terrain` is the one probe mode that runs against a capital the roster does
# not carry yet, and it is the input of both predicates below.
bash tools/wp13/evidence/20260915-nhal_veyr/terrain_all.sh . /tmp/nv-terrain

# Where the lots may stand, and whether the wall survives its own corners.
bash tools/wp13/evidence/20260915-nhal_veyr/lots.sh /tmp/nv-terrain
bash tools/wp13/evidence/20260915-nhal_veyr/wall_all.sh /tmp/nv-terrain

# Whether the gates work at all: the route graph's own acceptance, nine seeds.
bash tools/wp13/evidence/20260915-nhal_veyr/gates.sh /tmp/nv-gates

# Do the rules bite? Four mutations, each against a copy of the tree.
bash tools/wp13/evidence/20260915-nhal_veyr/mutations.sh

# Did the corner reconciliation move anything but a corner? Needs an export of
# the commit it landed on top of; see corners/celldiff.sh's own header.
bash tools/wp13/evidence/20260915-nhal_veyr/corners/celldiff.sh \
    /tmp/wall-before . /tmp/wall-cells

# Every plot on every seed of the anchor fixture, the load-time audit, and then
# the full pass on three seeds with the pictures it produces.
bash tools/wp13/evidence/20260915-nhal_veyr/surface_all.sh . /tmp/nv-surface
bash tools/wp13/evidence/20260915-nhal_veyr/full_runs.sh . /tmp/nv-full \
    531802985935182545 8675309 15912857179583385436
bash tools/wp13/evidence/20260915-nhal_veyr/errors.sh /tmp/nv-full/full-*/server.log
bash tools/wp13/evidence/20260915-nhal_veyr/renders.sh
```

## The one thing to read first

`corners/cell-diff.txt`, and then `wall-legality.txt`.

The wave-2 review's finding was that **the rampart walk BREAKS at the corners**:
`tools/wp13/capital_wall.lua` over the nine seeds reported 24 of 64 corner
measurements at three nodes or more — which is what the predicate fails at
(`CORNER_OPENING = 3`: a step of two or less is what a three-course opening
walks) — and the worst at nine. `wall-across-capitals.txt` is that same
predicate on Dur Brannoc and Highcourt over the two gate seeds, and it is kept
here as the BEFORE record: it is what said the mechanism was `wall.lua`'s and
the severity this capital's ground.

**It is fixed**, in `wp13/wall.lua` section 1b, and `wall-legality.txt` now
reports **step 0 on all 64**. `corners/` is the proof that the two capitals
already shipped moved at their corners and nowhere else: every cell of all four
wall runs of Highcourt and Dur Brannoc, before against after, on both gate
seeds, classified by column. The record's section 3b carries the rule and the
tables; `mutations.sh`'s fourth mutation is the red-without-the-fix.
