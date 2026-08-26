# Agent model policy

Decided 2026-08-22. This is the sole project-wide authority for assigning AI
models to coordination, planning, research, implementation, review, and
integration work in Grudgelands. It applies to every work package and research
area. Domain-specific documents may define technical roles and deliverables,
but must not define a competing model priority.

The user is the final authority over every routing choice, ruling, and merge;
every clause in this policy yields to an explicit user instruction. Where this
policy and a process document overlap on non-model process, the process
document governs; this policy governs model choice. At adoption, the model
labels mean GPT-5.6 Sol, Claude Opus ("Opus"), Claude Fable ("Fable"), and
GPT-5.6 Terra.

Model names in completed reports and historical contracts remain factual
history, not current routing instructions. Any future-facing instruction that
conflicts with this policy is stale and this policy wins. Agent contexts that
were already running when this policy was adopted finish under their accepted
brief; the policy applies to every context started afterward.

## 1. Principles

- Route work by task risk, ambiguity, duration, reversibility, and the observed
  working characteristics of a model, not by a claim that one model is
  universally more intelligent than another.
- GPT-5.6 Sol is the default long-lived project coordinator. Continuity,
  explicit task tracking, exact contract adherence, and reliable integration
  across long sessions matter more in that role than peak one-shot insight.
- GPT-5.6 Sol and Opus are the normal strong implementation and review models.
  Choose between them using Section 3; neither is a fallback-class model.
- The coordinator may start an Opus review or bounded Opus task without a
  per-call confirmation. Fable always requires explicit user authorization
  for the particular review or delegated task. If the coordinator judges
  Fable to be the better route, it asks for that authorization instead of
  silently substituting Opus.
- Fable is an exceptional-reasoning resource. Reserve it for problems where a
  wrong direction would be costly or where strong general-purpose agents have
  a material risk of exhausting time on a false approach.
- GPT-5.6 Terra is permitted only for low-risk work whose result is cheap,
  deterministic, and independently verifiable and that requires no unresolved
  technical or design judgment.
- No implementation agent may invent player-visible design, authority, or
  underspecified semantics. Clarify or freeze the contract first.
- Every non-trivial change is independently reviewed by a different strong
  agent under **Independent review** below. Cross-model review is preferred
  because it exposes different failure modes.

## 2. Model roles

### 2.1 GPT-5.6 Sol — default coordinator and structured implementer

Use Sol by default for:

- long-lived project coordination, task tracking, package ordering, worktree
  ownership, prompt preparation, and final integration;
- turning broad or partially specified goals into explicit contracts and
  bounded implementation briefs;
- long, multi-stage, mechanical, or repository-wide implementations;
- migrations, refactors, evidence packages, and work that crosses several
  files or contexts while requiring strict adherence to a specification;
- systematic audits of code, artifacts, logs, contracts, and returned agent
  work; and
- deciding whether a problem meets the Fable escalation criteria below.

Under the user's direction, Sol remains the default integration coordinator
even when bounded packages are delegated to other models. A different project
coordinator is an explicit user decision, not a package-local default.

### 2.2 Claude Opus — fast specialist for frozen, bounded packages

Prefer Opus when:

- the contract, interfaces, owned files, acceptance criteria, and non-goals are
  already explicit;
- the work can be completed in a fresh, bounded context without carrying a
  large evolving project state;
- implementation speed or several independent parallel lanes are valuable;
  or
- a creative or adversarial counter-view is useful when reviewing Sol work.

Do not hand an underspecified package directly to Opus. Sol first closes the
ambiguity and produces the brief; if the ambiguity is itself exceptionally
difficult, escalate that semantic question to Fable. A fresh package-local
Opus coordinator is allowed only for a frozen, bounded package while Sol
retains project-level ordering and integration authority.

### 2.3 Claude Fable — exceptional-reasoning escalation

Fable is appropriate when one or more of these conditions hold:

- mathematical foundations, proofs, deterministic geometry, topology, or a
  novel algorithm carry difficult invariants;
