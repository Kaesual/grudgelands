# Items and professions across the tiers (Round 32 study R3)

Read-only study, 2026-10-03, on main `c8951467`. It prepares a design session
with the user and **decides nothing**. Every claim carries its source:

- **[measured]**: counted by the R3 scripts over the shipped data and a one-boot
  registry dump of the real game (method in the Evidence appendix);
- **[code]**: read in code, `path:line`;
- **[doc]**: the design documents (`docs/design/…`, BACKLOG);
- **[data]**: the shipped JSON (`grug_mobs/data/*.json`,
  `grug_professions/data/enchants.json`, the zone quest files).

Tiers: T1 = levels 1–10 … T6 = 51–60. "Band" is the same ten-level slice.

## Summary

1. **Gear comes from three places, none of them quests.** Vendors sell the
   Common floor (13 fixed items plus 4 rotating per bracket, and in one hour
   out of five one Uncommon at ×3). Everyone can craft the same base items.
   Mobs drop Uncommon gear at 3 % per normal kill. Not one of the 515 quests
   rewards gear: the 30 item rewards are wood, stone and metal picks and axes,
   dual furnaces and cooked meat [data]. On the 15 h pace a Mage finds about
   one usable piece every 2¼ hours [measured].
2. **Trinkets, spellbooks and bags above 8 slots exist only through a
   profession.** No vendor sells them and no mob drops them. There is also no
   way to pay another player: `grug_money` has no transfer and there is no
   trade window [code]. A player without the Goldsmith keeps both trinket
   slots empty for the whole game. A caster without the Goldsmith has no
   offhand.
3. **Three of the seven primaries make nothing.** Weaponsmith, Armorsmith and
   Woodcarver only enchant, apart from their T3 station [measured]. Besides
   enchants, the Leatherworker's T3 and T6 offer only a Weapon Grip, which has
   no use; the Tailor's T3 offers only a bolt bundle and its T6 nothing.
4. **Dead ends, all verified.**
   - 67 of the 94 signature drops have no recipe or enchant use: 33 are asked
     for by one or two quests, and 34 are used nowhere and only sold
     [measured].
   - Emberglass Shard, Cut Citrine, Feather, the mob "Bundle of Arrows",
     Weapon Grips (6 items) and Ornament Components (4 items) have no
     consumer.
   - The same holds for the six cultural materials and the Fallen Crown;
     the Fallen Crown cannot even be sold.
5. **The nine enchant stats differ by an order of magnitude in value.** One
   crafted Attack-speed enchant gives +4 % to +14 % damage. Strength gives
   about +2.6 % at every tier, and Crit +0.2 % to +1.2 % [measured from
   `combat_stats.md` §2].
6. **Crafted enchants beat ordinary found rolls at every tier; only boss loot
   is better** (T6 Strength: crafted 10, expected world roll 7.8, boss roll
   11.4) [measured from `grug_quality/init.lua:74-128`]. Item level, not the
   affix, makes boss weapons strong: ilvl 75 gives 30 base damage against 22
   for a crafted or vendor T6 sword.
7. **Money is mainly a mount meter.**
   - The whole 1→60 leveling income (≈ 8g36s) is about what the four riding
     tiers and the boats cost (8g86s) [measured].
   - Repair is 0.6–1.8 % of net income, and crafting costs no money.
   - After Master Riding, nothing at level 60 takes money in any amount.
8. **Designed but not built:** cultural finishes, PvP counters and the
   Warding Draught, Grudgeforged masterwork (ilvl 70), helper and
   cultural-master NPCs, item-level affix scaling, the Leatherworker ×5
   leather, First Aid bandages, apothecary gear, cut-gem storage blocks and
   universal reagents (§3).

## 1. The loop as it is

### 1.1 Where items come from

