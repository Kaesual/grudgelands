# WP13: Dawnmere Fields, the second start (fourth increment)

Status: implemented 2026-09-14, awaiting independent review and the user's
GUI playtest. Classification: non-trivial (R7 manifest and successor seam,
raw node semantics, new palette, test gates). WP13 remains in progress.

## Why

[wp13-settlement-pipeline.md](wp13-settlement-pipeline.md) §6 makes the
second start the proof that "a palette plus roof-form change yields a
different-looking village from the same generators". Dawnmere Fields
(`elandor_dawnmere_fields`, `anchor_002`, x = 0, z = -2550) is the human
start; [world_zones.md](../design/world_zones.md) §10 gives its region
character as fields, oak woods, river forks and marsh roads.

## Part A: one seam, many settlements

The first increment hard-wired Hearthpine into the R7 tail. The seam is now a
roster, and everything it touched is parameterised:

| Was | Is |
| --- | --- |
| `wp40/r7_hearthpine.lua`, one config factory | `wp40/r7_settlement.lua`: `M.roster` (key, zone, anchor id/numeric id/x/z, blueprint file, five schema strings) plus `M.config(profile, blueprint, content, raw_sha256)` |
| `r7_successor.lua(p9g, anchors, hearthpine)` | `r7_successor.lua(p9g, anchors, settlement_configs)`, iterated in roster order; the ledger and metrics publish one table per settlement key, so `ledger.hearthpine` keeps the shape the accepted R6 settlement contract reads |
| `r7_content.lua(..., hearthpine_palette)`, schema `grug_wp13_hearthpine_content_v1` | `r7_content.lua(..., settlement_palette)`, schema `grug_wp13_settlement_content_v1`: ONE opcode-37 channel whose palette is the sorted ASCII union of every start's palette, so a cell's content ref stays inside the single `successor_ref` window the manifest delta declares and `r6_settlement.lua` needs no second opcode |
| manifest fields `hearthpine_content_*` | `settlement_content_*` (the shared channel) plus per-settlement `hearthpine_*` and `dawnmere_*` blueprint and delta blocks, in a fixed `SETTLEMENT_ORDER` |
| two copies of the library-path bootstrap | `wp40/r7_wp13_library.lua`; each `r7_*_blueprint.lua` wrapper is three lines |

`context.write_hearthpine` keeps its name: it is R7's opcode-37 settlement
writer in the accepted R6 contract, and renaming it would touch
`r6_settlement.lua` for no behavioural gain. The comment at the call site
says so.

**Hearthpine is byte-identical.** Its blueprint identity SHA-256 is still
`e07ac54bec01e662f224c629d12c424ec67ca03ee3183c5389943b5100cf9ffb`
(61,932 cells), and the live engine's architecture digest is still
`03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c` on both
seeds, in both owner orders, cold and after reload -- the same value as
`tools/wp13/evidence/20260914-hearthpine-fixes/`. The `blueprint_kat` row for
Hearthpine is unchanged in every field.

## Part B: the hamlet

`mods/MAPGEN/grug_mapgen/wp13/dawnmere.lua` composes the human start from the
existing library. The human palette (`palette.lua`) is contract §4's human
column -- cobble footings, `default:wood` walls, `default:brick` accents and
chimneys, `default:tree` framing, the `stairs:*_wood` roof family, flat panes,
wooden doors, cobble low walls and wooden fences -- plus the kit nodes that
fit a farm: `cottages_loam` half-timber panels, `cottages_straw_ground`,
`cottages_straw_bale`, `cottages_bench`, `cottages_table`,
`cottages_straw_mat`, `cottages_anvil` as the workbench,
`cottages_window_shutter_closed`, `cottages_wagon_wheel`,
`xdecor_stonepath`, `xdecor_barrel`, `xdecor_empty_shelf`,
`xdecor_cauldron`, `cottages_shelf`, and the potted geranium and dandelion as
flowers. Roofs stay in the `stairs:` family: the `cottages_roof_*` nodes ship
three shapes where the rasteriser needs five, for the reason recorded in the
previous increment's evidence.

