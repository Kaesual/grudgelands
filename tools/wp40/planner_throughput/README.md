# Planner throughput checks

This package checks the output-preserving R5 wet-neighbor cache and R6 wet-halo
reuse. It follows the adopted resource sampler; it does not change ore layout.

Run the bounded actual-planner fixtures with `bash tools/wp40/planner_throughput/run.sh`.
`WP40_LUA_BIN` defaults to LuaJIT. An optional repository argument selects the
production planner bytes for a baseline comparison. The fixtures freeze output
and check query bounds, dry/wet reuse, waterfall precedence, invalid depths,
authored-map edges, failure recovery and the maximum owner/halo size. Their
small synthetic sources avoid constructing complete worlds. Both fixtures are
also part of `tools/wp40/quality/final_micro.lua`; use the standard final runner
for the single frozen PUC/LuaJIT parity pair, never an intermediate PUC suite.

For primary performance evidence, run the real-engine profile harness three
times per variant in alternating serial order, with stage diagnostics disabled
and `WP40_PROFILE_FULL_DIGEST=1`. Keep the same engine, seed and owner cases.
The parent directory must contain `baseline-1` through `baseline-3` and
`optimized-1` through `optimized-3`. Then run:

```sh
python3 tools/wp40/planner_throughput/compare.py INPUT_ROOT ABSENT_OUTPUT
```

The comparison binds the instrumented baseline snapshot to `4403f01`, requires
only the two reviewed production planners to differ, and binds their optimized
hashes to the current checkout. It also requires identical full node/param2/light digests, vocabulary,
samples, engine and harness identity, ten cold callbacks and zero callbacks
when 1,250 stored mapblocks reload. It emits per-owner and aggregate medians
and ranges. These are local measurements, not a complete R8 performance or
supply certification. Optional stage diagnostics perturb the JIT and are
attribution aids, not the primary timing population.

Current results and archived evidence:
[planner throughput report](../../../docs/research/wp40-planner-throughput.md).
