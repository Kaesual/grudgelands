# WP40 verification harness

This directory contains the reusable WP40 acceptance harness. T0 freezes the
post-WP43 WP18/WP36 comparison checkout at
`7b6c8763224006630f967659047ffae88de6685d`; no later run may silently move
that baseline.

## T0 material handoff

Run:

```sh
tools/wp40/run_t0.sh
```

The runner first executes the complete WP43 suite, loads the real material
owner mod, and checks every public handoff symbol, lookup, boundary vector and
registered node/item. `grug_mapgen/wp43_handoff.lua` builds a private
integer/rational projection from those public tables. It owns no copied depth,
resource, density or race-region literal. It deliberately exposes no encoder
or checksum: T1 owns the single tagged big-endian integer/Q encoder and the
only registry-checksum seam.

## T1 deterministic foundation

Run:

```sh
tools/wp40/run_t1.sh
```

The T1 runner exercises the project-owned canonical binary grammar, raw
SHA-256 hash lanes and rejection sampling, Q16.16/value-noise primitives,
generic three-stage validation, the single checked IPC transport seam, and the
world-aligned 128-node index. It loads the same pure files as three independent
offline/main/mapgen stubs and requires byte-identical encodings, checksums,
hash words, noise values, and index answers. Stage 1/2 corruption prevents
publication; Stage 3 corruption performs one IPC read and prevents callback
readiness. The index fixture compares dense negative/edge/tie samples against a
slow oracle and proves that subsequent hot queries perform no IPC access.
Both `index128.compile(definition, expected_schema)` and
`index128.attach(compiled, expected_schema, evaluators)` fail closed on a
missing or mismatched schema. Direct and outside classifications are scalars;
functions, tables, userdata, and threads cannot enter the compiled grid.
Attach performs the full transport-side structural gate without copying the
grid: safe non-empty extents, unique layer IDs, exact cell coverage, boolean
direct flags, direct-cell shape, and non-empty strictly sorted/unique scalar
candidate IDs of one comparable type. A corrupted IPC grid therefore fails
before any query can observe it.

The compiled checksum is not accepted as an unrelated caller-supplied graph.
The owning schema supplies one `canonicalize_compiled(data, semantic_ids,
canonical)` function; main derives the digest from the exact retained payload
data and sorted semantic registration IDs, and every consumer rebuilds the same
canonical graph before retaining the IPC copy. Stage 3 also requires locally
expected source and compiled checksums, so even a coherent mutation that
rewrites both payload data and its declared digest is rejected. T2/T9 must
supply those expected values from their reviewed/frozen manifest contract;
reading them back from the same IPC payload would not be an independent check.
This schema-owned projection only constructs typed nodes for the one
`canonical.encode`/`canonical.checksum` implementation and is not a second
encoder.

`fixtures/t1_seed_corpus.tsv` freezes slots 1-27. The seven label-derived rows
are checked independently with `sha256sum` and again through the injected raw
SHA function used by the Lua tests. Slots 28-31 remain explicitly
`T2_MEASURED`, and slot 32 remains `T9_PRODUCTION`; T1 does not invent geometry
extremes or a production seed.
The executable T1 harness compares its exact header, fields, order, labels,
decimals, and pending markers against `seed_corpus.lua`; the TSV is a checked
rendering of that module, not a second corpus authority.

Production remains deliberately disabled with no placeholder dataset until T2
provides the checked geometry source and compiler. T1 uses a deterministic
mapgen-state stub because a disposable real emerge-state smoke would require
registering production mapgen scripts and a real payload that do not yet
exist. Real headless main/mapgen identity therefore remains an explicit T2/T9
gate and is not claimed here.

## T2 compiled schema/core

Run:

```sh
tools/wp40/run_t2_schema_core.sh
```

This narrow T2 gate freezes the data-only compiled transport shape, its single
schema-owned canonical projection, the deferred T4/T6/T7 coverage namespaces,
and the production compiler's private fixed-path trust boundary. The foundation
exposes only a narrow `compile(full_seed_string, wp43_vocabulary)` wrapper;
initialization consumers capture it, while the compiler module and its authority
remain private. An engine-free compiler-module instance alone exposes the test
adapter. Before the expected `compiled_geometry_unavailable` result, both paths
exercise the fixed source Stage-1 validator, raw-SHA closure and one compiled
canonicalizer. The later geometry compiler is intentionally absent at this
checkpoint, so no path publishes data, registers a callback or makes a T2-
readiness claim.

