# Round 56 hood (polygon part)

`hood.json` is the hood's polygon part in the schema of
[armor-format.md §1a](../../docs/technical/armor-format.md#1a-polygon-parts-round-56), exported by the hood workshop
page (Round 56 HOODPAGE). The user accepted the page's first shape unchanged (2026-10-22): these are the final
values. Lane HOOD builds the pipeline from this file.

Lane HOOD built the pipeline from it (polygon parts in `tools/r54_armor/`, the models, the chin strip; see
[`tools/r54_armor/README.md`](../r54_armor/README.md)). `portable_test.lua` is the lane's fixture: the hood's
atlas place below the boxes, the hood in the armor buffer of both models (schema points, normals, atlas UVs, the
Head bone, fanned triangles wound outward) and the shipped tier selection (metal never names the hood; a tier that
does names the helm too).
