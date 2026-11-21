# Round 84 — Player feedback: trade quantities, the crown, kiting, duplicate leaders (0.84.0)

Planned with the user on 2026-11-21 from the user's list of player reports and own
observations. Version **0.84.0**, expected **compatible** over 0.83.0: no world generation
changes, no saved state changes its shape. Beside the release lanes, three pieces of
preparation for Round 85 (the arena, with a map reset) and for the account page run in
parallel; they ship nothing.

Four read-only studies came first (2026-11-21; this session's research agents, no files kept).
The coordinator spot-checked their load-bearing claims against the code at main `ea8c603b`;
§4 names what each lane builds on, and every lane re-checks its own facts first (round workflow
§2 step 4). An independent Opus review of this plan (2026-11-21, verdict APPROVE AFTER FIXES:
four High, six Medium, ten Low) was checked by the coordinator and worked in.

Routing (the user, 2026-11-21): this session coordinates; Opus implements and reviews;
GPT-6.2 Astra makes the arena draft and the account page mock-up.

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a ruling until
  the user says so; a coordinator default is marked as such.

## 1. Lanes and order

Start state: main at the commit of this plan (0.83.0). Integration branch `round84` in
`.claude/worktrees/round84`. Orchestration folder `~/projects/grudgelands-orchestration/r84/`.
One wave: the six release lanes own disjoint code (shared files: §3.4).

| Lane | Goal (§4) | Who | Review |
|---|---|---|---|
| ELITE | Zone leaders (and the two other spawners of the same pattern) no longer appear twice | Opus | independent Opus review |
| WATER | Mobs swim at full speed; the Tortoise shoots back, slows and is faster in water | Opus | independent Opus review |
| TRADE | Quantity buttons 1 / 5 / 20 / Stack for buying and selling | Opus | independent Opus review; screenshots to the user |
| CROWN | The crown also raises enchants on a level 70 item; no once-per-item limit | Opus | independent Opus review |
| MAP | Zones keeps zoom and scroll; announcements get their own unread icon and a feed line | Opus | independent Opus review; screenshots to the user |
| SMALL | Cloak list sorted by name; death wear from level 10; eating on touch screens | Opus | independent Opus review |
| D | Release 0.84.0 and the round's end records | coordinator | coordinator |

Preparation, outside the release (tools and pages only, nothing merged into `round84` unless
the user says so):

| Lane | Goal (§4) | Who | Check |
|---|---|---|---|
| ARENADRAFT | A browser draft of the arena: the battlefield and the two faction buildings | GPT-6.2 Astra | coordinator; the user's picks |
| ACCOUNTMOCK | A browser mock-up of the Account page, unlinked and linked | GPT-6.2 Astra | coordinator; the user's pick |
| SITE | Read-only study: the map centre on the production seed, and what a fixed arena anchor moves | Opus | coordinator |

## 2. User rulings

From the conversation of 2026-11-21:

1. **The crown** works on an item when its item level is below 70 **or** it has an enchant
   below T7. The once-per-item limit goes. One crown still raises each enchant below T7 by one
   tier and costs the same fee and one Fallen Crown. (This reverses Round 70's removal of the
   enchant-only crown.)
2. **Quantity buttons** are 1 / 5 / 20 / Stack, for buying and for selling, and carry the real
   count. A button whose count exceeds the item's stack size or repeats another falls away
   (gear: 1; potions: 1 / 5 / 20; arrows: 1 / 5 / 20 / 100). On the sell side Stack replaces
   All and means one whole stack from the inventory. **Lot goods** ("1c per 50") are the one
   exception: one lot (the button shows the lot's count) and All (every whole lot).
3. **The Tortoise** answers an attack from range: a shot with normal ranged damage for its
   level, a range slightly above the player's longest (31 nodes: bow skills 25, Long View +3,
   the elf passive +3; so about 32), and a medium slow
   (40–50 % for a few seconds). It runs at about 3 on land (2 today) and is faster in water than
   on land (about 3.5–4). It stays neutral. Numbers are rough targets, tuned after play.
4. **Land mobs swim at full speed.**
5. **Death wear** (10 % durability of equipped items) starts at player level 10.
6. **The arena** (Round 85) stands at the map centre on the middle road; the road may run
   through it and the user prefers that. Each faction's building holds a waystone that is
   discovered like every other; the building's interior is friendly territory for its faction,
   everything outside is contested as everywhere in the Battlegrounds. The arena is protected
   from digging and building. Astra drafts the battlefield and buildings first, to be viewed in
   a browser; the look takes up the character creation screen's opening image.
7. **The arena's map reset keeps claims:** chunks that hold claims are not deleted, because
   nothing else in world generation changes and the Battlegrounds hold no claims.
   **Replaced on 2026-11-21** by the user's ruling that Round 85 is a full map reset including
   claims ([Round 85](#round-85-the-users-rulings-of-2026-11-21)).
8. **The Account page shows what the website decides.** Which rewards every linked account
   gets is set by the owner in the website's administration (today: the Cheer emote; a cloak
   may follow). The game receives that through the bridge and only displays it, also for an
   unlinked character.
9. **Astra is GPT-6.2 Astra** for all art and design work (done: main `ea8c603b`).
10. **The production seed is 3684797457838814663** (read from the rehearsal VM by the user).
11. **Round cut:** Round 84 everything compatible, with the drafts beside it; Round 85 the
    arena with its map reset.
12. **The arena's placement works on every seed,** not only on production's: more realms will
    follow. (So the site is a rule of world generation, as the dragon arenas are, never a spot
    picked on one seed.)
13. **No map filter changes zoom or scroll position** (the user's report: "Zones" changes the
    zoom). This drops the user's own pick of 2026-10-13, reaffirmed 2026-10-25, that entered
    Zones at 2×; names are small at 1× until the player zooms.

Coordinator proposals the user did not object to (2026-11-21); defaults until overruled:

14. The cloak list: "No cloak" first, then by the displayed name, case-insensitive, articles
    counted ("The Unbought Banner" under T).
15. The announcements icon stacks under the letter icon with its own count; the letter icon then
    counts letters only. A new announcement posts one feed line to online players.
16. Eating on touch screens: for food items a long tap holds "place", so the existing
    hold-to-eat runs unchanged. **Limit (plan review H3):** with food in hand a short tap must
    still open a door or chest and talk to an NPC. The lane first tries the gesture only where
    nothing is pointed at (and on objects, where it already holds today); if eating then is not
    reliable, or a short tap loses its use, it stops and brings the options to the user.
17. The crown leaves empty enchant channels alone, and the preview says so.
18. The duplicate fix also covers the rift boss and the depth-pulse mobs if the lane confirms
    they share the cause.

Coordinator defaults added after the plan review (2026-11-21); the user has not seen them
decided yet:

19. **The crown is refused when it would raise no number:** neither the item level nor any
    enchant's value. An enchant's value is capped by the item level (L = min(item level,
    10 × tier, 70)), so a second crown on an already crowned item below T6 would only change the
    tier label and still cost the fee and a Fallen Crown. Ruling 1's own case (level 70, a T6
    enchant) gains value and is allowed.
20. **Stack on a sell row** sells the whole slot the row stands for (at most one stack) and
    shows its count, also when the slot holds less than a full stack; it stays when its count
    repeats another button's only if that keeps "everything in this slot" one click away (13
    potions: 1 / 5 / Stack 13).
