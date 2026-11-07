# Round 71 — Expeditions: the framework and the level 20 Expedition

Planned with the user on 2026-11-07. **Started** on the user's go, 2026-11-07, on
branch `round71`. Routing (user, 2026-11-07): Opus 5.5 coordinates, implements and
reviews in its own context; GPT-6 Astra writes the storyline and quest text and
draws the art proposals. Version **0.71.0**, classification decided at its merge; no map reset is planned.

## Why

Groups have no repeatable group content, and the Miner's Guild has a story to give
it. This round proves the idea with one Expedition before four more are built.

## 1. Lanes and order

| Wave | Lane | Who | Goal | Waits for |
|---|---|---|---|---|
| 0 | SPIKE | Opus | Measure clearing and writing a full box in the engine; fix slot size, grid and step size | go |
| 1a | FRAME | Opus | Slots, preparation queue, template format and box writer, ownership, release, login rule, both waystones; publishes its interface first | SPIKE |
| 1b | GUARD | Opus | No riding, respawn inside, ore digging, proof that spawns stay out | FRAME's interface |
| 1b | MOBS | Opus | Room spawns, per-entity levels, no respawn, item levels above 60, boss credit, chest, reward door | FRAME's interface, Round 70 LEVELS |
| 1b | UI | Opus | Registrar NPC, level dropdown, eligibility dialog, invitation warning, preparing and ready notices, map | FRAME's interface |
| 0 | L20DOC | Astra, Opus review | Storyline, a short description and a 2D floor plan of the level 20 Expedition | go |
| 2 | L20 | Opus | The level 20 Expedition: template, roster, boss, loot table, quest | every wave 1 merge, **the user's approval of L20DOC** |
| 3 | D | Opus | Docs, completion, GUI checklist | every merge |

The other four Expeditions are a later round, on the proven format.

## 2. The user's rulings