For exhaustive development iteration on the expensive T2 source oracle, use:

```sh
tools/wp40/run_t2_source_fast.sh
```

This runs the exact `t2_source_test.lua` harness under LuaJIT and normalizes
only LuaJIT's successful `os.execute` return tuple to the numeric Lua 5.1
result expected by that shared harness. It measured 30.05 s versus 195.56 s
under PUC Lua 5.1 when that was written; the harness has grown since, and the
current figure is the 90.81 s in the acceleration table below. Plan with the
later number. Every change still gets
the plain-5.1 `luac51`/`SETGLOBAL`/five-sweep gates. Intermediate milestones
use targeted representative PUC KATs with byte-identical canonical evidence;
comprehensive parallelized WP40 PUC rounds are reserved for T2-final and
T9-final. A real fallback-engine runtime test remains a separate gate.

## T2 exact/raster/partition slice

The engine-free analytic-slice runner defaults to **LuaJIT**, for iteration:

```sh
tools/wp40/run_t2_partition.sh                    # LuaJIT, cache on
WP40_FINAL=1 tools/wp40/run_t2_partition.sh       # PUC 5.1 acceptance gate
```

`WP40_FINAL=1` is the plain-5.1 compatibility gate that `AGENTS.md` makes a
hard requirement. It forces the vendored PUC interpreter, bypasses the payload
cache, runs every phase and includes the historical block, and it rejects
`WP40_T2_ONLY` so it cannot be run partially. A bare invocation does **not**
satisfy that requirement. Set `WP40_LUA_BIN` to pin a different interpreter,
and `--no-cache` / `--historical` to select those individually; the runner
prints the resolved interpreter path. Do not automatically duplicate the complete
expensive run under PUC at each milestone: retain immutable LuaJIT
artifacts/logs/hashes, compare targeted representative PUC KATs byte-for-byte,
and reserve the parallelized comprehensive PUC round for T2-final. This focused runner owns
exact/rational and raster regression fixtures plus the private partition-family
construction exercised by this slice. It fails closed on any incomplete or
invalid seeded geometry and makes no full-T2 claim. The measured extreme seeds,
complete 32-seed report, publication, readiness, and Flatpak runtime gates
remain later work. The private analytic compiler exists only in this focused
runner and is not yet integrated into the fixed compiler entrypoint, which
intentionally continues to fail closed with `compiled_geometry_unavailable`.

## T2 extreme-selector measurement slice

The private E0 selector-foundation runner defaults to LuaJIT
(`WP40_LUA_BIN` overrides; merge mode below always uses vendored PUC —
the foundation's hardwired PUC default was replaced 2026-08-16 after it
exceeded 31 minutes, aborted, against the interpreter principle in
[luanti-lua.md](../../docs/research/luanti-lua.md)):

```sh
tools/wp40/run_t2_extreme.sh
```

The runner accepts no positional arguments, prints its resolved interpreter,
and keeps the same LuaJIT-exhaustive/targeted-PUC conformance layers as the
partition runner. It checks the single shared R7 boundary materializer, fresh
scalar-only projections, exact normalized rational scores, frozen candidate
identities, and canonical pinned range-shard parsing and merging. A measurement
worker sets no environment range. With the checked-in R16/R17 gate enabled,
the internal `run_t2_extreme_shard.sh START END OUTPUT` interface accepts
exactly the eight 512-candidate ranges `0..511` through `3584..4095`. Both the
single-shard worker and the orchestrator validate the closed gate; wrong
Source, boundary-policy, or partition pins fail before measurement.
The launcher exports immutable `HEAD`,
derives and records its commit/tree, and runs the captured worker with the
reviewed `/usr/bin/luajit` symlink, resolved target, version, and binary hash.
It copies a verified shard back only after that export run succeeds. Set
`WP40_EXTREME_MERGE=1` on this runner to parse, exact-cover, rank, and merge the
eight retained shards under the vendored PUC Lua 5.1 interpreter. Foundation
sizing is strictly limited to 16 or 64 candidates (an explicit range is also
capped at 64) and reports wall time plus direct/batched hash evidence. It
cannot select slots or emit a full-pool artifact; only the immutable eight-
shard path owns those operations.

