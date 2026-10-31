# Round 67 EMBLEM — media provenance

## Original candidates

The six emblem motifs, their two-colour UI artwork and the repainted
banner RGB artwork are original geometry authored for Grudgelands by
GPT-6 Astra on 2026-10-31. They are generated with Python, Pillow and
numpy, without external images, image-generation services or font glyphs.

The project dedicates any rights it holds in this original artwork to
**CC0-1.0**, to the extent such rights exist. The generator and HTML source
follow the repository code licence, **GPL-3.0-or-later**.

| Files in `candidates/` | Count | Construction |
|---|---:|---|
| `emblem_{accord,throng}_{a,b,c}.png` | 6 | Original silhouettes and light facets; 100 × 100 RGBA; sixfold supersampling. |
| `banner_{accord,throng}_{a,b,c}.png` | 6 | Original motif silhouettes in ivory on blue/red cloth, with a dark edge and one hem; 128 × 256 RGBA. |

The banner **alpha channel only** is retained byte for byte from the
corresponding shipped `grug_mapgen_faction_banner_*.png` to preserve the
existing cloth cut and model UV footprint. These original Round 63
generator outputs are already CC0-1.0 in the
[mapgen media ledger](../../mods/MAPGEN/grug_mapgen/LICENSE-media.md).
No RGB pixels from those textures enter the candidates.

Candidate files in `preview/` are byte-identical copies. `view_*_{a,b,c}.png`
projects these candidates onto the existing banner mesh, preserving its
CC0-1.0 geometry attribution. The drawn support pole and beam are original
review-only geometry, also CC0-1.0.

## Comparison and preview assets

References are copied byte for byte. Their existing media ledgers remain
authoritative; `manifest.json` records source paths and SHA-256 hashes.

| Preview files | Source and existing attribution |
|---|---|
| `ref_emblem_*.png` | `mods/PLAYER/grug_inventory/textures/grug_inventory_faction_*.png`; [inventory media ledger](../../mods/PLAYER/grug_inventory/LICENSE-media.md), CC0-1.0. |
| `ref_banner_*.png` | `mods/MAPGEN/grug_mapgen/textures/grug_mapgen_faction_banner_*.png`; [mapgen media ledger](../../mods/MAPGEN/grug_mapgen/LICENSE-media.md), CC0-1.0. |
| `ref_class_*.png`, `ref_race_*.png` | `mods/PLAYER/grug_classes/textures/grug_{class,race}_*.png`; [class media ledger](../../mods/PLAYER/grug_classes/LICENSE-media.md), CC0-1.0. |
| `view_*_current.png` | The above current banner textures on `mods/MAPGEN/grug_mapgen/models/grug_mapgen_faction_banner.b3d`; [mapgen media ledger](../../mods/MAPGEN/grug_mapgen/LICENSE-media.md), CC0-1.0. |
| `contact.png` | Review compilation of the original candidate icons and projections; labels rasterized with Pillow's bundled default font. No font file is distributed. |

The projection's rod and straps use illustrative flat colours, without
importing wood or strap texture pixels. It is an offline approximation,
not an engine capture.

After the user's choice, the coordinator copies only the chosen
candidates and records this provenance in the receiving mods' media
ledgers. These proposals do not replace the shipped emblem ownership or
its documented design.
