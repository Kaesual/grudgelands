# Round 11 REPAIR evidence

Date: 2026-09-20. Implementation model: native GPT-5.6 Sol. This package is
non-trivial and requires a fresh independent review before integration.

The package preserves exhausted stacks at wear 65535 and uses an integer
remainder so Common and refined combat equipment expire on exactly event 3000
and 6000. Broken base/affix/refinement and tool effects are suppressed, including
an `on_use` guard that covers the current and incoming FARM hoe callbacks, and
the quoted atomic city service restores the saved capabilities on the same
stack. Incoming wear is driven by COMBAT's post-mitigation, nonlethal actual
HP-loss seam. Successful damage, in-combat effective healing and in-combat
effective absorbs drive outgoing wear. A shared action identity deduplicates
multi-target and multi-result settlement.

`grug_repair.capture_action(player, action_id)` is the public delayed-action
boundary for Scout and other projectiles. It returns a serializable receipt
whose `id` is the supplied once-per-action identity and whose `item_ids` name
the concrete launch-time main hand and spellbook. Store that receipt in the
projectile's persistent data and pass it as `opts.action_id` to
`grug_core.deal_ability_damage`, or call
`grug_repair.settle_captured_action(player, receipt, kind)` once an effective
custom result is known. Call `cancel_action` on launch failure (it is an
intentional no-op because receipts own no live state). Persistent mod-storage
serials prevent identity reuse after restart; settlement scans owned equipment,
main and bag storage, so swaps cannot debit the replacement.

Healing callers pass one shared identity as
`grug_core.heal_player(..., {action_id = id})`; shield callers pass it as the
fifth argument to `grug_core.set_absorb(player, amount, duration, source, id)`.
Reuse the same value for every target/tick/result belonging to one action.
Core emits only for an effective in-combat heal or shield grant, and REPAIR
charges that identity once.

The registered-item audit requires every eligible identity to have an explicit
GEAR reference purchase price. Repair preserves ordinary metadata and clears
only the durability remainder and the temporary broken-capability snapshot.
Creative actions, misses, cancellations, full absorbs, lethal hits and
environmental damage do not spend combat durability.

Verification on the frozen candidate:

- plain Lua 5.1 parser over every changed Lua file: pass;
- changed-file `SETGLOBAL` inspection: only the established mod globals;
- five Lua compatibility/sandbox sweeps: no changed-code violation;
- `tools/r11_repair/runtime_kat.lua` under LuaJIT: pass — exact 3000/6000
  boundaries, non-destructive broken hoe guard, ordinary table and shared
  heal/absorb action identities,
  creative exclusion, and persisted concrete projectile item across restart
  and equipment/bag swaps, including persistent serial uniqueness;
- `tools/r11_repair/service_kat.lua` under LuaJIT: pass — includes restoration
  of saved tool capabilities while preserving unrelated metadata;
- `tools/r11_combat/armor_kat.lua` under LuaJIT: pass — effective heal/absorb
  action identity, out-of-combat/zero-result exclusions, and nonlethal combat
  incoming settlement versus lethal/environmental/zero-result exclusions;
- `tools/wp39/projectile_test.lua` under LuaJIT: pass;
- `git diff --check`: pass.

No PUC runtime, broad suite, sync, push or user-world mutation was performed.
