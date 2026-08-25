# Open-world Housing Claims

Housing is an open-world, per-character land-claim system. A placed **Claim
Stone** creates the only permanent player-owned protection in the game.
Separate private housing islands do not exist. The target game has no guild
system: claim ownership, access, storage and services never depend on guild
membership, guild roles, guild banks or guild terminals.

The implementation uses the ownership, member, visualization and
administration patterns of the MIT-licensed `reference_projects/protector/`
checkout at pinned commit `60d2280` as a behavioral reference, not as a
drop-in implementation.

## 1. Housing geography and core rules

- Claims may be placed only on authored housing-eligible ground in exactly ten
  peaceful level-11–30 home zones.
- The complete housing-zone catalog is:

  | Stable zone id | Display name | Faction | Level |
  |---|---|---|---:|
  | `elandor_copperfell_foothills` | Copperfell Foothills | Accord | 11–20 |
  | `elandor_goldmead_vale` | Goldmead Vale | Accord | 11–20 |
  | `elandor_starbough_vale` | Starbough Vale | Accord | 11–20 |
  | `elandor_whitebridge_shire` | Whitebridge Shire | Accord | 21–30 |
  | `elandor_lorindor` | Lorindor | Accord | 21–30 |
  | `kragmar_mournfen` | Mournfen | Throng | 11–20 |
  | `kragmar_redtusk_savanna` | Redtusk Savanna | Throng | 11–20 |
  | `kragmar_raincall_basin` | Raincall Basin | Throng | 11–20 |
  | `kragmar_speargrass_reach` | Speargrass Reach | Throng | 21–30 |
  | `kragmar_whispering_reedlands` | Whispering Reedlands | Throng | 21–30 |
- The six level-1–10 starting zones are completely claim-free. A character's
  first Claim Stone unlocks at level 20.
- Four level-11–20 zones provide guaranteed coastal alternatives:
  Copperfell Foothills and Mournfen on the west coasts, and Starbough Vale and
  Raincall Basin on the east coasts.
- Each guaranteed coastal housing strip is one fixed vertical capsule: a
  straight middle section with rounded ends, at least 600 continuous nodes of
  shoreline frontage and at least 300 nodes of buildable inland depth. The
  entire mutable capsule is dry, owned by its named housing zone and free of
  every static exclusion after final coastline variation.
- The capsule may taper at its rounded ends. Frontage and depth are audit
  minima, not a visible rectangle and not a Claim-Stone quota.
- Every possible 101×101 reservation wholly inside a guaranteed core has at
  most 12 nodes of generated natural-ground height variation and contains no
  forced cliff, ravine, river or lake. Trees, structures and later player
  edits do not count as natural-ground relief.
- A complete 101×101 reservation may meet the final shoreline but may not
  contain any coastal-shelf column. Protected underwater claims and private
  harbors do not exist.
- Each of the ten housing masks must admit at least one constructive complete
  reservation in the fixed-layout packing audit. No higher per-mask quota is
  promised; the administrator-facing faction limit is chosen below measured
  faction-wide capacity.
- Permanent player-owned protection exists only inside an active Claim Stone
  volume. Building elsewhere follows the ordinary faction, zone and contested
  terrain rules and is not private property.
- A successful placement binds its stone for four hours of real wall-clock
  time. Offline time and server downtime count. The placement timestamp is
  persisted from `os.time()`. Every relocation starts a new four-hour binding;
  an upgrade does not reset it.
- Before the binding expires, only an administrator may remove the stone.
  After expiry, its owner may recover it through the stone's controlled
  interaction. Recovery immediately deactivates the claim and any Home Stone
  destination.
- The two nodes directly above a placed Claim Stone are its permanently
  reserved arrival column. No player, including the owner or a trusted
  character, may place a node, torch or liquid there.
- Player-owned profession workstations are permitted inside valid claims.
  Public stations and passive helper NPCs remain available, so housing is
  never a material-progression requirement.
- Traders, trainers, Housing Stewards and every other service or quest NPC are
  world-owned content. Players cannot place, move, bind or transfer them into
  claim ownership. Private doors, ordinary workstations and unsealed
  inventories use the claim ACL in §3.

The authored zone geometry, road classes, coast rules and PvP boundaries are
defined by [Named World Zones & PvP Geography](world_zones.md), especially
§§7–15.

## 2. Claim tiers, reservation and issuance

The Claim Stone is the centre of its protected area.

| Claim tier | Required character level | Active radius | Active footprint |
|---|---:|---:|---:|
| I | 20 | 20 | 41 × 41 |
| II | 35 | 30 | 61 × 61 |
| III | 50 | 40 | 81 × 81 |
| IV | 60 | 50 | 101 × 101 |

