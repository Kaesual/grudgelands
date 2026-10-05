# Farming and wild plant renewal

Decided 2026-09-20. The material and recipe catalog remains in
[items_crafting.md](items_crafting.md); these rules govern farming, renewable
wild plants and the water-only bucket. They supersede the former blanket
non-renewal wording for plants, but never authorize renewable natural minerals.

## Cultivation and tools

All seventeen shipped crop families retain their growth and hydration timings.
Cultivated crops and their seeds remain distinct from natural source nodes.
Seeds use recognizable seed silhouettes from licensed references, rather than
recolored harvest icons. Reusing an appropriate seed silhouette is allowed.

Every family has four logical stages at 200 seconds per advance. Growth runs
only above wet crop soil; drying pauses exact partial progress and rewetting
resumes it. Crop soil checks for water within three nodes every 15 seconds
while a growing crop stands on it and once a minute otherwise; planting and
regrowth return it to the 15-second check at once. Destructively harvesting stages 1–3 always returns exactly one seed
and no ingredient. Mature annual crops return one ingredient plus one seed and
must be replanted. Yield is deterministic and remains one ingredient.

| Class | Families | Mature harvest |
|---|---|---|
| annual low crop | Wild Grain, Carrot, Cassava, Wild Onion, Potato | remove and replant |
| regrowing bush/patch | Fire Pepper, Blightberry, Sunberry, Jungle Berry, Cave Cap, Ember Moss | pick one ingredient; rooted plant returns to stage 2 |
| regrowing ground fruit | Pumpkin, Frost Melon | pick one fruit; rooted vine returns to stage 2 |
| salt crust | Salt Crust | scrape one crust; basin returns to stage 1 |
| retained vertical | Sugar Cane, Bamboo Shoot | harvest upper growth; root returns to stage 1 |
| annual vertical | Corn | remove the whole mature stalk and replant |

Corn grows to three nodes at maturity. Sugar Cane reaches four nodes including
its root; Bamboo reaches three. The bottom node exclusively owns stage, timer,
metadata and drops. Upper nodes are hidden helpers. Digging any segment removes
the complete organism once, except the explicit mature upper harvest of Sugar
Cane or Bamboo, which preserves and resets the root. Every multi-node placement,
growth, dig and harvest preflights all changed loaded positions and protection;
a blocker or unloaded/protected position causes no partial mutation. The root
retries blocked growth through its ordinary bounded timer.

Right-click harvests a mature regrowing crop in place. Sneak-right-click bypasses
that crop action. Removing the rooted plant remains the explicit way to recover
its seed; mature removal also returns its one ingredient. Cultivated regrowth is
independent of the wild-plant renewal below; crops and farm soil never count as
wild habitat.

Wooden, Stone and six metal-tier hoes perform exactly the same conversion of
eligible earth to farm soil. Their use budgets are respectively
**30 / 60 / 300 / 600 / 1000 / 1500 / 2000 / 3000**. Only an actual new conversion spends
a use; failed interaction, already-tilled soil and Creative do not. Their grid
shape and material count follow pinned VoxeLibre. They have hoe art and keep
their stack at exhaustion, refusing further conversion until repaired under
[durability_repair.md](durability_repair.md). Higher material tiers buy lifetime,
not faster growth or different soil.

## Initial wild population

Halve the initial density of all harvestable wild food, Cooking and gathering
plant sources, including the older Potato and Corn sources. Double each source
candidate denominator and retain the existing geographic, biome, support,
shore, level and depth predicates. Do not relocate rejected initial candidates.
Grass, decorative flowers, ores, gems, Rock Salt and Salt Crust are excluded.

## Wild plant renewal

Decided 2026-09-28 (Round 23); replaces the Round 11 exact-baseline renewal.
Wild plants come back **from their habitat**, not from a record of where
plants stood: suitable ground, zone, biome, light, free space and altitude or
depth decide, so nothing can go extinct. There is no persistent renewal state,
no generation callback, no LBM and no ABM.

**Density authority.** The target at a spot is the natural density the world
generator produces there, read from the generator's own data through the
read-only authority `grug_mapgen` `wp40/vegetation_density.lua`
(`grug_mapgen.wp40.vegetation`):

- *Resource plants* (the renewable world content and P9G gathering rows) count
  **per species**, at `1 / initial_denominator` per eligible column (cave rows:
  per eligible cave-floor node), with each row's zone, biome, support, level or
  depth and shore predicates. Rock Salt and Salt Crust are minerals and never
  renew.
- *Ground cover* (grass, dry grass, ferns, junglegrass, dry shrubs) counts **as
  one total** at the sum of the biome's decoration rates
  ([biomes_mobs.md](biomes_mobs.md) §2.1), thinned per support exactly like the
  planner (gravel at a quarter); the zone's biome palette picks the species by
  its rates. Bone piles are not vegetation and do not renew.
- *Trees* and *shrubs* (bushes, the blueberry bush included) are two separate
  classes, each counted against its own density by its trunks or stems,
  divided by the marker columns one grown plant of that template has; planted
  saplings count as plants.
