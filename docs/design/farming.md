# Farming and wild plant renewal

Decided 2026-09-20. This file owns farming and its Basic recipes (hoes,
bucket, seeds, the salt pan), the light rule for plants, renewable wild plants
and the water-only bucket; the food and material catalog remains in
[items_crafting.md](items_crafting.md) §3.7. These rules supersede the former
blanket non-renewal wording for plants, but never authorize renewable natural
minerals in the wild, with one deliberate exception: the two salts, Rock Salt
and Salt Crust, regrow in the wild (Round 48, [world.md](world.md) R4).

## Cultivation and tools

Eighteen crop families (Round 48: Melon and Mushroom joined, Salt Crust left
for the salt pan below) retain their growth and hydration timings.
Cultivated crops and their seeds remain distinct from natural source nodes.
Seeds use recognizable seed silhouettes from licensed references, rather than
recolored harvest icons. Reusing an appropriate seed silhouette is allowed.
**Seeds:** any player crafts one harvest item of a family into two of its
seeds (a Basic recipe, every family). Only cultivated plants drop seeds: wild
sources drop their harvest item only. The seeds of the three light-exempt
families (Cave Cap, Mushroom, Ember Moss) are called **Spores**. Spices and
healing herbs stay gather-only (Sunleaf, Marshbloom, Stormkelp, Gravemoss,
Dragonweed, Crimson Lotus); Ember Moss is both a healing herb in the wild and
a crop. Ground cover (grass, ferns, reeds, cattails, moss carpet and the like)
drops itself for decoration and has no seeds and no propagation.

Every family has four logical stages at 200 seconds per advance. Growth runs
only above wet crop soil; drying pauses exact partial progress and rewetting
resumes it. Crop soil checks for water within three nodes every 15 seconds
while a growing crop stands on it and once a minute otherwise; planting and
regrowth return it to the 15-second check at once.

**Light** (Round 48). A growing crop also needs **plant light 8**, the level at
which no monster spawns: daylight or torchlight, measured as at noon (the
larger of noon daylight and artificial light at the crop), so outdoor crops
keep growing at night and a torchlit field grows indoors. Darkness pauses a
crop exactly like dryness: its progress is kept, none accrues, and the soil's
15-second check resumes it when light returns (one light read per growing crop
per check). Fungi and cave plants need no light: **Cave Cap, Mushroom and
Ember Moss** grow in the dark. The same light rule and value
(`default.PLANT_LIGHT`) serve papyrus and cactus below.

Destructively harvesting stages 1–3 always returns exactly one seed
and no ingredient. Mature annual crops return one ingredient plus one seed and
must be replanted. Yield is deterministic and remains one ingredient.

| Class | Families | Mature harvest |
|---|---|---|
| annual low crop | Wild Grain, Carrot, Cassava, Wild Onion, Potato | remove and replant |
| regrowing bush/patch | Fire Pepper, Blightberry, Sunberry, Jungle Berry, Cave Cap, Mushroom, Ember Moss | pick one ingredient; rooted plant returns to stage 2 |
| regrowing ground fruit | Pumpkin, Frost Melon, Melon | pick one fruit; rooted vine returns to stage 2 |
| retained vertical | Sugar Cane, Bamboo Shoot | harvest upper growth; root returns to stage 1 |
| annual vertical | Corn | remove the whole mature stalk and replant |

Corn grows to three nodes at maturity. Sugar Cane reaches four nodes including
its root; Bamboo reaches three. The bottom node exclusively owns stage, timer,
metadata and drops. Upper nodes are hidden helpers. Digging any segment removes
the complete organism once, Sugar Cane and Bamboo included. The
root-preserving harvest of a mature Sugar Cane or Bamboo is the right-click
harvest below: it takes the upper growth and resets the root. A root that goes
any other way (its soil dug away, a block placed on it, a flood) takes its
upper nodes with it; an upper node left without its root can still be dug and
drops nothing. Every multi-node placement,
growth, dig and harvest preflights all changed loaded positions and protection;
a blocker or unloaded/protected position causes no partial mutation. The root
retries blocked growth through its ordinary bounded timer.

Right-click harvests a mature regrowing crop in place, also with seeds, a bucket
or the fishing rod in hand (their own use runs only on nodes without a
right-click action). Sneak-right-click bypasses that crop action. Removing the rooted plant remains the explicit way to recover
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

## Papyrus, cactus and saplings

