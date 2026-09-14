# WP13: Sunscar Camp, the orc start (fifth increment)

Status: implemented 2026-09-14, awaiting independent review and the user's
GUI playtest. Classification: non-trivial (R7 roster and manifest seam, raw
node semantics, a new palette and a new roof form, test gates). WP13 remains
in progress.

## Why

[wp13-settlement-pipeline.md](wp13-settlement-pipeline.md) §6 makes increment
5 the remaining four starts, "one palette each, plus race-only parts where
the palette alone is not enough (… orc earthworks and palisades …)". Sunscar
Camp (`kragmar_sunscar_flats`, `anchor_005`, x = 0, z = 2550) is the orc
start; [world_zones.md](../design/world_zones.md) §8.2 and §8.4 give the zone
as open golden savanna with small rock masks, and §10 gives the region
character as ochre grass, dry rivers, red mesas and siege earthworks.

## The road runs SOUTH

Every Accord start leaves north. The three Throng starts are on the other
side of the world, and their gate stations are `start:south`:
`wp40/source/catalog.lua` puts `station:kragmar_sunscar_flats:start_south` at
(0, 2486), which is anchor z **minus** 64. Sunscar's five-wide route,
gateway, towers, palisade and street lighting therefore run toward **-z**,
and the blueprint says so in its `main_street` landmark
(`{-2, 0, -63} .. {2, 3, 0}`).

That landmark is now the authority. `blueprint_kat` and `engine_cases` both
used to walk `for z = 0, 63` and call it "the north road"; both now read the
corridor out of `main_street` and check whatever the settlement declares.
Hearthpine and Dawnmere declare exactly what they always did, so their rows
and digests are untouched — the same check, no longer holding an assumption.

## Part A: identity

A war camp that stopped moving, on the ochre flats beside a low red rock
outcrop.
What makes it legible from the gate is the **roofline**: every building is
flat topped behind a crenellated breastwork, where the other two starts are
all ridges. Then, in order: adobe over a desert-stone base course instead of
timber walls; barred slits instead of glazed windows; a beaten muster yard
instead of a paved plaza or a turf green; a stake palisade and two gate
towers across the road face; siege berms on the other sides; flat-crowned
acacias instead of conifers or orchard standards; and a stepped red bluff
filling the north-east quarter of the pad.

Nine buildings plus the bluff:

| Landmark | Generator | Note |
| --- | --- | --- |
| `warlord_hall` | `hall`, 15 × 17, walls 7 | the largest, one tall storey; flat deck, breastwork, five braziers and an external stair up the east apron to a fighting platform |
| `armoury` | `workshop`, 11 × 13 + a 7 × 7 forge wing | the wing's walls are one course lower, so the two decks step |
| `beast_pen` | `shed`, 13 × 11, open on `x+` and `z+` | straw byre floor, paddock rails, a gate, feed bales, two wagons |
| `chief_lodge` | `build` with TWO overlapping blocks | the round-ish dwelling: a 7 × 9 and a 9 × 7 rectangle whose union is an octagon |
| `spear_lodge`, `tusk_lodge`, `bone_lodge` | `cottage`, 9 × 9 / 11 × 9 / 9 × 11 | three footprints, two wall heights, half-timbered on two of them |
| `west_tower`, `east_tower` | `watchpost` with a flat deck | the gate's flanking towers; the arch stands in the stake line between them |

Identity details that are not palette: 96 palisade stakes with sharpened
acacia crests, 150 breastwork merlons standing after the two roof cuts, 537
berm cells in seven short banks, 1,323 rock cells in six staggered slabs,
47 acacias, eight drill posts, two weapon racks, three bale targets, the
council fire ring and ten war standards.

New library code, all role-driven and all degrading when a palette lacks the
optional role: the `flat_deck` roof form (`roofs.lua`), and in `dressing.lua`
`parapet`, `outer_stair`, `palisade`, `berm`, `rock_terrace`, `standard`,
`drill_post`, `wagon` and `acacia`. `layout.plant_orchard` grew a `species`
parameter so a dry region can scatter acacias through the same clearance
rule. `parts.lua` grew the `meshoptions` param2 family (`default:dry_shrub`
pins `place_param2 = 4`, so a cell written at 0 is a node the engine would
never have produced), `plant_param2`, and the pane, solid-cube and param2
entries the new vocabulary needs; `library_kat` proves every one of them
equal to the real registry.

`roofs.flat_deck` is `flat` raised by one course. A pitched roof's lowest
course sits AT the eave, because one node inward it is already higher and
passes over the wall; a flat roof has no inward course, so rasterised at the
eave it would replace the top wall course with a slab and leave the room
open to the sky at its own ceiling height. The deck stands one course above
the wall head, which is what a flat roof on a parapeted building is; the
breastwork is written over the finished deck, because a parapet is a ring of
full nodes and the rasteriser writes exactly one cell per column.

The octagon needs no new generator. `buildings.build` already takes several
blocks and opens every wall cell that falls strictly inside another, so the
union of a tall narrow rectangle and a short wide one is a single room whose
four corner cells were never built. It publishes two rooms, and the home
kit's own torches slide onto the inner one's chamfer walls, so the outer ring
carries two hand-placed cressets — the one thing in the composition that
knows about the shape it is lighting.

