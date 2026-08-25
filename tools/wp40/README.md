# WP40 verification harness

Status: **historical exact-T2 harness unless a section explicitly names a
current simple-map R-stage.** The simple-map rebase on 2026-08-25 retired the
partition/topology schema, S1 lock, winner seeds, PCC/F1/F2 final gate and
full-W census. Commands and measurements below remain readable provenance;
they are not scheduled by R1-R8. T0/T1 artifacts and small deterministic/hash
utilities may be salvaged only through the reviewed simple-map source.

This directory contains the reusable WP40 acceptance harness. T0 freezes the
post-WP43 WP18/WP36 comparison checkout at
`7b6c8763224006630f967659047ffae88de6685d`; no later run may silently move
that baseline.

## Current simple-map R1/V1d preview gate

Run:

```sh
tools/wp40/run_simple_map.sh
```

This current preview runner loads the engine-free source and production evaluator,
runs the Lua 5.1 static gates, compares canonical LuaJIT/PUC 5.1 KATs for four
representative seed strings, renders the same production classifier twice,
requires byte identity, parses the SVG and writes only the canonical preview:

```text
docs/research/wp40-simple-map-preview.svg
```

Its full-grid connectedness, route-fit, contact, water-class and timing lines
are advisory until the user accepts V1d and R2 freezes the layout. The runner
does not repair routes, zones or water and must not be used to tune hidden
constants before visual review. The exact-T2 commands below are historical
reproducers only.

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

The former exact-T2 development loop used:

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
use targeted representative PUC KATs with byte-identical canonical evidence.
Exhaustive populations ran under LuaJIT. The PCC/F1/F2 wording below records
the retired exact-T2 final gate and does not apply to simple-map R1-R8.

## Historical T2 pinned PUC conformance core (PCC)

The retired exact-T2 standalone-PUC carrier was:

```sh
tools/wp40/run_t2_puc_core.sh --all
```

Its fixture manifest freezes the five-group semantic micro-corpus, targeted
Source parity, unit/comparator layer, compiler witness pair, worker witness
pair and seven-seed merge witness. The merge retains the fail-closed
`pairs()` probe plus synthetic and measured invariance. The worker gate keeps
canonical stdout and the complete TSV byte-exact while retaining raw runtime
telemetry separately; only the anchored wall/CPU suffix is removed for the
telemetry comparison. Before any leg, the runner proves that its LuaJIT side
really exposes `jit.version` and resolves to a different executable from PUC.
The merge report replaces only its leading host-specific interpreter identity
with `WP40 T2 census interpreter: <LuaJIT>`; every semantic line remains exact.
The standalone optional-load runner still reports the real locale it found.
The PCC requires one final success line proving C plus a supported real non-C
arm, then normalizes only that locale token to `<non-C>` before fixture
comparison; missing, ambiguous or malformed evidence fails. Use a single mode
(`--micro`, `--source`, `--unit`,
`--optional`, `--compiler`, `--worker`, `--merge`) during focused diagnosis;
`--worker-selftest` is the cheap positive/negative channel-gate proof.
`--unit` (and therefore `--all`) needs the retained Section-11 artifacts;
set `WP40_S11_ARTIFACTS_DIR` when running from a worktree that does not carry
the canonical checkout's ignored results directory.

The PCC did not launch final rounds or populations. The retired T2/T9 final
definition also named:

```sh
WP40_FINAL=1 tools/wp40/run_t2_partition.sh --no-cache --historical  # F1
tools/wp40/run_t2_extreme_conformance.sh                             # F2
```

F2 already carries candidate endpoints 0/4095 and selected slots 28--31, so
there is no separate six-candidate selector PCC leg. The full-`W` population
runs only under LuaJIT; `run_t2_census.sh --merge` still performs its
LuaJIT/PUC canonical-artifact comparison. Fixture/evidence changes require a
later owning memo in `wp40-t2-contracts.md`, never an ad-hoc re-pin.

## Historical T2 exact/raster/partition slice

The engine-free analytic-slice runner defaults to **LuaJIT**, for iteration:

```sh
tools/wp40/run_t2_partition.sh                    # LuaJIT, cache on
WP40_FINAL=1 tools/wp40/run_t2_partition.sh       # historical PUC reproduction
```

`WP40_FINAL=1` was the retired exact-schema plain-5.1 compatibility mode. It
forced the vendored PUC interpreter, bypassed the payload cache, ran every
phase and included the historical block. F1 was one named component of that
former bounded gate. The focused runner and its exact/raster fixtures remain
available solely to reproduce historical evidence; neither a bare nor final
invocation satisfies a simple-map milestone or readiness gate.

## Historical T2 extreme-selector measurement slice

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
repository root. The `$EDITOR` steps are deliberate review points: no program
generates any of the three hand-authored gate fixtures — `full_scan_gate.lua`,
`max_u64_r16_r17.lua` and `conformance_gate_v3.lua` — so each complete record
must be reconstructed from the immediately preceding no-cache evidence rather
than copied from an old artifact.

```sh
tools/wp40/run_t2_source_fast.sh
WP40_FINAL=1 tools/wp40/run_t2_partition.sh --no-cache --historical
"$PWD/tools/bin/lua51" tools/wp40/t2_extreme_gate_check.lua "$PWD" "$(mktemp -d -p /tmp grudgelands-wp40-t2-extreme.XXXXXXXX)"

# NOT removed. The pre-v3 pool files are content-pinned by
# t2_extreme_conformance_authority.lua (the frozen pre-v3 C1 graph), and four
# of them are additionally rostered by t2_extreme_conformance_v3_authority.lua
# because the v3 KAT reads them as negative inputs:
#   * the frozen pre-v3 pool - shard-luajit-0000-0511.tsv and its seven
#     peers, candidates-luajit.tsv, manifest-luajit.tsv
#   * conformance_gate.lua, the recorded conclusion of the pre-v3 C1
#     conformance run
#   * the twenty pre-v3 rescore-puc-%04d.tsv. Nothing pins them and no code
#     reads them any more; whether they are deleted is an open question, not
#     this recipe's decision. See "The two result generations" below.
#
# TWO GLOBS NOW MATCH BOTH GENERATIONS AND MUST NEVER BE USED:
#   * shard-luajit-*.tsv   - eight pre-v3 AND eight v3 shards
#   * rescore-puc-*.tsv    - forty rows: twenty pre-v3 and twenty v3
# Always spell the generation out: shard-luajit-v3-*.tsv, rescore-puc-v3-*.tsv.
git rm --ignore-unmatch -- \
  tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/candidates-luajit-v3.tsv \
  tools/wp40/fixtures/t2_extreme_e0/manifest-luajit-v3.tsv \
  tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/selected-puc-v3-slot*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/conformance-puc-v3.tsv
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

# Re-author the C1 v3 conformance gate. Nothing generates it, and EVERY value
# in it moves with a regenerated pool: pool_measurement_commit,
# pool_measurement_tree, pool_authority_dag_sha256, s1_authority_sha256,
# s1_source_projection_sha256, artifact_sha256, manifest_sha256,
# candidate_rows_sha256, the eight shard digests, the four winners and the
# staging row. Reconstruct all of them from the merge output just printed and
# from the pool commit above - never by editing the previous gate.
# It must be committed BEFORE the conformance launcher runs: the gate is inside
# the C1 v3 DAG, and the launcher's preflight requires the working tree to be
# byte-identical to HEAD for every rostered path. Skipping this step does not
# destroy anything - the launcher fails closed on a gate mismatch - but the
# conformance cannot start.
$EDITOR tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua
git add tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua
git commit -m "test(wp40): re-pin the C1 v3 conformance gate"

# The launcher writes v3 names only and refuses any other target, so it can no
# longer overwrite pre-v3 evidence. It reads conformance_gate_v3.lua and never
# writes any gate.
tools/wp40/run_t2_extreme_conformance.sh
git add tools/wp40/fixtures/t2_extreme_e0/rescore-puc-v3-*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/selected-puc-v3-slot*.tsv \
  tools/wp40/fixtures/t2_extreme_e0/conformance-puc-v3.tsv
git commit -m "test(wp40): retain regenerated extreme conformance"
```

