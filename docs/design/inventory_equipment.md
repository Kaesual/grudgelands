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
- Slots are a per-player detached inventory with group-filtered
  `allow_put` (3d_armor pattern); stat effects recompute on change.

## 3. Bags (WoW model, LotT implementation pattern)

- **Base inventory stays 32 slots** (must not feel cramped); **4 bag
  slots** extend it: small 8 / medium 16 / large 24 slots
  (`bagslots` group, per-player detached inventory — pattern:
  `lottinventory`).
- **Bags are Tailor products** (+ one small vendor-sold bag) — cloth
  farming feeds the tailor economy.
- No item drop on death (unchanged; death costs XP, not gear).

## 4. Crafting split

- The **3×3 grid** (inventory) keeps general recipes: torches, basic
  tools, blocks.
- **Profession recipes never use the 3×3 grid**: workbench nodes
  (forge, tailor bench, alchemy table) open a **recipe-list UI**
  (pick recipe → materials auto-consumed). Rationale: the inventory
  craft grid has no world-position context, workbench formspecs are
  position-gated for free — and a recipe list is the WoW-familiar UX.
- Workbenches are initially **uncraftable and stand only in the
  capitals** (placement with WP13); job-supply vendors (thread, flux,
  vials) stand next to them (materials design:
  TODO-design-items-crafting.md §5).
