# Round 59 — the story arc's first chapter and the quest rework of levels 11–20 (0.59.0, map reset)

Coordinator: Claude, 2026-10-24. Status: **planned**, waiting for the user's go. The plan review (a fresh Opus,
`r59/reports/plan-review.md`) is folded in; its blocker and questions are decided (§2a).

Round 59 starts the **quest rework of levels 11–60** on the Round 57 quest system, one level band per round, and
builds the **first chapter of the story arc** that the user picked in Round 57. This round is the band **11–20**: the
six zones Copperfell Foothills, Goldmead Vale, Starbough Vale (The Accord) and Mournfen, Redtusk Savanna, Raincall
Basin (The Throng), and the chapter's opening at the level-19 handovers in the six capitals. The user decided on
2026-10-24:
- **scope:** levels 11–20 this round; 21–60 follow band by band;
- **the chapter first:** Astra drafts the band's story chapter with variants at its open points, the user picks on a
  page, and only then Opus builds the quest structure;
- **a map reset is fine:** production is deployed only after the whole quest rework, so new sockets, givers and
  template changes are allowed (the "avoid a reset" rule does not apply).

Start state: main `90763439` (0.58.0, map reset), not pushed; the user's joint GUI test of 0.57 and 0.58 runs in
parallel and may send fixes.

Inputs:
- the Round 57 quest rulings (Round 57 plan §2, rulings 9–18), the system (`docs/design/quests.md`), the start-zone
  precedent (Round 57 STARTQUESTS, STARTTEXT, TEXTREVIEW);
- the story arc decision (Round 57 plan "Decisions during the round"; private draft
  `r57/reports/storyarc2-report.md` §3–§6 and its check `storyarc2-check.md`): levels 1–19 free; chapter 1 opens at
  the capital envoy at 19 with no prerequisite, A1/T1 send the player to the capital's guild leader, A2/T2 at 20 send
  them to a place in the capital zone and back; the band's theme "your own names end up in the wrong ledger"; the
  user's picks (guilds and military closely interwoven, little conflict inside a faction; a traitor or a wrong
  decision at the author's choice; the enemy guild impersonal);
- the Round 58 guild content in these zones (the `guild_t2_report_*` story follow-ups, `camp_hunt_t2`, the mining camp
  foreman hubs);
- the survey `~/projects/grudgelands-orchestration/r59/reports/survey-quests-11-20.md` (facts with file:line, the
  validator dry run, the pins, the ledger numbers);
- player feedback (BACKLOG ~96-101): fewer mob names, more objective variety (about 83 % of objectives are kill or
  kill-for-drop today).

## 1. Lanes and waves

| Wave | Lane | Who | Goal (one line) | Waits for |
|---|---|---|---|---|
| 0 | CHAPTER1 | Astra | The story chapter for levels 11–20: the band zones' local threads under the arc's theme, the chapter's quests A1/A2/T1/T2, the places and objects they need; two variants at each open point | the user's go |
| 0 | QSYS3 | Opus | The quest-system changes the band needs (§4) | the user's go |
| 0 | CHECK1 | Opus | A feasibility check of CHAPTER1's draft against the data and the system (as `storyarc2-check` did) | CHAPTER1 |
| 1 | BANDQUESTS | Opus | The six band zones rebuilt on the Round 57 system, flagged `reworked`, placeholder texts; the band zones' spawn files | the user's chapter picks, QSYS3 merged |
| 1 | STORYQUESTS | Opus | The chapter's story quests in the six capitals (envoys → guild leaders → a place in the capital zone and back), the leaders' hubs, the new places and use objects (placeholder looks from shipped textures) | the user's chapter picks, QSYS3 merged; rebases after BANDQUESTS merged |
| 1 | STORYART | Astra | Art for the new use objects of both lanes (two proposals, a pick page) | the user's QUESTMAP verdict |
| 2 | BANDTEXT | Astra | The texts of the band and the chapter (both lanes' quests) | the user's QUESTMAP verdict |
| 2 | TEXTREVIEW | Opus | Text review with a suggestion page; the user picks | BANDTEXT |
| 3 | D | Opus | Docs, CHANGELOG, version 0.59.0 with the map-reset declaration, STATUS, the GUI checklist | everything else |

Every non-trivial code lane gets an independent Opus review and a delta review for every logic fix. Art ships only
after the user's pick. BANDQUESTS and STORYQUESTS show the user **one** QUESTMAP page together, built from main after both merged (BANDQUESTS
merges first; STORYQUESTS rebases on it and builds the page).

