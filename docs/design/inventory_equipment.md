# Inventory, Character Screen & Equipment

Decided spec (last revised 2026-09-18; established 2026-08-06).
Implementation: WP15 (character screen +
bags), WP10 (workbench UIs), WP14 (offhand slot), WP35 (weapon slot +
hand count), WP38 (native swing capability/pointability bridge), WP39
(current-ray swing authority, shipped 2026-08-10).

## 1. Character screen (the "i" key)

- Built on sfinv pages; **Character is the homepage**. Shared pages use a
  10.4 × 11.1 legacy-coordinate form with the hotbar at `(1.2, 7.2)` and
  the remaining inventory at `(1.2, 8.35)`. Legacy content ends before y=7.0; pages using a content-only real-coordinate
  switch keep their controls above the same physical inventory boundary.
  Character, Bags, Talents, Skills, Crafting, Help and Creative share this
  boundary. The base inventory remains 32 slots.
- Character separates the model, concise live HP/resource/armor values and
  equipment into three columns. The current money balance is shown here, with
  balance changes updating the cached Character view; money has no gameplay HUD.
  Pool derivations use
  `grug_classes.get_pool_breakdown` in a wrapped, scrollable text area;
  long descriptions never share a rectangle with the model or slots.
  Help explains the B/C/G/T/S formula legend.
- Talents keeps the shared legacy inventory geometry but uses real coordinates
  for its page content. Class/stats, tree selection, rank rows and description
  occupy separate vertical bands. It shows both chains with equally sized available/locked controls,
  four ranks rows, and a taller wrapped selected-description area. Tooltips
  wrap at word boundaries. Selection, purchase and respec rules are unchanged.
- Help opens with gathering, Basics, crafting/equipping, Skills, combat and
  city services. Starter recipes are visible immediately; acquiring their
  main material reveals later recipes without restricting crafting permission.
- Creative includes a searchable, paged Food category derived from registered
  edible-food groups, including raw ingredients and cooked results.
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
  - **Eligible items carry `grug_equip_weapon`**: sword, dagger, Battle Axe,
    staff, wand and bow across the six metal tiers. Wood/Stone weapons are
    absent. All gathering tools, including Woodcutting Axes, are excluded.
  - **A fresh character starts with its class's weapon already in the slot**
    (decided 2026-09-15, playtest round 2). A **Warrior** gets the Bronze Sword,
    a **Priest** and a **Mage** the Bronze Staff, and a **Scout** the Bronze
    Bow plus a backup Bronze Sword and 200 arrows; the grant fires once per
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
    item's minimum level. Ordinary T1 weapons use level 1 despite base-stat
    item level 3; elevated found-item levels retain their own requirement.
  - The slot is **family-agnostic** — it holds whatever carries the group,
    including the current bow family, without a second slot.
  - **No migration**: weapons stay valid `main` items and nothing of a
    character's is moved behind its back. A character that owns a
    slot-eligible weapon, has finished character creation and has the slot
    empty gets a **one-time chat hint** instead. Since the starter grant above
    fills the slot at class choice, a fresh character never sees that hint;
    it survives for a character that took its weapon back out.
- **Hand count — the mechanism for `combat_stats.md` §7's two-handed rule**
  (decided 2026-08-08): every weapon declares `_grug_hands` —
  **Battle Axe 2, staff 2, bow 2, sword 1, dagger 1, wand 1**.
  An item **without** the field counts as
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
    technicality — carrying a torch or shield costs you the
    two-handed weapon. *(The offhand direction cannot fire until an item
    carries `grug_equip_offhand`, as shields and carried lights do.)*
- **2 Trinket slots** — **no longer reserved** (decided 2026-08-08).
  UI, meta and the group-filtered `allow_put` shipped with WP15; what
  was missing was an item family, and **trinket items now ship in the
  MVP** as the **Goldsmith's** exclusive family (professions.md §2,
  items_crafting.md §3.6b). A passive trinket has **one selectable primary-
  attribute prefix channel, one selectable HP/Mana/Crit suffix channel and
  one authored trinket special** (items_crafting.md §6.2). Goldsmith base items have empty enchant channels;
  applications have fixed tier values. It has no base-stat line, armor,
  durability, refinement state, cultural finish or extra ordinary-special
  channel. Trinkets carry **no armor class and no class
  rank binding** — every class wears both slots, and they add no armor
  rating (combat_stats.md §2), so they do not contribute to armor. The
  Unique quality tier keeps the
  ship-the-frame-first strategy on its own; the trinket slots no longer
  share it. The same registered trinket identity may not occupy both slots;
  different identities may, with each special's authored two-slot stacking
  rule controlling their combined effect.
