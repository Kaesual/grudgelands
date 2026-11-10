# Lower throne study — 2026-11-10

**Proposal only; no shipped geometry changed. Compatible, tools only.** Installing
these changed world-generation templates later requires a map-reset classification
unless the coordinator establishes an explicitly approved upgrade-contract exception.

Open `index.html` for the self-contained before/after comparison. `scenes.html`
contains the interactive shared web renderer, with orbit, zoom and the saved camera.
Both PNGs in `renders/` use the same 1200 × 1000 camera and the same cropped Highcourt
hall. The geometry, materials, and textures come from the shipped templates and
registry; pixel filtering is nearest-neighbour. This is a geometry preview, not a
Luanti client screenshot or a simulation of its lighting.

## Finding and proposal

The material described as gold is actually `grug_materials:bronze_block`.
The existing chair is built in `tools/r70_castle/build.py:125–151` and installed in
the six capital hall templates listed with source hashes in `measurements.json`.
All six source templates were byte-identical to main when this study was built.

| Measurement | Shipped | Proposal |
|---|---:|---:|
| Width × depth | 5 × 3 | 5 × 3 |
| Full chair height above dais | 7 | 6 |
| Upholstered seat width × depth | 3 × 2 | 3 × 2 |
| Seat surface above dais | 2 | 1 |
| Arm top above seat | 1.5 | 1 |

The dais surface is y=4.5. The original solid bronze base occupies y=5; cloth
occupies y=6, with its top at 6.5. The proposal removes the base and translates the
remaining chair down one node. It removes the half-node bronze arm caps as well,
so that the remaining full blocks end at y=6.5, one node above the new seat at 5.5.
The back, all five ornamented metal stones, and crown descend together. The original
open gaps below the rear arms remain. The dais and its steps are unchanged.

The pale reference figure is a neutral silhouette from the shared body catalogue,
scaled to **2.72 nodes high**, the king's final collision height. It is deliberately
placed beside the chair for comparison; it is not the king's actual visual mesh,
texture, socket, or collision width. The game computes the king's final scale as
(8/7) × elite 1.4 = 1.6 (`mods/ENTITIES/grug_mobs/bosses.lua:628–635`). His collision
width is 0.96. The actual king socket stays at (22,5,27), with settled feet at 4.5.

## Editable artifacts and verification

- `build.py` reads shipped sources and creates six full `.tpl` proposals in `variants/`.
- Each proposal changes exactly 42 cells, confined to x 20…24, y 5…11, z 28…30.
- All template points, including king/guard sockets, are unchanged.
- All six palettes resolve without missing nodes; seat cells remain cloth.
- The king's 0.96 × 2.72 collision volume remains clear in both variants (a conservative
  full-node intersection check, covering the initial and settled vertical positions).
- The shared renderer reports no skipped nodes, missing meshes or missing textures.
- Capture receipts record scene-input hashes, output PNG hashes, camera, size and browser.
- Both final PNGs were visually inspected. No gameplay or pathfinding claim is made.

From the worktree root:

```sh
python3 tools/capital_polish_study/throne/build.py
node tools/character_creation_preview/render-scenes.mjs \
  --directory tools/capital_polish_study/throne --width 1200 --height 1000
python3 tools/capital_polish_study/throne/build.py
```

The last build embeds the PNGs only when their receipts match the current scene
inputs. Chromium uses its own disposable profile; no game world is started.
Existing texture licences remain unchanged; provenance is the shipped node registry
and corresponding mod media notices. No new artwork is imported.
