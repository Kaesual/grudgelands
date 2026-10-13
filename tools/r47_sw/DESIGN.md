# Swamp concept (Round 47 lane SW, concept step)

The page `swamp.html` (built by `build.py`) draws a 48 × 48 swamp patch from
a seed with the rules below (`patch.js`), and the swamp tree from the tree
concept generator (`tools/r46_tree/concept/treegen.js`, species `swamp`).
Every seed is a new patch from the same rules. Everything on the page is a
node the client can draw: cubes, liquid sources, plantlike, plantlike_rooted,
the waterlily's thin box, a 1/16 carpet box, and the tree shapes of the tree
concept. This file is the build lane's starting point.

```
python3 -I tools/r47_sw/build.py            # write swamp.html (--check: fail if stale)
node tools/r47_sw/check.js [200] [500]      # patch rules, swamp tree rules, page parses
node tools/r47_sw/digest.js                 # the eight approved trees are unchanged
node tools/r46_tree/concept/check.js 500    # the rules every species shares, swamp included
```

Textures: the page switches between lane ART's proposals
(`tools/r47_art/swamp`, CC0, not picked yet) and stand-ins (today's
textures, some tinted with a texture modifier). The olive tree leaves are a
tinted jungle leaf (placeholder); the other choice is gravewood's grey.

## Terrain and pools

Heights are relative to the swamp's ground level 0 (the top node of a
column). Noise is integer value noise on a mixed hash lattice (the kind
`world_content.lua`'s `reef_noise` uses; a plain linear hash gave visible
straight runs of waterlilies, so a second hash round folds the value first).

- **Hummocks**: two-octave noise (period 9) above 700/1024 → the column is
  one node up. About 11 % of columns.
- **Pools**: water noise (period 11) below 370 on a flat column whose eight
  neighbours are flat too (none is a hummock, the patch border is land): the
  top mud node becomes a water source, **1 deep**. Where the noise is below
  290 and all four side neighbours are water too, the node below is water
  as well: **2 deep**. The bed under the water stays mud. No water source
  ever has a lower or open neighbour, so nothing flows. About 14 % of
  columns are water, a third of it 2 deep.
- A liquid source draws its top at the node border (`getCornerLevel`: a
  source is always full height), so the water is flush with the ground, and
  the waterlily's box (`-0.5 .. -15/32` of the node above) lies on it.

## Ground mix (land columns)

| ground | rule | share of land |
|---|---|---|
| mud (today's `grug_nodes:mud`) | everything else | 45 % |
| lighter mud (new) | ground noise (period 6) below 360 | 12 % |
| mottled mud (new) | within 2 of water | 17 % |
| wet grass (new) | ground noise above 680; hummocks with noise ≤ 600 | 16 % |
| moss soil (`grug_nodes:dirt_with_moss`, exists) | hummocks with noise > 600; within 3 of a trunk with noise > 560 | 9 % |

The filler below stays mud (biome row: mud, depth 2), and the pool beds are
mud.

## Plants (at most one per column, in the node above the ground)

Chances per column, in this order; per 1000 columns of a patch on average
over 200 seeds:

| plant | where | chance | per 1000 |
|---|---|---|---|
| waterlily (`grug_mapgen:freshwater_waterlily`, exists, param2 0–3) | pool column not on the bank | 22 % | 16 |
| reeds, rooted (new, plantlike_rooted in the bed, leveled) | pool column on the bank; height = depth + 1 (50 %: + 2) nodes, so 1–2 above the water | 30 % | 20 |
| reeds (new plantlike, 1–2 nodes, 45 % two) | land beside water | 32 % | 32 nodes |
| cattails (new plantlike, 1 node) | land beside water | next 18 % | 14 |
| moss carpet (new, 1/16 box) | mud within 3 of a trunk 40 %; mud beside water next 12 %; other mud 4 % | | 66 |
| fern 1–3 (exists) | within 3 of a trunk 30 %; moss soil 22 % | | 40 |
| tall grass 3–5, junglegrass (exist) | wet grass 34 %; mud 9 % | | 89 |
| dry shrub (exists) | anywhere on land | 1 % | 7 |
| swamp tree | flat land 2 round the trunk (5 × 5, no water), 8 apart; 40 tries per patch | | 4 per 1000 land columns (≈ 1/250), 8 per patch |

Cattails stay on land: a plantlike_rooted plant tiles its texture once per
node of height (`drawPlantlikeQuad`, `vertical_tiling = plant_height`), so
a rooted cattail of 2 would show its seed heads twice. Reeds tile cleanly.
A plantlike node can not stand in water (it would replace the source and
leave a hole), hence rooted reeds in the pools.

## The swamp tree (`swamp` in treegen.js, salt 9)

Gravewood's wood nodes and shapes (log cube, base, branch, twig), 1 × 1:

1. **Stilts**: the stem's foot stands 1–2 nodes up. 3–4 stilts on different
   sides (50 % 1 out, 50 % 2 out; a 2-out stilt leaves one higher in 45 %;
   25 % turn a corner one step sideways): a base leaving the stem sideways,
   branches out, then straight down to the foot level, where the last cell
   is a twig that joins the mud below (twig and base list the ground in
   `connects_to`, the ground declares `connect_sides = {"top"}`, as the tree
   concept's roots). A stilt touching other wood is left out. Mean 3.0.
2. **Stem**: 4–5 logs above the stilts; a knee 3 up towards its lean, in
   55 % a second right above it turned aside: a zigzag.
3. **Crown**: 3–5 limbs evenly round from the top 3 stem layers, reaching
   3–4.75 nodes out (targets kept within ±5 of the axis) and rising 0–1
   node; a third droop one out and down at the end; every end forks into two
   short level prongs. A flat pad (radius 1.9–2.6, half height ~1, cut flat
   at its centre layer) sits one above each end, a small one on a stub
   leader. Sparse: the outer band from 30 % depth keeps only 42 % of its
   cells. Mean 36 leaves (gravewood 6.5, apple 203).
4. **Hanging moss** (new kind `moss`): 4–9 strands of 1–3 nodes under
   leaves, branches or twigs with open air below, at least 3 up, each node
   within the leaf decay reach (3, cube search) of wood. Mean 12.5 nodes.

Height 7–10 (mean 8.0), wood within 15, leaves within 16 wide (mean 12).
Nothing tests the ground: the stilts always end at the foot level, so the
tree is the same on any terrain; the patch places trees only on flat land.
The stilts and moss use the tree's one random stream (no own stream, unlike
roots, because nothing depends on the ground).

## New nodes the build would need

| node | drawtype | notes |
|---|---|---|
| lighter mud, mottled mud | normal | top + side textures (ART: `mud_dry_*`, `mud_mottled_*`); soil groups like mud; `connect_sides = {"top"}` with the other grounds |
| dirt (mud) with wet grass | normal | top + side (ART `wet_grass_*`); bottom mud or mottled side |
| moss carpet | nodebox `{-0.5, -0.5, -0.5, 0.5, -7/16, 0.5}` | `attached_node = 3`, `buildable_to`, not walkable; texture with alpha (clip) |
| reeds | plantlike | stackable like papyrus (1–2) |
| reeds rooted in mud | plantlike_rooted, `paramtype2 = "leveled"` | tiles mud, `special_tiles` reeds with `tileable_vertical`, like `grug_mapgen:freshwater_waterweed` |
| cattails | plantlike | one node |
| hanging moss | plantlike, not walkable | **not** `attached_node = 4`: that needs a walkable node above (`check_attached_node`), so the second node of a strand would fall; instead list it with the swamp leaves in the tree's leaf decay (the generator keeps it within reach 3) |
| swamp leaves | allfaces_optional | only if the olive leaves are picked; else gravewood's leaves |
| swamp wood | — | gravewood's log, base, branch and twig (lane TA's shapes) |

