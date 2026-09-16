# Evidence: one street rule for all six capitals (2026-09-16)

The increment record is
[docs/research/wp13-street-geometry.md](../../../../docs/research/wp13-street-geometry.md).
Everything here was taken on branch `wp13-w3-streets`, off `main` at
**`f37a0c5b`** ("Freeze the Dur Brannoc corner digest on the gate seed", the
wave-2 merge with six capitals).

Wave 3, Lane S: the five rulings of playtest 5 (2026-09-16) about a capital's
streets, as rules of `wp13/avenue.lua` — a flat cross profile, junction
plateaus, lamps on the street's own level, viaducts on pillars, and bridges over
water in every capital and every race palette.

## What is here

| File | What it is | How to re-take it |
| --- | --- | --- |
| `measurements/before-*.tsv`, `*.log` | the streets of all six capitals on `main` at `f37a0c5b`, per run, on all nine fixture seeds | `luajit tools/wp13/street_geometry.lua /path/to/main <seed> --runs out.tsv` (the tool falls back to this branch's `street_plan.lua` when the tree it measures has none) |
| `measurements/after-*.tsv`, `*.log` | the same nine seeds on this branch | `luajit tools/wp13/street_geometry.lua . <seed> --runs out.tsv` |
| `kat/*-luajit.txt`, `kat/*-puc51.txt` | every WP13 KAT this lane touches, under both interpreters; each pair is byte-identical | `luajit -e 'io.write(dofile("tools/wp13/<kat>.lua")("."))'` and the same with `tools/bin/lua51` |
| `micro-luajit.tsv`, `micro-puc51.tsv` | the whole WP13 fixture set in one process under each interpreter, `street_kat` included; the two are byte-identical | `luajit tools/wp13/final_micro.lua . <out> luajit` and `tools/bin/lua51 tools/wp13/final_micro.lua . <out> puc51` |
| `mutation.py`, `mutation.txt` | **the KAT's own proof**: each of the five rulings broken in `avenue.lua` on purpose, and the section of `street_kat.lua` that goes red for it | `python3 tools/wp13/evidence/20260916-streets/mutation.py .` |
| `overlay_bench.lua`, `bench.txt` | what the new rules cost: every street run of every capital over one synthetic terraced surface, timed, on both trees | `luajit tools/wp13/evidence/20260916-streets/overlay_bench.lua . after` and the same against a `main` checkout |
| `engine/<key>-<mode>-<seed>/` | the engine passes: the runner's own stdout, the probe lines, the NPC placement lines and the read-back overlay digests | `WP13_CAPITAL_PORT=31010 tools/wp13/run_capital.sh <out> <key> <mode> <seed>` |
| `identity.txt`, `identity.sh` | the files this branch changed against `f37a0c5b`, the six start identities against `main`'s own, Highcourt's blueprint digests, the re-frozen digests and every settlement identity the integration fixture prints | `bash .../identity.sh . /path/to/main` |
| `static.sh`, `static.txt` | parser, SETGLOBAL, the five plain-5.1 sweeps and the fresh-server audit | `bash tools/wp13/evidence/20260916-streets/static.sh <repo>` |
| `lane-routes.txt` | the route-crossing gate on all nine seeds: `illegal=0 walk_faults=0 cross_faults=0 lamp_faults=0` everywhere | `luajit tools/wp13/lane_routes.lua . <seed> out.tsv` |
| `refreeze.sh` | what re-froze the seventeen built-geometry digests, from the engine passes and from nothing else | `bash tools/wp13/evidence/20260916-streets/refreeze.sh . <engine root>` |
| `street_dump.lua`, `renders.sh`, `renders/` | the three pictures playtest 5 asked for, before and after | `bash tools/wp13/evidence/20260916-streets/renders.sh /path/to/main` |

## The headline numbers

Nine fixture seeds, six capitals, measured off the **cells the overlay writes**:

| metric | before | after | ruling |
| --- | --- | --- | --- |
| worst cross-profile spread | 5..8 nodes | **0** | 1 |
| worst step per lane along a run | up to 3 | **1** | 1 |
| worst spread over a junction square | 4..22 nodes | **0** | 2 |
| columns raised ≥ 3 that are solid fill | all of them (924..2460) | **0..5** | 4 |
| …on pillars instead | 0..77 | 1498..4793 | 4 |
| street columns over water | 7475, identical on all nine seeds | 7475 | 5 |
| rails written | 0..1377, two capitals | 3702..5136, all six | 5 |
| lamps footing off the street | 1089..1244 of 4343 | **0 of 4444** | 3 |

## The renders

| File | What |
| --- | --- |
| `renders/before-dur_brannoc-lane-on-the-slope.png` | the east avenue on the blend band as the user saw it: the road stepping with the terraces, lamps at the ground beside it |
| `renders/after-dur_brannoc-lane-on-the-slope.png` | the same window: one flat carriageway, the raised stretch on pillars with air under it, a railed plank verge and the lamps on the road's own level |
| `renders/before-lethariel-ring-corner-1894--1405.png` | the junction the user named, at the ring street's north-east corner over the mere: two decks meeting at two different heights |
| `renders/after-lethariel-ring-corner-1894--1405.png` | the same corner as one square plateau, both runs arriving at it a node a column |
| `renders/before-highcourt-river-crossing.png` | the east avenue over a river as a causeway — a dam with a road on it |
| `renders/after-highcourt-river-crossing.png` | the same crossing as a bridge: deck one node over the water, piers on the verge, a rail either side, the water continuous underneath |

`renders/tsv/` holds the TSVs the pictures are drawn from: the real terrain of
seed 8675309 plus every overlay run that reaches into the window, in the seam's
own run order.

## The digests that moved, and why

An overlay's manifest identity is its SPECIFICATION and not its cells, so the
only two things this lane can move are the overlay's own identity row and the
built-geometry digests `run_capital.sh` gates on.

* **Four `avenue` overlay identities** moved — Highcourt's, Dur Brannoc's,
  Kezamba's and Nhal Veyr's — because those four capitals' road palette union
  gained the bridge vocabulary (`floor`, `railing`, and the `signature` /
  `wall_accent` pier). Gor Drazhak's and Lethariel's did not: their unions
  already carried every one of those names, from the palisade and from the elf
  bridge respectively. Every OTHER blueprint digest of every capital is
  unchanged — core, every plot, every settlement's identity root — and the six
  start identities are byte-identical to `main`'s. The written-cell counts in
  the integration fixture's rows move with the road, which is the road moving
  and not an identity moving. See `identity.txt`.
* **The built `avenue`, `rampart` and `gate` digests** moved for the capitals and
  seeds listed in `engine/`. The road moved by design; the `rampart` and `gate`
  regions moved because the ROAD cells inside them moved — the avenue is the
  first run and wins every cell it and the curtain share. `wall.lua` itself is
  untouched and its own KAT row is byte-identical (`kat/dur_brannoc_kat-*.txt`,
  the `dur_brannoc_wall` row). The `corner` digests did not move at all.
