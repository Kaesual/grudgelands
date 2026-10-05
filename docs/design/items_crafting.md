# Items, Crafting & Loot — Full Design Spec

**Decided spec** (authored + approved 2026-08-06; the surviving four flagged
points P1–P4 are recorded in §10).

**Reworked 2026-08-07** (crafting rework session): the material ladder is
now six tiers (§3.0), the tome chain is replaced by one UI recipe book per
profession (§2.2), professions **enchant** instead of owning
the item catalog (§3.3–§3.6b, §6b), and there is **exactly one item per
concept** — the vendor bracket catalog and the base craft ladder are the
same, material-named items (§3.0.3). Resolutions in §10.

**World-zone revision 2026-08-10.** Surface progression is now keyed by the
stable named zones and level bands in `world_zones.md`, not by WP18's radial
ring names. Any surviving ring wording below describes shipped calibration;
WP40 must translate placement to the named-zone catalog without changing the
item, tier, depth or economy rules.

**Material-system integration 2026-08-12.** Six universal metals now form a
non-circular pick/depth spine. Since Round 24 (2026-09-29) the pick tier is
checked against the tier of the rock or resource, not against y (§3.0.4). Emberglass and Abyssal Steel replace the old
Emberstone/Mese and Grudgesteel targets. Six depth-tiered gems (Round 29),
the final Goldsmith/trinket model and the rebased 25c→25s Common-price axis
are authoritative below; cultural finishes, the cultural materials and the
PvP-special channel were removed in Round 33. Private housing
isles, guild systems, finder items and the Amplifier are absent from the target
design. Historical decisions in §10 remain design history only.

Feeds: WP5 (loot/enchant rolls), WP7 (traders/consumables), WP10
(professions/workbenches), WP22 (repair). Crafting mechanics frame:
`inventory_equipment.md` §4 (3×3 grid, multi-stage, profession-level
permission gate and recipe-book UI).

**Notation (binding, 2026-08-07).** `T1`–`T6` **always** means a *gear /
material* tier (§3.0). The four **mastery** tiers are **always written by
name** — Apprentice, Journeyman, Expert, Master — never as "T4". The two
ladders are independent; §2.1 spells out how they meet.

## 0. Decided anchors (2026-08-06, binding — preserved)

- **Quality tiers: Common (white), Uncommon (blue), Rare (yellow),
  Unique (orange)**. MVP ships without Uniques, but quality field +
  enchant list live in item meta from day one.
- **Ordinary equipment:** Uncommon = exactly one affix; Rare = exactly one
  prefix plus one suffix. The same family pool is legal on either side and a
  stat may not repeat. Common has none.
  Trinkets use their fixed one-prefix/one-suffix/one-special exception (§6.2).
- Vendors sell simple (Common) gear — available but painfully expensive;
  better gear comes from **crafting** or **special bosses**. *Sharpened
  2026-08-07*: "crafting" means **enchanting** (§6b) — the
  plain base item is the same item the vendor sells (§3.0.3).
- Items are **upgradeable via crafting within limits**: an upgraded
  mediocre item never becomes a top item. No upgrade failure chance.
- **The harder the enemy, the better the loot** — elites and named mobs
  drop more often and in better quality, bosses always drop two blue or gold
  items at a higher item level with T7 enchants (§5.1), same mechanic
  everywhere.
- **Rare patrol mobs** with special loot as raid incentive into enemy
  territory; each of the six race **Kings** is a heavily guarded raid boss
  whose drops reach item level 65.
- **Class/profession synergy intended** (Warrior+Weaponsmith or Armorsmith,
  Priest/Mage+Tailor, …).
- Gems are depth-tiered and the same everywhere (§3.0.1, Round 29).
  Universal picks never require a gem or trophy.
- Material tiers mirror classic MMOs: vendor supplies (thread/vials) as
  small gold sink; world materials tiered by source level. Authored city/POI
  stations are personal workspaces; crafted player-placed stations are shared.
  Bags have parallel Tailor and Leatherworker lines.
- Vendor rule: vendors sell supplies, consumables, tools, the Common gear
  floor and a few T1 basics; never an enchant input and never a crafting
  ingredient above T1 (professions.md §4, economy.md §2).
- **One item per concept** (decided 2026-08-07, binding): no two items
  may fill the same role. The vendor bracket catalog *is* the base craft
  ladder, and both are material-named (§3.0.3).
- **Everyone crafts the base items of every material tier**; professions
  enchant them and hold a few exclusive recipes per mastery
  tier (§3.3–§3.6b, §6b).

## 1. Reference research (2026-08-06)

