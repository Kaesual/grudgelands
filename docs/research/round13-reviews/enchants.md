# Independent ENCHANTS review

2026-09-21. Reviewed immutable commit
`dc91d65a879ba913793d81412f1defc13c7795a6` against `5d850163`, worktree
`/tmp/grug-r13-enchants`. Reviewer: native GPT-6 Astra, independently authored
STATIONS but no ENCHANTS production code. Authority: current coordinator
`docs/design/crafting_equipment_revision.md`, workflow checklist and Lua rules.
No repository edits, native server run or PUC runtime. Elapsed time: unknown.

## High — partially worn enchanted equipment loses capabilities on paid repair

`mods/ITEMS/grug_quality/init.lua:469-476` writes the repair capability snapshot
only for fully broken items. The unchanged integration consumer
`mods/ITEMS/grug_repair/service.lua:89-92` unconditionally replaces capabilities
with that snapshot or nil. A partly worn weapon receiving a named attack-speed
enchant has no snapshot; ordinary paid repair therefore removes its faster
punch interval while retaining the affix and tooltip. For off-anchor found
weapons the same clearing can also discard their derived damage capabilities.

Concrete reproduction: extend the supplied real-module fixture, apply a T6
attack-speed enchant to a partly worn Abyssal Steel sword, then load the actual
repair service and perform a quoted paid repair into main inventory. Observed
FPI changes from `0.87719298245614` to `1`; the targeted assertion fails.
`repair_repro.lua` and `repair-repro.log` contain the complete bounded LuaJIT
reproduction. Money/inventory/player adapters are synthetic, but enchant planning
and the quote/apply service code are the actual production modules.

This consumer defect predates the named-enchant change, but blocks the explicitly
requested repaired-item integration acceptance. Fix at the repair consumer:
preserve usable capabilities for an unbroken item when there is no broken-item
snapshot, while restoring the saved usable snapshot for genuinely broken items.
Keep the new enchant after both partial-wear and broken-item paid repairs.

No additional blocking defect found within the 420-operation catalog/pure-plan
implementation. Package approval is conditional on this integration fix and the
coordinator's actual station Apply verification.

## Checked surfaces

- Exactly 420 entries: eight ordinary families, 35 legal family/stat pairs,
  two channels and six tiers. Family, owning profession, station, tier component,
  tier reagent and Woodcarver extra fitting match the current spec.
- Canonical selected-operation identity, profession/tier permission, target
  family/minimum tier, exact single target, required material counts, rejection
  of unrelated slots, preservation of the other channel, duplicate opposite
  stat rejection and identical-value no-op refusal.
- Fixed tier values and numeric derived metadata; attack-speed replacement
  rebuilds capabilities from the actual item definition/effective item level.
  ItemStack copy preserves wear, identity, unrelated metadata and input stacks.
- Suffix-first explicit channel encoding, no old-format migration path,
  retired refinement/upgrade registrations and APIs removed from owned modules.
- Ordinary found windows/count rules and trinket fixed prefix/suffix special
  remain. Broken enchant planning updates the usable repair snapshot and leaves
  disabled current capabilities; actual subsequent repair was not covered by
  the submitted fixture, which is why the additional consumer test mattered.
- Equipment-cache wrapper forwards the third reason argument. No new hot loop,
  globalstep or inventory mutation in the pure operation API.
- Submitted SHA256 manifest verified without mismatch. Submitted parser,
  SETGLOBAL and five-sweep logs inspected. Re-ran only the bounded LuaJIT fixture:
  all 420 applications pass. No PUC runtime repeated.

## Separate integration observation

The current STATIONS candidate regenerates `crafted_output` on every preview and
again at allow_take. Goldsmith trinket `quality_mode='fine'` intentionally remains
random, so this would reroll prospective outputs and usually fail metadata
comparison. This is a STATIONS-authored integration defect, not an ENCHANTS
finding. It was reported immediately to the coordinator, who requested an
explicit Craft transaction for random trinkets with one roll after validation.
The STATIONS author will fix it separately; this reviewer does not approve that
own change.

Calibration: implementer Astra; reviewer Astra (independent agent). High=1
cross-package consumer finding; Critical=0; review fix rounds=0. Root remains the
integration authority. User runtime: enchant a partly worn weapon, pay for repair,
verify unchanged speed/damage, repeat while fully broken, then replace a channel
at its station and confirm preserved metadata and exactly one material/XP debit.

## Later user steering

After this review the coordinator relayed a new explicit user instruction:
crafted trinket enchants must also be selected and fixed-value. The proposed
random-trinket station special case is therefore cancelled; no such code was
written. This report assesses dc91d65a against the specification current at its
review start. The revised trinket catalog/operations require a new focused review.
