# R9-PERF completion record — 2026-09-20

**Status: implemented and independently reviewed; WP48 remains open.**

This record closes the bounded R9-PERF implementation package at candidate
`e8e79c87c2022f02f9c8229a941b6da98a39cef7`, based on
`2a3088917b10f047dea9561b9f3fd36717619fff`. It does not close WP48, lift the
single-emerge-thread pin, redesign mapgen output or change gameplay. Broader
changed-run post-processing remains open, and parallel emerge remains blocked
by the engine issue recorded in WP48.

## Delivered changes

The package contains three bounded production optimizations:

1. R5 and R6 stop repeating liquid-neighbor analysis after a column is already
   known dirty; the accumulated result and direct liquid signals are retained.
2. Horizontal classification uses a session-local 65,536-entry FIFO memo that
   preserves exact tuple arity, nil holes and false values. The exact
   world-anchored lattice LRU grows from 4 to 16 entries.
3. Composed R5 execution delegates lighting to the final R6 transaction.
   Standalone R5 retains its former lighting ownership, and R6 validates the
   combined final context before any setter runs.

The production seams are
`mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua`,
`mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua` and
`mods/MAPGEN/grug_mapgen/wp40/height.lua`. The profiler, comparator and focused
fixtures live under `tools/wp40/profile/`, `tools/wp40/quality/` and
`tools/r9_perf/`; the six full runs and three pair comparisons are preserved in
`tools/r9_perf/evidence/`.

## Output equality and measurement

Every cold-generation and disk-reload result agrees on all 97 owners and
49,664,000 voxels. Content, param2 and light share the full digest
`4bc7438edfe1ecfa871fdc39c2ada49d7c59b57769e037fd7d6c3fa627812a9`.
The profiler authenticates the engine, seed, stages, input identities, owner
sets and complete output channels before comparing callbacks by owner.

Across the six sequential fresh starts and three alternating single pairs, the
sequence endpoints are:

| Metric | Result |
| --- | ---: |
| Startup elapsed | 77.572800 s → 64.187408 s (-17.26%) |
| Callback total | -27.47% |
| Writer total | -34.90% |

These numbers cover seed 0, one emerge thread and one machine. The elapsed
comparison reuses the first and last runs of the sequence; it is not a fourth
independent pair, a confidence interval, a steady-state exploration result or
a 100-player result. It is therefore a descriptive endpoint for this bounded
corpus rather than a general performance guarantee.

## Verification and retained failures

Static checks, the fresh-server audit, focused PERF fixtures, the existing
Round 6–9/WP fixture fleets and two separate 60-second headless boots passed.
The implementation fleet initially reported 39/41 because a generic wrapper
asserted on two valid nil-return KATs; both corrected direct invocations passed.
The independent fleet initially reported 80/81 because its R7 unit
runner received a relative LuaJIT executable; the corrected absolute
`/usr/bin/luajit` invocation passed. The original logs remain part of the
evidence and neither invocation issue identified a production failure.

The first final pair at `ca6035b8` is also preserved. Its compact test fixture
accidentally entered a LuaJIT FFI decoder path unavailable to PUC 5.1. Candidate
`e8e79c87` removes that fixture dependency without changing production bytes;
its corrected LuaJIT fixture output is byte-identical to the earlier LuaJIT
output. This was one pre-review tooling fix, separate from review fix rounds.

The one replacement final pair ran the frozen final bytes once under PUC 5.1
and once under LuaJIT. Both produced the same 61,236-byte canonical output:

`6a7bc3e4f266b3969f6e82578ceab9b6a0ed94cb552ff8fe42706274fde23fd4`

## Independent review and calibration

The independent review returned **MERGE** with 0 Critical, 0 High, 0 Medium and
0 Low findings. It inspected the frozen source and evidence without duplicating
the Lua or engine runs. Implementation used GPT-6 Astra; independent review
used GPT-5.6 Sol with xhigh reasoning. Review fix rounds: 0. Pre-review tooling
fixes: 1, described above. Observed elapsed delivery time: unknown.

The [independent review](r9-perf-review.md) is archived with this record.
Before the integration commit, the orchestrator verified that all 7,155 files
bound by the final-micro input manifest match the integrated tree exactly.
The input-manifest SHA256 is
`8b653f672c83df18885508a320abc314c2dbe306d482b9a3abb65283d21c597f`.
Synchronization and push are recorded separately in the orchestration handover.

## User runtime checklist

On a fresh world using the integrated candidate:

1. Visit a coast and check that shore transitions, shallow water and nearby
   generated terrain look intact.
2. Check daylight and underground lighting around newly generated terrain,
   including water edges.
3. Save, stop, reload and revisit the same area; verify that terrain, water and
   lighting remain unchanged and no generation error appears.
4. Run the separate real fallback-engine PUC 5.1 startup, generation and reload
   gate. The byte-identical standalone final pair supports compatibility but
   does not replace that user-run engine check.
