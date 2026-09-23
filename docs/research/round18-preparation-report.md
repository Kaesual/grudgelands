# Round 18 G — Surface preparation scheduler

Implementation: native Astra, 2026-09-23. Independent fresh-Astra review and
root's integrated final PUC/LuaJIT pair remain pending. Scope is the scheduler,
a bounded portable fixture and its evidence; source/planner output is unchanged.

## Diagnosis and decision

The existing scheduler runs at 0.2-second intervals, visits only 512 columns per
scan, and unconditionally returns after finishing selection. Even cheap column
sampling therefore leaves repeated idle intervals before native work begins.
A short pre-change diagnostic using the production scheduler, a 20 ms synthetic
server step and a one-microsecond-per-column source selected all 6,724 columns
of an 82-by-82 tile in 165 steps (3.30 simulated seconds), despite only 6.724 ms
of source work. This includes interval rounding and the final dispatch wait.
This deterministic counter experiment isolates artificial sleeps; it is not a
measurement of the user's source cost, storage latency or machine CPU use.

The changed scheduler uses a 4 ms elapsed-time scan budget, checked every 16
columns, with an 8,192-column hard ceiling if the clock is coarse. It runs at
most every 20 ms and dispatches immediately when selection finishes. The same
synthetic case takes two steps (40 ms), visits exactly the same 6,724 columns
and leaves one pending emerge. Progress listeners retain a 0.2-second minimum
notification interval. Time budget is cooperative: setup and one batch/source
call can exceed it; native emerge and storage are outside its preemption scope.

Phase separation is deliberately small: fixture source-call counts/timestamps
identify selection work; server-step counts identify scheduler waits; dispatch
and callback guards identify pending emerge; persisted snapshots check storage
boundaries; separate cancellation/duplicate/error cases exercise retries. The
native stop/resume log records dispatch, final callbacks, cursor and shutdown.
It does not independently profile disk flushing or native callback queue delay.
No broad profiler or speculative lookahead queue was added.

## Preserved contracts

- Status/listener API and tile-based percentages are unchanged, including
  `mode`, `completed`, `total`, `percent`, `ready`, `failed`, `eta_seconds`.
- Every source column and all conservative Y extents remain selected. No changes
  to preparation source, manifest, planner, water/content reach or start envelopes.
- Exactly one pending emerge; no enqueue from completion/cancellation callbacks.
  Native cancellation callbacks hold the queue mutex (`reference_projects/luanti/
  src/emerge.cpp:496–507`); the callback remains persistence/notification only.
- Mode and source identity remain immutable for a world; ordered success-prefix
  storage, inner-Y resume, retry limit/delay and explicit retry remain intact.
- Shutdown guards stop selection/dispatch while allowing pending callbacks to
  settle the actual successful prefix. `num_emerge_threads = 1` is unchanged.
- ETA's accepted early correction is unchanged. Remaining queued native work
  may still cause low CPU use or motionless tile-based progress.

## Evidence

`tools/r18_preparation/evidence/` contains source hashes, LuaJIT output, static
results and the trimmed native log. Portable invocation, also suitable as one
component of root's final paired runner:

```lua
io.write(dofile(repo .. "/tools/r18_preparation/fixture.lua")(repo))
```

The fixture exercises flat/peak/cliff/coastal height envelopes, start settlement
coverage, noncubic geometry, batch-independent selection, slow-source budget,
coarse-clock ceiling, UI cadence, single pending request, duplicate callbacks,
cancellation, bounded failure/retry, mode lock, partial-scan restart, persisted
inner-Y resume, success/cancellation during shutdown and source identity refusal.
Parser and SETGLOBAL pass for both Lua files (no global writes). All five sweeps
ran across `mods/*/grug_*` and the fixture: existing matches are comments or
string payloads; the changed files have none. No PUC runtime was run here.

The existing `tools/r16_surface/run_native.py` ran once as a two-boot functional
stop/resume check, using an immutable copied game in
`/tmp/grug-r16-surface-native-u7cqlg5g`. Both boots exited 0. Each dispatched two
requests, completed one tile and cancelled the second at shutdown; the second
boot resumed at cursor 1, ignored a changed configured mode and reached cursor
2. Five real authority columns passed their conservative coverage assertions in
each boot. Both completed requests spent approximately 16 seconds between
request and terminal callback: native emerge/wait remains substantial. This
small boundary run cannot predict full-world throughput or explain every CPU
fluctuation. No optional 60–120-second ETA observation or full-world run occurred.
The runner's existing unrelated vendor-price warnings were present; no ERROR.

## Runtime acceptance

On a fresh test world, start preparation, verify responsive waiting/menu UI,
stop during preparation and restart. Confirm the percentage resumes from the
successful prefix, the selected preparation mode remains fixed, and completion
releases character creation. A real plain-5.1 engine GUI test remains separate
from the final portable parity check.