- a cross-package architectural choice is expensive or hard to reverse;
- credible evidence conflicts, strong reviewers disagree, or a ruling has
  broad semantic consequences;
- two serious solution attempts have failed or repeated review rounds show
  that the current framing is wrong;
- Sol or Opus may produce a locally plausible solution while missing the
  governing model; or
- the coordinator can state a concrete reason why ordinary delegation has a
  high risk of wasting substantial time or moving the project in the wrong
  direction.

An obviously exceptional problem may go directly to Fable; failed attempts are
an escalation trigger, not a prerequisite. Announce the reason, expected
deliverable, and bounded scope before using Fable, and obtain explicit user
approval for that particular review or delegated task. Authorization for an
earlier Fable task does not silently carry to a new one. Do not route the work
to Opus merely to avoid asking when Fable is the coordinator's actual first
choice.

Fable should normally return the hard semantic result: a proof, ruling,
algorithm, architecture memo, or implementation-ready contract. Sol or Opus
then performs the mechanical implementation. If the semantic core cannot be
separated safely from its implementation, a bounded Fable implementation
requires the same explicit approval and an independent strong review.

Fable is not a routine coordinator, implementer, or reviewer and is not used
merely because a task is large.

### 2.4 GPT-5.6 Terra — low-risk verified assistance

Terra may perform:

- exact file, symbol, reference, or citation inventories;
- retrieval of facts from a prescribed source set without making the final
  interpretation;
- execution of explicitly listed, non-destructive checks;
- extraction or summarization of structured logs and test results;
- trivial documentation formatting; and
- tiny mechanical edits when the expected diff and automatic verification are
  both explicit.

Terra must not own:

- design decisions or interpretation of ambiguous requirements;
- mathematical, algorithmic, architectural, performance, persistence,
  security, or map-generation semantics;
- authority-heavy contracts, broad refactors, or repository-wide migrations;
- destructive or difficult-to-recover operations;
- final integration judgment; or
- the sole acceptance review of non-trivial work.

Research is not automatically low-risk. Terra may gather a bounded evidence
set; Sol, Opus, or Fable performs any complex synthesis or ruling.

## 3. Routing guide

| Task shape | Default route |
|---|---|
| Long-lived project coordination or integration | Sol |
| Ambiguous goal that needs a precise plan or contract | Sol; Fable if an exceptional criterion applies |
| Long, stateful, cross-file, mechanical, or strict-spec implementation | Sol |
| Frozen, self-contained implementation package where speed matters | Opus |
| Mathematical foundation, hard topology, novel invariants, or contested high-impact architecture | Fable for the semantic core, then Sol or Opus for implementation |
| Independent review of Sol implementation | Prefer Opus |
| Independent review of Opus implementation | Prefer Sol |
| Bounded fact gathering or deterministic clerical work | Terra, with strong-agent interpretation when needed |

When both Sol and Opus are reasonable, use this tie-breaker:

> Choose Opus for a clear build plan that a strong fresh agent should execute
> quickly. Choose Sol when the work must preserve evolving state, dependencies,
> or exact instructions across a long sequence. When both Sections 2.1 and 2.2
> match, choose Sol for long, stateful, repository-wide, or cross-package work.
> Choose Opus only when every owned file, interface, acceptance criterion, and
> non-goal is frozen before a package that fits one fresh bounded context
> starts.

Cost or availability may break a genuine tie, but must not downgrade a task
below the capability its risk requires.

## 4. Coordination and briefing

- Under the user's direction, Sol is the default project coordinator and
  maintains the current task graph, dependency order, agent routing, accepted
  findings, and integration gate.
- The coordinator may also implement when that is the most coherent route
  under this policy; role separation is not an end in itself. A coordinator
  must not self-approve its own non-trivial change under **Independent
  review**.
- Every delegated implementation brief states the authoritative documents,
  exact scope, owned files, frozen interfaces, non-goals, test budget,
  acceptance criteria, and stop/escalation conditions.
- An agent that finds material ambiguity stops that decision path and reports
  it. It may continue independent work that cannot prejudice the ruling.
