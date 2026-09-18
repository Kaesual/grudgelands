# Inventory, Character Screen & Equipment

Decided spec (last revised 2026-09-18; established 2026-08-06).
Implementation: WP15 (character screen +
bags), WP10 (workbench UIs), WP14 (offhand slot), WP35 (weapon slot +
hand count), WP38 (native swing capability/pointability bridge), WP39
(current-ray swing authority, shipped 2026-08-10).

## 1. Character screen (the "i" key)

- Built on sfinv pages (`sfinv.register_page`); the **Character page is
  the homepage**. It has the equipment slots and 3D model preview (formspec
  `model[]`) plus exactly two compact, live derivation lines above them: one
  for maximum HP and one for mana or rage. HP and mana show the resulting
  maximum and abbreviate base pool, class factor and gear/talent percentage
  bonuses as B/C/G/T; Help expands that legend. Rage names its fixed 100-point
  rule. The lines consume
  `grug_classes.get_pool_breakdown` and do not recompute the stats. Formula
  explanations and the remaining stat guidance live on the existing Help
  page; effective/raw Crit, Dodge and Armor remain in the Talents header.
- Every Character-page `label[]`, `textarea[]` or `hypertext[]` box is clear
  of every equipment/main-inventory `list[]`, `image[]` and `item_image[]`
  box. The pool lines occupy the strip above the model and the equipment grid,
  rather than sharing horizontal space with the slots.
- **Every equipment slot says what it is, without hovering** (decided
  2026-08-09, WP38). Eight identical empty cells plus a hover tooltip is
  not enough. Preferred: a **ghost icon per empty slot** — the slot's type
  drawn dimmed inside it (reuse the `grug_gear` art where a slot has a
  natural match: head/chest/legs/feet, weapon; offhand and trinket need two
  new 16 px silhouettes). Two constraints found while specifying it:
  - `listcolors[]` is **per formspec, not per list**, and the Character
    page also carries sfinv's main inventory and hotbar lists. Making slot
    backgrounds transparent so a ghost drawn *before* the `list[]` shows
    through therefore strips the cells from the main inventory too. So:
    draw the ghost **after** the `list[]` and **only for slots that are
    actually empty** — nothing to cover, no `listcolors` change, no effect
    on any other list. It needs the formspec re-sent on equipment change
    (`sfinv.set_player_inventory_formspec` from the existing
    `register_on_equipment_change` hook), which is a rare event.
  - **Runtime check that decides the approach**: an `image[]` over a
    `list[]` slot must not swallow the click. If it does, fall back to
    one- or two-character `label[]`s ("H", "C", "L", "F", "W", "O", "T1",
    "T2") — legibility beats prettiness here, and the existing hover
    tooltips carry the full name either way.
- Further pages: **Bags**, existing **Crafting** (3×3 grid).
- Armor visuals on the player model (multiskin layering à la lottarmor):
  Phase 3.

## 2. Equipment slots (MVP)

- **Head, Chest, Legs, Feet, Weapon, Offhand** (weapon slot: the block
  below; offhand mechanics: `combat_stats.md` §7 / WP14). Armor keeps its
  own column on the character page; **Weapon and Offhand sit next to each
  other** so the pair reads as "hands".
