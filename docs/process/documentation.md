# Documentation maintenance

Consolidation authorized 2026-09-23. These rules implement the existing separation
between decided design, open questions and implementation work.

## One purpose per layer

- `docs/design/`: approved rules, including clearly labeled future systems.
  Replace superseded rules in their topic; do not append competing overrides.
- Root `TODO-*.md`: genuinely undecided questions. Move decided answers into the
  topic owner and delete an exhausted TODO after checking unique context/links.
- `BACKLOG.md`: implementation scope, dependencies and remaining acceptance.
  “Partially delivered” is not “not started”; “technically delivered” is not GUI
  acceptance or public-release approval.
- `ROADMAP.md`: goals and milestone overview, derived from design/backlog.
- `docs/STATUS.md`: current delivery and active-work pointers.
- `AGENTS.md` / `docs/process/`: working instructions and gates. Module details
  belong in technical references, not an ever-growing mandatory startup file.
- `docs/technical/`: implementation seams and pitfalls. These explain how the
  current implementation works and do not invent game rules.
- `docs/research/` and `docs/archive/`: research, decision provenance and historic
  plans/reviews/evidence. A reference may remain useful without being authority.
- Root README: derived human-facing introduction, never independent authority.

## One owner per fact

Each fact has one home; every other document links to it instead of
repeating it (set 2026-10-05 from the October 2026 audit's proposal). When a
fact changes, change its owner and check the links.

| Fact | Owner | Others |
|---|---|---|
| Push, acceptance and GUI-test state per round | [docs/STATUS.md](../STATUS.md) | link only; AGENTS.md keeps a three-line pointer |
| What a round shipped, its numbers and GUI checklist | `docs/planning/round<NN>-plan.md`, section "Completion" | STATUS: a short entry per round |
| Player-facing change log | `CHANGELOG.md` (repository root) | README: a short current state |
| Open work, carry-overs, open questions | [BACKLOG.md](../../BACKLOG.md) | ROADMAP links |
| Goals and milestones | [ROADMAP.md](../../ROADMAP.md) | — |
| Decided game rules and numbers | the topic file in [docs/design/](../design/README.md) | AGENTS.md names the coding rule, not the numbers |
| Open design questions | root `TODO-*.md` | — |
| Working rules and conventions | [AGENTS.md](../../AGENTS.md) | — |
| Round workflow, gates, review checklist, brief rules, templates | [round-workflow.md](round-workflow.md) | AGENTS.md points |
| Model routing | [agent-model-policy.md](agent-model-policy.md) | CLAUDE.md, AGENTS.md point |
| Which mod owns which concern | [mod-map.md](../technical/mod-map.md) | — |
| Implementation seams per area | [module-guide.md](../technical/module-guide.md) | — |
| Lua and engine rules | [luanti-lua.md](../technical/luanti-lua.md) | AGENTS.md keeps the key rules |
| Engine workarounds | [upstream-workarounds.md](../technical/upstream-workarounds.md) | — |
| Fixture and probe folders per round | [tools/README.md](../../tools/README.md) | — |
| Vendored code and its patches | [VENDOR.md](../../VENDOR.md) | — |
| Media licences and credits | each mod's `LICENSE-media.md`, [CREDITS.md](../../CREDITS.md) | — |
| Reference projects | [reference_projects.md](../reference_projects.md) | — |

## Resolving disagreement

Trace an approved rule through later approved decisions and relevant code.
Distinguish stale prose, approved-but-unimplemented work, implemented-but-not-
approved behavior and an actual unresolved decision. Correct stale prose only
when the evidence identifies its replacement. Escalate unresolved semantics;
do not silently rewrite design to bless the code or erase pending scope.

## Finishing a round

Lane D's checklist and the post-merge status step are in the
[round workflow](round-workflow.md#4-lane-d-and-the-post-merge-status-step).
Update the actual topic paragraphs, affected backlog remainders and status
pointers. Add a concise receipt linking evidence. Check README implications;
coordinate with its owner instead of overwriting concurrent work. A completed
plan becomes historical; future agents should not need it to discover an
unwritten override. Preserve review calibration and acceptance limits.

## Archiving and deleting

Extract unique decisions, remaining requirements and provenance before removal.
Delete duplicate summaries without unique value; archive historical rationale
and records worth retaining. Check incoming links and repository consumers first.
Evidence bundles, license records and source-bound citations keep stable paths
when relocation would break their meaning or tools. Their age does not make
them obsolete as evidence, nor authoritative for current behavior.

Keep an honest distinction between structural classification and substantive
review. A file inventory or search hit is not proof that its entire contents
were read or that its implementation was tested.