- The active protection volume is a cube centred on the Claim Stone. Its x, y
  and z radii all equal the tier radius. The four active volumes are 41³, 61³,
  81³ and 101³ nodes.
- Tier is permanent state of the individual Claim Stone, not a
  character-wide licence. Every stone has one stable claim id, one owner and
  one tier in its canonical record; live item and node metadata mirror those
  fields together with the current registry generation.
- Recovery and relocation preserve stable id, owner and tier. Every additional
  stone begins at tier I and is upgraded independently.
- Claim Stones are owner-bound and non-tradeable. Another character cannot
  place, recover or upgrade one to bypass a level, quota or price gate.
- A placed stone exposes its own transactional upgrade action. It validates
  the owner and required level, consumes the final authored money and material
  cost, then increases the radius without replacing the stable id or ownership.
- At level 20, a short housing-introduction quest from a passive, invulnerable
  Housing Steward unlocks the first owner-bound Claim Stone. Every capital has
  a Housing Steward. This essential service is independent of the killable
  king and royal guards.
- The first-stone entitlement is free after the introduction quest. The
  character requests issuance from a Steward whenever a faction slot is
  obtainable. If none is obtainable, no uncounted stone is created.

| Upgrade | Required level | Material cost | Money target |
|---|---:|---:|---:|
| tier I → II, radius 20 → 30 | 35 | 4 Silversteel Bars | 30 minutes of reliable T4 net solo income |
| tier II → III, radius 30 → 40 | 50 | 8 Embersteel Bars | 90 minutes of reliable T5 net solo income |
| tier III → IV, radius 40 → 50 | 60 | 12 Abyssal Steel Bars | 3 hours of reliable T6 net solo income |

- Reliable net income is measured after routine level-appropriate repairs and
  consumables and excludes rare jackpots, world-boss rewards and player trade.
- Each measured raw-copper target is rounded with the coarsest denomination in
  `1s / 25c / 5c / 1c` whose nearest multiple remains within 5% of the target.
  An exact midpoint rounds upward.
- Upgrades are sequential and occur only through the placed stone. The server
  revalidates level, owner, current tier, full money balance and exact material
  stacks, then consumes money and bars in one atomic transaction before
  committing the new tier. Failure consumes nothing.
- No profession is required. There is no downgrade or refund. Paid tier
  progression survives recovery, relocation, inactivity decay, dormancy and
  later reissuance through the same stable id.
- Claim upgrades never require gems, culture materials, foreign-faction
  materials or profession-exclusive components.

### 2.1 Maximum reservation and exact spacing

- Placement of a tier-I stone immediately reserves its complete future tier-IV
  101×101 x/z footprint. Every point in that future footprint must be
  housing-eligible, ensuring that later upgrades cannot be blocked by a
  neighbor or world-content boundary.
- Maximum reservation is strictly two-dimensional. Different owners' projected
  radius-50 reservations cannot overlap even when their active protection
  cubes are vertically disjoint.
- Different owners require at least ten completely unclaimed horizontal nodes
  between reservation edges. Two critical-axis tier-IV centres therefore
  differ by at least 111 nodes, independent of y.
- The exact pair predicate is an inclusive x/z AABB test: expand the
  **candidate** radius-50 reservation by ten nodes on all four sides, then
  reject it if that expanded box intersects another owner's stored radius-50
  box.
- Only the candidate box is expanded. Expanding both boxes would incorrectly
  require a 20-node gap.
- The Chebyshev/AABB predicate applies at corners as well as cardinal edges. It
  is not a Euclidean centre-distance test.
- Multiple stones of the same owner may touch or overlap. They bypass only the
  pairwise inter-owner spacing predicate; every housing-mask and exclusion
  check still applies. Each stone consumes its own faction slot and an overlap
  creates no extra land capacity.

### 2.2 Personal quota and additional stones

- `grug_housing_max_claims_per_character` is an integer setting with range
  1..3 and default `1`.
- The quota counts every stable id owned by the character, including dormant
  ids. Recovery, decay and voluntary dormancy cannot evade it.
- The registry, persistence, UI and transactions support settings 2 and 3
  without data migration.
- A second or third owner-bound Claim Stone may be issued only at character
  level 60, only when every already owned stone is tier IV, and only when the
  same atomic transaction obtains a faction slot.
- The second stone costs 12 Abyssal Steel Bars plus 5 hours of measured
  reliable T6 net solo income. The third costs 24 Abyssal Steel Bars plus 10
  hours. Their ledger prices use the same denomination and 5% rounding rule as
  tier upgrades.
- Failure to obtain a faction slot consumes no money or material.
- Each additional purchase creates a new stable id at tier I. It is upgraded,
  placed, recovered, decayed, made dormant and reissued independently. Its
  one-time purchase is neither refunded nor charged again after dormancy.
