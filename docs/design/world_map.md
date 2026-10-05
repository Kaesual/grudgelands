# World atlas

Decided 2026-09-21; Round 14 user Go.

- A dedicated Map inventory tab displays a cartographic atlas of the authored
  world: coasts/regions, roads, zone names, settlements and player position.
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
  world at first start, then the cached image is reused (Round 27 sizes and
  times below). It carries no text: the region names are a label layer under
  the markers. No pre-rendered atlas image ships.
- Separate the shared map base from marker records and world-to-screen mapping.
  Markers must remain extensible for hover tooltips and/or click actions; do not
  bake labels and all marker semantics irreversibly into one raster.
- Map visibility never unlocks waypoint travel. Actual visit-unlock is the
  waystones' authority ([world.md](world.md) §6); a map marker grants no travel.
- Since Round 27 the same base image also feeds our own HUD minimap, which
  replaces Luanti's native minimap (see [Minimap](#minimap)). No client mods
  or native-minimap bitmap extraction are used.

## Live markers

Decided 2026-09-21: viewer position is a gold directional triangle; online
party members use cyan directional triangles, with names and hover tooltips.
Offline members have no live map position. The viewer draws above other
markers. Refresh at most every 2 s while the atlas is open, only for changed
visible state (Atlas navigation below). Retain zoom, scroll, selection and
stable click identity across updates while the selected marker remains;
clear selection when it disappears. Closing the atlas resets
the inventory page to Character. A later explicit Map click starts a new live
session; closed maps receive no polling or formspec refreshes.

Round 16 (approved 2026-09-22): authored quest givers have individual icon
markers with the same per-player ready/available/active/locked precedence as
world symbols. Include individual profession/Riding trainers, the six kings and
two dragons at their authored locations. The Housing Steward has its own
marker (kind `steward`, a cottage-and-key icon, Round 26 playtest), drawn above
trainers, kings and innkeepers but below quest, party and player markers. The
capital services of Round 33 share that layer (kind `service`, Round 34): the
Crownbinder (a crown over an anvil) and the Decor Merchant (a lantern). NPC/boss markers do not query live
entities, load terrain, reveal health or indicate respawn state. All NPC/player
hover tooltips contain only the name. Markers are not clustered, displaced or
merged when nearby; subsequent playtest feedback decides whether any handling
is necessary. Map markers confer no remote interaction or travel.

