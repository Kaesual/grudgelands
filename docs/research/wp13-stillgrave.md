# WP13: Stillgrave Hollow, the undead start (fifth increment)

Status: implemented 2026-09-14, awaiting independent review and the user's
GUI playtest. Classification: non-trivial (R7 manifest and roster seam, raw
node semantics, new palette, new generator, test gates). WP13 remains in
progress.

## Why

[wp13-settlement-pipeline.md](wp13-settlement-pipeline.md) §6 makes increment
5 "the remaining four starts, one palette each, plus race-only parts where
the palette alone is not enough (… undead ruins and bone dressing …)". This
is the undead lane of that increment: Stillgrave Hollow
(`kragmar_stillgrave_hollow`, `anchor_004`, x = -1800, z = +2550), whose
region character in [world_zones.md](../design/world_zones.md) §8.2 is a
"quiet cemetery basin and sheltered gravewood" and whose §8.4 landmarks are
`stillgrave_basin` and the broken outer ring of `stillgrave_ringbarrows`.

## Part A: the road does not always run north

Hearthpine and Dawnmere are both Elandor starts and both leave their pad
toward **+z**. Stillgrave does not. `wp40/source/catalog.lua` gives the three
northern starts a `start:north` gate and the three southern ones a
`start:south` gate; `station:kragmar_stillgrave_hollow:start_south` sits at
x = -1800, z = 2486, which is the anchor's z **minus** 64. The Hollow's
five-wide route, its gate and its watchtower therefore lie toward **-z**, and
the same will be true of the Sunscar and Kapok starts.

Two fixtures assumed the sign. Both now read it out of the blueprint's own
`main_street` landmark instead, which every start already published:

| Was | Is |
| --- | --- |
| `blueprint_kat`: `for z = 0, 63 do for x = -2, 2 do assert(stand(x, 1, z))` | the landmark's x and z span, with a shape assertion that it is still five by sixty-four |
| `engine_cases`: the same loop over `core.get_node_light` | the same landmark span |

Hearthpine's and Dawnmere's landmarks are unchanged, so both settlements are
byte-identical: blueprint identity SHA-256
`e07ac54b…5100cf9ffb` (61,932 cells) and `66c7f811…d54354f74` (66,343 cells),
architecture digests `03311c95…` and `cdbc0323…`, and every `library_kat`
and `blueprint_kat` field equal to `20260914-dawnmere-fixes`.

Three more seams were generalised rather than duplicated:

- `engine_cases` counted lights by node name (`default:torch`,
  `default:torch_wall`). The Hollow burns candles, so the census is taken
  from the blueprint's own light landmarks, which `blueprint_kat` proves
  equal to the set of light cells.
- `engine_cases` capped the emerged owners at a hand-typed 16. The cap is now
  `12 * #starts`: a 127-node span crosses at most three 80-node owners per
  horizontal axis and two vertically. Measured: 21 owners on the user seed,
  27 on the boundary seed.
- `library_kat` required every start to write at least one *connected*
  `xpanes` pane. That branch of `update_pane` is only reached when a third
  horizontal neighbour connects, and the neighbour that does it in the two
  timber settlements is the `group:stone` chimney breast behind a window. The
  Hollow's chimney is `grug_decor:castle_dungeon_stone`, which carries no
  stone group, so it legitimately writes none. Coverage of the branch is now
  a property of the corpus (8 panes, all in Hearthpine and Dawnmere); every
  pane that IS written is still checked cell by cell in every start.

`tools/wp13/stub_registry.lua` gained `grug_trees` and `grug_nodes`. The
comment that said `grug_trees` "cannot run without an engine-grade schematic
reader" was half right: the module reads its two gravewood `.mts` files and
keeps `schematic.size.y` before it registers a node, so the stub's
`read_schematic` now answers a shaped table. That is the whole change; both
mods then load cleanly and the KAT checks every gravewood, blight and bone
name against the real registration like any other.

## Part B: the hamlet

`mods/MAPGEN/grug_mapgen/wp13/stillgrave.lua` composes the undead start. The
undead palette (`palette.lua`) is contract §4's undead column with four
render-driven amendments, each recorded at the palette:

- roofs are the `obsidianbrick` stair family, not `stonebrick`;
- the wall accent is `default:mossycobble`, not `castle_dungeon_stone` — the
  first render had near-black masonry under near-black boards under a black
  roof, and every building was one silhouette. The mossy plinth is what lets
  a wall read as a wall;
- the ground flora is `default:dry_shrub` and `grug_nodes:bone_pile`; a
  blight basin has no grass;
