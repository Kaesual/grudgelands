# Full-preparation scan budget experiment

Date: 2026-09-23. This implements the user's follow-up authorization to test a
higher full-preparation scan budget after the
[CPU diagnosis](pregen-cpu-diagnosis.md). Production changes are restricted to
`starts_preload.lua`; no native emerge, cave, mapgen, server-step or thread
configuration is changed.

## Scope and ordinary cave generation

The candidate raises the named `FULL_PREPARATION_SCAN_BUDGET_US` from the former
4,000 microseconds to 40,000 microseconds. It is used only in the existing
`source and not state.selection` branch, inside the outer `not ready()` guard.
`source` is initialized only for the world's immutable `full` mode. Starts-only
preparation does not scan these columns; a ready world never reaches the scan
or scheduler-dispatch branch, including after reloading current world state.
The 16-column batch, 8,192-column hard ceiling, 20 ms work interval, one pending
request, native 90 ms server cadence, single emerge thread, tile coverage and
persistence format are unchanged.

The changed constant does not affect arbitrary `core.emerge_area` calls or
native mapgen. In particular, ordinary later cave exploration still uses the
same engine and game generation path. The portable fixture verifies that the
scheduler does not replace the engine's emerge function, then seeds only a
current-format last-tile plan, completes it, and makes both surface functions
throw if called again. One hundred subsequent steps produce no preparation
work. An external deep request at y=-4096 retains its coordinates and generated
callback; another hundred steps still produce no preparation work or cursor
change. The same checks pass after a completed-world restart. Starts-only
coverage also runs with throwing surface functions. Existing cancellation,
retry, partial-selection shutdown, resumed inner cursor, immutable mode,
authority, coverage and coarse-clock-cap cases remain exercised.

These are direct scheduler and API-routing tests, not a native cave-geometry
or player-navigation run. The native comparison below uses a fresh, unfinished
world; it does not pretend that 561 tiles constitute full-world completion.
Normal gameplay/cave acceptance remains a separate user-run GUI check.

## Matched-prefix native comparison

The comparison uses one separately authorized fresh copied game and a fresh
world on the workspace's ext4 filesystem. It matches baseline seed 8675309,
Luanti 5.17.0, LuaJIT 2.1.1784272936, single emerge thread, mapgen settings and
first **561 horizontal tiles**. Only the copied scheduler is instrumented.
Every completion records the same coordinates and action counters as baseline;
a snapshot-only flag at cursor 561 requests normal shutdown from the next
Server globalstep before any further scheduler work. The callback itself does
not initiate shutdown. An external seven-minute cap bounds failures.

The host sampler validates the executable name, exact disposable world
argument, unique PID and process start time. It found Luanti 72 ms after launch,
with zero accumulated CPU ticks, avoiding the original diagnosis's wrapper-PID
mistake. Five-second CPU samples include startup, process/thread breakdown,
RSS and I/O. CPU normalization is one logical core = 100%; the machine has 16
logical CPUs and unrestricted affinity. Native callback cadence and scan maxima
are recorded; candidate cadence histograms provide millisecond tail buckets.

The offline comparison verifies identical full dispatch-prefix and per-request
action hashes, identical engine settings, and identical snapshot file hashes
except the scheduler. Timing uses matched tile ranges, not equal-duration
windows on different geography. CPU comparisons admit only five-second sample
intervals wholly inside each matched range; boundary windows are conservatively
excluded using the engine log's second-resolution wall timestamps. Baseline
startup CPU samples are missing, so later matched regions are the stronger CPU
comparison.

## Result

The 40 ms candidate completed the identical 561-tile prefix **2.17 times as
fast**, reducing the preparation interval by **54.0%**. It is a useful bounded
improvement toward one busy core; it does not promise permanent 100% utilization
or extrapolate a whole-world ETA.

| Measurement | 4 ms baseline | 40 ms candidate |
|---|---:|---:|
| Mods-loaded marker to completed tile 561 | 386.52 s | 177.76 s |
| First dispatch to completed tile 561 | 386.06 s | 177.59 s |
| Launch to observed process exit, including startup/shutdown | 410.00 s | 197.81 s |
| First request, including emerge initialization | 15.893 s | 15.866 s |
| Matched tiles 101–561 elapsed | 341.48 s | 135.79 s |
| Matched tiles 101–561 mean request | 216.78 ms | 216.95 ms |
| Matched tiles 101–561 mean dispatch gap | 524.16 ms | 77.81 ms |
| Matched tiles 101–561 sampled CPU, one core | 32.70% | 82.05% |
| Same CPU windows, Emerge-0 | 28.92% | 73.02% |
| Same CPU windows, Server | 3.77% | 9.02% |

The exact native markers are the throughput comparison. Launch/exit figures
also include the different observer exit-poll cadence and are provided only
as end-to-end context. The unchanged request duration and sharply shorter
idle gaps confirm that this change improves scheduling of selection work;
it does not accelerate or modify native cave/mapgen work itself.