| Source | What | Tiers | Facts |
|---|---|---|---|
| **Vendors** (race, general, smith, armourer, bowyer, tanner) | Common sword + 12 armour pieces fixed, 4 of 5 extra weapon families hourly (dagger, battle axe, staff, wand, bow), 1 rotation in 5 an Uncommon at ×3 price | own bracket and every lower one | `grug_traders/stock.lua:94-99, 156-178, 230-244` [code]; the Uncommon is **live** (gated only on the roller existing), although `items_crafting.md` §3.8 wanted it lit only after an economy pass [doc] |
| **Basics crafting** (everyone) | every base weapon, tool, armour piece and shield of all six tiers, bars, bolts, leather grades, graded wood | T1–T6 | `inventory_equipment.md` §4 [doc]; recipe inputs sell for 5–30 % of the vendor price (T6 sword 1s28c of bars vs 25s) [measured] |
| **Mob gear drops** | one uniform pick over the tier's 18 catalogue items (sword, dagger, battle axe, staff, wand, bow, 4 metal, 4 leather, 4 cloth); **no shields, spellbooks or trinkets** | ilvl = mob level ≤ 60 | normal 3 % Uncommon; elite 20 % Uncommon + 3 % Rare; named rare 100 % + 25 %; General 60 % + 25 % (`grug_quality/init.lua:102-111, 735-797`) [code]; dropped on the ground for whoever picks it up |
| **Bosses** | Kings: Fallen Crown + 1 Rare ilvl 70; dragons: 4 Scaled Hide + 1 Rare ilvl 75; personal, 24 h lockout | level 60+ | `grug_mobs/bosses.lua:164-227`, `grug_quality/init.lua:748-751, 799-814` [code] |
| **Named rares** | 10 patrol rares, 2–4 h respawn | ~20–45 | `grug_mobs/rares.lua:382-647` [code] |
| **Signature and material loot** | 24 drop families × bands, 94 signatures + 24 generic items; signature items come from catalogue sub-types placed by the 38 zone recipes | T1–T6 | `grug_mobs/data/drops.json` [data]; rolled per kill and dropped on the ground (`grug_mobs/subtypes.lua:344-362`) [code] |
| **Mining and gathering** | ores, six depth-tiered gems, Emberglass, Abyssal Crystal, herbs, crops, fish, six cultural materials | by tier rock and zone | `items_crafting.md` §3.0 [doc] |
| **Quests** | copper (8 % of the tier's Common weapon price × weight) and XP; 30 of 515 quests also give a tool, a dual furnace or 3 cooked meat; **no gear, no consumable, no material** | — | `grug_quests/registry.lua:82-91` [code], zone quest files [data] |

**Expected found gear per band** (3 % per normal kill, kills from
`tools/r29_e4/income.py`, a uniform pick over 18 items, filtered to what the
class may equip) [measured]:

| Band | Minutes (15 h pace) | Kills | Found Uncommon | Warrior usable | Scout usable | Mage/Priest usable |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 77 | 48 | 1.4 | 1.2 | 0.9 | 0.6 |
| 2 | 111 | 70 | 2.1 | 1.8 | 1.3 | 0.8 |
| 3 | 138 | 88 | 2.7 | 2.2 | 1.6 | 1.0 |
| 4 | 165 | 106 | 3.2 | 2.6 | 1.9 | 1.2 |
| 5 | 192 | 124 | 3.7 | 3.1 | 2.3 | 1.4 |
| 6 | 219 | 158 | 4.7 | 3.9 | 2.9 | 1.8 |

Elites and leaders add a little; the model counts normal kills only.
`items_crafting.md` §2.4 promises "a visible upgrade every 45–90 min (quest
rewards + 3 % world drops)". Quests give no gear, so for casters the drop
cadence alone is one usable piece per ~2¼ h. Whether a piece is an upgrade
is a further filter.

### 1.2 What players do with items

[code; agent survey checked]

- **Found gear** can be equipped, sold, repaired, or enchanted in place.
  There is no salvage or disenchant, and no recipe takes a gear item.
- **Selling is quality-blind:** a found Rare sells like a Common, at 5 % of
  the Common price, for example 1s25c for a T6 weapon (`grug_traders/prices.lua:312-314`).
- **Signature loot** is used in enchants, a few Basics weapons and alchemy,
  quest requests, or is sold for 7c × the tier factor (7c … 7s).
- **Profession products** (trinkets, spellbooks, potions, elixirs, dishes,
  bags above 8 slots, shields) sell for **0** to vendors [measured with the
  real price module]. With no player money transfer, their only value is
  personal use or a gift.

### 1.3 Professions: what each makes and needs

Recipes and enchant operations per tier, from the registry dump (stations
and automatic finishing counted as recipes) [measured]:

| Profession | T1 | T2 | T3 | T4 | T5 | T6 | Products (besides enchanting) |
|---|---|---|---|---|---|---|---|
| Weaponsmith | 0 / 34 | 0 / 34 | 1 / 34 | 0 / 34 | 0 / 34 | 0 / 34 | only the Forge (T3) |
| Armorsmith | 0 / 14 | 0 / 14 | 0 / 14 | 0 / 14 | 0 / 14 | 0 / 14 | none (shares the Forge) |
| Woodcarver | 0 / 18 | 0 / 18 | 1 / 18 | 0 / 18 | 0 / 18 | 0 / 18 | only the Carving Bench (T3) |
| Leatherworker | 2 / 10 | 2 / 10 | 2 / 10 | 2 / 10 | 2 / 10 | 1 / 10 | Weapon Grip per tier (no consumer); leather bags 8/16/24/32 at T1/T2/T4/T5; Tanning Rack |
| Tailor | 1 / 8 | 2 / 8 | 2 / 8 | 1 / 8 | 1 / 8 | 0 / 8 | cloth bags 8/16/24/32 at T1/T2/T4/T5; bolt bundles (bag inputs); Tailor Bench |
| Goldsmith | 10 / 14 | 9 / 14 | 11 / 14 | 10 / 14 | 10 / 14 | 10 / 14 | cut gems, settings, a spellbook and six trinkets per tier; Ornament Components T3–T6 (no consumer) |
| Alchemist | 4 | 4 | 13 | 8 | 8 | 6 | potions and elixirs (mixture + Brewing Stand finish); Brewing Stand |
| Cooking | 4 | 4 | 4 | 4 | 4 | 4 | two dishes + one raw assembly and its furnace dish per tier |

