# Round 68 ART — media provenance

## Original candidates

All files in `candidates/` are original geometry, pixel textures, inventory
icons or supporting material/specification data authored for Grudgelands by
GPT-6 Astra on 2026-10-31. They are drawn entirely by `generate.py` with
Python, Pillow and numpy. No source image pixels, external images, fonts or
generated bitmap sources enter a candidate. The wood palette was inspected
against the existing wall sign and chest; the candidate grain is original.

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

Identically named PNGs in `preview/` are byte-identical copies. The
candidate model projections, stacks and contact sheet combine the original
art with the CC0 font below. They are also CC0-1.0. The two comparison
strips retain the comparison texture licences below and must not be
mistaken for distributable game assets.

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
| `scale_a.png`, `scale_b.png`: wall-sign portion | `mods/BASE/default/textures/default_sign_wall_wood.png`, by **Gambit**, **CC-BY-SA-3.0**; [source attribution](../../mods/BASE/default/README.txt), [licence](../../mods/BASE/default/license.txt). Rendered on a 0.875 × 0.625-node board, with the original nodebox UV crop and separate CC0 sample lettering. |
| `scale_a.png`, `scale_b.png`: chest portion | `mods/BASE/default/textures/default_chest_{front,side,top}.png`, by **BlockMen**, **CC-BY-SA-3.0**; [source attribution](../../mods/BASE/default/README.txt), [licence](../../mods/BASE/default/license.txt). Rendered on a one-node closed chest. |

The comparison strips are offline derivative renderings, distributed under
**CC-BY-SA-3.0**; the original sign candidates retain their independent CC0
dedication. A receiving lane should copy only the selected candidate files
and record their CC0 provenance in the receiving mod's media ledger.
