# Post-WP40 Readiness — Sequence, Handoff Cards and Critical Path

Status: **Planning record, authored 2026-08-13 (post-WP40 planning pass).**
This document sequences the implementation chain that follows WP40 and
records, per work package, what is ready, what is a labeled later input and
what is a genuine blocker. It deliberately contains **no final engineering
brief for WP13, WP33 or WP24**: their briefs would have to invent WP40
outputs (final anchors, measured capacity, audit results) that do not exist
yet. Nothing here changes a WP status or claims implementation.

Companion documents from the same pass:

- [`wp37-task-card.md`](wp37-task-card.md) — executable WP37 card;
- [`wp41-engineering-brief.md`](wp41-engineering-brief.md) — WP41 contract;
- [`wp44-engineering-brief.md`](wp44-engineering-brief.md) — WP44 contract;
- Phase-A design decisions (2026-08-13), already folded into
  `docs/design/`: start-settlement full-envelope+apron protection,
  fail-closed indirect mutation for hard-protected world content (no
  rollback system), and D20 (riding on the capital job trainers, cosmetic
  stable dressing slot only).

## 1. Recommended sequence and dependency picture

Recommended order after WP40 merges (confirmed 2026-08-13):

```text
WP40 (in progress, root)
 ├─► WP37  surface density        — small, mechanical, rebaselines density
 ├─► WP41  geographic PvP         — needs WP40 zone authority
 │    └─► (WP42, WP9 later)
 ├─► WP44  economy rebase         — NO WP40 dependency; may run in
 │    │                             parallel with WP37/WP41 at any time
 │    └─► WP24  claim stones      — needs WP40 masks + WP44 prices
 └─► WP13  world structures       — needs WP40 anchors; after WP41 so
      │                             king/guard tagging lands wired
      └─► WP33  gathering         — needs WP40 source masks; independent
                                    of WP13, may run in parallel with it
```

- **Critical path to "world content complete"**: WP40 → WP13 (→ WP34,
  WP23 later). WP13 is the largest post-WP40 package and the only one
  with a new asset pipeline (§2.6); starting it directly after WP41 keeps
  it off the end of the chain.
- **Critical path to "housing live"**: WP40 → WP44 → WP24. WP44 is
  executable **today** (dependencies WP7 ✅/WP43 ✅); running it during
  WP40's implementation shortens this path by its full length.
- **Critical path to "PvP live"**: WP40 → WP41. WP42/WP9 remain behind
  WP13/WP41 as already recorded in BACKLOG.
- WP33 and WP24 do not depend on each other; WP33 and WP13 share only
  WP40 inputs. The sequence above is a review/merge order, not a
  parallelism ban — every listed edge is the real dependency.
- **Ordering interplay WP37 ↔ WP44**: the Income Ledger's roster weights
  derive from the shipped spawn `chance` values, so the recommended order
  (WP37 before WP44) avoids a rerun. If WP44 completes first, WP37's
  multiplication is an explicit ledger-rerun trigger
  (`wp44-engineering-brief.md` §7; `wp37-task-card.md` §4/§5).

### 1.1 Open inputs versus genuine blockers

| WP | Genuine blockers | Labeled later inputs (not blockers) |
|---|---|---|
| WP37 | none (WP6 ✅) | if run before WP40: WP40 T8 carries values through migration |
| WP41 | WP40 zone API shipped | PvP-death/XP rule decided 2026-08-13 (`progression.md` §3: confirmed PvP deaths cost no XP) — seam ships, the exemption is WP9's wiring; WP5 finish/draught effects consumed later |
| WP44 | none (WP7 ✅, WP43 ✅) | per-band sanity sessions (user time); WP8 quest-income rerun later; WP40 world-label rerun |
| WP13 | WP40 shipped map + anchor/protection APIs | none design-side after Phase A; asset-pipeline risk §2.6; WP42 (units) and WP21 (innkeeper service) attach later |
| WP33 | WP40 shipped zone/source masks | WP34 refill economy explicitly out of scope |
| WP24 | WP40 housing masks + 32-seed capacity report; WP44 claim prices | the capacity **portfolio** is a WP40 measured report — explicitly not a quota; WP24 itself selects the per-faction live-limit defaults below that capacity (`housing.md` §10) |

