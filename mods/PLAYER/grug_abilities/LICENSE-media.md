# Media Origin & Licenses (grug_abilities)

- `grug_abilities_orb.png`: 16×16 radial gradient orb, generated with
  ImageMagick for this project (own work), **CC0**. Historical ability
  backdrop; Round 18 replaces active-skill inventory art with the action
  icons below.
- `grug_abilities_weapon_ready.png`: 20×20 gold readiness ring generated for
  this project with OpenAI image generation, chroma-keyed and reduced to the
  final HUD sprite (own work), **CC0**.

## Round 18 active-skill action icons — CC0

All 22 `textures/grug_abilities_skill_*.png` files were generated for this
project on 2026-09-23 with OpenAI's built-in `image_gen.imagegen` tool, one
separate prompt/call per asset. No third-party image was supplied to the tool.
The project dedicates any rights it holds in these generated images to
**CC0-1.0**, to the extent such rights exist. They are not imported game art.
The final files are opaque 64×64 RGB PNGs, reduced with Pillow's Lanczos
filter from the generated originals. No recoloring or compositing was applied
to the new art. Full per-file IDs, source output paths, exact prompts and
final SHA-256 hashes: `tools/r18_art/manifest.json` at the repository root.
Design rationale and reference inspection: `docs/research/round18-art-report.md`.

## Bow draw stages — CC BY-SA 4.0

The three draw-stage sprites are unchanged renamed copies from VoxeLibre
commit `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`. They are based on the
XSSheep / Pixel Perfection texture set and licensed CC BY-SA 4.0 under
VoxeLibre's top-level `LEGAL.md`; `mods/ITEMS/mcl_bows/README.txt` points its
textures to those license notes.

| Local file | Upstream source | Treatment |
|---|---|---|
| `textures/grug_abilities_bow_draw_0.png` | `textures/mcl_bows_bow_0.png` | unchanged renamed copy |
| `textures/grug_abilities_bow_draw_1.png` | `textures/mcl_bows_bow_1.png` | unchanged renamed copy |
| `textures/grug_abilities_bow_draw_2.png` | `textures/mcl_bows_bow_2.png` | unchanged renamed copy |

At runtime the Scout applies the equipped bow family's existing color grade
and any bracket modifier to the selected stage. Ending or cancelling the draw
restores that concrete bow's ordinary wield image.
