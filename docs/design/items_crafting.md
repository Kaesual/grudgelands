# Items, Crafting & Loot — Full Design Spec

**Decided spec** (authored + approved 2026-08-06; the five flagged
points P1–P5 were all decided per recommendation — resolutions in §10).

**Reworked 2026-08-07** (crafting rework session): the material ladder is
now six tiers (§3.0), the tome chain is replaced by one recipe book per
profession (§2.2), professions **refine and enchant** instead of owning
the item catalog (§3.3–§3.6b, §6b), and there is **exactly one item per
concept** — the vendor bracket catalog and the base craft ladder are the
same, material-named items (§3.0.3). Resolutions in §10.

**World-zone revision 2026-08-10.** Surface progression is now keyed by the
stable named zones and level bands in `world_zones.md`, not by WP18's radial
ring names. Any surviving ring wording below describes shipped calibration;
WP40 must translate placement to the named-zone catalog without changing the
item, tier, depth or economy rules.

Feeds: WP5 (loot/enchant rolls), WP7 (traders/consumables), WP10
(professions/workbenches), WP22 (repair). Crafting mechanics frame:
`inventory_equipment.md` §4 (3×3 grid, multi-stage, craft_predict
unlock gate, workbench proximity, recipe book UI) — unchanged here.

**Notation (binding, 2026-08-07).** `T1`–`T6` **always** means a *gear /
material* tier (§3.0). The four **mastery** tiers are **always written by
name** — Apprentice, Journeyman, Expert, Master — never as "T4". The two
ladders are independent; §2.1 spells out how they meet.

## 0. Decided anchors (2026-08-06, binding — preserved)

- **Quality tiers: Common (white), Uncommon (blue), Rare (yellow),
  Unique (orange)**. MVP ships without Uniques, but quality field +
  enchant list live in item meta from day one.
- **Uncommon = 1–2 weak enchantments; Rare = 3–4 enchantments.**
- Vendors sell simple (Common) gear — available but painfully expensive;
  better gear comes from **crafting** or **special bosses**. *Sharpened
  2026-08-07*: "crafting" means **refinement + enchanting** (§6b) — the
  plain base item is the same item the vendor sells (§3.0.3).
- Items are **upgradeable via crafting within limits**: an upgraded
  mediocre item never becomes a top item. No upgrade failure chance.
- **The harder the enemy, the better the loot** — boss/elite multipliers
  act on the enchant roll ranges, same mechanic everywhere.
- **Rare patrol mobs** with special loot as raid incentive into enemy
  territory; the faction **King** is a heavily guarded raid boss with
  top-tier rolls.
- **Class/profession synergy intended** (Warrior+Blacksmith,
  Priest/Mage+Tailor, …).
- Housing depth treasures (limited gems) are high-end ingredients.
- Race-exclusive recipes exist (world.md §7) — concretized in §4.
- Material tiers mirror WoW: vendor supplies (thread/flux/vials) as
  small gold sink; world materials tiered by source level; workbenches
  uncraftable, capitals/villages only; bags are Tailor products.
- Vendor floor rule: vendors sell only the LOWEST tier per category
  (professions.md §4, economy.md §1).
- **One item per concept** (decided 2026-08-07, binding): no two items
  may fill the same role. The vendor bracket catalog *is* the base craft
  ladder, and both are material-named (§3.0.3).
- **Everyone crafts the base items of every material tier**; professions
  refine and enchant them and hold a few exclusive recipes per mastery
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
- **One porting change** (decided 2026-08-07): our T6 alloy has **three**
  inputs (§3.0.2), LotT's `check_craft` matches exactly two. The port
  widens the `input` list and the matcher to **3** slots. Nothing else in
  the node changes.

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
Ours (§4) is a deliberate tightening — hard on the *crafter* (race in
player meta checked in craft_predict) and free on the *wearer* — that
is what makes race+profession combos tradeable.

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
  HP-tick timers, damage modifiers; persisted in player meta. Template
  for our elixir/buff engine (WP7).
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

**One mechanism only: the recipe book. No skill-up grind, no per-recipe
unlocks.** (Skill-ups were considered and rejected: a second progression
currency that fights the 10–20 h pace; the book already gates by zone
materials, which IS the level gate.)

### 2.1 The two ladders (mastery vs. gear) — made explicit 2026-08-07

There are **two independent ladders**. They are not alternatives; both
stay, and they never mean the same thing.

**Ladder 1 — mastery** (this table, unchanged since 2026-08-06). Four
tiers, one per quarter of the level curve. Mastery is a property of the
*crafter*.

| Tier | Name | Item levels | Learn at ~char level | Ring that feeds it |
|---|---|---|---|---|
| 1 | Apprentice | 1–15 | 1 (trainer) | safe core + inner |
| 2 | Journeyman | 16–30 | ~15–18 | inner (+depth mining) |
| 3 | Expert | 31–45 | ~30–33 | outer |
| 4 | Master | 46–60 | ~46–50 | coast + named rares |

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
2. **Mastery decides how many enchant slots a crafter can fill** —
   Apprentice 1, Journeyman 2, Expert 3, Master 4 (§6b.5). It does *not*
   decide which material tier you may touch; that is the gear ladder and
   the digging-depth gate (§3.0.4).
3. **Mastery additionally brings a few profession-exclusive recipes per
   tier** (§3.3–§3.6b). Everything else a profession makes is a
   refinement of a base item everybody can craft (§3.0.3).

Learning a mastery tier unlocks its exclusive recipes and raises the
fillable slot count. Learning a **book group** (below) unlocks a material
tier's recipes. The two unlocks are separate and both are needed.

### 2.2 The recipe book — one per profession (replaces the tome chain 2026-08-07)

**The LotT-style tome chain is retired.** Each better tome consuming the
previous one produced four near-identical items per profession — 24 in
all — whose only job was to be each other's ingredient, and it forced the
recipe catalog to be cut by mastery tier when what it actually needed to
be cut by is material tier. Replaced by **exactly one book per
profession**, internally grouped.

Item: `grug_items:book_<prof>` ("Book of Smithing"), tool, stack_max 1,
**one per profession, for the whole game**.

- **Right-click = browse**: opens the recipe book UI (LotT's
  group-filtered guide-viewer role, §1.1) filtered to that profession.
  Never consumed.
- **Six groups, T1–T6** — the gear/material tiers of §3.0, in one list.
- **Level controls visibility, the keystone controls the unlock.** A
  group becomes *visible* when the character reaches the first level of
  its band (§3.0: T3 at level 21), and it is shown **greyed with its
  keystone requirement spelled out** — a Blacksmith at 21 reads
  "requires: 6 steel bars + 2 stone cores". Redeeming the keystone once
  (§2.3) opens the group permanently. This is why keystones survive the
  rework: a pure level gate would lose the **zone** requirement, and
  obtaining materials from the appropriate named source region is what the
  keystone actually proves.
- **Unlock state lives in player meta**, not in the item: `grug_prof:
  <prof>` holds the highest opened group (idempotent writes). The book
  is interface, never progression storage.
- **Quest and boss recipes unlock inside the same book** — race
  signatures (§4), masterworks (§6.4) and any future quest reward appear
  in the group of their own material tier once earned. There is **no
  second book** and no separate unique-recipe list.
- **A player can craft only what is in their books, plus the universal
  base recipes** (§3.0.3). That is the whole craft permission model:
  base ladder for everyone, book contents for the two mains.
- **Books are tradeable**, and worth exactly one purchase: a lost book is
  re-bought from the job trainer for the same 25c (§8.2) and immediately
  shows everything the meta says you have opened.
- Unlearning a profession (switch at trainer, professions.md §1) wipes
  the meta key — progression of the dropped profession is lost (as
  decided); the book in your inventory becomes unreadable paper for you.
- **Cooking has a book too** (§3.7) — same six groups, same level gates.
  This overrides the old "Cooking and First Aid have no tomes" line in
  §2.3.

### 2.3 Tier keystones (the zone gate — materials, exact)

**Reframed 2026-08-07.** The keystone is no longer a tome *ingredient*;
it is the **redemption token that opens a group in the book** (§2.2). The
materials are unchanged — they were always chosen as proof that the
player has reached the region that produces them, and that is exactly the
job the new model needs them for. Redemption is a one-off action at the
profession's workbench; the materials are consumed, nothing is produced,
the meta key advances.

Columns are **book groups**, i.e. gear tiers (§3.0):

| Profession | T2 group | T3 group | T4 group |
|---|---|---|---|
| Blacksmith | 6 iron bar | 6 steel bar + 2 stone core | 3 gem + 1 `group:grug_rare_trophy` |
| Leatherworker | 6 cured leather | 6 heavy leather + 2 bear claw | 6 scaled hide + 1 rare trophy |
| Tailor | 6 woven bolt | 6 heavy bolt + 4 spider silk | 6 silkweave bolt + 1 rare trophy |
| Alchemist | 8 sunleaf + 8 gravemoss | 8 dragonweed + 2 venom gland | 8 crimson lotus + 4 stormkelp + 1 rare trophy |
| Woodcarver | — (`TODO-design-crafting-rework`) | — | — |
| Goldsmith | — (`TODO-design-crafting-rework`) | — | — |

- **T1 opens with the profession** — no keystone; it is the tier every
  player already crafts from (§3.0.3).
- **T5 and T6 keystones** follow the same shape at their own tier's
  materials and are listed with the signature recipes in
  `TODO-design-crafting-rework.md`. The *rule* is decided; the two lists
  are not yet authored.
- The **Herbalism and Gem Hunter rows are deleted** (2026-08-07):
  Herbalism merged into the Alchemist, Gem Hunter into the Goldsmith
  (professions.md §2), so the asymmetric "3 tiers"/"2 tiers" stubs have
  no owner. Their mechanics survive inside the merged professions —
  herb gathering is an Alchemist ability (§3.6), the mining bonus gem
  chance and the Gem Detector are Goldsmith (§3.6b).

`group:grug_rare_trophy` = the signature drop any **named rare** carries
(§5.4) — every named rare on your own continent qualifies; both
factions always have sources (biomes_mobs §3.3 lists ≥4 per continent).

**Cooking and First Aid stay free and universal** — the trainer teaches
them at no main-profession cost (professions.md §1). *Revised
2026-08-07*: **Cooking now has a recipe book** with the same six groups
and level gates (§2.2, §3.7), because its tiers are tied to regional
ingredients and want to be quest goals. Its groups take **no keystone** —
the ingredient itself is the gate. **First Aid keeps no book at all**:
all recipes at once, materials are the only gate.

### 2.4 Pacing check (10–20 h to level 60)

~10–20 min per level → progression milestones land at: L15 after ~2.5–5 h,
L30 after ~5–10 h, L45 after ~7.5–15 h. Each keystone is ~30–60 min of
natural play in the source region you just reached (6 iron bars ≈ one dig to
y −300 or a golem hunt; 2 bear claws ≈ 8 bear kills at 1/4). A player
who levels two professions alongside questing reaches Master at 50–55
without detour grinding; a pure fighter buys refined and enchanted gear
from crafters instead — both paths inside the 10–20 h envelope.
**Intended gear cadence: a visible upgrade every 45–90 min** (quest
rewards + 3% world drops between the six material tiers, §3.0),
and at 60 the professions stay load-bearing via repair (§8), consumables
(elixirs/bandages/potions), upgrade kits (§7), masterworks and race
signatures (§4).

## 3. Materials, curves and the profession catalogs

Multi-stage everywhere (decided): ore → bar → component → item; hide →
cured leather; cloth → bolt. Stages are base recipes (grid anywhere);
the final item needs the workbench nearby.

Reading order: **§3.0** the material ladder and the one-item-per-concept
rule, **§3.1/§3.2** the armor and weapon curves every item is generated
from, **§3.3–§3.6b** the six profession catalogs, **§3.7** the universal
secondaries, **§3.8** the vendor brackets.

### 3.0 The material ladder (decided 2026-08-07)

Six tiers, one per ten character levels. This is gear ladder 2 of §2.1;
the level bands and ilvl anchors are the §3.8 vendor brackets verbatim,
because under §3.0.3 they are the same items.

#### 3.0.1 The ore table

