# Items, Crafting & Loot — Full Design Spec

**Decided spec** (authored + approved 2026-08-06; the five flagged
points P1–P5 were all decided per recommendation — resolutions in §10).

Feeds: WP5 (loot/enchant rolls), WP7 (traders/consumables), WP10
(professions/workbenches), WP22 (repair). Crafting mechanics frame:
`inventory_equipment.md` §4 (3×3 grid, multi-stage, craft_predict
unlock gate, workbench proximity, recipe book UI) — unchanged here.

## 0. Decided anchors (2026-08-06, binding — preserved)

- **Quality tiers: Common (white), Uncommon (blue), Rare (yellow),
  Unique (orange)**. MVP ships without Uniques, but quality field +
  enchant list live in item meta from day one.
- **Uncommon = 1–2 weak enchantments; Rare = 3–4 enchantments.**
- Vendors sell simple (Common) gear — available but painfully expensive;
  better gear comes from **crafting** or **special bosses**.
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
  player-meta unlock) closes that hole; the adaptation in §2 keeps the
  chain and adds the hard gate.

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
| Armor | `mods/ITEMS/mcl_armor` | GPLv3+ | we only need the equip/update + texture-layer pattern (slots already ours, WP15) — LOW |
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

## 2. Profession progression: tiers & the tome chain

**One mechanism only: the tome chain. No skill-up grind, no per-recipe
unlocks.** (Skill-ups were considered and rejected: a second progression
currency that fights the 10–20 h pace; the chain already gates by zone
materials, which IS the level gate.)

### 2.1 Four tiers, aligned to the rings

| Tier | Name | Item levels | Learn at ~char level | Ring that feeds it |
|---|---|---|---|---|
| 1 | Apprentice | 1–15 | 1 (trainer) | safe core + inner |
| 2 | Journeyman | 16–30 | ~15–18 | inner (+depth mining) |
| 3 | Expert | 31–45 | ~30–33 | outer |
| 4 | Master | 46–60 | ~46–50 | coast + named rares |

Learning tier n unlocks that tier's **whole recipe list** (browsable in
the recipe book UI) including the recipe for the **next tome**.

### 2.2 The tome (LotT chain, adapted to our unlock model)

Item: `grug_items:tome_<prof>_<n>` ("Journeyman's Tome of Smithing"),
tool, stack_max 1.

- **Right-click = learn + browse**: writes the unlock (player meta
  `grug_prof:<prof> = n`, idempotent) and opens the recipe book UI at
  that profession — the tome IS the physical recipe book (LotT's
  guide-viewer role) and is **not consumed by reading**.
- **Reading tier n requires learned tier n−1** in that profession (and
  the profession itself, i.e. one of the 2 main slots) — else a chat
  message, nothing happens. No tier skipping.
- **The chain: crafting the tier-n+1 tome consumes the tier-n tome**
  as grid ingredient (LotT `protection_book` pattern) + 4× blank
  parchment (vendor) + a tier keystone (below), at the profession's
  workbench. Crafting it requires learned tier n (craft_predict).
- **Tomes are tradeable**: a master can buy a fresh Apprentice tome
  (25c, trainer) and forge it up into a Journeyman/Expert tome to sell —
  the buyer still needs the previous tier to read it, so the ladder
  holds while tome-crafting becomes an endgame product line.
- Lost your tome? The job trainer sells a replacement of your CURRENT
  learned tier (1s/3s/10s for T2/T3/T4) — meta is authoritative, the
  item is interface + ingredient.
- Unlearning a profession (switch at trainer, professions.md §1) wipes
  the meta key — progression of the dropped profession is lost (as
  decided); tomes in inventory become unreadable paper for you.

### 2.3 Tier keystones (the zone gate — materials, exact)

| Profession | T2 tome adds | T3 tome adds | T4 tome adds |
|---|---|---|---|
| Smithing | 6 iron bar | 6 steel bar + 2 stone core | 3 gem + 1 `group:grug_rare_trophy` |
| Leatherwork | 6 cured leather | 6 heavy leather + 2 bear claw | 6 scaled hide + 1 rare trophy |
| Tailoring | 6 woven bolt | 6 heavy bolt + 4 spider silk | 6 silkweave bolt + 1 rare trophy |
| Alchemy | 8 sunleaf + 8 gravemoss | 8 dragonweed + 2 venom gland | 8 crimson lotus + 4 stormkelp + 1 rare trophy |
| Herbalism (3 tiers) | 12 sunleaf + 12 gravemoss | 12 dragonweed + 6 marshbloom | — |
| Gem Hunter (2 tiers) | 3 gem + 2 stone core | — | — |

