# WP13 Nhal Veyr — evidence, 2026-09-15

Record: [`docs/research/wp13-nhal_veyr.md`](../../../../docs/research/wp13-nhal_veyr.md).

Tree: branch `wp13-w2-nhal-veyr`, based on `main` at `922bfd92`.

| Path | What |
| --- | --- |
| `static.sh` / `static.txt` | `luac51 -p` and the SETGLOBAL count per touched file and tree-wide, the five plain-5.1 sweeps scoped and tree-wide, the fresh-server audit |
| `identity.sh` / `identity.txt` | what this package did NOT move: the six start blueprint identities and `library_kat` / `blueprint_kat` / `highcourt_kat` / `dur_brannoc_kat`, byte-identical on this tree and on a `git archive` of `main` at `922bfd92` |
| `final-micro.sh` / `final-micro/` | the one bounded final-byte process: every WP13 fixture under LuaJIT and under PUC 5.1, the two outputs byte-identical |
| `timing.lua` / `timing.txt` | build time of the capital and of the seam, three runs under each interpreter. It is HERE and not in `tools/wp13/capital_timing.lua` because that harness reads `capital.district.plots` — one district — and builds the road with the dwarf palette; see the record's open point 2 |
| `terrain/grid-<seed>.tsv` | a 4-node grid of the whole 512 envelope plus its collar, both gate seeds, taken before the capital was on the roster |
| `terrain/wall-<seed>.tsv` | the ground under the four candidate curtain-wall lines, every column, lane by lane across the wall's thickness |
| `terrain/probe-<seed>.txt` | the `terrain` probe's own summary: range, worst step and wet columns per line |
| `terrain/calibration.txt` | how much 4-node sampling understates a relief, measured against the 1-node wall lines of the same dumps: a fall by at most one node and a rise by at most two |
| `lot-legality.txt` | the verdict of `tools/wp13/nhal_veyr_plots.lua` on the committed grids: every lot dry, inside the skirt, under its own roof and inside its own quarter on both worlds, and every plot fitting the lot it stands on |
| `lot-repair.txt` | the `--repair` run the six moved lots came from |
| `surface_all.sh`, `surface/surface-<seed>.tsv` | the per-plot surface, perimeter fall, rise, submerged columns and margin on ALL NINE seeds of `capital_anchor_fixture.lua` |
| `surface/audit-summary.tsv` | the same nine seeds in one table: the audit findings of all three capitals, the worst perimeter fall and the submerged count |
| `surface/audit-<seed>.txt` | the seam's own load-time `audit_terrain` findings for every settlement on that seed, which is the authority the offline predicate is a pre-flight for |
| `full_runs.sh`, `nhal_veyr/probe-<seed>.txt` | the engine pass: per-mapchunk timings by kind, the socket inventory, the loop inventory, the dump counts and digests |
| `nhal_veyr/npcs-<seed>.txt` | every placement line of that boot, and the roster summary |
| `nhal_veyr/embankment.py` / `embankment.txt` | how high the avenue stands above its own ground as BUILT: every carriageway column outside the core is a single course, which is why this capital needs no causeway parapet |
| `nhal_veyr/errors.txt` | the error-line inventory of the three full passes |
| `nhal_veyr/harness.sha256` | the probe and runner bytes those passes ran |
| `errors.sh` | what an engine pass of this capital may log and nothing else: exactly the two unregistered wave-2 vendor lines |
| `renders.sh`, `renders/*.png` | Nhal Veyr as built in terrain, drawn from the map read-back |
| `renders/tsv/*.tsv` | the read-back dumps themselves, anchor-relative, the renderer's input |
| `files.sha256` / `files.sha256.sh` | the frozen-byte manifest of every input and every artefact |

## Reproducing, from the repository root

```sh
bash tools/wp13/evidence/20260915-nhal_veyr/static.sh
bash tools/wp13/evidence/20260915-nhal_veyr/final-micro.sh
luajit tools/wp13/evidence/20260915-nhal_veyr/timing.lua . luajit

# What this package did not move. The second column needs a pristine main.
bash tools/wp13/evidence/20260915-nhal_veyr/identity.sh .

# The ground, before any composition is designed against it. `terrain` is the
# one probe mode that runs against a capital the roster does not carry yet.
WP13_CAPITAL_PORT=31301 WP13_CAPITAL_RACE=undead bash tools/wp13/run_capital.sh \
    /tmp/nv-terrain-a nhal_veyr terrain 531802985935182545
WP13_CAPITAL_PORT=31302 WP13_CAPITAL_RACE=undead bash tools/wp13/run_capital.sh \
    /tmp/nv-terrain-b nhal_veyr terrain 8675309
luajit tools/wp13/nhal_veyr_plots.lua . \
    /tmp/nv-terrain-a/nhal_veyr-grid.tsv /tmp/nv-terrain-b/nhal_veyr-grid.tsv

# Every plot on every seed of the anchor fixture, and the load-time audit.
bash tools/wp13/evidence/20260915-nhal_veyr/surface_all.sh . /tmp/nv-surface

# The engine pass, and the pictures it produces.
bash tools/wp13/evidence/20260915-nhal_veyr/full_runs.sh . /tmp/nv-full \
    531802985935182545 8675309 15912857179583385436
bash tools/wp13/evidence/20260915-nhal_veyr/errors.sh /tmp/nv-full/full-*/server.log
bash tools/wp13/evidence/20260915-nhal_veyr/renders.sh
```

## The one thing to read first

`run_capital.sh` gates on `errors == 0` and **reports FAILED on every pass of
this capital**, because two of its six profession vendors are WAVE-2 kinds whose
entities `grug_traders` has not registered yet. The sockets contract's section
8.4 says in as many words that such a kind "is an error line at placement and an
empty socket, never a load failure", so that is behaviour and not a defect — but
it means the runner's own verdict is not this package's gate. `errors.sh` is:
it passes only when a log carries exactly those two lines and nothing else.
