# TODO — Simplify equipment enchanting

Date: 2026-09-21. Discussion requested by the user; no implementation Go.

## Current behavior and authority

`docs/design/items_crafting.md` sections 6b.2–6b.5 define refinement as +15%
base weapon damage (or armor equivalent), doubled durability, and prerequisite
for ordinary affixes. `grug_quality/init.lua` and the gear base-stat functions
implement these bonuses. Ordinary gear currently has at most one prefix and one
suffix; crafter mastery unlocks operations. There is no general third T6 enchant
slot. Section 6b.7 separately defines authored special variants, and trinkets
have their own fixed prefix/suffix/special contract.

## User proposal

Remove the separate refined state and its recipes/prerequisite as potentially
confusing. Enchant base equipment directly through its owning profession:

- T1–T2: one prefix capacity.
- T3–T5: one prefix and one suffix capacity.
- T6: one prefix, one suffix, plus one special-effect capacity.

The user explicitly rejects added durability from refinement; use the proposed
new tier lifetimes without a refinement multiplier. Alchemy preparation and
profession progress decisions are recorded in `TODO-station-ownership.md`.

## Coordinator feedback for discussion

Support removing the mandatory refinement step rather than preserving it under
another label. Keep profession ownership, item-family affix eligibility and
meaningful resource costs. Slot capacity does not mean a free built-in enchant.
Treat a T6 special as one authored effect, not another arbitrary primary-stat
affix. Define its limited effect catalog before promising shipped effects.

Recheck the resulting enchanted-vs-base equipment budgets: removing +15% changes
damage, armor and the Protection top-gear target. Do not silently transfer +15%
to all plain items or stack it invisibly onto the first affix. Reconcile mastery,
temper operations, fine/masterwork recipes, special/cultural effects and recipe
progression with the simpler model; do not retain obsolete refinement gates.
Clarify whether the new capacity rule covers ordinary armor/offhands too;
recommend consistency across ordinary combat equipment while retaining the
separately designed trinket exception.
