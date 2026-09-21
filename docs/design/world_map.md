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
