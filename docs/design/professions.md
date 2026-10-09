# Professions

Decided 2026-08-06, roster **re-cut 2026-08-07** (crafting rework),
material identities integrated 2026-08-12 and profession progression revised
2026-09-18, the smith split adopted 2026-09-20, and Alchemy made a secondary
with progression from real recipes only in Round 33 (2026-10-04), and recipe
lists with gear made only by professions in Round 45 (2026-10-08,
[ui-crafting-rework-plan.md](../planning/ui-crafting-rework-plan.md) §2.16–2.36).

**This file owns the profession rules:** roster and ids, slots, learning,
progression and its thresholds, the profession tier, the recipe areas,
station ownership, production and progress, the families each
profession serves, the vendor rule and trainers. Item rules (materials,
catalogs, enchant operations, loot) live in
[items_crafting.md](items_crafting.md): the material ladder is its §3.0, the
per-profession catalogs are §3.3–§3.6b, and what a profession *does* to an
item is §6b. Every item number (enchant values, inputs, upgrades, potions) is
in [item_tiers.md](item_tiers.md). Station and workspace behaviour (shared and
personal stations, access, digging) is
[inventory_equipment.md](inventory_equipment.md) §4.

## 1. Structure

- **Exactly 2 primary profession slots per character, freely filled at
  profession trainers**
  (never class-bound — interdependence drives the server economy).
  Switching later is allowed at a trainer, but confirmed unlearning wipes
  the dropped profession's level and current-tier craft count. The six
  primaries are Weaponsmith, Armorsmith, Tailor, Leatherworker, Woodcarver and
  Goldsmith.
- **Secondary professions have no slot limit.** Cooking and **Alchemy** are
  the two secondaries (Alchemy since Round 33). Every player may learn both in
  addition to the two primaries; a secondary cannot be unlearned. Each has its
  own crafting area (§1.2). There is no First Aid.
  - **Every character knows Cooking from the start** (Round 45, spec ruling
    28): a character who does not know it learns it at T1 at its arrival and
    at every join (an existing character at its next join); a known Cooking
    keeps its tier and crafts. No trainer teaches it
    (`grug_jobs.STARTER_PROFESSIONS`). Alchemy is still learned at its
    trainer.
  - Both have the same T1–T6 recipes and profession-level gate as every
    primary profession (§1.2; `items_crafting.md` §3.6, §3.7).
  - **Riding is likewise universal**, but is taught only by the dedicated
    Riding Trainer in each capital's outer stable, in four steps at levels
    15/30/45/60 (`mounts.md` §1). It costs no main profession slot, is not a
    framework profession and is absent from all profession trainer interfaces.
- **Learning is free** (right-click a trainer). Like every service NPC, a
  trainer serves only its own faction (`grug_factions.serves`). The internal
  profession ids are `weaponsmith`, `armorsmith`, `tailor`, `leatherworker`,
  `woodcarver`, `goldsmith`, `cooking` and `alchemist` (Alchemy;
  `grug_jobs.PROFESSIONS`), so code asks `grug_jobs.has(player, "alchemist")`.
- **Seven trainers in every capital:** the six primaries plus Alchemy. The
  Cooking trainer sockets the world data still gives every start and every
  capital (Round 45) hold **Grudge-Free Repairs** (a title, the same in
  every town, `grug_jobs.MENDER_TITLE`; the user, 2026-10-09): it teaches nothing and has no trainer dialog and
  no map or minimap icon, but its click opens the repair form with the
  trainers' prices, faction and distance rules (the user, 2026-10-09:
  start towns keep a repair point). A runtime mapping in the trainer-role
  readers decides it (`grug_jobs.trainer_teaches`, applied at placement and
  at every activation), so no world data changes.
  Capital trainers and their public stations occupy themed outer-district
  premises, reusing suitable shops; vendors remain separate NPCs. Weaponsmith
  and Armorsmith share one forge house with separate trainers and one Forge.
  The other premises are an Alchemy herb court and brewing stand, Tailor's
  cloth hall and loom, Leatherworker's drying racks and tubs, Woodcarver's timber
  and carving shop, Goldsmith's display cases and workbench, and Cooking kitchen
  with hearth and counter. Stations and trainers have safe, unobstructed access.
  Forge dressing includes an anvil, quench basin, decorative lava and visible
  weapon/armor displays. Authored display gear has no collectible inventory;
  interaction, digging, damage, explosions and indirect node transformations
  cannot release items. This guarantee is intrinsic to the display definitions,
  independent of the unfinished general protection system.