| Tier | Levels | ilvl | Lead metal | Ore node | Digging depth | Gem |
|---|---|---|---|---|---|---|
| T1 | 1–10 | 3 | **Bronze** | Copper, Tin (exist) | 0 … −100 | — |
| T2 | 11–20 | 10 | **Iron** | Iron (exists) | −100 … −300 | **Quartz** (new, common) |
| T3 | 21–30 | 20 | **Steel** | — (alloy) | −300 … −500 | — |
| T4 | 31–40 | 30 | **Silversteel** | **Silver (new)** | −500 … −700 | **Garnet** (new) |
| T5 | 41–50 | 40 | **Embersteel** | **Emberstone** (repurposed mese) | −700 … −1000 | — |
| T6 | 51–60 | 50 | **Grudgesteel** | Abyssal Crystal (T5 band + §5.5) | below −1000 (`world.md` §4c) | **Diamond** (exists) |

- **Wood and stone are the pre-metal T1 floor** — the starter kit and the
  vendor floor. T1 therefore spans wood / stone / bronze. Wood and stone
  keep the stats `default` ships and sit **below the ilvl anchors**: they
  carry no level requirement, and they are the one rung that is not
  generated from the §3.1/§3.2 curves.
- **Gold is no longer a tool metal.** It becomes the **jewelry** material
  — the Goldsmith, the two trinket slots (§3.6b) — plus the gem-hunting
  bonus. No gold weapon, no gold armor, no gold pick.
- **The mese tool tier is retired**, and so is the diamond tool tier.
  The mese **ore node** is repurposed as **Emberstone**, a glowing yellow
  crystal — the existing `default` texture already reads that way. Both
  vendored tool ladders above steel are deleted (§3.0.3).
- **Diamond is a gem, not a tool material.**
- **New ore nodes to create: Silver, Quartz, Garnet.** Everything else
  exists in the vendored `default` (copper, tin, iron, coal, mese →
  Emberstone, diamond) or is already sketched as the abyssal gem of
  §5.5, now named **Abyssal Crystal**.
