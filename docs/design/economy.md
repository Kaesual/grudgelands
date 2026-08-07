# Economy — Currency & Money Flow

Decided spec (2026-08-06). Price *numbers* are still open (gold-income
curve: items_crafting.md §7); this file fixes the
currency structure and the qualitative bands.

## 1. Currency: copper / silver / gold

- Base-100 chain: **100 copper = 1 silver, 100 silver = 1 gold** —
  conversion is automatic, players never hold ≥100 copper or silver
  (the tiers act as "decimal places").
- **Storage: ONE integer in copper units** in player meta (1 = 1c,
  100 = 1s, 10000 = 1g). Lua doubles are exact up to 2^53 — no
  overflow risk at game scales. Conversion is display-only: UI always
  renders `Xg Ys Zc`.
- **No physical coin items in the MVP** — money is a counter; traders
  and NPCs adjust it. (Coin items as loot flavor: revisit later.)
- **Vendor floor rule** (decided 2026-08-06): vendors sell only the
  LOWEST tier of each item category (smallest bag, weak heal potion,
  basic tools) — everything above is player-crafted
  (`professions.md` §4).

## 2. Price bands (qualitative)

- Starter-zone items and trash loot: **a few copper**.
- High-tier weapons/armor pieces: **a few silver**.
- Valuable rare items: **several silver — never a full gold**.
- **A full gold is a fortune**, reserved for the big sinks: the deepest
  housing depth steps, the guild founding fee, mining claims.

## 3. Income streams

- **Quest rewards** — the baseline, paying from the very first starter
  quest on (a few copper for "kill 5 boars").
- **Selling loot** — traders buy EVERY mob drop (trickle income).
- No mob-only gold farming mechanic: "gold drops only from humanoids"
  was considered and rejected — traders buying everything already makes
  every mob a money source; steering happens via prices, not bans.
- **Bandit camps** (neutral-hostile humanoid camps in both territories)
  are the home-territory source of cloth; their loot sells like any
  other drop.

## 4. Sinks

- Small/steady: vendor goods, job supplies (thread, flux, vials),
  vendor bags, weak healing potions.
- **Repair** (decided 2026-08-06, WP22): gear has durability, but a
  broken item is **never destroyed** — at 0 durability it merely stops
  working (weapons deal no damage, armor stops protecting, item bonuses
  turn off) until repaired at an NPC for gold. Cost scales with quality
  tier: gray starter gear costs a few copper, rare lategame gear real
  money. The per-character steady sink from hour one.
- **Talent respec** at the class trainer, price rising with level
  (progression.md §2, WP11).
- Big/long-term: **housing depth rights** (the main one), guild founding
  fee, continental mining claims (one-time purchases of finite
  resources — `guilds.md` §3.2).

### 4.1 Housing depth rights — the central long-term sink

Revised 2026-08-07 with the housing rework (`world.md` §5). The isle
itself is **free** — a royal grant at level 30, not a purchase — and the
only paid axis is **depth**: 10 steps of 50 nodes from 50c up to 1g,
≈ 2.4g for the full ladder (table: world.md §5.3, price list:
items_crafting.md §8.4).

Why this works as the anchor sink:

- It starts at **level 30**, so the *long-term* sink opens well before
  the level cap. The early sinks (vendor gear, bags, consumables, job
  supplies, repair — §4) keep gold meaningful from hour one; what was
  missing was something to save *towards*.
- It is **per character, not per guild**, so the drain scales with the
  player count instead of the guild count. Total gold destroyed goes up
  even though the entry price went to zero.
- Every step buys a **finite** payout (world.md §5.4, no respawn), so it
  can never turn into an income source that pays for its own next step.
