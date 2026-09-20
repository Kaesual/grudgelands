> **2026-09-20 final Go:** the complete Round 11 plan is approved for autonomous
> implementation through the next playtest. Native Astra is recommended for the
> beach fix; native Sol remains default. Only minimal targeted LuaJIT gates/KATs;
> **no PUC runtime tests this round**. Keep plain-5.1 parser/static checks.

# Round 11 planning decisions and source reconciliation

Date: 2026-09-20. Runtime baseline: `ac232ec2`.
Planning only. The user explicitly requires planning to finish before any
runtime implementation. No code changes, runtime tests, sync or deployment
are authorized by this record. Native Sol research is permitted; the current
session still excludes Claude and same-provider CLI delegation.

This records user instructions for the pending design consolidation. Accepted
changes must be reconciled into the living design files before implementation
briefs are frozen. New proposals below are not silently adopted.

## Latest user steering — supersedes conflicting discussion below

Latest clarification during plan preparation: **overcapping is intentional**.
Use all raw armor against the attacker's level and cap only the resulting
reduction. Excess armor above the same-level 70% threshold must remain useful
against stronger enemies. Top tank gear should approach 70% against L70 dragons.
This rejects the coordinator's intermediate effective-rating cap; that model is
not an implementation option. A further explicit clarification requires maximum
tank gear **plus the Protection/Bulwark talent tree** for the near-70%-against-
dragons target. The damage Warrior with identical tank gear must remain clearly
below it, including any affordable shallow Ironbound investment. The proposed
plan uses the existing exclusive 21-point Unbroken capstone for that separation;
it introduces no fifth class, new tree or block mechanic.


- Rogue means the melee Scout, not a fifth class. Melee skill damage continues
  to use the equipped main hand; no second weapon damage source, offhand attack
  or separate one-/two-handed talent system is requested. The choice of main
  hand changes its input values only.
- Caster direction: retain **two-handed staves**, which block offhands. Use
  **wands** as the sole one-handed caster weapon family; remove scepters/orbs
  from the proposed active V1 catalog. Goldsmith spellbooks fill the caster
  offhand. This supersedes the proposed one-handed staff.
- Quiver as arrow storage without a combat bonus is accepted.
- Repair at up to 20% of **purchase/reference purchase price**, never sell-back
  price, is accepted; scale by missing durability under the money-only service.
- Ordinary equipment capacity becomes **one prefix plus one suffix maximum**,
  replacing the two-prefix/two-suffix ceiling. Preserve the separate existing
  trinket special. Lower-tier unlock timing and numerical progression require
  reconciliation, not automatic retention of four-slot mastery rewards.
- Item-family enchant legality is required: caster-only Int/spell bonuses,
  ranged Dex/crit, shared melee Str/Dex, cloth Int, leather Dex, metal Str.
  HP can span families; Mana is useful on Scout equipment but not warrior-only
  equipment. Exact pools and shared-family choices remain a planning task.
  Existing `items_crafting.md` section 6.2 already defines family pools; expand
  and audit those rather than invent a disconnected enchant system.
- Armor rating evaluated against attacker level is proposed, with a tentative
  70% reduction ceiling. Strong shield value and a diminishing protection curve
  against higher-level enemies are desired. Formula, rating budgets and cap
  calibration remain open. The user proposes displayed dragon level 70 where
  kings are 65; changing actual levels also affects other combat/reward scaling,
  so display-only relabeling is not a complete implementation.
- User requests brief feedback now, round planning next, implementation only
  after that planning is finished.

## Accepted direction and latest overrides

The user accepted the preceding Round 11 recommendations on seed icons,
workstation appearance, open stables with bounded animal movement, immediate
recipe-book refresh, unclipped station forms, mount look-direction presentation,
dragon persistence, approximately half wild-plant density with slow renewal,
water-only Iron buckets, tiered hoes, neutral-silver Silversteel and the
targeted beach correction. Fall damage, cave openings and crop growth were
reported satisfactory. Creative explains the reported absence of hoe wear.

Two explicit overrides replace the previous coordinator recommendations:

1. **Gate stair opening:** remove exactly one additional obstructing block in
   the shared template. The user explicitly declines a dedicated clearance
   test or a broader stair redesign. Do not reintroduce those as a task gate.
2. **V1 repair:** ledger money only; no repair materials, profession ownership
   requirement or profession-tier restriction. Everyone can repair all eligible
   equipment through every profession trainer in cities. Later, Housing also
   permits repair at every crafting station, using the same money-only service.
   This supersedes both the proposed trader service and the proposed material
   repair alternative. Preserve the accepted slow wear and non-destruction
   rules. Put a later repair-design reconsideration in the backlog; do not
   implement material repairs now. The discussed ceil(main-material-cost ×
   missing-durability) idea is historical context, not the V1 rule.

Housing station access does not authorize implementing all of WP24 in Round 11.
Exact repair prices, station classification and remaining wear event boundaries
still need a concrete contract. The coordinator proposes one shared price at
all authorized services and no profession-specific surcharge.

## Beach witnesses

User screenshots show narrow stone/sandstone columns retaining grass or sand
tops, sometimes exposed ore, and thin tall walls at beach boundaries. The
overall beach shape, width and course are accepted and must be preserved.

