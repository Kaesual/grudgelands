# Tree rework — handoff for the build round

Round 46, lane TREE, closed 2026-10-13. This document is for the coordinator
who plans the round that builds the new trees into the game. It links rather
than copies; the binding detail is in the concept sources.

## 1. Goal and status

The user wants better-shaped, varied, still blocky trees for all eight tree
species (apple, jungle, kapok, acacia, pine, aspen, silverwood, gravewood):
a readable growth logic (stem → limbs → twigs → leaf clusters at the twig
ends, thinning outwards), variation from that logic's parameters rather than
noise, round irregular crowns, each species keeping its character.

**Status: the concept is approved** in a 3D browser viewer ("everything fits
now"). Nothing is in the game yet. Everything shown in the viewer was designed
to be buildable in Luanti exactly as shown.

- Viewer: [`tools/r46_tree/concept/trees.html`](../../tools/r46_tree/concept/trees.html)
  (open in a browser; Four / Grove / Shapes views, seeds, leaves off,
  JSON export of the node lists).
- Sources: [`treegen.js`](../../tools/r46_tree/concept/treegen.js) (the
  generator), [`shapes.js`](../../tools/r46_tree/concept/shapes.js) (the wood
  shapes, writes [`models/grug_tree_quarter_oct.obj`](../../tools/r46_tree/concept/models/grug_tree_quarter_oct.obj)),
  [`viewer.js`](../../tools/r46_tree/concept/viewer.js) (meshes nodes the way
  the client does), [`check.js`](../../tools/r46_tree/concept/check.js).
- Rebuild: `python3 -I tools/r46_tree/concept/build.py` (`--check` verifies);
  checks: `node tools/r46_tree/concept/check.js 500`.
- Growth concept per species, parameter ranges and engine notes:
  [`DESIGN.md`](../../tools/r46_tree/concept/DESIGN.md) — the reference for
  the port.
- Jungle bark: the artist lane's candidates in `tools/r46_tree/astra/bark/`
  (branch `r46-astree`, merged next to this one); the pick is **M**.

## 2. The user's decisions (binding)

- Trunk quarter piece: **octagon** profile, 3 faces per quarter (half-width
  flat, slant, half-width flat), as a **mesh** node; the 16-gon was tried and
  dropped.
- **No square foundation and no square collars**; trees start at the ground
  with the slanted pieces; 1 × 1 trunks stay the existing log cube.
- **Limb base** is the 4th shape: 12/16 thick, level arms reaching 8/16 into
  the neighbour cell, closing the join to the slanted trunk face.
- **Twigs join a leaf only above them** (leaves get `connect_sides = {"bottom"}`).
- **Roots** join the ground only through the bottom of a limb base or a twig
  (ground nodes get `connect_sides = {"top"}`); per species: apple only on
  2 × 2 trees, rarely, length 1; jungle only on 2 × 2 trees, some from
  height 2; kapok always, mostly from height 2–3, one out then down the trunk,
  often forked; all others none. A **per-cell ground test** places them:
  nothing where the ground falls away or rises.
- Acacia foliage one node lower (sits on the twigs).
- Gravewood: downward growth clearly rarer, somewhat more foliage.
- Aspen and silverwood crowns wider; silverwood foliage 2–3 nodes lower.
- Apple foliage a little more spreading.
- Jungle: its irregular growth is kept.
- Kapok: a 3 × 3 trunk narrows to 2 × 2 only inside the crown (no visible ledge).
- Jungle bark **M** (deep russet ridges; CC0, GPT-6 Astra, provenance in
  `tools/r46_tree/astra/bark/LICENSE-media.md`) for jungle and kapok.
- The species tuning is approved **as it stands** in `treegen.js`.

## 3. Shape set

Per wood type 4 shapes; units 1/16 node, boxes `x1, y1, z1, x2, y2, z2`
centred on the node. Exact data: `shapes.js`; rationale: `DESIGN.md` "Shapes".

| shape | drawtype | geometry | param2 |
|---|---|---|---|
| quarter | `mesh`, `grug_tree_quarter_oct.obj` | outline seen from above, outwards from the axis corner: (16,0) → (16,7) → (7,16) → (0,16); full height; caps (material 1, `*_tree_top`) and bark sides (material 2, u round the outline, v up: grain along the trunk); the two axis-side faces omitted; collision/selection: full cube | facedir 0..3, inner corner (trunk axis) at +x +z for 0 |
| base | connected nodebox | core `{-6,-6,-6,6,6,6}`; level arms to 16, e.g. right `{6,-6,-6,16,6,6}`, front `{-6,-6,-16,6,6,-6}`; top/bottom arms to the border | facedir 0 / 4 / 12 = bark grain along y / z / x (tiles only) |
| branch | connected nodebox | core `{-5,-5,-5,5,5,5}`, arms to the border, e.g. right `{5,-5,-5,8,5,5}` | as base |
| twig | connected nodebox | core `{-3,-3,-3,3,3,3}`, arm right `{3,-3,-3,8,3,3}` | as base |

- 3 × 3 trunk: corners are quarters, edges and centre plain logs; 2 × 2:
  four quarters; 1 × 1: plain log (logs also take facedir 0/4/12 when lying).
- `connects_to` (same wood type throughout): base → log, quarter, base, branch,
  twig, ground; branch → log, quarter, base, branch, twig; twig → log, quarter,
  base, branch, twig, leaves, ground. "Ground" = `group:soil` (dirt, grass,
  the litters, blight dirt, mud), `group:sand`, `default:gravel`.
- Overrides: the seven leaf nodes `connect_sides = {"bottom"}`; the ground
  nodes `connect_sides = {"top"}`.
- Every shape drops the wood type's trunk item, copies its groups, is in the
  leaf-decay trunk list (radius 3 for all species; the generator keeps every
  leaf within 3 of wood) and should refuse being placed by players.
- **Node count: 7 wood types** (apple/oak, jungle — also kapok —, acacia,
  pine, aspen, silverwood, gravewood) **× 4 shapes = 28 new nodes**, plus one
  shared `.obj`.

## 4. Engine facts (verified in `reference_projects/luanti`) and open checks

Verified:

- Mesh nodes: cloned and turned by facedir per node, lit per vertex (smooth
  lighting) or by face shading from the normal, no triangle culled
  (`src/client/content_mapblock.cpp` `drawMeshNode`); solidness 0, so
  neighbours' faces toward them are not culled either
  (`src/client/node_visuals.cpp:372`); `.obj` scaled 1 unit = 1 node
  (`NodeVisuals::updateMesh`); the OBJ loader negates x and flips v
  (`irr/src/COBJMeshFileLoader.cpp:314`, `:331`) — `shapes.js` writes for it.
- Node boxes may reach beyond their cell; keep within ±1.45 nodes
  (`doc/lua_api.md` "Node boxes"); the base uses ±1.0.
- Connected boxes never turn with facedir, but `drawNodeboxNode` takes tiles
  through `getTile`, which applies the facedir tile rotation
  (`mapblock_mesh.cpp` `getNodeTile`).
- `nodeboxConnects` (`src/nodedef.cpp:1270`): two connected nodeboxes join
  if each lists the other; any other target joins if listed and, when it
  declares `connect_sides`, only through those faces.
- Fancy leaves draw all six faces; node-box faces are culled only on the node
  border against full cubes (step-1 findings, same files).

Still to check in the engine (first lane, one capture each):

1. Bark grain: facedir really turns a connected box's tiles in game.
2. Mesh quarter: caps and slants lit cleanly, no seams between quarters,
   the OBJ mirroring right (a lying-on-its-side test helps).
3. Render cost of a forest of the new trees, desktop and web client, compared
   with today's (numbers below are counted quads, not measured frames).
4. Template rotation of facedir 4/12 bark grain and quarter turns
   (`r6_templates.lua` `rotate_param2` handles facedir; confirm visually).

Capture method: the step-1 engine capture (`tools/r46_tree/capture.sh`,
probe `grug_probe_r46_tree`, removed in this round's wrap-up; last commit that
has them: `de5c8400`) booted the game headless with one real client on a
private Xvfb. Worth reusing: Debian's Xvfb needs `LIBGL_DRIVERS_PATH=/usr/lib64/dri`
for GLX on this host, and `LC_ALL=C` is required (see `tools/luanti_headless.sh`).

## 5. Integration plan (proposal)

- **Port `treegen.js` to Lua 1:1** (pure, no engine calls). It uses only
  integer maths on doubles, a 16-direction table, Park–Miller random numbers,
  an explicit cell order and sorted output (`DESIGN.md` "Porting to Lua").
  Verify with a fixture: JSON of the node list for a few hundred seeds per
  species equal to the JS output (commit the JS reference JSON or run node in
  the fixture tooling).
- **Wild trees**: N seeded variants per species written as `.mts` by a
  committed tool (`--check`), each a template row in the WP40 R6/R7 pipeline
  (`mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua` DECORATION_ROWS,
  `r6_templates.lua`). Limits there: x/z ≤ 16, y ≤ 64, ≤ 16384 cells,
  quarter-turn rotation via facedir (4dir refused). Template nodes must be in
  the R7 production content list (`r7_content.lua`); new nodes, new templates
  and the leaf/ground overrides move the frozen source projection pins in
  `r7_manifest.lua` (`decoded_templates`, `accepted_r6_content`, production
  semantics) — expected, renew them. Wider footprints (kapok up to 16) raise
  mapchunk-owner clipping (`current_mapchunk_owner_intersection_v1`): measure
  the losses with the seed fleet (`tools/seed_fleet`).
- **Roots**: not in the schematic (placement cannot test the ground per cell).
  Each variant carries its root runs as optional cell lists; the R7 writer,
  which already holds the VoxelManip data, tests two column nodes per cell
  and writes a run only if all pass. Saplings do the same with
  `core.get_node` after placing the schematic.
- **Saplings**: grow by position-hash seed → the Lua generator → place.
- **Towns**: `mods/MAPGEN/grug_mapgen/wp13/dressing.lua` (`jungle_tree`,
  `emergent`) puts trees cell by cell; switch it to the generator's cells.
- **Markers**: `wp40/vegetation_density.lua` maps rows to saplings and trunk
  markers; add the new shape names to the markers.
- **Classification: map reset** (new mapgen content and digests).
- **Fixtures**: the port's JSON-equality fixture; a node fixture (28 nodes:
  drops, groups, connects, leaf decay, placement refusal); the template
  `--check`; the mapgen digest fixtures renewed; one seed-fleet run.

