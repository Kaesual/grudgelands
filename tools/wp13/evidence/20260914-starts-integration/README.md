# WP13 starts integration — `wp13-starts`

The four parallel start lanes merged into one branch. Each lane built its
settlement on the same shared WP13 library, so every lane touched the same nine
files; this record is the proof that no start's bytes moved in the merge except
where a fix on `main` was deliberately carried into a lane.

## Per start

| Start | Lane branch | Identity (lane tip) | Dump SHA before merge | Dump SHA after merge |
| --- | --- | --- | --- | --- |
| Hearthpine | `main` (increments 1–3) | `239f462` | `760e0664…8ec9` | `760e0664…8ec9` |
| Dawnmere | `main` (increment 4 + `239f462`) | `239f462` | `3bba042d…c832` | `3bba042d…c832` |
| Silverleaf | `worktree-agent-a91e5457962f4b19b` | `79582d0` | `d756a3fb…4d10` (lane) | `081bded8…0b5b` |
| Stillgrave | `worktree-agent-a3b37d689ba57adb9` | `286c3ca` | `7dd3dbbd…c3ff` | `7dd3dbbd…c3ff` |
| Kapok | `worktree-agent-a0ef785034b3a5b50` | `11889e6` | `a73e0ede…a9c8` | `a73e0ede…a9c8` |

Full digests: `dumps.txt`. Reproduce with `dump.sh` (it dumps each start's
blueprint wrapper, which pulls the whole WP13 library, so the digest covers
every file a composition reads).

### Why Silverleaf's bytes moved

`239f462` ("Place the chapel dais opposite the door") landed on `main` **after**
the elf lane branched at `90d19ef`. It is a user-directed playtest fix to the
shared chapel kit, and Silverleaf's `moon_shrine` is a `chapel`, so the fix
applies to it too. The move was measured, not assumed: an elf-lane tree carrying
**only** that commit's two file changes dumps Silverleaf as
`081bded82d3c04864301fc3519cecd210f16c2b21905bd35fa80d5c80ecb0b5b` — bit for bit
the merged result. The cell diff against the lane is 68 lines, all of them the
shrine's dais, its bench rows, its shelves and its two dais lamps moving from the
door end of the runner to the far end. Nothing else in the elf lane changed.

## Conflicts resolved

Every conflict was two lanes adding to the same table, list or hunk. Rows
marked "(troll)" are the files the elf merge did not conflict in.

