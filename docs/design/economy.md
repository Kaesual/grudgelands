# Economy — Currency & Money Flow

Decided spec (2026-08-06; sinks re-cut 2026-08-07). This file fixes the
currency structure, the qualitative bands and the sinks; the concrete
price and gold-income numbers live in `items_crafting.md` §8
(cross-reference corrected 2026-08-07 — it pointed at §7).

## 1. Currency: copper / silver / gold

- Base-100 chain: **100 copper = 1 silver, 100 silver = 1 gold** —
  conversion is automatic, players never hold ≥100 copper or silver
  (the tiers act as "decimal places").
- **Storage: ONE integer in copper units** in player meta (1 = 1c,
  100 = 1s, 10000 = 1g). Corrected 2026-08-07: the Lua number is a
  double, but the storage path is not — `PlayerMetaRef:set_int` is a
  genuine **32-bit signed** store, so the balance is clamped at
  **2,147,483,647c ≈ 214,748g**. That ceiling is still five orders of
  magnitude above "a full gold is a fortune" (§2), i.e. unreachable by
  play; it exists so a sale crossing it cannot wrap the balance
  negative. Conversion is display-only: UI always renders `Xg Ys Zc`.
- **Display rule** (decided 2026-08-07): **leading zero units are
  omitted, copper is always shown, interior zeros are kept** — `5c`,
  `1s 5c`, `1g 0s 5c`. One format function for HUD, chat and every
  trade UI.
- **No physical coin items in the MVP** — money is a counter; traders
  and NPCs adjust it. (Coin items as loot flavor: revisit later.)
- **Vendor floor rule** (decided 2026-08-06, revised 2026-08-07):
  vendors sell only the LOWEST tier of each item category (smallest bag,
  weak heal potion, basic tools) — everything above is player-crafted
  (`professions.md` §4). Revision: **the floor moves with the player**.
  Gear comes in six **bracket catalogs** of 10 levels each, every
  bracket offering what a normal mob of that bracket drops — Common and
  therefore **always without enchants**, within roughly ±15 % of crafted
  gear of the same era (`items_crafting.md` §3.8; the enchants, not the
  base numbers, are the crafting advantage).

## 2. Price bands (qualitative)

- Starter-zone items and trash loot: **a few copper**.
- **Vendor gear rises ×1.4 per level bracket** (50c for the first
  weapon, 269c for the last — `items_crafting.md` §8.2): buying the one
  piece you are missing is affordable, outfitting fully at every bracket
  costs about a quarter of the lifetime income and is meant to hurt.
- High-tier weapons/armor pieces: **a few silver**.
- Valuable rare items: **several silver — never a full gold**.
- **A full gold is a fortune**, reserved for the big sinks: the last
  housing depth step (1g, §4.1) and the guild founding fee (5g).
- **Buy-back rate: vendors buy an item back at 25 % of their own sale
  price**, rounded down, never below 1c (decided 2026-08-07 — the docs
  had fixed sale prices but never a spread). Without a spread, a vendor
  is a free storage service and any later price edit risks an income
  loop; 25 % also keeps the `items_crafting.md` §3.8 anti-loop rule
  ("vendor value of a crafted item < summed vendor value of its
  ingredients") true **by construction** for everything a vendor sells.
  The same-race discount (world.md §7) applies to the sale price only —
  discounting the buy-back too would narrow the spread from both ends.
  **Mob-drop materials are unaffected**: they are never sold by a
  vendor, so their `_grug_sell_price` is their only price and is paid
  in full (§8.1 bands in `items_crafting.md`).

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
- Big/long-term: exactly two, since the removal of the guild mining
  claims (2026-08-07) — **housing depth rights** (§4.1, the main one,
  per character) and the **guild founding fee** (5g, per guild;
  `guilds.md` §1). Continental mining claims are gone: guilds own no
  ground, so there is no land purchase in the game at all.

### 4.1 Housing depth rights — the central long-term sink

Revised 2026-08-07 with the housing rework (`world.md` §5), **re-cut
2026-08-07** with the crafting rework. The isle itself is **free** — a
royal grant at level 30, not a purchase — and the only paid axis is
**depth**. The ladder is now **six steps ≈ 1.9g** (previously ten steps
of 50 nodes down to −530, ≈ 2.4g):

| Step | Opens down to | Rock tier | Price |
|---|---|---|---|
| free | −30 | (seabed) | — |
| 1 | −100 | T1 | 50c |
| 2 | −300 | T2 | 2s |
| 3 | −500 | T3 | 6s |
| 4 | −700 | T4 | 20s |
| 5 | −1000 | T5 | 60s |
| 6 | bedrock | T6 | **1g** |

The identical table lives in `world.md` §5.3 and the price list in
`items_crafting.md` §8.4 — the three must not drift.

**Why six steps and not ten**: each step opens **the next rock
stratum**, and the strata are the six material tiers T1–T6 that gate
tools, weapons and armor everywhere else in the game. The depth
boundaries are therefore not price points chosen for the ladder, they
are the continent's own rock layers (`world.md` §5.3). Buying step 4 and
being able to swing a T4 pick are the same statement about a character,
so the isle runs on **one rhythm with the rest of the game** instead of
a second, private progression scale. Ten arbitrary 50-node steps could
not do that.

Why it still works as the anchor sink:

- It starts at **level 30**, so the *long-term* sink opens well before
  the level cap. The early sinks (vendor gear, bags, consumables, job
  supplies, repair — §4) keep gold meaningful from hour one; what was
  missing was something to save *towards*.
- It is **per character, not per guild**, so the drain scales with the
  player count instead of the guild count — which matters more now that
  the guild founding fee is the only other big sink left.
- Every step buys a **finite** payout (world.md §5.4, no respawn), so it
  can never turn into an income source that pays for its own next step.
- The ladder is **back-loaded**: steps 1–3 together cost 8.5s, the last
  two cost 1.6g. The cheap half is affordable at the level it unlocks,
  and the flagship 1g step stays the endgame purchase §2 calls a
  fortune.

**The total fell (2.4g → 1.9g) and a second big sink disappeared with
it.** Removing the continental mining claims took 2g/5g one-time
purchases out of the economy, so the long-term drain now rests on this
ladder plus the 5g guild fee. That is a deliberate narrowing, not an
oversight: the ladder scales with the number of *characters* and is
therefore the only sink that grows with a server, while the guild fee is
a one-off per group. The claims scaled with neither — a handful of
guilds bought them once and the sink was spent.
