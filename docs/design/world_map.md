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
  and a light hillshade; roads join it in Phase 4. The hillshade samples
  terrain height on one fixed 8-node grid on every server (D29: no time
  budget, hardware never changes the image); that costs about 24 s once per
  world at first start, then the cached image is reused. It carries no text:
  the region names are a label layer under the markers. No pre-rendered atlas
  image ships.
- Separate the shared map base from marker records and world-to-screen mapping.
  Markers must remain extensible for hover tooltips and/or click actions; do not
  bake labels and all marker semantics irreversibly into one raster.
- Map visibility never unlocks waypoint travel. Actual visit-unlock remains
  WP17's authority; this first map slice has no Housing or travel dependency.
- The native V minimap remains a separate client feature. No client mods or
  native-minimap bitmap extraction are used.

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
two dragons at their authored locations. NPC/boss markers do not query live
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
Closing returns to Character as above. Zoom +/- offers 1x, 2x and 4x, preserving
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

## Native minimap

Native surface minimap is selected by
default, subject to client settings and the player's V toggle. It displays terrain
and player markers, including the local player's direction arrow; ordinary NPC
and mob dots are hidden. Player markers are not filtered by faction or party.
Party, quest and trainer icons remain on the full atlas. No custom minimap,
per-viewer marker proxies, client mod or fog of war is introduced.
