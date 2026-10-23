# The Miner's Guild

Spec of Round 58 (lane GUILDSPEC, 2026-10-23). The rulings are the user's
([Round 57 plan §8](../planning/round57-plan.md#8-decided-for-round-58),
restated in [Round 58 plan §2 and §2a](../planning/round58-plan.md#2-the-rulings));
each appears here once, in its own words, marked **Ruling**. Everything this
spec adds is marked **Proposal** until the user accepts it. Every number is a
proposal until the user accepts it on the tuning page (§9); the numbers live
in one place, `mods/PLAYER/grug_guild/catalog.lua`, and code reads them from
there. Numbers are rough targets, not hard gates.

## 1. Overview

- **Ruling:** one guild per faction, an essential political actor, a Miner's
  Guild house with NPCs in each of the six capitals.
- The player mines, trades the materials for **reputation** at the guild
  houses and the camp vendors, rises through **ranks 0–10** and spends the
  balance on two **consumables** in six tiers that make mining at depth
  easier. Mining camps on the surface carry a **lift** down to a protected
  **room** at every ore tier's depth. Foremen at the camps give **guild
  quests**; three ranks earn a **cloak**.

## 2. The two guilds

- **Ruling:** **The Charter of Stone** (The Accord) and **The Oathdelvers**
  (The Throng); the user interface says **"Miner's Guild"**; three equal
  leaders per guild, one per capital; foremen carry the role title "Foreman",
  only story-relevant ones are named (the story-arc decision).
- The guilds are loyal allies of their faction's military. Their proper names
  appear in quest texts and on buildings, never in the interface's own labels
  (rank display, vendor page, achievements say "Miner's Guild").
- Catalogue: `GUILDS.accord = {id = "charter_of_stone", name = "The Charter of
  Stone"}`, `GUILDS.throng = {id = "oathdelvers", name = "The Oathdelvers"}`,
  `UI_NAME = "Miner's Guild"`.

## 3. Camps, lifts and rooms

Built by lanes CAMPS, ROOMS, HALLS and LIFT; restated here so the guild is
one picture.

- **Ruling (camps):** 20 new camps, one in every T2, T3 and T4 zone outside the
  capital zones (6 T2, 8 T3, 6 T4), placed per seed in the part of the zone
  whose level fits; a T4 camp in a contested zone belongs to the faction whose
  half of the continent it lies on; the 16 Battlegrounds war camps become
  mining camps too (zones 35/36 are T5, 34/37 T6), guarded by faction guards
  and still the target of the enemy's raid quests; one enemy "camp under
  construction" in each own contested T4 zone: guards and a captain, no lift,
  nothing of use to the enemy; the foreman of the own T4 camp gives the quest
  against it.
- **Ruling (camp NPCs):** each camp has a foreman (quest giver) and a vendor
  who buys like every vendor, trades mining materials for reputation, repairs,
  and sells only reputation goods (one page, all consumables in 6 rows, each
  row "Reach Reputation Rank N" until reached; no torches or ladders).
- **Ruling (lifts):** one lift point per tier depth from T1 down to the camp's
  zone tier (a T2 camp has two, a T6 war camp six; 148 rooms over 36 camps); a
  teleport lift with no shaft, for members of the camp's faction only; it
  connects the surface with every level of its camp.
- **Ruling (rooms):** at the tier's lowest y + 50: −50, −250, −450, −650, −950;
  T6 at −1050; written by the world generator, never stamped at first use;
  protected, without guards and without mob spawns; enemy players may enter
  but not use the lift; safe from water and lava: a mantle with its liquids
  replaced, exits ending blind in rock, an invisible fill that players walk
  through and liquids cannot enter (`walkable = false`, `floodable = false`,
  `buildable_to = false`, `is_ground_content = false`); the planned lava-lake
  pass spares the rooms.
- Each room lies in its band's **lower half** (`grug_materials.TIERS`
  `lower_half_y_max`), where the "½" ore rows of the
  [density table](world_zones.md) lie at their full rate: Iron in T1,
  Anthracite in T2, Silver in T3, Emberglass in T4, Abyssal Crystal in T5. The
  yield model (§9) counts them so.
- The nodes are `grug_mapgen`'s (coordinator decision): CAMPS registers the
  lift point `grug_mapgen:guild_lift` as a placeholder, which LIFT overrides
  from `grug_guild` (`lift.lua`) with its behaviour and the picked art; ROOMS
  registers `grug_mapgen:room_fill`, `grug_mapgen:room_floor`,
  `grug_mapgen:room_lamp` and `grug_mapgen:room_mantle_t1` … `_t6`
  (`grug_mapgen/guild_room_nodes.lua`, the ids in `wp40/guild_rooms.lua`
  `NODES`). The catalogue does not repeat them.

## 4. Reputation

- **Ruling:** a currency the player does not carry, one value per player at
  every guild NPC of their faction; two numbers: the lifetime total (the rank)
  and the spendable balance; spending never lowers the rank; ranks 0–10, the
  last ones hard to reach; ranks 1–6 unlock buying the T1–T6 consumables. A
  new player is rank 0.
- **Ruling (§2a):** no copper route into reputation: the mason stops selling
  Cobblestone and Gravel; the exchange takes only items that no vendor sells.
- Rank n needs the lifetime total `RANKS[n]` (catalogue `rank.<n>`). Earning
  adds the same points to both numbers; spending takes from the balance only.
- **Proposal (the thresholds):** 200, 900, 2,700, 9,000, 23,000, 50,000,
  90,000, 150,000, 225,000, 350,000. Built backwards from hours of mining
  (§9): rank n is earned by mining at tier min(n, 6), the tier whose goods it
  unlocks, so a player reaches rank n about when their level lets them use
  the tier-n goods: ½ h at T1, 1½ h at T2, 2 h at T3, 3 h at T4, 4 h at T5,
  5 h at T6 for rank 6 (16 h in all); ranks 7–10 are prestige at T6 (8, 11½,
  14½ and 24 h: about 75 h in all for the winged cloak). The steps never
  shrink, so the last ranks are the hardest.
- **Proposal (one guild per character, by faction):** the values are kept per
  faction (`grug_guild:lifetime_accord`, …), so an admin's `/faction` (the
  only way a faction changes, `grug_factions.set_faction`) gives the
  character the other guild at its own values (0 at first) and keeps the old
  ones should it switch back. A character without a faction has no guild:
  rank 0, nothing to trade or buy.

## 5. The exchange

- **Ruling:** materials are traded for reputation at the guild houses and the
  camp vendors (a mechanism, not a repeatable quest); exchange rates by
  material, stone and sand very low; selling to vendors for copper stays
  possible. **Ruling (§2a):** bricks, blocks and other made goods are not
  exchanged.
- **Proposal (the mechanism):** like the vendor's Sell tab for lot goods: one
  row per exchanged item the player carries in `grug_inventory.consume_lists`
  (counts summed), "N points per L", a button that trades every whole lot and
  leaves the rest. No quality factor, wear ignored.
- **Proposal (the list):** raw mined goods only, 25 items:
  - stone and sand, **1 point per 50**: Cobblestone, Mossy Cobblestone,
    Desert Cobblestone, Granite, Basalt, Slate, Gravel, Sand, Silver Sand
    (every tier rock drops Cobblestone, so Cobblestone is "stone");
  - every mined resource's raw item, by class, **doubled per harvest tier
    above T1**: common ore 1 (Coal, Copper, Tin, Iron, Quartz; Anthracite,
    harvest tier 2: 2); precious metal or crystal 2 (Gold 4, Silver 8,
    Emberglass 16, Abyssal Crystal 32); gem 4 (Rough Citrine 4, Jade 8,
    Garnet 16, Sapphire 32, Ruby 64, Diamond 128). The classes follow the
    densities: a precious metal or crystal is about half as common as a
    common ore in its band, a gem about a quarter.
  - Left out: bars, blocks, bricks, cut gems, Sandstone (four Sand, both ways
    by recipe) and Desert Sand (no natural source in our world; a recipe only).
- **Cobblestone and Gravel wait for lane REP:** the mason sells both today
  (`grug_traders/stock.lua`), so their rows carry `pending = "rep"` and are not
  exchanged. REP deletes the two `pending` fields in the change that takes them
  off the shelf; the fixture (`tools/r58_guildspec`) then checks them like
  every other row, and refuses a `pending` row that has no vendor source left.

### 5.2 The camp vendor

- **Ruling:** see §3 (buys, trades, repairs, the one page of six rows).
- **Proposal:** the rows are locked by the rank of the player's own guild
  ("Reach Reputation Rank N"), and the rank is checked again at the purchase.
  Prices are paid from the balance. The page is not a shelf of
  `grug_traders.profession_stock`, so the ingredient source index never lists
  the consumables as copper goods. The hall's exchange counter in each capital
  trades and buys like the camp vendor but has no reputation page
  (**proposal**; the plan names it "the guild's vendor" for the exchange).

## 6. Achievements and cloaks

- **Ruling:** an achievement series "Reach Reputation Rank 3/6/10 with the
  Miner's Guild" with three cloaks (rank 10 winged; the picked art: drop-01 P1).
- **Proposal:** one achievement row `miners_guild` with tiers at 3, 6 and 10
  on the counter `guild:rank`, the highest rank the character reached with
  either guild (so an admin's `/faction` never takes a cloak); cloaks
  `miners_guild_1` … `_3` (`grug_achievements` convention: tier N of `<id>`
  unlocks `<id>_N`), the third with wings. The counter is fed by
  `grug_guild.register_on_rank_change` (§10.3). No `faction` field: both
  factions earn it.

## 7. The consumables

- **Ruling:** Ore Sense: every 60–120 s it marks one ore deposit of its tier in
  range for 5 s, visible to the user only. Treasure Hunt: it places one hidden
  block in solid rock (no air within 1, never in a protected area), marked for
  the user while in range; the block removes itself when the user goes too far
  (so nothing stays after a crash or logout); others may mine it, without a
  marker. Each has a fixed tier and works only in its depth: 12 items;
  expensive. Rank gates buying; level gates use (1 for T1, 11 for T2, …, 51
  for T6); tradeable and storable. Their own effect slot (not the elixir's),
  only one of the two active at a time; the effect continues across logout
  and death (it saves its remaining time).
- Names: **Ore Sense I … VI**, **Treasure Hunt I … VI** (Roman numerals like
  the elixirs; **proposal**). Items `grug_guild:ore_sense_t<n>`,
  `grug_guild:treasure_hunt_t<n>`; use level `_grug_req_level` = 10 n − 9
  (`grug_core.can_use_item_level`); purchase rank n.
- **Proposal (common rules):**
  - the effect lasts **30 minutes** (one mining session);
  - "works only in its depth": the item can be used only inside its tier's band
    (`grug_materials.tier_at(y) == tier`), and while the effect runs it marks
    or places nothing outside that band; its time keeps running everywhere
    (simple, and the effect is not combat-relevant);
  - an effect that runs is **never replaced**: using a second item while one
    runs is refused with the time left, so an expensive item is never lost
    (the one status id already makes "one at a time" hold);
  - price about **one hour of mining at the tier** in reputation (400, 500,
    900, 2,000, 3,500, 5,000 for both kinds): "expensive", one hour buys about
    one use (§9);
  - a vendor pays **5 % of the price in copper** (20c, 25c, 45c, 1s, 1s75c,
    2s50c), the 5 % of every buy-back; never more than the materials behind
    the price would have sold for (the fixture's no-loop check: at most price
    × the cheapest copper per point of the exchange, 0.75c, Gold and Silver).
- **Ore Sense (proposal):** a mark goes to the nearest deposit within
  **16 nodes** of the first target with one in range; its targets are the
  resources of its own harvest tier, the gem first (T1 Rough Citrine, Iron,
  Quartz, Copper, Tin, Coal; T2 Jade, Gold, Anthracite; T3 Garnet, Silver; T4
  Sapphire, Emberglass; T5 Ruby, Abyssal Crystal; T6 Diamond); a uniform
  random interval of 60–120 s between marks, the marker 5 s, seen by the user
  only. The search is `core.find_node_near` over the targets' nodes
  (`group:grug_resource` = the harvest tier), once per mark: about one call per
  player every 90 s.
- **Treasure Hunt (proposal):** one Miner's Remains at a time, placed
  **12–24 nodes** from the user in the tier's own rock (`TIERS[t].node`, all 26
  neighbours solid, `core.is_protected` and the hard protection false);
  marked while the user is within **32**; it removes itself when the user is
  beyond **48** or offline (its node timer checks every **5 s**; an unloaded
  block catches up when it loads); the next one **90 s** after the last was dug
  or removed. Others may dig it and take its loot.
- **The effect slot:** status id **`mining_sense`** with the variants
  `ore_sense` and `treasure_hunt` (the picked status icons, drop-01 P2); the
  row in `grug_core/status_icons.lua` is lane CONSUME's.
- **Persistence:** statuses are runtime-only and cleared at leave and death
  (`grug_core/status.lua`). The effect saves `{kind, tier, remaining}` in
  player meta `grug_guild:effect` on a timer and at leave, and re-applies it at
  join and after `on_dieplayer`. No position is saved (§10.9). `grug_core`
  clears the statuses in its own leave and death callbacks (`status.lua`:
  `register_on_leaveplayer`, `register_on_dieplayer(clear_runtime_statuses)`),
  which run before `grug_guild`'s (it loads first), so the status is already
  gone when `grug_guild`'s callback runs: CONSUME keeps the effect's own end
  time per player and saves and re-applies from that, never from the status.
- **Built** (lane CONSUME, `grug_guild/effect.lua`, `items.lua`): the common
  rules, both kinds and the slot as proposed above, with these choices:
  - the save timer writes every **30 s** (a crash costs the player at most
    that), plus at leave; the offline time does not count; the death and the
    respawn re-apply the picture;
  - Ore Sense makes **one** `core.find_nodes_in_area` (grouped) over the
    range cube, clipped to the band, for all its targets at once, and marks
    the nearest deposit within `range` (true distance) of the first target
    found; per-target
    `core.find_node_near` would be up to one full scan per target when none
    is near (measured in the round report);
  - the **markers** are per-player HUD image waypoints (`hud_add`
    `image_waypoint`): only the user's client has them, and they are drawn
    over the world, so a deposit or a Remains inside the rock shows;
    per-player particles and entities with observers are depth-tested and
    the rock in front hides them. Ore Sense shows the ore's own tile,
    Treasure Hunt the Remains' tile;
  - each Remains holds its owner and a **placement token** in node meta; its
    timer removes it when the token is no longer its owner's current one, so
    an old Remains whose block was unloaded while a newer one was placed
    goes when its block loads, and every Remains goes after a restart;
  - a relog never skips Treasure Hunt's pause: the leave takes the
    Remains, and the resumed effect places the next one after
    `respawn_seconds` (a fresh use places the first at once);
  - a refusal says why: the use level, the band (`… works only between y
    −301 and −500.`), or the running effect with its time left.

## 8. Miner's Remains

- **Ruling:** Miner's Remains give copper and materials, worth more deeper; a
  material obtainable only this way waits for the unique items (Round 57 §9).
- Six nodes `grug_guild:miners_remains_t<n>` ("Miner's Remains"): the tier's
  rock with the picked overlay (drop-01 P1), its dig level, no item of its
  own, `is_ground_content = false`.
- **Proposal (the loot):** a Bag of Coins (`grug_money.make_bag`), the tier's
  bar and, once in 8, the tier's cut gem: a fallen miner's pack.

  | Tier | Copper | Bars | Cut gem (1 in 8) |
  |---:|---|---|---|
  | 1 | 2–5c | 1 Bronze Bar | Cut Citrine |
  | 2 | 6–12c | 1–2 Iron Bar | Cut Jade |
  | 3 | 12–24c | 1–2 Steel Bar | Cut Garnet |
  | 4 | 30–70c | 1–2 Silversteel Bar | Cut Sapphire |
  | 5 | 80c–1s80c | 1–2 Embersteel Bar | Cut Ruby |
  | 6 | 2s–4s50c | 1–2 Abyssal Steel Bar | Cut Diamond |

  Sized so one Treasure Hunt (about 15 Remains in the model) is worth about
  half an hour of the band's income (82–105 %, §9). Bars and cut gems are made
  goods, so the exchange never takes them: Treasure Hunt cannot feed
  reputation, and reputation cannot buy reputation.
- **Built** (lane CONSUME): the nodes carry the tier rock's `grug_stratum`
  group with its level, so digging them is the rock's transaction (the
  protection, the tier pick and its hint) and the startup audit accepts the
  level; the loot goes to the digger like a dig's drops
  (`core.handle_node_drops`); when the Remains goes without a dig it turns
  back into its rock.
- The Remains are a second world source of copper beside the mobs' coin bags,
  by the ruling; `economy.md` §1 ("No NPC or world node drops money") gets that
  exception from lane CONSUME.

## 9. The numbers and the yield model

Every number, its key and its reason are on the tuning page
(`~/projects/grudgelands-orchestration/r58/tuning-page/index.html`, built by
`tools/r58_guildspec/build_page.lua`), which saves the user's values to
`picks/tuning`; `tools/r58_guildspec/apply_tuning.py` writes them into the
catalogue, `write_doc.lua` regenerates the tables below.

**No measured mining yield exists.** The tables are a **model**
(`tools/r58_guildspec/model.lua`) built from the game's data: the tier pick's
dig time on its own rock (`grug_materials` `PICK_PROFILES`), the ore rows'
host nodes per ore and vein caps (`wp40/r7_r6_manifest.lua`), the vendor
payouts (`grug_traders/price_rules.lua`, stone and sand 20 milli-copper each),
the income per band (`economy.md` §3), and the assumptions in the first line.
Per tier: nodes dug per hour = 3600 × digging share ÷ (dig time + overhead);
rock seen = nodes dug × exposure; each resource = rock seen ÷ its host nodes
per ore; reputation = the resources at their rates plus the carried stone at
Cobblestone's rate (counted as if REP had let it in). The copper column sells
the same goods instead. Rank n is earned at tier min(n, 6).

<!-- generated: guild-model -->
Assumptions: digging 50 % of the hour, 0.35 s per node beside the dig, 3 rock nodes seen per node dug, 25 % of the stone carried back; Ore Sense finds 50 % of its marks extra; a Remains takes 30 s to reach.

| Tier | Dig s | Nodes dug/h | Resources/h | Reputation/h (stone) | Copper/h if sold | Income/h of the band |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.450 | 2250 | 365 | 416 (11) | 4s 16c | 1s 72c |
| 2 | 0.425 | 2323 | 288 | 483 (12) | 5s 24c | 4s 28c |
| 3 | 0.400 | 2400 | 264 | 903 (12) | 10s 48c | 9s 11c |
| 4 | 0.350 | 2571 | 313 | 2047 (13) | 24s 91c | 24s 40c |
| 5 | 0.300 | 2769 | 320 | 3535 (14) | 54s 90c | 64s 48c |
| 6 | 0.250 | 3000 | 312 | 5165 (15) | 1g 12s 12c | 1g 47s 64c |

| Rank | Lifetime | Mined at | Hours for this rank | Hours in total | Hours at T6 alone |
|---:|---:|---:|---:|---:|---:|
| 1 | 200 | T1 | 0.5 | 0.5 | 0.0 |
| 2 | 900 | T2 | 1.4 | 1.9 | 0.2 |
| 3 | 2700 | T3 | 2.0 | 3.9 | 0.5 |
| 4 | 9000 | T4 | 3.1 | 7.0 | 1.7 |
| 5 | 23000 | T5 | 4.0 | 11.0 | 4.5 |
| 6 | 50000 | T6 | 5.2 | 16.2 | 9.7 |
| 7 | 90000 | T6 | 7.7 | 23.9 | 17.4 |
| 8 | 150000 | T6 | 11.6 | 35.5 | 29.0 |
| 9 | 225000 | T6 | 14.5 | 50.1 | 43.6 |
| 10 | 350000 | T6 | 24.2 | 74.3 | 67.8 |

| Tier | Price | Uses an hour of the tier buys | Ore Sense marks | Ore Sense extra reputation (share of price) | Treasure Hunt Remains | Remains loot each | Loot per use (share of half an hour's income) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 400 / 400 | 1.04 / 1.04 | 20 | 40 (10 %) | 15 | 6c | 90c (105 %) |
| 2 | 500 / 500 | 0.97 / 0.97 | 20 | 80 (16 %) | 15 | 12c | 1s 76c (82 %) |
| 3 | 900 / 900 | 1.00 / 1.00 | 20 | 160 (18 %) | 15 | 27c | 4s 9c (90 %) |
| 4 | 2000 / 2000 | 1.02 / 1.02 | 20 | 320 (16 %) | 15 | 73c | 10s 95c (90 %) |
| 5 | 3500 / 3500 | 1.01 / 1.01 | 20 | 640 (18 %) | 15 | 1s 80c | 27s 0c (84 %) |
| 6 | 5000 / 5000 | 1.03 / 1.03 | 20 | 1280 (26 %) | 15 | 4s 41c | 66s 15c (90 %) |
<!-- end generated -->

Reading the tables: an hour deeper earns more (416 → 5,165 points from T1 to
T6, stone 11–15 of them); an hour at a tier buys about one of its
consumables; Ore Sense's extra finds are worth 10–26 % of its price in
reputation (it saves searching rather than paying for itself); a Treasure
Hunt's Remains bring about half an hour of the band's income. Selling an
hour's finds instead pays about the band's income from T3 on and more below
(the model's T1 hour, 4s 16c against 1s 72c, says more about the generous
model than about the game).

## 10. The `grug_guild` contract

The mod `mods/PLAYER/grug_guild` holds the guild's own state and logic.
Wave-1 lanes build on this section and never change it; a problem in it stops
that path and goes to the coordinator with the change the lane would want.

### 10.1 Files, owners, dependencies

| File | Owner | Holds |
|---|---|---|
| `mod.conf` | GUILDSPEC | `depends = grug_core, grug_materials, grug_money, grug_inventory, grug_mapgen, grug_factions, default` — every dependency the planned mod needs, so no lane edits it; another one goes to the coordinator |
| `init.lua` | GUILDSPEC | the global `grug_guild`, the catalogue API, one `dofile` per file below, the load audit (every catalogue item registered once the mods have loaded) |
| `catalog.lua` | GUILDSPEC; its `VALUES` the coordinator (the tuning page); the two `pending` fields REP | every number and id as pure data, the accessors |
| `store.lua` | REP | reputation: §10.3 |
| `exchange.lua` | REP | the trade-in: §10.4 |
| `effect.lua` | CONSUME | the mining effect: §10.5 |
| `items.lua` | CONSUME | the 12 items, the 6 Remains nodes, the loot roll: §10.6 |
| `vendor.lua` | CAMPNPC | the reputation page's rows and the purchase: §10.7 |
| `lift.lua` | LIFT | the lift's interaction: overrides `grug_mapgen:guild_lift` (CAMPS' placeholder) with its behaviour and the picked art |

Until a lane fills its file, its functions are documented stubs that answer
as for a character of rank 0 with nothing to trade and no effect (`add`,
`trade_in`, `start_effect` and `buy` refuse with `"unavailable"`). The
fixture checks only that the functions exist, so each lane fills its file
without touching it. Outside
`grug_guild`, the lanes touch: REP `grug_traders` (the mason's shelf, the
trade-in in the vendor window, the consumables' payout in `prices.lua` from
`sell_copper`) and `grug_achievements` (§6); CONSUME
`grug_core/status_icons.lua` (§7) and `economy.md` §1 (§8); CAMPNPC
`grug_traders` (the camp vendor kind and its page) and `grug_repair` (the
provider). REP and CAMPNPC share the vendor window: REP first (plan §7).

### 10.2 The catalogue (`catalog.lua`)

Pure Lua (no engine call): the mapgen environment, the fixture and the tools
load the same bytes with `dofile`. Published as `grug_guild.catalog`.

- `VALUES`: every tunable number, one line each, by key:
  `rank.<n>`; `exchange.<item>.points` and `.lot`; `ore_sense.t<n>.price`,
  `treasure_hunt.t<n>.price`, `consumable.t<n>.sell_copper`;
  `ore_sense.{duration, range, interval_min, interval_max, marker_seconds}`;
  `treasure_hunt.{duration, place_min, place_max, marker_range,
  remove_distance, respawn_seconds, check_seconds}` (seconds and nodes);
  `remains.t<n>.{copper_min, copper_max, bars_min, bars_max, gem_chance}`.
  Whole numbers; code never reads `VALUES` directly but the tables below.
- `RANKS[n]`: the lifetime total rank n needs (n = 1..10); `MAX_RANK = 10`.
- `EXCHANGE`: list of `{item, points, lot, pending}` (catalogue order, the
  trade-in's row order); `EXCHANGE_BY_ITEM[item]`.
- `CONSUMABLES`: list of rows `{kind, tier, item, name, use_level, rank,
  price, sell_copper, variant, duration, …}` with the kind's parameters (Ore
  Sense: `range, interval_min, interval_max, marker_seconds, targets`;
  Treasure Hunt: `place_min, place_max, marker_range, remove_distance,
  respawn_seconds, check_seconds`); `CONSUMABLE_BY_ITEM[item]`.
- `REMAINS[tier]`: `{tier, node, name, host, bar, gem, copper_min,
  copper_max, bars_min, bars_max, gem_chance}`.
- `ORE_SENSE_TARGETS[tier]`: resource keys of `grug_materials.RESOURCES`, in
  priority order.
- `GUILDS[faction] = {id, name}`, `UI_NAME`, `STATUS = {id, variants}`,
  `KINDS`, `KIND_NAMES`, `NUMERALS`, `TIER_COUNT`.
- Accessors, also published on `grug_guild`: `rank_for(lifetime) -> 0..10`,
  `threshold(rank) -> lifetime | nil` (0 for rank 0, nil beyond 10),
  `exchange_rate(item) -> row | nil` (nil for a pending row),
  `consumable(kind, tier)`, `consumable_by_item(item)`, `remains(tier)`,
  `guild(faction) -> {id, name} | nil`; `validate()` raises on a broken shape
  (run at load).

### 10.3 Reputation (`store.lua`, REP)

| Function | Returns |
|---|---|
| `grug_guild.lifetime(player)` | integer, the own guild's lifetime total (0 without a faction) |
| `grug_guild.balance(player)` | integer, the spendable balance |
| `grug_guild.rank(player)` | 0..10, `rank_for(lifetime)` |
| `grug_guild.add(player, points, source)` | `lifetime, balance` after the change, or `nil, err` (`"no_faction"`, `"bad_amount"`: not a positive integer). Adds to both; `source` a word for the action log (`"trade_in"`, `"admin"`); fires the change callbacks and, when the rank rose, the rank callbacks |
| `grug_guild.spend(player, points)` | `balance` after the change, or `nil, err` (`"insufficient"`, `"no_faction"`, `"bad_amount"`); never touches the lifetime |
| `grug_guild.register_on_change(fn(player, faction, lifetime, balance))` | — |
| `grug_guild.register_on_rank_change(fn(player, faction, new_rank, old_rank))` | — the achievement series' hook |

Both numbers clamp at 2,147,483,647 (`set_int`). An admin command for tests
and the GUI checklist ("the winged cloak at rank 10, admin-set") is REP's:
**proposal** `/guild_rep <player> <points>` (privilege `server`), through
`add(…, "admin")`.

### 10.4 The trade-in (`exchange.lua`, REP)

| Function | Returns |
|---|---|
| `grug_guild.trade_in_rows(player)` | rows in catalogue order for every exchanged item carried in `grug_inventory.consume_lists`: `{item, count, lot, points, lots, total, rest}` (`lots = floor(count / lot)`, `total = lots × points`, `rest = count − lots × lot`) |
| `grug_guild.trade_in(player, item)` | `points, lifetime, balance`, or `nil, err` (`"no_faction"`, `"not_exchanged"`, `"too_few"`): takes every whole lot after every check (as the Sell tab's All), recomputed server-side, then `add(player, total, "trade_in")` |

### 10.5 The effect (`effect.lua`, CONSUME)

| Function | Returns |
|---|---|
| `grug_guild.active_effect(player)` | `{kind, tier, remaining}` (seconds) or nil |
| `grug_guild.start_effect(player, kind, tier)` | `true`, or `false, err` (`"unknown"`, `"level"`, `"depth"`, `"active"`) |
| `grug_guild.stop_effect(player)` | bool (admin and tests) |

The status id `catalog.STATUS.id` (`mining_sense`), the variant
`catalog.STATUS.variants[kind]`; the saved key `grug_guild.EFFECT_KEY`
(`grug_guild:effect`).

### 10.6 The items (`items.lua`, CONSUME)

- The 12 consumables (`catalog.CONSUMABLES`: id, name, `_grug_req_level` =
  `use_level`, the picked icons), stackable; on use `start_effect`, the item
  taken only when the effect starts.
- The 6 Remains nodes (`catalog.REMAINS`).
- `grug_guild.remains_loot(tier, random) -> {copper = n, items = {"name count", …}}`,
  pure (`random(lo, hi)` an integer source), so a fixture can roll it.

### 10.7 The vendor page (`vendor.lua`, CAMPNPC)

| Function | Returns |
|---|---|
| `grug_guild.vendor_rows(player)` | six rows `{tier, rank, unlocked, items}`, `items` the tier's two consumable rows |
| `grug_guild.buy(player, item)` | `true`, or `false, err` (`"no_faction"`, `"unknown"`, `"rank"`, `"insufficient"`, `"full"`: no room, nothing spent) |

The window and its buttons are `grug_traders`' (the camp vendor kind).

### 10.8 Ids

| Id | What |
|---|---|
| `grug_guild:ore_sense_t1` … `_t6` | Ore Sense I … VI |
| `grug_guild:treasure_hunt_t1` … `_t6` | Treasure Hunt I … VI |
| `grug_guild:miners_remains_t1` … `_t6` | Miner's Remains in each tier's rock |
| `grug_mapgen:guild_lift` | the lift point (CAMPS; LIFT overrides it) |
| `grug_mapgen:room_fill`, `room_floor`, `room_lamp`, `room_mantle_t1` … `_t6` | the room's nodes (ROOMS) |
| status `mining_sense`, variants `ore_sense`, `treasure_hunt` | the effect slot (not `elixir`) |
| achievement `miners_guild`, cloaks `miners_guild_1` … `_3`, counter `guild:rank` | §6 (proposal) |

### 10.9 Saved state and the map reset

| Where | Key | Value | Map-bound |
|---|---|---|---|
| player meta | `grug_guild:lifetime_<faction>` | integer | no |
| player meta | `grug_guild:balance_<faction>` | integer | no |
| player meta | `grug_guild:effect` | `core.serialize({kind, tier, remaining})` | no (no position) |
| the map | a Miner's Remains node and its meta (owner) | — | yes: it lives in the map and goes with it |

- The keys are created on first use, so with 0.58.0's map reset every
  character starts at 0 (plan §3). They hold no position, so a later map reset
  keeps them like money, and nothing needs a `register_on_relocate` clear
  ([upgrade contract](../technical/upgrade-contract.md) §3.4). The lift's
  return point (LIFT) is a position and gets one; the Treasure Hunt's block
  position is runtime-only, never in player meta.
- No mod storage.

## 11. Guild quests

Built by lane GUILDQUESTS on the Round 57 quest system ([quests.md](quests.md)).

- **Ruling:** guild gather quests are bound to the depth, not the camp: one
  quest id per tier (T2–T6) for both factions with a text per guild, taken and
  turned in only at own-faction camps; every own camp whose deepest lift
  reaches the tier offers it until done (a missed T2 quest is offered in a T3
  camp too); 1–2 gather quests per tier; when both gather quests of a tier are
  done, the foreman may give one follow-up ("tell the guild in the capital"),
  carrying the guild's small storyline (one seed per tier, story-arc draft §5);
  no T1 mining quest; each camp has 1–2 kill quests on mobs near the camp (day
  or night spawns; "at night" may be literal); all of a camp's quests can be
  taken at once; no chains beyond the one follow-up; no kill objectives in the
  depth; no repeatable quests.
- The gather quests ask for exchanged materials. **Proposal:** their copper
  and items follow the Round 57 reward rules; they give no reputation of their
  own (reputation comes only from the exchange; see the round report's
  questions).
