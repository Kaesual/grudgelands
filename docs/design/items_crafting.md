# Items, Crafting & Loot — Full Design Spec

**Decided spec** (authored + approved 2026-08-06; the surviving four flagged
points P1–P4 are recorded in §10).

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

**Material-system integration 2026-08-12.** Six universal metals now form a
non-circular pick/depth spine; natural-depth permission and resource harvest
tier are separate checks. Emberglass and Abyssal Steel replace the old
Emberstone/Mese and Grudgesteel targets. Six regional G1/G2 gems, cultural
finishes, a separate PvP-special channel, the final Goldsmith/trinket model and
the rebased 25c→25s Common-price axis are authoritative below. Private housing
isles, guild systems, finder items and the Amplifier are absent from the target
design. Historical decisions in §10 remain migration context only.

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
- **Ordinary equipment:** Uncommon = 1–2 weak enchantments; Rare = 3–4.
  Trinkets use their fixed one-prefix/one-suffix/one-special exception (§6.2).
- Vendors sell simple (Common) gear — available but painfully expensive;
  better gear comes from **crafting** or **special bosses**. *Sharpened
  2026-08-07*: "crafting" means **refinement + enchanting** (§6b) — the
  plain base item is the same item the vendor sells (§3.0.3).
- Items are **upgradeable via crafting within limits**: an upgraded
  mediocre item never becomes a top item. No upgrade failure chance.
- **The harder the enemy, the better the loot** — boss/elite multipliers
  act on the enchant roll ranges, same mechanic everywhere.
- **Rare patrol mobs** with special loot as raid incentive into enemy
  territory; each of the six race **Kings** is a heavily guarded raid boss
  with top-tier rolls.
- **Class/profession synergy intended** (Warrior+Blacksmith,
  Priest/Mage+Tailor, …).
- Regional materials and contested routes make high-tier equipment and
  optional target-race counters trade goods; universal picks never require a
  regional gem, cultural material or trophy.
- Cultural finishing is crafter-culture-bound but finished items remain
  tradeable and wearable by anyone; target-race PvP specials are a separate
  channel (§4).
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

