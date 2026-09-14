# WP13 review fixes: static furnishings, settled panes, honest param2

Candidate commit: see `candidate.txt` (`4815f375`). This is the independent
review's six findings against the increment-3 building library, fixed and
guarded.

| Path | What it is |
| --- | --- |
| `static.txt` | `luac51 -p` and `SETGLOBAL` on every changed Lua file and on the whole `grug_*` and `tools` trees, the five plain-5.1 sweeps (scoped to the changed Lua, then repeated tree-wide for context), and `tools/check_fresh_server.py` |
| `kat-luajit.txt`, `kat-puc51.txt` | `library_kat`, `blueprint_kat` and `integration_fixture` on the frozen bytes, byte-identical under both interpreters |
| `final-micro/` | the single bounded final-byte process, run once per interpreter, with the input and interpreter hashes taken before and after the run (`inputs-before.sha256` equals `inputs-after.sha256`) |
| `engine-user-seed/` | headless Luanti 5.17.0, seed `531802985935182545`: two fresh worlds with opposite owner orders, each followed by a disk-only reload |
| `engine-boundary-seed/` | the same for seed `8675309`, which also exercises the vertical owner boundary at Stillgrave |
| `luanti-flatpak-launcher.sh` | the launcher handed to `tools/wp13/run_engine.sh`; the workstation has Luanti only as a Flatpak. It mounts the repository read-only, so the runner's output directory has to live outside the repository and is copied in afterwards |
| `renders/` | the review renders the fixes were judged on |
| `files.sha256` | every file above |

The KAT pair was produced with, from the repository root:

```sh
luajit -e 'local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) \
  io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n")'
```

and the same line under `tools/bin/lua51`.

## What each finding cost and what now guards it

| Finding | Before | After | Guard |
| --- | --- | --- | --- |
| HIGH-1 metadata furniture | 39 chests, 21 bookshelves, 15 vessel shelves, 9 furnaces, all without the `on_construct` bulk placement never runs | barrels, plain shelves, crock shelves and a cauldron-plus-torch-plus-flue hearth, none of which carry any callback | `library_kat` §3b: every palette name checked against the real registrations loaded by `tools/wp13/stub_registry.lua`; the four retired bindings must still fail the test |
| MEDIUM-2 pane shape | 11 windows written as `xpanes:pane_flat` where `update_pane` produces the connected `xpanes:pane` | `parts.resolve_panes` runs the exact rule over the finished pad; 6 panes settle on the connected node | `library_kat` §9 re-implements `update_pane` from the mod source over all 266 panes |
| LOW-3 param2 on plain cubes | 440 `default:pine_wood` and 144 `default:stonebrick` cells rotated despite `place_param2 = 0` | only orientation-bearing families rotate; 3,449 plain-cube cells at param2 0 | `library_kat` §8: `place_param2` honoured on 1,723 cells, `param2_kind` agrees with every registration, and no unoriented node carries param2 |
| LOW-4 torches on glass | 15 wall torches supported by `xpanes:pane_flat` | none; the parts refuse a support that is not an opaque full cube, and the callers slide along the wall | `library_kat` §10 over all 74 torches |
| LOW-5 curation cross-check | one retirement source, required roles only | both sources, every emitted name | `library_kat` §3: `retirement_sources 2`, `default:ladder_steel` and `default:steel_ingot` both in the roster |
| LOW-6 docstring and family roles | `node(role)` claimed to prevent unregistered names; `door`/`bed` were prefixes | docstring corrected; family roles refused by `node`, reachable only through `variant`/`names` | `library_kat` §3 exercises both refusals |

## Results

- Blueprint: 61,932 cells, 46,389 of them not air, 41 materials, 74 lights,
  1,232 oriented nodes, 9 reachable destinations, 10 doors, 10 rooms, 180
  pines, 15,588 reachable standing cells. Bounds x/z `[-63, 63]`, y
  `[-1, 12]`, inside the authorized volume and under the 125,000 cell budget.
- Engine: both seeds pass forward and reverse generation and cold and disk
  reload, eight passes in total. All eight architecture digests equal
  `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c`. Every
  authored node name and param2 matches after generation and after reload,
  all 74 torches are lit, every destination and every main-road foot is lit,
  soil outside the blueprint is present and the deliberate edit canary
  survives the reload. The boundary seed also proves filler-only restoration
  at the vertical owner boundary.
- Final micro: LuaJIT and PUC 5.1.5 are byte-identical at
  `0a84a3702c41782f64743db32649ed0d653fe555de4506dacbcb72ab425024b8`.

## Appearance

- Pines: a nine-to-eleven log trunk with a five-layer tapering crown on the
  proportions of `mods/BASE/default/schematics/pine_tree.mts` and
  `small_pine.mts`, so five to seven logs stand clear below the needles.
  `renders/trees-west.png` and either overview show the difference.
- Roofs: the forge hall and the community hall carry the stone-brick stair
  family through a new palette override (`palettes.new(race, overrides)`),
  so two of nine roofs are stone.

  The `grug_decor` cottages roof family was tried first and does not fit.
  `cottages_roof_*` ships three shapes -- roof, connector and flat -- and the
  WP13 rasteriser needs five: stair, OUTER corner, INNER corner, slab and
  ridge. Every eave corner of every gable and the whole of a hip roof are
  outer corners, and a cross gable's valleys are inner ones, so the cottages
  family cannot express a single Hearthpine roof without a new rasteriser
  that emits its own corner geometry. `castle_roofslate` is `raillike`, a
  flat connected sheet with no pitch at all, and is not a roof shape in this
  sense either. Changing the rasteriser is a redesign of `roofs.lua` and was
  not attempted here.

## Scoped gaps

- `tools/wp13/stub_registry.lua` does not load `grug_trees`. That mod reads
  real `.mts` schematics and inspects the decoded `size` field before it
  registers a node, so it cannot run without an engine-grade schematic
  reader. No current palette names a `grug_trees` node; the elf and undead
  palettes that will must wait for an engine-free node table in that mod, or
  carry an explicit entry in the registry loader. The reason is written at
  the point where the mod would have been listed.
- The portable WP40 R7 micro-KAT body is still not part of this pair, for the
  reason recorded in `tools/wp13/final_micro.lua` and in the previous
  increment's evidence: `tools/wp40/r7/node_semantics_fixture.lua` cannot
  resolve a palette that names `doors`, `beds`, `xpanes`, `wool` or
  `grug_decor` nodes. The live engine run covers the same property more
  strongly.
