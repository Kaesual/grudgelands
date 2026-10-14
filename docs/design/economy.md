# Economy — Currency & Money Flow

Decided spec (established 2026-08-06; material and housing economy rebased
2026-08-12). This file owns the currency rules, the shared price axis and
buy-back, the income relationship and the sinks with their prices
(`items_crafting.md` §8 only points here); the item numbers it uses (sale
values, repair math, the crown fee, culture prices) are printed in
[item_tiers.md](item_tiers.md) §4 and §6.

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
- Money is a **ledger-only universal transaction currency**. No NPC or
  world node drops money. Currency enters or moves only through explicit
  transactions: quest rewards, NPC purchases of sellable loot, NPC/player
  sales, player-to-player trade and the coin bags mobs drop (below).
- **Bag of Coins** (Round 34): the one way money leaves the balance as an
  item, so players can give money to each other. **Withdraw** in the
  Inventory tab's money row (the Character page until the Round 45
  playtest) opens a dialog with gold, silver and copper fields; a whole
  amount from 1c up to the balance is taken and one Bag of Coins holding it
  is put into the first empty slot in the give order (`main[9..]`, the
  bags, the hotbar last; [inventory_equipment.md](inventory_equipment.md)
  §3) in one transaction (`grug_money.take_with_inventory`), refused when
  the whole inventory is full. The **deposit slot** on the Inventory tab
  (Round 44) takes only a filled bag, destroys it
  and credits its amount, refused if the balance would exceed the clamp
  above. One bag per stack, the amount in its item meta and tooltip. Traders
  neither sell nor buy it (no price class: payout 0). It drops, is picked up
  and stored like any item, despawns on the ground after the engine's item
  lifetime and burns in lava or fire; no transfer is logged.
- **Coin bags from mobs** (Round 46 ruling 12): the 23 sell-only mob drops
  (signatures and generics no recipe or quest uses) no longer drop; they
  stay registered and sellable. Instead every looted kill (the loot gate of
  [combat_stats.md](combat_stats.md) §3: a player tag, no faction NPC, no
  critter, no mob flagged `_grug_no_coin_bag` such as the Kraken) drops a
  Bag of Coins 1 time in 8, holding a whole amount from half to one and a
  half times its level band's mean: 4c, 10c, 26c, 64c, 1s 60c, 4s for bands
  1–6 (4 × the tier factor), so a kill pays half a tier factor of copper on
  average, about the mean the removed rows paid (`grug_mobs.COIN_BAG`,
  `tools/r29_e4/income.py` LOOT_PER_KILL).
- **Automatic deposit** (Round 46, the user): the Inventory tab's money row
  has a checkbox "Auto" (tooltip "Deposit coin bags automatically on
  pickup"), on by default (player meta `grug_money:auto_deposit` is "off"
  only when unticked). While it is on, picking up a Bag of Coins credits it
  at once under the deposit slot's rules, with one feed line "Deposited
  Xc."; a bag the slot would refuse (empty, or over the clamp) is picked up
  as an item with the usual pickup line.
- Physical Gold is a separate universal luxury/jewelry/build material. Gold
  ore, bars and blocks never add to the money balance, and a ledger payment
  never consumes inventory Gold.
- Vendors sell the T1 Common bases only (Round 33): every weapon family and
  armour piece of the first material tier, Common and unenchanted, at every
  level. From T2 the bases come from profession crafting (Round 45) or drops; there is no
  rotation and no vendor Uncommon (`items_crafting.md` §3.8).

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
  never an enchant input (a signature loot item or family input of
  `enchants.json`; a T1 own material such as the Bronze Bar may be sold) and
  never a crafting ingredient above T1.
- A vendor's **buy-back is capped at 5%** of the item's purchase price,
  **rounded up to the next copper**, and applies to goods a vendor also
  sells (gear, supplies) and to every equippable of the gear catalog by the
  reference price of its slot and tier (T2+ bases, shields, spellbooks and
  trinkets in the "other" slot; Round 33, [item_tiers.md](item_tiers.md) §6.1). Thus a T1 Common weapon returns 2c and a T6 Common
  weapon returns 1s25c. The same-race purchase discount never increases
  buy-back; a 1–2c supply (thread, torch, stick) is not sellable at all,
  because 5% rounded up would equal its discounted price. Sticks are crafted
  from free wood, so no mob drops them and fishing does not catch them.