## 2. WP13 — World Structures: handoff card

Everything WP13 builds is decided design; its brief becomes writable the
day WP40's anchors, gate records and capacity/audit outputs exist.

### 2.1 Structure and asset inventory (complete)

| Class | Count | Content per instance |
|---|---:|---|
| Starting settlements (**S**) | 6 | settlement inside the 128×128 envelope: spawn point, waypoint, graveyard, service platforms, road stub to the home zone; whole envelope + 10-node apron hard-protected (Phase A) |
| Capitals (**C**) | 6 | 512×512 build envelope, 96×96 civic core (king's hall, waypoint, principal service court), four 32-node no-jitter gates, four district quadrants (Market/Professions incl. the cosmetic stable dressing slot, Martial/Garrison, Lore/Spiritual, Residential/Cultural; seed may permute quadrants), race-specific terrain form per `world_zones.md` §12 |
| Kings + royal guards | 6 + 24 | killable L65 elite king, four L60 elite royal guards, group binding/reset/15-min persistent group respawn, personal Crown ledger (60-node / 60-second rules, rolling per-king 24 h lockout) — `world_zones.md` §12, `items_crafting.md` §5.4 |
| Civic services | per capital | class trainers, job trainers (incl. the four riding steps, D20), Housing Steward, vendors (the shipped 8 relocate to final positions), waypoint; all passive services invulnerable, king-independent |
| Villages (**V**) | 12 | two mandatory per race, in the §8 zones |
| Outposts (**O**) | 24 | four ordinary slots per race (`candidate_set` anchors inside reserved envelopes) |
| Bandit camps (**B**) | 12 | exactly one home-zone linen camp + one frontier heavy-cloth camp per race (cloth economy, `biomes_mobs.md` §6) |
| Mirefolk camps (**W**) | 4 | Whitebridge Shire, Lorindor, Mournfen, Whispering Reedlands |
| Peaceful mining camps (**M**) | 6 | one per race region, 10–15 renewable sockets in the region's own tier, protected functional anchor + sockets, mutable shell (`world.md` §2 R4/§4) |
| Apex mining camps (**D/M6**) | 2 | exactly 12 protected renewable sockets each (two per gem species), protected small functional anchor, mutable shell; on the dragon islands |
| Clash-anchor dressing (**K**) | 16 | war-front structure art only — units/schedules are WP42 |
| Named-rare route dressing (**R**) | 10 routes | patrol-route anchors migrate to zone anchors; spawner is shipped WP6 code |

### 2.2 Ownership boundary against WP40 (binding)

WP40 owns immutable terrain, gates, road interfaces, envelopes, semantic
anchor slots, protection/exclusion **geometry** and the query APIs. WP13
realizes visible structures **inside** reserved envelopes through WP40's
anchors/interfaces, meets each fixed gate's position/elevation/direction/
width/grade, and never recalculates an external route
(`wp40-engineering-brief.md` §1.5/§3.1). Multi-chunk schematics must
render as deterministic owner-chunk slices (WP40 §3.1's placement-owner
table); no first-writer platform heights exist anymore.

### 2.3 Spawn-safety decisions applied (Phase A, decided)

Starts and capitals register their complete envelope + 10-node apron in
the world-content registry, and **WP13 itself ships the world-content
half of the fail-closed indirect-mutation authority**: the central
mutation predicate lives in `grug_core` with liquid-inflow
suppression/restore, fire, falling-node and unattributed-effect handling
for hard-protected volumes, alongside the already-live direct dig/place
protection. WP24 later extends that same predicate — never a second one —
to claim volumes and ACL semantics (`housing.md` §6.4/§8). WP13's
protection contract is therefore complete at WP13's own merge, with no
WP24 dependency. No rollback system; no runtime pit/flood detection.

### 2.4 Dependency boundaries

- **WP41**: kings/guards call `grug_pvp.npc_hostile_attempt` — wired if
  WP41 is merged (recommended order), otherwise a documented latent seam.
- **WP42**: WP13 supplies walls/forts/siege art at the 16 clash anchors;
  units, schedules, caps and encounter state are WP42's.
- **WP21**: innkeeper rested-XP/recovery service is WP21; WP13 may
  reserve an inn building slot per capital (dressing, not a functional
  anchor).
- **WP34**: socket refill mechanics; WP13 builds sockets in depleted-safe
  initial state per the existing `grug_nodes` socket contract.
- **WP17/WP12**: waypoint lifecycle and map labels consume WP13's built
  waypoints later.

### 2.5 Open asset and build-pipeline risks (visible, not blocking design)

1. **First large-schematic pipeline**: 6 capitals × 4 districts + 6 starts
   are the project's first multi-chunk builds; authoring flow (build
   in-world → save schematic) and the deterministic owner-slice placement
   are new machinery to prove early — recommend one vertical slice
   (one start + one capital district) as WP13's first task.
