# WP13: building library and Hearthpine rebuild (third increment)

Status: implemented, independently reviewed and fix-rounded on 2026-09-14;
the user's first GUI playtest of the six starts produced the round-A fix
round recorded below, which is not reviewed yet. Classification: non-trivial
(architecture, raw node semantics, vendored code, licences, test gates).
WP13 remains in progress.

## Why

The user's playtest of the nine-building settlement found the houses
acceptable but plainer than VoxeLibre's villages. The comparison in
[wp13-settlement-pipeline.md](wp13-settlement-pipeline.md) §1 showed the
cause: large hollow buildings with stepped block roofs, glass blocks and
open door gaps versus small dense houses with stair roofs, panes, doors and
furniture. The user also asked for ContentDB building assets and a more
immersive look, and ruled that on this day Claude Fable coordinates with
Claude Opus lanes (policy "Day-to-day routing rule").

## What shipped, in lanes

1. **Atmosphere layer** (`mods/CORE/grug_core/atmosphere.lua`,
   `settingtypes.txt`, `minetest.conf`): presets `default`, `hearthpine`,
   `godrays`, `off` applied through `player:set_lighting` on join and by the
   admin command `/atmosphere`; sent only on change; game defaults enable
   dynamic shadows, bloom and waving. Gravewood leaves now wave.
2. **Vendored minetest_game mods** `doors`, `xpanes`, `beds`, `wool`, `dye`,
   `vessels`, `walls` from the pinned `b5243f3` checkout under `mods/BASE/`,
   fresh-server cleaned; beds are decoration only (no sleep, no respawn).
   Steel-ingot recipes were removed because `default:steel_ingot` is retired.
3. **Curated kit `mods/ITEMS/grug_decor`**: 333 static decorative nodes from
   castle_masonry `900d633` (148), cottages `ab7f7e1` (52), darkage
   `494f81c` (102) and xdecor-libre `43a7753` (31); 109 media files with a
   licence row each; no recipes, no mechanics. Licences verified in the
   source repositories
   ([asset-audit-2026-09-14.md](assets/asset-audit-2026-09-14.md)); the
   combined game is GPL-3.0-only because cottages is GPL-3.0-only.
4. **Textured blueprint renderer** `tools/wp13/render_blueprint.py` with
   `dump_blueprint.lua`, `extract_tiles.py` and `node_tiles.json`: isometric
   views, interior cutaway and a night mode. It is the review loop for every
   building generator from now on.
5. **Building library** `mods/MAPGEN/grug_mapgen/wp13/` (palette, parts,
   roofs, buildings, interiors, dressing, layout, hearthpine) and the
   rebuilt Hearthpine blueprint behind the unchanged
   `grug_wp13_hearthpine_blueprint_v1` schema, landmarks and bounds. Roofs
   are height fields rasterised into straight/outer/inner stairs and slab
   ridges; the same field sets wall heights. Generators: cottage (gable,
   hip, saltbox), workshop with smithy wing, hall, longhouse, shed,
   watchpost. Doors, beds, torches, panes, walls and stairs are written
   exactly as normal placement leaves them.

Evidence: `tools/wp13/evidence/20260914-hearthpine-library/` (lane result:
KATs under LuaJIT and PUC 5.1, eight engine passes on two seeds, final micro
pair) and `tools/wp13/evidence/20260914-hearthpine-fixes/` (after the review
fix round). Renders live next to each.

## Reviews and fix rounds

- Lanes 1–4, independent Claude Opus review: 0 Critical / 0 High /
  1 Medium / 8 Low; one fix round (tile map regenerated, unused dependency,
  README licence line, VENDOR.md completeness, KAT coverage). Final: 0.
