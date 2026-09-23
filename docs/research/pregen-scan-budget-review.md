# Independent review: full-preparation scan budget

Date: 2026-09-23. Reviewer: native GPT-5.6 Sol, independent of the Astra
implementation and measurement agent. Scope: production scheduler change,
portable regression fixture, full/starts/ready persistence boundaries,
character admission, ordinary deep emergence, shutdown behavior and the single
matched-prefix native comparison. The reviewer ran no engine or additional PUC
runtime.

## Verdict

**PASS.** No open Critical, High, Medium or Low finding remains. The 40 ms
candidate is confined to unfinished full-world surface selection, retains the
existing cooperative and persistence boundaries, and produced a materially
faster identical 561-tile preparation prefix. The evidence does not claim that
the fixture is a native cave-geometry test or that the partial run establishes
a full-world memory or completion-time bound.

## Findings and resolution

1. **High, resolved before the native run — snapshot instrumentation initially
   requested shutdown from the terminal Emerge-0 callback.** That contradicted
   the scheduler's queue-lock boundary and could have made shutdown unsafe or
   the comparison unrepresentative. The frozen instrumentation now sets a flag
   only in the callback; the next Server globalstep sets `stopped`, requests
   normal shutdown and returns before scheduler clock, scan or dispatch work.
   The actual run therefore ended after completion 561 with no dispatch 562.

No production-code defect was found. The earlier wrapper-PID defect from the
diagnosis was not repeated: this harness selected the unique `luanti.bin` whose
exact `--world` argument matched the disposable world, recorded its start time,
and revalidated that identity throughout sampling.

## Safety audit

- The production behavior change is exactly the scan deadline from 4,000 to
  40,000 microseconds. The 16-column check batch, 8,192-column ceiling, 20 ms
  work interval, one pending request, retry/callback rules and persistence
  format are unchanged.
- The budget is read only inside `source and not state.selection`, itself inside
  `state.total`, `not ready()`, `not pending`, `not failed` and retry guards.
  `source` is assigned only for the persisted immutable `full` mode. Starts-only
  therefore never calls either surface function; completed full worlds cannot
  scan or submit preparation work, including after restart.
- The 40 ms value is cooperative rather than a hard deadline. Time is checked
  after each 16-column batch, and one source call or batch can overshoot. The
  frozen fixture verifies an 80-column cutoff with 500 microseconds per column,
  the 8,192-column coarse-clock cap, and that shutdown between steps performs no
  later scan or dispatch.
- Readiness persistence remains `cursor == total`. The fixture constructs a
  current-format plan at its final tile, completes it, replaces both surface
  methods with throwing functions, and observes no preparation work over 100
  steps. It repeats this after reload.
- The actual character gate is unchanged and uses the same readiness state:
  `grug_classes` keeps incomplete players locked, blocks race/class display and
  receive-fields actions, and releases only after `world_preparation_status().ready`;
  `grug_factions` rejects spawn preparation and faction commits before ready;
  start NPCs require `start_ready`. Full mode therefore remains exclusive from
  ordinary admitted play until the full plan completes.
- The scheduler neither replaces nor wraps `core.emerge_area`. After ready, the
  fixture submits an unrelated request at y=-4096, verifies its exact bounds and
  generated callback, and observes no renewed preparation work or cursor change
  before or after reload. This directly verifies scheduler/API routing. It does
  not substitute for the separately retained user GUI cave check, but the
  production diff changes no mapgen, cave, emerge-thread or global-step setting.

## Evidence verification

- The candidate used the same seed 8675309, Luanti/LuaJIT build, engine SHA-256,
  configuration, single emerge thread and exact tile range 1–561 as the baseline.
  Comparison stops by completed cursor rather than elapsed time or a different
  geographic endpoint.
- Offline replay of `compare.py` reproduced `comparison.json` byte for byte.
  The dispatch/selection prefix and per-request action-delta hashes match; both
  runs end at bounds `(1248,-32,-3152)` through `(1327,47,-3073)` with 561
  generated and 69,564 memory callbacks. The claim is correctly limited to
  prefix/action identity rather than SQLite or node-byte identity.
- From mods loaded through tile 561, elapsed time fell from 386.52 to 177.76
  seconds, a 2.17 times throughput result. Across matched tiles 101–561, request
  duration stayed 216.78 versus 216.95 ms while mean dispatch gap fell from
  524.16 to 77.81 ms. Corrected one-core CPU rose from 32.70% to 82.05%, driven
  mainly by Emerge-0 rising from 28.92% to 73.02%.
- Candidate globalstep cadence remained near 90 ms: mean 90.289 ms, maximum
  100.510 ms, p99 bucket `[92,93)` ms. Maximum reported scan work was 40.417 ms.
  Peak sampled RSS growth from 2.75 to 2.98 GB is disclosed without unsupported
  attribution or extrapolation.
- The engine was identified 72 ms after launch with zero accumulated CPU ticks.
  It exited normally with code 0 after the Server-step stop, produced no native
  error and left no diagnostic survivor; the personal GUI process was not
  targeted.
- All changed Lua passed the plain-5.1 parser, SETGLOBAL check and five explicit
  source sweeps. The coordinator's single frozen PUC-5.1/LuaJIT fixture pair
  produced identical canonical SHA-256
  `f0312a1e2228fdfa4c556db0b57fa6fb639805e62b5953c11629879638b76a7b`.
  Its four recorded source hashes still match the reviewed files. The 21-entry
  retained evidence manifest verifies without mismatch.

The measured result supports delivering this bounded constant change. It does
not authorize broader scan tuning, a shorter global server step, more emerge
threads or a background preparation mode.
