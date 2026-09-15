# Evidence: WP40's routes end at the capital gates (WP13 wave 2, lane R)

Playtest round 4, 2026-09-15. The user's ruling: **every incoming route ends at
a planned point of the city boundary (a gate) and no longer runs into the
interior; inside, the WP13 streets take over.**

What shipped and why is [docs/research/wp13-route-gates.md](../../../../docs/research/wp13-route-gates.md);
the ruling is folded into the capitals contract as §2.1.1.

Base: main `c8050057` (rebased from `922bfd92` after the review of
2026-09-16). Branch: `wp13-w2-routes`. Ports 31000-31099, one headless server at
a time, every engine and measurement run under `nice -n 19`.

`tools/wp13/route_gates.lua` **exits 0 on all nine seeds** in its default mode
(`sweep/after-progress.txt`): that mode gates the ROUTE GRAPH, which is this
lane's. `--strict` adds the capital-terrain questions and exits 1 on five of the
nine, all of them Nhal Veyr's north gate, which is lane U's (research note §5).

## What is here

| path | what |
| --- | --- |
| `dur-brannoc-south-gate-user-seed.png` | **the user's own finding, before and after**, on the user's world seed 15912857179583385436: the road crossing the wall 47 nodes west of the gate, beside the road ending in the gate passage |
| `dur-brannoc-gates-user-seed.png` | the same capital, the whole 512 envelope and 300 nodes around it |
| `feature_map.lua` | dumps the WP40 functional feature of every column of a box; the renderer's input |
| `render_gate_approach.py` | draws one or more of those as a plan, coloured by who owns each column |
| `measure.sh` | the offline sweep: `tools/wp13/route_gates.lua` on all nine fixture seeds, before and after |
| `sweep/` | its output — 18 TSVs and `summary.txt`, the before/after table |
| `kat/` | `tools/wp13/route_gates_kat.lua` under LuaJIT and PUC 5.1 (identical), and the WP13 micro pair's output under both |
| `engine/` | the six engine passes: probe lines, overlay digests, error counts, `audit_terrain` counts |
| `crossings/` | `tools/wp13/lane_routes.lua` before and after: the wave-1 crossing rule has nothing left to do inside a capital (110 spanned columns → 0) and is still green |
| `static.txt`, `static.sh` | parser, SETGLOBAL, the five plain-5.1 sweeps and the fresh-server audit |
| `capital_anchor_fixture.tsv` | `tools/wp13/capital_anchor_fixture.lua` over nine seeds, digest `981a0353…` — unchanged |
| `start-identity.txt` | the six start identities, `0bbf87a7…` — unchanged |
| `r3-freeze-red-on-main.txt` | the R3 accepted-artefact freeze failing on a `git archive` of main `c8050057`, before this lane |
| `r3-station-rule.txt` | the station rule reached in a scratch copy: all 62 rows, 38 hubs and 24 gates, accepted |
| `r3-station-rule-mutation.txt` | the same with a deliberately wrong gate row — `capital gate station rule differs at station:elandor_dur_brannoc:gate_west` |
| `files.sha256` | every source file this lane changed |

## The numbers

Six capitals × the nine seeds of `tools/wp13/capital_anchor_fixture.lua`
(`sweep/summary.txt`):

| measurement | before | after |
| --- | --- | --- |
| route end to its gate point, 216 approaches | up to 256, total 55296 | **0 everywhere** |
| route columns graded strictly inside an envelope | 395757, worst 7330 | **3240, worst 60** |
| bridge-deck columns strictly inside an envelope | 11994, worst 1210 | **0** |
| gate columns stepping more than one node | 23 of 216, worst 30 | **4 of 216, worst 6** |
| entry runs with a walk break | 84 of 216, 616 breaks, worst 30 | **5 of 216, 5 breaks, worst 7** |
| water columns under the four avenues | 26586 over 63 wet runs | unchanged |
| avenue positions unpaved / climbing more than a node | 0 / 0 | 0 / 0 |
| worst ground step in the eight columns inside a gate | 3 | 9 (Kezamba's hillside south gate, two seeds; the limit is 12) |
| `route_gates.lua` exit status, default mode, nine seeds | 1 on every seed | **0 on every seed** |

The 60 remaining route columns per capital are the road's own seven-wide end
cap at the gate, three nodes deep, inside the curtain's thickness and paved
over by the avenue. All five remaining walk breaks are Nhal Veyr's north gate,
whose plateau stops twelve nodes short of its own envelope edge — a terrain
fact, not a route one, and not this lane's to fix.

## The engine

`tools/wp13/run_capital.sh` and `tools/wp13/run_highcourt.sh`, all six passes
exit 0 with zero `ERROR`, zero `ModError`, `event=complete` and zero
`audit_terrain` warnings:

| directory | run |
| --- | --- |
| `engine/db-gate1d` | `run_capital.sh … dur_brannoc full 531802985935182545` |
| `engine/db-gate2b` | `run_capital.sh … dur_brannoc full 8675309` |
| `engine/db-user` | `run_capital.sh … dur_brannoc full 15912857179583385436` (the user's world) |
| `engine/hc-gate1b` | `run_highcourt.sh … full 531802985935182545` |
| `engine/hc-gate2` | `run_highcourt.sh … full 8675309` |
| `engine/hc-edge` | `run_highcourt.sh … edge 15912857179583385436` — the chunk-edge case |

Per-mapchunk cost, the capital's own chunks, steady mean, same host:

| capital | before | after |
| --- | --- | --- |
| Dur Brannoc (85 chunks) | 587772 µs | 583202 µs |
| Highcourt (94 chunks) | 559080 µs | 520179 µs (−7.0 %) |

## Reproducing

    # the offline sweep (BEFORE_REPO is a 922bfd92 checkout with this lane's
    # tools/wp13/route_gates.lua copied in)
    bash tools/wp13/evidence/20260915-route-gates/measure.sh \
        BEFORE_REPO . /tmp/grug-route-gates

    # the route-graph gate: exit 0 on all nine seeds
    luajit tools/wp13/route_gates.lua "$PWD" <seed>
    # a capital lane's own acceptance check: gate step <= 1, entry breaks = 0
    luajit tools/wp13/route_gates.lua "$PWD" <seed> --strict

    # the KAT, both interpreters, byte-identical
    luajit -e 'io.write(dofile("tools/wp13/route_gates_kat.lua")("."))'
    tools/bin/lua51 -e 'io.write(dofile("tools/wp13/route_gates_kat.lua")("."))'

    # the micro pair
    luajit tools/wp13/final_micro.lua "$PWD" /tmp/micro-luajit.tsv luajit
    tools/bin/lua51 tools/wp13/final_micro.lua "$PWD" /tmp/micro-puc.tsv puc51

    # the engine
    WP13_CAPITAL_PORT=31010 nice -n 19 bash tools/wp13/run_capital.sh \
        /tmp/grug-route-gates-engine dur_brannoc full 15912857179583385436

    # the pictures
    luajit tools/wp13/evidence/20260915-route-gates/feature_map.lua "$PWD" \
        15912857179583385436 -1800 -1756 80 /tmp/south-after.tsv
    python3 tools/wp13/evidence/20260915-route-gates/render_gate_approach.py \
        /tmp/south-before.tsv /tmp/south-after.tsv -o /tmp/south.png \
        --centre=-1800,-1500 --scale 4
