# Economy — Currency & Money Flow

Decided spec (established 2026-08-06; material and housing economy rebased
2026-08-12). Concrete item and service prices are catalogued in
`items_crafting.md` §8; this file owns the currency rules, shared price axis,
income relationship and sink structure.

The price axis in §2 is live since the WP44 cutover (Round 29 lane E1,
[economy plan](../planning/economy-vendor-plan.md) §2–§3): traders, loot and
gathered payouts, buy-back, the anti-loop audit and repair's price source
switched together. WP44 is a **lighter pass** (user decision 2026-09-29,
[WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29) D1):
price tables, buy-back, the audit fixes and a simple income estimate, without
a checksummed manifest or audit DAG. Quest copper rewards use the same ×2.5
axis (D2).

## 1. Currency: copper / silver / gold

- Base-100 chain: **100 copper = 1 silver, 100 silver = 1 gold**.
  Conversion is display-only; players hold one balance rather than separate
  denominations.
- **Storage is one integer in copper units** in player meta (1 = 1c,
  100 = 1s, 10000 = 1g). `PlayerMetaRef:set_int` is a genuine 32-bit signed
  store, so the balance is clamped at **2,147,483,647c ≈ 214,748g**. Every
  transaction uses the shared `grug_money` API; no consumer reads or writes
  the meta key directly.
- **Display rule:** leading zero units are omitted, copper is always shown and
  interior zeros are retained: `5c`, `1s 5c`, `1g 0s 5c`. One formatter owns
  Character-screen, chat and trade UI output. The current balance is shown
  on Character and relevant trade screens; there is no persistent money HUD.
- Money is a **ledger-only universal transaction currency**. No NPC, mob or
  world node drops money or a physical coin item. Currency enters or moves
  only through explicit transactions: quest rewards, NPC purchases of
  sellable loot, NPC/player sales and player-to-player trade.
- Physical Gold is a separate universal luxury/jewelry/build material. Gold
  ore, ingots and blocks never add to the money balance, and a ledger payment
  never consumes inventory Gold.
- The vendor floor moves with the player. Six Common gear catalogs cover
  levels 1–10 through 51–60; a player sees the current and all lower brackets.
  Fixed stock and ordinary rotations are Common and unenchanted. The sole
  exception is the expensive one-in-five rotating Uncommon defined in
  `items_crafting.md` §3.8; vendors never offer Rare or higher gear.

## 2. Ordinary price axis and buy-back

The money axis follows one approximate **×2.5 tier index**. The binding
Common weapon anchors are 25c at T1 and 25s at T6; clean displayed prices take
precedence over preserving the exact mathematical ratio.

| Common vendor slot | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 25c | 65c | 1s60c | 4s | 10s | 25s |
| Chest | 20c | 50c | 1s30c | 3s20c | 8s | 20s |
| Offhand/head/legs/feet | 15c | 35c | 80c | 2s | 5s | 12s50c |

- The table prices slots, not weapon families. Every ordinary weapon family in
  one tier uses the same Common reference price. Common gear is the plain,
  enchant-free baseline; quality and enchantment premiums are applied above
  it and may never redefine the table.
- **Vendor rule** ([professions.md](professions.md) §4): vendors sell
  supplies, consumables, tools, the Common gear floor and a few T1 basics,
  never an enchant input and never a crafting ingredient above T1.
- A vendor's **buy-back is capped at 5%** of the item's purchase price,
  **rounded up to the next copper**, and applies only to goods a vendor also
  sells (gear, supplies). Thus a T1 Common weapon returns 2c and a T6 Common
  weapon returns 1s25c. The same-race purchase discount never increases
  buy-back; a 1–2c supply (thread, torch, stick) is not sellable at all,
  because 5% rounded up would equal its discounted price. Sticks are crafted
  from free wood, so no mob drops them and fishing does not catch them.
