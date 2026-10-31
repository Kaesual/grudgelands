# Round 67 EMBLEM — media provenance

## Original candidates — Pass 4

The three frontal hart heads and three frontal boar heads are original contours authored for
Grudgelands by GPT-6 Astra on 2026-10-31. Their ivory charges, cloth-faced
shields and repainted banner RGB artwork are generated with Python,
Pillow and numpy. No external images, image-generation services or font
glyphs enter a candidate. Pass 4 keeps Pass 2/3's original shield geometry,
ornament and muted cloth treatment; all six frontal drawings are new.
The three pairs use painted, engraved and stitched treatments respectively.

The project dedicates any rights it holds in this original artwork to
**CC0-1.0**, to the extent such rights exist. The generator and HTML source
follow the repository code licence, **GPL-3.0-or-later**.

| Files in `candidates/` | Count | Construction |
|---|---:|---|
| `emblem_{accord,throng}_{1,2,3}.png` | 6 | Authored mirrored head contours and negative-space cuts on muted cloth shields; ivory charges, tarnished-gold detail and borders; 100 × 100 RGBA, sixfold supersampling. |
| `banner_{accord,throng}_{1,2,3}.png` | 6 | The same animals on weathered slate-blue/wine-red cloth with gold vinework, weave, faded edges and rubbed hems; 128 × 256 RGBA. |

The banner **alpha channel only** is retained byte for byte from the
corresponding shipped `grug_mapgen_faction_banner_*.png`, preserving the
cloth cut and model UV footprint. These original Round 63 outputs are
CC0-1.0 in the [mapgen media ledger](../../mods/MAPGEN/grug_mapgen/LICENSE-media.md).
The cloth base is sampled as the most frequent fully opaque source RGB:
#344b5a and #683e39. No source RGB pixel regions or shipped motifs are
copied into candidates. `heraldry.py` owns the drawings and finish;
`generate.py` owns sampling, outputs and mesh projections.

Candidate images in `preview/` are byte-identical copies.
`view_*_{1,2,3}.png` projects them onto the existing banner mesh, retaining
its CC0-1.0 geometry attribution. The review-only support pole and beam
are original geometry, also CC0-1.0.

## Comparison and preview assets

The four `ref_pass3_*.png` inputs are immutable, byte-for-byte copies of
Pass 3's A1 (The Accord) and B3 (The Throng) from commit
`cf2e454a748e15bc0d5da7bda9376a4a3dd8565c`. They retain that pass's
original CC0-1.0 dedication and shipped-alpha attribution. These are the
only retained Pass 3 candidate images, stored solely for comparison;
The other Pass 3 choices and all Pass 1/2 candidates survive only in git history. Their fixed SHA-256
values are checked by the generator.

Shipped references are also copied unchanged. Their existing media
ledgers remain authoritative. `manifest.json` records every source path,
its SHA-256 and, for Pass 3, the source commit.

| Preview files | Source and existing attribution |
|---|---|
| `ref_pass3_emblem_*.png`, `ref_pass3_banner_*.png` | Pass 3 A1/B3 candidates in the above commit; original CC0-1.0 art, with the shipped banner alpha retained. |
| `ref_emblem_*.png` | `mods/PLAYER/grug_inventory/textures/grug_inventory_faction_*.png`; [inventory media ledger](../../mods/PLAYER/grug_inventory/LICENSE-media.md), CC0-1.0. |
| `ref_banner_*.png` | `mods/MAPGEN/grug_mapgen/textures/grug_mapgen_faction_banner_*.png`; [mapgen media ledger](../../mods/MAPGEN/grug_mapgen/LICENSE-media.md), CC0-1.0. |
| `ref_class_*.png`, `ref_race_*.png` | `mods/PLAYER/grug_classes/textures/grug_{class,race}_*.png`; [class media ledger](../../mods/PLAYER/grug_classes/LICENSE-media.md), CC0-1.0. |
| `view_*_{pass3,current}.png` | The corresponding reference textures on `mods/MAPGEN/grug_mapgen/models/grug_mapgen_faction_banner.b3d`; [mapgen media ledger](../../mods/MAPGEN/grug_mapgen/LICENSE-media.md), CC0-1.0. |
| `large_*_{1,2,3}.png` | Six 300 × 300 views from the same original drawing masters; CC0-1.0. |
| `contact.png`, `heads.png` | Review compilations of Pass 4 and reference images; labels use Pillow's bundled default font. No font file is distributed. |

Rod and straps use illustrative flat colours; no wood or strap texture
pixels are imported. Projections are offline illustrations, not engine
captures. After selection, the coordinator copies only the chosen
candidates and records this provenance in the receiving media ledgers.
