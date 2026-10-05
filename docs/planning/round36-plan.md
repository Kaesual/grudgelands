# Round 36 — The main questline (WP9): round plan

Coordinator: Claude (Opus 5.5), planned 2026-10-05 in a separate planning
session while Round 35 was running. Status: **approved by the user
(2026-10-05)**, with the two documentation corrections of §2.13 added at
the user's request.

This round builds V1's last missing content: WP9, the faction main
questline for levels 41–60 and its finale
([story.md](../design/story.md) §2,
[WP9 scope](work-package-scopes.md#wp9)). It sits on top of Round 29's
front quests and bounties and Round 31's fortress quests; it does not
replace them. Beside it run a small fix lane for the Round 35 GUI test, a
class fine-tuning lane from the Round 33 carry-overs, and the WP13 POI
review with its rework. Routing as before: Claude orchestrates, Opus
implements and reviews (an independent Opus review per code lane); GPT-6
Astra writes the story bible, the quest texts and the art.

Starts after Round 35 is complete, the user's Round 35 GUI test and push.
Not in this round: the walkable Nether and anything that needs it (V2), a
weather system, seed-dependent POI placement, Phase 2 content, the music
tab.

## 1. Lanes and waves

| Lane | Wave | Kind | Content |
|---|---|---|---|
| **S** Story bible | 1 | text (Astra) | names and beats for both factions' main line, the threat, the finale; the user approves it before Q starts (§2.9) |
| **E** Quest engine | 1 | code | the "use at a place" objective and its quest object, a turn-in hook, achievement wiring, chapter-chain checks (§2.4, §2.5, §2.7) |
| **R** Rift and commanders | 1 | code + data | the rift at one clash site: void crack, the rift boss with leash, 5 min respawn and the 24 h loot lockout; an elite war commander in one enemy war camp per faction (§2.1, §2.3) |
| **P** POI review page | 1 | offline renders | every POI rendered in its own race and two other race palettes, one private page for the user's verdicts and the rift-site pick (§2.11) |
| **K** Class fine-tuning | 1 | code + data, two phases | Priest heals with Intelligence, the Scout damage set under the ceiling (§2.12) |
| **F** Fixes | 1 | code | the findings of the user's Round 35 GUI test (list filled at the start) |
| **Q-A / Q-T** Main questline | 2 | data (Opus structure) | the Accord's and the Throng's main line: three chapters and the finale, corrupted sub-types, interaction places, ledger (§2.2–§2.8) |
| **T** Quest texts | 2 | text (Astra) | one text pass over both main lines and the rewritten front chains |
| **A** Art | 2 | textures (Astra) | cloaks, the void node and rift dressing, the quest objects, the boss and commander looks |
| **W** POI rework | 2 | mapgen blueprints | rework of the POIs the user marked on lane P's page, same size, position and sockets (§2.11) |
| **D** Documentation | 3 | docs | completion, GUI checklist, status files, design docs |

Wave 1 starts together. Q-A and Q-T start when the story bible is
approved and E is merged; T follows Q's structure; A starts with the
approved bible. W starts after the user's verdicts on lane P's page. D last.

## 2. User rulings (2026-10-05)

The user answered the planning questions on 2026-10-05, all as recommended
unless noted, plus three follow-ups (§2.3, §2.11, §2.1) and two
documentation corrections on the draft (§2.13).

### 2.1 The finale: "the rift"

**Ruling:** the finale is a rift at **one shared place** for both factions:
a clash site in Gravesalt Escarpment or The Skyglass Canopy near the
middle of the front, where the mobs are level 58–60 (candidates: Tombroad
Ambush, Saltgate Remnant, Skyroot Crossing, Cloudwatch Fall; the user picks
on lane P's page). Both factions come to the same place, separately and in
competition, as the premise asks ([story.md](../design/story.md) §1); PvP
contact there is intended.

- **The rift boss** is a new demonic level-60 elite on an existing mesh with
  its own look and a small kit, sized for a group of two or three players.
  It is spawned at runtime like a leader when a player comes near, bound to
  its place with a leash and a reset (the evade-home model), and returns
  **about 5 minutes** after its death.
- **The rift itself** is runtime content, not mapgen: a jagged line of
  **void nodes** cut into the site's floor once, when the place first loads,
  plus dark particles within the web budget (hundreds, never thousands).
  Void nodes are not walkable and one to two nodes deep, so a player who
  steps in sinks in and takes damage (`damage_per_second` acts on the nodes a
  player stands *in*) and can jump out. The clash site is a protected POI
  box, so players cannot dig the crack.
- **Loot (follow-up 12a):** the boss drops like a boss (two blue or gold
  items at item level 65) once per character per **24 hours**, the
  existing dragon and King lockout; a kill inside the lockout gives ordinary
  elite loot.
- The finale's last text points **below** — something answered from
  beneath — without any Nether content, travel or item (V2).

*Why:* the premise's demonic threat gets its payoff in V1 without building
the Nether; a shared place makes both factions race to the same threat; a
short respawn keeps the finale reachable on a busy server; the lockout keeps
it from becoming a gear farm.

### 2.2 Chapters and story moments

**Ruling:** three chapters per faction plus the finale, mirrored in
structure, with each faction's own texts:

1. **Ash on the Causeway** (41–46, The Broken Causeway; working title): the
   war profiteers of the front (Senn raises the dead for his tolls, Chirr
   pays with the coin of the dead) were paid themselves, in coin that
   carries a burnt mark. The other faction comes under suspicion.
2. **Behind the lines** (46–52, the Battlegrounds): camp raids and a trail
   into an enemy war camp; the other side is hunting the same people — in
   parallel, never as allies.
3. **The rift** (53–60, Gravesalt Escarpment and The Skyglass Canopy): the
   corruption grows and leads to the rift; the finale at 60.

The spine lives at the faction's **fortress Warmaster** (his free second
line) with travel handoffs to existing givers. Existing front chains are
folded in (§2.8): their texts take up the thread, the spine requires their
climaxes where it fits. The 11–30 thread of forged capital seals may be
picked up as the earliest trace.

*Why:* the story beats the scope names (corruption, The Broken Causeway,
the Battlegrounds) map onto the zones a player levels through anyway;
the fortress is each faction's war headquarters at the edge of all three
41–60 regions and has the only free quest lines.

### 2.3 Elite kills and "behind enemy lines"

**Ruling:** "enemy territory" in the strict sense (the other faction's
peaceful 1–30 land) holds nothing a level 41–60 player can fight, so the
main line goes **behind enemy lines in contested land**. The enemy
fortress garrison (twelve level-60 elites and the General) is too hard for
a regular target (user).

- **Follow-up 3a/3b:** in **one enemy higher war camp per faction**,
  crosswise — the Accord's target is the Throng War Camp in Gravesalt
  Escarpment, the Throng's the Accord War Camp in The Skyglass Canopy — a
  new **named elite war commander** (level 60, name by Astra) joins the
  garrison. The main line's mandatory step there stays **solo**: kill the
  camp's captain (a normal-tier named leader at level 60) and take his
  orders (a quest drop). The commander is the chapter's **optional
  "Group:" climax**.
- Elite kills otherwise: new corrupted elite leaders where the chapters
  need them, and the existing front elites (Last-Toll, Engine Nine,
  Glass-Throat, Salt-Counter) as optional group steps.
- The existing fortress raid on each of those two camps stays and becomes
  harder because the commander fights along; its text says so.
- No enemy king, General or player is a quest target (quests.md,
  pvp.md §7).

*Why:* the existing war camps give the beat a faction identity and a
structure without mapgen; the crosswise choice sends each faction through
both 51–60 zones; the solo rule (§2.4) holds because the elite is optional.

### 2.4 Level gates and difficulty

**Ruling:** chapters open at **41, 46 and 53**, the finale at **60**; each
chapter requires the last quest of the previous one (`requires`). The other
front quests stay ungated as today. The main line is **solo through
chapter 3**; only the finale (and optional elites) carry "Group:".

### 2.5 The quest place per contested zone

**Ruling:** a new objective kind, **"use at a place"**, fills the non-loot
quest-interaction slot every contested zone reserves
([world_zones.md](../design/world_zones.md) §16):

- A **quest object** appears at runtime at the place, an entity visible only
  to players who hold a quest for it (`set_observers`); the player
  right-clicks and holds for a few seconds; damage interrupts. Uses: light a
  signal fire, plant a banner, cleanse a burnt mark (the bible names them).
- **The place** is the zone's clash site where it has one (Ashenward March,
  Bannerbreak Mesa, the four Battlegrounds zones, both islands); in the four
  contested zones without one (Stormvault Heights, Glassroot Wilds,
  Blackwind Rise, Thunderroot Wilds) a rule-placed spot like a leader's.
  No mapgen.
- This changes the rule in [quests.md](../design/quests.md) that no
  node-interaction objective exists (user ruling).

*Why:* the slot asks for doing something at a place instead of collecting
loot; an entity needs no mapgen and no change to generated chunks.

### 2.6 New NPCs, places and mobs

**Ruling:** no new NPCs (the Warmaster's free line and travel handoffs); no
new mapgen places (clash sites, rule-placed spots, existing war camps); new
mobs only as **corrupted sub-types** of existing front families (name and
tint, data only), the war commanders and the rift boss. **No new sounds:**
the boss and the commanders take an approved voice family or stay silent
(approval gate).

### 2.7 Rewards and achievements

**Ruling:** XP and copper as today. A new **turn-in hook** in
`grug_quests` feeds achievements: one per faction for completing the main
line, each with its own cloak, and one for the finale with a cloak (Astra
art; tier N of an achievement unlocks its cloak, as today). The rift
boss's loot as §2.1.

### 2.8 XP budget: fold in, do not pile on

**Ruling:** the main line folds the existing front chains in (rewritten
texts, linked by `requires`) and adds few quests net; the quest share per
band stays roughly where it is today. The ledger is reported per faction,
not gated. Today's shares (ledger `--repeat 2`, solo): Human 40→50 104 %,
50→60 119 %; Orc 98 % and 101 % (target about 70 %).

### 2.9 Who writes what

**Ruling:** Astra first writes a short **story bible** per faction (lane
S): the names of the threat, its agents, the rift boss, the commanders and
the corrupted sub-types; the chapter beats; the interaction uses. The user
approves it. Opus then builds the structure (Q-A, Q-T) with working texts;
Astra rewrites all texts of both main lines and the folded front chains in
one pass (T); Opus re-validates; the user reads **a sample per faction**
before the merge.

### 2.10 Verification

**Ruling:** `validate.py --game` and `quest_targets.py` on the six seeds,
the ledger per faction (reported), fixtures for the new objective, the
hook, the chapter chain and the rift, one engine run for the quest object,
the rift and the boss, and the user's GUI checklist (§6). World generation
changes only in lane W (§2.11).

### 2.11 WP13: the POI review page and the rework

**Ruling (user, follow-up 11):** instead of a walk through the world, a
private **review page** (like the listening pages) with renders of every
POI: villages, outposts, bandit, mining and Mirefolk camps, clash sites,
apex camps, rare pads, the Round 14/15 compositions, the fortresses and
the war camps (about 100). Each POI is an individual composition with a
fixed race whose palette chooses stone, wood, roof and ground; the page
shows its **in-game render** with a top-down plan and the same
composition in **two other race palettes**. Per POI the user marks good /
dull / other race; the four rift-site candidates (§2.1) carry a pick.

The **rework** of the POIs the user marks runs in wave 2: **same size,
same position, same sockets** — dressing, buildings and props inside the
existing footprint, so core flattening, roads, protection boxes and the
world plan stay as they are. It is a world-generation change:
`tools/seed_fleet/run.sh quick` before its merge, `full` at the end of the
round.

### 2.12 Class fine-tuning (Round 33 carry-overs)

**Ruling:** lane K, two phases like Round 35's talent lane: phase 1
proposes, the user decides, phase 2 lands.

- **Priest heals and Intelligence:** Heal scales with `1 + Int/1000` today
  (the user's choice 2A in Round 33); propose a heal formula in which
  Intelligence matters about as much as Strength or Dexterity do for the
  damage classes (option 2B).
- **Scout damage set:** a full damage set gives the Scout +55 % at item
  level 60 and +82 % at 70, above the +50–60 % the stat check aims for
  (Warrior +47 %, Mage +45 %; [item_tiers.md](../design/item_tiers.md)
  §1.2); propose the smallest change that brings it into the band.
- Builds on Round 35's talent changes (lane B); numbers are comparisons.

### 2.13 Two documentation corrections

**Ruling (user, on the draft):** the code is right in both cases; lane D
corrects the Markdown.

- **The dragons are level 70** (`_grug_fixed_level = 70` in
  `boss_dragons.lua`, item level 70 in `items_crafting.md`). Docs that call
  the dragon a level-60 boss are wrong (`world_zones.md` "fixed-level-60
  boss"); the dragon islands themselves stay level-60 zones.
- **The Cinder Mark clue was removed on purpose** (with the Round 28–29
  quest rewrite). Docs that say it ships are wrong (`work-package-scopes.md` WP9
  status); the new main line does not bring it back under that name unless
  the story bible chooses to.

## 3. Shared conventions

- Fresh-server mode: no migrations, aliases or compatibility code.
- Numbers are comparisons, never targets (before/after on the same seed and
  method). If a change becomes clearly more complex or noticeably slower
  than planned, stop and report.
- No sound ships without the user's pick on a listening page; this round
  plans no new sound file (§2.6).
- World generation changes only in lane W: `tools/seed_fleet/run.sh quick`
  before its merge, `full` once at the end of the round. Runtime content
  (the rift, quest objects, commanders, sub-types) is not world generation;
  a spawn-recipe change re-runs `tools/r28_regions/run.sh <zones>`,
  `tools/r28_world/run.sh` and `quest_targets.py`.
- Quest rules (memory of Round 29's lanes, binding in every quest brief):
  no item tooltip texts; directions and seed-dependent places only as
  placeholders, never a fixed compass word; never "{name:X} {zone_area:X}";
  every target forms on the six seeds 42, 7, 2026, 1234, 99999, 314159;
  both factions are measured the same way; the prefixes "Optional:",
  "Bounty:", "Group:" are protected in Astra's text pass; reviews compare
  the quest JSON without `title` and `text`.
- Nether: nothing in this round requires, names or prepares the Nether's
  places, mobs, items or travel (V2).

## 4. Lanes (goals; the briefs add file facts)

### 4.1 S Story bible (Astra, wave 1)

- One page per faction, English: the threat's name and its agents in the
  overworld (a cult, a paymaster, …), the burnt mark, the three chapter
  beats (§2.2) with their climaxes, the commander, the rift boss, the
  finale's last line pointing below; names for the corrupted sub-types of
  the front families and for the interaction uses (§2.5).
- Own names, recognizable genre character, no copies from existing games;
  the factions are The Accord and The Throng; the Undead blight is old death,
  not this corruption ([story.md](../design/story.md) §3).
- The coordinator brings it to the user in German with a short summary;
  the user's approval gates Q, T and A.

### 4.2 E Quest engine (wave 1)

- **"Use at a place" objective:** a new kind in the quest registry, loader,
  validation (`validate.lua`, `validate.py`), ledger, labels (HUD, log,
  dialog) and the message feed; a place is a clash anchor or a rule-placed
  spot in a zone, with a hold time; quest text placeholders can name it.
- **Quest object:** a runtime entity at the place while a player is near,
  visible only to players with a matching quest, right-click and hold,
  damage interrupts, credit to that player; no node writes.
- **Turn-in hook** `grug_quests.register_on_turn_in(fn(player, id, def))`
  and its use in `grug_achievements` (an optional dependency); the
  catalogue rows and cloaks come with Q and A.
- **Chapter chains:** `requires` across files already works; the lane adds
  what the chain needs (for example a check that a chapter's gate and its
  prerequisite agree) only if the validators do not already cover it.
- Update [quests.md](../design/quests.md) (the new objective, the hook).
- Fixture: the objective's states, visibility per player, interruption,
  the hook firing once per turn-in; one engine run with a quest object.

### 4.3 R Rift and commanders (wave 1)

- **Rift boss:** a new level-60 elite on an existing mesh (look by A), a
  small kit, spawned at runtime at the chosen clash site when a player is
  near, leash and reset to its place, about 5 min respawn after death, the
  boss ledger with the 24 h loot lockout (§2.1) and a boss-kill callback for
  the finale achievement. Propose its numbers for a group of two or three
  (time to kill and damage taken for one, two and three players at level
  60 against a dragon and a front elite).
- **Rift:** the void node (damage per second, not walkable, own texture by
  A), a jagged line written once into the site's floor at first load and
  recorded in mod storage, particles within the web budget. Until the
  user's pick the lane works on one candidate site; the site is one
  constant.
- **War commanders:** one named elite level-60 commander in the Throng War
  Camp of Gravesalt Escarpment and in the Accord War Camp of The Skyglass
  Canopy (§2.3), through the garrison code, with a respawn like the
  captains; names from S.
- Update [pvp.md](../design/pvp.md) §6.2, the boss rules and `world.md` as
  needed.
- Fixture: lockout, respawn timing, leash, the one-time crack, the two
  commanders only in their camps; one engine run at the rift (boss spawn,
  crack, damage, reset).

### 4.4 P POI review page (wave 1, offline)

- Render every POI (§2.11) with the existing tools: its in-game race and
  two other palettes, a top-down plan, grouped by kind, with name, zone,
  race and anchor. Clash sites show the four rift candidates marked.
- A German page in the style of the listening pages with a verdict per POI
  (good / dull / other race) and the rift pick; the coordinator publishes it
  privately. No engine runs, no repository change except an optional
  render script under `tools/r36_p/`.

### 4.5 K Class fine-tuning (wave 1, two phases)

- **Phase 1:** proposals for §2.12 with a table (today vs proposed at levels
  30, 45 and 60 and item levels 60 and 70; heal per second and per mana for
  the Priest; the damage set's bonus per class), using the existing combat
  fixtures and the level-60 fit. The coordinator brings it to the user.
- **Phase 2:** land the user's picks; update `item_tiers.md`, the class
  docs and fixtures.

### 4.6 F Fixes (wave 1)

The findings of the user's Round 35 GUI test; the coordinator fills the
list at the start and assigns each finding to F or the lane it belongs to.

### 4.7 Q-A / Q-T Main questline (wave 2, one lane per faction)

- From the approved bible: the spine at the Warmaster's free line, three
  chapters with the gates of §2.4, the finale at 60; the existing front
  chains folded in (§2.8) with new `requires` where the spine needs their
  climaxes; travel handoffs between fortress, outposts and capitals.
- Interaction places (§2.5) in every contested zone of the faction's route
  (its three 31–40 zones, the four Battlegrounds zones, the islands where
  its quests go), each used by at least one quest; a 31–40 place goes into
  an existing quest of that zone where the giver's lines are full.
- Corrupted sub-types (data rows) and their spawn-recipe rows in the front
  zones; the behind-the-lines step and the commander's optional "Group:"
  quest (§2.3); the finale quest on the rift boss.
- The questline and finale achievements as catalogue rows (cloaks by A).
- Checks: `validate.py --game`, `quest_targets.py` on the six seeds, the
  ledger per faction before/after (reported), the portable quest tests.
- Working texts by Opus, then T; the user reads a sample per faction.

### 4.8 T Quest texts (Astra, wave 2)

One pass over the titles and texts of the faction's main line and its
folded front chains, after Q's structure is reviewed: the bible's voice per
race, 2–4 sentences, light humour where it fits, the quest rules of §3.
Opus re-validates (JSON diff without `title`/`text`).

### 4.9 A Art (Astra, wave 2)

Three cloaks (32×32, outer face left, lining right), the void node and
rift dressing textures, the quest-object textures, the rift boss's and the
commanders' looks (texture on an existing mesh), each with its
`LICENSE-media.md` row.

### 4.10 W POI rework (wave 2)

- The POIs the user marked dull or for another race: new buildings, props
  and dressing inside the same footprint, same position and sockets
  (§2.11); a race swap changes only the composition's palette.
- New renders of every changed POI before/after for the user.
- `tools/seed_fleet/run.sh quick` before the merge; the coordinator runs
  `full` at the end of the round.
- Keep the rift site's open floor free for the crack (§2.1).

### 4.11 D Documentation (wave 3)

Completion section here with numbers and the GUI checklist; BACKLOG (WP9
and WP13 status, Round 36 carry-overs), ROADMAP, STATUS, README;
[story.md](../design/story.md) with the main line's premise and chapters;
the design docs the lanes did not already update; the corrections of
§2.13 and the stale lines of §7.

## 5. Rules

As Round 35: AGENTS.md; `tools/check_lua.sh` (via bash) on every changed Lua
file; headless only through `LC_ALL=C chrt --idle 0 tools/luanti_headless.sh`,
never the user's Luanti folder; agents never push; no references to
commercial games; the factions are The Accord and The Throng. Engine
workarounds are listed in `docs/technical/upstream-workarounds.md`; the
coordinator checks it at the start of the round.

## 6. Verification

Each code lane: its fixture and `tools/run_fixtures.sh`,
`python3 tools/check_fresh_server.py`, one smoke boot, an independent Opus
review. Quest lanes: §2.10. Lane W: `seed_fleet quick`. End: `seed_fleet
full`, one boot of main, `tools/sync_to_luanti.sh`, the user's GUI check on
a fresh world (desktop and web build; two clients for the rift):

1. At level 40 the Warmaster shows chapter 1 as level-locked; at 41 it can
   be accepted; the fortress quests and front quests are unchanged.
2. Chapter texts read as one thread: no unfilled `{…}`, no fixed compass
   word, the burnt mark and the suspicion of the other faction come up.
3. Chapter 2 opens only at 46 after chapter 1, chapter 3 at 53, the finale
   at 60.
4. An interaction at a clash site: the object is visible only with the
   quest, holding right-click completes it, a hit interrupts it; the HUD,
   log and message feed show it.
5. An interaction in a contested zone without a clash site (rule-placed).
6. Corrupted sub-types at the front: names and looks.
7. Behind the lines: in the enemy war camp the captain drops the orders
   (solo); the elite commander stands there; his optional "Group:" quest;
   the old fortress raid on that camp can still be finished.
8. The rift: the crack is visible, stepping in hurts and you can climb out;
   particles stay modest.
9. The rift boss appears when you come near, leashes and resets, a group of
   two or three kills it, it drops two items once; a second kill within 24 h
   gives elite loot only; it returns after about 5 minutes.
10. Both factions at the rift: PvP contact as in pvp.md.
11. The main-line and finale achievements unlock their cloaks.
12. The finale's last text points below without naming any Nether place or
    item.
13. Lane K: Priest heals rise with Intelligence; the Scout's damage set.
14. The reworked POIs look as on the page, on a fresh world.
15. Lane F's findings.

## 7. Orchestration notes (for the coordinator)

- **Start state:** main after Round 35 complete, the user's Round 35 GUI
  test and push. Remove the `r35-*` worktrees first (never the sound
  download folders). Worktrees `.claude/worktrees/r36-<lane>` (`s` none:
  Astra works in the orchestration folder; `e`, `r`, `p`, `k`, `f`, `qa`,
  `qt`, `w`, `d`), `tools/bin/` copied. Briefs in
  `~/projects/grudgelands-orchestration/r36/` from `r35/common-brief.md`
  and `r35/review-common.md`; Astra lanes through
  `~/projects/grudgelands-orchestration/run_astra.sh 36 <lane>`; log in
  `r28/HANDOVER.md` under "ROUND 36". Check
  `docs/technical/upstream-workarounds.md` at the start.
- **Decided at the start:** lane F's list; the Round 35 carry-overs that
  join a lane; whether lane K needs Round 35 lane B's final talent values
  (it builds on main after Round 35).
- **Decided during the round:** the story bible (user); the rift site (user,
  on lane P's page); the POIs to rework (user, page); lane K's values
  (user); a sample of each faction's texts (user).

**Code facts** (planning session 2026-10-05, three read-only Opus agents;
hints, verify before relying on them):

- Quest engine: objective kinds `kill`, `item`, `talk` only
  (`grug_quests/registry.lua:44-58`, `validate.lua:108-143`, `:141`;
  `tools/r28_design/validate.py:840`). A new kind touches
  `registry.lua:44-58,147-157`, `loader.lua:207-222`, `validate.lua:40`
  (`OBJECTIVE_KEYS`), `:108-143`, `:528-547`, `:602-619`, `validate.py:61,
  806-840, 950-962`, `ledger.py:299-316`, `state.lua:157-169` and a credit
  function like `credit_kill` (`:466-485`), `labels.lua:42-62` (feeds HUD,
  log, dialog); the message feed is generic (`hud.lua:92-113`). Tests:
  `tools/r28_b4_quests`, `tools/r28_q0`, `tools/r28_a6_ui`, `tools/r32_f2`.
- Place triggers to copy: waystone proximity once a second
  (`grug_home/waypoints.lua:178-195`, reach 8 in `waypoints_core.lua:13`),
  per-player visibility with `set_observers` (`grug_quests/npc.lua:133-177`),
  runtime leader spawn near players (`grug_mobs/spawn_regions.lua:996-1022`,
  respawn in storage `:1026-1037`); clash anchors resolve as places
  (`spawn_regions.lua:500-520`).
- Clash sites: anchors `r20_anchor_071`–`086`
  (`grug_mapgen/wp40/r20_poi_catalog.lua:46-61`), 16×16 battlefield grade,
  four props, `host=false`, protected as `poi`
  (`world_protection.lua:83-93`). Rift candidates: Saltgate Remnant
  (−2200, −80), Tombroad Ambush (−1768, 64), Skyroot Crossing (1832, −96),
  Cloudwatch Fall (2176, 104). Zones without a clash site: Stormvault
  Heights, Glassroot Wilds, Blackwind Rise, Thunderroot Wilds.
- Kill credit and leaders: participation by damage or effective heal within
  40 nodes (`grug_mobs/init.lua:155-198`); kills match name and spawn tag,
  never the death position (`state.lua:450-461`); a new named elite is data
  (`subtypes.json` row `leader`, `tier: "elite"`, checked in
  `subtypes.lua:458-472`, plus a recipe `leaders` row,
  `spawn_regions_core.lua:148,523-563`). Level fit ±3 and levels up to 60
  (`validate.lua:19,309-310`): level-65 Generals and Kings cannot be
  targets.
- Boss ledger and lockout: `grug_mobs/bosses.lua` (`LOOT_LOCKOUT = 24 * 60
  * 60` :8, `settle_boss` ~205–240, `register_on_boss_kill` ~201); dragons in
  `boss_dragons.lua`. Drops: `grug_quality/init.lua` (`BOSS_DROPS`).
- War camps: keys `pvp_camp_<zone without front_>_<faction>_<band>`
  (`grug_mapgen/wp40/r31_pvp_catalog.lua:36-48`), so
  `pvp_camp_gravesalt_escarpment_throng_high` and
  `pvp_camp_skyglass_canopy_accord_high`; garrisons in
  `grug_mobs/pvp_garrison.lua`, names in `grug_mobs/data/pvp_names.json`;
  captains at the band's top level, normal tier with leader size and HP
  (`guard.lua:285-305`, `levels.lua:88-91`).
- Quest givers: the fortress givers declare only `front`, so each has one
  free line (`grug_quests/npcs.lua:93-101,271-280`); every outpost and
  capital envoy uses both lines; free quest sockets in four capitals
  (Highcourt, Dur Brannoc, Lethariel, Gor Drazhak), none in Nhal Veyr and
  Kezamba; Battlegrounds camps have no quest socket.
- Achievements: counters from hooks (`grug_achievements/init.lua:10-24,
  171-196`), catalogue `catalog.lua`, cloak unlock `core.lua:57-61`; no
  quest-complete hook today (`grug_quests/state.lua:403-449` fires only
  `register_on_change`).
- Front content today: 85 quests at level 41 and above in 10 front files
  plus 24 fortress quests; no `requires` crosses a file in 31–60; climaxes
  on Toll-Taker Senn (49), Standard-Bearer Ninepins (48), Watch-Captain
  Huskell (58), Paymaster Chirr (58); group elites Last-Toll and Engine Nine
  (50), Glass-Throat (59), Salt-Counter (59, Throng only), the island
  elites (60, Accord only). No quest text carries a main-story thread; the
  Round 14 Cinder Mark clue left with `content.lua` (only
  `docs/research/round14-story.md` keeps it).
- Corruption carriers: none in mapgen. Rift Spawn (`grug_mobs/rift_spawn.lua`)
  removes itself and cannot be a kill or quest-drop source; its deep row is
  WP34's. V2 reserve (never use): the Nether cast of the mob plan and the
  Fire Dragon.
- POI renders: `tools/wp13/render_blueprint.py` (isometric, real textures),
  `tools/r31_s/render.py` and `dump.lua` (plan, iso and cut views of
  compositions per race); palettes per race in
  `grug_mapgen/wp40/r20_poi_blueprint.lua` (six palettes, about lines
  31–38); each Round 20 anchor carries its own `race`
  (`r20_poi_catalog.lua`).
- **Stale lines for lane D** (§2.13): `work-package-scopes.md:32` (the
  Cinder Mark clue "ships"; "the new format has no enemy-guard objective",
  fixed in Round 31); `world_zones.md:248` ("fixed-level-60 boss"; the
  islands stay level-60 zones, only the dragon is 70); the ledger counts
  island kill XP in 50→60 although `quests.md` says island bounties count
  nothing (note for Q).

**Shared files and merge order:**

- `grug_quests` (E code; Q data and catalogue rows): **E before Q-A/Q-T**.
- `grug_mobs` (R: boss, rift, `pvp_garrison.lua`, `pvp_names.json`; Q:
  `subtypes.json`, front spawn recipes): **R before Q**; Q rebases on R's
  sub-type rows.
- `grug_achievements` (E: hook use; Q: catalogue rows; A: cloak textures):
  E first, then Q with A's files.
- `mods/MAPGEN` blueprints: **W only**; the rift and quest objects never
  write mapgen data.
- Q-A and Q-T touch different zone files except the shared Battlegrounds
  and island places; the two lanes merge one after the other through one
  integration check (`quest_targets.py` on the six seeds).
- F and K are independent; D last.
- **Pages:** lane P's review page and lane K's decision table are published
  privately by the coordinator (German, like Round 35's pages); verdicts and
  picks in `~/projects/grudgelands-orchestration/r36/`.