## 2. Rulings

Carried over unchanged from Round 57 §2 (rulings 9–18) for every reworked zone:
- as few quests as possible without losing depth; a task that is the same in several zones is **one shared quest**
  with a variant per zone; local quests only where the zone's own story is the point;
- free play: every free quest requires only a level; at most one follow-up, rarely; a zone offers its quests at once;
  **no repeatables**; kill counts follow the spawn phase (a night-only target asks about a third of the day count);
- story quests are marked (`story`), may chain, and carry the arc; a completion text where it helps;
- choice rewards and the reward budget per zone (two one-enchant rewards and one two-enchant reward; capitals
  excepted); equipment choices offer one item per armor class or weapon line; a reward is never the requested item.

New for this round:
- **The story arc's chapter 1** follows the user's picks (§ Inputs) and the user's picks on the CHAPTER1 page.
- **More objective variety** (player feedback): the band's quests use the system's other kinds (talk, item delivery,
  gathering, use objects) where they fit, so that kill and kill-for-drop objectives are clearly fewer than today's
  ~83 %; fewer distinct mob names per zone where a quest family can share one.
- **The start departures and the band's first quests:** the six `*_departure` quests stay (ids kept) and still hand the
  player to the band zone's first giver, but the band's first quests (min level 9–10) require nothing (free play; today
  ten require a departure, which the validator refuses once the band is flagged).
- **The capitals' first quests** (levels 19–20) stay as shipped except where the chapter's quests replace or join them;
  **the capital files stay unflagged** until their band (Round 60): flagged, their existing chains raise E-free-chain.
- **The camp hunt `camp_hunt_t2`** (all six variants in band zones) is folded into the band's rework; Round 58's rule
  that a camp hunt must not target a role the zone's quests hunt yields to "fewer mob names" (§2a point 4).
- **Map reset is fine** (the user, 2026-10-24): new quest sockets, NPCs and blueprint or template changes are allowed.

## 2a. Decided after the plan review (the user, 2026-10-24)

1. **The chapter's places may lie in the town too** (the review's blocker: a "use at a place" objective takes today only
   a clash site or a spawn-file place picked `farthest_from_roads`, `spawn_regions_core.lua` ~595, 626, so never in a
   town or by a road). The user chose a **new place kind on settlement sockets**: QSYS3 builds it (§4), so a place can
   be a spot in a capital (a depot, a warehouse yard) as well as a remote spot in the wilderness.
2. **The start zones' reward pattern applies to 11–20** (ruling 18): per band zone an early consumable choice, two armor
   pieces with one enchant (cloth / leather / metal), a weapon with prefix and suffix at the zone's end, at item levels
   11–20.
3. **"At most one follow-up" counts per faction** (QSYS3's per-faction `E-free-follow-ups`).
4. **`camp_hunt_t2` may share its target with zone quests** (folded into the band's rework; Round 58's distinct-role
   rule yields to "fewer mob names").

## 3. Shared conventions

- **Upgrade classification: map reset** (one `map_reset` entry for 0.59.0, by D). Characters keep items, levels, quests
  and money; quests whose ids vanish are dropped by the upgrade contract §4; new ids for every reworked quest whose
  objectives change.
- **Quest text rules** as in Round 57 (placeholders for places and directions, items by name, no tooltip text, no
  existing game; the guilds' proper names in texts and on buildings; the UI says "Miner's Guild").
- **Fixtures:** `tools/r59_<lane>/portable_test.lua`; the pins the survey lists (`r57_startquests` ~425-432,
  `r58_guildquests` ~117, ~185-215, ~244-276, ~369-372, `r46_xp`, `r45_st`, `r32_f2`, `r56_questmap`) move with a
  one-line reason each; `r58_guildquests` ~113 passes today only because "10 differ" contains "0 differ": BANDQUESTS
  replaces that check. Both code lanes edit the same count pins: BANDQUESTS merges first, STORYQUESTS rebases.
- **Owners:** BANDQUESTS the six band files, the band zones' spawn files (`grug_mobs/data/zones/<zone>.spawns.json`:
  places, dropped or added quest targets) and its rows in `use_objects.json`; STORYQUESTS the capital files (unflagged),
  the leaders' hubs, the capital templates' place sockets and the capital zones' spawn files (the chapter's places) and its
  rows in `use_objects.json`.
  New use objects get placeholder looks from shipped textures until STORYART's pick.

