# World preparation

Decided 2026-09-21; surface-selection revision approved 2026-09-22 (Round 16).


### Confirmed by the user

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
- First version: one mapchunk-sized request in flight. Persist the completed
  prefix only after all relevant block callbacks succeed, then defer the next
  dispatch through the main loop. This avoids out-of-order completion journals
  and an enormous emerge queue; do not add a custom worker fleet.
- Derive the aligned mapgen-chunk grid from the engine's actual chunk origin
  and size, including negative coordinates. Each work index identifies exactly
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
