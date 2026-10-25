# Round 62 — the front 41–60 and the main line's story layer (0.62.0, map reset)

Coordinator: Claude, 2026-10-25. Status: **planned**. The user took every §2a recommendation (2026-10-25) and added
the bag sizes (§2 point 11). The plan review (`r62/reports/plan-review.md`: 1 blocker, 6 important, 6 minor) is
folded in (§2b).

Round 62 is **the last round of the quest rework of levels 11–60** on the Round 57 quest system. Earlier rounds did
11–20 (Round 59), 21–30 and the capitals (Round 60), and 31–40 with chapter 3 of the story arc (Round 61). This round
reworks the **front 41–60**:

- the four contested hosts' `.front` files (Ashenward, Bannerbreak, Stormvault, Blackwind);
- the six capitals' `.front` files;
- the four Battlegrounds files (among the 14 unflagged files);
- the Round 36 main line, its 24 ids in the two contested base files and the front files;
- the guild's T5/T6 gathers, which stay as Round 58 shipped them.

The story arc plans no chapter 4: the main line already carries the story to 60 (three chapters at 41, 46 and 53, and
the party finale at 60). The round therefore gives the main line the arc's **story layer**:

- `story` marking;
- completions;
- the guild thread (the war camps as the guild's workplaces);
- Odren Vell and Tallykeeper Mardra.

The production deploy with one map reset follows this round.

**Start state:** main `cf3fab5e` (0.61.1 compatible on 0.61.0, map reset). It is not pushed: origin/main is 0.57.0.
The user's joint GUI test of 0.57 to 0.61.1 (`round60-plan.md` "GUI checklist") runs in parallel and may send fixes.

**Inputs:**

- the Round 57 quest rulings (Round 57 plan §2, rulings 9–18) and the system (`docs/design/quests.md`, including
  "Group quests (Round 61)");
- Round 61's plan, completion and lessons (`round61-plan.md`, `~/projects/grudgelands-orchestration/r61/HANDOVER.md`);
- the front story:
  - `docs/design/story.md` §2a and `docs/planning/round36/story-bible.md` §1–2;
  - the arc (`r57/reports/storyarc2-report.md` "Level 40–41" and the text additions :191, :292-296);
  - chapter 3's draft and shipped A6/T5 completions;
- the survey `~/projects/grudgelands-orchestration/r62/reports/survey-front-41-60.md`, cited as "survey §n";
- player feedback (BACKLOG ~96-110): fewer mob names, more objective variety. The front is 66 % kill today (78–82 % in
  the two big `.front` files), with 8–12 mob names per front zone and faction.

## 1. Lanes and waves

| Wave | Lane | Who | Goal (one line) | Waits for |
|---|---|---|---|---|
| 0 | CHAPTER4 | Astra | The main line's story layer for 41–60, with two variants at each open point (§4) | the user's §2a answers |
| 0 | CHECK4 | Opus | A feasibility check of CHAPTER4's draft against the data and the system | CHAPTER4 |
| 0 | TEMPLATEFIX | Opus | The known template defects that wait for a map-reset round (§2 point 10) | the plan review |
| 0 | BAGS | Opus | Bag sizes 8 / 12 / 16 / 20 instead of 4 / 8 / 12 / 16, prices unchanged (§2 point 11) | the plan review |
| 1 | FRONTQUESTS | Opus | The 14 unflagged files (ten `.front`, four Battlegrounds) rebuilt and flagged; the main-line spine marked `story`; the group quests, rewards, gaps and places; the spawn files; the validator and ledger fixes; placeholder texts; the QUESTMAP | the user's chapter picks |
| 1 | STORYART | Astra | Art for new use objects or quest items, if the picks add any (two proposals, a pick page) | the user's QUESTMAP verdict |
| 2 | FRONTTEXT | Astra | The texts of the lane's quests and the main line's completions; two runs by faction if the size needs it | the user's QUESTMAP verdict |
| 2 | TEXTREVIEW | Opus | Text review with a suggestion page; the user picks | FRONTTEXT |
| 3 | D | Opus | Docs, CHANGELOG, version 0.62.0 with the map-reset declaration, STATUS, the GUI checklist, the deploy list | everything else |

**Reviews:**

- Every non-trivial lane gets an independent Opus review.
- Every logic fix gets a delta review. The coordinator may check text-, display- and data-only deltas himself.
- Art ships only after the user's pick, as a STORYART-SHIP step (Rounds 60 and 61).

**Why one quest lane** (survey §13):

- The front has 127 quests at 41–60, about 1.7× Round 61.
- The factions share their leaders (Senn, Ninepins, Huskell, Chirr, the elites at 50 and 59), the Battlegrounds files,
  the six front spawn files, `subtypes.json`, `names.json` and the shared quests.
- A split by faction would need an owner for each of these, and a split by level range cuts the main line.
- The fortress quests (24 + 24) pass the flag as they are and mostly stay, so the real rebuild is smaller.
- The text lane is the large one. It may run as two Astra runs by faction (wave 2).

## 2. Rulings

The rulings of Rounds 57 and 59–61 carry over unchanged for every reworked file:

- as few quests as possible without losing depth;
- a task that is the same in several zones is one shared quest, with a variant per zone, one level, one title and every
  giver on the same line;
- free play: a free quest requires only a level and has at most one follow-up per faction; no repeatables; night counts
  about a third of the day count;
- story quests are marked `story`, may chain and get completion texts;
- choice rewards and the per-zone budget (point 5);
- more objective variety and about three mob names per zone (Rounds 59–61 reached 17–27 % kill);
- profession-gated items only where the profession is the point (Crimson Lotus in the Causeway and Skyglass, Ember
  Moss);
- use objects away from mob members, and quest-only items soulbound;
- check exits and hand-offs against the real front levels; rerun `quest_kinds.py` after any lane that drops quests;
- new quest ids never start with `camp_` or `guild_`;
- a map reset is fine.

**Elite group quests below level 51 are always optional** (the user, 2026-10-25; `quests.md` "Group quests (Round
61)"). From 51 they may stand on the story path.

New for this round:

1. **Scope and flag:**
   - All 14 unflagged files are flagged `reworked`: the ten `.front` files and the four Battlegrounds base files. The
     Battlegrounds files pass with 0 errors today (survey §5); BACKLOG ~3184 left them unflagged only by choice. That
     makes **all 48 quest files flagged**.
   - The flag in a `.front` file draws W-unknown-key, so `validate.py` (`V:782-784`) learns the key. The game's loader
     already accepts it (`validate.lua:468-470`).
   - The **fortress quests** keep their ids, chains, lines and files: one entry call, three ordinary quests and eight
     camp raids per faction. They pass the flag (survey §5), and `r31_q` pins them (~376-434). They get texts in
     FRONTTEXT only where the main line's voice needs it.
2. **The main line becomes the story path** (§2a point 1):
   - The spine pinned by `r36_qa` (17 Accord ids) and `r36_qt` (14 Throng ids), the climaxes on Senn, Ninepins,
     Huskell and Chirr included, is marked `story` throughout. Each spine step requires only spine steps.
   - Every front quest that is not on the spine becomes free play. The path today runs through 19 (Accord) and 14
     (Throng) free chain quests (survey §2), and a flagged free chain is the 54 errors of the dry run.
   - The spine keeps every id, its order, its levels and its giver/turn-in hand-offs. `r36_qa`/`qt` move only where a
     `requires` on a non-spine quest goes.
   - The final ids (`accord_main_final`, `throng_main_final`, `throng_main_07`, `accord_main_collector`) are fixed:
     `grug_mobs/rift_core.lua:79` and the achievements name them.
   - The optional War Commander quests (Stonegrudge, Greyvow, at 59) stay optional story branches.
   - The four island uses stay optional.
3. **The join at 41** (§2a point 2):
   - A6 and T5 end at the Warmaster through the free fortress calls.
   - `accord_main_impounded` and `throng_main_01` (min 41) require nothing today.
4. **Group quests:**
   - The four at 50 (`lasthedge_front_05`, `archshadow_front_04`, `bb_front_torn_06`, `bw_front_hollow_03`) become
     standalone free quests.
   - Both factions hunt Engine Nine and Last-Toll, so each of the two becomes one shared quest with a variant per
     faction's giver on `border` (Engine Nine: Nella + Yarra; Last-Toll: Alna + Orrel; point 7). Their extra is a
     plain trinket choice; the pattern's third trinket choice per faction at 41–50 sits on a late solo quest.
   - **Recorded exceptions** (plan review I2): the elites from 51 (Salt-Counter: Borin and Vaska share no non-front
     line; Glass-Throat: a shared quest would go into a capital base file), the island elites and the spine climaxes
     stay per faction. The Throng's island bounty hunts other island mobs (`rimehorn_ram`, `rime_pelt_leopard`,
     `glass_fang_serpent`, `salt_hex_witch`), so only its elite step repeats the Accord's.
   - The 59–60 group quests may stay on chains. The two finales (`accord_main_collector`, `throng_main_finale`) stay
     the only required group steps.
   - Below 51 a group quest never carries a zone's key reward; it gets an extra, for example a trinket choice.
