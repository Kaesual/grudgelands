# Inventory, Character Screen & Equipment

Decided spec (last revised 2026-10-01; established 2026-08-06).
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
  Beside the balance a **Withdraw** button and a **deposit slot** handle the
  Bag of Coins (Round 34, [economy.md](economy.md) §1).
  Round 19 removes the pool/armor derivation section. Character shows concise
  effective Crit and Dodge alongside armor rating, **Damage reduction** (the
  armor's reduction against an enemy of the character's own level; its tooltip
  says so and that it is higher against lower-level and lower against
  higher-level enemies; Round 28 ruling 21) and maximum pools. General formulas and the B/C/G/T/S legend belong to Help.
- Talents keeps the shared legacy inventory geometry but uses real coordinates
  for its page content. Class, tree selection, rank rows and description occupy
  separate bands; combat statistics belong to Character. Both chains use equally
  sized available/locked controls and wrapped tooltips. Clicking an available
  talent buys one rank immediately. Respec retains confirmation and its price.
- Help is a short player guide in six sub-pages chosen by buttons at its top
  (the selection lives in the sfinv context; Start is the default): **Start**
  (first steps, levels and zones, capitals, protected ground), **Quests &
  Professions**, **Basics** (ores by depth and pick tier, smelting, recipe
  discovery, skills, bags, food, repair, riding, home travel, death, groups),
  **Formulas** (the general pool/attribute/armor/mana formulas and the
  B/C/G/T/S legend), **About** (Discord, GitHub issues and repository,
  support link) and **Sound** (music and ambience on/off and volume per
  player, the same as `/music` and `/ambience`; Round 34). Body text is a
  scrolling `hypertext[]`; links are read-only `textarea[]` rows the player
  can select and copy, each with a `button_url[]` that asks before opening a
  browser. Starter recipes are visible immediately; acquiring their main
  material reveals later recipes without restricting crafting permission.
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
  - The two hand slots take their ghost and tooltip label from the class
    (Round 28): Warrior sword / shield ("Weapon" / "Shield"), Mage and
    Priest staff / spellbook ("Weapon" / "Caster offhand"), Scout bow / sword
    ("Ranged" / "Melee"). The Scout's quiver slot shows a dimmed quiver.
- Further pages: **Bags**, existing **Crafting** (3×3 grid).
- Armor visuals on the player model: composed with the character's look
  ([character_visuals.md](character_visuals.md) §1, §3).

## 2. Equipment slots (MVP)

- **Head, Chest, Legs, Feet, Weapon, Offhand** (weapon slot: the block
  below; offhand mechanics: `combat_stats.md` §7 / WP14). Armor keeps its
  own column on the character page; **Weapon and Offhand sit next to each
  other** so the pair reads as "hands".
- **The hand slots are per class** (Round 28 ruling 25). The two lists keep
  their names (`grug_weapon`, `grug_offhand`); what each one accepts, its
  label and its ghost image depend on the class
  (`grug_inventory.HAND_RULES`):

  | Class | Weapon slot | Offhand slot |
  |---|---|---|
  | Warrior | "Weapon": sword, dagger, Battle Axe | "Shield": shields (only Warriors equip shields) |
  | Mage, Priest | "Weapon": staff, wand, dagger | "Caster offhand": spellbooks |
  | Scout | "Ranged": bows | "Melee": sword or dagger |

  Why: the Scout has two kinds of skills, and with one weapon slot its melee
  skills swung with the bow. A visible per-class offhand makes each slot's
  purpose obvious, and then it is fair that **both slot items always count
  toward stats for every class** (`grug_quality` sums every equipment slot).
  A wrong item is refused with a message that names the slot it belongs in.
  A character without a class (still in creation) equips nothing in its
  hands.
