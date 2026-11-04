# Round 69 camp site studies

Three proposed construction camps for the user's pick, using the shipped
Round 63 materials. **First Lift is the recommendation:** its incomplete
headframe identifies an earlier mining camp from a distance.

- **A — Wallwright:** a completed west wall and an east scaffold, with
  successive bays of panels, first courses, footings and survey stakes.
- **B — First Lift:** a lower headframe ring and working deck, one raised
  upper portal, a rope hoist above a covered shaft collar, and a staked rear
  wall. Two worker tents flank the gate route.
- **C — Panel Yard:** long worker tents beside the parade route, three
  assembled wall bays awaiting installation, material stacks and marked
  foundations. A low, broad silhouette.

Open [index.html](index.html) directly. It contains **24 interactive scenes**
(today plus three proposals, for each of six races), all textures, meshes,
the renderer, controls, library and the still overview. No network or other
file is needed to view a copied or published `index.html`. A WebGL-capable
browser is required for the interactive views; the embedded overview remains
available without WebGL.

Select The Accord or The Throng, then one of that faction's three builders.
Drag any scene to rotate all four, use the wheel to zoom, right-drag to pan,
or use the five camera presets. Touch supports one-finger orbit and two-finger
pan/pinch. Clicking a block names its node, cell and param2. The guard-position
button adds inspection markers; they are not part of the templates.

[The overview PNG](renders/overview.png) contains gate-quarter, far-side and
top views of all three variants in Human and Orc materials. The 18 individual
PNGs in `renders/` are 1200 × 900. The interactive page supplies the other
four palettes. The stills are software renders of the shared viewer's actual
triangles, textures and vertex shading, not drawings of an imagined result.

## Rebuild

From the repository root, with Python 3, Pillow, numpy and LuaJIT installed:

```sh
python3 tools/r69_camp_art/build.py
python3 tools/r69_camp_art/build.py --check
```

`--check` compares the 18 generated templates, the resolved node inventory
and the single-file HTML byte for byte. It also runs both existing Python
template parsers and the game's existing Lua parser, resolves and stamps all
six palettes at all four rotations (72 stamps), and checks the authored
floor, box, central yard, exact socket positions/faces and flat gate routes.
`--templates-only` omits the page and the baseline blueprint export.

To regenerate the stills after changing the composition (Node.js is used
only to execute the existing viewer's geometry builder):

```sh
python3 tools/r69_camp_art/build.py
python3 tools/r69_camp_art/render.py
python3 tools/r69_camp_art/build.py
python3 tools/r69_camp_art/build.py --check
```

The first build supplies the geometry payload; the last embeds the refreshed
overview. `render.py --variant first_lift --race human` limits a render.
Independent variant jobs may use `--no-overview`; assemble the overview once
after all jobs finish. No browser or game/server process is used by these
commands. Temporary Lua adapters call existing readers; no Lua file is added
to the repository and no game file is written.

## Candidate contract

The eighteen ordinary files are
`candidates/<wallwright|first_lift|panel_yard>/camp_site_<race>.tpl`.
Each variant has one symbolic composition, with no race-specific geometry.
Race palette roles supply the ground, masonry, timber and roof materials;
stockade and cap nodes take the race, canvas trims and banners the faction.

Each template writes all **5290 cells**: origin `-11 0 -11`, size
`23 10 23`, extent `[-11,-11,11,11]`. Unoccupied cells explicitly write air.
The entire y=0 floor is solid. All five `camp_points` and their faces are
unchanged, the central 5 × 5 × 3 yard is empty, and a flat route with two
clear cells connects the gate to every socket. The gate and command standard
have overhead banner supports. No containers, timers, fire, water, lava,
working lift or new nodes/textures occur in a candidate.

The pivot `23 23` follows the existing mining-camp templates. As in
`r63_camp_blueprint.lua`, integration must rotate about the camp's origin,
not a town plot's corner. The native validation subtracts the footprint
rotation's origin offset before stamping, preserving the centred box.

The exact resolved node lists, grouped by variant and race, are in
[nodes.json](nodes.json). Material/callback facts were checked in the palette,
camp-node definitions, the static cottages furniture and rope definitions,
the darkage block registrations and the registry snapshot. The generic
template integration gate, migration and runtime checks belong to lane CAMP.

## Viewer adaptations and provenance

The shared `tools/building_templates/viewer` parser, cell packing, texture
export, B3D parsing and node geometry renderer are reused unchanged on disk.
There are two bounded export adaptations in this folder:

1. Round 63's animated canvas and banner B3D files use ten engine units per
   node and one mesh buffer per `TRIS` chunk. The static shared B3D reader
   leaves raw units and groups chunks by brush id; all three banner chunks
   have brush `-1`. Temporary distinct brush keys preserve their tile order,
   and xyz coordinates are divided by ten. UVs are preserved. Source:
   `tools/r63_camp_art/build.py`, `b3d()` and `validate_b3d()`; resulting
   buffer counts are one for canvas and three for banner cloth/wood/iron.
2. Offline HTML embeds the repository's already-vendored Three.js r147 from
   `tools/r54_armor/vendor/three.min.js`. The two r160 color-space property
   assignments in the shared renderer are translated to their r147 encoding
   equivalents in the generated page. `orbit.js` supplies local controls.

Three.js is MIT-licensed; [the licence](THREE-LICENSE.txt) is also embedded
in the HTML. Existing game textures/meshes retain their repository licences
in `LICENSE-media.md` and `CREDITS.md`. No third-party code was downloaded.
The geometry exporter uses the shared renderer up to its scene setup and
returns the constructed triangles without creating WebGL or browser objects.

## Review limits

A real browser could not be launched in this sandbox: Chromium failed before
page load on denied socket operations. JavaScript syntax, all 24 geometry
exports, image decoding and standalone asset references were checked; actual
browser interaction is **not certified**. The PNGs were inspected directly.
Terrain, NPCs, real game lighting and world integration are not simulated.
No fixtures, server boots or Lua game changes were made, as requested.

This is **compatible tooling only**. The selected live-world composition and
the Round 69 migration are lane CAMP's separate work. The coordinator's
independent review and the user's pick remain pending; nothing was merged
or pushed.