Round 31 (PvP ruling 13): **the NPC's faction decides who sees its
marker.** Each NPC marker carries its NPC's faction (the race's; a quest
giver's own race where it names one). A player sees only the own faction's
quest givers, trainers, Housing Stewards, Crownbinders, Decor Merchants and
innkeepers, plus every king
(the enemy's too) and both dragons; a character without a faction yet sees
only the kings and dragons. Both factions can have markers in one zone
(a spy in a contested zone), each seen only by its own side. The base,
the region names, roads and zone markers stay complete for everyone.

**Settlement icons by faction** (Round 31, the user's ruling after the
lane-M preview): the terrain map is the same for both factions, only the
icons differ. A faction's starts, capitals, villages, outposts and PvP
fortress show only to that faction; the Battlegrounds war camps (quest
targets) and every neutral place (bandit and Mirefolk camps, mines, clash
sites, dragon arenas) show to everyone; the kings and dragons stay visible
as NPC markers. A settlement's class comes from its anchor slot, carried in
the settlement registry; the rule and its one list of hidden classes live
in `grug_map/settlement_icons.lua` (`HIDDEN`), and the Map tab keeps one
list per viewer faction, built once. **Hostile camps** (Round 32: the bandit
camps of the start zones and the frontier, and the Mirefolk camps; by their
anchor slot, `HOSTILE` in the same file) draw a red "X", never the quest
giver's gold "!" (an available quest); other settlements keep their "+".
The minimap shows no settlement icons. The service and quest-giver lists are split per viewer faction
once at server start, so a marker build only picks the own list, in the
Map tab and the minimap alike; the quest givers' states still come from
one `grug_quests.marker_states` call.

Round 29 (WP17): every **discovered** waystone of the player's own network
(three starts, three capitals and, since Round 31, the faction's PvP
fortress; [world.md](world.md) §6) is a marker of kind
`waypoint` at the stone, labelled "<settlement> Waystone", with the icon
`grug_map_waypoint.png` (a grey standing stone with a blue rune, by GPT-6
Astra). Undiscovered and enemy waystones are not shown. The provider is
`waypoint` in `grug_map/providers.lua`, fed by `grug_home.known_waypoints`; a
marker never unlocks or starts travel.

## Innkeeper home travel

Round 17 adds the twelve innkeeper locations and the labels/current-home
distinction; since Round 31 a player's map shows the six of the own faction. The Return home button with destination and cooldown moved to
the Character page in Round 30 (user ruling, 2026-10-02: its live countdown
is cheap in that small form and no longer resends the Map tab). Its server
authority is [home_travel.md](home_travel.md). Map browsing itself grants no binding or
waypoint unlock; binding still requires visiting an eligible innkeeper.

## Atlas navigation

The single full-world view replaces regional cutouts. A new Map-tab visit starts
at 1x with origin scroll; no saved zoom/scroll preference. During that visit,
live marker updates, detail clicks and home-status refresh preserve the view.
Closing returns to Character as above. Zoom +/- offers 1x, 2x, 4x and 8x (8x added after the Round 26 playtest
for precise navigation to NPCs; the base image is simply shown larger), preserving
the current world center and clamping at edges. Native horizontal/vertical
scrollbars reach the complete map at enlarged zooms. No drag-to-pan or animation.

The Map tab uses the same outer window size and legacy scaling as the other
inventory tabs. Fit and center the 9:8 map viewport inside that shared window,
reserving space for controls and scrollbars. The map never determines window
size; a small unused margin is acceptable. Never distort/crop the full overview. Renderer and marker
projection use the same world bounds. Markers retain constant UI dimensions:
only positions scale with zoom; clipping and scroll translate image and markers
together. Hover/click bounds remain aligned. No clustered/offset markers.
Native scrolling does not itself trigger live-form rebuilds. While the tab is
open, the arrows and markers are brought up to date at most every 2 seconds
(Round 30 ruling, perf review #3), with current scroll values: a cheap
signature (zoom, selection, location label, minimap switch, each arrow's place
on a 0.02-unit grid and heading frame, the quest markers' version, which
location is the home, the discovered waystones, the viewer's faction) is
compared, and the form is built
and sent only when it changed. Since Round 32 (perf review R1) the poll runs
every 0.1 s and reads at most 8 signatures and builds at most 2 forms per pass;
viewers that are due wait longest-first, so each keeps its own phase and many
open tabs never rebuild in the same server step. The interval stays 2 seconds
while fewer than about 40 viewers' maps change at once; beyond that the queue
stretches it. Zoom, marker and switch clicks still answer at
once. Arrows are drawn on that grid, so a move inside one grid cell sends
nothing. Markers of one look share one `style[]`. While scroll changes
continue, defer a live rebuild until a short 0.5-second quiet interval;
pending marker changes must still appear afterward.

## Map quality and relief

Round 27 (WP50, approved 2026-09-29). One base image serves the Map tab and
the minimap. Its quality is the server setting `grug_map_quality` in
`minetest.conf` (main menu: *World map › World map quality*), the same for
every player on that server:

| Quality | Size | Nodes per pixel | Relief grid | Tiles | Download | First render |
|---|---|---|---|---|---|---|
| `normal` (default) | 1080×960 | about 6.7 | 8 nodes | 6 | about 0.92 MB | about 10 s |
| `high` | 3600×3200 | 2 | 4 nodes | 56 | about 6.93 MB | about 56 s |

Sizes and times are comparisons from one engine run each on the development
workstation (2026-09-30), not targets. Before Round 27 the normal base was one
PNG of about 0.56 MB in about the same time; high as one PNG would be about
8.06 MB. No edge exceeds 4096 px, because some GPUs cannot hold larger
textures. An unknown value warns and falls back to `normal`. The quality
enters the cache key, so switching it re-renders the base at the next start.

**Tiles.** The base is sent as 512 px tiles (`grug_map_base_<col>_<row>.png`,
edge tiles smaller), written to the world directory and announced as startup
media; nothing else of the base is sent. The Map tab combines all tiles into
one texture; the minimap combines only the at most four tiles each cell
texture overlaps.

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

**Region labels.** The nine region names are hypertext boxes. A box whose
text is taller than the box shows a small dark scrollbar next to the name;
since Round 27 the boxes are large enough for the bold name at a
1280×720 window (one line on the mainland, two on the islands). Known limit:
they are sized for the default font; a larger client font or a smaller
window can bring the scrollbar back.

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
  265 px across with a band of about 22.5 px at high quality and 239 px with
  a band of about 20.5 px at normal (since Round 32's zoom the normal scale
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
- **One zoom level:** a window of about 440 nodes (66 base pixels at normal
  quality, 220 at high). Round 32 halved it from 880 (the user, 2026-10-03):
  quest givers and trainers sit twice as far apart, so players can tell
  them apart; the base image, its tiles and their download stay the same,
  each base pixel is simply drawn twice as large.
- **Cells:** the Luanti client never frees textures it builds from texture
  modifiers, so every distinct map texture stays in client memory. The map
  therefore uses one texture per grid cell of 2 base pixels at normal
  (about 13 nodes) and 8 at high (16 nodes): a disc large enough to cover the hole
  wherever the player is in the cell, combined from the at most four tiles it
  overlaps. A new texture is built only when the player enters a new cell.
  The drawn scale is a whole multiple of 1/grid screen pixels per base pixel,
  so neighbouring cells' textures sit a whole number of pixels apart, and the
  texture and position change in the same step: a cell swap moves no pixel.
  The overhang under the bezel grows with the cell, so Round 32's zoom
  halved the high grid (the same screen geometry as before) and took the
  normal one from 6 to 2 base pixels (3 would reach about a pixel past the
  bezel's opaque band).
- **High quality at half resolution:** the high cell texture is combined at
  239 base pixels and halved on the client with `[resize` to 120 px, a
  quarter of the memory (one pixel short, so the resize steps exactly two
  base pixels per texel and swaps stay seam-free). Since Round 32's zoom
  the HUD draws a base pixel about one screen pixel wide at 1080p, so the
  half-size texture is drawn larger than it is and high shows less detail
  than it could, though still more than normal (three screen pixels per
  base pixel of about 6.7 nodes at 1080p).
- **Markers** are separate HUD elements, never pixels of the map texture:
  quest givers with their per-player state (ready, available, active,
  locked), the Housing Steward, the Crownbinder and the Decor Merchant,
  profession and Riding trainers, innkeepers,
  the player's home (the bound innkeeper or Claim Stone) and discovered
  waystones (Round 29). Settlements,
  camps, kings and dragons stay on the Map tab only. Markers glide with the
  map and are hidden unless the whole icon lies inside the hole. The minimap
  has 24 marker slots; when more markers fall inside the circle, quest givers
  keep a slot first, then the Steward and the capital services, home,
  innkeeper, trainers and
  waystones, and the
  kept ones are drawn in their usual order. Markers are not clustered or
  moved apart.
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
  the home, the discovered waystones or the faction. Party member names are
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
- **Switch:** "Show minimap" on the Map tab (Luanti has no custom keybinds),
  stored per player in player meta, on by default. If the server has no base
  image (the render failed) or cannot write the minimap's round mask to the
  world directory, the Map tab shows "No minimap available" instead; the
  native minimap stays off.
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
  everything else. The minimap line, the entry banner and the Map tab's
  "Current:" label show the same text.
- **Location line:** a small text centred under the minimap bezel (4 HUD px
  gap), in the colour of the territory status (below), created and removed
  with the minimap (hidden when the minimap is switched off or unavailable)
  and moved with it when the window changes. Text and colour follow the
  samples within 0.5 s and are sent only when they change.
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
- **Zone markers on the Map tab:** one marker per zone (islands and front
  zones included), a plain pennant icon, with the zone name and level band
  in its tooltip, e.g. "Dawnmere Fields (levels 1–10)" ("(level 60)" for a
  one-level zone). Clicking selects it like any marker. Zone markers draw
  under every other marker. Each sits at the land cell of its zone farthest
  from the zone's border and coast on a 32-node grid (the pole of
  inaccessibility), computed once at server start from the world authority
  (a later start of the same world reads the 32-node zone grid from
  `grug_map_zone_grid.txt`, keyed by `grug_mapgen.wp40.world_key`, the zone
  queries' seam and the sampling code; the placement itself runs every
  start).
  If another marker (service, king, dragon, quest giver, settlement,
  innkeeper) or a region name is too close, the marker takes the deepest
  cell of its zone that keeps 0.45 formspec units (zoom 1) from every other
  marker's centre on both axes and clear of the region names' text; where no
  cell is clear it takes the one clearest of other markers first and of the
  names' text second (the island names cover almost their whole island). The
  map has no layer filters; zone markers zoom and scroll like every marker.
- **King markers** name their settlement: "King of Highcourt" (a king with a
  name of his own would read "<name>, King of Highcourt").
