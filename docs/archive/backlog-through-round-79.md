# Backlog through Round 79 (archive)

Cold storage, not a current contract. On 2026-11-16 the documentation cleanup
([plan](../planning/docs-cleanup-plan.md) step 5) cut `BACKLOG.md` to the open work.
Each round's residual notes moved into that round's plan as a "Carry-overs"
section; this file keeps, verbatim, everything else the backlog held at commit
`56712959`: the delivery receipts ("Readiness", the `### Round N` sections), the work
package table and the WP48/WP49 records, the delivered or superseded requests, the
carry-overs of releases without a round plan (0.66.1, the UI modernization 0.60.1 and
the UI dialogs 0.61.1), and the original wording of the sections that the new backlog
condenses. Links point at where their targets live now; anchors that moved into the
round plans point there. Open items are in the [backlog](../../BACKLOG.md); git history
keeps the full old file.

## Round 75.2 — decoration corrections (GUI acceptance pending)

Material and city follow-ups from the first playtest are reviewed, tested,
merged into main and synced locally; not pushed. User acceptance covers the corrected props,
larger houses, profession trainers and obstacle-free royal halls:
[fix plan](../planning/round75.2-plan.md). No new gameplay systems or prices.

## Round 75 — decorations for homes and cities (GUI acceptance pending)

