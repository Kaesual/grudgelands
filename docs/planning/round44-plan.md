# Round 44 — UI rework: the window, the inventory and the map

Coordinator: Claude (Opus 5.5), drafted 2026-10-08. This round builds
**Round A** of the [UI and crafting rework plan](ui-crafting-rework-plan.md)
("the spec" below; its §2 rulings and §3 are this round's design). Layout:
wireframe v1 (<https://claude.ai/artifact/8XM4hJggJyJSpuigRyg9jJ>), accepted
by the user. Crafting stays as it is until Round 45 (Round B of the spec).
Status: **complete** (2026-10-09, version 0.44.0, the first release with a
declared migration step; not pushed;
[completion](#completion-2026-10-09) with the GUI checklist). Wave 1 ran
**in parallel with Round 43**; nothing of this round merged to main before
0.43.0 was complete and pushed (§7).

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
- **Fit check** (IH): `grug_inventory.fits(player, stacks)` answers whether
  the stacks would fit (helper order, partial stacks counted) without
  changing anything; bag removal and Round 45's cancel refund use it.
- **Sort** (IH): `grug_inventory.sort(player)` → changed; the button and its
  2–3 s server-side cooldown are FR's.
- **Key edges** (MQ writes it, QB uses it): one globalstep helper in a new
  small mod, `grug_keys` (input belongs neither to the map nor to the
  quickbar), that reports the rising edge of `zoom` and `aux1` per player.
- **Markers and icons:** AR delivers textures under the names MB and MQ
  use; until AR's picks merge, MB and MQ use clearly marked placeholders.

## 4. Lanes (goals; the briefs add file facts)

Every lane classifies its change (compatible, map reset, migrate, new
server) and updates the design docs whose rules it changes
(`inventory_equipment.md`, `world_map.md`, `quests.md`, `skill_trees.md`,
`mounts.md`, `parties.md`, `pvp.md` as touched).

### 4.1 Wave 1 — IH, inventory logic

- The give helper (§3) and all its call sites: the 24 direct
  `add_item("main", …)` calls in 16 files (22 in 14 game files, plus
  `BASE/creative/init.lua` and `BASE/default/craftitems.lua`; measured with
  `grep -rnE "add_item\(\s*['\"]main['\"]" mods`), `core.handle_node_drops`
  for digging (overridden), equipment returns, the quest reward helper (a
  variable list name, `grug_quests/state.lua:600`), item pickup
  (`grug_gear/init.lua:790-796`, `register_on_item_pickup`). The brief lists
  the exact sites. Inventory-full messages only when the whole inventory is
  full.
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

The crafting progress bar (spec §3.7) is not part of this lane: Round 45
generates it in code.

A review page with variants; the user picks. MB and MQ swap their
placeholders for the picks.

### 4.4 Wave 1 — MB, map base

- The renderer draws the baked icons and the pixel-font region names into
  the world-map variant and the icons alone into the minimap variant; both
  cached, the cache key covering art, font and layout versions (spec §3.6).
- MB owns the map page's region names (`grug_map/page.lua:49-58`, the
  `REGION_LABELS` drawing at :200-220) and its settlement marker provider
  (`page.lua:97-125`), the boss provider (`providers.lua:88-99`) and
  `settlement_icons.lua`; MQ starts from MB's result.
- **All settlements are baked, the other faction's included** (ruling 5):
  the per-viewer hiding of `grug_map/settlement_icons.lua` (Round 31) ends
  for the map image; NPC overlays (trainers, quest givers) stay own-faction
  only.
- The region-name `hypertext` elements and the dynamic markers of baked kinds
  leave the map page; the minimap's dynamic markers are trainers
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
- The game sets the players' `zoom_fov` to 72° (the user, 2026-10-08), so Z
  no longer shows the client's "Zoom currently disabled" message
  (`client/game.cpp:1924-1929`); at the default field of view nothing zooms
  visibly.
- The overlay (spec §2.12): own player and party arrows, home, discovered
  waypoints, own-faction trainers (about 2/3 size at zoom 1×/2×), question
  marks for active quests only (silver, gold) with the NPC name as tooltip;
  nothing on the other faction's side beyond the baked layer.
- The quest boxes move here from the Quests tab, which goes (spec §2.14):
  list, Quest HUD, Track on HUD, Abandon with confirm, quest text.
- No exclamation marks on the world map; the minimap keeps ! and ?.
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
lines; Help names E and Z and the aux1 notes (spec §3.5), including that
players who set aux1 to toggle open the quickbar on every second press (the
user: a Help note, no special logic).

### 4.9 Wave 3 — QB, the quickbar

- E's rising edge opens the quickbar: roughly square, inventory-sized slots,
  owned mounts and boats on top (summon/dismount with the existing gates),
  the potion belt below as item buttons (drink, shared cooldown); a click
  acts and closes.
- The **Return home** button also sits in the quickbar (the user,
  2026-10-08), with the same cooldown and combat gates as on the Character
  tab, which keeps its own.
- Mount items are no longer handed out or registered for use; ownership stays
  in player meta (`grug_mounts/state.lua`). The riding trainer and the
  shipwright tell the player "Press E for your mounts".

### 4.10 Wave 3 — MS, the migration step

The first real step under `tools/migration/steps/` (Round 43's layout): for
every character, remove mount items from every list and bound skills from
every list but `main[1..8]`. Offline only, no online work. TS does not
extend the login cleanup (`normalize_kit`) to `main[9..]`: existing stray
skills are the step's job.

MS owns the version change, so its branch can run the real flow: it bumps
`game.conf` and the declaration's `version` to 0.44.0, adds `0.44.0` to the
declaration's `migrate` list and to `grug_core.migrations` together
(`check_upgrade.py` stays green on every commit). Its test builds the world
from the **0.43.0 commit** (a worktree; 0.44 code no longer hands out mount
items), then runs the step, boots headless and checks.

### 4.11 Wave 4 — D, documentation

The plan's completion with the GUI checklist; STATUS, the AGENTS pointer,
ROADMAP, BACKLOG, README, CHANGELOG (0.44.0; the version itself is MS's);
the spec's status line for Round A and its §6, which this round supersedes
in two points: the migrations are offline steps, not "removed at login",
and the spec's precondition "framework and AGENTS change before the plans
are approved" is replaced by the parallel run with the merge rule (§7).

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

- `i` opens Inventory; the tab order; every tab at today's size; the
  Crafting tab still works inside the new frame.
- A 0.43 world started without the tool is refused with the guard's message
  naming the step and the command line.
- Inventory: four bags of mixed sizes shown as one grid, scrolling keeps its
  place after equipping and sorting; Sort (order, merging, hotbar untouched,
  the cooldown); swap a bag for a larger and a smaller one; take a full bag
  out with and without room; a bag inside a bag; the potion belt (refuses
  anything but potions and elixirs).
- Pickups, loot, quest rewards and dug blocks fill `main[9..]` and the bags
  before the hotbar; a Scout shoots arrows from a bag.
- Character: the four modes, the cloak, equipping by drag and shift-click,
  the arrow slot.
- Talents & Skills: the tree, the catalog row, a skill refused outside the
  hotbar, returned to the catalog.
- Quickbar: E opens it, a mount summons, a potion drinks, Return home works,
  the window closes; no mount items anywhere.
- Map: Z and the Map tab; the minimap switch in the map window; the other
  faction's settlements baked; the quest boxes (Quest HUD, Track on HUD,
  Abandon with confirm); no refresh while alone and standing still; baked
  icons and names at all zoom levels;
  trainers of the own faction; question marks with names; a kill quest shows
  circles, a leader quest the crosshair; the minimap shows ! and ? and the
  trainers.
- Party & PvP: online players of the own faction, invites, the member
  list, the PvP button.
- Texts: Help and the welcome window name the new tabs, E and Z; the riding
  trainer and the shipwright give the "Press E" tip.
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
  - IH: `grug_inventory/bags.lua`, a new helper module loaded from
    `bags.lua` (FR owns `grug_inventory/init.lua`), the 16 call-site files,
    `grug_quests/state.lua` (reward helper), ammo readers.
  - FR: `BASE/sfinv/` (patch markers), `grug_inventory/ui.lua`, `init.lua`,
    `pages.lua` (frame, Inventory tab), the ordering hooks
    (`talents_ui.lua:348-363`, `grug_skills/page.lua:147-153`,
    `grug_quests/ui.lua:172-178`, `grug_parties/ui.lua:207-213`,
    `grug_pvp/page.lua:95-104`, `grug_inventory/pages.lua:626-636`; the map
    page has none).
  - CH: `grug_inventory/pages.lua` (Character), `equipment.lua` (labels and
    the shift-click routing as needed).
  - TS: `grug_classes/talents_ui.lua`, `grug_skills/`, `grug_abilities`
    (grant path, `normalize_kit`).
  - MB: `grug_map/base.lua`, `minimap.lua`, `minimap_view.lua`, `page.lua`
    (region names, settlement provider), `providers.lua` (bosses),
    `settlement_icons.lua`, `world_map.md`, the fixtures that assert the
    hiding (`tools/r31_m/portable_test.lua:228-235`,
    `tools/r32_f1/portable_test.lua:350-361`).
  - MQ: `grug_map/page.lua`, `atlas.lua`, `providers.lua` (quest givers →
    active quests only, ? with the NPC name; `:129-140`), a new window
    module, `grug_quests/ui.lua` (moved), the new `grug_keys` mod.
  - PP: `grug_parties/ui.lua`, `grug_pvp/page.lua`, `grug_inventory/help.lua`,
    `welcome.lua`.
  - QB: `grug_mounts/`, a quickbar module, `grug_alchemy`/trader potion use.
  - MS: `tools/migration/steps/`, its test, `grug_core.migrations`,
    `game.conf`, `tools/web_data/upgrade.json`.
- Merge order: IH, FR, AR, MB, then CH, TS, PP, MQ, then QB, MS, then D.
  Lanes that start after a shared file changed merge main before their
  review. FR touches the ordering hooks of other mods' pages; the wave-2
  page lanes start from FR's result.
- Decided during the round: AR's picks (the user), the exact sort categories
  of edge items (IH reports), placeholder swaps.

## 8. Open questions for the user

None. Answered 2026-10-08: Astra paints lane AR with a pick page, as in
earlier art lanes; Return home also in the quickbar (§4.9).

## Completion (2026-10-09)

Every lane of waves 1–3 is merged on main; lane MS (version 0.44.0 and the
step, `5b367ec7`) and this lane D (this section and the status owners, on
MS's branch) merge back to back. Main's first-parent line from 0.43.0
(`9dc2fad5`, origin/main): wave 1 through the integration branch `r44-w1`
(`93f1536f`), CH (`fe5cc31b`), TS (`999c490a`), PP (`f45a9bec`), MQ
(`c48eb681`), the coordinator's fixture-rule commits (`98d461c4`,
`5a8a065d`) and QB (`36019071`). **Push:** origin/main is `9dc2fad5`
(0.43.0, pushed on 2026-10-09 by the coordinator on the user's request);
**0.44.0 is not pushed**. It is the first release with a declared
migration step; the platform adopts such a version only once its runner is
in production (contract revision 2, ruling 3), so 0.44.0 may wait on the
platform side. Nothing of Round 45 is part of this release.

Reviews, each by an independent Opus, every fix made by the lane itself
before its merge:

- **IH** MERGE; the give order (partial stacks anywhere, then empty slots
  in `main[9..]`, the bags, the hotbar) confirmed by the user; two
  theoretical notes to the backlog.
- **FR** MERGE; one Low (images drawn over list cells now take the mouse
  hover under formspec_version 6: the quiver above 100 arrows, the ghost
  images) left for the GUI check, the comment corrected; the view's
  scrollbar options no longer leak into page scrollbars (`0f1792f0`).
- **AR** MERGE; no finding.
- **MB** MERGE; one Low (the art decoder ignored PNG colour keys), fixed
  (`461de63a`) with a decoder self-test, and `check_fresh_server.py` now
  runs the generator's staleness check.
- **CH** MERGE; two Lows (a stale comment, fixed; more traffic per quiver
  change, accepted); the review's backlog safety net applied: the hidden
  shift-click list is emptied at join (`e7f2adac`).
- **TS** MERGE; three Lows (the chain names gone, a locked node's text
  replaced by its reason, one feed line for two causes), fixed
  (`afb5d55d`).
- **PP** MERGE; merge notes only (the conflicts with TS, applied at the
  merge).
- **MQ** MERGE AFTER FIXES; three Lows (the window at 76 % without
  `padding[0,0]`, a send that crossed a close left a dead window, the
  0.5 s scroll pause gone), fixed (`cb6c7867`); the re-review MERGE AFTER
  FIXES with one Medium (that fix let the window pop back up after another
  form replaced it), fixed (`a3ae2111`): a wrapper round
  `core.show_formspec` ends the window's session.
- **QB** MERGE; one Low (the "Press E" tip twice after a purchase), fixed
  (`85ec28b3`).
- **MS** MERGE; one Low (the step's frozen docstring claimed no skill or
  mount item can sit in a station's grid), reworded (`5b367ec7`).

Main has 138 portable fixtures (8 new: `r44_ih`, `r44_fr`, `r44_ch`,
`r44_ts`, `r44_pp`, `r44_mb`, `r44_mq`, `r44_qb`). The lanes' own gates are
in their reports (each lane's full fixture run, `check_fresh_server.py`,
a smoke boot; QB's full run 138/138 before its merge to `36019071`); MS's
step test 27/27 and lane IT's suite 59/59 on `1770300d`. This lane:
`tools/r37_dc` PASS, `check_upgrade.py` PASS (0.44.0 against origin/main),
`check_fresh_server.py` PASS. No seed fleet: no world generation changed.

**Round-end gates on the final branch** (`r44-d`, coordinator,
2026-10-09): full `run_fixtures.sh` 138/138, `check_upgrade.py` PASS
(0.44.0 against origin/main `9dc2fad5`), `check_fresh_server.py` PASS,
smoke boot PASS.

`mods/` +4,172 −2,106 lines this round (99 files), two new mods
(`grug_keys`, `grug_quickbar`).

### Shipped, by lane

Numbers are comparisons on the lanes' harnesses or seed 42, never targets.

- **IH, inventory logic** (`6cebd909`;
  [inventory_equipment.md §3](../design/inventory_equipment.md)):
  `grug_inventory.give` (the quiver, partial stacks, then `main[9..]`, the
  bags in slot order, the hotbar last; the Claim Stone only in `main`),
  `fits` and `sort` in `grug_inventory/storage.lua`; the direct
  `add_item("main", …)` sites (creative's, the unused mob capture and the
  skill grants left to their owners), pickup (one handler), dug drops,
  boss loot, trader buys, quest drops and turn-ins go through it, each keeping its
  leftover handling; bags inside bags, swaps and removals checked in the
  allow callback and redistributed before the resize; the sort
  (weapons and offhands, trinkets, armour, consumables, the rest; tier,
  name, quality; identical stacks merge; the hotbar untouched); the potion
  belt list `grug_potion_belt` (4); ammo, the trader's sell list and
  housing fuel read every list. Fixture 134 checks; the review's fuzz run
  (4 × 3,000 inventories × 12 steps) lost or duplicated nothing.
- **FR, the window frame** (`0f1792f0`;
  [inventory_equipment.md §1](../design/inventory_equipment.md)): the frame
  at formspec_version 6 with the old window size (13.5 × 13.673), one tab
  table (`grug_inventory.TAB_ORDER`, the ordering hooks gone), the full and
  short inventory views with the scrollbar echo (a pure scrollbar event
  never reaches a page), the Inventory tab (four bag slots, the belt, the
  coin deposit, Sort with a 2.5 s cooldown and no resend, one 8-wide grid
  of up to 152 slots, the hotbar below); the Bags tab and its 8×3 bug are
  gone; Inventory is the homepage. Bytes with four 32-slot bags: Inventory
  1,405 (the Bags tab, one bag cut to 24 slots) → 2,007; Character (Stats)
  3,177 → 3,619; a frame-only page 513 → 1,113. Fixture 332 checks.
- **AR, art** (`1681aa67`; [tools/r44_ar](../../tools/r44_ar/README.md)):
  eight profession trainer icons (cooking included), 13 baked map icons
  each with a 6 × 6 minimap drawing, a pixel font of 41 glyphs, the
  crosshair and the ring; three variants each on a pick page, the user's
  picks installed (A, font C); 155 files verified, 9.4 KB of art. CC0, by
  GPT-6 Astra, generator committed.
- **MB, the map base** (`461de63a`;
  [world_map.md "Baked layer"](../design/world_map.md)): the renderer bakes
  the icons and the pixel-font region names into the world-map image and
  the small icons into a minimap copy, both behind a cache key over art,
  font and layout (`tools/r44_mb/gen_baked_art.py` → `baked_art.lua`);
  every settlement baked for everyone (ruling 5), 124 icons on seed 42;
  the hypertext names and the settlement, hostile, king and dragon markers
  leave the map page; trainers get their profession icon. Render normal
  9.57 → 9.76 s, high 46.13 → 47.32 s; tiles normal 905,655 B → 814,426 B
  base + 904,751 B minimap (+0.81 MB download), high 7.83 → 7.19 MB; the
  map page 67,513 → 34,063 B (before MQ); the minimap's densest window 15
  markers (17 with home and a waystone) of its 24 slots. Fixture 128 checks.
- **CH, the Character tab** (`e7f2adac`;
  [inventory_equipment.md](../design/inventory_equipment.md)): the mode box
  (3D with the cloak picker as the default, Stats with the balance and
  Withdraw, Effects, Achievements, Professions until Round 45), the gear
  box (eight named slots with the class hand labels, the Scout's quiver),
  Return home at the gear box's foot in every mode, the short view;
  shift-click routes gear into its slot (or swaps), back out in the give
  order, arrows into and out of the quiver, through a hidden one-slot list
  `grug_shift`. Bytes (Scout, four 32-slot bags): 3D — → 5,038, Stats
  4,025 → 5,252, Effects 2,105 → 5,128, Achievements 5,407 → 7,030,
  Professions 2,275 → 5,341 (the gear box is in every mode now, the
  shift-click ring 1,017 B). Fixture 317 checks.
- **TS, Talents & Skills** (`afb5d55d`;
  [skill_trees.md §3](../design/skill_trees.md)): one tab; the tree
  framework (nodes with section, row, column and requirements, box
  connectors, several parents and children), today's trees as two sections
  side by side with their chain names; the skill catalog as one row above
  the short view; skills only on the hotbar (refused elsewhere, dragged
  back onto their icon to remove); talent unlocks and class changes place
  skills on a free hotbar slot or leave them in the row, with a feed line;
  mounts and boats leave the page. Bytes: Talents 4,142 + Skills 1,689 →
  6,460. Fixture 251 checks.
- **PP, Party & PvP and Help** (`7efe63e4`;
  [parties.md](../design/parties.md), [pvp.md](../design/pvp.md)): one page
  without an inventory, the party section unchanged, the PvP section below;
  Help without a view, a Keys block (I, E, Z, rebound keys, the two aux1
  settings); every text naming an old tab or key rewritten (Help, the
  welcome window, trainers, talents, skills, mounts, parties). Bytes: Party
  1,795 → 1,937 (in a party 2,167 → 2,309), Help Start 4,092 → 3,912.
  Fixture 162 checks, with a scan of every string under `mods/` for a
  removed tab name.
- **MQ, map and quest window** (`a3ae2111`;
  [world_map.md "Map window"](../design/world_map.md)): the new `grug_keys`
  (rising edges of zoom and aux1, one control read per player and step);
  Z and the Map tab open the window at 85 % of the screen (`padding[0,0]`,
  fallback 20 × 12, floor 16 × 10), `zoom_fov` 72°; the overlay (arrows,
  home, waystones, own trainers, own services, silver and gold ? at active
  quests' NPCs with the name as tooltip; no !, no zone markers); the quest
  boxes moved from the Quests tab, which is gone; quest targets from an
  index built at start (151 roles, 1,287 regions, about 2 ms): crosshairs
  first (leaders, PvP garrison camps, the rift boss), then up to five rings
  at the nearest regions, at least 0.7 units; all 360 kill objectives
  marked on seed 42 (94 crosshairs, 266 rings); refresh event-driven, at
  most one send a second with a trailing send, in a party a check every
  5 s, a 0.5 s pause after a scroll. Map form 34,065 → 5,013 B at 1×,
  34,289 → 5,134 B at 8× (Accord, no quest selected; 5,759 with a kill
  quest); sends a minute 0 alone, 12 in a moving party (before up to 30).
  Fixture 229 checks.
- **QB, the quickbar** (`85ec28b3`;
  [inventory_equipment.md "Quickbar"](../design/inventory_equipment.md),
  [mounts.md](../design/mounts.md)): the new mod `grug_quickbar`: E opens a
  window with one button per owned mount and boat tier (the ridden one
  framed, a click dismounts), the potion belt (a click drinks through the
  potion's own use, shared cooldown) and Return home (the Character tab's
  gates); a click acts and closes, one send per opening. Mount items are
  inert and no longer handed out or refreshed at join; the riding trainer
  and the shipwright show "Press E to open your mounts." Bytes 1,748 (six
  tiers, four potions, a home), 707 (one tier, one potion); before, the
  Skills page with its mount row was 1,689. Fixture 147 checks.
- **MS, the migration step** (`5b367ec7`;
  [upgrade contract §5.8](../technical/upgrade-contract.md#58-the-declared-steps)):
  `tools/migration/steps/v0_44_0.py` removes the six mount items from every
  list and every skill from every list but `main` slots 1–8, for every
  character, offline ones included; no online work; the names frozen in the
  step and checked against the real 0.43.0 game. `game.conf`,
  `upgrade.json` and `grug_core.migrations` at 0.44.0; Round 43's IT suite,
  MT's unit tests and `r43_gs` part F adapted to a non-empty `migrate`
  list. `tools/r44_ms/run.sh`: unit tests 4/4; end to end 27/27 (a 0.43.0
  world from a `git archive` of `9dc2fad5`, refused unmigrated, the tool's
  `--check`, migrate and `--check` in the container — counts: 1 character,
  1 inventory, exactly 8 stacks removed, every other slot and the meta
  unchanged —
  then a 0.44.0 boot and joins: owned mounts 1, 2 and 5 each with a
  quickbar button).
- **D, this lane:** this completion, the spec's status line and §6, the
  CHANGELOG entry, STATUS, the AGENTS pointer and its cache bullet, ROADMAP,
  BACKLOG, README and the `tools/README.md` line for `r44_ar`.

### Upgrade classification and the declaration

| Lane | Outcome | Reason |
|---|---|---|
| IH | compatible | one new list (`grug_potion_belt`) sized at join; nothing saved removed or rewritten |
| FR | compatible | runtime context only |
| AR | compatible | art only; MB's cache key re-renders the map |
| MB | compatible | a new map cache key: the map image is rendered once again at the first start; no saved state, no world generation |
| CH | compatible | one new, always empty list (`grug_shift`); the mode is runtime context |
| TS | compatible | talent meta unchanged, the catalog runtime only; stray skills stay for MS |
| PP | compatible | the page id kept; tab order and context runtime only |
| MQ | compatible | the minimap meta key and quest state unchanged; an old `grug_map_zone_grid.txt` stays unread; `zoom_fov` set at each join |
| QB | compatible | purchase meta unchanged, the mount items still registered (inert); old stacks wait for MS |
| MS | **migrate** | 0.44.0 no longer accepts mount items or skills outside the hotbar, which are saved character state; the step removes them offline |
| D | compatible | docs |

The round's declaration:
`{"schema": 2, "version": "0.44.0", "map_reset": ["0.40.1"], "new_server": [], "migrate": ["0.44.0"]}`.
A 0.43.0 world needs the tool (stop, back up,
`python3 tools/migrate.py --world <dir>`, start); unmigrated, the start
guard refuses it and names step 0.44.0 and the command. No map reset.

### Decisions during the round

The user (2026-10-08 and 2026-10-09), on the lanes' questions:

- **AR:** variant A for every file, the font from C.
- **FR:** "i opens Inventory" as built: Inventory is the homepage (at join
  and after the map), the last tab stays selected across closes;
  Withdraw stays on the Character tab.
- **MT (Round 43):** its separate `failed` event is kept and documented in
  the interface (answered in the same batch).
- **IH:** a bag moves between bag slots only when both are empty; the sort
  categories as built (higher tier and quality first; arrows, food,
  potions; mixtures and other edge items in "the rest"); the give order
  fills partial stacks, the hotbar's included, before empty slots.
- **MB:** the king's crown over his capital kept; overlapping icons tuned at
  the GUI test; the island names north over the sea; the Steward,
  Crownbinder, Decor Merchant and own-faction innkeepers back on the
  minimap; the +0.9 MB download at normal quality accepted; the kings'
  name tooltips gone.
- **CH:** 3D as the default mode; Return home in every mode; the mode
  buttons as they are.
- **MQ:** the services back on the world map (own faction); the zone
  markers removed (with their placement and the zone-grid cache); a quest
  target in the other faction's land gets a crosshair (garrison camps, the
  rift boss); the ring minimum 0.7 units; the own arrow moves only on an
  event when alone; no quest preselected.
- **QB:** one button per owned tier (the wireframe was layout only).
- **Process** (2026-10-09): the fixture-run rule tightened: during a lane
  only the fixtures that test the behaviour being changed, not every
  fixture that loads a changed file (round workflow §3, the brief
  templates, AGENTS.md).

### Deviations from the plan

- **Wave 1 merged as one:** IH merged into FR's branch, AR into MB's, and
  the integration branch `r44-w1` carried FR, MB and main (Round 43) into
  main in one merge (`93f1536f`; fixtures 133/133, smoke boot PASS); wave 2
  started from `r44-w1` (`5d2905cd`).
- **Round 45's wave 1 started in parallel** on 2026-10-09 (the user's go)
  from main `c48eb681`, in its own worktrees; nothing of it merges before
  this lane.
- **The spec's §6 and preamble are superseded in two points** (§4.11): the
  removal of mount items and stray skills is the offline step 0.44.0, not
  "removed at login"; and the precondition "framework and AGENTS change
  before the plans are approved" became the parallel run with the merge
  rule (§7).
- **§4.10 "from every list":** the step covers player inventories only. A
  crafting station's grid is a detached inventory saved in node meta, which
  needs the deferred map part (open notes).
- **§4.10 "a worktree":** MS built the 0.43.0 world from a `git archive`
  of `9dc2fad5` in its run directory.
- **§4.7 overlay:** the services are on the world map and the zone markers
  are gone (the user's answers).
- **§7 file lists:** lanes touched shared files outside their lists, each
  named in its report: PP's texts in TS's and QB's files, CH's
  `give(…, skip_quiver)` and the achievements and professions bodies, TS's
  tab-table line, MS's changes to MT's unit tests and `r43_gs` part F.
- **Estimates** (§1, unmeasured) were not tracked.

### Open notes

The reviews' and reports' backlog notes are in the
[BACKLOG](../../BACKLOG.md#round-44-carry-overs) (theoretical, no
severity). The overlapping map icons (58 pairs at normal quality, 44 at
high) and the names over icons are tuned at the GUI test. The stale comment
in `grug_mapgen/wp40/r7_loader.lua:46-47` waits for the next real mapgen
change, because a comment edit there invalidates the world-layout cache.
`tools/r44_ar`'s sheet captions still say the picks are pending (tools
only).

### GUI checklist

Plan §6, desktop (GUI scale 1 and 2) and the web build (about 1280 × 720);
on a copy of a 0.43 world migrated with the tool, and on a fresh world.

**Migration (first):**

1. Start the 0.43 world under 0.44.0 without the tool: refused, the
   message names step 0.44.0 and the command line.
2. Server stopped, on a copy: `python3 tools/migrate.py --world <copy>
   --check` (0.43.0, step 0.44.0 due), then without `--check`, then start.
3. Join: no mount items anywhere, no skills outside the hotbar, the hotbar
   skills kept, owned mounts in the quickbar (E); a removed skill can be
   dragged from the Talents & Skills row again. The first start re-renders
   the map once.

**The window and its tabs:**

4. `i` opens Inventory; the tab order Inventory, Character, Talents &
   Skills, Crafting, Party & PvP, Help, Map; the same window size on every
   tab; closing on the Map tab returns to Inventory next time.
5. **Web build:** the tab row fits ("Inventory" and "Party & PvP" are
   longer than the old captions; arrows may appear).
6. Other tabs: hotbar + 2 rows at the same place as on Inventory, nothing
   overlapping; the mouse wheel scrolls one row. The Crafting tab still
   works inside the new frame: the grid crafts, and shift-click moves
   between the craft grid and the inventory.

**Inventory:**

7. The top row readable: four bag slots, the potion belt, the deposit,
   Sort. Four bags of mixed sizes as one grid; scroll halfway, then equip
   or remove a bag or Sort: the position is kept.
8. Sort: the order, merging, the hotbar untouched, clicks within 2.5 s do
   nothing.
9. Swap a bag for a larger and a smaller one (with and without room: "No
   room for the bag's contents…"); take a full bag out by drag and by drop,
   with and without room; a bag inside a bag, never its own list.
10. The belt refuses anything but potions and elixirs; a Bag of Coins
    deposits.
11. Dig, pick up, loot, buy, fish, a quest reward: rows 2–4, then the bags,
    then the hotbar; partial hotbar stacks still grow; new characters'
    torches and apples no longer land on the hotbar. A Scout shoots arrows
    from a bag; selling from a bag works; the Claim Stone never lands in a
    bag.

**Character:**

12. Opens on 3D with the cloak picker; Stats (balance, Withdraw), Effects
    (**8 rows** now: 7 plus "… and N more", before 12), Achievements (pager)
    and Professions each inside their box.
13. **Mode buttons at GUI scale 2** and on the web build: does
    "Achievements" or "Professions" clip, do the gear labels?
14. Gear labels per class; the quiver only for Scouts. **Quiver above 100
    arrows:** the cell shows the total, but no item tooltip and no hover
    highlight (formspec_version 6); a click still takes up to 100. Empty
    slots' ghost images look right, their labels' tooltips show.
15. Equipping by drag still works. Shift-click: a helmet into Head, a second one swaps; an equipped piece
    goes to rows 2–4, bags, then the hotbar; with everything full a feed
    line; arrows into and out of the quiver; an apple does not move.
16. Return home in every mode, counting down in minutes.

**Talents & Skills:**

17. Both trees side by side with chain names, connectors under the nodes
    (gold for a full parent); a green node buys a rank, a locked one shows
    its text and reason; respec works.
18. Drag a skill onto a free hotbar slot; refused onto rows 2–4, a bag, the
    belt, an occupied slot, a second copy; dragged back onto its icon it is
    gone. A talent skill unlocked with a free slot lands on the hotbar
    (feed line), with a full hotbar it waits in the row.

**Party & PvP and texts:**

19. One tab without an inventory: the online players of your faction,
    invite, accept, decline, kick, make
    leader, leave, the checkboxes and the colours dropdown; the PvP section
    with the flag button on the right; on the web build the PvP rule lines
    stay inside; an open dropdown during a PvP countdown closes once a
    second.
20. Help has no inventory and every sub-page scrolls to its end; its Keys
    block names I, E and Z; the welcome window shows six points, nothing
    clipped at 1024 × 600.

**Map window:**

21. Z opens it with no zoom message and no zoom (a player whose field of
    view is not 72° sees a short change while Z is held). **A quick tap on
    Z** may be missed (the client sends key states about every 0.09 s).
    The Map tab opens it too; Back to inventory and Esc work; it covers
    about 85 % of the screen; a long zone name at the 16 × 10 floor.
22. The minimap switch in the window; the overlay: own and party arrows,
    home, waystones, own trainers with profession icons, own services, ?
    only for active quests with the NPC name; no !.
23. The baked layer at 1×–8×, both qualities: icons and pixel names, the
    other faction's places visible. **Overlapping icons** and names over
    icons: tune here. **The king's crown over his capital** (kept by the
    user): still readable?
24. The quest boxes: no quest preselected; Quest HUD, Track on HUD, Abandon
    with confirm. A kill quest shows rings (at least 0.7 units), a leader
    quest the crosshair, a garrison-camp quest a crosshair in the other
    faction's land; talk and use targets marked.
25. Alone and standing still nothing refreshes; in a party about every 5 s;
    scrolling never jumps.
26. The minimap: small icons glide with the map; !, ?, trainers, home,
    waystones, party, the Steward, Crownbinder, Decor Merchant and
    innkeepers.

**Quickbar:**

27. E opens it, Esc closes it; E does nothing while the inventory or chat is
    open. A mount summons and the window closes; reopened, the ridden tier
    is framed and dismounts; refused in combat; a boat refused on land,
    works in water.
28. The belt shows counts; a click drinks and closes; a second potion within
    60 s is refused; empty slots cannot be clicked. Return home works,
    refused in combat.
29. The riding trainer and the shipwright show "Press E to open your
    mounts." once, also after a purchase; no mount item after a purchase or
    a relog. With a rebound aux1 key that key opens it; with "Toggle Aux1
    key" every second press; with "Aux1 key for climbing/descending",
    holding E also sinks in water and climbs down ladders.
30. The web build: the quickbar fits.

### For the platform

0.44.0 declares the first real step, `0.44.0`, under the Round 43 tool and
interface unchanged ([tools/README.md](../../tools/README.md#the-migration-tool)):
for a 0.43.0 world, `python3 tools/migrate.py --world <dir>` from a full
export of the 0.44.0 commit runs it once (events `start`, `step_start`
`{0.44.0, from 0.43.0}`, `step_done` with its counts, `done`). It writes
only the inventories of characters that held a mount item or a skill
outside the hotbar, plus the record; no online work, no map part. Tested
end to end on SQLite; on PostgreSQL the step runs in IT's suite on a world
without skills or mounts (it uses only the shared data API).