- Lane 5, independent Claude Opus review: 0 Critical / 1 High / 1 Medium /
  4 Low. High: chests, furnaces, bookshelves and vessel shelves written
  through VoxelManip never receive `on_construct`, so they were dead props;
  fixed by binding those roles to static decor nodes (settlements carry no
  storage services by design). Medium: eleven panes with a third solid
  neighbour must be written as the connected `xpanes:pane`; fixed by
  applying the engine's pane rule at construction. Lows: rotated param2 on
  `place_param2 = 0` nodes, torches hung on window panes, incomplete
  retirement cross-check, palette docstring. One fix round
  (`tools/wp13/evidence/20260914-hearthpine-fixes/`): static decor roles,
  the engine's pane rule at construction, param2 only on orientation-bearing
  nodes, torches on opaque walls, both retirement sources, prefix roles,
  plus proper pines and stone-brick roofs on the two halls. Focused
  re-review (Claude Opus, fresh context): CLEAN, four non-blocking notes
  applied before merge. Final findings: 0.

Calibration: coordinator Claude Fable; implementing model Claude Opus (five
lanes plus one fix lane); reviewing model Claude Opus in fresh contexts;
initial findings 0 Critical / 1 High across both reviews; two fix rounds
(one per review); observed elapsed wall time about six hours for the whole
package.

## What the WP40 R7 portable micro-KAT no longer covers

`tools/wp40/r7/node_semantics_fixture.lua` reconstructs node semantics from
`default`/`grug_*` plus three stair shapes and cannot resolve the new palette
(doors, beds, panes, wool, vessels, walls, grug_decor). This increment's
`tools/wp13/final_micro.lua` keeps the interpreter-equality property on the
WP13 fixtures; registration and param2 legality are covered by the library
KAT's registry scan and by the live engine runs. Teaching the WP40 fixture the
new mods is a WP40-lane follow-up.

## Zone atmosphere (same day, separate lane)

`mods/CORE/grug_core/atmosphere_zones.lua`: ten moods (six race regions,
battlegrounds, dragon islands, ocean, underground below y = -20) with full
lighting, sky colours, tinted fog and clouds, applied by a 2 s per-player
staggered globalstep only when the mood key changes; `/atmosphere auto`
resumes zone mode after a manual preset; `grug_atmosphere_zones` switches
it off. Independent Claude Opus review: CLEAN, five Low notes (ownerless
columns stay "ocean" at any depth by design; `fog_distance` is a hard cap on
every client's view range, 110 in undead land and 90 underground; KAT does not
re-join a left player; citation lines corrected before merge). Calibration:
implementing Claude Opus, reviewing Claude Opus, 0 Critical / 0 High, zero
fix rounds.

## Increment 4: Dawnmere Fields and the settlement roster (same day)

`docs/research/wp13-dawnmere-fields.md` records the human start and the
roster seam (`wp40/r7_settlement.lua`, one union palette channel, per-
settlement manifest identity, Hearthpine byte-identical). Independent Claude
Opus review: 0 Critical / 0 High / 2 Medium / 7 Low; one fix round
(`tools/wp13/evidence/20260914-dawnmere-fixes/`): grounded handcart
barrel, fatal prop placement with exact prop-population assertions (the
fix lane found 22 of 27 exterior props silently lost, not only the carts),
byte-order palette sorting, reserved roster keys, WP40 roster refresh.
Calibration: implementing Claude Opus, reviewing Claude Opus, one fix
round, final findings 0. The user accepted the zone atmosphere first
version on 2026-09-14 before seeing Dawnmere.

## Increments 5-8: four starts in parallel, then one integration

The remaining four races were built at the same time, each on its own branch
off `main` at `90d19ef`, each against the same shared library, and then merged
one after the other onto `wp13-starts`. Every lane therefore touched the same
nine or thirteen files, and every conflict was two lanes adding to the same
table; the integration kept both sides in anchor order and is recorded in
`tools/wp13/evidence/20260914-starts-integration/`.

| Increment | Start | Race | Anchor | Note | Review |
| --- | --- | --- | --- | --- | --- |
| 5 | Stillgrave Hollow | undead | 4 | `wp13-stillgrave.md` | 0C / 1H / 2M / 8L |
| 6 | Silverleaf Glade | elf | 3 | `wp13-silverleaf.md` | 0C / 1H / 1M / 4L |
| 7 | Sunscar Camp | orc | 5 | `wp13-sunscar-camp.md` | 0C / 0H / 2M / 8L |
| 8 | Kapok Cradle | troll | 6 | `wp13-kapok.md` | 0C / 1H / 2M / 5L |

