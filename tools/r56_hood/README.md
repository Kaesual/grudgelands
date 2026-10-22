# Round 56 hood (polygon part)

`hood.json` is the hood's polygon part in the schema of
[armor-format.md §1a](../../docs/technical/armor-format.md#1a-polygon-parts-round-56), exported by the hood workshop
page (Round 56 HOODPAGE). The user accepted the page's first shape unchanged (2026-10-22): these are the final
values.

Lane HOOD built the pipeline from it (polygon parts in `tools/r54_armor/`, the models, the chin strip; see
[`tools/r54_armor/README.md`](../r54_armor/README.md)). `portable_test.lua` is the lane's fixture: the hood's
atlas place below the boxes, the hood in the armor buffer of both models (schema points, normals, atlas UVs, the
Head bone, fanned triangles wound outward) and the shipped tier selection (metal never names the hood; a tier that
does names the helm too).

The headless shots (plan §6): `shots.py OUT` writes the probe media (per cloth and leather tier a 128 × 64 layer
with only the placeholder hood of `tools/r54_armor/test_art`, in the tier's shipped palette, and the bald human
skin); `scene.lua` is a scene for `tools/r54_model/capture.sh` (`MODELS=OUT SCENE=tools/r56_hood/scene.lua`,
through the shared Lua queue): the cloth and leather head pieces at T1, T3 and T6 (shipped head layer with the chin
strip, placeholder hood over it) and the metal T3 helm, from the front, the side and the back, and nodding 50°
down and 60° up. Test art only, never in `mods/`.

## Painting in views

The sheet keeps each of the eight faces as its own rectangle in its own orientation, so neighbours on the head lie
far apart on the sheet. `views.py` (Round 56 HOODPAINT; Python 3 and Pillow) lets a painter paint the hood as one
sees it and projects the views onto the faces:

```sh
python3 tools/r56_hood/views.py templates OUT              # side.png, back.png, top.png to paint; *_8x.png guides
python3 tools/r56_hood/views.py project side.png back.png top.png -o hood_a.png   # the 64x12 sheet
python3 tools/r56_hood/views.py preview hood_a.png --views side.png back.png top.png -o preview.png
python3 tools/r56_hood/views.py demo OUT                   # an example view set, its sheet and its preview
python3 tools/r56_hood/views.py --selftest                 # the tool's tests
```

- **The views** (one pixel = one skin pixel, a margin of one pixel round the hood): **side**, seen from the
  character's right: the back on the left, the front on the right, rows top down; it paints both sides (the left
  faces sample it mirrored). **back**, seen from behind: the character's left on the left. **top**, seen from
  above: the back edge at the top, the character's right on the left (as the top faces lie on the sheet).
- **What to paint:** the 1× templates have every pixel some face samples tinted (one tint per face, as on
  `tools/r54_armor/templates/parts/hood.png`; the darker tint where only bleed texels sample, painted like its
  neighbours), the helm shell and the head in grey for orientation. Paint every tinted pixel with the reference
  colours (`tools/r54_armor/templates/palette.png`), opaque; everything else is ignored. The `*_8x.png` guides add
  the face edges (magenta), the hood's silhouette (black), the helm and head outlines, and hatch what is seen in
  this view but painted in another (the side faces seen from behind and from above). `--scale N` draws the guides
  and the preview at N× instead of 8×.
- **Projection:** every texel of every face rectangle, bleed included, takes the 3D point of its centre through
  the face's uv map (from `hood.json`) and the colour of the view pixel it falls in. The face's outward normal picks
  the view: the dominant axis, x the side view, −z the back view, +y the top view (ties x before z before y; a face
  facing the front or down has no view and is refused). The sheet is written only when every sample is an opaque
  reference colour; otherwise each bad sample is listed with its face, texel and view pixel. The result passes
  `tools/r54_armor/check.py` as a hood sheet, and can still be touched up by hand.
- **Preview:** the sheet rendered from the three views (orthographic, flat colours, next to the painted views when
  `--views` is given, with any pixel that differs framed), three shaded three-quarter views and the sheet at 8×.
  On the character: put the sheet into an art directory and run `tools/r54_armor/render.py` as usual.
- **Self-test:** the view rule; the seams (a view set whose pixels encode their own coordinates: at every point of
  every edge two faces share, the two touching texels sample within one pixel of the edge and of each other); the
  mirrored side faces sample the same pixels; a uniform view set gives a uniform sheet; the unpainted template,
  a transparent and an off-palette pixel are refused with face and texel; a random view set rendered back from
  each view matches the painted view; the projected sheets pass `check.py` in a copy of `tools/r54_armor/test_art`.
- The tool reads the geometry from `hood.json` (`--part FILE` for another schema file) and the shell and head boxes
  from `tools/r54_armor/data/catalog.json`; a new hood shape needs no change here. Test art only: nothing in
  `mods/` changes.