## 4. Lane goals (briefs add file facts)

**CHAPTER1 (Astra).** A transfer point or any other "place" may be a spot in a capital town (QSYS3's new place kind)
or a remote spot in the capital zone's wilderness (§2a point 1). From the picked draft: for each faction the chapter's story across the band and into the
capital at 19–20: the three local threads per faction that the band zones carry as free quests (Pella, Tovin, Nima;
Rokka, Veko, Hollis: how they feel the theme without being story quests), the chapter's quests A1/A2 and T1/T2 (givers,
turn-ins, what happens, the traitor or wrong decision if the author places it here), the **places** in the capital
zones (the `<transfer point>`s) and the **objects** to use there, and what the guild leaders say (the six mine leaders live in
the 21–30 files: text proposals only, built in Round 60). Two variants at each open point; a short list of what the structure needs (new givers, sockets, objects). The
coordinator builds a pick page from it.

**QSYS3 (Opus).**
- **Per-faction `E-free-follow-ups`**: a free quest's follow-ups counted per faction (the guild reports block flagging
  Copperfell and Mournfen today, BACKLOG ~3175).
- **The quest log shows a shared quest's home zone** instead of the variant's zone (`quest_box.lua`, BACKLOG ~3171).
- **A place kind on settlement sockets** (§2a point 1): a quest place defined by a socket in a settlement's template or
  blueprint (a capital, a village), so a "use at a place" (and a "go to" if the system has it) can target a spot in a
  town; the use object stands there as a node or entity the quest system already knows (re-check `use_objects.json` and
  the spawn-file places' mechanism and reuse them); map marker and quest-log location as for today's places; the
  validator checks that the socket exists. Report the design before building if it reaches beyond `grug_quests`, the
  settlement socket registry and the validator.
- No new objective kind unless CHAPTER1's picks need one (then a question to the user first).

**CHECK1 (Opus, read-only).** CHAPTER1's draft against the data and the system: every named NPC, place and object
exists or is listed as new; the free/story rules hold; the chapter fits the levels and the capital layouts; what is
expensive. The user sees the check beside the pick page.

**BANDQUESTS (Opus).**
- The six zone files rebuilt on the Round 57 system and flagged `reworked`; shared quests where the task is the same
  across zones (per faction or across both), local quests where the zone's story is the point; the counts before and
  after; the free-play rules; no repeatables; night counts.
- Objective variety and fewer mob names (§2); the band's first quests require nothing; the start departures' pin
  moves; the guild quests and the camp hunts in these files keep working (with QSYS3's per-faction rule the files can
  be flagged).
- New quest sockets and givers in the band's POIs where the structure needs them (map reset; a blueprint change needs
  `seed_fleet quick`).
- Rewards per zone on the Round 57 pattern, at item levels 11–20 (T2 materials, enchant tier 2; the survey lists the
  ids and pools): an early consumable choice, two armor pieces with one enchant (cloth / leather / metal), a weapon with
  prefix and suffix at the zone's end; the budget rule passes.
- The ledger (`tools/r28_design/ledger.py`) 10→20 before and after, as numbers to compare.
- Placeholder texts; the QUESTMAP page with STORYQUESTS.

**STORYQUESTS (Opus).**
- The chapter's story quests as picked: A1/T1 shared from the three envoys of a faction, turned in at the capital's
  guild leader; A2/T2 from the leader to the picked place in the capital zone and back. Sharing needs no code: a line
  is a label (`loader.lua` ~117), so a faction's three envoys get one common non-`front` line name, as the start towns'
  elders share theirs.
