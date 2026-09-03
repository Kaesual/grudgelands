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
  bounded functional anchors, complete civic cores and irreplaceable route
  pieces are hard-protected.
- **The ocean has authored classes.** Planned mainland water stays part of its
  named zone. An editable 80-node coastal shelf follows the analytic outer
  perimeter; immutable deep ocean begins beyond it. Two immutable channels
  separate the offshore level-60 dragon islands and keep them boat-only. The
  playable boat contract remains intentionally open in
  [TODO-design-boats.md](TODO-design-boats.md).
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
  land mounts only, and every exterior-ocean column forbids flight.
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
  **Legacy boundary:** the running surface still uses rectangles, radial
  difficulty and the mandatory water separation until WP40.
- [x] WP19, WP35, WP38, WP39: tuned class kits, race passives, weapon slot,
  native-animation held swings, exact current-ray aim, PvP/PvE settlement,
  ready reticle, diagnostics and swept Fireball projectiles.
- [x] WP25: six visual strata and a first material implementation.
  **Historical boundary:** its 2026-08-08 Completion Record describes the
  Emberstone and coupled node-`level`/pick-`maxlevel` implementation that
  WP43 now supersedes while preserving one-way saved-world migration.
- [x] WP43: canonical Bronze→Abyssal Steel registry, Emberglass/Abyssal Steel
  namespaces, exact natural depth, separate harvest tier, complete
  G1/G2/cultural/race-region data, migration diagnostics and the
  protection-first mining transaction.
- [x] WP45: safe character-creation stasis, opaque faction/race/class flow and
  race-start preloading with one final teleport after successful emergence.

### Next prerequisite roots

- [ ] **WP26 — Universal bars and furnace:** implement the dual-input furnace
  and the six-tier alloy chain against WP43's shipped canonical registry.
- [ ] **WP40 — Named-zone world foundation:** replace the WP18 surface with
  the 38-zone hybrid-v7 target using WP43's shipped resource/race-region
  contract. **In progress since 2026-08-13; simple-map rebase accepted
  2026-08-25; R0, R1, V1b, V1c and V1d accepted 2026-08-25; fixed-layout
  V1e R2 independently and visually accepted 2026-08-27 as the sole live R2
  authority, with V1d retained as history at `d337160`.** R0
  replaced the unfinished exact-T2 partition/topology path; R1 now provides
  one fixed pure 2D model and canonical SVG; V1d adds stronger single-warp
  border meanders, pinned curved routes, tapered bays with ownerless
  deep-ocean mouth caps, coherent visible water and six hard-protected capital
  ingress corridors; V1e freezes all 100 anchors and 74 actual POI spurs and
  closes three contact-face waterfalls. The V1e visual gate, exhaustive R2
  layout freeze, route/water/core validation and housing-capacity evidence are
  independently accepted. The pure R3 vertical implementation and canonical
  artifact and the complete still-disabled R4 geography/policy payload were
  independently accepted 2026-08-27. The pure typed R5 planner/adapter payload
  and canonical artifact were independently accepted 2026-08-29. R6's frozen
  surface/resource catalogs, private cultural-slot API, complete 32-seed
  evidence and canonical artifact were independently accepted 2026-08-31.
  R7's single production writer, existing-consumer cutover, WP33 gathering
  payload, P9G successor and functional-anchor suffix were independently
  accepted 2026-09-02 at `68f6cec`; its bounded evidence is explicitly a
  32-seed stratified main sample plus a seven-seed frontier-access lane, not
  exhaustive spatial coverage. R8 is the remaining final release/runtime
  stage and owns the first real fresh Luanti world.
  Current technical contract:
  [wp40-engineering-brief.md](docs/research/wp40-engineering-brief.md); current
  R0-R8 sequence:
  [wp40-simple-map-rebase-plan.md](docs/research/wp40-simple-map-rebase-plan.md).
  The accepted R2 artifact owns fixed-layout route/housing validation and
  once-per-layout capacity; the accepted R6 artifact owns the 32-seed
  content/supply/access evidence. Production mapchunk performance and runtime
  evidence remain R8 gates.
- [ ] **WP44 — Economy Rebase:** migrate the Common-price axis, 5% buy-back
  and Income Ledger against the final material ids; calibrate exact Claim
  Stone and mount costs.
- [ ] **WP37 — Surface density:** apply the already-decided 0.75 multiplier
  and re-run the spawn-budget audit.
- [ ] **WP11 / WP14 / WP20 / WP21 / WP8:** skill trees, live offhand/carried
  light, parties, recovery/rest and the quest framework are independently
  ready behind their shipped prerequisites.

### Dependent world and item loop

- [ ] WP27–WP30: base armor; the
  six-tier gear/tool merge; safe removal of superseded vendored recipes; and
  trader-catalog migration onto WP44 prices.
- [ ] WP5 remains blocked on `TODO-design-crafting-rework.md` A2/A6; WP10
  remains blocked on that file's A1/A4/A5/E21. They resume only after those
  genuine affix/recipe/content questions are decided.
- [ ] WP13: final starts, capitals, settlements, camps, kings/guards and both
  all-six-gem apex camps on WP40 geometry and WP43 materials.
- [x] WP33: gathering plants, signature woods and cultural sources on final
  zone/race-region ownership; accepted with WP40 R7 on 2026-09-02.
- [ ] WP34: deep spawn pressure, corrected depth-level curve, camp-only
  renewable resources, deep lava and final Abyssal/G1/G2 density. It follows
  map, materials, structures and economy; it is not an independent next WP.
- [ ] WP24: complete Claim Stone state machine, protection/indexing and
  capacity-calibrated placement after WP40/WP43/WP44.
- [ ] WP17 and WP12: claim-bound Home Stone, authored waypoint travel and the
  fog-of-war map after claims and final zones. Boat integration remains
  blocked on the focused boat TODO.
- [ ] WP41: implement the exact geographic PvP transaction after WP40.
- [ ] WP42 and WP9: bounded war-front clashes and mandatory named-zone
  questlines after final structures/map/PvP.
- [ ] WP23: both dragon encounters after structures, playable boats, final
  map, contested PvP and renewable apex resources.
- [ ] WP22: durability/repair and explicit six-pick speed/use calibration
  after loot, materials and economy.
- [ ] WP31: mounts after final map/economy plus the remaining explicit mount
  questions in `TODO-design-crafting-rework.md`.

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
