# Reviewed Round 10 capital overlay expectations

All 18 rows bind the actual six-capital engine readbacks from production source
`8dd1c8e463a13ccc356cdade123875471b398707`, seed `531802985935182545`.
Seven SHA/count pairs changed; eleven are unchanged. The exact historical
expectations remain untouched in `../20260915-capital-terrain/`.

The [coordinate attribution](../../../r10_capital_phase/ATTRIBUTION.md) accounts
for every changed coordinate: accepted inner-capital changes or earlier terrain
changes. No unexplained changes remain. This is not an R7 source-audit refreeze.

The original v3 capital wrapper exits remain 1 because they compared against
the historical oracle; all six actual engine runs completed with zero errors,
and their service, precinct and Alchemy witnesses passed. The retained-readback
validation here compares those unchanged receipts against this reviewed current
oracle: 18/18 match. No engine rerun is claimed for this metadata-only update.
