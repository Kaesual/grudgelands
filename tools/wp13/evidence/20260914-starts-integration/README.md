# WP13 starts integration — `wp13-starts`

The four parallel start lanes merged onto `main` in one branch. Every lane
built its settlement on the same shared WP13 library, so every lane touched the
same files; this record is the proof that no start's bytes moved in the merge
except where a fix already on `main` was deliberately carried into a lane.

Merge order: Stillgrave (already on the branch), then Silverleaf, then Kapok,
then Sunscar — one `git merge --no-ff` and one commit each.

## Per start

| Start | Race | Anchor | Lane branch | Lane tip | Dump SHA on the lane | Dump SHA after the merge |
| --- | --- | --- | --- | --- | --- | --- |
| Hearthpine | dwarf | 1 | `main` (increments 1–3) | `239f462` | `760e0664…8ec9` | `760e0664…8ec9` |
| Dawnmere | human | 2 | `main` (increment 4 + `239f462`) | `239f462` | `3bba042d…c832` | `3bba042d…c832` |
| Silverleaf | elf | 3 | `worktree-agent-a91e5457962f4b19b` | `79582d0` | `d756a3fb…4d10` | `081bded8…0b5b` |
| Stillgrave | undead | 4 | `worktree-agent-a3b37d689ba57adb9` | `286c3ca` | `7dd3dbbd…c3ff` | `7dd3dbbd…c3ff` |
| Sunscar | orc | 5 | `worktree-agent-aa04336c64359d367` | `7c0df63` | `14bbca78…5f6b` | `14bbca78…5f6b` |
| Kapok | troll | 6 | `worktree-agent-a0ef785034b3a5b50` | `11889e6` | `a73e0ede…a9c8` | `a73e0ede…a9c8` |

Full digests in `dumps.txt`; reproduce with `dump.sh`. The dumper loads each
start's blueprint wrapper, which pulls the whole WP13 library, so the digest
covers every file the composition reads — it is the identity check for "this
start's bytes did not move".

Each lane's own integration identity also survives unchanged:
`e07ac54bec01e662…` (Hearthpine), `e2c143c67f9697f8…` (Silverleaf),
`9c08a5c80194ae2a…` (Stillgrave), `dcb6e82cac6dcc36…` (Sunscar),
`0a0ad4784a0fe21b…` (Kapok) — each identical to the digest in that lane's own
`kat-luajit.txt`.

### The one deliberate byte change: Silverleaf

`239f462` ("Place the chapel dais opposite the door") landed on `main` **after**
all four lanes branched at `90d19ef`. It is a user-directed playtest fix to the
shared chapel kit. Silverleaf's `moon_shrine` is a `chapel`, so the fix reaches
it; Sunscar and Kapok build no chapel, and Stillgrave's lane already carried the
fix.

The move was measured, not assumed: an elf-lane tree carrying **only** that
commit's two file changes dumps Silverleaf as
`081bded82d3c04864301fc3519cecd210f16c2b21905bd35fa80d5c80ecb0b5b` — bit for bit
the merged result. The cell diff against the lane is 68 lines, all of them the
shrine's dais, its bench rows, its shelves and its two dais lamps moving from
the door end of the runner to the far end.

## Conflicts resolved

Every conflict was two or more lanes adding to the same table, list or hunk.
The rule throughout: keep both sides in the fixed roster order (hearthpine,
dawnmere, silverleaf, stillgrave, sunscar, kapok — anchor order), de-duplicate
identical additions, and where two lanes generalised the same function
differently, merge the behaviours instead of picking one.

