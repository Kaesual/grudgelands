# Round 10 — world content and farming integration

Status: production checkpoint `2bc6f33c`, independent review in progress. This is
not package acceptance. The bounded engine/current-save addendum and root's final
integrated PUC-5.1/LuaJIT pair remain gates. No intermediate PUC runtime was run.

## Authority and scope

The accepted rules are [world_zones.md](../design/world_zones.md#round-10-cooking-wild-sources-field-soil-and-shallow-reefs)
and [items_crafting.md](../design/items_crafting.md). The implementation preserves
WORLD's cave-purpose boundary, current demand-driven resource sampler, capital
geometry and existing protection. Farming remains usable on legal editable ground;
protected civic fields are scenery, not a permission bypass or housing prerequisite.
Berries follow the decided home-zone level 11–20 rule over earlier preflight prose.
The old found-only interpretation of Cave Cap and Ember Moss is superseded: FARM
owns all seventeen complete families, including those two and potato/corn.

## Closed acquisition table

Every row uses `grug_cooking:<key>` as its ingredient and
`grug_mapgen:<key>_source` as its independently harvestable wild node. The exact
closed zone IDs and final support node names are in
[`world_content_catalog.lua`](../../mods/MAPGEN/grug_mapgen/wp40/world_content_catalog.lua).
Surface numbers are mob-level bands; cave numbers are Y coordinates.

| Key | Zone / biome restriction | Band | Final support / shore |
| --- | --- | --- | --- |
| wild_grain | Six starts and six homes | 4–20 | Accepted meadow/pine/elf/savanna/blight/jungle soils |
| carrot | Three Accord starts | 1–6 | Meadow/pine/elf soils |
| cassava | Three Throng starts | 1–6 | Savanna/blight/jungle soils |
| wild_onion | Accord starts and homes | 1–20 | Pine/elf/deep-forest soils |
| fire_pepper | Throng starts and homes | 1–20 | Savanna/blight/jungle/badlands soils |
| pumpkin | Six homes | 11–20 | Meadow/swamp/blight soils |
| blightberry | Mournfen | 11–20 | Blight soils |
| sunberry | Redtusk Savanna | 11–20 | Savanna soils |
| jungle_berry | Raincall Basin | 11–20 | Jungle-edge soils |
| frost_melon | Frostbarrow / Whitebridge | 21–30 | Crags gravel or swamp mud; freshwater shore |
| sugar_cane | Any land zone | 1–60 | Actual sand; fresh or sea shore |
| bamboo_shoot | Jungle edge / deep jungle / swamp | 1–60 | Actual sand or mud; fresh or sea shore |
| salt_crust | Shattered Line | 44–50 | Mesa clay |
| cave_cap | Actual native cave air | −500…−100 | Stone / granite / slate / basalt |
| ember_moss | Actual native cave air | ≤−701 | Emberrock |

The existing Mushroom/Speargrass and Stormkelp/Shattered Line additions are swamp
mud only. Their other prior closed sources remain preserved. Ember Moss delegates
to the existing Alchemy harvest authorizer at group 5; Cave Cap is universal food.
Salt Crust and Rock Salt remain separate identities. Common surface density is
1/256, spices/salt 1/512, Cave Cap 1/768 and Ember Moss 1/1024 eligible coordinates;
these are deterministic hash thresholds, not guaranteed regional supply quotas.

## Production seams

[`world_content.lua`](../../mods/MAPGEN/grug_mapgen/wp40/world_content.lua) runs
inside the existing private R6 VM transaction, after old P9G and before anchor /
settlement successors. Placement consumes actual settled content IDs, occupation,
owned bounds, protection and native-air preservation. Cave support across an
uncommitted owner boundary is rejected. Surface roots may use the existing
analytical accepted-P7 support seam for below-owner support. No second writer,
engine decoration population, resource reranking or geometry expansion was added.

Shallow sea beds two through ten nodes below water use the 16-node cell and
column hashes. Six existing coral nodes and native sand-with-kelp retain their
real registration and param2 semantics; kelp requires sand and height×16 param2.
Freshwater, wrong support, non-source water, exclusions and owner-edge stems are
rejected. Ash and moss add existing-asset secondary soils without restoring sand
on mountains. Their provenance remains in
[grug_nodes/LICENSE-media.md](../../mods/ITEMS/grug_nodes/LICENSE-media.md).

The synchronous world-authority constructor cannot depend on FARM because FARM
already reaches mapgen through Jobs/Cooking/Mobs. Complete soil registrations and
a pure fresh-table crop visual builder therefore live in lower-layer `grug_nodes`.
FARM binds the real soil callbacks once before engine callbacks run; missing
binding fails loudly. FARM still owns its sole seventeen-row crop roster, timers,
seed conversion, progression/protection and every-load idempotent activation LBM.
No delayed world constructor, duplicate registration, compatibility placeholder
or migration was added. All 68 stage visual definitions retain their ART bindings.
Wild nodes share visual construction but never copy crop timers or growing groups.

## Verification matrix

| Requirement / production module | Actual consumer evidence |
| --- | --- |
| Early soil + shared visuals + FARM lifecycle | `registration_fixture.lua` invokes real FARM fixture; `farming_completion_kat.lua` proves 17 loops, dry pause/resume, VM activation/reload and vertical protection |
| Wild definitions + real harvest callback | Registration fixture compares 15 mature/wild definitions and 68 stages; actual Ember callback refuses absent/unlearned authority and accepts authorized Alchemy |
| All fifteen plant bands / supports / zones | `placement_fixture.lua`, with real registered content and resolver from `content_fixture.lua` |
| Cave output / purpose guards / private writes | `writer_fixture.lua`: actual writer Cave Cap13 and Ember Moss6, native/final-air and functional/foundation negatives, replay and conditional setters |
| Seven reefs / kelp / sea-vs-lake | Placement fixture: real CID/param2 resolver and actual production tail, support/depth/liquid/exclusion negatives |
| Projection / manifest / planner integration | Root shared R7 micro: actual strict constructor, writer and planner, source audit157; dedicated content coverage owns added modules |
| MTS identity | `template_refs.lua`: 21 files / 84 rotations; 692 shifted indices normalize exactly to prior decoded graph |
| Dependency load ordering | `dependencies.py` plus actual complete-game engine boot |
| Existing regressions | FARM/ART, R6 micro, R8 rules/writer and WP13 library/blueprint/seam/integration, LuaJIT only |

The first broad regression retained three failures. Two were obsolete WP13 soil
oracles and now pass with real FARM activation evidence. The R6 synthetic fixture
omitted the required stone host and used all-air fake terrain that triggered
unrelated pre-existing surface-skin repairs. Exact baseline `4491c996` reproduces
its ignore/light failure after the same host correction. The corrected context
provides native stone below the analytical surface and retains the original
ignore-rejection and byte-equal/no-light assertions. Failures are retained, not
counted as passes. The full corrected regression log follows in the addendum.

## Canonical binding and cost

The accepted registry is 84 entries, production content90, P9G34 and natural
ground25. Writer reference windows are91–124 /125–126 /127+. Anchor ledger offsets
come from the authoritative current content count; no literal100 remains there.
The strict mechanical pin report and bound inputs are under
[`tools/r10_map_b/evidence/source-checkpoint`](../../tools/r10_map_b/evidence/source-checkpoint).
The new soil names shift sorted decoded-template content references only; MTS
bytes and geometry are unchanged. The frozen historical source roster157 is not
expanded or falsely treated as coverage of new files.

Cave Y loops run only when the owned slice intersects a plant depth interval;
shallow/surface slices skip them. Eligible hashes precede native-air/support work.
At world bounds the linear mixed hash is below 2^36 and the second multiply below
2^40, safely within exact-double integer range2^53. No per-voxel SHA or global RNG
was introduced. `evidence_fixture` suppresses cave candidates because that
analytical projection has no native cave-air input; this is a diagnostic coverage
limit, not a gameplay switch. Actual private-writer and live cave witnesses cover
the production branch. No new performance or census fleet was run.

## Runtime playtest after root integration

Use a fresh world. Find and harvest wild Cooking plants in the listed regions;
check Cave Cap and Ember Moss underground, Alchemy gating, coastal corals/kelp,
and ash/moss patches. On legal unprotected ground convert ingredients to seeds,
hoe ground, add water, grow and replant; dry soil must pause growth and current-save
reload must resume normally. Civic protection must still refuse player edits.

The [acceptance addendum](../../tools/r10_map_b/evidence/acceptance-addendum)
records all thirteen corrected LuaJIT regressions passing and bounded engine
positives. Dawnmere's 3267 real VM-written soils include a 28-soil held sample;
with a clearly labeled scratch-only water stimulus, 12 hydrate and 16 remain dry,
all with active timers. Native cave samples contain Cave Cap1 and Ember Moss2;
the sea sample contains four coral variants. These sampled counts are not an
all-plant census. A final reload of the wet/dry state and focused review follow.
