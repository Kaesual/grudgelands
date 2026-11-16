# Agent model policy

Decided 2026-08-22, cut to the current rules on 2026-11-16. The one authority
for which AI model coordinates, implements and reviews; the
[round workflow](round-workflow.md) governs everything else about how work
runs. The former Sol and Terra roles, the routing table and the calibration
records are [archived](../archive/process/agent-model-policy-2026-08.md).

## Routing

- **The user decides per session** which model coordinates, implements and
  reviews (2026-09-14); the defaults below apply only when the user names
  none. Every clause here yields to an explicit user instruction.
- **Defaults:** a Claude session coordinates. **Opus implements and reviews
  wherever possible** (2026-11-16); the coordinator may start an Opus lane or
  review without asking. **Astra** (GPT-6 Astra through the Codex CLI,
  [Astra lanes](cross-cli-orchestration.md)) generates art and writes quest
  texts and other creative content inside a frozen frame (principles, limits,
  data schemas, measured facts); its output is a proposal, not a ruling, and
  is reviewed independently. Other models (such as GPT-5.6 Sol or Terra) run
  only when the user routes them.
- **Fable** is precious. A Fable lane, review or task needs the user's
  approval **per lane**, asked with a short reason why Fable and not Opus
  (for example a hard semantic core, an expensive-to-reverse architecture
  choice, conflicting evidence, or two failed attempts). An approval does not
  carry over to the next task. When Fable is the coordinator's real first
  choice, it asks instead of silently using Opus.
- **A session that runs on Fable passes Fable on** to every subagent started
  without a model override; such a subagent counts as a Fable lane. So the
  coordinator sets the model of every launch explicitly (the override
  `model: "opus"` works, tested 2026-11-16). It tests the override once
  before the first launch of a session; if the override fails, it asks the
  user before launching.
- **Execution channel** (2026-09-20): models of the coordinator's own
  provider run as native subagents, never through that provider's CLI. CLI
  delegation only crosses providers (Claude may run Codex CLI; Codex may run
  Claude CLI when authorized). A native slot limit does not justify a
  same-provider CLI workaround.

## Duties that do not relax

- **No agent invents** player-visible design, authority or underspecified
  semantics. An agent that finds a material ambiguity stops that path and
  reports it; it may continue work that cannot prejudice the ruling.
- **Independent review:** every change that is not trivial gets at least one
  full review before it merges, by an agent in a fresh context that wrote no
  part of the change and no contested ruling under review. Same-model review
  (Opus reviewing Opus) is valid. Findings are verified against the code,
  ranked by severity and fixed; a Critical or High fix gets a focused
  re-review. The [review checklist](round-workflow.md#5-reviewing) applies
  whatever the model. The coordinator may implement, but never approves its
  own non-trivial change.
- **Trivial** means comment-, formatting- or documentation-only with no
  effect on decided design, process authority, contracts, acceptance
  criteria, interfaces, behaviour, persistence, security,
  performance-sensitive logic, tests, gates, oracles or pinned evidence; or
  one mechanical edit with none of those effects. Any doubt makes a change
  non-trivial. The brief states a trivial classification before the work
  starts, and the plan's Completion or the commit message keeps it; the
  implementer cannot choose it afterwards.
- **Parallel agents** use separate worktrees and branches with
  non-overlapping file ownership.
- A model choice never overrides destructive-action safeguards, explicit
  user authorization, repository ownership, the process budgets or the
  review gates.

## Maintenance

Model names in reports and historical plans are history, not routing. A
version update under an adopted name keeps its role provisionally; a new or
renamed model class is not used for consequential work until its role is
added here. No per-package calibration records are kept (user, 2026-10-06).
Change this policy in one reviewed documentation commit; no local
exceptions.
