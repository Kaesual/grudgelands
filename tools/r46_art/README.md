# Round 46 ART — Repair marker proposals

Four original, AI-assisted pixel-art proposals by **GPT-6 Astra** for
Grudgelands, created on 2026-10-12. Offered under **CC0 1.0 Universal
(CC0-1.0)**: the project dedicates any rights it holds in these originals
to CC0. No downloaded artwork or third-party source images were used.

Open [the local review page](review.html) to compare A–D and prepare a
choice to send back. Nothing is preselected. The page works offline and
does not submit or install anything. The [overview](repair/overview.png)
places all four proposals among the existing service markers.

| Variant | Take | Sprite | Preview |
| --- | --- | --- | --- |
| A | A light hammer above a low steel anvil; the diagonal wooden handle separates it from the Crownbinder's gold crown. | [16×16](repair/A/grug_map_repair.png) | [Comparison](repair/A/preview.png) |
| B | An open wrench crossed with a small hammer; the fork and solid hammerhead distinguish the tools from the Tailor's scissors. | [16×16](repair/B/grug_map_repair.png) | [Comparison](repair/B/preview.png) |
| C | A split shield joined by three brass staples, with a broad pointed silhouette distinct from the Armorsmith's framed chestplate. | [16×16](repair/C/grug_map_repair.png) | [Comparison](repair/C/preview.png) |
| D | A diagonal blade joined by a brass strap with pale rivets, distinct from the Weaponsmith's upright framed sword. | [16×16](repair/D/grug_map_repair.png) | [Comparison](repair/D/preview.png) |

## Files and construction

- `repair/{A,B,C,D}/grug_map_repair.png`: four 16×16 RGBA sprites with
  transparent backgrounds, binary alpha and five or six opaque colours.
- `repair/{A,B,C,D}/preview.png`: four 1280×870 RGBA comparison sheets.
- `repair/overview.png`: one 1280×870 RGBA overview.
- `paint_art.py`: reproducible Python/Pillow generator and source pixel grids.
- `review.html`: local selection page; all assets are relative local paths.

Every sprite pixel is authored in a character grid at native resolution;
there is no downsampling, smoothing, dithering or image-generation service.
The dark contour (`#19150F`) follows the existing standalone service
markers. Steel, brass, wood and pale highlights follow the shipped trainer
palette; the steel shadow follows the Crownbinder. Free silhouettes help
separate the repair service from the framed trainer emblems.

Each sheet shows the proposed icon next to all eight trainer icons,
Innkeeper, Decor Merchant, Housing Steward, Home and Crownbinder. Every
background has a 1× row and a 4× row using nearest-neighbour scaling.
The backgrounds are exact base colours from the current map:

| Swatch | Colour | Local source |
| --- | --- | --- |
| Light world-map terrain | `#C6C280` | `mods/PLAYER/grug_map/base.lua`, `REGION.human` |
| Green grassland | `#86B274` | `mods/PLAYER/grug_map/base.lua`, `REGION.troll` |
| Dark minimap | `#1C3A52` | `mods/PLAYER/grug_map/minimap.lua`, `SEA` |

These are flat comparison swatches, not runtime screenshots. Existing
service icons and the project's map lettering appear only as comparison
and caption material; their existing CC0 provenance remains in
`mods/PLAYER/grug_map/LICENSE-media.md`. The generator reads those files
without changing them. No new licence rows are added there: lane RP will
add the picked repair file's row when it integrates the user's choice.

## Reproduce and validate

From the repository root, with Python 3 and Pillow installed:

```sh
python3 tools/r46_art/paint_art.py
python3 tools/r46_art/paint_art.py --check
```

The check compares all nine PNGs with the generated pixels, dimensions
and modes, and checks that the four sprites differ, have binary alpha,
are 16×16 RGBA and use at most six opaque colours. Preview scaling is
nearest-neighbour throughout. View the HTML at 100% browser zoom for its
16 CSS-pixel samples; the PNG sheets preserve exact 1× and 4× source sizes.

**Upgrade classification: compatible.** This lane adds review artwork and
its provenance only. No game code, files under `mods/`, saved state or
upgrade declarations change. The user's pick and the later map/minimap
integration belong to lane RP. Runtime desktop/web acceptance follows
that integration.
