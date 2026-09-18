# Creative plan: Cooking and Alchemy v1 (Round 7 deliverable R7-COOK)

Author: the Round 7 orchestrator (Claude Fable), 2026-09-18, on the user's
request to "work out a creative plan yourself". Evidence lanes:
[round7-inventory-extract.md](round7-inventory-extract.md) (what the game
has today) and [plants-and-potions-reference.md](plants-and-potions-reference.md)
(what the reference projects offer, with licences). This is a **plan for the
user's ruling**, not a decided rule: §9 lists every decided rule it wants to
change and §10 the decisions it needs. Round 8 (`TODO-round8.md`, lanes
R8-MAP, R8-COOK, R8-ALCH) implements what the user approves.

Binding inputs: the Round 7 rulings R7.1–R7.5 (`TODO-round7.md` §1), the
Alchemist catalog (`items_crafting.md` §3.6), Cooking and the six cooking
groups (§3.7, table E21), the recipe book (§2.2), the material ladder tiers
and levels (§3.0.1: T1 1–10, T2 11–20, T3 21–30, T4 31–40, T5 41–50,
T6 51–60), the gathering-source contract (`biomes_mobs.md` §2.2) and the
shipped gathering catalog (`mods/ITEMS/grug_gathering/catalog.lua`).

## 1. The consumable triangle

Three consumable classes, each with one job, so none makes another
redundant:

| Class | Job | Effect shape | In combat | Cooldown / exclusivity | Source |
|---|---|---|---|---|---|
| **Food** | sustain between fights | fixed instant HP per tier + 3-min regeneration buff (5 s ticks) + a weak secondary bonus from T3 | instant and regeneration pause; secondary bonus stays | one food buff at a time, newest wins; no cooldown | Cooking (universal, book gated by ingredients) |
| **Potion** | the emergency button | instant percent effect (HP, mana, short speed) | the only in-combat heal | shared 60 s wall-clock cooldown (`grug_traders/potion.lua`), refused at full | Alchemy T1–T3; vendor sells the weak T1 floor |
| **Elixir** | the strong, chosen buff | one strong percent stat bonus, 15 min, **no regeneration** | fully active | one elixir at a time (§3.6), **stacks with food, also on the same stat** (R7.3) | Alchemy T3–T6 |

Stacking rule, restated for implementers: every active status contributes
its modifiers through `grug_core.status_modifier_sum` (Round 7 R7-FOOD);
the sum is applied like a talent bonus. Food + elixir = sum. Two foods never
coexist; two elixirs never coexist. Utility flasks (§5.3) are elixirs for
this rule.

## 2. Numbers

### 2.1 Tiers, levels, instant values

The tier's first level is the consumable's minimum level (R7.4), taken from
the material ladder so a T2 dish and a T2 sword open together:

| Tier | Min level | Instant HP (fixed) | Instant as % of the neutral base pool at the tier's first level | … at its last level |
|---|---:|---:|---:|---:|
| T1 | 1 | 5 | 19 % (26) | 4 % (136) |
| T2 | 11 | 15 | 9 % (159) | 4 % (384) |
| T3 | 21 | 40 | 9 % (416) | 5 % (764) |
| T4 | 31 | 90 | 11 % (809) | 7 % (1276) |
| T5 | 41 | 180 | 13 % (1329) | 9 % (1920) |
| T6 | 51 | 300 | 15 % (1983) | 11 % (2696) |

(Base pool `20 + 5L + 0.66L²`, `combat_stats.md`.) The instant value is a
snack, not a heal: it shows the dish did something the moment you eat it and
it never competes with the potion's 30 %. The FOOD lane ships the same table
with min levels 1/10/20/30/40/50; **the plan proposes 1/11/21/31/41/51** to
match §3.0.1 (data change only).

### 2.2 Regeneration per 5 s tick (percent of MAX HP, R7.1's ruling of
2026-09-17 that self-consumption uses the maximum pool)

| Kind | T1 | T2 | T3 | T4 | T5 | T6 | Over the full 3 min (36 ticks) |
|---|---:|---:|---:|---:|---:|---:|---|
| Raw edible of the tier | 1 % | 1 % | 1 % | 1 % | 1 % | 1 % | 36 % |
| Dish | 2 % | 2.5 % | 3 % | 3.5 % | 4 % | 5 % | 72 / 90 / 108 / 126 / 144 / 180 % |

