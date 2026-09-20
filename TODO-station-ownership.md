# TODO — Shared crafting station ownership

Updated: 2026-09-21. Raised by the user during Round12 delivery. Investigation and
planning only; the user explicitly instructed the coordinator to finish the
current round without expanding implementation scope.

## Confirmed problem

World stations currently use shared node inventories. Access checks and recipe
profession checks are not ownership of deposited ingredients or completed work.
Another permitted user can remove inputs or take outputs if eligible. Timer-based
furnaces/brewing may consume ingredients before the eventual output-take profession
check, leaving an unusable result for the person who supplied the materials.
Normal digging refuses nonempty stations; blast callbacks require their own
analysis and are not equivalent to normal digging. Inventory Crafting is already
player-owned; this issue concerns node-based workstations.

Detailed source audit: [shared station inventory audit](docs/research/shared-station-ownership-audit.md).

## Accepted mode split and revised transaction proposal — 2026-09-21

The user accepted two fixed modes, selected by placement provenance rather than
player configuration, including the labels below. Implementation has not begun
and the full transaction contract is still open.

- Authored capital/POI stations: persistent personal working inventories per
  player and station. Other players cannot see or take those contents.
- All player-placed stations: shared node inventories, in both Housing and the
  open world. Player crafting never creates a personal-mode station.
- Housing's Protector Stone controls area-wide access, including chests and
  stations. No additional per-station access configuration is proposed.
- Player-placed world stations/chests outside Housing are openly accessible,
  subject to the existing global world-placement/protection rules.
- Show a concise mode/access explanation in the station UI. Suggested labels:
  “Personal workspace” and “Shared station”; shared wording explicitly refers to
  players who have access to the surrounding area.

The earlier coordinator suggestion to bind production/progress to an initiating
crafter is superseded by the user's new proposal:

- Shared 3x3 station inputs remain shared, but the result preview is per viewer.
  Only a player eligible for that recipe sees and may take its output; other
  viewers see an empty result slot. Revalidate eligibility and current ingredients
  on the real take transaction. A preview is not an independently owned item.
- Progress belongs to the collector, only if eligible and the recipe tier is
  exactly their current profession tier; otherwise that progress is lost.
- Automatic furnaces and dual furnaces transform inputs and allow collection
  without profession checks (area access still applies).
- Only qualified cooks may assemble profession-specific raw dishes, but anyone
  may then bake and collect those dishes from an oven.
- No production eligibility is bound to whoever happened to insert an ingredient.

An explicitly requested native GPT-6 Astra [audit](docs/research/station-viewer-rules-audit.md)
checked this against current recipe/engine paths. Open issues include the automatic Brewing Stand, raw/final
Cooking double progress, simple roasted foods, custom refinement stations,
per-player previews over shared inventories, and partial-stack progress receipts.
Authored loot chests remain separate and do not automatically become personal.

Coordinator recommendations pending user answers:

1. Alchemy follows the same qualified-preparation/free-automatic-finish split
   as Cooking. This needs new prepared mixtures and is a real content change,
   not merely removing the existing Brewing Stand output gate. Alternative:
   separately design a profession-gated brewing exception.
2. Award progress on collection of the profession-gated preparation only;
   automatic finishing then gives no second credit. Alternative: only the final
   result awards credit to an eligible collector. The user was asked explicitly.
3. Simple roasting of meat/fish/grain remains universal under the furnace rule.
   If preparation-only credit is selected, these universal conversions give no
   Cooking progression. Prepared dishes remain Cooking-exclusive to assemble.
4. Custom refinement/affix Apply transactions retain their metadata-preserving
   commit and commit-time roll. Viewer eligibility also controls their preview
   and confirmation. Do not turn a prospective affix preview into a takeable
   already-generated item or allow repeated preview rolls.

Separate per-viewer output adapters must revalidate distance, area access,
station identity, ingredients and eligibility at commit. A shared node inventory
cannot itself show different contents to two players. Persistent input/fuel/
output data for personal workspaces must survive UI close, reconnect and unload;
the temporary UI is not the persistence store.

Define full-inventory handling, concurrent viewers, profession loss, disconnect,
offline timing and all removal paths without loss/duplication. No personal
inventory may silently teleport contents between different physical stations.

## Next planning package

Cut one cross-station package across WP10/WP26/WP30 and future Housing integration,
with a frozen transaction/ownership contract before code changes. Acceptance:
two simultaneous users, unauthorized recipe attempts, cancellation, full inventory,
reconnect/restart/unload, respec/profession loss, and all node-removal paths.
No implementation or automatic migration is authorized by this TODO.
