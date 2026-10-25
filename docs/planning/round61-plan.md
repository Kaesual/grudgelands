# Round 61 — the story arc's third chapter and the quest rework of levels 31–40 (0.61.0, map reset)

Coordinator: Claude, 2026-10-25. Status: **draft**; the plan review (`r61/reports/plan-review.md`: 2 blockers, 5 important, 8 minor) is folded in, the user's answers are in §2a.

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
- **GUI checklist** (D, draft): a level-31 character of each faction finds the band's quests at once; shared quests in
  each zone's voice; the reward choices at tier 4; chapter 3 from 34/35 (Toren / Drek, the cargo place, the named
  foreman), ~39 (A6/T5 after the raid, pointing to the Warmaster); a group leader with a group, and the band played solo without it; the fortress calls and the main line at 41
  still offered.

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
