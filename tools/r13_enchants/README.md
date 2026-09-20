# Round 13 named enchanting

Authority: `docs/design/crafting_equipment_revision.md` (coordinator integration).
The native implementation thread was explicitly routed as Astra; it has no
independent model-introspection endpoint. This package requires an independent
review and the coordinator's combined station/equipment integration checks.

## Catalog and station contract

`grug_jobs.station_operations(station)` returns the selected-operation catalog;
with no station it returns all 420 entries. `station_operation(id)` resolves one
canonical object. These entries never participate in ordinary recipe matching.
Each entry contains `id`, `profession`, `station`, `tier`, `operation = "enchant"`,
`family`, `enchant_channel`, `enchant_stat`, `enchant_value`, `label`, `hint`,
`inputs`, `flat_inputs`, `output`, `output_name` and `in_place = true`.
`output` is a minimum-tier representative for the book, not a manufactured item.

`grug_items.operation_plan(recipe, inputs, player)` returns
`{output = ItemStack, consume = {[slot_index] = count}, recipe = recipe}` or
`nil, reason`. It is pure: no inventory writes, material consumption or progress.
`preview_station_operation` and `apply_station_operation` expose the same
fully validated deterministic output copy. The station must obtain a fresh plan
at Apply, check destination capacity and all current access/lifecycle rules,
then consume exactly `plan.consume`, deliver `plan.output` and award recipe-tier
progress once. Ineligible plans and identical replacements consume nothing.

The explicit channel is part of each `grug_ench` record, including found rolls.
It permits a suffix before a prefix without position-based ambiguity. No
old-format reader or migration is included. Found random windows and the fixed
trinket channel exception remain; ordinary applications use fixed tier values.
Broken item operations preserve wear, retain disabled capabilities and refresh
the repair service's usable-capability snapshot. Gathering tools are excluded.

## Bounded validation

Run from the repository root:

```sh
luajit -e 'io.write(dofile("tools/r13_enchants/final_micro.lua")("."))'
```

The fixture loads the real gear, quality, Jobs registry/state, profession and
artisan catalogs. It validates all 420 operation applications and startup
material references, suffix-first display, fixed strength on higher-tier gear,
replacement and opposite-channel preservation, no-op refusal, profession/item
tier/material/family rejection, wear/identity preservation, broken capability
snapshot, found/trinket rolls, Bronze level-one initialization and removal of
retired operations. It uses bounded engine stubs and does not claim engine UI,
station transaction or durability-service runtime acceptance.

Evidence: `evidence/development-luajit.log`, `evidence/static.log` and
`evidence/repo-sweeps.log`. Production SETGLOBAL writes are exactly the three
owning global tables; fixture globals are intentional isolated engine stubs.
The five changed-file sweeps have no hits. Repository-wide hits are existing
comments or quoted strings/data (including the multiline resource manifest),
not unsupported syntax. No PUC runtime or broad suite was executed; the
coordinator owns any final interpreter evidence under the session's limits.

The quality armor pipeline now reads `grug_core.PROTECTION_ARMOR_MULTIPLIER` and
the shield's concrete `describe_stack_base` armor; the coordinator owns that
constant, dynamic gear armor and combined Protection calibration.

## User runtime checks after integration

At a profession station apply a T1 suffix to an unenchanted higher-tier item,
then add a different prefix. Confirm the exact displayed result, unchanged wear,
and single material debit. Replace one channel, try the identical replacement
and the opposite channel's stat, and confirm refusals preserve inputs. Enchant a
broken weapon and confirm it remains unusable until paid repair; the repaired
item must have the new enchant. Check all named operations in the book and use
a newly created level-one character's Bronze weapon before and after enchanting.
