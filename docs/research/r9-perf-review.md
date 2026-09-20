# Independent R9-PERF Review

**Verdict: MERGE**

Candidate: `e8e79c87c2022f02f9c8229a941b6da98a39cef7`  
Baseline: `2a3088917b10f047dea9561b9f3fd36717619fff`  
Production tip: `2acaa9a75372b5274c683f40ace4052f08dc90d2`  
Frozen snapshot: `/tmp/grudgelands-r9-perf-20260919/gate-tree-e8e79c87`

## Findings

- Critical: none.
- High: none.
- Medium: none.
- Low: none.

No verified code defects or evidence blockers remain.

## Production review

- Liquid-column short circuits preserve monotonic dirty decisions and counts. R5 skips only subsequent liquid analysis after the column is already dirty ([map_adapter.lua](../../mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua#L1212)); R6 likewise retains direct liquid signals and the accumulated column result ([r6_settlement.lua](../../mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua#L3282)).

- The classification FIFO stores explicit tuple arity and therefore preserves nil holes, false values and short returns ([height.lua](../../mods/MAPGEN/grug_mapgen/wp40/height.lua#L4)). It is bounded, failure-before-mutation, and session-local at the real horizontal-classification consumer ([height.lua](../../mods/MAPGEN/grug_mapgen/wp40/height.lua#L2151)). The lattice cache remains world-anchored and exact; only its bounded LRU capacity changes to 16 ([height.lua](../../mods/MAPGEN/grug_mapgen/wp40/height.lua#L5261)).

- R5 retains standalone lighting ownership by default and accepts only the explicit outer-transaction mode ([map_adapter.lua](../../mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua#L987)). R6’s shadow rejects accidental inner lighting calls and delegates explicitly ([r6_settlement.lua](../../mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua#L2116), [r6_settlement.lua](../../mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua#L2124)). The final combined context is classified before any setter ([r6_settlement.lua](../../mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua#L3345)); the external commit follows afterward ([r6_settlement.lua](../../mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua#L3402)).

- Profiler owner collection, canonical ordering, cold-manifest persistence and exact disk reload are implemented at the real probe boundary ([probe/init.lua](../../tools/wp40/profile/probe/init.lua#L247)). Comparison authenticates full digest, vocabulary, sample, harness, engine, seed, stages and exact owner sets while matching callbacks by owner identity ([compare.py](../../tools/wp40/profile/compare.py#L15)).

- The `e8e79c87` compact-fixture change removes the eager FFI decoder only from compact composition setup, while retaining the actual content contract, planner and adapter ([writer_equivalence.lua](../../tools/r9_perf/writer_equivalence.lua#L68)). The corrected LuaJIT output is byte-identical to the preceding snapshot, so coverage and production data did not silently change.

No threading, plateau, gameplay, or mapgen-output redesign was found.

## Evidence checked

- Frozen-tree manifest: all 8,504 tracked hashes verified.
- Six sequential fresh profiling runs and three alternating single pairs were inspected.
- Every cold and disk phase agrees on 97 owners, 49,664,000 voxels and full content/param2/light digest `4bc7438edfe1ecfa871fdc39c2ada49d7c59b57769e037fd7d6c3fa627812a9`.
- Sequence endpoint: callback total `-27.47%`, writer `-34.90%`, elapsed `-17.26%`. The committed report correctly identifies this as reused endpoints, not a fourth independent pair ([evidence README](../../tools/r9_perf/evidence/README.md#L46)).
- Implementation fleet: 39/41 initial jobs passed. The two failures were generic wrapper `assert(nil)` errors; retained corrected invocations passed the real R6 balance and hotfix assertions.
- Independent fleet: 80/81 initial jobs passed. The retained corrected absolute `/usr/bin/luajit` R7 invocation passed.
- Static gates and both 60-second headless boots passed on ports 32601 and 32622.
- The failed `ca6035b8` final pair is correctly preserved and shows the accidental LuaJIT-FFI path.
- The replacement final pair completed during this review. PUC 5.1 and LuaJIT produced byte-identical 61,236-byte outputs with SHA-256 `6a7bc3e4f266b3969f6e82578ceab9b6a0ed94cb552ff8fe42706274fde23fd4`; input and output manifests verify, and the runner reports PASS. This satisfies the frozen-final-byte rule in [luanti-lua.md](../../docs/research/luanti-lua.md#L366).

## Material limits

The performance evidence is seed 0, one emerge thread, one machine, six sequential fresh-start runs and three single pairs. It provides no confidence interval, steady-state exploration estimate, 100-player result, or separation from temporal drift. The endpoint is descriptive only.

This review inspected immutable evidence and source without running Lua, Luanti, engines, or suites. The real fallback-engine and user GUI runtime gates remain separate. The stale R7 source audit was excluded as directed; roster authority remains 157 under ruling 43.

## Suggestions

None.

Original review SHA256: `4599c629c186359de294fe2a5fc56eebed8f9df7396c7986129d3aab8ecbcebf`. Local worktree links normalized for this archived copy.
