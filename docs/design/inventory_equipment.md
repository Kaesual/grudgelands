# Inventory, Character Screen & Equipment

Decided spec (last revised 2026-10-08; established 2026-08-06).
Implementation: WP15 (character screen +
bags), WP10 (workbench UIs), WP14 (offhand slot), WP35 (weapon slot +
hand count), WP38 (native swing capability/pointability bridge), WP39
(current-ray swing authority, shipped 2026-08-10).

## 1. The inventory window (the "i" key)

- Built on sfinv pages in one frame (Round 44, `grug_inventory/ui.lua`):
  `formspec_version[6]` with a real-coordinate `size[13.500,13.673]`, the
  same window as the old legacy 10.4 × 11.1 form. Every tab keeps that size
  (the Inventory tab's boxed layout fits it with seven rows and the money
  row; the user, 2026-10-09);
  the Map tab opens the map window, a form of its own sized to the screen
  (Round 44, [world_map.md](world_map.md#map-window)). Page content follows a
  `real_coordinates[false]`, so pages still in legacy coordinates keep their
  place and end before legacy y=7.0; pages in real coordinates start their
  content with `real_coordinates[true]`.
- **Tabs, in this fixed order** (one table, `grug_inventory.TAB_ORDER`, not
  the mods' load order): **Inventory** (the homepage, what "i" opens) ·
  Character · Talents & Skills · Crafting · Party & PvP · Help · Map. The
  quest log is in the map window. Creative's tabs, for creative players,
  follow the table.
- **Inventory views** (`grug_inventory.inventory_view(player, mode,
  context)`): `main[9..]`, then each equipped bag's content list in slot
  order, as one 8-wide grid in a scroll area (bag sizes are multiples of 8,
  so there are no gaps), and the hotbar (`main[1..8]`) below it, outside the
  scroll area. Both are boxed like the Inventory tab (Round 45 playtest,
  `grug_inventory.LAYOUT`): an **Inventory** box with the grid and its
  scrollbar and the gold **Hotbar** box, each labelled inside, top left
  above the slots. **Full** shows seven rows (the Inventory tab, layout
  below); **short** shows two (every other tab with an inventory), its
  Inventory box right above the Hotbar box. The Hotbar box is at the same
  place in every tab, so it does not jump on a tab switch; page content
  ends above the short Inventory box (`VIEW_GEOMETRY.top`). The scrollbar's
  thumb shows the visible share of the rows, so it can be dragged. A page asks the frame for its view and never draws `main`
  itself; Help and Party & PvP show **no** view (Round 44 lane PP): their
  content has the whole window. The scroll position is kept per view and sent back with every
  rebuild (the client forgets it on a resend), so equipping a bag or sorting
  keeps the place; a pure scrollbar event re-sends nothing. No listring in
  the views: shift-click has no job inside one inventory.
- **The Inventory tab** ([UI rework spec](../planning/ui-crafting-rework-plan.md) §3.2;
  boxed layout since the Round 45 playtest, `grug_inventory.LAYOUT`):
  each area has its own box with its label inside, top left above the
  slots. Along the top the four **Bags** slots and the four-slot **Potion
  belt** (`grug_potion_belt`, potions and elixirs only), sharing the full
  width; below them the **Inventory** box (the full view's grid and
  scrollbar, at most 24 + 4 × 32 = 152 slots in 19 rows), the **money
  row** and the **Hotbar** box (gold, the other boxes the Character tab's
  dark tint). All boxes share one left edge and one right edge; the group
  is centred in the window. The money row has no box and lies on the slot
  columns: "Money" over the balance (e.g. "123456g 99s 99c"), **Withdraw**
  (opens the Bag of Coins dialog, [economy.md](economy.md) §1), the Bag of
  Coins **deposit slot** and, at the right end with the hotbar's last slot,
  **Sort**; Withdraw and Sort are exactly as tall as the slot. A balance
  change re-sends the Inventory page while it is the selected page (also
  with the window closed, so it opens current); money has no gameplay HUD.
  Sort orders
  `main[9..]` and the bags (never the hotbar); after a sort it ignores clicks
  for 2.5 s, with no countdown and no resend. The old Bags tab (one bag at a
  time, a 32-slot bag cut to 24) is gone.
- **The Character tab** (Round 44, [UI rework spec](../planning/ui-crafting-rework-plan.md)
  ruling 6 and §3.3; real coordinates): top left the **mode box**, top right
  the **gear box**, both ending a gap above the short inventory view's box.
  The mode buttons switch the box only, the choice is runtime context (never
  stored): **Stats** (the default: the model on the left; right of it the
  stats and the Claim Stone status, and at the foot the cloak picker,
  bottom-aligned with the model, "Cloaks unlock through achievements." as
  its tooltip; 3D and Stats are one mode since the Round
  45 playtest), **Effects** and **Achievements**; the professions overview
  moved to the Crafting tab in Round 45.
  The gear box shows the eight equipment slots with each slot's name beside
  it (the hands' names per class, §1 below), the Scout's quiver under them
  and, at its foot in every mode, the travel home's name and the **Return
  home** button with its state ([home_travel.md](home_travel.md)).
  **Shift-click** moves between the inventory and the equipment: every list
  the page draws rings to `grug_shift`, a one-slot list no page draws and
  that never holds anything (whatever another writer leaves there goes back
  through the give helper at join), whose allow callback applies the move itself
  (`equipment.lua`; a listring alone reaches only one next list and fills
  `main` from the hotbar). From `main` (hotbar included) or a bag a piece
  of gear goes into its slot — an empty slot of its kind first, else it
  swaps with the equipped piece, which takes the source cell — under the
  drag's equip rules and refusal lines; arrows go into a Scout's quiver.
  From an equipment slot or the quiver the item goes into the inventory in
  the give order (`main[9..]`, the bags, the hotbar last), or stays with a
  feed line when it does not fit. Anything else does not move.
  The balance, **Withdraw** and the deposit slot are on the Inventory tab
  (the deposit since Round 44, balance and Withdraw since the Round 45
  playtest).
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
  discovery, skills, bags, food, repair, riding, home travel, death, parties),
  **Formulas** (the general pool/attribute/armor/mana formulas and the
  B/C/G/T/S legend), **About** (Discord, GitHub issues and repository,
  support link) and **Sound** (music and ambience on/off and volume per
  player, the same as `/music` and `/ambience`; Round 34). Body text is a
  scrolling `hypertext[]`; links are read-only `textarea[]` rows the player
  can select and copy, each with a `button_url[]` that asks before opening a
  browser.
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
  - The two hand slots take their ghost and label from the class
    (Round 28): Warrior sword / shield ("Weapon" / "Shield"), Mage and
    Priest staff / spellbook ("Weapon" / "Caster offhand"), Scout bow / sword
    ("Ranged" / "Melee"). The Scout's quiver slot shows a dimmed quiver.
    Since Round 44 every slot's name is also printed beside it in the gear
    box; the tooltips stay.
- **The Crafting tab** (Round 45, [UI rework spec](../planning/ui-crafting-rework-plan.md)
  §2.16–2.22, §4.2–4.5; real coordinates; the short view below): the 3×3
  grid and the recipe books are gone. Along the top the **area tabs**:
  Basic (the default), Cooking, the two primary slots ("Primary 1" and "2"
  while empty) and Alchemy, beside them the chosen area's tier progress
  ("Tier 3 · 7/15" with a small bar, "Tier 6 · highest", "Not learned",
  Basic has none). An empty primary slot or an unlearned profession shows an
  empty list with how to learn it.
  - **Left, the list** (`professions.md` §1.2): the area's recipes up to
    the player's profession tier there (Basic: all), ordered by tier, then
    name; 10 rows per page with "Page x of y"; a row is
    the output's icon, its name (a clipped name shows in full as its
    tooltip) and **×N**, the crafts the ingredients allow by the job's rule
    (stacks without metadata only), counted in one pass over the inventory
    per build. **Search** (the button or Enter) filters by the output's name
    on the server, at most once a second (a quicker request is ignored
    without a resend); **Craftable only** keeps the rows with ×N ≥ 1.
  - **Middle, the crafting box** in three stacked areas (Round 45 playtest
    fix 3). **Top:** the chosen recipe's output (its name in up to two
    lines, area, tier, "makes N"). **Middle:** the made item's description
    as its tooltip reads, without the name line and without colours, in a
    read-only text area that scrolls when long (a scroll sends nothing) and
    takes the room the rest leaves; left out when the tooltip is only the
    name. Gear (weapons, armour, offhands, trinkets, tools) shows the item
    the job makes (Common, no enchants, the tier's base item level, stats,
    requirement); a raw dish shows the cooked dish of its furnace recipe and
    "Must be cooked in a furnace to become edible."; anything else its own
    description. Below it the ingredients with icons and have/need for the
    field's quantity (a group entry reads "Any Wood", its members in the
    tooltip), "Max: N" ("(output area)" when the room limits it), the
    warnings, the note of the last refused action and the XP hint:
    "Crafting this will give you a <profession> experience point" in green
    when the job counts toward the tier, grey with "not" for a lower tier,
    the highest tier or a full tier count. **Bottom:** the **quantity
    field** with **Max** (stackable outputs only, default 1), below it
    **Craft now**. A missing station reads "Requires: <station> nearby" and
    a missing profession tier its reason; both draw **Craft now** greyed,
    and a click on it only rebuilds the page (checking the station again).
    While a job runs the button is **Stop**. Without a chosen recipe the box shows the professions overview
    (per known profession its tier, "Crafts: n/m toward tier N+1",
    "Highest tier reached." at T6 and the level-cap note, as the Character
    tab did until Round 45; rows that do not fit point to the area tabs).
  - **The enchant and upgrade boxes** (Round 45 lane EU, spec §2.24, §2.26,
    §4.6): a learned primary area shows the buttons "Enchant an item" and
    "Upgrade an item" below its list (ordinary buttons; the open box's one
    in the gold selection colour); a recipe row or an area tab returns to
    the recipe box. Both boxes draw the **target slot** `grug_craft_target` (one piece
    of equipment; shift-click moves an item of `main` into it; placing or
    taking it resends the page). The **enchant box**: the slot, an arrow,
    the preview (the result's image, its computed description as the
    tooltip), the profession's enchants valid for the item up to the
    profession tier, best tier first, each with the value it gives on this
    item ("T5 prefix: +11 Strength"), the chosen one's materials with
    have/need, the overwrite warning ("Replaces T7 Strength with T6
    Strength."), the XP hint and **Enchant now** (5 s), which turns into
    **Cancel**. The **upgrade box**: the slot, the item level and the cap
    ("Cap 30 (Weaponsmith tier 3)"), **+N levels** with **Max** (to the cap,
    as far as the materials pay), the resulting item level, the materials
    for N levels, and **Upgrade now**; a result that needs a higher level
    than the player's shows the permanent warning "The target item level
    exceeds your level, you won't be able to use this item before you have
    reached level N." and the yellow **Upgrade anyway**. The server learns
    N only with a click, so a click for an item and count not yet shown
    with the warning shows it and the next one starts (spec §4.3); a count
    above the cap or the materials is lowered with its note. An item at or
    above its cap reads "Already at the cap (item level C)." and takes no
    level. The running job reads "Enchanting…" with the item's name, or
    "Upgrading…" with "Steel Sword +3 levels". An item left in the slot
    goes back into the inventory at join and when a profession is unlearned
    (the give helper, then the output area; with no room anywhere it stays
    in the slot).
  - **The quantity field** (spec §4.3): Enter recalculates and never starts;
    Craft now above the maximum lowers the field to it with the job's note
    ("Not enough ingredients — quantity reduced to N") and starts nothing;
    the field echoes the last value the server knows on every resend.
  - **Right, the output area:** the four take-only slots (shift-click moves
    a stack into `main`), **Take all** (the give order; what does not fit
    stays, with a note), and the job: "No job running", or the green
    "Crafting…" indicator, the job's label ("Hearty Stew ×10") and the
    **progress bar**, one `animated_image[]` of 64 fill and 32 full frames
    (`grug_jobs_progress_bar.png`, generated by `tools/r45_ui/gen_progress_bar.py`)
    that runs 1.5 × the job time and starts at the frame of the elapsed
    time on every build, so it is full at the end and stays full through a
    late resend. Recipes stay browsable while a job runs; a second job
    cannot start.
  - **Sends:** a click answers with one resend; a job sends the page at its
    start, its end (only while the player's current page is Crafting) and a
    cancel; a pure scrollbar event of the view sends nothing.
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
    Base items require their item level (1 / 11 / 21 / 31 / 41 / 51, the
    ladder of Round 45; T1 needs level 1); found items retain their own
    requirement. Common `Usable by`
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
  slots** extend it. Cloth and leather each have four named variants, at
  profession tiers T1 / T2 / T4 / T5: **8 / 16 / 24 / 32** slots (`bagslots` group; bag slots + contents are
  player-inventory lists, see above). Four huge bags therefore add 128
  slots. The parallel cloth/leather catalog is an explicit one-item-per-concept
  exception; neither material grants stats, affixes or extra capacity.
- Cloth bags are Tailor products and leather bags are Leatherworker products.
  The **small 8-slot cloth bag is the
  exception and stays vendor-sellable**: it is the floor tier of its
  item category (professions.md §4), so it is bought, not crafted-only.
- **The give order** (Round 44, spec `ui-crafting-rework-plan.md` §2.4):
  every item source — pickup, dug blocks, loot, boss loot, purchases, quest
  rewards and drops, fishing, harvests, refunds, equipment returns, station
  results, coin withdrawals — goes through `grug_inventory.give`: arrows to
  a Scout's quiver first, then partial stacks of the same item anywhere,
  then the empty slots of `main[9..]`, the bags in slot order and the
  hotbar last, so a hotbar slot freed for a skill stays free. A soulbound
  item (the Claim Stone) sits in `main` only. `grug_inventory.fits` answers
  the same question without changing anything; a source that refuses
  instead of dropping (purchases, the Claim Stone, station results) says
  the inventory is full only when the whole inventory is.
- **Bag rules** (Round 44, spec §2.3): a bag may sit inside another bag but
  never in its own content list (an unequipped bag is always empty: the
  contents belong to the slot). Swapping to an equal or larger bag keeps the
  contents. Taking a bag out (drag, drop or into another inventory) or
  swapping to a smaller one first fills the cells the smaller bag keeps,
  then moves the rest to `main[9..]`, the other bags and the hotbar, in the
  same server callback and before the list shrinks; when the rest does not
  fit (counted without the bag's own list and without the slot the bag
  lands in) the move is refused with one feed line. A bag moves between two
  bag slots only when both are empty.
- **Sort** (Round 44, spec §2.5): `main[9..]` and the bags as one sequence,
  the hotbar never: weapons (offhands included), trinkets, armour,
  consumables (arrows, food, potions), then the rest; inside a category the
  higher tier first (gear bracket, food tier, else the item level's tier),
  then the name, then the higher quality. Stacks merge only when name, wear
  and metadata are identical; free slots end up contiguous at the end; a
  soulbound item stays in `main`.
- **The potion belt** (`grug_potion_belt`, 4 slots, Round 44): potions and
  elixirs only (group `grug_potion`), created for every player; filled here
  and drunk from the quickbar (below).
- **The quiver is a Scout-only slot** (Round 28 ruling 26), drawn under the
  equipment slots in the Character page's gear box with the arrow total
  beside it. There is
  no quiver item and no Leatherworker quiver recipe; non-Scouts have no quiver
  slot. It holds up to **500 arrows**; arrows stack to **100** in any
  inventory. Internally the list `grug_quiver_content` carries five stacks of
  100, but only its first cell is drawn and it always holds min(total, 100):
  **clicking the slot takes up to 100 arrows as one stack**. Above 100 arrows
  the cell shows the true total (e.g. 181) over the engine's count (Round 41
  ruling 6); its count corner matches the slot background only approximately
  and shows no hover highlight (accepted). Arrows enter by
  **drag** (onto the slot), **shift-click** (from the inventory) and **pickup**
  while the quiver has room; anything else is refused. A shift-click on the
  slot moves its up to 100 arrows into the inventory in the give order,
  never back into the quiver. Shots draw from the
  quiver first, then `main` and the bags; a talent refund returns to the
  quiver first. A
  drag of part of a stack onto the slot while it shows a full 100 moves the
  whole stack in (the engine treats that drop as a whole-stack swap).
  No item drop on death, so the quiver keeps its arrows like the equipped
  items do.
- No item drop or XP loss on death (Round 18).

## 4. Crafting model (Round 45)

- **Recipe lists, no grid** ([professions.md](professions.md) §1.2,
  [UI rework spec](../planning/ui-crafting-rework-plan.md) §2.16–2.36): every
  craft is an ingredient-list recipe of one area. **Basic** is the area for
  profession-free recipes (tools, blocks, planks, torches, dyes, bolts,
  leather grades, graded wood, arrows, …); gear (weapons, armour, offhands,
  trinkets) and bags are recipes of their profession. Basic shows all its
  recipes; a profession area shows its recipes up to the player's profession
  tier (capped by the level band; the user, 2026-10-09, playtest fix PT3).
  The player's engine `craft`
  list has size 0 (a join shrinks it while it is empty).
- **Crafting jobs and the output area** ([professions.md](professions.md)
  §1.2): ingredients leave the bags first, then `main[9..]`, the hotbar last
  (stacks without metadata only); finished stacks land in the output area
  `grug_craft_out`, four take-only slots created for every player at join
  (nothing is put, moved or swapped into it). Take all and a cancel's refund
  go through the give helper.
- Professional components such as settings are never Basic inputs.
- Named enchant application and replacement need the owning profession's
  station nearby. Weaponsmith and Armorsmith share one Forge; Leatherworker
  uses the Tanning Rack, Tailor the Tailor Bench and Woodcarver the Carving
  Bench. Since Round 45 they are jobs on the one stack in the target slot
  (§1, "The enchant and upgrade boxes"): the item stays in the job until the
  result reaches the output area, and its other metadata and wear are
  kept. An enchanted weapon, offhand or armour piece shows its
  prefix and suffix colours (character_visuals.md §5a) on its own inventory
  image, which also draws it in hand and when dropped and is rebuilt whenever
  its affixes change; a plain stack carries no image of its own.
- **Stations:** a profession recipe needs its station within 4 nodes when its
  job starts (`professions.md` §1.5). Only **furnaces and dual furnaces** keep
  a dialog with lists. The forge, the four benches and the brewing stand are
  proximity stations without a dialog, lists or a right-click action (Round
  45); inside an active Claim Stone claim the repair button sits in a
  player-placed furnace's or dual furnace's dialog
  ([durability_repair.md](durability_repair.md)).
- Authored capital/POI furnaces and dual furnaces are personal workspaces
  keyed by player and physical station: durable inputs, outputs, fuel and
  processing state per player. Player-placed ones share node inventories;
  inside an active Claim Stone claim, access follows the claim's permission
  list (`housing.md` §6), with no station-specific owner or ACL; outside
  protected areas they have no individual owner. The station UI shows its mode
  with a short explanation. Authored loot chests are outside this model.
  Closing a UI loses no contents.
- Player-placed furnaces, dual furnaces, brewing stands and profession
  stations can be dug at any time by anyone the normal protection allows
  (Round 28 ruling 18): in the open world there is no extra rule, inside a
  claim the claim's rights apply and in foreign home territory the territory
  rule applies. Digging drops every node list **and** every player's saved
  workspace record together with the station itself (to the digger's
  inventory, overflow on the ground), exactly what an explosion releases —
  also the old contents of a bench or brewing stand from before Round 45.
  A station is never undiggable because it still holds items, including
  other players' invisible leftovers. Authored public stations stay
  undiggable and blast-immune.
- Personal processing state, fuel, inputs and outputs persist in the physical
  node. Elapsed server game time may catch up lazily after unload/restart but
  does not promise work during shutdown. Automatic furnace and dual-furnace
  completion is universal and gives no profession progress.
- Learned profession and T1–T6 profession level gate professional recipes and
  operations. Basic recipes have neither gate and award no profession
  progress.
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
- **Character page modes** (Round 44: a mode box beside the gear box, see
  §1): "Stats" (the model; pools, armor, damage reduction, crit, dodge, the
  Claim Stone status and the cloak picker beside it; the **Return home** button with its
  cooldown in whole minutes sits in the gear box in every mode, re-sent when
  the text changes, [home_travel.md](home_travel.md)),
  "Effects": icon,
  name, remaining time and a detail line per status in one column (seven
  rows and "... and N more" when there are more than eight), refreshed about
  once a minute or on change while that mode is open. The professions
  overview (Round 28 ruling 23: per known profession, primary slots first,
  then Cooking and Alchemy, its tier, "Crafts: n/m toward tier N+1"
  (`professions.md` §1 counts; "Highest tier reached." at T6) and, while
  the character's ten-level band caps the tier, the note "Capped by your
  level: reach level 10N+1, then craft once more for tier N+1") was the
  fifth mode until Round 45 moved it into the Crafting tab's box (§1).
  Since Round 33 "Achievements" sits after Effects, and
  the **cloak picker** sits beside the model (the 3D mode since Round 44,
  the Stats mode since the Round 45 playtest, which merged the two;
  [character_visuals.md](character_visuals.md) §5b).
- **Class icons** (Warrior, Mage, Priest, Scout) appear in the party HUD
  list and in the Party & PvP tab's "Current party" table (`parties.md`).
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
  quest, every objective as "<name> n/m" joined by ", " ("Barley Piglet 3/10"),
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
  returned, and "Boss loot is waiting: free inventory space, then
  rejoin." (queued boss loot is handed over at the next join). Each
  notice group keeps one keyed line that a repeat refreshes (`potion`,
  `food`, `equip:<reason>`, `class_change:*`, `starter:<slot>`,
  `weapon_hint`, `mount`, `talents`, `boss_loot`, `combat:*`).
  Still in chat: death messages, rare sightings for the faction, the dragon
  arena's warnings, a boss's return warning and the one-time no-weapon hint
  (too long for the feed's 2.5 s).
- **Level-up** is a separate large centre announcement ("Reached level N!",
  double font size, 3 s), not a feed line. A level that earns talent points
  (every even level) adds a second line, "You gained +1 Talent Point", or
  "+N Talent Points" when one grant crosses several (Round 36 §2.14.4).
- **API** (`grug_core/feed.lua`): `grug_core.feed(player, kind, text, key)`
  (a line with the key of a shown line replaces it),
  `grug_core.feed_xp(player, amount)`, `grug_core.feed_item(player, item,
  count)` and `grug_core.banner(player, text, color)`. `grug_xp.add_xp`
  posts every positive grant itself; a caller that names the XP in its own
  line passes `quiet`.

## 6. The skill catalog and bound representations

Since Round 44 (`docs/planning/ui-crafting-rework-plan.md` rulings 8 and §3.4)
the skill catalog is one row under the talent trees on the **Talents &
Skills** tab (`skill_trees.md` §3.5), on the hotbar's columns in a
**Skills** box like the Hotbar box (Round 45 playtest), with the short
inventory right below so tools and food can leave the hotbar. It lists every
currently unlocked active ability, nothing else: mounts and boats left it
(they are in the quickbar). Its detached list is an infinite source and an
infinite destination: a drag onto a free hotbar slot copies the skill there
as a fresh stack, and dragging the carried copy back onto its own icon
removes that copy (the engine undoes the swap such a drop asks for). The
hint reads "Drag skills onto the hotbar. Drag one back here to remove it."

**Skills live on the hotbar only** (`main[1..8]`). Ability representations
carry `grug_ability` and `grug_bound_skill`; a move inside the inventory may
take a skill only onto a hotbar slot (a swap that would push one off the
hotbar is refused), and a put from the catalog lands only on a hotbar slot
and only while the player carries no other copy in `main`, `craft` or an
owned bag. Bags, `main[9..]`, the potion belt, crafting, equipment and the
quiver refuse skills. A grant goes onto a free hotbar slot or, with a full
hotbar, waits in the catalog, never into `main[9..]` or a bag: the base kit
at character creation (in kit order) and after a class change (its kit slot,
else the first free one), and a talent unlock (`skill_trees.md` §3.4). A
stray skill from before Round 44 outside the hotbar may still be moved onto
the hotbar or back onto its icon; removing the others is the 0.44.0
migration step, not the login.

The retired mount items (`grug_bound_skill` without `grug_ability`; nothing
hands them out since Round 44, the quickbar below replaces them) keep `main`
and the owned bag contents until the 0.44.0 migration step removes them. All node
metadata inventories and other detached inventories refuse bound stacks.
Source takes remain allowed so Q/drop reaches the item's deletion-only
callback. Entitlement, cooldowns, charge, resources and active mounts are
independent of the disposable item stack.

## The quickbar (E, Round 44)

Spec `docs/planning/ui-crafting-rework-plan.md` ruling 9 and §3.5
(`grug_quickbar`). The rising edge of aux1 (E by default; `grug_keys`) opens
a small window on the left of the screen, four inventory-sized slots wide
(5.5 × about 6.5 units):

- **Mounts and boats:** one image button per purchased tier (every owned
  riding tier and boat, four to a row, the model's icon, a tooltip with the
  model, tier and speed); the tier being ridden is framed green and its
  button dismounts. Without any: "No mounts or boats yet." The buttons call
  the mount's own summon path with its gates (`mounts.md` §3).
- **Potion belt:** the four belt slots; a filled one is an item button (the
  count in the item string; a list slot would pick the stack up), an empty
  one draws only the slot. A click uses the potion through its own `on_use`,
  so the shared 60 s potion cooldown, the full-health and level refusals
  hold; the stack shrinks in the belt.
- **Return home:** with a home, "Home: <name>" and the button "Return home
  (<state>)" with the Character tab's state text; the same travel request
  and its gates (combat, the cooldown, a running return).
- A click acts once and closes the window. It is sent once per opening and
  never refreshed; it does not open while dead or during character
  creation. The client releases every key while a menu or the chat is open,
  so E cannot open it over another window. Help names the limits: a rebound
  aux1 key, "Aux1 key for climbing/descending" sinks in water and climbs
  down ladders while E is held, and "Toggle Aux1 key" opens the quickbar on
  every second press.

## Round 14 navigation pages

The inventory gains separate Quests, Party and Map tabs, following `quests.md`,
`parties.md` and `world_map.md`. Quests and Party each own a saved HUD toggle,
default on; empty quest logs and players without a party have no
corresponding HUD.
Since Round 27 the Map tab likewise owns the saved "Show minimap" switch for
our own minimap, default on (`world_map.md`). Since Round 44 the quest log
and that switch live in the map window (Z or the Map tab); the Quests tab
is gone. Since Round 31 a PvP tab
(since Round 44 the PvP section of the Party & PvP tab, `grug_pvp/page.lua`) holds the "Flag me for PvP"
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
and not part of the status row (§5).

## Round 18 interaction clarity

Weapon-slot tooltips and contextual raw-weapon hints explain that equipped
weapons provide combat stats while hotbar skills execute attacks. No automatic
equipping or hotbar-weapon combat fallback. The top inventory row is explicitly
highlighted as Hotbar. Selected page controls use a visible border/tint rather
than a `>` prefix. The skill catalog explains placing and removing skills
(§6).
