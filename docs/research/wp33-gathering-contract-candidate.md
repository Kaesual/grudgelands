# WP33 / WP40 R7 Gathering Contract Candidate

Status: **ratified technical contract input**. The user accepted every
recommended decision D1--D6 on 2026-08-31. The player-visible rules are binding
through the authoritative design and backlog; this document retains their full
WP33/R7 schemas, predicates and evidence boundary.

Date: 2026-08-31 (Europe/Berlin)  
Candidate base: `dd1e192b8efa7afe865b5628b937a83a283433f6`

This candidate closes the exact WP33 content and placement population needed
before WP40 R7 may activate its writer. It changes no production file, runs no
Lua process and does not claim implementation acceptance.

Source authority cross-check: `BACKLOG.md` WP33/WP40;
`docs/design/biomes_mobs.md` Sections 2, 5 and 6;
`docs/design/world_zones.md` Sections 8 and 11;
`docs/design/items_crafting.md` Sections 2.2-2.3, 3.6 and 4.1; the still-open
questions in `TODO-design-crafting-rework.md` A1/A4/A5/E21;
`docs/research/wp33-gathering-cultural-preflight.md`;
`docs/research/wp40-r7-cutover-preflight.md`;
`docs/research/wp33-r7-preflight-review.md`; the accepted R6 contract;
`mods/MAPGEN/grug_mapgen/wp40/r6.lua`; and the existing item, node and tool
registrations under `mods/ITEMS/` and `mods/MAPGEN/`. The interpreter schedule
follows `docs/research/luanti-lua.md` “Interpreter and test strategy”, while
package/review handling remains governed by `docs/process/wp-workflow.md` and
`docs/process/agent-model-policy.md`.

## 1. Approved architecture carried into this contract

The user's 2026-08-31 approvals accept the coordinator's recommended
architecture and the exact player-visible decisions recorded in Section 9:

- exactly one `P9G` gathering tail runs after accepted R6 P9 and before the
  existing canonical run derivation and single VoxelManip commit;
- P9G is a versioned, strictly non-overwriting delta. It cannot alter a P2-P9
  candidate, reservation, intent or ledger row, and a rejected gathering root
  is never moved, retried or refilled;
- all six cultural registrations preserve P7 and use the accepted R6
  one-cell `(0, 1, 0)` shape;
- the concentrated cultural sources use source-specific tool families rather
  than one universal pick rule;
- healing herbs use one fail-closed authorizer owned by WP33, while WP10 alone
  owns profession and recipe-book state; and
- no WP33 node registers a decoration, mapgen callback, LBM healer, `set_node`
  placement or second VoxelManip pass.

The complete placement population is exactly **26 rows**:

| Placement class | Count | Authority |
|---|---:|---|
| `new_p9g_source` | 12 | New closed catalog in Section 5; R7 settles it after P9. |
| `reuse_r6_source` | 8 | Existing accepted R6 feature families in Section 6; WP33 adds no placement. |
| `r6_cultural_slot` | 6 | Exact accepted R6 registration shape in Section 7. |

These classes are disjoint catalog identities even where one existing tree
provides both apples and Oak. No twenty-seventh implicit source, placeholder or
fallback is permitted.

## 2. Shared P9G selection and settlement contract

### 2.1 Exact opportunity construction

Each of the twelve new rows supplies positive integers `fill_numerator` and
`fill_denominator`. The fraction is over **eligible root columns**, not over all
world columns, biome area, mapchunks or accepted placements.

For each source ID and each globally anchored 16 by 16 x/z cell, P9G:

1. enumerates eligible columns in canonical z-then-x order from the frozen R5
   planner source and the exact predicates in Sections 4-5;
2. calls the same exact-rational budget primitive used by R6 with multiplier
   `1/1`, using the domain-separated remainder digest
   `gathering_budget_remainder_v1` over full seed, source ID, cell x/z,
   numerator and denominator;
3. ranks eligible roots by `gathering_candidate_rank_v1` over full seed,
   source ID, cell x/z and root x/y/z, with z then x as the final tie-break;
4. retains exactly the budgeted prefix; and
5. later settles that fixed prefix in ASCII source-ID order. Settlement never
   asks for the next ranked root after a rejection.

The implementation must use the existing SHA-256 projection and exact integer
budget arithmetic; it may not add floating probability, `math.random`,
`PcgRandom`, seed truncation or a second density interpretation. The catalog,
zone arrays, host arrays and all digests are immutable defensive copies.

The manifest schema string is exactly
`grug_wp33_gathering_catalog_v1`. Its three dense arrays are ordered by ASCII
stable ID and have populations 12, 8 and 6. Its canonical framed serialization
includes every row field, every expanded zone/biome/host array, the P9G
placement record, R6 registration record/digest, harvest policy, raw/source
itemstring and source-file SHA-256. R7 authenticates one manifest SHA-256
before session construction in both Lua environments; an unknown field,
missing row, duplicate ID, changed order or digest mismatch is a startup
failure before callback registration.

