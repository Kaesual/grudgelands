# Round 44 — UI rework: the window, the inventory and the map

Coordinator: Claude (Opus 5.5), drafted 2026-10-08. This round builds
**Round A** of the [UI and crafting rework plan](ui-crafting-rework-plan.md)
("the spec" below; its §2 rulings and §3 are this round's design). Layout:
wireframe v1 (<https://claude.ai/artifact/8XM4hJggJyJSpuigRyg9jJ>), accepted
by the user. Crafting stays as it is until Round 45 (Round B of the spec).
Status: **draft**. Wave 1 starts **in parallel with Round 43** after Round
42 is complete; nothing of this round merges to main before 0.43.0 is
complete and pushed (§7).

Routing default (agent model policy; the user decides per session): Claude
coordinates, Opus implements and reviews; GPT-6 Astra paints the art
(lane AR) with the user's picks on a review page.

## 1. Lanes and waves

| Lane | What | Wave | Kind | Waits for |
|---|---|---|---|---|
| IH | Inventory logic: the give helper and its call sites, bag rules (bags in bags, swaps, redistribution), the sort, the potion belt list, ammo from all lists | 1 | code | Round 42 complete |
| FR | Window frame: fixed tab order, the new frame, the full and short inventory views, the Inventory tab | 1 | code | Round 42 complete |
| AR | Art: profession trainer icons, baked boss/dungeon/settlement icons (world map and minimap sizes), the pixel font, crosshair and ring; review page with the user's picks | 1 | art | Round 42 complete |
| MB | Map base: baked icons and pixel-font region names in the world-map variant, the minimap variant, the cache key; minimap markers | 1 | code | Round 42 complete (placeholder art until AR) |
| CH | Character tab: the four-mode box, the gear box with the arrow slot, the short inventory | 2 | code | FR, IH |
| TS | Talents & Skills tab: the tree framework, the skill catalog row, hotbar-only skills, the grant path; mounts leave the page | 2 | code | FR |
| MQ | Map and quest window: Z key and Map tab, screen-sized window, overlay rules, quest boxes, quest targets (crosshair, circles), refresh rules | 2 | code | MB, AR picks |
| PP | Party & PvP page and the Help texts | 2 | code | FR |
| QB | Quickbar on E: mounts, boats and the potion belt; mount items retired; riding trainer tip | 3 | code | IH, TS, MQ (key helper) |
| MS | Migration step 0.44.0: mount items and skills outside the hotbar removed offline | 3 | code + test | Round 43 merged, QB, TS |
| D | Documentation, version 0.44.0, the declaration's first `migrate` entry | 4 | docs | last merge |

Estimates (unmeasured, for planning only): IH 8–10 h, FR 8–12 h, AR 4–6 h
plus picks, MB 6–8 h, CH 4–6 h, TS 6–8 h, MQ 10–14 h, PP 2–3 h, QB 4–6 h,
MS 3–4 h, D 2–3 h, each code lane plus its review. FR and MQ are the large
lanes.

## 2. Rulings

The design rulings are the spec's §2 (items 1–15 for this round) and its
§3; the user's later decisions are folded in there (sort order, map symbol
sizes, Party & PvP page). Round-specific (the user, 2026-10-08):

1. **Order of rounds:** 43 migration foundation, 44 this round, 45 crafting.
2. **Crafting stays as today** in this round: the Crafting tab keeps its
   grid and books inside the new frame; the professions overview stays as a
   fifth mode in the Character tab until Round 45 (spec §3.3).
3. **First real migration:** the removal of mount items and of skills
   outside the hotbar is this release's `migrate` step (0.44.0), through the
   Round 43 tool. The platform adopts a version with a real step only once
   its runner is in production (contract, revision 2); 0.44.0 may therefore
   wait on the platform side. That is expected.
4. **Defaults of the wireframe stand:** short inventory = hotbar + 2 rows;
   the skill catalog as one row under the tree; tabs at today's window size;
   the map window at 80–90 % of the screen.
5. **Enemy settlements on the map:** baked settlement icons are the same for
   everyone, the other faction's start towns, capitals, villages, outposts
   and fortresses included. This supersedes the Round 31 ruling that hid
   them; MB rewrites the rule where it lives (`world_map.md`,
   `settlement_icons.lua`).

## 3. Shared conventions (coordinator defaults; lanes may refine them in their report)

- **Tab order** is one table in `grug_inventory`: Inventory, Character,
  Talents & Skills, Crafting, Party & PvP, Help, Map. `i` opens Inventory.
  The ordering hooks in the other mods go (FR removes them, each page lane
  only registers its page).
- **Inventory views** (FR): `grug_inventory.inventory_view(player, mode,
  context)` returns the formspec part for `"full"` or `"short"` (hotbar + 2
  scrollable rows) and owns the scrollbar echo; pages call it and never draw
  `main` themselves. Page handlers never resend on a pure scrollbar event.
- **Give helper** (IH): `grug_inventory.give(player, stack)` → leftover;
  order `main[9..]`, the bags in slot order, the hotbar last; arrows to the
  quiver first; the weapon-tooltip setup on pickup. Every item source uses
  it (spec §3.2).
- **Lists:** `grug_potion_belt` (4, potions and elixirs only; IH);
  `main` stays 32 (hotbar 8 + 24); bag contents `grug_bag<i>_content`.
- **Sort** (IH): `grug_inventory.sort(player)` → changed; the button and its
  2–3 s server-side cooldown are FR's.
- **Key edges** (MQ writes it, QB uses it): one globalstep helper in a new
  small mod (`grug_keys`, not `grug_core`, which Round 43 edits in parallel)
  that reports the rising edge of `zoom` and `aux1` per player.
- **Markers and icons:** AR delivers textures under the names MB and MQ
  use; until AR's picks merge, MB and MQ use clearly marked placeholders.

## 4. Lanes (goals; the briefs add file facts)

Every lane classifies its change (compatible, map reset, migrate, new
server) and updates the design docs whose rules it changes
(`inventory_equipment.md`, `world_map.md`, `quests.md`, `skill_trees.md`,
`mounts.md`, `parties.md`, `pvp.md` as touched).

### 4.1 Wave 1 — IH, inventory logic

- The give helper (§3) and all its call sites: the 30 direct
  `add_item("main", …)` calls in 15 files, `core.handle_node_drops` for
  digging (overridden), equipment returns, the quest reward helper; item
  pickup. Inventory-full messages only when the whole inventory is full.
- Bag rules (spec §2.3): bags inside bags allowed, never into their own list;
  swap to an equal or larger bag keeps the contents; taking a bag out (drag
  or drop out of the window) and swapping to a smaller one redistribute the
  contents (`main[9..]`, other bags, hotbar last) or refuse; counted in free
  slots, without the bag's own list and without the slot the bag lands in;
  the redistribution runs before the list is resized, in one callback.
- The sort (spec §2.5, §3.2): weapons (offhands included), trinkets, armour,
  consumables (arrows, food, potions), then the rest; tier, name, quality
  inside a category; identical stacks merge; occupied slots first; the hotbar
  is never sorted.
- Readers that assume `main` follow all lists, first of all ammo
  (`usable_ammo_lists`); the lane lists every other main-only reader it found
  and what it did.
- Fixtures for the helper order, bag swaps and removals (fit and refusal),
  the sort order and merging.

### 4.2 Wave 1 — FR, the window frame

- The frame at `formspec_version` 6 with real coordinates, the fixed tab
  order (§3), the inventory views (§3) with the scrollbar echo.
- The **Inventory tab** as in the wireframe: four bag slots, the potion belt,
  the coin deposit, Sort (cooldown 2–3 s, no resend), one continuous 8-wide
  scroll area (24 `main` slots, then each bag's list), the hotbar below.
  Shift-click rings only where spec §3.2 says.
- The old Bags tab goes (its 8×3 display bug with it); the Crafting page
  keeps working inside the new frame (it may stay in legacy coordinates
  until Round 45).
- Measured: the Inventory tab's formspec bytes with four 32-slot bags, before
  (Bags tab) and after.

### 4.3 Wave 1 — AR, art

Pixel art, matching the game's existing icons:

- profession trainer icons: weaponsmith, armorsmith, tailor, leatherworker,
  woodcarver, goldsmith, alchemist (riding keeps the mount icons);
- baked icons for bosses, dungeons/POIs and settlements, each in a world-map
  size (about the overlay icons at zoom 1×) and a minimap size;
- a pixel font for region names (uppercase, digits and the punctuation the
  zone names use; the lane measures the character set from the data);
- the red crosshair and a white ring (tinted in code).

A review page with variants; the user picks. MB and MQ swap their
placeholders for the picks.

### 4.4 Wave 1 — MB, map base

- The renderer draws the baked icons and the pixel-font region names into
  the world-map variant and the icons alone into the minimap variant; both
  cached, the cache key covering art, font and layout versions (spec §3.6).
- **All settlements are baked, the other faction's included** (ruling 5):
  the per-viewer hiding of `grug_map/settlement_icons.lua` (Round 31) ends
  for the map image; NPC overlays (trainers, quest givers) stay own-faction
  only.
- The region-name `hypertext` elements and the dynamic markers of baked kinds
  leave the map page's providers; the minimap's dynamic markers are trainers
  (new icons), quest givers ! and ?, home, waypoints and party (spec §3.7).
- Render time and texture sizes reported before and after (both quality
  settings).

### 4.5 Wave 2 — CH, the Character tab

The four-mode box (3D with the cloak dropdown, Stats, Effects,
Achievements; the professions overview as a fifth mode until Round 45), the
gear box (eight slots and the Scout's arrow slot, class hand labels), the
short inventory; shift-click inventory ↔ equipment. The Return-home line
and its button stay on the Character tab (Round 30 ruling,
`pages.lua:224-238`); the coin deposit moves to the Inventory tab (FR).
Measured formspec bytes before and after.

### 4.6 Wave 2 — TS, Talents & Skills

- The tree framework (spec §3.4): nodes with section, row, column and
  prerequisites; connectors as boxes under the nodes; several parents and
  children per node supported; today's trees render as two sections of
  linear chains. A fixture renders a small real tree with a branch.
- The skill catalog as one row under the tree, the short inventory below.
- Hotbar-only skills: moves to `main[9..]` or a bag are refused; back to the
  catalog removes; a grant goes to a free hotbar slot or only into the
  catalog.
- Mounts and boats leave the Skills page.

### 4.7 Wave 2 — MQ, map and quest window

- Opened by Z (the key helper, §3) and by the Map tab; sized to 80–90 % of
  `max_formspec_size` with a fixed fallback. The minimap on/off switch
  (today on the Map tab, player meta) moves into the map window.
- The overlay (spec §2.12): own player and party arrows, home, discovered
  waypoints, own-faction trainers (about 2/3 size at zoom 1×/2×), question
  marks for active quests only (silver, gold) with the NPC name as tooltip;
  nothing on the other faction's side beyond the baked layer.
- The quest boxes move here from the Quests tab, which goes (spec §2.14):
  list, Quest HUD, Track on HUD, Abandon with confirm, quest text.
- Quest targets: the role → regions index built once at start; leader
  crosshairs first, then up to five circles for the nearest spawn regions;
  talk NPCs and use places marked.
- Refresh (spec §3.6): event-driven, at most one send per second with a
  trailing send; in a party at most every 5 s and only when a member moved;
  nothing periodic when alone.
- Measured: the map formspec's bytes at zoom 1× and 8× against today's
  ~75 KB, and the sends per minute alone and in a party.

### 4.8 Wave 2 — PP, Party & PvP and Help

One page, no inventory: the party section keeps today's features (online
players of the own faction, pending invites, the member list while in a
party), the small PvP section below. Every player-facing text that names
an old tab or key is rewritten: Help, the welcome window
(`grug_inventory/welcome.lua`, "Skills tab", "Party tab"), trainer and NPC
lines; Help names E and Z and the aux1 notes (spec §3.5).

### 4.9 Wave 3 — QB, the quickbar

- E's rising edge opens the quickbar: roughly square, inventory-sized slots,
  owned mounts and boats on top (summon/dismount with the existing gates),
  the potion belt below as item buttons (drink, shared cooldown); a click
  acts and closes.
- Mount items are no longer handed out or registered for use; ownership stays
  in player meta (`grug_mounts/state.lua`). The riding trainer and the
  shipwright tell the player "Press E for your mounts".

### 4.10 Wave 3 — MS, the migration step

The first real step under `tools/migrate/steps/` (Round 43's layout): for
every character, remove mount items from every list and bound skills from
every list but `main[1..8]`. Offline only, no online work. Its test (the
Round 43 harness): a 0.43 world with such items, the step, a headless boot,
the checks. The declaration gains `"migrate": ["0.44.0"]` (lane D) and the
game's `grug_core.migrations` list the same entry.

### 4.11 Wave 4 — D, documentation

The plan's completion with the GUI checklist; STATUS, the AGENTS pointer,
ROADMAP, BACKLOG, README, CHANGELOG (0.44.0), `game.conf`, the declaration
(version 0.44.0, `migrate` 0.44.0); the spec's status line for Round A.

## 5. Rules

- Stock clients only; plain Lua 5.1; the web build is a target: every page
  is checked at the web build's window size.
- Formspec bytes and sends are reported before and after for the Inventory,
  Character and map pages; performance numbers are comparisons, never
  targets. A page that grows clearly beyond today's comparable page stops and
  reports.
- No per-tick inventory writes; the key helper reads controls once per step
  per player and does nothing else.
- Release mode: classification per lane. Expected: MS **migrate**, everything
  else compatible (new lists, new map cache key, no removed saved state
  besides MS's).
- No world-generation change: no seed fleet. The map renderer change only
  re-renders the cached map image.

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates).

GUI checklist (desktop and web):

- `i` opens Inventory; the tab order; every tab at today's size.
- Inventory: four bags of mixed sizes shown as one grid, scrolling keeps its
  place after equipping and sorting; Sort (order, merging, hotbar untouched,
  the cooldown); swap a bag for a larger and a smaller one; take a full bag
  out with and without room; a bag inside a bag; the potion belt.
- Pickups, loot, quest rewards and dug blocks fill `main[9..]` and the bags
  before the hotbar; a Scout shoots arrows from a bag.
- Character: the four modes, the cloak, equipping by drag and shift-click,
  the arrow slot.
- Talents & Skills: the tree, the catalog row, a skill refused outside the
  hotbar, returned to the catalog.
- Quickbar: E opens it, a mount summons, a potion drinks, the window closes;
  no mount items anywhere.
- Map: Z and the Map tab; baked icons and names at all zoom levels;
  trainers of the own faction; question marks with names; a kill quest shows
  circles, a leader quest the crosshair; the minimap shows ! and ? and the
  trainers.
- Party & PvP: invites, the member list, the PvP button.
- An old world (0.43) migrated with the tool, then boots: mount items and
  stray skills are gone, owned mounts are in the quickbar.

## 7. Orchestration notes

- Start state: main after Round 42's lane D; wave 1 runs in parallel with
  Round 43 in its own worktrees (the user, 2026-10-08).
- **Merge rule:** nothing of this round merges to main before Round 43's
  lane D has merged and the user has pushed 0.43.0. Lanes that finish
  earlier wait reviewed; each merges main (with Round 43) into its branch
  and reruns its gates before the merge. MS starts only after Round 43 has
  merged (it needs the tool and the step registry). Lane D of this round
  runs after Round 43's lane D (shared status files).
- Process budget: at most 8 Lua processes at once; engine runs only through
  `tools/luanti_headless.sh`.
- Files per lane (the briefs list exact files):
  - IH: `grug_inventory/bags.lua`, a new helper module, the 15 call-site
    files, `grug_quests/state.lua` (reward helper), ammo readers.
  - FR: `BASE/sfinv/` (patch markers), `grug_inventory/ui.lua`,
    `pages.lua` (frame, Inventory tab), the ordering hooks in
    `talents_ui.lua`, `grug_skills/page.lua`, `grug_quests/ui.lua`,
    `grug_parties/ui.lua`, `grug_pvp/page.lua`, `grug_map/page.lua` (hook
    lines only).
  - CH: `grug_inventory/pages.lua` (Character), `equipment.lua` (labels only).
  - TS: `grug_classes/talents_ui.lua`, `grug_skills/`, `grug_abilities`
    (grant path, `normalize_kit`).
  - MB: `grug_map/base.lua`, `minimap.lua`, `minimap_view.lua`,
    `providers.lua` (kinds).
  - MQ: `grug_map/page.lua`, `atlas.lua`, a new window module,
    `grug_quests/ui.lua` (moved), the new `grug_keys` mod.
  - PP: `grug_parties/ui.lua`, `grug_pvp/page.lua`, `grug_inventory/help.lua`,
    `welcome.lua`.
  - QB: `grug_mounts/`, a quickbar module, `grug_alchemy`/trader potion use.
  - MS: `tools/migrate/steps/`, its test, `grug_core.migrations`.
- Merge order: IH, FR, AR, MB, then CH, TS, PP, MQ, then QB, MS, then D.
  Lanes that start after a shared file changed merge main before their
  review. FR touches the ordering hooks of other mods' pages; the wave-2
  page lanes start from FR's result.
- Decided during the round: AR's picks (the user), the exact sort categories
  of edge items (IH reports), placeholder swaps.

## 8. Open questions for the user

- Routing: Astra for lane AR with a pick page, as in earlier art lanes?
- None else blocking.
