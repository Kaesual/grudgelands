# WP13 increment 4: Dawnmere Fields, and one seam for every start

Candidate commit: see `candidate.txt`. The note for this increment is
[docs/research/wp13-dawnmere-fields.md](../../../docs/research/wp13-dawnmere-fields.md).

| Path | What it is |
| --- | --- |
| `static.txt` | `luac51 -p` and `SETGLOBAL` on every changed Lua file and on the whole `grug_*` and `tools` trees, the five plain-5.1 sweeps (scoped to the changed Lua, then repeated tree-wide for context), and `tools/check_fresh_server.py` |
| `kat-luajit.txt`, `kat-puc51.txt` | `library_kat`, `blueprint_kat` and `integration_fixture` on the frozen bytes, byte-identical under both interpreters |
| `final-micro/` | the single bounded final-byte process, run once per interpreter, with the input and interpreter hashes taken before and after the run (`inputs-before.sha256` equals `inputs-after.sha256`) |
| `engine-user-seed/` | headless Luanti 5.17.0, seed `531802985935182545`: two fresh worlds with opposite owner orders, each followed by a disk-only reload |
| `engine-boundary-seed/` | the same for seed `8675309`, which also exercises the vertical owner boundary at Stillgrave |
| `luanti-flatpak-launcher.sh` | the launcher handed to `tools/wp13/run_engine.sh`; the workstation has Luanti only as a Flatpak, and the user runs the GUI client at the same time, so the launcher REFUSES an empty or personal `LUANTI_USER_PATH` and pins `XDG_CACHE_HOME`/`XDG_DATA_HOME`/`XDG_CONFIG_HOME` into the profiler's own scratch tree |
| `renders/` | the review renders this increment was judged on, plus `hearthpine-unchanged.png` |
| `files.sha256` | every file above |

The KAT pair was produced with, from the repository root:

```sh
luajit -e 'local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) \
  io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n")'
```

and the same line under `tools/bin/lua51`. The engine runs were

```sh
WP13_SEED=531802985935182545 WP13_PORT_BASE=32460 WP40_PROFILE_TIMEOUT=540 \
  timeout --kill-after=30 600 bash tools/wp13/run_engine.sh \
  /tmp/grug-wp13-dawnmere-user-$$ \
  tools/wp13/evidence/20260914-dawnmere/luanti-flatpak-launcher.sh
```

and the same with `WP13_SEED=8675309 WP13_PORT_BASE=32500`. The launcher
mounts the repository read-only, so the runner's output directory lives
outside the repository and is copied in afterwards. The set of
`pgrep -f luanti.bin` PIDs was taken before and after each run and is
identical, so no headless server was left behind and the user's own client
was never touched.

## Hearthpine is unchanged

| Property | Increment 3 (`20260914-hearthpine-fixes`) | Here |
| --- | --- | --- |
| Blueprint identity SHA-256 | `e07ac54b…5100cf9ffb` | the same |
| Cells | 61,932 | 61,932 |
| Engine architecture digest | `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c` | the same, on both seeds, both owner orders, cold and disk |
| `blueprint_kat` row | `61932 46389 41 74 1232 9 10 10 180 15588` | identical |

The engine receipt lines carry `hearthpine_digest=` and `dawnmere_digest=`
separately, plus the combined `digest=` the runner compares across the four
passes of a seed.

## Results

- Dawnmere: 66,291 cells, 44,805 of them not air, 52 materials, 97 lights,
  1,446 oriented nodes, 9 reachable destinations, 12 doors, 10 rooms, 27 oak
  standards, 1,555 planted crop cells and 216 hedgerow COLUMNS, which are 432
  cells (a `bush_stem` at y = 1 under a `bush_leaves` at y = 2):
  `dressing.hedge_line` returns columns, so the `hedge_cells` landmark counts
  columns and not cells, and an earlier wording here read "216 hedge cells".
  Bounds x/z
  `[-63, 63]`, y `[-1, 17]`, inside the authorized volume and well under the
  125,000 cell budget.
- Engine: both seeds pass forward and reverse generation and cold and disk
  reload, eight passes, fifteen and sixteen emerged owners. All eight
  combined digests equal
  `17f1381e5c29f332da126abfb353b07229fb8e2c0a716cf7f12e1a408cba40f2`. Every
  authored node name and param2 of BOTH settlements matches after generation
  and after reload, all 74 Hearthpine and 97 Dawnmere torches are lit, every
  destination and every main-road foot of both starts is lit, soil outside
  the blueprints is present and the deliberate edit canary survives the
  reload. The boundary seed also proves filler-only restoration at the
  vertical owner boundary.
- Fitted start heights on seed `531802985935182545`: Hearthpine y = 25,
  Dawnmere y = 17. On seed `8675309`: Hearthpine y = 16, Dawnmere y = 21.
- Final micro: LuaJIT and PUC 5.1.5 byte-identical at
  `2a725edd600e95fc4cd9d0027d0cd4ffa1d54de3dddf7d48e71a8868f73e0016`.

## What the renders were changed for

1. The first meadow scattered bare-earth and gravel patches over the whole
   128-node pad; at overview scale they read as litter, not as use. The
   patches are now confined to a 64-node worn core around the hamlet and the
   rest of the pad is unbroken turf.
2. Two of the eight crop fields silently failed their clearance test, because
   the smithy wing and the tollhouse apron reached into them. Both were moved
   off the buildings and two more fields were added on the south edge, taking
   the planted cells from 859 to 1,555.
3. The orchard placed ten trees on its first pass. It is now eight blocks
   with tighter spacing, and the standards read as orchard rows near the
   hamlet and as field-corner shade further out (27 trees).
4. The meeting hall had a plank roof, which made the civic core invisible
   from the fields. It now carries the brick stair family, like the
   tollhouse, and the belfry's own little hip roof is brick too.
5. The cottages and the barn were built at wall height 4 and 5, and their
   roofs swallowed the walls at every camera angle; they are 5 and 6 now, so
   the half-timbering, the shutters and the brick base course are visible
   from outside.

## Scoped gaps

- `tools/wp40/r7/{micro_kat_fixture,manifest_constructor_kat,runtime_fixture}`
  still call the pre-increment `r7_content`/`r7_hearthpine` signatures. Those
  three fixtures were ALREADY failing on this increment's base commit
  (`node_semantics_fixture.lua` cannot resolve a palette naming `doors`,
  `beds`, `xpanes`, `wool` or `grug_decor` -- the WP40-lane follow-up
  recorded in the previous increment's evidence), so they were left untouched
  rather than edited without a way to run them.
- `tools/wp13/final_micro.lua` still excludes the portable WP40 R7 micro-KAT
  body, for the same reason and as recorded in that file.
