# C8 — Player systems: jobs, quests, housing, home, mounts, inventory, money, achievements

**Scope.** `mods/PLAYER/` mods `grug_jobs` (4,631 lines), `grug_quests` (3,061),
`grug_housing` (2,595), `grug_home` (774), `grug_mounts` (1,340),
`grug_inventory` (2,471), `grug_money` (421) and `grug_achievements` (1,070):
16,363 Lua lines in total.

**Baseline.** `0f169898` (main). The working tree had no changes under these
paths while I reviewed it.

**Method.** I read these files in full: every file of `grug_money`,
`grug_achievements` (`init.lua`, `core.lua`), `grug_inventory` (`equipment.lua`,
`bags.lua`, `pages.lua`, `init.lua`, `ui.lua`), `grug_home` (all), `grug_mounts`
(`init.lua`, `state.lua`, `entity.lua`, `items.lua`, `trainer.lua`),
`grug_housing` (all except `catalog`-like data), `grug_quests` (`state.lua`,
`use.lua`, `npc.lua`, `ui.lua`, `hud.lua`, `registry.lua`), `grug_jobs` (`state.lua`,
`workspaces.lua`, `automatic.lua`, `stations.lua`, `discovery.lua`,
`trainers.lua`, `character_tab.lua`, `station_nodes.lua` install part, and the
runtime half of `ui.lua`).

I skimmed these: `grug_jobs/registry.lua` (the recipe index and
`recipe_for_craft`), `basics_routes.lua`, `basics_presentation.lua`,
`grug_quests/labels.lua`, `loader.lua`, `validate.lua`, `grug_inventory/help.lua`,
`grug_mounts/catalog.lua`, and `grug_achievements/catalog.lua` and
`creatures.lua`.

I traced the cross-mod chains that start or end in this lane into
`grug_repair`, `grug_core` (`combat.lua`, `status.lua`), `grug_classes/stats.lua`,
`grug_visuals/apply.lua`, `grug_abilities`, `grug_skills/bound_items.lua` and
`sfinv`. Engine behaviour is checked against `reference_projects/luanti`.

**Measured.** I ran one LuaJIT micro-benchmark of builtin `core.serialize` and
`core.deserialize` on a quest-state-shaped table
(`scratchpad/c8/bench_serialize.lua`). I also simulated the engine's
mod-load-order algorithm over every `mod.conf` (`scratchpad/c8/order.py`, a port
of `ModConfiguration::resolveDependencies` and `flattenMods`).

**Out of scope.** These belong to other lanes and are touched only where a
chain crosses this one:
- `grug_classes`, `grug_abilities`, `grug_pvp`, `grug_parties`, `grug_map`,
  `grug_skills`, `grug_trinkets`, `grug_visuals` and `grug_xp`;
- combat, durability (`grug_repair`) and world protection (`grug_core`);
- mob and NPC entities in `grug_mobs`.

## Summary

- **Persistence model.**
  - Per character in player meta: money (one int), quest state (one
    `core.serialize` blob that keeps every completed id forever), jobs (flat
    keys), achievements (flat int keys plus a comma list of cloaks), waystones
    (a space list), discovery (a serialized list), home bindings and mount
    tiers.
  - Mod-wide: housing claims live in mod storage in their own `v2|…`
    pipe-format records.
  - Shared stations keep their work in node meta; personal workspaces at
    public stations keep a private per-player record in node meta.
  - There is no shared "player data store" abstraction. Each mod owns its own
    keys, which is fine, but every format is different.
  - Fresh-server mode applies (AGENTS.md), so there are no schema migrations.
    None were found, and none are needed.
- **Equipment is the hub.** `grug_inventory.equipment_changed` is the one
  notifier; `grug_quality` wraps it. Its consumers are stats, the Character
  page, visuals, ability skins, trinkets, the Scout bow and gear descriptions.
  Durability writes since Round 33 fire it on every hit dealt and every hit
  taken. That turned the "rare event" assumption in several consumers into a
  per-hit cost (PLY-01).
- **The Character page is a cached inventory formspec** that is rebuilt from
  many places:
  - on equipment changes, status modifiers, money, the quiver, achievements,
    jobs and housing;
  - by a 1 s poll in `pages.lua` and a 10 s poll in `housing/interface.lua`.

  It is the default sfinv page, so "only when the Character page is shown"
  means "almost always", even while the inventory is closed. The engine sends
  nothing when the string is unchanged (`l_object.cpp:1748`), but the Lua
  build still runs.
- **Inventory guards are layered.** The pieces are:
  - three `register_allow_player_inventory_action` callbacks in `bags.lua`,
    `equipment.lua` and `housing/soulbound.lua`, plus one in `grug_skills`;
  - `override_item` wrappers on every node's `allow_metadata_inventory_*`
    (soulbound, bound skills, jobs stations);
  - raw `rawset` wrappers (the housing interaction guard);
  - a global wrap of `core.create_detached_inventory`.

  The engine runs the allow callbacks in OR_SC mode, so the first numeric
  return wins (`builtin/common/register.lua:46`). Every callback must return
  `nil` for "not my concern", and they currently do. The override layers rely
  on mods-loaded order (PLY-08).
- **Money is solid.** It is one clamped int. `take_with_inventory` is a real
  check-then-commit transaction. The Bag of Coins deposit slot is a per-player
  detached inventory that accepts only bags and destroys them on put. I found
  no dupe vector.
- **Quest state** is decoded once and cached per player, keyed by the raw meta
  string (Round 30). Readers must never write into the table `load` returns;
  the code uses `editable` (a deep copy) and then `save`. Turn-in is check, then
  commit, then a fully preflighted inventory write. Kill credit, use credit and
  quest drops all go through the shared state.