- **The Weapon slot** (decided 2026-08-08, shipped with WP35). The item in
  a hand slot is the **single, fixed source of damage and appearance** for
  every skill that reads it (`combat_stats.md` §2, `classes.md` §2b): Strike
  and every melee skill read the **melee slot** — the Scout's Melee offhand,
  everyone else's Weapon slot — the Scout's bow skills read Ranged, every
  other skill reads the Weapon slot, and shield-type skills would read the
  offhand. There
  is **no fallback to the wielded item**: an empty slot means the connected
  skills carry no item, look as they did before the slot existed and hit
  for the bare-handed baseline. **Weapons are therefore no longer hotbar
  items** — a sword lying in the hotbar drives no skill and no skin.
  - Ability stacks preserve native held-LMB hand digging and animation while
    publishing zero native combat damage. A held press is gathering (hand
    digging, pickup) or combat locked on a foe; a press on a hostile starts
    in combat, and a gathering hold turns into combat when a hostile comes
    into the crosshair and reach while an attacking skill is selected, and
    back once that foe is gone (Round 32); abilities never borrow tool
    digging power. Combat never digs and gathering never attacks.
    The equipped weapon supplies combat damage and cadence; the skill token
    takes no equipment wear. See `classes.md` §2b for click arbitration,
    cooldown fallback, right-click actions and accepted engine limits.
  - **Eligible items carry `grug_equip_weapon`**: sword, dagger, Battle Axe,
    staff, wand and bow across the six metal tiers. Wood/Stone weapons are
    absent. All gathering tools, including Woodcutting Axes, are excluded.
  - **A fresh character starts with its class's weapon already in the slot**
    (decided 2026-09-15, playtest round 2). A **Warrior** gets the Bronze Sword,
    a **Priest** and a **Mage** the Bronze Staff, and a **Scout** the Bronze
    Bow in Ranged, the Bronze Sword in Melee and 200 arrows in its quiver
    (Round 28); the grant fires once per
    character when the class is chosen — not at faction choice, where no class
    exists yet — and writes the equipment list server-side through
    `grug_inventory.equipment_changed`, so the ability skins and the visible
    weapon follow exactly as they do for a manual equip. It obeys the
    two-handed rule below rather than bypassing it, and falls back to `main`
    (with a message-feed line saying so) if the slot cannot take the item. The starter
    torch stays in `main`; torches are not offhand items (no carried light,
    `combat_stats.md` §7).
  - **Class-family permissions:** Warrior: sword, dagger, Battle Axe;
    Scout: bow, sword, dagger; Mage and Priest: staff, wand, dagger. The
    hand-slot table above says which slot takes which family. Level and
    occupied-hand checks also apply; the level check covers every slot (below).
    Ordinary T1 items require level 1 despite base-stat item level 3;
    elevated found-item levels retain their own requirement. Common `Usable by`
    tooltip text lists permitted classes; it never changes with the viewer.
    Broken items remain visibly equipped but provide no usable combat weapon.
  - **No migration**: weapons stay valid `main` items and nothing of a
    character's is moved behind its back. A character that owns a
    slot-eligible weapon, has finished character creation and has the slot
    empty gets a **one-time chat hint** instead (kept in chat: it is too
    long to read in the message feed). Since the starter grant above
    fills the slot at class choice, a fresh character never sees that hint;
    it survives for a character that took its weapon back out.
- **Hand count — the mechanism for `combat_stats.md` §7's two-handed rule**
  (decided 2026-08-08): every weapon declares `_grug_hands` —
  **Battle Axe 2, staff 2, sword 1, dagger 1, wand 1, bow 1** (the bow is
  one-handed since Round 28: only the Scout uses it, beside its Melee
  blade).
  An item **without** the field counts as
  one-handed, which is what keeps the rule additive for shields and every
  future offhand item.
  - The rule is one sentence in **both** directions: **the two occupied
    hands must add up to at most two hands.** A two-handed weapon refuses
    an occupied offhand, and an occupied two-handed hand refuses anything
    into the other slot.
  - Enforced in the **same `allow_put`** as the armor rank,
    as a **refusal with a message-feed line that says why** (throttled — the
    allow callback fires repeatedly while a stack is dragged) — never by
    clearing the other slot. Two-handers also carry ", two-handed" in their
    generated stat line, so the trade is readable before the refusal ever
    fires. Rationale: the consequence is a gameplay rule, not a
    technicality — carrying a shield or spellbook costs you the
    two-handed weapon.
