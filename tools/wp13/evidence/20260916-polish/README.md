# WP13 wave 3, Lane P: polish -- evidence

Branch `wp13-w3-polish`, base main `f37a0c5b`. The note is
[docs/research/wp13-polish-wave3.md](../../../../docs/research/wp13-polish-wave3.md).

Every script here resolves the repository from its own path and may be run from
anywhere; everything runs with `LC_ALL=C`.

## The gates

| script | output | what it proves |
|---|---|---|
| `static.sh` | `static.txt` | `luac51 -p` and the SETGLOBAL count on every file this lane changed, the whole `mods/*/grug_*` and `tools` trees parsing under plain 5.1, the five plain-5.1 sweeps scoped and then tree-wide, `bash -n` on the changed shell, and `check_fresh_server.py`. The only scoped sweep hits are `os.exit` in two standalone CLIs (`capital_lots.lua`, `dump_part.lua`) -- the pattern every WP13 CLI has carried since the renderer landed, neither ever loaded by the engine. |
| `kat.sh` | `kat.txt`, `kat/` | The twelve WP13 KATs under LuaJIT and again under `tools/bin/lua51`, each pair compared byte for byte, plus `tools/wp40/r7/run.sh unit`. It also names the three mutations this lane's two new KAT sections exist for; all three were run by hand on 2026-09-16 and all three go red. |
| `identity.sh` | `identity.txt` | The six start identities against main's, every settlement identity the integration fixture prints, and Highcourt's blueprint identities. |
| `final-micro.sh` | `final-micro.txt`, `final-micro/` | Every WP13 fixture in one process under LuaJIT and again under PUC 5.1, with the input set hashed before and after and the two outputs compared. Pair digest `3ce0b29cf99bde046defc047ee34be2b0e05e27803f4c54ce2d0bab07e43cbb3`. |

## The measurements

| file | what it is |
|---|---|
| `measurements/highcourt-lots-nine-before.txt` | `capital_lots.lua . highcourt <nine fields>` before the repair: 12 of 52 lots refused. |
| `measurements/highcourt-lots-repair.txt` | the same with `--repair`: 6 district lots and 7 fill lots moved. |
| `measurements/highcourt-lots-nine-after.txt` | and again after: "every lot and every fill lot of highcourt is dry, inside the skirt and under its own roof on all 9 worlds". |
| `measurements/dur_brannoc-lots-nine.txt` | Dur Brannoc on the same nine worlds: zero refused. The wave-2 log's "1 lot" does not reproduce. |
| `measurements/audit-terrain-before.txt` | the ENGINE's own load-time `r7_settlement.audit_terrain`, nine cold boots on the nine seeds, before the repair: 11 findings on 6 seeds, all Highcourt. |
| `measurements/audit-terrain-after.txt` | the same nine boots after: `AUDIT DONE total_findings=0`. |
| `measurements/kings-hall-nodes-{before,after}.txt` | every node name of `capitals.king_hall` under the BASALT handle, counted, before and after the basalt roof. |
| `measurements/tree-census-highcourt.txt` | the tree census: 52 plots, 4954 trunks, 0 wild; 15 street runs, 0 trunks. |
| `measurements/tree-census-lethariel.txt` | 44 plots, 3286 trunks, 0 wild; 15 street runs, 0 trunks. |
| `measurements/tree-census-lethariel-with-edge-belt.txt` | the FIRST Lethariel run, before `edge_` runs were excluded: 4269 canopied trunks along the grove edge, every one the composition's own silverwood. Kept because it is why the exclusion exists. |

## The engine passes

One headless server at a time, port 31310, through `tools/wp13/run_capital.sh`.

| file | pass |
|---|---|
| `engine/full-passes.txt` | Gor Drazhak and Kezamba, `full`, gate seed. Both PASS. Gor Drazhak's three committed digests match and its corner is recorded for the first time; Kezamba publishes no rampart, gate or corner region at all. |
| `engine/gor_drazhak/` | its overlay digests, its probe lines and the corner TSV the frozen digest was taken from. |
| `engine/kezamba/` | its overlay digests (avenue only) and probe lines. |
| `engine/highcourt/` | the pass that found the stale avenue expectation and from which all four Highcourt regions are now frozen. |
| `engine/lethariel/` | the census pass. |
| `npc/load-with-capital.txt` | `run_npc_load.sh … highcourt`: six start windows and one capital window, with the microbenchmark per settlement. |
| `npc/errors.txt` | the one error line, and it is a FINDING and not a defect of this lane: "highcourt handed a walker a ring of 1: it can never move". |

## The renders

| file | what it shows |
|---|---|
| `renders/bough-{before,after}.png` | Lethariel's bough house. Before: the flight's treads face the wrong way and the run reads as a flush face. After: a staircase. |
| `renders/kings-hall-{before,after}.png` | Kezamba's king's hall under the BASALT handle, with the junglewood roof and with the basalt one. **The user's call.** |
| `renders/gor_drazhak-corner.png` | the four curtain corners the frozen digest covers, 500 nodes apart, which is why the picture is mostly empty. |
| `renders/highcourt-lots-{before,after}.png` | the whole Highcourt plan on a flat plane, with the lot grid before and after the repair. |

`dump_part.lua` is this lane's own part dumper: the shared
`tools/wp13/dump_capital_part.lua` only reaches `wp13/capitals.lua`'s
generators with a plain race palette, and the two parts this lane had to look
at are an `elf_parts` one and a `capitals` one built with a palette HANDLE.