Round 48. **Papyrus** grows on any soil (every dirt, litter, mud and farm soil
node) or sand with water within 3 nodes; **cactus** on sand or mesa clay (the
badlands ground). Both need plant light 8 measured as at noon, as crops do, so
both grow indoors by torchlight, and both grow to four pieces at their
upstream pace (papyrus every 14 s at 1/71, cactus every 12 s at 1/83). They
regrow from their bottom piece: digging a piece takes every piece above it
(papyrus as upstream, cactus since Round 48), so leaving the bottom piece keeps
the plant. Neither grows where the terrain guard refuses
(`grug_core.world_alterable`: towns, capitals, landmarks), so the reed rows of
a capital's fields stay as built. A rotated cactus piece (`param2` ≥ 4) never
grows; the generated badlands cacti stand on trunks taller than four pieces and
so stay as generated, while wild shore papyrus grows to its cap of four. The
Large Cactus Seedling follows the cactus ground and light.

**Saplings** (trees and bushes) grow only by daylight: natural light 13
measured as at noon. Torches never help a sapling; a glass roof lets the sun
through. Picked apples and blueberries keep their vendored regrowth (light 11
from any source).

## The salt pan

Round 48: salt is no plant. A crafted **Salt Pan** (Basic recipe: 3 Embersteel
Bars, 1 filled Water Bucket, which is used up, and 1 Salt Crust) is placed on
the top face of any solid, walkable ground that is no liquid, with the usual
protection check. With water within 3 nodes it collects Salt Crust through
four fill stages of 200 seconds each, needs no light, and keeps its progress
while the water is gone. Right-click on a full pan scrapes one Salt Crust and
empties it to stage 1; digging returns the pan, a full one also its crust. It
wears the wild salt basin's look. The pan makes Salt Crust only; Rock Salt
stays gather-only.

## Tooltips

Every plant item and harvest carries one line that says how it grows or where
it comes from (`grug_farming/tooltips.lua`, one pass after the other
description writers): a crop's harvest item and its seeds or spores (light or
"even in the dark"), papyrus, cactus, saplings, Salt Crust, the Salt Pan, the
gather-only spices and foods ("Found in the wild only") and the alchemists'
healing herbs.

## Initial wild population

Halve the initial density of all harvestable wild food, Cooking and gathering
plant sources, including the older Potato and Corn sources. Double each source
candidate denominator and retain the existing geographic, biome, support,
shore, level and depth predicates. Do not relocate rejected initial candidates.
Grass, decorative flowers, ores and gems are excluded. Rock Salt and Salt
Crust keep their full initial density (Round 48: they renew, but the world
generates them as before).

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
  depth and shore predicates. Rock Salt (the three coast zones and their
  shore rule) and Salt Crust (mesa clay in The Shattered Line) renew too, at
  their full initial density (Round 48, the deliberate exception to
  [world.md](world.md) R4).
- *Ground cover* (grass, dry grass, ferns, junglegrass, dry shrubs) counts **as
  one total** at the sum of the biome's decoration rates
  ([biomes_mobs.md](biomes_mobs.md) §2.1), thinned per support exactly like the
  planner (gravel at a quarter); the zone's biome palette picks the species by
  its rates. The land kit's structures (bone finds, graveyards, ruins,
  boulders, cairns, fallen logs, driftwood; [biomes_mobs.md](biomes_mobs.md)
  §2.1) are not vegetation and do not renew.
- *Trees* and *shrubs* (bushes, the blueberry bush included) are two separate
  classes, each counted against its own density by its trunks or stems,
  divided by the marker columns one grown plant of that template has; planted
  saplings count as plants. A generated tree (Round 47) is counted by its
  trunk logs and trunk quarters, divided by the mean trunk columns of the
  world's variants of its species.
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
rows or where `grug_core.natural_renewal_allowed` refuses: ground whose
territory rule refuses natural change (`grug_core.natural_ground_alterable`:
towns, landmarks, immutable ground) or a natural renewal guard. The one guard
is the Claim Stone's: inside an active claim there is no natural renewal (wild
plants, trees); an expired claim renews like any other ground (Round 25 rulings 14
and 19, `housing.md` §6.4). Other
player protection is never consulted. Each class keeps its
own writer's claim exclusions: resource plants the "gathering" rule (the
static shapes as trees see them — start towns, capitals, a POI's core and
margin, planned water and coasts, but no anchor blend envelope — plus roads,
inland water and water banks; shoreline species ignore the bank, gathering
sources the dry island coast envelopes; user ruling 2026-10-07: the
envelopes round villages, camps and POIs grow their gatherables like open
land), trees and shrubs the decoration rule (the planner's vegetation
exclusions and road corridors; banks allowed), ground cover the same rule with
the seeded share of a start's or capital's treeless band open (Round 36 W3;
the band itself is a town and never renews). Cave plants follow the cave
rule `r6_settlement.lua` `r30_cave_limit` (the generator's own until Round
49; the generator now places them natively everywhere, mapgen plan answer
3): they stay
out of occupied ground and of planned-water and coast shapes, and below a
town's or POI's protected floor (placement height − 80, Round 24 ruling
30) the cave is ordinary ground. A surface resource plant on
ground below such a floor ignores the envelope's claim exclusion, as the
writers do. At the planned surface renewal follows the generator's own
host rule: nothing on an anchor platform, on a land grade other than a
start's or capital's dry anchor grade, on a sealed river or lake column or in
a surface cave mouth; the dry anchor grades (the natural skin around starts
and capitals) regrow grass, trees and resource plants at their biome's
density (resource plants since the user ruling of 2026-10-07).

