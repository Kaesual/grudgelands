# Round 47 ART — Texture proposals

Original pixel art by GPT-6 Astra for the user's selection:
[swamp](#swamp) and [Anthracite](#anthracite).
Each set includes its generator, comparison sheet and per-file provenance
in [LICENSE-media.md](LICENSE-media.md).

## Swamp

Ten original **16 × 16 RGBA PNGs**, made by **GPT-6 Astra** on
2026-10-13, for the swamp browser concept and the user's selection.
The original textures are dedicated to **CC0 1.0 Universal**; the
[media ledger](LICENSE-media.md) records each file and the comparison credits.

Open [the comparison sheet](swamp/preview.png) at 100% to see the native
1× samples: every texture appears at 1× and 8×, on both light and dark
backgrounds, and every repeating texture also appears as a 4 × 4 patch
at 2× pixel scale, without gutters between tiles.
Today's mud and papyrus occupy the first two rows at the same scales.
All enlargement uses nearest neighbour.

### Textures and intended use

| File | Idea |
| --- | --- |
| [mud_dry_top.png](swamp/mud_dry_top.png) | A lighter olive-brown crust with small dry crumbs breaks up the current swamp mud. |
| [mud_dry_side.png](swamp/mud_dry_side.png) | Darker compact earth beneath the dry crust keeps exposed banks grounded in the current mud palette. |
| [mud_mottled_top.png](swamp/mud_mottled_top.png) | Three small, irregular dark water pockets with subdued green reflections interrupt the damp earthen grain. |
| [mud_mottled_side.png](swamp/mud_mottled_side.png) | Dense brown-olive wet soil carries the mottled ground down a bank without putting horizontal water pockets on vertical faces. |
| [wet_grass_top.png](swamp/wet_grass_top.png) | Dark saturated green turf has small muddy openings and a few lighter blade tips. |
| [wet_grass_side.png](swamp/wet_grass_side.png) | A ragged green cap and fine root tips fade into an opaque damp soil face. |
| [moss_carpet_top.png](swamp/moss_carpet_top.png) | Soft olive-green cushions with transparent breaks form a low, patchy carpet over the ground. |
| [reeds.png](swamp/reeds.png) | Thin uneven stalks and short angled leaves use a greyer green than the current papyrus. |
| [cattails.png](swamp/cattails.png) | Three brown seed heads at different heights stand above a sparse fan of green leaves. |
| [hanging_moss.png](swamp/hanging_moss.png) | Pale grey-green strands attach at the top and taper into separated hanging wisps. |

Both mud variants **need their supplied side** to preserve their surface
look; use the side on vertical faces and the bottom. Their tops and sides
repeat on both axes. The wet-grass side is a complete opaque texture,
not an overlay; it repeats horizontally, and its 4 × 4 preview deliberately
shows stacked caps vertically. Use `mud_mottled_side.png` for its bottom.

The moss carpet repeats on both axes and is intended for a thin horizontal
surface or flat plant plane; the proposal supplies only its top. Reeds and
cattails are upright plantlike cutouts with their base at the bottom edge.
Hanging moss attaches at the top edge and should be kept upright below a
branch. The four cutouts use only alpha 0/255, with transparent RGB set to
zero, suitable for alpha clipping. Use nearest filtering in the browser
concept. These are material proposals, not new registered game nodes.

### Generator and provenance

Run from the repository root with Python 3 and the **already installed
Pillow 12.3.0**:

```sh
python3 tools/r47_art/swamp/generate.py
```

[generate.py](swamp/generate.py) is the complete committed source:
fixed palettes, seeded periodic grain, explicitly placed water and grass
clusters, original 16 × 16 plant grids and an original tiny label font.
The script regenerates all ten assets and the comparison sheet. It uses
no downloads or external fonts. It only reads existing artwork inside
the preview function, for the two labelled comparison rows; all new
textures are authored independently from blank canvases.

Palette references inspected locally: `default_dirt`, `default_grass*`,
`default_rainforest_litter*`, `default_papyrus`, `default_junglegrass`,
`default_fern_*`, `default_water*`, `default_mossycobble` under
`mods/BASE/default/textures/`, and
`mods/ITEMS/grug_nodes/textures/grug_nodes_mud.png`.
The requested waterlily is shipped under the renamed paths
`mods/MAPGEN/grug_mapgen/textures/grug_mapgen_waterlily*.png`;
the visible top was inspected there.

### Delivery check

All ten texture PNGs were opened and checked for 16 × 16 dimensions,
8-bit RGBA encoding and their intended opaque/cutout alpha. The
1040 × 2560 RGBA comparison sheet was inspected for both backgrounds,
all scales, edge repeats and silhouette readability. A second generation
reproduced all eleven PNGs byte for byte with the installed tool version.

Upgrade classification: **compatible** (concept art only). Changes are
confined to `tools/r47_art/`; game code, world generation and saved state
are unchanged. No Lua, fixtures or engine runs are part of this art lane.
The user's browser selection and later desktop/web appearance checks
remain with the concept/integration lane.

## Anthracite

Six original **RGBA PNGs**, made on **2026-10-13**, dedicated with their
generator to **CC0 1.0 Universal**. Anthracite has almost-black fractured
faces and sparse blue-grey/silver reflections; its torch combines a dark
glossy head with a white-yellow core, warm amber edges and a thin blue base.

| File | Size | Intended appearance |
| --- | --- | --- |
| [anthracite_lump.png](anthracite/anthracite_lump.png) | 16 × 16 | An angular black lump with two broken conchoidal reflection ridges, distinct from Coal's matte rounded lump. |
| [mineral_anthracite.png](anthracite/mineral_anthracite.png) | 16 × 16 | Four uneven glossy black inclusions with transparent space for the host rock. |
| [anthracite_torch_on_floor.png](anthracite/anthracite_torch_on_floor.png) | 16 × 16 | The inventory and wield sprite, using floor animation frame 02. |
| [anthracite_torch_on_floor_animated.png](anthracite/anthracite_torch_on_floor_animated.png) | 16 × 256 | Sixteen frames of an upright hot flame above the glossy head and dark wooden shaft. |
| [anthracite_torch_on_ceiling_animated.png](anthracite/anthracite_torch_on_ceiling_animated.png) | 16 × 256 | Sixteen frames of a compact curling flame at the bent ceiling sheet's lower head. |
| [anthracite_torch_animated.png](anthracite/anthracite_torch_animated.png) | 16 × 256 | Sixteen frames for the diagonal wall sheet, with the head and shaft at the existing pixel positions. |

[preview.png](anthracite/preview.png) is **1920 × 3376 RGBA**. Open at
100% for the actual 1× samples. It compares the lump, transparent overlay
and inventory torch against today's Coal art on light and dark grounds.
Both ores appear on `default_stone.png`, `grug_materials_t3_stone.png` and
`grug_materials_t6_stone.png`. Floor frames 00/04/08/12 appear side by side;
the bottom section contains **every complete animation strip at both 1×
and 8×**, beside its matching Coal strip, on both backgrounds.
All scaling is nearest neighbour.

[torch-compare.gif](anthracite/torch-compare.gif) is **960 × 720**, with
16 frames, an infinite loop and a shared 256-entry palette without
dithering. All three orientations appear beside Coal on both backgrounds.
Its 200/210 ms frame durations total **3.3 seconds**, matching the current
torch animation period to GIF timing precision. PNGs retain their exact
colours; the GIF is a palette-quantized comparison only.

### Texture layout and integration handoff

Each animated PNG has sixteen **16 × 16** frames, top to bottom, with no
padding or repacking. Pixel coordinates below are zero-based within a frame.

- **Floor:** the two-column shaft and head stay at x 7–8, y 6–15.
  The mesh cap uses x 7–8, y 6–7; the independently drawn flame remains
  above the head, at y 0–5. All cap and shaft texels are opaque.
- **Ceiling sheet:** the bent shaft starts at (5, 0) and ends in the head
  at x 6–7, y 5–6. The flame occupies the adjoining x 7–10, y 4–9 region.
- **Wall sheet:** the head stays at x 11–12, y 5–6, and the diagonal
  shaft continues to (15, 13). The flame sits above it.

**The current vendored floor, wall and ceiling mesh registrations all
sample `default_torch_on_floor_animated.png`.** An integration that reuses
those meshes should likewise use `anthracite_torch_on_floor_animated.png`
for all three registrations. The other two sheets preserve the formats
and pixel placement of their corresponding vendored image files; they
are not substitute UV atlases for the current wall/ceiling meshes.
This was checked directly in `mods/BASE/default/torch.lua` and the three
`mods/BASE/default/models/torch_*.obj` UV tables.

The assets use binary alpha 0/255, zero RGB in fully transparent pixels,
and no blur, antialiasing or baked host rock. Animation length 3.3 s and
light level 14 are integration settings; this art package registers no
items, nodes or lights.

### Generator and provenance

```sh
python3 tools/r47_art/anthracite/generate.py
```

[generate.py](anthracite/generate.py) uses Python 3 and the installed
**Pillow 12.3.0**. It contains the original lump and ore grids, palettes,
sixteen floor/wall flame grids, sixteen ceiling flame grids and explicit
shaft coordinates. It reuses the original tiny CC0 label font from
[`swamp/generate.py`](swamp/generate.py), so keep that sibling available.
New textures are painted on blank canvases before existing images are
opened for comparisons. No source pixels, recolouring, traced flame
frames, downloaded material or external fonts are used in the new art.

The comparison PNG/GIF include existing **CC BY-SA 3.0** media and are
distributed under that licence; the six separately supplied new textures
and the generator remain CC0. Full author/source details are in the
[media ledger](LICENSE-media.md#original-anthracite-textures).

### Delivery check

Checked all six texture dimensions, RGBA modes, binary alpha and zeroed
transparent RGB; all three animation strips contain 16 distinct frames.
Checked the fixed shaft/cap pixel positions against the existing texture
layouts and mesh UVs, and visually inspected both backgrounds, the three
ore composites and all torch frames including the loop transition.
Regeneration reproduced all eight media files byte for byte with the
installed Pillow version. GIF frame count, loop and total duration were
checked after reopening it.

Upgrade classification: **compatible** (art proposals only). This part
changes `tools/r47_art/anthracite/` and these two ART documentation files.
No `mods/` changes, Lua, fixtures, engine runs, agents, merge or push.
Selection and later desktop/web appearance checks belong to the user
and the integration lane.