- **Quality** (Round 33): a vendor buys a blue (Uncommon) item at **×3** and a
  gold (Rare) item at **×6** of its Common buy-back, per stack
  (`grug_traders.stack_sell_price`); item level 61+ sells as T6.
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
  | Raw material | 1c | ore lumps, coal, quartz, gold, silver, emberglass, abyssal crystal, herbs, gathered plants, band fish |
  | Generic material | 2c | leathers, cloth, teeth, hides, silk and other `generic` catalogue loot |
  | Signature loot | 7c | every `signature` item of the loot catalogue |
  | Gem | 4c | rough gem; a cut gem pays the same as its rough gem |

- **Processed goods** (bars, leather grades, cloth bolts and bundles, jewellery
  settings, wood grades) pay the summed payout of their cheapest
  recipe's inputs; a vendor supply counts 0 in that sum. A leather grade that
  is also loot pays the lower of both.
- **Free world materials** (wood and logs, leaves, saplings, stone, cobble,
  sand, sandstone, gravel, clay, glass, snow, ice, flowers and dyes) are worth
  0 and count 0 in a recipe **of the rules above**, so a vendor good made
  only from them (a wooden pick, a stone brick, a glass vial) pays nothing
  back. The load audit warns when a sold good keeps a buy-back only because
  none of its recipes can be judged.
- One price module (`grug_traders/prices.lua`) owns every payout; items have
  no per-definition price field.

**Selling almost everything** (Round 48,
[sell plan](../planning/sell-fuel-daytime-plan.md) §3.2–§3.5 under
[round48-plan.md](../planning/round48-plan.md) ruling 2.2). The rules above
run unchanged as a **first pass** in whole copper and give every item that
paid before exactly its old payout. A **second pass** then prices only the
items without one:

- **Values in milli-copper** (mc, 1c = 1000 mc): integers, no fractions;
  recipe values divide with `floor`, so rounding only ever lowers a value.
  An item the first pass pays counts its payout × 1000.
- **Lots:** the vendor pays for the smallest lot of **1, 2, 5, 10, 20, 50,
  99** whose value reaches 1c, `floor(value × lot / 1000)` copper. A value
  of 1c or more sells singly as before (3500 mc pays 3c each); less than 1c
  per 99 (the stack size) is not sellable.
- **The bulk table** (explicit, so no rule detects conversions):

  | Material | Value | Sells as |
  |---|---:|---|
  | Cobblestone, Mossy and Desert Cobblestone, Granite, Basalt, Slate; Stone, Desert Stone and their bricks and blocks | 20 mc | 1c per 50 |
  | Sand, Desert Sand, Silver Sand, Gravel | 20 mc | 1c per 50 |
  | Leaves (`group:leaves`), saplings (`group:sapling`) | 20 mc | 1c per 50 |
  | Sandstone, Desert and Silver Sandstone and their bricks and blocks | 80 mc (four sand) | 1c per 20 |
  | Logs (`group:tree`) and Cactus | 50 mc | 1c per 20 |
  | Planks (`group:wood`) | 12 mc (a quarter log, rounded down) | 1c per 99 |

  Sandstone is exactly four sand, because the recipes run both ways. The
  table wins over the vendor rule: the Mason's Cobblestone, Gravel and
  bricks sell in these lots too (always below their shelf price).
- **Crafted goods** (no class, sold by no vendor, not gear: potions,
  dishes, seeds, tools, bags, stations, furniture, stairs ...) pay **half**
  the material value of their cheapest recipe, without exceptions. The
  halving is one last step: a later recipe counts a crafted input at its
  material value before the halving, so a potion made from a mixture is not
  halved twice. Tools need no rule of their own; halved they stay below the
  gear buy-back of their tier. Wear is ignored, as for gear.
- **Storage blocks** pay **nine times** their item's payout, because
  unpacking is free: the twelve pack/unpack rows of `grug_smelting` (the
  metal blocks, Emberglass and Abyssal Crystal) and every other block that
  nine of one item make and that gives the nine back (Coal Block, the
  cut-gem blocks, the meat blocks).
- **Vendor goods and gear** keep the first pass: the 5 % buy-back, and a
  1–2c supply (thread, torch, stick) stays unsellable.