- **Housing protection is cheap.** `claim_at` is a 128-node grid-cell lookup.
  The is_protected wrapper asks world protection first. Claim lifecycle,
  expiry, drafts and orphan handling are self-healing across crashes (a
  `vanished` scan, `/claim_remove orphans`). Placement validation is the one
  expensive call (PLY-04).
- **Mounts** are an invisible physical controller entity plus a visual child.
  The rider is attached to the controller, and both entities use
  `static_save = false`. Dismount runs on damage, death, leave, shutdown, race
  or faction change and teleport. The entity's `on_step` is per server step
  but cheap. The fragile spot is the "any HP loss dismounts" rule (PLY-02).
- **Jobs workspaces** have the most stateful UI in the lane. A personal
  workspace is a detached-inventory view saved into node meta on every change.
  Shared stations use node inventories. The output-take path (receipt set in
  `allow_take`, consumed in `on_take`) is correct but invariant-heavy, and the
  session is not closed when another form replaces it (PLY-03).

## Findings table

| ID | Sev | Category | Title | Location |
|---|---|---|---|---|
| PLY-01 | High | Perf | Every hit dealt or taken runs the full equipment-change chain: Character page rebuild, `get_properties`, an unconditional `set_properties` broadcast, ability description sync | `mods/ITEMS/grug_repair/runtime.lua:51`, `mods/PLAYER/grug_inventory/pages.lua:600` |
| PLY-02 | High | Bug | Any drop of max HP (a food or Vigor buff expiring) dismounts the rider; on a flying mount the rider falls | `mods/PLAYER/grug_mounts/entity.lua:697` |
| PLY-03 | Medium | Bug | At a furnace or dual furnace, the recipe-book button opens the book, then the workspace form pops back every second | `mods/PLAYER/grug_jobs/workspaces.lua:354`, `:392-401` |
| PLY-04 | Medium | Perf | Claim Stone placement scans all 10,201 columns before the cheap cube check; a held right-click repeats it about 4×/s | `mods/PLAYER/grug_housing/registry.lua:480-516` |
| PLY-05 | Medium | Perf | Per-player inventory polling: quest-tracker holdings at 2 Hz, discovery scan of every list at 0.5 Hz and after every inventory action | `mods/PLAYER/grug_quests/hud.lua:122`, `mods/PLAYER/grug_jobs/discovery.lua:50-77` |
| PLY-06 | Medium | Perf | `marker_states` recomputes every quest of both factions once a second per player, with a meta read per offerable quest | `mods/PLAYER/grug_quests/state.lua:242-274`, `:103-109` |
| PLY-07 | Medium | Duplication | The soulbound guard and the bound-skill guard implement the same three seams twice, with diverging coverage | `mods/PLAYER/grug_housing/soulbound.lua`, `mods/PLAYER/grug_skills/bound_items.lua` |
| PLY-08 | Medium | Agent-trap | Global API monkeypatches and wrappers whose correctness depends on the mods-loaded order | `mods/PLAYER/grug_housing/stone_form.lua:32`, `soulbound.lua:78`, `mods/PLAYER/grug_jobs/stations.lua:138-181` |
| PLY-09 | Medium | Duplication | Five NPC-service session and permission implementations with diverging reach, socket and faction rules | `grug_mounts/trainer.lua`, `grug_housing/manager.lua`, `grug_home/innkeeper.lua`, `grug_quests/npc.lua`, `grug_jobs/trainers.lua` |
| PLY-10 | Low | Perf | Quest state is one ever-growing blob; each crediting kill deep-copies and re-serializes it (122 µs and 17.6 KB at 450 completed) | `mods/PLAYER/grug_quests/state.lua:20-40`, `:488-507` |
| PLY-11 | Low | Perf | A Scout's every shot rebuilds and re-sends the Character page (the quiver total label changes) | `mods/PLAYER/grug_inventory/bags.lua:167-171`, `:263` |
| PLY-12 | Low | Duplication | Four Character-page refresh paths and two polls, each with its own change test | `pages.lua:395`, `:574`, `:584`, `:471`; `housing/interface.lua:125-147` |
| PLY-13 | Low | Legacy | Personal notices still go to chat in several mods, against the feed rule | `grug_jobs/state.lua:26`, `stations.lua:10`, `grug_home/travel.lua:7`, `waypoints.lua:68`, … |
| PLY-14 | Low | Legacy | Dead alias `invalidate_armor` (no caller) and history-heavy comments in `equipment.lua` | `mods/PLAYER/grug_inventory/equipment.lua:217-220` |
| PLY-15 | Low | Duplication | Seven hand-written "give or drop at feet" sites with different list coverage | `grug_quests/state.lua:564`, `grug_housing/api.lua:245`, `:294`, … |
| PLY-16 | Low | Perf | A 10 Hz all-player control and wielded-item poll only for the "weapons go in the hand slots" hint | `mods/PLAYER/grug_inventory/equipment.lua:1073-1095` |

## Findings

### PLY-01 Every hit dealt or taken runs the full equipment-change chain
- **Severity:** High. **Category:** Perf. **Confidence:** Verified (traced end
  to end; network cost by engine reading, not measured).
- **Location:** `mods/ITEMS/grug_repair/runtime.lua:33-54` (`wear_stack`),
  `:140-158` (outgoing and incoming hooks);
  `mods/PLAYER/grug_inventory/equipment.lua:207-215`. The consumers are listed
  below.
