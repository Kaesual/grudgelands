# Round 67 — playtest feedback: social tab, map window, crafting, containers, world fixes

Planned with the user on 2026-10-30 from the notes of the group playtest of
2026-10-28. **Started on the user's "go" on 2026-10-30; Claude
coordinates.** **Complete on 2026-10-30:** all six lanes merged (five
independent reviews: MAP MERGE, WORLD, SOCIAL, CRAFT and CONTAINERS MERGE
after one fix round each, every delta review MERGE; the art study checked
by the coordinator); **not pushed**; GUI test pending, joining the joint
test of 0.57–0.66 ([completion](#completion-2026-10-30)).
Version: **0.67.0**. Classification: **migrate** (step 0.67.0: the metal
rods are removed items and become bars; every other lane compatible).
Delivery state: [STATUS](../STATUS.md).

## Why

The user's notes, each checked against the code at `0ff50ed1` while
planning (the lanes re-check them, round workflow §2.4):

- **Party invitations** are one chat line (`grug_parties/init.lua`
  `invite`) and a row in the Party tab; players miss them. A player in a
  party cannot be invited at all (`eligible`, "That player already belongs
  to a party."), and an invitation expires after 120 s. The party HUD sits at
  the left edge, vertically centred; without a party that place is empty.
- **The Party & PvP tab** has three stacked panels (current party, online
  same-faction players as a plain textlist, pending invitations) and the
  PvP section on the right (`grug_parties/ui.lua`). It refreshes on party
  events only. No player favourites exist; there are no race icons (only
  class and faction icons).
- **Creative category tabs** show on every page: the navigation draws the
  second row whenever creative is enabled, whatever page is open
  (`grug_inventory/navigation.lua` `navigation_layout`).
- **Duplicate recipe rows:** the crafting list has one row per recipe,
  labelled with the output only (`grug_jobs/ui.lua` `list_content`). Several
  outputs have more than one recipe: the three planks (log or bush stem),
  every block from its stairs or slabs (about 28 blocks, a registry loop),
  seven dyes, glass fragments, the locked chest, and sword, dagger and
  greataxe of six metals (stick or metal rod). Metal rods have no other use.
- **Map markers** are displaced by up to half an icon (16 px) to avoid
  overlaps (`grug_map/icon_layout.lua`, via `markers.lua` `M.offsets`), in
  the map window and the minimap. The solve is not run at server start: it
  runs per build, but over every marker of the layer including those
  outside the view, and the quest layer reserves a slot for every quest
  giver, including those without a visible quest. So markers move for
  neighbours the player cannot see.
- **Party arrows are not displaced** and are drawn on top. They are
  re-checked every 2 s (`window.lua` `PARTY_US`) and only then redrawn, so on
  a fast mount a member's arrow can lag by tens of nodes. That is most
  likely what the playtester saw.
- **The map window** is 85 % of the capped viewport (Round 66,
  `grug_core/ui_window.lua`). Map and quest column share the width equally.
  Quest rows are 1.25 units high, so about two are visible. The list is
  sorted by quest id, while the HUD sorts by level (`grug_quests/hud.lua`).
  The layer dropdown closes whenever a party move redraws the window. It
  replaced a button row in `28fa1aac`.
- **Flight underground** is refused only at summon time, by comparing the
  player's y with the planned terrain height (`grug_mounts/entity.lua`
  `summon_position`). No-fly zones are x/z only (`flight.lua`).
- **Flying mounts climb and sink at 0.6× their horizontal speed**, a
  hard-coded factor: T3 8 / 4.8, T4 12 / 7.2 nodes/s (`entity.lua`
  `flight_step`).
- **Nametags** sit on every levelled mob, critters included, and on every
  settlement NPC, plain citizens included (`grug_mobs/levels.lua`,
  `start_villagers.lua` `install_nametag`). Settlement NPCs carry their role
  (`_grug_socket_role`): `idle` and `work` are plain citizens.
- **Spiders stuck in rock:** mobs_redo's default spawn check tests one
  node column (`mob_area_spawn` is off) for the `mobs:spawn` rows, the
  spider's cave row among them; the region and depth spawns already use
  `mobs:can_spawn`. The spider's box is 2.1 nodes wide
  (elite 2.9, rare 4.2, scaled after the spawn without a re-check), so it
  spawns into cave walls. Its path searches fail from inside a node, and
  after three failures it gives up and heals to full (`aggro.lua`
  `give_up_target`).
- **Containers:** chest and locked chest have 32 slots, the bookshelf and
  the vessels shelf 16 (vendored MTG nodes). There is no sort button on any
  node inventory. Text on nodes exists only as hover infotext (signs). The
  inventory sort is written for the player's own slots
  (`grug_inventory/storage.lua` `grug_inventory.sort`).
- **Furnace fuel:** coal and charcoal burn 80 s, anthracite 120 s, logs and
  cactus 15 s, leaves 2 s; a bar smelts in 10 s, so one coal makes 8 bars
  (`grug_jobs/automatic.lua` `FURNACE_FUELS`; the user measured the same).
- **Craft amount:** the Craft button reads "Craft ×N" but follows only
  +/−, not a typed number (formspec); "makes 10" stands only in the
  recipe's subtitle. "Recipe details" is a button on the ingredients
  heading, away from the favourite star.
- **Finding a material** needs a recipe that uses it first. The source
  index behind Recipe details is a reusable module (`grug_jobs/sources.lua`,
  with the text lines in `details.lua` `grug_jobs.source_lines`).

## 1. Lanes and order

| Wave | Lane | Worktree / branch | Result | Depends on |
|---|---|---|---|---|
| 1 | SOCIAL — Social tab, invitation box, favourites | `r67-social` | The tab renamed and rebuilt, a sortable online-players table, the invitation HUD box | — (race icons after ART's pick) |
| 1 | MAP — map window, markers, layer buttons, quest list, quest HUD order | `r67-map` | 90 % window, no marker displacement, smaller markers, flat layer buttons, compact quest list and HUD both story first, then by level | — |
| 1 | CRAFT — recipe variants, craft box, material help, fuel, creative tabs | `r67-craft` | One row per output with a variant switch, fewer recipes, the per-craft hint, a Materials help page, half fuel times | — |
| 1 | WORLD — flight, nametags, spiders | `r67-world` | Flight underground, vertical speed per tier, nametags only on functional NPCs, spiders that spawn with room | — |
| 1 | CONTAINERS — sort, labels, tiers | `r67-containers` | Sort and label on chests, three tiers of chests and shelves with recipes and an upgrade button, scrolling lists | — (merges after CRAFT; final textures after ART's pick) |
| 1 | ART — race icons, container tier textures (Astra) | `r67-art` | Six race icons and the tier textures, with a review page | — |
| 2 | D — delivery documentation | coordinator | Completion, version, declaration, status owners, GUI checklist | all merged |

Merge order: **WORLD, MAP, CRAFT, SOCIAL, CONTAINERS, ART**, then D.
CONTAINERS merges main after CRAFT (both change the recipe catalog; the
merge is resolved by regenerating it, never by hand). SOCIAL
and CONTAINERS build with placeholder art (the tinted existing textures, a
lettered placeholder per race). After the user's pick, ART's textures replace
the placeholders: as a commit on ART's branch, or a small follow-up when
ART merges last.

## 2. The user's rulings (2026-10-30)

**Social**

1. The **"Party & PvP" tab becomes "Social"** and is rebuilt.
2. **Invitation box in the HUD:** "<name> has invited you to join their
   party" with an icon and the note to answer in the Social tab, where the
   party HUD stands. It stays until the invitation expires, is accepted or
   is declined. With several invitations it shows one and "+N more". No
   `/accept` command.
3. **A player in a party cannot be invited** (today's rule stays), and the
   list shows no invite button for them.
4. **One party box, no sub-tabs** (Q1 answered 2026-10-30: "current party"
   and "pending invitations" exclude each other, since a player in a party
   cannot hold invitations). Without a party the box shows the pending
   invitations under a heading with the count ("0 Pending Invitations",
   "1 Pending Invitation"), with a short hint to invite from the list when
   it is empty. In a party it shows "Current Party" with its actions.
   Accepting an invitation switches it at once.
4a. **Layout** (Q2 answered 2026-10-30): the party box and the PvP section
    stacked on the left, the online players table at full height on the
    right.
5. **"Online Players" replaces "Online same-faction players":** every
   online player, both factions, in one scrollable table. It has its own
   row design (like the sell and quest lists), one line per row with
   faction, name, class, race and level. Faction, class and race are icons
   with the word as tooltip.
   - **Sort:** own faction first, the enemy faction below. Within a
     faction, favourites first, then by name; favourites are sorted by name
     too.
   - **No paging.**
6. **Row actions on the right:**
   - a **star** that makes the player a favourite;
   - an **invite button**, shown only when the viewer can invite: not in a
     party, or its leader, and the target eligible.
7. **Race icons:** one icon per race, made by ART.
8. **Refresh on change, coalesced:** the list refreshes on changes (join,
   leave, level, class, party), but a burst of changes sends one update per
   interval instead of one per change.

**Crafting**

9. **The Creative category tabs show only while a Creative page is open.**
10. **One list row per output**, with a **variant switch** where an output
    has several recipes.
11. **Stairs and slabs are end products:** the recipes back to the block
    are removed.
12. **Bush stems drop one plank** of their wood when dug; the stem-to-plank
    recipes are removed.
13. **Metal rods leave the game:** the rods, their recipes and the rod
    variants of the weapons.
14. **Craft button:** plain "Craft" (and "Queue"), no count. Left of it a
    short fixed hint "×10 per craft" for outputs that make more than one.
    "makes 10" stays in the subtitle.
15. **"Details" with an info icon, left of the favourite star**, replaces
    the "Recipe details" button.
16. **A Materials help page** in the Help tab: search any material by name
    and see where it comes from (the Recipe details source lines).
17. **Furnace fuel burns half as long** as today.

**Map**

18. **The map window takes about 90 % of the screen** in width and height
    on every resolution; the viewport cap does not apply to it. The map
    grows and may take more width than the quest list.
19. **Quest list:** lower rows, so a long list is easy to scan. Q3
    answered 2026-10-30, option (a): the Story and Side quests groups stay,
    sorted by quest level inside each group.
19a. **The quest HUD follows the same order:** story quests on top, each
     group sorted by level. Ties are broken as today, by title and then id.
     The HUD gets no group headings.
20. **Markers about 2/3 of today's size; overlaps are allowed.** The
    displacement goes, in the map window and on the minimap.
21. **Player and party markers are always at the true position and always
    on top.**
22. **The layer dropdown becomes a row of flat buttons** above the map (two
    rows if one does not fit); the active layer's button is marked.

**World**

23. **Flight is allowed underground.** No-fly zones stay as they are, by
    x/z only, also below enemy territory.
24. **Vertical flight speed** becomes settable per mount tier.
25. **Nametags only on NPCs with a function** (quest givers, vendors,
    trainers, services); none on plain citizens and none on critters.
26. **Spiders (and other wide mobs) must not get stuck in blocks.**

**Containers**

27. **Chests get a Sort button**, sorting like the inventory but only the
    chest.
28. **Chests get a label**, shown as hover text like signs; no icon. In
    another player's claim, editing it needs the "Everything" right; in the
    open world, anyone may edit it. Bookshelves and vessels shelves get no
    label and no sort.
29. **Three tiers:** Wooden Chest (32 slots), Steel-Reinforced Chest (T3,
    64), Abyssal Chest (T6, 96).
    - **Locked chests, bookshelves and vessels shelves** get the same three
      tiers. Shelves grow from 16 to 32 slots at the base tier, so all three
      tiers are 32, 64 and 96.
30. **Upgrade button** on every container: "Upgrade ⟨Steel Bar⟩×8", then
    "Upgrade ⟨Abyssal Steel Bar⟩×8". The contents stay. Same edit rights as
    the label.
31. **Direct recipes** for every tier:
    - Steel-Reinforced Chest: 8 planks and 8 steel bars.
    - Abyssal Chest: 8 planks, 8 steel bars and 8 abyssal steel bars.
    - The shelves and the locked chest follow the same pattern from their
      own base recipe.
32. **Same layout for every container:** 4 rows of 8 slots as today; more
    slots scroll.
33. **Same 3D models for every container;** the higher tiers differ only by
    texture (ART), shelves included.

**Coordinator defaults** (the user may overrule them; look and feel is
tuned after the first in-game look):

- **Refresh interval** of the online list: at most one send per 2 s per
  viewer, only to players whose current inventory page is Social (the
  server cannot tell whether the inventory is open). A single change goes
  out at once when the last send is older. A send is held briefly after a
  scrollbar move, like the map window's `QUIET_US`.
- **Players listed:** the viewer's own row is included (marked "you", no
  actions). The invite button needs the target to be:
  - in the own faction;
  - online;
  - in no party;
  - accepting invitations;
  - not already invited by the viewer;
  - and the party must not be full.

  So enemy rows never show it.
- **Favourites** live in player meta like the recipe favourites, by name.
- **Invitation box:** it shows the inviter, the seconds left and "Open
  Social to answer". It shows regardless of the Party HUD switch and never
  while the player is in a party. When a party forms, the invitations of
  both players are cleared: today only the joining player's are, so a
  player who becomes a leader would keep theirs. Expiry raises no event,
  so the box runs its own timer.
- **Settings row** (Invitations, Party HUD, Health colours): the top of the
  left column, above the party box.
- **Variant switch:** "Recipe 1/2 ◀ ▶" in the craft box. It opens on the
  first variant the player can craft now, else the first. After rulings
  11–13 and the locked-chest default only dyes and glass fragments keep
  several recipes. The switch stays general.
- **Recipe favourites** belong to the output, not the variant. Stored
  recipe ids map to their output when read.
- **Locked chest:** one recipe per tier: the open tier's ingredients plus 1
  iron bar. CONTAINERS removes the "chest + iron bar" variant. Only the
  owner may label, sort or upgrade a locked chest.
- **Metal rods in saved state:** a migration step refunds them as bars of
  their metal (two rods → one bar, rounded up). It covers every store the
  upgrade contract lists for a removed item:
  - inventories (bags and overflow included), offline characters too;
  - the `recovered:*` and `packed:*` entries;
  - mail attachments;
  - the `consumed` stacks of running and queued craft jobs (`grug_jobs:job`
    and `grug_jobs:queue` player meta).

  Rods in chests on the map stay unknown items. The contract accepts that,
  since a step never reads the map.
- **Fuel times:**
  - coal and charcoal 40 s, anthracite 60 s;
  - logs and cactus stay at 15 s, leaves at 2 s;
  - the Claim Stone's fuel is unchanged.
- **Map window:**
  - Map share about 62 % of the width.
  - Quest rows one line high (title and `[Lv N]`, like the HUD), about
    0.6 units.
  - Layer button labels: Quests, Bosses, Services, Travel, Places, PvP,
    Zones, None.
  - Markers 21 px at the reference (today 32), the floor scaled from 16 to
    11 px.
  - Draw order by importance, players on top as today.
  - The party check goes from 2 s to 1 s now that no dropdown is lost. MAP
    reports the window's bytes per send before and after; if a send grows a
    lot, it stays at 2 s.
- **Vertical flight speed:** a per-tier field defaulting to the horizontal
  speed (1.0×; today 0.6×).
- **Summon room:** with the underground rule gone, a flying mount is
  summoned only where its collision box fits. Ground mounts keep today's
  rule, which works in 1-wide tunnels and doorways.
- **Nametags:**
  - The tag stays on guards, kings and every hostile or neutral mob (they
    are fought).
  - It goes from settlement NPCs with the role `idle` or `work`, and from
    mobs with the disposition `critter`.
- **Spiders:**
  - Wide mobs use the area spawn check (the existing `mobs:can_spawn`) per
    mob, not through the global `mob_area_spawn`.
  - The elite and rare scale re-checks the room and falls back to the base
    size if the scaled box does not fit.
  - **Stuck cleanup:** a mob counts as stuck only when its scaled collision
    box overlaps the collision boxes of walkable nodes, not just its origin.
    Snow layers, slabs and stairs under the feet are normal footing. It is
    removed when it stays stuck after its path searches failed (the case
    that today ends in `give_up_target`) and no player watches.
- **Label:** at most 40 characters. Hover text: the label on the first line
  and the container's name on the second. The edit right is
  `core.is_protected` (as for writing a sign): it follows claims with the
  "Everything" right, and inactive or draft claims protect nothing.
- **Chest names:** "Steel-Reinforced Chest", "Abyssal Chest" (and "Locked …",
  "… Bookshelf", "… Vessels Shelf").

## 3. Shared conventions

- English UI strings. Player-visible changes go into the Help section that
  describes the topic today; the sections are Start, Story & Craft, Basics,
  Mail, Formulas, About and Sound. The new Materials section is the only
  new one. "Party & PvP" is named in Help, the welcome text and the invite
  chat line; SOCIAL renames all of them.
- Each lane updates the design docs of its topic:
  - SOCIAL: `parties.md`, `pvp.md`, `inventory_equipment.md`;
  - MAP: `world_map.md`;
  - CRAFT: `items_crafting.md` (rods, fuel);
  - WORLD: `mounts.md`, `settlements.md`, `biomes_mobs.md`;
  - CONTAINERS: `inventory_equipment.md`, `housing.md`.
- Vendored files (`mods/BASE/*`) change only with GRUG PATCH markers and a
  `VENDOR.md` entry (AGENTS.md).
- A screen the user did not mention keeps today's look, except the map
  window (ruling 18).
- No new sound (sound approval gate).
- Art follows the icon style: readable at 32 and 16 px, few details.
  Tier textures keep the vendored models' UV layout.
- Every refresh is event-driven or coalesced. No per-tick formspec sends.

## 4. Lane goals

### SOCIAL — Social tab, invitation box, favourites

Rename the tab and rebuild it.
- **Party box:** one box whose content switches (ruling 4).
- **Online players:** the table of ruling 5 with the row actions of ruling
  6. It is a compact row of its own, like the sell list; the shared row
  helper floors rows at 1.25 units and has no action buttons.
- **Layout** (ruling 4a): the party box and the PvP section stacked on
  the left, the online table at full height on the right.
- **Invitation box:** the HUD box of ruling 2, sharing the party HUD's
  anchor; never together with the party list (see the default).
- **Favourites** in player meta.
- **Refresh** per ruling 8 and its default.
- **Race icons:** placeholders until ART's pick.
- **Performance:** the lane measures the formspec bytes with a full list of
  50 players and reports them.
- **Pinned title:** the fixtures `r38_wc`, `r44_fr`, `r44_pp`, `r31_pvp`,
  `r31_p2`, `r451_kf` and `r48_admin` pin "Party & PvP" and follow the
  rename.

### MAP — map window, markers, layer buttons, quest list, quest HUD order

Rulings 18–22 and 19a.
- **Window size:** the map window sizes from the real window information,
  not the capped viewport.
- **Markers:** remove the displacement from the window and the minimap
  (`icon_layout.lua` and its callers, the reserved quest slots and the
  offsets cache). Shrink the markers to about 2/3 and order the drawing by
  importance.
- **Layer buttons:** bring back a flat button row; the old handler fields
  still exist.
- **Quest list:** a compact one-line row variant, added to
  `grug_core.ui.rows` as an option that leaves today's rows (mail, quest
  giver) unchanged. Within the Story and Side groups it is sorted by
  level.
- **Quest HUD:** `grug_quests.hud_entries` puts story quests first
  (ruling 19a), using the same story test as the map list. One shared sort
  function serves both, so they cannot drift apart.
- **Party check:** apply the default, with bytes per send before and after.

### CRAFT — recipe variants, craft box, material help, fuel, creative tabs

Rulings 9–17.
- **Creative tabs:** the second navigation row only on `creative:*` pages.
  `navigation_layout` gains the selected page as an optional argument. The
  map window's call (`grug_map/window.lua`) passes none and shows no
  category row.
- **Recipe list:** one row per output with the variant switch.
- **Recipe removals:**
  - Remove the stairs and slab back-recipes (the loop in
    `grug_jobs/registry.lua` and the generator's copy).
  - Remove the stem recipes and set the bush stems' drop.
  - Remove the metal rods: items, recipes, weapon variants, price entries,
    and the probes and fixtures that pin them.
  - Catalog changes go through `tools/r45_rg/edits.lua` and the generator,
    never by editing `basic_recipes.lua` by hand.
- **Migration:** CRAFT owns the step (`tools/migration/steps/v0_67_0`), its
  entry in `grug_core/migrations.lua`, and the version 0.67.0 with its
  `migrate` entry in `game.conf` and `tools/web_data/upgrade.json`, so
  `check_upgrade.py` passes in the lane. It also owns the step's test and
  the container run of every declared step.
- **Craft box:** the plain button, the per-craft hint, and the Details
  button by the star.
- **Materials help page:** a Help section with a search field, a result
  list and the source lines. `grug_jobs` depends on `grug_inventory`, so
  the section reaches `grug_jobs` at runtime (`rawget`, as help.lua already
  does for the mender) or registers through a hook.
- **Fuel:** the new times, with the stale fuel comments fixed. Burn times
  that the design docs or Help name are updated.
- **Checks:**
  - `gen_basic_recipes.lua --check` and the `r45_rg` fixture;
  - the price load audit (output ≤ inputs);
  - `income.py --check`;
  - `r47_an` (it pins the 80 s fuel).

### WORLD — flight, nametags, spiders

Rulings 23–26 and their defaults.
- **Flight:** drop the summon-time underground rule, add the room check,
  and add the vertical speed field per tier. Update `docs/design/mounts.md`
  §3.2 and the speed line.
- **Nametags:** remove them from plain citizens and critters.
- **Spiders:** apply the spawn room check, the re-check after scaling and
  the stuck cleanup.
- **Spider evidence:** a fixture covering a spider in a narrow cave
  pocket, plus counts from a short headless run underground (spawns, stuck
  removals). Keep that run inside the mapgen run budget.

### CONTAINERS — sort, labels, tiers

Rulings 27–33.
- **Sort:** generalise the inventory sort to any inventory and slot list.
  The player's sort must stay byte-identical (fixture), and the Sort button
  goes on chests.
- **Label:** the label field with the claim rights of ruling 28.
- **Tier nodes:** the tiered nodes (open variants of chests included) with
  their recipes and the upgrade button. The upgrade swaps the node and
  keeps the meta and contents. On an open chest it swaps to the tier's
  `_open` node and rewrites the remembered node name of every viewer, so
  closing the lid lands on the new tier.
- **Scrolling:** the scrolling lists. The scroll position survives a resend
  after sort or upgrade.
- **Shelf growth:** existing shelves grow from 16 to 32 slots when opened
  (and new ones at construction), never shrinking anything.
- **Pinned sizes:** update every place that pins container sizes or the
  chest LBM:
  - `grug_housing/packed.lua` `CONTAINER_LISTS` and the `r50_pgame` probe;
  - `recovered.lua`;
  - the `r491_view` fixture;
  - the LBM label `check_fresh_server.py` asserts.
- **Digging:** a tiered container drops its own tier.
- **Textures:** placeholder tints until ART's pick.

### ART — race icons, container tier textures (GPT-6 Astra)

**Goals:**
- Six race icons (human, dwarf, elf, orc, troll, undead), readable at 16
  and 32 px in the icon style.
- Tier textures for the Steel-Reinforced and Abyssal versions of the chest,
  the locked chest (the open model's textures included), the bookshelf and
  the vessels shelf, on the existing models and UV layouts.

**Output:** a review page with the candidates for the user's pick, at the
sizes they appear in game. Race icons go to a directory the
`web_data/export.lua --check` texture grammar accepts.

## 5. Rules

- [Round workflow](../process/round-workflow.md) and AGENTS.md apply. Lanes
  never push, merge, sync or touch the main checkout.
- Re-check first: every claim of this plan a lane acts on is checked against
  the code at the base commit and reported as confirmed, changed or refuted.
- Fixtures: your own plus the ones that test the behaviour you change. Run
  the full set once before your report, and name what you ran and why.
- Headless runs only through `tools/luanti_headless.sh` (never the user's
  Luanti folder), with `LC_ALL=C` for captures.
- A case the rulings do not cover is decided by the ruling's reason.
  Otherwise stop that path and report under `## Blockers / questions`.

## 6. Verification

**Per lane** (round workflow §3):
- `check_lua.sh` on changed Lua;
- `check_fresh_server.py`;
- the lane fixture `tools/r67_<lane>/portable_test.lua`;
- the full fixture run once;
- one smoke boot;
- the upgrade classification in the report;
- an independent review. For ART, that is a review of the textures against
  the art rules.

**Fixtures cover at least:**

- **SOCIAL:** the sort (faction, favourite, name). The invite button's
  visibility for:
  - no party, leader and member;
  - enemy, in a party, invites off, already invited, full party.

  The party box with and without a party, and the count label in singular
  and plural. The HUD box: shown, "+N more", hidden on expiry,
  accept and decline. The coalesced refresh: a burst gives one send.
- **MAP:**
  - the window size at 1280×720, 1920×1080 and 3840×2160;
  - markers at their anchors (no offsets);
  - marker sizes;
  - the active layer button;
  - the quest list and the HUD in the same order: story first, by level
    inside each group.
- **CRAFT:**
  - one row per output and the variant default;
  - none of the removed recipes registered, rods gone;
  - the stem drop;
  - the creative row only on creative pages;
  - fuel times;
  - Materials search hits and source lines;
  - the migration step's test.
- **WORLD:**
  - summon underground allowed, still refused in a no-fly zone and without
    room;
  - vertical speed per tier;
  - the tag decision per role and disposition;
  - a wide mob refused where its box does not fit, and the scale re-check;
  - the stuck test: a mob on snow, a slab or a stair is not stuck, a spider
    whose box sits in rock is.
- **CONTAINERS:**
  - the player sort byte-identical and the chest sort;
  - label rights in the open world, own claim, foreign claim with and
    without "Everything", and locked chests;
  - upgrade keeps the contents and charges 8 bars;
  - direct recipes;
  - a 16-slot shelf growing to 32 with its items kept;
  - dig drops by tier.

Round end on main: the gates of the round workflow §3,
`check_upgrade.py`, sync to Luanti.

### GUI checklist (desktop and web)

Refined by lane D from the lanes' excerpts and the reviewers' notes. Each
item on the desktop client and on the web client. Items marked *look* ask
for the user's verdict on a first-look default.

**Social**

1. **The tab** is called "Social" in the tab bar, its title, Help, the
   welcome text and the invite chat line. Left: the settings row
   (Invitations, Party HUD, Health colors), the party box, the PvP section
   below it; right: Online Players at full height (about 20 rows at
   1920×1080).
2. **Inviting:** A invites B from B's row. A's Invite button goes; B gets
   the chat line and the HUD box at the party HUD's place ("<name> has
   invited you…", the seconds left, "Open Social to answer"); B's party
   box reads "1 Pending Invitation". A third player invites B: the box adds
   "+1 more". With the Party HUD switched off the box still shows. (At
   1920 px "party." may wrap onto a line of its own; cosmetic.)
3. **Answering:** B accepts: B's box switches to "Current Party (2/10)" at
   once and both HUD boxes go. A decline or the 120 s expiry: the box goes
   and A's Invite button comes back at once.
4. **No Invite button** for an enemy, a player in a party, a player with
   invitations off, one already invited, the own row ("(you)"), a party
   member, or when the viewer's party is full; a member who does not lead
   sees none.
5. **Favourites:** a star turns gold, the row moves to the top of its
   faction's group, and the stars survive a relog. Players still in
   character creation are listed last, without icons or buttons.
6. **Live list:** joins, leaves and level changes update the list while it
   is scrolled, without a jump and without breaking a scrollbar drag; a
   burst arrives as one update (at most one per 2 s). Flagged for PvP with
   the tab open, the countdown steps by 2 s. *Look:* the Health colors
   dropdown closes when such an update arrives while it is open; say
   whether that is a nuisance in a busy hour or a PvP countdown.
7. **Icons:** faction, class and race icons (the picked set A) with the
   word as tooltip; the web client shows the star glyph and the race
   icons.

**Map**

8. **Z at 1920×1080:** the window takes about 90 % of the screen; one
   control row: the zoom (−, 1x, +) left, the eight layer buttons over the
   map, the location line and "Show minimap" over the quest column; the
   map about 838 px; about eight quest rows with both headings; no empty
   bands beside the map.
9. **Other screens:** at 1280×720, at 1035×696 and on a phone (2400×1080
   at density 2.5) the layer buttons take a row of their own; on the
   phone the window is 90 % wide and shows about one quest row (as
   0.66.1). At 2560×1440 and 4K the map grows (1118 and 1677 px).
   Labels fit, nothing is clipped. *Look:* above 1620 px the text grows
   by the old rule while the window grows more, so it looks smaller
   relative to the window.
10. **Layer buttons:** the active one is underlined, none while a quest is
    selected; a click switches the layer and clears the quest selection.
11. **Markers:** about two thirds of their old size (21 px at 1920×1080,
    19 px on the phone, **12 px at 1280×720**: still readable?), never
    shifted, in the map window and on the minimap; neighbours may overlap;
    a quest "?" over a "!" over a silver one; the player and party arrows
    (32 px) at their true place and on top.
12. **In a moving party** the arrows follow about every second (was 2 s)
    and the buttons stay usable (a click may wait up to a second). Each
    send is about 41 KB on the Quests layer, so an open map in a moving
    party costs about 40–60 KB/s, twice 0.66's; say if the web client
    shows it.
13. **Quest order:** one line per quest with `[Lv N]` in the difficulty
    colour, Story then Side, each by quest level; the row tooltip names
    the full title and the state. The quest boxes on screen follow the
    same order (story first, no headings), as Help now says.

**World**

14. **Flyer summon** (Expert or Master flying mount): in a cave room it
    works; in a 1-wide tunnel or a doorway, underground or on the surface,
    "There is not enough room here for a flying mount." (a horse comes
    there); beside a slab, a stair's lower step or snow it works. In a
    2-wide tunnel only with the player near the seam of the two columns
    (backlog).
15. **No-fly zones** refuse below enemy territory as on its surface. Jump
    and sneak on a flyer climb and sink as fast as forward flight.
16. **Nametags:** no name over plain townsfolk; trainers, vendors, the
    innkeeper, quest givers (with their "!") and guards keep theirs.
    Rabbits, birds and bats carry none; pointing at one still fills the
    target frame.
17. **Caves:** spiders and giant rats appear only in wider caves, never
    half inside a wall; elite and rare ones not in the rock. *Look:*
    underground Giant Spiders and Giant Rats became rarer (about a tenth
    of the floor spots at the measured cave); the user accepted that for
    the first look.

**Crafting**

18. **Creative tabs:** a creative player sees the category row only on the
    Creative pages; every other tab and the map window keep the one-row
    header.
19. **Variants:** in Basic, search "brown" holding Red and Green Dye: one
    row, opening on "Recipe 2/2"; ◀ and ▶ switch and wrap; the star is
    gold on both variants. "Craftable only": the row counts its shown
    variant (never ×0 while one variant is craftable); a chosen variant
    that cannot be crafted leaves the filtered list.
20. **Craft box:** "Craft" and "Queue" without a count; "×4 per craft"
    beside planks, nothing for a furnace; a typed quantity is used;
    "Details" with the help icon left of the star opens the details page.
21. **Removed recipes:** digging a bush stem gives one plank; no stairs or
    slab turns back into a block; no metal rod anywhere; one recipe for
    each sword, dagger and greataxe. A favourite set on a rod weapon in
    0.66 shows on the weapon.
22. **Help → Materials:** search (for example "iron bar": one hit with its
    furnace and drop lines), page, choose (the text scrolls), ×.
23. **Fuel:** one coal smelts four bars (40 s), anthracite burns 60 s.
24. **The migration** on a copy of a 0.66 world: rods in bags, crafting
    jobs, the Claim Stone's belongings and letters are bars (two rods, one
    bar, rounded up); a rod in a chest on the map is an unknown item.

**Containers**

25. **Sort** on every chest tier orders like the inventory's Sort; a second
    click within 2.5 s is ignored; no Sort on shelves; on a locked chest
    only for its owner.
26. **Label:** anyone in the open world; in the own claim; in a foreign
    claim with the "Everything" right yes, with Interact only no (the label
    shows as text); in a draft claim yes; on a locked chest only the
    owner. Pointing at the chest shows the label above its name. Typing
    "E" in the field does not close the form. A wide 40-character label
    shown as text may run under the Sort button.
27. **Upgrade** an open chest while a second player views it: both forms
    grow, the lid closes on the new tier, contents and label stay, 8 bars
    are taken; without the bars a refusal line; a repeated click charges
    nothing. The second viewer's unsaved label text resets when the
    upgrade re-shows the form.
28. **Scrolling:** a 96-slot chest scrolls; drag and drop and shift-click
    work both ways; Sort, label and Upgrade keep the scroll position.
29. **Shelves and art:** an old 16-slot bookshelf or vessels shelf shows 32
    slots when opened, its items kept. The Steel-Reinforced and Abyssal
    textures (set A) on the chest (the open lid's inside too), the locked
    chest, the bookshelf and the vessels shelf; a dug container drops its
    own tier.

## 7. Orchestration notes

- **Start state:** main `0ff50ed1` (0.66.1 plus the BACKLOG note, not
  pushed). The joint GUI test of 0.57–0.66 is pending and independent of
  this round.
- **Routing:** the user decides per session. Latest routing: Claude
  coordinates, Opus implements and reviews, GPT-6 Astra the art lane. Every
  lane gets an independent review.
- **Process budget:** at most eight Lua processes through the shared queue;
  no wall-clock kills.
- **Expected classification: migrate.**
  - The metal rods are removed items, so they need a declared step (CRAFT)
    with its test, run with every declared step in the `debian:trixie`
    container.
  - The shelf growth is lazy and lossless, so it is compatible.
  - The bush stems stay registered.
  - Any lane that finds otherwise reports before building.
- **Shared files:**
  - the recipe catalog: `tools/r45_rg/edits.lua`, the generated
    `basic_recipes.lua` and `grug_jobs/registry.lua` (CRAFT, CONTAINERS;
    resolved by regenerating);
  - `mods/BASE/default/nodes.lua` and `VENDOR.md` (CRAFT's stem drop,
    CONTAINERS' bookshelf);
  - `mods/CORE/grug_core/ui_rows.lua` (MAP's compact rows, additive);
  - `mods/PLAYER/grug_map/window.lua` (MAP; CRAFT's `navigation_layout`
    call);
  - `mods/PLAYER/grug_inventory/help.lua` (CRAFT, SOCIAL);
  - `mods/PLAYER/grug_inventory/navigation.lua` (CRAFT; SOCIAL's tab name
    and icon);
  - `mods/ENTITIES/grug_traders/prices.lua` (CRAFT, CONTAINERS if a price
    is added).

  Merge order per §1.
- **Lane D:** the version is already set by CRAFT; D writes the completion
  section,
  STATUS, the AGENTS pointer, BACKLOG, README, CHANGELOG.
- **Decided during the round:** the user's art pick, and the coordinator
  defaults of §2 after the first in-game look.

## Completion (2026-10-30)

All six lanes are merged on main. MAP, WORLD, SOCIAL, CRAFT and CONTAINERS
were each reviewed independently (Opus): MAP MERGE (two Low findings: the
phone width, fixed by the lane; the Help line, fixed by this lane D); WORLD,
SOCIAL, CRAFT and CONTAINERS MERGE AFTER FIXES, each with one fix round and
a delta review MERGE. The art study ART (tools only) was checked by the
coordinator (`generate.py --check`); its picked files were copied into
SOCIAL and CONTAINERS, whose reviews checked them byte for byte. This lane
D (the completion, the GUI checklist, the status owners and the Help line)
follows on main `b1f6314e`. **0.67.0 is migrate:** CRAFT's step 0.67.0
(`tools/migration/steps/v0_67_0.py`) refunds the metal rods as bars
(ceil(N / 2) of their metal) in every character's inventory lists (offline
characters, bags and overflow included), the `consumed` stacks of the
running and waiting craft jobs, `grug_housing`'s `recovered:*` and
`packed:*` entries and `grug_mail`'s attachments; rods in chests on the map
stay unknown items (accepted: a step never reads the map). Every other
lane is compatible: MAP and ART write no saved state; WORLD adds the mob
field `_grug_visual_scale` (missing on old mobs: the tier's scale); SOCIAL
adds the player meta `grug_parties:favorites` (missing: no favourites);
CONTAINERS adds the node meta `grug_label` and grows shelves from 16 to
32 slots lazily when opened (never shrinking); the bush stems stay
registered. No map reset. **Push:** not pushed; production is still
0.55.1; origin/main is `7a68e871` (0.65.0 and its status note). **GUI
test:** pending; it joins the joint GUI test of 0.57–0.66
([checklist](#gui-checklist-desktop-and-web)). **Sync:** by the
coordinator after each merge.

### Lanes

Main's first-parent commits from the plan `9fcf8093` (lane tip in
brackets), in merge order:

| Lane | Commit | What | Review |
|---|---|---|---|
| MAP | `adffe004` (`53272fb9`; `558b98f5`, follow-up `c4ba9865`) | `grug_map/window.lua`: the window sized from the client's own window report at 90 % (not the capped viewport), the 9:8 map as high as the window allows and at most 62 % of the width, the quest column the rest (at least 6.5 units); one control row (zoom, the eight flat layer buttons Quests, Bosses, Services, Travel, Places, PvP, Zones, None, the location line), the buttons on a row of their own where each would be narrower than `W.button_min`; the dropdown gone (the handler fields `grug_map_layer_<id>` kept); `PARTY_US` 2 → 1 s. `markers.lua` `SIZE` 32 → 21, `MIN` 16 → 11, `ARROW` 32, `rank` for the draw order; the displacement solve, the offsets and their caches and `providers.quest_slots` removed (map window and minimap; `icon_layout.lua` keeps the tooltip geometry). `grug_core.ui.rows` gains a `compact` option (other rows byte-identical); `grug_quests.sort_quests` (story, level, title, id) orders the quest list and the HUD. `world_map.md`, `quests.md`, `ui-presentation.md`; fixture `tools/r67_map` (and `bytes.lua`, a capture); `r35_f`, `r44_mq`, `r64_map`, `r66_map`, `r26_map`, `r27_minimap` follow | MERGE (Low: the phone at 73 % width, fixed in `53272fb9`; Low: the Help line, fixed here) |
| WORLD | `bf0ecde0` (`e2335627`; `2a087b9a` … `2ead589f`) | `grug_mobs/room.lua`: one collision-box test (real node boxes, boxes up to 0.5 above the feet are footing, unknown or unloaded counts as solid) used for the spawn of mobs wider than one node (`mobs:spawn_abm_check`), the elite and rare scale (kept at the current size when the scaled body has no room; the feet kept, so scaled spiders no longer sink) and the stuck cleanup (a mob that gives up stuck is removed once no player is within 32 nodes). `grug_mobs.wants_nametag`: none for `critter` and the roles `idle` and `work`. `grug_mounts`: the underground refusal gone, a flyer needs room for its body (the bottom clamped to the feet after the review), `vertical_speed` per tier (8 and 12, defaulting to the horizontal speed). `mounts.md`, `settlements.md`, `biomes_mobs.md`, `combat_stats.md`, `module-guide.md`; fixture `tools/r67_world`, engine probe `tools/r67_world/run.sh` | MERGE AFTER FIXES (Minor: the flyer refused beside a slab or a stair's lower step); fix `e2335627`, delta review MERGE |
| SOCIAL | `a7a0f162` (`7230cc48`; `04056c40` … `04908762`, follow-ups `c52f9748`) | The Social tab (`grug_parties/ui.lua` rewritten): the settings row, one party box (pending invitations with the count heading, or "Current Party"), the PvP section below, Online Players at full height (rows 0.54 units, faction, name, class, race, level, the star and Invite by player name); the roster event, `can_invite`, `newest_invitation`, `is_online`; refresh only for viewers on the Social page, at most one send per 2 s, held 0.5 s after a scroll; a forming party clears both players' incoming invitations, a joining member's and a demoted leader's sent ones (`clear_sent`); expiry and decline tell the inviter; the switches Party HUD and Health colours raise the local reason `"display"`. `hud.lua`: the invitation box at the party anchor (`hud_layout.invite_box`), polled by the existing 0.5 s HUD poll. `grug_pvp/page.lua` sends through `social_resend` (the 2 s limiter). Race icons `grug_classes/textures/grug_race_*.png` (set A) and `status_icons.race_icon`. `parties.md`, `pvp.md`, `inventory_equipment.md`, `mod-map.md`, `module-guide.md`; fixture `tools/r67_social`; nine fixtures follow the rename and the page | MERGE AFTER FIXES (Minor: a decline did not tell the inviter; the coordinator added the demoted leader's invitations, the local display switches and old comments); fix `7230cc48`, delta review MERGE |
| CRAFT | `502f3ef0` (`e19c94ee`; `b023a553` … `9265bfb1`, `7d5366bf`, fixes `4f719301`, `576c98ca`, main merged in) | `navigation_layout(..., selected)`: the Creative row only on `creative:*` pages. One row per output with "Recipe i/n ◀ ▶" (opens on the first craftable variant; favourites by output, old recipe ids read as their output). Removed through `tools/r45_rg/edits.lua` and the generator: 56 stairs and slab back-routes, the 3 stem recipes (the stems drop one plank, `GRUG PATCH` in `default/nodes.lua`), the six metal rods with their 6 recipes, 18 weapon variants and price groups. Plain "Craft"/"Queue", the muted "×N per craft", "Details" with the tinted help icon left of the star; "Craftable only" follows the shown variant. Help → Materials (`grug_jobs.source_lines` behind a search). `FURNACE_FUELS` coal and charcoal 40 s, anthracite 60 s. Step `v0_67_0`, `migrations.lua`, `game.conf` 0.67.0, `upgrade.json` migrate. `items_crafting.md`, `inventory_equipment.md`, `professions.md`, `economy.md`, `ui-presentation.md`, `upgrade-contract.md`, `module-guide.md`; fixture `tools/r67_craft` and the step test `tools/r67_craft/run.sh` | MERGE AFTER FIXES (Medium: `r53_ms/e2e.py` pinned 0.53.0 as the last step; Low: favourites of removed recipe ids; the coordinator added "Craftable only" ×0 and a game reference in `items_crafting.md`); fixes `4f719301`, `576c98ca`, delta review MERGE |
| CONTAINERS | `3e8f90c1` (`b7a8cbe0`; `357af854` … `f1517a19`, fix `b6485df8`, main merged in `50dd4e7b`) | New vendored `default/containers.lua`: twelve tier nodes (chest, locked chest, bookshelf, vessels shelf × base, Steel-Reinforced, Abyssal; open chests' `_open` nodes too) with 32 / 64 / 96 slots, direct recipes (+8 Steel Bars, +8 Abyssal Steel Bars; locked: +1 Iron Bar), drops by tier; the label (`grug_label`, 40 characters, rights by `core.is_protected`, the owner on locked chests; hover "label\nname"); Sort through `grug_inventory.sort_slots` / `sort_list` (the player's sort byte-identical); Upgrade (8 bars, `swap_node`, `set_size`, viewers retargeted, the field naming the target tier); 4 rows of 8 in a scroll container (`grug_inventory/ui.lua` `station_list`) with the scroll kept across a resend; shelves grow 16 → 32 when opened. Sixteen tier textures (set A) with licence rows; VENDOR.md; `inventory_equipment.md`, `housing.md`, `ui-presentation.md`; fixture `tools/r67_containers` and an engine probe | MERGE AFTER FIXES (Medium: a repeated Upgrade submit charged the next tier); fix `b6485df8`, delta review MERGE |
| ART | `b1f6314e` (`2f580376`; `5e3f7633` … `29c3da35`) | GPT-6 Astra's study in `tools/r67_art/`: 44 candidates (six race icons A/B at 64 px, the Steel-Reinforced and Abyssal textures A/B, eight per tier and variant), generator, offline preview, licence rows, `REPORT.md`; the user's pick recorded | coordinator check (`generate.py --check`, 134 files) |
| D | this section | the completion, the GUI checklist, the Help line, STATUS, AGENTS, BACKLOG, README, CHANGELOG (the version and declaration were set by CRAFT) | independent review |

Main has **297** portable fixtures (5 new: `r67_map`, `r67_world`,
`r67_social`, `r67_craft`, `r67_containers`; 0.66.1 added `r661_perf`).
`mods/` against the plan commit (measured, `git diff 9fcf8093 b1f6314e --
mods`): 75 files, +2594 −936 lines: 50 Lua files (six of them vendored),
22 PNGs (six race icons, sixteen tier textures) and three media ledgers.

### Decisions during the round

**The user:**

- Before the start (2026-10-30): Q1 one party box without sub-tabs
  (ruling 4), Q2 the PvP section under the party box on the left (ruling
  4a), Q3 (a) the Story and Side groups stay, each by level, and the quest
  HUD story first too (rulings 19 and 19a).
- **Art pick:** race icons **A** (coloured frontal heads), Steel-Reinforced
  **A** and Abyssal **A** (strapped wood for both tiers; Astra had
  recommended Abyssal B, the plated case).
- **WORLD Q1:** underground Giant Spider and Giant Rat spawns drop to about
  a tenth of the floor spots; accepted as proposed, to look at first and
  tune later.

**The coordinator** (answers to lane questions and reviews; each built as
stated):

- **MAP:** one control row with the layer buttons beside the zoom (their
  own row where too narrow); the spare width at 1× goes to the quest
  column; the list shows at least eight rows at 1080p; arrows stay 32 px;
  text keeps today's growth rule; the scrollbars at 1× stay (the
  horizontal one holds the focus that lets "i" close the window); the
  party check at 1 s, with the bytes note (checklist item 12).
- **WORLD:** its own `room.lua` box test instead of `mobs:can_spawn` (see
  the deviations); the stuck cleanup's watch range 32 nodes; a stuck mob
  still heals on giving up while a player watches (today's behaviour).
- **CRAFT:** Details uses the shipped `grug_ui_icon_help.png` tinted in the
  accent colour; Materials lists every item with a source (806); the
  variant switch lists the variants the list shows.
- **SOCIAL:** players in character creation are listed last; the box shows
  the newest invitation; a joining member's sent invitations are cleared;
  the PvP countdown goes through the 2 s limiter.
- **CONTAINERS:** the base names stay "Chest" and "Locked Chest" (no
  "Wooden" prefix; Help and the design doc say "base tier").

### Deviations from the plan

- **Merge order:** MAP before WORLD and SOCIAL before CRAFT (plan: WORLD,
  MAP, CRAFT, SOCIAL); the files were independent, CRAFT merged main
  before its merge.
- **WORLD's spawn check** is its own collision-box test, not
  `mobs:can_spawn`: for even widths (bear 1.4, rat 1.28) `can_spawn` tests
  an offset centre that a wrapper cannot move the spawn to, so it would
  test the wrong columns; one geometry now serves spawn, scale and stuck.
  The review accepted it with the engine evidence.
- **"Expiry raises no event"** (§2, invitation box): refuted by SOCIAL;
  the 1 s prune pass emits `"invitation"` to the recipient. The box needs
  no own timer (the existing 0.5 s HUD poll); the inviter is now told too.
- **CONTAINERS' pinned sizes:** `recovered.lua` and the `r50_pgame` probe
  read `CONTAINER_LISTS` and pin no sizes; refuted, unchanged.
- **The Help line** on the quest HUD order (MAP review) was fixed by this
  lane, not at the merge.

### Numbers worth keeping

From the lanes' reports (measured there unless marked).

- **MAP, window, map and markers** (px; v0.66.1 → 0.67.0):

  | Profile | Window | Map | Markers | Quest rows (both headings) |
  |---|---|---|---|---|
  | 1280×720 | 1081×607 → 1144×643 | 496 → 498 | 21 → 12 | 4 |
  | 1920×1080 | 1631×918 → 1728×972 | 762 → 838 | 32 → 21 | 8 |
  | 2560×1440 | 1631×918 → 2304×1296 | 762 → 1118 | 32 → 21 | 8 |
  | 3840×2160 | 2175×1224 → 3456×1944 | 1016 → 1677 | 32 → 21 | 8 |
  | phone 2400×1080 × 2.5 | 1728×1080 → 2160×1080 | 783 → 753 | 33 → 19 | 1 |

  Bytes per send with a party of five (fixture): no layer or Quests 10.5 →
  12.4 KB, Trainers 19.1 → 17.6 KB, Towns 20.7 → 18.6 KB. The engine logs
  41 KB per send on the Quests layer (61 markers, 335 tooltips) and 58 KB
  on Travel; the party check at 1 s doubles the sends of an open map in a
  moving party (up to 60 a minute).
- **WORLD** (seed 42, a cave at −400, −2550, y −112 to −49): floor spots
  for Giant Spider and Giant Rat 2683 by the one-column check → 281 with
  room (10.5 %), Spiderling 2683 → 2683; two 60 s windows: 7 wide spawns
  (2 stuck 3 s later) → 0; the stuck cleanup 2 flagged, 2 removed.
  Nametag carriers: 1124 fewer over the 144 settlements (Highcourt alone
  165); 0 of the 1124 idle or work sockets holds a quest giver.
- **SOCIAL, tab body without the PvP section** (fixture): 1 / 10 / 50
  players 1,998 / 6,749 / 27,988 bytes; the full page with 33 rows in the
  engine 22,295 bytes (50 rows about 32 kB, estimated). The same four
  players: 5,281 → 6,461 bytes out of a party, 5,635 → 6,789 in one. No
  new globalstep.
- **CRAFT:** recipe records 676 → 593 (the catalog's rows 237 after
  CONTAINERS); outputs keeping several recipes: seven dyes (2 or 3 each),
  glass fragments 2. Materials: 806 items; "iron bar" 1 hit, "planks" 7,
  "dye" 15; the page 11,642 bytes (the list) and 8,794 (a material
  chosen). Every declared step's end-to-end test after the step:
  `r53_ms` 29/29, `r47_ms` 21/21, `r48_bags` 25/25, `r44_ms` 32/32 and
  `r45_ms` 64/64 (the last two after pins of later rounds' game behaviour
  were updated); `r67_craft/run.sh` unit 3/3 and end to end 23/23; the
  container test 38 OK.
- **CONTAINERS, chest form** (four 20-slot bags): 32 slots 2,762 → 3,715
  bytes, 64 slots 3,977, 96 slots 3,685 (no Upgrade row).

### Checks

- MAP: full run 291/293 before two pin fixes, both then PASS; smoke boot
  PASS; captures at 1920×1080. Review: 21 fixtures PASS.
- WORLD: full run 292 + 1 fixed (`r51_mobs`' stub); smoke boot and two
  probe runs PASS; fix round `r67_world` (86 checks), `r56_mount`,
  `r531_flight`. Review: eight fixtures PASS, a scratch harness on the real
  `room.lua`.
- SOCIAL: full run 293/0; two smoke boots and a capture boot. Fix round:
  `r67_social` (97 checks) and five fixtures. Review: six fixtures PASS.
- CRAFT: after the main merge, full run 295/296 (only `r37_dc`, waiting
  for this CHANGELOG entry); `check_upgrade.py`, `gen_basic_recipes.lua
  --check`, `income.py --check` PASS; smoke boot PASS. Review: nine
  fixtures PASS.
- CONTAINERS: after the main merge, full run 296/297 (only `r37_dc`);
  smoke boot with the probe PASS (39 checks). Review: eight fixtures PASS.
- Main: `check_fresh_server.py` PASS after each merge. This lane:
  `check_upgrade.py`, `check_fresh_server.py`; `r37_dc` (the CHANGELOG's
  newest entry, the Help version line), `r41_up`, `r42_dr` and `r43_gs`
  (the declaration, the README and CHANGELOG links); the Help fixtures for
  the changed line; the link and anchor check of the touched documents;
  the full run once.