Every tick restores at least 1 HP. A caster dish applies the same percent to
mana as well (both pools, one buff). The dish curve deliberately stays below
"full heal in one minute": at T6 a full refill takes 100 s of not fighting,
which is the pause between two pulls, not a reason to skip the potion.

### 2.3 Secondary bonus by role (active in combat)

| Role line | T1–T2 | T3 | T4 | T5 | T6 |
|---|---|---|---|---|---|
| **Hearty** (universal, tank) | none | +2 % HP pool | +4 % HP pool | +6 % HP pool | +8 % HP pool |
| **Caster** (HP + mana regeneration) | none | +2 % mana pool | +4 % mana pool | +6 % mana pool | +8 % mana pool |
| **Hunter** (melee / archer) | none | +2 % HP pool | +4 % HP pool | +1 % crit | +1 % crit |

Three role lines, not four: the user's "tank" role is the Hearty line (HP
pool is what a tank wants; armor as a food bonus would need an armor
percent model the game does not have). Decision §10.2.

### 2.4 Mana regeneration (R7.5) — the trade-off, made visible

Today: 2 %/s of max mana out of combat, 0.5 %/s in combat
(`grug_abilities/init.lua:2582-2593`). Proposal implemented by R7-FOOD as a
data table: out of combat `1 + 0.15 × level` mana/s, in combat a quarter.

| Level | Pool | Today ooc (mana/s, time to full) | Proposal ooc | Today in combat | Proposal in combat |
|---:|---:|---|---|---|---|
| 1 | 26 | 0.5, 50 s | 1.15, 23 s | 0.13 | 0.29 |
| 10 | 136 | 2.7, 50 s | 2.5, 54 s | 0.68 | 0.63 |
| 20 | 384 | 7.7, 50 s | 4.0, 96 s | 1.9 | 1.0 |
| 30 | 764 | 15.3, 50 s | 5.5, 139 s | 3.8 | 1.4 |
| 40 | 1276 | 25.5, 50 s | 7.0, 182 s | 6.4 | 1.75 |
| 60 | 2696 | 53.9, 50 s | 10.0, 270 s | 13.5 | 2.5 |

What the curve buys: the user's goal (a level-60 caster needs food for a
good regeneration; a T6 caster dish adds 5 % of the pool per 5 s = 27 mana/s,
nearly tripling the base). What it costs: the **in-combat** rate at level 60
falls from 13.5 to 2.5 mana/s, one fifth of today, and the Round 6 TTK/TTD
bands were measured with today's in-combat regen. Two options for the user:

- **A (recommended):** keep the proposal for out of combat, but set the
  in-combat rate to **`max(quarter of ooc, 0.25 %/s of the pool)`** — a
  floor of half of today's in-combat rate (6.7 mana/s at L60), so sustained
  casting loses a little, not 80 %. Cold Focus keeps its relative effect on
  whichever term wins.
- **B:** the pure quarter as briefed; re-measure the Mage TTK band with the
  Round 6 tool (`tools/r5_progression/ttk_measure.lua`) before Round 8 ends.

Either way the numbers are a data table in R7-FOOD; nothing structural
changes.

## 3. Ingredient catalog by zone, tier and band

Bands are R7.6's thirds along the continent axis; "band 1" is the outer
third of a zone, "band 3" the third toward the front. Existing sources are
the shipped catalog rows; **new** rows are this plan's proposals for R8-MAP
(assets from the reference projects R7-REF verifies; every new plant is a
one-cell hand-gathered node in the P9G pattern unless marked).

### 3.1 What exists (26 gathering identities, `biomes_mobs.md` §2.2)

