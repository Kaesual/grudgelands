# WP33 Gathering and Cultural Surface Resources Preflight

Status: historical implementation preflight; superseded by the ratified
2026-08-31 contract in `wp33-gathering-contract-candidate.md`
Date: 2026-08-31 (Europe/Berlin)
Base: `d6002a289aa079fba4fe1d943a00dc50f777f30a`

## 1. Outcome

WP33 is not yet implementation-ready as one undivided package. The accepted
R6 cultural seam is sufficient for the six culture-bound source features, and
the safest exact registrations are already represented by R6's synthetic test
shape: one simple source node at relative `(0, 1, 0)`, a one-cell footprint,
and `lower_two_policy = "preserve_p7"`
(`tools/wp40/r6/fixtures.lua:425-439`). That choice needs no schematic, never
touches the P7 top/filler cells, cannot exceed the 5 by 5 by 9 reservation and
does not reopen terrain semantics.

The blocker is the other half of WP33. R6 deliberately freezes exactly 48
surface decorations and declares herbs, spices, foods and all other gathering
nodes absent rather than zero-density entries
(`docs/research/wp40-simple-map-r6-contract.md:664-681`). R6 exposes a closed
six-key cultural validator only (`mods/MAPGEN/grug_mapgen/wp40/r6.lua:24-27,
116-220`); it has no candidate or settlement seam for biome/zone-driven
healing herbs, spices or foods. R7 nevertheless has to migrate gathering while
enabling one consolidated writer
(`docs/research/wp40-simple-map-rebase-plan.md:970-986`). A reviewed successor
contract must therefore close that missing same-transaction integration before
WP33 implementation or R7 activation.

Recommendation: keep R6's six cultural registrations unchanged and add a
closed WP33 gathering catalog consumed by a strictly later R7 `P9G`
successor tail after accepted R6 P9, inside the same retained buffers and the
same single VM commit. P9G must not overwrite or alter any accepted P2-P9
intent. It may settle only an otherwise unoccupied, valid dry surface cell and
must reject
without retry or fallback. This preserves the accepted R6 candidate,
reservation, resource and decoration outputs while giving herbs/spices/foods
their different zone, tier and access rules.

## 2. Binding scope and current inventory

The BACKLOG acceptance row requires six herb/spice nodes, cooking ingredients,
found-only foods, signature woods and culture materials, plus exact six R6
registrations before R7 (`BACKLOG.md:56`). The design closes these content
families:

- healing herbs: Gravemoss T1, Dragonweed T2 and Crimson Lotus T3;
- universal spices: Sunleaf T1, Marshbloom T2 and Stormkelp T3;
- farmable-later foods: potato, corn, apple, berries and melon;
- found-only foods: mushrooms, wild cocoa and rock salt;
- cultural materials: Sunwax, Runeslate, Moonresin, Red Ochre, Spirit Resin
  and Gravesalt; and
- signature woods: Oak, Mountain Pine, Silverwood, Spikethorn Acacia, Kapok
  and Gravewood.

The gathering split, exact names and farmability are binding in
`docs/design/biomes_mobs.md:658-686,695-707,775-801`. Open cooking recipes and
magnitudes in `TODO-design-crafting-rework.md:546-610` block WP10, not the
registration and world-source work in WP33.

Current registrations are uneven:

- all six cultural **inventory items** already exist under
  `grug_materials:*` (`mods/ITEMS/grug_materials/registry.lua:262-276` and
  `mods/ITEMS/grug_materials/ores.lua:138-152`), but no cultural source node
  exists;
- all six signature tree/wood mappings already exist and WP43 audits their
  runtime registrations (`mods/ITEMS/grug_materials/registry.lua:278-292` and
  `mods/ITEMS/grug_materials/audit.lua:69-79`); WP33 must not duplicate them;
- `default:apple` and `default:blueberries` already exist
  (`mods/BASE/default/nodes.lua:785-804,1752-1763` and
  `mods/BASE/default/craftitems.lua:232-236`) and R6 already places their tree
  and bush templates; and
