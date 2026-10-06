# Roadmap — Grudgelands

Goals and remaining milestones, not a chronological implementation diary.
Current delivery: [project status](docs/STATUS.md). Exact work-package scope and
status: [BACKLOG](BACKLOG.md). Rules and numbers: [design index](docs/design/README.md).
Earlier delivery narratives are preserved in the
[historical roadmap](docs/archive/planning/roadmap-before-consolidation.md).

## Vision

- **Two distinct faction continents.** The Accord holds southern Elandor and
  the Throng northern Kragmar. Their independently authored three-lobed
  silhouettes meet along the continuous four-zone Battlegrounds; ocean
  separates the rest of the coast. The stable 38-zone map fixes names, hubs,
  level ranges, race regions, PvP rules, biome palettes and POI budgets;
  neighbors follow the natural zone borders, and seeds vary local terrain.
- **Six races, six starts, six capitals and six kings.** Each race begins in
  its own outer level-1–10 settlement and later reaches a central gated
  capital. Capitals are peaceful civic hubs with level-60 guards and no
  ambient hostile mobs. Kings and royal guards are killable high-end
  combatants; essential service NPCs are separate and invulnerable.
- **Progression moves toward conflict.** All level-1–30 surface zones are
  peaceful. Every ordinary level-31–60 frontier, Battlegrounds or dragon-island
  zone is contested. At y = −501 and below, every non-ocean land column is
  contested independently of its surface zone.
- **PvP is a simple per-player flag** (delivered in Round 31,
  [pvp.md](docs/design/pvp.md)). Two enemy players can harm each other only
  while both are flagged. Contested ground and enemy territory flag by
  location, a button and PvP contact flag for 60 s, only own peaceful land
  clears the flag and death clears it; no attack or heal ever changes it.
  Support is one-way, PvP combat lasts 10 s and a logout in PvP combat is
  death. PvE combat does not notice PvP. Each faction holds a fortress at
  the front, and 16 Battlegrounds war camps are the targets of PvP quests
  (players are never quest targets).
- **Controlled destructibility keeps the world playable.** Peaceful home
  terrain is editable by its faction; peaceful enemy land is not. Ordinary
  contested land, including the Battlegrounds at every depth, is editable by
  both sides. Deep ocean and full dragon channels are immutable. Roads with
  their bridges and the building cores of POIs, villages and camps are
  protected for everyone (Round 25); the rest of village/outpost/camp shells
  and battlefield dressing stays mutable. Only
  bounded functional anchors and complete civic cores — capitals and starting
  settlements with their bare protected bands (Round 22 D76/D78) — are
  hard-protected, fail-closed
  against indirect mutation.
- **The ocean has authored classes.** Planned mainland water stays part of its
  named zone. An editable 80-node coastal shelf follows the analytic outer
  perimeter; immutable deep ocean begins beyond it. Two immutable channels
  separate the offshore level-60 dragon islands and keep them boat-only.
  Deep ocean is deadly through the Kraken, which never breaks off a
  pursuit while it stands in open water and leashes normally everywhere else.
- **Two equivalent apex destinations.** The Wyrmglass Crown and Stormscale
  Summit are contested offshore dragon islands, each with a dragon lair and an
  apex camp, reached by boat. Each dragon fights in a round arena whose edge
  is its leash, with hazards of its own (Round 31). Each boat landing has a small beach and a wooden
  pier (Round 30); beyond them the islands stay untamed, without paths or
  roads, so the climb is part of reaching the dragon. Minerals never regrow
  anywhere, camps included.
- **Housing lives in the open world** (delivered in Round 25,
  [housing.md](docs/design/housing.md)). From level 20 each player gets one
  free, soulbound Claim Stone from a capital's Housing Steward. It claims a
  101 × 101 column from y = −100 up in the player's own level-11–30 home
  zones, protects it while coal or charcoal burns, grants Interact or
  Everything to named players and can be the travel-home target. There are
  no tiers, and private housing islands do not exist.
- **One six-tier material spine serves every race.** Bronze, Iron, Steel,
  Silversteel, Embersteel and Abyssal Steel picks dig the six tier rocks:
  stone down to −100, then ever harder rock below −100/−300/−500/−700/−1000
  (Round 24). Every ore and gem needs the pick of the layer where it first
  appears, at any depth; a weaker pick cannot dig it at all. Loose ground
  needs no tool, and decorative rocks do not drive access.
