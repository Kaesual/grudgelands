# Preparation pipeline implementation

Date: 2026-09-23. Implementation for the user's full-speed preparation Go;
contract: [bounded preparation pipeline](pregen-fullspeed-plan.md).

## Scheduler behavior

`starts_preload.lua` now keeps at most two native mapchunk-sized requests in
its preparation queue. Both starts-only and full preparation feed that queue
from server globalsteps. Full mode scans the next required tile while the
preceding native request is outstanding. It stops scanning once the queue is
supplied; there is no whole-world prepass, worker fleet, busy wait or additional
20 ms scheduler interval. Progress notifications retain their separate 200 ms
cadence.

A shared per-step surface scan budget is 100,000 microseconds, checked after
16-column batches, with a hard ceiling of 8,192 requested column visits. A final
partial batch can consume fewer actual visits. These cooperative bounds return
control for callbacks, UI and shutdown; a slow source call can exceed the time
budget. No extra wait is scheduled between productive steps. This does not
promise constant 100% CPU: native locks, disk operations, faster-than-step
requests and the unchanged server cadence remain relevant.

The native emerge thread count, global settings, engine, mapgen/cave code and
`core.emerge_area` API are unchanged. Only incomplete preparation enters the
scanner/refill path. Completed worlds, including a completed-world restart,
perform no further preparation scan or dispatch. Starts-only mode never calls
the full-mode surface authority.

## Persistence, errors and stopping

A separate speculative planner shares immutable geometry and bounds with the
saved plan, but owns its own cursor and copied selection. Each queued request
captures its coordinates, selection and distinct expected block set. Callbacks
record their own terminal outcome; only a contiguous successful queue prefix
advances the durable cursor. Later successes cannot skip an earlier incomplete
or failed request. Each head transition persists the existing current-format
state, including partial inner-Y progress and the next current selection when
one exists.

At most two queued requests and one unresolved scan are transient. Future tile
selections and out-of-order success are not a durable journal. After restart,
the saved current selection resumes directly; speculative future selections may
be scanned again and previously generated chunks re-requested under the same
validated source authority and geometry. Existing native blocks then load.
This is bounded current-world replay, with no old-format reader or migration.

Failure pauses speculative filling. An exact request retries after five seconds;
three failed attempts stop preparation until explicit retry or restart. Successful
later outcomes remain available for ordered commit after the gap succeeds.
Callbacks never dispatch, including cancellation callbacks during teardown. Late
successful callbacks may persist the contiguous prefix. Normal shutdown stops
server stepping before worker teardown; a late Lua shutdown hook additionally
guards subsequent scheduler steps. The queue is bounded, but native generation
is not interrupted halfway through a chunk.

Readiness derives only from the committed final prefix. Existing stasis and
creation gates remain authoritative. ETA still starts as estimating and uses
committed tile samples; elapsed time is measured between tile commits so
concurrent scan/native request time is not added twice. No early-estimate tuning
or new ETA smoothing was introduced.

## Portable validation

The new actual-scheduler fixture in
`tools/r19_preparation_fullspeed/fixture.lua` retains coverage/alignment checks
from the previous single-request fixture and replaces obsolete single-pending
expectations with the pipeline contract. Development execution under LuaJIT
passes. It covers:

- Surface coverage, negative alignment, a narrow peak, neighboring cliff,
  non-cubic geometry, coastal heights and all start readiness envelopes.
- Two outstanding requests in starts and full modes, productive scanning while
  a request is pending, independent notification cadence and shared cooperative
  scan/count limits, including a coarse clock.
- Reverse completion order, duplicate block positions, a missing expected block,
  cancellation/error outcomes, five-second retry, the three-attempt stop and
  manual retry while retaining a successful later result.
- Shutdown-settled successful callbacks, a cancelled prefix gap with speculative
  success, deterministic restart replay, partial unresolved selection and saved
  inner-Y progress; authority mismatch still rejects the state.
- Immutable world mode, completion/race readiness, completed-world restart and
  ordinary external deep-cave request coordinates/callbacks without restarting
  preparation.

Here duplicate callbacks mean duplicate block-position notifications within a
request's advertised callback count. Late callbacks mean normal outstanding
callbacks settling during shutdown. The fixture does not invent another callback
after the engine has already reported `remaining == 0` for that request.

The three changed/new Lua files pass `tools/bin/luac51 -p`; opcode inspection
finds no `SETGLOBAL` writes. All five source sweeps were run across owned game
mods and explicitly across the new tool Lua. Hits are existing comments/string
data; the changed Lua adds no prohibited construct. No PUC runtime was used for
development. The coordinator ran the single frozen final PUC/LuaJIT parity
pair after independent code PASS. Both executions passed, with byte-identical
canonical output SHA-256
`db7fda65073b5c54504bda3675a5080960d17d3b67b8be8d798eb22f722389e5`.
Runtime was 40.5 ms under PUC 5.1 and 9.9 ms under LuaJIT; the source hashes and
receipts are retained in `tools/r19_preparation_fullspeed/evidence/final-parity.json`.

