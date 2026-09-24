# Round 21 execution state

Updated 2026-09-24. **ACTIVE: user Go received.** Root GPT-6 Astra orchestrates.
Integration branch `wp21-round21`, baseline `b5cf84d0`.
Plans: [round scope](round21-mapgen-and-playtest-fixes.md),
[mining/furnaces/ammunition](round21-mining-furnaces.md).

## Approved decisions

- Full proposed T1–T6 matrix with final Gold `—/512/256/128/256/256`.
  Preserve first appearances, vein caps and deep multipliers. No sampler rebase.
- Keep starter coal quests; fix inaccurate bronze-only advice.
- Normal metal smelts 10s; charcoal from one log in 10s. Fuel log15/coal80/
  charcoal80. Only those fuels in normal/dual furnaces. Work-triggered ignition,
  current piece burns to completion, no dark tick on continued refueling.
  Existing alloy durations unchanged. Do not change brewing fuel semantics.
- Bronze Bar + two diagonal Sticks -> 200 existing basic arrows, no feathers,
  no other metal, no damage tiers or arrowhead intermediates. Stack/start 200.
- Food sound during hold; bounded HUD motion. Separate boar selection box.
  Propagate authored POI labels. Preserve the accepted Round20 input contract.
- Shared complete junctions/landings and bounded plot entrance fitting;
  natural POI ground. Terrain, water/coast and aquatic details within the plan's
  approved visual discretion; no new erosion/route architecture.
- One bounded ambient fish family, no XP/drop; choose and record the licensed
  animated candidate before implementation. Escalate unexpected complexity.
- Fresh-world development, no migrations. Local merge/sync; no remote push.

## Workers and ownership

| Lane | Agent/model | Worktree | Status |
|---|---|---|---|
| G1 constructed-ground geometry | r21_settlement_preflight / Astra | /tmp/grug-r21-settlement | running |
| G2 terrain/lakes/coast | r21_nature_preflight / Astra | /tmp/grug-r21-nature | running |
| F1/F2/F3/F5 feedback/names/ammo | r21_feedback_preflight / Sol | /tmp/grug-r21-feedback | running |
| F4 furnaces | Sol slot after feedback | TBD | queued |
| G3 aquatic decor/fish | Sol slot after interface freeze | TBD | queued |
| R1 resources + docs | root Astra | primary integration checkout | running |

G1 owns wp13 street/avenue/landing/plot helpers, wp40 r7_settlement and planner
grading consumer. G2 owns height.lua and simple_map geometry, shore material
logic; send producer seam changes between owners, never concurrent same-file
edits. Root R1 owns resource-row hunks in r7_r6_manifest/r6_content; G2 sends
its separate r6_content shore hunk for clean integration. Feedback owns input
presentation, boar selection, runtime/loader/socket labels, atlas labels and
basic-arrow recipe/routes. G3 world_content/catalog later; G2 freezes water
query semantics first. Independent non-author reviews precede merge.

## Test budget and recording

Latest user instruction: **minimum necessary CPU, at most six CPU workers**.
No planning tests executed. No full-world pregen, census, seed fleet, full
capital roster VM or historical monolithic suites. Do not execute an old runner
before checking what it initializes/runs. No intermediate PUC runtime.

Initial estimate/budget: mapgen checks should take minutes, aiming at **4–10
CPU-core minutes total and roughly 2–5 elapsed minutes** when independent small
checks run in parallel. This is a planning estimate, not measured speed or the
implementation/review duration. Six workers are a ceiling, not a target.

- At most eight chosen 80³ owners total initially (G1 four, G2 four), shared
  across concerns. Prefer small real consumer/column fixtures whenever possible.
- Before heavy execution, report exact command, input count and time estimate
  to root. Timeout120s per heavy command; log wall/user/sys. No silent reruns.
- Small development JIT fixtures target seconds. One final portable PUC/JIT
  pair on frozen bytes, plus parser/SETGLOBAL/five sweeps. Root owns final pair.
- Reviewers inspect existing evidence instead of rerunning. Replacements only
  for changed bytes or a concrete failure. Escalate if the initial cumulative
  CPU budget cannot establish essential correctness; user GUI is visual gate.
- Preserve real r7_manifest.new/planner.plan_slice/writer seams when changed.

### Evidence ledger

No Round21 test commands run yet. Record commands, inputs, times, hashes and
findings here as work proceeds.

## Completion obligations

Finish all authorized lanes unless a specific complexity blocker is escalated.
Review independently, fix verified findings, merge no-squash to main, sync from
main, update BACKLOG/ROADMAP/README/status and completion/playtest receipt.
No user permission re-request for this authorized local round. Do not treat a
progress update or compaction as completion.

### First implementation checkpoint

- Feedback commits `af72c406`, `39d3b59b`, `7b3bb090`, `4e905186` are ready
  for independent root review. F4 now running in the same Sol worktree.
  Root requested stoppable food sound and native-wield visibility restoration.
- G2 bounded scalar runs: 8.87s +9.15s wall, 8.84s +9.12s user; zero VM owners.
  First fixture assumption rejected a dry rapid sample, corrected once. Water
  tuples unchanged. Natural lake-edge changes cover Frostbarrow/Moonfall;
  functional/civic connected reaches retain their shore footprints.
- G1 two tiny geometry/seam fixtures: each <=0.01 CPU s, zero VM owners.
  Plot approaches must slope toward authoritative shared street height, not
  force street junctions to match plot heights.
- R1 actual content validator + quota fixture passes (0.01s). Derived density
  pins update only catalog/WP43 limbs; real `r7_manifest.new` integration still
  REQUIRED after all mapgen branches merge. Do not mistake derived pins for
  an executed constructor gate.
- Feedback existing R7 micro attempt cost11.7 CPU s and failed in stale factory
  setup before changed code; do not repeat. Targeted input/socket/atlas JIT
  fixtures passed. No PUC runtime or engine test yet.
