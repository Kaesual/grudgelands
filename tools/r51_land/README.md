# Round 51 land rework — swamp texture lab

Concept material for the land-zone rework, starting with the swamp.

- [swamp_calm.py](swamp_calm.py) writes the calm swamp proposals into
  [swamp/](swamp/): `wet_grass_top_calm(32)`, `mud_mottled_top_calm(32)`,
  `wet_grass_side_calm`, `mud_mottled_side_calm` and `hanging_moss_strand`.
  They keep lane ART's palettes (tools/r47_art/swamp) but weight the coarse
  field less, use the middle of each palette and drop the stamped pockets,
  so a tile carries no single motif. A 32 × 32 file is meant for
  `align_style = "world", scale = 2` (one texture over 2 × 2 nodes, 16 px
  per node). `hanging_moss_strand` starts and ends with the top row of
  `hanging_moss.png`, so stacked moss is one continuous curtain that ends in
  the tapered piece.
- The swamp concept page ([tools/r47_sw](../r47_sw/), `build.py`) inlines
  every PNG in `swamp/` as `lab_<file>`; its texture lab compares them with
  today's textures per slot and takes uploaded PNGs (16, 32 or 64 px).

User picks (2026-10-18): wet grass top and wet mud top in their 2 × 2
(32 px) versions, the continuous hanging-moss strand.

## SWART: three more grounds

[swamp_art.py](swamp_art.py) draws the plain mud, dry crust and moss-soil
tops at **32 × 32**, plus an opaque **16 × 16** moss-soil side:

```sh
python3 -I tools/r51_land/swamp_art.py
```

Requires the installed Pillow (12.3.0 at delivery). New textures start on
blank canvases, using independently seeded periodic fields and original
palettes. Fine grains, small aggregates and soft moss cushions carry most
of the variation; the broad field has only 6–8% weight. Most pixels use
the middle palette values. The dry crust has three small broken edges;
there are no stamped pockets, directional mud highlights or grass blades
in the moss. No downloads, traced pixels or recoloured source images.
The generator reads existing images only when composing the preview and
reuses the original CC0 pixel font from
[`tools/r47_art/swamp/generate.py`](../r47_art/swamp/generate.py).

Integration intent: the three tops repeat over **2 × 2 nodes**, using
`align_style = "world", scale = 2`, with **16 pixels per node**.
`mud_top_32.png` also suits vertical banks. Keep the Round 47
`mud_dry_side.png` with the new dry top. The moss side repeats horizontally
at one tile per node, with a ragged 3–6-pixel moss fringe over independently
drawn brown dirt; keep `default_dirt.png` for the bottom.

[preview-32.png](swamp/preview-32.png) is **1600 × 2104 RGBA**, on light
and dark backgrounds. Each new texture appears at **1× and 4×**, and as
an **8 × 8-node** area beside today's version, both at 2× pixel scale.
The tops repeat **4 × 4** tiles; today's 16 px versions and the new side
repeat **8 × 8** tiles over the same area. Stacked side caps are a
comparison only: the side is horizontally tileable, not vertically.
A **16 × 12-node mixed patch** joins all three new grounds to the picked
wet grass and mottled mud, following irregular node boundaries while
keeping one world texture phase. Cap/side/bottom strips and the existing
moss carpet show the colour relationships. All scaling is nearest
neighbour; open at 100% for the native samples.

Delivery checks: all five PNGs reopened with the stated dimensions,
RGBA mode and alpha 255 throughout; byte-identical regeneration;
no shorter axis period in any new tile; wrapped seams and repeated
patches inspected. Mean RGB of the plain mud is (53.71, 55.64, 42.34),
close to today's (53.55, 55.38, 42.16). Mean HSV saturation of the moss
is 0.425, between the moss carpet's 0.407 (opaque pixels) and the picked
wet grass's 0.465; today's moss is 0.663.

Upgrade classification: **compatible** (art proposals only). No `mods/`,
Lua, viewer or coordinator-art changes; no fixtures or engine runs.
Selection, independent review and desktop/web appearance checks remain
with the user and coordinator's integration lane.

## ARTL pass 1: land grounds and plants

[land_art.py](land_art.py) writes **12 grounds** into [grounds/](grounds/)
and **13 plants** into [plants/](plants/), plus the two comparison sheets:

```sh
python3 -I tools/r51_land/land_art.py
```

