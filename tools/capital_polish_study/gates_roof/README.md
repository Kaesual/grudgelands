# Capital gate and roof study

2026-11-10. User-requested investigation and proposals only. Open `index.html`
for six receipt-checked stills, `scenes.html` for the self-contained interactive
shared web renderer. Shipped templates, registry and world generation are unchanged.
Classification: **tools only, compatible**. Installing template changes later is a
world-generation change and must be classified under the upgrade contract.

## Findings

Five capitals share the frozen 13 × 7 gate geometry: Highcourt, Dur Brannoc,
Lethariel, Gor Drazhak and Nhal Veyr. Their `*_gate_south.tpl` legends H/I map
`castle_wall_stair` to facedir 1/3. At local x=4/8, y=5, z=0…6 (14 nodes per
unique template), the upper recess points towards the wall and forms a small
horizontal tube. This is separate from the side room's ascending stairs.
Kezamba's `kezamba_gate_house_south.tpl` is a different building with no such arch.
The proposal changes only those 14 cells to facedir 21/23. The current view must
be confirmed by the user before any shipped repair.

All six current castle templates have the same roof profile. At local x=22,
z=8…32, an upside-down roof slab at y=27 occupies [27,27.5]; the ridge block at
y=28 occupies [27.5,28.5]. The adjacent upper slabs x=21/23 end at y=26.5,
leaving a 0.5-node gap. Proposed equivalent 1.5-node group: full roof block at
y=27, normal lower roof slab at y=28. Bounds become [26.5,28], exactly 0.5 lower.
No custom node or fractional template placement is needed. In the cutaway the
neighbouring surfaces meet the ridge at an edge; this is a visual geometry fix,
not a claim about structural simulation.

## Authority and evidence

- `mods/MAPGEN/grug_mapgen/building_templates/templates/*_gate_south.tpl`,
  `kezamba_gate_house_south.tpl`: actual shipped gate layouts and orientations.
- Castle names and exact template/roster hashes: `audit.json`. The builder reads
  each shipped template and its shipped roster palette bindings, not old mockups.
- `tools/r70_castle/build.py`, `Castle.roof`: origin of the shared roof profile.
- `mods/ITEMS/grug_decor/shapes.lua`: actual two-box stairs and lower slabs.
- `mods/BASE/stairs/init.lua`: same standard stair/slab box definitions.
- Read-only engine source at main's `reference_projects/luanti/src/client/mesh.cpp`,
  `rotateMeshBy6dFacedir` (line 267): rotations checked against the renderer's
  `facedirPoint` in `tools/building_templates/viewer/renderer.js`.
- Current main and this worktree's complete template/layout directories compared
  equal during this study; no main files were changed.

Views are bright geometry studies, not engine screenshots. Node registry and
textures are the shared building viewer's; media retains its original licences
under the owning mods. The same camera is used for each before/after pair.
Gold frames are overlays around actual node envelopes. Source geometry is not
replaced. `renders/*.json` records source/output hashes, dimensions and camera.

## Reproduce

From the worktree root:

```sh
python3 tools/capital_polish_study/gates_roof/build.py
node tools/character_creation_preview/render-scenes.mjs --directory tools/capital_polish_study/gates_roof --width 1200 --height 900
python3 tools/capital_polish_study/gates_roof/gallery.py
```

One short LuaJIT invocation loads actual palette bindings. The existing renderer
uses its own disposable Chromium profile, no game server, personal browser
profile or persistent world. The builder asserts all five gate orientation pairs
and all six ridge groups; the gallery verifies every PNG against the scene and
capture hashes. No runtime tests or acceptance are claimed.

## Independent review

`throne_study` reviewed this package read-only on 2026-11-10: PASS, no blocking
findings. Independently checked 70 stair orientations, six sets of 25 ridge pairs,
source hashes, all six capture receipts, PNGs, and before/after geometry. This is
approval of the study's correctness, not user approval to install the proposal.