`group:grug_rare_trophy` = the signature drop any **named rare** carries
(§5.4) — every named rare on your own continent qualifies; both
factions always have sources (biomes_mobs §3.3 lists ≥4 per continent).
Herbalism tiers gate *gathering* (punching a T2 herb without tier 2
yields nothing + hint message); Gem Hunter tier 2 raises the bonus gem
chance 10%→20% while mining (WP10). **Cooking and First Aid have no
tomes**: the trainer teaches them free, all recipes at once; materials
are the only gate (universal valve skills stay frictionless).

### 2.4 Pacing check (10–20 h to level 60)

~10–20 min per level → ring transits land at: L15 after ~2.5–5 h, L30
after ~5–10 h, L45 after ~7.5–15 h. Each keystone is ~30–60 min of
natural play in the ring you just reached (6 iron bars ≈ one dig to
y −300 or a golem hunt; 2 bear claws ≈ 8 bear kills at 1/4). A player
who levels one crafting + one gathering profession alongside questing
reaches Master at 50–55 without detour grinding; a pure fighter can buy
tomes/gear from crafters instead — both paths inside the 10–20 h
envelope. **Intended gear cadence: a visible upgrade every 45–90 min**
(quest rewards + 3% world drops between the four crafted tier sets),
and at 60 the professions stay load-bearing via repair (§8), consumables
(elixirs/bandages/potions), upgrade kits (§7), masterworks and race
signatures (§4).

## 3. Item catalog per profession per tier

Multi-stage everywhere (decided): ore → bar → component → item; hide →
cured leather; cloth → bolt. Stages are base recipes (grid anywhere);
the final item needs the workbench nearby.

### 3.1 Armor curve (proposal — consistent with mob dmg 2 + 0.4L)

1 armor point = 1% damage reduction; equipped pieces sum, **clamped at
the 60% cap** (combat_stats §2: endgame plate 60%, cloth ~15%). Set
totals (4 pieces: chest/legs/head/feet split ≈ 35/27/22/16%):

| Class (profession) | T1 | T2 | T3 | T4 | T4 per piece |
|---|---|---|---|---|---|
| Metal (Smith) | 16 | 29 | 42 | 55 | 19/15/12/9 |
| Leather (LW) | 11 | 20 | 30 | 40 | 14/11/9/6 |
| Cloth (Tailor) | 5 | 8 | 11 | 15 | 5/4/3/3 |
| Shield (Smith, T2+, Warrior) | — | 4 | 5 | 5 | — |

Check at 60: full plate+shield = 60% → mob hit 26 → 10.4 eff. vs 325 HP
(≈31 hits); cloth Mage 15% → 22.1 vs 148 HP (≈7 hits) — tank/squishy
spread as designed. Drop gear uses the same table at its ilvl bracket;
quality adds enchants, never base armor.

### 3.2 Weapon table (curve: 1H dmg = 4 + 0.35 × ilvl, combat_stats §2)

Tier ilvls 12/27/42/57; fpi = full_punch_interval.

| Family | fpi | dmg factor | T1 | T2 | T3 | T4 |
|---|---|---|---|---|---|---|
| 1H sword / mace / axe | 1.0 | ×1.0 | 8 | 13 | 19 | 24 |
| Dagger | 0.7 | ×0.7 | 6 | 9 | 13 | 17 |
| 2H greataxe / warhammer | 1.4 | ×1.5 | 12 | 20 | 28 | 36 |
| Metal-shod staff (caster 2H) | 1.4 | ×1.2 | 10 | 16 | 23 | 29 |

2H DPS ≈ 1.07× of 1H — pays for the empty offhand. Wands/orbs stay
**drop-only** in the MVP (WP5 class items); the Tailor tome (below) is
the craftable caster offhand. Weapons carry `grug_req_level = ilvl`.

### 3.3 Blacksmith (forge) — metal weapons, metal armor, tools

Materials: T1 **bronze** (copper+tin, any depth ≤ y 0), T2 **iron**
(y ≤ −300, outer-ring surface veins, or golem drops 1/2), T3 **steel**
(1 iron + 2 coal, furnace), T4 **gem-tempered steel** (steel + gem +
flux at the forge — no new ore, see §10 P1). Vendor supply: flux.

