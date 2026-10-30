# World atlas

Decided 2026-09-21; Round 14 user Go.

## Approved icon integration (Round 64)

User decisions, 2026-10-27; implemented in 0.64.0. Technical receipts and
the pending desktop/web GUI checklist: [Round 64](../planning/round64-plan.md).

- Use the accepted [icon set](../planning/map-icon-rework.html) on both
  world map and minimap, one 32x32 PNG per motif/direction. Preserve the
  intentional smaller motif fill of the innkeeper. One brown side-view
  horse replaces the six riding-trainer map motifs. Quest/profession icons
  have no surrounding circular/square badges. Post, music and daytime art
  stay as they are; the minimap bezel is retained.
- Ordinary icons have the same displayed size in both views, independent
  of world-map zoom. Shared UI scaling may change their common size.
  Geographic area rings retain their actual extent; exact positional
  targets and player/party arrows stay on their real anchors.
- Avoid overlaps of nontransparent icon pixels while allowing transparent
  areas to overlap. Initial maximum displacement is 16 display pixels at
  standard scale, scaled with the icons. Anchor proximity takes priority
  over complete separation: residual overlap in dense groups is accepted.
  Do not add automatic clusters or hide markers as an overlap remedy.
  **Superseded by Round 67** (rulings 20 and 21, 2026-10-30): no
  displacement at all; every marker sits at its anchor and overlaps are
  allowed (see [Markers at their anchors](#markers-at-their-anchors-round-67)).
- Both views use separate markers; the user accepted additional minimap
  position updates after the M0 memory comparison. Terrain resolution stays
  unchanged; no map icons are baked into terrain. Markers remain above flight,
  claim and other ground overlays. Keep personalized home/innkeeper,
  discovered-waystone, Claim Stone and quest-state behavior; player/party
  positions remain live. Preserve existing faction visibility and travel
  discovery rules.
- Cache layout per simultaneous marker group and projection/display scale;
  translating the view must not rearrange its icons. Both renderers
  use the computed positions and must preserve the common icon size and
  readable source art. Exact cache/render mechanics and measured costs
  belong to the implementation plan, not additional gameplay rules.
  (The layout and its cache left with Round 67.)

## Markers at their anchors (Round 67)

User rulings 20 and 21 of 2026-10-30 (the playtest of 2026-10-28: markers
moved for neighbours the player could not see), implemented in 0.67.0:

- Markers are about two thirds of their Round 64 size (21 px at the
  reference instead of 32, the floor 11 px instead of 16; the size rule of
  Round 66 is unchanged) and overlaps are allowed: the displacement solve,
  its reserved quest-giver slots and its cache are gone, in the map window
  and on the minimap.
- Markers draw by importance, bottom to top (the minimap's layers of
  before, extended by the quest states): places, bosses, trainers and
  innkeepers, then the Steward and the services, the home and waystones,
  then quest givers by their state (a silver "!" of a quest in one or two levels lowest, then in
  progress, available, ready; a story marker above the plain one of its
  status) (`grug_map/markers.lua` `rank`; the minimap's z-index and the map
  window's draw order). The map window keeps the baked layer's order for
  the place kinds below that.
- The player's and the party's arrows always stand at their true position
  and on top of every marker; they keep their 32 px at the reference and
  scale with the markers.

## Atlas behavior

- A cartographic atlas of the authored world: coasts/regions, roads, zone
  names, settlements and player position. Since Round 44 it is its own
  window, opened by Z and by the Map tab, with the quest log beside it
  ([Map window](#map-window)); until then it was the Map inventory tab.
- No fog of war and no per-character terrain discovery mask. The atlas does not
  require full-world generation and does not render actual player-built terrain.
- Use existing world authority and stable anchors. The whole-world atlas uses
  zoom and scrolling without adding travel or visit objectives.
- **Round 22 (2026-09-25):** coast, zone borders and roads differ per world
  seed, so the map base can no longer ship as a pre-rendered PNG. The server
  renders it once for its own world at first start from the world authority
  (coarse sampling, `core.encode_png`), caches it in the world directory and
  sends it to clients as dynamic media. Markers stay separate as before.
  The base shows land/water, zone areas in race-region colours with borders
  and a hillshade (stronger relief since Round 27, below); roads join it in
  Phase 4. Since Round 51 the sea is coloured by depth ("Sea" in
  [Map quality and relief](#map-quality-and-relief)).
  Lakes show as water pixels; rivers (about 7.5–30 nodes of water
  width, `terrain_data.lua`) are stroked from the water layout's centrelines
  onto land at about their water width at the image scale, at least three
  pixels wide from 18 nodes (`grug_map/base.lua` `RIVER_WIDE`; Map quality
  and relief below). The cache key includes the
  water layout, so a changed layout re-renders the base. The relief samples
  terrain height on one fixed grid per map quality on every server (D29: no
  time budget, hardware never changes the image); the render is paid once per
  world at first start, then the cached image is reused (sizes and times
  below). Since Round 44 the region names are baked into it, and until
  Round 47 the settlement, point-of-interest and boss icons were too
  ([Baked layer](#baked-layer)); Round 64 also removes them from the minimap. No
  pre-rendered atlas image ships.
- Separate the shared map base from marker records and world-to-screen mapping.
  Markers must remain extensible for hover tooltips and/or click actions. The
  world map's image carries only the region names; the places that are the
  same for every player (settlements, points of interest, kings, dragons)
  are markers of the map window's layers since Round 47 (baked into its
  image in Rounds 44–46) and separate minimap markers since Round 64.
- Map visibility never unlocks waypoint travel. Actual visit-unlock is the
  waystones' authority ([world.md](world.md) §6); a map marker grants no travel.
- Since Round 27 the same base image also feeds our own HUD minimap, which
  replaces Luanti's native minimap (see [Minimap](#minimap)). No client mods
  or native-minimap bitmap extraction are used.

## Live markers

Decided 2026-09-21: viewer position is a gold directional triangle; online
party members use cyan directional triangles. Offline members have no live
map position. The viewer draws above other markers. Since Round 47 the
party arrows carry the member's name as tooltip (the viewer's own arrow
none); markers take no clicks. Both arrows show in every layer and in
quest mode; when the world map sends them is the
[Map window](#map-window)'s refresh rule. Closed maps receive no formspec
refreshes.

Round 16 (approved 2026-09-22): authored quest givers have individual icon
markers with the same per-player ready/available/active/locked precedence as
world symbols (`locked`, the silver "!", means "next quest in one or two
levels" since Round 65). Since Round 47 the world map shows them in its Quests layer,
the same states as the minimap ([Map window](#map-window)); in Round 44–46
it showed only a question mark at the hand-in NPC of each active quest.
Include individual profession/Riding trainers at their
authored locations (since Round 44 one icon per profession,
`grug_map_trainer_<profession>.png` by GPT-6 Astra, replacing the book;
Riding uses the shared brown horse icon); the six kings and two dragons are markers of
the Bosses layer since Round 47 (baked in Rounds 44–46). The Housing Steward has its own
marker (kind `steward`, a cottage-and-key icon, Round 26 playtest), drawn above
trainers and innkeepers but below quest, party and player markers. The
capital services of Round 33 share that layer (kind `service`, Round 34): the
Crownbinder (a crown over an anvil) and the Decor Merchant (a lantern); since
Round 46 also Grudge-Free Repairs, the mender of every start town and capital
(a hammer over an anvil; the repairing profession trainers keep their own
icons). NPC markers do not query live
entities, load terrain, reveal health or indicate respawn state. NPC and
player tooltips contain only the name. Ordinary markers sit at their anchors
(Round 67; Round 64's bounded alpha-aware placement before), as do exact
targets and player/party arrows. No automatic clustering is used. Map markers confer no remote interaction or travel.

Round 31 (PvP ruling 13): **the NPC's faction decides who sees its
marker.** Each NPC marker carries its NPC's faction (the race's; a quest
giver's own race where it names one). A player sees only the own faction's
quest givers, trainers, Housing Stewards, Crownbinders, Decor Merchants,
menders and innkeepers; a character without a faction yet sees no NPC markers. Both
factions can have markers in one zone (a spy in a contested zone), each seen
only by its own side. The settlement, place and boss layers show both
factions (Round 47 ruling 5; in Rounds 44–46 everything was baked into the
image for everyone, Round 44 ruling 5), and the base and its roads stay
complete for everyone; since Round 44 the selected quest's own targets
show wherever they are.

Round 29 (WP17): every **discovered** waystone of the player's own network
(three starts, three capitals and, since Round 31, the faction's PvP
fortress; [world.md](world.md) §6) is a marker of kind
`waypoint` at the stone, labelled "<settlement> Waystone", with the icon
`grug_map_waypoint.png` (a grey standing stone with a blue rune, by GPT-6
Astra). Undiscovered and enemy waystones are not shown. The provider is
`waypoint` in `grug_map/providers.lua`, fed by `grug_home.known_waypoints`; a
marker never unlocks or starts travel. Since Round 45 (PT9) the owner's
activated Claim Stone is a `waypoint` marker "Your Claim Stone" in the
shared map-only claim icon (`grug_map_claim.png`;
`grug_home.claim_waypoint`), unless it is the travel home, which the home
marker already shows. A marker's own texture wins over its kind's on the
minimap.

## Innkeeper home travel

Round 17 adds the twelve innkeeper locations and the labels/current-home
distinction; since Round 31 a player's map shows the six of the own faction. The Return home button with destination and cooldown moved to
the Character page in Round 30 (user ruling, 2026-10-02: its live countdown
is cheap in that small form and no longer resends the Map tab). Its server
authority is [home_travel.md](home_travel.md). Map browsing itself grants no binding or
waypoint unlock; binding still requires visiting an eligible innkeeper.

## Atlas navigation

The single full-world view replaces regional cutouts. Each opening of the
map starts at 1x with origin scroll; no saved zoom/scroll preference. Zoom
+/- offers 1x, 2x, 4x and 8x (8x added after the Round 26 playtest for
precise navigation to NPCs; the base image is simply shown larger),
clamping at edges. The wanted centre of a zoom step follows a soft lock
(0.45.1, the user's decision of 2026-10-10): at every opening and again at
each return to 1x it is the player's own position, so every zoom step, in
and out, centres the map on the player as well as the edges allow
(recomputed each step, no drift); once the player moves a scrollbar at
2x–8x (dragging, the wheel, a click on the bar, also scrolling exactly
back; the engine reports only the player's own moves as `CHG`) it is the
current centre of the view, for zooming in and out alike, until the next
return to 1x. Native
horizontal/vertical scrollbars reach the complete map at enlarged zooms. No
drag-to-pan or animation. Never distort/crop the full overview: the map is
9:8 at every window size. Renderer and marker projection use the same world
bounds. Markers retain constant UI dimensions: only positions scale with
zoom; clipping and scroll translate image and markers together. No
clustered markers; ordinary icons sit at their anchors (Round 67). Native scrolling never sends the form; the
server keeps the scroll values from every event (read at the zoom of the
form they come from; ignored while the soft lock holds, when the server
owns the view) and echoes them on the next send, so a send does not move
the view. Arrows sit on a 0.02-unit
grid. Until Round 44 the Map tab shared the inventory window's size and
was rebuilt by a 2 s poll (Round 30, perf review #3; Round 32 R1); both
ended with the [Map window](#map-window).

## Map window

UI modernization (2026-10-25 fidelity pass, merged in 0.60.1): the following
size describes the whole window. The compact common inventory navigation
header is reserved inside that budget, and the map/quest body uses the
remaining height. The existing minimum-size floor may still require client
scaling at small window sizes. Navigation uses allowed sfinv pages and
keeps the existing map session; choosing another tab cancels pending map
sends before displaying it. Both Z and Map & Quests enter directly, without
an Open button. Native scrollbars and client-side scrolling are unchanged.

Round 44 (the UI rework spec, rulings 10, 12 and 14, §3.6; wireframe v1).

- **Opening:** Z (the zoom key; `grug_keys` reports its rising edge, and
  every player has `zoom_fov` 72, the client's default field of view, so
  the client no longer answers Z with "Zoom currently disabled" and at the
  default field of view a held Z changes nothing visibly) and the Map tab.
  The Map tab opens the window at once and puts the inventory back on its
  homepage on the next step, so the next "i" opens Inventory. Not during
  character creation or while dead. Esc, the inventory key ("i") or the X
  button closes the window; "Back to inventory" opens the inventory window
  at Inventory. A focused element that takes typed keys would swallow
  "i" (the engine focuses the first text box, read-only ones included, and
  a clicked list keeps the focus), so every send focuses the map's
  horizontal scrollbar (`set_focus[…;true]`; it keeps only the arrow keys,
  which scroll the map), and a click on the selected quest sends the
  window too. A click into the quest text keeps the focus there until the
  next send.
- **Size** (Round 67 ruling 18): 90 % of the client's own
  `max_formspec_size` in both directions, read when rendering, with
  `padding[0,0]`, on every resolution: the viewport ceiling of the other
  windows ([ui-presentation.md](../technical/ui-presentation.md)) does not
  apply to it (85 % of the capped viewport before). The shared navigation
  header is included in that height budget. Clients without window
  information use the fallback in `grug_map/window.lua`; a minimum body
  size (16 × 10 units) remains client-scalable. Text keeps the growth the
  ceiling rule gives it (`grug_core.ui.text_growth`), so on a screen above
  1620 px height it grows less than the window does.
- **Layout** (dialog review, 2026-10-25; Round 67): shared inventory
  navigation, then one row above the map: the zoom on the left, the eight
  layer buttons beside it over the map, the location line and the minimap
  switch over the quest column. Where the buttons there would be narrower
  than their text (about 68 screen pixels at GUI scale 1, growing with the
  GUI scaling and the text growth: 1280×720, small windows, the phone) they
  take a row of their own across the window under the zoom row, two rows of
  four where even that is too narrow. The map keeps its 9:8 aspect ratio
  and native scrollbars and is as large as the body's height allows, at
  most 62 % of the usable width; the quest column takes the rest, at least
  6.5 units (equal halves before Round 67), so no empty band stands beside
  a height-bound map. Zoom, minimap settings, quest selection and HUD
  controls keep their existing owners and field routes. The scrollbars stay
  at 1× too: the horizontal one holds the keyboard focus that lets the
  inventory key close the window (Opening).
- **Marker layers** (Round 47, the user's rulings of 2026-10-13, the
  [work package](../planning/round47-map-layers.md); until then Round 44's
  fixed overlay of ruling 12): the player picks **one** layer at a time
  with the buttons. Since Round 67 (ruling 22; a dropdown in the header
  from 0.63.0 to 0.66.1, Round 47's buttons under the map before) they are
  flat buttons above the map in the toolkit's navigation style (Layout);
  the active one is marked by the accent (its text and an
  edge under it), none in quest mode; each button's tooltip is its long
  name, its label the short one. A new session starts on Quests; the
  chosen layer is kept between openings until the player leaves (not
  stored). Buttons, not a dropdown: every send recreates a dropdown and
  closes an open list, and opening it sends no event the server could wait
  for.

  | Button | Long name | Content | Factions | Tooltip |
  |---|---|---|---|---|
  | Quests | Quest givers | every quest giver by its state, the minimap's set and precedence: gold "?" ready, "!" available, silver "?" active, silver "!" locked (next quest in one or two levels) | own | the NPC's name |
  | Bosses | Kings & bosses | the six kings, the two dragons (a dragon arena within 64 nodes of its dragon is one icon), the rift boss at his clash site (the clash icon), the rare dens | both | the name, with the level where the registry has a fixed one ("King of Highcourt (level 65)"); a den its name, "Rare den" and the level at its anchor |
  | Services | Trainers & traders | the profession and Riding trainers, the mender, the Crownbinder, the Decor Merchant, the Housing Steward | own | the NPC's title |
  | Travel | Settlements & travel | every start, capital, village and outpost; the own innkeepers, the home (innkeeper or Claim Stone), the discovered waystones and the Claim Stone waypoint | both; own for NPCs and travel | the settlement's name; "Highcourt Innkeeper", "Your home: Highcourt Innkeeper", "Highcourt Waystone" |
  | Places | Points of interest | bandit and Mirefolk camps, mines and gem camps, the mining camps (Round 58, the brown tent and bright pickaxe icon `grug_map_mining_camp.png`), clash sites | both | "Bandit camp: Coalbrand Yard" (kind and name) |
  | PvP | PvP | the two fortresses and the war camps in their faction's colour (Round 66 ruling 8: the Throng's red `grug_map_war_camp.png`, the Accord's blue `grug_map_war_camp_accord.png`, the same symbol; the faction from the slot `pvp_<faction>_<band>`), with the camps under construction (Round 58, the scaffold icon; since Round 66 its cloth in the faction's colour, `grug_map_camp_construction_<faction>.png`, the faction of the camp's race) | both | the name |
  | Zones | Zones | every zone's name and level band as text | — | — |
  | None | No markers | only the arrows | — | — |

  Generals, captains and the other leaders stay unmarked outside a selected
  quest's crosshairs. Markers sit at their anchors without clustering
  (Round 67); within a layer the former baked kinds draw in the baked
  layer's order (war camps, outposts, villages, mines, clash sites, rare
  dens, camps, fortresses, starts, capitals, kings with the rift boss,
  dragons), the NPCs and travel above them by importance (quest givers by
  their state, [Markers at their anchors](#markers-at-their-anchors-round-67)). Settlements, places and bosses are built once at start from
  the settlement registry, the king sockets, `grug_mobs.dragon_map_markers`
  and the rift's site, never from live entities.
- **Icons:** one approved 32×32 PNG per motif/direction, exported by
  `tools/r64_map/ship.py` with alpha masks and exact source hashes; the
  camps' faction variants (Round 66) are recoloured by palette from their
  masters (`tools/r66_map/recolor.py`, the faction colours of
  `grug_core.factions`) and shipped by the same tool with their masters'
  masks. Both renderers use `grug_map/markers.lua`. **Marker size**
  (Round 66 ruling 5): a marker keeps the share of its map that it has on a
  1920×1080 desktop at HUD and GUI scale 1, where it is 21 px since Round
  67 (32 before): `round(21 × drawn / reference)`, never above the rounded
  product of 21 and the effective HUD scale, never below 11 px (16 before
  Round 67). The map window measures the map's drawn width at zoom 1 (its
  `map_w` in formspec units times the client's integer pixel size, from the
  same window information the window is laid out with, the client's own
  since Round 67) against the same layout on the 1920×1080 reference;
  without window information it keeps the HUD-scaled size. The arrows are
  32 px where the markers are 21 and scale alike. Independent of GUI scale,
  terrain quality and world-map zoom. The world map converts that extent
  using the client's integer formspec pixel size, including window fit.
  Round 67 sizes (marker px, map px; before in brackets): 1280×720 12, 498
  (21, 496), 1920×1080 21, 838 (32, 762), 2560×1440 21, 1118 (32, 762),
  3840×2160 21, 1677 (32, 1016), a 2400×1080 phone at density 2.5 19, 753
  (33, 783).
- **Quest mode** (Round 47 ruling 2): a quest selected in the list shows
  only its targets ([Quest targets](#quest-targets)) and its hand-in NPC
  (silver "?" in progress, gold when ready; the NPC's name as tooltip), and
  no button is highlighted. Every ring and crosshair has the line of each
  objective it marks as tooltip ("Defeat Barrow Piglet: 0/8 (level 1–2)",
  one line each when two share a crosshair). Any layer button deselects the
  quest and shows that layer; a selected quest that leaves the log
  (handed in, abandoned) falls back to the last chosen layer.
- **Tooltips:** every marker has one (positional `tooltip[]`, no hover
  delay, re-evaluated every frame, so a resend does not hide it). The
  client shows the first rect under the pointer (`guiFormSpecMenu.cpp`
  drawMenu), so they are sent topmost first: the party arrows', then the
  markers' in reverse draw order. They are clipped to the map's view.
  Round 64 uses filled silhouette interiors instead of each icon's entire
  square. Engine rectangles have inclusive endpoints and ignore zero area,
  so isolated one-pixel slivers have no hit region; every emitted region
  covers only nontransparent pixels. Geographic rings keep area tooltips.
- **Zones layer** (Round 47 ruling 7; the one line is the user's pick of
  2026-10-13 after the screenshots, reaffirmed 2026-10-25): per zone one
  `label[]` with its name and level band on one line ("Dawnmere Fields 1–10",
  "Stormscale Summit 60"), over a tight translucent dark box (`#101820c0`)
  kept inside the map. Text is 0.65 of the client font at 1× and 0.85 at
  2× and above; larger zooms make room for the more readable type. Box
  dimensions and rendering share the same font metrics (0.52 em per
  character, 1.2 em line height; 16 px times GUI scaling, pixels per unit
  from window information). Selecting Zones from a 1× overview enters
  the existing 2× zoom around the player; minus still permits 1×.
  Placement (`grug_map/zone_labels.lua`) reuses Round 28 M1's: at startup
  sample land on the 32-node grid, prefer the cell farthest from border and
  coast, and nudge clear of earlier labels and baked region names in both
  axes. It uses the small viewport's 1× boxes; diagnostics report both
  reference and small viewport collisions. No per-player or per-tick
  placement is added, and crowded zones can still overlap at 1×.
  **Historical measurements (Round 47, before the current layout/font):**
  seed 42 had 38 labels, at 1× on 1920×1080 no overlapping pair and none
  over a region name; on 1035×696 (8.84 map units at 53 px per unit),
  46 overlapping pairs and 6 over a region name. The two-line candidate
  before the 2026-10-13 pick had 3 and 0, then 79 and 16 respectively.
  Placement took 0.13 s at startup, the grid 0.12 s of it. Those are the
  original comparison figures, not measurements of today's map (62 % of
  the window's width since Round 67).
- **Quest boxes** (ruling 14, the quest log of [quests.md](quests.md)):
  the list box (the active count, the Quest HUD switch, the list, Track on
  HUD and Abandon with its confirmation) and below it the selected quest's
  title, level and zone, its text and where to hand it in. Nothing is
  preselected (the user, 2026-10-08): every opening starts without a
  selection, the text box asks to select a quest, and the map shows quest
  targets only after the player clicked one. A layer button deselects the
  quest (Round 47): the list shows no selection, the text box its hint, and
  Track on HUD and Abandon are hidden as with no selection. The quest text
  box is recreated by every send (`guiFormSpecMenu.cpp`), so a long text
  scrolled down jumps back to the top when a party member's move sends the
  window (accepted, Round 47 ruling 9); the list keeps its scroll. Since
  Round 67 (ruling 19) the text box keeps 2.75 units (the title, the level
  line, about two lines of the text, which scrolls, and the status line)
  and the list box takes the rest of the column, so at 1920×1080 it shows
  eight quests with both group headings (1280×720: four, the phone: one).
  It has one compact line (0.6 units) per quest: its state marker, the title
  (cut with "…", whole in the tooltip) and "[Lv N]" in the difficulty
  colour like the quest HUD (`grug_core.ui.rows` with `compact`), in the
  Story and Side quests groups, each sorted by quest level, ties by title,
  then id (`grug_quests.sort_quests`, the HUD's order;
  [quests.md](quests.md)).

### Quest targets

Selecting a quest marks where its open objectives are done
(`grug_map/targets.lua`):

- a kill objective whose role is a named leader: a red crosshair at the
  leader's spot; a talk objective: the crosshair at the NPC (it counts from
  the start, so it stays marked while the quest is active); a use
  objective: the crosshair at its place;
- a kill objective at a PvP garrison camp (its area is the camp, no
  recipe region): the crosshair at the camp's anchor; the rift boss (no
  region, a place of his own): the crosshair at his clash site. A quest
  target shows wherever it is, in the other faction's land too (the user,
  2026-10-08);
- every other kill objective: rings around spawn regions, those of its
  area (a kind or camp of the zone's recipe) or, without an area, those of
  the quest's zone whose kind or camp spawns its role (the slots its names
  come from). Crosshairs come first; then at most five rings, the regions
  nearest the player. A ring uses the approved orange ring texture, as wide as a disc of the
  region's area, at least 0.7 units: below 32 screen pixels nearest-neighbour
  scaling drops parts of the line, and 0.7 units are about 50 px at 1080p
  and 37 px at 720p (most regions are 0.2–0.45 units
  wide at zoom 1);
- finished kill and use objectives, item objectives (gathering, ore, quest
  drops) and roles outside the region maps without a place of their own
  (underground, water, rare and critter spawns) mark nothing; the text
  suffices. Two objectives at one spot share one crosshair.

The index (role → regions, area → regions, leader → spot) is built once at
start from the region maps ([spawn_regions.md](spawn_regions.md)): seed 42,
151 roles, 1287 regions, 363 areas and 49 leaders in about 2 ms. On that
seed the targets mark all 94 talk, 18 use and 360 kill objectives (94 kill
objectives with a crosshair, 266 with rings).

### Refresh

Event-driven (spec §3.6): a click (zoom, the switch, a layer button, the
quest boxes), a quest selection or a quest change (`grug_quests.register_on_markers_changed`:
accept, kill credit, abandon, held objective items, a level) sends the
window again, at most once a second per player; an event inside that
second is owed and goes out when it ends (one trailing send). In a party
the arrows are compared every second (Round 67, as no dropdown can be
closed by a send any more; 2 s from Round 47 ruling 8, 5 s before), counted
from the later of the last check and the last send, and the window is sent
only when a member's arrow (the viewer's included) moved to another grid
cell (0.02 units: about 12 nodes at 1x on a 1920×1080 window, so a walking
member moves an arrow about every 3 s there and every check at 2x and
more). The same bounded 1 s pass checks window information for solo players
as well: a resize or GUI/HUD scale change resends the form. Without an event
or window change, a solo player's arrow shows where they stood at the last send. A scrollbar move sends nothing and holds every
send for 0.5 s after it (the old Map tab's rule: a form rebuilt during a
drag breaks the drag); what falls due meanwhile is owed until then. A pass
every 0.1 s serves the owed sends and party checks, longest waiting first,
at most 8 party checks and 2 sends per pass, so many windows opened
together drift apart. The window counts as open from a send or any other
event of it until its quit or until any other form is shown: every form
the server shows passes a wrapper in `window.lua`, so another form, the
death screen, the inventory ("Back to inventory") or a close of every form
end it, and it is never sent again until the next opening, also after that
form is closed (`default.node_formspec.shown_form` naming another form
also means closed). A send that crosses a close shows the window again
while its quit arrives after it; the window's next event proves it is
shown and marks it open again, so clicks are answered.

Comparisons (not targets; seed 42, an Accord or Throng viewer with seven
active quests at its start town, engine probe `tools/r44_mq/grug_probe_r44_mq`,
2026-10-13). Round 47, at 85 % of 1920×1080 (one button row), zoom 1x/8x,
the Accord viewer: Quests 6.0/6.1 KB (30 markers, each with its tooltip;
the Throng viewer 32), Bosses 5.1/5.2 KB (19), Trainers 7.1/7.3 KB (39),
Towns 8.3/8.5 KB (54), POIs 7.3/7.5 KB (40), PvP 4.9/4.9 KB (18), Zones
5.8 KB at 1x and 5.9 KB at 4x (38 boxes and labels; the capture probe
`tools/r47_ml`, one-line labels), None 2.9/2.9 KB; quest mode with the
first kill quest 3.9/3.9 KB (its three targets and the hand-in NPC, four
tooltips). The eight buttons with their tooltips and styles are part of
every figure. Round 44's window on the same seed and day: 5.0/5.1 KB with
no quest selected (53 images, 7 tooltips, 3 buttons), 5.7/5.8 KB with that
kill quest selected; before Round 44 the Map
tab was 34.1/34.3 KB (MB's base: 78 image buttons, 38 buttons, 114 tooltips)
plus the Quests tab's 2.0 KB, and about 67.5 KB before MB. Sends per minute
(the fixture's clock): alone 0 standing or walking; in a party with a
member moving about an arrow cell per check 30 (12 with Round 44's 5 s
check); in a party standing still 0; 60 party windows walking together at
least 19 each, the pass budget holding them about 3 s apart; before Round
44, the open Map tab's 2 s poll sent a walking viewer up to 30.

Round 67 (the `tools/r44_mq` scene with a party of five, `tools/r67_map/bytes.lua`,
the same at 1920×1080 and 3840×2160; before → after): no markers 10.5 →
12.4 KB (the eight flat buttons with their tooltips and one shared set of
styles replace the dropdown; 76 tooltip rectangles, the four party
arrows'), Trainers 19.1 → 17.6 KB (214 → 158 rectangles at the smaller
size), Towns 20.7 → 18.6 KB (234 → 169). At the 1 s check a walking
party sends at most 60 a minute instead of 30, so at most about 0.74–1.1 MB
a minute instead of 0.32–0.62 MB for such a viewer; standing still sends
nothing. The fixture's walking party member went from 30 to 47 sends a
minute.

## Baked layer

Only the world map's region names are baked into terrain. The nine names
use the existing uppercase pixel font with a dark halo, ×2 at normal and
×6 at high quality. Island names stand north of their islands over the sea,
one word per line. The minimap's terrain copy has neither names nor icons.
Every map icon is a separate marker, above ground overlays.

`tools/r44_mb/gen_baked_art.py` still exports the font and historical art
into `grug_map/baked_art.lua`; the current base renderer calls only the name
pass. The old 6px icons are no longer used at runtime. The base cache key
includes its builder's source, so Round 64 rebuilds prepared worlds' derived
images automatically. No saved gameplay state or terrain generation changes.
The current map-icon exporter is `tools/r64_map/ship.py`; historical exporters
cannot overwrite these assets. The 0.64.0 receipt records the new cost;
older measurements below describe their named historical versions.

## Map quality and relief

Round 27 (WP50, approved 2026-09-29). The Map tab's base image has the
quality of the server setting `grug_map_quality` in `minetest.conf` (main
menu: *World map › World map quality*), the same for every player on that
server. The minimap always shows normal quality (user ruling 2026-10-06)
in its own variant (Round 44, [Baked layer](#baked-layer)): a normal-size
copy (1215×1080) of the terrain taken before anything is baked, the same
pixels at `normal` and at `high` scaled down from the high image in the same
pass, with no second terrain sampling (each high pixel goes to the normal
pixel its centre lies in, which takes their mean):

| Quality | Size | Nodes per pixel | Relief grid | Tiles | Download | First render |
|---|---|---|---|---|---|---|
| `normal` (default) | 1215×1080 | about 6.7 | 8 nodes | 9 + 9 | about 1.07 + 1.09 MB | about 13 s |
| `high` | 3600×3200 | 2.25 | 4 nodes | 56 + 9 | about 6.77 + 1.25 MB | about 66 s |

Both images cover the atlas, ±4050 × ±3600 nodes since Round 51 (sea plan
rulings 2 and 3: room for the coastal belt; ±3600 × ±3200 before): normal
grew with it at the same scale, high kept its pixel count. The Round 51
figures are one engine run each on the user's seed (2026-10-19, with the
region names baked, the second figure the minimap's copy; the Claim Stone
overlays add about 26 KB). Offline renders with the real renderer on the
same world (`tools/r27_minimap/render_base.lua`, without names and icons)
compare: before the round 1080×960 in 12.0 s (6 tiles, 0.92 MB) and
3600×3200 in 60.3 s (6.92 MB), after it 1215×1080 in 14.0 s (9 tiles,
1.09 MB) and 3600×3200 in 67.4 s (6.92 MB); the time grows with the area,
the depth colouring costs about nothing and compresses as well as before.

The older figures are comparisons from one engine run each on the development
workstation (seed 42, 2026-10-13, Round 47: the world map's image without
icons), not targets; the second figure is the minimap's copy. On the same
seed and day with the icons baked (Round 46) the world map's image was
0.80 MB at normal and 5.96 MB at high (the icons' flat areas compress
better than the terrain under them); the minimap's copy is byte for byte
the same size before and after (0.89 and 1.08 MB), and the renders took
9.0 s and 45.6 s before, 9.1 s and 46.9 s after (run-to-run noise). The
Round 44 figures (2026-10-08, the world of that round): 0.81 + 0.90 MB and
6.10 + 1.09 MB. Before Round 44 (seed 42, 2026-10-08) the normal base was
0.91 MB and the minimap showed it (no copy), the high base 6.74 MB plus a
1.09 MB copy; the renders took 9.6 s and 46.1 s before, 9.8 s and 47.3 s
after (run-to-run noise; baking and the copy cost about 0.1 s at normal and
0.5 s at high). The baked icons covered terrain detail, so in Round 44 the
map's tiles got smaller (until Round 47); at normal the minimap's own copy adds about 0.90 MB to the
download. Before Round 27 the normal base was one
PNG of about 0.56 MB in about the same time; high as one PNG would be about
8.06 MB. No edge exceeds 4096 px, because some GPUs cannot hold larger
textures. An unknown value warns and falls back to `normal`. The quality,
its size, the atlas bounds (Round 51) and the size of the minimap's copy
enter the cache key, so switching the quality re-renders the base (and the
copy) at the next start, and so does a world of an older size; both are cached in
the world directory. A render clears the old key before it writes the
first tile and writes the new key last, so a start after a crash in the
middle of a render renders again instead of taking mixed tiles as current
(Round 41).

**Tiles.** The base is sent as 512 px tiles (`grug_map_base_<col>_<row>.png`,
edge tiles smaller), the minimap's copy as
`grug_map_mini_<col>_<row>.png`, since 0.50.2 the Claim Stone
overlays as `grug_map_claim_<faction>_<col>_<row>.png` and since 0.53.1
the no-fly overlays as `grug_map_flight_<faction>_<col>_<row>.png` (both
factions to every client; [Minimap](#minimap) "Claim mode", "Flight
mode"), written to the world directory and announced as startup media;
nothing else of the base is sent.
The overlays are rendered and cached with the base; their rules (the
column rule's source `grug_housing/registry.lua`, its world queries' source
`grug_housing/api.lua`, the settlement margin and the digest of the mapgen
tree, which holds the settlement cores' margins and the landmark columns)
enter the cache key; for the no-fly overlays the flight rule's source
(`grug_mounts/flight.lua`) and the same mapgen digest. A failing overlay
render costs only its own preview: it logs an error, the base and the
minimap are cached and announced without those overlays, and the next start
tries again. After every
render or cache hit, tiles of these names that the current quality does
not use (after high → normal the 47 extra base tiles, about 5.8 MB) are
deleted from the world directory and their count is logged; a failed delete
is a warning (Round 41). No other file is touched. A world of an earlier
version re-renders once under the new key and overwrites its tiles of the
same names.
The Map tab combines all its tiles into one texture; the minimap combines
only the at most four tiles of its base each cell texture overlaps.

**Relief** (both qualities, tuned on images of the user's world):
- Hillshade: Lambert shading with light from the north-west (map top-left)
  at 45°, slopes exaggerated 1.2×, clamped to 0.7–1.18 of the flat colour.
- Contours: a thin darker line every 16 nodes of height and a darker index
  line every 64 nodes. Where lines would come closer than 3 pixels only the
  index lines are drawn, and none where even those would.
- Elevation tint: land above y 60 blends toward a light stone colour, up to
  30 % at y 320 and above; light enough that the race-region hues still read
  on mountains.
- River strokes follow the river's water width at the image scale, so high
  quality draws wide rivers wider; wide rivers keep the Round 22 minimum of
  three pixels.

**Sea** (Round 51, sea plan ruling 1; `grug_map/base.lua` `SEA`). Water is
coloured by depth in three steps with soft edges:
- **Bay, belt and channel water** is light at the waterline (66, 122, 146),
  the middle blue (48, 92, 118) from 8 nodes of water on, and shades a
  little further toward (36, 72, 98) down to 32 nodes, so a bay's deep
  middle reads a little darker than its rims. The depth is sea level minus
  the floor height of the relief grid above (the same terrain height the
  water query's depth is, sampled once and read bilinearly), so it is
  smooth at both qualities.
- **The open sea** is clearly darker (16, 35, 54). Its edge to the belt,
  the bays and the channels is soft: the open sea's share of the pixels in
  16-node cells, box-blurred twice by two cells, blends the two colours over
  about 100 nodes. A pocket of belt or channel water inside the open sea, or
  an open-sea speck inside the belt, a few dozen nodes across, fades into
  its surroundings instead of showing as a speck; belt pockets at bay rims
  and channel pockets in the belt share the colour of the water around them.
- **Lakes and rivers** keep the lake blue (62, 118, 152). Planned water is a
  bay or a lake by the water query (`grug_zones.water_query_at`), asked for
  planned-water pixels only; swamp pools stay land on the map as before.
- **Coast:** land next to sea or bay water is drawn in the coast brown
  (bays got it in Round 51); lake shores are not. Beyond the image (the
  minimap's sea disc, the fallback image) the open sea's colour is used.

**Region labels.** The nine region names are baked into the Map tab's
image since Round 44 ([Baked layer](#baked-layer)); until then they were
hypertext boxes over the image.

## Minimap

Round 27 (WP50) replaces Luanti's native minimap with our own HUD minimap
drawn from the base image above. The gliding version (approved in playtest,
2026-09-30) keeps the arrow centred and moves the map under it.

- **Native minimap off** for every player: `hud_set_flags` minimap and radar
  false on join, with a single "off" minimap mode as backstop. The client's V
  key only reports that the minimap is disabled by the game.
- **Look and place:** round, top right, in the box of the native minimap it
  replaces (a square of 25 % of the window height, 10 HUD px from the top and
  right edges, `grug_core.hud_layout.minimap_box`; it follows window
  resizes). An opaque pewter bezel (a warm grey-bronze band with a small "N"
  and dot marks at E, S and W) frames the map and covers the map texture's
  overhang, since HUD images are never clipped. The art is opaque out to
  0.975 of its radius and the hole is 0.83 of it; at 1920×1080 the bezel is
  239 px across with a band of about 20.5 px (since Round 32's zoom the scale
  steps by half a pixel, so the bezel fills 0.79–0.99 of the box by window
  size, 0.89 at 1080p, where it filled 0.88–0.98 before). The whole bezel sits inside the
  native box (top-right corners aligned), so the quest list's clearance below
  it is unchanged. North is always up; the map never rotates.
- **Centred arrow, gliding map:** the player's gold arrow stays at the
  centre. It is a compass HUD element that the client turns with the view,
  so turning sends nothing. The map moves under it pixel by pixel on every
  server step: the map element is placed so the player's own pixel lies on
  the arrow's pixel, and a `hud_change` is sent only when that rounded pixel
  changes.
- **One zoom level:** a window of about 440 nodes (66 pixels of the
  normal-size base). Round 32 halved it from 880 (the user, 2026-10-03):
  quest givers and trainers sit twice as far apart, so players can tell
  them apart; the base image, its tiles and their download stay the same,
  each base pixel is simply drawn twice as large.
- **Cells:** the Luanti client never frees textures it builds from texture
  modifiers, so every distinct map texture stays in client memory. The map
  therefore uses one texture per grid cell of 2 base pixels (about 13
  nodes): a disc large enough to cover the hole
  wherever the player is in the cell, combined from the at most four tiles it
  overlaps. A new texture is built only when the player enters a new cell.
  The drawn scale is a whole multiple of 1/grid screen pixels per base pixel,
  so neighbouring cells' textures sit a whole number of pixels apart, and the
  texture and position change in the same step: a cell swap moves no pixel.
  The overhang under the bezel grows with the cell, so Round 32's zoom
  took the grid from 6 to 2 base pixels (3 would reach about a pixel past
  the bezel's opaque band).
- **Normal quality on every server** (Round 37): until then a high server's
  minimap used the high base, with an 8-pixel grid (16 nodes) and the cell
  texture halved on the client to 120 px. Since Round 32's zoom it showed
  little more detail than normal, at more than twice the client memory:
  by `tools/r37_po/texture_growth.lua`, an hour's walk built 1114 textures
  of about 61.2 MB at high and builds 1333 of about 26.4 MB now (3 hours:
  185.0 MB before, 79.9 MB now), the same as on a normal server. The
  geometry code (`minimap_view.lua`) still takes either base size; the game
  passes it the normal one.
- **Markers:** settlements, points of interest, kings and dragons of both
  factions are separate HUD images, alongside the own faction's quest
  givers, Housing Steward, capital services, mender, profession and Riding
  trainers, innkeepers, home and discovered waystones/Claim Stone. The clash
  landmark represents the rift site; there is no duplicate rift-boss icon.
  Ordinary markers use the same size rule as the world map (21 px at the
  reference since Round 67), measured against the minimap's own hole (its
  drawn map) on the 1920×1080 reference; the player's and the party's
  arrows inside the hole scale alike from 32 px. The box is a quarter of
  the window height in real pixels whatever the HUD scaling, so before
  Round 66 the HUD-scaled markers outgrew it on a high-density screen (a
  2400×1080 phone at scaling 2.5: the desktop's 270 px box, 80 px markers;
  32 px in Round 66, 21 px since Round 67). Every marker stands at its
  anchor (Round 67, no displacement).
  Icons glide with the terrain and are culled near the circular edge; the
  bezel covers the remaining corner overhang. Stable marker IDs retain
  their HUD elements. A reusable pool grows to the maximum simultaneously
  visible count, with no 24-marker cutoff and no automatic clustering.
  Landmarks draw above ground overlays (including the green claim square),
  mender/Steward/capital services above that base layer, home/waypoints above
  those and quests above travel, by their state since Round 67
  (`markers.rank`). Trainers and innkeepers share the landmark layer; all
  remain below the bezel.
  Player/party arrows keep exact anchors.
- **Party members** (online, same party) have nine slots of their own: a cyan
  heading arrow that glides with the map inside the hole, or a cyan arrow on
  the bezel pointing toward them (16 directions) when they are outside it.
  Rim arrows fill 85 % of the bezel's band and are drawn above the "N".
- **Updates:** the map, markers and party members are checked every server
  step, and placed again only when something the player sees changed
  (Round 37): the map and its markers when the map moves by a whole screen
  pixel, the cell, the cell texture, the markers or the window change; the
  party arrows then or when a member comes, goes, moves or turns to another
  of the 16 heading frames. A player standing still with a still party costs
  one position read, one wielded-item read and one read of the mount table
  per step and sends nothing. Static markers are asked from their providers
  on joining, whenever the quest markers may have changed
  (`grug_quests.markers_changed`: a quest change, held objective items as
  the quest tracker sees them every 0.5 s, a level change), and at a check
  every 5 s (each player in their own phase) only when their key changed:
  the quest markers' version, the home, the discovered waystones, the Claim Stone waypoint or the
  faction. Party member names are
  read again only on a party change and that 5 s check. The window size and
  the location line are read every 0.5 s (Round 30, perf review #12); a
  window change then resends every element's position. Only changed HUD
  values are sent. The quest givers' states come from one
  `grug_quests.marker_states` call per player (one decoded quest state for
  all givers, memoized until the quest state, held objective items or the
  level change it). A story quest's giver (Round 57) shows the story icon
  of its status (`grug_map_quest_story_<status>.png`,
  [quests.md](quests.md) "Confirmed by the user").
- **Cost** (comparisons, not targets): `tools/r27_minimap/bench_glide.lua`
  (LuaJIT, no engine; one player, 0.09 s server steps, about ten markers in
  the window, two party members moving along) measures about 18 HUD packets
  and 0.49 KB per second walking, 25 sprinting, 31 riding and 45 (1.2 KB/s)
  flying, about 3.7–3.9 times the earlier snapped minimap (4.9 walking,
  11.5 flying). Minimap work is about 5–7 µs per player per step there. By
  the portable fixture a 3000-node walk builds 76 client textures (about
  6.0 MB) at normal and 95 (about 20.9 MB) at high. Round 32's zoom
  (440 nodes): the bench measures 13.2 packets and 0.38 KB per second
  walking, 20.1 sprinting, 28.4 riding and 39.5 (1.1 KB/s) flying (fewer
  markers in the smaller window); the fixture's walk builds 226 textures
  (about 4.5 MB, 72 px each) at normal and 188 (about 10.3 MB, 120 px) at
  high. The engine probe `tools/r32_f1/engine.sh` (one player stand-in
  leaving Dawnmere on one seed, 30 s per speed) measured, before and after
  the zoom: walking 0.23 → 0.39 KB/s, sprinting 0.29 → 0.31, riding
  0.23 → 0.21, flying 0.15 → 0.31 KB/s, and new cell textures 0.17–0.40 →
  0.47–1.23 per second.
- **Claim mode** (0.50.2, [housing.md](housing.md) §2 "Placement
  preview"): while a player with a faction holds a Claim Stone, the minimap
  shows where a claim may go. The cell texture then also holds the
  faction's overlay tiles after the map's (`[combine` blends them by their
  alpha): forbidden ground semi-transparent red (about 45 %). Every claim
  near the cell, drafts included, is one `[fill` in the same red; two
  claims that touch share a pixel line that looks darker (accepted). The
  player's own 101 × 101 square is one HUD image above the map and below
  the markers, centred on the arrow: a green fill (about 30 %) with a more
  opaque frame of one HUD pixel, built as `[fill`s at the size it is drawn
  (it changes only with the window; the map glides under it, so walking
  sends nothing for it). The texture is built again on a cell change, a
  mode change or a change of the claim set (grug_housing's claim-set
  version: a stone placed, picked up, crumbled, destroyed or removed) and
  sent only when its string differs, so a claim elsewhere sends nothing.
  Every claim rectangle is clipped to the cell texture in Lua and left out
  when empty: the engine refuses a `[fill` whose x or y lies outside the
  image or whose width or height is 0, and leaves it out of the texture
  with an error line (`imagesource.cpp`). Another item, no faction or no
  overlays (the render failed or grug_housing is missing): the normal
  minimap. A switched-off minimap appears for claim mode and goes after it;
  its side row moves beside the bezel meanwhile and back afterwards.
  **Overlays:** rendered once per world with the base, one per faction at
  the minimap base's size, from the render's per-pixel water class and
  zone (no second sampling); the territory is asked only for pixels whose
  zone is eligible. At high quality a minimap pixel is red when any render
  pixel whose centre lies in it is red, never averaged; then red is widened
  by one pixel. Settlement cores and hard footprints come on top, widened by
  the 16-node margin and rounded outward (the placement check's own query
  over a quadtree of 64-pixel blocks). Not shown: the depth limit and the
  arrival cube.
  **Cost** (comparisons; `tools/r502_cmap/`): the overlays add about
  0.4–0.5 s to the 9–10 s normal render and about 4.2 s to the 47 s high
  render (LuaJIT offline, seed 4242424242; about 205,000 territory queries
  at normal, 2.3 million at high, 44,000 settlement queries) and about
  22.5 KB of tiles for both factions. Held on the bench's walk
  (`bench_claim.lua`, 70 claims near the route), the stone sends the same
  packets per second (11.1 walking, 33.1 flying) and about 8–10 % more
  bytes (longer texture strings); the per-step cost stays within the
  noise (about 1–2.5 µs per player and step with and without; the engine
  adds one wielded-item read per player and step). An hour's walk builds
  the same 1344 cell textures (26.6 MB) with the stone held as without;
  held on every other leg 1384 (27.4 MB). A client decodes the faction's
  overlay tiles once (at most six, about 4 MB as RGBA8).
- **Claims** (0.50.2 lane HOME, ruling H4; [housing.md](housing.md) §1
  "Seeing a claim"): outside claim mode the cell texture frames every claim
  near the cell, drafts and expired claims included: the player's own in
  the green square's frame colour, every other in yellow (starting values
  the user tunes), one base pixel wide just inside the claim's
  outward-rounded box (the rectangle claim mode fills red, so about ±1 base
  pixel, roughly 7 nodes), no fill. Each frame is up to four `[fill`s,
  clipped to the cell texture in Lua exactly like claim mode's (an edge with
  nothing on the texture is left out), before the mask, so a frame is cut
  cleanly at the bezel and glides with the map; the own frame comes last, on
  top where two claims touch. The texture is built again on a cell change
  or a claim-set version change and sent only when its string differs; with
  no claim near it is the plain map's string. In claim mode everything stays
  as above (all claims red). **Cost** (comparisons, LuaJIT bench
  `tools/r502_cmap/bench_claim.lua` before and after, 70 claims near the
  route): the same packets per second (11.1 walking, 33.1 flying), about
  15 % more bytes without the stone (327 → 377 bytes/s walking: longer
  texture strings), the same 1344 textures (26.6 MB) on the hour's walk, the
  per-step cost within the noise (about 1–3 µs per player and step before
  and after); the server reads the claim set's version once per player and
  step, now also without the stone.
- **Flight mode** (0.53.1, [mounts.md](mounts.md) §4): while a player with
  a faction sits on a flying mount, the cell texture also holds the
  faction's no-fly overlay after the map's tiles and before any claim layer:
  semi-transparent red (Claim mode's red) wherever that faction's flyer is
  dismounted: enemy home land, the dragon islands and the ocean (bays and
  lakes inside the coast, which the map draws as water, stay clear). On
  foot, on a ground mount or a boat, or without a faction the minimap is the
  normal one. The minimap's per-step check reads the mount table
  (`grug_mounts.is_flying`), so mounting and dismounting rebuild the cell
  texture at once (no globalstep of its own); a switched-off minimap stays
  off. **Overlays:** rendered once per world with the base, one per faction
  at the minimap base's size, from the render's per-pixel water class and
  zone (no second sampling) through the dismount's own rule
  (`grug_mounts.flight_rule`), so overlay and dismount agree at every pixel
  centre; at high quality a minimap pixel is red when the rule refuses any
  render pixel centre in it. No widening: the 40-node flight warning covers
  the approach. Beyond the atlas (the sea disc) nothing is drawn.
  **Cost** (comparisons; `tools/r531_flight/`, two engine boots on seed
  42 at normal quality, 2026-10-20): the no-fly overlays render in about
  0.05 s (210 rule calls: one per faction, water class and zone) beside
  the Claim Stone overlays' 0.51–0.53 s and the base's 12.3–12.6 s, and add
  29.2 KB of tiles for both factions (the Claim Stone overlays: 26.5 KB).
  The per-step cost is one table read per player; the texture string grows
  by at most four tile entries while flying.
- **Underground** the minimap keeps showing the surface map.
- **Switch:** "Show minimap" in the map window (the Map tab until Round 44;
  Luanti has no custom keybinds), stored per player in player meta, on by
  default. If the server has no base image (the render failed) or cannot
  write the minimap's round mask to the world directory, the map window
  shows "No minimap available" instead; the native minimap stays off. The
  side elements below stay in either case. A Claim Stone in the hand shows
  the minimap while the switch is off (claim mode above).
- **Side elements** (Round 48): two small images in one row beside the
  minimap, sized with the minimap's box (they grow with the window like the
  bezel):
  - the **mail icon** (an envelope with its count right of it, as high as
    the envelope) shows the player's unread letters and broadcasts: hidden
    at 0, the digit 1–9, "9+" above ([mail plan](../planning/mail-plan.md)
    ruling 14; the image is wide enough for "9+" beside the envelope, the
    user's choice, so a single digit leaves room on its right and every
    count has the same width); drawn exactly as high as the band (72 × 23
    px at 1080p, 47 × 15 at 720p);
  - the **daytime band** shows roughly where the world day stands, not a
    clock (no numbers): one 20-minute day of day and night sections at their
    real lengths (the 15-minute day phase three quarters of it, with the
    sun at its centre; the 5-minute night a quarter, with the moon), with a
    fixed "now" marker in the middle. It moves from right to left, so the
    coming phase enters from the right, in 40 steps of 30 real seconds (the
    day phase's clock runs at 60, the night's at 108, so the step is real
    time, not clock time: 04:30 is the first step, 19:30 the 31st). It is
    about 34 % of the box wide (75 % of Round 48's first 45 %, the user's
    choice of 2026-10-14) at 4 : 1 (92 × 23 px at 1080p, 60 × 15 at 720p). Its phase edges are the night mobs' spawn clock's, so it also
    shows when night mobs come.

  The two stand in one row, band left and mail icon right, 8 HUD px apart,
  the same height and vertically centred on the row (the user's variant A,
  2026-10-14); the mail icon's place stays kept while it is hidden, so
  nothing jumps when a letter arrives. With the minimap shown, the row
  stands left of the bezel (the mail icon 4 HUD px from it), its top on the
  bezel's top; the location line and "Now playing" stay under the bezel.
  With the minimap hidden or unavailable, the row stands right-aligned in
  the top-right corner inside the minimap's box, and "Now playing" 4 HUD px
  below it, so the quest tracker and the other elements laid out around that
  box keep their places (round plan ruling 2.1). Both images are finished files
  (`grug_map_daytime_00` … `_39`, `grug_map_mail_1` … `_9` and `_9p`)
  composed by `tools/r48_hud/gen_hud_textures.py` from its parts (the
  count's digits are the cooldown digits); the HUD only switches the file
  name. The band is checked at the minimap's 5 s check and sends one
  `hud_change` when its step changes, so a clock jump (`/time`, sleeping)
  shows within 5 s; the mail icon changes when the mail count does. Both
  carry the user's Round 48 art picks (band A, envelope B; `tools/r48_artm`).
- No client mod, per-viewer entity proxies or fog of war.

## Zone and town names

Round 28 Lane M1 (user, 2026-10-02): players could not tell which zone they
were in, and quest texts and level routes now name zones.

- **Location:** each player has one location, sampled about once a second
  (each player in their own phase): the zone's display name; inside a
  **start town** or a **capital city** the town's or city's name instead.
  "Inside" is the town's protected footprint (start-town pad and band,
  capital protected city shape), asked with `grug_zones.hard_footprint_in`
  on the player's column only when the player is within 266 nodes of a
  town's anchor on both axes (half the capital's reserved square). Villages,
  outposts, camps and POIs keep the zone's name; where no zone owns the
  column the text is "Open sea". The town still belongs to its zone for
  everything else. The minimap line, the entry banner and the map window's
  "Current:" label show the same text.
- **Claims** (0.50.2 lane HOME, the user's rulings H1–H2): inside a Claim
  Stone's claim the text is **"Your Home"** for its owner and
  **"<owner>'s Home"** for everybody else (permission holders included;
  always `'s`, "Jens's Home"), in every claim state (draft, active,
  expired). "Inside" is `grug_housing.claim_at` on the player's position,
  exact to the node in x and z and in 3D: from y −100 (the claim's lower
  limit) upwards without a top; no hysteresis, so the edge where the text
  changes is the edge of the protection. Only the text changes: the
  territory line and colour, the town flags and the zone handed to the
  zone discovery stay the column's (a first visit to the zone under one's
  own claim still counts). The lookup is one claim-grid cell in the same
  1 s sample, no zone query.
- **Location line:** a small text centred under the minimap bezel (4 HUD px
  gap), in the colour of the territory status (below), created and removed
  with the minimap (hidden when the minimap is switched off or unavailable)
  and moved with it when the window changes. Text and colour follow the
  samples within 0.5 s and are sent only when they change.
- **Now playing** (0.45.1, the user's fix plan row 11): while a capital's
  music track really plays ([sound.md](sound.md) §5), a small box under the
  location line (4 HUD px below its line) shows a music-note icon on the
  left and two left-aligned lines right of it, the title and the artist (the
  name alone, no "by"), in the location line's calm colour and text size, on
  the inventory window's background colour (#343434) at 30 % alpha. HUD text
  cannot be measured, so the box is sized from the longer line's characters
  at 0.6 em each (the font measures 0.40–0.59 em per character over the
  shipped titles and artists); it is centred under the bezel and, when wider
  than the bezel, ends at the bezel's right edge and grows to the left (about
  280 px for "Fantasy Orchestral Theme" at 1080p). It is hidden in the pause
  between tracks, while a pick waits for its download, on leaving the
  capital (with the fade-out), and with music off or at volume 0. With the
  minimap hidden or unavailable it stands in the top-right corner below the
  row of the daytime band and the mail icon, its right edge on the minimap box's (Round 48; until then
  it was hidden). grug_ambience tells the minimap only when the playing track changes; the
  minimap places the box again after a window or GUI scaling change and
  sends only what changed. The note icon is the user's pick (a silver
  beamed pair of notes, 24 px art drawn 36 GUI px high, as tall as the two
  lines).
- **Territory status** (Round 32, the user's ruling): from the player's
  position, never from the PvP flag (`grug_pvp.territory_at`, the rule the
  location flag follows, [pvp.md](pvp.md) §1), sampled with the location:
  **friendly** (own peaceful land above y −501, green), **contested**
  (contested zones, and every land column at y −501 and below, yellow),
  **enemy** (the other faction's peaceful land above y −501, red). A player
  flagged by the PvP button in own land still stands in friendly territory.
  The open sea and a character without a faction have no status: no
  territory line, the feed's calm notice colour.
- **Entry banner:** when the location **or** the territory status changes,
  the name shows top centre for 4 s (Round 47 ruling 21; 1.5 s before) at
  2.5 times the default font, bold,
  in the status colour, below the
  target frame's line (`hud_layout.zone_banner_offset`), clear of the
  level-up banner (0.25 of the window height) and the flash line (0.35).
  A change found by a sample replaces a running display at once and starts
  its 4 s afresh (0.50.2 ruling H3; from Round 28 to 0.50.1 a running
  display blocked new ones until it ended), so the last banner always stays
  the full 4 s: zigzagging across a zone border or a claim's edge shows each
  crossing within a second. When a display ends, a fresh sample decides: a
  location or status other than the one just shown displays at once,
  otherwise the banner hides. Crossing y −501 under friendly or enemy land
  (through caves or shafts too) shows the same name again with the new line
  and colour; crossing it in a contested zone shows nothing; a zone change
  always shows. The location a player joins in shows once on join. A change
  shows within about a second.
- **Zone discovery** (Round 47 ruling 22, `grug_map/zone_discovery.lua`):
  the first time a character enters a **real zone** it gets
  `grug_xp.quest_reward(min(zone level_min, character level), 0.75)` XP — a
  quarter of the median quest weight of 3 kill equivalents, so a high zone
  pays no more than the character's own level — with source `discovery` (no
  race bonus, the usual "+N XP" feed line) and the level-up sound, once even
  when the XP levels the character up; at the level cap no XP is granted
  and no sound plays, the zone is still marked. A real zone is any zone but the six
  civic capital zones; a start town or capital city is its town, never a
  zone, and the open sea has none. The visited zones are kept per character
  in player meta (`grug_map:visited_zones`). A character without that record
  — a new one, or one from before Round 47 — gets the zone it stands in at
  its first location sample marked silently: a new character's start zone.
  It runs in the location sample only when the zone changes.
- **Territory line** (Round 32; it replaces Round 31's PvP subtitle): one
  centred line in the default size, bold, in the same colour under the name
  (`hud_layout.zone_subtitle_offset`; the flight-boundary warning sits one
  line below it): "Friendly Territory", "Contested Territory (PvP)" or
  "Enemy Territory (PvP)", none without a status. No level range (the
  underground mob level follows depth, so a range would only confuse).
  Each sample adds the status's two zone queries (`pvp_rule_at`,
  `faction_at`) to the location's one; the claim lookup adds none (about
  0.25 µs per sample on `tools/r502_home/bench_sample.lua`'s fakes).
- **Zone names on the map:** Rounds 28 to 43 had one Map tab marker per
  zone (a pennant icon, the name and level band in its tooltip); Round 44's
  window had none. Since Round 47 the map window's **Zones** layer shows
  every zone's name and level band as text ([Map window](#map-window)),
  placed at start by Round 28's rule; the zone-grid cache
  `grug_map_zone_grid.txt` stays gone (the grid is sampled at every start,
  seed 42 0.13 s), and a world's old file stays unread.
- **Kings** are markers of the map window's Bosses layer since Round 47,
  with name and level ("King of Highcourt (level 65)"); in Rounds 44–46
  they were baked icons without a tooltip, until then "King of Highcourt"
  markers.
