# TODO — Open-world housing claims

**Status:** design complete, pending coordinated integration and measured
calibration outputs; updated 2026-08-12. The private housing isles and the
complete guild system are retired. This file stages the decided replacement
until an integration pass folds it into `docs/design/`, ROADMAP and BACKLOG.
Do not implement from the obsolete island rules that remain elsewhere in the
repository.

## 1. Confirmed direction

- Housing is an open-world, per-character land claim represented by a placed
  **Claim Stone**. Its interaction model may adapt the MIT-licensed
  `reference_projects/protector/` ownership, member, visualization and admin
  patterns, pinned at commit `60d2280`.
- Claims may be placed freely only on authored housing-eligible ground in ten
  peaceful level-11–30 home zones. The six level-11–20 zones are Copperfell
  Foothills, Goldmead Vale, Starbough Vale, Mournfen, Redtusk Savanna and
  Raincall Basin; the four level-21–30 inter-capital zones are Whitebridge
  Shire, Lorindor, Speargrass Reach and Whispering Reedlands.
- Four of those zones have guaranteed coastal alternatives: Copperfell
  Foothills and Mournfen on the west coasts, Starbough Vale and Raincall Basin
  on the east coasts. Each receives a continuous gently buildable dry-land
  housing strip. After final coastline variation and all static exclusions,
  each strip retains at least 600 continuous nodes of shoreline frontage and
  300 nodes of buildable inland depth. The strip may curve and taper with the
  natural coast; these dimensions are an implementation/audit minimum, not a
  visible rectangle or a guaranteed Claim-Stone quota. Every possible 101×101
  reservation wholly inside the guaranteed core has at most 12 nodes of
  generated natural-ground height variation and no forced cliff, ravine, river
  or lake. Trees, structures and later player edits do not count as ground
  relief. A complete 101×101 reservation may meet the final shoreline but may
  not contain any coastal-shelf column; protected underwater claims and
  private harbors are outside the model.
- The six level-1–10 starting zones remain completely claim-free. The first
  Claim Stone still unlocks at level 20: new players encounter established
  homes while travelling through level-11–20 land, but cannot place their own
  stone early.
- The MVP quota is one Claim Stone per character. The registry, persistence,
  UI and permission model must support a later quota greater than one without
  a data migration.
- Permanent player-owned protection exists only inside an active Claim Stone
  volume. Building elsewhere follows the ordinary faction/contested terrain
  rules and is not private property.
- A successful placement binds the stone for four hours of real wall-clock
  time. Offline time and server downtime count. The persisted placement
  timestamp is recorded with `os.time()`; every later relocation starts a new
  four-hour binding, while an upgrade does not reset it.
- Before the binding expires only an administrator may remove the stone. After
  expiry, its owner may recover it through the stone's controlled interaction
  menu and place it elsewhere. Recovery immediately deactivates the claim and
  its Home Stone destination; no stale teleport remains while the Claim Stone
  is an inventory item.
- The two nodes directly above the Claim Stone are a permanent reserved
  arrival column. Players, including the owner and trusted characters, may not
  place nodes, torches or liquids there. The Home Stone returns the owner to
  this clear standing/head space.
- Player-owned profession workstations are permitted in a valid claim, but
  public stations and passive helper NPCs remain available. Housing is never a
  mandatory material-progression gate.
- Traders, trainers, Housing Stewards and all other service or quest NPCs are
  world-owned content. Players cannot place, move, bind or transfer them into
  claim ownership; private doors, ordinary workstations and unsealed
  inventories instead use the claim ACL in §3.

## 2. Claim tiers and future reservation

The Claim Stone is the centre of its protected area.

| Claim tier | Required character level | Active horizontal radius | Active footprint |
|---|---:|---:|---:|
| I | 20 | 20 | 41 × 41 |
| II | 35 | 30 | 61 × 61 |
| III | 50 | 40 | 81 × 81 |
| IV | 60 | 50 | 101 × 101 |

- The active protection volume is a cube centred on the Claim Stone. Its x, y
  and z radius always equals the current tier radius: 41³, 61³, 81³ and 101³
  nodes for tiers I–IV respectively. Vertical protection therefore grows with
  the same visible progression as horizontal build space.
- Tier is permanent state of the individual Claim Stone, not a character-wide
  housing licence. Every stone has a stable claim id, owner and tier in the
  canonical claim record and mirrored item/node metadata. Recovering and
  moving it preserves all three; a later additional stone starts at tier I and
  is upgraded independently.
- A placed stone exposes its own transactional upgrade action. The upgrade
  checks the required character level and consumes the final authored Gold
  and/or material cost before increasing that stone's radius. It never replaces
  the stable claim id or ownership and cannot invalidate the already reserved
  radius-50 footprint.
- Claim Stones are owner-bound and non-tradeable. Another character may not
  place, recover or upgrade one to bypass the level, quota or price gates.
- At character level 20, a short housing-introduction quest from a passive,
  invulnerable Housing Steward unlocks the character's first owner-bound Claim
  Stone. Every capital has such a steward. If the faction pool has no available
  or reclaimable slot, the steward creates no uncounted stone and tells the
  character to try again later. This essential service is deliberately
  independent of the killable king and his guards.
