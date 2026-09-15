# Evidence: Lethariel, the elf capital (2026-09-15)

The increment record is
[docs/research/wp13-lethariel.md](../../../../docs/research/wp13-lethariel.md).
Everything here was taken on branch `wp13-w2-lethariel`, based on `main` at
`922bfd92`.

| File | What it is | How to re-take it |
| --- | --- | --- |
| `kat.txt` | the acceptance KAT's own seven rows | `luajit -e 'io.write(dofile("tools/wp13/lethariel_kat.lua")("."))'` |
| `micro-luajit.tsv`, `micro-puc51.tsv` | the whole WP13 fixture set in one process under each interpreter; the two are byte-identical | `luajit tools/wp13/final_micro.lua . <out> luajit` and `tools/bin/lua51 tools/wp13/final_micro.lua . <out> puc51` |
| `lots.txt` | all 44 lots against the lot predicate on ALL NINE seeds | `luajit tools/wp13/lethariel_plots.lua .` |
| `shore.txt` | the mere: the water columns of the civic pad and the zero the composition writes on, on all nine seeds | `luajit tools/wp13/lethariel_plots.lua . --shore` |
| `edge.txt` | the grove edge's water spans, per run and per seed | `luajit tools/wp13/lethariel_plots.lua . --edge` |
| `seeds.txt` | the anchor and the root of anchor_009 on the nine seeds, and whether a root lands on a mapchunk edge | `luajit tools/wp13/lethariel_plots.lua . --seeds` |
| `identity.txt` | the files this package changed against `main`, and the identity digests of every settlement the integration fixture prints | `git diff --name-only 922bfd92` and `luajit -e 'io.write(dofile("tools/wp13/integration_fixture.lua")("."))'` |
| `files.sha256` | the sources this package added or changed | `sha256sum` over the list in `identity.txt` |
| `probe-<seed>.txt` | the engine pass's own log lines: build times, per-mapchunk timings, the socket inventory and the read-back digests | `tools/wp13/run_capital.sh <out> lethariel full <seed>` |
| `npcs-<seed>.txt` | every NPC the placement engine put on a socket | the same pass |
| `overlay-digests-<seed>.txt` | the built geometry the probe read back out of the map, as the runner wrote it | the same pass |
| `static.sh`, `static.txt` | parser, SETGLOBAL, the five plain-5.1 sweeps and the fresh-server audit | `bash tools/wp13/evidence/20260915-lethariel/static.sh` |
| `renders/` | the capital as built, drawn by `tools/wp13/render_blueprint.py` from TSVs the probe read back OUT OF THE FINISHED MAP on seed 531802985935182545 | `renders/tsv/*.tsv` are those dumps |

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
| `avenue.png` | **the picture this package exists for**: the north avenue leaves the civic core, walks down the terraces and runs out across the mere as a lamp-lit causeway to the far shore |

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

## The `full` passes exit 1, and why that is not a failure

`run_capital.sh`'s digest loop walks `for label in avenue rampart gate` and
assigns `digest="$(grep -o ... )"`. An OPEN capital publishes no rampart and no
gate, so the second iteration's `grep` finds nothing, exits 1, and the script's
own `set -euo pipefail` ends the run — after the avenue digest has been written
and before the final `PASS` line. The `surface` passes, which never reach that
loop, all exit 0. It is open point 1 of the record and a one-line fix in a file
this lane does not own.
