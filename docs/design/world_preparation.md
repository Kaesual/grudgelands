# World preparation

Decided 2026-09-21; Round 14 user Go.


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
  x_min/x_max/z_min/z_max/y_min/y_max. Cover both continents, the mainland
  frontier, both islands and a generous ocean margin.
- The ocean margin is **20 mapblocks = 320 nodes**, rounded outward to actual
  generation boundaries. The approximate -100/+300 vertical figures are coverage
  targets, not fixed values; derive them from terrain and surface loading needs.

### Implementation constraints

- One scheduler and one immutable ordered work list definition for both modes.
  Starts-only uses the deduplicated union of all six necessary start envelopes;
  full-world uses a simple bounding cuboid. Avoid coast-following masks.
- Store mode, resolved bounds/order/chunk geometry and the contiguous completed
  cursor together so resume cannot reinterpret the same index differently.
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
- Progress counts distinct completed work units, not callbacks or attempts.
  ETA is approximate; show “estimating” initially, not a made-up duration.
- Retain the existing safe creation/stasis gate; full-world completion satisfies
  the start-readiness interface without running a second generation pass.
- No promise of zero subsequent loading: disk reads, network transfer, client
  mesh construction and travel outside the prepared volume still cost time.
- Do not confuse mapblocks (16 nodes per axis) with generation chunks
  (normally 80 nodes per axis). No 1,600-node ocean margin is required.

Before freezing bounds, report the resulting chunk count and an estimate from
a tiny representative native sample. Surface walking is the coverage objective;
preparing every possible high-altitude flight view or deep mine is not required.
No hours-long full-world generation is an agent acceptance test.
