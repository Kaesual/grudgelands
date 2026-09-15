# WP13 wave 2: the NPC vocabulary

Evidence for [docs/research/wp13-npc-vocabulary.md](../../../../docs/research/wp13-npc-vocabulary.md),
taken on `wp13-w2-npc-vocabulary`, based on main `922bfd92`, on 2026-09-15.

| Path | What it is |
| --- | --- |
| `static.sh`, `static.txt` | parser and SETGLOBAL per changed file and tree-wide, the two shell harnesses' syntax, the five plain-5.1 sweeps scoped and tree-wide, `check_fresh_server.py`, and a re-check of every profession shelf entry against `items.txt` |
| `items.txt` | the measurement the shelves were built from: all 1012 item names the engine registers in this tree, with their `_grug_sell_price`, dumped by one throwaway headless boot |
| `kat.sh`, `kat.txt`, `kat/` | `start_npcs_kat` under both interpreters (byte-identical), the WP40 `vendor_fixture` under both, the `micro_kat_fixture` trader-projection check, and the six start identities |
| `final-micro.sh`, `final-micro/` | the one bounded final-byte process: every WP13 fixture in one interpreter, once under LuaJIT and once under `tools/bin/lua51`, inputs hashed before and after |
| `bones.txt` | the bone names `character.b3d` actually carries, which is what makes the mourner's bowed head a measurement rather than a hope |
| `probe-start/` | `run_npc_probe.sh` in its unchanged three-boot START mode: the round-1/2/3 programme still passes with the wave-2 code, plus the two startup audit lines |
| `probe-capital/` | the NEW capital mode, pointed at Highcourt: the inventory and the per-socket gap list |
| `load/` | `run_npc_load.sh` over the six starts on this branch. The BEFORE side is not re-taken: round 3 published its own numbers in `wp13-npc-work.md` §7.1 from the identical probe file, and a second ten-minute boot to reproduce a published figure buys nothing |
| `files.sha256`, `files.sha256.sh` | the frozen-byte manifest of every input and product above |

## How to re-run it

```bash
bash tools/wp13/evidence/20260915-npc-vocabulary/static.sh
bash tools/wp13/evidence/20260915-npc-vocabulary/kat.sh
bash tools/wp13/evidence/20260915-npc-vocabulary/final-micro.sh

# the engine, ONE server at a time, ports in this lane's own block 31600-31699
PORT=31610 tools/wp13/run_npc_probe.sh /tmp/npcvocab-start 531802985935182545 start
PORT=31620 tools/wp13/run_npc_probe.sh /tmp/npcvocab-capital 531802985935182545 capital highcourt
PORT=31630 tools/wp13/run_npc_load.sh /tmp/npcvocab-load 531802985935182545

bash tools/wp13/evidence/20260915-npc-vocabulary/files.sha256.sh
```

## The headline numbers

| | |
| --- | --- |
| activities implemented | 9 → **15** (contract §8.2's second table) |
| wielded tools / weapon families | 4 / 0 → **7 / 1**, all registered at load |
| profession vendor entities | 13 → **20**; 12 shelves, **62 offers**, none dropped |
| race-flavoured lines added | **43** (seven keys × six races, plus the `shade` key that had none) |
| `start_npcs_kat` residents / walkers / share | 8 / 2 / 25.0 % → **10 / 2 / 20.0 %** |
| WP13 final micro pair | `b3aa0177…` under LuaJIT and PUC 5.1, byte-identical |
| six start identities | `0bbf87a7…`, the wave-1 value, unchanged |
| Highcourt capital probe | roster 181, **marked 181**, owed 0, residents 144, walkers 22 (**15.3 %**), work 36, **all seven vendor kinds including the baker** |
| engine errors | 0 in every run (start mode `complete=3`, capital mode `complete=1`) |

See the research note for what each one means.