### 2.2 Shared one-cell placement record `P9G-1`

Every `new_p9g_source` row uses this complete placement record:

| Field | Exact value |
|---|---|
| kind | `simple` |
| root | `(x, surface_y + 1, z)` |
| immutable cells | one cell `(0, 0, 0)`, source node, `param2 = 0`, `force_place = false` |
| footprint | min=max `(0, 0, 0)`; exactly 1 by 1 by 1 |
| vertical gate | `surface_y >= 1`; the unique 3-D owner containing the root settles it; in-owner support must have settled `intent_opcode` in `1..4` and `final_data` equal to the row host CID; only support in the immediately lower owner uses the analytic P7 authority, never a second owner or VM-halo read |
| support | exact accepted P7 cell at `(x, surface_y, z)` matching the row predicate |
| root predecessor | exact P7 air/clear output; `CONTENT_IGNORE`, liquid, foreign or unknown content rejects |
| lower-two policy | `preserve_p7`; P9G writes neither `surface_y` nor `surface_y - 1` |
| exclusions | any fixed/hard-protected, route, authored-water, cultural reservation, P8 resource, P9 decoration or housing-exclusion occupancy rejects; coast exclusions reject except for the two exact dry-island cases below |
| collision | any nonzero accepted R6 occupancy or non-P7 final intent rejects |
| failure | one primary reason, no movement, retry, refill, partial write or fallback |
| mutation | one new shadow-buffer intent only; no setter before the common final commit |

The coast exception is local to P9G settlement and closed to exactly
`exclude:coast:island_wyrmglass` and
`exclude:coast:island_stormscale`. P9G may treat one of those two exclusion
results as nonblocking only when the same column's authenticated
`column_values_at(x, z)` result has `water_class` exactly `land`. An anchor,
route, authored-water or other
earlier exclusion retains its existing priority, every other coast exclusion
still rejects, and the exception does not alter claim or protection semantics
for any other consumer. The root-predecessor, P7 support, housing, occupancy,
clearance, one-cell, non-overwrite, no-retry and common-commit gates below the
exclusion check remain unchanged.

The accepted R6 evidence artifact remains immutable but is not mislabeled as
the production content table: its 77 ASCII rows use the synthetic compatible
target `grug_nodes:bone_pile` for all six Cultural fixtures. R7 first builds
and authenticates `grug_wp40_r7_production_r6_content_v1`, exactly 83
ASCII-ordered rows comprising those 77 names plus the six real Cultural source
nodes. The six definitions keep R6 capability 16 and settle through the normal
R6 resolver against this production table. Its refs intentionally differ after
the inserted `grug_gathering:*` names; no raw byte identity with the 77-row
evidence table is claimed.

P9G then uses the compatible R6 decoration write-capability class `8`; it does
not add a sixth bit. That value is permission to write the same compatible
natural-vegetation target class, not a feature or ledger identity: P9G still
has its own closed successor opcode, class, policy and schema. The separate
`grug_wp40_r7_p9g_content_v1` table contains exactly twelve ASCII-ordered P9G
rows with local refs `1..12`; with production count `N = 83`, its successor run
ref is exactly `N + p9g_ref`. A closed P9G-only resolver validates its node
name, CID, `param2 = 0`, allowed natural-vegetation class and capability 8
before writing the shared private buffers. It cannot resolve a production-R6
ref, and the R6 resolver cannot resolve a P9G ref.

All existing target-owner mods load before `grug_gathering`, so registering the
six Cultural and then twelve P9G nodes does not change an already registered
engine CID. The production table's logical ref reordering is expected,
manifested and covered by the normalization proof below. The R7 manifest
authenticates the accepted 77-row evidence digest, the 83-row production-R6
digest and the twelve-row P9G suffix digest separately.

Primary rejection order is:

```text
clipped_owner
fixed_or_protected
route_or_water
housing_exclusion
content_ignore
wrong_zone
wrong_biome
wrong_shore
wrong_support
insufficient_clearance
r6_occupancy
```

The implementation may share an existing more general exclusion reason only
when its ledger projection preserves this exact semantic distinction. No root
is eligible merely because the live VM happens to contain a superficially
matching node: logical biome, named zone, analytic P7 support and exclusion
state all have to agree.

## 3. Exact named-zone sets

Arrays are ASCII ordered in the immutable catalog. The mnemonic names below
are explanatory only; the arrays are the candidate values.

