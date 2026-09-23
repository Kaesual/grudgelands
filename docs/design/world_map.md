# World atlas

Decided 2026-09-21; Round 14 user Go.

- A dedicated Map inventory tab displays a cartographic atlas of the authored
  world: coasts/regions, roads, zone names, settlements and player position.
- No fog of war and no per-character terrain discovery mask. The atlas does not
  require full-world generation and does not render actual player-built terrain.
- Use existing world authority and stable anchors; support zoom/pan or bounded
  region views without adding travel or visit objectives.
- Separate the shared map base from marker records and world-to-screen mapping.
  Markers must remain extensible for hover tooltips and/or click actions; do not
  bake labels and all marker semantics irreversibly into one raster.
- Map visibility never unlocks waypoint travel. Actual visit-unlock remains
  WP17's authority; this first map slice has no Housing or travel dependency.
- The native V minimap remains a separate client feature. No client mods or
  native-minimap bitmap extraction are used.

## Round 15 live markers

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

## Round 18 coverage and minimap

Six regional views jointly cover the full world-atlas bounds, including frontiers,
capitals and islands, with overlap and correct aspect. Renderer and marker
projection share one bounds authority. Native surface minimap is selected by
default, subject to client settings and the player's V toggle. It displays terrain
and the local player's direction arrow only; other player/entity dots are hidden.
Party, quest and trainer icons remain on the full atlas. No custom minimap,
per-viewer marker proxies, client mod or fog of war is introduced.
