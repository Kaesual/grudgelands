# Economy — Currency & Money Flow

Decided spec (established 2026-08-06; material and housing economy rebased
2026-08-12). Concrete item and service prices are catalogued in
`items_crafting.md` §8; this file owns the currency rules, shared price axis,
income relationship and sink structure.

The price axis in §2 is the approved **WP44 target**. It is not a claim about
the current trader bytes: until WP44 lands, the shipped six-bracket Common
weapon prices are 50c/70c/98c/1s37c/1s92c/2s69c and buy-back is 25% rounded
down (minimum 1c). Round-11 repair deliberately quotes from that current
purchase catalog. WP44 must switch traders, reference prices, buy-back,
anti-loop audits and repair's price source together.

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

The WP44 target money axis follows one approximate **×2.5 tier index**. The
binding Common weapon anchors are 25c at T1 and 25s at T6; clean displayed
prices take precedence over preserving the exact mathematical ratio.

| Common vendor slot | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 25c | 65c | 1s60c | 4s | 10s | 25s |
| Chest | 20c | 50c | 1s30c | 3s20c | 8s | 20s |
| Offhand/head/legs/feet | 15c | 35c | 80c | 2s | 5s | 12s50c |

- The table prices slots, not weapon families. Every ordinary weapon family in
  one tier uses the same Common reference price. Common gear is the plain,
  enchant-free baseline; quality and enchantment premiums are applied above
  it and may never redefine the table.
- A vendor's **buy-back is capped at 5%** of the item's applicable purchase or
  authoritative reference price, **rounded up to the next copper**. Thus a T1
  Common weapon returns 2c and a T6 Common weapon returns 1s25c. The same-race
  purchase discount never increases buy-back.
- Items a vendor never sells still receive an authoritative **reference
  price** in the economy catalog. `_grug_sell_price` stores the resulting
  vendor payout (never more than the 5%-ceiling rule), while
  `grug_traders.set_price` supplies that payout for foreign definitions. Zero
  means not sellable. Every mob drop has a positive payout so selling loot
  remains a universal income stream; "paid in full" means the trader pays that
  authored `_grug_sell_price`, not 100% of the item's reference value.
- A craft, cook, pack/unpack or service loop may not print money. The vendor
  value of an output must stay below the summed vendor value of consumed
  inputs after every discount and rounding rule. Reversible storage recipes
  preserve one shared reference-value budget in both directions.

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
  ledger amount from that measured tier rate rather than from a stale global
  copper ratio.

## 4. Sinks

- Small/steady: vendor goods, job supplies, bags, potions and other ordinary
  consumables.
- **Repair:** broken gear is never destroyed; at zero durability its effects
  stop until repaired with ledger money at any city profession trainer, including
  Cooking. The V1 cost is `ceil(0.20 × reference purchase price × missing
  durability fraction)` per item; intact items are free. Anyone may repair any
  eligible item, with no profession or material requirement. The precise
  eligibility, current-price catalog, transaction and future Housing-station
  rules are in [durability_repair.md](durability_repair.md). This bounded Round-11
  service retains the shipped purchase curve until WP44 rebases it; it does not
  deploy the full target price axis below/above by implication.
- **Talent respec:** repeatable **in the talent UI — there is no class
  trainer and no NPC** (user ruling 4 of 2026-09-16, `skill_trees.md` §5,
  `progression.md` §2). The price is **five minutes of measured reliable net
  solo income** at the character's own bracket, rounded by §4.1's rule
  (ruling 22), and **the first respec of a character is free**. This retires
  "repeatable at the class trainer, rising with level".
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

### 4.1 Housing claims — the long-term per-character sink

Private housing isles, purchased depth rights, guild founding and every guild
bank/claim fee are retired. Permanent player protection comes from open-world
Claim Stones in the ten eligible level-11–30 housing zones. The authoritative
claim tiers, issuance, lifecycle and capacity contract is
[housing.md](housing.md).

- The first owner-bound Claim Stone is free after the level-20 Housing Steward
  introduction. A claim never grants private ore, purchased mining depth or a
  material unavailable in the ordinary world.
- Each placed stone upgrades sequentially. Every upgrade consumes the listed
  universal metal plus a ledger amount derived from reliable net solo income:

  | Upgrade | Level | Material | Money target |
  |---|---:|---:|---:|
  | Tier I → II | 35 | 4 Silversteel Bars | 30 minutes of T4 income |
  | Tier II → III | 50 | 8 Embersteel Bars | 90 minutes of T5 income |
  | Tier III → IV | 60 | 12 Abyssal Steel Bars | 3 hours of T6 income |

  The measured copper result is rounded with the coarsest denomination in
  `1s / 25c / 5c / 1c` whose nearest multiple stays within 5% of the target;
  exact midpoints round upward.
- When server settings allow more than one stone, a second or third may be
  issued only at level 60 after every existing stone reaches tier IV. The
  second costs 12 Abyssal Steel Bars plus five hours of reliable T6 income;
  the third costs 24 bars plus ten hours. No available faction slot means the
  transaction consumes nothing.
- Claims and upgrades consume no gem, cultural material, foreign-faction
  material or profession-exclusive component. They remain separate from the
  regional gear economy.

### 4.2 Mount pacing

Mount prices are derived after tier income is measured. The level-15,
level-30, level-45 and level-60 mounts target approximately **15 minutes,
45 minutes, 2 hours and 5 hours** of reliable level-appropriate net solo
income respectively. This replaces the obsolete fixed 1s/8s/30s/60s table;
the fast level-60 flying mount is a substantial but bounded farming goal.
