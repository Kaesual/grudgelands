# Independent review: full-world preparation CPU diagnosis

Date: 2026-09-23. Reviewer: native GPT-5.6 Sol, independent of the Astra
investigator and coordinator. Scope: measurement correctness, observational
instrumentation, process identity, phase attribution, isolation and shutdown.
No runtime was repeated and no production code was changed for this review.

## Verdict

**PASS.** No open Critical, High, Medium or Low finding remains. The retained
evidence supports the report's bounded local conclusion: after startup, the
single emerge worker's CPU use falls mainly because cooperative surface
selection increasingly separates otherwise short emerge requests. It does not
prove which surface-authority subroutine changes cost, a monotonic whole-world
trend, or a production-server speedup.

## Findings and resolution

1. **High, resolved during measurement — the original sampler selected the
   Flatpak `bwrap` wrapper instead of `luanti.bin`.** Its zero-CPU `os.jsonl`
   and `minutes.jsonl` would have invalidated process and thread conclusions.
   The investigator attached a corrected sidecar to verified engine PID 675697
   without restarting the world. The report explicitly excludes the wrapper
   series and retains only `engine-os.jsonl` and `engine-minutes.jsonl` as CPU
   evidence. The first 43 seconds consequently have cumulative CPU ticks but no
   reconstructed five-second timeline.
2. **Low, resolved in final report — direct thread attribution was absent from
   the narrative.** Independent replay found Emerge-0 means of 56.75%, 35.32%,
   26.00%, 21.70%, 24.32% and 25.57% of one core across corrected windows,
   while Server remained between 3.09% and 3.98%. The final report now records
   the relevant values and limits the causal wording accordingly.

The initial sampler defect is counted as the one substantive review finding;
it was discovered before analysis, corrected without another engine run, and
is preserved transparently in the durable report. No sidecar discontinuity was
present in the host samples.

## Verification

- The copied-game hash manifest contains 2,078 files. Comparison with production
  revision `4d7903e891497041b6fb9833a599b3acb87d2d18` found exactly one changed
  file, the documented snapshot-only `starts_preload.lua` instrumentation.
  Its diff preserves traversal, scan constants, one-request scheduling and
  callback state transitions; added work is timing, counters and logging only.
- The corrected sampler's `/proc` arithmetic uses process/thread CPU-tick deltas
  over wall time. `engine-identity.json` binds PID, executable, command line,
  start time, SHA-256 and the 16-CPU affinity mask. One-core and whole-machine
  percentages therefore use explicit, consistent denominators.
- Independent replay of retained `analyze.py` reproduced `phase-summary.txt`
  byte for byte. The 16-entry `SHA256SUMS.json` manifest verifies. Source-hash,
  CPU-window, request/gap, callback-action, scan-envelope, persistence and I/O
  claims were checked against the retained raw records.
- Phase attribution remains appropriately bounded. Scan timing is wall time,
  action counters are cumulative and persistence timing excludes eventual
  database flush. Uniform sampled 88 by 88 envelopes rule out radius growth in
  this prefix, but do not distinguish column-call computation from cache, JIT
  or scheduling effects.
- The one real engine run lasted 410 seconds and ended with exit code 0 after
  SIGINT to the verified engine identity. The shutdown callback recorded
  561/8,811 completed tiles with no preparation failure. The final host check
  found no diagnostic process and confirmed the pre-existing personal GUI
  process remained alive.

The proposed next action, a separately authorized bounded scan-budget change
and validation, follows from the measured pacing gap. This review does not
authorize or validate that production change.