- none of the six named herb/spice items, potato, corn, melon, mushrooms,
  wild cocoa, rock salt or their source nodes is registered in the current
  production mods. `default:sand_with_kelp` is an unrelated upstream node,
  not Stormkelp (`mods/BASE/default/nodes.lua:1970-2022`).

The implementation should freeze one stable raw item and one non-dropping
world-source node for every missing gatherable. A source node drops the raw
item, never itself; this keeps a mapgen source from becoming player-placeable
and lets WP32 later register crops against the same raw food/spice items
without turning herbs or found-only foods into crops.

| Family | Stable raw items | Stable source nodes | Placement class |
|---|---|---|---|
| healing herbs | `grug_gathering:gravemoss`, `:dragonweed`, `:crimson_lotus` | same local names with `_source` | `new_p9g_source` |
| universal spices | `grug_gathering:sunleaf`, `:marshbloom`, `:stormkelp` | same local names with `_source` | `new_p9g_source` |
| new farmable-later food | `grug_gathering:potato`, `:corn`, `:melon` | same local names with `_source` | `new_p9g_source` |
| found-only food | `grug_gathering:mushroom`, `:wild_cocoa`, `:rock_salt` | same local names with `_source` | `new_p9g_source` |
| existing food | `default:apple`, `default:blueberries` | accepted R6 apple-tree and blueberry-bush features | `reuse_r6_source` |
| signature woods | the six existing `default`/`grug_trees` wood nodes | accepted R6 tree features | `reuse_r6_source` |
| cultural materials | six existing `grug_materials:*` items | six nodes in Section 3 | `r6_cultural_slot` |

That is a closed placement population: exactly 12 `new_p9g_source` entries,
eight existing gatherable feature families reused from R6 (two foods and six
woods), and exactly six cultural-slot registrations. No WP33 entry has to
replace an accepted R6 decoration. The catalog should also expose dispatch
groups rather than consumer name lists: `grug_gathering_source = 1` plus one
of `grug_healing_herb = tier`, `grug_spice = tier`, `grug_food = 1`,
`grug_found_only_food = 1` or `grug_cultural_source = 1`. This follows the
repository's group-dispatch rule (`AGENTS.md:242-245`).

## 3. Exact cultural-slot recommendation

Use six distinct non-liquid, non-ignore, non-walkable low-nodebox source nodes
in a new `grug_gathering` mod. Every one drops its existing canonical
`grug_materials:*` item. Runtime texture modifiers derived from already
vendored `default` media are sufficient for this WP; the existing cultural
item palette and provenance are recorded at
`mods/ITEMS/grug_materials/ores.lua:138-151` and
`mods/ITEMS/grug_materials/LICENSE-media.md:105-114`.

Use the same bounded asset strategy for the 12 new gathering sources: derive
16px plant/item variants from already vendored, attributed `default` images
and record the runtime modifiers in `grug_gathering/LICENSE-media.md`. The
older asset survey identifies clean external candidates but still requires
per-file attribution and verification
(`docs/research/assets/plants_farming_food.md:18-39`); no external import is
necessary to unblock WP33.

| R6 key | Recommended source node | Existing drop | Presentation |
|---|---|---|---|
| `gravesalt` | `grug_gathering:gravesalt_source` | `grug_materials:gravesalt` | pale salt-crystal crust |
| `moonresin` | `grug_gathering:moonresin_source` | `grug_materials:moonresin` | cool pearlescent resin root |
| `red_ochre` | `grug_gathering:red_ochre_source` | `grug_materials:red_ochre` | low ochre outcrop |
| `runeslate` | `grug_gathering:runeslate_source` | `grug_materials:runeslate` | inscribed slate slab |
| `spirit_resin` | `grug_gathering:spirit_resin_source` | `grug_materials:spirit_resin` | warm/green resin root |
| `sunwax` | `grug_gathering:sunwax_source` | `grug_materials:sunwax` | wild waxcomb cache |

