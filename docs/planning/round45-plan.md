# Round 45 — Crafting rework: recipe lists, jobs and professions

Coordinator: Claude (Opus 5.5), drafted 2026-10-08. This round builds
**Round B** of the [UI and crafting rework plan](ui-crafting-rework-plan.md)
("the spec" below; its §2 rulings 16–34, §4 and §6 are this round's design).
Layout: wireframe v1 (<https://claude.ai/artifact/8XM4hJggJyJSpuigRyg9jJ>),
the Crafting artboard. Status: **draft**, waits for the user's go after
Round 44 is complete.

The 3×3 grid and the recipe books go. Recipes become ingredient lists in
five areas (Basic, Cooking, two primaries, Alchemy); every craft is a timed
job of the player's own, with a shared output area. Gear comes only from
professions; item levels move to the ladder 1/11/21/…; upgrades go +1 per
level. Profession stations work by proximity; only furnaces keep a dialog.
The release carries the second `migrate` step (0.45.0).

Routing default (agent model policy; the user decides per session): Claude
coordinates, Opus implements and reviews; no Astra lane (the progress bar
is generated in code).

## 1. Lanes and waves

| Lane | What | Wave | Kind | Waits for |
|---|---|---|---|---|
| IL | Item level ladder: brackets 1/11/21/…, trinkets on the ladder, requirement = item level from 1, the docs and exports that read it | 1 | code + data | Round 44 complete |
| RG | Recipe registry: one ingredient-list model, ~620 grid routes converted, gear moved to professions, durations, stations, visibility; the engine craft path, the craft list and the books removed; every craft-API consumer switched; old crafting fixtures retired or adapted | 1 | code + data | Round 44 complete |
| JB | Jobs: per-player job state, start checks and consumption, completion (online timer, catch-up at login and open), cancel and refund, XP, achievements, the HUD feed, the output area and Take all | 2 | code | RG |
| UI | The Crafting tab: area tabs with tier progress, paginated list with search, "Craftable only" and ×N, the crafting box variants, the output area, the progress bar, the quantity-field rules | 3 | code | JB |
| ST | Stations, cooking, alchemy: proximity stations without dialogs, the dig refund kept; cooking known from the start, its trainers ordinary NPCs; alchemy makes finished potions at the brewing stand, mixtures and automatic brewing go | 3 | code + data | JB |
| EU | Enchants and upgrades as jobs: target slot, preview, filtered list; +N upgrades with caps, cost and warning | 4 | code | UI, IL |
| PT | The user's playtest of IL–EU | 5 | GUI | EU, ST |
| MS | Migration step 0.45.0: item-level pin, craft list emptied, mixtures deleted, per-character description rebuild | 5 | code + test | IL, RG, ST (after PT findings are in) |
| D | Documentation, version 0.45.0, the declaration's `migrate` entry | 6 | docs | last merge |

Estimates (unmeasured, for planning only): IL 4–6 h, RG 12–16 h, JB 8–10 h,
UI 8–12 h, ST 6–8 h, EU 6–8 h, MS 4–6 h, D 2–3 h, each code lane plus its
review. RG is the largest lane and carries the most fixtures.

## 2. Rulings

The design rulings are the spec's §2 items 16–34 and §4 (durations, XP
sources, upgrade cost, visibility and gear recipes were decided on
2026-10-08, items 30–34). Round-specific (the user, 2026-10-08):

1. **Order:** after Round 44 (the frame, the short inventory view and the
   give helper are this round's base) and Round 43 (the migration tool).
2. **Mixtures are deleted**, not refunded (spec §6).
3. **Old workstation contents are discarded** as dead node meta; digging an
   old player-placed bench still hands its contents out (spec §6).
4. **A playtest (PT)** before the migration step and the docs: the crafting
   feel (durations, list, output area) is judged in the game, and its
   findings may still change values before MS freezes the step.
5. **No crafting on main between RG and UI** (coordinator default, pending
   the user, §8): the lanes merge in one go during the round; the user plays
   only at PT.
6. **Craft-grid leftovers** (coordinator default, pending the user, §8):
   stacks that do not fit offline are handed over at the next join through
   the give helper; anything still left goes to the crafting output area;
   only if that is full too, it drops at the character's feet.

## 3. Shared conventions (coordinator defaults; lanes may refine them in their report)

- **Recipe record** (RG, spec §4.1): `{id, output, count, ingredients =
  {{item = name | group = name, n = count}, …}, area, profession, tier,
  time, station, progress}`; `area` is `basic`, `cooking`, a primary id or
  `alchemist`; `station` nil or a station kind; `progress` false for Basic.
  A query API by area, by id and by output; nothing reads engine crafts.
- **Job state** (JB): player meta, one key, serialized; recipe id,
  quantity, consumed stacks (for the refund), the target stack for
  enchants and upgrades, start and end in `os.time()`.
- **Output area** (JB): player list `grug_craft_out`, 4 slots, take-only;
  Take all through `grug_inventory.give` (Round 44).
- **Consumption order** (JB): bags, `main[9..]`, the hotbar last; only stacks
  without metadata count as ingredients, for item and group entries alike —
  the ×N count (UI) uses the same rule.
- **Refund fit check** (JB): a cancel needs a dry run without side effects;
  it uses Round 44's `grug_inventory.fits` (IH).
- **Progress bar** (UI): one vertically stacked texture, 64 fill frames +
  32 full frames (spec §4.5), generated by a script in the lane and checked
  in.

## 4. Lanes (goals; the briefs add file facts)

Every lane classifies its change and updates the design docs whose rules it
changes (`items_crafting.md`, `professions.md`, `item_tiers.md`,
`inventory_equipment.md`, `economy.md` as touched).

### 4.1 Wave 1 — IL, the item level ladder

- `grug_gear.BRACKETS` base item levels 1/11/21/31/41/51, cap 10 × tier;
  the requirement is the item level from level 1, capped at 60; the
  bracket-1 exception goes (`grug_gear/init.lua:45-62`,
  `grug_quality/init.lua:236-247`).
- Trinkets move to the same ladder (`grug_gear/trinkets.lua:4`, their baked
  description lines). Consumables stay off the ladder.
- Regenerate `item_tiers.md` (`tools/r33_ds/build_doc.py --check`) and the
  fixture that asserts the bracket-1 exception
  (`tools/r33_c1/portable_test.lua:503`); the web-data export holds no item
  levels and only stays green (`export.lua --check`); the income check
  (`tools/r29_e4/income.py --check`) and vendor prices stay green.
- Classification: changes saved meaning for unmodified items → covered by
  MS's pin (migrate).

### 4.2 Wave 1 — RG, the recipe registry

- The registry (§3) and the conversion of every grid route
  (`basics_routes.lua` and the profession registry) into ingredient lists,
  generated where possible; loop-made families (stairs, slabs, walls) stay
  loop-made.
- Gear and trinket recipes move to their profession (spec §2.23, §2.34:
  today's ingredients, profession tier = item tier, station nearby, base
  level of the tier); arrows stay Basic.
- Durations per spec §2.30; stations per profession (forge for weaponsmith
  and armorsmith, the four benches, the brewing stand).
- Visibility: all recipes per area (§2.33); `discovery.lua`, the seen list
  and the starter flags go.
- Removed: shaped matching, the `register_craft` adapters, the craft-predict
  and on-craft gates (`grug_jobs/stations.lua`), the books (`grug_jobs/ui.lua`
  book parts), the inventory `craft` list. The engine re-creates `craft`
  with 9 slots at **every** load and the database loaders only resize lists
  that are stored (`database-sqlite3.cpp:587-591`,
  `database-postgresql.cpp:561`, `inventory.cpp:1033-1038`), so the game
  sets its size to 0 at every join; a stored size-0 list then sticks.
  Furnace, dual-furnace and alloy recipes stay.
- Every consumer of the engine craft API reads the registry or is adapted:
  vendor prices, the economy load audit (runs at load, so the smoke boot
  covers it), `grug_materials/audit.lua`, `content_curation.lua`, and the
  **smelting startup audit** (`grug_smelting/recipes.lua:206-243`, which
  `error()`s at load when the grid pack/unpack recipes are gone), plus
  `grug_professions/base_recipes.lua:62,139`, `grug_jobs/registry.lua:443`,
  `ui.lua:176`. `mobs/api.lua:922` is a cooking query and stays.
  `tools/r28_regions/run.sh` after the recipe change.
- RG also owns the lines of `grug_jobs/workspaces.lua` that call what it
  removes (`recipe_for_craft` :133, `station_book_button` :223 — drawn in
  every workspace dialog, furnaces included — `recipe_for_output` :323,
  `open_book` :373): the book button goes from every dialog; benches and
  the brewing stand show "Crafting moved to the Crafting tab" until ST.
  Nothing on main may call a removed function after RG's merge.
- The crafting fixtures (about 31 tool folders reference `grug_jobs`; the
  recipe-book, discovery and grid ones first) are adapted to the registry or
  retired with a one-line reason each; `tools/run_fixtures.sh` stays green.
- Until UI merges, the old Crafting page is replaced by a minimal stub
  (the lane names it): main has no crafting between RG and UI (ruling 5).

### 4.3 Wave 2 — JB, jobs

The job model of spec §2.19–2.22 and §4.4: one job per player; start checks
(station within 4 nodes once, output space incl. partial stacks and several
stacks above `stack_max`), consumption at start (§3); completion by a timer
only for online players with a job, caught up at login and on opening the
tab; the result into the output area, gear through
`grug_items.crafted_output` (base name, quality, item-level meta,
description, weapon tooltip; `grug_quality/init.lua:814-829`, today called
from `stations.lua:106` and `workspaces.lua:137`); XP = min(items, XP left
in the tier) for XP sources (§2.31), and a saturated profession still
advances its tier at job end as `record_craft` does today
(`grug_professions/state.lua:132-168`); the achievement counters get the
job's quantity (`grug_achievements/init.lua:205-210`); the HUD feed line
("Hearty Stew ×10 is ready") when online; cancel refunds everything or is
refused without room (the dry-run fit check, §3); a Stop after the end time
completes; unlearning a profession during a job lets the job finish without
XP; Take all. Fixtures for every rule, including a server restart in the
middle of a job.

### 4.4 Wave 3 — UI, the Crafting tab

As in the wireframe: area tabs (Basic default) with the tier progress of
profession areas; the list (10 per page, "Page x of y", search at most once
per second, "Craftable only", ×N from one inventory pass); the crafting box
(ingredients with have/need, maximum, quantity field for stackables with
Max, the green or grey XP hint, the station hint with the button disabled);
the output area with the job status, the green indicator and Stop/Cancel;
the quantity-field rules of spec §4.3; the progress bar (§3) with
`frame_start` on every render; resends only at start, end and cancel, and
never on a pure scrollbar event. The professions overview moves here: the
Character tab's fifth mode goes (`grug_professions/character_tab.lua`, the
mode in `grug_inventory/pages.lua`, the refresh call in
`grug_professions/state.lua:183-185`). Help and trainer texts that name the
old crafting ("Open Inventory > Crafting", books), cooking, brewing and
mixtures are rewritten from ST's merged result (ST merges first). Measured:
the tab's formspec bytes per page and the sends per job.

### 4.5 Wave 3 — ST, stations, cooking, alchemy

- Forge, benches and brewing stand become proximity stations: no
  `on_rightclick`, no lists; the dig and blast hooks stay (old contents come
  out when a player-placed station is dug). Furnaces and dual furnaces keep
  their dialog and per-player workspaces.
- Cooking: known from the start, tiers kept: at every join a character who
  does not know cooking learns it at T1 (new and existing characters); simple
  dishes as recipes, good dishes raw + furnace finish as today; quest cooks
  unchanged.
- The 12 cooking trainers become ordinary NPCs through a runtime mapping in
  the files that read `role == "trainer"` (`grug_mobs/start_npcs.lua:1442`,
  `grug_map/providers.lua:65`, `grug_repair/providers.lua:35`), applied at
  activation, so no world-generation data changes; talk quests that point at
  them are checked.
- Alchemy: recipes produce finished potions and elixirs at the brewing
  stand; the automatic brewing goes; the herb-gathering gate stays. Mixture
  items stay **registered as inert items** (stable ids; they may sit in
  chests or come out of dug stations) and are no longer made or used.
- The 163 item objectives checked for targets that become profession-only or
  disappear (spec §4.7); `tools/r28_design/validate.py --game` green.

### 4.6 Wave 4 — EU, enchants and upgrades

- Enchanting (spec §2.24, §4.6): the target slot, the arrow, the preview
  (`item_image` + computed tooltip), the list filtered to valid enchants;
  5 s; the item taken in at start, returned on cancel, the result in the
  output area; validity rules as today in `grug_quality`.
- Upgrades (spec §2.26, §2.32): "+N levels" with Max to 10 × the item's tier,
  the profession at that tier or higher; cost per level one family material
  (weapons plus a stick); 1 s per level; the permanent warning and the
  yellow "Upgrade anyway" when the target exceeds the player's level; no XP.
  An item already at or above its cap (crowned items, T7 boss gear) shows
  "already at the cap", never a negative +N. The crown stays a trader
  operation. EU runs `tools/r33_ds/build_doc.py --check` (it changes
  `upgrades.json`).

### 4.7 Wave 5 — PT and MS

- **PT:** the user's playtest of the crafting tab, jobs, stations,
  enchants, upgrades and the ladder on a fresh world; findings become fix
  commits in the owning lane's files before MS.
- **MS**, the step `0.45.0` (Round 43's layout, the baseline rule): for every
  character, (1) delete alchemy mixtures from every list; (2) move the
  `craft` list's stacks into empty slots of `main[9..]`, the bags, then the
  hotbar (the tool cannot read `stack_max`, so only empty slots), and store
  `craft` with size 0 when it is empty; what does not fit stays in `craft`
  for the online handler (ruling 6); (3) pin the item level and requirement
  into `grug_ilvl` / `grug_req_level` **only for gear stacks without an
  item-level meta** (missing or 0), from a table of the 0.44 definition
  values `_grug_ilvl` / `_grug_req_level` (unchanged since Round 33, so they
  hold for every world from 0.41 to 0.44); crafted, upgraded, crowned and
  rolled gear already carries its own and is never overwritten; (4) set the
  character marker. The marker's online handler (same lane) runs at the next
  join before the size-0 hook: it hands any `craft` leftovers over (ruling 6),
  then rebuilds item descriptions (`regenerate_description`).
  Its test builds the world from the **0.44.0 commit** (a worktree), then
  the step, a headless boot, a join, the checks. MS owns the version
  change: `game.conf` and the declaration's `version` to 0.45.0, `0.45.0`
  into the declaration's `migrate` list and into `grug_core.migrations`,
  together (`check_upgrade.py` green on every commit).

### 4.8 Wave 6 — D, documentation

The plan's completion with the GUI checklist; STATUS, the AGENTS pointer,
ROADMAP, BACKLOG, README, CHANGELOG (0.45.0; the version itself is MS's);
the spec's status line for Round B.

## 5. Rules

- Stock clients only; plain Lua 5.1; the web build is a target.
- No per-tick work beyond the job timer for online players with a running
  job; the ×N count is one inventory pass per page view or click.
- Formspec bytes and sends per job reported before and after (the old
  Crafting page as the comparison); numbers are comparisons, never targets.
- Release mode: IL, RG, ST and MS together are this release's **migrate**
  step; every other change is compatible. A lane that finds another saved
  state the new code cannot read stops and reports.
- The economy checks stay green after every recipe change
  (`income.py --check`; the price audit runs at load and is covered by the
  smoke boot).
- No world-generation change: no seed fleet. Stations already placed in
  capitals stay where they are.

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates);
RG and ST run `tools/r28_regions/run.sh` and `tools/r28_design/validate.py --game`.

GUI checklist (desktop and web):

- The Crafting tab: areas, paging, search, "Craftable only", ×N counts; a
  Basic craft of 1 and of 20 with Max; the green and grey XP hint.
- A job: start, close the window, reopen (the bar continues), log out and
  in (it finished or continues), the HUD line; Stop with and without room;
  the output area full, partly full, Take all.
- A profession craft at its station and out of range ("Requires: … nearby").
- A weapon made by the weaponsmith at its tier's base level; no gear in Basic.
- An enchant (preview, 5 s, cancel returns the item); an upgrade +N with
  Max, the warning above the player's level, the cap at 10 × tier.
- Cooking without a trainer; the former cooking trainer is an ordinary NPC
  without a trainer dialog or map icon; a good dish finished in the furnace;
  alchemy at the brewing stand makes finished potions; benches and the
  brewing stand open no dialog; a furnace still does, without a book button.
- The professions overview sits in the Crafting tab and is gone from the
  Character tab; Take all spills into the bags when `main` is full.
- An old world (0.44) migrated with the tool: equipped gear keeps its level
  and stays wearable; tooltips are right after the first join; craft-grid
  items are back in the inventory; mixtures are gone.

## 7. Orchestration notes

- Start state: main after Round 44's lane D.
- Process budget: at most 8 Lua processes at once; engine runs only through
  `tools/luanti_headless.sh`.
- Files per lane (the briefs list exact files):
  - IL: `grug_gear/init.lua`, `trinkets.lua`, `grug_quality/init.lua`
    (requirement), `tools/r33_ds`, `tools/web_data`, the bracket fixture.
  - RG: `grug_jobs/` (registry, stations, ui book parts, discovery,
    basics routes, the `workspaces.lua` lines of §4.2), `grug_professions/`,
    `grug_artisans`, `grug_smelting/recipes.lua` (audit), the consumers
    listed in §4.2, the crafting fixtures.
  - JB: a new jobs module in `grug_jobs`, `state.lua` (XP), achievements
    hook, `grug_core` feed call.
  - UI: `grug_jobs/ui.lua` (the new tab), `grug_inventory/help.lua`,
    `grug_jobs/trainers.lua` (texts), `grug_professions/character_tab.lua`,
    the professions mode in `grug_inventory/pages.lua`, the bar texture and
    its script.
  - ST: `grug_jobs/station_nodes.lua`, `workspaces.lua` (after RG),
    `automatic.lua`, `grug_cooking/`, `grug_alchemy/`, `grug_brewing/`, the
    trainer-role readers of §4.5.
  - EU: `grug_quality/init.lua` (operations), `grug_jobs/station_operations.lua`,
    `grug_professions/data/upgrades.json`, the UI's enchant and upgrade boxes.
  - MS: `tools/migration/steps/`, its test, the marker handler in the game,
    `grug_core.migrations`, `game.conf`, `tools/web_data/upgrade.json`.
- Merge order: IL, RG, then JB, then ST, then UI, then EU, then PT fixes,
  MS, D. IL and RG run in parallel and share no files: base gear recipes live
  in `grug_professions/base_recipes.lua:75-137`, trinket recipes in
  `grug_artisans/goldsmith.lua`; `grug_gear` has no recipes (RG only removes
  its dead `register_on_craft`, `grug_gear/init.lua:784`, in a separate
  commit).
- Decided during the round: the stub page until UI (RG), PT's findings.

## 8. Open questions for the user

Pending the user (from the plan review, 2026-10-08):

- Rulings 5 and 6 above (coordinator defaults).
- Mastery requirements: spellbooks (`tailor.lua:97`, mastery 2 at every
  tier) and bags (`tailor.lua:69-87`, `leatherworker.lua:51`) need a mastery
  band today; keep them under "profession tier = item tier"?
- Profession XP for bags and intermediates (bundles, bolts): ruling 31 lists
  gear, trinkets, potions, dishes and enchants. Do bags count?

Measured during the round and reported: how many grid routes convert
automatically and which need hand edits (RG).