- Additional stones use first-come, first-served issuance and receive no
  reservation or priority.
- Lowering the personal setting grandfathers all existing ids and never revokes
  one. Reissuing an existing dormant id remains legal. Creation of another id
  is blocked whenever the character already owns at least the configured
  number.

### 2.3 Depth bounds

- A Claim Stone may not be placed below y = −50. This is the T1 pick's natural
  depth limit at y = −100 minus the maximum possible claim radius 50, so no
  claim volume can reach below the T1 layer.
- At y = −701 and below, the universal contested T5/T6 terrain rule overrides
  every land claim: both factions may dig and place, and PvP is always
  contested.
- Deep ocean and immutable dragon-channel columns remain immutable at every
  depth.

## 3. Ownership and access

- Every Claim Stone has exactly one owner. There is no co-ownership.
- Only the owner may upgrade, recover or relocate the stone or edit its trusted
  list.
- A claim accepts at most ten trusted characters, all from the owner's faction.
- Trust is one permission, not a per-action matrix. It permits digging,
  placement and use of ordinary doors, workstations and unsealed inventories
  inside the active claim.
- Removing trust revokes those permissions immediately.
- Other characters may walk through a claim. Owners use ordinary walls and
  doors to restrict physical entry.
- Claim permission never overrides world, faction, immutable-content, depth or
  PvP rules. Every outer rule must permit the operation before the claim ACL is
  evaluated.
- At a point covered by multiple claims, a non-owner must be trusted by every
  covering claim; denial wins. Different owners' reservations cannot overlap,
  so this applies only to multiple stones belonging to one owner. The owner is
  permitted by all of their own claims.
- An active Claim Stone owns ordinary blocks, inventories and functional nodes
  within its volume regardless of which trusted character placed them. A
  trusted builder has revocable access, never competing ownership. Ownership is
  resolved from the claim registry rather than stored as the placer on every
  node.
- There is no separately owner-locked chest in the housing rules. A future
  container with an independent owner or ACL requires an explicit compatibility
  rule and cannot silently inherit a generic placer-owned convention.

## 4. Home Stone

- The Home Stone teleports only to the owner's currently bound, active Claim
  Stone. It has no capital fallback.
- Without an active bound claim, the Home Stone is disabled and explains why
  it cannot be used.
- Player state stores `home_claim_id`, never only a raw position.
- The first successfully placed Claim Stone binds automatically. With multiple
  claims, rebinding requires physical interaction with the destination Claim
  Stone.
- Recovering, decaying or making the bound claim dormant immediately disables
  its destination without leaving a stale position. Re-placing the same stable
  id makes its moved destination valid again.
- Use is a ten-second stationary channel. It cannot begin while
  `grug_core.in_combat(player)` is true.
- The server stores the cast-start position. Displacement greater than 0.1
  nodes interrupts. Camera rotation and sub-threshold engine correction do not.
  Logout and death interrupt.
- PvP interruption follows `world_zones.md` §15 event semantics:
  - a server-valid hostile attempt or effective support action performed by
    the channeling player interrupts even when a safe→safe hostile effect is
    blocked;
  - accepted hostile damage that lowers the channeler's HP or consumes absorb
    interrupts;
  - effective support received by the channeler interrupts;
  - misses, dodge, immunity, eligibility refusal, failed or zero-effect support
    and the PvP tag by itself do not interrupt.
- A PvP tag alone cannot prohibit the channel because contested zones force it
  permanently. The combat gate, exposed channel and qualifying action/effect
  interruptions are the anti-escape rules.
- The 60-minute cooldown begins only after a successful teleport and uses a
  persisted wall-clock timestamp. Offline time counts.
- An interrupted channel, unavailable claim or technical failure consumes no
  cooldown.
- Before the channel starts, the server loads or emerges the destination and
  validates the canonical claim, placed stone and reserved arrival column. It
  repeats those validations at completion. A load failure or invalidated
  destination fails safely with a message and no cooldown.
- Arrival is the standing node directly above the Claim Stone; the second
  reserved node is headroom. Temporary player or mob overlap does not block
  arrival.
- Innkeepers may retain recovery and rest services but never bind or rebind a
  Home Stone. The obsolete race-capital Home Stone destination is not part of
  the game.

## 5. Stable-id lifecycle, retention and administration

The canonical registry, never a world node or ItemStack, is authoritative.
Every stable claim id is in exactly one canonical location state.

| Canonical location | Live | Faction slot | Active protection/reservation |
|---|---|---|---|
| `placed` | yes | one | yes |
| `inventory` | yes | one | no |
| `recovery_escrow` | yes | one | no |
| transient transactional location | yes | one | only if the transaction's committed side is `placed` |
| `dormant` | no | none | no |

