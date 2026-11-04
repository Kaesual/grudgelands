# Round 69 — trash slot, respawn at home, camp sites, exact tooltips, quest-drop markers

Planned with the user on 2026-11-04 from player reports and the user's notes;
started on the user's "go" the same day. Claude coordinates, Opus implements
and reviews, GPT-6 Astra draws the camp site.
**Complete on 2026-11-04:** all six lanes merged, then this documentation
lane D (QUESTMAP, HOME and SKILLS reviewed MERGE; UI MERGE AFTER FIXES, one
doc line; CAMP MERGE AFTER FIXES, then MERGE). The user picked camp
**A Wallwright**. **Not pushed; the [GUI test](#gui-checklist-desktop-and-web)
is open** ([completion](#completion-2026-11-04)).
Version: **0.69.0**. Classification: **migrate** (lane CAMP's camp rewrite,
online part only); every other lane is compatible. No map reset. Delivery
state: [STATUS](../STATUS.md).

## Why

The coordinator's reading of `3cee37b3`, re-checked by the lanes (round
workflow §2.4):

- **Trash:** players throw unwanted items on the ground. The Inventory tab's
  Money box has about four units of empty space under the deposit slot.
- **Respawn:** a bound innkeeper already is the respawn point; only a Claim
  Stone home differs, because `grug_home/travel.lua` `request` resolves
  respawn through `grug_home.innkeeper` and travel through `grug_home.get`.
  That was Round 25 ruling 25. Help already says "You respawn at your home."
- **Camps under construction** (six, `r58_camp_blueprint.lua`) still use wool
  tents and the old post palisade, and read as half a broken camp: the
  palisade simply stops. Every other camp moved to the Round 63 templates.
- **Berufe order:** the Crafting tab ends in Alchemy (`grug_jobs/ui.lua`
  `AREA_SLOTS`).
- **Tooltips:** the hotbar and catalog stacks show exact numbers through
  `description_for`, Ice Nova included (also in production's 0.65.0), but
  Ice Nova's wording hides it ("for 30", no "damage"). Strike, Hamstring and
  Retort's plain swing show no number. The talent tree shows only static
  shares ("65 % of a Spark hit") for every skill.
- **Words Worth Bringing Back:** a disposable engine probe on seeds 42 and
  2026 found all six camps on the quest-target index with free spawn spots;
  on seed 42 real spawns carried the names the drop counts. The Packet is a
  1-in-3 quest drop, not a world object, and the Bannerbreak text suggests an
  object. The missing marker is by design: item objectives mark nothing
  (`grug_map/targets.lua`). 97 of 390 quests have item objectives, 93 have
  nothing else. 14 of the 97 name their source in data the loader drops or
  the map ignores.

## 1. Lanes and order

| Wave | Lane | Who | Goal | Waits for |
|---|---|---|---|---|
| 1 | UI | Opus | Trash box in the Inventory tab; the professions' order | go |
| 1 | HOME | Opus | Respawn goes where the home teleport goes | go |
| 1 | SKILLS | Opus | Exact numbers on every damage skill and in the talent tree | go |
| 1 | QUESTMAP | Opus | Rings for the 14 quests, source in the objective line, one text fix | go |
| 1 | CAMPART | Astra | Camp site designs as ordinary templates on a pick page | go |
| 1, then 2 | CAMP | Opus | Phase 1: the box rewrite and migration, proved with a placeholder. Phase 2: the picked composition | phase 2: the user's pick |
| 3 | D | Opus | Docs, completion, GUI checklist | every merge |

## 2. The user's rulings (2026-11-04)

1. **Trash, variant A:** an own box "TRASH" at the bottom of the Inventory
   tab's right column; the Money box gets shorter. Only in the Inventory tab,
   no other view and no container form. Mockup: the
   [Trash-Slot Mockup](https://claude.ai/artifact/77CRcgYF6e3LCmZie226Mc)
   (board A and its four states).
2. **Undo:** a dropped item is destroyed at once; the last one can be taken
   back until the next discard or logout. No shift-click route into the slot.
   Soulbound and bound items are refused with a hint.
3. **Respawn is home, Claim Stone included**, also without fuel (travel works
   there too). Round 25 ruling 25 is retired.
4. **Camp sites get a new design** from an Astra round, picked by the user,
   that clearly reads as "being built" in the Round 63 materials.
5. **No map reset for it:** the migration rewrites each existing camp's fixed
   box with the new blueprint. This is a deliberate, documented exception to
   the rule "world generation needs a map reset".
6. **Fallback:** if the two-boot proof fails, existing camps stay in the old
   design until the next map reset, new ones generate in the new design. The
   lane reports this before falling back.
7. **Professions order:** Basic, Cooking, Alchemy, Primary 1, Primary 2.
8. **Markers only for the 14 quests** whose source the data names; the 83
   gathering, crafting and fishing quests stay unmarked.
9. **Exact tooltips:** every damaging skill shows its exact number with the
   player's level, weapon, gear and talents, as the range already does; the
   talent tree shows the numbers too, also for skills not learned yet.
   Target-dependent values (level malus, armor, crits) stay out.

**Coordinator defaults** (the user may overrule them):

- The professions overview and the help text follow ruling 7.
- The objective line of a quest with a known source names it, for example
  "Bring Runner's Packet: 0/1 (from Trench Archer)".
- The camp's five sockets keep their ids and their cells, so existing guards
  and the captain stay right; the gate stays on the same side.
- CAMP owns `game.conf`'s version and the declaration.

## 3. Shared conventions

- English in the repository, code names English, no references to existing
  games, factions The Accord and The Throng.
- No new sound (sound approval gate); the trash uses what exists or stays
  silent.
- The trash icon is `creative_trash_icon.png` with a texture modifier; no new
  art for it.
- `grug_inventory/help.lua`: UI edits the professions' lines, HOME the home
  and death lines; nobody else touches it.

## 4. Lane goals

### UI — trash box and professions' order

The box of rulings 1–2 at the mockup's place and wording, in the shared UI
toolkit, working on desktop and web, with text growth. Ruling 7 in the tabs,
the overview and the help. Compatible; undo state is runtime only.

### HOME — respawn at home

Respawn and the home teleport resolve the same home. A blocked or unavailable
Claim Stone falls back to the innkeeper, then the start, and the respawn hold
stays on until the player stands somewhere valid. No cooldown, no combat rule
on respawn. Design docs and comments that state ruling 25 follow. Compatible.

### SKILLS — exact numbers

Rulings 9: the number appears in the same form on every damage skill ("N
damage"), Strike, Hamstring and Retort's plain swing gain theirs, and each
number matches what a hit computes before target-dependent factors. The
talent tree's skill nodes (unlock, transform, ultimate and the like) append
the skill's current text through the same `description_for`, so tree and
hotbar never differ; heals and shields follow by that. Compatible.

### QUESTMAP — quest-drop markers

An item objective with a named source (its own `roles`/`area`, or a quest drop
of that item) marks the map the way a kill objective of that source does:
rings for an area, a crosshair for a leader or garrison, only while open. The
objective line names the source (coordinator default). The Bannerbreak variant
of `border_packets` stops suggesting a world object, keeping its voice. The
objectives themselves do not change, so no quest takes a new id. Compatible.

### CAMPART — the camp site (GPT-6 Astra)

Two or three designs of a camp under construction that read at a glance as
being built rather than broken, in the Round 63 materials, as ordinary building
templates for all six race palettes and both factions, inside the fixed box,
with an interactive 3D comparison page. Nothing under `mods/`.

### CAMP — the new blueprint and the box rewrite

The camp site composition becomes templates (as the mining camps are). A
`migrate` step 0.69.0 with an online part rewrites each of the six boxes once,
whatever is generated, surviving restarts and safe to repeat. Phase 1 proves
the mechanism on a real 0.68 world (two boots) with a placeholder composition;
phase 2 installs the user's pick. The upgrade contract documents the
exception.

### D — docs

The usual: completion, GUI checklist, status owners.

## 5. Rules

Round workflow §3 gates; release mode; the Lua-process cap and the engine-run
budget of AGENTS.md; no map reset; no push.

## 6. Verification

Portable fixtures per lane (`tools/r69_<lane>/`), one smoke boot per code
lane, CAMP's two-boot proof on a 0.68 world, a quick seed fleet for CAMP (the
camp blueprint's path changes, the footprint does not), the migration's test
including the container run, GUI checklist by lane D.

### GUI checklist (desktop and web)

Written by lane D from the lanes' excerpts and the reviewers' notes. Each
item on the desktop client and on the web client. Items marked *look* ask
for the user's verdict on a first-look default.

**Trash box and professions' order (UI)**

1. **A real mouse drag into the Trash box.** No lane and no reviewer has run
   one: the lanes' states were staged through the box's callbacks. On the
   Inventory tab drag a whole stack into the box at the bottom of the right
   column: it is gone at once, the box names it and shows Undo; Undo brings
   back the whole stack, meta and wear included. Right-drag part of a stack:
   only that part goes, the cursor keeps the rest. On the web client also by
   touch, if it drags at all.
2. **Undo's reach:** a second discard replaces the first, which stays gone;
   logging out ends Undo. A double click on Undo gives one stack back.
3. **Refusals:** drag a soulbound item, a hotbar skill and a mount item: each
   stays where it was, with a hint for six seconds. With a stack waiting
   beside Undo the hint is the short "Bound items can't be destroyed here."
4. **The Undo no-room hint:** fill the inventory, press Undo: "No room: make
   space, then press Undo."; the stack stays undoable and comes back once
   there is room.
5. **Filled bag** from its bag slot: with room for its contents they move to
   the inventory and the bag goes; without room it stays, with a line in the
   feed (which the open window may cover).
6. **Shift-click** never reaches the box; the box appears in no other tab and
   no container form; the Money box above it still works.
7. *Look:* the box at small and large windows (the lane saw 1035x696,
   1600x900, 2560x1440 and GUI scale 1.5): its text is slightly smaller than
   the mockup's (0.85 × the page's), long names cut with the whole name in
   the tooltip. Large font settings; the web client's phone width if there
   is one.
8. **Professions' order:** Crafting tabs Basic, Cooking, Alchemy, Primary 1,
   Primary 2; the professions overview Cooking and Alchemy first; Select this
   recipe on the details page lands on the right tab; Help's professions line
   and its new Trash line read right.

**Respawn at home (HOME)**

9. **Claim Stone home:** die: you stand on the stone, no fall, the Return
   Home cooldown unchanged.
10. **Unfuelled stone:** set it as home: "Your Claim Stone is now your home.
    It has no fuel, but you still travel and respawn there."; die: as in 9.
11. **Blocked stone:** block the cube above the stone, die: the innkeeper,
    with the "arrival is blocked" message; the stone stays your home.
12. **Innkeeper home,** then **no home:** die: the innkeeper, then the
    starting town.
13. **Stone lost:** die, have the stone destroyed before pressing respawn:
    the message, then the innkeeper; no free moment at a wrong place.
14. **PvP death** with a Claim Stone home: you respawn there.

**Exact numbers (SKILLS)**

15. **Hotbar, catalog and tree agree per class:** for one skill of each of the
    four classes the three tooltips show the same "N damage". Strike,
    Hamstring and Retort's plain swing now show theirs; Ice Nova reads
    "N damage", no longer "for N".
16. **Weapon swap:** Strike and the Scout's blade numbers follow; with the
    Talents page open, tree and catalog follow too.
17. **Buy Fire Mastery:** an unlearned Fireball's number rises in the tree.
18. **Food or elixir with spell damage:** spell numbers rise, and fall back
    when it ends.
19. **Opening** with Turn the Blade shows three numbers.
20. **A bowless Scout** reads "0 damage" on bow skills in the tree, as the
    hotbar already did (the cast refuses anyway). *Look:* keep? (Both the lane
    and the reviewer say keep.)
21. **Refused click on a granting node:** the reason stays visible in the
    strip, the numbers follow it. *Look:* do the strip's numbers need
    scrolling on a touch screen, and is that acceptable? The longest node
    tooltip is 9 lines (Retort, locked).

**Quest-drop markers (QUESTMAP)**

22. **Quest rings per faction:** select Words Worth Bringing Back in an Accord
    zone (Stormvault Heights) and a Throng zone (Bannerbreak Mesa): rings on
    that zone's camp, each with its own source.
23. **Crosshairs:** select Read Before Accusing (Accord) or Find the Hand That
    Signed (Throng): a crosshair at the garrison camp.
24. **Pick up the Packet:** the marker goes, the quest turns ready.
25. **The source line:** on a Throng character in Bannerbreak the ring's tooltip
    and the quest log read "Bring Runner's Packet: 0/1 (from Trench Archer)";
    the HUD reads "0/1 Runner's Packet from Trench Archer".
26. **A gathering quest** (Room at the Table) shows no marker.
27. *Look:* long HUD lines: 9 of the 21 single-objective variants are cut with
    "..." inside the source (measured at 38 characters); the several-objective
    line (10 variants, "Barn Rat 0/3, Rat Fur Patch 0/1") names no source. The
    log's "(from X) (level N)" has two parentheses.

**Camp sites (CAMP)**

28. **Upgraded test world:** a 0.68.0 world through `tools/migrate.py`, then
    its first start: all six camps show Wallwright: no old tents, no wool, no
    palisade that simply stops. The log says every box read back.
29. **A fresh camp:** a new world's camp site shows Wallwright, the gate facing
    its continent. Both factions, more than one race.
30. **Camp life:** guards and captain on their posts, a raid quest counts.
31. **Walkable:** gate, yard and tents.
32. **Standing in a camp at the upgrade:** log out inside a box on the 0.68.0
    world, or stand there during the first start: you can walk or fall out; a
    full block at head height hurts until you do. Read and computed by the
    lane, not engine-tested; Return Home is the backstop.
33. *Look:* Wallwright's tents with their straw mats. **Open for the user's
    confirmation:** the Round 58 line "no shelter, no bed" was narrowed for
    them ([deviations](#deviations-from-the-plan)); recommended: keep.

## 7. Orchestration notes

- Start state: main `3cee37b3` plus this plan; all lanes branch from it.
- Merge order: UI, HOME, SKILLS, QUESTMAP in the order they pass review; CAMP
  last, because it owns the version; then D.
- Shared files: `grug_inventory/help.lua` (§3). `grug_quests/*` and
  `grug_map/*` are QUESTMAP's; `grug_classes/talent_graph_ui.lua` SKILLS';
  `mods/CORE/grug_core/migrations.lua`, `game.conf`,
  `tools/web_data/upgrade.json`, `docs/technical/upgrade-contract.md` CAMP's.
- Decided during the round: the user's camp pick.

## Completion (2026-11-04)

All six lanes are merged on main; this lane D (completion, GUI checklist,
status owners) follows on main `67391a4b`. Reviews (Opus, independent):
QUESTMAP, HOME and SKILLS **MERGE**; UI **MERGE AFTER FIXES** (one doc line,
fixed by the coordinator); CAMP **MERGE AFTER FIXES**, then **MERGE** on the
fix round. CAMPART (GPT-6 Astra; tools only) was checked by the coordinator.
**0.69.0 is migrate, no map reset:** UI, HOME, SKILLS and QUESTMAP are
compatible (no saved state added; `grug_home:claim` already existed, so a
0.68.0 player with a Claim Stone home respawns there after the update);
CAMPART touches tools only; CAMP declares the step 0.69.0 with an online part
only, the user's documented exception to "world generation needs a map reset"
([upgrade contract §5.9](../technical/upgrade-contract.md#59-a-protected-composition-rewritten-online)).
Saved state: `grug_core` `migrate_world:0.69.0`; `grug_mapgen` `camp_rewrite`,
map-bound and cleared once the boxes read back. **Push:** not pushed;
origin/main is `3cee37b3` (0.68.0). **Production** runs 0.65.0; an update to
0.69.0 crosses no map reset and runs the steps 0.67.0 and 0.69.0. **GUI test:**
[open](#gui-checklist-desktop-and-web). **Sync:** by the coordinator after
each merge.

### Lanes

Main's first-parent commits from the plan `e4837b6e` (lane tip in brackets),
in merge order:

| Lane | Commit | What | Review |
|---|---|---|---|
| QUESTMAP | `81f252c7` (`92009e9f`) | The 14 quests' item objectives keep their source (`loader.lua` `item_sources`, `Q.source_text`, `state.lua`; own `roles`/`area` or a quest drop of the item, per variant); `grug_map/targets.lua` `mark_mobs` shared by kill and item, so rings for an area, a crosshair for a leader or garrison, only while open; the quest log and the map's tooltips "Bring Runner's Packet: 0/1 (from Trench Archer) (level 38–40)", the HUD "0/1 Runner's Packet from Trench Archer"; `check_names` runs on an item's own source; the Bannerbreak sentence of `border_packets`; fixture `tools/r69_questmap` (1238 checks) and an engine probe | MERGE; reviewer's probe on seed 2026 equal to the lane's on 42: 14 quests, 31 variants, 0 without a target, 0 marks when finished, 166 plain item rows, 0 marked |
| HOME | `410a8639` (`dcb65117`) | `grug_home/travel.lua`: `request` uses `grug_home.get` only, legs `go_home` and `go_innkeeper`; the cube is loaded and judged before any teleport, so one held teleport to the stone or none; claim, then innkeeper, then the start pocket, the hold released only where the player is valid; a claim lost on the way redirects; the unfuelled message; Help's home line; `home_travel.md`, `housing.md` §8, `world.md`, `progression.md`, `pvp.md`; one comment in `grug_pvp/init.lua`; fixture `tools/r69_home` (271 checks), the Round 25 engine probe gained respawn steps | MERGE (a stale line in `world_zones.md`, fixed here); 2,222,222 event sequences to depth 6 without a violation; 40 return and 5 waystone scenarios, 209 transcript lines identical to the base |
| SKILLS | `449ac5a1` (`1c998f53`) | One form "N damage" through `skill_text`; Strike, Hamstring and Retort's plain swing gain theirs (`plain_swing_raw`, the moved swing formula, shared by swing and tooltip, damage unchanged); Opening's three values; status changes run `sync_descriptions`; `talent_graph_ui.lua` appends the stack's own text on granting nodes, learned or not; the open Talents page re-renders on equipment and status changes; `classes.md`, `skill_trees.md`; fixture `tools/r69_skills` (1,549 checks) | MERGE (one stale comment, fixed by the coordinator); 160 swing cases and 96 real transactions equal; 35 granting nodes for every viewer |
| UI | `6c79288d` (`e87832bd`, the coordinator's doc line on the lane's `0a4c3abe`) | New `grug_inventory/trash.lua` (195 lines): box "Trash" at the bottom of the right column, Money shorter; a detached list that stays empty, Undo in memory; `refresh_inventory_page`; ruling 7 in tabs, overview, Help, `grug_jobs.AREAS`, `details.lua` `slot_of`; the Help line; `inventory_equipment.md`, `professions.md`, module guide, mod map; fixture `tools/r69_ui` (124 checks), `ui_dialogs` scenes | MERGE AFTER FIXES (the doc line); no code finding; engine read for loss and duplication; no real mouse drag, first on the checklist |
| CAMPART | `325737b2` (`814e1c37`) | GPT-6 Astra's `tools/r69_camp_art/`: A Wallwright, B First Lift (the artist's recommendation), C Panel Yard; 18 templates, 72 native rotated stamps; an offline 3D pick page and PNGs; `build.py --check` PASS; the page's canvas fix by the coordinator (`2f44ae22`); the user's pick recorded | coordinator check |
| CAMP | `67391a4b` (`4d833804`) | `camp_site_<race>.tpl` (`tools/r69_camp/install_pick.py`), `grug_mapgen/camp_rewrite.lua`, `wp40/r69_camp_sites.lua`, the step and handler 0.69.0; emerge, clear metadata and timers, write the writer's own cells, then a read-back before the key goes (three passes, then `[GRUG-SEVERE]` with the key kept); 0.69.0 in `game.conf` and `upgrade.json`; contract §5.8, §5.9, `upstream-workarounds.md` entry 8, `settlements.md`, `pvp.md`, module guide; fixture `tools/r69_camp`, `run.sh` the two-boot proof, `check_escape.py` | MERGE AFTER FIXES (High: a neighbouring chunk's blit can undo a write, reproduced; two Lows; the preparation digest), then MERGE (a forced real race: five boxes undone, pass 2 mended them; full world identity unchanged by hash) |
| D | this section | the completion, the GUI checklist, STATUS, AGENTS, BACKLOG, README, CHANGELOG, ROADMAP, the review's doc lines in `world_zones.md` and `quests.md` (the version and declaration were set by CAMP) | independent review |

Main has **305** portable fixtures (5 new: `r69_ui`, `r69_home`, `r69_skills`,
`r69_questmap`, `r69_camp`). `mods/` against the plan commit (measured,
`git diff e4837b6e 67391a4b -- mods`): 43 files, +2639 −300: 36 Lua files, the
6 templates and one quest file.

### Decisions during the round

**The user** (rulings of §2, then):

- **Trash variant A** (own box, destroyed at once, Undo).
- **Claim respawn,** also without fuel.
- **Box rewrite with a fallback;** the proof passed, so the **fallback was not
  needed**.
- **14 quests only;** the 83 others stay unmarked.
- **Tree numbers for unlearned skills too.**
- **Camp pick: A Wallwright;** the artist recommended B First Lift.

**The coordinator** (answers to lane questions):

- UI: text at 0.85 × the page's and the short hint beside Undo stay
  (reviewer agrees); the Help line about the Trash box is added.
- HOME: if the start pocket fails too the player is released where they stand
  with "Home arrival is unavailable.", the one exception to "held until
  valid"; an unprepared claim uses the existing "arrival is blocked" message.
- SKILLS: a bowless Scout's "0 damage" stays; the strip on touch screens is
  decided at the GUI check (checklist 20, 21).
- QUESTMAP: the several-objective HUD line names no source; " from X" stays;
  "(from X) (level N)" stays (checklist 27); the dialogue is a follow-up.
- CAMP: an administrator's `protection_bypass` edits inside a box are
  overwritten (contract §5.9); the pick must hold no node needing
  initialisation (0 of 62 node types, measured on live registrations).

### Deviations from the plan

- **Lane launch:** the first launch failed with a 403 on the explicit model
  override; the lanes were launched again without it and ran on the session's
  inherited model.
- **The pick page's canvas fix:** the page showed sky only; fixed by the
  coordinator (`2f44ae22`) and republished. The Astra lane's own browser check
  was blocked by its sandbox.
- **`ground_bare` to `subsoil` at install:** `building_templates/check.py`
  refused the candidates with 42 errors, because `ground_bare` binds falling
  nodes (gravel, desert sand) on three races; `install_pick.py` swaps this one
  role, seven rear-footing cells per race. The art page's "today" column now
  shows the installed design; the original comparison is at `325737b2`.
- **Straw mats, open for the user's confirmation:** Wallwright's tents use
  `cottages_straw_mat`, which the Round 58 "no beds" fixture refused. It is
  plain decor (not walkable, no rightclick, already in war camps), so
  `r58_camps` was narrowed to real beds and `pvp.md`'s "no shelter" now calls
  the tents set dressing. This changes a Round 58 line; recommended: keep (the
  user picked the design with the mats visible). Checklist 33.
- **The fix round's read-back,** not planned: the reviewer reproduced a
  neighbouring chunk undoing a write (the engine's mapgen VM reads its one-block
  shell and blits it back). A generation that outlasts the settling time can
  still undo a write after the read-back; contract §5.9 says so.
- **`r7_runtime.lua` kept byte-identical:** it is in the preparation digest, so
  the seam moved to `wp40/r69_camp_sites.lua`; all 27 digest files equal
  `v0.68.0` by sha256, and the identity printed the same on both trees. No
  boot in `full` mode was run.
- **Help line about the Trash box:** not in UI's brief; added on the lane's own
  question.
- **`grug_jobs.AREAS` reordered and `details.lua` `slot_of`:** outside UI's file
  list, required by ruling 7 (`slot_of` hard-coded the tab numbers).
- **Plan's code facts:** free space under the deposit is 2.52 units (measured),
  not about four; the plan's HUD example did not fit, the verb goes there; no
  script owns the quest text (the JSON is its source); camps have no anchor
  banner; Opening needed three numbers, not one, with Turn the Blade.

### Numbers worth keeping

From the lanes' reports (measured there unless marked).

- **Box rewrite (final design, seed 42):** 0 of 5290 cells per box differ from
  a new world (node, param2), six camps; 0 of 34256 ring cells differ from the
  new world, 0 from 0.68.0 where it existed. Proof: 46 checks, 0 failed.
- **Cost:** emerge 0.5–1.0 s per camp, the first 4.5 s (start-up); write
  1.7–2.7 ms per camp; 11.6 s settling; settle step with the read-back 3.5–4.5 ms
  (review). First 0.69.0 start: layout rebuild about 25 s against 8 s. Settled
  heap equal to 0.68 (81.7 / 82.1 MiB, measured with the placeholder design).
- **Escape:** 549 body positions per race overlap a walkable cell, 0 without a
  way out (cell-centred; computed, no engine test).
- **Fleet:** seed fleet `quick` 100 of 100.
- **Skills, level 37 (review, by hand and transaction):** Retort 101 / 126,
  Ice Nova 71, Word of Ruin 177, Scout Strike 89, Opening 120 / 160 / 178.
- **Talents page:** about 1 KB more per tree on about 9.5 KB (estimated).
- **Quests:** 97 of 390 have item objectives, 14 name a source (31 variants,
  32 rows). HUD at 38 characters: 9 of 21 single-objective variants cut.
- No new globalstep. Claim Stone respawn: one synchronous load of at most two
  mapblocks (read, not measured).

### Checks

- QUESTMAP: `check_lua`, `check_fresh_server`, `validate.py --game` (0 errors,
  17 warnings), `r38_names/guarantee.py --check`, `build_structure.py --check`
  PASS; fixtures `r69_questmap`, `r44_mq`, `r28_q0`; full run 301/0; smoke
  boot with probe. Review: the three fixtures, own probe, three mutations.
- HOME: `check_lua`, `check_fresh_server`; `r69_home`, `r25_home_stone`,
  `r28_a5_player`, `r29_w`, `r45_pt9`; full run 301/0; engine probe 25 checks.
  Review: the five fixtures, a differential run and an event sweep. On a real
  player's hold: GUI items.
- SKILLS: `check_fresh_server`; `check_lua` (sweep 5 only on two lines older
  than the lane); `r69_skills`, the `r53_*` kits, `r46_cb`, `r52_graph`,
  `r53_live`, `r44_ts`, `r29_e4`; full run 301/0; smoke boot. Nothing was seen
  in a real client. Review: 9 fixtures, sweeps in scratch copies.
- UI: `check_lua`, `check_fresh_server`; `r69_ui` and the page fixtures; after
  merging main, full run 304/0 on `0a4c3abe`; smoke boot; real client at four
  sizes (20 shots, staged states). Review: 8 fixtures.
- CAMPART: `build.py --check`, re-run by the coordinator.
- CAMP: `check_lua`, `check_fresh_server`, `check_upgrade`,
  `building_templates/check.py` and self-test, `install_pick --check`,
  `check_escape`; `r69_camp`, `r58_camps`, `r63_camps`, `r36_w`, `r58_lift`;
  the proof at `7a1b3aba` (46/0); fleet `quick` before the fix round (no
  generation output changed after it); container step tests in phase 1
  (`tools/migration/` unchanged after); full run 304 + 1 (`r37_dc`, waiting for
  this CHANGELOG entry); smoke boot. Review: 10 fixtures, then 2 and two probe
  boots on the fix.
- Main: `check_fresh_server`, `check_upgrade`, `building_templates/check`, art
  `--check`, `validate` PASS after CAMP's merge. This lane: `check_upgrade.py`
  (compared with origin/main), `r37_dc`, `r41_up`, `r42_dr`, `r43_gs`, the
  link and anchor check of the touched documents (1164 links, 0 bad). The
  coordinator's round-end full run on main `67391a4b`: 304 of 305, only
  `r37_dc` waiting for this CHANGELOG entry, which passes on this lane.
