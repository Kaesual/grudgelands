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
  zone is contested. At y = −701 and below, every non-ocean land column is
  contested independently of its surface zone.
- **PvP uses one exact transaction.** A safe player who initiates a valid
  hostile action becomes tagged before resolution; safe→safe is blocked,
  safe→tagged may land, tagged→safe is blocked and tagged→tagged may land.
  Effective PvP damage or support refreshes the 60-second tail, contested
  ground forces the tag, reconnect preserves it and death clears it. Melee,
  casts, AoE, projectiles and support all use the same seam.
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
  Deep ocean is deadly through the Kraken Guard, which never breaks off a
  pursuit while it stands in open water and leashes normally everywhere else.
- **Two equivalent apex destinations.** The Wyrmglass Crown and Stormscale
  Summit are contested offshore dragon islands, each with a dragon lair and an
  apex camp, reached by boat. Minerals never regrow anywhere, camps included.
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
  connect every start and every capital of a faction (Round 29). Since Round 25 the player's own Claim Stone can
  replace the innkeeper as travel-home target; respawn stays at the
  innkeeper. Universal riding unlocks at
  levels 15/30/45/60 with land speeds 6.4/8 and flight speeds 8/12 nodes per
  second; damage dismounts. Battlegrounds permit flight, enemy territory allows
  land mounts only, and every exterior-ocean column forbids flight. Boats are
  water mounts (Round 29): the Shipwright in every capital sells the Boat
  from level 15 and the twice-as-fast Improved Boat from level 30, and any
  damage ejects a rider from a boat exactly as it dismounts one from a
  mount.
- **Story remains light and environmental.** The Accord–Throng war is old; an
  ancient demonic threat reaches upward through the Nether. Both factions face
  it in parallel without becoming allies.

**Scope versus delivery:** this vision includes approved future systems, not just
running code. WP41's exact PvP transaction and the WP9 story from level 41
remain unfinished; WP17 boats/waypoints and the WP44 economy are delivered
(Round 29) and await the playtest. [BACKLOG](BACKLOG.md) distinguishes them.

## V1 scope

The original V1 baseline (2026-09-18) is Rounds 1–9, open-world Housing,
mounts, the release gates and polish; the approved later rounds extend it. The
user's 2026-09-29 decisions
([WP audit](docs/planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
B1–B7) settle the rest:

- **In V1:** WP17 boats (the only access to the dragon islands and their
  camps) and waypoints at every start and capital (no zone hubs, no
  `/unstuck`); WP41 geographic PvP; WP9's story levels 41–60 and the finale.
- **After V1:** WP42's scripted NPC battles on the war front. Small PvP POIs
  (forts and camps with NPCs) may come in V1, and WP42 may ship before WP41.
- **Not V1:** the walkable Nether, the first expansion (V2).

## Phase 1 — Playable core and world foundation

### Delivered foundation

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
  The WP44 economy is delivered in Round 29; broader item/loot scope remains separate.
- [x] Quest framework; Round 20 extends the catalog to 240 quests and all 100 anchor art slots,
  persistent same-faction parties and optional HUDs. Since Round 28 quests are
  per-zone data with area, item-group and quest-drop objectives and repeatables;
  Round 29 replaces the catalog with 491 quests up to the front at 60.
- [x] World atlas with zoom/scroll, self/party/quest/service markers and, since
  Round 27, our own round minimap with the same markers; innkeeper home
  return and respawn; riding/flight (WP31) and farming (WP32, GUI acceptance
  pending). No fog-of-war or waypoint prerequisite.
- [x] Surface-following optional full-world preparation, resumable bounded scheduling
  and shared creation/reconnect waiting flow.
- [x] **WP24 Housing** (Round 25): Claim Stones, claim protection and
  permissions, the stone as travel home, and road and POI protection.
  Playtest under way: [completion](docs/planning/round25-housing-plan.md#completion-2026-09-29).
- [x] **Round 26** ([completion](docs/planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29)):
  Claim Stone draft and activation with the Housing Steward, the registration
  cleanup (WP28), the status icons and organic capitals with a character per
  capital. Next: fresh world and playtest.
- [x] **WP50 own minimap and map quality** (Round 27,
  [completion](docs/planning/round27-minimap-plan.md#completion-2026-09-30)):
  a round, north-up minimap drawn from the world map with quest-giver,
  service, home and party markers in place of the native one; the
  `grug_map_quality` setting (normal/high); readable relief. Next: short
  playtest.
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
  Battlegrounds 50 % wider with a middle road). Local, not pushed. Next:
  fresh world and GUI test.
- [x] **WP17 travel (V1)**, Round 29: boats as water mounts from the
  Shipwright in every capital, the Kraken retune, and visit-unlocked
  waystones at every start and capital. Innkeeper return and the Claim Stone
  travel home were already delivered.
- [x] **WP44 economy, a lighter pass**, Round 29: one price module for every
  payout, 5% buy-back on vendor goods, the vendor rule, the audit fixes,
  quest copper from weight and mount, boat and respec prices from a simple
  income estimate. It absorbed the price remainders of WP7, WP11, WP22, WP30
  and WP31.

### Remaining work

- [ ] **Round 30 performance** (next): the
  [performance review](docs/research/perf-review-2026-10.md)'s lanes P1–P4
  with the user's rulings of 2026-10-02 (quest state and map UI, mob pathing
  and allocation, the region-map file cache and boot memory, per-player
  ticks; fewer spawn ABMs). Items:
  [BACKLOG](BACKLOG.md#round-30--performance).
- [ ] **WP41 (V1):** exact geographic PvP transaction and shared eligibility seam.
- [ ] **WP9 (V1):** the level-41–60 main questline and the finale. Round 29's
  front quests and bounties carry the 41–60 leveling; the main storyline and
  the finale are reassessed on top of them.
- [ ] **WP5 / WP10 items and professions:** cultural/PvP finishes, masterwork
  (an item-level-70 upgrade), then cultural finishing and helper services.
  Selected enchanting, ordinary gear, found-item loot, loot by band, seven
  self-contained profession catalogs and the loot/demand audit (Round 29's
  price calibration) already exist.
- [ ] **WP13:** a separate walk of the Round 20 POI art (its GUI acceptance).
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

- [ ] Paladin, Rogue, Warlock and Shaman. Scout already owns the delivered bow
  and melee class paths; its stealth remains deferred.
- [ ] Further coastal-shelf life and shore wildlife inside the editable shelf,
  without redefining deep ocean or dragon channels. Shallow coral/kelp and
  fishing already shipped in bounded rounds; missing roster/media remains future.
- [ ] **V2's main content update: the walkable Nether**, with its own mapgen,
  story line and mob cast. The Fire Dragon and the Nether reserve from the mob
  plan remain reserve content for that update.
- [ ] WP42 bounded war-front encounters (scripted NPC battles, after V1).
- [ ] Dungeons, regional apex encounters, reputation and player trading.

## Phase 3 — Polish

- [ ] Original textures, sounds and animated models with complete provenance.
- [ ] Localization through Luanti's translation system; German first.
- [ ] Balance, accessibility, onboarding and a measured 100-player
  performance pass.

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
