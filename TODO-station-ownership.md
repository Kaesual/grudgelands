# TODO — Shared crafting station ownership

Date: 2026-09-20. Raised by the user during Round12 delivery. Investigation and
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

## User proposal and coordinator feedback — 2026-09-20

The user proposes two fixed modes, selected by placement provenance rather than
player configuration. These clarify the intended discussion; implementation has
not begun and the full transaction contract is still open.

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

Coordinator recommendation: adopt that split. Require recipe/profession
eligibility before consuming inputs/fuel and record the initiating crafter.
For shared stations, any area-authorized player may collect a legally produced
result, even without that profession; profession credit belongs to its crafter,
not its collector. This replaces the current late extraction gate. Personal
stations allow only their corresponding player to collect. Define cancellation,
full-inventory handling, profession loss, disconnect and offline timing without
loss/duplication. Authored loot chests remain a separate design question and do
not automatically become personal through this station rule.

Open transaction details include when automated production binds its crafter,
fuel reservation, interrupted work, recovery and the exact moment of awarding
profession progress. No personal inventory may silently teleport contents
between different physical stations.

## Next planning package

Cut one cross-station package across WP10/WP26/WP30 and future Housing integration,
with a frozen transaction/ownership contract before code changes. Acceptance:
two simultaneous users, unauthorized recipe attempts, cancellation, full inventory,
reconnect/restart/unload, respec/profession loss, and all node-removal paths.
No implementation or automatic migration is authorized by this TODO.