Reference-study history moved to
[the items history archive](../archive/design/items-history.md#1-reference-research-2026-08-06).
Current source-derived rules remain in the topical sections below.

### 1.1 Lord of the Test: the crafting-book chain (studied in source)

See [archived §1.1](../archive/design/items-history.md#11-lord-of-the-test-the-crafting-book-chain-studied-in-source).

### 1.2 VoxeLibre: harvestable item-family templates (verified per mod)

See [archived §1.2](../archive/design/items-history.md#12-voxelibre-harvestable-item-family-templates-verified-per-mod).

## 2. Profession progression: the two ladders & the recipe book

**Revised 2026-09-18:** the profession recipe book is UI and exposes its catalog;
profession level is the sole recipe-permission progression. There are no book
items, per-recipe unlocks, keystone redemptions or ingredient-discovery
unlocks for profession recipe permission. The 2026-09-20 Basics visibility
amendment below is a presentation rule, not a crafting-permission unlock.

### 2.1 The two ladders (mastery vs. gear) — made explicit 2026-08-07

There are **two independent ladders**. They are not alternatives; both
stay, and they never mean the same thing.

**Ladder 1 — mastery** (this table, unchanged since 2026-08-06). Four
tiers, one per quarter of the level curve. Mastery is a property of the
*crafter*.

| Tier | Name | Item levels | Learn at ~char level | Ring that feeds it |
|---|---|---|---|---|
| 1 | Apprentice | 1–15 | 1 (trainer) | start + home zones |
| 2 | Journeyman | 16–30 | ~15–18 | home + heartland (+depth mining) |
| 3 | Expert | 31–45 | ~30–33 | contested approaches/front |
| 4 | Master | 46–60 | ~46–50 | high front + named rares |

**Ladder 2 — gear/material, T1–T6** (§3.0). Six tiers, one per ten
character levels, matching the six vendor brackets of §3.8 exactly:
1–10, 11–20, 21–30, 31–40, 41–50, 51–60, ilvl anchors 3 / 10 / 20 / 30 /
40 / 50. Gear tier is a property of the *item*.

Three statements close the 4-vs-6 question for good — none of them is a
new rule, all three were implicit before:

1. **Enchant values follow item level up to their tier** (Round 33,
   [item_tiers.md](item_tiers.md) §1.1): a crafted enchant has its recipe's
   tier, a found one its item's tier; neither depends on the crafter's
   mastery.
2. **Profession tier gates enchant operations.** Every legal prefix and suffix
   is available in each T1–T6 tier; no mastery suffix gate or temper step remains.
3. **Mastery retains specialist recipes**, such as bag capacities and spellbooks;
   it does not add enchant slots. Recipe profession tier and explicitly declared
   specialist prerequisites govern crafting. Universal Basics routes are ungated.

| Profession | Retained specialist products |
|---|---|
| Weaponsmith | Physical-weapon enchantments |
| Armorsmith | Metal-armor and shield enchantments |
| Leatherworker | 8/16/24/32-slot leather bags; leather armour and bow enchants |
| Tailor | 8/16/24/32-slot cloth bags; spellbooks; cloth armour and spellbook enchants |
| Woodcarver | Staff and wand enchantments |
| Goldsmith | Rough→Cut gems; Settings; trinkets; trinket enchants |
| Alchemy (secondary) | Profession-gated mixtures for universal Brewing Stand finishing |

Enchant values and costs follow §6b, [item_tiers.md](item_tiers.md) and
[the current contract](crafting_equipment_revision.md#enchanting). Removed
Imbue/Temper recipes do not survive as mastery unlocks.

### 2.2 Recipe books are UI (revised 2026-09-18)

- Learning a profession at a trainer exposes its book. A book is not an item,
  is never bought, traded, carried, lost or consumed, and stores no state.
- Every learned book shows its complete catalog from T1 through T6. Recipes
  above the effective profession level remain visible but greyed, with the
  required profession tier and corresponding character-band floor
  ("Locked: needs Weaponsmith tier 3 (character level 21+).", in the tooltip
  and in the recipe view). A profession book's per-tier line counts these
  recipes ("T3: 4 locked"); Basics keeps its per-tier "Undiscovered" count.
  A station's book button lists only what the player can craft there.
  Greyed recipes are browsable but are never ingredient-navigation targets.
- The crafting page carries two primary book slots, one fixed slot for each
  framework secondary (Cooking, then Alchemy; Round 33), and the always-open
  **Basics** book below them. Empty learnable slots say **learn at a
  trainer**. Riding does not acquire a book slot.
- The Basics book derives its entries from existing non-profession engine and
  dual-furnace recipes. Those recipes remain registered by their owning mods
  and are not re-registered by the profession framework.
  A Basics recipe's tier (its "Undiscovered" count and sort order) is its
  output's material tier: the item's own tier, else its gear bracket, else
  its registered ingredient tier, else its item-level band; an output with
  none of these takes the highest tier among its inputs (a pick, block or
  rod takes its bar's tier), else T1 (Round 29).
- **Basics visibility (user decision 2026-09-20):** an explicit starter set is
  visible immediately: bootstrap wood/stick/torch/chest/furnace/wooden-hoe
  routes, every universal T1 weapon/tool/shield and metal/cloth/leather armor,
  the universal arrow, and T1 profession-free feedstock preparations. Additional
  universal recipes become visible after the first acquisition of their
  explicitly declared main material, rather than requiring every auxiliary
  ingredient to have been seen. Declarations are keyed by complete station,
  output, method/shape and input signature; missing, stale or ambiguous routes
  fail the catalog audit. Concrete acquired item names are persisted from all
  player-owned inventory lists, and group declarations match any acquired
  concrete member. This discovery remains recorded. Visibility
  never gates crafting: a level-1 character with the inputs may craft an
  Abyssal Steel base item. Character level does not reveal recipe tiers;
  material tier remains a catalog classification and item-level use/equip
  restrictions remain separate. Professional recipes keep their owning books.
- Every furnace, dual furnace and brewing stand carries the same book button,
  filtered to recipes for that station. Grid recipes remain beside the normal
  3×3 grid.
- **Ingredient navigation (decided 2026-09-28):** an ingredient cell of the
  selected recipe is clickable when the ingredient has a recipe the player's
  books already list (Basics, the primary professions, Cooking, Alchemy); its tooltip
  gains "Click to view recipe". A group ingredient uses the item the cell
  shows. The click keeps the current book when that view lists the
  ingredient; otherwise it opens the first of those books that does, and a
  station-filtered view falls back to that book's full view. It clears the
  search, selects the ingredient's first route and turns to its page. A Back
  button then restores the previous book, station, page, search, recipe and
  route (up to 20 steps). The grid looks unchanged at rest and on hover; raw,
  undiscovered and locked ingredients stay inert. Navigation ignores
  **inverse routes**: a route making X from one distinct ingredient Y, when
  some route makes Y from X alone with more slots (slab/stair back to block,
  block back to bar or lump). So mined materials such as cobble, sand, coal
  lump or snow stay inert, while bars (smelting) and planks (trees) stay
  clickable. Inverse routes remain listed and browsable in the book.
- A profession recipe is craftable only when the player has learned the
  profession and its profession level is at least the recipe tier. Universal
  base recipes (§3.0.3) remain craftable by everyone.
- Unlearning removes the book immediately and wipes that profession's level
  and current-tier count. Learning it again starts at T1.

### 2.3 Profession level and tier ingredients (revised 2026-09-18)

- Every profession starts at T1. Successful crafts of the **current** tier
  advance the fixed counter in `professions.md` §1; lower-tier crafts count
  nothing and above-tier crafts are refused.
- **Only real recipes count (Round 33):** enchants, upgrades and the
  profession's own end products (potion and elixir mixtures, dishes and raw
  dish assemblies, bags, trinkets, spellbooks). Stations and intermediates
  (settings, cut gems, bolt bundles) and every automatic
  furnace or brewing finish count nothing. A recipe registers as such with
  `material = true` or `progress = false`; every craft path and station
  operation awards progress through `grug_jobs.award_progress`.
- Character level caps the effective profession tier to the material bands of
  §3.0.1. Profession and item-use gates are independent: item-level requirements remain separate from profession qualification.
  Ordinary T1 weapons explicitly require level 1 through `_grug_req_level`;
  elevated found levels keep their actual item-level gate.
- Every profession recipe of tier N declares at least one tier-N ingredient.
  Lower-tier ingredients may accompany it; a higher-tier ingredient may not
  be hidden in a lower-tier recipe. Ingredient tier is registered explicitly
  through `grug_jobs.register_ingredient_tier(item, tier)` before the recipe.
- The former keystone tables are retired historical design data. No keystone
  item is registered or consumed and no workbench redemption advances a book.
  Regional ingredients still create travel and trade demand as recipe inputs,
  not as a second unlock state.

### 2.4 Pacing check (10–20 h to level 60; revised 2026-09-18)

~10–20 min per character level keeps each ten-level profession cap open for
roughly 100–200 minutes. The five current-tier craft thresholds are
10 / 15 / 20 / 25 / 30 (§2.3), so a player who works two professions beside
questing has a predictable craft goal in every band without a separate
redemption item or discovery grind. A pure fighter instead buys enchanted gear from crafters; both paths remain inside the 10–20 h envelope.
**Intended gear cadence: a visible upgrade every 45–90 min** (quest
rewards + the world drops of §5.1 between the six material tiers, §3.0),
and at 60 the professions stay load-bearing via consumables
(elixirs/potions) and named enchant application/replacement (§7). V1 repair is universal and gold-only at every profession
trainer; material/profession repair remains later work (§8 and
[durability_repair.md](durability_repair.md)).

## 3. Materials, curves and the profession catalogs

Multi-stage everywhere (decided): ore → bar → component → item; hide →
cured leather; cloth → bolt. Each authored recipe declares its station:
ordinary grid, furnace, dual furnace or brewing stand. A station hint in the
book explains where non-grid recipes are made.

Reading order: **§3.0** the material ladder and the one-item-per-concept
rule, **§3.1/§3.2** the armor and weapon curves every item is generated
from, **§3.3–§3.6b** the six profession catalogs, **§3.7** the universal
secondaries, **§3.8** the vendor brackets.

### 3.0 The material ladder (decided 2026-08-07)

Six tiers, one per ten character levels. This is gear ladder 2 of §2.1;
the level bands and ilvl anchors are the §3.8 vendor brackets verbatim,
because under §3.0.3 they are the same items.

#### 3.0.1 Universal materials and resource taxonomy

All six race regions use the same mandatory metal, pickaxe and tier-rock
progression. A faction or race never controls a material needed for the next
universal pick.

| Tier | Levels | ilvl | Metal | Processing | Tier rock (mapgen band) | Next-pick material available no deeper than |
|---|---:|---:|---|---|---|---:|
| T1 | 1–10 | 3 | **Bronze** | Copper + Tin, dual furnace | `default:stone`, y ≥ −100 | Iron: y ≥ −100 |
| T2 | 11–20 | 10 | **Iron** | Iron ore, normal furnace | `grug_materials:t2_stone`, −101…−300 | mined Coal/Steel inputs: y ≥ −300 |
| T3 | 21–30 | 20 | **Steel** | Iron Bar + mined Coal, dual furnace | `grug_materials:t3_stone`, −301…−500 | Silver: y ≥ −500 |
| T4 | 31–40 | 30 | **Silversteel** | Steel + Silver, dual furnace | `grug_materials:t4_stone`, −501…−700 | Emberglass: y ≥ −700 |
| T5 | 41–50 | 40 | **Embersteel** | Silversteel + Emberglass, dual furnace | `grug_materials:t5_stone`, −701…−1000 | Abyssal Crystal: y ≥ −1000 |
| T6 | 51–60 | 50 | **Abyssal Steel** | Embersteel + Abyssal Crystal, dual furnace | `grug_materials:t6_stone`, below −1000 | no T7 prerequisite |

- Wood and Stone starter picks are not extra material tiers. They are T1
  picks (T1 rock and T1 resources); Bronze is the best T1 pick. Wood and Stone
  gear stays below the generated ilvl anchors and carries no level requirement.
- Gold is a universal luxury, jewelry and building material, never a tool
  metal. There is no Gold weapon, armor or pick. Physical Gold and ledger money
  are separate systems (`economy.md` §1).
- Diamond is the T6 gem, never a tool material. The Mese and Diamond
  tool tiers remain retired.
- **Emberglass** is a real `grug_materials` item/node family. Fresh-server
  development uses its canonical names directly, with no old Mese or
  Emberstone migration aliases or parallel player-facing materials.
- **Abyssal Steel** is the ordinary craftable T6 metal. The optional final
  masterwork state is **the crown** (Round 33, [item_tiers.md](item_tiers.md)
  §4): a Crownbinder applies one Fallen Crown to one item, its item level
  becomes its tier's top + 5 and every enchant gains one tier; it replaces
  the Grudgeforged item-level-70 upgrade of the WP audit's D3. Named rares
  drop no trophies (D4). No Crown enters an Abyssal Steel bar or pick.
- Mundane Stone, Copper, Tin, Iron ore, Coal and Gold may retain stable
  upstream itemstrings. Reinterpreted fantastic materials, processed outputs
  and all gems use the Grudgelands namespace. `grug_materials` owns
  the taxonomy even where a mundane itemstring remains upstream.

Every natural resource has a minimum **harvest tier**: the pick tier of the
rock layer where it first appears (Round 24 ruling 2). A weaker pick cannot dig
the ore at all (§3.0.4). The tier holds at any depth, so Coal exposed at
y = −600 is still mined with a T1 pick. Tool-metal ores are therefore mined
one tier below the gear they make.

| Minimum pick tier | Natural resources |
|---|---|
| T1 — any pick, incl. the Wood/Stone starters | Coal, Copper, Tin, Iron, Quartz; Citrine |
| T2 | Gold; Jade |
| T3 | Silver; Garnet |
| T4 | Emberglass; Sapphire |
| T5 | Abyssal Crystal; Ruby |
| T6 | Diamond; T6 rock (below −1000) needs the T6 pick |

**Iron needs only a T1 pick** (Round 24, 2026-09-29). The former 2026-08-13
metal-pick rule for Iron relied on the retired under-tier shatter path and was
never shipped; with engine-native tier gating every T1 pick, the Wood and
Stone starters included, digs every T1 resource. The ladder stays
non-circular: starter pick → Copper + Tin → dual furnace → Bronze pick.

Quartz is a universal T1 mineral at every depth and a raw T1 enchant input;
it has no cut form (Round 33: Cut Citrine is the T1 trinket gem). Gems use
**Rough <Gem> → Cut <Gem>**. Emberglass and Abyssal Crystal are universal fantastic
progression resources and are never called gems.

**Gems are depth-tiered, not regional** (Round 29, economy plan §6). Each of
the six species has one tier and occurs **only in the tier rock of that
tier**, identically in every race region, zone and faction; its harvest tier
equals its tier, so it needs the pick of its layer:

| Tier | Tier rock | Gem |
|---|---|---|
| T1 | `default:stone`, y ≥ −100 | Citrine |
| T2 | `t2_stone`, −101…−300 | Jade |
| T3 | `t3_stone`, −301…−500 | Garnet |
| T4 | `t4_stone`, −501…−700 | Sapphire |
| T5 | `t5_stone`, −701…−1000 | Ruby |
| T6 | `t6_stone`, below −1000 | Diamond |

*Why:* one depth ladder for ores and gems; no contested route is needed for a
gem, and no enchant waits on another region's gem.

Each surface/depth column has exactly one race region, independent of
political territory or PvP state; it selects the region's signature wood:

| Faction | Race region | Signature wood |
|---|---|---|
| Accord | Human | Oak |
| Accord | Dwarf | Mountain Pine |
| Accord | Elf | Silverwood |
| Throng | Orc | Spikethorn Acacia |
| Throng | Troll | Kapok |
| Throng | Undead | Gravewood |

**Density shape and calibration targets:**

- Every gem: about **one per 512 eligible host nodes in its own band**, none
  elsewhere. Full table: [world_zones.md §11](world_zones.md#11-resource-loot-and-poi-budgets).
- Continental Abyssal Crystal exists for both factions throughout T5 and T6.
  Accepted Round 21 calibrations are **one crystal per 512 eligible host nodes in
  T5 and per 256 in T6**; the y = −701…−1000 entry
  band alone must yield enough for an
  Abyssal Steel pick without T6 access.
- At y = −1500…−1999, ordinary continental ores, Diamond and Abyssal
  Crystal receive **+25%** bounded placement budget; at y ≤ −2000 they
  receive **+50%**, capped. Trophies, king loot, claims and
  unique quest sources never receive this multiplier. It is mapgen placement,
  not runtime ore respawn.
- Map generation measures actual exposed yield and route time before freezing
  ore-registration literals. The acceptance audit compares both factions'
  native volume, dragon refill/yield including the Goldsmith bonus, a full
  gear set's demand and two-handed equivalence.

Crafted material blocks are storage/building nodes, never natural resources.
**The pack/unpack recipes shipped 2026-09-16** (WP26): all twelve processed
rows, 9 ↔ 1, both directions, derived from `grug_materials.PROCESSED_MATERIALS`
so the Gold Block and the two resource-form blocks are covered by construction.
The six cut-gem blocks pack and unpack the same way since Round 33 (a plain
Basics recipe in `grug_artisans/goldsmith.lua`, building accents); rough gems
have no block. Storage blocks have no harvest tier, any real pick recovers them wherever territory
permission allows, and they always drop themselves. Mapgen never places a
craftable nine-unit storage block. Citrine, Garnet, Jade, Diamond, Sapphire and
Ruby each pack from **9 Cut Gems** into one matching non-luminous luxury block
and unpack to the same 9 Cut Gems; Rough Gems cannot be packed. Emberglass,
Embersteel, Abyssal Crystal, Abyssal Steel, Gold and mundane metal blocks obey
the same non-gated building-node rule.

The Gold Block specifically packs from 9 Gold Ingots and unpacks to the same
9 ingots. It is a storage/status/decor node, not ledger currency or a housing
purchase token; no universal progression step requires it.

#### 3.0.2 Alloys and the two-slot furnace

**Shipped 2026-09-16** (WP26, `mods/ITEMS/grug_smelting`): both smelting
nodes, the five single-input smelts, the five alloys below, the storage
pack/unpack pairs of §3.0.1 and the station's own craft recipe are registered
and audited at every server start. **Round 21 decision (2026-09-24):** normal Copper, Tin, Iron, Silver and Gold smelts
each take **10 seconds**. Separate alloy durations retain the existing
4/6/8/10/12-second calibration. Earlier measured timings:
[`wp26-implementation.md`](../research/wp26-implementation.md).

Round 21 furnace rules: both furnaces accept
only logs (15s), mined coal (80s) and charcoal (80s) as fuel. One log cooks into
one distinct charcoal item in 10s. New fuel ignites only with a valid recipe
and output space; the current piece burns out even if work stops. Continued
processing refuels without an intervening dark tick. Flame shows remaining
burn time; arrow shows recipe progress. Personal/shared inventory semantics
remain unchanged. Active personal jobs illuminate the physical furnace until
the latest observed private fuel piece expires; only that cosmetic deadline is
shared, while each player's flame and progress remain private. Charcoal does
not replace mined coal in Steel or coal quests.

Two smelting nodes. The **normal furnace** does single-input smelting;
the **dual furnace** (ported from LotT, §1.1) does two-input alloys.

| Output | Recipe | Node |
|---|---|---|
| Bronze bar | Copper + Tin | dual furnace |
| Iron bar | Iron lump | normal furnace |
| Steel bar | 1 Iron Bar + 1 mined Coal | dual furnace |
| Silversteel bar | Steel + Silver | dual furnace |
| Embersteel bar | Silversteel + Emberglass | dual furnace |
| Abyssal Steel bar | Embersteel + Abyssal Crystal | dual furnace |

Steel has two material inputs. Mined Coal occupies the second material slot;
burning Coal or Charcoal as fuel never substitutes for it. The dual furnace
therefore keeps two material slots plus fuel. No universal bar consumes a
gem or trophy.

The dual furnace itself is crafted from one normal furnace plus the first
alloy's two metals — **2 Copper Bars and 1 Tin Bar** in LotT's T-arrangement
(one Copper Bar centered on top; Copper Bar, furnace, Tin Bar across the
bottom row). The alloy station is therefore strictly T1-accessible and is
built after the normal furnace, never before it (decided 2026-08-13).
Shipped 2026-09-16 as the node pair `grug_smelting:dual_furnace` /
`grug_smelting:dual_furnace_active`, following `default:furnace`'s naming
rather than LotT's `_inactive` suffix.

#### 3.0.3 One item per concept — NO duplicates (binding)

**There is exactly one item per concept.** No two items may fill the same
role: there is no `default` stone sword standing next to a "Crude Sword"
from `grug_gear`. Consequences, all binding:

- **The vendor bracket catalog and the base craft ladder are the same
  items**, and they are **material-named** — Bronze Sword, Iron
  Chestplate, Steel Greaves — never bracket-named. The 72 items WP7
  shipped under the adjectives *Crude / Plain / Tempered / Reinforced /
  Superior / Grand* merge into that one ladder. **Shipped 2026-09-15**
  (WP13 playtest round 2): the exact names are below, the generator, the six
  bracket catalogs, the prices and the ilvl anchors of §3.8/§8.2 are
  unchanged by the rename, and no old-stack migration was implemented
  (fresh-server development).

  | Line | T1 | T2 | T3 | T4 | T5 | T6 |
  |---|---|---|---|---|---|---|
  | Weapons and metal armor (§3.0.1's metals) | Bronze | Iron | Steel | Silversteel | Embersteel | Abyssal Steel |
  | Cloth armor (§3.5's bolt grades) | Patch | Woven | Heavy | Silkweave | Silk | Stormweave |
  | Leather armor (§3.4's grades) | Light | Cured | Heavy | Scaled | Sleek | Nightscale |

  Nouns are Sword / Dagger / Battle Axe / Staff, Helm / Chestplate / Greaves /
  Sabatons (metal), Cowl / Robe / Leggings / Slippers (cloth) and Hood /
  Jerkin / Pants / Boots (leather) — so the catalogue reads *Abyssal Steel
  Battle Axe*, *Silkweave Cowl*, *Iron Helm*. Itemstrings follow the same
  ladder (`grug_gear:sword_bronze`, `grug_gear:head_cloth_silkweave`); the
  full list was pinned by `tools/wp13/gear_catalogue_kat.lua` (retired in
  Round 22).
- **Everyone can craft the base items of every material tier** — tools,
  weapons, armor. This is the deliberate "Minecraft feel", and it is what
  makes mining and smelting worth doing for a player with no crafting
  profession at all.
  Four wood sticks use the familiar two-plank vertical recipe; the old
  one-plank shortcut is removed. Base swords use two same-tier bars over a wood stick, with a same-tier
  metal rod accepted in the handle slot. Pickaxes, axes, shovels and the
  Farmer's Hoes use their canonical Minecraft shapes; axes and hoes
  accept both mirrored orientations. The exact non-Minecraft shapes are dagger = one
  material over one handle; greataxe = five material units symmetrically around
  two vertical handles. Wands and staves use ordinary sticks, matching metal
  bars and the approved mob component; bows use sticks, metal and Thread.
  Their exact shapes and ingredient ladder are in
  [`crafting_equipment_revision.md`](crafting_equipment_revision.md#plain-caster-weapons-and-bows). No
  base recipe adds a gem or professional component beyond those stated shapes.
  **This supersedes §3.3's** "vendor floor sells up to the bronze pick —
  iron+ picks are smith products" (see the marked line there).
- **`default`'s tool ladder is replaced** by the six-tier ladder: wood
  and stone stay, bronze/iron/steel/silversteel/embersteel/abyssal steel
  replace the rest, and the **mese and diamond tool tiers are deleted**
  (that is `pick`/`shovel`/`axe`/`sword` × mese, diamond in
  `mods/BASE/default/tools.lua` — twelve registrations to drop, plus
  their craft recipes).
  **Current swords** live entirely in `grug_gear`, beginning at Bronze.
  Vendored Wood/Stone/Bronze/Steel swords are unregistered, alongside the
  removed mese and diamond tiers. Wood/Stone remain only for gathering tools.
  **Pick, axe and shovel** are complete at all six tiers, all in one
  namespace since Round 26 (ruling 14): `grug_materials:{pick,axe,shovel}_`
  plus `wood`, `stone`, `bronze` (T1), `iron` (T2), `steel` (T3),
  `silversteel`, `embersteel` and `abyssal_steel`, registered by
  `grug_materials/tools.lua`. Twelve engine aliases map the former `default:`
  wood/stone/bronze/steel tool names so repository references keep working;
  a startup audit (`grug_materials/audit.lua`) enforces the namespace. Iron gets tools
  because Iron is a full tier here — it owns a tier rock, a pick tier and a
  real bar item — so skipping it would leave §3.0.4's T2 row without a pick.
  All six pick, axe and shovel tiers use the familiar Minecraft grid shapes and
  are universal Basics recipes. Their existing capability profiles remain the
  authority for dig times: dig speed stays as in the game, and no separate
  six-pick speed calibration follows (user decision 2026-09-29, WP audit D8).
  Lifetime follows the current equipment revision.
  Woodcutting Axes are damage-free tools; two-handed Battle Axes are weapons.
  Wood and Stone exist only as tools. Fresh Warrior characters start with a
  Bronze Sword, Mage/Priest with a Bronze Staff, Scout with a Bronze Bow in
  Ranged, a Bronze Sword in Melee and 200 arrows in its quiver slot (Round 28).
  Ordinary T1 weapons are usable at level 1.
- **All armor base recipes use the canonical shapes:** head 5, chest 8,
  legs 7 and feet 4 units, in the same grid positions for metal, cloth and
  leather. All three lines and all six material tiers are registered and
  universal.
- A profession never gets a *parallel* item. What a profession adds on
  top of the base item is the **enchantment and the special
  variant** (§6b), plus its handful of exclusive recipes.

#### 3.0.4 Tier rock, harvest tier and loose ground

Decided with the user for Round 24 (2026-09-28/29; plan
`docs/planning/round24-mining-underground-mobs-plan.md`, rulings 1–8). The
former per-pick depth limits and the under-tier "shatter" path are retired.

Mining evaluates two independent questions:

1. **Territory/protection:** may the player modify this position? Server
   protection stays authoritative.
2. **Pick tier:** is the wielded pick at least the tier of the target rock or
   resource? The position's y plays no part.

Six tier rocks are "ordinary stone compressed by depth". Mapgen places each in
a flat y band; the band only says where the rock lies, never what a pick may
reach:

| Tier | Band (inclusive) | Node | Description | Pick needed |
|---|---|---|---|---|
| T1 | y ≥ −100 | `default:stone` | Stone | any pick (T1+) |
| T2 | −101…−300 | `grug_materials:t2_stone` | Stone | T2+ |
| T3 | −301…−500 | `grug_materials:t3_stone` | Stone | T3+ |
| T4 | −501…−700 | `grug_materials:t4_stone` | Stone | T4+ |
| T5 | −701…−1000 | `grug_materials:t5_stone` | Stone | T5+ |
| T6 | below −1000 | `grug_materials:t6_stone` | Stone | T6 |

- All six display as plain "Stone" with a tooltip line "Requires a T<N>
  pick", carry `grug_stratum = <N>` for dispatch (cave mob spawn lists use
  `group:grug_stratum`) and drop ordinary Cobble, so no player can place hard
  rock. T1 keeps the upstream name `default:stone`. Worlds are discarded; no
  aliases exist for the retired names.
- The five deeper rocks are `ore_type = "stratum"` registrations placed last
  (`wp40/r7_native.lua`), so natural cave walls show the correct band.
  Textures: the tier rocks read as the same stone, progressively darker and
  slightly cooler with depth (items art, Round 24 ruling 16).

**Engine-native gating** (ruling 4). A rock or resource that needs a pick of
tier N carries the node group `level = N − 1`; a tier-t pick carries
`maxlevel = t − 1` on its `cracky` and `grug_resource` capabilities. Luanti's
`getDigParams` skips a capability whose `maxlevel` is below the node `level`,
so the client itself predicts "not diggable": a too-weak pick shows no cracks
and cannot dig at all (ruling 3), for rock and resources alike and at any
depth. Only tier rock and natural resources may carry a non-zero `level`;
storage blocks, obsidian and every other node are normalized to none.

- **Speed:** a higher pick digs lower rock faster. The engine divides the
  dig time by the level difference when it exceeds 1; the per-tier `times` of
  the pick profiles apply on top. For every rock a pick reaches, each higher
  pick is strictly faster than the one below it.
- **Resources:** every pick's `grug_resource` capability carries one ordinary
  time for all five harvest ratings; the level gate alone decides access.
  Descriptions read "<Resource> Ore / Requires a T<N> pick".

**Loose ground** (ruling 5). Every generated ground node except stone — dirt
and its litter/snow variants, sand, silver sand, gravel, clay, snow, snow
block, mud, mesa clay, ash ground (`grug_materials.NATURAL_GROUND_NODES`) —
has no level and no tool gate. It carries `grug_loose` equal to its `crumbly`
rating (mesa clay is loose ground with no `cracky`). The bare hand digs it
through its `crumbly` capability; the equipped skill hand digs it through the
engine's hand fallback. A shovel digs it faster than the pick of the same tier
(picks use twice the shovel time of their tier, capped at the bare hand's time
so no pick or shovel is ever slower than the hand), and a higher shovel is faster
than a lower one. Shovels carry `grug_shovel_tier`.

**Wood** is not gated (ruling 6). Axes carry `grug_axe_tier`; a better axe
chops faster.

**Decorative rocks** (ruling 8): `grug_materials:slate`, `grug_materials:basalt`
and `grug_materials:granite`, clearly different in look from stone. Any pick
digs them, they drop themselves (building variety), no ore grows in them and
they are never a tier stratum. Mapgen uses them only as the surface strata
bands' secondary rock, in irregular nests and in the sparse mountain layers.

**Punch hints** (ruling 7). The client still sends a punch when it starts
digging a node it predicts as undiggable (`src/client/game.cpp`
`handleDigging`), so the server answers with one line in the shared screen
flash line (`grug_core.flash`, the same line the skill errors use, here in a
neutral colour). Refused edits on protected ground report too: the
protection-violation callback (builtin dig and place refusals, the skill
hand's refused dig, door, bed, sapling, kelp and coral placement, farming
buckets, hoes and seeds) shows the same protection line for an online player;
explosions and other non-player violations stay silent. Undiggable town
dressing (`diggable = false`) shows the line on punch. One refused action gives one flash: the same line is
re-shown at most once per flash lifetime (1.5 s), so it stays on screen while
the player keeps trying, and a different line replaces it at once (at most
every 0.25 s):

- protected node, with the protection reason: "Town – protected" (a
  capital's protected city or a start town), "Landmark – protected" (a
  protected functional column: outpost or bandit camp), "Road –
  protected" (a road corridor), "Village – protected" and similar for the
  other POI boxes (`world.md` §2 R1b), "Home of <owner> – protected" (an
  active Claim Stone claim, `housing.md` §6), "Accord home territory –
  protected", "Throng home territory – protected", "Open sea – protected"; a
  player without a faction reads "Protected – choose a faction first";
- rock or resource too hard for the wielded tool: "Requires a T<N> pick";
- a broken pick on rock or ore: "Your pick is broken – repair it".

The protection line does not depend on the wielded item (bare hand, skill,
any tool or item). A selected skill produces no tier, broken-pick or level
line (with a skill, LMB on an unprotected node the hand cannot dig is a
gathering press that digs nothing; on any protected node it is a gathering
press, so the protection line shows, unless a hostile is aimed at;
`classes.md` §2b). Undiggable town dressing (`diggable = false`: capital service props,
camp displays) gives only the protection line. A press that already cast a
self or support skill gives no protection line on its punch; the skill hand's
refused dig still reports it. Protected
nodes still show cracks (an engine limit: the client cannot know position or
faction); there is no per-player capability swapping.

**Tool level requirement** (Round 24 ruling 29, 2026-09-29). Picks, axes and
shovels need a character level by material tier; the tier is the tool's own
`grug_pick_tier` / `grug_axe_tier` / `grug_shovel_tier` group
(`grug_materials.TOOL_LEVEL_REQUIREMENTS`):

| Material tier | Tools | Required level |
|---|---|---:|
| T1 | wood, stone and bronze pick, axe, shovel | none |
| T2 | Iron pick, axe, shovel | 5 |
| T3 | Steel pick, axe, shovel | 15 |
| T4 | Silversteel pick, axe, shovel | 25 |
| T5 | Embersteel pick, axe, shovel | 35 |
| T6 | Abyssal Steel pick, axe, shovel | 45 |

- Every gated tool's tooltip ends with "Requires level <N>" (item definition; stacks
  from earlier worlds are not relabelled, as worlds are discarded).
- The central mining decision refuses, as reason `too_low_level`, any dig on
  any node (natural or placed) that the gated tool itself would perform; where
  the engine falls back to the bare hand anyway (a pick on leaves) nothing is
  refused. A punch and a refused dig answer with one line in the same
  rate-limited flash line as the other hints, e.g. "Iron Pickaxe requires
  level 5". Protection is answered first, on placed nodes too (a protected
  node answers its protection line and records the violation); a rock the
  tool cannot dig at all
  keeps its "Requires a T<N> pick" line.
- The client still predicts the dig from the item capabilities and shows
  cracks in this rare case (an engine limit, accepted); the server resets the
  node.
- Tools are never weapons: their damage groups are zero
  (`tool_lifetimes.lua`), they cannot enter the Weapon slot, a wielded hotbar
  tool is no damage source against mobs or players (the vendored raw-punch
  veto and the PvP handler), so the requirement needs no combat gate.

**Gathering XP** (Round 24 ruling 28, 2026-09-29). Every natural ore or gem
node a player digs and every fish caught gives XP (formula and table in
[progression.md](progression.md) "Gathering XP"): 0.10 kill equivalents per ore
node, 0.20 per gem node (the six depth-tiered species), 0.33 per fish, of
`M(min(reference level, player level + 5))` (Round 28 ruling 32) with reference level 10 × harvest
tier (T1 10 … T6 60) or 10 × the water's zone band. The harvest callback of the
node_dig wrapper settles it, so only a successful player dig of a natural
resource node pays; explosions and mobs never dig through it, and ore nodes
drop their raw item, so no player can place one. There is no gray rule and no
anti-cheat check.

`grug_materials` remains the sole public owner of the tier and harvest
taxonomy: `TIERS`, `tier_at(y)`, `stratum_node_for(y)`, `level_for_tier(tier)`,
`required_pick_tier(node)`, `DECORATIVE_ROCKS`, `PICK_PROFILES` /
`build_pick_capabilities`, the read-only
`mining_decision` and `register_on_harvest`. Its `core.node_dig` wrapper
re-checks the engine rule server-side for natural nodes, records protection
violations and settles harvest callbacks after a successful resource dig. The
startup audit (`grug_materials/audit.lua`) fails before a world starts unless
the whole contract holds, including an engine dig matrix over every pick,
shovel, axe and the hand. No other mod hard-codes a stratum node name, tier
level or harvest tier.

Pick profiles retain their authored monotonic ladder. Hoe identities, uses,
soil conversion, water buckets and wild renewal are authoritative in
[farming.md](farming.md); this document owns only their Basics recipes.

#### 3.0.5 Boats have no recipe

Boats are water mounts ([boats.md](boats.md), travel plan rulings 1 and 3,
user 2026-10-02): the Shipwright sells the base boat at level 15 and the
improved boat at level 30 as owner-bound skill items, exactly like the riding
tiers. There is no boat recipe, no boat material and no boat reference price;
the bound items are never sold, bought back, traded or stored externally.

### 3.1 Armor rating curve (base values shipped in WP7; mitigation revised 2026-09-20)

Armor values are raw rating, not percentage points. Equipped base rating,
affixes, finishes and statuses aggregate before
`combat_stats.md` §2 resolves that total against attacker level and caps only
the resulting reduction at 70%. The generated four-piece set totals use the
existing chest/legs/head/feet split (approximately 35/27/22/16%):

**Column relabel, 2026-08-07 — no number changed.** These columns used to
be headed "T1–T4", which now collides with the six gear tiers of §3.0.
They are and always were **four sample points on one continuous line**,
taken at **ilvl 12 / 27 / 42 / 57**; the paragraph below already says so.
Headed by their ilvl from here on.

| Armor line (profession) | ilvl 12 | 27 | 42 | 57 | ilvl 57 per piece |
|---|---|---|---|---|---|
| Metal (Armorsmith) | 16 | 29 | 42 | 55 | 19/15/12/9 |
| Leather (Leatherworker) | 11 | 20 | 30 | 40 | 14/11/9/6 |
| Cloth (Tailor) | 5 | 8 | 11 | 15 | 5/4/3/3 |
| Shield | — | — | — | — | matching-tier base metal-set total |

The six live catalog anchors at ilvl 3/10/20/30/40/50 produce cloth set
ratings 4/5/6/8/11/14, leather 5/10/17/23/29/36 and metal
8/14/23/32/40/49. A plain shield contributes the matching tier's complete
base metal-set rating: 8/14/23/32/40/49. Drop gear uses the same curve at
its ilvl; quality adds affixes without changing the base curve.

**Off-tier ilvls: linear interpolation** (recorded 2026-08-07 with WP7).
The vendor brackets sit at ilvl 3/10/20/30/40/50 (§3.8) — ilvls the tier
table above does not cover — so the implementation fits a straight line
through the T1/T4 anchors (ilvl 12 and 57) per armor line and reads the
set total off it. Result against the four table cells:

| Line | ilvl 12 | 27 | 42 | 57 |
|---|---|---|---|---|
| Metal | 16 | 29 | 42 | 55 (all four exact) |
| Leather | 11 | **21** (table 20) | 30 | 40 |
| Cloth | 5 | 8 | **12** (table 11) | 15 |

So **the cloth and leather rows are not perfectly linear** — each misses
one interior cell by 1 point; metal reproduces the table exactly. No
shipped vendor bracket touches ilvl 27 or 42, but **WP5's drop tables
will**, and the 1-point step is accepted there rather than bending the
line: the table cell is the authority at the four tier ilvls, the line
is the authority between them.

**Minimum 1 armor point per piece.** The per-piece split can round to 0
at the very bottom of the cloth line — bracket 1 (ilvl 3) has a set
total of 3, and the 16 % foot share rounds to 0. A 0-armor boot is a
bug, not a design statement, so every piece is clamped to ≥ 1. That
clamp bites at exactly one item in the whole shipped catalog.

**The six-tier ladder reads off the same line** (2026-08-07). Under
§3.0.3 the material sets and the vendor brackets are one catalog, so a
tier's armor values are the line evaluated at that tier's ilvl anchor —
3 / 10 / 20 / 30 / 40 / 50 — per piece, exactly as the shipped generator
already does it. Nothing is re-derived and no coefficient changes; the
tier columns above stay the authority at their four ilvls.

**Base recipes.** `default` ships no armor (§1.2), so the four shapes are
ours. Material costs use the canonical shapes — chest 8 / legs 7 / head 5 / feet 4 per
piece — for the lead metal of the tier, and the same shapes serve the
leather and cloth lines with cured leather and bolts in place of bars.

### 3.2 Weapon table (curve: 1H dmg = 4 + 0.35 × ilvl, combat_stats §2)

fpi = full_punch_interval. Columns are **ilvl sample points**, relabelled
2026-08-07 for the same reason as §3.1's — no number changed.

| Family | fpi | dmg factor | ilvl 12 | 27 | 42 | 57 |
|---|---|---|---|---|---|---|
| 1H sword / mace / axe | 1.0 | ×1.0 | 8 | 13 | 19 | 24 |
| Wand (caster 1H) | 1.0 | ×1.0 | 8 | 13 | 19 | 24 |
| Dagger | 0.7 | ×0.7 | 6 | 9 | 13 | 17 |
| 2H greataxe / warhammer | 1.4 | ×1.5 | 12 | 20 | 29 | 36 |
| Metal-shod staff (caster 2H) | 1.4 | ×1.2 | 10 | 16 | 23 | 29 |
| Bow (physical 2H) | charged | ×1.0 | 8 | 13 | 19 | 24 |

**Rounding rule** (made explicit 2026-08-07): **round the 1H value
half-up, then apply the family factor and round half-up again** — never
one rounding over the whole product. The greataxe ilvl-42 cell read 28
under the old text and is **corrected to 29** here: 1H at ilvl 42 is
18.7 → 19, and 19 × 1.5 = 28.5 → 29, the same two-step that already turns
ilvl 27's 13 × 1.5 = 19.5 into 20. The rule is load-bearing, not
bookkeeping: it
also generates the vendor bracket weapons of §3.8.

2H DPS ≈ 1.07× of 1H — pays for the empty offhand.

The active caster roster is the two-handed staff or the one-handed wand plus a
Tailor spellbook. Scepters and orbs are absent on fresh servers: no item,
recipe, loot or vendor identity remains. Staves and wands use universal plain
Basics recipes; Woodcarver owns their enchantments. Bows are likewise
universal plain Basics, with the Leatherworker owning their improvement
operations (Round 33).

Every equipment item requires min(item level, 60) as its minimum character
level (Round 33, round33-plan.md §2.2; `_grug_req_level`, per stack
`grug_req_level`); T1 bases require level 1. Every equipment slot enforces it
(`inventory_equipment.md`). This gate does not apply to tools, which
carry their own material-tier level requirement instead (§3.0.4 "Tool level
requirement").

**How to read §3.3–§3.6b** (rewritten 2026-08-07). These sections used to
describe a model where each profession **owned** its item catalog. Under
§3.0.3 that is no longer true: the base item of every material tier is
craftable by everyone. What each section now lists is three things —

1. the **material chain** the profession refines through (unchanged; it
   is still the profession's progression and its trade good),
2. the **item families** the profession may **enchant and turn
   into special variants** (§6b) — its exclusive claim on the *quality*
   of an item, not on its existence,
3. its **exclusive recipes**, a handful per mastery tier: things nobody
   else can make at all.

Coverage across the six primaries and the two secondaries is complete and
overlap-free (professions.md §2).

### 3.3 Weaponsmith and Armorsmith (shared Forge)

**Material chain**: T1 **Bronze** → T2 **Iron** → T3 **Steel** → T4
**Silversteel** → T5 **Embersteel** → T6 **Abyssal Steel** (§3.0.1/§3.0.2).
Vendor supply: flux. *Revised 2026-08-07*: the old four-step chain
(bronze / iron / steel / gem-tempered steel) is superseded by the
six-tier ladder, and **§10 P1's "gem-tempered steel" is retired with it**
— the T4 metal is Silversteel from a real new ore, which is exactly the
"new ore post-MVP" option P1 held open.

**Weaponsmith enchants** physical weapons. Gathering tools have no combat enchants.
**Armorsmith enchants** metal armor and shields. Plain base recipes
remain universal: swords cost two bars plus a handle; picks cost three bars;
armor uses the canonical 5/8/7/4 head/chest/legs/feet layouts. Both smiths
enchant with the metal bar of the enchant tier as their own material (§6b);
the former Weaponsmith metal fittings are removed (Round 28 ruling 28).

**Exclusive recipes**: named family-legal enchantments.
Plain shields use their universal Basics grid; Armorsmith owns their enchants.

Ore access follows §3.0.4: territory/protection, then the pick tier against
the ore's harvest tier, at any depth. Natural distribution comes
from §3.0.1 and the column's `race_region`, not from a tier-matched stratum or
a lead-metal-band rule.

Every pick is a universal base recipe. Higher-tier tools improve their mining
access and lifetime; no professional refinement step exists.

### 3.4 Leatherworker (tanning rack) — leather

**Material chain**: hide + thread → leather, 1:1 per grade. Authored grades are
**T1 light leather, T2 cured leather, T3 heavy leather and T4 scaled hide**;
decided 2026-08-13: **T5 sleek leather** (from the panther's sleek pelt —
`biomes_mobs.md` §3.1/§6, both continents via jungle fringe/deep jungle) and
**T6 nightscale leather**, a composite of scaled hide + sleek pelt following
the Tailor's T4 silkweave precedent (serpents and panthers carry the
level-51–60 zones on both continents; no new mob is required).

**Enchants**: leather armor, all four slots. Base recipes use
the §3.1 shapes at jerkin 8 / pants 7 / hood 5 / boots 4 leather. Its MVP
wearers are the **Warrior** (light avoidance set, §3.8 — decided
2026-08-13) and the **Scout**.

**Exclusive recipes** (mastery cut decided 2026-08-13, §2.1): named
leather-armor enchantments across T1–T6 (§6b). At Apprentice it also makes
the 8-slot Leather Pouch. (The quiver item and its recipe were removed in
Round 28; the quiver is a Scout-only slot, `inventory_equipment.md` §3.) Its 16/24/32-slot leather bags follow at
Journeyman/Expert/Master. Plain bows are Basics; the Leatherworker enchants
and upgrades them with its leather grade (Round 33, [item_tiers.md](item_tiers.md) §3.3).


### 3.5 Tailor (tailor bench) — cloth and cloth bags

**Material chain**: 2 cloth + thread → bolt. Authored grades are **T1 linen
scrap → patch bolt** (zombies drop scraps from L1 — Tailors start in safe
starting zones), **T2 linen cloth → woven bolt**, **T3 heavy cloth → heavy
bolt** and **T4 heavy + spider silk → silkweave bolt** (spider silk is the
item `grug_mobs:spider_silk`, shown as **Raw Silk** because T5/T6 outlaws drop
it too); decided 2026-08-13:
**T5 spider silk → silk bolt** (pure silk, the same 2 + thread pattern;
spiders exist 25–60 on both continents) and **T6 spider silk + stormkelp →
stormweave bolt** — stormkelp (coast 45–60, both continents,
`biomes_mobs.md` §6) doubles as a weaving fiber here; its spice role is
unchanged, and the T6 bolt gives the level-45–60 coast zones an economic
pull.

**Enchants**: cloth armor, all four slots. Base recipes:
robe 8 / leggings 7 / cowl 5 / slippers 4 bolts.

**Exclusive recipes**:

- **Bags** (`inventory_equipment.md` §3) — **four sizes across the four
  mastery tiers, 8 / 16 / 24 / 32 slots**. The 8-slot bag stays
  vendor-sellable, because it is the floor tier (vendor floor rule); the
  16-slot bag is 8 woven bolts + 2 cured leather, the 24-slot 10 heavy
  bolts + 4 spider silk + 2 heavy leather, and the 32-slot ("huge bag")
  is the Master-tier addition of 2026-08-07. Bags are the one signature
  recipe line that is fully decided.
- **Named cloth enchantments** across all six tiers (§6b); no separate kit line.
- **Spellbooks** (Round 33, from the Goldsmith): two bolts of the tier and a
  Parchment at the Tailor Bench, Journeyman mastery; the Tailor also enchants
  and upgrades them with its bolt ([item_tiers.md](item_tiers.md) §3.3).
- The woven and heavy bolt bundles are bag inputs (intermediates, no
  profession progress).

### 3.6 Alchemy (brewing stand) — potions and elixirs

**Implemented 2026-09-18; a secondary profession since Round 33** (no primary
slot, its own book slot beside Cooking, `professions.md` §1). Herbalism is
part of Alchemy rather than a separate profession. Gravemoss, Dragonweed, Crimson Lotus and Ember Moss are
fail-closed scenery for everyone who has not learned Alchemy; learning the
profession authorizes all four. Cave Cap remains food-grade and universal.
Recipe access is the effective Alchemy tier (§2.2), not a herb
or keystone book gate. Every tier-N recipe contains a declared tier-N reagent.

Alchemists assemble a potion mixture from its reagents and vial in their own
inventory 3x3 grid; that qualified preparation awards current-tier progress.
The **Brewing Stand** accepts one mixture, fuel and finished outputs. Its
automatic completion and extraction are universal and grant no further progress.
Capital stations are personal workspaces; all player-placed copies are shared
stations subject to area access. The stand is a T3 Alchemy grid recipe (a
station: it awards no profession progress):
three Steel Bars, one Furnace and one Glass Bottle. Glass Bottles cost 3 copper.

Potions restore or act immediately and share the persistent potion clock.
Every successfully consumed potion or elixir plays one shared drinking sound;
refused uses play no sound.
Since Round 33 ([item_tiers.md](item_tiers.md) §5) healing and mana potions
restore **fixed amounts**, about half a Priest's base pool at the tier's top
level: **70 / 200 / 400 / 650 / 1000 / 1350** for tiers I–VI. Every potion and
draught starts the one shared **60-second** clock; the vendor's Weak Healing
Potion (8c) heals a fixed **35 HP** on the same clock. A full-health healing
potion is refused without consumption or cooldown. A mana potion may be
consumed at full mana. Elixirs give two enchants' worth of their stat at the
tier's top level (Stoneskin one armor enchant) and never touch the potion
clock: exactly one `elixir` status may run, the newest replaces it, and it
stacks with the separate food status. Pool and crit values are percentage
points, armor a rating. Consumables require the first character level of
their recipe tier: **1, 11, 21, 31, 41, 51**. No recipe uses a reagent that
drops in only one faction's zones; Elixir of Precision II takes the Ridged
Boar Tusk because Dragonweed and Fang are the Swiftness Draught's recipe.

| Tier | Product | Reagent 1 | Reagent 2 | Effect |
|---:|---|---|---|---|
| T1 | Healing Potion I | Gravemoss | Sunleaf | Restores 70 HP at once; 60 s shared cooldown |
| T1 | Mana Potion I | Gravemoss | Carrot or Cassava | Restores 70 Mana at once; 60 s shared cooldown |
| T1 | Elixir of Vigor I | Sunleaf | Tattered Flesh | +4.0% maximum HP for 15 minutes |
| T1 | Elixir of Focus I | Gravemoss | Crab Eye | +5.0% maximum Mana for 15 minutes |
| T1 | Elixir of Precision I | Sunleaf | Boar Tusk | +4.2 percentage points Crit for 15 minutes |
| T1 | Stoneskin Elixir I | Gravemoss | Crab Leg | +0.8 armor rating for 30 minutes |
| T2 | Healing Potion II | Dragonweed | Sunleaf | Restores 200 HP at once; 60 s shared cooldown |
| T2 | Mana Potion II | Dragonweed | Sugar Cane | Restores 200 Mana at once; 60 s shared cooldown |
| T2 | Elixir of Vigor II | Dragonweed | Tough Sinew | +4.8% maximum HP for 15 minutes |
| T2 | Elixir of Focus II | Dragonweed | Clear Crab Eye | +5.6% maximum Mana for 15 minutes |
| T2 | Elixir of Precision II | Dragonweed | Ridged Boar Tusk | +5.2 percentage points Crit for 15 minutes |
| T2 | Stoneskin Elixir II | Dragonweed | Ridged Crab Shell | +1.6 armor rating for 30 minutes |
| T2 | Antivenom | Dragonweed | Venom Gland | Cures poison; 60 s shared cooldown |
| T2 | Swiftness Draught | Dragonweed | Fang | +10% movement speed for 5 seconds; 60 s shared cooldown |
| T3 | Healing Potion III | Crimson Lotus | Gravemoss | Restores 400 HP at once; 60 s shared cooldown |
| T3 | Mana Potion III | Crimson Lotus | Sugar Cane | Restores 400 Mana at once; 60 s shared cooldown |
| T3 | Elixir of Vigor III | Crimson Lotus | Bear Claw | +5.6% maximum HP for 15 minutes |
| T3 | Elixir of Focus III | Crimson Lotus | Cave Cap | +6.2% maximum Mana for 15 minutes |
| T3 | Elixir of Precision III | Crimson Lotus | Serrated Fang | +6.0 percentage points Crit for 15 minutes |
| T3 | Stoneskin Elixir III | Crimson Lotus | Layered Crab Shell | +2.4 armor rating for 30 minutes |
| T3 | Cave Draught | Cave Cap | Bound Wisp Mote | Night vision for 10 minutes; 60 s shared cooldown |
| T4 | Healing Potion IV | Crimson Lotus | Leathery Flesh | Restores 650 HP at once; 60 s shared cooldown |
| T4 | Mana Potion IV | Crimson Lotus | Venom Sac | Restores 650 Mana at once; 60 s shared cooldown |
| T4 | Elixir of Vigor IV | Crimson Lotus | Ironbound Sinew | +6.4% maximum HP for 15 minutes |
| T4 | Elixir of Focus IV | Crimson Lotus | Campaign Talisman | +6.8% maximum Mana for 15 minutes |
| T4 | Elixir of Precision IV | Crimson Lotus | Razor Cat Claw | +7.0 percentage points Crit for 15 minutes |
| T4 | Stoneskin Elixir IV | Crimson Lotus | Shiny Scale | +3.2 armor rating for 30 minutes |
| T5 | Healing Potion V | Ember Moss | Crimson Lotus | Restores 1000 HP at once; 60 s shared cooldown |
| T5 | Mana Potion V | Stormkelp | Crimson Lotus | Restores 1000 Mana at once; 60 s shared cooldown |
| T5 | Elixir of Vigor V | Ember Moss | Scorched Flesh | +7.2% maximum HP for 15 minutes |
| T5 | Elixir of Focus V | Ember Moss | Cave Cap | +7.4% maximum Mana for 15 minutes |
| T5 | Elixir of Precision V | Ember Moss | Siegepack Fang | +7.8 percentage points Crit for 15 minutes |
| T5 | Stoneskin Elixir V | Stormkelp | Siege Bone | +4.0 armor rating for 30 minutes |
| T5 | Deepwater Elixir | Stormkelp | Cave Cap | Water breathing for 10 minutes |
| T6 | Healing Potion VI | Wild Cocoa | Ember Moss | Restores 1350 HP at once; 60 s shared cooldown |
| T6 | Mana Potion VI | Wild Cocoa | Stormkelp | Restores 1350 Mana at once; 60 s shared cooldown |
| T6 | Elixir of Vigor VI | Wild Cocoa | Salt-Cured Flesh | +8.0% maximum HP for 15 minutes |
| T6 | Elixir of Focus VI | Wild Cocoa | Last-Hex Shard | +8.0% maximum Mana for 15 minutes |
| T6 | Elixir of Precision VI | Ember Moss | Sharp Feather | +8.6 percentage points Crit for 15 minutes |
| T6 | Stoneskin Elixir VI | Wild Cocoa | Unquiet Bone | +4.8 armor rating for 30 minutes |

Every row also consumes one Glass Bottle. There is no apothecary gear, no
imbuing oil and no Sovereign's Flask (removed in Round 33).

### 3.6a Woodcarver (carving bench) — wood and caster weapons

Woodcarver owns named enchant and upgrade operations for the caster weapon
families: staff and wand (bows belong to the Leatherworker since Round 33,
[item_tiers.md](item_tiers.md) §3.3). Their plain recipes remain universal
Basics.
Plain weapons use ordinary sticks and matching-tier metal bars. Wands and
staves additionally use the tier's ordinary mob component; bows use Thread.
The exact shapes and six-component ladder are defined in
[`crafting_equipment_revision.md`](crafting_equipment_revision.md#plain-caster-weapons-and-bows).

**Material chain**: wood, including the per-race woods of biomes_mobs §5 —
silverwood and gravewood among them. Signature woods are not a mandatory
universal tier ladder. The six processed grades are decided
(2026-08-13): **Seasoned → Polished → Hardened → Inlaid → Lacquered →
Heartwood** (T1→T6), retained for enchanting rather than plain weapon recipes,
each craftable from any `group:wood` — both continents
reach every grade by construction, and the per-race woods stay a cosmetic
skin on top, never a tier gate. These are component names; finished weapons follow the shared tier names,
for example Steel Staff (§3.8).

**Enchants and upgrades**: staves and wands.

**Exclusive operations:** named staff and wand enchants and upgrades across T1–T6.

**Self-contained (Round 28 ruling 28).** The Woodcarver enchants with its
own graded wood of the enchant tier plus the tier's loot and mining inputs
(§6b); it no longer buys Weaponsmith metal fittings, which are removed.
Universal plain caster weapons never require a professional component.

### 3.6b Goldsmith (jeweller's bench) — gold, gems, both trinket slots

New profession, 2026-08-07 (professions.md §2). **Gem Hunter is merged
into it** and disappears as a separate profession. The useful gathering hook
survives; the private-island Gem Detector does not.

**Material chain:** physical **Gold** and the six depth-tiered gems
(§3.0.1): T1 Citrine, T2 Jade, T3 Garnet, T4 Sapphire, T5 Ruby, T6 Diamond.
Natural gem nodes drop Rough Gems. The Goldsmith alone refines Rough → Cut,
at the gem's tier; every storage block and equipment recipe consumes Cut Gems
where a gem is required. Quartz is a mineral without a cut form (Round 33);
raw Quartz stays an enchant input. Cut gems and settings are intermediates:
they award no profession progress (§2.3).

**Owns exclusively:**

- both generic trinket slots and the six core trinket identities of §6.2;
- Rough → Cut gem refinement;
- jewelry Settings and trinket assembly; trinket enchants and upgrades;
- one bonus-yield roll after a **successfully harvested** natural
  gem node: **10% base chance at Apprentice, 20% from Journeyman onward**. A
  success grants exactly one additional raw gem item of the harvested species.
  The roll never fires on stone or any failed harvest (a too-weak pick cannot
  dig the ore at all) and never converts one gem into another.

Rough→Cut conversion, Settings, trinket assembly and named enchantments use
profession-tier qualification. Spellbooks moved to the Tailor and Ornament
Components were removed (Round 33). Imbue/Temper kits are removed.

The Gem Detector and Dowsing Rod are retired. Continental mining remains
exploration rather than direction/radar gameplay, and the Goldsmith already
has trinkets, cutting, settings and real-node bonus yield as its complete
identity.

Use **Setting** consistently for the tiered jewelry component:

| Tier | Setting | Gem use per core trinket |
|---|---|---|
| T1 | Tin Setting | 1 Cut Citrine |
| T2 | Iron Setting | 1 Cut Jade |
| T3 | Copper-inlaid Steel Setting | 1 Cut Garnet |
| T4 | Gold Setting | 1 Cut Sapphire |
| T5 | Gold-filigreed Embersteel Setting | 1 Cut Ruby + 1 Cut Sapphire |
| T6 | Gold-filigreed Abyssal Steel Setting | 1 Cut Diamond + 1 Cut Ruby + 1 Cut Sapphire |

Copper-inlaid Steel and the two filigree Settings are Goldsmith components,
not universal bars or tool materials. Every core trinket takes the gem of its
recipe tier (T5 and T6 add the gems one and two tiers below); the
six identities differ only by their Setting count. The complete tier list is
visible in the matching book group: all six T4 recipes become craftable with
profession T4, so mining depth rather than recipe rarity remains the
material gate. No recipe scroll, reputation grind or enemy unlock is involved.
Each core trinket recipe consumes only its tier-appropriate Setting and the
listed Cut gem(s): there is no special-specific herb, catalyst, mob drop,
trophy or cross-profession component.

### 3.7 Universal secondaries & vendor floor

Cooking and Alchemy (§3.6) are the two secondary professions; neither costs a
main profession slot (professions.md §1).

- **Cooking** (trainer, free) uses the profession framework. Learning it opens
  T1 and shows the complete T1–T6 catalog; profession level gates crafting and
  `_grug_ilvl` gates eating independently. There is no Cooking Fire.

  **Food restore values** (recovery amended 2026-09-22). A serving lasts **300 s**, ticks every **5 s**,
  and the newest food replaces the old one. Eating is refused before consumption while the player is in combat.
  Accepted food heals instantly; its regeneration pauses during later combat,
  while secondary modifiers remain active. Successful eating plays one shared
  eating sound at 0.5 gain; rejected attempts play no sound.

  | Tier | Minimum level | Instant HP | Dish regeneration per tick | Hearty secondary | Caster secondary | Hunter secondary |
  |---|---:|---:|---:|---|---|---|
  | T1 | 1 | 5 | 4% | — | — | — |
  | T2 | 11 | 15 | 5% | — | — | — |
  | T3 | 21 | 40 | 6% | +2% HP pool | +2% mana pool | +2% HP pool |
  | T4 | 31 | 90 | 7% | +4% HP pool | +4% mana pool | +4% HP pool |
  | T5 | 41 | 180 | 8% | +6% HP pool | +6% mana pool | +1% Crit |
  | T6 | 51 | 300 | 10% | +8% HP pool | +8% mana pool | +1% Crit |

  Hearty and Hunter dishes regenerate HP. Caster dishes regenerate both HP and
  mana at the listed rate. Every raw edible regenerates 2% maximum HP per tick;
  Wild Cocoa is HP food, not mana food. Rock Salt and Salt Crust are inedible.

  **Cooking plant sources.** The current farming and renewal contract is in
  [farming.md](farming.md), with geographic projection in `world_zones.md`.
  Their `Raw tier` is the band of the lowest source;
  `Recipe tier` is the profession ingredient tier and may deliberately differ.

  | Item | Raw tier | Recipe tier | Food rule | Planned source |
  |---|---:|---:|---|---|
  | Wild Grain | T1 | T1 | raw HP food | start-zone clearings |
  | Carrot / Cassava | T1 | T1 | raw HP food | Accord / Throng start palettes |
  | Wild Onion / Fire Pepper | T1 | T1 | inedible spice | faction start and home palettes |
  | Pumpkin | T2 | T2 | raw HP food | level 11–20 margins |
  | Blightberry / Sunberry / Jungle Berry | T2 | T2 | raw HP food | Throng level 11–20 palettes |
  | Frost Melon | T3 | T4 | raw HP food | Frostbarrow and Whitebridge, level 21–30 |
  | Sugar Cane | T1 | T2 | inedible sweetener | fresh and salt shores in every band |
  | Bamboo Shoot | T1 | T1 | raw HP food | jungle and swamp shores |
  | Cave Cap | T3 | T3 | raw HP food | caves at y −100…−500 |
  | Salt Crust | T5 | T5 | inedible salt | The Shattered Line, level 41–50 |
  | Ember Moss | T5 | T5 | inedible Alchemy reagent | T5 stone (`grug_materials:t5_stone`) at y ≤ −701 |

  Existing raw-food tiers are Apple T1, Blueberries T1, raw meat T1, ordinary
  Raw Fish T1, Corn T1, Potato T1, Melon T1, Mushroom T3 and Wild Cocoa T6.
  The five band fish are T2–T6 respectively. Cooked Meat, Cooked Fish and Bread
  are T1 Hearty dishes.

  **Cooking book.** Every row is a profession recipe at the crafting grid and
  contains at least one ingredient registered at its own recipe tier. The
  Hearty dishes have no direct grid route (Round 28 ruling 27): they come only
  from their raw assembly in the furnace (below). Within a tier a stronger
  dish costs more to make, never less (Round 34): the Caster dish (HP and mana
  regeneration) needs more input value, counted in vendor payouts, than the
  Hearty and Hunter dishes of its tier (HP only; their secondaries differ in
  kind and count as equal).

  | Tier | Role | Inputs | Output |
  |---|---|---|---|
  | T1 | Caster | 2 carrot or cassava + potato or corn + Wild Grain | Sweetroot Mash |
  | T1 | Hunter | raw fish + corn | Corn-Crusted Fish |
  | T2 | Caster | 3 berries + Pumpkin + Sugar Cane | Berry Preserve |
  | T2 | Hunter | raw meat + apple or berries | Fruit-Glazed Roast |
  | T3 | Caster | 2 mushrooms | Mushroom Skewer |
  | T3 | Hunter | raw meat + Wild Onion or Fire Pepper + mushroom | Onion-Seared Steak |
  | T4 | Caster | raw fish + 2 Marshbloom | Marshbloom Chowder |
  | T4 | Hunter | 2 raw meat + melon + mushroom | Hunter's Feast |
  | T5 | Caster | 2 Stormkelp + raw fish + Rock Salt | Stormkelp Broth |
  | T5 | Hunter | raw fish + Rock Salt | Salt-Crusted Fish |
  | T6 | Caster | 2 Wild Cocoa + Rock Salt | Jungle Cocoa |
  | T6 | Hunter | raw meat + Wild Cocoa + Fire Pepper or Wild Onion | Cocoa-Rubbed Game |

  **Both furnace patterns.** Raw meat → Cooked Meat, ordinary Raw Fish →
  Cooked Fish and Wild Grain → Bread are universal Basics routes with no
  profession progression. Every tier also
  has one Cooking grid recipe for an inedible raw assembly ("Raw X"); its
  universal furnace finishing route is the only source of that tier's
  Hearty dish:

  | Tier | Raw assembly inputs | Furnace output |
  |---|---|---|
  | T1 | raw meat + potato or corn + Wild Grain | Hearty Stew |
  | T2 | pumpkin + raw meat + Wild Grain | Pumpkin Stew |
  | T3 | Cave Cap + raw meat + potato or corn | Forager's Pot |
  | T4 | raw meat + Marshbloom + Frost Melon | Marsh Roast |
  | T5 | raw meat + Stormkelp + Salt Crust | Kelp-Wrapped Roast |
  | T6 | 2 raw meat + Wild Cocoa + Salt Crust | Grand Feast |

  Fishing remains universal. `grug_fishing.table_for(pos)` maps the
  authoritative mob level at the cast position to six ten-level tables; each
  table is 90% its band fish and 10% papyrus (no sticks since Round 29). Fresh and salt water
  use the same table for the same level.

  Round 14 fishing uses one visible bobber per angler. Right-click casts and
  reels; a bite visibly dips the float and opens a 1.5-second catch window.
  A missed bite returns to waiting, early reeling retrieves an empty line.
  Successful catches show a message-feed line `Caught <Fish Name> (+N XP)`,
  not chat (`inventory_equipment.md`, "Message feed").
  Current catch tables and catch-only rod wear stay unchanged. Death, logout,
  unequipping or leaving the permitted range removes the line. No fishing
  profession or lure system is introduced. The rod is an early T1 Basics
  craft: three sticks and two thread (user decision, Round 29).

- **Vendor stock**: the level-independent core (small bag, weak healing
  potion, torches, wooden/stone tools, bronze pick, player arrows, job
  supplies — thread/parchment/vial) plus the **T1 catalog** of §3.8.
  Profession shelves carry their trade's supplies, food and T1 basics
  ([economy plan](../planning/economy-vendor-plan.md) §2.3); no shelf sells
  an enchant input or an ingredient above T1, which a load audit enforces.

### 3.8 Vendor bracket catalogs (decided 2026-08-07)

**Round 33 ([round33-plan.md](../planning/round33-plan.md) §2.6): vendors sell
the T1 catalog only** — all six weapon families and the three armour lines
at their T1 slot prices, at every level, with no rotation and no rotating
Uncommon item. From T2 the bases come from Basics crafting (mined and
gathered materials) or drops. The six catalogs below stay the craft ladder,
the drop pool and the reference prices of buy-back and repair (§8.2). The
historical reading that follows (a moving floor, hourly rotation) is
superseded where it says vendors sell a bracket.

Revises the old "one floor at ilvl ≤ 5" model. The vendor floor rule
stands — vendors sell the lowest tier of each category — but **the floor
moves with the player** instead of freezing at the starter set.

**Merged with the base craft ladder** (2026-08-07, §3.0.3). A bracket is
a **material tier** (§3.0.1), and the items in it are the base items
everybody can craft. Two consequences, and nothing else in this section
changes:

- **The items are material-named**, never bracket-named. The old
  adjective naming — *Crude / Plain / Tempered / Reinforced / Superior /
  Grand* over the six brackets — was replaced by the material the item is
  actually made of: **metal items take the lead metal** of §3.0.1
  (Bronze Sword, Iron Helm, Steel Chestplate, Silversteel Greaves,
  Embersteel Sabatons, Abyssal Steel Greataxe), **cloth items take their
  bolt grade** and **leather items their leather grade** (§3.4/§3.5) —
  Patch Robe, Silkweave Cowl. The slot nouns are unchanged (Helm /
  Chestplate / Greaves / Sabatons, Cowl / Robe / Leggings / Slippers),
  and so are the generator, the prices, the ilvl anchors and the bracket
  boundaries. **Shipped 2026-09-15** with WP13's round-2 merge, together
  with the merge into `default`'s tool ladder; the exact ladder is §3.0.3's
  table and `grug_gear.MATERIALS`.
- **Selling a base item is not selling "the low tier of crafting".** It
  is selling the same item a crafter starts from. What a vendor can never
  sell is a **enchanted** item (§6b) — that is the whole
  of the crafting advantage now, stated as a rule instead of as a number
  comparison.

- **Six catalogs, one per 10 levels**: 1–10, 11–20, 21–30, 31–40, 41–50,
  51–60 — the same bands as the six material tiers. A player sees their
  own bracket **and every bracket below** (tabs in the trade formspec),
  so starter goods stay buyable and a new shelf opens every 10 levels — a
  deliberate reward beat on a level curve that otherwise only pays out
  talent points (progression.md §2). The bands are **1-based**: bracket 1
  is levels 1–10, never 0–9.
- **Binding strength rule**: *a bracket's gear is exactly what a normal
  mob of that bracket drops — guaranteed, but expensive.* The floor, not
  the ceiling. Item level per bracket **3 / 10 / 20 / 30 / 40 / 50**,
  always **Common**, therefore always without enchants (§6.1).

| Bracket | 1–10 | 11–20 | 21–30 | 31–40 | 41–50 | 51–60 |
|---|---|---|---|---|---|---|
| Material tier | T1 | T2 | T3 | T4 | T5 | T6 |
| ilvl | 3 | 10 | 20 | 30 | 40 | 50 |
| 1H weapon dmg (§3.2 curve) | 5 | 8 | 11 | 15 | 18 | 22 |

  **No gem base cost.** Ordinary crafted combat weapons, armor
  pieces and offhands at every tier use only their universal material
  recipe (bars, cloth, leather, wood). The former T4–T6 Cut-gem surcharge on
  base equipment is retired (Round 10 ruling 7: "There is no additional high-tier
  regional-gem surcharge on base equipment"). Gem demand comes from trinkets
  (§3.6b/§6.2) and enchant inputs (§6b). Dropped/vendor gear
  stays a usable floor.

  Rationale for having the vendor ladder at all: on a small server the
  crafter for your armor class may simply not exist — the floor stops a
  player from going naked, it does not compete. Superseded 2026-08-07:
  the old "±15 % of crafted gear of the same era" comparison, and the
  older "10–15 % behind" before it. Under the merge there is nothing to
  compare — vendor gear and base crafted gear are the same item, and the
  crafter's edge is enchantments (§6b), not a base number.
- **Rotation**: the core stock is fixed; each bracket additionally shows
  a handful of **rotating gear slots**, re-rolled hourly. Roughly **one
  rotation in five carries a single Uncommon item**, rolled like a found
  item (§6.3: the enchant has the item level's tier and the rule's value) and priced above the Common
  baseline by the authoritative quality multiplier. That is
  the "today the trader had something good" moment, without a second
  gear source.

  **Implemented reading** (decided 2026-08-07):
  - The bracket's **fixed floor is always on sale**: the 1H sword plus a
    full set in each of the three shipped armor lines = **13 items**. That is what
    "guaranteed, but expensive … the floor, not the ceiling" requires,
    and the rotation may never touch it.
  - On top of it sit the **rotating slots**, drawn hourly from the
    **extra weapon families**, so **one family is withheld every
    rotation**. Withholding is what makes it a rotation: with one slot
    per extra the whole catalog would be on the shelf every hour and the
    re-roll would only permute the display order. The slot count is
    **always strictly below the pool size** — that is the rule, the
    number follows from §3.2.
    The active extra pool is **five** families — dagger, greataxe, staff, wand
    and bow — with fewer rotating slots than families. Scepters and orbs are
    not aliases or visual variants.
  - The **1-in-5 Uncommon is rolled per vendor and per bracket** (so two
    vendors in the same hour differ, and a player's own brackets differ
    from each other), replaces one of the rotating slots and is priced
    by the final enchanted/quality purchase multiplier.
  - The Uncommon is **only offered once WP5's enchant roller exists.**
    Common is enchant-free by definition, so an Uncommon without rolls
    is mechanically identical to the Common beside it while costing
    more than the Common beside it — a blue-named trap, not a luxury. The
    quality/description machinery ships regardless; WP5 lights it up only
    after the economy/loot pass fixes the multiplier. Round 33 removed
    the rotation and the Uncommon with it.
  - The rotation is **deterministic**: a pure function of (real hour,
    vendor, bracket). Two players at the same vendor in the same hour
    see the same shelf, and a restart does not re-roll it.
- Catalogs are **generated from the curves** of §3.1/§3.2, not authored
  by hand — six brackets cost the same as three.
- **Shipped armor lines: metal, cloth and leather** (leather decided
  2026-08-13, superseding 2026-08-07's "does not ship"). The rank rule
  grants each class its own rank **and everything below**
  (`inventory_equipment.md` §2: Warrior 3 / Scout 2 / Mage 1 / Priest 1), so
  leather (rank 2) is the **Scout's armor line** and remains a legal light set
  for the Warrior. §6.2's leather pool (+Dex, +max HP%, +max Mana%, +crit%,
  +dodge%) against metal's (+Str, +max HP%, +armor rating, +dodge%) is a real
  mitigation-versus-avoidance choice, and
  §3.1 already prices leather below metal at equal tier, so plate stays
  the mitigation king. The curve sits in the generator; the 24 leather
  registrations land with WP29's catalog merge. Under the §3.0.3 merge
  this covers the **craft** ladder too — one catalog, so the line ships
  vendor and craft at once (§3.4). The Scout replaces the retired separate
  Rogue plan; no later Rogue wearer is implied.
- Cultural-region vendor presentation and the same-race purchase discount
  layer on top without changing catalog strength or buy-back (§8.2).

Every craft output follows the **anti-loop rule: the payout of a crafted
item is at most the summed payout of its ingredients** (economy.md §2) —
vendors are a floor, never a factory profit.

## 4. Material art contract

Cultural materials, cultural finishing, the PvP weapon counter and the
Warding Draught were removed in Round 33 (fresh-server mode: no items, nodes,
mapgen placement, recipes or services remain).

Use a hybrid source strategy: derive mundane bases/tree palettes from
license-cleared references and adapt the proven per-stack trim/meta
technique. Every reused asset records file provenance, author, exact license,
pinned source commit and modifications in the owning `LICENSE-media.md`.

Each of the six gems has exactly four visual roles: natural ore node,
Rough Gem, Cut Gem and polished non-luminous storage block — **24 roles total**
before equipment overlays. Signature woods receive a full tree/build palette
only where an existing licensed wood cannot carry the race region cleanly.
AI-generated concepts/variants require manual limited-palette, hard-edge and
pixel-cluster cleanup before they become final game art.

## 5. Loot zones — what drops where

Drops obey the player-tag rule (combat_stats §3), the chances of §5.1 and
the enchant values of §6.3, and use **gear-drop ilvl = min(mob level, 60)**.
Bosses are the exception (Round 33): the race Kings and the fortress Generals
drop item level **65**, the dragons item level **70** (§5.1). Their ilvl above
60 feeds the same weapon base-damage curve as every other weapon, not a second
combat multiplier, and their enchants are tier T7 (§6.3). The
Kraken Guard (a level-70 elite of the deep sea) drops nothing, not even a bag. Since the enchant value and the
enchant tier follow the item's ilvl, that one number is all a drop needs: a
drop has no crafter whose mastery could be read instead. Named zone → materials is
binding through each zone's fixed biome/gathering palette; the level band adds
the gear/special layer.

**A dropped item's material tier must match the mob's tier** (added
2026-08-07). The ordinary `ilvl = min(mob level, 60)` rule of §5 already
implied it; stated outright
because the item is now material-named: a **T3 (Steel) item drops from
level 21–30 mobs** and nowhere else. A mob may not drop gear from a tier
its level band does not cover — that is what stops the drop table from
becoming a side door around the pick-tier gate of §3.0.4.

| Named-zone band | Materials | Gear drops | Special |
|---|---|---|---|
| Peaceful starts 1–10 | equivalent T1 access on both faction sides | T1, chances per §5.1 | no PvP objective |
| Peaceful home zones 11–20 | equivalent T2 access | T2, chances per §5.1 | first named rares; no contested zone |
| Peaceful heartland 21–30 | equivalent T3 access | T3, chances per §5.1 | preparation for the central frontier |
| Contested approaches 31–40 | equivalent T4 access | T4, elite chances on elites | all six race approaches are contested |
| Front 41–50 | equivalent T5 access | T5, elite chances on elites | The Broken Causeway and The Shattered Line; war-front objectives and quest hooks; no free supply crates |
| High front 51–60 / endpoints 60 | equivalent T6 access | T6; elites common | two contested dragons and the apex camps |
| Depth axis | six tier rocks gated by pick tier (§3.0.4); Iron is reachable in T1, mined Coal by T2, Silver by T3, Emberglass by T4, Abyssal Crystal by T5; one gem per tier rock (§3.0.1); deep T6 adds bounded density | cave mobs as per surface tier | **no gear-drop layer of its own**, at any depth (below) |
| Enemy faction | equivalent tier budgets, not necessarily identical palettes | same tier/source rules | enemy named rares and any raid-enabled king remain incentives |

**The depth axis pays in materials, and gets no drop layer of its own**
(decided 2026-08-08). The deep band below −1000 (`world.md` §4c) is a
level-60 place only a T6 pick reaches, which makes it the obvious home
for a T6 gear layer — and deliberately does not become one. Underground
mobs keep dropping exactly what their families drop on the surface (the
Gear drops column above); nothing is added for being deep. Two reasons,
both structural: **the best items come from crafting and from hard
bosses** (§0, §6.4), and a depth layer would be a third top source with neither a
crafter nor a boss behind it; and the depth already pays the endgame
*material*, which is the input the crafted endgame item is made of.
Depth buys danger and volume; the gear it feeds is made, not found.

### 5.1 Quality chance per source (kill, player-tagged)

**Still valid after the 2026-08-07 rework.** "Only professions can
enchant" (§6b.3) means only a profession can **apply** an enchant to an
item; **found items keep their own enchants**. A mob drop arrives
pre-enchanted from this table and is worn as it fell, with no crafter
involved. The two systems never meet.

Round 33 (user ruling, [round33-plan.md](../planning/round33-plan.md) §2.1).
One roll per kill decides, so a kill drops **at most one** gear item:

| Source | White (Common) | Blue (Uncommon) | Gold (Rare) | Total |
|---|---:|---:|---:|---:|
| Normal mob | 5% | 2% | 1% | 8% |
| Elite, named rare, zone leader, war-camp captain | 10% | 10% | 5% | 25% |
| Critter | — | — | — | 0% |

**Bosses** — the six race Kings, the two dragons and the rift boss (Round 36)
through their personal reward (§5.3, §5.4, §5.3b), the two PvP fortress
Generals on every enemy player's kill — always drop **two** items, each blue
or gold at even odds: Kings, Generals and the rift boss item level 65,
dragons item level 70. Their other loot (Fallen Crown,
Scaled Hide, the General's war trophies) stays. The General has no reward
ledger: his two items drop on the kill, like any mob gear, and only an enemy
player's kill drops them; his bodyguards, like royal guards, drop no gear.
**Encounter adds drop no gear and no bag** (Round 34): royal guards, the
General's bodyguards, the dragons' whelps and the raiders a King calls in his
fight. Their ordinary drops stay (the guards' war trophies and heavy cloth on
an enemy player's kill; the raiders' skeleton materials; whelps have none).

**Bags** drop from any mob at **0.1%** per kill (not from the Kraken Guard and
the Reed Angelfish, which drop no quality loot at all), independent of the gear roll,
sized by the mob's level: 1–15 → 8 slots, 16–30 → 16, 31–45 → 24, 46+ → 32
(the cloth bag line of `grug_inventory`). The 8-slot bag stays on sale; larger
bags otherwise come only from the Tailor or the Leatherworker.

Found enchantments do not imply a separate refined state. A found item's
quality is its enchant count: white none, blue one, gold two. Trinkets roll
0/1/2 like every other item; a single trinket enchant takes either channel
from that channel's pool (§6.2).

**Which item drops is one uniform draw over every equippable item of the
mob's own tier** (`grug_gear.drop_pool`, Round 33): the tier's six weapons and
twelve armour pieces, its shield and spellbook, and its six trinkets — 26
items, with no slot pre-selection and no per-family weighting.
Adding a registered family therefore changes the resulting proportions; no
fixed family count or weighted table exists anywhere in this design.

A found enchant has its item's enchant tier and is worth exactly the rule of
[item_tiers.md](item_tiers.md) §1.1 at the item's level, like a crafted
enchant of that tier (§6.3); only its stats are rolled.

Vendors buy a blue item at **×3** and a gold item at **×6** of its Common
buy-back ([economy.md](economy.md) §2).

WP5 still owes the loot/economy audit: found gear must not erase demand for
crafted gear. No removed masterwork/temper workflow is assumed by that audit.


### 5.2 Named rares (spawn rules decided in biomes_mobs §3.3)

2–4 h respawn, patrol routes, faction-wide broadcast. Loot per kill: the
elite row of §5.1 (10% white, 10% blue, 5% gold). Named rares drop **no
signature trophy** (user decision 2026-09-29, WP audit D4). Anti-camping:
patrol routes + broadcast + the 2–4 h jitter (already decided) — no
extra mechanic needed.

### 5.3 Apex world bosses (world.md §4b)

The two offshore dragons are separate contested encounters and use personal
boss rewards with independent per-character 24-hour loot lockouts. Their
participation and reset accounting matches the king ledger below. A boss
reward is two blue-or-gold items at item level 70 (§5.1) and authored materials, but it
never pays ledger money directly and no universal bar/pick depends on it:
continental T5 Abyssal Crystal is the ordinary T6 entry. There is no hoard
chest (WP audit E11) and no renewable gem socket on the islands (E5).

### 5.3b The rift boss (Round 36)

The main line's finale boss at the rift ([world.md](world.md) §4b) rewards
through the same participation ledger and death grace as the dragons. Once
per character per **24 hours** (its own rolling wall-clock lockout) a credited
participant receives the boss reward: two blue-or-gold items at item level 65
and nothing else. A credited kill inside the lockout gives that character an
**elite's roll** instead (§5.1's elite row at its level 60, at most one item)
and never moves the lockout. Every credited kill counts for achievements.

### 5.4 Six race Kings and Fallen Crowns

Each race has one killable level-65 elite King protected by four level-60
elite royal guards. Essential service NPCs are separate, passive and
invulnerable.

- **Fallen Crown** is one registered item with per-stack defeated-race
  provenance and generated name, not six currencies.
- Every eligible participant receives exactly one Crown entitlement. Personal
  allocation replaces a shared ground drop; the killing blow has no special
  ownership. All six Kings use the same quantity, reference-value budget and
  eligibility rules.
- The current-attempt ledger accepts a player who deals accepted damage to the
  King or a royal guard, or provides effective healing/shielding to an eligible
  attacker. A qualifying living player must be within 60 nodes at the kill. A
  participant slain by the encounter, another encounter NPC or an enemy player
  retains eligibility for 60 seconds. Proximity alone is insufficient; a full
  encounter reset clears the ledger and grace.
- A successful award starts that King's rolling 24-hour wall-clock Crown
  lockout for the character. Other enemy Kings remain independently rewarding;
  repeat kills during one lockout may proceed but grant no Crown.
- The Crown is the Crownbinder's input for crowning one item (§2,
  [item_tiers.md](item_tiers.md) §4); it stays unsellable. Royal provenance
  supplies visual identity.
- No universal bar, pick, profession-level advancement or ordinary base gear requires a
  Crown, and no power-bearing recipe is Crown-only. Royal guards drop no gear
  and no bag (encounter adds, §5.1), only a guard's war trophies and heavy
  cloth on an enemy player's kill; nothing they drop substitutes for a Crown.
  Rewards enter the ledger only if their sellable items are later sold.

### 5.5 Contested-front reward hook

The authored war front feeds crafting only through the existing
player-involvement war-trophy/heavy-cloth rules and later explicit quests.
WP42 ships no refilling supply crate. Each contested zone reserves one
non-loot quest-interaction slot for WP9; it is not a free material source.
The two endpoint apex camps add no renewable gem sockets: renewable ores are
removed entirely, camps included (user decision 2026-09-29, WP audit E5).

## 6. Quality tiers & enchant values

### 6.1 Meta model

Item meta carries `grug_quality` (1 Common / 2 Uncommon / 3 Rare / 4
Unique-reserved) and one serialized ordinary-affix table (`grug_ench`). Exact
storage keys are implementation owned; one idempotent description/stat
regeneration path reads them all.

**Level requirement** (Round 33, [round33-plan.md](../planning/round33-plan.md)
§2.2). **Every** equipment item — weapons, armour, shields, spellbooks,
trinkets; dropped, crafted or bought — requires the character level
**min(item level, 60)**. Ordinary base items therefore require levels
**1 / 10 / 20 / 30 / 40 / 50** across the six material tiers: T1 uses an
explicit level-1 requirement (`_grug_req_level`) while retaining item level 3
for base stats, so the starter kit and the first vendor bracket fit a new
character. A found item requires its own item level up to the character cap,
stored per stack (`grug_req_level`); boss drops at item level 65/70 require
level 60. Every equipment slot refuses an item above the character's level
and says so in the message feed, naming the slot; the tooltip ends with
"Requires level N" above level 1. The hand slots also enforce the
class-family permissions in `inventory_equipment.md`. Wood/Stone weapons
are absent; gathering tools cannot be equipped there. Higher-level items remain lootable and tradeable, just not
equippable yet. The
description is regenerated from meta on every change
(name colorized: white `#FFFFFF`,
blue `#4A90FF`, yellow `#FFD700`, orange `#FF8000`; one line per
enchant).

**Ordinary equipment descriptions always show the BASE stat** (decided 2026-08-07 in
WP7): under the name and the item level, one grey line carrying the
number the item actually contributes — `5 damage, 1.0 s swing` for
weapons (the swing interval belongs next to the damage, or a dagger's
higher rate is invisible — combat_stats.md §2), `3 armor rating` for armor pieces. Without it a player cannot compare two pieces
without re-deriving the §3.1/§3.2 curves by hand. The base stat does
**not** live in item meta and cannot be reconstructed from an enchant
roll, so the regeneration above must **preserve these lines and append
the enchant lines below them**. Every Weapon-slot item with positive damage
uses the same damage-and-swing line, including every Battle Axe; a missing item level omits only the `Item level` line, never the damage
line. Every weapon stack in a player's inventory adds
`Effective at level L: N damage per swing`, including melee bonus plus
the character-level damage fit; ilvl is already present in the weapon's base
damage and is never multiplied again. The line is initialized at trader
purchase, dropped-item pickup or crafting output, and refreshes on level or
equipment change only
when its bytes change. Attack speed applies via `tool_capabilities.
full_punch_interval` meta override; stats recompute on equip change
(WP15 hook). **The conversion is `fpi_new = fpi_base / (1 + p)`** for a
rolled `+p` (2026-08-13): "attack speed +16%" means sixteen percent more
swings per second, which is the only reading under which an attack speed
enchant is a linear DPS gain; `fpi × (1 − p)` would pay more than it says.
The override must be written as a **complete** tool-capability table — a
plain meta float named `full_punch_interval` is not read by the engine —
and every other capability of the base item is preserved unchanged. Enchant count: **Uncommon rolls exactly one affix; Rare rolls exactly one prefix and one suffix** — the decided budgets, and from 2026-08-07 also the prefix and
suffix count of §6b. Found/vendor Uncommon sources receive one affix and Rare
sources receive both channels. Crafted results use the same exact shape;
the chosen channels determine the count (§6b.5).

Trinkets are the exception to the ordinary
base-stat model: §6.2 gives them no base-stat line or durability, but two selectable enchant channels and an authored special.

The base-stat line uses the concrete item's level. Chosen affixes add only
their explicit values; there is no hidden damage/armor/lifetime multiplier.

**Hand-off from the vendor catalogs** (WP7 → WP5, 2026-08-07): vendor
gear ships with the item-def fields **`_grug_ilvl`, `_grug_req_level`,
`_grug_bracket` and `_grug_quality = 1`**. The slot filter reads the
requirement directly, so a bracket catalog needs no second list of levels or
per-stack duplicate.
The later quality/enchant pipeline derives its rolls from these fields and
preserves the requirement while rebuilding the description.

### 6.2 Enchant pools per item family (no duplicate stat per item)

| Family | Pool |
|---|---|
| Sword | +Str, +Dex, +attack speed%, +crit%, +max HP%, +max Mana% |
| Dagger | +Str, +Dex, +Int, +attack speed%, +crit%, +max HP%, +max Mana% |
| Battle Axe | +Str, +attack speed%, +crit%, +max HP% |
| Bow | +Dex, +crit%, +attack/draw speed%, +max HP%, +max Mana% |
| Staff, wand | +Int, +max Mana%, +crit%, +max HP% |
| Shield | +Str, +Dex, +max HP%, +armor rating |
| Spellbook (Tailor) | +Int, +max Mana%, +crit%, +max HP% |
| Metal armor | +Str, +max HP%, +armor rating |
| Leather armor | +Dex, +max HP%, +max Mana%, +crit%, +dodge% |
| Cloth armor | +Int, +max Mana%, +max HP%, +crit% |
| Bags | none |

Ordinary equipment keeps the no-duplicate-stat rule across its prefix and
suffix. Either channel draws from the same family pool; all sources add
before final caps.
Every HP/Mana affix is stored as a percentage: HP uses the current-level base
pool after the HP class factor, while Mana uses the class-neutral base pool.
Even when its name is shortened to "+HP" or "+Mana", its tooltip always shows
both the percentage and the absolute current-level contribution.

#### Trinket exception: one prefix, one suffix, one special

A passive trinket has one authored identity special plus two enchant channels:

- prefix choices: **Strength, Intelligence or Dexterity**;
- suffix choices: **maximum HP, maximum Mana or Crit**.

The pools make nine possible completed prefix/suffix pairs and structurally
prevent duplicate stats. Armor, Dodge and attack speed are excluded. Goldsmiths
craft the base item with empty channels, then select fixed-tier enchantments at
the Jeweller's Bench, just like other professions. Either channel may be filled
first or replaced; target tier must be at least enchant tier. No enchant value
is random: a found item rolls only which stats it carries (§5.1).

A trinket has no separate base-stat line, armor, durability or refinement state.
Its material tier scales the authored special; enchanting does not change that
special. Ordinary quality follows the number of applied enchants. Register six
core identities across six tiers, for 36 item ids. Identity, Setting, tier, item
level, required level, special strength and image are static; chosen enchants and
generated names remain per-stack metadata.

| Visual family | Core identities |
|---|---|
| Amulet | **Manawell Pendant**, **Last Light Locket** |
| Ring | **Battlebeat Band**, **Apothecary Loop** |
| Medallion/ornament | **Mercy Seal**, **Reclaimer's Mark** |

Either generic trinket slot accepts every form; the form grants no stat or
restriction. The same registered identity may not occupy both slots, even at
different material tiers. Different identities combine freely. Each special
defines its own two-slot rule; no consumer invents a default.
A later boss/quest trinket may use a distinct registered identity with one of
the same specials; it remains subject to that special's authored two-slot rule.

| Special | T1 | T2 | T3 | T4 | T5 | T6 | Two-slot behavior |
|---|---:|---:|---:|---:|---:|---:|---|
| Manawell, flat Mana/s | 0.05 | 0.10 | 0.15 | 0.25 | 0.35 | 0.50 | additive, cap 1.00/s |
| Battlebeat, Rage/accepted hit | 0.25 | 0.50 | 0.75 | 1.00 | 1.50 | 2.00 | additive, cap 4 Rage/hit |
| Mercy Seal, outgoing healing | 1% | 2% | 3% | 4% | 5% | 6% | additive, cap 12% |
| Last Light, max-HP absorb | 3% | 4% | 5% | 6% | 8% | 10% | highest only, shared 120 s cooldown |
| Reclaimer's Mark, max HP/Mana | 1% | 1.5% | 2% | 2.5% | 3% | 4% | highest only, shared 10 s cooldown |
| Reclaimer's Mark, Rage | 1 | 2 | 3 | 4 | 5 | 6 | same trigger/cooldown as its HP restore |
| Apothecary Loop, instant potion amount | 2.5% | 5% | 7.5% | 10% | 12.5% | 15% | additive, cap 30% |

- Manawell piggybacks the existing Mana-regeneration tick.
- Battlebeat settles only on an accepted equipped-weapon hit. Miss, dodge,
  full absorb and refused PvP grant nothing; fractional Rage may accumulate
  internally.
- Mercy Seal runs through the central outgoing-heal path.
- Last Light triggers after a survived hit leaves the wearer below 25% maximum
  HP. It grants an absorb from post-hit maximum HP for at most 120 seconds,
  sharing that 120-second cooldown, and cannot save an already lethal hit.
- Reclaimer's Mark triggers only on an XP-eligible kill, settles its shared
  cooldown first, then restores HP plus maximum-Mana percentage for Mage/
  Priest or HP plus flat Rage for Warrior. Gray kills grant nothing.
- Apothecary Loop increases only the restored amount of instant HP/Mana
  potions. It neither shortens nor resets the shared 60-second cooldown.

Direct damage procs, ability cooldown reduction, movement speed, gathering
yield, durability and vendor bonuses are excluded from the six-special MVP.
A future race-taunt trinket would consume its one authored-special channel,
not add a fourth channel; no such placeholder ships now.

The shared trinket owner rebuilds an event-driven per-character equipment cache
when equipment changes. Hot mana, heal, hit, kill and potion paths read that
cache and never rescan equipment per tick or event. It enforces the
same-identity-per-character exclusion and every cap/cooldown above.

### 6.3 Found-item enchant tier and value

**Enchant tier of a found item** (Round 33, round33-plan.md §2.3): item level
1–10 is T1, 11–20 T2 … 51–60 T6, above 60 (boss drops) T7
(`grug_items.enchant_tier`). Since Round 33 a found enchant has no random
value: it is worth exactly the rule of [item_tiers.md](item_tiers.md) §1.1 at
its item level and tier, like a crafted one of that tier. The four flat roll
bands that stood here are gone. A T2 enchant cannot be applied to a T1 item;
mastery never unlocks a suffix or scales a crafted value.

The endgame budget follows [item_tiers.md](item_tiers.md) §1.1: one enchant
is worth about 1.6 % + 0.04 % × L in its kind, and a fully damage-enchanted
level-60 Warrior gains about **+47 % / +57 % / +69 %** at item level 60 / 65 /
70 (Scout +55 % / +68 % / +82 %), the order of the intended +50–60 % fully
equipped ceiling ([combat_stats.md](combat_stats.md) §2).

**Combined cap policy (revised 2026-09-20).** Ordinary affixes, trinket
prefixes/suffixes, attributes and base equipment all add
before their consumers. Crit and Dodge cap at 30%. Armor sources add uncapped
raw rating; `combat_stats.md` §2 converts that rating against attacker level
and caps only final reduction at 70%. Character shows effective Crit/Dodge
plus armor rating and Damage reduction (same-level); Help explains formulas
and caps.

The old eight-identical-affix-slot calculation is retired: each trinket now has
one primary prefix and one HP/Mana/Crit suffix rather than four ordinary slots.
At T6, two trinkets can therefore add at most two direct Crit suffixes, while
the six ordinary combat stacks retain their family pools. These maxima can
intentionally push a same-level build to the 70% reduction
cap. Surplus rating remains useful against higher-level attackers. The
cap/demand audit evaluates all three source channels together.

### 6.4 Crafted quality

Base recipes produce Common gear and are universally craftable. One enchant
makes ordinary equipment Uncommon; one prefix plus one suffix makes it Rare.
There is no refinement prerequisite, bonus or separate Imbue/Temper path.
Enchant values follow the item level up to the enchant's tier
([item_tiers.md](item_tiers.md) §1.1). Trinket authored specials retain their
own rules.

## 6b. Enchantments

### 6b.1 Profession ownership

Apply enchantments at the owning profession station to the concrete stack.
Everyone can craft base gear; qualified professionals can apply or replace its
legal enchants. Tools are not weapons and receive no ordinary combat enchants.

### 6b.2 Tier bonuses (Round 33)

The nine stat curves and their tier caps are [item_tiers.md](item_tiers.md)
§1.1; the 588 operations and their inputs
[the current contract](crafting_equipment_revision.md#enchanting) and
item_tiers.md §2. A bonus grows with the item's level up to `10 × tier`; an
upgrade (item_tiers.md §3) or the crown (§4) raises it accordingly. No extra
base-damage or lifetime multiplier exists.

**Enchant inputs** (Round 28 ruling 28, Round 33): every operation of tier T
consumes the family's own material of tier T, the tier's loot item for the
chosen stat in its channel (`prefix_loot` / `suffix_loot`) and the tier's
mining or gathering item for the equipment family (`family_input`), from
`grug_professions/data/enchants.json`:

| Family (`family_input` key) | Profession | Own material T1 → T6 |
|---|---|---|
| sword, dagger, greataxe | Weaponsmith | Bronze → Abyssal Steel Bar |
| metal_armor, shield | Armorsmith | Bronze → Abyssal Steel Bar |
| leather_armor, bow | Leatherworker | Light → Nightscale Leather |
| cloth_armor, spellbook | Tailor | Patch → Stormweave Bolt |
| caster_weapon | Woodcarver | Seasoned → Heartwood Wood |
| trinket | Goldsmith | Tin → Gold-filigreed Abyssal Steel Setting |

Prefix and suffix of a stat take different loot; the trinket's prefix pool
uses `prefix_loot`, its suffix pool `suffix_loot`. No input may be another profession's product (a Cut gem is a
Goldsmith product, so other families use raw gems). Load fails on a missing entry, an unregistered item, an input declared
above the enchant tier or a foreign
product.

### 6b.3 Eligibility

Each ordinary enchantable item has one prefix and one suffix from T1. Either
channel may be filled first. Target tier must be at least enchant tier. The
family pools in §6.2 decide legal stats; a stat cannot occupy both channels.

### 6b.4 The prefix/suffix naming system

| Stat | Prefix | Suffix |
|---|---|---|
| Strength | Heavy | of the Bear |
| Dexterity | Quick | of the Fox |
| Intelligence | Clever | of the Owl |
| Maximum HP (%) | Stout | of the Ox |
| Maximum Mana (%) | Attuned | of the Raven |
| Crit (percentage points) | Lucky | of the Eagle |
| Attack speed (%) | Swift | of the Hornet |
| Dodge (percentage points) | Elusive | of the Cat |
| Armor rating | Stalwart | of the Tortoise |

Words are identical across tiers; the tooltip states the concrete value and
the enchant's tier, e.g. "+15 Strength (T5)".
Examples: *Bronze Sword of the Ox*, *Lucky Bronze Sword of the Bear*. No refined
state or marker exists.

### 6b.5 Qualification and replacement

Qualification and progression use the enchant recipe tier. Both channels are
available at every tier; mastery does not gate suffix access. Select the named
operation, inspect the exact preview, then apply it with its material cost.
Replacement preserves the other channel, wear and unrelated stack metadata.
An identical no-op (same stat and tier) is refused without cost or progress.
Overwriting a higher tier is allowed; the preview warns ("Replaces T7
Strength with T6 Strength.").

### 6b.6 Quality follows slot count

Zero/one/two ordinary affixes correspond to Common/Uncommon/Rare. Found items
roll which stats they carry, never their values. Trinket quality does
not alter its independently defined prefix/suffix/special structure.

### 6b.7 Special variants

No third ordinary enchant slot is included. Existing trinket specials remain.
There are no cultural or PvP finishes (removed in Round 33).

## 7. Upgrade mechanics

Enchants change through the named replacement workflow in §6b.5. Since Round
33 a profession **upgrade** (one per profession and tier, at its station)
lifts an item of its families and material tier T below item level `10 × T`
to `10 × T`, never lower, and its enchants follow; a **Fallen Crown** lifts
an item to `10 × T + 5` and its enchants one tier, once
([item_tiers.md](item_tiers.md) §3, §4). There are no Imbue/Temper kits,
random crafted application rolls or separate refinement steps.

## 8. Prices and money pacing

This section specifies the economy as shipped since the WP44 cutover (Round
29); [economy.md](economy.md) §2 owns the payout rules and
[durability_repair.md](durability_repair.md) the repair quotes.

All values use ledger copper (100c = 1s, 100s = 1g). No creature, NPC or
world node drops currency or a physical coin. Tiered combat income is the
expected vendor value of sellable loot; physical Gold remains a separate
Goldsmith/build material.

### 8.1 Income and reference values

- Ordinary quest rewards and expected level-appropriate loot value rise on the
  same approximate **×2.5 tier index** as Common gear. Scaling both preserves
  baseline time-to-buy. Elites and named encounters improve item/source
  budgets rather than bypassing the ledger with direct money drops.
- Reliable net solo income is measured after routine tier-appropriate repair
  and consumables, excluding rare jackpots, boss rewards and player trade.
  Mount, boat and respec prices derive from those tier rates (`economy.md`
  §3, §4).
- Every mob drop and every gathered good has a positive payout from the loot
  formula of economy.md §2 (class value × tier factor); processed goods pay
  their cheapest recipe's inputs. Material values rise with tier, while player
  trade remains their intended high-value market. Zero means unsellable.
- Every craft/cook and service path passes the anti-loop audit: an output pays
  at most its consumed inputs (break-even allowed).

### 8.2 Vendor prices and buy-back

The exact unenchanted Common slot ladder is:

| Common slot | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 25c | 65c | 1s60c | 4s | 10s | 25s |
| Chest | 20c | 50c | 1s30c | 3s20c | 8s | 20s |
| Offhand/head/legs/feet | 15c | 35c | 80c | 2s | 5s | 12s50c |

The table prices slots, not weapon families. Quality/enchanted gear costs more
than Common, but no premium may alter these baseline references. Vendors sell
only the T1 column (Round 33); the other columns are reference prices.

Vendor buy-back is capped at **5% of the purchase price, rounded up to the
next copper**, and applies to goods a vendor sells and, since Round 33, to
every equippable of the gear catalog by its reference price — T2+ bases,
shields, spellbooks and trinkets (the "other" slot; [item_tiers.md](item_tiers.md)
§6.1); a blue item pays ×3, a gold one ×6. A T1 Common weapon
therefore returns 2c and a T6 weapon returns 1s25c; a crafted good never
returns more than its cheapest recipe's inputs. Same-race purchase discounts
never raise buy-back. Loot and gathered goods are paid by the formula of
economy.md §2, never by a reference price; zero means unsellable.

Core supplies remain simple fixed-price goods. No profession book is sold or
replaced: the UI book reflects player-meta progression directly. Finder-item
rows are deleted; no Dowsing Rod or Gem Detector is sold or crafted.

### 8.3 Recurring sinks

- **Repair:** [durability_repair.md](durability_repair.md) is authoritative for
  eligible identities, exact wear events, non-destruction, the current
  tier-specific lifetime tables, all-trainer service and the money-only
  quote: since Round 33 the full reference price times the missing
  durability (factor 1.00).
- **The crown:** the Crownbinder in every capital applies one Fallen Crown to
  one item for one hour of band-6 income, **1g 47s** (`grug_traders.CROWN_FEE`,
  checked by `tools/r29_e4/income.py`; [item_tiers.md](item_tiers.md) §4).
- **Culture vendor:** the Decor Merchant in every capital sells cosmetic,
  non-craftable blocks and lights in four bands: accent blocks 25c, small
  lights 1s, large lights 10s, showpieces 1g ([item_tiers.md](item_tiers.md)
  §6.4; the shelf is in `grug_traders/stock.lua`).
- **Respec:** repeatable **in the talent UI, with no class trainer and no
  NPC** (ruling 4 of 2026-09-16, `skill_trees.md` §5). It costs **five
  minutes of measured reliable net solo income** at the character's bracket,
  rounded by §8.1's money axis and `economy.md` §4.1, and **the first respec
  of a character is free** (ruling 22). Retires "repeatable at the class
  trainer and rising with level".
- Job supplies and vendor consumables provide the ordinary steady drain.

### 8.4 Services, claims and mounts

Private housing isles, paid depth rights and the complete guild system are
retired. Housing has no money price, tiers, upgrades or additional stones
(Round 25; [housing.md](housing.md) owns the complete contract):

- **Claim Stone** `grug_housing:claim_stone`: one per player, soulbound (never
  in chests, bags, trades or mail; kept on death; destroyed when dropped), not
  craftable and not sold. The Housing Steward in every capital hands it out
  free from level 20 while the player has none, carried or placed.
- **Upkeep fuel:** the placed stone accepts only coal lumps
  (`default:coal_lump`) and charcoal (`grug_smelting:charcoal`), both burning
  7 h 16 min (26 160 s) per lump, at most 99 in its slot (≈ 30 days). Coal
  blocks are refused. Inserted fuel cannot be taken out; picking the stone up
  returns only the whole unburnt lumps.

Mounts at levels 15/30/45/60 cost **15 minutes / 45 minutes / 2 hours /
5 hours** of reliable tier-appropriate net solo income: **1s5c, 7s, 1g32s and
7g37s**; the Boat costs 1s5c and the Improved Boat 7s, like the two land
tiers (`economy.md` §4.2). The retired fixed 1s/8s/30s/60s table is not a
fallback.

## 9. Bow and arrow item foundation

**Its consumer is delivered in Round 11**: the Scout's base kit opens
with a bow shot ([scout.md](scout.md) §2, rulings 7 and 12 of
[skill_trees.md](skill_trees.md) §5) and Round 17 changes the arrow to **targeted homing**, like Fireball
(`combat_stats.md` §2, `classes.md` §2b). Round 11 has delivered the registered bow and arrow
item foundation below (Round 28 replaced the quiver item with a Scout-only
slot). The Scout runtime owns draw, launch and
accepted-action hit settlement.

Item path (source: `mcl_bows`, code **LGPL 3.0 or GPL 3.0** — VoxeLibre
dual-licences every mod, `LEGAL.md:25-28`, and both are on `AGENTS.md`'s
permitted list ✓; media: **textures CC BY-SA 4.0**, sounds **two CC0** plus
**one CC BY 3.0** (`mcl_bows_hit_player.ogg`, tim.kahn) — so exactly **one**
attribution-requiring sound, not two; port ≈ 1000 lines incl.
`vl_projectile`, §1.2). The item/ammunition foundation and Scout ability
consumer are active:

- **Bow family on the weapon curve**: bow damage = the 1H curve
  (8/13/19/24 at ilvl 12/27/42/57) at 25 m range, full draw 2.5 s (mcl
  hold-pattern); Loose multiplies it by `0.2 + 2.05 f²` of the draw fraction
  (×2.25 at full draw, `combat_stats.md`). One bow per material tier,
  material-named like everything else (§3.0.3). Its ordinary affix pool is
  Dexterity, Crit, draw speed, HP and Mana; draw speed uses the weapon-family
  attack-speed channel to shorten draw time.
- **Arrows** stack to **100** in any inventory (Round 28 ruling 26, which
  replaced the 200 of the 2026-09-20 playtest ruling); new Scouts receive 200
  in their quiver slot, which holds up to 500 (`inventory_equipment.md` §3). Ammo also has a targeted projectile entity;
  one Basics craft fills one stack of 100 from 1 bronze bar + 2 sticks
  (Round 28 ruling 26). Arrows cost 3c each
  (2c after the same-race discount) at every race vendor and the Bowyer;
  traders do not buy them back, because the basic craft makes a full stack
  from one bar (economy.md §2).
- **Plain production is Basics; the Leatherworker owns enchantments and
  upgrades** (Round 33, [item_tiers.md](item_tiers.md) §3.3). The
  Scout consumes the family in V1. Shots draw from the Scout's quiver slot
  first, then `main`.

## 10. Historical decision log (non-authoritative)

Decision history moved to
[the items history archive](../archive/design/items-history.md#10-historical-decision-log-non-authoritative).
Sections §0–§9 and their topical links remain the only living authority.

### 10.1 2026-08-06

See [archived §10.1](../archive/design/items-history.md#101-2026-08-06).

### 10.2 2026-08-07 (crafting rework)

See [archived §10.2](../archive/design/items-history.md#102-2026-08-07-crafting-rework).

### 10.3 2026-08-08

See [archived §10.3](../archive/design/items-history.md#103-2026-08-08).

### Round 21 visual and basic-ammunition decisions

Approved 2026-09-24: a valid 1.5s food hold provides
continuous bite feedback at gain 0.5; a modest moving HUD food image may
substitute for the native wield image with full cancellation cleanup. Keep
consumption timing and interaction priority. Basic arrows craft 200 (100 since
Round 28: one craft fills one stack) from one
Bronze Bar and two Sticks diagonally (`--M / -S- / S--`), without feathers or
a profession. No other metal recipe or bonus-damage ammo tier is included.