- **Gathering split**: food-grade plants (potatoes, berries, cooking
  ingredients) are gatherable by EVERYONE. The wild sources of the four
  **Alchemy herbs** — Gravemoss, Dragonweed, Crimson Lotus and Ember Moss —
  need Alchemy: learning it authorizes all four, with no per-tier herb gate,
  and for everyone else those plants are scenery. Sunleaf, Stormkelp and
  Wild Cocoa are ungated reagents, and the cultivated Ember Moss crop and its
  seeds are not gated ([farming.md](farming.md)).
- Mining, smelting and the Basic recipes (tools, blocks, planks, torches,
  dyes, bolts, leather grades, graded wood, arrows, …) are open to everyone.
  **Gear comes only from professions** (Round 45, spec §2.23): every weapon,
  armour piece, offhand and trinket is a recipe of the profession that owns
  its family (§2), at the profession tier equal to the item's tier.
- Learning any framework profession opens profession tier 1. A fixed number
  of successful crafts at the current profession tier opens the next tier:
  **10 / 15 / 20 / 25 / 30** crafts for T1→T2 through T5→T6. Lower-tier
  crafts do not count and above-tier crafts are refused. The effective
  profession tier is capped by the character band: T1 L1–10, T2 L11–20,
  T3 L21–30, T4 L31–40, T5 L41–50, T6 L51–60. Reaching a craft threshold
  while character-capped leaves the stored profession tier unchanged and
  saturates the current-tier counter at its threshold. Entering the next
  character band does not advance the profession automatically: the next
  successful craft of the previous tier opens the new tier and clears the
  counter. Further crafts while still character-capped count nothing.
- **Only real recipes count (Round 33, Round 45):** enchants and the
  profession's own end products (gear, trinkets, bags, potions
  and elixirs, dishes and raw dish assemblies). Upgrades (Round 45, spec
  §2.31: no XP farm), stations (Forge, Carving Bench, …), intermediates
  (settings, cut gems, bolt bundles) and every automatic furnace finish
  count nothing. A recipe registers as
  such with `material = true` or `progress = false`; every craft path and
  station operation awards progress through `grug_jobs.award_progress`. There
  is no fast path for late starters. Every profession still reaches its band
  cap: each primary makes and enchants gear at every tier, Cooking and
  Alchemy have counting recipes at T1–T6.
- Profession level gates crafting only. Item consumption and equipment remain
  independently gated by `_grug_ilvl` and the level requirement
  (`items_crafting.md` §6.1); neither consuming an item nor checking its use
  requirement consults profession state.

### 1.1 Profession tier and mastery band

- **Profession tier T1–T6** is the crafter's progression in one profession
  (§1). It uses the same six tiers as gear and materials (`items_crafting.md`
  §3.0: one per ten character levels, base item levels 1 / 11 / 21 / 31 /
  41 / 51). Every profession recipe and station operation needs a profession
  tier at least its own, and it counts only at the crafter's current tier. A
  gear recipe's tier is the item's tier (spec §2.34).
- **The mastery band** comes from the character's level, not from any
  profession: **Apprentice** from level 1, **Journeyman** 16, **Expert** 31,
  **Master** 46 (`grug_items.mastery_band`), always written by name, never as
  "T4". Since Round 45 (ruling 7) it gates no recipe: bags and spellbooks need
  only the profession tier equal to their tier, like all gear. Its one reader
  is the Goldsmith's gem bonus yield (10 % at Apprentice, 20 % from
  Journeyman, §2.3). Riding reuses the four names (`mounts.md`).