- **Quality** (Round 33): a vendor buys a blue (Uncommon) item at **×3** and a
  gold (Rare) item at **×6** of its Common buy-back, per stack
  (`grug_traders.stack_sell_price`). An item without a Common buy-back
  (today shields, spellbooks and trinkets) sells for nothing at any quality.
- **Loot and gathered goods** pay one formula, `max(1, round(class value ×
  tier factor))`, with tier factors **1 / 2.6 / 6.4 / 16 / 40 / 100** (the
  weapon axis ÷ 25c) and the class values below, tuned once so the median kill
  of each band lands near 3c × the tier factor. The tier is the item's own:
  its catalogue tier, a mined resource's harvest tier, a plant's raw tier
  (`items_crafting.md` §3.7), a band fish's band. Every mob drop and every
  gathered plant, herb, ore, gem and band fish is sellable.

  | Class | T1 value | Members |
  |---|---:|---|
  | Trash / food | 1c | raw meat, bone, feather, linen scrap, stolen purse, war trophy, raw fish, apples, rotting flesh, papyrus |
  | Raw material | 1c | ore lumps, coal, quartz, gold, silver, emberglass, abyssal crystal, herbs, gathered plants, band fish, cultural materials |
  | Generic material | 2c | leathers, cloth, teeth, hides, silk and other `generic` catalogue loot |
  | Signature loot | 7c | every `signature` item of the loot catalogue |
  | Gem | 4c | rough gem; a cut gem pays the same as its rough gem |

- **Processed goods** (bars, leather grades, cloth bolts and bundles, jewellery
  settings, wood grades, reagents) pay the summed payout of their cheapest
  recipe's inputs; a vendor supply counts 0 in that sum. A leather grade that
  is also loot pays the lower of both.
- **Free world materials** (wood and logs, leaves, saplings, stone, cobble,
  sand, sandstone, gravel, clay, glass, snow, ice, flowers and dyes) are worth
  0 and count 0 in a recipe, so a vendor good made only from them (a wooden
  pick, a stone brick, a glass vial) pays nothing back. The load audit warns
  when a sold good keeps a buy-back only because none of its recipes can be
  judged.
- One price module (`grug_traders/prices.lua`) owns every payout; items have
  no per-definition price field. Anything it does not price is not sellable.
- A craft, cook, pack/unpack or service loop may not print money: an output
  pays **at most** the summed payout of its consumed inputs (break-even is
  allowed). The startup audit judges every engine, dual-furnace and
  profession-station recipe whose inputs are all priced, a `group:` input by
  its cheapest priced member. Goods a vendor sells are capped by their
  cheapest such recipe, so 100 arrows from one bar sell for nothing.

## 3. Income streams and tier pacing

- **Quest rewards** provide the baseline from the first starter quest.
- **Selling loot** provides the universal combat income. Traders buy every mob
  drop; humanoids are not a privileged money source. A stolen purse may exist
  as an ordinary sellable trash item, but opening or dropping it never changes
  the ledger directly.
- Gathered materials enter the same sell-price system. Player trade is their
  intended high-value market; NPC prices remain a floor.
- Ordinary quest income and the expected vendor value of level-appropriate
  mob/NPC loot grow on the same approximate ×2.5 tier index as Common gear.
  "Loot income scales" always means expected sellable-loot value, never direct
  coin drops. Scaling prices and ordinary income together preserves the
  intended time-to-buy for baseline gear.
