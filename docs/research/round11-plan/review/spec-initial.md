# Independent Round 11 SPEC authority review

Reviewer: native GPT-5.6 Sol (`/root/r11_farm_review`), independent of the documentation author.\
Candidate: `da3a4958` on `wp11-r11-spec-audit`; base `bc112522`.\
Disposition: **CHANGES REQUESTED**.

## Findings

### Medium — the Scout's authoritative weapon roster omits its accepted two-handed melee family

`docs/design/scout.md:45` defines Scout weapons as bow, dagger, and one-handed sword. The approved Round 11 authority explicitly adds the existing greataxe as the Scout's two-handed melee option (`round11-plan/README.md` and `round11-plan/gear.md` §3). No later active paragraph in `scout.md` restores that family; the file mentions only that bows are two-handed.

Concrete scenario: SCOUT implementation follows its class-specific living spec and gates or documents melee choices as dagger/sword only, silently dropping the approved greataxe route. Add greataxe to the authoritative Scout weapon row and keep the already decided generic-main-hand formula/no-class-gate behavior.

### Medium — active item-design prose still carries the retired Rogue and old leather-affix model

`docs/design/items_crafting.md:1357-1369` still describes leather primarily as a Warrior light set, lists the old pool without Mana, and says a separate Phase-2 Rogue will later become its primary wearer. The binding plan says Scout replaces the separate Rogue, uses leather, and may roll Mana; the same file's current §6.2 already lists leather as `Dex, HP, Mana, crit, dodge`. `docs/design/items_crafting.md:2152-2158` also states in active affix-vocabulary prose that poison arrives with the Rogue in Phase 2, while the approved plan says there is no separate Rogue and no V1 poison.

Concrete scenario: a future catalog or Scout worker reads the active vendor/affix explanations and either omits Mana from leather, preserves a fifth-class hook, or schedules poison contrary to Round 11. Rewrite these active paragraphs around Scout as the intended leather wearer and describe poison as absent/deferred without assigning it to a retired Rogue. Historical §10 quotations may remain labelled historical.

### Medium — living talent/combat status still reports settled decisions and delivered runtime as open or wholly unimplemented

`docs/design/combat_stats.md:19-21` still calls `skill_trees.md` a proposal and says it carries an open cap-override decision. The candidate itself changes the talent design to DECIDED, and Round 11 has settled and delivered the Unbroken armor-rating multiplier/window under the universal 70% cap.

`docs/design/skill_trees.md:18-20` says all keystones, capstones, and cap overrides remain unimplemented. That blanket statement is now false: the approved and accepted COMBAT package delivered the targeted Ironbound/Unbroken rating slice. `docs/design/skill_trees.md:45-52` additionally says current `economy.md` and `items_crafting.md` still carry the class-trainer seam and attempts to justify open questions inside `docs/design/`; both claims are stale. The current files have already removed that trainer seam, and AGENTS requires open questions to live in root `TODO-*.md`, never in design docs.

Concrete scenario: a later WP11 worker treats Unbroken as untouched X3 scope and reimplements or overwrites the delivered armor consumer, while planning reads a decided cap rule as open. Update the status to identify the delivered targeted Unbroken slice while leaving the remainder of X3 open, change the combat pointer to decided/current authority, and remove or rewrite the stale meta-history.

### Medium — the audit record asserts completeness despite the contradictions above

`docs/research/round11-spec-audit.md:44-48` claims the targeted Ironbound/Unbroken slice remains explicitly distinguished, but the living status paragraph still says all capstones/cap overrides are unimplemented. Lines 57-61 then state that no unresolved authority contradiction remains. The Scout roster and active Rogue/leather/poison passages above directly disprove that conclusion.

Required correction: after fixing the living docs, amend the audit to name those reconciliations and retain the intentional outstanding Bowyer bracket and Tanner shelf obligations. Those two obligations are valid pending SCOUT scope and are not findings.

## Reviewed areas without additional findings

- The revised armor-rating formula, attacker provenance, universal 70% cap, no pre-cap on rating, Unbroken `x1.40` then `+15` ordering, shield basis, and dragon level 70 match the approved plan.
- The active six-family gear roster, removal of scepter/orb routes, one-prefix/one-suffix quality contract, family affix matrix, bag/quiver rules, ammo ownership boundary, bow art dependency, and pending REPAIR wear boundary are otherwise represented consistently in the changed paragraphs.
- `scout.md` correctly keeps ballistic arrows, class/abilities/talents, Bowyer bracket integration, and Tanner shelf integration pending while treating GEAR/ART foundations as delivered. The required Bowyer and Tanner work must remain.
- The candidate contains documentation only and `git diff --check bc112522..da3a4958` passes. No runtime test was needed or run.

No repository file was edited and no commit was made by the reviewer.
