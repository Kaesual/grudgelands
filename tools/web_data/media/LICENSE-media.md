# Website media licences

## Wide character creation backdrops — rendered composites

The six 2560 × 1440 PNGs below were rendered on 2026-11-16 from the game's
existing blocks, plant textures, meshes and building templates. No external
scene image or generated raster artwork was used. The authored arrangement
and additional project contribution are CC BY-SA 3.0; this does not relicense
incorporated components. Those retain their original licenses and notices.
Author of the arrangement and lateral extension: Grudgelands contributors.

These are browser renders, using the same material sources and the licence
notice of the [game backdrops](../../../mods/PLAYER/grug_classes/LICENSE-media.md#character-creation-backdrops--rendered-composites).
Editable base scenes and tree placements:
`tools/character_creation_preview/scenes/<race>.json`; separate wide layers:
`tools/character_creation_preview/scenes/wide/<race>.json`.
The tree shapes come from the shipped procedural generator. Source assembly:
`tools/character_creation_preview/scenery.py` and `wide/build.py`; game camera
calibration: `native.py`; renderer: `tools/building_templates/viewer/renderer.js`;
capture: `tools/character_creation_preview/render-scenes.mjs` and `wide/render.py`.
All source paths are relative to the repository root, or to
`tools/character_creation_preview/` where abbreviated.

The texture/mesh attributions and original source licenses remain in
`mods/BASE/default/license.txt`, `mods/BASE/default/LICENSE-media.md`, and the
`LICENSE-media.md` files of `mods/ITEMS/grug_decor`, `grug_nodes`, `grug_trees`,
`grug_gathering`, and `mods/MAPGEN/grug_mapgen`. In particular, the decor ledger
includes CC BY-SA 3.0, CC BY-SA 2.0 DE, CC0 and WTFPL textures, and the GPLv3
barrel/tub meshes. Their editable source meshes and notices remain alongside
the assets; the rendered composite is not offered as wholly CC0 or solely
under the license of the new arrangement. Upstream source provenance is also
recorded in [VENDOR.md](../../../VENDOR.md).

Rebuild instructions, camera/input/output receipts and projected figure anchors:
[wide/README.md](../../character_creation_preview/wide/README.md) and
`tools/character_creation_preview/wide/renders/<race>.json`.
Each SHA-256 below equals the `output` hash in that receipt.

| Local file | SHA-256 |
|---|---|
| `grug_creation_dwarf_wide.png` | `fa87b4d48e85078f283064c1c5f0bc2e7988004826d05bbc6fbbcbd4cfdabe5c` |
| `grug_creation_elf_wide.png` | `fe1acc4ecdeca5bf4f2c6c3edeaf76cfdd1e279da5cc86b07f188cda12e223fe` |
| `grug_creation_human_wide.png` | `69a4661d60358b7465fd852ad22fd59697be594ffd9b0ae8921dc297768f8ab4` |
| `grug_creation_orc_wide.png` | `17ab9f020eb2f8aab4027694d69395c13a20fdb7586fffd3dec24f49c8b92270` |
| `grug_creation_troll_wide.png` | `593359dd96991cd58a1c8b87d0ab84a9d55a9215945bed561141b35d58eb09f7` |
| `grug_creation_undead_wide.png` | `948e289e4506eaa804073d7800203b586a4108b6dc056bc12308dd8c3e46e3cc` |

---
<!-- INTRO lane: append the wide opening notice below this line. -->
## Wide character creation opening — rendered composite

`grug_creation_intro_wide.png` is the 2560 × 1440 RGB (no alpha), sRGB website render of the
game's two-keep opening, prepared in Round 80.1 on 2026-11-16. SHA-256:
`71392e92be6047dbc024accd904a360dcda94c0b9ff01b8917798481c1b775c1`.
The optional duplicate `tools/character_creation_preview/intro/wide/intro.png`
is ignored build output; the website media file is the committed deliverable.

The notice follows the game's
[opening media section](../../../mods/PLAYER/grug_classes/LICENSE-media.md#character-creation-opening--rendered-composite):
the authored arrangement and new contribution are **CC BY-SA 3.0**, without
relicensing incorporated components. Source notices remain in the default
ledgers and the media ledgers of `grug_decor`, `grug_materials`, `grug_nodes`,
`grug_trees`, `grug_guild` and `grug_mapgen` under `mods/`. These include the
GPLv3 barrel mesh and CC0 faction standards; editable sources remain in those
mods. Smoke/fire texture notices remain in `mods/ENTITIES/mobs/license.txt`,
`mods/BASE/default/license.txt` and `VENDOR.md`. This composite is not represented
as wholly CC0 or solely under the arrangement's licence.

Provenance: the unchanged `tools/character_creation_preview/intro/scene.json`
and its packed `scenes.html`, built by `tools/character_creation_preview/intro.py`;
static atmosphere from `intro-atmosphere.js`; trees from the shipped procedural
generator; geometry rendered by the embedded
`tools/building_templates/viewer/renderer.js`. The separate `intro/wide.json`
adds a low, close website camera, continues the rolling ground and tree line
to the right, and extends the camp with timber barricades, fallen logs and
rubble, including low stone debris and fallen timber in the lower-left corner.
The added trees reuse complete shapes already packed in the base scene;
all additions remain outside the visible game view.
No external illustration or generated raster artwork is included. The PNG
contains no text or figure. Three.js retains its embedded MIT notice.

Editable layer, rebuild/check commands, input and output hashes, browser
receipt and the game-camera pixel comparison:
[website opening source record](../../character_creation_preview/intro/README.md#website-opening--round-801).