| Ingredient | Kind | Tier | Zones (start → front) | Note |
|---|---|---|---|---|
| Potato | food, crop | T1 | Dawnmere, Goldmead, Whitebridge, Ashenward, Broken Causeway | meadows only — **Throng has no potato**; corn is its T1 gate |
| Corn | food, crop | T1 | Dawnmere, Goldmead, Whitebridge, Ashenward, Sunscar, Redtusk, Speargrass, Bannerbreak, Broken Causeway, Shattered Line | meadows + savanna |
| Apple | food (tree) | T2 gate (Accord extra) | deep forest, elf forest, meadows apple trees | Accord-heavy |
| Blueberries | food (bush) | T2 gate | pine hills | Dwarf column only |
| Mushroom | found-only food | T3 gate | Whitebridge, Lorindor, Moonfall, Ashenward, Glassroot, Broken Causeway, Gravesalt, Skyglass, + Throng rows | bone forest / deep forest / swamp |
| Melon | food, crop | T4 gate | Glassroot, Skyglass, Stormscale, Kapok, Raincall, Thunderroot, Totemwater, Whispering | jungle palettes — **Accord reaches it only at Glassroot (31–40)** |
| Sunleaf | spice T1 | T1 | Goldmead, Starbough, Raincall, Redtusk | 11–20 zones, both continents |
| Marshbloom | spice T2, T4 gate | T2 | Lorindor, Whitebridge, Ossuary, Whispering | swamp mud |
| Stormkelp | spice T3, T5 gate | T3 | Gravesalt, Skyglass, Stormscale, Wyrmglass | **51–60 zones only** |
| Rock Salt | found-only, T5 gate | T5 | Gravesalt, Stormscale, Wyrmglass | beach sand, **51–60 zones only** |
| Wild Cocoa | found-only, T6 gate | T6 | Skyglass, Stormscale | raw mana food today |
| Gravemoss / Dragonweed / Crimson Lotus | healing herbs T1/T2/T3 | Alchemist only | Copperfell, Mournfen / Ashenward, Frostbarrow, Bannerbreak, Ossuary / Skyglass, Stormscale | fail-closed authorizer seam exists |
| Meat, raw fish | animal | any | every zone (drops); fishing anywhere | fish also from Mirefolk |
| Venom gland, venom sac, slime gel, bear claw, fang, croc tooth, ape hair, shiny scale, bone, zombie flesh | mob parts | by mob level | per family (`biomes_mobs.md` §3.1) | alchemy reagents and trophies |

**Two gaps the table shows.** (1) The T5 gate (rock salt + stormkelp)
exists only in level-51–60 zones, so a level-41–50 character in The
Shattered Line cannot open T5 cooking; T5 is unreachable at its own level.
(2) Melon, the T4 gate, is jungle-only and reaches the Accord only in
Glassroot Wilds (31–40), which is fine for the tier but leaves the Human
and Dwarf columns without a T4 gate ingredient of their own. §3.2 fixes both.

### 3.2 Proposed new plants (R8-MAP input)

| New plant | Kind, tier | Grows where (biome → zones, band) | Asset candidate (R7-REF verifies licence) | Why |
|---|---|---|---|---|
| **Wild Grain** (wheat) | food, crop, T1 | meadows, savanna, pine-hills clearings → all six start zones band 2–3 and the 11–20 zones | `x_farming` barley/rice or VoxeLibre `mcl_farming` wheat (R7-REF: `farming` carries five NC textures, not cleared) | bread is the universal T1 dish base every start zone lacks; farmable later |
| **Carrot** (Accord) / **Cassava** (Throng) | food, crop, T1 | meadows + elf forest / jungle edge + savanna → start zones band 1–2 | `x_farming` carrot (CC BY-SA 4.0 runtime media) ; cassava = retextured `x_farming` potato | the T1 caster dish root; mirrored pair per the cross-continent rule |
| **Pumpkin** | food, crop, T2 | meadows edges, swamp margins, blight → 11–20 zones | VoxeLibre `mcl_farming` pumpkin | T2 Hearty dish; carve-able later (housing decoration) |
| **Sugar Cane** | sweetener, crop, T2 | **shore sand** beside fresh and salt water in every zone with a shore, band-independent | VoxeLibre `mcl_core` reeds (sugar cane) | the user's shore rule (sand + reeds); preserves and glazes |
| **Bamboo shoot** | food T1 (shoot) + material | **shore sand and mud** in jungle-edge, deep-jungle and swamp palettes | VoxeLibre `mcl_bamboo` | Throng shore identity; T1 Caster ingredient on that continent |
| **Wild Onion** (Accord) / **Fire Pepper** (Throng) | spice T1–T2 | deep forest, pine hills / badlands, savanna | `x_farming` has no onion or chili: retint VoxeLibre beetroot (onion) and `x_farming` strawberry (fire pepper), or hand-drawn 16 px textures | a second early spice so Cooking is not sunleaf-only; the Hunter line's flavour |
| **Cave Cap** | found-only food + alchemy reagent, T3 | **underground −100 to −500**, on stone in caves (P9G-style single node, cave-air host) | tinted `default` mushroom (already shipped) | gives Cooking and Alchemy a depth ingredient; the underground world of the mob plan needs a reason to forage |
| **Salt Crust** | found-only, T5 (alias of Rock Salt) | **badlands mesa clay in The Shattered Line and Bannerbreak Mesa** (salt flats, band 2–3) | existing rock-salt texture | closes gap (1): T5's gate reaches a 41–50 zone |
| **Stormkelp** extra host | spice T3 | swamp shores of The Shattered Line and The Broken Causeway | existing | closes gap (1) for the other half of the gate |
| **Frost Melon** (Dwarf/Human alias of Melon) | food, crop, T4 | crags tarns and Whitebridge/Frostbarrow swamp margins | existing melon, tinted | closes gap (2): the Accord's northern columns get a T4 gate on their own axis |
| **Ember Moss** | alchemy reagent T5 | **y ≤ −701** on emberrock, cave-air host | tinted gravemoss | the Alchemy depth ingredient for T5 elixirs; deep mining pays in reagents too (`world.md` §4c) |