(cells: recipes / enchant operations; 588 operations in total)

**Inputs** [data, measured]:

- **Every enchant** costs three things:
  - the profession's own material of its tier (a bar, leather grade, bolt,
    graded wood or setting);
  - one stat loot item of the tier (five signatures at T1/T2, four from T3;
    the T3–T6 strap drops at 1 per outlaw kill);
  - one mined item for the equipment family: a bar, quartz, a raw gem, coal,
    Emberglass, Abyssal Crystal, Rock Salt or Stormkelp.
- **T6 needs Rough Diamond** for shield, dagger and trinket enchants. It
  sells for 400c and occurs once per 512 host nodes below y −1000.
- **Goldsmith:** a trinket costs 1–6 settings (2 bars each) plus the tier's
  cut gem(s): T5 needs Ruby + Sapphire, T6 Diamond + Ruby + Sapphire.
- **Alchemist:** herbs it gathers itself, plus generic mob drops (Bear Claw,
  Venom Sac, Shiny Scale, Crocodile Tooth, Stone Core, Sharp Feather, Fang).
- **Cooking:** crops, meat, fish and spices.

**Progression** (`professions.md` §1; `grug_jobs/state.lua:121-160`) [code]:

- 10 / 15 / 20 / 25 / 30 successful crafts at the current tier open the next.
- The profession tier is capped by the character band.

The cheapest progress craft per tier [measured]:

| Profession | Cheapest progress craft | Bill to reach T6 (100 crafts) |
|---|---|---|
| Enchant-only professions | an enchant: about 2 kills per craft at T1/T2 (1-in-2 loot) and 1 outlaw kill per craft from T3 (strap), plus a bar and a mined item | ~125 kills of the right families, plus 100 bars along the alloy chain and 100 mined items; at T3 the station recipe (20 Forges) also counts |
| Goldsmith | cutting a gem or making a setting | a few copper of inputs per craft, no kills |
| Leatherworker | a Weapon Grip (2 leather) | the grip has no use: it is progression fodder |
| Alchemist, Cooking | herbs or crops | cheap; little or no kills |

### 1.4 The loop per tier at a glance

[measured unless marked]

| Tier | Income / h | Common 6-slot set | One enchant: input sell value | Signature items (enchant / other recipe / quest only / sell only) | Distinct loot items dropping (share with a use) |
|---|---:|---:|---:|---|---:|
| T1 | 1s77c | 1s5c (36 min) | 9c | 11 (5 / 0 / 3 / 3) | 18 (83 %) |
| T2 | 4s35c | 2s55c (35 min) | 22c | 17 (5 / 1 / 7 / 4) | 27 (85 %) |
| T3 | 9s18c | 6s10c (40 min) | 52c | 21 (4 / 0 / 8 / 9) | 38 (74 %) |
| T4 | 24s39c | 15s20c (37 min) | 1s46c | 19 (4 / 0 / 3 / 12) | 37 (59 %) |
| T5 | 65s65c | 38s (35 min) | 3s24c | 10 (4 / 0 / 4 / 2) | 24 (83 %) |
| T6 | 1g45s | 95s (39 min) | 8s4c | 16 (4 / 0 / 8 / 4) | 33 (85 %) |

How to read the table:

- **Income** is `tools/r29_e4/income.py` as run today. Bands 5 and 6 are a
  little below the `economy.md` table (6866c and 14668c per hour); see the
  side note in §2.6.
- **Set price:** a Common set always costs about 35–40 minutes of the band's
  income.
- **"Share with a use"** counts an enchant, recipe or quest use. Band 4 is
  the weakest: 15 of its 37 dropping loot items are sell-only.

**T1 (1–10).** Vendor floor and Basics gear dominate. The 1–2 found
Uncommons roll 1–3 per stat.

- Crafted T1 enchants are tiny: +2 Strength moves floored melee damage only
  sometimes, and +0.5 Crit is negligible. Only Attack speed (+4 %) and Armor
  (+1, about +2.6 % effective HP) are noticeable.
- Gathering pays and quests teach the dual furnace.
- Professions start here. The Goldsmith gets trinkets at once (Cut Quartz).

**T2 (11–20).**

- Bags of 16 slots appear, and Journeyman unlocks spellbooks (crafter level
  16+).
- Antivenom and Swiftness are the only T2 potions; no T2 healing potion
  exists.
