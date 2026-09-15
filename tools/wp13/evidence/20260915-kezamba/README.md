# WP13 Kezamba — evidence

The troll capital, built round WP40's authored cenote. The increment record is
[docs/research/wp13-kezamba.md](../../../../docs/research/wp13-kezamba.md).

Taken on `main` at `922bfd92` with LuaJIT 2.1, PUC Lua 5.1 (`tools/bin/lua51`)
and Luanti 5.17.0 through `tools/luanti_headless.sh`'s isolation rules, port
block 31500–31599, everything under `nice -n 19`, one headless server at a time.

## What is here

| File | What it is |
| --- | --- |
| `kat-luajit.txt`, `kat-puc51.txt` | `tools/wp13/kezamba_kat.lua` under both interpreters; the two files are byte-identical |
| `micro-luajit.log`, `micro-puc51.log`, `micro-pair.sha256` | the whole WP13 fixture set in one process under each interpreter; both outputs hash to `46b4dea6…` |
| `identity.txt` | the six start identity digests; the SHA-256 of this file is `0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f`, the value wave 1 recorded |
| `static.sh`, `static.txt` | parser and SETGLOBAL per changed file and tree-wide, the five plain-5.1 sweeps, `check_fresh_server.py` |
| `measurements/water-survey.txt` | `kezamba_water.lua --emit`: the nine-seed wet mask, the water surface and the two committed masks |
| `measurements/core-water.txt` | the same survey at node resolution over the 95 × 95 core, with the per-seed histogram of dry heights |
| `measurements/lots-check.txt` | `kezamba_lots.lua check`: all 52 lots against the four rules on nine seeds |
| `measurements/walk.txt` | `kezamba_lots.lua walk`: can a player walk up to every lot, on nine seeds |
| `engine/` | the `run_capital.sh` passes: nine `terrain` boots and nine `full` ones, one per fixture seed |
| `renders/` | the capital as BUILT, drawn by `render_blueprint.py` from the TSVs the probe read back out of the finished map |

## How to re-take it

```
# the measurements
luajit tools/wp13/kezamba_water.lua . --verify
luajit tools/wp13/kezamba_lots.lua  . check
luajit tools/wp13/kezamba_lots.lua  . walk

# the KAT, both interpreters
luajit            -e 'io.write(dofile("tools/wp13/kezamba_kat.lua")("."))'
tools/bin/lua51   -e 'io.write(dofile("tools/wp13/kezamba_kat.lua")("."))'

# the micro pair
luajit          tools/wp13/final_micro.lua . /tmp/micro-luajit.tsv luajit
tools/bin/lua51 tools/wp13/final_micro.lua . /tmp/micro-puc51.tsv  puc51

# the six starts
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .

# the engine
WP13_CAPITAL_PORT=31500 WP13_CAPITAL_RACE=troll \
  tools/wp13/run_capital.sh /tmp/k-terrain kezamba terrain 531802985935182545
WP13_CAPITAL_PORT=31500 \
  tools/wp13/run_capital.sh /tmp/k-full    kezamba full    531802985935182545

# the static gates
tools/wp13/evidence/20260915-kezamba/static.sh
```

## How to read the engine passes

`run_capital.sh` in `full` mode ABORTS for an OPEN capital before printing its
own PASS: its digest gate greps the log for `avenue`, `rampart` and `gate`, two
of the three find nothing where there is no curtain wall, and under
`set -euo pipefail` a command substitution whose pipeline failed ends the script.
Lane E met the same thing independently and lane D owns the runner.

So the verdict on each of these boots is read from the LOG and not from the
runner's exit code, and each `engine/<seed>/` directory carries exactly that:

* `error-count.txt` / `moderror-count.txt` — both **0** on every seed after this
  lane was rebased onto Lane N (`c8050057`), which registered the wave-2 vendor
  entities;
* `findings.txt` — every ERROR, ModError and WARNING line of the boot, so a
  terrain-audit finding would be visible; there is none;
* `probe.txt` — the `event=complete` line with the mapchunk timings, the plot
  relief, the socket inventory and the read-back digests;
* `npcs.txt` — the roster line, complete on every seed.

## What the shared files this lane touched are for

`wp40/r7_settlement.lua` gains one roster row, appended last, in its own commit.
`tools/wp13/final_micro.lua` gains one row, append-only, in the composition's
commit. Nothing else outside this lane's own files: `tools/wp13/run_capital.sh`
was patched and then reverted on the coordinator's ruling, and the revert commit
carries the diagnosis.