5. **Rewards at item level 41–60** (§2a point 3):
   - **Materials and enchants:** T5 (Embersteel, Silk, Sleek; enchant tier 5) at 41–50, and T6 (Abyssal Steel,
     Stormweave, Nightscale; tier 6) at 51–60 (survey §10).
   - **Pattern** per faction and per band 41–50 and 51–60, as Round 61's:
     - six armor pieces with one enchant, every slot at least once;
     - three weapons, one per weapon line, with prefix and suffix, on solo quests;
     - three trinket choices on group or late quests;
     - Healing or Mana Potion V/VI choices on early quests (usable from 41 and 51).
   - **Over the round** that is 24 armor pieces, 12 weapons and 12 trinket choices.
   - **The budget problem:** `E-reward-budget` counts per zone and ignores level, and the six contested zones' budgets
     are full from Round 61 (survey §10).
   - **The fix:** the budget counts **per zone and level band**, the band being `(level − 1) // 10` of the quest's
     reward `level` (31–40, 41–50, 51–60), in both validators (`validate.py` ~1022-1027, `grug_quests/validate.lua`
     ~1172-1182), the same band for `W-reward-levels`; fixture cases in `tools/r57_qsys/quest_test.lua` ~846-866 and
     `validate.py --self-test` ~2368-2375 (the message prefix "… has N equipment rewards with 1 enchant" stays).
   - **The Accord at 41–50 has only two non-capital giver zones** (Ashenward; Stormvault with Alna alone) and no
     capital work below 55, so the pattern does not fit there (plan review B1). The fix is a CHAPTER4 pick (§2b
     point 1): an Accord envoy (Dorrin or Mariel) gets 41–50 work through a departure at about 45, budget-exempt as a
     capital, mirroring Thorga for the Throng and filling the Accord's thin level 45. The fallback, a smaller 41–50
     pattern (4 armor + 2 weapons), would be the user's call.
   - The final turn-ins (`*_main_final`, solo) give one key reward.