- Every decoration species' rate is multiplied by its altitude class factor
  at the spot, from the same vegetation rule the generator uses
  (`habitat_registry.lua` `vegetation_rule`, [world_zones.md](world_zones.md)
  §7.6): trees thin to zero at the tree line and follow the forest field
  (groves, clearings, ×1.5 in deep forest and deep jungle), shrubs rise to
  three times their density at the tree line and end 40 nodes above it
  (band-only bushes appear only there), ground cover ends at the snow line,
  and a spot whose column carries snow (cap or dust band) grows no
  decoration.

**Where.** Only near connected players, in loaded terrain, caves included:
spots lie 20–48 nodes horizontally from the sampling player and at least 20
nodes (3-D) from every player; unloaded nodes are skipped and nothing is caught
up for unvisited areas. A spot needs an open support the habitat accepts
(player-made ground of the same node counts) and, above the planned surface,
natural noon light 10 (13 for a sapling). Never on farm soil, capital hard
rows or ground whose territory rule refuses natural change
(`grug_core.natural_ground_alterable`: towns, landmarks, immutable ground).
Inside an active Claim Stone claim there is no natural renewal (wild plants,
trees); an expired claim renews like any other ground (Round 25 rulings 14
and 19, `housing.md` §6.4). Other
player protection is never consulted. Each class keeps its
own writer's claim exclusions: resource plants the full territory rule
(settlements, POIs with their collars, start and capital blend envelopes,
roads, inland water and water banks; shoreline species ignore the bank,
gathering sources the dry island coast envelopes), trees and shrubs the decoration rule (the planner's vegetation
exclusions and road corridors; banks allowed), ground cover the same rule with
the seeded share of a start's or capital's treeless band open (Round 36 W3;
the band itself is a town and never renews). Cave plants follow the
generator's own cave rule (`r6_settlement.lua` `r30_cave_limit`): they stay
out of occupied ground and of planned-water and coast shapes, and below a
town's or POI's protected floor (placement height − 100, Round 24 ruling
30) the cave is ordinary ground. A surface resource plant on
ground below such a floor ignores the envelope's claim exclusion, as the
writers do. At the planned surface renewal follows the generator's own
host rule: nothing on an anchor platform, on a land grade other than a
start's or capital's dry anchor grade, on a sealed river or lake column or in
a surface cave mouth; the dry anchor grades (the natural skin around starts
and capitals) regrow grass and trees at their biome's density, but no
resource plants.

**How much.** Around the spot, the renewal counts present plants of the chosen
species or class and the eligible open supports in a box whose radius makes
the natural count about 1.5 plants (radius 4–24, ±4 nodes high; woody trunks
4 below to 12 above). Target = eligible supports × density, rounded to an
integer by a fixed per-patch fraction. At or above the target nothing is
placed; below it the chance is the class chance × (target − present) / target.
Shoreline species count at most two eligible supports per box width.

**Trees.** Trees and bushes renew as saplings of the species the biome
naturally grows (setting `grug_tree_regrowth`, default on), which then grow
through the vendored sapling timers. No sapling is placed within 10 nodes of
any non-natural node, farm soil or unloaded terrain. Natural nodes are air,
liquids, generated ground and ores (`grug_natural`), the tree, leaf, sapling,
flora and fruit families and every node the generator places as vegetation.
The snowy crags pine and the crags pine bush (gravel), the fallen apple log, the badlands cactus
(mesa clay) and swamp papyrus have no renewal path.

**Rates** (first version by feel, tuned in playtest; constants in
`grug_farming/renewal.lua`): each player is serviced once per 5 seconds with
4 sampled spots; class chance at a full deficit 0.05 for resource plants, 0.5
for ground cover and 0.1 for tree and shrub saplings. Area queries are capped at 150 000 node
visits per player and step, independent of world size.

**Apples and blueberries** are not renewal plants: a picked natural apple
(`param2 = 0`) and picked blueberry leaves regrow through the vendored
`default` node timers. Ores and other minerals retain [world.md](world.md) R4.

## Water bucket

One empty Iron Bucket and one filled Water Bucket, both stack size one. The
Basics recipe is three `grug_materials:iron_bar` in the pinned VoxeLibre V
layout. There is no profession, character-level or Housing prerequisite.

Fill only from actual ordinary or river water sources. Preserve that family in
filled-stack metadata and place the same source family again. Invalid/missing
metadata, flowing water, lava and protected decorative water are refused.
Check reach and the player's protection at the node removed/placed. Exchange
empty and filled stacks only when the node mutation succeeds; full inventory or
failed mutation cannot consume or duplicate either water or the bucket.

## Water protection prerequisite

The bucket requires a narrow shared water-flow guard. At protected authored and
claimed positions, veto non-air flooding before destruction/drops, preserving
the original node callback elsewhere. For air and liquid transformations,
restore the exact old node including param2 through the engine's liquid change
callback. Never remove an allowed outside source to suppress retries.
The world's own planned water is exempt where it flows by design: above a wet
planned inland column and no higher than the highest planned surface among its
four neighbours (the rapid or fall at a step between two planned surfaces,
[world_zones.md](world_zones.md) §7.4), so steps inside protected territory
flow like any other.

Use the existing engine scheduler: repeated boundary callbacks are allowed.
Bound work per transformed node and any cache storage per loaded boundary;
there is no new polling/retry queue or unbounded per-attempt allocation.
This is the water slice of WP46, not fire, explosions, a custom fluid simulation,
an engine fork, Housing or an administrative reconstruction feature.