| File | What the lanes added | What was kept |
| --- | --- | --- |
| `wp13/buildings.lua` | elf/undead: `roof`, `ridge_axis`, `rise`, `kit`, `kit_spec`, `chimneys` read from `spec` in `chapel`; orc: `spec.roof` and `spec.wing_wall_h` in `workshop`, `spec.roof` in `hall` | the union of all of them. `spec.ridge_axis` keeps no `or "x"` because `buildings.lua:126` already falls back to `"x"`; every added default is the value the literal had, so the frozen starts do not move |
| `wp13/dressing.lua` | one vocabulary of parts per lane (gravewood/graves/cobweb/ivy/rubble/blight flora; lantern post/lantern pillar/columnar; jungle tree/emergent/totem/drying rack/rope fall/lantern/walkway/stair up/basin flora; the orc plant-param2 call sites) | every function of every lane. Verified purely additive in both directions against each parent: zero deleted lines |
| `wp13/interiors.lua` | main's chapel-dais fix; troll `M.kits.lodge` and `M.kits.smoker`; the orc kits | all of them |
| `wp13/layout.lua` | undead `plant_gravewood`; elf `glade` + `plant_grove`; troll `basin` | all four functions |
| `wp13/palette.lua` | one race table and its own optional roles per lane | one merged, sorted `M.optional` literal (the troll lane's append-loop and the orc lane's `cargo` folded into it) and all six race tables in roster order |
| `wp13/parts.lua` | `PARAM2_KIND`, `PANE_CONNECTS` and `FULL_SOLID` rows per lane; the undead `Buffer:put` fallback `M.place_param2`; the orc lane's identical `M.plant_param2` | all rows, **de-duplicated** — `wool:brown`, `default:mossycobble`, `walls:mossycobble`, `grug_decor:darkage_serpentine`, `grug_decor:xdecor_candle` and `default:dry_shrub` had each been added by two lanes. One param2 helper survives, the engine-named `M.place_param2`; the orc lane's two call sites were renamed to it (same table, same default, so the same bytes) |
| `wp40/r7_manifest.lua` | one `FIELD_ORDER` block and one `SETTLEMENT_ORDER` row per lane | all six, both lists in anchor order |
| `wp40/r7_settlement.lua` | one `M.roster` row per lane | all six, in anchor order |
| `tools/wp13/blueprint_kat.lua` | one `SETTLEMENTS` spec row per lane; elf: `spec.light_support` + `light_carrier`; undead: the light node names moved into `spec.light`; troll: `prop_mode` with a `"ceiling"` kind; three lanes independently rewrote the road check to read the `main_street` landmark | all six spec rows and all four generalisations — they compose: `LIGHT` comes from `spec.light`, the carrier rule from `spec.light_support`, prop support from `prop_mode`, and the road from `main_street` with the strictest of the three extent assertions (`== 63`, which every start satisfies) |
| `tools/wp13/engine_cases.lua` | elf/troll/orc: the owner cap `18 * #roster` with its `ceil((127 + 79) / 80) = 3` derivation; undead: the filler-boundary seed note; orc: the control population scaled to `7 * #starts`; several lanes: the `main_street` road route; two lanes: a light-landmark set | the `18 * #roster` derivation and both caps, the undead seed note, the orc control scaling, the `main_street` route, and **one** light set (`light_at`) |
| `tools/wp13/library_kat.lua` | undead: per-start `connected_panes` accumulated into a corpus total plus a corpus-level assertion; troll: a `glazed`/`open` window-vocabulary split so a race with open bars is not forced to glaze; orc: registry rows | both, plus one removal. The troll lane's per-start `connected_panes > 0` is gone: Stillgrave bars every opening with a single flat face, writes 140 panes and no junction, and the per-start rule failed on it. The corpus assertion still covers the connected branch of `update_pane` (38 junctions across the six starts) |
| `tools/wp13/extract_tiles.py` | one `MANUAL_OVERRIDES` block per lane | all of them, no key collisions |
| `tools/wp13/node_tiles.json` | one generated file per lane | **regenerated** from the merged tree — `python3 tools/wp13/extract_tiles.py --root mods --root reference_projects/minetest_game/mods --relative-to .` — and checked to be the exact union: 456 nodes, none missing from any lane, every entry that differs from one lane equal to another lane's override |
| `tools/wp13/stub_registry.lua` | elf and undead both added `grug_trees` and `grug_nodes` to `SOURCES` and `MOD_GLOBALS` and both stubbed `read_schematic`; the troll lane declared `grug_trees` unloadable without an engine | one entry each, `seed = "grug_trees"`, the merged `MOD_GLOBALS`, and the unit-volume `read_schematic` stub. `grug_trees` DOES load engine-free: it reads `size.y` only for a runtime growth height, never for a node definition |

## Checks

| Gate | Result |
| --- | --- |
| `tools/bin/luac51 -p` per changed file | PASS, 22 files |
| `tools/bin/luac51 -p` tree-wide | PASS for `mods/*/grug_*` and for `tools` |
| SETGLOBAL | 0 on every changed file |
| Five plain-5.1 sweeps, changed files | zero hits |
| Five plain-5.1 sweeps, `wp13/` + the changed `wp40` files + `tools/wp13` | only the six pre-existing `os.exit` lines in `tools/wp13/dump_blueprint.lua`, a developer tool that never runs in the engine sandbox |
| `python3 -m py_compile tools/wp13/extract_tiles.py` | PASS |
| `node_tiles.json` parses | PASS, 456 nodes |
| `tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `library_kat` + `blueprint_kat` + `integration_fixture`, LuaJIT vs PUC 5.1 | byte-identical, `dc993b2680be07b2…` |
| `atmosphere_kat`, LuaJIT vs PUC 5.1 | `OK` under both, identical apart from the interpreter banner the KAT prints on line 2 |
| `tools/wp13/final_micro.lua` pair | byte-identical, `dc993b2680be07b2e45b4e874903d9dc1eaa032590994b33369f1f73764c0035` |
| Engine gate | **not run here** — the coordinator runs one combined engine gate over all six starts |

Composed integration row: `composed/6/169` — six starts, 169 names in the one
shared opcode-37 settlement palette; `palette_static 170` counts the library's
own static union.

Scripts: `static.sh`, `kat.sh`, `dump.sh`, `final-micro.sh`. Outputs:
`static.txt`, `kat-luajit.txt`, `kat-puc51.txt`, `atmosphere-luajit.txt`,
`atmosphere-puc51.txt`, `dumps.txt`, `final-micro/`. Each lane's own evidence
is preserved untouched under `tools/wp13/evidence/20260914-<key>/`.