- Seven T2 signatures exist only for one quest each.

**T3 (21–30).**

- The T3 station recipes count as progression crafts.
- The Alchemist's richest tier: 6 potions and elixirs.
- 9 sell-only signatures. Crocodile Tooth and Shiny Scale (T4 items) drop in
  bands 2–3 (Round 30 carry-over).

**T4 (31–40).**

- PvP from depth T4.
- Leather and cloth 24-slot bags.
- 12 sell-only signatures, the worst band.
- Emberglass Shard was added as filler loot (Round 30 lane E) and has no use.

**T5 (41–50).**

- The fewest signatures (10).
- The 32-slot bags (Master).
- Embersteel's chain demands Silver, Emberglass, Steel and Coal per bar.

**T6 (51–60).**

- Enchant inputs reach Rough Diamond and Abyssal Crystal.
- Tailor and Leatherworker make no bag at T6.
- At 60 the only goals are:
  - Kings and dragons: ilvl 70/75 Rares with a 24 h lockout. The Crowns
    they also award have no use.
  - Master Riding: 7g33s, about 5 h of income.
  - PvP fortress Generals: ilvl 65.

### 1.5 Money: sources and sinks

**Sources** [measured]:

- Quest copper: 66c in band 1 → 14 180–17 160c in band 6, per route.
- Selling loot: the median kill pays 4.3 / 9.0 / 16.7 / 43.6 / 119.5 / 239.3c
  in bands 1–6. The band-6 median is 0.80 of its target axis (BACKLOG Round
  30 carry-over).
- Selling gathered goods.

Leveling 1→60 nets about **83,600c ≈ 8g36s** on the income model.

**Sinks:**

| Sink | Size | Share of income |
|---|---|---|
| Riding and boats | 1s10c + 7s + 1g37s + 7g33s, boats 1s10c + 7s = **8g86s** | ≈ 106 % of the whole leveling income; the dominant sink by far |
| One Common set per tier | 1g58s for all six | about 19 % |
| Repair | e.g. 335c over the 219-minute band 6 (`income.py`); a full repair of a fully broken T6 Common set costs 19s | 1.8 % of net income in band 1, falling to 0.6 % in band 6 |
| Respec | 15c … 12s, the first one free | — |
| Supplies | potions 8c, bottles 3c, thread, arrows | — |

Crafting costs **no money**: enchants consume items only, and no service fee
exists. The cultural-master fee tables (`economy.md` §4) are unused because
the masters do not exist.

## 2. Where it lacks reward or sense

### 2.1 Dead ends

Every item below was checked for a consumer: engine recipes, profession
recipes, enchant operations, smelting and quest objectives, with item groups
expanded [measured].

| Item(s) | Source | Today | Note |
|---|---|---|---|
| **34 sell-only signatures** (e.g. Bandit Talisman T1, three Crab Shells T2/T4/T6, Razor Cat Claw, Scarred and Salt Bear Claw, Gravewood Resin, Bone Chitin, Coarse Spider Silk, Campaign Purse, Marching Bone, five Feathers, three Cores) | their family's band table | sold only | the catalogue README itself said "remove that unused signature and its icon" when no quest claims it |
| **33 quest-only signatures** | as above | 1–2 quests ask for 2–5 items each, then they are vendor trash | 3 of them sit in a repeatable quest |
| Emberglass Shard | stone T4 and weevil T4 at 1-in-2 (Round 30 filler), crystal shard, dungeon master | sold only (16c) | a "WP43 migration target" comment in `grug_smelting/recipes.lua:92` (fresh-server mode removes migration leftovers) |
| Cut Citrine | Goldsmith T1 cut from Rough Citrine | no consumer | T1 trinkets use Cut Quartz (Round 29 carry-over, accepted); the Citrine Block has no recipe |
| Feather | crows, eagles, vultures; scavengers T3–T6 at 1-in-2 | no consumer | the **Bowyer sells it** (`profession_stock.bowyer`) |
| Bundle of Arrows (`grug_mobs:arrow`) | skeletons T3–T6 at 1-in-5, slingers and archers | sold only (2c) | not the Scout's `grug_gear:arrow` |
| Weapon Grips ×6 | Leatherworker T1–T6 | no consumer, sells 0 | the doc says "without a current consumer"; they still count as progression crafts |
| Ornament Components T3–T6 | Goldsmith | no consumer, sells 0 | — |
| Six cultural materials | gather nodes (1/4096 columns, 1/1024 in the concentrated zone with a T4 tool gate) | sold only (1c) | their only purpose, finishes, is unbuilt |
| Fallen Crown | every King kill, per participant | no consumer, **unsellable** | meant for the unbuilt Grudgeforged upgrade |
| Six gem storage blocks | registered nodes | no recipe | optional WP10 item |

### 2.2 Crafting versus loot per tier

Value of one stat, crafted versus found [measured from `grug_quality/init.lua:74-128`]:

| Tier | Crafted Strength | Found, world window (expected) | Found, boss window (expected) | Crafted Attack speed | Found world / boss |
|---|---:|---:|---:|---:|---:|
| T1 | 2 | 1.6 | — | 4 % | 3.9 / — |
| T2 | 3 | 1.6–2.9 | — | 6 % | 3.9–5.2 |
| T3 | 5 | 2.9 | — | 8 % | 5.2 |
| T4 | 7 | 5.2 | — | 10 % | 7.8 |
| T5 | 9 | 5.2–7.8 | — | 12 % | 7.8–10.4 |
| T6 | 10 | 7.8 | 11.4 (ilvl 70/75) | 14 % | 10.4 / 15.2 |

- **Crafting is never pointless next to ordinary loot.** A crafted channel
  beats the expected world and elite roll at every tier. Enchanting can also
  replace a found affix in place, so loot and crafting combine.
- **Loot is not pointless next to crafting either:** item level carries the
  weapon. A crafted or vendor T6 sword is ilvl 50 (22 damage); a found ilvl-60
  sword has 25, an ilvl-75 dragon sword 30. The ideal endgame item is a boss
  base with crafted affixes.
- **Two weak spots.**
  - **T1:** crafted values are so small that enchanting barely shows (below).
  - **Found affixes do not scale within a band.** ilvl 46 and 75 roll the
    same 6–12 Strength, so boss gear differs only by its roll window and base
    (BACKLOG "Enchantment and item-level revision").
- **Enchants live for one band.** Each band's new base item restarts the
  bill. A full Rare set needs 16 operations, worth 1s44c (T1) to 1g28s (T6)
  in sold inputs, about 50 minutes of income at every tier.

### 2.3 The nine stats are not worth the same

A Warrior at the band's middle level with the band's vendor sword (`combat_stats.md`
§2: melee = weapon + floor(Str/10); crit ×1.5; armor `rating / (rating + K)`)
[measured]:

| Tier | +Str enchant | +Crit enchant | +Attack speed | +HP % | +Armor (plate + shield) |
|---|---:|---:|---:|---:|---:|
| T1 | +2.8 % dmg | +0.24 % dmg | +4 % dmg | +1 % HP | +2.6 % effective HP |
| T3 | +2.6 % | +0.58 % | +8 % | +2 % | +3.8 % |
| T6 | +2.6 % | +1.18 % | +14 % | +5 % | +4.1 % |

- **Attack speed** is the dominant weapon stat.
- **Strength** stays at about 2.6 %. Its weight shrinks only because the
  class's own Strength growth (3 per level) dwarfs the enchant.
- **Crit** is nearly worthless as an affix.
- **Dexterity** (0.1 % crit and 0.1 % dodge per point) for non-Scouts is
  weaker still.

The design's budget is "+5 % per slot" (`items_crafting.md` §6.3), and most
stats sit well below it. This is the "balance pass over all nine stats" the
BACKLOG item names.

### 2.4 Items nobody can buy, find or pay for

[code, measured]

- **Trinkets (both slots) and spellbooks** are Goldsmith-only. No drop, no
  vendor, no quest. The spellbook also needs a crafter of character level
  16+ (Journeyman, `grug_jobs/state.lua:181`).
- **Shields** cannot be bought or found, but anyone can craft them (Basics).
- **Bags of 16–32 slots** come only from the Tailor or Leatherworker; only
  the small 8-slot bag is sold.
- **No player-to-player money.** `grug_money` offers
  get/set/add/take/take_with_inventory only (`grug_money/init.lua:47-140`);
  `/money give` is admin-only. There is no trade window or mail.
- **The design assumes a market:**
  - "interdependence drives the server economy" and "a pure fighter instead
    buys enchanted gear from crafters" (`professions.md` §1, `items_crafting.md`
    §2.4);
  - "player trade is their intended high-value market" (`economy.md` §3).

Round 28 made professions self-contained precisely because forced
interdependence felt bad. Yet the trinket slots, the caster offhand and the
large bags still depend on one profession, with no way to pay its crafter.

### 2.5 Profession progression

- **Late starters** must craft through every lower tier. Lower-tier crafts
  count only at the current tier, and the threshold resets.
  - A level-45 player who learns Weaponsmith needs 10 T1 enchants (boar
    tusks, rat tails … from start-zone mobs that give no XP), then 15 T2,
    20 T3 and 25 T4 before T5 crafts count.
  - Switching a profession at 50 costs the same again.
  - Goldsmith, Alchemist and Cooking catch up easily (gem cutting, herbs);
    the enchant-only professions do not.
- **Throwaway crafts count.**
  - At T3 every profession's station recipe is a progression craft
    (`grug_jobs/stations.lua:109-114`). Twenty Forges (60 Steel Bars, 20
    furnaces) open Weaponsmith T4.
  - The Leatherworker's grips (2 leather each, no use) are its cheapest
    progression at most tiers.
