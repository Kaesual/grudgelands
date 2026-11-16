# Documentation maintenance

Consolidation authorized 2026-09-23. These rules implement the existing separation
between decided design, open questions and implementation work.

## One purpose per layer

- `docs/design/`: approved rules, including clearly labeled future systems.
  Replace superseded rules in their topic; do not append competing overrides.
- Root `TODO-*.md`: genuinely undecided questions. Move decided answers into the
  topic owner and delete an exhausted TODO after checking unique context/links.
- `BACKLOG.md`: the open implementation inventory by topic: scope,
  dependencies, what remains. A delivered item is deleted, not marked done;
  headings carry no delivery or acceptance state. “Partially delivered” is
  not “not started”; delivered is not public-release approval.
- `ROADMAP.md`: goals and milestone overview, derived from design/backlog.
- `docs/STATUS.md`: a replaced snapshot of the current state (shape in the
  owner table), never a log.
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
| Current state: version, the last round's squash commit and tag, production, push state, work in progress, open actions for the user, the last five rounds | [docs/STATUS.md](../STATUS.md): a snapshot of at most about 3 KB, replaced, never extended: a date and the hint to check the live state with `git status -sb`, `git log` and `git tag -l` (no main hash); the version with the last round's squash commit and tag; the production version; work in progress (branches, worktrees, the next round's plan); open user actions other than GUI tests; a table of the last five rounds (version, upgrade kind, pushed, completion link): a round's end adds its row at the top, drops the oldest and replaces the lines that changed, and a follow-up round (0.NN.x) widens its round's row instead of adding one; pointers to CHANGELOG, BACKLOG, ROADMAP and the archive. No lanes, fixtures, reviews or feature prose | link only; AGENTS.md keeps a three-line pointer |
| What a round shipped, its numbers, deviations and open notes; what it leaves behind | `docs/planning/round<NN>-plan.md`, sections "Completion" and "Carry-overs" (beside it) | STATUS: one table row; BACKLOG: a one-line topic item for a carry-over that is still wanted work |
| Player-facing change log | `CHANGELOG.md` (repository root) | README: a short current state, replaced, not extended |
| Open work and open questions | [BACKLOG.md](../../BACKLOG.md): only open work, by topic, no per-round sections; a delivered item is deleted | ROADMAP links |
| Goals and milestones | [ROADMAP.md](../../ROADMAP.md) | — |
| Decided game rules and numbers | the topic file in [docs/design/](../design/README.md) | the module guide's Rules block of the area names the coding rule, not the numbers |
| Open design questions | root `TODO-*.md` | — |
| Working rules and conventions | [AGENTS.md](../../AGENTS.md) for the rules every agent needs; a topic's rules in the **Rules** block of its [module guide](../technical/module-guide.md) section | AGENTS.md routes to them |
| Round workflow, gates, review checklist, brief rules, templates | [round-workflow.md](round-workflow.md) | AGENTS.md points |
| Which topic check to run after which change | [checks.md](checks.md) | AGENTS.md and the round workflow's gates link |
| Model routing | [agent-model-policy.md](agent-model-policy.md) | CLAUDE.md, AGENTS.md point |
| Which mod owns which concern | [mod-map.md](../technical/mod-map.md) | — |
| Implementation seams per area | the area files in `docs/technical/modules/`, indexed by [module-guide.md](../technical/module-guide.md) | — |
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

A round's end writes three things: the CHANGELOG entry, the plan's
"Completion" and "Carry-overs", and the round's row in STATUS
([round workflow](round-workflow.md#4-lane-d-and-the-post-merge-status-step)).
In the same pass lane D replaces README's short "Current state" paragraph
when the round changes what a visitor should read there; it is replaced,
never extended. Nothing is appended to AGENTS.md, ROADMAP.md or BACKLOG.md;
the lanes keep the topic paragraphs and the backlog items up to date by
replacing text, and a carry-over that is still wanted work gets a one-line
BACKLOG item under its topic, linking to the plan's "Carry-overs". The evidence of a round is linked from
its Completion, not repeated as a receipt elsewhere. Coordinate with a
file's owner instead of overwriting concurrent work. A completed plan becomes
historical; future agents should not need it to discover an unwritten
override.

## Archiving and deleting

Extract unique decisions, remaining requirements and provenance before removal.
Delete duplicate summaries without unique value; archive historical rationale
and records worth retaining. Check incoming links and repository consumers first.
Evidence bundles, license records and source-bound citations keep stable paths
when relocation would break their meaning or tools. Their age does not make
them obsolete as evidence, nor authoritative for current behavior.

**Cold storage** (user, 2026-11-16): bulky evidence that no code, tool,
fixture or live document reads (logs, data dumps, evidence folders) may leave
the working tree for `~/projects/grudgelands-orchestration/archive/`. Check
each group for readers first (grep `mods/` and `tools/`, including the
fixtures); licence provenance and path-bound data that tools read stay. The
folder it left keeps a short index of what moved and where.

Keep an honest distinction between structural classification and substantive
review. A file inventory or search hit is not proof that its entire contents
were read or that its implementation was tested.