For an intermediate plain-PUC compatibility milestone without either a full
partition suite or a 4096-row scan, run:

```sh
tools/wp40/run_t2_extreme_puc_kat.sh
```

It checks the closed full-scan gate and pins, byte-identical Seed0/max-u64 R7
scalar projections, candidate0 identity and exact rational score, and a
canonical one-row shard parse/digest. It does not compile Whole geometry or
claim final T2/T9 PUC coverage.

`run_t2_extreme_shards.sh` is the eight-worker launcher. Each worker flushes a
range/current/completed/ETA line every 32 candidates; the launcher reports
aggregate completion out of 4096 and a global ETA. On restart it skips only a
pre-existing shard that passes the pinned PUC verifier, lets independent valid
workers finish if a peer fails, and exits nonzero until all eight canonical
ranges verify. Progress text is diagnostic and is never hashed as candidate
authority.
The launcher gate records the committed stage-S1 authority digest. The worker
recomputes that digest from its immutable archive and from the live S1 Source
projection before emitting a retained shard.

### What the pool provenance binds, and what it excludes

Since the stage-S1 migration the E0 pool binds exactly one thing:
`s1_authority_sha256`, the digest published by `tools/wp40/t2_s1_authority.lua`
over the S1 module (`geometry/boundary.lua`), the arithmetic surface S1 reads
(`canonical.lua`, `deterministic.lua`, `geometry/exact.lua`,
`geometry/raster.lua`), and the canonical checksum of the S1 Source projection
(`s1_source_projection_sha256`). The extreme selector consumes stage S1 only,
so this is the complete set of inputs that can move a pool scalar.

It deliberately excludes `source/catalog.lua` bytes, `geometry/partition.lua`
bytes (stages S2–S9) and the boundary-displacement policy checksum. Those were
the old `source_checksum` / `partition_sha256` / `boundary_policy_checksum`
pins. None of them can change an S1 scalar identity or value, yet pinning them
invalidated the measured pool on every later-stage geometry correction, which
is why the pool was unreachable from R16 onward. The S1 projection
`83b1b16a…` is bit-identical from the T2b seed-zero geometry freeze
(`db62f43`) through R19, so one measured pool now survives R16–R19 and every
future correction that leaves S1 alone.

Because `geometry/boundary.lua` and `tools/wp40/t2_s1_authority.lua` do not
exist at the pinned pre-extraction commits that `validate_pinned_authority`
re-materializes, both travel as `stage_paths` outside the Authority-DAG
`paths` manifest and are always read from the live worktree. Consequently the
stage-S1 digest is a claim about the current tree, never about a
re-materialized historical commit; `validate_pinned_authority` syntax-checks it
and does not verify it.

### Extreme-evidence regeneration

The pool no longer needs regeneration when `geometry/partition.lua` changes —
that coupling was the entire defect this migration removed. Regeneration is
required only when the stage-S1 authority itself changes: the S1 module, the
arithmetic surface, `t2_s1_authority.lua`, or a Source edit that moves the S1
projection. `tools/wp40/t2_extreme_gate_check.lua` is the single place where
the checked-in gate is re-derived from the live tree, and it fails closed with
`stage-S1 authority digest differs` when it does not match.

Regeneration starts only from a committed, independently reviewed snapshot.
Note that `run_t2_extreme_shards.sh` refuses to start unless its launcher
authority (`run_t2_extreme_shards.sh`, `run_t2_extreme_shard.sh`,
`t2_extreme_authority.lua`, `t2_extreme_gate_check.lua`, `full_scan_gate.lua`)
is committed and identical to `HEAD`. Run the following sequence from the
repository root. The two `$EDITOR` commands are deliberate review steps: no
program currently generates either closed gate, so their complete records must
be reconstructed from the immediately preceding no-cache evidence rather than
copied from an old artifact.

