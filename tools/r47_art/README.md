# Round 47 ART — Swamp proposals

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

## Textures and intended use

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

## Generator and provenance

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

## Delivery check

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
