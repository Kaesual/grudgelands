# Round 9 process-authority audit

## Scope and method

This is a read-only audit of the Round 9 orchestration briefs against the repository's process contracts and the user rulings recorded in `TODO-round9.md`. It does not assess agent intent. No repository, handover, engine, test, or agent state was changed.

Files examined directly:

- `/home/jan/projects/grudgelands-orchestration/w9/common.md`
- `/home/jan/projects/grudgelands-orchestration/w9/docs/brief.md`
- `/home/jan/projects/grudgelands-orchestration/w9/prof-a/brief.md`
- `/home/jan/projects/grudgelands-orchestration/w9/prof-a/brief-run2.md`
- `/home/jan/projects/grudgelands-orchestration/w9/prof-b/brief.md`
- later PROF-A/B fix and review briefs in those two directories
- `/home/jan/projects/grudgelands/docs/process/agent-model-policy.md`
- `/home/jan/projects/grudgelands/docs/process/wp-workflow.md`
- `/home/jan/projects/grudgelands/TODO-round9.md`
- the relevant decided rules in `docs/design/items_crafting.md` and `docs/design/professions.md`

## Confirmed authority inversion

### 1. The common brief gives a generated task brief power to override its own authoritative plan

`/home/jan/projects/grudgelands-orchestration/w9/common.md:13-17` first calls the lane's `TODO-round9.md` bullet, user rulings, and design docs binding, but line 15 then says: “Where this brief and the plan differ, this brief wins.” This is a categorical priority rule. It does not limit brief priority to a later explicit user ruling, an approved contract amendment, or a recorded supersession.

That priority is inverted relative to the project process:

- `/home/jan/projects/grudgelands/docs/process/agent-model-policy.md:9-14` makes the user final authority and says policy defaults yield to explicit user instruction.
- `agent-model-policy.md:54-55` says implementation agents may not invent player-visible design or underspecified semantics.
- `agent-model-policy.md:194-200` requires delegated briefs to state authoritative documents and requires material ambiguity to stop the affected decision path and be reported.
- `/home/jan/projects/grudgelands/docs/process/wp-workflow.md:35-46` requires a brief to identify authoritative spec sections and says a WP with an unresolved design blocker is not started.

A coordinator may sharpen an implementation contract, but these rules do not grant an ordinary lane brief unconditional authority to supersede user rulings or decided design. The defect is the unconditional wording in `common.md:15`, not the existence of a detailed brief.

### 2. The documentation lane explicitly places implementation above user decisions and decided design

`/home/jan/projects/grudgelands-orchestration/w9/docs/brief.md:101-104` orders its sources of truth as: (1) code on main, (2) merge records, (3) `TODO-round9.md` user rulings, (4) the audit report. It then instructs: “Every design document says what the merged Round 9 code does.”

This is a concrete inversion, because the repository's documentation layers make `docs/design/` the decided game design and WPs/implementation consumers of it; the workflow requires design-adherence review rather than retroactive normalization of design to code (`wp-workflow.md:35-46,134-137`). The user remains final authority (`agent-model-policy.md:9-10`). If merged code contradicts a user ruling or decided design, the proper docs-lane result is a blocker/code discrepancy, not changing the design document so the code becomes authoritative.

The danger is not hypothetical: `docs/brief.md:117-121` directs the docs worker to document the merged profession catalogs and exceptions, while its source-order rule makes any implementation divergence outrank the older user-approved design.

## Profession briefs: universal base versus refinement

### Decided rule available before Round 9

The universal-base/refinement split was not newly invented by Playtest 12. It had been explicit since 2026-08-07:

- `/home/jan/projects/grudgelands/docs/design/items_crafting.md:69-74`: one item per concept; everyone crafts every tier's base items; professions refine/enchant and own only a few exclusive recipes.
- `items_crafting.md:546-584`: tools, weapons, and armor are universally craftable; professions add refinement, enchants, special variants, and a few exclusive recipes.
- `items_crafting.md:858-869`: the old profession-owned catalog is expressly superseded; profession sections list material chains, families they improve, and a small exclusive set.
- `items_crafting.md:874-909`: Blacksmith “refines and enchants” the named families; its actual exclusive recipes are fittings, shield, kits, and special operations. Higher picks are universal base recipes; the Blacksmith trade good is the refined pick.
- `items_crafting.md:2076-2123`: “This is what a profession is for”; everyone crafts the base, the profession improves it by +15% and unlocks enchanting.
- `/home/jan/projects/grudgelands/docs/design/professions.md:38-39,181-194`: base crafting is universal; vendors and base crafting share item identities; refined/enchanted output is profession-only.