2. **Missing build-set media** (`biomes_mobs.md` §5): adobe, marble,
   carved granite, thatch, bone block, cursed cobble, carved totem node
   textures (retints, license-clean path known); great_silverwood.mts and
   gravewood.mts hand-built schematics.
3. **King/guard visuals**: character.b3d + per-race skins (2D work);
   royal-guard tier reuses the shipped guard chassis.
4. **Quantity risk**: 100+ placed structures; mitigate with per-class
   template reuse and the §8 POI budget as the fixed scope fence.

## 3. WP33 — Gathering & Cultural Surface Resources: handoff card

### 3.1 Complete node/content catalog (decided)

- **Healing herbs** (Alchemist-only, never farmable): gravemoss `[herb
  T1]`, dragonweed `[herb T2]`, crimson lotus `[herb T3]`.
- **Spices** (everyone gathers): sunleaf `[spice T1]`, marshbloom
  `[spice T2]`, stormkelp `[spice T3]`.
- **Food plants** `[food]`: potato, corn, apples, berries, melon;
  `[food found-only]`: mushrooms, wild cocoa, rock salt.
- **Cultural sources** (6 × ordinary surface + 6 × concentrated contested
  T4 form): wild waxcomb/apiary cache (Sunwax), slate inscription seam
  (Runeslate), resin root/fossil-resin nodule (Moonresin), ochre
  clay/outcrop deposit (Red Ochre), resinous root/amber nodule (Spirit
  Resin), salt crust/crystal seam (Gravesalt). Item ids exist from WP43
  (`CULTURAL_MATERIALS`); WP33 registers the **source nodes** and harvest
  behavior (ordinary sources keep natural axe/shovel/hand gathering; the
  concentrated form requires T4 harvesting — `items_crafting.md` §4.1).
- **Ordinary signature woods**: tree placement itself is WP40's authored
  decoration pass; WP33 supplies any missing gatherable wood-source
  content the palettes name and must not duplicate tree registrations.

### 3.2 Binding inputs

- WP43 (✅): `CULTURAL_MATERIALS`, `SIGNATURE_WOODS`, `RACE_REGIONS`
  and item ids — consumed by API, never copied. Gatherable plants are
  **not** natural ground: they must not receive `grug_natural` or enter
  `NATURAL_GROUND_NODES` (that inventory is for generated ground/rock).
- WP40: zone ids, `biome_at`, the compiled cultural/gathering source
  masks and exclusions (`wp40-engineering-brief.md` §4.1); zone gathering
  palettes and herb-tier source zones from `world_zones.md` §8/§11
  (gravemoss: Copperfell/Mournfen; dragonweed: Dwarf/forest side and
  Undead/Orc wilds; crimson lotus: only Skyglass Canopy / Stormscale
  Summit palettes; marshbloom: the four Mirefolk wetland zones; stormkelp:
  endpoint coasts and both high coastal approaches).

### 3.3 Required audits

1. **Coverage**: every zone palette gatherable exists in that zone;
   nothing places outside its palette (`world_zones.md` §14
   biomes/content gate).
2. **Faction balance**: paired gather opportunity per level bracket within
   ±10% (§11); both factions reach every herb/spice tier and every
   cooking-tier ingredient (T6 cooking gate intact).
3. **Placement**: no floating/buried result, exclusion corridors and
   protected envelopes respected, Alchemist gate verified (non-Alchemist
   punch yields nothing plus hint), found-only three never farmable.

### 3.4 Non-goals

No WP34 resource economy (renewable refill, deep multipliers, socket
yields), no WP32 farming, no WP10 recipes — WP33 supplies world sources
only.

## 4. WP24 — Claim Stone Housing: handoff card

