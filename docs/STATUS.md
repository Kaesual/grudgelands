# Project status

Updated 2026-09-24. This is the delivery pointer, not another game specification.

- **Round 21 startup correction:** fixed the missing fish disposition and native
  arrow recipe catalog binding; real isolated server startup and 200-arrow craft
  passed. Merged as `f00433c7` and synchronized.
  [Receipt](research/round21-startup-fix.md). No remote push.
- **Round 21 delivered locally:** terrain/POI access, resource calibration,
  furnaces, aquatic detail and feedback fixes. Independently reviewed, final
  gates passed, merged as `96c40fa3` and synchronized to Luanti on 2026-09-24.
  [Receipt](research/round21-completion.md), [playtest](research/round21-playtest.md),
  [execution state](planning/round21-state.md). No remote push.
- **Round 20 delivered locally:** 240 quests, all 100 anchor art slots, contextual
  input and equipment/UX fixes. Independently reviewed, final gates passed,
  merged as `8308229f` and synchronized to Luanti on 2026-09-24. No push.
  [Completion receipt](research/round20-completion.md),
  [playtest checklist](research/round20-playtest.md),
  schematic POI gallery (`tools/r20/evidence/pois/`, retired in Round 22;
  git history keeps it).
- **Documentation consolidation:** complete with independent Astra PASS;
  [receipt and coverage](maintenance/documentation-round.md). Remaining decisions
  and code/design discrepancies: [findings](maintenance/findings.md).
- **Latest game:** Round 21 includes Round 20 and earlier Round 19 UI, pursuit/idle-recovery
  and full-speed preparation follow-ups. GUI acceptance of the new round is
  pending; fresh-world development remains in force.
- **Technical reviews/gates:** recorded PASS for those delivered candidates;
  not a fresh certification of arbitrary later changes.
- **Preparation performance follow-up:** the bounded two-request pipeline
  completed the same measured prefix in a further 24% less time than the prior
  40 ms scheduler. Its native emerge worker reached 99.43% of one core over the
  matched steady interval. Completed preparation remains inactive during later
  on-demand cave generation; engine tick/thread settings are unchanged.
  Independent review, native comparison, two-pending stop/resume and final
  interpreter parity passed. Merged to local main and synchronized. Receipt:
  [full-speed follow-up](research/pregen-fullspeed.md). No remote deployment
  claimed. Prior measurement: [scan-budget follow-up](research/pregen-scan-budget.md).
- **GUI acceptance:** user-run and pending where not explicitly accepted.
  [R21 checklist](research/round21-playtest.md) covers the new changes; the
  R20 input limits remain documented in its earlier checklist.
- **Remote observation:** local `origin/main` remains `e346ec48`. No network
  fetch/push occurred in this round; the Round 20 and Round 21 commits are local.
- **Release:** unreleased fresh-server development. The Nether is expansion
  content. [First-public-release gates](../BACKLOG.md#first-public-release-gates)
  remain open.

Older deliveries: [R18](research/round18-completion.md),
[R17](research/round17-completion.md), [R16](research/round16-completion.md),
[R15](research/round15-completion.md), [R14](research/round14-completion.md),
[R13](research/round13-completion.md), [R12](research/round12-completion.md),
[R11](research/round11-completion.md). Read these for evidence or provenance,
not to reconstruct the current rules from successive overrides.