**The signature table is decided (2026-08-13)** — per-profession detail
in §3.3–§3.6b, the kit rule in §7. Deliberately thin cells are design,
not gaps: filler recipes would collide with decided systems (repair is
WP22's ledger sink, light sources are R2-gated, combat buff consumables
belong to the Alchemist's no-treadmill line). Material tier is always
the book group's business; this table cuts only mastery:

| Profession | Apprentice | Journeyman | Expert | Master |
|---|---|---|---|---|
| Blacksmith | metal fittings | shield; whetstone imbue kit | whetstone temper kit; armor-polish imbue kit | armor-polish temper kit |
| Leatherworker | weapon grips | leather-armor imbue kit | leather temper kit | quiver (cataloged; ships with §9) |
| Tailor | 8-slot bag | 16-slot bag; spell tome +10; embroidery imbue kit | 24-slot bag; spell tome +20; embroidery temper kit | 32-slot bag; spell tome +30 |
| Woodcarver | — (the base caster ladder is the Apprentice value) | wood-oil imbue kit | wood-oil temper kit | bows (cataloged; ship with §9) |
| Goldsmith | Rough→Cut refinement; Settings (§3.6b ladder) | trinket assembly (all six §6.2 identities); gem-setting imbue kit | gem-setting temper kit; ornament components | — (§4 cultural jewelry services ride §2.2's earned unlocks) |
| Alchemist | §3.6 Apprentice row | §3.6 Journeyman row; Apothecary Hood | §3.6 Expert row; Apothecary Garb | §3.6 Master row; Master's Regalia |

Costs follow only existing patterns — fittings 2 bars (§3.3), grips 2
leather of the item's tier (professions.md §3's cross-buy as a concrete
component item), kits ≈ 1 tier reagent + tier materials (§7), bags/
tomes/consumables unchanged. No new numbers are introduced here.

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
- **Quest and boss recipes unlock inside the same book** — cultural finishing
  operations (§4), masterworks (§6.4) and any future quest reward appear
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

### 2.3 Authored tier keystones (the zone gate)

**Reframed 2026-08-07.** The keystone is no longer a tome *ingredient*;
it is the **redemption token that opens a group in the book** (§2.2). The
materials are unchanged — they were always chosen as proof that the
player has reached the region that produces them, and that is exactly the
job the new model needs them for. Redemption is a one-off action at the
profession's workbench; the materials are consumed, nothing is produced,
the meta key advances.

Columns are **book groups**, i.e. gear tiers (§3.0):

| Profession | T2 group | T3 group | T4 group | T5 group | T6 group |
|---|---|---|---|---|---|
| Blacksmith | 6 iron bar | 6 steel bar + 2 stone core | 3 gem + 1 `group:grug_rare_trophy` | 6 embersteel bar + 2 venom sac | 6 abyssal steel bar + 2 stone core |
| Leatherworker | 6 cured leather | 6 heavy leather + 2 bear claw | 6 scaled hide + 1 rare trophy | 6 sleek leather + 2 fang | 6 nightscale leather + 2 venom sac |
| Tailor | 6 woven bolt | 6 heavy bolt + 4 spider silk | 6 silkweave bolt + 1 rare trophy | 6 silk bolt + 2 venom gland | 6 stormweave bolt + 2 sleek pelt |
| Woodcarver | 6 polished wood + 1 iron staff fitting | 6 hardened wood + 1 steel staff fitting | 6 inlaid wood + 1 silversteel fitting + 1 rare trophy | 6 lacquered wood + 1 embersteel fitting + 2 sharp feather | 6 heartwood + 1 abyssal steel fitting + 4 spider silk |
| Alchemist | 8 sunleaf + 8 gravemoss | 8 dragonweed + 2 venom gland | 8 crimson lotus + 4 stormkelp + 1 rare trophy | 8 crimson lotus + 2 venom sac | 8 stormkelp + 2 bear claw |
| Goldsmith | 4 Iron Bars + 2 Cut Quartz | 3 Steel Bars + 1 Cut Citrine + 1 Cut Garnet + 1 Cut Jade | 4 Gold Bars + 2 Emberglass | 4 Gold Bars + 2 Embersteel Bars + 2 sleek pelt | 4 Gold Bars + 2 Abyssal Steel Bars + 2 bear claw |

- **T1 opens with the profession** — no keystone; it is the tier every
  player already crafts from (§3.0.3).
- **The table is complete since 2026-08-13** (the A4 decision). Every
  T5/T6 drop is existing regional loot with both-faction sources
  (`biomes_mobs.md` §3.1/§3.2/§6): venom sac/gland from serpents and
  spiders, fang from the shared wolf table, sleek pelt from the panther
  pair, bear claw from the bear pair, stone core from the elite golems,
  sharp feather from the bird-of-prey pair, crimson lotus and stormkelp
  from both jungles/coasts. The Goldsmith rows keep their rule: ordinary
  combat proofs, never G2 gems, loose Abyssal Crystal,
  `group:grug_rare_trophy` or Fallen Crowns. The rare trophy appears
  exactly once per profession, at T4. Processed tier bars are legal
  keystone inputs and create no circularity — book groups gate
  profession recipes, never the universal bars or picks. The
  Woodcarver's fitting requirement is the §3.6a Blacksmith cross-buy as
  arrival proof; its wood grades are the universal §3.6a ladder, never a
  race wood.
- No profession keystone may make a universal pick circular.
- The **Herbalism and Gem Hunter rows are deleted** (2026-08-07):
  Herbalism merged into the Alchemist, Gem Hunter into the Goldsmith
  (professions.md §2), so the asymmetric "3 tiers"/"2 tiers" stubs have
  no owner. Their mechanics survive inside the merged professions —
  herb gathering is an Alchemist ability (§3.6), and natural-gem bonus
  yield is Goldsmith (§3.6b). The Gem Detector is retired with private-island
  treasure clusters.

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
natural play in the source region you just reached (6 iron bars ≈ one dig in
the shallow T1 band or a golem hunt; 2 bear claws ≈ 8 bear kills at 1/4). A player
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
- **Emberglass** is a real `grug_materials` item/node family. Old Mese and
  Emberstone aliases may exist only as an explicit one-time migration path;
  they are not parallel usable materials or player-facing names.
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
| T1 | Copper, Tin, mined Coal, Iron, Quartz |
| T2 | Gold; Citrine, Garnet and Jade (G1) |
| T3 | Silver |
| T4 | Emberglass; Diamond, Sapphire and Ruby (G2) |
| T5 | Abyssal Crystal |
| T6 | no universal progression resource; the tier grants deep access and better density |

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

#### 3.0.3 One item per concept — NO duplicates (binding)

**There is exactly one item per concept.** No two items may fill the same
role: there is no `default` stone sword standing next to a "Crude Sword"
from `grug_gear`. Consequences, all binding:

- **The vendor bracket catalog and the base craft ladder are the same
  items**, and they are **material-named** — Bronze Sword, Iron
  Chestplate, Steel Greaves — never bracket-named. The 72 items WP7
  shipped under the adjectives *Crude / Plain / Tempered / Reinforced /
  Superior / Grand* merge into that one ladder. That shipped naming is a
  migration source for the **rename plus
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
  and stone stay, bronze/iron/steel/silversteel/embersteel/abyssal steel
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
**Silversteel** → T5 **Embersteel** → T6 **Abyssal Steel** (§3.0.1/§3.0.2).
Vendor supply: flux. *Revised 2026-08-07*: the old four-step chain
(bronze / iron / steel / gem-tempered steel) is superseded by the
six-tier ladder, and **§10 P1's "gem-tempered steel" is retired with it**
— the T4 metal is Silversteel from a real new ore, which is exactly the
"new ore post-MVP" option P1 held open.

**Refines and enchants**: metal armor (all four slots), 1H weapons,
daggers, 2H weapons, shields. Bar costs for the base recipes: chest 5,
legs 4, head 3, feet 2, shield 4, 1H 3, dagger 2, 2H 5, staff fitting 2,
pick 3.

**Exclusive recipes** (mastery cut decided 2026-08-13, §2.1): **metal
fittings** at Apprentice (the Woodcarver cross-buy, §3.6a); **shields**
at Journeyman (no other profession makes an offhand of metal) plus the
whetstone imbue kit; the whetstone temper and armor-polish imbue kits at
Expert; the armor-polish temper kit at Master (§7's kit rule); and the
cultural/PvP operations of §4 as earned unlocks (§2.2).

Ore access follows §3.0.4's three separate checks: territory/protection, the
pick's exact maximum natural y-depth and the resource's independent minimum
harvest tier. Cosmetic strata never grant access. Natural distribution comes
from §3.0.1 and the column's `race_region`, not from a tier-matched stratum or
a lead-metal-band rule.

> **Superseded 2026-08-07 (§3.0.3):** ~~"Vendor floor sells up to the
> bronze pick — iron+ picks are smith products (mining stays open to
> all, the TOOL is the trade good)."~~ Every pick on the ladder is a base
> recipe now, so the Blacksmith has no claim on iron+ picks. Vendor stock
> is unchanged — the bronze pick stays the vendor's top tool (§3.7); a
> higher pick is **crafted, not bought**. The trade good is the
> **refined** pick: +100 % durability (§6b.2) is worth more on a mining
> tool than on anything else in the game.

### 3.4 Leatherworker (tanning rack) — leather

**Material chain**: hide + thread → leather, 1:1 per grade. Authored grades are
**T1 light leather, T2 cured leather, T3 heavy leather and T4 scaled hide**;
decided 2026-08-13: **T5 sleek leather** (from the panther's sleek pelt —
`biomes_mobs.md` §3.1/§6, both continents via jungle fringe/deep jungle) and
**T6 nightscale leather**, a composite of scaled hide + sleek pelt following
the Tailor's T4 silkweave precedent (serpents and panthers carry the
level-51–60 zones on both continents; no new mob is required).

**Refines and enchants**: leather armor, all four slots. Base recipes use
the §3.1 shapes at jerkin 6 / pants 5 / hood 4 / boots 3 leather. Its MVP
wearer is the **Warrior** (light avoidance set, §3.8 — decided
2026-08-13); the Rogue joins in Phase 2.

**Exclusive recipes** (mastery cut decided 2026-08-13, §2.1): **weapon
grips** at Apprentice — 2 leather of the item's tier, the
professions.md §3 cross-buy as a concrete component item; the
leather-armor imbue kit at Journeyman and its temper kit at Expert
(§7); and at Master the **quiver** — a bag-slot item that holds only
arrows, catalogued here and shipping with §9's Phase-2 bow decision.
The bow itself is a Woodcarver product (§3.6a, §9), the quiver is not.

Supply loop as decided: the ×5 leather tag (professions.md §3), Tailors
buy leather for bags, Alchemists for apothecary gear, Woodcarvers for
grips.

### 3.5 Tailor (tailor bench) — cloth, bags, the caster offhand

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
- **Embroidery kits** (§7): imbue at Journeyman, temper at Expert
  (mastery cut decided 2026-08-13, §2.1). With one bag size per tier and
  the tome at J/E/M, the Tailor's signature row is full at every tier.

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

**Material chain**: wood, including the per-race woods of biomes_mobs §5 —
silverwood and gravewood among them. Signature woods remain cultural inputs,
not a mandatory universal tier ladder. The six processed grades are decided
(2026-08-13): **Seasoned → Polished → Hardened → Inlaid → Lacquered →
Heartwood** (T1→T6), each craftable from any `group:wood` — both continents
reach every grade by construction, and the per-race woods stay a cosmetic/
cultural skin on top, never a tier gate. These grade words are the item
names WP29 uses (§3.8): a Hardened Staff, a Heartwood Orb.

**Refines and enchants**: staves, wands, scepters, orbs — the whole
caster weapon family of §3.2, main hand, 1H and 2H.

**Exclusive recipes** (mastery cut decided 2026-08-13, §2.1): the
Apprentice cell is deliberately empty — the base caster ladder itself is
the Apprentice value (§3.0.3); **wood-oil kits** (§7) arrive at
Journeyman (imbue) and Expert (temper); **bows** are the Master line
from Phase 2 (§9 — this replaces the old "Bowyer = Leatherworker split"
assignment; the quiver stays Leatherworker, §3.4).

**Cross-buy: the Woodcarver buys metal fittings from the Blacksmith.**
The §3.2 family is literally called "metal-shod staff"; from T2 up every
caster weapon needs a Blacksmith-made fitting of its own tier. That is
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

**Mastery cut** (decided 2026-08-13, §2.1): Rough→Cut refinement and the
Settings of the ladder below at Apprentice; **trinket assembly** (all
six §6.2 identities — which material tier is the book group's business,
§2.2) and the gem-setting imbue kit at Journeyman; the gem-setting
temper kit and **ornament components** at Expert; Master adds no new
row — §4's cultural jewelry services ride §2.2's earned unlocks.

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
Last Light and Apothecary Loop. The complete tier list opens with the matching
book group: all six T4 recipes are learned together, so foreign-gem acquisition
rather than recipe rarity is the gate. No recipe scroll, reputation grind or
enemy unlock is involved. Goldsmith keystones are specified in §2.3 and never
consume G2 gems or masterwork trophies.
Each core trinket recipe consumes only its tier-appropriate Setting and the
listed Cut gem(s): there is no special-specific herb, catalyst, mob drop,
trophy or cross-profession component.

### 3.7 Universal secondaries & vendor floor

Neither of these costs a main profession slot (professions.md §1).

- **Cooking** (trainer, free): cooked foods use regional ingredients and the
  Cooking recipe book described below.
  **Raw food restores; cooked food restores AND buffs** (structure decided
  2026-08-08; restore mechanics and the per-group lists decided 2026-08-13
  with E21). `combat_stats.md` §5 carries the same rules from the recovery
  side; the two must not drift apart.
  - **A food restore is a buff, not a standing channel** (2026-08-13,
    replacing the old resting-channel delivery): eating grants a
    restore-over-time effect that **tolerates movement** but is
    **canceled by entering combat** (PvE or PvP, the shared `in_combat`
    window) — the remaining restore is lost. **Eating in combat is
    refused** (message, nothing consumed — the potion's full-HP refusal
    pattern). Exactly one food restore runs at a time; eating again
    replaces it.
  - **Raw / plain food: regeneration only, no buff** — **4 % max HP/s
    for up to 25 s** (a full heal if uninterrupted; the solo detour,
    unchanged in rate).
  - **Cooked food gives both**: the serving's authored percentage of max
    HP, delivered at **8 % max HP/s**, plus **Well Fed** — the buff
    persists into combat, only the restore dies. The instant slot stays
    the Alchemist's (§3.6 Healing Potion — 30 % max HP instantly, usable
    in combat, 60 s shared cooldown): the potion holds the **in-combat
    monopoly**, food is out-of-combat acceleration, and **both stay
    percent-based** — no absolute values, no consumable treadmill
    (`combat_stats.md` §5; Max HP = 20 + 2×(level−1) + Str spans ~22 to
    ~170, so one absolute item could never serve both ends).
  - **Only one food buff is active at a time, and the most recently
    eaten food wins** — eating again *replaces* the running buff; food
    buffs never stack and never extend one another. This is the food-side
    twin of §3.6's "one elixir active at a time" (§10 P3), and a food
    buff and an elixir still stack **with each other**, exactly as
    before.
  - Every cooked-food buff occupies the single **Well Fed** category governed
    by the replacement rule above. **Well Fed is decided (E21)**:
    **I = +1 Str and Int** (T1–T2 dishes), **II = +2** (T3–T4),
    **III = +3** (T5–T6), **15 minutes**. The old "+5 Strength, 5 min"
    worked example is superseded — it was the shape, this is the size.

  **Cooking gets a recipe book** (2026-08-07, §2.2): the same six T1–T6
  groups and the same level gates as a profession book, but **no
  keystones** — a cooking tier opens on its **ingredients**, which are
  regional, so **T6 cooking needs ingredients that only exist in level
  50+ areas**. Tier unlocks are explicitly wanted as quest goals ("find
  cocoa in the jungle"). Cooking is free and universal *and* gated; the
  book is what makes both true at once.

  **The six groups are decided (E21, 2026-08-13)** — gate ingredient,
  recipes, restore per serving, Well Fed step; every gate ingredient
  exists on both continents (`biomes_mobs.md` §2/§6):

  | Group | Gate ingredient | Recipes | Restore/serving | Well Fed |
  |---|---|---|---|---|
  | T1 | potato/corn | Cooked Meat / Cooked Fish; Hearty Stew (meat + potato/corn) | 20% | I |
  | T2 | berries (apples as Accord extra) | Berry Preserve (2 berries); Fruit-Glazed Roast (meat + fruit) | 24% | I |
  | T3 | mushrooms (found-only) | Mushroom Skewer (2 mushrooms); Forager's Pot (mushroom + meat + potato/corn) | 28% | II |
  | T4 | melon + marshbloom | Marshbloom Chowder (fish + marshbloom); Hunter's Feast (2 meat + melon + mushroom) | 32% | II |
  | T5 | rock salt + stormkelp | Salt-Crusted Fish (fish + rock salt); Kelp-Wrapped Roast (meat + stormkelp + rock salt) | 36% | III |
  | T6 | wild cocoa | Jungle Cocoa (2 wild cocoa + rock salt); Grand Feast (2 meat + wild cocoa + stormkelp) | 40% | III |

  A serving may exceed the potion's 30% because the two no longer
  compete — food never works in combat. One restore value per **group**,
  not per dish. The worked "potatoes with boar steak" example is the T1
  Hearty Stew at 20%; its old 30% reading predates this table.
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
  Embersteel Sabatons, Abyssal Steel Greataxe), **cloth items take their
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
  other gathering tools, bars, furnaces, repair and profession keystones are
  excluded. Refinement and ordinary affixes do not charge the base G2 again.
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
  game, strictly below crafted-fine's 0.30–0.80) and priced above the Common
  baseline by the authoritative quality multiplier. That is
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
  (`inventory_equipment.md` §2: Warrior 3 / Mage 1 / Priest 1), so
  leather (rank 2) ships as the **Warrior's light set**: §6.2's leather
  pool (+Dex, +HP, +crit%, +dodge%) against metal's (+Str, +HP,
  +armor%, +dodge%) is a real mitigation-versus-avoidance choice, and
  §3.1 already prices leather below metal at equal tier, so plate stays
  the mitigation king. The curve sits in the generator; the 24 leather
  registrations land with WP29's catalog merge. Under the §3.0.3 merge
  this covers the **craft** ladder too — one catalog, so the line ships
  vendor and craft at once (§3.4). The Rogue (Phase 2) later joins as
  the intended primary wearer.
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
  architecture, quests and trade, plus a higher-yield source in its contested
  level-31+ zones or deep race-region column. The concentrated source requires
  T4 harvesting; an ordinary surface source retains its natural axe/shovel/
  hand-gathering behavior.