21. **The quantity rule beyond the vendor shelves:** the guild Trade-in and the Stonewright
    count lots or recipe conversions, so they take the lot form (one lot, All); the camp
    vendor's reputation page takes the buy form.

## 3. Shared conventions

### 3.1 Coordinator defaults (the user may overrule)

- **Quantity rows show the total price** of each amount (on the button or in its tooltip), and
  an amount the player cannot afford or cannot carry is greyed text, as the sell row does today.
- **The announcements icon** is built from the existing announcement motif
  (`grug_mail_admin_badge.png`) through the HUD texture generator; no new art lane. The user
  sees it on a screenshot before the merge.
- **The Tortoise's shot** reuses the bite clip (the model has no shoot clip) and a small
  generated projectile texture; the slow goes through `grug_mobs.slow_player`, so it shares the
  one mob-slow slot and does not stack with a web or a hex.
- **The Tortoise's change applies to all six tiers** (sub-types carry no speed or ability
  fields; the format is not extended for this), so the level 1–10 Pond Terrapin in the start
  lakes shoots back too. A Tortoise saved while slowed or evading may keep its old run speed
  until it resets; accepted.
- **Leaders already duplicated in the production world** disappear by the same mechanism that
  prevents new ones (at activation), with no migration step.

### 3.2 Release

`game.conf` 0.84.0; `tools/web_data/upgrade.json` declares **compatible**. Every lane reports
its classification; a lane that finds its change is not compatible stops and reports before
building it.

### 3.3 Reversed records

These earlier decisions are reversed on purpose; each lane rewrites the design text and the
fixture that pins the old behaviour instead of working around it:

- the enchant-only crown and "once per item" (`item_tiers.md` §4, `economy.md`; `tools/r33_c4`,
  `tools/r33_c5`): CROWN;
- Zones at 2× (`world_map.md`; `tools/r44_mq`): MAP;
- the letter icon counting announcements (`mail.md`, Help; `tools/r48_hud`, `r48_mail`,
  `r27_minimap`): MAP;
- the Tortoise a player can always walk away from (`combat_stats.md`, `biomes_mobs.md`) and
  "both swim at half their land speed" (`combat_stats.md`; `tools/r42_nv1` D8): WATER;
- sell amounts 1 / 5 / 10 / All (`economy.md`, `miners_guild.md`; `tools/r48_sell`, `r58_rep`,
  `r70_guild`, `r29_b`, `r56_small`, `r28_a6_ui`, `r451_mc`): TRADE;
- death wear on every death (`durability_repair.md`; `tools/r70_death`): SMALL;
- Round 85 only: the keep-claims map reset discarded on 2026-11-15 (`docs/STATUS.md`) returns
  with ruling 7.

### 3.4 Shared files

A later lane merges the round branch in before its review (round workflow §2 step 6).

