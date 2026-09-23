# Full-world preparation CPU diagnosis

Authorized by the user on 2026-09-23. Coordinator: native Astra; investigator:
native Astra (`pregen_cpu_diagnosis`). This is a measurement task, not permission
to change production generation behavior. Starting checkout: `4d7903e8`.

## Question and scope

The production server reportedly uses approximately 100% CPU for its first few
minutes, then falls to 5–20% during full-world preparation. Establish whether a
local fresh-world run reproduces that transition and separate CPU computation,
surface-selection pacing, emerge completion waits and storage work. CPU units
on production, server hardware, storage and exact engine version remain unknown.

- Use an immutable copied game and disposable world, loopback-only server,
  full preparation enabled, no players, unchanged generation/engine settings.
- Measure one native LuaJIT-backed Luanti run for at most 30 minutes. Early stop
  is appropriate once the transition repeats and the evidence explains it.
- Sample process/thread CPU, memory, IO and progress every five seconds; produce
  minute summaries. Distinguish one-core CPU percentages from machine totals.
- Add bounded observational instrumentation only in the copied snapshot for
  actual server-step cadence, surface selection, request/callback timing,
  completion actions, persistence and the next-dispatch gap.
- Preserve generation order, scan budgets, single pending request, settings,
  shutdown/resume contracts and generated output. Record instrumentation limits.
- Record engine version, system facts, effective settings, source hashes, all
  artifact locations and graceful shutdown outcome. Use disk-backed disposable
  storage: this workstation's `/tmp` is tmpfs and would hide normal disk costs.
- No production fixes, engine builds, personal-world writes, installed-game sync,
  broad performance campaigns or repeated long runs. Any follow-up experiment
  needs a specific evidence-based purpose and is proposed separately.

## Work split and evidence

The investigator owns the isolated sampler/probe and
`docs/research/pregen-cpu-diagnosis.md`. Root owns this plan, parallel read-only
engine/scheduler inspection and synthesis. An independent reviewer checks the
final instrumentation and evidence without repeating the measurement run.

Lua instrumentation receives the plain-5.1 parser, SETGLOBAL and five static
sweeps. The actual long run uses the native engine with LuaJIT, never a standalone
PUC population. No changed production Lua means no production conformance suite
or game deployment is needed for this diagnosis.

Deliver a measured timeline, supported findings versus remaining hypotheses,
and the smallest justified next action. If the local symptom does not reproduce,
provide a bounded production comparison procedure instead of asserting a cause.

## Starting evidence, not conclusions

`starts_preload.lua` allows 4 ms of cooperative surface scanning per server step
and a 20 ms minimum work interval. The engine's default dedicated step is 90 ms.
One emerge request remains outstanding at a time. The Round 18 short native
probe observed roughly 16 seconds to terminal callbacks, but did not separate
native work, storage and waits; it is not proof of a bottleneck.

## Status

The single native run finished cleanly after approximately 410 seconds,
with 561 of 8,811 horizontal tiles complete. Repeated low-load intervals and
scan-gated dispatch gaps justified the authorized early stop. The initial
Flatpak-wrapper CPU samples were rejected; the corrected exact-engine series
starts 43 seconds after launch without restarting generation.

Report: [pregen-cpu-diagnosis.md](pregen-cpu-diagnosis.md). Durable evidence:
`tools/r19_preparation_diagnosis/evidence/`. Independent Sol evidence review
[passed](pregen-cpu-diagnosis-review.md), with no open findings. No production changes authorized or made; there is no game sync
or new in-game acceptance requirement for this observation-only task.
