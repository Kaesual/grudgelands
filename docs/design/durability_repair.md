# Durability and repair

Decided 2026-09-20. V1 uses copper-ledger repair for everyone. No material cost,
profession-matching requirement or repair skill is imposed. This is a bounded
WP22 delivery and does not rebase the WP44 economy or calibrate mining speeds.

## Eligible items and wear

Ordinary weapons, shields, spellbooks, quivers, four armor slots, gathering
tools and hoes are repairable. Trinkets, bags, ability tokens, mount skills,
consumables and decorative items do not wear.

The material budgets and exact event rules are defined in
[the equipment revision](crafting_equipment_revision.md#equipment-and-lifetime).
Combat equipment has 1000/1500/2000/2500/3000/4000 qualifying uses across T1–T6.
Outgoing settled damage or effective in-combat healing wears only the main
weapon, once per action. Incoming settled nonlethal combat HP loss wears one
random intact item among the four armor slots and offhand. Pure absorb grants,
fully absorbed hits and Creative do not spend wear. Existing combat settlement
semantics remain; no extra fall/environmental wear hook is added.

Broken quivers keep their stored arrows retrievable, but do not supply automatic
ammunition or accept new arrows until repaired. Tool/hoe budgets are
30/60/300/600/1000/1500/2000/3000 from Wood through Abyssal Steel; mining depth
penalties remain separate.

At zero durability keep the concrete stack, name and all metadata. Disable
its base effects, affixes and operation until repaired. A broken bow cannot
shoot, a broken tool cannot dig/till; ordinary skills retain their existing
unarmed/baseline behavior. Equipment durability is separate from ability-token
cooldown/charge displays. Equipment changes use the shared equipment notifier;
no per-player wear polling loop is permitted.

## Providers and service

Every city profession trainer, including Cooking, repairs all eligible owned
equipment irrespective of the player's professions. Existing faction/service
access applies. Riding trainers are not profession trainers. No additional NPC
or trader distribution is introduced.

The service offers a preview and repair of one item or all eligible items in
equipment, main and bag inventories. Future Housing binds every crafting
station to the same service API. Housing itself and repair at arbitrary
wilderness stations are not included in this delivery.

## Price

For an item's missing durability fraction `w` and regular reference purchase
price `P` in copper:

```
repair_cost = ceil(0.20 * P * w)
```

Intact items cost zero. Repair-all sums individual rounded quotes and provides
no discount. Reference **purchase** price is never the buy-back/sale price or
an inferred price paid by the player. Do not introduce race discounts or
material costs.

Use the existing regular gear purchase catalog and fixed stock as authority
for sold items. Unsold weapons/tools use their matching material-tier weapon
reference; shields/books use that tier's other-slot reference. Keep wooden and
stone fixed-stock prices; wooden/stone hoes use their corresponding tool prices. Quality
multipliers are **1 / 3 / 6** for Common / Uncommon / Rare. Above-ladder items use the T6
slot reference and quality multiplier. Missing catalog identities fail the
catalog audit and service rather than receiving free repair.

Register and review the complete eligible-identity reference-price catalog
before implementing repair. This round retains the shipped purchase curve;
the full future economy curve in [economy.md](economy.md) remains WP44 work.
No buy-back, income, mount or Housing price rebase is implicit in repair.

## Transaction

At application time revalidate the provider's identity, distance and service
access, sufficient ledger funds, and every exact quoted stack and its wear.
A stale form or changed item aborts without debit or inventory mutation.
Commit the ledger payment and inventory restoration together. Preserve affixes, cultural information and item identity. No partial repair-all,
duplication, stack destruction or unnoticed metadata replacement is allowed.

Material-based self repair and differentiated profession repair remain later
WP22 follow-up design; V1 does not anticipate them with extra rules.
