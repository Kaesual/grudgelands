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
  slots** extend it: small 8 / medium 16 / large 24 slots
  (`bagslots` group; bag slots + contents are player-inventory lists,
  see above).
- **Bags are Tailor products** (+ one small vendor-sold bag) — cloth
  farming feeds the tailor economy.
- No item drop on death (unchanged; death costs XP, not gear).

## 4. Crafting model (revised 2026-08-06 — replaces the workbench-UI split)

- **Everything is crafted in the 3×3 grid**, base recipes and profession
  recipes alike; profession items are **multi-stage** (ore → ingot →
  component → item).
- **Recipes are gated by profession progression**: laying the right
  materials into the grid without having learned the recipe produces
  nothing (`craft_predict` veto). Learned recipes are browsable in a
  **recipe book UI** (character screen / trainer) — mandatory, since a
  3×3 shape you don't know is otherwise undiscoverable.
- **Profession recipes additionally require the matching workbench
  nearby** (`find_node_near`: forge, tanning rack, tailor bench, alchemy
  table) — keeps cities/camps as crafting magnets. Base recipes work
  anywhere.
- Workbenches are initially **uncraftable and stand only in the
  capitals/villages** (placement with WP13); job-supply vendors (thread,
  flux, vials) stand next to them (materials design:
  items_crafting.md).