Three consequences:

1. **Enchant values follow the item level up to their tier**
   ([item_tiers.md](item_tiers.md) §1.1): a crafted enchant has its recipe's
   tier, a found one its item's tier; neither depends on the crafter.
2. **Profession tier gates enchant operations.** Every legal prefix and
   suffix is available at each tier T1–T6; no mastery suffix gate or temper
   step remains, and removed Imbue/Temper recipes do not survive as mastery
   unlocks.
3. **Mastery adds no enchant slots.** Basic recipes are ungated.

### 1.2 Recipe areas (Round 45)

The 3×3 crafting grid and the recipe books are gone
([ui-crafting-rework-plan.md](../planning/ui-crafting-rework-plan.md) §2.16–2.36,
§4.1). Profession level is the sole recipe-permission progression: no book
items, per-recipe unlocks, keystone redemptions or discovery.

- **One recipe registry** (`grug_jobs/registry.lua`): every craft is an
  ingredient list — items or item groups, each with a count — and one output
  stack, in one **area**: Basic, Cooking, the six primaries, Alchemy. A craft
  names its recipe; nothing matches a shape. Furnace, dual-furnace and alloy
  recipes are no recipes of the registry: they stay with their stations
  (§1.5).
- **Basic** has no profession, no station and no profession XP: tools, blocks,
  stairs, slabs, planks, torches, dyes, bolts, leather grades, graded wood,
  storage blocks, arrows and every other profession-free recipe
  (`grug_jobs/basic_recipes.lua`, converted from the engine's grid recipes
  in Round 45; stairs, slabs and walls are made per material by a loop).
- **Gear only from professions** (spec §2.23, §2.34): every weapon, armour
  piece, offhand and trinket is a recipe of its family's owner (§2) with the
  ingredients the universal grid used, the profession tier equal to the item's
  tier and the owner's station nearby; the result starts at its tier's base
  item level. Arrows are ammunition and stay Basic.
- **Visibility** (spec §2.33, corrected by the user in Round 45's playtest,
  2026-10-09): a profession area (Cooking, Alchemy and the primaries) lists
  only the recipes up to the player's profession tier there (the tier the
  character's level band allows, as the profession gate counts it); each
  new tier adds its recipes. Basic has no profession tier and lists all its
  recipes. Search, pages and "Craftable only" work on the listed recipes and
  replace the old discovery (no seen list, no starter set). Basic and
  Cooking are there from the start; the two primaries and Alchemy start
  empty and are learned at the capital trainers (spec §2.16).
- **Durations** (spec §2.30), per crafted item; a job lasts quantity ×
  duration:

  | Recipe | Seconds |
  |---|---|
  | Basic | 1 |
  | Simple dishes and raw dish assemblies (then the furnace as before) | 1 |
  | Potions and elixirs | 2 |
  | Gear (weapons, armour, offhands, trinkets) and bags | 3 |
  | Profession intermediates (bolt bundles, cut gems, settings) and station nodes | 1 |
  | Enchants (station operations) | 5 |
  | Upgrades (station operations) | 1 per level |

- **The craft gate:** a profession recipe needs the profession learned and its
  effective profession tier at least the recipe tier
  (`grug_jobs.can_craft_recipe`), and its station within 4 nodes when the job
  starts (§1.5). Basic is open to everyone.
