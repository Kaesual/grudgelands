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

Textures: the page switches between lane ART's set (`tools/r47_art/swamp`,
CC0, picked by the user 2026-10-13) and stand-ins (today's textures, some
tinted with a texture modifier). The olive tree leaves are ART's
`swamp_leaves.png` with the ART set (a tinted jungle leaf with the
stand-ins); the other choice is gravewood's grey.

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
| reeds, rooted (`grug_nodes:mud_with_reeds`, plantlike_rooted bed, leveled) | pool column on the bank; height = depth + 1 (50 %: + 2) nodes, so 1–2 above the water | 30 % | 20 |
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

## The nodes (built in step 1, registered, not placed yet)

The user picked the concept with lane ART's textures and the olive leaves
(2026-10-13). Ground and plants live in `grug_nodes` next to the mud (they
are swamp ground and its plants, and the mud's `dirt_groups` and sounds are
there); the leaves and the hanging moss live in `grug_trees` next to
gravewood (they belong to gravewood's wood: one leaf decay registration for
everything that decays with it, see below). Textures are ART's PNGs
(commits `3480a978` and `d7996ec8` for the leaves, CC0) under the mods' prefixes, provenance in each mod's
`LICENSE-media.md`. `tools/r47_sw/portable_test.lua` checks all of it.

| node | drawtype | groups, drops, digging |
|---|---|---|
| `grug_nodes:mud_dry` (lighter) | normal, top `grug_nodes_mud_dry_top`, sides and bottom `_side` | the mud's: `soil`, `mud`, natural loose ground (crumbly 3 = grug_loose 3); drops `grug_nodes:mud`; digs as mud |
| `grug_nodes:mud_mottled` | normal, `grug_nodes_mud_mottled_top` / `_side` | as above |
| `grug_nodes:mud_with_wet_grass` | normal, top `grug_nodes_wet_grass_top`, bottom `grug_nodes_mud_mottled_side`, sides `grug_nodes_wet_grass_side` | as above; the litters' grass footstep |
| `grug_nodes:moss_carpet` | nodebox `{-0.5, -0.5, -0.5, 0.5, -7/16, 0.5}`, `use_texture_alpha = "clip"` | snappy 3, `attached_node = 3`, flammable; `buildable_to`, `floodable`, not walkable; drops itself |
| `grug_nodes:reeds` | plantlike | snappy 3, flammable, like papyrus: a stack of 1–2, digging one takes those above (`default.dig_up`); drops itself |
| `grug_nodes:mud_with_reeds` | plantlike_rooted, `paramtype2 = "leveled"`: the mud bed (tile `grug_nodes_mud`) with reeds (`special_tiles`, `tileable_vertical`) up through the water; param2 = height in sixteenths | natural loose ground but no soil; drops `grug_nodes:mud`; digs as mud; not in creative |
| `grug_nodes:cattails` | plantlike, one node | snappy 3, flammable, `attached_node = 1`; drops itself |
| `grug_trees:swamp_leaves` | allfaces_optional, `grug_trees_swamp_leaves` (ART's olive leaves, commit `d7996ec8`) | as gravewood leaves: snappy 3, `leafdecay = 3`, `leaves`, drops nothing (gravewood leaves drop nothing, no sapling) |
| `grug_trees:swamp_hanging_moss` | plantlike, not walkable | snappy 3, `leafdecay = 3`; drops nothing; **not** `attached_node = 4` (that needs a walkable node above, so a strand's second node would fall) |

Swamp wood is gravewood's: its log and lane TA's base, branch and twig.

**Leaf decay.** `default.register_leafdecay` sets the trunks'
`after_destruct`; a second registration on the same trunk replaces the
first. So gravewood's one registration (`grug_trees/init.lua`) lists all
three: gravewood leaves, swamp leaves, hanging moss, radius 3. When lane
TA's tree shapes merge, its gravewood entry (`WOODS` in `shapes.lua`) must
list the same three leaves (it re-registers gravewood's decay with the
shape pieces as trunks), and the gravewood twig must join swamp leaves above
it as it joins gravewood leaves (`connects_to`, swamp leaves
`connect_sides = {"bottom"}`); the later of the two lanes to merge does it.

**Root ground.** The three grounds have `soil = 1`, so lane TA's
`register_on_mods_loaded` pass (every `soil`, `sand` and gravel node gets
`connect_sides = {"top"}`) takes them in with no change. The rooted bed is
no soil (nothing grows on it; a root does not dive into a pool).

**Step 2 adds them to `grug_materials.NATURAL_GROUND_NODES`** (it feeds the
WP43 handoff, so it moves the pins; step 1 leaves it alone).

Existing nodes reused: `grug_nodes:mud`, `grug_nodes:dirt_with_moss`,
`default:water_source`, `grug_mapgen:freshwater_waterlily`, ferns, grasses,
junglegrass, dry shrub.

## The pool rule on real terrain (user ruling, plan ruling 23)

A pool must never create flowing water. On gentle slopes the ground may be
levelled slightly so a small pool fits; on steep slopes pools are left out
(the ground mix, plants and trees carry the swamp there). Levelling never
touches towns, POIs or protected ground. The concept patch is flat, so it
shows only the flat case; the rule for step 2:

1. **Candidates**: swamp columns where the pool noise is below the pool
   threshold (as in the concept), not excluded: the column and its 8
   neighbours outside every claim exclusion the content tail already uses
   (`ctx.exclusion_at`: towns, capitals, POI cores and margins, roads,
   protected ground; the terrain damage guard's ground), and at least 2
   columns away from planned water, banks and the sea (a swamp pool never
   meets other water, so its level is its own).
2. **Gentle or steep**: take the ground tops `h` of the column's 5 × 5 window
   (itself ± 2) from the analytic terrain (`ctx.column_values_at`, valid
   outside the owner chunk too). Relief = max − min. **Gentle: relief ≤ 1**;
   **steep: relief ≥ 2 → no pool** in that column.
3. **Level**: the column's water level `L` = the lowest ground top in its
   5 × 5 window. The column's water top is at `L`: if its own ground was at
   `L + 1`, that top node is removed (air) — **levelling is at most one node,
   and only downwards, only in the pool column itself**; the banks stay as
   they are (every one of them is ≥ `L` by the definition of `L`). Water
   fills `L` (and `L − 1` for a 2-deep column), the bed below stays mud.
4. **No flow, after levelling**: a water source spreads only sideways into
   air at its level or lower, and down. A pool column is kept only if none
   of its 8 neighbours is a pool column with a lower level `L'` (else its
   water at `L` would spill into that neighbour's air at `L`). Dropping a
   column restores its ground (top `h ≥ L'` of every neighbour, since the
   neighbour's window holds it), so it never breaks a kept neighbour: **one
   pass decides**, and every kept water node then has, on each side, ground
   at least as high as its top, or water at the same level. Non-pool
   neighbours are ≥ `L` by step 3.
5. **2 deep** only where the column is kept, the deeper noise holds and all
   4 side neighbours are kept pool columns with the same `L`.
6. Everything above reads only analytic heights and the noise of a 9 × 9
   window round the column, so a column decides the same in every chunk
   (no cross-chunk state), the same way `world_content.lua`'s freshwater
   pass reads `column_values_at`.

Plants and lilies follow the kept pools; trees keep their 5 × 5 flat test
(`relief = 0`) on the final ground.

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