Result: 57,227 cells, 44,102 of them not air, 44 materials, 112 lights, 1,352
oriented nodes, 10 reachable destinations (the fighting platform is one), 10
doors, 11 rooms, 228 barred panes of which 14 are the connected shape.
Bounds x/z `[-63, 63]`, y `[-1, 11]`. No liquids, no spawner nodes, no NPCs,
no node that needs a callback bulk placement never runs.

**Superseded figures.** Before the 2026-09-14 review fixes this settlement was
59,673 cells / 46,551 not air / 1,320 oriented, identity `b29071e3…f22ade7c`.
Almost all of the difference is the eight-course mesa coming out (below); the
rest is the shared ground-cover fix, the decked armoury roof and the acacia
stake caps.

## What else the 2026-09-14 review changed

- **M1** `tools/wp40/r7/changed_production_lua.txt` and `source_audit.sh` had
  not been told about the four lanes' new production Lua. 134 → 142: the four
  compositions and the four blueprint wrappers.
- **L1** the `merlon_cells` landmark published `dressing.parapet`'s return,
  which is the ring's whole cell count, and published it before the two cuts
  where the armoury and its wing meet. `parapet` now collects its cap
  positions and the composition counts the ones still standing: 150.
- **L2** every palisade stake was capped with `roof_stair_outer`, which in
  this palette is `stairs:stair_outer_desert_stonebrick`: a stone point
  balanced on a log. A new optional role `stake_cap` binds
  `stairs:stair_outer_acacia_wood`, the same timber the stakes are.
- **L3** seven columns of the armoury's main room were roofed only by the
  forge wing's west breastwork ring, and `walls:desertcobble` is a connected
  nodebox: daylight came down between it and its neighbours. That ring is cut
  like the main one already was and the roof deck laid across.
- **L4** `dressing.standard`'s `lights` parameter was dead -- both callers
  passed nothing, and this settlement reads its light landmarks off the
  finished cell list by node name. Removed.
- **L5** the control-owner loop in `engine_cases.lua` padded the owner list
  up to a threshold, and once the roster reached six starts the structure
  owners already exceeded it, so the corpus carried no controls at all while
  still claiming to. Two controls are added outright now and counted in the
  bound.
- **L6** `PARAM2_KIND` and `FULL_SOLID` carried
  `castle_arrowslit_desert_stonebrick`, `darkage_ors_rubble` and
  `darkage_straw_bale`, which no blueprint emits and no palette binds:
  unverified claims about node shapes. Removed.
- **L7/L8** the owner-count comment said the superseded bound was "two per
  axis, so eight"; it was a flat sixteen. And the `main_street` check is
  anchored to the pad, not only measured.

## Part B: the seam took a third start unchanged

One roster row in `wp40/r7_settlement.lua` after Dawnmere, one
`SETTLEMENT_ORDER` row and one field block in `r7_manifest.lua`, a
three-line `r7_sunscar_blueprint.lua` wrapper, one palette in `palette.lua`,
one composition in `wp13/sunscar.lua`, one `blueprint_kat` spec row. Nothing
in `r7_runtime.lua`, `r7_content.lua` or `r7_successor.lua` changed: the
shared opcode-37 content channel simply carries a larger palette union (95
names, up from 88).

`engine_cases.lua` needed two bounds generalised, not raised by hand: the
structure-owner ceiling is `8 * #starts` (one start of 127 × 127 × ~20 cells
occupies at most two owners per horizontal axis and two vertically) and the
control population `8 * #starts + 2`, so the fourth, fifth and sixth start
cost no further edit.

**Hearthpine and Dawnmere are byte-identical.** Hearthpine's blueprint
identity SHA-256 is still
`e07ac54bec01e662f224c629d12c424ec67ca03ee3183c5389943b5100cf9ffb` (61,932
cells) and Dawnmere's is still
`66c7f8118b0b761d8e7c009f72753e9ec7578c1cb2b6d464f55ca97d54354f74` (66,343
cells); both `blueprint_kat` rows are unchanged in every field.

## Verification

- `tools/bin/luac51 -p` and `SETGLOBAL [0]` on all thirteen changed Lua files
  and tree-wide; the five plain-5.1 sweeps scoped and tree-wide;
  `tools/check_fresh_server.py` PASS. (`static.txt`)
- `library_kat`, `blueprint_kat` and `integration_fixture` on the frozen
  bytes, byte-identical under LuaJIT and `tools/bin/lua51`.
- Engine: headless Luanti 5.17.0, seeds `531802985935182545` and `8675309`,
  two fresh worlds with opposite owner orders each followed by a disk-only
  reload — eight passes, 24 and 33 emerged owners, covering Hearthpine,
  Dawnmere and Sunscar. All eight combined digests equal
  `ffe90fedca583344c197078c41ec1a4882194e17cc284af32d9949ef27dbd220`;
  Sunscar's own architecture digest is
  `bd673e4acd4f9c187b26a7649e3e64c7e8045c579f80dee2d335d6bf8407c8be`.
  Fitted start height: y = 27 on the user seed, y = 46 on the boundary seed.