```sh
tools/wp40/run_t2_source_fast.sh
WP40_FINAL=1 tools/wp40/run_t2_partition.sh --no-cache --historical
"$PWD/tools/bin/lua51" tools/wp40/t2_extreme_gate_check.lua "$PWD" "$(mktemp -d -p /tmp grudgelands-wp40-t2-extreme.XXXXXXXX)"

# NOT removed, because they are content-pinned by
# t2_extreme_conformance_authority.lua and must stay:
#   * the frozen pre-v3 pool - shard-luajit-0000-0511.tsv and its seven
#     peers, candidates-luajit.tsv, manifest-luajit.tsv
#   * conformance_gate.lua, the recorded conclusion of the pre-v3 C1
#     conformance run
# Note that shard-luajit-*.tsv now matches sixteen files: the eight frozen
# pre-v3 shards AND the eight live v3 shards. Never glob on that pattern.
# The rescore-puc-*.tsv are resume state rather than evidence - each names
# the measurement_commit it belongs to and nothing pins them - so they are
# cleared and recomputed.
git rm --ignore-unmatch -- \
  tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/candidates-luajit-v3.tsv \
  tools/wp40/fixtures/t2_extreme_e0/manifest-luajit-v3.tsv \
  tools/wp40/fixtures/t2_extreme_e0/rescore-puc-*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/selected-puc-slot*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/conformance-puc.tsv
$EDITOR tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua \
  tools/wp40/fixtures/t2_extreme_e0/max_u64_r16_r17.lua
tools/wp40/run_t2_extreme.sh
tools/wp40/run_t2_extreme_puc_kat.sh
git diff --check
git add tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua \
  tools/wp40/fixtures/t2_extreme_e0/max_u64_r16_r17.lua
git commit -m "test(wp40): re-pin extreme scan authority"

tools/wp40/run_t2_extreme_shards.sh
WP40_EXTREME_MERGE=1 tools/wp40/run_t2_extreme.sh
git add tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/candidates-luajit-v3.tsv \
  tools/wp40/fixtures/t2_extreme_e0/manifest-luajit-v3.tsv
git commit -m "test(wp40): retain regenerated extreme pool"

# BLOCKED until the C1 chain is migrated to v3. run_t2_extreme_conformance.sh
# writes conformance_gate.lua in place, and that file is the content-pinned
# conclusion of the pre-v3 run, asserted by selected_stage2_blocked.lua as
# measurement_commit 53be77e / artifact 1096139a. Running it now overwrites
# pinned evidence and leaves WP40_FINAL=1 run_t2_partition.sh --historical
# permanently red. The migration must give the v3 gate a distinct name, the
# same separation the shards, artifact and manifest already have.
tools/wp40/run_t2_extreme_conformance.sh
git add tools/wp40/fixtures/t2_extreme_e0/rescore-puc-*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/selected-puc-slot*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/conformance-puc.tsv
git commit -m "test(wp40): retain regenerated extreme conformance"
```

The first fixture edit must bind the stage-S1 authority digest and S1 Source
projection printed by `t2_extreme_gate_check.lua`, plus the freshly reproduced
max-u64 prerequisite, from that one snapshot. The conformance-gate edit must
bind the new immutable measurement commit/tree/DAG, all eight shard files, the
merged artifact and manifest, candidate rows, winners, and staging row printed
by the PUC merge. Each commit must contain only the files named for that stage;
the shard launcher and conformance launcher then execute from those immutable
commits.

Re-pinning asserts only that the named stage-S1 authority is the reviewed input
to the new measurement; it does not assert that old results remain valid. It
invalidates the earlier eight shards, merged candidate artifact, manifest,
endpoint/winner rescores, selected results, and final conformance result. Those
files remain historical evidence in Git history and must not be relabelled or
reused as evidence for the new pins.

This applies in full to the stage-S1 migration itself. The retained v2
artifacts — the eight pre-v3 `shard-luajit-%04d-%04d.tsv`,
`candidates-luajit.tsv`, `manifest-luajit.tsv` and `conformance_gate.lua`
— were measured at `53be77e` under the old byte pins, before
`geometry/boundary.lua` existed. No stage-S1 authority digest can be computed
for them, so they cannot be carried forward into v3 and must not be re-headed
to look current. They stay exactly as they are, as historical evidence for the
pins they were measured under. The v3 pool is a new measurement.