- **2 Trinket slots** — **no longer reserved** (decided 2026-08-08).
  UI, meta and the group-filtered `allow_put` shipped with WP15; what
  was missing was an item family, and **trinket items now ship in the
  MVP** as the **Goldsmith's** exclusive family (professions.md §2,
  items_crafting.md §3.6b). A passive trinket has **one selectable primary-
  attribute prefix channel, one selectable HP/Mana/Crit suffix channel and
  one authored trinket special** (items_crafting.md §6.2). Goldsmith base items have empty enchant channels;
  applications have fixed tier values. It has no base-stat line, armor,
  durability, refinement state or extra ordinary-special channel. Trinkets carry **no armor class and no class
  rank binding** — every class wears both slots, and they add no armor
  rating (combat_stats.md §2), so they do not contribute to armor. The
  Unique quality tier keeps the
  ship-the-frame-first strategy on its own; the trinket slots no longer
  share it. The same registered trinket identity may not occupy both slots;
  different identities may, with each special's authored two-slot stacking
  rule controlling their combined effect.
- **Equipment effect channels are separate per stack** (integrated
  2026-08-12; cultural finishes and PvP specials removed in Round 33):
  ordinary equipment has at most one prefix and one suffix, with no repeated
  stat; trinkets retain their fixed exception. Ordinary stat caps apply
  after all equipment sources have been summed; Character displays effective
  Crit/Dodge and armor rating/reduction, with formulas and caps explained in Help.
  The complete effect, replacement, recipe and tooltip rules live in
  `items_crafting.md` §6.
- No ring/neck/shoulder slots in the MVP.
- Slots are **player-inventory lists** with group-filtered `allow_put`
  (decided during WP15 — auto-persisted, simpler than the 3d_armor
  detached-inventory pattern originally sketched here). Every tracked
  equipment write goes through the one equipment-change notification: caches
  invalidate first, equipment-derived stats recompute before consumers render
  them, and the open Character page refreshes exactly once. Join uses that
  notification after `sfinv` and `player_api`; a genuine nested equipment
  write may cause the documented second notification pass.
- **The level requirement is implemented here** (Round 33, every equipment
  slot): the same `allow_put` filter asks `grug_core.can_use_item_level` —
  the stack's own `grug_req_level`, else the definition's `_grug_req_level`
  (min(item level, 60); 1 for T1 items) — in every equipment slot, rejects
  the item when that value exceeds the character's level, and says so in the
  message feed, naming the slot (`grug_inventory/equipment.lua`). Items
  without a positive level are unrestricted. The tooltip ends with
  "Requires level N" above level 1 (`items_crafting.md` §6.1). Rejecting
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
    the slot rules, with a throttled message-feed refusal (the allow callback
    fires repeatedly while a stack is dragged).
  - A **class change unequips** every piece above the new rank back
    into the main inventory — the filter can only ever refuse an equip,
    so worn gear would otherwise survive a respec untouched. If the
    inventory is full the piece stays worn and the player is told to
    make room.
  - Why the rule exists: without it nothing stops a Mage from buying plate,
    and the rating budgets that `combat_stats.md` §2 uses for the tank/squishy
    spread collapse into "everyone wears the best armor they can afford".

## 3. Bags (classic MMO model, LotT implementation pattern)

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
- **The quiver is a Scout-only slot** (Round 28 ruling 26), drawn left of the
  armor column on the Character page with the arrow total beside it. There is
  no quiver item and no Leatherworker quiver recipe; non-Scouts have no quiver
  slot. It holds up to **500 arrows**; arrows stack to **100** in any
  inventory. Internally the list `grug_quiver_content` carries five stacks of
  100, but only its first cell is drawn and it always holds min(total, 100):
  **clicking the slot takes up to 100 arrows as one stack**. Arrows enter by
  **drag** (onto the slot), **shift-click** (from the inventory) and **pickup**
  while the quiver has room; anything else is refused. Shots draw from the
  quiver first, then `main`; a talent refund returns to the quiver first. A
  drag of part of a stack onto the slot while it shows a full 100 moves the
  whole stack in (the engine treats that drop as a whole-stack swap).
  No item drop on death, so the quiver keeps its arrows like the equipped
  items do.