- A material is not forced into every cultural object: Gravewood furniture
  need not consume Gravesalt. Moonresin uses a cool silver-blue/pearlescent
  palette; Spirit Resin uses warm amber or toxic green.
- Foreign cultural materials are used almost exclusively for optional
  level-40+ PvP counters. They never enter universal bars/tools, ordinary G2
  base costs, ordinary recovery consumables, solo-leveling requirements or
  profession keystones. Regional G2 demand and optional cultural-counter
  demand are independent economies.
- Signature woods remain universal `group:wood` inputs. Their distinct value
  is cultural builds, furniture and optional recipes, never mandatory tool
  progression.

### 4.2 Cultural finishing

A cultural finish is a permanent per-stack workstation operation. It preserves
the base item, material tier, refinement, quality, durability, ordinary
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
- Direct player production requires the base family's owning Blacksmith,
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
| Maximum HP | +6 |
| Maximum Mana | +10 |
| Crit / Dodge | +1 percentage point |
| Armor | +1 armor point (= 1 percentage point before cap) |

Primary attributes, HP and Mana round half-up to whole numbers. Crit, Dodge
and armor show one decimal where needed. Every tier must be strictly stronger
in effective and displayed value; if a conversion would collapse two adjacent
tiers, its display/conversion quantum changes. A two-handed weapon retains the
five-point weapon budget and receives no compensation for its unavailable
offhand.

