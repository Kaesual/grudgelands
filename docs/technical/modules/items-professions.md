# Items, professions and economy

Part of the [module implementation guide](../module-guide.md), which indexes every
area. Professions and crafting, crops, fishing, trinkets, enchantments, materials, traders and money, the Miner's Guild. Implementation seams and engine pitfalls only; the
[design docs](../../design/README.md) own the game rules. Source paths in code
spans are repository-relative.

Sections: [Professions](#professions), [Crop registration](#crop-registration), [Fishing](#fishing), [Trinkets](#trinkets), [Enchantments](#enchantments), [Materials and tier-rock gating](#materials-and-tier-rock-gating), [Traders and money](#traders-and-money), [Miner's Guild](#miners-guild).

## Professions

### The six professions and their owners

- **Professions**: `grug_jobs` owns the exact six primaries — Weaponsmith,
  Armorsmith, Tailor, Leatherworker, Woodcarver and Goldsmith — plus the
  secondaries Cooking and Alchemy (`alchemist`; Round 33), two primary slots,
  player-meta progression and the recipe registry. The debug command `/prof`
  (`grug_jobs/admin.lua`, `professions.md` §1.6) writes through
  `state.lua`'s `admin_set(player, profession, tier, slot)` (the tier capped
  at `character_tier`) and `admin_unlearn(player, profession)`; both share
  `unlearn`'s `drop_progression` (job XP forfeited, target slot returned).

### The recipe registry

- **The recipe registry** (Round 45, `grug_jobs/registry.lua`): every craft is
  a record `{id, output, count, ingredients = {{item = name | group = name,
  n}, ...}, area, profession, tier, time, station, progress}`; `area` is
  `basic`, `cooking`, `alchemist` or a primary (`grug_jobs.AREAS`),
  `profession` the area's (nil in Basic), `time` seconds per item
  (`grug_jobs.DURATIONS`), `station` nil or the profession's station kind
  (`grug_jobs.PROFESSION_STATIONS`), `progress` whether it awards profession
  progress (never in Basic). Queries: `recipe(id)`, `recipes_in_area(area)`
  (tier, then the output's description, then id; sorted once every mod has
  loaded), `recipes_for_output(output)`; `grug_jobs.recipes` is every record
  in registration order. The returned lists are the registry's own: never
  write into them. An id defaults to the output plus the sorted ingredient
  list (`"default:wood|default:tree*1"`), stable however a catalog orders its
  rows; a job stores it. Content mods first call
  `register_ingredient_tier(item, tier)`, then
  `register_recipe{area, output, count?, ingredients, tier, time, station?,
  progress?, material?}`; `ingredient_list(tokens)` counts a flat list or grid
  of item names and `"group:x"` tokens into ingredients (the profession
  catalogs keep their input tables). A profession recipe needs a declared
  ingredient of its own tier and none above it; `material = true` (an
  intermediate whose output is an ingredient of the recipe's tier) gives no
  XP. After load every output and item ingredient must be registered and every
  group must have a member; a Basic record's tier (for the order only) is its
  output's material tier, else its highest ingredient's, else T1. **Basic** is
  `grug_jobs/basic_recipes.lua`: rows converted once from the base commit's
  engine grid routes by `tools/r45_rg/gen_basic_recipes.lua` (`--check`;
  input `tools/r45_rg/corpus_base.lua` from `dump_corpus.sh`), plus the
  stairs and walls families made per material by
  `register_basic_catalog`'s loop; a later change is a row of
  `tools/r45_rg/edits.lua` (a count, a removed row or an added row, with its round), which
  the generator applies and the fixture accepts. Gear recipes are
  registered by their family's owner (`grug_professions/base_recipes.lua`
  through `grug_professions.family_owner`, trinkets in
  `grug_artisans/goldsmith.lua`). Nothing matches a craft grid and nothing
  reads engine crafts: the vendored and other mods' engine grid registrations
  that remain are unreachable (the player's `craft` list has size 0,
  `craft_list.lua`). Furnace, dual-furnace and alloy recipes are no records:
  engine cooking recipes and `grug_smelting.RECIPES`; the good dishes' furnace
  finish is an engine cooking recipe `grug_cooking` registers.
  `can_craft_recipe(player, recipe)` is the profession gate (Basic always; a
  profession recipe or station operation needs the profession at the recipe's
  tier).

### The Crafting tab