`decay_eligible` is a predicate on a live stone owned by an inactive character.
It is not a canonical state and is not synonymous with `dormant`.

### 5.1 Binding state transitions

| Transition | Stable id and tier | Faction assigned count | Required result |
|---|---|---:|---|
| new issuance → `inventory` or `recovery_escrow` | new id, tier I | +1 | one canonical live item/delivery |
| dormant reissue → `inventory` or `recovery_escrow` | preserved | +1 | no new personal id |
| inventory/escrow → `placed` | preserved | unchanged | protection, reservation, ACL, arrival and placement timestamp committed together |
| `placed` → inventory/escrow recovery | preserved | unchanged | active indexes and Home destination removed before item delivery becomes valid |
| eligible live stone → `dormant` through decay | preserved | −1 | node/item/escrow, indexes, ACL and Home destination invalidated |
| live stone → `dormant` voluntarily | preserved | −1 | same removal and no-archive warning as decay |
| forced recovery → `recovery_escrow` | preserved | unchanged | protection removed, delivery retained |
| forced dormancy → `dormant` | preserved | −1 | all live locations invalidated |
| placed upgrade → `placed` | same id, higher paid tier | unchanged | expanded active cube committed inside existing reservation |

- Each faction has an administrator-configurable maximum number of live Claim
  Stones. A placed, inventory-held, escrow-held or transient live stone
  consumes one slot.
- Voluntary relocation never risks losing its faction slot between recovery
  and placement.
- The exact per-faction limits are selected below demonstrated 32-seed physical
  capacity under §10, not from gross zone area.

### 5.2 Inactivity and on-demand decay

- `grug_housing_inactivity_days` is an integer setting with range 0..3650 and
  default `0`.
- Zero disables inactivity decay. A positive value makes a live stone
  decay-eligible after that many complete real-time days of owner inactivity.
- Changing the setting affects existing claims but does not itself reclaim
  one.
- Owner activity is the character's latest successful login. A successful
  login refreshes the timestamp for every live Claim Stone belonging to that
  character before any issuance request can inspect those records. A returning
  online owner cannot lose a stone during that login.
- Stone interaction is not recurring upkeep.
- Decay is on demand. An eligible stone remains live until an issuance request
  needs and atomically reuses its faction slot.
- Issuance is strictly first come, first served. There is no wait list, offer,
  reservation or priority state.
- If `assigned < limit`, one request atomically consumes a free slot.
- If `assigned == limit`, a request considers every live stone whose owner has
  exceeded the inactivity duration. The transaction makes the oldest eligible
  id dormant and immediately issues the single released slot. Ties use stable
  claim id.
- The requester receives one of their already owned dormant ids when
  applicable; otherwise the transaction creates a new id only if their
  personal quota permits it.
- No stone decays solely because it is old when no request needs the slot.
- If an administrator has lowered the faction limit so `assigned > limit`,
  ordinary issuance pauses and a failed request reclaims nothing. Replacing an
  old live stone would not reduce the overhang.
- Only voluntary dormancy, explicit forced dormancy or a later limit increase
  can reduce or resolve an administrative overhang. Limit changes never revoke
  stones automatically.
- New characters and returning owners of dormant ids follow the same request
  rule and receive no priority over each other.

### 5.3 Steward pool information

Every Housing Steward exposes a read-only interaction-time snapshot for the
visitor's own faction.

- Normal pool line: **“Faction Claim Stones: <assigned> assigned, <free> free
  (<limit> total).”**
- `assigned` counts every live placed, inventory-held and recovery-escrow
  stone. `free = max(0, limit - assigned)`.
- Administrative-overhang line: **“<assigned> assigned, 0 free (configured
  limit <limit>; new issuance paused).”**
- When decay is enabled and `assigned == limit`, the UI also shows
  **“Inactive and currently decay-eligible on request: <count>”.** Eligible
  stones remain assigned and are never shown as free before an atomic issuance.
- During an overhang, the UI explains that issuance is paused and never
  presents eligible stones as obtainable slots.
- Counts create no reservation and expose no owner, position or private claim
  data. Administrator tools may inspect both factions.
- Dates use `YYYY-MM-DD HH:MM server time`.
- A live Claim Stone menu with decay enabled shows: **“Inactivity protection:
  logging in refreshes all your Claim Stones. This claim may become eligible
  for on-demand reclamation after <date/time>.”**
- On first issuance with decay enabled, the Steward also says: **“If you do not
  log in for <days> days, this Claim Stone may be reclaimed when another player
  requests a faction slot. Buildings and inventories are not archived.”**
- If the pool is full and decay is disabled: **“No Claim Stones are currently
  available for the <faction>. Inactivity reclamation is disabled on this
  server.”**
