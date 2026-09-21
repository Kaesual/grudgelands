# Round 14 preparation work record

Implementation in progress; independent review and final interpreter pair pending.

## Interface and ownership

`grug_core.world_preparation_status()` returns mode (`starts` / `full`),
completed/total chunk counts, percent, ready, failed and optional eta_seconds.
ETA remains absent until three successfully completed timed units. Timing is
approximate and includes cold worker initialization in the early average.
`register_on_preparation_progress(fn(status))` publishes from the throttled
server step, at most five times per second. Existing starts readiness reports
0/6 until the entire selected preparation plan completes, then 6/6. Existing
start listeners fire on readiness/failure, not every full-world chunk.
`request_starts_preload()` explicitly retries a stopped failed unit without
changing the plan/cursor or creating another scheduler. Root owns creation UI
and reconnect stasis; the faction spawn loader rejects entry before readiness.

Exactly one boolean, `grug_prepare_full_world`, defaults false. Mode is saved
at mod load before anchors resolve. The single serialized storage record then
contains resolved traversal geometry, order, bounds/list and completed prefix.
Changed settings are visibly ignored on restart. No old preload-marker reader,
world migration or duplicate starts queue exists.

## Bounds and count

Source `wp40/source/simple_map.lua:153–166` defines additive mainland primitives:
outer prongs reach z=-2960/+2970. Island polygons at lines 180–181 reach
x=-3440/+3440. Bays at z=±3660 are **subtractive water masks**, not additive land.
The source extent x=±3600, z=±3200 encloses all these land shapes. Add 320 nodes
(20 mapblocks) on each side, then round outward on the active engine chunk grid.

Unaligned bounds: x=-3920..3920, z=-3520..3520, y=-100..457.
The upper target is mountain maximum 360 + detail 16 + water level 1 +
80 nodes of surface-loading headroom. Secondary landmarks replace/blend relief
profiles rather than stacking another mountain above one. The deep ocean bed
is water level minus 24 (`height.lua` exterior-bed branch); the lower target
provides surface and shallow-underground coverage, not exhaustive deep mining.

Default five-mapblock chunks have origin -32 and width 80 nodes. Resolved
inclusive node bounds: x=-3952..3967, z=-3552..3567, y=-112..527.
Count: **99 × 89 × 8 = 70,488 chunks**, each expecting 125 distinct mapblocks.
The real six-start plan for seed 8675309 contains 90 deduplicated chunks.
No full-world population is an agent test.

## Native shutdown prerequisite

Before scheduler implementation, `run_stop_probe.py` booted a minimal isolated
singlenode game three times. Every boot requested normal shutdown while one
80³-node request was pending. Each delivered all 125 distinct successful
mapblocks, advanced exactly one cursor, and exited; restart observed cursor
1, then 2. The deferred callback never ran during teardown. Shutdown hooks
followed the request by about 91 ms. Logs: `tools/r14_pregen/evidence/boot*.log`.

Source ordering: Luanti `src/server.cpp:372–385` stops the server thread before
joining emerge workers; `:390–436` invokes shutdown hooks, destroys/saves the
map, then commits mod storage. `src/emerge.cpp:339–344` supplies the chunk grid
origin formula, including negative coordinates. The scheduler only queues from
a server step, never an emerge callback. Late Lua shutdown hooks are a secondary
guard, not the mechanism that prevents dispatch during native teardown.

A request records its cursor only after every expected mapblock reports
GENERATED/FROM_MEMORY/FROM_DISK, counting each position once. Cancellation,
errors or missing positions never advance the prefix. At most three attempts
run before an actionable failure; explicit retry/restart resumes that unit.
Normal stop may finish the current native mapchunk, cancel other queued block
callbacks within that request, save the world, and replay that final request
on restart. No cross-database power-loss atomicity is claimed.

## Checks

`python3 tools/r14_pregen/static.py`: plain-5.1 parser, SETGLOBAL and all five
source sweeps, including lane Lua under tools. The pre-existing faction command
help literal `[throng|accord]` is a reviewed string false positive.
`luajit tools/r14_pregen/kat.lua .`: aligned positive/negative bounds, complete
ordered volume count, deduplicated starts, duplicate callbacks, cancellation,
bounded failures, explicit retry, mode immutability, cursor restart, completed
skip and no premature full-mode readiness. This portable fixture is ready for
the root-coordinated final PUC/LuaJIT pair; no PUC runtime has been run here.

## Production native evidence and estimate

`run_native.py` copied one immutable production snapshot, restricted full mode
to two chunks in that snapshot only, and ran starts/full with two restarts each.
Starts progressed 0/90 → 1/90 → 2/90 → 3/90 across boots. Each boot stopped
while the second request was pending; that cancelled request never advanced
the cursor, and the next boot requested exactly that unit again. Full progressed
0/2 → 1/2, then 2/2 on restart; its third boot dispatched **zero** units.
Changed configuration was ignored visibly in both directions. Shutdown latency
from normal request to Lua shutdown hook was 0.508 seconds (full), and
0.668/0.943/0.825 seconds (starts). No errors or ModErrors occurred.

A final tiny three-chunk sample on a second immutable snapshot completed actual
Dawnmere-area surface chunks in 16.472 s cold, then **0.609 and 0.940 s warm**.
The first request includes emerge-worker initialization. Scaling the two warm
samples to 70,488 units, plus up to 0.2 s deferred-dispatch spacing per unit,
gives an illustrative **about 16–23 hours**. This is not a representative full
world benchmark or a delivery promise: ocean, empty upper layers, underground,
cities and worker/disk conditions have different costs. The UI estimates from
actual progress and initially says estimating. No full-world run was performed.

Cold initialization was 15–16 seconds in the restart runs too. Stopping during
that first native work unit may therefore take that long; subsecond stopping
is not guaranteed. The measurements establish bounded stopping on the supported
engine path, not a retrospective diagnosis of the old scheduler's reported delay.
There was no controlled old-code timing comparison.

Evidence logs are `tools/r14_pregen/evidence/{starts1,starts2,starts3,full1,full2,
full3,timing}.log`; full input SHA manifests are `restart-snapshot.json` and
`timing-snapshot.json`. The restart snapshot predates only the explicit UI retry
addition in the scheduler; the final timing snapshot includes it. Test-only
bounds/probe differences are confined to the copied game. All scratch games,
worlds, configuration and XDG paths were under `/tmp`; personal worlds were
never accessed. The reference engine and production mapgen were not changed.

## Handoff

Final static and LuaJIT checks pass. Root coordinates independent review and
exactly one final bounded interpreter pair. Runtime playtest: choose each mode
on separate fresh worlds, observe estimating/progress, stop and restart during
preparation, change the boolean and confirm the logged immutable mode, reconnect
an existing character during preparation and verify stasis, then verify normal
entry after completion. Full-world completion is user-operated, not an agent
acceptance benchmark.