The resulting T6 per-stack values are:

| Culture | Weapon | Offhand | Head | Chest | Legs | Feet |
|---|---|---|---|---|---|---|
| Human | +15 Str | +12 Int | +20 Mana | +18 HP | +3 armor | +6 Dex |
| Dwarf | +30 HP | +4 armor | +6 Str | +18 HP | +3 armor | +6 Str |
| Elf | +5% Crit | +4% Dodge | +2% Crit | +9 Dex | +9 Dex | +2% Dodge |
| Orc | +15 Str | +24 HP | +2% Crit | +18 HP | +9 Str | +2% Crit |
| Troll | +15 Int | +40 Mana | +12 HP | +18 HP | +3% Dodge | +2% Dodge |
| Undead | +15 Int | +4% Crit | +20 Mana | +30 Mana | +9 Int | +2% Crit |

All finish, affix, attribute and base-equipment sources add before the existing
final caps: Crit 30%, Dodge 30% and armor 60%. Overcap remains on its source
stacks but has no combat effect. The Character page displays effective and raw
values, for example `Armor 60% (67% raw)`; there is no reroll, overflow
conversion, diminishing-return curve or cap increase. The theoretical T6
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
   elixir and Well Fed, but it shares the global 60-second potion-use clock and
   does not require missing HP/Mana. Apothecary Loop changes neither its
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
| Contested approaches 31–40 | equivalent T4 access plus practical foreign-G2 routes | T4, improved windows on qualifying elites | all six race approaches and the Holy Grounds entry are contested |
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
| Apex boss / race King | — | 100% | boss |

