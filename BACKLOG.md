# Backlog — Work Packages

Current implementation work and remaining scope. [Design](docs/design/README.md)
owns game rules; [ROADMAP](ROADMAP.md) owns goals; [project status](docs/STATUS.md)
owns the latest local/remote delivery and GUI acceptance. Completed implementation
narratives are [historical receipts](docs/archive/planning/backlog-before-consolidation.md),
not additional current contracts. No behavior changes are authorized by this cleanup.

## Readiness

There are **54 identities**: WP0–WP50 and WP-Scout/WP-HUD/WP-Speed.
**47 delivered**, **3 canceled** (WP16, WP37, WP49), **4 open or partial**
(WP34, WP42, WP46, WP48).
The 2026-09-29
[WP audit](docs/planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
closed WP14, WP21, WP22, WP23, WP27, WP29, WP31 and WP32 as delivered, merged WP7's rebase, WP11, WP30 and the price parts of WP22 and
WP31 into WP44 (WP11 and WP30 count as delivered), and canceled WP37 and WP49.
WP28 followed in Round 26, WP50 in Round 27, WP17 and WP44 in Round 29, WP41
in Round 31 (with WP42's PvP-POI part), WP5 and WP10 in Round 33, WP9 and
WP13 in Round 36. The audit's letters and numbers (for
example E5) are cited below.

- **Latest delivery:
  [Round 45 "Crafting rework"](docs/planning/round45-plan.md#completion-2026-10-09)
  complete, 0.45.0 not pushed** (2026-10-09, `4a892fd6` and lane D,
  version 0.45.0, **migrate**: the second declared step; GUI test open):
  Round B of the UI rework — the recipe registry and the Crafting tab
  instead of the grid and the books, crafting jobs with the output area,
  gear only from professions, the item level ladder, enchants and
  upgrades as jobs, proximity stations, Cooking from the start, finished
  potions, Grudge-Free Repairs; the playtest's fix lanes (inventory
  window, shift-click inbox, mounts, mobs, station sounds, the Claim Stone
  as a waypoint) and the user's art picks; step 0.45.0 removes mixtures,
  empties the craft grid and pins old gear's item level offline
  ([Round 45](#round-45--crafting-rework),
  [carry-overs](#round-45-carry-overs)).
- [Round 44 "Inventory, map and quickbar"](docs/planning/round44-plan.md#completion-2026-10-09)
  (2026-10-09, `36019071` and lanes MS and D, version 0.44.0,
  **migrate**: the first declared step; pushed by the user on 2026-10-09
  inside `2f918739`; GUI test open):
  Round A of the UI rework — the window with fixed tabs, the give helper,
  bags in bags, Sort and the potion belt, the Character tab, Talents &
  Skills with hotbar-only skills, Party & PvP, the baked pixel-art map,
  the map window with the quest log and targets on Z, the quickbar on E;
  step 0.44.0 removes mount items and skills outside the hotbar offline
  ([Round 44](#round-44--inventory-map-and-quickbar),
  [carry-overs](#round-44-carry-overs)).
- [Round 43 "World migrations"](docs/planning/round43-plan.md#completion-2026-10-08)
  (2026-10-08, `d10018a7` and lane D, version 0.43.0, compatible, pushed
  2026-10-09 as `9dc2fad5`; GUI test open): the migration tool, the world
  version record, the start guard and the online-work runner, with an
  empty `migrate` list ([Round 43](#round-43--world-migrations),
  [carry-overs](#round-43-carry-overs)).
- [Round 42 "Mob navigation"](docs/planning/round42-plan.md#completion-2026-10-08)
  (2026-10-08, `f8265d60` and lane D, version 0.42.0, compatible,
  playtest accepted, pushed 2026-10-08 as `332c5e79`): one navigation module on the
  engine's pathfinder for combat, fixed walks and settlement walkers, a
  route cache in start towns and capitals, capital patrols along the
  streets, NPCs that use doors, no random stops on routes
  ([Round 42](#round-42--mob-navigation),
  [carry-overs](#round-42-carry-overs)).
- [Round 41 "Playtest fixes, the production crash and the upgrade contract"](docs/planning/round41-plan.md#completion-2026-10-07)
  (2026-10-07, `a3790e65` and lane D, version 0.41.0, pushed 2026-10-08 as
  `71612d19`; the production server moves to it with a map reset; GUI
  test open): release mode and the hosting platform's
  [upgrade contract](docs/technical/upgrade-contract.md) with its map
  reset; the production crash loop fixed and mapgen failures reported as
  `[GRUG-SEVERE]` instead of stopping the server; the Round 40 playtest
  fixes (walk animation, kings and Generals at their seat, the recipe
  book's Close and multi-item slots, the bow's missed release, the quiver
  total, stale map tiles, the waterweed bed)
  ([Round 41](#round-41--playtest-fixes-the-production-crash-and-the-upgrade-contract),
  [carry-overs](#round-41-carry-overs)).
- [Round 40 "Combat feel"](docs/planning/round40-plan.md#completion-2026-10-06)
  (2026-10-06, `bd52bbf4` and lane D, pushed; its follow-up 0.40.1, ore
  wherever digging is allowed, pushed 2026-10-07; no new world needed;
  GUI test open): the cooldown overlay on the hotbar
  instead of the wear bar, poses and the head look, Charge as a dash,
  particle effects for player skills, bosses and mob specials with
  `grug_particle_scale` ([Round 40](#round-40--combat-feel),
  [carry-overs](#round-40-carry-overs)).
- [Round 39 "Web data for the realm website"](docs/planning/round39-web-data-plan.md#completion-2026-10-06)
  (2026-10-06, pushed 2026-10-06 as `d018d866`, GUI-accepted): no gameplay
  change; the level and appearance in player meta, the exported web data
  and the player model as glTF for realm websites
  ([Round 39](#round-39--web-data-for-the-realm-website),
  [carry-overs](#round-39-carry-overs)).
- [Round 38 "Mob names"](docs/planning/round38-mob-names-plan.md#completion-2026-10-06)
  (2026-10-06, `ec2e874c` and lane D, pushed 2026-10-06; a
  fresh world for the test; GUI test open): new names for every mob slot
  from the user's picks, a kill counted by the shown name (the quest
  kill-credit bug fixed), quest texts on the names, the whelps at level
  60, the Kraken, twelve item names, Party instead of Group
  ([Round 38](#round-38--mob-names),
  [carry-overs](#round-38-carry-overs)).
- [Round 37 "Audit fixes"](docs/planning/round37-plan.md#completion-2026-10-06)
  (2026-10-06, `27e5db87` and lane D, pushed 2026-10-06 as `db848931`; no new
  world beyond Round 36's; GUI test open): the
  [October 2026 audit](docs/audit-2026-10/README.md)'s code packages P1–P5
  (the combat hot path, mob behaviour, mob persistence and bosses, the
  interaction bugs, per-player polling), MGT-02 with P7 (mapgen), P9
  (sound) and the documentation packages A–F, plus the user's rulings of
  2026-10-06 (start zones fight alone, the Reef Lurker, the minimap at
  normal quality, mob projectiles push)
  ([Round 37](#round-37--audit-fixes),
  [carry-overs](#round-37-carry-overs)).
- [Round 36 "The main questline"](docs/planning/round36-plan.md#completion-2026-10-05)
  (2026-10-05, pushed 2026-10-05 as `0f169898` with the follow-up lanes;
  needs a world made on `fef94a6a` or later; GUI test open): WP9
  delivered — each faction's main line from its fortress Warmaster in
  three chapters (41, 46, 53) and a party finale at 60 on the
  approved [story bible](docs/planning/round36/story-bible.md), the "use at
  a place" objective with quest objects, the turn-in hook and three
  achievements (E, Q0, Q-A, Q-T, T, A); the rift with Isquarre the
  Tithe-Eater and two war commanders (R); WP13's POI review on a render
  page (P) and the decor pass over every POI, start town and capital house
  (W); one target predicate with "Evading", free mobs evading only from
  outside their wander radius, the talent-point banner (F); Priest heals
  with gear Intelligence, the Scout's Dexterity curve, spell rounding (K);
  the dragons' wider hazards and wing gust (G); after the user's first look
  the held button across a hotbar switch (F2), benches with their back to
  the wall (W2), ground cover in the protected band round starts and
  capitals (W3) and smoother roads (RD)
  ([Round 36](#round-36--the-main-questline),
  [carry-overs](#round-36-carry-overs)).
- **GUI acceptance:** Rounds 25–35 count as GUI-accepted (the user,
  2026-10-05, [Round 37 plan](docs/planning/round37-plan.md) §2.3.5),
  Round 39 too (2026-10-06), Round 42's playtest (2026-10-08); Rounds
  36–38, 40, 41 and 43–45 are open ([project status](docs/STATUS.md)).
- [Round 35 "Fixes and character creation"](docs/planning/round35-plan.md#completion-2026-10-05)
  (2026-10-05, pushed 2026-10-05; its first GUI findings fed Round 36): the user's
  Round 34 GUI findings — the server's aiming rays test rotated selection
  boxes in Lua (T, with the
  [upstream-workaround list](docs/technical/upstream-workarounds.md)); music
  only in the six capitals, either music or the bed (M); the break sound,
  broken look, empty hand, dig sounds, flint removed, the quest list colours
  and read-only quest text (F); character creation in one window (C); night
  mobs leave at dawn and the drop audit (E); level-proof talents and the
  user's review picks (B)
  ([Round 35](#round-35--fixes-and-character-creation),
  [carry-overs](#round-35-carry-overs)).
- [Round 34 "Sound"](docs/planning/round34-plan.md#completion-2026-10-04)
  (2026-10-04, pushed 2026-10-05; the user's GUI test fed Round 35): V1's
  sound ([sound.md](docs/design/sound.md), [CREDITS.md](CREDITS.md)), every
  file picked by the user — effects, hits, ability cues and mob voices
  (S1a, S1b), ambience beds for every zone, loops, dragon-island thunder,
  music pools pushed on demand and the settings (S2); mobs in water (F1);
  text boxes, cooking costs, the Bag of Coins, service markers, the damage
  fit, encounter adds, thin ice (F2)
  ([Round 34](#round-34--sound), [carry-overs](#round-34-carry-overs)).
- [Round 33 "Items, professions and achievements"](docs/planning/round33-plan.md#completion-2026-10-04)
  (2026-10-04, pushed 2026-10-04 after Rounds 30–32; needs a fresh world): the
  items design session's rulings and their data
  ([item_tiers.md](docs/design/item_tiers.md), DS); drops by quality with
  boss double drops, bag drops and the level requirement on all gear (C1);
  Alchemy as a secondary, progress from real recipes and the removals (C2);
  per-character achievements and cloaks (C3); enchant values by item level
  with tiers, profession upgrades, the crown and the profession families
  (C4); crit ×2, T1-only vendors, repair ×1.00, potions I–VI, the
  Crownbinder and the Decor Merchant, the income model green (C5). WP5 and
  WP10 delivered; the user's test findings fed Round 34
  ([Round 33](#round-33--items-professions-and-achievements),
  [carry-overs](#round-33-carry-overs)).
- [Round 32 "Fixes, preparation and research"](docs/planning/round32-plan.md#completion-2026-10-03)
  (2026-10-03, pushed 2026-10-04, GUI-accepted): the minimap zoom ×2, hostile
  camps on the Map tab, zone names coloured by territory with a territory
  line (F1); one LMB hold state machine and quest kill labels with the
  zone's mob names (F2); combat and personal notices in the message feed
  and the quest log in one text field (F3); the Map tab, party HUD and
  camp/leader tick spread over steps (F4); three read-only studies
  (performance at 50/100 stand-ins, sound, items and professions)
  ([Round 32](#round-32--fixes-preparation-and-research),
  [carry-overs](#round-32-carry-overs)).
- [Round 31 "PvP, appearance and clean-up"](docs/planning/round31-plan.md#completion-2026-10-03)
  (2026-10-03, pushed 2026-10-03, GUI-accepted): WP41 geographic PvP (the
  per-player flag, the PvP tab and markers, the NPC faction filter, PvP from
  depth tier T4), WP42's PvP-POI part (a fortress per faction, 16
  Battlegrounds war camps, garrisons with Generals and named captains, 24
  fortress quests), the appearance package (looks at creation, NPC look
  rolls, enchant colours), the dragon arena redesign and the Round 31
  clean-up lane
  ([Round 31](#round-31--pvp-appearance-and-clean-up),
  [carry-overs](#round-31-carry-overs)).
- [Round 30 "Performance and clean-up"](docs/planning/round30-plan.md#completion-2026-10-02)
  (2026-10-02, pushed 2026-10-03, GUI-accepted): the
  [performance review](docs/research/perf-review-2026-10.md)'s lanes P1–P4
  (quest-state cache and Map tab every 2 s, the region-map file cache and boot
  memory, the per-step A* budget with the give-up of unreachable targets and
  three merged spawn ABMs, per-player ticks), Return home on the Character
  page, piers and beaches at the dragon-island landings, the quest and fixture
  clean-up with the Dawnmere duplication fix, and the band-4/5 loot smoothing
  with recomputed prices ([Round 30](#round-30--performance),
  [carry-overs](#round-30-carry-overs)).
- [Round 29 "Economy and travel"](docs/planning/round29-plan.md#completion-2026-10-02)
  (2026-10-02, pushed as `e512bb5c` after the user's fresh-world test): 491 quests on the Round 28
  framework replace the 240 legacy quests (one track per race, the
  contested 31–40 zones, the 41–60 front with repeatable and island
  bounties; WP9 advances); WP44 delivered (one price module, 5% buy-back,
  income-derived mount, boat and respec prices, claim-station repair D7);
  WP17 delivered (boats as water mounts, the Shipwright, waystones at every
  start and capital, the Kraken retune); a mapgen bundle (gems by depth,
  `apex_sockets` removed, mapgen band data, the Battlegrounds 50 % wider
  with a middle road); the spawn playtest fixes; a read-only
  [performance review](docs/research/perf-review-2026-10.md), which became
  Round 30 ([carry-overs](#round-29-carry-overs)).
- [Round 28](docs/planning/round28-questing-leveling-plan.md#completion-2026-10-02)
  (2026-10-02, pushed): the 2026-09-30 playtest fixes, the questing and
  leveling framework, the catalogue with 89 icons and the naming rule,
  rule-based spawn regions for all 38 zones with the border rule,
  quest-log level ranges and zone names. It advanced WP5, WP6, WP8 and WP10.
- [Round 27](docs/planning/round27-minimap-plan.md#completion-2026-09-30)
  (2026-09-30; pushed): WP50 delivered — our own
  round minimap with quest, service, home and party markers in place of the
  native one, the `grug_map_quality` setting (normal/high) for the Map tab and
  the minimap, readable relief and the tiled map base (Lane M), and the
  documentation (Lane D). GUI-accepted.
- [Round 26](docs/planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29)
  (2026-09-29, pushed): Claim Stone draft and
  activation with the Housing Steward (Lane S), the registration cleanup
  (WP28 delivered, Lane R), the status-icon package (audit D10, Lane I),
  organic capitals with a character per capital (the D72 follow-up, Lane W)
  and its documentation cleanup (Lane D). GUI-accepted.
  Not in that round: the depth pulse (WP34), WP44, WP17, WP41, WP9, WP5 and
  WP10.
- Round 25 delivers WP24 Housing (pushed, GUI-accepted). Round 24 is
  pushed (`d4eaffff`) and accepted.
- **V1 scope** ([ROADMAP](ROADMAP.md#v1-scope)): WP17 boats and waypoints (starts,
  capitals and, since Round 31, the PvP fortresses), WP41 geographic PvP and
  WP9's story levels 41–60 with the finale are V1; WP42's scripted NPC
  battles come after V1, its small PvP POIs shipped in Round 31. **Sound is
  V1** (the user, 2026-10-03), delivered in Round 34
  ([Sound](#sound-v1-user-2026-10-03-delivered-in-round-34)).
- **Removed systems** (never to be built): renewable ores and camp sockets
  (E5), natural out-of-combat HP regeneration and rested XP (WP21: food is the
  recovery system), carried torch light (C5), the dragon hoard chest (E11) and
  `/unstuck` (B3).
- Open work without its own WP: friendly-guard healing stays deferred as a
  coherent support-combat feature (rule owner `combat_stats.md`); the T6 lava
  lakes of `world.md` §4c stay planned (E3) with no scheduled owner. Repair at
  crafting stations inside a claim (D7) shipped in Round 29; since Round 45
  only player-placed furnaces and dual furnaces offer it (the user leans to
  repair only in towns, [Round 45 carry-overs](#round-45-carry-overs)).
- **October 2026 audit:** the design questions that block no fix are in
  [Audit 2026-10 open questions](#audit-2026-10-open-questions), the fix
  packages after Round 37 in
  [later fix packages](#audit-2026-10-later-fix-packages).

“Delivered” records the package's bounded development delivery. It does not mean
all later refinements, release gates or user GUI checks have passed. Historical
technical evidence certifies its recorded bytes, never an arbitrary later head.

## Phase 1 (MVP)

| WP | Scope | Status / remaining work | Dependencies |
|----|-------|-------------------------|--------------|
| WP0 | Game foundation | Delivered; historical receipt below. Current rules: topic design. | — |
| WP1 | Starter mobs, XP and drops | Delivered; historical receipt below. Current rules: topic design. | — |
| WP2 | First territory mapgen (superseded by WP40) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP3 | Character creation and original classes | Delivered; historical receipt below. Current rules: topic design. | — |
| WP4 | Original ability framework | Delivered; historical receipt below. Current rules: topic design. | — |
| WP5 | [Loot, found-item affixes and cultural/PvP finishes](docs/planning/work-package-scopes.md#wp5) | **Delivered in Round 33** ([completion](docs/planning/round33-plan.md#completion-2026-10-04)): drops by quality (normal 5/2/1 %, named and elite 10/10/5 %), boss double drops at item level 65/70 with T7 enchants, shields, spellbooks and trinkets in the pool, bag world drops, the level requirement on all gear; enchant values by item level with a tier cap ([item_tiers.md](docs/design/item_tiers.md)). The cultural and PvP finishes were removed by the user (round33-plan §2.8); the crown (a Fallen Crown lifts an item to its tier's top + 5, enchants +1 tier) takes the place of the Grudgeforged masterwork (D3). Named rares drop no trophies (D4). Round 28's loot by band and Round 29's payout calibration came before. | WP1 ✅, WP3 ✅, WP43 ✅ |
| WP6 | Mob roster, threat, guards and combat feel | Delivered; historical receipt below. Round 28 adds sub-types (195 incl. 49 named leaders) and rule-based spawn regions for all 38 zones ([spawn_regions.md](docs/design/spawn_regions.md)); Round 29 sets leader HP to 1.5×; Round 30 lets mobs give up unreachable targets, merges the spawn ABMs and fixes the start-NPC duplication. Round 31 adds NPC look rolls, the PvP garrisons (Generals, bodyguards, camp captains) and the round dragon arenas. Round 42 replaces the stuck handling with navigation on the engine's pathfinder (combat, fixed walks, settlement walkers, doors). Current rules: topic design. | — |
| WP7 | Ledger currency and traders | Delivered; Round 29 (WP44) replaced its price curve and 25% buy-back. | — |
| WP8 | Quest framework | Framework delivered; Round 20: 240 quests with talk handoffs. Round 28: per-zone quest data, area, item-group, multi-objective and quest-drop objectives, repeatables, travel credit on accept, load-time validation, target level ranges in the log. Round 29: text placeholders filled per seed, the compass-word check, copper from weight. Round 30: the legacy fields removed (unknown fields stop the load), the decoded-state cache and markers that follow held items and levels. Round 31: givers serve only their faction, PvP garrison kill objectives, PvP POIs as placeholder targets. Broader story remains WP9. | — |
| WP9 | [Named-zone story and questlines](docs/planning/work-package-scopes.md#wp9) | **V1. Delivered in Round 36** ([completion](docs/planning/round36-plan.md#completion-2026-10-05), rules [quests.md](docs/design/quests.md) "The main line", [story.md](docs/design/story.md)): each faction's main line 41–60 from its fortress Warmaster (chapters at 41, 46, 53, the party finale at 60 on the rift boss) on the approved [story bible](docs/planning/round36/story-bible.md), the front climaxes folded in, the "use at a place" objective filling each contested zone's quest-interaction slot, ten corrupted sub-types, three achievements with cloaks; the rift at Tombroad Ambush. Before: Round 29's 491 quests on the Round 28 framework (a track per race, the contested 31–40 zones, the front with bounties), Round 31's 24 fortress quests; 540 quests now. GUI test open (Round 36). | WP6 ✅, WP8 ✅, WP40 ✅, WP41 ✅ |
| WP10 | [Profession content and priced integration](docs/planning/work-package-scopes.md#wp10) | **Delivered in Round 33** ([completion](docs/planning/round33-plan.md#completion-2026-10-04)): six primaries and the secondaries Cooking and Alchemy; progress only from real recipes; enchant recipes per channel and tier and one upgrade per profession and tier give 68 of 94 signatures a use; two professions dress each class (bows with the Leatherworker, spellbooks with the Tailor); fixed potions and elixirs T1–T6. Cultural finishing and its helper NPCs were removed by the user (round33-plan §2.8). Round 28 made every profession self-contained. | WP5 ✅, WP26 ✅, WP33 ✅, WP43 ✅, WP44 ✅ |
| WP11 | [Talent trees](docs/planning/work-package-scopes.md#wp11) | Delivered; closed 2026-09-29, respec price merged into WP44 (C2) and set in Round 29. | WP3 ✅, WP4 ✅, WP-Speed ✅ |
| WP-Scout | Scout class and talent trees | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-HUD | Exact health/resource HUD | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-Speed | Shared movement modifiers | Delivered; historical receipt below. Current rules: topic design. | — |
| WP12 | World atlas | Delivered through R19: whole-atlas zoom/scroll and live markers; waystone markers came with WP17 (Round 29). | — |
| WP13 | [Remaining authored structures and POI roster](docs/planning/work-package-scopes.md#wp13) | **Delivered** with Round 36's POI review: Round 20 completes roster art; Round 21 improves access/ground; Round 23 walls all six capitals. `bandit_frontier` core stays 16 (E1); Round 26 gives every capital its own outline and character (D72); Round 31 adds the PvP fortress and camp blueprints. Round 36: the separate POI walk (E2) became a render page of all 106 POIs with the user's verdicts, and the decor pass it asked for (a theme per POI kind, house touches in POIs, start towns and capitals; [settlements.md](docs/design/settlements.md) "Decor pass"); GUI check in the Round 36 checklist. | WP40 ✅, WP43 ✅ |
| WP14 | [Offhands](docs/planning/work-package-scopes.md#wp14) | Delivered; closed 2026-09-29. Carried light canceled (C5). | WP3 ✅ |
| WP15 | Character equipment and bags | Delivered; historical receipt below. Current rules: topic design. | — |
| WP16 | Canceled historical proposal | Canceled 2026-08-12; no game code shipped. | — |
| WP17 | [Boats and waypoint travel](docs/planning/work-package-scopes.md#wp17) | **V1.** Delivered in Round 29 ([travel plan completion](docs/planning/travel-boats-waypoints-plan.md#completion-2026-10-02)): boats as water mounts from the Shipwright in every capital (the only access to the dragon islands), waystones at every start and capital, the Kraken retune. No `/unstuck` (B3). The user's Round 29 test passed; Round 30 adds a pier and a beach at each island landing (`boats.md` §7.1). | WP40 ✅, WP13 ✅ |
| WP18 | First continent map (superseded by WP40) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP19 | Original kit and race-passive tuning | Delivered; historical receipt below. Current rules: topic design. | — |
| WP20 | Same-faction parties | Delivered R14–19: persistent parties, management and optional HUD. | — |
| WP21 | [Recovery/rest](docs/planning/work-package-scopes.md#wp21) | Food recovery delivered; closed 2026-09-29: food is the recovery system, no natural HP regeneration, no rested XP. | WP1 ✅ |
| WP22 | [Tool wear and repair](docs/planning/work-package-scopes.md#wp22) | Delivered; closed 2026-09-29. Dig speed stays as in the game (D8); prices to WP44; claim-station repair (D7) below. | WP43 ✅ |
| WP23 | [Dragon encounters](docs/planning/work-package-scopes.md#wp23) | Delivered R8–R10; closed 2026-09-29. Boat route → WP17, island PvP → WP41 (delivered); no hoard chest (E11), no apex sockets (E5). Round 31 redesigns the arenas (round leash arenas with hazards, `world.md` §4b). | — |
| WP24 | [Open-world Claim Stone Housing](docs/planning/work-package-scopes.md#wp24) | Delivered in Round 25 ([completion](docs/planning/round25-housing-plan.md#completion-2026-09-29)): Claim Stones as in `housing.md`, no price, housing masks removed; road and POI protection alongside. Round 26 Lane S adds the draft and 5-lump activation, the 12 h pick-up lock, the Housing Steward and admin removal. GUI-accepted with Rounds 25 and 26 (the user, 2026-10-05); carry-overs below. | WP40 |
| WP25 | Original strata/materials (superseded by WP43) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP26 | Furnace and alloy chain | Delivered; historical receipt below. Current rules: topic design. | — |
| WP27 | [Armor catalog](docs/planning/work-package-scopes.md#wp27) | Delivered; closed 2026-09-29 (no G2 surcharge, Round 10 ruling 7). | WP26 ✅, WP43 ✅ |
| WP28 | [Remove superseded recipe/tool registrations](docs/planning/work-package-scopes.md#wp28) | Delivered in Round 26 Lane R: mobs_redo utility items removed (D5), silver-sandstone recipes removed (D6), all tier tools under `grug_materials:` with 12 aliases (D9), two surface critters at 0.75 density, `chance` 2200 → 2933 (C6). | — |
| WP29 | [Gear/tool catalog](docs/planning/work-package-scopes.md#wp29) | Delivered; closed 2026-09-29. Tool-namespace unification moved to WP28. | WP26 ✅, WP43 ✅ |
| WP30 | [Trader catalog](docs/planning/work-package-scopes.md#wp30) | Catalog delivered; closed 2026-09-29, prices merged into WP44 (C2). | — |
| WP31 | [Mounts](docs/planning/work-package-scopes.md#wp31) | Delivered (C3); prices merged into WP44 and set in Round 29; boats are the water mode since Round 29. | WP40 ✅ |
| WP32 | [Farming](docs/planning/work-package-scopes.md#wp32) | Delivered 2026-09-29 (C4), GUI-accepted with Rounds 25–35 (the user, 2026-10-05); Claim Stone integration shipped with WP24. | WP24 ✅, WP33 ✅ |
| WP33 | Gathering/source catalog | Delivered; Round 23 replaces exact-baseline renewal with habitat-driven renewal ([receipt](docs/research/round23-habitat-renewal.md)). Current rules: topic design. | — |
| WP34 | [Deep spawn pulse](docs/planning/work-package-scopes.md#wp34) | Only the depth pulse remains; kept, for later (E5). Renewable camp resources removed. the Land Guard and the Rift Spawn's deep row join the pulse (E4); placement and servant roster open. | WP6 ✅, WP40 ✅ |
| WP35 | Equipped weapon source and appearance | Delivered; historical receipt below. Current rules: topic design. | — |
| WP36 | Reference submodules and first runtime fixes | Delivered; historical receipt below. Current rules: topic design. | — |
| WP37 | [Surface-density cut](docs/planning/work-package-scopes.md#wp37) | Canceled 2026-09-29: superseded by Round 24 ruling 27 (about 1.5× density). Only Bone Weevil and Bog Fowl get 0.75 density (`chance` 2200 → 2933), delivered with WP28 (C6). | WP6 ✅ |
| WP38 | Held melee timing and settlement | Delivered; historical receipt below. Current rules: topic design. | — |
| WP39 | Crosshair-authoritative combat | Delivered; historical receipt below. Current rules: topic design. | — |
| WP40 | Named-zone world foundation | Development delivery accepted; first-public-release gates remain open. | — |
| WP41 | [Geographic PvP](docs/planning/work-package-scopes.md#wp41) | **V1.** Delivered in Round 31 ([completion](docs/planning/round31-plan.md#completion-2026-10-03), rules [pvp.md](docs/design/pvp.md)): a per-player flag (location, button, contact) instead of the old transaction; the PvP tab, icons, banner and target frame; the NPC faction filter; PvP from depth T4. GUI-accepted with Round 31 (the user, 2026-10-05); the engineering brief is historical. | WP39 ✅, WP40 ✅ |
| WP42 | [Bounded war-front encounters](docs/planning/work-package-scopes.md#wp42) | **After V1** (scripted battles). The PvP-POI part shipped in Round 31: two fortresses and 16 Battlegrounds war camps with garrisons and quests ([pvp.md](docs/design/pvp.md) §6). Clash anchors and art delivered; no war-unit runtime. | WP13 ✅, WP40 ✅ |
| WP43 | Canonical material/depth registry | Delivered; Round 24 replaces pick depth bounds and shatter with tier rock and engine-native gating (rulings 1–8). Current rules: topic design. | — |
| WP44 | [Economy rebase, lighter pass](docs/planning/work-package-scopes.md#wp44) | Delivered in Round 29 ([lane status](docs/planning/economy-vendor-plan.md#lane-status-round-29-2026-10-02)): one price module for every payout, 5% buy-back on vendor goods, the vendor rule and shelves, the audit fixes, quest copper from weight, repair at claim stations (D7), mount, boat and respec prices from a simple income estimate (D1, D2); gems by depth. The user's Round 29 test passed; Round 30 smooths the band-4/5 loot medians and recomputes Expert Riding and two respec prices. | WP7 ✅, WP43 ✅ |
| WP45 | Character-creation stasis and safe arrival | Delivered; Round 24 makes creation pausable (ruling 32). Current rules: topic design. | — |
| WP46 | Indirect terrain-damage guard | Partial: actor-neutral guard and protected water flow delivered; the fire/explosion remainder is deferred until a fire or explosion source exists (expected with V2's Nether) (E6). | WP40 ✅, WP24 ✅ |
| WP47 | Skills catalog and recoverable representations | Delivered R12–13; current rules in inventory_equipment.md. | — |
| WP48 | Mapgen writer performance and parallel emerge | Partial; parked until a playtest shows slowness (E8). | WP40 ✅ |
| WP49 | Fixed mapgen source-audit roster | Canceled 2026-09-29: its audit script was deleted in Round 22 (D1/D3/D22). | — |
| WP50 | [Own minimap and map quality](docs/planning/work-package-scopes.md#wp50) | Delivered in Round 27 ([completion](docs/planning/round27-minimap-plan.md#completion-2026-09-30)): our own round minimap on the pre-generated map with quest-giver, service, home and party markers; native minimap off; `grug_map_quality` normal/high shared with the Map tab; readable relief; 512 px tiles. GUI-accepted with Round 27 (the user, 2026-10-05); carry-overs below. | WP40 ✅, WP24 ✅ |

### WP46 — Terrain-damage guard: explosions, fire and lava never damage settlements or POIs

**Partial; the remainder is deferred until a fire or explosion source
exists** (E6, user decision 2026-09-29), expected with V2's Nether.
Round 11 delivers the neutral `grug_core.world_alterable` authority and the
protected ordinary/river-water flow for buckets. Nothing in the game damages
terrain today: there is no `fire` and no `tnt` mod, lava is natural only (no
bucket), the Rift Spawn explodes with terrain radius 0, and the dragon
rime/scorch effects write only into air and restore it by timer. The risk is
future content (Nether V2 fire, later explosive mobs, TNT, lava buckets).

Requirement (user 2026-09-19, extended 2026-09-29): explosions (mobs and
players) must not damage capitals, starts, landmarks and POIs, and fire must
never spread into them. A future fire or explosion guard also spares **roads
and the building cores of POIs, villages and camps** (E7, `world.md` §2 R1b).
Today `world_alterable` does not consult that Round 25 layer
(`grug_core.world_feature_at`); a future consumer must.

When the work is scheduled (with the first fire or explosion source):

1. **One guard predicate in `grug_core`**, actor-neutral, asked per node by
   every effect that changes nodes on its own (not through a player's
   dig/place, which `core.is_protected` already covers): mob explosions, fire
   spread, lava flow into non-natural nodes, boss ground effects. It covers
   the hard-protected capital cities and start towns, landmark and functional
   footprints, road corridors and POI boxes; Claim Stone claims guard only
   their arrival cube (claim protection against explosions and fire is not
   part of V1, Round 25).
2. **mobs_redo `explode` GRUG PATCH:** terrain damage stays radius 0, or the
   patched `mobs:boom` skips every node the guard refuses. Note:
   `mobs/api.lua` defaults `explosion_radius or 1`, so a new explode mob needs
   an explicit radius.
3. **Fire policy:** spread is an ABM that asks the guard per target node, has
   a burn budget per flame and never ignites settlement palettes; "eternal
   flame" nodes are decoration without spread.
4. **Lava:** mapgen keeps natural lava outside settlement and POI
   exclusions; a lava bucket, if ever added, is placement and already covered
   by `core.is_protected`.
5. **Repair safety net (optional):** an admin command that re-projects an
   authored settlement blueprint at its anchor.

Checks follow the Round 22 minimal policy: a small fixture of the guard and a
short headless probe, no KAT suite or static sweep.

### WP48 — Mapgen writer performance and parallel emerge

**Parked until a playtest shows that preparation or exploration is too slow**
(E8, user decision 2026-09-29). Performance numbers are comparisons, never
targets. The rest of this section is the record.

**Opened by the Round 9 MAP-C plateau attempt, 2026-09-19.** The WP40
writer spends its time in Lua post-processing per MODIFIED voxel (dirty-
intent scan, light-context scan, replay), with apparent fixed costs per
touched chunk slice: a v7 plateau that turns the whole sky below 441 into
stone-to-air writes raised emerge time by 30–70 % regardless of height,
and a bulk-clear fast path for the per-voxel resolution did not help
(evidence in `tools/r9_map_c/evidence/`, retired; git history keeps it).
Two levers, measured with the profiler's phase records before any change:

1. Make the post-processing loops proportional to changed runs instead of
   whole slices (Round 9 measurement: the writer was ~21 of 68 s over the
   profiler corpus; Rounds 22–24 changed the writer, so re-measure first,
   now aimed at underground chunks).
2. Move the deterministic per-chunk mapgen into Luanti's mapgen
   environment (`core.register_mapgen_script`, emerge-thread Lua states)
   and lift the pinned `num_emerge_threads = 1`; requires the global
   state (manifests, memoisation, mod storage) to become per-thread or
   read-only.

**Lever 2 is blocked by the engine (verified 2026-09-19):** Luanti issue
#9357 ("Mapgen: unfinished y-slices with num_emerge_threads > 1", open,
label non-trivial) makes v7/valleys/carpathian lose biome nodes, ores and
caves in the topmost/lowermost y-slice of mapchunks and truncates
decorations when more than one emerge thread runs; the engine therefore
enables multithreading by default only for singlenode
(`reference_projects/luanti/src/emerge.cpp:180-187`). The mapgen already
runs in the mapgen environment (`register_mapgen_script`), so the Lua side
is ready, but `num_emerge_threads = 1` stays pinned until the engine fixes
#9357 (PR #16224 pending) or the project moves to singlenode with its own
cave/ore generation, which `mapgen-control.md` rejected.

**R9-PERF substep implemented (2026-09-20):** three bounded
single-thread writer optimizations are complete: already-dirty liquid columns
short-circuit repeated neighbor scans, exact horizontal classification uses a
bounded FIFO while the lattice LRU grows from 4 to 16 entries, and composed R5
lighting is delegated to the final R6 transaction while standalone R5 keeps its
own lighting. All cold/disk measurements retain the same 97 owners, 49,664,000
voxels and content/param2/light digest. The measured sequence endpoint falls
from 77.572800 s to 64.187408 s (-17.26%); it reuses sequence endpoints and is
descriptive rather than a replicated fourth pair. The independent review found
no findings. Evidence, exact limits and the final PUC/LuaJIT parity digest are
recorded in [the R9-PERF completion record](docs/research/r9-perf-completion.md).
WP48 remains open: the engine threading block and broader changed-run
post-processing work are unchanged.

The v7 plateau (caves everywhere under the surface) is no longer a
performance question: Round 24 ruling 13 keeps caves out of the fill, and own
fill caves are only a possible later package (Round 22 D77(d)).

**Round 23 (2026-09-28)** (Phase 2 tree line: [receipt](docs/research/round23-tree-line.md)):
- Full-world preparation now covers the whole column players can trigger,
  from the neighbourhood's lowest bed minus reach up to above the flight
  ceiling.
- A writer fast path skips air chunks the writer provably cannot change.
- The Round 11 ecology main-environment `on_generated` is removed.
- Underground chunks remain the dominant Lua cost; they have no safe fast
  path yet.
- The engine threading block is unchanged. An own-engine patch was evaluated
  and deferred.
- [Receipt](docs/research/round23-full-column-preparation.md).

**Round 24 (2026-09-29):** output-identical P8 vein and layer-pass speedups
(218 of 218 chunks content-identical, about 20 % less Lua mapgen time), after
Lane B's ores and layers in the fill had cost mountain boxes about +20 %.
[Evidence](tools/r24_fill/evidence/b2.txt).

### WP49 — R7 source-audit refreeze on a fixed mapgen roster

**Canceled 2026-09-29** (C1). WP49 was to refreeze
`tools/wp40/r7/source_audit.sh` on a fixed mapgen roster (Round 9 ruling 43).
That script and the final micro were deleted in Round 22 (`66e3832e`, "retire
unused tools", D3/D22), and Round 22 D1 removed the PUC gate it served. The
frozen 157-file roster stays historical evidence only.

### Round 24 carry-overs

**Noted 2026-09-29** ([completion](docs/planning/round24-mining-underground-mobs-plan.md#completion-2026-09-29)); none blocks
the playtest.

- WP48: `tools/wp40/profile/instrument-settlement-stages.patch` no longer
  applies to `r6_settlement.lua` on main (stale since Round 22). Re-anchor it
  before the next stage profile.
- WP45: a one-time waiting-screen race when an Esc crosses a progress update.
- The "Requires level N" tooltip line does not relabel tool stacks from older
  worlds. This does not matter for fresh worlds.

### Round 25 carry-overs

**Noted 2026-09-29** ([completion](docs/planning/round25-housing-plan.md#completion-2026-09-29));
none blocks the playtest.

- **Capitals: more irregular wall outline and more variety** (user idea
  2026-09-29, audit A1–A5): **done in Round 26 Lane W.** The outline stays
  star-shaped inside the 512 reserved square; with the replan at +8 %/+16 %
  area the named-building drops went from 2 to 0 of 200 seeds.
- WP24: an admin command to remove a claim or an orphaned fuelled stone. A
  fuelled stone without a registry row (for example after a crash between the
  map save and the mod-storage save) cannot be dug by anyone (Lane A review).
  **Done in Round 26 Lane S:** `/claim_remove <player> | here | orphans`.
- WP24: a `buildable_to` node such as snow in the arrival cube cannot be dug,
  not even by the owner (arrival-cube placement guard). **Done in Round 26
  Lane S:** it is dug under the ordinary claim rules; placing stays refused.
- WP24: two touching claims can cover all three route points of one named
  rare and suppress its spawn (consequence of ruling 24). Accepted by the user
  (E12); no work.
- Housing follow-up: crafting stations inside an active claim repair at the
  trader price, as a convenience (D7, `durability_repair.md`). **Done in
  Round 29 Lane E1.**
- The per-run early-out in `world_protection` (Lane E) relies on dyadic road
  profiles (multiples of 1/16). Revisit if road profiles change.
- Remove `apex_sockets` from mapgen (E5). **Done in Round 29 Lane M-res.**

### Round 26 carry-overs

**Noted 2026-09-29** ([completion](docs/planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29));
none blocks the playtest. All are low priority.

- Capitals: Lethariel's south gatehouse sits slightly further over the civic
  lake (up to about 0.8 node); check it in the playtest.
- Capital planner hardening (optional): clamp to `rmax` after the partial
  smoothing, assert `POLY` ≥ 4, and guard a plaza that has no avenue.
- `tools/wp13/node_tiles.json` (generated) still lists `mobs:mob_repellent`;
  regenerate it. The Round 25 engine probes `tools/r25_claim_core/run.sh`
  and `tools/r25_interfaces/run.sh` assume the pre-draft Claim Stone; the
  current probe is `tools/r26_claim_activation/`.

### Round 27 carry-overs

**Noted 2026-09-30** ([completion](docs/planning/round27-minimap-plan.md#completion-2026-09-30));
none blocks the playtest.

- In start towns several minimap markers (quest givers, trainers, innkeeper)
  stack on top of each other; like the Map tab they are not clustered. The
  playtest decides whether this needs handling.
- A new home (innkeeper binding or Claim Stone) appears on the minimap up to
  5 s later: static markers refresh on quest changes and every 5 s.
- Minimap glide: delivered 2026-09-30 (the map glides under a centred arrow
  inside a pewter bezel, merged as `9c8ece8c`;
  [follow-up](docs/planning/round27-minimap-plan.md#follow-up-gliding-minimap-2026-09-30)).

### Round 28 carry-overs

**Noted 2026-10-02** ([completion](docs/planning/round28-questing-leveling-plan.md#completion-2026-10-02)).
The Round 29 content proposed here (quest files per race track, the
contested zones and the front; economy lanes E1–E5; WP17; the mapgen bundle
with gem depth tiers, `apex_sockets` removal, the wider Battlegrounds, the
middle road and mapgen band data) is **delivered in Round 29**
([completion](docs/planning/round29-plan.md#completion-2026-10-02)); its
inputs were the [quests plan](docs/planning/round29-quests-plan.md), the
[economy plan](docs/planning/economy-vendor-plan.md) and the
[boats and waypoints plan](docs/planning/travel-boats-waypoints-plan.md).

**Future package — outpost seed** (Round 28 plan item 46, user G8): a
player-placed seed in contested land spawns workers who build a small fort;
killing the workers and destroying the seed stops it. Specified after the
playtest of the front quests and bounties.

**Catalogue and loot:**

- Elite ideas never shipped (dropped from the catalogue ideas): Rat King,
  Old/Giant Boar, Silver Fox, Rotting Brute, an elite Giant Scorpion.
- Loot text pass (identical descriptions across tiers, "Spider Silk" from
  T5/T6 outlaws): **done in Round 29 Lane E1** (tier-distinct lines, shown as
  Raw Silk).
- Six of the 195 sub-types appear in no recipe (measured 2026-10-02): the
  optional cap-1 elites `causeway_construct`, `siege_war_construct`,
  `seam_mesa_golem`, `seam_stone_golem` and `crown_stone_golem` (a recipe
  roster cannot cap a role at one) and the Salt Reef Lurker. **The Reef
  Lurker is placed since Round 37 F** (the 51–60 shores of Gravesalt and
  Skyglass, user ruling 2026-10-06); the War Constructs are DW-04 below.

**Spawn regions:**

- Steep zones get no generated camp cells. Partly addressed in Round 29
  (M-geo): a camp with no block meeting every rule takes its flattest block
  up to slope 0.5.
- Camps sit in tight clusters in Mournfen and Bannerbreak.

**Quest system (Lane Q0 review notes, low severity):**

- The zone-band fallback of a target's level range ignores a definition's
  own min/max levels, and for zone-filtered kills the displayed zone and the
  zone used for the level fit can differ. Only legacy objectives reached
  these paths. **Round 30 Lane C** removed the zone filter with the legacy
  fields; the zone-band fallback now serves only a base mob in a zone
  without a recipe, which no shipped zone is.
- The game (Lua) and `tools/r28_design` (Python) disagree at edges on item
  sources.

**Zone names (Lane M1 notes):**

- On very small windows the entry banner and the flight warning may lack
  clearance.

### Round 29 carry-overs

**Noted 2026-10-02** ([completion](docs/planning/round29-plan.md#completion-2026-10-02));
none blocks the fresh-world playtest.

- **Riding tier purchase fixture:** no portable test buys riding tiers 1–4 at the shipped prices (the boats are covered; same code path). Add a loop to `tools/r29_b` or `tools/r29_e4` when that code is next touched (E4 review, 2026-10-02). **Done in Round 30 Lane C** (`tools/r29_b` section H).
- **Band-5 loot median smoothing** (user, 2026-10-02: prices kept for now).
  E1's band-5 median per kill lands above its target and band 4's below,
  so band 5's income rises ×3.6 over band 4 instead of ×2.5 and Expert
  Riding is steep (1g63s against 1g38s on the target axis; Master 7g33s
  against 8g76s). Smoothing the band medians would move the E4 prices
  (`tools/r29_e4/income.py --check`). A few band-3 loot outliers have no T3
  replacement. **Done in Round 30 Lane E:** band 4 39.0 → 43.6c, band 5
  147.6 → 119.5c; Expert Riding 1g37s, respec 31–40 2s and 41–50 6s; the
  band-3 outliers and band 6 stay (Round 30 carry-overs).
- **Quests the new format cannot express:** kill objectives name only
  spawn-recipe roles and leaders, so enemy-faction guard quests and PvP
  quests (which also need WP41's tag) have no form. A design step first.
  **Done in Round 31 Lane Q:** a kill objective may name a PvP garrison's
  area (enemy guards and captains); player kills stay excluded.
- **Legacy quest fields in code:** no shipped quest uses `mobs`, `zone`,
  fixed `xp`, `faction`/`race` gates or the line `legacy`, but
  `grug_quests` (`registry.lua`, `validate.lua` incl. `LEGACY_GUARDS`) and
  `tools/r28_design/validate.py` (`--legacy`, its README) still accept
  them. Remove in fresh-server mode. **Done in Round 30 Lane C:** unknown
  fields stop the load (`E-unknown-key`), `--legacy` is gone.
- **Possible bugs** (perf review side observations, not reproduced):
  Dawnmere once held 53 NPC objects after 13 logged placements (duplication?);
  mobs_redo `general_attack` raises the mob's eye height per candidate
  (`sp = s` aliases the position, then `sp.y = sp.y + 1` in the loop).
  **Both fixed in Round 30:** the duplication was real (Lane C: start NPCs
  whose block was saved and unloaded before their next deactivation came
  back twice; `start_npcs.lua` passes `_grug_unplaced` in the staticdata),
  the eye is a copy at the position + 1 (Lane P2).
- **Dragon-island landings** (final engine check 2026-10-02): the boat
  landings are mostly a one-node shore strip at y 1 with cliffs 40–130
  nodes high about 5 nodes inland (seed 42 both landings, seed 20261002 the
  south landing; the other was a real beach). The islands are boat-only, so
  stepping ashore may be hard or impossible. Mapgen: guarantee a walkable
  beach or ramp at each landing; check in the user's GUI playtest first.
  **Done in Round 30 Lane L:** a sand beach and a wooden pier at all four
  landings (`boats.md` §7.1); no path up the island, by design (the islands
  stay untamed, user 2026-10-02).
- **Pallcloth Den** (Blackwind Rise): its trail now joins the middle road,
  so it runs along the front; check in the playtest.
- **Thin front areas:** Gravesalt `tomb_fen` forms only 1–2 regions on some
  seeds (2.6 % of the land on seed 1234) and Shattered Line `siegecrest`
  3.8 % on seed 314159; their quest targets form on all six checked seeds.
  Blackwind Rise's bandit hideout uses the camp slope fallback on seeds 42,
  2 and 99 (0.42–0.47; accepted). Mournfen's camp belt warns on seed 99999
  in the region renderer.
- **Stale fixtures:** `tools/r24_density_xp/fixture.lua` and
  `tools/r25_spawn_guard/fixture.lua` fail on main: `r24_density_xp/
  roster.lua` reads the removed `grug_mobs/wp40/r7_settlement.lua`.
  **Done in Round 30 Lane C:** `r25_spawn_guard` repaired, the
  `r24_density_xp` fixture deleted (its palette budget applies to no zone),
  `r27_quest_item_names` repaired too.
- Smaller notes: the POI "West Trench Mouth" trips the compass-word rule
  (quests must not name it); T1 trinkets keep Cut Quartz (accepted); the
  bronze tool stock against the gear axis and base-mob fallback drops (E1
  review notes).

### Round 30 — performance

**Delivered 2026-10-02**
([completion](docs/planning/round30-plan.md#completion-2026-10-02)): every
item below shipped (#22, an investigation, as a proposal); the before/after numbers and the rulings made during
the round are in the completion section, open notes in
[Round 30 carry-overs](#round-30-carry-overs). The record as planned, from
the read-only
[performance review](docs/research/perf-review-2026-10.md) (§5 lane
split; numbers are comparisons, never targets). Rulings of 2026-10-02:

- **#4 yes:** mobs give up a static target they cannot reach instead of
  repeating a full no-path A* forever.
- **Region-map file cache yes** (#2, design in §3 of the report): boot
  9.5 s of region-map builds → about 2 ms of loading.
- **#3 Map tab:** the arrow and the rebuild at most every 2 s, a rebuild
  only when the marker signature changes, one shared marker style.
- **#11 spawn ABMs:** retire the surface spawn ABMs where the region
  spawner is authoritative; merge the rest (underground, ocean, rift) into a
  few ABMs.
- The other findings as the report recommends.

Lanes:

- **P1 Quest state and map UI:** #1 (quest state deserialized per giver),
  #5 (tracker HUD in one step), #3 (Map tab), #12 (minimap glide), the NPC
  tag callback part of #10.
- **P2 Mob pathing and allocation:** #4, #13 (stuck patrol A*), #6
  (`get_properties()` per step), #17 (privilege checks), #18 (`mobs_can_hear
  = false`), and #11 (spawn ABMs).
- **P3 Region-map cache and boot memory:** #2, #9, #20, #21; investigate
  #22 (grug_mapgen load on a cache hit).
- **P4 Per-player ticks and misc:** #7 (crafting recipe scan), #8
  (crosshair rays), #10 (tag-carrier slotting), #14, #15, #16, #19.

Order: P1 and P3 in parallel, then P2 and P4; each lane re-runs its probe
as a before/after comparison. All four delivered, with a P1 follow-up
(Return home on the Character page, user ruling) and P1b (markers follow
held objective items and level changes).

Also in Round 30 beside the performance lanes (user, 2026-10-02):

- **Island landings (mapgen):** each dragon-island boat landing gets a simple
  wooden pier and a little beach, so a player can step ashore from a boat
  ([Round 29 carry-overs](#round-29-carry-overs)). This narrows the travel
  plan's "no docks" scope for these landings only. **Done (Lane L).**
- **Clean-up after the quest rebuild:** drop the legacy quest fields the loader,
  validator and `validate.py --legacy` still accept; repair the stale fixtures
  `tools/r24_density_xp` and `tools/r25_spawn_guard`; add the riding-tier
  purchase fixture; look at the 18 "No craft recipe known for output" boot
  warnings (leathers, bolts, woods; `clear_craft` calls). **Done (Lane C),**
  all four; the 18 calls were no-ops and are removed.
- **Possible bugs** from the performance review: the Dawnmere NPC duplication
  (seen once) and the mobs_redo `general_attack` eye height (with P2).
  **Both fixed (Lanes C and P2).**
- **Band-5 loot median smoothing** (Expert riding steep; prices recomputed with
  `tools/r29_e4/income.py` afterwards). **Done (Lane E).**

Planned next (user, 2026-10-02): Round 31 PvP (WP41 with enemy-guard quest
objectives and small PvP POIs from WP42, planned in its own design session),
Round 32 the WP9 main storyline 41–60 and the finale. (Round 32 became
fixes and studies; WP9 moved to a later round, 2026-10-03.)

**Dragon arena design iteration** (user, 2026-10-02; next round, a small
design step first; **done in Round 31, lanes DA and DA2**:
[round31-dragon-arenas.md](docs/planning/round31-dragon-arenas.md)): the ice dragon (Wyrmglass) stands on a square, rather
plain terrace (the jungle dragon's arena is to be checked). The arena core
(32 nodes, `simple_map.lua` POI kind `dragon`, `arena_terrace`) is already
protected as a POI core (`grug_core.world_feature_at`; the dragon's own
breath patches are exempt), so terrain can shape the fight: lava pits,
spiked pillars, cover, height and similar hazards, per dragon. The islands
themselves stay untamed: no mapgen paths or roads by design (user
2026-10-02, `boats.md` §7.1).

### Round 30 carry-overs

**Noted 2026-10-02** ([completion](docs/planning/round30-plan.md#completion-2026-10-02));
none blocks the fresh-world playtest. Numbers are comparisons, never targets.

**Round 31 clean-up lane** (user, 2026-10-03): the small code follow-ups
below go into one clean-up lane of Round 31: the cold-build heap (drop the
zone-query caches after a build), the held objective counts capped at
`min(count, needed)`, `changed()` also after a failed turn-in reward, the
zone-grid encode assert inside the pcall, and one runner script that starts
every `tools/*` fixture with its right arguments (several `fixture.lua`
files need the repository path). The #22 proposal stays the user's call; the
Map tab strip and the crosshair timing wait for the GUI test. **Done in
Round 31 Lane C** (all five: first-start heap 149 → 110 MiB at the first
step, `tools/run_fixtures.sh`); the cache keys that omit the mapgen data
files and the engine version stay as noted.

- **grug_mapgen warm load (perf review #22, proposal; the user decides):** on
  a cache hit grug_mapgen still spends about 6.35 s loading (settlement
  preparation 4.09 s, the capitals about 3.5 s). Storing
  `prepared_handover()` as a fifth section of the world-layout cache (D71)
  would cut that part 4.6 → about 1.2 s; size M, risk medium (the manifest
  SHA must stay covered).
- **Region-map cache (P3 review notes):** a cold build still peaks at about
  150 MiB of Lua heap, because the zone-query caches are kept for the session;
  the zone-grid encode assert (more than 255 zones) sits outside the pcall
  that turns a cache failure into a rebuild, while the rehydrate asserts sit
  inside the build pcall; the mapgen data files and the engine version are
  not part of the cache keys (the same holds for the D71 world-layout cache).
- **Quest markers (P1b review notes):** held objective counts are not capped
  at what the objective needs, so over-gathering re-computes the markers on
  each 0.5 s tracker poll (refine to `min(count, needed)`); a turn-in whose
  reward fails skips `changed()` (pre-existing).
- **Economy:** band 6 pays 0.80 of its target axis (239.3c against about
  300c), so Master Riding stays 7g33s against about 8g76s on the axis; the
  band-3 outliers (Crocodile Tooth, Shiny Scale; T4 items in bands 2–3) stay
  because no T3 replacement exists
  ([economy plan](docs/planning/economy-vendor-plan.md#band-smoothing-round-30-2026-10-02)).
- **Mob give-up (P2 notes, for the GUI test):** a player who keeps
  re-aggroing a mob from a closed house or other hidden spot gets it fully healed at
  each give-up (about every 7 s; since Round 42 the veto lasts until the
  player moved 8 nodes or 15 s passed); P2's one-seed count run showed +55 % spawn
  attempts in a shallow cave, judged run noise (the merged dispatcher keeps
  every row's rate by construction).

### Round 31 — PvP, appearance and clean-up

**Delivered 2026-10-03**
([completion](docs/planning/round31-plan.md#completion-2026-10-03), plan
[round31-plan.md](docs/planning/round31-plan.md) with
[pvp-plan.md](docs/planning/pvp-plan.md)); every code lane independently
reviewed by Opus (the small follow-ups M2 and G2 checked by the coordinator),
the rules as built in [pvp.md](docs/design/pvp.md):

- **WP41 geographic PvP delivered** (P1, P2, P1b, P1c): `grug_pvp` with the
  per-player flag, one-way support, 10 s PvP combat, logout death and kill
  credit; the PvP tab, status icons, banner subtitle and target-frame
  marker; PvP and building rights in the depths from T4 (y ≤ −501).
- **NPC faction filter** (N): services, quest givers and waystones serve
  only their own faction; map and minimap markers per viewer faction.
- **WP42 PvP-POI part delivered** (S, M, M2, G, G2, Q, names): the two
  fortresses and 16 Battlegrounds war camps, placed, protected and
  garrisoned (Generals with bodyguards, named captains as leaders), seven
  waystones per faction, enemy settlement icons hidden, 24 fortress quests
  from level 40 with GPT-6 Astra texts.
- **Appearance package** (A, B): character looks at creation, NPC look
  rolls, the helmet face window, equal hitboxes for races and mounts,
  enchant colours on items, held and dropped stacks, worn armour and the
  kings' weapons.
- **Dragon arena iteration** (DA, DA2): round leash arenas of radius 40 on
  local ground with hazards and the dragon's wrath.
- **Round 31 clean-up lane** (C) as listed under the Round 30 carry-overs;
  the skill renames (Heal, Shield, Mend, Ice Nova) and neutral wording in
  place of a commercial MMO's terms.

### Round 31 carry-overs

**Noted 2026-10-03** ([completion](docs/planning/round31-plan.md#completion-2026-10-03));
none blocks the fresh-world GUI test. Numbers are comparisons, never targets.

- **Quest XP share above 100 % in several bands** (human 30→40 134 %,
  50→60 119 %; orc 30→40 120 %; `ledger.py --game --track <race> --repeat 2`,
  solo): whether a ledger/balance pass follows is the user's call. The human 50→60 overshoot
  predates Round 31 (103 %); most of the PvP raids' share is their targets'
  kill XP, not the reward weights (lowered to 3/4 by the user's option (b)).
- **First-start heap:** after Lane C a first start still holds about 45 MiB
  more Lua heap at the first step than a later start (110 against 65 MiB);
  it is grug_mapgen's first-start load, not caches (a possible later item;
  the #22 warm-load proposal above stays the user's call).
- **Mounts:** the tier-3/4 flyers share one selection box per tier, sized
  for the highest seat (taller than a smaller race's flyer); the riderless
  capital displays keep each model's own box (`display_box`) — check their
  name tags in the GUI test.
- **Dragon arenas (DA2 review notes):** Dragon Rime from the breath can lie
  on thin ice; the refreeze radius of broken ice; a breath splash just
  outside the rim damages without a fight flag. Watch in the GUI test.
- **UI headroom:** the flight warning has 4 px of headroom under the banner
  subtitle at 720p and GUI scale 1.
- **Small notes:** a profession vendor outside a settlement would serve
  everyone (none exists); Mend ticks continue after the helper's flag ends
  (allowed by ruling 6); the enchant masks keep their source texture's
  licence (CC BY-SA derivatives); Smite keeps its name for now.

### Round 32 — fixes, preparation and research

**Delivered 2026-10-03**
([completion](docs/planning/round32-plan.md#completion-2026-10-03), plan
[round32-plan.md](docs/planning/round32-plan.md)); every code lane
independently reviewed by Opus (F3's third pass and F2's last small commit
checked by the coordinator), 66 fixtures pass, no mapgen change:

- **Minimap zoom ×2** (F1): a 440-node window, the base map unchanged; a
  cell grid of 2 base pixels at normal and 8 at high.
- **Hostile camps** (F1): the bandit camps (start zones and frontier) and
  the Mirefolk camps draw a red "X" on the Map tab.
- **Territory colours and line** (F1): the zone banner and the minimap line
  in green, yellow or red by the territory at the position
  (`grug_pvp.territory_at`), "Friendly Territory" / "Contested Territory
  (PvP)" / "Enemy Territory (PvP)" in place of Round 31's subtitle, a banner
  on a zone or status change (y −501 too).
- **LMB hold** (F2): one gather/combat state machine; gather turns into
  combat on a hostile in the crosshair and reach (neutral mobs too, players
  when both are flagged) while an attacking skill is selected, back when
  the foe is gone; self and support skills only on a fresh press
  ([classes.md](docs/design/classes.md#left-click-and-held-input)).
- **Quest kill labels** (F2): the zone's mob name; `validate.py`
  `E-label-name` and `E-item-source-drop`.
- **Feed and quest window** (F3): combat notices and the personal notices
  in the message feed (only deaths, rare sightings, boss and dragon
  warnings and the one-time no-weapon hint stay in chat); the quest log in
  one text field with Track on HUD and Abandon in one row.
- **Performance** (F4, perf review R1–R3): the Map tab at most 2 builds and
  8 signature reads per 0.1 s pass, the party HUD in five slots, camps and
  leaders in 20 zone slices.
- **Studies:** [performance review](docs/research/perf-review-2026-10-r32.md),
  [sound research](docs/research/sound-research-2026-10.md),
  [items and professions analysis](docs/research/items-professions-analysis-2026-10.md).

### Round 32 carry-overs

**Noted 2026-10-03** ([completion](docs/planning/round32-plan.md#completion-2026-10-03));
none blocks the GUI test. Numbers are comparisons, never targets.

- **Minimap at normal quality** (F1, GUI test): the bezel is 239 px at
  1080p instead of 265 and changes in steps of about 40 px with the window
  (768p 186 → 159, 1440p 345 → 358); high quality keeps its size but draws
  a base pixel about one screen pixel wide at 1080p and shows less detail
  than it could (`REDUCE.high` stays 2). The user decides after the test.
  **High settled in Round 37 F:** the minimap always shows normal quality
  (user ruling 2026-10-06); the normal bezel is unchanged.
- **Location sample** (F1 review): 34.7 → 53.9 µs per player and second;
  the territory status repeats two zone queries `grug_pvp`'s own location
  tick already makes (could share them). Standing exactly at y −501 can
  flicker the banner, which is the rule itself.
- **F4 fixture gap:** the party HUD's `slot_of` clean-up on leave is not
  covered by `tools/r32_f4/portable_test.lua`.
- **Performance review "later" list**
  ([R6–R13](docs/research/perf-review-2026-10-r32.md#later)): R6 ability
  input and crosshair every step (20–34 ms/s at 100) and R7 the minimap
  glide (13–25 ms/s) — re-measure both first, F2 and F1 changed those files;
  R8 the quest-marker memo's 1 s expiry; R9 the tracker's bag scan; R10
  vegetation renewal bursts; R11 the discovery scan; R12 tag carriers in
  crowded places; R13 royal and garrison NPC steps. **R7, R8, R9 and R11
  done in Round 37 PO** (audit CORE-04, PLY-06, PLY-05): the minimap places
  only on change (21.0 → 9.9 ms/s at 100 stand-ins), the marker memo lives
  until something changes, the tracker reads no bags without an item
  objective, discovery scans in slots; R6, R10, R12 and R13 stay.
- **Playtest server operations** (R4, R5): serve media through
  `remote_media` (about 13.8 MB per first join); give the server at least
  4 GB of RAM and swap (2.9–3.3 GB after the first mapgen). Later: the two
  dragon models (2.3 MB together) and the 405 KB quiver texture.
- **Mapgen-environment memory** (R5, investigation): the emerge thread's
  mapgen Lua environment holds 630–745 MiB live after a collection and
  grows with generated chunks; find what it keeps (a heap walk there) and
  whether its world-query caches are bounded.
- **`tools/r29_e4/income.py --check` fails on main** since Round 31's
  fortress quests changed the income estimate. **Done in Round 33 Lane
  C5:** the estimate carries the Round 33 terms (gear sales, repair ×1.00)
  and the prices follow (Apprentice Riding and the boat 1s5c, Expert
  Riding 1g32s, Master 7g37s, respec 41–50 5s50c, the crown fee 1g47s);
  the check passes. Round 36 re-derived them after the main line's quest
  copper (1g29s, 7g38s, 5s25c, 1g48s).
- **Real-client performance test:** stand-ins do not cover the engine's
  block and object sending, physics or client work; a short test with a
  handful of real clients, perhaps at the end of the next round.

### Round 33 — items, professions and achievements

**Delivered 2026-10-04**
([completion](docs/planning/round33-plan.md#completion-2026-10-04), plan
[round33-plan.md](docs/planning/round33-plan.md), numbers in
[item_tiers.md](docs/design/item_tiers.md)); every code lane independently
reviewed by Opus, the data lane approved by the user, 72 fixtures pass;
needs a fresh world:

- **Item data** (DS): enchant values by item level up to the tier's cap
  (T7 to 70), enchant loot per channel, one upgrade per profession and
  tier, the crown, fixed potions and elixirs, drop sale values, repair,
  culture prices; 68 of 94 signatures with a use.
- **Drops** (C1): normal 5/2/1 %, named and elite 10/10/5 %, at most one
  item; bosses two blue or gold items at item level 65/70; shields,
  spellbooks and trinkets in the pool, trinkets 0/1/2 enchants; bags at
  0.1 % by mob level; min(item level, 60) required in every slot; blue ×3,
  gold ×6; the Kraken Guard a level-70 elite without XP or drops.
- **Professions** (C2, C4): Alchemy a secondary with its own book slot;
  progress only from real recipes; the removals of plan §2.8; cut-gem
  blocks 9 ↔ 1; enchant tiers stored and shown, the weaker-overwrite
  warning, profession upgrades, the crown operation; bows to the
  Leatherworker, spellbooks to the Tailor; Ornament Components and the Cut
  Quartz recipe gone, Cut Citrine the T1 trinket gem; zone leaders and
  war-camp captains on the elite row.
- **Economy and combat** (C5): crit ×2 with 0.05 % per Dexterity point and
  attribute fractions; T1-only vendor shelves, buy-back for all gear,
  repair ×1.00; potions I–VI with one 60 s cooldown; the Crownbinder and
  the Decor Merchant in every capital; `income.py --check` green.
- **Cloaks and achievements** (C3): 17 per-character achievements, 41
  cloaks by GPT-6 Astra, the Achievements tab and cloak dropdown, the
  player cloak model.

### Round 33 carry-overs

**Noted 2026-10-04** ([completion](docs/planning/round33-plan.md#completion-2026-10-04));
none blocks the GUI test. Numbers are comparisons, never targets.

- **Map markers for the capital services:** done in Round 34 F2 (kind
  `service` on the Map tab and the minimap).
- **Scout damage set above the ceiling:** done in Round 36 lane K: the
  Dexterity curve's c 0.0019 → 0.0011 gives the Scout's set +49 / +59 /
  +69 % at item level 60 / 65 / 70, the Warrior's +47 / +57 / +69 %.
- **Priest heals barely use Intelligence:** done in Round 36 lane K (2B):
  support amounts multiply by `1 + gear Int / 10 / B(L)`, so a full
  Intelligence set adds what it adds to a Mage's Fireball (+35 % at item
  level 60); without Intelligence gear the listed pool share is exact.
- **Ruination under ×2 crits:** the capstone's window rises from +9 % to
  +18 % damage, a hit at its 50 % cap averages ×1.5 instead of ×1.25; a
  playtest number. Round 35 made the window 15 s every 60 s (about +4 %
  damage overall). Whitehot fires a little later (less crit from
  Dexterity).
- **Decor Merchant's light bands** hold one item each (lantern, hanging
  lantern); no Candle, which the Embalmer sells at 4c (C5 review).
- **Sell-only loot:** the 20 one-faction signatures stay sell-only (user
  choice); Slime Gel, Crocodile Tooth (one faction) and Stone Core (no
  placed source) have no recipe use (item_tiers §2.4, §3.4).
- **C3 review notes (theoretical, not measured):** one small table per
  kill on the achievement path; noted for a later performance pass, no
  action now.

### Round 34 — sound

**Delivered 2026-10-04**
([completion](docs/planning/round34-plan.md#completion-2026-10-04), plan
[round34-plan.md](docs/planning/round34-plan.md), rules
[sound.md](docs/design/sound.md), credits [CREDITS.md](CREDITS.md)); every
code lane independently reviewed by Opus, every shipped sound on its lane's
approval list, 77 fixtures pass, no mapgen change:

- **Effects** (S1a): `grug_sounds` (play helper, hook list, formspec
  click); NPC role cues, quests, trade, money, progression, crafts by kind,
  upgrade, crown, repair, equip, cloak, potions, mounts, boats, travel,
  fishing, the Enable PvP button; 30 files.
- **Combat and creatures** (S1b): swing, hits by weapon kind, block, dodge,
  death; one cue per ability theme and projectile sounds; 22 voice families
  (`grug_mobs/voices.lua`), the dragons' and kings' cues; 88 files.
- **Ambience and music** (S2): `grug_ambience`, beds per region, night,
  cave, deep and sea (half gain in towns), dragon-island thunder, forge,
  fire and flowing-water loops, four music pools with 16 tracks pushed on
  demand (capital rotations since Round 35), the main-menu theme, Help →
  Sound, `/music`, `/ambience`.
- **Mobs in water** (F1): combat follows through harmless water, idle mobs
  swim home, a one-node bank is climbed.
- **Fixes and the Bag of Coins** (F2): text boxes, cooking costs per tier,
  the Bag of Coins, service markers, the damage-fit fractions, no gear from
  encounter adds, thin ice breaking 1 s behind a runner (3 × 3 × 3).

### Round 34 carry-overs

**Noted 2026-10-04** ([completion](docs/planning/round34-plan.md#completion-2026-10-04));
none blocks the GUI test. Numbers are comparisons, never targets.

- **Sound balance:** gains and pacing are tuned from the user's GUI check;
  the formspec click plays at the file's level (a style has no gain).
- **Public town furnaces** use the vendored furnace form, so taking a dish
  out of one plays no cooking cue.
- **Music push cost** is unmeasured (the engine hashes the file on the main
  thread, a few milliseconds per push); since Round 35 pushes happen only
  in the capitals.
- **Town pool under capitals:** resolved differently in Round 35: the Town
  pool is gone and the capital is found by x/z, so a cave below a capital
  plays that capital's rotation (bed silent), with music off its cave bed
  at half gain; below a start town the half-gain bed plays.
- **Volume rounding:** a `/music` or `/ambience` volume off the dropdown's
  grid (5 % steps since Round 35) shows at the nearest step on the Help
  page; the stored value is kept.
- **Licence rows** of the incompetech tracks point at the catalogue, not at
  each track's page.
- **Water probe:** with the sea bed shipped it reads 33 nodes per
  evaluation instead of 1 (not re-measured); a comment in
  `grug_ambience/init.lua` still says no sea bed exists.
- **S1a review notes:** the gallop follows the requested speed, a clip's
  tail plays after a stop, position sounds of one event within 0.1 s fold
  into one.
- **F1:** an idle mob facing a two-node bank may stay in water (no
  regression); animals following food do not wade; `grug_bank_ahead` runs
  per step for a floating mob in water (could be cached on the 0.25 s
  probe).
- **F2:** the Character page's Money label may overlap at a very large
  balance (GUI check).
- mobs_redo still falls back to a missing `tnt_explode` sound; no mob can
  reach it today (note, not a task).
- The Round 32 real-client performance test stays optional.

### Round 35 — fixes and character creation

**Delivered 2026-10-05**
([completion](docs/planning/round35-plan.md#completion-2026-10-05), plan
[round35-plan.md](docs/planning/round35-plan.md)); every code lane
independently reviewed by Opus, the break sound on the approval list
(`tools/r35_f/approved.txt`), 84 fixtures pass, no mapgen change:

- **Aiming** (T): `grug_core.aim_raycast` tests `rotate = true` selection
  boxes in Lua for every server-side aiming ray (the engine misreads them
  since Luanti 5.12); zombie and crocodile probe misses 62 and 32 → 0;
  [upstream-workarounds.md](docs/technical/upstream-workarounds.md) with
  this entry and the emerge-thread pin.
- **Capital music** (M): music only in the six capitals, one rotation each
  (Master of the Feast in none), either music or the bed with a 3 s
  crossfade, 5 s pauses, the next track pushed ahead, 35 % by default
  ([sound.md](docs/design/sound.md)).
- **Small fixes** (F): the break sound (the user's pick B1.2, once at the
  break), the drained and cracked broken look, the bare hand for a skill
  without a weapon, dig sounds for 42 ore, gem, coal, sand and loose nodes,
  flint removed, quest dialog and log coloured by status with "(R)" and a
  read-only description.
- **Character creation** (C): one window, a session-only draft, everything
  stored at "Create character", a reconnect during the arrival wait
  resumes it.
- **Mobs and economy** (E): night region mobs leave at dawn unless fighting
  or a player is within 32 nodes; the rat, crab, band-1 fox, crocodile,
  zombie and outlaw drop outliers lowered, band medians unchanged.
- **Talents** (B): 13 flat values become a percentage of the base hit or
  the armour constant at the player's level; the user's picks from the
  review of all 64 talents ([skill_trees.md](docs/design/skill_trees.md)
  §2.10).

### Round 35 carry-overs

**Noted 2026-10-05** ([completion](docs/planning/round35-plan.md#completion-2026-10-05));
none blocks the GUI test. Numbers are comparisons, never targets.

- **Spell formulas round before the level scalar:** done in Round 36 lane
  K: every spell (Smite included) floors once after the level scalar, like
  Loose and the melee hits; Mighty Blow and Opening still floor their
  weapon part by design.
- **Ability items show the static cooldown:** done in Round 36 lane F: the
  timing line of Grudge, Onset, Quick Step, Swift Word, Second Skin and
  Slip Away shows the effective cooldown.
- **Scout crit above the cap:** a fully geared level-60 Scout still exceeds
  the 30 % cap (about 33 % raw with the new Dexterity curve) and is held at
  it; since Round 36 Cold Eye, Firebrand and Hard Faith say "(30 % cap
  holds)" like Keen Edge.
- **Recompense's internal cooldown** (6 s) is a per-session timer; a relog
  resets it (not exploitable: a relog takes longer and leaves combat).
- **Opening on rooted targets** works in PvP too: a Scout can root a player
  with Pinning Shot and follow with a 280 % Opening (the user's pick; a
  note, not a bug).
- **Admin `/faction`** on an existing character re-enters the full creation
  window: the player may pick another faction than the admin set, and the
  class and look picks are ignored; on a player still drafting it stores
  faction and starter kit before Create. Admin-only; a possible fix locks
  the faction row and hides class and look when a class is stored.
- **Broken capture probes:** `tools/r26_map`, `tools/r26_status_icons` and
  `tools/r27_minimap` still drive the removed creation fields
  (`choose_accord`, `choose_*`); broken since Round 31's look step.
- **Music tab** (a personal playlist in the inventory; the user leans
  towards "not now"): lane M's study estimates about 450 lines (page about
  180, playlist storage 40, scheduler and "play now" 70, fixture 150, docs);
  the open question is where it plays (everywhere would undo the immersion
  ruling), plus a "loading" note, a push rate limit, up to about 29 MB of
  downloads per player and no seeking in the engine.
- **Long war-camp quest titles** are cut in the quest list below about 1080p
  (at 720p about 95 % of titles fit).
- **Aim-ray cost:** about 1–2.5 ms of server time per second per fighting
  player in the worst case (20 rotated mobs round every ray); the
  workaround goes once upstream fixes the engine
  ([upstream-workarounds.md](docs/technical/upstream-workarounds.md)).
  Limit: a "blocking" node or non-rotated object does not hold back rotated
  hits behind it (none exists in the game).
- **Night mobs by day:** a player may see one vanish in a puff 32–64 nodes
  away; a player on a fast mount may come within 32 nodes before its first
  check, and the mob then stays until the player leaves.
- **Band 3 below its income target** (median 16.7c against 19c); the
  crocodile change lowers that family further, the median does not move.

### Round 36 — the main questline

**Delivered and pushed 2026-10-05**
([completion](docs/planning/round36-plan.md#completion-2026-10-05), plan
[round36-plan.md](docs/planning/round36-plan.md), the
[story bible](docs/planning/round36/story-bible.md)); every code and data
lane independently reviewed by Opus, art and texts checked by the
coordinator, the texts reviewed by Opus with the user's picks (of the
follow-up lanes F2, W3 and RD reviewed, W2 turns blocks only); 96 fixtures
pass with the follow-up lanes, `validate.py --game` 0 errors,
`quest_targets.py` 1207 targets on six seeds; world generation changed
(lanes G, W, W2, W3 and RD; `seed_fleet quick` 100 of 100 for G, W, W3 and
RD, `full` 303 of 303 on `0f169898` at the start of Round 37), so a world
made on `fef94a6a` or later is required. WP9 and WP13 delivered:

- **Quest engine** (E): the "use at a place" objective (a quest object at a
  clash site or a recipe's quest place, seen only by its quest's holders,
  a held right-click that damage interrupts), the turn-in hook, quest tags
  and the achievement counters `quest:` / `quest_tag:`, `W-chain-gate`.
- **Shared data** (Q0) and **art** (A): ten corrupted sub-types with one
  ember tint, twelve quest-object kinds, the four quest places named for
  their uses, three achievements with cloaks and the faction rule, the two
  captains' orders; 21 textures by GPT-6 Astra.
- **The main line** (Q-A, Q-T, T): "Every Name Accounted For" and "Our
  Oaths Are Ours", chapters at 41, 46 and 53 and the finale at 60, the
  front climaxes folded in, the solo captain's orders on The Shattered
  Line, the commanders as optional "Group:" hunts; 540 quests (+25); texts
  by GPT-6 Astra with 28 review picks; prices re-derived.
- **The rift** (R): the void crack at Tombroad Ambush (11 % of the maximum
  HP per second), Isquarre the Tithe-Eater (2 × an elite's HP, 5-minute
  return, 24-hour loot lockout, only for a player with the finale), war
  commanders Greyvow and Stonegrudge.
- **POI review and decor pass** (P, W): renders of all 106 POIs for the
  user's verdicts; a theme per POI kind, house touches on every POI, start
  town and capital house, benches, window, headroom and lane rules.
- **Fixes and classes** (F, K, G): one target predicate with "Evading",
  free mobs evading only from outside their wander radius, the talent-point
  banner, the effective cooldown; the support factor from gear
  Intelligence, the Dexterity curve, spells floored once; wider dragon
  hazards, a 2-minute refreeze and the wing gust.
- **Follow-up lanes** (F2, W2, W3, RD; merged 2026-10-05 evening,
  [completion](docs/planning/round36-plan.md#follow-up-lanes-2026-10-05-evening)):
  an LMB held across a hotbar switch decides again for the new skill after
  0.2 s and digging goes on across a switch; every bench keeps its back to
  the wall beside it; low ground cover in the protected band round start
  towns and capitals; road profiles with `C_STEP` 0.5 instead of 0.05, so
  no lone half-step bumps or holes.

### Round 36 carry-overs

**Noted 2026-10-05** ([completion](docs/planning/round36-plan.md#completion-2026-10-05));
none blocks the GUI test. Numbers are comparisons, never targets.

- **Float floor in `scale_player_damage`** (K review): a value that should
  land on an integer can floor one below it (±1, also for melee since
  before Round 36); a small epsilon in the shared seam (`floor(x + 1e-9)`)
  would settle it.
- **The Tombroad tally-stone sits on Isquarre's spot:** both chapter-3
  uses at Tombroad Ambush stand on the site's centre, where the boss
  appears; a chapter-3 player there can be hit only while a finale group
  has him up (the spawn rule needs a finale holder near). Quest places have
  no offset field (lane E's format).
- **The ledger counts the Throng captain's kill twice**
  (`throng_main_04`: the kill and the orders it drops), and it still counts
  the island bounties' kill XP in 50 → 60 although quests.md says they
  count nothing (round36-plan §7).
- **Quest share above the old level:** with the main line the solo share
  (`ledger.py --repeat 2`) rose to 106–112 % (40 → 50) and 105–125 %
  (50 → 60) per race, Human highest (reported, not gated; plan §2.8).
- **Decor nodes that do not exist yet** (lane W): a thin banner cloth
  (banners are a whole wool block), weapons for the racks, a tent, rails
  and an ore cart, an ember node, a grave cross, a window flower box.
- **The captains' orders** use a placeholder icon.
- **Main-menu background:** none of lane AM's candidates; the user's own
  in-game screenshot follows (`menu/background.png` with a
  `LICENSE-media.md` row).
- **Hidden achievement rows still count:** a character's counters also
  advance for the other faction's rows, which it never sees or earns
  (harmless; no unlock).
- **Isquarre's spawn** is a plain `add_entity` under mobs_redo's mob cap,
  so on a crowded server he may appear late (R review). **Done in Round 37
  MP:** he is an authored actor outside the cap. Mobs that end up in the
  void take a flat 300 per second (players 11 %).
- **The finale's kill target is no zone recipe's:** `validate.py` warns on
  both finales (`W-role-not-in-zone`, `W-recipe-target`) and does not check
  the boss's level against the quest; the quest lanes set it by hand.
- **Names and places:** two corrupted sub-types share their family noun
  with a sibling of their zone (the bible's names, listed as exceptions);
  the Kiln-Whisper Hexer's `mourning_mire` row is missing on one quest seed
  (`tomb_fen` is reliable); Ashen Grave and Coinpit Hollow fall back to
  the belt's woods on some seeds (their names fit either ground).
- **Decor ways:** a dressed composition keeps every way within a detour of
  up to six steps (accepted by the coordinator).
- **Roads (RD review):** with `C_STEP` 0.5 one Dur Brannoc lane on seed 42
  became infeasible and the planner took its next option (plots
  unchanged).

### Round 37 — audit fixes

**Delivered 2026-10-06, pushed the same day** (`db848931`;
[completion](docs/planning/round37-plan.md#completion-2026-10-06), plan
[round37-plan.md](docs/planning/round37-plan.md), the
[audit](docs/audit-2026-10/README.md)); every code lane and every
non-trivial docs lane independently reviewed by Opus; 106 fixtures pass,
`validate.py --game` 0 errors, `income.py --check` passes; the mapgen's
code changed without changing its output (`seed_fleet quick` 100 of 100,
rosters unchanged), so no new world is needed beyond Round 36's.

- **Combat hot path** (CB; PLY-01, CORE-01, CMB-02, ITM-01, PLY-02,
  CMB-06, CMB-01, CMB-04, CMB-03, ITM-14): durability as its own cheap
  event, the max-HP clamp is not damage, the PvP Strike fallback on the
  current path, one knockback rule (mob projectiles push, user ruling
  2026-10-06), the dead WP38 tool and fist path removed.
- **Mob behaviour** (MB; MOB-01, MOB-04, MOB-07, MOB-02, MOB-05, MOB-16):
  retargeting only through threat, the held swing, the wind-up freeze, the
  `follow` scan, staticdata, the pathfinding setting.
- **Mob persistence and bosses** (MP; MOC-01, MOB-03, MOC-03, MOB-06,
  MOC-02, MOC-06, MOC-04, MOC-05): one liveness rule for rares and dragons,
  authored actors outside the mob cap, restarts keep mobs, Bone Call's cap
  and faction, royal guards return, straight side shots, patches only into
  air.
- **Interaction fixes** (IX; ITM-03, ITM-02, PLY-03/X-01, X-02, CORE-02,
  ITM-10) and **per-player polling** (PO; CORE-04, CORE-05 measured,
  PLY-04, PLY-05, PLY-06, PLY-16/X-13).
- **Mapgen** (MG; MGT-02, MGT-01, MGS-02, MGT-07/MGS-10; MGT-03
  documented) and **sound** (SN; MOC-07, the `cast_ice_nova` id).
- **The user's rulings of 2026-10-06** (F): start zones fight alone, the
  Salt Reef Lurker on the 51–60 coasts, the minimap always at normal
  quality, stale code comments.
- **Documentation** (DA, DB, DC, DD, DE, DF, D): status sync, AGENTS.md as
  working rules with the round workflow and one owner per fact, the player
  README with CHANGELOG.md and version 0.37.0, the world, player and item
  design docs against the code.

### Round 37 carry-overs

**Noted 2026-10-06** ([completion](docs/planning/round37-plan.md#completion-2026-10-06));
none blocks the GUI test. Numbers are comparisons, never targets.

- **Quest kill credit** (the user's playtest, 2026-10-06): a kill objective
  with an area counts only mobs that *spawned* in that region
  (`grug_quests/state.lua` `mob_counts`, `_grug_area == target.area`),
  while the same role spawns under the same name in other regions of the
  zone; about one in three nearby Small Plague Boars and Large Grave Rats
  in Stillgrave Hollow does not count (seed 42), and 214 of 301 area kill objectives
  can meet it (quest drops follow the same rule). **Fixed in
  [Round 38](docs/planning/round38-mob-names-plan.md#completion-2026-10-06):**
  a kill counts by the name the mob shows (268 objectives with uncounted
  same-named mobs → 0).
- **PLY-11** (CB): a Scout shot still rebuilds the Character page (its
  arrow total); a poll would save little, the fix takes the total off the
  cached page, which is a UI change for the user.
- **Cave mobs under the start zones** still call each other (open
  question): the base Giant Rats, Zombies, Spiders, Spiderlings and Goblin
  Miners of the cave rows (about y −40 to −175, depth level 10 or below)
  are no recipe roles, so the start-zone rule does not reach them; lane F
  would leave them (caves are the depth domain).
- **Start-zone camps fight alone** too (lane F's reading of the ruling:
  bandits, poachers and their chiefs; every member still attacks on
  sight); to confirm with the user.
- **`minimap_view.lua` keeps its high-quality rows** (8-pixel grid, halved
  texture), unused since Round 37 F; the `tools/r27_minimap` geometry
  fixture still tests them.
- **Mob behaviour notes** (MB review): after a wind-up a dogshoot elite in
  shooting range can fire at once (the cone resets `punch_timer`, not the
  shot timer `self.timer`); a zero-damage hit on a mob fighting an NPC no
  longer pulls it; long punch clips (Shore Crab 2.0 s, some start-zone
  families 1.4–1.7 s) hold the punch pose while the mob chases (GUI
  check); a shot from beyond 40 m no longer pulls a bound actor that
  already fights. A dodged PvP swing still pushes (CB review).
- **Interaction notes** (IX and its review): a tall-crop top lost on its
  own leaves the root undiggable until the next block load; mobs with
  `fly_in = "air"` fail their flight check inside a water barrier; the
  right-click forwarding of `grug_core.node_rightclick` is repeated in
  `grug_abilities/init.lua` and `grug_housing/stone.lua`; inside a Claim
  Stone's arrival cube a flow can still loop (no barrier there).
- **Polling notes** (PO and its review): a player with an active item
  objective still reads the inventory every 0.5 s; `raw_weapon_controls`
  is never cleared on leave (a rejoin with dig held skips one hint).
- **Sound notes** (SN review): mobs_redo's `tnt_explode` fallback in
  `mobs:boom` stays unreachable (no such file ships); `mobs_spell` is still
  called by the vendored protector rune and `lucky_block.lua`, neither of
  which loads.
- **Mob persistence notes** (MP review): if mod storage lags the map after a
  crash, a newer-generation copy removes itself (healed by the next spawn);
  an object finishing deactivation into a block that just turned active
  again can read as lost (a reset, never a duplicate); a royal guard killed
  early in a King attempt longer than 15 minutes returns mid-fight; with
  the King's faction the raiders' loot follows the faction-NPC rule.
- **Shore kind** (F review): the new shore regions reshape the coasts a
  little; Gravesalt `whitewall`, a target of two front quests, shrinks from
  7.9 % to 6.4 % of land (seed 7) and from 5.7 % to 4.2 % (seed 2026) but
  exists on every seed; two `item_tiers.md` availability grades moved from
  common to regular by the formula only (Last-Pay Talisman, Unbroken
  Weapon Strap).
- **Tools** (MG review): the harnesses that compare a branch with an older
  tree now load `world_assembly.lua` from that tree, so they cannot run
  against trees before Round 37 (`r25_capital_plots`, `r26`,
  `r28_zone_atlas` and `r28_world --before`).

### Round 38 — mob names

**Delivered and pushed 2026-10-06**
([completion](docs/planning/round38-mob-names-plan.md#completion-2026-10-06),
plan [round38-mob-names-plan.md](docs/planning/round38-mob-names-plan.md));
every code lane independently reviewed by Opus (lane C without its own
review), the naming lanes' proposals by a taste review and the user's
page; 108 fixtures pass, `validate.py --game` 0 errors,
`check_rules.py --shipped` 0 problems, `guarantee.py --check` passes. No
world generation changed; the GUI test wants a fresh world (garrison
guards and named rares carry their name key from their placement).

- **Inventory and rules** (I, C): 950 name slots, the rule checker
  (`tools/r38_names/check_rules.py`, `--shipped` the naming gate) and the
  quest-name guarantee validator (`guarantee.py`).
- **Names** (V, Z1–Z7, T, the page, B2): the user's picks in
  `grug_mobs/data/names.json`, 536 of 950 slots renamed, 356 → 513
  distinct names, the plan's rule breaks 374 → 0; code-built names read
  the file; the dragon whelps at level 60.
- **The quest-name guarantee** (M/B1): a kill counts by the name the mob
  shows; objectives with uncounted same-named mobs 268 → 0, captain
  labels naming another mob 21 → 0.
- **Texts and terms** (B3, NR, IT, IB, PR): 242 quest text fields on the
  new names, the Kraken, twelve item display names, Party instead of
  Group.

### Round 38 carry-overs

**Noted 2026-10-06** ([completion](docs/planning/round38-mob-names-plan.md#completion-2026-10-06));
none blocks the GUI test.

- **Dragon broadcasts** put "The " before the names file's dragon name in
  code (`bosses.lua`): a dragon renamed to a proper name would read
  "The <Name>".
- **Achievement short forms:** "Kill the Wyrmglass Dragon" and "Kill the
  Stormscale Wyvern" (`grug_achievements/catalog.lua`) keep the short
  forms from before Round 38; the mobs show "Wyrmglass Ice Dragon" and
  "Stormscale Jungle Wyvern".
- **Entity descriptions in Lua are fallbacks** (text review): a family's
  registered description shows only where `names.json` names no slot for
  the mob; reading one as the shown name misleads.
- **The level-60 whelps** make a dragon's enrage phase clearly harder than
  before (HP 384 → 2696 each); watch it in playtests.
- **The Rift Spawn's gap exemption** in `check_rules.py` (rule 4) holds
  only while its name stays on the one story role.
- **`guarantee.py` information:** `I-now-counts` (205 objectives now count
  same-named mobs beyond their area: the fix) and `W-level-fit` (135
  objectives whose counted name reaches beyond the quest level ±3) are
  reported, not errors.
- **Eight three-word family items** keep their names (the user, plan §6
  item 16): the family word tells which mobs drop them.
- **The welcome window** after character creation came from the user's
  separate lane WC and merged after lane D as a follow-up (`f21aea6d`;
  [completion](docs/planning/round38-mob-names-plan.md#follow-up-lanes)).

### Round 39 — web data for the realm website

**Delivered and pushed 2026-10-06**
([completion](docs/planning/round39-web-data-plan.md#completion-2026-10-06),
plan [round39-web-data-plan.md](docs/planning/round39-web-data-plan.md));
every lane independently reviewed by Opus; 112 fixtures pass, the
exporter's `--check`, `check_glb.py` and `build_glb.py --check` pass. No
gameplay change, no world generation changed.

- **Player meta** (WM): `grug_xp:level` and `grug_visuals:appearance`, the
  external contract in the
  [module guide](docs/technical/module-guide.md#player-meta-read-by-external-tools);
  on main from `03a76229`.
- **Export** (WE): `tools/web_data/web_data.json`, generated and checked by
  `tools/web_data/export.lua`.
- **Model** (WG): `tools/web_data/model/grug_visuals_character.glb`,
  animated stand and walk, tested against the `.b3d`; a GUI probe mod.

### Round 39 carry-overs

**Noted 2026-10-06** ([completion](docs/planning/round39-web-data-plan.md#completion-2026-10-06)),
from the reviews (backlog notes, no severity); none blocks the GUI test.

- **The offhand is stored but not drawn** in game: the user wants it on
  the character later; the appearance format already carries it.
- **An unregistered item in a hand slot** would store an empty `image`
  (`grug_visuals.hand_image` finds no definition); release mode rules such
  an item out (a removed item needs a migration step or a new server).
- **Admin `/faction`** updates the stored appearance only at the
  character's next apply.
- **The grammar's `max_depth = 4`** is exactly the measured depth of
  today's strings (no headroom; `tools/r39_wm` asserts the equality): a
  composition nested deeper or shallower fails the fixture until the
  grammar, and with it the contract, follows.
- **The model test is not in `run_fixtures.sh`:** `check_glb.py` and
  `build_glb.py --check` are Python (a LuaJIT wrapper would need
  `io.popen`, which check_lua's sweep 5 flags), so a round that touches the `.b3d` or player_api's
  animations runs them explicitly.
- **Equippable items from another mod:** the exporter loads only
  `grug_gear`'s registrations; a mod that starts registering equippable
  items must be added to `tools/web_data/build.lua`.
- **Further clips** (sit, lay, mine, walk_mine) are one entry each in
  `build_glb.py`'s `CLIPS` plus the same name in `tools/web_data/build.lua`'s
  animation list (the export's frame ranges).
- **Exporter shell calls** put the repository path in single quotes
  (`build.lua`'s directory listing, the fixture's `find`): a path with a
  `'` in it breaks them.
- **Square hand images:** the export's README describes a hand item as an
  extruded square of its image; every shipped hand image is square, a
  non-square one would need that description extended.

### Round 40 — combat feel

**Delivered and pushed 2026-10-06**
([completion](docs/planning/round40-plan.md#completion-2026-10-06),
plan [round40-plan.md](docs/planning/round40-plan.md)); every code lane
independently reviewed by Opus, the wave 1 pages' numbers too; 119
portable fixtures on main. No world generation changed.

- **Acceptance material** (V1–V4, R): the cooldown, animation and
  particle preview pages, the GUI probe `tools/r40_probe`, the accepted
  pose table `tools/r40_an` and particle catalogue `tools/r40_v3`,
  `character_anim` as a reference project.
- **Cooldown overlay** (CD): a cover and image digits on hotbar slots
  ([classes.md](docs/design/classes.md#the-cooldown-overlay)); the wear bar
  shows no cooldown or charge.
- **Poses and head look** (AN1, AN2):
  [character_visuals.md](docs/design/character_visuals.md#5c-poses-round-40)
  §5c and §5d.
- **Charge as a dash** (CH): the planned path, the hole rule, the hit on
  arrival ([classes.md](docs/design/classes.md#3-warrior-rage) §3).
- **Particles** (PX, PM): one helper, `grug_particle_scale`, the player
  skills ([combat_stats.md](docs/design/combat_stats.md#skill-particle-effects)),
  the bosses and mob specials ([biomes_mobs.md](docs/design/biomes_mobs.md)
  §3.1).

### Round 40 carry-overs

**Noted 2026-10-06** ([completion](docs/planning/round40-plan.md#completion-2026-10-06)),
the user's open picks and the reviews' backlog notes (no severity); none
blocks the GUI test.

- **Sounds were out of this round** (plan §2.7), Smite's included: Smite
  keeps the shared holy cast cue and Charge its cast cue; the dash, the
  poses and the new effects add no sound. Any new sound goes through a
  listening page ([sound.md](docs/design/sound.md) §1).
- **Particle art order:** the effects are single-colour; the V3 page named
  optional art for later (a snowflake sprite for Ice Nova and Glacial
  Ward, animated fire for Fireball's splash, draconis ice and fire motes
  for the dragon breath and its bolts, a four-point holy spark for Smite,
  a slash streak for Mighty Blow). The user has flagged none yet.
- **Cleave's wind-up** marks the cone with the facing frozen at the cast
  (and halfway) while the hit tracks the target: existing behaviour the
  motes now make visible; the user decides.
- **The Charge arrival hold** (about 0.34 s without control on the stop)
  stays for now; the user picks at the GUI test (the forward snap per hold
  length: `tools/r40_ch/lag_replay.py`).
- **Not on the particle helper:** the tails of mob fireballs, embers and
  void bolts (one particle per step) and the stun cross and root crystals
  (sized from the object's box), so `grug_particle_scale` does not reach
  them.
- **`--check` of the PNG generators** (`tools/r40_cd/gen_cooldown_textures.py`,
  `tools/r40_probe/gen_textures.py`) compares bytes that depend on the
  installed zlib's output; another zlib build could fail it with nothing
  changed.
- **The Kraken's drag** can push the Charge carrier off its path until the
  next segment starts.
- **A Charge miss shows no notice.**
- **A skill moved by Lua** (not by an inventory action) and cast again
  keeps its overlay on the old slot for up to 0.5 s, until the next
  hotbar check.
- **The overlay assumes `gui_scaling` 1 and `hud_hotbar_max_width` 1.0**
  (the server cannot read them): about a pixel off where 48 × density is
  not a whole number.
- **A stale comment** in the vendored mobs fork (`mods/ENTITIES/mobs/api.lua`,
  the wear-free punch write) still names the cooldown wear ticker, which
  is gone.
- **A sneak toggle in the middle of a one-shot pose** (swing, flinch):
  the pose's end is estimated from the current animation speed.
- **The probe** (`tools/r40_probe`, tools only) switches its carrier's
  segments up to one server step late (corrected by an interpolated
  `move_to`); the shipped dash is `grug_abilities/charge.lua`.

### Round 41 — playtest fixes, the production crash and the upgrade contract

**Delivered 2026-10-07, pushed 2026-10-08**
([completion](docs/planning/round41-plan.md#completion-2026-10-07),
plan [round41-plan.md](docs/planning/round41-plan.md)); every code lane
independently reviewed by Opus except the coordinator's one-line lane WW; 123 portable fixtures on main. Version
0.41.0, the first release in release mode: the production server moves to
it with a map reset (declaration `map_reset: ["0.40.1"]`).

- **Release mode and the upgrade contract** (UP): AGENTS.md "Release
  mode", [upgrade-contract.md](docs/technical/upgrade-contract.md),
  `tools/web_data/upgrade.json` with `tools/check_upgrade.py`, the map
  reset through `grug_reset_world`, unknown quest ids dropped.
- **The production crash** (CR): the writer reads the water barrier as
  air; a mapgen failure keeps the engine's terrain and is reported through
  `grug_core.severe` ([luanti-lua.md](docs/technical/luanti-lua.md)).
- **Playtest fixes:** the walk animation and kings and Generals at their
  seat (MOB, [world.md](docs/design/world.md), [pvp.md](docs/design/pvp.md)),
  stale world-map tiles (MAP, [world_map.md](docs/design/world_map.md#map-quality-and-relief)),
  the bow's missed release and the quiver total (SC,
  [classes.md](docs/design/classes.md#cancellation-and-native-client-limits)),
  the recipe book's Close and multi-item slots (UI; the books went in
  Round 45),
  the waterweed bed out of `group:sand` (WW).

### Round 41 carry-overs

**Noted 2026-10-07** ([completion](docs/planning/round41-plan.md#completion-2026-10-07)),
the reviews' backlog notes (theoretical, no severity); none blocks the GUI
test or the migration.

- **The rift boss** (`walk_chance = 0`) may hop while chasing (mobs_redo's
  `do_jump` reads it as a jumping mob); unverified in the engine, not
  taken up by Round 42.
- **`wielded_now`** (`grug_abilities/init.lua`) drops an in-place edit by a
  node `on_rightclick` that returns the passed stack; no such node exists
  today.
- **The quiver cover** assumes the default font size (16); a larger user
  font could show part of the engine's "100".
- **The bow's second cause** (round41-plan §8, a lost release snapshot on a
  lossy link) stays open; the plan's three questions tell it apart.
- **A repair form stays open without a session** after walking out of
  range and pressing Repair; its Close then only closes.
- **`check_upgrade.py`** accepts a new entry below the pushed version
  together with a bump; a later rule: a new entry must exceed the pushed
  version.
- **`tools/web_data/README.md`** does not mention `upgrade.json` (the docs
  index and upgrade-contract.md do).
- **The late-failure light restore** in the mapgen degrade path has no
  test (the portable test checks content and param2).
- **A systematic mapgen failure** would send one red chat line per chunk
  to every player; a cap would need the user's call.

### Round 42 — mob navigation

**Delivered 2026-10-08, playtest accepted the same day, pushed 2026-10-08**
([completion](docs/planning/round42-plan.md#completion-2026-10-08),
plan [round42-plan.md](docs/planning/round42-plan.md)); every lane
independently reviewed by Opus; 129 portable fixtures on main. Version
0.42.0, compatible. No world generation changed.

- **Test scene** (NV0): `tools/r42_nv0`, 15 scenes × 7 movers, the
  before-numbers and the calibration (rulings 18–20).
- **Navigation core and combat** (NV1): `mobs/grug_nav.lua`, the stuck
  detector, local search, path checks, smoothing and follower; the give-up
  in sight with the longer veto
  ([combat_stats.md §4](docs/design/combat_stats.md#4-threat-aggro-system)).
- **Fixed walks** (NV2): patrols, posts, seats, the royal follow, the
  evade, the rift boss and named rares ([world.md](docs/design/world.md)
  §4a).
- **Settlement walkers and the route cache** (NV3), **doors** (DR) and
  **no random stops on routes** (ST):
  [settlements.md](docs/design/settlements.md#settlement-walkers).
- **Cleanup** (CL): the unread stuck settings and the dead helpers.

### Round 42 carry-overs

**Noted 2026-10-08** ([completion](docs/planning/round42-plan.md#completion-2026-10-08)),
the reviews' and reports' backlog notes (theoretical, no severity); none
blocked the playtest.

- **Tall mobs** (NV1): rares ×2 and kings also get the collision height
  under 2 and clip through lintels (the playtest accepted the look).
- **Close targets** (NV1) are searched directly only, so a bandit still
  gives up at a 2-high gap 5 nodes aside.
- **An evader sliding along a wall** (NV2) counts as stuck only when it
  stops.
- **Royal guards running to a fighting leader** (NV2) can overshoot by up
  to about 4 nodes (cosmetic).
- **A named rare that evades** (NV2) runs two walk owners (theoretical).
- **A blocked walker is steered every step** (NV2); option: steer the
  idle-leader follow only while it has a path.
- **A fixed-walk goal over 32 nodes away** (NV2) searches every 5 s while
  its ring fails.
- **Cache builds skip the per-mob lockout** (NV3), bounded by the cap and
  the budget.
- **Gate-tower patrol loops never climb** (NV3; older than the round).
- **A player's unlocked door** (DR) within 20 nodes of a village walker's
  ends, outside protection, can be opened by a failed fixed walk.
- **A door hand-over is lost** (DR) when a fight pulls the opener over 8
  nodes away; the door stays open.
- **Random stops come back now and then** (ST) with server steps over
  0.5 s.
- **A roamer pinned outside its leash** (ST) never pauses.
- **The random turn** (ST) still applies to post guards walking back,
  named rares, royal guards, the rift boss and the wild evade, roam-cap
  and shore walks (a mild veer of about 0.3 m).
- **Walkable decor named "wall"** (ST; castle wall slabs and stairs) still
  counts as a fence.
- **No negative-cache and lockout merge** (CL): they decide differently
  when a mob searches again.
- **Unused before Round 42, left untouched** (CL):
  `grug_mobs.start_npc_activity`, the unread `mobs_disable_damage_kb`
  setting, upstream's unused `deg`, `vmultiply`, `vsubtract`,
  `set_pitch`, `set_roll`, and `no_path_wait_cap` (read, never reached).

### Round 43 — world migrations

**Delivered 2026-10-08, pushed 2026-10-09**
([completion](docs/planning/round43-plan.md#completion-2026-10-08),
plan [round43-plan.md](docs/planning/round43-plan.md)); every lane
independently reviewed by Opus; 130 portable fixtures on main. Version
0.43.0, compatible, with an empty `migrate` list: the foundation of the
platform's migration contract, shipped alone (ruling 2). No world
generation changed.

- **Game side** (GS): the world version record, the start guard,
  new-world recognition, the online-work runner and the schema-2
  declaration with `check_upgrade.py`
  ([upgrade contract §5](docs/technical/upgrade-contract.md#5-migrations)).
- **The migration tool** (MT): `tools/migrate.py` and `tools/migration/`
  ([tools/README.md](tools/README.md#the-migration-tool)).
- **Integration tests** (IT): `tools/r43_it/run.sh`, SQLite and PostgreSQL.
- **Open for a later step:** map blocks (format v29, both SQLite `blocks`
  layouts, the round-trip test) only when a step needs them (ruling 4);
  the first real step, 0.44.0, did without them (its station-grid gap is a
  [Round 44 carry-over](#round-44-carry-overs)).

### Round 43 carry-overs

**Noted 2026-10-08** ([completion](docs/planning/round43-plan.md#completion-2026-10-08)),
the reviews' and reports' backlog notes (theoretical, no severity).

- **A held character** (GS; a failed character handler) still meets the
  other join callbacks of that join; handlers must be safe to rerun.
- **One contrived registry layout** (GS) passes `check_upgrade`'s parser: a
  block-commented literal `versions` table plus a non-literal real one.
- **The PostgreSQL schema guard** (MT) compares columns only.
- **A step could commit through `raw(...)` itself** (MT), outside the
  tool's rollback.
- **A missing `mod_storage.sqlite` with no characters** (MT) is exit 2
  rather than "new world".
- **Strings that are not valid UTF-8** (MT) cannot be written to
  PostgreSQL: the step fails, exit 1.
- **PostgreSQL migrate mode takes no lock at `begin()`** (IT), so a lock
  timeout during a step's first write is exit 1 `step`, not exit 2 `lock`
  (the operator stops the server first).

### Round 44 — inventory, map and quickbar

**Delivered 2026-10-09, 0.44.0 not pushed**
([completion](docs/planning/round44-plan.md#completion-2026-10-09),
plan [round44-plan.md](docs/planning/round44-plan.md)); every lane
independently reviewed by Opus; 138 portable fixtures on main. Version
0.44.0, **migrate**: the first declared step. Round A of the
[UI and crafting rework](docs/planning/ui-crafting-rework-plan.md). No
world generation changed.

- **Inventory logic** (IH) and **the window frame** (FR): the give helper,
  the fit check, bags in bags, the sort, the potion belt; the fixed tab
  order, the inventory views and the Inventory tab
  ([inventory_equipment.md](docs/design/inventory_equipment.md)).
- **Character** (CH), **Talents & Skills** (TS), **Party & PvP and Help**
  (PP): the mode and gear boxes with shift-click routing; the tree
  framework, the skill row and hotbar-only skills
  ([skill_trees.md](docs/design/skill_trees.md)); one Party & PvP page and
  the rewritten texts.
- **Map** (AR, MB, MQ): the user's art picks, the baked layer, the map
  window on Z with the quest log, quest targets and event-driven refresh,
  `grug_keys` ([world_map.md](docs/design/world_map.md)).
- **Quickbar** (QB) and **the step** (MS): `grug_quickbar` on E, mount
  items inert; step 0.44.0 and its test
  ([upgrade contract §5.8](docs/technical/upgrade-contract.md#58-the-declared-steps)).

### Round 44 carry-overs

**Noted 2026-10-09** ([completion](docs/planning/round44-plan.md#completion-2026-10-09)),
the reviews' and reports' backlog notes (theoretical, no severity). The map
icon overlaps (and MB's GUI tuning) wait for the GUI test; MB has nothing
else open.

- **Window frame** (FR): reopening the inventory shows the scrollbar
  position of the last send, not where the player left it; a page with no
  view and an empty tab row would turn `size` into a legacy size (none
  exists); a pure scrollbar event stops at sfinv, so `""` handlers
  registered after it never see one (none acts on it).
- **Bags** (IH): a cross-inventory bag swap (a chest's bag onto an equipped
  bag) is checked as a full removal, stricter than needed; two soulbound
  stacks past `main` would push one into a bag in a sort (one Claim Stone
  per player).
- **Character** (CH): a future allow rule on gear or arrow moves must also
  cover `route_shift`, which skips the allow callbacks registered after
  `equipment.lua`; a quiver change, a Scout's shot included, resends the
  cached Character page in every mode.
- **Talents & Skills** (TS): no message when a class change finds a full
  hotbar (the base skills wait silently in the row).
- **Texts** (PP): the removed-tab scan in `tools/r44_pp` misses
  concatenations across lines, words split by hypertext tags and `[[...]]`
  strings (no hits by hand today).
- **Map window** (MQ): `zoom_fov` 72 replaces the 15° zoom creative mode
  gives; while Charge's field of view is active, Z shows "Zoom currently
  disabled"; the old probe `tools/r27_quest_item_names` still reads the
  Quests page (outside `run_fixtures.sh`); the stale comment in
  `grug_mapgen/wp40/r7_loader.lua:46-47` (zone markers as a `world_key`
  reader) waits for the next real mapgen change, since a comment edit there
  invalidates the world-layout cache.
- **Quickbar** (QB): an open quickbar is never refreshed; `grug_mounts`
  still depends on `grug_inventory`, which it no longer uses;
  `grug_mounts.register_on_owned_tiers_changed` has no listener.
- **The step** (MS): the station grids are gone since Round 45 (RG, ST),
  so nothing new can enter one; what remains is an old player-placed
  station's dead node meta, which may still hold a skill or mount item
  from before 0.44 and hands it out when the station is dug (the dig refund;
  nothing is lost). The e2e row dump cuts rows over
  90 characters (byte identity checked separately); on PostgreSQL the step
  runs only on a world without skills or mounts (it uses only the shared
  data API).

### Round 45 — crafting rework

**Delivered 2026-10-09, not pushed**
([completion](docs/planning/round45-plan.md#completion-2026-10-09),
plan [round45-plan.md](docs/planning/round45-plan.md)); every code lane
independently reviewed by Opus (PT1 and ART without a separate review);
152 portable fixtures on main. Version 0.45.0, **migrate**: the second
declared step. Round B of the
[UI and crafting rework](docs/planning/ui-crafting-rework-plan.md). No
world generation changed.

- **The item level ladder** (IL) and **enchants and upgrades** (EU):
  1/11/21/31/41/51, the requirement = the item level; the target slot,
  the filtered enchant list, +N upgrades to 10 × tier
  ([item_tiers.md](docs/design/item_tiers.md)).
- **Recipes, jobs and the Crafting tab** (RG, JB, UI, PT3): the registry,
  gear in its profession, the grid, books and discovery removed; timed
  jobs and the output area; the tab with areas, list, box and bar
  ([professions.md §1.2](docs/design/professions.md#12-recipe-areas-round-45),
  [inventory_equipment.md §4](docs/design/inventory_equipment.md#4-crafting-model-round-45)).
- **Stations, cooking, alchemy** (ST, PT8, ART): proximity stations,
  Cooking at join, finished potions, Grudge-Free Repairs, station sounds
  at a job's start, the new station looks and jewellery icons
  ([durability_repair.md](docs/design/durability_repair.md),
  [sound.md](docs/design/sound.md)).
- **Playtest fixes** (PT1, PT2, PT5, PT6, PT7, PT9): the boxed Inventory
  tab with the money row, one Character Stats mode, the shift-click inbox;
  mounts in first person, ride sounds, rider fall damage, liquids end a
  ride ([mounts.md](docs/design/mounts.md)); fliers, crabs, dawn; the
  Claim Stone as a waypoint ([home_travel.md](docs/design/home_travel.md)).
- **The step** (MS): 0.45.0 and its test
  ([upgrade contract §5.8](docs/technical/upgrade-contract.md#58-the-declared-steps)).

### Round 45 carry-overs

**Noted 2026-10-09** ([completion](docs/planning/round45-plan.md#completion-2026-10-09)),
the user's items for later rounds and the reviews' and reports' backlog
notes (theoretical, no severity).

- **The waiting point for players in creation stasis** (the user,
  Round 46): every player whose wait ends in a teleport waits at
  (0, 31000, 0), where no map is generated around them; the spec is
  ready (`grudgelands-orchestration/r46/waiting-point-spec.md`, outside
  the repository).
- **Random seeds can fail at load** ("river covers the core of POI", e.g.
  seed 8507030740356938342, already in 0.44.0); the user's long-term fix
  is POI placement adapted to the roads and rivers (Round 46;
  [seed-dependent POI placement](#seed-dependent-poi-placement-user-2026-10-03-optional-set-aside)).
- **A map and minimap icon for Grudge-Free Repairs** (the user, Round 46):
  a repair icon without a tooltip; new art and the user's pick.
- **Repair only in towns** (the user leans to it): remove claim repair,
  the furnaces' included; a crafting-table repair station is dropped
  (repairs stay scarce so players meet).
- **`grug_materials/registry.lua` `TIERS[].ilvl`** still says 3/10/…/50
  (unread, part of the pinned WP43 projection): fold it into the next
  mapgen change with the `r7_loader.lua:46-47` comment
  ([Round 44 carry-overs](#round-44-carry-overs)).
- **Night mobs and idle players** (PT7): a player who stands still or is
  away keeps every night mob within 64 nodes (up to about 110 at the
  cube's corners) all day; watch it.
- **Crafting tab** (UI): the ×N count and the station hint go stale until
  the next click; the search echo cut at 40 bytes can split a UTF-8
  character; a Craft now click reads the inventory three times; Help's
  "Profession recipes need their station within 4 blocks" also reads as
  covering Cooking (the line above says otherwise); the enchant and
  upgrade boxes stack their notes without a cap (only an unlikely
  eight-line combination reaches the button), and a recipe box whose
  description is dropped for room is not checked against the quantity
  row (no recipe gets there).
- **Jobs** (JB, EU): XP counts crafts, not items (the same while every
  XP recipe makes one); a worn tool without metadata counts as a plain
  ingredient (no recipe takes a tool); corrupted job meta is dropped with
  its consumed items (nothing writes such meta); an operation that
  vanishes mid-job returns the item and its materials, possibly more
  stacks than the start checked (they spill into the inventory, then at
  the feet); missing materials do not grey the button.
- **Recipes** (RG, ST): the 332 dead engine grid routes could be reached
  by a modified client only while a pre-0.45 `craft` list keeps 9 slots
  with items; Round 9's setting counts are kept though their collision
  reason is gone; `r45_st` §Q sees only the records it loads (alchemy and
  cooking), so it would miss a quest target moved to a primary.
- **Grudge-Free Repairs** (ST): a saved Cooking trainer keeps its old
  nametag until its first claim tick (seconds); a refused click (more than
  8 nodes away, or the NPC pushed off its socket) shows nothing.
- **Shift-click inbox** (PT5): only a modified client can move a bag slot
  into the inbox, where a leftover drops at the feet; `room_for` assumes
  the quiver takes all its room (one arrow item today); "No room in your
  inventory." also shows when the source would refuse anyway; `bag_rings`
  reads only the page content, not a view's listrings.
- **Mounts** (PT6): the ride clip restarts on a speed flicker (pressing
  almost head-on into a wall under lag); a clip's last 0.05 s is never
  cut; the fall factor comes from the node under the centre, the engine's
  from the collided node (an edge case for the three nodes in that
  group); a mount falls through cobwebs and climbables at full speed; a
  bottom slab on water refuses a summon.
- **Mobs** (PT7): a forced stand restarts a hovering flier's wing loop
  once; a flier within 0.25 nodes of the ground plays stand; a perched
  bird plays fly for one step after it reloads.
- **Claim Stone** (PT9): the arrival does not check the floor (a stone
  that vanished before the 5 s scan; Return home has the same gap); a
  forged tab-1 field on the Waypoints tab is still handled (the owner on
  their own stone, harmless).
- **Art** (ART): the lit brewing stand only glows; the jeweller's bench
  and the brewing stand keep metal dig sounds and `cracky`.
- **The step** (MS): the drop at the feet runs before a map reset's
  relocation (only a release crossing a map reset and 0.45.0 together,
  which the declaration does not allow today); a nil from `core.add_item`
  would hold the character at every join (safe; a SEVERE line).

### Audit 2026-10 open questions

**Open, for the user** (collected 2026-10-05 from the
[October 2026 audit](docs/audit-2026-10/README.md)'s "Open questions for
Jan" and its "Jan decides" findings that the
[Round 37 plan](docs/planning/round37-plan.md) §2 did not decide). None
blocks a fix; until a ruling the docs describe the code as it is (plan
§2.4). One line each, details in the linked audit document.

- **DW-04** — the ambient War Construct sub-types (`causeway_construct`,
  `siege_war_construct`) are in no recipe: add them to their two zones'
  recipes or drop them and their docs? ([world docs](docs/audit-2026-10/docs/03-design-world.md))
- **DW-08** — V1's "scorched breaches, twisted vegetation" and "Nether
  corruption" do not exist (V1 has the rift): keep as a V1 wish, move to
  V2 or drop? ([world docs](docs/audit-2026-10/docs/03-design-world.md))
- **DW-26** — the proposed "Rift-Touched" state in `TODO-design-nether.md`
  collides with V1's rift and Rift Spawn. ([world docs](docs/audit-2026-10/docs/03-design-world.md))
- **DW-40** — "never overlaid": `grug_core.surface_mob_level_at` returns the
  region overlay, only `grug_zones.*` is the pure field; which does the
  rule mean? ([world docs](docs/audit-2026-10/docs/03-design-world.md))
- **DI-14** — spellbooks need Journeyman mastery (level 16+) at every tier
  (the T5 32-slot bags Master, level 46+), so the T1 spellbook is out of
  reach in the T1 band (levels 1–10) and counts only from level 16 for a
  Tailor still at profession tier 1: keep the gate? **Decided 2026-10-08,
  done in Round 45:** the mastery bands go (round45-plan ruling 7).
  ([item docs](docs/audit-2026-10/docs/05-design-items.md))
- **DI-17** — station recipes belong to one profession each, so only the
  Weaponsmith crafts a Forge: may the Armorsmith craft one too?
  ([item docs](docs/audit-2026-10/docs/05-design-items.md))
- **DI-27** — cultivated Ember Moss (seed recipe, crop) is not
  Alchemy-gated, only the wild source is: intended? ([item docs](docs/audit-2026-10/docs/05-design-items.md))
- **D3 / mastery bands** — the mastery bands (character level 16 / 31 /
  46, bags and spellbooks only) beside the six profession tiers: keep them
  or make them profession tiers? **Decided 2026-10-08, done in Round 45:**
  removed; the profession tier equals the item tier for everything. (from the archived
  [findings](docs/archive/maintenance/findings.md); [item docs](docs/audit-2026-10/docs/05-design-items.md))
- **DI-10** — is a "found gear versus crafted demand" audit still wanted
  after WP5, or does the sentence go? ([item docs](docs/audit-2026-10/docs/05-design-items.md))
- **DP-06** — the Priest talents' "Word" names (Sharpened Word, Swift Word,
  Word of Ruin, Last Word): keep or rename? ([player docs](docs/audit-2026-10/docs/04-design-player.md))
- **DP-08** — `/xp` can no longer lower a level: keep the level-drop talent
  reset for API callers or remove it? ([player docs](docs/audit-2026-10/docs/04-design-player.md))
- **DP-10** — Warrior shield abilities were deferred "after WP14", which is
  delivered: post-V1 or a BACKLOG entry? ([player docs](docs/audit-2026-10/docs/04-design-player.md))
- **DP-12** — the Scout's HP factor is an implicit 1.00 (`stats.lua`
  fallback): confirm 1.00 as decided? ([player docs](docs/audit-2026-10/docs/04-design-player.md))
- **DP-18** — "Last Word" is both an achievement and the Priest capstone:
  keep the shared name? ([player docs](docs/audit-2026-10/docs/04-design-player.md))
- **CMB-10** — a relog resets every ability cooldown and refills mana,
  while talent and trinket cooldowns persist: should long cooldowns and
  mana survive a relog? ([combat code](docs/audit-2026-10/code/07-combat-progression.md))
- **Blink into claims** — Blink and Charge ignore housing claims and
  protected POI interiors (only walls stop them): refuse them there?
  ([combat code](docs/audit-2026-10/code/07-combat-progression.md))
- **Rift void and shields** — the rift void's damage is soaked by absorb
  shields, unlike lava and drowning: intended? ([core code](docs/audit-2026-10/code/06-core-hud-ambience.md))
- **CORE-03** — switching off the atmosphere (a graphics fallback) also
  mutes the ambience beds: keep the beds then? ([core code](docs/audit-2026-10/code/06-core-hud-ambience.md))
- **ITM-16 / fuels** — furnaces burn only coal, charcoal and logs, the
  brewing stand the engine fuels (planks yes, charcoal no): intended? The
  brewing stand takes no fuel since Round 45 (no automatic brewing); the
  furnace half stays open.
  ([item code](docs/audit-2026-10/code/09-items.md))
- **Fishing rod** — all other gear breaks and is repaired, the rod breaks
  and disappears: intended? ([item code](docs/audit-2026-10/code/09-items.md))
- **MGS-08 / water in POIs** — planned and bucket water may flow into
  village, camp and POI cores and onto roads (only towns and capitals are
  guarded): keep until WP46 or extend the water guard? ([settlement
  code](docs/audit-2026-10/code/02-mapgen-settlements.md))
- **MGT-14** — will the WP40 evidence and capture modes run again, or may
  they go from `r6_settlement.lua`, `r6.lua` and `r7_runtime.lua`?
  ([terrain code](docs/audit-2026-10/code/01-mapgen-terrain.md))
- **W13-04** — should the Round 14, 20 and 31 POIs use the race palette (a
  visible change) or keep their own material tables? ([wp13 code](docs/audit-2026-10/code/03-mapgen-wp13.md))
- **W13-09** — delete the dead pre-planner generators (`wall_tower`,
  `stilt_platform`, `water_channel`, `fish_landing` …) or keep them as a
  parts shelf? ([wp13 code](docs/audit-2026-10/code/03-mapgen-wp13.md))
- **W13-03** — one small fixture for the `parts.lua` registry mirror tables
  against `tools/wp13/stub_registry.lua`? ([wp13 code](docs/audit-2026-10/code/03-mapgen-wp13.md))
- **X-08** — may the fixed SHA-256 and population pins in
  `grug_gathering` and `grug_farming` go, now that fixtures guard the
  content? ([cross-cutting code](docs/audit-2026-10/code/10-cross-cutting.md))
- **CTX-14** — the per-package calibration records of
  `agent-model-policy.md` §7: still wanted? **Decided 2026-10-06:**
  dropped (`700dd5f6`). ([agent context](docs/audit-2026-10/docs/02-agent-context.md))
- **CTX-26** — where do the decided Nether rules of `TODO-design-nether.md`
  live (a TODO holds only open questions)? ([agent context](docs/audit-2026-10/docs/02-agent-context.md))
- **RDM-08** — name the six peoples in the README under their generic
  names now, or wait for flavour names? **Decided 2026-10-06, done in
  Round 37 D:** named as the game shows them (Human, Dwarf, Elf; Orc,
  Troll, Undead). ([README](docs/audit-2026-10/docs/01-readme-player.md))
- **README and PvP NPCs** — should the README say that Kings, Generals and
  guards attack enemy players regardless of the flag? **Done in Round 37
  D:** one sentence in the PvP bullet (as `pvp.md` §4 and the faction veto
  in `grug_mobs/init.lua`). ([README](docs/audit-2026-10/docs/01-readme-player.md))
- **D18, swimmer exhaustion** (deferred ocean survival) — what, if anything,
  does "Exhausted" do to an unmounted swimmer? Today the ocean's deterrents
  are the Kraken, immutable deep-ocean terrain and the boat-threat rules
  ([boats.md](docs/design/boats.md)); flyers use their warning band and
  no-flight columns ([mounts.md](docs/design/mounts.md)), and no swimmer
  mechanic is authorized. Moved from the dissolved
  `TODO-design-crafting-rework.md` in Round 37 (DI-12). ([item docs](docs/audit-2026-10/docs/05-design-items.md))

### Audit 2026-10 later fix packages

**Not in Round 37** ([plan](docs/planning/round37-plan.md)); details in the
[code audit summary](docs/audit-2026-10/code/00-summary.md#proposed-fix-packages).

- **MGT-03 trees at chunk borders** (the user, 2026-10-05: later, plan
  §2.2.3): owner-only writes drop every tree that crosses a chunk border,
  so treeless bands run along chunk borders and at y ≡ 15..50 mod 80;
  accepted by the R6 contract, the fix is size L
  ([terrain code](docs/audit-2026-10/code/01-mapgen-terrain.md)).
- **P6 beyond MGT-02** (mapgen performance and memory): MGS-01/W13-01
  emerge memory (about 7–10 % of the emerge high-water mark; is server
  memory a concern, or does it wait for WP48?), W13-02 the composition
  rebuild on every boot, MGT-04/MGT-05 surface-only passes, MGS-03 the
  per-chunk palette rebuild ([summary](docs/audit-2026-10/code/00-summary.md#proposed-fix-packages)).
- **P8 structure and legacy:** the wp13/wp40 merge (W13-05; open: is a
  directory rename worth the churn?), mobs_redo as an owned fork (X-06,
  MOB-08; open: may it be declared one?), the `mod.conf` coupling (X-07),
  the tooltip writers (ITM-04) and the other duplications
  ([summary](docs/audit-2026-10/code/00-summary.md#proposed-fix-packages)).

### Character creation in one window (user, 2026-10-05; delivered in Round 35)

**Done:** delivered in Round 35 lane C
([completion](docs/planning/round35-plan.md#completion-2026-10-05)); the
rules are [world.md](docs/design/world.md) §7 and
[character_visuals.md](docs/design/character_visuals.md) §1.1. The request
as written:

Faction, race, class and look in one dialog with a live preview, replacing
today's four separate steps (`grug_factions` faction form, `grug_classes`
`selection.lua` race and class forms, `grug_visuals/creation.lua` look form).

- **Layout:** the faction buttons in a full-width row at the top; below
  them a narrow race column on the left (the selected race's description
  under the list); to its right the class buttons in a row (the selected
  class's description in one line below them) and under them the look
  area: the model on the left, the trait selectors with ‹ › and Random on
  the right, as in today's look dialog. A "Create character" button at the
  bottom right, active only once faction, race and class are chosen, with
  "This choice is final" beside it. The current choices stay highlighted;
  tooltips on every button.
- **Empty states:** before a faction is chosen everything below is empty
  with a short hint; before a race is chosen the right side shows a hint
  and no model is rendered.
- **Changes:** changing the faction clears the race and the look (the class
  stays); changing the race rolls a new random look.
- **Preview:** mouse rotation on, auto-rotation off. The rotation resets on
  every change (the engine rebuilds the model with each formspec); the user
  accepts that. No weapon in the preview (`model[]` cannot show the attached
  wield entity; no replacement wanted).
- **Nothing is stored before "Create character":** the choices are a
  session-only draft; Esc pauses and I resumes within the session; a
  disconnect starts over. On the click everything is stored at once and the
  arrival area is loaded then (the starts are generated at server start, so
  this only reads them from disk, a short wait in the dialog is fine; no
  prefetch on race selection). A reconnect during that wait resumes it
  ("created, not yet arrived").
- **Kept:** creation stasis (frozen, immortal) until the arrival, the wait
  for world preparation at server start, retry after a load failure, the
  dark backdrop. The rewrite simplifies the step machine (no pending class,
  no per-step resume); the work is re-testing those cases, plus the layout
  on small screens and in the web build.

### Money withdraw and deposit: Bag of Coins (user, 2026-10-04; done in Round 34 F2)

**Done:** delivered in Round 34 lane F2 (`grug_money/coins.lua`); the rules
are [economy.md](docs/design/economy.md) §1 (withdraw on the Character page,
the deposit slot, no vendor price, no transfer log, the engine's item
lifetime). A deliberate design change: players can give money to each other
for the first time (a high-level character can fund an alt; acceptable
without a market).

### Sound (V1; user, 2026-10-03; delivered in Round 34)

**Done:** Round 34
([completion](docs/planning/round34-plan.md#completion-2026-10-04)) built
V1's sound after the user's seven decisions (round34-plan.md §2.1: CC0
sources first with CC BY where clearly better; neutral cues per NPC role;
music pools by region group; the picked tracks; music pushed on demand,
on by default; quiet beds per region; no weather in V1) and the user's
picks on the listening pages. Rules: [sound.md](docs/design/sound.md);
credits: [CREDITS.md](CREDITS.md). The ambience pilot (human beds only) was
extended to every zone in the same round, so no zone waits for a bed.
Every new or changed sound goes through a listening page (sound.md §1).

### Weather (optional; user, 2026-10-04)

Not V1 (round34-plan.md §2.1 ruling 7): no weather system exists; distant
thunder plays as a rare ambience call on the dragon islands without one. An
optional later package: a small weather system with its own sky, particles
within the web budget (hundreds, never thousands) and a rain bed, which
would also be the place for the rain recordings the user turned down as bed
backgrounds. Not planned yet.

### Items and professions design session (user, 2026-10-03)

**Done:** held with the user 2026-10-03/04; its rulings are
[round33-plan.md](docs/planning/round33-plan.md) §2 and became Round 33
([completion](docs/planning/round33-plan.md#completion-2026-10-04)). Kept
for its record:

The [items and professions analysis](docs/research/items-professions-analysis-2026-10.md)
(Round 32 R3) decides nothing; it prepares a design session with the user.
Options (§4): 1 close the dead ends and fix progression (S–M), 2 a value
pass so stats and item level mean something (M; the
[enchantment revision](#enchantment-and-item-level-revision-user-2026-10-03-a-later-round)),
3 a crafter's market (M), 4 every profession makes something per tier (L),
5 the endgame layer of WP5/WP10 (XL). The 16 questions (§5): player
payments; trinkets, spellbooks and large bags outside professions; quest
gear; the 67 signatures without a recipe use; enchant-only professions;
equal stat values; item-level scaling; found-gear sell value; masterwork;
cultural finishes and materials; PvP counters and the Warding Draught; money
at level 60; late starters; throwaway progression crafts; the small
promises (×5 leather, bandages, apothecary gear, gem blocks, reagents); the
vendor Uncommon.

Side findings: the vendor Uncommon is gone and shields, spellbooks and
trinkets drop from mobs (Round 33); royal guards and other encounter adds
drop no gear by design (Round 34 ruling 7).

### Seed-dependent POI placement (user, 2026-10-03; optional, set aside)

**Taken up again by the user (2026-10-09) for Round 46:** random seeds can
still fail at load ("river covers the core of POI", e.g. seed
8507030740356938342); the long-term fix is POI placement adapted to the
roads and rivers instead of fixed anchors. The record below is the earlier
state.

Set aside by the user (2026-10-03): optional, not planned for now; POIs and
the fortresses stay at their fixed positions. Confirmed by the user
(2026-10-04, after the Round 34 seed failure): the map stays as it is; robustness comes
from testing (a seed fleet before merging world-generation changes and at the end of
such rounds), not from moving POIs. If they move,
the zone's mob-level distribution must be respected too (a POI's level band
must fit the level field where it lands).

Today every one of the 118 anchors has fixed coordinates in
`grug_mapgen/wp40/source/simple_map.lua` (`layout_fixed` / `authored_fixed`,
"frozen layout"); the world plan builds on them in a fixed order (core
flattening, road routing, protection, region-map cache, quest targets).
The proposal, if chosen:

- **Start towns and capitals stay fixed.**
- **POIs, camps (bandit, Mirefolk, PvP war camps), outposts, mines and the
  two PvP fortresses are placed per seed**, once at the first world build,
  as well fitted to the terrain as possible and by each kind's rules (for
  the fortresses: dry, flat, near the Battlegrounds and the middle road).
- Shape: run the placement pick that lane M built offline
  (`tools/r31_m/candidates.lua`, `pick.lua`, `spacing_check.lua`) on the
  natural terrain before flattening and road routing; identical in the main
  and emerge environments; spacing and zone/level-band rules checked
  online; the result stored in the world-layout cache. Quest texts already
  use placeholders, so positions may change per world.
- Risk: it reorders the world plan; frozen pins, quest-target checks on six
  seeds and the region-map cache must follow.

### Enchantment and item-level revision (user, 2026-10-03; a later round)

**Done in Round 33** (lanes DS and C4): enchant values grow continuously
with item level up to their tier's cap, bosses drop item level 65/70 with
T7 enchants, the crown adds five more levels and one tier
([item_tiers.md](docs/design/item_tiers.md) §1, §4). The note below is the
state before it.

The user plans to rework enchantments; item level should then make boss
drops clearly stronger. How it works today (`grug_gear/init.lua`,
`grug_quality/init.lua`):

- Vendor and starter gear carries the bracket item level (3, 10, 20, 30, 40,
  50). Dropped gear stores its own level per stack (`grug_ilvl`): the mob's
  level capped at 60, the General 65, kings 70, dragons 75.
- Item level scales weapon damage linearly (one-hand about 4 + 0.35 × ilvl:
  22 at 50, 29 at 70), the armour value linearly per material, and the
  weapon level requirement (`min(ilvl, 60)`).
- Affix values come from only four item-level bands (≤ 15, ≤ 30, ≤ 45,
  ≤ 75), so an item level 46 piece rolls the same range as a dragon drop;
  bosses differ only through their better roll window.
- Idea: scale affix values with item level (linear or finer bands) so king
  and dragon drops carry noticeably stronger enchantments; part of the
  enchantment rework, with a balance pass over all nine stats.
- Round 32's [analysis](docs/research/items-professions-analysis-2026-10.md)
  measures the gap (§2.2, §2.3: attack speed +4–14 % per enchant against
  strength about 2.6 % and crit at most 1.2 %) as its option 2; the
  [design session](#items-and-professions-design-session-user-2026-10-03)
  decides.

### Round 26 capital wall follow-ups

**Noted 2026-09-30** after the playtest fix `1ff541e4` (wall–gatehouse gaps
10336 → 0 and leaking gates 2287 → 0 over 200 seeds; river dips 271 → 86 by
`tools/r26_capitals/gate_gaps.lua`, whose merged dip metric undercounts a
crossing plus a bend clip). Lethariel leaves more of its crown lake shore
unwalled; the user accepted this.

- River V-dips still occur where a whole run of rays sits on the far bank:
  the bank-run pass moves rays one at a time and never the whole run back to
  its neighbours' bank (for example seed 9469376632389957802, Lethariel and
  Kezamba). Same as before the fix, not a regression against main.
- Streets on the wall line: after the Round 27 playtest fix (lanes, squares,
  junctions and the plaza keep off the wall band; every gatehouse's outermost
  column is a tower) capital plans with a wall opening away from a gate fell
  from 58 to 6 of 1200 over 200 seeds. The remaining 6 (Lethariel seeds
  10977656699485584087, 10086036900283954633, 17175927337665330950,
  13094141985803758170; Kezamba 14402018182688909832; Gor Drazhak
  17608184500408850831) are outline geometry: where the gate-line pass stops
  at water, the wall leaves a gatehouse through its inner face and the avenue
  covers the wall line beside the box. Options: let the wall win over avenue
  columns beside a gatehouse (cheap, may narrow the approach), or make the
  wall leave the box sideways (cleaner, touches the river-dip tuning and needs
  a new dip run). Deferred by the user 2026-09-30.

### First-public-release gates

**Open; owner: the project coordinator preparing the first public release.**
Trigger: freeze the intended release candidate, before asking the user to approve
that release. These obligations remain visible after WP40 development completion
by explicit user decision on 2026-09-13; they are not passed or waived gates.
Rewritten 2026-09-29 after the WP audit (E9, E10).

Gates:

- Freeze game/engine/settings identity and choose the intended public seed.
  Since Round 22 D24 the coast and borders vary per seed, so the seed is a
  free choice.
- Complete the Z-Image media gate for `menu/icon.png`: set ContentDB's
  **AI-generated media flag** (content policy §4.3), credit Z-Image, retain Jan
  Hangebrauck as prompt/mask author and rights holder, keep the source render
  and derivative under CC0 1.0, and retain the source/prompt/export record in
  `menu/LICENSE-media.md` (added 2026-09-16).

Release checks with judgement, not gates (E10: sometimes thorough, never a
rigid rule that forces hour-long tests):

- Start, generate and restart the candidate on the native engine, as deep as
  the changes since the last playtest warrant; there is no mandatory native
  smoke with runtime/RSS evidence.
- The PUC Lua 5.1 (fallback-engine) run is **optional** (E9): at most one
  crash smoke test once the mapgen is finished (Round 22 D1).
- One spot check of resource supply and regional access on a few seeds (rough
  ~5 % parity target, `world_zones.md` §11; Round 22 D21).

Evidence boundary: [R8](docs/research/wp40-simple-map-r8-contract.md) and
[WP40 completion](docs/research/wp40-completion.md) are historical owner texts,
superseded for these checks by Round 22 D1/D5 and the decisions above. This is
a development-WP completion, not a public release. Fresh-server mode ended
with 0.41.0 (the user's announcement, 2026-10-07; release mode in AGENTS.md).
Plain Lua 5.1 compatibility of the code
stays a hard rule throughout development; only PUC runtime testing is
optional.

## Historical receipts and unresolved carry-overs

The [pre-consolidation backlog](docs/archive/planning/backlog-before-consolidation.md)
retains original completion records, review calibration, runtime observations,
old acceptance descriptions and carry-overs. Its obsolete migration, radial-map,
soft-lock, ballistic and refinement instructions do not govern new work.

Do not silently discard a historical carry-over merely because its parent WP is
marked delivered. Reconcile it against current design and the domain findings;
if still open, retain an owner here. The current documentation round records its
coverage and remaining uncertainties rather than declaring every old claim verified.

For execution use the [round workflow](docs/process/round-workflow.md), current topic rules
and a refreshed bounded task brief. Historical research briefs are starting
material, not permission to restore superseded requirements.
