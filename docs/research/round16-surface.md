# Round 16 surface preparation — lane G

Implemented on `wp16-surface`; independent review and integrated final parity
remain coordinator-owned. No writer projection or planner tuple changes.

## Selection and persistence

`preparation_plan.lua` walks 8,811 horizontal tiles on the usual 5-mapblock grid,
with the unchanged 320-node ocean margin and negative-coordinate alignment.
Each tile resolves its conservative local vertical interval before any emerge
request. Every column is sampled, including neighbors and content-root reach;
512 columns are resolved per scheduler pass. This is local incremental selection,
not a world prepass or a separately persisted planning phase.

`wp40/preparation_source.lua` reads the existing `column_values_at` tuple:
terrain, water, functional surface, waterfall/rapid upper and lower heights.
Shallow water retains the bed through eight nodes of water; deeper seabeds are
outside this surface-travel preparation. Actual decoded template rotations and
cultural cells provide root reach and height/support allowances. Settlement boxes
use prepared blueprint bounds and the same anchor/reference-column transformation
as `r7_settlement.lua:base_of`. Avenue overlays add their authored reach/half-width
neighborhood and authorized local box; the template allowance also conservatively
covers their lamps above the local ground/deck envelope. Activation anchor roots
are included from the real anchor roster. All six start readiness boxes are folded
into the affected tiles.

Only the current resolved interval and its successful inner-chunk cursor are
stored. An unfinished scan may restart; completed inner chunks do not replay.
After the last Y chunk, the horizontal cursor advances. A tile is never counted
from an individual callback or an incomplete chunk. Existing distinct mapblock
accounting, sticky failure, bounded retry, one request in flight and deferred
server-step dispatch remain intact. Starts mode retains its deduplicated list.

The selected world mode still persists immediately and ignores later setting
changes. Geometry and the stable semantic source/seed/content-extents fingerprint
are checked at restart. A missing or mismatched authority fails with an actionable
message rather than choosing guessed heights or a fallback volume.

## Evidence

- `tools/r16_surface/fixture.lua(repo)` is the compact callable scheduler/selector
  fixture: flat land, a one-column peak, cliff immediately outside the tile,
  negative/non-cubic alignment, full start readiness, successful tile completion,
  duplicate/cancel callbacks, retry exhaustion/retry action, immutable mode,
  completed-world restart, partial-tile restart and authority mismatch.
- `tools/r16_surface/content_fixture.lua(repo)` loads the real adapter and selector:
  template crown/support across Y boundaries, root reach, shallow/deep water,
  bridge and waterfall tuples, fitted anchor/reference structures, avenue reach
  and activation roots. Both fixtures passed under LuaJIT. They replace the old
  fixed-volume expectations in the historical `tools/r14_pregen/kat.lua`.
- `tools/r16_surface/static.py`: plain Lua 5.1 parser, SETGLOBAL inventory and all
  five sweeps, explicitly including tools. No global writes. The only sweep hits
  are existing literal pipes in Character information strings. Use `LUAC51` to
  select the parser in a worktree without its ignored tools/bin build.
- Native correctness snapshot: `tools/r16_surface/evidence/boot1.log`, `boot2.log`
  and `snapshot.json.gz`. Two boots of one disposable world with seed 8675309,
  five actual column/adapter samples per boot, and at most two emerge requests
  per boot. The first request succeeds; normal shutdown is requested during the
  second. Its blocks can already be available and legitimately complete. The
  observed cursor is 2 after boot one; boot two restores 2 and finishes at 4.
  There is no third request during teardown, no error, and the changed boolean
  is visibly ignored. Both boots publish an identical semantic authority hash.
- Native samples include outer ocean (-23 bed / +1 water, clipped local envelope
  -10..34), land heights 9, 18 and 74, and a shallow coast (-2 bed / +1 water).
  These are authority integration checks, not a whole-world coverage census.
- Initial native correctness attempt exposed a restart defect in the candidate:
  the complete R7 manifest includes runtime CIDs, so its hash can differ after
  a normal restart. Replaced that fingerprint with stable source/seed plus the
  decoded reach and fitted boxes; strict live manifest construction remains.
  That failed candidate never advanced its tile cursor; the fixed candidate
  passes restart. Initial failed logs are retained separately for traceability.
- The first corrected native harness expected exactly one completed tile on stop.
  Both requested chunks actually succeeded before shutdown. Validation was fixed
  to compare the next boot with the recorded successful cursor, then applied to
  the existing logs. No extra engine run was made for this harness correction.

The engine shutdown order is unchanged: `src/server.cpp` stops the server thread
before stopping emerge workers and invokes Lua shutdown after worker settlement;
map/environment saving follows. Callbacks only record completion; only server
steps dispatch. The current native logs exercise this order with the new selector.

No PUC runtime was executed by this lane; the coordinator runs the compact final
pair on frozen integrated bytes. No full world, seed fleet, PERF campaign, savings
comparison or ETA timing sample was run. The initial estimate remains deliberately
unchanged. GUI travel and fallback-engine acceptance remain user tests.

## Runtime test plan

Create a fresh full-preparation world, confirm the surface waiting screen, stop
normally partway through preparation and restart with the setting changed. It
must keep full mode and resume without resetting progress. After completion,
visit a settlement, a tall wooded slope/cliff and a shallow coast; enter all six
starts normally. Repeat a fresh starts-only world to check its bounded wait.