- A hub per capital for the guild leaders (they are talk targets in no hub today), the new places (town places on new
  sockets in the capital templates or blueprints through QSYS3's place kind, or wilderness places in the capital zones'
  spawn files), the new use-object kinds with placeholder looks (STORYART's picks swap in later). A template change
  runs `tools/building_templates/check.py` and `seed_fleet quick`.
- The capitals' existing first quests kept or adjusted only where the chapter needs it.
- Placeholder texts; the QUESTMAP page with BANDQUESTS.

**STORYART (Astra).** The new use objects of both lanes (from the accepted QUESTMAP): two proposals, a pick page; icon
and node rules as before (simple, readable at 16/32 px).

**BANDTEXT (Astra) and TEXTREVIEW (Opus).** As in Rounds 57 and 58, for both lanes' quests.

**D.** Version 0.59.0 with the map-reset entry; CHANGELOG, STATUS, ROADMAP, BACKLOG, AGENTS; the completion section;
the GUI checklist (a level-11 character through the band, the chapter at 19–20 in each capital); a seed fleet if
blueprints changed (`full` at the round's end when a placement or footprint change merged).

## 5. Rules

The usual ones ([round workflow](../process/round-workflow.md)): one worktree and branch per lane; an independent Opus
review per non-trivial lane and a delta review for logic fixes; the Lua queue at most 8 at once; no pushes, merges or
syncs by lanes; nothing unpicked ships. Fixtures: each lane runs only its own fixture plus the fixtures that test the
behaviour it changes, and the full run once before its report.

## 6. Verification

- **Gates:** the full fixtures, `check_fresh_server.py`, `check_upgrade.py` (with the map-reset entry),
  `validate.py --game` (0 errors with the six band files flagged; the capitals unflagged), `quest_kinds.py --check`,
  `tools/r28_regions/run.sh` (the quest-target regions; stale since Round 51, so `quest_targets.py` stops on them),
  `income.py --check`,
  `tools/building_templates/check.py` if templates change, the seed fleet as above, one boot per lane.
- **GUI checklist** (D, draft): a level-11 character of each faction finds the band's quests at once, without a
  departure first; shared quests read in each zone's voice; the reward choices with their enchants; at 19 the envoy
  offers the chapter's first quest; the guild leader continues it; the place in the capital zone and its object work;
  the quest log shows the variant's zone; the guild quests and camp hunts still work.

## 7. Orchestration notes

- **Order:** CHAPTER1 and QSYS3 start together; CHECK1 after CHAPTER1; the user's chapter picks; then BANDQUESTS and
  STORYQUESTS (BANDQUESTS merges first, STORYQUESTS rebases and builds the joint QUESTMAP from main); the QUESTMAP
  verdict; STORYART and BANDTEXT (from main after both merges) → TEXTREVIEW; D last.
- **Shared files:** BANDQUESTS owns the six band files (and the start departures' pin); STORYQUESTS owns the capital
  files and the leaders' hub; both touch `grug_quests/npcs.lua` and possibly blueprints: STORYQUESTS the capitals,
  BANDQUESTS the band POIs.
- **The GUI test of 0.57/0.58** runs in parallel; a fix it needs becomes a small FIX lane that merges first.

## 8. Engine and code facts (from the survey; re-check in the briefs)

- The band: zone rows `wp40/source/simple_map.lua` ~65-92; six files, 14–15 quests each, one linear chain per zone
  (1–2 chains per zone: steward → scout → captive → named leader → departure at 19), 46 kill, 31 item, 20 talk objectives, no main-line
  quest; no free quest socket in the band's POIs (`r14_poi_blueprint.lua` ~291-294, 320, 372; `r58_camp_blueprint.lua`
  ~153).
- The validator dry run with the six files flagged: 97 errors (80 E-free-chain, 14 E-free-follow-ups, 3
  E-free-requires) and 14 W-night-count (`validate.lua` ~755-806, `validate.py` ~1226-1266).
- The capitals (levels 20–30): one hub each with the envoy and the cook, two lines each; the guild leaders
  `r58_guild_leader_*` (`npcs.lua` ~115-127) are in no hub; the guild house has three idle residents
  (`capital_services.lua` ~41-44).
- Hub limits: 2 givers per hub, 2 lines per giver (`validate.lua` ~20-21); a shared quest needs a common line
  (`validate.lua` ~606); a line is only a label (`loader.lua` ~117), `front` is reserved for front files
  (`validate.lua` ~630-634).
- Places: a "use at a place" objective takes a clash site or a spawn-file place picked `farthest_from_roads`
  (`spawn_regions_core.lua` ~595, 626).
- Rewards at item levels 11–20: T2 materials iron / woven / cured (`grug_gear/init.lua` ~117-118), enchant tier 2
  (`grug_quality/init.lua` ~110), pools ~56-74.
- The ledger 10→20: 11,750 XP needed; reward XP 5,056–5,521 per race; questing share 91–100 %.

## 9. Later

Round 60 and on: the bands 21–30, 31–40, 41–50, 51–60 with the arc's next chapters (Frostbarrow and Ossuary Reach at
24–29, with Brodd Deeppeg's per-NPC title, BACKLOG ~3157; the mine leaders as guild members; the front at 41; T3's two
free bosses, BACKLOG ~3099); then the production deploy with one map reset; then the
armor redesign and the unique items.