- Reliable net solo income is measured after routine level-appropriate repair
  and consumable costs and excludes rare jackpots, boss rewards and a
  functioning player market. Time-priced aspirational sinks derive their
  ledger amount from that tier rate rather than from a stale global copper
  ratio; WP44 obtains the rate from a simple income estimate (D1),
  `tools/r29_e4/income.py`, recorded with its assumptions in the
  [economy plan](../planning/economy-vendor-plan.md#e4-completion-2026-10-02)
  (loot per kill after the Round 30 band-4/5 smoothing):

  | Bracket | 1–10 | 11–20 | 21–30 | 31–40 | 41–50 | 51–60 |
  |---|---:|---:|---:|---:|---:|---:|
  | Net solo income per hour | 1s77c | 4s35c | 9s18c | 24s39c | 68s66c | 1g46s68c |

## 4. Sinks

- Small/steady: vendor goods, job supplies, bags, potions and other ordinary
  consumables.
- **Repair:** broken gear is never destroyed; at zero durability its effects
  stop until repaired with ledger money at any city profession trainer, including
  Cooking. The V1 cost is `ceil(0.20 × reference purchase price × missing
  durability fraction)` per item, from the §2 purchase table; intact items are
  free. Anyone may repair any eligible item, with no profession or material
  requirement. Crafting stations inside an active Claim Stone claim offer the
  same repair at the same trader price, as a convenience (D7). The precise
  eligibility, price catalog, transaction and claim-station rules are in
  [durability_repair.md](durability_repair.md).
- **Talent respec:** repeatable **in the talent UI — there is no class
  trainer and no NPC** (user ruling 4 of 2026-09-16, `skill_trees.md` §5,
  `progression.md` §2). The price is **five minutes of measured reliable net
  solo income** at the character's own bracket, rounded by §4.1's rule
  (ruling 22), and **the first respec of a character is free**: **15c, 35c,
  75c, 2s, 6s and 12s** for the brackets 1–10 to 51–60
  (`grug_classes.RESPEC_PRICES`). This retires "repeatable at the class
  trainer, rising with level".
- **Profession-replacement services:** allied passive helper NPCs perform
  supplied-material cultural finishes, weapon-counter operations and Warding
  Draught crafts when the relevant player crafter is absent. They never create
  the supplied regional material. Cultural masters charge the fixed table
  below; the weapon helper charges the matching weapon entry; an Alchemist
  helper charges 50% of the draught's authoritative reference price. Ordinary
  same-race vendor discounts do not apply.

| Cultural-master service | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 15c | 35c | 80c | 2s | 5s | 12s50c |
| Chest | 10c | 25c | 65c | 1s60c | 4s | 10s |
| Offhand/head/legs/feet | 10c | 20c | 40c | 1s | 2s50c | 6s25c |

### 4.1 Income-derived price rounding; housing has no price

Every price derived from measured reliable net solo income (respec, mounts,
boats) rounds its copper result with the coarsest denomination in
`1s / 25c / 5c / 1c` whose nearest multiple stays within 5% of the target;
exact midpoints round upward.

Housing is not a money sink (Round 25, [housing.md](housing.md)). Private
housing isles, purchased depth rights, guild founding and every guild
bank/claim fee are retired. The one Claim Stone per player is free from the
Housing Steward at level 20; there are no tiers, upgrades, additional stones
or faction pools. Its only running cost is fuel: coal lumps or charcoal, one
lump per 7 h 16 min of protection; activation pays the first 5 lumps at once
(Round 26). A claim never grants private ore,
purchased mining depth or a material unavailable in the ordinary world.

### 4.2 Mount and boat prices

The level-15, level-30, level-45 and level-60 mounts cost approximately
**15 minutes, 45 minutes, 2 hours and 5 hours** of reliable net solo income at
their level's bracket (§3), rounded by §4.1. The Boat costs as much as
Apprentice Riding and the Improved Boat as much as Journeyman Riding
([boats.md](boats.md) §2). `grug_mounts.PRICES` holds them:

| Purchase | Level | Income time | Price |
|---|---:|---|---:|
| Apprentice Riding | 15 | 15 min | 1s10c |
| Journeyman Riding | 30 | 45 min | 7s |
| Expert Riding | 45 | 2 h | 1g37s |
| Master Riding | 60 | 5 h | 7g33s |
| Boat | 15 | as Apprentice | 1s10c |
| Improved Boat | 30 | as Journeyman | 7s |

This replaces the obsolete fixed 1s/8s/30s/60s table; the fast level-60
flying mount is a substantial but bounded farming goal.