**One combined fix round** for all four, plus two cross-cutting findings the
reviews raised against the shared library, recorded in
`tools/wp13/evidence/20260914-starts-fixes/`. The findings worth carrying
forward as library knowledge:

- **Two hashes over one position are rarely independent.**
  `dressing.undergrowth` picked cells with `(7x + 11z) % density` and chose
  the plant with `(x + z) % 4`, and 7x + 11z IS 3(x + z) modulo 4: at density
  4 one of the two plants could never appear. Both tests read different
  offsets into `parts.position_hash` now, and `library_kat` asserts every
  start emits both of its ground-cover nodes. Hearthpine Vale keeps the old
  selector as `dressing.vale_undergrowth` because its identity is in the
  frozen R7 manifest; exactly one caller is allowed and the KAT counts them.
- **A placement test that only guards an `if` is not a test.** Stillgrave
  lost six of ten burial-ground wall runs and three of 41 route lamps that
  way, and Dawnmere had already lost 22 of 27 exterior props to the same
  shape of code one increment earlier. Every placement in these compositions
  is fatal now, and every authored population is asserted.
- **A flag that switches an invariant off has to be checked itself.**
  `room.ruin` turns off the watertight-roof and lit-interior rules;
  `blueprint_kat` now requires a room that claims to be a ruin to have no
  door landmark in it, be nobody's destination, be unlit, and really have a
  column open to the sky.
- **Neighbour rules and support rules catch different defects.**
  `library_kat` section 11 requires every building cell to touch another
  across a face or a vertical diagonal (trees, wallmounted nodes and sprites
  excepted, each for a reason at the site) -- that is what found a bell
  hanging in mid air inside a four-course belfry. It does NOT catch a floor
  with nothing under it, because each such cell touches the podium beside it,
  so `blueprint_kat` separately requires every cell of a start's `paved`
  family to rest on something, with an exact declared population for the one
  start that raises its floors on purpose.
- **`attached_node` ratings are not interchangeable.** 3 is floor, 4 is
  ceiling (`reference_projects/luanti/builtin/game/falling.lua:391-399`).
  Kapok bound the floor lantern and hung sixteen of them from decks.
- **`<` on strings is `strcoll`.** Every composition sorts its palette with
  `parts.less_bytes`, and the KAT runs it against the identical comparator in
  `wp40/r7_settlement.lua` over a corpus chosen to separate them if they ever
  drift.
- **A generator must reproduce the schematic it claims.** The elf grove's
  crowns were the aspen's courses minus a "parity notch" that left 868 leaves
  with nothing on any face; the orc camp's relief was a Bannerbreak mesa in a
  Sunscar savanna. Both were decoded from the source (`aspen_tree.mts`,
  `world_zones.md` section 8.4) and rebuilt.

Calibration: implementing Claude Opus, reviewing Claude Opus, one combined
fix round across four lanes, final findings 0. Six starts built; none is
accepted until the user has walked it.

## Round A (user playtest), 2026-09-14

The user walked the six starts in the GUI client and came back with three
things the review rounds had not caught, all of them the same kind of defect:
a cell that is correctly placed, correctly oriented and correctly supported,
and still wrong, because the question nobody was asking was about the SHAPE of
the node or about what the running world does to it afterwards. Evidence:
`tools/wp13/evidence/20260914-round-a-blueprints/`.

- **A bottom slab's surface is half a node below the top of its own cell.**
  `roofs.flat_deck` capped every deck in Sunscar Camp with `roof_slab`, so the
  breastworks, the five braziers and the warlord's fighting top stood on half a
  node of air — 296 cells, on every parapeted building in the camp. A deck is
  walked on and built on, so it now caps with `roof_ridge`, the full cube of
  the same roof family; `roofs.combine` carries the flag, because
  `buildings.build` combines even a single block's field. `library_kat`
  section 8d is the rule: an upright `group:slab` cell may not have a non-air
  cell above it, in any start. A stair is exempt — its raised half reaches the
  top of its cell, which is the whole point of a stair.
