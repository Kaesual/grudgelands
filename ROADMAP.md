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
  separates the rest of the coast. The stable 38-zone graph fixes names,
  neighbors, level ranges, race regions, PvP rules, biome palettes and POI
  budgets while seeds vary bounded borders and local terrain.
- **Six races, six starts, six capitals and six kings.** Each race begins in
  its own outer level-1–10 settlement and later reaches a central four-road
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
  both sides. Deep ocean and full dragon channels are immutable. Roads,
  village/outpost/camp
  shells and battlefield dressing are mutable but claim-excluded; only
  bounded functional anchors, complete civic cores — capitals and starting
  settlements with their 10-node aprons — and irreplaceable route pieces are
  hard-protected, fail-closed against indirect mutation.
- **The ocean has authored classes.** Planned mainland water stays part of its
  named zone. An editable 80-node coastal shelf follows the analytic outer
  perimeter; immutable deep ocean begins beyond it. Two immutable channels
  separate the offshore level-60 dragon islands and keep them boat-only.
  Deep ocean is deadly through the Kraken Guard, which never breaks off a
  pursuit while it stands in open water and leashes normally everywhere else.
- **Two equivalent apex destinations.** The Wyrmglass Crown and Stormscale
  Summit are contested offshore dragon islands. Each reserves an all-six-gem
  apex camp with exactly twelve protected renewable sockets: two each of
  Citrine, Garnet, Jade, Diamond, Sapphire and Ruby.
- **Housing lives in the open world.** Exactly ten peaceful level-11–30 home
  zones accept Claim Stones. Four stone tiers protect radii 20/30/40/50 while
  every placement immediately reserves its future 101×101 footprint. Stable
  ids survive recovery, dormancy, decay and reissue; a claim-bound Home Stone
  has no capital fallback. Private housing islands do not exist.
- **One six-tier material spine serves every race.** Bronze, Iron, Steel,
  Silversteel, Embersteel and Abyssal Steel open exact natural depths of
  −100/−300/−500/−700/−1000/map floor. Resource harvest tier is a
  separate check: a pick can reach a node yet destroy it without a drop when
  under-tier. Cosmetic strata no longer drive access.
- **Regional materials add identity without blocking universal progression.**
  Quartz is universal; Citrine/Garnet/Jade are G1 and
  Diamond/Sapphire/Ruby G2. Each race region selects one G1, one G2, one
  cultural material and one signature wood. Foreign G2 and cultural resources
  come through contested/deep routes, both apex camps and trade, never through
  a mandatory faction monopoly.
- **The economy stays ledger-only.** Copper/silver/gold are one integer;
  physical Gold is a separate crafting material. The target Common weapon
  axis is 25c/65c/1s60c/4s/10s/25s and vendor buy-back is ceiling-rounded 5%.
  An Income Ledger measures reliable net solo income after ordinary costs and
  calibrates Claim Stone and mount prices.
- **Combat supports solo play and the tank/healer/damage trinity.** Threat,
  taunt and healing threat make group roles matter, but content is sized for
  two or three players and remains beatable without a healer. Level 60 takes
  roughly 10–20 played hours; endgame PvP, bosses, crafting and housing are
  the destination.
- **Travel has separate systems.** Delivered innkeeper home return binds one of
  twelve faction-compatible homes, returns instantly outside combat on a personal
  30-minute cooldown and owns death respawn. Planned visit-unlocked waypoints
  connect authored hubs; the separate planned Housing Home Stone targets an active
  bound claim only. Universal riding unlocks at
  levels 15/30/45/60 with land speeds 6.4/8 and flight speeds 8/12 nodes per
  second; damage dismounts. Battlegrounds permit flight, enemy territory allows
  land mounts only, and every exterior-ocean column forbids flight. Boats are
  the deliberate exception to earning travel: the base boat costs five wood at
  level 1, and only the twice-as-fast improved boat needs a recipe taught once
  by a shipwright from level 30. Any damage ejects a rider from a boat exactly
  as it dismounts one from a mount.
- **Story remains light and environmental.** The Accord–Throng war is old; an
  ancient demonic threat reaches upward through the Nether. Both factions face
  it in parallel without becoming allies.

