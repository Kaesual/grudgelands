# Round 12 final documentation review

Date: 2026-09-20  
Scope: bounded read-only review of the uncommitted completion/status documents. No tests were run and no repository file was edited.

## Findings

### High — `skill_trees.md` opens with an active status that says X3 is still open

`docs/design/skill_trees.md` lines 9–22 still say “Status, 2026-09-17,” “Lane X3 remains open,” and “Other keystones, capstones and cap overrides remain unimplemented.” This directly contradicts the updated X3 lane, BACKLOG, ROADMAP, design index and Round-12 completion record.

Replace that status block with current wording such as:

> **Status, 2026-09-20: lanes X1–X4 are implemented.** X1/X2 delivered the model and numeric consumers; X4 delivered the Talents page, free-first/paid reset transaction and level-up notice. Round 11 delivered the Scout trees and Ironbound/Unbroken slice. Round 12 completed the original-class X3 abilities, replacements and capstone consumers, together with Skills-catalogue entitlement and manual recovery. WP11 remains in progress only because WP44 has not published the measured six-bracket paid-respec prices; the current table in `talents_ui.lua` remains an explicitly named coordinator placeholder, not accepted measured values.

The X3 lane row is correctly labeled implemented, but its body retains future/planning phrases: “must preserve,” “The remaining crit override,” “Each remaining ability … needs,” and “needs the aggregator first.” Rewrite those as delivered facts or move them into historical implementation notes. For example, state that Round 12 preserved Ironbound/Unbroken, implemented the crit override, validated each consumer, and consumed the already shipped movement aggregator.

### Medium — completion/shipped wording currently precedes the still-pending delivery actions

The task state says main merge, runtime sync and push are still pending. The staged documents already say:

- BACKLOG: “subsequent approved round is complete,” “Round 12 delivered,” and WP47 “Shipped.”
- ROADMAP: “Round 12 delivered” and WP47 checked.
- README: “Round 12 technical delivery is complete.”
- `round12-completion.md`: “Delivery actions … are recorded in the final execution checkpoint.”

These statements become accurate after the authorized merge/sync/push sequence, but are premature before it. Either commit these completion docs only as part of/after that sequence, or temporarily change the completion header to:

> Technical implementation and independent review are complete. Main merge, runtime synchronization and push remain pending and will be recorded in the final execution checkpoint. GUI acceptance remains the user's next playtest.

After the actions succeed, restore final delivered/shipped wording and record the exact main head, sync result and pushed ref. Do not leave “are recorded” unless that record actually exists.

### Medium — `round12-execution.md` has no final checkpoint and remains actively contradictory

The execution record still begins `Status: ACTIVE`, lists every worker/package as active or queued, leaves all completion boxes unchecked, says “No Round12 bytes installed yet,” and ends with X3 review/integration/final regressions pending. Because the new completion record explicitly delegates delivery-action proof to this file, it must receive a final appended checkpoint after delivery.

The final checkpoint should record:

- all package/review gates clean and the final integrated head;
- the completed living-spec/TODO/evidence/checklist boxes;
- 110 native X3 assertions;
- catalog result 596 Basics / 63 starters / 57 foods / 4 Bronze armor starters, with the separate 830 total / 234 profession-owned catalog audit where relevant;
- the four focused regressions: combat settlement, real Skills callbacks, UI geometry and talent UI;
- static gates: 351 Lua files, SETGLOBAL, five sweeps and 13 unchanged pins;
- 1,961 runtime payload files and manifest SHA256 `9f46c3c50ff80ba3bd8d510280ddf42dc162fa6c102bd10b0286d85dfdb04fda`;
- no PUC runtime, GUI/network-client acceptance or broad mapgen/PERF claim;
- exact merge/main head, runtime sync and pushed ref after those actions actually succeed.

Earlier active/candidate sections can remain as chronological history if the final checkpoint explicitly supersedes them.

### Low — one README design-tour delivery sentence is now misleading

The farming paragraph ends “Both are delivered in Round 11,” immediately after describing the new Round-12 seventeen-family behavior. Grammatically, “Both” refers to Farming and Durability/repair, making the new farming iteration sound delivered in Round 11.

Suggested correction:

> The farming foundation and durability/repair service were delivered in Round 11; Round 12 adds the family-specific crop iteration.

### Low — completion evidence wording can name the four focused fixtures explicitly

`round12-completion.md` accurately states that combat settlement, Skills callbacks, UI geometry and talent purchase/respec fixtures pass. To match the requested “4 focused tests PASS” calibration unambiguously, say “Four focused fixtures pass:” before that list. This is editorial clarity, not an evidence gap.

## Checks that passed

- The readiness arithmetic is correct: **24 of 53 shipped**, **28 open/in progress**, with WP16 canceled. WP47 is the sole newly completed identity.
- WP11 consistently remains open for WP44's measured respec-price calibration in README, BACKLOG, ROADMAP, the design index and completion record. Apart from the `skill_trees.md` opening block above, active X3 status is correctly completed.
- Active README/BACKLOG/ROADMAP prose contains no remaining “awaits Go,” “Round 12 planning,” `TODO-round12-planning.md`, 23/53 or 25/53 status residue.
- Deleting `TODO-round12-planning.md` is correct: it had no open design question after Go and the accepted rules are folded into living design.
- The design index updates correctly cover five-minute food/main-material discovery, Skills/bound representations, retained mount tiers, farming families and X3/WP44 status.
- Completion and playtest links resolve: gallery, UX review, X3 review, next-playtest, plan and review directory are present.
- The playtest checklist correctly assigns Turn Aside to Priest Mercy and distinguishes GUI checks from existing synthetic/native evidence.
- The QA numbers are supported by the evidence files: X3 reports 110 checks; native catalog reports 596/63/57/4; startup/catalog documentation reports 830 total and 234 profession-owned; static summary reports 351 parsed Lua files and 13 unchanged pins; staging reports 1,961 matching payload files and the stated manifest hash.
- `git diff --check` is recorded PASS in final evidence and the reviewed documentation diff has no whitespace error.
- No historical Round-6/Round-7 record needs rewriting. Current Round-12 authority is added separately, and the old records are visibly historical.

## Result

The completion documents are close to internally consistent. Fix the active `skill_trees.md` status, clarify the Round-11 farming sentence, and make completion claims coincide with the actual merge/sync/push checkpoint. After those changes and successful delivery actions, the 24/53 status, WP47 completion, WP11 remainder, links and QA claims are coherent.

## Coordinator closure

The active skill-tree header and X3 row now report the delivered consumers,
leaving only WP44 price calibration. README distinguishes the Round11 farming
foundation from Round12 family work. Execution has a final technical checkpoint;
its main/sync/push receipt will be appended after delivery. The user raised
shared station ownership during this audit; its investigation and undecided
followup are recorded separately, with no implementation added to Round12.