A dropped item that carries enchants is by definition also **refined**
(§6b.3 admits no other state) — which is why the refinement word never
appears in a drop's name (§6b.4).

### 5.2 Named rares (spawn rules decided in biomes_mobs §3.3)

2–4 h respawn, patrol routes, faction-wide broadcast. Loot per kill:
guaranteed Uncommon (rare window) + 25% Rare + **100% signature trophy**
(`group:grug_rare_trophy` — Grimtusk's Tusk, Silkfang's Gland, …): a
qualifying optional masterwork ingredient and, where explicitly listed, a
profession-book proof. It never enters a universal bar or pick (§2.3,
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
- No universal bar, pick, profession keystone or ordinary base gear requires a
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
`grug_upgrades` (0–2, §7), `grug_req_level`, and separate structured
masterwork, cultural-finish and PvP-special state where applicable. These
channels never overwrite one another. Exact migration keys are implementation
owned; one idempotent description/stat regeneration path reads them all.

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

**Ordinary equipment descriptions always show the BASE stat** (decided 2026-08-07 in
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

Cultural finish and PvP-special lines are displayed separately, naming their
culture/target and exact value. Trinkets are the exception to the ordinary
base/refinement model: §6.2 gives them no base-stat line, refinement or
durability, only their one prefix, one suffix and authored special.

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

Ordinary equipment keeps the no-duplicate-stat rule inside its up-to-four
prefix/suffix slots. Cultural finish and PvP-special stats are separate named
sources and may match an ordinary affix; all sources add before final caps.

#### Trinket exception: one prefix, one suffix, one special

A passive trinket has exactly:

- one prefix rolling **Strength, Intelligence or Dexterity**;
- one suffix rolling **maximum HP, maximum Mana or Crit**;
- one authored trinket special.

The pools make nine possible prefix/suffix pairs and structurally prevent a
duplicate stat. Armor, Dodge and attack speed are excluded. Rolls reuse
§6.3's ordinary equipment ranges for the item's ilvl band and source window;
prefix and suffix roll independently. A trinket has **no separate base-stat
line, armor, durability or refinement state**. Material tier scales only the
authored special. Common/Uncommon/Rare presentation may communicate source and
roll window, but never changes the fixed channel count or multiplies a special.
This is the explicit exception to §6b's ordinary refine-before-enchant rule.

Register exactly six ordinary core identities, each craftable in T1–T6.
Setting, tier, item level, required level, affix rolls, special strength,
generated display name/color and image composition are per-stack data, yielding
six item ids rather than 36:

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
  HP. It grants an absorb from post-hit maximum HP and cannot save an already
  lethal hit.
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
| crafted-masterwork | 0.60–1.00 | crafted Rare incl. Grudgeforged items |
| boss | 0.80–1.00 | apex hoards, race Kings |

**Combined cap policy (re-run 2026-08-12).** Ordinary affixes, trinket
prefixes/suffixes, cultural finishes, attributes and base equipment all add
before the unchanged final caps: Crit 30%, Dodge 30% and armor 60%. Values over
a cap remain on their source stacks but add no combat power. The Character page
shows both effective and raw totals, and no automatic reroll, overflow
conversion, diminishing return or cap increase hides the waste.

The old eight-identical-affix-slot calculation is retired: each trinket now has
one primary prefix and one HP/Mana/Crit suffix rather than four ordinary slots.
At T6, two trinkets can therefore add at most two direct Crit suffixes, while
the six ordinary combat stacks retain their family pools. Cultural finishes
add at most approximately +14.8 Crit points (including compatible Dexterity),
+9.9 Dodge points or +7 armor points across a freely mixed T6 six-slot set.
These maxima can intentionally overcap a specialized build. Full plate plus a
shield may already reach 60% armor, so Dwarf armor finishes can be partly or
fully wasted there and remain useful to lighter, incomplete or two-handed
configurations. The cap/demand audit evaluates all three source channels
together and verifies at least two desirable finish cells per culture.

### 6.4 Crafted quality (how crafting reaches Uncommon/Rare)

Re-stated 2026-08-07 against the refinement model of §6b; the windows and
the quality thresholds are unchanged.

- **Base recipes → Common**, no enchants, craftable by everyone
  (§3.0.3). This is the reliable, repairable baseline and the item a
  vendor sells.
- **Refinement → Common, refined** (§6b.1/§6b.2). Still Common — a
  refined item has no enchants yet, so it cannot be blue. Professions
  only.
- **Fine recipes** = refine + **1–2 affixes** plus an authored tier reagent
  (venom sac, slime gel, sleek pelt, etc.) → **Uncommon**, crafted-fine
  window. A generic Cut Gem is not charged automatically: T4–T6 base combat
  gear already pays its specific G2, and refinement/affix application never
  repeats that tax.
- **Masterwork recipes** = refine + **3–4 affixes** (Expert/Master only;
  + one qualifying named-rare trophy or Fallen Crown in the trophy slot) →
  **Rare**, crafted-masterwork window. The trophy is consumed when the final
  masterwork state is applied; an Abyssal Steel item names that state
  **Grudgeforged**. Cultural finishes and PvP specials remain separate and may
  coexist. This keeps "better gear comes
  from crafting or hard bosses" literally true: the two 0.60–1.00 windows
  are crafting and bosses.

The mapping is exact: §0's **Uncommon = 1–2 enchants, Rare = 3–4** and
§6b.4's **2 prefixes + 2 suffixes = 4 slots** are the same budget counted
two ways. Trinkets follow §6.2's fixed two-affix exception rather than this
ordinary equipment count.

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
- **Prefixes** name a stat the item gives its wielder as an adjective;
  **suffixes** do the same in the genitive. The complete vocabulary is
  decided (2026-08-13): **exactly one prefix word and one suffix word
  per §6.3 stat, no synonyms** — the word says which stat,
  unambiguously:

  | Stat | Prefix | Suffix |
  |---|---|---|
  | +Str | Heavy | of the Bear |
  | +Dex | Quick | of the Fox |
  | +Int | Clever | of the Owl |
  | +HP | Stout | of the Ox |
  | +Mana | Attuned | of the Raven |
  | +crit% | Lucky | of the Eagle |
  | +attack speed% | Swift | of the Hornet |
  | +dodge% | Elusive | of the Cat |
  | +armor% | Stalwart | of the Tortoise |

  **The stat names are §6.2's own, verbatim** (aligned 2026-08-08: the
  ox used to be written "+health", which is not a stat this game has).
  **§6.2 remains the sole legality source**: an affix is legal on an
  item family iff its stat is in that family's pool (the +armor% words
  can therefore only ever appear on metal armor), and the trinket
  exception in §6.2 constrains its two slots the same way. Every word
  maps to exactly one stat — there is **no poison stat** in this game
  (see §6.2 and `combat_stats.md` §2; poison arrives with the Rogue in
  Phase 2, `classes.md` §6), and an affix word for a stat nothing
  consumes is a bug, not flavour.
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
- **An enchanted item still declares its refined state in the tooltip**
  (decided 2026-08-13): one grey line, "Refined", above the affix lines —
  no name-length cost, no art. A refined but unenchanted item needs no
  such line; its name still carries the refinement word. §6b.7's special
  variants state their authored effect in the same tooltip block.
