# Mod ownership map

Which mod owns which concern, the seams other mods call, and where the rules
live. Built on 2026-10-05 (Round 37 lane DB) from the `mod.conf` files, the
`SETGLOBAL` listing and a count of `<global>.<name>` uses outside each mod.
The [module guide](module-guide.md) has the details per area; the
[design docs](../design/README.md) own the game rules. Load order follows the
declared dependencies: BASE → `grug_sounds` → `grug_core` → `grug_xp`,
`grug_money` → ITEMS base → `grug_mapgen` → `grug_factions` → `grug_classes`,
`grug_visuals`, `grug_inventory` → `grug_mobs` → feature mods.

**Globals:** one table per mod, named after the mod, with two exceptions:
`grug_quality` publishes `grug_items` (the per-stack item model; the mod
sets no `grug_quality` table) and `grug_core` also publishes `grug_zones`
(the zone façade, `rawset` in `grug_core/zone_authority.lua`). The vendored
mobs_redo fork publishes `mobs`.

## CORE

| Mod | Owns | Seams other mods use | Rules |
|---|---|---|---|
| `grug_core` | Shared constants and helpers: the damage pipeline (`combat.lua`), aiming rays (`combat_ray.lua`), combat state, statuses and their icons, the message feed, HUD layout, settlement sockets, preparation plan and start preload, the zone authority, world protection, water guard, environment damage, tag carriers, item names, the platform's map reset (`map_reset.lua`), the world version record, start guard and online migration runner (`world_version.lua`, `migrations.lua`) | `feed`, `hud_layout`, `set_status`/`clear_status`, `settlement_sockets_at`, `mono_time`, `deal_ability_damage`, `aim_raycast`, `mark_in_combat`, `world_alterable`, `mob_level_at`, `register_level_overlay`, `register_on_equipment_change`, `map_reset.clear`/`register_on_relocate`, `migrations` (step versions and online handlers) ([upgrade contract](upgrade-contract.md)); PvP seams `pvp_can_harm`/`pvp_hit_landed` filled by `grug_pvp`; publishes `grug_zones` (`id_at`, `mob_level_at`, `terrain_height_at`, `faction_at`, …) | [combat_stats.md](../design/combat_stats.md), [world_zones.md](../design/world_zones.md) §13 |
| `grug_sounds` | Every effect sound: the event specs (`EVENTS`), their hooks (`HOOKS`), the formspec click, the approved files | `play(event, target)` | [sound.md](../design/sound.md) |
| `grug_ambience` | Beds, loops, calls and music per player; capital rotations; Help → Sound, `/music`, `/ambience` | none (data in `data.lua`, pure rules in `rules.lua`) | [sound.md](../design/sound.md) |

## PLAYER

