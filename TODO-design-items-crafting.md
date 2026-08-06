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
  speed, HP, mana, crit, dodge, …) — attributes and player formulas are
  now decided (`docs/design/combat_stats.md`), so the pool can be
  finalized against them; enchant budgets must respect the 30%/30%/60%
  crit/dodge/armor caps.

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

## 5. Material tiers & loot tables — direction decided 2026-08-06, params OPEN

Decided direction (user):

- **Crafting materials come in tiers**; where you get them mirrors WoW:
  - **Vendor supplies**: cheap consumable ingredients (thread/Garn,
    flux, vials) sold by job-supply vendors near the workbenches in the
    capitals — a small steady gold sink.
  - **World materials**: dropped by mobs or gathered/mined —
    **tier follows the source's level**: low-level humanoids drop
    low-tier cloth, high-level humanoids high-tier cloth; ores likewise
    via mining in high-level areas (heartland).
- Workbenches (forge, tailor bench, alchemy table) are initially
  **uncraftable and stand only in the capitals** (placement WP13; recipe
  list UI see TODO-design-inventory-ui.md).
- Bags are Tailor products (cloth sink; see TODO-design-inventory-ui.md).

Proposal for the params (open):

- **4 material tiers** aligned to level brackets 1–15 / 15–30 / 30–45 /
  45–60, matching the difficulty rings; loot tables per mob category
  (humanoid → cloth, beast → leather/meat, undead → reagents) with the
  tier picked from the mob's level.
- Mob loot tables live in the mob def (`drops` as function of mob level
  — mobs_redo supports function drops, see AGENTS.md).

**Decision (params):** _pending_

## 4. Vendor pricing & gold flow — OPEN (seeds economy.md)

- Decided direction: gold scarce; vendor gear expensive (early gold
  sink); housing expansion as the big long-term sink; vendors buy every
  mob drop (trash-loot income, already planned in WP7).
- Open: actual price levels — needs the gold-income curve first (gold
  value per mob tier, quest rewards).
- Open (from the guild decision, `docs/design/guilds.md`): guild
  founding fee; housing tile reserve + expansion step sizes/prices
  (requirement: steps small and rising so the maximum is practically
  never reached); mining claim sizes + one-time prices (price buys the
  finite resources inside).

**Decision:** _pending_
