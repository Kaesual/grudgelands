# Evidence: Lethariel, the elf capital (2026-09-15)

The increment record is
[docs/research/wp13-lethariel.md](../../../../docs/research/wp13-lethariel.md).
Everything here was taken on branch `wp13-w2-lethariel`, rebased onto `main` at
**`f5583e13`** ("Merge the Dur Brannoc upgrade to the Highcourt standard" — Lane
N's vendor entities, Lane R's routes ending at the capital gates, Lane D's
`run_capital.sh` fixes). It was first taken on `922bfd92` and then on
`c8050057`.

| File | What it is | How to re-take it |
| --- | --- | --- |
| `kat.txt` | the acceptance KAT's own nine rows; byte-identical under both interpreters | `luajit -e 'io.write(dofile("tools/wp13/lethariel_kat.lua")("."))'` and the same with `tools/bin/lua51` |
| `routes.txt` | **the rebase's headline**: the four gate points of `source.capital_gates` against the level the SHIPPED composition builds its centre lane at, plus the 64-node walk in — 36 pairs, worst step 0 | `luajit tools/wp13/lethariel_plots.lua . --routes` |
| `route-gates-strict.txt` | Lane R's own tool, `--strict`, on the nine fixture seeds and on seed 7: every Lethariel row clean, the nine faults all Nhal Veyr's | `luajit tools/wp13/route_gates.lua . <seed> --strict` |
| `micro-luajit.tsv`, `micro-puc51.tsv` | the whole WP13 fixture set in one process under each interpreter; the two are byte-identical | `luajit tools/wp13/final_micro.lua . <out> luajit` and `tools/bin/lua51 tools/wp13/final_micro.lua . <out> puc51` |
| `lots.txt` | all 44 lots against the lot predicate on ALL NINE seeds | `luajit tools/wp13/lethariel_plots.lua .` |
| `shore.txt` | the mere: the water columns of the civic pad and the zero the composition writes on, on all nine seeds | `luajit tools/wp13/lethariel_plots.lua . --shore` |
| `edge.txt` | the grove edge's water spans, per run and per seed | `luajit tools/wp13/lethariel_plots.lua . --edge` |
| `gates.txt` | **the fix round's headline**: the air each of the four thresholds leaves over the ROAD it spans, on all nine seeds — 36 values, worst 3 against a `MIN_CLEAR` of 3 | `luajit tools/wp13/lethariel_plots.lua . --gates` |
| `water.txt` | the wet span of every overlay run, per seed; the table `wp13/lethariel.lua` commits | `luajit tools/wp13/lethariel_plots.lua . --water` |
| `bodies.txt` | **the other headline**: the mere's connected bodies before and after the crossings — 2 and 2, with 152 columns paved and **0 cleared to air** | `luajit tools/wp13/lethariel_plots.lua . --bodies` |
| `census.txt` | legal lot positions per quarter, at both reaches, on nine seeds; section 3.1 of the note | `luajit tools/wp13/lethariel_plots.lua . --census [reach]` |
| `mapcheck.py`, `built-map-<seed>.txt` | what the BUILT MAP says about the east threshold's clearance and the water under the bridge: 368 carriageway columns over the lake, 368 open water at the surface, 0 solid, 0 holes | `python3 .../mapcheck.py <run output dir>` |
| `seeds.txt` | the anchor and the root of anchor_009 on the nine fixture seeds AND on seed 7, the edge-coverage seed whose root does land on a mapchunk's lowest layer | `luajit tools/wp13/lethariel_plots.lua . --seeds` |
| `identity.txt` | the files this package changed against `main`, and the identity digests of every settlement the integration fixture prints — every one but this capital byte-identical to `f5583e13`'s own | `git diff --name-only f5583e13` and `luajit -e 'io.write(dofile("tools/wp13/integration_fixture.lua")("."))'` |
| `files.sha256` | the sources this package added or changed | `sha256sum` over the list in `identity.txt` |
| `probe-<seed>.txt` | the engine pass's own log lines: build times, per-mapchunk timings, the socket inventory and the read-back digests | `tools/wp13/run_capital.sh <out> lethariel full <seed>` |
| `npcs-<seed>.txt` | every NPC the placement engine put on a socket | the same pass |
| `overlay-digests-<seed>.txt` | the built geometry the probe read back out of the map, as the runner wrote it | the same pass |
| `static.sh`, `static.txt` | parser, SETGLOBAL, the five plain-5.1 sweeps and the fresh-server audit | `bash tools/wp13/evidence/20260915-lethariel/static.sh` |
| `renders/` | the capital as built, drawn by `tools/wp13/render_blueprint.py` from TSVs the probe read back OUT OF THE FINISHED MAP on seed 531802985935182545 | `renders/tsv/*.tsv` are those dumps |
| `renders/capital-plan.png` | the exception: the whole capital as a PLAN, off the composition rather than the map. Its TSV is 21 MB and is not committed | `luajit tools/wp13/dump_capital_plan.lua . lethariel 531802985935182545 > plan.tsv` then `python3 tools/wp13/render_blueprint.py plan.tsv --scale 4 --max-pixels 4600 -o capital-plan.png` |