- the crypt-chapel takes the pale stone the roof gave up: its walls and
  ceiling are `default:stonebrick` under the hamlet's own black roof. The
  first attempt was the other way round (pale roof, dark walls) and the roof
  mass swallowed the building.

The rest: `grug_trees:gravewood_wood` walls on `default:obsidianbrick`
footings, `grug_trees:gravewood_tree` posts and window frames,
`xpanes:bar_flat` instead of glass, `doors:door_steel`, `walls:mossycobble`
low walls and headstones, `grug_decor:castle_rubble` for what came down,
`grug_decor:xdecor_candle` (`light_source = 12`) as the only indoor light,
`grug_decor:xdecor_cauldron` as the hearth, `grug_decor:xdecor_workbench` as
the bone-carver's bench, `grug_decor:castle_pavement_brick` for the
gravecourt and `grug_decor:castle_pillar_obsidianbrick_*` for the gate piers
and the court cairn.

Identity: a half-ruined hamlet in a blight basin. From the gate the road runs
between gravewood lamp standards to a paved **gravecourt** with a dry well, an
offering stall, a stone cairn on a black plinth, settles, bone cairns and six
old plots kept in the paving itself. The **crypt-chapel** closes the far side:
pale stone walls, barred windows, and a nave sunk one node into black
pavement between board walkways, with sarcophagus lids down both sides and an
altar tomb at the head. East is the **bone-carver's works** (the cross-gabled
`workshop` silhouette with the carver kits instead of the forge kits), and at
the gate a **watchtower**. Behind the chapel, four homes on one lane: two kept
(`keepers_house`, `warden_house`) and two **roofless ruins**. West and east of
the court lie two walled **burial grounds** of 162 markers. A broken ring of
74 gravewoods surrounds the pad. No liquids, no spawner nodes, no NPCs.

Each burial ground is walled by five runs — two long sides, the far return and
the two stubs of the near one that leave a gate in the middle — and the runs
share their corner cells. Until the 2026-09-14 review they were tested with
`layout.free_area` over the whole run, so the first run to reach a corner
claimed it and the next was refused, silently: six of the ten runs were never
built and both grounds stood open on two sides. A run now tests only the cells
it writes, accepts a cell already carrying this palette's own low wall, and is
fatal on anything else; `blueprint_kat` holds the low-wall population at 418.

New library code, all role-driven and all degrading when a palette lacks the
optional role:

- `buildings.ruin` — the new race-only generator. Footings, a board floor
  with holes, wall runs that break off at five heights on a three-node
  lattice (a per-cell height reads as crenellation, which is exactly what the
  first render showed), two corner posts still up and two snapped off, rubble
  heaps, bones and dead shrubs inside, ivy on the faces that carry it and
  cobwebs in the corners that are still corners.
- `interiors.crypt`, `interiors.carver`, `interiors.carver_wing`.
- `dressing.gravewood`, `dressing.grave`, `dressing.graveyard`,
  `dressing.cobweb`, `dressing.ivy`, `dressing.rubble_heap`,
  `dressing.blight_flora`.
- `layout.blight`, `layout.plant_gravewood`.
- `parts`: a `MESHOPTIONS` param2 kind and a `place_param2` table, because
  `default:dry_shrub` is the one palette name the engine only ever writes at
  a non-zero param2 (4); plus the pane, solid-cube and param2-kind entries
  the new vocabulary needs, every one of them proved equal to the real
  registry by `library_kat`.
- `palette`: the `pillar` family role (`_bottom`/`_middle`/`_top`), so a
  dressed stone column is reached the way a door or a bed is and a typo fails
  at construction time.

### The gravewood

`dressing.gravewood` is built on the proportions decoded from the mod's own
assets, `grug_gravewood_small.mts` (7 × 7 × 7) and `grug_gravewood_tall.mts`
(7 × 9 × 7): three clear stem logs, the first fork on the fourth course, bent
branch runs reaching two or three nodes out while rising one, and four to six
grey leaf remnants in the whole crown. One deliberate difference: the stem
carries on to its own tip and ends in a leaf remnant. The assets let the trunk
stop in mid-air under a fork, and the settlement tree invariant — every leaf
rooted on an unbroken stem that starts on the ground — is worth more than that
detail, which the branch runs give back anyway.

### A bug the Hollow found, and did not fix

`dressing.undergrowth` picked cells with `(7x + 11z) % density` and then chose
its role with `(x + z) % 4`. Those are not independent: 7x + 11z is 3(x + z)
modulo 4, so at density 4 every cell it picked took the `undergrowth` branch
and `grass_tuft` was never reached. In a pine wood that is a slightly
monotonous flora; in the Hollow it carpeted the pad with 3,300 bone piles, so
the Hollow sows its own instead (`dressing.blight_flora`, one hash and three
bands).

