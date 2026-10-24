# Round 60 — the story arc's second chapter and the quest rework of levels 21–30 (0.60.0, map reset)

Coordinator: Claude, 2026-10-24. Status: **planned**; the plan review (`r60/reports/plan-review.md`) and the user's answers (§2a) are folded in.

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
