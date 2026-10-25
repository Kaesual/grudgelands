# Round 60 — the story arc's second chapter and the quest rework of levels 21–30 (0.60.0, map reset)

Coordinator: Claude, 2026-10-24. Status: **complete** ([completion](#completion-2026-10-24)); 0.60.0 not pushed, it
waits for the user's joint GUI test of 0.57.0, 0.58.0, 0.59.0, 0.60.0 and 0.60.1 (the merged UI modernization)
([checklist](#gui-checklist-rounds-57-58-59-60-and-the-ui)); the user's go 2026-10-24. The plan review
(`r60/reports/plan-review.md`) and the user's answers (§2a) are folded in.

Round 60 continues the **quest rework of levels 11–60** band by band on the Round 57 quest system (Round 59 did
11–20) and builds the **second chapter of the story arc**. This round is the band **21–30**: the eight zones Frostbarrow
Shelf, Whitebridge Shire, Lorindor, Moonfall Wood (The Accord) and Ossuary Reach, Speargrass Reach, Whispering
Reedlands, Totemwater Reach (The Throng), plus the six capital quest files (levels 19–30), which Round 59 left
unflagged. The pattern is Round 59's: Astra drafts the chapter with variants at its open points, the user picks on a
page, a feasibility check runs beside it, and only then Opus builds the structure with placeholder texts; the user sees
one QUESTMAP; then art, texts, a text review, docs.

Start state: main `e6efbfb5` (0.59.0, map reset), not pushed (origin/main is 0.57.0). The user's joint GUI test of
0.57, 0.58 and 0.59 (`round59-plan.md` "GUI checklist") runs in parallel and may send fixes. The user's own lane
`ui-modernization` (UI only; today docs only) runs in parallel and is never touched by this round.

Inputs:
- the Round 57 quest rulings (Round 57 plan §2, rulings 9–18), the system (`docs/design/quests.md`, incl. "Town
  places", "The band 11–20", "Chapter 1 in the capitals"), Round 59's plan, completion and lessons
  (`round59-plan.md`, `~/projects/grudgelands-orchestration/r60/HANDOVER.md` "Lessons from R59");
- the story arc: `r57/reports/storyarc2-report.md` §3 "Level 21–30", §6; `r59/reports/chapter1-draft.md` §1–2, §7
  (the six mine leaders as guild members, text proposals), §9–10; the shipped chapter-1 completions point on to Frostbarrow
  Shelf and Ossuary Reach (the zones only); the chapter-1 draft (~37, ~67) names Brodd Deeppeg, Kelda, Rellis
  Shalemark, Mereth and Neris for 24–29;
- the survey `~/projects/grudgelands-orchestration/r60/reports/survey-quests-21-30.md` (facts with file:line, the
  validator dry run, the pins, the ledger, the Alchemy facts §11) and the plan review
  `r60/reports/plan-review.md` (2 blockers, 4 important, 10 minor; folded in);
- player feedback (BACKLOG ~96-101): fewer mob names, more objective variety (the band is 58 % kill today).

## 1. Lanes and waves

| Wave | Lane | Who | Goal (one line) | Waits for |
|---|---|---|---|---|
| 0 | CHAPTER2 | Astra | The story chapter for levels 21–30: the eight zones' local threads, the chapter's quests (A3/A4, T3 and a Throng step at 24 if picked), the mine leaders as guild members, the places and objects; two variants at each open point | the user's go |
| 0 | CHECK2 | Opus | A feasibility check of CHAPTER2's draft against the data and the system | CHAPTER2 |
| 0 | HERBS | Opus | The Alchemy herbs re-placed so every tier's herb grows in its own level band, in every race's zones (§2 point 9) | the user's go |
| 1 | BANDQUESTS | Opus | The eight band zones rebuilt on the Round 57 system, flagged `reworked`, placeholder texts; their spawn files; the chapter-2 story quests whose giver stands in a band zone | the user's chapter picks |
| 1 | CAPITALS | Opus | The six capital files flagged `reworked` (chapter 1 kept), their chains untied, the chapter-2 story quests whose giver stands in a capital, the Alchemy quest (§2 point 6), the foreman titles for Brodd and Rellis | the user's chapter picks, HERBS merged; rebases after BANDQUESTS merged |
| 1 | STORYART | Astra | Art for the new use objects of both lanes (two proposals, a pick page) | the user's QUESTMAP verdict |
| 2 | BANDTEXT | Astra | The texts of both lanes' quests | the user's QUESTMAP verdict |
| 2 | TEXTREVIEW | Opus | Text review with a suggestion page; the user picks | BANDTEXT |
| 3 | D | Opus | Docs, CHANGELOG, version 0.60.0 with the map-reset declaration, STATUS, the GUI checklist | everything else |

Every non-trivial lane gets an independent Opus review and a delta review for every logic fix (the coordinator may
check text-, display- and data-only deltas). Art ships only after the user's pick. BANDQUESTS merges first; CAPITALS
rebases on it and builds the joint QUESTMAP page on its rebased branch (as Round 59's STORYQUESTS did).

**Why one band lane, not two:** the band is 84 quests in eight files, the size of Round 59's 83 in six; shared quests
across both factions (Steel Bars in five zones) would otherwise span two lanes' files.

## 2. Rulings

Carried over unchanged from Round 57 §2 (rulings 9–18) and Round 59 §2 for every reworked file: as few quests as
possible without losing depth; a task that is the same in several zones is one shared quest with a variant per zone;
free play (a free quest requires only a level, at most one follow-up per faction, no repeatables, night counts about a
third of the day count); story quests marked `story`, may chain, completion texts; choice rewards and the per-zone
budget (capitals excepted); more objective variety and fewer mob names per zone; map reset is fine.

New for this round:
1. **Chapter 2** follows the arc drafts and the user's picks on the CHAPTER2 page. Known from the survey: A3 (24,
   Brodd → a cargo place in Frostbarrow → Kelda) and A4 (29, Kelda → Hadrin, requires A3 and the free Nib quest); T3
   (29, Ossa → Iven, requires T2, the free travel quest Mereth → Neris and the free Hush quest). Because a free quest
   may have one follow-up per faction, `frostbarrow_departure` and `nhal_veyr_vigil_04` lose their prerequisites
   (the climax's one follow-up is the story quest). The BACKLOG's "T3 needs two free boss quests" is corrected: one boss
   (Hush), one travel quest.
2. **The capitals are flagged `reworked`** this round (40 errors today: envoy/cook dispatch lines, branching climaxes).
   Their dispatch and journey quests become free handovers with no predecessor, as the start and band departures are;
   chapter 1 (A1/A2, T1/T2) stays as shipped; the envoy ids and the envoy `front` line stay (front files talk to the
   envoys).
3. **The band's first quests** (min 20–21) require nothing; the band 11–20's departures still hand the player to the
   capital envoys (pin `r59_bandquests` ~304-305); the band's departures at 29/30 to the 31–40 hosts stay as free
   handovers (ids kept; nothing outside these files requires a band or capital quest).
4. **The mine leaders as guild members** (Kelda, Halen, Saevin, Gorren, Zali; Neris in her dig): their first quests
   carry it, from the chapter-1 draft §7's proposals and the CHAPTER2 picks.
5. **Rewards at item level 21–30** on the Round 59 pattern: T3 materials (steel / heavy cloth / heavy leather),
   enchant tier 3; per zone an early consumable choice, **two** armor pieces with one enchant (mid hunt, later task), a weapon
   with prefix and suffix at the zone's end; each faction's four zones cover all four armor slots (each slot at least
   twice); the budget rule passes. T3 potions (`potion_healing_t3` / `potion_mana_t3`) need level 21
   (`grug_alchemy/effects.lua` ~1): a first quest at min 20 gives T3 potions only at reward level ≥ 21, else T2.
6. **An Alchemy quest at the first capital visit** (the user, 2026-10-24): around level 19–21 the capital's **envoy**
   (the player's first contact; on the shared `envoy` line, which `r59_storyquests` ~158-162 already wants) asks for
   an easy tier-1 elixir the player has not been given as a reward before, with the hint "the Alchemy trainer can
   teach you to brew it" (the trainer's plot named in words; the trainer is a villager without a quest dialog, survey
   §11b). Every tier-1 elixir needs Sunleaf or Gravemoss plus a band-1 mob drop (Precision I: Sunleaf + Boar Tusk;
   Vigor I: Sunleaf + Tattered Flesh; each with a Glass Bottle). Today **neither ingredient is in reach of any
   capital**: Boar Tusk and Tattered Flesh drop only from level 1–10 mobs, Sunleaf grows only in Goldmead, Starbough,
   Raincall and Redtusk (plan review B2). After HERBS (point 9) both T1 herbs grow in every start zone, so the
   envoy sends the player back to where they started by the start settlement's waystone (§2a point 5); the text
   never names the start zone (a text follows the giver's race, not the player's, `quests.md` ~606-610). Glass Bottles (Basic recipe), a
   Brewing Stand in each capital, learning Alchemy for free and "never rewarded before" hold. A crafting lesson
   requests the item, never its provenance, so a friend's elixir counts. **The fixture `r45_st` ~1043-1083 refuses
   any item objective naming a `grug_alchemy:` item** (~1079; `quests.md` ~181 says so in words): CAPITALS allows
   this quest's id there with a one-line reason, D records the exception beside `quests.md` ~181.
7. **Profession-gated items:** no gather or item objective may ask for a profession-gated item unless it is the point
   (point 6). **Dragonweed** (Alchemy-gated) grows in Frostbarrow and Ossuary: the Gravemoss trap of this band.
8. **Use objects** stand away from mob members in camps (damage breaks the hold); town places only in plots every world
   builds (seven service plots, the inn and the guild house are still free per capital), through the plot's
   `extra_sockets`.
9. **The Alchemy herbs follow the level bands** (the user, 2026-10-24): for levels 1–20 each tier's herbs grow in the
   zones of every race (T1 Sunleaf and Gravemoss in the six start zones, T2 Dragonweed in each race's 11–20 zone); for
   21–40 each tier's herbs grow on each faction's own half of the continent, scattered over that faction's zones of
   the band (not every zone, not per race; Crimson Lotus in 21–40); 41–60's herbs grow in the Battlegrounds and front
   zones anyway (kept unless a tier lacks one); the current places may stay; `grug_gathering/catalog.lua` (zones,
   hosts, density); mob-loot ingredients already drop in their own band (catalogue tier). Mapgen content, so the map
   reset covers it.
10. **Quest-only items never leave the carried inventory** (the user, 2026-10-24): no chest, station, mail, trade or
   trash. The game has that rule already: the group `grug_soulbound` (`grug_housing/soulbound.lua` ~1-15: only `main`,
   the bags' content lists and the hotbar store accept it; trades and mail never carry it). Today's two quest-only
   items (`grug_mobs:accord_captains_orders`, `throng_captains_orders`, `items.json` kind `quest`) lack it and can be
   put in a chest; every quest-only item (those two and any this round adds, e.g. the Dispatch Folio) gets it. A lost
   item drops again on the next kill while the quest is active (`grug_quests/state.lua` ~714-743). The quest drop's
   `give` puts an item that does not fit at the player's feet (~705-707): the lane makes that safe for a soulbound item
   (for example no roll while the inventory is full) and checks what dropping one does. Owner: BANDQUESTS. (the user, 2026-10-24)

## 2a. Decided after the plan review (the user, 2026-10-24)

1. **Scope: all 14 files this round** (the eight band files and the six capital files, flagged `reworked`).
2. **Questing share 21–30: the Round 59 pattern's ~55–60 % is fine** (no XP bump on non-kill quests).
3. **Brodd Deeppeg and Rellis Shalemark get their names** through a per-camp foreman title in
   `grug_quests/npcs.lua` ~142-147 (CAPITALS; small code, no mapgen).
4. **The Alchemy quest's product:** "whichever has the better-reached ingredients" (the user); the plan review found
   both equally far (§2 point 6), so the product follows §2a point 5. The quest text fits the chosen elixir and is
   imaginative, not a dry request (the user's example for Precision: someone bet a neighbour they could hit an apple
   with a bow; an example, not a prescription): a note for BANDTEXT.
5. **The ingredients: the player fetches them in their start zone** (the user, 2026-10-24, after the plan review's
   Q1). The start settlement's waystone brings them there quickly; the quest says so without naming the zone. The
   user's question "how does anyone level Alchemy when the start zones lack its ingredients?" showed the root cause:
   the herbs grow one to three level bands above their tier (T1's Sunleaf and Gravemoss only in 11–20, T2's
   Dragonweed only in 21–40, T3/T4's Crimson Lotus only in 51–60), and four races lack Gravemoss, two lack Sunleaf in
   their own zones. **The user's ruling: a HERBS lane re-places the herbs** (§2 point 9). More elixir kinds are not
   needed (six to eight products per tier exist). The product (Precision I or Vigor I) follows ingredient reach after
   HERBS (point 4).
6. **The chapter-2 picks: all thirteen recommendations** (K1–K13 "A", page `r60/chapter2-page`, 2026-10-24): T2a at 24
   (Rellis → a place in Ossuary → Mereth, requires T2, required by T3); A3's held load in the Frostbarrow mining camp;
   the Dispatch Folio as Nib's quest drop; T3 at a public register place by Nhal Veyr's guild house (`claim_notice`);
   Zali in the shared steel help; Thorn and Murk two local quests; Moonfall's sighting post, Totemwater's reading
   bank, Lorindor's snare ground, Speargrass's banner cache; Hush kept his old working copies; torches and a shared
   night task in the capitals; one Alchemy occasion per envoy. Draft `r60/reports/chapter2-draft.md`, check
   `r60/reports/chapter2-check.md`; the check's fixes are taken into the briefs (Hushwater's place in the wilderness,
   one title per shared quest and a line plan, no Paper in Ossuary, Highcourt's cook asks for a Gnarled Boar Tusk,
   the Folio a new soulbound item, cross-lane ids). The Alchemy product is **Precision I** (boars by day in every start
   zone).
7. **The seed fleet checks the quest places** (the user, 2026-10-24): BANDQUESTS checks whether the fleet covers that
   every recipe quest place is placed on every fleet seed; if not, it adds that check (the regions are computed
   offline). Today `quest_targets.py` checks it on 6 seeds only.

## 3. Shared conventions

- **Upgrade classification: map reset** (one `map_reset` entry for 0.60.0, by D): new places in band spawn files, new
  quest sockets in band POIs and capital plots. Characters keep items, levels, quests and money; quests whose ids vanish
  are dropped (upgrade contract §4); new ids for every reworked quest whose objectives change.
- **Quest text rules** as in Rounds 57 and 59.
- **Generators:** each lane's `tools/r60_<lane>/build_structure.py` writes the structure once with `[PH]` texts; its
  `--check` compares structure only (ids, objectives, targets, levels, requires, rewards, givers, lines), never texts
  (Round 59 lesson).
- **Fixtures:** `tools/r60_<lane>/portable_test.lua`, text-agnostic (no `[PH]` pins). The pins the survey §6 lists move
  with a one-line reason each: `r46_xp` ~266/271 (48 files / 433 quests), `r45_st` ~1077 (98 item objectives), `r32_f2`
  ~780 (≥ 270 kill objectives, 274 today), `r58_guildquests` ~376-381 (camp zones unflagged), ~249/278/302 (camp hunts;
  :302 depends on `lorindor_cutting_opt_01`), ~197-225 (report variants), `build_structure.py --check --ids`;
  `r59_storyquests` ~145 (capitals unflagged), ~151-162 (envoy lines, leader hub) and its generator
  `tools/r59_storyquests/build_structure.py` ~283 (asserts the capitals unflagged; the fixture crashes once a capital
  is flagged); `r59_bandquests` ~304-305; `r45_st` ~1079 (the Alchemy quest, §2 point 6); new town places or sockets:
  `r59_qsys3` ~156-162 (Highcourt's one shipped place), `r56_freeze_capitals` ~98-124 (capital digests); a band
  blueprint change: `r58_camps`, `r36_r`, `r36_w`; the foreman titles: `r58_campnpc` ~118 (every foreman "Foreman")
  and the Python mirror `r28common.py` ~1236-1239. Both
  lanes edit the same count pins: BANDQUESTS merges first, CAPITALS rebases and recounts.
- **Owners:** BANDQUESTS the eight band files, their spawn files (places, quest targets), the R20 POI blueprint and the
  mining-camp blueprint if new sockets are needed, its rows in `use_objects.json`; CAPITALS the six capital files, the
  capital zones' spawn files, the capital plot `extra_sockets`, `grug_quests/npcs.lua` (the foreman titles only), its rows in
  `use_objects.json`. New givers are declared in the quest file (`"new": {name, race, socket}`, `validate.lua`
  ~500-523), not as `npcs.lua` rows; the foremen keep their NPC ids.
- **HERBS** owns `grug_gathering/catalog.lua` and the docs that list herb places (`professions.md`, `item_tiers.md`,
  `farming.md` where they name zones), and the fixtures that pin herb zones; no quest file.
- **Cross-lane slots and ids** (plan review I2): three free quests have their one per-faction follow-up taken by a story
  quest: `frostbarrow_cutting_04` → A4 (both BANDQUESTS), `ossuary_rubbings_03` (BANDQUESTS) → T3 (CAPITALS),
  `nhal_veyr_vigil_03` → T3 (both CAPITALS). These quests keep their ids even if their objectives change (an exception
  to "new id when objectives change", so the story quests' `requires` hold across lanes); no other free quest may
  follow them in that faction. The briefs fix the ids. New use objects get
  placeholder looks from shipped textures until STORYART's pick.
- **The guild content** in these files keeps working: `guild_t3_report_accord` / `_throng` (homed Frostbarrow /
  Ossuary, 11 variants each), `camp_hunt_t3` (7 variants), `camp_hunt_t3_night` (Totemwater), the T2 report's band
  foreman variants, the mining-camp foreman hubs; the T3 camp hunts may share targets with zone quests (as Round 59's §2a point 4 ruled
  for `camp_hunt_t2`; the pin `r58_guildquests` ~244-302 moves); `guild_t3_anthracite` / `_garnet` stay in `charter_of_stone`.

## 4. Lane goals (briefs add file facts)

**CHAPTER2 (Astra).** From the drafts and the chapter-1 completions: for each faction the chapter's story across the
band and the capitals at 21–30: the local threads the eight zones carry as free quests (the zones' named leaders Nib,
Thorn, Murk, Iss, Bracken; the Archivist, Rakk, the Reed-Maw, Ush; the chapter's people Brodd, Kelda, Rellis, Mereth,
Neris, Hush, Ossa), the chapter's story quests (A3/A4, T3; whether the Throng gets a step at 24 to mirror A3), where the
open question of chapter 1 (where do the abused papers come from?) leads, the places and objects, the mine leaders as
guild members (from §7's proposals), and the hand-off toward 31–40 (Ashenward, A5 at 34). No vanishing NPCs. Two
variants at each open point (K-points with a recommendation); a short list of what the structure needs (new givers,
sockets, places, objects). German report, as in Round 59.

**CHECK2 (Opus, read-only).** The draft against the data and the system: every named NPC, place and object exists or
is listed as new; the free/story rules (one follow-up per faction); levels; profession-gated items; what is expensive.
The user sees it beside the pick page; the coordinator folds in plain fixes as in Round 59.

**HERBS (Opus).** Re-place the Alchemy herbs (§2 point 9): per tier the ingredients a recipe needs (`grug_alchemy/recipes.lua`)
reachable in that tier's level band for every race (a table before/after: herb, tier, zones, hosts, density); hosts
that exist in the new zones (biome and ground node); the mob-loot side re-checked (catalogue tier vs the band its
mobs live in); gated stays gated; densities as rough targets, positions free. Checks: the gathering fixtures, the
herb/catalogue pins, `validate.py --game`, `seed_fleet quick` (mapgen content), one boot. Report a herb a band has no
fitting host for instead of inventing a biome.

**BANDQUESTS (Opus).**
- The eight band files rebuilt and flagged `reworked`; shared quests where the task repeats (survey §1: Steel Bars in
  five zones, armored crabs ×4, toll mirefolk ×3, poachers ×3, bears ×3, wisps ×3; a shared quest has one level, share
  per faction when the levels differ); local quests for the zone's story; counts before and after; zone size follows the
  ledger's 20→30 row (~55–60 % questing share, §2a point 2) as the rough yardstick, not a fixed count per zone; a giver
  socket only where the picks need one.
- Objective variety and fewer mob names; first quests require nothing; departures kept; Frostbarrow's chapter-2
  quests (A3, A4: wholly band-file data, A4 turns in at Hadrin), the unchained `frostbarrow_departure`, and
  `ossuary_rubbings_03` with its id kept (T3's prerequisite).
- New quest sockets and givers where the structure needs them (Moonfall and Totemwater have two givers each, the POI host and the foreman; R20
  POIs have one socket, camps none free): map reset; a blueprint change runs `seed_fleet quick`. Places: spawn-file
  places (as Starbough's `snare_ground`) or camp sockets; use objects away from mob members.
- Rewards (§2 point 5); the ledger 20→30 before and after (`ledger.py --game --track <race> --party solo`, the band
  row); `quest_kinds.py --check`, `tools/r28_regions/run.sh`, `guarantee.py --check`, `quest_targets.py`.
- Placeholder texts; the QUESTMAP page with CAPITALS.

**CAPITALS (Opus).**
- The six capital files flagged `reworked`; their chains untied (free dispatch/journey handovers, climaxes with one
  follow-up per faction); chapter 1 unchanged (the `r59_storyquests` structure check stays green except the pins that
  move); the envoy ids and `front` line kept; the capital climaxes (Brakk, Penn, Rusk, Hush, Garr, Takka) as free
  quests; objective variety; rewards optional (capitals are budget-exempt).
- The chapter-2 story quests whose giver stands in a capital (T3 Ossa → Iven, requiring `ossuary_rubbings_03` and
  `nhal_veyr_vigil_03`; the unchained `nhal_veyr_vigil_04`), new town places if picked (free every-world plots via `extra_sockets`;
  `tools/building_templates/check.py`, `seed_fleet quick`).
- The Alchemy quest (§2 point 6) in each capital, on the envoy's `envoy` line, after HERBS merged: Precision I or Vigor
  I by ingredient reach (§2a point 4); the `r45_st` ~1079 exception.
- The foreman titles for Brodd and Rellis (§2a point 3): a per-camp title in `npcs.lua`; note
  `validate.py` reads NPC factions from `existing.json` (BACKLOG Round 59 carry-overs) if an id is new.
- Placeholder texts; rebases on BANDQUESTS and builds the joint QUESTMAP page from main.

**STORYART (Astra).** The new use objects of both lanes (from the accepted QUESTMAP): two proposals, a pick page; the
Round 59 objects show the style (32×32 sprites).

**BANDTEXT (Astra) and TEXTREVIEW (Opus).** As in Round 59, for both lanes' quests; the Alchemy quest's text fits
its elixir and is playful (§2a point 4).

**D.** Version 0.60.0 with the map-reset entry; CHANGELOG, STATUS, ROADMAP, BACKLOG, AGENTS (merge with the user's
`ui-modernization` AGENTS.md lines if that branch has merged); the completion section; the GUI checklist (a level-21
character of each faction through the band, chapter 2 at 24 and 29, the Alchemy quest at the first capital visit,
the capitals' handovers); a full seed fleet at the round's end if a placement or blueprint change merged.

## 5. Rules

The usual ones ([round workflow](../process/round-workflow.md)): one worktree and branch per lane; an independent Opus
review per non-trivial lane and a delta review for logic fixes; the Lua queue at most 8 at once; no pushes, merges or
syncs by lanes; nothing unpicked ships. Fixtures: each lane runs only its own fixture plus the fixtures that test the
behaviour it changes, and the full run once before its report. No lane touches `.claude/worktrees/ui-modernization`.

## 6. Verification

- **Gates:** the full fixtures, `check_fresh_server.py`, `check_upgrade.py` (with the map-reset entry),
  `validate.py --game` (0 errors with the 14 files flagged), `quest_kinds.py --check`, `tools/r28_regions/run.sh`,
  `quest_targets.py`, `guarantee.py --check`, `income.py --check`, `tools/building_templates/check.py` if templates
  change, the seed fleet as above, one boot per lane.
- **GUI checklist** (D, draft): a level-21 character of each faction finds the band's quests at once; shared quests
  read in each zone's voice; the reward choices; the Alchemy quest at the first capital visit (learn, brew, turn in);
  chapter 2 from 24 (Brodd, the cargo place, Kelda) and at 29 (A4 at Hadrin, T3 at Iven); the capitals' handovers;
  the guild quests and camp hunts still work.

## 7. Orchestration notes

- **Order:** CHAPTER2 and HERBS start together; CHECK2 after CHAPTER2; the user's chapter picks and the §2a answers; BANDQUESTS and CAPITALS in parallel
  (BANDQUESTS merges first; CAPITALS rebases and builds the QUESTMAP from main); the QUESTMAP verdict; STORYART and
  BANDTEXT from main → TEXTREVIEW; D last.
- **Cross-lane requires:** T3 requires the band's `ossuary_rubbings_03` (BANDQUESTS keeps its id); A4 may require
  Frostbarrow's Nib quest and turns in at Hadrin; the briefs fix the ids both lanes use.
- **The GUI test of 0.57–0.59** runs in parallel; a fix it needs becomes a small FIX lane that merges first.
- **ui-modernization:** today docs only (AGENTS.md +3 lines). Its planned quest/map lane touches `grug_quests/npc.lua`,
  `grug_map/quest_box.lua`, `page.lua`, `window.lua`; this round's lanes stay data-only there (`npcs.lua` is a
  different file). Re-check the overlap at each merge.

## 8. Engine and code facts (from the survey; re-check in the briefs)

- Zones: `wp40/source/simple_map.lua`, zone n on line 63+n; band zones 4, 9, 14, 15 (Accord), 20, 25, 30, 31 (Throng);
  capitals :66, :71, :76, :82, :87, :92.
- 148 own quests (84 band, 64 capitals); band objectives 51 kill / 14 item / 23 talk; 6–8 mob names per zone.
- Dry run flagged: band 31 errors, capitals 40, together 71 (E-free-chain, E-free-follow-ups) + 26 W-night-count.
- Sockets: none free in the band (R20 POIs one `quest_host` each, `r20_poi_blueprint.lua` ~239-241; camps
  `r58_camp_blueprint.lua` ~151-159); capitals: one `quest_place` each (R59), seven service plots, inn, guild house
  free; the guild house's residents are idle villagers, not quest shells.
- Hubs: 2 givers per hub, 2 lines per giver (`validate.lua` ~20-21); every envoy and cook at the cap; the leader hub has
  one giver, line `guild`, anchor `zone`.
- Ledger 20→30 solo: questing share 78–103 %; quest weight per file 24.5–38.5 KE (the reworked 11–20 files 47.5–48.5).
- Alchemy: herbs Gravemoss (Copperfell, Mournfen), Dragonweed (Frostbarrow, Ossuary, two 31–40 zones), none in a capital
  zone; harvest refused without Alchemy (`harvest.lua` ~55-66); the trainer in each capital's alchemist plot
  (`capital_services.lua` ~6-26, socket ~140) is a villager without a quest dialog; no "profession learned" objective.

## 9. Later

Round 61 and on: the bands 31–40 (the arc's A5 at Ashenward 34), 41–50 (the front at 41), 51–60; then the production
deploy with one map reset; then the armor redesign and the unique items.

## Completion (2026-10-24)

Every lane is merged on main, every code lane independently reviewed (Opus) and every logic fix delta-reviewed or,
where it was data or text only, checked by the coordinator; this lane D (the version, the declaration, this section,
AGENTS, the status owners, the joint GUI checklist) follows on main `b63318dd`. **0.60.0 is a map reset:** no
migration step; characters keep their items, levels, quests and money; a quest whose id vanished is dropped (upgrade
contract §4); item, achievement and waypoint ids unchanged; no new position in player meta. **Push:** not pushed;
0.57.0 was pushed on 2026-10-23 without its GUI test, and 0.58.0, 0.59.0 and 0.60.0 wait for the user's joint GUI test
of all four. **Sync:** by the coordinator after every merge.

### Lanes

Worktrees and branches `r60-<lane>`. Main's first-parent commits, in order (lane tip in brackets):

| Lane | Commit | What | Review |
|---|---|---|---|
| plan | `e3ca411e`, `4a279ae4`, `f1d1f21b`, `56513c2a`, `0ab3aea0` | this plan with the plan review folded in (B1, B2, I1–I4, M1–M10) and the user's answers (§2a); then the herb rulings (§2 point 9), the soulbound quest items (§2 point 10), the chapter-2 picks and the fleet's place check (§2a points 6–7) | fresh Opus plan review (2 blockers, 4 important, 10 minor) |
| CHAPTER2 | outside the repository | GPT-6 Astra's draft of chapter 2 (`r60/reports/chapter2-draft.md`, German): the eight zones' local threads, A3/A4, T2a/T3, the mine leaders as guild members, four new object kinds, the Dispatch Folio, eleven new places, open points K1–K13 with two variants each | CHECK2 (Opus, read-only, `chapter2-check.md`): ready after corrections (below) |
| HERBS | `4007a7e8` (`f4324f8b`) | the Alchemy herbs re-placed by level band (`grug_gathering/catalog.lua`, the helper `ground_hosts`; the digest pin in `wp40/r7_manifest.lua`), the cooking addendum (Frost Melon on The Throng's half, Pumpkin hosts in all six home zones, `wp40/world_content_catalog.lua`), `tools/r60_herbs` (`reach.lua`, `count.lua`, fixture) | MERGE (five minor findings: the report's CPU label, the faction balance, more yield in the old zones, one zone per faction and band for 21–40, a stale per-biome table); the docs fix `f4324f8b` checked by the coordinator |
| BANDQUESTS | `b235da41` (`c4d9d9e4`) | the eight band files rebuilt and flagged `reworked` (`tools/r60_bandquests/build_structure.py`, fixture), A3, A4 and T2a; quest-only items soulbound with an `on_drop` that destroys them and no roll while they would not fit (`grug_mobs/subtypes.lua`, `grug_quests/state.lua`, `grug_traders/prices.lua`); the Dispatch Folio; `quest_place` sockets at Rimebell Watch and Market Close (`wp40/r20_poi_blueprint.lua` `QUEST_PLACES`) and `held_load` in every mining camp (`wp40/r58_camp_blueprint.lua`); seven recipe places and the flags in the band spawn files; the 59 region maps; the seed fleet's quest-place check (`tools/seed_fleet/seed.lua`, `runtime.lua`) | MERGE (Low: three travel handovers reached a giver with nothing to offer for 4–5 levels; the report's GUI line); the fix `c4d9d9e4` (four handover levels) checked by the coordinator as data only |
| CAPITALS | `7cceabee` (`e5f95fb6`) | the six capital files flagged `reworked` (`tools/r60_capitals/build_structure.py`, fixture, engine probe), chapter 1 kept; T3; the Alchemy quest `capital_precision`; the public register socket on Nhal Veyr's guild plot (`wp13/nhal_veyr_district.lua`); the per-camp foreman titles (`grug_quests/npcs.lua`, mirrored in `r28common.py`); rebased on BANDQUESTS; the joint QUESTMAP (`tools/r60_capitals/questmap.py`) | MERGE before the rebase (Low: the night task asked 3 against 6 by day); the rebase deltas (T3 requires T2a, the night task asks 2) checked by the coordinator as data only |
| STORYART-SHIP | `b4792a7c` (`0d077f3f`) | the picked sprites of the four Round 60 objects (`grug_quests_obj_{signal_lantern,sighting_frame,reading_knots,claim_notice}.png`) and the three quest item icons (`grug_mobs_dispatch_folio.png`, `grug_mobs_{accord,throng}_captains_orders.png`), their `use_objects.json` rows and sizes, `tools/r60_storyart` (`paint_art.py --check`), `LICENSE-media.md` "Round 60" | checked by the coordinator (PNGs byte-identical to the picks, the rows, no code) |
| BANDTEXT, TEXTREVIEW, flag fix | `b63318dd` (`d0aecf87`) | GPT-6 Astra wrote the 291 text fields of the 14 files (`5bff77db`: 110 titles, 149 texts, 32 completions); the user's 13 text picks applied by the coordinator's script (`870849a7`); the `quest_target` flags that no quest names any more removed from four capital spawn files (`d0aecf87`, an Opus step) | TEXTREVIEW (Opus): 1 must-fix, 12 proposals, all picked; `870849a7` (text only) and `d0aecf87` (flags only, the region maps byte-identical) checked by the coordinator |
| D | this section | the version 0.60.0 and the `map_reset` entry, upgrade contract §2, AGENTS, STATUS, CHANGELOG, BACKLOG, ROADMAP, README, the docs check, the joint GUI checklist | independent review |

**STORYART** (GPT-6 Astra, outside the repository): story art drop 02 (the four objects and the Folio icon, two
proposals each) and drop 02b (the Captain's Orders icons); the user's picks are below. Nothing unpicked ships.

Main has 275 portable fixtures (3 new: `r60_herbs`, `r60_bandquests`, `r60_capitals`). `mods/` against 0.59.0
(measured, `git diff e6efbfb5 b63318dd -- mods`): 47 files, +2,860 −2,401 lines: the fourteen quest files, ten spawn
files, `use_objects.json`, `items.json` and the seven textures, the gathering catalogue, the manifest pin, the world
content catalogue, the R20 POI and camp blueprints, Nhal Veyr's district file, and the code in `grug_mobs/subtypes.lua`,
`grug_quests/state.lua`, `grug_quests/npcs.lua` and `grug_traders/prices.lua`.

### Lanes added during the round

- **HERBS** (added while planning, before the plan's commit): the plan review found no tier-1 elixir ingredient near
  any capital (B2); the user asked how anyone levels Alchemy when the start zones lack its herbs, and the root cause
  (each tier's herbs grew one to three bands above it) became a lane of its own (§2a point 5, §2 point 9).
- **The cooking survey** (Opus, read-only, the user asked whether Cooking needs the same treatment,
  `r60/reports/cooking-survey.md`): no separate lane; two data fixes the user approved went into HERBS as an addendum
  (Frost Melon for The Throng's T4 dish, Pumpkin in the three home zones that lacked a host). Left as they are: corn in
  four start zones and berries for humans and elves at 11–20 (farming closes them after one trip).
- **Drop 02b** (STORYART): the Captain's Orders still showed the quest kind's tinted placeholder; the user wanted
  their own icons, painted and picked like drop 02.
- **STORYART-SHIP:** as in Round 59, a small Opus lane copied the picked PNGs into the mods, so the art is
  reproducible and `r36_q0` checks the objects as shipped files.
- **The flag fix** (`d0aecf87`, a step on `r60-bandtext`): `quest_kinds.py --check` reported 7 differences on main
  after CAPITALS (capital kinds flagged `quest_target` that no quest names any more); the texts fixed one (Hush's text
  names `nhal_veyr/tombfields`), the step removed the other six flags.

### Decisions during the round

**The user** (HANDOVER):

- **§2a (the plan review):** all 14 files this round; the questing share of 21–30 at about 55–60 % is fine; Brodd
  Deeppeg and Rellis Shalemark named by a per-camp foreman title; the Alchemy product by ingredient reach, its text
  playful; the ingredients fetched in the start zone by the start waystone, the text never naming the zone.
- **The herb rulings:** levels 1–20 in every race's own zones; 21–40 on each faction's half of the continent,
  scattered; 41–60 in the Battlegrounds and fronts. From HERBS' report: the mapgen cost (+7–10 % on herb-zone chunks)
  accepted; Dragonweed's faction balance in 11–20 (988/479, estimated) **not** equalised (plenty); the T2 mob-loot
  gaps to the BACKLOG.
- **Quest items never leave the carried inventory** (§2 point 10): no chest, station, mail, trade or trash.
- **The chapter-2 picks K1–K13: all "A"** (no notes): T2a at 24; A3's held load in the Frostbarrow mining camp; the
  Dispatch Folio as Nib's quest drop; T3 at a public register by Nhal Veyr's guild house; Zali in the shared steel
  quest; Thorn and Murk two local quests; Moonfall's sighting post, Totemwater's reading bank, Lorindor's snare
  ground, Speargrass's banner cache; Hush kept his old working copies; torches and a shared night task in the
  capitals; one Alchemy occasion per envoy.
- **The seed fleet checks the quest places** (§2a point 7); after BANDQUESTS measured it, the check stays in the
  `quick` fleet (+11 %).
- **QUESTMAP:** accepted ("Ja, die Quests passen").
- **The art picks** (`story-art/pick/picks.md`, Round 60): all P2: the signal lantern (1.2), the sighting frame (1.4),
  the reading knots (1.3), the claim notice (1.3), the Dispatch Folio icon; drop 02b P2 for both Captain's Orders
  (rolled despatches with seal tags).
- **The texts:** all 13 proposals of the text review (the Acacia Wood Fence Gate name; Nib's and the Archivist's papers
  left open; Mariel's elixir lines; two shared titles fitted; T3's struck claims; A3's loading ground).

**The coordinator** (answers to lane questions and the check; each built as stated):

- **CHECK2's fixes, taken into the briefs:** the Hushwater place moved into the open Reedbanks (outside the camp's
  24-node member disc); one title per shared quest and a line plan (a shared `shore` line for Hedra, Orya, Lethen and
  Tokai); a local item instead of Paper in Ossuary (no papyrus there); Highcourt's cook asks for a Gnarled Boar Tusk;
  the Folio a new soulbound item; the fish quest (Tokai, Varda) and T2a in BANDQUESTS.
- **The Alchemy product:** Precision I (Sunleaf and a Boar Tusk: boars by day in every start zone).
- **The cross-lane ids** fixed in both briefs: A3 `story_accord_03`, A4 `story_accord_04`, T2a `story_throng_03`
  (BANDQUESTS), T3 `story_throng_04` (CAPITALS); `frostbarrow_cutting_04`, `ossuary_rubbings_03` and
  `nhal_veyr_vigil_03` keep their ids.
- **CAPITALS' questions:** the rewards as proposed (no weapon choice at the climaxes); `capital_precision` at minimum
  level 19, so it is offered at first contact; the two Gnarled Boar Tusk errands stay local; Kezamba's cook line
  `smokehouse` became `provisions` (one line for the shared Raw Meat quest); the questing share measured after the
  rebase (below).
- **BANDQUESTS' questions:** the questing share accepted (the capitals' rework lowered it, below); Varda's old Mire
  Carp quest gone (Varda gives `band_mire_carp`); the name "Reedlands Seized Stores" kept; the fleet's +11 % to the
  user.
- **The data-only fixes** (BANDQUESTS' handover levels, CAPITALS' rebase deltas, the text picks, the flag fix)
  checked by the coordinator; no logic changed in them.

### Deviations from the plan

- **Lanes added** (above): HERBS before the plan's commit, the cooking addendum, drop 02b, STORYART-SHIP, the flag fix.
- **The soulbound group alone did not stop a drop:** a quest item dropped from the inventory would have landed as an
  entity; every quest item got an `on_drop` that destroys it with a feed notice (BANDQUESTS' re-check).
- **The three quest item icons needed no code:** `subtypes.lua`'s `item_image()` already prefers an item's own PNG;
  the tinted placeholder stays for a future quest item without art.
- **`check_upgrade.py` passed in every lane** (the plan expected a failure until D): unpushed 0.58.0's entry already
  covers every change against pushed 0.57.0; D declares 0.60.0's reset all the same.
- **The camp hunt generator** (`tools/r58_guildquests/build_structure.py`) would have turned Totemwater's night hunt
  into a day hunt once the band no longer hunts its tapirs; BANDQUESTS pinned it (`KEPT_HUNTS`).
- **The 21–40 herbs** grow in one zone per faction and band (HERBS' reading of "scattered": Whitebridge and the
  Reedlands at 21–30, Glassroot and Thunderroot at 31–40).
- **The QUESTMAP** came from CAPITALS' own `tools/r60_capitals/questmap.py` (the real loader over a draft folder),
  not from `tools/r56_questmap`.
- **`quest_kinds.py --check`** was not rerun by CAPITALS; the flag fix after the texts closed it (above).

### Numbers worth keeping

Measured unless marked "report" (taken from the lane's report).

- **Quests:** the eight band files 84 → 71 quests, the six capitals' own 64 → 47 (measured over the files at
  `e6efbfb5` and `b63318dd`); **403 shipped** in 48 quest files (433 − 84 + 71 − 64 + 47), 28 of them flagged
  `reworked`; 78 ids dropped (50 band, 28 capital), 48 added, 70 kept (two with changed objectives:
  `frostbarrow_cutting_04` gained the Folio, `nhal_veyr_vigil_03` asks only for Hush). Offered per band zone (report,
  shared and guild variants included): Frostbarrow 14 → 14, Whitebridge 15 → 14, Lorindor 15 → 15, Moonfall 13 → 11,
  Ossuary 13 → 12, Speargrass 11 → 12, Reedlands 12 → 13, Totemwater 11 → 11.
- **Objectives** (per quest, a shared quest counted once): the band kill 51 → 14, item 14 → 20 (one kill-near drop),
  talk 23 → 29, use 0 → 10, so the kill share 58 % → 19 %; the capitals kill 31 → 13, item 12 → 5, talk 26 → 26, use
  2 → 3 (44 % → 28 %). Per band zone (report, counting each zone's variants): 50–62 % → 17–27 %.
- **Mob names per zone** (measured: the kill and kill-near objectives of each zone's variants): Frostbarrow Barnacle
  Pincher, Cliffbuck, Goblin Powder-Counter Nib; Whitebridge Acorn Hog, Basket-Poacher Thorn, Mirefolk Ferryman Murk;
  Lorindor Barnacle Pincher, Brook Hind, Mirefolk Pearl-Counter Iss; Moonfall Barnacle Pincher, Crescent Stag, Poacher
  Snarewarden Bracken; Ossuary Marrow Weevil, Ash Howler, Skeleton Marrow Archivist; Speargrass Quagga, Tallgrass Tiger
  (its claws), Goblin Banner-Broker Rakk; Reedlands Reed Tapir, Logback, Mirefolk Tollkeeper Ush; Totemwater Barnacle
  Pincher, Sedge Ooze (at night), Crocodile Reed-Maw; before 5–7 mob roles per zone (report). The capitals 3–4
  names each with the shared night and meat quests (report: 2–3 of their own; before 3–6).
- **The ledger 20→30, solo** (`ledger.py --game --track <race> --party solo` on main `b63318dd`, the questing share
  against 21,960 XP needed): human 60 %, dwarf 65 %, elf 78 %, orc 61 %, troll 81 %, undead 54 %; before the round
  78–103 % (report, survey and BANDQUESTS); elf and troll walk two band zones; undead is one point under 55 % (no
  weight raised).
- **The validator:** the dry run with the 14 files flagged before the round found 71 errors and 26 `W-night-count`
  (report, survey); `validate.py --game` on main: 0 errors, 6 warnings (as before the round), 28 files flagged.
- **Herbs** (report, HERBS' real-writer sample of 57 surface chunks on seed 42): Gravemoss 15 → 100, Sunleaf 25 →
  142, Crimson Lotus 0 → 20, Dragonweed 0 → 17; every race's start zone grows both T1 herbs. CPU of that sample (plan
  and write) **+7–10 %** (about 0.28 → 0.30 s per herb-zone chunk; the review reran +7.5 %).
- **The fleet's place check** (report): 4.2 s per seed on average (max 5.6) of 37.8 s, **+11 %**; on seed 42 the fleet
  puts all 13 places where the rendered maps do. This lane's full fleet: see [Round-end gates](#round-end-gates).
- **Rewards** (measured over the files): every band zone's first quest a choice of 2 Healing or 2 Mana Potion III
  (reward level 21); the slots Frostbarrow head and chest, Whitebridge legs and feet, Lorindor head and legs, Moonfall
  chest and feet; Ossuary chest and legs, Speargrass head and feet, Reedlands chest and feet, Totemwater head and legs
  (each slot twice per faction); the named leaders a weapon per line; the capitals' climaxes 3 Heavy Leather, 3 Heavy
  Cloth or 2 Steel Bars; the night task and T3 a potion III choice.

### Classification

**Map reset**, no step:
`{"schema": 3, "version": "0.60.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0", "0.58.0", "0.59.0", "0.60.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0"], "map_reset_pass": "0.50.0"}`.
The reason ([upgrade contract §2](../technical/upgrade-contract.md#2-the-declaration)): the Alchemy herbs and two
cooking crops in new zones and on new hosts, the `quest_place` sockets in two R20 POIs, every mining camp and Nhal
Veyr's guild plot, the seven quest places in the band spawn files and the changed `quest_target` flags in the band and
four capital spawn files change what world generation and the towns build. A world on 0.57.0 (or 0.58.0, 0.59.0)
moves on across one reset with the pre-reset pass: characters keep everything but their position and home claim
(contract §3.2); an active quest whose id vanished leaves the log, a kept id keeps its state.

What needs the reset and what alone would be compatible (the lanes' reports): the herbs and crops (HERBS), the
sockets and recipe places (BANDQUESTS, CAPITALS; the blueprints' and the plot's cells are byte-identical, the sockets
are new) and the flags change what new worlds build, and the quests that use them ride on the reset; the quest data
itself, the soulbound group and the drop rule, the price change, the foreman titles, the texts and the art alone are
compatible. Saved state, all without a position: `grug_quests:state` for the new ids (no format change; the old
counter of `nhal_veyr_vigil_03` is ignored); nothing new in player meta or mod storage, so no `register_on_relocate`
clear.

### Open notes

- **For the user:** the joint GUI test below, with these to judge: the use objects' look and size (four new), the
  hold at the Frostbarrow camp's loading ground and at the open places with mobs around, the band's errands as a first
  version, the questing share (54–81 %), the Folio's behaviour with full bags; from Round 59 the held supplies' hold in
  the Redtusk and Raincall camps, the Nhal Veyr town place outside the mourners' hall, a level-9 arrival at the
  steward; from Round 58 the names never picked (the three cloaks, the achievement and its line) and from Round 57 the
  violet story colour (now on chapter 2 too) and the headland edge.
- **Round 61** reworks the band 31–40 with the arc's next chapter (A5 at Ashenward 34, §9).
- The reviews' and reports' notes are in the [Round 60 carry-overs](../../BACKLOG.md#round-60-carry-overs).

### GUI checklist (Rounds 57, 58, 59, 60 and the UI)

One test for all four rounds and the UI modernization (0.60.1; nothing since 0.57.0 has been tested in the GUI),
desktop and the web build (the lanes' web shots were taken at 1024 × 600; Round 57's at 1280 × 720 and 1035 × 696), on
the synced game. It replaces [Round 59's list](round59-plan.md#gui-checklist-rounds-57-58-and-59); items 1–48 keep that
list's numbers (and its wording, linked below), Round 60 adds items 5–7 in (A) and 49–66 in (B), the UI modernization
items 67–81 in (B). Where Round 60 changes what an earlier item tests, the item says so; every earlier window item now
also sees the new look.

**Resetting a local world** (what the hosting platform does, contract §3.5; one reset covers 0.58, 0.59 and 0.60; 0.60.1 needs none):

1. Quit the world (stop the server), then make a copy of the world folder.
2. Optional, to test the claims' containers: from the repository checkout,
   `python3 tools/migrate.py --world <world folder> --map-reset` (Python 3.14, or 3.13 with python3-zstandard; it packs the containers in
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
world and with new characters; (C) a new world (or the "test" world) for the bays. *Re-checked (D, as Rounds 58 and
59):* no Round 57–60 item needs the old **map**; Round 57's items 3 (its last sentence), 5 (its last sentence) and 15,
Round 59's band ids and Round 60's kept ids and soulbound Orders test an old character's **first join on the new
code**, which the reset keeps (player meta stays), so they run in (A) at that first join, the path the production
world takes. Do not join the existing world on the new game before the reset, or that first join is spent. Items 1,
2 and 4 of Round 57 need no old state.

**(A) The existing world, at the first join after the reset** (a character above level 10 with old start quests done
or active, ideally one with old band quests of levels 11–20 active or done, **one of level 21 or more with old band
21–30 or capital quests active or done**, a crafting job running when it last logged out, enchanted items, a housing
claim if you have one):

1. **The reset:** the character arrives at its race's start town without the welcome and keeps its level, inventory,
   equipment, money, quests, professions, mounts and waypoints; its home claim is gone (Return home falls back to the
   innkeeper), the Housing Steward hands out a new Claim Stone, and (after step 2) the claim's containers wait in its
   Belongings tab. The Character page shows "Miner's Guild: Rank 0".
2. **Round 57 item 3, last sentence:** a job of the old version that was running finishes as before (its output in the
   inventory or the Overflow).
3. **Round 57 item 5, last sentence:** the existing character has its Basic recipes after this login.
4. **Round 57 item 15, changed by Round 59:** the new start quests are offered (one whose old finale was done
   keeps it done); its old start quests are gone from the log without an error. Its level-11 zone offers the
   **reworked** band quests (not the old chain); an old band quest that was active and no longer exists is gone from
   the log without an error, while a kept id (the departure, the witness travel, the handoff, five day hunts, three
   perpetrators) keeps its state: done stays done and is not offered again.
5. **Round 60, the band 21–30 and the capitals for an old character:** a character of level 19 or more finds the
   reworked capital quests at its envoy and cook (item 58), one of 21 or more the reworked band quests (item 49); an old
   band 21–30 or capital quest that no longer exists is gone from the log without an error (78 ids went); a kept id
   keeps its state (chapter 1, the departures and travels, the cooks' dispatches, the T3 camp hunts and reports, six
   leaders' and day hunts, Takka's and Hush's quests): done stays done and is not offered again.
6. **Round 60, two kept ids with new objectives:** if Nib's "An Explosive Miscalculation" (`frostbarrow_cutting_04`,
   Kelda) was active, it now also asks for the Dispatch Folio (item 52); if Hush's "The Account Is Closed"
   (`nhal_veyr_vigil_03`, Ossa) was active with revenants counted, it completes on Hush alone. **Judge:** both read
   right in the log.
7. **Round 60, the Captain's Orders an old character carries:** they are soulbound now: a chest, the mail, a trade and
   the trash refuse them, dropping one destroys it (item 52).

**(B) Round 57** (its [checklist](round57-plan.md#gui-checklist-round-57) items, unchanged unless noted):

1. Layout C. 2. The queue. 3. Offline and the overflow (its last sentence in A). 4. Favourites. 5. The Basic unlock
(its last sentence in A). 6. Recipe details. 7. Alloys and woods. 8. Dyes. 9. Vendors (and Round 58's mason below).
10. A new character's start (the waystone and mailbox now stand at the town's centre: Round 58 below). 11. Shared
quests. 12. Choice rewards (Round 58's hunts add a choice of materials; Rounds 59's and 60's band rewards, items 37
and 54). 13. Completion text: **changed by Round 59:** the start town's departure (level 9) now leads to the level-11
zone's steward, whose first quest opens at level 10 (item 35). 14. Story marking: **changed by Rounds 58–60**: judge
the violet "!", the "Story" heading and the map icons on a guild follow-up (item 31), on chapter 1 at an envoy (item
43) or on chapter 2 (items 55–56) instead of the capture probe. 15. An existing character above level 10 (in A).
16. Bays (in C). 17. The chin underside. 18. Help. 19. The pages for the user.

**(B) Round 58** (items 20–34 of [Round 58's list](round58-plan.md#gui-checklist-rounds-57-and-58), unchanged unless
noted): 20. Mining camps (**since Round 60** every camp has an empty `held_load` cell on its loading ground; only
Frostbarrow's shows objects, for A3, item 55). 21. Camps under construction. 22. The map. 23. The lift. 24. The rooms.
25. The camp vendor at rank 0. 26. Reputation. 27. The cloaks. 28. Ore Sense. 29. Treasure Hunt. 30. Guild houses
(**since Round 59** each leader also gives chapter 1's second quest, item 44; **since Round 60** Hadrin Beamset takes
A4 and Iven Lastshift T3). 31. Guild quests: the T2 ones in a band 11–20 zone (Round 59's note), **the T3 ones in a band
21–30 zone (item 62)**. 32. Town fixes. 33. Help. 34. The pages for the user.

**(B) Round 59** (items 35–48 of [Round 59's list](round59-plan.md#gui-checklist-rounds-57-58-and-59), unchanged unless
noted): 35. The band at level 11. 36. Shared quests in each zone's voice. 37. The reward choices with their enchants.
38. The use places in the four camps. 39. The snare ground and the name rest. 40. The gathered and crafted items in
their zones (**since Round 60** Sunleaf and Gravemoss grow in the start zones too, item 60). 41. The hunts. 42. The
departure at 19 (**since Round 60** the envoy it leads to also offers the Alchemy quest at once, item 59). 43. Chapter
1, step one: **changed by Round 60:** its last sentence ("The envoys' old quests are still offered") is replaced by
the reworked capital quests (item 58). 44. Chapter 1, step two. 45. The guild reports. 46. The four objects (**since
Round 60** the dispatch record also stands at Market Close and, with the held supplies, at the Frostbarrow camp's
loading ground, the held supplies at the Speargrass Banner Cache and the Reedlands Seized Stores, the witness record at
the Ossuary Claim Rest and the snare bundle at the Lorindor and Moonfall snare grounds). 47. Web. 48. The pages for
the user.

**(B) Round 60:**

49. **The band at level 21** (BANDQUESTS): with a level-21 character of each faction (`/xp give <you> <amount>`), in
    each band zone each zone's first quest (the village host, level 20) is offered at once, with a choice of 2 Healing
    or 2 Mana Potion III: Frostbarrow Shelf Edda Tarnmantle (5 Frost Melons), Whitebridge Shire Merren Oakstamp (8
    Corn), Lorindor Ilwen Petalmeasure (6 Marshbloom), Moonfall Wood Lethen Moonledger (6 Glass); Ossuary Reach Sovel
    Namekeeper (10 Gravewood Planks), Speargrass Reach Brakka Jarward (8 Corn), Whispering Reedlands Taleko Drycord (4
    Melons), Totemwater Reach Tokai Knotreader (4 Mire Carp). The other givers offer theirs from each quest's level
    (the mine leaders' steel at 23, Hedra's lantern at 22, Mereth's travel at 25, Morga's banners at 27, Enashi's
    stores at 26); no quest asks for another outside the story. A travel handover opens about a level before its
    target's first quest (Speargrass to Morga at 26, Reedlands to Enashi at 25, Ossuary to Mereth at 24). The
    departures at 29 go to the 31–40 hosts and require nothing.
50. **Shared quests in each zone's voice:** "Steel for the Work" (4 Steel Bars, level 23) at the six mines (Kelda
    Screesort, Halen Chalkthumb, Saevin Rootscribe; Neris Fossilhand, Gorren Redpick, Zali Runoff), each leader naming
    its guild (The Charter of Stone, The Oathdelvers) in this first offer; "Room for Our Feet" (6 Barnacle Pinchers on
    the zone's shore by day, 24: Hedra Rimebell, Orya Petalward, Lethen Moonledger, Tokai Knotreader); "Cut the
    Snares" (21: Orya, Lethen); "The Waiting Still Eat" (8 Corn, 20: Merren, Brakka); "Sound Wood" (15 planks of any
    wood, 22: Lethen, Tokai); "Fish for the Table" (4 Mire Carp, 20: Tokai, and Varda Copperpan in Dur Brannoc). Taken
    in one zone, the faction's other zones do not offer it while it is active and never again once done (Steel taken
    at Kelda is not offered at Halen); each zone's text reads in its own voice under the one title; "Return to" names
    the giver; the log shows the zone you took it in.
51. **The places and their objects:** the map crosshair on the spot, the object only for players who still need it,
    "<act> at <place>" in the log and the HUD, the hold counted in the feed, stepping away or taking damage stops it.
    The three town places: Rimebell Watch's signal stand by the banner (Hedra's "The Reliable Light": Trim the signal
    lantern, 4 s), Market Close's basket check beside the stores (Merren's "Two Pickups for One Basket": Check the
    pickup records, the dispatch record, 4 s), the Frostbarrow mining camp's loading ground (A3, item 55). The seven
    open places, on dry ground with the place's name and direction right in the text, the log and on the map:
    the Lorindor Snare Ground (the Berrywoods) and the Moonfall Snare Ground (the Eaves) ("Cut the Snares", the snare
    bundle, 3 s), the Moonfall Sighting Post (the Deepwood; "A Fixed Point of Reference", Set up the sighting frame),
    the Ossuary Claim Rest (the Barrowlands; T2a, item 56), the Speargrass Banner Cache (the Hunting Grounds; Morga's
    "Bring the Colours Home", Secure the stolen banners), the Reedlands Seized Stores (the Reedbanks, in the open, not
    in Hushwater Nests; Enashi's "Loosen the Held Bundles", Free the seized stores) and the Totemwater Reading Bank
    (the Reedbanks; Tokai's "A Reading Worth Checking", Secure the reading cord). **Judge:** can each hold be finished
    with the area's mobs around?
52. **Quest items stay in your bags** (BANDQUESTS): Goblin Powder-Counter Nib drops the Dispatch Folio for Kelda's
    "An Explosive Miscalculation" (level 28): a chest, a station, the craft grid, the mail, a trade and the trash refuse
    it; dropping it destroys it with "Dispatch Folio is lost; it drops again while your quest needs it." and it drops
    again on a later kill; with full bags a kill gives "No room for Dispatch Folio; it can drop on a later kill." and
    nothing lands at your feet. The Captain's Orders of the high war camps' captains (`throng_main_04` "Find the Hand
    That Signed", level 47, and its Accord counterpart) behave the same.
53. **The hunts:** about three mob names per zone (Frostbarrow: Barnacle Pincher, Cliffbuck, Goblin Powder-Counter
    Nib; Whitebridge: Acorn Hog, Basket-Poacher Thorn, Mirefolk Ferryman Murk; Lorindor: Barnacle Pincher, Brook Hind,
    Mirefolk Pearl-Counter Iss; Moonfall: Barnacle Pincher, Crescent Stag, Poacher Snarewarden Bracken; Ossuary:
    Marrow Weevil, Ash Howler, Skeleton Marrow Archivist; Speargrass: Quagga, the Tallgrass Tiger's claws, Goblin
    Banner-Broker Rakk; Reedlands: Reed Tapir, Logback, Mirefolk Tollkeeper Ush; Totemwater: Barnacle Pincher, Sedge
    Ooze after dark, Crocodile Reed-Maw), every other count by day; the named leaders at 28–29 read without a doubled
    place.
54. **The reward choices with their enchants** (as item 37, at item levels 21–30): two armor choices per zone (a
    prefix piece, then a suffix piece; Frostbarrow head and chest, Whitebridge legs and feet, Lorindor head and legs,
    Moonfall chest and feet; Ossuary chest and legs, Speargrass head and feet, Reedlands chest and feet, Totemwater
    head and legs) and the named leader's weapon per line with a prefix and a suffix; the offer lists each by its
    enchanted name with its enchant lines, and the item received has them. No shared quest gives equipment.
55. **Chapter 2, The Accord** (story, violet): at 24, after "What a Seal Allows", Brodd Deeppeg, the Frostbarrow mining
    camp's foreman, offers "Held in Our Name": at the camp's loading ground Secure the dispatch record and Release the
    held load (4 s each, any order), then turn in at Kelda Screesort at Tarncut Mine (a potion III choice). At 29
    "Under a Joint Seal" is offered by Kelda only after A3 and Nib's quest; it turns in only at Hadrin Beamset in Dur
    Brannoc's Miner's Guild house. **Judge:** the loading ground's holds with the camp around.
56. **Chapter 2, The Throng** (story): at 24, after "Whose Word Is This?", Rellis Shalemark, the Ossuary mining camp's
    foreman, offers "The Copy Between Them": Secure the copied claim at the Ossuary Claim Rest (the witness record,
    4 s), then turn in at Mereth Rubbinghand. At 29 Ossa Quietregister in Nhal Veyr offers "Strike the False Claim" only
    after T2a, "A Chisel Leaves Its Signature" (Mereth's or Rellis's travel to Neris) and "The Account Is Closed"
    (Hush): Post the claim notice at the public register on the guild house forecourt, west of its door (3 s), then
    turn in at Iven Lastshift only. **Judge:** does the register read as part of the guild house?
57. **Free play around the story:** Nib's and Hush's quests, the travel to Neris and the departures read well without
    the story; Hush's departure "Help Freely Given" (to Vaska) and Frostbarrow's "Keep Your Head at Splitbolt" require
    nothing.
58. **The capitals** (CAPITALS): at 20–22 every envoy offers "Light for the City's Work" (20 Torches) and, in Highcourt,
    Dur Brannoc, Lethariel and Nhal Veyr, "Debts That Walk at Night" (2 Debtbound Zombies after dark, a potion III
    choice); the cooks of Lethariel, Gor Drazhak, Kezamba and Nhal Veyr "Meat for the Table" (8 Raw Meat from the
    capital's day game); Highcourt's cook Ansel Ovenward and Kezamba's Teshani Smokereed ask for Gnarled Boar Tusks;
    the cooks' dispatch travels lead into the band; each capital's named culprit (Bandit Tollmaster Penn, Goblin
    Ore-Factor Brakk, Poacher Bough-Counter Rusk, Bandit Ration-Broker Garr, Bandit Offering-Broker Takka, Zombie
    Mortuary-Clerk Hush; a choice of 3 Heavy Leather, 3 Heavy Cloth or 2 Steel Bars) and the departures at 29; all at
    once from their level, none asking for another.
59. **The Alchemy quest at the first capital visit:** at 19 each envoy (Mariel Waybook, Dorrin Gateledger, Eriath
    Boughwarden; Thorga Roadspeaker, Nalo Pathdrum, Ossa Quietregister) offers "A Steady Hand for a Rash Promise" with
    its own occasion: 1 Elixir of Precision I. The text names the capital's Alchemy trainer by plot (Highcourt's herb
    garden, Dur Brannoc's and Lethariel's brewhouses, Gor Drazhak's herb house, Kezamba's herbalist, Nhal Veyr's
    physic house) and the start waystone, never the start zone. Learn Alchemy at the trainer (free), take the waystone
    to your start settlement, gather Sunleaf and take a Boar Tusk from the boars by day, make a Glass Bottle (Basic),
    brew at the capital's Brewing Stand, turn in at the same envoy. A friend's elixir counts.
60. **Herbs by level band** (HERBS, a new world): in all six start zones find Gravemoss and Sunleaf (without Alchemy,
    Gravemoss says "Requires the Alchemy profession."); in an 11–20 zone Dragonweed; in Whitebridge or the Reedlands
    Crimson Lotus; in Copperfell, Starbough or Redtusk Pumpkin; in Ossuary or the Reedlands Frost Melon at a freshwater
    edge. **Judge:** the recipe card's "Grows in …" line (clipped on the card, full in the tooltip).
61. **Name tags:** Brodd Deeppeg and Rellis Shalemark over their camps' foremen; every other foreman "Foreman".
62. **The guild quests and camp hunts in the band 21–30:** the foreman's T3 gather quests ("Keep the Forges Fed", "A
    Small Order", one variant per guild), the camp hunt "A Load on Every Back" (8 of the zone's game, a choice of
    materials) in seven zones and Totemwater's "What the Dark Drags In" (3 Sedge Oozes after dark), the T3 reports
    "Two Hands on the Seal" (to Hadrin Beamset) and "Marks Beside the Promise" (to Iven Lastshift) next to the story
    quests.
63. **The objects and icons** (STORYART): look and size on the ground, desktop and web: the signal lantern (1.2) at
    Rimebell Watch, the sighting frame (1.4) at the Moonfall Sighting Post, the reading knots (1.3) at the Totemwater
    Reading Bank, the claim notice (1.3) on the register socket's cell; the Dispatch Folio and both Captain's Orders
    (rolled despatches with seal tags) in the inventory, the hotbar and the quest log at 16 px.
64. **The quest log and HUD:** a shared quest of the band shows the zone you took it in; A3's two uses show as two
    lines in the dialogue and the log, one compact line in the HUD.
65. **Web:** a reward choice's dialog, the feed notices of item 52 and the objects at the web size.
66. **The pages for the user** (outside the game, private claude.ai pages): the
    [chapter-2 pick page](https://claude.ai/artifact/75ykbz5V7PMF6YMdfGHRmH), the
    [QUESTMAP](https://claude.ai/artifact/KQ9ZQnCGpvCi4myvScabwW) of the band 21–30 and the capitals and the
    [text pick page](https://claude.ai/artifact/KacTKqvwAciXKtp7dM5gMf).

**(B) The UI modernization (0.60.1, compatible):** the UI plan's own
[desktop and web checklist](ui-modernization-plan.md#6-verification-and-gui-checklist) (every form, privilege and
service) is part of this test; the items below are the points its reviews left for the GUI. The seven theme PNGs and
the ten tab line icons are picked (the fidelity contact sheets, 2026-10-25), the quiver total beside the slot and the
compact header (1.5 units per tab row) are accepted.

67. **Small windows and GUI scales:** every tab at 1035 × 696 and at 1920 × 1080, at GUI scale 1 and 1.5: titles,
    labels, achievements, the PvP card, effects and slot labels readable and not clipped. **Judge:** the dense texts
    (achievement descriptions, crafting rows, the header's faction and level).
68. **High-density display** (OS scaling 2× or a raised `display_density_factor`): text keeps its size instead of
    shrinking to about half.
69. **Privileged tabs:** a player with `mail_admin` only, Creative only, both and neither: the tab rows (two rows when
    needed), Admin Mail and Creative reachable, a grant or revoke while the window is open handled.
70. **Native inventory interactions:** drag, shift-click, split, scroll, tooltips and item counts in the bags, the
    belt, the equipment, the quiver (the total beside the slot) and hotbar A/B unchanged.
71. **Focus and closing:** the X button and Escape close like before; Enter in the craft search; no window reopens
    after it was closed or replaced.
72. **Mail drafts:** unfinished text survives non-send actions, attachments come back on close, no duplicate send.
73. **Long story text:** a long quest offer, completion text and the reward choice scroll and stay readable.
74. **Map navigation:** Z and the Map & Quests tab open the larger map directly; the tabs on top lead to every other
    page and back; zoom, scrolling, filters and the quest panel unchanged.
75. **Zone labels at 1× in a small window:** the labels overlap densely there (measured 73 overlapping pairs at
    1035 × 696, 3 at 1920 × 1080). **Judge:** acceptable, or a later fix.
76. **Progress animations:** crafting and furnace progress still animate without extra sends, also after reopening.
77. **Hover on the clear tab buttons:** the hover and the selected state are visible on bright, dark and busy
    backgrounds.
78. **Narrow tabs:** no overlap of icon and text, also with two tab rows and long labels.
79. **The one client crash:** a client abort (`malloc(): unaligned tcache chunk detected`) happened once at GUI 1.5
    under Xvfb in an intermediate version; its cause is unproven. Use GUI 1.5 for a while and note any crash.
80. **The other windows:** chests, shelves, vendors, trainers, the Claim Stone, signs and books, character creation
    and the arrival window in the new look.
81. **Web:** items 67, 69, 70, 74 and 77 in the web build too.

**(C) Round 57 item 16, the bays:** in a new world with the "test" seed (or the reset "test" world).

### Round-end gates

Lane D on its branch from `b63318dd` (measured; `mods/` identical to main): `check_upgrade.py` PASS (against
origin/main `69481ed1`, 0.57.0, with the `map_reset` entry 0.60.0; it also passes without that entry, since unpushed
0.58.0's covers every change against 0.57.0), `check_fresh_server.py` PASS, `validate.py --game` 0 errors (6 warnings,
as before), `quest_kinds.py --check` 0 differ (119 quest-named kinds), `quest_targets.py` 0 missing (947 targets on
seeds 42, 7, 2026), `guarantee.py --check` PASS, `income.py --check` PASS, `r37_dc` PASS (766 checks),
`tools/r60_bandquests/build_structure.py --check` 0 of 8 and `tools/r60_capitals/build_structure.py --check` 0 of 6
differ, `tools/r59_bandquests/build_structure.py --check` and `tools/r59_storyquests/build_structure.py --check` 0 of
6, `tools/r58_guildquests/build_structure.py --check --ids` 0 of 26, `tools/r60_storyart/paint_art.py --check` OK (7
textures) and `tools/r59_storyart/paint_art.py --check` OK (4), a link and anchor check of every touched file, the
full `run_fixtures.sh` (**275 passed, 0 failed**), the **full seed fleet on main's tree** (`seed_fleet/run.sh full`
through the queue at 8 parallel, with the quest-place check: **304 of 304 seeds build, 0 failed, 21 min 25 s**;
Round 59's took 20 min 8 s) and one headless boot (PASS, no ERROR line). Each code lane ran the full `run_fixtures.sh`
once (HERBS 273/0, BANDQUESTS 273 of 274, `r30_p1`'s stub then fixed and passing, CAPITALS 275/0 after its rebase,
STORYART-SHIP 275/0).