The twenty `rescore-puc-*.tsv` are deliberately not in that list. They are
resume state, not evidence: each names in its own header the
`measurement_commit` it belongs to, nothing pins them, and the historical
reader does not consult them. They exist so an interrupted conformance run
does not repeat 249 s of PUC row rescoring. `conformance_gate.lua` is the
recorded conclusion; the rescores are the working papers behind it.

`grug_wp40_extreme_candidate_shard_v3`, `…_measurement_artifact_v3` and
`…_shard_manifest_v3` replace `source_checksum`, `boundary_policy_checksum` and
`partition_sha256` with `s1_authority_sha256` and
`s1_source_projection_sha256`. Row bytes are unchanged between v2 and v3 — only
the provenance header differs — which is why the retained candidate0 row digest
`a1cf557c…` still reproduces.

The two generations therefore live under different names, and never share a
path:

| generation | shards | artifact | manifest |
|---|---|---|---|
| frozen pre-v3 (53be77e) | `shard-luajit-%04d-%04d.tsv` | `candidates-luajit.tsv` | `manifest-luajit.tsv` |
| current v3 pool | `shard-luajit-v3-%04d-%04d.tsv` | `candidates-luajit-v3.tsv` | `manifest-luajit-v3.tsv` |

This is not cosmetic. `run_t2_extreme_shards.sh` verifies every already-present
shard before resuming, so with a shared path the eight frozen v2 files aborted
every fresh v3 run; and the merge writes the artifact and manifest, so a shared
path would have overwritten evidence that
`t2_extreme_conformance_authority.lua` content-pins and that
`selected_stage2_blocked.lua` pins by digest. `authority.retained_shard_path`
names the v3 generation and is the only path a measurement may write;
`authority.historical_shard_path` names the frozen one and has no writer.
`validate_retained_shard_path` rejects the historical name, so it can never
become a resume source.

Resume stays fail-closed in both directions: an interrupted v3 run resumes from
its own verified shards, while anything unparseable at a v3 path — a stale
pre-v3 file, a truncated or corrupted shard — aborts the launcher loudly
instead of being skipped.

There is a v3 writer only. The retained v2 artifacts stay readable through
`extreme.parse_historical_shard_blob`, an explicitly named read-only reader used
by the C1 conformance chain so that the historical measurement stays checkable
*as historical*. It never validates a v2 record against a current pin, and no
code path can present a v2 record as current. When the pool is re-measured, the
whole C1 chain (`t2_extreme_conformance.lua` and the rescore/selected workers)
must be moved to v3 against the artifacts that run actually produces; that is
deliberately not done in advance, because it cannot be tested until they exist.

### Locked surfaces

These six files are covered by the stage-S1 authority digest that pins the
measured 4,096-candidate pool:

    tools/wp40/t2_s1_authority.lua
    mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua
    mods/MAPGEN/grug_mapgen/wp40/canonical.lua
    mods/MAPGEN/grug_mapgen/wp40/deterministic.lua
    mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua
    mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua

Editing any of them invalidates the pool and its four winner seeds, costing a
fresh ~91-minute measurement. No work package may touch them as a side effect;
needing a new arithmetic primitive is an escalation, not a local decision.

`source/catalog.lua` and `geometry/partition.lua` may change freely — the pool
binds the Source by canonical projection rather than by file bytes, verified by
control experiment. That is the entire purpose of the S1 scoping.

### `git diff --check` is expected to report this branch

Two categories of whitespace here are correct and must not be "fixed":

- Everything under `evidence/` is a verbatim capture — console logs with box
  drawing and ASCII art, raw JSONL. Editing it falsifies the record.
- `t2_partition_oracle.lua` carries eleven trailing-whitespace lines and is
  content-pinned by `t2_extreme_conformance_authority.lua:33`. Changing its
  bytes invalidates the conformance authority.

So a clean `git diff --check` is the wrong readiness signal for WP40. Check
that every reported path is one of those two categories instead.

### Measured cost anchors

