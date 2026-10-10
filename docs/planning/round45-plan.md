# Round 45 — Crafting rework: recipe lists, jobs and professions

Coordinator: Claude (Opus 5.5), drafted 2026-10-08. This round builds
**Round B** of the [UI and crafting rework plan](ui-crafting-rework-plan.md)
("the spec" below; its §2 rulings 16–34, §4 and §6 are this round's design).
Layout: wireframe v1 (<https://claude.ai/artifact/8XM4hJggJyJSpuigRyg9jJ>),
the Crafting artboard. Status: **complete** (2026-10-09, version 0.45.0,
**migrate**; [completion](#completion-2026-10-09)).

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
5. **No crafting on main between RG and UI:** accepted; the user plays only
   at PT.
6. **Craft-grid leftovers:** stacks that do not fit offline are handed over
   at the next join through the give helper; anything still left goes to the
   crafting output area; only if that is full too, it drops at the
   character's feet.
7. **Mastery bands go:** spellbooks and bags no longer need a mastery band
   (`grug_professions/state.lua:223-226`, `tailor.lua:69-97`,
   `leatherworker.lua:51`); profession tier = item tier for everything (RG).
8. **Bags give profession XP;** intermediates (bundles, bolts and other
   `material` recipes) do not (JB).

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

None. The plan review's questions were answered on 2026-10-08 (rulings
5–8). Measured during the round and reported: how many grid routes convert
automatically and which need hand edits (RG).

## Completion (2026-10-09)

Every lane is merged on main; this lane D (this section and the status
owners) follows MS on main `4a892fd6`. Main's first-parent line from
Round 44 with hotfix 0.43.1 (`c913dbbe`): IL (`73a5806f`), RG
(`a86098ad`), JB (`0b7b1331`), ST (`0dd375b8`), UI (`ca9cd103`), EU
(`2f918739`), then the playtest phase: PT1 (`d57ec82f`), PT9 (`8d32c84c`,
follow-up `a39b22ee`), PT7 (`0bee63b9`), PT6 (`1b51a9bb`, follow-ups
`c887d1b7` and `bff2d5b9`), PT3 (`b9ff54b8`, its review Low `570ed6b1`),
PT8 (`02f27c39`, follow-up `716dc58e`), PT2 (`6751b892`, follow-up
`74f78ece`), PT5 (`66381441`), ART (`5ed74763`), and MS (`4a892fd6`).
**Push:** the user pushed `2f918739` (Round 45 up to EU, still labelled
0.44.0) on 2026-10-09; no realm runs it, the production server is on
0.41.0. **0.45.0 is pushed on the user's word (2026-10-09) after the
round-end gates, as the merge commit of lane D.** It is the second release
with a declared
step: production moves 0.41.0 → 0.45.0 in one tool run that applies 0.44.0
and 0.45.0 (MS tested this chain).

Reviews, each by an independent Opus, every fix made by the lane itself
before its merge:

- **IL** MERGE; the follow-ups (the wood and stone gear sentence in
  `items_crafting.md`, the stale `TIERS[].ilvl` kept with a comment)
  fixed (`ef6ae6f2`).
- **RG** MERGE; one Low (the items probe read Basic records as profession
  routes), fixed (`c0a653e2`); the retired-fixture list added to the
  report.
- **JB** MERGE; three Lows (a nested rebuild during completion, a job of an
  unknown kind dropping its target, `begin_job` over a running job),
  fixed (`143154ff`).
- **ST** MERGE with one Medium for the user (start towns lost their only
  repair point); the user's answer, the repair-only NPC on the former
  Cooking sockets, reviewed MERGE (`e093683a`).
- **UI** MERGE AFTER FIXES; one Medium (a crafted client could stall the
  server through the field trim), fixed (`6d56495e`); one Low (the bar
  restarts at its last sent frame on reopen) accepted by the user; the
  delta MERGE.
- **EU** MERGE; two Lows (the target slot's allow callback ended the chain,
  an item left in Target), fixed (`78534db3`).
- **PT2** MERGE; the delta (7 rows) MERGE AFTER FIXES with one Low/Medium
  (a draft Claim Stone status ran into the Cloak label), fixed
  (`7c0671a1`).
- **PT3** MERGE; one Low (a stale sentence in `inventory_equipment.md`
  §4), fixed on main (`570ed6b1`).
- **PT5** MERGE AFTER FIXES; one Medium (shift-click from `main` on the
  Crafting tab moved items into bag 1), fixed (`c866bcfe`).
- **PT6** MERGE; the first follow-up MERGE AFTER FIXES with one Medium (a
  fall into a shallow pool could kill, depending on step timing), fixed
  (`db13ee78`); its two Lows (lava one node deep, a mid-air summon
  cancelling fall damage) became the user's decisions, built in
  `8007f6e2` and checked by the coordinator.
- **PT7** MERGE, no finding. **PT8** MERGE; one Low (a start between a
  sound's end and its queued replay played twice), fixed (`68452353`).
  **PT9** MERGE; one Low (a blocked arrival reported as unreachable),
  fixed (`61385b3d`); the follow-up MERGE.
- **MS** MERGE; two Lows (step 0.45.0's own writes untested on
  PostgreSQL, no station-enchanted, upgraded or crowned weapon in the
  tests), closed by tests (`c8219677`); the delta (`craftresult`, the
  chain) MERGE.
- PT1 (layout only) and ART (the user's picks on review pages) merged
  without a separate review; PT4 was research only.

Main has 152 portable fixtures (13 new: `r45_il`, `r45_rg`, `r45_jb`,
`r45_st`, `r45_ui`, `r45_eu`, `r45_pt5` … `r45_pt9`, `r45_art`,
`r45_ms`). The lanes' own gates are in their reports (each lane's full
fixture run, `check_fresh_server.py`, a smoke boot); MS's full run
151/152 (`r37_dc` red until this lane's CHANGELOG entry), its step test
64/64 (13 on PostgreSQL), `r44_ms` 32/32 with the chain checks, lane IT's
suite 59/59. This lane: `tools/r37_dc` PASS, `check_upgrade.py` PASS
(0.45.0 against origin/main `2f918739`), `check_fresh_server.py` PASS.
No seed fleet: no world generation changed.

**Round-end gates on the final branch** (`r45-d` at `5d175be6`,
coordinator, 2026-10-09): full `run_fixtures.sh` 152/152 PASS,
`check_upgrade.py` PASS (0.45.0 against origin/main `2f918739`),
`check_fresh_server.py` PASS, headless smoke boot PASS. Lane D's review:
MERGE AFTER FIXES (Lows and nits only), fixed.

`mods/` +5,049 −4,962 lines this round (162 files); no new mod; removed
from `grug_jobs`: `stations.lua`, `discovery.lua`, `basics_routes.lua`,
`basics_presentation.lua`.

### Shipped, by lane

Numbers are comparisons on the lanes' harnesses, never targets.

- **IL, the item level ladder** (`73a5806f`;
  [item_tiers.md](../design/item_tiers.md)): `grug_gear.BRACKETS` base
  item levels 1/11/21/31/41/51 with a cap of 10 × tier; the requirement is
  the item level from level 1, capped at 60, without the first-bracket
  exception (`grug_gear.required_level`); trinkets on the same ladder.
  New items, old → new: T1 item level 3 → 1 (one-hand damage 5 → 4,
  metal set 8 → 6), T2 10 → 11, … T6 50 → 51; damage from T2 up
  unchanged. `item_tiers.md` regenerated; income check unchanged (crown
  fee 1g 48s). Fixture 92 checks.
- **RG, the recipe registry** (`a86098ad`;
  [professions.md §1.2](../design/professions.md#12-recipe-areas-round-45)):
  one record model (`grug_jobs/registry.lua`) with queries by area, id and
  output; 620 grid routes converted (231 Basic rows and 171 loop-made rows
  generated, 15 mirrored duplicates merged, 138 gear routes → 132
  profession records, 64 profession grid recipes in place; hand edits: 15
  dye tokens, the written-book copy dropped); registry 174 → 662 records;
  the grid, books, discovery, mastery bands and the engine craft path
  removed, `craft` sized 0 at every join; every consumer on the registry
  (vendor prices: 392 payouts identical, the smelting and materials
  audits); durations per spec §2.30 plus intermediates 1 s, station nodes
  1 s, bags 3 s; engine grid routes 621 → 332 (unreachable data); 15
  crafting fixtures adapted or retired. Crafting page 1,148 → 188 B (the
  stub until UI).
- **JB, jobs** (`0b7b1331`;
  [inventory_equipment.md §4](../design/inventory_equipment.md#4-crafting-model-round-45)):
  `grug_jobs/jobs.lua`: one job per player in one meta key; start checks
  (station within 4 nodes, output room, ingredients), consumption from the
  bags, `main[9..]`, then the hotbar, plain stacks only; completion by
  `core.after` for online players, caught up at login and on opening the
  tab; gear through `crafted_output`; XP per job capped by the tier, a
  saturated tier advancing at the end; achievements count the job's items;
  the feed line; cancel with a dry-run fit check; the 4-slot output area
  `grug_craft_out` with Take all. Per job two meta writes, the output list
  sent once, no globalstep. Fixture 169 checks.
- **ST, stations, cooking, alchemy** (`0dd375b8`;
  [professions.md](../design/professions.md),
  [durability_repair.md](../design/durability_repair.md)): the forge, the
  four benches and the brewing stand are proximity stations without a
  dialog (the dig and blast refund of old contents kept, a lit stand goes
  out at its node timer); furnaces keep their dialog; claim repair only at
  player-placed furnaces and dual furnaces; Cooking learned at T1 at every
  join; the 12 Cooking trainer sockets hold **Grudge-Free Repairs**
  (repair only, no map icon); 40 alchemy recipes make finished potions at
  the stand (2 s), the automatic brewing and the `grug_brewing` adapter
  gone, the 40 mixtures inert ("No longer used"); the 163 item objectives
  unaffected. Fixture 459 checks.
- **UI, the Crafting tab** (`ca9cd103`;
  [inventory_equipment.md §4](../design/inventory_equipment.md#4-crafting-model-round-45)):
  area tabs with tier progress, the list (10 a page, search at most once a
  second, Craftable only, ×N from one inventory pass), the crafting box
  (have/need, Max, the quantity rules, the XP hint, the station hint with a
  greyed but clickable button), the output area with the progress bar
  (66 × 672, 96 frames, `frame_start` on every build) and Stop; the
  professions overview moved here from the Character tab; Help and
  trainer texts rewritten. Bytes (content / page): old page 1,148 / 2,128
  and the old Basics book 9,208; Basic page 1 3,235 / 4,215, a recipe
  chosen 3,875 / 4,855, Weaponsmith 3,968 / 4,948, during a job 3,842 /
  4,822. Sends per job: start 1, end 1 (only on Crafting), cancel 1; none
  on a scrollbar event or a throttled search. Basic lists 402 recipes (41
  pages). Fixture 232 checks.
- **EU, enchants and upgrades** (`2f918739`;
  [item_tiers.md](../design/item_tiers.md),
  [inventory_equipment.md §4](../design/inventory_equipment.md#4-crafting-model-round-45)):
  "Enchant an item" and "Upgrade an item" in learned primary areas, a
  target slot `grug_craft_target`, the preview (`image[]` plus the
  computed tooltip), the list of valid enchants up to the profession tier,
  5 s, cancel returning the exact item; "+N levels" with Max to 10 × the
  item's tier (and the materials), one own material per level and a Stick
  for weapons, 1 s per level, no XP, the warning and the yellow "Upgrade
  anyway", "Already at the cap"; the target handed back at join and on
  unlearn; the grid operation functions removed. Bytes (box / page):
  recipe 569 / 3,230, enchant 32 rows 2,445 / 5,075, 72 rows 3,466 /
  6,061, upgrade 1,189 / 3,819; one send more per slot placement and list
  click. Fixture 937 checks.
- **PT1, the Inventory tab layout** (`d57ec82f`): a box per area with its
  label inside, aligned slots, a draggable scrollbar handle (the thumb is
  the visible share of the rows). Inventory 2,004 → 2,221 B.
- **PT2, inventory and Character** (`6751b892`, `74f78ece`;
  [inventory_equipment.md §1](../design/inventory_equipment.md#1-the-inventory-window-the-i-key)):
  the money row (Money and the balance, Withdraw, the deposit slot, Sort)
  between the grid and the hotbar, the Coins box gone; Character's 3D and
  Stats merged into one Stats mode (three modes), the cloak hint a
  tooltip; the boxed short view on every tab with the hotbar at one place;
  7 inventory rows in today's window size (13.5 × 13.673); the Skills box
  on Talents. Inventory 2,221 → 2,241 B and Crafting 4,076 → 4,142 (the
  7-row follow-up); Character Stats 5,076 → 5,126 and Talents 6,264 →
  6,381 (measured on PT2's first, 8-row version).
- **PT3, the crafting box** (`b9ff54b8`): three areas (top; the
  description, ingredients, Max and notes; the quantity row and Craft
  now), the description exact for crafted gear and the cooked dish plus
  "Must be cooked in a furnace to become edible." for raw dishes; bordered
  Enchant/Upgrade buttons; profession areas list recipes only up to the
  profession tier. Sword box 569 → 829 B; Weaponsmith page 4,948 → 4,575.
  The review's probe built all 662 recipes: 206 gear descriptions equal
  the job's result, no overflow.
- **PT5, the shift-click inbox** (`66381441`;
  [inventory_equipment.md §3](../design/inventory_equipment.md#3-bags-classic-mmo-model-lott-implementation-pattern)):
  a hidden one-slot list `grug_inbox` as the ring target of chests,
  furnaces, the bookshelf, vessels, creative and our pages (vendored ones
  with GRUG PATCH): it takes what fits in the give order (`main[9..]`, the
  bags, the hotbar), also with `main` full; "No room in your inventory."
  otherwise; bag rings on Crafting and creative; the creative page no
  longer deletes a shift-clicked stack. Crafting +35 B, enchant box +70,
  furnace +105, +84 per equipped bag. Fixture 147 checks.
- **PT6, mounts** (`1b51a9bb`, `c887d1b7`, `bff2d5b9`;
  [mounts.md](../design/mounts.md), [boats.md](../design/boats.md)): the
  mount and the boat hull visible in first person (`forced_visible`); ride
  sounds from the mount's step (paused after 0.5 s in the air, cut on
  standing still and every dismount; `grug_sounds.stop`); fall damage for
  riders of ground mounts by the engine's formula on the drop height (6
  nodes 1 native HP, 10 nodes 6; the hit dismounts); any liquid ends a
  ride ("Mounts cannot enter water." / "… lava."); no mount summoned in
  water, from a boat or in lava; ground mounts only on solid ground.
  Fixture 118 checks.
- **PT7, mobs** (`0bee63b9`;
  [biomes_mobs.md](../design/biomes_mobs.md)): air fliers keep their fly
  clip while flying (a wrapper on the prototype, no vendored change);
  shore crabs stepheight 1 → 1.1 (the engine's step-up is strict); night
  mobs stay at dawn while a player is within 64 nodes on every axis
  (before a 32-node sphere). Fixture 95 checks.
- **PT8, station sounds** (`02f27c39`, `716dc58e`;
  [sound.md §3.2](../design/sound.md#32-events-that-sound)): a job start
  plays the station's cue at the nearest station (the forge's 1.5 s
  hammer, the brewing stand's 1.8 s alchemy cue), at most one queued
  behind a playing one; the job's end cue moved to the start; the idle 10 s
  forge loop and its file (78 kB) removed. Fixture 61 checks.
- **PT9, the Claim Stone as a waypoint** (`8d32c84c`, `a39b22ee`;
  [home_travel.md](../design/home_travel.md),
  [housing.md](../design/housing.md)): every waystone list ends with
  "Your Claim Stone" (Travel from activation, "No claim stone" otherwise),
  free and without cooldown, landing on the stone's arrival cube; a
  Waypoints tab on the owner's activated stone; the map and minimap marker
  shows the stone's own texture (the home marker wins). Fixture 44 checks.
- **ART, the user's art picks** (`5ed74763`;
  [tools/r45_a1](../../tools/r45_a1/README.md),
  [tools/r45_a2](../../tools/r45_a2/README.md)): 36 jewellery icons, one
  per identity and tier (manawell A, last_light A, battlebeat B,
  apothecary_loop B, mercy_seal A, reclaimers_mark C); new node boxes and
  tiles for the tanning rack (B), tailor bench (B), carving bench (B),
  jeweller's bench (A) and brewing stand (B); the forge unchanged; the
  loom and the old brewing textures removed. CC0, by GPT-6 Astra,
  generators committed. Fixture 280 checks.
- **MS, the migration step** (`4a892fd6`;
  [upgrade contract §5.8](../technical/upgrade-contract.md#58-the-declared-steps)):
  `tools/migration/steps/v0_45_0.py`, for every character: mixtures
  deleted from every list; the `craft` grid and `craftresult` moved into
  empty slots of `main[9..]`, the bags, then the hotbar (`craft` stored
  with size 0 when empty); every 0.44 gear stack without an item level
  pinned at its 0.44 item level and requirement (frozen table of 156
  items); `craftpreview` emptied, `grug_jobs:seen_items` deleted; the
  marker on every character. Its join handler hands leftovers out (give
  helper, output area, feet), refreshes first-tier weapon damage
  (`grug_items.refresh_capabilities`) and rebuilds descriptions.
  `game.conf`, `upgrade.json` and `grug_core.migrations` at 0.45.0.
  `tools/r45_ms/run.sh`: 7 unit tests, end to end 64/64 (a 0.44.0 world
  from a `git archive` of `c913dbbe`, SQLite and PostgreSQL); the chain
  0.43.0 → 0.45.0 and 0.41.0 → 0.45.0 in `tools/r44_ms`. Real-run counts:
  3 characters, 2 player meta, 3 inventories, 3 markers.
- **D, this lane:** this completion, the spec's status line and its
  amendments, the CHANGELOG entry, STATUS, the AGENTS pointer, ROADMAP,
  BACKLOG, README and the `tools/README.md` lines for the playtest and art
  folders.

### Upgrade classification and the declaration

| Lane | Outcome | Reason |
|---|---|---|
| IL | **migrate** | unmodified saved gear reads a new item level, requirement and stats; MS pins the old values |
| RG | **migrate** | the `craft` list is never shown or read again; MS empties it |
| JB | compatible | a new meta key and a new list made at join |
| ST | **migrate** | the mixtures are deleted (ruling 2); Cooking at join only adds keys, the trainer mapping is runtime |
| UI | compatible | context state, one texture, texts |
| EU | compatible | a new list made at join and two job kinds; enchanted, upgraded and crowned items keep their meta |
| PT1–PT3, PT5–PT9 | compatible | layout, runtime and live-derived state only; PT5's inbox is a new empty list |
| ART | compatible | looks only; node and item names unchanged |
| MS | **migrate** | the step 0.45.0 for IL, RG and ST |
| D | compatible | docs |

The round's declaration:
`{"schema": 2, "version": "0.45.0", "map_reset": ["0.40.1"], "new_server": [], "migrate": ["0.44.0", "0.45.0"]}`.
A 0.44.0 world needs the tool once (stop, back up,
`python3 tools/migrate.py --world <dir>`, start); a 0.41.0 or 0.43.0 world
gets 0.44.0 and 0.45.0 in the same run. Unmigrated, the start guard
refuses it and names the due steps and the command. No map reset.

### Decisions during the round

The user (2026-10-08 and 2026-10-09), on the lanes' questions:

- **Wave 1:** the weaker new T1 items accepted (the ruled curve); RG's
  durations kept (intermediates 1 s, station nodes 1 s, bags 3 s); the
  332 unreachable engine grid recipes stay as data; the T1 damage refresh
  is MS's; `grug_materials/registry.lua` `TIERS[].ilvl` stays (pinned
  mapgen projection).
- **JB:** a job of an unlearned profession still counts toward the craft
  achievements; a job finished offline plays its end sound and feed line
  at login.
- **ST:** claim repair only at player-placed furnaces and dual furnaces
  for now; old lit brewing stands go out at their node timer; the 12
  former Cooking trainer sockets hold a repair-only NPC titled
  **"Grudge-Free Repairs"** (the user's name, the same everywhere); no
  crafting-table repair station (repairs stay scarce so players meet).
- **UI:** Craftable only also needs the profession tier; the greyed button
  stays clickable; a throttled search is ignored; the grey XP hint at T6
  and a full tier; the lane's labels; the bar restarts at its last sent
  frame when the window is reopened.
- **EU:** the entry buttons below the list; the Target item handed back at
  join and on unlearn; the enchant list hides tiers above the profession
  tier; Max is limited by the materials too; "set gem" is the Goldsmith's
  Setting; three signatures (Campaign Purse, Scarred and Blighted Bear
  Claw) lose every use; "Upgrading…"; upgrades give no XP and do not count
  toward the craft achievements.
- **Playtest:** the Inventory tab's boxed layout and money row (balance,
  Withdraw, deposit slot, Sort); one Character "Stats" mode (3D and Stats
  merged); the boxed short view everywhere; **7 inventory rows in
  today's window size**; the crafting box in three areas with item
  descriptions, bordered Enchant/Upgrade buttons, **recipes above the
  profession tier hidden (corrects spec §2.33)**; the shift-click inbox
  (into `main` and the bags, as its own list); mounts visible in first
  person (boats too), ride sounds stopping in the air, when standing and
  at a dismount, fall damage for riders of ground mounts as on foot (any
  hit dismounts), any liquid (water and lava) ends a ride, ground mounts
  summoned only on solid ground; flying mobs keep their fly clip in the
  air, crabs climb one-node steps, night mobs stay at dawn while a player
  is within 64 nodes (cube); station sounds only when a player starts a
  job (queued at most once, at the job's start; the 10 s forge loop
  removed); the activated Claim Stone a normal waypoint for its owner both
  ways ("Your Claim Stone" last in the waystone list, a "Waypoints" tab on
  the stone, its own texture as marker, "No claim stone" otherwise); art
  picks: stations tanning B, tailor B, carving B, jeweller A, brewing B;
  jewellery manawell A, last_light A, battlebeat B, apothecary_loop B,
  mercy_seal A, reclaimers_mark C (GPT-6 Astra).
- **PT9's consequence accepted:** told that a Claim Stone which is the
  travel home is then reachable from any waystone for free and without
  the Return home cooldown, the user kept the stone a normal waypoint
  both ways.
- **MS:** `craftresult` is part of the craft move; the push of
  `2f918739` needs nothing (no realm ran it).
- **Next round (46):** the waiting point for players in creation stasis
  (spec ready); the map and minimap icon for Grudge-Free Repairs (new art,
  the user's pick); POI placement adapted to roads and rivers for the
  random-seed load failures (BACKLOG).

### Deviations from the plan

- **The playtest phase (ruling 4) grew into nine fix lanes and two art
  lanes** on the user's findings, decided live in chat: PT1–PT3 and
  PT5–PT9 (PT4 was research only, which led to PT5), and A1/A2 (GPT-6
  Astra, merged as ART after the user's picks). Several had follow-ups
  after the user's answers (PT2, PT6 twice, PT8, PT9). They touched more
  than crafting: the inventory window, mounts, mobs, sounds and the Claim
  Stone.
- **Spec §2.33 corrected:** profession areas list recipes only up to the
  profession tier (PT3, the user); Basic still lists all.
- **Spec §2.26 "Max always fills to the cap":** Max stops at what the
  materials pay for too (EU, the user).
- **§4.5 "ordinary NPCs":** after ST's review Medium (start towns lost
  their only repair point), the former Cooking trainers answer as the
  repair-only Grudge-Free Repairs.
- **Spec §6 "no new game code" for the pin:** unmodified T1 weapons read
  their damage from the definition, so MS added
  `grug_items.refresh_capabilities` and runs it in the join handler; the
  pin covers every list, and offline the craft move fills only empty slots
  (the tool cannot read `stack_max`), leftovers at the join (ruling 6).
  `craftresult` joined the move (the user).
- **§4.7 "a worktree":** MS built the 0.44.0 world from a `git archive`
  of `c913dbbe`, as in Round 44.
- **§6 checklist "the bar continues":** a reopened window shows the bar
  from its last send (accepted; no per-tick sends).
- **The wireframe** had no entry point for enchants and upgrades; EU put
  buttons below the list (accepted).
- **A mid-round push:** the user pushed `2f918739` (IL–EU, labelled
  0.44.0) before PT and MS; no realm runs it.
- **§4.2 "about 31 tool folders":** 37 name `grug_jobs`, 15 test
  crafting.
- **§7 file lists:** lanes touched shared files outside their lists, each
  named in its report: ST's repair provider and `start_npcs.lua`, EU's
  unlearn hand-back in `state.lua`, PT2's `grug_skills/page.lua`, PT3's
  Help sentence, PT6's `grug_sounds`, PT8's `grug_sounds` and
  `grug_ambience`, PT2's and PT5's edits in `grug_jobs` page files.
- **Estimates** (§1, unmeasured) were not tracked.

### Open notes

The reviews' and reports' backlog notes are in the
[BACKLOG](../../BACKLOG.md#round-45-carry-overs) (theoretical, no
severity, and the user's Round 46 items). Recommendations kept as built
unless the user says otherwise at the GUI test: a raw dish's text keeps
the cooked dish's "Hold RMB … to eat" line before the furnace note (PT3);
the lit brewing stand looks like the unlit one and only glows, the
jeweller's bench and the brewing stand keep metal dig sounds (ART); the
four benches have no job sound (PT8; a new sound needs a listening page);
the Wisp and swimmers keep their clips (PT7). `grug_materials/registry.lua`
`TIERS[].ilvl` (3/10/…/50, unread) and the stale comment in
`grug_mapgen/wp40/r7_loader.lua:46-47` wait for the next real mapgen
change, since an edit there changes the pinned projection or the
world-layout cache.

### GUI checklist

Plan §6, desktop (GUI scale 1 and 2, and a 720p screen) and the web build
(about 1280 × 720); on a copy of the production world (0.41) or a 0.44
world migrated with the tool, and on a fresh world.

**Migration (first):**

1. Start the old world under 0.45.0 without the tool: refused; the message
   names the due steps and the command line.
2. Server stopped, on a copy: `python3 tools/migrate.py --world <copy>
   --check` (from 0.41.0: 0.44.0 and 0.45.0 due; from 0.44.0: 0.45.0),
   then without `--check`, then start.
3. Join: equipped gear stays equipped and the armour value is unchanged;
   tooltips show the old level ("Item level 3" on a Bronze Sword, which
   still deals 5; "Requires level 10" on Iron pieces); craft-grid items are
   in `main`, the bags or the hotbar, else in the Crafting output area,
   else at your feet; no "Prepared … Mixture" left; crafted, enchanted,
   upgraded and crowned items unchanged; Cooking known at T1 (a higher tier
   kept).

**Inventory window:**

4. Inventory: a box per area with its label inside, 7 rows, the window as
   large as before; with four bags the scrollbar handle drags.
5. The money row: Money and the balance, Withdraw (opens its dialog and
   returns), the deposit slot, Sort ending with the last hotbar slot; the
   balance updates; a balance of 100000g or more beside Withdraw.
6. Switch tabs: the hotbar stays at one place; the short view is boxed on
   Character, Crafting and Talents & Skills.
7. Character: three modes. Stats shows the model left, the stats and the
   Claim Stone status right, the Cloak dropdown at the bottom with its
   hint as a tooltip; a draft Claim Stone's four-line status stays clear of
   the Cloak label; no balance or Withdraw here.
8. Talents & Skills: the Skills box above the short view; the hint beside
   "Skills" readable in a small web window; dragging skills to and from the
   hotbar works.
9. Shift-click: from a chest with `main` full and a bag equipped → the
   bag; a partial fit leaves the rest in the chest; everything full → "No
   room in your inventory." and nothing moves. Creative → `main[9..]` with
   the hotbar free, the creative stack stays; on the creative page a
   shift-click from the hotbar, `main` or a bag deletes nothing. Furnace
   lists, the Crafting output area and the target slot → the inventory;
   from `main` still into the chest, the furnace input or the target slot.
   On Crafting with a bag: from `main` nothing moves (recipe box); with
   Enchant/Upgrade open, gear from a bag goes into the target slot.

**Crafting tab:**

10. Areas Basic (default), Cooking, two primaries and Alchemy with tier
    progress; profession areas list only recipes up to your tier, Basic
    everything; 10 a page with "Page x of y"; search, Craftable only and
    ×N right; a clipped long name shows its tooltip.
11. The box in three areas: a T1 sword shows its stats and no quantity
    row; the raw stew pot shows the stew's text and the furnace note; a
    long text scrolls; the quantity row sits right above Craft now. A
    Basic craft of 1 and of 20 with Max; above the maximum the field drops
    and the note shows. The XP hint green, and grey at T6 or a full tier.
12. Away from the forge: "Requires: Forge nearby" and a greyed button that
    still answers a click; at the forge Craft now works. A weapon from the
    Weaponsmith at its tier's base item level; no gear in Basic. The
    professions overview sits in the box; Character has no Professions
    mode.
13. A job: start, close and reopen the window (the bar shows its last sent
    frame, right again after a click or at the end); log out and in (the
    job finished or continues; a finished one plays its sound and feed
    line at login); the HUD line "… is ready"; Stop with and without room;
    the output area full, partly full, Take all into the bags when `main`
    is full.

**Enchants and upgrades:**

14. Weaponsmith: "Enchant an item" looks like a button (gold while open);
    a steel sword in Target lists the enchants T3–T1 (up to your tier) with
    their values; the preview tooltip equals the result after 5 s
    "Enchanting…"; Cancel returns the sword; away from the forge the
    button is greyed; shift-click reaches the slot.
15. Upgrade: Max → +9 and "Result: item level 30 (cap)" (fewer with too few
    materials); "Upgrading…" while it runs; above your level the warning,
    then a yellow "Upgrade anyway" and the second click starts; at 30 or on
    a crowned item "Already at the cap"; a T2 smith on a T3 item:
    "Weaponsmith tier 3 required."
16. An item left in Target is back in the inventory after a relog and
    after unlearning the profession.

**Stations, cooking, alchemy, repair:**

17. The forge, the four benches and the brewing stand open no window; a
    furnace still does, without a book button, and inside your claim shows
    Repair; dig an old player-placed bench or brewing stand: its contents
    drop; an old lit brewing stand goes out.
18. Cooking without a trainer; a good dish finished in the furnace; a
    potion at the brewing stand takes 2 s, away from it "Requires: Brewing
    Stand nearby"; an old mixture shows "No longer used".
19. Grudge-Free Repairs in every start town and capital: only the repair
    form, no trainer dialog, no map or minimap icon, the other faction
    refused; Help names it.
    A profession trainer's hint names the Crafting tab and the station.
20. The new stations (tanning rack, tailor bench, carving bench,
    jeweller's bench, brewing stand) from front and back; the selection
    outline follows the shape; dig one of your own: it comes back as the
    station item; the forge unchanged. Trinkets T1–T6 show
    distinct jewellery in the inventory, the equipment slots and the web
    inventory; the Goldsmith's product display.
21. Sounds: an idle capital forge is silent; a Weaponsmith job start plays
    one hammer cue at the forge and none at the end; two players starting
    within 1.5 s hear two cues back to back, a third adds nothing; an
    alchemy job sounds at the stand when it starts; an upgrade hammers at
    the start and chimes at the end; a burning furnace keeps its fire
    loop.

**Item levels:**

22. A new character's starter weapon reads "Item level 1" without
    "Requires level"; an Iron piece needs level 11; a T3 trinket reads
    "Item level 21, Requires level 21".

**Mounts and mobs:**

23. First person on a horse, a race mount, an eagle and a bat: the head or
    body shows looking ahead or down (in the way?); the boat hull shows;
    third person unchanged.
24. The gallop stops when W is released, goes quiet in a jump and resumes
    on landing, keeps going downhill, ends at a dismount; a hovering flyer
    and a dismount stop the wing beats.
25. A ledge of about 6 nodes on a horse: a small hit and thrown off; 5
    nodes or a jump: nothing; a high fall into deep water: no damage.
26. Riding into a river or the sea (a thin flowing film too) dismounts
    with "Mounts cannot enter water."; flying low over water goes on,
    diving in dismounts; lava one node deep dismounts with the lava note
    and lava damage; a mount refused in water, from a boat and in lava; a
    ground mount refused mid-air, a flyer allowed; on the ground it works.
27. A parrot or crow hovering, fleeing or fighting beats its wings; a crab
    climbs a one-node step, also when chasing; at dawn night mobs within
    64 nodes on every axis stay, farther away they leave (and an idle
    player keeps them all day: watch).

**Claim Stone:**

28. A waystone's list ends with "Your Claim Stone — No claim stone"
    without a stone and with a draft; after activating: Travel and a map
    and minimap marker in the stone's look; travel lands on the stone, the
    Return home cooldown unchanged; an unfuelled stone still works; as the
    travel home only the home marker shows; a block on the stone: "Your
    Claim Stone's arrival is blocked."; another player sees "No claim
    stone".
29. The activated stone's form has two tabs; Waypoints lists your
    discovered waystones; Travel arrives beside the waystone and closes
    the form; about 9 nodes away: "Stand at your Claim Stone to travel."
    in red; a draft has no tabs.

**Web build:**

30. At about 1280 × 720: the Crafting tab, the enchant box with its
    warning line, the money row, the Talents hint; nothing clipped.

### For the platform

0.45.0 declares its step `0.45.0` under the Round 43 tool and interface
unchanged ([tools/README.md](../../tools/README.md#the-migration-tool)).
The production world (0.41.0, no record) needs one run of
`python3 tools/migrate.py --world <dir>` from a full export of the 0.45.0
commit; it applies 0.44.0, then 0.45.0 (events `start`, `step_start`
`{0.44.0, from 0.41.0}` and `{0.45.0, from 0.44.0}`, each `step_done`
with its counts, `done`). Step 0.45.0 writes the inventories and player
meta of every character that needs it and a marker on every character; its
online work runs at each character's next join (craft leftovers, the T1
damage refresh, descriptions). No map part. Tested end to end on SQLite,
on PostgreSQL (all three backends and the platform's layout, every row
equal to the SQLite result) and as the chain from a record-less copy.

## 0.45.1 fix round (2026-10-10)

The user's playtest of 0.45.0 (production runs 0.45.0) became fourteen
decided fixes and eleven lanes, all started from main `d4a1e645` on
2026-10-10 (the fix plan, in German, outside the repository:
`kaesual-stack/.local/grudgelands-0451-fixplan.md`). Every code lane was
reviewed by an independent Opus; every fix was made by the lane before
its merge. **0.45.1 is a compatible patch:** no migration step, no map
reset, no new world. **Push:** 0.45.1 is not pushed yet (pushed only on
the user's word).

### Lanes

Main's first-parent merges, in order:

| Lane | Merge (follow-ups) | What | Review |
|---|---|---|---|
| TR | `4e870c61` (`f320ee8b`, `7a3eaaa2`) | trainer window with one bottom button row, a greeting per trainer, the mender's form titled Grudge-Free Repairs | MERGE; follow-ups checked by the coordinator |
| TX | `605722ee` | GPT-6 Astra's greeting and note-icon proposals under `tools/r451_tx` (provenance) | Opus text review with suggestions |
| SC | `64336d7e` (`f9ba0ede`) | self and support skills: 350 ms tap window, no cancel on aim change; self skills at allies and non-target actors; right-click food tap | MERGE; fix round MERGE |
| MU | `9f3599de` (`57e9b45e`) | "Now playing" box under the minimap | MERGE |
| MZ | `542285b8` | map zoom soft lock; the inventory key closes the map | MERGE (two GUI Lows) |
| CH | `c5ce40cf` (`6d58fe54`) | Charge down and up stairs; no camera dip; safe cancel in a drop | MERGE; follow-up MERGE |
| CU | `2512c8bd` (`2101ba95`) | group ingredient labels and icon, − and +, search clear, no pre-focus, tab order | MERGE |
| MC | `7a02f62b` (`bc772f9a`, `e40a2d64`, `961a62bb`, `2bea36c5`, `bf639556`) | riding camera, sizes and seats per mount, Dismount, first-mount banner, flyers' ground frame, ride-only bat mesh, boats at the surface | MERGE AFTER FIXES (Medium: riders suffocated in 2-high passages; fixed); follow-ups 3 and 4 MERGE, the others checked by the coordinator |
| KF | `ca788210` (`09b837f6`) | harmless forced focus so the inventory key closes every window; Space/Enter on Character and Inventory | MERGE (its side finding became the follow-up) |
| NQ | `5454a970` (`93adae30`) | quest giver preselection; town NPCs wait for their floor, sunk NPCs re-seated | MERGE |
| D | this section | CHANGELOG, version 0.45.1, status owners, the boat help line | — |

### Decisions

The user's rulings (2026-10-10), one line each:

1. Group ingredients: up to 3 kinds written out ("Carrot or Cassava"), 4
   or more a hand-kept name ("Any wool"); the icon is the kind the player
   carries most of; two cut-off written-out labels accepted.
2. Charge downhill: run down the last step, cut at the last clearable
   edge; a stairs-down test.
3. Quantity `[−][field][+] [Max]`; "−" above the maximum jumps to it.
4. Quest giver: the first ready quest, else the first acceptable, else the
   first; after Accept the next acceptable (ready first), else stay.
5. Self and support skills keep click/hold: a 350 ms window, no cancel on
   aim change, for all self and support skills; Ice Nova casts at allies;
   self skills cast at NPCs, traders, tamed mobs and protected players;
   right-click food uses the same window.
6. Search: a narrower field, "×" then Search; × shows the full list at
   once.
7. Sunk NPCs: check standing room at placement, re-seat on activation (no
   migration); Kezamba's throne guard to the BACKLOG.
8. Riding camera per mount, tuned by the user with the never-shipped
   `/mountcam` probe (stag 120 %, bats 130 %, then three dumps of tuned
   values); a ride-only bat mesh without the body bob, eagles centred,
   the ridden ibex idling still; low ceilings in view accepted.
9. Dismount button in the quickbar while riding, boats included; the
   first-mount banner for riding mounts only (lost on a disconnect:
   accepted).
10. Tabs: Inventory · Character · Talents & Skills · Crafting · Party &
    PvP · Map & Quests · Help; the map window keeps its "Map" label.
11. "Now playing": the note icon pick B (36 px), "Town Theme" shortened,
    the 720p overlap with 10 tracked quests accepted.
12. Trainers: one bottom button row, greeting on top and notice below,
    the picked greetings (weaponsmith Astra B, armorsmith Opus, alchemist,
    tailor, leatherworker and goldsmith Astra A, woodcarver Astra C, mender
    Opus), the mender's form titled "Grudge-Free Repairs".
13. The inventory key closes every window: no pre-focused element; text
    editors and an already chosen list row keep their focus; the
    Character/Inventory Space/Enter fix added.
14. Map zoom soft lock on the player until the player scrolls at 2x–8x;
    a click into the quest text swallows "i" until the next send, Enter
    closes the map (both kept).
15. Flyers: the flight loop in the air (hovering included), a still level
    frame on the ground (within 0.1 node); boats only in the top two water
    nodes; the help line says "at the surface".

### Numbers worth keeping

- 161 portable fixtures on main (9 new: `r451_ch`, `cu`, `kf`, `mc`,
  `mu`, `mz`, `nq`, `sc`, `tr`); `mods/` +1,095 −242 lines in 42 files,
  two new binaries (the note icon, the ridden bats' mesh).
- **Charge** (cut plans before → after): stairs down with treads 1/2/3
  nodes 33/36/28 → 0, diagonal 91/95/86 → 0, a gentle slope 88 of 1,291
  → 0, stairs up with treads 2/3 80/82 → 0; every plan that reached its
  destination before is unchanged; the worst planning case under 1 ms
  per cast.
- **Tap window:** 350 ms = a 0.15 s click + one control report 0.09 s + a
  frame 0.02 s + one input pass 0.09 s; the dig guard stays 0.2 s.
- **Sunk NPCs:** the cause is a socket placed over an unfinished chunk
  shell (Nhal Veyr's sockets at y 48, a chunk border); on a 0.45.0 world
  the review's boot found 14 sunk NPCs and the fix re-seated all 14.
- **Mounts**, the shipped values (seat and cameras in nodes above the
  mount's feet):

  | Model | Size | Seat | First y, z | Third y |
  |---|---|---|---|---|
  | Horse | 3 | 1.26 | 2.4, −0.2 | 2.15 |
  | Ibex | 1.45 | 1.23 | 2.8, −0.3 | 2.15 |
  | Stag | 9.6 | 1.32 | 2.35, −0.1 | 2.25 |
  | Boar | 1.55 | 1.14 | 1.95, −0.3 | 2.15 |
  | Wolf | 2.125 | 1.78 | 2.5, −0.3 | 2.35 |
  | Tiger | 1.45 | 1.52 | 2.4, −0.2 | 2.4 |
  | Accord Eagle | 3 | 1.86 | 2.8, −0.2 | 2.75 |
  | Steller's Sea Eagle | 4 | 2.56 | 3.6, −0.2 | 3.5 |
  | Throng Cave Bat | 5.07 | 2.00 | 3.8, −0.4 | 3.4 |
  | Giant Blood Bat | 7.098 | 3.00 | 5, −0.5 | 4.6 |
  | Rowboat | 1.078 | 0.20 | 1, 0.2 | 0.8 |
  | Sailboat | 0.88 | 0.09 | 1, −0.2 | 0.8 |

  The tier selection boxes (the highest seat of a tier + 1.8) grew from
  3.32/3.72/4.66 to 3.58/3.80/4.80 for tiers 2/3/4 (both factions; the
  collision boxes are unchanged); the bats' torso travel in flight
  0.75/1.05 → 0 nodes; the 8-node flight headroom still holds (at most
  about 6 needed).
- **"Now playing":** about 281 px wide at 1080p, the icon 36 px, the
  background `#343434` at 30 %.
- **Trainers:** 11 wide; every picked greeting wraps to 2–3 lines (the
  longest 173 characters), so the window keeps 5.16 high; the mender's
  form 10.36.

### Classification

Every lane compatible: layout, texts, runtime state and one new meta
flag (`grug_mounts:summon_hint`, set at a first riding mount's purchase);
nothing saved is removed or rewritten, no id changes. The declaration
only raises the version:
`{"schema": 2, "version": "0.45.1", "map_reset": ["0.40.1"], "new_server": [], "migrate": ["0.44.0", "0.45.0"]}`.
A 0.45.0 world plays on; the production world's sunk Nhal Veyr NPCs are
re-seated the next time their area loads.

### Open notes

The reviews' and reports' backlog notes are in the
[BACKLOG](../../BACKLOG.md#0451-carry-overs).

### GUI checklist (0.45.1)

Desktop (GUI scale 1 and 2, a 720p screen) and the web build (about
1280 × 720), on a copy of the production world.

**Riding:**

1. Each mount (horse, ibex, stag, boar, wolf, tiger, both eagles, both
   bats, both boats), first and third person (F7 both ways): ride a
   slope, jump, turn; the neck and head low in view; stag and tiger
   riders on the back, eagles centred under you; a ridden ibex and the
   bats do not bob.
2. Flyers: climb, descend, hover (flight loop), land (still, level, no
   wing sound); bats in a 3–4-high tunnel; the larger selection boxes of
   tiers 2–4 in PvP.
3. `E` while riding (a boat too) shows Dismount under the mounts; a click
   dismounts and closes; on foot no button.
4. A new character buys Apprentice Riding and closes the dialogue: "Press
   E to summon your mount"; a later tier or a boat shows none.
5. A boat from the quickbar while wading or swimming at the surface; two
   or more nodes deeper: "Swim up to the surface to summon a boat."; the
   hull floats at the same waterline; riding through a 2-high tunnel does
   not hurt.

**Combat:**

6. Charge a mob lower on a gentle hill with one-node steps, also right
   behind the last step, and diagonally down a slope: the run reaches it
   and the hit lands, with no camera dip on long or diagonal stairs
   (down and up); uphill stairs, a ledge, a low wall, a 4-wide hole as
   before; a step under an overhang still stops on the step.
7. Ice Nova, then Blink, Glacial Ward, Sidestep, Sprint, Hold Ground,
   Heal, Shield and Mend: quick clicks at the ground 1–4 m away, also
   strafing, cast every time; at the sky at the press; Ice Nova at an
   ally, a trader, an NPC and a player without PvP casts once; a Heal
   tapped at the ground heals the ally in the crosshair at release.
8. Holding LMB with Ice Nova digs dirt; a torch or flower digs without
   flashing back; Fireball at the ground digs at once; Blink tapped on
   town ground casts, held it shows the protection hint.
9. Food: a quick right-click plants or opens; holding eats (the ring at
   0.35 s).

**Crafting and tabs:**

10. "i" opens and closes Crafting, also with a recipe chosen and in
    Enchant/Upgrade; typing "iron" + Enter keeps the cursor in the field;
    a job ending while typing moves the cursor (known).
11. × right after a search empties the field and shows the full list from
    page 1.
12. Ingredients "Carrot or Cassava", "Any wool", "Any planks"; the icon
    follows the wool you carry most of; the tooltip lists every member;
    long item names do not touch have/need.
13. The quantity row at the web size: −, field, + and Max fit, the signs
    render; "−" above the maximum jumps to it.
14. The tab bar ends Party & PvP · Map & Quests · Help; Map & Quests
    opens the map window.

**Quests, towns and trainers:**

15. A quest giver with finished quests opens on the first green one;
    Complete hands them in one after another, then the first gold one;
    Accept takes the gold ones in turn, a green one first; after the
    last the accepted quest stays; "i" closes the dialog, also after a
    list click; Space and Enter press Close.
16. Nhal Veyr on the production world: the NPCs in front of the houses
    stand on the ground after the first visit (server log "re-seated").
17. Each of the 7 trainers: the greeting in full, "Learn X?", one bottom
    row with Close on the right; Learn, Unlearn, Confirm/Cancel; Alchemy
    learned shows only Repair and Close; both slots taken: the refusal
    fits; no scrollbar; "i" closes in every state; the 11-wide window
    at a large GUI scale and on the web.
18. The mender: the title "Grudge-Free Repairs" with its greeting, the
    rows and the bottom row not cut off; a trainer's "Repair equipment"
    keeps "Equipment repairs" without a greeting.

**Map and windows:**

19. The map near its centre and near an edge: +, +, −, + stays on your
    arrow (clamped at the edge, no creep); at 2x scroll (drag, wheel, a
    bar click), then + and − keep that area; back at 1x it follows you
    again; every opening (Z and the tab) starts at 1x locked.
20. "i" closes the map after opening, zooming, a quest click (the
    selected one too), Abandon → Cancel and a checkbox; after a click
    into the quest text it stays open until the next refresh (known);
    arrow keys in the quest list move the focus to the map (known).
21. "i" closes Talents & Skills (with and without ranks), Party & PvP
    (alone, in a party, with a notice), every Help sub-page (also reopened
    on About), the Crownbinder, the creation window, the Claim Stone (also
    after Waypoints and back), the withdraw dialog and a written book;
    typing "i" into a field still types it; the invisible Talents and
    Inventory focus buttons draw nothing.
22. With a home set: Space or Enter on the Character tab (every mode)
    does not travel home; Space on the Inventory tab does not sort.

**Music:**

23. In a capital the box appears under the location line with the first
    track, hides for the pause between tracks, on leaving the city, with
    `/music off` or `/music 0` and with the minimap hidden, and comes
    back; readable over bright ground; the right edge at 720p; the icon
    at 36 px.

### Round-end gates

**Round-end gates on the final branch** (coordinator): pending — full
`run_fixtures.sh`, `check_upgrade.py`, `check_fresh_server.py`,
`tools/r451_mc/gen_bat_ride_mesh.py --check`, a smoke boot.