Lane split (estimates, marked as such):

| lane | content | size (estimate) |
|---|---|---|
| A nodes | 28 nodes, mesh, overrides, drops, leaf decay, bark M texture, the four engine checks above | medium |
| B port | Lua generator + JSON-equality fixture + `.mts` variant writer | medium |
| C world | template rows, digests, roots pass, saplings, towns, markers, seed fleet | large; after A and B |
| D cost | forest render cost desktop and web, today vs new | small; after C (or on A's test area) |

## 6. Numbers

Mean of 500 seeds per species (concept) vs today's schematic; wood = log +
quarter + base + branch + twig; quads counted as the client draws them
(leaves 6 each, culled log faces, node-box faces on the border against logs,
quarter mesh 6), not measured.

| species | today: wood / leaves / height / quads | concept: wood / leaves / height / quads | new-shape nodes |
|---|---|---|---|
| apple | 9 / 72 / 8 / 494 | 58 / 203 / 9.8 / 2339 | 56 |
| jungle | 35 / 90 / 17 / 684 | 43 / 123 / 14.2 / 1257 | 35 |
| kapok | 309 / 232 / 33 / 2038 | 221 / 387 / 23.8 / 4744 | 173 |
| acacia | 14 / 81 / 9 / 560 | 27 / 130 / 7.6 / 1274 | 24 |
| pine | 14 / 86 / 16 / 574 | 30 / 97 / 14.5 / 1034 | 22 |
| aspen | 12 / 106 / 14 / 686 | 21 / 111 / 13.7 / 976 | 14 |
| silverwood | 12 / 106 / 14 / 686 | 49 / 218 / 18.7 / 2066 | 39 |
| gravewood | 17 / 5 / 7 / 100 | 48 / 7 / 8.6 / 782 | 39 |

Today's kapok is `emergent_jungle_tree.mts` without its 4 buried layers;
silverwood today is the aspen schematic. The concept costs about 1.4–4.7×
today's quads per tree (apple the most, through its fuller crown; gravewood 7.8× from a nearly bare start).

## 7. Open questions for the user

1. How many variants per species? Recommendation: 8 (kapok 6); more seeds
   only add `.mts` files, not shapes.
2. Should town trees (`wp13/dressing.lua`) use the new generator too?
   Recommendation: yes, the same cells, so towns match the wild.
3. If the cost lane finds the leaf counts too heavy on the web client: trim
   crowns or accept? Recommendation: decide on measured numbers, not before.

## 8. Release context (coordinator, 2026-10-13)

- Main is release **0.46.0** (a map reset, world generation and player feedback),
  **not pushed and not deployed**; the user's GUI test of 0.46.0 is pending
  (checklist in [`round46-plan.md`](round46-plan.md) "Completion"). Findings from it
  may join the build round.
- The tree build is also a map reset. **The user decided (2026-10-13): 0.46.0,
  the trees and further map-touching items of the next round go to the server
  together**, so the production world resets once.
- Bark M replaces the jungle tree textures, which live in the vendored
  `mods/BASE/default` (`default_jungletree.png`, `default_jungletree_top.png`):
  either a `-- GRUG PATCH:` texture override with a VENDOR.md entry, or new
  `grug_*` texture names on the jungle nodes; the build round picks one. The
  artist's hand-made apple study (`tools/r46_tree/astra/apple.html`) was not
  chosen; it stays as reference only.
