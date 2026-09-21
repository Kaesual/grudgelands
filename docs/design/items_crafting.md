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
non-circular pick/depth spine; natural-depth permission and resource harvest
tier are separate checks. Emberglass and Abyssal Steel replace the old
Emberstone/Mese and Grudgesteel targets. Six regional G1/G2 gems, cultural
finishes, a separate PvP-special channel, the final Goldsmith/trinket model and
the rebased 25c→25s Common-price axis are authoritative below. Private housing
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
- **The harder the enemy, the better the loot** — boss/elite multipliers
  act on the enchant roll ranges, same mechanic everywhere.
- **Rare patrol mobs** with special loot as raid incentive into enemy
  territory; each of the six race **Kings** is a heavily guarded raid boss
  with top-tier rolls.
- **Class/profession synergy intended** (Warrior+Weaponsmith or Armorsmith,
  Priest/Mage+Tailor, …).
- Regional materials and contested routes make high-tier equipment and
  optional target-race counters trade goods; universal picks never require a
  regional gem, cultural material or trophy.
- Cultural finishing is crafter-culture-bound but finished items remain
  tradeable and wearable by anyone; target-race PvP specials are a separate
  channel (§4).
- Material tiers mirror WoW: vendor supplies (thread/flux/vials) as
  small gold sink; world materials tiered by source level; profession
  stations uncraftable, capitals/villages only; bags are Tailor products.
- Vendor floor rule: vendors sell only the LOWEST tier per category
  (professions.md §4, economy.md §1).
- **One item per concept** (decided 2026-08-07, binding): no two items
  may fill the same role. The vendor bracket catalog *is* the base craft
  ladder, and both are material-named (§3.0.3).
- **Everyone crafts the base items of every material tier**; professions
  enchant them and hold a few exclusive recipes per mastery
  tier (§3.3–§3.6b, §6b).

## 1. Reference research (2026-08-06)

### 1.1 Lord of the Test: the crafting-book chain (studied in source)

LotT (`reference_projects/Lord-of-the-Test`, code **LGPL 2.1** — GPL-3.0
compatible; `lottinventory` mixes WTFPL (Zeg9 zcg) + LGPL 2.1
(fishyWET)) implements exactly the chained book ladder:

- Books are **tools (stack_max 1) whose `on_use` opens a recipe-guide
  formspec** filtered by item groups (`lottinventory/guides.lua:7-61`,
  `functions.lua:27-160`): the craft book excludes `cook_crafts`/
  `armor_*`/`forbidden` outputs, the cooking book shows only cooking,
  the protection book shows armor, the forbidden book shows `forbidden`
  items, the master book shows everything.
- **The chain — each better book consumes a lower book as ingredient**
  (`lottinventory/init.lua:67-124`, itemstrings exact):
  - `lottinventory:craft_book` = 8× stick around `default:book`
  - `lottinventory:cooking_book` = 8× coal around `default:book`
  - `lottinventory:protection_book` = 8× steel ingot around **craft_book**
  - `lottinventory:brewing_book` = `lottpotion:brewer` + **cooking_book**
  - `lottinventory:potions_book` = `lottpotion:potion_brewer` + **cooking_book**
  - `lottinventory:forbidden_book` = 8× gold ingot around **protection_book**
  - `lottinventory:master_book` = **all six lower books** + 1×
    `lottores:mithril_ingot` + 2× `lottores:tilkal_ingot` in one 3×3.
- The elegant trick: the books **carry item groups themselves** (`book`,
  `armor_use`, `forbidden` — `guides.lua:29-34`), so each tier's book
  recipe is itself only *discoverable* inside the previous tier's book —
  one group-filter mechanism does both jobs (browse + ladder).
- Every race starts with `craft_book` (`lottclasses/init.lua:61-107`);
  the wizard admin class starts with `master_book`; traders sell the
  brewing book for 32–35 gold ingots (`lottmobs/trader_goods.lua:145`).
- **What LotT does NOT do**: the books never gate the engine craft —
  a player who knows a 3×3 shape can craft without the book. The book
  is pure recipe *discovery*. Our decided model (craft_predict veto +
  player-meta unlock) closes that hole. *Revised 2026-08-07*: we keep
  the group-filtered guide viewer and the hard gate, but **drop the
  chain** — one book per profession, groups instead of tiers (§2.2).

**The two-slot ("dual") furnace — ported** (verified in source
2026-08-07). `lottblocks:dual_furnace_active` /
`lottblocks:dual_furnace_inactive`, registered in
`lottblocks/crafting.lua:201`. It is a genuine **alloy** furnace, not a
parallel smelter: `on_construct` sets `input` to 2 slots, `output` to 2
and `fuel` to 1 (`crafting.lua:230-236`), and `check_craft`
(`crafting.lua:54-71`) matches a `type = "dualfurn"` recipe's two
ingredients against the two input slots **in either order**, consumes one
of each and emits one output. Recipes are registered through
`lottblocks.crafting.add_craft` (`crafting.lua:30-33`); LotT uses it for
its ring metallurgy (`lottother/rings/ringcraft.lua:52ff`). This is the
node our §3.0.2 alloys run on.

- **Licence**: LotT ships `LICENSE.txt` = **LGPL 2.1** for code, and
  `mods/lottblocks/license.txt` names every code author of that mod under
  LGPL 2.1 — so the §1.1 header note covers the dual furnace with no
  extra clearance. LGPL 2.1 → GPL-3.0-or-later is compatible (AGENTS.md
  "Licenses"). The **media** in `lottblocks` is CC BY-SA 3.0 (Amaz et
  al.), which is why the port takes the *code* and ships our own front
  textures — no CC BY-SA attribution debt for a node we re-skin anyway.
- **Target port:** retain LotT's two material inputs plus its separate fuel
  slot. The historical three-material T6 alloy and the corresponding third
  material port were retired on 2026-08-12; every universal alloy in §3.0.2
  fits the ordinary two-input matcher.

Race-specific items: races are **privileges** (`GAMEelf`, `GAMEorc`, …,
`lottclasses/init.lua:1-17`) driving skins/allies/immunity — but **LotT
race-gates no gear at all**: `lottweapons:elven_sword` (fpi 0.25,
fleshy 7.5 — `lottweapons/special.lua:1-12`) is craftable by everyone
(`crafting.lua:76-83`, steel/bronze/mese) and mostly enters play via
elf-land mapgen chests (`lottmapgen/chests.lua:275,338`);
`lottweapons:orc_sword` is gated only softly via the orc-world material
`lottores:orc_steel_ingot`. Real race checks exist only on doors
(race whitelists), chests (priv check + lockpick bypass), palantír
teleport ACLs, same-race trader discounts (`lottmobs/trader_goods.lua`)
and orc food (screen penalty for non-orcs); gear "race identity" is
starting kits + naming/textures, tiers are purely material-based
(wood→…→galvorn→mithril). Lesson: LotT race gating is soft flavor.
Ours (§4) is a deliberate tightening — hard on the *finish author* (culture
and profession checked by the workstation transaction) and free on the
wearer. Culture is per-stack metadata on a universal base item, not a parallel
registered catalog.

### 1.2 VoxeLibre: harvestable item-family templates (verified per mod)

`reference_projects/VoxeLibre`; LEGAL.md: code GPLv3+ unless a mod
declares a more permissive license (dual-license, our choice); media
CC BY-SA 4.0 (few CC0/CC BY 3.0 sounds). All code licenses below are
compatible with our GPL-3.0-or-later; media needs per-file attribution
in `LICENSE-media.md` (AGENTS.md rule).

| Family | Source mod | Code license | Adaptation effort |
|---|---|---|---|
| Bows & arrows | `mods/ITEMS/mcl_bows` (+`vl_projectile`) | **LGPL 3.0** (projectile GPLv3+) | ~1000 lines to port, ~6 dep shims — LOW-MEDIUM (§9) |
| Potions/brewing | `mods/ITEMS/mcl_potions` (`mcl_brewing`) | **MIT** (brewing GPLv3+) | effect engine liftable as-is — LOW |
| Armor | `mods/ITEMS/mcl_armor` | GPLv3+ | equip/update + texture-layer pattern (slots already ours, WP15) + the **trim/colour system** for special variants (§6b.7) — LOW |
| Tools/weapons | `mods/ITEMS/mcl_tools`, `vl_weaponry` | GPLv3+ | numbers reference only |
| Enchanting | `mods/ITEMS/mcl_enchanting` + `mods/HELP/tt` (MIT) | GPLv3+ | meta-storage + description pipeline is our WP5 template — MEDIUM |

Key implementation patterns we adopt:

- **Enchant storage** (`mcl_enchanting/engine.lua:9-48`): ONE serialized
  table under one meta key; `set_enchantments` → `load_enchantments`
  re-runs every effect hook idempotently (reset tool_capabilities,
  reapply, regenerate description via the `tt` snippet pipeline →
  `meta description`). We mirror this: `grug_ench` meta key, §6.
- **Roll logic** (`engine.lua:308-469`): weight-biased pick, power
  ranges per level, halving loop with `(level+1)/50` continuation —
  more machinery than we need; our flat count-per-quality + roll-window
  model (§6) replaces it (and is written from scratch, not copied).
- **Potion effects** (`mcl_potions/functions.lua`, MIT): registry with
  `on_start/on_step/on_end`, physics factors via factor-stacking,
  HP-tick timers, damage modifiers; persisted in player meta. The shipped
  timed-effect minimum is the runtime-only `grug_core.status` registry and
  text list; specialized elixir hooks remain item-owned work.
- **Armor damage formula** (`mcl_armor/damage.lua:84-87`): group-driven
  points; we use plain percent reduction instead (§3.1) — simpler and
  matches combat_stats caps.
- **Bow charging** (`mcl_bows/bow.lua`): hold-timestamps + meta-swapped
  inventory image; damage 9 base / 10+ crit at full 0.5 s charge (§9).
- **Armor recipes** (added 2026-08-07): `default` registers **no armor at
  all** — the vendored `mods/BASE/default/tools.lua` ladder is picks,
  shovels, axes and swords only. The four armor shapes therefore have to
  be authored by us. Two clean sources: `mcl_armor/api.lua:171-176`
  (a `craft_material` field per element, one generic
  `register_craft` per piece) and **Lord of the Test**
  `lottarmor/init.lua:284-345`, which loops one ingot variable over
  helmet / chestplate / leggings / boots. **LotT is the closer fit** — a
  flat `craft_ingreds` map from tier name to ingot is exactly our
  six-tier ladder, and it is LGPL 2.1 + BSD-3-Clause (`lottarmor/
  license.txt`), i.e. compatible. We take the **shapes** and keep our own
  bar costs (§3.3): LotT's are 5/8/7/4 for head/chest/legs/feet, ours are
  3/5/4/2.
- **Armor trims** (`mcl_armor/trims.lua`): a template craftitem plus a
  colour overlay baked onto the armor texture. That is the visual
  treatment for our special variants (§6b.7).

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

1. **The "item levels" column above is the enchant roll band, and the
   band follows the ITEM** (sharpened 2026-08-08). The four bands
   1–15 / 16–30 / 31–45 / 46–60 in that column are *precisely* the four
   columns of §6.3's roll table, and what picks a band is the **item's
   ilvl** — never the crafter's mastery tier and never the crafter's
   character level. There is no third set of boundaries anywhere in this
   document. That the four band boundaries fall on the same numbers as
   the four mastery level anchors is a property of the numbers, not a
   rule: nothing stops a level-50 Master from smithing a T1 Bronze Sword
   (ilvl 3), and that sword rolls in the first band. §6.3 spells out the
   two consequences.
2. **Profession tier gates enchant operations.** Every legal prefix and suffix
   is available in each T1–T6 tier; no mastery suffix gate or temper step remains.
3. **Mastery retains specialist recipes**, such as bag capacities and spellbooks;
   it does not add enchant slots. Recipe profession tier and explicitly declared
   specialist prerequisites govern crafting. Universal Basics routes are ungated.

| Profession | Retained specialist products |
|---|---|
| Weaponsmith | Metal fittings; physical-weapon enchantments |
| Armorsmith | Metal-armor and shield enchantments |
| Leatherworker | Weapon grips; 8/16/24/32-slot leather bags; quiver; leather enchants |
| Tailor | 8/16/24/32-slot cloth bags; cloth enchants |
| Woodcarver | Staff, wand and bow enchantments |
| Goldsmith | Rough→Cut gems; Settings; trinkets; spellbooks; ornaments; named enchants |
| Alchemist | Profession-gated mixtures for universal Brewing Stand finishing |