| Set | Exact stable zone IDs |
|---|---|
| `Z_GRAVEMOSS` | `elandor_copperfell_foothills`; `kragmar_mournfen` |
| `Z_DRAGONWEED` | `elandor_ashenward_march`; `elandor_frostbarrow_shelf`; `kragmar_bannerbreak_mesa`; `kragmar_ossuary_reach` |
| `Z_CRIMSON_LOTUS` | `front_skyglass_canopy`; `front_stormscale_summit` |
| `Z_SUNLEAF` | `elandor_goldmead_vale`; `elandor_starbough_vale`; `kragmar_raincall_basin`; `kragmar_redtusk_savanna` |
| `Z_MARSHBLOOM` | `elandor_lorindor`; `elandor_whitebridge_shire`; `kragmar_ossuary_reach`; `kragmar_whispering_reedlands` |
| `Z_STORMKELP` | `front_gravesalt_escarpment`; `front_skyglass_canopy`; `front_stormscale_summit`; `front_wyrmglass_crown` |
| `Z_POTATO` | `elandor_ashenward_march`; `elandor_dawnmere_fields`; `elandor_goldmead_vale`; `elandor_whitebridge_shire`; `front_broken_causeway` |
| `Z_CORN` | `elandor_ashenward_march`; `elandor_dawnmere_fields`; `elandor_goldmead_vale`; `elandor_whitebridge_shire`; `front_broken_causeway`; `front_shattered_line`; `kragmar_bannerbreak_mesa`; `kragmar_redtusk_savanna`; `kragmar_speargrass_reach`; `kragmar_sunscar_flats` |
| `Z_MELON` | `elandor_glassroot_wilds`; `front_skyglass_canopy`; `front_stormscale_summit`; `kragmar_kapok_cradle`; `kragmar_raincall_basin`; `kragmar_thunderroot_wilds`; `kragmar_totemwater_reach`; `kragmar_whispering_reedlands` |
| `Z_MUSHROOM` | `elandor_ashenward_march`; `elandor_glassroot_wilds`; `elandor_lorindor`; `elandor_moonfall_wood`; `elandor_whitebridge_shire`; `front_broken_causeway`; `front_gravesalt_escarpment`; `front_skyglass_canopy`; `front_stormscale_summit`; `kragmar_blackwind_rise`; `kragmar_ossuary_reach`; `kragmar_thunderroot_wilds`; `kragmar_totemwater_reach`; `kragmar_whispering_reedlands` |
| `Z_WILD_COCOA` | `front_skyglass_canopy`; `front_stormscale_summit` |
| `Z_ROCK_SALT` | `front_gravesalt_escarpment`; `front_stormscale_summit`; `front_wyrmglass_crown` |

The Dragonweed roster is deliberately four-way and bracket-paired: the Accord
gets the 21-30 Dwarf crags source and 31-40 Human forest source; the Throng gets
the 21-30 Undead wild source and 31-40 Orc wild source. This is the exact
closure of “Dwarf/forest side and Undead/Orc wilds” in `world_zones.md` Section
11; it does not authorize every deep-forest, bone-forest, crags or badlands
patch in the world.

The food sets implement the existing asymmetry rather than pretending each
crop is race-neutral: potato is an Elandor field food, while Kragmar has the
larger corn/melon line. All food is universally harvestable, and contested
routes make each stable item tradeable/gatherable cross-faction. Only healing
herbs and spices are subject to the binding paired-faction rate gate.

## 4. Exact biome, support and shore predicates

The symbols in Section 5 expand to these complete predicates. Every branch
also requires the named-zone set in Section 3 and `P9G-1`.

| Predicate | Exact logical biome and accepted P7 support |
|---|---|
| `H_GRAVEMOSS` | Copperfell: `grug_pine_hills` on `default:dirt_with_coniferous_litter`; Mournfen: `grug_blight` on `grug_nodes:blight_dirt`. |
| `H_DRAGONWEED` | Frostbarrow: `grug_crags` on `default:gravel`; Ashenward: `grug_deep_forest` on `grug_nodes:dirt_with_forest_litter`; Ossuary: `grug_bone_forest` on `grug_nodes:dirt_with_bone_litter`; Bannerbreak: `grug_badlands` on `grug_nodes:mesa_clay`. |
| `H_CRIMSON_LOTUS` | Skyglass: `grug_jungle_fringe`; Stormscale: `grug_deep_jungle`; both on `grug_nodes:dirt_with_canopy_litter`. |
| `H_SUNLEAF` | Goldmead: `grug_meadows` / `default:dirt_with_grass`; Starbough: `grug_elf_forest` / `grug_nodes:dirt_with_silver_litter`; Redtusk: `grug_savanna` / `default:dry_dirt_with_dry_grass`; Raincall: `grug_jungle_edge` / `default:dirt_with_rainforest_litter`. |
| `H_MARSH` | `grug_swamp` on `grug_nodes:mud`. |
| `H_MEADOW` | `grug_meadows` on `default:dirt_with_grass`. |
| `H_CORN` | `grug_meadows` on `default:dirt_with_grass`, or `grug_savanna` on `default:dry_dirt_with_dry_grass`. |
| `H_JUNGLE` | `grug_jungle_edge` on `default:dirt_with_rainforest_litter`, or `grug_deep_jungle` / `grug_jungle_fringe` on `grug_nodes:dirt_with_canopy_litter`. |
| `H_MUSHROOM` | `grug_deep_forest` on `grug_nodes:dirt_with_forest_litter`; `grug_bone_forest` on `grug_nodes:dirt_with_bone_litter`; or `grug_swamp` on `grug_nodes:mud`. |
| `H_COCOA` | `grug_jungle_fringe` or `grug_deep_jungle` on `grug_nodes:dirt_with_canopy_litter`. |
| `H_DRY_SHORE` | Candidate column has `water_class = "land"`; support is its exact accepted P7 top; and at least one cardinal neighbor has `water_class` equal to `planned_water`, `coastal_shelf`, `deep_ocean` or `immutable_dragon_channel`. Diagonal-only contact is not shore. |
| `H_SALT_SHORE` | `H_DRY_SHORE` plus logical biome `grug_beach` and support `default:sand`. |