- **Abyssal Crystal is a base resource, not a privilege** (decided
  2026-08-08, reversing the same day's earlier "no continental deposit at
  all"). It gets a **continental deposit**, because a material the whole
  T6 ladder depends on must not sit behind a 1.9 g purchase. It stays a
  housing treasure too (§5.5) and keeps the 10 % apex-hoard bridge (§10
  P5); what changes is that **Grudgesteel no longer needs the level-30
  isle grant**. The isle keeps its own reason to exist through its six
  exclusive materials (`world.md` §5.4) instead of by holding the T6
  alloy hostage. The node is `grug_materials:abyssal_crystal_ore`
  (`level = 4`, i.e. the Emberrock around it) dropping
  `grug_materials:abyssal_crystal`; WP25 registered both and placed
  neither, so the band below is the first thing that places it.
- **The continental band is the T5 band, not the deep one — and that is
  the binding rule, not a preference.** A lead metal lies one band
  *above* its own tier (the rule at the end of this section), so Abyssal
  Crystal sits in **−701 … −1000**, the Emberrock the T5 pick opens, and
  the ore node carries `level = 4` to match the rock around it. Putting
  it below −1000 instead would have closed the ladder into a circle: T6
  rock needs a Grudgesteel pick, Grudgesteel needs Abyssal Crystal, and
  the tier would have been reachable only through the 10 % apex-hoard
  drop. The hoard therefore stays what §10 P5 always called it — a
  **bridge**, not the door. The isle's step 6 is unaffected: it holds
  crystal too, and there the depth payment is the point.
- **The "Digging depth" column is a *tool* depth, not a find depth.** It
  names the band that this tier's own pick unlocks (§3.0.4), not the band
  its material lies in. Where the ores actually sit is the placement
  table below.
- **The T6 row's band is also endgame content territory.** Everything
  below −1000 needs a T6 tool, which makes it the one part of the world
  gated by the top of this very table — so `world.md` §4c gives it a
  role beyond its ores: dangerous underground environments (lava lakes)
  with a level-appropriate creature roster. The T6 row therefore buys a
  *place*, not only a metal.
- **Binding: a lead metal lies one band *above* its own tier, a gem lies
  in its own band.** Otherwise a tier-n tool would be needed to reach the
  material a tier-n tool is made of. Iron (T2 metal) is mined in the T1
  band, Silver (T4) in the T3 band, Emberstone (T5) in the T4 band; the
  gems Quartz, Garnet and Diamond sit in the T2, T4 and T6 bands they
  belong to, and a gem is always reachable by the pick of its own tier.

Ore placement (decided 2026-08-08). `clust_scarcity` is the
`register_ore` volume, i.e. one cluster per that many nodes:

| Ore | Role | Band (y) | `clust_scarcity` | `clust_num_ores` | `clust_size` |
|---|---|---|---|---|---|
| Iron (new shallow band) | T2 metal | −1 … −100 | 10³ | 5 | 3 |
| Quartz | T2 gem | −101 … −300 | 8³ | 6 | 3 |
| Silver | T4 metal | −301 … −500 | 9³ | 5 | 3 |
| Garnet | T4 gem | −501 … −700 | 10³ | 4 | 3 |
| Emberstone | T5 metal | −501 … −700 | 12³ | 4 | 3 |
| Emberstone (deep) | T5 metal | −701 … −31000 | 14³ | 5 | 3 |
| Diamond | T6 gem | −1001 … −31000 | 15³ | 4 | 3 |
| Abyssal Crystal | T6 material | −701 … −1000 | 20³ | 2 | 2 |

- Copper, tin, coal and gold keep their vendored `default` placement
  unchanged.
- The three new ore nodes are `grug_materials:stone_with_quartz`,
  `:stone_with_silver` and `:stone_with_garnet`, dropping
  `grug_materials:quartz_crystal`, `:silver_lump` and `:garnet_crystal`.
  Emberstone stays the vendored `default:stone_with_mese` (renamed, not
  re-registered) and Diamond stays `default:stone_with_diamond`. WP26's
  alloy recipes consume exactly these names.
- **Abyssal Crystal is deliberately the scarcest thing in the table** —
  by volume roughly a quarter of Diamond's, and its clusters are half the
  size of everything else's. It is the one material whose scarcity
  decides how fast the endgame alloy can move at all, and it sits in the
  band that carries the deepest phase-in pressure a T5 character can
  stand in (`biomes_mobs.md` §4.1), so what it really costs is time under
  fire. Re-tune it against §2.4 after the first runtime test rather than
  on paper (same pattern as the calibration line below).
- **The iron band is a deadlock fix, not tuning.** Vendored iron starts
  at −128, i.e. *below* the T2 stratum that already demands an iron or
  steel pick. Without an iron deposit above −100 the ladder is blocked
  shut at T2.
- **Calibration** ("reagent calibration"): Quartz at iron's density,
  Garnet just under copper's, Silver denser than Garnet — because §6.4
  makes one cut gem the cost of *every* fine recipe, a gem is a reagent,
  not a rarity. Re-tune against §2.4 after the first runtime test rather
  than deriving it on paper (pattern:
  `docs/research/wp6_spawn_budget.md`). The numbers in the table are the
  decision; this line only names the intent.
- **There is no natural Mese-block deposit any more.** minetest_game
  scatters `default:mese` (the *block*) as an ore below −2048; WP25
  removed those rows. The block carries `level = 2` upstream, so it sat
  inside the T6 band while a steel pick could still break it, and one
  block yields nine Emberstone crystals — the T5 lead material, handed
  out at T3 tooling. The Emberstone source is the *ore* node
  `default:stone_with_mese`; the craftable block is untouched (raising
  its `level` was rejected — it is a placeable building block, and a
  level-5 block would lock out the player who placed it).
- **An ore node carries the `level` of the band it lies in, not of its
  own tier** — an ore is exactly as hard as the rock around it. This
  closes the cave leak (a cave at −600 would otherwise expose Silver to
  any bronze pick) without creating a deadlock: Silver is a T4 metal but
  lies in the T3 band, carries `level = 2` and is therefore the steel
  pick's prey, exactly as intended. Concretely: Quartz `level = 1`,
  Silver `2`, Garnet `3`, Emberstone (`default:stone_with_mese`) `3`,
  Diamond `5`, Abyssal Crystal `4`. Copper, tin, coal, iron and gold get **no** `level` — they are not
  gate-relevant and the rock around them is the gate. **An ore may never
  carry a higher `level` than the stratum it lies in.**

#### 3.0.2 Alloys and the two-slot furnace

Two smelting nodes. The **normal furnace** does single-input smelting;
the **dual furnace** (ported from LotT, §1.1) does two-input alloys.

| Output | Recipe | Node |
|---|---|---|
| Bronze bar | Copper + Tin | dual furnace |
| Iron bar | Iron lump | normal furnace |
| Steel bar | 1 iron bar, ~2 coal of fuel | normal furnace |
| Silversteel bar | Steel + Silver | dual furnace |
| Embersteel bar | Silversteel + Emberstone | dual furnace |
| Grudgesteel bar | Embersteel + Abyssal Crystal + 1 `group:grug_rare_trophy` | dual furnace (3-input port, §1.1) |

The T6 bar is the only three-input recipe in the game, and the trophy
slot is deliberate: Grudgesteel cannot be farmed, it is spent from the
same named-rare drop that opens the T4 book group (§2.3, §5.2).

#### 3.0.3 One item per concept — NO duplicates (binding)

**There is exactly one item per concept.** No two items may fill the same
role: there is no `default` stone sword standing next to a "Crude Sword"
from `grug_gear`. Consequences, all binding:

- **The vendor bracket catalog and the base craft ladder are the same
  items**, and they are **material-named** — Bronze Sword, Iron
  Chestplate, Steel Greaves — never bracket-named. The 72 items WP7
  shipped under the adjectives *Crude / Plain / Tempered / Reinforced /
  Superior / Grand* merge into that one ladder. That is a **rename plus a
  merge with the tool ladder — planned work, not a defect**; the
  generator, the six bracket catalogs, the prices and the ilvl anchors of
  §3.8/§8.2 are untouched by it.
- **Everyone can craft the base items of every material tier** — tools,
  weapons, armor. This is the deliberate "Minecraft feel", and it is what
  makes mining and smelting worth doing for a player with no crafting
  profession at all.
  **This supersedes §3.3's** "vendor floor sells up to the bronze pick —
  iron+ picks are smith products" (see the marked line there).
- **`default`'s tool ladder is replaced** by the six-tier ladder: wood
  and stone stay, bronze/iron/steel/silversteel/embersteel/grudgesteel
  replace the rest, and the **mese and diamond tool tiers are deleted**
  (that is `pick`/`shovel`/`axe`/`sword` × mese, diamond in
  `mods/BASE/default/tools.lua` — twelve registrations to drop, plus
  their craft recipes).
- **Armor base recipes must be created.** `default` has **no armor at
  all**. Shapes adapted from LotT `lottarmor` (closer fit) or VoxeLibre
  `mcl_armor` — sources and licences in §1.2 — with our bar costs from
  §3.3.
- A profession never gets a *parallel* item. What a profession adds on
  top of the base item is the **refinement, the enchant and the special
  variant** (§6b), plus its handful of exclusive recipes.

#### 3.0.4 Depth gating: rock strata need a tool of their tier

The rock **below each tier's depth boundary can only be broken by a tool
of that tier**. This — not a level check — is what gates metal
availability by character level, and it is identical on the continent and
on the housing isles (world.md §5).

Engine mechanism, verified in `reference_projects/luanti/doc/lua_api.md`:
the stratum node carries a **`level` group**, the tool declares
**`groupcaps.<dig group>.maxlevel`**. Per `lua_api.md:2715-2731`, the
usable-uses count is multiplied by `3^leveldiff` where `leveldiff` is the
tool's `maxlevel` minus the node's `level`, and **"the node cannot be dug
if `leveldiff` is less than zero"** (`lua_api.md:2722`); the worked
example at `lua_api.md:2806` states it outright — *"At `level > 2`, the
node is not diggable, because it's `level > maxlevel`."* The gate is
therefore a hard engine refusal, not a slow dig, which is what we want.

The vendored `default` already uses the mechanism in both directions —
its tools declare `maxlevel` 1/1/2/2/3/3 up the ladder
(`mods/BASE/default/tools.lua`) and its hardest nodes carry
`groups = {cracky = 1, level = 2}` — so the six strata are a
re-parameterisation of a live system, not new engine work.

Six strata, one per tier — but only **five new nodes**, because
**`default:stone` *is* the T1 stratum** (`level` 0, unchanged). It is the
mapgen filler, the cobble source, the `wherein` of every ore
registration and an ingredient in several recipes; a separate T1 node
would have had to drag all of that along for no gain.

| Tier | Band (y, inclusive) | Node | Description | `level` | Texture |
|---|---|---|---|---|---|
| T1 | ≥ −100 | `default:stone` | Stone | 0 | unchanged |
| T2 | −101 … −300 | `grug_materials:slate` | Slate | 1 | `default_stone.png^[colorize:#4a5a6e:70` |
| T3 | −301 … −500 | `grug_materials:basalt` | Basalt | 2 | `default_stone.png^[colorize:#2a2a2e:90` |
| T4 | −501 … −700 | `grug_materials:granite` | Granite | 3 | `default_stone.png^[colorize:#8a5a52:60` |
| T5 | −701 … −1000 | `grug_materials:emberrock` | Emberrock | 4 | `default_stone.png^[colorize:#7a2a10:90` |
| T6 | −1001 … −31000 | `grug_materials:abyssal_rock` | Abyssal Rock | 5 | `default_stone.png^[colorize:#241830:150` |

- **Naming**: real rock up to T4, flavour for T5/T6 — the two deepest
  strata are named after the resource that lives in them (Emberstone T5,
  Abyssal Crystal T6), so a player can read the tier off the wall.
- **Textures** are engine texture modifiers (`^[colorize`) on
  `default_stone.png`, no own art. Hand-made 16px textures stay Phase-3
  work.
- **Every stratum drops `default:cobble`.** The gate is *access*, not
  building material (`world.md` §2).
- **Placement**: five `core.register_ore{ore_type = "stratum",
  clust_scarcity = 1, wherein = "default:stone"}` without noise
  parameters, registered **last of all ores**. In mgv7 ores run after
  cave generation and before the dungeons
  (`mapgen_v7.cpp:335/355/359`), and registration order is placement
  order.
- **Cave walls inherit their stratum** — they fall out of that order for
  free, and that was the actual question: otherwise every deep cave
  would be a free bypass for a level-10 player.
- **Group `grug_stratum = <tier>`** on every stratum as the dispatch
  group. `stone = 1` is deliberately absent: `default:furnace` and the
  stone-tool recipes take `group:stone`, and an abyssal-rock wall must
  not be furnace material.
- **`cracky = 3` on all six** — the gate is the hard refusal via `level`,
  not a slower dig.
- **Isles**: the same ladder applies on the housing isles (`world.md`
  §5.3). The stratum node for a depth is obtained through
  `grug_materials.stratum_node_for(y)`; that is the interface WP24's isle
  generator uses, because a VoxelManip pass does not get the strata for
  free (`register_ore` only runs in the mapgen).

Six `level` steps need six `groupcaps.cracky.maxlevel` thresholds and
`default` ships only three, so the vendored picks are re-parameterised
via `core.override_item` (`default` stays unpatched, VENDOR.md). Picks
only — strata are `cracky` and nothing else.

| Tool | `maxlevel` | Role |
|---|---|---|
| `default:pick_wood` | 0 | T1 |
| `default:pick_stone` | 0 | T1 |
| `default:pick_bronze` | 0 | T1 (bronze *is* T1) |
| `default:pick_steel` | 2 | T3, unchanged |
| `default:pick_mese` | 4 | temporary test bridge |
| `default:pick_diamond` | 5 | temporary test bridge |

- **`uses` and `times` are compensated with the `maxlevel` change.**
  `maxlevel` is not only the gate: the engine derives
  `leveldiff = maxlevel − node level` and feeds it into two more
  formulas — `real_uses = uses · 3^leveldiff` and, for
  `leveldiff > 1`, `time = time / leveldiff` (`src/tool.cpp:394-414`).
  Lowering a `maxlevel` therefore silently shreds durability and dig
  speed. The three lowered picks get their `uses` and dig `times`
  re-scaled so their **effective** values against ordinary level-0 rock
  are exactly the pre-WP25 ones: wood `uses` 10 → 30, stone 20 → 60,
  bronze 20 → 180 with all three `times` halved (bronze alone had
  `leveldiff = 2` before and thus the time division). This is a
  re-parameterisation of the *gate*, not a nerf of the starter tools.
- The mese and diamond picks are **deliberately not compensated**: their
  `maxlevel` goes *up*, which makes them 3× resp. 9× more durable and
  faster against level-0 rock. They are test bridges, not game items
  (see below), so those numbers state nothing about balance and must not
  seed a wear-budget check (§8.3).
- Accepted side effect: bronze no longer breaks default's `level = 2`
  nodes — obsidian and its two variants, the steel/copper/tin/bronze
  blocks and the mese block, plus the `stairs` registrations of all of
  those. Steel still breaks every one of them.
  `default:diamondblock` (`level = 3`) was already out of bronze's reach
  before WP25, and `default` has no `level = 1` node at all.
- **T2 has no tool of its own today** — the iron pick arrives with
  WP26/WP29. The steel pick (maxlevel 2) covers T2 *and* T3, and iron
  lies in the T1 band, so the ladder is unbroken as far as it goes:
  with today's item set a player digs down to **−500**, and T4 downward
  opens with WP26/WP29.
- **A pick is at its most fragile in the rock of its own tier**, and that
  is the intended shape of the ladder rather than a defect. `uses` is
  multiplied by `3^leveldiff`, so the steel pick gets 180 digs out of
  surface stone, 60 out of slate and only its bare 20 out of basalt —
  and the next tier's pick makes that same basalt cheap again. Whether
  the *base* `uses` of the six picks need raising for deep mining to feel
  fair is a durability question and belongs to **WP22**, not here.
- The mese and diamond picks are unreachable in game and are deleted by
  **WP28** (§3.0.3). Their maxlevel 4/5 exist only so a runtime tester
  can open T5/T6 at all.

**A higher tier does not only dig *deeper*, it digs *faster*** (decided
2026-08-08). The `maxlevel` gate above is the **access** half of the tool
ladder; the dig `times` are the other half, and they are the **reward**.
The rule: **each tier's pick digs its own stratum — and every stratum
above it — faster than the pick of the tier below.** So the next pick is
felt on the rock a player is already mining, not only on the rock they
could not touch before, and the ladder is monotone by construction —
using a higher pick is never slower on any stratum it can break at all.

**The per-tier numbers are open** and live in
`TODO-design-crafting-rework.md` **B22**. One subtlety this section
already documents has to be respected while authoring them: `maxlevel`
silently rescales **both** `uses` and dig `times` through `leveldiff`
(`real_uses = uses · 3^leveldiff`, and `time = time / leveldiff` for
`leveldiff > 1`), so the progression has to be authored against
**effective** values per stratum, never against the raw `times` in the
item def. Part of the wanted speed-up therefore already exists for free
and must be measured before more is stacked on top — and every `times`
change has to be re-checked against `uses`, which the same `leveldiff`
scales. WP25 walked into exactly this trap from the durability side.

### 3.1 Armor curve (decided; shipped as the generated curve in WP7)

1 armor point = 1% damage reduction; equipped pieces sum, **clamped at
the 60% cap** (combat_stats §2: endgame plate 60%, cloth ~15%). Set
totals (4 pieces: chest/legs/head/feet split ≈ 35/27/22/16%):

**Column relabel, 2026-08-07 — no number changed.** These columns used to
be headed "T1–T4", which now collides with the six gear tiers of §3.0.
They are and always were **four sample points on one continuous line**,
taken at **ilvl 12 / 27 / 42 / 57**; the paragraph below already says so.
Headed by their ilvl from here on.

| Armor line (profession) | ilvl 12 | 27 | 42 | 57 | ilvl 57 per piece |
|---|---|---|---|---|---|
| Metal (Blacksmith) | 16 | 29 | 42 | 55 | 19/15/12/9 |
| Leather (Leatherworker) | 11 | 20 | 30 | 40 | 14/11/9/6 |
| Cloth (Tailor) | 5 | 8 | 11 | 15 | 5/4/3/3 |
| Shield (Blacksmith, Journeyman+, Warrior) | — | 4 | 5 | 5 | — |

Check at 60: full plate+shield = 60% → mob hit 26 → 10.4 eff. vs 325 HP
(≈31 hits); cloth Mage 15% → 22.1 vs 148 HP (≈7 hits) — tank/squishy
spread as designed. Drop gear uses the same table at its ilvl bracket;
quality adds enchants, never base armor.

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
ours. Bar costs are §3.3's — chest 5 / legs 4 / head 3 / feet 2 per
piece — for the lead metal of the tier, and the same shapes serve the
leather and cloth lines with cured leather and bolts in place of bars.

### 3.2 Weapon table (curve: 1H dmg = 4 + 0.35 × ilvl, combat_stats §2)

fpi = full_punch_interval. Columns are **ilvl sample points**, relabelled
2026-08-07 for the same reason as §3.1's — no number changed.

| Family | fpi | dmg factor | ilvl 12 | 27 | 42 | 57 |
|---|---|---|---|---|---|---|
| 1H sword / mace / axe | 1.0 | ×1.0 | 8 | 13 | 19 | 24 |
| Wand / scepter / orb (caster 1H) | 1.0 | ×1.0 | 8 | 13 | 19 | 24 |
| Dagger | 0.7 | ×0.7 | 6 | 9 | 13 | 17 |
| 2H greataxe / warhammer | 1.4 | ×1.5 | 12 | 20 | 29 | 36 |
| Metal-shod staff (caster 2H) | 1.4 | ×1.2 | 10 | 16 | 23 | 29 |

**Rounding rule** (made explicit 2026-08-07): **round the 1H value
half-up, then apply the family factor and round half-up again** — never
one rounding over the whole product. The greataxe ilvl-42 cell read 28
under the old text and is **corrected to 29** here: 1H at ilvl 42 is
18.7 → 19, and 19 × 1.5 = 28.5 → 29, the same two-step that already turns
ilvl 27's 13 × 1.5 = 19.5 into 20. The rule is load-bearing, not
bookkeeping: it
also generates the vendor bracket weapons of §3.8.

2H DPS ≈ 1.07× of 1H — pays for the empty offhand.

**Caster weapons are craftable from 2026-08-07.** The old text left wands
and orbs **drop-only**, which meant a Mage or Priest had no craftable
weapon at all — the one real hole in the catalog. The **Woodcarver**
(§3.6a) closes it: wands, scepters and orbs are the caster **main-hand
1H** family and ride the existing 1H row (same fpi, same factor — the
weapon families are class flavor, not a power ladder, §8.2); staves stay
the caster 2H on the staff row, and "metal-shod" is literal — the
Woodcarver buys the fitting from a Blacksmith (§3.6a). Orbs are **not**
an offhand: the offhand is the Tailor's spell tome or the Blacksmith's
shield and nothing else (§3.5, §3.3), so there is no duplicate.

Weapons carry `grug_req_level = ilvl`
(the field is derived from `_grug_ilvl`; **enforced from WP5** — WP7's
vendor weapons already carry the ilvl but nothing checks it yet).

**How to read §3.3–§3.6b** (rewritten 2026-08-07). These sections used to
describe a model where each profession **owned** its item catalog. Under
§3.0.3 that is no longer true: the base item of every material tier is
craftable by everyone. What each section now lists is three things —

1. the **material chain** the profession refines through (unchanged; it
   is still the profession's progression and its trade good),
2. the **item families** the profession may **refine, enchant and turn
   into special variants** (§6b) — its exclusive claim on the *quality*
   of an item, not on its existence,
3. its **exclusive recipes**, a handful per mastery tier: things nobody
   else can make at all.

Coverage across the six professions is complete and overlap-free
(professions.md §2).

### 3.3 Blacksmith (forge) — metal, and everything made of it

**Material chain**: T1 **Bronze** → T2 **Iron** → T3 **Steel** → T4
**Silversteel** → T5 **Embersteel** → T6 **Grudgesteel** (§3.0.1/§3.0.2).
Vendor supply: flux. *Revised 2026-08-07*: the old four-step chain
(bronze / iron / steel / gem-tempered steel) is superseded by the
six-tier ladder, and **§10 P1's "gem-tempered steel" is retired with it**
— the T4 metal is Silversteel from a real new ore, which is exactly the
"new ore post-MVP" option P1 held open.

**Refines and enchants**: metal armor (all four slots), 1H weapons,
daggers, 2H weapons, shields. Bar costs for the base recipes: chest 5,
legs 4, head 3, feet 2, shield 4, 1H 3, dagger 2, 2H 5, staff fitting 2,
pick 3.

**Exclusive recipes**: shields (Journeyman+ — no other profession makes
an offhand of metal), the **metal fittings** the Woodcarver buys (§3.6a),
armor polish and whetstone kits (§7), and the race signatures of §4.

Ore access gating is now the depth/stratum rule of §3.0.4, not a
hand-written ore whitelist: a tier-n pick opens the tier-n stratum, and
§3.0.1's placement table says which ore lives there — a lead metal one
band above its own tier, a gem in its own band.

> **Superseded 2026-08-07 (§3.0.3):** ~~"Vendor floor sells up to the
> bronze pick — iron+ picks are smith products (mining stays open to
> all, the TOOL is the trade good)."~~ Every pick on the ladder is a base
> recipe now, so the Blacksmith has no claim on iron+ picks. Vendor stock
> is unchanged — the bronze pick stays the vendor's top tool (§3.7); a
> higher pick is **crafted, not bought**. The trade good is the
> **refined** pick: +100 % durability (§6b.2) is worth more on a mining
> tool than on anything else in the game.

### 3.4 Leatherworker (tanning rack) — leather

**Material chain**: hide + thread → leather, 1:1 per grade. **T1 light
leather, T2 cured leather, T3 heavy leather, T4 scaled hide**; the T5 and
T6 grades are listed in `TODO-design-crafting-rework.md`.

**Refines and enchants**: leather armor, all four slots. Base recipes use
the §3.1 shapes at jerkin 6 / pants 5 / hood 4 / boots 3 leather.

**Exclusive recipes**: armor kits from Journeyman up (§7), and the
**quiver** — a bag-slot item that holds only arrows, catalogued here and
shipping with §9's Phase-2 bow decision. The bow itself is a Woodcarver
product (§3.6a, §9), the quiver is not.

Supply loop as decided: the ×5 leather tag (professions.md §3), Tailors
buy leather for bags, Alchemists for apothecary gear, Woodcarvers for
grips.

**MVP note (corrected 2026-08-07):** an earlier draft of this section
claimed no MVP class could wear rank-2 armor. That is **wrong** — a
class wears its own rank *and everything below* (`inventory_equipment.md`
§2), so the **Warrior (rank 3) can wear leather**, and the equip filter
in `grug_inventory/equipment.lua` refuses only ranks *above* the
character's. What is genuinely unsettled is whether a Warrior ever
*wants* leather: at equal tier it is strictly less armor than metal, so
without a dodge or speed advantage the line is a legal but pointless
choice. Whether the leather line therefore registers in the MVP, and
what would make it worth wearing, is open in
`TODO-design-crafting-rework.md` (C10). The curve, the chain and the
recipes above are authored either way, and the Rogue (Phase 2) is the
line's intended main customer.

### 3.5 Tailor (tailor bench) — cloth, bags, the caster offhand

**Material chain**: 2 cloth + thread → bolt. **T1 linen scrap → patch
bolt** (zombies drop scraps from L1 — Tailors start in the safe core),
**T2 linen cloth → woven bolt**, **T3 heavy cloth → heavy bolt**, **T4
heavy + spider silk → silkweave bolt**; the T5 and T6 bolts are listed in
`TODO-design-crafting-rework.md`.

**Refines and enchants**: cloth armor, all four slots. Base recipes:
robe 6 / leggings 5 / cowl 4 / slippers 3 bolts.

**Exclusive recipes**:

- **Bags** (`inventory_equipment.md` §3) — **four sizes across the four
  mastery tiers, 8 / 16 / 24 / 32 slots**. The 8-slot bag stays
  vendor-sellable, because it is the floor tier (vendor floor rule); the
  16-slot bag is 8 woven bolts + 2 cured leather, the 24-slot 10 heavy
  bolts + 4 spider silk + 2 heavy leather, and the 32-slot ("huge bag")
  is the Master-tier addition of 2026-08-07. Bags are the one signature
  recipe line that is fully decided.
- **The spell tome (offhand)** from Journeyman up: +10 / +20 / +30 mana
  at Journeyman / Expert / Master, cloth + parchment + leather binding.
  It is one of exactly **two** offhands in the game; the other is the
  Blacksmith's shield (§3.3). Different item, different armor class, no
  duplicate.

### 3.6 Alchemist (alchemy table) — herbs, potions, elixirs, apothecary gear

**Herbalism is merged into the Alchemist** (2026-08-07, professions.md
§2): the Alchemist **gathers its own herbs**, and the separate gathering
profession is gone. What was a Herbalism tier gate is now the
Alchemist's book group — punching a herb the profession has not opened
yields nothing plus a hint message, exactly as before, but the gate is
the book group instead of a second profession. For everyone without the
Alchemist profession, alchemy herbs stay scenery; food-grade plants stay
universal (professions.md §1).

**Material chain**: herbs and spices in **three grades**, not six. The named
zone catalog places T1 sunleaf/gravemoss in low-level home regions, T2
dragonweed/marshbloom in the heartland and T3 crimson lotus/stormkelp in
high-level front/coastal regions; `biomes_mobs.md` §2/§6 owns the biome
binding and the healing-herb / spice split. Vendor supply: vials. All effects
percent-based or flat-small
(combat_stats §5: no consumable treadmill). **One shared 60 s cooldown
for instant potions; one "elixir" buff active at a time** (§10 P3). The
cooldown is an absolute wall-clock expiry in player meta, so a relog
cannot reset it; WP10's potions share that one clock rather than opening
a second timer. **Drinking at full health is refused** (message, no
consumption, no cooldown — decided 2026-08-07 in WP7: burning a potion
and a 60 s lockout on a misclick is a tax, not a rule).

**The potion keeps the instant slot; cooked food does not take it**
(decided 2026-08-08). Cooked food restores a comparable percentage —
the worked example is the same 30 % — but it does so through
`combat_stats.md` §5's **resting** channel (§3.7): standing still, at
8 % max HP/s, interrupted by any damage and by any movement. The Healing
Potion is the only thing in the game that restores health **instantly
and in combat**, and that, not the size of the number, is what it is
bought for.

**Exclusive recipes** — the entire consumable line is Alchemist-only;
nothing here has a base recipe (mastery names, relabelled 2026-08-07):

| Mastery | Recipes (2 herbs + vial unless noted) |
|---|---|
| Apprentice | Healing Potion (instant 30% HP — the combat_stats standard; vendor's weak 15% stays the floor), Mana Potion (instant 30% mana) |
| Journeyman | Elixirs of Might/Wisdom/Grace (+2 Str/Int/Dex, 15 min), Antivenom (cures poison — serpent/spider counter; dragonweed + venom gland) |
| Expert | Greater Elixirs (+4), Cat's-Eye Elixir (night vision 10 min — the enemy-territory raid tool vs the R2 no-torch rule), Deepwater Draught (water breathing 10 min; stormkelp), Swiftness Draught (+8% speed, 15 s — deliberately short; mobs must stay faster, flag §10 P4) |
| Master | Supreme Elixirs (+6), Stoneskin Flask (+4% armor, 30 min), Sovereign's Flask (§4, Human signature) |

**Apothecary gear** (the requested alchemist gear; cloth-class armor
values, cross-buys leather + bolts): Journeyman Apothecary Hood, Expert
Apothecary Garb (chest), Master's Regalia (chest, Rare, replaces Garb).
Worn
pieces add +10% potion/elixir duration and +1 elixir attribute each
(max 2 pieces counted) — profession identity you can see. Template:
slot pieces à la mcl_armor + effect hooks à la mcl_potions (both §1.2).

### 3.6a Woodcarver (carving bench) — wood, and every caster weapon

New profession, 2026-08-07 (professions.md §2). It exists because §3.2
left wands and orbs drop-only: before the Woodcarver, a Mage or Priest
had **no craftable weapon at all**, which is the only outright hole the
old roster had.

**Material chain**: wood, including the per-race woods of biomes_mobs §5
— silverwood and gravewood among them. Grades follow the six tiers; the
tier grade list is in `TODO-design-crafting-rework.md`.

**Refines and enchants**: staves, wands, scepters, orbs — the whole
caster weapon family of §3.2, main hand, 1H and 2H.

**Exclusive recipes**: the caster families themselves have base recipes
like everything else (§3.0.3), and the Woodcarver additionally owns
**bows** from Phase 2 (§9 — this replaces the old "Bowyer = Leatherworker
split" assignment; the quiver stays Leatherworker, §3.4).

**Cross-buy: the Woodcarver buys metal fittings from the Blacksmith.**
The §3.2 family is literally called "metal-shod staff"; from T2 up every
caster weapon needs a Blacksmith-made fitting of its own tier. That is
the same deliberate supply loop the Leatherworker and Tailor already run
in professions.md §3 — a profession that cannot finish its own top item
alone is what keeps the market alive.

### 3.6b Goldsmith (jeweller's bench) — gold, gems, both trinket slots

New profession, 2026-08-07 (professions.md §2). **Gem Hunter is merged
into it** and disappears as a separate profession; the mining bonus gem
chance and the Gem Detector come along as Goldsmith abilities.

**Material chain**: **Gold** — demoted from tool metal to jewelry metal
in §3.0.1 and now with exactly one consumer — plus the three gems of the
ore table: **Quartz (T2), Garnet (T4), Diamond (T6)**.

**Refines and enchants**: trinkets, and **gem refinement** — cutting a
raw gem into the reagent every other profession's fine and masterwork
recipes want (§6.4).

**Exclusive recipes**:

- **Both trinket slots** (`inventory_equipment.md` §2). They had no owner
  in the old roster at all; the Goldsmith is the first profession to hold
  a slot pair outright. **Trinkets ship in the MVP** (decided
  2026-08-08 — the slots are no longer reserved): the Goldsmith's
  headline is a **product, not a promise**, it is the profession's own
  wearable output on day one, and it is the reason the profession is no
  longer the one exception to `professions.md` §2.1's coverage claim.
  Trinkets carry no armor class and no class rank binding, so every
  class is a customer; their enchant pool is the trinket row of §6.2.
- **The Gem Detector** (world.md §5.4) — locates treasure clusters on a
  housing isle better than the vendor's Dowsing Rod. Carried over from
  the Gem Hunter unchanged, including its role as the profession's second
  pillar.
- The **bonus gem chance while mining** (10 % → 20 % at Journeyman) —
  carried over from the old Gem Hunter tier-2 effect.

### 3.7 Universal secondaries & vendor floor

Neither of these costs a main profession slot (professions.md §1).

- **Cooking** (trainer, free): cooked meat/fish, Hearty Stew (meat +
  potato/corn), Hunter's Feast (meat ×2 + melon + mushroom).
  **Raw food restores; cooked food restores AND buffs** (decided
  2026-08-08 — this replaces the old "raw food still fuels resting
  regen, cooking adds the buff, not the regen", which had the shape
  backwards). `combat_stats.md` §5 carries the same three rules from the
  recovery side; the two must not drift apart.
  - **Raw / plain food gives regeneration only, no buff.** It is the
    resting channel of `combat_stats.md` §5 — standing still,
    interrupted by damage or by movement — at **4 % max HP/s**.
  - **Cooked food gives both**: a restore *and* a buff. The restore runs
    through the **same resting channel at twice the rate, 8 % max HP/s**,
    and a dish carries the percentage of max HP one serving delivers
    (worked example: potatoes with boar steak, **30 % of max HP** plus a
    Strength buff). Cooking is therefore the **faster rest**, never a
    second instant heal: the instant slot stays the Alchemist's
    (§3.6 Healing Potion — 30 % max HP instantly, usable in combat, 60 s
    shared cooldown). A cooked dish that restores the same 30 % costs
    ~4 s of standing still and dies to a single hit or a single step;
    the potion costs a cooldown and nothing else. That is the entire
    difference between the two, and it is what keeps the potion worth
    carrying.
  - **Only one food buff is active at a time, and the most recently
    eaten food wins** — eating again *replaces* the running buff; food
    buffs never stack and never extend one another. This is the food-side
    twin of §3.6's "one elixir active at a time" (§10 P3), and a food
    buff and an elixir still stack **with each other**, exactly as
    before.
  - The buff is **Well Fed: +1/+2/+3 Str AND Int for 15 min by tier**
    (unchanged since 2026-08-06). **Its tier mapping is the open part**:
    three buff steps stand against the **six** T1–T6 groups the cooking
    book below now has, and no per-group restore percentage is authored
    either. Both live in `TODO-design-crafting-rework.md` **E21**, which
    already owns the per-tier recipe lists — the structure above is
    decided, the per-tier magnitudes are not.

  **Cooking gets a recipe book** (2026-08-07, §2.2): the same six T1–T6
  groups and the same level gates as a profession book, but **no
  keystones** — a cooking tier opens on its **ingredients**, which are
  regional, so **T6 cooking needs ingredients that only exist in level
  50+ areas**. Tier unlocks are explicitly wanted as quest goals ("find
  cocoa in the jungle"). Cooking is free and universal *and* gated; the
  book is what makes both true at once.
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

- **The items are material-named**, never bracket-named. The shipped
  adjective naming — *Crude / Plain / Tempered / Reinforced / Superior /
  Grand* over the six brackets — is replaced by the material the item is
  actually made of: **metal items take the lead metal** of §3.0.1
  (Bronze Sword, Iron Helm, Steel Chestplate, Silversteel Greaves,
  Embersteel Sabatons, Grudgesteel Greataxe), **cloth items take their
  bolt grade** and **leather items their leather grade** (§3.4/§3.5) —
  Linen Robe, Silkweave Cowl. The slot nouns are unchanged (Helm /
  Chestplate / Greaves / Sabatons, Cowl / Robe / Leggings / Slippers),
  and so are the generator, the prices, the ilvl anchors and the bracket
  boundaries. This is a rename plus the merge with `default`'s tool
  ladder — planned work, not a defect.
- **Selling a base item is not selling "the low tier of crafting".** It
  is selling the same item a crafter starts from. What a vendor can never
  sell is a **refined** or **enchanted** item (§6b) — that is the whole
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
| refined, +15 % (§6b.2) | 6 | 9 | 13 | 17 | 21 | 25 |

  **The refined row is the whole design in one line** (added 2026-08-07,
  computed from the row above with §3.2's half-up rounding). A refined
  item of tier n is strictly better than a base item of tier n — and
  strictly **worse** than a base item of tier n+1: 6 < 8, 9 < 11,
  13 < 15, 17 < 18, 21 < 22. That is exactly the constraint the rework was
  chosen for (+15 %, not +25 %), and it holds across the whole ladder
  with no exception. A refined item therefore never lets a player skip a
  tier; it makes the tier they are in worth staying in.

  Rationale for having the vendor ladder at all: on a small server the
  crafter for your armor class may simply not exist — the floor stops a
  player from going naked, it does not compete. Superseded 2026-08-07:
  the old "±15 % of crafted gear of the same era" comparison, and the
  older "10–15 % behind" before it. Under the merge there is nothing to
  compare — vendor gear and base crafted gear are the same item, and the
  crafter's edge is refinement and enchants (§6b), not a base number.
- **Rotation**: the core stock is fixed; each bracket additionally shows
  a handful of **rotating gear slots**, re-rolled hourly. Roughly **one
  rotation in five carries a single Uncommon item**, rolled in the
  **world window** (frac 0.00–0.60, §6.3 — the weakest rolls in the
  game, strictly below crafted-fine's 0.30–0.80) and priced ×3. That is
  the "today the trader had something good" moment, without a second
  gear source.

  **Implemented reading** (decided 2026-08-07):
  - The bracket's **fixed floor is always on sale**: the 1H sword plus a
    full set in each shipped armor line = **9 items**. That is what
    "guaranteed, but expensive … the floor, not the ceiling" requires,
    and the rotation may never touch it.
  - On top of it sit the **rotating slots**, drawn hourly from the
    **extra weapon families**, so **one family is withheld every
    rotation**. Withholding is what makes it a rotation: with one slot
    per extra the whole catalog would be on the shelf every hour and the
    re-roll would only permute the display order. The slot count is
    **always strictly below the pool size** — that is the rule, the
    number follows from §3.2.
    **Applied 2026-08-07**: §3.2 gained the caster 1H family
    (wand / scepter / orb, §3.6a), so the pool is now **4** — dagger,
    greataxe, staff, caster 1H — and the slot count rises from 2 to
    **3**, exactly as the rule above already prescribed. Casters can now
    buy a floor weapon, which the old three-family pool never allowed.
  - The **1-in-5 Uncommon is rolled per vendor and per bracket** (so two
    vendors in the same hour differ, and a player's own brackets differ
    from each other), replaces one of the rotating slots and is priced
    **×3**.
  - The Uncommon is **only offered once WP5's enchant roller exists.**
    Common is enchant-free by definition, so an Uncommon without rolls
    is mechanically identical to the Common beside it while costing
    three times as much — a blue-named trap, not a luxury. The whole
    ×3/quality/description machinery ships regardless; WP5 lights it up
    without a rule change here.
  - The rotation is **deterministic**: a pure function of (real hour,
    vendor, bracket). Two players at the same vendor in the same hour
    see the same shelf, and a restart does not re-roll it.
- Catalogs are **generated from the curves** of §3.1/§3.2, not authored
  by hand — six brackets cost the same as three.
- **Shipped armor lines: metal and cloth; leather does not ship**
  (decided 2026-08-07). The MVP classes are Warrior / Mage / Priest
  (`inventory_equipment.md` §2: ranks 3 / 1 / 1), so **nothing can wear
  leather** and 24 leather items would be dead weight in every catalog.
  The leather curve stays in the generator so its coefficients never
  have to be re-derived; the line registers with the Rogue (Phase 2) or
  with WP5's drop tables, whichever lands first. Under the §3.0.3 merge
  this decision now covers the **craft** ladder too — there is one
  catalog, so a line that does not ship does not ship anywhere (§3.4).
- Race-exclusive vendors and the same-race discount (world.md §7) layer
  on top of this unchanged.

Every craft output carries `_grug_sell_price` with the **anti-loop rule:
vendor value of a crafted item < summed vendor value of its
ingredients** — vendors are a floor, never a factory profit.

## 4. Race-exclusive signature recipes (top end, one per race)

Gate: crafter's race (player meta, checked in craft_predict) + Master
tier + the recipe. **Production is race-locked; the item is tradeable
and wearable by anyone in the faction** — that makes every
race+profession combo a market niche. All are Rare quality, ilvl 60,
rolled at the crafted-masterwork window (§6.3), **first enchant fixed**
(signature stat), remainder rolled. Shared mats: 2× Abyssal Crystal
(housing depths, §5.5) + **T6 bases** + one specific trophy. The recipe
unlocks **inside the profession's own book**, in its T6 group — there is
no separate signature book (§2.2).

| Race (faction) | Profession | Item | Slot/type | Fixed enchant |
|---|---|---|---|---|
| Dwarf (A) | Blacksmith | Deepforge Warhammer | 2H, dmg 36 | +Str (max roll) |
| Orc (H) | Blacksmith | Warfury Cleaver | 2H axe, dmg 36 | +Str (max roll) |
| Elf (A) | Tailor | Silvercanopy Robe | chest cloth, armor 5 | +Int (max roll) |
| Undead (H) | Tailor | Gloomweave Robe | chest cloth, armor 5 | +Int (max roll) |
| Troll (H) | Leatherworker | Serpentscale Harness | chest leather, armor 14 | +Dex (max roll) |
| Human (A) | Alchemist | Sovereign's Flask | consumable: +8 all attributes, 30 min | — |

Dwarf/Orc and Elf/Undead are exact cross-faction stat mirrors (different
look/name). Troll vs Human is deliberately asymmetric — see §10 P2.
This fulfills the world.md §7 hook ("only elven tailors craft the top
mage robe") with the Silvercanopy Robe.

## 5. Loot zones — what drops where

Drops obey the player-tag rule (combat_stats §3), quality/roll windows
per §6.3, **gear-drop ilvl = mob level** — and since §6.3's roll band is
chosen by the item's ilvl, that one number is all a drop needs: a drop
has no crafter whose mastery could be read instead. Named zone → materials is
binding through each zone's fixed biome/gathering palette; the level band adds
the gear/special layer.

**A dropped item's material tier must match the mob's tier** (added
2026-08-07). `ilvl = mob level` already implied it; stated outright
because the item is now material-named: a **T3 (Steel) item drops from
level 21–30 mobs** and nowhere else. A mob may not drop gear from a tier
its level band does not cover — that is what stops the drop table from
becoming a side door around the depth gate of §3.0.4.

| Named-zone band | Materials | Gear drops | Special |
|---|---|---|---|
| Peaceful starts 1–10 | equivalent T1 access on both faction sides | T1, source windows per §5.1 | no PvP objective |
| Peaceful home zones 11–20 | equivalent T2 access | T2, source windows per §5.1 | first named rares; no contested zone |
| Peaceful heartland 21–30 | equivalent T3 access | T3, source windows per §5.1 | preparation for the central frontier |
| Mixed frontier 31–40 | equivalent T4 access | T4, improved windows on qualifying elites | Human/Orc/shared-centre contested; four flank approaches peaceful |
| Front 41–50 | equivalent T5 access | T5, improved windows on qualifying elites | war-front objectives and quest hooks; no free supply crates |
| High front 51–59 / endpoints 60 | equivalent T6 access | T6, improved windows; elites common | two contested dragons and all-six-gem apex camps |
| Depth axis | the six strata of §3.0.4, each behind a tier-n tool; which ore lies in which band is §3.0.1's placement table: copper/tin/coal/**iron** (0…−100) → quartz (−300) → silver (−500) → garnet + emberstone (−700) → emberstone deep band **and Abyssal Crystal** (−1000) → diamond (below); gold keeps its vendored depth and its coast veins | cave mobs as per surface tier | **no drop layer of its own**, at any depth (below) |
| Enemy faction | equivalent tier budgets, not necessarily identical palettes | same tier/source rules | enemy named rares and any raid-enabled king remain incentives |

**The depth axis pays in materials, and gets no drop layer of its own**
(decided 2026-08-08). The deep band below −1000 (`world.md` §4c) is a
level-60 place only a T6 pick reaches, which makes it the obvious home
for a T6 gear layer — and deliberately does not become one. Underground
mobs keep dropping exactly what their families drop on the surface (the
Gear drops column above); nothing is added for being deep. Two reasons,
both structural: **the best items come from crafting and from hard
bosses** (§0, §6.4 — the two 0.60–1.00 windows of §6.3 are exactly those
two), and a depth layer would be a third top source with neither a
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
| Apex boss / faction King | — | 100% | boss |

A dropped item that carries enchants is by definition also **refined**
(§6b.3 admits no other state) — which is why the refinement word never
appears in a drop's name (§6b.4).

### 5.2 Named rares (spawn rules decided in biomes_mobs §3.3)

2–4 h respawn, patrol routes, faction-wide broadcast. Loot per kill:
guaranteed Uncommon (rare window) + 25% Rare + **100% signature trophy**
(`group:grug_rare_trophy` — Grimtusk's Tusk, Silkfang's Gland, …): the
T4 book-group keystone, the third input of the T6 alloy and the
masterwork ingredient (§2.3, §3.0.2, §6.4). Anti-camping:
patrol routes + broadcast + the 2–4 h jitter (already decided) — no
extra mechanic needed.

### 5.3 Apex world bosses (world.md §4b)

Respawn 20–28 h (rolled). Lair **hoard chest** unlocks on the kill, one
withdrawal per tagged player: 1 Rare item (boss window) + 3–5 wyrmscale
(Master-tier leatherworking masterwork mat) + 20–50c + **1 Abyssal
Crystal** (the bridge source until housing ships, §10 P5).

### 5.4 The faction King (enemy capital raid)

Respawn 20–28 h. Per tagged raider: 1 Rare (boss window) + 30–60c;
once per kill: **Fallen Crown** (masterwork ingredient usable in any
profession's Master-tier masterwork as the trophy slot). Elite guard ring
makes it a group raid by design; kills broadcast world-wide.

### 5.5 Housing depth treasures

**Abyssal Crystal** (renamed 2026-08-07 from "abyssal gem" — it is the T6
alloy input of §3.0.2, not a Goldsmith gem): finite nodes in the deepest
purchased step of a **personal** housing isle (world.md §5.4 — no
respawn, R4); ingredients for race signatures (×2) and optional
Master-tier masterworks.
Revised 2026-08-07: since every character is granted an isle at level 30
and the depths are a bought treasure-cluster ladder rather than guild
property, the supply is personal progression, not a guild privilege —
but the deep steps are endgame-priced, so the apex-hoard bridge stays
(§10 P5).

Revised 2026-08-08: the crystal also has a **continental deposit below
−1000** (§3.0.1), so an isle is now the *safe* source rather than the
only one. What an isle sells exclusively instead are its **six
step-exclusive materials** (`world.md` §5.4), of which one is live in the
MVP — the **Amplifier** of §6b.8.

### 5.6 Contested-front reward hook

The authored war front feeds crafting only through the existing
player-involvement war-trophy/heavy-cloth rules and later explicit quests.
WP42 ships no refilling supply crate. Each contested zone reserves one
non-loot quest-interaction slot for WP9; it is not a free material source.
The two endpoint apex mining camps are the sole map-side addition: each has
the 12 all-six-gem nodes specified by `world_zones.md` §6 and
`world.md` §2 R4.

## 6. Quality tiers & enchant roll ranges (WP5 numbers)

### 6.1 Meta model

Item meta: `grug_quality` (1 Common / 2 Uncommon / 3 Rare / 4 Unique-
reserved), `grug_ench` = one serialized `{stat = value, …}` table (mcl
pattern §1.2), `grug_upgrades` (0–2, §7), `grug_req_level`.

**`grug_req_level` scope** (sharpened 2026-08-07; **enforced from WP5** —
WP7 ships 72 equippable vendor items that carry the ilvl but no check):
**every equippable item** carries it — weapons, armor, offhands and trinkets — and it
equals the item's ilvl. Equipping below the requirement is **blocked
with a chat message**, enforced in the slots' group-filtered `allow_put`
(inventory_equipment.md §2); "equips but grants nothing" was rejected as
an invisible failure. Drops keep `ilvl = mob level` (§5), so gear above
your level is lootable and tradeable, just not wearable yet — that is
intended, and it is also what stops one level-60 friend from outfitting
a level-5 character and flattening the entire surface progression. Description
regenerated from meta on every change (name colorized: white `#FFFFFF`,
blue `#4A90FF`, yellow `#FFD700`, orange `#FF8000`; one line per
enchant).

**Item descriptions always show the BASE stat** (decided 2026-08-07 in
WP7): under the name and the item level, one grey line carrying the
number the item actually contributes — `5 damage, 1.0 s swing` for
weapons (the swing interval belongs next to the damage, or a dagger's
higher rate is invisible — combat_stats.md §2), `3 armor (-3% damage
taken)` for armor pieces. Without it a player cannot compare two pieces
without re-deriving the §3.1/§3.2 curves by hand. The base stat does
**not** live in item meta and cannot be reconstructed from an enchant
roll, so the regeneration above must **preserve these lines and append
the enchant lines below them**. Attack speed applies via `tool_capabilities.
full_punch_interval` meta override; stats recompute on equip change
(WP15 hook). Enchant count: **Uncommon rolls 1–2 (60/40), Rare 3–4
(70/30)** — the decided budgets, and from 2026-08-07 also the prefix and
suffix count of §6b.

**Refinement and the base-stat line** (2026-08-07): a refined item's grey
line shows the **refined** number — the +15 % damage or armor of §6b.2,
rounded half-up like every other value on the curve, and the doubled
durability. Refinement is a property of the item, not a roll, so it goes
into meta alongside `grug_quality` as a plain boolean; the description
pipeline reads it exactly like the ilvl. The affix words themselves live
in the **name**, not in the stat lines (§6b.4).

**Hand-off from the vendor catalogs** (WP7 → WP5, 2026-08-07): vendor
gear ships with the item-def fields **`_grug_ilvl`, `_grug_bracket` and
`_grug_quality = 1`**. WP5 derives the per-stack `grug_req_level` and
the enchant rolls **from those**, so a bracket catalog needs no second
list of levels. **WP7 deliberately enforces no level requirement at
all** — the equip filter has no `grug_req_level` branch yet, and the
number it would read is published but unused. Adding the check is WP5's
edit in one place, not a rewrite of the catalog.

### 6.2 Enchant pools per item family (no duplicate stat per item)

| Family | Pool |
|---|---|
| Melee weapons | +Str, +Dex, +attack speed%, +crit%, +HP |
| Caster weapons/offhands | +Int, +mana, +crit%, +HP |
| Metal armor | +Str, +HP, +armor%, +dodge% |
| Leather armor | +Dex, +HP, +crit%, +dodge% |
| Cloth armor | +Int, +mana, +HP, +crit% |
| **Trinkets** (both slots) | **+Str, +Int, +Dex, +HP, +mana, +crit%** |

**The trinket row** (added 2026-08-08 with the MVP trinkets,
`inventory_equipment.md` §2). Every other row is bound to a wearer by
its armor class or its weapon family, so its pool can be narrow;
trinkets are worn by **every class** (no armor class, no rank binding,
§3.6b), so theirs is the one **universal-ish** pool: all three primaries
so any class finds its own, +HP and +mana as the two flat resources, and
+crit% as the single percentage. It is deliberately **not** a superset:

- **No +armor%** — armor is what the four armor slots are *for*, and a
  fifth and sixth source would push the 60 % cap (`combat_stats.md` §2)
  without any class having to wear armor for it.
- **No +dodge%** — avoidance stays an armor property, so the
  mitigation-vs-avoidance choice between the metal and leather rows
  keeps its meaning; a trinket that hands out dodge would let a cloth
  wearer buy the leather row's identity.
- **No +attack speed%** — that is the melee-weapon row's identity and
  the one stat that multiplies with everything else on a character.

Six entries against the other rows' four or five is intended: with the
hard 4-slot ceiling of §6b.4, a wider pool means a trinket is a *roll*
rather than a predictable stat stick, which is what makes two of them
worth comparing. This section's **"no duplicate stat per item"** rule
applies to trinkets unchanged — a single trinket may never carry +Str
twice, so its up-to-four affixes are four *different* stats out of the
six. The two trinket slots hold two separate items, so the same stat may
legally appear once in each.

### 6.3 Roll ranges by the item's ilvl bracket and source window

Value ranges (min–max) per ilvl bracket. **The band is chosen by the
ITEM's ilvl** (decided 2026-08-08) — never by the crafter's mastery tier
and never by the crafter's character level. The four bands below are the
"item levels" column of §2.1's mastery table — 1–15 / 16–30 / 31–45 /
46–60, same boundaries, no third set anywhere; that those boundaries
fall on the same numbers as the four mastery level anchors is a property
of the numbers, not a rule. These bands are **not** the six material
tiers of §3.0; the two ladders are independent by design (§2.1).

Two consequences, both intended:

- **A Master who crafts a low-tier item gets low-tier rolls.** A
  level-50 Master smithing a T1 Bronze Sword (ilvl 3) rolls in the 1–15
  band — +1–3 Str, not +6–12. **The item is what is weak, not the
  crafter**, and this is the same rule as "a T2 enchant cannot be applied
  to a T1 item", read from the roll table's side. What the Master's rank
  still buys on that sword is the **slot count** (all four, §6b.5) and
  the crafted-masterwork window below, not a bigger number per slot.
- **An Apprentice fills one slot even on a T6 item.** Mastery decides
  *how many* affixes a crafter may put on an item (§6b.5), never *how
  big* they are: an Apprentice working T6 stock produces a one-affix
  item whose single roll is a full 46–60 roll.

**Mob drops have no crafter at all**, which is the other half of the
argument: §5 sets gear-drop ilvl = mob level and points at this table, so
for a drop only the item reading can work at all. One rule for both
sources is what keeps a dropped and a crafted item of the same ilvl
comparable.

| Enchant | 1–15 | 16–30 | 31–45 | 46–60 |
|---|---|---|---|---|
| +Str / +Int / +Dex | 1–3 | 2–5 | 4–8 | 6–12 |
| +HP | 4–8 | 8–15 | 14–24 | 20–35 |
| +Mana | 6–12 | 12–24 | 20–36 | 30–50 |
| +Crit% / +Dodge% | 0.5–1.0 | 0.5–1.5 | 1.0–2.0 | 1.5–3.0 |
| +Attack speed% | 3–6 | 4–8 | 6–12 | 8–16 |
| +Armor% (armor only) | 1–2 | 1–3 | 2–4 | 3–6 |

**Source window** (the decided "same mechanic, only ranges differ"):
`roll = min + frac × (max − min)`, frac uniform in the window:

| Window | frac | Used by |
|---|---|---|
| world | 0.00–0.60 | normal-mob drops |
| crafted-fine | 0.30–0.80 | crafted Uncommon ("fine" recipes) |
| elite | 0.30–0.90 | elite drops, dungeon/crate loot |
| rare | 0.50–1.00 | named-rare drops |
| crafted-masterwork | 0.60–1.00 | crafted Rare incl. race signatures |
| boss | 0.80–1.00 | apex hoards, faction King |

**Cap safety at 60 — re-run for 8 slots (2026-08-08).** The original
check assumed **6** enchantable slots (weapon, offhand, 4 armor) and
read: worst-case crit ≈ 6×3 % + 5 % base + ~7 % from Dex ≈ 30 %, landing
exactly on the cap. With the MVP trinkets (`inventory_equipment.md` §2)
the count is **8**, and the arithmetic changes:

| Stat | Slots that can roll it | Worst case at 60 | Cap (`combat_stats.md` §2) | Verdict |
|---|---|---|---|---|
| **Crit** | 8 (weapon, offhand, 4 armor, 2 trinkets) | 8×3 % = 24 % + 5 % base + ~7 % Dex ≈ **36 %** | **30 %** | over by ~6 points, **clamps** |
| **Dodge** | 4 (armor only — no trinket, no weapon) | 4×3 % = 12 % + ~7 % Dex ≈ **19 %** | **30 %** | under, no clamp |
| **Armor %** | 4 (armor only) | unchanged by trinkets | **60 %** | unchanged |

Where the numbers come from: **3 %** is the top of the 46–60
`+Crit%/+Dodge%` band in the table above, and one item may carry a given
stat **once** (§6.2), so 3 % per slot is the ceiling per item. The
**5 %** is crit's flat base and the **~7 %** is `0.1 %×Dex` at a
level-60 Dex of ≈ 70 (`combat_stats.md` §1/§2 — base 10 plus 1 per
level); dodge has the Dex term but no base, which is the whole
difference between the two rows.

**A stricter upper bound, for completeness.** Nothing stops one item
from carrying `+Dex` *and* `+crit%` (different stats, so §6.2's rule is
satisfied). Eight items at the band's top `+Dex` of 12 add 96 Dex, i.e.
another ~9.6 % crit, for an absolute ceiling of ≈ **45 %** — and dodge
by the same route reaches ≈ 12 % + 16.6 % ≈ **29 %**, still under its
cap by a hair. Both are deliberately generous — they need a full Rare
set rolled at the top of every range on both stats on every slot, and
they over-count anyway, because `+Dex` is in neither the metal-armor,
the cloth-armor nor the caster-weapon pool. No reachable set gets there;
the bound exists so nobody has to wonder.

**Verdict: the flat caps still absorb it, and no new rule is needed.**
Crit clamps at 30 %, dodge lands under its cap even in the stricter
bound above, and the 60 % armor cap is not touched at all because
trinkets roll no `+armor%`. What is gone is the *headroom*: the 6-slot
check landed on the cap with nothing to spare, the 8-slot one
**overshoots it by about 6 points** in the plain case and by ~15 in the
stacked one — a fully crit-stacked endgame set wastes roughly its last
two crit affixes. That is a clamp, not a balance break: nothing
overflows into a stat the design does not bound, and no number outside
this section changes. Since `+crit%` is the only percentage in the
trinket pool, it is also the **only** cap the two new slots move at all.
If the wasted affixes ever become a real complaint, the fix belongs in
WP5's affix distribution, not in a new cap.

### 6.4 Crafted quality (how crafting reaches Uncommon/Rare)

Re-stated 2026-08-07 against the refinement model of §6b; the windows and
the quality thresholds are unchanged.

- **Base recipes → Common**, no enchants, craftable by everyone
  (§3.0.3). This is the reliable, repairable baseline and the item a
  vendor sells.
- **Refinement → Common, refined** (§6b.1/§6b.2). Still Common — a
  refined item has no enchants yet, so it cannot be blue. Professions
  only.
- **Fine recipes** = refine + **1–2 affixes** (each tier, +1 cut gem or
  tier reagent — venom sac, slime gel, sleek pelt, …) → **Uncommon**,
  crafted-fine window.
- **Masterwork recipes** = refine + **3–4 affixes** (Expert/Master only;
  + named-rare trophy or Fallen Crown, at Master also an Abyssal Crystal
  option) → **Rare**, crafted-masterwork window. Race signatures (§4) are
  masterworks with a fixed first affix. This keeps "better gear comes
  from crafting or hard bosses" literally true: the two 0.60–1.00 windows
  are crafting and bosses.

The mapping is exact: §0's **Uncommon = 1–2 enchants, Rare = 3–4** and
§6b.4's **2 prefixes + 2 suffixes = 4 slots** are the same budget counted
two ways. Nothing had to be re-balanced for the prefix/suffix model —
that is why it was chosen.

## 6b. Refinement, affixes and special variants (decided 2026-08-07)

This is what a profession is *for*. Everyone crafts the base item
(§3.0.3); a profession makes it better, and every step below is
profession-only.

### 6b.1 Only professions refine

A base item becomes a **refined** item at the profession's workbench. The
refinement is expressed in the item **name** by a family word:

| Family | Refinement word | Example |
|---|---|---|
| Weapons, tools | **Honed** | Honed Stone Sword |
| Metal & leather armor, shields | **Reinforced** | Reinforced Iron Chestplate |
| Cloth armor, bags, spell tomes | **Ornate** | Ornate Robe |

A profession may only refine the families it owns (§3.3–§3.6b). No
player without the profession can produce a refined item by any means.

### 6b.2 The refinement bonus

**+15 % base damage** (or the armor equivalent) and **+100 % durability.**

- **15 %, not 25 %** — deliberately chosen so that a refined item of tier
  n never beats an unrefined item of tier n+1. §3.8 carries the full
  ladder check; it holds at every step.
- **+100 % durability** doubles WP22's 3000-combat-event wear budget
  (§8.3) to 6000 cleanly — no new constant, and it makes refinement worth
  buying even on an item whose damage number a player does not care
  about (a pick, §3.3).
- The bonus is applied to the item's own base value and shown in the grey
  stat line (§6.1). It does not scale with mastery tier; a Master's
  refinement is worth the same +15 % as an Apprentice's. What mastery
  buys is **slots** (§6b.5), not a bigger bonus.

### 6b.3 Only refined items can be enchanted

**A plain base item can never carry an enchant.** Refinement is the
prerequisite for every affix, without exception. This is the single rule
that makes refinement worth doing at all, and it is why "enchanted"
implies "refined" everywhere else in this document.

**Found items keep their own enchants** (§5.1). "Only professions can
enchant" restricts who may *apply* an affix; it says nothing about items
that arrived pre-enchanted from a mob.

### 6b.4 The prefix/suffix naming system

Enchants are expressed in the item name as **prefixes and suffixes**.

- **Maximum 2 prefixes + 2 suffixes = 4 enchant slots.** That is the hard
  ceiling for any item in the game.
- **Prefixes** name a stat the item gives its wielder: *lucky*
  (+crit%), *quick* (+Dex), *heavy* (+Str), *clever* (+Int).
- **Suffixes** do the same in the genitive: *of the bear* (+Str), *of the
  ox* (**+HP**), *of the cat* (+dodge%), *of the eagle* (+crit%).
  **The stat names above are §6.2's own, verbatim** (aligned 2026-08-08:
  the ox used to be written "+health", which is not a stat this game
  has) — an example that models a wrong stat name is exactly what A2's
  affix→stat mapping must not inherit.
  Every word maps to a stat that a §6.2 pool actually contains — there
  is **no poison stat** in this game (see §6.2 and `combat_stats.md` §2;
  poison arrives with the Rogue in Phase 2, `classes.md` §6), and an
  affix word for a stat nothing consumes is a bug, not flavour.
- **Two suffixes combine into one phrase**: "of Bear and Ox" — the "the"
  is dropped when combining, because "of the Bear and the Ox" reads
  badly. One suffix keeps it: "of the Ox".
- Examples: *Stone Sword of the Ox*, *Lucky Stone Sword of the Bear*,
  *Heavy Lucky Stone Sword*, *Heavy Lucky Stone Sword of Bear and Ox*
  (a full four-slot Master piece).
- **The refinement word disappears as soon as an affix is present.** An
  enchanted sword is "Stone Sword of the Ox", never "Honed Stone Sword of
  the Ox". Since only refined items can be enchanted (§6b.3), the refined
  state is *implied* by any affix — the word would carry no information
  and would crowd out the affixes that do.
- The affix **words** are the display layer; the rolled **values** live
  in `grug_ench` exactly as before (§6.1) and are shown one per line
  under the grey stat lines. The word says which stat, the line says how
  much.

The word lists and the stat each word maps to — including which affixes
are legal on which item family (§6.2 has the pools) — are in
`TODO-design-crafting-rework.md`.

### 6b.5 Mastery tier = fillable slots

| Mastery | Fillable enchant slots |
|---|---|
| Apprentice | 1 |
| Journeyman | 2 |
| Expert | 3 |
| Master | 4 |

An Apprentice can put one affix on a refined item; a Master can fill all
four. The slots are the item's — a Master can add a second affix to a
one-affix item an Apprentice made, up to four. This is the second reason
mastery matters (the first is the exclusive recipes, §2.1) and it is what
makes a Master crafter worth seeking out on a server.

### 6b.6 Quality follows the slot count

No new rule — §6.1's budgets, read through the affix model:

| Affixes | Quality | Colour |
|---|---|---|
| 0 | Common | white |
| 1–2 | Uncommon | blue |
| 3–4 | Rare | yellow |

So an Apprentice and a Journeyman produce Uncommon items, an Expert and a
Master produce Rare ones. The roll **values** come from the §6.3 band of
the **item's** ilvl (sharpened 2026-08-08), in the crafted-fine or
crafted-masterwork window (§6.4): mastery buys the number of slots on
this table, never the size of what goes into one.

### 6b.7 Special variants

A profession can turn a **refined but not yet enchanted** item into a
**special variant** with an effect of its own — an "Iron Frost Armor"
that slows attackers, for instance.

- A special variant **keeps its full 2 prefix + 2 suffix slots on top of
  its special effect.** The effect is not one of the four; it is a fifth
  thing the item does.
- The input must be unenchanted: the special variant is a step *between*
  refinement and enchanting, not an alternative to either.
- **Visual treatment**: adapt VoxeLibre's armor **trim/colouring** system
  (`mcl_armor/trims.lua`, §1.2) — a template item plus a colour overlay
  baked onto the armor texture, e.g. Iron armor carrying a diamond trim.
  That gives every special variant a look without one texture per
  combination.

### 6b.8 The Amplifier (isle-exclusive, decided 2026-08-08)

The **Amplifier** is one of the six materials that exist only in a
housing isle's purchased depth steps (`world.md` §5.4) and the only one
of the six that does anything in the MVP.

- **Effect: it raises *all* prefix and suffix values on one item by
  10 %**, rounded the way the affix line is displayed. It multiplies what
  §6.3 already rolled; it never adds a slot, never changes an item's
  quality tier (§6b.6) and never turns an unenchanted item into an
  enchanted one.
- **Applicable once per item**, ever. The used-up state is a marker in
  the item's meta next to `grug_ench` (§6.1) — the roller/description
  side of WP5 owns it, and it must be a marker rather than a counter on
  the values, because the effect has to be idempotent against a second
  application no matter how the item travelled.
- The input is an item that already carries affixes: the Amplifier is a
  step *after* enchanting, unlike the special variant of §6b.7, which is
  a step before it.
- **The §6.3 cap arithmetic has to be re-run against this multiplier
  before it ships** — the same check §6.3 already ran for eight slots.
  The caps sit in the consumer (crit clamps at 30 %, armor at 60 %,
  `combat_stats.md` §2), so a 10 % lift on already-clamping values is
  expected to absorb cleanly, but that is a prediction and it is to be
  verified, not assumed. This is a task, not an open design question: the
  effect is decided.

## 7. Upgrade mechanics (resolves the old §2 — no failure chance)

Two kit types per profession, applied in the grid (item + kit),
workbench nearby; effects on the item's OWN family only (whetstones/armor
polish = Blacksmith, armor kits = Leatherworker, embroidery = Tailor,
wood oils = Woodcarver, gem settings = Goldsmith, imbuing oils =
apothecary gear):

- **Imbue kit** (per material tier): **refined** Common → Uncommon; rolls
  1–2 affixes in the crafted-fine window. Cost ≈ 1 tier reagent + tier
  materials. *Sharpened 2026-08-07*: the input must be **refined**
  (§6b.3) — a kit is a way to apply affixes, and affixes need a refined
  item like every other route to them. The kit is bought from a
  profession; applying it is not.
- **Temper kit** (Expert/Master): re-rolls all affix VALUES on an
  Uncommon/Rare item; 1st application window 0.50–0.95, 2nd 0.60–1.00,
  **max 2** (`grug_upgrades` meta). Never changes affix count or quality
  tier — an imbued Common (now Uncommon, 1–2 affixes) stays strictly
  below a fresh Rare (3–4 affixes): the decided "upgraded mediocre item
  never becomes a top item", enforced structurally, not by caps.

## 8. Prices & the gold-income curve (resolves the old §4; seeds economy.md numbers)

All values copper (100c = 1s, 100s = 1g). Design target: **lifetime
gross income to 60 ≈ 1g**, arriving at 60 with ~20–40s after sinks;
endgame farming ≈ 6–12s/hour — "a full gold is a fortune" holds.

### 8.1 Income

- **Quest reward** = 2c + 1.5c × quest level, rounded to 5c steps
  (L1 ≈ 5c, L20 ≈ 30c, L60 ≈ 90c); elite/group and war-front PvP
  quests ×2. ~80 quests to 60 ≈ 35–40s total.
- **Trash/vendor loot** per kill (expected): 1–2c (L1–15), 2–4c
  (16–30), 4–7c (31–45), 6–10c (46–60); elites ×3 quantity, named
  rares ×6 (mob-tier multipliers). ≈ 35s over ~1000 kills to 60.
  Bandit "coin" drops become a *stolen purse* trash item (5c) at a
  **drop chance of 1/3** (fixed 2026-08-07) — no physical currency
  items (economy.md §1 upheld).
- Herbs/materials sold to vendors: **1–6c each, scaling with material
  tier** (widened 2026-08-07 — the shipped material scale already runs
  to 6c for heavy leather and scaled hide, and a T3/T4 reagent priced
  like a bone would make the tier ladder invisible). Still a floor; the
  real market is player trade.
- **Known deviation — the bandit runs hot.** A bandit's expected vendor
  yield is ≈ **6c** in WP18's core/inner bands and ≈ **9c** in its outer
  band, i.e. roughly **2–3× the trash-loot band of its current source
  region**. The
  purse is not the cause (1/3 × 5c ≈ 1.7c); the dominant term is WP6's
  **guaranteed** 1–2 cloth drop, which was priced as a Tailor material
  rather than as trash income. Flagged for a balance pass (drop the
  cloth to a chance roll, or re-price the band for humanoids) rather
  than silently accepted — bandits are the intended cloth source, so
  the fix is a tuning call, not a bug fix.

### 8.2 Vendor prices (sell to players)

| Item | Price |
|---|---|
| Thread / flux / vial / parchment / whetstone blank | 1c / 2c / 3c / 5c / 4c |
| Torch | 1c |
| Weak healing potion (15%) | 8c |
| Small bag (8 slots) | 80c |
| Vendor Common gear: weapon / chest / other piece | 50c / 40c / 25c |
| Wood & stone tools / bronze pick | 5–15c / 40c |
| Recipe book (any profession; also the replacement) | 25c |
| Dowsing Rod (housing cluster finder, world.md §5.4) | 15c |

*Book prices revised 2026-08-07*: the four tome rows collapse into one.
There is one book per profession (§2.2), so there is one price, and it is
the old Apprentice-tome price unchanged. The 1s/3s/10s replacement rows
are **deleted** — they priced a *progression carrier*, and progression
now lives in player meta, so a re-bought book immediately shows every
group the character has opened. Losing a book costs 25c at any level.

**Bracket gear ladder** (§3.8, decided 2026-08-07): the bracket-1 prices
above are the anchor and every further bracket costs **×1.4**; chest =
0.8 × weapon, every other piece = 0.5 × weapon.

| Bracket | 1–10 | 11–20 | 21–30 | 31–40 | 41–50 | 51–60 |
|---|---|---|---|---|---|---|
| Weapon | 50c | 70c | 98c | 137c | 192c | 269c |
| Chest | 40c | 56c | 78c | 110c | 154c | 215c |
| Other piece | 25c | 35c | 49c | 69c | 96c | 134c |
| Full set | 165c | 231c | 323c | 454c | 634c | 886c |

Two notes on the table (2026-08-07):

- **The table prices SLOTS, not families.** Every weapon family of
  §3.2 shares the single "weapon" price, so a dagger costs exactly what a
  two-hander costs. Deliberate — the families are class flavor, not a
  power ladder, and one price per bracket keeps the ×1.4 ladder legible.
  Revisit only if a family ever becomes strictly better.
- **Buy-back is 25 % of the sale price** (economy.md §2), applied to the
  prices above and to every other vendor good.

Outfitting completely from vendors in **every** bracket costs ≈ **27s**,
about a quarter of the lifetime income to 60 (§8) — affordable
selectively, deliberately painful as a habit. That pressure is what
keeps drops and crafting primary; the rotating Uncommon at ×3 is priced
as a luxury, not as an upgrade path.

### 8.3 Recurring sinks

- **Repair** (WP22): per piece = ceil(ilvl × 0.5c) × quality factor
  (Common ×1, Uncommon ×1.5, Rare ×2). Starter piece 1–3c; full Rare
  set at 60 ≈ 3s per full repair. Wear budget ≈ 3000 combat events per
  item (broken = stops working, never destroyed — decided), **6000 on a
  refined item** (§6b.2). The price, not the frequency, is the tier
  lever — and refinement halves the frequency, which is exactly the
  convenience a player pays a crafter for.
- **Respec**: 5c × character level (min 25c) → 3s at 60, repeatable.
- Job supplies + vendor consumables: the steady trickle (≈15–25% of
  leveling income re-sunk by design).

### 8.4 Big one-time sinks

Revised 2026-08-07 with the housing rework (world.md §5): the isle is a
**free royal grant at level 30**, and the old split of build-rights and
mining-rights purchases collapses into **one depth ladder**.

**Re-cut 2026-08-07 to six depth steps**, one per rock stratum (§3.0.4),
so the ten arbitrary 50-node steps become the six the mining ladder
already needs. Use this table verbatim; world.md §5.3 carries the same
one.

| Sink | Price |
|---|---|
| Housing isle itself | free (questline grant, min_level 30) |
| Housing depth step 1 → −100 (T1 rock) | **50c** |
| Housing depth step 2 → −300 (T2) | **2s** |
| Housing depth step 3 → −500 (T3) | **6s** |
| Housing depth step 4 → −700 (T4) | **20s** |
| Housing depth step 5 → −1000 (T5) | **60s** |
| Housing depth step 6 → bedrock (T6) | **1g** |
| Guild founding | **5g** |
| Dowsing Rod (vendor) / Gem Detector (Goldsmith craft) | 15c / crafted |

Six steps total ≈ **1.9g** (was ≈ 2.4g over ten steps). The 1g final step
is still the flagship purchase, so economy.md §2's "a full gold is a
fortune" holds; economy.md §4.1 carries the reduced total. Down to −30
is free (the seabed layer, world.md §5).

**Continental mining claims are removed** (2026-08-07): guilds are
social, chat and the guild bank, nothing else, so the 2g/5g claim rows
are deleted here, in `guilds.md` §3.2, in `world.md` §4 and in the
economy.md §4 sink list. Guild founding at 5g stays.

The depth ladder is the **anchor sink** (economy.md §4.1): it opens at
level 30, is per character rather than per guild, and each step buys a
finite cluster payout (world.md §5.4) that can never fund the next step.
A 5-player guild pools its 5g founding fee at 1g per head — **8–17
hours of endgame income each** at the 6–12s/hour rate of §8. (The
earlier "~1–2 evenings each" did not survive the arithmetic; corrected
2026-08-07. `guilds.md` §1 carries the same figure.)

## 9. Bows & arrows (Phase-2 enabler — catalogued, class NOT decided)

Item path (source: `mcl_bows`, code LGPL 3.0 ✓, media CC BY-SA 4.0 +
2 attribution sounds; port ≈ 1000 lines incl. `vl_projectile`, §1.2):

- **Bow family on the weapon curve**: full-charge damage = the 1H curve
  (8/13/19/24 at ilvl 12/27/42/57) at 25 m range, charge 0.5 s (mcl
  hold-pattern), partial charge scales linearly, enchant pool = melee
  weapons (attack speed → charge speed). One bow per material tier,
  material-named like everything else (§3.0.3).
- **Arrows** as stackable ammo + entity (vl_projectile template);
  craft 20/batch: 1 iron bar + 4 sticks + 4 feathers (sharp feathers —
  eagle/vulture drops finally get their reagent role). Quiver =
  Leatherworker bag-slot item holding only arrows (§3.4).
- **Producer: the Woodcarver** (decided 2026-08-07). This replaces the
  old "Bowyer = Leatherworker split" assignment — the Woodcarver already
  owns every other wooden ranged/caster weapon (§3.6a), so the bow needs
  no new profession and the Bowyer split is dropped from professions.md
  §5 entirely.
- This section makes the OPEN Phase-2 Archer/Hunter decision cheap: the
  entire item/ammo/entity path is specced, license-clean and now has an
  owner; the only open questions left are class kit + balance.
  **Explicitly not decided here.**

## 10. Resolved decision points

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
**Decided as recommended (2026-08-06).**

**P3 — Potion/elixir exclusivity.** One shared 60 s cooldown for
instant potions (heal AND mana) + one active elixir + Well Fed stacking
on top. Recommendation: **as proposed** — keeps consumable pressure
without a buff-stacking meta.
**Decided as recommended (2026-08-06).**

**P4 — Swiftness Draught.** +8% speed for 15 s brushes the "mobs must
outrun players" pillar (4.0 × 1.08 = 4.32 < 4.4 keeps mobs faster, but
PvP chases change). Recommendation: **ship at +8%/15 s**, tag as
balance-watch in the WP7 playtest.
**Decided as recommended (2026-08-06).**

**P5 — Abyssal-gem bridge.** Until guild housing ships, race
signatures would be uncraftable. Recommendation: **apex hoards drop 1
abyssal gem** as interim source; remove (or reduce to 10% chance) once
housing depths are live.
**Decided as recommended (2026-08-06).** *Amended 2026-08-07*: with
personal isles the source is no longer guild-gated, but the **Abyssal
Crystal** (renamed, §5.5) sits in depth step 6 — the 1g step, the single
most expensive purchase in the game (§8.4) — so the bridge is **kept at
the reduced 10%** rather than removed. *Amended 2026-08-08*: the
continental band of §3.0.1 did not change that, because it lies below
−1000 and needs the very pick the crystal makes — the 10 % hoard drop is
now the **only** ungated source of the material and is therefore
permanent, not interim (§3.0.1, "The T6 entry point is the apex hoard").

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

**D3 — Six professions, cut by material.** Blacksmith, Leatherworker,
Tailor, Woodcarver, Goldsmith, Alchemist. Herbalism merges into the
Alchemist, Gem Hunter into the Goldsmith; all six are symmetric with four
mastery tiers. Cutting by class was rejected: it breaks the moment
Phase 2 adds four classes, and a material profession serving several
classes is what keeps the supply chain social (professions.md §2/§4).

**D4 — One recipe book per profession, groups instead of a chain.** The
LotT tome chain is retired: level controls visibility, the keystone
controls the unlock, quest and boss recipes land in the same book, and a
player crafts only what is in their books plus the universal base
recipes. The keystones survive because they carry the **zone** gate a
level check cannot (§2.2/§2.3).

**D5 — Refinement is the profession's product.** +15 % base damage or
armor and +100 % durability; only refined items can be enchanted; affixes
are 2 prefixes + 2 suffixes, and mastery tier is how many of the four a
crafter can fill. 15 % was chosen against 25 % because a refined tier-n
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
decides only **how many** affix slots may be filled (§6b.5). D1 had left
the sentence readable both ways ("read as a crafter … read as an item"),
and the two readings diverge, because mastery follows the *character's
level* while ilvl follows the *item's material tier*. The crafter
reading broke two things at once: a level-50 Master's T1 Bronze Sword
(ilvl 3) would have carried band-4 rolls, violating "a T2 enchant cannot
be applied to a T1 item"; and **mob drops have no crafter at all**, while
§5 sets gear-drop ilvl = mob level and sends the roller to §6.3. That
the band boundaries coincide with the four mastery level anchors is a
property of the numbers, not a rule. Rejected: two roll tables, one for
crafted and one for dropped gear — the same ilvl would then have meant
two different items.

**D9 — Raw food restores, cooked food restores AND buffs.** §3.7 had it
backwards ("cooking adds the buff, not the regen"). Raw/plain food gives
**regeneration only**; cooked food gives a **restore and a buff**, and
only **one food buff** is ever active — the most recently eaten food
replaces the previous one. The restore is routed through
`combat_stats.md` §5's **resting** channel at **8 % max HP/s** (twice
raw food's 4 %) rather than being made instant: the Alchemist's Healing
Potion owns the instant slot by design (§3.6), and a cooked dish
restoring 30 % instantly would have deleted the potion's reason to
exist. Cooking therefore buys a **faster rest**, not a second potion.
The per-tier magnitudes (Well Fed's three steps against the cooking
book's six groups, and the restore % per group) stay open in
`TODO-design-crafting-rework.md` E21.

**D10 — A higher-tier pick digs faster, not only deeper.** §3.0.4
documented the `maxlevel` *gate* thoroughly but never stated the other
half of the tool ladder: each tier's pick digs its own stratum, and
every stratum above it, faster than the tier below. The gate is
**access**, the `times` are the **reward**. Numbers open in
`TODO-design-crafting-rework.md` B22, to be authored against
**effective** values — `maxlevel` silently rescales both `uses` and dig
`times` through `leveldiff`, which is the trap WP25 already hit from the
durability side.

**D11 — Trinkets get their own §6.2 pool row, and the cap check is re-run
for 8 slots** (resolves the trinket half of A3). Pool: **+Str, +Int,
+Dex, +HP, +mana, +crit%** — universal-ish because every class wears
both slots, and deliberately without +armor%, +dodge% and +attack
speed%, which are the identity of the armor and melee-weapon rows.
Consequence, stated rather than discovered later: the §6.3 worst case
for crit rises from ≈ 30 % on 6 slots to ≈ 36 % on 8 and now **clamps**
against the 30 % cap of `combat_stats.md` §2 instead of landing on it.
Dodge (≈ 19 %) and the 60 % armor cap are untouched, because trinkets
roll neither.

**D12 — There is no poison stat** (resolves the poison half of A2).
§6b.4's *of the snake* (+poison) was an off-hand example, not a
decision: poison appears in no §6.2 pool, no §6.3 row and nowhere in
`combat_stats.md`. The example is now *of the cat* (+dodge), and poison
is booked as the **Rogue's signature damage type for Phase 2**
(`classes.md` §6). Poison as a *mob* effect (the serpent, and the
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
would have been needed to mine the material the T6 pick is made of, and
the 10 % apex hoard would have become the tier's only door instead of a
bridge. The crystal is a **base resource**, and the earlier
arrangement made the entire T6 alloy depend on a 1.9 g gold sink. What
replaces the isle's hold on T6 is its six step-exclusive materials
(`world.md` §5.4). Rejected: leaving T6 behind the purchase, which had
been chosen only to keep one sentence in §3.0.1 literally true.

**D16 — The depth gets no drop layer of its own** (resolves the loot half
of `TODO-design-depth.md` D10). Underground mobs drop what their families
drop on the surface; being deep adds nothing (§5). A T6 gear layer down
there would have been a third 0.60–1.00-window source with neither a
crafter nor a boss behind it, against §0's promise that the best items
come from crafting and hard bosses — and the band already pays the
endgame *material* that the crafted endgame item is made of. Rejected:
T6 gear drops on the level-60 deep roster.

**D17 — The Amplifier is the one live isle-exclusive material in the
MVP** (resolves the effect half of `TODO-design-depth.md` C9). Once per
item, **+10 % on all prefix and suffix values** (§6b.8); the other five
isle materials are named and placed but inert, so later recipes can hang
off stock that is already in the ground and no mapgen change is needed
to add them. Two follow-ups are **tasks, not open questions**: §6.3's cap
arithmetic is re-run against the multiplier, and WP5 owns the
once-per-item marker in item meta.
