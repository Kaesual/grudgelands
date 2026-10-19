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

## The nodes (built in step 1, placed from step 2 on)

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

## The pool rule on real terrain (user ruling, plan ruling 23) — built

A pool must never create flowing water. On gentle slopes the ground may be
levelled slightly so a small pool fits; on steep slopes pools are left out
(the ground mix, plants and trees carry the swamp there). Levelling never
touches towns, POIs or protected ground. Built in step 2 as
`mods/MAPGEN/grug_mapgen/wp40/swamp_pools.lua` (pure, per column):

1. **Candidate**: a dry swamp land column whose pool noise (two octaves,
   periods 11 and 6) lies below 370/1024, with its 8 neighbours dry swamp
   land too, none of the 9 under a static claim exclusion (towns, capitals,
   POI cores and margins, protected ground), a road or inland-water
   overlay, a functional surface, a hard foundation, a coast material or a
   surface cave, and no water column (sea, lake, river) in its 5 × 5 window.
2. **Gentle or steep**: the ground tops of the 5 × 5 window differ by at
   most 1 (gentle), else no pool. Ground at least 2.
3. **Level** `L`: the window's lowest ground top. A column one above it
   loses its top node: **at most one node, only downwards, only in the
   pool column**. Water fills `L` (and `L − 1` when 2 deep).
4. **No flow**: a candidate is kept only if none of its 8 neighbours is a
   candidate with a lower level. A dropped column keeps its ground, at
   least each neighbour's level (their windows hold it), so one pass
   decides; every kept water node has ground or water of its own level on
   its four sides and ground or water below.
5. **2 deep** where the deep noise (period 9) lies below 290 and all four
   side neighbours are kept with the same level.
6. Only analytic heights and noise of a 9 × 9 window: every chunk decides
   the same.

Around it: the surface selector gives a pool column plain mud over a filler
of 3 and the columns within 2 of a pool mottled mud; the planner roots no
decoration in a pool column; the writer's surface skin never opens at a
pool or beside one (an opening would drain it); the swamp pass
(`wp40/swamp_writer.lua`, in the R7 successor right after the road
dressing, before P9G and world content, which then see the water) writes
the water through `write_road`, only over a swamp ground, removes a
levelled top only when nothing but air or a plant stands on it (where the
top stays, the column keeps its mud: no water hidden under ground), and adds
the waterlilies (22 % of inner pool columns), reeds rooted in the bed
(`grug_nodes:mud_with_reeds`, 30 % of bank pool columns, 1–2 above the
water) and, on the dry bank, reeds 1–2 high (32 %), cattails (18 %) and
carpets (12 %).

## As built (step 2)

- **Ground mix** (`r6_content.lua`, `dry_row`'s swamp branch): moss soil
  where a period-20 noise lies above 820, wet grass where the wet noise
  (periods 12 and 5) lies above 680, mottled mud below 300, the lighter mud
  where a period-9 noise lies below 300, else mud; mottled within 2 of a
  pool. Shares of the noise alone over the whole map (seed 12345): mud 54 %,
  wet grass 15 %, lighter mud 13 %, mottled 10 % (more round the pools),
  moss soil 9 %.
- **Rows** (`r7_r6_manifest.lua`, hosts in `r6_content.lua` SWAMP_HOSTS):
  `swamp_tree` 1/120 (treegen:swamp) on all five grounds; tall grass 3–5
  1/9 each and junglegrass 1/20 on wet grass (a quarter on the muds); ferns
  1–3 1/14 each on moss soil (a quarter on mottled); moss carpet 1/16 on the
  muds; dry shrub on mud and the lighter mud; papyrus as before (mud,
  mottled mud, sand).
- **Swamp trees**: the `swamp` row of TC's species table
  (`tree_templates.lua`: 32 variants, gravewood wood, swamp leaves, hanging
  moss). Its stilts (limb cells up to one above the stem's lowest log) are
  optional cells like leaves, so higher ground shortens a stilt instead of
  refusing the tree. The concept's flat 5 × 5 placement is the row's
  `stilt_ground` rule (r6_planner.lua, rule 4): no column within 2 lies
  lower than the root's ground or is a pool, so every stilt ends on ground
  (seed 12345, 12 chunks of the probe: 0 of 39 stilt ends hang; without the
  rule 5 of 47 did). No swamp sapling: the row is not renewed.
- **Content**: six production rows (116 → 122); the three new grounds in
  `grug_materials.NATURAL_GROUND_NODES`; pins in their own commit.
- **Habitats**: the swamp's mob spawn lists (`grug_mobs/*.lua`,
  `spawn_regions.lua`) take mud_dry, mud_mottled and mud_with_wet_grass
  next to mud; the three swamp-only lists (crocodile, bog ooze, bog fowl,
  zone-gated to the swamp family) take moss soil too (the user,
  2026-10-13); the gathering catalog's swamp hosts,
  world content's swamp soil and the P9G hosts take all five grounds (they
  are per biome); renewal knows the pass's plants as natural.