The complete design is decided in `housing.md`; this card fixes the
implementation shape and the placeholders.

### 4.1 Canonical model (pointers, all decided)

- **State machine**: canonical locations `placed` / `inventory` /
  `recovery_escrow` / transient transactional / `dormant`, with the exact
  §5.1 transition table (slot accounting per transition) and
  `decay_eligible` as a predicate, not a state.
- **Stable ids and generations**: monotonically increasing registry
  generation per id; live ItemStacks mirror id+generation; decay/
  dormancy/reissue increment before a replacement becomes valid; stale
  stacks are rejected and lazily removed; one canonical live location
  (§8.1).
- **Indexes**: canonical records in mod storage; ≥3 AreaStore-backed
  logical indexes (active 3D protection cubes; radius-50 reservations as
  degenerate y=0 cuboids; claim-exclusion envelopes), rebuilt on load,
  updated transactionally; hot dig/place/spawn checks are point queries,
  never node scans or a protection globalstep (§8).
- **Placement validation**: candidate radius-60 AABB (candidate-expanded
  only) against stored radius-50 AABBs of other owners; every point of
  the 101×101 mask passes `housing_eligible_at` and all §6 exclusions;
  depth bound y ≥ −50.
- **Lifecycle services**: four-hour binding, recovery with escrow
  fallback, voluntary/forced dormancy, on-demand decay with atomic
  slot transfer, reissue, Steward pool snapshots and notices with the
  exact §5.3/§5.4 texts, admin tools with audit logging.

### 4.2 Phase-A addition (decided 2026-08-13)

The **central mutation predicate serves two volume classes**: active
claims and hard-protected world content share the fail-closed
indirect-mutation model and the spatial indexes (`world.md` §2 R1,
`housing.md` §6.4/§8). The world-content half ships with WP13 (§2.3);
WP24 extends that same predicate to claim volumes and ACL semantics —
one implementation, never a claims-only special case or a second
evaluator.

### 4.3 Test model (crash/reconnect/duplicate)

The §8.1 transaction list is the base matrix: placed↔inventory/escrow
count preservation; live→dormant releases exactly one slot;
dormant→live consumes exactly one without a new personal id; full-pool
decay+issuance leaves assigned unchanged; `assigned > limit` does
nothing; stale generations never create a second live location. Extend
with: crash between recovery steps (protection removed only after safe
persistent state), idempotent escrow delivery across restarts, offline
stack invalidation on login, Home-Stone destination disable/enable races,
concurrent issuance requests (first-come atomicity), index rebuild
equivalence after unclean shutdown.

### 4.4 Explicit placeholders (later inputs, labeled)

- **Per-faction live-Stone limits**: WP40 owns only the measured 32-seed
  packing **portfolio** (`wp40-engineering-brief.md` §6.3 — explicitly not
  a claim-count quota); WP24 itself selects and configures the per-faction
  defaults below that demonstrated capacity (`housing.md` §10). Until the
  portfolio exists, the setting ships conservative and documented.
- **Claim upgrade / additional-stone copper values**: WP44 ledger outputs
  consumed by reference (`wp44-engineering-brief.md` §6); material halves
  (4/8/12/12/24 bars) are already decided data.
- **Housing masks**: `housing_eligible_at` and the guaranteed coastal-core
  audit are WP40 outputs; WP24 consumes the immutable mask, never
  recomputes relief.

## 5. Documentation and status hygiene for this pass

- No WP status changed; nothing here claims implementation or runtime
  results. WP40's own gates (brief review, 32-seed audits, benchmarks)
  remain implementation gates recorded in BACKLOG/ROADMAP.
- Phase-A decisions are folded into `world.md`, `world_zones.md`,
  `housing.md`, `mounts.md`, `professions.md`; `TODO-design-spawn-safety.md`
  is deleted and `TODO-design-crafting-rework.md` carries D12/D14–D19
  only. BACKLOG (WP13/WP31 rows, WP18 record annotation), ROADMAP and
  README were synchronized in the same pass.
- When WP13/WP33/WP24 briefs are eventually written, they consume this
  card plus the then-existing WP40 outputs; a card row that names a WP40
  output is a *later input*, and inventing it earlier would violate the
  same rule the WP40 brief sets for itself.
