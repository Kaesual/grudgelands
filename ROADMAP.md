# Roadmap — Grudgelands

Grudgelands is a standalone, WoW-inspired voxel RPG for Luanti. It combines
two factions, races, classes, fast leveling, threat-based combat, professions,
an item economy, open-world housing and geographic PvP in an authored but
procedurally detailed world.

The decided game rules live in [docs/design/](docs/design/). Implementation
status and exact dependencies live in [BACKLOG.md](BACKLOG.md); this roadmap is
the goal-level view.

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
- **Travel is earned.** Visit-unlocked waypoints connect authored hubs. A Home
  Stone channels to the active bound claim only. Universal riding unlocks at
  levels 15/30/45/60 with land speeds 6/8 and flight speeds 7/10 nodes per
  second; damage dismounts. Battlegrounds permit flight, enemy territory allows
  land mounts only, and every exterior-ocean column forbids flight. Boats are
  the deliberate exception to earning travel: the base boat costs five wood at
  level 1, and only the twice-as-fast improved boat needs a recipe taught once
  by a shipwright from level 30. Any damage ejects a rider from a boat exactly
  as it dismounts one from a mount.
- **Story remains light and environmental.** The Accord–Throng war is old; an
  ancient demonic threat reaches upward through the Nether. Both factions face
  it in parallel without becoming allies.

## Phase 1 — Playable core and world foundation

### Shipped foundation

- [x] WP0–WP4: standalone game skeleton, factions, XP, three classes and the
  first ability kits.
- [x] WP6: complete mob roster, level/tier engine, threat, leash/evade,
  pathfinding pass, guards, camps and named rares.
- [x] WP7: ledger currency, generated gear catalogs, armor pipeline and eight
  trader NPCs. **Legacy boundary:** the running implementation still uses its
  old price curve and 25% buy-back until WP44.
- [x] WP15: Character/Bags pages, equipment lists and four bag slots.
- [x] WP18, WP36: the current two-continent map, biome baseline, repaired
  coastline/capital generation, reference submodules and critter/prey pass.
  WP40 now supersedes their surface geometry and difficulty authority.
- [x] WP19, WP35, WP38, WP39: tuned class kits, race passives, weapon slot,
  native-animation held swings, exact current-ray aim, PvP/PvE settlement,
  ready reticle, diagnostics and swept Fireball projectiles.
- [x] WP25: six visual strata and a first material implementation.
  **Historical boundary:** its 2026-08-08 Completion Record describes the
  Emberstone and coupled node-`level`/pick-`maxlevel` implementation that
  WP43 now supersedes; development-era migrations have been removed.
- [x] WP43: canonical Bronze→Abyssal Steel registry, Emberglass/Abyssal Steel
  namespaces, exact natural depth, separate harvest tier, complete
  G1/G2/cultural/race-region data and the protection-first mining transaction.
- [x] WP45: safe character-creation stasis, opaque faction/race/class flow and
  race-start preloading with one final teleport after successful emergence.
- [x] **WP40 — Named-zone world foundation:** the fixed 38-zone world,
  terrain/biome/content/resource generation, fitted pads/terraces and routes,
  water handling and shared geography APIs are delivered. The first correction
  round and native/browser-local Lua-5.1 user acceptance are complete on
  2026-09-13. See the [completion record](docs/research/wp40-completion.md).
  This development completion leaves the explicitly separated first-public-
  release gates below open and does not end fresh-server mode.

### Next prerequisite roots

- [x] **WP26 — Universal bars and furnace:** the dual-input furnace and the
  six-tier alloy chain are implemented against WP43's shipped canonical
  registry (2026-09-16). `mods/ITEMS/grug_smelting` ships the ported two-slot
  station, the five single-input smelts, the five alloys, the twelve storage
  pack/unpack pairs and the station's own T1 craft recipe, and extends
  `grug_traders`' anti-loop audit to the alloy chain the engine cannot see.
  Details: [WP26 implementation](docs/research/wp26-implementation.md). The
  user's ~10-minute runtime test plan (task card §8) is still open.
- [ ] **WP44 — Economy Rebase:** migrate the Common-price axis, 5% buy-back
  and Income Ledger against the final material ids; calibrate exact Claim
  Stone and mount costs.