- `mods/PLAYER/grug_inventory/help.lua`: CROWN (the crown line), SMALL (death wear, eating),
  MAP (the letter icon's line). Merge order CROWN, SMALL, MAP.
- `docs/technical/modules/items-professions.md`: CROWN, then TRADE ("Traders and money").
  `docs/design/economy.md`: CROWN ("once per item"), then TRADE.
- `docs/technical/modules/mobs.md`, `mods/ENTITIES/grug_mobs/init.lua`, `VENDOR.md` and
  `mods/ENTITIES/mobs/api.lua` (vendored: a change carries a GRUG PATCH marker and a `VENDOR.md`
  entry): WATER, then ELITE (ELITE touches the vendored file only if it must).
- `docs/design/combat_stats.md`: WATER only. `docs/design/world_map.md`: MAP only.
- `CHANGELOG.md`, `docs/STATUS.md`, `game.conf`, `upgrade.json`: D only.

## 4. Lane goals

Each brief adds the file facts; the goal is what counts.

### ELITE

Players see named zone leaders twice ("Elite Gravewood Treant Hollowbell", "Elite Bog Witch
Salt-Counter"). Finding to re-check: `SR.leader_tick` (`grug_mobs/spawn_regions.lua`) sets
`static_save = false` only after `add_mob` returned, so the engine has already stored a copy in
the mapblock; when a living leader's block unloads, that copy stays on disk, comes back at the
next visit, and the spawner adds a second, tracked leader. Start NPCs had the same fault
(Round 30) and the rule is in `docs/technical/modules/mobs.md`. Goal: at most one of each leader
at any time; copies already saved in a world (they carry `_grug_authored` and the leader
sub-type, but no leader mark) remove themselves when they activate; a stray copy never pays out
as a leader. The mechanism is the lane's choice. The plan review found that the rares' liveness
generations do not fit as they are (a leader is never saved, so its saved copy would hold the
current generation and could win the claim); the start NPCs' guard (`start_npcs.lua`, the
`placing` flag and `_grug_unplaced`) and the Expedition packs' body registry are closer models.
Mind that the real leader's first activation runs inside `add_entity`, before the spawner sets
any field. Check the rift boss (`rift.lua`, identifiable by its name) and the depth-pulse mobs
(`depth_pulse.lua`) for the same cause and fix what can be told apart; depth-pulse copies
already saved look like ordinary mobs and stay. A fixture models the saved copy. Docs: the wrong
comment in `spawn_regions.lua`, `mobs.md`, and an entry in
`docs/technical/upstream-workarounds.md` for the engine's add-time record.

### WATER

Two exploits of slow mobs. (1) `grug_liquid_speed` (`mobs/api.lua`) halves every swimming mob,
so a player in water (who keeps 4 nodes/s) kills land mobs safely: mobs that swim keep their
land speed in water (ruling 4); lava keeps slowing, and the stuck detector keeps using the same
number.
(2) The Tortoise (`grug_mobs/tortoise.lua`, run 2, no ability) can be kited by anyone with a
ranged attack: ruling 3. The Bog Witch's hex bottle is the template for a slowing shot; a
mob's shot range is its view range + 4 unless the definition sets `_grug_shot_range`, which the
arrow's target lock reads too. The lane verifies that a neutral mob with view range 8 answers an
attacker at 32 nodes and that the mob stays active at that distance, and reports the numbers it
chose with the reason. Docs: `combat_stats.md` (speed table, swimming), `biomes_mobs.md`,
`mobs.md`; `crocodile.lua`'s header ("4.6 on land and in water") is re-checked, it becomes true. Particle budget and the terrain guard apply as always.

### TRADE

Every vendor uses `grug_traders/trade.lua`; buying gives one item per click everywhere, selling
has 1 / 5 / 10 / All (single goods: one row per slot; lot goods: one row per item name). Goal:
ruling 2 with defaults 20 and 21 on every buy and sell row of the shared window, the guild
Trade-in, the Stonewright and the camp vendor's reputation page. A bought
amount is paid and delivered as one transaction or not at all, and the window's existing
re-validation against its snapshot stays. Screenshots (a decor row, arrows, a potion, gear, a
lot good, a part-filled slot on the sell side, an unaffordable amount) go to the user; merge
after the user's go. Docs: `economy.md` (the sell window), `miners_guild.md`,
`modules/items-professions.md`; the fixtures of §3.3.

### CROWN

Ruling 1 in `grug_quality` (`crown_plan`) and the Crownbinder's window
(`grug_traders/crown.lua`): refuse only when no number would rise (default 19); the level line of the preview
appears only when the level changes; the "Crowned" tooltip line and the meta flag need a
decision by the lane on what they still mean without the limit (report it). Empty channels:
default 17. Texts: the window, Help, `item_tiers.md` §4, `items_crafting.md`, `economy.md`,
`modules/items-professions.md`; the `CROWN_FEE` line in `crown.lua` stays as it is
(`income.py` parses it); the fixtures that pin the old refusals are rewritten to the new
rule, the reported case (level 70, one T7 and one T6 enchant) among them.

### MAP

(1) Remove the zoom step when Zones is chosen (`grug_map/window.lua`); no layer changes zoom or
scroll, and a fixture says so for every layer. (2) Announcements: `grug_mail` hands the minimap
two counts; the side row gets a second icon under the letter icon (default 15, §3.1), with the
hidden-minimap layout and the "Now playing" line moved accordingly; one feed line per new
announcement. Screenshots (minimap shown and hidden, letters only, announcements only, both) go
to the user; merge after the user's go. The icon is ten textures (1–9 and 9+) from
`tools/r48_hud/gen_hud_textures.py` with rows in `grug_map/LICENSE-media.md`; if the generator
cannot take the badge motif, the lane reports instead of painting something else. Docs:
`world_map.md`, `mail.md`, Help.

### SMALL

Three small, independent changes. (1) `grug_achievements.cloak_dropdown` sorts by default 14;
`R.unlocked` keeps its order. (2) `grug_repair.wear_death` does nothing below player level 10
(a named constant; the mod declares the dependency it now uses); Help and
`durability_repair.md`, `progression.md`, `pvp.md`, `expeditions.md` say so. (3) Food sets the
engine's per-item touch gesture so a long tap holds "place" (default 16); the tooltip and Help
gain the touch wording. The lane reports what a short tap and a long tap with food in hand then
do on a chest, a door, an NPC, plain ground and nothing, read from the engine source.

### ARENADRAFT (GPT-6.2 Astra; tools only)

Design goals, not a parts list: a battlefield with one Accord and one Throng building facing
each other, in the spirit of the opening image
(`tools/character_creation_preview/intro/`, a block scene of shipped nodes; there the two works
stand about 40–70 nodes apart, a starting point and not a target); each building has an interior that reads as the faction's safe room with a
place for a waystone and a clear threshold to the open field; the middle road runs through the
battlefield as its axis and the buildings stand beside it, not across it; the ground between
gives cover and lines to fight over; the whole footprint fits a levelled site on gentle ground.
Technical rules: shipped nodes only, the building template or blueprint formats, viewable in
`tools/building_templates/viewer`. Output: a page with two or three variants and stills, as
`tools/r69_camp_art` did, for the user's picks.

### ACCOUNTMOCK (GPT-6.2 Astra; a page only)

A browser mock-up of the inventory's Account page in the game's UI style, two or three
variants, each unlinked and linked. Goals: the page explains linking in three steps (open
grudgelands.com/play, create a code there, enter it here), names grudgelands.com with a button
that opens it, shows the rewards every linked account gets before linking and the account's rewards
after, carries one strong image, and makes the code entry the clear call to action. Frame: what
formspecs can draw (`docs/technical/ui-presentation.md`), the 20 × 13.5 inventory body, existing
textures or proposed new art marked as such.

### SITE (Opus; read-only)

With the analytic world tools (LuaJIT, no engine), on the production seed
3684797457838814663 and on a handful of other seeds from `tools/seed_fleet/seeds.txt` (ruling
12): the relief, water and existing placements within about 200 nodes of (0, 0), the middle
road's course there, the two fortresses' distances; a picture per seed the user can read, and
the worst case named (the steepest and the wettest centre found). Then, as far as the tools allow without
changing shipped code: what adding a fixed anchor at the centre would move (war camps, roads),
and whether anything outside the four Battlegrounds zones changes, which decides ruling 7's
condition. Findings are proposals for the Round 85 plan.

### D

Version, upgrade declaration, CHANGELOG, STATUS, the module and design docs the lanes did not
own, this plan's Completion and Carry-overs.

## 5. Rules

- AGENTS.md and the round workflow apply; the faction names, "Expedition" and the naming rule
  hold in briefs and pages too.
- Fixtures: a lane runs only the fixtures its change touches; the one full run is the
  coordinator's at the round end.
- A fix delta that changes game logic gets an independent delta review.
- TRADE and MAP are merged only after the user's explicit go on their screenshots.
- Numbers for the Tortoise and prices are rough targets; no extra gates are built around them.

## 6. Verification and human tests

Per lane the gates of round workflow §3 and its own fixtures; at the round end the full gates
and one headless boot. Human-test proposals (offers, not open items):

- **Touch:** on a phone or tablet, hold food in the hand and long-press: the eating ring runs
  and one portion is eaten. No fixture can see this.
- **Tortoise:** shoot one from maximum bow range, on land and across water.
- **Leaders:** find a zone leader, walk away for a minute, come back: one leader.

## 7. Orchestration notes

- **Website message (early):** the Account page of ruling 8 needs the website's list to carry
  the rewards every linked account gets. The coordinator drafts the request to the kaesual
  coordinator at the round's start and gives it to the user; the game side is built after the
  mock-up pick (Round 85 or a small round of its own) and shows no reward strip while the field
  is missing.
- **Platform message (after SITE):** the keep-claims map reset needs the platform's deletion
  tool; Round 77's interface notes (`~/projects/grudgelands-orchestration/r77/`) are the
  starting point.
- **Process budget:** six release lanes at once fit the Lua queue's limit; Astra lanes run
  through `run_astra.sh 84 <lane>`.
- **Compaction checkpoints:** C0 before the start (the user compacts after this plan); C1 when
  all lanes are launched; C2 when the reviews are in; C3 after the merges, before D and the
  round-end run.
- **Decided during the round:** the user's picks on the two pages and the two screenshot sets.

## Completion (2026-11-21)

The six release lanes (Opus each) ran in one wave and each got an independent Opus review;
every verdict was MERGE. CROWN and TRADE each had a fix round for a stale double click, each
closed by an independent delta review (MERGE). TRADE, MAP and CROWN (whose window layout
changed) merged only after the user's go on their screenshots. Lane D (this section) runs on
`round84` after the first pass of the round-end gates. Release **0.84.0**, **compatible**:
no world generation change and no saved key read or written differently (each lane's
classification, checked by its reviewer); copies of leaders and the rift boss that older
versions saved remove themselves at activation, with no migration step (§3.1).

Merges into `round84`, in this order (working notes until the squash): SMALL `79ff752e`,
WATER `9a917cee`, ELITE `d744ccac`, CROWN `d2a2e0b4`, TRADE `9809d463`, MAP `81ec1a74`; then
the coordinator's fixture-list fix `2d706942`; after lane D, on the user's go, the three
preparation branches (tools only) SITE `cbd86d21`, ACCOUNTMOCK `47d9df6c`, ARENADRAFT
`fecc36bc`, and SMALL fix round 1 (the user's touch rulings below). Before those, 98
files, about +4,200/−540 lines (43 of the files under `tools/`).

**What shipped:**

- **TRADE** (ruling 2, defaults 20 and 21): one rule, `grug_traders.quantities(kind, size,
  held)`, gives every row its buttons. Buying: 1 / 5 / 20 / Stack up to the stack size (gear
  1, potions 1 / 5 / 20, arrows Stack 100, most goods Stack 99). Selling a slot: the numbers
  up to the slot's count and Stack for the whole slot (13 potions: 1 / 5 / Stack 13; amounts
  above the slot are left out, not greyed). Lot goods, the guild Trade-in and the Stonewright:
  one lot and All. The camp vendor's reputation page: the buy form. Fields are
  `<prefix><key>_<index>`, and the count is derived again from the key on the fresh row, so a
  forged or stale key does nothing. Buy rows show "Xc each"; each button's tooltip gives the
  total (not on "1"); an amount above the player's money or room is grey text. A purchase
  checks room first, then takes count × price and gives one stack; `grug_guild.buy` gained a
  `count` (error `"count"`). A single-good sell row now also re-checks the count and the unit
  price against its snapshot. The longest page, the Decor Merchant's (128 rows), grew from
  52,497 to 63,375 bytes (61,596 logged by the engine; the lane first had 80,737 and cut it by
  styling the names once per shelf and dropping the "1" tooltip); the other pages stayed about
  the same or shrank. Fix round 1: a new form name per render (`grug_traders:trade:<serial>`),
  so a click or quit from an older form acts on nothing (the review found a stale second
  click on the Sell tab selling the item that moved into the row). Fixtures: new
  `tools/r84_trade` (with section G, the double clicks), and `r48_sell`, `r56_small`,
  `r58_rep`, `r58_campnpc`, `r70_guild` rewritten to the rule.
- **CROWN** (ruling 1, defaults 17 and 19): `crown_plan` lifts the item level to
  max(item level, min(10 × T + 10, 70)) and every enchant below T7 by one tier; it refuses
  only when neither the level nor any enchant's value rises ("The crown would raise nothing:
  …"), and nothing is taken then. Empty channels stay empty and the preview says so; the
  preview gives each enchant's value before and after and the level line only when the level
  rises. The reported case (level 70, T7 Strength, T6 Crit) gives "T6 Crit +4.3% becomes T7
  +4.8%." The chain ends: the level reaches its target at the first crown, every later crown
  must lift a tier, tiers stop at T7, so one set of enchants takes at most six crowns (the
  fixture loops to exactly six). `grug_crowned` now means "crowned at least once" and drives
  only the tooltip's "Crowned" line (the lane's decision: no new key, no counter). The fee
  line reads "and one Fallen Crown per crown"; `CROWN_FEE` is unchanged. Layout follow-up
  (display only, checked by the coordinator on the screenshot): five rows of 1.08 per page,
  so two-line previews show without a scrollbar. Fix round 1: a new form name after every
  crown, so a double click from the old form crowns nothing. Fixtures: `r33_c4` E and
  `r33_c5` F rewritten (no `tools/r84_crown`: the existing harnesses load the real code);
  the capture scene `crown_enchanted` in `tools/ui_dialogs`.
