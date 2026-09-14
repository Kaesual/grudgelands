# WP13 increment 3 evidence: the building library and Hearthpine rebuilt

Candidate commit: see `candidate.txt`. Package note:
`docs/research/wp13-hearthpine-library.md`.

| Path | What it is |
| --- | --- |
| `static.txt` | `luac51 -p` and `SETGLOBAL` on every changed Lua file and on the whole `grug_*` and `tools` trees, the five plain-5.1 sweeps (scoped to the changed Lua, then repeated tree-wide for context), and `tools/check_fresh_server.py` |
| `kat-luajit.txt`, `kat-puc51.txt` | `library_kat`, `blueprint_kat` and `integration_fixture` on the frozen bytes, byte-identical under both interpreters |
| `final-micro/` | the single bounded final-byte process, run once per interpreter in parallel, with the input and interpreter hashes taken before and after the run |
| `engine-user-seed/` | headless Luanti 5.17.0, seed `531802985935182545`: two fresh worlds with opposite owner orders, each followed by a disk-only reload |
| `engine-boundary-seed/` | the same for seed `8675309`, which also exercises the vertical owner boundary at Stillgrave |
| `luanti-flatpak-launcher.sh` | the launcher handed to `tools/wp13/run_engine.sh`; the workstation has Luanti only as a Flatpak |
| `renders/` | the review renders the architecture was iterated on |
| `files.sha256` | every file above |

## Results

- Blueprint: 63,620 cells, 48,084 of them not air, 38 materials, 66 lights,
  2,095 oriented nodes, 9 reachable destinations, 10 doors, 10 rooms, 174
  pines, 15,041 reachable standing cells. Bounds x/z `[-63, 63]`, y
  `[-1, 12]`, inside the authorized volume and under the 125,000 cell budget.
- Engine: both seeds pass forward and reverse generation and cold and disk
  reload, eight passes in total. All eight architecture digests equal
  `0e49239a73d60940b2f61b7bfa4b3375b509f6c2b58767ed8be28f63ff829f03`. Every
  authored node name and param2 matches after generation and after reload,
  all 66 torches are lit, every destination and every main-road foot is lit,
  soil outside the blueprint is present and the deliberate edit canary
  survives the reload. The boundary seed also proves filler-only restoration
  as `default:dirt` at y=47 under the y=48 Stillgrave surface.
- Final micro: LuaJIT and PUC 5.1.5 are byte-identical at
  `5d1ab7c9737dadf11384539f47aef17e40a7297fc91f53461e2282eba7681558`.

## Scoped gap

The portable WP40 R7 micro-KAT body is not part of this pair.
`tools/wp40/r7/node_semantics_fixture.lua` reconstructs registered-node
semantics engine-free from `default`, `grug_trees`, `grug_materials`,
`grug_nodes`, `grug_gathering` and three hand-listed stairs shapes, so it
cannot resolve a Hearthpine palette that also names `doors`, `beds`,
`xpanes`, `wool`, `vessels` or `walls` nodes. Teaching it the seven newly
vendored mods belongs to the WP40 lane that owns the fixture. The live
engine run covers the same property more strongly: R7's real content
manifest hard-fails on any unregistered Hearthpine palette name, and it did
exactly that for `default:steelblock` before the workbench role was moved to
`grug_materials:iron_block`.
