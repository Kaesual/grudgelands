# Planner-throughput evidence

See [the report](../wp40-planner-throughput.md) for scope and interpretation.

- `baseline-1..3.tar.gz`, `optimized-1..3.tar.gz`: six alternating serial primary
  engine runs, including output digests, per-callback timings, source manifests,
  engine identity, configuration and logs. Extract all into one parent and run
  `tools/wp40/planner_throughput/compare.py PARENT ABSENT_OUTPUT` from the reviewed
  checkout. `aggregate.tsv` and `owners.tsv` are its checked output.
- `timing-harness.tar.gz`: exact measurement harness bytes. The optional stage
  patch changed after measurement; that old patch is retained in this archive.
  The primary runs did not enable stage instrumentation.
- `diagnostic-*.tar.gz`: coarse and detailed pre-change stage diagnostics,
  excluded from primary performance claims.
- `terrain-baseline.tar.gz`, `terrain-optimized.tar.gz`: additional ten-owner
  full-byte and persistence parity. `terrain-parity-cases.lua` gives the input
  owner selection; `terrain-parity.tsv` records the comparison.
- `historical-witness-baseline-failure.tar.gz`: the existing fixed cave witness
  fails on unchanged baseline. This is not an optimization regression, and this
  package does not certify that historical tube-shape assertion.
- `final-micro.tar.gz`: one final compact PUC/LuaJIT pair, actual manifest
  constructor, complete input binding, post-run checks and equal output hashes.
- `compact-luajit.tsv`, `r5-baseline.log`, `r6-baseline.log`: compact production
  planner regression outputs and separate baseline query counts.
- `static.log`, `fresh-server.log`, `submodules.txt`: parser, SETGLOBAL, all five
  textual sweeps, fresh-server audit and unchanged reference pins. Sweep hits
  are existing prose/string literals, not incompatible executable syntax.
- `comparison-negative.log`: six baseline copies are rejected by the comparator.
- `review.md`: independent review receipt and resolved evidence findings.

The whole-quality input manifest covers runtime sources and current tools;
report/evidence files are written afterward and do not change those bytes.
Archives contain test-world settings and logs, not a user's world database.
