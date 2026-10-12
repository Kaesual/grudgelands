# Round 46 ART — Repair marker proposals

Four original proposals, three corrected A takes, two heavier A1
anvils and two closer-hammer A1a takes, original AI-assisted pixel art
by **GPT-6 Astra** for Grudgelands,
created on 2026-10-12.
Offered under **CC0 1.0 Universal
(CC0-1.0)**: the project dedicates any rights it holds in these originals
to CC0. No downloaded artwork or third-party source images were used.

The latest [closer-hammer comparison](repair/overview-a1c.png) places
**A1a, A1c and A1d** among the existing service markers on all three
backgrounds. The earlier [A1 comparison](repair/overview-a1.png) places
**A1, A1a and A1b** among the same markers.
The earlier [local review page](review.html) still compares A1–A3 and
prepares a choice to send back. Nothing is preselected. The page works
offline and does not submit or install anything. The [A comparison](repair/overview-a.png)
places the original A and its three hammer corrections among the existing
service markers. All earlier sprites, previews, overviews and the review
page remain unchanged.

## A1a closer hammer — fix round 3

The user picked A1a and requested a smaller gap between hammer and anvil.
Both takes translate the complete hammer straight down, keeping its exact
head, shaft length, angle and colours. A1a's heavy anvil stays pixel-identical.

| Take | Change | Sprite | Preview |
| --- | --- | --- | --- |
| A1c | The complete A1a hammer moves down exactly one pixel. | [16×16](repair/A1c/grug_map_repair.png) | [Comparison](repair/A1c/preview.png) |
| A1d | The complete A1a hammer moves down exactly two pixels; the grip's dark end meets the anvil's dark top edge. | [16×16](repair/A1d/grug_map_repair.png) | [Comparison](repair/A1d/preview.png) |

In A1d, two identical dark contour pixels coincide at `(12, 9)` and
`(13, 9)` (zero-based); no steel or wooden fill is covered or repainted.
The head remains above the face: with the approved angle and full shaft
preserved, the grip reaches the anvil first. Both takes retain the five
opaque colours and transparent 16×16 canvas. All earlier artwork and the
review page remain unchanged. These proposals use the same CC0 dedication.

## A1 heavier anvils — fix round 2

The user preferred A1's raised hammer but found its anvil too thin.
Both new takes give the anvil a stepped horn on the left, a deep steel
body, a solid six-pixel waist and a broad foot. They retain the one-pixel
contour, the same five opaque colours and the frameless silhouette,
distinct from the Weaponsmith's framed sword and the Armorsmith's framed
chestplate.

| Take | Change | Sprite | Preview |
| --- | --- | --- | --- |
| A1a | A1's hammer is pixel-identical; the anvil grows downward to the bottom row, with three steel rows between its outlines. | [16×16](repair/A1a/grug_map_repair.png) | [Comparison](repair/A1a/preview.png) |
| A1b | The same hammerhead and shaft angle, with one 2:1 shaft step removed; the anvil starts one row higher and has four steel rows, making it the dominant shape. | [16×16](repair/A1b/grug_map_repair.png) | [Comparison](repair/A1b/preview.png) |

A1a retains the original blank row below the hammer and the original
anvil top height. A1b also keeps one clear row between hammer and anvil.
Both feet reach row 16; every sprite remains on a transparent 16×16 canvas.
These are review proposals for the user's choice, under the same CC0
dedication above.

## A corrections

The user preferred A's hammer-over-anvil composition but found the head
rounded and the handle too short. These takes replace it with a compact,
straight-edged steel head across a long, straight wooden shaft. The shaft
from the head's centre to the grip is about twice the head's length.
The diagonal shafts use a 2:1 pixel step (about 27 degrees); their heads
lean across them. The head ends are squared, without A's rounded underside.

| Take | Pose | Sprite | Preview |
| --- | --- | --- | --- |
| A1 | Raised head on the left, with the long shaft sloping down to the right. | [16×16](repair/A1/grug_map_repair.png) | [Comparison](repair/A1/preview.png) |
| A2 | Horizontal shaft just above the anvil, across a rectangular, upright head. | [16×16](repair/A2/grug_map_repair.png) | [Comparison](repair/A2/preview.png) |
| A3 | Head lowered to the anvil face, shaft rising right, with two pale spark pixels. | [16×16](repair/A3/grug_map_repair.png) | [Comparison](repair/A3/preview.png) |

All three keep A's outline and five opaque colours. The anvil keeps A's
face, neck and foot; removing one bevel row makes room above it. These
frameless tool silhouettes remain separate from the Weaponsmith's framed
sword and the Armorsmith's framed chestplate. The sparks in A3 are painted
pixels only, with no runtime particle effect.

## Original proposals (unchanged)

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
- `repair/{A1,A2,A3}/grug_map_repair.png`: three 16×16 RGBA sprites with
  transparent backgrounds, binary alpha and five opaque colours each.
- `repair/{A1,A2,A3}/preview.png`: three 1280×870 RGBA comparison sheets.
- `repair/overview-a.png`: original A and A1–A3 on a 1280×870 RGBA sheet.
- `repair/{A1a,A1b}/grug_map_repair.png`: two 16×16 RGBA sprites with
  transparent backgrounds, binary alpha and the same five opaque colours.
- `repair/{A1a,A1b}/preview.png`: two 1280×870 RGBA comparison sheets.
- `repair/overview-a1.png`: A1, A1a and A1b on a 1280×870 RGBA sheet.
- `repair/{A1c,A1d}/grug_map_repair.png`: two 16×16 RGBA sprites with
  transparent backgrounds, binary alpha and the same five opaque colours.
- `repair/{A1c,A1d}/preview.png`: two 1280×870 RGBA comparison sheets.
- `repair/overview-a1c.png`: A1a, A1c and A1d on a 1280×870 RGBA sheet.
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

The check compares all twenty-six PNGs with the generated pixels, dimensions
and modes, and checks that the eleven sprites differ, have binary alpha,
are 16×16 RGBA and use at most six opaque colours. Preview scaling is
nearest-neighbour throughout. View the HTML at 100% browser zoom for its
16 CSS-pixel samples; the PNG sheets preserve exact 1× and 4× source sizes.

**Upgrade classification: compatible.** This lane adds review artwork and
its provenance only. No game code, files under `mods/`, saved state or
upgrade declarations change. The user's pick and the later map/minimap
integration belong to lane RP. Runtime desktop/web acceptance follows
that integration.