The first fixture edit must bind the stage-S1 authority digest and S1 Source
projection printed by `t2_extreme_gate_check.lua`, plus the freshly reproduced
max-u64 prerequisite, from that one snapshot. The `conformance_gate_v3.lua`
edit must bind the new immutable pool commit/tree/Authority-DAG, the two
stage-S1 digests, all eight shard files, the merged artifact and manifest,
candidate rows, the four winners and the staging row printed by the PUC merge.
Each commit must contain only the files named for that stage; the shard
launcher and the conformance launcher then execute from those immutable
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

#### The two result generations

The twenty `rescore-puc-%04d.tsv` are pre-v3 files, and since the C1 chain
moved to v3 they are inert. The facts, all checkable in the tree:

- **No code reads them.** The v3 chain writes and verifies
  `rescore-puc-v3-%04d.tsv`; every path guard in it rejects the pre-v3 name.
- **Nothing pins them.** No rescore file of either generation appears in
  `t2_extreme_conformance_authority.lua`'s roster or in
  `t2_extreme_conformance_v3_authority.lua`'s, and no fixture records their
  digests.
- **They can never be resume state again.** Each names in its own header the
  pre-v3 `measurement_commit` `53be77e`, which the v3 verifier rejects, so a v3
  run would recompute regardless of whether they are present.

Whether they should be deleted, or kept as historical working papers behind
`conformance_gate.lua`, is **an open question for the next package** — this
file does not decide it. Until it is decided they stay, and the glob warning
above applies. Note the tension a reader will hit: the paragraph history of
this section called them disposable resume state, while the C1 v3 handoff
ruling called them must-retain. Both were written when they were still the
current chain's resume state; neither survives contact with the migration, and
that is exactly why the question is open rather than answered here.

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
`extreme.parse_historical_shard_blob`, an explicitly named read-only reader. It
never validates a v2 record against a current pin, and no code path can present
a v2 record as current.

The C1 conformance chain has since been migrated: `t2_extreme_conformance.lua`
and the rescore/selected workers read the v3 pool through
`extreme.parse_shard_blob`, and `parse_historical_shard_blob` is no longer
reachable from the chain at all. The only remaining C1 use of the pre-v3
artifacts is negative — `t2_extreme_conformance_test.lua` presents each of them
to a v3 reader and requires rejection. See "The v3 conformance generation".

### The v3 conformance generation

The C1 selected-four conformance chain reads the v3 scalar pool. It is a
*generation*, not a replacement: the pre-v3 chain's authority module, gate and
artifacts are frozen where they are, and the two can never be confused.

**Why a second authority module.** `t2_extreme_conformance_authority.lua` must
stay byte-identical. `t2_partition_test.lua`'s `selected_stage2_historical` mode
(`WP40_FINAL=1 tools/wp40/run_t2_partition.sh --no-cache --historical`) `dofile`s
it from the live tree and re-materializes the pre-v3 conformance DAG
`086855378e…` from commit `5a2fc0d` through its exact roster. Any roster edit
makes that digest unreproducible and turns the historical gate permanently red.
The v3 chain therefore owns `t2_extreme_conformance_v3_authority.lua`, with the
domain-separated DAG prefix `grug_wp40_t2c_e0_c1_v3_dag_v1`, so a pre-v3 and a
v3 file manifest can never collide even if the two rosters became equal.

**What the v3 roster names** (66 paths): the v3 chain modules — including the
recorded-evidence driver — plus the runner, gate,
merged artifact, manifest and eight shards; `t2_partition_test.lua`,
`t2_partition_oracle.lua`, the WP40 schema modules and the WP43 material surface
those two load, plus the shared phase selector and the partition payload cache;
every file the measurement Authority-DAG covers (`t2_extreme_authority.lua`'s
`paths` and `stage_paths`), because `execution_authority_dag_sha256` is
recomputed from the live tree and the preflight must be able to prove the live
tree equals the pinned commit for every byte that digest depends on; and the
four pre-v3 fixtures the KAT reads as negative inputs.

**Old → new.**

| kind | pre-v3 | v3 |
|---|---|---|
| gate fixture | `conformance_gate.lua` | `conformance_gate_v3.lua` |
| gate schema | `…_conformance_gate_v1` | `…_conformance_gate_v3` |
| authority module | `t2_extreme_conformance_authority.lua` | `t2_extreme_conformance_v3_authority.lua` |
| DAG prefix | `grug_wp40_t2c_e0_c1_dag_v1` | `grug_wp40_t2c_e0_c1_v3_dag_v1` |
| merged artifact | `candidates-luajit.tsv` (20 headers) | `candidates-luajit-v3.tsv` (19 headers) |
| manifest | `manifest-luajit.tsv` | `manifest-luajit-v3.tsv` |
| shards | `shard-luajit-%04d-%04d.tsv` | `shard-luajit-v3-%04d-%04d.tsv` |
| rescore result | `rescore-puc-%04d.tsv` / `…_puc_rescore_v1` | `rescore-puc-v3-%04d.tsv` / `…_puc_rescore_v3` |
| selected result | `selected-puc-slot%02d.tsv` / `…_selected_partition_v1` | `selected-puc-v3-slot%02d.tsv` / `…_selected_partition_v3` |
| final result | `conformance-puc.tsv` / `…_puc_conformance_v1` | `conformance-puc-v3.tsv` / `…_puc_conformance_v3` |
| preflight token | `WP40_T2_C1_PREFLIGHT` | `WP40_T2_C1_V3_PREFLIGHT` |

Every path guard rejects the other generation's name in both directions —
`is_historical_result_path` recognises the pre-v3 names, `assert_v3_result_path`
requires the exact retained directory under a named repository root, and the
launcher's `v3_target` refuses any target that is not a v3 name in one of the
two retained directories.

**The three provenance claims.** The pre-v3 chain asserted that the live
measurement Authority-DAG equalled the gate's. That is not true any more and is
not faked: `geometry/partition.lua`, `source/catalog.lua` and
`validation/t2_source.lua` all differ between the pool commit and HEAD, because
the Section 11 correction landed after the pool was measured. Three separately
named claims replace it, and no two share a field name:

| claim | fields in every result row | how it is established |
|---|---|---|
| pool origin (historical) | `pool_measurement_commit`, `pool_measurement_tree`, `pool_authority_dag_sha256` | `t2_extreme_conformance_verify.lua` re-materializes `19fc28d1` / `bca04056` / `069cce2d` through `validate_pinned_authority`, with no `partition_sha256` |
| stage-S1 currency | `s1_authority_sha256`, `s1_source_projection_sha256` | recomputed from the tree the conformance runs on, following `t2_extreme_gate_check.lua`'s sequence, and required to equal the gate |
| executing code | `execution_authority_dag_sha256` | the measurement Authority-DAG of the conformance tree; recorded in a gate-independent position, recomputed live per row by the verifier, and required to agree across all twenty-four rows by the finalizer |

A fourth, different thing sits beside them: `conformance_commit`,
`conformance_tree` and `conformance_dag_sha256` are the C1 v3 launch pins of the
run that produced the row.

**One consequence of the retained interpreter pin.** The merged artifact records
`merge_interpreter_path = /home/jan/projects/grudgelands/tools/bin/lua51`, and
the workers, the verifier and the finalizer all compare it against their own
`argv[0]`. The pin is deliberately retained, so an end-to-end run only succeeds
when the repository root is exactly that path: **the conformance cannot be run
from a git worktree.** Parse/validate/mutation KATs are unaffected and run
anywhere.