## Native throughput

The one authorized fresh comparison generated the same 561-unit prefix with
the same engine, seed, one native emerge worker, ordinary 90 ms server setting
and disk-backed scratch world as both retained baselines. Measurement starts
at the common post-mod-load event and ends at committed prefix 561:

| Scheduler | Prefix elapsed | Matched steady emerge-worker CPU | Matched process CPU |
| --- | ---: | ---: | ---: |
| Original 4 ms serial | 386.52 s | 28.92% | 32.70% |
| Previous 40 ms serial | 177.76 s | 73.02% | 82.05% |
| Bounded two-request pipeline | 135.07 s | 99.43% | 111.58% |

CPU percentages are relative to one core, from five-second OS sample intervals
wholly inside matched tiles 101–561. The new run spends 24.0% less elapsed time
than the previous optimization (1.316× throughput), and 65.1% less than the
original baseline. The process exceeds one core because surface selection on
the Server thread uses another 12.15%; there is still exactly one native emerge
worker. This is a bounded surface-prefix observation, not a guarantee of constant
100% CPU across different hardware, terrain, disk waits or a complete world.

Observed outstanding requests never exceeded two; between first dispatch and
final completion, the measured queue-empty time was zero. Request residence
includes waiting in that queue and must not be described as native generation
service time. Actual maximum server-step interval was 127.21 ms, with p99 in
[100,101) ms; maximum measured scan slice was 84.58 ms. Sampled peak RSS was
2.89 GB. The normal drained exit had no engine errors or surviving processes.

The work-prefix hash is
`a563b8ac8fb44211d04035d58b739b8f45743039ed9a3e7a3daf95e618a77d30`
for all three runs, over request ID, bounds and selection. Unlike the older
serial-only comparison, this representation excludes the observed committed
cursor at dispatch: lookahead legitimately dispatches before that cursor catches
up. The comparator separately verifies contiguous committed progress. Per-request
action hash remains
`dad3858337b83b9fc81ebb020b941cf4a18a94598bbfa7bf387619356c6f0d3c`.
Only the scheduler differs among the copied game source manifests. These are
work/action identity checks, not a comparison of every generated node/database.

The [harness](../../tools/r19_preparation_fullspeed/README.md) and retained
evidence include the exact disposable instrumentation, source hashes, engine
identity, phase/thread logs and offline comparison. No full-world test, personal
GUI/world access, remote push or production deployment was performed.

## Shutdown and review

The authorized two-boot native case reused only the disposable comparison
world. Boot A requested shutdown from a server step with exactly two requests
pending. Native teardown cancelled their 250 mapblock callbacks; committed
progress stayed at 561 and the resolved next selection remained persisted.
No request was submitted after stop, and both pending requests settled before
the shutdown receipt. Boot B reloaded that exact prefix, completed units
562–563, drained its queue and shut down normally. Each boot remained below
its 60-second cap. Stopping may still wait for initial native worker setup or
the current unit; it does not cancel a chunk halfway through generation.

An offline receipt reader initially treated the engine's JSON `null` for an
empty queue as a Python list. The reader was corrected to accept null only for
queue depth zero and reconstruct its summary from the same retained logs; no
engine rerun or production change was needed. The executed harness bytes and
the reader-only correction remain in the evidence package.

[Independent Sol review](pregen-fullspeed-review.md): final PASS for production
code, fixture, design, native comparison, stop/resume and interpreter parity.
All 39 retained artifact hashes and frozen final Lua inputs were verified again
by the coordinator before integration.

Calibration: native GPT-6 Astra implementation and measurement, native GPT-5.6
Sol independent review; 0 Critical/High/Medium/Low production findings and zero
production fix rounds. One pre-run measurement-harness hardening round and one
post-run offline receipt-reader correction; neither changed production code.
Observed overall/reviewer wall time was not instrumented (`unknown`). Native
comparison took 155.76 seconds including startup/shutdown, followed by the two
authorized boots of 37.12 and 36.67 seconds. No further native run was performed.

## User runtime acceptance

After installing the new version and restarting the server, observe full-world
preparation, stop it once and verify progress resumes on restart. Once preparation
is complete, normal play and exploration of new deep cave chunks should retain
their existing behavior. The bounded headless measurements and portable routing
fixture do not replace this user-run GUI/multiplayer acceptance.

## Local delivery

Implementation commit `23439c97`, merged into local main as `19acb7a8`.
Synced from main using `tools/sync_to_luanti.sh`; the installed scheduler is
byte-identical and all frozen final-parity source hashes remain unchanged.
No remote push or production-server deployment was performed. Restart loads
the new scheduler; its persisted format and surface-source identity are unchanged.
