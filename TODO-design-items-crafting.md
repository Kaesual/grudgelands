# TODO — Items, Crafting & Loot

Open design questions for a future `docs/design/items_crafting.md` (plus
seeds for `economy.md`). Process: see AGENTS.md "Documentation layers".

Directions decided in chat (2026-08-06):

- **Item quality tiers: Common (white), Uncommon (blue), Rare (yellow),
  Unique (orange)**. The MVP ships without Uniques, but the architecture
  (quality field + enchant list in item meta) supports them from day one —
  nothing gets bolted on later.
- **Uncommon = 1–2 weak enchantments; Rare = 3–4 enchantments.**
- Sources: vendors sell simple (Common) gear — sufficiently available but
  painfully expensive (gold is scarce by design); better gear comes from
  **crafting** or from **special bosses**.
- Items are craftable and can be **upgraded via crafting within limits**:
  a mediocre base item can be improved, but never becomes a top item.
- **The harder the enemy, the better the loot.** Special mobs (e.g. the
  faction **King**, a heavily guarded raid boss in the capital) roll
  higher enchantment ranges than normal or rare mobs.
- **Rare patrol mobs**: some areas have hard-to-kill rare mobs with
  limited/low spawn rates and special loot — a deliberate incentive to
  raid enemy territory.
- **Class/profession synergy is intended**: e.g. Blacksmith + Warrior
  (craft your own gear while leveling), Tailor + Priest, etc.
- Housing depth treasures (exclusive, artificially limited gems/materials,
  see `docs/design/world.md` §5) are ingredients for high-end recipes.
- Race-exclusive recipes exist (e.g. only elven tailors craft the top mage
  robe — decided with races, `docs/design/world.md` §7).

## 1. Quality & enchantment budgets — OPEN

- Proposal: enchant *count* per tier as decided above; enchant *strength*
  scales with item level and source difficulty (mob tier/boss multiplier
  on the roll ranges — same mechanic everywhere, only the ranges differ).
- Open: the enchantment pool (strength, intelligence, dexterity, attack
  speed, HP, mana, crit, dodge, …) — finalize together with attributes
  (`TODO-design-combat-stats.md`), so item stats and player stats are one
  system.

**Decision:** _pending_

## 2. Crafting & upgrade mechanics — OPEN

- Proposal: each profession has recipes per tier; Rare recipes require
  rare materials (boss drops, housing gems, race-exclusive unlocks).
- Proposal for upgrades: an upgrade recipe consumes the item + materials
  and raises/re-rolls its enchants **within a cap set by the item's base
  quality** — an upgraded Common caps below a freshly rolled Rare.
- Open: number of upgrade steps, material lists per recipe.
- Recommendation: **no upgrade failure chance** (frustration without
  depth).

**Decision:** _pending_

## 3. Boss & rare-mob loot — OPEN

- Open: spawn timers/rates for rare patrol mobs and the King; loot table
  structure; anti-camping measures (roaming patrol routes already help).

**Decision:** _pending_

## 4. Vendor pricing & gold flow — OPEN (seeds economy.md)

- Decided direction: gold scarce; vendor gear expensive (early gold
  sink); housing expansion as the big long-term sink; vendors buy every
  mob drop (trash-loot income, already planned in WP7).
- Open: actual price levels — needs the gold-income curve first (gold
  value per mob tier, quest rewards).

**Decision:** _pending_