- **What:** `grug_repair` wears the melee stack on every settled outgoing
  damage or heal action, and a random armour piece on every settled incoming
  hit. `wear_stack` always writes the stack back and calls
  `grug_inventory.equipment_changed(player, list, "durability_metadata")`,
  because the wear remainder changes on every use. That fires every
  `register_on_equipment_change` consumer, and only some of them honour the
  `durability_metadata` reason:
  - `grug_classes/stats.lua:210-212` → `apply_stats`: one `get_properties()`,
    which allocates the full property table, plus `get_max_hp`.
  - `grug_visuals/apply.lua:490-495` → `grug_visuals.apply`: `compose`, then
    an **unconditional** `player:set_properties({visual_size = …})` at `:412`.
    That clears `m_properties_sent`, so the engine re-sends the player's full
    property packet to every client that sees the player.
  - `grug_inventory/pages.lua:600-602` → `grug_inventory.refresh` → a full
    Character page build. The default sfinv page is the Character page, so this
    happens almost always. The build covers two pool breakdowns, the armour
    breakdown, crit and dodge, `preview_model` (another `get_properties`), eight
    slot reads, the housing status, the cloak dropdown and money. The engine
    drops the send if the string is unchanged (`l_object.cpp:1748`).
  - `grug_abilities/init.lua:1923-1929`: `clamp_mana`, `hud_update`, and
    `sync_descriptions` (a walk of `main`) run **before** its
    durability-aware branch.
  - Not affected: `grug_gear` returns at once for this reason, trinkets skip
    non-trinket lists, and `grug_quality`'s wrapper only drops its aggregate
    cache (so the next stat read recomputes equipment totals).
- **Impact:**
  - **Frequency:** per hit dealt plus per hit taken, per player in combat.
  - **Cost class:** heavy Lua per event (several engine calls that allocate
    property tables, a formspec string build of about 40 elements) plus one
    property broadcast per event. The broadcast scales with players × nearby
    observers, which makes group fights at the rift, fortresses and dragons
    O(N²) in property packets.
  - **Visible effects:** none directly; this is server CPU and network.
- **Better:**
  1. In `equipment_changed`, or one level up in `grug_repair`, treat
     `durability_metadata` as a cheap event. Invalidate the caches, but notify
     consumers only when the broken state changed. A broken-state change is the
     one case that alters stats and looks, and the existing comment at
     `equipment.lua:201-202` already names it.
  2. Make `grug_visuals.apply` compare `visual_size` before writing.
  3. Optionally, have the Character-page consumer skip this reason entirely.
     The list[] shows wear live.

  Effort S–M. Risk: consumers that rely on per-hit notification. The
  durability tooltip is refreshed in-stack by `refresh_stack`, so it should be
  unaffected. Coordinate with the ITEMS (repair) and visuals lanes. Before and
  after, measure with a fight stand-in (the method of the R30/R32 performance
  probes).
- **Verification (phase 2):** Partly confirmed — the CPU chain is real (`grug_repair/runtime.lua:49-52` → grug_quality wrapper `init.lua:1019-1024` → `equipment.lua:207-214` → seven consumers; only grug_gear `init.lua:809`, the abilities swing-clock branch `init.lua:1944` and Scout `scout.lua:475` read the reason, trinkets and visuals filter by list only), but the network amplification is wrong: the engine's `set_properties` only marks properties unsent when the struct actually changed (`reference_projects/luanti/src/script/lua_api/l_object.cpp:1027-1032`, since c524c52ba), so the unchanged `visual_size` write sends nothing, and the Character formspec is deduplicated (`l_object.cpp:1748`); the only per-event packet is the inventory resend any wear write needs. Estimate (engine calls counted, ~0.5 µs per `get_stack`, 1.6 µs per `get_properties` from upstream-workarounds.md, ~6–12 µs LuaJIT `-joff` for the ~3 KB Character string): about 0.25–0.5 ms per weapon-wear event (two 96–128-slot walks dominate) and 0.15–0.3 ms per armour-wear event, i.e. O(players × hits) CPU only, still High at the 100-player target. Same verdict as CORE-01, CMB-02, ITM-01.

### PLY-02 A drop in max HP dismounts the rider; a flying rider falls
- **Severity:** High. **Category:** Bug. **Confidence:** Verified (code and
  engine traced; not reproduced in the engine).
- **Location:** `mods/PLAYER/grug_mounts/entity.lua:697-702`;
  `mods/PLAYER/grug_classes/stats.lua:175-186`; engine
  `src/script/common/c_content.cpp:345-347` and
  `src/server/player_sao.cpp:519`.
- **What:**
  ```lua
  core.register_on_player_hpchange(function(player, hp_change)
  	local record = hp_change < 0 and active[player:get_player_name()]
  	if record then grug_mounts.dismount(player, nil, record.mode == "water") end
  end, false)
  ```
  `apply_stats` lowers `hp_max` through `set_properties` whenever a
  max-HP-percent status ends. It is called from `status.lua`'s modifier hook
  and from equipment changes. Examples are the food "hearty" and "hunter" buffs
  (`grug_food/init.lua:21-39`) and the Elixir of Vigor. The engine clamps HP
  through `setHP(…, SET_HP_MAX)`, which runs `on_player_hpchange` with a
  negative change, reason `{type = "set_hp", from = "engine"}`.

  A rider at full HP therefore gets dismounted the moment such a buff expires.
  For land and flight mounts this is a non-hard dismount: `set_pos(free_dismount_pos(pos))`
  in mid-air, with no message (`reason` is nil). A flying rider then falls; the
  flight ceiling is y = 600, and fall damage exists (`death:fall` is an
  achievement counter).

  The same root cause cancels a quest "use" hold (`grug_quests/use.lua:300-304`)
  and makes a gear swap that lowers max HP mid-ride dismount.
