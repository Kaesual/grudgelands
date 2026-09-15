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

2026-09-15, WP40 lane: the R7 source audit was refrozen to today's `main` and
`quality/final_micro.sh` was repointed off the dead `manifest_constructor_kat`
onto `tools/wp13/final_micro.lua` (`tools/wp40/r7/README.md`, "Refreeze of
2026-09-15"); the fixture follow-up above is still open and is now the single
remaining blocker of the R7 micro body — the roster's union palette is 178 node
names, of which 58 are `grug_decor` and 34 `stairs`.

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

## Round B (user playtest), 2026-09-14

Round A fixed three things inside the blueprints; the same playtest named three
things *around* them, and all three live in the WP40 height/route/decoration
layer. No blueprint file and no blueprint identity moved: the KAT trio and the
WP13 final micro digest `758c3e8c5facc9eb…`, which is main's own value after the
visuals and start-NPC lanes and is unmoved by this round, and the engine gate's
six per-start digests and combined `206a86a057b0b6ed…` are round A's. Evidence:
`tools/wp13/evidence/20260914-round-b-terrain/`.

- **A blueprint landmark and a compiled route can disagree, and only the
  landmark is read.** Every start opens a five-wide `main_street` on the z axis
  with its `gate` at anchor.z ± 63, and `source/catalog.lua` agrees — it places
  each start's `start_gate` station one node further out. The COMPILED route in
  `source/simple_map.lua` started at the zone hub, which IS the anchor centre,
  and its first bowed leg left the axis at once, so the road crossed the build
  envelope diagonally and surfaced 60-70 nodes beside the gate (Dawnmere and
  Kapok only 1-5, which is why nobody noticed it in a fixture). The gate-axis run
  is compiled into the centreline now: hub, the gate point at anchor.z ± 128, two
  eased vertices (smootherstep laterally, linear axially, so an S and not a
  re-spaced chord) and then the leg's OWN second bow point unchanged before the
  authored crossing pin. `height.lua` only
  rasterises it and reports the one thing the source cannot express — that the
  first segment carries the gate street's five-node width instead of the class's
  seven — through `make_path`'s new optional narrow leading prefix, whose three
  membership tests ask the segment width first while every bounding box keeps
  reading the path's widest values as the upper bound they are.
- **The vertex that decides a corner is the one before it.** The first attempt
  at the gate leg replaced the leg's FIRST bow point, which kept the vertex count
  and `pinned_point_index` at 4 and looked equivalent -- and moved the road's
  approach onto the chord, so the turn at the authored crossing pin went from
  22.3° to 62° at Hearthpine and from 91-101° to 133-138° on the three starts
  that already carry a switchback there. Keeping the SECOND bow point instead
  makes every pin turn byte-for-byte the authored one, at the price of two extra
  vertices (and therefore `pinned_point_index` 6, a graded-segment population of
  488 instead of 476, and up to 49° at the gate point). When a change to a curve
  has to leave a later corner alone, the vertex to preserve is the one that sets
  the heading INTO it.
- **A raster that its own source does not know about loses every rule derived
  from the source.** The first version of this fix rebuilt that leg inside
  `height.lua` and left the compiled centreline alone. It looked right and
  measured right on the gate axis, and it silently broke `world.md` §2 R1:
  `exclude:route:<id>` is compiled from the source polyline, so 3,779 of 3,779
  road columns on Hearthpine's approach — 3,862 of Silverleaf's, and thousands
  more across the other four — lay outside any claim exclusion, and vegetation
  could host one node off the carriageway where every other road keeps its
  ±8 corridor. The independent review found it by measuring the claim rule
  directly. **Geometry that consumers derive from belongs in the source**; the
  height layer may shape what the source authored, never author its own. The
  contract is now three `fail()` paths in `start_gate_prefix`: the compiled
  layout is load-bearing for the six start routes, and a source edit that moves a
  start hub off its anchor, takes a start off its z axis or drops the axis run
  stops construction instead of quietly putting the road beside the gate again.
- **One rule consulted twice is two gates, and narrowing one proves nothing.**
  `exclude:anchor:anchor_00N:01` covers a start's whole 256-node blend envelope,
  and both `r6_settlement.lua`'s decoration loops AND `r6_planner.lua`'s
  `dry_start_grade` host test read it. Narrowing only the settlement side left
  the ring exactly as bare as before — measured in the engine as `0/1888` cover,
  not assumed. The planner side was worse than narrow: because every dry
  start-grade column is inside that one exclusion, `not excluded` made the
  branch **unreachable**, so the whole envelope had no decoration host and
  `settlements.md`'s "dry start-fitting ground and blending slopes retain their
  biome surface materials" was not delivered by it.
  `static_exclusion_values_at` now takes a `purpose`; `"vegetation"` SKIPS the
  six start blend envelopes and lets the rest of the bucket answer. Skipping and
  not short-circuiting is the load-bearing detail: the blend envelope is the
  first shape in its bucket, so an early return would have opened the pad too.
  The 148-node hard core, the road corridors, planned water and the coast still
  refuse. Ring cover per start went from `0/…` to 2-25% of sampled columns and
  now matches the untouched biome beyond the envelope where the corpus reaches
  it (Sunscar 22.4% against 21.6%); the pad and its ten-node apron stay at 0.
- **A smootherstep ramp hides a radius jitter almost completely.** The pad's
  flat/slope boundary is an exact 128 square, and `height.lua` now pushes it
  outward by 0..6 seed-derived nodes from one memoised value-noise lattice per
  start while shrinking the ramp's span by the same amount — outward-only and
  span-compensated, so excess 0 keeps weight Q and the outer envelope edge keeps
  weight 0. Measured against the same bytes with only that branch disabled:
  nothing inside the envelope, in the apron or beyond 128 changed by a single
  node. But the ramp is a 64-node smootherstep
  carrying at most eight nodes of cut or fill, so the rendered contour only
  moves by one or two nodes, and the flat radius per ray was already irregular
  (63…126, 27-41 distinct values per start). **After the vegetation fix the most
  visible square around a start is the treeline on the 148-node protection
  square**, which is a rule and not a look; softening THAT outline is the next
  lever and was deliberately not taken here.

Four library rules come out of it. A landmark the blueprints export is the
authority on a settlement's geometry, and any WP40 layer that has its own idea
of the same geometry has to be measured against it rather than trusted.
Geometry other rules are derived from belongs in the compiled source, and the
height layer may shape what the source authored but never author its own. And a
"narrow the suppression" fix is not done when the suppression it knows about is
narrowed: count the thing that should appear, in the engine, before believing
it.

Calibration: implementing Claude Opus; two independent Claude Opus reviews.
First verdict merge-after-fixes, one blocking finding (the approach outside its
own claim exclusion) plus one medium and one record correction; the fix round
moved the gate-axis prefix from `height.lua` into the compiled source. Second
verdict merge-after-fixes, no code defect, one finding about the relocated corner
at the crossing pin plus two record items; the second fix round keeps the leg's
second bow point and updates `pinned_point_index`, the graded-segment population
and the records. Blueprints
byte-identical, six per-start engine digests unchanged, the WP13 final micro pair
`758c3e8c5facc9eb…` — main's own value, unmoved by this round.

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