**Scope versus delivery:** this vision includes approved future systems, not just
running code. WP41's exact PvP transaction, WP24 Housing, WP17 boats/waypoints and
WP44 economy remain unfinished. [BACKLOG](BACKLOG.md) distinguishes them.
The original V1 baseline (2026-09-18) included Rounds 1–9, open-world Housing,
mounts, release gates and polish; subsequently approved Rounds 10–19 extend that
baseline. This documentation round neither expands nor removes release scope.
**The walkable Nether remains the first expansion, not V1.**

## Phase 1 — Playable core and world foundation

### Delivered foundation

- [x] Standalone game, faction/race/class creation, progression and four classes
  including Scout; current-ray combat, equipped weapons, talents and shared movement.
- [x] Named-zone world foundation, six starts and capitals, gathering/materials,
  strata and bounded terrain/coast/cave corrections. Public-release evidence remains open.
- [x] Threat/taunt, populations, kings/dragons, homing ranged attacks, dispositions,
  nametags and injured bars. Full endgame encounter scope remains WP23.
- [x] Currency/traders, inventory/bags, Skills recovery, ordinary equipment/offhands,
  fixed-tier enchanting, wear/repair, profession workspaces, food, farming and fishing.
  WP44 target economy and broader item/loot scope remain separate.
- [x] Quest framework with 66 starter and 36 local quests, eighteen regional POIs,
  persistent same-faction parties and optional HUDs.
- [x] World atlas with zoom/scroll, self/party/quest/service markers; innkeeper home
  return and respawn; riding/flight. No fog-of-war or waypoint prerequisite.
- [x] Surface-following optional full-world preparation, resumable bounded scheduling
  and shared creation/reconnect waiting flow.

### Remaining work

- [ ] **WP44 economy:** final Common-price axis, 5% buy-back, complete anti-profit
  audits, Income Ledger and measured mount/claim/respec prices. Running economy
  retains its legacy curve and 25% buy-back until this implementation.
- [ ] **WP5 / WP10 / WP27–WP30 items and professions:** retain wider loot,
  cultural/PvP finish, masterwork and catalog/price remainders. Selected enchanting,
  ordinary gear and seven profession catalogs already exist; do not rebuild them.
- [ ] **WP11:** measured respec-price calibration through WP44; talent consumer lanes
  are implemented, including Scout and the original-class X3 consumers.
- [ ] **WP13 / WP9 / WP42:** remaining authored POI roster and story progression,
  then bounded war-front encounters with their PvP dependencies. Existing start/local
  quests and POIs do not close the full world-story plan. The bandit-frontier
  building-core width discrepancy remains explicit in BACKLOG.
- [ ] **WP24 Housing:** complete Claim Stone protection/state/indexing, capacity
  and pricing integration. No private housing islands or old-world migration.
- [ ] **WP17 travel:** boats with ocean-danger prerequisites, claim-bound Home Stone
  and authored visit-unlocked waypoints. Innkeeper return is already delivered.
- [ ] **WP34 depth:** renewable camp resources, deep pressure/lava and final supply
  tuning after world structures/economy; unresolved design stays in TODO-design-depth.md.
- [ ] **WP41:** exact geographic PvP transaction and shared eligibility seam.
- [ ] **WP23:** full two-dragon encounter scope behind structures, boats, PvP and
  apex resources; visible bosses and several behavior corrections are implemented.
- [ ] **WP14 / WP21 / WP22 / WP31 / WP32:** bounded remaining light/rest, digging-speed,
  repair/Housing, mount-price/acceptance and farming/Housing work. Held-torch moving
  light and friendly-guard healing remain deferred after R18. Use current BACKLOG
  scope, not older “not implemented” descriptions of whole systems.
- [ ] **WP37:** reconcile the old blanket surface-density reduction with later
  approved scoped tuning before scheduling another density change.
- [ ] **WP46 / WP48 / WP49:** remaining indirect terrain protection, bounded writer
  optimization/engine threading dependency and fixed mapgen source-audit roster.

### Before the first public release

These gates remain open after WP40's user-approved development completion.
Freeze game/engine/settings and public seed; rebase current-sampler resource
supply/access evidence; check candidate feature/native/generation-order/runtime/RSS;
verify native and actual fallback-engine startup/generation/restart; complete
media publication attribution/flag obligations. Exact acceptance and ownership:
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
