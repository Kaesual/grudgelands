# Round 59 — the story arc's first chapter and the quest rework of levels 11–20 (0.59.0, map reset)

Coordinator: Claude, 2026-10-24. Status: **complete** ([completion](#completion-2026-10-24)); 0.59.0 not pushed, it
waits for the user's joint GUI test of 0.57.0, 0.58.0, 0.59.0 and 0.60.0
([checklist](round60-plan.md#gui-checklist-rounds-57-58-59-and-60)); the user's go 2026-10-24. The plan review (a fresh
Opus, `r59/reports/plan-review.md`) is folded in; its blocker and questions are decided (§2a).

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

## Completion (2026-10-24)

Every lane is merged on main, every code lane independently reviewed (Opus) and every logic fix delta-reviewed; this
lane D (the version, the declaration, this section, AGENTS, the status owners, the joint GUI checklist) follows on
main `8f84be22`. **0.59.0 is a map reset:** no migration step; characters keep their items, levels, quests and money;
a quest whose id vanished is dropped (upgrade contract §4); item, achievement and waypoint ids unchanged; no new
position in player meta. **Push:** not pushed; 0.57.0 was pushed on 2026-10-23 without its GUI test, and 0.58.0 and
0.59.0 wait for the user's joint GUI test of all three. **Sync:** by the coordinator after every merge.

### Lanes

Worktrees and branches `r59-<lane>`. Main's first-parent commits, in order (lane tip in brackets):

| Lane | Commit | What | Review |
|---|---|---|---|
| plan | `567669ee` | this plan with the plan review folded in (B1 and I1–I7) and the user's four decisions (§2a) | fresh Opus plan review (one blocker, seven important findings) |
| CHAPTER1 | outside the repository | GPT-6 Astra's draft of chapter 1 (`r59/reports/chapter1-draft.md`, German): the band's six local threads, A1/A2 and T1/T2, the places and objects, the leaders' stances, open points K1–K13 with two variants each | CHECK1 (Opus, read-only, `chapter1-check.md`): ready after three fixes, three more open points K14–K16 |
| QSYS3 | `138e8e33` (`8a0f9e01`) | `E-free-follow-ups` per faction (`validate.lua`, `validate.py`); the quest log's zone of the variant taken (`grug_map/quest_box.lua`); the town place kind: `socket:<settlement key>/<socket id>`, role `quest_place` (`grug_core/settlement_sockets.lua`, `labels.lua`, `use.lua`, both validators, `E-use-place`); `tools/r59_qsys3` (`socket_places.lua`, fixture, engine probe) | MERGE AFTER FIXES (L1: a settlement with only a `quest_place` socket logged an error at every boot), fixed (`start_npcs.lua` build_rows treats a settlement without a resolver socket as silent scenery, an `r31_g` case), delta MERGE |
| BANDQUESTS | `5b536a68` (`42d3e39e`) | the six band files rebuilt and flagged `reworked` (`tools/r59_bandquests/build_structure.py`, `report.py`, fixture); the four use-object kinds; `CAMP_PLACES` `quest_place` sockets in the dwarf, human, orc and troll bandit camps (`wp40/r14_poi_blueprint.lua`); the recipe places `snare_ground` (Starbough Vale) and `name_rest` (Mournfen); four `quest_target` flags off; the region maps of all 38 recipe zones regenerated (stale since Round 51) | MERGE AFTER FIXES (two quests asked for Gravemoss, an Alchemy-only herb), fixed (data only: `copperfell_firewood`, 12 logs; `mournfen_markers`, 6 Wooden Signs), checked by the coordinator |
| STORYQUESTS | `bc415821` (`6ebb3ed6`) | chapter 1's four story quests in the capital files (`tools/r59_storyquests/build_structure.py`, fixture, engine probe), the six leaders' hubs (`"anchor": "zone"`), the envoys' common line `envoy`, the six town places in their service plots' `extra_sockets`; rebased on BANDQUESTS; the joint QUESTMAP (`questmap.py`) | MERGE (five minor findings: two text notes to BANDTEXT, a stale fixture label fixed in `ad2eca2f`, the objects' notes, a GUI judgement); the rebase checked by the coordinator (game deltas identical to the reviewed tip except `use_objects.json`) |
| BANDTEXT, TEXTREVIEW | `8f41fb53` (`1f6dd580`) | GPT-6 Astra wrote the 168 text fields of 63 quests (`f5b5e77e`: 59 titles, 85 texts, 24 completions); `034b27ae` (STORYQUESTS' agent on `r59-bandtext`): both generators' `--check` compare the structure only, the chapter fixture checks the real texts; the user's 20 text picks applied by the coordinator's script | TEXTREVIEW (Opus): 0 must-fix, 20 proposals, all picked; `034b27ae` delta MERGE (mutation-tested) |
| STORYART-SHIP | `b36f9f70` (`c1b59fb3`), `8f84be22` | the four picked sprites (`grug_quests_obj_{dispatch_record,witness_record,held_supplies,snare_bundle}.png`), their `use_objects.json` rows and sizes, `tools/r59_storyart` (`paint_art.py --check`), `LICENSE-media.md` "Round 59"; then the coordinator's `tools/README.md` duplicate fix | checked by the coordinator (PNGs byte-identical to the picks, `r36_q0`) |
| D | this section | the version 0.59.0 and the `map_reset` entry, upgrade contract §2, AGENTS, STATUS, CHANGELOG, BACKLOG, ROADMAP, README, the docs check, the joint GUI checklist | independent review |

**STORYART** (GPT-6 Astra, outside the repository): story art drop 01 with two proposals per object, the snare redone
as drop 01b; the user's picks are below. Nothing unpicked ships.

Main has 272 portable fixtures (3 new: `r59_qsys3`, `r59_bandquests`, `r59_storyquests`). `mods/` against 0.58.0
(measured, `git diff 90763439 8f84be22 -- mods`): 35 files, +2,121 −1,630 lines: the twelve band and capital quest
files, `use_objects.json` and the four textures, the six capital district files and the camp blueprint, four spawn
files, and the code in `grug_quests` (`validate.lua`, `labels.lua`, `use.lua`), `grug_core/settlement_sockets.lua`,
`grug_mobs/start_npcs.lua` and `grug_map/quest_box.lua`.

### Lanes added during the round

- **STORYART-SHIP:** STORYART works outside the repository, and the four objects shipped with placeholder looks (a
  texture modifier over a shipped object PNG). After the user's OK of the redone snare, a small Opus lane copied the
  picked PNGs into `grug_quests`, set the picked sizes and committed the trimmed painters, so the art is reproducible
  and `r36_q0` checks the four as shipped files.
- **The generators' `--check` (`034b27ae`)** was a step on `r59-bandtext`, not a lane: once the texts landed, both
  generators' `--check` reported every file as different; it now compares the structure only, and the chapter fixture
  checks the real texts instead of the placeholders.

### Decisions during the round

**The user** (HANDOVER):

- **§2a (plan review):** places in the town too (QSYS3's place kind on settlement sockets); the start zones' reward
  pattern for 11–20; "at most one follow-up" per faction; `camp_hunt_t2` may share its targets with zone quests.
- **The chapter picks K1–K16: all "A"** (the recommendations, no notes), including the three the check added:
  K1 no traitor and no wrong decision of one's own before level 21; K2–K7 the six town places (the Highcourt dispatch
  yard at the butcher's plot `market_store`, Dur Brannoc's `forge_ore_yard`, Lethariel's `market_bowyer`, Gor
  Drazhak's water depot at `warren_cook_court`, Kezamba's `shore_store`, Nhal Veyr's receiving point at
  `homes_mourners_hall`); K8 the load record in the bandit camp, shared with Goldmead; K9 Starbough's snares in the
  Lower Boughs; K10 Mournfen's grave names in the Blightfields; K11 Raincall's held supplies, shared with Redtusk;
  K12 the captives stay at their sockets; K13 A2/T2 decides the capital's case, the papers' source stays open;
  K14 the witness and the perpetrator stay local per zone; K15 the draft's frame as the core plus local tasks until
  the quest XP is roughly today's; K16 the close names (Veko / Vek, Mordec Silt / Silt) stay.
- **No NPCs that vanish per player:** asked by the user; nothing in the chapter does (K12 A keeps the captives in
  place). A per-player visibility of NPCs is noted as a possible later feature
  ([carry-overs](../../BACKLOG.md#round-59-carry-overs)).
- **The questing share:** kept at BANDQUESTS' 55–61 % (no XP bump on the non-kill quests).
- **QUESTMAP:** accepted ("Die Quests sehen gut aus"); the user's question whether the gathered items spawn in the
  quest zones was checked in `grug_gathering/catalog.lua` (yes; Sunleaf is a spice, ungated).
- **The art picks** (`story-art/pick/picks.md`): the dispatch record drop-01 P1 (a trestle board, size 1.1), the
  witness record P2 (two bound tablets, 1.2), the held supplies P1 (packs behind a rope cross, 1.3), the snare P1's
  shape but rope instead of metal, redone as drop-01b (brown hemp rope, loop and peg, 1.2) and accepted.
- **The texts:** all 20 proposals of the text review.

**The coordinator** (answers to lane questions and the check; each built as stated):

- **The check's three fixes taken without asking:** the witness travel shared per faction (one level per shared
  quest), the Redtusk and Raincall use sockets outside the camp members' spawn disc (as built: out of the leader's
  sight, since the disc covers the whole camp; Deviations), the town sockets in the plots'
  `extra_sockets` (two of the templates are built by several plots; Nhal Veyr's outside the hall door).
- **The leaders' hubs anchored at the zone** (`"anchor": "zone"`): a hub anchored at the capital fails
  `validate.py --atlas` (`r28common.py` gives a guild NPC its settlement key as its anchor), as the camps' foreman
  hubs already do.
- **STORYQUESTS' questions:** the rewards as proposed (A1/T1 weight 1; A2/T2 weight 3 with a choice of 2 Healing or
  Mana Potion II); the envoys' common line named `envoy`; no dressing beside the town places (the user sees the spots
  on the QUESTMAP and in the GUI test).
- **QSYS3's optional question:** town places stay no `{name:…}` placeholder targets for now.
- **BANDQUESTS' fix** checked by the coordinator as a data-only delta (no logic changed).

### Deviations from the plan

- **One lane added** (STORYART-SHIP, above).
- **The town place kind** needed one change outside `grug_quests` and the registry: `grug_mobs/start_npcs.lua`
  skips a settlement whose sockets nobody stands on (the review's L1), so a camp or POI without NPC sockets may carry
  a town place.
- **The band's use places are town places of the camps**, not spawn-file places (a spawn-file place keeps 64 nodes
  from camps, CHECK1); Starbough and Mournfen got recipe places. The held supplies' corner is outside the leader's
  14-node sight but within the members' 24-node spawn disc (the whole camp is; BANDQUESTS' re-check), a GUI judgement.
- **The leaders' hubs** use `"anchor": "zone"` (above).
- **`check_upgrade.py` passed in every lane** (the plan expected a failure until D): the unpushed 0.58.0 entry already
  covers every change against pushed 0.57.0; D declares 0.59.0's reset all the same.
- **The generators' `--check`** compares the structure, not the texts, since `034b27ae` (Round 58's gave up at that
  point; Round 59's stays a check).
- **`tools/r28_regions/run.sh`** was rerun for all 38 recipe zones (the plan's gate, stale since Round 51), so
  `quest_targets.py` runs again (0 missing).

### Numbers worth keeping

Measured unless marked "report" (taken from the lane's report).

- **Quests:** the six band files hold 86 → 62 quests (measured, `git show` of `567669ee` and `8f84be22`): the band's
  own 83 → 59 and Round 58's three (`camp_hunt_t2`, `guild_t2_report_accord`, `guild_t2_report_throng`); 13 offered
  per zone (before 15–17); 3 shared (`band_repairs` in six zones, `band_load_record` and `band_held_supplies` in two);
  4 story quests in the capitals; **433 shipped** (453 − 83 + 59 + 4; measured over the quest files, 48 files).
- **Objectives** (all six band zones, `tools/r59_bandquests/report.py --before 567669ee`): kill 51 → 18,
  kill-for-drop 13 → 0, item 18 → 36, travel 24 → 24, use 0 → 6; the kill share per zone 50–67 % → 21 % (all six
  together 60 % → 21 %); **mob names per zone 8–10 → 3**.
- **The ledger 10→20, solo** (`ledger.py --game --track <race> --start-level 10` on main `8f84be22`): reward XP and
  the questing share, against 11,750 XP needed: human 5,495 (61 %), dwarf 5,054 (57 %), elf 4,880 (54 %), orc 5,172
  (58 %), troll 5,172 (58 %), undead 4,920 (55 %); before the round (report, survey) 5,056–5,521 XP and 91–100 %.
  A1/T1 count in this band (+120 XP), A2/T2 in 20→30. The lanes' reports read 1–2 points higher (55–62 %).
- **The validator dry run** with the six files flagged (report, QSYS3 and BANDQUESTS): 97 errors (80 E-free-chain,
  14 E-free-follow-ups, 3 E-free-requires) → 95 after QSYS3 (E-free-follow-ups 14 → 12, the guild forks) → **0**
  after BANDQUESTS; `validate.py --game` on main: 0 errors, 6 warnings (as before the round).
- **Rewards** (`report.py`): per zone the steward's first quest (reward level 11) 2 Healing or 2 Mana Potion II; the
  day hunt (15–16) a prefix armor piece; the local's last craft (17) a suffix piece; the perpetrator (19) a weapon
  per line with a prefix and a suffix; the slots Copperfell chest/feet, Goldmead head/feet, Starbough head/legs,
  Mournfen head/chest, Redtusk head/feet, Raincall chest/legs.
- **Town places** (report, engine): the hold's `use_pass` 69 µs (QSYS3's probe); the six town places on seed 42 air
  over walkable ground with headroom (STORYQUESTS' probe).
- **Fleet times (report):** `seed_fleet quick` 100 of 100 in BANDQUESTS and STORYQUESTS (11 min 51 s under
  contention); lane D's **full fleet on main**: see [Round-end gates](#round-end-gates).

### Classification

**Map reset**, no step:
`{"schema": 3, "version": "0.59.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0", "0.58.0", "0.59.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0"], "map_reset_pass": "0.50.0"}`.
The reason ([upgrade contract §2](../technical/upgrade-contract.md#2-the-declaration)): the `quest_place` sockets in a
service plot of each capital and in four of the band's bandit camps and the two quest places in the Starbough Vale
and Mournfen spawn files change what world generation and the towns build. A world on 0.57.0 (or 0.56.1, 0.58.0)
moves on across one reset with the pre-reset pass: characters keep everything but their position and home claim
(contract §3.2); an active quest whose id vanished leaves the log, a kept id keeps its state.

What needs the reset and what alone would be compatible (the lanes' reports): the camp sockets (BANDQUESTS) and the
capital sockets (STORYQUESTS) change what new worlds build, and the quests that use them ride on the reset (the
capitals' plot cells are byte-identical, so an old world would have free cells there too); QSYS3's code, the quest
data itself, the texts and the art alone are compatible. Saved state, all without a position: `grug_quests:state`
for the new ids (no format change); nothing new in player meta or mod storage, so no `register_on_relocate` clear.

### Open notes

- **For the user:** the joint GUI test below, with these to judge: the held supplies' hold in the Redtusk and
  Raincall camps with the members around, the Nhal Veyr town place outside the mourners' hall, the four objects'
  look and size, the band's errands as a first version, a level-9 arrival at the steward whose first quest opens at
  10; from Round 58 the names never picked (the three cloaks, the achievement and its line) and from Round 57 the
  violet story colour (now on chapter 1 too) and the headland edge.
- **Round 60** reworks the band 21–30 with chapter 2 (§9).
- The reviews' and reports' notes are in the [Round 59 carry-overs](../../BACKLOG.md#round-59-carry-overs).

### GUI checklist (Rounds 57, 58 and 59)

**Superseded (Round 60):** the test was not run before Round 60, so one checklist for 0.57, 0.58, 0.59 and 0.60
replaces this one: [GUI checklist (Rounds 57, 58, 59 and 60)](round60-plan.md#gui-checklist-rounds-57-58-59-and-60) (the items below keep their numbers there; Round 60
changes items 4, 12, 14, 20, 30, 31, 40, 42, 43 and 46 and adds 5–7 and 49–66).

One test for all three rounds (nothing since 0.57.0 has been tested in the GUI), desktop and the web build (the
lanes' web shots were taken at 1024 × 600; Round 57's at 1280 × 720 and 1035 × 696), on the synced game. It replaces
[Round 58's list](round58-plan.md#gui-checklist-rounds-57-and-58); items 1–34 keep that list's numbers.

**Resetting a local world** (what the hosting platform does, contract §3.5; one reset covers 0.58 and 0.59):

1. Quit the world (stop the server), then make a copy of the world folder.
2. Optional, to test the claims' containers: from the repository checkout,
   `python3 tools/migrate.py --world <world folder> --map-reset` (Python 3.13 or newer; it packs the containers in
   every housing claim and must end with exit 0).
3. Delete `map.sqlite` in the world folder; keep `map_meta.txt` (the seed), `world.mt`, `players.sqlite`,
   `auth.sqlite` and `mod_storage.sqlite`.
4. In Luanti's settings, *Content: Games → Grudgelands → Hosting platform*, raise **Map reset counter**
   (`grug_reset_world`) above the world's record: 1 for a world never reset before, else one more than last time (the
   game reads it at the start; only a value above the record resets).
5. Start the world. `debug.txt` must show `[grug_core] map reset N applied to the world (was M)`
   (`grug_core/map_reset.lua`); if the line is missing, the value was not above the record: quit, restore the copy
   and start again from step 2 with a higher value. The map is generated anew from the seed; each existing character
   is held on the waiting screen and moved to its race's start town at its next join, without the welcome.
6. Afterwards set the counter back to **0**: it is one setting for every local world, and another world whose record
   is lower would reset at its next start (without its map being emptied): its claims and NPC records cleared, its
   characters moved to their start towns.

**Order:** (A) the existing world, reset as above, first join with its old characters; (B) everything else on that
world and with new characters; (C) a new world (or the "test" world) for the bays. *Re-checked (D, as Round 58):* no
Round 57, 58 or 59 item needs the old **map**; Round 57's items 3 (its last sentence), 5 (its last sentence) and 15
and Round 59's band ids test an old character's **first join on the new code**, which the reset keeps (player meta
stays), so they run in (A) at that first join, the path the production world takes. Do not join the existing world
on the new game before the reset, or that first join is spent. Items 1, 2 and 4 of Round 57 need no old state.

**(A) The existing world, at the first join after the reset** (a character above level 10 with old start quests done
or active, ideally one with old band quests of levels 11–20 active or done, a crafting job running when it last
logged out, enchanted items, a housing claim if you have one):

1. **The reset:** the character arrives at its race's start town without the welcome and keeps its level, inventory,
   equipment, money, quests, professions, mounts and waypoints; its home claim is gone (Return home falls back to the
   innkeeper), the Housing Steward hands out a new Claim Stone, and (after step 2) the claim's containers wait in its
   Belongings tab. The Character page shows "Miner's Guild: Rank 0".
2. **Round 57 item 3, last sentence:** a job of the old version that was running finishes as before (its output in the
   inventory or the Overflow).
3. **Round 57 item 5, last sentence:** the existing character has its Basic recipes after this login.
4. **Round 57 item 15, changed by Round 59:** the new start quests are offered (one whose old finale was done keeps it
   done); its old start quests are gone from the log without an error. Its level-11 zone now offers the **reworked**
   band quests (not the old chain); an old band quest that was active and no longer exists is gone from the log
   without an error, while a kept id (the departure, the witness travel, the handoff, five day hunts, three
   perpetrators) keeps its state: done stays done and is not offered again.

**(B) Round 57** (its [checklist](round57-plan.md#gui-checklist-round-57) items, unchanged unless noted):

1. Layout C. 2. The queue. 3. Offline and the overflow (its last sentence in A). 4. Favourites. 5. The Basic unlock
(its last sentence in A). 6. Recipe details. 7. Alloys and woods. 8. Dyes. 9. Vendors (and Round 58's mason below).
10. A new character's start (the waystone and mailbox now stand at the town's centre: Round 58 below). 11. Shared
quests. 12. Choice rewards (Round 58's hunts add a choice of materials, below; Round 59's band rewards, below).
13. Completion text: **changed by Round 59:** the start town's departure (level 9) now leads to the level-11 zone's
steward, whose first quest opens at level 10 (item 35). 14. Story marking: **changed by Rounds 58 and 59**: judge
the violet "!", the "Story" heading and the map icons on a guild follow-up (item 31) or on chapter 1 at an envoy
(item 43) instead of the capture probe. 15. An existing character above level 10 (in A). 16. Bays (in C). 17. The
chin underside. 18. Help. 19. The pages for the user.

**(B) Round 58** (items 20–34 of [Round 58's list](round58-plan.md#gui-checklist-rounds-57-and-58), unchanged unless
noted): 20. Mining camps. 21. Camps under construction. 22. The map. 23. The lift. 24. The rooms. 25. The camp
vendor at rank 0. 26. Reputation. 27. The cloaks. 28. Ore Sense. 29. Treasure Hunt. 30. Guild houses (**since Round
59** each leader also gives chapter 1's second quest, item 44). 31. Guild quests: unchanged by Round 59 (the camp hunt
`camp_hunt_t2` and the guild reports are as Round 58 shipped them, now inside the reworked band files); check them
again in a band zone: the foreman's Iron, Jade and hunt at once, the report turned in at the leader. 32. Town fixes.
33. Help. 34. The pages for the user.

**(B) Round 59:**

35. **The band at level 11** (BANDQUESTS): with a level-11 character of each faction (`/xp give <you> <amount>`
    raises the level), in each band zone (Copperfell Foothills, Goldmead Vale, Starbough Vale; Mournfen, Redtusk
    Savanna, Raincall Basin): the village's steward and local, the outpost's scout, the bandit camp's captive and the
    mining camp's foreman offer their quests at once, each from its level, without a departure done first; no quest
    asks for another (apart from the guild reports, which follow both T2 gather quests). The start departure (level 9) arrives at the steward (Orrik Pineledger, Marta Millward, Ilyra
    Mossveil; Mordec Silt, Borak Redgrass, Daro Kapok), whose first quest opens at level 10 (**judge**: a level-9
    arrival finds no offer there yet).
36. **Shared quests in each zone's voice:** "Something Worth Mending" (4 Iron Bars and 4 Coal Lumps for the local) in
    all six zones, "Whose Name Is on the Load?" in Copperfell and Goldmead, "Already Ours" in Redtusk and Raincall:
    taken in one zone, the other zones do not offer it while it is active and never again once done; each zone's
    text reads in its own voice; "Return to" names the giver you took it from. **The quest log** (QSYS3) shows the
    zone you took it in: "Level … · Goldmead Vale" for the Goldmead variant, "Level … · Copperfell Foothills" for
    Copperfell's (and a start quest taken in Sunscar "… · Sunscar Flats", in Dawnmere "… · Dawnmere Fields").
37. **The reward choices with their enchants:** the steward's first quest 2 Healing Potion II or 2 Mana Potion II;
    the day hunt (level 15–16) a cloth, leather or metal piece with the class's main stat as its prefix; the local's
    last craft (17) another slot with a suffix (mana, crit, maximum HP); the perpetrator (19) a weapon per line (a
    Wand or Staff, the Bow, a Sword or Battle Axe) with a prefix and a suffix, at item level 19. The offer lists each
    by its enchanted name with its enchant lines; the item received has them. Slots: Copperfell chest and feet,
    Goldmead head and feet, Starbough head and legs; Mournfen head and chest, Redtusk head and feet, Raincall chest
    and legs.
38. **The use places in the four camps:** the load record at the Copperfell and Goldmead bandit camps (by the camp's
    stores) and the held supplies at the Redtusk and Raincall camps (the corner across from the captive's enclosure):
    the map crosshair on the spot, the object only for players who still need it, "<act> at <camp>" in the log and
    the HUD, the 4 s hold counted in the feed, stepping away or taking damage stops it. **Judge (Redtusk and
    Raincall):** can the hold be finished with the camp's members around?
39. **The snare ground and the name rest:** Starbough's "A Cruel Use for a Knot" (cut the snare bundle at the
    Starbough Snare Ground in the Lower Boughs) and Mournfen's "Before the Letters Go" (copy the names from the marker
    at the Mournfen Name Rest in the Blightfields): the object stands on dry ground, the holds take 3 s and 5 s, the place's name and direction
    read right in the text, the log and on the map.
40. **The gathered and crafted items in their zones:** the errands' logs, Corn, Potatoes, Melons, Sunleaf and Copper
    Lumps are found in their zones without a profession, and the torches, Wooden Signs, Wooden Ladders, fences and
    locked chests come from Basic recipes (Copperfell's 12 logs for the watch fire, Mournfen's 6 Wooden Signs).
41. **The hunts:** three mob names per zone (Copperfell: Bracken Fox, Surefoot Ibex, Goblin Foreman Nog; Goldmead:
    Rooter, Bristleback, Bandit Requisitioner Hobb; Starbough: Truffle Sow, Thicket Vixen, Poacher Snarekeeper Vetch;
    Mournfen: Bog Seep, Plague Tusker, Mirefolk Reed-Counter Silt; Redtusk: Cackler, Waterhole Zebra, Bandit
    Water-Broker Korr; Raincall: Wallow Sow, Serval, Bandit Tithe-Keeper Vek), every count by day; Korr's and Vek's
    kill quests (the giver stands in the camp) read without a doubled place.
42. **The departure at 19:** offered at 19 without the perpetrator done; it leads to the capital's envoy and reads
    well either way.
43. **Chapter 1, step one** (STORYQUESTS): at 19 each envoy (Mariel Waybook in Highcourt, Dorrin Gateledger in Dur
    Brannoc, Eriath Boughwarden in Lethariel; Thorga Roadspeaker in Gor Drazhak, Nalo Pathdrum in Kezamba, Ossa
    Quietregister in Nhal Veyr) offers the violet story quest "A Hearing for the Absent" (The Accord) or "Our Word,
    Our Witness" (The Throng); "Travel to <leader>" leads to the Miner's Guild house of the same capital and turns in
    only there. The envoys' old quests are still offered.
44. **Chapter 1, step two:** at 20 the leader (Alis Cartwright, Hadrin Beamset, Caelir Veinward; Drava Flintshoulder,
    Ombali Ropekeeper, Iven Lastshift) offers "What a Seal Allows" or "Whose Word Is This?"; after step one in one
    capital, **another capital's leader** of the faction offers it too, and its text reads right without that
    capital's step one. The map crosshair marks the town place: Highcourt the dispatch yard beside the butcher's,
    Dur Brannoc the ore yard's loading apron, Lethariel the timber check beside the bowyer's, Gor Drazhak the water
    depot on the cook court's outer rim, Kezamba the witness landing beside the shore store, Nhal Veyr the receiving
    court outside the mourners' hall. The object stands there (the dispatch record in The Accord's capitals, the
    witness record in The Throng's), only for players who need it; "Secure the dispatch record at Highcourt" (or the
    witness record) in the log and the HUD; the 3 s hold counts; at the leader the completion text decides the case
    (an Accord seal, a Throng public strike), with the choice of 2 Healing or 2 Mana Potion II. **Judge (Nhal Veyr):**
    does the place read as outside the mourners' hall?
45. **The guild reports** (`guild_t2_report_*`) still turn in at the same leaders, next to their new quest.
46. **The four objects** (STORYART): look and size on the ground, desktop and web: the dispatch record (a trestle
    board, 1.1) at the Copperfell and Goldmead camps and the Accord capitals, the witness record (two bound tablets,
    1.2) at the Mournfen name rest and the Throng capitals, the held supplies (packs behind a rope cross, 1.3) at the
    Redtusk and Raincall camps, the snare bundle (a hemp rope loop and peg, 1.2) in the Lower Boughs.
47. **Web:** the quest log's zone line, a choice reward's dialog (the picked tooltip without scrolling) and the
    objects at the web size.
48. **The pages for the user** (outside the game, private claude.ai pages): the
    [chapter pick page](https://claude.ai/artifact/VrSxVPMooAkhRtwQJUDU7D), the
    [QUESTMAP](https://claude.ai/artifact/QSu4jpSBQxWNRYshy1ey4B) of the band and chapter 1, the
    [art pick page](https://claude.ai/artifact/Qbb8qiKghobZsXBXExq266) and the
    [text pick page](https://claude.ai/artifact/Q2gFdXALsF9s3qCycvVrax).

**(C) Round 57 item 16, the bays:** in a new world with the "test" seed (or the reset "test" world).

### Round-end gates

Lane D on its branch from `8f84be22` (measured): `check_upgrade.py` PASS (against origin/main `69481ed1`, 0.57.0,
with the `map_reset` entry 0.59.0; it also passes without that entry, since unpushed 0.58.0's covers every change
against 0.57.0), `check_fresh_server.py` PASS, `validate.py --game` 0 errors (6 warnings, as before),
`quest_kinds.py --check` 0 differ, `quest_targets.py` 0 missing (1,094 targets on seeds 42, 7, 2026), `income.py
--check` PASS, `r37_dc` PASS (766 checks), `tools/r59_bandquests/build_structure.py --check` and
`tools/r59_storyquests/build_structure.py --check` 0 of 6 differ, `tools/r58_guildquests/build_structure.py --check
--ids` 0 of 26 differ, `tools/r59_storyart/paint_art.py --check` OK (4 textures), a link and anchor check of every
touched file, the full `run_fixtures.sh` (**272 passed, 0 failed**), the **full seed fleet on main** `8f84be22`
(`seed_fleet/run.sh full` through the queue at 8 parallel: **304 of 304 seeds build, 0 failed, 20 min 8 s**) and one
headless boot (PASS, no ERROR line). Each code lane ran the full `run_fixtures.sh` once (QSYS3 270/0, BANDQUESTS
271/0, STORYQUESTS 268 with three pins fixed then 272/0 after its rebase, STORYART-SHIP 272/0).
