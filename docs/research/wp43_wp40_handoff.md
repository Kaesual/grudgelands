# WP43 → WP40 material-registry handoff

Status: WP43 shipped 2026-08-12. WP40 must rebase its engineering brief and
implementation against the runtime contract below. The code sources of truth
are [`registry.lua`](../../mods/ITEMS/grug_materials/registry.lua) and
[`mining.lua`](../../mods/ITEMS/grug_materials/mining.lua); the design sources
remain [`items_crafting.md`](../design/items_crafting.md) and
[`world_zones.md`](../design/world_zones.md).

## Tier and depth contract

All boundaries are inclusive. Target y, not the visual stratum or the path used
to reach it, determines natural-depth access.

| Tier | Key | Canonical bar | Canonical block | Stratum node | Lowest y |
|---:|---|---|---|---|---:|
| 1 | `bronze` | `grug_materials:bronze_bar` | `grug_materials:bronze_block` | `default:stone` | -100 |
| 2 | `iron` | `grug_materials:iron_bar` | `grug_materials:iron_block` | `grug_materials:slate` | -300 |
| 3 | `steel` | `grug_materials:steel_bar` | `grug_materials:steel_block` | `grug_materials:basalt` | -500 |
| 4 | `silversteel` | `grug_materials:silversteel_bar` | `grug_materials:silversteel_block` | `grug_materials:granite` | -700 |
| 5 | `embersteel` | `grug_materials:embersteel_bar` | `grug_materials:embersteel_block` | `grug_materials:emberrock` | -1000 |
| 6 | `abyssal_steel` | `grug_materials:abyssal_steel_bar` | `grug_materials:abyssal_steel_block` | `grug_materials:abyssal_rock` | -31000 |

The public depth surface is `TIERS`, `TIER_BY_KEY`, `tier_at(y)`,
`stratum_node_for(y)`, `max_depth_for_pick_tier(tier)` and
`can_mine_natural_at(pick_tier, y)`. WP40 must call or iterate these APIs; it
must not copy any y boundary or stratum ID.

The remaining public mining surface is `SHORTFALL_MULTIPLIERS`,
`PICK_PROFILES`, `build_pick_capabilities`, `pick_tier_for_stack`,
`is_natural_node`, `mining_decision`, `resource_ore_description`,
`register_on_harvest`, `emit_mining_failure`, `is_shattering` and the audited
`node_dig_wrapper`. WP40 does not replace these functions; its ground and
resource nodes enter the existing transaction through registry groups.

## Natural-ground extension duty

The mining transaction classifies generated ground through the explicit
`grug_natural = 1` group. `NATURAL_GROUND_NODES` is the owner inventory and
`NATURAL_GROUND_SET` is its audited lookup. `is_ground_content` is not a
classifier: the engine defaults it to true for nodes that include saplings and
decorations.

Whenever WP40 adds a generated ground, filler, beach, shelf, seabed or authored
rock node, it must add that node name to `NATURAL_GROUND_NODES` and apply
`natural_groups(groups)` in the owner registration. A crafted/decorative node
must not receive that group. The startup audit deliberately fails when an
inventory entry is missing or is not registered as natural.

## Resource registry

The public lookup surface is `RESOURCES`, `RESOURCE_BY_KEY`,
`RESOURCE_BY_NODE`, `resource(key)`, `resource_for_node(node_name)` and
`resource_node(key)`.

| Key | Scope/grade | Natural node | Raw item | Cut item | Harvest tier |
|---|---|---|---|---|---:|
| `coal` | universal | `default:stone_with_coal` | `default:coal_lump` | — | 1 |
| `copper` | universal | `default:stone_with_copper` | `default:copper_lump` | — | 1 |
| `tin` | universal | `default:stone_with_tin` | `default:tin_lump` | — | 1 |
| `iron` | universal | `default:stone_with_iron` | `default:iron_lump` | — | 1 |
| `quartz` | universal | `grug_materials:stone_with_quartz` | `grug_materials:quartz` | `grug_materials:cut_quartz` | 1 |
| `gold` | universal | `default:stone_with_gold` | `default:gold_lump` | — | 2 |
| `citrine` | regional G1 | `grug_materials:stone_with_citrine` | `grug_materials:rough_citrine` | `grug_materials:cut_citrine` | 2 |
| `garnet` | regional G1 | `grug_materials:stone_with_garnet` | `grug_materials:rough_garnet` | `grug_materials:cut_garnet` | 2 |
| `jade` | regional G1 | `grug_materials:stone_with_jade` | `grug_materials:rough_jade` | `grug_materials:cut_jade` | 2 |
| `silver` | universal | `grug_materials:stone_with_silver` | `grug_materials:silver_lump` | — | 3 |
| `emberglass` | universal | `grug_materials:stone_with_emberglass` | `grug_materials:emberglass` | — | 4 |
| `diamond` | regional G2 | `grug_materials:stone_with_diamond` | `grug_materials:rough_diamond` | `grug_materials:cut_diamond` | 4 |
| `sapphire` | regional G2 | `grug_materials:stone_with_sapphire` | `grug_materials:rough_sapphire` | `grug_materials:cut_sapphire` | 4 |
| `ruby` | regional G2 | `grug_materials:stone_with_ruby` | `grug_materials:rough_ruby` | `grug_materials:cut_ruby` | 4 |
| `abyssal_crystal` | universal | `grug_materials:abyssal_crystal_ore` | `grug_materials:abyssal_crystal` | — | 5 |

Harvest tier is independent of depth tier. WP40 owns placement geometry, not
the `grug_resource` value or its ×4/×6/×8/×10 under-tier transaction.

