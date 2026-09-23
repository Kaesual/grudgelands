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

## Resolving disagreement

Trace an approved rule through later approved decisions and relevant code.
Distinguish stale prose, approved-but-unimplemented work, implemented-but-not-
approved behavior and an actual unresolved decision. Correct stale prose only
when the evidence identifies its replacement. Escalate unresolved semantics;
do not silently rewrite design to bless the code or erase pending scope.

## Finishing a round

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
