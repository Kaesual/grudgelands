# Partial plan — selling (almost) everything, leaf and cactus fuel, the daytime band, smaller bags

> **Built in Round 48** (0.48.0, 2026-10-14;
> [completion](round48-plan.md#completion-2026-10-14)). The round plan's §2
> rulings and §3 interfaces override this file where they differ.

Status: **partial plan for Round 48**, built in Round 48 (see above). The user approved
the concept in chat on 2026-10-14; a coordinator folds this file into the
round plan together with the [mail plan](mail-plan.md) and the [plant growth
plan](plant-growth-plan.md). Rulings in §2 are the user's; §3 lists the
defaults this draft chose, which the lanes build unless the user overrides
them. File facts are against main `6a8afb9f`. The numbers in §1 come from a
disposable census probe (a headless boot listing every registered item with
its payout, recipes, fuel time and dig times; scratchpad only, not in the
repo).

## 1. Goals and reasons

**Fuel.** Leaves and cactus should burn in furnaces: cactus about as well as
wood, leaves briefly. The vendored `default` already registers both as
engine fuel (leaves 4 s, cactus 15 s), but our furnaces ask only
`automatic.fuel_time` (`grug_jobs/automatic.lua:13-24`): logs 15 s, Coal and
Charcoal 80 s, Anthracite 120 s, nothing else
([items_crafting.md](../design/items_crafting.md) §3.0.2, "Round 21 furnace
rules").

**Selling.** Players should be able to sell nearly everything they carry,
cheap goods in lots ("1c per 50 Cobblestone"; 49 cannot be sold). Today 393
of 1571 registered items have a payout. Most of the other 1178 are never in
an inventory (growth stages, door halves, mapgen nodes), but these are
unsellable too, although a player expects to sell them: all 80 potions and
elixirs, 30 dishes, tools from Iron up, bags, metal and gem storage blocks,
seeds, stations, and every building material (`FREE_GROUPS`,
`grug_traders/prices.lua:62-74`, worth 0 by design,
[economy.md](../design/economy.md) §2 "Free world materials").

Measured dig times (engine `get_dig_params`): every tier stone drops
`default:cobble`; one takes 0.45 s with the Bronze pick, 0.20 s with Steel;
sand 0.22 s with the Bronze shovel; a log 0.85 s with the Bronze axe. The
user's ruling (§2.3) accepts that bulk goods pay a noticeable share of a
level-1–10 income: levelling still pays more, and from level 11 on bulk
income is negligible.

**Daytime.** A small box near the minimap shows roughly where the day
stands: a band of day and night sections at their real lengths scrolling
through a window, no clock. A world day is 20 minutes: 15 minutes day phase
(04:30–19:30) and 5 minutes night (`grug_core.DAY_PHASE_START/END`,
`DAY_TIME_SPEED`, `NIGHT_TIME_SPEED`, `grug_core/atmosphere.lua:59-72`). The
same edges drive the night mobs' spawn clock, so the band also says when
night mobs come.

**Bags.** Four bag slots with bags of 8 / 16 / 24 / 32 slots add up to 128
slots on top of the base 32 (`grug_inventory/bags.lua:42-75`,
[inventory_equipment.md](../design/inventory_equipment.md) §3): too generous.
The join callback sizes each bag's content list from its bag
(`bags.lua:346-355`), and `set_size` truncates, so shrinking the bags
without a migration would silently destroy items in the cut slots.

## 2. Rulings (user, 2026-10-14)

1. **Cactus and leaves burn** in both furnaces; cactus about like wood,
   leaves short.
2. **Almost everything is sellable**, with common sense: not every item has
   to be (the user, chat). Items that pay today **keep their exact
   payout**; only items without a payout get one.
3. **Lots:** cheap goods sell per lot, and the sell window must make that
   clear. **Sand, gravel, stone, leaves and saplings: 1c per 50 each.**
4. **Crafted goods sell below their material value** (a discount; the
   amount is a default, §3.3).
5. **The daytime band** sits in a box near the minimap, like the mail
   icon; day and night sections at their real lengths, sun and moon on
   them. It moves **from right to left** (what comes next enters from the
   right). It is updated about every **30 seconds**; it is not a clock. It
   **stays visible with the minimap hidden**, like the mail icon.
6. **Simplifications (user, chat):** integer values instead of fractions,
   an explicit bulk table instead of conversion detection, a discount
   without exceptions, no tool rule, a one-time price comparison instead of
   a permanent golden-list fixture, one "All" button for lot goods with the
   engine's `remove_item`, forty finished band images instead of texture
   modifiers (§3.2–§3.6, §6).
7. **Every bag shrinks to half:** 4 / 8 / 12 / 16 slots (cloth and leather
   alike); four of the largest add 64 slots, 96 in all.
8. **Existing characters:** their inventory is **sorted once**; what no
   longer fits **arrives in their mailbox** (letters of four stacks each;
   at most 16 letters, which always fit: system letters are delivered
   beyond the limit, and nobody has letters yet at the update).
9. Half-empty rows in the inventory grid (a 4- or 12-slot bag) are
   accepted. *(Superseded by the user's play test: the slots flow on in
   8-wide rows, Round 48 fix lane INV.)*
10. **The vendor's Small Bag costs 20c** (today 80c).

## 3. Defaults chosen by this draft

The user may overrule any of these; the lanes build them otherwise.

### 3.1 Fuel

1. **Cactus 15 s** (as a log), **every node of `group:leaves` 2 s** (five
   leaves per 10-second smelt). Both furnaces, through `automatic.fuel_time`.
2. Claim Stone upkeep is unchanged (coal, charcoal, Anthracite only;
   [housing.md](../design/housing.md)).
3. Saplings and papyrus stay non-fuel in our furnaces.

### 3.2 Bulk values and lots

Every value is an **integer in thousandths of a copper** ("milli-copper",
mc; 1c = 1000 mc): no fractions anywhere. Recipe values divide with
`floor`, so rounding only ever lowers a value and can never open a money
loop. What the vendor pays is a **lot**: the smallest size in **1, 2, 5,
10, 20, 50, 99** whose value reaches 1c, paying `floor(value × lot / 1000)`
copper. An item worth 1c or more sells singly as today (a value of 3500 mc
pays 3c each). An item worth less than 1c per 99 is not sellable (99 is the
stack size).

The bulk table is explicit and complete: it names the raw bulk materials
**and** the plain building conversions made from them, so no rule has to
detect conversions in the recipe graph (the first three rows are ruling 3):

| Material | Value | Sells as |
|---|---:|---|
| Cobblestone, Mossy and Desert Cobblestone, Granite, Basalt, Slate; Stone, Desert Stone and their bricks and blocks | 20 mc | 1c per 50 |
| Sand, Desert Sand, Silver Sand, Gravel | 20 mc | 1c per 50 |
| Leaves (`group:leaves`), saplings (`group:sapling`) | 20 mc | 1c per 50 |
| Sandstone, Desert and Silver Sandstone and their bricks and blocks | 80 mc (four sand) | 1c per 20 |
| Logs (`group:tree`, the items a player holds) and Cactus | 50 mc | 1c per 20 |
| Planks (`group:wood`) | 12 mc (a quarter log, rounded down) | 1c per 99 |

- **Sandstone is worth exactly four sand:** the recipes run both ways
  (4 sand → 1 sandstone → 4 sand), so any other value would let a player
  gain by converting.
- **Logs at 50 mc** (this draft): a log is worth 2.5 leaves; the user named
  no value for logs.
- Stairs, slabs and walls are not in the table; they are crafted goods
  (§3.3) and fall below 1c per 99.
- **Dirt** and the soils, mud, clay, snow and ice stay unsellable: the
  ruling names sand, gravel, stone, leaves and saplings only.

### 3.3 Crafted goods

1. An item with **no class, not sold by any vendor and not gear** gets the
   **material value** of its cheapest recipe (the summed values of its
   inputs per output unit, a group input by its cheapest member, as
   `price_rules.resolve` does today for processed goods).
2. It **pays half its material value** (ruling 4; the factor ½ is this
   draft's default), **without exceptions**. The resolver computes material
   values exactly as today, and the halving is one last step over the
   crafted items: later recipes count the undiscounted material value, so a
   potion made from a mixture is not halved twice. There is no second value
   track.
3. **Storage blocks** (the twelve pack/unpack rows of `grug_smelting`) are
   not crafted goods: they pay nine times their contents' payout, read from
   that storage table, because unpacking is free.
4. **Tools need no rule of their own:** halved, they stay below the gear
   buy-back of their tier (Steel pickaxe 6c against a T3 weapon's 8c,
   Abyssal Steel 99c against 1s 25c). Wear is ignored, as for gear.
5. Vendor goods keep today's rule: 5 % buy-back capped by the recipe, and a
   1–2c supply (thread, torch, stick) is not sellable.

Examples from the prototype (½ factor; final numbers come from the lane's
resolver):

| Item | Today | New |
|---|---|---|
| Carrot Seeds (Carrot 1c, 1 → 2 seeds) | — | 1c per 5 |
| Healing Potion I / VI | — | 1c / 70c |
| Elixir of Vigor VI | — | 4s |
| Grand Feast | — | 71c |
| Leather Pouch / Leather Rucksack | — | 8c / 3s 20c |
| Iron Block (9 bars, no discount) | — | 9c |
| Steel / Abyssal Steel pickaxe | — | 6c / 99c |
| Locked Chest | — | 1c per 2 |
| Cobblestone, Stone, Stone Brick | — | 1c per 50 |
| Planks | — | 1c per 99 |

About 220 items become sellable.

### 3.4 Never sellable

- The **Bag of Coins** ([economy.md](../design/economy.md) §1).
- Items of group `grug_soulbound` or `grug_bound_skill` (Claim Stone,
  ability items) and the mount and boat tokens; the lane checks each is
  covered by a group, else names it.
- The **Fallen Crown** (`grug_rare_trophy`, the crown input) and both
  **Captain's Orders** (quest items).
- Dirt, soils, mud, clay, snow, ice, ground cover (grass, ferns, reeds,
  cattails, moss), flowers, coral, obsidian, permafrost: no value.
- Anything worth less than 1c per 99 after §3.2/§3.3, and anything no player
  can hold (growth stages, door halves, liquids, mapgen and internal nodes).

### 3.5 The sell window

1. **Lot goods get one row per item name**, counted over every carried list
   (`grug_inventory.carried_lists`); otherwise 30 + 30 Cobblestone in two
   slots could never be sold. Goods that sell singly keep one row per slot,
   as today. Lot goods never carry quality, so nothing is lost by merging.
2. Row text: `Cobblestone x143` · `1c per 50` · one button **All (2c)**.
   Single goods keep `1c each`, **1** and **All (…)**.
3. Below the lot size the row is shown greyed, `Need 50 to sell`, without
   a button, so the player learns that the item sells in lots.
4. "All" sells as many whole lots as the player carries; the rest stays:
   status `Sold 100 Cobblestone for 2c. 43 left.`
5. A sale removes the units with the engine's `InvRef:remove_item`, list by
   list over the carried lists, only after every check has passed; no own
   slot planner and no slot order rule.
6. The security model of `trade.lua` holds: the row is recomputed
   server-side on every click and cross-checked against what was shown
   (item, lot, copper, total count); a mismatch re-renders without selling.
   The money ceiling check stays before anything is removed.
7. The hint line (`trade.lua:228`) becomes: `The vendor buys most things you
   carry. Cheap goods sell in lots, e.g. 1c per 50; the rest stays with
   you.`

### 3.6 The daytime band

1. **Geometry of the band:** one 20-minute cycle is 160 texture pixels:
   day 120 px with the sun at its centre, night 40 px with the moon at its
   centre. The box shows exactly one cycle with a fixed "now" marker in the
   middle; the band moves **right to left**, so the coming phase enters
   from the right.
2. **40 positions** per cycle (one per 30 real seconds, 4 px each). The
   position is the real time since 04:30: the day phase maps linearly onto
   the first 900 s, the night onto the last 300 s (the clock runs at two
   speeds, so `timeofday` itself is not linear in real time). A pure
   function computes it (`timeofday → 0..39`).
3. **Updates:** the minimap's existing slow tick (`SLOW = 5`,
   `grug_map/minimap.lua:49`) recomputes the position and sends one
   `hud_change` only when it changes: about one per player every 30 s, and
   a time jump (`/time`, sleeping) shows within 5 s. No new globalstep.
   The tick must also run while the minimap is hidden (item 5).
4. **Forty finished images, no texture modifiers:** a generator script
   writes `grug_map_daytime_00.png` … `grug_map_daytime_39.png` (one per
   position, the box with band, sun, moon, frame and marker), and the HUD
   only switches the file name. No `[combine` offsets, no question of what
   the web client supports; a few KB in all.
5. **Placement:** left of the minimap bezel, bottom-aligned with it, about
   half the minimap diameter wide (aspect about 4 : 1); the mail icon of the
   mail plan sits top-aligned on the same side. **The band stays visible
   with the minimap hidden or unavailable** (ruling 5, the user): it moves
   to the top-right corner with the mail icon, through the same placement
   the MAIL lane builds for that icon.
6. **Art:** sun, moon, the day and night colours, the frame and the "now"
   marker come from the mail plan's ART lane (GPT-6 Astra, two or three
   proposals for the user's pick). The generator composes the 40 images
   from them (`--check` mode), so a later art change regenerates them.
   Until then the lane ships simple generated placeholders.

### 3.7 Smaller bags

1. **Sizes:** Small Bag and Leather Pouch 4, Medium Bag and Leather Satchel
   8, Large Bag and Leather Pack 12, Great Cloth Bag and Leather Rucksack
   16 (`bagslots`). The descriptions follow ("Small Bag (4 slots)"); three
   are written out in `bags.lua:42-61`, five are built from the number.
   Recipes, tiers and drop rows (`grug_quality/init.lua:102-105`) stay.
2. **Upgrade class: migration**, step **0.48.0**. The offline step only sets
   the character marker for every character (stack sizes and the sort order
   live in Lua, as in step 0.45.0). The online part runs through
   `grug_core.migrations` at the character's next join, before every other
   join callback, so before the bags' `set_size`:
   1. take every stack of `main[9..]` and the bags' content lists, shrink
      the content lists to the new sizes, and lay the stacks out again with
      the **one sort path** (`grug_inventory.sort`, `storage.lua:306`,
      extended so it sorts into the given sizes and returns what is left
      over; no second sort). The hotbar is not touched. Soulbound and bound
      items (Claim Stone, mount items) take their slots first and are never
      left over;
   2. the leftovers (the end of the sort order: the "rest" category, low
      tiers last) go into **system letters of four stacks each**, kind
      "npc", sender "Lost and Found", subject "Your bags got smaller",
      body: the bags hold half as much now, the items that no longer fit
      are attached, take them with Take all, the letter is deleted after
      30 days like every letter (text by the coordinator; not a quest
      text);
   3. a feed line once the join has finished, when letters were sent; the
      mail icon shows them through MAIL's own unread count at the join.
   It is safe to run again: the marker is cleared only when every leftover
   is in a letter. A character without bags only loses the marker.
3. **The mail plan's `send_system` gains an optional `stacks` argument**
   (up to four `ItemStack` strings), stored and taken like player
   attachments. Only this migration uses it; admin letters keep carrying no
   items (mail plan ruling 5).
4. **Small Bag 20c** at the vendor (`grug_traders/stock.lua:55`). Its
   buy-back falls from 4c to 1c (5 % of 20c, rounded up): the one existing
   payout that moves this round, by this ruling.
5. The inventory grid needs no code change: each bag starts a row
   (`grug_inventory/ui.lua:191-193`), a 4- or 12-slot bag leaves half a row
   empty (ruling 9). The doc sentence "bag sizes are multiples of 8, so
   there are no gaps" goes. *(Superseded: fix lane INV lets the slots flow
   on in 8-wide rows.)*

## 4. Lanes

Suggested split: **SELL** (prices and the sell window), **FUEL** (small),
**DAY** (the band), **BAGS** (sizes and the migration), and the round's
docs lane.

### 4.1 Lane SELL — `grug_traders`

- `price_rules.lua` (pure): `resolve` and the audits count in integer
  milli-copper instead of copper (same walk, same floor per output unit);
  the lot ladder; the halving as one final step over the crafted items;
  the never list. `loop_findings` judges these values; the existing
  "output pays at most its consumed inputs" rule stays.
- `prices.lua`: feed the bulk table (§3.2), the storage blocks from
  `grug_smelting`'s storage rows, the never list and the crafted items from
  the registries; `FREE_GROUPS`/`FREE` (lines 62-74) shrink to what stays
  worthless (§3.4).
- API: `grug_traders.sell_price(item)` keeps today's meaning for every item
  that sells singly (the probes and `income.py` read it) and returns 0 for
  lot goods; a new call returns the lot offer (copper, lot) for any stack.
  The lane checks every caller: `grug_traders/init.lua` (audits at lines
  53-80 and 83-185), `trade.lua`, and the probes under `tools/r29_e1`,
  `r33_c1`, `r28_e1`, `r45_rg`.
- `trade.lua`: the sell window of §3.5 (`current_rows` line 119,
  `render_sell` line 214, `do_sell` line 422, the field dispatch from
  line 549).
- **Price comparison, once:** the lane lists every item's payout before
  and after its change (a disposable headless probe from its base, after
  FARM has merged) and puts the difference in its report: every item priced
  before is unchanged, the new ones are listed. The reviewer checks that
  report; nothing is checked in and no permanent fixture is added. The
  Small Bag's buy-back (4c → 1c) is the one expected difference once BAGS
  has merged (§3.7.4).
- Upgrade class: **compatible** (no stored state changes).

### 4.2 Lane FUEL — two fuels

- `grug_jobs/automatic.lua`: `default:cactus` 15 s, `group:leaves` 2 s, next
  to the log rule.
- Check whether shift-click into a furnace (`grug_jobs/workspaces.lua:207,
  214, 363`) now routes cactus or leaves differently when a recipe also
  takes them, and report.
- Small enough to ride with another lane (suggested: FARM, same plants);
  game logic, so it is reviewed. Upgrade class: compatible.

### 4.3 Lane DAY — the daytime band in `grug_map`

- A pure function for the position (§3.6.2); the HUD element in
  `minimap.lua` beside the mail icon, kept and placed in the corner while
  the minimap is hidden, through the same placement the MAIL lane builds
  for its icon.
- The generator for the 40 images (§3.6.4) with placeholder art; ART's
  picks replace it.
- Upgrade class: compatible.

### 4.4 Lane BAGS — half-size bags and migration 0.48.0

- `grug_inventory/bags.lua`: the sizes and descriptions (§3.7.1).
- `grug_inventory/storage.lua`: the sort extended to target sizes with
  leftovers (§3.7.2); the Sort button keeps its behaviour.
- `grug_core/migrations.lua`: the 0.48.0 character handler;
  `tools/migration/steps/v0_48_0.py` (the marker); the declaration in
  `tools/web_data/upgrade.json` (`python3 tools/check_upgrade.py`); the
  step's end-to-end test (round workflow §3), with a character whose four
  32-slot bags are full (64 leftover stacks, 16 letters).
- `grug_traders/stock.lua:55`: Small Bag 20c.
- `tools/web_data/web_data.json` regenerated (`export.lua --check`), since
  item descriptions change; the item-tier tables from `tools/r33_ds`
  (`build_doc.py --check`) where they name bag sizes.
- Upgrade class: **migration** (0.48.0).

### 4.5 Docs (the round's docs lane)

- [economy.md](../design/economy.md) §2: milli-copper values, lots and the
  ladder, the bulk table, crafted goods at half their material value,
  storage blocks, the never list; "Free world materials" and "Anything it
  does not price is not sellable" are rewritten; the Sell-window rules.
- [items_crafting.md](../design/items_crafting.md) §3.0.2: cactus and
  leaves as fuel.
- [world_map.md](../design/world_map.md), the minimap section, and the
  module guide's minimap seam: the daytime box beside the mail icon.
- [inventory_equipment.md](../design/inventory_equipment.md) §3 and the
  inventory-view paragraph: 4 / 8 / 12 / 16, 64 bag slots at most, half
  rows, the vendor's Small Bag at 20c (no design file names its price
  today); [item_tiers.md](../design/item_tiers.md) bag rows through
  `tools/r33_ds`.
- The upgrade contract's step list: 0.48.0.
- Help: one line each where Help explains trading, fuel and bags, if it
  does.
- CHANGELOG and README current state.

## 5. Rules

- No price field on items, no `set_price`; the one price module stays
  (AGENTS.md "Economy and travel").
- Existing payouts never move. If a rule would move one, the lane reports
  it instead of changing it. The one exception is the Small Bag's buy-back
  (4c → 1c), which follows its new price (§3.7.4).
- No item is lost by the bag change: everything either stays in the
  inventory or is in a letter.
- No new money loop: every recipe passes the audit on the milli-copper
  values; the startup audits stay errors.
- The band is not a clock: no numbers, no minute precision.

## 6. Verification

**Fixtures** (only the ones that test the changed behaviour; the full set
once per lane):

- SELL, pure (extend `tools/r29_e1/portable_test.lua`): lot choice (20 mc
  → 1c per 50, 80 mc → 1c per 20, 12 mc → 1c per 99, 8 mc → not sellable,
  3500 mc → 3c each); the halving once along a chain (mixture → potion);
  never list; `loop_findings` flags a converting gain and accepts
  sand ↔ sandstone.
- SELL, window: one row for Cobblestone in three slots; All sells whole
  lots over several slots and leaves the rest; 49 shows the greyed row
  without a button; a stack moved between render and click refuses without
  loss; the money ceiling refuses before removal.
- SELL, prices: the one-time before/after comparison in the lane report
  (§4.1).
- `tools/r29_e4/income.py --check` and `tools/r29_e1/band_payout.sh`
  unchanged.
- FUEL: extend `tools/r47_an/portable_test.lua`: cactus 15 s, three leaf
  kinds 2 s, Coal Block and a sapling still 0.
- DAY: the position function at 04:30 (0), 19:29 (29), 19:30 (30), 00:00
  and 04:29 (39); the generator's `--check` (40 images); the box stays with
  the minimap hidden.
- BAGS: the sort into target sizes (pure part: order, merge, leftovers
  from the end, soulbound and bound items never left over); the 0.48.0
  end-to-end test (offline marker, then the join: four full 32-slot bags →
  the inventory sorted into 4 × 16, 16 letters of four stacks, nothing
  lost, a second join changes nothing); `check_upgrade.py`.

**GUI checklist (the user):**

1. A furnace with cactus as fuel smelts about 1.5 bars per cactus; leaves
   burn briefly (five per bar).
2. At a vendor with 143 Cobblestone in three stacks: one row "Cobblestone
   x143 · 1c per 50"; All: 2c, 43 left in the inventory.
3. With 30 Sand: the row is greyed "Need 50 to sell".
4. Sell a Healing Potion, a dish, seeds, an Iron Block and a Steel pickaxe:
   each has a price; a Bag of Coins, the Claim Stone and dirt do not show.
5. Items that sold before sell for the same price as in 0.47.0.
6. The daytime box next to the minimap: sun section long, moon section
   short, the next phase coming in from the right; it moves about every
   30 s; `/time 19:00` and the box shows night close within seconds; hide
   the minimap and the box stays in the corner. Desktop and web build.
7. A character from 0.47.0 with full bags joins after the migration: the
   inventory is sorted, the bags show 4 / 8 / 12 / 16 slots, gear is still
   there, the mail icon shows the "Lost and Found" letters; Take all brings
   the items back once there is room.
8. The vendor sells the Small Bag (4 slots) for 20c.

## 7. Orchestration notes

- **Waves:** FUEL any time (with FARM if possible). SELL after FARM merges
  (new seeds, spores and crops change the item set the price comparison is
  taken from). DAY and BAGS in wave 2 after MAIL merges: DAY shares
  `grug_map/minimap.lua` and the "minimap hidden" placement with MAIL; BAGS
  needs `send_system` with `stacks` (§3.7.3).
- **Review:** SELL, FUEL, DAY and BAGS change game logic → independent
  review (BAGS with its migration test); fix deltas with logic are reviewed
  again. The band's art through the user's pick.
- **The round gets a migration** (0.48.0, BAGS) besides its map reset; the
  mail plan's §5 ("No migration") then reads "no migration of its own".
  MAIL's API gains the optional `stacks` argument of `send_system`
  (§3.7.3); the coordinator writes it into the MAIL lane's brief.
- **Shared files with the other partial plans:** `grug_inventory`
  (MAIL's attachment list, BAGS), `grug_core/migrations.lua` (BAGS),
  `grug_map/minimap.lua` (MAIL, DAY), `grug_jobs` (FUEL; the plant plan's
  salt pan may touch stations), `grug_traders` (SELL, BAGS' stock line),
  `docs/design/economy.md` (MAIL's postage, SELL), `items_crafting.md`
  (FARM, FUEL), the MAIL ART lane (DAY's art).
- **Note for the coordinator:** papyrus pays 1c per piece today and becomes
  farmable indoors with the plant plan. That is income of the size crops
  already give, not an outlier; its price stays (ruling 2).
- **Decided during the round:** the art pick (the user); the band's size and
  corner position (the lane proposes with screenshots, the user can change
  them in the GUI test).