Everything else stays found-only as decided (mushrooms, wild cocoa, rock
salt): the top of the ladder remains a reason to travel. Asset sources
follow R7-REF's verdict (`plants-and-potions-reference.md` §8): `x_farming`
is the one recommended new reference submodule (code LGPL-2.1, runtime
media with per-file CC BY-SA rows; its `.blend`/`.xcf` sources are not
cleared), `farming` is not (NC textures), VoxeLibre covers the core crops
and the potion lifecycle.

### 3.3 The cooking ladder by zone column (both continents, outer → front)

| Column | Band 1–3 of the start zone (T1) | 11–20 zone (T2) | 21–30 zones (T3) | 31–40 zone (T4) | Front 41–60 (T5–T6) |
|---|---|---|---|---|---|
| Dwarf (pine hills / crags) | grain, carrot, blueberries, boar meat, fish | onion, pumpkin, sugar cane at the tarns, gravemoss (Alch.) | mushroom (Frostbarrow swamp), frost melon, dragonweed | frost melon, mushroom, marshbloom via Whitebridge trade | salt, stormkelp, cocoa on the front |
| Human (meadows / deep forest) | potato, corn, grain, carrot, apple, meat, fish | pumpkin, sugar cane, onion, sunleaf | mushroom, marshbloom (Whitebridge), frost melon | mushroom, marshbloom, dragonweed (Ashenward) | Broken Causeway 31–40 → front 51+ |
| Elf (elf forest) | grain, carrot, apple, meat, fish | sunleaf, onion, sugar cane | mushroom (Lorindor, Moonfall), marshbloom | melon + mushroom (Glassroot) | Skyglass: cocoa, lotus, stormkelp |
| Undead (blight / bone forest) | corn, cassava, grain, plague-boar meat, fish | pumpkin, pepper, gravemoss (Mournfen swamp), sugar cane | mushroom (Ossuary), marshbloom, dragonweed | mushroom, salt crust (Blackwind is 31–40: **no**, keep salt for 41+) | Gravesalt: salt, stormkelp |
| Orc (savanna / badlands) | corn, cassava, grain, boar meat, zebra meat | pepper, sunleaf, sugar cane at waterholes | mushroom? **none** — Speargrass has swamp 5 %: add the mushroom row there | dragonweed, salt crust (Bannerbreak) | Shattered Line: salt crust, stormkelp (41–50) |
| Troll (jungle edge / deep jungle) | cassava, bamboo shoot, melon (Kapok!), jungle-boar meat, fish | sunleaf, pepper, sugar cane, bamboo | mushroom (Whispering, Totemwater), marshbloom, melon | melon, mushroom, Thunderroot | Stormscale: cocoa, lotus, salt, stormkelp |

