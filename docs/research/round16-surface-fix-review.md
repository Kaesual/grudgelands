# Focused independent review — Round 16 G-1

Verdict: **CLEAN**, subject to the coordinator's final integrated static,
portable-parity and native smoke gates. Reviewed `a4af5cfa` atop `b009e778`
in `/tmp/grug-r16-surface`, including the prior independent G-1 finding.
The reviewer authored neither the original G implementation nor this correction.

No new findings. The original missing terrain-source identity is corrected.

- The fixed 15-file roster binds the actual terrain/layout constructors and
  direct mathematics/schema inputs: source layout, horizontal map, height,
  coupled grade, zones, canonical/deterministic/index helpers and R5/R6
  authority assembly. It also binds the R7 integration, local envelope adapter,
  identity implementation and core selection implementation. Traced the live
  `r6.new_authority` → `r5.new_source_runtime` → zone/column source path; the
  omitted writer/planner execution modules do not construct this authority's
  queried columns.
- `r7_runtime.lua:366` passes the resulting source digest alongside the full
  seed and semantic source-projection digest into the real preparation adapter.
  The existing envelope/structure identity remains included. File names are
  hashed in fixed order with individual SHA256 values; absolute installation
  paths and runtime content IDs are absent. Self-hashing is a finite source-byte
  read, not recursive execution.
- `r7_loader.lua:36` constructs this main-thread authority once at load. Reads
  total 632,121 bytes across 15 files on this revision, followed by a small
  combined hash. There is no world-column scan, per-tile hashing or emerge
  callback cost.
- Secure `io.open(..., "rb")` is supported. The actual security wrapper checks
  only writing modes as writes (`s_security.cpp:1031`); canonical game/mod paths
  permit reads (`:853–874`). The fixed sibling core path resolves inside the
  shipped game/mod directories. Files are closed after reading; an unavailable
  file fails loudly with its roster name rather than allowing unsafe resume.
- Identical shipped bytes produce identical source identity on normal restart.
  A changed height/layout/selection byte changes that identity independently of
  runtime CIDs. `starts_preload.lua:72` compares authority before trusting a
  persisted selection or dispatching. The existing scheduler fixture explicitly
  rejects changed authority after persisted progress.

Executed one bounded LuaJIT identity fixture; result:

```
surface-identity:15-files:stable-restart:terrain-layout-selector-mismatch:ok
```

The fixture reads the actual production roster through its file double, checks
15 reads, repeat stability and changed height/layout/zones/selector/adapter bytes.
Its injective encoding proves byte participation without pretending to test
SHA256 itself. `git diff --check b009e778 a4af5cfa` passed. No production edits,
commit, PUC runtime, native generation, new world or timing campaign was performed.
Earlier native logs certify the original scheduling/restart observation only;
the corrected integrated seam still belongs in the coordinator's final gates.

Calibration: G-1 implementer root native Astra; independent review agent
`/root/r16_review_combat` (launch model recorded by coordinator); **0 Critical /
0 High / 0 Medium / 0 Low** new findings; original G-1 Medium resolved in one
fix round; elapsed wall time **unknown**.

User runtime check: stop and restart a fresh full-preparation world partway
through with unchanged game bytes; preparation must retain its chosen mode and
completed progress, then continue normally.
