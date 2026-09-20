# R9-PERF bounded checks

Run from the checkout root with plain Lua 5.1 parsing and LuaJIT execution.
No command below starts an engine or records a performance measurement.

```sh
nice -n 19 python3 tools/r9_perf/profile_compare_test.py
nice -n 19 luajit -e 'io.write(dofile("tools/r9_perf/profile_probe_test.lua")("."))'
nice -n 19 luajit -e 'io.write(dofile("tools/r9_perf/cache_fixture.lua")("."))'
nice -n 19 luajit -e 'io.write(dofile("tools/r9_perf/lighting_fixture.lua")("."))'
```

The probe check mocks SHA and voxel reads to test collection, ordering and
reload control flow; actual byte authentication belongs to the engine profiler.
The cache fixture tests tuple arity, nil/false values, bounds, failed queries,
FIFO eviction and lattice LRU order. Existing `tools/r8_map_a/kat.lua` checks
the exact world-grid sample positions and tie rules. Cache scope is one
immutable world/seed session: 65,536 classification tuples and 16 completed
80×80 lattice tiles, with four scalar arrays per tile. Eviction changes cost,
never output. No final coast target is cached: supplied terrain participates
in its result.

`writer_equivalence.lua(repo, production_repo)` runs the actual R5 planner and
adapter over a synthetic source, then the actual R6 Gravewood successor fixture.
It hashes complete emerged content, param2 and light buffers, R5 intent runs
and external VM call traces, and reports dirty-column counts. Pass an immutable
snapshot root as `production_repo` for before/after comparisons using identical
current fixture tooling. The source contract is synthetic; the real engine
profiler and complete package gates remain required for production integration.

`lighting_fixture.lua` uses a compact R5 slice to exercise explicit
`outer_transaction` delegation: content, param2, result and liquid call intent
match standalone R5 while all inner light calls disappear. A real R6 fixture
injects invalid semantics into its final halo light context and requires failure
before any external setter. Both this fixture and the cache fixture are included
in the single final PUC/LuaJIT micro pair; do not run an intermediate PUC suite.

R5's optional final `apply` argument is an internal composition contract.
Absent means standalone lighting. `outer_transaction` means the caller must
validate and commit lighting after settling all successors. R6 is that caller;
its shadow methods reject accidental inner lighting. Dirty-column/result flags
still describe the R5 projection. Final combined-context validation remains
mandatory; discarded intermediate shadow lighting is not an independent
transaction and no longer computes seeds or restoration buffers.

`static.sh LUA_FILE ...` runs only parser, SETGLOBAL and the five source sweeps.
It prints matches for review (tool-only I/O and comments are not mod violations).
The historical `tools/wp11/static.sh` also launches runtime suites including PUC;
when intermediate runtime gates are prohibited, use only its static portion and
run `tools/check_fresh_server.py` separately. The final gate invocation belongs
to the orchestrator.