- **Crafting jobs** (Round 45, spec §2.19–2.22, §4.4; `grug_jobs/jobs.lua`):
  every craft is a timed job of the player's own, one job per player, the
  whole quantity as one job (quantity × duration).
  - **Start:** the profession gate, the station within 4 nodes (checked only
    at the start), room in the output area (partial stacks of the same item
    and several stacks of `stack_max` counted) and the ingredients. A quantity
    above what the ingredients or the output area allow is refused with the
    maximum ("… quantity reduced to N"); none at all reads "No space in the
    output area" or "Not enough ingredients".
  - **Ingredients** are consumed at the start: the bags first, then
    `main[9..]`, the hotbar last. Only stacks without metadata count, for item
    and group entries alike; the list's ×N uses the same rule.
  - **The output area:** four take-only slots (`grug_craft_out`, every
    player) shared by all jobs; **Take all** moves it into the inventory in
    the give order, and what does not fit stays.
  - **The end:** the result appears in the output area (gear with its base
    item level, quality and tooltip), the profession XP and the achievement
    counters count the whole job, and an online player gets the feed line
    "Hearty Stew ×10 is ready". Jobs run with the window closed and while
    offline: the job ends at login or when the Crafting tab opens, and by a
    timer while the player is online.
  - **Cancel/Stop** refunds every consumed stack (and an enchant's or
    upgrade's target item) into the inventory, or is refused with "Not enough
    inventory space to cancel" when the refund does not fit. A Stop after the
    end time completes the job instead.
  - **Enchants and upgrades** (Round 45 lane EU, spec §2.24, §2.26; the
    boxes are [inventory_equipment.md](inventory_equipment.md) §1) are jobs on
    the item in the Crafting tab's **target slot** (`grug_craft_target`, one
    piece of equipment): the start takes the item in with the materials, so
    while the job runs it lives only in the job; the result appears in the
    output area; a cancel returns the item. The start judges the item as it
    is then (family, tier, channels, the cap) and needs the profession at the
    operation's tier, the station nearby and a free output slot. An enchant
    takes 5 s and counts as one craft; an upgrade of +N levels takes N s,
    costs N times one own material of the item's tier (a weapon also N
    Sticks) and gives no XP.
- **A job's XP** is min(crafts, XP left in the tier) for a counting recipe of
  the current profession tier, awarded at its end; a saturated profession
  advances at the end of its next counting job once the character band
  allows it. Unlearning a profession while its job runs lets the job finish
  without XP. The list, search and ×N of the Crafting tab, its crafting
  box, output area and progress bar: [inventory_equipment.md](inventory_equipment.md)
  §1 "The Crafting tab" (spec §2.17–2.18 and §4.2–4.5); the professions
  overview sits in its box.
- Unlearning wipes that profession's level and current-tier count. Learning
  it again starts at T1.

### 1.3 Tier ingredients (revised 2026-09-18)

- Every profession recipe of tier N declares at least one tier-N ingredient.
  Lower-tier ingredients may accompany it; a higher-tier ingredient may not
  be hidden in a lower-tier recipe. Ingredient tier is registered explicitly
  through `grug_jobs.register_ingredient_tier(item, tier)` before the recipe.
- The former keystone tables are retired historical design data. No keystone
  item is registered or consumed and no workbench redemption advances a book.
  Regional ingredients still create travel and trade demand as recipe inputs,
  not as a second unlock state.

### 1.4 Pacing check (10–20 h to level 60; revised 2026-09-18)

~10–20 min per character level keeps each ten-level profession cap open for
roughly 100–200 minutes. The five current-tier craft thresholds are
10 / 15 / 20 / 25 / 30 (§1), so a player who works two professions beside
questing has a predictable craft goal in every band without a separate
redemption item or discovery grind. A pure fighter instead buys enchanted gear
from crafters; both paths remain inside the 10–20 h envelope.
**Intended gear cadence: a visible upgrade every 45–90 min** (quest
rewards + the world drops of `items_crafting.md` §5.1 between the six material
tiers), and at 60 the professions stay load-bearing via consumables
(elixirs/potions) and named enchant application/replacement
(`items_crafting.md` §6b, §7). V1 repair is universal and money-only (§2.2);
material/profession repair remains later work
([durability_repair.md](durability_repair.md)).

### 1.5 Stations, production and progress

- **Stations by profession** (spec §2.27): Weaponsmith and Armorsmith the
  Forge, Leatherworker the Tanning Rack, Tailor the Tailor Bench, Woodcarver
  the Carving Bench, Goldsmith the Jeweller's Bench, Alchemy the Brewing Stand
  (`grug_jobs.PROFESSION_STATIONS`). Cooking needs none. A profession recipe
  needs its station within 4 nodes, checked once when its job starts. The
  forge, the four benches and the brewing stand keep no dialog and no
  inventory; a player-placed one still hands out its old contents when dug
  (round45-plan.md ruling 3).
