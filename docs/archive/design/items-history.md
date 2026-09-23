# Items and crafting — archived research and decision history

Archived from `docs/design/items_crafting.md` on 2026-09-23 during
documentation cleanup round 20. Source baseline: `e2295c59` (original
pre-extraction content descended from the 2026-08-06 through 2026-09-21
design history). This file preserves provenance, source citations, rejected
alternatives and superseded wording. It is not living design authority.

Current rules remain in [items_crafting.md](../../design/items_crafting.md)
and its linked topical design documents.

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

**D5 — Refinement was the profession's product.** The 2026-08-07 form used
+15% base damage or armor, doubled durability and four affix slots. An interim
2026-09-20 revision reduced that to one prefix and one suffix while retaining
refinement. Round 13 superseded the whole refinement model on 2026-09-21:
refinement, its hidden stat/lifetime bonuses and Imbue/Temper no longer exist.
The active deterministic named-enchant rules are in §6b and
[crafting_equipment_revision.md](../../design/crafting_equipment_revision.md#enchanting).

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
