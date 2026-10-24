# The Miner's Guild

Spec of Round 58 (lane GUILDSPEC, 2026-10-23). The rulings are the user's
([Round 57 plan §8](../planning/round57-plan.md#8-decided-for-round-58),
restated in [Round 58 plan §2 and §2a](../planning/round58-plan.md#2-the-rulings));
each appears here once, in its own words, marked **Ruling**. Everything this
spec adds is marked **Proposal** until the user accepts it. Every number is a
proposal until the user accepts it on the tuning page (§9); the numbers live
in one place, `mods/PLAYER/grug_guild/catalog.lua`, and code reads them from
there. Numbers are rough targets, not hard gates. The user accepted the
numbers as a first version on 2026-10-23 (the tuning page saved no change,
so the catalogue's proposals stand); the names of the cloaks and the
achievement (§6) are still proposals.

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
  only story-relevant ones are named (the story-arc decision; since Round 60
  Brodd Deeppeg of Frostbarrow Shelf's camp and Rellis Shalemark of Ossuary
  Reach's, [quests.md](quests.md) "The Miner's Guild givers").
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
- **The room** (lane ROOMS, `wp40/guild_rooms.lua`): an open room 7 × 7 nodes
  and 4 high round the camp's lift column, the lift in its centre facing the
  arrival point beside it, three exits (1 wide, 2 high) in three walls running
  through the 3-node mantle, each ending blind in a plug of the tier's rock
  one node past the mantle (outside the protection: players dig on from
  there; no cave or liquid opens it), four wall lamps; the
  mantle wears the tier's host rock. The whole 13 × 10 × 13 box is protected
  ("Miner's Guild – protected") and refuses mob spawns; below −501 it is
  contested ground like everything there.
- **The lift** (lane LIFT, `grug_guild/lift.lua`): a right-click opens the
  list of the camp's levels, "Surface" and "Level N (floor y)" for each room
  (Level 1 (-50) … the camp's tier), the current one "You are here", the
  others a Travel button. The camp is found from the clicked lift (a room's
  through `guild_rooms.room_at`, the surface lift through
  `mining_camps.near`). Only members of the camp's faction use it; everyone
  else (the enemy, in a room too, and a character without a faction) gets
  the faction service's refusal line ("<Miner's Guild Lift> I serve only
  The Accord."). A trip runs through `grug_home.travel` with the waystones'
  rules ([world.md](world.md) §6): instant, free, no cooldown, alive and out
  of combat, standing within 8 nodes of the lift, one trip at a time, the
  mount left behind; combat or walking away during the emerge cancels it.
  It arrives at the room's arrival point in front of its lift, or on the
  surface in front of the surface lift (its `4dir` front, the deck toward the
  gate), else behind or beside it; no free cell leaves the player where they
  are. Nothing is saved: the list always offers every level, so there is no
  return point. The node's look (guild art drop 02 P1, the rope drum hoist,
  its node box and a full-node selection box) is static in
  `grug_mapgen/world_nodes.lua`; `lift.lua` overrides only the right-click.
- Each room lies in its band's **lower half** (`grug_materials.TIERS`
  `lower_half_y_max`), where the "½" ore rows of the
  [density table](world_zones.md) lie at their full rate: Iron in T1,
  Anthracite in T2, Silver in T3, Emberglass in T4, Abyssal Crystal in T5. The
  yield model (§9) counts them so.
- The nodes are `grug_mapgen`'s (coordinator decision): CAMPS registers the
  lift point `grug_mapgen:guild_lift` (LIFT gave it the picked art and node
  box in `world_nodes.lua` and overrides its right-click from `grug_guild`,
  `lift.lua`); ROOMS
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
- **Proposal (one guild per character, by faction; built by lane REP):** the
  values are kept per faction (`grug_guild:lifetime_accord`, …), so an admin's
  `/faction` (the only way a faction changes, `grug_factions.set_faction`)
  gives the character the other guild at its own values (0 at first) and keeps
  the old ones should it switch back. A character without a faction has no
  guild: rank 0, nothing to trade or buy.

## 5. The exchange

- **Ruling:** materials are traded for reputation at the guild houses and the
  camp vendors (a mechanism, not a repeatable quest); exchange rates by
  material, stone and sand very low; selling to vendors for copper stays
  possible. **Ruling (§2a):** bricks, blocks and other made goods are not
  exchanged.
- **Proposal (the mechanism; built by lane REP):** like the vendor's Sell tab
  for lot goods: one row per exchanged item the player carries in
  `grug_inventory.consume_lists` (counts summed), "N points per L", a button
  that trades every whole lot and leaves the rest. No quality factor, wear
  ignored. Built as the vendor window's **Trade-in** mode, shown by a vendor
  whose definition (`grug_traders.vendors`) carries `guild = true`; the window
  opens on it and shows the guild, the rank and the balance.
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
- **Cobblestone and Gravel joined with lane REP (built):** the mason no
  longer sells them (`grug_traders/stock.lua`), and their rows carry no
  `pending` field any more; the fixture (`tools/r58_guildspec`) checks them
  like every other row, and refuses a `pending` row that has no vendor source
  left.

### 5.2 The camp vendor

- **Ruling:** see §3 (buys, trades, repairs, the one page of six rows).
- **Proposal (built by lane CAMPNPC):** the rows are locked by the rank of
  the player's own guild ("Reach Reputation Rank N"), and the rank is checked
  again at the purchase. Prices are paid from the balance. The page is not a
  shelf of `grug_traders.profession_stock`, so the ingredient source index
  never lists the consumables as copper goods. The hall's exchange counter in
  each capital trades and buys like the camp vendor but has no reputation
  page (**proposal, built**; the plan names it "the guild's vendor" for the
  exchange).
- **As built:** the Camp Vendor (`grug_traders:vendor_camp`, every mining
  camp's and war camp's `vendor_camp` socket) is a guild vendor (`guild =
  true`) that opens on Trade-in; it sells no copper goods, so its **Buy**
  mode is the reputation page (`guild_page = true`): the guild's rank,
  balance and lifetime as on the Trade-in, then one row per tier with its
  Ore Sense and Treasure Hunt, each item a button with its price in
  reputation and the row's use level ("Use from level 21"); a locked row is
  greyed, has no button and says "Reach Reputation Rank N" (its prices
  shown). A purchase that fails (rank, balance, a full bag) spends nothing
  and says why. Its **Repair** button opens the repair form
  ([durability_repair.md](durability_repair.md)). The Miner's Guild
  Exchange (`grug_traders:guild_exchange`, the hall's exchange socket) opens
  on Trade-in, buys like every vendor, and its Buy mode says "The Miner's
  Guild sells its goods at the mining camps." Both serve only the faction of
  the settlement they stand in (Round 31 ruling 13, as every vendor; the
  reviewer's raider concern), and the foremen and leaders serve their own
  faction like every quest giver.

## 6. Achievements and cloaks

- **Ruling:** an achievement series "Reach Reputation Rank 3/6/10 with the
  Miner's Guild" with three cloaks (rank 10 winged; the picked art: drop-01 P1).
- **Proposal (built by lane REP):** one achievement row `miners_guild` with
  tiers at 3, 6 and 10 on the counter `guild:rank`, the highest rank the
  character reached with either guild (so an admin's `/faction` never takes a
  cloak); cloaks `miners_guild_1` … `_3` (`grug_achievements` convention: tier
  N of `<id>` unlocks `<id>_N`), the third with wings. The counter is fed by
  `grug_guild.register_on_rank_change` (§10.3). No `faction` field: both
  factions earn it. Built with the counter read live
  (`grug_guild.highest_rank`, nothing copied) and the cloaks Lamp Badge
  Workcloth, Lamp and Pick Workcloth and Lamplight Mantle (names a proposal).

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
- **Ore Sense:** **Ruling** (the user, 2026-10-23): a mark goes to a
  **random deposit, ore or gem**, of its targets within **16 nodes**; the
  first mark comes one interval after the use, and marks happen only while
  the user is in the item's tier depth. Its targets are the
  resources of its own harvest tier (the gem listed first: T1 Rough Citrine, Iron,
  Quartz, Copper, Tin, Coal; T2 Jade, Gold, Anthracite; T3 Garnet, Silver; T4
  Sapphire, Emberglass; T5 Ruby, Abyssal Crystal; T6 Diamond); a uniform
  random interval of 60–120 s between marks, the marker 5 s, seen by the user
  only. One search per mark over the targets' nodes: about one per player
  every 90 s (built with `core.find_nodes_in_area`, below).
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
    a random target kind that has a deposit within `range` (true
    distance), then one of its deposits at random: kind first, so the gem
    is marked about as often as a common ore rather than drowning in Coal;
    a mark that falls due outside the band does nothing and the next
    interval starts (per-target `core.find_node_near` would be up to one
    full scan per target when none is near; measured in the round report);
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
| `catalog.lua` | GUILDSPEC; its `VALUES` the coordinator (the tuning page); REP deleted the two `pending` fields (no row is pending now) | every number and id as pure data, the accessors |
| `store.lua` | REP | reputation: §10.3 |
| `exchange.lua` | REP | the trade-in: §10.4 |
| `effect.lua` | CONSUME | the mining effect: §10.5 |
| `items.lua` | CONSUME | the 12 items, the 6 Remains nodes, the loot roll: §10.6 |
| `vendor.lua` | CAMPNPC | the reputation page's rows and the purchase: §10.7 |
| `lift.lua` | LIFT | the lift's interaction: overrides `grug_mapgen:guild_lift`'s right-click (the node's static fields and picked art are `world_nodes.lua`'s); `lift_at(pos)`, `use_lift(player, pos)` (§3) |

Each lane filled its file (Round 58); while the skeleton stood alone, the
functions were documented stubs answering as for a character of rank 0 with
nothing to trade and no effect. The fixture checks only that the functions
exist, so no lane had to touch it. Outside
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
- `ORE_SENSE_TARGETS[tier]`: resource keys of `grug_materials.RESOURCES`
  (display order; a mark picks a random kind in range, §7).
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
**proposal, built** `/guild_rep <player> <points>` (privilege `server`), through
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

### 10.7 The vendor page (`vendor.lua`, CAMPNPC; built)

| Function | Returns |
|---|---|
| `grug_guild.vendor_rows(player)` | six rows `{tier, rank, unlocked, items}`, `items` the tier's two consumable rows |
| `grug_guild.buy(player, item)` | `true`, or `false, err` (`"no_faction"`, `"unknown"`, `"rank"`, `"insufficient"`, `"full"`: no room, nothing spent) |

The window and its buttons are `grug_traders`' (the camp vendor kind):
the page's buttons are `repbuy_<index in catalog.CONSUMABLES>`, and a
click counts only for an item the page showed buyable. `buy` checks the
room before it spends (`grug_inventory.fits`) and gives through
`grug_inventory.give`; it saves nothing of its own.

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
  ([upgrade contract](../technical/upgrade-contract.md) §3.4). The lift keeps
  no return point (its list offers every level), so it saves nothing; the
  Treasure Hunt's block position is runtime-only, never in player meta.
- No mod storage.

## 11. Guild quests

Built by lanes GUILDQUESTS and GUILDTEXT on the Round 57 quest system
([quests.md](quests.md)).

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
- **Ruling (2026-10-23):** no reputation from guild quests; reputation comes
  only from the exchange. Rewards are XP, copper, materials or choices under
  the budget rule.
- **As built (the structure by lane GUILDQUESTS; the texts by lane
  GUILDTEXT with the user's picks of the text review, 2026-10-24):** 30
  quests with new ids, the structure first written by
  `tools/r58_guildquests/build_structure.py`, checked by
  `tools/r58_guildquests/portable_test.lua`; the structure page is
  `tools/r58_guildquests/questmap.py`. Every reward is XP and the quest
  copper of the reward weight (quests.md "Copper"), no reputation; the
  camp hunts add a choice of materials (below).
  - **Gather quests** (free play, weight 4, opening at the tier's first
    level, reward level two above), two per tier, each the tier's
    signature resource and its gem: T2 `guild_t2_iron` (Iron Lump × 20) and
    `guild_t2_jade` (Rough Jade × 4); T3 `guild_t3_anthracite` (Anthracite
    × 20), `guild_t3_garnet` (Rough Garnet × 4); T4 `guild_t4_silver`
    (Silver × 15), `guild_t4_sapphire` (Rough Sapphire × 4); T5
    `guild_t5_emberglass` (Emberglass × 15), `guild_t5_ruby` (Rough Ruby ×
    4); T6 `guild_t6_crystal` (Abyssal Crystal × 10), `guild_t6_diamond`
    (Rough Diamond × 4). Counts are rough: about a quarter hour's digging in
    the tier (the yield model, §9). Each has one variant per faction whose
    givers are the role rows `foreman_tk` … `foreman_t6` of that faction,
    so every own camp whose lift reaches the tier gives it and takes it in
    (quests.md "The Miner's Guild givers"); the variant's text names its
    guild.
  - **Where they live:** a shared quest lives in its first variant's file
    and a variant's zone needs a quest file, so the gather quests live in
    the two guild files, `charter_of_stone.quests.json` (every gather
    quest; its first variant is The Accord's) and
    `oathdelvers.quests.json` (the Throng variant's zone; no quest of its
    own), whose zones are the guilds' ids. The loader reads them like
    every zone file; the quest log shows such a quest's level without a
    zone. Both are reworked: the free-play rules and the reward checks
    apply to them.
  - **Follow-ups** (story quests, weight 1.5, the gather quests' levels):
    `guild_t<k>_report_accord` and `_throng`, one per tier and faction. Each
    requires both gather quests of its tier (two requirements: a story
    quest, `E-free-requires`) and is a travel quest to a guild leader, one
    variant per zone with an own camp of tier ≥ k (that zone's foremen give
    it; 14/11/7/4/2 variants per faction for T2…T6). Per faction, because a
    Battlegrounds zone holds both factions' camps, a variant is keyed by its
    zone, and a talk objective names one NPC. The leader is the capital's of
    the zone's race region; a Battlegrounds zone is one faction's race
    region, so the other faction's camps there report to the race across the
    front (dwarf–undead, human–orc, elf–troll: the zones' columns): The
    Broken Causeway and The Shattered Line to Highcourt and Gor Drazhak,
    Gravesalt Escarpment to Dur Brannoc and Nhal Veyr, The Skyglass Canopy
    to Lethariel and Kezamba. The variants carry a completion text; the
    tier's story seed (the story-arc decision §5) is each quest's design
    note for GUILDTEXT.
  - **Camp hunts** (free play): a role near the camp, in a quest-target
    kind of the camp's level belt (the zone's lowest belt; a war camp's high
    band the highest), that the zone's own quests (its file and the front
    files) do not hunt yet, by role or by name; a role met by day first (8
    kills, weight 3.5), else a night-only one (3 kills, a third of the day
    count, weight 2.5). One shared quest per camp band and clock, a variant
    per camp zone given by its foremen: by day `camp_hunt_t2` (6 zones,
    reward level 12), `camp_hunt_t3` (7, level 22), `camp_hunt_t4`
    (Stormvault, Ashenward, Glassroot, Bannerbreak; 32), and for the war
    camps `camp_hunt_t5_low` (42), `camp_hunt_t5_high` (49),
    `camp_hunt_t6_low` (52) and `camp_hunt_t6_high` (59), each with its two
    Battlegrounds zones (the zone's Accord and Throng camps of that band in
    one variant; the low and high bands hunt different names); after dark
    `camp_hunt_t3_night` (Totemwater Reach) and `camp_hunt_t4_night`
    (Blackwind Rise, Thunderroot Wilds). Lorindor's quests already hunt
    every role by its camp, so its hunt keeps the stag (`moss_antler_stag`
    in the Berrywoods; `lorindor_cutting_opt_01` hunts it in the
    Paleroots). Every camp has one hunt; a T4 camp also the raid.
  - **The hunts' reward** (the user, 2026-10-23: materials for the hunt):
    besides XP and copper a choice of the camp tier's hunted leather, its
    cloth or a bar of its metal, none of which a vendor sells (Round 57
    ruling 28), so a hunt is a real source: T2 Light Leather × 4, Linen
    Cloth × 3 or Iron Bar × 2; T3 Heavy Leather × 3, Heavy Cloth × 3 or
    Steel Bar × 2; T4 Scaled Hide × 3, Raw Silk × 3 or Silversteel Bar × 2;
    T5 Sleek Pelt × 3, Raw Silk × 4 or Embersteel Bar × 2; T6 Sleek Pelt ×
    4, Raw Silk × 5 or Abyssal Steel Bar × 1. No equipment, so the reward
    budget counts none.
  - **The raid** `camp_site_raid` (free play, level 36, reward level 40,
    weight 4): one quest with a variant per contested T4 zone, given by the
    own T4 foreman, against the zone's camp under construction: its four
    guards and its captain (`guard_` and `captain_<builder faction>` in the
    area `<zone>/camp_site_<zone>`), as a war camp's raid. The guards are
    named by their slot `<zone>/camp_site_<zone>.guard/L38-40` of
    `data/names.json` ("Accord Stakeguard", "Throng Stakeguard";
    `pvp_garrison.lua` gives them the name key `<key>.guard`, written by
    `tools/r38_b1/gen_names.py --proposals
    tools/r58_guildquests/names_proposals.json`). The war-camp raids of
    the fortresses stay as they are.
  - **Files:** each surface camp zone's file gains a hub `<camp id>` with
    its foreman (lines `camp` and `guild`) and the guild quests whose first
    variant is that zone's; it keeps its own quests and its rework state
    (unflagged: its chains stay until its rework). The four Battlegrounds
    zones get a quest file of their own (not reworked: both factions'
    follow-ups there require the same gather quests, which the free-play
    count `E-free-follow-ups` read as two follow-ups until Round 59; since
    then it counts them per faction, as a player sees only their own
    faction's, [quests.md](quests.md) "Story and free play").
  - **The reward budget** (`E-reward-budget`) counts equipment rewards per
    zone a quest is given in, that is per variant zone: a role variant in
    its guild zone, an NPC variant in its camp zone. No guild quest rewards
    equipment, so it counts none anywhere.
  - All of a camp's quests can be taken at once (only the follow-ups wait
    for their two gather quests); nothing is repeatable; no kill objective
    lies in the depth (every kill area is a surface kind or a camp
    under construction).