**Recorded-commit reuse: what a finished artifact is evidence of.**
**The current retained `conformance-puc-v3.tsv` exists.** The WARCOAST
reacceptance produced it from commit `86e5071`, tree `07e5d99c`, and C1-v3 DAG
`42b8a38c…`; final SHA-256 `1edbb12a…`. A second invocation at that unchanged
HEAD was coordinator-observed to reverify all 24 retained rows through the
same-HEAD branch; its raw stdout was not retained. Commit `17efc8d` then bound
the 25 result files. From that descendant HEAD, the recorded-commit branch was
coordinator-observed to reverify the 66-path closure and all 24 rows, returning
`REUSED RECORDED EVIDENCE` with exit 0; that stdout was also not retained. The
current manifest and provenance limitations are recorded under
`tools/wp40/evidence/t2-c1-v3-86e5071/`; independent Opus/xhigh acceptance
review and focused re-review are green. The earlier `db9c344` and `5d770365`
acceptances remain historical evidence in their named directories, not the
live fixture identity.

A completed `conformance-puc-v3.tsv` would be evidence of the commit it
*records*, not of whatever `HEAD` happens to be. Without this rule any later
commit — including a documentation-only one that touches nothing the conformance
reads — would make the recorded evidence "stale", delete it and buy a full
24-row rerun, because the only available check takes its pins from
`git rev-parse HEAD`.

`tools/wp40/t2_extreme_conformance_recorded.lua` is the second branch of the
launcher's "final output already exists" block. The first branch is unchanged:
re-verify against the current launch pins, and if that works nothing else runs.
Only when it fails does the recorded-evidence branch try, and only when *that*
fails does the existing stale/recompute path take over. **Generation is not
relaxed anywhere** — a first run still has to produce all 24 rows from one
clean, immutable commit/tree/DAG.

What the reuse branch proves, in this order, all fail-closed:

1. **The pins come from the artifact's bytes.** `parse_recorded_pins` reads
   `conformance_commit`, `conformance_tree` and `conformance_dag_sha256` out of
   `conformance-puc-v3.tsv` itself and validates 40/40/64 lowercase hex before
   any value reaches a git command line. The leading line must be
   `schema<TAB>grug_wp40_extreme_puc_conformance_v3` and `status` must be
   `passed`; a repeated pin line is a refusal, so appended bytes cannot redirect
   the check. A pre-v3 final artifact and a result row of either generation all
   carry `conformance_*` fields, and none of them can pass this reader.
2. **The commit is ours.** `assert_recorded_history` requires a real commit
   *object* (`rev-parse --verify --quiet <id>^{commit}`) that is an **ancestor of
   HEAD** (`merge-base --is-ancestor`). An object that merely exists — a
   dangling `commit-tree` commit, a tree id, an object fetched from elsewhere —
   is refused.
3. **The tree is the recorded tree**, via the existing `validate_provenance`.
4. **The whole pinned closure is unchanged.** `closure_equality` compares the
   bytes of **every path in the `paths` roster** of
   `t2_extreme_conformance_v3_authority.lua` at the recorded commit against the
   **current working tree**, and names the first path that differs. There is no
   second, informally maintained file list: the roster *is* the closure
   definition, and because the authority module is itself a roster member, a
   proven closure is also proof that the roster applied is the recorded commit's
   roster. A member that is missing at the recorded commit is a refusal, never a
   skip. The roster's DAG at that commit must equal the recorded
   `conformance_dag_sha256`.

   **One input the roster cannot carry.** `tools/bin/lua51` changes a v3 result,
   but it is built per checkout and gitignored (`.gitignore`: `tools/bin/`), so
   it is not a tracked path and `capture_git` could never read it at a commit.
   It is pinned per **result row** instead, by step 5: the verifier re-hashes the
   live `argv[0]` and requires it to equal every row's `interpreter_sha256` and
   the merged artifact's `merge_interpreter_sha256`. So the roster is the
   complete closure *of tracked inputs*, not of everything that can change a
   result — and the interpreter is covered by a different mechanism, not left
   open. The byte comparison also ignores git file modes; the repository has no
   tracked symlinks, and adding one to the roster would need that revisited.
5. **The evidence re-derives.** Only then is
   `t2_extreme_conformance_finalize.lua` run in `verify` mode with the
   **recorded** pins. That is the existing path: it re-runs
   `t2_extreme_conformance_verify.lua` against all 20 rescore rows and 4 selected
   rows, rebuilds the entire final blob from those retained bytes and requires it
   to equal the artifact byte-for-byte. So a modified retained row and a modified
   final artifact both fail.

**Equality of the final TSV alone is never accepted** as proof of closure
equality — the pins parse identically out of an artifact whose result rows were
tampered with, which is exactly why steps 4 and 5 are both required. Any refusal
means a rerun: the launcher falls through to its existing stale/recompute path.

Acceptance is announced with a token no other path prints —
`WP40_T2_C1_V3_RECORDED_EVIDENCE_ACCEPTED` from the driver, and
`WP40 T2 C1 v3 conformance REUSED RECORDED EVIDENCE …` from the launcher, both
carrying the recorded commit/tree/DAG, the closure size and the recomputed
artifact digest — so reused evidence can never be read as a fresh measurement.

The five properties are executable in `t2_extreme_conformance_test.lua`, which
builds a throwaway git repository under `/tmp` and drives the real closure
functions against a two-entry synthetic roster: a documentation-only HEAD
movement still verifies; moving one closure member refuses and names it (also
after that edit is committed, when HEAD and the working tree agree again and
only the recorded commit can still refuse); a refusing finalizer and a tampered
row are fatal; malformed, wrong-length, uppercase, missing, repeated,
non-existent, non-commit, out-of-history and wrong-tree pins each refuse with
their own diagnostic; and pre-v3 evidence cannot satisfy the v3 reader in either
direction.


### Historical S1 locked surfaces — lock dissolved 2026-08-25

These six files are covered by the stage-S1 authority digest that pins the
measured 4,096-candidate pool:

    tools/wp40/t2_s1_authority.lua
    mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua
    mods/MAPGEN/grug_mapgen/wp40/canonical.lua
    mods/MAPGEN/grug_mapgen/wp40/deterministic.lua
    mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua
    mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua

Editing any of them invalidated the historical pool and its four winner seeds.
The simple-map rebase dissolved this lock: current work may replace these
files deliberately under R1-R7 review, but old pool/winner evidence must not be
relabeled as evidence for the new schema.

`source/catalog.lua` and `geometry/partition.lua` may change freely — the pool
binds the Source by canonical projection rather than by file bytes, verified by
control experiment. That is the entire purpose of the S1 scoping.

### `git diff --check` is expected to report this branch

Two categories of whitespace here are correct and must not be "fixed":

- Everything under `evidence/` is a verbatim capture — console logs with box
  drawing and ASCII art, raw JSONL. Editing it falsifies the record.
