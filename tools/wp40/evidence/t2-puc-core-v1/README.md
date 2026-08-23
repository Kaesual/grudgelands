# WP40 T2 Phase-0B Pinned PUC Conformance Core evidence

This directory is the retained execution/calibration evidence for the first
accepted PUC-1 PCC capture on the integrated ownership provider. Canonical
result bytes live in `tools/wp40/fixtures/t2_puc_core/`; this directory keeps
the non-canonical runtimes and raw telemetry needed to audit how those bytes
were obtained.

The provider was commit `62afc64e598129e6e069d26a7746073a96673ccd`
(tree `6366c5e1457886d7c32f53e08f6c10e9669d9b86`). The mechanical review-fix
implementation is commit `ee4478bc4210b0be75661152a9c1f240f53a36ce`
(tree `b91ba958bf7643c6a9c39eea3581a1b56aa7690d`). The implementation was
performed by GPT-5.6 Sol. Independent Claude Opus/xhigh review reported
0 Critical / 0 High / 2 Medium / 6 Low; one bounded mechanical fix round is
complete and focused re-review is pending. No pending-review field is a claim
of approval.

Measured Phase-0B legs:

- compiler pair: 69 s LuaJIT + 1,734 s PUC = 1,803 s, exact stdout;
- worker pair: 132 s LuaJIT + 2,325 s PUC = 2,457 s, exact canonical stdout
  and complete record bytes, with raw runtime telemetry separated below;
- seven-seed merge carrier: retained per-seed worker wall counters sum to
  346 s; the exact whole-leg wall was not retained and is strictly larger due
  to the following dual-runtime merge and final gate. The complete leg passed
  its 420 s cap, with the `pairs()` probe, synthetic invariance and measured
  invariance all green;
- optional-load/locales: approximately 5.8 s, byte-identical across both
  interpreters and both available locales; and
- complete Source harness under LuaJIT plus the targeted Source PUC parity
  KAT: approximately 88 s in the final successful invocation.

`worker-pair-*-stderr-v1.log` are intentionally different raw telemetry.
The gate validates exactly two anchored seed/index lines and no others, removes
only the terminal ` wall=<integer>s cpu=<decimal>s` suffix, and requires the
normalized bytes to agree. Canonical worker stdout is never normalized. The
complete worker record is independently protected by exact byte identity,
external SHA-256 and its own trailing internal digest.

The merge fixture normalizes only its exactly one leading host-specific
interpreter identity to `WP40 T2 census interpreter: <LuaJIT>`, after the
runner has proved that the configured LuaJIT is genuine and resolves to a
different executable from PUC. Every remaining merge byte and both fixture
trees are unchanged. Future successful captures also retain
`merge-runtime-v1.tsv`; the original capture predates that field, so no exact
whole-leg runtime is fabricated here. Optional-load output is now fixture-
pinned in both capture and verification modes.

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
