# Documentation consolidation round

Approved by the user on 2026-09-23. Baseline `d6937b31`; branch
`docs20-consolidation`. Documentation only; this is not a gameplay round.

## Contract

Make current decisions, implementation status, open work and historical evidence
distinguishable. Consolidate confirmed rules, remove redundant current prose,
archive superseded context and repair navigation. Code is implementation
evidence, never automatic design authority. A newer proposal is not automatically
an approved decision. Preserve approved but unimplemented scope and explicitly
report unresolved conflicts instead of silently choosing a design.

No game code, tests, media, reference pins or license evidence changes. Root
README is owned by another agent and remains untouched; provide a handoff for
needed updates. No game synchronization, runtime/PUC/PERF campaign or remote
push. Existing technical evidence is not re-certified. Markdown/link checks and
an independent Astra review are the gates for this round.

## Baseline

`docs/`: 1,387 files; 452 Markdown files; 106,098 Markdown lines. These are
filesystem counts before this round, excluding reference projects. A generated
inventory will distinguish structural classification from substantive review.
No assertion that every historical document has been read in full is permitted.

## Work ownership

| Lane | Model | Scope | State |
|---|---|---|---|
| Items | Sol | Crafting, professions, gear, food/farming, economy, equipment | integrated; e2295c59 + ba6138f2 |
| World | Astra | World/mapgen, populations, settlements, housing, boats/mounts, preparation | integrated; e1096c6c |
| Play | Sol | Combat/classes, progression, quests/groups, atlas/home, UI revision | integrated; bc87d184 + process 5fb2c4b9 |
| Navigation/process | Root Astra | Inventory, entry points, AGENTS, backlog/roadmap, archive routing | complete |
| Final review | Independent Astra | Rule preservation, authority, links, unresolved findings, scope | PASS at `1ab46e99`; initial 3 Medium/1 Low closed |

Authors own separate worktrees and non-overlapping files. Reports identify
inspected sources, corrected findings, unresolved findings and cross-lane edits.
No whole-file relocation until root integrates and checks incoming references.

## Sequence and acceptance

1. Record the inventory and classify by purpose/topic provisionally.
2. Read each living topic and trace relevant approved decisions and code.
3. Consolidate evidence-backed corrections; record unresolved design/code gaps.
4. Integrate lane changes, reconcile planning, remove duplicate rule authority,
   and label/archive historical material without breaking evidence paths.
5. Check changed Markdown links, inventory completeness, protected-file hashes,
   and independent rule-preservation review. Resolve findings and record limits.

The deliverable is a usable documentation entry point, a smaller mandatory
reading set, reconciled topic documents, an honest discrepancy list and a clear
maintenance rule. Historical evidence volume alone is not a deletion target.
Delete only content whose unique decisions, open requirements and provenance
have been accounted for. Ask the user only for actual unresolved decisions.

## Continuity

Latest user authorization is the Go for this documentation round. No approval
to alter game behavior is implied. Root README remains excluded even when a
standing completion rule would normally require editing it. Current game
delivery remains Round 19 plus its follow-ups; do not mark GUI checks passed.

Findings and README-owner handoff: [reconciliation findings](findings.md).
The inventory records baseline classification; topic reports record actual reading coverage.

## Completion

Documentation consolidation complete; independent Astra re-review PASS at
`1ab46e99` after one focused correction round. [Review and re-review](review.md).
No Critical/High findings; three Medium planning defects and one Low routing
issue were corrected. Authors: root Astra, world Astra, items/play/process Sol.
Review: fresh independent Astra. Classification: non-trivial documentation and
process authority; observed elapsed wall time: unknown.

Checks on the reviewed candidate and completion prose:

- Baseline inventory covers all **611/611 tracked Markdown files**; third-party,
  root README and provenance exclusions are explicit. Topic reports state actual
  reading limits; the whole historical corpus was not reread line by line.
- All changed Markdown local file targets and checked fragment targets resolve;
  `git diff --check` passes.
- All **10,270 existing protected files** retain baseline SHA256, including game
  code/runtime tools, media, root README, reference pins and license ledgers.
  Diff contains Markdown and the documentation inventory TSV only.
- No Lua, native world, GUI, performance, sync or remote push performed.
- AGENTS shrank from 1,181 to 383 lines; BACKLOG from 1,002 to approximately 265;
  ROADMAP from 443 to 194. Living design shrank from 14,848 to 13,850 lines.
  Historical archives, the technical guide and audit evidence remain accessible;
  total repository documentation size is not the success metric.

[D1–D4 findings](findings.md) remain explicitly routed: pending WP37 scope
reconciliation, profession-book code drift, specialist mastery audit coverage,
and future boat/Kraken danger acceptance. They are not hidden behind the review
PASS. No code fix, balance change, future-scope cancellation or GUI acceptance
was inferred. Root README-owner suggestions are recorded in the same findings.

Delivery: merged to local main as `aa06429e5ea448573a65b5fb74fce472bbea385d`.
The local `origin/main` ref at delivery is the pre-round baseline `d6937b31`;
no network operation was performed. STATUS corrects the inherited stale claim
that the earlier game baseline was still absent from the tracking ref.
This does not alter the installed game; no runtime test is needed for this
round. Existing user playtests and first-public-release obligations remain.