- `t2_partition_oracle.lua` carries eleven trailing-whitespace lines and is a
  roster member of both conformance authorities
  (`t2_extreme_conformance_authority.lua:33` and the v3 roster). "Fixing" the
  whitespace would be a pointless byte change, so leave it. Editing the file
  for a real reason is a different matter and is *not* barred: the frozen
  pre-v3 DAG `086855378e…` is re-materialized from commit `5a2fc0d` through
  `capture_git`, so a working-tree edit cannot move it — measured 2026-08-21,
  the pinned DAG reproduced exactly while roster members were modified in the
  tree. What such an edit does move is the **v3** DAG, which is recomputed live
  at every launch; once an accepted v3 artifact exists, moving it costs a rerun
  under the recorded-commit closure rule above.

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
| PCC compiler witness pair | 69 s LuaJIT / 1,734 s PUC / 1,803 s total (Phase 0B, 2026-08-23) |
| PCC worker witness pair | 132 s LuaJIT / 2,325 s PUC / 2,457 s total (Phase 0B, 2026-08-23) |
| PCC seven-seed merge witness | seven retained per-seed worker walls sum to 346 s; exact whole-leg total and following merge/gate overhead were not retained; all three divergence halves passed within the 420 s cap (Phase 0B, 2026-08-23) |
| C1-v3 F2 PUC rescore / selected phase | 215 s / 5,507 s; ~99 min end to end (2026-08-22) |
| payload cache hit | 0.37 s LuaJIT / 1.03 s PUC |
| full partition gate, PUC, 8-way sharded | ~62 min wall |
| 4,096-candidate pool, 8 LuaJIT workers | 91 min wall |
| `run_t2_s1_authority.sh` test, PUC / LuaJIT | 111 s / 21 s (LuaJIT default since 2026-08-16) |
| `run_t2_extreme.sh` foundation, LuaJIT / PUC | 181 s / aborted unfinished at 1,975 s (LuaJIT default since 2026-08-16) |
| census Scan-1 worker pass, one seed, LuaJIT | 22.7 s seed 0 / 24–25 s max-u64 (M1, 2026-08-16) |
| census Scan-1+2 worker pass, one seed, LuaJIT | 30–43 s across seeds 0/Slot 29/max-u64 and repeat runs, host-load dependent (M3, 2026-08-16) |
| the Scan-2 share of that pass, unflagged seed | ~8 s in a 30-s run: ~5.4 s the eight lazy Wing tails, ~2.4 s the four trace-bound envelopes, ~0.15 s the 16 completion traces, ~0.13 s counting+probes (M3, 2026-08-16) |
| the flagged Slot-29 extra tuple (probe + dead trace) | below measurement noise: 30.6 s total, inside the unflagged band (M3, 2026-08-16) |
| census Scan-1+3a+2 worker pass, one seed, LuaJIT | 29–33 s, median 31 s over nine interleaved seed-0 samples; spikes to ~45 s under concurrent load (M4, 2026-08-16) |
| the Scan-3a surcharge, interleaved M3-vs-M4 A/B | ~0.4 s per seed, about 1.4 % — inside noise (M4, 2026-08-16) |
| the per-tier split after M4, one seed | stage build ~20–27 s, Scan-1 ~2.0 s, Scan-3a ~8.3 s, Scan-2 ~0.6 s (M4, 2026-08-16) |
| eight census workers, first completions, quiet host | 34–39 s per seed, projecting 5.7 h wall (M4, 2026-08-16) |
| eight census workers, steady state, four seeds each | 36–69 s per seed; per-worker means 37.5–54.0 s, projecting 5.4–7.7 h wall (M4, 2026-08-16) |
| the three slow first seeds of the aborted full-`W` start, re-measured solo | 29 / 31 / 32 s per seed, against 51 / 53 / 70 s in the contended start minute — the control seed took the same 29–32 s (full-`W` abort, 2026-08-16) |
| eight census workers, first completions, idle host, re-run | seven seeds 35–37 s, one 53 s, on a shard that was none of the three above (full-`W` abort, 2026-08-16) |
| seed 0 across the two full-`W` starts, same host, same bytes | 36 s then 51 s; the second start's shard 1 read 51/52/65 s on seeds 0–2 against seven shards at 34–39 s, two of which then took 51 s on their fourth seed. `cpu ≈ wall` throughout — SMT pairing churn, and its victims move between runs (second full-`W` abort, 2026-08-16) |
| a stage-rejected seed, LuaJIT | 8 s (W-112, first measurement 2026-08-17): the aperture block kills it before Scan-1/3a/2 ever run, so a stage-rejected seed costs a quarter of a full one |

The PUC-to-LuaJIT ratio is not one number: 2.8x on validation-heavy paths,
17.6x on the measured PCC worker pair, 25.1x on the measured PCC compiler
pair, and 26.5x on a full seed-0 compile. The former 16.2x "exhaustive numeric
sweep" figure had no retained measurement and is withdrawn; never apply one
ratio across workloads.

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
and run their full partition gates. That evidence now exists as the retained
2026-08-22 C1-v3 acceptance set and is not a second 4096-origin claim. This
slice does not publish geometry,
integrate `compiler.lua`, promote measured slots into the fixed corpus, or
claim Stage 2/T2/32-seed readiness. The former fixed-slot-19 blocker is now a
positive pinned R16/R17 prerequisite; every selected-extreme full-partition
failure remains fatal with no fallback. Slots 28--31 passed the unchanged
complete partition gate; corpus promotion remains pending.

The accepted C1 conformance launcher is:

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

## T2 census scans (Scan-1/Scan-3a/Scan-2 worker, launcher and merge, M1-M5)

The census contract lives in
[wp40-t2-plan.md](../../docs/research/wp40-t2-plan.md) section 6; this
section owns only the runner mechanics. M1 shipped the Scan-1 worker pass and
the frozen row schema, M2 the eight-shard full-`W` launcher with its GO gate,
verified resume, first-record validation and cost gate, M3 the Scan-2
counting and R19 tuple tiers on the same per-seed pass, M4 the Scan-3a
aperture, Wing, bank-width and head-Bank projections, M5 the
deterministic merge into the five section-6.2 artifacts plus the section-6.3
manifest, carrying the targeted `pairs()`-order divergence test and gated on a
byte-identical artifact digest under LuaJIT and the vendored PUC 5.1. The
stage-reject package (2026-08-17, plan section 6.7) moved the classified
aperture-formation failures from hard aborts to recorded `stage_reject` rows
after full-`W` start 3 lost three shards to one occupied 3-F9 class (record
schema `grug_wp40_census_scan_v4`, shard pattern `census-scan-v4-*`).
Full-`W` start 4 then measured all 4,123 seeds in 7 h 50 min and published
the artifacts; what it found is plan section 6.8, and the committed
artifacts under `fixtures/t2_census/` are that run's.

The collected-correction round (contracts section 8, gate 2 accepted
2026-08-18) republished the corrected artifacts as the v5-schema/v2-name
set. The Scan-3b/4 completion (contracts section 9) then grew the record
to schema `grug_wp40_census_scan_v6`: the sixteen transition-incident
Bank traces with the attribution histogram and the R20/R21 event
classifiers, and the Scan-4 face/Whole/fragment tiers on the ruled
membership (branch A, 3,061 = the v2 seed set plus the seven admission
seeds), with the worker KAT grown to seven seeds (the two F10 face
witnesses joined). Full-`W` run 6 (2026-08-19, 10 h 15 min, zero worker
deaths) measured all 4,123 seeds; the merge ran the section-9.2 top-up
protocol (15 extremal-winner seeds) and published the `census-*-v3.tsv`
artifacts and manifest, which supersede v2 for every downstream
consumer. What the run found and what follows from it is the contracts
section-10 decision memo.

```sh
tools/wp40/run_t2_census.sh --kat                  # 7 seeds: 0, the two F10 witnesses, W-112, Slot 30, Slot 29, max-u64
WP40_CENSUS_OUTPUT=/path/out.tsv \
  tools/wp40/run_t2_census.sh --seeds 0 7 4096     # small explicit lists run freely
WP40_CENSUS_OUTPUT=/path/out.tsv \
  tools/wp40/run_t2_census.sh --range 0 15         # a small slice of W, also free
tools/wp40/run_t2_census.sh --merge-kat            # the M5 gate: KAT, merge twice, compare
tools/wp40/run_t2_census.sh --plan                 # derive W, print the GO token
WP40_CENSUS_GO=<token> tools/wp40/run_t2_census.sh --full-w
tools/wp40/run_t2_census.sh --merge                # publish the five artifacts
tools/wp40/run_t2_census_probe.sh                  # measure the CPU gate (~5 min, saturates the host)
tools/wp40/run_t2_census_gates.sh                  # the six gates, proven negatively
```

