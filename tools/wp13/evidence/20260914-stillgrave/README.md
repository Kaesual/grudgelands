# WP13 increment 5, undead lane: Stillgrave Hollow

Candidate commit: see `candidate.txt`. The note for this lane is
[docs/research/wp13-stillgrave.md](../../../docs/research/wp13-stillgrave.md).

| Path | What it is |
| --- | --- |
| `static.sh`, `static.txt` | `luac51 -p` and `SETGLOBAL` on every changed Lua file and on the whole `grug_*` and `tools` trees, the five plain-5.1 sweeps (scoped to the changed Lua, then repeated tree-wide for context), `py_compile` on the one changed Python file, and `tools/check_fresh_server.py` |
| `kat-luajit.txt`, `kat-puc51.txt` | `library_kat`, `blueprint_kat` and `integration_fixture` on the frozen bytes, byte-identical under both interpreters |
| `final-micro.sh`, `final-micro/` | the single bounded final-byte process, run once per interpreter, with the input and interpreter hashes taken before and after the run (`inputs-before.sha256` equals `inputs-after.sha256`) |
| `engine-user-seed/` | headless Luanti 5.17.0, seed `531802985935182545`: two fresh worlds with opposite owner orders, each followed by a disk-only reload |
| `engine-boundary-seed/` | the same for seed `8675309`, which also exercises the vertical owner boundary at Stillgrave |
| `luanti-flatpak-launcher.sh` | the launcher handed to `tools/wp13/run_engine.sh`; the workstation has Luanti only as a Flatpak, and the user runs the GUI client at the same time, so the launcher REFUSES an empty or personal `LUANTI_USER_PATH` and pins `XDG_CACHE_HOME`/`XDG_DATA_HOME`/`XDG_CONFIG_HOME` into the profiler's own scratch tree |
| `renders.sh`, `renders/` | the review renders this lane was judged on |
| `files.sha256` | every file above |

The KAT pair was produced with, from the repository root:

```sh
luajit -e 'local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) \
  io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n")'
```

and the same line under `tools/bin/lua51`. The engine runs were

```sh
WP13_SEED=531802985935182545 WP13_PORT_BASE=32700 WP40_PROFILE_TIMEOUT=540 \
  timeout --kill-after=30 600 bash tools/wp13/run_engine.sh \
  /tmp/grug-wp13-stillgrave-user-$$ \
  tools/wp13/evidence/20260914-stillgrave/luanti-flatpak-launcher.sh
```

and the same with `WP13_SEED=8675309 WP13_PORT_BASE=32740`. The launcher
mounts the repository read-only, so the runner's output directory lives
outside the repository and is copied in afterwards. `pgrep -f luanti.bin` was
taken before and after each run; after both runs it was empty, so no headless
server was left behind and the user's own client was never touched. Three
other WP13 lanes share the workstation, so the runs waited for
`pgrep -c -f '^luanti.bin --server'` to be below four and the two seeds ran
one after the other, never at the same time.

## Hearthpine and Dawnmere are unchanged

| Property | `20260914-dawnmere-fixes` | Here |
| --- | --- | --- |
| Hearthpine blueprint identity | `e07ac54b…5100cf9ffb`, 61,932 cells | the same |
| Dawnmere blueprint identity | `66c7f811…d54354f74`, 66,343 cells | the same |
| Hearthpine architecture digest | `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c` | the same on both seeds, both owner orders, cold and disk |
| Dawnmere architecture digest | `cdbc03239c181f1f41caf1a4a2bd851753c17f2b04e2df95037d1e62893ef4f9` | the same, likewise |
| `blueprint_kat` rows | `61932 46389 41 74 1232 9 10 10 180 15588` / `66343 44863 52 98 1467 9 12 10 27 15411` | identical field for field; one column is new for every start (`ruins`, 0 for both) |
| `library_kat` rows | identical | identical; the corpus lines grew a third start and `registry_nodes` went 761 → 779 because `stub_registry` now loads `grug_trees` and `grug_nodes` |

