# WP13 Kezamba — evidence

The troll capital, built round WP40's authored cenote. The increment record is
[docs/research/wp13-kezamba.md](../../../../docs/research/wp13-kezamba.md).

Taken on `main` at `922bfd92` and re-taken on `f5583e13` (Lane N + Lane R +
Lane D) with LuaJIT 2.1, PUC Lua 5.1 (`tools/bin/lua51`)
and Luanti 5.17.0 through `tools/luanti_headless.sh`'s isolation rules, port
block 31500–31599, everything under `nice -n 19`, one headless server at a time.

## What is here

| File | What it is |
| --- | --- |
| `kat-luajit.txt`, `kat-puc51.txt` | `tools/wp13/kezamba_kat.lua` under both interpreters; the two files are byte-identical |
| `micro-luajit.log`, `micro-puc51.log`, `micro-pair.sha256` | the whole WP13 fixture set in one process under each interpreter; on `f5583e13` with this lane's fixes both outputs hash to `41ed5eb2…` |
| `identity.txt` | the six start identity digests; the SHA-256 of this file is `0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f`, the value wave 1 recorded |
| `static.sh`, `static.txt` | parser and SETGLOBAL per changed file and tree-wide, the five plain-5.1 sweeps, `check_fresh_server.py` |
| `measurements/water-survey.txt` | `kezamba_water.lua --emit`: the nine-seed wet mask, the water surface and the two committed masks |
| `measurements/core-water.txt` | the same survey at node resolution over the 95 × 95 core, with the per-seed histogram of dry heights |
| `measurements/water-verify.txt` | `kezamba_water.lua --verify`: the committed mask against the planner on nine seeds, 0 disagreements |
| `measurements/water-verify-failed-on-rebase.txt` | the same command BEFORE the mask was re-emitted, with the 273 ravine disagreements that found the vanished gorge (note §3d) |
| `measurements/lots-check.txt` | `kezamba_lots.lua check`: all 52 lots against the four rules on nine seeds |
| `measurements/walk.txt` | `kezamba_lots.lua walk`: can a player walk up to every lot, on nine seeds |
| `measurements/gates.txt` | `kezamba_lots.lua gates`: the four gate points on nine seeds — step, ramp columns, drop, floating cells |
| `measurements/gate-vs-route-ends.txt` | the same 36 gates against Lane R's own route ends (`route_gates.lua --strict`); 0 disagreements |
| `measurements/route-gates-531802985935182545.txt` | Lane R's strict output for the gate seed, whole file |
| `measurements/field-vs-mask.txt` | `kezamba_water.lua --field`: the ENGINE's terrain field (`run_capital.sh field`) against the committed lagoon mask, 251 001 columns, 0 disagreements |
| `measurements/emergent-trees.txt` | the tree census of the built map: the core against an untouched control band of the same world |
| `engine/` | the `run_capital.sh` passes: nine `terrain` boots and nine `full` ones, one per fixture seed, plus `f5583e13-full-…` and `f5583e13-field-…`, the two boots taken after the rebase on Lane D's fixed runner |
| `renders/` | the capital as BUILT, drawn by `render_blueprint.py` from the TSVs the probe read back out of the finished map |
| `renders/plan-whole-capital-ne.png` | the whole capital on one flat plane — core, 52 plots, four avenues, ring street — from Lane D's generic `dump_capital_plan.lua` |

## How to re-take it

```
# the measurements
luajit tools/wp13/kezamba_water.lua . --verify
luajit tools/wp13/kezamba_lots.lua  . check
luajit tools/wp13/kezamba_lots.lua  . walk
luajit tools/wp13/kezamba_lots.lua  . gates

# the gate junction against Lane R's route ends, per seed
luajit tools/wp13/route_gates.lua   . 531802985935182545 --strict

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
WP13_CAPITAL_PORT=31500 WP13_CAPITAL_RACE=troll \
  tools/wp13/run_capital.sh /tmp/k-field   kezamba field   531802985935182545
luajit tools/wp13/kezamba_water.lua . --field /tmp/k-field/kezamba-field.tsv

# the whole capital as a plan
luajit tools/wp13/dump_capital_plan.lua . kezamba 531802985935182545 > /tmp/plan.tsv
python3 tools/wp13/render_blueprint.py /tmp/plan.tsv --scale 4 -o /tmp/plan.png

# the static gates
tools/wp13/evidence/20260915-kezamba/static.sh
```

## How to read the engine passes

**Lane D fixed the open-capital abort in its round**, so on `f5583e13` the `full`
mode prints `WP13 capital pass PASS: kezamba full` and skips the two labels an
open capital does not publish (`engine/f5583e13-full-531802985935182545/`).

The eighteen boots taken before that fix were read from their LOGS instead,
because the runner then aborted before printing its own PASS: its digest gate
grepped for `avenue`, `rampart` and `gate`, two of the three found nothing where
there is no curtain wall, and under `set -euo pipefail` a command substitution
whose pipeline failed ended the script. Lane E met the same thing independently.
Each `engine/<seed>/` directory therefore carries exactly what that verdict
needs:

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
was patched and then reverted on the coordinator's ruling, and both commits were
skipped on the rebase onto `f5583e13` because Lane D had landed the fix upstream.
A diff of this branch against `f5583e13` over `run_capital.sh`, `avenue.lua`,
`parts.lua` and `capital_probe/` is empty.