**Fixed for everyone in the 2026-09-14 integration.** Both tests now read two
different offsets into `parts.position_hash`; Hearthpine Vale, whose identity
is in the frozen R7 manifest, keeps the old selector under the name
`dressing.vale_undergrowth`, and `library_kat` section 8c asserts that every
start emits both of its ground-cover nodes. `blight_flora` is unchanged: the
Hollow wants its own proportions, not the shared routine's.

## Results

51,641 cells, 37,717 of them not air, 44 materials, 78 lights, 1,292 oriented
nodes, 5 reachable destinations, 7 doors, 8 rooms of which 2 are ruins, 74
gravewoods, 162 grave markers, 418 low-wall cells, 359 bone piles, 612 dead
shrubs, 18 stepping stones, 14 barrels, 13 ivy tendrils, 7 cobwebs. Bounds
x/z `[-63, 63]`, y `[-1, 12]`, inside the authorized volume and well under the
125,000 cell budget. Blueprint identity SHA-256
`a0f41a3b806f4075bf0545ac05bbdd89e88beae3a72d14c6f310054f90e6e657`, dump
SHA-256 `eeda9dbf0700a4369962531fa892bc372712b6ec3af627447940aff6bd8cdf2b`.

The bone-pile and dead-shrub figures are the whole pad, the ruins' own flora
included; `blight_flora`'s own return is smaller, and the first version of
this note quoted that return as if it were the population. 44 materials, not
45: the review threw out `grug_decor:darkage_iron_bars` as a railing (below).

**Superseded figures.** Before the 2026-09-14 review fixes this settlement was
51,597 cells / 37,667 not air / 45 materials / 75 lights / 1,300 oriented,
identity `9c08a5c8…3d29627f`, dump `7dd3dbbd…83b9c3ff`. The difference is the
six burial-ground wall runs and the three route lamps that were being dropped
in silence, the offering stall and one crate stack that moved out of a lamp's
way, and the railing rebind.

## Verification

- `tools/bin/luac51 -p` and `SETGLOBAL [0]` on all fourteen changed Lua files
  and tree-wide; the five plain-5.1 sweeps scoped to the changed Lua (zero
  hits) and tree-wide; `py_compile` on the one changed Python file;
  `tools/check_fresh_server.py` PASS. (`static.txt`)
- `library_kat`, `blueprint_kat` and `integration_fixture` over all three
  starts, byte-identical under LuaJIT and `tools/bin/lua51` at
  `55534489…593122dd`. The ruin relaxation in `blueprint_kat` is keyed on the
  `ruin` flag the generator publishes: a ruin room is exempt from the
  watertight-roof and lit-interior invariants and is required to carry no
  light at all, while every inhabited room of every settlement — including
  the two kept homes on the same lane — keeps the full invariant. The
  fixture also carries the Hollow's exact prop population (18 stepping
  stones, 14 barrels, 13 ivy, 0 bales, 0 wheels, 0 carts), and the
  composition refuses to skip a prop rather than returning false.
- Engine: headless Luanti 5.17.0, seeds `531802985935182545` and `8675309`,
  two fresh worlds with opposite owner orders each followed by a disk-only
  reload — eight passes, twenty-one and twenty-seven emerged owners. All
  eight combined digests equal
  `efc47fd2f46fe398ede2c7c071141f4a9f40e65cfe0f7729f463df1f856cc923`.
  Per-settlement architecture digests: Hearthpine
  `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c`
  (unchanged), Dawnmere
  `cdbc03239c181f1f41caf1a4a2bd851753c17f2b04e2df95037d1e62893ef4f9`
  (unchanged), Stillgrave
  `3aacf7b8cac89b01d3095ac904ce83564c6e35631e02e912d46769c0438fc0ee`.
  All 75 Stillgrave lights are lit, every destination and every foot of the
  five-wide route is lit, and the boundary seed's vertical-owner witness
  passes.
- Fitted start heights: on `531802985935182545` Hearthpine y = 25, Dawnmere
  y = 17, Stillgrave y = 54; on `8675309` y = 16, y = 21 and y = 48.
- Final micro pair: LuaJIT and PUC 5.1.5 byte-identical at
  `555344896071d34045c5b2051ce395b0079eaa6788bf26683e180f91593122dd`.

Evidence: `tools/wp13/evidence/20260914-stillgrave/`.

## What the 2026-09-14 review changed

1. **The burial-ground walls** (High). Six of ten runs silently skipped; see
   above. All ten stand, and the population is asserted.