- If decay is enabled but no slot is reclaimable: **“No Claim Stones are
  currently available for the <faction>. The next slot is expected after
  <date/time>, provided its owner does not return first. This creates no
  reservation or waiting-list position.”**
- The estimate is the earliest current `last_owner_activity + decay_duration`.
  It may move when an owner returns or an administrator changes policy.
- Once at least one stone is eligible, the aggregate eligible count replaces
  the future estimate. Only an atomic issuance request decides whether a slot
  remains obtainable.

### 5.4 Decay notice and retained state

- A successful request that reclaims an eligible slot tells its recipient:
  **“An inactive Claim Stone slot was reclaimed and your Claim Stone was
  issued.”**
- The registry persists this one-shot notice for the previous owner:
  **“Your Claim Stone in <zone> at <coordinates> was reclaimed on <date/time>
  after <days> days of inactivity. Its protection and Home Stone destination
  ended. The building remains in the world and was not archived. Your Claim
  Stone retains tier <tier> and may be reissued when a faction slot is
  available.”**
- For an inventory- or escrow-held stone with no active site, `<zone> at
  <coordinates>` becomes **“unplaced”** and the building sentence is omitted.
- The notice is delivered on the previous owner's next login and remains
  available through a Steward until acknowledged.
- Decay operates from canonical registry state whether the stone is placed,
  held in an offline inventory or waiting in escrow.
- Decay removes any placed node, active protection, maximum reservation, ACL
  and Home Stone destination and invalidates/removes the live item or escrow
  delivery.
- There is no schematic, construction, inventory or item-content archive.
- Dormancy retains the owner-bound stable id, paid tier and audit/notification
  record. It retains no live location or claim protection.
- Buildings, ordinary nodes and inventories remain in the world. They
  immediately lose claim-derived ownership and may be edited by any player of
  the owning faction under ordinary home-zone rules. Enemy-faction terrain
  restrictions still apply.
- A later valid Claim Stone placement takes ownership of all ordinary contents
  inside its active volume under §3.

### 5.5 Recovery, voluntary dormancy and administration

- Voluntary recovery moves only the Claim Stone. Buildings, nodes and
  inventory contents remain where they are.
- Recovery requires an explicit confirmation warning that all remaining
  construction and inventory contents immediately lose claim protection and
  claim-derived ownership.
- Recovery atomically removes protection, reservation and Home destination
  only after the persistent unplaced-live record and returned-stone state are
  safe.
- If the inventory cannot accept a recovered stone, it enters persistent
  recovery escrow. It never becomes a dropped item and is not lost.
- Voluntary dormancy is a separate explicitly confirmed action available
  through a Housing Steward and a placed Claim Stone.
- A placed stone may enter voluntary dormancy only after its current four-hour
  binding expires. An administrator may force dormancy at any time.
- Voluntary or forced dormancy removes the live node, item or escrow delivery,
  protection, reservation, ACL and Home destination. It applies the same
  no-archive warning as recovery, retains stable id/owner/tier, and releases
  exactly one faction slot.
- Dormancy does not reduce the owner's personal stable-id count. Reissue is
  free, preserves paid tier and competes first come, first served for a faction
  slot.
- Released construction remains unclaimed. Another eligible character may
  claim it later, subject to the complete placement rules.
- Administrators have inspect, index-rebuild, forced-recovery,
  forced-dormancy and stone-recovery tools. Every forced operation is
  audit-logged and never deletes buildings or inventories.
- Forced recovery preserves the faction slot and puts the stable id/tier into
  recovery escrow. Forced dormancy preserves the stable id/tier as slot-free
  progression.
- Recovery escrow is canonical claim-registry state exposed on the owner's
  next login and through Housing Stewards. Delivery is idempotent across
  crashes.

## 6. Housing eligibility and exclusions

`housing_eligible_at(x, z)` is the authored positive housing mask within the
six level-11–20 and four level-21–30 housing zones, minus every deterministic
exclusion corridor and envelope. The complete future radius-50 footprint—not
only its centre or corners—must pass the rule.

A reservation may never intersect:

- another owner's maximum x/z reservation plus the ten-node separation,
  regardless of either stone's y;
- a non-housing zone or a contested/peaceful boundary;
- a capital, starting settlement or another hard-protected civic area;
- a village, outpost, camp or other authored POI exclusion envelope;
- a road, bridge, waypoint, graveyard, quest, travel or sight-line corridor;
- a reserved candidate envelope for a dynamic POI that mapgen has not placed;
- a planned bay, lake, river or other zone-water mask;
- the exterior 80-node coastal shelf or deep ocean.

Roads and ordinary POIs may be mutable while remaining claim-excluded.
Protection and claim eligibility are independent systems.

- There is no general runtime slope test. Outside the four guaranteed gentle
  cores, players may claim steep or unusual ground when the complete
  reservation passes every authored mask and exclusion.
