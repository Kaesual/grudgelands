# Mining camp visual review

Proposal requested on 2026-10-26. This is a local design comparison, not a
shipped camp change. On 2026-10-26 the user accepted the visual design,
including the revised military enclosure and the extended banner mounts.
The accepted design is implemented in the Round 63 local
playtest candidate (`docs/planning/round63-plan.md`). The checked-in HTML
is the original approval snapshot; rebuilding reads the current game.

Build and open:

```sh
python3 tools/mining_camp_review/build.py
xdg-open tools/mining_camp_review/index.html
```

Alternatively serve this directory only:

```sh
python3 -m http.server 8764 --bind 127.0.0.1 --directory tools/mining_camp_review
```

Open <http://127.0.0.1:8764/>. Three.js and OrbitControls use the same pinned
0.160.0 CDN URLs as the existing viewer, so the first load needs network
access. All game geometry, textures and review artwork are embedded.

## Scope and sources

- The shared renderer and export helpers are reused from
  `tools/building_templates/viewer/`; they are not modified.
- All 18 current views execute the shipped `r31_pvp_poi_blueprint.lua`
  (small and large converted war camps) or `r58_camp_blueprint.lua`
  (newer mining camps), for all six race palettes, unrotated. NPCs, world
  terrain, dynamic quest objects and engine lighting are not simulated.
- Each proposal has the same horizontal footprint as its baseline: 23 × 23
  or 27 × 27. The headframe is copied from the corresponding current
  `<capital>_miners_guild.tpl`, through the existing template resolver:
  x=12..15, z=8..12, y=0..16, translated by (-14, 0, -3). Its tub is
  replaced with the existing lift node under the rope. Ground under it is
  dressed for the camp. Existing guild banners stay on the headframe.
- The proposal keeps a clear 5 × 5 × 3 central yard. Canvas tents and new
  faction banners are page-only geometry; original vector artwork lives in
  `build.py`. The inventory header is schematic, with a 32 px icon.
- The original visual studies did not implement gameplay integration.
  Round 63 now supplies the templates, NPC/service positions, raid roles,
  protection, paths and quest sockets separately. The proposed
  tower is higher (16 versus 9) and the lift moves. Revision 02 replaces
  the first proposal’s fence with a stone plinth, closed timber panels,
  projecting posts and a roofed gate with a five-column entrance.
- Every new faction banner has a wooden crossbar and two iron brackets
  reaching into a beam or roof above it. Gate banners sit at x=±5, next to
  the posts at x=±4; the latter remain complete. The original revision had
  no mounting hardware and replaced part of a gatepost with a banner.
  These defects are corrected. The capital headframe’s existing guild
  banners are unchanged.

## Controls and inspection

Faction, race material and camp kind selectors; six camera presets; linked
orbit, zoom and pan; click a visible block for its node and coordinates.
The two scenes share the same camera and scale. On narrow screens they stack.
Query hooks: `?faction=throng&race=orc&kind=pvp_camp_high&view=lift`.

## Verification and classification

Build assertions check bounds, central clearance, one lift, resolved template
entries and missing game textures/meshes. Revision 02 also checks every
faction banner’s overhead support and refuses to replace a post with a banner. Python compilation and the required
Lua parser/sweeps pass. The independent Sol review found no material issues;
local Chromium checks passed for all 18 pairs: loaded textures, equal camera
poses, canvas sizing, all six presets and the block inspector. Both factions
were also inspected visually, including a close view of the canvas and banner.
This folder is **compatible tooling only**. The approved geometry is now
implemented separately by Round 63 (see `docs/planning/round63-plan.md`),
classified **map reset**. The game uses ordinary templates and shipped art;
it does not import this viewer at runtime.

The user accepted revision 02 with the final bracket extension to the visible
cloth edge. Game integration still needs the desktop and web GUI checklist;
browser design acceptance is not a runtime acceptance test.
