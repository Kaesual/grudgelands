# World preparation

Decided 2026-09-21; surface-selection revision approved 2026-09-22 (Round 16).
Bounded full-throughput scheduling approved 2026-09-23.


### Preparation modes and readiness

- Option B only: preparation before players enter normal gameplay. No background
  idle-generation mode and no separately implemented LuaJIT world writer.
- Exactly one Grudgelands boolean in `minetest.conf` selects full-world versus
  starts-only preparation at the **first startup of a fresh world**.
- Persist the selected mode immediately, before queueing preparation. It is
  immutable for that world. Later configuration edits cannot switch the mode.
- Full-world mode replaces starts-only mode; do not queue both schedulers.
- One waiting UI handles both modes, shows actual progress and an estimated
  remaining time when enough timing evidence exists. Players cannot enter the
  unprepared world while the selected preparation plan is incomplete.
- Both modes must stop on a normal server-shutdown request and resume their
  deterministic chunk traversal after restart. Do not complete all remaining
  starts or the full world before shutting down.
- Bounds are named code constants, not additional configuration settings:
  x_min/x_max/z_min/z_max. Select heights from conservative local surface
  envelopes, not one global y_min/y_max slab. Cover both continents, the mainland
  frontier, both islands and a generous ocean margin.
- The ocean margin is **20 mapblocks = 320 nodes**, rounded outward to actual
  generation boundaries. Include land/water surface, exposed cliffs, structures
  and vegetation. Extra air/soil within selected chunks is acceptable. Deep mines,
  deep ocean floors and arbitrary high-altitude flight volumes are outside scope.

### Implementation constraints

- One scheduler and one immutable ordered work list definition for both modes.
  Starts-only uses the deduplicated union of all six necessary start envelopes;
  full-world resolves and generates one horizontal tile's local Y envelope at a
  time in deterministic order. No full-world height prepass or global 3D list.
  Use actual terrain/water/functional/content authority with boundary neighbors;
  center/corner-only samples must not miss narrow peaks or exposed cliff faces.
- Store mode, resolved bounds/order/chunk geometry and the contiguous completed
  cursor together so resume cannot reinterpret the same index differently.
  Full mode persists horizontal tile and inner-chunk progress plus the resolved
  current selection. Do not lose partial-tile completion on normal restart.
  This is current-world persistence, not compatibility with earlier versions.
- Supply the single native emerge worker through at most **two** outstanding
  mapchunk-sized requests. Refill from the main loop only, including selection
  while earlier work runs. Each request owns its outcome; persist only the
  contiguous successful prefix, never a later success across a pending/failed
  head. Failed requests pause new filling and retry their exact coordinates.
  There is no persistent out-of-order journal or custom worker fleet.
- Full preparation selects surface columns in cooperative **100 ms** slices
  per server step, checked after batches of 16 columns with an 8,192-column
  ceiling across that step. One source call/batch can exceed the time budget;
  this is not a hard real-time deadline. Stop early when the bounded queue is
  supplied; never busy-wait for native completion. There is no additional
  work-interval timer; UI notifications retain their separate 200 ms cadence.
  This work applies only while preparation is incomplete. Starts-only mode
  uses the same bounded request pipeline without surface scans. Completed worlds
  perform no preparation scans or dispatches, including after restart.
  Ordinary on-demand generation (including deep caves) retains the engine's
  existing behavior; global server-step and emerge-thread settings are unchanged.
- Derive the aligned mapgen-chunk grid from the engine's actual chunk origin
  and size, including negative coordinates. Each dispatched unit identifies exactly
  one aligned 3D mapchunk and its expected mapblock set. Count distinct successful
  block positions, accepting generated/memory/disk outcomes; duplicate callbacks
  or one successful corner must not mark the whole chunk complete.
- CANCELLED/ERRORED requests never advance the cursor. Bound retries and show
  an actionable stopped/error state rather than incorrectly reaching 100%.
- A completed emerge callback means generated/loaded, not necessarily already
  durable on disk. Verify the normal shutdown save ordering against the shipped
  engine. A partially completed final request may be re-requested on restart;
  existing blocks load instead of being overwritten. Do not promise zero replay.
- Graceful shutdown may finish the current native work unit and necessary
  saves. Do not promise cancellation halfway through a chunk. Lua shutdown hooks
  run after emerge workers stop; do not enqueue work from emerge callbacks or
  rely exclusively on a shutdown hook to break a pre-existing giant queue.
