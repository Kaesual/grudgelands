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

The wooden hoe and six metal-tier hoes perform exactly the same conversion of
eligible earth to farm soil. Their use budgets are respectively
**64 / 128 / 192 / 256 / 384 / 512 / 768**. Only an actual new conversion spends
a use; failed interaction, already-tilled soil and Creative do not. Their grid
shape and material count follow pinned VoxeLibre. They have hoe art and keep
their stack at exhaustion, refusing further conversion until repaired under
[durability_repair.md](durability_repair.md). Higher quality buys lifetime,
not faster growth or different soil.

## Initial wild population

Halve the initial density of all harvestable wild food, Cooking and gathering
plant sources, including the older Potato and Corn sources. Double each source
candidate denominator and retain the existing geographic, biome, support,
shore, level and depth predicates. Do not relocate rejected initial candidates.
Grass, decorative flowers, ores, gems, Rock Salt and Salt Crust are excluded.

## Bounded renewal

Natural plants may renew only to replace observed natural depletion; cultivated
or player-placed nodes never create renewal debt. Use **64×64 horizontal habitat
cells**, keyed by species. Record the generated/observed natural baseline and
source identities: a partially loaded or naturally sparse cell is never empty
by inference and is never topped up to a statistical expectation.

The first replacement opportunity is uniformly **4–8 real hours** after
depletion. A failed attempt backs off **30–60 minutes**. One successful placement
consumes one debt; debt cannot exceed the recorded baseline. Persist and
coalesce debt and due time per species/cell. Observe digging, destruction and
replacement, and reconcile other disappearance lazily against the recorded
natural positions on loaded terrain. Never scan an entire habitat cell to
discover a deficit.

One globally throttled **10-second** pass services at most **8 cells**, inspects
at most **64 candidate positions**, and places at most **2 plants**. Node reads
have a separate fixed global bound recorded by the implementation, including
support and shore neighbors. Deduplicate player-visible cells; these are global
budgets even with 100 players. No forced emergence, world scan, per-plant ABM or
per-missing-node timer. Candidates or required neighbors in unloaded mapblocks
defer without loading them.

Each service rotates through at most eight candidates. Reuse one authoritative
habitat catalog and zone API for mapgen and renewal. Require natural unmodified
support, air/clearance and the original family habitat/depth/shore predicates.
Never replace existing nodes or place on player farmland, modified support,
routes, authored surfaces, protected content or reserved/active claims.
The actor-neutral `grug_core.world_alterable(pos)` is the shared permission seam;
an empty player name passed to player protection is not a system permission.
Ores and other minerals retain [world.md](world.md) R4.

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

Use the existing engine scheduler: repeated boundary callbacks are allowed.
Bound work per transformed node and any cache storage per loaded boundary;
there is no new polling/retry queue or unbounded per-attempt allocation.
This is the water slice of WP46, not fire, explosions, a custom fluid simulation,
an engine fork, Housing or an administrative reconstruction feature.