6. **Coverage and the unfound givers** (survey §4):
   - **Departures** lead to Thorga (Gor Drazhak, 41–45) and Ossa (Nhal Veyr, 53–58). Their quests fill the Throng's
     thin levels 44–45 and 54–56.
   - **The Accord's thin levels** 45, 52 and 54–55 are filled.
   - **Eriath's Skyglass work** opens about 51–52 instead of 55.
   - **The Throng gets an island bounty pair** at 60, mirroring the Accord's Dur Brannoc / Highcourt bounties (§2a
     point 4).
   - **The questing share** is about 55–60 % solo in 50→60 and at most about 65 % in 40→50 (§2a point 5). The Throng's
     50→60 rises to the Accord's level: today it needs twice the free play.
   - **The ledger** gets its two known bugs fixed first: the captain's kill counted twice, and the island bounties'
     kill XP (BACKLOG ~1314-1320).
7. **Shared quests across the factions** sit in a base file on the hosts' `border` line, Round 61's shape. Toren,
   Nella, Alna, Orrel, Drek and Yarra have `border` + `front` (Faeris and Rumela carry `border` too). A shared front quest is homed in its first variant's
   zone's base file (`V:885-887`), and `tools/r61_bandquests/build_structure.py` learns them (the r61 fixture's
   `--check`).