- Before implementing the scheduler, verify the actual stop path: server-step
  termination must prevent deferred dispatch from submitting another unit during
  teardown, while pending emerge callbacks settle without enqueueing directly.
  Prove this with the targeted native stop/resume test; a comment or shutdown
  boolean set only in the late Lua hook is insufficient. If the supported engine
  path cannot provide bounded stopping, report that blocker instead of silently
  adding an engine patch or claiming the contract is met.
- Diagnose the reported starts-only shutdown delay with a small native case;
  do not assert its root cause before measuring the actual engine path.
- Do not guarantee power-loss transactionality between separate map and mod
  storage databases. Any crash-hardening beyond safe bounded replay must be
  justified explicitly; clean stop/restart is the required acceptance case.
- An immutable world mode overrides later config edits visibly in the server
  log. Completed worlds skip preparation on later starts.
- Full-mode progress counts fully completed horizontal tiles, each only after
  all required Y chunks succeed. Starts-only retains completed chunk progress.
  Neither mode counts callbacks or attempts as completed work.
  ETA is approximate; show “estimating” initially, not a made-up duration.
- Retain the existing safe creation/stasis gate; full-world completion satisfies
  the start-readiness interface without running a second generation pass.
- No promise of zero subsequent loading: disk reads, network transfer, client
  mesh construction and travel outside the prepared volume still cost time.
- Do not confuse mapblocks (16 nodes per axis) with generation chunks
  (normally 80 nodes per axis). No 1,600-node ocean margin is required.

Surface walking is the coverage objective; preparing every possible high-altitude
flight view or deep mine is not required. Exact savings are not a deliverable.
The initial ETA can be pessimistic and naturally fall after early progress; this
is accepted and must not trigger estimator tuning. An optional final runtime
estimate may use exactly one 60–120-second generation sample after implementation,
then normal shutdown; no repeated development timing runs or full-world test.

### Surface selection and current-world resume

Full mode walks horizontal tiles in z/x order and selected Y chunks bottom-up.
Each tile reads every terrain column in its local rectangle, including neighboring
columns for cliff exposure and the decoded horizontal reach of vegetation roots.
Water columns retain the real shallow bed down to eight nodes below their surface;
content support and chunk rounding may include additional depth. Functional
crossings and waterfall upper/lower heights join the same local envelope.

Decoded tree rotations and cultural cells provide conservative content height
allowances. Fitted settlement blueprints contribute their actual world boxes;
terrain-relative plots use the writer's reference-column height. Capital avenues
also include their authored neighboring-ground reach. Every start's full readiness
box is included wherever its horizontal footprint intersects a tile. Conservative
content allowances may apply where that content does not spawn.

Selection advances in bounded local batches before the tile's first emerge request.
The current head's resolved Y interval and successful inner-chunk cursor are
stored together. Forward selections and request outcomes are bounded ephemeral
lookahead. On interruption they can be deterministically recomputed/re-requested
from the committed prefix; speculative chunks may already exist and then load
again. This does not advance saved progress over a gap or require a new saved
format. Resume validates engine geometry and stable semantic source/seed and
content-extents identity. Runtime content IDs are excluded from this identity,
because a normal restart may assign different IDs to the same registered nodes.
A mismatch stops preparation with a restoration message; there is no fallback
volume, old-plan reader or migration.

The persisted surface authority also binds a fixed, bounded source digest of
its live terrain/layout constructors and selection adapters. This is calculated
once at load and excludes engine-assigned content IDs; unchanged restarts must
remain stable, while changed terrain or selection semantics reject reuse.

## Scheduling and waiting

Use bounded productive work without artificial selection pauses; decouple UI
notification cadence from scheduler work. Preserve the surface envelope, one
emerge thread, ordered successful-prefix persistence and stop/resume. Constant
CPU utilization is not an invariant. Estimate remaining time from committed
tile progress and elapsed wall time, without summing overlapping request times;
the accepted approximate early-estimation behavior remains.

Pending preparation comes before faction/race/class creation; both page display
and receive-fields actions honor it. Escape dismisses the form without releasing
stasis, allowing the native menu on a subsequent Escape. Routine progress does
not reopen it. A new failure opens the error/retry form once. Readiness continues
creation or releases an existing complete character without regranting its kit.