Existing nodes reused: `grug_nodes:mud`, `grug_nodes:dirt_with_moss`,
`default:water_source`, `grug_mapgen:freshwater_waterlily`, ferns, grasses,
junglegrass, dry shrub.

## Mapping to the WP40 pipeline

Facts at `d459eef2`:
- biome row `grug_swamp|grug_nodes:mud|grug_nodes:mud|2|grug_nodes:mud|grug_nodes:mud|-`
  (`wp40/r7_r6_manifest.lua`);
- `r6_content.lua`: `dry_row` returns the swamp's plain surface before any
  patch noise, and `fertile_palettes` has no swamp entry;
- decoration rows `swamp_dry_shrub` (simple, 1/250) and `swamp_papyrus`
  (template `papyrus_on_dirt.mts`, 1/50, surface y 1–4) are the swamp's
  only ones;
- waterlilies come from `world_content.lua`'s freshwater pass, in every
  biome, on planned water 2–6 deep, 1/192 — not on 1-deep pools.

Suggested place for each part (the build lane decides):

1. **Ground mix**: a swamp palette in `fertile_palettes` and a swamp branch in
   `dry_row` instead of its early return, with the rules above (light mud,
   wet grass from patch noise; mottled mud needs the distance to the pools,
   so it belongs with step 2).
2. **Pools and hummocks**: a deterministic pass over swamp columns in the
   R7 writer's content tail (where `world_content.lua` places freshwater
   plants with `reef_noise`), writing 1–2 water sources into the top mud
   when the column and its eight neighbours are flat swamp land inside the
   owner chunk (`ctx.inside_owner`, `ctx.column_values_at`). The tail's
   P9G writer knows only its 36 content refs today; water and the new
   ground nodes would join that list, or the pass goes into the surface
   writer. Hummocks (+1) are the same pass or a small terrain offset.
3. **Plants**: rows for the plain chances (tall grass on wet grass, ferns on
   moss soil, carpets, dry shrub) as `simple` decoration rows; the
   bank and shade rules (beside water, near a trunk) need the tail pass of
   step 2 (it knows the pools; the catalog's `shore` test is the model);
   waterlilies on swamp pools in the same pass (the freshwater rule wants
   depth ≥ 2), rooted reeds as P9G writes with a leveled param2 like the
   waterweed.
4. **Trees**: templates of the `swamp` species through TC's template
   mechanism, a template decoration row on swamp ground; the 5 × 5 flat
   test and the 8-node spacing are the writer's (decorations can not test
   a footprint), or accept a stilt that ends a node above lower ground.
5. The swamp species in both generators with TB's equality fixture.

All of this changes the frozen mapgen digests (map reset, fine). Pins move
in `wp40/r7_manifest.lua` and the WP43 projection.
