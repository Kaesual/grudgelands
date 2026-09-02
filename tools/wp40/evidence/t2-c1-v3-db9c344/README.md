# Integrated Wave-1 C1-v3 evidence

This directory describes the current C1-v3 result set launched from commit
`db9c344499e7f76418e4f11e822e7492e777161b` and bound by evidence commit
`89e4ba17a1c5d0334cc85543e3f0a03b1541dc49`.

The acceptance-critical bytes live in
`tools/wp40/fixtures/t2_extreme_e0/`: 20 PUC rescore rows, four selected rows
and the self-manifesting final artifact. `artifact-manifest.tsv` independently
lists the byte count and SHA-256 of those exact committed files.

The original combined runner stdout, same-HEAD resume stdout and preflight
stdout were not retained. Therefore this directory deliberately contains no
reconstructed `run.log` or `resume.log`, and no elapsed counter is a calibrated
cost record. `run-metadata.tsv` distinguishes coordinator-observed exit status
from immutable byte evidence instead of presenting an authored summary as
verbatim output.

The descendant-HEAD recorded-evidence path is reproducible without generation:
it validates the 66-path closure and re-runs the finalizer against all 24 rows.
The independent acceptance review exercised that driver directly under the
vendored PUC interpreter. T2 contracts Section 14.10 records the result and
the remaining non-claims.