- World name: `test`.
- Screenshots 1 and 2: approximately `(-414, 20, -2724)`.
- Screenshot 3: approximately `(-511, 20, -2562)`.
- Read-only inspection of that world's `map_meta.txt` gives the top-level seed
  **15140735923413111218**. Nested noise seeds are not the world seed.

The prior world seed from Round 10 is not this witness. No personal-world
mutation or engine loading was performed. Source hypotheses must distinguish
height-field transitions from resource/support column preservation or later
writer passes; screenshots alone do not prove the responsible code path.

Screenshot-informed source inspection shifts the leading hypothesis to the
broad coast-shaping veto at `wp40/height.lua:5382-5390`: it calls the generic
static exclusion predicate, which includes wider claim-exclusion envelopes.
Whole unlowered grass/ore columns fit this better than distance quantization
alone. Natural surface and ore classes are both cut by the actual natural-cut
policy (`planner.lua:1517-1518`, `map_adapter.lua:5-31`); no special ore-column
preservation is evident. This remains unconfirmed until a bounded coordinate
probe distinguishes exclusion identity, incoming/final height and chunk seams.

## New user proposals requiring discussion/consolidation

- Add a capital profession-building style pass: recognizable exterior item
  frames and interior stands with typical products, consistently for all
  professions. Atmospheric objects must remain non-removable, non-lootable,
  non-collectible and correct after reload. Prefer fixed decorative displays
  over introducing general player-editable frame inventories in this package.
- Include playable Scout and its bow foundation in the coming round.
- Woodcarver owns bows and staves; do not create Bowyer as another profession.
- Extend Leatherworker with bags matching cloth-bag capacities, with distinct
  names and restrained color variants of shared art.
- Warrior and melee Scout: two-handed damage option or one-handed weapon plus
  shield. Prefer existing armor/dodge mechanisms to a new block subsystem.
- Mage/Priest V1: one-handed staff plus Goldsmith caster book, initially mana.
- Archer: Leatherworker quiver in the offhand equipment slot.

These proposals need explicit reconciliation rather than parallel agents
inventing an independent equipment model.

## Verified existing design and implementation

- Leatherworker is one of the seven existing primaries. Its six material
  grades, recipes/refinement and 24 leather armor items are already shipped
  (`mods/ITEMS/grug_professions/leatherworker.lua`, `grug_gear/init.lua`). It is
  not an eighth profession or a new armor implementation package.
- Woodcarver bows and Leatherworker quivers are already assigned by
  `docs/design/professions.md` and `items_crafting.md` section 9.
- Bags currently belong exclusively to Tailor: decided sizes 8/16/24/32;
  current bag registrations cover 8/16/24. Leather variants and the missing
  32-slot size need explicit ownership and catalog work. Separate material
  variants require a deliberate exception to one-item-per-concept rather than
  accidentally violating recipe-book ownership.
- Offhand slot and hand-count enforcement already exist. Current rule is
  staff/greataxe two-handed; sword/dagger/wand/scepter/orb one-handed. Shields
  belong to Armorsmith; spell tomes to Tailor. These items/mechanics are planned
  under WP14, not an unplanned equipment slot.
- The quiver was a later arrow-only **bag-slot** item; Scout V1 did not require
  one. Moving it to Offhand must preserve a two-handed bow's exclusion of
  shields/tomes while allowing the worn quiver. A quiver is not a third hand.
- Scout replaces the old separate Rogue concept. Its current design is leather,
  bow/dagger/one-handed sword, mana, Quarry and Veil trees, no stealth/poison/
  traps in V1. Two-handed melee and shield access would extend that scope.
- `docs/design/scout.md` is stale about unregistered leather armor and missing
  leather art; Round 10 already supplied them. Reconcile those assertions and
  the contradictory proposal/decided status before reusing its task table.
- Current two-handed staff damage includes a family premium. Making the staff
  one-handed must explicitly rebalance the main-hand/offhand combination.
  Decide whether existing wand/scepter/orb families remain available in V1.
- Shields should retain the existing armor cap. Verify that their protection
  actually matters alongside metal armor/refinement rather than silently
  granting a capped-away bonus. A new block roll is not recommended.

## Proposed remaining decisions

1. Treat the user's Rogue as the melee Scout, retaining four classes.
2. Shield supplies armor, not a new block system; keep Scout evasion in its
   existing talents. Decide the concrete two-handed melee family and talent
   compatibility for Scout.
3. Adopt one-handed caster staff + Goldsmith book and settle the disposition
   of the already shipped alternative caster main hands.
4. Quiver is a worn Offhand-slot item compatible with a bow, without making
   bows compatible with shields/books. Define its useful V1 benefit and arrow
   source/consumption before implementation.
5. Cloth/leather bags share capacities/progression; neither grants extra
   class-specific bonuses. Decide catalog representation explicitly.
6. Freeze repair price curve and renewal tuning after the structural decisions;
   no implementation agent may choose missing player-visible numbers silently.

Round 11 is larger than the previous bug-fix plan. Sequence world/UI/lifecycle
corrections, then equipment/repair/farming foundations, then Scout/bows/talents
with dependencies respected. At most three workers run alongside root; this
does not mean all packages run concurrently. Every required independent review
still applies. Runtime implementation has not started.
