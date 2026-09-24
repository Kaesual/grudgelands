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
| G1 constructed-ground geometry | r21_settlement_preflight / Astra | /tmp/grug-r21-settlement | integrated; independent Astra review clean |
| G2 terrain/lakes/coast | r21_nature_preflight / Astra | /tmp/grug-r21-nature | integrated, root reviewed |
| F1/F2/F3/F5 feedback/names/ammo | r21_feedback_preflight / Sol | /tmp/grug-r21-feedback | integrated, root reviewed |
| F4 furnaces | r21_feedback_preflight / Sol | /tmp/grug-r21-feedback | reviewed; final personal-light scope closure running |
| G3 aquatic decor/fish | r21_feedback_preflight / Sol | /tmp/grug-r21-feedback | integrated; independent Astra review clean |
| R1 resources + docs | root Astra | primary integration checkout | implemented, independent Astra reviewed |

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

Evidence below is cumulative; earlier pending checkpoints are retained as
chronological records and superseded by the final integration checkpoint.

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

### Review/integration checkpoint

- G2 `35ff7360` integrated as `f4c01d7a`; independent root review clean.
- R1 `84592a9c`: independent Astra (nature agent) review clean; constructor gate pending.
- Feedback through `95beab13` and follow-ups `dbe7dbf5`, `6a4b243d`,
  `2e3f323d` integrated. Root reviewed sound cleanup, boar box, label chain,
  arrows, fuel and UI. Independent Astra F4 medium finding (brewing exact
  zero-elapsed refuel) fixed in `6a4b243d` and closed by reviewer.
- G1 `510596d6` independent Astra review clean; 0.166s six-descriptor inspection
  proved current junction writer coverage. Author is adding explicit preparation
  envelopes for collars/approaches and a real-owner assertion helper.
- G3 first candidate has waterweed/reef/fish; root requested surface lily using
  pinned minetest_game flowers media, corrected pre-offset fish spawn check,
  and moving reef-only hash work inside its eligible-water branch.
- `tools/round21/integration.lua` is prepared but NOT RUN: real constructor,
  actual planner/writer and <=4 chosen owners. Derived density pins are not
  independent construction proof; final integration remains mandatory.

### Final integration checkpoint (2026-09-24)

- G1 through `9854b3e4` / integrated `8e5ecd15`, G3 through `c7828ae5` /
  integrated `9f9c5299` independently reviewed clean by nature Astra.
- Real integration `tools/round21/integration.lua` PASS on final mapgen bytes:
  actual manifest constructor, preparation source, planner and writer; three
  selected 80-cubed owners; core landing, gate and real plot approach walkable;
  zero approach findings. Final run 19.46s wall / 19.39s CPU. Manifest
  `3575ddcb09da9209be3f9dd57abac20b3f589ba1d7452f35fbb92752033e560a`.
- Previous bounded attempts: fixture missing actual R20 scenery (5.88s wall,
  5.86s CPU); gate fixture demanded half-steps on ordinary exterior terrain
  (19.38s wall, 19.30s CPU); replay capture exposed a no-nearby-street entrance
  (20.31s wall, 20.25s CPU). That plot now connects to natural terrain within
  its eight-node collar. Three unique owners reused, nine owner emissions total
  across three full attempts; no other VM owners. Sparse replay avoids further
  constructor runs for inspection. All attempts stayed within the CPU budget.
- Including nature scalar runs and the earlier obsolete feedback fixture, the
  recorded larger mapgen checks total about **95 CPU seconds**. Small micro
  fixtures add less than a few seconds. No mapgen test remains scheduled.
- Initial compact final interpreter pair passed identically, digest
  `486402fe35b65c4a1e0d8fcdc59164fefd358077330ead8ccd07883d8a6ecd88`;
  PUC0.52s CPU / JIT0.24s CPU. Both actual small planner fixtures included.
- Scope audit found personal furnace world light still omitted. F4 §7 already
  authorizes a bounded cosmetic deadline. Sol is closing it using the existing
  node timer; no player-record scan/new scheduler. Independent source review,
  tiny fixture and one replacement portable pair required afterward. **Do not
  rerun mapgen for this UI/world-light-only change.**
- Root corrected remaining stale implementation-pending wording and added fish
  to the living critter table after independent Sol documentation review.
- Remaining: personal light closure, replacement final static/portable gates,
  frozen source hashes and final receipt review, local commit/merge/sync. No push.