- The affix **words** are the display layer; the rolled **values** live
  in `grug_ench` exactly as before (§6.1) and are shown one per line
  under the grey stat lines. The word says which stat, the line says how
  much.

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

### 6b.6 Ordinary-equipment quality follows the slot count

No new rule — §6.1's budgets, read through the affix model:

| Affixes | Quality | Colour |
|---|---|---|
| 0 | Common | white |
| 1–2 | Uncommon | blue |
| 3–4 | Rare | yellow |

So an Apprentice and a Journeyman produce Uncommon ordinary items; an Expert
and a Master produce Rare ones. The roll **values** come from the §6.3 band of
the **item's** ilvl (sharpened 2026-08-08), in the crafted-fine or
crafted-masterwork window (§6.4): mastery buys the number of slots on
this table, never the size of what goes into one. Trinket quality instead
communicates source/roll window and never changes its fixed two-affix-plus-
special shape (§6.2).

### 6b.7 Special variants

A profession can turn a **refined but not yet enchanted** item into a
**special variant** with an effect of its own — an "Iron Frost Armor"
that slows attackers, for instance.

- An ordinary special variant **keeps its full 2 prefix + 2 suffix slots on
  top of its one authored effect.** The effect is not one of the four. It is
  also distinct from §4's cultural-finish and PvP-special metadata; every
  legal combination participates in the combined cap audit.
