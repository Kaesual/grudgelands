# WP40 R8 Seed and Visual Preflight

Status: prepared from accepted R6/R7 evidence; no Luanti world, build, long
run, or new gate was executed for this note. The companion candidate and route
tables are `tools/wp40/r8/seed-candidates.tsv` and
`tools/wp40/r8/visual-itinerary.tsv`.

## Result and limit of the evidence

Three reproducible seeds are proposed as GUI candidates:

1. `0` (`C1_preview`), the documented preview seed in
   `docs/research/wp40-simple-map-preview.svg:6491` and
   `docs/research/wp40-simple-map-rebase-plan.md:202`, with corpus slot 1
   at `docs/research/wp40-simple-map-r6-seed-corpus.tsv:2` and R7 seed row
   at `docs/research/wp40-r7-artifact.tsv:5`.
2. `1` (`C2_pilot`), the seed-one R6 pilot/targeted-reference identity
   recorded at `docs/research/wp40-simple-map-r6-review.md:52-55`, corpus
   slot 2 at `docs/research/wp40-simple-map-r6-seed-corpus.tsv:3`, and R7
   seed row at `docs/research/wp40-r7-artifact.tsv:6`.
3. `42` (`C3_literal_42`), corpus slot 4 at
   `docs/research/wp40-simple-map-r6-seed-corpus.tsv:5` and R7 seed row at
   `docs/research/wp40-r7-artifact.tsv:8`.

This is a provenance shortlist, not a visual ranking. The accepted artifacts
prove deterministic construction and bounded sampled behavior, but they do
not contain in-game screenshots, a visual-quality score, real Luanti timing,
or a metric for beauty, readability, lighting, cave atmosphere, or player
comfort. The three rows therefore remain equal visual candidates until the
user's fresh-world inspection. The R7 seed-evidence byte sizes are recorded
for traceability only; they are not a quality score.

## What is fixed and what can vary

The source is `schema=grug_wp40_simple_map_source_v2`, layout
`wp40-simple-map-v1d` with revision `wp40-simple-map-v1e`
(`mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:16-27`). Its accepted
horizontal identities are common to all three candidates: 38 named zones, 57
land routes, four boat routes, 100 anchor positions, ten housing masks and 24
apex sockets. Start/capital positions, route centrelines, channels, island
polygons and housing geometry are consequently not a reason to prefer one
seed over another.

The seed-dependent part begins with the project-owned height field `H`, local
logical-biome choice, native v7 cave/ore/dungeon/stratum substrate, resources,
cultural/decorative candidates and their settlement. This fixed/varying split
is the accepted R6 contract and review boundary; R7 explicitly warns that its
32-seed stratified sample is not exhaustive spatial, visual, performance or
real-world evidence. The accepted R7 sample has 32 seeds, 128 owners per seed
and 795,281 sampled columns per seed; its separate frontier lane has seven
seeds and is not pooled with the main sample.

`seed-candidates.tsv` preserves the exact R6 corpus slot, R7 seed evidence
digest and mocked-engine manifest provenance for each candidate. The latter is
not an expected real-engine content-ID manifest. R6 review additionally
records seed one as the
accepted pilot and targeted reference. The R8 plan explicitly names seed `0`
as the SVG's documented preview seed. These statements establish provenance;
they do not predict what the first GUI world will look like.

## GUI inspection route

The route table contains 14 ordered checkpoints and deliberately combines
paired observations where doing so keeps the pass compact. It covers both
faction-side starts and capitals, ordinary inland terrain, the faction/front
boundary, the Battlegrounds, road and hydrology crossings, lake, coast/shelf/
deep ocean, both immutable dragon channels, both island endpoints, a housing
mask, and deep strata/cave/dungeon/resource witnesses.

The source coordinates are exact x/z values. A row with multiple coordinate
pairs is a paired comparison, not an implied continuous walking path. Surface
y is intentionally left to `terrain_height_at`; the two deep witnesses retain
their exact R6 y values (`-834` and `-842`). Dragon-island rows use the fixed
hub, dragon and apex-mine anchor coordinates, while the channel rows use the
centres of the closed source channel polygons. These are inspection points,
not claims that a static source file alone proves the final rendered block at
every point.

### Machine-checkable observations

Where the current production API exposes the query, record the result for
`id_at`, `territory_rule_at`, `pvp_rule_at`, `terrain_height_at`,
`water_class_at`, `biome_at`, `surface_mob_level_at`, `nearest_route_at`,
`nearest_hydrology_at`, `anchor`, `housing_eligible_at`, and
`grug_materials.tier_at`. Also check fixed
anchor/socket identity, route class/corridor and boat landing identity, water
precedence, the 101 by 101 housing footprint, and deep full-column channel
protection. These checks are assertions against accepted source/API contracts;
they do not require a new seed fleet.

For the deep witness row, the two exact x/y/z records are
`docs/research/wp40-simple-map-r6-artifact.tsv:14-15`. The automatable API checks can establish zone,
territory and depth tier. They cannot establish that a cave, dungeon, ore or
stratum is present at an arbitrary sampled coordinate. The real world must be
inspected for native v7 preservation, lighting/liquids and operation order, as
required by R8.

### User-judgement observations

The user should judge start/capital legibility, silhouette and relief, biome
patch coherence, route readability, alternate crossings, coast-to-ocean
gradient, channel/island drama, island landing choice, housing plausibility,
and cave/dungeon atmosphere. Note performance and generation feel separately;
neither is represented by the offline R6/R7 artifact hashes.

## Rollout assumptions and blockers

- The first world must be a fresh v7 world. The accepted R7 review explicitly
  says that no old WP18/WP36 world is a migration target.
- The R7 writer is the single production authority and the cultural/P9G
  registrations are already part of its accepted cutover. No second writer or
  repair pass should be introduced during the visual pass.
- This preflight did not run Luanti, Flatpak, a seed fleet, a build, or a new
  validation gate, by design.
- The only blocker to calling one candidate a winner is missing visual and
  real-runtime evidence. If all three GUI passes are acceptable, selection is
  a product choice; if one is visually preferable, record that judgement and
  the inspected seed rather than retroactively treating the offline hashes as
  a ranking metric.
