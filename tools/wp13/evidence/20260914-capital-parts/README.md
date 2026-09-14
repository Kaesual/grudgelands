# WP13 capital parts — evidence, 2026-09-14

The lane record is
[docs/research/wp13-capital-library.md](../../../../docs/research/wp13-capital-library.md).
Every script here derives the repository root from its own path and can be
re-run from anywhere. Run them in this order.

| Script | What it produces |
| --- | --- |
| `static.sh` | `static.txt` — `luac51 -p` and the SETGLOBAL count per touched file, the tree-wide parse, the five plain-5.1 sweeps, `py_compile`, the tile-map parse, the fresh-server audit |
| `kat.sh` | `kat-luajit.txt`, `kat-puc51.txt` — `library_kat` (with the new section 12) + `blueprint_kat` + `integration_fixture` in one process under each interpreter; the two must be byte-identical |
| `start_identity.lua` | `start-identity.txt` — the identity digest `r7_settlement` computes for each of the six starts. `start-identity-base-9026d89.txt` is the same file computed from a `git archive` of `main` at `9026d89`; the two are identical, which is the byte-identity proof for the three shared modules this lane changed. Usage: `luajit start_identity.lua <repo>` |
| `renders.sh` | `renders/` — every generator for human, dwarf and troll, twelve interior cutaways, two turned views, two night views (71 files), and `renders/tsv/` with the dumped cells and sockets of each |
| `sockets.sh` | `sockets.txt` — the socket inventory of every part, id / role / local x,y,z / facing |
| `final-micro.sh` | `final-micro/` — the single bounded final-byte process, one LuaJIT and one PUC 5.1 run of `tools/wp13/final_micro.lua` over inputs hashed before and after |

Results on the frozen bytes:

```
KAT PAIR BYTE-IDENTICAL
875fc3ddc6aecea28752a68b0b9ba9cbb6abd50dd5c31cb951500eaa985b4ee7  kat-luajit.txt
875fc3ddc6aecea28752a68b0b9ba9cbb6abd50dd5c31cb951500eaa985b4ee7  kat-puc51.txt
875fc3ddc6aecea28752a68b0b9ba9cbb6abd50dd5c31cb951500eaa985b4ee7  final-micro/micro-luajit.tsv
875fc3ddc6aecea28752a68b0b9ba9cbb6abd50dd5c31cb951500eaa985b4ee7  final-micro/micro-puc51.tsv
```

(The KAT pair and the final micro carry the same digest because
`final_micro.lua` runs exactly those three fixtures and nothing else.)

No engine run: nothing in this lane is wired into a settlement, so there is
no mapchunk to generate. The first composition that places these parts owes
the engine run.

`tools/bin/lua51` is git-ignored and built per checkout
(`tools/build_lua51.sh`); in a worktree whose `reference_projects` submodule
is unpopulated, copy the binaries from the main checkout.
