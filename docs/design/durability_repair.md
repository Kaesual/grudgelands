# Durability and repair

Decided 2026-09-20. V1 uses copper-ledger repair for everyone. No material cost,
profession-matching requirement or repair skill is imposed. This is a bounded
WP22 delivery and does not rebase the WP44 economy or calibrate mining speeds.

## Eligible items and wear

Ordinary weapons, shields, spellbooks, four armor slots, gathering tools and
hoes are repairable. Trinkets, bags, quivers, ability tokens, mount skills,
consumables and decorative items neither wear nor enter repair quotes.

Combat equipment lasts **3000 qualifying events**, or **6000 when refined**.
One settled outgoing action wears the main hand and its spellbook once, even
when it hits multiple victims or creates multiple projectiles. It must cause
actual damage, effective in-combat healing or an effective in-combat shield
grant. Incoming armor and shield wear once per combat event that actually
lowers HP after dodge and absorb. Misses, canceled casts, complete absorption,
falls, drowning, death and out-of-combat healing do not spend combat durability.
Creative skips wear. Tools keep their own authored mining/hoeing use budgets.

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
stone fixed-stock prices; a wooden hoe uses the wooden tool price. Quality
multipliers are **1 / 3 / 6** for Common / Uncommon / Rare. Refined Common keeps
the Common price; its lifetime doubles instead. Above-ladder items use the T6
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
Commit the ledger payment and inventory restoration together. Preserve affixes,
refinement, cultural information and item identity. No partial repair-all,
duplication, stack destruction or unnoticed metadata replacement is allowed.

Material-based self repair and differentiated profession repair remain later
WP22 follow-up design; V1 does not anticipate them with extra rules.