Use these instead of extrapolating; several plans built on a single guessed
ratio have been wrong.

| operation | cost |
|---|---|
| S1 scalars, one seed | 10.7 s (4,096 candidates / 91 min / 8 LuaJIT workers) |
| seed-0 compile, LuaJIT, uncached | 32.7 s |
| seed-0 compile, PUC 5.1, uncached | 868 s |
| seed-0 + max-u64 + traversal, PUC, uncached | 3,091 s |
| payload cache hit | 0.37 s LuaJIT / 1.03 s PUC |
| full partition gate, PUC, 8-way sharded | ~62 min wall |
| 4,096-candidate pool, 8 LuaJIT workers | 91 min wall |
| `run_t2_s1_authority.sh` test, PUC / LuaJIT | 111 s / 21 s (LuaJIT default since 2026-08-16) |
| `run_t2_extreme.sh` foundation, LuaJIT / PUC | 181 s / aborted unfinished at 1,975 s (LuaJIT default since 2026-08-16) |
| census Scan-1 worker pass, one seed, LuaJIT | 22.7 s seed 0 / 24–25 s max-u64 (M1, 2026-08-16) |

The PUC-to-LuaJIT ratio is not one number: 2.8x on validation-heavy paths,
16.2x on an exhaustive numeric sweep, 26.5x on a full seed-0 compile.

Up to 8 concurrent Lua processes are appropriate on this host. Detach anything
expected to exceed ~8 minutes and poll it; use `/usr/bin/stdbuf -oL -eL` — the
`stdbuf` first on `PATH` is a broken AppImage shim. Stop runs by explicit PID
from `pgrep -f extreme_shard`; `pkill -f run_t2_extreme_shards.sh` matches the
invoking shell and orphans the workers.

### Harness acceleration measurements

These wall times were recorded on the same development host during the
harness-acceleration task. They were not normalized for concurrent load.
`$scratch` below was a fresh accepted `/tmp/grudgelands-wp40-*` directory.
Where no pre-change measurement was retained, the table says so rather than
substituting an estimate.

| Command or operation | Before | After |
|---|---:|---:|
| `tools/wp40/run_t1.sh` | 0.17 s | 0.18 s |
| `tools/wp40/run_t2_source_fast.sh` | 90.75 s | 90.81 s |
| `tools/wp40/run_t2_partition.sh` (default LuaJIT) | Not recorded; only a 6--10 min estimate existed | 156.40 s with one cache miss; 134.66 s fully warm |
| `WP40_T2_ONLY=production_trust_path /usr/bin/luajit tools/wp40/t2_source_test.lua "$PWD" "$scratch"` | Not available; the selector did not exist | 0.25 s |
| `WP40_NO_CACHE=1 WP40_T2_ONLY=c2_selector_seams /usr/bin/luajit tools/wp40/t2_partition_test.lua "$PWD" "$scratch"` | Not available; the selector did not exist | 0.06 s |
| One-shot seed-zero `compiler.compile("0")` benchmark | 31.26 s first call; 29.37 s second call, both uncached | 43.20 s forced uncached; 32.99 s cache fill; 0.45 s cache hit |

The compile timings came from the temporary one-shot benchmark used for the
task; that measurement wrapper was not retained as a repository command. The
forced-uncached and cache-hit values are the requested like-for-like cache
comparison. The higher forced-uncached result reflects observed run variance,
not additional cache work.

The complete 4096-row artifact is explicitly a LuaJIT-origin
`R7_SCALAR_MEASUREMENT_ONLY` pool with `stage2=pending_selected_four`. Once
the retained pool exists, PUC must parse and rank it without relabelling its
origin, then rematerialize deterministic shard endpoints and the four winners
and run their full partition gates. That evidence does not exist yet and will
not be a second 4096-origin claim. This slice does not publish geometry,
integrate `compiler.lua`, promote measured slots into the fixed corpus, or
claim Stage 2/T2/32-seed readiness. The former fixed-slot-19 blocker is now a
positive pinned R16/R17 prerequisite; every selected-extreme full-partition
failure remains fatal with no fallback. Slots 28--31 stay pending until the
selected four pass the unchanged complete partition gate.

The pending C1 conformance launcher is:

```sh
tools/wp40/run_t2_extreme_conformance.sh
```

It accepts no arguments and is deliberately unusable as retained evidence
until its complete code-and-input DAG is committed unchanged. From that
immutable archive it first rescores the 16 canonical shard endpoints union the
four ranked winners under vendored PUC Lua 5.1, with at most sixteen workers
and an exact byte-for-byte comparison against the retained LuaJIT rows. Only a
hard 20/20 barrier may start the four fixed slot workers (28--31); they derive
their seeds from the closed artifact, accept no seed argument or fallback, and
run the shared full partition/Whole oracle under PUC. Existing partial results
are resumed only after pinned verification, peers are allowed to finish after
a failure, and the final conformance artifact is written last only after all
20 row checks and all four selected gates pass. These results remain
`T2C_E0_SELECTED_FOUR_CONFORMANCE_ONLY` with corpus promotion pending; they do
not claim Stage 2, T2-final, T9-final, runtime publication, or a 32-seed corpus.

### Pinned engine facts used by T1

- `core.sha256(data, true)` returns the raw 32-byte digest, and the utility is
  registered in emerge states
  (`reference_projects/luanti/src/script/lua_api/l_util.cpp:587-602,862-895`;
  `reference_projects/luanti/doc/lua_api.md:6398-6403`).
- IPC packs on set and unpacks a fresh graph on each get; userdata is rejected
  (`reference_projects/luanti/src/script/lua_api/l_ipc.cpp:17-63`;
  `reference_projects/luanti/doc/lua_api.md:7826-7849`). This is why T1 has one
  initialization read and no query-time recovery/poll path.
- Main-state mods finish loading before `initMapgens`, while each emerge state
  then loads the registered mapgen scripts and fires `on_mods_loaded`
  (`reference_projects/luanti/src/server.cpp:523-577`;
  `reference_projects/luanti/src/emerge.cpp:641-667`).
- Emerge states register IPC, hashing, mapgen settings, and mapgen callbacks,
  but have their own Lua globals
  (`reference_projects/luanti/src/script/scripting_emerge.cpp:45-80`;
  `reference_projects/luanti/doc/lua_api.md:7684-7708`).
- Luanti installs the `string.pack` backport in every server-side Lua state
  (`reference_projects/luanti/src/script/cpp_api/s_base.cpp:81-87`;
  `reference_projects/luanti/doc/lua_api.md:4597-4600`). T1 nevertheless uses
  one manual big-endian encoder so the plain standalone Lua 5.1 harness runs
  the exact production algorithm rather than a replacement stub.

## T2 census scans (Scan-1 worker, milestone M1)

The census contract lives in
[wp40-t2-plan.md](../../docs/research/wp40-t2-plan.md) section 6; this
section owns only the runner mechanics. M1 ships the one-seed worker pass;
the eight-shard full-`W` launcher with GO gate, resume, first-record
validation and cost gate is milestone M2 and does not exist yet — the worker
caps explicit seed lists at 64, so a full-`W` run cannot be started by
accident.

```sh
tools/wp40/run_t2_census.sh --kat                 # seeds 0 + max-u64, pinned digest
WP40_CENSUS_OUTPUT=/path/out.tsv \
  tools/wp40/run_t2_census.sh --seeds 0 7 4096    # small explicit lists run freely
```

LuaJIT by default, `WP40_LUA_BIN` overrides. One worker process evaluates
`partition.census_scan1` per seed — the S1 R7 compile, Bay masks and fills,
then the F1 interval classes for all 61 edges, F7 junction-pair classes plus
the minimum pair clearance, F8 attachment Chebyshev distances and F6 fill
counts — and emits one canonical TSV: `schema`/`vocabulary` manifest lines,
the seed-independent `prefilter` block, per-seed `edge`/`perimeter`/
`attachment`/`junction`/`junction_pair`/`bay` rows framed by
`seed_begin`/`seed_end`, and a trailing `digest` line over the exact
preceding bytes. Reject classes are recorded rows, not errors; the census
continues scanning. Two exceptions abort hard by design: a discharged edge
realizing any interval count other than one (plan section 6.6.8), and any
stage-level global precondition (S1 validity, aperture formation, notch
ownership) — no Scan-1 class covers those, so their occupancy must surface
loudly instead of silently becoming a row.

