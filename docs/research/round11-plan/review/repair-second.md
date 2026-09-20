# R11 REPAIR focused re-review — findings

Candidate: `c53a512d30413ff6d0308c5382203ee04234c78e`\
Review: fresh native GPT-5.6 Sol, read-only\
Result: **not clean**

The correction closes the original exact-budget, broken-hoe, persistent item-ID,
action-settlement, runtime-evidence, and vendor-ledger findings. One High defect
remains.

## High

1. **`mods/ITEMS/grug_repair/runtime.lua:40-43,115-116` with `mods/PLAYER/grug_abilities/init.lua:2036-2053` — durability and identity metadata writes reset the authoritative swing cadence.** Every equipped wear event writes the changed stack and calls `equipment_changed`; `capture_action` does the same when it assigns `_grug_repair_item_id`. The real ability consumer compares the complete concrete `ItemStack` with `ItemStack:equals`, so wear, `_grug_wear_remainder`, `_grug_repair_caps`, or the new identity makes it look like an A→B weapon swap and resets `next_due` to a full interval. A successful swing therefore overwrites the already advanced late-carry clock, while launching the first Fireball with an unmarked weapon also resets the melee clock solely because metadata was added. This violates the frozen rule that wear/metadata writes must not reset cadence. `runtime_kat.lua:89` stubs `equipment_changed` as a no-op, so its claimed real-consumer coverage cannot expose the regression.

   Acceptance boundary for the correction: an equipped-stack write that changes
   only wear or repair-owned metadata must still invalidate equipment/stat/skin
   consumers and expose the broken baseline immediately, while preserving the
   existing `next_due`, late carry, input latch, and accumulated-melee state.
   Assigning the first projectile identity must have the same cadence-neutral
   behavior. A real concrete weapon replacement must continue to clear the
   accumulated melee state and begin one full interval. The focused fixture must
   load the actual equipment-change consumer and distinguish all three cases:
   ordinary wear, the 65535 transition/identity assignment, and an actual A→B
   swap.

## Resolved initial findings

- Integer remainder arithmetic reaches wear 65535 on event 3000/6000.
- Broken tool `on_use` is guarded before the hoe operation.
- Concrete launch-item IDs use a persistent mod-storage counter and receipts carry them.
- Heal/absorb APIs accept a caller-owned shared action identity suitable for
  future aura deduplication. Ordinary tables without `.id` also settle and
  deduplicate by table identity.
- Runtime and service KATs now load the changed modules and cover capability restoration, though their assertions/stubs miss the two defects above.
- `VENDOR.md` now records the repair patch and 66 markers accurately.

Correction to the review record: the earlier ordinary-table finding was a
reviewer false positive. In Lua, `condition and action_id.id or action_id`
falls back to the original table when `.id` is nil. A direct expression check
passed, and a temporary copy of the actual runtime KAT with the added assertion
`first wear > wear before first settlement` also passed. No product file was
changed.

Targeted verification performed: the two documented LuaJIT KATs were rerun,
plus the expression and first-debit counterexample above. No PUC runtime, broad
suite, production edit, commit, sync, push, or user-world mutation was performed.
