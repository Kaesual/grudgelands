# Round 61 — the story arc's third chapter and the quest rework of levels 31–40 (0.61.0, map reset)

Coordinator: Claude, 2026-10-25. Status: **complete** ([completion](#completion-2026-10-25)); 0.61.0 not pushed, it
waits for the user's joint GUI test of 0.57.0 to 0.61.0
([checklist](round60-plan.md#gui-checklist-rounds-57-58-59-60-61-the-ui-and-0611)). The plan review
(`r61/reports/plan-review.md`: 2 blockers, 5 important, 8 minor) is folded in, the user's answers are in §2a.

Round 61 continues the **quest rework of levels 11–60** band by band on the Round 57 quest system (Round 59 did 11–20,
Round 60 21–30 and the capitals) and builds the **third chapter of the story arc**. This round is the band **31–40**:
the six contested zones Stormvault Heights, Ashenward March, Glassroot Wilds (The Accord) and Blackwind Rise,
Bannerbreak Mesa, Thunderroot Wilds (The Throng). The front 41–60 (14 files, 108 quests, the Round 36 main line) is
**Round 62**, the last quest round (the user, 2026-10-25: two rounds, not one). The pattern is Round 60's: Astra drafts
the chapter with variants at its open points, the user picks on a page, a feasibility check runs beside it, then Opus
builds the structure with placeholder texts; the user sees one QUESTMAP; then art, texts, a text review, docs.

Start state: main `1878c103` (0.60.1, compatible: the merged UI modernization), not pushed (origin/main is 0.57.0).
The user's joint GUI test of 0.57–0.60.1 (`round60-plan.md` "GUI checklist") runs in parallel and may send fixes.

Inputs:
- the Round 57 quest rulings (Round 57 plan §2, rulings 9–18), the system (`docs/design/quests.md`), Round 60's plan,
  completion and lessons (`round60-plan.md`, `~/projects/grudgelands-orchestration/r61/HANDOVER.md`);
- the story arc: `r57/reports/storyarc2-report.md` §3 "Level 31–40" and "Level 40–41", §6; `r60/reports/chapter2-draft.md`
  (A4's and T3's outlooks); the front story (`docs/design/story.md` §2a, `docs/planning/round36/story-bible.md` §1–2);
- the survey `~/projects/grudgelands-orchestration/r61/reports/survey-quests-31-40.md` (facts with file:line, the
  validator dry run, the pins, the ledger, the places, the rewards, the herbs);
- player feedback (BACKLOG ~96-101): fewer mob names, more objective variety (the band is 68 % kill today, 8–10 mob
  names per zone).

## 1. Lanes and waves

| Wave | Lane | Who | Goal (one line) | Waits for |
|---|---|---|---|---|
| 0 | CHAPTER3 | Astra | The story chapter for levels 31–40: the six zones' local threads, A5/A6 and T4/T5, the places and objects, the hand-off to the front at 41; two variants at each open point | the user's go |
| 0 | CHECK3 | Opus | A feasibility check of CHAPTER3's draft against the data and the system | CHAPTER3 |
| 1 | BANDQUESTS | Opus | The six band files rebuilt (their 31–40 part) and flagged `reworked`, the 15 main-line quests marked `story`, chapter 3, placeholder texts; their spawn files; the Ashenward and Bannerbreak foremen's titles; the QUESTMAP | the user's chapter picks |
| 1 | STORYART | Astra | Art for new use objects or quest items, if the picks add any (two proposals, a pick page) | the user's QUESTMAP verdict |
| 2 | BANDTEXT | Astra | The texts of the lane's quests (and T3's one outlook sentence, §2 point 3) | the user's QUESTMAP verdict |
| 2 | TEXTREVIEW | Opus | Text review with a suggestion page; the user picks | BANDTEXT |
| 3 | D | Opus | Docs, CHANGELOG, version 0.61.0 with the map-reset declaration, STATUS, the GUI checklist | everything else |

Every non-trivial lane gets an independent Opus review and a delta review for every logic fix (the coordinator may
check text-, display- and data-only deltas). Art ships only after the user's pick (a STORYART-SHIP step as in Round 60).

**Why one band lane:** 75 quests in six files (Round 60: 84 in eight); the shared quests span both factions' zones.
No capital or herb lane: the capitals are done (Round 60), and the 31–40 herbs grow on each faction's half (survey §9).

## 2. Rulings

Carried over unchanged from Round 57 §2 (rulings 9–18), Round 59 §2 and Round 60 §2 for every reworked file: as few
quests as possible without losing depth; a task that is the same in several zones is one shared quest with a variant
per zone (one level, one title, every giver on the same line); free play (a free quest requires only a level, at most
one follow-up per faction, no repeatables, night counts about a third of the day count); story quests marked `story`,
may chain, completion texts; choice rewards and the per-zone budget; more objective variety and fewer mob names per
zone (Rounds 59/60: about three); profession-gated items only where the profession is the point (Crimson Lotus in
Glassroot and Thunderroot, Dragonweed in Ashenward and Bannerbreak); use objects away from mob members; quest-only
items soulbound; map reset is fine.

New for this round:
1. **The contested base files** (`elandor_ashenward_march`, `kragmar_bannerbreak_mesa`) are flagged whole (§2a point
   1): their 31–40 part is reworked; their 15 main-line quests (41–60) keep ids, objectives, levels, `requires`, lines
   and home and are only marked `story` (the survey's dry run: 27 → 12 errors in these two files; the 12 are the 31–40
   part's). Their texts are Round 62's. The two `.front` files and the other twelve front files stay unflagged.
2. **Chapter 3** follows the arc drafts and the user's picks on the CHAPTER3 page. Known from the survey (§4):
   - **A5** (34, Toren → a raided cargo place in Ashenward → the Ashenward camp's foreman; requires A4 and the free
     Scrip quest `ashenward_rations_03`, min 32); **A6** (~39, the foremen of the three Accord zones → Nella; requires
     A5 and the free camp raid, §2a point 5); A6's completion points to the Ashenward Warmaster.
   - **T4** (35, Drek → a raided cargo place on Bannerbreak → the Bannerbreak camp's foreman; requires T3 and the free
     Rattle quest `bannerbreak_ramp_03`); **T5** (~39, the three Throng foremen → Yarra; requires T4 and the free camp
     raid); T5's completion points to the Bannerbreak Warmaster.
   - Rattle's quest opens at min 34 with reward level 36 today, and the leader is level 37 (`subtypes.json`): the
     quest moves to min ≤ 34 with a reward level ≤ 35 and the leader's level drops to match, so T4 never waits on a
     higher free quest (`names.json` is regenerated, or the load stops; BANDQUESTS owns both files).
   - Scrip, Rattle and `bannerbreak_standard_04` lose their own prerequisites (a free quest requires only a level).
   - The free quests whose one follow-up a story quest takes (Scrip, Rattle and the camp raid, §2a point 5) keep their ids (as Round 60 §3 "cross-lane slots"), and the drafts' unchaining holds:
     `ashenward_road_stormvault/glassroot/last_hedge` and `bannerbreak_standard_group` lose their prerequisites.
   - **No A7/T6** (§2a point 5): the drafts' A7/T6 would be the same travel as the free fortress calls
     (`ashenward_bastion_call`, `bannerbreak_warhold_call`: Nella / Yarra → the Warmaster, min 40), which stay free entry
     quests on line `front`, untagged (pin `r31_q` ~391-432) and carry the player to the Warmaster. The chapter has two
     steps per faction five levels apart, as chapter 2 (24 → 29). The front's main line at 41 is untouched (Round 62
     decides whether it requires A6/T5).
   - Odren Vell and Tallykeeper Mardra stay text-only (the front's people, Round 36).
3. **T3's outlook names Drek:** the shipped completion of `story_throng_04` (`kragmar_nhal_veyr`) names only
   "Bannerbreak Mesa", while A4's names Toren at Cinderline Watch; one sentence in BANDTEXT, data otherwise unchanged.
4. **Rewards at item level 31–40** on the Round 60 pattern: T4 materials (Silversteel / Silkweave / Hardened, key
   `scaled`), enchant tier 4; per zone an early consumable choice (Healing or Mana Potion IV need level 31:
   `grug_alchemy/effects.lua` ~1), two armor pieces with one enchant, a weapon with prefix and suffix on a late **solo** quest of the
   zone (§2 point 8; in Ashenward and Bannerbreak Scrip's and Rattle's quests); each faction's three zones give six armor pieces for four slots (every slot at least once, two slots twice,
   the lane picks which); the budget rule passes.
5. **Places:** spawn-file recipe places (`farthest_from_roads`, 64 nodes from other places, leaders and camps; the
   level belts are 31–33, 34–37 and 38–40) and the camps' `held_load`
   sockets are both available; a new recipe place in Glassroot, Stormvault, Blackwind or Thunderroot moves the pin
   `r36_q0` ~262-269 (one place each today); a new object kind moves `r36_q0` ~259 (20 kinds) and needs art. Reusing a
   Round 59/60 object kind (`dispatch_record`, `held_supplies`, …) needs neither. No new givers unless a pick needs one
   (a new giver is a blueprint socket). New quest ids never start with `camp_` or `guild_` (the r58 generator's
   prefixes). A shared quest given by hosts uses one common line name across those hosts.
6. **The camp content stays as Round 58 shipped it:** the T4 camp hunts (`camp_hunt_t4`, `_night`), the raid
   `camp_site_raid` (§2a point 5), `guild_t4_report_*`, the foreman hubs; no zone quest kills a
   camp hunt's role in its zone (pin `r58_guildquests` ~303: Stormhorn Ram, Ashwolf, Rootantler, Muster Husk by day;
   Pall Weaver, Shade Panther in Thunderroot at night). `guild_t4_silver` / `_sapphire` stay in `charter_of_stone`.
7. **The hand-off at 40:** every zone's last quests lead toward the front. Only Ashenward's and Bannerbreak's hosts
   offer front quests from 40 (`cinderline_front_01/02`, `lasthedge_front_01`, `bb_front_ramp_01`, `bb_front_torn_01/02`,
   the fortress calls). Stormvault's front starts at 44 (Alna) and 50 (Borin), Blackwind's at 46 (Orrel) and 53 (Vaska),
   and Glassroot's and Thunderroot's hosts have no `front` line: these four zones end with a free departure at 40 to a
   40-level front host in Ashenward or Bannerbreak (plan review B1). The 10 host NPC ids, every host's `front`
   line, the Warmasters' second lines (`main`, `oaths`) and the fortress hubs stay (front files give and talk through
   them).
8. **Elite group quests below level 51 are always optional** (the user, 2026-10-25: the player base is small, a
   partner of the same level online at the same time is rare; from 51 a max-level helper is easier to find). Below 51 a
   `group` quest is free, standalone (requires nothing, required by nothing, never on the story path, no travel or
   departure needs it) and never carries a zone's only key reward (the zone's weapon is on a solo quest; the group
   quest gives an extra, e.g. a tier-4 trinket choice). The questing share is met without it (the solo ledger skips
   group quests, `ledger.py` ~272). From 51 group quests may stand on the story path. Measured today (2026-10-25): no
   group quest below 39; the six at 39 (this band) and the four at 50 (`lasthedge_front_05`, `archshadow_front_04`,
   `bb_front_torn_06`, `bw_front_hollow_03`) are free and required by nothing; at 59–60 ten, two of them on the main
   line (`accord_main_collector`, `throng_main_finale`). D adds the rule to `docs/design/quests.md`.

