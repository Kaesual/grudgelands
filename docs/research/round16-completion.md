# Round 16 completion record

Status: integration in progress; final gates and delivery receipt pending.
Date: 2026-09-22. Contract: [approved plan](round16-plan.md).
Execution: [lane ledger](round16-execution.md).

## Scope

- Safe mounted leave/shutdown cleanup; normal dismount appearance retained.
- Targeted threat/Taunt corrections with its existing three-second tuning;
  real Charge stun, player Nova roots, small Nova damage and ice particles;
  an oriented Ibex selection box matched to its ordinary animated body.
- Visible directional atlas markers above the raster, individual quest givers,
  profession/Riding trainers and static king/dragon locations. Names-only
  tooltips, without clustering or overlap special cases.
- Fixed quest rewards by intended level/work, explicit prerequisites and six
  starter-to-village handoffs; +50% kill XP with existing sharing rules; exact
  XP progress beside the bar and privileged `/xp give`.
- Clear armor type labels and station-book placement; food refused during
  combat before consumption, doubled periodic recovery and a small Combat HUD.
- Surface-following full preparation, one locally resolved tile at a time,
  conservative terrain/content coverage and persistent inner-chunk resume.
  The 320-node ocean margin, immutable world mode and starts-only path remain.
- Atmosphere/audio/density lane: awaiting final implementation handoff and review.

This is an increment of existing work packages; the shipped count remains
27 of 53. Nether, waypoints and broader POI/progression expansion are unchanged.

## Independent review and calibration

| Scope | Implementer | Reviewer | Initial C/H/M/L | Fix rounds | Result |
| --- | --- | --- | --- | --- | --- |
| A mounts | Astra | Sol | 0/0/0/0 | 0 | Clean |
| B combat/control/Ibex | Astra | separate Astra | 0/1/1/0 | 1 | Clean |
| C atlas | root Astra | Sol | 0/0/0/0 | 0 | Clean |
| D progression + XP UI/admin | Sol | Astra | 0/0/0/0 | 0 | Clean |
| E food/UI excluding XP | root Astra | Sol | 0/0/0/0 | 0 | Clean |
| G surface preparation | Astra; root correction | separate Astra reviewers | 0/0/1/0 | 1 | Clean |
| F atmosphere/audio/density | Sol | pending | pending | pending | Pending |

Reviewers did not author their reviewed scopes. No Claude or same-provider CLI
was used. Review elapsed wall times were not recorded. Reports:
[A/C/E](round16-mounts-map-food-review.md),
[B initial](round16-combat-review.md), [B correction](round16-combat-fix-review.md),
[G/D initial](round16-surface-progression-review.md),
[G correction](round16-surface-fix-review.md).

The combat review caught retained horizontal velocity under a zero speed
override and missing rotation on the asymmetric Ibex selection box. Both are
closed using engine-supported braking and a preserved rotation flag. The surface
review added a bounded live terrain/selector source digest to the stable
seed/content identity; engine-assigned content IDs remain excluded.

## Validation and limits

Final integrated parser/static gates, compact PUC/LuaJIT parity and isolated
registration smoke: pending. Source hashes and results will live under
`tools/r16_final/evidence/`.

The surface lane's bounded two-boot native test saved cursor 2, restored 2 and
advanced to 4, with no dispatch during teardown. Five actual authority samples
agreed across boots. Those logs cover scheduling/adapter behavior before the
subsequent source-fingerprint correction, which has its own focused regression
and review. No whole-world generation, repeated timing samples, exact savings
measurement or AI-budget/PERF campaign was run. No optional ETA estimate was
requested from the final implementation.

Fixtures exercise real Lua consumers with bounded engine doubles; these are
not two-client or GUI acceptance. Movement feel, marker readability, brightness,
audio loudness, quest pacing and density remain playtest judgments. The next
user check is [Round 16 playtest](round16-playtest.md).

## Delivery receipt

Pending merge, local sync, installed-byte verification and authorized push.
