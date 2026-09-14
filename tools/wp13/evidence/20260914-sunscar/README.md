# WP13 increment 5a: Sunscar Camp, the orc start

Candidate commit: see `candidate.txt`. The note for this increment is
[docs/research/wp13-sunscar-camp.md](../../../docs/research/wp13-sunscar-camp.md).

| Path | What it is |
| --- | --- |
| `static.sh`, `static.txt` | `luac51 -p` and `SETGLOBAL` on every changed Lua file and on the whole `grug_*` and `tools` trees, the five plain-5.1 sweeps (scoped to the changed Lua, then repeated tree-wide for context), and `tools/check_fresh_server.py` |
| `kat-luajit.txt`, `kat-puc51.txt` | `library_kat`, `blueprint_kat` and `integration_fixture` on the frozen bytes, byte-identical under both interpreters |
| `final-micro.sh`, `final-micro/` | the single bounded final-byte process, run once per interpreter, with the input and interpreter hashes taken before and after the run (`inputs-before.sha256` equals `inputs-after.sha256`) |
| `engine.sh` | one engine round: two fresh worlds with opposite owner orders, each followed by a disk-only reload, on one seed, capped at ten minutes, with the luanti PID set taken before and after |
| `engine-user-seed/` | headless Luanti 5.17.0, seed `531802985935182545` |
| `engine-boundary-seed/` | the same for seed `8675309`, which also exercises the vertical owner boundary at Stillgrave |
| `luanti-flatpak-launcher.sh` | the launcher handed to `tools/wp13/run_engine.sh`; the workstation has Luanti only as a Flatpak and the user runs the GUI client at the same time, so the launcher REFUSES an empty or personal `LUANTI_USER_PATH` and pins `XDG_CACHE_HOME`/`XDG_DATA_HOME`/`XDG_CONFIG_HOME` into the profiler's own scratch tree |
| `renders.sh`, `renders/` | the review renders this increment was judged on |
| `files.sha256` | every file above |

The KAT pair was produced with, from the repository root:

```sh
luajit -e 'local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) \
  io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n")'
```

and the same line under `tools/bin/lua51`. The engine rounds were

```sh
bash tools/wp13/evidence/20260914-sunscar/engine.sh \
  531802985935182545 33100 /tmp/grug-wp13-sunscar-user
bash tools/wp13/evidence/20260914-sunscar/engine.sh \
  8675309 33140 /tmp/grug-wp13-sunscar-boundary
```

The launcher mounts the repository read-only, so the runner's output
directory lives outside the repository and is copied in afterwards. Four WP13
lanes share the workstation; each round was started only while
`pgrep -c -f '^luanti.bin --server'` was below four, and the two rounds ran
one after the other. The luanti PID set was taken before and after each
round: no pid survives a round that did not precede it, so no headless server
was left behind and the user's own client was never touched. (The PID lists
in the logs shrink rather than grow, because a sibling lane's round finished
while this one ran.)

## Hearthpine and Dawnmere are unchanged

| Property | Before (`20260914-dawnmere-fixes`) | Here |
| --- | --- | --- |
| Hearthpine blueprint identity SHA-256 | `e07ac54b…5100cf9ffb` | the same |
| Hearthpine cells | 61,932 | 61,932 |
| Hearthpine architecture digest | `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c` | the same, both seeds, both owner orders, cold and disk |
| Dawnmere blueprint identity SHA-256 | `66c7f811…d54354f74` | the same |
| Dawnmere cells | 66,343 | 66,343 |
| Dawnmere architecture digest | `cdbc03239c181f1f41caf1a4a2bd851753c17f2b04e2df95037d1e62893ef4f9` | the same, both seeds, both owner orders, cold and disk |
| Both `blueprint_kat` rows | `61932 46389 41 74 1232 9 10 10 180 15588` / `66343 44863 52 98 1467 9 12 10 27 15411` | identical |

The engine receipt lines carry `hearthpine_digest=`, `dawnmere_digest=` and
`sunscar_digest=` separately, plus the combined `digest=` the runner compares
across the four passes of a seed.

## Results

- Sunscar: 59,673 cells, 46,551 of them not air, 44 materials, 112 lights,
  1,320 oriented nodes, 10 reachable destinations, 10 doors, 11 rooms, 228
  barred panes (14 of them the connected shape), 47 acacias, 320 breastwork
  merlons, 96 palisade stakes, 537 berm cells, 2,626 mesa cells. Bounds x/z
  `[-63, 63]`, y `[-1, 11]`, inside the authorized volume and well under the
  125,000 cell budget.
- Blueprint identity SHA-256
  `dcb6e82cac6dcc360b1485359c8c85566d49a033a131d2f51993005b07472744`.
- Engine: both seeds pass forward and reverse generation and cold and disk
  reload, eight passes, 24 and 33 emerged owners. Every authored node name
  and param2 of ALL THREE settlements matches after generation and after
  reload, all 74 Hearthpine, 98 Dawnmere and 112 Sunscar torches are lit,
  every destination and every main-route foot of all three starts is lit,
  soil outside the blueprints is present and the deliberate edit canary
  survives the reload. The boundary seed also proves filler-only restoration
  at the vertical owner boundary.
- All eight combined architecture digests equal
  `ffe90fedca583344c197078c41ec1a4882194e17cc284af32d9949ef27dbd220`, and the
  three per-settlement digests are equal across both seeds:
  Hearthpine `03311c95…`, Dawnmere `cdbc0323…`, Sunscar
  `bd673e4acd4f9c187b26a7649e3e64c7e8045c579f80dee2d335d6bf8407c8be`.
- Fitted start heights on seed `531802985935182545`: Hearthpine y = 25,
  Dawnmere y = 17, **Sunscar y = 27**. On seed `8675309`: Hearthpine y = 16,
  Dawnmere y = 21, **Sunscar y = 46**.
- Final micro: LuaJIT and PUC 5.1.5 byte-identical at
  `5456e9ff54826d0a705ff2411ed21e08d07082ad8fd2cbbc65e84fe4dfaf2d1e`.

## The one bound this increment had to correct

`engine_cases.lua` asserted at most sixteen structure owners for two starts,
on the argument that a start "occupies at most two owners per horizontal
axis". That is arithmetically wrong: a start spans 127 nodes per horizontal
axis and an owner is 80 wide, so 127 nodes touch two OR THREE owners. The
bound held only because the two starts it was written for happened to fall
kindly; the third start needed 33 owners on the boundary seed and the assert
refused the corpus. The ceiling is now the honest 3 x 3 x 2 = eighteen per
start, and it scales with the roster. The first user-seed round was discarded
and re-run on the corrected harness, so both rounds in this directory share
one `harness.sha256`.

## Scoped gaps

- `tools/wp40/r7/{micro_kat_fixture,manifest_constructor_kat,runtime_fixture}`
  still call the pre-increment-4 `r7_content`/`r7_hearthpine` signatures.
  They were ALREADY red on this increment's base commit for the reason the
  Dawnmere evidence records, so they were left untouched rather than edited
  without a way to run them.
- `tools/wp13/final_micro.lua` still excludes the portable WP40 R7 micro-KAT
  body, for the same reason and as recorded in that file.
- The renders were produced with `--texture-root` pointing at the main
  checkout's `reference_projects/minetest_game/mods`, because in a git
  worktree that submodule is unpopulated (`README-render.md` says so).
