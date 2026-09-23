# Full-speed world preparation

User authorization: 2026-09-23. The user requests maximum useful generation
throughput until preparation is complete, since players cannot play yet.
This supersedes the earlier one-outstanding-request scheduling constraint,
while retaining bounded shutdown, deterministic coverage and later-game safety.
Branch: `perf/preparation-fullspeed`, baseline `82a1491b`.

## Work split

- Root Astra: orchestration, contract, integration and final interpreter pair.
- Native Astra `pregen_fullspeed_design`: production scheduler and portable
  regression fixture, implementation report.
- Native Astra `pregen_cpu_diagnosis`: isolated native comparison harness and
  measurement evidence; no production Lua ownership.
- Independent native Sol `idle_heal_preflight`: scheduler correctness, engine
  contract, measurement preflight and final evidence review. The prior reviewer
  could not be reactivated within the available thread limit; this reviewer has
  not authored the preparation implementation or instrumentation.

## Contract

Keep the one native emerge worker supplied through a bounded pipeline, initially
at most two mapchunk-sized requests plus one incremental next-tile selection.
Refill only from server steps, including selection work while a request runs.
Do not enqueue from emerge callbacks, spin on pending work or precompute the
whole world. Scan work remains cooperative and bounded so the engine can process
callbacks, waiting UI and shutdown. Prefer useful sustained work over artificial
delays; no promise of 100% utilization during disk/lock waits or cached requests.

Use the unchanged immutable mode, surface authority, coverage and traversal.
Persist only the contiguous successfully completed prefix, including inner-Y
progress. Each request owns its expected-block set, outcome and checkpoint;
out-of-order successes cannot jump over a failed or unfinished head. Preserve
bounded retries, five-second backoff and stopped-state UI. No readiness until
every selected unit is committed.

Forward selection is ephemeral to avoid a persistent out-of-order journal or
saved-format change. An interruption may rescan/re-request bounded speculative
work from the same immutable authority. Already generated blocks can be loaded
again. A speculative request is not durable completed progress until the prefix
reaches it. Record this explicitly in the living design; the old assertion that
every unpersisted selection has generated nothing no longer applies to lookahead.

After readiness, failure or shutdown the preparation scheduler must become idle
as appropriate. Completed-world reload must not restart it. Ordinary player-
driven generation, especially deep caves, retains its existing behavior. Neither
native emerge-thread count nor global server-step configuration changes.

Engine note: the dedicated loop caches its step setting on entry
(`reference_projects/luanti/src/server.cpp`, `dedicated_server_loop`), so changing
the setting from Lua later is not a safe temporary acceleration/restoration
mechanism. A pipeline avoids that dependency.

## Verification budget

- LuaJIT development fixture loads actual scheduler. Cover two-request bound,
  out-of-order completion, head failure followed by later success, retries,
  duplicate/late/cancel callbacks, shutdown and contiguous persistence;
  retain coverage, immutable mode/authority, inner-Y resume, starts-only and
  completed-world/external-deep-request checks.
- Plain-5.1 parser, SETGLOBAL and all five static sweeps for changed Lua.
  On frozen reviewed code root runs one compact PUC/LuaJIT pair with identical
  canonical output. No intermediate or exhaustive PUC execution.
- One fresh native comparison, identical engine/seed/disk and 561-unit prefix
  as retained baselines; maximum seven minutes. Snapshot-only cap must prevent
  dispatch beyond 561, then drain normally and request shutdown on Server step.
  Instrumentation captures per-request local IDs, not a shared latest counter.
- Measure CPU on the verified engine PID/start time, useful throughput, actual
  cadence, scan slices, inflight bound and shutdown. Compare identical geography.
  One additional two-boot native stop/resume case is authorized because the
  pipeline changes cancellation boundaries: reuse the disposable comparison
  world, stop with two pending requests, then reload the saved prefix and finish
  a bounded couple of requests. Separate logs, at most 60 seconds per boot;
  no broad benchmark or full-world run.

ETA must avoid double-counting overlapping work; only the minimal accounting
adjustment is in scope. Early estimation behavior is not being tuned.
Unexpected architectural expansion pauses for user discussion. If the bounded
candidate is correct and measurably improves sustained throughput, integrate
after independent review and sync locally; remote deployment is separate.

## Status

Implementation and independent production-code review PASS. The single frozen
PUC-5.1/LuaJIT pair passed with identical output
`db7fda65073b5c54504bda3675a5080960d17d3b67b8be8d798eb22f722389e5`.
Native measurement and final independent evidence review PASS. Same 561-unit
prefix: 135.07 s versus 177.76 s for the previous scheduler; matched native
worker CPU 99.43% of one core. Two-pending stop/resume passed. Implementation
and calibration details: [receipt](pregen-fullspeed.md). Merged into local main
as `19acb7a8` and synchronized; no remote push or production deployment.