- **Proof**: `tools/r47_sw/portable_test.lua` (the rule on a synthetic
  world with flat, gentle and steep swamp, a town, a lake, a road, a cave
  and a coast: no pool where it must not be, no open water side; the pass
  on a fake context), `tools/r47_sw/world_probe.lua` (the real writer over
  the seed fleet's fake VoxelManip), `tools/r47_sw/capture.sh` (engine
  screenshots and the in-engine pool check).

## Round 51: the land viewer (lane VIEW)

`land.html` extends this page into a viewer of every land zone, for the
user's picks (land plan ruling 1: nothing goes into the game before the
user has picked it here). The swamp page stays as it is (`swamp.html`);
both share the mesher (`mesh.js`) and the swamp patch (`patch.js`).

```
python3 -I tools/r47_sw/build.py [--local FILE]   # swamp.html and land.html (+ a wrapped copy for file://)
python3 -I tools/r47_sw/build.py --check          # fail if either is stale
node tools/r47_sw/land_check.js [12]              # the land patches, kit, plant rows and page
```

`land.html` is page content only (a `<title>`, the `<style>`, the markup,
the scripts): the publisher wraps it. It inlines the zone data that
`build.py` reads from the mapgen sources (`SURFACE_ROWS` and
`DECORATION_ROWS` of `wp40/r7_r6_manifest.lua`, `fertile_palettes` of
`wp40/r6_content.lua`, the default schematics, the gathering sources of
`grug_gathering/catalog.lua` with the look `presentation.lua` gives them),
the props of `tools/r51_land/props` (the prop format of
`tools/r51_land/README.md`), and every texture the sources name plus all of
`tools/r51_land/{swamp,grounds,plants}` for the texture lab.

**Views.** A zone switcher (swamp, jungle, undead, dwarf, orc badlands,
elves, savanna, beach) and a biome per zone; **Patch** (Today, Proposal or
side by side, a seeded 48 × 48 patch), **Kit** (the zone's structures and
single blocks in rows, numbered, each with every block and its drop),
**Plants** (the zone's gathering sources, brown labels, next to its new
plants, ruling 11) and **All notes**. The texture lab of the swamp page
(pick or upload a texture per ground slot; 32 / 64 px drawn world-aligned)
and the "one ground everywhere" switch stay; the lab acts on the proposal
side. Default: the jungle, proposal on.

**Today's patch** (`land.js`, `generate`): a faithful-enough reading of
the zone, not a port of the mapgen. Where it simplifies:

- **Relief** is value noise per biome (amplitude and period by eye; the
  badlands get mesa steps for steep faces, the beach slopes into the sea
  with a small pool inland). Real terrain, rivers and roads are not
  modelled.
- **Ground mix**: `dry_row`'s patch noise and thresholds (palette 1, 2, 3,
  gravel, stone; the crags' own) on our noise, not the world's; a steep
  face is stone (a drop of 3 or more) or gravel (2) instead of the rock
  and lip rows; the snowy crags get their snow dust. The beach is sand
  within 9 of water (the coast rule) and shingle and rock further up.
- **Decorations**: every row of the biome with its density
  (`num / den`) on its host and the biome's fertile palette (gravel at a
  quarter for low plants), templates first, then simple rows, one per
  column, in a seeded column order; a template must fit (its wood free).
  Generated trees are the tree concept's (`treegen.js`), not turned by
  quarter turns; schematics are anchored on their lowest occupied slice and
  turned. Rows above y 60 are left out (the patch is low). No P9G
  gathering sources in the patch (they are in the Plants row).
- **The swamp** is Round 47's patch (`patch.js`) as it is, plus today's
  `swamp_papyrus` row (1/50 at the water) as the pedestal of
  `papyrus_on_dirt.mts`, dirt turned to mud: the defect the plan names.
- **Drawing**: dry shrubs and grasses as plain X plants (no meshoptions);
  props turned by facedir move their side tiles and turn the top tile;
  water is a flat translucent top.

