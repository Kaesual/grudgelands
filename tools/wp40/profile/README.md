# WP40 real-engine mapgen profiler

This bounded harness profiles the R7 mapgen callback in Luanti 5.17.x with
LuaJIT. It copies the selected game into a disposable user path, patches only
that copy, generates an ordered ten-owner corpus in a fresh world, restarts the
engine against the same world, and requires the second pass to report only
`EMERGE_FROM_DISK` blocks. It never changes a shared Luanti installation or a
production source file.

The corpus starts with three adjacent surface owners in Hearthpine Vale. The
centre at `(-1800, -2550)` must resolve to `grug_pine_hills` for seed 0. The
remaining owners cover a capital, the faction front, the battleground, a river
crossing, the west dragon channel and island, and one deep resource slice.
Every surface height and logical biome query finishes before the first timed
request.

## Run

Pass the engine executable or a launcher followed by any fixed launcher
arguments. The launcher must forward the engine arguments appended by the
runner and preserve `LUANTI_USER_PATH`.

```sh
WP40_PROFILE_OUTPUT=/tmp/wp40-profile-baseline \
WP40_PROFILE_DEDICATED=1 \
  bash tools/wp40/profile/run.sh /usr/local/bin/luantiserver
```

To use a frozen game archive instead of the current checkout:

```sh
WP40_PROFILE_GAME_ARCHIVE=/tmp/grug-mapgen-profile-20260913/baseline-game.tar \
WP40_PROFILE_OUTPUT=/tmp/wp40-profile-baseline \
WP40_PROFILE_DEDICATED=1 \
  bash tools/wp40/profile/run.sh /usr/local/bin/luantiserver
```

`WP40_PROFILE_OUTPUT` must name an absent absolute path. If omitted, the runner
creates and prints a result directory under `/tmp`. `WP40_PROFILE_GAME_ROOT`
selects an unpacked game root and cannot be combined with the archive option.
The optional settings are `WP40_PROFILE_SEED` (default `0`),
`WP40_PROFILE_TIMEOUT` (default `900`, maximum `3600` seconds per process), and
`WP40_PROFILE_PORT_BASE` (default `32160`). Set
`WP40_PROFILE_DEDICATED=1` for `luantiserver`, which already runs in server
mode and rejects the client binary's `--server` option. Exactly one engine
process runs at a time.

For a byte-preserving before/after comparison, enable the full post-timing
owner digest in both runs:

```sh
WP40_PROFILE_GAME_ARCHIVE=/tmp/grug-mapgen-profile-20260913/corrected-game.tar \
WP40_PROFILE_OUTPUT=/tmp/wp40-profile-corrected-full \
WP40_PROFILE_DEDICATED=1 \
WP40_PROFILE_FULL_DIGEST=1 \
  bash tools/wp40/profile/run.sh /usr/local/bin/luantiserver
```

The full digest canonically binds the sorted content-ID/name vocabulary once,
then hashes content, `param2`, and light for every voxel in each 80-cube owner.
It processes one owner and small byte batches at a time. Both engine phases
must produce the same digest over 5,120,000 owner voxels. Run the optimized
snapshot with the same seed, cases, engine image, and setting, then compare the
two `summary.tsv` full-digest fields.

For a container, use a small external launcher that mounts the runner's paths
read-write, preserves `LUANTI_USER_PATH`, and executes the container's
`/usr/local/bin/luantiserver` entrypoint. The launcher receives `--version`
during preflight and later receives all headless server arguments. This keeps
container policy and privileged launch details outside the measurement
harness.

## Measurements and artifacts

The patched callback records `plan_slice`, `writer.apply`, and their total in
microseconds. It also records callback order, owner bounds, block seed, R5 run
count, R6 column/candidate counts, writer result, and coarse call counts and
elapsed time for each VoxelManip method. Logging occurs after the timing
timestamps. Luanti's `profiler_print_interval = 1` output independently records
native `Mapgen::makeChunk`, `Lua on_generated`, disk loading, lighting, server
steps, and saving.
The patch hunk is anchored on the R8 native-baseline preamble and callback.

The probe records end-to-end `emerge_area` time and action counts per owner. A
small ordered node/param2 sample digest is computed only after all timed
requests finish. `WP40_PROFILE_FULL_DIGEST=1` additionally reads the already
loaded owner VoxelManip data after the measured finish and hashes canonical
content names, `param2`, and light. The completion record separates
`measured_elapsed_us` from `diagnostic_us`; neither digest runs in a mapgen
callback or an emerge request. The disk restart must reproduce every enabled
digest and must produce zero mapgen callbacks. The default sample detects gross
output or persistence drift without paying the full diagnostic cost.

Set `WP40_PROFILE_STAGES=1` to apply the optional disposable R6 stage patch.
Its `GRUG_WP40_PROFILE_STAGE` records report coarse phase boundaries, including
eligibility setup and P8 resources. The adopted sampler has no root heap or
per-host root digest; historical stage counters describe the earlier algorithm.
Clock and logging instructions can change LuaJIT traces, so
these records support coarse attribution only. Leave stage instrumentation
disabled for primary before/after callback timings.

Each result contains the exact snapshot file manifest and digest, harness
hashes, engine version, hardware summary, invocation template, copied configs,
full engine logs, extracted callback/probe events, extracted native profiler
lines, callback timing summaries, error scans, and `summary.tsv`. `cold/` and
`disk/` keep separate logs.
The disposable game, user path, and world are removed after the validated run.

The cold phase means a new map database, not a flushed host page cache. The
runner defers periodic liquid processing and retains generated blocks until the
post-timing digest; its writer timing still includes any synchronous
`update_liquids` call made by the R7 transaction. Native-v7-only comparison is
a separate diagnostic control and is not a playable configuration or a
production alternative. Headless VM timings do not establish browser latency.

## Static verification

No engine is launched by these checks:

```sh
bash -n tools/wp40/profile/run.sh tools/wp40/profile/patch_snapshot.sh \
  tools/wp40/profile/patch_settlement_stages.sh
shellcheck tools/wp40/profile/*.sh
tools/bin/luac51 -p tools/wp40/profile/probe/cases.lua
tools/bin/luac51 -p tools/wp40/profile/probe/init.lua
tools/bin/luac51 -l -p tools/wp40/profile/probe/init.lua | rg SETGLOBAL
```

The expected global-write result is exactly the probe's single mod table.

The v2 small sample digest uses explicit `outside_owner` sentinels whenever a
sample lies outside its requested 80-cube owner. Cold generation can populate
transient neighbouring halos which a disk-only request does not load; these
are not valid persistence comparisons. The full owner digest remains the
unchanged stronger comparison. Optional `expected_nodes` on diagnostic corpus
rows assert exact node names after all requests, before shutdown, without
requesting any additional generation; the dedicated quality cave corpus uses
this to check the entire tube after P7/P8/P9 settlement.

Select the checked-in ten-owner cave integration corpus with an absolute path:

```sh
WP40_PROFILE_CASES="$PWD/tools/wp40/quality/cave_engine_cases.lua" \
WP40_PROFILE_SEED=0 WP40_PROFILE_FULL_DIGEST=1 \
WP40_PROFILE_DEDICATED=1 \
  bash tools/wp40/profile/run.sh /usr/local/bin/luantiserver
```

The selected file is copied into the disposable probe, included in both the
harness and snapshot SHA-256 manifests, and named in `environment.tsv`.
The cave corpus requires seed 0 and proves 416 air voxels in a tube crossing
two owners during both cold generation and disk-only reload. It is a separate
correctness corpus, not the default timing comparison.