- **Station recipes:** each station node is a T3 recipe of exactly one owning
  profession's area, with Steel Bars as its declared T3 ingredient, no station
  nearby and no progress: the Forge is the Weaponsmith's, the Tanning Rack the
  Leatherworker's, the Tailor Bench the Tailor's, the Carving Bench the
  Woodcarver's, the Jeweller's Bench the Goldsmith's and the Brewing Stand
  Alchemy's (`grug_jobs/station_nodes.lua`, `grug_alchemy/recipes.lua`). The
  Armorsmith works at the shared Forge but has no Forge recipe of its own.
- **Furnaces and dual furnaces** keep their dialog for smelting, alloys and the
  good dishes' finish. All automatic furnace and dual-furnace completion is
  universal and gives no profession progress, and neither does crafting a
  station or an intermediate (§1). The six Hearty dishes that have a raw
  assembly come only from that "Raw X" in a furnace (Round 28 ruling 27);
  simple meat, fish and grain roasting is universal and gives no progress.
- Profession progression requires exact equality of recipe tier and current
  effective profession tier.

## 2. MVP roster — six primaries and two secondaries, cut by material

Two free main professions per player, unchanged, plus the two secondaries
Cooking and Alchemy. The roster is organised **by material, never by class**.

| Profession (id) | Material chain T1–T6 | Owns exclusively |
|---|---|---|
| **Weaponsmith** (`weaponsmith`) | Bronze → Iron → Steel → Silversteel → Embersteel → Abyssal Steel | Swords, daggers and battle axes (the Scout's melee blade too): craft, enchants and upgrades; tools are Basic |
| **Armorsmith** (`armorsmith`) | Bronze → Iron → Steel → Silversteel → Embersteel → Abyssal Steel | Metal armor and shields: craft, enchants and upgrades |
| **Leatherworker** (`leatherworker`) | light → cured → heavy → scaled → sleek → nightscale leather | Leather armor and bows: craft, enchants and upgrades; leather bags |
| **Tailor** (`tailor`) | patch → woven → heavy → silkweave → silk → stormweave bolts | Cloth armor and spellbooks: craft, enchants and upgrades; cloth bags |
| **Woodcarver** (`woodcarver`) | any `group:wood`, graded Seasoned → Polished → Hardened → Inlaid → Lacquered → Heartwood (enchant materials) | Staves and wands (sticks + metal + occult mob components): craft, enchants and upgrades |
| **Goldsmith** (`goldsmith`) | Settings from tin, iron, steel + copper, gold, embersteel + gold and abyssal steel + gold bars; the six depth-tiered gems (one per tier rock, Citrine T1 … Diamond T6) | Trinkets for both trinket slots (craft, enchants and upgrades), gem refinement, Settings |
| **Alchemy** (`alchemist`, secondary) | the four Alchemy herbs plus ungated reagents and mob loot | Potions and elixirs, brewed at the Brewing Stand — **gathers its own herbs** |
| **Cooking** (`cooking`, secondary) | farmed and gathered food plants, meat and fish | Dishes and raw dish assemblies (`items_crafting.md` §3.7) |

Two professions dress every class in armour, weapon and offhand (Round 33,
[item_tiers.md](item_tiers.md) §3.3): Warrior Armorsmith + Weaponsmith, Scout
Leatherworker + Weaponsmith, Mage and Priest Tailor + Woodcarver; the
Goldsmith serves every class. An **upgrade** (one per profession and tier)
adds +N item levels to an item of its families, up to 10 × the item's tier,
for one own material per level (a weapon also a Stick), without XP
(item_tiers.md §3.1, Round 45).

### 2.1 The coverage is complete and overlap-free

That is the property the re-cut was made for, and it is checkable:

- **Three armor classes, three professions.** Metal → Armorsmith,
  leather → Leatherworker, cloth → Tailor. No class of armor has two
  makers and none has none.
- **Every weapon family has one maker.** Swords, daggers and battle axes
  belong to the Weaponsmith; wands and staves to the Woodcarver; bows to the
  Leatherworker (Round 33): recipe, enchants and upgrades (Round 45: the
  recipe too). Scepters and orbs are absent from V1.
- **Both trinket slots finally have an owner** — the Goldsmith. In the
  old roster they had none at all. **The items ship in the MVP**
  (decided 2026-08-08): the slots are no longer reserved
  (`inventory_equipment.md` §2). Each trinket has one selectable primary-
  attribute prefix channel, one selectable HP/Mana/Crit suffix channel and one
  authored special. Crafted bases start with empty channels; an enchant's
  value follows the item level up to its tier's top
  ([item_tiers.md](item_tiers.md) §1.1).
- **Offhands have distinct roles**: the Armorsmith makes and improves
  shields; the Tailor makes and improves spellbooks (Round 33, before the
  Goldsmith). The Scout's offhand is its melee
  blade, and its quiver is a slot, not an item (Round 28).
- **Potions and elixirs** are Alchemy's alone, dishes Cooking's (vendors
  still sell the Weak Healing Potion, `items_crafting.md` §3.7). Tailor owns cloth
  bags and Leatherworker owns equal-capacity leather bags.

### 2.2 Why material-cut and not class-cut

A class-cut roster ("Warrior smith", "Mage outfitter") looks tidy with
three classes and **breaks the moment Phase 2 adds four more** — every
new class needs either a new profession or an awkward second home in an
old one, and the roster grows with the class list forever.

A material cut does not move when the class list does: a later class that
wears leather finds a maker already there, and one that wants cloth and a
wand finds both makers already there.

It is also the only cut that keeps **§4's social supply chain** alive. A
profession that serves exactly one class serves exactly one customer per
group; a material profession serves several classes at once, which is
what makes a crafter worth finding on a server with a handful of players
online. Trade stays voluntary: since Round 28 no profession needs another
profession's product (§3 below).

V1 repair is the explicit exception to profession ownership: every profession
trainer repairs every repairable item of a player of its faction for money
only. Player-placed stations inside an active Claim Stone claim offer the same
service ([durability_repair.md](durability_repair.md)). Material-matched
repair is backlog work, not a hidden benefit of learning the item's owning
profession.

### 2.3 Two professions were merged away

- **Herbalism merges into Alchemy.** Alchemy gathers its own herbs: learning
  it authorizes all four Alchemy herbs (§1, gathering split); there is no
  separate herb recipe group or per-tier herb gate (`items_crafting.md` §3.6).
- **Gem Hunter merges into the Goldsmith.** Its useful gathering identity
  survives as bonus yield from a successfully harvested natural gem node (`items_crafting.md` §3.6b): **10% base chance at Apprentice, 20%
  from Journeyman onward**, rolled once after a valid harvest and granting one
  additional raw gem item of the harvested species (Quartz is a mineral, not
  a gem, and gets no roll). The old Gem Detector was
  tied to deleted private-island treasure clusters and is retired rather than
  given a continental radar role.

Both disappear as separate professions. They were the two asymmetric
stubs in the old roster, and burning one of a player's two main slots on a
pure gathering skill was never a real choice. **Every profession is now
symmetric: six profession tiers each, six material groups each.**

### 2.4 The Woodcarver closes a real hole

The active caster roster is two-handed staff or one-handed wand plus a
Tailor spellbook. The Woodcarver makes staves and wands and owns their
enchantments and upgrades. Scepters and orbs are absent from fresh V1 worlds.

## 3. Self-contained professions (Round 28)

**No profession needs another profession's product** (Round 28 ruling 28,
user decision 2026-10-01). *Why:* forcing players to have items made by
another profession turned out to be much worse in practice than expected.
Variety comes from loot tables per tier band instead: every enchant consumes
the profession's **own material** of the tier (metal bar, leather grade,
cloth bolt, graded wood or setting), **one loot item of the tier** chosen by
the stat and channel, and **one mining or gathering item** chosen by the equipment
family (`items_crafting.md` §6b.2); the Goldsmith may refine base gems
further for its own recipes only. The load check fails when any profession
recipe or enchant operation uses an item made by another profession's
recipe. The Weaponsmith metal fittings that the Woodcarver used to buy are
removed, and so are the universal reagents, the Leatherworker's ×5 leather
drop and its Weapon Grips (Round 33).