- The gentle-core relief limit is audited against mapgen's natural
  surface-height field over 32 seeds and is not recomputed at placement.
- Road exclusions use exactly the world plan's three fixed classes: a 7-node
  primary road in a 16-node total corridor, a 5-node secondary road in a
  12-node corridor, and a 3-node trail in an 8-node corridor.
- Deterministic road meanders move the analytic corridor with the road.
  Removing or rebuilding visible road nodes never removes the exclusion.

### 6.1 Boundary visibility

- Claim boundaries are never permanent world nodes, luminous walls or
  always-on effects.
- Crossing into or out of a claim briefly shows that claim's active boundary
  to the crossing player only.
- A denied dig, placement or use triggers the same visualization immediately
  and identifies the owner.
- The visualization is a sparse, low-intensity outline of the relevant cube
  edges, visible for only a few seconds. It remains legible underground and
  uses bounded client-scoped particles or equivalent transient markers, never
  persistent entities or nodes.
- Repeated crossings and denied actions are throttled per player and claim.
- The owner and trusted characters may request a temporary full outline from
  Claim Stone interaction or a housing inspection action.
- Placement preview distinguishes the current active cube from the reserved
  radius-50 horizontal footprint and leaves neither visible afterward.

### 6.2 Natural mob spawning

- Every natural mob spawn candidate inside an active protection cube is
  rejected, including hostiles, passive prey and critters.
- The unused part of a radius-50 future reservation remains ordinary spawn
  ground until an upgrade expands the active cube into it.
- Spawn checks query only the active-claim index. They scan neither world nodes
  nor maximum reservations and add no claim-spawn globalstep.
- Claims do not despawn, repel, pacify or block existing mobs. Creatures
  spawned outside may enter, pursue and fight inside a claim. An upgrade does
  not remove creatures already standing in the enlarged volume.
- Claims control natural spawning; they are not combat sanctuaries.

### 6.3 Growth across a boundary

- Crops, saplings, bamboo and other player-grown content may grow naturally
  from an active claim into unprotected surroundings. Growth does not wait for
  a higher tier and is not clipped at the active or maximum-reservation edge.
- Ownership remains point-based after growth. Resulting nodes inside the active
  cube belong to the claim; nodes outside are ordinary world content and may be
  altered by anyone allowed by outer faction and zone rules.
- The ten empty nodes required between different owners' reservations are also
  the authored horizontal growth buffer.
- Every ordinary player-growable structure intended for housing has a maximum
  horizontal reach of ten nodes from its planted/source position over every
  variant.
- The farming/content asset gate enumerates every shipped crop, sapling,
  bamboo and other player-growable template and rejects any variant exceeding
  that ten-node horizontal reach.
- A future exceptional growable larger than ten nodes requires its own
  cross-claim rule.

### 6.4 Indirect mutation protection

- An active claim protects its nodes, metadata, inventories and functional
  state from every destructive, replacing or intrusive mutation path.
- Direct digging and placement, explosions, fire, liquids, falling-node
  placement, terrain-changing mobs, machines and scripted world effects all
  obey the same ACL.
- A mutation is allowed only when its complete causal action carries an
  authenticated owner, trusted character or administrator permitted by every
  covering claim.
- Attribution fails closed. Ambient and unattributed effects cannot alter
  protected state. An effect gains no permission merely because it began
  outside a claim.
- Player-authorized destructive effects may act inside that player's claim
  only when attribution survives to the final per-node mutation. A subsystem
  that cannot preserve attribution leaves the protected nodes unchanged.
- Engine liquid flow into air exposes only the after-change
  `register_on_liquid_transformed` callback; `on_flood` is not called for air
  (`reference_projects/luanti/doc/lua_api.md:6774-6779` and
  `:11009-11016`). The implementation restores affected protected nodes or
  suppresses automatic liquid transformation there. A player-placed liquid
  source remains ordinary direct placement governed by the ACL.
- Benign growth under §6.3 may advance stages and add ordinary growth nodes.
  It grants no general destructive-replacement permission.
- Normal operation of an owner-accessible workstation may alter its own
  inventory and metadata.
- Protection governs world state, not combat. Mobs and hostile effects may
  enter and damage eligible players inside claims but cannot alter claimed
  terrain.

### 6.5 Build palette and private functional content

- Housing has no race-, faction-, zone-, biome- or material-tier placement
  palette. An owner or trusted character may place every ordinary block they
  legitimately possess when general world rules and claim geometry permit it.
- Foreign cultural materials are valid building materials.
- Claim permission never overrides immutable content, the arrival column,
  depth rules or another outer restriction. The free palette is not a system
  bypass.
- Race build sets and regional materials are optional cosmetic goals, never a
  style score or construction requirement.
