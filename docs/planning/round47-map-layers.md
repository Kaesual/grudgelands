# Work package draft — map window marker layers

Status: **scheduled as Round 47 lane ML** (the user, 2026-10-13). Rulings
in §2 are the user's (chat of 2026-10-13); §8 lists the defaults the draft
chose, which the lane builds unless the user overrides them after the
screenshots.

## 1. Goals and reasons

**Why.** Round 44 baked the settlement, point-of-interest, king and dragon
icons into the map image and cut the live overlay down to a fixed set, mainly
to keep the window's formspec small: every live marker, and every tooltip,
is bytes in every send. Players report that the result neither works nor
looks good: 124 icons sit in the image at once (seed 42, 58 overlapping
pairs at `normal`), they have no names, they cannot be hovered, and the
map is hard to read under them.

**What we want instead.**

- A clean base: terrain, roads, region names, the player and the party.
  Everything else comes from the one chosen layer.
- Information on demand: the player picks **one** marker layer at a time
  (or a quest), so the map never shows everything together.
- Every marker named: with one layer at a time, tooltips on all markers are
  affordable again.
- The party readable: party arrows with their names, refreshed more often.

**Why this keeps the data cost in check.** The cost is per send, not per
world: one layer of 20–80 markers with tooltips is roughly 3–10 KB on top
of the window's ~5 KB today, still well below the old Map tab's 34 KB that
Round 44 replaced. Showing every layer together would be cheap enough too;
the one-layer rule exists mainly for readability.

## 2. Rulings (user, 2026-10-13)

1. **Layers, one at a time.** A row of buttons under the map selects the
   layer; at most one is active. Wrap to a second row when one row does not
   fit. Buttons, not a dropdown (see §6.2 for why).
2. **Quest selection is its own mode.** Selecting a quest in the quest list
   shows only that quest's targets and its hand-in NPC; no layer button is
   highlighted then. Pressing any layer button **deselects the quest** (the
   list goes back to no selection, the text box to its "select a quest"
   hint) and shows that layer.
3. **Always visible, in every mode:** the player's arrow and the party
   members' arrows, the party arrows with the member's name as tooltip.
4. **Baked icons leave the world map image.** Region names stay baked, at
   today's scale (smaller names at higher zoom would need an image per zoom
   level, see §5; not wanted). The **minimap keeps its baked icons and its
   markers** unchanged.
5. **Settlement and point-of-interest layers show both factions.** NPC
   layers (quest givers, trainers, services, innkeepers) stay own-faction
   only (ruling 13 of Round 31 holds).
6. **Every marker gets a tooltip** (name, plus a useful detail where there
   is one), the quest targets included (§3).
7. **Zone names as text** in their own layer, with a translucent box behind
   each name; if it looks bad the user decides a change after seeing it.
8. **Party refresh every 2 s** (`PARTY_US` 5 s → 2 s); a send still goes
   out only when an arrow moved to another cell.
9. **Quest text scroll reset is accepted** (§6.1), plus a count of how many
   quest texts scroll at all (report only).
10. Other window elements (header row, quest column) keep their size and
    place.

## 3. The layers

Button labels are short; the button's tooltip carries the long name.
Default at the first opening: **Quests**. The chosen layer is kept between
openings until the player leaves (window session); whether to persist it
in player meta is an open point (§8).

