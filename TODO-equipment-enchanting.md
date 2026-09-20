# TODO — Simplify equipment enchanting

Updated: 2026-09-21. Planning only; user explicitly requires a later implementation Go.

## Current behavior and authority

`docs/design/items_crafting.md` sections 6b.2–6b.5 define refinement as +15%
base weapon damage (or armor equivalent), doubled durability, and prerequisite
for ordinary affixes. `grug_quality/init.lua` and the gear base-stat functions
implement these bonuses. Ordinary gear currently has at most one prefix and one
suffix; crafter mastery unlocks operations. There is no general third T6 enchant
slot. Section 6b.7 separately defines authored special variants, and trinkets
have their own fixed prefix/suffix/special contract.

## Confirmed user direction

Remove the separate refined state and its recipes/prerequisite. The user accepted
removal; no implementation has started. Enchant base equipment directly through
its owning profession. The latest preferred capacity replaces the prior
one-slot-at-T1/T2 proposal:

- One prefix and one suffix from T1 through T6.
- No new third T6 special slot in this round.
- Every legal named prefix and suffix has one recipe at each enchant tier T1–T6.
  Preserve the existing stat-specific words across tiers.
- Enchant tier may not exceed target item tier: T1 fits T1–T6, T3 fits T3–T6,
  T6 fits T6 only. The enchant's strength follows its own tier, never that of a
  higher-tier target item.

The user explicitly rejects added durability from refinement; use the proposed
new tier lifetimes without a refinement multiplier. Alchemy preparation and
profession progress decisions are recorded in `TODO-station-ownership.md`.

## Existing recipe implementation (verified before planning)

`grug_professions.register_add_affix` and the equivalent artisan helpers already
register six-tier in-place affix operations. These are generic "add the next
affix" operations per exact base item, not individually selectable named
prefix/suffix recipes. `grug_items.append_affix` requires refinement, picks a
random unused stat from the legal family pool and rolls its value from target
item level. Prefix/suffix access currently follows crafter mastery (suffix at
level 16); Imbue/Temper paths add further prerequisites and reroll operations.
These rules must be replaced coherently, not retained as hidden extra gates.

The nine existing stat name pairs are Heavy/of the Bear (Strength), Quick/of
the Fox (Dexterity), Clever/of the Owl (Intelligence), Stout/of the Ox (HP),
Attuned/of the Raven (Mana), Lucky/of the Eagle (Crit), Swift/of the Hornet
(attack speed), Elusive/of the Cat (Dodge), Stalwart/of the Tortoise (Armor).
Legal item-family pools remain binding; not every stat fits every item.

## Coordinator feedback and two pending user choices

Support removing the mandatory refinement step rather than preserving it under
another label. Keep profession ownership, item-family affix eligibility and
meaningful resource costs. Slot capacity does not mean a free built-in enchant.
No new ordinary special slot/effect is included. Keep already designed trinket
specials separate from this removal of the proposed new T6 slot.

Recheck the resulting enchanted-vs-base equipment budgets: removing +15% changes
damage, armor and the Protection top-gear target. Do not silently transfer +15%
to all plain items or stack it invisibly onto the first affix. Reconcile mastery,
temper operations, fine/masterwork recipes, special/cultural effects and recipe
progression with the simpler model; do not retain obsolete refinement gates.
Recommend consistency across ordinary enchantable weapons, armor and offhands
while retaining the separately designed trinket exception. The existing rule
against repeating the same stat across prefix/suffix should remain.

Two questions were explicitly sent to the user:

1. Fixed authored bonus per enchant tier (recommended), or a random range within
   that enchant tier? Both preserve targeted stat selection and never scale a
   cheap T1 enchant up to the target's tier.
2. Allow a new enchant to replace its occupied channel with material cost and
   clear preview (recommended), preserving the other channel, or fill empty
   channels only?

Recommended profession progression uses the enchant recipe's own tier, not the
target's tier; a T1 application to a T6 item remains T1 work. Remove separate
Imbue/Temper/refinement upgrade paths in favor of this single enchant workflow.
Materials, numeric bonus tables and station presentation need a bounded catalog
design pass before implementation; the user need not choose each individual
recipe value if the round Go delegates that calibration.
