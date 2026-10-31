# Round 68 ART — media provenance

## Original candidates

All files in `candidates/` are original geometry, pixel textures, inventory
icons or supporting material/specification data authored for Grudgelands by
GPT-6 Astra on 2026-10-31. They are drawn entirely by `generate.py` with
Python, Pillow and numpy. No source image pixels, external images, fonts or
generated bitmap sources enter a candidate. The wood palette was inspected
against the existing wall sign, chest and planks; the candidate grain is original.

The project dedicates any rights it holds in these original assets to
**CC0-1.0**, to the extent such rights exist. The generator is
**GPL-3.0-or-later**, following the repository code licence.

| Files in `candidates/` | Count | Construction |
|---|---:|---|
| `{sign_standing,waypost,notice_board}_{a,b}.obj` | 6 | Original low-polygon models in node units, with one material group. |
| `{sign_standing,waypost,notice_board}_{a,b}.mtl` | 6 | One material referencing the corresponding atlas. |
| `{sign_standing,waypost,notice_board}_{a,b}.png` | 6 | Original opaque 64 × 64 pixel atlases, UV-mapped at 16 texels per node. |
| `{sign_standing,waypost,notice_board}_{a,b}_inv.png` | 6 | Original transparent 16 × 16 renders of the unlettered models. |
| `{sign_standing,waypost,notice_board}_{a,b}.json` | 6 | Original model, text-plane and suggested collision/selection specifications. |
| `sign_wall_wood.png` | 1 | GPT-6 Astra, original CC0-1.0 redraw from [generate.py](generate.py): 16 × 16 warm timber, uniform writing field and narrow rim. No source pixels copied. |
| `sign_wall_iron.png` | 1 | GPT-6 Astra, original CC0-1.0 redraw from [generate.py](generate.py): 16 × 16 light grey iron, uniform writing field and narrow rim. No source pixels copied. |

### Pass 3 — wood sets

Each file below is original work by **GPT-6 Astra, 2026-10-31**, generated
from [generate.py](generate.py), dedicated to **CC0-1.0**. The shipped OBJ
and UV layouts are unchanged. Chest/plank pixels are used only in the
comparison strips, never in these candidates. The palette and long-grain
pixel treatment guide newly drawn pixels; there is no image extraction.

| File in `candidates/` | Construction / modifications | Licence |
|---|---|---|
| `sign_standing_wood_a.png` | Original 64 × 64 atlas, planed timber on the picked standing model. | CC0-1.0 |
| `sign_standing_wood_b.png` | Original 64 × 64 atlas, warm heartwood on the same model. | CC0-1.0 |
| `waypost_wood_a.png` | Original 64 × 64 atlas, planed arrow and uniform round-post sample. | CC0-1.0 |
| `waypost_wood_b.png` | Original 64 × 64 atlas, warm arrow and uniform round-post sample. | CC0-1.0 |
| `notice_board_wood_a.png` | Original 64 × 64 atlas, planed boards, vertical frame grain and roof knot. | CC0-1.0 |
| `notice_board_wood_b.png` | Original 64 × 64 atlas, warm boards, richer frame and roof grain. | CC0-1.0 |
| `sign_wall_wood_a.png` | Original 16 × 16 tile, planed boards in the fixed nodebox layout. | CC0-1.0 |
| `sign_wall_wood_b.png` | Original 16 × 16 tile, warm boards in the same layout. | CC0-1.0 |
| `sign_standing_wood_a_inv.png` | 16 × 16 transparent render of the unlettered model with wood A. | CC0-1.0 |
| `sign_standing_wood_b_inv.png` | 16 × 16 transparent render of the unlettered model with wood B. | CC0-1.0 |
| `waypost_wood_a_inv.png` | 16 × 16 transparent render of the unlettered model with wood A. | CC0-1.0 |
| `waypost_wood_b_inv.png` | 16 × 16 transparent render of the unlettered model with wood B. | CC0-1.0 |
| `notice_board_wood_a_inv.png` | 16 × 16 transparent render of the unlettered model with wood A. | CC0-1.0 |
| `notice_board_wood_b_inv.png` | 16 × 16 transparent render of the unlettered model with wood B. | CC0-1.0 |

### Pass 4 — picked notice-board halves

Original work by **GPT-6 Astra, 2026-10-31**, generated from
[generate.py](generate.py), dedicated to **CC0-1.0**. The source model and
picked warm-heartwood atlas remain unchanged.

| File in `candidates/` | Construction / modifications | Licence |
|---|---|---|
| `notice_board_b_left.obj` | Source model clipped at x = +0.5, retaining the lower-x surfaces and their UVs; origin unchanged. | CC0-1.0 |
| `notice_board_b_right.obj` | Source model clipped at x = +0.5, retaining the higher-x surfaces and their UVs; shifted −1 in x to its own node centre. | CC0-1.0 |
| `notice_board_b_left.mtl` | One wood material using the unchanged `notice_board_wood_b.png` atlas. | CC0-1.0 |
| `notice_board_b_right.mtl` | Same shared atlas and material for the right half. | CC0-1.0 |

The four `preview/notice_halves_{front,angle}_{whole,joined}.png` images
are original **CC0-1.0** software renders of the serialized models. They
contain no comparison assets or lettering. `notice_halves_manifest.json`
records the model measurements and pixel comparisons.