- The input must be unenchanted: the special variant is a step *between*
  refinement and enchanting, not an alternative to either.
- **Visual treatment**: adapt VoxeLibre's armor **trim/colouring** system
  (`mcl_armor/trims.lua`, §1.2) — a template item plus a colour overlay
  baked onto the armor texture, e.g. Iron armor carrying a diamond trim.
  That gives every special variant a look without one texture per
  combination.
- **Tooltip statement** (decided 2026-08-13 with the refined-marker
  rule): a special variant states its authored effect as one grey
  tooltip line in the same block as §6b.4's "Refined" line, above the
  affix lines — the effect is readable without art or name cost.

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
- **Kit mastery rule** (decided 2026-08-13): imbue kits unlock at
  Journeyman and temper kits at Expert; a profession's second kit
  family — the Blacksmith's armor polish — sits one tier later (imbue
  Expert, temper Master). §2.1's signature table is the authoritative
  cut.

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

Core supplies remain simple fixed-price goods. A profession replacement book
costs 25c and immediately reflects player-meta progression. Finder-item rows
are deleted; no Dowsing Rod or Gem Detector is sold or crafted.

### 8.3 Recurring sinks

- **Repair:** broken gear stops functioning but is never destroyed. Repair
  cost scales with item level/quality on the same tiered money axis. The wear
  target remains approximately 3,000 combat events per ordinary item and
  6,000 for a refined item; exact prices participate in the reliable-net-
  income measurement rather than using the retired flat formula.