**The proposal** (`ITEMS` in `land.js`): each item has a stable key (shown
next to it), a toggle, a density slider where a density is at stake (× ¼ …
× 4 of a guide value set by eye: `den` columns per piece, or a share of the
ground), a verdict (pick, rework, drop) and a note. Texture items swap a
node's tiles on the proposal side; the rest place nodes after today's
content, in free cells: structures at seeded spots (expected count =
columns / den × multiplier, each spot tried once), plants per column,
lianas under jungle leaves with open air below (2–6 long, at least one node
above the ground). The skeleton set replaces the bone pile; the swamp's
own moss replaces the moss soil there; the clay bands take the faces of
steep badland columns by height (a 7-node cycle of four colours).
Lichen (rework after the user's first look, 2026-10-19) lies in small
patches: a patch centre in 1 of 450 columns, 2–5 carpets within 2 of it,
only on gravel and stone; the carpet is drawn with alpha clip (the ground
shows through). The undead got more variety at about the same density:
the kneeling mourner statue (ARTL pass 3; its bust or base alone now and then), fallen and sunken gravestones in the wild graveyards, ruin variants (a broken arch, a column stub, a sunken wall corner whose
lowest course is the ground's top, a crypt doorway over a sunken step
with rubble), fallen gravewood logs, gravewood stumps (a log with
gravewood's own branch or twig shape on top and a root base beside it),
earth grave mounds, and wild graveyards that differ per seed (2–6 stones,
2 or 3 apart, a mix leaning to steles or crosses, a fence on 0–2 sides).

| zone | keys |
| --- | --- |
| swamp | `swamp.ground.calm`, `swamp.ground.mud32`, `swamp.moss`, `moss.forest`, `swamp.hanging_moss`, `swamp.papyrus` |
| jungle | `jungle.ground.canopy32`, `jungle.liana`, `jungle.flower.ruby_fan`, `jungle.flower.ember_star`, `jungle.flower.violet_fan`, `jungle.fern`, `jungle.bush`, `jungle.log` |
| undead | `gravestone.fallen`, `gravestone.sunken`, `undead.ground.blight32`, `undead.ground.bone_litter32`, `undead.graveyard`, `undead.ruin`, `undead.ruin.arch`, `undead.ruin.column`, `undead.ruin.corner`, `undead.crypt`, `undead.log`, `undead.stump`, `undead.grave_mound`, `undead.statue`, `undead.obelisk`, `undead.bones`, `undead.town_graveyard`, `gravestone.slab`, `gravestone.cross`, `bones.skull_human`, `bones.skull_horned`, `bones.ribcage_human`, `bones.spine_animal`, `bones.scattered`, `bones.fragments` |
| dwarf | `dwarf.boulder`, `dwarf.lichen`, `dwarf.alpine`, `dwarf.cairn.blocks`, `dwarf.cairn.branches`, `dwarf.ice`, `dwarf.dead_pine` |
| orc | `orc.ground.mesa32`, `orc.bones`, `orc.withered_bush`, `orc.clay_bands`, the `bones.*` pieces |
| elves | `elves.ground.silver32`, `moss.forest`, `elves.ruin`, `elves.statue`, `elves.flower.blush_star`, `elves.flower.lilac_bells`, `elves.flower.cream_cups`, `elves.log` |
| savanna | `savanna.today` (a reference, ruling 15); `orc.ground.mesa32` shows on its clay too |
| beach | `beach.sand32` (above and under water, the pool bed), `beach.papyrus` (with today's pedestal to compare), `beach.marram`, `beach.driftwood`, `beach.pebbles` |

Art: ARTL's grounds, plants and props (passes 1 to 3); Astra's SWART
grounds and the calm proposals (`tools/r51_land/swamp`). No stand-ins
remain; `STANDIN_PROPS` stays for a prop still to come. The lichen
alternates `lichen_carpet_top` and `_b` by column.
Built from default nodes: ruins (cobble, mossy cobble, stone brick; silver
sandstone for the elves), boulders, the obelisk's plinth and shaft, the
plinths, the fallen logs, the town graveyard's flagstones, the fences. The
L13 variant B cairn is the tree concept's base, branch and twig node boxes
in stone. The dead pine is the concept pine without needles, broken off at
60 % of its height, with a snow layer on its wood.

**Notes** follow the orchestration brief's storage contract: the page
gets `claude.use("db")` after drawing everything, subscribes once to the
collection `notes`, one document per key (`{key, verdict, text,
updatedAt}`; characters a document id may not hold would become `~hex~`,
no key has one), writes on a verdict click or when a note field is left,
one write at a time per document and only on a change, deletes a note
with no text and no verdict, and says inline whether it was saved. Without
a db (opened from `file://`) the notes are read-only with one line saying
so; localStorage keeps only the zone and the mode. The "Note this density"
button adds the slider's density to the note text.