Per tier: 1H sword, 1H mace, dagger, 2H, 4 armor pieces; T2+ adds
shield + staff; picks: bronze/iron/steel/gem-tipped. Bar costs: chest 5,
legs 4, head 3, feet 2, shield 4, 1H 3, dagger 2, 2H 5, staff 2 (+2
wood), pick 3. Ore access gating: stone pick → copper/tin/coal; bronze
→ iron; iron → gold/gems (y ≤ −600 or coast veins); steel → abyssal gem
nodes (housing depths). Vendor floor sells up to the bronze pick —
iron+ picks are smith products (mining stays open to all, the TOOL is
the trade good).

### 3.4 Leatherworker (tanning rack) — dex gear

Stage: hide + thread → cured/heavy/scaled leather 1:1. Sets per tier
(jerkin 6 / pants 5 / hood 4 / boots 3 leather): T1 light leather, T2
cured leather, T3 heavy leather, T4 scaled hide + heavy mix. T2+ armor
kits (§7). Quiver (bag-slot item for arrows) is catalogued but ships
with §9's Phase-2 decision. Supply loop as decided: LW ×5 leather tag,
Tailors buy leather for bags, Alchemists for apothecary gear.

### 3.5 Tailor (tailor bench) — cloth armor + bags + caster offhand

Stage: 2 cloth + thread → bolt. T1 linen scrap → patch bolt (zombies
drop scraps from L1 — Tailors start in the safe core), T2 linen cloth →
woven bolt, T3 heavy cloth → heavy bolt, T4 heavy + spider silk →
silkweave bolt. Sets per tier: robe 6 / leggings 5 / cowl 4 / slippers
3 bolts. **Bags** (inventory_equipment §3): medium 16 slots = T2 (8
woven bolts + 2 cured leather), large 24 = T3 (10 heavy bolts + 4
spider silk + 2 heavy leather); the small 8-slot bag stays vendor-only
(floor rule). T2+ **spell tome offhand**: +10/+20/+30 mana (T2/T3/T4),
cloth + parchment + leather binding.

### 3.6 Alchemist (alchemy table) — potions, elixirs, apothecary gear

Herb map: T1 sunleaf/gravemoss (inner), T2 dragonweed/marshbloom
(outer), T3 crimson lotus/stormkelp (coast) — biomes_mobs §2/§6.
Vendor supply: vials. All effects percent-based or flat-small
(combat_stats §5: no consumable treadmill). **One shared 60 s cooldown
for instant potions; one "elixir" buff active at a time** (§10 P3).

| Tier | Recipes (2 herbs + vial unless noted) |
|---|---|
| T1 | Healing Potion (instant 30% HP — the combat_stats standard; vendor's weak 15% stays the floor), Mana Potion (instant 30% mana) |
| T2 | Elixirs of Might/Wisdom/Grace (+2 Str/Int/Dex, 15 min), Antivenom (cures poison — serpent/spider counter; dragonweed + venom gland) |
| T3 | Greater Elixirs (+4), Cat's-Eye Elixir (night vision 10 min — the enemy-territory raid tool vs the R2 no-torch rule), Deepwater Draught (water breathing 10 min; stormkelp), Swiftness Draught (+8% speed, 15 s — deliberately short; mobs must stay faster, flag §10 P4) |
| T4 | Supreme Elixirs (+6), Stoneskin Flask (+4% armor, 30 min), Sovereign's Flask (§4, Human signature) |

**Apothecary gear** (the requested alchemist gear; cloth-class armor
values, cross-buys leather + bolts): T2 Apothecary Hood, T3 Apothecary
Garb (chest), T4 Master's Regalia (chest, Rare, replaces Garb). Worn
pieces add +10% potion/elixir duration and +1 elixir attribute each
(max 2 pieces counted) — profession identity you can see. Template:
slot pieces à la mcl_armor + effect hooks à la mcl_potions (both §1.2).

### 3.7 Universal secondaries & vendor floor

- **Cooking** (trainer, free): cooked meat/fish (T1), Hearty Stew
  (T2: meat + potato/corn), Hunter's Feast (T3: meat ×2 + melon +
  mushroom). Eating cooked food grants **Well Fed: +1/+2/+3 Str AND
  Int for 15 min** by tier (stacks with one elixir). Raw food still
  fuels resting regen (combat_stats §5) — cooking adds the buff, not
  the regen.