- **Mastery gates are thin.** Mastery (Apprentice … Master) gates only bag
  sizes and the spellbook; the enchant tiers follow the profession tier.

### 2.6 Money

- **Sources and sinks** (§1.5):
  - Income per hour scales ×2.1–2.7 per band.
  - Riding is the one large sink.
  - After Master Riding a level-60 character earns about 1g45s per hour and
    has nothing to spend it on (no fees, a negligible repair share, no
    crafting fee, no player market).
- **Repair** costs 20 % of the reference price for a full lifetime: 1000–4000
  uses, ×3 for Uncommon and ×6 for Rare (`grug_repair/service.lua:17-22`,
  `grug_gear/init.lua:410-432`). It is 0.6–1.8 % of net income (`income.py`)
  and does not shape decisions.
- **Found-gear sale price:**
  - Buy-back is by item name only (5 % of the Common price), so a found
    Rare is worth as little as a Common.
  - Unusable drops are near-worthless: a T6 Rare weapon sells for 1s25c,
    against 7s for one T6 signature.
- **Side observation (not investigated):** `python3 tools/r29_e4/income.py
  --check` fails on main today. The estimate gives Expert Riding 1g31s,
  Master 7g25s and respec 41–50 5s50c; the shipped values are 1g37s, 7g33s
  and 6s. The quest data probably moved after Round 30 (Round 31's fortress
  quests).

### 2.7 Band outliers

- **Band 4** has the weakest loot use: 15 of 37 dropping items are sell-only
  (§1.4).
- **Band 6** pays 0.80 of its target axis (BACKLOG).
- **Band 5** has only 10 signatures.
- **Crocodile Tooth and Shiny Scale** (T4) drop in bands 2–3 (BACKLOG Round
  30 carry-overs).
- **Raw Silk** is catalogued T1 (band-1 spiderlings) but feeds the T4–T6
  bolts, so a T5 Silk Bolt sells for 4c against 28c for a T4 Silkweave
  Bolt [measured].
- **Healing potions stop at T3** (Greater Healing); T4–T6 have elixirs only
  (`items_crafting.md` §3.6). The potions heal by percentage, so this may be
  intended.

## 3. Open parts: designed, not built

Status [code] from the two code surveys, spot-checked by grep over `mods/`:

| Feature | Design | Code |
|---|---|---|
| Cultural finishes (per-stack channel, 6×6 effect matrix, own-culture crafter) | `items_crafting.md` §4.2; WP5, WP10 | absent; only the culture/material/wood tables `grug_materials/registry.lua:270-314` (used by an audit and mapgen) |
| Cultural materials as recipe inputs (candles, seals, tablets, war paint) | §4.1 | items and gather nodes exist (`grug_materials/ores.lua:133-148`, `grug_gathering/catalog.lua:266-335`), **no consumer** |
| PvP weapon counter finish | §4.3.1 | absent; no flat-add seam after crit in `grug_core/combat.lua`; mobs have no race identity except kings and royal guards |
| Warding Draught | §4.3.2 | absent; only a status icon "planned, no caller yet" (`grug_core/status_icons.lua:71-73`) |
| Grudgeforged masterwork → ilvl 70, Fallen Crown as input | §3.0.1, §5.4; WP5 (D3) | absent; the Crown exists (`grug_mobs/bosses.lua:253-258`) with no consumer and no price |
| Helper services: cultural masters, weapon-counter helper, Alchemist helper; their capital sockets | `economy.md` §4, `world.md` §7; WP10 (D11) | absent; no socket role reserved |
| Affix scaling by item level, balance pass of the nine stats | BACKLOG "Enchantment and item-level revision" | four flat bands (`grug_quality/init.lua:74-91`) |
| Dungeon gear ilvl 65 | §5 | no dungeons |
| Leatherworker ×5 leather from tagged kills | `professions.md` §3 | hook pipeline exists, nothing registered (`grug_mobs/aggro.lua:693-711`); the tag stores no profession |
| First Aid bandages (Linen/Heavy/Silk; the no-healer valve) | `items_crafting.md` §3.7, `professions.md` §1 | absent |
| Apothecary gear (`grug_apothecary` group), imbuing oils, Sovereign's Flask | §3.6 | only the reader `grug_alchemy/effects.lua:13-20`; no item |
| Universal reagents (e.g. a tin and quartz mix) | `crafting_equipment_revision.md` | loader ready, `reagents.json` empty |
| Cut-gem storage blocks (9 ↔ 1) | §3.0.1; WP10 optional | nodes registered, no recipe |
| Rotating vendor Uncommon only after an economy pass | §3.8 | live at ×3 already |
| Royal guard loot "ordinary level-60 elite loot" | §5.4 (contradicts §5.1) | guards drop no gear (`grug_quality/init.lua:785`) |
| Elite loot windows by zone (31–60) | §5 table | the window depends on the source tier only |
| Player-to-player trade | `economy.md` §1, §3 | absent |