- **The Crafting tab** (`ui.lua` the page, `craft_box.lua` the recipe box,
  `queue_box.lua` the queue view, Round 45 lane UI, Round 57 layout C;
  layout `inventory_equipment.md` §1): runtime state in
  the sfinv context `grug_craft` (area slot, page, applied and typed search,
  Craftable only, Favorites only `fav_only`, chosen recipe id, last known
  quantity text, the note of the last refused action, the row ids of the
  last build, the open box `box` and the one it was opened from
  `box_return`, and since Round 46
  the chosen kinds `picks` (group -> item) of the recipe `picks_for` and the
  built dropdowns `pick_rows`). In player meta only the favourites (Round
  57): `grug_jobs:favorites`, one `core.serialize`d sorted list of recipe
  ids ("" for none), read once per session; `is_favorite(player, id)`,
  `toggle_favorite(player, id)`; an id no recipe has is never shown. A group entry with
  two or more carried kinds gets `dropdown[...;grug_craft_pick_<serial>_<index>;
  ...;true]` (index events; `pick_serial` counts the box's builds); `fields`
  applies a value of the newest build's serial that differs from the built
  index, so the values every other event carries change nothing and a change
  on a page the server already replaced is ignored.
  `crafting_picks(st, recipe, counts)` (craft_box.lua) drops a pick whose
  kind is no longer carried or whose group shows no dropdown, and every pick
  when another recipe is chosen; ui.lua passes the result to the chosen
  row's ×N. Each build runs `update_job(player, "open")`, one
  `ingredient_counts` pass that feeds ×N, Craftable only and the box, and
  echoes the field values. The list hides a profession area's recipes above
  `profession_level`, Basic's above what `recipe_known` allows (Round 47;
  each build scans the inventory first, quietly). The recipe box's description is
  built per build: gear through `grug_items.crafted_output` on a copy (the
  job's own path), a Cooking output with an engine cooking recipe through
  `core.get_craft_result` (the cooked dish), else the definition; it is a
  nameless read-only `textarea[]`, which scrolls on the client without an
  event. A click is handled and answered with one resend;
  a search within a second of the last is ignored without one. The end
  resend is a `register_on_job_end` callback for the sources `timer` and
  `join` while the current page is Crafting (`open`, `start` and `stop` are
  answered by their own build or click). The box is replaceable for
  lane EU: `register_craft_box(name, {build = fn(player, view) -> formspec,
  fields = fn(player, st, fields) -> handled})` draws into
  `grug_jobs.CRAFT_BOX` (`view` = `{st, tab, recipe, job, counts, queue,
  full, bottom}`: the running job, the waiting ones (`queue_state`),
  whether the queue is full, and the y where the box's own content ends; the
  box named by `grug_craft.box`, default `recipe`; a def with `button = {label,
  shown = fn(player, tab)}` gets a button below the list, field
  `grug_craft_box_<name>`; `has_craft_box(name)`, `open_craft_box(st,
  name)` and `close_craft_box(st)` open a box over the current one and go
  back: the queue view `queue` from View Queue, and the seam for lane
  DETAILS: once a `details` box is registered, the recipe box draws
  "Recipe details" (`grug_craft_details`) beside its ingredients heading,
  and the enchant and upgrade boxes "Details" (`grug_craft_op_details`),
  which open it through `open_recipe_details(st, page)`, a new page stack).
  The details box (`details.lua`) reads the **ingredient source index**
  (`sources.lua`): `grug_jobs.item_sources()` builds it once at its first
  use from `grug_jobs.sources.game_data()` (the registry, the engine's
  cooking recipes, `grug_smelting.RECIPES`, the vendor shelves,
  `grug_mobs.drop_tables()` and `subtypes`, the gathering catalog, the
  mapgen's wild plants, ore rows and decorations read from its pure data
  files, the fishing and crop tables) and answers `sources(item)`,
  `members(group)`, `has_source(token)`, `label(item)` and `zone(id)`;
  `sources.build(data)` is pure, and `tools/r57_details` tests it on the
  real data. `source_lines(token)` is the page's one line per kind of
  source. Below every box ui.lua draws the job strip (from
  `CRAFT_STRIP_Y`: the bar, the stop button `stop_field(job)` =
  `grug_craft_stop_<start in ms>` (a click names the job it stops, so a
  double click never stops the next one), the job's
  line, View Queue `grug_craft_queue`) and, while it holds something, the
  overflow row; `action_button(view, field, label, enabled[, style])` is
  the big button right-aligned in a box's bottom row (`CRAFT_ACTION`,
  greyed as `grug_craft_recheck` when disabled; live it is named
  `<field>_<serial>`, the page build's serial `grug_craft.serial`, and
  `action_clicked(st, fields, field)` accepts only the newest build's, so a
  double click never starts or queues twice). `JOB_TEXTS[kind](job)`
  is a job's one line and `JOB_ICONS[kind](job)` its icon in the queue
  view (the waiting jobs' ✕ are `grug_craft_unqueue_<id>`), `progress_bar(x, y, w, h,
  job, now)` draws the bar
  (`grug_jobs_progress_bar.png` from `tools/r45_ui/gen_progress_bar.py
  --check`: 64 fill + 32 full frames, `BAR_FRAMES`), field names are
  `CRAFT_FIELDS`. Fixtures `tools/r45_ui`, `tools/r46_id` (the dropdowns).

### Crafting jobs

- **Crafting jobs** (`jobs.lua`, Round 45 lane JB; the queue Round 57):
  the running job in
  player meta `grug_jobs:job` (one `core.serialize`d table: `kind`
  "recipe", `recipe` id, `quantity`, `consumed` itemstrings for the refund,
  `target` itemstring for lane EU's enchant and upgrade kinds, `start` and
  `finish` in os.time() seconds with a sub-second part from `grug_jobs.now()`,
  `no_xp` after an unlearn; Round 47: `delivered`, the crafts of a recipe
  job delivered so far, and `picks`, the chosen kinds; a job without
  `delivered` delivers at its end only). The waiting jobs (Round 57) in
  `grug_jobs:queue`: one `core.serialize`d list in queue order ("" when
  none), each entry a job record with `duration` (seconds) instead of
  `start`/`finish` and an `id` (unique per player, named by the queue
  view's cancel); `QUEUE_MAX` 5 entries with the running one. An old save
  without the key has an empty queue; code before Round 57 reads only the
  running job. When the running job completes, the first entry becomes
  the running job with `start` = the previous `finish` (before the kind's
  finish runs, so a hook inside it finds the next job already running);
  `update_job` loops until the running job is not due, which is the login's
  offline catch-up; a Stop starts the next one now. `queue_state(player)`
  (copies with `recipe_def`), `queue_full(player)`, `QUEUE_FULL` (the
  message), `cancel_queued(player, id)` → ok, reason (the consumed stacks
  and target whole, refused when they do not fit). An unreadable queue
  entry is dropped with a warning, as an unreadable job is.
  `start_job(player, recipe_id, quantity[, picks])` →
  ok, reason, `{code, max}` (codes `busy` (the queue is full), `recipe`, `quantity`,
  `profession`, `station`, `ingredients`, `space`: the whole order's result
  does not fit into the inventory once its ingredients are taken,
  `output_fits`); `cancel_job(player)` → ok, `"completed"`/`"cancelled"` or
  the refusal (it delivers what is due, refunds the unfinished crafts'
  ingredients per entry in the take's order and awards the delivered crafts
  with `award_progress(..., quiet)`); `job_state(player)` (a copy, no side
  effects); `update_job(player, source)` completes a due job (login, the
  tab's build), else delivers the crafts finished so far and arms the
  timer; the timer is one `core.after` per online player with a job, at
  the next craft's end, no globalstep.
  `ingredient_counts(player)` (one pass over the bags, `main` and the
  inactive hotbar layout last, in the take's order, stacks without metadata:
  `is_ingredient_stack`), `ingredient_have(counts, entry)`,
  `crafts_from_counts(counts, recipe[, picks])` (when one item satisfies two entries,
  a dry-run take on the counted stacks, searched by halving from the
  per-entry total; Round 46, uncapped since Round 47),
  `output_fits(player, ingredients, quantity, stacks[, counts])` (the take on
  copies, then `grug_inventory.fits` with those copies standing in for the
  lists; `counts.lists` lends the pass's lists, nothing is written),
  `max_craftable(player, recipe[, counts[, picks]])` → n, by ingredients, by
  space (the crafts whose result fits, searched by halving);
  `picks` (group -> item, the crafting box's choice) goes through
  `picked_ingredients(ingredients, picks)`, which turns each chosen group
  entry into an item entry and merges entries of one item (without picks the
  list itself), and `start_job` counts and takes that list;
  `station_nearby(player, station)` (nodes whose `_grug_station` is the kind,
  within 4 nodes; true and the nearest such node); `take_all(player)` → moved, left. Finished
  stacks go through the give helper; the rest into the overflow
  `grug_craft_out` (at least 4 take-only slots, `ensure_output_area`, created at
  every join; a join handler that runs earlier, such as the 0.45.0
  migration's join part in `grug_core/migrations.lua`, calls it before it
  uses the list) through `to_overflow(player, stack)`, which adds a slot
  while a stack does not fit (Round 57: nothing goes to the feet; the drain
  moves what is left to the front and shrinks the list back to 4). `watch_overflow(player)` drains it by one
  `core.after` chain per player while it holds something (`take_all` every
  `OVERFLOW_POLL` s, started by a delivery into it and at the join);
  `refresh_crafting_page(player)` (ui.lua) resends an open Crafting page
  when the overflow appears or empties.
  `register_on_job_end(fn(player, job, outcome, source))` (outcome
  `completed`/`cancelled`; source `timer`, `join`, `open`, `start`, `stop`)
  is where UI resends an open Crafting page;
  `register_on_job_start(fn(player, job, station_pos))` runs after a job
  was accepted, started or queued (`station_pos` the station the start
  found, nil without one; the station sound plays then);
  `register_job_kind(kind, {finish})`, `begin_job(player, job[,
  station_pos])` (it runs the job, or queues it while one runs, the copy's
  `queued` set; nil and the reason when the queue is full: the caller gives
  back what it took) and `take_ingredients` are the parts EU's kinds
  use. A job is cleared before its kind's `finish` runs, so a hook inside it
  cannot complete it twice; a job without its recipe, or of an unknown kind,
  returns its ingredients and target. A finished recipe job makes its
  stacks (gear through `grug_items.crafted_output`), calls `award_progress`
  once and feeds "<item> ×N is ready". Fixtures `tools/r45_jb`, `tools/r57_craft` (the queue, offline, the grown overflow).

### The Basic unlock

- **The Basic unlock** (`basic_unlock.lua`, Round 47 lane CR, ruling 19): the
  held set in player meta `grug_jobs:held` (the format word `1`, then the
  sorted tokens a Basic recipe names, item names and `group:<name>`,
  space-separated; read once per session, written when it grows; about
  4.7 KB once every ingredient was held). `recipe_known(player, recipe)`
  (true outside Basic and for the starter outputs, `basic_unlock.lua` `STARTER`:
  the stick, the four wooden tools and, since Round 66, the fishing rod),
  `scan_held(player[, quiet])` (every
  list; returns the recipes it unlocked and feeds
  "New recipe: X" / "New recipes: X and N more", resends an open page
  unless quiet; the first scan of a character without the key is silent).
  Round 57 the tier unlock: `needed_basic(profession, tier)` (the walk,
  cached per profession and tier: for each ingredient of the tier's recipes
  and station operations the Basic recipes that make its item or any member
  of its group, recursively, a recipe X ← Y left out when another Basic
  recipe makes Y from X) and `unlock_basic_tiers(player, profession, from,
  to[, quiet])` into player meta `grug_jobs:basic_unlocked`
  (`BASIC_UNLOCKED_KEY`, the held set's format with recipe ids, read once
  per session), called by `learn` (tier 1), the tier advance in
  `record_craft` and `admin_set` (tiers 1..N, quiet), and at every join for
  each learned profession's tiers 1..`profession_level` (quiet);
  `recipe_known` reads both sets
  `held_dirty(player)` (jobs.lua after a delivery). When: at the join,
  before the Crafting tab's build, and in the player's slot (5 slots of
  0.1 s, one slot's players per step) when an inventory action or a
  delivery marked it, or an item placed by `grug_inventory.give` (dug
  drops, pickups, rewards; its `register_on_give` seam) names a token the
  held set lacks (Round 81 P2-04; a creative player's dug node, which
  skips the give helper, always marks), else every 10 s. The scan never
  reads the stored string again: whether the first scan is still due is
  kept from the session's one read. Fixtures `tools/r47_cr`,
  `tools/r57_craft` (the tier unlock); the
  list filter in `tools/r45_ui`.

### Station sounds

- **Station sounds** (`station_sounds.lua`, Round 45 PT8): a start hook
  plays the station's sound at the station a job (recipe, enchant or
  upgrade) starts at: `STATION_SOUNDS` (forge `craft_smithy`, brewing stand
  `craft_alchemy`, each with its file's length); the other stations are
  silent. `play_station_sound(pos)` keeps one entry per station node (end
  time, pending start of a queued sound): a start while the sound plays queues it once, never
  more (one `core.after`). A recipe made at such a station has no craft cue
  at its end (`state.lua`'s `craft_sound`). Fixture `tools/r45_pt8`.

### Enchants and upgrades as jobs

- **Enchants and upgrades as jobs** (`operation_jobs.lua`,
  `operation_box.lua`, Round 45 lane EU): the target slot
  `grug_craft_target` (`TARGET_LIST`, one slot made at join; the allow
  callback refuses everything else and returns nothing on accept, so later
  callbacks still judge, `operation_target(stack)`; a placement resends an
  open Crafting page; `return_operation_target(player)` hands a left item
  back at join and on an unlearn: give helper, overflow, else it stays). `start_operation(player, op_id,
  levels)` → ok, reason, `{code, max}` (queued while a job runs, Round 57; codes `busy` (the queue is full), `recipe`, `quantity`,
  `profession`, `station`, `cap`, `target`, `space`, `ingredients`) judges
  the slot's item with `grug_items.operation_result`, needs room for the
  result in the inventory once the materials are taken (`output_fits`), takes `operation_ingredients(op, stack)` × levels (one own material
  per upgrade level, a weapon also `weapon_extra`) and the item, then
  `begin_job` with kind `enchant`/`upgrade`, `operation` the id, `quantity`
  the levels, `target` the itemstring (a refused begin hands both back).
  The kinds' finish rebuilds the result from the stored item without the
  profession gate and calls `award_progress` (XP for enchants only:
  `progress` is set for enchants, never upgrades). `OPERATION_SECONDS`
  (enchant 5, upgrade 1 per level). The boxes register as `enchant` and
  `upgrade` craft boxes with their buttons (`OPERATION_FIELDS`); the
  upgrade warning is a two-step on `grug_craft.warned` (the item and count
  the last build showed with the warning). Fixture `tools/r45_eu`.
  Fixture `tools/r45_rg`: record shape, queries, refusals, the conversion
  against the base catalog, gear in its profession, durations, stations, the
  craft list and the removed APIs.
- Player APIs are `learn`, `unlearn`, `has`, `profession_level`,
  `crafts_in_tier`, `character_tier`, `record_craft`, `award_progress` and
  `can_craft_recipe`; every craft path and station operation (enchants
  count, profession upgrades play their sound only) goes through
  `award_progress(player,
  recipe[, crafts[, no_xp]])`, which checks the recipe's flag and counts a
  job's crafts at once (`record_craft(player, profession, tier[, crafts])`:
  min(crafts, XP left in the tier)); `register_on_award_progress(fn(player,
  recipe, items))` (Round 33) runs after each counted award with the items
  made (grug_achievements counts dishes and potions there; fixture
  `tools/r33_c2`: roster and progress flags). `profession_level` returns 0 when unlearned and effective T1–T6 when
  learned. Weaponsmith and Armorsmith have separate authorization/progression
  but share station id `forge` and node `grug_jobs:forge`; there is no
  `blacksmith` alias.

### Stations and workspaces

- **Stations** (`workspaces.lua`): furnaces and dual furnaces keep their dialog;
  authored ones have persistent per-player/per-station workspaces, player-placed
  ones share node inventories. The forge, the benches and the brewing stand
  are proximity stations (Round 45 lane ST): no `on_rightclick`, no lists, no
  activation LBM; a job checks one nearby. Digging or blasting a player-placed
  station releases every list its node meta still holds (an old crafting
  grid, an old stand's mixture, fuel and output) and every saved workspace
  record. A workspace record (node meta `grug_jobs:workspace:<name>`) is
  stored only while it holds an item or fuel left; an empty one is deleted
  at the save, and empty ones stored before Round 81 go at the station's
  first opening in a server run (P2-03). A lit brewing stand left by the
  old automatic brewing goes out at its next node timer. Automatic furnace/dual processing is
  universal and grants no progress. Stations and workspaces are
  `docs/design/inventory_equipment.md` §4 and `professions.md` §1.5, named
  tiered enchantments (including trinkets) `items_crafting.md` §6b, equipment
  separation `items_crafting.md` §3.0.3–§3.0.4 and wear `durability_repair.md`.
  `grug_jobs.open_trainer(player, profession, pos)` serves the six primaries
  and Alchemy: `grug_jobs.trainer_teaches(profession)` is false for the
  `STARTER_PROFESSIONS` (Cooking, which every character learns at T1 at its
  arrival and at every join, `grug_cooking/init.lua`, through
  `grug_jobs.learn(player, profession, quiet)`). The trainer-role readers ask
  it: `grug_mobs/start_npcs.lua` turns a Cooking trainer socket's NPC into the
  repair NPC at placement and at every activation (its claim): the title
  `grug_jobs.MENDER_TITLE` (one constant, "Grudge-Free Repairs"), the socket's
  profession kept, so `open_trainer` opens only `grug_repair.open_trainer`'s
  form and the trainer provider (`grug_repair/providers.lua`, any trainer
  socket; with the camp vendor's `camp_vendor` of Round 58 the only repair
  providers: no station repairs since Round 46) and the
  faction rule apply as to a trainer; `grug_map/providers.lua` marks it as a
  `service` with `grug_map_repair.png` and the title as label (no tooltip,
  Round 46); `grug_core/settlement_sockets.lua` only validates that a trainer
  socket names a profession, Cooking included (world data unchanged). The professions overview (Round 28 ruling 23,
  `grug_jobs/overview.lua`: `profession_overview` rows,
  `professions_formspec(rows, area)`) is drawn into the Crafting tab's box
  while no recipe is chosen; the Character page has no Professions mode
  since Round 45. Capital-only Riding uses `grug_mounts.open_trainer(player, entity)`
  with an authenticated Riding socket, never the generic profession hook.

## Crop registration

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- The Alchemy herbs' catalogue (`grug_gathering/catalog.lua`) is mapgen content: a change
  needs a map reset ([world_zones.md §11](../../design/world_zones.md#11-resource-loot-and-poi-budgets)).

- **Crop registration**: `grug_nodes` registers complete `grug_farming:soil` and
  `soil_wet` definitions before synchronous mapgen compilation, and exports
  `crop_visual(key, stage, sounds, context)` (the context: the mode and
  segment of a multi-node crop) and `bind_crop_soil_callbacks`. FARM binds
  its real callbacks once and owns the 18 crop families, timers and current-world
  activation. Mapgen has no FARM dependency; do not defer world authority.
  Tall crops keep state, timers and drops on the root; hidden helpers never own
  rewards. Multi-position growth/harvest preflights loaded, protected and exact
  matching nodes before mutation. Mature regrowers use right-click; annuals are
  replanted, while harvested Cane/Bamboo retain and reset the base.
  Since Round 30 soil without a growing crop checks its water once a minute
  (15 s under a growing crop; planting and regrowth re-arm 15 s), and the
  crop geometry LBM leaves a plant whose helpers already stand untouched.
  Since Round 48 the soil check under a growing crop also reads the crop's
  light (`default.plant_lit`, light 8 as at noon, defined with
  `default.PLANT_LIGHT` in the patched `default/functions.lua` and shared by
  papyrus and cactus) and pauses or resumes it on every check; profiles with
  `dark` (Cave Cap, Mushroom, Ember Moss) skip it. `grug_cooking.PLANTS` rows
  with `crop = false` (Salt Crust) are no crop. The Salt Pan
  (`salt_pan.lua`) runs on its own node timer; the tooltip pass
  (`tooltips.lua`, `grug_farming.apply_plant_tooltips`) runs at
  `register_on_mods_loaded`. The P9G sources' and items' looks are runtime
  overrides in `grug_gathering/presentation.lua`, never catalog fields (the
  catalog is hashed into the mapgen manifest).

## Fishing

- **Fishing (Round 14):** transient bobber, manual reel in a 1.5-second bite
  window, missed bites rearm; only successful catches wear the returned rod.
  A catch writes one line to the message feed (`grug_core.feed(player,
  "fish", notice)`), no catch chat spam. A rod wears `floor(65535 / 64)` per
  catch, so it breaks on the 65th. Death, leave, shutdown, invalid water/rod and distance clean up.

## Trinkets

- **Trinkets**: `grug_trinkets` owns the six special consumers and rebuilds an
  event-driven per-character equipment cache through the equipment-change seam;
  hot mana/heal/hit/kill/potion paths read that cache and never rescan slots.
  The same trinket may occupy both slots (0.53.1): additive specials sum up
  to their cap; a "highest" special (Last Light, Reclaimer's Mark) fires once
  from the stronger copy, strengthened by the other copy's tier share
  (`_grug_trinket_pair_share`, 5–30 %). Last Light uses one shared 120-second
  cooldown and maximum shield lifetime.

## Enchantments

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- An enchant's value is never stored free: `grug_items.enchant_value(stat, ilvl, tier)`
  derives it through grug_quality's one store path on every level or tier change.

- **Enchantments**: every enchant stores its stat, channel and tier (1–7) in
  `grug_ench`; its value is `grug_items.enchant_value(stat, ilvl, tier)`
  (`docs/design/item_tiers.md` §1.1), derived on write by grug_quality's one
  store path (rolls, enchants, upgrades, the crown, since Round 57 the
  authored stacks of `grug_items.make_stack(item, ilvl, affixes, player)`,
  the quest rewards' fixed enchants checked by
  `grug_items.check_affixes(item, affixes)`; nothing else writes an item
  level but the 0.45.0 migration's offline pin), never rolled.
  `grug_items.tooltip_text(item, player)` (Round 57) is the one tooltip
  text of an item for item buttons and images, which show only a
  definition's description: the lines the stack shows (equipment rebuilt
  through the store path's description, the reader's lines with a player),
  on a copy, not escaped (fixture `tools/r57_qsys`).
  `grug_items.refresh_capabilities(stack)` rewrites a stack's tool
  capabilities from its item level and enchants as that path does (a broken
  stack keeps them for the repair); the 0.45.0 migration's join part uses it. `grug_items.operation_plan(recipe, stack,
  player[, levels])` handles both station operation kinds
  (`grug_jobs.register_station_operation`: "enchant" and "upgrade") on one
  item behind the profession gate, `operation_result` the same without it (a
  job's end); `enchant_refusal(recipe, stack)` filters the enchant list and
  `upgrade_span(stack)` gives item level, cap (10 × material tier) and tier;
  a plan's `warning` names a replaced higher-tier enchant.
  `grug_items.crown_item(stack, player)` / `crown_preview(stack)` apply the
  Fallen Crown (the crown NPC owns the fee and the crown item). Gear drops
  (Round 33) are data in `grug_quality/init.lua`: `grug_items.DROP_CHANCES`
  (normal, elite and rare rows; zone leaders and war-camp captains roll the
  elite row), `BOSS_DROPS` (two items at each boss's fixed item level),
  `BAG_DROPS` (0.1 % by mob
  level) and `grug_items.enchant_tier(ilvl)` (T7 above 60); the pool is
  `grug_gear.drop_pool` (every equippable item of the tier). Every stack
  with an item level carries `grug_req_level` = min(ilvl, 60), written by
  `write_item_level_meta` (a first-bracket item keeps level 1 up to its own
  item level). Fixtures `tools/r33_c1` (drop rates, bosses, bags, pool,
  requirement, sale value; `drop_income.py` the income per band),
  `tools/r33_c4` (values, tiers, upgrades, crown, families),
  `tools/r33_c5` (crit, attributes, vendors, repair, potions, Crownbinder,
  culture shelf); the value rule and its data in `tools/r33_ds`. Family
  eligibility and replacement rules belong to the gear design. Per-stack appearance keys (`inventory_image`, `inventory_overlay`,
  `wield_image`, `wield_overlay`, `wield_scale`, `color`, `range`, `description`)
  override item definitions. Build texture modifier strings in one helper:
  malformed modifiers produce client-side image errors that may not appear in
  server logs. Equipment changes must notify the shared equipment seam.
  Since Round 28 the inputs are data: `grug_professions/data/enchants.json`
  (own material + the channel's loot + a mined or gathered family input per
  tier) and, since Round 33, `upgrades.json` (Round 45: the cost of one
  level and the families per profession), checked by the pure
  `enchant_data.lua` (`grug_professions/data/README.md`); the family owners
  are `grug_professions.FAMILY_OWNERS`.

## Materials and tier-rock gating

- **Materials & tier-rock gating** (`items_crafting.md` §3.0,
  `world.md` §2 R6):
  - **Contract (WP43, Round 24):** Bronze, Iron, Steel, Silversteel,
    Embersteel and Abyssal Steel are the six universal tiers. Their tier rocks
    (`default:stone`, `grug_materials:t2_stone`..`t6_stone`) lie in the bands
    y ≥ -100, -101..-300, -301..-500, -501..-700, -701..-1000 and below; the
    rock's tier, not y, gates the pick. `grug_materials` is the sole owner of
    `TIERS`, `TIER_BY_KEY`, `tier_at(y)`, `stratum_node_for(y)`,
    `level_for_tier(tier)`, `required_pick_tier(node)` and `DECORATIVE_ROCKS`.
    Consumers never copy a band boundary, harvest tier, rock name or
    race-region assignment.
  - Registry consumers use `RESOURCES`, `RESOURCE_BY_KEY`,
    `RESOURCE_BY_NODE`, `PROCESSED_MATERIALS`,
    `SIGNATURE_WOODS`, `RACE_REGIONS` and `DENSITY`,
    with the `resource`, `resource_for_node`, `resource_node` and `processed`
    accessors. `CURRENT_SCATTER_RESOURCES` is only the pre-WP40 placement
    roster. WP40 replaces its geometry with race-region columns; it does not
    replace or duplicate this taxonomy.
  - The natural-node contract is explicit. Picks carry
    `grug_pick_tier = 1..6`; generated ground carries `grug_natural = 1`;
    resources additionally carry `grug_resource = 1..6` (gems carry
    `gem = true` in `RESOURCES`; Diamond is the only T6 resource). Mapgen owners must
    add every new generated ground node to `NATURAL_GROUND_NODES` and apply
    `natural_groups(groups)` when registering their own nodes. Never infer
    natural ground from `is_ground_content`: the engine defaults that field
    to true even for saplings and decorations. `NATURAL_GROUND_SET` is the
    audited lookup, not a second extension point.
  - The engine gates tiers (level scale of Round 47): tier rock and
    resources of tier N >= 2 carry node `level = N`, tier 1 none, Iron Ore
    `level = 1` (`resource_level`: its `pick_level`), mirrored as
    `grug_pick_level`; the Wood and Stone picks carry `maxlevel = 0`, a metal
    pick of tier t `maxlevel = t` on `cracky`, `grug_resource` and
    `grug_pick_level`, so the client predicts a too-weak pick as unable to
    dig (no cracks). The `cracky`/`grug_resource` times carry the factor
    t / max(1, t - 1) and the gated nodes dig through `grug_pick_level`, so
    the shift kept every dig time (`build_pick_capabilities`). No other node
    may carry a `level`; the startup audit checks this and an engine dig
    matrix. Loose generated ground carries `grug_loose` (= its `crumbly`
    rating) and no level; shovels and axes carry
    `grug_shovel_tier`/`grug_axe_tier`. The engine's default dig sound is
    `default_dig_<group>` and these three groups have no such file, so a node
    of any of them without its own `dig` sound gets one after all mods load
    (`dig_sounds.lua`, Round 35: resources and gated rock the stone dig,
    loose ground the crumbly one). The `core.node_dig` wrapper re-checks
    protection and the engine rule for natural nodes (`mining_decision`
    returns `protected`/`too_low_level`/`too_hard`/`allowed`; `too_low_level`
    applies on any node a pick/axe/shovel above the player's level would dig,
    `TOOL_LEVEL_REQUIREMENTS`), and settles `register_on_harvest` after a
    successful resource dig; its own harvest callback awards gathering XP
    through `grug_xp.award_gathering`. There is no
    depth limit per pick and no dig-without-drop path. A
    `register_on_punchnode` handler and a `register_on_protection_violation`
    handler (online players only) show one rate-limited hint in the shared
    screen flash line (`grug_core.flash(player, message, color)`, which
    `grug_abilities.flash` forwards to in error red): the protection reason
    (`grug_core.protection_hint`) for any wield, "Requires a T<N> pick" or the
    broken-pick line (never with a selected skill). Code that refuses an edit
    on protected ground calls `core.record_protection_violation` so the player
    sees the reason. `max_drop_level` is a separate ordinary drop
    property and may remain non-zero. `build_pick_capabilities` and the
    six `PICK_PROFILES` are the verification/consumer seam and the dig-time
    authority: dig speed stays as in the game, with no separate calibration
    (2026-09-29 WP audit D8; WP22 and WP29 are closed). Canonical storage blocks, Iron Sign/Ladder
    and the 20 canonical metal stair/slab nodes are storage/building
    derivatives, not natural ground and never harvest-gated.
  - Emberglass and Abyssal Steel are the canonical names; no aliases or
    migration readers of development-era material names exist (release mode
    allows `register_alias` only for an item renamed from now on). WP26 owns
    furnace/alloy/storage recipes in `mods/ITEMS/grug_smelting`; its
    `grug_smelting.RECIPES` surface is consumed by the trader anti-loop audit
    because engine craft inspection cannot see dual-furnace recipes. The
    storage pack/unpack pairs and the dual furnace's own recipe are Basic
    recipes of the registry since Round 45; the smelting startup audit checks
    them there. Recipe ownership and remaining economy work are tracked in
    BACKLOG.

## Traders and money

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- One price module (`grug_traders/prices.lua`, pure `price_rules.lua`) pays every vendor:
  no price field on an item, no `set_price`; a new loot or gathered item gets a class and a
  tier, a crafted good is priced by its recipe; a new recipe passes the load audit (output
  ≤ inputs).
- A capital service takes over a gate resident (`grug_core.assign_service_socket`), no
  blueprint change.

- **Traders/gold** (shipped with WP7; `docs/design/economy.md`,
  `items_crafting.md` §3.8, `world.md` §7). **WP7 patterns
  (binding):**

### grug_money, the one money API

  - **`grug_money` is the ONLY money API.** One integer in copper units
    in player meta (100c = 1s, 100s = 1g, conversion display-only);
    `get/set/add/take` (take is atomic and never goes negative) plus
    `register_on_change`. **Never read or write the meta key directly** —
    the clamp and the change callbacks (the Inventory page's refresh is
    one) all live in those functions; there is no money HUD. `PlayerMetaRef:set_int` is a real 32-bit signed
    store, hence the hard ceiling `grug_money.MAX`.

### The Bag of Coins

  - **The Bag of Coins** (`grug_money/coins.lua`, Round 34) is the only
    money item: `withdraw` goes through `take_with_inventory`, the deposit
    slot is a per-player detached list that destroys the bag in `on_put`;
    the amount is item meta (`bag_amount`), never a price class. Round 46:
    mobs drop it (`grug_mobs.drop_coin_bag`, rolled in the loot gate
    `_item_drop_filter`, aggro.lua; grug_money is an optional dependency of
    grug_mobs), and the bag's own `on_pickup` deposits it at once
    (`auto_deposit_pickup`, the deposit slot's rules) while the player's
    toggle (`auto_deposit`, meta `grug_money:auto_deposit`) is on, else
    hands it to `core.item_pickup`. A credited bag sets
    `_grug_no_pickup_feed` on its item entity, so grug_core's pickup wrapper
    (`feed.lua`) adds no item line next to "Deposited Xc.". A mob definition
    with `_grug_no_coin_bag = true` (the Kraken; kept by
    `register_level_cfg`, since mobs_redo copies no custom def field into
    the entity) or a live mob with that field never rolls a bag
    (`grug_mobs.no_coin_bag`).

### One price module

  - **One price module owns every payout** (`grug_traders/prices.lua`,
    pure rules in `price_rules.lua`; Round 29): loot and gathered goods by
    class × tier factor, processed goods by their cheapest recipe, sold
    goods by 5% ceiling buy-back capped by their recipe (the recipe
    registry's records, the dual furnace's and the engine's cooking recipes;
    Round 45). It reads each
    item's tier from its own registration and resolves once when every mod
    has loaded; items carry **no** price field. Since Round 48 that first
    pass runs unchanged and a second pass in milli-copper
    (`price_rules.resolve_values`) prices only the items without a payout:
    the bulk table, storage blocks, crafted goods at half their material
    value, the never list ([economy.md](../../design/economy.md) §2).
    `grug_traders.sell_value` returns an item's value in milli-copper (0 =
    not sellable); `grug_traders.sell_price` the copper of a good that sells
    **singly**, and 0 for a lot good or an unsellable one;
    `grug_traders.sell_offer(stack)` the vendor's offer for any stack as
    `copper, lot` (lot 1 = singly, quality included; `0, nil` = not sold). A
    new loot or gathered item gets a class there, not a number in its def.

### grug_gear, the generated catalog

  - **`grug_gear` is a GENERATED catalog, never a hand-written list**:
    the six bracket catalogs come out of the §3.1/§3.2 curves at load
    time. Public surface for anything that sells gear:
    `grug_gear.BRACKETS` (the Common slot table of `economy.md` §2),
    `bracket_for_level`, `get_price`, `catalog[b].fixed/.extras/.all`.

### Armor pipeline and armor-rank gate

  - **Armor pipeline**: item `_grug_armor` values and every additive source
    aggregate as uncapped raw rating `A`. The deep Bulwark Unbroken capstone
    multiplies that aggregate by 1.65 and its emergency window then adds
    33 % of `K` at the Warrior's own level (Round 35; about 15 at level 50).
    For authoritative attacker level `L >= 1`, `K = 20 + 0.5*min(L,60) +
    8.5*max(L-60,0)` and reduction is `min(0.70, A/(A+K))`. Apply once to
    player combat damage before absorb, with the existing final `math.ceil`;
    environmental/fall damage has no attacker provenance and bypasses armor.
    Ratings carry one decimal (a piece is its share rounded to 0.1, at least
    1.0; Round 78) and every text shows one through `grug_gear.format_armor`
    (×10, a whole number); the math above keeps the inner unit.
  - **Armor-rank gate**: items carry `grug_armor_class` (cloth 1 <
    leather 2 < metal 3), classes carry `armor_rank`
    (`grug_classes.get_armor_rank`, no class = 1); the check sits in the
    existing group-filtered `allow_put` with a **throttled** chat
    refusal (the allow callback fires repeatedly while dragging), and a
    class change unequips what the new rank may not wear.

### Vendor NPCs

  - **Vendor NPCs use plain `mobs:register_mob`, NOT
    `grug_mobs.register_mob`** — that wrapper IS the level/XP engine and
    would give a shopkeeper a level, a health bar and aggro wrappers.
    `type = "npc"` is what makes them permanent (it exempts them from
    all three mobs_redo removal paths); a **truthy `do_punch` return**
    is what makes them invulnerable (the api.lua precedence gotcha
    above). A settlement's vendors stand on the `vendor` sockets its
    blueprint exports (`grug_core/settlement_sockets.lua`, placed by
    `grug_mobs/start_npcs.lua`); WP7's fixed capital offsets and their
    placement pass are gone (Round 81). At mods-loaded
    `grug_traders/vendors.lua` reads from the registry, never from a
    hard-coded list, whether every capital is socketed, and logs an error
    for one that is not (that capital then has no traders). The twelve **profession shop**
    vendors (butcher, smith, fishmonger, baker, tailor, mason, brewer,
    bowyer, herbalist, armourer, tanner, embalmer) are socket-only, carry no
    race of their own — the settlement key answers that — and only `smith`
    and `armourer` reach the full T1 gear tab (Bowyer and Tanner filtered
    views). Since Round 33 the gear shelf is the T1 catalog only, with no
    rotation; the buy-back of unsold gear comes from its reference price
    (`prices.lua` `reference_prices`).

### Capital services on gate residents

  - **Capital services on gate residents** (Round 33): the Crownbinder
    (`grug_traders:crownbinder`, `crown.lua`) and the Decor Merchant
    (`grug_traders:vendor_culture`, shelf `culture`) take over the gate
    resident of each capital's goldsmith and woodcarver service plot through
    `grug_core.assign_service_socket` (roles `crownbinder`,
    `culture_vendor`), as the Housing Steward does. The crown operation is
    one call, `grug_traders.crown_operation` → `grug_items.crown_item`
    (the window shows `grug_items.crown_preview`; a worn item the wearer
    could no longer wear afterwards is not offered); the payment is one
    `grug_money.take_with_inventory` with the fee `grug_traders.CROWN_FEE`
    (14 800c, checked by `income.py --check`), one Fallen Crown and the
    crowned item. The Decor Merchant's shelf is `grug_decor`'s harvested kit
    (`stock.lua` `culture`, four price bands); vendors buy blue ×3 and gold
    ×6 of the Common payout (`grug_traders.stack_sell_price`,
    `price_rules.QUALITY_FACTOR`).

### The camp vendor

  - **A Miner's Guild vendor** (Round 58): a vendor definition in
    `grug_traders.vendors` with `guild = true` gets the window's third mode,
    Trade-in (`trade.lua`; it opens on it): "Miner's Guild" (never a
    guild's proper name: those belong in texts and on buildings), the rank
    and the balance, and a row per exchanged item from
    `grug_guild.trade_in_rows`, its All button `tradein_<catalogue index>` and quantity buttons
    `tradein1_`, `tradein5_`, `tradein10_` with the same index,
    traded through `grug_guild.trade_in` after the row is re-checked against
    the one shown. The camp vendor and the
    guild house's exchange counter carry the field. The guild's consumables
    pay their catalogue `sell_copper` (`prices.lua`). A guild vendor with
    `guild_page = true` (the camp vendor, lane CAMPNPC) has the reputation
    page as its Buy mode: `grug_guild.vendor_rows`, buttons
    `repbuy_<index in catalog.CONSUMABLES>` for the rows the rank unlocks
    (`session.rep_shown`, the click's cross-check), bought through
    `grug_guild.buy`. `repairs = true` (the camp vendor) shows a Repair
    mode in the same vendor session. It uses a server-owned repair quote and
    `grug_repair.quote_formspec`; serial-prefixed actions reject replay after
    a quote refresh, and every action rechecks the authored provider socket
    (`grug_traders.open`'s fifth argument `origin = {settlement, socket}`,
    plain strings from the entity's `_grug_start`/`_grug_socket`) through
    `grug_repair.provider_permitted`. The
    Miner's Guild Exchange (`grug_traders:guild_exchange`) takes over each
    capital's `capital_services.GUILD_HALL.exchange` socket as the service
    role `guild_exchange` (`grug_core` `SERVICE_ROLES`), like the
    Crownbinder. The Stonewright (`grug_traders:stonewright`, Round 70)
    takes over `GUILD_HALL.stonewright` the same way; `stonewright = true`
    gives it one page without modes, the recipes of
    `grug_guild.stonewright_rows` with the Trade-in's lots, locked by rank
    (`stoneN_<index>`, `stoneall_<index>`), made by
    `grug_guild.stonewright_make`.
    The Expedition Registrar has its own core socket `expedition_registrar`
    a few nodes outside each capital's great hall door (0.75.3, map reset;
    at the waystone plaza approach from 0.73.1; the six
    `wp13/<capital>.lua` compositions; `grug_expeditions/registrar.lua`), a
    villager like the Housing Steward; the guild clerk stays an ordinary
    resident. Its window, like the other service windows, stays open only
    while the player is within 8 nodes and the NPC within 2 nodes of its
    socket (`grug_core.npc_window_permitted`, Round 81).

### No detached inventories in trade UIs

  - **No detached inventories in trade UIs.** The reference
    implementations (VoxeLibre `mobs_mc/villager.lua`, LotT
    `lottmobs/trader.lua`) move items through detached
    `wanted/input/offered/output` lists — that loses whatever sits in
    the input list when a player disconnects mid-trade. Every transfer
    goes directly against the player's own inventory (purchases through
    `grug_inventory.give`, sales from `main` and the bags), the vendor's
    "stock" is a computed list of names and prices, and **every formspec
    action re-validates from scratch** (session, distance to the stored
    POSITION not an ObjectRef, access rule, and prices/counts recomputed
    server-side against the snapshot the player was shown).

### Startup audits

  - **Three startup audits** in `grug_traders/init.lua`
    (`register_on_mods_loaded`; no warning/error finding when clean —
    one informational action line, the function-drop audit count,
    always prints): every mob drop has a
    price; no vendor buy/sell spread that prints money (discount
    included); no craft/cook recipe whose output is worth more than its
    priced inputs (the §3.8 anti-loop rule — the real case was smelting
    a 3c iron lump into a 5c steel ingot). Add prices, don't disable
    them.

## Miner's Guild

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- A change to the lift node's fields that the settlement digest reads (`world_nodes.lua`'s
  comment at the lift) belongs in `grug_mapgen` in a map-reset round, never in an override.

- **`grug_guild` (Round 58):** the catalogue, its API, the files and their owners and the saved keys: [miners_guild.md](../../design/miners_guild.md) §10.
  Reputation (`store.lua`): two integers per character and guild in player
  meta, keyed by faction id (`grug_guild:lifetime_<faction>`,
  `grug_guild:balance_<faction>`); `add` and `spend` fire
  `register_on_change`, and `add` fires `register_on_rank_change` only when
  the rank rose (the achievement counter `guild:rank` reads
  `grug_guild.highest_rank` live, so nothing is copied). Every display of
  rank and balance goes through `grug_guild.summary`, `format_points` and
  `reputation_formspec` (the picked icon `grug_guild.REPUTATION_ICON`,
  `grug_guild_reputation.png`, then the number; text "Reputation 1,234"
  when the icon is nil). The trade-in (`exchange.lua`) counts and takes over
  `grug_inventory.consume_lists` like the Sell tab's lots (remove_item by
  name, every check first). `/guild_rep <player> <points>` (privilege
  `server`) adds reputation for tests and the GUI checklist. The vendor page
  (`vendor.lua`, CAMPNPC): `vendor_rows` and `buy` (room checked before the
  spend, nothing saved of its own); the window is `grug_traders`'.
- **The guild's people** (Round 58 CAMPNPC): the 36 foremen
  (`r58_foreman_<camp id>`, role `foreman_t<tier>`) and the six leaders
  (`r58_guild_leader_<capital>`) are quest NPCs of `grug_quests/npcs.lua`
  (it reads `grug_mapgen.mining_camps` and `capital_services.GUILD_HALL`;
  [quests.md](../../design/quests.md) "The Miner's Guild givers"); the Camp
  Vendor and the Miner's Guild Exchange are `grug_traders` vendors; the camp
  vendor's repair is `grug_repair`'s provider kind `camp_vendor`
  (`providers.lua`: the camp's `vendor_camp` socket, distance 8, the camp's
  faction).
- **The mining effect** (`effect.lua`, `items.lua`, Round 58 CONSUME):
  runtime state per player name (the effect's own end time from
  `core.get_us_time`, the current Remains `{pos, token}`, the marker HUD
  ids), never the status record: `grug_core` clears statuses in its own
  leave and death callbacks first. Its timers are `core.after` chains per
  running effect (the end, the 30 s save, Ore Sense's 60–120 s mark,
  Treasure Hunt's `check_seconds` check), no globalstep. Saved: player meta
  `grug_guild:effect` only. Helpers beside the contract:
  `grug_guild.band_text(tier)` (the band in words), `ore_sense_find(pos,
  tier, range)` (the one search), `remains_spot_ok(pos, tier, name)` (the
  placement rules); `_remains_on_timer` and `_remains_on_dig` are the
  Remains nodes' hooks into the effect. Fixture: `tools/r58_consume`.
- **The lift** (`lift.lua`, Round 58 LIFT): `core.override_item` of
  `grug_mapgen:guild_lift` with `on_rightclick` only (the settlement
  semantic digest reads the static fields, `world_nodes.lua`'s).
  `grug_guild.lift_at(pos)` finds the camp (`grug_mapgen.guild_rooms.room_at`
  for a room's lift, `grug_mapgen.mining_camps.near(pos, 0)` for the surface
  lift) and returns `{camp, level, levels}`; `use_lift(player, pos)` refuses
  another faction through `grug_factions.refuse` and shows the list
  (`grug_guild:lift:<n>`). A trip is `grug_home.travel` (read at run time:
  grug_home is no dependency) to the room's `lift_cell` (arrival
  `room.arrival`) or the camp's `lift` socket (arrival the first safe cell
  in front of, behind, then beside the node by its `4dir` param2); the
  check on the server step after the emerge wants the same faction, out of
  combat, within 8 nodes of the lift. Runtime dialogs per player name only,
  dropped at leave and death; nothing saved. Fixture: `tools/r58_lift`.
