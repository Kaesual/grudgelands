# Independent Round 13 equipment review

Reviewer: native Astra thread, independent from ROOT equipment authorship. Scope: frozen 18 code/test files plus design spec listed in SHA256SUMS; diff against 5d850163 in review.diff. No source edits. jobs/ui.lua and reviewer-authored ENCHANTS excluded.

## Finding: medium — partial repair removes active enchanted capabilities

mods/ITEMS/grug_repair/service.lua:84–94 resets tool capabilities to nil whenever no saved broken-item snapshot exists. An intact but worn Swift weapon has an active capability override and no _grug_repair_caps snapshot. Repair therefore removes its shortened attack interval while keeping its enchant metadata/description. Preserve the existing override unless restoring an actual saved snapshot. Confirmed using real repair service, provider and money transaction code through partial_repair_repro.lua under LuaJIT.

## Checks and evidence

- Exact tool budgets and combat budgets match the revision. Incoming wear chooses one eligible armor/offhand piece; outgoing wear remains main-hand-only with concrete action identity. Creative guards and broken quiver access/refund behavior inspected.
- Gathering tools have no equipment eligibility and zero weapon damage. The existing grug_mobs registered-cadence guard at mods/ENTITIES/mobs/api.lua:2981–2984 rejects ordinary tool/fist punches before damage; the initial candidate finding was retracted.
- Bronze definition level 1, metadata integration contract, concrete-ilvl armor and shield evaluation inspected. Protection calibration agrees: 181 raw armor becomes 298.65 (68.87% vs level 70); emergency 313.65 gives 69.91%.
- LuaJIT tools/r13_equipment/runtime_kat.lua passed in 0.03 seconds. This bounded fixture verifies durability transactions, not the full native engine/UI.
- git diff --check 5d850163 passed. No PUC runtime executed; review did not duplicate final parser/static/interpreter evidence.
- At review completion every frozen code/test hash still matched. The live design spec changed for the newly authorized jewelry extension; the reviewed snapshot remains immutable here.

Verdict: repair finding requires correction and focused recheck before clean approval. Native engine runtime remains a separate user gate.