## Results

- Stillgrave: 51,597 cells, 37,667 of them not air, 45 materials, 75 lights,
  1,300 oriented nodes, 5 reachable destinations, 7 doors, 8 rooms of which 2
  are ruins, 74 gravewoods, 162 grave markers, 347 bone piles, 616 dead
  shrubs, 18 stepping stones, 14 barrels, 13 ivy tendrils, 7 cobwebs. Bounds
  x/z `[-63, 63]`, y `[-1, 12]`. Blueprint identity SHA-256
  `9c08a5c80194ae2aabc667d8dcb9e6888033bc41f557ce78ff6a12cd3d29627f`.
- Engine: both seeds pass forward and reverse generation and cold and disk
  reload — eight passes, twenty-one and twenty-seven emerged owners. All eight
  combined digests equal
  `efc47fd2f46fe398ede2c7c071141f4a9f40e65cfe0f7729f463df1f856cc923`.
  Every authored node name and param2 of ALL THREE settlements matches after
  generation and after reload, all 74 Hearthpine, 98 Dawnmere and 75
  Stillgrave lights are lit, every destination and every foot of every
  start's five-wide route is lit, soil outside the blueprints is present and
  the deliberate edit canary survives the reload. The boundary seed also
  proves the vertical owner boundary at Stillgrave.
- Fitted start heights on seed `531802985935182545`: Hearthpine y = 25,
  Dawnmere y = 17, Stillgrave y = 54. On seed `8675309`: y = 16, y = 21 and
  y = 48.
- Final micro: LuaJIT and PUC 5.1.5 byte-identical at
  `555344896071d34045c5b2051ce395b0079eaa6788bf26683e180f91593122dd`, the
  same digest as the KAT pair.

## The road runs south

`kragmar_stillgrave_hollow` carries a `start:south` gate
(`station:kragmar_stillgrave_hollow:start_south`, x = -1800, z = 2486, the
anchor's z minus 64), so this pad's five-wide route, gate and watchtower lie
toward **-z**. `blueprint_kat` and `engine_cases` no longer assume +z: both
read the route out of the `main_street` landmark every start already
publishes. Hearthpine's and Dawnmere's landmarks are unchanged, which is why
their digests are.

## What the renders were changed for

1. `dressing.undergrowth`'s selector and its role test are not independent
   (7x + 11z is 3(x + z) modulo 4), so at density 4 it only ever writes the
   `undergrowth` role. In a blight basin that meant 3,300 bone piles over the
   whole pad. The Hollow sows its own flora instead (347 bone piles, 616 dead
   shrubs); the two frozen settlements keep the routine exactly as it is.
2. The ruins drew their wall heights per cell and read as crenellation, on a
   solid band of red rubble. They draw them on a three-node lattice now,
   stand a course taller, and keep the mossy-cobble apron the other plots on
   the lane have.
3. Near-black masonry under near-black boards under a black roof gave every
   building one silhouette and hid the watchtower's parapet entirely. The
   wall accent is `default:mossycobble` now.
4. The crypt-chapel wore a pale roof over dark walls and read as a grey hip
   roof on short legs. It has the hamlet's black roof and pale stone walls
   now, at roof rise 3.
5. The gravecourt was an empty grey rectangle: it has the cairn on its black
   plinth, six kerbed plots in the paving and four fewer lamp standards, and
   the well moved off the chapel's sight line.

## Scoped gaps

- `tools/wp40/r7/{micro_kat_fixture,manifest_constructor_kat,runtime_fixture}`
  were ALREADY failing on this lane's base commit for the reason the previous
  two increments recorded, so they were left untouched rather than edited
  without a way to run them.
- `tools/wp13/final_micro.lua` still excludes the portable WP40 R7 micro-KAT
  body, for the same reason and as recorded in that file.
