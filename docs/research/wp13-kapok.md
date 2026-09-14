# WP13: Kapok Cradle, the troll start (fifth increment, troll lane)

Status: implemented 2026-09-14, awaiting independent review and the user's
GUI playtest. Classification: non-trivial (R7 manifest and roster seam, raw
node semantics, new palette, new library parameters, test gates). WP13
remains in progress.

## Why

[wp13-settlement-pipeline.md](wp13-settlement-pipeline.md) §6 makes increment
5 "the remaining four starts, one palette each, plus race-only parts where
the palette alone is not enough (elf platforms in trees, undead ruins and
bone dressing, orc earthworks and palisades, **troll stilts**)". This is the
troll lane. [world_zones.md](../design/world_zones.md) §8.2 gives the zone as
Kapok Cradle (`kragmar_kapok_cradle`, level 1-10, jungle edge 90 / swamp 10,
"sheltered jungle basin beneath one giant kapok"), §8.4 its required landmark
`kapok_worldtree_basin`, and §10 the troll region character: kapok basins,
rivers, reed mazes, storm jungle.

## The road runs to -z

`anchor_006` sits at (1800, 2550) and the zone's start gate station is
`station:kragmar_kapok_cradle:start_south` at (1800, **2486**) --- 64 nodes
SOUTH of the anchor, i.e. local z = -64. Every Kragmar start exits south and
every Elandor start north (`catalog.lua`, the `start_gate` stations and the
`start:south` / `start:north` map beside them). Kapok therefore carries its
five-wide route, its gate and its watchpost on NEGATIVE z, which is the one
place this increment deviates from the brief's assumption of +z.

Rather than letting each start's fixture know its own direction by name, both
route checks now read it off the blueprint:
`blueprint_kat` and `tools/wp13/engine_cases.lua` iterate
`landmarks.main_street` instead of a hard-coded `for z = 0, 63`. Hearthpine
and Dawnmere publish exactly the window those loops used to walk, so both are
checked as before, byte for byte.

## The settlement

`mods/MAPGEN/grug_mapgen/wp13/kapok.lua` composes the troll start from the
library. The troll palette (`palette.lua`) is contract §4's troll column ---
mossy and basalt footings, `default:junglewood` walls, `default:jungletree`
posts, the `stairs:*_junglewood` roof family, open windows instead of glass,
junglewood fences, wooden doors --- plus the kit nodes the basin asks for:
`darkage_basalt_brick` terrace and wall bases, `darkage_reinforced_wood`
beams and lintels, `darkage_serpentine` accents, `darkage_wood_bars` window
bars, `xdecor_cauldron` fires, `cottages_tub` soaking vats, `cottages_straw`
and `cottages_straw_mat` floors, `xdecor_lantern_hanging` and `xdecor_rope`.
Two roles are new and optional: `lantern` and `rope`.

The "fires" are cold geometry. `grug_decor:xdecor_cauldron` is a nodebox with
a light source and a texture of embers; this game ships no fire mod, nothing
here burns, spreads, cooks or damages, and no cell in this blueprint has a
callback of any kind. The hearths, the smoking fires and the council ring are
all scenery, and the light they give is the node's own `light_source`.

The one binding that decides the whole look is `path = default:junglewood`.
In a basin that floods, a settlement walks on boardwalks, not on stone, so
the road, the lanes, every building apron and every raised walkway are one
continuous timber deck over rainforest litter blotched with `grug_nodes:mud`.

Identity: **eight buildings**, no water (the basin's rivers are mapgen's), no
spawner nodes, no metadata nodes.

- a **spirit lodge** (hall, 13 x 15, wall height 7) alone on a raised basalt
  terrace with a serpentine kerb, four totem posts of stacked jungletree
  banded with serpentine, a central fire whose flue rises through the ridge,
  woven mats and low benches facing it;
- a **fish smoker** (workshop, on two courses of stilts) with three smoking
  fires on its back wall under two mossy flues, soaking tubs down the middle
  and a rope drying line on a tie beam;
- **four stilt dwellings**, three courses up on jungletree posts, each with a
  wide plank veranda, a railing all round it except at the mouth of its
  flight, barred windows, an outside stair and rope hanging from the deck ---
  two gabled, two hipped;
- a **drying shed** (open on two sides) on a straw floor with four racks of
  split fish on rope lines, stacked timber and crates;
- a **lookout** (watchpost) at the gate, guard room below and railed deck
  above;
- a **gate** of two totem posts under a reinforced lintel, torch-lit.

Two **flying bridges**, deck to deck, cross the main road at deck height
between the southern pair of dwellings and the northern pair; their pier rule
refuses a post anywhere within three nodes of the route's centre, which is
what keeps the five-wide road clear underneath. Sixteen lanterns hang under
the bridges and the verandas.

The deck height is **4**, raised from 3 by the 2026-09-14 review. At 3 the
plank soffit was two nodes above a player walking the route -- one node of
headroom over a 1.8-node model, which is a duck, not a bridge. Four gives the
road the three clear courses section 5's route invariant means it to have,
at one more tread on each flight and one more course on each pier.