- **Never sellable:** the Bag of Coins, the Fallen Crown, both Captain's
  Orders, soulbound and bound items (`grug_soulbound`, `grug_bound_skill`:
  the Claim Stone, ability items, the retired mount and boat items); and,
  having no value, dirt and the soils, clay, snow, ice, ground cover,
  flowers and dyes, obsidian, and anything no player can hold (growth
  stages, door halves, liquids, mapgen nodes).
- A craft, cook, pack/unpack or service loop may not print money: an output
  pays **at most** the summed value of its consumed inputs (break-even is
  allowed). The startup audit judges every engine, dual-furnace and
  profession-station recipe whose inputs are all priced, over the combined
  table of both passes in milli-copper, a `group:` input by its cheapest
  priced member, and a consumed crafted good at its material value before
  the halving (two slabs back into a block, or a block back into its nine
  gems, gain nothing a player did not put in). Goods a vendor sells are
  capped by their cheapest such recipe, so 100 arrows from one bar sell for
  nothing.

**The sell window** (the trader's Sell tab):

- It lists what the player carries in `main` and the bags
  (`grug_inventory.carried_lists`). A good that sells singly keeps one row
  per slot with **1** and **All**, at its quality factor. A **lot good** gets
  **one row per item name**, its count summed over every carried list
  (30 + 30 Cobblestone make a lot of 50), e.g. `Cobblestone x143` ·
  `1c per 50` · **All (2c)**. Lot goods carry no quality, so nothing is lost
  by merging.
- Below its lot size the row is greyed with `Need 50 to sell` and has no
  button, so the player learns that the item sells in lots.
- **All** sells as many whole lots as the player carries and leaves the
  rest: `Sold 100 Cobblestone for 2c. 43 left.` The units are taken with the
  engine's `remove_item`, list by list, only after every check has passed.
- Security as for every trade action: the row is recomputed server-side on
  every click and cross-checked against the one shown (item, lot, copper,
  total count); a mismatch re-renders without selling. A sale that would
  cross the money ceiling is refused before anything is removed.
- The hint line reads: "The vendor buys most things you carry. Cheap goods
  sell in lots, e.g. 1c per 50; the rest stays with you."

## 3. Income streams and tier pacing

- **Quest rewards** provide the baseline from the first starter quest.
- **Selling loot** provides the universal combat income, with the coin bags
  of §1 (Round 46) in place of the removed sell-only drops. Traders buy every
  mob drop; humanoids are not a privileged money source. A stolen purse may exist
  as an ordinary sellable trash item, but opening or dropping it never changes
  the ledger directly.
- Gathered materials enter the same sell-price system. Player trade is their
  intended high-value market; NPC prices remain a floor.
- Ordinary quest income and the expected vendor value of level-appropriate
  mob/NPC loot grow on the same approximate ×2.5 tier index as Common gear.
  "Loot income scales" means expected sellable-loot value plus the coin
  bags' expected copper (half a tier factor per kill). Scaling prices and ordinary income together preserves the
  intended time-to-buy for baseline gear.
- Reliable net solo income is measured after routine level-appropriate repair
  and consumable costs and excludes rare jackpots, boss rewards and a
  functioning player market. Time-priced aspirational sinks derive their
  ledger amount from that tier rate rather than from a stale global copper
  ratio; WP44 obtains the rate from a simple income estimate (D1),
  `tools/r29_e4/income.py`, recorded with its assumptions in the
  [economy plan](../planning/economy-vendor-plan.md#e4-completion-2026-10-02)
  (loot per kill after the Round 30 band-4/5 smoothing; quest copper of the
  shipped quests, Round 36's main line included):

  | Bracket | 1–10 | 11–20 | 21–30 | 31–40 | 41–50 | 51–60 |
  |---|---:|---:|---:|---:|---:|---:|
  | Net solo income per hour | 1s72c | 4s28c | 9s11c | 24s40c | 64s48c | 1g47s64c |

  Since Round 33 the estimate also counts every normal kill's gear drop sold
  (white 5 % / blue 2 % / gold 1 % at ×1 / ×3 / ×6, an upper bound) and repair
  at factor 1.00 ([item_tiers.md](item_tiers.md) §6.5); `income.py` prints
  the change per band (−3.1 % at 1–10 to +1.5 % at 51–60). The table above
  is the estimate with those terms; the prices below come from it.

  Round 46: with the coin bags and the 1/1 cloth (rulings 11, 12) and the
  round's other changes, the estimate is 1s96c / 4s39c / 10s38c / 25s75c /
  69s78c / 1g67s23c per hour (+14 %, +3 %, +14 %, +6 %, +8 %, +13 % over the
  table above): the measured median kill barely felt the removed rows, the
  bags pay their mean. The prices stay; `income.py
  --check` accepts a shipped price within 20 % of the estimate's.

## 4. Sinks

- Small/steady: vendor goods, job supplies, bags, potions and other ordinary
  consumables.
- **Repair:** broken gear is never destroyed; at zero durability its effects
  stop until repaired with ledger money at any town profession trainer or at
  Grudge-Free Repairs (the former Cooking trainer socket). The cost is `ceil(1.00 × reference purchase price × missing
  durability fraction)` per item (Round 33: wearing an item out once costs
  its price), from the §2 purchase table; intact items are
  free. Anyone may repair any eligible item, with no profession or material
  requirement. Repair happens only in towns (Round 46 ruling 16): the
  claim-station repair (D7) is removed. The precise eligibility, price
  catalog and transaction rules are in
  [durability_repair.md](durability_repair.md).
- **Talent respec:** repeatable **in the talent UI — there is no class
  trainer and no NPC** (user ruling 4 of 2026-09-16, `skill_trees.md` §5,
  `progression.md` §2). The price is **five minutes of measured reliable net
  solo income** at the character's own bracket, rounded by §4.1's rule
  (ruling 22), and **the first respec of a character is free**: **15c, 35c,
  75c, 2s, 5s50c and 12s** for the brackets 1–10 to 51–60
  (`grug_classes.RESPEC_PRICES`). This retires "repeatable at the class
  trainer, rising with level".
- **The crown** (Round 33, [item_tiers.md](item_tiers.md) §4): the
  Crownbinder at the gate of every capital's goldsmith hall applies one Fallen Crown to one item for one
  hour of band-6 income, **1g 48s** (`grug_traders.CROWN_FEE`, checked by
  `income.py`). Once per item; the operation refuses where it would change
  nothing.
- **Culture vendor** (Round 33, [item_tiers.md](item_tiers.md) §6.4): the
  Decor Merchant at the gate of every capital's woodcarver hall sells
  cosmetic blocks and lights nobody can craft — accent blocks 25c (marble,
  marble tile, serpentine, slate tile, old red sandstone brick, basalt brick,
  chalked brick, paving stone, round and square glass, wooden frame, iron
  grille), small lights 1s (lantern), large lights 10s (hanging lantern),
  showpieces 1g (wagon wheel, four paintings) — at every level, with the
  ordinary 5 % buy-back. All are grug_decor's harvested kit, licensed per
  file in its `LICENSE-media.md`.
- **Postage** (Round 48, [mail.md](mail.md)): **5c** per letter to another
  player plus **30c per attached stack**, up to four stacks (35c, 65c, 95c,
  125c); mail to the admin is free. A small, steady sink at the mailboxes;
  `tools/r29_e4/income.py` does not check it.
- **No profession-replacement services:** cultural finishes, the PvP weapon
  counter and the Warding Draught were removed (Round 33), and with them the
  cultural masters and helper NPCs that would have performed them.

### 4.1 Income-derived price rounding; housing has no price

Every price derived from measured reliable net solo income (respec, mounts,
boats, the crown fee) rounds its copper result with the coarsest denomination in
`1s / 25c / 5c / 1c` whose nearest multiple stays within 5% of the target;
exact midpoints round upward.

Housing is not a money sink (Round 25, [housing.md](housing.md)). Private
housing isles, purchased depth rights, guild founding and every guild
bank/claim fee are retired. The one Claim Stone per player is free from the
Housing Steward at level 20; there are no tiers, upgrades, additional stones
or faction pools. Its only running cost is fuel: coal lumps or charcoal, one
lump per 7 h 16 min of protection, or Anthracite at 1.5 lumps; activation pays the first 5 lumps at once
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
| Expert Riding | 45 | 2 h | 1g29s |
| Master Riding | 60 | 5 h | 7g38s |
| Boat | 15 | as Apprentice | 1s10c |
| Improved Boat | 30 | as Journeyman | 7s |

This replaces the obsolete fixed 1s/8s/30s/60s table; the fast level-60
flying mount is a substantial but bounded farming goal.
