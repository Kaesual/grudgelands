# WP13 increment 5, troll lane: Kapok Cradle

Candidate commit: see `candidate.txt`. The note for this increment is
[docs/research/wp13-kapok.md](../../../docs/research/wp13-kapok.md).

| Path | What it is |
| --- | --- |
| `static.sh`, `static.txt` | `luac51 -p` and `SETGLOBAL` on every changed Lua file and on the whole `grug_*` and `tools` trees, the five plain-5.1 sweeps (scoped to the changed Lua, then repeated tree-wide for context), and `tools/check_fresh_server.py` |
| `kat-luajit.txt`, `kat-puc51.txt` | `library_kat`, `blueprint_kat` and `integration_fixture` on the frozen bytes, byte-identical under both interpreters |
| `final-micro.sh`, `final-micro/` | the single bounded final-byte process, run once per interpreter, with the input and interpreter hashes taken before and after (`inputs-before.sha256` equals `inputs-after.sha256`) |
| `engine.sh`, `engine-run.log` | the two engine runs, one seed after the other, each preceded by a wait until the workstation is below four headless servers |
| `engine-user-seed/` | headless Luanti 5.17.0, seed `531802985935182545`: two fresh worlds with opposite owner orders, each followed by a disk-only reload |
| `engine-boundary-seed/` | the same for seed `8675309`, which also exercises the vertical owner boundary at Stillgrave |
| `luanti-flatpak-launcher.sh` | the launcher handed to `tools/wp13/run_engine.sh`, unchanged from the previous increment: the workstation has Luanti only as a Flatpak and the user runs the GUI client at the same time, so the launcher REFUSES an empty or personal `LUANTI_USER_PATH` and pins `XDG_CACHE_HOME`/`XDG_DATA_HOME`/`XDG_CONFIG_HOME` into the profiler's own scratch tree |
| `renders/` | the review renders this increment was judged on |
| `files.sha256` | every file above |

The KAT pair was produced with, from the repository root:

```sh
LC_ALL=C luajit -e 'local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) \
  io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n")'
```

and the same line under `tools/bin/lua51`. The engine runs were
`WP13_SEED=531802985935182545 WP13_PORT_BASE=32700` and
`WP13_SEED=8675309 WP13_PORT_BASE=32740`, each wrapped in
`timeout --kill-after=30 600` and each writing to `/tmp` (the launcher mounts
the repository read-only), copied in here afterwards.

## The leftover-server check

The previous increments compared the whole `luanti.bin` PID set before and
after a run. That test is unsound while four settlement lanes share this
workstation: the orc lane started two servers of its own during this run, and
the comparison read them as a leak of ours. `engine.sh` therefore scopes the
check to the lane --- every headless server names its own run directory on its
command line --- and the recorded run log shows the original comparison firing
on the sibling lane's PIDs (678438, 678477), both of which had exited by the
time they were looked up. No Kapok server remained: both runs printed
`WP13 engine PASS`, and `pgrep -af 'luanti.bin --server'` afterwards listed
only servers whose logfile path is `/tmp/grug-wp13-sunscar-boundary/…`.

## Hearthpine and Dawnmere are unchanged

| Property | Recorded before | Here |
| --- | --- | --- |
| Hearthpine blueprint identity SHA-256 | `e07ac54b…5100cf9ffb` | the same |
| Hearthpine engine architecture digest | `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c` | the same, both seeds, both owner orders, cold and disk |
| Hearthpine `blueprint_kat` row | `61932 46389 41 74 1232 9 10 10 180 15588` | identical |
| Dawnmere blueprint identity SHA-256 | `66c7f811…d54354f74` | the same |
| Dawnmere engine architecture digest | `cdbc03239c181f1f41caf1a4a2bd851753c17f2b04e2df95037d1e62893ef4f9` | the same, both seeds, both owner orders, cold and disk |
| Dawnmere `blueprint_kat` row | `66343 44863 52 98 1467 9 12 10 27 15411` | identical |

## Results

- Kapok: 71,783 cells, 51,755 of them not air, 42 materials, 87 lights, 831
  oriented nodes, 8 reachable destinations, 9 doors, 9 rooms, 32 rope cells,
  16 lanterns, 42 stepping stones, 2,967 flora cells, 83 jungle trees and 3
  emergent kapoks. Bounds x/z `[-63, 63]`, y `[-1, 22]`, inside the
  authorized volume and well under the 125,000 cell budget.
- Blueprint identity SHA-256
  `0a0ad4784a0fe21ba6fa815498405bb43a446b25188b6f08230dfe67bb887777`.
- Engine: both seeds pass forward and reverse generation and cold and disk
  reload, eight passes, 21 and 22 emerged owners. All eight combined digests
  equal
  `b9966f25cd2bc571f66c826639078d436eed5d58493fc272a2953de9f1cf638a`. Every
  authored node name and param2 of ALL THREE settlements matches after
  generation and after reload, all 74 Hearthpine, 98 Dawnmere and 87 Kapok
  torches are lit, every destination and every main-road foot of all three
  starts is lit (Kapok's road read off its own `main_street` landmark, which
  runs to -z), soil outside the blueprints is present and the deliberate edit
  canary survives the reload. The boundary seed also proves filler-only
  restoration at the vertical owner boundary.
- Kapok architecture digest
  `cb3cd86d8b324571336458b2a59f56e7a79f6387384e741938d4f7353bcff2c3`.
- Fitted start heights on seed `531802985935182545`: Hearthpine y = 25,
  Dawnmere y = 17, **Kapok y = 20**. On seed `8675309`: Hearthpine y = 16,
  Dawnmere y = 21, **Kapok y = 17**.
- Final micro: LuaJIT and PUC 5.1.5 byte-identical at
  `50ecddf34daeee387c11026c77463a3a6bdb775f541428748fc015527b3c9ab9`.

## What the renders were changed for

The list is in the note, `docs/research/wp13-kapok.md`, section "What the
renders were changed for": the seven placeholder-coloured decor nodes, the
striped floor scatter, the roofs that buried their own walls, the stilts that
did not read, and the terrace props that were being placed inside the lodge.

## Scoped gaps

- `tools/wp40/r7/source_audit.sh` still pins `changed_production_lua` at 134
  and this increment adds two production Lua files. Four start lanes each add
  two, so the constant and the generated
  `tools/wp40/r7/changed_production_lua.txt` belong to the coordinator's
  fold-in rather than to any one lane.
- `tools/wp40/r7/{micro_kat_fixture,manifest_constructor_kat,runtime_fixture}`
  remain red on their pre-increment grounds, and `tools/wp13/final_micro.lua`
  still excludes the portable WP40 R7 micro-KAT body, both unchanged from the
  previous increment's evidence.