- The first stone entitlement is free when the level-20 introduction quest is
  completed; the player requests its issuance from a Housing Steward whenever
  a faction slot is available. Each later step combines ledger money with one
  universal progression metal:

  | Upgrade | Required level | Material cost | Money target |
  |---|---:|---:|---:|
  | tier I → II, radius 20 → 30 | 35 | 4 Silversteel Bars | 30 minutes of reliable T4 net solo income |
  | tier II → III, radius 30 → 40 | 50 | 8 Embersteel Bars | 90 minutes of reliable T5 net solo income |
  | tier III → IV, radius 40 → 50 | 60 | 12 Abyssal Steel Bars | 3 hours of reliable T6 net solo income |

  Reliable net income is measured after routine level-appropriate repairs and
  consumables and excludes rare jackpots, world-boss rewards and player trade.
  Once those three tier rates are measured, each raw copper target is rounded
  with the coarsest denomination in `1s / 25c / 5c / 1c` whose nearest multiple
  stays within 5% of the target; an exact midpoint rounds upward. The resulting
  three ledger prices are calibration outputs, not another design choice.
- Upgrades are sequential and performed only through the placed stone's own
  interaction. The server revalidates level, owner, current tier, complete
  money balance and exact material stacks, then consumes money and bars in one
  atomic transaction before committing the new tier. Failure consumes nothing.
  No profession is required, and there is no downgrade or refund. Paid tier
  progression survives recovery, relocation, inactivity decay and later
  reissuance through the stone's stable id.
- Claim upgrades never require gems, culture materials, foreign-faction
  materials or profession-exclusive components. Housing therefore remains
  faction-neutral and does not compete directly with the authored gem and
  cultural-material gear paths.
- Placement of even a tier-I stone immediately reserves the complete future
  tier-IV footprint. The whole 101 × 101 area must be housing-eligible, so a
  later paid upgrade can never be blocked by a newly placed neighbour or a
  world-content boundary.
- Maximum-reservation overlap is a two-dimensional x/z rule, independent of
  Claim Stone height. Two different owners may never have overlapping projected
  101 × 101 reservation footprints even when their active protection cubes are
  vertically disjoint; one player can therefore never build a second home
  above or below another player's home.
- Different owners' projected maximum reservations require at least ten
  completely unclaimed horizontal nodes between their edges. For two tier-IV
  reservations on the critical axis this means their centres differ by at
  least 111 nodes at every y. The exact pair predicate is an inclusive x/z AABB
  test: expand the **candidate** radius-50 reservation by ten nodes on all four
  sides and reject it if that expanded box intersects any other owner's stored
  radius-50 box. Do not expand both boxes; doing so would accidentally require
  a 20-node gap. This Chebyshev/AABB rule applies at corners as well as along a
  cardinal axis and is not a Euclidean centre-distance test.
- Multiple stones belonging to the same owner may touch or overlap. The access
  intersection rule in §3 governs the overlap; each stone still consumes its
  own faction slot and overlapping them creates no additional land capacity.
- `grug_housing_max_claims_per_character` is an integer setting with range 1..3
  and default **1**. It counts every stable Claim-Stone id owned by the
  character, including a dormant id retained after inactivity decay or
  voluntary dormancy; neither operation can therefore evade the personal
  limit. The
  default is the MVP's one-Stone rule, while the registry, UI and transactions
  support later values 2 or 3 without migration.
- A second or third owner-bound Claim Stone can be issued only at level 60,
  only when every already owned stone is tier IV, and only when the same atomic
  transaction obtains a faction slot. The second costs **12 Abyssal Steel Bars
  plus 5 hours of measured reliable T6 net solo income**; the third costs **24
  Abyssal Steel Bars plus 10 hours**. Their ledger prices use §2's same
  coarsest-denomination/5% rounding rule. No available or reclaimable faction
  slot means no money or material is consumed.
- Each additional purchase creates a new stable id at tier I. It is upgraded,
  placed, recovered, decayed and reissued independently; its one-time purchase
  is not refunded or charged again after decay. First come, first served still
  applies, with no reservation or priority for an additional stone. Lowering
  the personal setting grandfathers every existing id and never revokes one.
  Reissuing an existing dormant id remains legal; only creation of another
  stable id is blocked while the character already owns at least the configured
  number. A lowered setting therefore need not force permanent progression
  deletion merely to make the character numerically compliant.
- Claim placement depth is bounded by the T1 pick's natural-depth limit minus
  the maximum possible effect radius. With the confirmed T1 limit at y = −100
  and maximum radius 50, a Claim Stone may not be placed below y = −50. This
  guarantees that no possible claim volume reaches below the T1 layer.
- At y = −701 and below, the universal contested T5/T6 terrain rule overrides
  every claim: both factions may dig and place, and the deep layer is always
  PvP-contested. The deep-ocean exception remains immutable at every depth.

## 3. Claim ownership and access

