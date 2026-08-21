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

Two pool generations live in this directory, and they never share a path.

The frozen **pre-v3** set is the measurement from `53be77e`: the eight
`shard-luajit-%04d-%04d.tsv`, `candidates-luajit.tsv`, `manifest-luajit.tsv`
and `conformance_gate.lua`, all content-pinned. The live **v3** set is the
measurement from `19fc28d1` (tree `bca04056`, Authority-DAG `069cce2d`): the
eight `shard-luajit-v3-*.tsv`, `candidates-luajit-v3.tsv`,
`manifest-luajit-v3.tsv` and `conformance_gate_v3.lua`.

Two globs match BOTH generations and must never be used: `shard-luajit-*.tsv`
(sixteen files) and `rescore-puc-*.tsv` (forty, once a v3 run has produced its
twenty). Always spell the generation out.

`conformance_gate_v3.lua` is the closed input gate of the v3 C1 conformance.
Like the pre-v3 gate it records the immutable LuaJIT measurement and its PUC
merge result and claims nothing about the selected four having passed. Unlike
it, it drops `source_checksum`, `boundary_policy_checksum` and
`partition_sha256` and carries `s1_authority_sha256` /
`s1_source_projection_sha256` instead, and it names the pool with
`pool_`-prefixed fields the pre-v3 gate does not have — so neither gate can
validate against the other's reader. The row bytes are identical across the two
generations (`candidate_rows_sha256` `b08e142a…` in both); only the provenance
header differs.

The C1 chain reads the v3 set. Its results are the v3 names
`rescore-puc-v3-%04d.tsv`, `selected-puc-v3-slot%02d.tsv` and
`conformance-puc-v3.tsv`; every path guard in the chain refuses a pre-v3 name
as a target and vice versa, so a v3 run cannot overwrite pre-v3 evidence. The
twenty pre-v3 `rescore-puc-%04d.tsv` are inert leftovers — nothing pins them,
no code reads them, and their header names the pre-v3 measurement commit, so
they can never be resume state again. Whether they are deleted is an open
question recorded in `tools/wp40/README.md`, not settled here.

PUC Lua 5.1 must separately parse and rank every row, rematerialize the
deterministic shard endpoints plus the four winners, and run the four selected
full-partition gates. Implementation bytes alone are not evidence: the C1
launcher may run only from an independently reviewed immutable conformance
commit, and no `rescore-puc-v3-*`, `selected-puc-v3-*` or
`conformance-puc-v3.tsv` file is evidence until every closed gate records that
commit. **No such file exists: the acceptance conformance has not been run.**
This directory does not claim a second 4096-row origin.

The former fixed-slot-19 fatal has a positive, pinned max-u64 R16/R17
prerequisite fixture. Slots 28--31 nevertheless remain unpromoted until the
pool has been measured and all four selected full-partition gates pass with no
fallback. Nothing here claims Stage 2, T2, a 32-seed corpus, runtime geometry,
or publication authority by itself.