## 2a. Decided and open (the user, 2026-10-25)

Decided (the survey's questions 1, 2, 4 and 9, HANDOVER):
1. **The contested files** are flagged whole, their 15 main-line quests marked `story` (§2 point 1).
2. **Questing share 30→40: about 55–60 %** is fine (the survey estimates 57–62 % under the pattern); no XP bump.
3. **One elite "Party" quest per zone, folded into the zone's leader:** the zone's normal and elite leader become
   one, the elite, as an optional group quest at ~39 (§2 point 8: standalone, an extra reward, not the weapon).
4. **The Ashenward and Bannerbreak foremen get names** through per-camp titles (`grug_quests/npcs.lua`
   `FOREMAN_TITLES`, mirrored in `r28common.py`; as Brodd and Rellis in Round 60); CHAPTER3 proposes the names.

Decided on the coordinator's recommendations (the user, 2026-10-25, after the plan review):
5. **A6/T5 follow the free camp raid at ~39, no A7/T6** (survey §4, question 6, option (c); plan review B2 and I3):
   the raid `camp_site_raid` stays free and as Round 58 shipped it (min 36, reward level 40, the camp sites in the
   38–40 belt); A6/T5 at ~39 require A5/T4 and the raid: the foreman sends the player with the raid's result to Nella
   / Yarra (the raid's one follow-up per faction is A6/T5), whose completion points to the Warmaster; the free fortress
   call is the travel there. Rejected: the raid as the two story quests (no longer free play; r58 pins :123,
   :311-334, :659 and `--ids` break); A6/T5 killing the same garrison again; A6/T5 at 36 without the raid with the
   fortress calls turned into story quests A7/T6 (free players would lose the call).
6. **Scrip and Rattle stay solo** and carry their zone's weapon: both are the chapter's free prerequisites (A5, T4);
   they stay normal leaders at 32–34, and Ashenward's and Bannerbreak's elite at ~39 (Red-Receipt, Banner-Eater, or
   one CHAPTER3 picks) is the zone's one optional group quest (§2 point 8).
7. **The zone's weapon on a solo quest** (plan review I5b; the user: elite group quests stay optional before 51, §2
   point 8).

Decided by the coordinator (the survey's questions 3, 5, 7, 8, 10–12; the plan review may object):
- **Zone size** follows the ledger (~55–60 %), not a count; no new givers (survey question 3).
- **Chapter shape** as drafted up to A6/T5 (§2 point 2), Drek named (§2 point 3).
- **A5/T4's place:** CHAPTER3 proposes; a recipe place in the zone's 34–37 belt (the camps' `held_load` is the turn-in
  foreman's own camp, the clash sites 072/073 stand in the 38–40 belt). The round is a map reset anyway (§3).
- **Shared quests:** the bandit-camp archers in all six zones, the apes and bears, the siege goblins, Bitter Resin as
  the survey lists them; the camp hunts' roles stay off-limits (§2 point 6).
- **Reward slots** chosen by the lane (§2 point 4); **exits at 40** as §2 point 7.

## 3. Shared conventions

- **Upgrade classification: map reset** (one `map_reset` entry for 0.61.0, by D, its reason taken from the merged diff): the changed `quest_target` flags in
  the six band spawn files (every kill objective that goes) and any new recipe place change what world generation
  builds. Characters keep items, levels, quests and money; quests whose ids vanish are dropped (upgrade contract §4);
  new ids for every reworked quest whose objectives change, except the cross-lane slots (§2 point 2).
- **Quest text rules** as in Rounds 57, 59 and 60.
- **Generator:** `tools/r61_bandquests/build_structure.py` writes the structure once with `[PH]` texts (the main
  line's texts are kept, not replaced); its `--check` compares structure only, never texts.
- **Fixtures:** `tools/r61_bandquests/portable_test.lua`, text-agnostic. The pins the survey §6 lists move with a
  one-line reason each: `r46_xp` ~266/274 (48 files / 403 quests) and ~277-281 (hub lines used); `r45_st` ~1087 (97 item
  objectives); `r32_f2` ~782 (`kills >= 215`; the Round 60 pattern drops about 28); `r58_guildquests` ~378-386 (the
  camp zones unflagged; all 20 camp zones flagged after this round), ~123, ~118 (`--ids`), ~193-226, ~249-303,
  ~311-334, ~659-664 (the raid unchanged, §2a point 5; A6/T5's `requires` on it must not trip them); `r60_bandquests` ~345-348 and `tools/r60_capitals` (departures to
  the host ids, kept), `r60_bandquests` ~284-296 (a probe with A5 requiring A4 fails it); `r36_qa` ~49-51, ~66-72, ~169-178 and `r36_qt` ~68-75, ~134-147 (the main line: kept, a `story`
  tag must not break them); `r36_q0` ~259, ~262-269 (§2 point 5); `r31_q` ~391-432 (§2 point 2); the foreman titles:
  `r58_campnpc`, `r60_capitals` ~129 and ~499-506 (`r28common.py` reads the titles by regex, no edit); `seed_fleet` (places on every seed); `quest_kinds.py --check`, then
  `tools/r28_regions/run.sh`, `quest_targets.py`, `guarantee.py --check`, `r38_names/check_rules.py --shipped` when
  mob names or leaders change.
- **Leaders no quest hunts any more** (the four zones whose normal and elite leader become one, §2a point 3) leave
  their spawn files with their `subtypes.json` and `names.json` rows and `quest_target` flags (as every reworked zone
  keeps only the leaders its quests hunt; BANDQUESTS).
- **Potion IV rewards** sit only on quests with min level ≥ 31 (usable from 31).
- **Owners:** BANDQUESTS the six band files, their spawn files (places, flags), the camp blueprint if a socket is
  needed, `grug_quests/npcs.lua` (the foreman titles only), its rows in `use_objects.json` and `items.json`, the
  QUESTMAP; BANDTEXT additionally T3's completion sentence in `kragmar_nhal_veyr`. New givers in the quest file
  (`"new": {...}`); `validate.py` reads NPC factions from `existing.json` (rerun `dump_items.sh` for a new NPC id).
- **Main-line quest drops:** the Captain's Orders (`throng_main_04` and its Accord counterpart) are the front's and
  stay as shipped.

## 4. Lane goals (briefs add file facts)

**CHAPTER3 (Astra).** From the drafts, A4's and T3's outlooks and the front story at 41: for each faction the
chapter's story across the three band zones at 31–40: the local threads the zones carry as free quests (the zones'
leaders, Scrip, Rattle; the hosts Borin, Alna, Toren, Nella, Faeris; Vaska, Orrel, Drek, Yarra, Rumela), A5/A6 and
T4/T5 (§2 point 2), A6/T5 after the free raid (§2a point 5), the optional group quests (§2 point 8), A5/T4's place and object, the Ashenward and
Bannerbreak foremen's names, the hand-off to the Warmasters and the front's main line (Vell, Mardra, the branded pay,
the false requisition: as hints, not new people). No vanishing NPCs. Two variants at each open point (K-points with a
recommendation); a short list of what the structure needs. German report.

**CHECK3 (Opus, read-only).** The draft against the data and the system: every named NPC, place and object exists or
is listed as new; the free/story rules; levels (Rattle ≤ T4); profession-gated items; the pins it would move; what is
expensive. The coordinator folds in plain fixes.

**BANDQUESTS (Opus).**
- The six band files' 31–40 part rebuilt and all six flagged `reworked`; the 15 main-line quests marked `story` and
  otherwise unchanged; shared quests where the task repeats (survey §1); local quests for the zone's story; one optional
  group leader per zone (§2 point 8, §2a points 3, 6, 7; the four dropped leaders, §3); counts before and after; zone size by the ledger 30→40 (~55–60 %); objective
  variety (use, item, talk; the band 21–30 reached 17–27 % kill) and about three mob names per zone.
- Chapter 3 (§2 point 2, the picks), Rattle's level, the unchaining, the cross-lane ids kept; the foreman titles.
- Places and objects from the picks; rewards (§2 point 4); the ledger 30→40 before and after
  (`ledger.py --game --track <race> --party solo`); `quest_kinds.py --check` (rerun after the rework, then
  `tools/r28_regions/run.sh`), `guarantee.py --check`, `quest_targets.py`, `validate.py --game` (0 errors), the seed
  fleet `quick` if a place or socket is added.
- Placeholder texts; the QUESTMAP page (Round 60's `tools/r60_capitals/questmap.py` as the template).

**STORYART (Astra).** Only if the picks add an object kind or a quest item: two proposals, a pick page (Round 60
drop 02 shows the style).

**BANDTEXT (Astra) and TEXTREVIEW (Opus).** As in Round 60, for the lane's 31–40 quests and chapter 3; the main
line's texts stay; T3's sentence (§2 point 3).

**D.** Version 0.61.0 with the map-reset entry; CHANGELOG, STATUS, ROADMAP (Round 62 = the front), BACKLOG, AGENTS;
the completion section; the GUI checklist (a level-31 character of each faction through the band, chapter 3 at 34/35
and ~39, the optional group quests (§2 point 8, in `quests.md`), the foremen's names); a full seed fleet at the round's end if a placement or blueprint change
merged.

## 5. Rules

The usual ones ([round workflow](../process/round-workflow.md)): one worktree and branch per lane; an independent Opus
review per non-trivial lane and a delta review for logic fixes; the Lua queue at most 8 at once; no pushes, merges or
syncs by lanes; nothing unpicked ships. Fixtures: each lane runs only its own fixture plus the fixtures that test the
behaviour it changes, and the full run once before its report.

## 6. Verification

- **Gates:** the full fixtures, `check_fresh_server.py`, `check_upgrade.py` (with the map-reset entry),
  `validate.py --game` (0 errors with the six files flagged, 34 files in all), `quest_kinds.py --check`,
  `tools/r28_regions/run.sh`, `quest_targets.py`, `guarantee.py --check`, `r38_names/check_rules.py --shipped`,
  `income.py --check`, the seed fleet as above,
  one boot per lane.
- **GUI checklist:** Round 61's items are part of the joint checklist of 0.57 to 0.61,
  [Round 60's list](round60-plan.md#gui-checklist-rounds-57-58-59-60-61-the-ui-and-0611) item 8 in (A) and items 82–96 in
  (B); the draft here (a level-31 character of each faction through the band, chapter 3 at 34/35 and 39/40, a group
  leader with a group and the band solo without it, the fortress calls and the main line at 41) is folded in there.

## 7. Orchestration notes

- **Order:** CHAPTER3; CHECK3 after it; the user's picks and the §2a answers; BANDQUESTS; the QUESTMAP verdict;
  STORYART (if needed) and BANDTEXT from main → TEXTREVIEW; D last.
- **The GUI test of 0.57–0.60.1** runs in parallel; a fix it needs becomes a small FIX lane that merges first.

## 8. Engine and code facts (from the survey; re-check in the briefs)

- Zones: `wp40/source/simple_map.lua` rows :68 (stormvault, 5), :73 (ashenward, 10), :79 (glassroot, 16), :84
  (blackwind, 21), :89 (bannerbreak, 26), :95 (thunderroot, 32); all `contested_land`.
- 75 quests (60 at 31–40, 15 main line); band objectives 46 kill / 7 item / 15 talk / 0 use; six Party quests at 39.
- Dry run flagged: 52 errors (27 in the contested files); with the 15 main-line quests marked `story` 37 (12 in the contested files, all in their 31–40 part; plan review).
- Givers: 10 hosts on `quest_host` (`npcs.lua` ~13-29), the fortress givers 40+ only (`npcs.lua` ~93-102), the six
  foremen (`npcs.lua` ~152-159); hubs 2 givers, 2 lines each (`validate.lua` ~20-21).
- Free places without a new socket: the six camps' `held_load`, the clash sites 072 Hedgefire Crossing and 073 Redcut
  Breach (38–40 belt); the four main-line recipe places (one each in glassroot, stormvault, blackwind, thunderroot).
- Ledger 30→40 solo today: questing share 76–86 % (from level 1) / 70–78 % (from 30).
- Herbs: Crimson Lotus (Glassroot, Thunderroot), Dragonweed (Ashenward, Bannerbreak), both Alchemy-gated; ungated
  errands: Corn, Melon, Mushroom, Potato, sugar cane, bamboo, Cave Cap, Frostfin; Stormvault grows no catalogue food
  plant.

## 9. Later

Round 62: the front 41–60 (14 files, 108 quests, the Round 36 main line, the fortresses); then the production deploy
with one map reset; then the armor redesign and the unique items.

## Completion (2026-10-25)

Every lane is merged on main, the code lane BANDQUESTS independently reviewed (Opus) and every fix checked: its fix
round and the text picks were data or text only and checked by the coordinator; this lane D (the version, the
declaration, this section, AGENTS, the status owners, the joint GUI checklist) follows on main `1a5aae56`. **0.61.0 is
a map reset:** no migration step; characters keep their items, levels, quests and money; a quest whose id vanished is
dropped (upgrade contract §4); item, achievement and waypoint ids unchanged; no new position in player meta. **Push:**
not pushed; 0.57.0 was pushed on 2026-10-23 without its GUI test, and 0.58.0 to 0.61.0 wait for the user's joint GUI
test. **Sync:** by the coordinator after every merge.

### Lanes

Worktrees and branches `r61-<lane>`. Main's first-parent commits, in order (lane tip in brackets):

| Lane | Commit | What | Review |
|---|---|---|---|
| SURVEY | outside the repository | the survey of the band 31–40 (`r61/reports/survey-quests-31-40.md`: 75 quests, the validator dry run, the pins, the ledger, the places, the rewards, the herbs, 12 questions) | the user's answers (§2a points 1–4) |
| plan | `c3861491` | this plan with the plan review folded in (B1, B2, I1–I5, M1–M8) and the user's answers (§2a), the group-quest rule (§2 point 8) | fresh Opus plan review (2 blockers, 5 important, 8 minor) |
| CHAPTER3 | outside the repository | GPT-6 Astra's draft of chapter 3 (`r61/reports/chapter3-draft.md`, German): the six zones' local threads, A5/A6 and T4/T5, the foremen's names, six new places, four `held_load` uses, the new object `storm_vessel`, the quest item Runner's Packet, the host line `border`, open points K1–K13 with two variants each | CHECK3 (Opus, read-only, `chapter3-check.md`): ready after two fixes (T3's sentence, one Rattle level) |
| BANDQUESTS | `309732f9` (`45dec70d`) | the six band files' 31–40 part rebuilt and all six flagged `reworked`, the 15 main-line steps marked `story` (`tools/r61_bandquests/build_structure.py`, fixture, `questmap.py`); chapter 3 (A5, A6, T4, T5); two foremen-title rows (`grug_quests/npcs.lua`); the Runner's Packet (`items.json` kind `quest`) and `storm_vessel` (`use_objects.json`) as placeholders; six recipe places, four leaders dropped, Rattle's level, the `quest_target` flags and the six zones' 36 region maps (six seeds each); the r58 generator's `KEPT_HUNTS` | MERGE AFTER FIXES (Medium: 4 armor pieces per faction, not 6; Low: Rattle's kept id with changed objectives; Low: no fixture for A6/T5's offers); the fix `45dec70d` (six pieces per faction, the new `glassroot_ladders`, the r28_q0 A6/T5 lines) checked by the coordinator as data and fixtures only |
| STORYART-SHIP | `62f979cd` (`38621c5a`) | the picked drop-03 P1 art (`grug_quests_obj_storm_vessel.png`, size 1.2; `grug_mobs_runners_packet.png`), the rows, `tools/r61_storyart` (`drop03.py`, `paint_art.py --check`), `LICENSE-media.md` "Round 61" | checked by the coordinator (PNGs byte-identical to the picks, the rows, no code) |
| BANDTEXT, TEXTREVIEW | `1a5aae56` (`1f1b52ad`) | GPT-6 Astra wrote the 121 text fields of the six band files (`99ab9980`: 45 titles, 66 texts, 10 completions), T3's outlook sentence in `kragmar_nhal_veyr` and Stormvault's `identity`; the user's seven text picks and the two storm-vessel notes that still said placeholder, applied by the coordinator's script (`1f1b52ad`) | TEXTREVIEW (Opus): 0 must-fix, 7 proposals, all picked; `1f1b52ad` (text and notes only) checked by the coordinator |
| D | this section | the version 0.61.0 and the `map_reset` entry, upgrade contract §2, AGENTS, STATUS, CHANGELOG, BACKLOG, ROADMAP, README, the group-quest rule in `quests.md`, the docs check, the joint GUI checklist | independent review |

**STORYART** (GPT-6 Astra, outside the repository): story art drop 03 (the storm vessel and the Runner's Packet icon,
two proposals each, `story-art/art/drop-03`); the user's picks are below. Nothing unpicked ships.

Main has 277 portable fixtures (1 new: `r61_bandquests`). `mods/` against 0.60.1 (measured, `git diff 1878c103
1a5aae56 -- mods`): 23 files, +1,566 −1,092 lines: the seven quest files (the six band files and T3's sentence in
Nhal Veyr's), six spawn files, `subtypes.json`, `names.json`, `items.json`, `use_objects.json`, the two textures and
their `LICENSE-media.md` rows, the camp blueprint's comment and the title rows in `grug_quests/npcs.lua`.

### Decisions during the round

**The user** (HANDOVER):

- **Two rounds, not one:** Round 61 the band 31–40 and chapter 3, Round 62 the front 41–60 (the last quest round).
- **§2a points 1–4** (the survey): the contested files flagged whole, their main line marked `story`; a questing share
  of 30→40 of about 55–60 % is fine; one elite "Party" quest per zone folded into the zone's leader; the Ashenward and
  Bannerbreak foremen named by a per-camp title.
- **§2a points 5–7** (the plan review, on the coordinator's recommendations): A6/T5 follow the free camp raid at ~39,
  no A7/T6; Scrip and Rattle stay solo and carry their zone's weapon; the zone's weapon on a solo quest.
- **The group-quest rule** (§2 point 8): elite group quests below level 51 are always optional; from 51 they may stand
  on the story path ([quests.md](../design/quests.md#group-quests-round-61)).
- **The chapter-3 picks K1–K13: all "A"** (no notes): among them T5 at 40 (K1), the Broken Load and the Scattered Load
  (K4–K6), the storm vessel (K9), the Runner's Packet (K10), Audra Wainholt and Greda Stonehaul (K12, K13).
- **QUESTMAP:** accepted ("passt so").
- **The art picks** (`story-art/pick/picks.md`, Round 61, drop 03): both P1: the storm vessel (a clay crock in a
  wooden holder, size 1.2) and the Runner's Packet (a flat strapped envelope).
- **The texts:** all seven proposals of the text review (A Soldier's Due's doubled location, Rattle's and Borin's
  garbled clauses, Audra's A6 line, Rumela's Packet line, Faeris's ladders text, Alna's Emberglass text).

**The coordinator** (answers to lane questions and the check; each built as stated):

- **CHECK3's fixes, taken into the briefs:** T3's sentence without a second "on Bannerbreak Mesa"; Rattle's quest at
  minimum 34 with reward level 35 and the leader at 35; one drop area per variant for the Runner's Packet;
  `r60_bandquests`' `ALLOWED_FOLLOWERS` with A5.
- **BANDQUESTS' Q1 accepted:** Blackwind's hideout archers (Shroud Archer, L36–37) are named like the camp's archers
  and drop the Packet too (drops count by the name; the quest opens at 38, so they are only an easier source).
- **Rattle's kept id accepted** (review finding 2): an active `bannerbreak_ramp_03` saved before 0.61.0 keeps its
  per-objective progress and may read ready without Rattle's kill; one production world, declared by D
  ([classification](#classification)).
- **BANDQUESTS' Q2 answered by the review's fix** (six armor pieces per faction, plan §2 point 4).
- **The data-only fixes** (BANDQUESTS' fix round, the text picks and the two placeholder notes) checked by the
  coordinator; no logic changed in them.

### Deviations from the plan

- **No A7/T6** after the plan review (§2a point 5): the free fortress calls carry the player to the Warmaster.
- **The shared quests:** the survey's shared ape, bear, goblin and Bitter Resin quests (§2a, "Shared quests") were
  dropped by the draft; the five shared quests are errands, a drop and a use (`border_meal`, `border_melons`,
  `border_stores`, `border_packets`, `border_reserve`), all on the hosts' new line `border`.
- **Four leaders dropped** (§3): Bolt-Chewer, Basket-Biter, Grave-Broker Mute and Bottle-Keeper Zek left their spawn
  files, `subtypes.json` and `names.json`; the six elite leaders stay as the Party quests.
- **T5 at 40, not ~39** (K1 "A"): A6 at 39, T5 at 40, shown locked at 39.
- **The armor:** the first build gave 4 pieces per faction; the fix round moved the Packet's reward to potions, put
  armor on four quests that paid none and added `glassroot_ladders` (Faeris, 10 Wooden Ladders, level 34) for the
  Accord's sixth piece; Toren's buckets moved to 31 and his travels to 30.
- **The r58 camp hunt generator** would have re-picked every T4 hunt once the band changed its kinds; BANDQUESTS
  pinned the shipped ones (`KEPT_HUNTS`, as Round 60).
- **`check_upgrade.py` passed in every lane** (the plan expected a failure until D): unpushed 0.58.0's entry covers
  every change against pushed 0.57.0; D declares 0.61.0's reset all the same.
- **The validator's warnings** grew from 6 to 11: five new `W-night-count` on content whose counts are fixed (the
  shipped main line and `camp_hunt_t4_night`).
- **T3's completion has four sentences** (the rule says 1–3): the mandated wording of §2 point 3.
- **STORYART-SHIP** was added as in Rounds 59 and 60; the two storm-vessel notes that still said placeholder were
  fixed by the coordinator with the text picks.

### Numbers worth keeping

Measured unless marked "report" (taken from the lane's report).

- **Quests:** the six band files' quests of reward level 31–40, 60 → 50 (measured over the files at `c3861491` and
  `1a5aae56`; the 15 main-line steps unchanged but for `story`); **393 shipped** in 48 quest files (403 − 60 + 50), 34
  of them flagged `reworked`; 31 ids dropped, 21 added, 29 kept (one with changed objectives: Rattle's
  `bannerbreak_ramp_03`). Offered per zone (report, shared and camp or guild variants included, before → after):
  Stormvault 15 → 15, Ashenward 16 → 16, Glassroot 14 → 14 (13 before the fix round's ladders), Blackwind 13 → 15,
  Bannerbreak 13 → 15, Thunderroot 14 → 14.
- **Objectives** (per quest, a shared quest counted once): kill 46 → 13, item 7 → 10, talk 15 → 19, use 0 → 9, so the
  kill share 68 % → 25 %. Per zone (report, counting each zone's variants with the camp quests): Stormvault 56 → 25 %,
  Ashenward 61 → 29 %, Glassroot 60 → 29 %, Blackwind 62 → 25 %, Bannerbreak 62 → 38 %, Thunderroot 65 → 27 %.
- **Mob names per zone** (report, besides the raid's garrison): Stormvault 8 → 3, Ashenward 9 → 4, Glassroot 7 → 3,
  Blackwind 8 → 3, Bannerbreak 9 → 5, Thunderroot 8 → 3; the Packet's archers Waylayer, Hedge Bowman, Bandit Fletcher,
  Shroud Archer, Trench Archer and Brigand Bowman (measured, `names.json`).
- **The ledger 30→40, solo** (`ledger.py --game --track <race> --party solo`, from level 1 / with `--start-level 30`,
  on main `1a5aae56`): human 62 / 61 %, dwarf 59 / 58 %, elf 58 / 57 %, undead 56 / 56 %, orc 59 / 57 %, troll 56 /
  55 %; before the round 76–86 % / 70–78 % (report, survey); the group quests are not counted.
- **Group quests** (measured over all files): none below level 39; six at 39 (this band), four at 50, ten at 59–60
  (four of them main-line steps marked `story`, two on the path to the final turn-in).
- **The armor** (measured over the files; each faction six pieces with one enchant at item levels 31–40):

  | Faction | Head | Legs | Chest | Feet |
  |---|---|---|---|---|
  | The Accord | Silversteel Bars (prefix), the ladders (suffix) | Emberglass (suffix), the buckets (suffix) | the reserve (prefix) | the Melons (prefix) |
  | The Throng | the Mushrooms (prefix) | A Soldier's Due (suffix), the reading cord (suffix) | the signal lantern (suffix), the reserve (prefix) | the Melons (prefix) |

  The weapons (one per weapon line, a prefix and a suffix): the Survey Stand (37), Scrip (33), the Carrier Path (39),
  the Recovery Rest (39), the storm vessel (39), Rattle (35). The potions IV: Frostfin, the Corn, the Chests and the
  Packet; A5 and T4 a potion choice; the six Party quests a choice of three plain tier-4 trinkets.
- **The validator:** the dry run with the six files flagged before the round found 52 errors (report, survey);
  `validate.py --game` on main: 0 errors, 11 warnings, 34 files flagged.
- **The fleet:** BANDQUESTS' `quick` fleet with the six new places, 100 of 100 seeds, 9 min 45 s at 6 parallel
  (report, `r61/reports/bandquests-fleet.txt`); this lane's full fleet: see [Round-end gates](#round-end-gates).

### Classification

**Map reset**, no step:
`{"schema": 3, "version": "0.61.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0", "0.58.0", "0.59.0", "0.60.0", "0.61.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0"], "map_reset_pass": "0.50.0"}`.
The reason ([upgrade contract §2](../technical/upgrade-contract.md#2-the-declaration)): six new quest places in the
band spawn files, four leaders removed and Rattle's level changed, and the changed `quest_target` flags change the
spawn recipes and the region maps world generation builds. A world on 0.57.0 (or 0.58.0 to 0.60.1) moves on across one
reset with the pre-reset pass: characters keep everything but their position and home claim (contract §3.2); an
active quest whose id vanished leaves the log, a kept id keeps its state.

What needs the reset and what alone would be compatible (the lanes' reports): the six recipe places, the dropped
leaders, Rattle's level and the flags change what new worlds build, and the quests that use them ride on the reset;
the quest data itself, the Runner's Packet, the storm vessel, the foremen's titles, the texts and the art alone are
compatible. Saved state, all without a position: `grug_quests:state` for the new ids (no format change); nothing new
in player meta or mod storage, so no `register_on_relocate` clear. **One known edge:** Rattle's
`bannerbreak_ramp_03` kept its id while its objectives went from [Sappers/Slingers ×4, Rattle] to [Rattle]; progress
is stored per objective position (`grug_quests/state.lua`), so an active copy saved before 0.61.0 with the old count
can read "ready" without Rattle's kill (the review's probe through the real loader). Accepted by the coordinator: one
production world, and only a character in the middle of that quest.

### Open notes

- **For the user:** the joint GUI test of 0.57 to 0.61 (Round 60's checklist, extended), with these to judge: the
  storm vessel's look and size and the Packet's icon at 16 px, the holds at the six new places and the four loading
  grounds with mobs or the camp around, the Recovery Rest where it falls back near Hollowbell (3 of 6 seeds), the six
  Party leaders with a group, the band's errands as a first version, the questing share of 30→40 (55–62 %), T3's
  four-sentence completion; Rattle's edge at the first join.
- **Round 62** reworks the front 41–60 (14 files, 108 quests, the Round 36 main line, the fortresses) and decides
  whether the main line at 41 requires A6/T5; the four group quests at 50 still follow their front chains and become
  standalone there (the group-quest rule).
- The reviews' and reports' notes are in the [Round 61 carry-overs](../../BACKLOG.md#round-61-carry-overs).

### Round-end gates

Lane D on its branch from `1a5aae56` (measured; `mods/` identical to main): `check_upgrade.py` PASS (against
origin/main `69481ed1`, 0.57.0, with the `map_reset` entry 0.61.0; it also passes without that entry, since unpushed
0.58.0's covers every change against 0.57.0), `check_fresh_server.py` PASS, `validate.py --game` 0 errors (11
warnings, as after BANDQUESTS), `quest_kinds.py --check` 0 differ (114 quest-named kinds), `quest_targets.py` 0
missing (894 targets on seeds 42, 7, 2026, CLOCK 0), `guarantee.py --check` PASS, `check_rules.py --shipped` 0
problems, `income.py --check` PASS, `r37_dc` PASS (766 checks), `tools/r61_bandquests/build_structure.py --check` 0 of
6, `tools/r60_bandquests/build_structure.py --check` 0 of 8, `tools/r60_capitals/build_structure.py --check` 0 of 6,
`tools/r59_bandquests/build_structure.py --check` and `tools/r59_storyquests/build_structure.py --check` 0 of 6,
`tools/r58_guildquests/build_structure.py --check --ids` 0 of 26, `tools/r61_storyart/paint_art.py --check` OK (2
textures), `tools/r60_storyart/paint_art.py --check` OK (7) and `tools/r59_storyart/paint_art.py --check` OK (4), a
link and anchor check of every touched file (1,145 links), the full `run_fixtures.sh` (**277 passed, 0 failed**), the
**full seed fleet on main's tree** (`seed_fleet/run.sh full` through the queue at 8 parallel, with the quest-place
check: **304 of 304 seeds build, 0 failed, 22 min 34 s**; Round 60's took 21 min 25 s) and one headless boot (PASS,
listening, no ERROR line). Each code lane ran the full `run_fixtures.sh` once (BANDQUESTS 277/277 after its fix round,
STORYART-SHIP 277/0; BANDTEXT 277/0 per Astra).
