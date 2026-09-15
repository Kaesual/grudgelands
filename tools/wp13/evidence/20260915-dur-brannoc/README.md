# WP13 Dur Brannoc — evidence, 2026-09-15

Record: [`docs/research/wp13-dur-brannoc.md`](../../../../docs/research/wp13-dur-brannoc.md).

| Path | What |
| --- | --- |
| `static.sh` / `static.txt` | `luac51 -p`, SETGLOBAL per touched file and tree-wide, the five plain-5.1 sweeps, the fresh-server audit |
| `identity.sh` / `identity.txt` | what this package did NOT move: the six start blueprint identities, and `library_kat` / `blueprint_kat` / `highcourt_kat` byte-identical on this tree and on a `git archive` of `main` at `9e22b0d` |
| `final-micro.sh` / `final-micro/` | the one bounded final-byte process: every WP13 fixture under LuaJIT and under PUC 5.1, inputs hashed before and after, the two outputs byte-identical |
| `timing.sh` / `timing.txt` | build time of the capital and of the seam, three runs under each interpreter, with Highcourt's own row on the same tree for comparison |
| `terrain/wall-<seed>.tsv` | the ground under the four candidate curtain-wall lines, every column, lane by lane across the wall's thickness, both gate seeds |
| `terrain/grid-<seed>.tsv` | a 4-node grid of the whole 512 envelope plus its collar, both seeds |
| `terrain/probe-<seed>.txt` | the `terrain` probe's own summary: range, worst step and wet columns per line |
| `wall-legality.txt` | the verdict of `tools/wp13/capital_wall.lua`: every line dry, stepping no more than a terrace, four courses of face overlap on both worlds, and the corner step measured over the same look-around window the wall module uses — zero at seven of the eight corners and one node where `wall_north` meets `wall_west`'s turret on the user seed, which the turret's three-course opening walks |
| `surface/surface-<seed>.tsv` | the surface and the submerged column count under every district plot footprint, both seeds |
| `surface/scan-<seed>.tsv` | the full candidate sweep the four plot moves were decided from |
| `surface/plot-legality.txt` | the verdict of `tools/wp13/capital_plots.lua` on the committed positions |
| `dur_brannoc/probe-<seed>.txt` | the engine pass: per-mapchunk timings by kind, the socket inventory, the dump counts and digests |
| `dur_brannoc/npcs-<seed>.txt` | every placement line of that boot |
| `dur_brannoc/{avenue,rampart,gate}-digest-<seed>.txt` | the SHA-256 of the road, a stretch of curtain and the east gatehouse as read back out of the finished map, which `run_capital.sh` compares on every full pass |
| `dur_brannoc/harness.sha256` | the probe and runner bytes those passes ran |
| `renders/*.png` | Dur Brannoc as built in terrain, drawn from the map read-back |
| `renders/tsv/*.tsv` | the read-back dumps themselves, anchor-relative, the renderer's input |
| `files.sha256` / `files.sha256.sh` | the frozen-byte manifest of every input and every artefact |

Reproducing, from the repository root:

```sh
bash tools/wp13/evidence/20260915-dur-brannoc/static.sh
bash tools/wp13/evidence/20260915-dur-brannoc/final-micro.sh
bash tools/wp13/evidence/20260915-dur-brannoc/timing.sh

# The ground, before any composition is designed against it. `terrain` is the
# one probe mode that runs against a capital the roster does not carry yet.
WP13_CAPITAL_PORT=31301 WP13_CAPITAL_RACE=dwarf bash tools/wp13/run_capital.sh \
    /tmp/wp13-db-terrain-a dur_brannoc terrain 531802985935182545
WP13_CAPITAL_PORT=31302 WP13_CAPITAL_RACE=dwarf bash tools/wp13/run_capital.sh \
    /tmp/wp13-db-terrain-b dur_brannoc terrain 8675309
luajit tools/wp13/capital_wall.lua . dur_brannoc \
    /tmp/wp13-db-terrain-a/dur_brannoc-wall.tsv \
    /tmp/wp13-db-terrain-b/dur_brannoc-wall.tsv

# Where the district plots may stand.
WP13_CAPITAL_PORT=31303 bash tools/wp13/run_capital.sh \
    /tmp/wp13-db-scan-a dur_brannoc scan 531802985935182545
WP13_CAPITAL_PORT=31304 bash tools/wp13/run_capital.sh \
    /tmp/wp13-db-scan-b dur_brannoc scan 8675309
luajit tools/wp13/capital_plots.lua . dur_brannoc \
    /tmp/wp13-db-scan-a/dur_brannoc-scan.tsv \
    /tmp/wp13-db-scan-b/dur_brannoc-scan.tsv

# The capital in the world, both gate seeds, with the built-geometry gate.
WP13_CAPITAL_PORT=31305 bash tools/wp13/run_capital.sh \
    /tmp/wp13-db-full-a dur_brannoc full 531802985935182545
WP13_CAPITAL_PORT=31306 bash tools/wp13/run_capital.sh \
    /tmp/wp13-db-full-b dur_brannoc full 8675309
bash tools/wp13/evidence/20260915-dur-brannoc/renders.sh
```

Isolation, for every engine line above: a fresh scratch directory as
`LUANTI_USER_PATH` and as every XDG directory, the log inside it, a
`timeout --kill-after`, only this run's own server killed, ports restricted to
31300–31399, and nothing under the user's personal Flatpak folder touched.