Built and working: the trinket specials (`grug_trinkets/init.lua:93-157`),
both bag lines, spellbooks, the Goldsmith bonus gem roll
(`grug_artisans/goldsmith.lua:129-154`), the named-rare loot, the King Crown
ledger, repair (trainers and claim stations) and the same-race discount.

## 4. Proposals

The proposals are coherent packages, from small to large. They combine:
options 1 + 2 make a "fix the feel" round; 3, 4 and 5 are larger directions. Effort is
in the project's own units: **S** = part of one lane, **M** = one lane,
**L** = two or three lanes, **XL** = a round of its own.

### Option 1: Close the dead ends and fix progression (S–M)

- **Per tier.** Every drop either has a use or is plainly vendor loot.
  - Feather fletches arrows, or leaves the Bowyer shelf.
  - Bundle of Arrows unpacks to Scout arrows, or is cut.
  - Emberglass Shard is cut, or 3 shards make 1 Emberglass.
  - Cut Citrine becomes the T1 trinket gem, or its recipe goes.
  - Grips and Ornament Components get one consumer each, or are removed.
  - The Fallen Crown gets a sell value.
- **Late starters** may count lower-tier crafts, or a new profession starts
  at the character's band minus one.
- **Station crafts** no longer count as progression.
- **Sell-only signatures:** the 34 are kept as named vendor loot (a class
  "trophy", like the purse) or trimmed per band.
- **Systems:** `grug_mobs/data/*.json`, Basics and profession recipes,
  `grug_jobs/state.lua`, shelves, the price audit.
- **Risks:**
  - The anti-loop audit: a new recipe must not pay out more than its inputs.
  - Loot medians move when rows change; re-run `band_payout.sh` and
    `income.py --check`.
  - Removing icons touches `LICENSE-media.md`.

### Option 2: Value pass, so stats and item level mean something (M)

- **Per tier:**
  - Every enchant is worth roughly the design's +5 % per slot.
  - Strength, Crit and Dexterity rise, or Attack speed falls.
  - T1 values become noticeable.
  - Found affixes scale with item level (linear, or 6–10 finer bands), so an
    ilvl-75 dragon drop clearly beats an ilvl-46 drop.
  - Optionally, crafted values scale with the **item's** tier up to the
    enchant's tier, and found Uncommon/Rare sell at their quality multiplier.
- **Systems:** `grug_quality/init.lua` (bands, enchant values, windows), the
  combat formulas only if the stat weights change, `prices.lua` (quality
  sell), `combat_stats.md`, `items_crafting.md` §6. This is the BACKLOG item.
- **Risks:**
  - The +50–60 % endgame ceiling must be re-derived.
  - PvP balance.
  - Existing stacks re-describe on the next change only (fresh-server mode:
    no migration needed).

### Option 3: A crafter's market (M)

- **Per tier:** crafters can sell trinkets, spellbooks, bags and enchanting
  to other players for money. A pure fighter can fill both trinket slots
  without the Goldsmith.
- **Smallest form:** a two-player trade window (both confirm; items and
  copper swap atomically, like the repair transaction).
- **Larger forms:**
  - an "enchant for another player" mode at the station (the customer
    supplies the item and pays);
  - a trainer commission board.
- **Systems:** `grug_money` (transfer), a new trade UI, `grug_jobs`
  workspaces for the service mode, faction rules (same faction only?), PvP
  (no trade in combat).
- **Risks:**
  - Duplication and scams; this needs transactional checks like repair's.
  - The economy's income model assumes no market.

### Option 4: Every profession makes something per tier (L)

- **Per tier.** Enchant-only professions gain products that use the
  signatures.
  - **Weaponsmith and Armorsmith "fine" bases:** the base item at the top
    of the band's item level (ilvl 10/20/…/60 instead of 3/10/…/50, or
    +5), costing bars plus two or three of the band's sell-only signatures.
  - **Woodcarver:** fine bows, staves and wands the same way.
  - **Leatherworker and Tailor:** T3 and T6 bags or utility items (the
    quiver upgrade, a T6 bag).
  - **Alchemist:** T4–T6 healing and the Warding Draught.
  - **Goldsmith:** gem-block recipes and Ornament Components as a trinket
    upgrade.
- **What it fixes:**
  - This would give most of the 67 unused signatures a recipe use.
  - Crafters gain a reason to exist beyond enchanting.
  - The intended "crafted is better than vendor" step returns, without
    forcing interdependence.
- **Systems:** the profession recipe files, `grug_gear` (per-stack ilvl on
  crafted output: the drop path already writes `grug_ilvl` per stack),
  `drops.json`, the price audit, Basics visibility.