LuaJIT by default, `WP40_LUA_BIN` overrides. One worker process evaluates
`partition.census_scan` per seed — the S1 R7 compile, Bay masks and fills,
then the F1 interval classes for all 61 edges, F7 junction-pair classes plus
the minimum pair clearance, F8 attachment Chebyshev distances, F6 fill
counts, and since M3 the Scan-2 tiers: `scan2_endpoint` rows (the F2
counting tier — every eligible incidence of the selected interval through
the exact shared R16 resolver; these are also the section 6.2.3 transition
stress scalars), `scan2_edge` rows (the R19 joint decision: exactly-one /
zero / multiple complete, duplicate authority, the 192-station backstop)
and occupancy-driven `scan2_tuple` witness rows keyed by their read-set
envelope digest. The tuple tier evaluates on every seed wherever at least
one tuple exists; the analysis section 5 flagging predicate survives as the
per-row `flagged` marker (decided 2026-08-16, M3 — the section 6.2
artifact-5 joint distribution, the U2 occupancy measurement and the
0-complete class are required outputs and are not measurable on the
predicate's skipped side).

Since M4 the same pass also runs Scan-3a, *before* Scan-2 and on one shared
Bank tracer: `scan3_aperture` rows (the eight F4 incidences, resolved
through the compiler's own terminal authority and classified from its reject
messages, with the emitted tail's water side decided here rather than at
trace time), `scan3_wing` rows (the eight F5 analyses under the decided
pair-exclusion reading — K candidates per side, complete tail paths,
raw/structural/wedge-valid pair counts, both selected ranks and the seven
per-cause exclusion counts), `scan3_bank` rows (the four head-Bank traces
with their step, station, DFS-frame and stack counts), `scan3_width` rows
(the section 6.4 `w = 0` event per Bay, in the exact body numerator
`E = base_width_num + delta_nodes*L`), and the occupancy-driven `scan3_step`
and `scan3_selection` rows that carry the realized F3 step-class coverage.
The order matters: Scan-2's completion tier and Scan-3a share one tail and
terminal cache, so a Wing resolved by Scan-2 first would return from cache
unanalysed — and running Scan-3a first is also why the Scan-2 share dropped
from ~8 s to ~0.6 s while the total pass did not move.

The worker emits one canonical TSV:
`schema`/`vocabulary` manifest lines, the seed-independent `prefilter`
block, per-seed `edge`/`perimeter`/`aperture`/`attachment`/`junction`/
`junction_pair`/`bay`/`scan2_endpoint`/`scan2_edge`/`scan2_tuple`/
`scan3_aperture`/`scan3_wing`/`scan3_bank`/`scan3_width`/`scan3_step`/
`scan3_selection` rows
framed by `seed_begin`/`seed_end` — the M1 rows stay an exact prefix of
each record, and the M1+M3 rows an exact prefix too — and a trailing
`digest` line over the exact preceding bytes.
Reject classes are recorded rows, not errors; the census continues
scanning. Per-tuple precondition failures (the decided U1 empty-clip and
U2 previous-binding readings among them) are DECIDED-with-continuation
tuple rows, never seed aborts.

Since v4 (the stage-reject package) a record has a second shape: a seed
whose `build_scan_stage` dies in the aperture block on one of the six
classified 3-F9 malformations emits exactly one `stage_reject` row — site,
class and the verbatim fail message — and nothing else; the two shapes are
mutually exclusive by grammar. Such a seed builds no stage and therefore
attests no prefilter, so stage_reject records may precede the prefilter
block, the block sits immediately before the first full record, and an
input with no full record at all is refused. The message-to-class map lives
beside `census_scan` in `partition.lua`; the class list is declared in
`t2_census_authority.lua` and the worker refuses to run when the two
disagree. Everything else still aborts hard by design: a discharged edge
realizing any interval count other than one (plan section 6.6.8), and every
stage-level global precondition outside the six classified sites — S1
validity, notch ownership, the two seed-independent mouth-absent lookups,
and the by-construction-unreachable maximality check, the latter two
declared as abort-by-design lines in the coverage report. The classifier
requires an aperture row id at the message head and re-raises anything
unmatched, so an unknown failure can never quietly become a row.

The prefilter discharges the 14 ordinary edges whose R7 envelope cannot
reach any Bay capsule-plus-jitter box, wing box, notch adjacency or the
displaced-coast margin. The 23 closure/frame edges that sit on the perimeter
itself stay conservatively `scanned` — the analysis's section 3-F1 criterion
carries no coast term, and widening the discharge set would need an explicit
footprint argument first. Discharged edges are still evaluated on every seed;
the block records verified predictions, not skipped work.

### The Scan-3a table-to-vocabulary map

The full map lives beside the projection, in `census_scan3a`'s comment in
`geometry/partition.lua`; the class lists themselves are declared once in
`t2_census_authority.lua`, because M5's vacuous-branch report is exactly
"declared minus realized" over them. Where the analysis section 3 tables and
the compiled decision procedure differ in granularity the census follows the
*procedure* and records the difference — a class no configuration can reach
is a vacuous-branch row, not a measurement. The three differences worth
knowing without opening the file:

- **F4 row 4** ("`W` missing / non-unique / non-diagonal / not same-Bay-only
  raw+final") is four classes in the procedure, one of which — W not
  immediately aperture-included — that row does not name at all. **F4 row 7**
  (wrong tail water side) is decided in `trace_bank`, and all eight
  incidences sit on transition-incident Banks, so a trace-driven reading
  would leave it unmeasurable until Scan-3b; the predicate is O(1) from the
  resolved `D,T,W` and the declared water side and is evaluated in Scan-3a.
  **F4 row 8** (terminal identity drift) reads only seed-independent catalog
  state: declared, expected vacuous, underlying failure still a loud abort.
- **F5** gains two classes with no table row at all — an empty distance-layer
  DAG and the finite path bound — and its single "structural pair fails
  side/disjoint/predecessor/X-cross" row splits into four counted causes,
  whose side clause is vacuous by construction because `collect_paths` emits
  strict-side stations only. `Chebyshev(K,J) > 4` is the section 6.4
  refuted-frozen-universal event and is the Wing's own class. Two of the
  declared classes are **dominated rather than merely unoccupied**, which a
  reader of a permanent zero needs to know: `wedge_radius_above_five` cannot
  fire because the Chebyshev guard has already hard-failed the Wing
  (`R = 1 + max Chebyshev(K,J) ≤ 5` identically), and
  `aperture_w_foreign_water_reject` cannot fire because
  `w_final_owned_by_bay` is tested first and implies `not w_foreign_water`.
  `intra_tail_x_cross` is vacuous for a third reason: a distance-layer tail
  visits one column per Chebyshev level, so two of its diagonal steps can
  never share a 2×2 cell.
- **F3** declares six step predicates, not the table's five, and gives the
  lone-admitted-successor case its own selection class. Foreign-water contact
  gets no class: `bay_candidate` absorbs it, so it reaches the census as a
  zero-reachable-successor reject.

### The merge, and what the five artifacts say (M5)

`t2_census_merge.lua` consumes a complete verified record set and emits the
five section-6.2 artifacts plus the manifest, into
`fixtures/t2_census/` for a full-`W` run and into a scratch directory
otherwise. Two input framings, one grammar: `--full-w` reads the eight
canonical shards, verifies each against the authority and requires them to
cover `W` in order and exactly once; `--records` reads free worker output,
which carries the frozen M1 preamble instead of a shard header and therefore
states no commit, tree or interpreter — the manifest says so, so a KAT
artifact can never be read as a measurement of `W`. Verification and
aggregation share one parse (the authority's verifier takes a per-row
callback), and no per-seed intermediate is retained.

- **census-occupied-classes-v1.tsv** — one `occupied` row per (site,
  decision class) with its seed count, row count and least witness seed;
  one `witness` line per row carrying that witness's **verbatim record row**,
  which is section 6.3's "configuration bytes"; `derived` rows for the three
  section-3 branches that have no class column; and the section-6.4
  `no_branch_matched` sink, whose emptiness is stated in the summary rather
  than left to be inferred. A REJECTED verdict is a finding, and the verdict
  per branch is *declared* in the authority rather than inferred from a name
  suffix — `scan2_tuple_probe_wet` and `x_cross` both read like failures and
  are both ordinary DECIDED-with-continuation outcomes under U1/U2. A
  stage-rejected seed contributes exactly its occupied row and witness here
  and its `stage_reject` flag to artifact 3 — nothing to extremal, derived
  or histogram stores, which the merge asserts per record rather than
  leaving to which folds read which tags — and the summary and manifest
  count `stage_reject_seeds` explicitly.
- **census-vacuous-branches-v1.tsv** — every declared branch with
  realized/vacuous and its status: `dominated`, `vacuous_by_construction`,
  `expected_vacuous`, `out_of_scope_scan3b`, `consequent` or `in_scope`, plus
  the `derived` and `unmeasured` line kinds. A permanent zero that is
  dominated and one that is untested must not read alike. As of the v3
  artifacts (run 6) `out_of_scope_scan3b` is retired by measurement:
  Scan-3b ran, and every branch it covered is now declared in scope or
  measured vacuous.
- **census-scan4-seed-set-v1.tsv** — the named union: flagged ∪ per-site
  extremal ∪ winners ∪ corpus, with one `extremal` line per (site, scalar,
  bound), one `open` line per Scan-3b Bank **named**, and the Holy band's
  exclusion stated with its reason and verified against the rows.
- **census-prefilter-discharge-v1.tsv** — all 61 edges with status and
  reason, agreeing across every input, plus the re-derived verification that
  no discharged edge ever realized an interval count other than one.
- **census-histograms-v1.tsv** — the section-6.2.5 distributions and
  Scan-3a's own, with an explicit `universal` line per section-6.4 universal
  including its zero.

Section 6.5 wants the run manifest to state the measured single-seed cost and
the projected total in wall time at a stated worker count. The merge is a
separate process hours after the scan, so the launcher persists its projection
to the gitignored `results/t2_census/cost-projection.txt` beside the shards it
describes, and `--merge` reads it from there; `WP40_CENSUS_COST_PROJECTION`
overrides it for a merge of shards whose run predates that file. The note holds
the newest of the rolling evaluations below, not the first: by the last
completion of the run that line has stopped being a projection and is a
measurement of the slowest shard.

The M5 gate is `--merge-kat`: run the four-seed worker KAT, merge it under
LuaJIT and under `tools/bin/lua51`, compare all five artifacts byte for byte,
and check the artifacts digest against the fixture's pin. Only the PUC run may
write into the committed fixtures, so the half that publishes is never the
half that is merely compared — and it is handed the LuaJIT run's digest as
`--expect-artifacts-digest`, which it checks *before* it writes anything.
Comparing only afterwards would leave six unvetted files in the committed tree
whenever the gate fired, and the retry would then abort on "already exists"
instead of on the divergence. The digest covers the five artifacts and not the
manifest, which names the merge interpreter and differs between the two runs
by construction.

The `pairs()`-order divergence test (plan section 5) rides here because census
aggregation is the iteration-order-dependent control flow it exists to catch.
It has two halves: a probe that shows this runtime's `pairs()` really does
hand out a non-sorted order, and an invariance half that folds a synthetic
record set covering every declared class, plus the measured records where they
fit in memory twice, through the whole artifact construction in two different
orders and requires byte-identical output. A merge whose probe comes back
sorted **aborts** rather than recording the fact and continuing: the
invariance half would then pass for the one reason that makes it meaningless,
and it is recorded in the manifest, which the compared digest does not cover. It found a real defect on its first run: a
Wing counts seven pair-exclusion causes on one row, so a site can realize the
same branch through several rows of one seed and "the first such row" was an
arrival-order choice. The witness is now the least row of the least seed.

`fixtures/t2_census/scan_kat_v6.lua` pins the M1+M3+M4+M5 KAT plus the
stage-reject witness: the section
3-F6 witness fills (seed 0 `0/0/0/0`, Slot 30 `0/0/0/0`, Slot 29 `0/0/0/0`,
max-u64 `1/1/1/0`), the
structural row counts, six transition edges with qualifying count one, 102
passing junction pairs, attachment distances at most one, the
zero-displacement Holy band, the measured Scan-2 counting and joint-decision
values per endpoint and edge, and the determinism digest over all five
seeds. The fifth seed is W-112 = 343674299183575008, the seed full-`W`
start 3 died on: it emits a `stage_reject` record instead of a roster, and
the worker asserts it still stage-rejects at the pinned site and class —
a witness that quietly built a full stage would mean the 3-F9 occupancy
this package records has vanished. The load-bearing M3 pin is the Slot-29 R19 witness (analysis section
3-F2): `land_010:to` holds two direct R16 candidates, the endpoint's own
tuple dies bank-incomplete — the dead-direct-terminal shape that generated
R19 — and the retreat tuple completes, exactly one complete joint tuple; at
max-u64 the same endpoint resolves via the diagonal elbow, agreeing with
the pinned 7-direct/1-elbow R16/R17 prerequisite fixture.

M4 adds three load-bearing pins, all measured rather than adopted. The
**retained R15 corpus comparison**: the Scan-3a Wing projection reproduces
all five quantities of source-authority section 6.1 at every KAT seed — raw
pair counts `4,18,18,4,2,18,18,18`, wedge-valid exactly one each, selected
ranks `1,10,2,1,2,17,9,17`, radii `4,5,5,4,3,5,5,5` and both tail lengths per
Wing — which makes the corpus an acceptance oracle for the Wing analysis
rather than a number copied forward. It also carries the section 3-F5
Slot-29 witness (Kragmar-west-left: 2 structural pairs, 1 wedge-valid at rank
2), which turns out to hold at every seed and not only at Slot 29. The
**aperture tail-mode witness**: Slot 29's Elandor-east `before` incidence is
the first measured tail-mode occupancy, and its emitted tail keeps `W` on the
declared water side. And the **head-Bank shape**: all four complete at every
seed with zero branching steps, so the reachability DFS never runs and both
trace stress scalars are zero — the analysis's "path lengths 453–794, DFS
frames ≤ 24" came from transition-incident Banks, which are Scan-3b.

M5 adds the fourth seed and re-shapes one M4 pin. **Slot 30** is the analysis
section 3-F8 fragment case and no earlier KAT covered it: `land_007` carries
two maximal dry intervals of which one is a singleton, exactly one qualifies,
and the attachment on that edge sees the same count — the excluded dry
fragment, reproducing 3-F8 and 3-F1 as written. And the **bank-width pin is
now per seed and per Bay**, because Slot 30 refutes M4's reading that the
station minimum sits where the taper forces `delta_nodes = 0`: it moves to a
jittered station in two of the four Bays (75 nodes at delta −30, 74 at −26).
The taper decides the *segment*, not the station. The exact per-column bound —
which is what actually rules a collapse out — reads 46 there, the tightest of
the four seeds and still 14 above the structural floor of `80 − 48`.

The record digest moved legitimately at M3 (the record grew the Scan-2 rows),
again at M4 (the Scan-3a rows), again at M5 (the fourth seed) and again with
the stage-reject package (schema v4 plus the fifth seed), and is
re-pinned at `a9c3ecfc...`; it remains the determinism gate for everything
after. `merge_artifacts_digest` (`2a22bfd9...`) is its counterpart over the
five artifacts. The five-seed KAT merge itself now carries a finding by
design — `rejected=1 stage_reject_seeds=1`, W-112's occupied
`aperture_second_run_reject` row — which is the pinned proof that a
stage-rejected seed survives worker, validator and merge as a row rather
than as a dead shard. The LuaJIT/PUC comparison is the merge gate; M1-M4 run PUC
only as the language contract (`luac51 -p`, `SETGLOBAL`, the five sweeps —
which are scoped to `mods/*/grug_*` and must be run explicitly for `tools/`).

### One declaration point

`t2_census_authority.lua` owns every rule more than one consumer needs: the
`W` derivation, the eight shard ranges, the shard path, the decision-class
vocabulary with its per-seed site roster, the GO-token rule and the two
numeric gates. The launcher, the worker and the merge ask it rather than
restating it — a second copy of the shard-name rule is what aborted a fresh
pool launch before any seed was measured (see the comment in
`run_t2_extreme_shards.sh`). Plan section 6.7's file cut names three census
files; this is a deliberate fourth, with `t2_census_gate.lua` (launcher-side
entry points), `t2_census_hasher.lua`, `t2_census_sha_server.py` and the two
gate-proof harnesses alongside.

M5 completed the declaration rather than starting a second one beside it. The
merge reads every field by name, so the record grammar gained `columns` and a
`site` key per row kind, cross-checked against the frozen widths at load. The
section-6.2.2 report is "declared minus realized", so the branch universe
gained the verdict per branch, which vocabularies are decision branches at all
(a mode or a kind is a row shape, not dead policy), the M3/M4 review's notes
on why a given zero is expected, and the section-3 rows that are `derived`
from counting columns or `unmeasured` by this record. And section 6.2.3's
153-site roster and flagged predicate are declared here too, because "the
artifact covered 137 of 153 sites" is only checkable against a stated total.

`W` is derived, never listed: the 27 corpus slots — seed 0 is slot 1 and
max-u64 slot 19 — plus the 4,096 pool candidates recomputed from the
committed `grudgelands-wp40-extreme-NNNN` label rule and cross-checked row
for row against `candidates-luajit-v3.tsv`. Measured **|W| = 4,123**: the
two terms are disjoint, so the plan's approximate 4,130 is 7 high, and the
eight shards are three of 516 and five of 515 rather than the pool's clean
512s. The order is ascending canonical unsigned-64 decimal and the seeds
never pass through a Lua number.

### The six gates, and why they are proven negatively

`run_t2_census_gates.sh` drives each gate to its refusal, in a throwaway git
export of HEAD so the real tree is never written; `t2_census_gate_test.lua`
does the same against the decision functions directly (4,707 checks, 78 of
them demanding an abort for a named reason). A gate that refused everything
would pass all the negatives, so the positives are proven too: a well-formed
shard is resumed and costs exactly one worker, a real worker record validates
while the run continues, a free record set merges into all six outputs, and
the cost gate is replayed over two measured completion timelines — the start
minute that must *not* abort and a fleet at 71 s per seed that must.

1. **GO gate** (section 6.6.7). The full-`W` path starts only when
   `WP40_CENSUS_GO` equals this `W`'s digest. The token is a digest rather
   than a word because it is checkable and names which seed set was
   approved: every worker re-derives `W` and re-checks the token itself, so
   a direct worker call cannot start a full-`W` slice either — which is what
   replaces M1's 64-seed list cap now that range mode exists. Any run above
   64 seeds needs the token; a gated range must additionally be one of the
   eight canonical ranges and publish at the canonical shard path, and a
   free run is refused a shard file name so a three-seed file can never be
   resumed as a finished shard.
2. **First record** (section 6.6.2). Fan-out is immediate and at full width
   — there is no serial pre-validation pass (plan section 5). The launcher
   validates each worker's first *completed* record against the contract
   while all eight keep running: every declared site present at its roster
   count, every row at its declared width, every class string drawn from the
   declared vocabulary. That check is why the worker streams and flushes per
   record instead of materialising its TSV at the end. A structural failure
   aborts the fleet. If no worker produces a validated record within
   `WP40_CENSUS_FIRST_RECORD_DEADLINE` (default 900 s) the run aborts too — a
   worker that hangs before writing anything is the same early failure.
3. **Cost gate** (sections 6.5 and 6.6.3). Once every running worker has a
   completion the slowest shard is projected to full length, and from then on
   the whole projection is re-taken at every completion. The projection takes
   the
   slowest shard rather than a sum or an average because the shards run
   concurrently: summing inflates by the worker count, averaging hides an
   unbalanced run. A shard's rate is its **own** elapsed seconds at its **own**
   latest completion over its own completed count — the launcher reads that
   pair out of the shard's progress line — and a rate may only cast a verdict
   once that shard has completed two seeds. Until then it is reported and
   deferred: the projection line carries `completions=`, an
   `observed_…_seconds=` that includes single-sample shards, and
   `verdict=passed|deferred|aborted`, so an over-budget observation that did not
   stop the run is in the log rather than behind it. Deferral belongs to the
   verdict and not to the fleet — one shard stalled after its first seed must
   not buy seven provably over-budget siblings an exemption — so the budget is
   applied to the slowest shard that *has* answered twice.

   **What it is compared against moved on 2026-08-18** (plan section 6.5, "why
   the wall cap retired"): this host is a workstation, so concurrent user load
   is normal operation rather than degradation, and wall time cannot separate a
   contended run from a pathological one. The wall projection survives — same
   estimator, same line, now reading `verdict=advisory` — and is what the
   manifest still states in wall seconds at eight workers, for the operator to
   read. Nothing aborts on it. The hard abort is the same rolling estimator
   re-based on the **CPU** seconds each worker reports beside its wall figure on
   the same progress line, against a per-seed CPU budget of a measured anchor
   times a measured contention margin (`WP40_CENSUS_CPU_BUDGET_SECONDS` lowers
   it, which is how the negative proof fires inside two minutes). Beside it
   rides a **liveness gate**: the fleet consuming more than `X` CPU-seconds
   since its last completed seed aborts — the busy-loop hang — while a fleet
   merely starved by user work accumulates no CPU and is never accused of it. It
   arms at the first completion, because before that there is no such span and
   the run's first seeds are its most expensive; that window is gate 2's.
   Honest residual, recorded in the plan: a worker blocked forever while
   consuming no CPU trips nothing automatic. An estimate re-taken all run long
   can also find a breach late; the abort then keeps every finished shard
   through gate 4's reaper and the next `--full-w` resumes them, which is
   section 6.5's "report and re-scope" rather than "abandon".

   The budget and `X` are measured, never estimated:
   `tools/wp40/run_t2_census_probe.sh` scans three KAT seeds solo and then again
   under one busy loop per logical CPU, and writes the worst solo per-seed CPU,
   the worst inflation ratio (rounded up) and ten times the worst loaded seed to
   the gitignored `tools/wp40/results/census-cpu-gate.conf`. A `--full-w` start
   refuses to begin without that file, or with one dated before its own HEAD
   commit — a margin measured before the code that would spend it is a number
   about a different program. The workers themselves launch under `chrt --idle 0`
   plus `ionice -c3` (`nice -n19` where those are refused), so user work
   preempts the fleet and the run stretches instead of the user yielding the
   machine: the accepted consequence of the same decision. Measured at M4 under
   the retired wall gate, and still the reason the host matters: the same probe
   read 34–39 s per seed on an idle machine and 71 s per seed while a second
   eight-worker measurement ran.

   The cap itself was re-decided over the *second* full-`W` start, 2026-08-16,
   and the estimator was left alone. That run aborted at a projected 28,896 s
   against 28,800 s — 0.33 % — from a shard whose seeds 0–2 took 51/52/65 s
   while the other seven ran 34–39 s and the corpus ETA read 22,728 s. Seed 0
   had cost 36 s in the previous start and `cpu ≈ wall` throughout, so this is
   SMT pairing churn and its victims move between runs: two shards that held
   34–37 s for three seeds took 51 s on their fourth. Eight hours sat 0.33 %
   *below* the noisiest honest projection and therefore could not separate a
   noisy run from the one measured degradation case (71 s per seed, 36,636 s);
   nine hours is the round hour at the geometric middle of those two bands and
   clears them by 12.1 % and 13.1 %. Plan section 6.5 carries the decision; both
   runs are replayed from their own measured per-seed times in the gate test.

   Two boundaries of that rule, measured and pinned in the replay tests rather
   than left to be rediscovered. First, two completions is a thin basis for a
   nine-hour cap: 32,400 s over 516 seeds is 62.79 s per seed, so one shard
   averaging above that across its first two seeds aborts a fleet whose other
   seven are on a 5.2 h pace — a 53 s cold first seed followed by a 73 s second
   is enough, and neither figure is outside what this host has produced. That is
   the cap's arithmetic meeting the two-completion rule, not slack the estimator
   picked; only a higher completion count would widen it. (At the retired cap
   the trigger sat at 55.81 s per seed, close enough that a 53/60 pair reached
   it; that fleet passes now, pinned in both directions so the flip is a
   recorded consequence rather than a discovery.) Second, a deferral
   has no ceiling of its own: eight shards each holding a single completion are
   deferred no matter how far over the cap that one observation lands, because
   what bounds the deferral is the next completion. In the ordinary case that
   costs one seed. A fleet that stops completing seeds entirely is not the
   projection's to catch and never was — gate 2's deadline covers a worker that
   produces no record at all, gate 6's death watch reaps a worker that exits
   early, and since 2026-08-18 the liveness gate covers the fleet that keeps
   burning CPU while nothing closes. What remains uncovered, by decision, is the
   worker still alive, stalled mid-range and consuming nothing: that one is the
   operator's to see.

   The two-completion rule is there because the first seed of a shard is
   systematically the most expensive — cold JIT, and eight R7 compiles landing
   at once — and because 2026-08-16 spent a full-`W` start proving it. That
   run aborted on 71 s per seed projected from eight first completions, three
   of which read 51/53/70 s against five at 36–37 s. Re-measured solo, those
   three seeds took **29, 31 and 32 s**, exactly what the control seed takes:
   the spread was eight workers and eight SHA responders contending for eight
   physical cores in the one minute the gate sampled, not three expensive
   seeds. The launcher also divided by its own wall clock rather than the
   shard's, so a shard that had finished a seed in 36 s was credited with the
   fleet's age — 71 s per seed — for as long as a slower sibling had not
   finished. Both are fixed here; the cap, the full-width fan-out and the
   worker count are unchanged. Re-run the same day on an idle host, seven of
   eight first seeds took 35–37 s and one took 53 s, on a shard that was not
   one of the three outliers — a cold-start cost that moves between runs is
   exactly what a single sample cannot tell from an expensive seed.
4. **Verified resume** (section 6.6.4). A shard already on disk is parsed,
   digest-checked against its own preceding bytes, and required to cover
   exactly its range of this `W` under the same module bytes before it is
   skipped. Anything unparseable aborts loudly — including the empty claim
   file a crashed worker leaves behind, which is never read as an empty
   shard. The key is the module digest, not the commit: a shard header
   records its commit for provenance, but resuming on the commit SHA would
   throw away hours of finished measurement the moment an unrelated docs
   commit landed mid-run. When the launcher aborts, it re-verifies the shards
   *it* started and removes only those that do not stand up, so a finished
   shard keeps its hours and the next `--full-w` is not blocked by the
   partial files of the last one.
5. **Merge gate** (sections 6.3, 6.4 and 6.6.5). The same inputs merge under
   LuaJIT and under the vendored PUC 5.1 and the five artifacts must come out
   byte for byte identical; only the PUC run may write into the committed
   fixtures, and only a full-`W` merge may publish at all, so a KAT artifact
   can never claim a provenance it does not have. A shard read as a free
   record set is refused and so is the reverse, a merge over a directory it
   already wrote is refused, and the pinned artifacts digest is checked
   against the KAT fixture — the LuaJIT/PUC comparison shows the runtimes
   agree, the pin shows they agree with a reviewed measurement. The
   section-6.4 sink is the one gate that does *not* abort: the merge writes
   every artifact, reports the count and exits 3, because a configuration no
   branch covers is worth stopping for but its evidence is worth keeping.
6. **Worker-death watch** (section 6.6.9; added 2026-08-17, after run 3
   carried three dead shards past an hourly log watch). The monitor loop
   reaps every exited worker at its two-second poll, and an exit short of a
   complete range — crash, kill, or a zero-status bug alike — kills the
   remaining workers, tails every shard log into the main log and exits
   nonzero, instead of the death surfacing when the last survivor finishes
   hours later. Unlike a cost-gate abort, nothing is reaped: the workers are
   deterministic, so a blind resume dies at the same seed, and the partial
   shards stay on disk as triage evidence until the operator removes them —
   the next start follows a fix that moves the module digest and would
   refuse them anyway. Proven live before start 4: the real fleet was
   launched, one worker killed before its first completion, and the
   launcher aborted at the next poll with
   `worker exited status=143 at completed=0/516 seeds`, every shard log
   tailed into the main log and every partial left in place.

A refusing gate exits 3 and a broken one exits 1, and the launcher says which
happened. Without that split it would report a cap overrun when the
projection had actually crashed — the shape of the vacuous ripgrep gate and
the zero-worker verification run, and the first thing these proofs caught.
For the same reason the launcher carries no `started + resumed == 8` guard:
over a loop of eight indices each incrementing one counter, that comparison
cannot fail. What forbids a zero-worker success is at the end of the run,
where every shard is re-read from disk and the seed counts the *verifier*
reports must add up to |`W`|.

### Paths, provenance and cost

Census shards are per-seed intermediates, which section 6.3 forbids
committing, so they are written to the gitignored
`tools/wp40/results/t2_census/census-scan-v4-%04d-%04d.tsv`; only the merged
section-6.2 artifacts belong under `fixtures/t2_census/`, as
`census-{occupied-classes,vacuous-branches,scan4-seed-set,prefilter-discharge,histograms,manifest}-v1.tsv`.
The shard name shares no stem with either pool pattern
(`shard-luajit-*.tsv`) and the disjointness is computed, not asserted in
prose. The artifacts are absent until the full-`W` run and its merge have
happened; the KAT writes the same six files into a scratch directory.

A full-`W` run requires every geometry module and launcher file to be tracked
and unmodified against `HEAD`, and each worker pins those bytes before it
loads them and re-reads them before it publishes. That replaces the extreme
launcher's per-shard `git archive` of the whole tree: same guarantee that a
shard belongs to one commit, without eight full exports.

The SHA path is a persistent responder (`t2_census_sha_server.py`) over a
FIFO pair rather than the extreme worker's batch script. Measured on one
seed-0 pass: 639,512 `raw_sha256` calls, **1,004 of them distinct**,
discovered inside the R7 compile — so the batch script's discover-then-strict
shape would cost a second ~25 s compile to remove ~1.3 s of fork overhead,
and `t2_sha256_batch.py` cannot be edited anyway because it is byte-pinned by
the extreme authority DAG. Same framing, same `hashlib`, verified per session
against three fixed vectors and the first eight real inputs. A/B on seed 0
with four processes in parallel: **33-35 s wall with the fork hasher, 26 s
with the responder**, KAT digest `08547fef` unchanged either way.

Per-seed cost is noisy on this host — 22 s to 37 s for the same seed-0 pass
across runs, depending on concurrent load — so the plan's 22.7 s anchor is
the fast end and no schedule should rest on it. Eight workers producing their
first records took 28-36 s per seed, which projects to roughly 4.7 h for
Scan-1 alone, inside the cap. The gate re-projects from the live run for
exactly this reason; it is not an extrapolation from section 4.

Still open for M3 and later: the R19 tuple enumeration the compiler does not
carry (plan section 5), Scan-2's counting and tuple tiers, Scan-3a, and the
merge with its LuaJIT/PUC digest comparison. One fact a fresh session should
not re-derive: `fixtures/t2_extreme_e0/max_u64_r16_r17.lua` pins the
`partition.lua` bytes (`partition_sha256`), so any partition edit must re-pin
it and rerun `run_t2_extreme.sh` — the pool itself is unaffected. M2 touched
no file under `mods/`, so that rule did not fire here.

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