8. **Kill share and names:**
   - About 25 % kill and three to five mob names per front zone and faction.
   - Leaders no quest hunts any more leave their spawn files with their `subtypes.json`/`names.json` rows and
     `quest_target` flags (the Round 61 practice).
   - The camp hunts' roles stay off-limits (`r58_guildquests` ~251-273).
9. **Places:**
   - The five free clash sites 076, 079, 080, 083 and 085, and new recipe places in the front zones where a pick needs
     one (a map reset anyway).
   - The Tombroad tally-stone stays (plan review I3: quest places have no offset field, and both uses are spine steps
     pinned at `r20_anchor_077`; a move is not worth a new mechanism). It stays in BACKLOG.
   - No text names "West Trench Mouth" (compass word, `r29_q1`).
   - No new giver sockets: the capitals' free sockets are unverified at runtime (survey §7).
   - No foreman names unless CHAPTER4 puts a war-camp foreman into the story.
10. **Template defects (TEMPLATEFIX, §2a point 6):** the known-defects baseline that waits for a map-reset round
    (BACKLOG ~3013-3017):
    - the three known defects (`known_defects.txt`): Kezamba's moot-house pane over a door and the two Lethariel
      mere shrines' inside point on a block;
    - Kezamba's moot-house inside point (5,5,8);
    - the rest of `check.py`'s 14 unreachable points are triaged in the viewer, not edited: the ten gate posts at the
      gatehouse fronts and Sunscar's warlord platform are very likely reached from outside the template (plan review
      I5; the 25 was Round 56's count).

    The deploy's one map reset is the last chance before production.