The [concept](round71-expeditions-concept.md) holds them, with its proposals marked;
since lane D the [design file](../design/expeditions.md) owns the rules as they stand.
[Round 70 §2.10](round70-plan.md#210-boss-levels-and-item-levels-user-2026-11-07-no-reset-needed)
changes the item level rules this round builds on.

## 3. Shared conventions

- One new mod owns Expeditions (`grug_expeditions`); other mods get hooks, not
  Expedition logic.
- The word is "Expedition" everywhere: players, docs, briefs and code (user, 2026-11-07).
- The 100 slot positions, box size and step size live in one catalogue the lanes read.
- A template is a repository file written by a tool, like the building templates.
  The format stays 3D, so later Expeditions can use several y levels and height.

## 4. Lane goals

### SPIKE — measure first

In the engine, with a player online: emerge, clear and write a box of the largest
expected size in slots beyond the map, at about x 8000 and more. Report the time per
step, the effect on the running game and a sensible step size, and test whether more
than one preparation at once makes sense. Confirm the off-map behaviour the concept
reads from the code. Report numbers and a recommendation; the user decides on slot
position if it differs.

### FRAME — slots and binding

The pool, the low-priority preparation, the template format, its tool and the box
writer, ownership (player or party) with every change of owner, the entry gate, all
release rules of the concept including login and server restart, and both waystones.
Anyone who does not belong is teleported out at once. The interface for the other
lanes comes first.

### GUARD — the rules inside

No riding, respawn at the start waystone, the exception from the open sea's
immutability for what is meant to be dug. Building and flying are already refused
off the map; prove this and that natural spawns stay out of the box, and build only
what the proof shows is missing.

### MOBS — encounters

Spawn by encounter room through `_grug_spawn_level`, no respawn. Lift the item level
cap in `roll_mob_gear` for Expedition mobs only. Boss credit through `bosses.lua`,
without its 24-hour lockout and direct rewards. The per-player chest and the reward
door belong here.

### UI — the registrar

The NPC on the clerk's socket in the six guild houses, the dropdown with only the
levels the creator may enter, the eligibility dialog with its warning, the warning in
the invitation box, "Your expedition is being prepared...", the ready notice, the
minimap's ocean and party arrows off the map.

### L20DOC — for the user to read

A short description with a 2D floor plan of the level 20 Expedition: story, place in the guild's story, route,
encounters, boss, ore and rewards. One main floor; several y levels stay out for now.
Astra drafts the storyline and quest text, an Opus review round follows
the quest text rules. The user approves it before L20 starts.

### L20 — the first Expedition

Build what the approved L20DOC describes: T2 ore only, rare on the way and only after the first
mob pack, a richer reward room, its loot table, its optional quest. Balance for 3
players at every level from +0 to +9, and check XP against the level pace.

### D — docs

A design owner for Expeditions, `world.md` R4's exception, the completion section, GUI
checklist, STATUS, BACKLOG and CHANGELOG.

## 5. Rules

- Round workflow and `AGENTS.md` apply; every non-trivial lane gets an independent
  review.
- The running game comes first: preparation never competes with players.
- No lane pushes. Only the user pushes.
- A case the rulings do not decide stops that path and goes to the coordinator.
- Every launch prompt carries the fixture sentence of the lane start checklist.

## 6. Verification

Round workflow §3. `tools/r29_e4/income.py --check` for L20. Before and after
numbers for preparation with players online. Round end: one smoke boot of the
branch, then the user's test.

### GUI checklist (desktop and web)

Written by lane D from the plan's list, the lanes' excerpts and the reviewers' notes.
Each item on the desktop client and on the web client. Items marked *look* ask for the
user's verdict on a first-look default.

**Only the user can prove these.** No lane ran the web client, a second real player, a
real fight or PostgreSQL. So:

- **Web:** the whole list. The lanes' clients were desktop builds on Xvfb.
- **[2+]** needs two or more real players. Party, leader and member views ran on stand-ins
  and in fixtures; the rules are proven on the real `runs.lua`, a real second player never.
- **[fight]** needs a real fight. The probes teleport, kill packs by script and land
  Flintback's hits through the ability path; the fight lengths are a model.
- **[shove]** and **[Rehearsal]**: items 34 and 46.

**The registrar (start in a capital's guild house)**

1. On an existing world the clerk's place in **each of the six** guild houses holds the
   Expedition Registrar. The other faction gets the refusal.
2. The window opens; the dropdown changes the rows and shows only levels you may enter,
   for a leader too. Web: the dropdown's popup.
3. **[2+]** A leader sees one row per member, and the warning stops nobody. A member sees
   the refusal instead of the button.
4. The leader activates an Expedition, sees "Your Expedition is being prepared...", waits,
   gets the ready notice; nobody enters before that.
5. *Look* **[2+]**: is a 2.5 s feed line enough for a busy member, on the ready notice?
6. **[2+]** A member below the entry level is refused with the reason: level 20 at +1
   admits a level 19 player, at +2 it does not.

**Arrival and maps**

7. One second of black, then the room, fully lit, with no frame of sky. Web: the
   full-screen curtain.
8. **[2+]** Members enter up to the limit of 3; the next one is refused. It takes four
   players; the fixture covers it otherwise.
9. The minimap shows ocean, and **[2+]** the party's arrows, rim arrows included. Web: the
   tile-less minimap texture.
10. The map window's arrow stands at the map's east edge; the location line reads the
    Expedition's name.

**Owner changes**

11. A solo player creates one. While owning alone, the invitation box and the Social tab
    say that accepting ends it.
12. **[2+]** Inviting someone makes it the party's: they can enter.
13. **[2+]** Solo inside, accept a foreign party's invitation: out at once, both lines
    show, no way back, and **your name tag stays visible to the second player**.
14. **[2+]** A party falling to one member leaves that member as owner.
15. **[2+]** Leaving the party teleports out, also in combat, and frees the place. A
    kicked member gets the line; the others hear nothing. A stranger cannot stay.

**Release, logout, restart**

16. Leave a ready run alone for 10 minutes: the line shows in full width and the slot is
    free. A late login stands in the capital.
17. *Look:* logging in inside an ended run, is the feed line seen while the client still
    loads?
18. Logout out of combat: you stand where you stood.
19. Logout in combat with a pack: dead at login, durability lost once, at the start
    waystone. With the run gone: in the capital you came from.
20. After a server restart a login inside lands in that capital.

**The way out**

21. Both waystones lead to the capital you came from, with no cooldown. Return Home works
    inside and goes home.
22. A waystone in combat refuses in the feed, not in chat. With a pack pulled, Return Home
    refuses too.
23. Neither way leaves the party, and you can go back in through a registrar.

**The rules inside**

24. Every mount and boat button refuses, with the line in the feed.
25. Building and a water bucket are refused.
26. A marked node digs with a fitting pick, not by hand. The walls say "Expedition –
    protected"; the hole takes nothing.
27. Death respawns at the start waystone; durability loss applies.
28. No nametag shows through the walls in a whole run.

**Rooms and packs**

29. *Look:* the rooms read as a mine and are bright enough.
30. Mobs appear before the party reaches a room, at the chosen level. A skipped pack still
    waits later.
31. Packs wake one at a time; the screen hides c from d.
32. **[fight]** One hit on a golem brings its spiders. The pack never gives up, and you stay
    in combat through a pause: the icon stays.
33. **[fight]** Outrun a pack or hide on a pillar: it appears beside you. *Look:* the jump is
    a plain teleport.
34. **[shove]** Stand still in a whole pack: the hits shove you about 39 nodes in 30 s
    (measured, no input, all pushes from one side, [Numbers](#numbers-worth-keeping)).
    *Look:* does it read badly? The way out is to drop pack pushes or vary landing sides.
35. **[fight]** Nobody dies of a fall in a pack fight (0 falls in the engine run).
36. **[fight]** After a wipe a partly killed pack stands whole at its place; a dead pack
    stays dead.
37. **[2+]** A party member who never engaged may walk out; the others may not.

**Flintback and the rewards**

38. **[fight]** **A real fight's length and difficulty, at 20 and at 29,** with a Warrior, a
    Priest and a third player at the run's level. The model says packs 16–27 s, Flintback
    2 minutes, the run 8.7 minutes, against the concept's 10–20.
39. **[fight]** Flintback throws rocks and signals its slam, and stepping aside dodges only
    the slam. A wipe heals it.
40. The boss's death opens the door and drops nothing.
41. The chest is refused before the kill. The warning line reads well, and shift-click takes
    (not driven in the engine). Gear at the run's level, no ore or gem.
42. **[2+]** Each player sees their own chest, also a member who came in after the kill.
43. Eight nodes dig with a T2 pick, at 20 and at +9.
44. All six guild leaders offer "Party: The Stilled Seam" from level 18, in their faction's
    text; it turns in at the giver, and the Expedition repeats.
45. The end waystone returns to the capital. A new run finds the planned layout: mined ore
    back, dead mobs back.

**The running game**

46. **[Rehearsal]** The running game does not stutter during preparation, on **PostgreSQL**:
    the slices' database cost and the disk use were never measured there.

## 7. Orchestration notes

- **Own coordinator context:** this round runs beside
  [Round 70](round70-plan.md) in its own session and private folder `r71`.
- **Branch:** an integration branch `round71` from main at the go; its lanes branch
  from it. Main is merged into it after each Round 70 wave.
- **Release order:** Round 70 ships as 0.70.0, then `round71` merges as 0.71.0.
- **Shared files:** Round 70 owns `game.conf`, STATUS, BACKLOG, CHANGELOG and the
  upgrade declaration until it is released; this round changes them only at its
  merge.
- **Touch points:** `bosses.lua`, `grug_quality/init.lua` and the guild hall socket
  list are Round 70's first; this round merges them in from main.
- **Limits:** the 8 Lua runs are shared. The user's GUI test takes one round at a
  time. `tools/sync_to_luanti.sh` syncs from main unless the user asks, so a test
  before the merge needs the user's request for a branch sync.
- **Lua queue:** the shared `~/projects/grudgelands-orchestration/r45/lua_run.sh`.
- **Decided during the round:** slot position if SPIKE differs, the user's approval
  of L20DOC.

## Completion (2026-11-07)

All planned lanes and four that the round added are merged into the integration branch
`round71` at `670482ca`; this lane D follows on it. **Nothing is on main.** Round 70 owns
main until 0.70.0 ships, then `round71` merges as 0.71.0. Reviews (Opus, independent, one
per lane) are in the table below.

**0.71.0 is compatible:** no step, no map reset. No report argues otherwise, and lane D's
reading agrees: a 0.70.0 world boots and plays on. The six clerks give way to the
registrar on activation (measured on a kept world, seed 42, 15–20 s), nothing touches
world generation, and `check_upgrade.py --base 9b77b9ee` passes (the towns build as at the
merge base; measured by lane D). Saved state: new player meta `grug_expeditions:origin`
(a location id) and `grug_expeditions:logout_death`; int counters `boss:expedition`,
`boss:expedition:<id>`; quest state of `capital_stilled_seam`. None is map-bound, so no
reset clear. Box contents are wiped by each preparation; slots add disk (Numbers).

**Push:** not pushed. **GUI test:** [open](#gui-checklist-desktop-and-web). **Sync:** none
from `round71` unless the user asks. STATUS, BACKLOG, CHANGELOG, README, ROADMAP, the AGENTS
pointer, `game.conf` and the upgrade declaration wait for the merge to main (§7); their
texts are ready in the coordinator's `r71/merge-notes.md`, the README's design tour line
among them.

### Lanes

`round71`'s first-parent merges from the start `106bc87a` (lane tip in brackets), in order:

| Lane | Commit | What | Review |
|---|---|---|---|
| L20DOC | `f5a6883e` (`98694389`) | GPT-6 Astra's description and floor plan of The Stilled Seam; `tools/r71_l20doc` | Opus text and rule review AFTER FIXES, applied; four texts by the user's pick; **approved by the user** |
| FRAME 1 | `75461f2d` (`1b3b8601`) | The interface, catalogue, template format, tool and preparation | with phase 2 |
| SPIKE | `303107d6` (`7ac25570`) | The measuring probe, tools only: box, grid, step size | RELY AFTER CORRECTIONS (delete in slices, assert generation, say what "no stutter" covers), carried into FRAME 2 and GUARD |
| FRAME 2 | `e4c62727` (`16d6023d`) | Ownership, entry, release, the login rule, both waystones; hooks in `grug_home`, `grug_parties`; preparation in slices with the generation gate | MERGE; two cosmetic notes went to FOLLOW |
| GUARD | `1a13952f` (`a17219d7`) | No mounts or boats, respawn at the start waystone, `dig` marks and the world exception, the spawn-free field; proofs that building, liquids, flight, Blink and Charge need nothing | MERGE AFTER FIXES (comment and doc only) |
| UI | `4c687fa7` (`894ead06`) | The registrar on all six clerk sockets, its window, notices, invitation warning, the maps off the map, the black curtain; `start_npc_claim`'s general rule | MERGE, no findings |
| MOBS | `e4fa885a` (`99c7baf4`) | Rooms, levels per entity, item levels to 69, the drop filter, boss credit, reward door, per-player chest, `loot.lua` | MERGE AFTER FIXES (one line, to FOLLOW) |
| FOLLOW (added) | `b3051e49` (`7ef0ab2b`) | Attached objects stay, every notice in the feed, end texts, the header | MERGE (delta) |
| L20 | `d7a607d3` (`f138cbb0`) | Template, Flintback, loot row, catalogue row, the quest, `balance.py` | MERGE AFTER FIXES (Flintback's HP factor 12 to 8, pack damage in the model), then merged |
| PACK (added) | `53d6ace9` (`fd97ec08`) | The user's pack rule: pulled whole, no de-aggro, refill, jumps, the logout rule, the saved capital | MERGE AFTER FIXES (capital past the look on arrival, real reach, a jump needs a floor, keys), then MERGE on the delta |
| Integration fix (added) | `163b0ed2` (`7e43e00e`) | Two bugs in `packs.lua`: a jump landing in the player's cell below y 0, and a pack's downward pushes adding up to a fall | MERGE (delta) |
| OUTLINE (added) | `670482ca` (`899801fb`) | GPT-6 Astra's four proposals for levels 30–60 with sketches: proposals, nothing decided | AFTER FIXES, 17 of 18 applied |
| D | this section | Design owner, `world.md`, completion, GUI checklist, module guide, `tools/README.md`, the merge notes | independent review |

Main was merged in at `bc6b27bd`, `5e45c2f9` and `844f8bee`. `mods/` against the merge base
(measured, `git diff 9b77b9ee 670482ca -- mods`): 39 files, +2747 −36, 34 of them Lua, the two
templates and one quest file among the rest. Six new portable fixtures: `r71_frame`,
`r71_guard`, `r71_ui`, `r71_mobs`, `r71_pack`, `r71_l20`.

### Decisions during the round

**The user** (all in the [concept](round71-expeditions-concept.md), now in the
[design file](../design/expeditions.md)):

- **Ownership:** one player or one party; solo allowed; a party falling to one leaves its last
  member as owner; joining a foreign party ends it.
- **Entry** is a hard gate at the teleport; the dropdown offers only what the creator may enter.
- **100 slots**, refusal when none is free; Round 70's death penalty applies inside.
- **Both waystones** to the capital of entry, no cooldown. They refuse in combat, and a login
  after the end lands in that capital, not at home.
- **No natural mobs anywhere round the slots,** sea rows included.
- **L20DOC** approved "as recommended", with its four texts.
- **Balance at the target level only:** player level = Expedition level. **Every Expedition
  needs a tank and a healer.**
- **The pack rule,** with its three defaults (a dead player leaves the list, no way out in
  combat, stranded mobs jump). **A logout counts as a death only in combat with a pack.**
- **The levels 30–60 designed now** by Astra, as proposals.

**The coordinator's defaults, standing until the user says otherwise:**

- MOBS: what is left in the chest at the end is lost, with a line saying so; one roll, reopen
  until the end; **the boss drops nothing on the ground** (the brief said "other drops stay",
  flagged by lane and reviewer); bars from band tables stay; every Expedition mob authored,
  up to about 16 per run outside the 600 count.
- GUARD: boats refused too; the `dig` line in the template format.
- FRAME and SPIKE: `delete_area` every run, in slices; forced exits ignore combat.
- UI: feed lines for ready and end (checklist 5); a black curtain for the sky frame.
- FOLLOW: two lines for a player inside at an end.
- PACK: sight counts as a pull; a list holds only who engaged; a jump is a plain teleport.
- L20: **coins kept and to be measured**; packs' short run kept; `test_vault` stays hidden.

### Deviations from the plan

- **Four lanes added:** FOLLOW (the reviews' small items), PACK (the user's new ruling), the
  integration fix and OUTLINE (the user's wish). L20 balanced by a model, not a fight.
- **Natural spawns did not stay out** (plan and concept assumed they would): SPIKE saw 24 cave
  mobs round a box in 80 s, so GUARD built the spawn-free field.
- **"No stutter" narrowed:** SPIKE's intervals hide busy time under 90 ms and every run used
  SQLite. The review's correction: delete in slices (upstream workaround 9), generation gate,
  rerun walking over fresh land. PostgreSQL stays unmeasured.
- **Mobs stay saved,** against the plan's check notes: `static_save = false` goes with its
  block, so mobs carry a high lifetimer and preparation wipes them.
- **Old worlds:** a role change alone would never show, so `start_npc_claim` became a general
  rule: an NPC whose saved role differs from its socket's removes itself.
- **One saved value after all:** "nothing about a run is saved" holds, but a login after a
  restart needs the capital, so `grug_expeditions:origin` is saved on entry.
- **Flintback's HP factor 8, not 12,** and the run 8.7 minutes modelled, under the concept's
  10–20; the document's "dodge the rocks" does not exist, as rocks home on the target.
- **Integration failed once** on `844f8bee`: the level 20 run's character died of falls. The
  fixtures and PACK's probe had missed it (a fixture's `round` that was not the engine's, a
  probe at y −0.49). Fixed by the integration commits, proved by two engine runs.
- **`r57_details`, `r67_craft`** failed from FRAME 1 until FRAME 2's harness fix; they are why
  GUARD, UI and MOBS report 310 passed, 2 failed.
- **Lane D here** wrote the status owners as drafts, by the plan's §7, and the design tour line
  goes to the README at the merge.

### Numbers worth keeping

From the lanes' reports, measured there unless marked; comparisons, not targets.

- **Slot:** 128 × 64 × 128, 256 mapblocks, pitch 320, y −112 to −49; 8 chunks.
- **Preparation:** 13.3 s still, 14.8 and 18.0 s walking, 15.9 s under load for The Stilled
  Seam. Job time per step: p99 at most 1.40 ms standing, 2.86 walking, max 13.75 (a delete
  step). Step interval walking at viewing range 190, p99: 97.9 ms baseline, 105.6 with two
  preparations, 99.3 after; load peaked at 28 on 16 cores (other lanes).
- **Queue of 5:** about 62 s (estimated from 10 in 123.6 s).
- **Disk:** 1.16 MB per used slot, about 250 MB for all 100 (estimated; first free wins).
- **Spawns, slot 1, 120 s:** 736 calls refused, 0 allowed, 0 mobs against 29 without the
  field. Field x 7744..11391, z −1936..1711; a Kraken spawned 3 nodes outside, none in it.
- **Pack:** one hit, all three on the player in 0.3 s; far run, beside them in 0.27 s; inactive
  member 1.09 s; walled-off mob 2.8 s; out of combat 2.8 s after the last death. PvE micro
  against the base: noise. **The shove:** about 39 nodes in 30 s on a still player.
- **The Stilled Seam, modelled** (`tools/r71_l20/balance.py`, this code; Warrior, Mage,
  half-healing Priest, 0.78 × 0.85; the same at 20 and 29): packs 16 / 23 / 27 / 27 s, 0.74 / 0.99
  / 1.34 / 1.34 raw party pools; packs with 30 s recovery 3.6 min against a target of 8,
  Flintback 2.0 against 3, walk 1.1, rewards 2.0, **run 8.7 min** against 15.
- **XP:** 28 kill equivalents shared, 9.3 each: 1,166 at +0, 1,586 at +9, about 64 per hour at
  8.7 minutes against the band's 64 (lane D's arithmetic), so at pace, not above it.
- **Chest coins:** 100c at 20, 260c at 21–29 (a bag factor of 10; the jump at 21 is the bag's
  band). A quarter hour of income is 108c and 243c, so at an 8.7-minute run the chest pays about
  690c and 1,790c an hour against 433c and 971c of income (lane D's arithmetic, estimated). It
  replaces other play. **The user's test decides;** the reviewer proposed factor 6–7.
- **Quest:** 500 XP (550 human), 21c, weight 4.
- **A wipe's price:** solo, three spiders of pack c and a death pay 375 XP, 22 % of a level; a
  win 875; 10 % durability each (estimated; an open-world spider pays the same).

### Checks

- **Full run on `844f8bee`: 319 passed, 0 failed.** No full run after it (budget): the
  integration fix changes `packs.lua` and its fixture; `r71_pack`, `r71_mobs`, `r71_frame`,
  `r71_ui`, `r71_guard`, `r71_l20` pass on it.
- **Engine, real client on Xvfb, seed 42, `7e43e00e`:** `r71_l20` 141 PASS, 0 FAIL, 0 falls: create
  to store at 20 with credit, door, chest, Gold and quest, rooms and boss at 29, no error.
  `r71_pack` 62 PASS, 0 FAIL, the capital after a logout death with the run gone
  included (stood at (23,42,−1522), the stone at (22,42,−1522)).
- **Lanes:** `check_lua.sh`, `check_fresh_server.py`, `build.py --check`, `income.py --check`,
  `validate.py --game`, `check_rules --shipped`; `check_upgrade.py` by lane D. Fixtures per lane
  are in the reports. `r71_frame` carries about 111,000 checks, `r71_pack` 249,000, `r71_l20` 48,500.
- **Lane D:** docs only, no fixtures and no boots, by its brief. `tools/r71_l20/balance.py` run
  for the model's final numbers.

### Open notes

- **For the user:** the standing defaults above, first the boss's ground drops; the coins; the
  shove; whether travel failure texts move to the feed; the
  [outline](round71-expeditions-outline.md)'s five open choices.
- **Not proven by anyone:** see the checklist's first lines. Slots 2–100 rest on arithmetic and
  the fixture, only slot 1 ran in the engine. `expelled` and `empty` lines ran in fixtures only.
- **For the next Expeditions:** a lava guard before level 60; a sized room clock and floor marks
  before levels 30 and 50 (OUTLINE's review); `on_spawn` families; the arrival beyond a pack's
  view range + 8. [Module guide](../technical/module-guide.md#expeditions).
- `loot.lua`'s comment still says a quarter hour is "the length of a run". `income.py --check`
  has no Expedition term. Both for the coins' decision.
- Every smaller note is a BACKLOG row in the merge notes, one being that open-world mobs keep
  the fall mechanism fixed here for packs.
