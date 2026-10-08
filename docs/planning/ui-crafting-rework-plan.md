# UI rework and crafting rework — design plan (Rounds A and B)

Status: **specification complete** (2026-10-08), written from the design
session with the user after the friends playtest of 2026-10-07, reviewed by
an independent Opus pass (findings verified and applied; edge cases decided by
the user). The layout wireframe v1
(<https://claude.ai/artifact/8XM4hJggJyJSpuigRyg9jJ>) was accepted by the
user as drawn. Next step: the round plans (`round<NN>-plan.md`) for the two
rounds, after the user's migration-framework specification.

Two rounds, cut by the user (2026-10-08):

- **Round A — window structure:** tabs, the one-inventory view with bags and
  sort, the Character tab, the talent tree framework, the quickbar (E), the
  map and quest window (Z), map icons and pixel-font region names.
- **Round B — crafting and professions:** the 3×3 grid and the recipe books go;
  recipe lists per area, timed crafting jobs with an output area, profession
  stations nearby, gear made only by professions, the item level ladder
  1/11/21/…, item level upgrades by +1 per level.

Release mode: every change is classified per lane as usual. The user is
writing a separate specification for **per-version migration scripts** with a
shared helper framework (2026-10-08); it replaces "new server" as the answer
to saved state the new code cannot read. The migrations this plan needs are
listed in §6 and get mapped onto that framework once it lands. AGENTS.md
("Release mode": "No data migrations") still forbids them, so the framework
and the AGENTS.md change must land before these round plans are approved.

Guiding rule (the user, 2026-10-08): the world map works well today — do not
over-optimise. Measure formspec bytes before and after; performance numbers
are comparisons, not targets.

## 1. Code facts this plan builds on (main `43a0d5ea`)

Engine (`reference_projects/luanti`, 5.17-dev):

- **A changed inventory list is resent whole and uncompressed**
  (`src/inventory.cpp:535` `InventoryList::serialize`, the per-item
  "Keep" is a TODO; `src/server.cpp:1588` `SendInventory`). Unchanged lists
  are skipped. The hotbar is `main[1..8]`, so every hotbar change (wear,
  food, potions) resends all of `main`.
- **A formspec is one string, resent whole** (`TOCLIENT_SHOW_FORMSPEC`,
  `TOCLIENT_INVENTORY_FORMSPEC`, `server.cpp:1650`, `:2195`). No partial
  update, no stacked formspecs; `show_formspec` replaces the open one.
  Element order is draw order, so visual layers inside one formspec are free.
  Inventory contents travel in their own packets, never with the formspec.
- **Field values reach the server only with an event** (button, Enter in a
  field, checkbox, dropdown, table click, **and every scrollbar change**,
  including each mouse-wheel step over a `scroll_container`,
  `guiFormSpecMenu.cpp:5335-5338`); every event carries all fields.
  On a resend of the same form the client keeps table/textlist scroll and
  selection (`guiFormSpecMenu.cpp:3136-3143`) and focus, but **not** typed
  field text or `scroll_container` scrollbar positions — the server echoes
  those back (it receives them with every event). A page handler must **not**
  resend on a pure scrollbar event, or the scroll position fights the user
  (the map already does this, `grug_map/page.lua:70-73`).
- `animated_image[]` animates client-side with a frame duration in ms and a
  `frame_start`; it loops (`guiAnimatedImage.cpp:52`). Frames are stacked
  **vertically** in the texture (drawn like `vertical_frames`,
  `guiAnimatedImage.cpp:22-29`); one texture serves every duration.
- GUI images scale without filtering by default (`gui_scaling_filter =
  false`, `defaultsettings.cpp:301`): pixel art stays sharp when zoomed.
- `core.get_player_window_information(name)` (client 5.7+) reports the
  window size and `max_formspec_size`, the largest formspec before the
  client shrinks it — the basis for a map window sized to the screen.
- Node dialogs: workspace nodes open their dialog through `on_rightclick` +
  `show_formspec` (`grug_jobs/workspaces.lua:502`), not a `formspec` string
  in node meta; removing `on_rightclick` removes the dialog without touching
  the map. Workspace contents live in node meta (`workspaces.lua:41`).
- **Keys:** the server sees only `up/down/left/right/jump/aux1/sneak/dig/
  place/zoom` (`doc/lua_api.md:9249`). Mute (M) is client-only. The Q key
  reaches the server only with a wielded item, through that item's `on_drop`
  (`inventorymanager.cpp:697`; the client predicts the removal); dragging a
  stack out of any formspec list also drops it (`guiFormSpecMenu.cpp:5194`),
  so `on_drop`/allow-take apply to every list we draw. The game reads neither
  aux1 nor zoom today and sets no `zoom_fov`. The client releases all keys
  while any menu or the chat is open (`client/game.cpp:1376-1380`), so aux1
  and zoom cannot rise there.

Game:

- **Window:** vendored sfinv (GRUG PATCHes only for the suspend hooks,
  `BASE/sfinv/api.lua:124-180`); `grug_inventory` overrides
  `sfinv.make_formspec` with a legacy `size[10.4,11.1]` frame, the hotbar row
  and an 8×3 `main` view at the bottom of every page
  (`grug_inventory/ui.lua:3`, `:39-53`). Ten survival tabs: Character, Bags,
  Talents, Skills, Help, Crafting, Quests, Party, PvP, Map; the tail order
  depends on mod load order (`BACKLOG.md:744`).
- **Inventory:** `main` is the engine default 32 (hotbar 8 + 24). Bags are
  `grug_bag1..4` (one slot each) with `grug_bag<i>_content` lists sized
  8/16/24/32 (`bags.lua:9-69`); a bag can only leave an empty slot.
  Display bug: the Bags page draws 8×3, so 32-slot bags show 24
  (`pages.lua:581`). Item sources write to `main` only (30 direct
  `add_item("main", …)` calls in 15 game files, plus builtin
  `core.handle_node_drops` for digging, `builtin/game/item.lua:468`), except
  quest rewards (main, then bags; `grug_quests/state.lua:85-94`, `:595-602`).
  Arrows go to the quiver first (`bags.lua:290-300`); ammo is read from the
  quiver and `main` only (`bags.lua:220-225`).
- **Equipment:** eight one-slot lists (`equipment.lua:6-15`), the Scout's
  arrow slot `grug_quiver_content` (no quiver item, `bags.lua:72-73`), the
  coin deposit (detached, `grug_money/coins.lua:111`), the cloak dropdown
  (`grug_achievements/init.lua:269-282`).
- **Skills** are `grug_abilities:<id>` tool items, allowed in `main` and bag
  contents (`grug_skills/bound_items.lua:31-41`). Mounts are craftitems
  dragged from the Skills page to the hotbar. Potions are `on_use` items.
  The hotbar cooldown overlay is HUD (`grug_abilities/cooldown_hud.lua`),
  which draws under any formspec.
- **Map:** the base image is rendered per world at start, tiled, cached under
  a sha256 key and sent with `dynamic_add_media` (`grug_map/base.lua`); 1080×960
  normal, 3600×3200 high. Zoom 1/2/4/8 enlarges one image. About 230 markers,
  each an `image_button`/`button` with a `tooltip`; region names are
  `hypertext` with four halo copies; the form is ~75 KB
  (`docs/research/perf-review-2026-10.md:124-133`) and is rebuilt every 2 s
  while open when its signature changes. Marker visibility depends on the
  viewer's faction (`providers.lua:35`).
- **Minimap:** a custom round HUD minimap (~440 nodes, 24 marker slots + 9
  party slots — our own limit, not the engine's; `minimap.lua:51-71`).
- **Spawn regions** are computed once (~9.5 s) and cached in
  `<world>/grug_region_maps.txt`; per zone `regions {kind, belt, x, z
  (centroid), size, levels}`, `by_kind`, `camps`, `leaders`, `places`
  (`spawn_regions_cache.lua:117-135`, `spawn_regions.lua:359-457`). No
  index from mob role to regions exists. Underground, water, rare and ABM
  critter spawns are not in these maps.
- **Quests:** 540 quests; 360 kill (59 without `area`), 163 item, 94 talk,
  18 use objectives; no objective stores a position, all are derivable
  (talk → giver socket, use → `SR.place_spot`, kill → region map, leader →
  `SR.leader_pos`).
- **Crafting** (Round B): one framework, `grug_jobs` (~4.8 k lines) plus
  `grug_professions`, smelting, alchemy, cooking (~7 k lines core), enchant
  and upgrade logic in `grug_quality`. 648 engine routes (556 Basics grid),
  174 profession registry recipes, 624 station operations (588 enchants, 36
  upgrades). Grid crafts are instant; durations exist only on furnaces, dual
  furnaces and the brewing stand; the registry already has a `time` field.
  Weaponsmith and armorsmith make nothing but the forge today: all base gear
  is Basics (`base_recipes.lua:75-137`). Upgrade families per profession
  (`grug_professions/data/upgrades.json`): weaponsmith dagger/greataxe/sword,
  armorsmith metal armour/shield, leatherworker leather armour/bow, tailor
  cloth armour/spellbook, woodcarver caster weapons, goldsmith trinkets.
- **Item levels:** brackets have base item level 3/10/20/30/40/50
  (`grug_gear/init.lua:45-52`); equip requirement = item level capped at 60,
  except bracket 1 = level 1 (`:59-62`). A stack's `grug_ilvl` and
  `grug_req_level` meta override the definition
  (`grug_quality/init.lua:228-255`). Enchant tier = ceil(ilvl / 10), T7
  above 60 (`:110-114`) — so today a T2 base item (ilvl 10) counts as T1.
- **HUD feed** for XP and loot lines: `grug_core.feed` (`grug_core/feed.lua:128`).

## 2. Rulings (the user, 2026-10-08)

1. **Tabs:** Inventory (first, default, opened by `i`) · Character · Talents &
   Skills · Crafting (Round B content; Round A keeps today's crafting page) ·
   Party & PvP · Help · Map (opens the map window). The Bags, Quests and
   separate Skills tabs go. The tab order is fixed in one place, not by load
   order.
2. **One inventory, five lists.** The data model stays `main` + four bag
   content lists (a merged list would resend everything on every hotbar
   change, §1). The view draws them as one continuous 8-wide grid; bag sizes
   are multiples of 8, so no gaps.
3. **Bags** (the user, 2026-10-08, review round):
   - Bags may be stored inside bags (an unequipped bag is always empty; the
     rule "no bags inside bags" goes). A bag can never be moved into its own
     content list.
   - **Swap to an equal or larger bag:** always allowed; the contents stay
     (the content list is per slot and only grows).
   - **Take a bag out** (drag, or drop out of the window): allowed only when
     its contents fit into the remaining inventory — counted in free slots,
     without the bag's own list and without the slot the bag lands in.
     Then the contents move automatically, `main[9..]` first, then the other
     bags, the hotbar last; otherwise the action is refused.
   - **Swap to a smaller bag:** the same rule for the overflow (the items that
     do not fit into the smaller bag).
   - The redistribution runs before the content list is resized
     (`set_size` truncates), in one server callback.
4. **Every item source uses one shared helper:** `main[9..]`, then the bags,
   the hotbar last (so a slot freed for a skill stays free).
5. **Sort button:** type → tier → name → quality; identical stacks merge;
   occupied slots first, free slots contiguous at the end; the hotbar is not
   sorted. No lock (Lua runs the sort in one server step). A 2–3 s cooldown,
   enforced server-side by ignoring clicks — no countdown, no resend.
6. **Character tab:** top left a box with four modes (3D, Stats, Effects,
   Achievements); top right the gear box (eight slots, plus the arrow slot for
   Scouts); below a shortened, scrollable inventory. The cloak choice lives in
   the 3D mode. Professions leave the Character tab (Round B: into Crafting).
7. **Talent tree framework:** sections, nodes on rows and columns with
   prerequisites, connectors drawn as boxes (orthogonal: down, across, down).
   Today's trees render as two sections of linear chains. Content rework is
   a later round.
8. **Skills only on the hotbar.** A skill cannot leave `main[1..8]`; dragging
   it back to the catalog removes it. The Talents & Skills tab keeps the
   short inventory so tools and food can be moved off the hotbar. **Short
   inventory everywhere = the hotbar + 2 scrollable rows** (the prototype
   also shows 3 rows for comparison).
9. **Quickbar on E (aux1):** a small, roughly square window on the left with
   slots the size of the inventory's: the purchased mounts and boats on top,
   the four-slot **potion belt** below; a click uses the mount, boat or potion
   and closes the window. The belt is one list, filled in the Inventory tab and
   shown in both places; it accepts potions and elixirs only.
   The quickbar also carries the **Return home** button (it stays on the
   Character tab too; the user, 2026-10-08).
   **The quickbar is the only place for mounts:** no mount items on the
   hotbar, none on the Skills page; the riding trainer says so in a short tip.
10. **Map window on Z (zoom)** and from the Map tab; sized to about 80–90 % of
    the player's available width and height (`max_formspec_size`, §1). It may
    be the same window that grows when Map is chosen; all other tabs keep
    today's window size.
11. **Map base image:** bosses, dungeons/POIs and settlements are baked into
    the base image, plus the **region names in an English pixel font**. Two
    variants rendered at start and cached: the world map (names and icons) and
    the minimap (no names, icons at their own size). The cache key includes
    the art and font version.
12. **World map overlay** (dynamic): own player and party arrows, home,
    discovered waypoints, **own-faction trainers** with one stylised icon per
    profession (no tooltip; about 2/3 size at zoom 1× and 2×), and the NPCs of
    the player's **active quests only** as question marks (silver in progress,
    gold ready to turn in) with the NPC name as tooltip. No exclamation marks
    on the world map. Nothing on the other faction's side except the baked
    layer. **No search, no POI list, no legend, no filters.**
13. **Minimap:** the no-names base variant; dynamic HUD markers for
    trainers (new icons), quest givers (! and ?), home, waypoints, party.
14. **Quests in the map window:** right of the map, two boxes — the quest
    list (active count, Quest HUD checkbox, list, Track on HUD, Abandon with
    confirm) and the selected quest's text. Selecting a quest marks its targets
    on the map: a **red crosshair** for named targets (leaders) and up to **five
    semi-transparent coloured circles** for the nearest spawn regions of kill
    targets; the crosshair has priority over circles (a quest "kill 7 bandits
    and their leader" shows the crosshair first). The NPC of a talk objective
    and the place of a use objective are marked too (the user's original ask:
    "a circle around the target NPC or place"). Quests without a mapped
    target (gathering, ore, underground) show no marker; the text suffices.
15. **Trainer icons** per profession replace the book icon (art lane).
16. **Crafting areas** as tabs: Basic (default), Cooking, Primary 1, Primary 2,
    Alchemy. Basic and Cooking from the start; the two primaries and Alchemy
    start empty and are learned at the capital trainers as today.
17. **Recipe list:** 10 rows per page, "Page x of y", server-side search
    (≤ 1 per second), "Craftable only" checkbox, stable order tier → name.
    A row: output icon, name, craftable count "×N". No ingredient icons in
    the list.
18. **Crafting box** (middle): ingredients with icons and have/need, the
    maximum, a quantity field (stackable outputs only, default 1) with a
    **Max** button, the profession XP hint, station requirement, warnings.
19. **One job per player**, whole quantity as one job: ingredients consumed
    at start, the finished stack appears in the output area at the end.
    Stop/Cancel refunds everything not yet produced — which, with one job, is
    everything — and is **refused** when the inventory cannot hold the refund.
    A Stop that arrives after the end time completes the job instead of
    refunding it.
20. **Output area:** four take-only slots, shared by all crafts and enchants,
    plus the running job's status: progress bar, a green "Crafting…" /
    "Enchanting…" indicator, and the start button turned into **Stop**
    ("Craft now" → "Stop"; "Enchant now" → "Cancel"). Recipes can be
    browsed while a job runs; a second job cannot start. A **Take all**
    button moves the output area into the inventory through the give helper
    (shift-click reaches only one list, §3.2).
21. **Jobs are player-bound stations:** they run with the window closed and
    while offline (end timestamp); the state is restored on open and login. A
    HUD feed line ("Hearty Stew ×10 is ready") when the player is online.
22. **Profession XP per job** = min(items crafted, XP remaining in the tier),
    for recipes of the current tier; awarded at the end.
23. **Gear only from professions:** every weapon, armour piece, offhand and
    trinket is a profession recipe; everything else (tools, blocks, stairs,
    planks, torches, dyes, …) stays in Basic. The six primaries and today's
    family mapping stay; no new weapon types; the woodcarver keeps its name;
    no larger vendor shelf (drops suffice). Bags stay tailor/leatherworker
    items. Arrows are ammunition, not gear: they stay in Basic.
24. **Enchanting:** a target slot, an arrow, a preview of the result; the list
    filters to enchants valid for the placed item; 5 s duration; the item is
    taken in at start and returned on cancel; the result appears in the output
    area.
25. **Item level ladder:** bracket base item levels **1/11/21/31/41/51**, cap
    **10 × tier** (60 at T6); equip requirement = item level from level 1
    (capped at 60); the bracket-1 exception goes. The crown stays as it is.
    Trinkets have their own level table and bake "Item level N" into their
    definition description (`grug_gear/trinkets.lua:4`, `:62-68`); they move
    to the same ladder. Consumables (food `min_level`, alchemy tier levels)
    stay off the ladder. Regenerate `docs/design/item_tiers.md`
    (`tools/r33_ds`), the web-data export, and the fixture that asserts the
    bracket-1 exception (`tools/r33_c1/portable_test.lua:503`).
26. **Upgrades:** +1 item level per level, cheap, 1 s per level, with a "+N"
    quantity and Max up to the cap. **The cap is 10 × the item's own
    (material) tier** — a steel sword (T3) ends at 30 — and the upgrade
    needs the profession at that tier or higher (today's rule: the upgrade
    recipe's tier equals the item's material tier,
    `grug_quality/init.lua:704-715`). Target above the
    player's level: a permanent warning ("The target item level exceeds your
    level, you won't be able to use this item before you have reached level
    N.") and a yellow "Upgrade anyway" button; Max always fills to the cap
    and may produce the warning. The player's level never limits an upgrade
    (a level-22 crafter at profession T3 may raise a steel sword to 30). A
    higher profession tier never lifts an item past its own tier's cap: a T1
    smith cannot make or upgrade T2 items, and a T2 smith raises a T1 item
    to 10 at most.
27. **Stations:** profession recipes need their station within 4 nodes, checked
    only at start. Furnaces and dual furnaces stay for smelting and alloys.
    Cooking needs no station: simple dishes are crafted directly, good dishes
    are finished in a furnace (today's raw + finish split). Alchemy needs a
    brewing stand nearby and produces finished potions and elixirs directly;
    mixtures and automatic brewing go. **Only furnaces and dual furnaces
    keep a dialog;** the forge, the four benches and the brewing stand become
    proximity stations without a dialog and without inventories (their old
    contents are discarded, §6).
28. **Cooking without trainers:** every player knows cooking from the start
    (keeps its tiers); the cooking trainers become ordinary NPCs; quest cooks
    stay.
29. **Existing items keep what they are** where possible (§6): an existing
    ilvl-20 steel sword may exist; new crafts follow the new ladder.

## 3. Round A — window structure

### 3.1 Window frame

- Move the window to `formspec_version` ≥ 6 with real coordinates for the new
  pages (Map already uses its own header). Page sizes are set in the
  prototype; desktop and web are both targets.
- The tab order is one table owned by `grug_inventory`; the ordering hooks in
  `talents_ui`, `grug_skills`, `grug_quests`, `grug_parties`, `grug_pvp` go.
- Pages declare which inventory view they want: `full` (Inventory), `short`
  (Character, Talents & Skills, Crafting), `none` (Party & PvP, Help).

### 3.2 Inventory tab

- Top: four bag slots, the potion belt (4), the coin deposit, **Sort**.
- Main area: one `scroll_container` with the 24 non-hotbar `main` slots, then
  each equipped bag's content list, all 8 wide; at most 152 slots = 19 rows.
  Bottom: the hotbar row, outside the scroll area.
- The scrollbar value is echoed back on every resend (§1) so equipping or
  sorting does not jump to the top.
- Shift-click (`listring`) moves a stack only into the **one** next list of
  the ring, with no spill to further lists (`guiFormSpecMenu.cpp:4178-4193`).
  Inside the one-inventory view shift-click has no job; rings are defined
  only for the pairs that matter (inventory ↔ equipment on the Character
  tab, output area → inventory on Crafting), each targeting `main`. Where a
  spill into the bags is needed, the server routes the move itself in the
  inventory callback (the quiver pattern, `bags.lua:96`).
- Sort categories (the user, 2026-10-08): weapons (offhands included),
  trinkets, armour, consumables (arrows, food, potions), then the rest.
  Tier from `_grug_bracket` / item level;
  quality from `grug_quality`. Stacks merge only when name and metadata are
  identical.
- The shared give helper (`main[9..]`, bags in slot order, hotbar last,
  §2.4) replaces every
  direct `add_item("main", …)` (30 calls in 15 files: pickup, traders,
  bosses, fishing, farming, workspaces, housing, goldsmith, the faction kit,
  equipment returns `equipment.lua:750,848,910`, quests) and
  `core.handle_node_drops` for digging (overridden; builtin adds to `main`).
  It keeps "arrows go to the quiver first" and the weapon-tooltip setup on
  pickup (`grug_gear/init.lua:790-797`).
- Every reader that assumes items sit in `main` follows the five lists —
  first of all ammo (`usable_ammo_lists`, `bags.lua:220-225`), so sorted or
  overflowed arrows in a bag still shoot. The lane audits the other
  main-only readers.
- The Inventory and Character pages never resend on a pure scrollbar event
  (§1).

### 3.3 Character tab

- Left box with mode buttons 3D · Stats · Effects · Achievements. 3D carries
  the cloak dropdown.
- Right gear box: head, chest, legs, feet, main hand, offhand, two trinkets;
  the Scout's arrow slot. Class hand labels as today (`HAND_RULES`).
- Below: the short inventory (scrollable, same view as §3.2, fewer rows).
- Round A keeps the professions overview as a fifth mode until Round B moves
  it into Crafting.

### 3.4 Talents & Skills tab

- **Tree framework:** a node list `{id, section, row, col, requires = {…}}`;
  the renderer lays out sections side by side, draws nodes as image buttons
  and connectors as `box[]` segments (orthogonal, layered under the nodes).
  It must support several parents and children per node so later rounds
  can draw real trees; today's data maps to linear chains.
- **Skills:** the catalog as a single row under the tree, as its own sub-tab,
  or as a column right of the tree — the prototype shows all three; plus the
  short inventory (hotbar + 2 rows).
- **Hotbar-only rule:** `allow_player_inventory_action` refuses moving a
  bound skill to `main` index > 8 or to any bag; `normalize_kit` and
  `bound_items.lua` follow. Skills currently in bags or `main[9..]` are
  removed at login (they are re-granted from the catalog; today's
  `normalize_kit` already removes skills from other lists,
  `grug_abilities/init.lua:1995-2001`). Granting a skill
  (`grant_initial_kit`, `grug_abilities/init.lua:2036`, and talent unlocks)
  puts it on a free hotbar slot, else only into the catalog — never into
  `main[9..]`.
- Mounts leave the Skills page and the hotbar (they live in the quickbar
  only, §2.9, §3.5).

### 3.5 Quickbar (E)

- A globalstep watches `aux1` and opens the quickbar on its rising edge
  (Z / `zoom` the same way for the map window). No "menu open" check is
  needed: the client releases all keys while a menu or the chat is open
  (§1). Cheap: one control read per online player per step.
- Layout: roughly square, inventory-sized slots; purchased mounts and boats
  on top (one button each, summon/dismount, existing combat and indoor
  gates), the potion belt below; then close. The belt is drawn here as
  `item_image_button`s (count in the item string), not as the list — a
  `list[]` slot would pick the stack up instead of using it. A click drinks
  through the existing potion `on_use` and the shared potion cooldown.
- Mount items are no longer handed out; the purchase record stays the source
  of truth. The riding trainer's dialog gets the tip "Press E to open your
  mounts" (wording in the prototype).
- Known limits, written into Help: players who rebound aux1 see another key;
  players with "aux1 descends" sink in water and on ladders while pressing it.
- `grug_potion_belt` list (4 slots) with `allow_*` limited to the potion and
  elixir groups.

### 3.6 Map window (Z and the Map tab)

- A separate formspec (or the same window grown) at about 80–90 % of
  `max_formspec_size`, with a fixed fallback size for clients that do not
  report it. Left the map, right the quest boxes (§2.14).
- **Baked base:** the renderer draws boss, dungeon/POI and settlement icons
  and the region names (pixel font, a small glyph table in Lua) into the
  world-map variant; the minimap variant gets icons at their own size and no
  names. Sizes "roughly as today" (the user): a baked icon at zoom 1× is
  about the size of the overlay icons and grows with the zoom; the minimap
  keeps its own icon sizes, its baked icons again about the size of its
  other icons. The cache key covers art,
  font and layout versions.
- **Overlay** per §2.12, as plain `image[]` elements; only quest NPCs carry
  tooltips. Trainers per own faction; 2/3 size at zoom 1×/2×. The region-name
  `hypertext` elements go.
- **Quest targets:** a role → regions index built once at start from the
  cached region maps (`SR.zone_ids`, `get_area().roles`, `by_kind`).
  Selection draws the leader crosshair(s) first, then up to five circles for
  the regions nearest the player (ring texture scaled to the region size,
  tinted with `^[multiply`, semi-transparent). Talk and use objectives mark
  the NPC or place with the crosshair.
- **Refresh:** event-driven (click, zoom, pan, quest selection), throttled per
  player to one send per second with a trailing send; while in a party, at
  most every 5 s and only when a member moved. No periodic rebuild when alone.
- Measure the form's bytes at zoom 1× and 8× against today's ~75 KB.

### 3.7 Minimap and icons

- Base: the no-names variant. Marker kinds: trainer (per profession icon),
  quest giver ! and ?, home, waypoint, party. Nearest first; the 24 slots stay
  unless a capital proves too dense (32 is safe).
- **Art lane:** profession trainer icons (weaponsmith, armorsmith, tailor,
  leatherworker, woodcarver, goldsmith, alchemist; riding keeps the mount
  icons), baked boss / dungeon / settlement icons, the pixel font, the
  crosshair and circle textures, the progress-bar strip for Round B. All
  pixel art.

### 3.8 Party & PvP, Help

- Party and PvP become one page with two sections, no inventory (split as in
  wireframe v1). The party section keeps every feature of today's page: the
  online players of the own faction, pending invites, and the member list
  while in a party; the small PvP section sits below. The PvP 1 s check
  stays.
- Help texts that name Bags, Quests, Skills or "Inventory > Crafting" are
  rewritten.

## 4. Round B — crafting and professions

### 4.1 Recipe model

- One registry: `{id, output, count, ingredients = {{item|group, n}, …},
  area, profession, tier, time, station, progress}`. Shaped matching,
  `register_craft` adapters, the craft-predict and on-craft gates, the
  `craft` list and the book UI go. Furnace, dual furnace and alloy recipes
  stay where they are (stations with fuel).
- All ~620 grid routes become ingredient lists (generated from today's
  recipes where possible; stairs, slabs and other loop-made families stay
  loop-made).
- Gear recipes move from Basics to their profession (§2.23) by family:
  weaponsmith daggers/greataxes/swords, armorsmith metal armour and shields,
  leatherworker leather armour and bows, tailor cloth armour and spellbooks,
  woodcarver caster weapons, goldsmith trinkets.
- Every consumer of the engine craft API reads the registry instead: vendor
  prices (`grug_traders/prices.lua:201-213`), the economy load audit
  "output ≤ inputs" (`price_rules.lua`, `recipes_for`),
  `grug_materials/audit.lua:144`, `content_curation.lua:62-71`,
  `mobs/api.lua:922`.
- Jobs reproduce what the engine craft hooks do today, first of all the
  weapon-tooltip setup on crafted gear (`grug_gear/init.lua:784-788`,
  `register_on_craft`) and `grug_items.crafted_output`.

### 4.2 Crafting tab layout

- Top: area tabs. Each profession area shows its tier progress.
- Left: the paginated list (§2.17). The craftable count comes from one pass
  over hotbar, `main` and bags building `item → count` (and group counts);
  each recipe is then a few lookups. "Craftable only" uses the same table.
  The count uses the same rule as consumption (§4.4: stacks without metadata
  only), so "×N" never promises more than a job can take.
- Middle: the crafting box (§2.18). The XP hint: "Crafting this will give you
  a <profession> experience point" small and green; grey with "not" when the
  recipe tier is below the profession tier. Station missing: "Requires:
  <station> nearby", the button is disabled.
- Right: the output area (§2.20).

### 4.3 Quantity field behaviour

The server learns the typed number only with an event (§1). Rules:

- Enter in the field recalculates (maximum, warnings) and never starts a job.
- **Craft now** with a number above the maximum (ingredients or output space)
  lowers the field to the maximum, shows the note ("Not enough space in the
  output area — quantity reduced to N" / "…ingredients…"), and does not start;
  the player clicks again. With no output space at all: "No space in the
  output area". The same two-step covers the upgrade warning (§4.6): the
  server only knows the target level after the click.
- The server echoes the last known field value on every resend. Text typed but
  not yet sent can be lost when a resend arrives (job end); accepted.

### 4.4 Jobs

- State per player in player meta: recipe, quantity, consumed ingredients (for
  the refund), the enchant/upgrade target stack, start and end time
  (`os.time()`, so jobs survive restarts and logouts).
- Start: station check (radius 4, once), output space check (four slots,
  existing partial stacks of the same item count), consume ingredients —
  bags first, then `main[9..]`, the hotbar last; only stacks without metadata
  count as ingredients.
- Completion: a timer only for online players with a running job; on login
  and on opening the tab the state catches up. At completion: the result into
  the output area (several stacks when the quantity exceeds `stack_max`; the
  start check counts them), profession XP (§2.22), achievements, the HUD feed
  line.
- Cancel: refunds ingredients (and the target item) into the inventory;
  refused with "Not enough inventory space to cancel" when they do not fit.
- Output space cannot shrink during a job (take-only slots, one job), so the
  start check is sufficient.
- Formspec sends per job: start, end, cancel. The server cannot tell whether
  the inventory window is open (there is no open event); "open" means the
  player's current sfinv page is Crafting, and the end resend goes out then
  (`set_inventory_formspec` is cheap and harmless while closed).

### 4.5 Progress bar

- One bar texture stacked **vertically** (§1) with F fill frames plus F/2
  "full" frames as a lag buffer (the user, 2026-10-08): the animation lasts
  1.5 × the job time and the bar is full at 2/3 of it, so a late end resend
  (up to half the job time, 0.5 s for the shortest 1 s recipe) still shows a
  full bar instead of restarting. E.g. F = 64 → 96 frames; frame duration =
  1.5 × job time / 96 (integer ms).
- `frame_start` = the fill frame for the elapsed time (elapsed / job time ×
  F), computed on **every** render while a job runs (each page, search or
  quantity click rebuilds the element). The job end resends the form.

### 4.6 Enchanting and upgrades

- Enchanting per §2.24; the preview is `item_image` plus a `tooltip[]` with
  the computed description; validity rules (family, tier, channels, overwrite
  warning) as today in `grug_quality`.
- Upgrades per §2.26: cost per level = the family material of the tier plus a
  common ingredient (e.g. a stick and a bar for weapons); the cap is
  10 × the item's material tier and needs the profession at that tier
  (§2.26); the profession tier is already capped by character level. The
  crown stays a trader operation.

### 4.7 Stations, cooking, alchemy

- Station kinds: forge (weaponsmith, armorsmith), the four benches, the
  brewing stand (alchemy). Lookup: `find_nodes_in_area` over 9×9×9 once per
  start.
- Cooking: simple dishes as recipes; good dishes as raw recipe + furnace finish
  (as today). Cooking XP at the raw recipe as today.
- Alchemy: recipes produce finished potions and elixirs at the brewing stand;
  mixtures and the automatic brewing go.
- Cooking trainers (6 capital, 6 start town) become ordinary NPCs; check talk
  quests that point at them.
- Check the 163 item objectives (94 name `grug_materials` items, 6
  `grug_smelting`) for targets that become profession-only or disappear
  (mixtures).

## 5. Performance and traffic notes

- Inventory lists stay separate (§2.2); sort resends at most five lists once.
- The craftable count: one inventory pass (~190 slots) per page view or
  click; no polling.
- Crafting jobs: two or three formspec sends per job regardless of quantity.
- Map: ~230 interactive markers become ~30–45 plain images and a few tooltips;
  names baked; no rebuild when alone. Expect a large drop from 75 KB; measure.
- Quickbar: one control read per online player per step.
- Everything is measured as a comparison in the lane reports (user rule: no
  targets).

## 6. Migrations (for the migration framework)

- **Item level ladder (Round B):** base items read their level from the
  definition, so changing the bracket table moves unmodified items (T2 base 10
  → 11, T3 20 → 21, …). For every gear stack in player-held lists (equipment,
  `main`, bags, belt) the migration pins the **old** item level and
  requirement into `grug_ilvl` / `grug_req_level` meta, which already override
  the definition — no new game code, enchants stay valid (their strength uses
  min(ilvl, 10 × enchant tier)), upgrades continue from the pinned level.
  Pinning the old requirement keeps every equipped item wearable (it was met
  when equipped and levels never drop), so no separate lowering step is
  needed. The tooltip is rebuilt with the existing description code. Items
  in node storage follow the new definitions (accepted).
- **Crafting (Round B):** the player's own `craft` list (at most 9 stacks,
  possibly gear) is emptied into the inventory through the give helper
  **before** the item-level pin pass, then removed. The engine creates
  `craft` for every new player (`src/player.cpp:34`), so the game also sets
  its size to 0 on join; for existing players the removal sticks
  (`inventory.cpp:966-977`).
  Workspace contents in node meta (station grids, brewing stands, the
  per-player capital workspaces) are **discarded** (the user, 2026-10-08):
  once `on_rightclick` and the lists are gone no code reads them, so they stay
  as dead node meta until the next map reset — no world scan, no LBM. The
  dig and blast hooks of player-placed stations stay, so digging an old bench
  still hands out its contents (`workspaces.lua:509-519`; the user: keep
  it as a free refund). The
  per-player workspaces of capital **furnaces and dual furnaces** stay as
  they are (`workspaces.lua:257`, `:347`), since furnaces keep their dialog.
  Alchemy mixtures in player inventories are **deleted**, not refunded (the
  user, 2026-10-08).
- **Skills and mounts (Round A):** bound skills outside the hotbar and every
  mount item are removed at login; purchased mounts stay recorded.
- **Potion belt / quickbar (Round A):** new lists only; compatible.
- **Map cache (Round A):** a new cache key re-renders on first start;
  compatible.

## 7. Prototype outcome and what is left

The user accepted wireframe v1 as drawn (2026-10-08). Its defaults stand:
the short inventory is the hotbar + 2 rows; the skill catalog is a single row
under the talent tree; every tab keeps today's window size; the map window
uses 80–90 % of the screen; inventory slot sizes do not change.

Decided afterwards (the user, 2026-10-08): the sort order (§3.2), the map
symbol sizes "roughly as today" (§3.6), the Party & PvP page (§3.8),
mixtures deleted (§6). Fine-tuning of icon sizes happens at the GUI test.