- **Impact:** normal play. Eating food before a long ride is common, and
  out-of-combat regeneration keeps riders at full HP, so the clamp nearly
  always bites. The worst case is death by falling during flight travel.
- **Better:** ignore max-HP clamps in both handlers, for example by skipping
  `reason.type == "set_hp" and reason.from == "engine"`; real damage in this
  game comes with `from = "mod"` or a punch, fall, node or drown type. A more
  explicit alternative: `apply_stats` clamps first with a marked reason
  (`player:set_hp(max_hp, {type = "set_hp", _grug_max_clamp = true})`) before
  lowering `hp_max`, and the handlers skip that marker. Add a fixture where a
  buff expires while mounted. Effort S.
- **Verification (phase 2):** Confirmed — `apply_stats` lowers `hp_max` via `set_properties` (`grug_classes/stats.lua:173-186`, from the status hook `:190-192`); the engine then calls `setHP(hp_max, SET_HP_MAX)` (`c_content.cpp:344-347`), which runs every `on_player_hpchange` with a negative change and type `set_hp` (`player_sao.cpp:511-519`, `player_sao.h:283-284`), so `grug_mounts/entity.lua:697-702` dismounts non-hard into mid-air (`free_dismount_pos`, `:42-59`, no ground search) and `grug_quests/use.lua:300-304` interrupts holds. Real triggers: food tiers 3+ (`hp_pool_percent` 2–6, `grug_food/init.lua:21-33`) and the Elixir of Vigor; only an active absorb shield swallowing the clamp (CMB-06) avoids it.

### PLY-03 Recipe book at a furnace: the workspace form pops back every second
- **Severity:** Medium. **Category:** Bug. **Confidence:** Verified (code
  trace).
- **Location:** `mods/PLAYER/grug_jobs/workspaces.lua:223`, `:354`, `:392-401`.
- **What:**
  - Every workspace form carries the station book button (`:223`).
  - `fields.grug_jobs_book` opens the book (`:354`) but does not detach the
    workspace session; the repair button at `:355-362` does detach first.
  - The 1 s globalstep calls `refresh(ctx, ctx.station == "furnace" or …)`
    for every viewer (`:399`), which re-shows the workspace form.

  Showing another formspec does not send `quit` for the old one, which is why
  `housing/stone_form.lua:27-39` wraps `core.show_formspec`. The book is
  therefore replaced by the furnace form within a second. Closing the book (Esc
  or its Close button) does not end the furnace session either, so the furnace
  form keeps reappearing until the player presses Esc on the furnace form itself
  or walks more than 8 nodes away.
- **Impact:** every player who opens a recipe book from a furnace or dual
  furnace, whether at a public hearth, a personal workspace or a shared station.
  Brewing stands and benches are not affected (`refresh(ctx, false)`).
- **Better:** detach (save and drop `viewers[name]`) before `open_book`, as the
  repair path does. Or keep the context and stop re-showing while another form
  is open, tracked through the same `core.show_formspec` observation that
  `stone_form.lua` uses. Effort S.
- **Verification (phase 2):** Confirmed — `workspaces.lua:354` opens the book without `detach`, unlike repair at `:355-362`; the receive-fields handler ignores other form names (`:350`), there is no `core.show_formspec` observer in grug_jobs (only `default/node_formspec.lua:92` and `housing/stone_form.lua:31` have one), and the 1 s globalstep calls `refresh(ctx, true)` for furnaces (`:392-401`) → `core.show_formspec(FORM)` at `:240`.

### PLY-04 Claim Stone validation does the full zone scan before the cheap checks
- **Severity:** Medium. **Category:** Perf. **Confidence:** Plausible (call
  counts verified; per-column cost not measured in the engine).
- **Location:** `mods/PLAYER/grug_housing/registry.lua:480-516`
  (`SAMPLE_STEP = 1` at `:46`); `mods/PLAYER/grug_housing/stone.lua:62`.