- **First Aid** (trainer, free): Linen/Heavy/Silk Bandage — channel
  6 s (damage interrupts), restores 15%/30%/45% HP, then 30 s
  "recently bandaged". Cloth competes with Tailoring demand — intended.
- **Vendor floor stock** (Common, ilvl ≤ 5): worn shortsword (dmg 4),
  padded shirt set pieces (armor 2/1/1/1), small bag (8), weak healing
  potion (15%), wooden/stone tools, bronze pick, torches, job supplies
  (thread/flux/vial/parchment/whetstone blank). Everything above:
  player-crafted (floor rule).

Every craft output carries `_grug_sell_price` with the **anti-loop rule:
vendor value of a crafted item < summed vendor value of its
ingredients** — vendors are a floor, never a factory profit.

## 4. Race-exclusive signature recipes (top end, one per race)

Gate: crafter's race (player meta, checked in craft_predict) + Master
tier + the recipe. **Production is race-locked; the item is tradeable
and wearable by anyone in the faction** — that makes every
race+profession combo a market niche. All are Rare quality, ilvl 60,
rolled at the crafted-masterwork window (§6.3), **first enchant fixed**
(signature stat), remainder rolled. Shared mats: 2× abyssal gem
(housing depths, §5.5) + tier-4 bases + one specific trophy.

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
per §6.3, gear-drop ilvl = mob level. Ring → materials is binding via
biomes_mobs §6; this table adds the gear/special layer:

| Ring (levels) | Materials (recap) | Gear drops | Special |
|---|---|---|---|
| Safe core 1–10 | light leather, linen scrap, T1 ores | 3% Uncommon **base variants** (WP5 class items) | — |
| Inner 10–25 | leather, linen cloth, T1 herbs | base variants | Grimtusk/Ashmaw (L12); bandit camps = linen |
| War coast 20–30 | heavy cloth (raiders), linen | base variants | PvP quests ≥20; Captain Bonerattle (L28); **outpost supply crates** (§5.6) |
| Outer 25–45 | heavy leather, scaled hide, heavy cloth, spider silk, T2 herbs, stone cores, iron/steel | **improved variants** on elites (20% Unc / 3% Rare) | named rares L32–42; apex dragon lair (L50) |
| Coast 45–60 | scaled hide, silk, T3 herbs, gold/gems | improved variants; elites common | coast named rares L48–50; Reef Lurker |
| Depth axis | ore ladder: copper/tin/coal → iron (−300) → gold/gems (−600) | cave mobs as per surface tier | abyssal gems only in housing depths |
| Enemy territory | identical base tables (mirrored biomes) | identical | enemy named rares + enemy King = the raid incentive |

### 5.1 Quality chance per source (kill, player-tagged)

| Source | Uncommon | Rare | Roll window (§6.3) |
|---|---|---|---|
| Normal mob | 3% | — | world |
| Elite (armor 80) | 20% | 3% | elite |
| Named rare (armor 70) | 100% | 25% | rare |
| Apex boss / faction King | — | 100% | boss |

### 5.2 Named rares (spawn rules decided in biomes_mobs §3.3)

2–4 h respawn, patrol routes, faction-wide broadcast. Loot per kill:
guaranteed Uncommon (rare window) + 25% Rare + **100% signature trophy**
(`group:grug_rare_trophy` — Grimtusk's Tusk, Silkfang's Gland, …): the
T4-tome keystone and masterwork ingredient (§2.3, §6.4). Anti-camping:
patrol routes + broadcast + the 2–4 h jitter (already decided) — no
extra mechanic needed.

### 5.3 Apex world bosses (world.md §4b)

Respawn 20–28 h (rolled). Lair **hoard chest** unlocks on the kill, one
withdrawal per tagged player: 1 Rare item (boss window) + 3–5 wyrmscale
(T4 leatherworking masterwork mat) + 20–50c + **1 abyssal gem** (the
bridge source until housing ships, §10 P5).

### 5.4 The faction King (enemy capital raid)

