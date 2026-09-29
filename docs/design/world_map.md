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
  Phase 4. Lakes show as water pixels; rivers (3–25 nodes wide, below one
  map pixel at normal quality) are stroked from the water layout's
  centrelines onto land, one pixel wide and three pixels from 11 nodes of
  channel width (Phase 5). The cache key includes the
  water layout, so a changed layout re-renders the base. The relief samples
  terrain height on one fixed grid per map quality on every server (D29: no
  time budget, hardware never changes the image); the render is paid once per
  world at first start, then the cached image is reused (Round 27 sizes and
  times below). It carries no text: the region names are a label layer under
  the markers. No pre-rendered atlas image ships.
- Separate the shared map base from marker records and world-to-screen mapping.
  Markers must remain extensible for hover tooltips and/or click actions; do not
  bake labels and all marker semantics irreversibly into one raster.
- Map visibility never unlocks waypoint travel. Actual visit-unlock remains
  WP17's authority; this first map slice has no Housing or travel dependency.
- Since Round 27 the same base image also feeds our own HUD minimap, which
  replaces Luanti's native minimap (see [Minimap](#minimap)). No client mods
  or native-minimap bitmap extraction are used.

## Live markers

Decided 2026-09-21: viewer position is a gold directional triangle; online
party members use cyan directional triangles, with names and hover tooltips.
Only positions within the selected view appear; offline members have no live
map position. The viewer draws above other markers. Refresh at most twice per
second while the atlas is open, only for changed visible state. Retain view,
selection and stable click identity across updates while the selected marker
remains visible; clear selection when it disappears or leaves the current view. Closing the atlas resets
the inventory page to Character. A later explicit Map click starts a new live
session; closed maps receive no polling or formspec refreshes.

Round 16 (approved 2026-09-22): authored quest givers have individual icon
markers with the same per-player ready/available/active/locked precedence as
world symbols. Include individual profession/Riding trainers, the six kings and
two dragons at their authored locations. The Housing Steward has its own
marker (kind `steward`, a cottage-and-key icon, Round 26 playtest), drawn above
trainers, kings and innkeepers but below quest, party and player markers. NPC/boss markers do not query live
entities, load terrain, reveal health or indicate respawn state. All NPC/player
hover tooltips contain only the name. Markers are not clustered, displaced or
merged when nearby; subsequent playtest feedback decides whether any handling
is necessary. Map markers confer no remote interaction or travel. Waypoints
remain a later package.

## Innkeeper home travel

Round 17 adds the twelve innkeeper locations, labels/current-home distinction
and a Return home button with destination and cooldown. Its server authority
is [home_travel.md](home_travel.md). Map browsing itself grants no binding or
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
Native scrolling does not itself trigger live-form rebuilds; actual changed
marker state is refreshed at most twice per second with current scroll values.
While scroll changes continue, defer a live rebuild until a short 0.5-second
quiet interval; pending marker changes must still appear afterward.

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
one texture; the minimap combines only the at most four tiles its window
overlaps.

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
drawn from the base image above.

- **Native minimap off** for every player: `hud_set_flags` minimap and radar
  false on join, with a single "off" minimap mode as backstop. The client's V
  key only reports that the minimap is disabled by the game.
- **Look and place:** round, top right, in the box of the native minimap it
  replaces (a square of 25 % of the window height, 10 HUD px from the top and
  right edges, `grug_core.hud_layout.minimap_box`; it follows window
  resizes). The quest list's clearance below it is unchanged. A ring frame
  with an "N" plate surrounds the map. North is always up; the player's gold
  arrow is a compass HUD element that the client turns with the view, so
  turning sends nothing. The map never rotates.
- **One zoom level:** a window of about 900 nodes (135 base pixels at normal
  quality, 450 at high).
- **Grid snapping:** the Luanti client never frees textures it builds from
  texture modifiers, so every distinct map window would stay in client
  memory. The window therefore snaps to a grid of 16 base pixels at normal
  (about 107 nodes) and 64 at high (128 nodes), centred on the player's grid
  cell; the player's arrow moves off-centre inside it (at most half a cell).
  A new window texture is built only when the player enters a new cell, about
  every 110–130 nodes walked.
- **Markers** are separate HUD elements, never pixels of the map texture:
  quest givers with their per-player state (ready, available, active,
  locked), the Housing Steward, profession and Riding trainers, innkeepers
  and the player's home (the bound innkeeper or Claim Stone). Settlements,
  camps, kings and dragons stay on the Map tab only. The minimap has 24
  marker slots; when more markers fall inside the circle, quest givers keep
  a slot first, then the Steward, home, innkeeper and trainers, and the kept
  ones are drawn in their usual order. Markers are not clustered or moved
  apart.
- **Party members** (online, same party) have nine slots of their own: a cyan
  heading arrow inside the circle, or a small cyan arrow on the rim pointing
  toward them (16 directions) when they are outside the window.
- **Updates:** positions and party members are checked every 0.2 s, static
  markers are asked from their providers on joining, on every quest change
  and every 5 s (each player in their own phase). Only changed HUD values are
  sent; a standing player costs no packets.
- **Underground** the minimap keeps showing the surface map.
- **Switch:** "Show minimap" on the Map tab (Luanti has no custom keybinds),
  stored per player in player meta, on by default. If the server has no base
  image (the render failed) or cannot write the minimap's round mask to the
  world directory, the Map tab shows "No minimap available" instead; the
  native minimap stays off.
- No client mod, per-viewer entity proxies or fog of war.
