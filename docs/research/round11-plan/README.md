# Round 11 execution plan

Date: 2026-09-20. Baseline: `ac232ec2` on main.
Status: **DELIVERED — main, Luanti sync and remote push complete, 2026-09-20.**
Delivery checkpoint and next playtest: [Round 11 completion](../round11-completion.md).
The user approved the complete plan and authorized autonomous delivery through
the next playtest. The final test-budget amendment below supersedes older annex
wording and the historical v3 review inputs.

## Authority and completion target

Deliver one independently reviewed, integrated fresh-world build for the next
user playtest. The accepted user rulings are recorded in
[round11-planning-decisions.md](../round11-planning-decisions.md). This plan
resolves routine implementation choices explicitly rather than leaving product
rules to individual workers. Approval of the plan adopts the numerical tuning
and catalog choices below; they are not represented as previous user quotes.

Before runtime work, consolidate these rules into `docs/design/` and reconcile
all conflicting active paragraphs. Historical evidence stays historical. Update
BACKLOG/ROADMAP and README when a package status changes; do not mark a whole WP
complete merely because this round delivers one slice. Delete the Round 11 TODO
once this plan is approved and the living-spec fold is complete.

Routing: root orchestrates and integrates. Native GPT-5.6 Sol implements and
reviews ordinary packages; native Astra may own difficult world/performance
work. Own-provider workers never run through CLI. No Claude this session.
There are three worker slots beside root. Worktrees, source ownership and
current checkpoint files survive compaction. Each non-trivial implementation
gets an independent reviewer who did not author it.

## Frozen product direction

- Four classes: Warrior, Mage, Priest, Scout. Scout has ranged and melee trees,
  uses mana and leather; no stealth, poison, traps or separate Rogue class.
  All weapon-derived skill damage comes from the equipped main hand. Bow-only
  skills require a bow; no offhand attack or new dual-wield system.
- Physical weapon families: sword, dagger, greataxe; the existing greataxe is
  also the Scout's two-handed melee option. Caster families: two-handed staff
  or one-handed wand plus Goldsmith book. Remove scepters/orbs from active V1
  registrations, recipes, loot and vendor choices; no legacy aliases.
- Ordinary equipment has at most one prefix and one suffix, no repeated stat.
  Family legality applies to both channels. Common has zero affixes, Uncommon
  one, Rare two; reserved Unique and the trinket special are not expanded.
  Apprentice adds the prefix, Journeyman the suffix, Expert gains masterwork
  value access/first temper, Master the second temper. Item-level value bands
  remain; do not compensate for fewer slots by doubling affix values.
- Use the exact accepted family matrix in the [GEAR annex](gear.md). HP and Mana remain
  base-pool percentages. Armor affixes become numerical rating. No direct
  spell-damage enchant is introduced: Intelligence already contributes it.
- Plain bows and shields join universal Basics, following the Round 10 ordinary
  equipment rule. Woodcarver owns bow refinement/enchanting, Armorsmith shield
  refinement/enchanting. This explicitly replaces the older unimplemented
  Master-only bow-crafting and specialist plain-shield assumptions. Goldsmith
  books, Leatherworker quivers and each profession's bags remain specialist
  recipes, one owning book per concrete recipe. Familiar base grid layouts are
  read from pinned VoxeLibre, never guessed.
- Cloth and leather bags both have 8/16/24/32 slots at the four mastery bands.
  Eight named material variants are an explicit catalog exception; same storage
  behavior and no stats/affixes. Small cloth bag remains the vendor floor.
- One basic Leatherworker quiver, four arrow-stack slots, Apprentice recipe,
  no combat bonus/affix/refinement/wear. Shooting works without it. Ammo comes
  first from an equipped quiver, then main inventory, as one atomic shot action.
  A worn quiver is the sole zero-hand exception beside a two-handed bow; other
  two-handed weapons still require empty offhand. One-handed melee may keep
  the quiver equipped. Removing it moves its arrows to main only if all fit;
  otherwise refuse without moving anything. No automatic ammo loss/drop.
- Scout starter: wooden bow equipped; ordinary stone sword and 20 player arrows
  in main inventory. A quiver is an optional profession convenience, not a
  mandatory starter or a new below-ladder identity. Reuse the existing four
  Scout abilities and sixteen talents; finish their actual consumers, not just
  their UI. Old three-class WP11 X3 completion is not silently included.

## Armor and boss contract

Use raw rating A and authoritative attacker level L:

```
K(L) = 20 + 0.5 * min(L,60) + 8.5 * max(L-60,0)  # L >= 1
A = max(0, base_rating) * (1.40 if Unbroken learned else 1.00)
    + (15 if Unbroken emergency window active else 0)
reduction = min(0.70, A / (A + K(L)))
```

