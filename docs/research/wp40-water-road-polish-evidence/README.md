# Water and road polish evidence

See [the report](../wp40-water-road-polish.md) for scope, causes and limits.

- `production.patch`: final production changes relative to `76576e3`.
- `engine-before.tar.gz`: actual engine negative control, flowing water at a required stone witness.
- `engine-after.tar.gz`: corrected engine run before the bounded cache.
- `engine-final-cached.tar.gz`: final engine run with the cache, ten generated owners and disk reload.
- `shore-before.*`: 226 low wet/dry contacts in the reported basin.
- `shore-after-*.{tsv,log}`: corrected uncached scans, both seeds have zero contacts.
- `shore-final-cached-*.{tsv,log}`: final cached scans, both seeds have zero contacts.
- `road-before.tsv`, `road-only-after.tsv`: isolated road comparison, without the water fix.
- `road-only-source.tar.gz`, `road-only-source.sha256`: reconstructed isolated source and exact input hashes.
- `road-only-repeat.tsv`, `road-only-canonical.tsv`, `road-reconstruction.tsv`: repeat verification of all 146 geometric rows, excluding timings.
- `banner-negative.log`: original node fails the new opacity regression.
- `static.log`, `fresh-server.log`, `submodules.txt`: parser, globals, five sweeps, fresh-server and reference checks.
- `final-micro.tar.gz`: final cached input binding, constructor check, interpreter hashes and matching 264-row PUC/LuaJIT outputs. Earlier final bytes were superseded by the cache and are not the accepted final parity evidence.
- `performance-*.tar.gz`, `performance.tsv`: four single-run controls; the first after-run overlapped compact quality checks. No precise performance percentage is claimed.
- `cache-parity.tsv`, `cache-parity-user.tsv`: unchanged full engine output across the cache addition, for seed 0 and the reported seed respectively.

Archives preserve original temporary path names in logs and hash manifests.
Validate archived inputs against the corresponding source snapshot; the final
micro input paths are repository-relative. `SHA256SUMS` binds the evidence files
except itself. Independent review is recorded in `review.md`.
