# Resource sampling prototype evidence

The [prototype report](../wp40-resource-sampling-prototype.md) states the scope,
results, limitations and pending adoption decision.

`performance/` contains three baseline and three sampler runs. The baseline
runs correspond to the earlier scratch names `baseline-3`, `baseline-memory`
and `baseline-4`; all use the same repaired measurement harness as the sampler.
`performance-comparison/` records independently checked callback medians and
whole-run aggregates. Recompute using:

```sh
python scripts/compare_performance.py /tmp/NEW_COMPARISON .
```

`audit/` is a separate correctness/distribution corpus. Suffixes 0–2 use the ten
depth cases under seeds 0, 4074524248646631899 and 4655649881628627392; suffix 3
uses ten human/dwarf cases under seed 0; suffix 4 uses the original surface
workload under seed 0. Three independent seed processes ran concurrently at
idle priority with separate worlds, ports and outputs. These instrumented
parallel runs are excluded from timing comparisons.

`audit-comparison/` binds 54,131 fieldwise rows and resource/tier aggregates.
The comparison requires equal eligible counts, budgets and planned veins;
exact actual VM ore counts; identical non-ore content, param2 and light; and
successful full cold/disk persistence checks. Recompute using:

```sh
python scripts/compare_audit.py audit /tmp/NEW_AUDIT_COMPARISON
```

To reconstruct measured games, archive `mods`, `game.conf` and `minetest.conf`
from `a87b58c` into disposable directories. Apply the matching patch under
`variants/` with `patch -p1`. `sampler.patch` is the final production prototype;
`earlier-comment.patch` reproduces only the earlier proof-comment bytes used by
sampler performance runs 1–2. Audit variants include resource-row logging.
No game definitions or resource distributions differ because of that comment.
Compare reconstructed snapshots against their SHA manifests.

`measurement-harness.tar` contains the exact ordinary profiling harness.
`audit-harness.tar` adds post-timing ore counts and ore-normalized full content
hashes. The preparation/wave scripts preserve the original `/tmp` execution
paths as a record; adapt those paths into fresh disposable directories for a
rerun, retain the explicit seeds/cases and never reuse a measured world for a
new cold run. `flatpak.sh` grants the installed headless engine access to those
scratch paths; no GUI or Rehearsal host is involved.

`engine-rss.tsv` samples kernel VmHWM for the actual disposable `luanti.bin
--server` processes, filtered by their scratch-world path. Polling may miss a
short final process tail. `rss.tsv` in the baseline-memory result measures only
the Flatpak launcher and is explicitly unsuitable as engine-memory evidence.

The final compact PUC/LuaJIT pair, static checks and review receipt are retained
alongside the corpus. An earlier compact pair did not execute the changed
horizontal census branch; adding that concrete missing witness required a
replacement final pair. Statistical populations and expanded fixtures remain
LuaJIT-only. Evidence remains a prototype record, not adoption or release
approval.