- **The Weapon slot** (decided 2026-08-08, shipped with WP35). The item in
  it is the **single, fixed source of damage and appearance** for every
  skill of its type — sword-type skills read the weapon slot, shield-type
  skills read the offhand (`combat_stats.md` §2, `classes.md` §2b). There
  is **no fallback to the wielded item**: an empty slot means the connected
  skills carry no item, look as they did before the slot existed and hit
  for the bare-handed baseline. **Weapons are therefore no longer hotbar
  items** — a sword lying in the hotbar drives no skill and no skin.
  - Swing ability stacks mirror this slot's `full_punch_interval` in a
    per-stack tool-capability override whenever the kit or equipment syncs,
    but publish `fleshy = 0`, no digging groupcaps and no attack wear. The
    interval keeps native animation and direct object acquisition aligned with
    the slot; zero damage prevents acquisition-only PvP packets from causing
    builtin knockback. The authoritative held-LMB clock rebuilds the real full
    damage capabilities from this same slot only when WP39's current server
    crosshair ray finds a valid hostile; enemy target memory is not an attack
    source. Their
    item definitions additionally mark the `crumbly`, `snappy` and
    `oddly_breakable_by_hand` groupcaps plus the engine's independent
    `dig_immediate` path as pointability `"blocking"`, so objects remain
    natively punchable without held LMB continuing into node digging. Because
    blocked ground can mask a resting drop's native selection box, a fresh
    Swing LMB press additionally restores builtin-item pickup through a 4 m
    first-visible-object server ray; nodes and other objects stop that ray.
  - **Eligible is whatever carries the item group `grug_equip_weapon`**:
    all four `grug_gear` weapon families (sword, dagger, greataxe, staff) at
    all six material tiers, the below-ladder starters
    (`default:sword_wood`, `default:sword_stone`, `grug_gear:staff_wood`) and
    every **hatchet** — the four vendored `default:` axes plus the four
    `grug_materials` ones that complete the tool ladder. It was twelve
    vendored items when this was written and is **six today**: WP25/WP43
    deleted the mese and diamond tiers and WP13's round-2 merge retired
    `default:sword_bronze`/`_steel` in favour of `grug_gear:sword_bronze` and
    `grug_gear:sword_steel` (`items_crafting.md` §3.0.3).
    `grug_gear/init.lua`'s `VENDORED_WEAPONS` is the live list, and it shrinks
    to nothing by construction as WP28/WP29 fold those items into the material
    ladder. Mining tools stay mining tools — **picks and shovels are not
    eligible**.
  - **A fresh character starts with its class's weapon already in the slot**
    (decided 2026-09-15, playtest round 2). A **Warrior** gets the stone sword,
    a **Priest** and a **Mage** the wooden staff; the grant fires once per
    character when the class is chosen — not at faction choice, where no class
    exists yet — and writes the equipment list server-side through
    `grug_inventory.equipment_changed`, so the ability skins and the visible
    weapon follow exactly as they do for a manual equip. It obeys the
    two-handed rule below rather than bypassing it, and falls back to `main`
    (with a chat line saying so) if the slot cannot take the item. The starter
    torch stays in `main` for the same reason: in the offhand it would cost
    every caster their two-handed staff.
  - **No class gate.** Weapon families are class *flavor*, not a power
    ladder (`items_crafting.md` §8.2), so a Mage may equip a greataxe and
    simply gains nothing from it. The **only** gate on this slot is the
    generated item's `_grug_ilvl`, enforced directly as the minimum character
    level (`grug_inventory/equipment.lua:173-185,330-338`).
  - The slot is **family-agnostic** — it holds whatever carries the group,
    which is how the future bow family joins without a second slot.
  - **No migration**: weapons stay valid `main` items and nothing of a
    character's is moved behind its back. A character that owns a
    slot-eligible weapon, has finished character creation and has the slot
    empty gets a **one-time chat hint** instead. Since the starter grant above
    fills the slot at class choice, a fresh character never sees that hint;
    it survives for a character that took its weapon back out.
- **Hand count — the mechanism for `combat_stats.md` §7's two-handed rule**
  (decided 2026-08-08): every weapon declares `_grug_hands` —
  **greataxe 2, staff 2, sword 1, dagger 1** (the caster 1H family of
  `items_crafting.md` §3.2 is one-handed too when WP30 registers it; the
  below-ladder **wooden staff is 2**, like every staff), and
  every surviving `default:` sword and every hatchet **1** (a hatchet is not the
  Greataxe: 4 fleshy at a 1.0 s interval against the same tier's sword at 6
  and 0.8 s, i.e. strictly worse in combat, and it is the woodcutting tool
  every character carries). An item **without** the field counts as
  one-handed, which is what keeps the rule additive for torches, shields
  and every future offhand item.
  - The rule is one sentence in **both** directions: **the two occupied
    hands must add up to at most two hands.** A two-handed weapon refuses
    an occupied offhand, and an occupied two-handed hand refuses anything
    into the other slot.
  - Enforced in the **same group-filtered `allow_put`** as the armor rank,
    as a **refusal with a chat message that says why** (throttled — the
    allow callback fires repeatedly while a stack is dragged) — never by
    clearing the other slot. Two-handers also carry ", two-handed" in their
    generated stat line, so the trade is readable before the refusal ever
    fires. Rationale: the consequence is a gameplay rule, not a
    technicality — carrying a torch (or later a shield) costs you the
    two-handed weapon. *(The offhand direction cannot fire until an item
    carries `grug_equip_offhand`, i.e. WP14's shields and the carried
    light.)*
- **2 Trinket slots** — **no longer reserved** (decided 2026-08-08).
  UI, meta and the group-filtered `allow_put` shipped with WP15; what
  was missing was an item family, and **trinket items now ship in the
  MVP** as the **Goldsmith's** exclusive family (professions.md §2,
  items_crafting.md §3.6b). A passive trinket has exactly **one primary-
  attribute prefix, one HP/Mana/Crit suffix and one authored trinket
  special** (items_crafting.md §6.2). It has no base-stat line, armor,
  durability, refinement state, cultural finish or extra ordinary-special
  channel. Trinkets carry **no armor class and no class
  rank binding** — every class wears both slots, and they add no armor
  points (combat_stats.md §2), which is why the 60 % armor cap is
  untouched by them. The Unique quality tier keeps the
  ship-the-frame-first strategy on its own; the trinket slots no longer
  share it. The same registered trinket identity may not occupy both slots;
  different identities may, with each special's authored two-slot stacking
  rule controlling their combined effect.