Identically named PNGs in `preview/` are byte-identical copies. The
candidate model projections, stacks and contact sheet combine the original
art with the CC0 font below. They are also CC0-1.0, including pass 3's
front/angle/reverse views and stack/join close-ups. The pass-3 `*_shipped`
previews use the unchanged CC0 assets from passes 1 and 2. The family comparison
strips and the wall comparison retain the comparison texture licences below
and must not be mistaken for distributable game assets.

## Preview font input

**VoxeLibre**, pinned reference commit
`2373982f19f9b5d89cd2e3146ad7749876319e15`:

- The font is **CC0-1.0**, originally by **PilzAdam**, modified and extended
  by **EmoryNB**, as recorded in
  `reference_projects/VoxeLibre/mods/ITEMS/mcl_signs/README.md`, "Font".
- Source mapping:
  `reference_projects/VoxeLibre/mods/ITEMS/mcl_signs/characters.tsv`.
  Source images: `reference_projects/VoxeLibre/textures/_*.png`.
- `inputs/reference_font.png` packs the 95 printable ASCII glyphs at their
  original dimensions and alpha, without resampling. White source pixels
  are preserved. `inputs/reference_font.json` records each glyph's atlas
  crop, the original table's width column and the SHA-256 of its source PNG.
  The width column is provenance, not a claimed runtime advance.
- The lane's reference submodule was uninitialized. The snapshot was read
  from the main checkout's already initialized reference at the same
  pinned commit. No reference checkout, pin or main-tree file was changed.
  The two small saved inputs make generation independent of that checkout.
- Only preview text planes tint these glyphs to dark ink. No font is
  installed, no reference code/model is copied, and no glyph enters a
  candidate texture or inventory icon.

## Comparison assets

The following are **review-only** references. Their original attribution
and licence records remain authoritative:

| Preview files | Source, attribution and licence |
|---|---|
| `inputs/wall_wood_before.png`; `wall_comparison.png`: old wooden-sign portion | Byte-identical copy of `mods/BASE/default/textures/default_sign_wall_wood.png`, by **Gambit**, **CC-BY-SA-3.0**; [pinned upstream source](https://github.com/minetest/minetest_game/blob/b5243f3e42410ae3ca85ead795149406fa654538/mods/default/textures/default_sign_wall_wood.png), [source attribution](../../mods/BASE/default/README.txt), [licence](../../mods/BASE/default/license.txt). The comparison adds separate CC0 sample lettering and original preview masonry. |
| `inputs/wall_iron_before.png`; `wall_comparison.png`: old iron-sign portion | Byte-identical copy of `mods/BASE/default/textures/default_sign_wall_steel.png`, by **celeron55 (Perttu Ahola)** under the source README's unlisted-media attribution, **CC-BY-SA-3.0**; [pinned upstream source](https://github.com/minetest/minetest_game/blob/b5243f3e42410ae3ca85ead795149406fa654538/mods/default/textures/default_sign_wall_steel.png), [source attribution](../../mods/BASE/default/README.txt), [licence](../../mods/BASE/default/license.txt). Same separate CC0 text and original masonry. |
| `scale_a.png`, `scale_b.png`, `wood_scale_{shipped,a,b}.png`: chest portion | `mods/BASE/default/textures/default_chest_{front,side,top}.png`, by **BlockMen**, **CC-BY-SA-3.0**; [source attribution](../../mods/BASE/default/README.txt), [licence](../../mods/BASE/default/license.txt). Rendered on a one-node closed chest. |
| `wood_scale_shipped.png`: plank portion | `mods/BASE/default/textures/default_wood.png`, by **BlockMen**, **CC-BY-SA-3.0**; [source attribution](../../mods/BASE/default/README.txt), [licence](../../mods/BASE/default/license.txt). Rendered on a one-node plank block. |
| `wood_scale_a.png`: plank portion | Same `default_wood.png`, **BlockMen**, **CC-BY-SA-3.0**, source and licence as above; unchanged pixels on a one-node block beside texture set A. |
| `wood_scale_b.png`: plank portion | Same `default_wood.png`, **BlockMen**, **CC-BY-SA-3.0**, source and licence as above; unchanged pixels on a one-node block beside texture set B. |

The wall snapshots preserve the original comparison after the receiving lane
replaces the runtime textures. SHA-256:

- `wall_wood_before.png`: `a8e2a5be9b54bbec0b7804a9b87efcd6fe3f2975e64c84e8f965b7ff9b910675`.
- `wall_iron_before.png`: `ddf0e3dcc2690eb8eecccbfb79e7a1db905a987eaca9c14271620dcf55234caa`.

The new wall portions in all three comparisons are the original CC0-1.0
candidates above. The masonry in `wall_comparison.png` is original CC0-1.0
preview art drawn by the generator; it is not an imported game texture.
All wall boards use the existing nodebox's 0.875 × 0.625 × 0.0625-node
dimensions and UV layout. The original wall textures appear only in the
wall comparison, not in the refreshed family strips.

All six comparison strips are offline derivative renderings, distributed under
**CC-BY-SA-3.0**; the original sign candidates retain their independent CC0
dedication. A receiving lane should copy only the selected candidate files
and record their CC0 provenance in the receiving mod's media ledger.