Melon already grows in Kapok Cradle (a 1–10 zone) while it gates T4: that
is a catalog fact, not a bug — the T4 book group still needs level 31, and
a Troll novice carrying melons to a level-31 cook is exactly the trade the
economy wants. Two catalog fixes for R8-MAP: a mushroom host in Speargrass
Reach (its 5 % swamp) so the Orc column reaches T3 at 21–30, and no salt
below level 41.

## 4. The cooking book: six tiers, three role lines

Recipe grammar: **1 protein (meat or fish) or 1 base (grain, root)** +
**the tier's gate ingredient** + **optionally a spice**; three ingredients
maximum, so a serving is a small trip, not a shopping list. E21's dish
names are kept where they exist; new dishes fill the role lines. Plain
furnace cooking (Cooked Meat, Cooked Fish, **Bread** from grain) needs no
book and is a T1 Hearty dish with the raw-rule regeneration plus 1 pp
(1 % → 2 %): the furnace is the first cooking station everyone owns.

| Tier (gate) | Hearty | Caster (HP + mana) | Hunter |
|---|---|---|---|
| **T1** (potato / corn) | Hearty Stew (meat + potato or corn) [E21] | Sweetroot Mash (carrot or cassava + potato or corn) | Corn-Crusted Fish (fish + corn) |
| **T2** (berries; apple as the Accord extra) | Pumpkin Stew (pumpkin + meat + potato or corn) | Berry Preserve (2 berries + sugar cane) [E21, + sugar] | Fruit-Glazed Roast (meat + apple or berries) [E21] |
| **T3** (mushroom) | Forager's Pot (mushroom + meat + potato or corn) [E21] | Mushroom Skewer (2 mushrooms) [E21] | Onion-Seared Steak (meat + wild onion or fire pepper + mushroom) |
| **T4** (melon + marshbloom) | Marsh Roast (meat + marshbloom + potato or corn) | Marshbloom Chowder (fish + marshbloom) [E21] | Hunter's Feast (2 meat + melon + mushroom) [E21] |
| **T5** (rock salt + stormkelp) | Kelp-Wrapped Roast (meat + stormkelp + rock salt) [E21] | Stormkelp Broth (stormkelp + fish + melon) | Salt-Crusted Fish (fish + rock salt) [E21] |
| **T6** (wild cocoa) | Grand Feast (2 meat + wild cocoa + stormkelp) [E21] | Jungle Cocoa (2 wild cocoa + rock salt) [E21] | Cocoa-Rubbed Game (meat + wild cocoa + fire pepper or wild onion) |

Effects come from §2 by tier and role; a recipe never carries its own
numbers. Tooltip pattern (R7-FOOD ships the format): *"+40 HP now. Then
+3 % HP every 5 s for 3 min. +2 % HP pool while it lasts. Regeneration
pauses in combat; the pool bonus stays. Requires level 21."*

Stations: the **furnace** for plain cooking; a **Cooking Fire** node
(cheap: 3 sticks + 1 stone, placeable anywhere, `find_node_near` like the
profession benches, `inventory_equipment.md` §4) for book recipes; capitals
and villages get one in the tavern socket. The book is `grug_items:book_cooking`
per §2.2, tier groups open on the gate ingredient: crafting any T-n gate
ingredient into any T-n dish once (or holding the ingredient and opening the
book — decision §10.5) opens the group.

Books, per Round 5's R22 (durable wording `BACKLOG.md:33`, not yet in
`docs/design/`, evidence doc §5.1): the **player recipe book** lists every
global recipe the character has opened, and each station carries a
**station book** (furnace: plain cooking and smelting; Cooking Fire: the
dish groups; alchemy table: potions and elixirs). The tier-group gating
above lives in the player's meta (§2.2); the station books are views.

Qualities: R9's raw / simply cooked / well cooked becomes **raw / dish**.
"Well cooked" as a third state is retired (§9); the cooking mastery axis is
the tier, and the profession-style refinement (§6b) does not apply to
food.

## 5. Alchemy v1

### 5.1 Structure

Alchemist is a main profession with keystones (§2.2/§2.3) and gathers its
own herbs (§3.6). Book groups follow the material tiers; the §3.6 mastery
names map onto them: Apprentice = T1–T2, Journeyman = T3, Expert = T4–T5,
Master = T6. Station: the **alchemy table** (§3.6). Vials from the vendor.
Recipe grammar: **2 reagents + 1 vial**, as decided.