- **Equipment effect channels are separate per stack** (integrated
  2026-08-12):
  - Ordinary equipment retains its refinement plus up to two prefixes and two
    suffixes.
  - Exactly the six combat families weapon, offhand, head, chest, legs and feet
    may additionally carry one **cultural finish**. The finish is an in-place,
    deterministic culture/family effect; trinkets are never eligible. Different
    cultures may be mixed freely across the six slots.
  - An item may also carry at most one **PvP special**, independent of its
    prefix/suffix and cultural-finish data. Applying another target-race special
    overwrites that channel at full cost; applying the identical target again
    is rejected before consuming anything.
  - A cultural finish and a PvP special may coexist on the same eligible item.
    Neither consumes an affix slot, changes the base identity/material tier,
    nor creates a parallel registered-item catalog. Ordinary stat caps apply
    after all equipment sources have been summed; the Talents header displays
    effective/raw Crit, Dodge and Armor with their caps.
  The complete effect, replacement, recipe and tooltip rules live in
  `items_crafting.md` §4/§6.
- No ring/neck/shoulder slots in the MVP.
- Slots are **player-inventory lists** with group-filtered `allow_put`
  (decided during WP15 — auto-persisted, simpler than the 3d_armor
  detached-inventory pattern originally sketched here). Every tracked
  equipment write goes through the one equipment-change notification: caches
  invalidate first, equipment-derived stats recompute before consumers render
  them, and the open Character page refreshes exactly once. Join uses that
  notification after `sfinv` and `player_api`; a genuine nested equipment
  write may cause the documented second notification pass.
- **Weapon level requirement is implemented here:** the same `allow_put`
  filter reads the generated item's `_grug_ilvl` directly for the Weapon slot,
  rejects it when that value exceeds the character's level, and says so in
  chat (`grug_inventory/equipment.lua:173-195,316-356`). Items without a
  positive `_grug_ilvl` and every non-Weapon slot are unrestricted. Rejecting
  the equip is deliberate — letting the item sit in the slot without effect
  would be an invisible failure.
- **Armor classes are bound to the character class** (decided
  2026-08-07 in WP7 — the mechanism `combat_stats.md` §2 and
  `items_crafting.md` §3.1 both assume but never named):
  - Every armor item carries an **armor class**: **cloth 1 < leather 2
    < metal 3** (item group `grug_armor_class`). Items without the
    group are unaffected.
  - Each character class has a **maximum rank** and may wear its own
    rank **and everything below**: **Warrior 3, Mage 1, Priest 1**. A
    character without a class counts as cloth (rank 1). This
    below-inclusive rule is load-bearing since 2026-08-13: leather
    (rank 2) ships as the **Warrior's light avoidance set**
    (`items_crafting.md` §3.8) — a Warrior chooses between metal's
    mitigation pool and leather's avoidance pool, not between wearing
    and not wearing.
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

- **Ordinary items are crafted in the 3×3 grid**, base recipes and profession
  recipes alike; profession items are **multi-stage** (ore → ingot →
  component → item). Cultural finishing and weapon-counter preparation are
  deliberate exceptions: each is a transactional in-place workstation
  operation on one specific stack, so its refinement, quality, affixes,
  durability and unrelated metadata survive. They create no intermediate kit
  or parallel item identity (`items_crafting.md` §4).
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
- Public workbenches are initially **uncraftable and stand in the
  capitals/villages** (placement with WP13); job-supply vendors (thread,
  flux, vials) stand next to them (materials design:
  items_crafting.md). Player-owned profession workstations may also stand
  inside a valid open-world housing claim under
  [housing.md](housing.md) §6.5. Claim ACL access never grants a recipe,
  profession tier or material the character has not unlocked.

## 5. Buff/debuff display (decided 2026-09-17)

Every ordinary timed player effect registers centrally with an id, label,
buff/debuff category and expiry. The registry is runtime-only: a relog drops
ordinary buffs and debuffs. A mechanic that must survive a relog keeps its own
authoritative persistence; the potion cooldown remains in player meta and is
only mirrored into the registry for display.

- **First version:** one top-right HUD text list, buffs first and debuffs
  second, capped at eight lines. Each line is `Name  1:23`; a numeric value
  may follow the name, as in `Shield 12  0:09`. Durations under ten minutes
  use `m:ss`; longer durations use the largest fitting unit.
- One throttled 1 s pass owns timed ticks, expiry and display refresh. It
  calls `hud_change` only when the complete rendered text changed; an idle
  player generates no repeated HUD packets.
- Current entries are Power Word: Shield, Renew, food restore and the
  persistent Potion cooldown (shown in the debuff section). Combat state is
  not a status entry.
- Specialized displays such as the target frame remain separate.
- **WP10 replaces the text presentation with the icon framework:** HUD image
  elements, countdown text, green/red category frames and matching Character
  page tooltips. Effects keep using the same central registry rather than
  gaining per-consumer status stores.