| Button | Long name | Content | Factions | Tooltip |
|---|---|---|---|---|
| Quests | Quest givers | "!" available, "?" silver active, "?" gold ready (`grug_quests.marker_states`, the `quest` provider; the minimap's precedence) | own | NPC name |
| Bosses | Kings & bosses | 6 kings, 2 dragons, the rift boss at his clash site, rare dens | both | name (+ level where the data has one) |
| Trainers | Trainers & traders | profession trainers, Riding trainer, mender, Crownbinder, Decor Merchant, Housing Steward | own | NPC title |
| Towns | Settlements & travel | starts, capitals, villages, outposts (both factions, `display_name`); own innkeepers, home, Claim Stone, discovered waystones | both / own for NPCs and travel | settlement name; "… Innkeeper", "Your home", "… Waystone" |
| POIs | Points of interest | bandit and Mirefolk camps, mines and gem camps, clash sites | both | kind + name where there is one |
| PvP | PvP | the two fortresses, the war camps | both | name |
| Zones | Zones | zone names as text, level band as second line, box behind | — | — (text is the label) |
| None | No markers | only the arrows | — | — |

Notes:

- A dragon arena and its dragon stay one icon (today's `SAME_PLACE` rule
  in `bake.lua`), in **Bosses**.
- A king stands about 32 nodes from his capital's anchor: in different
  layers now, so no overlap.
- Generals and captains (49 leaders on seed 42) stay unmarked outside a
  selected quest's crosshairs.
- Markers are not clustered or moved apart (as today); playtest decides.
- **Quest mode** (a quest selected): today's targets (rings, crosshairs,
  `targets.lua`) plus the quest's hand-in NPC (`turnin_npc`, the
  question mark of today's `quest_marks` for that one quest), with the
  NPC's name as tooltip. Rings and crosshairs get the objective's line as
  tooltip ("Defeat Barrow Piglet: 0/8"); two objectives on one crosshair
  share it, one line each.
- **The selected quest leaves the log** (handed in, abandoned): the map
  falls back to the last chosen layer.
- Track on HUD and Abandon act on the selected quest; after a layer click
  deselected it they behave as with no selection today.

## 4. Behaviour

- **Buttons:** under the horizontal scrollbar, left-aligned with the map,
  as wide as the map; the active one visibly highlighted (`style[]`). One
  row if all fit at a sensible minimum width, else two rows. In quest mode
  none is highlighted.
- **Layout:** the layout reserves the button rows below the map. Where the
  window has spare height (e.g. the user's 1035×696 client, roughly 1.8
  units free under the map, estimated from a screenshot) the map keeps its
  size; at 16:9 full screen
  (1920×1080, 1280×720) the map is height-bound today and becomes one or
  two rows shorter (one row ≈ 0.75 units ≈ 7 %). The quest column and the
  header stay as they are.
- **Tooltips:** positional `tooltip[x,y;w,h;…]` as today. The client shows
  the **first** matching rect (`guiFormSpecMenu.cpp` ~3673), so tooltips
  are emitted in reverse draw order (topmost marker first). Positional
  tooltips have no hover delay and are re-evaluated every frame, so a
  resend does not hide them.
- **Icons:** the baked 16 px art (`grug_map/art/baked_*.png`, not the
  `_mini` ones) becomes overlay textures (`grug_map_<kind>.png` in
  `textures/`, licence lines in `LICENSE-media.md` follow). Constant size
  in formspec units like the other overlay icons; the lane picks the size
  (today 0.34 icons, trainers 0.23 at 1x/2x).
- **Arrows:** unchanged (gold own, cyan party, on the `ARROW_STEP` grid);
  party arrows get a name tooltip.
- **Refresh:** `PARTY_US` 2 s; the rest of the refresh rule (event-driven,
  `SEND_GAP_US`, `QUIET_US`, per-pass caps) unchanged. A layer click is an
  event like a zoom click.
- **Zones layer:** one `label[]` per zone at a placement point plus a
  translucent `box[]` behind it; name on line 1, level band on line 2.
  Text has a constant size at every zoom (at 1x small zones may collide;
  report how many). Placement: Round 28 M1 had one marker per zone at its
  pole of inaccessibility on a 32-node grid, nudged clear of other markers
  and the region names (commit `42c1f418`, removed in Round 44) — reuse
  that, keeping clear of the baked region names (`bake.lua`
  `REGION_LABELS` carries their clearance boxes).

## 5. Baked layer change

- `normal` and `high` world map images: no icons, region names stay.
- Minimap image (`mini`): unchanged, icons stay.
- The cache key already covers `bake.lua`, so every world re-renders its
  map at the next start; no migration. (Release mode: only the user's one
  production world; a re-render is fine.)
- RAM note (for the record, no action): all zoom levels draw the same
  client texture. Only with the client setting `gui_scaling_filter` (off by
  default) does the client cache a scaled copy per drawn size
  (`guiscalingfilter.cpp` 64–134), which at 8x is a very large texture.
  Existing behaviour, not changed by this package.