- Every Claim Stone has exactly one owner. The MVP has no co-ownership, and
  only the owner may upgrade, recover or relocate the stone or edit its trusted
  list.
- A claim accepts at most ten trusted characters, all from the owner's faction.
  Trust is one deliberately simple permission rather than a per-action matrix:
  it permits digging, placement and use of ordinary doors, workstations and
  unsealed inventories inside the active claim.
- Removing a character from the trusted list revokes those permissions
  immediately. Other characters may still walk through the claim; owners use
  walls and doors when they want to restrict physical access.
- Claim permission never overrides a world, faction, immutable-content, depth
  or PvP rule. Every applicable outer rule must permit the operation before the
  claim ACL is evaluated.
- At a point covered by multiple claims, a non-owner must be trusted by every
  covering claim: denial wins. Because different owners' reservations cannot
  overlap, this rule concerns only multiple stones belonging to one owner. The
  owner is permitted by all of their own claims.
- The active Claim Stone determines ownership of ordinary blocks, inventories
  and functional nodes within its volume, regardless of which trusted
  character placed them. A trusted builder receives revocable access, never
  ownership. Implementations should resolve this from the claim registry
  rather than writing the placer as a competing owner into every node.
- The MVP defines no separately owned or personally locked chest inside a
  claim. If a later container needs its own owner or ACL, that exception must
  receive a separate design and compatibility rule; it must not silently
  inherit a generic placer-owned convention.

## 4. Home Stone

- The housing-bound Home Stone completely replaces the obsolete race-capital
  destination. It teleports only to the owner's currently bound, active Claim
  Stone and has no automatic capital fallback. Without an active home claim,
  the item is disabled and explains why it cannot be used.
- Player state stores a stable `home_claim_id`, never only a raw position. The
  first successfully placed stone binds automatically. The data model supports
  multiple later claims: rebinding then requires physical interaction with the
  target Claim Stone. Recovering the bound stone makes its destination
  inactive without leaving a stale position; re-placing that same stable claim
  id makes the moved destination valid again.
- Use is a ten-second stationary channel. It may not begin while
  `grug_core.in_combat(player)` is true. The server stores the cast-start
  position; displacement greater than **0.1 nodes** interrupts, while camera
  rotation and sub-threshold engine correction do not. Logout and death also
  interrupt.
- PvP interruption uses `world_zones.md` §15's events rather than only HP loss.
  A server-valid hostile attempt or effective support action performed by the
  channeling player interrupts them even if the safe→safe hostile effect is
  blocked. Accepted hostile damage that lowers the channeler's HP or consumes
  absorb, and effective support received by the channeler, also interrupt.
  Misses, dodge, immunity, eligibility refusal, failed/zero-effect support and
  the PvP tag by itself do not. The tag alone cannot prohibit the channel
  because contested zones force it permanently; the combat gate, exposed cast
  and qualifying action/effect interruptions are the anti-escape rules there.
- The 60-minute cooldown begins only after a successful teleport and uses
  persisted real wall-clock time, so offline time counts. An interrupted cast,
  unavailable claim or technical failure consumes no cooldown.
- Before the channel starts, the server loads or emerges the destination and
  validates the claim, stone and reserved arrival column. It validates them
  again at completion. A load failure or invalidated claim fails safely with a
  message and no cooldown.
- Arrival is at the standing node directly above the Claim Stone; the second
  reserved node is headroom. Temporary player or mob overlap does not block
  arrival and therefore cannot be used to grief the owner. The permanent node,
  torch and liquid exclusion keeps the physical destination clear.
- WP17 must replace its race-capital Home Stone with this claim-bound flow.
  WP21's Innkeeper may retain its recovery/rest services but loses all Home
  Stone rebinding responsibility. The old capital destination in `world.md`,
  ROADMAP and related design summaries is obsolete pending integration.

## 5. Recovery, retention and administration

- The canonical registry distinguishes four live locations and one slot-free
  state: `placed`, `inventory`, `recovery_escrow` and any transient
  transactional location are **live** and consume one faction slot;
  `dormant` retains only the stable id, owner, paid tier and audit/notification
  state and consumes no faction slot. **Decay-eligible** is a predicate on an
  inactive owner's live stone, not another state and not a synonym for
  dormant. The registry, never a world node or ItemStack, is authoritative.
- Each faction has an administrator-configurable maximum number of live Claim
  Stones. A live stone consumes one faction slot whether it is placed, held in
  inventory or waiting in recovery escrow; voluntary relocation therefore
  never risks losing the slot halfway through a move. The exact limits are
  selected below the measured 32-seed physical capacity, not guessed from
  gross zone area.
- The integer setting `grug_housing_inactivity_days` controls inactivity decay
  in whole real-time days, has range 0..3650 and defaults to **0**. Zero
  disables decay; a positive value makes a stone eligible for on-demand
  reclamation after that many complete days. Changing the setting affects
  existing claims but does not itself reclaim one. Owner activity is the
  character's latest successful login and refreshes the timestamp for every
  live Claim Stone belonging to that character **before** any issuance request
  can inspect it. A returning online owner therefore cannot lose a stone during
  that login. Interacting with a stone is not a recurring upkeep chore.