Implementation is merged into main on the completed Round 74 baseline;
reviewed history is preserved by `round-75`. Not pushed. Design: [decorations.md](../design/decorations.md). Remaining acceptance:
[desktop/web checklist and art gallery](../planning/round75-plan.md#6-verification-and-gui-checklist).
No implementation family from the approved E01–E20 / N01–N32 / A01–A05 list is deferred.
Map-reset declaration joins the planned deployment; no production reset was run.

## 0.66.1 — performance log lines (carry-overs)

Delivered in 0.66.1 (compatible): `grug_perf`, the `[GRUG-PERF]` minute,
spike and `profile_saved` lines and the settings `grug_perf_monitor` and
`grug_perf_profile_minutes`
([module guide](../technical/module-guide.md#performance-log-lines)).
Review notes (no severity):

- **Silent profile setting:** with `grug_perf_profile_minutes` above 0 but
  the engine's `profiler.load` off, the periodic save does nothing without
  a word (`mods/CORE/grug_perf/init.lua`). The setting's description says
  so; one info line at load would help an admin who set only one of the
  two.
- **Spike rounding:** a spike line can show `step_ms` 250 for a 250.04 ms
  step (counted correctly as a spike, rounded to 0.1 ms for the line).
- **Minute callback errors:** an error inside the once-a-minute summary
  would surface as a globalstep error. Every call in it is safe today.

## Round 64 — map icons (GUI acceptance pending)

The approved [atlas icon rules](../design/world_map.md#icons-and-markers)
are implemented: shared 32px assets and sizes, bounded alpha-aware placement,
and separate minimap markers with unchanged terrain resolution. Remaining:
the user's desktop/web [GUI checklist](../planning/round64-plan.md#5-verification-and-acceptance).
Delivery and technical receipts: [Round 64 plan](../planning/round64-plan.md).
Compatible presentation change; no additional deployment reset or migration.

## UI review follow-ups (2026-10-26)

Requested during [UI polish review](../planning/ui-polish-review.md); these
are separate future work, not changes authorized by the browser study.
The [UI implementation](../planning/ui-polish-implementation.md) was merged
on 2026-10-27; these two follow-ups remain open.

- **Shipwright venue:** evaluate a small dedicated building or an annex beside
  the stable, displaying the actual boats, optionally in a shallow display
  pond. Preserve the trainer's access and purchase rules. Check settlement
  footprint, navigation, water/boat presentation and generation implications
  before choosing a layout; no new building or pond is committed as design.
- **Claim recovery scale:** audit very large claims, including the user's
  example of 10,000 chests. The current recovery UI enumerates stored recovery
  entries and grows its list; a packed container is one entry, not one item.
  No application hard cap was found in these paths, which is not a guarantee
  that storage, migration, metadata, detached inventories, transfer validation,
  network payload and client rendering support arbitrary counts. Measure the
  whole recovery path and failure behavior before proposing bounds or paging.
  Do not add a cap, truncate stored contents or build virtualization as part
  of the layout work. Owners: `grug_housing/recovered.lua`,
  `grug_housing/stone_form.lua`, the map-reset container migration tools;
  [housing design](../design/housing.md).

## Player experience follow-up (2026-10-11)

Open follow-up work from the user's playtest assessment of 2026-10-11.
Priority and direction live in the
[ROADMAP](../../ROADMAP.md#next-priorities--deepening-the-playable-game).
These packages refine delivered systems; they do not reopen historical WP
receipts or change the identity counts below. No round is assigned yet.
Current design rules remain in force until the respective design pass
settles their replacements; this entry does not specify new skills, talent
layouts, resource tables or buff values.

## Classes, talents and progression

- Review all four classes over the leveling journey: starting kits, talent
  unlocks, the feel of progression and customization, ability interactions
  and rotations. The user's assessment is that the trees are not yet
  cohesive and the skills remain basic; the Scout currently feels worst
  to play and needs particular attention.
- Review revised kit and talent proposals against the roadmap's direction,
  including how their mechanics work together in group play and PvP.
  A working ability implementation alone does not settle class feel or
  balance.
- **The class rework is built:** planned 2026-10-12 to 2026-10-20
  ([delivery plan](../planning/class-redesign/delivery-plan.md)); Round
  52 built round F, the foundation, and Round 53 round K, the four new kits
  and talent graphs with an automatic talent reset
  ([Round 53](#round-53--the-new-classes)); the fix round 0.53.1 followed
  the user's first look (areas without line of sight, the range line,
  racials, the redrawn icons). 0.53.0 to 0.54.1 were pushed on 2026-10-21;
  next: their GUI test with 0.55.0's, the playtest and a short balance fix round
  ([Round 53 carry-overs](../planning/round53-plan.md#carry-overs),
  [0.53.1 carry-overs](../planning/round53-fix-plan.md#carry-overs)).
- Current owners: [classes](../design/classes.md),
  [talents](../design/skill_trees.md), [Scout](../design/scout.md),
  [combat](../design/combat_stats.md) and [PvP](../design/pvp.md).

## Atmosphere, world variety and resource distribution

- Review music, sound effects, regional ambience and icons for quality and
  consistency. Preserve what already works: the user particularly likes
  the human areas' daytime birds and nighttime crickets. Wind-dominated
  areas currently lack that richness. Use those contrasts to guide the
  listening and visual review; retain the existing exact-file sound
  approval process. Round 52 moved the beds from the race zone to the
  biome, gave the badlands, the swamp, the crags, the snowy crags and the
  Battlegrounds beds of their own, wind only at height and on peaks, and
  animal calls ([Round 52](#round-52--ambience-and-the-class-rework-foundation)).
- Review surface variety, tree shapes and city variety, and prepare changes
  that give exploration and settlements more character. Round 47 built the
  tree rework (generated trees per world, greener towns and capitals) and
  the swamp ([Round 47](#round-47--trees-mining-progression-and-crafting-feedback)),
  Round 51 a few characteristic changes in every other land zone
  ([Round 51](#round-51--land-zones-and-the-sea)); city variety stays
  open.
- Reassess ore, gem and coal availability through the depth tiers, then
  revise the distribution design and data. Round 46 made a first pass
  (gems one and two tiers deeper at half and a quarter, Coal and Iron
  raised in T3; [items_crafting.md §3.0.1](../design/items_crafting.md#301-universal-materials-and-resource-taxonomy)),
  Round 47 a second (next-tier ores only in the lower half of the band
  before, Iron behind a Bronze pick, Anthracite replacing Coal from T3);
  a broader revision is checked against gathering and crafting
  progression first.
- Current owners: [sound](../design/sound.md),
  [world](../design/world.md), [settlements](../design/settlements.md)
  and [materials and crafting](../design/items_crafting.md).

## Crafting and Cooking variety

- Review the crafting experience as well as the recipe roster. The user
  considers the current recipes a good foundation; the follow-up should
  add variety, wit and versatility, especially to Cooking.
- Explore more distinct and useful buff foods as part of the Cooking
  design pass, then review their ingredients and usefulness through
  progression. This is a direction to investigate, not an approved buff
  list or set of values.
- Current owners: [professions](../design/professions.md),
  [recipes and food](../design/items_crafting.md) and
  [economy](../design/economy.md).

## Quest onboarding and immersion

- Walk the early quest experience from a new player's perspective, identify
  where the game leaves its mechanics unexplained, and revise the quest
  flow to teach them more naturally.
- Review how quest tasks, dialogue and surroundings support immersion;
  develop improvements on the existing framework rather than treating
  its delivery as the end of quest refinement.
- **Player feedback 2026-10-12, deferred to the quest/content round:**
  fewer distinct mob names and roles (461 names; one route meets 177),
  fewer and merged loot items with their recipes, and quest variety with
  new objective types at the new seed-placed POIs (about 83 % of quests are
  kill or kill-for-drop). Round 46 removed the repeatables, stopped the 23
  sell-only drops and built the placement
  ([Round 46 plan](../planning/round46-plan.md)); Round 59 took the band
  11–20 to 21 % kill objectives (no kill-for-drop) and three mob names per
  zone ([quests.md](../design/quests.md#the-band-1120)); Round
  60 took the band 21–30 to 17–27 % per zone and about three mob names per
  zone, and the capitals to 2–3 names of their own
  ([quests.md](../design/quests.md#the-band-2130)); Round 61
  took the band 31–40 to 25–38 % per zone and 3–5 mob names per zone
  ([quests.md](../design/quests.md#the-band-3140)); Round 62
  took the free front 41–60 to 25 % (The Accord) and 18 % (The Throng)
  kill objectives and 4–6 mob names per front zone and faction
  ([quests.md](../design/quests.md#the-front-4160)), which
  completes the quest rework of levels 11–60.
- Current owners: [quests](../design/quests.md) and
  [story](../design/story.md). Coordinate teaching steps with the class
  and crafting revisions above.

## Readiness

There are **54 identities**: WP0–WP50 and WP-Scout/WP-HUD/WP-Speed.
**48 delivered**, **3 canceled** (WP16, WP37, WP49), **3 open or partial**
(WP42, WP46, WP48).
The 2026-09-29
[WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
closed WP14, WP21, WP22, WP23, WP27, WP29, WP31 and WP32 as delivered, merged WP7's rebase, WP11, WP30 and the price parts of WP22 and
WP31 into WP44 (WP11 and WP30 count as delivered), and canceled WP37 and WP49.
WP28 followed in Round 26, WP50 in Round 27, WP17 and WP44 in Round 29, WP41
in Round 31 (with WP42's PvP-POI part), WP5 and WP10 in Round 33, WP9 and
WP13 in Round 36. The audit's letters and numbers (for
example E5) are cited below. WP34 followed in Round 46.

- **Latest delivery: [Round 48 "Mail, plants and light, selling, smaller
  bags"](../planning/round48-plan.md#completion-2026-10-14)**
  (2026-10-14, version 0.48.0, **map reset** plus the step 0.48.0; not
  pushed; GUI test open): mailboxes, letters with attachments, messages to
  the admin and the Admin Mail tab, the starter quest and the welcome and
  level letters, plant light, Melon and Mushroom crops, the Salt Pan,
  selling almost everything in lots, cactus and leaf fuel, the daytime band
  and bags at half size with the leftovers mailed
  ([Round 48](#round-48--mail-plants-and-light-selling-smaller-bags),
  [carry-overs](../planning/round48-plan.md#carry-overs)).
- [Round 47 "Trees, mining progression and crafting
  feedback"](../planning/round47-plan.md#completion-2026-10-14)
  (2026-10-14, version 0.47.0, **map reset** plus the step 0.47.0;
  GUI-accepted together with 0.46.0 and pushed at `6a8afb9f`): trees from the seeded generator, greener towns and capitals, the
  swamp, the lower-half ore rule and the Bronze gate, Anthracite and Steel
  from it, quieter furnaces, crafts into the inventory, the Basic unlock by
  held ingredients, NPC facing, first-entry zone XP and the map window's
  marker layers ([Round 47](#round-47--trees-mining-progression-and-crafting-feedback),
  [carry-overs](../planning/round47-plan.md#carry-overs)).
- [Round 46 "World generation and player
  feedback"](../planning/round46-plan.md#completion-2026-10-13)
  (2026-10-13, version 0.46.0, **map reset**, never deployed on its own;
  GUI-accepted with Round 47): seed-dependent POI placement, the revised ore, gem and coal
  table, kill XP by level difference, the repeatables removed, underground
  spawns and the depth pulse (WP34), rage by weapon speed and the caster
  spell base, coin bags, plain dishes, repair only in towns and the
  waiting point ([Round 46](#round-46--world-generation-and-player-feedback),
  [carry-overs](../planning/round46-plan.md#carry-overs)).
- [0.45.1, the fix round after the 0.45.0
  playtest](../planning/round45-plan.md#0451-fix-round-2026-10-10)
  (2026-10-10, compatible, pushed, in production): the riding camera per mount,
  Dismount, Charge on stairs, reliable self-skill clicks, the crafting
  and quest giver fixes, the inventory key closing every window, the map
  zoom's soft lock, "Now playing" and the trainer greetings
  ([carry-overs](../planning/round45-plan.md#0451-carry-overs)).
- [Round 45 "Crafting rework"](../planning/round45-plan.md#completion-2026-10-09)
  complete (2026-10-09, `4a892fd6` and lane D; pushed on the user's
  word after the round-end gates;
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
  [carry-overs](../planning/round45-plan.md#carry-overs)).
- [Round 44 "Inventory, map and quickbar"](../planning/round44-plan.md#completion-2026-10-09)
  (2026-10-09, `36019071` and lanes MS and D, version 0.44.0,
  **migrate**: the first declared step; pushed by the user on 2026-10-09
  inside `2f918739`; GUI test open):
  Round A of the UI rework — the window with fixed tabs, the give helper,
  bags in bags, Sort and the potion belt, the Character tab, Talents &
  Skills with hotbar-only skills, Party & PvP, the baked pixel-art map,
  the map window with the quest log and targets on Z, the quickbar on E;
  step 0.44.0 removes mount items and skills outside the hotbar offline
  ([Round 44](#round-44--inventory-map-and-quickbar),
  [carry-overs](../planning/round44-plan.md#carry-overs)).
- [Round 43 "World migrations"](../planning/round43-plan.md#completion-2026-10-08)
  (2026-10-08, `d10018a7` and lane D, version 0.43.0, compatible, pushed
  2026-10-09 as `9dc2fad5`; GUI test open): the migration tool, the world
  version record, the start guard and the online-work runner, with an
  empty `migrate` list ([Round 43](#round-43--world-migrations),
  [carry-overs](../planning/round43-plan.md#carry-overs)).
- [Round 42 "Mob navigation"](../planning/round42-plan.md#completion-2026-10-08)
  (2026-10-08, `f8265d60` and lane D, version 0.42.0, compatible,
  playtest accepted, pushed 2026-10-08 as `332c5e79`): one navigation module on the
  engine's pathfinder for combat, fixed walks and settlement walkers, a
  route cache in start towns and capitals, capital patrols along the
  streets, NPCs that use doors, no random stops on routes
  ([Round 42](#round-42--mob-navigation),
  [carry-overs](../planning/round42-plan.md#carry-overs)).
- [Round 41 "Playtest fixes, the production crash and the upgrade contract"](../planning/round41-plan.md#completion-2026-10-07)
  (2026-10-07, `a3790e65` and lane D, version 0.41.0, pushed 2026-10-08 as
  `71612d19`; the production server moves to it with a map reset; GUI
  test open): release mode and the hosting platform's
  [upgrade contract](../technical/upgrade-contract.md) with its map
  reset; the production crash loop fixed and mapgen failures reported as
  `[GRUG-SEVERE]` instead of stopping the server; the Round 40 playtest
  fixes (walk animation, kings and Generals at their seat, the recipe
  book's Close and multi-item slots, the bow's missed release, the quiver
  total, stale map tiles, the waterweed bed)
  ([Round 41](#round-41--playtest-fixes-the-production-crash-and-the-upgrade-contract),
  [carry-overs](../planning/round41-plan.md#carry-overs)).
- [Round 40 "Combat feel"](../planning/round40-plan.md#completion-2026-10-06)
  (2026-10-06, `bd52bbf4` and lane D, pushed; its follow-up 0.40.1, ore
  wherever digging is allowed, pushed 2026-10-07; no new world needed;
  GUI test open): the cooldown overlay on the hotbar
  instead of the wear bar, poses and the head look, Charge as a dash,
  particle effects for player skills, bosses and mob specials with
  `grug_particle_scale` ([Round 40](#round-40--combat-feel),
  [carry-overs](../planning/round40-plan.md#carry-overs)).
- [Round 39 "Web data for the realm website"](../planning/round39-web-data-plan.md#completion-2026-10-06)
  (2026-10-06, pushed 2026-10-06 as `d018d866`, GUI-accepted): no gameplay
  change; the level and appearance in player meta, the exported web data
  and the player model as glTF for realm websites
  ([Round 39](#round-39--web-data-for-the-realm-website),
  [carry-overs](../planning/round39-web-data-plan.md#carry-overs)).
- [Round 38 "Mob names"](../planning/round38-mob-names-plan.md#completion-2026-10-06)
  (2026-10-06, `ec2e874c` and lane D, pushed 2026-10-06; a
  fresh world for the test; GUI test open): new names for every mob slot
  from the user's picks, a kill counted by the shown name (the quest
  kill-credit bug fixed), quest texts on the names, the whelps at level
  60, the Kraken, twelve item names, Party instead of Group
  ([Round 38](#round-38--mob-names),
  [carry-overs](../planning/round38-mob-names-plan.md#carry-overs)).
- [Round 37 "Audit fixes"](../planning/round37-plan.md#completion-2026-10-06)
  (2026-10-06, `27e5db87` and lane D, pushed 2026-10-06 as `db848931`; no new
  world beyond Round 36's; GUI test open): the
  [October 2026 audit](../audit-2026-10/README.md)'s code packages P1–P5
  (the combat hot path, mob behaviour, mob persistence and bosses, the
  interaction bugs, per-player polling), MGT-02 with P7 (mapgen), P9
  (sound) and the documentation packages A–F, plus the user's rulings of
  2026-10-06 (start zones fight alone, the Reef Lurker, the minimap at
  normal quality, mob projectiles push)
  ([Round 37](#round-37--audit-fixes),
  [carry-overs](../planning/round37-plan.md#carry-overs)).
- [Round 36 "The main questline"](../planning/round36-plan.md#completion-2026-10-05)
  (2026-10-05, pushed 2026-10-05 as `0f169898` with the follow-up lanes;
  needs a world made on `fef94a6a` or later; GUI test open): WP9
  delivered — each faction's main line from its fortress Warmaster in
  three chapters (41, 46, 53) and a party finale at 60 on the
  approved [story bible](../planning/round36/story-bible.md), the "use at
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
  [carry-overs](../planning/round36-plan.md#carry-overs)).
- **GUI acceptance:** Rounds 25–35 count as GUI-accepted (the user,
  2026-10-05, [Round 37 plan](../planning/round37-plan.md) §2.3.5),
  Round 39 too (2026-10-06), Round 42's playtest (2026-10-08); Rounds
  36–38, 40, 41 and 43–45 are open ([project status](../STATUS.md)).
- [Round 35 "Fixes and character creation"](../planning/round35-plan.md#completion-2026-10-05)
  (2026-10-05, pushed 2026-10-05; its first GUI findings fed Round 36): the user's
  Round 34 GUI findings — the server's aiming rays test rotated selection
  boxes in Lua (T, with the
  [upstream-workaround list](../technical/upstream-workarounds.md)); music
  only in the six capitals, either music or the bed (M); the break sound,
  broken look, empty hand, dig sounds, flint removed, the quest list colours
  and read-only quest text (F); character creation in one window (C); night
  mobs leave at dawn and the drop audit (E); level-proof talents and the
  user's review picks (B)
  ([Round 35](#round-35--fixes-and-character-creation),
  [carry-overs](../planning/round35-plan.md#carry-overs)).
- [Round 34 "Sound"](../planning/round34-plan.md#completion-2026-10-04)
  (2026-10-04, pushed 2026-10-05; the user's GUI test fed Round 35): V1's
  sound ([sound.md](../design/sound.md), [CREDITS.md](../../CREDITS.md)), every
  file picked by the user — effects, hits, ability cues and mob voices
  (S1a, S1b), ambience beds for every zone, loops, dragon-island thunder,
  music pools pushed on demand and the settings (S2); mobs in water (F1);
  text boxes, cooking costs, the Bag of Coins, service markers, the damage
  fit, encounter adds, thin ice (F2)
  ([Round 34](#round-34--sound), [carry-overs](../planning/round34-plan.md#carry-overs)).
- [Round 33 "Items, professions and achievements"](../planning/round33-plan.md#completion-2026-10-04)
  (2026-10-04, pushed 2026-10-04 after Rounds 30–32; needs a fresh world): the
  items design session's rulings and their data
  ([item_tiers.md](../design/item_tiers.md), DS); drops by quality with
  boss double drops, bag drops and the level requirement on all gear (C1);
  Alchemy as a secondary, progress from real recipes and the removals (C2);
  per-character achievements and cloaks (C3); enchant values by item level
  with tiers, profession upgrades, the crown and the profession families
  (C4); crit ×2, T1-only vendors, repair ×1.00, potions I–VI, the
  Crownbinder and the Decor Merchant, the income model green (C5). WP5 and
  WP10 delivered; the user's test findings fed Round 34
  ([Round 33](#round-33--items-professions-and-achievements),
  [carry-overs](../planning/round33-plan.md#carry-overs)).
- [Round 32 "Fixes, preparation and research"](../planning/round32-plan.md#completion-2026-10-03)
  (2026-10-03, pushed 2026-10-04, GUI-accepted): the minimap zoom ×2, hostile
  camps on the Map tab, zone names coloured by territory with a territory
  line (F1); one LMB hold state machine and quest kill labels with the
  zone's mob names (F2); combat and personal notices in the message feed
  and the quest log in one text field (F3); the Map tab, party HUD and
  camp/leader tick spread over steps (F4); three read-only studies
  (performance at 50/100 stand-ins, sound, items and professions)
  ([Round 32](#round-32--fixes-preparation-and-research),
  [carry-overs](../planning/round32-plan.md#carry-overs)).
- [Round 31 "PvP, appearance and clean-up"](../planning/round31-plan.md#completion-2026-10-03)
  (2026-10-03, pushed 2026-10-03, GUI-accepted): WP41 geographic PvP (the
  per-player flag, the PvP tab and markers, the NPC faction filter, PvP from
  depth tier T4), WP42's PvP-POI part (a fortress per faction, 16
  Battlegrounds war camps, garrisons with Generals and named captains, 24
  fortress quests), the appearance package (looks at creation, NPC look
  rolls, enchant colours), the dragon arena redesign and the Round 31
  clean-up lane
  ([Round 31](#round-31--pvp-appearance-and-clean-up),
  [carry-overs](../planning/round31-plan.md#carry-overs)).
- [Round 30 "Performance and clean-up"](../planning/round30-plan.md#completion-2026-10-02)
  (2026-10-02, pushed 2026-10-03, GUI-accepted): the
  [performance review](../research/perf-review-2026-10.md)'s lanes P1–P4
  (quest-state cache and Map tab every 2 s, the region-map file cache and boot
  memory, the per-step A* budget with the give-up of unreachable targets and
  three merged spawn ABMs, per-player ticks), Return home on the Character
  page, piers and beaches at the dragon-island landings, the quest and fixture
  clean-up with the Dawnmere duplication fix, and the band-4/5 loot smoothing
  with recomputed prices ([Round 30](#round-30--performance),
  [carry-overs](../planning/round30-plan.md#carry-overs)).
- [Round 29 "Economy and travel"](../planning/round29-plan.md#completion-2026-10-02)
  (2026-10-02, pushed as `e512bb5c` after the user's fresh-world test): 491 quests on the Round 28
  framework replace the 240 legacy quests (one track per race, the
  contested 31–40 zones, the 41–60 front with repeatable and island
  bounties; WP9 advances); WP44 delivered (one price module, 5% buy-back,
  income-derived mount, boat and respec prices, claim-station repair D7);
  WP17 delivered (boats as water mounts, the Shipwright, waystones at every
  start and capital, the Kraken retune); a mapgen bundle (gems by depth,
  `apex_sockets` removed, mapgen band data, the Battlegrounds 50 % wider
  with a middle road); the spawn playtest fixes; a read-only
  [performance review](../research/perf-review-2026-10.md), which became
  Round 30 ([carry-overs](../planning/round29-plan.md#carry-overs)).
- [Round 28](../planning/round28-questing-leveling-plan.md#completion-2026-10-02)
  (2026-10-02, pushed): the 2026-09-30 playtest fixes, the questing and
  leveling framework, the catalogue with 89 icons and the naming rule,
  rule-based spawn regions for all 38 zones with the border rule,
  quest-log level ranges and zone names. It advanced WP5, WP6, WP8 and WP10.
- [Round 27](../planning/round27-minimap-plan.md#completion-2026-09-30)
  (2026-09-30; pushed): WP50 delivered — our own
  round minimap with quest, service, home and party markers in place of the
  native one, the `grug_map_quality` setting (normal/high) for the Map tab and
  the minimap, readable relief and the tiled map base (Lane M), and the
  documentation (Lane D). GUI-accepted.
- [Round 26](../planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29)
  (2026-09-29, pushed): Claim Stone draft and
  activation with the Housing Steward (Lane S), the registration cleanup
  (WP28 delivered, Lane R), the status-icon package (audit D10, Lane I),
  organic capitals with a character per capital (the D72 follow-up, Lane W)
  and its documentation cleanup (Lane D). GUI-accepted.
  Not in that round: the depth pulse (WP34), WP44, WP17, WP41, WP9, WP5 and
  WP10.
- Round 25 delivers WP24 Housing (pushed, GUI-accepted). Round 24 is
  pushed (`d4eaffff`) and accepted.
- **V1 scope** ([ROADMAP](../../ROADMAP.md#v1-scope)): WP17 boats and waypoints (starts,
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
  crafting stations inside a claim (D7) shipped in Round 29 and was removed
  in Round 46: gear is repaired only in towns
  ([Round 46](#round-46--world-generation-and-player-feedback)).
- **October 2026 audit:** the design questions that block no fix are in
  [Audit 2026-10 open questions](../../BACKLOG.md#audit-2026-10-open-questions), the fix
  packages after Round 37 in
  [later fix packages](../../BACKLOG.md#audit-2026-10-later-fix-packages).

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
| WP5 | [Loot, found-item affixes and cultural/PvP finishes](../planning/work-package-scopes.md#wp5) | **Delivered in Round 33** ([completion](../planning/round33-plan.md#completion-2026-10-04)): drops by quality (normal 5/2/1 %, named and elite 10/10/5 %), boss double drops at item level 65/70 with T7 enchants, shields, spellbooks and trinkets in the pool, bag world drops, the level requirement on all gear; enchant values by item level with a tier cap ([item_tiers.md](../design/item_tiers.md)). The cultural and PvP finishes were removed by the user (round33-plan §2.8); the crown (a Fallen Crown lifts an item to its tier's top + 5, enchants +1 tier) takes the place of the Grudgeforged masterwork (D3). Named rares drop no trophies (D4). Round 28's loot by band and Round 29's payout calibration came before. | WP1 ✅, WP3 ✅, WP43 ✅ |
| WP6 | Mob roster, threat, guards and combat feel | Delivered; historical receipt below. Round 28 adds sub-types (195 incl. 49 named leaders) and rule-based spawn regions for all 38 zones ([spawn_regions.md](../design/spawn_regions.md)); Round 29 sets leader HP to 1.5×; Round 30 lets mobs give up unreachable targets, merges the spawn ABMs and fixes the start-NPC duplication. Round 31 adds NPC look rolls, the PvP garrisons (Generals, bodyguards, camp captains) and the round dragon arenas. Round 42 replaces the stuck handling with navigation on the engine's pathfinder (combat, fixed walks, settlement walkers, doors). Current rules: topic design. | — |
| WP7 | Ledger currency and traders | Delivered; Round 29 (WP44) replaced its price curve and 25% buy-back. | — |
| WP8 | Quest framework | Framework delivered; Round 20: 240 quests with talk handoffs. Round 28: per-zone quest data, area, item-group, multi-objective and quest-drop objectives, repeatables, travel credit on accept, load-time validation, target level ranges in the log. Round 29: text placeholders filled per seed, the compass-word check, copper from weight. Round 30: the legacy fields removed (unknown fields stop the load), the decoded-state cache and markers that follow held items and levels. Round 31: givers serve only their faction, PvP garrison kill objectives, PvP POIs as placeholder targets. Broader story remains WP9. | — |
| WP9 | [Named-zone story and questlines](../planning/work-package-scopes.md#wp9) | **V1. Delivered in Round 36** ([completion](../planning/round36-plan.md#completion-2026-10-05), rules [quests.md](../design/quests.md) "The main line", [story.md](../design/story.md)): each faction's main line 41–60 from its fortress Warmaster (chapters at 41, 46, 53, the party finale at 60 on the rift boss) on the approved [story bible](../planning/round36/story-bible.md), the front climaxes folded in, the "use at a place" objective filling each contested zone's quest-interaction slot, ten corrupted sub-types, three achievements with cloaks; the rift at Tombroad Ambush. Before: Round 29's 491 quests on the Round 28 framework (a track per race, the contested 31–40 zones, the front with bounties), Round 31's 24 fortress quests; 540 quests now. GUI test open (Round 36). | WP6 ✅, WP8 ✅, WP40 ✅, WP41 ✅ |
| WP10 | [Profession content and priced integration](../planning/work-package-scopes.md#wp10) | **Delivered in Round 33** ([completion](../planning/round33-plan.md#completion-2026-10-04)): six primaries and the secondaries Cooking and Alchemy; progress only from real recipes; enchant recipes per channel and tier and one upgrade per profession and tier give 68 of 94 signatures a use; two professions dress each class (bows with the Leatherworker, spellbooks with the Tailor); fixed potions and elixirs T1–T6. Cultural finishing and its helper NPCs were removed by the user (round33-plan §2.8). Round 28 made every profession self-contained. | WP5 ✅, WP26 ✅, WP33 ✅, WP43 ✅, WP44 ✅ |
| WP11 | [Talent trees](../planning/work-package-scopes.md#wp11) | Delivered; closed 2026-09-29, respec price merged into WP44 (C2) and set in Round 29. | WP3 ✅, WP4 ✅, WP-Speed ✅ |
| WP-Scout | Scout class and talent trees | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-HUD | Exact health/resource HUD | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-Speed | Shared movement modifiers | Delivered; historical receipt below. Current rules: topic design. | — |
| WP12 | World atlas | Delivered through R19: whole-atlas zoom/scroll and live markers; waystone markers came with WP17 (Round 29). | — |
| WP13 | [Remaining authored structures and POI roster](../planning/work-package-scopes.md#wp13) | **Delivered** with Round 36's POI review: Round 20 completes roster art; Round 21 improves access/ground; Round 23 walls all six capitals. `bandit_frontier` core stays 16 (E1); Round 26 gives every capital its own outline and character (D72); Round 31 adds the PvP fortress and camp blueprints. Round 36: the separate POI walk (E2) became a render page of all 106 POIs with the user's verdicts, and the decor pass it asked for (a theme per POI kind, house touches in POIs, start towns and capitals; [settlements.md](../design/settlements.md) "Decor pass"); GUI check in the Round 36 checklist. | WP40 ✅, WP43 ✅ |
| WP14 | [Offhands](../planning/work-package-scopes.md#wp14) | Delivered; closed 2026-09-29. Carried light canceled (C5). | WP3 ✅ |
| WP15 | Character equipment and bags | Delivered; historical receipt below. Current rules: topic design. | — |
| WP16 | Canceled historical proposal | Canceled 2026-08-12; no game code shipped. | — |
| WP17 | [Boats and waypoint travel](../planning/work-package-scopes.md#wp17) | **V1.** Delivered in Round 29 ([travel plan completion](../planning/travel-boats-waypoints-plan.md#completion-2026-10-02)): boats as water mounts from the Shipwright in every capital (the only access to the dragon islands), waystones at every start and capital, the Kraken retune. No `/unstuck` (B3). The user's Round 29 test passed; Round 30 adds a pier and a beach at each island landing (`boats.md` §7.1). | WP40 ✅, WP13 ✅ |
| WP18 | First continent map (superseded by WP40) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP19 | Original kit and race-passive tuning | Delivered; historical receipt below. Current rules: topic design. | — |
| WP20 | Same-faction parties | Delivered R14–19: persistent parties, management and optional HUD. | — |
| WP21 | [Recovery/rest](../planning/work-package-scopes.md#wp21) | Food recovery delivered; closed 2026-09-29: food is the recovery system, no natural HP regeneration, no rested XP. | WP1 ✅ |
| WP22 | [Tool wear and repair](../planning/work-package-scopes.md#wp22) | Delivered; closed 2026-09-29. Dig speed stays as in the game (D8); prices to WP44; claim-station repair (D7) below. | WP43 ✅ |
| WP23 | [Dragon encounters](../planning/work-package-scopes.md#wp23) | Delivered R8–R10; closed 2026-09-29. Boat route → WP17, island PvP → WP41 (delivered); no hoard chest (E11), no apex sockets (E5). Round 31 redesigns the arenas (round leash arenas with hazards, `world.md` §4b). | — |
| WP24 | [Open-world Claim Stone Housing](../planning/work-package-scopes.md#wp24) | Delivered in Round 25 ([completion](../planning/round25-housing-plan.md#completion-2026-09-29)): Claim Stones as in `housing.md`, no price, housing masks removed; road and POI protection alongside. Round 26 Lane S adds the draft and 5-lump activation, the 12 h pick-up lock, the Housing Steward and admin removal. GUI-accepted with Rounds 25 and 26 (the user, 2026-10-05); carry-overs below. | WP40 |
| WP25 | Original strata/materials (superseded by WP43) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP26 | Furnace and alloy chain | Delivered; historical receipt below. Current rules: topic design. | — |
| WP27 | [Armor catalog](../planning/work-package-scopes.md#wp27) | Delivered; closed 2026-09-29 (no G2 surcharge, Round 10 ruling 7). | WP26 ✅, WP43 ✅ |
| WP28 | [Remove superseded recipe/tool registrations](../planning/work-package-scopes.md#wp28) | Delivered in Round 26 Lane R: mobs_redo utility items removed (D5), silver-sandstone recipes removed (D6), all tier tools under `grug_materials:` with 12 aliases (D9), two surface critters at 0.75 density, `chance` 2200 → 2933 (C6). | — |
| WP29 | [Gear/tool catalog](../planning/work-package-scopes.md#wp29) | Delivered; closed 2026-09-29. Tool-namespace unification moved to WP28. | WP26 ✅, WP43 ✅ |
| WP30 | [Trader catalog](../planning/work-package-scopes.md#wp30) | Catalog delivered; closed 2026-09-29, prices merged into WP44 (C2). | — |
| WP31 | [Mounts](../planning/work-package-scopes.md#wp31) | Delivered (C3); prices merged into WP44 and set in Round 29; boats are the water mode since Round 29. | WP40 ✅ |
| WP32 | [Farming](../planning/work-package-scopes.md#wp32) | Delivered 2026-09-29 (C4), GUI-accepted with Rounds 25–35 (the user, 2026-10-05); Claim Stone integration shipped with WP24. | WP24 ✅, WP33 ✅ |
| WP33 | Gathering/source catalog | Delivered; Round 23 replaces exact-baseline renewal with habitat-driven renewal ([receipt](../research/round23-habitat-renewal.md)). Current rules: topic design. | — |
| WP34 | [Deep spawn pulse](../planning/work-package-scopes.md#wp34) | Delivered in Round 46 ([completion](../planning/round46-plan.md#completion-2026-10-13), rules [biomes_mobs.md §4.1](../design/biomes_mobs.md#41-the-depth-pulse-decided-2026-08-08-built-round-46)): the user's curve below −300, flying servants in line of sight, the Riftwing below −1000; the Land Guard and the Rift Spawn's deep row joined the pulse (E4). Renewable camp resources removed. | WP6 ✅, WP40 ✅ |
| WP35 | Equipped weapon source and appearance | Delivered; historical receipt below. Current rules: topic design. | — |
| WP36 | Reference submodules and first runtime fixes | Delivered; historical receipt below. Current rules: topic design. | — |
| WP37 | [Surface-density cut](../planning/work-package-scopes.md#wp37) | Canceled 2026-09-29: superseded by Round 24 ruling 27 (about 1.5× density). Only Bone Weevil and Bog Fowl get 0.75 density (`chance` 2200 → 2933), delivered with WP28 (C6). | WP6 ✅ |
| WP38 | Held melee timing and settlement | Delivered; historical receipt below. Current rules: topic design. | — |
| WP39 | Crosshair-authoritative combat | Delivered; historical receipt below. Current rules: topic design. | — |
| WP40 | Named-zone world foundation | Development delivery accepted; first-public-release gates remain open. | — |
| WP41 | [Geographic PvP](../planning/work-package-scopes.md#wp41) | **V1.** Delivered in Round 31 ([completion](../planning/round31-plan.md#completion-2026-10-03), rules [pvp.md](../design/pvp.md)): a per-player flag (location, button, contact) instead of the old transaction; the PvP tab, icons, banner and target frame; the NPC faction filter; PvP from depth T4. GUI-accepted with Round 31 (the user, 2026-10-05); the engineering brief is historical. | WP39 ✅, WP40 ✅ |
| WP42 | [Bounded war-front encounters](../planning/work-package-scopes.md#wp42) | **After V1** (scripted battles). The PvP-POI part shipped in Round 31: two fortresses and 16 Battlegrounds war camps with garrisons and quests ([pvp.md](../design/pvp.md) §6). Clash anchors and art delivered; no war-unit runtime. | WP13 ✅, WP40 ✅ |
| WP43 | Canonical material/depth registry | Delivered; Round 24 replaces pick depth bounds and shatter with tier rock and engine-native gating (rulings 1–8). Current rules: topic design. | — |
| WP44 | [Economy rebase, lighter pass](../planning/work-package-scopes.md#wp44) | Delivered in Round 29 ([lane status](../planning/economy-vendor-plan.md#lane-status-round-29-2026-10-02)): one price module for every payout, 5% buy-back on vendor goods, the vendor rule and shelves, the audit fixes, quest copper from weight, repair at claim stations (D7), mount, boat and respec prices from a simple income estimate (D1, D2); gems by depth. The user's Round 29 test passed; Round 30 smooths the band-4/5 loot medians and recomputes Expert Riding and two respec prices. | WP7 ✅, WP43 ✅ |
| WP45 | Character-creation stasis and safe arrival | Delivered; Round 24 makes creation pausable (ruling 32). Current rules: topic design. | — |
| WP46 | Indirect terrain-damage guard | Partial: actor-neutral guard and protected water flow delivered; the fire/explosion remainder is deferred until a fire or explosion source exists (expected with V2's Nether) (E6). | WP40 ✅, WP24 ✅ |
| WP47 | Skills catalog and recoverable representations | Delivered R12–13; current rules in inventory_equipment.md. | — |
| WP48 | Mapgen writer performance and parallel emerge | Partial: Round 49 did the single-thread part ([completion](../planning/round49-plan.md#completion-2026-10-16)); several emerge threads wait for Luanti #9357, the cold planner and the first-start pre-step remain. | WP40 ✅ |
| WP49 | Fixed mapgen source-audit roster | Canceled 2026-09-29: its audit script was deleted in Round 22 (D1/D3/D22). | — |
| WP50 | [Own minimap and map quality](../planning/work-package-scopes.md#wp50) | Delivered in Round 27 ([completion](../planning/round27-minimap-plan.md#completion-2026-09-30)): our own round minimap on the pre-generated map with quest-giver, service, home and party markers; native minimap off; `grug_map_quality` normal/high shared with the Map tab; readable relief; 512 px tiles. GUI-accepted with Round 27 (the user, 2026-10-05); carry-overs below. | WP40 ✅, WP24 ✅ |

## WP46 — Terrain-damage guard: explosions, fire and lava never damage settlements or POIs

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

## WP48 — Mapgen writer performance and parallel emerge

**Partial: Round 49 did the single-thread part** (2026-10-16,
[completion](../planning/round49-plan.md#completion-2026-10-16)), after the
user's live session of 2026-10-15 showed the one emerge thread about 87 %
busy in our mapgen Lua (it had been parked until a playtest showed slowness,
E8, user decision 2026-09-29). Performance numbers are comparisons, never
targets.

**What Round 49 did** ([before/after](../research/mapgen-chunk-profile-2026-10.md#round-49-beforeafter-lane-meas2)):
ores, gems and cave plants native in v7, the fill ores by a flat
integer-hash pass (P8 71–463 → ≤ 1 ms per chunk, 12 ms in a filled
surface chunk); no Lua for chunks below every writer (wholly underground
chunks 1.3–2.3 → about 40 chunks per second); a compilable R5 adapter and
zones lookup; an integer placement hash instead of SHA-256; P9G per column
and the mapgen column cache 3× (+30–40 MiB); the v7 flag `nomountains`
(`makeChunk` about 6–7 ms less). Surface chunks need about half the Lua
(A_S1 648 → 304 ms, A_S2 229 → 88 ms); the first start is ready at 66 s
instead of 79 s.

**What remains:**

1. **Several emerge threads** after Luanti #9357 (PR #16224 pending;
   [upstream workarounds §2](../technical/upstream-workarounds.md#2-more-than-one-emerge-thread-loses-ores-and-caves-at-chunk-edges)):
   with native ores the lost edge slices would now cost ores as well as
   caves, so `num_emerge_threads = 1` stays pinned until the engine fix.
2. **The cold planner** (R5, R6 columns and candidates) costs about 95 ms
   (93–102) on the first chunk with Lua work of every new column and is now
   the largest surface cost.
3. **The first-start pre-step:** before the first server step the world
   layouts take about 24 s, the world map base render 9.5 s and the mob
   spawn regions 8 s (single-threaded, a new world or a map reset only),
   about two thirds of the time to ready.

The rest of this section is the record.

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
recorded in [the R9-PERF completion record](../research/r9-perf-completion.md).
WP48 remains open: the engine threading block and broader changed-run
post-processing work are unchanged.

The v7 plateau (caves everywhere under the surface) is no longer a
performance question: Round 24 ruling 13 keeps caves out of the fill, and own
fill caves are only a possible later package (Round 22 D77(d)).

**Round 23 (2026-09-28)** (Phase 2 tree line: [receipt](../research/round23-tree-line.md)):
- Full-world preparation now covers the whole column players can trigger,
  from the neighbourhood's lowest bed minus reach up to above the flight
  ceiling.
- A writer fast path skips air chunks the writer provably cannot change.
- The Round 11 ecology main-environment `on_generated` is removed.
- Underground chunks remain the dominant Lua cost; they have no safe fast
  path yet.
- The engine threading block is unchanged. An own-engine patch was evaluated
  and deferred.
- [Receipt](../research/round23-full-column-preparation.md).

**Round 24 (2026-09-29):** output-identical P8 vein and layer-pass speedups
(218 of 218 chunks content-identical, about 20 % less Lua mapgen time), after
Lane B's ores and layers in the fill had cost mountain boxes about +20 %.
[Evidence](../../tools/r24_fill/evidence/b2.txt).

## WP49 — R7 source-audit refreeze on a fixed mapgen roster

**Canceled 2026-09-29** (C1). WP49 was to refreeze
`tools/wp40/r7/source_audit.sh` on a fixed mapgen roster (Round 9 ruling 43).
That script and the final micro were deleted in Round 22 (`66e3832e`, "retire
unused tools", D3/D22), and Round 22 D1 removed the PUC gate it served. The
frozen 157-file roster stays historical evidence only.

## Round 30 — performance

**Delivered 2026-10-02**
([completion](../planning/round30-plan.md#completion-2026-10-02)): every
item below shipped (#22, an investigation, as a proposal); the before/after numbers and the rulings made during
the round are in the completion section, open notes in
[Round 30 carry-overs](../planning/round30-plan.md#carry-overs). The record as planned, from
the read-only
[performance review](../research/perf-review-2026-10.md) (§5 lane
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
  ([Round 29 carry-overs](../planning/round29-plan.md#carry-overs)). This narrows the travel
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
[round31-dragon-arenas.md](../planning/round31-dragon-arenas.md)): the ice dragon (Wyrmglass) stands on a square, rather
plain terrace (the jungle dragon's arena is to be checked). The arena core
(32 nodes, `simple_map.lua` POI kind `dragon`, `arena_terrace`) is already
protected as a POI core (`grug_core.world_feature_at`; the dragon's own
breath patches are exempt), so terrain can shape the fight: lava pits,
spiked pillars, cover, height and similar hazards, per dragon. The islands
themselves stay untamed: no mapgen paths or roads by design (user
2026-10-02, `boats.md` §7.1).

## Round 31 — PvP, appearance and clean-up

**Delivered 2026-10-03**
([completion](../planning/round31-plan.md#completion-2026-10-03), plan
[round31-plan.md](../planning/round31-plan.md) with
[pvp-plan.md](../planning/pvp-plan.md)); every code lane independently
reviewed by Opus (the small follow-ups M2 and G2 checked by the coordinator),
the rules as built in [pvp.md](../design/pvp.md):

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

## Round 32 — fixes, preparation and research

**Delivered 2026-10-03**
([completion](../planning/round32-plan.md#completion-2026-10-03), plan
[round32-plan.md](../planning/round32-plan.md)); every code lane
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
  ([classes.md](../design/classes.md#left-click-and-held-input)).
- **Quest kill labels** (F2): the zone's mob name; `validate.py`
  `E-label-name` and `E-item-source-drop`.
- **Feed and quest window** (F3): combat notices and the personal notices
  in the message feed (only deaths, rare sightings, boss and dragon
  warnings and the one-time no-weapon hint stay in chat); the quest log in
  one text field with Track on HUD and Abandon in one row.
- **Performance** (F4, perf review R1–R3): the Map tab at most 2 builds and
  8 signature reads per 0.1 s pass, the party HUD in five slots, camps and
  leaders in 20 zone slices.
- **Studies:** [performance review](../research/perf-review-2026-10-r32.md),
  [sound research](../research/sound-research-2026-10.md),
  [items and professions analysis](../research/items-professions-analysis-2026-10.md).

## Round 33 — items, professions and achievements

**Delivered 2026-10-04**
([completion](../planning/round33-plan.md#completion-2026-10-04), plan
[round33-plan.md](../planning/round33-plan.md), numbers in
[item_tiers.md](../design/item_tiers.md)); every code lane independently
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

## Round 34 — sound

**Delivered 2026-10-04**
([completion](../planning/round34-plan.md#completion-2026-10-04), plan
[round34-plan.md](../planning/round34-plan.md), rules
[sound.md](../design/sound.md), credits [CREDITS.md](../../CREDITS.md)); every
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

## Round 35 — fixes and character creation

**Delivered 2026-10-05**
([completion](../planning/round35-plan.md#completion-2026-10-05), plan
[round35-plan.md](../planning/round35-plan.md)); every code lane
independently reviewed by Opus, the break sound on the approval list
(`tools/r35_f/approved.txt`), 84 fixtures pass, no mapgen change:

- **Aiming** (T): `grug_core.aim_raycast` tests `rotate = true` selection
  boxes in Lua for every server-side aiming ray (the engine misreads them
  since Luanti 5.12); zombie and crocodile probe misses 62 and 32 → 0;
  [upstream-workarounds.md](../technical/upstream-workarounds.md) with
  this entry and the emerge-thread pin.
- **Capital music** (M): music only in the six capitals, one rotation each
  (Master of the Feast in none), either music or the bed with a 3 s
  crossfade, 5 s pauses, the next track pushed ahead, 35 % by default
  ([sound.md](../design/sound.md)).
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
  review of all 64 talents ([skill_trees.md](../design/skill_trees.md)
  §2.10).

## Round 36 — the main questline

**Delivered and pushed 2026-10-05**
([completion](../planning/round36-plan.md#completion-2026-10-05), plan
[round36-plan.md](../planning/round36-plan.md), the
[story bible](../planning/round36/story-bible.md)); every code and data
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
  [completion](../planning/round36-plan.md#follow-up-lanes-2026-10-05-evening)):
  an LMB held across a hotbar switch decides again for the new skill after
  0.2 s and digging goes on across a switch; every bench keeps its back to
  the wall beside it; low ground cover in the protected band round start
  towns and capitals; road profiles with `C_STEP` 0.5 instead of 0.05, so
  no lone half-step bumps or holes.

## Round 37 — audit fixes

**Delivered 2026-10-06, pushed the same day** (`db848931`;
[completion](../planning/round37-plan.md#completion-2026-10-06), plan
[round37-plan.md](../planning/round37-plan.md), the
[audit](../audit-2026-10/README.md)); every code lane and every
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

## Round 38 — mob names

**Delivered and pushed 2026-10-06**
([completion](../planning/round38-mob-names-plan.md#completion-2026-10-06),
plan [round38-mob-names-plan.md](../planning/round38-mob-names-plan.md));
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

## Round 39 — web data for the realm website

**Delivered and pushed 2026-10-06**
([completion](../planning/round39-web-data-plan.md#completion-2026-10-06),
plan [round39-web-data-plan.md](../planning/round39-web-data-plan.md));
every lane independently reviewed by Opus; 112 fixtures pass, the
exporter's `--check`, `check_glb.py` and `build_glb.py --check` pass. No
gameplay change, no world generation changed.

- **Player meta** (WM): `grug_xp:level` and `grug_visuals:appearance`, the
  external contract in the
  [module guide](../technical/module-guide.md#player-meta-read-by-external-tools);
  on main from `03a76229`.
- **Export** (WE): `tools/web_data/web_data.json`, generated and checked by
  `tools/web_data/export.lua`.
- **Model** (WG): `tools/web_data/model/grug_visuals_character.glb`,
  animated stand and walk, tested against the `.b3d`; a GUI probe mod.

## Round 40 — combat feel

**Delivered and pushed 2026-10-06**
([completion](../planning/round40-plan.md#completion-2026-10-06),
plan [round40-plan.md](../planning/round40-plan.md)); every code lane
independently reviewed by Opus, the wave 1 pages' numbers too; 119
portable fixtures on main. No world generation changed.

- **Acceptance material** (V1–V4, R): the cooldown, animation and
  particle preview pages, the GUI probe `tools/r40_probe`, the accepted
  pose table `tools/r40_an` and particle catalogue `tools/r40_v3`,
  `character_anim` as a reference project.
- **Cooldown overlay** (CD): a cover and image digits on hotbar slots
  ([classes.md](../design/classes.md#the-cooldown-overlay)); the wear bar
  shows no cooldown or charge.
- **Poses and head look** (AN1, AN2):
  [character_visuals.md](../design/character_visuals.md#5c-poses-round-40)
  §5c and §5d.
- **Charge as a dash** (CH): the planned path, the hole rule, the hit on
  arrival ([classes.md](../design/classes.md#3-warrior-rage) §3).
- **Particles** (PX, PM): one helper, `grug_particle_scale`, the player
  skills ([combat_stats.md](../design/combat_stats.md#skill-particle-effects)),
  the bosses and mob specials ([biomes_mobs.md](../design/biomes_mobs.md)
  §3.1).

## Round 41 — playtest fixes, the production crash and the upgrade contract

**Delivered 2026-10-07, pushed 2026-10-08**
([completion](../planning/round41-plan.md#completion-2026-10-07),
plan [round41-plan.md](../planning/round41-plan.md)); every code lane
independently reviewed by Opus except the coordinator's one-line lane WW; 123 portable fixtures on main. Version
0.41.0, the first release in release mode: the production server moves to
it with a map reset (declaration `map_reset: ["0.40.1"]`).

- **Release mode and the upgrade contract** (UP): AGENTS.md "Release
  mode", [upgrade-contract.md](../technical/upgrade-contract.md),
  `tools/web_data/upgrade.json` with `tools/check_upgrade.py`, the map
  reset through `grug_reset_world`, unknown quest ids dropped.
- **The production crash** (CR): the writer reads the water barrier as
  air; a mapgen failure keeps the engine's terrain and is reported through
  `grug_core.severe` ([luanti-lua.md](../technical/luanti-lua.md)).
- **Playtest fixes:** the walk animation and kings and Generals at their
  seat (MOB, [world.md](../design/world.md), [pvp.md](../design/pvp.md)),
  stale world-map tiles (MAP, [world_map.md](../design/world_map.md#map-quality-and-relief)),
  the bow's missed release and the quiver total (SC,
  [classes.md](../design/classes.md#cancellation-and-native-client-limits)),
  the recipe book's Close and multi-item slots (UI; the books went in
  Round 45),
  the waterweed bed out of `group:sand` (WW).

## Round 42 — mob navigation

**Delivered 2026-10-08, playtest accepted the same day, pushed 2026-10-08**
([completion](../planning/round42-plan.md#completion-2026-10-08),
plan [round42-plan.md](../planning/round42-plan.md)); every lane
independently reviewed by Opus; 129 portable fixtures on main. Version
0.42.0, compatible. No world generation changed.

- **Test scene** (NV0): `tools/r42_nv0`, 15 scenes × 7 movers, the
  before-numbers and the calibration (rulings 18–20).
- **Navigation core and combat** (NV1): `mobs/grug_nav.lua`, the stuck
  detector, local search, path checks, smoothing and follower; the give-up
  in sight with the longer veto
  ([combat_stats.md §4](../design/combat_stats.md#4-threat-aggro-system)).
- **Fixed walks** (NV2): patrols, posts, seats, the royal follow, the
  evade, the rift boss and named rares ([world.md](../design/world.md)
  §4a).
- **Settlement walkers and the route cache** (NV3), **doors** (DR) and
  **no random stops on routes** (ST):
  [settlements.md](../design/settlements.md#settlement-walkers).
- **Cleanup** (CL): the unread stuck settings and the dead helpers.

## Round 43 — world migrations

**Delivered 2026-10-08, pushed 2026-10-09**
([completion](../planning/round43-plan.md#completion-2026-10-08),
plan [round43-plan.md](../planning/round43-plan.md)); every lane
independently reviewed by Opus; 130 portable fixtures on main. Version
0.43.0, compatible, with an empty `migrate` list: the foundation of the
platform's migration contract, shipped alone (ruling 2). No world
generation changed.

- **Game side** (GS): the world version record, the start guard,
  new-world recognition, the online-work runner and the schema-2
  declaration with `check_upgrade.py`
  ([upgrade contract §5](../technical/upgrade-contract.md#5-migrations)).
- **The migration tool** (MT): `tools/migrate.py` and `tools/migration/`
  ([tools/README.md](../../tools/README.md#the-migration-tool)).
- **Integration tests** (IT): `tools/r43_it/run.sh`, SQLite and PostgreSQL.
- **Open for a later step:** map blocks (format v29, both SQLite `blocks`
  layouts, the round-trip test) only when a step needs them (ruling 4);
  the first real step, 0.44.0, did without them (its station-grid gap is a
  [Round 44 carry-over](../planning/round44-plan.md#carry-overs)).

## Round 44 — inventory, map and quickbar

**Delivered 2026-10-09, pushed 2026-10-09 inside `2f918739`**
([completion](../planning/round44-plan.md#completion-2026-10-09),
plan [round44-plan.md](../planning/round44-plan.md)); every lane
independently reviewed by Opus; 138 portable fixtures on main. Version
0.44.0, **migrate**: the first declared step. Round A of the
[UI and crafting rework](../planning/ui-crafting-rework-plan.md). No
world generation changed.

- **Inventory logic** (IH) and **the window frame** (FR): the give helper,
  the fit check, bags in bags, the sort, the potion belt; the fixed tab
  order, the inventory views and the Inventory tab
  ([inventory_equipment.md](../design/inventory_equipment.md)).
- **Character** (CH), **Talents & Skills** (TS), **Party & PvP and Help**
  (PP): the mode and gear boxes with shift-click routing; the tree
  framework, the skill row and hotbar-only skills
  ([skill_trees.md](../design/skill_trees.md)); one Party & PvP page and
  the rewritten texts.
- **Map** (AR, MB, MQ): the user's art picks, the baked layer, the map
  window on Z with the quest log, quest targets and event-driven refresh,
  `grug_keys` ([world_map.md](../design/world_map.md)).
- **Quickbar** (QB) and **the step** (MS): `grug_quickbar` on E, mount
  items inert; step 0.44.0 and its test
  ([upgrade contract §5.8](../technical/upgrade-contract.md#58-the-declared-steps)).

## Round 45 — crafting rework

**Delivered 2026-10-09, pushed on the user's word after the round-end gates**
([completion](../planning/round45-plan.md#completion-2026-10-09),
plan [round45-plan.md](../planning/round45-plan.md)); every code lane
independently reviewed by Opus (PT1 and ART without a separate review);
152 portable fixtures on main. Version 0.45.0, **migrate**: the second
declared step. Round B of the
[UI and crafting rework](../planning/ui-crafting-rework-plan.md). No
world generation changed.

- **The item level ladder** (IL) and **enchants and upgrades** (EU):
  1/11/21/31/41/51, the requirement = the item level; the target slot,
  the filtered enchant list, +N upgrades to 10 × tier
  ([item_tiers.md](../design/item_tiers.md)).
- **Recipes, jobs and the Crafting tab** (RG, JB, UI, PT3): the registry,
  gear in its profession, the grid, books and discovery removed; timed
  jobs and the output area; the tab with areas, list, box and bar
  ([professions.md §1.2](../design/professions.md#12-recipe-areas-round-45),
  [inventory_equipment.md §4](../design/inventory_equipment.md#4-crafting-model-round-45)).
- **Stations, cooking, alchemy** (ST, PT8, ART): proximity stations,
  Cooking at join, finished potions, Grudge-Free Repairs, station sounds
  at a job's start, the new station looks and jewellery icons
  ([durability_repair.md](../design/durability_repair.md),
  [sound.md](../design/sound.md)).
- **Playtest fixes** (PT1, PT2, PT5, PT6, PT7, PT9): the boxed Inventory
  tab with the money row, one Character Stats mode, the shift-click inbox;
  mounts in first person, ride sounds, rider fall damage, liquids end a
  ride ([mounts.md](../design/mounts.md)); fliers, crabs, dawn; the
  Claim Stone as a waypoint ([home_travel.md](../design/home_travel.md)).
- **The step** (MS): 0.45.0 and its test
  ([upgrade contract §5.8](../technical/upgrade-contract.md#58-the-declared-steps)).

## Round 46 — world generation and player feedback

**Delivered 2026-10-13; pushed by the user with Round 47's main (`b3a30ab0`,
2026-10-14); never deployed on its own, production moves 0.45.1 → 0.47.0**
([completion](../planning/round46-plan.md#completion-2026-10-13), plan
[round46-plan.md](../planning/round46-plan.md)); every code lane
independently reviewed by Opus, the follow-up deltas XPC, XPC2, CKF and
LTF checked by the coordinator, ART picked by the user. Version 0.46.0, **map reset**: world generation changed; no
migration step.

- **Placement** (PL): villages, outposts, camps, mines, clash sites, rare
  dens and the PvP sites per seed
  ([world_zones.md §8.5](../design/world_zones.md#85-seed-dependent-poi-placement-round-46));
  quest-named region kinds always form a region
  ([spawn_regions.md](../design/spawn_regions.md#how-a-region-map-is-built)).
- **Resources** (OR): the §3 table of the plan, gems one and two tiers
  deeper ([items_crafting.md §3.0.1](../design/items_crafting.md#301-universal-materials-and-resource-taxonomy)).
- **XP and quests** (XP, XPC, XPC2): kill XP by level difference, gray at
  −7 and for every no-XP mob, the con gradient, gathering XP, the 55
  repeatables removed ([progression.md](../design/progression.md),
  [combat_stats.md](../design/combat_stats.md)).
- **Underground and the depth pulse** (UW, DP): spawns from y −1, light 7,
  sight 26, 4 % elites; WP34's pulse with the Riftwing
  ([biomes_mobs.md §4.1](../design/biomes_mobs.md#41-the-depth-pulse-decided-2026-08-08-built-round-46)).
- **Combat** (CB): rage by base swing interval, the caster spell base
  half from the weapon, caster talents on the spell base
  ([combat_stats.md](../design/combat_stats.md),
  [skill_trees.md](../design/skill_trees.md)).
- **Loot, cooking, crafting, repair** (LT, LTF, CK, CKF, ID, RP, ART):
  coin bags with the Auto box, cloth 1/1, spiders at 41–50; the plain
  role and six plain dishes; the ×N count by halving; the ingredient
  dropdown and one torch recipe; repair only in towns with the mender's
  icon ([economy.md](../design/economy.md),
  [items_crafting.md](../design/items_crafting.md),
  [durability_repair.md](../design/durability_repair.md)).
- **The waiting point** (WT)
  ([world_preparation.md](../design/world_preparation.md#the-waiting-point)).

## Round 47 — trees, mining progression and crafting feedback

**Delivered 2026-10-14; GUI-accepted together with 0.46.0 and pushed by
the user at `6a8afb9f` (2026-10-14)**
([completion](../planning/round47-plan.md#completion-2026-10-14), plan
[round47-plan.md](../planning/round47-plan.md)); every code lane
independently reviewed by Opus, every follow-up delta with game logic
reviewed again, ART on the user's picks. Version 0.47.0, **map reset**
plus the step 0.47.0 (stored tool capabilities rebuilt at join); the
production world moves from 0.45.1 in one update.

- **Trees** (TA, TB, TC, TD): the shape nodes, the generator in Lua, 32
  variants per species from the world seed, roots and saplings, town
  groves, town and capital greening
  ([handoff](../planning/tree-rework-handoff.md),
  [biomes_mobs.md §5](../design/biomes_mobs.md)).
- **The swamp** (SW, ART): the ground mix, pools that never flow, plants
  and swamp trees ([world_zones.md](../design/world_zones.md),
  `tools/r47_sw/DESIGN.md`).
- **Mining** (OR, AN): the lower-half rule, Iron behind Bronze, Anthracite,
  Steel from it, the Anthracite torch, the claim stone's time cap
  ([items_crafting.md](../design/items_crafting.md),
  [world_zones.md §11](../design/world_zones.md)); the step
  ([upgrade contract §5.8](../technical/upgrade-contract.md#58-the-declared-steps)).
- **Furnaces and crafting** (FS, CR): the furnace sound
  ([sound.md](../design/sound.md)); delivery with the overflow and the
  Basic unlock ([professions.md](../design/professions.md)).
- **NPCs, zones and the map** (NZ, ML): NPC facing
  ([settlements.md](../design/settlements.md)), zone discovery and the
  marker layers ([world_map.md](../design/world_map.md)).

## Round 48 — mail, plants and light, selling, smaller bags

**Delivered 2026-10-14; pushed (origin/main `f915d777`; 0.48.1 at
`1ef11b5e`); GUI test open** ([completion](../planning/round48-plan.md#completion-2026-10-14),
plan [round48-plan.md](../planning/round48-plan.md)); every code lane
independently reviewed by Opus, every fix delta with game logic reviewed
again, ARTP and ARTM on the user's picks, the letters and the quest text
by GPT-6 Astra with an Opus text review and the user's picks. Version
0.48.0, **map reset** (the mailboxes) plus the step 0.48.0 (bags at half
size, leftovers by mail); the production world moves from 0.45.1 in one
update.

- **Mail** (MAIL, WORLD, HUD, ADMIN, QUEST, ARTM): `grug_mail`, the
  mailbox on the twelve waystone pads, the unread icon, the privilege
  `mail_admin` and the Admin Mail tab, the system quest kind, the starter
  quest and the welcome and level letters ([mail.md](../design/mail.md),
  [mail plan](../planning/mail-plan.md)).
- **Plants** (FARM, ARTP): plant light, papyrus, cactus and saplings,
  Melon and Mushroom, spores, the Salt Pan, salt renewal, tooltips and the
  picked plant art ([farming.md](../design/farming.md),
  [plant growth plan](../planning/plant-growth-plan.md),
  [plant art plan](../planning/plant-art-plan.md)).
- **Selling, fuel, the daytime band and bags** (SELL, FARM, HUD, BAGS):
  [economy.md §2](../design/economy.md),
  [world_map.md](../design/world_map.md),
  [inventory_equipment.md §3](../design/inventory_equipment.md#3-bags-classic-mmo-model-lott-implementation-pattern),
  the step ([upgrade contract §5.8](../technical/upgrade-contract.md#58-the-declared-steps));
  [sell plan](../planning/sell-fuel-daytime-plan.md).

## Round 49 — mapgen performance (native first) and gameplay polish

**Delivered 2026-10-16; not pushed (pushed only on the user's word); GUI
test open** ([completion](../planning/round49-plan.md#completion-2026-10-16),
plan [round49-plan.md](../planning/round49-plan.md)); every code lane
independently reviewed by Opus, every fix delta with game logic reviewed
again, the measurement lanes checked by the coordinator. Version 0.49.0,
**map reset**, no migration step.

- **World generation** (ORE, PROT, SKIP, JIT, HASH, CACHE, V7, V7A, P8,
  MEAS, MEAS2): WP48's single-thread part, see
  [WP48](../../BACKLOG.md#wp48--mapgen-writer-performance-and-parallel-emerge)
  ([mapgen plan](../planning/mapgen-native-plan.md),
  [world_zones.md](../design/world_zones.md),
  [world_preparation.md](../design/world_preparation.md)).
- **Gameplay** (UI, INV, MOB, NAV, NAV2, VIS): postage at Send, Sell
  tooltips, the Claim Stone in any carried list, the Steward's button, the
  starter kit on the hotbar, kill XP and the rare tier, path repair,
  padding escalation and ranged mobs regaining sight, blocks at 70 % in the
  third-person hand, the half-buried onion
  ([gameplay draft](../planning/round49-gameplay-draft.md)).

## Round 51 — land zones and the sea

**Delivered 2026-10-19; pushed 2026-10-19 (`75ea1b4c`); GUI test open**
([completion](../planning/round51-plan.md#completion-2026-10-19),
plan [round51-plan.md](../planning/round51-plan.md), partial plans
[land](../planning/round51-land-plan.md) and
[sea](../planning/round51-sea-plan.md)); every code lane independently
reviewed by Opus, every fix delta with game logic reviewed again, the art,
design and page lanes checked by the coordinator and picked by the user.
Version 0.51.0, **map reset**, no migration step.

- **The sea** (T1, T2, T3, MAP, WRECK): the larger world, bays without
  specks, the 250–350-node coastal belt, organic dragon channels, protected
  water 24+ off the coast, the water query, seabed growth, the sea by depth
  on the map, shipwrecks ([world_zones.md §7.4](../design/world_zones.md#74-water-coast-and-islands),
  [world_map.md](../design/world_map.md#map-quality-and-relief)).
- **Water creatures** (NAMES, MOBS): five families by water band, the
  swimmer reset, fish loot, quest-ready zone slots
  ([biomes_mobs.md](../design/biomes_mobs.md#round-51-water-families)).
- **The land zones** (VIEW, ARTL, LG, LP, LK, T4): calm 2 × 2 grounds, the
  swamp moss, clay bands, ice and pebble patches, new plants with regrowth,
  the kit (ruins, graveyards, cairns, statues, logs, varied bones,
  driftwood), the towns' graves ([biomes_mobs.md §2.1](../design/biomes_mobs.md#21-wp40-surface-and-deterministic-decoration-projection)).

## Round 52 — ambience and the class rework foundation

**Delivered 2026-10-20; pushed (`67941764`, 0.52.1 `e4d5c9d5`); the GUI
test of 0.52.0 passed on 2026-10-20** ([completion](../planning/round52-plan.md#completion-2026-10-20),
plan [round52-plan.md](../planning/round52-plan.md), partial plans
[ambience](../planning/round52-ambience-plan.md) and
[class foundation](../planning/round52-class-plan.md)); every code lane
independently reviewed by Opus, the sounds, the art and the particle cards
picked by the user. Version 0.52.0, **compatible**, no migration step.

- **Ambience** (SND, AMB): beds by biome group, three layers (surface,
  cave, wind) by the height relative to the terrain or the water surface,
  real caves told from dug tunnels, the atmosphere's underground band
  relative to the terrain, animal calls by sound key, `/ambience debug`;
  23 new cuts, six beds dropped ([sound.md §4](../design/sound.md#4-ambience-beds-grug_ambience),
  [module guide](../technical/module-guide.md#sound)).
- **Class rework, round F** (SPLIT, CORE-A, CORE-B, GRAPH, WFX, ARTA,
  ARTB, PFX): per-class kit and talent files, the action clock, the
  transformation field, the readiness windows, the area helpers and the
  group helper, Mend on the status system, the graph talents as an admin
  preview, the scrolling skill row, the weapon overlay, the art and the
  particle design ([module guide](../technical/module-guide.md#combat-and-classes),
  [skill_trees.md §3.12](../design/skill_trees.md#312-the-graph-talents-of-round-k-round-52-live-since-round-53)).
  The audit's CMB-13 (Mend's shared tick phase) is fixed.

## Round 53 — the new classes

**Delivered 2026-10-20; not pushed (pushed only on the user's word); GUI
test open** ([completion](../planning/round53-plan.md#completion-2026-10-20),
plan [round53-plan.md](../planning/round53-plan.md)); every code lane
independently reviewed by Opus, the cast sounds picked by the user. Version
0.53.0, **migrate**, one step 0.53.0. Round K of the
[class rework](../planning/class-redesign/delivery-plan.md):

- **The talents** (LIVE): the graph talents live, one data file per class,
  `<tree>_<name>` ids, the Talents page ([skill_trees.md](../design/skill_trees.md)).
- **The kits** (MAGE, WARRIOR, PRIEST, SCOUT): two or three starters per
  class, the rest from the trees; the Scout's bow draw removed
  ([classes.md](../design/classes.md), [scout.md](../design/scout.md),
  [ability_targeting.md](../design/ability_targeting.md)).
- **The seams and the content** (HOOKS, SKS): family keys, the swing
  callback, clock seams, the held fallback, cones; 25 icons, 41 effects,
  20 sound events ([module guide](../technical/module-guide.md#combat-and-classes)).
- **The step and the clean-up** (INTEG): the step 0.53.0, HP factors, the
  old talent engine removed, `opts.no_crit`, the held cast's catch-up.
- **0.53.1, the fix round** (compatible, no step of its own;
  [fix plan and completion](../planning/round53-fix-plan.md#completion-2026-10-20)):
  areas, cones and group heals without line of sight; "Range: N m" in the
  tooltips; the 40-node flight band and the minimap's no-fly overlay on a
  flyer; shield and spellbook tooltips from the equip rule; the same
  trinket twice; the undead truce day and night (husks too), Elf +3 m,
  Dwarf +5 % armor rating; skeleton bows; right-click picking; the 36
  redrawn icons. Lanes ART, FLIGHT, SKILLS, GEAR and RACE, each reviewed
  independently. Built, not pushed; pushed together with 0.53.0 after the
  user's one GUI test.

## Round 54 — the armor redesign in the game

**Delivered 2026-10-21; not pushed (pushed only on the user's word, after
the GUI test of 0.53.1 and 0.54.0); GUI test open**
([completion](../planning/round54-plan.md#completion-2026-10-21), plan
[round54-plan.md](../planning/round54-plan.md), background
[armor redesign plan](../planning/armor-redesign-plan.md)); every code
lane independently reviewed by Opus, the art picked by the user. Version
0.54.0, **compatible**, no step:

- **The contract** (CONTRACT): the box catalog, the atlas, the render/check
  tool and the [armor format](../technical/armor-format.md)
  (`tools/r54_armor/`).
- **The model** (MODEL): 28 armour boxes, the swing panels and the weapon
  card in the player model, the NPC model.
- **The art** (ART, BAKE, INTEG): GPT-6 Astra's three drops, the user's
  picks, `bake.py`, the old armour media removed.
- **The game** (GAME, VIEW): composition and apply, the royal armour,
  appearance version 2, Hardened, the Character tab with the held weapon
  ([character_visuals.md §3](../design/character_visuals.md#3-visible-armor)).
- **The web** (WEB): the four-primitive `.glb`, version 1 appearances, the
  kaesual handoff.

## UI modernization carry-overs

**Noted 2026-10-25** (0.60.1, [UI plan](../planning/ui-modernization-plan.md)),
the three reviews' notes (theoretical or accepted, no severity). The
GUI points are items 67–81 of the
[GUI checklist](../planning/round60-plan.md#gui-checklist-rounds-57-58-59-60-61-62-the-ui-and-0611).

- **Vendored rename:** `minetest.` became `core.` throughout
  `mods/BASE/default/nodes.lua`, `default/craftitems.lua` and
  `creative/inventory.lua`; with it undone only the marked sign, book and
  creative layouts differ, but it bloats every future upstream diff. The
  creative trash listring warning comment was lost on the way (the ring
  order is still safe); restore it with the rename's revert.
- **Media licence:** `grug_core/LICENSE-media.md` covers the 18
  `grug_ui_*.png` in one paragraph; give each file its own row like the
  other sections.
- **Formspec version:** `grug_core/ui.lua`'s prepend styles
  `button:focused`, a formspec version 7 state, inside version 6 forms; it
  works on the pinned engine.
- **Map payload:** the map window's added tab bar (about 1.2 KB per send,
  estimated) is unmeasured.
- **Zone labels at 1× in small windows** overlap densely (73 overlapping
  pairs at 1035 × 696, 10 over baked region names; 3 pairs at 1920 × 1080);
  the corrected reference geometry does not make them collision-free at
  every client size (GUI checklist item 75 decides).
- **Text scale:** `grug_core.ui.text_scale` uses the one-row header height
  (`grug_inventory.UI.window_h`); with more tab rows (admins, or four tabs
  per row at GUI above 1.2 on windows under 1500 px) the form is up to
  about 7 % taller and its text about 7 % less compensated. Very small
  windows at GUI 1 (for example 800 × 600) are not compensated (the floor
  is 1), as before.
- **Theme bytes:** `tools/ui_theme/build.py --check` compares exact PNG
  bytes, which depend on the Pillow and zlib versions (Pillow 12.3.0
  today); a Pillow update may need a regeneration without a visual change.

## UI dialogs carry-overs

**Noted 2026-10-25** (0.61.1, [dialog review](../planning/ui-dialog-review.md)),
the implementer's stated limits and the two reviews' notes (accepted or for
the user to judge, no severity). The implementer's two visual correction
passes are used up, so any further fit work is a new lane. The GUI points
are items 97–106 of the
[GUI checklist](../planning/round60-plan.md#gui-checklist-rounds-57-58-59-60-61-62-the-ui-and-0611).

- **GUI scale 1.5 in small windows** (1035 × 696): the mail tabs, Admin
  Mail's preview labels and the mailbox footer labels clip or overlap, the
  welcome window needs more scrolling and some crafting buttons are tight
  (items 100, 101 and 105 decide).
- **WQHD font size:** at 2560 × 1440 and GUI scale 1 the client keeps its
  pixel font size while the panels grow, so text looks small next to them;
  no global font scaling was added (item 104 decides).
- **Zone labels at 1×:** the 1× text is now 0.65 of the font and choosing
  Zones from an overview enters 2×, but a manually chosen 1× overview stays
  dense. The startup diagnostic at seed 12345 (estimated label boxes)
  reports 0 overlapping pairs and 2 over a region name at 1920 × 1080, 9
  and 3 at 1035 × 696; the 0.60.1 figures above predate the half-width map
  (item 103 decides).
- **Map figures:** `docs/design/world_map.md` no longer records the map's
  size and layout per window size for the half-width layout (dropped in
  `a849d18f`, only the Round 47 figures remain as history); measure them
  again with `tools/r44_mq` when the map is next touched.
- **Web build unchecked:** the implementer captured the desktop client only
  (item 106).
- **Vendor thumb on short shelves:** the thumb shows the visible share of
  the list, so on the General shelf (14 offers) it fills 20/21 of the track
  and is barely draggable; accurate, the mouse wheel scrolls.
- **`grug_core.ui.prose`** restores `border=true` and the caller's textarea
  font scale (default 1) after its text; a new caller whose form styles
  textareas differently must pass its scale (only Mail does today, 0.85).
- **Fixture sweeps:** five CLI fixtures keep their existing
  `check_lua.sh` sweep-5 findings (`io.popen` in `r27_quest_item_names` and
  `r57_qsys/quest_test.lua`, `os.exit` in `r29_b` and `r451_nq`, both in
  `r35_f`); the dialog lane changed only their rendering assertions.

## Decided for later rounds (Round 56 §8)

**Decided with the user on 2026-10-22**, each its own round in an order the
user sets; the decisions and their detail are in
[Round 56 plan §8](../planning/round56-plan.md#8-decided-for-later-rounds).

- **Crafting window:** **delivered in Round 57** (0.57.0): layout C, the
  queue of five, the details pages, recursive Basic unlocks, favourites and
  the chain-depth report.
- **Town fixes** (**map reset**): **delivered in Round 58** (0.58.0, lane
  TOWNFIX; the royal-guard posts in all six capitals). In the templates (the user in the editor or
  a lane): Lethariel's bough platforms (the beam over the stair and the deck
  rail go) and the five core gatehouses (an inner stair, the doors one node
  towards the passage, a 4-node deck opening, the first-floor openings
  closed); in code: Lethariel's royal guards on posts by the king, the gate
  guards' two patrols and the tower post, the terrace stair's off-by-one in
  `dressing.terrace`, the waystone and mailbox at each start town's centre.
  Candidates: NPCs using doors more visibly, the town workshop evening.
- **Mining camps** (**map reset**): 20 camps (one per T2, T3 and T4 zone
  outside the capital zones), a faction-only teleport lift to a protected
  room written by the world generator at the tier's lowest y + 50 (−250,
  −450, −650), a fetch quest, faction guards; the T4 room may lie in the PvP
  depth.
- **Quest rework** (after QUESTMAP and QUESTIDEAS): the foundation and the
  six start zones are **delivered in Round 57** (shared quests, story
  marking, choice rewards, no repeatables, quest families across the start
  towns, rewards that are not the requested items); the story thread from
  the capital on and the levels 11–60 follow from Round 59 (below).

## Decided for Round 58 and later (Round 57 plan §8–§9)

**Decided with the user on 2026-10-23**, replacing the mining-camp entry
above; the detail is in [Round 57 plan §8](../planning/round57-plan.md#8-decided-for-round-58).

- **Round 58, the Miner's Guild** (**map reset**, together with the town
  fixes above): **delivered in Round 58** (0.58.0,
  [completion](../planning/round58-plan.md#completion-2026-10-24)):
  - one guild per faction, a political actor, with a guild building in every
    capital: **The Charter of Stone** (The Accord) and **The Oathdelvers**
    (The Throng), the user's names of 2026-10-23;
  - 20 new camps (T2–T4) plus the 16 Battlegrounds war camps as mining camps,
    and one "camp under construction" of the enemy in each own contested T4
    zone (guards only, no lift);
  - a faction-only teleport lift to a protected room at every tier depth
    down to the camp's tier (148 rooms), guarded against water and lava;
  - guild quests bound to the depth (one id per tier for both factions, at
    own camps only), 1–2 kill quests per camp, everything at once, no T1
    quest, no repeatables;
  - reputation with a lifetime rank (0–10) and a spendable balance, an
    achievement with three cloaks (ranks 3, 6, 10);
  - a camp vendor who buys, repairs, trades materials for reputation and
    sells only the 12 consumables (Ore Sense and Treasure Hunt, T1–T6; rank
    gates buying, level gates use, own effect slot, one active at a time,
    the effect lasts across logout and death); materials are also traded for
    reputation at the guild in the capitals;
  - the art is picked (GUILDART, 2026-10-23: the cloaks, the 12 consumable
    icons, two status icons and the Miner's Remains block) and waits in the
    orchestration folder for this round's code.
- **Round 59 and later:** the story arc and the quest rework of levels
  11–60, zone by zone with the rework flag (Round 59 delivered the band
  11–20 and chapter 1, 0.59.0,
  [completion](../planning/round59-plan.md#completion-2026-10-24);
  Round 60 the band 21–30, the six capitals and chapter 2, 0.60.0,
  [completion](../planning/round60-plan.md#completion-2026-10-24);
  Round 61 the band 31–40 and chapter 3, 0.61.0,
  [completion](../planning/round61-plan.md#completion-2026-10-25);
  Round 62 the front 41–60 and the main line's story layer, 0.62.0, the
  last quest round,
  [completion](../planning/round62-plan.md#completion-2026-10-25)); the arc follows the user's picks
  on the Round 57 draft ([completion](../planning/round57-plan.md#decisions-during-the-round):
  the guilds and their faction's military closely interwoven with little
  conflict inside a faction, a traitor or a wrong decision as the author
  chooses, the enemy guild rather impersonal);
  then unique items (quest rewards, boss loot tables for instances, world
  finds) and the armor redesign with several polygon groups per slot.

## Audit 2026-10 open questions

**Open, for the user** (collected 2026-10-05 from the
[October 2026 audit](../audit-2026-10/README.md)'s "Open questions for
Jan" and its "Jan decides" findings that the
[Round 37 plan](../planning/round37-plan.md) §2 did not decide). None
blocks a fix; until a ruling the docs describe the code as it is (plan
§2.4). One line each, details in the linked audit document.

- **DW-04** — the ambient War Construct sub-types (`causeway_construct`,
  `siege_war_construct`) are in no recipe: add them to their two zones'
  recipes or drop them and their docs? ([world docs](../audit-2026-10/docs/03-design-world.md))
- **DW-08** — V1's "scorched breaches, twisted vegetation" and "Nether
  corruption" do not exist (V1 has the rift): keep as a V1 wish, move to
  V2 or drop? ([world docs](../audit-2026-10/docs/03-design-world.md))
- **DW-26** — the proposed "Rift-Touched" state in `TODO-design-nether.md`
  collides with V1's rift and Rift Spawn. ([world docs](../audit-2026-10/docs/03-design-world.md))
- **DW-40** — "never overlaid": `grug_core.surface_mob_level_at` returns the
  region overlay, only `grug_zones.*` is the pure field; which does the
  rule mean? ([world docs](../audit-2026-10/docs/03-design-world.md))
- **DI-14** — spellbooks need Journeyman mastery (level 16+) at every tier
  (the T5 32-slot bags Master, level 46+), so the T1 spellbook is out of
  reach in the T1 band (levels 1–10) and counts only from level 16 for a
  Tailor still at profession tier 1: keep the gate? **Decided 2026-10-08,
  done in Round 45:** the mastery bands go (round45-plan ruling 7).
  ([item docs](../audit-2026-10/docs/05-design-items.md))
- **DI-17** — station recipes belong to one profession each, so only the
  Weaponsmith crafts a Forge: may the Armorsmith craft one too?
  ([item docs](../audit-2026-10/docs/05-design-items.md))
- **DI-27** — cultivated Ember Moss (seed recipe, crop) is not
  Alchemy-gated, only the wild source is: intended? ([item docs](../audit-2026-10/docs/05-design-items.md))
- **D3 / mastery bands** — the mastery bands (character level 16 / 31 /
  46, bags and spellbooks only) beside the six profession tiers: keep them
  or make them profession tiers? **Decided 2026-10-08, done in Round 45:**
  removed; the profession tier equals the item tier for everything. (from the archived
  [findings](maintenance/findings.md); [item docs](../audit-2026-10/docs/05-design-items.md))
- **DI-10** — is a "found gear versus crafted demand" audit still wanted
  after WP5, or does the sentence go? ([item docs](../audit-2026-10/docs/05-design-items.md))
- **DP-06** — the Priest talents' "Word" names (Sharpened Word, Swift Word,
  Word of Ruin, Last Word): keep or rename? ([player docs](../audit-2026-10/docs/04-design-player.md))
- **DP-08** — `/xp` can no longer lower a level: keep the level-drop talent
  reset for API callers or remove it? ([player docs](../audit-2026-10/docs/04-design-player.md))
- **DP-10** — Warrior shield abilities were deferred "after WP14", which is
  delivered: post-V1 or a BACKLOG entry? ([player docs](../audit-2026-10/docs/04-design-player.md))
- **DP-12** — the Scout's HP factor is an implicit 1.00 (`stats.lua`
  fallback): confirm 1.00 as decided? ([player docs](../audit-2026-10/docs/04-design-player.md))
- **DP-18** — "Last Word" is both an achievement and the Priest capstone:
  keep the shared name? ([player docs](../audit-2026-10/docs/04-design-player.md))
- **CMB-10** — a relog resets every ability cooldown and refills mana,
  while talent and trinket cooldowns persist: should long cooldowns and
  mana survive a relog? ([combat code](../audit-2026-10/code/07-combat-progression.md))
- **Blink into claims** — Blink and Charge ignore housing claims and
  protected POI interiors (only walls stop them): refuse them there?
  ([combat code](../audit-2026-10/code/07-combat-progression.md))
- **Rift void and shields** — the rift void's damage is soaked by absorb
  shields, unlike lava and drowning: intended? ([core code](../audit-2026-10/code/06-core-hud-ambience.md))
- **CORE-03** — switching off the atmosphere (a graphics fallback) also
  mutes the ambience beds: keep the beds then? ([core code](../audit-2026-10/code/06-core-hud-ambience.md))
- **ITM-16 / fuels** — furnaces burn only coal, charcoal, Anthracite (Round
  47), logs and, since Round 48, cactus (15 s) and leaves (2 s), the
  brewing stand the engine fuels (planks yes, charcoal no): intended? The
  brewing stand takes no fuel since Round 45 (no automatic brewing); the
  furnace half stays open.
  ([item code](../audit-2026-10/code/09-items.md))
- **Fishing rod** — all other gear breaks and is repaired, the rod breaks
  and disappears: intended? ([item code](../audit-2026-10/code/09-items.md))
- **MGS-08 / water in POIs** — planned and bucket water may flow into
  village, camp and POI cores and onto roads (only towns and capitals are
  guarded): keep until WP46 or extend the water guard? ([settlement
  code](../audit-2026-10/code/02-mapgen-settlements.md))
- **MGT-14** — will the WP40 evidence and capture modes run again, or may
  they go from `r6_settlement.lua`, `r6.lua` and `r7_runtime.lua`?
  ([terrain code](../audit-2026-10/code/01-mapgen-terrain.md))
- **W13-04** — should the Round 14, 20 and 31 POIs use the race palette (a
  visible change) or keep their own material tables? ([wp13 code](../audit-2026-10/code/03-mapgen-wp13.md))
- **W13-09** — delete the dead pre-planner generators (`wall_tower`,
  `stilt_platform`, `water_channel`, `fish_landing` …) or keep them as a
  parts shelf? ([wp13 code](../audit-2026-10/code/03-mapgen-wp13.md))
- **W13-03** — one small fixture for the `parts.lua` registry mirror tables
  against `tools/wp13/stub_registry.lua`? ([wp13 code](../audit-2026-10/code/03-mapgen-wp13.md))
- **X-08** — may the fixed SHA-256 and population pins in
  `grug_gathering` and `grug_farming` go, now that fixtures guard the
  content? ([cross-cutting code](../audit-2026-10/code/10-cross-cutting.md))
- **CTX-14** — the per-package calibration records of
  `agent-model-policy.md` §7: still wanted? **Decided 2026-10-06:**
  dropped (`700dd5f6`). ([agent context](../audit-2026-10/docs/02-agent-context.md))
- **CTX-26** — where do the decided Nether rules of `TODO-design-nether.md`
  live (a TODO holds only open questions)? ([agent context](../audit-2026-10/docs/02-agent-context.md))
- **RDM-08** — name the six peoples in the README under their generic
  names now, or wait for flavour names? **Decided 2026-10-06, done in
  Round 37 D:** named as the game shows them (Human, Dwarf, Elf; Orc,
  Troll, Undead). ([README](../audit-2026-10/docs/01-readme-player.md))
- **README and PvP NPCs** — should the README say that Kings, Generals and
  guards attack enemy players regardless of the flag? **Done in Round 37
  D:** one sentence in the PvP bullet (as `pvp.md` §4 and the faction veto
  in `grug_mobs/init.lua`). ([README](../audit-2026-10/docs/01-readme-player.md))
- **D18, swimmer exhaustion** (deferred ocean survival) — what, if anything,
  does "Exhausted" do to an unmounted swimmer? Today the ocean's deterrents
  are the Kraken, immutable deep-ocean terrain and the boat-threat rules
  ([boats.md](../design/boats.md)); flyers use their warning band and
  no-flight columns ([mounts.md](../design/mounts.md)), and no swimmer
  mechanic is authorized. Moved from the dissolved
  `TODO-design-crafting-rework.md` in Round 37 (DI-12). ([item docs](../audit-2026-10/docs/05-design-items.md))

## Audit 2026-10 later fix packages

**Not in Round 37** ([plan](../planning/round37-plan.md)); details in the
[code audit summary](../audit-2026-10/code/00-summary.md#proposed-fix-packages).

- **MGT-03 trees at chunk borders** (the user, 2026-10-05: later, plan
  §2.2.3): owner-only writes drop every tree that crosses a chunk border,
  so treeless bands run along chunk borders and at y ≡ 15..50 mod 80;
  accepted by the R6 contract, the fix is size L
  ([terrain code](../audit-2026-10/code/01-mapgen-terrain.md)).
- **P6 beyond MGT-02** (mapgen performance and memory): MGS-01/W13-01
  emerge memory (about 7–10 % of the emerge high-water mark; is server
  memory a concern, or does it wait for WP48?), W13-02 the composition
  rebuild on every boot, MGT-04/MGT-05 surface-only passes, MGS-03 the
  per-chunk palette rebuild ([summary](../audit-2026-10/code/00-summary.md#proposed-fix-packages)).
- **P8 structure and legacy:** the wp13/wp40 merge (W13-05; open: is a
  directory rename worth the churn?), mobs_redo as an owned fork (X-06,
  MOB-08; open: may it be declared one?), the `mod.conf` coupling (X-07),
  the tooltip writers (ITM-04) and the other duplications
  ([summary](../audit-2026-10/code/00-summary.md#proposed-fix-packages)).

## Character creation in one window (user, 2026-10-05; delivered in Round 35)

**Done:** delivered in Round 35 lane C
([completion](../planning/round35-plan.md#completion-2026-10-05)); the
rules are [world.md](../design/world.md) §7 and
[character_visuals.md](../design/character_visuals.md) §1.1. The request
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

## Money withdraw and deposit: Bag of Coins (user, 2026-10-04; done in Round 34 F2)

**Done:** delivered in Round 34 lane F2 (`grug_money/coins.lua`); the rules
are [economy.md](../design/economy.md) §1 (withdraw on the Character page,
the deposit slot, no vendor price, no transfer log, the engine's item
lifetime). A deliberate design change: players can give money to each other
for the first time (a high-level character can fund an alt; acceptable
without a market).

## Sound (V1; user, 2026-10-03; delivered in Round 34)

**Done:** Round 34
([completion](../planning/round34-plan.md#completion-2026-10-04)) built
V1's sound after the user's seven decisions (round34-plan.md §2.1: CC0
sources first with CC BY where clearly better; neutral cues per NPC role;
music pools by region group; the picked tracks; music pushed on demand,
on by default; quiet beds per region; no weather in V1) and the user's
picks on the listening pages. Rules: [sound.md](../design/sound.md);
credits: [CREDITS.md](../../CREDITS.md). The ambience pilot (human beds only) was
extended to every zone in the same round, so no zone waits for a bed.
Every new or changed sound goes through a listening page (sound.md §1).

## Weather (optional; user, 2026-10-04)

Not V1 (round34-plan.md §2.1 ruling 7): no weather system exists; distant
thunder plays as a rare ambience call on the dragon islands without one. An
optional later package: a small weather system with its own sky, particles
within the web budget (hundreds, never thousands) and a rain bed, which
would also be the place for the rain recordings the user turned down as bed
backgrounds. Not planned yet.

## Items and professions design session (user, 2026-10-03)

**Done:** held with the user 2026-10-03/04; its rulings are
[round33-plan.md](../planning/round33-plan.md) §2 and became Round 33
([completion](../planning/round33-plan.md#completion-2026-10-04)). Kept
for its record:

The [items and professions analysis](../research/items-professions-analysis-2026-10.md)
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

## Seed-dependent POI placement (user, 2026-10-03; delivered in Round 46)

**Done:** delivered in Round 46 lane PL
([completion](../planning/round46-plan.md#completion-2026-10-13)); the
rules are [world_zones.md §8.5](../design/world_zones.md#85-seed-dependent-poi-placement-round-46).
Villages, outposts, bandit and Mirefolk camps, mines, clash sites (but the
four rift sites), rare dens, the two PvP fortresses and the sixteen war
camps are placed per seed by rules for each kind, once per world, on the
natural terrain before core fitting and road routing, identical in the main
and emerge environments and stored in the world-layout cache; start towns,
capitals, dragon arenas, apex mines and the rift sites stay fixed. Seed
8507030740356938342 loads. The request (set aside 2026-10-03 and 2026-10-04
in favour of the seed fleet, taken up again on 2026-10-09) also asked that
a POI's level band fits the level field where it lands, which the rules
keep. A catalog row may declare an underground reservation; quest-bearing
POIs with an underground part are later content.

## Enchantment and item-level revision (user, 2026-10-03; a later round)

**Done in Round 33** (lanes DS and C4): enchant values grow continuously
with item level up to their tier's cap, bosses drop item level 65/70 with
T7 enchants, the crown adds five more levels and one tier
([item_tiers.md](../design/item_tiers.md) §1, §4). The note below is the
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
- Round 32's [analysis](../research/items-professions-analysis-2026-10.md)
  measures the gap (§2.2, §2.3: attack speed +4–14 % per enchant against
  strength about 2.6 % and crit at most 1.2 %) as its option 2; the
  [design session](#items-and-professions-design-session-user-2026-10-03)
  decides.

## First-public-release gates

**Open; owner: the project coordinator preparing the first public release.**
Trigger: freeze the intended release candidate, before asking the user to approve
that release. These obligations remain visible after WP40 development completion
by explicit user decision on 2026-09-13; they are not passed or waived gates.
Rewritten 2026-09-29 after the WP audit (E9, E10).

Gates:

- Freeze game/engine/settings identity and choose the intended public seed.
  Since Round 22 D24 the coast and borders vary per seed, so the seed is a
  free choice.
- Complete the AI-generated media gate for `menu/icon.png`: set ContentDB's
  **AI-generated media flag**, credit OpenAI's built-in image generation,
  retain Jan Hangebrauck as art director and rights holder, keep the source
  render and derivatives under CC0 1.0, and retain the source/prompt/export
  record linked from `menu/LICENSE-media.md` (updated 2026-11-10).

Release checks with judgement, not gates (E10: sometimes thorough, never a
rigid rule that forces hour-long tests):

- Start, generate and restart the candidate on the native engine, as deep as
  the changes since the last playtest warrant; there is no mandatory native
  smoke with runtime/RSS evidence.
- The PUC Lua 5.1 (fallback-engine) run is **optional** (E9): at most one
  crash smoke test once the mapgen is finished (Round 22 D1).
- One spot check of resource supply and regional access on a few seeds (rough
  ~5 % parity target, `world_zones.md` §11; Round 22 D21).

Evidence boundary: [R8](../research/wp40-simple-map-r8-contract.md) and
[WP40 completion](../research/wp40-completion.md) are historical owner texts,
superseded for these checks by Round 22 D1/D5 and the decisions above. This is
a development-WP completion, not a public release. Fresh-server mode ended
with 0.41.0 (the user's announcement, 2026-10-07; release mode in AGENTS.md).
Plain Lua 5.1 compatibility of the code
stays a hard rule throughout development; only PUC runtime testing is
optional.

## Historical receipts and unresolved carry-overs

The [pre-consolidation backlog](planning/backlog-before-consolidation.md)
retains original completion records, review calibration, runtime observations,
old acceptance descriptions and carry-overs. Its obsolete migration, radial-map,
soft-lock, ballistic and refinement instructions do not govern new work.

Do not silently discard a historical carry-over merely because its parent WP is
marked delivered. Reconcile it against current design and the domain findings;
if still open, retain an owner here. The current documentation round records its
coverage and remaining uncertainties rather than declaring every old claim verified.

For execution use the [round workflow](../process/round-workflow.md), current topic rules
and a refreshed bounded task brief. Historical research briefs are starting
material, not permission to restore superseded requirements.
