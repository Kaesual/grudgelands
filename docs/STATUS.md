# Project status

Updated 2026-09-24. This is the delivery pointer, not another game specification.

- **Active Round 20:** [Round 20 POIs, quests and playtest fixes](planning/round20-pois-quests-fixes.md)
  is approved and in progress. [Execution state](planning/round20-state.md)
  tracks parallel lanes, ownership, reviews and remaining gates. Housing and
  geographic PvP are excluded; input and crosshair-only healing are included.
- **Documentation consolidation:** complete with independent Astra PASS;
  [receipt and coverage](maintenance/documentation-round.md). Remaining decisions
  and code/design discrepancies: [findings](maintenance/findings.md).
- **Latest game:** Round 19 plus UI and pursuit/idle-recovery follow-ups, merged
  to local main and synchronized before this documentation branch began.
  [R19 receipt](research/round19-completion.md),
  [UI follow-up](research/round19-ui-followup.md),
  [combat follow-up](research/round19-pursuit-followup.md).
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
  [R19 checklist](research/round19-playtest.md) plus the follow-up checklists above.
- **Remote observation:** the local `origin/main` tracking ref is `d6937b31`,
  already containing the game baseline and R19 follow-ups. Earlier R18/R19
  receipts' “remote pending” statements are historical, not current proof of
  missing delivery. No network fetch/push was performed in this round. The new
  documentation commits are local; no remote delivery is claimed for them.
- **Release:** unreleased fresh-server development. The Nether is expansion
  content. [First-public-release gates](../BACKLOG.md#first-public-release-gates)
  remain open.

Older deliveries: [R18](research/round18-completion.md),
[R17](research/round17-completion.md), [R16](research/round16-completion.md),
[R15](research/round15-completion.md), [R14](research/round14-completion.md),
[R13](research/round13-completion.md), [R12](research/round12-completion.md),
[R11](research/round11-completion.md). Read these for evidence or provenance,
not to reconstruct the current rules from successive overrides.