For every key, validate this exact shape through
`r6.cultural_slot_api().validate` and persist the returned record and digest:

```lua
{
    id = "wp33_<key>_source_v1",
    template_or_simple_kind = "simple",
    immutable_content = {cells = {{
        x = 0, y = 1, z = 0,
        node = "grug_gathering:<key>_source",
        param2 = 0,
        force_place = false,
    }}},
    footprint_min_x = 0,
    footprint_max_x = 0,
    footprint_min_y = 1,
    footprint_max_y = 1,
    footprint_min_z = 0,
    footprint_max_z = 0,
    lower_two_policy = "preserve_p7",
}
```

R6 requires ASCII key order: Gravesalt, Moonresin, Red Ochre, Runeslate,
Spirit Resin, Sunwax (`mods/MAPGEN/grug_mapgen/wp40/r6.lua:24-27,253-299`).
R7's production content contract must mark each source node with cultural role
bit 16; construction otherwise fails closed
(`mods/MAPGEN/grug_mapgen/wp40/r6.lua:283-297`). The accepted reservation is
225 voxels but this proposal uses one above-ground cell and therefore cannot
invoke the lower-two replacement branch
(`docs/research/wp40-simple-map-r6-contract.md:605-662`).

## 4. Non-cultural single-writer integration options

### Option A — generalize the R6 cultural API

Rejected. The validator is structurally reusable for a cell shape, but the
candidate population is not: it is hard-bound to six cultural keys,
race-region eligibility, cultural density domains and accepted reservations
(`docs/research/wp40-simple-map-r6-contract.md:585-623`). Herbs, spices and
foods require different biome/zone/tier rosters and are explicitly excluded
from R6's closed decoration catalog. Generalizing it would rewrite R6
candidate, planner, settlement, manifest and ledger authority instead of
merely registering content.

### Option B — native engine decorations or a later healing writer

Rejected. Logical biome identity belongs to `grug_zones`, not the engine
biomemap, and R7 must leave exactly one Grudgelands geography/content writer.
R6's P7 normalization and surface clear also make survival of pre-existing
native flora an invalid assumption. Runtime healing is explicitly forbidden
for cultural slots (`docs/design/world_zones.md:866-895` and
`docs/research/wp40-simple-map-r6-decisions.md:60-75`).

### Option C — closed R7 P9G gathering successor (recommended)

WP33 owns an immutable, digestible catalog of the non-cultural source nodes,
outputs, logical-biome/zone eligibility, exact density, harvest policy and a
one-cell `(0,1,0)` presentation. R7 owns candidate selection and settlement as
P9G after accepted R6 P9 but before the single semantic replay/VM commit. P9G
accepts only dry, ordinary, unoccupied above-surface cells; any R6 occupancy,
cultural reservation, route/water/fixed/protected/housing exclusion, wrong
support or owner clipping rejects without movement, retry or refill. It must
not overwrite P7 material or any P8/P9 cell.

This is the smallest route that preserves R6 as a proven predecessor. It does
require a reviewed R7 extension because the current R6 session API exposes
only final `apply_fixture`, not its private pre-setter buffers
(`mods/MAPGEN/grug_mapgen/wp40/r6.lua:323-343`). P9G therefore cannot be an
external second pass after `apply_fixture`; it must be composed inside the R7
successor settlement before setters.

`P9G` is a name for this R7-only successor tail, not an edit to R6's accepted
P9 schema. The name avoids collision with implementation WP10 (professions)
while making the order explicit. The noninterference proof still treats all
P9G output as a removable versioned delta over frozen R6.

## 5. Healing-herb authorization without WP10

WP33 must enforce the Alchemist and matching book-group gate even though WP10
does not exist yet. Directly reading `grug_prof:alchemist` in WP33 would make a
second owner of future profession state, and granting a temporary profession
would ship behavior the design never authorizes. The minimal fail-closed seam
is therefore:

