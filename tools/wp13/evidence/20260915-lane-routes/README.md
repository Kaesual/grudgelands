# WP13 round 3, lane 3: where a capital's streets meet WP40's routes

Evidence for `docs/research/wp13-lane-routes.md`, taken on `main` at
`19abee02` on 2026-09-15.

The defect: WP40 bridges the rivers that run through a capital's envelope, and
a WP13 street crossing the same river underneath ends up with one or two
blocks of air over it — a street no player can walk, and therefore a street
that dead ends at the route. The ruling (playtest round 3): three blocks of
air and the street passes under unchanged; fewer and the street climbs onto
the route in one-block ground steps and crosses at grade.

## What is here, and what re-runs it

| Path | What | How to re-run |
| --- | --- | --- |
| `static.txt` | plain-5.1 parser, SETGLOBAL counts, the five sweeps, the fresh-server audit, the crossing KAT under both interpreters | `./static.sh` |
| `final-micro/`, `final-micro.txt` | every WP13 fixture once under LuaJIT and once under PUC 5.1, with the input set hashed before and after | `./final-micro.sh` |
| `identity.txt` | the six start identities and the four capital fixtures, this tree against the base commit | `./identity.sh <base checkout>` |
| `crossings/`, `measure.txt` | every column a bridge deck spans on both gate seeds, before and after, plus the run-by-run parity against the base commit | `./measure.sh <base checkout>` |
| `kat/` | the crossing KAT under both interpreters | `luajit -e 'io.write(dofile("tools/wp13/lane_crossing_kat.lua")("."))'` |
| `engine/<when>-<seed>/` | one isolated headless boot per (seed, code state): the probe log, the error counts, the terrain-audit warning count, the avenue road digest, and the crossing regions read back out of the finished map | see below |
| `walk.txt` | the crossings as a walk — the topmost road node of every column along each centre line, and the lamp standards on the ring_north verges before and after, out of those dumps | `./walk.sh` |
| `renders/` | 16 pictures: each crossing, whole and cut, before and after | `./renders.sh <before A> <after A> <before B> <after B>` |
| `files.sha256` | the frozen-byte manifest of every input and every artefact | `./files.sha256.sh` |

`<base checkout>` is a tree of `19abee02`, e.g. `git archive 19abee02 | tar -x
-C /tmp/base` plus a copy of `tools/bin/`.

## The engine passes

Four boots of `tools/wp13/run_highcourt.sh <out> full <seed>`, ports
31200-31299:

| directory | seed | `wp13/avenue.lua` | crossing boxes (anchor-relative) |
| --- | --- | --- | --- |
| `engine/before-A` | 531802985935182545 | `19abee02`'s | `-60,-24,92,100;-64,-36,142,150;-104,-88,26,44` |
| `engine/after-A` | 531802985935182545 | this lane's | the same three |
| `engine/before-B` | 8675309 | `19abee02`'s | `-48,-16,88,102` |
| `engine/after-B` | 8675309 | this lane's | the same one |

Handed to the runner as `WP13_HIGHCOURT_CROSSING`, which this lane added. All
four: exit 0, `errors=0`, `moderror=0`, `complete=1`, zero `audit_terrain`
warnings, and the committed `avenue_road_digest` matching for both seeds (the
east avenue is not a run a route spans).

The three boxes are, in order: the ring street's north side over `route_006`;
the north-west district lane over the same route; and the ring street's west
side under `route_021`, which already had exactly three blocks of air and is
the control — it must NOT move.

## The headline numbers

| | seed 531802985935182545 | seed 8675309 |
| --- | --- | --- |
| carriageway columns a deck spans | 110 | 1 |
| illegal before (fewer than 3 blocks of air, not at grade) | 17 | 1 |
| illegal after | 0 | 0 |
| at grade after | 72 | 1 |
| passing under after | 38 | 0 |
| overlay runs byte-identical to the base commit's | 21 of 23 | 22 of 23 |
| lamp standards lighting from under the road they light | 0 | 0 |
| piece cuts checked against the whole run | 49 | 3 |
| cut differences | 0 | 0 |

Dur Brannoc has no deck over any of its twelve overlay runs on either seed and
is byte-identical throughout.

## Engine isolation

Every boot went through `tools/wp13/run_highcourt.sh`: a fresh `mktemp -d`
directory as `LUANTI_USER_PATH` and as every XDG directory, the log inside it,
a `timeout --kill-after`, a kill scoped to this run's own world path, and the
scratch directory removed on exit. Ports 31210-31217 (the `after-*` pair was re-run on 31216/31217 after the review's lamp fix). Nothing under the user's
personal Flatpak folder was touched, and no `luanti.bin --server` process
belonging to these runs survives them.
