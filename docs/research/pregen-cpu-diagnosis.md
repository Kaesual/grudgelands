# Full-world preparation CPU diagnosis

Date: 2026-09-23. Diagnostic observation only; no production change or game sync,
personal-world change, or remote operation. Documentation and compact evidence
may be committed separately. Source revision:
`4d7903e891497041b6fb9833a599b3acb87d2d18`.

## Finding

The observed CPU decline is primarily consistent with **cooperative surface
selection starving the single emerge worker between requests**. Preparation
scans at most roughly 4 ms of surface work per server callback, but the actual
callback cadence is approximately 90 ms. The configured 20 ms work interval
does not schedule additional callbacks. Surface scans and native emergence are
serial phases; no request is queued while the next tile is being selected.
Repeatedly increasing completion-to-dispatch gaps account for a growing share
of elapsed time even though request duration remains short.

This is an observed pacing bottleneck, not evidence of a broken thread count,
a CPU leak, or a disk bottleneck. The measurements establish the broad cause
locally; they do not identify which individual surface-authority subroutine
accounts for changing scan cost, or prove a monotonic trend across the world.

## Method and scope

One real native headless run used a fresh disposable world and a copied game.
The engine was Flatpak Luanti 5.17.0, LuaJIT 2.1.1784272936, seed 8675309,
`grug_prepare_full_world=true`, `num_emerge_threads=1`, default
`dedicated_server_step=0.09`, and unchanged production preparation budgets,
scan batches/caps, traversal, callback handling and persistence semantics.
The real engine executable SHA-256 was
`8f7355f928237fed68717237aff52c7a4944535cab7964f2fc1d0cf99c57de54`.
All 16 logical CPUs were in its affinity mask. A separate pre-existing GUI
process was neither sampled nor stopped.

The disposable world resided on the workspace's ext4 block filesystem in
`tools/wp40/results/pregen-cpu-diagnosis-20260923/world`. Snapshot, isolated
Luanti user/XDG directories and evidence resided under
`/tmp/grug-pregen-diagnosis-20260923`. Thus world persistence used the normal
disk filesystem, while diagnostic logs used tmpfs. No personal Luanti paths
were used. A sandbox launch failed before the engine started; the subsequent
host-authorized launch was the sole engine measurement run.

Only the copied `starts_preload.lua` was instrumented. Every five seconds it
reported globalstep cadence, scan elapsed time/steps, pending state and cursor;
every dispatch/completion reported coordinates, inner selection, duration and
callback-action totals. Persistence timing measures Lua serialization and
`storage:set_string`, **not** eventual database flush/fsync. Counters for
requests, callbacks and action types are cumulative; scan/step/persist counters
are interval totals. Action deltas must therefore be derived between records.
No extra terrain sampling or world generation was added. The copied Lua passed
the plain-5.1 parser, SETGLOBAL inspection and all five explicit static sweeps;
no standalone PUC runtime was used.

Host `/proc` sampling recorded CPU ticks, per-thread CPU/wait channel, RSS,
process I/O, block-I/O delay ticks and system CPU/iowait at five-second
intervals. CPU percentages use elapsed-wall deltas: 100% means one logical
CPU, whereas machine percentage divides that value by 16. Percentages from an
unknown task-manager display cannot be compared without its normalization.

An initial sampler selected a Flatpak wrapper. Its `os.jsonl` and
`minutes.jsonl` are **invalid CPU evidence and excluded**. The corrected
`engine-os.jsonl` and `engine-minutes.jsonl` attach to verified engine PID
675697, without restarting the world. They begin 43 seconds after launch;
there is no five-second CPU timeline for those first 43 seconds. The first
correct sample contains 39.96 cumulative CPU seconds, approximately 93% of one
core over startup, with about 19.57 seconds in Main and 20.07 in Emerge-0.
Startup therefore has aggregate high-load evidence, not a reconstructed
fine-grained trace.

## Measured result

The engine ran from approximately 15:50:23 to 15:57:11 UTC (6 minutes
48 seconds including graceful shutdown). The launcher observed exit code 0 at
410 seconds. SIGINT targeted the verified engine PID and start time; a final
host process check found no diagnostic instance and confirmed the pre-existing
GUI instance remained. The run stopped early because the decline and pacing
mechanism had repeated across hundreds of tiles, satisfying the authorized
stop condition; no second measurement run was needed.

The corrected CPU windows were:

| UTC window | Mean, one core | Five-second range, one core | Mean, whole 16-CPU machine |
|---|---:|---:|---:|
| 15:51:06–15:52:01 (55 s) | 59.82% | 53.4–66.6% | 3.74% |
| 15:52:01–15:53:01 | 38.93% | 26.2–44.0% | 2.43% |
| 15:53:01–15:54:01 | 29.88% | 25.2–34.0% | 1.87% |
| 15:54:01–15:55:01 | 25.67% | 13.2–37.6% | 1.60% |
| 15:55:01–15:56:01 | 28.27% | 17.8–36.0% | 1.77% |
| 15:56:01–15:57:01 | 29.42% | 25.6–39.0% | 1.84% |