`H_DRY_SHORE` is the exact Stormkelp repair. Requiring `grug_beach` would make
the explicitly required Skyglass high coastal approach empty because that
zone has no beach palette row. The predicate remains visibly shore-bound: it
requires a dry surface cell directly cardinal-adjacent to authored water. It
does not turn an inland canopy patch into a coast and does not expose a new
public coast query.

## 5. Twelve `new_p9g_source` records

All raw items are non-placeable craftitems. All source nodes are low,
non-walkable, diggable, `buildable_to = false` nodes with
`not_in_creative_inventory = 1` that drop the raw item rather than themselves.
The source node definition carries `grug_gathering_source = 1` and exactly one
family group described below. `Farmable = yes` means WP32 may use the raw item
in its closed crop allowlist; it never makes the mapgen source node placeable.

| Stable source ID | Raw item / source node | Zone / host predicate | Exact density | Placement / lower two | Harvest and exact drop | Farmable |
|---|---|---|---:|---|---|---|
| `wp33_gravemoss_source_v1` | `grug_gathering:gravemoss` / `grug_gathering:gravemoss_source` | `Z_GRAVEMOSS` / `H_GRAVEMOSS` | `1/512` | `P9G-1`; preserve P7 | healing herb grade 1; authorizer group 1; success drops 1 Gravemoss | no |
| `wp33_dragonweed_source_v1` | `grug_gathering:dragonweed` / `grug_gathering:dragonweed_source` | `Z_DRAGONWEED` / `H_DRAGONWEED` | `1/768` | `P9G-1`; preserve P7 | healing herb grade 2; authorizer group 2; success drops 1 Dragonweed | no |
| `wp33_crimson_lotus_source_v1` | `grug_gathering:crimson_lotus` / `grug_gathering:crimson_lotus_source` | `Z_CRIMSON_LOTUS` / `H_CRIMSON_LOTUS` | `1/1024` | `P9G-1`; preserve P7 | healing herb grade 3; authorizer group 3; success drops 1 Crimson Lotus | no |
| `wp33_sunleaf_source_v1` | `grug_gathering:sunleaf` / `grug_gathering:sunleaf_source` | `Z_SUNLEAF` / `H_SUNLEAF` | `1/384` | `P9G-1`; preserve P7 | universal spice grade 1; hand gather; drops 1 Sunleaf | yes |
| `wp33_marshbloom_source_v1` | `grug_gathering:marshbloom` / `grug_gathering:marshbloom_source` | `Z_MARSHBLOOM` / `H_MARSH` | `1/512` | `P9G-1`; preserve P7 | universal spice grade 2; hand gather; drops 1 Marshbloom | yes |
| `wp33_stormkelp_source_v1` | `grug_gathering:stormkelp` / `grug_gathering:stormkelp_source` | `Z_STORMKELP` / `H_DRY_SHORE` | `1/1024` | `P9G-1`; preserve P7 | universal spice grade 3; hand gather; drops 1 Stormkelp | yes |
| `wp33_potato_source_v1` | `grug_gathering:potato` / `grug_gathering:potato_source` | `Z_POTATO` / `H_MEADOW` | `1/256` | `P9G-1`; preserve P7 | universal food; hand gather; drops 1 Potato | yes |
| `wp33_corn_source_v1` | `grug_gathering:corn` / `grug_gathering:corn_source` | `Z_CORN` / `H_CORN` | `1/256` | `P9G-1`; preserve P7 | universal food; hand gather; drops 1 Corn | yes |
| `wp33_melon_source_v1` | `grug_gathering:melon` / `grug_gathering:melon_source` | `Z_MELON` / `H_JUNGLE` | `1/512` | `P9G-1`; preserve P7 | universal food; hand gather; drops 1 Melon | yes |
| `wp33_mushroom_source_v1` | `grug_gathering:mushroom` / `grug_gathering:mushroom_source` | `Z_MUSHROOM` / `H_MUSHROOM` | `1/384` | `P9G-1`; preserve P7 | universal found-only food; hand gather; drops 1 Mushroom | no |
| `wp33_wild_cocoa_source_v1` | `grug_gathering:wild_cocoa` / `grug_gathering:wild_cocoa_source` | `Z_WILD_COCOA` / `H_COCOA` | `1/1024` | `P9G-1`; preserve P7 | universal found-only food; hand gather; drops 1 Wild Cocoa | no |
| `wp33_rock_salt_source_v1` | `grug_gathering:rock_salt` / `grug_gathering:rock_salt_source` | `Z_ROCK_SALT` / `H_SALT_SHORE` | `1/1024` | `P9G-1`; preserve P7 | universal found-only food; hand gather; drops 1 Rock Salt | no |