- **A nodebox can float from above as well as from below.**
  `grug_decor:cottages_wagon_load` occupies y 0..0.5 of its cell, so the 15
  loads on Sunscar's wains rode half a node above their bearers and no
  full-node bearer could have closed it. The `cargo` role is
  `stairs:slab_acacia_wood` now, a half-height stack of boards that fills the
  bottom of its cell. Dawnmere's handcarts were already flush — their load is
  `grug_decor:xdecor_barrel`, a full cube — which is why the shape of the node,
  not the shape of the cart, is what the rule is about.
- **A blueprint can be correct and still not survive the world.** Dawnmere's
  crop furrows were `default:dirt`, the one and only name in default's "Grass
  spread" ABM, so the fields greened over minutes after the chunk went active
  while every fixture stayed green. Both courses of a field are now
  `grug_nodes:tilled_soil` (new optional role `crop_soil`, human palette only),
  which that ABM cannot reach and which is deliberately outside
  `NATURAL_GROUND_NODES`: `grug_materials`' audit requires only that every name
  IN that roster carries `grug_natural`, and putting authored ground under the
  mining transaction's pick-tier gating would be wrong. 3,267 tilled cells,
  asserted as a `blueprint_kat` ground row.
- **A substring of a node name is a spelling, not a property.** Six places in
  the library asked whether a cell may carry a wild plant as
  `below.name:find("dirt")`, so renaming Dawnmere's furrows silently took 425
  tufts and bushes out of its fields -- the look we want, arrived at by
  accident. All six ask `parts.wild_soil` now, whose rule is written down: a
  plant seeds itself in ground the MAPGEN generates, never in ground a
  settlement authored. `library_kat` section 7d proves every member is in
  `grug_materials.NATURAL_GROUND_NODES` and that the authored furrow is in
  neither roster, and `blueprint_kat` holds each start's two ground-cover
  populations at an exact count.

Two library rules came out of it and hold for every start from here:
`parts.Buffer:put` refuses any facedir axis but upright and upside-down and
refuses to flip anything that is not a stair or a slab (`parts.shaped`, proven
equal to the registry's `group:stair`/`group:slab` for every emitted name, in
both directions), and `library_kat` section 8e requires every upside-down
facedir cell -- gated on the node's own `paramtype2`, so a future `degrotate`
or `color` node is not caught by a number it uses for something else -- to be
a slab or a stair and to meet a non-air cell above it, since meeting what is
above is the only reason to flip a slab. There is exactly one such cell in the
six starts: the elf shrine's bell, which used to hang half a node below the
frame it is tied to. Section 8d deliberately grants no table-top exemption: a
prop on a bottom-slab table floats exactly as a breastwork on a bottom-slab
deck does, so a table that carries something is a top slab or a full node, and
8e then requires that flip to meet its load. The two rules compose into one --
a shaped node's surface must be at the top of its cell whenever anything rests
on it.

Calibration: implementing Claude Opus; no review round yet; Hearthpine
byte-identical at `760e0664…8ec9`; Stillgrave and Kapok untouched.

## User runtime test

Fresh world, dwarf, seed `531802985935182545` (Hearthpine y = 25):

1. Look around the arrival plaza (paving band, well, market stall, benches,
   planters), then walk the cross street west and east.
2. Open the forge hall's double doors, walk through the hall into the smithy
   wing, check the roof valley from outside.
3. Enter the four homes: bed, hearth with chimney, table and stools, shelves,
   barrel, rug, wall lights.
4. Visit the open timber workyard, the storage longhouse and the community
   hall.
5. Climb the watchpost's internal stairs to the lookout, check the roof, walk
   out under the gate arch.
6. `/atmosphere off`, `default`, `hearthpine` at midday and at night by the
   torches; `godrays` once to price it on your GPU.
7. Set night, follow the lit road plaza → gate; leave and reload.
