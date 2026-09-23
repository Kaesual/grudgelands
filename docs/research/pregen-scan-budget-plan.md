# Bounded full-preparation scan budget follow-up

User authorization: 2026-09-23, following the independently reviewed
[CPU diagnosis](pregen-cpu-diagnosis.md). Root Astra coordinates; native Astra
`pregen_cpu_diagnosis` implements and measures; independent native Sol
`pregen_measurement_review` checks behavior and evidence. Branch:
`fix/preparation-scan-budget`, starting at `87279c2e`.

## Contract

Test a larger bounded surface-selection budget to reduce idle gaps and approach
one-core utilization. Initial candidate: 40 ms instead of 4 ms, only in the
unfinished full-world preparation path. Preserve every sampled column, terrain
output, traversal order, source identity, successful-prefix persistence,
single outstanding emerge request and callback/shutdown rules. Retain the
16-column cooperative checks, 8,192-column ceiling, work/UI cadence, global
server-step setting and emerge-thread count.

The user's explicit safety requirement is that this preparation optimization
must not alter later on-demand generation when players explore ungenerated
deep caves. Check the actual separation between preparation selection and
ordinary native emergence, completed readiness across restart, starts-only
mode and character admission. No persistent global mapgen acceleration setting,
new queue fleet, terrain algorithm change or legacy-world migration.

## Work and test budget

- Astra owns the scheduler change, relevant portable fixture, isolated native
  measurement and `pregen-scan-budget.md` report. Sol owns independent review.
- Reuse the existing diagnosis as the baseline. Run one fresh candidate world
  on disk, identical seed/engine/settings, stopping after the same 561-tile
  prefix (seven-minute ceiling). Compare the same terrain prefix, CPU and
  throughput, not different locations reached after equal time.
- Bind process samples to verified engine executable, PID and start time from
  the beginning. Capture server-step latency, shutdown behavior and exact
  artifacts. Only the isolated snapshot receives observational logging.
- LuaJIT owns development checks and the native measurement. Plain-5.1 parser,
  SETGLOBAL and all five static sweeps cover changed Lua. Once bytes and review
  are final, root executes one bounded PUC-5.1 fixture and its LuaJIT counterpart,
  requiring identical canonical output. No broad mapgen or PUC campaign.
- Add meaningful regression coverage for a fully completed full-world plan:
  further steps and reload perform no surface scans or preparation dispatches;
  unrelated deep emergence remains unchanged. Existing coverage checks retries,
  cancellation, selected inner-Y resume, single request, stop and starts mode.

If the candidate improves throughput while keeping bounded responsiveness and
the runtime separation intact, deliver the reviewed minimal fix and local sync.
Otherwise report the limit rather than expanding into a new architecture.
Unexpected complexity or a need for broad retuning returns to the user.

## Status

Candidate complete: the same 561-tile prefix took 177.59 seconds from first
dispatch versus 386.06 seconds in the baseline (54.0% less elapsed time).
Matched post-startup tiles 101–561 averaged 82.05% of one CPU versus 32.70%.
The native server exited normally at the exact prefix. Independent code-safety
and native-evidence [review](pregen-scan-budget-review.md) passed with no open
findings, as did the final PUC/LuaJIT pair. Local delivery is recorded in the
[budget follow-up](pregen-scan-budget.md).