- **Regional materials add identity without blocking universal progression.**
  Each race region selects one cultural material and one signature wood;
  foreign cultural resources come through contested/deep routes and trade,
  never through a mandatory faction monopoly. Gems are not regional (Round
  29): one gem per tier rock — Citrine, Jade, Garnet, Sapphire, Ruby,
  Diamond — found everywhere at its depth; Quartz is universal.
- **The economy stays ledger-only.** Copper/silver/gold are one integer;
  physical Gold is a separate crafting material. The target Common weapon
  axis is 25c/65c/1s60c/4s/10s/25s and vendor buy-back is ceiling-rounded 5%.
  A simple estimate of reliable net solo income after ordinary costs
  calibrates mount, boat and respec prices (Round 29); the Claim Stone is
  free.
- **Combat supports solo play and the tank/healer/damage trinity.** Threat,
  taunt and healing threat make group roles matter, but content is sized for
  two or three players and remains beatable without a healer. Level 60 takes
  roughly 10–20 played hours; endgame PvP, bosses, crafting and housing are
  the destination.
- **Travel has separate systems.** Delivered innkeeper home return binds one of
  twelve faction-compatible homes, returns instantly outside combat on a personal
  30-minute cooldown and owns death respawn. Visit-unlocked waystones
  connect every start, every capital and the PvP fortress of a faction
  (Rounds 29 and 31). Since Round 25 the player's own Claim Stone can
  replace the innkeeper as travel-home target; respawn stays at the
  innkeeper. Universal riding unlocks at
  levels 15/30/45/60 with land speeds 6.4/8 and flight speeds 8/12 nodes per
  second; damage dismounts. Battlegrounds permit flight, enemy territory allows
  land mounts only, and every exterior-ocean column forbids flight. Boats are
  water mounts (Round 29): the Shipwright in every capital sells the Boat
  from level 15 and the twice-as-fast Improved Boat from level 30, and any
  damage ejects a rider from a boat exactly as it dismounts one from a
  mount. There are no docks; a boat lands anywhere in water, and only the
  four island landings have piers (Round 30).
- **Story remains light and environmental.** The Accord–Throng war is old; an
  ancient demonic threat reaches upward through the Nether. Both factions face
  it in parallel without becoming allies. Since Round 36 each faction's main
  line from level 41 follows that threat's branded pay across the front to a
  shared finale at the rift, whose last line points below
  ([story.md](docs/design/story.md)).

**Scope versus delivery:** this vision includes approved future systems, not just
running code. The WP9 story from level 41 with its finale is delivered in
Round 36 (GUI test open); V1's sound is
delivered in Round 34 (tested by the user; Round 35 made music a capital
feature); the items
and professions revision (WP5, WP10) is delivered in Round 33; WP41 PvP and
the PvP POIs of WP42 are delivered (Round 31, GUI-accepted), WP17
boats/waypoints and the WP44 economy too (Round 29, tested by the user). [BACKLOG](BACKLOG.md) distinguishes them.

## V1 scope

