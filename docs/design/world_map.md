# World atlas

Decided 2026-09-21; Round 14 user Go.

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
  Phase 4. Lakes show as water pixels; rivers (about 7.5–30 nodes of water
  width, `terrain_data.lua`) are stroked from the water layout's centrelines
  onto land at about their water width at the image scale, at least three
  pixels wide from 18 nodes (`grug_map/base.lua` `RIVER_WIDE`; Map quality
  and relief below). The cache key includes the
  water layout, so a changed layout re-renders the base. The relief samples
  terrain height on one fixed grid per map quality on every server (D29: no
  time budget, hardware never changes the image); the render is paid once per
  world at first start, then the cached image is reused (sizes and times
  below). Since Round 44 the settlement, point-of-interest and boss icons
  and the region names are baked into it ([Baked layer](#baked-layer)). No
  pre-rendered atlas image ships.
- Separate the shared map base from marker records and world-to-screen mapping.
  Markers must remain extensible for hover tooltips and/or click actions. Only
  the places that are the same for every player (settlements, points of
  interest, kings, dragons) and the region names are baked (Round 44, the
  user's ruling); everything per player stays a marker.
- Map visibility never unlocks waypoint travel. Actual visit-unlock is the
  waystones' authority ([world.md](world.md) §6); a map marker grants no travel.
- Since Round 27 the same base image also feeds our own HUD minimap, which
  replaces Luanti's native minimap (see [Minimap](#minimap)). No client mods
  or native-minimap bitmap extraction are used.

## Live markers

Decided 2026-09-21: viewer position is a gold directional triangle; online
party members use cyan directional triangles. Offline members have no live
map position. The viewer draws above other markers. Since Round 44 the
arrows carry no names or tooltips and markers take no clicks; when the
world map sends them is the [Map window](#map-window)'s refresh rule.
Closed maps receive no formspec refreshes.

Round 16 (approved 2026-09-22): authored quest givers have individual icon
markers with the same per-player ready/available/active/locked precedence as
world symbols. Since Round 44 the world map shows only the subset of
ruling 12 ([Map window](#map-window)): no Steward, services, other
innkeepers or "!", question marks only for active quests; the minimap keeps
the full set below. Include individual profession/Riding trainers at their
authored locations (since Round 44 one icon per profession,
`grug_map_trainer_<profession>.png` by GPT-6 Astra, replacing the book;
Riding keeps the mount icon); the six kings and two dragons are baked since
Round 44. The Housing Steward has its own
marker (kind `steward`, a cottage-and-key icon, Round 26 playtest), drawn above
trainers and innkeepers but below quest, party and player markers. The
capital services of Round 33 share that layer (kind `service`, Round 34): the
Crownbinder (a crown over an anvil) and the Decor Merchant (a lantern). NPC markers do not query live
entities, load terrain, reveal health or indicate respawn state. All NPC/player
hover tooltips contain only the name. Markers are not clustered, displaced or
merged when nearby; subsequent playtest feedback decides whether any handling
is necessary. Map markers confer no remote interaction or travel.

Round 31 (PvP ruling 13): **the NPC's faction decides who sees its
marker.** Each NPC marker carries its NPC's faction (the race's; a quest
giver's own race where it names one). A player sees only the own faction's
quest givers, trainers, Housing Stewards, Crownbinders, Decor Merchants and
innkeepers; a character without a faction yet sees no NPC markers. Both
factions can have markers in one zone (a spy in a contested zone), each seen
only by its own side. The base with its baked layer (the kings and dragons
included) and roads stay complete for everyone; since Round 44 the
selected quest's own targets show wherever they are.

Round 29 (WP17): every **discovered** waystone of the player's own network
(three starts, three capitals and, since Round 31, the faction's PvP
fortress; [world.md](world.md) §6) is a marker of kind
`waypoint` at the stone, labelled "<settlement> Waystone", with the icon
`grug_map_waypoint.png` (a grey standing stone with a blue rune, by GPT-6
Astra). Undiscovered and enemy waystones are not shown. The provider is
`waypoint` in `grug_map/providers.lua`, fed by `grug_home.known_waypoints`; a
marker never unlocks or starts travel. Since Round 45 (PT9) the owner's
activated Claim Stone is a `waypoint` marker "Your Claim Stone" in the
stone's own look (its block texture, `grug_housing.STONE_TEXTURE`;
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
clustered/offset markers. Native scrolling never sends the form; the
server keeps the scroll values from every event (read at the zoom of the
form they come from; ignored while the soft lock holds, when the server
owns the view) and echoes them on the next send, so a send does not move
the view. Arrows sit on a 0.02-unit
grid. Until Round 44 the Map tab shared the inventory window's size and
was rebuilt by a 2 s poll (Round 30, perf review #3; Round 32 R1); both
ended with the [Map window](#map-window).

## Map window

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
- **Size:** 85 % of the client's `max_formspec_size`
  (`core.get_player_window_information`, read at every send) with
  `padding[0,0]` (`max_formspec_size` assumes no padding; the default 0.05
  would shrink the form to about 76 % of the screen), 20×12 units for
  clients that do not report it, at least 16×10 (the client shrinks a
  larger form itself). At 1920×1080 and GUI scale 1 (72 px per unit) that
  is 22.66×12.75 units: the map 12.49×11.10, the quest column 9.0 wide. At
  1280×720 the client's fixed image size (0.5555 inch, 53.3 px) wins over
  1/15 of the height, so `max_formspec_size` is 24×13.5 and the window
  20.4×11.47 (the map 10.85×9.64). At GUI scale 1.5 on 1080p the window
  sits at the 16×10 floor, which still fits (17.8×10 maximum). The
  inventory tabs keep their own size.
- **Layout:** a header row (the zoom, the location as "Current:", the
  minimap switch "Show minimap", stored per player in player meta, or "No
  minimap available", "Back to inventory", the close button); the 9:8 map
  with its scrollbars on the left; the quest column on the right, at least
  6.5 units and 30 % of the window wide plus what the map's aspect leaves.
- **Overlay** (ruling 12; the Steward, services and innkeepers added back
  by the user, 2026-10-08), plain `image[]` elements, bottom to top: quest
  target rings, the own faction's trainers (the profession icons, riding
  the mount icon; 0.23 units at 1x and 2x, two thirds of the 0.34 icons,
  0.34 at 4x and 8x), innkeepers, the home and discovered waystones, the
  Housing Steward, the Crownbinder and the Decor Merchant (their icons,
  0.34, without tooltips; each NPC of the own faction only, like the
  minimap), a question mark at the hand-in NPC of every active quest of the
  own faction (silver in progress, gold when one of its quests is ready;
  the NPC's name as tooltip, the only tooltips of the map), quest target
  crosshairs, the party's cyan arrows, the player's gold arrow. No
  exclamation marks and no zone markers; nothing of the other faction
  beyond the baked layer except the selected quest's own targets. No
  search, list, legend or filters.
- **Quest boxes** (ruling 14, the quest log of [quests.md](quests.md)):
  the list box (the active count, the Quest HUD switch, the list, Track on
  HUD and Abandon with its confirmation) and below it the selected quest's
  title, level and zone, its text and where to hand it in. Nothing is
  preselected (the user, 2026-10-08): every opening starts without a
  selection, the text box asks to select a quest, and the map shows quest
  targets only after the player clicked one.

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
  nearest the player. A ring is the white ring texture (32 px, a 1 px line)
  tinted orange and semi-transparent, as wide as a disc of the region's
  area, at least 0.7 units: below 32 screen pixels nearest-neighbour
  scaling drops parts of the line, and 0.7 units are about 50 px at 1080p
  and 37 px at 720p, about twice an icon (most regions are 0.2–0.45 units
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

Event-driven (spec §3.6): a click (zoom, the switch, the quest boxes), a
quest selection or a quest change (`grug_quests.register_on_markers_changed`:
accept, kill credit, abandon, held objective items, a level) sends the
window again, at most once a second per player; an event inside that
second is owed and goes out when it ends (one trailing send). In a party
the arrows are compared every 5 s and the window is sent only when a
member's arrow (the viewer's included) moved to another grid cell. Alone,
nothing is sent without an event: the player's own arrow shows where they
stood at the last send. A scrollbar move sends nothing and holds every
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
active quests at its start town, engine probe `tools/r44_mq/grug_probe_r44_mq`):
the window is about 5.0 KB at zoom 1x and 5.1 KB at 8x with no quest
selected (53 images, 7 tooltips, 3 buttons), 5.8/5.9 KB with a kill
quest selected (its three targets, Track on HUD and Abandon); before
Round 44 the Map
tab was 34.1/34.3 KB (MB's base: 78 image buttons, 38 buttons, 114 tooltips)
plus the Quests tab's 2.0 KB, and about 67.5 KB before MB. Sends per minute
(the fixture's clock): alone 0 standing or walking, in a party with a
walking member 12, in a party standing still 0; before, the open Map tab's
2 s poll sent a walking viewer up to 30.

## Baked layer

Round 44 (the UI rework spec, rulings 11 and 13; plan ruling 5). The base
renderer draws, into the image itself:

- **Icons** of every settlement by its anchor slot (`grug_map/settlement_icons.lua`):
  start towns, capitals, villages, outposts, PvP fortresses, Battlegrounds
  war camps, bandit and Mirefolk camps (red warning details), mines and gem
  camps (`mine`, `apex_mine`), clash sites (`clash_*`), rare dens
  (`rare_*`), the dragon arenas; plus the six kings at their sockets and the
  two dragons. A dragon arena and its dragon are one icon. Generals,
  captains and the rift boss stay unmarked. **Every settlement is baked for
  everyone**, the other faction's starts, capitals, villages, outposts and
  fortress included (Round 44 ruling 5; it ends Round 31's per-faction
  hiding). Draw order bottom to top: war camps, outposts, villages, mines,
  clash sites, rare dens, bandit and Mirefolk camps, fortresses, starts,
  capitals, kings, dragons; icons are not moved apart (a king stands about
  32 nodes from his capital's anchor, so his crown covers most of the
  capital's icon).
- **Region names** in an English uppercase pixel font (cap height 7) with a
  dark halo of one glyph pixel, light text, at the nine places of the Round
  22 macro layout; the island names stand north of their islands over the
  sea, one word per line. Names draw above the icons.

Two variants: the **Map tab's image** gets the 16 px icons scaled ×2 at
`normal` (32 px, about 0.37 formspec units at zoom 1, beside the overlay's
0.34) and ×6 at `high` (96 px, 0.33), and the names at the same scale; the
**minimap's image** gets the hand-drawn 6 px icons unscaled (about 18 screen
pixels at 1080p) and no names. Both grow with the zoom like the terrain.
The art (lane AR, `grug_map/art/`) reaches Lua as data:
`tools/r44_mb/gen_baked_art.py` writes `grug_map/baked_art.lua` (`--check`
tells a stale copy), because the engine decodes no PNG for Lua. The cache
key covers the drawing code (`bake.lua`), the art and font versions and
every icon's kind and place, so new art, a new layout or a moved settlement
re-renders the map at the next start. Each render logs the drawn icons and
names and how many pairs overlap (seed 42: 124 icons, 58 overlapping pairs
at normal, 44 at high; 10 and 8 names over an icon). The map window draws no
settlement, camp, king or dragon markers and no region-name text; the
minimap shows its baked icons under its markers.

## Map quality and relief

Round 27 (WP50, approved 2026-09-29). The Map tab's base image has the
quality of the server setting `grug_map_quality` in `minetest.conf` (main
menu: *World map › World map quality*), the same for every player on that
server. The minimap always shows normal quality (user ruling 2026-10-06)
in its own variant (Round 44, [Baked layer](#baked-layer)): a normal-size
copy (1080×960) of the terrain taken before anything is baked, the same
pixels at `normal` and at `high` scaled down from the high image in the same
pass, with no second terrain sampling (each high pixel goes to the normal
pixel its centre lies in, which takes their mean):

| Quality | Size | Nodes per pixel | Relief grid | Tiles | Download | First render |
|---|---|---|---|---|---|---|
| `normal` (default) | 1080×960 | about 6.7 | 8 nodes | 6 + 6 | about 0.81 + 0.90 MB | about 10 s |
| `high` | 3600×3200 | 2 | 4 nodes | 56 + 6 | about 6.10 + 1.09 MB | about 47 s |

Sizes and times are comparisons from one engine run each on the development
workstation (seed 42, 2026-10-08), not targets; the second figure is the
minimap's copy. Before Round 44 (same seed and day) the normal base was
0.91 MB and the minimap showed it (no copy), the high base 6.74 MB plus a
1.09 MB copy; the renders took 9.6 s and 46.1 s before, 9.8 s and 47.3 s
after (run-to-run noise; baking and the copy cost about 0.1 s at normal and
0.5 s at high). The baked icons cover terrain detail, so the Map tab's tiles
got smaller; at normal the minimap's own copy adds about 0.90 MB to the
download. Before Round 27 the normal base was one
PNG of about 0.56 MB in about the same time; high as one PNG would be about
8.06 MB. No edge exceeds 4096 px, because some GPUs cannot hold larger
textures. An unknown value warns and falls back to `normal`. The quality
and the size of the minimap's copy enter the cache key, so switching it
re-renders the base (and the copy) at the next start; both are cached in
the world directory. A render clears the old key before it writes the
first tile and writes the new key last, so a start after a crash in the
middle of a render renders again instead of taking mixed tiles as current
(Round 41).

**Tiles.** The base is sent as 512 px tiles (`grug_map_base_<col>_<row>.png`,
edge tiles smaller), the minimap's copy as
`grug_map_mini_<col>_<row>.png`, written to the world directory and
announced as startup media; nothing else of the base is sent. After every
render or cache hit, tiles of these two names that the current quality does
not use (after high → normal the 50 extra base tiles, about 5.3 MB) are
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
- **Baked icons:** the minimap's own base carries the 6 px icons of every
  settlement, point of interest, king and dragon, without names (Round 44,
  [Baked layer](#baked-layer)); they glide with the map as part of it.
- **Markers** are separate HUD elements, never pixels of the map texture:
  quest givers with their per-player state (ready, available, active,
  locked: the "!" and "?"), the Housing Steward, the Crownbinder and the
  Decor Merchant, profession trainers with their profession's icon (Round
  44) and Riding trainers with the mount icon, innkeepers, the player's home
  (the bound innkeeper or Claim Stone) and discovered waystones (Round 29),
  each NPC of the own faction only (Round 31). The user kept this set in
  Round 44. Markers glide with the
  map and are hidden unless the whole icon lies inside the hole. The minimap
  has 24 marker slots; when more markers fall inside the circle, quest givers
  keep a slot first, then the Steward and the capital services, home,
  innkeeper, trainers and waystones, and the kept ones are drawn in their
  usual order. Markers are not clustered or moved apart. The densest
  window, measured in every capital and start town of seed 42 with every
  quest giver of the faction counted (2026-10-08), holds 15 markers in a
  capital and 4 in a start town, plus at most the home and a waystone, so
  the 24 slots stay.
- **Party members** (online, same party) have nine slots of their own: a cyan
  heading arrow that glides with the map inside the hole, or a cyan arrow on
  the bezel pointing toward them (16 directions) when they are outside it.
  Rim arrows fill 85 % of the bezel's band and are drawn above the "N".
- **Updates:** the map, markers and party members are checked every server
  step, and placed again only when something the player sees changed
  (Round 37): the map and its markers when the map moves by a whole screen
  pixel, the cell, the markers or the window change; the party arrows then
  or when a member comes, goes, moves or turns to another of the 16 heading
  frames. A player standing still with a still party costs one position read
  per step and sends nothing. Static markers are asked from their providers
  on joining, whenever the quest markers may have changed
  (`grug_quests.markers_changed`: a quest change, held objective items as
  the quest tracker sees them every 0.5 s, a level change), and at a check
  every 5 s (each player in their own phase) only when their key changed:
  the quest markers' version (a repeatable's cooldown ending shows then),
  the home, the discovered waystones, the Claim Stone waypoint or the
  faction. Party member names are
  read again only on a party change and that 5 s check. The window size and
  the location line are read every 0.5 s (Round 30, perf review #12); a
  window change then resends every element's position. Only changed HUD
  values are sent. The quest givers' states come from one
  `grug_quests.marker_states` call per player (one decoded quest state for
  all givers, memoized until the quest state, held objective items, the
  level or the end of a repeatable's cooldown change it).
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
- **Underground** the minimap keeps showing the surface map.
- **Switch:** "Show minimap" in the map window (the Map tab until Round 44;
  Luanti has no custom keybinds), stored per player in player meta, on by
  default. If the server has no base image (the render failed) or cannot
  write the minimap's round mask to the world directory, the map window
  shows "No minimap available" instead; the native minimap stays off.
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
  capital (with the fade-out), with music off or at volume 0, and with the
  minimap hidden or unavailable (switching the minimap on shows it again).
  grug_ambience tells the minimap only when the playing track changes; the
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
  the name shows top centre for 1.5 s at 2.5 times the default font, bold,
  in the status colour, below the
  target frame's line (`hud_layout.zone_banner_offset`), clear of the
  level-up banner (0.25 of the window height) and the flash line (0.35).
  While a display runs no new one starts; when it ends, a fresh sample
  decides: a location or status other than the one just shown displays at
  once, otherwise the banner hides (leaving a city and coming back within
  the 1.5 s shows nothing new). Crossing y −501 under friendly or enemy land
  (through caves or shafts too) shows the same name again with the new line
  and colour; crossing it in a contested zone shows nothing; a zone change
  always shows. The location a player joins in shows once on join. A change
  shows within about a second.
- **Territory line** (Round 32; it replaces Round 31's PvP subtitle): one
  centred line in the default size, bold, in the same colour under the name
  (`hud_layout.zone_subtitle_offset`; the flight-boundary warning sits one
  line below it): "Friendly Territory", "Contested Territory (PvP)" or
  "Enemy Territory (PvP)", none without a status. No level range (the
  underground mob level follows depth, so a range would only confuse).
  Each sample adds the status's two zone queries (`pvp_rule_at`,
  `faction_at`) to the location's one.
- **Zone markers on the Map tab (Round 28 to 43, gone in Round 44):** one
  marker per zone, a pennant icon with the zone name and level band in its
  tooltip. The map window draws none (ruling 12; the user, 2026-10-08), so
  their placement at start, their provider and the zone-grid cache
  `grug_map_zone_grid.txt` are gone; a world's old file stays unread.
- **Kings** carry no name on the map since Round 44: they are baked icons
  without a tooltip (until then "King of Highcourt" markers).