Original pixel work by **GPT-6 Astra**, 2026-10-19. The generator uses
authored palettes, toroidal material fields and hand-drawn pixel silhouettes.
It reuses the CC0 field helpers from `swamp_art.py` and the Round 47 CC0
pixel font; it does not execute their main functions or write their outputs.
Existing textures are read only for comparisons. No downloaded, traced or
recoloured source pixels enter the new textures.

Integration intent (all still proposals, awaiting the user's viewer picks):

- Every `*_32.png` is **32 × 32**, opaque RGBA, spanning **2 × 2 nodes**
  with `align_style = "world", scale = 2`; texel density stays 16 px/node.
  All are periodic on both axes, without a baked horizon or light direction.
  Clay bands are separate colours: placement supplies the horizontal strata.
- `swamp_moss_side.png` is **16 × 16**, opaque, horizontally periodic, with
  a 3–6 px moss fringe on cool mud. It has an intentional top and bottom.
  The swamp moss is darker and cooler than the picked SWART forest moss,
  with soft cushions instead of grass blades.
- Silver litter keeps the ivory-green palette, so retain today's
  `grug_nodes_silver_litter_side.png` over dirt. Its join is in the preview;
  no replacement side is proposed.
- All plants are **16 × 16 RGBA**, with only alpha **0 or 255**, and zero
  RGB under transparent pixels. Bush foliage is for **allfaces**; lichen is
  a horizontal carpet; the other images are **plantlike**, one texture per
  node. Neither plantlike images nor the bush foliage use world alignment.
- The liana strand's first and last rows and the end's first row are
  identical. A chain is `N - 1` strands followed by one end; the final two
  rows of the end are empty. Side edges are clear. The low alpine plants
  occupy the bottom seven rows, rooted at row 15.

[preview-grounds.png](preview-grounds.png) is **1600 × 5494 RGBA**:
1×/4× samples, each new 32 px tile over an **8 × 8-node area** beside
today's ground at the same scale, and **16 × 10-node** irregular elf,
undead, badlands and swamp studies. The badlands show horizontal bands on
an exposed stepped slope face; the swamp includes all four picked ground
tops beside its own moss. Texture phase follows world pixels across node
boundaries. A sand study adds labelled flat water-colour overlays.

[preview-plants.png](preview-plants.png) is **1600 × 3610 RGBA**:
1×/4× samples, repeat studies for foliage and lichen, lianas **1, 3 and 6
nodes high including the end**, plants on their zone grounds and every
flower beside gathering sources. All twelve catalog sources appear in a
register with the actual world texture expressions. The flower comparisons
include the union of relevant biome-family sources and neighbouring swamp
sources, not a claim that every source occurs in every zone.

**The catalog alone is not the current appearance.** The previews respect
`grug_gathering/presentation.lua`: Sunleaf, Gravemoss and Wild Cocoa use
their `_plant` files; Corn, Potato, Melon and Mushroom use mature crop
textures via `grug_nodes/crop_visual.lua`. The remaining numeric
`colorize` expressions reproduce the engine's rounded channel interpolation
(`reference_projects/luanti/src/client/imagesource.cpp`, `apply_colorize`,
and `irr/include/SColor.h`, `getInterpolated`). The main checkout's pinned
engine source was inspected read-only; this worktree's uninitialised
reference submodules were left untouched.

Both sheets use light and dark backgrounds and nearest-neighbour scaling.
They are orthographic texture studies, not engine screenshots: wild crops'
1.15 visual scale is rounded to whole preview pixels, leaf faces are shown
flat rather than as an allfaces bush, and the sand overlays do not simulate
engine water. The VIEW lane owns the 3D judgement.

[artl-checks.json](artl-checks.json) records dimensions, RGBA mode, alpha,
SHA-256, full axis periods, and mean seam/interior neighbour differences.
The generator checks saved pixels against its output, full 32/16 periods
for repeatable textures, clean alpha and exact liana joins. A seamless
periodic field does **not** require identical opposite edge rows: those
rows are adjacent samples, not duplicate samples. The mud side is checked
only horizontally for period; plantlike silhouettes do not tile. Wrapped
repeats, both backgrounds, side joins, strata and source comparisons were
also inspected visually. Re-running the generator reproduces every output
byte for byte.

Upgrade classification: **compatible**, concept art only. No changes under
`mods/`, no Lua, no viewer or SWART changes; no fixtures or engine runs,
as requested. User selection, independent integration review and desktop/web
appearance acceptance remain open. Props are deferred to pass 2.

## Media

The files of `swamp_calm.py` are original, generated by Claude (Opus 5.5)
on 2026-10-18 from lane ART's CC0 palettes, and dedicated to **CC0 1.0
Universal**.

The four SWART textures and their generator are original work by
**GPT-6 Astra**, **2026-10-18**, dedicated to **CC0 1.0 Universal**
(<https://creativecommons.org/publicdomain/zero/1.0/>). This table is their
per-file media record; source is [swamp_art.py](swamp_art.py).

| File | Size | Licence | Idea / modifications |
| --- | --- | --- | --- |
| [mud_top_32.png](swamp/mud_top_32.png) | 32 × 32 RGBA | CC0-1.0 | Original dark, cool olive-brown aggregates, with quiet structure and no up/down on exposed banks. |
| [mud_dry_top_32.png](swamp/mud_dry_top_32.png) | 32 × 32 RGBA | CC0-1.0 | Original muted dry crust with three tiny broken edges, matching the existing dry-mud side. |
| [moss_soil_top_32.png](swamp/moss_soil_top_32.png) | 32 × 32 RGBA | CC0-1.0 | Original soft natural-green cushions, subdued enough for swamp hummocks and plain enough for forest soil. |
| [moss_soil_side.png](swamp/moss_soil_side.png) | 16 × 16 RGBA | CC0-1.0 | Original irregular moss fringe over warm brown earth, fully opaque and horizontally tileable. |
| [swamp_art.py](swamp_art.py) | Python source | CC0-1.0 | Original deterministic palette/field drawing and comparison layout, reusing the Round 47 CC0 pixel font. |
| [preview-32.png](swamp/preview-32.png) | 1600 × 2104 RGBA | CC BY-SA 3.0 Unported | Today/new repeats, irregular world-aligned patchwork and side joins on two backgrounds; nearest-neighbour scaling, repetition, cropping, compositing and labels. |

The comparison includes existing **CC BY-SA 3.0 Unported** artwork and
is distributed under that licence
(<https://creativecommons.org/licenses/by-sa/3.0/>); the four separate new
textures and generator remain CC0. Its original layout and new artwork
are also offered under CC BY-SA 3.0 for this combined sheet. Credits:

- **paramat:** `default_moss.png` and `default_moss_side.png`, CC BY-SA 3.0;
  [source top](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_moss.png),
  [source side](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_moss_side.png).
  Used unchanged for the today comparisons; the side is composited over dirt.
- **random-geek**, derived from **Neuromancer:** `default_dirt.png`,
  CC BY-SA 3.0;
  [source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_dirt.png).
  Used unchanged for the old moss side and bottom join. **Grudgelands
  contributors** made its existing olive recolour `grug_nodes_mud.png`,
  used unchanged for today's mud comparison.
- **GPT-6 Astra:** Round 47 dry top/side, moss carpet and label font,
  CC0-1.0; [per-file provenance](../r47_art/LICENSE-media.md).
- **Claude (Opus 5.5):** the picked `wet_grass_top_calm32.png` and
  `mud_mottled_top_calm32.png`, CC0-1.0, recorded above; unchanged in the
  mixed patch and its swatches.

Existing attribution verified locally in
[`default/README.txt`](../../mods/BASE/default/README.txt) and
[`default/license.txt`](../../mods/BASE/default/license.txt), with the mud
derivation in the
[`grug_nodes` media ledger](../../mods/ITEMS/grug_nodes/LICENSE-media.md).

### ARTL pass 1 media

All 25 separate new textures, their generator and the generated check record
are original **GPT-6 Astra**, **2026-10-19**, dedicated to **CC0 1.0
Universal** (<https://creativecommons.org/publicdomain/zero/1.0/>).
Source for every new PNG: [land_art.py](land_art.py). No modifications of
third-party art occur in these individual assets.

| File | Size | Licence | Idea / modifications |
| --- | --- | --- | --- |
| [swamp_moss_top_32.png](grounds/swamp_moss_top_32.png) | 32 × 32 RGBA | CC0-1.0 | Dark, damp, cool moss cushions with quiet olive-green variation. |
| [swamp_moss_side.png](grounds/swamp_moss_side.png) | 16 × 16 RGBA | CC0-1.0 | Ragged soft moss fringe over cool muddy earth. |
| [silver_litter_top_32.png](grounds/silver_litter_top_32.png) | 32 × 32 RGBA | CC0-1.0 | Six loose clusters of pale folded leaves in a muted ivory-green bed. |
| [blight_dirt_32.png](grounds/blight_dirt_32.png) | 32 × 32 RGBA | CC0-1.0 | Calm grey-violet earth aggregates, retaining the blight's palette. |
| [bone_litter_top_32.png](grounds/bone_litter_top_32.png) | 32 × 32 RGBA | CC0-1.0 | Ash-grey litter with a few tiny weathered pale fragments. |
| [mesa_clay_32.png](grounds/mesa_clay_32.png) | 32 × 32 RGBA | CC0-1.0 | Soft terracotta mineral grain that works on tops and steep faces. |
| [canopy_litter_top_32.png](grounds/canopy_litter_top_32.png) | 32 × 32 RGBA | CC0-1.0 | Deep emerald litter with subdued broad leaf folds. |
| [clay_band_ochre_32.png](grounds/clay_band_ochre_32.png) | 32 × 32 RGBA | CC0-1.0 | Warm ochre clay for mellow golden strata. |
| [clay_band_sienna_32.png](grounds/clay_band_sienna_32.png) | 32 × 32 RGBA | CC0-1.0 | Muted red-brown clay for iron-coloured sediment layers. |
| [clay_band_chalk_32.png](grounds/clay_band_chalk_32.png) | 32 × 32 RGBA | CC0-1.0 | Pale warm buff clay for a restrained light sediment seam. |
| [clay_band_umber_32.png](grounds/clay_band_umber_32.png) | 32 × 32 RGBA | CC0-1.0 | Quiet brown-grey clay for darker basal strata. |
| [sand_32.png](grounds/sand_32.png) | 32 × 32 RGBA | CC0-1.0 | Plain warm beach sand with fine grain and no directional ripple stamp. |
| [liana_strand.png](plants/liana_strand.png) | 16 × 16 RGBA | CC0-1.0 | Thin woody hanging vine with small alternating leaves and matching end rows. |
| [liana_end.png](plants/liana_end.png) | 16 × 16 RGBA | CC0-1.0 | Matching vine tip curling down to a bare tapered end. |
| [flower_ruby_fan.png](plants/flower_ruby_fan.png) | 16 × 16 RGBA | CC0-1.0 | Two small ruby-red petal fans on bent green stems. |
| [flower_ember_star.png](plants/flower_ember_star.png) | 16 × 16 RGBA | CC0-1.0 | Two open orange stars with dark centres and low leaves. |
| [flower_violet_fan.png](plants/flower_violet_fan.png) | 16 × 16 RGBA | CC0-1.0 | Small violet petal fans above a sparse green base. |
| [flower_blush_star.png](plants/flower_blush_star.png) | 16 × 16 RGBA | CC0-1.0 | Soft dusty-pink woodland stars on two short stems. |
| [flower_lilac_bells.png](plants/flower_lilac_bells.png) | 16 × 16 RGBA | CC0-1.0 | Two pale lilac bells hanging from a slender arch. |
| [flower_cream_cups.png](plants/flower_cream_cups.png) | 16 × 16 RGBA | CC0-1.0 | Small open cream cups above modest green leaves. |
| [withered_bush_leaves.png](plants/withered_bush_leaves.png) | 16 × 16 RGBA | CC0-1.0 | Curled dry yellow leaves and a few exposed brown twigs. |
| [jungle_bush_leaves.png](plants/jungle_bush_leaves.png) | 16 × 16 RGBA | CC0-1.0 | Broad overlapping leaves with subdued central folds and open gaps. |
| [lichen_carpet_top.png](plants/lichen_carpet_top.png) | 16 × 16 RGBA | CC0-1.0 | Dull grey and earthy orange lobes forming a thin broken crust. |
| [alpine_cushion.png](plants/alpine_cushion.png) | 16 × 16 RGBA | CC0-1.0 | Compact grey-sage cushion hugging the gravel. |
| [alpine_windshrub.png](plants/alpine_windshrub.png) | 16 × 16 RGBA | CC0-1.0 | Low woody evergreen with short folded leaves above the snow. |
| [land_art.py](land_art.py) | Python source | CC0-1.0 | Original deterministic drawing, source rendering, preview layout and image checks, reusing the documented CC0 helpers. |
| [artl-checks.json](artl-checks.json) | JSON | CC0-1.0 | Reproducible image dimensions, alpha, periods, seams and file hashes. |
| [preview-grounds.png](preview-grounds.png) | 1600 × 5494 RGBA | CC BY-SA 3.0 Unported | Today/new repeats, world-phase mixed grounds, side joins, stepped strata and labelled sand colour studies. |
| [preview-plants.png](preview-plants.png) | 1600 × 3610 RGBA | CC BY-SA 4.0 International | Plant swatches, zone-ground contexts, continuous lianas and current gathering world textures with runtime colour treatments. |

The previews include existing artwork: the ground sheet is distributed under
[CC BY-SA 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/),
the plant sheet under
[CC BY-SA 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/)
(its crop references include CC BY-SA 4.0). The original layout and new art
are also offered under those licences for the combined sheets; the separate
new assets remain CC0. Preview operations are nearest-neighbour scaling,
cropping, repetition, compositing, labels and the explicitly shown colour
treatments. Attribution for source pixels used in these sheets:

- **paramat:** `default_moss.png`, CC BY-SA 3.0; the existing swamp-moss
  comparison, [source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_moss.png).
  Also `default_dry_grass_2.png` and `default_marram_grass_1.png`, `_2.png`,
  `_3.png` (the latter derived from **TumeniNodes**), CC BY-SA 3.0;
  [source directory](https://github.com/luanti-org/minetest_game/tree/b5243f3/mods/default/textures).
  The gathering comparisons apply the catalog's `colorize` values.
- **TumeniNodes:** `default_coniferous_litter.png` and its side,
  CC BY-SA 3.0, the originals behind the project's silver, bone, canopy and
  forest recolours; [source top](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_coniferous_litter.png),
  [source side](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_coniferous_litter_side.png).
  Existing project recolours used unchanged; their derivations are in
  [`grug_nodes/LICENSE-media.md`](../../mods/ITEMS/grug_nodes/LICENSE-media.md).
- **random-geek**, derived from **Neuromancer:** `default_dirt.png`,
  CC BY-SA 3.0, behind the blight recolour and the retained silver side's
  dirt; [source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_dirt.png).
- **celeron55 / Perttu Ahola:** `default_clay.png`, CC BY-SA 3.0, the
  source of the existing mesa-clay recolour;
  [source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_clay.png).
- **VanessaE:** `default_sand.png`, CC BY-SA 3.0;
  [source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_sand.png).
- **Cisoun:** `default_stone.png`, CC BY-SA 3.0;
  [source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_stone.png).
- **Gambit:** `default_snow.png` and `default_clay_lump.png`, CC BY-SA 3.0;
  [snow](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_snow.png),
  [clay lump](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_clay_lump.png).
  The latter uses Rock Salt's catalog colour treatment.
- **sofar**, derived from **Gambit:** `default_gravel.png`, CC0-1.0;
  [source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_gravel.png).
- **SaKeL:** `x_farming_corn_10.png` and `x_farming_potato_8.png`,
  CC BY-SA 4.0, shipped unchanged as `grug_farming_corn_4.png` and
  `grug_farming_potato_4.png`;
  [pinned source licence](https://bitbucket.org/minetest_gamers/x_farming/src/ac5f69d5103d4af841b1a5ed3a0b49a4e19d0c84/LICENSE.txt).
  The copied stages are recorded by
  [`import_crop_stages.sh`](../r10_art/import_crop_stages.sh) and the
  [`grug_farming` ledger](../../mods/ITEMS/grug_farming/LICENSE-media.md).
- **GPT-6 Astra:** SWART forest moss, plain/dry mud, Round 47 pixel font,
  and Round 48 Sunleaf, Gravemoss, Wild Cocoa, mature Melon and Mushroom,
  CC0-1.0; source records above, in
  [`tools/r47_art/LICENSE-media.md`](../r47_art/LICENSE-media.md), and in
  [`tools/r48_artp/LICENSE-media.md`](../r48_artp/LICENSE-media.md).
- **Claude (Opus 5.5):** picked wet grass and mottled mud, CC0-1.0;
  source records above.

Default-file attribution was verified in the vendored
[`default/README.txt`](../../mods/BASE/default/README.txt); the two crop
files were checked in the pinned `x_farming/LICENSE.txt` (SaKeL's
CC BY-SA 4.0 list). The source repositories are provenance, not design
references.