**How much.** Around the spot, the renewal counts present plants of the chosen
species or class and the eligible open supports in a box whose radius makes
the natural count about 1.5 plants (radius 4–24, ±4 nodes high; woody trunks
4 below to 12 above). Target = eligible supports × density, rounded to an
integer by a fixed per-patch fraction. At or above the target nothing is
placed; below it the chance is the class chance × (target − present) / target.
Shoreline species count at most two eligible supports per box width.
Round 51: the shore papyrus counts as a shoreline species and by columns (a
stack of 2–4 is one plant); the lichen counts at most one patch (25 columns)
of supports, since it grows only inside its patches.

**The Round 51 land plants** (lane LP) are ground cover and renew like the
grass: the jungle's ferns and strong flowers, the elves' pastel flowers, the
crags' and pine hills' alpine plants and lichen, the warm shores' papyrus
(one stalk at the water's edge, which then grows to four) and the marram on
dry sand, each at its row's density on its row's hosts, at the sites its row
asks (papyrus beside the water, marram away from it, lichen in its patches).
The jungle's large-leaved bush and the badlands' withered bush have no
renewal path (no sapling grows their foliage), and the lianas come back only
with their tree.

**Trees.** Trees and bushes renew as saplings of the species the biome
naturally grows (setting `grug_tree_regrowth`, default on), which then grow
through the vendored sapling timers into the generator's trees (Round 47,
[biomes_mobs.md](biomes_mobs.md) §5). No sapling is placed within 10 nodes of
any non-natural node, farm soil or unloaded terrain. Natural nodes are air,
liquids, generated ground and ores (`grug_natural`), the tree, leaf, sapling,
flora and fruit families and every node the generator places as vegetation.
The snowy crags pine and the crags pine bush (gravel), the fallen apple log, the badlands cactus
(it grows from its own stands, above) and the two Round 51 bushes have no
renewal path.

**Rates** (first version by feel, tuned in playtest; constants in
`grug_farming/renewal.lua`): each player is serviced once per 5 seconds with
4 sampled spots; class chance at a full deficit 0.05 for resource plants, 0.5
for ground cover and 0.1 for tree and shrub saplings. Area queries are capped at 150 000 node
visits per player and step, independent of world size.

**Apples and blueberries** are not renewal plants: a picked natural apple
(`param2 = 0`) and picked blueberry leaves regrow through the vendored
`default` node timers. Ores and other minerals retain [world.md](world.md) R4
(the two salts excepted).

## Water bucket

One empty Iron Bucket and one filled Water Bucket, both stack size one. The
Basic recipe is three `grug_materials:iron_bar` (the pinned VoxeLibre V
layout until Round 45). There is no profession, character-level or Housing prerequisite.

Fill only from actual ordinary or river water sources and place the same
source family again. A bucket of ordinary water carries no metadata (Round 48:
so it counts as a recipe ingredient, the salt pan's); river water keeps its
family in the stack's metadata and reads "River Water Bucket". Invalid
metadata, flowing water, lava and protected decorative water are refused, and
a filled bucket never replaces an existing liquid. Check reach and the
player's protection at the node removed/placed; both filling and placing are
also refused wherever `grug_core.world_alterable` is false (ground whose
territory rule refuses natural change — towns, landmarks, the open sea and
other immutable ground — and a Claim Stone's arrival cube). Exchange
empty and filled stacks only when the node mutation succeeds; full inventory or
failed mutation cannot consume or duplicate either water or the bucket.

## Water protection prerequisite

The bucket requires a narrow shared water-flow guard. Where
`grug_core.world_alterable` is false (protected authored ground and Claim
Stone arrival cubes; a claim itself lets water flow), veto non-air flooding
before destruction/drops, preserving
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