The user's latest correction explicitly permits overcapping: never clamp rating
before evaluating the attacker's level. Only the final reduction is capped.
Proposed K values are 50/92.5/135 against levels 60/65/70. The final user
clarification requires both top tank gear AND deep Protection/Bulwark investment.
Use the existing Unbroken capstone's mutually exclusive 21-point investment gate
for the permanent x1.40 rating multiplier. A Ruin build can dip five ranks into
Ironbound but cannot also take this capstone. With identical maximum gear and
210 base rating including that dip, reductions against L70 are 60.9% for Ruin,
68.5% for Bulwark (294 rating), and 69.6% during its emergency window (309).
Surplus same-level armor remains fully useful against stronger enemies.

The Character page shows raw rating and same-level reduction; item tooltips do
not pretend a rating point is one percentage point. Existing per-item armor
curves/refinement and affix bands supply rating. Each shield derives its base
rating from the same-ilvl unrefined full metal set; normal +15% refinement
applies to the shield too. The [COMBAT annex](combat.md) supplies balance examples and a
maximum-source audit. Unbroken retains its +15-rating emergency window (8 seconds, 180-second
cooldown) after the permanent multiplier; its old 75% cap exception is removed.
This targeted Bulwark X3 consumer is in scope even though the rest of the old
three-class X3 package remains open. Update talent/UI wording and show base
rating, talent multiplier and resulting rating transparently.

Only player combat intake changes; mobs_redo NPC/mob armor remains its existing
pipeline. Combat caller/projectile provides attacker level. No guessed zone
level; unattributed environmental damage bypasses armor. Projectiles snapshot
attacker level at launch. PvP uses actual attacker character level. Armor applies
once, before absorb; fall/Dwarf/absorb ordering remains unchanged. The no-rating
fractional damage path must remain unrounded until its existing accumulator.

Kings remain actual L65. Dragons become actual L70, not only relabeled. Audit
HP, outgoing damage, player-vs-higher-target fit, XP and loot consumers together;
retain explicit authored boss loot ilvls and existing XP cap unless their own
contract says otherwise. Record the before/after numbers in the package review.

## V1 durability and repair contract

Owner: REPAIR, a bounded WP22 slice. No material repair or full WP44 income
rebase. Later reconsideration belongs in BACKLOG under WP22 follow-up.

- Eligible: registered ordinary weapons, shields, spellbooks, four armor slots
  and ordinary gathering tools including hoes. Trinkets, bags, quivers, ability
  tokens, mount skills, consumables and decorative items do not wear.
- Combat equipment lasts 3000 qualifying events, 6000 when refined. Count one
  settled outgoing action per main hand (and its spellbook), never one per
  native packet or AoE victim; require actual damage or effective in-combat
  healing or effective shield grant. Armor and shield wear once per incoming combat
  event with actual HP loss after dodge/absorb. No wear for falls, drowning,
  death, canceled casts, full misses or out-of-combat healing. Creative skips
  wear. Specify an exact-once action identity for multi-hit/projectile effects.
- Tool digging/hoeing keeps its own authored use budgets, not the 3000 combat
  constant. No new pick speed or depth rebalance; B22 calibration remains open.
- Zero durability disables that item's base and affix effects without destroying
  the stack or losing metadata. Tools refuse their operation while broken.
  Skills retain existing unarmed/baseline behavior; broken bow cannot shoot.
  Do not reuse the ability-token cooldown bar as equipment durability.
- Repair one/all owned eligible items in equipment, main and bag inventories.
  All city profession trainers, including Cooking, offer the same service
  regardless of the player's profession. Riding is not a profession trainer.
  Existing faction/service access still applies. No new repair NPC or trader
  distribution. Housing will bind every crafting station to the same API later;
  this round does not implement Housing or turn all wilderness stations into
  repair services.
- For wear fraction w and regular reference purchase price P, charge
  `ceil(P * 0.20 * w)` copper per damaged item; intact costs zero. Repair-all is
  the sum of the same per-item quotes, not a discount. Show price before payment.
  No material costs, profession or race repair discounts, or forced repair timer.
- Define one registered reference-purchase-price lookup: existing catalog/stock
  buy price for sold items; explicit matching slot/tier reference for unsold
  items; quality multipliers defined below (including the current Uncommon stock factor). Never invert
  buy-back or infer paid price from the player's sale value. The price table for
  every eligible identity is a required pre-code catalog artifact, reviewed with
  GEAR; missing entries fail that gate, never fall back to free repair. The
  existing economy rebase discrepancy stays visible; repairing at 20% must not
  silently deploy all of WP44 or introduce a second competing purchase table.