Identity: nine buildings around a turf **village green** with a draw well, a
market stall, flower beds, settles and hand carts -- no paved plaza. A
belfried **meeting hall** and a **tollhouse** at the gate carry brick roofs;
the **inn**, the **barn** and two cottages are half-timbered; four cottages
show three roof forms (gable, hip, saltbox) and a fourth cross-ridge gable.
Eight fenced crop fields with furrows and rows, hedgerows of
`bush_stem`/`bush_leaves` on their outer boundaries, two orchard blocks and
scattered standards on the proportions of the decoded
`mods/BASE/default/schematics/apple_tree.mts` (7 x 7 x 8: four clear trunk
logs, then four diamond crown courses with two branch logs). No liquids, no
spawner nodes, no NPCs.

New library code, all role-driven and all degrading when a palette lacks the
optional role: `layout.meadow`, `layout.plant_orchard`, `dressing.broadleaf`,
`dressing.hedge_line`, `dressing.crop_rows`, `dressing.bale_stack`,
`dressing.handcart`, `dressing.stepping_line`, `dressing.flower_bed`,
`parts.wall_prop`, half-timbered walls and shutters in `buildings.build`, and
the `barn`, `chapel`, `belfry` generators plus the `barn`, `chapel` and `inn`
interior kits. `parts.lua` grew the param2, pane-connection and opaque-cube
entries the new vocabulary needs; the library KAT proves every one of them
equal to the real registry.

Result: 66,291 cells, 44,805 of them not air, 52 materials, 97 lights, 1,446
oriented nodes, 9 reachable destinations, 12 doors, 10 rooms, 27 oak
standards, 1,555 planted crop cells, 216 hedge cells. Bounds x/z `[-63, 63]`,
y `[-1, 17]`.

## Verification

- `tools/bin/luac51 -p` and `SETGLOBAL [0]` on all nineteen changed Lua files
  and tree-wide; the five plain-5.1 sweeps scoped and tree-wide;
  `tools/check_fresh_server.py` PASS. (`static.txt`)
- `library_kat` now checks EVERY race in `palettes.races` and runs its
  registry, pane and torch sections over EVERY blueprint in the R7 roster;
  `blueprint_kat` runs the §5 invariants over both starts from a per-start
  node vocabulary; `integration_fixture` drives both successors over the real
  owner grid, refuses a foreign anchor, and proves an unrelated owner
  receives nothing. Byte-identical under LuaJIT and `tools/bin/lua51`.
- Engine: headless Luanti 5.17.0, seeds `531802985935182545` and `8675309`,
  two fresh worlds with opposite owner orders each followed by a disk-only
  reload -- eight passes, fifteen and sixteen emerged owners. All eight
  combined digests equal
  `17f1381e5c29f332da126abfb353b07229fb8e2c0a716cf7f12e1a408cba40f2`.
- Final micro pair: LuaJIT and PUC 5.1.5 byte-identical at
  `2a725edd600e95fc4cd9d0027d0cd4ffa1d54de3dddf7d48e71a8868f73e0016`.

Evidence: `tools/wp13/evidence/20260914-dawnmere/`.

## Scoped gaps

- `tools/wp40/r7/{micro_kat_fixture,manifest_constructor_kat,runtime_fixture}`
  still call the pre-increment `r7_content`/`r7_hearthpine` signatures. They
  were ALREADY red on this increment's base commit -- `node_semantics_fixture`
  cannot resolve a palette naming `doors`, `beds`, `xpanes`, `wool` or
  `grug_decor`, which is the documented WP40-lane follow-up from increment 3
  -- so they were left untouched rather than edited blind. Teaching that
  fixture the vendored mods and the settlement roster is one WP40 task.
- `docs/design/settlements.md` is unchanged: it records decided appearance,
  and Dawnmere is not decided until the user has walked it.

## User runtime test

Fresh world, human, seed `531802985935182545` (Dawnmere anchor x = 0,
z = -2550, fitted y = 17):

1. Spawn on the village green: well, market stall, flower beds, settles, hand
   carts; walk the green's brick kerb and the three lanes off it.
2. North to the meeting hall: double doors, benches down the runner, the
   lectern dais, then step back and look at the belfry on the ridge.
3. East to the inn (half-timbered, long table, hearth, two beds), then the
   smithy and its wing.
4. West to the barn: straw yard, bale stacks, cart wheels, the big door on
   the lane; then the four cottages on the south lane -- gable, hip, saltbox
   and cross gable, shutters on every window.
5. Out through the crop fields and hedgerows to the orchards; check that no
   field fence blocks a route you need.
6. Set night, follow the lit road green -> gate -> tollhouse, climb its
   lookout, leave and reload.