- **Risks:**
  - The vendor floor rule ("vendors sell the same item crafters start from")
    holds, but crafted bases out-scale vendor bases.
  - The found-vs-crafted audit must be redone.
  - The icon and art count grows.

### Option 5: The endgame layer, WP5/WP10's remainder (XL)

- **Per tier:**
  - From T1, cultural finishes on weapons and armour: each culture's fixed
    stat, using the six cultural materials that are dead today.
  - From T4, the PvP weapon counter and the Warding Draught.
  - At 60, Grudgeforged lifts any item to ilvl 70 with a Fallen Crown and
    T6 materials.
  - Cultural masters in the capitals perform finishes for a fee, the first
    money sink after riding.
- **Systems:**
  - `grug_quality` (two new per-stack channels);
  - `grug_core/combat.lua` (counter flat add after crit, ward after armor);
  - mob race identity;
  - new NPC sockets in six capitals and a cultural-master NPC;
  - `grug_alchemy`;
  - art (trims, markers).
- **Risks:**
  - Size: a full round.
  - It touches the combat path (the PvE micro-run must stay unchanged).
  - New capital sockets touch the capital planner.
  - Balance with option 2's numbers; best decided after option 2.

## 5. Questions for the design session

1. **Market:** should players be able to pay each other (trade window,
   service mode), or do professions stay strictly for oneself?
2. **Trinkets, spellbooks and large bags:** keep them profession-only, or
   also give them through bosses, quests or a vendor at Common?
3. **Quest gear:** should quests reward gear (the design cadence counts on
   quest rewards; none exist), and at which beats?
4. **The 67 signatures without a recipe use:** give them recipes (option 4),
   accept them as named vendor loot, or trim them?
5. **Enchant-only professions:** is "Weaponsmith/Armorsmith/Woodcarver only
   enchant" the intended identity, or should they make better bases?
6. **Stat values:** should the nine enchant stats be worth roughly the same
   (today Attack speed 4–14 % against Strength about 2.6 % and Crit at most
   1.2 %)?
7. **Item level:** found affixes scaling with ilvl, crafted values scaling
   with the item tier, crafted bases above vendor ilvl. Which of these?
8. **Found-gear value:** should an Uncommon or Rare sell for more than a
   Common?
9. **Masterwork:** Grudgeforged at ilvl 70. Its inputs (the Crown?), who
   performs it, and does it stack with a boss item that is already ilvl 70/75?
10. **Cultural finishes and the six cultural materials:** build them, or cut
    the materials and their gather nodes?
11. **PvP counters and the Warding Draught:** still wanted for V1?
12. **Money at 60:** after Master Riding, what should money buy (master
    fees, higher repair, cosmetics, housing)?
13. **Late starters:** may a profession learned at level 45 start nearer the
    character's band?
14. **Throwaway progression:** should station crafts and grips count as
    progression?
15. **Small promises:** keep or drop the Leatherworker ×5 leather, First Aid
    bandages, apothecary gear, gem storage blocks and universal reagents?
16. **The vendor Uncommon** is live at ×3 although the doc wanted an economy
    pass first. Keep it as is?

## Evidence

- **Worktree:** `/home/jan/projects/grudgelands/.claude/worktrees/r32-r3`
  (detached at `c8951467`, left clean).
- **Engine run:** one headless boot, 44 s, through `tools/luanti_headless.sh`
  (`LC_ALL=C`, `chrt --idle 0`). It staged the disposable probe
  `~/projects/grudgelands-orchestration/r32/r3-evidence/probe/grug_probe_r32_r3`.
  The probe dumped every registered item (groups, `_grug_` fields,
  ingredient tier, `grug_traders.sell_price`), every engine craft recipe with
  inputs, every profession recipe and station operation, the smelting
  recipes, the trader stock and the gear catalogue. The output is
  `r3-evidence/r32_r3_probe.json` and the log is `run1_server.log`. The run
  directory was removed afterwards.
- **Scripts** (Python 3, read-only) in `r3-evidence/scripts/`:

  | Script | Produces |
  |---|---|
  | `common.py` | shared loaders |
  | `consumers.py` | consumer map and catalogue classification, `consumers.json` |
  | `professions.py` | recipes and operations per profession and tier |
  | `bands.py` | loot uses per band, `bands_table.md` |
  | `economy.py` | `economy_table.md` |
  | `enchant_value.py` | `enchant_value.md` |
  | `gear_drops.py` | `gear_drops.md` |
  | `progression_bill.py` | `progression_bill.md` |

  Also `quest_only.md`. Repository tools used: `tools/r29_e4/income.py`
  (and `--check`).
- **Code surveys:** two read-only sub-agents mapped the loot pipeline and the
  design-versus-code status. Their key claims were re-checked by hand
  (`grug_quality/init.lua:74-128, 735-797`; trader Uncommon gate; grep for
  absent features; gem block recipes absent in the dump).