11. **Bag sizes 8 / 12 / 16 / 20** (the user, 2026-10-25, after playtests: steps of four are right, but four slots
    are too few for the first bag). Every bag grows by four slots:
    - the cloth bags: Small 4 → 8, Medium 8 → 12, Large 12 → 16, Great 16 → 20;
    - the leather bags: Pouch 4 → 8, Satchel 8 → 12, Pack 12 → 16, Rucksack 16 → 20.

    The prices, recipes and vendor stock stay unchanged.
    - **No migration.** A bag's size is its `bagslots` group (`grug_inventory/bags.lua` ~45-77). Each join sets an
      equipped bag's content list to that size and grows it freely (`bags.lua` ~363-376); only shrinking needs care
      (the 0.48.0 step). An unequipped bag is always empty. The change is upgrade-compatible on its own; it rides in
      0.62.0.
    - **The inventory page needs no re-layout:** it is one 8-wide scroll grid (`grug_inventory/ui.lua` ~196-225);
      four 20-slot bags make 13 rows instead of 11 (80 bag slots, 64 before). BAGS does not touch `pages.lua` /
      `ui.lua` (the user's UI lane proposes inventory height changes); it checks the scroll maximum and makes a
      capture.
    - **The lane changes** the item descriptions "(n slots)", the docs (`inventory_equipment.md`,
      `items_crafting.md`, the comment at `bags.lua` ~38-42), the item dump `docs/planning/round28/items/existing.json`
      (regenerated, never merged by hand), and the pins that move (plan review I4, measured on a mirror): `r48_bags`
      section A, `r44_ih`, `r33_c1`. The 0.48.0 step's online part reads the live sizes
      (`grug_core/migrations.lua` ~192-196): `r48_bags` D/E/F stub the old 4/8/12/16 groups around the handler run, so
      the step's tested behaviour stays. The pushed step's code stays; a character still carrying the 0.48.0 marker
      now sorts into the new sizes (harmless; its letter says "half as much"), one line in the upgrade contract's
      0.48.0 row (`docs/technical/upgrade-contract.md` ~616).

## 2a. Decided (the user, 2026-10-25: every point as recommended)

Each point carries the coordinator's recommendation, which the user took.

1. **The main line as the story path:** the r36 spine (17 / 14 steps, the four climaxes included) is `story`, and
   everything else is free (§2 point 2).
   - **Alternatives:**
     - (b) only the 24 `*_main_*` ids `story`, with the climaxes cut out of the path, which moves both r36 pins and
       loses the leaders from the story;
     - (c) new story quests between the chapters.
   - **Recommended: the spine.**
2. **The join at 41:**
   - (a) The main line's opener requires nothing, as today. A6/T5 point to the Warmaster, and players who skipped the
     story (old characters on the production world) are not locked out.
   - (b) The opener requires A6/T5: one unbroken story from 1 to 60, but an old character at 45 would have to play
     A1–A6 first.
   - **Recommended: (a).**
3. **Rewards:** the per-band pattern (§2 point 5) and the budget per zone and level band (a rule change in both
   validators). The final turn-ins get one key reward. **Recommended as written.**
4. **The Throng's island bounty pair** at 60 (Thorga / Ossa or new envoy quests): **recommended yes** (fairness; the
   Throng lacks free play at 50→60).
5. **Questing share:**
   - 50→60 at about 55–60 %, the Throng lifted to the Accord.
   - 40→50 may stay up to about 65 %: its reward share alone is 53–59 %, and cutting the kills gives about 63–70 %
     (survey §9, estimate). Trimming reward XP there instead would be the alternative.
   - **Recommended: accept up to about 65 %.**
6. **TEMPLATEFIX:** take the template defects into this round, since the map reset is the last one before production?
   **Recommended yes** (small, independent of the quest lanes).

Decided by the coordinator (the plan review may object):

- one FRONTQUESTS lane (survey §13);
- the fortress quests kept (§2 point 1);
- the four at 50 standalone and Engine Nine / Last-Toll shared (§2 point 4);
- the empty zones (the Shattered Line, Skyglass) get no own quests, because the hosts' quests send players there;
- shared quests on `border` (§2 point 7);
- kill share and names (§2 point 8);
- places (§2 point 9);
- the validator key fix and the ledger bugs (§2 points 1 and 6);
- 0.62.0 as a map reset.

## 2b. The plan review (folded, 2026-10-25)