- Claim issuance is strictly first come, first served. There is no wait list,
  offer, reservation or priority state. An eligible character asks a Housing
  Steward; if a faction slot is free, that single request atomically consumes
  it. If no slot is currently obtainable, the request fails without changing
  state and the character may try again later.
- When `assigned == limit`, a request considers every live stone whose owner
  has exceeded the configured inactivity duration. The same transaction makes
  the oldest eligible id dormant and immediately issues that one released slot
  to the requester; ties use the stable claim id. The requester receives an
  already owned dormant id when applicable, otherwise a newly created id if
  their personal limit permits it. A stone does not decay merely because it is
  old when nobody requests the slot.
- When an administrator has lowered the faction limit so that `assigned >
  limit`, ordinary issuance is paused and a failed player request reclaims
  nobody: replacing one old live stone with another would preserve the illegal
  overhang while removing another player's protection for no attainable slot.
  Only voluntary dormancy, an administrator's explicit forced-dormancy action
  or a later limit increase can reduce or resolve this overhang. Limit changes
  never revoke stones automatically.
- New characters and returning owners of decayed stones follow exactly the
  same request rule and receive no priority over each other.
- Every Housing Steward exposes an exact, read-only snapshot of its visitor's
  own faction pool: **“Faction Claim Stones: <assigned> assigned, <free> free
  (<limit> total).”** `assigned` counts every live placed, inventory-held and
  recovery-escrow stone; `free = max(0, limit - assigned)`. If an administrator
  lowered the limit below current usage, the line instead reads **“<assigned>
  assigned, 0 free (configured limit <limit>; new issuance paused).”** The UI
  also shows **“Inactive and currently decay-eligible on request: <count>”**
  when decay is enabled and `assigned == limit`. Those stones remain live and
  part of `assigned`, never `free`, until an atomic issuance actually makes one
  dormant and transfers its slot. During an administrative overhang the UI
  instead explains that issuance is paused and does not present eligible
  stones as obtainable slots. Counts are an
  interaction-time snapshot, create no reservation and reveal no owner name,
  position or other private claim data. Administrator tools may inspect both
  factions; an ordinary Steward view exposes only the player's faction.
- Dates use the unambiguous format `YYYY-MM-DD HH:MM server time`. The Claim
  Stone menu shows: **“Inactivity protection: logging in refreshes all your
  Claim Stones. This claim may become eligible for on-demand reclamation after
  <date/time>.”** On first issuance with decay enabled, the Steward additionally
  says: **“If you do not log in for <days> days, this Claim Stone may be
  reclaimed when another player requests a faction slot. Buildings and
  inventories are not archived.”**
- When the pool is full and decay is disabled, the Steward says: **“No Claim
  Stones are currently available for the <faction>. Inactivity reclamation is
  disabled on this server.”** When decay is enabled but no slot is currently
  reclaimable, it says: **“No Claim Stones are currently available for the
  <faction>. The next slot is expected after <date/time>, provided its owner
  does not return first. This creates no reservation or waiting-list
  position.”** The estimate is the earliest current
  `last_owner_activity + decay_duration`; it may move when an owner returns or
  an administrator changes the policy. Once at least one claim is eligible,
  the aggregate count above replaces the future estimate; only an atomic
  issuance request decides whether it remains obtainable.
- A request that makes the oldest eligible stone dormant and succeeds tells the
  new owner: **“An inactive Claim Stone slot was reclaimed and your Claim Stone
  was issued.”** The registry persists a one-shot notice for the previous owner:
  **“Your Claim Stone in <zone> at <coordinates> was reclaimed on <date/time>
  after <days> days of inactivity. Its protection and Home Stone destination
  ended. The building remains in the world and was not archived. Your Claim
  Stone retains tier <tier> and may be reissued when a faction slot is
  available.”** For an inventory- or escrow-held stone with no active site,
  `<zone> at <coordinates>` is replaced by **“unplaced”**, and the building
  sentence is omitted. The notice is delivered on that owner's next login and
  remains available through the Steward until acknowledged.
- Decay works from canonical registry state whether the live stone is placed,
  held in an offline inventory or waiting in recovery escrow. It removes any
  placed node, active protection, maximum reservation, ACL and Home Stone
  destination and invalidates/removes the live item or escrow delivery. There
  is no schematic, construction or inventory archive and no item-content
  transfer. The only retained dormant **progression** state is the owner-bound
  stone's stable id and paid tier, plus its audit/notification record; a
  returning owner can receive that same progression again on a later
  successful first-come-first-served request.
- Every remaining building, ordinary node and inventory stays in the world at
  its existing position. It immediately loses claim-derived ownership and is
  diggable under the ordinary peaceful home-zone rules by any player of the
  owning faction; enemy-faction players still cannot alter that friendly
  territory. A later valid Claim Stone placement takes ownership of all
  remaining ordinary contents inside its volume under §3.
- Voluntary recovery moves only the bound Claim Stone, retaining its stable id,
  owner and individual tier. Buildings, placed nodes and inventory contents
  remain exactly where they are; housing is not a portable schematic.