## The renders

| File | What |
| --- | --- |
| `core-overview.png` | the whole civic core — the picture to look at first. The pad stops at the mere on its north-east diagonal |
| `core-sw.png` | the same from the other diagonal |
| `core-night.png` | the lantern walks at night |
| `quay.png` | the marble quay along the mere and the head of the causeway |
| `kings-hall.png` | the Hall of the Silver Boughs and the throne approach |
| `sacred-grove.png` | the standing silverwood inside the civic core, with the shrine on its walk |
| `plot.png` | one district plot as built on its own terrace |
| `capital-plan.png` | **the whole capital on one flat plane**, drawn from `tools/wp13/dump_capital_plan.lua` with the SEEDED quarter assignment of 531802985935182545: the civic core, the four quarters round the ring street, the four avenues out to their thresholds and the hedge edge round the whole envelope |
| `avenue.png` | **the picture this package exists for**: the east avenue leaves the civic core, walks down the terraces, crosses the mere on the bridge and arrives at its threshold |
| `bridge.png` | the road over the mere as it ships: a railed deck on marble piers, water on both sides and under it |
| `bridge-piers.png` | the same span CUT AT THE WATER LINE: two rows of pier tops on the verges, and unbroken water everywhere between them — the ruling, as a picture |

The three re-taken on the fixed tree, from `renders/tsv/lethariel-avenue.tsv`:
`--region 40 -12 260 12 --scale 10` (avenue), `--region 140 -14 240 14 --scale
14` (bridge), `--region 170 -12 215 12 --ymax -6 --ymin -10 --scale 22`
(bridge-piers, the cut at the water line).
| `gate-east.png` | the east threshold — six marble pillars and the road running clear between them. The probe's dump box ends one node under the lintel course, so the pillars' top is what the picture shows; `built-map-531802985935182545.txt` has the number |

## Nine seeds

The coordinator's wave-2 rule. `full` on the two gate seeds and the user's seed;
`surface` on the other six, which is a cold boot each and is what runs the
seam's load-time `audit_terrain` against that world and samples every plot on
it. All nine report `exit=0 errors=0 complete=1`, **zero Lethariel findings**
and no submerged plot column.

Two of the nine logs carry ONE audit warning each, and neither is this
capital's: `WP13 highcourt: the plot martial_wood_yard ... rise 10 against a
clear of 8` on 15912857179583385436, and `WP13 highcourt: the plot
homes_kitchen_garden ... perimeter fall 8 against a skirt of 6` on seed 0.
Highcourt's lots were derived on two seeds; these are two of the seven it was
never asked about. Reported, not fixed — they are not this lane's files.

## The older `full` passes exit 1, and why that was not a failure

`run_capital.sh`'s digest loop walked `for label in avenue rampart gate` and
assigned `digest="$(grep -o ... )"`. An OPEN capital publishes no rampart and no
gate, so the second iteration's `grep` found nothing, exited 1, and the script's
own `set -euo pipefail` ended the run — after the avenue digest had been written
and before the final `PASS` line. The `surface` passes, which never reach that
loop, all exited 0.

**Lane D fixed it in `f5583e13`.** The pass this package ships on that tree ends:

```
exit=0 errors=0 complete=1
avenue overlay digest recorded (no committed value for seed 531802985935182545 yet)
rampart: this capital publishes no such overlay region
gate: this capital publishes no such overlay region
WP13 capital pass PASS: lethariel full /tmp/grug-w2-leth-r2
```

The `probe-*.txt`, `npcs-*.txt`, `overlay-digests-*.txt`, `built-map-*.txt` and
`renders/tsv/*.tsv` for seed 531802985935182545 are from that pass; the ones for
seeds 7, 42, 8675309 and 15912857179583385436 predate the rebase and are judged
from their own logs.