- **Equipment effect channels are separate per stack** (integrated
  2026-08-12):
  - Ordinary equipment has at most one prefix and one
    suffix, with no repeated stat. Trinkets retain their fixed exception.
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
    rank **and everything below**: **Warrior 3, Scout 2, Mage 1, Priest 1**. A
    character without a class counts as cloth (rank 1). This
    below-inclusive rule is load-bearing since 2026-08-13: leather
    (rank 2) ships as the **Warrior's light avoidance set**
    (`items_crafting.md` §3.8) — a Warrior chooses between metal's
    rating-based mitigation and leather's avoidance pool, not between wearing
    and not wearing.
  - Enforced in the **same group-filtered `allow_put`** as the rest of
    the slot rules, with a throttled chat refusal (the allow callback
    fires repeatedly while a stack is dragged).
  - A **class change unequips** every piece above the new rank back
    into the main inventory — the filter can only ever refuse an equip,
    so worn gear would otherwise survive a respec untouched. If the
    inventory is full the piece stays worn and the player is told to
    make room.
  - Why the rule exists: without it nothing stops a Mage from buying plate,
    and the rating budgets that `combat_stats.md` §2 uses for the tank/squishy
    spread collapse into "everyone wears the best armor they can afford".

## 3. Bags (WoW model, LotT implementation pattern)

- **Base inventory stays 32 slots** (must not feel cramped); **4 bag
  slots** extend it. Cloth and leather each have four named variants, one per
  mastery tier: **8 / 16 / 24 / 32** slots (`bagslots` group; bag slots + contents are
  player-inventory lists, see above). Four huge bags therefore add 128
  slots. The parallel cloth/leather catalog is an explicit one-item-per-concept
  exception; neither material grants stats, affixes or extra capacity.
- Cloth bags are Tailor products and leather bags are Leatherworker products.
  The **small 8-slot cloth bag is the
  exception and stays vendor-sellable**: it is the floor tier of its
  item category (professions.md §4), so it is bought, not crafted-only.
- Offhand accepts shields, Goldsmith spellbooks and the Leatherworker quiver.
  A two-handed bow explicitly permits the zero-hand quiver; shield, book and
  torch remain illegal beside it. One-handed melee may retain the quiver, while
  staff and greataxe require empty Offhand. The quiver has four arrow-only
  slots of up to 200 arrows each (800 total) and no combat stat or affix.
  It wears as an offhand; a broken quiver permits arrow retrieval but no refill
  or automatic ammunition until repaired. Removing a filled quiver
  transfers all arrows to `main` atomically or refuses unchanged if they do not
  all fit.
- No item drop on death (unchanged; death costs XP, not gear).

## 4. Crafting model (revised 2026-09-21)

- **Basics** is the exclusive category for profession-free recipes. Every recipe
  route belongs to exactly one category: Basics or its owning profession.
  Starter recipes are visible immediately; further Basics recipes appear after
  first acquiring their main material (user decision 2026-09-20). Neither that
  visibility rule nor character level restricts universal recipe crafting.
- Everyone uses the familiar 3×3 layouts to make plain weapons, tools and
  metal, cloth or leather armor. Plain feedstock preparation for cloth, leather
  and processed wood is also profession-free. Professional fittings, grips and
  other improvement materials remain trade goods but are never base-item inputs.
- Named enchant application and replacement use the owning profession station.
  Weaponsmith and Armorsmith share one Forge; Leatherworker uses the Tanning
  Rack, Tailor the Tailor Bench and Woodcarver the Carving Bench. These are
  transactional in-place operations on one concrete stack and preserve its
  metadata and wear. Other profession recipes retain their explicit grid,
  furnace, dual-furnace or brewing-stand route.
- Personal/shared workspaces, viewer-qualified output and universal automatic
  processing follow [the current station contract](crafting_equipment_revision.md#workspaces-and-production).
- Learned profession and T1–T6 profession level gate professional operations.
  Universal Basics routes have neither gate and award no profession progress.
- Recipe books display human item descriptions. A group slot lists concrete
  alternatives with “or”; arrows switch only between complete recipe routes.
- Claim ACL access never grants a recipe, profession tier or material the
  character has not unlocked.

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
- Food labels state the active effect, for example `Food +1% HP/5s` or
  `Food +2% HP, +4% Mana/5s, +2% HP pool`. The regeneration text remains
  visible during combat even though those ticks pause; the item tooltip
  explains that secondary bonuses remain active.
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

## 5. Skills page and bound representations

The sfinv **Skills** page follows Talents and lists all currently unlocked active
abilities plus every purchased riding tier. Its detached catalogue is an
infinite source and matching deletion destination. A drag to the visible main
inventory succeeds only when the exact item is absent from `main`, `craft` and
all four owned bag-content lists and main has room.

Ability and mount representations carry `grug_bound_skill`. Player inventory
moves allow only `main` and owned bag contents; all node metadata inventories,
other detached inventories, crafting and equipment refuse them. Source takes
remain allowed so Q/drop reaches the item's deletion-only callback. Entitlement,
cooldowns, charge, resources and active mounts are independent of the disposable
item stack.

## Round 14 navigation pages

The inventory gains separate Quests, Group and Map tabs, following `quests.md`,
`parties.md` and `world_map.md`. Quests and Group each own a saved HUD toggle,
default on; empty quest logs and ungrouped players have no corresponding HUD.
Party rows show name and HP only, with explicit offline state. HUD allocation
uses the shared layout authority so party, quest and transient notices do not
overlap existing combat bars, target information or status effects.

## Round 16 readability amendments (2026-09-22)

Armor hover descriptions explicitly state Cloth, Leather or Metal, including
named enchanted variants. A compact Combat indicator appears beside the life
bar only while the living player is in the existing combat state. Station recipe
book buttons occupy a separate right-hand position clear of input/fuel/output
slots, mode explanations and crafting-operation controls.