Per-thread samples separate the work: Emerge-0 fell from a mean 56.75% of one
core in the first corrected window to 21.70% in 15:54:01–15:55:01, while
the Server thread remained near 3–4% (3.09% initially, 3.98% in that lower
window). In the final two windows Emerge-0 averaged 24.32% and 25.57%,
and Server 3.92% and 3.85%. The decline is therefore mainly the emerge
worker spending less time executing, while incremental selection remains
a small, paced Server-thread workload.

The first emergence request took 15.893 seconds; the following 560 averaged
0.210 seconds, with maximum 0.301 seconds. Thus the first request's duration
is not representative of steady generation. Initialization/warmup is a
plausible contributor but was not separately profiled inside that request.

Phase windows are measured from the mods-loaded marker, independently of the
CPU table's later start:

| Minute after mods loaded | Completed requests | Mean request time | Mean completion-to-next-dispatch gap | Scan elapsed time |
|---|---:|---:|---:|---:|
| 0 | 142 | 289 ms, including first request | 130 ms | 0.79 s |
| 1 | 132 | 194 ms | 260 ms | 1.45 s |
| 2 | 75 | 220 ms | 574 ms | 1.97 s |
| 3 | 68 | 227 ms | 663 ms | 2.03 s |
| 4 | 56 | 253 ms | 823 ms | 2.14 s |

In minute 4 the gap occupied approximately 76% of a request-plus-gap cycle.
Scans used 549 of roughly 665 steps, but only 2.14 seconds of elapsed work in
that minute. Actual steps averaged 90.228 ms over all observed intervals, with
maximum 94.312 ms. Increasing scan-step count while leaving approximately
86 ms between 4 ms work slices explains why a relatively small amount of
selection work produces long idle gaps. Sampled scan envelopes were uniformly
88 × 88 columns; no sampled radius increase explains this prefix's trend.
Changing underlying column cost or cache/JIT behavior remains unprofiled.

The final completed prefix was **561/8811 tiles (6.37%)**, from the first row
at z=-3552 into z=-3152. Every dispatched selection had inner cursor 0 and
one vertical chunk, so this run does not test multi-level tile transitions.
There were 70,125 successful mapblock callbacks: 561 generated actions and
69,564 memory actions (one generated chunk yields 125 mapblock callbacks).
No preparation failure or engine ERROR was recorded.

Correctly sampled RSS ranged from 2.34 to 2.75 GB. Over the six-minute corrected
sample span, process disk writes increased by 59.70 MB, disk reads by zero,
and reported block-I/O delay ticks by zero. System-wide iowait was approximately
0.0064% of total CPU time. This provides no evidence for a storage bottleneck
in this run. Measured Lua persistence calls totaled 97 ms across reported
intervals; later engine database flushing is outside that wrapper measurement.

## Source explanation and minimal proposal

The relevant production code is
[`starts_preload.lua`](../../mods/CORE/grug_core/starts_preload.lua):25-26
(work interval and 4,000 microsecond scan budget), 130-166 (actual server-step
entry, incremental selection and dispatch), and 92-128 (single outstanding
request and completion). [`preparation_plan.lua`](../../mods/CORE/grug_core/preparation_plan.lua):95-140
requires each tile's full expanded column envelope before creating its fixed
selection. [`preparation_source.lua`](../../mods/MAPGEN/grug_mapgen/wp40/preparation_source.lua):70
calls the existing column authority; this run does not profile its individual
classification, terrain, hydrology, cache or feature subroutines.

A minimal candidate is a larger, still bounded surface-scan budget during
exclusive initial full-world preparation, retaining server-step-only dispatch,
one outstanding emerge request, current column coverage and persistence.
This requires separate approval/implementation and bounded validation for
responsiveness, shutdown and measured throughput. Do not globally shorten the
server step or increase emerge threads to address this measured gap. No exact
speedup or whole-world completion estimate follows from the partial-world run.

## Evidence and limitations

The [retained evidence directory](../../tools/r19_preparation_diagnosis/README.md)
contains the copied source hash manifest,
instrumentation diff, static-check receipt, exact launch/configuration,
engine identity/start time/affinity, system facts, native log, raw corrected
process/thread samples and minute summaries. The [offline analyzer](../../tools/r19_preparation_diagnosis/evidence/analyze.py)
derives phase summaries from native records using its sibling `engine.log`. The compact evidence is retained in the repository; the complete copied game
and disposable world remain local scratch artifacts.

The local headless process has no connected players and covers only a prefix
of the world. It does not reproduce every GUI/client load or later terrain,
settlement and vertical-stack condition. Wait channels are five-second point
samples; zero observed I/O delay is not a proof that every I/O call was free.
Instrumented scan timings are elapsed wall time, not direct CPU profiling.

## Independent review and delivery

[Independent Sol review](pregen-cpu-diagnosis-review.md): PASS, no open findings.
Investigator/coordinator: Astra. Initial findings: 0 Critical, 1 High (the
rejected wrapper-PID samples), 1 Low (missing steady per-thread attribution).
Each received one focused correction; the native run was not repeated.
The observed engine run lasted approximately 408 seconds, with launcher
completion recorded at 410 seconds. Diagnosis and review took approximately
15 minutes overall. Only documentation and diagnostic evidence are delivered;
no installed-game sync, production fix or runtime playtest is required.
