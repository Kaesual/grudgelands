# TODO — Round 12 approval

Date: 2026-09-20. Baseline: `8d0d393e`.

The Round 11 interaction fixes are delivered and independent review is clean.
The user accepted the next-round lanes, expanded farming/Skills/art, and asked
for a concrete autonomous execution plan before giving the final Go.

Working plan: [Round 12](docs/research/round12-plan/README.md).
Source audits: [food/farming](docs/research/round12-food-farming-audit.md) and
[recipes/UI](docs/research/round12-recipes-ui-audit.md). Those audits describe
Round 11 baseline code, not the new design.

## Decided by the user

- Starter Basics recipes visible immediately; later recipes revealed by first
  acquisition of the main material, without crafting or character-level gates.
- Full farming iteration across plant families, with varied world shapes and
  appropriate mechanics. Cultivated berries/fruit can regrow; roots/grain are
  resown; cane/bamboo regrow from the retained base. Wild renewal stays separate.
- All food buffs last five minutes; remaining food effects stay unchanged.
- Unprofiled held items get a 90-degree forward fallback, preserving authored
  weapon/item poses.
- WP47 Skills tab includes unlocked class/talent abilities and every purchased
  mount tier. Discard deletes the item representation, never the entitlement.
  Recovery checks carried inventory and all owned bags for duplicates.
- Old mount tiers retain their original speeds after upgrades.
- Careful art audit/revision of cooked results, wands and double-bit Greataxes;
  preserve accepted swords, one-handed axes, armor and raw crop icons.
- Art selection is autonomous with an independent visual reviewer. Supply a
  before/after gallery at delivery; no intermediate user approval checkpoint.
- Recipe presentation/Help, inventory/talent readability and food findability,
  original-class WP11 talent consumers, and a report-only newcomer UX audit.

## Execution authorized

The user explicitly gave Go. The concrete annexes and independent plan review
are complete, with no open findings or user design questions. Execution is tracked
in `docs/research/round12-execution.md`.

After approval, fold all final rules into living design, record execution state
and package ownership, and delete this TODO once no design questions remain.