- Cooking crops and the universal spice line may be grown inside active claims.
- Healing herbs, race/culture materials, ores and the found-only cooking
  ingredients—mushrooms, wild cocoa and rock salt—are never cultivated by
  housing.
- Ordinary saplings, bamboo and decorative or mundane useful plants are
  allowed and follow §6.3.
- No claim-specific livestock, breeding or stable system exists. Animal
  husbandry requires a separate design.
- Ordinary workstations, cooking stations, doors and unsealed inventories use
  §3's owner/trusted ACL. They grant no recipe, profession, service-NPC or
  material-progression entitlement.
- The authoritative gathering and crop classifications remain in
  [Biomes & Mobs](biomes_mobs.md) §2.

## 7. World mutability boundaries

### 7.1 Hard-protected world content

The following bounded content remains reproducible and cannot be changed by
players in its shallow protection volume:

- full race capitals, their gates and narrow aprons;
- starting and respawn cores;
- waypoints and graveyards;
- essential service and quest-giver platforms;
- small functional NPC spawn/return anchors;
- renewable mining sockets and other bounded renewable-resource mechanisms;
- critical bridges or gates with no adequate alternate route;
- the Holy Grounds from the surface through y = −700.

- Every land-side hard-protected footprint extends upward without limit and
  downward through y = −700 inclusive.
- Its x/z extent is the bounded authored core, apron or functional anchor,
  never the ordinary shell of a whole road, village or camp.
- An essential service NPC on such a platform is passive and invulnerable.
- The universal editable T5/T6 land rule resumes at y = −701 and overrides
  shallow land protection.

### 7.2 Mutable but claim-excluded world content

The following content is generated once and may be damaged, dug or rebuilt,
but its authored envelope can never be privatized:

- ordinary roads and their travel corridors;
- villages outside small functional cores;
- ordinary outposts, bandit or Mirefolk camps and war camps outside their
  functional anchors;
- ruins, tents, fences, decorative fortifications and battlefield dressing;
- terrain surrounding quest and NPC platforms.

- Destruction of this layer persists; it is not structurally regenerated.
- A reproducible gameplay loop attaches to a small protected functional
  anchor, not a destructible wall, tent or road node.
- Only a bridge or gate without an adequate alternate route is promoted to
  hard protection. A bridge or gate is not immutable by type alone.

### 7.3 Mutable and claimable ground

Ordinary terrain inside the positive housing mask is freely reshapeable and
may receive a Claim Stone when its complete future reservation passes §6.

## 8. Runtime and persistence contract

Protector Redo's fixed-radius `core.find_nodes_in_area` scan is not used for
per-stone radii up to 50 or the project's 100-player target.

- Canonical claim and POI records are persisted and mirrored into spatial
  indexes. Luanti `AreaStore` is the preferred implementation for 3D cuboids
  and points (`reference_projects/luanti/doc/lua_api.md:8422-8464`); a
  mapblock-bucket index is used only if profiling shows unacceptable allocation
  overhead.
- At least three logical indexes exist: active hard/claim protection volumes,
  maximum claim reservations, and claim-exclusion envelopes/corridors.
- Active protection uses real 3D cubes.
- The maximum-reservation index stores each x/z radius-50 footprint as a
  degenerate cuboid at y = 0. Every reservation query is projected to y = 0.
- Placement queries the candidate radius-60 x/z AABB at y = 0 against other
  owners' stored radius-50 degenerate AABBs. Same-owner reservations bypass
  only this pairwise spacing check.
- Dig, place and use attempts perform point queries and never scan surrounding
  world nodes or run a protection globalstep.
- Natural-spawn candidates perform point queries against the active-claim
  index only.
- One central claim-mutation predicate handles direct and indirect node/state
  changes. Every game-owned explosion, fire, machine, mob terrain action and
  scripted bulk write invokes it for affected claim regions. `core.set_node`,
  schematic placement and VoxelManip are never protection bypasses.
- Claim placement performs one reservation/exclusion intersection query plus
  exact validation of every point in the 101×101 housing mask. This rare
  operation may do more work than hot point queries.
- Roads and future POI slots register deterministic exclusion envelopes before
  claims are possible nearby.
- If mapgen selects among terrain-dependent POI candidates, every candidate
  remains inside a pre-reserved envelope. The winning small functional core is
  registered when its final position is persisted.
- `AreaStore` is not persistence. Canonical records live in mod storage. All
  indexes rebuild on load and update transactionally on placement, upgrade,
  recovery, dormancy, reissue and forced operations.

### 8.1 Generation and stale-copy safety

- Every canonical stable id stores a monotonically increasing registry
  generation.
- Each authorized live ItemStack mirrors stable id and current generation. The
  registry also stores the one canonical live location.
