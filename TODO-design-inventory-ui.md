# TODO — Inventory UI: character screen, equipment slots, bags, workbenches

Raised 2026-08-06. Decided direction (user): the inventory key ("i") is
the character screen — stats visible, equipment managed there (armor,
offhand, trinkets & co.), plus a WoW-style bag system; 3×3 crafting grid
stays in the inventory, special recipes require workbenches.

## 1. Technical base (findings, low risk)

- Our `sfinv` (BASE) is tab-based and extensible: `sfinv.register_page` /
  `override_page`. The 3×3 grid already exists as the `sfinv:crafting`
  page. Plan: new pages **Character** (default homepage) and **Bags** —
  no inventory rewrite needed; visual polish is Phase 3.
- Character screen: stat sheet (the `/char` data: attributes, HP/mana,
  melee/spell bonus, crit/dodge) + equipment slots + 3D preview
  (formspec `model[]` element).
- Bags, LotT pattern (`lottinventory` + `lottarmor/armor.lua`, GPL):
  bag items with group `bagslots=N`, fixed bag slots in a per-player
  detached inventory, each bag contributes its slots. Direct fit.
- Equipment slots: detached inventory with `allow_put` filters by item
  group (pattern: 3d_armor/lottarmor); stat effects recompute on change
  (hooks into `wob_classes.apply_stats` / later the damage pipeline).

## 2. Proposals (to decide)

- **Equipment slots MVP**: Head, Chest, Legs, Feet, Offhand (WP14),
  2× Trinket. Trinkets are *reserved slots* (UI + meta support from day
  one, first trinket items post-MVP) — same approach as Unique quality.
- **Bags**: 4 bag slots (WoW-like). Base inventory shrinks to hotbar 8 +
  8 slots; bags extend it (small 8 / medium 16 / large 24). **Bags are
  Tailor-crafted** (+ a small vendor bag) — cloth farming feeds the
  tailor economy, classic WoW loop. No item drop on death (unchanged).
- **Workbench crafting**: profession recipes do NOT go through the 3×3
  grid. Technical reason: the inventory craft grid has no world-position
  context, so "near a forge" cannot be checked cleanly there. Instead:
  workbench nodes (forge, tailor bench, alchemy table) open a **recipe
  list UI** (WoW-style: pick recipe, materials auto-consumed) — cleaner
  than shape puzzles and position-gated for free. The 3×3 grid keeps
  general recipes (torches, basic tools, blocks).
- Workbenches initially **uncraftable, placed only in the capitals**
  (with WP13); job trainers sell supply items nearby (see items TODO §5).

## 3. Open questions

- Slot list confirmed as proposed? (Head/Chest/Legs/Feet/Offhand/2×
  Trinket; no ring/neck/shoulder MVP.)
- Base-inventory shrink to 16 okay (encourages the bag chase), or keep
  32 and let bags add on top?
- Armor visuals on the player model: MVP (multiskin layering à la
  lottarmor) or Phase 3?

**Decision:** _pending_

## WP mapping (once decided)

New WP15 "Character screen & bags" (sfinv pages, equipment slots +
stat recompute, bag system); workbench recipe-list UI lands with WP10
(jobs); WP14 (offhand) plugs its slot into the character screen.