- Final micro pair: LuaJIT and PUC 5.1.5 byte-identical at
  `5456e9ff54826d0a705ff2411ed21e08d07082ad8fd2cbbc65e84fe4dfaf2d1e`.
- One bound had to be corrected on the way: `engine_cases.lua` asserted at
  most eight structure owners per start, on the argument that a start
  "occupies at most two owners per horizontal axis". A start spans 127 nodes
  and an owner is 80 wide, so it touches two OR THREE; the bound held only
  because the two starts it was written for fell kindly, and the third start
  needed 33 owners on the boundary seed. The ceiling is the honest
  3 × 3 × 2 = eighteen per start now.

Evidence: `tools/wp13/evidence/20260914-sunscar/`.

## What the renders were changed for

1. `grug_decor:darkage_adobe` and `grug_decor:darkage_ors_block` had no
   entry in `node_tiles.json` — `darkage.lua` builds its tile names through a
   local helper the scanner cannot follow — so the material the whole
   settlement is walled in rendered as a flat placeholder colour and could
   not be judged at all. Three `MANUAL_OVERRIDES` entries fixed it.
2. The first ground was one unbroken yellow across the whole 127-node pad.
   Two wear passes were added, and their materials went through three
   versions: two more shades of dry grass (no contrast at all), then
   `default:gravel` (grey litter scattered over a warm landscape), and
   finally brown trodden earth and pale blown sand, which read as use.
3. The wear pattern itself went through three hashes. Anything linear in x
   lays its hits on an arithmetic progression, and an arithmetic progression
   modulo the sieve's period is a stripe: version one streaked the pad
   diagonally, version two banded it. Two rounds of a plain LCG fixed it.
   Single-cell hits also read as dithering at every camera distance, so each
   hit now paints a 2 × 2 blob.
4. The camp had no horizon, so relief was built into the north-east quarter
   as six stepped terraces with the z of each step staggered, capped with
   the same ground so it reads as the flats carried up. Two berm banks were
   shortened to leave it room.

   **The 2026-09-14 review cut it down.** It had been built eight courses
   high and run out to the pad edge, which is a MESA -- the landform of the
   neighbouring Bannerbreak Mesa zone, not of Sunscar Flats, whose relief
   `world_zones.md` §8.4 gives as open savanna with small rolling-hill rock
   masks. It also met the edge, where the writer's apron has to blend into
   whatever terrain the seed put there. Three courses now, nothing closer
   than four nodes to the edge, and the slabs overlap so the foot is broken
   and the top is two or three ledges: 1,323 cells where there were 2,626.
5. The berms were first one continuous three-row band round the whole
   perimeter, which read as ploughed furrows. They are seven short banks now:
   a camp digs where it expects to be hit.
6. The gateway was first a pair of piers at z = -58, between the towers,
   where the towers hide it from every approach. It stands in the stake line
   at z = -56 now, in the gap between them, so a rider passes the arch and
   the wall together with a tower over each shoulder.
7. The flats were 3,056 dead shrubs on the first pass, because the flora
   sieve `(7x + 11z) % 4` collapses onto the `(x + z) % 4` that chooses
   between shrub and tuft, so every planted cell came out a shrub. Density 6
   makes the two tests independent again.
8. The fighting platform was unreachable: the stair climbs under the deck's
   own eave, and a slab sat where a warrior's head goes. The eave is cut away
   over the flight, and a gap is cut in the breastwork where it lands.

## Scoped gaps

- `tools/wp40/r7/{micro_kat_fixture,manifest_constructor_kat,runtime_fixture}`
  still call the pre-increment-4 `r7_content`/`r7_hearthpine` signatures.
  They were ALREADY red on this increment's base commit for the reason the
  Dawnmere note records, and were left untouched rather than edited blind.
- `docs/design/settlements.md` is unchanged: it records decided appearance,
  and Sunscar is not decided until the user has walked it.
- The camp has no water, which is right for the flats; the zone's waterholes
  are `sunscar_waterholes` outside the protected start core and belong to
  terrain, not to this blueprint.

## User runtime test

Fresh world, orc, seed `531802985935182545` (Sunscar anchor x = 0, z = 2550,
fitted y from the engine receipt):

1. Spawn on the muster yard: the council fire ring behind you, drill posts
   and weapon racks west, bale targets east, four standards on the corners.
2. North to the warlord's hall: double doors, the long tables, then out and
   round to the east apron, up the external stair, through the gap in the
   breastwork onto the fighting platform, and look back down the road.
3. East to the armoury and its forge wing; note the stepped decks.
4. West to the beast pen: straw byre, paddock rails and gate, bales, wagons;
   then north-west to the round chief's lodge and walk its chamfered corners.
5. South down the road past the three lodges and the road standards, out
   through the gateway between the two towers, and climb one of them.
6. Set night, walk the road green-to-gate and back, check the palisade crest
   and the berms from outside, then leave and reload.
