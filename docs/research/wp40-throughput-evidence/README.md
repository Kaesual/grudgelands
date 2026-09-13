# Output-preserving throughput investigation

This checkpoint was not merged or synced. See [the report](../wp40-mapgen-throughput.md).
The joint-decision resource-sampling prototype lives on the separate
`wp40-resource-sampling-prototype` branch/worktree and supersedes this direction.

Raw baseline, cache, early-exit-only and conditional-cache engine results are
retained. `comparison.tsv` uses the three matching-harness baseline results
and final-1/2/3; earlier runs differ only in an unused diagnostic stage-patch
hash. `rss.tsv` measures the Flatpak launcher, not the actual game; only
`engine-rss.tsv` samples the headless engine. The final compact interpreter
pair belongs to this output-preserving checkpoint, not the later sampler.
The hash probe runs are exploratory and have no final PUC acceptance pair.
