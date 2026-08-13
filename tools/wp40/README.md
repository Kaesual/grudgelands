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
