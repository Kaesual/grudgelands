# Round 36 — The main questline (WP9): round plan

Coordinator: Claude (Opus 5.5), planned 2026-10-05 in a separate planning
session while Round 35 was running. Status: **complete and pushed
2026-10-05** ([completion and GUI checklist](#completion-2026-10-05), with
the [follow-up lanes](#follow-up-lanes-2026-10-05-evening)); approved by the
user 2026-10-05, with the two documentation corrections of §2.13 added at
the user's request. The approved [story bible](round36/story-bible.md) and
the user's choices during the round
([completion](#the-users-choices-during-the-round)) win over the earlier
sections (for example §2.3's chapter-2 camp and the boss's health); the
design as built is in `docs/design/`.

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

### 2.14 Round 35 GUI findings (user, 2026-10-05)

Added by the coordinator after the plan's approval, from the user's first
Round 35 GUI test; lane F (§4.6) and lane A (§4.9) carry them.

1. **A mob running home is not shown as a target.** At the night-to-day
   change the user could not attack a rat: the crosshair turned red, the
   Fireball did not fire, no message. Cause (coordinator investigation):
   the rat was in its evade run home, untouchable by design. The crosshair
   (`grug_abilities.aimed_target` → `valid_target`, `crosshair.lua` ~154,
   `grug_abilities/init.lua` ~240–266) ignores `temp.grug_evading`; the
   click needs `fightable` (`input.lua` ~214–218), which rejects evaders, so
   the hold stays in "gather" and `activate` returns silently (`input.lua`
   ~357–360). Present since Round 32 F2, not caused by Round 35's dawn rule
   (which waits for the evade to end). **Ruling:** crosshair and click use
   one target predicate (an evading mob does not turn the crosshair red),
   and a click at an evading mob shows a short "Evading" (the TODO at
   `grug_mobs/init.lua` ~741–742).
2. **Free mobs run home only from outside their wander area.** The pursuit
   rule is implemented as decided (no distance limit while effective player
   damage arrives within 15 s; `combat_stats.md` "Ambient pursuit policy").
   But after a reset a free mob more than **4 m** from its spawn point runs
   home untouchable for up to 40 s (`aggro.lua` ~256–275, `EVADE_ARRIVED`
   ~290), although outside combat it may idle anywhere within its 32-node
   wander radius (`WANDER_RADIUS`). **Ruling:** a free (damage-pursuit) mob
   reset inside its wander radius only heals and drops its target (no run,
   no untouchable state); outside it, it runs home and becomes a normal mob
   again as soon as it is back inside the wander radius. Camp mobs, guards,
   rares, bosses, patrollers and royals keep their own thresholds. Not
   changed (user): the 15 s damage clock still starts at the first aggro.
3. **A background image for the Luanti main menu.** `menu/` holds only
   `icon.png` and `theme.ogg`; add `menu/background.png` (optionally
   `header.png`), with a `LICENSE-media.md` row; the user picks from a
   preview.
4. **The level-up banner names the talent point.** On every level that
   grants a talent point (`floor(level / 2)`, so every even level) the
   centre banner (`grug_core.banner` in `grug_xp/init.lua` ~103) gets a
   second line "You gained +1 Talent Point"; a jump over several levels
   names the right number ("+2 Talent Points").

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

The findings of the user's Round 35 GUI test (§2.14): one target predicate
for crosshair and click with the "Evading" feedback (§2.14.1); free mobs run
home only from outside their wander radius, with `combat_stats.md` and the
evade fixtures updated (§2.14.2); the talent-point line in the level-up
banner (§2.14.4). The main-menu background (§2.14.3) is lane A's. Further
findings from the ongoing test join at the start; the coordinator assigns
each to F or the lane it belongs to. Fixture cases for each item; one engine
run with a reset free mob inside and outside its wander radius.

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
`LICENSE-media.md` row. Also the main-menu background (§2.14.3): two or
three candidates on a preview page, the user picks one; it does not wait
for the story bible.

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
- **Decided at the start:** further Round 35 GUI findings beyond §2.14;
  the Round 35 carry-overs that join a lane (BACKLOG "Round 35
  carry-overs"; e.g. spell formulas rounding before the level scalar could
  join K). Lane K builds on main after Round 35, which already holds lane
  B's final talent values (merged a15bd0ae).
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

## Completion (2026-10-05)

Every lane below is merged on main (last the text pass T, `5069b5a5`,
and its fixture `d133c3fc`); the user pushed the round on 2026-10-05
(`1e8a975d`) and the [follow-up lanes](#follow-up-lanes-2026-10-05-evening)
the same evening (`0f169898`). Each code and data lane was
independently reviewed by Opus once: F, K, E and R said MERGE with notes
(each note fixed before the merge except the carry-overs below), G, W, Q-T
and Q-A MERGE AFTER FIXES (all fixed and merged), Q0 MERGE (one finding
fixed); lane A's art and lane T's texts were checked by the coordinator
(T's JSON diff without `title` and `text`: no other change) and T's texts
reviewed by Opus with improvement suggestions the user picked. After each
merge the coordinator ran the portable fixtures, `check_fresh_server.py`
and `validate.py --game`; `tools/run_fixtures.sh` passes **93 of 93** on
main (re-run on this lane's branch), `validate.py --game` reports 0 errors
and 7 warnings (the finale's rift boss is no zone's recipe target: four;
two chain gates one level apart; no atlas given), `income.py --check`
passes after the re-derived prices. One boot of main after wave 1 (seed
5423894902269011374) passed. Lanes G and W changed world generation: each
ran `tools/seed_fleet/run.sh quick` (100 of 100 seeds); **a fresh world is
required** for the decor pass and the dragon arenas. A second text review
(Opus suggestions on the other quest texts) landed after this section as
the data-only commit `6794af6e` (136 suggestions, all accepted by the
user), with the catalogue regenerated in `1e8a975d`.

### Shipped, by lane

Numbers are each lane's own probe, fixture or model, same seed and method
before and after (comparisons, never targets).

- **F fixes from the Round 35 GUI test** (merge `2b51e74d`;
  [combat_stats.md](../design/combat_stats.md) §4,
  [classes.md](../design/classes.md) §2b,
  [inventory_equipment.md](../design/inventory_equipment.md)): **one target
  predicate** — `grug_abilities.valid_target` refuses a mob evading home,
  and the LMB hold's `fightable` is that predicate, so the crosshair turns
  red exactly where a press would act; a fresh press at an evader shows
  "Evading" in the flash line at most once per 1.5 s per player (a held
  press stays quiet, a self or support skill still fires); a ray at a
  mount means its rider; no skill colour while the player cannot act.
  **Free mobs** (damage pursuit) reset inside their 32-node wander radius
  only heal and drop the target; reset outside it they run home
  untouchable and are a normal mob again once back inside the radius, not
  at 4 m. Camp members, guards, rares, bosses, patrollers, royals and
  dragons keep their thresholds; the 15 s damage clock still starts at the
  first aggro. Engine probe (`tools/r36_f/engine.sh`, a wolf on a moving
  stand-in): reset 12.9 nodes from home, no evade; reset 50.7 nodes out,
  evade ended at 28.1 nodes and did not start again. **Level-up banner:** a
  level that earns talent points adds "You gained +1 Talent Point" (or
  "+N Talent Points" over a jump), from one rule
  `grug_classes.talent_points_at`. Also the Round 35 carry-over: the timing
  line of Grudge, Onset, Quick Step, Swift Word, Second Skin and Slip Away
  shows the effective cooldown.
- **K class fine-tuning** (phase 1 `f77d41e9`, merge `778533a7`;
  [combat_stats.md](../design/combat_stats.md) §2,
  [item_tiers.md](../design/item_tiers.md) regenerated,
  [classes.md](../design/classes.md), [skill_trees.md](../design/skill_trees.md)):
  the decided table (`tools/r36_k/numbers.py`), all as recommended:

  | Change | Before | After |
  |---|---|---|
  | Support factor (Heal, Hearten, Mend, Shield, Recompense, Glacial Ward) | `1 + Int / 1000` | `1 + gear Int / 10 / B(L)` (`grug_classes.get_support_factor`) |
  | Priest Heal per cast, level 60, no Intelligence gear | 760 | 674 (−11.3 %; −6.4 % at 30, −8.9 % at 45) |
  | Priest Heal, Intelligence set, item level 60 / 70 | 862 / 889 | 908 / 970 |
  | What the Intelligence set adds to Heal, 60 / 60 and 60 / 70 | +13.5 % / +17.0 % | +34.8 % / +43.9 % (the Mage's Fireball column) |
  | Dexterity enchant curve `0.8 + 0.13 L + c L²` | c 0.0019 (T6 top 15) | c 0.0011 (T6 top 13) |
  | Scout full damage set, item level 30 / 45 / 60 / 65 / 70 | +35.2 / +44.8 / +55.0 / +68.3 / +81.7 % | +35.2 / +41.2 / +49.0 / +59.3 / +69.4 % (Warrior +33.5 / +40.2 / +47.0 / +57.4 / +69.4 %) |
  | Spell rounding | to an integer before the level scalar | floored once after it (up to ±4 at 60, Smite with Sharpened Word ±7) |
  | "(30 % cap holds)" | Keen Edge only | also Cold Eye, Firebrand, Hard Faith |

  Two help lines in `grug_inventory/help.lua` follow. Fixture
  `tools/r36_k`; the Round 33 models in `tools/r33_ds` follow.
- **P POI review page** (merge `e846db72`, tools only): `tools/r36_p`
  renders all **106 POIs** as the runtime builds them (villages 6, outposts
  18, bandit camps 6, mines 6, Mirefolk camps 4, clash sites 16, apex camps
  2, rare pads 10, the Round 14/15 compositions 18, fortresses 2,
  Battlegrounds camps 16, dragon arenas 2): an isometric in-game view, a
  top-down plan and the two most different other palettes, on a private
  German page with a verdict per POI and the rift pick. The user answered
  in chat (the decor pass below).
- **E quest engine** (merge `94ccdb6d`; [quests.md](../design/quests.md),
  [spawn_regions.md](../design/spawn_regions.md)): the objective **"use at a
  place"** (`place`, `object`, `label`, `hold` 1–15 s): a quest object, an
  entity at a clash site or at a recipe's quest place (placed per seed like
  a kind leader, at least 64 nodes from every leader, camp and other place;
  region-map cache format v2), added while a player who still needs it is
  within 48 nodes and seen only by such players; a right-click within 5
  nodes starts the hold, the feed counts the seconds, letting go, stepping
  away or any damage stops it; every aiming ray of a player who does not see
  the object passes through it (`grug_core.unseen_by`). One working place
  in each contested zone without a clash site. **Turn-in hook**
  `grug_quests.register_on_turn_in(fn(player, id, def))`, quest `tags`, and
  the achievement counters `quest:<id>` and `quest_tag:<tag>`; the
  validator's `W-chain-gate`. `quest_targets.py`: 1124 targets ok on the
  six seeds; engine probe with a quest object PASS.
- **R the rift and the war commanders** (merge `c564dd95`, boss health
  `e0ec800b`; [world.md](../design/world.md) §4b,
  [items_crafting.md](../design/items_crafting.md) §5.3b,
  [pvp.md](../design/pvp.md) §6.2): **the rift** at Tombroad Ambush
  (`r20_anchor_077`, the only candidate in the 58–60 belt on all six
  seeds; the user's pick): a jagged crack of 70 void nodes two deep,
  written once per world into the site's protected floor and recorded;
  the void is not walkable, a player sinks in, loses **11 % of his
  maximum HP per second** (about 9 s from full, the new node group
  `grug_pool_damage`) and swims out; dark motes for each player within 48
  nodes (about 80 per 5 s, about 50 alive). **Isquarre the
  Tithe-Eater**, a level-60 elite on the Dungeon Master's mesh (voice
  `giant`) at **2 × an elite's HP** (16,176; the user: no harder than a
  dragon): void bolts, the elite frontal wind-up and a void pulse every
  14 s (×2 hit within 6 nodes); a 24-node leash and its own evade home
  round the crack; back **5 minutes** after its death; the boss ledger's
  **24-hour lockout** (two blue or gold items at item level 65, an elite's
  roll inside the lockout); achievement counter `boss:rift`. Since Q-T it
  appears only when a player within 48 nodes has a faction's finale in
  the log or turned in (`rift_core.FINALE_QUESTS`, `grug_quests.quest_held`).
  `tools/r36_r/numbers.py` (level-60 players):

  | Encounter | HP | 1 player | 2 players | 3 players |
  |---|---:|---|---|---|
  | Isquarre, 2 × elite HP (shipped) | 16,176 | 60 s / 5.5 pools | 30 s / 2.6 | 20 s / 1.9 |
  | Isquarre, 3 × (the first proposal) | 24,264 | 90 s / 8.4 | 45 s / 4.0 | 30 s / 2.6 |
  | Dragon (level 70) | 18,000 | 107 s / 7.4 | 53 s / 3.7 | 36 s / 2.5 |
  | Front elite (Glass-Throat, 59) | 11,756 | 44 s / 4.2 | 22 s / 2.1 | 15 s / 1.4 |
  | War commander (60) | 12,132 | 45 s / 4.5 | 22 s / 2.3 | 15 s / 1.5 |

  Time to kill / damage to the tank in level-60 pools. **War commanders:**
  War Commander Greyvow in the Accord War Camp of The Skyglass Canopy, War
  Commander Stonegrudge in the Throng War Camp of Gravesalt Escarpment,
  level-60 elites with the leaders' factors, five nodes beside the captain,
  respawning after 270–330 s, counted as captains on the PvP tab, each in
  his faction's tabard over the camp race's guard look. Engine probe at the
  site (crack, boss, void damage, reset, return) PASS.
- **G dragon arenas** (added lane, merge `89e8462d`;
  [world.md](../design/world.md) §4b): Stormscale's six ember fissures
  three or four wide (ember cells 121 → 279; never a 5 × 5 block, so the
  wyvern cannot stand in one; at most two steps from floor), Wyrmglass's
  seven thin-ice fields one node wider (437 → 673 cells), ice water
  refreezes **2 minutes** after it broke (was 20 s; rechecked every 5 s
  while someone stands in it). **The wing gust:** every 12 s on the ground
  with a hostile player within 8 nodes, a 1.25 s wind-up (growl, beating
  wings, a wind ring, "… spreads its wings: get clear!"), then a push of
  about 6 nodes (16 nodes per second and 5 up), no damage or slow, never
  past the arena radius − 4 (it reads the player's live braking); no chain
  with the dive. `seed_fleet quick` 100 of 100; fixture and engine probe
  `tools/r36_g`.
- **A art** (GPT-6 Astra, merge `2afdb73b`): **21 textures**, CC0, made
  reproducibly by `tools/r36_a/paint_art.py`: the three cloaks (Mantle of
  the Unburnt Roll, The Unbought Banner, Mantle of the Broken Due),
  Isquarre's skin on the Dungeon Master's UV layout, two commander tabard
  overlays, the void node, the rift particle and the void bolt, and twelve
  quest-object sprites. The main-menu background (lane AM) did not ship
  (deviations below).
- **Q0 shared data** (added lane, merge `20302c38`;
  [biomes_mobs.md](../design/biomes_mobs.md),
  [quests.md](../design/quests.md),
  [character_visuals.md](../design/character_visuals.md) §5b): the bible's
  **ten corrupted sub-types** (Coal-Purse Factor, Brandbound Collector,
  Tallow-Sealed Husk in The Broken Causeway and The Shattered Line;
  Ash-Writ Bowman, Kiln-Whisper Hexer, Debtjaw Hound, Embergrit Gnawer in
  Gravesalt Escarpment; Dunshade Prowler, Furnace-Coil Serpent, Sootlace
  Spinner in The Skyglass Canopy; the bowman also at Chirr's camp) as the
  minor role of front kinds and camps, all with **one ember tint**
  `#B4472A` at three strengths (the tint now returns after a relevel); the
  **twelve object kinds** of the bible; the four quest places renamed for
  their uses (Brandscar Cairn, Courier's Stump, Ashen Grave, Coinpit
  Hollow); **three achievements** with their cloaks — Every Name Accounted
  For (`quest:accord_main_final`, The Accord's), Our Oaths Are Ours
  (`quest:throng_main_final`, The Throng's), The Last Claim Denied
  (`boss:rift`, shared) — and the **faction rule** (the user): a faction
  row is hidden from, and never earned by, the other faction; the two
  captains' orders as quest items. Ledger unchanged, `quest_targets.py`
  1124 ok, region renders of the eight changed zones, engine probe.
- **Q-A and Q-T the main line** (merges `966c557a`, `bfceba75`;
  [quests.md](../design/quests.md) "The main line",
  [story.md](../design/story.md) §2a): the spine at each fortress
  Warmaster's second line, the front climaxes folded in as required steps
  (new `requires`, tags and corrupted kill roles; Senn's Archshadow chain
  opens two levels earlier), the finale on Isquarre at 60, the last line at
  the Warmaster. **540 quests** (+25: The Accord 13, The Throng 12; 14
  front quests changed beyond their text). The Accord, "Every Name
  Accounted For" (tag `accord_main`):

  | Ch. | Quest (min level) | Giver → turn-in | Step |
  |---|---|---|---|
  | 1 | Bring Me the Account (41) | Warmaster → Toren Waterbarrel | unseal the impounded pay at Ashen Wheelbreak |
  | 1 | Warm Coin, Cold Supper (41) | Toren Waterbarrel | five Coal-Purse Factors |
  | 1 | A Stamp for Archsight (44) | Toren Waterbarrel → Alna Archsight | travel |
  | 1 | The Burn Beneath the Stamp (45) | Alna Archsight | siege bones; a rubbing of the brand at Brandscar Cairn |
  | 1 | Collection Ends Here (46) | Alna Archsight | Toll-Taker Senn; the toll-box at Causeway Toll Ruin |
  | 1 | Good Paper, Bad Company (46) | Alna Archsight → Warmaster | travel |
  | 2 | The Price of a Salute (46) | Warmaster → Nella Hedgeward | three Brandbound Collectors; the pledged standard at Siege Ramp Foot |
  | 2 | Nobody Left to Rally (47) | Nella Hedgeward | Standard-Bearer Ninepins |
  | 2 | Read Before Accusing (47) | Warmaster | the Throng Captain's Orders, solo, Throng high war camp on The Shattered Line |
  | 2 | A Quiet Audit (47) | Warmaster | Odren Vell's courier ledger at Courier's Stump |
  | 3 | Following Vell's Pay (53) | Warmaster → Borin Splitbolt | four Debtjaw Hounds |
  | 3 | The Last Watch Ends (57) | Borin Splitbolt | Watch-Captain Huskell |
  | 3 | The Clerk at the Foot (57) | Borin Splitbolt → Eriath Boughwarden | travel |
  | 3 | The Price of Another War (58) | Eriath Boughwarden | Paymaster Chirr |
  | 3 | Names Beyond His Reach (58) | Eriath Boughwarden → Warmaster | the rootmark at Skyroot Crossing; the tally-stone at Tombroad Ambush |
  | F | Group: The Collector Comes Due (60) | Warmaster | Isquarre the Tithe-Eater |
  | F | Every Name Accounted For (60) | Warmaster | the report and the last line |

  Optional: Group: Stonegrudge's Inquiry (57), Group: Nothing Left to Count
  (Salt-Counter, 58), the island uses Optional: No Claim on the Crown
  (Crystal Landing Scar) and Optional: A Chest Overboard (Thunder Shore
  Wreck) at 60 from the Dur Brannoc and Highcourt envoys. The Throng, "Our
  Oaths Are Ours" (tag `throng_main`):

  | Ch. | Quest (min level) | Giver → turn-in | Step |
  |---|---|---|---|
  | 1 | Too Warm for Wages (41) | Warmaster → Drek Rampbinder | break the false requisition seal at Bannerfall Pocket; three Coal-Purse Factors |
  | 1 | Payment in Full (46) | Drek Rampbinder | Toll-Taker Senn; the toll-box at Causeway Toll Ruin |
  | 1 | A Coin for Orrel (46) | Drek Rampbinder → Orrel Hollowstep | travel |
  | 1 | The Fire Is New (46) | Orrel Hollowstep → Warmaster | wash the ash slab at Ashen Grave |
  | 2 | An Oath in Hock (46) | Warmaster → Yarra Standardmender | three Brandbound Collectors; the pledged standard at West Trench Mouth |
  | 2 | Let That Banner Fall (46) | Yarra Standardmender → Warmaster | Standard-Bearer Ninepins |
  | 2 | Find the Hand That Signed (47) | Warmaster | the Accord captain and his orders, solo, Accord high war camp on The Shattered Line |
  | 2 | Our Tallykeeper's Treason (48) | Warmaster | bury the branded pay at Coinpit Hollow (Mardra named) |
  | 3 | Still Buying Our Dead (53) | Warmaster → Vaska Ashlistener | three Kiln-Whisper Hexers |
  | 3 | Dismissed, Captain (57) | Vaska Ashlistener | Watch-Captain Huskell |
  | 3 | Promises with Bowstrings (57) | Nalo Pathdrum | Paymaster Chirr; the rootmark at Skyroot Crossing |
  | 3 | No Names Left to Own (57) | Vaska Ashlistener → Warmaster | burn the names off the tally-stone at Tombroad Ambush |
  | F | Group: No Claim on Our Dead (60) | Warmaster → Vaska Ashlistener | Isquarre the Tithe-Eater |
  | F | The Answering Blow (60) | Vaska Ashlistener → Warmaster | the report and the last line |

  Optional: Group: Greyvow's Last Filing (57), Optional: No New Volume and
  Optional: Sink the Wages on the islands at 60 (Nhal Veyr and Gor
  Drazhak envoys). The old optional elites (Last-Toll, Engine Nine,
  Glass-Throat, Salt-Counter) stay optional; the fortress raids on the two
  commander camps warn of him ("Under Stonegrudge's Eye", "Greyvow Has
  Company"). Ledger (`ledger.py --track <race> --repeat 2`, today's tool on
  the data before and after; reported, not gated):

  | Race | 40 → 50 solo | 50 → 60 solo | 40 → 50 duo | 50 → 60 duo |
  |---|---|---|---|---|
  | Human | 104 → 112 % | 119 → 125 % | 79 → 86 % | 106 → 120 % |
  | Dwarf, Elf | 98 → 106 % | 115 → 120 % | 76 → 83 % | 102 → 114 % |
  | Orc | 98 → 107 % | 101 → 105 % | 75 → 83 % | 86 → 95 % |
  | Troll, Undead | 98 → 106 % | 101 → 106 % | 73 → 81 % | 86 → 95 % |

  `quest_targets.py` on the six seeds after both lanes: 1207 targets ok.
  Fixtures `tools/r36_qa`, `tools/r36_qt` (chain, gates, tags, the final
  turn-in and its last line, the solo rule, the places). The quest copper
  moved the income model: **re-derived prices** (`income.py`,
  `8f4d5638`): Expert Riding 1g32s → 1g29s, Master Riding 7g37s → 7g38s,
  the 41–50 respec 5s50c → 5s25c, the crown fee 1g47s → 1g48s.
- **W decor pass** (widened lane, merge `1c43968a`;
  [settlements.md](../design/settlements.md) "Decor pass"): one kit,
  `grug_mapgen/wp13/decor_kit.lua`, with pieces in each race's palette
  and the house touches; a theme per kind instead of the old block
  formations on **68 Round 20 POIs** (villages 6: a hamlet; outposts 18: a
  watch post; bandit camps 6: a hideout; mines 6: a working dig; Mirefolk
  camps 4: a fen camp; clash sites 16: the remains of a battle; rare pads
  10: the beast's lair; apex camps 2: the prospectors' camp) and the **18
  Round 14/15 compositions**; the house touches (a torch beside a door
  without light, a barrel or pot by the door, flowers under a window, a
  wood pile or barrel on a side wall) on every closed building of those,
  of the **6 start towns** and of **155 capital plots**; war camps,
  pickets, fortresses and dragon arenas untouched. Rules: no solid node
  before or behind a window (144 such cells in 51 compositions moved), two
  nodes of headroom in every closed room (Redtusk Village's annex 2 → 3
  courses), every way stays walkable within a detour of a few steps
  (barrels that cut porches in Lethariel and long detours in Highcourt, Dur
  Brannoc and Nhal Veyr fixed), the rift site's crack untouched. **Benches**
  look across their bench: Stillgrave's court settles, the temple pews of
  every capital, the court bench of Dur Brannoc, Gor Drazhak and Nhal Veyr,
  Dawnmere's end benches. Footprints, positions, protection boxes and
  sockets of all 402 compositions held to main's record
  (`tools/r36_w/baseline.tsv`); `seed_fleet quick` 100 of 100, mapgen time
  about +2 %. Before/after pages from `tools/r36_w/render.py`, `page.py`.
- **T quest texts** (GPT-6 Astra, merge `5069b5a5`): titles and texts of
  45 quests (The Accord 25, The Throng 20: both main lines and the folded
  front quests) in the bible's voices; then an Opus review with **28
  suggestions** (9 wit, 8 clarity, 5 voice, 3 story, 3 title), all accepted
  by the user and applied by script. `validate.py --game`: 0 errors.
- **D:** this section, the status files, story.md, the corrections of
  §2.13 and §7, AGENTS.md and the module guide, the regenerated
  existing-items catalogue.

### Follow-up lanes (2026-10-05 evening)

From the user's first look at the round, merged after this section was
written (`git log 1e8a975d..0f169898`). F2, W3 and RD were independently
reviewed by Opus (MERGE; the notes applied before the merge); no separate
review is recorded for W2, which only turns blocks. After them `tools/run_fixtures.sh`
passes **96 of 96**, `check_fresh_server.py` passes and a smoke boot of
main passed. W2, W3 and RD change world generation: **the GUI test needs a
world made on `fef94a6a` or later** (W3 and RD each ran `seed_fleet quick`,
100 of 100; W2 turns blocks only). The round-end `seed_fleet full` owed
after W3 and RD ran at the start of Round 37 on `0f169898`: 303 of 303
seeds build ([Round 37 plan](round37-plan.md) §7).

- **F2 held button across a hotbar switch** (merge `4b224ccd`;
  [classes.md](../design/classes.md) §2b): an LMB held across a switch to
  another skill is the same press, decided again for the new item once it
  has stayed wielded **0.2 s** (a further switch restarts the wait, a
  release inside it acts for nothing), so a slot the scroll wheel only
  passes never fires; a kept combat foe stays while it is in the new
  skill's reach; digging goes on across a switch in both directions and
  never waits. Fixture and engine probe `tools/r36_f2` (digs across a
  switch: 3 of 6 accepted before, 6 of 6 after, 7 of 7 across a fast
  scroll).
- **W2 benches** (merge `4b53dec8`;
  [settlements.md](../design/settlements.md) "Benches"): a bench keeps its
  back to the house or wall beside it and looks out to the lane, a well, a
  fire or a table; a sitter faces where the bench looks. Turned: the bench
  before every capital plot's door, eight Round 20 outposts' benches, both
  fortress barracks benches, court benches in Hearthpine, Silverleaf, Dur
  Brannoc, Nhal Veyr and Gor Drazhak, Gor Drazhak's clan-house sitter and
  Lethariel's two crossing sitters (on main 165 benches and the clan-house
  sitter failed the rule). Fixture over every composition `tools/r36_w2`.
- **W3 ground cover in the treeless band** (merge `9883782a`;
  [world_zones.md](../design/world_zones.md) §12,
  [settlements.md](../design/settlements.md)): the protected band round
  start towns and capitals keeps no trees, bushes or resource plants but
  grows the zone's one-node ground cover on a seeded share of its columns,
  a third at the town rising to all at the band's outer edge; never on the
  pad, a road or its corridor (Dawnmere 0 → 16.9 and Sunscar 0 → 18.2
  covered columns per 100 in the engine probe). Fixture and probe
  `tools/r36_w3`.
- **RD roads** (merge `fef94a6a`;
  [world_zones.md](../design/world_zones.md) "Grade"): a level change in a
  road profile costs `C_STEP` **0.5** instead of 0.05, so roads no longer
  trace the ground's one-node dither with lone half-step bumps and holes
  (about 500 per world before, 0 on the measured seeds).

### The user's choices during the round

1. **Rift site:** Tombroad Ambush (`r20_anchor_077`), lane R's constant.
2. **Story bible v2** approved after an independent Opus review the user
   worked through: the Undertithe, the Tithe-Brand, Isquarre the
   Tithe-Eater, Greyvow and Stonegrudge, the traitors Odren Vell and
   Mardra (text only), twelve objects.
3. **Chapter 2, variant A:** the solo captain in the enemy's high war camp
   on The Shattered Line (47–49), not in the 58–60 camps of §2.3; the
   commanders stay there as optional "Group:" hunts.
4. **Last lines** one per faction (the bible's §5).
5. **Boss health 2 ×** an elite's (lane R proposed 3 ×): no harder than a
   dragon.
6. **Achievement faction rule:** a faction's achievement is hidden from
   the other faction and never earned by it.
7. **Decor pass** instead of a rework of single POIs (POI verdict in chat:
   buildings good, non-building decor bad, clash sites and rare pads
   themeless, apex camps empty, war camps good), widened to the start towns
   and capital houses, the stair benches turned 90° as a bug; approved
   after the sample page with decisions 1–4 (the themes per kind; a torch
   at every door without light plus one to three lanterns; banners as a
   whole wool block; the same touches in start towns, capitals and the
   Round 14/15 places).
8. **Windows and Redtusk:** no full block in front of a window (flowers
   are fine); Redtusk Village's low annex gets a third course.
9. **Dragon feedback:** wider ember fissures, slightly larger ice fields,
   a noticeable push-away attack for both dragons, ice water back after
   2 minutes (lane G).
10. **Lane K all as recommended** (decisions 1–4 of the phase-1 page).
11. **Main-menu background:** none of lane AM's three candidates; the user
    takes an in-game screenshot later, which the coordinator installs.
12. **Text review:** all 28 Opus suggestions on the main-line texts.

### Deviations from the plan

- **Lane AM** (wave 1, GPT-6 Astra): the main-menu background of §2.14.3
  as its own lane instead of lane A's: three candidates (a voxel scene from
  the game's textures, a pixel panorama, an engraving) and three prompts
  for a local image generator on a preview page; the user picked none
  (choice 11). Nothing shipped; `menu/` is unchanged.
- **Lane G added** for the user's dragon feedback (choice 9), a mapgen
  lane beside W.
- **Lane W widened** from reworking the POIs marked on lane P's page to a
  decor pass over every Round 20 POI (but war camps, pickets, fortresses
  and dragon arenas), the Round 14/15 places, the start towns and the
  capital houses, in two phases (kit and samples, then everything).
- **Lane Q0 added:** the data both quest lanes share (sub-types and
  recipes, object kinds, achievements, the orders, art wiring) as one lane
  before Q-A and Q-T ran in parallel.
- **The story bible was revised** (v2) after an independent review: v1's
  names clashed with existing places and chains, and its chapter 2 put a
  level-60 captain into the 46–52 chapter (choice 3).
- **Prices re-derived** after the main line's quest copper (Q lanes'
  ledger); the first commit went in with a stale fixture and table, fixed
  in the next one.
- Lane S got a worktree of its own (the Astra runner needs one); the
  Round 35 carry-overs joined lanes K (spell rounding, the cap texts) and
  F (the effective cooldown).

### Open notes

In the [BACKLOG](../../BACKLOG.md#round-36-carry-overs); none blocks the
GUI test. Numbers are comparisons, never targets.

- The tally-stone at Tombroad Ambush sits on Isquarre's spot; a chapter-3
  player there can be hit only while a finale group has him up.
- The ledger counts the Throng captain's kill twice; it still counts island
  bounties' kill XP in 50 → 60.
- Missing decor nodes (thin banner cloth, weapons for racks, a tent, rails
  and ore cart, an ember node, a grave cross, a window flower box); the
  captains' orders use a placeholder icon; the main-menu background waits
  for the user's screenshot.
- The float floor (±1) in `scale_player_damage`; hidden achievement rows
  still count; Isquarre's spawn is subject to the mob cap.

### GUI playtest checklist

Desktop client and the web build, **a fresh world** made on `fef94a6a` or
later (the decor pass, the dragon arenas and the follow-up lanes' benches,
ground cover and roads are world generation); **two clients** for the rift
and PvP.
Helpers: `/xp give`, `/teleport`, `/giveme`, `/time`, `/money`
(privileges `server`, `give`, `settime`). Places: Ashenward Bastion
(136, −488), Bannerbreak Warhold (−80, 632), the Shattered Line high war
camps (Throng 648, 48; Accord 944, −16), the Gravesalt Throng camp
(−1464, 24), the Skyglass Accord camp (2080, −56), Tombroad Ambush
(−1768, 64). Say what looks or reads wrong.

The main line (Q-A, Q-T, E, Q0):

1. **The gate:** at level 40 the Warmaster shows chapter 1 as locked, at
   41 it can be accepted; the fortress quests and the other front quests
   are unchanged. Chapter 2 opens at 46 only after chapter 1, chapter 3 at
   53, the finale at 60.
2. **Read each line through** (one character per faction, `/xp give`
   between chapters): one thread, no unfilled `{…}`, no fixed compass
   word, the burnt brand and the suspicion of the other faction early,
   each step sent where the last was turned in.
3. **Behind the lines (solo):** in the enemy's high war camp on The
   Shattered Line kill the captain; his orders drop (only with the quest);
   the traitor is named after it (Odren Vell / Mardra) and again on
   Huskell's roll in chapter 3.
4. **Quest objects:** at a clash site (Ashen Wheelbreak or Bannerfall
   Pocket) the object shows only with the quest (a second player without
   it sees nothing and can click through it); holding right-click fills
   the seconds in the feed and completes it; letting go, walking away and
   a hit stop it; the HUD, the log and the feed name the act.
5. **The four rule-placed places:** Brandscar Cairn (Stormvault Heights),
   Courier's Stump (Glassroot Wilds), Ashen Grave (Blackwind Rise),
   Coinpit Hollow (Thunderroot Wilds): the object stands on open ground
   and the text's direction points there.
6. **Corrupted sub-types** at the front (Coal-Purse Factor, Debtjaw Hound,
   Sootlace Spinner …): their names and the ember tint, also after they
   change level.
7. **The commanders:** Stonegrudge in the Gravesalt Throng camp and
   Greyvow in the Skyglass Accord camp, each beside the captain in his
   faction's tabard; the optional "Group:" quest on him; the old fortress
   raid on that camp still finishes.

The rift (R, two clients):

8. **Isquarre appears only for an eligible player:** a chapter-3 player
   alone at the tally-stone meets no boss; a player with the finale in the
   log calls him up within 48 nodes; once up he stays.
9. **The crack:** visible across the site, particles modest; stepping in
   sinks you, costs about a tenth of your health per second, and you can
   swim up and step out; the crack cannot be dug.
10. **The fight:** a group of two or three kills him (the void pulse is
    telegraphed); dragged away he resets and walks home round the crack;
    he drops two blue or gold items once; a second kill within 24 hours
    gives an elite's loot only; he returns about 5 minutes after his
    death.
11. **Both factions at the rift:** PvP contact as in pvp.md, no shared
    turn-in.
12. **Achievements and cloaks:** each faction's line unlocks its cloak,
    the kill the shared one; the other faction's row is not on your tab.
13. **The last lines** at each Warmaster point below without naming any
    Nether place or item.

Fixes, classes and dragons (F, K, G):

14. **An evading mob:** reset a mob far from home (lead it more than 32
    nodes away): the crosshair stays neutral on it, a click shows
    "Evading" once, a held button stays quiet; it is a normal mob again
    once back within 32 nodes of its spot. A mob reset close to home only
    heals and drops you.
15. **Level-up banner:** "You gained +1 Talent Point" on every even level,
    "+2 Talent Points" over a jump; the timing line of Swift Word, Quick
    Step or Grudge shows the shortened cooldown.
16. **Priest heals:** Heal with and without Intelligence gear (the tooltip
    and the healed amount: lower without, clearly higher with); the
    Scout's damage set feels in line with the Warrior's.
17. **Dragons:** Stormscale's fissures three or four wide, Wyrmglass's
    ice fields larger; the gust's wind-up (wings, ring, feed line), then a
    push of about 6 nodes that never throws you out of the arena; broken
    ice comes back after 2 minutes.

The decor pass (W):

18. **One of each:** a village (Whitebridge Market Close), a mine (Tarncut
    Mine), a clash site, a rare pad (Whitefang's Cold Den), an apex camp
    (Wyrmglass Fault Camp), a start town (Dawnmere) and a capital lane
    (Highcourt): the themes look as on the preview page, a few lights per
    place.
19. **No window blocked** by a barrel, crate or log; benches face across
    their seats (Stillgrave, the capital temples); Redtusk Village's annex
    has headroom; porches and lanes can be walked.

Prices:

20. **The new prices:** Expert Riding 1g29s, Master Riding 7g38s, the
    41–50 talent reset 5s25c, the crown 1g48s.

The follow-up lanes (F2, W2, W3, RD):

21. **A held button across a hotbar switch:** hold LMB on a mob and switch
    to another skill: it acts once it has stayed selected about 0.2 s;
    scrolling quickly past Blink, Heal or Ward fires nothing; digging goes
    on across a switch from the empty hand to a skill and back (the node
    does not come back).
22. **Benches:** the bench before a capital plot's door has its back to the
    house; benches in start towns, outposts and the fortress barracks never
    face a wall; Lethariel's crossing sitters look the way their benches
    look.
23. **Ground cover round towns:** the protected band round a start town
    (Dawnmere, Sunscar) and outside a capital wall has grass and low plants,
    sparse near the town and denser outward, but no trees or bushes; roads
    stay bare.
24. **Roads:** no lone half-node bumps or holes along a road.