## 6. Known limits

1. **Quest text jumps to the top on a resend.** The read-only `textarea`
   is recreated on every send (`guiFormSpecMenu.cpp` ~1540); the quest
   list keeps its scroll (`table_dyndata`). With 2 s party refresh a long
   quest text scrolled down jumps back up while a party member walks.
   Accepted (ruling 9); the lane reports how many quest texts overflow the
   text box at 1920×1080 and 1280×720 (an estimate is enough).
2. **Why not a dropdown:** a resend recreates the dropdown and closes an
   open list (`regenerateGui` clears `m_dropdowns`; opening it sends no
   event, so the server cannot hold the send). In a moving party that
   would close the list mid-choice.

## 7. Scope for the lane

Files (expected):

- `grug_map/window.lua` — layer state, buttons, layout, overlay per layer,
  tooltips, quest mode, `PARTY_US`.
- `grug_map/providers.lua` — new providers for settlements, bosses, camps
  and places, PvP, zones (or a separate module); existing providers reused.
- `grug_map/bake.lua`, `grug_map/base.lua` — no icons in the world map
  variants; minimap variant unchanged.
- `grug_map/settlement_icons.lua` — reuse the slot → kind mapping for the
  layer assignment.
- `grug_map/textures/`, `grug_map/LICENSE-media.md` — the overlay icons.
- `grug_map/quest_box.lua` — deselection on a layer click.
- Zone placement: its own small module (pure where possible).
- `docs/design/world_map.md` — Live markers, Map window, Baked layer,
  Refresh; the Round 44 sentences "No search, list, legend or filters",
  "No exclamation marks and no zone markers", "the arrows carry no names
  or tooltips", "the NPC's name as tooltip, the only tooltips of the map"
  and the ruling-12 overlay list are replaced; the party check interval
  (5 s) and the Round 44 byte and send comparisons are updated; ruling 5 (everything baked for everyone) becomes "the
  settlement and place layers show both factions".

Conflict check (2026-10-13): no running Round 47 lane branch (an, art, cr,
fs, or, sw, ta, tb) changes `mods/PLAYER/grug_map/` or
`docs/design/world_map.md`; lane NZ (merged) touched `location*` and the
zone discovery only.

Proof (comparisons, not targets):

- Fixture: extend `tools/r44_mq/portable_test.lua` (or a new
  `tools/r4x_ml/`): layer switching, quest deselection on a layer click,
  quest mode content, one-layer-only, tooltip order, faction filtering
  (NPC layers own faction, settlement/place layers both), arrows in every
  mode. Run the own fixture and those that test the changed behaviour;
  one full run per lane.
- Engine probe (extend `tools/r44_mq/grug_probe_r44_mq`): seed 42, form
  bytes, image and tooltip counts **per layer** at 1x and 8x, and in quest
  mode; sends per minute alone and in a walking party at 2 s.
- Re-rendered base: icon count 0 in `normal`/`high`, names unchanged,
  minimap unchanged.
- Screenshots at the user's 1035×696 and at 1920×1080 (layout with one and
  two rows) for the user's look-and-feel check; the zone layer at 1x and
  4x.

## 8. Open points (defaults chosen, user may override)

- Layer memory: session only (default) or player meta.
- Quests layer: show locked quest givers as the minimap does (default) or
  hide them.
- Button order: as in the table (default).
- Icon size of the former baked icons: lane proposes, user picks after the
  screenshots.
- The player's own arrow: no tooltip (default) or "You".
- A **None** layer (only the arrows): included by default; drop it if the
  user does not want it.

**Decided (the user, 2026-10-13, after the lane's screenshots):** the
defaults above as built (layer memory session only, locked quest givers
shown, the table's button order, no tooltip on the own arrow, None
included); the former baked icons at 0.34 units; the rift boss keeps the
clash site's icon; the Zones layer shows name and level band on one line
("Dawnmere Fields 1–10") with a smaller, tighter box. The two-row
threshold (1.25 units per button) stays.
