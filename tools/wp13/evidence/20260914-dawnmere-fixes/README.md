# WP13 increment 4: the independent review's fixes

The increment is
[20260914-dawnmere](../20260914-dawnmere/); its note is
[docs/research/wp13-dawnmere-fields.md](../../../../docs/research/wp13-dawnmere-fields.md).
Candidate commit: see `candidate.txt`.

| Path | What it is |
| --- | --- |
| `static.sh`, `static.txt` | `luac51 -p` and `SETGLOBAL` on every Lua file these fixes changed and on the whole `grug_*` and `tools` trees, the five plain-5.1 sweeps (scoped, then tree-wide), and `tools/check_fresh_server.py` |
| `kat-luajit.txt`, `kat-puc51.txt` | `library_kat`, `blueprint_kat` and `integration_fixture` on the frozen bytes, byte-identical under both interpreters |
| `final-micro.sh`, `final-micro/` | the single bounded final-byte process, once per interpreter, with the input set hashed before and after (`inputs-before.sha256` equals `inputs-after.sha256`) |
| `engine-user-seed/` | headless Luanti 5.17.0, seed `531802985935182545`: two fresh worlds with opposite owner orders, each followed by a disk-only reload |
| `engine-boundary-seed/` | the same for seed `8675309`, which also exercises the vertical owner boundary |
| `luanti-flatpak-launcher.sh` | the launcher handed to `tools/wp13/run_engine.sh`, unchanged from the increment: it REFUSES an empty or personal `LUANTI_USER_PATH` and pins every XDG directory into the profiler's own scratch tree, because the workstation has Luanti only as a Flatpak and the user runs the GUI client at the same time |
| `renders/` | the review renders: the village green, the cart beside the market stall, the farmyard, and the whole pad |
| `files.sha256` | every file above |

Commands, from the repository root:

```sh
bash tools/wp13/evidence/20260914-dawnmere-fixes/static.sh
luajit -e 'local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) \
  io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n")'
# and the same line under tools/bin/lua51
bash tools/wp13/evidence/20260914-dawnmere-fixes/final-micro.sh
WP13_SEED=531802985935182545 WP13_PORT_BASE=32460 WP40_PROFILE_TIMEOUT=540 \
  timeout --kill-after=30 600 bash tools/wp13/run_engine.sh \
  /tmp/grug-wp13-fixes-a2 \
  tools/wp13/evidence/20260914-dawnmere-fixes/luanti-flatpak-launcher.sh
# and the same with WP13_SEED=8675309 WP13_PORT_BASE=32500 -> /tmp/grug-wp13-fixes-b2
```

The launcher mounts the repository read-only, so both runner output
directories live in `/tmp` and were copied in afterwards. `pgrep luanti.bin`
was empty before and after every run: no headless server of this session was
left behind, and the user's own client was never touched.

## Hearthpine is still unchanged

| Property | Increment 4 | Here |
| --- | --- | --- |
| Blueprint identity SHA-256 | `e07ac54b…5100cf9ffb` | the same |
| Cells | 61,932 | 61,932 |
| Engine architecture digest | `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c` | the same, on both seeds, both owner orders, cold and disk |
| `blueprint_kat` row | `61932 46389 41 74 1232 9 10 10 180 15588` | identical |

`hearthpine.lua` did change (`pairs` -> an ordered `ipairs` walk of the placed
plots), so the identity above is the proof that the change is inert: the TSV
dump of `r7_hearthpine_blueprint.lua` has SHA-256
`760e066434284475957a399336f64b577daf3aecff936902a4a2cb46ebfe8ec9` before and
after.

## Results

- Dawnmere: 66,343 cells (was 66,291), 44,863 of them not air, 52 materials,
  98 lights, 1,467 oriented nodes, 9 reachable destinations, 12 doors, 10
  rooms, 27 oak standards, 1,555 planted crop cells, 216 hedgerow columns
  (432 cells). Bounds x/z `[-63, 63]`, y `[-1, 17]`. Blueprint identity
  SHA-256 `66c7f8118b0b761d8e7c009f72753e9ec7578c1cb2b6d464f55ca97d54354f74`.
- Loose props now in the bytes, all of them asserted by the composition and
  counted by `blueprint_kat`: 3 hand carts (each two bearer logs, two wheels
  and a barrel riding ON a bearer), 12 wagon wheels, 27 straw bales, 24
  barrels, 25 stepping stones. Before the fixes, three carts, two standalone
  wheels, four bale stacks, four kerbs, four crates, three settles and a wood
  pile were silently skipped, and one barrel floated at `(-8, 2, 7)`.
- Engine: both seeds pass forward and reverse generation and cold and disk
  reload, eight passes, fifteen and sixteen emerged owners. All eight
  combined digests equal
  `cf0390e03f2f52be7a5e6646587dc624c89f9e6d0c32cbe57bc8f91483866924`;
  Dawnmere's own architecture digest is
  `cdbc03239c181f1f41caf1a4a2bd851753c17f2b04e2df95037d1e62893ef4f9` and
  Hearthpine's is unchanged. All 74 Hearthpine and 98 Dawnmere torches are
  lit, the edit canary survives the reload, and the boundary seed still
  proves filler-only restoration at the vertical owner boundary.
- Fitted start heights, seed `531802985935182545`: Hearthpine y = 25,
  Dawnmere y = 17; seed `8675309`: Hearthpine y = 16, Dawnmere y = 21 -- the
  same as the increment's.
- Final micro: LuaJIT and PUC 5.1.5 byte-identical at
  `74074883819a53d434733f400541ae3220fbb734567aa472e52834087a48e68a`.
- The 71-name union palette sorts identically under Lua's `<` and under byte
  order, which is why the byte-order fix moved no byte. (Note for whoever
  reads the fix: Lua never calls `setlocale`, so `strcoll` is the C locale
  unless something calls `os.setlocale` -- the hazard was latent, not live.)

## What is NOT fixed here

`tools/wp40/r7/source_audit.sh` still fails, for reasons older than this
review. The changed-production roster and its expected population are now
correct and consistent; the next gate, the deleted-legacy-Lua population, is
7 in the script and 12 in the tree, and the `final` phase's durable micro-KAT
binding pins the old roster's SHA-256 and 74 executed modules. Both belong to
the WP40 lane that froze them. With the deleted count raised to 12 in a copy
of the script outside the repository, the prefreeze phase PASSES end to end
(`source_set_sha256=1c702799c6a4528a51a4c5273dd7e86eefaaf9612a7e1242d8d3ceb06da6aa0c`).