Respawn 20–28 h. Per tagged raider: 1 Rare (boss window) + 30–60c;
once per kill: **Fallen Crown** (masterwork ingredient usable in any
profession's T4 masterwork as the trophy slot). Elite guard ring makes
it a group raid by design; kills broadcast world-wide.

### 5.5 Housing depth treasures

**Abyssal gems**: finite nodes in guild housing depths (no respawn, R4);
ingredients for race signatures (×2) and optional T4 masterworks. Until
housing ships, apex hoards drop 1 each (§10 P5).

### 5.6 War-coast PvP incentive (proposal)

Enemy **outpost supply crates**: one lootable crate per military
outpost, openable only by the ENEMY faction, node-timer refill 60 min:
3–6 heavy cloth + 2–4 iron bars + 20% 1 gem. Raiding the war coast
feeds your crafters without any player-item loss (death rules stay
untouched). Faction NPC kills additionally drop war trophies (vendor
5–10c) + heavy cloth 1/3 (combat_stats player-tag PvP rule).

## 6. Quality tiers & enchant roll ranges (WP5 numbers)

### 6.1 Meta model

Item meta: `grug_quality` (1 Common / 2 Uncommon / 3 Rare / 4 Unique-
reserved), `grug_ench` = one serialized `{stat = value, …}` table (mcl
pattern §1.2), `grug_upgrades` (0–2, §7), `grug_req_level`. Description
regenerated from meta on every change (name colorized: white `#FFFFFF`,
blue `#4A90FF`, yellow `#FFD700`, orange `#FF8000`; one line per
enchant). Attack speed applies via `tool_capabilities.
full_punch_interval` meta override; stats recompute on equip change
(WP15 hook). Enchant count: **Uncommon rolls 1–2 (60/40), Rare 3–4
(70/30)** — the decided budgets.

### 6.2 Enchant pools per item family (no duplicate stat per item)

| Family | Pool |
|---|---|
| Melee weapons | +Str, +Dex, +attack speed%, +crit%, +HP |
| Caster weapons/offhands | +Int, +mana, +crit%, +HP |
| Metal armor | +Str, +HP, +armor%, +dodge% |
| Leather armor | +Dex, +HP, +crit%, +dodge% |
| Cloth armor | +Int, +mana, +HP, +crit% |

### 6.3 Roll ranges by ilvl bracket and source window

Value ranges (min–max) per ilvl bracket:

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

Cap safety at 60 (6 slots: weapon, offhand, 4 armor): worst-case crit
stacking ≈ 6×3% + 5% base + ~7% from Dex = ~30% — lands exactly on the
cap, which **clamps** (flat caps, combat_stats §2); dodge and the 60%
armor cap clamp identically. Budgets need no further rules.

### 6.4 Crafted quality (how crafting reaches Uncommon/Rare)

- Standard recipes → **Common** (reliable, repairable baseline).
- **Fine recipes** (each tier, +1 gem or tier reagent — venom sac,
  slime gel, sleek pelt, …) → **Uncommon**, crafted-fine window.
- **Masterwork recipes** (T3/T4 only; + named-rare trophy or Fallen
  Crown, T4 also abyssal-gem option) → **Rare**, crafted-masterwork
  window. Race signatures (§4) are masterworks with a fixed first
  enchant. This keeps "better gear comes from crafting or hard bosses"
  literally true: the two 0.60–1.00 windows are crafting and bosses.

## 7. Upgrade mechanics (resolves the old §2 — no failure chance)

Two kit types per crafting profession, applied in the grid (item +
kit), workbench nearby; effects on the item's OWN family only
(whetstones/armor polish = smith, armor kits = LW, embroidery = tailor,
imbuing oils = apothecary gear + caster offhands):

- **Imbue kit** (per tier): Common → Uncommon; rolls 1–2 enchants in
  the crafted-fine window. Cost ≈ 1 tier reagent + tier materials.
- **Temper kit** (T3/T4): re-rolls all enchant VALUES on an Uncommon/
  Rare item; 1st application window 0.50–0.95, 2nd 0.60–1.00, **max 2**
  (`grug_upgrades` meta). Never changes enchant count or quality tier —
  an imbued Common (now Uncommon, 1–2 enchants) stays strictly below a
  fresh Rare (3–4 enchants): the decided "upgraded mediocre item never
  becomes a top item", enforced structurally, not by caps.

## 8. Prices & the gold-income curve (resolves the old §4; seeds economy.md numbers)

All values copper (100c = 1s, 100s = 1g). Design target: **lifetime
gross income to 60 ≈ 1g**, arriving at 60 with ~20–40s after sinks;
endgame farming ≈ 6–12s/hour — "a full gold is a fortune" holds.

### 8.1 Income

- **Quest reward** = 2c + 1.5c × quest level, rounded to 5c steps
  (L1 ≈ 5c, L20 ≈ 30c, L60 ≈ 90c); elite/group and war-coast PvP
  quests ×2. ~80 quests to 60 ≈ 35–40s total.
- **Trash/vendor loot** per kill (expected): 1–2c (L1–15), 2–4c
  (16–30), 4–7c (31–45), 6–10c (46–60); elites ×3 quantity, named
  rares ×6 (mob-tier multipliers). ≈ 35s over ~1000 kills to 60.
  Bandit "coin" drops become a *stolen purse* trash item (5c) — no
  physical currency items (economy.md §1 upheld).
- Herbs/materials sold to vendors: 1–3c each (floor; the real market
  is player trade).

### 8.2 Vendor prices (sell to players)

| Item | Price |
|---|---|
| Thread / flux / vial / parchment / whetstone blank | 1c / 2c / 3c / 5c / 4c |
| Torch | 1c |
| Weak healing potion (15%) | 8c |
| Small bag (8 slots) | 80c |
| Vendor Common gear: weapon / chest / other piece | 50c / 40c / 25c |
| Wood & stone tools / bronze pick | 5–15c / 40c |
| Apprentice tome (any profession) | 25c |
| Replacement tome T2 / T3 / T4 | 1s / 3s / 10s |

### 8.3 Recurring sinks

- **Repair** (WP22): per piece = ceil(ilvl × 0.5c) × quality factor
  (Common ×1, Uncommon ×1.5, Rare ×2). Starter piece 1–3c; full Rare
  set at 60 ≈ 3s per full repair. Wear budget ≈ 3000 combat events per
  item (broken = stops working, never destroyed — decided). The price,
  not the frequency, is the tier lever.
- **Respec**: 5c × character level (min 25c) → 3s at 60, repeatable.
- Job supplies + vendor consumables: the steady trickle (≈15–25% of
  leveling income re-sunk by design).

### 8.4 Big one-time sinks (seeds for guilds/housing TODOs)

Guild founding **5g**; housing build-rights step 1 = **2g**, each
further step ×1.5 (steps small and rising — the maximum is practically
never reached, as decided); mining-rights depth step 1 = **3g**, ×1.5
per step; continental mining claims 2g (small) / 5g (large), one-time,
finite resources included. A 5-player guild pools its founding fee with
~1–2 evenings of endgame income each.

## 9. Bows & arrows (Phase-2 enabler — catalogued, class NOT decided)

Item path (source: `mcl_bows`, code LGPL 3.0 ✓, media CC BY-SA 4.0 +
2 attribution sounds; port ≈ 1000 lines incl. `vl_projectile`, §1.2):

- **Bow family on the weapon curve**: Shortbow T1 / Hunting Bow T2 /
  Longbow T3 / Wyrmsinew Bow T4 — full-charge damage = the 1H curve
  (8/13/19/24) at 25 m range, charge 0.5 s (mcl hold-pattern), partial
  charge scales linearly, enchant pool = melee weapons (attack speed →
  charge speed).
- **Arrows** as stackable ammo + entity (vl_projectile template);
  craft 20/batch: 1 iron bar + 4 sticks + 4 feathers (sharp feathers —
  eagle/vulture drops finally get their reagent role). Quiver =
  LW bag-slot item holding only arrows.
- **Producer**: Bowyer = the decided Leatherworker split
  (professions.md §5); until then the recipes sit unassigned.
- This section makes the OPEN Phase-2 Archer/Hunter + Bowyer decision
  cheap: the entire item/ammo/entity path is specced and license-clean;
  the only open questions left are class kit + balance. **Explicitly
  not decided here.**

## 10. Resolved decision points (2026-08-06)

**P1 — Tier-4 metal.** Gem-tempered steel (steel + gems, no new ore —
uses Gem Hunter, golem drops, existing depth ores) vs a new deep ore
with mapgen registration. Recommendation: **gem-tempered steel** (zero
mapgen risk, strengthens two existing loops); a new ore can still be
added post-MVP as a T5/Unique hook.
**Decided as recommended (2026-08-06).**

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
**Decided as recommended (2026-08-06).**
