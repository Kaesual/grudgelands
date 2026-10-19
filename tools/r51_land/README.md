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

## Prop format (lane VIEW, for ARTL and LK)

A prop is **one node** drawn as a node box: a PNG set plus a box list. The
land viewer (`tools/r47_sw/land.html`, built by `build.py`) reads exactly this; LK later
turns each prop into a `nodebox` node. Bigger things (a gravestone of two
blocks, a statue, a cairn) are stacks of props, composed in the viewer's kit.

**Where:** one folder per prop, `tools/r51_land/props/<prop>/`. `<prop>` is
lowercase `a-z`, `0-9` and `_`, unique, and never renamed once the viewer
shows it (it is the prop's key there: `prop.<prop>`), e.g. `gravestone_a`,
`skull_human`, `cairn_stone`.

**`prop.json`** in that folder (UTF-8 JSON):

| field | meaning |
| --- | --- |
| `name` | short English name, e.g. `"Gravestone, leaning slab"` |
| `drop` | what digging it gives (L7): a default block such as `"default:cobble"`, `"default:stone"`, `"default:gravel"`, `"default:dirt"`, `"default:wood"`; `""` for nothing |
| `tiles` | 1–6 PNG file names in Luanti's order **+Y, −Y, +X, −X, +Z, −Z** (top, bottom, right, left, back, front); a shorter list repeats its last entry, as the engine does |
| `boxes` | a list of boxes `[x1, y1, z1, x2, y2, z2]` in **sixteenths** of a node, the node centre at 0, every value from −8 to 8 with `x1 < x2`, `y1 < y2`, `z1 < z2`; +Y is up and −Z is the front. LK writes each value as `v / 16` into `node_box = {type = "fixed", fixed = {...}}` |
| `alpha` | optional, `"clip"` when transparent pixels should cut holes (`use_texture_alpha = "clip"`); default: every pixel opaque |
| `rotate` | optional, default `true`: the prop may be placed turned in 90° steps round Y (`paramtype2 = "facedir"`); `false` for something that must face one way |
| `note` | optional, one line for the user |

**The PNGs:** 16 × 16 RGBA, one node, in the same folder, named
`<prop>.png` when one tile serves every face, else `<prop>_top.png`,
`<prop>_bottom.png`, `<prop>_side.png`, `<prop>_front.png`, `<prop>_back.png`
(and `_right`, `_left` when those differ). Own work, CC0, as for every ARTL
texture.

**What a box face shows** (as the engine maps node boxes): each face of a box
shows the part of its tile that lies under it, seen from outside, the image
upright. In tile pixels (column, row from the top-left corner):

| face | columns | rows |
| --- | --- | --- |
| front (−Z) | `x + 8` | `8 − y` |
| back (+Z) | `8 − x` | `8 − y` |
| right (+X) | `z + 8` | `8 − y` |
| left (−X) | `8 − z` | `8 − y` |
| top (+Y) | `x + 8` | `8 − z` (the back edge at the top of the image) |
| bottom (−Y) | `x + 8` | `z + 8` |

So a thin box only uses a strip of its tile: paint what that strip must show
and leave the rest plain. Faces of two boxes that touch are still drawn.

**Worked example** — a leaning slab, `tools/r51_land/props/gravestone_a/`:

```json
{
  "name": "Gravestone, leaning slab",
  "drop": "default:cobble",
  "tiles": ["gravestone_a_top.png", "gravestone_a_top.png", "gravestone_a_side.png",
            "gravestone_a_side.png", "gravestone_a_face.png", "gravestone_a_face.png"],
  "boxes": [[-5, -8, -1, 5, 3, 2],
            [-4, 3, -1, 4, 6, 2],
            [-6, -8, -3, 6, -6, 3]]
}
```

A slab 10 wide and 3 deep up to 3/16 above the centre, a narrower cap up to
6/16, a low foot. Its front shows columns 3–12, rows 5–15 of
`gravestone_a_face.png` for the slab and columns 4–11, rows 2–4 for the cap;
so the painter draws the weathered face in that area. Lean and crookedness
are in the boxes (a cap shifted by one sixteenth) or in a second prop; the
engine has no tilted boxes.

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