- `grug_gathering` owns the source node, the dig transaction and
  `register_herb_authorizer(fn)`. Registration accepts exactly one function
  for the process lifetime and rejects a second registration, following the
  existing single-consumer callback pattern
  (`mods/CORE/grug_core/combat.lua:689-700`).
- The callback contract is
  `fn(player, herb_key, required_group) -> allowed, reason`, where
  `required_group` is exactly the herb grade 1, 2 or 3. `allowed` must be a
  boolean; a denial reason is exactly `no_alchemist` or `book_group_locked`.
  A missing provider, thrown callback, non-boolean result or unknown reason is
  a fail-closed denial (`profession_unavailable` for missing/invalid
  integration), never a harvest.
- Until WP10 ships there is deliberately no registered production provider.
  All three healing-herb nodes remain scenery and a throttled message states
  that the Alchemist profession and the matching T1/T2/T3 book group are
  required. Food, spices and cultural sources never call this authorizer.
- WP10's `grug_jobs` mod depends on `grug_gathering` and performs the sole
  registration during load. Only that callback reads WP10's canonical
  profession/book state and decides `no_alchemist`, `book_group_locked` or
  success. WP33 neither names nor reads a player-meta key. The designed future
  storage remains WP10-owned (`docs/design/items_crafting.md:264-304`).

The grade-to-group identity is not a new design choice. The text says that the
former Herbalism tier gate is the Alchemist's own book group and that an
unopened herb yields nothing plus a hint
(`docs/design/items_crafting.md:845-854`); T1 opens with the profession and the
T2/T3 keystones consume the preceding herb grade
(`docs/design/items_crafting.md:319-330`). Thus Gravemoss requires open group
1, Dragonweed group 2 and Crimson Lotus group 3.

Focused offline fixtures use the same harvest-decision constructor with
injected stub callbacks; they do not register a profession or write player
meta. Required rows are: provider absent; provider throws; malformed return;
`no_alchemist`; group 1 against each grade; exact matching groups 1/2/3; and
universal food/spice bypass. The production instance receives only the
single registered callback. This proves negative and positive behavior while
the shipped pre-WP10 runtime remains entirely fail closed.

## 6. Evidence boundary

If P9G is strictly non-overwriting and cannot affect R6 candidate acceptance,
these accepted R6 results remain immutable predecessor evidence:

- R2-R5 projection parity and every P2-P9 plan/run tuple;
- 32-seed natural-resource placement, sampled-density parity, cultural
  opportunity/reservation and practical-access ledgers;
- the exact 24 apex and ordinary-camp socket results; and
- the accepted R6 artifact as the before-P9G projection.

The actual six WP33 cultural records add visible P9 cells inside already
accepted reservations. R7 must record their exact digests and exercise all six
real node targets; it does not reselect any cultural slot. R6's accepted
fixtures used one synthetic `grug_nodes:bone_pile` cell for every key
(`tools/wp40/r6/fixtures.lua:425-439`), so those fixtures prove the shape and
validator but not the final node identities or harvest behavior.

P9G creates new acceptance evidence rather than silently inheriting R6's
empty gathering boundary:

- exact catalog and source-file hashes;
- eligibility and rejection coverage for every gathering source;
- a 32-seed LuaJIT opportunity/accepted-source ledger over the existing seed
  corpus, including the binding faction-paired healing-herb and spice
  opportunity gate (`docs/design/world_zones.md:905-916`);
- an explicit proof that projecting away P9G yields byte-identical R6 P2-P9
  plans, ledgers and final intents;
- owner-slice, mapchunk-order, content-ignore, light/liquid and single-setter
  fixtures with P9G present;
- updated whole-mapchunk performance evidence; and
- on frozen final R7 Lua bytes, static PUC 5.1 gates plus exactly one compact
  PUC/LuaJIT micro-KAT pair with identical canonical digest. Exhaustive and
  32-seed work stays LuaJIT (`docs/research/luanti-lua.md:330-390`).

## 7. Decisions still required before implementation