- The recovery UI requires an explicit warning confirmation that all remaining
  construction and inventory contents immediately lose claim protection and
  claim-derived ownership. The player is expected to dismantle and empty
  anything they want to keep before moving.
- Recovery atomically removes the active protection, reservation and Home
  destination only after the persistent unplaced-live claim record and returned
  stone state are safe. It remains a slot-preserving relocation operation, not
  a way to reduce faction occupancy. If the player's inventory cannot accept
  the stone, it goes to the persistent recovery escrow rather than becoming a
  dropped item or being lost.
- **Voluntary dormancy** is a separate, explicitly confirmed action available
  through the Housing Steward and a placed Stone's interaction. A placed stone
  may enter it only after the current four-hour relocation binding has expired;
  an administrator may force it at any time. The transaction removes the live
  node/item/escrow delivery, protection, reservation, ACL and Home destination,
  applies the same no-archive warning as recovery, retains stable id/owner/tier
  as dormant and releases exactly one faction slot. It does not reduce the
  owner's personal stable-id count. Reissuing that id later is free, preserves
  its tier and competes first come, first served for a faction slot.
- Released terrain and its surviving construction become unclaimed. Another
  eligible player may subsequently place a valid Claim Stone there, at which
  point that new active claim becomes the owner under §3.
- Administrators receive inspect, index-rebuild, forced-recovery,
  forced-dormancy and stone-recovery tools. Every forced operation is
  audit-logged and never deletes buildings or inventories. Forced recovery
  preserves the faction slot and places the id/tier into recovery escrow;
  forced dormancy preserves the id/tier as slot-free dormant progression.
- Recovery escrow is claim-registry state exposed on the owner's next login and
  through the Housing Steward. Delivery is idempotent so a crash cannot clone
  or lose a Claim Stone.
- Changing a faction limit never revokes an active stone merely because the
  new limit is lower. While `assigned > limit`, new issuance pauses until
  voluntary dormancy, explicit forced dormancy or a later limit increase makes
  the pool valid again. Recovery and ordinary full-pool decay/reissue do not
  reduce occupancy and therefore cannot resolve an administrative overhang.

## 6. Housing eligibility and exclusion

Level range alone is not sufficient. `housing_eligible_at(x, z)` is the
authored housing mask inside the six level-11–20 and four level-21–30 home
zones, minus every exclusion corridor or envelope. The entire future
radius-50 footprint, not just its centre or corners, must pass this rule.

Claims may never intersect:

- another owner's projected x/z maximum reservation plus its ten-node
  separation, regardless of either stone's y position;
- a non-housing zone or a contested/peaceful boundary;
- a capital, starting settlement or other hard-protected civic area;
- a village, outpost, camp or other authored POI exclusion envelope;
- an authored road, bridge, waypoint, graveyard, quest, travel or sight-line
  corridor;
- a reserved candidate envelope for a dynamic POI that mapgen has not placed
  yet;
- planned bay/lake/river/other zone-water masks, the exterior 80-node coastal
  shelf, or deep ocean.

Roads and ordinary POIs need not be immutable to exclude claims. Protection
and claim eligibility are separate systems.

There is no general runtime slope test for Claim-Stone placement. Outside the
four guaranteed gentle coastal cores, players may deliberately claim steep or
unusual housing ground when the complete reservation passes the authored mask
and exclusions. The gentle-core relief limit is measured from mapgen's natural
surface-height field during the 32-seed audit instead of being recomputed on
placement.

Road exclusions use the world plan's three fixed classes: a 7-node primary
road inside a 16-node total corridor, a 5-node secondary road inside a 12-node
corridor, or a 3-node trail inside an 8-node corridor. Deterministic road
meanders move the corresponding analytic corridor with the road; removing or
rebuilding its visible nodes never removes that exclusion.

### 6.1 Boundary visibility

- Claim boundaries are not permanent world nodes, luminous walls or always-on
  effects. A permanent transition-node seam would scar the landscape, require
  rewriting large cube surfaces on every move or upgrade and communicate the
  wrong fiction of a physical force field.
- Crossing into or out of a claim briefly shows that claim's active boundary
  to the crossing player only. A denied dig, placement or use action triggers
  the same visualization immediately and identifies the owner, so an
  underground player understands why otherwise ordinary stone is protected.
- The visualization is a sparse, low-intensity outline of the relevant cube
  edges, visible for only a few seconds. It must remain legible underground but
  use bounded client-scoped particles or equivalent transient markers rather
  than persistent entities or nodes. Repeated crossings and denied actions are
  throttled per player and claim.
- The owner and trusted characters may deliberately request a temporary full
  outline from the Claim Stone interaction or a housing inspection action.
  Placement preview distinguishes the current active cube from the reserved
  radius-50 horizontal footprint without leaving either visible after the
  preview ends.

### 6.2 Natural mob spawning

- Every natural mob spawn candidate inside a Claim Stone's current active
  protection cube is rejected. This includes hostile creatures, passive prey
  and critters; an active home does not accumulate unsolicited entities.