Fixed enchant tier bonuses/costs follow §6b and
[the current contract](crafting_equipment_revision.md#enchanting). Removed
Imbue/Temper recipes do not survive as mastery unlocks.

### 2.2 Recipe books are UI (revised 2026-09-18)

- Learning a profession at a trainer exposes its book. A book is not an item,
  is never bought, traded, carried, lost or consumed, and stores no state.
- Every learned book shows its complete catalog from T1 through T6. Recipes
  above the effective profession level remain visible but greyed, with the
  required profession tier and corresponding character-band floor.
- The crafting page carries two primary book slots, one slot for every
  framework secondary (Cooking today), and the always-open **Basics** book.
  Empty learnable slots say **learn at a trainer**. First Aid and Riding do not
  acquire book slots.
- The Basics book derives its entries from existing non-profession engine and
  dual-furnace recipes. Those recipes remain registered by their owning mods
  and are not re-registered by the profession framework.
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
- A profession recipe is craftable only when the player has learned the
  profession and its profession level is at least the recipe tier. Universal
  base recipes (§3.0.3) remain craftable by everyone.
- Unlearning removes the book immediately and wipes that profession's level
  and current-tier count. Learning it again starts at T1.

### 2.3 Profession level and tier ingredients (revised 2026-09-18)

- Every profession starts at T1. Successful crafts of the **current** tier
  advance the fixed counter in `professions.md` §1; lower-tier crafts count
  nothing and above-tier crafts are refused.
- Character level caps the effective profession tier to the material bands of
  §3.0.1. Profession and item-use gates are independent: `_grug_ilvl` remains
  the only consumption/equipment check.
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
redemption item or discovery grind. A pure fighter instead buys enchanted and
enchanted gear from crafters; both paths remain inside the 10–20 h envelope.
**Intended gear cadence: a visible upgrade every 45–90 min** (quest
rewards + 3% world drops between the six material tiers, §3.0),
and at 60 the professions stay load-bearing via consumables
(elixirs/bandages/potions), upgrade kits (§7), masterworks and race
signatures (§4). V1 repair is universal and gold-only at every profession
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

All six race regions use the same mandatory metal, pickaxe and natural-depth
progression. A faction or race never controls a material needed for the next
universal pick.

| Tier | Levels | ilvl | Metal | Processing | Maximum natural depth | Next-pick material available no deeper than |
|---|---:|---:|---|---|---:|---:|
| T1 | 1–10 | 3 | **Bronze** | Copper + Tin, dual furnace | y = **−100** | Iron: y ≥ −100 |
| T2 | 11–20 | 10 | **Iron** | Iron ore, normal furnace | y = **−300** | mined Coal/Steel inputs: y ≥ −300 |
| T3 | 21–30 | 20 | **Steel** | Iron Bar + mined Coal, dual furnace | y = **−500** | Silver: y ≥ −500 |
| T4 | 31–40 | 30 | **Silversteel** | Steel + Silver, dual furnace | y = **−700** | Emberglass: y ≥ −700 |
| T5 | 41–50 | 40 | **Embersteel** | Silversteel + Emberglass, dual furnace | y = **−1000** | Abyssal Crystal: y ≥ −1000 |
| T6 | 51–60 | 50 | **Abyssal Steel** | Embersteel + Abyssal Crystal, dual furnace | map floor (**−31000**) | no T7 prerequisite |

- Wood and Stone starter picks are not extra material tiers. They share T1's
  y = −100 limit; Bronze is the best T1 pick. Wood and Stone gear stays below
  the generated ilvl anchors and carries no level requirement.
- Gold is a universal luxury, jewelry and building material, never a tool
  metal. There is no Gold weapon, armor or pick. Physical Gold and ledger money
  are separate systems (`economy.md` §1).
- Diamond is a regional G2 gem, never a tool material. The Mese and Diamond
  tool tiers remain retired.
- **Emberglass** is a real `grug_materials` item/node family. Fresh-server
  development uses its canonical names directly, with no old Mese or
  Emberstone migration aliases or parallel player-facing materials.
- **Abyssal Steel** is the ordinary craftable T6 metal. **Grudgeforged** is an
  optional final masterwork state applied to a qualifying equipment stack by
  consuming a named-rare trophy or Fallen Crown. No trophy enters an Abyssal
  Steel bar or pick.
- Mundane Stone, Copper, Tin, Iron ore, Coal and Gold may retain stable
  upstream itemstrings. Reinterpreted fantastic materials, processed outputs
  and all regional gems use the Grudgelands namespace. `grug_materials` owns
  the taxonomy even where a mundane itemstring remains upstream.

Natural resources have a separate minimum **harvest tier**. This tier controls
whether a destroyed node yields its resource; it does not grant permission to
mine at the node's y.

| Minimum pick tier | Natural resources |
|---|---|
| T1 — any pick, incl. the Wood/Stone starters | Copper, Tin, mined Coal, Quartz |
| T1 — **metal pick required** (Bronze or better) | Iron |
| T2 | Gold; Citrine, Garnet and Jade (G1) |
| T3 | Silver |
| T4 | Emberglass; Diamond, Sapphire and Ruby (G2) |
| T5 | Abyssal Crystal |
| T6 | no universal progression resource; the tier grants deep access and better density |

**Iron requires a metal pick** (decided 2026-08-13): the Wood and Stone
starter picks harvest Copper, Tin, Coal and Quartz but **shatter** iron
ore (the ordinary §3.0.4 under-tier path — ×4 time, node destroyed, no
drop, feedback naming the required Bronze pick). The ladder is therefore
strictly sequential — starter pick → Copper + Tin → dual furnace →
Bronze pick → Iron — and non-circular, since Bronze consumes only
any-pick resources. Mechanism: Bronze+ picks additionally carry
`grug_metal_pick = 1` and the iron resource row is flagged
`metal_only`, evaluated inside `grug_materials`' central
`mining_decision` (a group value of 0 cannot encode a starter tier —
group 0 means "group absent" — which is why this is a flag, not a
renumbering of the shipped 1..6 taxonomy). Runtime lands with WP29.

Quartz is the universal T1 jewelry mineral. Regional gems use **Rough
<Gem> → Cut <Gem>**; `G1` and `G2` are internal grade labels, not
player-facing substitutes for species names. Emberglass and Abyssal Crystal
are universal fantastic progression resources and are never called regional
gems.

Each surface/depth column has exactly one cultural race region. It chooses the
eligible regional gem species and cultural source independently of political
territory or PvP state:

| Faction | Race region | G1 | G2 | Cultural material | Signature wood |
|---|---|---|---|---|---|
| Accord | Human | Citrine | Diamond | Sunwax | Oak |
| Accord | Dwarf | Garnet | Sapphire | Runeslate | Mountain Pine |
| Accord | Elf | Jade | Sapphire | Moonresin | Silverwood |
| Throng | Orc | Garnet | Diamond | Red Ochre | Spikethorn Acacia |
| Throng | Troll | Jade | Ruby | Spirit Resin | Kapok |
| Throng | Undead | Citrine | Ruby | Gravesalt | Gravewood |

Thus both factions have all three G1 species and Diamond; Ruby is Accord's
foreign G2 and Sapphire is Throng's. The authored supply routes are native
faction regions, enemy contested level-31+ regions, cross-border deep T5/T6
columns, both all-six-gem dragon-island camps and trade. A practical T4
contested route to the missing G2 must exist before the level-60 islands.

**Density shape and calibration targets:**

- G1 starts sparse in the upper progression, rises through T4, retains exactly
  its T4 ordinary density in T5 and ordinary T6, and rises again only through
  the shared deep-T6 multiplier.
- G2 is sparse in T4 (about one ore per 12,000 eligible host nodes per species),
  doubles in T5 (one per 6,000) and reaches four times the T4 rate in ordinary
  T6 y = −1001…−1499 (one per 3,000). All three require a T4 pick.
- Continental Abyssal Crystal exists for both factions throughout T5 and T6.
  The first calibration starts near **one crystal per 2,048 eligible host
  nodes**; the y = −701…−1000 entry band alone must yield enough for an
  Abyssal Steel pick without T6 access.
- At y = −1500…−1999, ordinary continental ores, G1, G2 and Abyssal
  Crystal receive **+25%** bounded placement budget; at y ≤ −2000 they
  receive **+50%**, capped. Trophies, king loot, dragon sockets, claims and
  unique quest sources never receive this multiplier. It is mapgen placement,
  not runtime ore respawn.
- Map generation measures actual exposed yield and route time before freezing
  ore-registration literals. The acceptance audit compares both factions'
  native volume, T4/T5/T6 foreign routes, dragon refill/yield including the
  Goldsmith bonus, a full gear set's demand, two-handed equivalence and vendor/
  drop substitution pressure.

Crafted material blocks are storage/building nodes, never natural resources.
**The pack/unpack recipes shipped 2026-09-16** (WP26): all twelve processed
rows, 9 ↔ 1, both directions, derived from `grug_materials.PROCESSED_MATERIALS`
so the Gold Block and the two resource-form blocks are covered by construction.
Rough gems and cut-gem blocks remain WP10's and still have no recipe.
They have no harvest tier, any real pick recovers them wherever territory
permission allows, and they always drop themselves. Mapgen never places a
craftable nine-unit storage block. Citrine, Garnet, Jade, Diamond, Sapphire and
Ruby each pack from **9 Cut Gems** into one matching non-luminous luxury block
and unpack to the same 9 Cut Gems; Rough Gems cannot be packed. Emberglass,
Embersteel, Abyssal Crystal, Abyssal Steel, Gold and mundane metal blocks obey
the same non-gated building-node rule.

The Gold Block specifically packs from 9 Gold Ingots and unpacks to the same
9 ingots. It is a storage/status/decor node, not ledger currency or a housing
purchase token; no claim upgrade or universal progression step requires it.

#### 3.0.2 Alloys and the two-slot furnace

**Shipped 2026-09-16** (WP26, `mods/ITEMS/grug_smelting`): both smelting
nodes, the five single-input smelts, the five alloys below, the storage
pack/unpack pairs of §3.0.1 and the station's own craft recipe are registered
and audited at every server start. Cook durations are WP26 runtime calibration
and are deliberately not frozen here; see
[`wp26-implementation.md`](../research/wp26-implementation.md).

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
regional gem, cultural material or trophy.

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

  Nouns are Sword / Dagger / Greataxe / Staff, Helm / Chestplate / Greaves /
  Sabatons (metal), Cowl / Robe / Leggings / Slippers (cloth) and Hood /
  Jerkin / Pants / Boots (leather) — so the catalogue reads *Abyssal Steel
  Greataxe*, *Silkweave Cowl*, *Iron Helm*. Itemstrings follow the same
  ladder (`grug_gear:sword_bronze`, `grug_gear:head_cloth_silkweave`); the
  full list is pinned by `tools/wp13/gear_catalogue_kat.lua`.
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
  two vertical handles; wand = one processed wood over one handle; staff =
  three processed wood in a column. No
  base recipe adds a gem or professional fitting beyond those stated shapes.
  **This supersedes §3.3's** "vendor floor sells up to the bronze pick —
  iron+ picks are smith products" (see the marked line there).
- **`default`'s tool ladder is replaced** by the six-tier ladder: wood
  and stone stay, bronze/iron/steel/silversteel/embersteel/abyssal steel
  replace the rest, and the **mese and diamond tool tiers are deleted**
  (that is `pick`/`shovel`/`axe`/`sword` × mese, diamond in
  `mods/BASE/default/tools.lua` — twelve registrations to drop, plus
  their craft recipes).
  **State 2026-09-15**, after WP13's round-2 merge. **Swords** are complete and
  live entirely in `grug_gear`: `default:sword_wood` and `default:sword_stone`
  remain as the below-ladder starters and `default:sword_bronze`/`_steel` are
  unregistered by the curation list, next to the mese and diamond tiers.
  **Pick, axe and shovel** are complete at all six tiers: `default`'s Bronze is
  T1 and its Steel is T3 (the mapping `grug_materials/overrides.lua` already
  encoded through `grug_pick_tier`), and Iron, Silversteel, Embersteel and
  Abyssal Steel are registered by `grug_materials/tools.lua`. Iron gets tools
  because Iron is a full tier here — it owns a depth band, a pick tier and a
  real bar item — so skipping it would leave §3.0.4's T2 row without a pick.
  All six pick, axe and shovel tiers use the familiar Minecraft grid shapes and
  are universal Basics recipes. Their existing capability profiles remain the
  authority for dig times. Lifetime follows the current equipment revision.
  Woodcutting Axes are damage-free tools; two-handed Battle Axes are weapons.
  Wood and Stone exist only as tools. Fresh Warrior characters start with a
  Bronze Sword, Mage/Priest with a Bronze Staff, Scout with a Bronze Bow,
  backup Bronze Sword and 200 arrows. Ordinary T1 weapons are usable at level 1.
- **All armor base recipes use the canonical shapes:** head 5, chest 8,
  legs 7 and feet 4 units, in the same grid positions for metal, cloth and
  leather. All three lines and all six material tiers are registered and
  universal.
- A profession never gets a *parallel* item. What a profession adds on
  top of the base item is the **enchantment and the special
  variant** (§6b), plus its handful of exclusive recipes.

#### 3.0.4 Natural depth, harvest tier and cosmetic strata

Mining evaluates three independent questions in this order:

1. **Territory/protection:** may the player modify this position?
2. **Natural depth:** does the wielded pick reach the target node's y?
3. **Resource harvest:** if the target is a natural ore/gem, does the pick meet
   its minimum harvest tier?

Permission never implies tool access. Tool capability never expresses
political ownership, and failure to earn an ore drop never grants access below
the pick's maximum depth.

| Pick tier | Canonical pick | Maximum natural depth | Natural band opened |
|---|---|---:|---|
| T1 | Bronze (Wood/Stone share its limit) | y = −100 | surface/T1 Stone |
| T2 | Iron | y = −300 | Slate |
| T3 | Steel | y = −500 | Basalt |
| T4 | Silversteel | y = −700 | Granite |
| T5 | Embersteel | y = −1000 | Emberrock |
| T6 | Abyssal Steel | y = −31000 | Abyssal Rock and all deeper T6 |

The boundaries are inclusive at the bottom shown. Therefore y = −700 is the
last protected shallow/T4 node, y = −701 is the first contested deep node,
T5 is y = −701…−1000 and T6 is y = −1001…−31000. There is no T7.

The natural-depth gate covers generated excavation material: natural strata,
ore/gem nodes and any other generated ground node that could bypass a stone
layer. Target y is authoritative even in an exposed cavern, cliff or another
player's tunnel. If the pick is too shallow, digging is refused before node
damage, tool wear or any resource/profession roll, and shared feedback names
the required pick tier or maximum depth. Natural classification uses item
groups/API data; mapgen does not write metadata to every node.

The six strata remain visual depth language:

| Tier | Band (inclusive) | Node | Description | Texture |
|---|---|---|---|---|
| T1 | y ≥ −100 | `default:stone` | Stone | unchanged |
| T2 | −101…−300 | `grug_materials:slate` | Slate | `default_stone.png^[colorize:#4a5a6e:70` |
| T3 | −301…−500 | `grug_materials:basalt` | Basalt | `default_stone.png^[colorize:#2a2a2e:90` |
| T4 | −501…−700 | `grug_materials:granite` | Granite | `default_stone.png^[colorize:#8a5a52:60` |
| T5 | −701…−1000 | `grug_materials:emberrock` | Emberrock | `default_stone.png^[colorize:#7a2a10:90` |
| T6 | −1001…−31000 | `grug_materials:abyssal_rock` | Abyssal Rock | `default_stone.png^[colorize:#241830:150` |

- Strata are cosmetic rock, not ore, crystal, metal or alloy. All use ordinary
  stone-like pick diggability, carry `grug_stratum = <tier>` for dispatch and
  drop ordinary Cobble. Deep rock encountered or placed near the surface is
  ordinary breakable material, never an indestructible PvP wall.
- Higher picks dig ordinary rock faster through explicitly authored `times`.
  For every stratum a higher-tier pick may reach, it is never slower than the
  preceding pick. Durability and speed are authored directly and verified in a
  six-pick × six-strata matrix.
- The five replacement strata remain `ore_type = "stratum"` registrations
  placed last, so natural cave walls inherit the correct visual band. That
  placement mechanism does not make their node identity the access gate.

The old node-`level`/pick-`maxlevel` progression is retired. Every Grudgelands
pick uses `groupcaps.cracky.maxlevel = 0`; natural resources, cosmetic strata
and crafted blocks in this system carry no non-zero `level`. Reachable vendored
exceptions, including Obsidian and metal/gem storage blocks and stairs, are
normalized so an unrelated default node cannot preserve the retired gate.
`times` and `uses` are then set to the intended effective values without any
`leveldiff` speed/durability multiplication. The shipped WP25 overrides and
its temporary Mese/Diamond test bridges are migration history, not balance
inputs; the revised test path must reach every band before those tools vanish.

If depth permission succeeds but the pick is below a natural resource's
minimum harvest tier, the node may be deliberately destroyed without a drop:

| Harvest-tier shortfall | Dig-time multiplier | Result |
|---:|---:|---|
| 1 | ×4 | node destroyed, no resource drop |
| 2 | ×6 | node destroyed, no resource drop |
| 3 | ×8 | node destroyed, no resource drop |
| 4+ | ×10 cap | node destroyed, no resource drop |

- The multiplier applies to that pick's normal effective dig time. One
  completed attempt consumes one ordinary pick-use event; there is no second
  wear penalty. Bare hands and non-picks cannot destroy ore/gem nodes.
- A `metal_only` resource (today exactly iron, §3.0.1) treats a
  same-tier starter pick as one shortfall step: ×4, destroyed, no drop,
  feedback naming the required Bronze pick.
- Descriptions/inspection state `Requires a T<n> pick to harvest`. Completion
  uses a dull fracture sound, a shattered particle cue and rate-limited HUD/
  chat feedback naming the lost resource and required tier.
- No raw item, Goldsmith bonus yield, XP or quest harvest credit is granted. A
  renewable socket still enters its ordinary depleted state and starts its
  refill timer, preventing free retries.
- Crafted storage/building blocks never enter this path: any real pick recovers
  them as themselves at any permitted position.

`grug_materials` remains the sole public owner of depth and harvest taxonomy.
It retains `TIERS`, `tier_at(y)` and `stratum_node_for(y)`, replaces
`level_for_tier` with a depth-oriented lookup such as
`max_depth_for_pick_tier(tier)`, exposes one
`can_mine_natural_at(pick_tier, y)` predicate, resolves group-backed resource
minimum tiers and settles successful harvest/bonus yield only after the tier
check. It returns structured failure data for the shared feedback path.
Callers always apply protection first; no other mod hard-codes a depth boundary,
harvest tier or stratum node name.

Pick profiles retain their authored monotonic ladder. Hoe identities, uses,
soil conversion, water buckets and wild renewal are authoritative in
[farming.md](farming.md); this document owns only their Basics recipes.

#### 3.0.5 The two boat recipes (decided 2026-08-13)

Water travel is specified in [boats.md](boats.md); this section owns only the
two recipes. Both are ordinary 3×3 grid recipes and need no workbench.

**Base boat** — a universal base recipe under §3.0.3: every character can
craft it from level 1, with no profession, trainer, vendor or quest. Five
`group:wood` in the hull shape (the arrangement of
`reference_projects/Lord-of-the-Test/mods/boats/init.lua:201-208`, whose row
boat is our reference implementation):

| | | |
|---|---|---|
| — | — | — |
| `group:wood` | — | `group:wood` |
| `group:wood` | `group:wood` | `group:wood` |

**Improved boat** — craftable only by a character carrying the Improved Boat
unlock (`boats.md` §1), which the shipwright teaches from level 30. It
consumes one base boat plus T4 materials, so the level-30 unlock still costs
a level-31–40 material run:

| | | |
|---|---|---|
| — | Silkweave Bolt | — |
| Silversteel Bar | Silkweave Bolt | Silversteel Bar |
| thread | base boat | thread |

The two bolts are the sail and the two bars the fittings; `thread` is the
ordinary level-independent vendor job supply of §3.7, not a new item and not
a Tailor product. Bolts and bars are material stages, and every stage is a
base recipe on its own grid (§3's "ore → bar → component → item; hide → cured
leather; cloth → bolt", with the bolt grades in §3.5), so the improved boat
binds no profession anywhere in its chain.

The shipwright's teaching transaction consumes exactly this ingredient list
once and returns one finished improved boat (`boats.md` §2). **Vendors never
stock a boat**, but like every other unsold item both boats still receive an
authoritative reference price and the ordinary ceiling-rounded 5% buy-back of
`economy.md` §2 — "not stocked" is not "worth nothing". §3.8's anti-loop rule
binds both recipes: a boat's payout must stay **strictly below** the summed
payout of the wood, bars, bolts and thread consumed to make it.

The shipped audit only partly enforces that, so the pricing WP owes two
explicit tests instead of trusting it. The improved boat's inputs are all
concrete items and are walked normally, but the base boat's are `group:wood`,
and the third `grug_traders` audit **skips any recipe with an unpriced input**
— a group never carries a price of its own
(`mods/ENTITIES/grug_traders/init.lua:257-261`). Its comparison is also
`out_price > input_total` (`:269`), so an exactly break-even output passes.
The base boat must therefore be priced below the five cheapest `group:wood`
members by construction, and both boats verified by test rather than by the
audit's silence.

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
Goldsmith spellbook. Scepters and orbs are absent on fresh servers: no item,
recipe, loot or vendor identity remains. Staves and wands use universal plain
Basics recipes; Woodcarver owns their enchantments. Bows are likewise
universal plain Basics, with Woodcarver owning their improvement operations.

For weapons, the catalogue's `_grug_ilvl` is also the minimum character level
for the Weapon slot. The slot filter enforces it directly; a weapon without an
item level has no level requirement. This gate does not apply to tools, whose
material/crafting ladder supplies their progression.

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

Coverage across the seven professions is complete and overlap-free
(professions.md §2).

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
armor uses the canonical 5/8/7/4 head/chest/legs/feet layouts. Metal fittings
are Weaponsmith trade goods used for professional improvement, never base gear.

**Exclusive recipes**: **metal fittings** and named family-legal enchantments.
Plain shields use their universal Basics grid; Armorsmith owns their enchants.
Cultural/PvP operations remain separate future delivery.

Ore access follows §3.0.4's three separate checks: territory/protection, the
pick's exact maximum natural y-depth and the resource's independent minimum
harvest tier. Cosmetic strata never grant access. Natural distribution comes
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

**Exclusive recipes** (mastery cut decided 2026-08-13, §2.1): **weapon
grips** at Apprentice — 2 leather of the item's tier, the
professions.md §3 cross-buy as a concrete component item; named leather-armor enchantments across T1–T6 (§6b). At Apprentice it also makes the four-stack **quiver**, an Offhand item
that stores arrows but grants no stat, affix or combat bonus, plus
the 8-slot Leather Pouch. Its 16/24/32-slot leather bags follow at
Journeyman/Expert/Master. Plain bows are Basics; Woodcarver owns their quality.

Supply loop as decided: the ×5 leather tag (professions.md §3), Tailors
buy leather for bags, Alchemists for apothecary gear, Woodcarvers for
grips.

### 3.5 Tailor (tailor bench) — cloth and cloth bags

**Material chain**: 2 cloth + thread → bolt. Authored grades are **T1 linen
scrap → patch bolt** (zombies drop scraps from L1 — Tailors start in safe
starting zones), **T2 linen cloth → woven bolt**, **T3 heavy cloth → heavy
bolt** and **T4 heavy + spider silk → silkweave bolt**; decided 2026-08-13:
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

### 3.6 Alchemist (brewing stand) — potions and elixirs

**Implemented 2026-09-18.** Herbalism is part of the Alchemist rather than a
separate profession. Gravemoss, Dragonweed, Crimson Lotus and Ember Moss are
fail-closed scenery for everyone who has not learned Alchemy; learning the
profession authorizes all four. Cave Cap remains food-grade and universal.
Recipe access is the Alchemist's effective profession tier (§2.2), not a herb
or keystone book gate. Every tier-N recipe contains a declared tier-N reagent.

Alchemists assemble a potion mixture from its reagents and vial in their own
inventory 3x3 grid; that qualified preparation awards current-tier progress.
The **Brewing Stand** accepts one mixture, fuel and finished outputs. Its
automatic completion and extraction are universal and grant no further progress.
Capital stations are personal workspaces; all player-placed copies are shared
stations subject to area access. The stand is a T3 Alchemist grid recipe:
three Steel Bars, one Furnace and one Glass Bottle. Glass Bottles cost 3 copper.

Potions restore or act immediately and share the persistent potion clock.
Ordinary potions use 60 seconds; the Greater Healing and Greater Mana pair use
45 seconds on that same clock. A full-health healing potion is refused without
consumption or cooldown. A mana potion may be consumed at full mana. Elixirs
never touch the potion clock: exactly one `elixir` status may run, the newest
replaces it, and it stacks with the separate food status. Pool and crit values
are percentage points. Apothecary equipment carrying `grug_apothecary` adds
10% duration to timed potions and elixirs, and +1 percentage point to a stat
elixir, per worn piece, with at most two pieces counted. Instant potions are
unchanged. Consumables require the first character level of
their recipe tier: **1, 11, 21, 31, 41, 51**.

| Tier | Product | Reagent 1 | Reagent 2 | Effect |
|---:|---|---|---|---|
| T1 | Healing Potion | Gravemoss | Sunleaf | 30% maximum HP instantly; 60 s shared cooldown |
| T1 | Mana Potion | Gravemoss | Carrot or Cassava | 30% maximum mana instantly; 60 s shared cooldown |
| T2 | Antivenom | Dragonweed | Venom Gland | Clears all active poison; 60 s shared cooldown |
| T2 | Swiftness Draught | Dragonweed | Fang | +10% movement speed for 5 s; 60 s shared cooldown |
| T3 | Greater Healing Potion | Crimson Lotus | Gravemoss | 30% maximum HP instantly; 45 s shared cooldown |
| T3 | Greater Mana Potion | Crimson Lotus | Sugar Cane | 30% maximum mana instantly; 45 s shared cooldown |
| T3 | Cave Draught | Cave Cap | Slime Gel | Night vision for 10 min; 60 s shared cooldown |
| T3 | Elixir of Vigor III | Crimson Lotus | Bear Claw | +5% maximum HP for 15 min |
| T3 | Elixir of Focus III | Crimson Lotus | Cave Cap | +5% maximum mana for 15 min |
| T3 | Elixir of Precision III | Crimson Lotus | Fang | +1 percentage point crit for 15 min |
| T4 | Elixir of Vigor IV | Crimson Lotus | Crocodile Tooth | +10% maximum HP for 15 min |
| T4 | Elixir of Focus IV | Crimson Lotus | Venom Sac | +10% maximum mana for 15 min |
| T4 | Elixir of Precision IV | Crimson Lotus | Shiny Scale | +2 percentage points crit for 15 min |
| T4 | Stoneskin Elixir | Shiny Scale | Crocodile Tooth | +4 armor rating for 30 min |
| T5 | Elixir of Vigor V | Crimson Lotus | Ember Moss | +15% maximum HP for 15 min |
| T5 | Elixir of Focus V | Cave Cap | Ember Moss | +15% maximum mana for 15 min |
| T5 | Elixir of Precision V | Shiny Scale | Ember Moss | +3 percentage points crit for 15 min |
| T5 | Deepwater Elixir | Stormkelp | Slime Gel | Water breathing for 10 min |
| T6 | Elixir of Vigor VI | Ember Moss | Stone Core | +20% maximum HP for 15 min |
| T6 | Elixir of Focus VI | Ember Moss | Wild Cocoa | +20% maximum mana for 15 min |
| T6 | Elixir of Precision VI | Ember Moss | Sharp Feather | +4 percentage points crit for 15 min |

Every row also consumes one Glass Bottle. Sovereign's Flask remains reserved
for the Human signature line in §4 and is not registered until that signature
effect exists. Apothecary armor items and imbuing oils remain later catalog
work; the two-piece runtime seam above is already authoritative.

### 3.6a Woodcarver (carving bench) — wood, bows and caster weapons

Woodcarver owns quality operations for the active wooden weapon families:
staff, wand and bow. Their plain recipes remain universal Basics.

**Material chain**: wood, including the per-race woods of biomes_mobs §5 —
silverwood and gravewood among them. Signature woods remain cultural inputs,
not a mandatory universal tier ladder. The six processed grades are decided
(2026-08-13): **Seasoned → Polished → Hardened → Inlaid → Lacquered →
Heartwood** (T1→T6), each craftable from any `group:wood` — both continents
reach every grade by construction, and the per-race woods stay a cosmetic/
cultural skin on top, never a tier gate. These grade words are the item
names WP29 uses (§3.8), such as a Hardened Staff.

**Enchants**: staves, wands and bows.

**Exclusive operations:** named staff, wand and bow enchants across T1–T6.
The quiver stays Leatherworker (§3.4).

**Cross-buy: the Woodcarver buys metal fittings from the Weaponsmith.**
Every tier of
professional enchanting needs a Weaponsmith-made fitting of the enchant tier.
Universal plain caster weapons never require a professional component. That is
the same deliberate supply loop the Leatherworker and Tailor already run
in professions.md §3 — a profession that cannot finish its own top item
alone is what keeps the market alive.

### 3.6b Goldsmith (jeweller's bench) — gold, gems, both trinket slots

New profession, 2026-08-07 (professions.md §2). **Gem Hunter is merged
into it** and disappears as a separate profession. The useful gathering hook
survives; the private-island Gem Detector does not.

**Material chain:** physical **Gold**, universal Quartz, and the six regional
gems Citrine/Garnet/Jade/Diamond/Sapphire/Ruby. Natural regional nodes drop
Rough Gems. The Goldsmith alone refines Rough → Cut; every storage block and
equipment recipe consumes Cut Gems where a gem is required.

**Owns exclusively:**

- both generic trinket slots and the six core trinket identities of §6.2;
- Rough → Cut gem refinement;
- jewelry Settings, ornament components and trinket assembly;
- one bonus-yield roll after a **successfully harvested** natural or renewable
  gem node: **10% base chance at Apprentice, 20% from Journeyman onward**. A
  success grants exactly one additional raw gem item of the harvested species.
  The roll never fires on stone, an under-tier shattered node or any failed
  harvest and never converts one gem into another. Dragon-camp yield audits
  include it.

Rough→Cut conversion, Settings, trinket assembly and named enchantments use
profession-tier qualification. Spellbooks retain their Journeyman prerequisite;
ornament components remain T3–T6. Imbue/Temper kits are removed.

The Gem Detector and Dowsing Rod are retired. Continental mining remains
exploration rather than direction/radar gameplay, and the Goldsmith already
has trinkets, cutting, components and real-node bonus yield as its complete
identity.

Use **Setting** consistently for the tiered jewelry component:

| Tier | Setting | Gem use per core trinket |
|---|---|---|
| T1 | Tin Setting | 1 Cut Quartz |
| T2 | Iron Setting | one authored Cut G1 variant |
| T3 | Copper-inlaid Steel Setting | one authored Cut G1 variant |
| T4 | Gold Setting | 1 Cut Sapphire for Manawell/Mercy Seal/Last Light; 1 Cut Ruby for Battlebeat/Reclaimer's Mark/Apothecary Loop |
| T5 | Gold-filigreed Embersteel Setting | 1 Cut Sapphire + 1 Cut Ruby |
| T6 | Gold-filigreed Abyssal Steel Setting | 1 Cut Diamond + 1 Cut Sapphire + 1 Cut Ruby |

Copper-inlaid Steel and the two filigree Settings are Goldsmith components,
not universal bars or tool materials. At T2/T3, Citrine supplies Manawell and
Mercy Seal, Garnet supplies Battlebeat and Reclaimer's Mark, and Jade supplies
Last Light and Apothecary Loop. The complete tier list is visible in the
matching book group: all six T4 recipes become craftable with profession T4,
so foreign-gem acquisition rather than recipe rarity remains the material
gate. No recipe scroll, reputation grind or enemy unlock is involved.
Each core trinket recipe consumes only its tier-appropriate Setting and the
listed Cut gem(s): there is no special-specific herb, catalyst, mob drop,
trophy or cross-profession component.

### 3.7 Universal secondaries & vendor floor

Neither of these costs a main profession slot (professions.md §1).

- **Cooking** (trainer, free) uses the profession framework. Learning it opens
  T1 and shows the complete T1–T6 catalog; profession level gates crafting and
  `_grug_ilvl` gates eating independently. There is no Cooking Fire.

  **Food restore values** (duration amended 2026-09-20). A serving lasts **300 s**, ticks every **5 s**,
  and the newest food replaces the old one. Instant healing and regeneration
  wait while the player is in combat; secondary modifiers remain active.

  | Tier | Minimum level | Instant HP | Dish regeneration per tick | Hearty secondary | Caster secondary | Hunter secondary |
  |---|---:|---:|---:|---|---|---|
  | T1 | 1 | 5 | 2% | — | — | — |
  | T2 | 11 | 15 | 2.5% | — | — | — |
  | T3 | 21 | 40 | 3% | +2% HP pool | +2% mana pool | +2% HP pool |
  | T4 | 31 | 90 | 3.5% | +4% HP pool | +4% mana pool | +4% HP pool |
  | T5 | 41 | 180 | 4% | +6% HP pool | +6% mana pool | +1% Crit |
  | T6 | 51 | 300 | 5% | +8% HP pool | +8% mana pool | +1% Crit |

  Hearty and Hunter dishes regenerate HP. Caster dishes regenerate both HP and
  mana at the listed rate. Every raw edible regenerates 1% maximum HP per tick;
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
  | Ember Moss | T5 | T5 | inedible Alchemist reagent | emberrock at y ≤ −701 |

  Existing raw-food tiers are Apple T1, Blueberries T1, raw meat T1, ordinary
  Raw Fish T1, Corn T1, Potato T1, Melon T1, Mushroom T3 and Wild Cocoa T6.
  The five band fish are T2–T6 respectively. Cooked Meat, Cooked Fish and Bread
  are T1 Hearty dishes.

  **Cooking book.** Every row is a profession recipe at the crafting grid and
  contains at least one ingredient registered at its own recipe tier.

  | Tier | Role | Inputs | Output |
  |---|---|---|---|
  | T1 | Hearty | raw meat + potato or corn | Hearty Stew |
  | T1 | Caster | carrot or cassava + potato or corn | Sweetroot Mash |
  | T1 | Hunter | raw fish + corn | Corn-Crusted Fish |
  | T2 | Hearty | pumpkin + raw meat + potato or corn | Pumpkin Stew |
  | T2 | Caster | 2 berries + Sugar Cane | Berry Preserve |
  | T2 | Hunter | raw meat + apple or berries | Fruit-Glazed Roast |
  | T3 | Hearty | mushroom + raw meat + potato or corn | Forager's Pot |
  | T3 | Caster | 2 mushrooms | Mushroom Skewer |
  | T3 | Hunter | raw meat + Wild Onion or Fire Pepper + mushroom | Onion-Seared Steak |
  | T4 | Hearty | raw meat + Marshbloom + potato or corn | Marsh Roast |
  | T4 | Caster | raw fish + Marshbloom | Marshbloom Chowder |
  | T4 | Hunter | 2 raw meat + melon + mushroom | Hunter's Feast |
  | T5 | Hearty | raw meat + Stormkelp + Rock Salt | Kelp-Wrapped Roast |
  | T5 | Caster | Stormkelp + raw fish + melon | Stormkelp Broth |
  | T5 | Hunter | raw fish + Rock Salt | Salt-Crusted Fish |
  | T6 | Hearty | 2 raw meat + Wild Cocoa + Stormkelp | Grand Feast |
  | T6 | Caster | 2 Wild Cocoa + Rock Salt | Jungle Cocoa |
  | T6 | Hunter | raw meat + Wild Cocoa + Fire Pepper or Wild Onion | Cocoa-Rubbed Game |

  **Both furnace patterns.** Raw meat → Cooked Meat, ordinary Raw Fish →
  Cooked Fish and Wild Grain → Bread are universal Basics routes with no
  profession progression. Every tier also
  has one Cooking grid recipe for an inedible raw assembly; its
  universal furnace finishing route meets the direct grid route at the same edible
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
  table is 78% its band fish, 12% stick and 10% papyrus. Fresh and salt water
  use the same table for the same level.

- **First Aid** (trainer, free): Linen/Heavy/Silk Bandage — channel
  6 s (damage interrupts), restores 15%/30%/45% HP, then 30 s
  "recently bandaged". Cloth competes with Tailoring demand — intended.
  **No book** — all recipes at once, materials are the only gate.
- **Vendor stock**: the level-independent core (small bag, weak healing
  potion, wooden/stone tools, bronze pick, torches, job supplies —
  thread/flux/vial/parchment/whetstone blank) plus the **bracket
  catalogs** of §3.8.

### 3.8 Vendor bracket catalogs (decided 2026-08-07)

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

  **T4–T6 regional-G2 base cost.** Every ordinary crafted combat weapon,
  armor piece and offhand at these tiers consumes one specific Cut G2 gem in
  addition to its universal material recipe:

  | Gear tier | Main-hand weapons | Head/chest/legs/feet | Offhand |
  |---|---|---|---|
  | T4 | Ruby | Diamond | Sapphire |
  | T5 | Diamond | Sapphire | Ruby |
  | T6 | Sapphire | Ruby | Diamond |

  One reference main hand, four armor pieces and one offhand across all three
  tiers therefore consumes exactly **6 Diamond / 6 Sapphire / 6 Ruby**. A
  two-handed weapon consumes its tier's main-hand gem and its offhand gem,
  preserving the demand of the displaced slot. Pickaxes, shovels, axes and
  other gathering tools, bars, furnaces and repair are
  excluded. Ordinary affixes do not charge the base G2 again.
  Species grants no hidden stat; it is the recipe's material identity.
  Trinkets use their explicit symmetric recipes in §3.6b/§6.2.

  Adding two native-family T4 trinkets and two current trinkets at each of T5
  and T6 yields this lifetime reference demand:

  | Faction | Diamond | Sapphire | Ruby | Foreign native-exclusive G2 |
  |---|---:|---:|---:|---:|
  | Accord | 8 | 12 | 10 | 10 Ruby |
  | Throng | 8 | 10 | 12 | 10 Sapphire |

  Choosing a foreign-family T4 special deliberately raises foreign demand;
  the baseline burden remains symmetric. Dropped/vendor gear stays a usable
  floor for contesting the source but is audited so it cannot erase crafted
  G2 demand.

  Rationale for having the vendor ladder at all: on a small server the
  crafter for your armor class may simply not exist — the floor stops a
  player from going naked, it does not compete. Superseded 2026-08-07:
  the old "±15 % of crafted gear of the same era" comparison, and the
  older "10–15 % behind" before it. Under the merge there is nothing to
  compare — vendor gear and base crafted gear are the same item, and the
  crafter's edge is enchantments (§6b), not a base number.
- **Rotation**: the core stock is fixed; each bracket additionally shows
  a handful of **rotating gear slots**, re-rolled hourly. Roughly **one
  rotation in five carries a single Uncommon item**, rolled in the
  **world window** (frac 0.00–0.60, §6.3 — the weakest rolls in the
  game; crafted enchantments instead have fixed tier values) and priced above the Common
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
    after the economy/loot pass fixes the multiplier.
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

Every craft output carries `_grug_sell_price` with the **anti-loop rule:
vendor value of a crafted item < summed vendor value of its
ingredients** — vendors are a floor, never a factory profit.

## 4. Cultural materials, finishing and PvP counters

The old six fixed ilvl-60 race-signature recipes are retired. Cultural identity
now scales across T1–T6 as an in-place finish on universal base equipment. A
separate PvP-special channel represents deliberate preparation against a
target race; cultural appearance never implies that the item counters its own
culture.

### 4.1 Cultural resources and ownership

| Culture | Material | Ordinary cultural/architectural uses | Concentrated contested form |
|---|---|---|---|
| Human | Sunwax | candles, seals, polish, gilded accents | wild waxcomb/apiary cache |
| Dwarf | Runeslate | tablets, hearths, carved inlay | slate inscription seam |
| Elf | Moonresin | varnish, bows, pale wood ornament | resin root/fossil-resin nodule |
| Orc | Red Ochre | pigment, adobe decoration, war paint | ochre clay/outcrop deposit |
| Troll | Spirit Resin | totem lacquer, incense, masks | resinous root/amber nodule |
| Undead | Gravesalt | grave lights, urns, wards, markers | salt crust/crystal seam |

- Each culture has an ordinary home-region surface source sufficient for its
  architecture, quests and trade, plus a concentrated surface source in
  exactly the one race-frontier zone listed for it in `world_zones.md` §11.
  No Battlegrounds zone receives that concentrated rate. The concentrated
  source requires T4 harvesting; an ordinary surface source retains its
  natural axe/shovel/hand-gathering behavior.
- Ordinary opportunity density is exactly 1/4096 eligible logical-biome
  columns; the concentrated zone uses 1/1024. Both forms drop exactly one
  material per node: concentration is the fourfold opportunity density, never
  a second per-node yield multiplier.
- A material is not forced into every cultural object: Gravewood furniture
  need not consume Gravesalt. Moonresin uses a cool silver-blue/pearlescent
  palette; Spirit Resin uses warm amber or toxic green.
- Foreign cultural materials are used almost exclusively for optional
  level-40+ PvP counters. They never enter universal bars/tools, ordinary G2
  base costs, ordinary recovery consumables, solo-leveling requirements or
  profession-level advancement. Regional G2 demand and optional cultural-counter
  demand are independent economies.
- Signature woods remain universal `group:wood` inputs. Their distinct value
  is cultural builds, furniture and optional recipes, never mandatory tool
  progression.

The concentrated harvesting families are exact:

| Material | Required family at T4+ | Ordinary source behavior |
|---|---|---|
| Sunwax | axe | hand |
| Runeslate | pick | hand |
| Moonresin | axe | axe |
| Red Ochre | shovel | shovel |
| Spirit Resin | axe | axe |
| Gravesalt | pick | shovel |

`grug_materials` is the sole tool-family tier authority. Its public resolver
`tool_tier_for_stack(stack, family)` accepts exactly `pick`, `axe` or `shovel`
and reads the matching integer group `grug_pick_tier`, `grug_axe_tier` or
`grug_shovel_tier` in 1..6. WP29 supplies those groups on the final tool
catalog. Missing/malformed authority, the wrong family or a tier below four
fails closed without removing the node, wearing the tool or granting a drop;
WP33 creates no temporary T4 tool or duplicate tier taxonomy.

### 4.2 Cultural finishing

A cultural finish is a permanent per-stack workstation operation. It preserves
the base item, material tier, quality, durability, ordinary
prefixes/suffixes, masterwork state and PvP-special data; it creates no kit or
parallel registered item.

- Eligible families are exactly **weapon, offhand, head, chest, legs and
  feet**. Trinkets are excluded. Each eligible stack carries at most one
  cultural finish, while a character may freely mix any number of cultures
  across its six slots.
- Every culture has one fixed deterministic effect for each eligible family.
  The user never chooses a culture-local random/smart stat, and a sword and
  hammer do not select different signatures merely because their visual
  subtype differs.
- Direct player production requires the base family's owning Weaponsmith, Armorsmith,
  Leatherworker, Tailor or other explicitly assigned profession at the
  matching tier, and the crafter may apply only their own culture's finish.
  Finished stacks are tradeable and function for any wearer without race or
  faction restriction.
- Each culture's passive, invulnerable cultural master offers the identical
  operation to allied players who supply all inputs and pay §8.4's ledger fee.
  The customer needs no owning profession. An enemy master refuses service;
  foreign finishes arrive through trade or transferred finished items.
- A different cultural finish overwrites the old finish and appearance at full
  material/service cost without refund; the preview shows old effect, new
  effect and complete cost. Reapplying the same culture is rejected before any
  consumption.

Direct inputs by item family and material tier:

| Eligible family | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 1 | 2 | 3 | 4 | 4 | 5 |
| Offhand | 1 | 2 | 2 | 3 | 4 | 4 |
| Chest / legs | 1 | 2 | 2 | 2 | 3 | 3 |
| Head / feet | 1 | 1 | 1 | 2 | 2 | 2 |

The number is units of the selected culture's material. Weapon and offhand
also consume one unit of that culture's signature wood for a grip/core/focus;
armor consumes no wood. The operation adds no G1/G2 gem, universal bar or
trophy because the base item has already paid its ordinary recipe.

The fixed effect matrix is:

| Culture | Weapon | Offhand | Head | Chest | Legs | Feet |
|---|---|---|---|---|---|---|
| Human | Strength | Intelligence | Mana | HP | Armor | Dexterity |
| Dwarf | HP | Armor | Strength | HP | Armor | Strength |
| Elf | Crit | Dodge | Crit | Dexterity | Dexterity | Dodge |
| Orc | Strength | HP | Crit | HP | Strength | Crit |
| Troll | Intelligence | Mana | HP | HP | Dodge | Dodge |
| Undead | Intelligence | Crit | Mana | Mana | Intelligence | Crit |

Effects consume normalized value points. A point is a balancing unit with an
explicit conversion, not a generic +1%:

| Family | T6 point budget |
|---|---:|
| One- or two-handed weapon | 5 |
| Offhand | 4 |
| Chest | 3 |
| Legs | 3 |
| Head | 2 |
| Feet | 2 |

| Material tier | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Share of T6 budget | 20% | 35% | 50% | 65% | 80% | 100% |

| Effect | Per value point after tier scaling |
|---|---:|
| Strength / Intelligence / Dexterity | +3 |
| Maximum HP | +1% of the base pool |
| Maximum Mana | +1% of the base pool |
| Crit / Dodge | +1 percentage point |
| Armor | +1 raw armor rating |

Primary attributes and the current-level absolute values of HP/Mana
percentages round half-up to whole numbers. HP/Mana lines show both the
percentage and that absolute value. Crit, Dodge and armor show one decimal
where needed. Every tier must be strictly stronger
in effective and displayed value; if a conversion would collapse two adjacent
tiers, its display/conversion quantum changes. A two-handed weapon retains the
five-point weapon budget and receives no compensation for its unavailable
offhand.

The resulting T6 per-stack values are:

| Culture | Weapon | Offhand | Head | Chest | Legs | Feet |
|---|---|---|---|---|---|---|
| Human | +15 Str | +12 Int | +2% Mana | +3% HP | +3 armor | +6 Dex |
| Dwarf | +5% HP | +4 armor | +6 Str | +3% HP | +3 armor | +6 Str |
| Elf | +5% Crit | +4% Dodge | +2% Crit | +9 Dex | +9 Dex | +2% Dodge |
| Orc | +15 Str | +4% HP | +2% Crit | +3% HP | +9 Str | +2% Crit |
| Troll | +15 Int | +4% Mana | +2% HP | +3% HP | +3% Dodge | +2% Dodge |
| Undead | +15 Int | +4% Crit | +2% Mana | +3% Mana | +9 Int | +2% Crit |

All finish, affix, attribute and base-equipment sources add before their final
consumers. Crit and Dodge cap at 30%. Armor remains uncapped as raw rating;
attacker-level mitigation alone caps at 70%. The Talents header displays raw
rating and same-level reduction; there is no reroll or overflow conversion.
The theoretical T6
cultural-only mixed-set maxima are approximately +14.8 Crit percentage points
(including compatible Dexterity), +9.9 Dodge points and +7 armor points.

Every cell grants exactly one existing central stat. Cultural finishes add no
proc engine, periodic step, regeneration, steal/execute/control effect,
cooldown reduction or knockback resistance. Cells are intentionally not
class-adaptive: some are unattractive to a particular build, while each culture
retains at least two economically desirable cells and each faction's three
cultures collectively cover damage, mitigation and healing/casting roles.

### 4.3 PvP-special channel and target-race recipes

Every item may carry at most one **PvP special**, stored independently of
ordinary affixes and the cultural finish. Identical target-race specials never
stack; if two legal sources affect one action, use the highest value. Applying
a new target overwrites the old special at full material/service cost and no
refund; applying the identical target is rejected as a no-op.

The MVP ships exactly two data-driven families, parameterized by the six target
cultures:

1. **Weapon counter finish.** A permanent in-place operation on an equipped
   weapon, owned by the profession that owns that weapon family.

   | Weapon tier | Target cultural material | Target-race damage |
   |---|---:|---:|
   | T4 | 1 | +1 flat |
   | T5 | 2 | +2 flat |
   | T6 | 3 | +3 flat |

   It consumes no additional bar, gem, wood or trophy. Only an accepted attack
   sourced from the currently equipped weapon contributes counter damage; a
   spell does not inherit it from the ability icon's weapon appearance. Add
   the flat amount after the ordinary Crit result and before armor and absorb,
   so armor mitigates it and Crit never multiplies it. It affects hostile
   players and combat-capable
   NPCs/mobs with the matching race identity, never passive invulnerable
   service NPCs. An allied passive profession helper performs the same
   supplied-material operation for 50% of that tier's Common weapon reference
   price (§8.4); it supplies no foreign material.

2. **Warding Draught.** An Alchemist-only T4–T6 recipe reducing incoming
   damage from one selected target race for five minutes.

   | Tier | Mitigation | Cultural material | Complete recipe |
   |---|---:|---:|---|
   | T4 | 5% | 1 | 1 Vial + 1 Dragonweed + 1 Marshbloom + 1 target material |
   | T5 | 7.5% | 2 | 1 Vial + 1 Crimson Lotus + 1 Stormkelp + 2 target materials |
   | T6 | 10% | 3 | 1 Vial + 2 Crimson Lotus + 2 Stormkelp + 3 target materials |

   Apply its multiplier after armor and before absorb. Only one target-race
   ward is active; a new draught replaces the old ward and its remaining
   duration. It is its own PvP-buff category and may coexist with one ordinary
   elixir and the food restore buff, but it shares the global 60-second
   potion-use clock and does not require missing HP/Mana. Apothecary Loop
   changes neither its
   percentage nor duration. An allied passive Alchemist helper consumes the
   same supplied ingredients and charges 50% of the draught's authoritative
   reference price. The ward recognizes hostile players and combat-capable
   NPCs/mobs carrying the selected race identity; passive invulnerable service
   NPCs never enter the damage interaction.

Armor-wide counter stacking, percentage counter damage, coatings, counter-kit
items, taunt trinkets, effigies and other race gadgets are outside the MVP and
receive no placeholder registrations or recipes.
All six target cultures use the same tier/effect budget. Population statistics
never make a currently common race's permanent counter stronger.

### 4.4 Material art contract

Use a hybrid source strategy: derive mundane bases/tree palettes from
license-cleared references, adapt the proven per-stack trim/meta technique, and
author Grudgelands' six cultural motifs plus fantastic-material language. Every
reused asset records file provenance, author, exact license, pinned source
commit and modifications in the owning `LICENSE-media.md`.

Each of the six regional gems has exactly four visual roles: natural ore node,
Rough Gem, Cut Gem and polished non-luminous storage block — **24 roles total**
before equipment overlays. Each cultural material has an inventory identity
and at least one source-node/gather presentation. Signature woods receive a
full tree/build palette only where an existing licensed wood cannot carry the
culture cleanly.

Before bulk production, one 16×16 art spike verifies: a complete gem family
through trinket use; Emberglass → Embersteel item/bar/block language; one armor
base with two cultural trims and a separate PvP-special marker; one cultural
material in ordinary architecture and a counter recipe; and the complete
sheet at native resolution plus nearest-neighbor enlargement. AI-generated
concepts/variants require manual limited-palette, hard-edge and pixel-cluster
cleanup before they become final game art.

## 5. Loot zones — what drops where

Drops obey the player-tag rule (combat_stats §3), quality/roll windows
per §6.3, and ordinarily use **gear-drop ilvl = min(mob level, 60)**.
Authored level-60 endgame rewards are the exception: dungeon gear is ilvl
**65**, raid/King gear ilvl **70**, and apex/final-boss gear ilvl **75**.
All three use §6.3's top roll band; their ilvl above 60 feeds the same weapon
base-damage curve as every other weapon, not a second combat multiplier or a
fifth enchant band. The
level-100 Kraken Guard still drops nothing. Since the roll band is chosen by
the item's ilvl, that one number is all a drop needs: a drop
has no crafter whose mastery could be read instead. Named zone → materials is
binding through each zone's fixed biome/gathering palette; the level band adds
the gear/special layer.

**A dropped item's material tier must match the mob's tier** (added
2026-08-07). The ordinary `ilvl = min(mob level, 60)` rule of §5 already
implied it; stated outright
because the item is now material-named: a **T3 (Steel) item drops from
level 21–30 mobs** and nowhere else. A mob may not drop gear from a tier
its level band does not cover — that is what stops the drop table from
becoming a side door around the depth gate of §3.0.4.

| Named-zone band | Materials | Gear drops | Special |
|---|---|---|---|
| Peaceful starts 1–10 | equivalent T1 access on both faction sides | T1, source windows per §5.1 | no PvP objective |
| Peaceful home zones 11–20 | equivalent T2 access | T2, source windows per §5.1 | first named rares; no contested zone |
| Peaceful heartland 21–30 | equivalent T3 access | T3, source windows per §5.1 | preparation for the central frontier |
| Contested approaches 31–40 | equivalent T4 access plus practical foreign-G2 routes | T4, improved windows on qualifying elites | all six race approaches and the Battlegrounds entry are contested |
| Front 41–50 | equivalent T5 access | T5, improved windows on qualifying elites | war-front objectives and quest hooks; no free supply crates |
| High front 51–59 / endpoints 60 | equivalent T6 access | T6, improved windows; elites common | two contested dragons and all-six-gem apex camps |
| Depth axis | six cosmetic strata behind the position-based limits of §3.0.4; Iron is reachable in T1, mined Coal by T2, Silver by T3, Emberglass and G2 by T4, Abyssal Crystal by T5; race-region columns select G1/G2/cultural species and deep T6 adds bounded density | cave mobs as per surface tier | **no gear-drop layer of its own**, at any depth (below) |
| Enemy faction | equivalent tier budgets, not necessarily identical palettes | same tier/source rules | enemy named rares and any raid-enabled king remain incentives |

**The depth axis pays in materials, and gets no drop layer of its own**
(decided 2026-08-08). The deep band below −1000 (`world.md` §4c) is a
level-60 place only a T6 pick reaches, which makes it the obvious home
for a T6 gear layer — and deliberately does not become one. Underground
mobs keep dropping exactly what their families drop on the surface (the
Gear drops column above); nothing is added for being deep. Two reasons,
both structural: **the best items come from crafting and from hard
bosses** (§0, §6.4 — §6.3's two top windows, crafted-masterwork 0.60–1.00
and boss 0.80–1.00, are exactly those two), and a depth layer would be a third top source with neither a
crafter nor a boss behind it; and the depth already pays the endgame
*material*, which is the input the crafted endgame item is made of.
Depth buys danger and volume; the gear it feeds is made, not found.

### 5.1 Quality chance per source (kill, player-tagged)

**Still valid after the 2026-08-07 rework.** "Only professions can
enchant" (§6b.3) means only a profession can **apply** an enchant to an
item; **found items keep their own enchants**. A mob drop arrives
pre-enchanted from this table and is worn as it fell, with no crafter
involved. The two systems never meet.

| Source | Uncommon | Rare | Roll window (§6.3) |
|---|---|---|---|
| Normal mob | 3% | — | world |
| Elite (armor 80) | 20% | 3% | elite |
| Named rare (armor 70) | 100% | 25% | rare |
| Apex boss / race King | — | 100% | boss |

Found enchantments do not imply a separate refined state.

**Which item drops is one uniform draw over the concrete registered base
items of the mob's own tier** (stated 2026-08-13) — the bracket's whole
current item list, with no slot pre-selection and no per-family weighting.
Adding a registered family therefore changes the resulting proportions; no
fixed family count or weighted table exists anywhere in this design.

Found source windows have expected fractions world 0.30, elite 0.60,
rare 0.75 and boss 0.90. They overlap; a single lower-source roll can exceed a
higher-source roll. Crafted enchantments instead use the fixed tier table in
[the current contract](crafting_equipment_revision.md#enchanting).

WP5 still owes the loot/economy audit: found gear must not erase demand for
crafted G2 gear. No removed masterwork/temper workflow is assumed by that audit.


### 5.2 Named rares (spawn rules decided in biomes_mobs §3.3)

2–4 h respawn, patrol routes, faction-wide broadcast. Loot per kill:
guaranteed Uncommon (rare window) + 25% Rare + **100% signature trophy**
(`group:grug_rare_trophy` — Grimtusk's Tusk, Silkfang's Gland, …): a
qualifying optional masterwork ingredient and, where explicitly listed, a
profession recipe input. It never enters a universal bar or pick (§2.3,
§3.0.2, §6.4). Anti-camping:
patrol routes + broadcast + the 2–4 h jitter (already decided) — no
extra mechanic needed.

### 5.3 Apex world bosses (world.md §4b)

The two offshore dragons are separate contested encounters and use personal
boss rewards with independent per-character 24-hour loot lockouts. Their
participation and reset accounting matches the king ledger below. A boss
reward may include Rare gear in the boss window and authored materials, but it
never pays ledger money directly and no universal bar/pick depends on it:
continental T5 Abyssal Crystal is the ordinary T6 entry. Dragon-island gem
sockets are a separate renewable gathering source, not boss loot.

### 5.4 Six race Kings and Fallen Crowns

Each race has one killable level-65 elite King protected by four level-60
elite royal guards. Essential service NPCs are separate, passive and
invulnerable.

- **Fallen Crown** is one registered item with per-stack defeated-race
  provenance, cultural overlay and generated name, not six currencies.
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
- The Crown substitutes one-for-one for a qualifying named-rare trophy in the
  existing trophy slot of an ordinary Master-tier masterwork, including a T6
  Grudgeforged item. It grants the same stat/affix budget and quality window;
  royal provenance supplies visual identity.
- No universal bar, pick, profession-level advancement or ordinary base gear requires a
  Crown, and no power-bearing recipe is Crown-only. Guard loot is ordinary
  level-60 elite loot and never substitutes for a Crown. Rewards enter the
  ledger only if their sellable items are later sold.

### 5.5 Contested-front reward hook

The authored war front feeds crafting only through the existing
player-involvement war-trophy/heavy-cloth rules and later explicit quests.
WP42 ships no refilling supply crate. Each contested zone reserves one
non-loot quest-interaction slot for WP9; it is not a free material source.
The two endpoint apex mining camps are the sole map-side addition: each has
the 12 all-six-gem nodes specified by `world_zones.md` §6 and
`world.md` §2 R4 — exactly two renewable sockets per species. Each depleted
socket refills independently after a randomized 2–4 hour interval; an
under-tier destruction still depletes it, and the Goldsmith bonus is included
in the yield audit. Runtime economy calibration may tune the interval while
preserving the confirmed two-live-nodes-per-species budget.

## 6. Quality tiers & enchant roll ranges (WP5 numbers)

### 6.1 Meta model

Item meta carries `grug_quality` (1 Common / 2 Uncommon / 3 Rare / 4
Unique-reserved), one serialized ordinary-affix table (`grug_ench`),
and separate structured cultural-finish and PvP-special state where applicable. These
channels never overwrite one another. Exact storage keys are implementation
owned; one idempotent description/stat regeneration path reads them all.

**Weapon level requirement.** Ordinary base weapons require levels
**1 / 10 / 20 / 30 / 40 / 50** across the six material tiers. T1 uses an explicit
level-1 requirement while retaining item level 3 for base stats. Elevated found
weapons require their actual item level up to the character cap. The Weapon slot
refuses insufficient level but imposes no class-family gate. Wood/Stone weapons
are absent; gathering tools cannot be equipped there. Armor, offhands and
trinkets are not level-gated by this weapon-only rule. Higher-level weapons remain lootable and tradeable, just not
equippable yet. Endgame ilvl 65/70/75 weapons all require level 60. The
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
swings per second, which is the only reading under which §6.3's 3–16%
band is a linear DPS gain; `fpi × (1 − p)` would pay more than it says.
The override must be written as a **complete** tool-capability table — a
plain meta float named `full_punch_interval` is not read by the engine —
and every other capability of the base item is preserved unchanged. Enchant count: **Uncommon rolls exactly one affix; Rare rolls exactly one prefix and one suffix** — the decided budgets, and from 2026-08-07 also the prefix and
suffix count of §6b. Found/vendor Uncommon sources receive one affix and Rare
sources receive both channels. Crafted results use the same exact shape;
the chosen channels determine the count (§6b.5).

Cultural finish and PvP-special lines are displayed separately, naming their
culture/target and exact value. Trinkets are the exception to the ordinary
base-stat model: §6.2 gives them no base-stat line or durability, but two selectable enchant channels and an authored special.

The base-stat line uses the concrete item's level. Chosen affixes add only
their explicit values; there is no hidden damage/armor/lifetime multiplier.

**Hand-off from the vendor catalogs** (WP7 → WP5, 2026-08-07): vendor
gear ships with the item-def fields **`_grug_ilvl`, `_grug_bracket` and
`_grug_quality = 1`**. The Weapon-slot filter reads `_grug_ilvl` directly,
so a bracket catalog needs no second list of levels or per-stack duplicate.
The later quality/enchant pipeline derives its rolls from these fields and
preserves the requirement while rebuilding the description.

### 6.2 Enchant pools per item family (no duplicate stat per item)

| Family | Pool |
|---|---|
| Sword, dagger, greataxe | +Str, +Dex, +attack speed%, +crit%, +max HP%, +max Mana% |
| Bow | +Dex, +crit%, +attack/draw speed%, +max HP%, +max Mana% |
| Staff, wand | +Int, +max Mana%, +crit%, +max HP% |
| Shield | +Str, +Dex, +max HP%, +armor rating |
| Goldsmith spellbook | +Int, +max Mana%, +crit%, +max HP% |
| Metal armor | +Str, +max HP%, +armor rating |
| Leather armor | +Dex, +max HP%, +max Mana%, +crit%, +dodge% |
| Cloth armor | +Int, +max Mana%, +max HP%, +crit% |
| Quiver, bags | none |

Ordinary equipment keeps the no-duplicate-stat rule across its prefix and
suffix. Either channel draws from the same family pool. Cultural finish and
PvP-special stats are separate named
sources and may match an ordinary affix; all sources add before final caps.
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
first or replaced; target tier must be at least enchant tier. No crafted roll is
random. Found-item random rolls remain separate loot behavior.

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
  potions. It neither shortens nor resets the shared 60-second cooldown and
  does not modify Warding Draughts.

Direct damage procs, ability cooldown reduction, movement speed, gathering
yield, durability and vendor bonuses are excluded from the six-special MVP.
A future race-taunt trinket would consume its one authored-special channel,
not add a fourth channel; no such placeholder ships now.

The shared trinket owner rebuilds an event-driven per-character equipment cache
when equipment changes. Hot mana, heal, hit, kill and potion paths read that
cache and never rescan equipment per tick or event. It enforces the
same-identity-per-character exclusion and every cap/cooldown above.

### 6.3 Roll ranges by the item's ilvl bracket and source window

Value ranges (min–max) per ilvl bracket. **The band is chosen by the
ITEM's ilvl** (decided 2026-08-08) — never by the crafter's mastery tier
and never by the crafter's character level. The four bands below are the
"item levels" column of §2.1's mastery table — 1–15 / 16–30 / 31–45 /
46–60, same boundaries, no third set anywhere; authored ilvl 61–75 endgame
items continue to use the 46–60 value band. That those boundaries
fall on the same numbers as the four mastery level anchors is a property
of the numbers, not a rule. These bands are **not** the six material
tiers of §3.0; the two ladders are independent by design (§2.1).

Two consequences, both intended:

- **A Master who crafts a low-tier item gets low-tier rolls.** A
  level-50 Master smithing a T1 Bronze Sword (ilvl 3) rolls in the 1–15
  band — +1–3 Str, not +6–12. **The item is what is weak, not the
  crafter**, and this is the same rule as "a T2 enchant cannot be applied
  to a T1 item", read from the roll table's side. What the Master's rank
  still buys on that sword is access to the later value operations (§6b.5),
  not a bigger number per slot.
- **An Apprentice fills the prefix even on a T6 item.** Mastery decides
  which slot/value operation a crafter may perform (§6b.5), never how big
  the roll is: an Apprentice working T6 stock produces a one-affix
  item whose single roll is a full 46–60 roll.

**Mob drops have no crafter at all**, which is the other half of the
argument: §5 ordinarily sets gear-drop ilvl = min(mob level, 60) and points at this
table, so
for a drop only the item reading can work at all. One rule for both
sources is what keeps a dropped and a crafted item of the same ilvl
comparable.

| Enchant | 1–15 | 16–30 | 31–45 | 46–75 |
|---|---|---|---|---|
| +Str / +Int / +Dex | 1–3 | 2–5 | 4–8 | 6–12 |
| +Max HP% | 1–2 | 2–3 | 3–4 | 4–5 |
| +Max Mana% | 1–2 | 2–3 | 3–4 | 4–5 |
| +Crit% / +Dodge% | 0.5–1.0 | 0.5–1.5 | 1.0–2.0 | 1.5–3.0 |
| +Attack speed% | 3–6 | 4–8 | 6–12 | 8–16 |
| +Armor rating (armor/shield families) | 1–2 | 1–3 | 2–4 | 3–6 |

The endgame ordinary-affix budget is therefore approximately **+5% per
equipped slot × eight slots = +40%** when every slot is dedicated to one
axis. An offensive allocation may spend all eight damage-equivalent
contributions. At level 60, the damage curve gives a 1H weapon 25 / 29 / 30
damage at ilvl 60 / 70 / 75. With the Warrior's 18-point melee bonus and the
shared damage fit, the +40% allocation produces 515 / 526 effective damage at
ilvl 70 / 75 against the ilvl-60 baseline's 337: **+52.8% / +56.1%**, the
intended +50–60% fully equipped ceiling.

**Source window** (the decided "same mechanic, only ranges differ"):
`roll = min + frac × (max − min)`, frac uniform in the window:

| Window | frac | Used by |
|---|---|---|
| world | 0.00–0.60 | normal-mob drops |
| elite | 0.30–0.90 | elite drops, dungeon/crate loot |
| rare | 0.50–1.00 | named-rare drops |
| boss | 0.80–1.00 | apex hoards, race Kings |

**Combined cap policy (revised 2026-09-20).** Ordinary affixes, trinket
prefixes/suffixes, cultural finishes, attributes and base equipment all add
before their consumers. Crit and Dodge cap at 30%. Armor sources add uncapped
raw rating; `combat_stats.md` §2 converts that rating against attacker level
and caps only final reduction at 70%. The Talents header shows Crit/Dodge
effective and raw values plus raw armor rating and same-level reduction.

The old eight-identical-affix-slot calculation is retired: each trinket now has
one primary prefix and one HP/Mana/Crit suffix rather than four ordinary slots.
At T6, two trinkets can therefore add at most two direct Crit suffixes, while
the six ordinary combat stacks retain their family pools. Cultural finishes
add at most approximately +14.8 Crit points (including compatible Dexterity),
+9.9 Dodge points or +7 armor points across a freely mixed T6 six-slot set.
These maxima can intentionally push a same-level build to the 70% reduction
cap. Surplus rating remains useful against higher-level attackers. The
cap/demand audit evaluates all three source channels together and verifies at
least two desirable finish cells per culture.

### 6.4 Crafted quality

Base recipes produce Common gear and are universally craftable. One enchant
makes ordinary equipment Uncommon; one prefix plus one suffix makes it Rare.
There is no refinement prerequisite, bonus or separate Imbue/Temper path.
Crafted values are fixed by enchant tier, as specified in
[the current enchanting contract](crafting_equipment_revision.md#enchanting).
Found-item random windows and trinket authored specials retain their own rules.

## 6b. Enchantments

### 6b.1 Profession ownership

Apply enchantments at the owning profession station to the concrete stack.
Everyone can craft base gear; qualified professionals can apply or replace its
legal enchants. Tools are not weapons and receive no ordinary combat enchants.

### 6b.2 Fixed tier bonuses

The nine stat curves, material costs and 420 operations are defined in
[the current contract](crafting_equipment_revision.md#enchanting). Bonuses depend
on enchant tier, never a higher target tier. No extra base-damage or lifetime
multiplier exists.

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

Words are identical across tiers; the tooltip states the concrete fixed value.
Examples: *Bronze Sword of the Ox*, *Lucky Bronze Sword of the Bear*. No refined
state or marker exists.

### 6b.5 Qualification and replacement

Qualification and progression use the enchant recipe tier. Both channels are
available at every tier; mastery does not gate suffix access. Select the named
operation, inspect the exact preview, then apply it with its material cost.
Replacement preserves the other channel, wear and unrelated stack metadata.
An identical no-op is refused without cost or progress.

### 6b.6 Quality follows slot count

Zero/one/two ordinary affixes correspond to Common/Uncommon/Rare. Found-item
random windows stay separate from fixed crafted values. Trinket quality does
not alter its independently defined prefix/suffix/special structure.

### 6b.7 Special variants

No third ordinary enchant slot is included. Existing trinket specials remain.
Future cultural/PvP finishes and masterwork scope stay in WP5 and require their
own delivery; the removed refinement workflow is not a prerequisite.

## 7. Upgrade mechanics

Use the explicit named enchant replacement workflow in §6b.5. There are no
Imbue/Temper kits, random crafted application rolls or separate refinement steps.

## 8. Prices and money pacing

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
  Claim and mount Gold targets derive from those measured tier rates.
- Every mob drop has a positive `_grug_sell_price` or registered foreign-item
  override; zero means unsellable. Material values rise with tier and scarcity,
  while player trade remains their intended high-value market. Rough/Cut Gem,
  Gold, Emberglass, Abyssal Crystal, trophies and processed bars each receive
  an explicit reference value before recipes ship.
- Every craft/cook, nine-unit pack/unpack and service path passes the anti-loop
  audit: output vendor value stays below consumed-input value after discounts
  and rounding, while reversible storage shares one value budget.

### 8.2 Vendor prices and buy-back

The exact unenchanted Common slot ladder is:

| Common slot | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 25c | 65c | 1s60c | 4s | 10s | 25s |
| Chest | 20c | 50c | 1s30c | 3s20c | 8s | 20s |
| Offhand/head/legs/feet | 15c | 35c | 80c | 2s | 5s | 12s50c |

The table prices slots, not weapon families. Quality/enchanted gear costs more
than Common, but no premium may alter these baseline references. The rotating
Uncommon shelf remains a luxury source and must be priced against its final
quality multiplier before activation.

Vendor buy-back is capped at **5% of the applicable purchase or authoritative
reference price, rounded up to the next copper**. A T1 Common weapon therefore
returns 2c and a T6 weapon returns 1s25c. Same-race purchase discounts never
raise buy-back. For an item the vendor does not sell, the economy catalog
assigns a reference price and `_grug_sell_price` stores the resulting final
payout; foreign definitions use `grug_traders.set_price`. Zero means
unsellable, while every mob drop receives a positive payout.

Core supplies remain simple fixed-price goods. No profession book is sold or
replaced: the UI book reflects player-meta progression directly. Finder-item
rows are deleted; no Dowsing Rod or Gem Detector is sold or crafted.

### 8.3 Recurring sinks

- **Repair:** [durability_repair.md](durability_repair.md) is authoritative for
  eligible identities, exact wear events, non-destruction, the 3,000/6,000
  budgets, all-trainer service and the money-only 20%-of-reference-price quote.
- **Respec:** repeatable **in the talent UI, with no class trainer and no
  NPC** (ruling 4 of 2026-09-16, `skill_trees.md` §5). It costs **five
  minutes of measured reliable net solo income** at the character's bracket,
  rounded by §8.1's money axis and `economy.md` §4.1, and **the first respec
  of a character is free** (ruling 22). Retires "repeatable at the class
  trainer and rising with level".
- Job supplies, vendor consumables and profession-helper fees provide the
  ordinary steady drain.

### 8.4 Services, claims and mounts

Cultural masters charge 50% of the matching Common slot price, rounded to the
confirmed clean table. The normal same-race vendor discount does not apply:

| Cultural-master service | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 15c | 35c | 80c | 2s | 5s | 12s50c |
| Chest | 10c | 25c | 65c | 1s60c | 4s | 10s |
| Offhand/head/legs/feet | 10c | 20c | 40c | 1s | 2s50c | 6s25c |

The allied weapon-counter helper uses the weapon row. The allied Alchemist
helper charges 50% of the Warding Draught's authoritative reference price.
Both consume the player's complete physical inputs and create no regional
material.

Private housing isles, paid depth rights and the complete guild system are
retired. The first open-world Claim Stone is free after the level-20 Housing
Steward introduction. Claim geometry, placement, ownership and lifecycle are
defined by [housing.md](housing.md). Sequential upgrades consume:

| Claim upgrade | Level | Universal metal | Ledger target |
|---|---:|---:|---:|
| I → II | 35 | 4 Silversteel Bars | 30 minutes of reliable T4 net solo income |
| II → III | 50 | 8 Embersteel Bars | 90 minutes of reliable T5 net solo income |
| III → IV | 60 | 12 Abyssal Steel Bars | 3 hours of reliable T6 net solo income |

The measured copper target uses the coarsest denomination in
`1s / 25c / 5c / 1c` whose nearest multiple is within 5%; exact midpoints
round upward. If configured above one stone, the second and third require
level 60 and all existing stones at tier IV. They cost 12/24 Abyssal Steel
Bars plus 5/10 hours of reliable T6 income. Claims never consume gems,
cultural materials, foreign materials or profession-exclusive components.

Mounts at levels 15/30/45/60 target **15 minutes / 45 minutes / 2 hours /
5 hours** of reliable tier-appropriate net solo income. Their copper prices
are derived only after those rates are measured; the retired fixed
1s/8s/30s/60s table is not a fallback.

## 9. Bow and arrow item foundation

**Its consumer is delivered in Round 11**: the Scout's base kit opens
with a bow shot ([scout.md](scout.md) §2, rulings 7 and 12 of
[skill_trees.md](skill_trees.md) §5) and the arrow is **ballistic** — gravity
and a draw-time impulse, while Fireball stays straight (`combat_stats.md`
§2, `classes.md` §2b). Round 11 has delivered the registered bow, arrow and
quiver item foundation below. The Scout runtime owns draw, launch and
accepted-action hit settlement.

Item path (source: `mcl_bows`, code **LGPL 3.0 or GPL 3.0** — VoxeLibre
dual-licences every mod, `LEGAL.md:25-28`, and both are on `AGENTS.md`'s
permitted list ✓; media: **textures CC BY-SA 4.0**, sounds **two CC0** plus
**one CC BY 3.0** (`mcl_bows_hit_player.ogg`, tim.kahn) — so exactly **one**
attribution-requiring sound, not two; port ≈ 1000 lines incl.
`vl_projectile`, §1.2). The item/ammunition foundation and Scout ability
consumer are active:

- **Bow family on the weapon curve**: full-charge damage = the 1H curve
  (8/13/19/24 at ilvl 12/27/42/57) at 25 m range, charge 0.5 s (mcl
  hold-pattern), partial charge scales linearly. One bow per material tier,
  material-named like everything else (§3.0.3). Its ordinary affix pool is
  Dexterity, Crit, draw speed, HP and Mana; draw speed uses the weapon-family
  attack-speed channel to shorten charge time.
- **Arrows** stack to **200** per inventory/quiver slot (user playtest ruling
  2026-09-20); new Scouts receive 200. Ammo also has a ballistic entity;
  craft 20/batch: 1 iron bar + 4 sticks + 4 feathers (sharp feathers —
  eagle/vulture drops finally get their reagent role). The optional quiver is
  a Leatherworker Offhand item with four arrow-only slots (§3.4). The current
  Bowyer offer is 3c per arrow (2c after the same-race discount), with 1c
  buy-back; purchase remains strictly above buy-back after rounding.
- **Plain production is Basics; Woodcarver owns enchantments.** The
  Scout consumes the family in V1. The Leatherworker's Apprentice quiver is an
  optional four-stack Offhand convenience; shooting still reads `main` when no
  quiver is equipped.

## 10. Historical decision log (non-authoritative)

This section records how shipped and staged work reached the current design.
It preserves retired names and mechanisms only to explain earlier decisions.
Fresh-server mode forbids implementing compatibility for those states. **Nothing in §10 is an active target rule; §§0–9
override every conflicting statement below.**

### 10.1 2026-08-06

**P1 — Tier-4 metal.** Gem-tempered steel (steel + gems, no new ore —
uses Gem Hunter, golem drops, existing depth ores) vs a new deep ore
with mapgen registration. Recommendation: **gem-tempered steel** (zero
mapgen risk, strengthens two existing loops); a new ore can still be
added post-MVP as a T5/Unique hook.
**Decided as recommended (2026-08-06).** **Superseded 2026-08-07 by
D1**: the ladder is six tiers, the T4 metal is Silversteel from a real
new ore, and gem-tempered steel is retired. P1's own escape hatch ("a
new ore post-MVP") is what was taken, one phase earlier than expected —
the mapgen risk it was avoiding is now carried anyway for Silver, Quartz
and Garnet (§3.0.1).

**P2 — Signature-recipe asymmetry.** Troll harness (top leather) and
Human flask have no cross-faction stat mirror (6 races on 4 crafting
professions). Recommendation: **accept for the MVP** (leather is not
worn by MVP classes' endgame sets; the flask is consumable, not
permanent power) and add mirrored recipes in Phase 2 when the Rogue
makes top leather PvP-relevant.
**Decided as recommended (2026-08-06), then superseded 2026-09-16.** The
Scout replaces the separate Rogue, wears leather in V1 and does not introduce
poison; no Phase-2 Rogue mirror is current scope.

**P3 — Potion/elixir/food exclusivity.** Healing and mana potions share one
60 s cooldown. One active elixir and one food restore buff may coexist with
that cooldown and with each other. The most recent food replaces the previous
food; it never occupies the instant-potion slot. **Decided 2026-08-06;
food rule replaced by R9 on 2026-09-17 and Food v2 on 2026-09-18.**

**P4 — Swiftness Draught.** The original +8% for 15 s was replaced on
**2026-09-18** by **+10% for 5 s**. At the ordinary 4.0 player speed this is
4.4 nodes/s, still below the aggressive mob band's 4.6. The PvP half of the
flag is untouched — a draught still does nothing
about another player at 4.0.

### 10.2 2026-08-07 (crafting rework)

**D1 — Two ladders, not one.** The four mastery tiers and a six-tier
material ladder were read as a 4-vs-6 conflict. **Both stay, they mean
different things**: mastery is a property of the crafter (enchant slots +
exclusive recipes), T1–T6 is a property of the item (materials, level
bands, who may wear what). The mastery table's "item levels" column is
identical to §6.3's four roll bands — one set of boundaries, two names.
`T<n>` from now on always means a material tier; mastery tiers are always
written by name (§2.1).

**D2 — One item per concept.** Binding. The vendor bracket catalog and
the base craft ladder are **the same, material-named items**, and
`default`'s tool ladder is replaced rather than supplemented. Everyone
crafts the base items of every tier; what a profession adds is
refinement, affixes, special variants and a few exclusive recipes. The
72 shipped `grug_gear` items are renamed and merged, and the mese and
diamond tool tiers are deleted (§3.0.3). Rejected alternative: letting
`default`'s ladder stand next to a bracket ladder — two items per
concept, and no player would ever be able to tell which one to make.

**D3 — Seven professions, cut by material.** Weaponsmith, Armorsmith,
Leatherworker, Tailor, Woodcarver, Goldsmith and Alchemist. Herbalism merges
into the Alchemist, Gem Hunter into the Goldsmith; all seven are symmetric with four
mastery tiers. Cutting by class was rejected: it breaks the moment
Phase 2 adds four classes, and a material profession serving several
classes is what keeps the supply chain social (professions.md §2/§4).

**D4 — One UI recipe book per profession, groups instead of a chain
(revised 2026-09-18).** The LotT tome chain and authored keystones are
retired. A learned profession exposes its complete catalog; profession level
controls crafting permission while locked rows remain visible. Quest and boss
recipes land in the same book, and universal base recipes remain in the
Basics book (§2.2/§2.3).

**D5 — Refinement is the profession's product.** The 2026-08-07 form used
+15 % base damage or armor and +100 % durability; only refined items could be
enchanted; affixes were 2 prefixes + 2 suffixes, with mastery filling the four.
**Superseded 2026-09-20:** ordinary gear now has one prefix and one suffix,
and Expert/Master temper values rather than adding slots (§0, §6b.5). The
15 % refinement and doubled durability remain. 15 % was chosen against 25 % because a refined tier-n
item must not beat an unrefined tier-n+1 item — §3.8 shows it holds at
every step of the ladder. The refinement word drops out of the name once
an affix is present, since only refined items can carry one (§6b).

**D6 — Cooking gets a book, but not a profession slot.** Cooking and
First Aid stay free and universal. Cooking's tiers are tied to regional
ingredients (T6 needs level-50+ ingredients) and are wanted as quest
goals, which needs a group structure; First Aid does not and keeps none
(§2.3, §3.7).

### 10.3 2026-08-08

**D7 — Trinkets ship in the MVP** (resolves `TODO-design-crafting-rework.md`
C11). The two slots stop being reserved (`inventory_equipment.md` §2) and
the Goldsmith's headline product becomes real content instead of a
promise (§3.6b). It was the cheapest missing family in the game — the
slots, their meta and their `allow_put` shipped with WP15, and trinkets
need no model, no armor class and no rank binding. Rejected: shipping
the Goldsmith as a pure supplier profession, which left one of six
professions with no wearable output of its own.

**D8 — The enchant roll band follows the ITEM, not the crafter.** §6.3's
four bands are picked by the item's **ilvl**; the crafter's mastery
decides only which affix/value operation is available (§6b.5). D1 had left
the sentence readable both ways ("read as a crafter … read as an item"),
and the two readings diverge, because mastery follows the *character's
level* while ilvl follows the *item's material tier*. The crafter
reading broke two things at once: a level-50 Master's T1 Bronze Sword
(ilvl 3) would have carried band-4 rolls, violating "a T2 enchant cannot
be applied to a T1 item"; and **mob drops have no crafter at all**, while
§5 sets gear-drop ilvl = min(mob level, 60) and sends the roller to §6.3. That
the band boundaries coincide with the four mastery level anchors is a
property of the numbers, not a rule. Rejected: two roll tables, one for
crafted and one for dropped gear — the same ilvl would then have meant
two different items.

**D10 — A higher-tier pick digs faster, not only deeper.** §3.0.4
documented the `maxlevel` *gate* thoroughly but never stated the other
half of the tool ladder: each tier's pick digs its own stratum, and
every stratum above it, faster than the tier below. The gate is
**access**, the `times` are the **reward**. In the legacy model,
**effective** values matter because `maxlevel` silently rescales both `uses`
and dig `times` through `leveldiff`, which is the trap WP25 already hit from
the durability side.

**D11 — Trinkets get their own §6.2 pool row, and the cap check is re-run
for 8 slots** (resolves the trinket half of A3). Pool: **+Str, +Int,
+Dex, +HP, +mana, +crit%** — universal-ish because every class wears
both slots, and deliberately without +armor%, +dodge% and +attack
speed%, which are the identity of the armor and melee-weapon rows.
Consequence, stated rather than discovered later: the §6.3 worst case
for crit rises from ≈ 30 % on 6 slots to ≈ 36 % on 8 and now **clamps**
against the 30 % cap of `combat_stats.md` §2 instead of landing on it.
Dodge (≈ 19 %) was untouched by that decision because trinkets roll neither.
The referenced 60% armor cap was later superseded by Round 11's attacker-level
rating formula and universal 70% reduction cap.

**D12 — There is no poison stat** (resolves the poison half of A2).
§6b.4's *of the snake* (+poison) was an off-hand example, not a
decision: poison appears in no §6.2 pool, no §6.3 row and nowhere in
`combat_stats.md`. The example is now *of the cat* (+dodge), and poison
was then booked as the **Rogue's signature damage type for Phase 2**. That
plan is superseded by the Scout, which has no poison in V1 (`classes.md` §6;
`scout.md` §1). Poison as a *mob* effect (the serpent, and the
Alchemist's Antivenom that cures it) is unaffected — that is a mob verb,
not a player stat.

**D13 — Six strata, five new nodes** (resolves `TODO-design-crafting-rework.md`
B7). `default:stone` stays the T1 stratum, the five below it are new
`grug_materials` nodes placed as `stratum` ores registered last, so cave
walls inherit their tier and a deep cave stops being a free bypass; every
stratum drops cobble and the tool ladder is re-parameterised to six
`maxlevel` steps via `core.override_item` (§3.0.4). Rejected: a separate
T1 node (drags mapgen filler, cobble and every `wherein` behind it), a
`grug_mapgen` y-band VoxelManip pass (misses the cave walls the ore pass
gets for free) and reusing `default`'s stone family, which already
carries biome meaning.

**D14 — Ore bands follow the tool, ore `level` follows the rock**
(resolves B8). Lead metals lie one band above their own tier, gems in
their own band, and an ore node carries the `level` of the band it lies
in rather than of its tier (§3.0.1). The second half closes the cave leak
without deadlocking the first. Iron gains a −1 … −100 band because
vendored iron starts at −128, below the stratum that demands an iron
pick.

**D15 — Abyssal Crystal gets a continental band in the T5 rock** (resolves
`TODO-design-depth.md` C7 and reverses the half of D14 that had written
"no continental deposit at all"). `clust_scarcity = 20³`,
`clust_num_ores = 2`, `clust_size = 2`, band −701 … −1000 (§3.0.1) —
by volume the scarcest entry in the placement table by a wide margin.
The band is the T5 one, not the deep one, because §3.0.1's binding rule
puts a lead metal one band above its own tier — below −1000 the T6 pick
would have been needed to mine the material the T6 pick is made of. This
records the shipped WP25 legacy placement only; the target natural-depth and
harvest-tier rules in §3.0.1/§3.0.4 supersede its engine-level mechanism and
WP43 owns the migration.

**D16 — The depth gets no drop layer of its own** (resolves the loot half
of `TODO-design-depth.md` D10). Underground mobs drop what their families
drop on the surface; being deep adds nothing (§5). A T6 gear layer down
there would have been a third top source — beside crafted-masterwork
0.60–1.00 and boss 0.80–1.00 — with neither a crafter nor a boss behind it, against §0's promise that the best items
come from crafting and hard bosses — and the band already pays the
endgame *material* that the crafted endgame item is made of. Rejected:
T6 gear drops on the level-60 deep roster.