Later matched geographic ranges show the same effect:

| Tiles | Baseline elapsed / CPU | Candidate elapsed / CPU |
|---|---:|---:|
| 301–400 | 88.89 s / 29.27% | 30.92 s / 82.40% |
| 401–500 | 102.53 s / 26.93% | 31.72 s / 84.92% |
| 501–561 | 60.06 s / 27.96% | 19.93 s / 84.33% |

Here CPU means one-core percentage from wholly enclosed sample intervals,
not every instant in the range. Across tiles 101–561, those intervals cover
335 seconds in baseline and 130 seconds in the candidate. Dividing by 16
converts the aggregate 32.70% and 82.05% to 2.04% and 5.13% of this machine.
The candidate's first sampled startup minute averaged 89.77% of one core;
subsequent minute windows averaged 76.43% and 85.65%.

Observed globalstep mean remained approximately 90 ms: 90.228 ms baseline,
90.289 ms candidate. The maximum in reported intervals rose from 94.312 to
100.510 ms; candidate 95th-percentile cadence was in [90,91) ms and 99th in
[92,93) ms. The largest reported scan slice was 40.417 ms. This is a cooperative
budget checked after a 16-column batch, not a hard real-time preemption bound:
a slow source call or batch can overshoot. Final partial reporting intervals
are not included in these cadence/scan aggregates. There was no native error,
no extra dispatch 562, and normal exit code was zero with no diagnostic engine
survivors. The existing personal GUI instance was not targeted.

Sampled peak RSS was 2.75 GB baseline versus 2.98 GB candidate. This experiment
establishes a bounded prefix result, not a full-world memory bound; it does not
attribute the RSS difference to a particular cache or allocation.

Both runs produced the same dispatch/selection prefix SHA-256
`326d272bfa1d1cb058507a4a576cb7c48f92fd6dfb857dc8a043ebea76988fcf`
and per-request action-delta SHA-256
`dad3858337b83b9fc81ebb020b941cf4a18a94598bbfa7bf387619356c6f0d3c`.
Each completed 561 generated actions plus 69,564 memory actions, with the same
last bounds (1248,-32,-3152) through (1327,47,-3073). This is prefix/action
identity, not a claim that entire SQLite files or every node were byte-compared.
Every other copied game file, including all native-facing mapgen and cave Lua,
was hash-identical to baseline. Both runs used the same engine executable hash
`8f7355f928237fed68717237aff52c7a4944535cab7964f2fc1d0cf99c57de54`.

The candidate run lasted from 16:15:20 UTC to approximately 16:18:38 UTC. Its
copied game/user paths remain at `/tmp/grug-preparation-budget-ezadaltp`, and
its disposable world at
`tools/wp40/results/preparation-budget-wn0ay4sn/world`. Compact reproducible
evidence is retained in the repository rather than depending on those scratch
paths.

## Validation and evidence

Development used LuaJIT. Both changed Lua files passed the plain-5.1 parser,
SETGLOBAL inspection, and the five source sweeps (existing comment/string hits
were inspected). The disposable instrumented source passed the same explicit
static checks. The coordinator ran the one compact frozen final PUC-5.1 versus LuaJIT
parity pair; both succeeded with identical canonical output SHA-256
`f0312a1e2228fdfa4c556db0b57fa6fb639805e62b5953c11629879638b76a7b`.
The fixture exercises the actual production scheduler, and the parity receipt
records hashes of its frozen inputs.

[Harness and retained evidence](../../tools/r19_preparation_budget/README.md)
include immutable input hashes, exact configuration, source instrumentation,
raw native/process/thread samples, prefix comparison and the final parity
receipt. No personal Luanti installation or world was touched, and no extra
emerge thread or global server-step change was used.

## Review and user acceptance

[Independent Sol review](pregen-scan-budget-review.md): PASS, no open findings.
Implementer/coordinator: Astra. Calibration: 0 Critical, 1 High in the
test-only stop instrumentation, fixed in one round before the native run;
no production-code defect was found. Investigation/implementation/review took
approximately 20 minutes, including one 198-second native candidate run.
The frozen final portable runtime pair took approximately 31 ms under PUC 5.1
and 7 ms under LuaJIT; reviewers inspected its artifacts without repeating it.

At the next user-run server test, check that the preparation waiting UI remains
responsive and normal stop/restart resumes progress. After preparation has
completed, explore previously ungenerated deep cave chunks and confirm ordinary
gameplay. This GUI/multiplayer acceptance is not claimed by the headless prefix
measurement or mocked deep-request routing fixture.

## Local delivery

Implementation commit `d47e58de`, merged into local main as
`f2c8998475239eaf9e25fd0ffb72606fded57142`. Synced from main with
`tools/sync_to_luanti.sh`; the installed scheduler was verified byte-identical
and all final-parity source hashes remain unchanged. No remote push or
production-server deployment was performed. Restart is required to load the
new Lua code; the preparation persistence format and source identity are
unchanged.