- The unused part of the radius-50 future reservation remains ordinary spawn
  ground until a later stone upgrade expands the active cube into it. Active
  protection and maximum reservation already use separate spatial indexes, so
  the spawn check queries only the active index and requires no surrounding
  node scan.
- A claim does not despawn, repel, pacify or block existing mobs. Creatures
  spawned outside may enter, pursue and fight inside it, and an upgrade leaves
  creatures already standing in the newly active volume untouched. Claims are
  therefore homes with controlled spawning, not combat sanctuaries.

### 6.3 Growth across a claim boundary

- Crops, saplings, bamboo and other player-grown content may grow naturally
  from an active claim into its unprotected surroundings. Growth neither waits
  for a larger Claim Stone tier nor clips its result at the active boundary or
  at the maximum-reservation edge.
- Claim ownership remains point-based after growth. Nodes inside the active
  cube belong to the claim; every overhanging trunk, leaf, crop or bamboo node
  outside it is ordinary unprotected world content and may be altered by any
  player permitted by the outer faction/zone rules.
- The ten completely empty nodes required between different owners' maximum
  footprints are also the authored horizontal growth buffer. Ordinary
  player-growable structures intended for housing must not extend more than
  ten nodes horizontally from their planted position. A future exceptional
  growable larger than that requires its own cross-claim rule rather than a
  generic growth block for every ordinary plant.
- WP32's asset gate measures every shipped crop, sapling, bamboo and other
  player-growable template from its planted/source node over every growth
  variant and rejects any variant extending more than ten nodes horizontally.
  This is an automated content audit, not an assumption left to asset authors.

### 6.4 Protection from indirect mutation

- An active claim protects its nodes, metadata, inventories and functional
  state from every destructive, replacing or intrusive mutation path, not only
  direct player digging and placement. Explosions, fire, liquids, falling-node
  placement, mobs that break or build, machines and later scripted world
  effects must obey the same claim ACL.
- A mutation inside an active claim is allowed only when its complete causal
  action carries an authenticated owner, trusted character or administrator
  with permission in every covering claim. Attribution fails closed: an
  ambient or unattributed effect may not alter protected state, and an effect
  must not inherit permission merely because it began outside the claim.
- Player-authorized destructive effects may operate inside that player's
  claim when their attribution survives through the final per-node mutation.
  If a subsystem cannot preserve that attribution, it must leave protected
  nodes unchanged rather than guess. Engine liquid flow into air exposes only
  the after-change `register_on_liquid_transformed` callback (`on_flood` is not
  called for air; `reference_projects/luanti/doc/lua_api.md:6774-6779` and
  `:11009-11016`), so the implementation may need to restore affected protected
  nodes or disable automatic liquid transformation there; a placed source node
  remains an ordinary direct placement governed by the ACL.
- The expressly permitted benign growth in §6.3 is the exception: a crop stage
  or player-grown plant may advance and add its ordinary growth nodes without
  becoming a generic authorization for destructive replacement. Normal
  operation of an owner-accessible workstation is likewise not an outside
  attack on its own inventory or metadata.
- Protection changes world nodes, not combat rules. Mobs and hostile effects
  may still enter and damage eligible players inside a claim; they simply
  cannot damage or place the claimed terrain around them.

### 6.5 Free player build palette

- Housing has no race-, faction-, zone-, biome- or material-tier-specific
  placement palette. An owner or trusted character may place every ordinary
  block they legitimately possess wherever the general world rules and claim
  geometry permit it; foreign cultural materials are valid building materials
  too.
- Claim permission still cannot override immutable content, the reserved Home
  Stone arrival column, depth rules or another outer restriction. “Any block”
  means no aesthetic whitelist, not a bypass around those systems.
- Race build sets and regional materials are optional cosmetic goals, never a
  style score or construction requirement. Authored capitals, settlements,
  POIs, terrain and vegetation carry each race region's reproducible visual
  identity while player homes remain a Minecraft-style space for expression.

### 6.6 Farming and private functional content

- The later farming package may grow cooking crops and the universal spice
  line inside any active claim. Healing herbs, race/culture materials, ores
  and the found-only cooking ingredients—mushrooms, wild cocoa and rock
  salt—remain non-cultivable world resources. A claim never turns a gathered
  progression resource into a farmable one.
- Ordinary saplings, bamboo and other decorative or mundane useful plants are
  allowed and follow §6.3 when growth crosses the active boundary. There is no
  claim-specific livestock, breeding or stable system in scope; a later animal
  husbandry feature requires its own design rather than inheriting permission
  from the farming rule.
- Ordinary owner-accessible workstations, cooking stations, doors and unsealed
  inventories operate under §3's owner/trusted ACL. They grant no recipe,
  profession, service-NPC or material-progression permission that the
  interacting character does not already possess.

## 7. World mutability model

### 7.1 Hard-protected world content

These structures remain reproducible and cannot be changed by players in their
shallow protection volume:

- full race capitals, their gates and narrow surrounding aprons;
- starting/respawn cores;
- waypoints and graveyards;
- essential service and quest-giver platforms;
- small functional NPC spawn/return anchors;
- renewable mining sockets and other bounded renewable-resource mechanisms;
- critical bridges or gates that have no adequate alternate route;
- the Holy Grounds from the surface through y = −700.

Every land-side hard-protected footprint extends upward without limit and
downward through y = −700 inclusive. Its x/z extent is the bounded authored
core/apron or functional anchor, never the ordinary shell of a whole road,
village or camp.

An essential service NPC standing on such a platform is passive and
invulnerable. Hard protection never overrides the universal editable T5/T6
land layer at y = −701 and below.

### 7.2 Mutable but claim-excluded world content

The following are generated once and may be dug, rebuilt or visibly damaged,
but a player may never privatize their authored envelope:

- ordinary roads and their travel corridors;
- villages outside their small functional cores;
- ordinary outposts, bandit/Mirefolk camps and war camps outside their
  functional anchors;
- ruins, tents, fences, decorative fortifications and battlefield dressing;
- terrain surrounding quest and NPC platforms.

This is the Minecraft-like mutable layer. Destruction changes the persistent
world rather than causing automatic structural regeneration. Any gameplay
loop that must remain reproducible attaches to the small protected functional
anchor, not to a destructible wall, tent or road node.

Only a bridge or gate with no adequate alternate route is promoted from this
layer into §7.1 hard protection. The presence of a bridge or gate alone does
not make it immutable.

### 7.3 Mutable and claimable ground

Ordinary terrain inside the positive housing mask is freely reshapeable and
may receive a Claim Stone if its full future reservation passes §6.

## 8. Runtime and persistence contract

The upstream Protector Redo mod is a reference, not a drop-in implementation.
Its fixed-radius `core.find_nodes_in_area` scan is unsuitable for per-stone
radii up to 50 and the project's 100-player target.

- Use a persistent claim/POI registry mirrored into spatial indexes. Luanti's
  `AreaStore` is the preferred first implementation; it indexes 3D cuboids and
  points (`reference_projects/luanti/doc/lua_api.md:8422-8464`). A
  mapblock-bucket index is the fallback only if profiling finds unacceptable
  allocation overhead.
- Keep at least three logical indexes: active hard/claim protection volumes,
  maximum claim reservations, and claim-exclusion envelopes/corridors. Active
  protection remains a real 3D cube index. The reservation index implements
  the binding 2D rule by storing every x/z footprint as a degenerate cuboid at
  y = 0 and projecting every reservation query to y = 0; `AreaStore` therefore
  supplies the spatial acceleration without letting vertical separation bypass
  an overlap.
- Placement queries the candidate's radius-60 x/z AABB at y = 0 against other
  owners' stored radius-50 degenerate AABBs, implementing §2's one-sided
  ten-node expansion exactly. Same-owner reservations bypass only this pairwise
  spacing test; every housing/exclusion-mask check still applies.
- A dig/place attempt performs a point query. It never scans surrounding world
  nodes and runs no protection globalstep.
- A natural mob spawn candidate performs the same kind of point query against
  the active-claim index only. It never scans the maximum reservation or world
  nodes and does not add a claim-spawn globalstep.
- One central claim-mutation predicate handles direct and indirect node/state
  changes. Every game-owned explosion, fire, machine, mob terrain action and
  scripted bulk write must call it per affected claim region; no subsystem may
  treat `core.set_node`, schematic placement or VoxelManip as a protection
  bypass. Engine-owned liquid callbacks require the fail-closed restoration or
  suppression described in §6.4.
- Claim placement performs one reservation/exclusion intersection query plus
  the exact 101 × 101 housing-mask validation. This rare operation may do more
  work than the hot dig/place path.
- Authored roads and future POI slots register deterministic exclusion
  envelopes before a player can claim nearby ground. If mapgen chooses among
  terrain-dependent POI candidates, all candidate positions stay inside the
  pre-reserved envelope; the winning small functional core is registered when
  its final position is persisted.
- `AreaStore` is not persistence. Canonical records live in mod storage; the
  indexes are rebuilt on load and updated transactionally on placement,
  upgrade, recovery, dormancy, reissue, admin removal or later ownership
  transfer.
- Every canonical id stores a monotonically increasing registry generation.
  Each authorised live ItemStack mirrors both stable id and current generation;
  the registry additionally records its one canonical live location. Decay,
  voluntary/forced dormancy and reissue increment the generation before any
  replacement Stack can become valid. Inventory use, placement, login
  reconciliation and escrow delivery reject and remove a Stack whose id,
  generation or canonical location does not match. An offline Stack can
  therefore be invalidated immediately in registry state and removed lazily on
  the owner's next load without restoring protection, cloning a slot or
  reviving a dormant id.
- The canonical record persists the latest successful placement's wall-clock
  timestamp. Recovery removes the active indexes and Home Stone destination
  atomically before returning the bound Claim Stone item; successful
  re-placement creates the new destination and binding timestamp atomically.