- Parallel agents use separate branches or worktrees and non-overlapping file
  ownership. Parallelism does not justify duplicating authority or assigning a
  task to a weaker model than its risk permits.

## 5. Independent review

- Every change that is not trivial under the definition below receives at
  least one full independent review before integration by a different Sol or
  Opus agent in a context that has not worked on the reviewed change. The
  reviewer must not have implemented any part of that change or authored a
  contested ruling being reviewed. A Fable reviewer may replace or supplement
  that gate only when explicitly authorized under Section 2.3.
- Cross-model review is the default preference: Opus reviews Sol work and Sol
  reviews Opus work. Same-model review remains valid when availability or a
  specialized review lens makes it preferable; the freshness and independence
  requirements above apply equally to both routes.
- Review findings are verified against the actual code and evidence, ranked by
  severity, and fixed before integration. Critical or High fixes receive a
  focused re-review under the same independence requirements.
- Terra may prepare inventories or evidence for a review but cannot be its sole
  decision-maker.
- The project-specific technical checklist in
  [wp-workflow.md](wp-workflow.md) remains mandatory regardless of reviewer
  model.

A change is trivial only if it is comment-, formatting-, or documentation-only
with no effect on decided design, process authority, contracts, acceptance
criteria, interfaces, behavior, persistence, security, performance-sensitive
logic, tests, gates, oracles, or pinned evidence; or if it is one mechanical
edit with none of those effects. Any uncertainty makes the change non-trivial.
The task brief states a trivial classification before implementation and
preserves it in the durable completion record used under **Calibration and
policy maintenance**, or in the commit message when no such package record
exists. The implementer cannot choose it retrospectively.

## 6. Escalation and stop rules

- Escalate from Terra as soon as a task requires interpretation, branching
  judgment, or non-trivial editing.
- Escalate an underspecified Opus package to Sol for contract closure rather
  than accepting a best-guess implementation.
- An agent that finds its own assignment routed elsewhere by this policy says
  so before starting and continues only after explicit user confirmation.
- Escalate to Fable under Section 2.3 instead of repeating broad speculative
  attempts. State the precise hard question; do not send the whole repository
  when a bounded semantic core can be isolated.
- A model assignment never overrides destructive-action safeguards, explicit
  user authorization, repository ownership, runtime budgets, or the normal
  review gates.

## 7. Calibration and policy maintenance

Evaluate the Sol/Opus boundary after roughly every six to ten independently
reviewed packages using lightweight project evidence: specification
deviations, Critical/High findings, number of fix rounds, elapsed delivery
time, and coordination overhead. Each such package records its implementing
and reviewing model, Critical/High count, fix-round count, and observed elapsed
wall time (or `unknown`) in its durable completion record — normally its
BACKLOG completion summary, its package contract when it has no BACKLOG row,
this section when the reviewed change amends this policy, or the commit message
when none of those locations applies. Calibration reads those records rather
than relying on recollection.
Adjust this policy in one reviewed documentation commit when repeated evidence
supports a change; do not create local WP exceptions.

Model context limits, pricing, and product behavior change over time and are
not policy invariants. Record durable observed working characteristics and
routing outcomes rather than hard-coding transient vendor claims. A version
update presented under one of the four adopted labels retains that role
provisionally and is checked through calibration; a new or renamed model class
is not used for consequential work until its project role is explicitly added
here.

**Adoption-package calibration record (2026-08-22):** implementing model
GPT-5.6 Sol; reviewing model Claude Opus; classification: non-trivial (model
routing authority); initial review findings 0 Critical / 2 High; two fix
rounds; observed elapsed wall time `unknown`.

**Claude-execution and parallelism amendment calibration record
(2026-08-26):** implementing model GPT-5.6 Sol; reviewing model Claude Opus;
classification: non-trivial (process authority); initial review findings 0
Critical / 2 High; two fix rounds; observed elapsed wall time `unknown`. The
focused re-review verdict and immutable review hashes belong in the amendment
commit message.
