# DT1 — Module guide and mod map against the code (verified)

- Finder model: claude-opus-5-5
- Verifier model: claude-opus-5-5
- Files read in full: 4 of 10 (`module-guide.md`, `mod-map.md`, `modules/expeditions.md`, `modules/platform.md`); skimmed: `modules/combat-classes.md` (lines 10-801 read, sampled), `modules/mobs.md` (20-522 read, sampled), `modules/player-systems.md` (20-701 read, sampled), `modules/items-professions.md` (10-130, 140-793 read, sampled), `modules/ui-looks.md` (10-385, 450-589 read; 386-449 partly), `modules/mapgen.md` (1-300, 330-480, 530-637 read; 300-330 and 480-530 skimmed); not reached: none
- Summary: The ten documents are in very good shape. A mechanical pass over every backticked identifier (about 6,300, list per document below), every qualified `grug_x.y` name, every `name(` call form, every linked file and anchor, every named path and every mod.conf found almost nothing missing. Every mod under `mods/` is in the mod map, every mod the map lists exists, and every seam in its "Seams" column exists under that mod's global. Every Rules block was checked against the code. Every constant quoted with its value (`NAME` (n) / `NAME` = n, 25 of them) matches the code except the ones below. The one stale section that matters is mapgen.md's "R7.6 difficulty seam": it describes `difficulty_for_macro_at` and `difficulty_lattice_digest()`, both removed in Round 22. The other findings are a stale fee (14 700 vs 14 800), a stale reach (80 vs 103), a few renamed functions, two inaccurate lists in the mod map and one central seam (`grug_inventory`'s give/pickup/sort/bags/trash) that has no implementation section.
- Verifier note: every finding was checked, the Low ones included (one search each). For each, the document is the wrong side; the code is right. Both Medium findings are corrected to Low: DT1-01's section is right in substance and wrong only in names, and DT1-02's rules are already written down in `docs/design/inventory_equipment.md`. One of DT1-12's four slips does not hold.

## Findings

### DT1-01 | Low | docs | mapgen.md "R7.6 difficulty seam" names functions removed in Round 22; the mechanism it describes still exists under another name

- **Verdict:** CORRECTED — The names are stale, as claimed. `rg 'difficulty_lattice_digest|difficulty_for_macro_at' -g '!docs/**'` finds nothing, `rg -c difficulty mods/MAPGEN mods/CORE` finds nothing, and `git log -S difficulty_for_macro_at -- mods` ends at `651e45e22`. The doc is wrong, but only in its names: the mechanism the section describes still lives in `simple_map.lua`, not in `zones.lua` as the finder's proposal says. `band_ranges` (`simple_map.lua:217-232`) splits each zone range into integer thirds along z from the home-facing side. `zone_level_at` (`:475-489`, published as `session.zone_level_at` `:895`) serves the staircase, with the summits flat. `zones.lua:678-685` (`zone_field_level`) then applies the start-band override (`start_band_level_at`, `:640-641, 660`). `level_thirds` (`zones.lua:711`) is the start-zone gradient, a different thing. What is really false: the digest method and the claim at `mapgen.md:291-292` that "the difficulty field survives only inside WP40's own compatibility layer". A section that is right in substance and has two stale names is a small cleanup, so Low.
- **Where:** `docs/technical/modules/mapgen.md:332-345`; `docs/technical/modules/mapgen.md:291-292`
- **What:** The section says `difficulty_for_macro_at` (in `simple_map.lua`) and the "compatibility method" `difficulty_lattice_digest()` are live, and :291-292 says "the difficulty field survives only inside WP40's own compatibility layer". Neither function exists. The word `difficulty` no longer occurs anywhere under `mods/MAPGEN` or `mods/CORE`. The staircase is now `simple_map.lua`'s `band_ranges` and `zone_level_at` (`session.zone_level_at`). `zones.lua` applies the start band afterwards (`zone_field_level`, `start_band_level_at`, `START_LEVEL_CORE_RADIUS = 100` and `START_LEVEL_BAND_RADIUS = 150` at :640-641).
- **Evidence:** `rg -n 'difficulty_lattice_digest|difficulty_for_macro_at' -g '!docs/**' .` returns no hit. `rg -c difficulty mods/MAPGEN mods/CORE` returns no hit. `git log -S difficulty_for_macro_at -- mods` shows `651e45e22` (Round 22 Phase 3 lane A) as the last commit that touched the name; that commit removed it.
- **Proposal:** In the section, replace `difficulty_for_macro_at` with `zone_level_at` (`band_ranges`, `session.zone_level_at`), delete the `difficulty_lattice_digest()` sentence, and rename the heading to "The zone level staircase". Drop the "survives only inside the compatibility layer" clause at :291-292.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-02 | Low | docs | grug_inventory's item flow (give order, pickup, sort, bags, potion belt, inbox, Trash) has no implementation section

- **Verdict:** CORRECTED — Under `docs/technical/modules/` the claim holds: `storage.lua`, `bags.lua`, `inbox.lua` and `trash.lua` are never named there, and no heading covers the item flow. The rules are not undocumented, though. `docs/design/inventory_equipment.md:623-630` states the give order and the "every item source goes through `grug_inventory.give`" rule. `:105-113` covers the Trash box (naming `trash.lua`), and the inbox and potion belt are in the same file. The mod map row (`mod-map.md:38`) names the files and seams and links that design doc. `ui-looks.md:42` states the `consume_lists` "inactive layout last" rule. What is missing is a short technical section, or a pointer to those parts of the design doc. That is a small cleanup, so Low rather than Medium.
- **Where:** `docs/technical/modules/*.md` (no section); `mods/PLAYER/grug_inventory/storage.lua` (548 lines), `bags.lua` (514), `trash.lua` (195), `inbox.lua` (90); rules in `docs/design/inventory_equipment.md:105-113, 623-630`
- **What:** The mod map calls `grug_inventory.give` "every item source" and lists `fits`, `room_for`, `sort`, `slot_order`, `carried_lists`, `consume_lists`, `INBOX_LIST`, `POTION_BELT` and the `trash_*` seams. No module-guide file has a section on them, and `storage.lua`, `inbox.lua` and `trash.lua` are never named under `docs/technical/modules/`. The player-facing rules are in the design doc.
- **Evidence:** `rg -c -F 'storage.lua' docs/technical/modules/` returns 0, as do `inbox.lua`, `trash.lua` and `bags.lua`. `rg -n 'give order' docs/design/inventory_equipment.md` finds the rule at :623.
- **Proposal:** Add a short "Inventory and item flow" section to `player-systems.md` or `ui-looks.md`. It should name the files (`storage.lua`, `bags.lua`, `inbox.lua`, `trash.lua`), the seams other mods must use (every item source through `give`; `fits` before an all-or-nothing give; `consume_lists` with the inactive layout last), and the fixtures, and link `inventory_equipment.md` for the rules instead of restating them.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-03 | Low | docs | items-professions.md gives the Crownbinder fee as 14 700c; the code has 14 800

- **Verdict:** CONFIRMED — `items-professions.md:664` says "14 700c"; `crown.lua:12` reads `grug_traders.CROWN_FEE = 14800`. The doc is wrong.
- **Where:** `docs/technical/modules/items-professions.md:663-664`; `mods/ENTITIES/grug_traders/crown.lua:12`
- **What:** `grug_traders.CROWN_FEE = 14800`, but the doc says "(14 700c, checked by `income.py --check`)". Commit `8f4d56384` ("Prices after the main questline's quest income … the crown fee 14800") changed the code and not the doc.
- **Evidence:** `crown.lua:12` reads `grug_traders.CROWN_FEE = 14800`. `git log -L12,12:mods/ENTITIES/grug_traders/crown.lua`.
- **Proposal:** Write 14 800c, or name only the constant.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-04 | Low | docs | ui-looks.md gives the start-town reach `D.town_reach` as 80; the code has 103

- **Verdict:** CONFIRMED — `ui-looks.md:524` says "within `D.town_reach` 80"; `grug_ambience/data.lua:92` reads `D.town_reach = 103`. The doc is wrong.
- **Where:** `docs/technical/modules/ui-looks.md:523-524`; `mods/CORE/grug_ambience/data.lua:81-92`
- **What:** `D.town_reach = 103` ("the footprint's farthest corner … about 102.5 nodes"), set by `68aff3443` ("Ambience 0.52.1 delta review G1: the start-town reach covers the footprint's corners (103)"). The doc still says "within `D.town_reach` 80".
- **Evidence:** `data.lua:92`.
- **Proposal:** Write 103 and give the reason (it covers the footprint's corners).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-05 | Low | docs | combat-classes.md names a module function `grug_abilities.description_for`; the code has a per-definition `description_for` and `update_stack_description`

- **Verdict:** CORRECTED — The main claim holds: there is no `grug_abilities.description_for`. The text comes from the per-definition `def.description_for(player, def)` (`init.lua:1216`; `kits_warrior.lua:62, 155, 201`), and `grug_abilities.update_stack_description` (`init.lua:1224`) writes it. The doc is wrong there. The `def.values` part does not hold as stated: `def.values` is a per-kit convention, not an engine-side call. The warrior kit defines and calls it as `values(user)` (`kits_warrior.lua:56, 63, 156, 197, 202`), so the doc's `def.values(user)` matches that use. Only the scout's helper takes `(player, def)` (`scout.lua:293`).
- **Where:** `docs/technical/modules/combat-classes.md:411-414`; `mods/PLAYER/grug_abilities/init.lua:1180-1234`
- **What:** The doc says `grug_abilities.description_for` writes the effective values to the stack. The writer is `grug_abilities.update_stack_description(stack, def, player)`, driven by `sync_descriptions`. The text comes from an optional per-definition `def.description_for(player, def)`. `def.values` is a kit-internal helper whose signature varies by kit.
- **Evidence:** `rg -n 'grug_abilities\.description_for' mods` returns no hit. `init.lua:1216` reads `return def.description_for and def.description_for(player, def)`.
- **Proposal:** Name `def.description_for(player, def)` and `grug_abilities.update_stack_description`. Describe `def.values` as an optional kit helper that `description_for` reads, without fixing its signature.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-06 | Low | docs | ui-looks.md names `automatic_take_sound` for furnace and brewing-stand takes; the code has `grug_jobs.furnace_take_sound`, for furnace dishes only

- **Verdict:** CONFIRMED — `rg automatic_take_sound mods` finds nothing. `grug_jobs.furnace_take_sound` is at `state.lua:202`, called only from `workspaces.lua:249`, and `rg 'take_sound|sounds.play' mods/ITEMS/grug_brewing` finds nothing. The doc (`ui-looks.md:413-414`) is wrong.
- **Where:** `docs/technical/modules/ui-looks.md:412-414`; `mods/PLAYER/grug_jobs/state.lua:196-211`, `mods/PLAYER/grug_jobs/workspaces.lua:249`
- **What:** No `automatic_take_sound` exists. `grug_jobs.furnace_take_sound(stack)` returns `"craft_cooking"` only for a dish that a raw assembly cooks into, and nil otherwise; its comment says "smelting and the plain refinements stay silent". Nothing in `grug_brewing` plays a take sound.
- **Evidence:** `rg -n automatic_take_sound mods` returns no hit. `rg -n 'take_sound|sounds.play' mods/ITEMS/grug_brewing` returns no hit.
- **Proposal:** Replace with "`grug_jobs.furnace_take_sound` for a cooked dish taken from a furnace".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-07 | Low | docs | mapgen.md says its zone-query list is "the whole grug_core surface, not a sample", but the list omits five published functions

- **Verdict:** CONFIRMED — `rg -o '^\s*function grug_core\.[a-z_]+'` on `zone_authority.lua` lists 23 functions. Of these, `surface_mob_level_at`, `world_feature_at`, `world_feature_boxes_in`, `zone_protected_for_faction` and `register_level_overlay` (plus the three install helpers) are missing from the list at `mapgen.md:287-291`. The doc is wrong. (`surface_mob_level_at` appears in the next sentence, but only as a `grug_zones` method.)
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

- **Verdict:** CONFIRMED — `rg -l 'grug_inventory\.give\b' mods` lists `grug_core/migrations.lua` (`:56`, `hand_over`) and no `grug_money` file. `grug_money` reads only `grug_inventory.slot_order` (`coins.lua:91`). `grug_core/mod.conf` depends only on `grug_sounds`. The doc (`mod-map.md:107-109`) is wrong.
- **Where:** `docs/technical/mod-map.md:105-113`; `mods/PLAYER/grug_money/coins.lua:80-91`; `mods/CORE/grug_core/migrations.lua:56`
- **What:** The trap lists `grug_money` among the lower mods that call `grug_inventory.give` at run time. `grug_money` calls `grug_inventory.slot_order` (coins.lua:91) and never `give`. The list leaves out `grug_core`, the lowest mod that does call `give` (`migrations.lua:56`, the 0.45.0 character step); `grug_core` does not declare `grug_inventory` either.
- **Evidence:** `rg -l 'grug_inventory\.give\b' mods` returns no file under `grug_money`, and a hit in `mods/CORE/grug_core/migrations.lua`.
- **Proposal:** Replace `grug_money` with `grug_core` in the list, and note that `grug_money` reads `slot_order`.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-09 | Low | docs | mod-map.md's load-order sentence and its "understates coupling" trap contradict each other about grug_mobs and grug_inventory

- **Verdict:** CONFIRMED — `grug_mobs/mod.conf` depends on neither `grug_inventory` nor `grug_classes` (optional: `grug_visuals`, `grug_money`), and `grug_inventory/mod.conf` names no `grug_mobs`, so the order between them is not declared. `grug_ambience/mod.conf` depends on `grug_map`. The doc (`mod-map.md:7-10`, `:107-109`) is wrong.
- **Where:** `docs/technical/mod-map.md:7-10` and `:107-109`
- **What:** The header gives the order "… → `grug_classes`, `grug_visuals`, `grug_inventory` → `grug_mobs` → feature mods" and says it "follows the declared dependencies". The trap says `grug_mobs` is one of the mods "that load before" `grug_inventory`. The declarations decide neither: `grug_mobs`' `mod.conf` names neither `grug_inventory` nor `grug_classes`, only `grug_visuals` as optional, and `grug_inventory`'s names no `grug_mobs`. So the engine's order between them is unspecified. The header is also off for CORE: `grug_ambience` depends on `grug_map`, so that CORE mod loads after a PLAYER feature mod.
- **Evidence:** `mods/ENTITIES/grug_mobs/mod.conf`, `mods/PLAYER/grug_inventory/mod.conf`, `mods/CORE/grug_ambience/mod.conf`.
- **Proposal:** Say in the header that it is a partial order. In the trap, say "mods that do not depend on it" instead of "load before it".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-10 | Low | docs | ui-looks.md says the achievements catalogue holds 21 achievements; it holds 22

- **Verdict:** CONFIRMED — The `achievements = {` table (`catalog.lua:181`) closes after `miners_guild`, and `rg -c '^\s*\{\s*id\s*='` from there gives 22. The doc (`ui-looks.md:337`) says 21 and is wrong.
- **Where:** `docs/technical/modules/ui-looks.md:337`; `mods/PLAYER/grug_achievements/catalog.lua:181-…`
- **What:** The `achievements` table has 22 rows: hunter … last_claim_denied, then `supporter` and `miners_guild`. The Miner's Guild series was added in Round 58 (`0e2c40483`) and the count was not updated.
- **Evidence:** `sed -n '181,$p' catalog.lua | rg -c '^\s*\{\s*id\s*='` returns 22.
- **Proposal:** Write 22, or drop the number.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT1-11 | Low | docs | mobs.md cites stale `mobs/api.lua` line ranges

- **Verdict:** CONFIRMED — `mobs.md:24` cites `api.lua:1853-2017` and `:134` cites `api.lua:3956-4112`. `general_attack` now starts at `api.lua:1800` and `mobs:register_mob` at `:4120`. The doc is wrong.
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

- **Verdict:** CORRECTED — Three of the four slips hold, and the doc is wrong in each. (1) `grug_classes/talents_ui.lua:1` is "The sfinv Talents & Skills page". (2) No `grug_core.status` table is defined anywhere in `mods/`. (4) `grug_expeditions/init.lua:105` documents `register_on_close` (implemented in `runs.lua:30`), and the mod-map row omits it. The third slip does not hold: `Q.reward_stacks` is published, `grug_quests/state.lua:530` reads `Q.reward_stacks = reward_stacks`, so `player-systems.md:90` is right.
- **Where / What:**
  - `docs/technical/mod-map.md:35` calls `talent_graph_ui.lua` "the Talents & Skills page". The page is `grug_classes/talents_ui.lua` (header: "The sfinv Talents & Skills page …"); `talent_graph_ui.lua` draws the graph content into it (`graph.page_content`).
  - `docs/technical/modules/combat-classes.md:423` calls `grug_core.status` the registry. No such table exists; the registry is `grug_core/status.lua` (`set_status`, `clear_status`, `get_status`, `status_modifier_sum` …).
  - `docs/technical/mod-map.md:52`: the grug_expeditions seam list names `register_on_ready/_end/_enter/_leave` but leaves out `register_on_close` (init.lua header :104-106), which `player-systems.md:477` names as a seam `grug_expeditions` uses.
- **Evidence:** the cited lines.
- **Proposal:** Correct the three names.
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
- Verifier: the `Q.reward_stacks` slip (formerly DT1-12's third item) does not hold (`grug_quests/state.lua:530` exports it). It was dropped from DT1-12 rather than listed as a separate refuted finding, because the other three items of that finding hold.