1. Freeze the P9G successor boundary and its non-overwrite rule. This is an
   architecture/acceptance decision and blocks implementation.
2. Freeze exact source densities for the six herb/spice and six new food
   sources. The design fixes cultural density but not gathering density.
   Recommendation: keep these as exact rational, globally anchored
   opportunities in the P9G contract and calibrate one initial denominator per
   source from the 32-seed realized-area ledger; do not infer supply from an R6
   decoration fill or add refill logic to compensate for collisions.
3. Freeze the precise zone allowlists where the prose is broader than the
   explicit §11 examples, especially Dragonweed and the ordinary food line.
   Gravemoss (Copperfell/Mournfen), Crimson Lotus (Skyglass/Stormscale),
   Marshbloom (Whitebridge/Lorindor/Mournfen/Whispering Reedlands) and the four
   stated Stormkelp coast/approach zones can be exact rows. Dragonweed needs a
   reviewed explicit list rather than "Dwarf/forest side and Undead/Orc
   wilds" (`docs/design/world_zones.md:917-927`). Stormkelp also needs an exact
   shore predicate: Skyglass is a required high approach but has no
   `grug_beach` palette row (`docs/design/world_zones.md:600-607`), while the
   gathering spec otherwise says coast-zone beaches only
   (`docs/design/biomes_mobs.md:779-783`). Recommendation: bind Stormkelp to
   the four named zones plus valid wet sand/shore support, rather than require
   a `grug_beach` logical-biome label that would make Skyglass empty.
4. Freeze the cultural ordinary/concentrated harvest transaction. The design
   says ordinary sources retain natural axe/shovel/hand behavior while the
   concentrated zone requires T4 harvesting
   (`docs/design/items_crafting.md:1185-1202`), but no exact tool-family and
   failure-message seam is specified. Retain one source node per culture and
   determine the rate class from R7's exact named-zone authority at the node
   position (no node metadata). Ordinary sources keep their source-specific
   natural hand/axe/shovel semantics exactly as designed; WP33 must not route
   them all through one tool family.

   Concentrated-source tool families remain an explicit user/design decision,
   not an implementation recommendation. Before the contract can freeze, it
   must either assign the exact eligible family or families per cultural
   source, or deliberately choose one common family for all six. If it chooses
   source-specific families, use one reviewed, tier-neutral harvest resolver
   taking the wielded stack and requested family and returning an exact tier or
   `nil`; the source-specific transaction then requires tier 4. A missing or
   malformed resolver fails closed. Existing
   `grug_materials.pick_tier_for_stack` proves only the pick family
   (`mods/ITEMS/grug_materials/mining.lua:103-109`) and must not be promoted to
   universal cultural-harvest authority merely because no axe/shovel tier seam
   exists yet. Exact eligible families, the sole resolver owner and matching
   failure messages must be independently reviewed before implementation.
5. Accept the Section 5 single-authorizer seam as a real WP33/WP10 contract.
   It needs no interim profession implementation and no invented player-meta
   key, but WP10 must be bound to the exact callback before herb harvesting can
   become available.

The recommended cultural `preserve_p7` choice is not an outstanding decision:
it is the minimal safe answer to the R6-owned lower-two choice and avoids the
entire replacement proof chain.

## 8. Proposed package order

1. Independently review and accept the exact WP33/R7 successor contract,
   including P9G densities, zone rosters and harvest seams.
2. Implement `grug_gathering`: source/item registrations, harvest behavior,
   the pure closed P9G catalog and the exact six R6 validated records. Keep
   every writer disabled.
3. Run WP33 static and focused LuaJIT checks, then the final compact
   PUC/LuaJIT parity pair; independently review the package.
4. In R7, consume the accepted six cultural digests and P9G catalog in the
   single production content contract/settlement; prove R6 noninterference and
   all new gathering evidence before activation.
5. Only then perform the atomic legacy-writer cutover. Runtime/fresh-world
   visual evidence remains R8-owned.
