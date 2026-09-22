# Round 16 completion record

Status: delivered on main, synchronized locally and pushed.
Independent reviews and final gates PASS; GUI acceptance remains separate.
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
- A 15-minute day / five-minute night, moderately brighter outdoor nights
  composed with Night Vision, licensed success-only food/drink audio, and about
  30% more ordinary fightable surface mobs; encounter populations unchanged.

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
| F atmosphere/audio/density | Sol | Astra | 0/0/0/0 | 0 | Clean |

Reviewers did not author their reviewed scopes. No Claude or same-provider CLI
was used. Review elapsed wall times were not recorded. Reports:
[A/C/E](round16-mounts-map-food-review.md),
[B initial](round16-combat-review.md), [B correction](round16-combat-fix-review.md),
[G/D initial](round16-surface-progression-review.md),
[G correction](round16-surface-fix-review.md),
[F](round16-atmosphere-review.md).

The fresh [Astra documentation audit](round16-docs-drift-review.md) closed one
Medium and one Low finding in one correction round: XP basis versus final award
and the missing concrete living-spec quest table. Final drift verdict is clean;
no gameplay retuning was introduced by those documentation corrections.

The combat review caught retained horizontal velocity under a zero speed
override and missing rotation on the asymmetric Ibex selection box. Both are
closed using engine-supported braking and a preserved rotation flag. The surface
review added a bounded live terrain/selector source digest to the stable
seed/content identity; engine-assigned content IDs remain excluded.

## Validation and limits

All 53 changed/new Lua files pass the plain-5.1 parser, SETGLOBAL inspection
and five source sweeps. Production global writes are owning mod tables; fixture
writes are isolated engine doubles. Sweep hits are comments/literal separators
and an unchanged deprecated namespace in the vendored mobs API.

One final compact PUC-5.1 process (0.034638 s) and one LuaJIT process (0.022603 s)
pass all nine fixtures with identical canonical SHA-256:
`193d7aa7b7e653efa4aa97760111f6192ddb0fc184999f3a26afbb5f9975b2ee`.
Source hashes, static output and results are retained in `tools/r16_final/evidence/`.

The isolated native registration smoke passes: 72 armor definitions (including
rebuilt descriptions), 47 edible definitions, 60 trainer markers, eight boss
markers and the self marker. Its 2,054-file production snapshot matches the
integrated checkout. The executed snapshot only disables automatic preparation
scheduling and adds a disposable probe; it generates no terrain and touches no
personal world. Two earlier probe-only failures were corrected: inherited crop
node groups were an invalid proxy for edible registrations, and mod storage must
be acquired at load time rather than from `on_mods_loaded`. Production bytes did
not change between those attempts; logs are retained and not counted as passes.

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

Reviewed candidate `adeae43d` merged without squash as `00baacf8`.
`tools/sync_to_luanti.sh` installed main; all 2,056 installed names/contents
match the checkout and all 53 final Lua hashes remained unchanged.
Authorized `git push origin main` advanced `github.com/Kaesual/grudgelands`
from `3e714e7e` to `00baacf8`. This subsequent documentation-only receipt
changes no tested or installed game bytes. All implementation/review tasks and
isolated server processes have finished. Next action is the linked fresh-world
playtest; no additional implementation or approval is pending for Round 16.
