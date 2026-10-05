# C9 — Item, crafting and profession mods

**Scope.** Every mod under `mods/ITEMS/` (13,040 Lua lines plus 18.5 KB of JSON):
grug_materials 2,366 · grug_decor 2,132 · grug_farming 1,134 · grug_quality 1,104 ·
grug_gear 1,051 · grug_professions 890 (+ `data/enchants.json`, `data/upgrades.json`) ·
grug_gathering 662 · grug_repair 585 · grug_food 557 · grug_alchemy 465 ·
grug_smelting 400 · grug_fishing 394 · grug_nodes 381 · grug_trees 317 ·
grug_artisans 272 · grug_cooking 265 · grug_brewing 65.

**Baseline.** `0f169898` (main). No file in scope changed during the review
(`git diff --stat 0f169898 -- mods/ITEMS` is empty).

**Method.** Read in full: grug_quality, grug_gear (all four files), grug_repair
(all), grug_farming (all), grug_food, grug_cooking, grug_fishing, grug_alchemy,
grug_brewing, grug_smelting, grug_professions (all Lua), grug_artisans,
grug_trees, grug_nodes, grug_gathering (init, harvest, nodes; catalog
skimmed), grug_materials (all except a skim of `audit.lua`'s matrix). grug_decor:
read `init.lua`, `capital.lua`, `shapes.lua`; skimmed the four kit files
(declarative node definitions, no crafts, ABMs, timers or inventories). To trace
the paths that start in this lane I also read the parts of
`PLAYER/grug_jobs/{automatic,workspaces,station_nodes,station_operations,stations}.lua`,
`PLAYER/grug_inventory/equipment.lua`, the equipment-change listeners in
`PLAYER/grug_{classes,visuals,abilities,trinkets,inventory}`,
`CORE/grug_core/combat.lua` (equipment notification, hit settlement) and
`ENTITIES/grug_traders/potion.lua`, plus the engine's `l_env.cpp`
(`find_nodes_in_area`), `l_object.cpp` (`set_properties`),
`serverpackethandler.cpp` (dig and place) and builtin `item.lua`,
`item_entity.lua`, `falling.lua`, `register.lua`.
Every texture name built in Lua (weapons, armour, tools, crop stages and
segments, dishes, raw assemblies) was checked against the shipped media: none
is missing. Every mob-loot item named by the alchemy, tailor, leatherworker
and base recipes was checked against `grug_mobs/data/items.json`: all exist.
One micro-benchmark (LuaJIT, scratch dir): builtin-style `core.deserialize` of a
two-enchant `grug_ench` string costs about 1.2 µs, so deserialization is not
where the per-hit cost of ITM-01 lies.

**Out of scope.** The station inventories, timers and dig handling of the
dual furnace, brewing stand and profession benches live in
`PLAYER/grug_jobs/workspaces.lua` and `automatic.lua` (the PLAYER lane). I read
them only to answer this lane's dig and fuel questions. Design docs were
consulted for intent only.

## Summary

- **No ABMs anywhere in ITEMS.** Growth and processing are node timers: crop
  soil (15 s under a growing crop, 60 s idle), crops (200 s per stage, only on
  wet soil), saplings (300–1500 s), and the stations' 1 s timer in grug_jobs.
  Two `run_at_every_load` LBMs (soil timers, tall-crop geometry). Wild plants
  return through a budgeted per-player globalstep (`grug_farming/renewal.lua`).
- **`grug_quality` publishes the global `grug_items`**, not `grug_quality`. It
  owns every enchant write (`store_affixes`), the item level and requirement
  meta, drops and boss rewards, the crown and the station operations, and it
  wraps `grug_classes.get_attributes/get_crit_chance_raw/get_dodge_chance_raw`,
  `grug_core.can_use_item_level`, `grug_core.get_armor_rating` and
  `grug_inventory.equipment_changed` at load time. Its per-player
  `aggregate_cache` is only correct because every equipment write goes
  through that wrapped `equipment_changed`.
- **Tooltips are layered strings.** A gear tooltip is written by
  `grug_items.regenerate_description`, then `grug_repair.decorate_description`
  (which removes the "Durability:" and "Usable by:" lines and adds them again),
  then `grug_gear.initialize_weapon_tooltip` (which adds the player-specific
  "Effective at level" line), and on a wear event by
  `grug_repair.decorate_description` once more. Several definition passes at
  `on_mods_loaded` (grug_gear, grug_repair, grug_materials) add lines as well. Each
  layer removes the other layers' lines by pattern (ITM-04).
- **Durability is per action.** Every settled outgoing action wears the
  weapon and every non-lethal hit taken wears a random armour piece, through
  `grug_repair/runtime.lua` `wear_stack`. That function rebuilds the tooltip
  and fires the whole equipment-change fan-out on every hit (ITM-01). This
  is the one hot-path problem in this lane.
- **Tools carry exact lifetimes** (`_grug_tool_uses`, `_grug_hoe_uses`) with an
  integer wear remainder in meta. The engine's groupcap `uses` values only
  serve as a "this dig wears" flag. The lifetime numbers and the remainder
  arithmetic exist in several copies (ITM-05).
- **`core.node_dig` is replaced** by `grug_materials/mining.lua:569-596`, which adds
  the tier, level and protection gates and the harvest hook for gathering XP
  and the goldsmith bonus. `audit.lua` fails the boot if anything replaces it
  later. Crops bypass it with their own `on_dig` (`dig_crop`).
- **Recipes are guarded at boot**: grug_smelting's audit, grug_professions' and
  grug_artisans' catalog input checks, the enchant-data item check and grug_jobs'
  overlap audit. Plain `core.register_craft` calls (leather grades, bolts,
  wood grades, fishing rod, bucket, seeds) are not covered by these audits, but
  every item they name exists.
- **Item meta is never written on stackable items.** Every stack with
  per-stack meta has `stack_max = 1` (gear, tools, buckets, trinkets), so no
  stacking bug was found. Crafted, rolled and upgraded equipment and tools
  carry a full `tool_capabilities` snapshot in their meta (ITM-15).
- **Fragile layering.** `grug_brewing` (which depends only on default and
  vessels) executes grug_jobs' `station_nodes.lua` to register the grug_jobs
  bench nodes before mapgen. `grug_professions` executes grug_jobs'
  `station_operations.lua`, which defines `grug_jobs.register_station_operation`
  (ITM-06).

## Findings table

| ID | Sev | Category | Title | Location |
|---|---|---|---|---|
| ITM-01 | High | Perf | Every hit and every action rebuilds the worn item's tooltip three times and fires the full equipment-change fan-out, which also empties the armour and enchant caches | `mods/ITEMS/grug_repair/runtime.lua:33-55`, `:147-160` |
| ITM-02 | Medium | Bug | Tall crops (cane, bamboo, corn) leave upper nodes that cannot be dug when the root goes without `dig_crop` | `mods/ITEMS/grug_farming/init.lua:308-357`, `:391-395`, `:418`; `mods/ITEMS/grug_nodes/crop_visual.lua:66-67` |
| ITM-03 | Medium | Bug | With seeds, a bucket or the fishing rod in hand, a right-click never reaches the node's `on_rightclick` (doors, chests, stations, harvesting regrowing crops) | `mods/ITEMS/grug_farming/init.lua:266-306`; `bucket.lua:27-75`; `mods/ITEMS/grug_fishing/init.lua:72-77`, `:260-283` |
| ITM-04 | Medium | Agent-trap | Tooltip is a layered string with 3–4 writers that remove each other's lines by pattern; line order depends on the path | `grug_quality/init.lua:479-515`; `grug_repair/presentation.lua:68-92`; `grug_gear/init.lua:382-391`, `:675-697`, `:703-748` |
| ITM-05 | Medium | Duplication | Tool and gear lifetimes are in six places (two of them dead); the wear-remainder arithmetic exists three times | `grug_materials/tool_lifetimes.lua:3`; `mining.lua:29-48`; `tools.lua:75-96`; `grug_farming/hoes.lua:3-18`; `grug_repair/presentation.lua:3-10`, `runtime.lua:39-45`, `:190-207` |
| ITM-06 | Medium | Agent-trap | ITEMS mods execute grug_jobs files: station nodes registered by grug_brewing, a grug_jobs API defined by grug_professions | `grug_brewing/node.lua:4-5`; `grug_professions/init.lua:73`; `PLAYER/grug_jobs/station_nodes.lua:1-4`, `:249-251` |
| ITM-07 | Low | Duplication | Vendor Weak Healing Potion copies the alchemy potion logic; it sends refusals to chat and has no level gate | `ENTITIES/grug_traders/potion.lua:72-120` vs `grug_alchemy/effects.lua:21-63` |
| ITM-08 | Low | Legacy | Nine "derived consumer" meta keys are written on every tooltip rebuild and never read | `grug_quality/init.lua:19-22`, `:158-175`, `:330-341` |
| ITM-09 | Low | Legacy | Dead data and dead overrides (REFINEMENTS, fish `on_use`, axe and shovel `uses`, edits of later-removed blocks) | `grug_cooking/init.lua:255-262`; `grug_fishing/init.lua:108`, `:126`; `grug_materials/tools.lua:75-96`; `overrides.lua:76-84` |
| ITM-10 | Low | Bug | Placing a slab on a slab uses up the item even when the placement fails | `grug_decor/shapes.lua:154-191`; `grug_materials/derivatives.lua:19-38` |
| ITM-11 | Low | Agent-trap | Gathering catalog: hand-kept manifest digest, plus source-file digests nothing checks | `grug_gathering/catalog.lua:4-11`; `init.lua:32-35` |
| ITM-12 | Low | Duplication | grug_artisans repeats grug_professions' helpers and audit with different duplicate-item rules; small tables and helpers are copied across files | `grug_artisans/init.lua:10-75`; `grug_professions/init.lua:24-116` |
| ITM-13 | Low | Perf | Armour totals are read through the tooltip builder; the shield rating is recomputed on every hit taken | `PLAYER/grug_inventory/equipment.lua:542-566`; `grug_quality/init.lua:1008-1017` |
| ITM-14 | Low | Perf | Every node dug with a tool rebuilds the tool's whole tooltip and serializes the stack twice | `grug_repair/runtime.lua:190-209`; `presentation.lua:80-92` |
| ITM-15 | Low | Agent-trap | Crafted and rolled equipment and tools store a `tool_capabilities` snapshot in their meta, so later definition retunes never reach existing stacks | `grug_quality/init.lua:517-543`, `:814-829` |
| ITM-16 | Low | Duplication | Two fuel systems: furnaces use their own table, the brewing stand uses engine fuel recipes; charcoal works in one only | `PLAYER/grug_jobs/automatic.lua:10-25`; `grug_smelting/recipes.lua:41-52` |

## Findings

### ITM-01 Every hit and every action rebuilds the worn item's tooltip three times and fires the full equipment-change fan-out
- **Severity** High / **Category** Perf / **Confidence** Verified (path traced end to end); cost Plausible (not measured in the engine)
- **Location:** `mods/ITEMS/grug_repair/runtime.lua:33-55` (`wear_stack`), `:141-145` (outgoing actions), `:147-160` (incoming hits); `presentation.lua:80-92` (`refresh_stack`)
- **What:** `wear_stack` runs on every settled outgoing damage or heal action
  (`grug_core.run_settled_outgoing_action`, `CORE/grug_core/combat.lua:997`,
  `:1523`, `:1589`, `PLAYER/grug_abilities/init.lua:1197`) and on every non-lethal
  punch damage to a player (`combat.lua:1928-1934`). For each event it:
  1. calls `grug_repair.refresh_stack`. That runs `refresh_appearance`, then
     `initialize_weapon_tooltip`, which runs `refresh_appearance` again and
     `regenerate_description` (a third `refresh_appearance`, `read_affixes`,
     `describe_stack_base`, `usable_by`, `write_derived` with at least nine meta
     writes), then `decorate_description` and the "Effective at level" line.
     It then runs `decorate_description` a second time and `stack:to_string()`
     twice. All of this produces a new "Durability: N / M" line, and that
     number changes on every use (1000–4000 uses per item);
  2. writes the stack back and calls
     `grug_inventory.equipment_changed(player, list, "durability_metadata")`.
     That empties `armor_cache`, `slot_cache` and grug_quality's `aggregate_cache`,
     then runs every equipment-change listener. Only grug_gear
     (`grug_gear/init.lua:809`) and the Scout's bow
     (`grug_abilities/scout.lua:475`) look at the reason. The others run in
     full on every hit: `grug_classes.apply_stats` (`get_max_hp` recomputes the
     enchant totals, plus a `player:get_properties()`), `grug_visuals.apply`
     (compose, `player_spec`, `sync_wield`), `grug_inventory.refresh` (rebuilds
     and resends the Character formspec if it is open), and grug_abilities'
     `clamp_mana`, `hud_update` and `sync_descriptions`, which walks main and
     the bags to compare every ability item's description.

  The armour cache's own comment says it exists because "the armor total is
  read once per punch TAKEN (~1200/s at the 100-player target)"
  (`PLAYER/grug_inventory/equipment.lua:591-594`). This path empties that cache
  on exactly those punches. The next read then runs `describe_stack_base` for
  all four armour pieces (ITM-13).
- **Impact:** The cost grows with players × hits. One player in a fight
  causes about 1–2 events per second (one swing or cast and one mob hit).
  Estimated cost class: 0.1–0.3 ms of Lua per event, from about ten listener
  passes, three tooltip rebuilds and the cache rebuilds, plus one changed
  equipment list sent to the client. That is 4–12 ms/s at 20 fighting players
  and 20–60 ms/s at 100. Group fights (raid bosses, rift, PvP) are the worst
  case. This is an estimate: measure it with the R32 perf probe before
  and after any fix.
- **Better:** Separate a wear update from an equipment change.
  (a) In `wear_stack`, call `equipment_changed` only when the broken state
  flips, because that is the only thing the stat, armour and skin consumers
  read. For the bow identity snapshot, either keep a narrow
  `durability_metadata` notification that only the Scout listens to, or let the
  Scout read the bow's identity lazily. (b) Replace the full `refresh_stack`
  on a non-breaking use with a cheap update that rewrites only the
  durability line in place (one `gsub` on `meta:get_string("description")`), and
  do the full rebuild only when the item breaks or is repaired. (c) Optionally
  throttle the visible durability number (for example every 1 % or on inventory
  open). That would also stop the equipment list being resent on every hit.
  Effort M. Risks: the Scout's captured-shot identity (`capture_action`), the
  broken-item look (`refresh_appearance`), and fixtures in `tools/r35_f`
  (break hook) and the repair fixtures. Depends on ITM-04 if the line is
  edited in place.
- **Verification (phase 2):** Partly confirmed — the CPU chain is real (`grug_repair/runtime.lua:49-52` → grug_quality wrapper `init.lua:1019-1024` → `equipment.lua:207-214` → seven consumers; only grug_gear `init.lua:809`, the abilities swing-clock branch `init.lua:1944` and Scout `scout.lua:475` read the reason, trinkets and visuals filter by list only), but the network amplification is wrong: the engine's `set_properties` only marks properties unsent when the struct actually changed (`reference_projects/luanti/src/script/lua_api/l_object.cpp:1027-1032`, since c524c52ba), so the unchanged `visual_size` write sends nothing, and the Character formspec is deduplicated (`l_object.cpp:1748`); the only per-event packet is the inventory resend any wear write needs. Estimate (engine calls counted, ~0.5 µs per `get_stack`, 1.6 µs per `get_properties` from upstream-workarounds.md, ~6–12 µs LuaJIT `-joff` for the ~3 KB Character string): about 0.25–0.5 ms per weapon-wear event (two 96–128-slot walks dominate) and 0.15–0.3 ms per armour-wear event, i.e. O(players × hits) CPU only, still High at the 100-player target. Part (1), the in-stack tooltip rebuild (`presentation.lua:80-92` → `grug_gear/init.lua:703-743` → `grug_quality/init.lua:479-515`), is confirmed as written; ITM-01 does not claim the property broadcast. Same verdict as PLY-01, CORE-01, CMB-02.

### ITM-02 Tall crops leave upper nodes that cannot be dug when the root goes without `dig_crop`
- **Severity** Medium / **Category** Bug / **Confidence** Verified
- **Location:** `mods/ITEMS/grug_farming/init.lua:308-318` (`root_for`), `:340-357` (`dig_crop`), `:391-395` (helper: `buildable_to = false`, `on_dig = dig_crop`), `:418` (root `attached_node = 1`), `:465-477` (LBM runs only from roots); `mods/ITEMS/grug_nodes/crop_visual.lua:66-67` (root `buildable_to = true`, `floodable = true`)
- **What:** Sugar cane, bamboo shoot and corn are a root plus 1–3 "Crop
  (upper)" helper nodes. Both `on_dig` and `on_rightclick` of a helper first
  resolve the root, and when the root is missing they return without doing
  anything (`root_for` → nil). The root can disappear without `dig_crop`
  in three ordinary ways:
  - **Digging the soil under it.** The root is `attached_node`, so builtin's
    `on_dignode` → `check_for_falling` → `drop_attached_node` removes it
    (`builtin/game/falling.lua:361-389`). The helpers have no attached group
    and stay where they are.
  - **Placing a block on it.** The root inherits `buildable_to = true` from
    `crop_visual`, and the gameplay table does not override it.
  - **Flowing water.** The root is `floodable`; water at ground level replaces
    the root and leaves the helpers above.

  The orphaned helper is `buildable_to = false`, cannot be dug and cannot be
  harvested. The geometry LBM only runs from roots, so nothing ever removes it.
  The reverse case also exists: if a helper is lost, `whole_crop_positions`
  fails and the root can no longer be dug until the LBM rebuilds the helper on
  the next block load.
- **Impact:** Floating, permanent plant nodes in player fields, and blocked
  building space. This is common enough: re-digging a field is normal, and
  fields need water within 3 nodes.
- **Better:** (1) When `root_for` fails in `dig_crop`, remove the helper
  (with the protection check and no drops). (2) Give roots an `after_destruct`
  that removes owned helpers, which covers attached drops, floods and
  `set_node`. (3) Optionally set `buildable_to = false` on roots of tall crops.
  Effort S. Risk: `after_destruct` also runs inside `transition_crop`'s
  `swap_node`. It does not, because `swap_node` does not call destruct
  callbacks, but check the regrow path in a test.
- **Verification (phase 2):** Confirmed — a helper's `on_dig`/`on_rightclick` resolve the root through `root_for` and return without action when it is missing (`grug_farming/init.lua:308-318`, `:340-344`); the root keeps `buildable_to`/`floodable` from `grug_nodes/crop_visual.lua:65-66` and is `attached_node` (`:419`), builtin `drop_attached_node` uses plain `core.remove_node` (`builtin/game/falling.lua:380`) and grug_materials' `node_dig` wrapper delegates to builtin, and no `after_destruct`/`on_destruct` or other orphan cleanup exists anywhere in `mods/`. Small nuance: helpers are themselves floodable, so flowing water can still wash an orphan away.

### ITM-03 With seeds, a bucket or the fishing rod in hand, a right-click never reaches the node's `on_rightclick`
- **Severity** Medium / **Category** Bug / **Confidence** Verified
- **Location:** `mods/ITEMS/grug_farming/init.lua:266-306` (`place_seed`); `mods/ITEMS/grug_farming/bucket.lua:27-62` (`fill`, `place`), `:68`, `:75`; `mods/ITEMS/grug_fishing/init.lua:72-77`, `:260-283` (`cast_or_reel`)
- **What:** On a right-click on a node the engine calls only the wielded item's
  `on_place` (`serverpackethandler.cpp`, INTERACT_PLACE → `item_OnPlace`). A
  node's `on_rightclick` runs only through builtin `core.item_place`. These three
  custom `on_place` functions never call it, while MTG's farming and bucket
  versions do. The result:
  - Seeds in hand: a right-click on a mature regrowing crop does not
    harvest it (`place_seed` returns at `:273-277`). Doors, chests and
    stations do not open.
  - Water bucket in hand: a right-click on a chest, door or station places a
    water source in front of it (`place` falls through to `pointed.above`).
  - Empty bucket or rod in hand: nothing happens.

  Food items are not affected: grug_food's `on_place` forwards to the original
  `on_place` or `core.item_place`.
- **Impact:** Players who farm hold seeds, so harvesting a field fails
  silently. Water can be placed by accident in front of chests and doors.
- **Better:** One shared helper (for example in grug_core) that calls the
  pointed node's `on_rightclick` unless the player is sneaking, as MTG does,
  used first in all three `on_place` functions. Effort S.
- **Verification (phase 2):** Confirmed — INTERACT_PLACE calls only the wielded item's `on_place` (`serverpackethandler.cpp:1185ff`) and node `on_rightclick` forwarding lives in builtin `core.item_place` (`builtin/game/item.lua:337-347`); `place_seed` (`init.lua:266-306`), the bucket's `fill`/`place` (`bucket.lua:27-62`) and `cast_or_reel` (`grug_fishing/init.lua:260-283`) never call it, and no global `on_place` wrapper exists outside BASE (grug_abilities' forwarding at `init.lua:579` covers ability items only). The filled bucket (liquids_pointable) does place water at `pointed.above` in front of a chest or door.

### ITM-04 Tooltip is a layered string with 3–4 writers that remove each other's lines by pattern
- **Severity** Medium / **Category** Agent-trap (Duplication) / **Confidence** Verified
- **Location:** `grug_quality/init.lua:479-515` (`regenerate_description`); `grug_repair/presentation.lua:68-78` (`decorate_description`), `:80-92` (`refresh_stack`); `grug_gear/init.lua:382-391` (`describe_stack_base` fallback filters `^Effective at level`, `^Durability:`, `^Usable by:`, `^%d+ uses$`), `:675-697`, `:703-748`; `grug_materials/tool_lifetimes.lua:17-19`, `mining.lua:214-228`
- **What:** No single function builds a tooltip. Each layer appends its own
  lines and removes the others' by Lua pattern. The final line order therefore
  depends on the path. After a pickup or craft (`initialize_weapon_tooltip`
  only) a weapon reads "… Requires level N / Usable by / Durability /
  Effective at level". After its first wear (`refresh_stack`, which runs
  `decorate_description` again) it reads "… Requires level N / Effective at
  level / Usable by / Durability". `usable_by` is computed three times per
  rebuild.
- **Impact:** The order visibly changes. Adding a new line (a new stat, a set
  bonus, a binding) needs coordinated edits to the strip patterns in at least
  three files, or lines are duplicated or lost. Agents tend to patch one
  layer.
- **Better:** One `grug_items.build_tooltip(stack, player)` that builds an
  ordered list of named sections (name, base, enchants, crowned, usable,
  requirement, durability, effective), each filled by a registered provider.
  grug_repair and grug_gear register providers instead of editing the string.
  The definition-time `on_mods_loaded` passes use the same builder. Effort M.
  Makes ITM-01(b) trivial.
- **Verification (phase 2):** Confirmed — traced: `regenerate_description` emits … Usable by / Requires / Durability (`grug_quality/init.lua:500-508`), `decorate_description` strips and re-appends Usable by + Durability (`grug_repair/presentation.lua:68-78`), `initialize_weapon_tooltip` appends Effective (`grug_gear/init.lua:703-748`) and `refresh_stack` decorates once more (`presentation.lua:89`), so the line order differs between craft and first wear exactly as stated; `usable_by` runs three times per `refresh_stack`.

### ITM-05 Tool and gear lifetimes are in six places; the wear-remainder arithmetic exists three times
- **Severity** Medium / **Category** Duplication / **Confidence** Verified
- **Location:** `grug_materials/tool_lifetimes.lua:3` (`{300 … 3000}`, sets `_grug_tool_uses`); `grug_materials/mining.lua:29-48` (`PICK_PROFILES[t].uses`, same numbers); `grug_materials/tools.lua:75-96` (`AXE_PROFILES`/`SHOVEL_PROFILES` `uses = 24…60`, overwritten by `tool_lifetimes`); `grug_farming/hoes.lua:3` (`uses_by_tier`), `:8-18` (`spend_use`); `grug_repair/presentation.lua:3-10` (`maximum_durability` fallback `{1000 … 4000}`); `grug_repair/runtime.lua:39-45` (`wear_stack`), `:190-207` (`after_use`)
- **What:** The per-tier lifetime of a tool exists four times, and two of
  those copies (axe and shovel `uses`) have no effect, because
  `tool_lifetimes.normalize` replaces every groupcap `uses`. Gear lifetimes
  have a fifth table. The integer-remainder wear is implemented three times
  with different reset rules: hoes reset the remainder when wear is 0, the
  repair paths do not.
- **Impact:** Retuning `AXE_PROFILES.uses` or `PICK_PROFILES.uses` silently does
  nothing, or only half of it. A new tool family has to copy the remainder
  code a fourth time.
- **Better:** One lifetime table (per tier and family) in grug_materials, and
  one `grug_repair.spend_use(stack, uses)` that the hoe, the `after_use`
  override and `wear_stack` call. Remove the dead `uses` fields. Effort S.
- **Verification (phase 2):** Confirmed — `tool_lifetimes.lua:4-30` overwrites every groupcap `uses` of all grug_materials picks, axes and shovels, so `AXE_PROFILES`/`SHOVEL_PROFILES.uses` (`tools.lua:77-93`) are dead and `PICK_PROFILES[t].uses` (`mining.lua:29-48`) is effectively dead as well (read only by `build_pick_capabilities`, whose value is then overwritten, and by `audit.lua:265`), so "or only half of it" understates: retuning pick `uses` changes nothing either. The remainder arithmetic is in `hoes.lua:8-17`, `runtime.lua:39-42` and `:194-200`, with the wear-0 reset only in the hoe copy.

### ITM-06 ITEMS mods execute grug_jobs files: station nodes registered by grug_brewing, a grug_jobs API defined by grug_professions
- **Severity** Medium / **Category** Agent-trap (Legacy) / **Confidence** Verified
- **Location:** `mods/ITEMS/grug_brewing/node.lua:4-5`; `mods/ITEMS/grug_professions/init.lua:73`; `mods/PLAYER/grug_jobs/station_nodes.lua:1-4`, `:249-251`, `:141-155` (LBM registered with `":grug_jobs:"`); `mods/PLAYER/grug_jobs/init.lua:14`
- **What:** `grug_brewing`, which declares only `default, vessels`, executes
  `grug_jobs/station_nodes.lua`. That registers `grug_jobs:forge`,
  `:tanning_rack`, `:tailor_bench`, `:carving_bench`, `:jewellers_bench` and an
  LBM through `":"`-prefixed names, and stores the module as
  `grug_brewing._grug_station_factory` so that grug_jobs' later `dofile` of the
  same file returns the same instance. The reason given is mapgen ordering:
  capital blueprints must name these nodes before grug_mapgen loads.
  Separately, `grug_jobs.register_station_operation` is defined only when
  `grug_professions` executes `grug_jobs/station_operations.lua`. The real
  owner of that API is "the first content catalog after Jobs and Quality".
- **Impact:** Load order is implicit and hidden. Renaming or splitting either
  file, or changing a mod.conf dependency, breaks registration in ways that are
  hard to trace. A new caller of `register_station_operation` that loads
  before grug_professions gets a nil call.
- **Better:** Move the five bench node definitions (and the brewing stand) into
  a low mod that already sits below mapgen (grug_nodes, or a small
  `grug_stations`), with grug_jobs only overriding behaviour, as it already
  does for the furnace and the dual furnace. grug_jobs should load
  `station_operations.lua` itself and depend on grug_quality, or grug_quality
  should own operations. Effort M. Risk: the mapgen content ID authentication
  (R7) checks registered node names, so run the seed fleet quick run if any
  name moves.
- **Verification (phase 2):** Confirmed — grug_brewing (`mod.conf` depends = default, vessels) dofiles `grug_jobs/station_nodes.lua` and calls `register_nodes()` (`node.lua:4-5`), with the shared-instance handshake at `station_nodes.lua:1-4`, `:250`; `grug_jobs.register_station_operation` is defined only in `grug_jobs/station_operations.lua:9`, which only `grug_professions/init.lua:73` executes (`grug_jobs/init.lua` never loads it). Its only callers today are in `grug_professions/enchants.lua`, so there is no current nil call.

### ITM-07 Vendor Weak Healing Potion copies the alchemy potion logic
- **Severity** Low / **Category** Duplication / **Confidence** Verified
- **Location:** `mods/ENTITIES/grug_traders/potion.lua:72-120`; `mods/ITEMS/grug_alchemy/effects.lua:21-63`
- **What:** Two implementations of "drink an instant potion". The vendor potion
  sends refusals with `core.chat_send_player`, which breaks the AGENTS.md
  rule that personal notices go to the feed. It checks full health through
  `get_properties().hp_max`, has no `can_use_item_level` gate, and repeats
  the trinket scaling.
- **Impact:** The two potions behave differently, for example chat versus
  feed. A future change to potion rules lands in only one of them.
- **Better:** Move `potion_use` (and the cooldown) into one shared helper.
  grug_traders already owns the cooldown, and grug_alchemy depends on
  grug_traders. Register the Weak Healing Potion with it. Effort S.

### ITM-08 Nine "derived consumer" meta keys are written on every tooltip rebuild and never read
- **Severity** Low / **Category** Legacy / **Confidence** Verified (grep over `mods/` and `tools/`)
- **Location:** `mods/ITEMS/grug_quality/init.lua:19-22`, `:158-175`, `:330-341`, called from `:510`, `:572`, `:822`
- **What:** `write_derived` clears nine `_grug_<stat>` keys and writes the
  non-zero ones on every `regenerate_description`, every `store_affixes` and
  every `crafted_output`. No code or fixture reads them: consumers use
  `read_affixes` and `get_affixes`.
- **Impact:** Meta writes on every rebuild (including every hit, see ITM-01),
  larger item strings, and a header comment that describes consumers that do
  not exist.
- **Better:** Keep the totals computation (`apply_capabilities` needs
  `attack_speed_percent`) and drop the meta writes and the header paragraph.
  Effort S.

### ITM-09 Dead data and dead overrides
- **Severity** Low / **Category** Legacy / **Confidence** Verified (grep over `mods/`)
- **Location:** `grug_cooking/init.lua:255-262` (`REFINEMENTS`, no consumer); `grug_fishing/init.lua:108`, `:126` (`on_use = core.item_eat(...)`, replaced by `on_use = false` in `grug_food/init.lua:487`); `grug_materials/tools.lua:75-96` (axe and shovel `uses`); `grug_materials/overrides.lua:76-84` (edits the groups of `default:steelblock`, `copperblock`, `tinblock`, `bronzeblock`, which `content_curation.lua` unregisters afterwards)
- **Impact:** These look authoritative to the next agent, and none of them has
  any effect.
- **Better:** Delete them. Effort S.

### ITM-10 Placing a slab on a slab uses up the item even when the placement fails
- **Severity** Low / **Category** Bug / **Confidence** Verified
- **Location:** `mods/ITEMS/grug_decor/shapes.lua:184-188`; `mods/ITEMS/grug_materials/derivatives.lua:37-42` (upstream origin: `mods/BASE/stairs/init.lua:199-202`)
- **What:** `core.item_place_node(...)` is called, and then `itemstack:take_item()`
  runs unconditionally. When the target is protected or occupied, the
  placement fails and one slab is lost. Current MTG checks the second return
  value.
- **Impact:** One slab is lost per refused click in towns and claims.
- **Better:** `local _, placed = core.item_place_node(...)`, and take the item
  only if `placed`. Effort S. The vendored copy carries the same bug; patch it
  with a `GRUG PATCH` marker or leave it, since only the grug copies are used
  for our materials.

### ITM-11 Gathering catalog: hand-kept manifest digest, plus source-file digests nothing checks
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
- **Location:** `mods/ITEMS/grug_gathering/catalog.lua:4-11`; `init.lua:32-35`; consumer `mods/MAPGEN/grug_mapgen/wp40/r7_p9g.lua:103-111`
- **What:** Any edit to a catalog row changes `canonical_bytes`. The boot then
  fails with "catalog manifest digest differs" until `EXPECTED_MANIFEST_SHA256`
  is recomputed by hand. `NODE_SOURCE_SHA256` and `HARVEST_SOURCE_SHA256` claim
  to pin `nodes.lua` and `harvest.lua`. They match today, but nothing compares
  them with the files, so they go stale silently on the next edit.
- **Impact:** Friction on a simple data change, and a false sense that the
  harvest code is pinned.
- **Better:** Either drop the two unverified source digests from the
  manifest, or verify them in a fixture. Document the recompute step (or add a
  `--print-digest` helper) next to the constant. Effort S. Check the mapgen R7
  contract first, because the manifest bytes are part of its identity.

### ITM-12 grug_artisans repeats grug_professions' helpers and audit
- **Severity** Low / **Category** Duplication / **Confidence** Verified
- **Location:** `mods/ITEMS/grug_artisans/init.lua:10-75`; `mods/ITEMS/grug_professions/init.lua:24-49`, `:93-113`; `grid()` copied in `grug_cooking/init.lua:144-158`, `grug_professions/tailor.lua:5-14`, `grug_artisans/goldsmith.lua:5-14`; the six-metal list in `grug_professions/smiths.lua:5`, `enchants.lua:3`, `tailor.lua:105`, `grug_artisans/enchants.lua:6`
- **What:** `register_item`, `register_ingredient`, `register_recipe` and the
  `on_mods_loaded` input audit are copied. Their semantics differ: artisans
  raise an error on a duplicate item, professions silently skip it.
- **Better:** Let grug_artisans use `grug_professions.register_*` (it already
  depends on grug_professions), with `CATALOGS` keyed by profession. Take the
  metal list from `grug_materials.TIERS`. Effort S.

### ITM-13 Armour totals are read through the tooltip builder
- **Severity** Low / **Category** Perf / **Confidence** Verified
- **Location:** `PLAYER/grug_inventory/equipment.lua:542-566` (`compute_equipped_armor`); `mods/ITEMS/grug_quality/init.lua:1008-1017` (`get_equipment_armor_rating_bonus`, called by `raw_armor` on every armour read); `grug_gear/init.lua:300-392`
- **What:** To get one number, both call `grug_gear.describe_stack_base`, which
  also formats coloured tooltip lines. The shield bonus is not cached at all,
  so it runs on every incoming hit.
- **Impact:** A small cost per hit, which ITM-01's cache invalidation makes
  four or five times larger.
- **Better:** Split a pure `grug_gear.base_stats(def, ilvl)` (damage, armour,
  mana) out of `describe_stack_base`, and cache the shield rating with
  `armor_cache`. Effort S.

### ITM-14 Every node dug with a tool rebuilds the tool's whole tooltip
- **Severity** Low / **Category** Perf / **Confidence** Verified (cost estimated)
- **Location:** `mods/ITEMS/grug_repair/runtime.lua:190-209`; `presentation.lua:80-92`
- **What:** The `after_use` override for every eligible tool calls
  `refresh_stack` on each dig. That is the same three-layer rebuild as in
  ITM-01, but without the equipment fan-out, because tools sit in main.
- **Impact:** Tens of µs per dug node per mining player. Acceptable, but
  avoidable. The same fix as ITM-01(b) applies.
- **Better:** Rewrite only the durability line, and do a full refresh only on
  break. Effort S (shares code with ITM-01).

### ITM-15 Crafted and rolled equipment and tools store a `tool_capabilities` snapshot in their meta
- **Severity** Low / **Category** Agent-trap / **Confidence** Verified
- **Location:** `mods/ITEMS/grug_quality/init.lua:517-543` (`apply_capabilities`), `:814-829` (`crafted_output`, which reaches picks, axes, shovels and hoes through grug_jobs' `final_grid_craft`)
- **What:** Every station-crafted or Basics-crafted item with a recognised
  family, and every rolled or upgraded item, gets
  `meta:set_tool_capabilities(copy of def caps ± ilvl damage ± speed enchant)`.
  Armour gets one too, although its capabilities are inert.
- **Impact:** After a code change that retunes dig times, `full_punch_interval`
  or damage, existing stacks in a test world keep the old values. The
  playtest then contradicts the code. Larger item strings.
- **Better:** Write meta caps only when they differ from the definition (weapons
  with a changed ilvl or a speed enchant). Note the behaviour in the module
  guide. Effort S.

### ITM-16 Two fuel systems
- **Severity** Low / **Category** Duplication / **Confidence** Verified
- **Location:** `PLAYER/grug_jobs/automatic.lua:10-25` (`FURNACE_FUELS`: coal 80 s, charcoal 80 s, any `group:tree` 15 s, nothing else); `mods/ITEMS/grug_smelting/recipes.lua:41-52` (charcoal item and recipe, no `type = "fuel"` craft)
- **What:** Furnaces and the dual furnace accept only their own table.
  The brewing stand uses engine fuel recipes (default's coal at 40 s,
  planks, logs at 30 s), and there charcoal is not a fuel at all.
- **Impact:** Players see inconsistent rules, for example charcoal that does
  not fuel the brewing stand and planks that do not fuel a furnace. Two
  places to edit for a new fuel.
- **Better:** Decide on one fuel source of truth, either the engine fuel registry
  with our burn times or the table used by all stations (see the open question).
  Effort S.

## Hot-path inventory

| Path | Trigger and frequency | Cost class | Verdict |
|---|---|---|---|
| `grug_repair` `wear_stack` (`runtime.lua:33`) | every settled outgoing action and every non-lethal hit taken, per player | three tooltip rebuilds, about ten listener passes, cache rebuilds, one list resend (est. 0.1–0.3 ms) | **ITM-01** |
| Tool `after_use` override (`runtime.lua:190`) | every node dug with an eligible tool | full tooltip rebuild, two `to_string` calls | ITM-14 |
| `grug_materials` `node_dig` wrapper (`mining.lua:571`) | every node dig | O(1): group lookups, `tool_level_shortfall`, one `is_protected` for natural nodes | fine |
| `punch_hint_callback` (`mining.lua:540`) | every node punch (dig start) | rate-limited; `protection_hint` and a few lookups | fine |
| Harvest callbacks (XP, goldsmith bonus) | each dug ore or gem | O(1) | fine |
| `grug_items` `equipment_totals` (`grug_quality/init.lua:968`) | every attribute, crit, dodge or pool query | cached per player; a rebuild is O(equipment slots) with one ~1.2 µs deserialize per item | fine, but the cache is emptied per hit (ITM-01) |
| `raw_armor` → shield `describe_stack_base` | every armour read (per hit taken) | string formatting, uncached | ITM-13 |
| `roll_mob_gear` and kill-loot hook | per mob kill with a player tag | one PcgRandom, at most three stacks | fine |
| `register_on_craft` (grug_gear) → grug_jobs `crafted_output` | per craft | two tooltip rebuilds | fine (cold) |
| `register_on_item_pickup` (grug_gear) | per item pickup | O(1) for non-gear, one rebuild for gear | fine |
| `refresh_weapon_descriptions` (`grug_gear/init.lua:753`) | equipment change (not durability) and level change | O(all inventory slots), one rebuild per gear stack | fine (event) |
| Renewal globalstep (`grug_farming/init.lua:555`, `renewal.lua:337`) | 0.5 s tick; each player once per 5 s | bounded at 150k node visits per service; measured 53–440 µs per service, ticks up to 23 ms at 100 players (R32 perf review R10) | known (BACKLOG R10); see Noted for the sapling guard |
| Soil timer (`grug_farming/init.lua:85-105`) | per soil node every 60 s idle or 15 s under a growing crop, active blocks only | one `find_node_near` with r=3 (342 nodes) | fine after R30 (#15) |
| Crop timer (`:232-264`) | per growing crop every 200 s, only on wet soil | O(height) | fine |
| Sapling timers (grug_trees) | once per sapling after 300–1500 s | schematic placement; gravewood scans about 7×7×H nodes | fine |
| LBM `start_soil_timer` (run every load) | per soil node per block load | one `get_node_timer` and `is_started` | fine (known #15) |
| LBM `activate_crop_geometry` (run every load) | per crop root per block load | early return unless tall crop; no write when intact | fine (R30 #16) |
| Fishing globalstep (`grug_fishing/init.lua:236`) | 0.2 s scan over active casts | O(casts) | fine |
| Food hold (`grug_food/init.lua:382`) | per input step while eating | one `hud_change`, 10 particles per 0.2 s | fine (within the particle budget) |
| Deepwater elixir tick (`grug_alchemy/effects.lua:139-147`) | 1 s per player with the elixir | `get_properties()` | fine |
| Station timers (grug_jobs, out of scope) | 1 s while a furnace or brewing stand runs | serialize/deserialize state, `advance` | fine |
| Boot audits (dig matrix, smelting, professions, enchant data, farming `non_natural`) | once at load | O(items × checks) | fine |

## Bug-prone areas

- **`grug_quality` load-time wrappers** (`grug_quality/init.lua:1019-1098`).
  The enchant cache is correct only while every equipment write calls
  `grug_inventory.equipment_changed` through the table. A module that keeps a
  local reference to the original, or writes a list without notifying, makes
  stats stale with no error.
- **Tooltip layering** (ITM-04): every tooltip change crosses three files.
- **Crops with helpers** (ITM-02). Also, `transition_crop` records protection
  violations with the planter's name from a timer.
- **Custom `on_place` items** (ITM-03): any new tool-like item with its own
  `on_place` repeats the missing `on_rightclick` forward.
- **Broken-state bookkeeping** (`grug_repair/presentation.lua:35-66`,
  `grug_quality/init.lua:426-453`, `:533-542`). Seven meta keys
  (`_grug_broken_base_*`, `_grug_broken_drawn_*`, `_grug_repair_caps`) are kept
  in sync between enchanting, repair and the enchant image. That works, but
  every new image or capabilities writer must follow the same protocol.
- **grug_gathering and grug_materials frozen-contract artefacts** (ITM-11 and
  the `validate_registry` counts, for example "expected twelve processed material
  rows"): a data edit trips a hard boot error far from the edited line.
- **Station factory singleton** (ITM-06).

## Noted (no action)

- **Renewal sapling guard** (`renewal.lua:263-268`). The guard queries a 21³ box
  against `api.non_natural`, about 766 node names (engine logs in
  `tools/r26_capitals/results/engine-seed42/server.log:64`). The engine resolves
  the names per call and does a linear `std::find` over the ID list for every
  visited node (`l_env.cpp:749-760`, `:821-880`). That is roughly 9,261 × 766
  comparisons per guard, about 1 ms. It adds to the R10 bursts, which are
  already in BACKLOG. If R10 is worked on, a guard against a short list of
  natural IDs in a VoxelManip read would remove it.
- A crop growth retry under changed protection flashes "Protected" to the
  planter wherever they are (`grug_farming/init.lua:198-202`, `:249-255`).
  Rare edge case.
- The fishing rod lasts 65 catches, not 64: `add_wear` clears the stack only
  when the next step passes 65535 (`grug_fishing/init.lua:48-49`).
- `hoe_on_use` starts the soil timer twice (on_construct and an explicit
  call; `hoes.lua:39-40`). This is harmless.
- `grug_items.mastery_band` (`grug_quality/init.lua:804-810`) is based on the
  character level, not a profession mastery. Only the goldsmith gem bonus
  uses it. The name could mislead.
- `grug_gathering/harvest.lua` `VALID_HERBS` lists `grug_cooking:ember_moss`,
  which is never a P9G healing-herb source. That entry is unreachable.
- The base of the vendor potion and the default stairs slab bug live in
  vendored or ENTITIES code; see ITM-07 and ITM-10.

## Open questions for Jan

1. **Durability display (ITM-01):** Must the "Durability: N / M" tooltip line
   change with every single hit and use? Or is it enough to update it every 1 %,
   on break and repair, and when the inventory opens? The answer decides how
   cheap the fix can be.
2. **Fuels (ITM-16):** Is it intended that furnaces burn only coal, charcoal
   and logs (with their own times) while the brewing stand uses the engine
   fuels (planks yes, charcoal no)?
3. **Crops (ITM-02):** Should crops stay `buildable_to` and floodable, which is
   MTG behaviour where a block or water silently destroys the plant? Or should
   placing onto a crop be refused?
4. **Fishing rod:** All other gear breaks and is then repaired, but the rod
   breaks and disappears. Is that intended?
