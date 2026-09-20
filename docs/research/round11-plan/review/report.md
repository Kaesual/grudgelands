# Independent Round 11 plan review

Reviewed 2026-09-20 by native Astra, independently of plan authorship. Planning only: no implementation, engine, interpreter fixture or runtime test was executed. Scope: the four files in `/tmp/grudgelands-r11-plan-review-inputs.sha256`; all four SHA checks passed. Baseline `ac232ec2`. Latest user armor clarification is included in the reviewed README and COMBAT annex.

**Verdict: FIX FIRST — 0 Critical, 0 High, 2 Medium, 0 Low.** These are bounded planning corrections, not new design questions or implementation findings.

## M1 — The water release criterion demands engine quiescence that the documented veto API does not promise

Locations: `docs/research/round11-plan/world.md:239-250`, §6 water-flow acceptance, and `:296`.

The annex requires the callbacks to become quiescent and proposes escalation to an engine/vendor patch if they do not. The pinned engine explicitly documents that a vetoed flood will most likely invoke `on_flood` again every liquid interval (`reference_projects/luanti/doc/lua_api.md:11009-11015`); `reference_projects/luanti/src/servermap.cpp:1172-1175` skips air and continues after a veto. A correct protected boundary can therefore receive repeated callbacks without an accumulating queue or performance defect. Requiring zero/receding callbacks unnecessarily blocks the accepted water bucket or expands it into engine work.

Required correction: define bounded steady-state work and storage, not absence of engine callbacks. Preserve the pre-flood veto, original callback behavior outside protection, exact post-transform restoration for protected air/liquid, no drops and no modification of allowed neighboring sources. Charge work to actual transformed/vetoed boundary entries; prohibit a growing private retry queue and added polling. Verify stable bounded work/storage over repeated liquid intervals. Escalate only an actual inability to preserve the protection/no-loss/bounded-work contract, not ordinary repeated engine callbacks. No engine fork or custom fluid simulation is authorized by this plan.

## M2 — Mount annex introduces an intermediate user-GUI freeze gate

Locations: `docs/research/round11-plan/combat.md:209-211` versus `docs/research/round11-plan/README.md:263-265`.

COMBAT requires a real first/third-person and remote-observer GUI witness **before freezing the transform**. The governing README explicitly permits autonomous delivery without waiting for an intermediate user GUI session. These are conflicting instructions at the handoff to GAME, even though README declares precedence.

Required correction: retain those viewpoints as explicit fresh-world user visual acceptance after delivery, and require available bounded technical/visual evidence before source freeze without conditioning it on a user GUI session. State honestly that headless correctness does not prove perceived camera behavior. Do not remove the eventual GUI checklist or claim it passed.

## Checked boundaries without further findings

- Armor remains a proposal, not a retroactive claim about accepted old design. Raw rating is not clamped; K(60/65/70)=50/92.5/135 and final DR alone caps at 70%. At L70, 210/294/309 rating yields approximately 60.87%/68.53%/69.59%. The existing talent implementation documents the 21-point capstone cost and impossibility of two capstones with 30 points (`mods/PLAYER/grug_classes/talents.lua:11-25`). The targeted permanent Unbroken consumer plus its emergency window is explicitly in scope; the other old three-class X3 work remains excluded. The no-rating fractional path, authoritative attacker provenance, boss level consumers and retained authored loot/XP boundaries are specified.
- Repair uses a bounded reference-purchase-price provider, current sold prices and explicit unsold slot/tier mappings with proposed quality factors. Its exhaustive identity table is a pre-code package deliverable, not an implicit implementation of WP44. Tool wear budgets, exact-once combat events and metadata-preserving transactions are separated.
- Quiver is optional, has four stack slots, and is absent from the Scout starter kit. Ammo has main-inventory fallback, a narrow bow/offhand exception and an all-or-refuse removal contract. New book/bag/bow proposals explicitly supersede the relevant earlier assumptions rather than silently inheriting incompatible ones.
- Ecology accounts for partial loading and observed generation baselines, charges every inspected node to the global budget, and does not infer depletion from unseen regions. Source eligibility and actor-neutral claim protection are assigned to explicit owners. Baseline bookkeeping and nonzero debt are separate persistent information; implementation must retain both as the annex already requires. No new census, global scan, ore renewal or preload is scheduled.
- Water metadata retains ordinary versus river identity; the protection dependency is explicit rather than omitted. The remaining correction is M1's acceptance criterion.
- Shared-file integration is serialized; WORLD-CAP geometry and GAME display movement have separate ownership and a socket contract. Price/rating/ammo/event interfaces have named consumers. The narrow beach diagnosis has bounded witnesses and an explicit escalation condition rather than an assumed broad terrain rewrite.
- LuaJIT owns development, static Lua 5.1 checks remain required, workstation concurrency is capped at seven, and only one final frozen compact PUC/LuaJIT pair is planned. No intermediate PUC fleet, resource census or dedicated gate-headroom test is introduced. Broader future WPs are not claimed complete.

A focused reread of the two corrected paragraphs and their corresponding acceptance/stop-condition wording is sufficient to close these findings; no runtime is needed for this planning review.

## Focused v2 closure

All four hashes in `/tmp/grudgelands-r11-plan-review-inputs-v2.sha256` verified. M2 is closed: COMBAT now explicitly keeps GUI checks in the final user playtest without an intermediate delivery gate. Armor upper-bound wording and mandatory shield refinement are consistent.

M1 remains open only in two missed WORLD clauses: §6 still requires a bounded callback count “rather than repeated restoration forever”; §7 still requires a “bounded quiescent protected boundary”. The corrected §5.1 is satisfactory. Align these final acceptance/stop clauses with bounded per-event work/storage and protection/no-loss semantics; do not require cessation of normal repeated engine events.

Current v2 result: **0 Critical, 0 High, 1 Medium open; 1 Medium closed**.

## Final focused v3 closure

All four hashes in `/tmp/grudgelands-r11-plan-review-inputs-v3.sha256` verified. WORLD §6 now explicitly permits repeated engine callbacks while requiring bounded per-event work and loaded-boundary storage without a growing queue. Its §7 stop condition now concerns preservation of protected state, drops/loss and bounded work/storage. Both remaining M1 clauses are fixed.

**Final planning verdict: CLEAN — 0 Critical, 0 High, 0 Medium, 0 Low open.** Original history remains two Medium findings, both closed. This approves the reviewed plan's consistency and bounded execution strategy; it does not authorize implementation, assert technical tests passed, or preempt the user's final Go and subsequent implementation reviews. No runtime was executed and no repository file was changed by this reviewer.
