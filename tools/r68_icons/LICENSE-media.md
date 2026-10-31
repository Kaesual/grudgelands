# Round 68 ICONS — media provenance

## Original candidates

All 141 PNG files in `candidates/` are original pixel drawings authored for
Grudgelands by **GPT-6 Astra on 2026-10-31**. They are drawn entirely by
[art.py](art.py), called by [generate.py](generate.py), using Python, Pillow
and numpy. No source sprite pixels, external images, fonts or generated
bitmap sources enter a candidate. The colour ramps were inspected against
the shipped gear and trinkets; all silhouettes and surface marks are new.

The project dedicates any rights it holds in these original assets to
**CC0-1.0**, to the extent such rights exist. Both Python files are
**GPL-3.0-or-later**, following the repository code licence.

| Candidate paths | Count | Construction |
|---|---:|---|
| `bars_{a,b}/*_bar.png` | 20 | Transparent 16 × 16 RGBA ingots: A tapered castings, B broad billets. |
| `bars_{a,b}/*_block.png` | 20 | Opaque 16 × 16 RGBA node faces: A solid cast faces, B stacked billets. |
| `settings_{a,b}/setting_*.png` | 12 | Transparent 16 × 16 RGBA empty mounts: A loose bezels, B ring blanks with open prongs. |
| `gems_{a,b}/{rough,cut}_*.png` | 24 | Transparent 16 × 16 RGBA gems: six rough specimens and six distinct polished cuts per variant. |
| `gems_{a,b}/{quartz,abyssal_crystal}.png` | 4 | Transparent 16 × 16 RGBA raw minerals, with no cut counterparts. |
| `gems_{a,b}/*_block.png` | 14 | Opaque 16 × 16 RGBA gem/crystal faces: A broad facets, B stepped slabs. |
| `gems_{c,d}/cut_*.png` | 12 | Transparent 16 × 16 RGBA regular cuts: C a clipped step family, D distinct classic silhouettes. |
| `gems_{c,d}/*_block.png` | 14 | Opaque 16 × 16 RGBA faces: C parallel bevels, D broad crown planes. Both Abyssal Crystal blocks are byte-identical to A. |
| `gems_final/rough_*.png` | 6 | A's natural forms redrawn larger on the 16 px grid, preserving the colour ramps, fracture cues and upper-left light. |
| `gems_final/{quartz,abyssal_crystal}.png` | 2 | A's two-prism Quartz and three-pronged Abyssal Crystal cluster redrawn at the same larger specimen scale. |
| `gems_final/cut_*.png` | 6 | Byte-identical copies of the picked D cuts. |
| `gems_final/*_block.png` | 7 | Byte-identical copies of the picked D blocks, including the unchanged A-origin Abyssal Crystal face. |

C/D reuse A’s six rough gems, Quartz and Abyssal Crystal unchanged from
`gems_a/`; these eight files are not duplicated or rescaled. All original
A/B candidate files remain byte-identical to pass 1.
Pass 3 keeps all 120 A/B/C/D candidate files byte-identical to pass 2;
only `gems_final/` adds assets. [INSTALL.md](INSTALL.md) lists the 47 picked
files across bars A, settings B and final gems, with the owning mods'
required licence rows.

The block textures are opaque because they cover solid node faces; the
item icons have transparent backgrounds. Candidate coordinates use only
integer pixels, without antialiasing or resampling.

## Palette and style context

The source images below are inspected as context; **none is copied into
a candidate**:

- `mods/ITEMS/grug_gear/textures/grug_gear_item_head_metal_<metal>.png`:
  Bronze's ochre, Silversteel's cool pale metal and the dark higher metals.
- `mods/ITEMS/grug_gear/textures/grug_gear_item_sword_<metal>.png`:
  warm grey Iron, neutral Steel, fire-bright Embersteel and dark Abyssal Steel.
- `mods/ITEMS/grug_gear/textures/grug_gear_trinket_battlebeat_t<tier>.png`:
  the six tier metals and copper/gold trim, as drawn by the Round 45 B
  palette in `tools/r45_a1/paint_art.py`. Settings use these exact metal ramps.
- `mods/ITEMS/grug_materials/textures/grug_materials_anthracite_lump.png`:
  the sparse glints, dark coloured contour and upper-left light direction.

The preview embeds the six shipped armour helmets and six shipped
Battlebeat trinkets unchanged as palette context. Their existing CC0-1.0
provenance remains with `mods/ITEMS/grug_gear/LICENSE-media.md`.

## Current comparisons — separate from candidate art

The 47 images in `preview/current/` reconstruct the shipped texture
expressions from `grug_materials/ores.lua` and `grug_artisans/goldsmith.lua`.
[current_sources.json](current_sources.json) records the exact expression,
source path and SHA-256 for each. The engine's colour interpolation and
brighten operations are transcribed in the generator; the PNGs are not
game screenshots.

These vendored source textures are **CC BY-SA 3.0**. The attribution record
is `mods/BASE/default/README.txt`; the licence notice is
`mods/BASE/default/license.txt`.

| Source under `mods/BASE/default/textures/` | Credited author |
|---|---|
| `default_gold_ingot.png`, `default_diamond.png` | BlockMen |
| `default_steel_ingot.png` | BlockMen; the vendored README credits the older filename `default_iron_ingot.png`. |
| `default_copper_ingot.png`, `default_bronze_ingot.png` | Gambit |
| `default_tin_ingot.png` | kilbith |
| `default_{copper,tin,bronze,steel,gold}_block.png` | kilbith |

Modifications are the shipped colour modifiers and brighten operation;
comparison contact sheets add layout, labels and nearest-neighbour scaling;
wall studies repeat the face and shade its top and side. Those comparison
derivatives retain **CC BY-SA 3.0**, not CC0. Inlined current images and
walls on the preview page have the same attribution and licence. The
original candidates remain individually available under CC0-1.0.

The applicable vendored media licence notice is reproduced beside the
preview as [comparison-license.txt](preview/comparison-license.txt). It
contains the original attribution and the licence URL. The preview HTML
contains no external URLs, network resources or scripts.

## Preview text and layout

The preview is generated from `generate.py`. Browser text uses system
fonts; no web fonts are downloaded. Contact sheet labels use Pillow's
built-in default font; these sheets are comparison documents, never
candidate textures. The HTML's embedded images make the page itself
self-contained; retain the licence notice when publishing the directory.
