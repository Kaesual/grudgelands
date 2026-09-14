# WP13 increment 5: Silverleaf Glade, the elf start

Candidate commit: see `candidate.txt`. The note for this increment is
[docs/research/wp13-silverleaf.md](../../../docs/research/wp13-silverleaf.md).

| Path | What it is |
| --- | --- |
| `static.sh`, `static.txt` | `luac51 -p` and `SETGLOBAL` on every changed Lua file and on the whole `grug_*` and `tools` trees, the five plain-5.1 sweeps (scoped to the changed Lua, then repeated tree-wide), and `tools/check_fresh_server.py` |
| `kat-luajit.txt`, `kat-puc51.txt` | `library_kat`, `blueprint_kat` and `integration_fixture` on the frozen bytes, byte-identical under both interpreters |
| `final-micro.sh`, `final-micro/` | the single bounded final-byte process, run once per interpreter, with the input and interpreter hashes taken before and after the run (`inputs-before.sha256` equals `inputs-after.sha256`) |
| `engine.sh` | the two engine invocations, one seed per call, with the shared-workstation guard that refuses to start while four headless servers are already running |
| `engine-user-seed/` | headless Luanti 5.17.0, seed `531802985935182545`: two fresh worlds with opposite owner orders, each followed by a disk-only reload |
| `engine-boundary-seed/` | the same for seed `8675309`, which also exercises the vertical owner boundary at Stillgrave |
| `luanti-flatpak-launcher.sh` | the launcher handed to `tools/wp13/run_engine.sh`; the workstation has Luanti only as a Flatpak and the user runs the GUI client at the same time, so the launcher REFUSES an empty or personal `LUANTI_USER_PATH` and pins `XDG_CACHE_HOME`/`XDG_DATA_HOME`/`XDG_CONFIG_HOME` into the profiler's own scratch tree |
| `renders/` | the review renders this increment was judged on |
| `files.sha256` | every file above |

The KAT pair was produced with, from the repository root:

```sh
luajit -e 'local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) \
  io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n")'
```

and the same line under `tools/bin/lua51`. The engine runs were

```sh
bash tools/wp13/evidence/20260914-silverleaf/engine.sh user     531802985935182545 32600
bash tools/wp13/evidence/20260914-silverleaf/engine.sh boundary 8675309            32640
```

one after the other, never at the same time: four WP13 start lanes share this
workstation, so `engine.sh` checks `pgrep -c -f '^luanti.bin --server'` and
refuses to start while four are already up, and the port bases are this lane's
own. The launcher mounts the repository read-only, so the runner's output
directory lives outside the repository and is copied in afterwards. The set of
`pgrep -x luanti.bin` PIDs was empty before each run and carried no
`--server` process after it, so no headless server was left behind and the
user's own GUI client was never touched.

## Hearthpine and Dawnmere are unchanged

| Property | `20260914-dawnmere-fixes` | Here |
| --- | --- | --- |
| Hearthpine blueprint identity | `e07ac54b…5100cf9ffb`, 61,932 cells | the same |
| Hearthpine `blueprint_kat` row | `61932 46389 41 74 1232 9 10 10 180 15588` | identical |
| Hearthpine engine digest | `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c` | the same |
| Dawnmere blueprint identity | `66c7f811…54354f74`, 66,343 cells | the same |
| Dawnmere `blueprint_kat` row | `66343 44863 52 98 1467 9 12 10 27 15411` | identical |
| Dawnmere engine digest | `cdbc03239c181f1f41caf1a4a2bd851753c17f2b04e2df95037d1e62893ef4f9` | the same |

The engine receipt lines carry `hearthpine_digest=`, `dawnmere_digest=` and
`silverleaf_digest=` separately, plus the combined `digest=` the runner
compares across the four passes of a seed.

## Results

See `RESULTS.md`.

## What changed in the shared test tooling

- `tools/wp13/engine_cases.lua` counts a start's lights from its own
  `landmarks.lights` instead of from two hard-coded torch names, so the check
  is exact for a start whose lamps are candles, hanging lanterns and glowing
  blocks. The set is identical for Hearthpine and Dawnmere, whose receipts are
  unchanged.
- The same file's structural owner ceiling was `8 * #roster`, from a comment
  claiming a 127-node span covers at most two owner columns. An 80-node grid
  cuts a 127-node span into up to three columns, and the authorized y range
  into up to two levels, so the ceiling is `18 * #roster`. The old number held
  for the first two anchors by accident of their offsets and failed on the
  boundary seed the moment a third start fitted across an owner floor.
- `tools/wp13/blueprint_kat.lua` gained an optional per-start `light_support`
  rule (`above` for a `group:attached_node = 4` lamp, `self` for a full cube),
  because the wallmounted param2 is not how every race's lamp is carried.
- `tools/wp13/stub_registry.lua` loads `grug_trees` and `grug_nodes`. The elf
  palette is the first to name them; the undead palette will name the same two
  mods, so that lane's copy of this edit and this one are the same hunk.
