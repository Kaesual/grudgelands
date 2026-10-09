# Durability and repair

Decided 2026-09-20. V1 uses copper-ledger repair for everyone. No material cost,
profession-matching requirement or repair skill is imposed. Since the WP44
cutover (Round 29) quotes use the Common price axis of
[economy.md](economy.md) §2.

## Eligible items and wear

Ordinary weapons, shields, spellbooks, four armor slots, gathering
tools and hoes are repairable. Trinkets, bags, ability tokens, mount skills,
consumables and decorative items do not wear.

This file owns the material budgets and the exact wear events (tools and
weapons are disjoint, [items_crafting.md](items_crafting.md) §3.0.3–§3.0.4).
Combat equipment has 1000/1500/2000/2500/3000/4000 qualifying uses across T1–T6.
Outgoing settled damage or effective in-combat healing wears only the slot
that acted, once per action: a synchronous swing or cast wears the melee slot
(the Scout's Melee offhand, everyone else's Weapon slot), a Scout's shot the
bow it was loosed from (Round 28). Incoming settled nonlethal combat HP loss
wears one random intact item among the four armor slots and an offhand shield
or spellbook (never a weapon carried in the offhand). Pure absorb grants,
fully absorbed hits and Creative do not spend wear. Existing combat settlement
semantics remain; no extra fall/environmental wear hook is added.

Tool/hoe budgets are
30/60/300/600/1000/1500/2000/3000 from Wood through Abyssal Steel. There is
no mining depth penalty: a pick too weak for a tier rock cannot dig it at all
(Round 24 ruling 3).

At zero durability keep the concrete stack, name and all metadata. Disable
its base effects, affixes and operation until repaired. A broken bow cannot
shoot, a broken tool cannot dig/till; ordinary skills retain their existing
unarmed/baseline behavior. Equipment durability is separate from ability-token
cooldown/charge displays. Equipment changes use the shared equipment notifier;
no per-player wear polling loop is permitted.

## Providers and service

Every city profession trainer repairs all eligible owned equipment
irrespective of the player's professions (the former Cooking trainers are
ordinary residents since Round 45 and repair nothing). Existing faction/service
access applies. Riding trainers are not profession trainers. No additional NPC
or trader distribution is introduced.

The service offers a preview and repair of one item or all eligible items in
equipment, main and bag inventories. Every player-placed furnace and dual
furnace (the stations with a window since Round 45; the forge, the benches
and the brewing stand have none)
inside an active (activated and fuelled) Claim Stone claim offers the same
service at the same trader price, as a convenience only (user decision
2026-09-29, [WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
D7): its window shows a "Repair equipment" button to anyone who may use the
station there (a claim's interact permission is enough). Repair at wilderness
stations outside a claim, in a draft or an expired claim is not offered.

## Price

For an item's missing durability fraction `w` and regular reference purchase
price `P` in copper:

```
repair_cost = ceil(1.00 * P * w)
```

The factor is `grug_repair.FACTOR`; it rose from 0.20 to 1.00 in Round 33
([item_tiers.md](item_tiers.md) §6.2): wearing an item out once costs what
buying it again would.

Intact items cost zero. Repair-all sums individual rounded quotes and provides
no discount. Reference **purchase** price is never the buy-back/sale price or
an inferred price paid by the player. Do not introduce race discounts or
material costs.

Use the regular gear purchase catalog (the Common slot table of economy.md
§2) and fixed stock as authority for sold items. Unsold weapons/tools use their matching material-tier weapon
reference; shields/books use that tier's other-slot reference. Keep wooden and
stone fixed-stock prices; wooden/stone hoes use their corresponding tool prices. Quality
multipliers are **1 / 3 / 6** for Common / Uncommon / Rare. Above-ladder items use the T6
slot reference and quality multiplier. Missing catalog identities fail the
catalog audit and service rather than receiving free repair.

Repair never changes buy-back, income, mount or Housing prices.

## Transaction

At application time revalidate the provider's identity, distance and service
access, sufficient ledger funds, and every exact quoted stack and its wear.
A stale form or changed item aborts without debit or inventory mutation.
Commit the ledger payment and inventory restoration together. Preserve affixes and item identity. No partial repair-all,
duplication, stack destruction or unnoticed metadata replacement is allowed.

Material-based self repair and differentiated profession repair are possible
future design topics, not approved WP22 behavior. V1 does not anticipate them
with extra rules or hidden profession benefits.

## Wear presentation

Tooltips show whole remaining durability against the authoritative item lifetime,
including the fractional wear remainder, rounded upward. Each use rewrites only
that line; it is no equipment change for stats, looks or the Character page.
The use that breaks the item, a repair and a swap are (Round 37). Native wear bars are
available for armor and offhands as well as weapons and tools. Skill items show
no wear bar: their cooldowns and charges are the hotbar overlay
([classes.md](classes.md) §2b), not equipment durability.

A broken item retains its model and is drawn broken in inventory,
first-person and third-person presentation, including the weapon a held skill
shows: drained of colour, darkened and cracked (Round 35; one modifier,
`grug_gear.broken_image`). Only the affected worn armor layer is drawn broken. Cosmetic equipment reads include broken items; combat/stat reads
still reject them. Repair restores the current base or enchanted appearance;
it does not remove or reroll enchantments.