- **WATER** (rulings 3 and 4): `grug_liquid_speed` (vendored `mobs/api.lua`, two GRUG PATCH
  markers, `VENDOR.md` totals 158 / 196): water (group `water`) no longer slows a mob, and a
  definition's `_grug_water_speed_factor` makes it faster there; lava keeps v / (viscosity +
  1), 1/8, and the stuck detector shares the number. The Tortoise: `dogshoot` (bite close
  in), a homing mud ball `grug_mobs:tortoise_mud` (damage stamped for the level, a slow to
  0.55 for 3 s through `grug_mobs.slow_player` on players only), shot range 33, a shot about
  every 2.5 s, run 3, water factor 1.25 (3.75), view range 8, still neutral; the shot plays
  the bite clip and is silent; a generated sprite (CC0,
  `tools/r84_water/gen_mud_texture.py`). It applies to all six tiers (§3.1). The lane
  confirmed from the engine source that a hit at 32 nodes makes the attacker the target
  (no distance test; give-up distance 45 or unlimited) and that the mob stays active there
  with the default `active_block_range` 4. Fixtures: new `tools/r84_water`; `r42_nv1` D8
  rewritten; a `register_homing_arrow` stub in `r51_mobs`.
- **ELITE:** the cause, confirmed in the engine source and at runtime: the engine stores an
  object's staticdata in its block at the add, after the activation callbacks, and a later
  `static_save = false` does not remove it when the block unloads while the object lives
  ([upstream workarounds §11](../technical/upstream-workarounds.md#11-an-unsaved-objects-add-time-entry-survives-its-blocks-unload)).
  New `grug_mobs/unsaved.lua`: `add_mob_unsaved` and `add_entity_unsaved` mark the entity
  being placed, and `unsaved_claim` (the first statement of `init.lua`'s after_activate
  wrapper, before `live_claim`) turns static saving off inside that activation; any other
  activation of a definition marked `_grug_unsaved` (the 45 leader sub-types, the rift boss)
  removes itself before anything runs, with one `action` log line. The leader spots, the
  rift boss and the depth pulse add through the helpers; old depth-pulse copies look like
  ordinary mobs and stay (default 18). Fixtures: new `tools/r84_elite`; `r28_s1` (with the
  saved-copy cases), `r36_r`, `r46_dp` run the real claim; the probe `r36_q0` adds its rift
  boss through the helper (review Low 1, a coordinator fix). The engine probe
  `tools/r84_elite/engine.sh` ran three times: the first failed in its own setup, the second
  ran away (its log wrapper caught its own lines: 2 × 8.4 GB in `/tmp` within a minute, killed
  by the coordinator; probe code only, now capped at 200 lines), the third passed (an object
  made unsaved after its add came back, a leader added the 0.83.0 way came back and removed
  itself, a leader added unsaved left nothing).
- **MAP** (ruling 13, default 15): the step to 2× on Zones is gone, and `r44_mq` now clicks
  every layer from every other and from quest mode, at 1× and 4× with the scrollbar echo,
  checking zoom, scroll, lock and the sent form. `grug_mail.unread_counts` hands the minimap
  letters and announcements apart (`set_mail_count(name, letters, announcements)`); the
  shield icon (ten textures 1–9 and 9+ from `tools/r48_hud/gen_hud_textures.py`, CC0, derived
  from the Round 48 badge) stands under the letter icon, or in its place when no letter is
  unread (the user's correction during the round, follow-up 1), with "Now playing" below the
  icons shown when the minimap is hidden; `send_broadcast` posts "New announcement:
  <subject>." to every online player. Fixtures: new `tools/r84_map`; `r44_mq`, `r48_mail`,
  `r48_hud`, `r27_minimap` rewritten.
- **SMALL** (ruling 5, defaults 14 and 16): the cloak picker sorts its own fresh list ("No
  cloak" first, then by the shown name, case-insensitive, articles counted; `R.unlocked`
  keeps the catalogue order); `grug_repair.DEATH_WEAR_LEVEL = 10` (the mod now declares
  `grug_xp`); food sets `touch_interaction` (pointed at nothing a long tap holds place, at a
  node and, since fix round 1, at an object a short tap places), with a tooltip line and
  Help in the same words ("the sky or anything out of reach"). The touch table, read from the
  engine source and confirmed by the reviewer (the object row by fix round 1's delta review): eating works wherever the player points at
  nothing; a short tap still opens a door or a chest and talks to an NPC or trader; at an
  object a long tap punches (no damage with food in hand; it picks up a dropped item), so no
  eating there. Fixtures: new `tools/r84_small`; `r33_c3` F, `r70_death` W, `r56_small` F
  rewritten.

**Reviews:** SMALL MERGE (one optional Low: the tooltip's wording, fixed in fix round 1 on the
user's ruling). WATER MERGE (one Low: the fixture's swim model, a carry-over). ELITE MERGE (one
Low, fixed by the coordinator: the `r36_q0` probe). CROWN MERGE (one Low: a quick double click
paid for a second crown, plus two doc lines; fix round 1, delta review MERGE). TRADE MERGE (a
Low on `room_for` per row; its backlog note on the stale Sell click became fix round 1, delta
review MERGE). MAP MERGE (one Low, a stale comment in `zone_labels.lua`, fixed by the
coordinator).

**The user's choices during the round:** TRADE "looks good", with both lane questions as
built (sell rows leave out amounts above the slot; the buy button reads "Stack 99" /
"Stack 100"). CROWN: go on the five-row screenshot. MAP: the announcements icon moves up into
the letter icon's place when no letter is unread (a change of default 15), then go. The
preparation pages: "Breach Road" for the arena and "The Charter" for the Account page (see
Round 85 below).

**Decided on 2026-11-21 (the user, after lane D):** touch eating: with food in hand a short
tap at an NPC talks to it (`pointed_object = "long_dig_short_place"`, SMALL fix round 1; a
long tap at an object then punches); no touch eating in a small room where everything is
within reach is accepted as it is; the tooltip's touch sentence takes Help's wording. The
start-zone Pond Terrapin keeps shooting back (§3.1, as built). The three preparation
branches (SITE, ACCOUNTMOCK, ARENADRAFT; tools only) were merged into `round84` on the user's
go.

**Deviations from the plan:**

- Refuted lead (WATER): a swimming player keeps about 2.7 nodes/s, not 4 (engine source); the
  reasoning of ruling 4 holds the more.
- Default 16's limit (plan review H3) did not hold before the round either: with food in
  hand a short tap at an NPC punches under the default touch settings. The lane left objects
  as they were; on the user's ruling of 2026-11-21 SMALL fix round 1 made a short tap at an
  object a click, so the limit now holds.
- CROWN has no `tools/r84_crown`; its cases live in `r33_c4` E and `r33_c5` F.
- TRADE's optional room data once per render was not built (it needs a new shared helper in
  `grug_inventory/storage.lua`).
- The preparation lanes (ARENADRAFT, ACCOUNTMOCK, SITE) were not planned to merge into
  `round84` (§1); on the user's go they were merged after lane D (tools only).

**Gates** (first pass on `round84` at `81ec1a74`, before lane D, on the user's instruction):
the one full fixture run 380 passed and 1 failed: `r72_ranged` R2, whose list of ranged mob
files lacked the Tortoise that WATER made a shooter; the coordinator added it (test list
only, `2d706942`) and reran that fixture alone: PASS. `check_fresh_server.py` PASS,
`check_upgrade.py` PASS (then still at 0.83.0), `income.py --check` PASS,
`validate.py --game` 0 errors (the 18 known warnings), one smoke boot PASS (listening, no
error; two spawn-region warnings, Carry-overs). No seed fleet: no world generation changed.
Lane D: `check_upgrade.py` PASS at 0.84.0, `check_fresh_server.py` PASS, the fixtures that
read the version, the declaration and the changelog (`r37_dc`, `r41_up`, `r43_gs`) PASS, and
`r72_ranged` once more on the branch head: PASS (222 checks).

**Preparation for Round 85 (shipped nothing):** ARENADRAFT (GPT-6.2 Astra): "Breach Road"
(99 × 87) over "Hollow Span"; a second pass after the user's notes (terraces, a less uniform
field, sparse smoke, some dressing, a palette that fits the zone), which the user liked. ACCOUNTMOCK (GPT-6.2
Astra): "The Charter" over "Village Road". SITE (Opus, read-only, 11
seeds): (0, 0) lies on the border of zones 35 and 36 on every seed; relief within 200 nodes
75–307, the 100 × 100 square 21–139 nodes high and holding up to 370 water columns; the
middle road crosses that square on 10 of 11 seeds; a fixed anchor of the dragon arenas' kind
changes claim zones on 9 of 11 seeds, the variant hidden from the zone field, terrain field
and inland water without a road reserve changes none. With the full map reset (below) that
constraint no longer binds. The website message (the rewards every linked account gets) went
to the user; the platform message for a keep-claims reset is obsolete.

**Human tests (offers):** the three of §6 (touch eating, plus with food in hand a short tap at
an NPC that talks and a long tap at a hostile mob that does no damage; the Tortoise from maximum bow
range on land and across water, a leader after walking away); Zones at 1× on a phone or a web
window (are the names readable without the old zoom); at a vendor buy 20 arrows and a Stack of
torches and sell a part-filled potion slot with Stack, on desktop and web; at a Crownbinder
crown a level 70 King drop that has one re-enchanted T6 enchant.

### Follow-up 0.84.1 (2026-11-21)

A small follow-up round on its own branch `round84.1` (one lane, Opus), from the user's
report of 2026-11-21: since SMALL fix round 1 made a short tap at an object a place click,
a short tap with food in hand at a dropped item did nothing (only a long tap, a punch,
picked it up); with any other item in hand a short tap picks a drop up. Release **0.84.1**,
**compatible** (no saved state, no world generation; one runtime branch).

- **What changed:** `grug_food.click`, the food click a short tap at an object (or a short
  RMB click) performs on release, hands a pointed `__builtin:item` to the one pickup path,
  `grug_inventory.pick_up_pointed` (one attempt through the entity's own `on_punch`; a full
  inventory leaves the drop lying; the wielded stack is not written back), and does nothing
  else there. `grug_food` now declares `grug_inventory` (it already loaded after it through
  `grug_abilities`; no cycle). On desktop a short right-click with food in hand at a drop
  picks it up as well (accepted in the brief). A held press still never clicks: the click
  runs only while the press is undecided (`input.lua` `release_right`), so a press that
  reached the eating stage at 0.35 s never picks up; on a touch screen a long tap at an
  object is a punch, which picks up as before.
- **The touch table** (what a short and a long tap do with food in hand, per thing pointed
  at, read from the engine and game source) replaces the touch prose in
  [classes.md](../design/classes.md); not tried on a touch device. The pickup rule in
  [inventory_equipment.md](../design/inventory_equipment.md) names the food click.
- **Fixtures:** `tools/r84_small` gained section P (the real `grug_food.click` with a stub
  pickup: one attempt at a drop, also with a full inventory, no entity right-click, no
  wield write; an NPC still gets its right-click; a removed object and a non-food hand do
  nothing). Run: `r84_small` (the new case), and `r37_dc` and `r41_up` (they read the
  version, the declaration and the changelog). `check_upgrade.py` and
  `check_fresh_server.py` PASS; `check_lua.sh` on the changed Lua files PASS. No full run,
  no engine boot.
- **Not verified:** nothing was tried on a touch device or in a running game; the
  touch rows rest on the source reading. **Human test (offer):** on a phone or the web
  build with touch, food in hand: a short tap at a dropped item picks it up, a short tap at
  a trader talks, a long press at the sky eats.

## Carry-overs

Each line names where it came from. None is wanted work yet, so none has a BACKLOG line. The
round's open user decisions (the touch points, the Pond Terrapin, the preparation branches)
were decided on 2026-11-21 (Completion).

**Notes:**

- **WATER review Low 1:** the fixture's swim model (`tools/r84_water/portable_test.lua`, about
  line 402) scales the acceleration `inc` by `physics_speed`; the engine scales only the
  target speed, so swimming stays near 2.7 nodes/s (at most about 3.0) whatever the buff, not
  the report's 4.11 at the 1.5 cap. Game code and docs are not affected; the Tortoise's 3.75
  stays above.
- **`minetest.conf:129`:** the comment says swimming is 4 nodes/s; it is about 2.7.
- **Tortoise tuning (WATER):** a slowed player (about 2.2 nodes/s) cannot walk away from a
  Tortoise (3) while hits renew the slow; the fight ends with the 15 s damage grace once the
  player stops attacking. Tune after play.
- **Tortoise reach (WATER):** answering at 32–33 nodes needs the mob active there, which holds
  with the engine default `active_block_range` 4 (the game does not set it); production's own
  setting is unknown.
- **Trade window (TRADE review):** `render_buy` and `render_reputation` call
  `grug_inventory.room_for` once per row (128 times per render on the Decor Merchant, per
  click, not per tick; not measured). The Decor Merchant's single page is 63,375 bytes (it was
  already above the 30 KB the user found heavy); categories or pages would shrink it. Each
  scrollbar packet on that shelf tests 4 × 128 field names.
- **`grug_guild.buy` (TRADE review):** an undelivered remainder after `fits` (an impossible
  state) is only logged; `do_buy` refunds it.
- **Fast clicks (TRADE delta review):** a second click sent before the redrawn form arrived
  is lost, by design (noticeable on the web build or with lag).
- **`grug_money.format`** prints "5s 0c" (older than this round; TRADE).
- **The announcement feed line (MAP review):** up to about 78 characters, which may run wide
  on narrow windows.
- **Announcement expiry (MAP):** an announcement that expires while a player is online lowers
  the count only at the next mail event or join (as before).
- **Leaders spawned by hand (ELITE review):** an admin's `/spawnentity` of a leader sub-type
  or the rift boss removes itself at once with the log line, by design of the unsaved rule.
- **`placing` (ELITE review):** the mark is not reset if an activation raises (already a
  fatal error).
- **The 2026-11 audit's MOB2 line** ("leaders are static_save = false, so no leader survives
  an unload") was wrong in effect; the audit is a historical document and stays as it is
  (ELITE).
- **A long tap drifting** between the sky and a node switches between eating and digging (the
  engine reads the gesture every frame; harmless; SMALL review).
- **`tools/ui_polish_review/src/app.js:53`** still shows the old crown mock-up text (CROWN
  review; a tool).
- **Smoke boot:** two `grug_mobs` spawn-region warnings (`kragmar_redtusk_savanna`,
  `kragmar_ossuary_reach`), not checked for whether they are new this round.

## Round 85 outline (not a plan yet)

Written before the round; where it speaks of ruling 7 and keeping claims, the user's rulings
of 2026-11-21 ([below](#round-85-the-users-rulings-of-2026-11-21)) replace it.

Decided: rulings 6, 10, 12, and ruling 7 as the user's intent; whether its condition holds
(nothing outside the Battlegrounds changes) is SITE's question. Coordinator proposal, not a
ruling: the site is a fixed anchor with its own levelling, as the dragon arenas are, which is
what makes it hold on every seed. The upgrade contract knows no map reset that keeps claims (a
map reset empties the map), so ruling 7 needs a contract change agreed with the platform. Known from the studies: territory is answered per zone only, so the
friendly interior needs a small overlay in the PvP zone answer (and in the flight and spawn
readers); a player keeps the contact flag for 60 s inside, and area effects pass walls; an
unflagged defender cannot hit an intruder, so the buildings probably need guards as the
fortresses have (open);
waystone rows are a fixed list that takes two more entries; a new point of interest is a map
reset under the upgrade contract. Open until SITE and the draft picks: the footprint and exact
levelling, the road's routing through the site, the guards, the hostile-spawn-free area, and
whether the Account page ships with it.

## Round 85: the user's rulings of 2026-11-21

Given after checkpoint C3, during Round 84's end.

**Rulings:**

- **The arena** stands at the map's centre (ruling 6). The design is "Breach Road", in its
  second pass with terraces; its preparation came from the branches `r84-arenadraft` and
  `r84-site` (tools and pages only, merged into `round84` on the user's go). The
  battlefield must blend smoothly into the landscape, with no steep cut walls where they can
  be avoided.
- **Round 85 is a FULL map reset, claims included.** It replaces ruling 7 (a reset that keeps
  claims): the arena's placement makes no compromise for claims. So SITE's measured constraint
  (an anchor hidden from the zone field, the terrain field and inland water, without a road
  reserve) no longer binds: the arena may be a real anchor with a blending envelope and roads
  routed to it. The platform message for a keep-claims reset is obsolete.
- **The Account page** takes the mock-up "The Charter" (from `r84-accountmock`, merged). The
  page still lacks the hint that the player must click "Create Character" to generate the code;
  the implementation adds it.

**Open (under discussion, not decided):**

- **A Claim Stone rework with the same reset:** a claim of one map chunk (80 × 80 nodes;
  today 101 × 101); restricted claimable areas (for example keeping quest spawns free); one
  shared stone per account and faction. The user's further ideas (claims placed like points
  of interest, a capacity question, a link refused when both characters already have a
  stone, waystone travel to the stone from level 20, no character holding a stone after the
  reset) are to be discussed in detail and planned; the rework may be left out if it gets
  too hard. Starting points: [housing.md](../design/housing.md) for today's claim and
  [accounts-concept.md](accounts-concept.md) §5.5 for the shared stone.
