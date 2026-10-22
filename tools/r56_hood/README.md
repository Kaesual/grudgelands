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