- Transaction tests cover every state edge: placed↔inventory/escrow recovery
  preserves assigned count; live→dormant releases one slot; dormant→live
  consumes one slot without creating a new personal id; full-pool decay plus
  reissue leaves assigned count unchanged; `assigned > limit` performs neither
  decay nor issuance; and stale generations never create a second live
  location.
- The implementation must retain `protection_bypass`, protection-violation
  callbacks, owner/member area visualization and administrative cleanup.

## 9. World scale and housing-capacity dependency

- The binding authored mainland frame is x = −2,600..+2,600 and
  z = −3,000..+3,000. It bounds the mainland rather than the generated world:
  coastlines vary and taper inside it, open sea continues beyond it, and the
  two separately authored dragon islands may sit beyond the mainland coast.
- The Holy Grounds is fixed at x = −2,500..+2,500 and z = −250..+250. This
  500-node-deep central land battlefield may contain authored lakes but is not
  ocean. Its nominal internal x edges are −1,500 / 0 / +1,500 with bounded
  shared-edge variation. Inside the outer rectangle the
  surface-through-y = −700 no-change rule in §7.1 applies; y = −701 and below
  remains universally contested and editable.
- The dragon-island centres are (−3,150, 0) and (+3,150, 0), each inside a
  fixed 600×700 envelope. Their channels guarantee at least 200 ocean nodes,
  use 48-node flight-warning bands on both shores and retain at least 104 hard
  no-flight nodes. The channels are immutable at every depth.
- Each continent's analytic planned footprint contains dry land plus authored
  bays, lakes, rivers and other zone-water masks. Those water bodies remain
  zone-classified, can never become deep ocean and stay outside claim
  reservations even if filled. The exact 80-node editable shelf begins only
  outside the planned footprint's final perimeter; deep ocean after it is
  immutable at every depth. Dragon-channel masks override that shelf.
- `world_zones.md` §7 fixes both complete outer footprint chains. The four
  lateral arcs between `|z| = 1900` and `|z| = 2500` stay within `|x| =
  2580..2600`; coast and zone-boundary variation are damped together there to
  preserve each decided 600-node shoreline × 300-node inland housing core.
- The six capital centres are fixed at (−1,800, +1,500), (0, +1,500) and
  (+1,800, +1,500) for Kragmar, and (−1,800, −1,500), (0, −1,500) and
  (+1,800, −1,500) for Elandor. Their x/z positions are authoritative scale
  inputs; surface y remains terrain-derived. Neither road authoring nor mount
  balance promises a capital-to-capital target duration. Roads follow legible
  geography and do not wind artificially to manufacture travel time.
- The corresponding starting/respawn-settlement centres are fixed at the same
  three x coordinates and z = +2,550 for Kragmar or z = −2,550 for Elandor.
  They are terrain-height anchors inside the six claim-free level-1–10 zones;
  their x/z centres do not vary by seed.
- Housing capacity is a two-dimensional packing problem. Claims may not be
  stacked vertically between different owners to multiply capacity; every
  stone reserves its full future radius-50 projected horizontal footprint plus
  the ten-node inter-owner gap.
- A regular maximum-claim packing therefore consumes approximately 111 × 111
  horizontal nodes per claim before roads, POIs, water, boundaries and organic
  placement loss. The earlier working suggestion of 150 claims per faction is
  not the target: more measured physical capacity is wanted before the
  per-faction live-Stone limit is selected.
- Expanding eligibility from four level-21–30 zones to all ten level-11–30
  home zones gives each faction five housing zones and substantially increases
  supply without sacrificing the six claim-free starting zones. The resulting
  capacity still requires measurement: zone area does not reveal how many
  radius-50 reservations survive roads, water, POIs and irregular borders.
- The per-faction live-Stone limit and on-demand inactivity decay in §5 bound
  permanent occupancy and create a soft incentive toward the faction with more
  available housing. They do not replace the physical-capacity audit and do
  not directly balance active PvP population.
- The housing-zone polygons are fixed by `world_zones.md` §7; the per-faction
  live-Stone limits remain open until physical capacity is measured. Their
  audit must cover all 32 seeds and use the real exclusion masks and simulated
  free-placement sequences rather than gross area alone; the audit may not
  enlarge the decided mainland frame merely to satisfy an arbitrary quota.
  For each of the four coastal alternatives it must also prove the decided
  600-node continuous frontage and 300-node usable inland depth after coastline
  variation and static exclusions. It additionally slides the full 101×101
  reservation footprint over each guaranteed core and proves at most 12 nodes
  of natural-ground relief with no forced cliff, ravine, river or lake. Those
  minima do not replace the packing simulation.

## 10. Deferred measured outputs

No structural housing design question remains. Two numeric outputs require the
implementation's mandated measurements rather than an owner choice:

1. WP40 measures 32-seed packing with real exclusions and simulated placement
   sequences. Safe per-faction live-Stone defaults are selected below the
   measured capacity and may not enlarge the fixed mainland frame.
2. Revised T4/T5/T6 reliable net-income measurements convert the decided
   30m/90m/3h expansion and 5h/10h additional-Stone targets into ledger copper
   values through §2's fixed rounding rule.
