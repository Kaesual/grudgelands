# WP13: building library and Hearthpine rebuild (third increment)

Status: implemented, independently reviewed and fix-rounded on 2026-09-14;
awaiting the user's focused GUI playtest. Classification: non-trivial
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