| File | Both sides added | Kept |
| --- | --- | --- |
| `wp13/buildings.lua` | elf: `roof`/`ridge_axis or "x"`/`rise` from `spec`; undead: the same plus `kit`, `kit_spec` (main's dais fix) and `chimneys` from `spec` | the undead form, which is the union; `spec.ridge_axis` with no `or "x"` because `buildings.lua:126` already falls back to `"x"` |
| `wp13/layout.lua` | undead `M.plant_gravewood`; elf `M.glade` + `M.plant_grove` | both functions, elf first |
| `wp13/palette.lua` | undead `cobweb`/`ivy`/`pillar` optional roles + `M.races.undead`; elf `light_beacon`/`light_hanging` optional roles + `M.races.elf` | one merged sorted `M.optional`, both race tables, elf before undead (roster order) |
| `wp13/parts.lua` | undead `PARAM2_KIND` candle/ivy/workbench/dry_shrub + `PANE_CONNECTS`/`FULL_SOLID` gravewood rows; elf the darkage stair/slab facedir family + silverwood rows | both, `FULL_SOLID` de-duplicated (`wool:brown` was added twice) and re-sorted |
| `wp40/r7_manifest.lua` | one `FIELD_ORDER` block and one `SETTLEMENT_ORDER` row each | both, silverleaf (anchor 3) before stillgrave (anchor 4) in both lists |
| `wp40/r7_settlement.lua` | one `M.roster` row each | both, in the same anchor order |
| `tools/wp13/blueprint_kat.lua` | one `SETTLEMENTS` spec row each; elf generalised the light-support rule (`spec.light_support`, `light_carrier`), undead generalised the light node names into `spec.light` | both spec rows (silverleaf first) and both generalisations — they compose: `LIGHT` comes from `spec.light`, the carrier rule from `spec.light_support` |
| `tools/wp13/engine_cases.lua` | elf: owner cap `18 * #roster` with its `ceil((127 + 79) / 80) = 3` derivation; undead: `12 * #starts` plus the note on the filler-boundary seed. Both lanes independently added a light-landmark set (`is_light` / `light_at`) and both routed the street check through the `main_street` landmark | the elf derivation and both caps (`18 * #roster`, `18 * #roster + 2`), the undead seed note folded in, **one** light set (`light_at`), and the `main_street` road generalisation |
| `wp13/dressing.lua` (troll) | undead `gravewood`/`grave`/`graveyard`/`cobweb`/`ivy`/`rubble_heap`/`blight_flora` and elf `lantern_post`/`lantern_pillar`/`columnar`; troll `jungle_tree`/`emergent`/`totem`/`drying_rack`/`rope_fall`/`lantern`/`walkway`/`stair_up`/`basin_flora` | every function of both sides; verified purely additive in both directions (zero deleted lines against either parent) |
| `wp13/interiors.lua` (troll) | main's chapel-dais fix; troll `M.kits.lodge` and `M.kits.smoker` | both; the troll lane never saw the dais fix, and Kapok builds no chapel |
| `tools/wp13/library_kat.lua` (troll) | undead: per-start `connected_panes` accumulated into `corpus_connected_panes` + a corpus-level assertion; troll: a `glazed`/`open` window-vocabulary split so a race with open bars is not forced to glaze | both. The troll lane's per-start `connected_panes > 0` was dropped in favour of the undead lane's corpus-level assertion — Stillgrave bars every opening with a single flat face and legitimately writes 140 panes and no junction, which the per-start rule would have failed |
| `tools/wp13/extract_tiles.py` (troll) | one `MANUAL_OVERRIDES` block each | both, no key collisions |
| `tools/wp13/node_tiles.json` (troll) | one generated file each | **regenerated** from the merged tree (`extract_tiles.py --root mods --root reference_projects/minetest_game/mods --relative-to .`) and checked to be the exact union: 453 nodes, none missing, every differing entry equal to the other side's override |
| `tools/wp13/stub_registry.lua` | both lanes added `grug_trees` and `grug_nodes` to `SOURCES` and `MOD_GLOBALS`, and both stubbed `read_schematic` (zero volume vs unit volume) | one entry each, elf's `seed = "grug_trees"`, the merged `MOD_GLOBALS`, and the unit-volume stub — `grug_trees` reads `size.y` only for a runtime growth height, never for a node definition |

## Checks

| Gate | Result |
| --- | --- |
| `tools/bin/luac51 -p` on every changed Lua | PASS (19 files individually, plus `mods/*/grug_*` and `tools` tree-wide) |
| SETGLOBAL | 0 on every changed file |
| Five plain-5.1 sweeps, changed files | zero hits |
| Five plain-5.1 sweeps, `wp13/` + changed `wp40` + `tools/wp13` | only the six pre-existing `os.exit` lines in `tools/wp13/dump_blueprint.lua`, a developer tool that never runs in the engine sandbox |
| `tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `python3 -m py_compile tools/wp13/extract_tiles.py`, `node_tiles.json` parses | PASS, 453 nodes |
| `library_kat` + `blueprint_kat` + `integration_fixture`, LuaJIT vs PUC 5.1 | byte-identical, `e4d2cb264879918e…` |
| `atmosphere_kat`, LuaJIT vs PUC 5.1 | `OK` under both, identical apart from the interpreter banner the KAT prints on line 2 |
| `tools/wp13/final_micro.lua` pair | byte-identical, `e4d2cb264879918e77ba01405ee0b69cf67b9a748879baff4476286938a4c290` |
| Engine gate | **not run here** — the coordinator runs one combined engine gate over all six starts |

Composed integration row: `composed/5/147` — five starts, 147 names in the one
shared opcode-37 settlement palette.

Scripts: `static.sh`, `kat.sh`, `dump.sh`, `final-micro.sh`. Outputs:
`static.txt`, `kat-luajit.txt`, `kat-puc51.txt`, `atmosphere-luajit.txt`,
`atmosphere-puc51.txt`, `dumps.txt`, `final-micro/`.