- No item drop or XP loss on death (Round 18).

## 4. Crafting model (revised 2026-09-21)

- **Basics** is the exclusive category for profession-free recipes. Every recipe
  route belongs to exactly one category: Basics or its owning profession.
  Starter recipes are visible immediately; further Basics recipes appear after
  first acquiring their main material (user decision 2026-09-20). Neither that
  visibility rule nor character level restricts universal recipe crafting.
- Everyone uses the familiar 3×3 layouts to make plain weapons, tools and
  metal, cloth or leather armor. Plain feedstock preparation for cloth, leather
  and processed wood is also profession-free. Professional components such as
  settings are never base-item inputs.
- Named enchant application and replacement use the owning profession station.
  Weaponsmith and Armorsmith share one Forge; Leatherworker uses the Tanning
  Rack, Tailor the Tailor Bench and Woodcarver the Carving Bench. These are
  transactional in-place operations on one concrete stack and preserve its
  metadata and wear. An enchanted weapon, offhand or armour piece shows its
  prefix and suffix colours (character_visuals.md §5a) on its own inventory
  image, which also draws it in hand and when dropped and is rebuilt whenever
  its affixes change; a plain stack carries no image of its own. Each
  enchanting station shows the colour legend. Other profession recipes retain their explicit grid,
  furnace, dual-furnace or brewing-stand route.
- Authored capital/POI stations are personal workspaces keyed by player and
  physical station. Player-placed stations share node inventories; inside an
  active Claim Stone claim, access follows the claim's permission list
  (`housing.md` §6), with no station-specific owner or ACL. Shared 3×3
  inputs are common while each viewer's output preview is qualified
  independently. A successful take revalidates recipe, station,
  distance, access, inputs, profession tier and capacity before consuming or
  awarding progress. Partial transfers retain produced remainder without a
  second debit or progress award, and closing a UI loses no contents.
  Digging a player-placed station is allowed whenever protection allows it
  and drops all of its contents and every player's saved workspace record
  (`crafting_equipment_revision.md`, Round 28 ruling 18).
- Personal processing state, fuel, inputs and outputs persist in the physical
  node. Elapsed server game time may catch up lazily after unload/restart but
  does not promise work during shutdown. Automatic furnace, dual-furnace and
  brewing completion is universal and gives no profession progress; only the
  protected qualified preparation/craft grants current-tier progress.
- Learned profession and T1–T6 profession level gate professional operations.
  Universal Basics routes have neither gate and award no profession progress.
- Recipe books display human item descriptions. A group slot lists concrete
  alternatives with “or”; arrows switch only between complete recipe routes.
- Claim permission never grants a recipe, profession tier or material the
  character has not unlocked.

## 5. Buff/debuff display (decided 2026-09-17)

Every ordinary timed player effect registers centrally with an id, label,
buff/debuff/neutral category and expiry (`grug_core.set_status`; the icon
table is `grug_core.status_icons`). The registry is runtime-only: a relog
drops ordinary buffs and debuffs. A mechanic that must survive a relog keeps
its own authoritative persistence.

**Status icon row** (Round 26 Lane I, the status-icon package of WP audit
D10; [plan](../planning/round26-capitals-housing-cleanup-plan.md) rulings
17–23, [effect list](../planning/status-icons-2026-09-29.md)). It replaces
the Round 19 top-centre text list:

- **Place:** bottom centre, a row of 40 px icons directly above the breath
  and skill rows, so the top centre belongs to the target frame alone.
