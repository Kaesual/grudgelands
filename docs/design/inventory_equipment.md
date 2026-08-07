# Inventory, Character Screen & Equipment

Decided spec (2026-08-06). Implementation: WP15 (character screen +
bags), WP10 (workbench UIs), WP14 (offhand slot).

## 1. Character screen (the "i" key)

- Built on sfinv pages (`sfinv.register_page`); the **Character page is
  the homepage**: stat sheet (attributes, HP/mana, melee/spell bonus,
  crit/dodge — the `/char` data), equipment slots, 3D model preview
  (formspec `model[]`).
- Further pages: **Bags**, existing **Crafting** (3×3 grid).
- Armor visuals on the player model (multiskin layering à la lottarmor):
  Phase 3.

## 2. Equipment slots (MVP)

- **Head, Chest, Legs, Feet, Offhand** (offhand mechanics:
  `combat_stats.md` §7 / WP14).
- **2 Trinket slots, reserved**: UI + meta support from day one, first
  trinket items post-MVP (same strategy as the Unique quality tier).
  Both slots are the **Goldsmith's** exclusive item family
  (professions.md §2).
- No ring/neck/shoulder slots in the MVP.
- Slots are **player-inventory lists** with group-filtered `allow_put`
  (decided during WP15 — auto-persisted, simpler than the 3d_armor
  detached-inventory pattern originally sketched here); stat effects
  recompute on change.
- **Level requirement enforced here** (2026-08-07; **lands with WP5** —
  WP7's equip filter deliberately ships without it): the same `allow_put`
  filter rejects any item whose `grug_req_level` exceeds the character's
  level and says so in chat (items_crafting.md §6.1). Rejecting the
  equip is deliberate — letting the item sit in the slot without effect
  would be an invisible failure.
- **Armor classes are bound to the character class** (decided
  2026-08-07 in WP7 — the mechanism `combat_stats.md` §2 and
  `items_crafting.md` §3.1 both assume but never named):
  - Every armor item carries an **armor class**: **cloth 1 < leather 2
    < metal 3** (item group `grug_armor_class`). Items without the
    group are unaffected.
  - Each character class has a **maximum rank** and may wear its own
    rank **and everything below**: **Warrior 3, Mage 1, Priest 1**. A
    character without a class counts as cloth (rank 1).
  - Enforced in the **same group-filtered `allow_put`** as the rest of
    the slot rules, with a throttled chat refusal (the allow callback
    fires repeatedly while a stack is dragged).
  - A **class change unequips** every piece above the new rank back
    into the main inventory — the filter can only ever refuse an equip,
    so worn gear would otherwise survive a respec untouched. If the
    inventory is full the piece stays worn and the player is told to
    make room.
  - Why the rule exists: without it nothing stops a Mage from buying
    plate, and the **60 %-plate / 15 %-cloth spread** that
    `combat_stats.md` §2 balances the whole tank/squishy design around
    collapses into "everyone wears the best armor they can afford".

## 3. Bags (WoW model, LotT implementation pattern)

- **Base inventory stays 32 slots** (must not feel cramped); **4 bag
  slots** extend it. **Four sizes, one per mastery tier** (revised
  2026-08-07 — the huge bag is new): **small 8 / medium 16 / large 24 /
  huge 32** slots (`bagslots` group; bag slots + contents are
  player-inventory lists, see above). Four huge bags therefore add 128
  slots — the Master tailor's flagship product, and the reason the bag
  line stays interesting to the end of the mastery ladder.
- **Bags are Tailor products on all four mastery tiers**
  (`items_crafting.md` §2.1 for the tiers, §3.5 for the recipes) — cloth
  farming feeds the tailor economy. The **small 8-slot bag is the
  exception and stays vendor-sellable**: it is the floor tier of its
  item category (professions.md §4), so it is bought, not crafted-only.
- No item drop on death (unchanged; death costs XP, not gear).

## 4. Crafting model (revised 2026-08-06 — replaces the workbench-UI split)

- **Everything is crafted in the 3×3 grid**, base recipes and profession
  recipes alike; profession items are **multi-stage** (ore → ingot →
  component → item).
- **Recipes are gated by profession progression**: laying the right
  materials into the grid without having unlocked the recipe produces
  nothing (`craft_predict` veto). What a character has unlocked is
  defined by the **profession's recipe book** — one book per profession,
  its tier groups gated by character level and tier keystone
  (`items_crafting.md` §2.2, revised 2026-08-07); that model is written
  there and deliberately not restated here.
- **The book UI is mandatory**, since a 3×3 shape you don't know is
  otherwise undiscoverable: unlocked recipes are browsable, reachable
  from the character screen.
- **Profession recipes additionally require the matching workbench
  nearby** (`find_node_near`) — **one bench per profession**, so the
  roster of professions.md §2 is also the roster of benches (forge,
  tanning rack, tailor bench, alchemy table, and one each for the
  Woodcarver and the Goldsmith). Keeps cities/camps as crafting magnets;
  base recipes work anywhere.
- Workbenches are initially **uncraftable and stand only in the
  capitals/villages** (placement with WP13); job-supply vendors (thread,
  flux, vials) stand next to them (materials design:
  items_crafting.md).