- Round-local price resolution is concrete: current regular gear purchase
  catalog and fixed stock are the source for existing sold items. New unsold
  weapon/tool identities use the matching material-tier weapon reference;
  shield/book uses that tier's other-slot reference. Preserve current wooden/
  stone fixed-stock prices; wooden hoe references the wooden tool price.
  Quality multipliers are 1/3/6 for Common/Uncommon/Rare (3 retains the existing
  Uncommon offer; 6 supplies an explicit unsold Rare reference). A refined
  Common item keeps its Common purchase reference; durability doubles rather
  than repair cost doubling. Endgame items use T6's slot anchor plus quality.
  Do not change the existing global buy-back, mounts, housing or income tables.
- Quote and apply revalidate exact items, wear, provider identity, distance,
  access and funds. Debit via grug_money and commit inventory changes together;
  stale forms/full inventory/insufficient funds change nothing. Preserve affixes,
  refinement, cultural data and identity. Equipment writes use the notifier.
- No per-player wear polling loop. One event owner publishes settled actions to
  wear and stats; preserve the 100-player performance constraints.

## Farming, world and presentation

The [WORLD annex](world.md) carries geometry/ecology contracts. Defaults for approval:
64x64 habitat cells; renewed plants get their first opportunity 4-8 real hours
after depletion; failed attempts back off 30-60 minutes. A global 10-second pass
services at most 8 cells, 64 candidates and 2 placements, with a separately
bounded node-inspection budget. Only already-loaded terrain; no world scans,
forced emergence or per-missing-node timers. Preserve observed generated
population, never invent debt from a statistical expectation alone. Respect
natural ground, current habitat, authored/protected areas and future claims.
Ores, gems, Rock Salt and Salt Crust do not join plant renewal.

Halve initial densities of the approved harvestable wild plant families,
including existing Potato/Corn sources, preserving geographic membership. Do
not halve grass, decorative flowers or mineral density. A registry inventory is
reviewed before editing probabilities.

Water-only bucket: three canonical `grug_materials:iron_bar` in the reference
V-shape, Basics, no level/profession gate. One empty and one filled item; filled
metadata preserves ordinary versus river source family. Refuse flowing water,
lava and protected decorative sources. Release depends on a narrow shared
actor-neutral liquid protection seam which prevents indirect alteration of
protected authored content. Do not defer that safety to unimplemented WP46.
This is the water guard slice only, not fire/TNT/admin reconstruction or Housing.

Wooden hoe plus six material tiers: identical soil conversion, proposed uses
64 / 128 / 192 / 256 / 384 / 512 / 768 respectively. Spend a use only on a real
new conversion outside Creative; repairable and non-destructive at exhaustion.
Keep the crop growth/hydration timings already accepted in playtest.

Presentation package: proper seed silhouettes from licensed pinned references;
VoxeLibre-like hoe, loom and anvil appearances; goldsmith muted-gold anvil;
correct Woodcarver bench; neutral-silver Silversteel across icons/worn skins and
metal parts of existing weapons/tools. Preserve weapon forms. Add six bows,
starter bow, shields, books, quiver and cloth/leather bag variants as required
by the catalog. Inspect actual reference imagery, not filenames alone; record
licenses. Do not generate new art unless a concrete reference gap needs it.

CAP builds an open six-post stable with earth floor, flat roof, one-node fences,
clear public entrance and four racial mount positions. GAME consumes explicit
bounded movement/rest regions: ground models take short slow walks and pauses;
flyers remain grounded with verified idle animation. No full mob AI, attacks,
loot, flight or visible emergency teleports. Preserve ordinary reload state and
exact population. All profession premises get protected exterior product frames
and interior stands; the smiths share a house but keep distinct trainers/books.

The gate change removes one additional block in the shared upper-floor opening;
no dedicated stair test/redesign. Diagnose the two supplied beach witnesses
before choosing the smallest correct fix. Preserve accepted beach width/course,
functional foundations and routes. Different root cause escalates to root for
technical replanning, not automatic user interruption.

## Work packages and dependency order