Materials everyone can make as Basic recipes (leather grades, cloth bolts,
graded wood) are not profession products.

## 4. Vendor supply rule

**Vendors sell supplies, consumables, tools, the Common gear floor and a
few T1 basics. They never sell an enchant input — a signature loot item or
family input of `grug_professions/data/enchants.json` — and never a crafting
ingredient above T1** (user ruling 1 of 2026-10-02,
[economy plan](../planning/economy-vendor-plan.md) §2). A T1 own material
may be sold (the smith and the armourer sell the Bronze Bar, the tanner Light
Leather). Every ingredient from T2 up and every enchant input comes from
loot, mining or gathering: the hunt is the game. T1 basics stay buyable
because T1 is the tutorial band. A load audit in `grug_traders` drops and
reports any shelf entry that breaks the rule; it judges a food by its own raw
tier (`items_crafting.md` §3.7, so the baker's T1 melon passes) and anything
else by the higher of its own tier and its profession ingredient tier.
Flavour shelves (the mason's blocks, candles, food to eat) stay. (Also
anchored in economy.md §2.)

The gear floor (revised 2026-08-07 twice over):

- Since Round 33 vendors sell the **T1 catalog only**, at every level
  (`items_crafting.md` §3.8); from T2 the bases come from profession crafting
  (Round 45) or drops. The six bracket catalogs (one per material tier, 1-based: bracket 1
  is levels 1–10) stay the craft ladder and the reference prices.
- Vendors sell plain base equipment, never professionally enchanted gear.
  Base and enchanted items have the same material lifetime; enchantments add
  the explicitly chosen stats, with no hidden refinement bonus.

Enchant and upgrade operations and their inputs are `items_crafting.md` §6b
and [item_tiers.md](item_tiers.md) §2–§3; production and progress are §1.5.

## 5. Phase 2+

The former Blacksmith is split in the current roster. Weaponsmith and Armorsmith
use one shared physical Forge but have separate trainers, recipe areas,
progression and recipe ownership (the Forge's own recipe is the Weaponsmith's, §1.5). The six
primaries still compete for two slots; a metal user
who wants both specialties spends both slots, matching the two-profession cost
of cloth or leather users who also want a professionally improved weapon.

- **The Bowyer split is dropped entirely** (2026-08-07). The Leatherworker
  makes bows and owns their named enchant operations (Round 33; the
  Woodcarver before), so there is nothing left for a Bowyer to own. The
  Leatherworker is not split.
  *A settlement shop called a bowyer is not this.* Since 2026-09-15 a
  settlement may hold one of twelve **profession shop vendors** — butcher,
  smith, fishmonger, baker, tailor, mason, brewer, bowyer, herbalist,
  armourer, tanner, embalmer (`settlements.md`, "Settlement NPCs and guard
  targeting"). Those are shopkeepers with a shelf of their trade; nothing is
  taught, levelled or unlocked at one, and the six crafting professions of §2
  are unaffected by which shops a city has.
- **Enchanter as a separate profession is dropped too**: enchanting is
  what equipment professions do to their own item families
  (`items_crafting.md` §6b), not another profession that would take a
  cut of all of them.
- **The bow foundation now has the Scout consumer.** Six tier bows beginning at Bronze are active V1 equipment. The Leatherworker improves bows (Round 33).

## Round 18 trainer feedback

A successful Learn action displays explicit success and points to the profession
recipe book in Crafting. Subsequent visits show known state/progress and guidance.
Cooking and Alchemy have no Unlearn action. Primary professions require confirmation that
all progression in the selected profession will be lost; cancellation preserves
it. Failed learning never displays success. Repair access is unchanged.
