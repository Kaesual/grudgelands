# Wide character creation scenes

Round 80.1 SCENES, prepared for visual approval. Open [index.html](index.html)
directly, or serve the repository root. Select a race; toggle layout guides and
the projected bare-body silhouette. Expand the 1366 × 768 and 2560 × 1440 views
for exact CSS sizes. The page shows the committed website copies in
`tools/web_data/media/`. `check-page.mjs` writes `preview-<race>.png` (ignored
build output), each page at 1600 × 1120 with both overlays on and the unchanged
game image beside it.

## Rebuild

From the repository root (Python 3 + Pillow, LuaJIT, Node 24, Chromium):

```sh
python3 tools/character_creation_preview/wide/build.py
python3 tools/character_creation_preview/wide/render.py --chrome /usr/bin/chromium-browser
python3 tools/character_creation_preview/wide/proof.py --chrome /usr/bin/chromium-browser
python3 tools/character_creation_preview/wide/build-page.py
node tools/character_creation_preview/wide/check-page.mjs
python3 tools/character_creation_preview/wide/render.py --check
```

The builder calls the existing short LuaJIT palette/tree exporters (base and
wide-layer tree seeds), not an engine or fixture. It uses an optional variant
callback to `scenery.main`;
default callers keep their original geometry. `native.build(write_camera=False)`
calibrates the proof cameras without writing the game camera. Disposable embedded
viewers live in `.build/`, `scenes.html` and `proof/*/scenes.html` (ignored).
Retained build/scene receipts pin the inputs; per-image receipts in `renders/`
pin the camera, dimensions, sRGB declaration, PNG hash and `figure`. The PNGs
beside them (`renders/*.png`, `proof/*/renders/*.png`) are ignored build output;
the committed pictures are the six media copies.

The render command first seeds a missing `renders/<race>.png` from its media
copy, so `render-scenes.mjs` recaptures only scenes whose input changed. It then
emits the six `tools/web_data/media/grug_creation_<race>_wide.png` files
byte-identically, `media/wide.json` in EXPORT's exact six-race shape, and
the race section of `media/LICENSE-media.md`. It preserves everything after the
INTRO marker. PNG normalization removes opaque alpha and adds the sRGB chunk;
RGB pixels are unchanged. `--check` works without Chromium, intermediate HTML or
the ignored renders: it verifies the committed media PNGs against their receipts
(and a local render only when one exists), exits 1 on stale sources/receipts, a
changed shipped image, incorrect dimensions, colour space, anchors or licence
hashes, and does not write files.

Chromium 156 hung during shutdown after the initial multi-scene captures.
The shared capture script now isolates XDG paths and the browser process group,
requests graceful shutdown, then reaps only that group. Its five-second grace
period applies only after capture, never to rendering. Final runs exited cleanly.

## Composition and anchors

Each separate `../scenes/wide/<race>.json` supplies its wide camera, lateral
terrain bounds and authored tree placements (`species`, `seed`, `at`).
The layer continues the original ground from x = ±42 to ±76,
keeping the boundary height, surface and soil. Whole new columns must lie
outside the native camera's horizontal frustum, with a 2% margin. Every base
cell remains identical. Existing buildings, trees, props, fog, sky and tint
are reused.

The added trees form uneven clumps on the side slopes and smaller groups or
single silhouettes on the far ridges. Only species already in each base scene
are used, directly from the shipped generator, without scaling or clipping.
Each seed is root-free and has no buried trunk layer, suitable for the existing
hills. The builder checks ground support, rejects every cell collision and
requires each complete tree bounding box to clear the same game-frustum margin.
No tree changes the terrain. Darker right-hand groups stand farther back so the
existing fog softens them behind the list panel. Buildings naturally hide some
trunks and crowns; the additions do not form a continuous screen of trees.

Every race has `figure = {"x": 0.43, "y": 0.811757, "node": 0.24151}`.
The cameras, standing points and `media/wide.json` are byte-identical to the
approved composition before this tree pass.
`x/y` are the projected `portrait.feet`, normalized from the top-left;
`node` is the vertical projection difference between feet and feet + one world
unit. The render camera computes them, rounded to six decimals; the check
independently projects the same points. The silhouette uses the existing body
catalogue and `0.0525 * stature` scale, with full perspective, not a guessed height.

