# Round 11 GEAR independent review

Reviewed candidate `d0190d4a7b90f96cf6cd2864359029e4d3376fd1` against base `45fbc477`, the approved Round 11 plan and GEAR annex, the current living design documents, the workflow checklist, and the frozen evidence/catalog. Reviewer independence: I authored none of the candidate. Review was read-only; no production files or commits were changed.

## Findings

### Medium — profession recipe books ignore the new mastery gate

`mods/PLAYER/grug_jobs/ui.lua:235` considers a recipe unlocked solely from profession tier, while `mods/PLAYER/grug_jobs/state.lua:173` separately rejects `mastery_required`. The new Goldsmith spellbooks and cloth/leather bag recipes therefore appear in the book as usable before their approved mastery band. Concrete example: a newly learned level-1 Goldsmith sees the T1 spellbook recipe because its recipe tier is 1, but the station refuses it until Journeyman mastery at character level 16. Likewise, a level-11 T2 Tailor sees the 16-slot bag but cannot make it until level 16. Make the book's unlock predicate apply the same mastery-band test (and preferably expose the required band in the recipe detail), using one shared authority so UI and station cannot drift.

### Low — full-inventory quiver refusal has no required player message

`mods/PLAYER/grug_inventory/bags.lua:190-196` correctly rejects removal when all quiver arrows cannot fit in `main`, but it only returns `0`. The approved contract requires a clear message; in the concrete full-inventory case the quiver merely snaps back with no explanation. Send a throttled player message on this refusal path while preserving the unchanged inventory transaction.

### Low — the frozen ammo evidence does not exercise the filled-quiver transfer it claims

`tools/r11_gear/ammo_kat.lua:34-40` consumes the last quiver arrow before simulating unequip, so the subsequent `atomic-unequip` receipt only transfers an empty quiver list. It does not test either successful transfer of remaining arrows or the full-main all-or-none refusal, despite `tools/r11_gear/evidence/luajit.log` claiming `atomic-unequip`. Extend the targeted LuaJIT fixture with (1) a still-filled quiver that transfers into available main capacity and clears only after success, and (2) insufficient main capacity that leaves the offhand and all arrow stacks byte-for-byte unchanged.

## Verified

- Frozen HEAD and clean worktree matched the brief.
- Catalog and evidence hashes match the recorded SHA-256 values; the catalog has 155 data rows.
- The existing targeted LuaJIT ammo and quality fixtures passed. No PUC runtime or broad suite was run, per the session constraint.
- The active runtime registrations remove scepter/orb gear identities and routes; ability-orb presentation references are unrelated.
- Bow/quiver hand legality, quiver-first/main-fallback consumption, shield base rating publication, spellbook base Mana, canonical reference-purchase-price lookup, and station operation registration were inspected against the approved contract.
- Pending final gear/station media remains the acknowledged ART-package dependency and is not treated as a GEAR logic defect.

Result: **FINDINGS — not clean.**