- **Respec:** repeatable at the class trainer and rising with level.
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

## 9. Bow and arrow item foundation (inactive Phase-2 substrate)

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
- No current or committed class consumes a bow baseline. The item/ammo/entity
  foundation is license-clean and has an owner, but it creates no player-facing
  bow, arrow or quiver registrations or recipes until a class package explicitly
  adopts it.

## 10. Historical decision log (non-authoritative migration context)

This section records how shipped and staged work reached the current design.
It deliberately preserves retired names and mechanisms so migrations and
reverts can be understood. **Nothing in §10 is an active target rule; §§0–9
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
would have been needed to mine the material the T6 pick is made of. This
records the shipped WP25 legacy placement only; the target natural-depth and
harvest-tier rules in §3.0.1/§3.0.4 supersede its engine-level mechanism and
WP43 owns the migration.

**D16 — The depth gets no drop layer of its own** (resolves the loot half
of `TODO-design-depth.md` D10). Underground mobs drop what their families
drop on the surface; being deep adds nothing (§5). A T6 gear layer down
there would have been a third 0.60–1.00-window source with neither a
crafter nor a boss behind it, against §0's promise that the best items
come from crafting and hard bosses — and the band already pays the
endgame *material* that the crafted endgame item is made of. Rejected:
T6 gear drops on the level-60 deep roster.