`~/projects/grudgelands-orchestration/r62/reports/plan-review.md`, verdict: buildable with one blocker. The
coordinator re-measured B1 (the Accord's 41–50 givers: Ashenward and Alna only, no capital below 55).

1. **B1, the Accord's 41–50 rewards:** a K-point on the CHAPTER4 page (recommended: Dorrin or Mariel gets 41–50 work
   through a departure at about 45; fallback a smaller pattern, the user's call), §2 point 5.
2. **I1:** FRONTQUESTS owns `tools/r61_bandquests` and limits its band sections (§3).
3. **I2:** the recorded per-faction exceptions and the Throng's island mobs (§2 point 4).
4. **I3:** the tally-stone stays (§2 point 9).
5. **I4:** BAGS' pins, the 0.48.0 step and the item dump (§2 point 11).
6. **I5:** TEMPLATEFIX's real list (§2 point 10).
7. **I6:** owners and contested files (§3).
8. **M1–M6:** the dry-run numbers (§8), the r36 pins (§3); Faeris and Rumela also carry `border`; the join at 41,
   the departures to Thorga (Drek, Yarra or the Warmaster at 41–43) and Ossa (Orrel or Vaska at 52–53), and Engine
   Nine / Last-Toll on `border` are legal as planned; a departure requires nothing (r61 ~328-348).

## 3. Shared conventions

- **Upgrade classification: map reset.** D adds one `map_reset` entry for 0.62.0, its reason taken from the merged
  diff: changed `quest_target` flags in the front spawn files, new recipe places, dropped leaders, template changes.
  - Characters keep items, levels, quests and money. Quests whose ids vanish are dropped (upgrade contract §4).
  - Every reworked quest whose objectives change gets a new id, except the spine and fortress ids (kept) and their
    declared edges.
  - The deploy carries one reset from 0.57.0 to 0.62.0.
- **Quest text rules** as in Rounds 57 and 59–61. The main line keeps its texts until FRONTTEXT, and its completions
  are new.
- **Generator:** `tools/r62_frontquests/build_structure.py` writes the structure once with `[PH]` texts. Its `--check`
  compares structure only, never texts. r61's generator learns the shared front quests in the base files (§2 point 7).
- **Fixtures:** `tools/r62_frontquests/portable_test.lua`, text-agnostic. The pins of survey §8 move with a one-line
  reason each:
  - `r46_xp` ~266/277 (files and quests, exact) and ~281-284 (hub lines used);
  - `r45_st` ~1087 (item objectives, exact);
  - `r32_f2` ~784 (the kill floor; the pattern removes far more than 4);
  - `r56_questmap` ~87;
  - `r36_qt` ~165 (`gated > 20` becomes 17; `r36_qa` passes on the stripped data, plan review M2);
  - `r36_q0` ~260/271 (object kinds, places);
  - `r31_q` (kept);
  - `r58_guildquests` ~117/123 and ~251-273 (kept);
  - `r60_capitals` ~168/183-187, `r59_storyquests` ~154/161-164 (the capital `.front` files kept);
  - `r61_bandquests`: MAIN ~205-213/~452-462 and the host lines ~756-771 hold; the shared front quests in the host
    base files break its band sections (~272, ~284 `shared_count == 5`, ~352, ~474, ~523, ~540, ~543, section H
    ~602-687), which count only quests at level ≤ 40 or exclude a `FRONT_SHARED` set as they exclude `MAIN`; ~908-911
    (`--check`);
  - `r33_c3`, `r36_r` (the final ids, fixed);
  - the seed fleet (places on every seed);
  - `quest_kinds.py --check`, then `tools/r28_regions/run.sh`, `quest_targets.py`, `guarantee.py --check`,
    `r38_names/check_rules.py --shipped` when mob names or leaders change;
  - `income.py --check` after copper changes.
- **Owners:**
  - FRONTQUESTS: the 14 unflagged files (ten `.front`, four Battlegrounds), the main-line quests in the two contested base
    files, shared front quests in the four host base files, the six front spawn files, `subtypes.json`, `names.json`,
    `use_objects.json`, `items.json`, `validate.py`/`validate.lua` (the key and the budget) with `r57_qsys`'s budget case
    and `validate.py --self-test`, `ledger.py` (the two bugs), `tools/r61_bandquests` (test and generator),
    `tools/r36_qt`, `tools/r60_capitals`/`r59_storyquests` only if quests go into capital base files, and the
    QUESTMAP.
  - TEMPLATEFIX: `building_templates`, the defects baseline and `tools/r36_w/baseline.tsv` if a socket point moves.
  - BAGS: `grug_inventory/bags.lua` (not the page layout), its docs, `tools/r48_bags`, `tools/r44_ih`,
    `tools/r33_c1`, the item dump.
  - **Contested:** `BACKLOG.md` (lanes report their lines to D); `existing.json` (regenerated on main after a
    conflict, never merged); `grug_inventory` (a GUI-test FIX lane merges first; the user's UI lane owns the pages).
  - D: the release files.

## 4. Lane goals (briefs add file facts)

**CHAPTER4 (Astra).** Starting from the story bible, the arc's "Level 40–41" and its text additions, and A6's and T5's
completions, Astra writes for each faction the story layer of the main line at 41–60:

- **The spine:** what each step tells, the completion of each step (a hand-over sentence), and how the four climaxes
  (Senn, Ninepins, Huskell, Chirr) sit in it.
- **The people and the thread:** the guild thread (the war camps as the guild's workplaces; the pay meant for war-camp
  workers too); Vell and Mardra; Audra Wainholt and Greda Stonehaul where they belong.
- **The joins:** the join at 41 (§2a point 2) and the hand-off to the finale.
- **The free front threads by host:** the hosts and envoys (Toren, Nella, Alna, Borin, Eriath, Dorrin, Mariel; Drek,
  Yarra, Orrel, Vaska, Nalo, Thorga, Ossa); the optional group quests (the four at 50 standalone); the Throng's island
  pair.
- **New places and objects** where a step needs them, and foreman names only if a foreman enters the story.

There are no vanishing NPCs, and the fixed ids stay. Each open point gets two variants (K-points with a
recommendation). Astra adds a short list of what the structure needs. The report is in German.

**CHECK4 (Opus, read-only).** It checks the draft against the data and the system:

- every named NPC, place and object exists or is listed as new;
- the free/story rules and the group-quest rule;
- levels against the real front starts;
- profession-gated items;
- the pins it would move;
- what is expensive.

The coordinator folds in plain fixes.

**FRONTQUESTS (Opus).**

- **The files:** the 14 unflagged files (ten `.front`, four Battlegrounds) rebuilt and flagged (§2 point 1). The fortress
  quests are kept. The spine is `story` (§2 point 2), and everything else is free and standalone or has one follow-up.
- **Structure and size:** shared quests where the task repeats, including across factions (§2 points 4 and 7); local
  quests for each host's thread; counts before and after; zone size by the ledger (§2 point 6).
- **Variety:** objective variety and about three to five mob names per zone (§2 point 8).
- **Chapter 4:** the picks, the join, the group quests at 50, the gaps, the departures to Thorga and Ossa, the Throng's
  island pair.
- **Rewards:** §2 point 5, with the budget change in both validators and a fixture case.
- **Places and objects:** from the picks and §2 point 9.
- **Tools:**
  - the `validate.py` key;
  - the two ledger bugs;
  - the ledger 40→50 and 50→60 before and after (`ledger.py --game --track <race> --party solo`);
  - `quest_kinds.py --check`, then `tools/r28_regions/run.sh`, `guarantee.py --check`, `quest_targets.py`;
  - `validate.py --game` (0 errors);
  - the seed fleet `quick` if a place is added.
- **Placeholder texts.** The QUESTMAP page: Round 61's `r61/questmap` is the template.

**TEMPLATEFIX (Opus).** The defects of §2 point 10, fixed in the templates. The known-defects baseline shrinks to
what remains, and the town checks pass. Town placement is unchanged.

**BAGS (Opus).** The sizes of §2 point 11, the inventory page laid out for 20-slot bags, the docs and the pins; a
headless capture of the inventory with four large bags for the GUI checklist.

**STORYART (Astra).** Only if the picks add an object kind or a quest item: two proposals and a pick page (drop 03
shows the style).

**FRONTTEXT (Astra) and TEXTREVIEW (Opus).** As in Round 61, for the lane's quests, the spine's texts and their
completions, and the fortress quests' voice where it needs it.

**D.** It delivers:

- version 0.62.0 with the map-reset entry;
- CHANGELOG, STATUS, ROADMAP (the quest rework 11–60 complete; next the production deploy), BACKLOG and AGENTS;
- `quests.md` (the front section, the reward budget per band);
- the completion section;
- the joint GUI checklist extended with Round 62's items;
- **the deploy list:** the release gates (BACKLOG ~3828-3865) and the open names (cloaks, the "Miner's Guild"
  achievement), so that the deploy round starts from one list;
- a full seed fleet at the round's end.

## 5. Rules

The usual ones apply ([round workflow](../process/round-workflow.md)):

- one worktree and branch per lane;
- an independent Opus review per non-trivial lane, and a delta review for logic fixes;
- reviewers work in their own scratch copies, never in a check worktree;
- the Lua queue runs at most 8 processes at once;
- no pushes, merges or syncs by lanes;
- nothing unpicked ships;
- never `.claude/worktrees/ui-tab-hover` (the user's UI lane).
- **Fixtures:** each lane runs only its own fixture plus the fixtures that test the behaviour it changes, and the full
  run once before its report.

## 6. Verification

- **Gates:**
  - the full fixtures;
  - `check_fresh_server.py`;
  - `check_upgrade.py` (with the map-reset entry);
  - `validate.py --game` (0 errors with all 48 files flagged);
  - `quest_kinds.py --check` and `tools/r28_regions/run.sh`;
  - `quest_targets.py`, `guarantee.py --check`, `r38_names/check_rules.py --shipped`, `income.py --check`;
  - the seed fleet;
  - one boot per lane.
- **GUI checklist:** Round 62's items extend the joint checklist of 0.57 to 0.61.1
  ([Round 60's list](round60-plan.md#gui-checklist-rounds-57-58-59-60-61-the-ui-and-0611)). The draft:
  - a level-40 character of each faction through 41–60;
  - the main line with its completions;
  - the four group quests at 50 solo-skippable;
  - the departures to Thorga and Ossa;
  - the island pairs;
  - the reward choices at T5/T6;
  - the template fixes;
  - the new bag sizes (an old character's equipped bags grow on first join, their items kept; four 20-slot bags on the
    inventory page).

## 7. Orchestration notes

- **Order:**
  1. The §2a answers (done) and the plan review.
  2. CHAPTER4, with TEMPLATEFIX and BAGS beside it.
  3. CHECK4.
  4. The user's picks.
  5. FRONTQUESTS.
  6. The QUESTMAP verdict.
  7. STORYART (if needed) and FRONTTEXT from main, then TEXTREVIEW.
  8. D last.
- **The GUI test of 0.57–0.61.1** runs in parallel. A fix it needs becomes a small FIX lane that merges first.

## 8. Engine and code facts (from the survey; re-check in the briefs)

- **Size:** 127 quests at 41–60. There are 108 in the 14 unflagged files, 15 main-line steps in the contested base
  files and 4 guild gathers; the objectives are 110 kill, 22 item, 16 talk and 18 use.
- **Givers:** no giver stands in a front zone except the 16 war-camp foremen, and their two lines (`camp`, `guild`)
  are full. Hosts and envoys give from their own zones. A `.front` file holds `zone`, `quests` and `notes`. A front
  quest has one giver; shared quests live in a base file.
- **Dry run:** with all 14 flagged, 60 errors (the survey). With the whole 31-id spine `story`, 11; with the spine's
  10 non-spine `requires` dropped, 10; with the 32 non-spine free `requires` dropped (fortress chains and story kept),
  **0** in `validate.py`, and the game loader passes (plan review M1). The Battlegrounds files give 0.
- **Rewards:** today no 41–60 quest gives equipment, a potion or a trinket. The six contested zones' budgets are full.
- **Ledger solo, questing share:** 86–91 % at 40→50 and 69–85 % at 50→60. The Throng needs about twice the Accord's
  free play at 50→60.
- **Free places:** the clash sites 076, 079, 080, 083 and 085, and the `held_load` in Stormvault and Glassroot. There
  are no recipe places in front zones and no `held_load` in the war camps.
- **Fixed in code:** `rift_core.lua:79` (four main-line ids) and the achievements' `quest:*_main_final`.

## 9. Later

The production deploy with one map reset (0.57.0 → 0.62.0 on the user's world), then the armour redesign and the
unique items.