- Decay, voluntary dormancy, forced dormancy and reissue increment the
  generation before a replacement stack can become valid.
- Inventory use, placement, login reconciliation and escrow delivery reject
  and remove a Stack whose id, generation or canonical location does not match.
- An offline Stack can be invalidated immediately in registry state and
  removed lazily on owner login. It cannot restore protection, clone a slot or
  revive a dormant id.
- The record persists the latest successful placement wall-clock timestamp.
- Recovery removes active indexes and the Home destination atomically before
  returning a valid bound item. Placement creates the destination and new
  binding timestamp atomically.
- Transaction tests cover every lifecycle edge:
  - placed↔inventory/escrow recovery preserves assigned count;
  - live→dormant releases exactly one slot;
  - dormant→live consumes exactly one slot without creating a personal id;
  - full-pool decay plus issuance leaves assigned count unchanged;
  - `assigned > limit` performs neither decay nor issuance;
  - stale generations never create a second live location.
- The implementation retains `protection_bypass`, protection-violation
  callbacks, owner/member area visualization and administrative cleanup.

## 9. Fixed world-scale dependencies

- The authored mainland frame is x = −2,600..+2,600 and
  z = −3,000..+3,000. It bounds mainland authoring, not the generated world.
- The Holy Grounds is x = −2,500..+2,500 and z = −250..+250. Its four-zone
  internal ownership follows the fixed Holy hubs and integer power rule in
  `world_zones.md` §§7.1/7.3. It is hard-protected through y = −700; universal
  contested depth resumes at y = −701.
- Dragon-island centres are (−3,150, 0) and (+3,150, 0), each inside a fixed
  600×700 envelope. Their channels retain at least 200 ocean nodes, 48-node
  flight-warning bands on both shores and at least 104 hard no-flight nodes.
  The channel columns are immutable at every depth.
- Authored lakes, rivers, zone-water masks and the landward parts of bays
  remain zone-classified and claim-ineligible even if filled or drained. The
  four declared outer bay-mouth caps are ownerless deep ocean and likewise
  claim-ineligible.
- The editable nominal shelf is exactly
  `expanded_land_at(80) and not land_at`; deep ocean beyond it is immutable at
  every depth. Dragon-channel masks override the shelf.
- The Copperfell, Starbough, Mournfen and Raincall coastal-core records each
  reference their corresponding fixed 600-by-300 landmark geometry. They do
  not depend on a materialized perimeter or zone boundary.
- Kragmar capital centres are (−1,800, +1,500), (0, +1,500) and
  (+1,800, +1,500). Elandor capital centres are (−1,800, −1,500),
  (0, −1,500) and (+1,800, −1,500). Surface y is terrain-derived.
- Kragmar starting/respawn centres use the same x coordinates at z = +2,550;
  Elandor uses z = −2,550. These fixed anchors remain inside the six
  claim-free level-1–10 zones.
- Road authoring and mount balance promise no capital-to-capital duration.
  Roads follow legible geography and are never lengthened artificially to
  manufacture travel time.

## 10. Capacity and calibration requirements

- Housing capacity is a two-dimensional packing problem. Different owners
  cannot stack claims vertically.
- A regular maximum-claim packing consumes approximately 111×111 horizontal
  nodes per claim before roads, POIs, water, boundaries and organic placement
  loss.
- Each faction has five housing zones. The ten-zone supply replaces the former
  four-zone working scope and the former 150-claims-per-faction suggestion is
  not a target.
- The per-faction live-Stone defaults are selected below measured physical
  capacity. They bound permanent occupancy and create a soft availability
  incentive without directly balancing active PvP population.
- The two-dimensional capacity audit runs once per accepted fixed layout and
  uses final housing-centre masks, real exclusion masks and the canonical
  portfolio of lattice, greedy, row-major/reverse, edge-biased and 16
  hash-order placement sequences. Gross area alone is not a capacity result.
  Varying-seed height/content conformance is a separate audit and never
  recomputes the horizontal mask or packing portfolio.
- The fixed-layout capacity audit may not enlarge the fixed mainland frame to
  satisfy a quota.
- For each guaranteed coastal core, the fixed layout proves at least 600
  continuous shoreline nodes and 300 usable inland nodes after static
  exclusions.
- The varying-seed height/content audit slides the complete 101×101 reservation
  over every guaranteed core and proves no more than 12 nodes of natural-ground
  relief and no forced cliff, ravine, river, lake or coastal-shelf intersection.
- Coastal geometry minima do not replace the packing simulation.
- Revised T4, T5 and T6 reliable net-income measurements convert the fixed
  30-minute, 90-minute, 3-hour, 5-hour and 10-hour targets into ledger copper
  values using §2's fixed rounding algorithm.
