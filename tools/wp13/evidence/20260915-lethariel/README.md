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
| `engine-errors-<seed>.txt` | the four EXPECTED error lines: the wave-2 vendor kinds whose entities the traders mod has not registered yet (sockets contract section 8.4) | the same pass |
| `overlay-digests.txt` | the built road and core geometry the probe read back out of the map, and why the runner never compares them | see the file |
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

## The engine pass exits 1, and why that is not a failure

`run_capital.sh`'s gate is `grep -c 'ERROR\|ModError'`. Lethariel places four
WAVE-2 vendor kinds — `bowyer`, `armourer`, `herbalist`, `brewer` — whose
entities the traders mod has not registered yet, and the sockets contract's
section 8.4 says in as many words that such a kind "is an error line at
placement and an empty socket, never a load failure". The four lines are in
`engine-errors-<seed>.txt`; `exit=0 complete=1` and a terrain audit with no
finding are in `probe-<seed>.txt`. The runner cannot tell the two apart; that
is open point 1 of the record.