The prefilter discharges the 14 ordinary edges whose R7 envelope cannot
reach any Bay capsule-plus-jitter box, wing box, notch adjacency or the
displaced-coast margin. The 23 closure/frame edges that sit on the perimeter
itself stay conservatively `scanned` — the analysis's section 3-F1 criterion
carries no coast term, and widening the discharge set would need an explicit
footprint argument first. Discharged edges are still evaluated on every seed;
the block records verified predictions, not skipped work.

`fixtures/t2_census/scan1_kat_v1.lua` pins the M1 KAT: the section 3-F6
witness fills (seed 0 `0/0/0/0`, max-u64 `1/1/1/0`), the structural row
counts, six transition edges with qualifying count one, 102 passing junction
pairs, attachment distances at most one, the zero-displacement Holy band and
the determinism digest over both seeds. The LuaJIT/PUC digest comparison is
milestone M5's merge gate; M1 runs PUC only as the language contract
(`luac51 -p`, `SETGLOBAL`, the five sweeps).

Census artifacts never share a path or name pattern with pool shards
(`shard-luajit-*.tsv`); the worker refuses to overwrite an existing output.

## Isolated headless capture

The designated-host raw T0 capture is:

```sh
WP40_CAPTURE_BASELINE=1 WP40_REPETITIONS=1 tools/wp40/run_t0.sh
```

`capture_t0_baseline.sh` exports the selected commit with `git archive` into a
temporary game under an explicit disposable `LUANTI_USER_PATH`, adds the
test-only probe there, creates a fresh world, and runs Flatpak Luanti pinned to
logical CPUs 0-7. It never calls `tools/sync_to_luanti.sh` and never reads or
writes the shared installed `grudgelands` game. Generated scratch captures go
under the gitignored `tools/wp40/results/`; reviewed release evidence is
generated by overriding `WP40_RESULTS_ROOT` to `tools/wp40/evidence/...`.

The probe ends with `core.request_shutdown` after writing a `complete` event.
The observed Luanti 5.16.1 controlled shutdown exits with status 0. Harness
status 2 means a preflight error or refusal to overwrite an immutable result;
it is not treated as successful shutdown. Status 124 is the outer timeout and
always fails the capture.

The T0 corpus is intentionally labelled `t0_legacy_substrate`. It records a
real raw baseline of the old rectangle/radial mapgen, but cannot anticipate
T2's geometry-derived Chapter 6 microcorpus or 100-requester trace. After T2
freezes those fixtures, T9 replays them against the same immutable checkout:

```sh
WP40_CHECKOUT_SHA=7b6c8763224006630f967659047ffae88de6685d \
WP40_CORPUS=path/to/t2-microcorpus.tsv \
WP40_PHASE=T9-baseline \
WP40_COMPARISON_ROLE=final_microcorpus_baseline \
WP40_REPETITIONS=40 \
tools/wp40/capture_t0_baseline.sh

WP40_CHECKOUT_SHA=<reviewed-candidate-commit> \
WP40_CORPUS=path/to/t2-microcorpus.tsv \
WP40_PHASE=T9-candidate \
WP40_COMPARISON_ROLE=final_microcorpus_candidate \
WP40_REPETITIONS=40 \
tools/wp40/capture_t0_baseline.sh
```

Both sides must use the same host, runtime, settings, seed, fixture digest,
affinity and cache class. The runner refuses to overwrite a result directory.
Every run retains raw events, server logs, realized `map_meta.txt`, process
RSS/high-water/Lua-heap/CPU observations and SHA-256 checksums.

## Evidence limits

The installed Flatpak is Luanti 5.16.1 with LuaJIT, while the pinned source
reference is 5.17.0-dev at `df04879066de6eb94ca43996822a6dfacc74feca`.
The manifest records that mismatch. The filesystem page cache is currently
uncontrolled, so T0 labels it unknown and makes no cold-cache claim. A bundled
Lua 5.1 engine measurement and the full cold/warm repetitions remain T9 gates;
plain-5.1 source compatibility is checked separately with `tools/bin/luac51`.