- **What:** `M.validate` checks every column of the 101 × 101 square: 10,201
  columns, each calling `water_class_at`, `zone_at` (`id_at`) and
  `territory_at`. The last builds a position table, and the R7 overlay
  concatenates a string key per call (`r7_zone_overlay.lua:43-50`). The cheap
  3 × 3 × 3 cube check runs only after all of that (`:514`, "Last: the one
  refusal the player can fix on the spot").

  `on_place` runs on every placement attempt, and holding the place button
  repeats it about every 0.25 s. A player at a legal spot whose cube is blocked,
  or a spot that fails late in the scan, therefore triggers repeated full scans.
  The registry comment quotes about 10 ms per placement in the engine-free
  fixture. With the real `grug_zones` lookups it is likely higher.
- **Impact:** an event-driven path, but one player holding the place button
  can cost tens of milliseconds per second of server step. That is a small,
  self-inflicted stall, abusable by one player.
- **Better:**
  - Run `cube_clear` and the claim-overlap check first, but report their
    refusal in the same order as now, so the UX order is kept.
  - Cache the last validated `(pos, result)` per player for a few seconds.
  - Optionally, rate-limit `on_place` per player.

  Effort S. Measure one validation in the headless engine first.
- **Verification (phase 2):** Confirmed — `registry.lua:497-512` scans all 10,201 columns (SAMPLE_STEP 1, `:46`) with `water_class_at`, `id_at` and `territory_rule_at` (fresh position table, `api.lua:338-340`) before `cube_clear` at `:514`, and `stone.lua:62` re-runs it per placement attempt (client `repeat_place_time` 0.25 s). Correction to *Better*: the claim-overlap loop (`:491-496`) and `feature_in` already run first; only the cube check is late. Per-attempt cost not measured here.

### PLY-05 Per-player inventory polling allocates every slot twice a second
- **Severity:** Medium. **Category:** Perf. **Confidence:** Verified (code);
  cost not measured.
- **Location:**
  - `mods/PLAYER/grug_quests/hud.lua:118-138`, `:162-175` → `state.lua:351-379`
    (`journal_key` → `holdings`, `:81-90`);
  - `mods/PLAYER/grug_jobs/discovery.lua:50-77`.
- **What:**
  - The quest tracker polls each player every 0.5 s. `journal_key` calls
    `holdings`, which runs `get_list` on `main` and every bag: up to 160
    `ItemStack` userdata per call. It runs whenever the player has any active
    quest, which is nearly always.
  - Discovery scans **every** player list every 2 s with
    `inventory:get_lists()`: main, craft, the equipment slots, bags, the
    quiver, and so on. It calls `grug_jobs._item_name` per stack. It also
    queues a second scan via `core.after(0)` after every inventory action.
  - `use.lua` and `marker_states` (PLY-06) add their own holdings snapshots.
- **Impact:**
  - **Frequency:** per player, 2.5 polls per second.
  - **Cost class:** O(inventory slots) userdata allocations per poll, which is
    GC pressure that grows with players × bag size.

  Each poll is modest; the sum is a steady background cost. Nothing is
  player-visible.
- **Better:**
  - **Discovery:** the seen set only grows. Scan on pickup
    (`register_on_item_pickup`), on inventory actions and on server-side
    grants, with a slow sweep as a backstop.
  - **Tracker:** compute holdings only for the item names that active
    objectives accept, using `inv:contains_item` or counted
    `get_stack` reads. Or bump a cheap per-player inventory version from the
    pickup and inventory-action hooks and skip the poll when it is unchanged.

  Effort M. Measure before and after with stand-ins, the way the Round 32 slot
  probes did.

### PLY-06 `marker_states` recomputes every quest once a second per player
- **Severity:** Medium. **Category:** Perf. **Confidence:** Verified (code);
  cost estimated.
- **Location:** `mods/PLAYER/grug_quests/state.lua:242-274` (recompute loop),
  `:201-216` (`status_at`), `:103-109` (`permitted` calls
  `grug_xp.get_level`).
- **What:**
  - The memo lasts 1 s (`MARKER_MEMO_US`). The NPC tag carriers ask once a
    second (`npc.lua:151-178`), as do the Map tab and minimap providers, so for
    a player near quest givers or with the map open the memo is recomputed
    about every second.
  - Each recompute walks **all** `quests_by_npc` entries: 540 quests, including
    the other faction's 84 givers. The faction filter is applied only by the
    consumers.
  - For every quest that has no unmet prerequisite and is not done (115 have
    no prerequisites, so more than 115 at the start), `offerable` → `permitted`
    calls `grug_xp.get_level(player)`. That is a meta `get_int` plus a
    level-curve loop of up to 60 iterations, **per quest**.
- **Impact:** per player-second, O(all quests) table work plus more than 100
  meta reads. Roughly a few hundred µs per player-second at the high end
  (estimate). Not visible to players; it scales linearly with players.
- **Better:**
  - Read the level once per recompute and pass it into `status_at` and
    `permitted`.
  - Iterate only the player's own faction's givers: keep a
    `quests_by_npc_by_faction`, since `resolve_npc_factions` already runs at
    mods-loaded.
  - Optionally, raise the memo lifetime to the coarsest consumer's period.

  Effort S.

### PLY-07 Two copies of the "item may not leave the player" guard
- **Severity:** Medium. **Category:** Duplication. **Confidence:** Verified.
- **Location:** `mods/PLAYER/grug_housing/soulbound.lua` (all of it) and
  `mods/PLAYER/grug_skills/bound_items.lua:32-80`.
- **What:** both guard the same three seams: a player-inventory allow
  callback, an `override_item` on every node's
  `allow_metadata_inventory_put` and `_move`, and detached-inventory
  `allow_put`. They already differ:
  - housing wraps `core.create_detached_inventory` globally, so it also guards
    detached inventories created at runtime (workspaces, deposit, fuel slot);
  - skills wraps only the detached inventories that exist at mods-loaded, and
    only `allow_put`, not `allow_move`;
  - the flags differ (`_grug_soulbound_guard` vs `_grug_bound_guard`).

  A third kind of restricted item would add a third copy.
- **Impact:** today the gaps are harmless. For example, bound skill or mount
  items can enter a personal workspace, but those exist only at undiggable
  public stations and only the owner sees them. The risk is the next edit
  fixing one copy and not the other.
- **Better:** one `grug_core` (or `grug_inventory`) helper,
  `register_item_confinement(predicate, allowed_lists_fn)`, that installs all
  three seams once, wraps runtime-created detached inventories, and runs after
  every other mods-loaded override (see PLY-08). Effort M.

### PLY-08 Global monkeypatches and wrappers that depend on load order
- **Severity:** Medium. **Category:** Agent-trap. **Confidence:** Verified
  (order simulated with `scratchpad/c8/order.py`).
- **Location:**
  - `mods/PLAYER/grug_housing/stone_form.lua:31-39` (`core.show_formspec`);
  - `soulbound.lua:29-89` (`core.create_detached_inventory` at `:77-82`, `wrap_node` at
    mods-loaded);
  - `protection.lua:42-48`, `:50-88` (`core.is_protected`, raw `rawset` of
    `on_punch` and `on_dig` on every buildable_to node);
  - `interaction.lua:124-176` (raw wrap of every node's `on_rightclick`,
    `on_receive_fields` and `allow_metadata_*`, deferred to `core.after(0)`);
  - `mods/PLAYER/grug_jobs/stations.lua:138-181` (wraps
    `core.register_craft_predict` and `register_on_craft`, and keeps its veto
    last);
  - `workspaces.lua:471-563` (`override_item` of station allow callbacks at
    mods-loaded);
  - `grug_inventory/ui.lua:39`, `pages.lua:549` (`sfinv.make_formspec`,
    `sfinv.get_homepage_name`);
  - `mods/ITEMS/grug_quality/init.lua:1019-1026` (re-wraps
    `grug_inventory.equipment_changed`).
- **What:** the station nodes' allow callbacks are wrapped in this order:
  1. `grug_jobs` replaces them (`override_item`) at mods-loaded;
  2. the soulbound guard and the bound-skill guard wrap whatever is there at
     *their* mods-loaded;
  3. the interaction guard wraps raw on the first step.

  Mods-loaded callbacks run in mod load order. The simulated engine order is
  `grug_jobs` (34) → `grug_housing` (38) → `grug_skills` (46), which is correct
  today. There is no dependency edge that enforces it: housing and skills do not
  depend on jobs. If the order flipped (a new dependency, or the
  `random_mod_load_order` setting), jobs' `override_item` would replace the
  wrapped callbacks. The guards set `_grug_*_guard` flags that survive the
  override, so they would never re-wrap. Claim Stones and bound items could
  then be put into shared stations.

  Separately, the global `core.show_formspec` and
  `core.create_detached_inventory` replacements are invisible to anyone
  reading the calling mod.
- **Impact:** no bug today. A plausible regression from an innocent
  `mod.conf` edit, and hard to diagnose.
- **Better:**
  - Run every guard wrap at `core.after(0)`, after all mods-loaded work, as
    `interaction.lua` already does. Or add `optional_depends = grug_jobs` to
    housing and skills.
  - Add a load-time audit: after the wraps, assert that every station node's
    `allow_metadata_inventory_put` refuses a soulbound stack.
  - List the global replacements in `docs/technical/module-guide.md`.

  Effort S.

### PLY-09 Five NPC-service dialogs, five permission rules
- **Severity:** Medium. **Category:** Duplication. **Confidence:** Verified.
- **Location:**
  - `grug_mounts/trainer.lua:23-43` (distance ≤ 8, socket ≤ 2, own
    `CAPITAL_FACTION` table);
  - `grug_housing/manager.lua:67-87` (a near-copy, own `FACTION` table);
  - `grug_home/innkeeper.lua:2-12` (distance ≤ 8, row ≤ 2, luaentity
    identity);
  - `grug_quests/npc.lua:9-14`, `:99-101` (distance ≤ 6, `grug_factions.serves`);
  - `grug_jobs/trainers.lua:86-93` (distance ≤ 8 from where the dialog was
    *opened*; no entity or faction re-check).
- **What:** each service keeps its own session table, formname scheme (serials
  or not) and "still allowed?" rule. Faction is checked three different ways:
  hard-coded capital tables, a location row, or `grug_factions.serves`.
  AGENTS.md makes `grug_factions.serves` the rule. Upstream,
  `start_villagers.lua:1037-1041` already applies it, so the copies are
  redundant and can drift.
- **Impact:** inconsistent reach. A jobs trainer keeps working if its NPC is
  removed or replaced mid-dialog. A new service has no single template to
  copy.
- **Better:** one `grug_core.npc_session` helper (open, permitted, close on
  leave or die) parameterised by reach and socket tolerance, using
  `grug_factions.serves`. Migrate the five sites. Effort M.

### PLY-10 Quest state is one ever-growing serialized blob
- **Severity:** Low. **Category:** Perf. **Confidence:** Verified (measured
  with LuaJIT and builtin `serialize.lua`).
- **Location:** `mods/PLAYER/grug_quests/state.lua:20-40` (`load`, `editable`,
  `save`), `:488-507` (`credit_kill`).
- **What:** the whole quest state is one meta string, and `completed` keeps
  every finished id forever. Each kill that raises a counter does a
  `table.copy` of the full state plus `core.serialize`. Every `load` call
  re-reads the whole string from meta to compare it with the cache key. That
  happens several times per player-second: `journal_key`, `use_needs`,
  `marker_states`, `quest_held`.

  Measured on a late-game shape (450 completed, 20 active, 60 cooldowns):
  17,652 bytes, **122 µs** for copy plus serialize and 59 µs to deserialize.
  At 100 completed: 6 KB and 49 µs.
- **Impact:** per crediting kill, about 0.1 ms per late-game character, plus a
  17 KB meta rewrite. Small, but it grows with progress and runs on the kill
  path.
- **Better:** store `completed` (append-only) and `cooldowns` under their own
  meta keys and keep the hot blob to `active` and `tracked`. Or keep a dirty
  flag and serialize at most once per second. Effort S–M (touches the
  fixtures).

### PLY-11 Every Scout shot rebuilds and re-sends the Character page
- **Severity:** Low. **Category:** Perf. **Confidence:** Verified.
- **Location:** `mods/PLAYER/grug_inventory/bags.lua:167-171` (`quiver_changed`),
  `:263` (`consume_ammo`); `pages.lua:144-145` (the total label).
- **What:** `consume_ammo` → `quiver_changed` → `normalize_quiver` (inventory
  writes) plus `refresh_character_tab(player, "stats")`. Because the quiver
  total label is part of the page, the string changes on every shot and the
  engine really sends the full inventory formspec (a few KB). Money changes do
  the same (`pages.lua:615`), but those are rarer.
- **Impact:** one formspec packet per arrow to the shooter only, so O(players)
  and not O(N²). The shooter also pays a page build per shot.
- **Better:** drop the live total from the cached page and update it on page
  open or on the 1 s poll. Or show the total through the slot's count overlay
  or a HUD element. Effort S.

### PLY-12 Four Character-page refresh paths and two polls
- **Severity:** Low. **Category:** Duplication. **Confidence:** Verified.
- **Location:**
  - `pages.lua:395` (`refresh_character_tab`), `:574` (`refresh`, via
    `set_page`), `:584` (`refresh_character`), `:471-485` (1 s poll for the
    home and effects text);
  - `grug_housing/interface.lua:117-147` (`ui.refresh_character` with its own
    `shown` cache and a 10 s poll).
- **What:** every consumer chooses a slightly different refresh with a
  slightly different "is it shown?" test. `refresh` also re-enters `set_page`
  (on_leave and on_enter). The housing status text is polled separately from
  the home text, although both render into the same page.
- **Impact:** this is where PLY-01 and PLY-11 come from. Every new status line
  invites another poll.
- **Better:** one `grug_inventory.request_character_refresh(player, reason)`
  that coalesces requests per step (dirty flag, rebuild once in a
  globalstep), plus one poll that asks registered "status providers" for
  their keys. Effort M.

### PLY-13 Personal notices still go to chat
- **Severity:** Low. **Category:** Legacy. **Confidence:** Verified.
- **Location:**
  - `grug_jobs/state.lua:26-30` (learned and advanced messages),
    `stations.lua:3-12` (craft denials);
  - `workspaces.lua:384`;
  - `grug_home/travel.lua:7` (`notify`), `waypoints.lua:68` (chat and
    flash), `claim_home.lua:84`;
  - `grug_housing/stone.lua:25-28` (flash and chat);
  - `grug_inventory/equipment.lua:1039` (the weapon hint).
- **What:** AGENTS.md (Round 32): "Personal notices go to the message feed …
  never to chat". These sites predate the rule or ignore it.
- **Impact:** chat spam and inconsistent UX.
- **Better:** route them through `grug_core.feed` with a key per notice group.
  Effort S.

### PLY-14 Dead alias and history-heavy comments in `equipment.lua`
- **Severity:** Low. **Category:** Legacy. **Confidence:** Verified (searched
  all of `mods/` and the docs).
- **Location:** `mods/PLAYER/grug_inventory/equipment.lua:217-220`. It is
  re-assigned at `mods/ITEMS/grug_quality/init.lua:1026`.
- **What:**
  - `grug_inventory.invalidate_armor` is "kept because AGENTS.md and the WP7
    armor pipeline document it". AGENTS.md does not mention it, and nothing
    calls it.
  - The file carries long design-history comments (the class-change unequip
    "has no caller left", playtest-round narratives).
  - The weapon join hint is written for pre-slot characters, which fresh-server
    mode rules out. It is still reachable by unequipping a weapon.
- **Impact:** noise. Agents keep or extend paths that only exist for history.
- **Better:** remove the alias and both of its assignments. Trim the comments
  to current rules. Effort S.

### PLY-15 Seven hand-written "give or drop at feet" sites
- **Severity:** Low. **Category:** Duplication. **Confidence:** Verified.
- **Location:** `grug_quests/state.lua:564-572` (main and bags);
  `grug_housing/api.lua:245`, `:294` and `stone_form.lua:236-242` (main only);
  `grug_inventory/equipment.lua:894`, `:904` and `bags.lua:282` (main only).
- **What:** each site writes `add_item`, then `core.add_item(get_pos)`, with a
  different choice of lists. Quests fill bags; the others do not.
- **Better:** one `grug_inventory.give(player, stack, {bags = true})` returning
  what was dropped. Effort S.

### PLY-16 A 10 Hz poll only for the weapon hint
- **Severity:** Low. **Category:** Perf. **Confidence:** Verified.
- **Location:** `mods/PLAYER/grug_inventory/equipment.lua:1073-1095`.
- **What:** every 0.1 s, for every player: `get_player_control()` (a table)
  plus `get_wielded_item()` (an ItemStack), to detect a fresh LMB press with a
  weapon in hand. The LMB hold state machine (`grug_abilities/input.lua`)
  already polls controls.
- **Better:** hook the hint into the state machine's fresh-press event, or
  drop the rate to 0.25 s. Effort S.

## Hot-path inventory

| Path | Frequency | Cost class | Notes |
|---|---|---|---|
| `equipment_changed` chain on durability writes | per hit dealt and per hit taken | **heavy** | PLY-01 |
| Mount controller `on_step` (`entity.lua:486-533`) | per server step per mounted player | light | Flight adds `water_class_at` and `id_at` per step; the 16 × 7 warning sweep runs 1/s (R30) |
| Mount `on_player_hpchange` | per HP change | trivial | The rule itself is wrong (PLY-02) |
| `core.is_protected` wrapper (`housing/protection.lua:42`) | per dig, place and any protection query | light | World check first (other lane); `claim_at` is a grid-cell lookup; privs only when protected |
| Interaction guard on node right-click and inventory | per interaction | light | `claim_at` |
| `register_world_alteration_guard` (arrival cube) | per liquid update reaching the guard | light | `arrival_cube_claim` = `claim_at` |
| Allow-player-inventory callbacks (bags, equipment, soulbound, skills) | per inventory action or drag frame | light | Refusal messages throttled (`claim_warn`) |
| Quest tracker poll (`hud.lua:162`) | per player per 0.5 s | medium | `holdings` (PLY-05); journal rebuilt only on key change |
| Quest use pass (`use.lua:320`) | per player per 1 s, slotted | light | `use_needs` memoized per state string |
| Quest `marker_states` | per player about 1/s | medium | PLY-06 |
| Quest `credit_kill` | per eligible kill per participant | light, or medium when it credits | PLY-10 |
| `roll_quest_drops` | per kill | trivial | Set lookup exits early |
| Achievements kill hook | per eligible kill per participant | light | Cached counters per entity name; `set_int` per counter |
| Jobs discovery scan (`discovery.lua:73`) | per player per 2 s, plus per inventory action | medium | PLY-05 |
| Jobs craft predict and on_craft (`stations.lua`) | per craft-grid change or craft | light | Indexed `recipe_for_craft` (R30 P4) |
| Workspace viewers globalstep (`workspaces.lua:392`) | per open workspace per 1 s | light | Furnaces re-show the form every second (PLY-03); signature serialize twice per advance |
| Station node timers (`workspaces.lua:504`) | per active furnace per 1 s | light | Deserialize and serialize process meta, `set_string` every tick (block dirty each second, like minetest_game) |
| Station LBMs (`run_at_every_load`) | per station node per block load | trivial | |
| Character page 1 s poll (`pages.lua:471`) | per player per 1 s | light | `home_button_text` (`grug_home.get` plus innkeeper copy) or `effects_key` |
| Housing status poll (`interface.lua:140`) | per player per 10 s | trivial | |
| Housing claim scan (`stone.lua:227`) | per 5 s | light | O(claims log claims) plus `get_node_or_nil` per claim |
| Housing draft form tick (`stone_form.lua:496`) | per open draft form per 1 s | trivial | |
| Waystone discovery (`waypoints.lua:181`) | per player per 1 s | trivial | Decode a short string, 7 rows |
| Weapon-hint poll (`equipment.lua:1073`) | per player per 0.1 s | light | PLY-16 |
| Money `register_on_change` → Character page | per balance change | light | The string changes, so a real send |

## Bug-prone areas

- **`grug_jobs/workspaces.lua`.**
  - The receipt handshake between `allow_take` and `on_take` asserts (a server
    crash if the invariant ever breaks).
  - A personal versus shared split in every callback.
  - Detached-inventory sessions that are not closed by a replacing form
    (PLY-03).
  - Item state in three places at once: the detached view, the node meta
    record, and node inventories.
- **`grug_inventory/bags.lua` quiver.** Moves into the quiver are applied
  inside an *allow* callback, which then refuses the engine's move, and
  normalization rewrites cells. Correct as written, but any change to the
  engine's move or swap semantics breaks it.
- **The equipment notifier.** It has a re-entrancy guard, two-pass coalescing
  and reason propagation (`grug_core/combat.lua:333-380`), and a wrapper in
  `grug_quality`. Consumers must be idempotent and cheap, and PLY-01 shows they
  are not.
- **Mods-loaded wrapper layering** (PLY-08): station callbacks, soulbound and
  bound guards, the interaction guard, and the jobs craft-callback "terminal"
  re-append machinery.
- **The quest state cache.** Writing into a table that `load` returned
  corrupts every reader silently. The fixture checks this, but the rule is
  easy to break in a new credit path.
- **Housing digging context.** `digging[name]` is set around
  `on_punch`/`on_dig` of buildable_to nodes, so the arrival-cube rule can tell
  a dig from a place. That relies on callbacks being looked up raw at call time
  and on nothing re-registering those nodes after the first step.

## Noted (no action)

- **Personal workspaces and crashes.** Workspace items live in node meta, and
  player inventories in the player database, saved at different times. A crash
  between the two saves can duplicate or lose items in transit, exactly like
  any Luanti chest.
- **Claim crash safety.** Claims are stored in mod storage, the stone in a map
  block and the item in player data. Crash leftovers heal themselves (the
  `vanished` scan, `already_placed`, `/claim_remove orphans`).
- **Runtime detached inventories.** Personal workspaces and the deposit slot
  are not covered by the bound-skill guard (PLY-07). This is harmless: public
  stations are undiggable, and the deposit takes bags only.
- **Cloak names.** `choose_cloak_by_name` matches by display name. Uniqueness
  of cloak names is not asserted in `R.build`; today all names are unique.
- **Station operations.** `fields.apply` relies on `ctx.choices` having been
  filtered by `can_craft_recipe` when the form was built. It is not re-checked
  at apply time; the window for that is a trainer unlearn, which is
  practically unreachable.
- **Bag content size.** The join hook resizes each bag's content list from the
  bag item. A removed bag definition would shrink the list to 0 and destroy its
  contents; fresh-server mode makes this moot.
- **Return home while pending.** `grug_home.return_home` returns `false`
  silently when a trip is already pending (`travel.lua:128`).

## Open questions for Jan

1. Durability granularity (PLY-01). Should wear really be written to the stack,
   and announced, on every hit? An alternative is to accumulate wear per player
   in memory and flush it on a timer, on unequip, on leave and on the
   broken-state transition. That would also remove most of the per-hit chain.
2. Mount rule (PLY-02). The intent is "any *damage* dismounts". May a max-HP
   clamp from an expiring buff or a gear swap leave the rider mounted? I assume
   yes.
3. Claim placement (PLY-04). Is it fine to check the cheap refusals (cube,
   overlap) first internally, while showing the same message order? Or should
   placement be rate-limited per player instead?
