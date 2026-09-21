# Round 14 fixes work

## State

- Flight policy: implemented in `grug_mounts.flight_state`; focused LuaJIT
  evidence passes. Both stable dragon-island zone ids are denied before the
  shared mainland territory matrix, and `contested_land` plus `holy_grounds`
  are allowed for both factions.
- Profession isolation: the reported cross-player state has not reproduced in
  the production trainer callback/state path. The focused fixture uses two
  distinct players, persistent per-name metadata, real trainer formspec and
  receive-fields callbacks, Cooking plus a primary profession, reversed order
  and reconnect. All states remain isolated. No speculative production change
  has been made. Bounded action diagnostics now record one line per trainer
  open and submitted learn/confirmed-unlearn action without changing behavior.

## Evidence

- `tools/r14_fixes/profession_isolation_kat.lua`: callback-level multiplayer
  isolation fixture.
- `tools/r14_fixes/flight_policy_kat.lua`: compact direct production-module
  matrix fixture, independent of the broader historical mount runner.
- `tools/r9_mounts/mounts_kat.lua`: revised full flight matrix coverage,
  including own/enemy homes, ordinary contested land, Holy Grounds, both
  dragon islands and ocean behavior through the shared production predicate.
  The historical runner currently stops earlier on its stale pre-Skills mount
  inventory expectation; that pre-existing failure is outside this fix.

## Remaining native probe

The minimum next step for the profession report is a two-client Luanti probe
that records the two authenticated player names and each player's
`grug_jobs:learned:cooking` / primary-slot metadata immediately before opening
the trainer and after submitting the learn field. The standalone callback path
provides no evidence for a code change; a native failure would distinguish
wrong player identity before `open_trainer` from unexpected engine metadata.

Search `debug.txt` for the exact marker `[grug_jobs] trainer_`. For each client,
record the `trainer_open` line followed by `trainer_learn` (or confirmed
`trainer_unlearn`). Each line includes `player`, `profession`, `known_before`,
`known_after`, `primary_1` and `primary_2`; compare the two player names and the
before/after values without sharing inventory or unrelated player metadata.