| Mod | Owns | Seams other mods use | Rules |
|---|---|---|---|
| `grug_xp` | XP, levels, the curve, kill and quest XP units, the XP bar | `get_level`, `add_xp`, `register_on_level_change`, `mob_xp`, `quest_reward` | [progression.md](../design/progression.md) |
| `grug_money` | Copper in player meta, its display, the Bag of Coins | `format`, `get`, `add`, `take`, `take_with_inventory` | [economy.md](../design/economy.md) |
| `grug_factions` | The Accord and The Throng, faction choice, friend/foe, whom an NPC serves | `get_faction`, `same_faction`, `hostile`, `serves`/`refuse`, `register_on_faction_chosen` | [world.md](../design/world.md), [pvp.md](../design/pvp.md) |
| `grug_classes` | Classes and races, character creation (one window, `selection.lua`), attributes, HP and mana scaling, talents and the Talents & Skills page (the tree framework `layout_tree`) | `get_class`, `get_race`, `get_talent_bonus`, `get_max_mana`, `get_support_factor`, `talent_points_at`, `register_on_class_chosen`, `register_look_panel`, `register_on_arrival` | [classes.md](../design/classes.md), [skill_trees.md](../design/skill_trees.md), [scout.md](../design/scout.md) |
| `grug_abilities` | Class abilities as hotbar items, cooldowns, mana and rage, the crosshair, the LMB hold machine (`input.lua`), Blink, Charge's dash (`charge.lua`, `charge_path.lua`), the Scout kit, cast sounds | `register_ability`, `is_unlocked`, `restore_mana`, `add_rage`, `CAST_SOUNDS` | [classes.md](../design/classes.md) |
| `grug_skills` | The skill catalogue row of the Talents & Skills tab and the hotbar-only rule for bound skill representations (the retired mount items: main and bags) | `skill_catalog_row` (installed into `grug_classes`) | [inventory_equipment.md](../design/inventory_equipment.md) |
| `grug_inventory` | The inventory window (frame, tab order, inventory views; Round 44), the Inventory and Character tabs, equipment slots, bags, Help pages, the welcome window after the arrival, the equipment-change event; the give order, item pickup and dug drops, the sort and the potion belt (`storage.lua`, Round 44) | `equipment_changed` (fires `grug_core`'s equipment-change event; `grug_quality` wraps it), `equipment_slots`, `refresh`, `inventory_view`, `TAB_ORDER`, `BAG_COUNT`, `LINKS`, `give` (every item source), `fits`, `sort`, `slot_order`, `carried_lists`, `POTION_BELT` | [inventory_equipment.md](../design/inventory_equipment.md) |
| `grug_visuals` | One composition for skins, stature, armour overlays and the wielded weapon; looks; enchant colours; the player model's pose clips; the head look | `apply_entity`, `npc_race`, `npc_look`, `set_look`, `register_cloak_source`, `play_pose`, `start_pose`/`stop_pose`, `hold_head` | [character_visuals.md](../design/character_visuals.md) |
| `grug_trinkets` | The six special trinket consumers and their equipment cache | none (listens to the equipment-change event) | [items_crafting.md](../design/items_crafting.md) |
| `grug_jobs` | The recipe registry (every craft as an ingredient list, the Basic catalog), crafting jobs and the output area, profession progress, the Crafting tab, trainers, station nodes and furnace workspaces, station operations | `register_recipe`, `recipe`, `recipes_in_area`, `recipes_for_output`, `register_ingredient_tier`, `register_station_operation`, `can_craft_recipe`, `start_job`, `cancel_job`, `job_state`, `max_craftable`, `take_all`, `register_on_job_end`, `register_craft_box`, `award_progress`, `register_on_award_progress`, `open_trainer` | [professions.md](../design/professions.md), [inventory_equipment.md](../design/inventory_equipment.md) §4, [items_crafting.md](../design/items_crafting.md) §6b |
| `grug_quests` | Quest registry, per-zone quest data and its validation, state, the journal, tracker, markers, quest NPCs, "use at a place" objects | `register_on_turn_in`, `quest_held`, `marker_states`, `register_on_markers_changed`, `open_npc` | [quests.md](../design/quests.md), [story.md](../design/story.md) |
| `grug_parties` | Same-faction parties, invitations, the party HUD, the Party & PvP tab | `view`, `register_on_change`, `PAGE`, `pvp_section` (set by `grug_pvp`) | [parties.md](../design/parties.md) |
| `grug_pvp` | The PvP flag, the PvP section of the Party & PvP tab (installed as `grug_parties.pvp_section`), banner, target frame state, kill credit, logout death | `can_harm`, `can_support`, `support_contact`, `territory_at`, `stats`, `register_on_stat`, `register_on_change` | [pvp.md](../design/pvp.md) |
| `grug_mounts` | Riding tiers and boats (the purchase record; the six mount items are retired, Round 44), mount entities, the Riding Trainer and the Shipwright, mount prices | `dismount`, `toggle`, `owns_tier`, `owned_tier_ids`, `open_trainer`, `register_on_owned_tiers_changed`, `PRICES` | [mounts.md](../design/mounts.md), [boats.md](../design/boats.md) |
| `grug_home` | Innkeeper homes, the Claim Stone as travel home, return and respawn, waystones; one travel path (`travel.lua`) | `travel`, `respawn`, `open_innkeeper`, `known_waypoints` | [home_travel.md](../design/home_travel.md), [world.md](../design/world.md) §6 |
| `grug_housing` | Claim Stones: claims, fuel, permissions, interaction guard, Housing Stewards | `MIN_Y` (the rest is internal) | [housing.md](../design/housing.md) |
| `grug_map` | The map window (atlas, Z and the Map tab, Round 44) with the quest log (`quest_box.lua`) and quest targets (`targets.lua`), our minimap, markers and their providers, the zone banner and location | `location` (`capital_of`, …), `register_marker_provider`, `window.open`, `quest_npc`, `quest_targets` | [world_map.md](../design/world_map.md), [quests.md](../design/quests.md) |
| `grug_keys` | Rising edges of the zoom and aux1 keys (one control read per player per step) and the players' `zoom_fov` (Round 44) | `register_on_press` | [world_map.md](../design/world_map.md#map-window) |
| `grug_quickbar` | The quickbar on E (Round 44): owned mounts and boats, the potion belt and Return home in one window sent once per opening | `open`, `drink`, `FORMNAME` | [inventory_equipment.md](../design/inventory_equipment.md#the-quickbar-e-round-44) |
| `grug_achievements` | Per-character achievements, their counters and the cloaks they unlock | none (counts through other mods' hooks) | [character_visuals.md](../design/character_visuals.md) §5b |

## ENTITIES

| Mod | Owns | Seams other mods use | Rules |
|---|---|---|---|
| `mobs` | Vendored mobs_redo, a fork with GRUG PATCH sites ([VENDOR.md](../../VENDOR.md)): the mob entity and AI loop | `mobs:register_mob` and the entity API, through `grug_mobs` | [VENDOR.md](../../VENDOR.md) |
| `grug_mobs` | Every mob and NPC: the `register_mob` wrapper, levels and kill XP, threat (`aggro.lua`), sub-types, loot and drops, spawn regions and the merged spawn ABMs, camps and leaders, rares and bosses, dragons and arenas, the rift, garrisons, start villagers and settlement NPC roles, voices, the dawn departure | `register_mob`, `registered_cadence` (the live mob registry), `register_start_socket_role`, `spawn_regions`, `register_on_eligible_kill`, `register_on_boss_kill`, `subtype`, `pvp_garrison` | [biomes_mobs.md](../design/biomes_mobs.md), [spawn_regions.md](../design/spawn_regions.md), [combat_stats.md](../design/combat_stats.md) |
| `grug_projectiles` | Server-side homing projectiles | `register`, `spawn`, `spawn_batch` | [combat_stats.md](../design/combat_stats.md) |
| `grug_traders` | Vendors and the trade form, the one price module (`prices.lua`, pure `price_rules.lua`), stock, potions and their cooldown, the Crownbinder | `register_all_vendor_stock`, `start_potion_cooldown`, `CROWN_FEE` | [economy.md](../design/economy.md), [item_tiers.md](../design/item_tiers.md) |

## ITEMS

| Mod | Owns | Seams other mods use | Rules |
|---|---|---|---|
| `grug_materials` | The six material tiers, tier rock and mining, ores, resources, the race-region registry, tool lifetimes and the tool aliases | `TIERS`, `RESOURCES`, `PROCESSED_MATERIALS`, `TOOL_ALIASES`, `register_on_harvest` | [items_crafting.md](../design/items_crafting.md) |
| `grug_nodes` | Signature surface and structure nodes, crop soil and crop visuals | `crop_visual`, `bind_crop_soil_callbacks` | [farming.md](../design/farming.md) |
| `grug_trees` | The race trees Silverwood and Gravewood | `silverwood_replacements` | [biomes_mobs.md](../design/biomes_mobs.md) |
| `grug_gathering` | The closed gathering catalogue and harvest authorization | `register_herb_authorizer` | [professions.md](../design/professions.md) |
| `grug_gear` | Vendor bracket catalogues, weapons, armour and trinket items, tooltips' base text, enchant colours, usage permissions | `initialize_weapon_tooltip`, `describe_stack_base`, `usable_by`, `BRACKETS` | [items_crafting.md](../design/items_crafting.md), [item_tiers.md](../design/item_tiers.md) |
| `grug_quality` | Per-stack quality, enchantments and their values, found affixes, descriptions, drop chances, the crown (global `grug_items`) | `grug_items.enchant_value`, `crown_item`, `crown_preview`, `regenerate_description`, `POOLS` | [item_tiers.md](../design/item_tiers.md) |
| `grug_repair` | Durability and wear, broken gear, city repair services | `refresh_appearance` | [durability_repair.md](../design/durability_repair.md) |
| `grug_professions` | Weaponsmith, Armorsmith, Leatherworker and Tailor improvement catalogues, enchant data, upgrades | `register_enchants`, `register_upgrades` | [professions.md](../design/professions.md), [item_tiers.md](../design/item_tiers.md) |
| `grug_artisans` | Woodcarver and Goldsmith material, gear and enchant catalogues | none | [professions.md](../design/professions.md) |
| `grug_smelting` | The smelting nodes' recipe families and alloys | `register_alloy` | [items_crafting.md](../design/items_crafting.md) |
| `grug_brewing` | The brewing stand node and its recipe adapter | `register_recipe` | [professions.md](../design/professions.md) |
| `grug_alchemy` | Alchemist recipes, potions and elixirs | none | [item_tiers.md](../design/item_tiers.md) |
| `grug_cooking` | The dish catalogue in six tiers, cooking plants | `PLANTS` | [items_crafting.md](../design/items_crafting.md) |
| `grug_food` | Out-of-combat health and mana food buffs | `register_item`, `heal_multiplier` | [items_crafting.md](../design/items_crafting.md) |
| `grug_farming` | Crops, buckets, hoes, habitat renewal of wild plants and trees | none | [farming.md](../design/farming.md) |
| `grug_fishing` | The fishing rod, bobber and catch tables | none | [items_crafting.md](../design/items_crafting.md) |
| `grug_decor` | The decorative building kit | `register_shapes` | [settlements.md](../design/settlements.md) |

## MAPGEN and BASE

| Mod | Owns | Seams other mods use | Rules |
|---|---|---|---|
| `grug_mapgen` | World generation: the WP40 R7 pipeline (`wp40/`: zones, terrain, water, roads, ores, caves, settlements, capitals, POIs, decor, the one VoxelManip transaction), the wp13 building library, world nodes and POI displays | `wp40` (the zone session, layouts; through `grug_zones` for gameplay) | [world.md](../design/world.md), [world_zones.md](../design/world_zones.md), [settlements.md](../design/settlements.md), [world_preparation.md](../design/world_preparation.md) |
| BASE (`beds`, `creative`, `default`, `doors`, `dye`, `player_api`, `sfinv`, `stairs`, `vessels`, `walls`, `wool`, `xpanes`) | Vendored upstream mods with GRUG PATCH sites | engine-style APIs (`sfinv`, `player_api`, `default`) | [VENDOR.md](../../VENDOR.md) |

## Ownership traps

- **Two level APIs.** `grug_zones.mob_level_at` is the mapgen's level field;
  the level a mob gets on the surface is `grug_core.mob_level_at`, which
  asks the overlay `grug_mobs/spawn_regions.lua` registers through
  `grug_core.register_level_overlay` first.
- **`mod.conf` understates coupling.** Several mods call higher mods at
  runtime without declaring them (for example `grug_gear` declares only
  `default`; `grug_inventory.give` is called at run time from mods that load
  before it: `grug_factions`, `grug_money`, `grug_mobs`, `grug_housing`,
  `grug_farming`, `grug_fishing` and the vendored `default`). A fixture that
  loads one mod alone needs stand-ins for what it calls.
- **"compatibility" and "legacy" in a name do not mean removable.** The zone
  authority's compatibility adapters are the live `grug_zones` API, and
  `grug_mobs.registered_cadence` is the live mob registry.
- **mobs_redo is a fork,** not an upstream tree: read the vendored
  `mods/ENTITIES/mobs/api.lua` and VENDOR.md, not upstream documentation.