All six cameras have a 55-degree vertical FOV and a geometric horizon at
**30.0000%**. The actual terrain/tree skyline rises above it. The standing point
is on the existing road or deck, inside the requested feet zone. The lower-left
name corner stays on plain ground. Some right-hand building wings fall beneath
the list panel; the preview exposes this for the user's judgement.

| Race | Side continuation and tree groups | Trees added | Added cells | PNG bytes |
|---|---|---:|---:|---:|
| Human | Orchard grass; apple groups beside the houses and distant crowns on both ridges | 10 | 67,360 | 1,280,548 |
| Dwarf | Rocky slopes; uneven pine clumps on the left and more distant pines on the right | 14 | 64,200 | 988,453 |
| Elf | Garden grass; mixed silverwood/aspen edges on both hills, with open gaps | 14 | 68,367 | 1,622,849 |
| Orc | Dry ground; sparse acacia pairs and isolated trees on the side ridges | 8 | 67,450 | 1,011,660 |
| Troll | Wet banks; jungle clumps with hanging vines, fading into the far side hills | 12 | 68,506 | 1,071,785 |
| Undead | Blighted ground; crooked gravewood groups on the left and misty ridge silhouettes on the right | 11 | 64,106 | 889,118 |

All six are 2560 × 1440 RGB PNGs, explicitly sRGB, without figures, text, HUD
or watermarks. Each is below the approximate 2 MB expectation.
The tree counts include crowns partly hidden by the unchanged buildings.

## Proof and scope

- [build.json](build.json): source hashes, unchanged installed image hashes,
  zero modified base cells and zero additions inside the game frustum.
  Tree records include each generated shape's cell count and full bounds.
  Decoded base cells also equal the archived architecture-refresh payload.
  Native camera recipes equal the installed refresh's recipes.
- [proof/comparison.json](proof/comparison.json): all six paired 1540 × 1400
  game-camera renders have **0 differing pixels**, **0 maximum per-channel
  difference**, and no difference bounding box. `proof/diff-<race>.png` is
  black (differences would be amplified 8×). The receipts are retained under
  `proof/base/renders/` and `proof/layered/renders/`; the paired PNGs there are
  ignored build output that `proof.py` captures again.
- The renderer uses fixed face shading, local three-neighbour ambient
  occlusion and the recipe's fixed fog distances (`renderer.js`, face shading,
  `buildGroup`, `selectScene` in `scenes.html.in`). It has no extent-dependent
  light/shadow fit to pin; no renderer setting was changed for the layer.
  The wide builder emits all base cells before additions, preserving the
  order in which texture buckets create materials. Without that ordering the
  first tree-pass comparison changed 28 Troll pixels (maximum channel
  difference 12) on coplanar existing branches: Three.js sorts opaque meshes
  by material id. Preserving base order removes those differences without
  changing the game recipe, camera, renderer or lighting.
- [browser-check.json](browser-check.json): 49 checks pass, six screenshots,
  no JavaScript or console errors (screenshots not committed). Checks cover both
  display sizes, image loads, projected anchor positions, both toggles and page overflow.

Confirmed against the base commit: browser renders through the shared renderer,
original scenes/trees from `scenery.py` and `export-trees.lua`, native calibration
from `native.py`, installed PNGs matching the 2026-11-11 refresh receipts.
The installed render receipts say Chromium 151; this run used Chromium
156.0.8078.79, Node 24.22.3 and Pillow 12.3.0. Therefore the pixel proof compares
two current-browser captures, not the installed historical PNGs.

Classification: **compatible**, tools and website media only. No saved keys,
world state, Lua source or files under `mods/` change. No game-scene recipes
change. No Lua fixtures, engine runs, sync, merge or push were performed.
Visual approval and independent review belong to the coordinator's next step.
Media notice and component provenance: [LICENSE-media.md](../../web_data/media/LICENSE-media.md).