- [ ] **WP37 — Surface density:** apply the already-decided 0.75 multiplier
  and re-run the spawn-budget audit.
- [ ] **WP11 — skill trees, phase 1 shipped (2026-09-16):** the talent model
  and its thirty numeric consumers are in the game (lanes X1 + X2 of
  `docs/design/skill_trees.md` §4) — 48 talents of Warrior, Mage and Priest,
  one point every two levels, both gate kinds, a full-reset respec, and
  interim `/talents` `/talent` `/respec` chat commands until the sfinv page
  lands. Still open: lane X3 (keystones, capstones, four new abilities) and
  lane X4 (the UI, the respec price, the level-up page).
- [ ] **WP14 / WP20 / WP21 / WP8:** live offhand/carried
  light, parties, recovery/rest and the quest framework are independently
  ready behind their shipped prerequisites.

### Dependent world and item loop

- [ ] WP27–WP30: base armor; the
  six-tier gear/tool merge; safe removal of superseded vendored recipes; and
  trader-catalog migration onto WP44 prices.
- [ ] WP5 is design-unblocked (A2 affix vocabulary and A6 refined marker
  decided 2026-08-13, `items_crafting.md` §§6b.4/6b.7) and **startable now**:
  all three dependencies are shipped and the executable card is
  [docs/research/wp5-task-card.md](docs/research/wp5-task-card.md). WP10 is
  design-unblocked (A1/A3/A4/A5/E21 decided 2026-08-13, incl. the revised
  food-restore buff model and the buff/debuff icon framework); with WP26 ticked
  above it now follows WP44 alone, since WP33 and WP43 are shipped too.
- [ ] **WP13 — in progress:** final starts, capitals, settlements, camps,
  kings/guards and both all-six-gem apex camps on shipped WP40 geometry and
  WP43 materials. **All six start settlements are built** (2026-09-14) on one
  reusable building library with per-race palettes, together with the
  atmosphere layer and a licence-audited decorative building kit: Hearthpine
  Vale (dwarf), Dawnmere Fields (human), Silverleaf Glade (elf), Stillgrave
  Hollow (undead), Sunscar Camp (orc) and Kapok Cradle (troll). The four
  parallel lanes were merged onto one branch and given one combined
  review-fix round. Every start awaits the user's GUI playtest; capitals,
  villages, outposts, camps and the king/guard content are the rest of the
  package.
  The **capital parts library** followed the same day: eighteen generators
  (king's hall with throne room, curtain wall, tower, gatehouse, market
  square, colonnade, temple, barracks, scriptorium, granary, stable,
  statue, and hedge/grove/stilt/water edge pieces), the capital palette
  vocabulary and the NPC socket seam, with the six starts byte-identical
  (`docs/research/wp13-capital-library.md`).
  **Highcourt**, the human capital and the pilot for the other five, was
  composed out of those parts on 2026-09-14: a 96 x 96 civic core with the
  king's hall, four gatehouses, market square, colonnades, chapel, service
  court with the two royal vendors and a travel plaza reserved for WP17;
  the market and professions district as nine terrain-relative plots; and
  the gate avenues as a pure surface overlay a successor can run per
  mapchunk (`docs/research/wp13-highcourt.md`).
  On 2026-09-15 the **settlement seam was generalised** and Highcourt now
  stands in the world: a settlement carries its own build envelope and may
  own many blueprints, its district plots are projected from the terrain
  under their own reference column, its avenues are computed per mapchunk
  from the ground the map has, and a capital's buildings are constructed
  only when somebody goes there. Its 71 NPCs arrive with the place rather
  than at server start, and its two royal traders stand on the blueprint's
  own sockets. The six starts are byte-identical, engine digests included
  (`docs/research/wp13-seam-generalisation.md`).
  **All six capitals stand** since 2026-09-16; every record named below is a
  note in `docs/research/`. Highcourt's other three
  districts and the seeded quadrant permutation landed first
  (`wp13-highcourt-districts.md`), then its wall ring, fill and trades
  (`wp13-highcourt-fill.md`); the wave-2 lanes added Dur Brannoc (dwarf),
  Gor Drazhak (orc), Lethariel (elf), Kezamba (troll) and Nhal Veyr
  (undead), each with four districts of nine plots plus four pieces of open
  fill ground, its own envelope edge — a stone curtain for the four walled
  capitals, a stake palisade on an earth rampart for Gor Drazhak, a planted
  belt with thresholds for the two open ones — and its own trades
  (`wp13-dur-brannoc.md`, `wp13-gor_drazhak.md`, `wp13-lethariel.md`,
  `wp13-kezamba.md`, `wp13-nhal_veyr.md`). Alongside them: the terrace step
  bands and per-race capital ground (`wp13-capital-terrain.md`), the one
  material-named weapon ladder of `items_crafting.md` §3.0.3
  (`wp13-weapon-ladder.md`), the NPC work/activity vocabulary, the twelve
  profession shop vendors and the 80/20 walker split (`wp13-npc-work.md`,
  `wp13-npc-vocabulary.md`), and the user's routes-end-at-the-gate ruling
  (`wp13-route-gates.md`). **Still open in WP13:** the user's GUI playtest
  of the six capitals; the whole remainder of the contract's 100-anchor POI
  roster (`wp13-capitals-pois-contract.md` §2.5) — 12 villages, two of them
  with a shipwright's plot and display boat, 24 outposts, 12 bandit camps, 6
  mining camps, 4 mirefolk camps, 16 clash anchors, 2 dragon arenas, 2 apex
  camps and 10 rare-route pads, where the mirefolk camps, clash anchors and
  dragon arenas are WP13 dressing only and WP42/WP23 own their encounters;
  and the six kings with their royal guards — no king entity exists yet, only
  the `king` socket in every capital core.
