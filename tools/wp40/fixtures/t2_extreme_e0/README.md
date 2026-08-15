# T2 E0 retained measurement artifacts

This directory receives range shards from `run_t2_extreme_shard.sh`, the
reviewed exact-cover manifest, and the canonical merged candidate artifact.
Every retained shard is pinned to an immutable infrastructure commit/tree,
the closed selector input manifest, the normalized vocabulary projection, and
the exact interpreter launcher/target/version/binary. The complete pool is
eight canonical LuaJIT 512-row shards and is labelled
`R7_SCALAR_MEASUREMENT_ONLY` with `stage2=pending_selected_four`. The
checked-in full-scan gate binds the stage-S1 authority digest and the S1
Source projection, and deliberately binds neither `source/catalog.lua`,
`geometry/partition.lua` nor the boundary-displacement policy checksum — a
gate still carrying those is rejected. That is what lets a geometry
correction land without invalidating a measured pool.

Two pool generations live in this directory. The eight
`shard-luajit-%04d-%04d.tsv`, `candidates-luajit.tsv`, `manifest-luajit.tsv`
and `conformance_gate.lua` are the frozen pre-v3 measurement from `53be77e`
and are content-pinned. The eight `shard-luajit-v3-*.tsv`,
`candidates-luajit-v3.tsv` and `manifest-luajit-v3.tsv` are the live v3
measurement. `shard-luajit-*.tsv` matches both sets — sixteen files — so
never glob on it. Once all retained shards exist, PUC Lua 5.1 must
separately parse and rank every row, rematerialize the deterministic shard
endpoints plus the four winners, and run the four selected full-partition
gates. Implementation bytes alone are not evidence: the C1 launcher may run
only from an independently reviewed immutable conformance commit, and no
`rescore-puc-*`, `selected-puc-*`, or `conformance-puc.tsv` file is evidence
until every closed gate records that commit. It does not claim a second
4096-row origin.

The former fixed-slot-19 fatal has a positive, pinned max-u64 R16/R17
prerequisite fixture. Slots 28--31 nevertheless remain unpromoted until the
pool has been measured and all four selected full-partition gates pass with no
fallback. Nothing here claims Stage 2, T2, a 32-seed corpus, runtime geometry,
or publication authority by itself.