- **Look:** 64 px art on the dark skill-icon plate, with a frame drawn by
  code: green for buffs, red for debuffs, gold for neutral states. The
  caption under each icon is the countdown or the value (for example a
  shield's remaining absorb).
- **Capacity:** at most 10 icons. When more statuses run, debuffs keep their
  slots first, then neutral states, then buffs.
- **No cooldowns** on the row (ruling 21): the potion cooldown is no longer
  shown; its refusal messages remain.
- **Registered statuses:** food (the eaten item's own image, else the
  generic food icon), elixirs, draughts, mounts (land or flight; an untimed
  status, so the row caption is empty and the tier name and "+N% speed"
  appear only on the Effects tab), one shield icon for every absorb source,
  move immunity, Sprint, Sidestep and Mend (their skill icons), the six
  talent windows (Unbroken, Ruination, Whitehot, Turn Aside, Last Word,
  Untouchable), poisoned, slowed (one icon for every slow), rooted, stunned
  and scorched (1.5 s per Dragon Scorch tick); the neutral (gold) PvP flag
  (Round 31, `grug_pvp/hud.lua`, a status source read from
  `grug_pvp.state`): "Contested Territory" or "Enemy Territory" (untimed)
  while the location flags the player, "PvP flagged" with the countdown while
  the button or PvP contact does.
- **The combat state is not a status.** It never takes a row slot or appears
  on the Effects tab: `grug_core/combat_hud.lua` draws a 32 px gold-framed
  crossed-swords icon right of the health bar, where the "Combat" text was.
- A food status is named after the dish itself; its effect, for example
  `+2% HP/5s` or `+6% HP, +6% Mana/5s, +2% Mana pool`, is the detail line on
  the Effects tab. The item tooltip explains that secondary bonuses remain
  active while the regeneration ticks pause in combat.
- One throttled pass every 0.5 s owns timed ticks, expiry and display refresh, and
  changes a HUD element only when its content changed; an idle player
  generates no repeated HUD packets. A poison chain ends on death.
- **Character page tabs:** "Stats" (the view as before; since Round 30 it
  also carries the **Return home** button with its cooldown in whole
  minutes, re-sent when the text changes, [home_travel.md](home_travel.md)),
  "Effects": icon,
  name, remaining time and a detail line per status, refreshed about once a
  minute or on change while that tab is open, and "Professions" (Round 28
  ruling 23): per known profession (primary slots, then Cooking and Alchemy) its tier,
  "Crafts: n/m toward tier N+1" (`professions.md` §1 counts; "Highest tier
  reached." at T6) and, while the character's ten-level band caps the tier,
  the note "Capped by your level: reach level 10N+1, then craft once more
  for tier N+1" when the count is full and only the character level blocks
  the next tier. A counted craft refreshes the tab while it is open.
  Since Round 33 a tab "Achievements" sits between Effects and Professions,
  and the Stats view has the **cloak picker** under the model
  ([character_visuals.md](character_visuals.md) §5b).
- **Class icons** (Warrior, Mage, Priest, Scout) appear in the party HUD
  list and in the Group page's "Current party" table (`parties.md`).
- Specialized displays such as the target frame remain separate. Effects
  keep using the one central registry rather than per-consumer status
  stores. Art provenance: `tools/r26_icons/` and the `LICENSE-media.md` files
  of `grug_core` and `grug_classes`.

## Message feed and level-up banner (Round 28 ruling 20)

Gains the player just earned and short combat notices appear near their own
bars instead of in chat (the top-left chat was easy to miss). There is **no chat copy** of any of
them.

- **Place:** bottom centre, stacked upwards from 6 HUD units above the status
  icon row, which itself sits right above the skill-name row; the row is
  reserved even when no status runs, so the feed never moves. Line pitch is
  20 GUI units converted to HUD units, and the feed rises with the icon row
  at larger GUI scaling (`grug_core.hud_layout.feed_line_offset`).
- **Lines:** at most 3, newest at the bottom; each lives 2.5 s and is drawn
  at 45 % brightness for its last 0.5 s (HUD text has no alpha fade on every
  client). Colours by kind: loot white, XP purple (`#aa66ff`), quest yellow
  (`#ffe080`, also talent points), fishing light blue, combat notices grey
  (`#aaaaaa`), other notices and refusals the neutral notice colour
  (`#f0e6c8`).
- **Content:** XP gains as "+N XP", every grant within 1.5 s of the previous
  one summed into the same line; items picked up off the ground (mob drops,
  dropped items) and boss loot entering the inventory as "+3 Light Leather",
  summed per item while that line is shown (also queued boss loot delivered
  on join and quest reward items at turn-in); quest progress as one line per
  quest, every objective as "<name> n/m" joined by ", " ("Small Boar 3/10"),
  a quest's newer line replacing its own older one, cut to the widest
  tracker line (38 characters, "..."); fishing catches as
  "Caught <fish> (+N XP)" (junk: "Caught <item>"); combat notices
  "You dodge!" and "Dismount before attacking." (a mounted attack, at most
  once a second); and since Round 32 the personal notices: potion and food
  refusals (level, potion cooldown, full health, no mana pool, not
  poisoned), equip refusals (armor class, weapon level, hand slot,
  two-handed rule), the class-change unequip notices, the starter-weapon
  line at class choice, the raw-weapon hint, mount notices (dismount
  reason, flight-boundary warning, summon refusal, a mount not bound to
  this character), talent points earned or
  returned, and "Boss loot is waiting: free main inventory space, then
  rejoin." (queued boss loot is handed over at the next join). Each
  notice group keeps one keyed line that a repeat refreshes (`potion`,
  `food`, `equip:<reason>`, `class_change:*`, `starter:<slot>`,
  `weapon_hint`, `mount`, `talents`, `boss_loot`, `combat:*`).
  Still in chat: death messages, rare sightings for the faction, the dragon
  arena's warnings, a boss's return warning and the one-time no-weapon hint
  (too long for the feed's 2.5 s).
- **Level-up** is a separate large centre announcement ("Reached level N!",
  double font size, 3 s), not a feed line.
- **API** (`grug_core/feed.lua`): `grug_core.feed(player, kind, text, key)`
  (a line with the key of a shown line replaces it),
  `grug_core.feed_xp(player, amount)`, `grug_core.feed_item(player, item,
  count)` and `grug_core.banner(player, text, color)`. `grug_xp.add_xp`
  posts every positive grant itself; a caller that names the XP in its own
  line passes `quiet`.

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

The Skills catalog has a short visible hint: "Drop skills to remove them. Drag
them back from here." This does not alter entitlement or the one-copy rule.

## Round 14 navigation pages

The inventory gains separate Quests, Group and Map tabs, following `quests.md`,
`parties.md` and `world_map.md`. Quests and Group each own a saved HUD toggle,
default on; empty quest logs and ungrouped players have no corresponding HUD.
Since Round 27 the Map tab likewise owns the saved "Show minimap" switch for
our own minimap, default on (`world_map.md`). Since Round 31 a PvP tab
(right after Group, `grug_pvp/page.lua`) holds the "Flag me for PvP"
button, the current state (safe, or flagged with the reason and the seconds
left; PvP combat) and the PvP statistics; it is re-sent once a second only
while its text changes.
Party rows show name and HP only, with explicit offline state. HUD allocation
uses the shared layout authority so party, quest and transient notices do not
overlap existing combat bars, target information or status effects.

## Round 16 readability amendments (2026-09-22)

Armor hover descriptions explicitly state Cloth, Leather or Metal, including
named enchanted variants. The combat state is shown while the living player
is in combat; since Round 26 it is a 32 px gold-framed crossed-swords icon
beside the life bar (`grug_core/combat_hud.lua`), no longer a "Combat" text,
and not part of the status row (§5). Station recipe
book buttons occupy a separate right-hand position clear of input/fuel/output
slots, mode explanations and crafting-operation controls.

## Round 18 interaction clarity

Weapon-slot tooltips and contextual raw-weapon hints explain that equipped
weapons provide combat stats while hotbar skills execute attacks. No automatic
equipping or hotbar-weapon combat fallback. The top inventory row is explicitly
highlighted as Hotbar. Selected page controls use a visible border/tint rather
than a `>` prefix. Crafting starts with recipe-book guidance; Skills explains
safe icon deletion/recovery and one carried copy across main/craft/owned bags.