Planting: 83 jungle trees and 3 emergent kapoks on the decoded proportions of
`mods/BASE/default/schematics/jungle_tree.mts` (5 x 17 x 5: a plus-shaped
buttress root three courses high, a bare single-log trunk for two thirds of
the height, four small leaf spurs on alternating diagonals, and a flat crown
of two 5 x 5 leaf slabs and a 3 x 3 cap in the top three courses) and
`emergent_jungle_tree.mts` (7 x 37 x 7: a five-cell buttress, a solid 3 x 3
trunk, leaf collars where the branch whorls leave it, a seven-cell crown).
The emergent is shortened --- the schematic is 37 courses and the authorized
volume is 27 --- and nothing else about it is.

New library code, all role-driven and all degrading when a palette lacks the
optional role:

| Where | What |
| --- | --- |
| `buildings.lua` | `spec.stilt` raises a whole building onto posts (floor, walls, windows, doors, roof, chimneys and rooms move up; corner posts and window frames keep their feet on the pad); `spec.apron` widens the veranda independently of the roof overhang; `spec.stairs` gives it the outside flights; the deck's outer ring carries a rail everywhere but a flight's mouth; piers under the veranda edge; `kit`, `chimneys` and `rise` are overridable on `hall` and `workshop` |
| `dressing.lua` | `jungle_tree`, `emergent`, `totem`, `drying_rack`, `rope_fall`, `lantern`, `walkway` (railed, with a pier veto), `stair_up`, `basin_flora` |
| `interiors.lua` | the `lodge` and `smoker` kits |
| `layout.lua` | `basin` (the mud-blotched jungle floor), `plant_jungle`, `plant_giants` |
| `parts.lua` | the pane writer accepts a window role that is not an `xpanes` pane; the pane-connection and opaque-cube tables grew the jungle vocabulary |

Result: 72,535 cells, 51,967 of them not air, 42 materials, 87 lights, 837
oriented nodes, 8 reachable destinations, 9 doors, 9 rooms, 56 rope cells, 16
lanterns, 42 stepping stones, 83 jungle trees and 3 emergent kapoks. Bounds
x/z `[-63, 63]`, y `[-1, 22]`.

**Superseded figures.** Before the 2026-09-14 review fixes this settlement was
71,783 cells / 51,755 not air / 831 oriented, identity `0a0ad478…bb887777`.
The difference is the deck raised from 3 to 4 and the shared belfry and
ground-cover changes.

## What the 2026-09-14 review changed

1. **H1, the lantern** (High). The palette bound
   `grug_decor:xdecor_lantern`, which is in `group:attached_node = 3`, and
   rating 3 is "always attach to FLOOR"
   (`reference_projects/luanti/builtin/game/falling.lua:391-399`). All
   sixteen lanterns hang under a deck, so every one of them would have been
   dropped as an item the first time anything near it updated. Rebound to
   `grug_decor:xdecor_lantern_hanging`, rating 4, "always attach to ceiling".
   Three comments in `blueprint_kat`, `dressing.lua` and this note had the
   two ratings the wrong way round and are corrected. `xdecor_rope` carries
   no attachment group at all: its "ceiling" mode is an authoring convention
   this project enforces, and nothing but `blueprint_kat` enforces it.
2. **M1, the deck height.** Above.
3. **M2**, the engine evidence, regenerated with the sealed script as part of
   the combined six-start gate.
4. **L1**, `parts.pane`/`pane_base` keyed on the `xpanes:` PREFIX where
   `library_kat` and `xpanes` itself key on `group:pane`. `parts.lua` has no
   registry, so it now carries a written-out `PANE_NAMES` set and
   `library_kat` section 7a asserts the set agrees with `group:pane` for all
   779 registered nodes.
5. **L2**, `library_kat` section 8b matched a start's emitted names against
   every race's `window` role at once; the dwarf and human palettes both bind
   `xpanes:pane_flat`, so a start could be told it emitted "two window
   vocabularies" for building with one. The roster rows now carry `race` and
   the question is asked of the start's own palette.
6. **L3**, the prop clearance tested four courses while a totem post is seven
   or eight, so a totem could have been driven through a veranda deck with
   nothing said. `open_air` takes the real height and both totem calls pass
   it.
7. **L5**, the cauldron fires are cold geometry. Above.

## What the renders were changed for

1. Seven of the troll vocabulary's nodes rendered as flat placeholder colours,
   which made the terrace, the beams, the window bars, the lanterns and the
   ropes unjudgeable. `extract_tiles.py` gained their `MANUAL_OVERRIDES` rows
   (`darkage.lua` builds tile names through its own helper and composes the
   reinforced timber as an overlay, neither of which the scanner follows) and
   `node_tiles.json` the matching entries.
2. The first floor scatter used the shared `dressing.undergrowth`, whose
   per-cell modulo lays a diagonal lattice; over a 127-node jungle floor that
   reads as green STRIPES from above. `basin_flora` seeds clump centres on a
   coarse lattice and fills a ragged blob round each instead.