Family groups are exact: `grug_healing_herb = 1|2|3`,
`grug_spice = 1|2|3`, `grug_food = 1`, and additionally
`grug_found_only_food = 1` on the final three food rows. No source is inferred
from a name list.

The densities are the ratified initial supply contract, not a claim that the values have
already passed a world census. T1/common foods are deliberately more frequent;
T2 sources are intermediate; T3 and top cooking sources are `1/1024`. Section
8 requires the realized 32-seed ledger before any activation.

## 6. Eight `reuse_r6_source` records

These rows add **zero** P9G opportunities. WP33 attaches or audits gathering
identity and future-farming classification against the accepted R6 feature
families; it may not copy or resettle their templates.

| Stable reuse ID | Gatherable | Accepted R6 feature IDs | Existing source/output | WP33 rule |
|---|---|---|---|---|
| `wp33_apple_r6_reuse_v1` | Apple | `deep_forest_apple_tree`, `elf_forest_apple_tree`, `meadows_apple_tree` | tree templates containing `default:apple`; output `default:apple` | universal food, farmable later; retain existing apple interaction |
| `wp33_blueberry_r6_reuse_v1` | Blueberries | `pine_hills_blueberry_bush` | `default:blueberry_bush_leaves_with_berries`; output `default:blueberries` | universal food, farmable later; retain existing berry interaction |
| `wp33_oak_r6_reuse_v1` | Oak | `deep_forest_apple_log`, `deep_forest_apple_tree`, `elf_forest_apple_tree`, `meadows_apple_tree` | `default:tree` / `default:wood` | signature wood; existing axe/drops/sapling behavior; never a WP32 crop |
| `wp33_mountain_pine_r6_reuse_v1` | Mountain Pine | `crags_snowy_pine`, `pine_hills_pine_tree`, `pine_hills_small_pine_tree` | `default:pine_tree` / `default:pine_wood` | same rule |
| `wp33_silverwood_r6_reuse_v1` | Silverwood | `elf_forest_silverwood` | `grug_trees:silverwood_tree` / `grug_trees:silverwood_wood` | same rule |
| `wp33_spikethorn_acacia_r6_reuse_v1` | Spikethorn Acacia | `savanna_acacia_tree` | `default:acacia_tree` / `default:acacia_wood` | same rule |
| `wp33_kapok_r6_reuse_v1` | Kapok | `emergent_jungle_tree`, `jungle_edge_jungle_tree`, `jungle_tree` | `default:jungletree` / `default:junglewood` | same rule |
| `wp33_gravewood_r6_reuse_v1` | Gravewood | `blight_gravewood`, `bone_forest_gravewood` | `grug_trees:gravewood_tree` / `grug_trees:gravewood_wood` | same rule |

Apple and Oak intentionally refer to the same accepted templates but remain
two closed gatherable identities: fruit and trunk are different outputs. The
same feature bytes are never counted as two placements.

## 7. Six `r6_cultural_slot` records

The rows are in R6's required ASCII cultural-key order. Each definition is
validated by `r6.cultural_slot_api().validate`, and R7 embeds or derives the
returned canonical record and SHA-256. All six nodes carry
`grug_gathering_source = 1` and `grug_cultural_source = 1`, are non-walkable,
non-liquid, non-ignore and drop the existing canonical item rather than the
source node.

Shared registration bytes, with `<key>` and `<node>` substituted from the
table:

```lua
{
    id = "wp33_<key>_source_v1",
    template_or_simple_kind = "simple",
    immutable_content = {cells = {{
        x = 0, y = 1, z = 0,
        node = "<node>",
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

| R6 key / registration ID | Source node / exact drop | Ordinary eligible biomes | Concentrated zone | Density | Ordinary harvest | Concentrated harvest |
|---|---|---|---|---|---|---|
| `gravesalt` / `wp33_gravesalt_source_v1` | `grug_gathering:gravesalt_source` / 1 `grug_materials:gravesalt` | `grug_beach`, `grug_blight`, `grug_bone_forest`, `grug_swamp` | `kragmar_blackwind_rise` | ordinary `1/4096`; concentrated `1/1024` | shovel/crumbly; no minimum tier | pick family, tier >= 4 |
| `moonresin` / `wp33_moonresin_source_v1` | `grug_gathering:moonresin_source` / 1 `grug_materials:moonresin` | `grug_deep_forest`, `grug_elf_forest`, `grug_jungle_fringe` | `elandor_glassroot_wilds` | same | axe/choppy; no minimum tier | axe family, tier >= 4 |
| `red_ochre` / `wp33_red_ochre_source_v1` | `grug_gathering:red_ochre_source` / 1 `grug_materials:red_ochre` | `grug_badlands`, `grug_savanna` | `kragmar_bannerbreak_mesa` | same | shovel/crumbly; no minimum tier | shovel family, tier >= 4 |
| `runeslate` / `wp33_runeslate_source_v1` | `grug_gathering:runeslate_source` / 1 `grug_materials:runeslate` | `grug_crags`, `grug_crags_snowy`, `grug_pine_hills` | `elandor_stormvault_heights` | same | hand/oddly-breakable; no minimum tier | pick family, tier >= 4 |
| `spirit_resin` / `wp33_spirit_resin_source_v1` | `grug_gathering:spirit_resin_source` / 1 `grug_materials:spirit_resin` | `grug_badlands_east`, `grug_deep_jungle`, `grug_jungle_edge`, `grug_swamp` | `kragmar_thunderroot_wilds` | same | axe/choppy; no minimum tier | axe family, tier >= 4 |
| `sunwax` / `wp33_sunwax_source_v1` | `grug_gathering:sunwax_source` / 1 `grug_materials:sunwax` | `grug_deep_forest`, `grug_meadows` | `elandor_ashenward_march` | same | hand/oddly-breakable; no minimum tier | axe family, tier >= 4 |

The concentrated result is four times the **opportunity density**, not a second
node or a multiplied per-node drop. Ordinary and concentrated sources both
drop exactly one material. The exact current zone at dig time selects the
harvest rule; node metadata never stores a stale rate class.

### 7.1 Tier-neutral tool resolver contract

The sole resolver owner is `grug_materials`, because that mod already owns the
six material tiers and `grug_pick_tier`; `grug_gathering` must not create a
second tier taxonomy.

```text
grug_materials.tool_tier_for_stack(stack, family) -> tier_or_nil, reason
```

Contract:

- `family` is exactly `pick`, `axe` or `shovel`; any other family is a
  programmer error caught by startup catalog validation;
- family membership comes from existing `pickaxe`, `axe` or `shovel` groups;
- tier comes only from exact integer `grug_pick_tier`, `grug_axe_tier` or
  `grug_shovel_tier` in 1..6;
- success returns the integer and `ok`;
- empty or another family returns `nil, wrong_family`;
- a matching family with missing/malformed tier returns
  `nil, tier_unavailable`; and
- the implementation may delegate the pick branch to
  `pick_tier_for_stack`, but may not treat that pick-only API as axe or shovel
  authority.

The ratified fold also amends the WP29 `BACKLOG.md` row to own the exact
`grug_axe_tier` and `grug_shovel_tier` groups in addition to its existing pick
authority; `BACKLOG.md` now records that durable dependency. WP29 then
attaches the exact tier group to its final tool catalog. Until the relevant T4
tool exists, that concentrated family is deliberately unharvestable; WP33 does
not manufacture a temporary T4 tool. If the resolver is absent, throws,
returns a non-integer or returns a tier outside 1..6,
`grug_gathering` fails the dig closed as `resolver_unavailable`. A wrong family
is `wrong_tool_family`; a correct family below T4 is `tool_tier_too_low`.
Every refusal leaves node, wield stack, wear, drop callbacks, quest credit and
inventory unchanged and emits one throttled message naming the required
family and T4.

## 8. Healing-herb authorizer and evidence contract

### 8.1 One authorizer, no profession-state duplication

`grug_gathering` owns exactly this one-time registration seam:

```text
grug_gathering.register_herb_authorizer(fn)
fn(player, herb_key, required_group) -> allowed, reason
```

- Registration accepts exactly one function for the process lifetime. A
  second registration, even of the same function, is a load-time error.
- `herb_key` is exactly `gravemoss`, `dragonweed` or `crimson_lotus` and
  `required_group` is respectively 1, 2 or 3.
- Success is exactly `true, nil`.
- A valid denial is exactly `false, no_alchemist` or
  `false, book_group_locked`.
- Missing provider, thrown callback, malformed boolean, a reason on success or
  an unknown denial reason maps to `false, profession_unavailable`.
- Before WP10 there is no production provider: the three herbs are visible
  scenery but cannot be removed or harvested.
- Later, only `grug_jobs` registers the callback and reads its canonical
  profession/book meta. WP33 neither names nor reads `grug_prof:*`.
- Spice, food and cultural-source transactions do not call the authorizer.

Refusal happens before node removal, wear, drop, harvest callbacks or credit.
Messages are throttled per player/reason and distinguish “requires the
Alchemist profession”, “requires Alchemist book group Tn” and “profession
service unavailable”.

### 8.2 Required acceptance evidence

WP33 implementation and R7 activation require all of the following:

1. exact 12/8/6 population, ASCII IDs, source-file SHA-256 values, canonical
   manifest digest and six real R6 validator digests;
2. all referenced items/nodes/groups present, exact content-role masks and no
   unknown/ignore/liquid target;
3. offline harvest fixtures for provider absent/throws/malformed, each valid
   denial, groups 1/2/3 against all herb grades, universal bypass, every
   cultural ordinary family and every concentrated resolver failure/success;
4. a 32-seed LuaJIT P9G ledger with eligible, budgeted, accepted and every
   rejection count by source/zone/biome/faction/bracket;
5. for each healing-herb and spice grade and each applicable level bracket,
   exact faction opportunity rates `B_f/E_f`. With `hi` and `lo` selected by
   exact cross-products, acceptance is the inclusive 10% extrema rule
   `10 * B_hi * E_lo <= 11 * B_lo * E_hi`; no floating tolerance;
6. nonzero accepted access for both factions at every herb/spice grade, both
   high cooking sources (`wild_cocoa`, `rock_salt`) and all six cultural keys;
7. a closed two-stage proof: first remove the twelve-row P9G suffix and every
   P9G operation/run to recover the authenticated 83-row production-R6 result
   byte-for-byte; then normalize that result to the accepted 77-row evidence
   namespace by node name, map each of the six real Cultural targets back to
   the accepted `grug_nodes:bone_pile` fixture target/ref, rederive aux, runs,
   checksums and affected registration/content evidence, and require the
   accepted R6 artifact bytes plus identical P2-P9 candidate, occupancy,
   rejection and placement decisions. This explicitly bounded content-target
   normalization is not reported as raw predecessor byte identity;
8. same-seed, shard-order, mapchunk-order, owner-clipping, repeated-run,
   `CONTENT_IGNORE`, light/liquid and single-setter fixtures;
9. source audits proving zero WP33 `core.register_decoration`,
   `core.register_on_generated`, `core.register_mapgen_script`, geography LBM,
   `core.set_node` or VoxelManip placement path and one R7 mapgen transaction;
   ordinary item/node registration is expected and is not a writer; and
10. LuaJIT for all development, fixed-layout and 32-seed work. On frozen final
    Lua bytes, PUC 5.1 owns syntax/static gates and exactly one compact
    executable micro-KAT, run once under PUC 5.1 and once under LuaJIT with a
    byte-identical canonical digest. No intermediate PUC runtime or PUC fleet
    is scheduled.

### 8.3 Pragmatic frontier-access evidence amendment

For R7 pragmatic acceptance, this subsection supersedes only the population
scope and hard/advisory treatment in items 4--6 above. The main sample still
records its complete twelve-source ledger; its density and faction-parity
arithmetic are advisory, while the hard frontier access values move to the
separate lane below. Every other evidence requirement remains binding.

R7 keeps its 128-owner-per-seed three-projection stratified sample intact and
adds one strictly separate successor-only frontier-access lane. The new lane
uses no candidate, eligible, budgeted, accepted, biome, source-density or
settlement result to choose an owner. Before its first successor result, its
literal roster and SHA-256 are frozen from these four inclusive, static
horizontal envelopes and the fixed 80-by-80 owner grid:

- Gravesalt: `x = -2500..-1200`, `z = -250..250`, producing owner origins
  `x = -2512..-1232` and `z = -272..208` in steps of 80: 119 owners;
- Skyglass: `x = 1200..2500`, `z = -250..250`, producing owner origins
  `x = 1168..2448` and `z = -272..208` in steps of 80: 119 owners;
- Wyrmglass: `x = -3500..-2800`, `z = -390..380`, producing owner origins
  `x = -3552..-2832` and `z = -432..368` in steps of 80: 110 owners; and
- Stormscale: `x = 2800..3500`, `z = -400..390`, producing owner origins
  `x = 2768..3488` and `z = -432..368` in steps of 80: 110 owners.

The four ranges do not overlap. They therefore contain exactly 458 full owners
and 2,931,200 columns per seed, or 14,656 `(seed, owner)` cases and 93,798,400
visited columns over all 32 frozen seeds. The Holy Grounds envelopes follow the
fixed rectangle, the four unbiased frontier hubs and the closed maximum
60-node horizontal warp bound; the two island envelopes are their authored
polygon bounding boxes expanded by that same bound. This deliberately
conservative construction may include irrelevant columns but cannot discard a
dry target-zone column based on a later outcome.

This lane hard-gates nonzero eligible, budgeted and accepted populations for
exactly eight source-by-faction pairs: Crimson Lotus, Stormkelp, Wild Cocoa and
Rock Salt, each for Accord and Throng. Its four geographic zone identities are
exactly `front_gravesalt_escarpment`, `front_skyglass_canopy`,
`front_stormscale_summit` and `front_wyrmglass_crown`. Every owner is run for
every seed even after a pair has passed, zero rows remain evidence, and a
failure reopens placement or density rather than permitting owner reselection.

The frontier lane does not own or contribute to Stage A, Stage B, tuple parity,
the main sample's source populations, density, or faction-parity arithmetic.
Those claims remain with the unchanged three-projection sample and integration
gate; the two ledgers are validated and reported separately and are never
pooled.

The 32-seed ledger may reject the proposed denominators as insufficient
supply. Changing a denominator after seeing that evidence creates a new
candidate version and requires the complete P9G ledger again; it may not be an
unrecorded calibration loop or a collision refill.

## 9. Player-visible decisions ratified 2026-08-31

The user accepted Option A, the recommendation, for every decision D1--D6.
The alternatives remain below only as historical decision context and are not
implementation choices.

### D1 — Exact P9G densities

- **Accepted -- Option A:** Section 5's progression-shaped values:
  common food `1/256`, common spice/mushroom `1/384`, T1/T2 plants
  `1/512` or `1/768`, and T3/top sources `1/1024`, subject to the one recorded
  32-seed adequacy pass.
- Option B: use one density for all twelve. This is simpler but makes potato
  as rare as Crimson Lotus or makes high-tier sources commonplace.
- Option C: leave numbers open until implementation measurements. That keeps
  R7 blocked and invites an implementer to tune against outcomes without a
  frozen oracle.

### D2 — Exact source-zone rosters

- **Accepted -- Option A:** Sections 3-4, including the four-way
  Dragonweed pairing, high-only Wild Cocoa, beach-only Rock Salt and
  cardinal-water Stormkelp shore predicate.
- Option B: authorize every biome-compatible zone. This is mechanically
  shorter but violates the design rule that a biome patch alone does not
  authorize content above or outside the zone palette.
- Option C: narrow every ingredient to one zone per faction. This strengthens
  identity but makes collision/seed variance more likely to remove practical
  supply.

The prior authoritative design fixed Marshbloom to the four `W` wetland-
camp zones: `elandor_whitebridge_shire`, `elandor_lorindor`,
`kragmar_mournfen` and `kragmar_whispering_reedlands`
(`world_zones.md` Sections 8 and 11). The accepted roster replaces Mournfen
with `kragmar_ossuary_reach`, so all four accepted zones are level 21-30 and
the per-bracket paired-faction gate is satisfiable. Accepting this option
explicitly amends that authoritative four-zone list; the implementation may
not make the change silently. Retaining the current four-zone authority needs
no roster or palette amendment, but it leaves the 11-20 bracket with a
Throng-only Marshbloom source and therefore cannot meet the existing
per-bracket parity gate without a separate user ruling that changes that gate
or adds a paired Accord 11-20 source.

### D3 — Cultural tool-family assignment

- **Accepted -- Option A:** Section 7: concentrated resins/wax use
  axe, Runeslate and Gravesalt use pick, and Red Ochre uses shovel. Ordinary
  sources retain hand/axe/shovel behavior by presentation.
- Option B: one T4 pick for all six. This uses the current API but makes picks
  harvest wax and resin and was rejected by the independent preflight review.
- Option C: any T4 pick/axe/shovel harvests every source. This weakens source
  identity and makes the family parameter meaningless.

### D4 — What “concentrated” yields

- **Accepted -- Option A:** one item per node in both classes; concentration
  is exactly the already-decided fourfold opportunity density (`1/1024`
  versus `1/4096`).
- Option B: multiply the concentrated per-node drop as well. This compounds
  the already-fourfold density and adds an economy magnitude absent from the
  design.

### D5 — Tier-neutral resolver ownership

- **Accepted -- Option A:** `grug_materials` owns the generic family/tier
  resolver and WP29 supplies final family-tier groups. Missing T4 tools fail
  closed until WP29.
- Option B: WP33 owns its own tool-tier tables. This creates a second material
  taxonomy and will drift when WP29 replaces the tools.
- Option C: delay all cultural harvesting to WP29. Placement could proceed,
  but WP33 would not meet its gathering behavior contract.

### D6 — Ordinary P9G source interaction and per-node yield

- **Accepted -- Option A:** every successful herb, spice and new food source
  is one hand-gathered low node and drops exactly one stable raw item. Access
  rules still intercept herbs before removal. Supply is tuned only by the
  frozen opportunity fractions, so one quantity axis owns calibration.
- Option B: make field foods multi-node patches or grant multi-item drops.
  This is more visually abundant but adds a second yield multiplier and a
  larger collision footprint that the accepted one-cell successor no longer
  proves.
- Option C: require ordinary tools for some non-cultural plants. No such tool
  split exists in the design, and it would make universal food/spices less
  universal in practice.

The fail-closed single Alchemist authorizer has already been approved in
principle; Section 8 merely makes its return and failure vocabulary exact. If
any of those exact returns/messages are rejected, they must be replaced before
implementation rather than guessed in code.

## 10. Ratified implementation boundary

With Section 9 accepted and folded into authority, WP33 may implement one
new `grug_gathering` mod containing registrations, pure manifests and harvest
behavior, plus the minimal reviewed `grug_materials` resolver extension. It
must depend on every accepted R6 target-owner mod, register the six cultural
source nodes before the twelve ASCII-ordered P9G target nodes, and keep all
placement disabled. R7 then consumes the immutable manifest in the single
successor transaction, proves the delta and only then performs the atomic
legacy cutover.

No open recipe, cooking magnitude, profession keystone, T5/T6 leather/cloth,
Woodcarver grade, farming-growth or cultural-finishing question is decided by
this candidate. Those remain with `TODO-design-crafting-rework.md`, WP10,
WP29 or WP32 as already assigned.