Git blame attributes the core universal-base statements at `items_crafting.md:69-74` and the interpretive rule at `:858-869` to the 2026-08-07 design commit, well before the 2026-09-19 profession briefs.

### What the Round 9 plan said

`/home/jan/projects/grudgelands/TODO-round9.md:227-251` preserved the distinction: PROF-A includes “in-place refinement of the universal base items”; PROF-B builds its catalog after the shared substrate. It did not authorize moving universal base production behind profession stations.

### PROF-A confirmed mismatch

The first substrate brief does not itself assign base gear to professions; `/home/jan/projects/grudgelands-orchestration/w9/prof-a/brief.md:112-156` builds stations and station-only recipe mechanics. Its broad phrase “Blacksmith, Leatherworker and Tailor catalogs” at `:92-97` is deferred to run 2.

The run-2 brief cites the correct source sections, including universal in-place refinement (`/home/jan/projects/grudgelands-orchestration/w9/prof-a/brief-run2.md:8-18`). However, its actual deliverable at `:20-29` tells the worker to register T1-T6 chains as station recipes, with gear recipes outputting existing `grug_gear` items, plus refinements in the grid. It never separately requires the universal base recipes, their ordinary 3x3 shapes, or a proof that base items remain craftable without the profession. Its acceptance criteria at `:37-47` require an exact profession recipe surface and rejection at the wrong station/grid, but have no universal-base reachability assertion.

This is not a complete omission of refinement: refinement is explicitly required at `brief-run2.md:15,24`. The misrepresentation is that the brief also frames the base gear outputs as profession-station catalog recipes, despite the cited design saying the profession owns improvement, not existence. Because acceptance independently freezes “every expected output, none extra” without a universal-base oracle, the tests can certify the wrong ownership model.

### PROF-B confirmed mismatch

The same pattern appears in `/home/jan/projects/grudgelands-orchestration/w9/prof-b/brief.md:97-123`: it cites one-item-per-concept and §6b refinement, then requires T1-T6 caster-weapon recipes at the carving bench whose outputs are existing gear, plus separate grid refinements. Acceptance at `:125-136` proves station binding, tier rules, and exact profession recipe surface, but never proves that the unrefined caster base remains universally craftable.

Again, refinement was not omitted: `prof-b/brief.md:105,117-118` expressly requires it. Universal base ownership was omitted from the executable deliverable and acceptance contract, while station creation of base gear was positively required.

### Later PROF-A/B briefs did not repair the authority boundary

Later review/fix briefs focus on refinement metadata, quality callbacks, fitting cross-buy, missing gear identities, and integration behavior. Examples include:

- `/home/jan/projects/grudgelands-orchestration/w9/prof-a/review-brief-2.md:60-68`
- `/home/jan/projects/grudgelands-orchestration/w9/prof-b/review-brief-1.md:60-68`
- `/home/jan/projects/grudgelands-orchestration/w9/prof-b/fix-brief-2.md:12-20`

Those briefs verify that refinement survives and grants the planned bonus. They do not introduce an oracle requiring canonical profession-free base recipes or removing base-assembly recipes from profession stations. Thus they fixed refinement execution while retaining the original ownership mismatch.

## Relation to the later user rulings

`/home/jan/projects/grudgelands/TODO-round9.md:683-708` records Playtest-12 rulings 47-50.

Confirmed chronology: the initial PROF-A/B briefs are dated 2026-09-19, while these rulings were added on 2026-09-20. The initial briefs therefore could not quote rulings 47-50 themselves.

The substance separates into old and new decisions:

- Ruling 47's exclusive **Basics** category and player-language group labels are new UI clarification.
- Ruling 48's exact Minecraft/VoxeLibre shapes and sword quantities are new precision, but its statement that base weapons/tools/all armor are universal restates the pre-existing 2026-08-07 design.
- Ruling 49 restates and demands completion of the pre-existing refinement/+15%/prefix-suffix plan; it does not establish that plan for the first time.
- Ruling 50 moves the Weaponsmith/Armorsmith split into current work and explicitly supersedes the prior no-split decision; this is a genuine new design change and cannot be treated as an earlier brief defect.

## Bounded causal inference

Confirmed facts support this process chain:

1. Decided design and the Round 9 plan said universal base plus profession refinement.
2. Implementation briefs cited those sources but required profession-station base-output catalogs and did not test universal base reachability.
3. The common rule said the brief wins if it differs from the plan.
4. The final docs brief said merged code outranks user rulings and instructed docs to match code.

It is therefore reasonable to infer that the orchestration contract permitted a design-to-brief-to-code drift to be treated as authoritative and then documented as intended behavior. This is an inference about the effect of the written process, not about why any person or agent wrote it. Establishing the exact historical cause of each shipped recipe would require a separate commit-by-commit implementation audit; this report does not claim that every incorrect recipe arose solely from these sentences.

## Preventive traceability and checklist

Replace categorical “brief wins” language with this hierarchy:

1. Latest explicit user ruling.
2. Decided `docs/design/` rule, unless a later user ruling explicitly supersedes it.
3. Approved WP/`TODO-round9.md` contract.
4. Implementation brief, which may sharpen but may not contradict levels 1-3.
5. Existing code and merge reports as evidence of implementation state, never design authority.

Every implementation brief that touches player-visible behavior should include a compact traceability table:

| Deliverable / acceptance row | Authority | Exact invariant | Supersedes |
|---|---|---|---|
| e.g. base sword recipe | `items_crafting.md:546-584` | profession-free, canonical grid shape | none |
| e.g. sword refinement | `items_crafting.md:2076-2123` | profession-only, consumes base, +15% | none |

Mandatory preflight checks:

- Quote every relevant “supersedes”, “everyone”, “only”, and “exclusive” sentence from the named design sections; do not rely on section titles such as “Blacksmith catalog”.
- For every output, classify the route as exactly one of: universal base, profession refinement, profession-exclusive item, or intermediate material.
- Require a negative ownership test: universal output succeeds with no profession; refinement/exclusive output fails without its profession.
- Require an exact-route test: one base route belongs to Basics; one refinement route belongs to the profession book; no duplicate book membership.
- For shaped base recipes, pin an independent VoxeLibre-derived layout/quantity oracle rather than deriving the expected surface from production tables.
- If a brief differs from plan/design, include a `Supersession` row with the later user ruling and date. Without one, stop that decision path.
- Reviewers compare the brief itself to authority before reviewing code. Passing tests derived from a contradictory brief cannot establish design adherence.
- Documentation lanes use priority: user ruling/design -> implementation. Code discrepancies become blockers or implementation follow-ups; docs are changed to match code only when code is already proven conformant or the user explicitly adopts the code behavior.

Closeout should include a ruling-to-code-to-test-to-doc matrix. A row is incomplete if any of those four links is absent, and “merged behavior” alone is never a design citation.

## General context-injection risk

The current external PERF reviewer stderr reportedly contains a Codex warning that automatic `AGENTS.md` injection exceeded a 32,768-byte budget and was truncated. This is a general process risk, not evidence that an earlier profession or documentation worker failed to read `AGENTS.md`, and it does not establish which portion any earlier context contained. The Round 9 common brief explicitly told workers to read `AGENTS.md` (`common.md:8-12`), so no stronger historical conclusion is supported without the individual run transcript.

The safe preventive rule is to avoid treating automatic instruction injection as proof of full-file coverage. Keep the short, critical authority hierarchy near the start of `AGENTS.md`, and make each brief explicitly require direct reads of the bounded scope documents and cited line ranges. The traceability table above should record those direct sources. If the applicable sections are long, the worker should report the exact files/ranges read and continue reads to EOF where the task requires the whole file. No Codex configuration change is needed for this safeguard.


---
Archived from the independent audit; local source links and whitespace were normalized to
portable path citations. Baseline line numbers refer to `2a308891`.
Coordinator dispositions in [README.md](README.md) govern the combined inventory.
