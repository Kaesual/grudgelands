# WARCOAST C1-v3 reacceptance evidence

This directory describes the C1-v3 result set launched from commit
`86e5071de0fd449c2a1c88587f4d7614b2a2ccc8`, tree
`07e5d99c96edd3f66c454feefa606b072c78d33e`, after the reviewed
WARCOAST-SOURCE-1 correction. Result-fixture commit
`17efc8d822b401d6a32505c75c3c83bfc2ee7fd8` binds the 25 acceptance-critical
files.

Those bytes live in `tools/wp40/fixtures/t2_extreme_e0/`: 20 PUC rescore
rows, four selected rows and the self-manifesting final artifact.
`artifact-manifest.tsv` independently lists their byte counts and SHA-256
values.

The original combined runner stdout, same-HEAD resume stdout and descendant-
HEAD reuse stdout were not retained. Therefore this directory deliberately
contains no reconstructed `run.log` or `resume.log`. The coordinator observed
runner counters of 235 seconds for the rescore phase and 5,447 seconds for the
four parallel selected workers, but these counters are not immutable timing
evidence and the complete end-to-end elapsed time was not retained.
`run-metadata.tsv` separates those observations from the authoritative result
bytes.

The same-HEAD resume path reverified all 24 rows without recomputation. From
the result-fixture commit, the recorded-evidence path then rejected current-
HEAD launch-pin identity as expected, validated the complete 66-path closure,
re-ran the finalizer against all 24 recorded rows and exited 0 without
generation. A separate coordinator-managed read-only audit independently
recomputed both DAGs and every row/final-artifact hash and returned `APPROVE`
with no finding. The workflow-required fresh Opus/xhigh acceptance review is
pending; it will be recorded in T2 contracts Section 14.12.
