# WP13: Highcourt's other three districts, and the quadrant permutation

Evidence for `docs/research/wp13-highcourt-districts.md`, taken on `main` at
`9e22b0d` on 2026-09-15.

## What is here, and what re-runs it

| Path | What | How to re-run |
| --- | --- | --- |
| `static.txt` | plain-5.1 parser, SETGLOBAL counts, the five sweeps, the fresh-server audit | `./static.sh` |
| `final-micro/` | the interpreter pair over every WP13 fixture, with the input set hashed before and after | `./final-micro.sh` |
| `timing.txt` | build time under both interpreters, three runs each; every blueprint identity the capital publishes; the six start identities | `./timing.sh` |
| `plots.txt` | the 36 lots against the terrain of both gate seeds, and the derivation that produces the committed grids | `./plots.sh` |
| `highcourt/field-<seed>.tsv` | the pure final height and the land/water class of every column of the ±250 envelope, per gate seed | `tools/wp13/run_highcourt.sh <out> field <seed>` (~20 s, no mapchunk emerged) |
| `highcourt/avenue-digest-<seed>.txt` | the digest of the road as READ BACK OUT OF THE FINISHED MAP, per gate seed; `run_highcourt.sh` gates against these | see below |
| `engine-user-seed/`, `engine-boundary-seed/` | one isolated headless boot per gate seed: the probe log, the NPC placement log, the error counts, the plot surface report | `tools/wp13/run_highcourt.sh <out> full <seed>` (~95 s) |
| `renders/` | 46 pictures: every plot from its composition, the whole capital per seed, and four plots plus the avenue as built | `./renders.sh <engine output dir>` |
| `files.sha256` | the frozen-byte manifest of every input and every artefact | `./files.sha256.sh` |

## The one thing that is not frozen forever

`highcourt/avenue-digest-<seed>.txt` is the built road, and WP40 terrain
changes move the ground the road follows. It is a "look at what moved and say
why" gate, not a constant. This package moved it on purpose: the avenue
overlay's run list gained the seven district lanes.

The expectation file lives with the lane that last CHANGED the road, which is
why `run_highcourt.sh` reads it from here rather than from
`20260915-seam-generalisation/`.

## Engine isolation

Every boot went through `tools/wp13/run_highcourt.sh`: a fresh `mktemp -d`
directory as `LUANTI_USER_PATH` and as every XDG directory, the log inside it, a
`timeout --kill-after`, a kill scoped to this run's own world path, and the
scratch directory removed on exit. Ports 31200-31299. Nothing under the user's
personal Flatpak folder was touched, and no `luanti.bin --server` process
belonging to these runs survives them.