The original V1 baseline (2026-09-18) is Rounds 1–9, open-world Housing,
mounts, the release gates and polish; the approved later rounds extend it. The
user's 2026-09-29 decisions
([WP audit](docs/planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
B1–B7) settle the rest:

- **In V1:** WP17 boats (the only access to the dragon islands and their
  camps) and waypoints at every start, capital and PvP fortress (no zone hubs, no
  `/unstuck`); WP41 geographic PvP; WP9's story levels 41–60 and the finale;
  **sound** (the user, 2026-10-03): effects for the game's events, mob
  voices, ambience and calm background music without a combat switch
  (delivered in Round 34, [sound.md](docs/design/sound.md); since Round 35
  music plays only in the six capitals).
- **After V1:** WP42's scripted NPC battles on the war front. The small PvP
  POIs shipped in V1 (Round 31).
- **Not V1:** the walkable Nether, the first expansion (V2).

## Phase 1 — Playable core and world foundation

### Delivered foundation

Rounds 25–35 count as GUI-accepted (the user, 2026-10-05); Rounds 36 and 37
are open ([project status](docs/STATUS.md)).

- [x] Standalone game, faction/race/class creation, progression and four classes
  including Scout; current-ray combat, equipped weapons, talents and shared movement.
- [x] Named-zone world foundation, six starts and capitals, gathering/materials,
  strata and bounded terrain/coast/cave corrections. Round 21 improves access,
  natural POI ground, inland/coastal detail and resource density. Round 24 adds
  tier-rock mining, ores and layers in the underground fill and start-zone mob
  gradients. Public-release evidence remains open.
- [x] Threat/taunt, populations, kings/dragons, homing ranged attacks, dispositions,
  nametags and injured bars. The dragon encounters are delivered (WP23 closed
  2026-09-29); boats reach their islands since Round 29 (WP17).
- [x] Currency/traders, inventory/bags, Skills recovery, ordinary equipment/offhands,
  fixed-tier enchanting, wear/repair, profession workspaces, food, farming and fishing.
  The WP44 economy is delivered in Round 29; the items and professions revision
  (WP5, WP10) in Round 33.
- [x] Quest framework; Round 20 extends the catalog to 240 quests and all 100 anchor art slots,
  persistent same-faction parties and optional HUDs. Since Round 28 quests are
  per-zone data with area, item-group and quest-drop objectives and repeatables;
  Round 29 replaces the catalog with 491 quests up to the front at 60;
  Round 31 adds 24 PvP fortress quests with garrison objectives.
- [x] World atlas with zoom/scroll, self/party/quest/service markers and, since
  Round 27, our own round minimap with the same markers; innkeeper home
  return and respawn; riding/flight (WP31) and farming (WP32). No
  fog-of-war or waypoint prerequisite.
- [x] Surface-following optional full-world preparation, resumable bounded scheduling
  and shared creation/reconnect waiting flow.
- [x] **WP24 Housing** (Round 25): Claim Stones, claim protection and
  permissions, the stone as travel home, and road and POI protection.
  GUI-accepted: [completion](docs/planning/round25-housing-plan.md#completion-2026-09-29).
- [x] **Round 26** ([completion](docs/planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29)):
  Claim Stone draft and activation with the Housing Steward, the registration
  cleanup (WP28), the status icons and organic capitals with a character per
  capital. GUI-accepted.
- [x] **WP50 own minimap and map quality** (Round 27,
  [completion](docs/planning/round27-minimap-plan.md#completion-2026-09-30)):
  a round, north-up minimap drawn from the world map with quest-giver,
  service, home and party markers in place of the native one; the
  `grug_map_quality` setting (normal/high); readable relief. GUI-accepted.
- [x] **Round 28 questing and leveling framework**
  ([completion](docs/planning/round28-questing-leveling-plan.md#completion-2026-10-02)):
  the 2026-09-30 playtest fixes (mob behaviour near roads, environmental
  damage, knockback, sizes, LMB lock, message feed, class offhands, Scout
  slots and quiver, Professions tab); data-driven sub-types and loot by band,
  the kill-equivalent XP curve, quests as per-zone data, self-contained
  professions; the catalogue (195 sub-types, 119 items, 89 icons) with the
  naming rule; rule-based spawn regions for all 38 zones
  ([spawn_regions.md](docs/design/spawn_regions.md)); The Broken Causeway
  41–50 and Gravesalt/Skyglass 51–60; quest-log level ranges and zone
  names. Complete and pushed 2026-10-02; the spawn playtest (2026-10-02)
  fed Round 29.
- [x] **Round 29 "Economy and travel"**
  ([completion](docs/planning/round29-plan.md#completion-2026-10-02)):
  491 quests on the Round 28 framework replace the 240 legacy quests (one
  track per race, the contested 31–40 zones, the 41–60 front with
  repeatable and island bounties); the spawn playtest fixes; a mapgen bundle
  (gems by depth, `apex_sockets` removed, mapgen band data, the
  Battlegrounds 50 % wider with a middle road). Pushed and tested by the
  user on a fresh world (2026-10-02).
- [x] **WP17 travel (V1)**, Round 29: boats as water mounts from the
  Shipwright in every capital, the Kraken retune, and visit-unlocked
  waystones at every start and capital. Innkeeper return and the Claim Stone
  travel home were already delivered.
- [x] **WP44 economy, a lighter pass**, Round 29: one price module for every
  payout, 5% buy-back on vendor goods, the vendor rule, the audit fixes,
  quest copper from weight and mount, boat and respec prices from a simple
  income estimate. It absorbed the price remainders of WP7, WP11, WP22, WP30
  and WP31.
- [x] **Round 30 "Performance and clean-up"**
  ([completion](docs/planning/round30-plan.md#completion-2026-10-02)): the
  [performance review](docs/research/perf-review-2026-10.md)'s lanes P1–P4
  with the user's rulings — a quest-state cache and the Map tab at most every
  2 s, the region-map file cache (a later start about 7 s instead of about
  16 s) and lower boot memory, a per-step A* budget and mobs that give up
  unreachable targets, three merged spawn ABMs instead of 88, cheaper
  crafting lookups, crosshair and name tags; Return home on the Character
  page; piers and beaches at the dragon-island landings; the legacy quest
  fields removed and the Dawnmere NPC duplication fixed; band-4/5 loot
  smoothing with recomputed prices. Pushed 2026-10-03; GUI-accepted.
- [x] **Round 31 "PvP, appearance and clean-up"**
  ([completion](docs/planning/round31-plan.md#completion-2026-10-03)):
  **WP41 geographic PvP** (the per-player flag, the PvP tab, icons, banner
  and target frame, the NPC faction filter for services and map markers,
  PvP from depth tier T4); **WP42's PvP-POI part** (a fortress per faction
  with a General, a waystone and quests, 16 Battlegrounds war camps with
  named captains, 24 fortress quests from level 40); the **appearance
  package** (character looks chosen at creation, NPC look rolls, helmet
  face window, equal hitboxes, enchant colours on gear); the **dragon
  arenas** redesigned (round leash arenas, ice and ember hazards, the
  dragon's wrath); the Round 30 clean-up items and a fixture runner. Pushed
  2026-10-03; GUI-accepted.
- [x] **Round 32 "Fixes, preparation and research"**
  ([completion](docs/planning/round32-plan.md#completion-2026-10-03)): the
  minimap zoomed ×2, hostile camps marked on the Map tab, zone names
  coloured by the territory at the player's position with a territory line;
  one LMB hold state machine (mining turns into combat when a hostile comes
  into the crosshair, and back); quest kill labels with the zone's mob
  names; combat and personal notices in the message feed, the quest log in
  one text field; three performance fixes for many players (Map tab
  rebuild budget, party HUD slots, camp and leader slices). Read-only
  studies: a [performance review](docs/research/perf-review-2026-10-r32.md)
  at 50 and 100 stand-ins, the [sound research](docs/research/sound-research-2026-10.md),
  the [items and professions analysis](docs/research/items-professions-analysis-2026-10.md).
  Pushed 2026-10-04; GUI-accepted.
- [x] **Round 33 "Items, professions and achievements"**
  ([completion](docs/planning/round33-plan.md#completion-2026-10-04)), the
  items design session's rulings (**WP5 and WP10 delivered**): gear drops by
  quality with more from elites and named mobs and two blue or gold items
  from every boss, bags as world drops, a level requirement on all gear;
  enchant values that grow with item level up to their tier and show it,
  profession upgrades, the crown (a Fallen Crown lifts an item beyond its
  tier), two professions per class; Alchemy beside Cooking, progress only
  from real recipes, the cultural finishes and other dead ends removed;
  crit ×2, T1-only vendor gear, dearer repair, fixed potions, a Crownbinder
  and a Decor Merchant in every capital; per-character achievements that
  unlock cosmetic cloaks ([item_tiers.md](docs/design/item_tiers.md)).
  Pushed 2026-10-04; the user's findings fed Round 34.
- [x] **Round 34 "Sound"**
  ([completion](docs/planning/round34-plan.md#completion-2026-10-04)), V1's
  sound ([sound.md](docs/design/sound.md), [credits](CREDITS.md)): every
  file picked by the user on a listening page; effects at the game's events
  with many left silent by choice, hits by weapon kind, ability cues, mob
  voices in 22 families, dragon and King cues; quiet ambience beds per
  region, night, cave, deep and sea, thunder on the dragon islands, loops at
  forges, hearths and flowing water; four music pools pushed to a player
  only while music is on (replaced by capital rotations in Round 35), a
  main-menu theme, volume and off switches per player. Two fix lanes from
  the Round 33 test: mobs follow through water in combat; text boxes,
  cooking costs, the Bag of Coins, service map markers, the damage fit, no
  gear from encounter adds, thin ice breaking behind a runner. Pushed
  2026-10-05; the user's GUI test fed Round 35.
- [x] **Round 35 "Fixes and character creation"**
  ([completion](docs/planning/round35-plan.md#completion-2026-10-05)), the
  user's Round 34 GUI findings: the server's aiming rays test rotated
  selection boxes in Lua (an engine bug since Luanti 5.12), recorded in the
  new [upstream-workaround list](docs/technical/upstream-workarounds.md);
  music only in the six capitals with a rotation each, either music or the
  ambience bed, 35 % by default; a break sound and a clearer broken look,
  the bare hand for a skill without a weapon, dig sounds for ores and sand,
  flint removed, quest lists coloured by status with read-only text;
  character creation in one window with nothing stored before "Create
  character"; night mobs leave at dawn, a drop audit against the income
  targets; level-proof talents and the user's picks from a review of all
  64. Pushed 2026-10-05; the user's first GUI findings fed Round 36.
- [x] **Round 36 "The main questline" (WP9)**
  ([completion](docs/planning/round36-plan.md#completion-2026-10-05)), V1's
  last missing content: each faction's main line from its fortress
  Warmaster in three chapters (41, 46, 53) and a party finale at 60 on the
  approved [story bible](docs/planning/round36/story-bible.md), with the
  front climaxes folded in, a solo step behind enemy lines, the "use at a
  place" objective with quest objects, ten corrupted sub-types, a turn-in
  hook and three achievements with cloaks; the rift at Tombroad Ambush with
  its void crack and Isquarre the Tithe-Eater, war commanders in two enemy
  camps; WP13's POI review on a render page and a decor pass over every POI,
  start town and capital house; fixes from the Round 35 GUI test (one target
  predicate, free mobs evading only from outside their wander radius, talent
  points in the level-up banner); Priest heals with gear Intelligence and
  the Scout's damage set; the dragons' wider hazards and wing gust; after
  the user's first look a held button across a hotbar switch, benches with
  their back to the wall, ground cover in the protected band round towns
  and smoother roads. Pushed 2026-10-05; needs a world made on `fef94a6a`
  or later. Next: the GUI test on desktop and in the web build, two clients
  for the rift (still open).
- [x] **Round 37 "Audit fixes"**
  ([completion](docs/planning/round37-plan.md#completion-2026-10-06)), the
  [October 2026 audit](docs/audit-2026-10/README.md)'s fix round: combat
  without the per-hit equipment fan-out, mounts and shields that survive an
  expiring buff, one knockback rule; mobs that retarget only through
  threat, show their swing and freeze their wind-up; named rares and
  dragons that never stand twice, a restart that keeps the world's mobs,
  capped Bone Call, returning royal guards, straight side shots; the
  right-click, crop, furnace, ground-growth and water-guard fixes; the
  minimap and quest markers only on change; the mapgen without its dead
  halo and a seed fleet over real chunks; the picked dragon and Rift
  Spawn sounds; after the user's rulings start zones that fight alone,
  the Salt Reef Lurker and a minimap always at normal quality; a player
  README with a changelog and version 0.37.0, and the agent and design
  documents set to one owner per fact. Pushed 2026-10-06; no new world
  needed beyond Round 36's. Next: the GUI test, together with Round 36's.
- [x] **Round 38 "Mob names"**
  ([completion](docs/planning/round38-mob-names-plan.md#completion-2026-10-06)):
  short names with the zone's feel instead of signal words for every mob
  slot, picked by the user on a preview page (536 of 950 slots renamed,
  rules for words, signal words, Piglet and level stretches checked by
  `check_rules.py --shipped`); a mob's name is the exact answer to which
  mobs a quest means — a kill counts by the shown name, which fixes the
  quest kill-credit bug the user met; quest texts on the new names, the
  dragon whelps at level 60, the Kraken, twelve shorter item names and
  Party instead of Group. Complete and pushed on 2026-10-06; a
  fresh world for the test. Next: the GUI test, together with Rounds 36
  and 37.
- [x] **Round 39 "Web data for the realm website"**
  ([completion](docs/planning/round39-web-data-plan.md#completion-2026-10-06)),
  for websites that host managed realms, with no gameplay change: each
  character's level and appearance (slot items, the composed textures) in
  player meta as a documented external contract, an exported
  `tools/web_data/web_data.json` with the ids, names, frames, wield
  geometry, texture files and items a website needs, and the player model
  as an animated glTF tested against the game's `.b3d`. Complete and
  pushed on 2026-10-06. Next: the GUI test, together with Rounds 36
  to 38.

### Remaining work

- [ ] **Seed-dependent POI placement** (optional, set aside 2026-10-03):
  whether POIs, camps, outposts, mines and the PvP fortresses are placed per
  world instead of at fixed positions
  ([BACKLOG](BACKLOG.md#seed-dependent-poi-placement-user-2026-10-03-optional-set-aside)).
- [x] **WP9 (V1):** the level-41–60 main questline and the finale,
  delivered in Round 36 on top of Round 29's front quests and bounties.
- Round 34's late fix: the ~1 % seed load failure is fixed (F3, rivers never
  cover a POI core; a seed fleet guards world-generation changes). Round 33's to 36's other
  open notes (sound balance, the music tab study, the main line's ledger
  and decor notes, the main-menu background) are in the
  [Round 33](BACKLOG.md#round-33-carry-overs),
  [Round 34](BACKLOG.md#round-34-carry-overs),
  [Round 35](BACKLOG.md#round-35-carry-overs),
  [Round 36](BACKLOG.md#round-36-carry-overs),
  [Round 37](BACKLOG.md#round-37-carry-overs),
  [Round 38](BACKLOG.md#round-38-carry-overs) and
  [Round 39](BACKLOG.md#round-39-carry-overs) carry-overs; Round 36 settled
  Priest healing, the Scout's set and spell rounding. The audit's design
  questions and later fix packages:
  [open questions](BACKLOG.md#audit-2026-10-open-questions),
  [later packages](BACKLOG.md#audit-2026-10-later-fix-packages).
- [x] **WP13:** the POI review (audit E2) done in Round 36 as a render page
  with the user's verdicts instead of a walk, and the decor pass it asked
  for; the reworked places are in the Round 36 GUI checklist.
- [ ] **WP34 depth pulse** (kept, for later): placement and the deep servant
  roster stay open in TODO-design-depth.md. Renewable camp resources are
  removed; the T6 lava lakes stay planned.
- [ ] **WP46 / WP48:** the fire/explosion guard is deferred until a fire or explosion source exists (expected with V2's Nether)
  (nothing damages terrain today); writer performance is parked until a playtest shows
  slowness.
- Closed on 2026-09-29: WP11, WP14, WP21, WP22, WP23, WP27, WP29, WP30, WP31,
  WP32 (delivered or merged), WP37 and WP49 (canceled). Held-torch moving light,
  natural out-of-combat regeneration, rested XP, renewable ores, the dragon
  hoard chest and `/unstuck` are removed from the design. Friendly-guard
  healing stays deferred.

### Before the first public release

Rewritten 2026-09-29 (audit E9, E10). Gates: freeze game/engine/settings and
the public seed; complete the media publication attribution/flag obligations.
Checks with judgement, not gates: a native start/generation/restart of the
candidate as deep as its changes warrant, an optional PUC Lua 5.1 crash smoke
test, and a resource spot check on a few seeds. Exact wording and ownership:
[BACKLOG release gates](BACKLOG.md#first-public-release-gates).
Historical evidence does not certify later code. Only the user's announcement
ends fresh-server development mode.

## Phase 2 — Expansion

- [ ] Further classes, names open. Scout already owns the delivered bow and
  melee class paths; its stealth remains deferred.
- [ ] Further coastal-shelf life and shore wildlife inside the editable shelf,
  without redefining deep ocean or dragon channels. Shallow coral/kelp and
  fishing already shipped in bounded rounds; missing roster/media remains future.
- [ ] **V2's main content update: the walkable Nether**, with its own mapgen,
  story line and mob cast. The Fire Dragon and the Nether reserve from the mob
  plan remain reserve content for that update.
- [ ] WP42 bounded war-front encounters (scripted NPC battles, after V1).
- [ ] Dungeons, regional apex encounters, reputation and player trading.

## Phase 3 — Polish

- [ ] Original textures, sounds and animated models with complete provenance
  (V1's sound pass, Round 34, uses licence-clean sources first).
- [ ] Optional: a small weather system (sky, particles within the web
  budget, a rain bed); not V1 (Round 34 ruling 7,
  [BACKLOG](BACKLOG.md#weather-optional-user-2026-10-04)).
- [ ] Localization through Luanti's translation system; German first.
- [ ] Balance, accessibility, onboarding and a 100-player performance pass
  with real clients (Round 32 measured 50 and 100 stand-ins).

## Deliberately outside the target

- Private housing islands, purchased mining-depth rights and private material
  sources.
- A social-organization system, shared organization bank/chat or
  organization-owned land.
- Instanced PvP battlegrounds/arenas and permanent war-front capture in the
  current scope.
- A separate Enchanter profession; each profession enchants the families it
  owns.
- Taming mounts; riding is a permanent purchase and summons an ephemeral
  owner-bound entity.
