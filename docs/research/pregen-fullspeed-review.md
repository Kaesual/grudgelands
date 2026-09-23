# Full-speed preparation independent review

Date: 2026-09-23. Reviewer: native GPT-5.6 Sol. The reviewer did not author
the scheduler, fixture, design revision or native instrumentation.

## Code gate: PASS

Reviewed frozen implementation inputs:

- `mods/CORE/grug_core/starts_preload.lua` —
  `858df635037ccd64eef45c6c01a5a838022cae4562e94e8cc46e536631fc780e`
- `tools/r19_preparation_fullspeed/fixture.lua` —
  `d23e48559a8ead4171277f0a4e0cc944cfd2ad1058c73a3553bba0ad1ad87282`
- `tools/r19_preparation_fullspeed/micro.lua` —
  `d2f79cf0e873b451a1c9e18beb17b72ea8b354fa1792dbb095ca8b327000000b`

No Critical, High, Medium or Low code finding remains.

The scheduler admits at most two queue rows and one bounded unresolved surface
scan. It fills only from server steps; callbacks settle their captured row and
may drain a successful contiguous prefix, but never scan or dispatch. Reverse
completion cannot advance over a pending or failed head. A failed row retains
its exact coordinates and selection, retries after five seconds, and stops the
scheduler after three failed attempts. Manual retry waits for all native pending
rows to settle before clearing the stopped state.

Durable state remains the existing contiguous cursor/current-selection format.
The speculative planner has a separate cursor and copied mutable selection;
queued rows capture another selection copy. Committing an inner-Y unit restores
that row's selection before advancing the durable plan, then persists the next
head selection when present. Restart discards only bounded speculative state,
reuses the persisted head selection and recomputes later selections under the
same geometry and source identity. Readiness observes only the durable cursor.

Shutdown sets the scheduler stop flag and submits no work from callbacks.
Outstanding callbacks may persist only a newly successful contiguous prefix;
a cancelled/error head leaves later success speculative for bounded replay.
This matches the engine contract that server stepping stops before emerge
teardown and cancellation callbacks run under the native queue lock. The fixture
uses duplicate block notifications within the advertised callback count and
normal teardown-late settlement; it correctly does not invent a callback after
`calls_remaining == 0`.

Full-mode scan work is bounded to 100 ms checks after 16-column batches and an
8,192-column per-step ceiling, and stops when the two-row queue is supplied.
Starts-only performs no surface scan. Failed, stopped and ready schedulers do no
further fill; a completed restart and an external deep-cave request remain on
the unchanged native `core.emerge_area` route. Engine worker count and global
server cadence are unchanged. ETA uses telescoping wall time between committed
tiles; committing an already-successful second tile with near-zero additional
time correctly divides the overlapped wall interval across both samples.

The actual-scheduler fixture covers alignment and surface envelopes, two pending
requests, pending-time lookahead, reverse completion, distinct callback counting,
head failure with future success, retry/stop/manual recovery, shutdown settlement,
restart replay, partial inner-Y resume, immutable mode/authority, final readiness,
completed restart and external deep generation. The author's LuaJIT development
result, Lua 5.1 parser result, `SETGLOBAL` inspection and five source sweeps are
recorded in `pregen-fullspeed.md`. The coordinator's single frozen final
PUC-5.1/LuaJIT pair passed with byte-identical canonical digest
`db7fda65073b5c54504bda3675a5080960d17d3b67b8be8d798eb22f722389e5`;
the retained receipt is `tools/r19_preparation_fullspeed/evidence/final-parity.json`.
This review inspected that result and did not duplicate it.

## Native evidence gate: PASS

The retained native comparison used the frozen production source and stopped at
the instrumented 561-unit snapshot limit. It dispatched exactly that prefix,
never exceeded two native requests in flight, never refilled from a callback and
recorded request-local identity, start time and action counts. The committed
prefix and action hashes match both retained serial baselines. The run completed
normally with no engine error or surviving process.

Across the matched steady range 101--561, Emerge-0 used 99.43% of one core,
the Server thread used 12.15% and the process used 111.58%. Queue-empty time
between first dispatch and final completion was zero. The same prefix completed
in 135.07 seconds, versus 177.76 seconds for the prior 40 ms serial scheduler.
The maximum measured scan slice was 84.58 ms under the 100 ms cooperative bound;
the maximum observed server-step interval was 127.21 ms. These measurements
support the bounded-pipeline change on this machine and do not broaden it into a
general hardware or whole-world guarantee.

The separate retained two-boot case exercised shutdown with two native requests
pending. Boot A requested shutdown at committed cursor 561; 250 cancelled block
callbacks settled both rows to retry, inflight reached zero, and the durable
cursor remained 561. Boot B loaded cursor 561, replayed the saved head selection,
committed exactly rows 562 and 563, drained its queue and exited normally. Both
boots had maximum inflight two, dispatched nothing after their stop request,
reported no engine errors and left no surviving process.

Luanti encoded Boot B's empty `queue_rows` Lua table as JSON `null`, exposing an
offline receipt-reader `TypeError` after that engine process had already exited
successfully. The retained fix normalizes `null` to an empty list only after the
independent `queue_depth == 0` assertion. Replaying the unchanged logs then
passed byte-identically; no native rerun or production change was needed. The
finding, exact reader diff and originally executed harness bytes are retained.

The immutable 39-artifact manifest is
`tools/r19_preparation_fullspeed/evidence/SHA256SUMS.json` with SHA-256
`6191f13cff3c7f3360badf589fac811c0d6a1c6f17e11359a13c72ef4fea4736`.
The two-boot summary has SHA-256
`340c38158944f60f0278f7e20b75d5b18341701867e420a43758d82eab299b5a`.
The reviewer inspected the retained comparison, shutdown receipts, reader
finding and final parity receipt and did not rerun tests.

## Final verdict

PASS. No Critical, High, Medium or Low finding remains in the production change,
fixture, design contract or retained evidence. This review required one fixture
hardening round before the code freeze and one offline evidence-reader correction;
neither required a production-code correction after freeze.