2. **The route lamps** (Medium). `layout.street_lamps` threw its return away
   and the court pass hid its refusals in an `if`, so three authored lamps
   were missing: the offering stall's roof oversailed one, a crate stack
   stood on another, and the third was authored inside the sunken ruin's
   footprint. Both passes are fatal now and the total is asserted at 41; the
   stall moved two nodes east, the crate one node west, and the third lamp to
   (17, 34), west of the ruin as its mirror is west of the warden house.
3. **The ruin relaxation** (Medium). `room.ruin` switches off the watertight
   roof and lit-interior invariants, so `blueprint_kat` now checks the flag
   instead of believing it: a room that claims to be a ruin must have no door
   landmark inside it, be nobody's destination, carry no light, and really
   have at least one column open to the sky.
4. **The railing** (Low). `grug_decor:darkage_iron_bars` is a `glasslike`
   FULL cube, so the twelve cells meant to be a waist-high rail along the
   works gallery were a solid barred screen. `grug_decor` registers no fence
   and no vendored fence is black, so the railing is now
   `default:fence_junglewood`, the Hollow's own fence timber.
5. **The flora counts** in this note quoted `blight_flora`'s return, not the
   pad's population. Corrected above.

## What the renders were changed for

1. `dressing.undergrowth`'s aliasing (above) put 3,300 bone piles on the pad;
   at overview scale the basin read as a field of bones. It is 359 now, with
   612 dead shrubs, and the burial grounds are the only place the bones are
   thick.
2. The ruins drew their wall heights per cell and read as crenellation. They
   draw them on a three-node lattice now, stand at wall height 6 instead of 5,
   and keep the mossy-cobble apron every other plot on the lane has instead of
   a solid band of red rubble.
3. Every building was near-black masonry under near-black boards under a black
   roof, and the watchtower's parapet and lookout disappeared into its own
   roof. The wall accent is `default:mossycobble` now: one pale course under
   every wall, and a legible parapet.
4. The crypt-chapel's pale roof over dark walls made it a grey hip roof on
   short legs. It has the hamlet's black roof and pale stone walls now, at
   roof rise 3 instead of 4.
5. The gravecourt was an empty grey rectangle. It has the cairn on its black
   plinth, six kerbed plots in the paving and four fewer lamp standards; the
   well moved off the chapel's sight line.

## Scoped gaps

- `tools/wp40/r7/{micro_kat_fixture,manifest_constructor_kat,runtime_fixture}`
  still call pre-increment-4 `r7_content`/`r7_hearthpine` signatures. They
  were ALREADY red on this increment's base commit for the reason the
  previous two increments recorded (`node_semantics_fixture` cannot resolve a
  palette naming `doors`, `beds`, `xpanes`, `wool` or `grug_decor`), so they
  were left untouched rather than edited blind. Teaching that fixture the
  vendored mods and the settlement roster is one WP40 task; `stub_registry`
  now shows how `grug_trees` and `grug_nodes` fit into it.
- `tools/wp13/final_micro.lua` still excludes the portable WP40 R7 micro-KAT
  body, for the same reason and as recorded in that file.
- `docs/design/settlements.md` is unchanged: it records decided appearance,
  and the Hollow is not decided until the user has walked it.
- The renderer draws `grug_decor:xdecor_cobweb`, `xdecor_ivy` and the castle
  pillars from `MANUAL_OVERRIDES` entries added to
  `tools/wp13/extract_tiles.py`; `node_tiles.json` was regenerated and the
  diff is five added nodes and five previously tile-less ones, nothing else.

## User runtime test

Fresh world, undead, seed `531802985935182545` (Stillgrave anchor x = -1800,
z = +2550, fitted y = 54). The road runs SOUTH from the court, so walk
toward -z to reach the gate.

1. Spawn on the gravecourt: the dry well, the offering stall, the cairn on
   its black plinth, the settles and the six kerbed plots in the paving.
2. North to the crypt-chapel (x -5..5, z 12..26): step through the steel
   double door, down into the sunken nave, past the sarcophagus lids to the
   altar tomb and its two standing lights.
3. East along the lane to the bone-carver's works (x 24..39, z -6..6): the
   stone benches, the racks and the drying wing.
4. On to the home lane behind the chapel (z 30..32): the keeper's and the
   warden's houses, then the two roofless ruins — check the broken wall runs,
   the ivy, the cobwebs and that nothing there is walkable that should not be.
5. Out through both burial grounds (west x -48..-28 z -24..-8, east
   x 28..48 z 10..26) and into the gravewood ring; check that no grave wall
   blocks a route you need.
6. Set night, follow the lit road court -> gate (z = -58) -> watchtower
   (x 5..13, z -53..-45), climb its lookout, leave and reload.