Reagent pool: healing herbs (gravemoss T1, dragonweed T2, crimson lotus
T3), spices (sunleaf, marshbloom, stormkelp), the new Cave Cap (T3) and
Ember Moss (T5), mob parts (venom gland, venom sac, slime gel, bear claw,
fang, croc tooth, shiny scale, bone), sugar cane, wild cocoa.

### 5.2 Potions (T1–T3; instant; shared 60 s cooldown; the in-combat monopoly)

| Tier | Potion | Recipe | Effect |
|---|---|---|---|
| T1 | Healing Potion | gravemoss + sunleaf + vial | 30 % HP instantly (the decided standard; the vendor's 15 % stays the floor) |
| T1 | Mana Potion | gravemoss + sugar cane + vial | 30 % mana instantly |
| T2 | Antivenom | dragonweed + venom gland + vial | cures poison [E: §3.6 unchanged] |
| T2 | Swiftness Draught | dragonweed + fang + vial | **+10 % speed for 5 s** (R7.3) — §3.6 says +8 % / 15 s; §9 |
| T3 | Greater Healing / Greater Mana | crimson lotus + gravemoss or sugar cane + vial | still 30 %, but **no full-health refusal on the mana half and a 45 s cooldown** instead of 60 (decision §10.6); the tier buys convenience, not a bigger number (`combat_stats.md` §5: no consumable treadmill) |
| T3 | Cave Draught | cave cap + slime gel + vial | 10 min night vision (replaces Cat's-Eye from Expert; the underground world wants it earlier) |

### 5.3 Elixirs (T3–T6; 15 min; one at a time; no regeneration; stack with food)

R7.3 replaces the attribute elixirs (+2/+4/+6 Str/Int/Dex, §3.6) with
pool and crit percentages, because Round 6 made attributes secondary-only
and a +2 Str elixir is now noise:

| Tier | Vigor (HP pool) | Focus (mana pool) | Precision (crit) | Utility flask |
|---|---|---|---|---|
| T3 | +5 % | +5 % | +1 % | — |
| T4 | +10 % | +10 % | +2 % | Stoneskin Flask +4 % armor, 30 min [§3.6, unchanged] |
| T5 | +15 % | +15 % | +3 % | Deepwater Draught, water breathing 10 min [§3.6 Expert] |
| T6 | +20 % | +20 % | +4 % | Sovereign's Flask [§4 Human signature, unchanged] |

Recipes: Vigor = crimson lotus + bear claw (T3), + croc tooth (T4),
+ ember moss (T5/T6); Focus = crimson lotus + wild cocoa / cave cap /
ember moss; Precision = crimson lotus + fang / shiny scale / ember moss.
The T5/T6 rows share Ember Moss on purpose: the top elixirs need the deep
reagent, so deep mining and the front both feed the Alchemist.

Apothecary gear (§3.6: +10 % duration, +1 elixir attribute per piece) keeps
the duration half; the "+1 attribute" half becomes **+1 percentage point on
the elixir's stat** per piece (max 2 pieces) — §9.

### 5.4 Minimum levels and stacking

Potions and elixirs carry `_grug_ilvl` = the tier's first level, through
the same helper food uses (R7-FOOD Part B). Food + elixir stack; potion
effects are instant and stack with nothing. The elixir does not touch the
potion clock (`potion.lua` comment, "an elixir is not an instant potion").

## 6. Raw items and today's foods under the new rule

Every gathered edible, mob meat and raw fish is a raw item of its tier
(R7.1): the tier's instant value plus 1 % / 5 s. Tiers for existing items:
apple, blueberries, potato, corn, meat, fish, mushroom = T1 raw when eaten
raw (their **dish** tier is what the ladder gates); melon T1 raw; wild cocoa
raw = T1 mana food (5 mana instantly + 1 % mana / 5 s) so a novice who finds
cocoa gets a taste, and the T6 dish is the reward. Rock salt is not edible.

## 7. What the mapgen must provide (R8-MAP input, consolidated)

1. **Shore sand** along water in every zone with a bank (Round 6's bank rule
   stays), with **sugar cane** on sand beside water in every palette and
   **bamboo** on sand and mud in the jungle-edge, deep-jungle and swamp
   palettes. Sand is the furnace's glass input (user ruling). Placement
   reuses the shipped deterministic shore predicates (`dry_cardinal`,
   `salt_cardinal` in `grug_gathering/catalog.lua`), not a biome-name
   lookup (R7-REF §7).
2. **A second soil per zone**: meadows keep grass but gain dirt patches and
   farmland-ready soil near villages; pine hills gain gravel benches; savanna
   gains cracked earth; jungle edge gains mud flats; blight gains ash; elf
   forest gains moss. The plant rows above name their host soils.
3. **New P9G rows** for the §3.2 plants with densities in the existing
   range (1/256 for staples, 1/512 for spices, 1/768 for cave cap, 1/1024
   for ember moss), the catalog fixes (mushroom in Speargrass Reach, salt
   crust in Shattered Line and Bannerbreak, stormkelp in Shattered Line and
   Broken Causeway, frost melon in Frostbarrow and Whitebridge), and the two
   underground rows (cave-air host, first underground P9G use).
4. **Crop soils** as scenery now (tilled patches at village fields) so
   farming (WP32) later flips them on without a mapgen change.

## 8. Round 8 sequencing

R8-MAP first (plants exist), then R8-COOK (book, Cooking Fire, dishes
table, tooltips, qualities), then R8-ALCH (table, potions, elixirs, reagent
authorizer hook-up, Cave Draught). R7-FOOD's framework carries the numbers;
Round 8 changes data tables and adds items, not the buff engine.

## 9. Proposed changes to decided rules (for the user's ruling)

| Decided rule | Where | Proposed change | Why |
|---|---|---|---|
| Food: raw / simply cooked / well cooked with 2/5/10 % per 10 s | `items_crafting.md` §3.7 (R9) | raw / dish; instant value + 5 s ticks per §2 | R7.1 |
| Elixirs of Might/Wisdom/Grace +2/+4/+6 Str/Int/Dex | §3.6 table | Vigor/Focus/Precision as pool and crit percentages (§5.3) | attributes are secondary since Round 6; R7.3 names pool/crit |
| Swiftness Draught +8 % speed, 15 s | §3.6 | +10 %, 5 s | R7.3's example; a shorter, sharper dodge tool |
| Cat's-Eye Elixir at Expert | §3.6 | Cave Draught at T3 (potion) | the underground world needs night vision from level 21 |
| Apothecary gear "+1 elixir attribute" | §3.6 | +1 percentage point on the elixir stat | follows the elixir change |
| Cooking min levels 1/10/20/30/40/50 (R7-FOOD default) | data table | 1/11/21/31/41/51 | §3.0.1 tier levels |
| Mana regen: in-combat quarter (R7.5 proposal) | R7-FOOD data | option A floor `0.25 %/s` (§2.4) | keeps Round 6 TTK bands roughly valid |
| Rock salt only on 51–60 beaches; stormkelp only in four 51–60 zones | catalog | salt crust + stormkelp hosts in 41–50 zones | T5 must be reachable at 41–50 |

## 10. Decisions for the user

1. Instant HP per tier (§2.1) and dish regeneration per tier (§2.2): yes or
   adjust.
2. Three role lines (Hearty = tank) or a fourth tank line with its own
   bonus.
3. Mana regeneration: option A (floor) or B (pure quarter).
4. The new plant list (§3.2) — per row yes/no; carrot/cassava and onion/
   pepper as mirrored pairs.
5. Cooking book unlock: first craft of a tier dish, or holding the gate
   ingredient while opening the book.
6. Greater potions: shorter cooldown (45 s) as the T3 benefit, or keep 60 s
   and give T3 nothing but a cheaper recipe.
6a. Potion strength: the decided 30 % (`items_crafting.md` §3.6, kept in
   §5.2) or the 15 % named as an example in R7.3 (then the vendor floor
   drops to 10 %).
7. The decided-rule changes of §9, row by row.
8. Which reference project supplies the plant assets: R7-REF recommends
   adding `x_farming` as a submodule and not `farming`; the orchestrator
   adds the submodule after the ruling.