| ID | Deliverable | Primary ownership | Dependencies |
|---|---|---|---|
| SPEC | Living-spec reconciliation, exact catalogs/tables, authority audit | docs/design, BACKLOG/ROADMAP/README | approved plan |
| GAME | Dragon unload persistence, mount/rider yaw, stable display movement | grug_mounts/entity, capital_displays, authored-boss culling flag | SPEC; CAP geometry contract |
| WORLD-CAP | Beach correction, one gate block, shelters, profession displays | wp40/height and minimal query seam; wp13 capital blueprints | SPEC |
| AFF-GEAR | Two affixes/quality, roster, offhands, bags, quiver, books, UI fixes | grug_quality, grug_gear, grug_professions, grug_jobs, inventory | SPEC; COMBAT rating interface |
| ART | Licensed item/armor/station/display visuals and bow pose assets | media/build scripts/license manifests; registration hooks via owner | SPEC/catalog; integrate through GEAR/CAP |
| COMBAT | Rating formula/provenance, deep-Bulwark passive/emergency window, shields, dragon L70 | grug_core combat, equipment/stat consumers, mobs level consumers | SPEC; GEAR identities |
| FARM | Density/renewal, water bucket/flow guard, tiered hoes | world-content sources, farming, bounded core protection seam | SPEC; WORLD query contract |
| REPAIR | Wear, broken-state suppression, trainer repair UI, price quotes | new repair module, thin combat/tool/trainer hooks | GEAR price/identity; COMBAT event seam; FARM hoes |
| SCOUT | Bow draw/ballistic arrows, class/base kit, both talent trees | projectiles, classes/talents/abilities; GEAR ammo API | GEAR, COMBAT, existing WP11 X1/X2/X4 |
| INTEGRATE | Independent reviews, targeted LuaJIT/engine gates, delivery | integration worktree/evidence/docs | all packages |

Initial three implementation lanes: GAME, WORLD-CAP (Astra when warranted),
AFF-GEAR. ART and FARM use released slots. COMBAT, REPAIR and SCOUT follow their
published interfaces. Shared files are serial: GEAR publishes equipment/quality
first; COMBAT rebases and owns its consumers next; REPAIR then adds event hooks;
SCOUT rebases on those seams. ART returns assets or a patch to the owning lane,
not concurrent edits to its registration file. Root records every exact branch,
commit, file owner, interface and review status in the execution checkpoint.

## Verification and integration budget

Read `docs/research/luanti-lua.md` and the workflow review checklist before any
implementation or test brief. On Lua edits: luac51 parser, SETGLOBAL and all five
sweeps, explicitly including tools Lua. LuaJIT owns development/runtime fixtures.
Maximum seven interpreter processes workstation-wide, immutable inputs and
separate outputs; independent jobs use idle scheduling. No full resource census,
PERF rerun, reference repin or unrelated WP40 audit is scheduled.

Package fixtures exercise real consumers: dragon save/unload/activate vs death;
armor attacker provenance/PvP/projectiles and maximum builds; inventory/affix/
ammo/repair transactions and reload; bounded renewal/protection and bucket flow;
Scout all talent consumers. Geometry uses both beach witnesses and existing
capital blueprint/rotation fixtures. User explicitly excludes a dedicated gate
headroom test. Keep mount/camera and aesthetics as honest GUI acceptance gates;
headless correctness is not visual proof and does not block autonomous delivery
waiting for an intermediate user GUI session.

Merge reviewed branches into an integration worktree first. **Latest user ruling,
2026-09-20:** no PUC runtime tests in Round 11, including the previously planned
final parity pair. Keep the plain Lua 5.1 parser, SETGLOBAL and five static
sweeps. Run only focused, minimal LuaJIT gates/KATs needed for changed behavior;
no hours-long mapgen suites, broad populations or repeated unchanged evidence.
The v3 independent review remains historical evidence of the prior plan; this
explicit user amendment is not retroactively included in its hashes.
Run targeted real-engine scratch-world lifecycle/capital/source tests appropriate
to the changes; never modify the user's test world. All material findings must
be fixed/re-reviewed before main. Then merge, sync from main, push to the already
authorized Kaesual/grudgelands target and deliver a concise fresh-world playtest
checklist. Engine fallback GUI remains a separate user gate.

## Exclusions and durable state

No complete Housing, no full WP44 income/economy rebase, no other three-class
WP11 X3 completion, no carried-light implementation, stealth, poison, traps,
block system, material repairs, general editable item frames, migrations or
legacy aliases. Do not claim WP11/WP14/WP22/WP24/WP44 as wholly complete on the
basis of this round. Deferred repair redesign is recorded under WP22.

At every handoff update docs/research/round11-execution.md (created after Go):
source heads, completed/pending packages, active workers, interface owners,
review findings, immutable evidence and the next concrete action. User rulings
win over this plan; record new rulings before dependent work. Stop only the
blocked dependency if a material product decision truly cannot be inferred;
continue independent work. Runtime implementation is authorized; the execution checkpoint tracks progress.