3. The first three buildings were roof and no wall: a two-node roof overhang
   on a nine-wide house buries its own walls at every camera angle. The roof
   overhang went back to one and `spec.apron` was added so the veranda can
   still be two or three nodes wide; walls went from 4 to 5 courses (the lodge
   to 7) and the pitch from 4 to 3.
4. The stilts did not read: the veranda's outer edge floated. Piers under the
   apron ring, every third cell plus its corners, and a rail on that ring.
5. The lodge's fish stall, notice post and settles were placed inside the
   lodge's own cleared room --- a cleared room passes an emptiness test. Both
   prop helpers now refuse any cell that is not `outdoors`.

## Verification

- `tools/bin/luac51 -p` and `SETGLOBAL [0]` on all fourteen changed Lua files
  and tree-wide; the five plain-5.1 sweeps scoped and tree-wide;
  `tools/check_fresh_server.py` PASS. (`static.txt`)
- `library_kat`, `blueprint_kat` and `integration_fixture` over all three
  starts, byte-identical under LuaJIT and `tools/bin/lua51`.
  `stub_registry.lua` gained `grug_nodes` so the troll palette's swamp mud is
  checked against the real registration like every other name;
  `library_kat` §9 now derives from the palettes and the registry whether a
  start glazes its windows, and applies the `update_pane` rule only to one
  that does; `blueprint_kat` gained the Kapok spec, its exact prop row and a
  `ceiling` support mode for props that hang (`group:attached_node = 3`, and
  a rope tied to a beam).
- Engine: headless Luanti 5.17.0, seeds `531802985935182545` and `8675309`,
  two fresh worlds with opposite owner orders each followed by a disk-only
  reload --- eight passes, 21 and 22 emerged owners. All eight combined
  digests equal
  `b9966f25cd2bc571f66c826639078d436eed5d58493fc272a2953de9f1cf638a`; Kapok's
  own architecture digest is
  `cb3cd86d8b324571336458b2a59f56e7a79f6387384e741938d4f7353bcff2c3` and its
  blueprint identity
  `0a0ad4784a0fe21ba6fa815498405bb43a446b25188b6f08230dfe67bb887777`. Fitted
  start height y = 20 on the first seed and y = 17 on the second.
- Final micro pair: LuaJIT and PUC 5.1.5 byte-identical at
  `50ecddf34daeee387c11026c77463a3a6bdb775f541428748fc015527b3c9ab9`.

**Hearthpine and Dawnmere are byte-identical.** Hearthpine's blueprint
identity SHA-256 is still
`e07ac54bec01e662f224c629d12c424ec67ca03ee3183c5389943b5100cf9ffb` and its
live architecture digest still `03311c95…`; Dawnmere's identity is still
`66c7f8118b0b761d8e7c009f72753e9ec7578c1cb2b6d464f55ca97d54354f74` and its
digest still `cdbc0323…`, the value the increment-4 review fixes recorded.
Both `blueprint_kat` rows are unchanged in every field.

Evidence: `tools/wp13/evidence/20260914-kapok/`.

## Scoped gaps

- `tools/wp40/r7/source_audit.sh` pins `changed_production_lua` at 134. This
  increment adds two production Lua files (`wp13/kapok.lua` and
  `wp40/r7_kapok_blueprint.lua`) and each of the other three start lanes of
  increment 5 adds two more, so the constant is left alone rather than set to
  a number the next merge invalidates. It belongs to the coordinator's fold-in
  of the four lanes, together with the regenerated
  `tools/wp40/r7/changed_production_lua.txt`.
- `tools/wp40/r7/{micro_kat_fixture,manifest_constructor_kat,runtime_fixture}`
  remain red on their pre-increment grounds, unchanged from increment 4's
  scoped gap; `tools/wp13/final_micro.lua` still excludes the portable WP40 R7
  micro-KAT body for the same reason.
- `docs/design/settlements.md` is unchanged: it records decided appearance,
  and Kapok is not decided until the user has walked it.

## User runtime test

Fresh world, troll, seed `531802985935182545` (Kapok anchor x = 1800,
z = 2550, fitted y = 20):

1. Spawn on the boardwalk crossroads: look SOUTH down the plank road to the
   two totem posts of the gate, and NORTH up the spine to the spirit lodge.
2. Walk north to the lodge: double doors, the fire in the middle of the floor
   with its flue through the ridge, mats and benches round it; step back onto
   the basalt terrace and check the four totems, the fish stall and the kerb.
3. East to the fish smoker: climb its flight, walk the veranda, look at the
   three smoking fires, the tubs and the rope line; then west to the drying
   shed, its straw yard and its four racks.
4. Climb any of the four dwellings: the flight, the railed veranda, the barred
   windows, the bed and hearth inside; then cross a flying bridge to the
   dwelling on the other side of the road and look DOWN at the road from it.
5. Walk the road south under both bridges to the gate; confirm nothing stands
   in the five-wide route and the watchpost's door and lookout are reachable.
6. Set night, follow the lit road and lanes, look for the three emergent
   kapoks against the sky, then leave and reload.
