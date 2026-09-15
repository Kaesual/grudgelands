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
| `engine/` | the `run_capital.sh` passes: nine `terrain` boots and four `full` ones |
| `renders/` | the capital as BUILT, drawn by `render_blueprint.py` from the TSVs the probe read back out of the finished map |

## How to re-take it

```
# the measurements
luajit tools/wp13/kezamba_water.lua . --verify
luajit tools/wp13/kezamba_lots.lua  . check

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

## The two ERROR lines every full pass carries, and why they are expected

```
ERROR[Main]: [grug_mobs] settlement npcs: kezamba socket
  shore_market/shore_market_vendor_brewer resolves to no registered entity
  (grug_traders:vendor_brewer)
ERROR[Main]: [grug_mobs] settlement npcs: kezamba socket
  vine_herbalist/vine_herbalist_vendor_herbalist resolves to no registered
  entity (grug_traders:vendor_herbalist)
```

`brewer` and `herbalist` are two of the seven wave-2 vendor kinds the sockets
contract's §8.4 added on 2026-09-15, and the contract says in as many words what
happens before the NPC lane registers their entities: "a kind whose entity the
traders mod has not registered yet is an error line at placement and an empty
socket, never a load failure". That is exactly what the log shows, and the same
pass reports its roster complete — `guards 18/18 flair 175/175 vendor 5/5
quest 1/1 pending 0 spare 11`.

`run_capital.sh` gates on the ERROR **count** rather than on the content, so it
calls such a pass FAILED. That is the runner's rule and not this capital's: the
passes are otherwise complete (`event=complete`, zero `ModError`, no finding
from the seam's load-time terrain audit). The runner belongs to lane D
(`tools/wp13/capital_*`), and the note's open points say so rather than this
lane changing a shared gate to make its own run green.