- [x] WP33: gathering plants, signature woods and cultural sources on final
  zone/race-region ownership; accepted with WP40 R7 on 2026-09-02.
- [ ] WP34: deep spawn pressure, corrected depth-level curve, camp-only
  renewable resources, deep lava and final Abyssal/G1/G2 density. It follows
  map, materials, structures and economy; it is not an independent next WP.
- [ ] WP24: complete Claim Stone state machine, protection/indexing and
  capacity-calibrated placement after WP40/WP43/WP44.
- [ ] WP17 and WP12: claim-bound Home Stone, authored waypoint travel and the
  fog-of-war map after claims and final zones. WP17 also implements the
  decided boat contract plus the three ocean-danger prerequisites it needs, so
  its runtime test covers the whole mob roster.
- [ ] WP41: implement the exact geographic PvP transaction after WP40.
- [ ] WP42 and WP9: bounded war-front clashes and mandatory named-zone
  questlines after final structures/map/PvP.
- [ ] WP23: both dragon encounters after structures, playable boats, final
  map, contested PvP and renewable apex resources.
- [ ] WP22: durability/repair and explicit six-pick speed/use calibration
  after loot, materials and economy.
- [ ] WP31: mounts after final map/economy plus the remaining explicit mount
  questions in `TODO-design-crafting-rework.md`.

### Before the first public release

These gates remain **open** after WP40's user-approved development completion.
The project coordinator owns them when preparing the release candidate, before
user release approval: freeze game/engine/settings and the public seed; rebase
current-sampler resource supply/regional access evidence; run current-candidate
feature/native/generation-order and runtime/RSS checks; and confirm native plus
actual fallback-engine startup/generation/restart. Historical source-bound
results are not silently promoted to later bytes; native events not observed
remain explicit coverage limits. Full tracking lives in
[BACKLOG](BACKLOG.md#first-public-release-gates) and the
[WP40 completion record](docs/research/wp40-completion.md).

## Phase 2 — Expansion

- [ ] Paladin, Rogue, Warlock and Shaman; decide the separate ranged-weapon
  class direction before activating the already-catalogued bow family.
- [ ] Farming inside active claims: only cooking foods and universal spices
  become crops; healing herbs, cultural materials, ores and found-only foods
  do not.
- [ ] Coastal-shelf life: coral, kelp, fish, coastal materials and shore
  wildlife inside the authored editable shelf, without redefining deep ocean
  or the dragon channels.
- [ ] Walkable Nether content and later demonic bosses after its focused
  design questions are resolved.
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