## Processed concepts

`PROCESSED_MATERIALS`, `PROCESSED_BY_KEY` and `processed(key)` publish exactly
12 concepts. WP40 may refer to their IDs but does not register their processing
or storage recipes.

| Key | Kind | Canonical item | Canonical block |
|---|---|---|---|
| `copper` | bar | `grug_materials:copper_bar` | `grug_materials:copper_block` |
| `tin` | bar | `grug_materials:tin_bar` | `grug_materials:tin_block` |
| `bronze` | T1 bar | `grug_materials:bronze_bar` | `grug_materials:bronze_block` |
| `iron` | T2 bar | `grug_materials:iron_bar` | `grug_materials:iron_block` |
| `steel` | T3 bar | `grug_materials:steel_bar` | `grug_materials:steel_block` |
| `silver` | bar | `grug_materials:silver_bar` | `grug_materials:silver_block` |
| `silversteel` | T4 bar | `grug_materials:silversteel_bar` | `grug_materials:silversteel_block` |
| `emberglass` | resource | `grug_materials:emberglass` | `grug_materials:emberglass_block` |
| `embersteel` | T5 bar | `grug_materials:embersteel_bar` | `grug_materials:embersteel_block` |
| `abyssal_crystal` | resource | `grug_materials:abyssal_crystal` | `grug_materials:abyssal_crystal_block` |
| `abyssal_steel` | T6 bar | `grug_materials:abyssal_steel_bar` | `grug_materials:abyssal_steel_block` |
| `gold` | bar | `grug_materials:gold_bar` | `grug_materials:gold_block` |

## Race-region supply schema

`GEM_GRADES.G1` is Citrine/Garnet/Jade and `GEM_GRADES.G2` is
Diamond/Sapphire/Ruby. The exact `RACE_REGIONS` rows are:

| Race | Faction | G1 | G2 | Cultural key/item | Wood key / tree / wood node |
|---|---|---|---|---|---|
| Human | Accord | Citrine | Diamond | `sunwax` / `grug_materials:sunwax` | `oak` / `default:tree` / `default:wood` |
| Dwarf | Accord | Garnet | Sapphire | `runeslate` / `grug_materials:runeslate` | `mountain_pine` / `default:pine_tree` / `default:pine_wood` |
| Elf | Accord | Jade | Sapphire | `moonresin` / `grug_materials:moonresin` | `silverwood` / `grug_trees:silverwood_tree` / `grug_trees:silverwood_wood` |
| Orc | Throng | Garnet | Diamond | `red_ochre` / `grug_materials:red_ochre` | `spikethorn_acacia` / `default:acacia_tree` / `default:acacia_wood` |
| Troll | Throng | Jade | Ruby | `spirit_resin` / `grug_materials:spirit_resin` | `kapok` / `default:jungletree` / `default:junglewood` |
| Undead | Throng | Citrine | Ruby | `gravesalt` / `grug_materials:gravesalt` | `gravewood` / `grug_trees:gravewood_tree` / `grug_trees:gravewood_wood` |

`CULTURAL_MATERIALS` also publishes the source descriptors: Sunwax from a
wild waxcomb or apiary cache; Runeslate from a slate inscription seam;
Moonresin from a resin root or fossil-resin nodule; Red Ochre from ochre clay
or an outcrop deposit; Spirit Resin from a resinous root or amber nodule; and
Gravesalt from a salt crust or crystal seam.

Only resources whose registry `scope` is `universal` belong to generic
placement. G1/G2 placement follows the race-region column. Cultural sources
and signature woods are likewise race-region content; they are not generic
fallback scatter. Foreign supply comes from the contested/deep/apex/trade
routes specified by the design, not a second material identity.

`DENSITY` publishes these final inputs:

- G1 shape `sparse_upper_rises_through_t4_flat_t5_t6`, with deep multiplier.
- G2 harvest tier 4 and host-node ratios T4 1:12000, T5 1:6000, T6 1:3000.
- Abyssal Crystal begins at T5 at 1:2048 host nodes.
- Deep multipliers are ×1.25 at y -1500..-1999 and ×1.50 at
  y -2000..-31000.

`CURRENT_SCATTER_RESOURCES` contains Coal, Tin, Copper, Iron, Gold,
Emberglass, Diamond, Quartz, Silver and Garnet only as the pre-WP40 running
mapgen baseline. WP40 replaces that global scatter with the final generic and
race-region placement; it must not mistake the list for the target roster.

## Forbidden targets and migration-only names

WP40 must never emit an Emberstone, Grudgesteel or Mese target ID. It must not
generate the upstream Mese/Diamond nodes, use `level_for_tier`, add node
`level`, or derive depth/access/durability from groupcap `maxlevel`.

`LEGACY_ALIASES` and `STORAGE_DERIVATIVES` are saved-world migration data, not
new-placement choices. In particular, minetest_game's historical
`default:steel_ingot` and `default:steelblock` mean smelted **Iron** and map to
`grug_materials:iron_bar` and `grug_materials:iron_block`; they never mean the
canonical Steel tier. `default:stone_with_mese` maps to Emberglass Ore and
`default:stone_with_diamond` maps to the canonical regional Diamond Ore.
`FORBIDDEN_RUNTIME_STEMS` publishes `emberstone` and `grudgesteel`, while
`canonical_name(item_name)` performs the one-hop lookup.

WP40 consumes this registry. It does not duplicate a depth boundary, harvest
tier, natural-node classification, resource/stratum ID, density input,
race-region assignment or legacy alias.
