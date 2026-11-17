# DT1 — Module guide and mod map against the code

- Finder model: claude-opus-5-5
- Files read in full: 4 of 10 (`module-guide.md`, `mod-map.md`, `modules/expeditions.md`, `modules/platform.md`); skimmed: `modules/combat-classes.md` (lines 10-801 read, sampled), `modules/mobs.md` (20-522 read, sampled), `modules/player-systems.md` (20-701 read, sampled), `modules/items-professions.md` (10-130, 140-793 read, sampled), `modules/ui-looks.md` (10-385, 450-589 read; 386-449 partly), `modules/mapgen.md` (1-300, 330-480, 530-637 read; 300-330 and 480-530 skimmed); not reached: none
- Summary: The ten documents are in very good shape. A mechanical pass over every backticked identifier (about 6,300, list per document below), every qualified `grug_x.y` name, every `name(` call form, every linked file and anchor, every named path and every mod.conf found almost nothing missing. Every mod under `mods/` is in the mod map, every mod the map lists exists, and every seam in its "Seams" column exists under that mod's global. Every Rules block was checked against the code. Every constant quoted with its value (`NAME` (n) / `NAME` = n, 25 of them) matches the code except the ones below. The one stale section that matters is mapgen.md's "R7.6 difficulty seam": it describes `difficulty_for_macro_at` and `difficulty_lattice_digest()`, both removed in Round 22. The other findings are a stale fee (14 700 vs 14 800), a stale reach (80 vs 103), a few renamed functions, two inaccurate lists in the mod map and one central seam (`grug_inventory`'s give/pickup/sort/bags/trash) that has no implementation section.

## Findings

### DT1-01 | Medium | docs | mapgen.md "R7.6 difficulty seam" describes functions removed in Round 22

- **Where:** `docs/technical/modules/mapgen.md:332-345`; `docs/technical/modules/mapgen.md:291-292`
- **What:** The section says `difficulty_for_macro_at` (in `simple_map.lua`) and the "compatibility method" `difficulty_lattice_digest()` are live, and :291-292 says "the difficulty field survives only inside WP40's own compatibility layer". Neither function exists. The word `difficulty` no longer occurs anywhere under `mods/MAPGEN` or `mods/CORE`. The level staircase now lives in `wp40/zones.lua`: `level_thirds` :711, `start_band_level_at` :660, `START_LEVEL_CORE_RADIUS = 100` and `START_LEVEL_BAND_RADIUS = 150` at :640-641, `session.zone_level_at`. `simple_map.lua` adds its own `zone_level_at` (:475 and :895).
- **Evidence:** `rg -n 'difficulty_lattice_digest|difficulty_for_macro_at' -g '!docs/**' .` returns no hit. `rg -c difficulty mods/MAPGEN mods/CORE` returns no hit. `git log -S difficulty_for_macro_at -- mods` shows `651e45e22` (Round 22 Phase 3 lane A) as the last commit that touched the name; that commit removed it.
- **Proposal:** Rewrite the section against `zones.lua` (`level_thirds`, the start-band override, `session.zone_level_at`) or delete it. Drop the "survives only inside the compatibility layer" clause at :291-292.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-02 | Medium | docs | grug_inventory's item flow (give order, pickup, sort, bags, potion belt, inbox, Trash) has no implementation section

- **Where:** `docs/technical/modules/*.md` (no section); `mods/PLAYER/grug_inventory/storage.lua` (548 lines), `bags.lua` (514), `trash.lua` (195), `inbox.lua` (90)
- **What:** The mod map calls `grug_inventory.give` "every item source" and lists `fits`, `room_for`, `sort`, `slot_order`, `carried_lists`, `consume_lists`, `INBOX_LIST`, `POTION_BELT` and the `trash_*` seams. No module-guide file has a section on them. `storage.lua`, `inbox.lua` and `trash.lua` are never named under `docs/technical/modules/`, and `grug_inventory.give` appears once, in passing. Every other seam of that size (the equipment seam, hotbars, the jobs) has its own section with rules and fixtures.
- **Evidence:** `rg -c -F 'storage.lua' docs/technical/modules/` returns 0, as do `inbox.lua` and `trash.lua`. `rg -c 'grug_inventory.give' docs/technical/modules/` returns 1.
- **Proposal:** Add an "Inventory and item flow" section to `player-systems.md` or `ui-looks.md`. It should cover the give order and its fallbacks, pickup and dug drops, the sort, the bag sizes (with the existing platform rule "a bag's size only grows at a join"), the inbox, the potion belt and the Trash undo, and name the rules other mods must follow: every item source goes through `give`, and `consume_lists` has the inactive layout last.
- **Effort:** M · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** medium

### DT1-03 | Low | docs | items-professions.md gives the Crownbinder fee as 14 700c; the code has 14 800

- **Where:** `docs/technical/modules/items-professions.md:663-664`; `mods/ENTITIES/grug_traders/crown.lua:12`
- **What:** `grug_traders.CROWN_FEE = 14800`, but the doc says "(14 700c, checked by `income.py --check`)". Commit `8f4d56384` ("Prices after the main questline's quest income … the crown fee 14800") changed the code and not the doc.
- **Evidence:** `crown.lua:12` reads `grug_traders.CROWN_FEE = 14800`. `git log -L12,12:mods/ENTITIES/grug_traders/crown.lua`.
- **Proposal:** Write 14 800c, or name only the constant.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-04 | Low | docs | ui-looks.md gives the start-town reach `D.town_reach` as 80; the code has 103

- **Where:** `docs/technical/modules/ui-looks.md:523-524`; `mods/CORE/grug_ambience/data.lua:81-92`
- **What:** `D.town_reach = 103` ("the footprint's farthest corner … about 102.5 nodes"), set by `68aff3443` ("Ambience 0.52.1 delta review G1: the start-town reach covers the footprint's corners (103)"). The doc still says "within `D.town_reach` 80".
- **Evidence:** `data.lua:92`.
- **Proposal:** Write 103 and give the reason (it covers the footprint's corners).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-05 | Low | docs | combat-classes.md names `grug_abilities.description_for` and `def.values(user)`; the code has a per-definition `description_for` and `update_stack_description`

- **Where:** `docs/technical/modules/combat-classes.md:411-414`; `mods/PLAYER/grug_abilities/init.lua:1180-1234`, `:2363-2369`
- **What:** The doc says `grug_abilities.description_for` writes the effective values to the stack, and that registrations expose `def.values(user)`. There is no `grug_abilities.description_for`:
  - The writer is `grug_abilities.update_stack_description(stack, def, player)`, driven by `sync_descriptions`.
  - The text comes from an optional per-definition `def.description_for(player, def)` (`kits_warrior.lua:62`).
  - `def.values` takes `(player, def)` (`scout.lua:300`).
- **Evidence:** `rg -n 'grug_abilities\.description_for' mods` returns no hit. `init.lua:1216` reads `return def.description_for and def.description_for(player, def)`.
- **Proposal:** Name `def.description_for(player, def)`, `def.values(player, def)` and `grug_abilities.update_stack_description`.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-06 | Low | docs | ui-looks.md names `automatic_take_sound` for furnace and brewing-stand takes; the code has `grug_jobs.furnace_take_sound`, for furnace dishes only

- **Where:** `docs/technical/modules/ui-looks.md:412-414`; `mods/PLAYER/grug_jobs/state.lua:196-211`, `mods/PLAYER/grug_jobs/workspaces.lua:249`
- **What:** No `automatic_take_sound` exists. `grug_jobs.furnace_take_sound(stack)` returns `"craft_cooking"` only for a dish that a raw assembly cooks into, and nil otherwise; its comment says "smelting and the plain refinements stay silent". Nothing in `grug_brewing` plays a take sound.
- **Evidence:** `rg -n automatic_take_sound mods` returns no hit. `rg -n 'take_sound|sounds.play' mods/ITEMS/grug_brewing` returns no hit.
- **Proposal:** Replace with "`grug_jobs.furnace_take_sound` for a cooked dish taken from a furnace".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-07 | Low | docs | mapgen.md says its zone-query list is "the whole grug_core surface, not a sample", but the list omits five published functions

- **Where:** `docs/technical/modules/mapgen.md:284-291`; `mods/CORE/grug_core/zone_authority.lua`
- **What:** `zone_authority.lua` also publishes these gameplay functions, which the list leaves out:
  - `grug_core.surface_mob_level_at`
  - `world_feature_at`
  - `world_feature_boxes_in`
  - `zone_protected_for_faction`
  - `register_level_overlay`

  It also publishes the install helpers `install_zone_authority`, `prepare_zone_authority` and `zone_authority_installed`.
- **Evidence:** `rg -o 'grug_core\.[a-z_]+'` on the definition sites in `zone_authority.lua`.
- **Proposal:** Add the five gameplay functions to the list, or drop "not a sample".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-08 | Low | docs | mod-map.md "understates coupling" list: `grug_money` does not call `grug_inventory.give`, but `grug_core` does

- **Where:** `docs/technical/mod-map.md:105-113`; `mods/PLAYER/grug_money/coins.lua:80-91`; `mods/CORE/grug_core/migrations.lua:56`
- **What:** The trap lists `grug_money` among the lower mods that call `grug_inventory.give` at run time. `grug_money` calls `grug_inventory.slot_order` (coins.lua:91) and never `give`. The list leaves out `grug_core`, the lowest mod that does call `give` (`migrations.lua:56`, the 0.45.0 character step); `grug_core` does not declare `grug_inventory` either.
- **Evidence:** `rg -l 'grug_inventory\.give\b' mods` returns no file under `grug_money`, and a hit in `mods/CORE/grug_core/migrations.lua`.
- **Proposal:** Replace `grug_money` with `grug_core` in the list, and note that `grug_money` reads `slot_order`.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-09 | Low | docs | mod-map.md's load-order sentence and its "understates coupling" trap contradict each other about grug_mobs and grug_inventory

- **Where:** `docs/technical/mod-map.md:7-10` and `:107-109`
- **What:** The header gives the order "… → `grug_classes`, `grug_visuals`, `grug_inventory` → `grug_mobs` → feature mods" and says it "follows the declared dependencies". The trap says `grug_mobs` is one of the mods "that load before" `grug_inventory`. The declarations decide neither: `grug_mobs`' `mod.conf` names neither `grug_inventory` nor `grug_classes`, only `grug_visuals` as optional, and `grug_inventory`'s names no `grug_mobs`. So the engine's order between them is unspecified. The header is also off for CORE: `grug_ambience` depends on `grug_map`, so that CORE mod loads after a PLAYER feature mod.
- **Evidence:** `mods/ENTITIES/grug_mobs/mod.conf`, `mods/PLAYER/grug_inventory/mod.conf`, `mods/CORE/grug_ambience/mod.conf`.
- **Proposal:** Say in the header that it is a partial order. In the trap, say "mods that do not depend on it" instead of "load before it".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-10 | Low | docs | ui-looks.md says the achievements catalogue holds 21 achievements; it holds 22

- **Where:** `docs/technical/modules/ui-looks.md:337`; `mods/PLAYER/grug_achievements/catalog.lua:181-…`
- **What:** The `achievements` table has 22 rows: hunter … last_claim_denied, then `supporter` and `miners_guild`. The Miner's Guild series was added in Round 58 (`0e2c40483`) and the count was not updated.
- **Evidence:** `sed -n '181,$p' catalog.lua | rg -c '^\s*\{\s*id\s*='` returns 22.
- **Proposal:** Write 22, or drop the number.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-11 | Low | docs | mobs.md cites stale `mobs/api.lua` line ranges

- **Where:** `docs/technical/modules/mobs.md:24`, `:134`; `mods/ENTITIES/mobs/api.lua:1800`, `:4120-4131`
- **What:** Both cited line ranges have drifted:
  - `general_attack()` is cited as `api.lua:1853-2017`; it now starts at :1800.
  - The `register_mob` def-field whitelist is cited as `api.lua:3956-4112`; `mobs:register_mob` now starts at :4120, and its `core.register_entity` table at :4131.

  The `GRUG PATCH` count at :232-233 ("122 counted 2026-10-04") is dated. The file now has 154 occurrences, which is acceptable for a dated figure.
- **Evidence:** `rg -n 'function mob_class:general_attack|^function mobs:register_mob' mods/ENTITIES/mobs/api.lua`.
- **Proposal:** Cite function names instead of line numbers, because line numbers drift with every patch.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-12 | Low | docs | Small naming slips, one line each

- **Where / What:**
  - `docs/technical/mod-map.md:35` calls `talent_graph_ui.lua` "the Talents & Skills page". The page is `grug_classes/talents_ui.lua` (header: "The sfinv Talents & Skills page …"); `talent_graph_ui.lua` draws the graph content into it (`graph.page_content`).
  - `docs/technical/modules/combat-classes.md:423` calls `grug_core.status` the registry. No such table exists; the registry is `grug_core/status.lua` (`set_status`, `clear_status`, `get_status`, `status_modifier_sum` …).
  - `docs/technical/modules/player-systems.md:90` calls it `Q.reward_stacks`. It is a local function `reward_stacks` (`grug_quests/state.lua:513`), not part of the `Q` surface.
  - `docs/technical/mod-map.md:52`: the grug_expeditions seam list names `register_on_ready/_end/_enter/_leave` but leaves out `register_on_close` (init.lua header :104-106), which `player-systems.md:477` names as a seam `grug_expeditions` uses.
- **Evidence:** the cited lines.
- **Proposal:** Correct the four names.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

## Backlog notes

- `docs/technical/modules/expeditions.md:47` says "every player teleport ends in `travel.lua`". The arrival teleport and the map-reset relocation (`grug_classes/selection.lua:476`, `:574`) and grug_factions' respawn fallback (`grug_factions/init.lua:313`, `:343`, reached only when `grug_home.respawn` has no home row) set the position directly. No path today leads into an Expedition box, so it is harmless. The player-systems Travel rule (:456) names only home return, respawn and waystones, and the respawn fallback is the one exception to it.
- The grug_factions respawn fallback calls `player:set_pos(spawn)` and then `teleport_to_spawn` (another `set_pos` after the emerge): `grug_factions/init.lua:342-344`. Taste-level.
- `grug_mobs.settle_mob_death` is defined in `grug_mobs/init.lua:300` and wrapped again in `spawn_regions.lua:1259-1272` (leader timers). `expeditions.md:115` and `mobs.md:455` name only the init.lua one; the wrapper is correct but undocumented.

## Good to know

- Identifiers checked per document. Each backticked token of 4 or more characters was checked against the code's word set; qualified `grug_x.y` names were checked against the definitions, and `name(` call forms against the function and field definitions:

  | Document | Identifiers checked |
  |---|---|
  | `mod-map.md` | 761 (plus every Seams cell against `<global>.<name>`, and all 54 `mod.conf` files) |
  | `module-guide.md` | 1 (plus 54 anchors and 39 stubs against the module headings) |
  | `combat-classes.md` | 859 |
  | `expeditions.md` | 260 |
  | `items-professions.md` | 1,000 |
  | `mapgen.md` | 612 |
  | `mobs.md` | 632 |
  | `platform.md` | 543 |
  | `player-systems.md` | 883 |
  | `ui-looks.md` | 783 |

  The only identifiers that did not resolve are the ones in the findings above, plus deliberate history (removed WP18 files, retired keys, reference-project names, engine C++ symbols). Every `tools/…` path named exists except `tools/wp39/`, which is documented as retired.
- Every relative link and `#anchor` in the eleven files resolves.
- Every Rules block was checked: the quoted seams exist, and the rules match the code. `grug_sounds` is the one play path; the five direct `core.sound_play` calls are the accepted set in `docs/design/sound.md:50-58`. `placement_refused` is asked by doors, beds, the bucket, the notice board and the Claim Stone. Expedition paths never call `core.find_path`. Expedition meta is limited to the three listed keys. The money meta key is read only inside `grug_money`.
- A reliable way to find stale names in these docs: list the functions removed from `mods/` in recent history (`git log -p` for removed `function` lines, minus the names the code still has), then search the docs for them. It took seconds and found DT1-01 and DT1-06.
