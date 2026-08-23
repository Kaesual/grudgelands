# WP40 T2 Phase-0B Pinned PUC Conformance Core evidence

This directory is the retained execution/calibration evidence for the first
accepted PUC-1 PCC capture on the integrated ownership provider. Canonical
result bytes live in `tools/wp40/fixtures/t2_puc_core/`; this directory keeps
the non-canonical runtimes and raw telemetry needed to audit how those bytes
were obtained.

The provider was commit `62afc64e598129e6e069d26a7746073a96673ccd`
(tree `6366c5e1457886d7c32f53e08f6c10e9669d9b86`). The implementation was
performed by GPT-5.6 Sol. Independent review is pending Claude Opus/xhigh and
must be appended to the contracts closeout; no pending-review field is a claim
of approval.

Measured Phase-0B legs:

- compiler pair: 69 s LuaJIT + 1,734 s PUC = 1,803 s, exact stdout;
- worker pair: 132 s LuaJIT + 2,325 s PUC = 2,457 s, exact canonical stdout
  and complete record bytes, with raw runtime telemetry separated below;
- seven-seed merge carrier: 335 s LuaJIT worker/dual-merge wall, with
  `pairs()` probe, synthetic invariance and measured invariance all passed;
- optional-load/locales: approximately 5.8 s, byte-identical across both
  interpreters and both available locales; and
- complete Source harness under LuaJIT plus the targeted Source PUC parity
  KAT: approximately 88 s in the final successful invocation.

`worker-pair-*-stderr-v1.log` are intentionally different raw telemetry.
The gate validates exactly two anchored seed/index lines and no others, removes
only the terminal ` wall=<integer>s cpu=<decimal>s` suffix, and requires the
normalized bytes to agree. Canonical stdout is never normalized. The complete
worker record is independently protected by exact byte identity, external
SHA-256 and its own trailing internal digest.

F1, F2, full-`W`, C1 reacceptance and any population under PUC were not run by
Phase 0B. F1 and the already-completed C1-v3 F2 remain the two separately named
final rounds. F2's measured closeout was 20 PUC rescores in 215 s, four
parallel selected slots in 5,507 s, and approximately 99 minutes end to end;
it already supplies candidate endpoints 0/4095 and slots 28--31 as the
selector full-path carrier. The future full-`W` population remains LuaJIT-only
with its dual-runtime merge parity gate.

The wall interval from the first retained Phase-0B capture to the final worker
capture was approximately 6 h 43 min. It includes two heavy-run authority
pauses and is not a model-throughput benchmark.
