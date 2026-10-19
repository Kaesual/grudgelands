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
appearance acceptance remain open. Props continue in pass 2 below.

## ARTL pass 2: land props

[props_art.py](props_art.py) writes **15 prop folders**, each containing
`prop.json` and **six 16 × 16 RGBA tiles**, into [props/](props/), plus
[preview-props.png](preview-props.png) and [props-checks.json](props-checks.json).

```sh
python3 -I tools/r51_land/props_art.py
python3 -I tools/r51_land/props_art.py --check
```

Original **GPT-6 Astra**, **2026-10-19**, **CC0-1.0**. Every shape, palette
and mark is authored in the generator, starting from blank images; no
downloaded, traced or recoloured source artwork enters the props. The only
shared art inputs are the Round 47 CC0 pixel font and pass 1's original CC0
grounds, read for the preview. Pass 1's outputs are unchanged.

Integration notes (proposals, awaiting the user's viewer picks):

- **Bones:** `skull_human`, `skull_horned`, `ribcage_human`, `spine_animal`,
  `bones_scattered`, `bones_fragments`. Each rests at `y = -8`; skulls rise
  at most half a node and the other pieces less. The skulls use `alpha:
  "clip"` for small nasal openings; the rib, vertebra and fragment gaps are
  actual geometry. All six drop `""`, as requested. Each note mentions the
  possible alternative `grug_mobs:bone`, for the user to decide.
  **`bones_scattered` is the proposed `grug_nodes:bone_pile` successor**;
  LK can retain that registered name for the existing town-kit references.
  These are sparse finds, singles or an occasional pair, not a new density
  prescription or a repeated complete skeleton.
- **Graves:** `gravestone_slab` is a rounded, weathered stele by itself;
  `gravestone_cross` is a low cross by itself or its crown one node above
  the slab. Both drop `default:cobble`. Courses shift horizontally by one
  sixteenth to suggest age and a lean. Keep the same quarter-turn for a
  slab/crown stack; no tilted placement or fractional node position is used.
- **Cairns:** one or two `cairn_course` nodes, then `cairn_cap`, make a
  two- or three-node stack. The course reaches `y = 8`; the cap begins at
  `y = -8`, so there is no floating join. The cap is a terminal piece,
  not a repeatable course. Both drop `default:cobble`. The tree-branch
  alternative remains the viewer lane's proposal.
- **Statues:** `statue_broken_torso` and `statue_veiled_head` are pale,
  worn silver sandstone, each dropping `default:silver_sandstone`. Stack
  the head directly above the torso with the same quarter-turn, on ordinary
  silver-sandstone blocks. `obelisk_broken_tip` drops `default:stone` and
  finishes an ordinary stone shaft for the undead. Special shapes cover
  only the drapery, damaged anatomy and fractured tip, not extra plinth or
  wall blocks. There are no copper-green mineral stains.
- **Driftwood:** `driftwood_log` recommends `default:wood` for the thicker
  log; `driftwood_fork` recommends `default:stick` for the small branch.
  Both lie low, with bleached grey grain and worn, broken ends.

All props use six explicit tiles in **+Y, -Y, +X, -X, +Z, -Z** order.
Only each box face's projected strips receive texture detail; unused
texels stay at a plain material colour. The filenames follow the binding
format below. All coordinates are integer sixteenths within one node;
all props permit quarter-turn rotation. The shapes use **4–18 boxes**
each. Nothing sets runtime collision, placement density or selection boxes
in this art package; LK owns those decisions after selection.

The **1600 × 7472 RGBA** preview shows every prop from the front and in
three-quarter view, each at **1× and 4×**, on both light and dark backgrounds.
One native projected unit equals one texel; the enlarged samples use nearest
neighbour. Six diagnostic tile strips at 2× show the used face areas (unused
pixels are hidden in this diagnostic only). Keys and drops label every row.
Eight small compositions show four crooked wild graves with a broken fence,
a town row, two cairn heights, a humanoid skull/ribcage pair, a horned skull
and animal spine on mesa clay, the elf statue on silver litter, an undead
obelisk, and driftwood on sand. Each composition also has a native-size
copy. Placements use whole nodes and quarter-turns, with no scaling or tilting.

This is an orthographic box rasterization with the documented UV mapping,
depth occlusion, binary alpha and fixed face shading, **not an engine
screenshot**. Ordinary plinth, shaft and fence blocks use original neutral
material stand-ins; the cairn's ground is pass 1's ash-grey bone litter as a
colour context, not a proposed dwarf ground. The viewer and the user's
desktop/web checks remain the final appearance judgement.

The generator reopens **every `prop.json` and every referenced PNG**, checking
keys, names, tile count/order by generation, filenames, existence, box bounds
and strict extents, RGBA dimensions and binary/opaque alpha. `--check` writes
nothing and requires byte-identical regeneration, including the preview and
the SHA-256 receipt. The native/enlarged views, alpha openings, face strips
and compositions were inspected visually. Upgrade classification:
**compatible**, concept art only. No fixtures or engine runs, as requested;
no changes under `mods/`, no Lua or viewer changes. User selection and the
coordinator's independent integration review remain open.

## ARTL pass 3: sparse lichen and undead memorials

Rework after the user's first look, **2026-10-19**. Original **GPT-6 Astra**
art, **CC0-1.0**, generated with installed Pillow:

```sh
python3 -I tools/r51_land/land_art.py
python3 -I tools/r51_land/props_art.py
python3 -I tools/r51_land/land_art.py --check
python3 -I tools/r51_land/props_art.py --check
```

Run the land generator first: the new prop preview reads its three lichen
files. Both `--check` commands validate and compare outputs without writing.
The land generator now writes 15 plant textures, including the archived
lichen; the prop generator writes 19 folders. The pass-1 and pass-2 preview
sheets remain historical comparisons, byte-identical to their earlier
versions, as do the 15 existing props and all unrelated textures.

- **Lichen:** `plants/lichen_carpet_top.png` and
  `plants/lichen_carpet_top_b.png`, **16 × 16 RGBA**, each have **39 opaque
  texels out of 256** (15.23% cover, **84.77% transparent**). Each tile has
  three small, lobed grey-green/pale-grey crusts and three dull ochre flecks.
  Only alpha **0 or 255** is used, with zero RGB beneath transparent pixels.
  A and B differ in placement and orientation; their mixed repeat is shown
  alongside the individual repeats. Retain binary clipping when integrating
  the horizontal carpet. The filename of A is unchanged for viewer pickup;
  the old PNG survives byte-for-byte as `lichen_carpet_top_v1.png`.
  No saturated orange, copper-green mineral marks or luminous pixels are
  proposed. This changes appearance only; VIEW owns the requested lower
  placement frequency, and the existing drop decision is unaffected.
- **`prop.statue_mourner_base`**, *Mourner, kneeling robe and knees*:
  cracked dark stone, two forward knees and a folded robe with restrained
  olive moss; **9 boxes**, drop **`default:stone`**. It also works as a
  broken lower fragment. For **`undead.statue`**, put
  **`prop.statue_mourner_upper`**, *Mourner, bowed hood and clasped hands*,
  directly above, with the **same quarter-turn**: **14 boxes**, also
  **`default:stone`**. The upper piece contains shoulders, hands and the
  whole bowed, empty hood, and can rest on its broken waist as a separate
  bust. This is a dark, closed mourning pose, distinct from the pale elf
  head/torso pair. There are no glowing features. The base's top and upper
  piece's bottom share `x = -4..4, z = -1..4` at their node boundary.
- **`prop.gravestone_fallen`**, *Gravestone, fallen split stele*:
  **4 boxes**, drop **`default:cobble`**. Two ground-touching fragments,
  two sixteenths thick, have an open break and the old stele's eroded
  diamond on the upward face; both fragments belong to one node.
- **`prop.gravestone_sunken`**, *Gravestone, sunken leaning stele*:
  **3 boxes**, drop **`default:cobble`**. Its eight-sixteenth height is
  half the upright stele's; offset courses suggest a lean to the right
  and back, with a mossy soil line and no exposed pedestal. Both new
  gravestones use the existing slab/cross palette and engraving language.
  The wild study mixes all four types as five memorials with a broken fence.

Every new prop has `prop.json` and six **16 × 16 opaque RGBA** textures in
the binding **+Y, -Y, +X, -X, +Z, -Z** order; the unchanged format below
applies. All geometry stays inside the node, touches the ground when used
alone, and uses integer sixteenths and quarter-turns. No decorative
mushrooms, new bone props or density prescriptions are introduced.

[preview-pass3.png](preview-pass3.png) is **1600 × 4214 RGBA**, with light
and dark panels. Old lichen, A, B and a mixed A/B patch each cover a
**4 × 4-node** gravel and stone study, each at **1× and 4×**. These
preview-only substrates are original CC0 material studies, not the game's
ground textures or new replacement proposals. A filled 4 × 4 repeat tests
the artwork; it does not prescribe how frequently carpets occur in a zone.
Every new prop appears from the front and in three-quarter view at **1×
and 4×**, with face-strip diagnostics, its key, name and drop. An assembled
mourner also appears from both angles, followed by a wild graveyard and
the statue on blight dirt and bone litter; both statue scenes include a
detached bust and a sunken stone. All enlargement is nearest-neighbour.
This uses pass 2's orthographic box renderer, without engine lighting.

Delivery checks: all **19** delivered `prop.json` files and **114**
referenced tiles reopened and validated against the format; both generators
reproduce their outputs byte-for-byte. Lichen alpha, coverage, dimensions,
periods and hashes are in [artl-checks.json](artl-checks.json); prop bounds,
tile/spec hashes and both prop-preview hashes are in
[props-checks.json](props-checks.json). Native/enlarged views, stacking
contacts, ground contacts and both preview backgrounds were inspected.

Upgrade classification: **compatible**, art proposals only. No changes under
`mods/`, no Lua, viewer edits, fixtures, engine runs or agents, as requested.
The user's pick and coordinator's integration review and desktop/web
appearance checks remain open.

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
| [lichen_carpet_top_v1.png](plants/lichen_carpet_top_v1.png) | 16 × 16 RGBA | CC0-1.0 | Original pass-1 grey/orange crust, archived byte-for-byte in pass 3; shown in the historical pass-1 sheet. |
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

### ARTL pass 2 media

Every file in the 15 folders below (`prop.json` and the six named PNGs),
[props_art.py](props_art.py), [props-checks.json](props-checks.json) and
[preview-props.png](preview-props.png) is original **GPT-6 Astra**,
**2026-10-19**, dedicated to **CC0 1.0 Universal**
(<https://creativecommons.org/publicdomain/zero/1.0/>). Source for every
prop and its textures: [props_art.py](props_art.py). No third-party pixels
are used. The preview reuses pass 1's CC0 grounds (recorded above), the
Round 47 CC0 pixel font ([record](../r47_art/LICENSE-media.md)), and original
material stand-ins; its operations are projection, binary clipping, fixed
face shading, repetition, nearest-neighbour enlargement and labels.

| Prop folder | Files / size | Licence | Idea / drop |
| --- | --- | --- | --- |
| [skull_human](props/skull_human/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Low humanoid skull with dark sockets, pierced nose, worn teeth and a crown seam; drops nothing. |
| [skull_horned](props/skull_horned/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Small horned animal skull with a long muzzle and one broken horn; drops nothing. |
| [ribcage_human](props/ribcage_human/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Four arched ribs, sternum and backbone lying close to the ground; drops nothing. |
| [spine_animal](props/spine_animal/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Uneven small vertebrae, transverse processes and a broken pelvis; drops nothing. |
| [bones_scattered](props/bones_scattered/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Two irregular long bones and a chip, proposed `bone_pile` successor; drops nothing. |
| [bones_fragments](props/bones_fragments/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Broken jaw arc and two thin splinters as a quiet alternative find; drops nothing. |
| [gravestone_slab](props/gravestone_slab/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Crooked rounded stele with an eroded diamond and damp foot; `default:cobble`. |
| [gravestone_cross](props/gravestone_cross/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Chipped cross used alone or as the slab's crown; `default:cobble`. |
| [cairn_course](props/cairn_course/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Compact rough stone courses with broad stacking contacts; `default:cobble`. |
| [cairn_cap](props/cairn_cap/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Three low, offset cap stones finishing the cairn; `default:cobble`. |
| [statue_veiled_head](props/statue_veiled_head/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Almost erased face beneath a chipped pale hood; `default:silver_sandstone`. |
| [statue_broken_torso](props/statue_broken_torso/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Broken-armed torso with worn drapery for an elf relic; `default:silver_sandstone`. |
| [obelisk_broken_tip](props/obelisk_broken_tip/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Fractured grey taper above an ordinary stone shaft; `default:stone`. |
| [driftwood_log](props/driftwood_log/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Bleached grey log with exposed grain and broken end rings; `default:wood` recommended. |
| [driftwood_fork](props/driftwood_fork/) | JSON + 6 × 16 × 16 RGBA | CC0-1.0 | Thin weathered fork on the sand; `default:stick` recommended. |

### ARTL pass 3 media

Original **GPT-6 Astra**, **2026-10-19**, dedicated to **CC0 1.0 Universal**
(<https://creativecommons.org/publicdomain/zero/1.0/>). Every new bitmap
starts on a blank canvas; every box and mark is authored in the generators.
No downloaded, traced or recoloured third-party source art is used.
The preview uses the original gravel/stone studies in `props_art.py`, the
CC0 blight and bone-litter grounds from pass 1, existing CC0 props from
pass 2, and the Round 47 CC0 pixel font recorded above. Its operations are
alpha compositing, repetition, projection, fixed face shading, cropping,
nearest-neighbour scaling and labels. Both generators and both JSON check
records retain the CC0 dedication recorded above, including their pass-3
extensions.

| File | Size | Licence | Source / idea / modifications |
| --- | --- | --- | --- |
| [lichen_carpet_top.png](plants/lichen_carpet_top.png) | 16 × 16 RGBA | CC0-1.0 | `land_art.py`: replacement A, small open grey-green and pale-grey crusts, three dull ochre flecks. |
| [lichen_carpet_top_b.png](plants/lichen_carpet_top_b.png) | 16 × 16 RGBA | CC0-1.0 | `land_art.py`: alternative B, repositioned and turned colonies with the same sparse coverage. |
| [lichen_carpet_top_v1.png](plants/lichen_carpet_top_v1.png) | 16 × 16 RGBA | CC0-1.0 | `land_art.py`: unchanged pass-1 output under an archive name, for comparison only. |
| [preview-pass3.png](preview-pass3.png) | 1600 × 4214 RGBA | CC0-1.0 | `props_art.py`: lichen comparison, four props, mourner assembly, mixed graves and two undead ground contexts. |

For each prop below the media record covers the explicitly listed six
**16 × 16 RGBA** files plus **`prop.json`** in that folder. Source:
[props_art.py](props_art.py); licence: **CC0-1.0** for every file.

| Prop folder | Files | Idea / drop |
| --- | --- | --- |
| [statue_mourner_base](props/statue_mourner_base/) | `prop.json`, `statue_mourner_base_top.png`, `statue_mourner_base_bottom.png`, `statue_mourner_base_right.png`, `statue_mourner_base_left.png`, `statue_mourner_base_back.png`, `statue_mourner_base_front.png` | Kneeling dark-stone lower body, cracked robe and mossy knees; `default:stone`. |
| [statue_mourner_upper](props/statue_mourner_upper/) | `prop.json`, `statue_mourner_upper_top.png`, `statue_mourner_upper_bottom.png`, `statue_mourner_upper_right.png`, `statue_mourner_upper_left.png`, `statue_mourner_upper_back.png`, `statue_mourner_upper_front.png` | Bowed hollow hood, clasped hands, worn shoulders, broken waist; `default:stone`. |
| [gravestone_fallen](props/gravestone_fallen/) | `prop.json`, `gravestone_fallen_top.png`, `gravestone_fallen_bottom.png`, `gravestone_fallen_right.png`, `gravestone_fallen_left.png`, `gravestone_fallen_back.png`, `gravestone_fallen_front.png` | Two flat pieces with an open break and weathered upward engraving; `default:cobble`. |
| [gravestone_sunken](props/gravestone_sunken/) | `prop.json`, `gravestone_sunken_top.png`, `gravestone_sunken_bottom.png`, `gravestone_sunken_right.png`, `gravestone_sunken_left.png`, `gravestone_sunken_back.png`, `gravestone_sunken_front.png` | Half-buried, offset stele sharing the existing graves' stone and diamond; `default:cobble`. |
