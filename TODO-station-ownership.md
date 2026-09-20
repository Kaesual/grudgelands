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

## Proposed direction, not yet decided

- Public city stations expose persistent personal working inventories/jobs,
  allowing simultaneous users without ingredient/result theft or slot blocking.
- Validate recipe/profession eligibility before consuming ingredients or fuel;
  revalidate at execution/collection with a defined cancellation policy.
- Bind inputs/results and profession credit to the same owner. Closing the UI,
  disconnect, death, unload and restart must not lose or duplicate anything.
- Define safe cancellation/recovery and full-inventory handling.
- Decide separately whether player/Housing stations allow deliberate shared work
  with trusted players. Do not silently impose private city behavior on Housing.
- Audit every deletion/blast path so it cannot bypass job ownership or recipe
  authorization. Reuse WP46 protection boundaries where applicable.

## Next planning package

Cut one cross-station package across WP10/WP26/WP30 and future Housing integration,
with a frozen transaction/ownership contract before code changes. Acceptance:
two simultaneous users, unauthorized recipe attempts, cancellation, full inventory,
reconnect/restart/unload, respec/profession loss, and all node-removal paths.
No implementation or automatic migration is authorized by this TODO.
